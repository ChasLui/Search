import AppKit
import SwiftUI

enum InterfaceLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    @MainActor var title: String {
        switch self {
        case .system: return Language.shared.text("language.system", fallback: "Follow Mac")
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        }
    }
}

/// The interface language is shared by every window, but is separate from the
/// language chosen for translating web pages.
@MainActor
final class Language: ObservableObject {
    static let shared = Language()
    static let didChange = Notification.Name("SearchInterfaceLanguageDidChange")

    private static let key = "ui.language"
    static let resources: Bundle = {
        if Bundle.main.bundleURL.pathExtension == "app",
           Bundle.main.path(forResource: "en", ofType: "lproj") != nil { return .main }
        return .module
    }()

    @Published private(set) var selection: InterfaceLanguage
    @Published private(set) var effective: InterfaceLanguage
    private var bundle: Bundle
    private var changes: NSObjectProtocol?

    private init() {
        let saved = Store.settings.string(forKey: Self.key).flatMap(InterfaceLanguage.init(rawValue:)) ?? .system
        let effective = Self.resolve(saved, preferred: Locale.preferredLanguages)
        self.selection = saved
        self.effective = effective
        self.bundle = Self.bundle(for: effective)
        changes = NotificationCenter.default.addObserver(
            forName: NSLocale.currentLocaleDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    static func resolve(_ selection: InterfaceLanguage, preferred: [String]) -> InterfaceLanguage {
        guard selection == .system else { return selection }
        for identifier in preferred {
            let language = Locale.Language(identifier: identifier)
            switch language.languageCode?.identifier {
            case "en": return .english
            case "zh":
                if language.script?.identifier == "Hans" { return .simplifiedChinese }
                if language.script?.identifier == "Hant" || ["HK", "MO", "TW"].contains(language.region?.identifier ?? "") {
                    continue
                }
                return .simplifiedChinese
            default: continue
            }
        }
        return .english
    }

    private static func bundle(for language: InterfaceLanguage) -> Bundle {
        let path = resources.path(forResource: language.rawValue, ofType: "lproj")
        return path.flatMap(Bundle.init(path:)) ?? resources
    }

    private static let chineseBundle = bundle(for: .simplifiedChinese)

    static func matches(_ title: String, english: String) -> Bool {
        title == english || title == chineseBundle.localizedString(forKey: english, value: english, table: nil)
    }

    var locale: Locale {
        let region = Locale.current.region.map { "_\($0.identifier)" } ?? ""
        return Locale(identifier: effective.rawValue + region)
    }

    func select(_ choice: InterfaceLanguage) {
        guard selection != choice else { return }
        selection = choice
        Store.settings.set(choice.rawValue, forKey: Self.key)
        refresh()
    }

    private func refresh() {
        let next = Self.resolve(selection, preferred: Locale.preferredLanguages)
        guard next != effective else { return }
        bundle = Self.bundle(for: next)
        effective = next
        NotificationCenter.default.post(name: Self.didChange, object: nil)
    }

    func text(_ key: String, fallback: String) -> String {
        bundle.localizedString(forKey: key, value: fallback, table: nil)
    }

    func format(_ key: String, fallback: String, _ arguments: CVarArg...) -> String {
        String(format: text(key, fallback: fallback), locale: locale, arguments: arguments)
    }

    func count(_ key: String, _ count: Int) -> String {
        let format = bundle.localizedString(forKey: key, value: key, table: nil)
        return String(format: format, locale: locale, count)
    }
}

/// A hosting view has its own SwiftUI environment, even when it belongs to
/// a window already showing another hosting view.
struct LanguageRoot<Content: View>: View {
    @ObservedObject private var language = Language.shared
    var content: Content

    var body: some View { content.environment(\.locale, language.locale) }
}

struct CountText: View {
    @ObservedObject private var language = Language.shared
    let key: String
    let count: Int

    var body: some View { Text(language.count(key, count)) }
}
