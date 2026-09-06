import RadioAtlasCore
import SwiftUI

struct GlobePaneView: View {
    let stations: [Station]
    let countryLookup: CountryLookup?
    let regions: [CountryRegion]
    let activeCountryCode: String?
    let activeCountryName: String?
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
                    onStationTapped: onStationTapped,
                    onCountryTapped: onCountryTapped
                )
                .padding(16)
            }
            HStack {
                Text(activeCountryName.map { "\($0)  ·  click another country to browse" }
                    ?? "Drag or flick to spin  ·  wheel to zoom  ·  click a signal or country")
                    .font(Palette.monoCaption)
                    .foregroundStyle(Palette.dim)
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
}
