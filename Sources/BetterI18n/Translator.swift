import Foundation

/// Belirli bir locale için çevirileri sunan value type.
///
/// `callAsFunction` ile `t("auth.login.title")` şeklinde JS API'sini mirror eder.
/// Dot-notation key resolution: `"auth.login.title"` → messages["auth"]["login"]["title"]
/// Interpolation: `{name}` → value (JS SDK ile aynı format)
/// Fallback: key bulunamazsa key string'i döner — hiçbir zaman crash etmez.
public struct Translator: @unchecked Sendable {
    private let messages: [String: Any]
    let locale: String

    init(messages: [String: Any], locale: String) {
        self.messages = messages
        self.locale = locale
    }

    // MARK: - callAsFunction

    /// Çeviriyi döner. Key bulunamazsa key string'ini döner (crash olmaz).
    ///
    ///     let title = t("auth.login.title")
    public func callAsFunction(_ key: String) -> String {
        resolve(key) ?? key
    }

    /// Değişken ikamesiyle çeviriyi döner.
    ///
    ///     let message = t("welcome.message", ["name": "Osman"])
    ///     // "Merhaba, Osman!" ← template: "Merhaba, {name}!"
    public func callAsFunction(_ key: String, _ variables: [String: String]) -> String {
        guard let template = resolve(key) else { return key }
        return StringInterpolator.interpolate(template, variables: variables)
    }

    // MARK: - Subscript

    /// Subscript kolaylığı — aynı davranış, farklı sözdizimi.
    ///
    ///     let title = t["auth.login.title"]
    public subscript(key: String) -> String {
        callAsFunction(key)
    }

    // MARK: - Private

    /// Dot-notation key'i messages nested dict'inden recursive olarak çözer.
    private func resolve(_ key: String) -> String? {
        let parts = key.components(separatedBy: ".")
        var current: Any = messages

        for part in parts {
            guard let dict = current as? [String: Any],
                  let next = dict[part] else {
                return nil
            }
            current = next
        }

        return current as? String
    }
}
