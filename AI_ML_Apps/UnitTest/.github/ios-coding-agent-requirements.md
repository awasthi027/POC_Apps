# iOS Coding Agent Development Requirements

## Overview
This document defines the coding standards, architecture rules, testing expectations, and development process that the coding agent must follow while implementing iOS features. The goal is to ensure the codebase is maintainable, testable, scalable, and aligned with Apple platform standards and Swift 6 best practices.

---

## 1. Architecture Requirements

- Follow **Clean Architecture** principles.
- Separate code clearly into layers such as:
  - Presentation
  - Domain
  - Data
- Apply **dependency inversion**.
- Business logic must remain independent from UI, frameworks, and persistence details.
- Keep modules loosely coupled and easy to replace or mock.
- Use protocol-based abstractions where appropriate.
- Design the code to support easy maintenance and future scalability.

---

## 2. Swift and Apple Coding Standards

- Follow **Swift 6 guidelines** and modern Swift best practices.
- Follow **Apple naming conventions** for:
  - Variables
  - Constants
  - Functions
  - Types
  - Protocols
- Use clear, intention-revealing names.
- Avoid abbreviations unless they are standard and widely accepted.
- Keep code readable, consistent, and self-explanatory.
- Prefer value types where appropriate.
- Use access control properly.
- Avoid unnecessary complexity.
- Code should be structured for long-term maintainability.

---

## 3. Safety and Validation Rules

- **Do not use force unwraps**.
- **Do not use unsafe force casts**.
- Validate all external inputs.
- Handle optional values safely using:
  - `guard`
  - `if let`
  - `nil` coalescing
  - safe patterns
- Add proper validation for:
  - API responses
  - user input
  - local storage data
  - navigation arguments
- Handle all possible failure states gracefully.
- Error handling must be explicit and testable.

---

## 4. Function and Code Size Rules

- A function should **not be more than 15 lines** wherever reasonably possible.
- Each function should have **a single responsibility**.
- Break large logic into smaller reusable methods.
- Avoid deeply nested logic.
- Keep view controllers, view models, and use cases focused and lightweight.
- Complex workflows should be split into composable units.

---

## 5. Multithreading and Concurrency

- Follow proper **multithreading** and **concurrency** practices.
- Use modern Swift concurrency where appropriate:
  - `async`
  - `await`
  - structured concurrency
- Ensure UI updates happen on the main thread.
- Avoid race conditions and shared mutable state issues.
- Background tasks must be isolated and safe.
- Concurrency decisions should be explicit and testable.
- Avoid blocking the main thread.
- Design asynchronous code for readability and predictability.

---

## 6. Testing Requirements

### 6.1 Unit Testing
- All business logic must be covered with **unit tests**.
- The complete codebase should be designed for high testability.
- Use dependency injection to support mocking and isolation.
- Unit tests must cover:
  - success cases
  - failure cases
  - validation rules
  - edge cases
  - error handling
- Include both:
  - **passing unit test cases**
  - **failing unit test cases**, when useful to validate expected failure behavior

### 6.2 UI Testing
- The application must be easy to automate using **UI tests**.
- Accessibility identifiers should be added for key UI elements.
- UI flows should be deterministic and stable for automation.
- UI tests must cover:
  - happy path flows
  - validation failures
  - navigation flows
  - error states
- Include both:
  - **passing UI test scenarios**
  - **failing UI test scenarios**, where appropriate for validation and negative paths

### 6.3 Testability Standards
- Avoid tightly coupling logic to UIKit/SwiftUI framework details.
- Separate view logic from business logic.
- External dependencies should be mockable.
- Code should be structured to support reliable CI automation.
- Tests should be readable, repeatable, and independent.

---

## 7. Code Coverage Requirements

- Maintain **minimum unit test coverage of 90%**.
- Critical modules such as:
  - authentication
  - business logic
  - validation
  - persistence
  should target **95%+ coverage**.
