# MockGen — Unit Test Mock Generator for macOS

A lightweight macOS app that parses Swift protocols and automatically generates ready-to-use mock classes for unit testing.

## Features

### 🎯 Dual-Mode Generation

**Interactor Protocol Mode**
- Automatically detects protocols containing "Interactor" in the name
- Generates success/failure flags (`isMethodSuccess`)
- Pulls test data via `Data.getResponse()` helper
- Supports async throws and RxSwift patterns

**Standard Protocol Mode**
- Generates default return values directly in method bodies
- Zero boilerplate for simple mocks
- Clean, minimal implementation

### 🔄 Smart Method Overload Handling

Methods with identical names are automatically renamed:
```swift
// Input
func getUser() async -> User
func getUser() -> Single<User>

// Output
getUser()          // first overload
getUser2()         // second overload
```

No property name collisions, no call count conflicts.

### 📝 Protocol Parsing

- **Properties**: Parses `var name: Type { get }` and `{ get set }`
- **Methods**: External/internal parameter names, async, throws, return types
- **Multiline**: Preserves original formatting of multiline method signatures
- **Generics**: Handles nested `<>`, `[]`, `()` in type annotations
- **Comments**: Strips all documentation and inline comments automatically

### 🎨 RxSwift Support

Auto-detects and imports RxSwift when mocks contain:
- `Single<T>` return types
- `Completable` return types

Generates proper `.just()` and `.failure()` chains.

### 💾 Settings Persistence

Module Name, Author Name, and App Name are saved to UserDefaults and restored on next launch.

### ⚡ Reactive Generation

Mock updates in real-time as you type—see the result immediately in the right panel.

## UI Layout

**Left Panel**
- Protocol input field with placeholder example
- Module Name, Author Name, App Name settings

**Right Panel**
- Live generated mock code
- Smooth scrolling with text selection enabled
- Copy button for full mock export

## Usage

1. Paste a Swift protocol into the left panel
2. Fill in Module, Author, and App names (auto-saved)
3. Watch the mock generate in real-time on the right
4. Select and copy individual sections, or use **Copy to Clipboard** for the entire mock
5. Paste into your test file

## Example

**Input Protocol**
```swift
protocol UserInteractorProtocol {
    func getUser(id: String) async throws -> User
    func getUser(for email: String) -> Single<User>
}
```

**Generated Mock**
```swift
final class UserInteractorMock: UserInteractorProtocol {
    
    var isGetUserSuccess = true
    private(set) var getUserCallCount = 0
    private(set) var getUserId: String?

    var isGetUser2Success = true
    private(set) var getUser2CallCount = 0
    private(set) var getUser2Email: String?

    func getUser(id: String) async throws -> User {
        getUserCallCount += 1
        getUserId = id

        if isGetUserSuccess {
            let response: User! = Data.getResponse(
                bundleClass: Self.self,
                jsonName: "UserTest",
                responseType: User.self
            )
            return response
        } else {
            throw SystemError.common
        }
    }

    func getUser(for email: String) -> Single<User> {
        getUser2CallCount += 1
        getUser2Email = email

        if isGetUser2Success {
            let response: User! = Data.getResponse(
                bundleClass: Self.self,
                jsonName: "UserTest",
                responseType: User.self
            )
            return .just(response)
        } else {
            return .failure(SystemError.common)
        }
    }
}
```

## Architecture

- **MockGenParser**: Tokenizes and parses Swift protocol syntax
- **MockGenCodeGenerator**: Builds mock class with proper formatting, naming, and return logic
- **ContentView**: macOS SwiftUI interface with split panels and live updates

## Keyboard Shortcuts

- **⌘A**: Select all text in active field
- **⌘C**: Copy selected text (or entire mock code via button)
- **⌘V**: Paste
- **⌘X**: Cut

## Requirements

- macOS 12.0+
- Swift 5.5+
- Optional: RxSwift dependency (auto-detected)

## License

Copyright © 2026. All rights reserved.
