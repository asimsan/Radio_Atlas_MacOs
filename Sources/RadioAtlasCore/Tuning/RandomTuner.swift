public struct RandomTuner {
    public init() {}

    public func pickStation(from stations: [Station], avoiding recentIDs: Set<String>) -> Station? {
        let candidates = stations.filter { !recentIDs.contains($0.id) }
        let pool = candidates.isEmpty ? stations : candidates
        return pool.randomElement()
    }
}
