import Foundation

public enum SphereMath {
    public static func point(radius: Double, latitude: Double, longitude: Double) -> (x: Double, y: Double, z: Double) {
        let latRad = latitude * .pi / 180
        let lonRad = longitude * .pi / 180
        let x = radius * cos(latRad) * cos(lonRad)
        let y = radius * sin(latRad)
        let z = -radius * cos(latRad) * sin(lonRad)
        return (x, y, z)
    }
}
