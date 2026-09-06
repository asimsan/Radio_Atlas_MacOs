import Foundation

/// Maps a station's country code — and, for wide countries, its longitude —
/// to a `TimeZone`, so the globe can show the *station's* local time rather
/// than the user's.
public enum CountryTimeZones {
    /// One representative IANA zone per single-zone country, including the
    /// half- and quarter-hour-offset countries.
    private static let singleZone: [String: String] = [
        // Europe
        "AD": "Europe/Andorra", "AL": "Europe/Tirane", "AT": "Europe/Vienna",
        "BA": "Europe/Sarajevo", "BE": "Europe/Brussels", "BG": "Europe/Sofia",
        "BY": "Europe/Minsk", "CH": "Europe/Zurich", "CY": "Asia/Nicosia",
        "CZ": "Europe/Prague", "DE": "Europe/Berlin", "DK": "Europe/Copenhagen",
        "EE": "Europe/Tallinn", "ES": "Europe/Madrid", "FI": "Europe/Helsinki",
        "FR": "Europe/Paris", "GB": "Europe/London", "GR": "Europe/Athens",
        "HR": "Europe/Zagreb", "HU": "Europe/Budapest", "IE": "Europe/Dublin",
        "IS": "Atlantic/Reykjavik", "IT": "Europe/Rome", "LI": "Europe/Vaduz",
        "LT": "Europe/Vilnius", "LU": "Europe/Luxembourg", "LV": "Europe/Riga",
        "MC": "Europe/Monaco", "MD": "Europe/Chisinau", "ME": "Europe/Podgorica",
        "MK": "Europe/Skopje", "MT": "Europe/Malta", "NL": "Europe/Amsterdam",
        "NO": "Europe/Oslo", "PL": "Europe/Warsaw", "PT": "Europe/Lisbon",
        "RO": "Europe/Bucharest", "RS": "Europe/Belgrade", "SE": "Europe/Stockholm",
        "SI": "Europe/Ljubljana", "SK": "Europe/Bratislava", "SM": "Europe/San_Marino",
        "TR": "Europe/Istanbul", "UA": "Europe/Kyiv", "VA": "Europe/Vatican",
        "XK": "Europe/Belgrade",
        // Asia
        "AE": "Asia/Dubai", "AF": "Asia/Kabul", "AM": "Asia/Yerevan",
        "AZ": "Asia/Baku", "BD": "Asia/Dhaka", "BH": "Asia/Bahrain",
        "BN": "Asia/Brunei", "BT": "Asia/Thimphu", "CN": "Asia/Shanghai",
        "GE": "Asia/Tbilisi", "HK": "Asia/Hong_Kong", "IL": "Asia/Jerusalem",
        "IN": "Asia/Kolkata", "IQ": "Asia/Baghdad", "IR": "Asia/Tehran",
        "JO": "Asia/Amman", "JP": "Asia/Tokyo", "KG": "Asia/Bishkek",
        "KH": "Asia/Phnom_Penh", "KP": "Asia/Pyongyang", "KR": "Asia/Seoul",
        "KW": "Asia/Kuwait", "LA": "Asia/Vientiane", "LB": "Asia/Beirut",
        "LK": "Asia/Colombo", "MM": "Asia/Yangon", "MN": "Asia/Ulaanbaatar",
        "MO": "Asia/Macau", "MV": "Indian/Maldives", "MY": "Asia/Kuala_Lumpur",
        "NP": "Asia/Kathmandu", "OM": "Asia/Muscat", "PH": "Asia/Manila",
        "PK": "Asia/Karachi", "PS": "Asia/Gaza", "QA": "Asia/Qatar",
        "SA": "Asia/Riyadh", "SG": "Asia/Singapore", "SY": "Asia/Damascus",
        "TH": "Asia/Bangkok", "TJ": "Asia/Dushanbe", "TL": "Asia/Dili",
        "TM": "Asia/Ashgabat", "TW": "Asia/Taipei", "UZ": "Asia/Tashkent",
        "VN": "Asia/Ho_Chi_Minh", "YE": "Asia/Aden",
        // Africa
        "AO": "Africa/Luanda", "BF": "Africa/Ouagadougou", "BI": "Africa/Bujumbura",
        "BJ": "Africa/Porto-Novo", "BW": "Africa/Gaborone", "CD": "Africa/Kinshasa",
        "CF": "Africa/Bangui", "CG": "Africa/Brazzaville", "CI": "Africa/Abidjan",
        "CM": "Africa/Douala", "CV": "Atlantic/Cape_Verde", "DJ": "Africa/Djibouti",
        "DZ": "Africa/Algiers", "EG": "Africa/Cairo", "ER": "Africa/Asmara",
        "ET": "Africa/Addis_Ababa", "GA": "Africa/Libreville", "GH": "Africa/Accra",
        "GM": "Africa/Banjul", "GN": "Africa/Conakry", "GQ": "Africa/Malabo",
        "GW": "Africa/Bissau", "KE": "Africa/Nairobi", "KM": "Indian/Comoro",
        "LR": "Africa/Monrovia", "LS": "Africa/Maseru", "LY": "Africa/Tripoli",
        "MA": "Africa/Casablanca", "MG": "Indian/Antananarivo", "ML": "Africa/Bamako",
        "MR": "Africa/Nouakchott", "MU": "Indian/Mauritius", "MW": "Africa/Blantyre",
        "MZ": "Africa/Maputo", "NA": "Africa/Windhoek", "NE": "Africa/Niamey",
        "NG": "Africa/Lagos", "RW": "Africa/Kigali", "SC": "Indian/Mahe",
        "SD": "Africa/Khartoum", "SL": "Africa/Freetown", "SN": "Africa/Dakar",
        "SO": "Africa/Mogadishu", "SS": "Africa/Juba", "ST": "Africa/Sao_Tome",
        "SZ": "Africa/Mbabane", "TD": "Africa/Ndjamena", "TG": "Africa/Lome",
        "TN": "Africa/Tunis", "TZ": "Africa/Dar_es_Salaam", "UG": "Africa/Kampala",
        "ZA": "Africa/Johannesburg", "ZM": "Africa/Lusaka", "ZW": "Africa/Harare",
        // Americas
        "AG": "America/Antigua", "AR": "America/Argentina/Buenos_Aires",
        "AW": "America/Aruba", "BB": "America/Barbados", "BO": "America/La_Paz",
        "BS": "America/Nassau", "BZ": "America/Belize", "CL": "America/Santiago",
        "CO": "America/Bogota", "CR": "America/Costa_Rica", "CU": "America/Havana",
        "DO": "America/Santo_Domingo", "EC": "America/Guayaquil",
        "GD": "America/Grenada", "GT": "America/Guatemala", "GY": "America/Guyana",
        "HN": "America/Tegucigalpa", "HT": "America/Port-au-Prince",
        "JM": "America/Jamaica", "KN": "America/St_Kitts", "LC": "America/St_Lucia",
        "NI": "America/Managua", "PA": "America/Panama", "PE": "America/Lima",
        "PR": "America/Puerto_Rico", "PY": "America/Asuncion", "SR": "America/Paramaribo",
        "SV": "America/El_Salvador", "TT": "America/Port_of_Spain",
        "UY": "America/Montevideo", "VC": "America/St_Vincent", "VE": "America/Caracas",
        // Oceania
        "CK": "Pacific/Rarotonga", "FJ": "Pacific/Fiji", "FM": "Pacific/Chuuk",
        "KI": "Pacific/Tarawa", "MH": "Pacific/Majuro", "NC": "Pacific/Noumea",
        "NR": "Pacific/Nauru", "NU": "Pacific/Niue", "NZ": "Pacific/Auckland",
        "PF": "Pacific/Tahiti", "PG": "Pacific/Port_Moresby", "PW": "Pacific/Palau",
        "SB": "Pacific/Guadalcanal", "TO": "Pacific/Tongatapu", "TV": "Pacific/Funafuti",
        "VU": "Pacific/Efate", "WS": "Pacific/Apia",
    ]

