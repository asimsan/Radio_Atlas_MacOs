import Foundation

/// The country a search query unambiguously names.
public struct CountryMatch: Equatable {
    public let isoCode: String
    public let name: String
}

/// Decides whether a search query names a country, so the UI can switch from
/// local filtering to a full country browse. Country *names* come from station
/// data (the same strings the sidebar displays — the bundled GeoJSON carries
/// only ISO codes, and the Radio Browser API's own spellings are what users
/// see and type); ISO *codes* are checked against the region codes the globe
/// can actually render.
public enum CountryMatcher {
    /// Match priority: exact full-name match, then ISO code, then a prefix
    /// that names exactly one country. Ambiguous or non-country queries
    /// return nil.
    public static func match(_ query: String, stations: [Station], regionCodes: Set<String>) -> CountryMatch? {
        let normalized = normalize(query)
        guard !normalized.isEmpty else { return nil }

        // Normalized country name -> uppercase ISO codes seen for it.
        var nameToCodes: [String: Set<String>] = [:]
        // Uppercase ISO code -> the display name stations use for it.
        var codeToName: [String: String] = [:]
        for station in stations {
            let name = normalize(station.country)
            guard !name.isEmpty else { continue }
            let code = station.countryCode.uppercased()
            nameToCodes[name, default: []].insert(code)
            codeToName[code] = station.country
        }

        // 1. Exact full-name match.
        if let code = pickCode(forName: normalized, in: nameToCodes, regionCodes: regionCodes) {
            return CountryMatch(isoCode: code, name: codeToName[code] ?? normalized)
        }

        // 2. ISO code.
        let codeQuery = normalized.uppercased()
        if regionCodes.contains(codeQuery) {
            return CountryMatch(isoCode: codeQuery, name: codeToName[codeQuery] ?? codeQuery)
        }

        // 3. Unique prefix match.
        let prefixed = nameToCodes.keys.filter { $0.hasPrefix(normalized) }
        if prefixed.count == 1, let code = pickCode(forName: prefixed[0], in: nameToCodes, regionCodes: regionCodes) {
            return CountryMatch(isoCode: code, name: codeToName[code] ?? prefixed[0])
        }

        return nil
    }

    /// Lowercases, trims, and collapses internal whitespace.
    static func normalize(_ string: String) -> String {
        string.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// A name is ambiguous if station data maps it to several codes; when it
    /// is, prefer the code the globe can render, then fall back to a
    /// deterministic first.
    private static func pickCode(forName name: String, in nameToCodes: [String: Set<String>], regionCodes: Set<String>) -> String? {
        guard let codes = nameToCodes[name], !codes.isEmpty else { return nil }
        if let renderable = codes.filter({ regionCodes.contains($0) }).sorted().first { return renderable }
        return codes.sorted().first
    }
}
