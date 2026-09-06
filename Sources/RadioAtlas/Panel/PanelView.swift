import SwiftUI

struct PanelView: View {
    var body: some View {
        VStack {
            Text("Radio Atlas")
                .font(.title2)
            Text("Globe and controls land here in later tasks.")
                .foregroundStyle(.secondary)
        }
        .frame(width: 480, height: 640)
        .padding()
    }
}
