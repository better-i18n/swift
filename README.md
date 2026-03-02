<div align="center">
  <img src="https://better-i18n.com/logo.png" alt="better-i18n" width="120" />
  <h1>BetterI18n Swift SDK</h1>
  <p>Native Swift SDK for better-i18n CDN — fetch, cache, and serve translations in iOS, macOS, watchOS, and tvOS apps.</p>

  [![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
  [![Platforms](https://img.shields.io/badge/Platforms-iOS%2015%20%7C%20macOS%2012%20%7C%20watchOS%208%20%7C%20tvOS%2015-blue.svg)](https://github.com/better-i18n/swift)
  [![SPM](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://swift.org/package-manager)
  [![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)](LICENSE)
</div>

---

## Features

- **Over-The-Air Translations** — fetch the latest strings from the better-i18n CDN without an App Store update
- **Offline-First** — serves from memory cache or UserDefaults when the network is unavailable
- **SwiftUI Integration** — `I18nProvider` + `I18nStore` with `@EnvironmentObject` support
- **Widget / App Group Support** — main app and WidgetKit extensions share translations via `AppGroupStorage`
- **Dot-notation Keys** — `t("auth.login.title")` resolves nested JSON automatically
- **Variable Interpolation** — `t("welcome", ["name": "Osman"])` → `"Hello, Osman!"`
- **Locale Detection** — matches device language to available CDN locales (BCP 47 best-match)
- **No Dependencies** — pure Swift, no third-party packages

---

## Requirements

| Platform | Minimum Version |
|----------|----------------|
| iOS      | 15.0+          |
| macOS    | 12.0+          |
| watchOS  | 8.0+           |
| tvOS     | 15.0+          |

---

## Installation

### Swift Package Manager

In Xcode: **File → Add Package Dependencies** and enter:

```
https://github.com/better-i18n/swift
```

Or add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/better-i18n/swift", from: "0.1.0")
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "BetterI18n", package: "swift"),   // Core (no UI)
            .product(name: "BetterI18nUI", package: "swift"),  // SwiftUI layer
        ]
    )
]
```

---

## Quick Start

### 1. Configure in App.swift

```swift
import SwiftUI
import BetterI18n
import BetterI18nUI

@main
struct MyApp: App {
    let i18n = BetterI18n(config: I18nConfig(
        project: "my-org/my-app",   // your better-i18n project slug
        defaultLocale: "en"
    ))

    var body: some Scene {
        WindowGroup {
            I18nProvider(core: i18n) {
                ContentView()
            }
        }
    }
}
```

### 2. Use translations in views

```swift
import SwiftUI
import BetterI18nUI

struct ContentView: View {
    @EnvironmentObject var i18n: I18nStore

    var body: some View {
        VStack {
            Text(i18n.t("home.title"))
            Text(i18n.t("welcome.message", ["name": "Osman"]))

            // Language picker
            Picker("Language", selection: Binding(
                get: { i18n.locale },
                set: { newLocale in Task { await i18n.setLocale(newLocale) } }
            )) {
                ForEach(i18n.languages) { lang in
                    Text(lang.nativeName ?? lang.name).tag(lang.code)
                }
            }
        }
        .opacity(i18n.isLoaded ? 1 : 0)
    }
}
```

---

## Core API (without SwiftUI)

Use `BetterI18n` directly in ViewModels, services, or non-SwiftUI contexts:

```swift
import BetterI18n

let i18n = BetterI18n(config: I18nConfig(
    project: "my-org/my-app",
    defaultLocale: "en"
))

// Detect best locale for the device
let locale = try await i18n.detectLocale()  // "tr"

// Get a translator
let t = try await i18n.getTranslator(locale: locale)

// Translate keys
print(t("auth.login.title"))                         // "Giriş Yap"
print(t("welcome.message", ["name": "Osman"]))       // "Merhaba, Osman!"
print(t["auth.login.button"])                        // subscript syntax

// Get available languages
let languages = try await i18n.getLanguages()
// [LanguageOption(code: "tr", name: "Turkish", nativeName: "Türkçe"), ...]
```

---

## Configuration

```swift
let config = I18nConfig(
    project: "my-org/my-app",           // Required: "org/project" slug
    defaultLocale: "en",                // Required: fallback locale
    cdnBaseUrl: "https://cdn.better-i18n.com",  // Optional: custom CDN
    manifestCacheTtlMs: 300_000,        // Optional: cache TTL (5 min default)
    fetchTimeout: 10,                   // Optional: request timeout in seconds
    retryCount: 1,                      // Optional: retry count on failure
    debug: false                        // Optional: print debug logs
)
```

---

## Widget / App Group Support

Share translations between your main app and WidgetKit extensions:

```swift
// Main App — configure with appGroupIdentifier
let config = I18nConfig(
    project: "my-org/my-app",
    defaultLocale: "tr",
    appGroupIdentifier: "group.com.mycompany.myapp"  // enables AppGroupStorage
)

// Widget Extension — reads the same storage automatically
// Storage keys are identical to the JS SDK:
//   @better-i18n:messages:my-org/my-app:tr
```

The widget doesn't need to make CDN requests — it reads from the App Group storage that the main app already populated.

---

## Advanced

### Manual refresh

```swift
// Force re-fetch manifest from CDN (ignores cache)
let manifest = try await i18n.getManifest(forceRefresh: true)
```

### Save user language preference

```swift
// Persists to storage — detectLocale() returns this next time
await i18n.saveLocalePreference("ar")
```

### Custom storage

```swift
// Implement TranslationStorage for Keychain, CoreData, etc.
actor KeychainStorage: TranslationStorage {
    func get(_ key: String) -> String? { /* ... */ }
    func set(_ key: String, value: String) { /* ... */ }
    func remove(_ key: String) { /* ... */ }
}

let config = I18nConfig(
    project: "my-org/my-app",
    defaultLocale: "en",
    storage: KeychainStorage()
)
```

---

## Storage Key Schema

Compatible with the better-i18n JS SDK — same keys, same format:

| Type | Key |
|------|-----|
| Manifest | `@better-i18n:manifest:{project}` |
| Translations | `@better-i18n:messages:{project}:{locale}` |
| Locale preference | `@better-i18n:locale:{project}` |

---

## License

MIT © [better-i18n](https://better-i18n.com)
