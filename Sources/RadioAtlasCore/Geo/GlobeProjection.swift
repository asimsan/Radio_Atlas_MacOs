import Foundation
import CoreGraphics

public enum GlobeProjection {
    public static func project(
        _ point: GeoPoint,
        centerLatitude: Double,
        centerLongitude: Double,
        scale: Double,
        viewRadius: Double
    ) -> (point: CGPoint, isFrontFacing: Bool) {
        let radius = viewRadius * scale
        let lat = point.latitude * .pi / 180
        let lat0 = centerLatitude * .pi / 180
        let deltaLon = (point.longitude - centerLongitude) * .pi / 180

        let cosC = sin(lat0) * sin(lat) + cos(lat0) * cos(lat) * cos(deltaLon)
        let x = radius * cos(lat) * sin(deltaLon)
        let y = radius * (cos(lat0) * sin(lat) - sin(lat0) * cos(lat) * cos(deltaLon))

        return (CGPoint(x: x, y: -y), cosC > 0)
    }

    public static func unproject(
        _ screenPoint: CGPoint,
        centerLatitude: Double,
        centerLongitude: Double,
        scale: Double,
        viewRadius: Double
    ) -> GeoPoint? {
        let radius = viewRadius * scale
        let x = Double(screenPoint.x)
        let y = -Double(screenPoint.y)
        let rho = (x * x + y * y).squareRoot()
        if rho > radius { return nil }
        if rho < 1e-9 {
            return GeoPoint(latitude: centerLatitude, longitude: centerLongitude)
        }

        let c = asin(rho / radius)
        let lat0 = centerLatitude * .pi / 180
        let lat = asin(cos(c) * sin(lat0) + (y * sin(c) * cos(lat0)) / rho)
        // BUG FIX: `centerLongitude` is already in degrees (it's the function's own
        // degrees-valued parameter), but the brief's reference code multiplied it by
        // `180 / .pi` as though it were radians needing conversion — that treats a
        // longitude of e.g. 20° as if it were 20 radians, producing nonsense results
        // like 1150.9° instead of ~25°. Only the atan2 term (computed in radians) needs
        // that conversion; centerLongitude itself is added directly.
        let lon = centerLongitude
            + atan2(x * sin(c), rho * cos(lat0) * cos(c) - y * sin(lat0) * sin(c)) * 180 / .pi

        return GeoPoint(latitude: lat * 180 / .pi, longitude: lon)
    }
}
