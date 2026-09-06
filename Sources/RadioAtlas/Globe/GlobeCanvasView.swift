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
    /// Country of the currently playing station — drawn as its own, stronger
    /// highlight distinct from the browse highlight above.
    let playingCountryCode: String?
    /// The playing station itself, used only as a fallback rotation target
    /// when its country has no region geometry to center on.
    let playingStation: Station?
    /// Live aurora activity (nil while the feed is unavailable — bands fall
    /// back to the static look).
    let auroraActivity: AuroraActivity?
    let onStationTapped: (Station) -> Void
    let onCountryTapped: (String) -> Void

    @StateObject private var interaction = GlobeInteractionState()
    @State private var lastDragTranslation: CGSize = .zero
    // Aurora animation state: `phase` advances while the view is on screen
    // and drives the bands' drift; `lastTimelineDate` turns timeline ticks
    // into real elapsed seconds.
    @State private var auroraPhase: Double = 0
    @State private var lastTimelineDate: Date?
    // Per-pole band geometry, eased toward the live-data target every tick
    // so a refresh changes the bands smoothly instead of jumping.
    @State private var smoothedNorthConfig = AuroraBandConfig.fallback
    @State private var smoothedSouthConfig = AuroraBandConfig.fallback
    // Sunburst rotation phase (radians) — advanced every tick; also drives
    // the twinkle and flare envelopes via `SparkleMath`.
    @State private var sparklePhase: Double = 0

    private enum Palette {
        static let paneBackground = Color(hex: 0x090A0C)
        static let sphereFill = Color(hex: 0x11151A)
        static let land = Color(hex: 0x283039)
        static let graticule = Color(hex: 0x7D8791)
        static let outline = Color(hex: 0x9099A3)
        static let stationDot = Color(hex: 0xD9DEE3)
        static let countryHighlight = Color(hex: 0x7C7CA8)
        // Same gold as the app's favorite-star color language: "active".
        static let playingCountryHighlight = Color(hex: 0xF2C94C)
        static let auroraInner = Color(hex: 0x63E6A0) // green
        static let auroraOuter = Color(hex: 0x53D8C8) // teal
    }

    /// Aurora animation constants. Band geometry (edges/amplitude/opacity)
    /// comes from `AuroraBandConfig`, derived from live data.
    private enum Aurora {
        static let waveCount = 3.0
        static let samples = 72
        /// Radians per second of phase drift — a slow, gentle curtain sway.
        static let driftSpeed = 0.15
        static let blurRadius = 6.0
        /// Seconds over which the bands ease toward freshly fetched data.
        static let settleTime = 30.0
    }

    /// Country-border sparkle constants. The twinkle/flare math itself lives
    /// in `SparkleMath` (Core, tested).
    private enum Sparkle {
        /// Radians per second of the animation phase's advance — sets the
        /// cadence the flare, glow pulse, and glints all derive from.
        static let rotationSpeed = 0.25
        /// Flare pulses this many times faster than the base phase — a
        /// bright border flash lands roughly every 8 s.
        static let flareSpeedMultiplier = 3.0
        /// Glints pop at this multiple of the base phase.
        static let glintSpeedMultiplier = 1.4
        static let glowBlurRadius = 4.0
        /// Glints below this visibility are skipped entirely (mostly-off
        /// sparkle: sharp pops, not a constant shimmer).
        static let glintVisibilityThreshold = 0.05
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            // The aurora shimmer means the timeline never pauses: idle
            // redraws run at a reduced 15 fps (full 60 fps only while the
            // user drags/rotates), keeping the always-on animation light.
            TimelineView(.animation(
                minimumInterval: interaction.isCoasting || interaction.isAutoRotating ? 1.0 / 60.0 : 1.0 / 15.0,
                paused: false
            )) { timeline in
                Canvas { context, canvasSize in
                    draw(context: &context, size: canvasSize, auroraPhase: auroraPhase)
                }
                .onChange(of: timeline.date) { date in
                    // The two-parameter onChange(of:initial:_:) overload requires macOS 14;
                    // this package targets macOS 13, so the single-parameter form is used.
                    let dt = lastTimelineDate.map { date.timeIntervalSince($0) } ?? 0
                    lastTimelineDate = date
                    interaction.tickCoast(dt: dt)
                    interaction.tickAutoRotation()
                    auroraPhase = (auroraPhase + dt * Aurora.driftSpeed)
                        .truncatingRemainder(dividingBy: 2 * .pi)
                    sparklePhase += dt * Sparkle.rotationSpeed

                    // Ease the per-pole band geometry toward the live-data
                    // target over `settleTime` seconds.
                    let blend = min(1, dt / Aurora.settleTime)
                    smoothedNorthConfig = smoothedNorthConfig.mixed(
                        with: AuroraBandConfig.resolve(activity: auroraActivity?.north),
                        factor: blend
                    )
                    smoothedSouthConfig = smoothedSouthConfig.mixed(
                        with: AuroraBandConfig.resolve(activity: auroraActivity?.south),
                        factor: blend
                    )
                }
            }
            .onChange(of: playingCountryCode) { newCode in
                guard let newCode else { return }
                var target: GeoPoint?
                if let region = regions.first(where: { $0.isoCode == newCode }) {
                    target = RegionCentroid.centroid(of: region)
                }
                if target == nil, let station = playingStation,
                   let latitude = station.latitude, let longitude = station.longitude {
                    target = GeoPoint(latitude: latitude, longitude: longitude)
                }
                guard let target else { return }
                interaction.animateCenter(toLatitude: target.latitude, longitude: target.longitude)
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

    private func draw(context: inout GraphicsContext, size: CGSize, auroraPhase: Double) {
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

        // The playing country gets its own stronger highlight on top of the
        // browse highlight, so "listening to Brazil while browsing France"
        // shows both distinctly (and one strong fill when they coincide).
        if let playingCountryCode {
            let playing = regions.filter { $0.isoCode == playingCountryCode }
            let path = drawRegions(playing, context: &context, center: center, viewRadius: viewRadius, color: Palette.playingCountryHighlight, opacity: 0.55)
            context.stroke(path, with: .color(Palette.playingCountryHighlight), lineWidth: 1)
        }

        // Atmospheric layer: drawn above land but below the sphere outline
        // and station dots, so signals stay readable through the glow.
        drawAurora(context: &context, center: center, viewRadius: viewRadius, phase: auroraPhase)

        // The playing country's glowing, sparkling border — above the
        // aurora, below the crisp sphere outline and station dots.
        if let playingCountryCode {
            drawCountrySparkle(
                context: &context, center: center, viewRadius: viewRadius,
                phase: sparklePhase, countryCode: playingCountryCode
            )
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

    /// Fills the regions and returns the drawn path so callers can add a
    /// stroke on top (the playing-country highlight does).
    @discardableResult
    private func drawRegions(_ regions: [CountryRegion], context: inout GraphicsContext, center: CGPoint, viewRadius: Double, color: Color, opacity: Double) -> Path {
        var path = Path()
        for region in regions {
            path.addPath(regionPath(region, center: center, viewRadius: viewRadius))
        }
        context.fill(path, with: .color(color.opacity(opacity)))
        return path
    }

    /// A single region's screen path, each ring projected with the same
    /// horizon approximation the fills use.
    private func regionPath(_ region: CountryRegion, center: CGPoint, viewRadius: Double) -> Path {
        var path = Path()
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
        return path
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

    // MARK: - Aurora

    /// Two drifting bands (green core, teal fringe) around each pole, sized
    /// and brightened by that pole's live-data config; the far pole's bands
    /// are culled by the front-facing check like land regions.
    private func drawAurora(context: inout GraphicsContext, center: CGPoint, viewRadius: Double, phase: Double) {
        drawAuroraBand(
            pole: .north, config: smoothedNorthConfig, color: Palette.auroraInner,
            phase: phase, context: &context, center: center, viewRadius: viewRadius
        )
        drawAuroraBand(
            pole: .north, config: smoothedNorthConfig, color: Palette.auroraOuter,
            // Offset phase so the two bands sway out of sync.
            phase: phase + 1.2, context: &context, center: center, viewRadius: viewRadius
        )
        drawAuroraBand(
            pole: .south, config: smoothedSouthConfig, color: Palette.auroraInner,
            phase: phase, context: &context, center: center, viewRadius: viewRadius
        )
        drawAuroraBand(
            pole: .south, config: smoothedSouthConfig, color: Palette.auroraOuter,
            phase: phase + 1.2, context: &context, center: center, viewRadius: viewRadius
        )
    }

    private func drawAuroraBand(
        pole: AuroraPole,
        config: AuroraBandConfig,
        color: Color,
        phase: Double,
        context: inout GraphicsContext,
        center: CGPoint,
        viewRadius: Double
    ) {
        let inner = AuroraGeometry.wavyRing(
            pole: pole, base: config.innerBand.inner, amplitude: config.amplitude,
            waveCount: Aurora.waveCount, phase: phase, samples: Aurora.samples
        )
        let outer = AuroraGeometry.wavyRing(
            pole: pole, base: config.outerBand.outer, amplitude: config.amplitude,
            waveCount: Aurora.waveCount, phase: phase, samples: Aurora.samples
        )
        let path = bandPath(outerRing: outer, innerRing: inner, center: center, viewRadius: viewRadius)
        guard !path.isEmpty else { return }

        // Soft glow underneath a crisper fill — the glow layer's filters are
        // scoped to `drawLayer` so the outline/dots drawn later stay sharp.
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: Aurora.blurRadius))
            layer.fill(path, with: .color(color.opacity(0.32 * config.opacityMultiplier)))
        }
        context.fill(path, with: .color(color.opacity(0.16 * config.opacityMultiplier)))
    }

    // MARK: - Country sparkle

    /// The playing country's boundaries glow and sparkle: a soft blurred
    /// stroke that breathes with the flare pulse, plus small gold glints
    /// popping in and out along the outline, each on its own hash-derived
    /// rhythm — mostly off, sharp pops, so the border shimmers rather than
    /// staying lit.
    private func drawCountrySparkle(
        context: inout GraphicsContext,
        center: CGPoint,
        viewRadius: Double,
        phase: Double,
        countryCode: String
    ) {
        guard let region = regions.first(where: { $0.isoCode == countryCode }) else { return }
        let path = regionPath(region, center: center, viewRadius: viewRadius)
        guard !path.isEmpty else { return }

        let flare = SparkleMath.flareEnvelope(phase: phase * Sparkle.flareSpeedMultiplier)

        // Border glow: a wide blurred stroke underneath the crisp stroke the
        // highlight already draws, brightening with each flash.
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: Sparkle.glowBlurRadius))
            layer.stroke(
                path,
                with: .color(Palette.playingCountryHighlight.opacity(0.30 + 0.40 * flare)),
                lineWidth: 3
            )
        }

        // Glints: tiny crosses at ring points whose hash-scheduled pop is
        // currently visible.
        var pointIndex = 0
        for ring in region.rings {
            for geoPoint in ring {
                defer { pointIndex += 1 }
                let projected = GlobeProjection.project(
                    geoPoint,
                    centerLatitude: interaction.centerLatitude, centerLongitude: interaction.centerLongitude,
                    scale: interaction.scale, viewRadius: viewRadius
                )
                guard projected.isFrontFacing else { continue }

                let glint = SparkleMath.flareEnvelope(
                    phase: phase * Sparkle.glintSpeedMultiplier + SparkleMath.hash(pointIndex) * 2 * .pi
                )
                guard glint > Sparkle.glintVisibilityThreshold else { continue }

                let point = CGPoint(x: center.x + projected.point.x, y: center.y + projected.point.y)
                let size = 1.2 + 2.2 * glint
                var cross = Path()
                cross.move(to: CGPoint(x: point.x - size, y: point.y))
                cross.addLine(to: CGPoint(x: point.x + size, y: point.y))
                cross.move(to: CGPoint(x: point.x, y: point.y - size))
                cross.addLine(to: CGPoint(x: point.x, y: point.y + size))
                context.stroke(
                    cross,
                    with: .color(Palette.playingCountryHighlight.opacity(min(1, 0.35 + 0.65 * glint))),
                    lineWidth: 1
                )
            }
        }
    }

    /// Builds the filled polygon between the two wavy rings: outer edge
    /// front-facing points forward, inner edge reversed, then closed. Same
    /// horizon approximation as country rings (see `drawRegions`).
    private func bandPath(outerRing: [GeoPoint], innerRing: [GeoPoint], center: CGPoint, viewRadius: Double) -> Path {
        func projected(_ ring: [GeoPoint]) -> [(point: CGPoint, isFrontFacing: Bool)] {
            ring.map { geoPoint in
                let entry = GlobeProjection.project(
                    geoPoint,
                    centerLatitude: interaction.centerLatitude, centerLongitude: interaction.centerLongitude,
                    scale: interaction.scale, viewRadius: viewRadius
                )
                return (CGPoint(x: center.x + entry.point.x, y: center.y + entry.point.y), entry.isFrontFacing)
            }
        }

        let outer = projected(outerRing)
        let inner = projected(innerRing)

        func frontRatio(_ ring: [(point: CGPoint, isFrontFacing: Bool)]) -> Double {
            guard !ring.isEmpty else { return 0 }
            return Double(ring.filter(\.isFrontFacing).count) / Double(ring.count)
        }
        guard frontRatio(outer) >= 0.5, frontRatio(inner) >= 0.5 else { return Path() }

        var path = Path()
        for entry in outer where entry.isFrontFacing {
            if path.isEmpty {
                path.move(to: entry.point)
            } else {
                path.addLine(to: entry.point)
            }
        }
        // `outer` has ≥50% front-facing points, so the path has started.
        for entry in inner.reversed() where entry.isFrontFacing {
            path.addLine(to: entry.point)
        }
        path.closeSubpath()
        return path
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
