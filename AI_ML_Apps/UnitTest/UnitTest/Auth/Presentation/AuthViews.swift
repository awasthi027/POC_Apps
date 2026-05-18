import SwiftUI

struct ConnectionStatusView: View {
    @ObservedObject var connectivity: AppConnectivityMonitor

    var body: some View {
        HStack(spacing: 12) {
            Label(statusText, systemImage: statusIcon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(connectivity.isOnline ? .green : .orange)
                .accessibilityIdentifier(AccessibilityID.Connection.statusLabel)

            Spacer()

            Button(toggleTitle) {
                connectivity.toggle()
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier(AccessibilityID.Connection.toggleButton)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var statusText: String {
        connectivity.isOnline ? "Online Mode" : "Offline Mode"
    }

    private var toggleTitle: String {
        connectivity.isOnline ? "Go Offline" : "Go Online"
    }

    private var statusIcon: String {
        connectivity.isOnline ? "wifi" : "wifi.slash"
    }
}

struct AuthChoiceView: View {
    @ObservedObject var connectivity: AppConnectivityMonitor
    let onSignIn: () -> Void
    let onSignUp: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                ConnectionStatusView(connectivity: connectivity)
                titleSection
                actionButtons
                Spacer()
            }
            .padding()
            .navigationTitle("Authentication")
            .accessibilityIdentifier(AccessibilityID.Choice.screen)
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome")
                .font(.largeTitle.bold())
            Text("Choose how you would like to continue.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 16) {
            Button("Sign In", action: onSignIn)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier(AccessibilityID.Choice.signInButton)

            Button("Sign Up", action: onSignUp)
                .buttonStyle(.bordered)
                .accessibilityIdentifier(AccessibilityID.Choice.signUpButton)
        }
    }
}

struct SignInView: View {
    private enum Field {
        case identifier
        case password
    }

    @ObservedObject var connectivity: AppConnectivityMonitor
    @ObservedObject var viewModel: SignInViewModel
    let onAuthenticated: (User) -> Void
    let onCreateAccount: () -> Void
    let onUserNotFound: (String) -> Void
    @FocusState private var focusedField: Field?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ConnectionStatusView(connectivity: connectivity)
                header
                fields
                errorView
                signInButton
                Button("Need an account? Sign Up", action: onCreateAccount)
                    .accessibilityIdentifier(AccessibilityID.SignIn.secondaryButton)
                Spacer(minLength: 0)
            }
            .padding()
        }
        .accessibilityIdentifier(AccessibilityID.SignIn.screen)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sign In")
                .font(.largeTitle.bold())
            Text("Use your username or email and password to continue.")
                .foregroundStyle(.secondary)
        }
    }

    private var fields: some View {
        VStack(spacing: 16) {
            TextField("Username or Email", text: $viewModel.identifier)
                .textInputAutocapitalization(.never)
                .textContentType(.username)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($focusedField, equals: .identifier)
                .onSubmit { focusedField = .password }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier(AccessibilityID.SignIn.identifierField)

            SecureField("Password", text: $viewModel.password)
                .textContentType(.password)
                .submitLabel(.go)
                .focused($focusedField, equals: .password)
                .onSubmit { submitSignIn() }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier(AccessibilityID.SignIn.passwordField)
        }
    }

    @ViewBuilder
    private var errorView: some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .foregroundStyle(.red)
                .accessibilityIdentifier(AccessibilityID.SignIn.errorLabel)
        }
    }

    private var signInButton: some View {
        Button(viewModel.isLoading ? "Signing In..." : "Sign In") {
            submitSignIn()
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.isLoading)
        .accessibilityIdentifier(AccessibilityID.SignIn.submitButton)
    }

    private func submitSignIn() {
        focusedField = nil
        Task {
            let outcome = await viewModel.signIn()
            handle(outcome: outcome)
        }
    }

    private func handle(outcome: SignInOutcome?) {
        switch outcome {
        case .authenticated(let user):
            onAuthenticated(user)
        case .needsRegistration(let identifier):
            onUserNotFound(identifier)
        case nil:
            return
        }
    }
}

struct SignUpView: View {
    private enum Field {
        case firstName
        case lastName
        case email
        case username
        case password
        case confirmPassword
    }

