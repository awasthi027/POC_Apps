import Foundation

enum AccessibilityID {
    enum Choice {
        static let screen = "auth.choice.screen"
        static let signInButton = "auth.choice.signInButton"
        static let signUpButton = "auth.choice.signUpButton"
    }

    enum Connection {
        static let statusLabel = "auth.connection.statusLabel"
        static let toggleButton = "auth.connection.toggleButton"
    }

    enum SignIn {
        static let screen = "auth.signIn.screen"
        static let identifierField = "auth.signIn.identifierField"
        static let passwordField = "auth.signIn.passwordField"
        static let submitButton = "auth.signIn.submitButton"
        static let errorLabel = "auth.signIn.errorLabel"
        static let secondaryButton = "auth.signIn.secondaryButton"
    }

    enum SignUp {
        static let screen = "auth.signUp.screen"
        static let firstNameField = "auth.signUp.firstNameField"
        static let lastNameField = "auth.signUp.lastNameField"
        static let emailField = "auth.signUp.emailField"
        static let usernameField = "auth.signUp.usernameField"
        static let passwordField = "auth.signUp.passwordField"
        static let confirmPasswordField = "auth.signUp.confirmPasswordField"
        static let submitButton = "auth.signUp.submitButton"
        static let errorLabel = "auth.signUp.errorLabel"
        static let secondaryButton = "auth.signUp.secondaryButton"
    }

    enum Home {
        static let screen = "auth.home.screen"
        static let welcomeLabel = "auth.home.welcomeLabel"
        static let signOutButton = "auth.home.signOutButton"
    }
}
