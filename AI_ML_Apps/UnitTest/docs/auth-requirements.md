# Authentication Module Requirements

## Overview
Design and implement the authentication module for the application. The module should support user registration and login using server-based authentication, local data persistence with Core Data, and offline authentication using locally stored user data.

## Functional Requirements

### 1. Entry Screen
The first screen of the application should display two options:
- **Sign In**
- **Sign Up**

### 2. Sign Up Screen
The Sign Up screen should allow the user to register with the following fields:
- First Name
- Last Name
- Email
- Username
- Password
- Confirm Password

#### Sign Up Validations
- All fields are mandatory.
- Email must be in a valid format.
- Password and Confirm Password must match.
- Password should follow basic security rules such as minimum length.
- Username should be unique if validated through the server or mock API.

### 3. Sign In Screen
The Sign In screen should allow the user to log in using:
- Username or Email
- Password

#### Sign In Behavior
- If the user exists and credentials are valid, login should be successful.
- If the user attempts to sign in and the user is not found, the app should redirect the user to the Sign Up screen.
- If the credentials are invalid, an appropriate error message should be shown.

### 4. Server Integration
- User authentication and registration data should be retrieved from a server API.
- Since the actual server API is not available yet, a placeholder API or any public mock API may be used temporarily.
- The implementation should allow easy replacement of the placeholder API with the actual backend in the future.

### 5. Local Storage with Core Data
- User data received from the server should be stored locally using Core Data.
- The local database should store the information required for offline authentication and basic user profile access.

### 6. Offline Authentication
- If the user is offline, the app should authenticate using the locally stored data in Core Data.
- Offline authentication should only work for users whose data has already been synced and saved locally.
- If the device is offline and the user data is not available locally, the app should show an appropriate message.

### 7. Navigation Flow
- Launch the app to the authentication choice screen with **Sign In** and **Sign Up** options.
- On **Sign Up**:
  - Register the user through the server or placeholder API.
  - Save the returned user data into Core Data.
  - Navigate the user to the next screen after successful registration.
- On **Sign In**:
  - If online, validate credentials with the server.
  - Save or update user data in Core Data after successful login.
  - If offline, validate credentials against Core Data.
  - If the user is not found, redirect to the Sign Up screen.

### 8. Error Handling
The app should show appropriate messages for the following cases:
- No internet connection
- User not found
- Invalid credentials
- Password and Confirm Password do not match
- Required fields are empty
- API/server failure

## Non-Functional Requirements
- The solution should be modular so that API and local storage logic are separated.
- Core Data should be used for local persistence.
- The code should support future replacement of the placeholder API with the actual production API.

## Suggested API Approach
- Use a placeholder or public mock API for initial integration and testing.
- API contracts should be defined in a way that can later be replaced without major UI or data-layer changes.

## Acceptance Criteria
- User can view Sign In and Sign Up options on the first screen.
- User can register using First Name, Last Name, Email, Username, Password, and Confirm Password.
- Password must be entered twice and both values must match.
- User can sign in with Username/Email and Password.
- If user is not found during sign in, the app redirects to the Sign Up screen.
- User data is fetched from server/mock API and stored in Core Data.
- If internet is unavailable, previously saved user data can be used for authentication.
- Proper error messages are shown for validation, network, and authentication failures.