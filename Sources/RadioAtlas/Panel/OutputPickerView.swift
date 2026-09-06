import RadioAtlasCore
import SwiftUI

struct OutputPickerView: View {
    let devices: [OutputDevice]
    let selectedID: String?
    let onSelect: (OutputDevice) -> Void
    @State private var isPresented = false

    var body: some View {
        Button(action: { isPresented.toggle() }) {
            Image(systemName: "hifispeaker")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.foreground)
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("AUDIO OUTPUT")
                    .font(Palette.monoCaption).bold()
                    .foregroundStyle(Palette.dim)
                if devices.count <= 1 {
                    Text("No other audio outputs found")
                        .font(Palette.monoCaption)
                        .foregroundStyle(Palette.dim)
                } else {
                    ForEach(devices) { device in
                        Button {
                            onSelect(device)
                            isPresented = false
                        } label: {
                            HStack {
                                Text(device.name).font(Palette.monoBody)
                                Spacer()
                                if device.id == selectedID {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Palette.foreground)
                    }
                }
            }
            .padding(12)
            .frame(minWidth: 220)
            .background(Palette.background)
        }
    }
}
