import Foundation

// The address field doubles as the most basic kind of command line: a
// handful of words that mean "go here in the app" rather than "go here on
// the web". Only the whole word runs on Return, so a search that starts
// with one still searches; part of a word is just offered lower in the
// list. Off by default (Settings › Spaces & Pins ›
// Opening and starting › Address bar commands): nobody typing "settings" into a browser
// expects the app to open its own panel instead of asking Google.
//
// With it on, every menu command (Shortcuts.swift's Command) is offered
// too, as in Arc's Command Bar, found by the words of its name, and every
// Settings page by its name: under what was typed, so Return still goes
// where it went, and run through the menu's own action.

@MainActor
enum AddressCommand: Equatable {
    case settings
    case newTab
    case newPrivateTab
    case newSpace
    case bookmarks
    case history
    case downloads
    case passwords
    case toggleSidebar
    /// A menu command, by its id in Command.all.
    case menu(String)
    /// A Settings page, opened on that page.
    case page(SettingsPanel.Page)

    /// The words, which run on Return when typed whole.
    static let allCases: [AddressCommand] = [
        .settings, .newTab, .newPrivateTab, .newSpace, .bookmarks, .history, .downloads, .passwords, .toggleSidebar,
    ]

    /// What you'd type to reach it. The first is what the list shows.
    var aliases: [String] {
        let english: [String]
        switch self {
        case .settings: english = ["settings", "preferences"]
        case .newTab: english = ["new tab"]
        case .newPrivateTab: english = ["new private tab", "private tab"]
        case .newSpace: english = ["new space"]
        case .bookmarks: english = ["bookmarks"]
        case .history: english = ["history"]
        case .downloads: english = ["downloads"]
        case .passwords: english = ["passwords"]
        case .toggleSidebar: english = ["toggle sidebar", "sidebar"]
        case .menu(let id): english = [Command.named(id)?.title ?? id]
        case .page(let page): english = ["\(page.title) Settings"]
        }
        guard Language.shared.effective == .simplifiedChinese else { return english }
        let chinese: [String]
        switch self {
        case .settings: chinese = ["设置", "偏好设置"]
        case .newTab: chinese = ["新建标签页", "新标签页"]
        case .newPrivateTab: chinese = ["新建无痕标签页", "无痕标签页"]
        case .newSpace: chinese = ["新建空间"]
        case .bookmarks: chinese = ["书签"]
        case .history: chinese = ["历史记录"]
        case .downloads: chinese = ["下载"]
        case .passwords: chinese = ["密码"]
        case .toggleSidebar: chinese = ["切换侧边栏", "侧边栏"]
        case .menu(let id):
            chinese = [Command.named(id)?.localizedTitle ?? english[0]]
        case .page(let page): chinese = ["\(page.localizedTitle)设置"]
        }
        return chinese + english
    }

    var title: String {
        switch self {
        case .menu, .page: return aliases[0]
        default: return aliases[0].localizedCapitalized
        }
    }

    /// The menu command that does the same, whose key the row shows.
    var commandID: String? {
        switch self {
        case .settings: return "app.settings"
        case .newTab: return "file.newTab"
        case .newPrivateTab: return "file.newPrivateTab"
        case .bookmarks: return "bookmarks.show"
        case .history: return "history.show"
        case .downloads: return "history.downloads"
        case .passwords: return "app.passwords"
        case .toggleSidebar: return "view.sidebar"
        case .menu(let id): return id
        case .newSpace, .page: return nil
        }
    }

    /// Its key as it stands, as the menu writes it: "⇧⌘N".
    var key: String? { commandID.flatMap { ShortcutStore.shared.key(for: $0)?.display } }

    /// Some only mean something once the feature behind them is even on.
    func available(in browser: Browser) -> Bool {
        switch self {
        case .newSpace: return browser.prefs.usesSpaces
        case .menu(let id): return Self.offers(id, in: browser)
        case .page(let page): return page != .ai || AI.shipped
        default: return true
        }
    }

    func run(on browser: Browser) {
        switch self {
        case .settings: browser.tuning = true
        case .newTab: browser.newTab()
        case .newPrivateTab: browser.newShyTab()
        case .newSpace: browser.askForSpace()
        case .bookmarks: browser.bookmarking = true
        case .history: browser.recalling = true
        case .downloads: browser.showDownloads()
        case .passwords: browser.managing = true
        case .toggleSidebar: browser.toggleSidebar()
        case .menu(let id): Command.named(id)?.run(browser)
        case .page(let page):
            browser.settingsPage = page
            browser.tuning = true
        }
    }

    /// The command whose words are all that was typed, if any. Only the
    /// whole thing: a command must not take a search from anyone, so
    /// "settings for gmail" or "sett" still searches.
    static func matching(_ typed: String, in browser: Browser) -> AddressCommand? {
        let needle = typed.trimmingCharacters(in: .whitespaces).lowercased()
        return allCases.first { $0.available(in: browser) && $0.aliases.contains(needle) }
    }