    @ObservedObject var connectivity: AppConnectivityMonitor
    @ObservedObject var viewModel: SignUpViewModel
    let onAuthenticated: (User) -> Void
    let onShowSignIn: () -> Void
    @FocusState private var focusedField: Field?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ConnectionStatusView(connectivity: connectivity)
                header
                fields
                errorView
                signUpButton
                Button("Already have an account? Sign In", action: onShowSignIn)
                    .accessibilityIdentifier(AccessibilityID.SignUp.secondaryButton)
                Spacer(minLength: 0)
            }
            .padding()
        }
        .accessibilityIdentifier(AccessibilityID.SignUp.screen)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sign Up")
                .font(.largeTitle.bold())
            Text("Create an account to continue.")
                .foregroundStyle(.secondary)
        }
    }

    private var fields: some View {
        VStack(spacing: 16) {
            entryField(
                "First Name",
                text: $viewModel.firstName,
                identifier: AccessibilityID.SignUp.firstNameField,
                field: .firstName,
                submitLabel: .next,
                nextField: .lastName
            )
            entryField(
                "Last Name",
                text: $viewModel.lastName,
                identifier: AccessibilityID.SignUp.lastNameField,
                field: .lastName,
                submitLabel: .next,
                nextField: .email
            )
            entryField(
                "Email",
                text: $viewModel.email,
                identifier: AccessibilityID.SignUp.emailField,
                field: .email,
                submitLabel: .next,
                nextField: .username,
                keyboard: .emailAddress
            )
            entryField(
                "Username",
                text: $viewModel.username,
                identifier: AccessibilityID.SignUp.usernameField,
                field: .username,
                submitLabel: .next,
                nextField: .password
            )
            secureField(
                "Password",
                text: $viewModel.password,
                identifier: AccessibilityID.SignUp.passwordField,
                field: .password,
                submitLabel: .next,
                nextField: .confirmPassword
            )
            secureField(
                "Confirm Password",
                text: $viewModel.confirmPassword,
                identifier: AccessibilityID.SignUp.confirmPasswordField,
                field: .confirmPassword,
                submitLabel: .go,
                nextField: nil
            )
        }
    }

    private func entryField(
        _ title: String,
        text: Binding<String>,
        identifier: String,
        field: Field,
        submitLabel: SubmitLabel,
        nextField: Field?,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        TextField(title, text: text)
            .keyboardType(keyboard)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(submitLabel)
            .focused($focusedField, equals: field)
            .onSubmit { handleSubmit(nextField: nextField) }
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier(identifier)
    }

    private func secureField(
        _ title: String,
        text: Binding<String>,
        identifier: String,
        field: Field,
        submitLabel: SubmitLabel,
        nextField: Field?
    ) -> some View {
        SecureField(title, text: text)
            .submitLabel(submitLabel)
            .focused($focusedField, equals: field)
            .onSubmit { handleSubmit(nextField: nextField) }
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private var errorView: some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .foregroundStyle(.red)
                .accessibilityIdentifier(AccessibilityID.SignUp.errorLabel)
        }
    }

    private var signUpButton: some View {
        Button(viewModel.isLoading ? "Creating Account..." : "Sign Up") {
            submitSignUp()
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.isLoading)
        .accessibilityIdentifier(AccessibilityID.SignUp.submitButton)
    }

    private func handleSubmit(nextField: Field?) {
        guard let nextField else {
            submitSignUp()
            return
        }
        focusedField = nextField
    }

    private func submitSignUp() {
        focusedField = nil
        Task {
            guard let user = await viewModel.signUp() else {
                return
            }
            onAuthenticated(user)
        }
    }
}

struct HomeView: View {
    let user: User
    let onSignOut: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Welcome, \(user.firstName) \(user.lastName)")
                    .font(.largeTitle.bold())
                    .accessibilityIdentifier(AccessibilityID.Home.welcomeLabel)
                Text("Signed in as @\(user.username) • \(user.email)")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Sign Out", action: onSignOut)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier(AccessibilityID.Home.signOutButton)
            }
            .padding()
            .navigationTitle("Home")
            .accessibilityIdentifier(AccessibilityID.Home.screen)
        }
    }
}
