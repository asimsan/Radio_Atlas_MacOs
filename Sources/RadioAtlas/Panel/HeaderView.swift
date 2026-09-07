import SwiftUI

struct HeaderView: View {
    @Binding var searchQuery: String
    var searchFieldFocus: FocusState<Bool>.Binding
    let helpVisible: Bool
    let onRandom: () -> Void
    let onToggleHelp: () -> Void
    let onToggleFloating: () -> Void
    let onClose: () -> Void
    let onQuit: () -> Void

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
                    .focused(searchFieldFocus)
                Button(action: onRandom) { Image(systemName: "shuffle") }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.foreground)
                    .help("Tune randomly (R)")
                Button(action: onToggleFloating) { Image(systemName: "pip.enter") }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.foreground)
                    .help("Toggle floating mini window")
                Button(action: onToggleHelp) { Text("?").font(Palette.monoBody) }
                    .buttonStyle(.plain)
                    .foregroundStyle(helpVisible ? Palette.accent : Palette.foreground)
                    .help(helpVisible ? "Hide controls (?)" : "Show controls (?)")
                Button(action: onClose) { Image(systemName: "xmark") }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.foreground)
                    .help("Close")
                // Quit is separated from the dismiss button above: they sit
                // next to each other but one hides the panel and the other
                // ends playback and the process.
                Rectangle().fill(Palette.divider).frame(width: 1, height: 20)
                Button(action: onQuit) { Image(systemName: "power") }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.foreground)
                    .help("Quit Radio Atlas (\u{2318}Q)")
            }
            .padding(.horizontal, 16)
            .frame(height: 68)
            Rectangle().fill(Palette.divider).frame(height: 1)
        }
        .background(Palette.background)
    }
}
