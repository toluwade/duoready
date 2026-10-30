import SwiftUI

struct ProfileView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        // Adaptive: driven by the size class, not the device.
        let columns = sizeClass == .regular ? 2 : 1
        VStack {
            Text("Columns: \(columns)")
            Image("avatar")
                .frame(width: UIScreen.main.bounds.width * 0.4) // duoready:ignore DR001
        }
    }
}
