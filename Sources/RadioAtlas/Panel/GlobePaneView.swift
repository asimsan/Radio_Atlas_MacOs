import RadioAtlasCore
import SwiftUI

struct GlobePaneView: View {
    let stations: [Station]
    let countryLookup: CountryLookup?
    let regions: [CountryRegion]
    let activeCountryCode: String?
    let activeCountryName: String?
    let playingCountryCode: String?
    let playingStation: Station?
    let auroraActivity: AuroraActivity?
    let statusMessage: String?
    let onStationTapped: (Station) -> Void
    let onCountryTapped: (String) -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Palette.globePaneBackground
            if let countryLookup {
                GlobeCanvasView(
                    stations: stations,
                    countryLookup: countryLookup,
                    regions: regions,
                    activeCountryCode: activeCountryCode,
                    playingCountryCode: playingCountryCode,
                    playingStation: playingStation,
                    auroraActivity: auroraActivity,
                    onStationTapped: onStationTapped,
                    onCountryTapped: onCountryTapped
                )
                .padding(16)
            }
            HStack {
                Text(hintText)
                    .font(Palette.monoCaption)
                    .foregroundStyle(hintColor)
                    .lineLimit(1)
                Spacer()
                Text("\(stations.count) signals")
                    .font(Palette.monoCaption)
                    .foregroundStyle(Palette.dim)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .overlay(alignment: .topTrailing) {
            // The playing station's city and its local date/time, ticking
            // once a second — the user's own time while nothing is playing.
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                let time = Self.formattedDate(timeline.date, timeZone: displayTimeZone)
                if playingStation != nil,
                   let city = CountryTimeZones.cityName(forIdentifier: displayTimeZone.identifier) {
                    Text("\(city) · \(time)")
                        .font(Palette.monoCaption)
                        .foregroundStyle(Palette.dim)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                } else {
                    Text(time)
                        .font(Palette.monoCaption)
                        .foregroundStyle(Palette.dim)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                }
            }
        }
    }

    /// The timezone the clock displays: the playing station's country zone
    /// (the station's longitude disambiguates wide countries like the US),
    /// falling back to the user's own timezone.
    private var displayTimeZone: TimeZone {
        if let station = playingStation {
            return CountryTimeZones.timeZone(countryCode: station.countryCode, longitude: station.longitude) ?? .current
        }
        return .current
    }

    private static func formattedDate(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy · HH:mm:ss"
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }

    // A fetch/local error takes precedence over the active-country hint,
    // which takes precedence over the default hint — matching the original's
    // documented `fetchError` priority (see design spec's globe pane hint text).
    private var hintText: String {
        if let statusMessage { return statusMessage }
        if let activeCountryName { return "\(activeCountryName)  ·  click another country to browse" }
        return "Drag or flick to spin  ·  wheel to zoom  ·  click a signal or country"
    }

    private var hintColor: Color {
        statusMessage != nil ? Palette.urgent : Palette.dim
    }
}