- UI automation coverage should include all critical user journeys.
- Code coverage reports must be generated as part of the test process.
- New code should not reduce the agreed quality threshold.

---

## 8. UI Automation Readiness

- Screens, buttons, text fields, labels, and error messages should support easy UI automation.
- Add stable accessibility identifiers for all important UI controls.
- Avoid dynamic behavior that makes tests flaky unless necessary.
- Navigation and screen states should be predictable.
- Test environments should support mock/stub data where possible.

---

## 9. Code Cleanliness Rules

- **No commented-out code** should remain in the codebase.
- Remove unused code, dead code, and unused imports.
- Keep files clean and focused.
- Logging should be intentional and appropriate.
- Avoid temporary debugging artifacts in committed code.
- The codebase should remain production-ready.

---

## 10. Validation and Error Handling Standards

- Every feature must include validation rules where needed.
- Errors must be:
  - user-friendly in UI
  - meaningful for developers
  - testable in unit and UI tests
- Avoid silent failures.
- Use typed error models when possible.
- Handle network, parsing, persistence, and business-rule failures explicitly.

---

## 11. Step-by-Step Delivery Process

The coding agent must follow this execution order for every feature:

1. **Requirement Understanding**
   - Understand the requirement fully.
   - Identify business rules, edge cases, dependencies, and risks.

2. **Architecture Design**
   - Define layers, protocols, models, use cases, and data flow.
   - Ensure Clean Architecture compliance.

3. **Implementation**
   - Write production code in small, reviewable steps.
   - Follow Swift 6 and Apple coding standards.
   - Keep functions short and focused.

4. **Unit Testing**
   - Add unit tests for all business logic and validation paths.
   - Cover positive, negative, and edge cases.

5. **UI Testing**
   - Add UI automation tests for all main flows.
   - Cover both pass and fail scenarios.

6. **Verification**
   - Ensure code compiles cleanly.
   - Ensure tests pass.
   - Ensure coverage threshold is met.

7. **Cleanup**
   - Remove unused code.
   - Remove commented code.
   - Verify naming, formatting, and architecture quality.

---

## 12. Definition of Done

A feature is considered complete only if all of the following are satisfied:

- Clean Architecture is followed.
- Swift 6 best practices are followed.
- Apple naming guidelines are followed.
- No force unwraps or unsafe casts are used.
- Functions are not longer than 15 lines wherever reasonably possible.
- Code is thread-safe and follows concurrency best practices.
- Validation is complete and explicit.
- No commented-out code remains.
- Code is easy to automate with UI tests.
- Unit tests are implemented for all core logic.
- UI tests are implemented for critical flows.
- Both positive and negative test scenarios are covered.
- Minimum required code coverage is achieved.
- Code is clean, readable, maintainable, and production-ready.

---

## 13. Recommended Additional Standards

The coding agent should also consider the following Apple-standard-aligned practices:

- Use SOLID principles where appropriate.
- Prefer composition over inheritance.
- Keep side effects isolated.
- Ensure deterministic behavior in tests.
- Use environment-based dependency configuration for testability.
- Keep models simple and focused.
- Avoid massive view controllers or overly complex views.
- Follow accessibility best practices where possible.
- Support future localization if text is user-facing.
- Ensure performance is acceptable for UI and data operations.
- Keep persistence and networking abstracted behind interfaces.

---

## 14. Optional Quality Gates

If supported by the project, the coding agent should also enforce:

- SwiftLint compliance
- SwiftFormat compliance
- CI pipeline test execution
- Code coverage checks in CI
- Static analysis checks
- Warning-free builds
- Accessibility audit for important screens

---

## 15. Summary

The coding agent must produce production-quality iOS code that is:
- Cleanly architected
- Safe
- Testable
- Concurrent where needed
- Fully validated
- Easy to maintain
- Easy to automate
- Aligned with Swift 6 and Apple development standards