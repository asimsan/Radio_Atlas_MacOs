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
