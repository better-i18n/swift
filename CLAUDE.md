# Better i18n Swift SDK — Claude Code Context

## What This Is

Native Swift SDK for the Better i18n localization platform. Provides CDN-based translation loading with offline-first two-phase loading, designed to mirror the JavaScript SDK architecture.

## AI Assistant Guidelines

- **Package manager:** Swift Package Manager (SPM)
- **Base branch:** `main`
- **Tests:** `swift test`
- **No external dependencies** — pure Swift, zero third-party packages
- **Conventional commits required** — `feat:`, `fix:`, `refactor:`, `docs:`, `chore:`
- **Only stage files YOU changed** — use `git add <specific-files>`, NEVER `git add .`
- **Linear ticket'ları güncelle** — Commit sonrası ilgili Linear issue varsa (BETTER-xxx) `mcp__linear-server__save_issue` ile "Done" yap. Commit mesajında ticket ID referans ver.

## Architecture

Two libraries mirroring the JS SDK separation:

| Library | Purpose | Dependencies |
|---------|---------|-------------|
| `BetterI18n` | Core: CDN fetch, TtlCache, storage, locale detection | None |
| `BetterI18nUI` | SwiftUI: `I18nProvider`, `I18nStore` (ObservableObject) | `BetterI18n` |

**Platforms:** iOS 15+, macOS 12+, watchOS 8+, tvOS 15+

## JS SDK Architecture Mirror

The Swift SDK intentionally mirrors the JS SDK (`@better-i18n/core`) patterns:

| JS SDK | Swift SDK | Notes |
|--------|-----------|-------|
| `TtlCache` (module-level) | `actor TtlCache<T>` | Actor isolation replaces JS singleton |
| `createI18nCore()` | `BetterI18n(config:)` | Main entry class |
| `getMessages(locale)` | `getTranslator(locale:)` | Returns `Translator` (callable) |
| 5-layer fallback chain | Same: TtlCache → CDN → Storage → staticData → throw | |
| `normalizeLocale()` | `LocaleDetector.normalize()` | BCP 47 lowercase |
| `{key}` interpolation | `StringInterpolator` | Same `{key}` → value syntax |

## TtlCache (Actor-Based)

`Sources/BetterI18n/TtlCache.swift`

```swift
actor TtlCache<T> {
    func get(_ key: String) -> T?      // Lazy eviction on read
    func set(_ key: String, value: T, ttlMs: Double)
    func invalidate(_ key: String)
    func clear()
}
```

- **Actor isolation** replaces locks/mutexes — safe for Swift concurrency
- **Lazy eviction:** expired entries deleted on access, not proactively (matches JS SDK)
- **No max-size cap** (unlike helpcenter's 50-entry ssrMessagesByRequest)
- Two instances in `BetterI18n`: one for manifests, one for messages

**Cache key format (same as JS SDK):**
- Manifest: `{cdnBaseUrl}|{project}`
- Messages: `{cdnBaseUrl}|{project}|{locale}`

## Storage Key Format (Cross-Platform Compatible)

Keys are identical to the JS SDK — an Expo/React Native app writing to the same App Group storage can be read by a WidgetKit extension using this SDK.

| Type | Key |
|------|-----|
| Manifest | `@better-i18n:manifest:{project}` |
| Messages | `@better-i18n:messages:{project}:{locale}` |
| Locale preference | `@better-i18n:locale:{project}` |

**Storage selection priority:**
1. Explicit `config.storage` (custom `TranslationStorage` conformance)
2. `AppGroupStorage(suiteName:)` if `config.appGroupIdentifier` set (for widgets)
3. `UserDefaultsStorage()` default

## Two-Phase Loading Pattern (CRITICAL)

`Sources/BetterI18nUI/I18nStore.swift` — `load()` method

### Phase 1 — Instant (No Network)

```
detectLocaleFromStorageOnly()      → storage only
getManifestFromStorageOnly()       → TtlCache → storage
getTranslatorFromStorageOnly()     → TtlCache → storage
→ If all available: isLoaded = true, render immediately with stale data
```

### Phase 2 — CDN Refresh (Always Runs)

```
detectLocale()      → storage pref → CDN manifest → BCP 47 match → defaultLocale
getLanguages()      → TtlCache → CDN
getTranslator()     → TtlCache → CDN
→ Update published properties, isRefreshing = false
→ If Phase 1 succeeded and Phase 2 fails: error silently swallowed, stale data preserved
```

**This ensures the UI never shows a loading spinner on app relaunch if translations were previously cached.**

## CDN Client

`Sources/BetterI18n/CDNClient.swift` — `actor CDNClient`

- All requests: `Cache-Control: no-cache` header
- Retry: exponential backoff (`2^attempt` seconds), up to `config.retryCount` (default 1)
- `CancellationError` re-thrown immediately (no retry)
- Manifest URL: `{cdnBaseUrl}/{project}/manifest.json`
- Translation URL: from `manifest.files[locale].url`, fallback to `{cdnBaseUrl}/{project}/{locale}/translations.json`

## Project Structure

```
swift/
├── Package.swift              # SPM config: BetterI18n + BetterI18nUI
├── Sources/
│   ├── BetterI18n/            # Core (no SwiftUI)
│   │   ├── BetterI18n.swift   # Main entry class (@unchecked Sendable)
│   │   ├── I18nConfig.swift   # Configuration struct
│   │   ├── CDNClient.swift    # Network actor (retry, exponential backoff)
│   │   ├── TtlCache.swift     # In-memory TTL cache (actor)
│   │   ├── TranslationStorage.swift  # Protocol + UserDefaultsStorage
│   │   ├── AppGroupStorage.swift     # Widget/App Group storage
│   │   ├── ManifestResponse.swift    # CDN response models
│   │   ├── Translator.swift          # Translation resolver (callAsFunction)
│   │   ├── LocaleDetector.swift      # BCP 47 locale matching
│   │   └── StringInterpolator.swift  # {key} → value substitution
│   └── BetterI18nUI/          # SwiftUI layer
│       ├── I18nStore.swift          # @MainActor ObservableObject (two-phase load)
│       ├── I18nProvider.swift       # View wrapper (injects store)
│       └── I18nEnvironmentKey.swift # EnvironmentValues extension
└── Tests/
    └── BetterI18nTests/
        ├── TtlCacheTests.swift
        ├── CDNClientTests.swift     # Includes MockStorage, two-phase tests
        ├── TranslatorTests.swift
        └── LocaleDetectorTests.swift
```

## graphify

This project has a graphify knowledge graph at graphify-out/.

Rules:
- Before answering architecture or codebase questions, read graphify-out/GRAPH_REPORT.md for god nodes and community structure
- If graphify-out/wiki/index.md exists, navigate it instead of reading raw files
- After modifying code files in this session, run `python3 -c "from graphify.watch import _rebuild_code; from pathlib import Path; _rebuild_code(Path('.'))"` to keep the graph current

## Debugging (CRITICAL — Log + Code methodology)

When ANY error is reported or suspected, ALWAYS read logs FIRST:
1. **Logs first** → Check test output, Xcode logs, or any available runtime logs — find exact error, stack trace, timestamp
2. **Code second** → With log context, read the failing file/line — understand WHY it broke
3. **Fix with precision** → Logs show reality, code shows intent. The gap = the bug.

**Never debug by code-reading alone.** You'll guess at symptoms and risk false fixes. Logs pinpoint; code explains. Together = surgical fix.
