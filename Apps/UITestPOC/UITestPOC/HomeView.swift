
import SwiftUI
import LearningSubspecSDK

struct HomeView: View {
    @Environment(\.currentRootView) var rootView
    var body: some View {

        VStack(spacing: 20) {
            Text("HomeView")
                .font(.largeTitle)
                .bold()
                .accessibilityIdentifier("home.view")
            Button(action: {
                LearningSDKManager.shared.logoutUser()
                self.rootView.wrappedValue = .login
            }) {
                Text("Log out")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("logout.button")
        }
        .navigationBarTitle("Home", displayMode: .inline)
        .padding()
    }
}

#Preview {
    LoginView()
}
