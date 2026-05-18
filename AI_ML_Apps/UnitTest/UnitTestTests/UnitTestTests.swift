//
//  UnitTestTests.swift
//  UnitTestTests
//
//  Created by Ashish Awasthi on 14/05/26.
//

import XCTest
@testable import UnitTest

final class AuthValidatorTests: XCTestCase {
    private let validator = AuthValidator()

    func test_validateRegistration_requiresFirstName() {
        let request = RegistrationRequest(
            firstName: " ",
            lastName: "User",
            email: "demo@example.com",
            username: "demo",
            password: "Password123",
            confirmPassword: "Password123"
        )

        XCTAssertThrowsError(try validator.validateRegistration(request)) { error in
            XCTAssertEqual(error as? AuthError, .emptyField("First Name"))
        }
    }

    func test_validateRegistration_rejectsInvalidEmail() {
        let request = RegistrationRequest(
            firstName: "Demo",
            lastName: "User",
            email: "not-an-email",
            username: "demo",
            password: "Password123",
            confirmPassword: "Password123"
        )

        XCTAssertThrowsError(try validator.validateRegistration(request)) { error in
            XCTAssertEqual(error as? AuthError, .invalidEmail)
        }
    }

    func test_validateRegistration_rejectsWeakPassword() {
        let request = RegistrationRequest(
            firstName: "Demo",
            lastName: "User",
            email: "demo@example.com",
            username: "demo",
            password: "short",
            confirmPassword: "short"
        )

        XCTAssertThrowsError(try validator.validateRegistration(request)) { error in
            XCTAssertEqual(error as? AuthError, .weakPassword(minimumLength: 8))
        }
    }

    func test_validateRegistration_requiresMatchingPasswords() {
        let request = RegistrationRequest(
            firstName: "Demo",
            lastName: "User",
            email: "demo@example.com",
            username: "demo",
            password: "Password123",
            confirmPassword: "Password321"
        )

        XCTAssertThrowsError(try validator.validateRegistration(request)) { error in
            XCTAssertEqual(error as? AuthError, .passwordMismatch)
        }
    }

    func test_validateSignIn_requiresIdentifier() {
        let request = SignInRequest(identifier: " ", password: "Password123")

        XCTAssertThrowsError(try validator.validateSignIn(request)) { error in
            XCTAssertEqual(error as? AuthError, .emptyField("Username or Email"))
        }
    }
}
