public enum StationFilter {
    /// Matches `query` against a station's name, country (code and full
    /// name), and tags — the search field's placeholder advertises "Search
    /// station, country, or genre", so all three must be searchable, not
    /// just the name.
    public static func filter(_ stations: [Station], query: String) -> [Station] {
        guard !query.isEmpty else { return stations }
        let lowered = query.lowercased()
        return stations.filter { station in
            if station.name.lowercased().contains(lowered) { return true }
            if station.countryCode.lowercased().contains(lowered) { return true }
            if station.country.lowercased().contains(lowered) { return true }
            if station.tags.contains(where: { $0.lowercased().contains(lowered) }) { return true }
            return false
        }
    }
}