    /// A command that partly matches: "down", "dwn" or "downlaods" for
    /// Downloads. From three letters, and only offered, never run on Return.
    static func near(_ typed: String, in browser: Browser) -> AddressCommand? {
        let needle = typed.trimmingCharacters(in: .whitespaces).lowercased()
        let minimum = needle.unicodeScalars.contains { $0.properties.isIdeographic } ? 2 : 3
        guard needle.count >= minimum, matching(needle, in: browser) == nil else { return nil }
        let letters = Array(needle.utf8)
        let available = allCases.filter { $0.available(in: browser) }
        // Closest match first, then the order above.
        let tests: [(String) -> Bool] = [
            { $0.hasPrefix(needle) || $0.split(separator: " ").contains { $0.hasPrefix(needle) } },
            { $0.split(separator: " ").contains { Fuzzy.abbreviates(needle, $0) } },
            { Fuzzy.nearly(letters, in: $0) },
        ]
        for test in tests {
            if let found = available.first(where: { $0.aliases.contains(where: test) }) { return found }
        }
        return nil
    }

    /// Menu commands that make no sense from the field: it is already open,
    /// there is nothing found to step through, or the key must be held.
    private static let unoffered: Set<String> = [
        "file.openAddress", "edit.findNext", "edit.findPrevious", Command.recentTabs, "tabs.search",
    ]
    /// Those the menu greys out without a web page in front.
    private static let needsPage: Set<String> = [
        "file.share", "file.savePage", "file.exportPDF", "file.print", "edit.copyCleanLink", "view.reader",
        "view.summarize", "view.ask", "tabs.duplicate", "tabs.copyAddress", "tabs.copyMarkdown", "bookmarks.add",
        "view.style",
    ]
    /// More words for a few, the ones other browsers use.
    private static let alsoCalled: [String: String] = [
        "view.reader": "reader view", "tabs.mute": "mute", "view.float": "picture in picture pip",
        "view.inspector": "devtools developer tools", "bookmarks.add": "bookmark", "view.hide": "zapper",
        "view.style": "boost css",
    ]

    /// A menu command, offered only where the menu has it, and enabled.
    private static func offers(_ id: String, in browser: Browser) -> Bool {
        guard let command = Command.named(id), !unoffered.contains(id) else { return false }
        let prefs = browser.prefs
        if command.section == .spaces, !prefs.usesSpaces { return false }
        if Command.split.contains(id) {
            guard prefs.splitView else { return false }
            if id != "tabs.split", browser.activeSplit == nil { return false }
        }
        if Command.ai.contains(id), !prefs.ai { return false }
        if Command.dusk.contains(id), !prefs.darkensPages { return false }
        if Command.archive.contains(id), prefs.tabLife == .never { return false }
        if Command.capture.contains(id), !prefs.capturesPages { return false }
        if Command.styles.contains(id), !prefs.sitesStyles || browser.active?.shy == true { return false }
        if id == "view.sitePanel", !prefs.sitesInPanel { return false }
        if id == "tabs.pinRow", !prefs.showsPinRows { return false }
        if id == "view.foldGroups", !browser.canFoldAllGroups { return false }
        if id == "view.unfoldGroups", !browser.canUnfoldAllGroups { return false }
        if needsPage.contains(id), browser.active?.isWeb != true { return false }
        return true
    }

    /// Menu commands and Settings pages every typed word begins a word of,
    /// in any order: "priv tab" for New Private Tab, "hide el" for Hide
    /// Elements…, "appear" for Appearance Settings. Those whose name starts
    /// with what was typed first, then the menus' order; never a command
    /// one of the words above already stands for. From three letters, and
    /// never for an address.
    static func listed(_ typed: String, in browser: Browser, limit: Int = 4) -> [AddressCommand] {
        let needle = typed.trimmingCharacters(in: .whitespaces).lowercased()
        let minimum = needle.unicodeScalars.contains { $0.properties.isIdeographic } ? 2 : 3
        guard needle.count >= minimum, Address.url(from: needle) == nil else { return [] }
        let asked = needle.split(separator: " ")
        let taken = Set([matching(needle, in: browser), near(needle, in: browser)].compactMap { $0?.commandID })
        let candidates = Command.all.map { AddressCommand.menu($0.id) }
            + SettingsPanel.Page.allCases.map { AddressCommand.page($0) }
        var first: [AddressCommand] = [], rest: [AddressCommand] = []
        for candidate in candidates {
            if let id = candidate.commandID, taken.contains(id) { continue }
            let names = candidate.aliases.map { $0.lowercased().replacingOccurrences(of: "…", with: "") }
            let extra = candidate.commandID.flatMap { alsoCalled[$0] } ?? ""
            let matches = names.contains { name in
                let words = (name + " " + extra).split(separator: " ")
                return asked.allSatisfy { typed in words.contains { $0.hasPrefix(typed) } }
            }
            guard matches,
                  candidate.available(in: browser) else { continue }
            if names.contains(where: { $0.hasPrefix(needle) }) { first.append(candidate) } else { rest.append(candidate) }
        }
        return Array((first + rest).prefix(limit))
    }
}
