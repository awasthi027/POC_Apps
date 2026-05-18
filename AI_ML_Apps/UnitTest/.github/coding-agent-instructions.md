# Coding Agent Implementation Instructions

## Objective
The coding agent must read the requirement document placed in the project and implement the feature end-to-end in the existing iOS codebase.

## Input Source
- The agent must use the requirement `.md` file available in the project path as the source of truth.
- Before implementation, the agent must read and understand the requirement completely.
- If multiple requirement files exist, the agent should use the one explicitly referenced for the task.

## Expected Agent Workflow

### 1. Requirement Analysis
- Read the requirement markdown file completely.
- Identify:
  - business rules
  - UI flow
  - validation rules
  - data flow
  - persistence requirements
  - online and offline behavior
  - edge cases
  - error states
- Convert the requirement into implementation tasks before writing code.

### 2. Architecture
- Follow **Clean Architecture**.
- Separate code into appropriate layers:
  - Presentation
  - Domain
  - Data
- Keep UI, business logic, persistence, and networking decoupled.
- Use protocols and dependency injection to make components testable and replaceable.

### 3. Implementation Standards
- Follow **Swift 6** guidelines.
- Follow **Apple naming conventions** for variables, constants, types, methods, and protocols.
- Avoid force unwraps.
- Avoid force casting.
- Validate all input and responses.
- Keep functions small and focused.
- Target functions to be no more than **15 lines where reasonably possible**.
- No commented-out code.
- No dead code.
- No unused imports.
- Code must be production-ready.

### 4. Concurrency and Threading
- Use safe concurrency and multithreading practices.
- Prefer modern Swift concurrency (`async/await`) where appropriate.
- Ensure all UI updates happen on the main thread.
- Do not block the main thread.
- Make asynchronous logic testable.

### 5. Testing Requirements
- Add unit tests for:
  - business logic
  - validation rules
  - repository behavior
  - error handling
  - offline and online authentication logic
- Add UI tests for:
  - sign in flow
  - sign up flow
  - invalid input validation
  - user not found flow
  - redirect from sign in to sign up
  - offline authentication behavior
- Cover both:
  - positive scenarios
  - negative scenarios

### 6. Code Coverage
- Maintain minimum **90% unit test coverage** for core feature logic.
- Critical modules should target **95%+ coverage** where practical.
- Do not reduce the overall project quality bar.

### 7. UI Test Automation Readiness
- Add accessibility identifiers for all important UI elements.
- Keep flows deterministic for stable automation.
- Ensure screens are easy to test with XCUITest.

### 8. Validation Rules
The agent must implement all validation described in the requirement file, including:
- mandatory field validation
- email format validation
- password confirmation validation
- user existence checks
- offline data existence checks
- API failure handling
- local persistence validation

### 9. Persistence and Networking
- Use the requirement file to determine what must come from server and what must be stored locally.
- If API is placeholder-based, build the code so the API layer can be replaced later without changing business logic.
- Persist required local data using the project’s chosen persistence strategy.

### 10. Definition of Done
The task is complete only when:
- Requirement is fully implemented.
- Code follows clean architecture.
- Validation is complete.
- Unit tests are added and passing.
- UI tests are added and passing.
- Edge cases are handled.
- No force unwraps or unsafe casts exist.
- No commented code remains.
- Naming follows Apple conventions.
- Code is maintainable and production-ready.

## Agent Execution Rule
The agent should not only generate code snippets.  
The agent should implement the requirement directly in the project codebase by:
- creating required files
- modifying existing files
- adding tests
- wiring dependencies
- preparing UI automation support

## Output Expectation
The final output from the agent should include:
- implemented production code
- unit tests
- UI tests
- summary of changed files
- summary of validations implemented
- summary of test coverage
- any assumptions made during implementation