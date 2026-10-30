import SwiftUI

struct OnboardingView: View {
    var body: some View {
        VStack(spacing: UIDevice.current.userInterfaceIdiom == .pad ? 32 : 16) {
            Image("welcome")
                .frame(width: 390, height: 300)
            Text("Welcome")
                .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    OnboardingView().frame(width: 393, height: 852)
}
