import SwiftUI

struct HelpOverlayView: View {
    private struct ControlRow: Hashable { let input: String; let action: String }
    private struct ControlSection { let title: String; let rows: [ControlRow] }

    private let sections: [ControlSection] = [
        ControlSection(title: "KEYBOARD", rows: [
            ControlRow(input: "/", action: "Search"),
            ControlRow(input: "UP / DOWN", action: "Select station"),
            ControlRow(input: "ENTER", action: "Play selected station"),
            ControlRow(input: "SPACE", action: "Play or pause"),
            ControlRow(input: "R", action: "Tune randomly"),
            ControlRow(input: "F", action: "Favorite selected station"),
            ControlRow(input: "M", action: "Mute or unmute"),
            ControlRow(input: "+ / -", action: "Change volume"),
            ControlRow(input: "ESC", action: "Back, clear, or close"),
            ControlRow(input: "?", action: "Show or hide controls"),
        ]),
        ControlSection(title: "MOUSE", rows: [
            ControlRow(input: "DRAG / FLICK", action: "Spin globe"),
            ControlRow(input: "GLOBE WHEEL", action: "Zoom"),
            ControlRow(input: "CLICK SIGNAL", action: "Play station"),
            ControlRow(input: "CLICK COUNTRY", action: "Browse stations"),
            ControlRow(input: "SPEAKER", action: "Choose audio output"),
        ]),
    ]

    var body: some View {
        VStack(spacing: 24) {
            Text("CONTROLS")
                .font(Palette.monoTitle)
                .foregroundStyle(Palette.foreground)
            HStack(alignment: .top, spacing: 72) {
                ForEach(sections, id: \.title) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title)
                            .font(Palette.monoCaption).bold()
                            .foregroundStyle(Palette.dim)
                        ForEach(section.rows, id: \.self) { row in
                            VStack(spacing: 4) {
                                HStack {
                                    Text(row.input)
                                        .font(Palette.monoCaption).bold()
                                        .foregroundStyle(Palette.foreground)
                                        .frame(width: 120, alignment: .leading)
                                    Text(row.action)
                                        .font(Palette.monoBody)
                                        .foregroundStyle(Palette.dim)
                                    Spacer()
                                }
                                Rectangle().fill(Palette.divider).frame(height: 1)
                            }
                        }
                    }
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
    }
}