    /// Multi-zone countries: (westmost longitude of the zone, IANA id),
    /// sorted ascending. The zone whose westmost longitude is the greatest
    /// one ≤ the station's longitude wins.
    private static let multiZone: [String: [(westmostLongitude: Double, zoneID: String)]] = [
        "US": [
            (-180, "Pacific/Honolulu"), (-165, "America/Anchorage"),
            (-125, "America/Los_Angeles"), (-105, "America/Denver"),
            (-90, "America/Chicago"), (-75, "America/New_York"),
        ],
        "CA": [
            (-180, "America/Vancouver"), (-100, "America/Winnipeg"),
            (-90, "America/Toronto"), (-60, "America/Halifax"),
            (-55, "America/St_Johns"),
        ],
        "RU": [
            (20, "Europe/Kaliningrad"), (35, "Europe/Moscow"), (50, "Europe/Samara"),
            (55, "Asia/Yekaterinburg"), (70, "Asia/Omsk"), (85, "Asia/Krasnoyarsk"),
            (95, "Asia/Irkutsk"), (105, "Asia/Yakutsk"), (125, "Asia/Vladivostok"),
            (135, "Asia/Magadan"), (150, "Asia/Kamchatka"),
        ],
        "AU": [
            (110, "Australia/Perth"), (128, "Australia/Darwin"),
            (133, "Australia/Adelaide"), (140, "Australia/Brisbane"),
            (145, "Australia/Sydney"),
        ],
        "BR": [
            (-75, "America/Rio_Branco"), (-65, "America/Manaus"),
            (-55, "America/Sao_Paulo"), (-35, "America/Noronha"),
        ],
        "MX": [
            (-120, "America/Tijuana"), (-110, "America/Mazatlan"),
            (-100, "America/Mexico_City"), (-90, "America/Cancun"),
        ],
        "ID": [
            (95, "Asia/Jakarta"), (115, "Asia/Makassar"), (125, "Asia/Jayapura"),
        ],
    ]

