
import SwiftUI
import LearningSubspecSDK

struct BaseView: View {

    @State var rootView: RootScreen = LearningSDKManager.shared.userIsLogin ? .homeView : .login

    var body: some View {
        AutomationLoggerView()
        if rootView == .login {
            NavHandler {
                LoginView()
                    .environment(\.currentRootView, self.$rootView)
            }
        }else {
            NavHandler {
                HomeView()
                    .environment(\.currentRootView, self.$rootView)
            }
        }
    }
}

#Preview {
    LoginView()
}

