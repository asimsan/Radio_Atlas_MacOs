public enum StationFilter {
    public static func filter(_ stations: [Station], query: String) -> [Station] {
        guard !query.isEmpty else { return stations }
        let lowered = query.lowercased()
        return stations.filter { $0.name.lowercased().contains(lowered) }
    }
}
