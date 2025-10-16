# EverydayApp

Scaffolded SwiftUI iOS 17+ application prepared with a modular MVVM architecture, Firebase integration points, theming, and reusable UI components. The project is ready to expand into a production household companion experience featuring Home, Tasks, Shopping, and Profile areas.

## Requirements

- Xcode 15 or later (iOS 17+ SDK)
- Swift 5.9+
- CocoaPods is **not** required (all dependencies managed through Swift Package Manager)

## Project Structure

```
EverydayApp/
├─ App/
│  ├─ EverydayAppApp.swift        # Entry point & scene configuration
│  └─ RootTabView.swift           # Tab-based navigation shell
├─ Features/                      # Feature-first MVVM modules
│  ├─ Home/
│  │  ├─ ViewModels/
│  │  └─ Views/
│  ├─ Tasks/
│  ├─ Shopping/
│  └─ Profile/
├─ Models/                        # Codable domain models
├─ Services/
│  ├─ Firebase/                   # Firebase configuration & auth/messaging services
│  └─ Networking/                 # Alamofire-backed networking layer
├─ Shared/
│  ├─ Components/                 # Reusable SwiftUI building blocks
│  ├─ Environment/                # AppEnvironment + theme environment key
│  └─ Theme/                      # Color palette, typography, spacing, theme definitions
├─ Resources/
│  ├─ Assets.xcassets/            # Color & icon assets
│  └─ Preview Content/            # SwiftUI preview assets
└─ Configurations/
   ├─ Debug.xcconfig
   ├─ Release.xcconfig
   └─ Secrets.template.xcconfig
```

The repository also includes `EverydayApp.xcodeproj`, preconfigured with the targets, build settings, and Swift Package Manager dependencies described below.

## Architecture Guidelines

- **MVVM + Feature Folders**: Each feature exposes `Views` and `ViewModels`, keeping state & domain logic close to the UI that consumes it. Shared state (e.g., authentication) lives in `AppEnvironment`.
- **Services Layer**: Isolate integrations such as Firebase Auth/Messaging and networking to dedicated services. Protocols (`FirebaseAuthServicing`, `NetworkServicing`) make mocking and testing straightforward.
- **Environment Management**: `AppEnvironment` is provided to the SwiftUI hierarchy and handles configuration values (`AppConfiguration`) plus Firebase authentication state.
- **Theming**: `AppTheme` centralises palette, typography, and spacing while exposing an `EnvironmentKey` for consistent styling via `Environment(\.appTheme)`.

## Dependencies (Swift Package Manager)

| Package | URL | Notes |
| ------- | --- | ----- |
| Firebase iOS SDK | `https://github.com/firebase/firebase-ios-sdk` | Auth, Firestore, Messaging, Analytics, Core |
| CombineExt | `https://github.com/CombineCommunity/CombineExt` | Ergonomic Combine operators (`weakAssign`, `shareReplay`, etc.) |
| Alamofire | `https://github.com/Alamofire/Alamofire` | Type-safe REST networking layer |

Packages are resolved directly in the Xcode project; opening `EverydayApp.xcodeproj` will trigger dependency resolution automatically.

## Build Configurations & Secrets

- `Debug.xcconfig` and `Release.xcconfig` contain configuration values such as bundle identifiers, API hosts, and compile-time flags.
- `Secrets.template.xcconfig` documents the sensitive keys (Firebase, analytics, etc.). Copy it to `Secrets.xcconfig` (ignored via `.gitignore`) and populate with real values.
- Info.plist includes placeholder keys (`API_BASE_URL`, `ANALYTICS_API_KEY`, `APP_ENVIRONMENT`) bound to the xcconfig settings.
- Firebase configuration automatically checks for `GoogleService-Info.plist` and safely skips configuration when absent, supporting local development without secrets.

## UI Foundation

- **Root Navigation**: `RootTabView` hosts four primary tabs – Home, Tasks, Shopping, Profile – each backed by placeholder MVVM modules.
- **Reusable Components**: `PrimaryButton`, `AppListRow`, and `AppFormSection` deliver consistent styling for interactive elements, lists, and forms.
- **Theme & Assets**: Color assets (`Primary`, `Secondary`, `AppBackground`, `AccentColor`) back the theme palette. Typography and spacing scales provide consistent sizing.

## Getting Started

1. Open `EverydayApp.xcodeproj` in Xcode 15+.
2. Copy `Configurations/Secrets.template.xcconfig` to `Configurations/Secrets.xcconfig` and add any environment secrets required (API keys, Firebase plist name, etc.).
3. Add your Firebase `GoogleService-Info.plist` to the project root if you need Firebase services locally.
4. Select the **EverydayApp** scheme, choose an iOS 17+ simulator, and run.

## Coding Standards

- Prefer value semantics (`struct`) for models; use `ObservableObject` for view models with `@Published` state.
- Keep feature-specific types inside their respective feature folders; promote to `Shared/` only when reused.
- Use `AppTheme` and shared components for visual styling rather than ad-hoc modifiers to maintain consistency.
- Inject services via initialisers to keep view models testable; reference protocols (`NetworkServicing`, `FirebaseAuthServicing`) in abstractions.
- SwiftUI previews should provide required environment dependencies (`AppTheme`, `AppEnvironment`) to mirror runtime behaviour.

## Next Steps

- Flesh out real data flows by backing services with Firestore and live APIs.
- Expand unit test coverage by introducing a Tests target and mocks for `AppEnvironment` and service protocols.
- Integrate analytics events using the configured Firebase/analytics services as screens and interactions mature.

This scaffold establishes the foundation for a modern, modular SwiftUI application ready to evolve into a production product.
