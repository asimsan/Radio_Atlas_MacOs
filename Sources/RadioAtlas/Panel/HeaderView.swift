import SwiftUI

struct HeaderView: View {
    @Binding var searchQuery: String
    let helpVisible: Bool
    let onRandom: () -> Void
    let onToggleHelp: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("RADIO ATLAS")
                    .font(Palette.monoTitle)
                    .foregroundStyle(Palette.foreground)
                Spacer()
                TextField("Search station, country, or genre", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(Palette.monoBody)
                    .padding(6)
                    .background(Palette.elevated)
                    .cornerRadius(4)
                    .frame(maxWidth: 330)
                Button(action: onRandom) { Image(systemName: "shuffle") }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.foreground)
                    .help("Tune randomly (R)")
                Button(action: onToggleHelp) { Text("?").font(Palette.monoBody) }
                    .buttonStyle(.plain)
                    .foregroundStyle(helpVisible ? Palette.accent : Palette.foreground)
                    .help(helpVisible ? "Hide controls (?)" : "Show controls (?)")
                Button(action: onClose) { Image(systemName: "xmark") }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.foreground)
                    .help("Close")
            }
            .padding(.horizontal, 16)
            .frame(height: 68)
            Rectangle().fill(Palette.divider).frame(height: 1)
        }
        .background(Palette.background)
    }
}
