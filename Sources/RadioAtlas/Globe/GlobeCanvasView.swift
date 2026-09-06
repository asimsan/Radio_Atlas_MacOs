import AppKit
import RadioAtlasCore
import SwiftUI

/// Flat-shaded, orthographic-projection globe rendered on a SwiftUI `Canvas`,
/// matching the original omarchy-radio-atlas plugin's `Globe.qml` (a
/// QtQuick `Canvas`/2D-painter globe) rather than a lit, textured 3D sphere.
/// Colors are the exact values from the design spec's Visual Design Reference.
struct GlobeCanvasView: View {
    let stations: [Station]
    let countryLookup: CountryLookup
    let regions: [CountryRegion]
    let activeCountryCode: String?
    let onStationTapped: (Station) -> Void
    let onCountryTapped: (String) -> Void

    @StateObject private var interaction = GlobeInteractionState()
    @State private var lastDragTranslation: CGSize = .zero

    private enum Palette {
        static let paneBackground = Color(hex: 0x090A0C)
        static let sphereFill = Color(hex: 0x11151A)
        static let land = Color(hex: 0x283039)
        static let graticule = Color(hex: 0x7D8791)
        static let outline = Color(hex: 0x9099A3)
        static let stationDot = Color(hex: 0xD9DEE3)
        static let countryHighlight = Color(hex: 0x7C7CA8)
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !interaction.isCoasting)) { timeline in
                Canvas { context, canvasSize in
                    draw(context: &context, size: canvasSize)
                }
                .onChange(of: timeline.date) { _ in
                    // The two-parameter onChange(of:initial:_:) overload requires macOS 14;
                    // this package targets macOS 13, so the single-parameter form is used.
                    interaction.tickCoast(dt: 1.0 / 60.0)
                }
            }
            .background(Palette.paneBackground)
            .background(
                ScrollWheelCapture { deltaY in
                    // Scroll up (negative deltaY in AppKit's convention) zooms in.
                    interaction.applyZoom(delta: -deltaY * 0.02 * interaction.scale)
                }
            )
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        let deltaX = value.translation.width - lastDragTranslation.width
                        let deltaY = value.translation.height - lastDragTranslation.height
                        interaction.applyDrag(deltaX: deltaX, deltaY: deltaY)
                        lastDragTranslation = value.translation
                    }
                    .onEnded { _ in
                        interaction.endDrag()
                        lastDragTranslation = .zero
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        let delta = (value - lastMagnification) * interaction.scale
                        interaction.applyZoom(delta: delta)
                        lastMagnification = value
                    }
                    .onEnded { _ in
                        lastMagnification = 1
                    }
            )
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        handleTap(at: value.location, in: size)
                    }
            )
        }
    }

    // MagnificationGesture's onChanged/onEnded closures can't capture a
    // @State var by reference across a struct's `body` re-evaluation the way a
    // class would, so this is tracked the same way `lastDragTranslation` is.
    @State private var lastMagnification: CGFloat = 1

    // MARK: - Drawing

    private func draw(context: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let viewRadius = min(size.width, size.height) * 0.44
        let sphereRadius = viewRadius * interaction.scale

        context.fill(Path(ellipseIn: CGRect(x: center.x - sphereRadius, y: center.y - sphereRadius, width: sphereRadius * 2, height: sphereRadius * 2)), with: .color(Palette.sphereFill))

        drawGraticule(context: &context, center: center, viewRadius: viewRadius)
        drawRegions(regions, context: &context, center: center, viewRadius: viewRadius, color: Palette.land, opacity: 1)

        if let activeCountryCode {
            let highlighted = regions.filter { $0.isoCode == activeCountryCode }
            drawRegions(highlighted, context: &context, center: center, viewRadius: viewRadius, color: Palette.countryHighlight, opacity: 0.3)
        }

        context.stroke(Path(ellipseIn: CGRect(x: center.x - sphereRadius, y: center.y - sphereRadius, width: sphereRadius * 2, height: sphereRadius * 2)), with: .color(Palette.outline), lineWidth: 1)

        drawStations(context: &context, center: center, viewRadius: viewRadius)
    }

    private func drawGraticule(context: inout GraphicsContext, center: CGPoint, viewRadius: Double) {
        var path = Path()
        // Latitude lines every 20 degrees, sampled across all longitudes.
        for lat in stride(from: -80.0, through: 80.0, by: 20.0) {
            appendGraticuleLine(
                &path,
                points: stride(from: -180.0, through: 180.0, by: 4.0).map { GeoPoint(latitude: lat, longitude: $0) },
                center: center, viewRadius: viewRadius
            )
        }
        // Longitude lines every 20 degrees, sampled pole-to-pole.
        for lon in stride(from: -180.0, to: 180.0, by: 20.0) {
            appendGraticuleLine(
                &path,
                points: stride(from: -90.0, through: 90.0, by: 4.0).map { GeoPoint(latitude: $0, longitude: lon) },
                center: center, viewRadius: viewRadius
            )
        }
        context.stroke(path, with: .color(Palette.graticule.opacity(0.35)), lineWidth: 0.5)
    }

    private func appendGraticuleLine(_ path: inout Path, points: [GeoPoint], center: CGPoint, viewRadius: Double) {
        var isDrawing = false
        for geoPoint in points {
            let projected = GlobeProjection.project(
                geoPoint, centerLatitude: interaction.centerLatitude, centerLongitude: interaction.centerLongitude,
                scale: interaction.scale, viewRadius: viewRadius
            )
            let screenPoint = CGPoint(x: center.x + projected.point.x, y: center.y + projected.point.y)
            if projected.isFrontFacing {
                if isDrawing {
                    path.addLine(to: screenPoint)
                } else {
                    path.move(to: screenPoint)
                    isDrawing = true
                }
            } else {
                isDrawing = false
            }
        }
    }

    private func drawRegions(_ regions: [CountryRegion], context: inout GraphicsContext, center: CGPoint, viewRadius: Double, color: Color, opacity: Double) {
        var path = Path()
        for region in regions {
            for ring in region.rings {
                guard ring.count >= 3 else { continue }
                let projected = ring.map { geoPoint in
                    GlobeProjection.project(
                        geoPoint, centerLatitude: interaction.centerLatitude, centerLongitude: interaction.centerLongitude,
                        scale: interaction.scale, viewRadius: viewRadius
                    )
                }
                let frontFacingCount = projected.filter(\.isFrontFacing).count
                guard Double(frontFacingCount) / Double(projected.count) >= 0.5 else { continue }

                // A ring straddling the horizon is approximated by connecting only
                // its front-facing points with straight lines (see plan Step 8.3) —
                // exact horizon clipping isn't required to read correctly at a glance.
                var ringPath = Path()
                var started = false
                for entry in projected where entry.isFrontFacing {
                    let screenPoint = CGPoint(x: center.x + entry.point.x, y: center.y + entry.point.y)
                    if started {
                        ringPath.addLine(to: screenPoint)
                    } else {
                        ringPath.move(to: screenPoint)
                        started = true
                    }
                }
                ringPath.closeSubpath()
                path.addPath(ringPath)
            }
        }
        context.fill(path, with: .color(color.opacity(opacity)))
    }

    private func drawStations(context: inout GraphicsContext, center: CGPoint, viewRadius: Double) {
        let dotRadius: Double = 2
        for station in stations {
            guard let latitude = station.latitude, let longitude = station.longitude else { continue }
            let projected = GlobeProjection.project(
                GeoPoint(latitude: latitude, longitude: longitude),
                centerLatitude: interaction.centerLatitude, centerLongitude: interaction.centerLongitude,
                scale: interaction.scale, viewRadius: viewRadius
            )
            guard projected.isFrontFacing else { continue }
            let screenPoint = CGPoint(x: center.x + projected.point.x, y: center.y + projected.point.y)
            let dotRect = CGRect(x: screenPoint.x - dotRadius, y: screenPoint.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
            context.fill(Path(ellipseIn: dotRect), with: .color(Palette.stationDot))
        }
    }

    // MARK: - Hit testing

    private func handleTap(at tapPoint: CGPoint, in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let viewRadius = min(size.width, size.height) * 0.44
        let relative = CGPoint(x: tapPoint.x - center.x, y: tapPoint.y - center.y)
        let hitRadius: CGFloat = 8

        var nearestStation: Station?
        var nearestDistance: CGFloat = .infinity
        for station in stations {
            guard let latitude = station.latitude, let longitude = station.longitude else { continue }
            let projected = GlobeProjection.project(
                GeoPoint(latitude: latitude, longitude: longitude),
                centerLatitude: interaction.centerLatitude, centerLongitude: interaction.centerLongitude,
                scale: interaction.scale, viewRadius: viewRadius
            )
            guard projected.isFrontFacing else { continue }
            let dx = projected.point.x - relative.x
            let dy = projected.point.y - relative.y
            let distance = (dx * dx + dy * dy).squareRoot()
            if distance <= hitRadius && distance < nearestDistance {
                nearestDistance = distance
                nearestStation = station
            }
        }

        if let nearestStation {
            onStationTapped(nearestStation)
            return
        }

        guard let geoPoint = GlobeProjection.unproject(
            relative, centerLatitude: interaction.centerLatitude, centerLongitude: interaction.centerLongitude,
            scale: interaction.scale, viewRadius: viewRadius
        ) else {
            return // Tapped off the sphere entirely.
        }

        if let isoCode = countryLookup.countryCode(at: geoPoint) {
            onCountryTapped(isoCode)
        }
        // Otherwise: open ocean — do nothing, per spec.
    }
}

private extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

/// SwiftUI has no first-class scroll-wheel gesture for an arbitrary view (only
/// `ScrollView` content participates in scroll events); this transparent
/// `NSViewRepresentable` overlay captures `scrollWheel(with:)` directly, per
/// the plan's documented fallback.
private struct ScrollWheelCapture: NSViewRepresentable {
    let onScroll: (Double) -> Void

    func makeNSView(context: Context) -> ScrollCaptureView {
        let view = ScrollCaptureView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: ScrollCaptureView, context: Context) {
        nsView.onScroll = onScroll
    }

    final class ScrollCaptureView: NSView {
        var onScroll: ((Double) -> Void)?

        override func scrollWheel(with event: NSEvent) {
            onScroll?(Double(event.scrollingDeltaY))
        }
    }
}