    /// The station's timezone: country mapping first, then a longitude-based
    /// fixed-offset approximation for unknown countries; nil when neither the
    /// country nor a longitude is known.
    public static func timeZone(countryCode: String, longitude: Double?) -> TimeZone? {
        let code = countryCode.uppercased()
        if let zoneID = singleZone[code] {
            return TimeZone(identifier: zoneID)
        }
        if let zones = multiZone[code], !zones.isEmpty {
            if let longitude {
                let candidates = zones.filter { $0.westmostLongitude <= longitude }
                if let zoneID = candidates.last?.zoneID {
                    return TimeZone(identifier: zoneID)
                }
            }
            // No longitude (or west of every zone): the list's first zone.
            return TimeZone(identifier: zones[0].zoneID)
        }
        guard let longitude else { return nil }
        let hours = Int((longitude / 15).rounded())
        return TimeZone(secondsFromGMT: max(-12, min(12, hours)) * 3600)
    }

    /// The representative city an IANA zone identifier names ("Europe/Berlin"
    /// → "Berlin", "America/New_York" → "New York"). Nil for zones without a
    /// city in the identifier (fixed-offset zones like "GMT+0200").
    public static func cityName(forIdentifier identifier: String) -> String? {
        let components = identifier.split(separator: "/")
        // Fixed-offset zones ("GMT+0200", "UTC") have no slash and no city.
        guard components.count > 1, let lastComponent = components.last, !lastComponent.isEmpty else {
            return nil
        }
        let city = lastComponent.replacingOccurrences(of: "_", with: " ")
        return city.isEmpty ? nil : city
    }
}
