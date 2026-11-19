import AppKit
import SwiftUI
import XCTest
@testable import Search

@MainActor
final class LanguageTests: XCTestCase {
    override class func setUp() {
        setenv("SEARCH_PROBE", "language-\(getpid())", 1)
        super.setUp()
    }

    func testSystemLanguageUsesTheFirstSupportedPreference() {
        XCTAssertEqual(Language.resolve(.system, preferred: ["ja-JP", "zh-Hans-CN", "en-US"]), .simplifiedChinese)
        XCTAssertEqual(Language.resolve(.system, preferred: ["zh-Hant-TW", "en-US"]), .english)
        XCTAssertEqual(Language.resolve(.system, preferred: ["zh-Hans-TW", "en-US"]), .simplifiedChinese)
        XCTAssertEqual(Language.resolve(.system, preferred: ["zh-Hant-CN", "en-US"]), .english)
        XCTAssertEqual(Language.resolve(.system, preferred: ["ja-JP"]), .english)
        XCTAssertEqual(Language.resolve(.english, preferred: ["zh-Hans-CN"]), .english)
    }

    func testSwitchingResourcesAndPluralForms() {
        let language = Language.shared
        let before = language.selection
        defer { language.select(before) }

        language.select(.english)
        XCTAssertEqual(language.text("settings.general.language.title", fallback: ""), "Interface language")
        XCTAssertEqual(language.count("count.tabs", 1), "1 tab")
        XCTAssertEqual(language.count("count.tabs", 2), "2 tabs")
        XCTAssertEqual(language.count("count.remove_shown_button", 2), "Remove 2…")
        XCTAssertEqual(language.count("count.remove_passwords", 2), "Remove 2 Passwords?")
        XCTAssertEqual(language.count("count.addresses_copied", 1), "1 address copied")
        XCTAssertEqual(language.count("count.addresses_copied", 2), "2 addresses copied")

        language.select(.simplifiedChinese)
        XCTAssertEqual(language.count("count.remove_shown_button", 2), "移除 2 项…")
        XCTAssertEqual(language.count("count.remove_passwords", 2), "移除 2 个密码？")
        XCTAssertEqual(language.text("settings.general.language.title", fallback: ""), "界面语言")
        XCTAssertEqual(language.count("count.tabs", 1), "1 个标签页")
        XCTAssertEqual(language.count("count.tabs", 2), "2 个标签页")
        XCTAssertEqual(language.count("count.addresses_copied", 2), "已复制 2 个地址")
        XCTAssertEqual(language.text("missing.key", fallback: "fallback"), "fallback")
        XCTAssertEqual(Store.settings.string(forKey: "ui.language"), "zh-Hans")
    }

    func testLanguageEnvironmentReachesBothOpenWindows() {
        _ = NSApplication.shared
        let language = Language.shared
        let before = language.selection
        language.select(.english)
        var seen: [[String]] = [[], []]
        var windows: [NSWindow] = []
        defer {
            language.select(before)
            for window in windows { window.contentView = nil; window.close() }
        }
        for index in 0..<2 {
            let window = NSWindow(contentRect: NSRect(x: -20_000, y: -20_000, width: 300, height: 120),
                                  styleMask: .borderless, backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: LanguageRoot(content: LocaleProbe { seen[index].append($0) }))
            window.orderFrontRegardless()
            windows.append(window)
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        language.select(.simplifiedChinese)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertTrue(seen.allSatisfy { $0.last?.hasPrefix("zh") == true }, "both windows must receive Chinese: \(seen)")
        language.select(.english)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertTrue(seen.allSatisfy { $0.last?.hasPrefix("en") == true }, "both windows must receive English: \(seen)")
    }

    func testSettingsSearchTracksTheSelectedLanguage() {
        let language = Language.shared
        let before = language.selection
        defer { language.select(before) }
        language.select(.simplifiedChinese)
        XCTAssertTrue(SettingsIndex.find("下载").contains { $0.group == "downloads" })
        XCTAssertTrue(SettingsIndex.find("Downloads").contains { $0.group == "downloads" })
        language.select(.english)
        XCTAssertTrue(SettingsIndex.find("Downloads").contains { $0.group == "downloads" })
    }

    func testSettingsCatalogHasTranslationsForItsDisplayedText() {
        let language = Language.shared
        let before = language.selection
        defer { language.select(before) }
        for choice in [InterfaceLanguage.english, .simplifiedChinese] {
            language.select(choice)
            for group in SettingsIndex.groups {
                let key = "settings.group.\(group.id)"
                let text = language.text(key, fallback: "<missing>")
                XCTAssertNotEqual(text, "<missing>", "\(choice): \(key)")
                if choice == .english { XCTAssertEqual(text, group.title, key) }
            }
            for item in SettingsIndex.items {
                let fields = [("title", item.title), ("detail", item.detail), ("more", item.more ?? "")]
                for (field, source) in fields where !source.isEmpty {
                    let key = "settings.\(item.id).\(field)"
                    let text = language.text(key, fallback: "<missing>")
                    XCTAssertNotEqual(text, "<missing>", "\(choice): \(key)")
                    if choice == .english { XCTAssertEqual(text, source, key) }
                }
            }
        }
    }

    func testSearchSuggestionExplanationsFollowLanguage() throws {
        let language = Language.shared
        let before = language.selection
        defer { language.select(before) }
        let item = try XCTUnwrap(SettingsIndex.item("search.suggest"))
        language.select(.simplifiedChinese)
        XCTAssertEqual(item.localizedDetail, "输入内容时会发送给搜索引擎")
        XCTAssertEqual(item.localizedMore, "建议显示在地址栏下方。无痕标签页和网址输入不会发送。")
        XCTAssertEqual(language.format("settings.search.sent_to", fallback: "What you type is sent to %1$@ as you type", "Google"),
                       "输入时，内容会发送至 Google")
        XCTAssertEqual(language.text("settings.search.no_suggestions", fallback: ""), "自定义搜索引擎不提供建议，因此不会发送内容")
        XCTAssertEqual(language.text("settings.search.custom_engine", fallback: ""), "自定义")
        language.select(.english)
        XCTAssertEqual(item.localizedDetail, item.detail)
        XCTAssertEqual(item.localizedMore, item.more)
    }

    func testSettingsShieldErrorsFollowLanguageAndKeepSystemErrors() {
        let language = Language.shared
        let before = language.selection
        let browser = Browser(record: WindowRecord())
        defer { language.select(before); browser.closeAll() }
        let panel = SettingsPanel(browser: browser, prefs: browser.prefs)
        let errors = [
            ("Couldn't build the block list", "无法构建拦截列表"),
            ("WebKit has nowhere to compile it", "WebKit 无法存放编译后的拦截列表"),
            ("Compiling the block list failed", "编译拦截列表失败"),
        ]
        language.select(.simplifiedChinese)
        for (original, translated) in errors { XCTAssertEqual(panel.shieldTrouble(original), translated) }
        XCTAssertEqual(panel.shieldTrouble("A system error"), "A system error")
        language.select(.english)
        for (original, _) in errors { XCTAssertEqual(panel.shieldTrouble(original), original) }
    }

    func testSettingsBridgeSwitchesAndReportsInterfaceLanguage() {
        let language = Language.shared
        let before = language.selection
        let prefs = Preferences()
        defer { language.select(before) }
        XCTAssertTrue(SettingsIndex.apply("general.language", "zh-Hans", to: prefs))
        XCTAssertEqual(SettingsIndex.values(prefs)["ui.language"] as? String, "zh-Hans")
        XCTAssertFalse(SettingsIndex.apply("general.language", "invalid", to: prefs))
        XCTAssertEqual(language.selection, .simplifiedChinese)
    }

    func testChineseAndEnglishCommandsKeepExactMatching() {
        _ = NSApplication.shared
        let language = Language.shared
        let before = language.selection
        defer { language.select(before) }
        language.select(.simplifiedChinese)
        let browser = Browser(record: WindowRecord())
        let wasEnabled = browser.prefs.commandBar
        defer { browser.prefs.commandBar = wasEnabled; browser.closeAll() }
        browser.prefs.commandBar = true
        XCTAssertEqual(AddressCommand.matching("设置", in: browser), .settings)
        XCTAssertEqual(AddressCommand.matching("settings", in: browser), .settings)
        XCTAssertNil(AddressCommand.matching("设置路由器", in: browser))
        XCTAssertEqual(AddressCommand.near("新标", in: browser), .newTab)
        XCTAssertEqual(AddressCommand.listed("appearance", in: browser).first, .page(.appearance))
        XCTAssertEqual(AddressCommand.listed("放大", in: browser).first, .menu("view.zoomIn"))
        XCTAssertEqual(AddressCommand.listed("zoom in", in: browser).first, .menu("view.zoomIn"))
        XCTAssertEqual(browser.placeOffers(for: "设置").offers.first?.kind, .command(.settings))
        XCTAssertFalse(browser.placeOffers(for: "设置路由器").offers.first?.kind.isCommand ?? true)
        browser.prefs.commandBar = false
        XCTAssertFalse(browser.placeOffers(for: "设置").offers.contains { $0.kind.isCommand })
    }

    func testAddressFieldLeavesMarkedTextCommandsToTheInputMethod() {
        _ = NSApplication.shared
        let browser = Browser(record: WindowRecord())
        defer { browser.closeAll() }
        let coordinator = AddressField.Coordinator(browser: browser)
        let field = AddressField.Field()
        let editor = NSTextView()
        editor.setMarkedText("设置", selectedRange: NSRange(location: 2, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertTrue(editor.hasMarkedText())
        XCTAssertFalse(coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.insertNewline(_:))))
        XCTAssertFalse(coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.moveDown(_:))))
        XCTAssertTrue(editor.hasMarkedText())
        XCTAssertFalse(browser.tuning)
    }

    func testOnlySearchOwnedTabNamesAreTranslated() {
        let language = Language.shared
        let before = language.selection
        defer { language.select(before) }
        language.select(.simplifiedChinese)
        let tab = Tab()
        XCTAssertEqual(tab.label, "New Tab")
        XCTAssertEqual(tab.displayLabel, "新标签页")
        tab.name = "New Tab"
        XCTAssertEqual(tab.displayLabel, "New Tab")
        tab.name = nil
        tab.show(InternalPage(.settings))
        XCTAssertEqual(tab.label, "Settings")
        XCTAssertEqual(tab.displayLabel, "设置")
    }

    func testSwitchKeepsTabAndWebViewIdentitiesInTwoWindows() {
        _ = NSApplication.shared
        let language = Language.shared
        let before = language.selection
        let previousSession = Session.read()
        Session.write(now: true, Session.Shape(tabs: [], active: 0))
        defer { language.select(before) }
        var browsers: [Browser] = []
        var windows: [NSWindow] = []
        defer {
            for window in windows { window.contentView = nil; window.close() }
            for browser in browsers { browser.closeAll() }
            Session.write(now: true, previousSession)
        }
        for count in [20, 200] {
            let browser = Browser(record: WindowRecord())
            for index in 0..<count {
                if browser.tabs.last?.isBlank == false { browser.newTab() }
                browser.tabs.last?.restore(url: URL(string: "http://127.0.0.1:1/tab-\(index)")!, title: "Tab \(index)")
            }
            browsers.append(browser)
            let window = NSWindow(contentRect: NSRect(x: -20_000, y: -20_000, width: 800, height: 600),
                                  styleMask: .borderless, backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: LanguageRoot(content: ContentView(browser: browser)))
            window.orderFrontRegardless()
            windows.append(window)
            _ = browser.active?.web
        }
        let ids = browsers.map { $0.tabs.map(\.id) }
        let webViews = browsers.map { $0.tabs.map { $0.built.map(ObjectIdentifier.init) } }
        XCTAssertEqual(ids.map(\.count), [20, 200])
        XCTAssertTrue(webViews.allSatisfy { $0.contains(nil) }, "restored background tabs remain lazy")
        XCTAssertTrue(webViews.allSatisfy { $0.contains { $0 != nil } }, "each window has a built page")
        for choice in [InterfaceLanguage.english, .simplifiedChinese, .english] {
            language.select(choice)
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            XCTAssertEqual(browsers.map { $0.tabs.map(\.id) }, ids)
            XCTAssertEqual(browsers.map { $0.tabs.map { $0.built.map(ObjectIdentifier.init) } }, webViews)
        }
    }

    func testDisplayedAnnouncementsKeepStableEnglishAndFollowLanguage() {
        _ = NSApplication.shared
        let language = Language.shared
        let before = language.selection
        let browser = Browser(record: WindowRecord())
        defer { language.select(before); browser.closeAll() }
        language.select(.english)
        browser.announce("Saved test%20.png", localizedKey: "announcement.saved", arguments: ["test%20.png"])
        XCTAssertEqual(browser.announcement, "Saved test%20.png")
        XCTAssertEqual(browser.displayedAnnouncement, "Saved test%20.png")
        language.select(.simplifiedChinese)
        XCTAssertEqual(browser.announcement, "Saved test%20.png")
        XCTAssertEqual(browser.displayedAnnouncement, "已保存 test%20.png")
        browser.announce("Download finished")
        XCTAssertEqual(browser.displayedAnnouncement, "下载完成")
        browser.announce("Search 2.0 is downloading…", localizedKey: "update.downloading", arguments: ["2.0"])
        XCTAssertEqual(browser.announcement, "Search 2.0 is downloading…")
        XCTAssertEqual(browser.displayedAnnouncement, "正在下载 Search 2.0…")
        browser.announce("Spaces", localized: { "Spaces" })
        XCTAssertEqual(browser.displayedAnnouncement, "Spaces", "a user-chosen name must remain unchanged")
    }

    func testFileImportAnnouncementTracksLanguageAndKeepsDiagnosticText() {
        _ = NSApplication.shared
        let language = Language.shared
        let before = language.selection
        let browser = Browser(record: WindowRecord())
        defer { language.select(before); browser.closeAll() }
        let result = Browser.FileTake(said: "diagnostic result", bookmarks: 2, already: 1, places: 1, kept: 2, skipped: 1,
                                      cancelled: false, failed: false, mergedBookmarks: true, safari: true, busy: false)
        language.select(.english)
        browser.announce(result.said, localized: { result.localizedText })
        XCTAssertEqual(browser.announcement, "diagnostic result")
        XCTAssertEqual(browser.displayedAnnouncement, "2 new bookmarks, 1 already here · 1 place · 2 passwords, 1 skipped — the exported file holds your passwords in the clear: delete it now")
        language.select(.simplifiedChinese)
        XCTAssertEqual(browser.announcement, "diagnostic result")
        XCTAssertEqual(browser.displayedAnnouncement, "新增 2 个书签，1 个已存在 · 1 条历史记录 · 2 个密码，跳过 1 个——导出文件以明文保存了密码，请立即删除该文件")
        browser.announce("Download finished")
        XCTAssertEqual(browser.displayedAnnouncement, "下载完成", "a later announcement must not reuse the previous formatter")

        let cancelled = Browser.FileTake(said: "", bookmarks: 0, already: 0, places: 0, kept: 0, skipped: 0,
                                         cancelled: true, failed: false, mergedBookmarks: true, safari: false, busy: false)
        XCTAssertEqual(cancelled.localizedText, "已合并书签，随后取消导入")
    }

    func testShortcutNamesFollowLanguageWithoutChangingCommandIds() {
        let language = Language.shared
        let before = language.selection
        defer { language.select(before) }
        let command = Command.named("file.newTab")!
        language.select(.english)
        XCTAssertEqual(command.localizedTitle, "New Tab")
        language.select(.simplifiedChinese)
        XCTAssertEqual(command.id, "file.newTab")
        XCTAssertEqual(command.localizedTitle, "新标签页")
        XCTAssertEqual(Command.named("spaces.1")?.localizedTitle, "空间 1")
    }

    func testIconTipLocalizesForPeopleAndKeepsBenchTextStable() {
        let language = Language.shared
        let before = language.selection
        defer { language.select(before) }
        let tab = Tab(shy: true)
        language.select(.simplifiedChinese)
        XCTAssertEqual(IconTiles.tip(tab, address: nil), "New Tab\nPrivate")
        XCTAssertEqual(IconTiles.tip(tab, address: nil, localized: true), "新标签页\n隐私浏览")
        language.select(.english)
        XCTAssertEqual(IconTiles.tip(tab, address: nil, localized: true), "New Tab\nPrivate")
    }

    func testTranslationAndAINoticeFollowLanguage() {
        let language = Language.shared
        let before = language.selection
        defer { language.select(before) }
        let mark = TranslationMark(from: "fr", to: "en", phase: .failed("stable diagnostic"), issue: .unsupported("fr", "en"))
        language.select(.english)
        XCTAssertEqual(PageTranslator.name("fr"), "French")
        XCTAssertEqual(TranslateMenu.heading(mark), "French to English can't be translated on this Mac")
        XCTAssertTrue(AIAssist.notice(for: .openRouter).contains("OpenRouter"))
        language.select(.simplifiedChinese)
        XCTAssertNotEqual(PageTranslator.displayName("fr"), "French")
        XCTAssertTrue(TranslateMenu.heading(mark).contains("无法"))
        XCTAssertTrue(AIAssist.notice(for: .openRouter).contains("隐私"))
        XCTAssertEqual(PageTranslator.name("fr"), "French")
    }

    func testImportResultsFollowTheCurrentLanguage() {
        let language = Language.shared
        let before = language.selection
        defer { language.select(before) }
        let result = ImportPanel.Said.passwords(2, skipped: 1, undecrypted: 1, source: "Example")
        language.select(.english)
        XCTAssertTrue(result.text.contains("2 passwords"))
        XCTAssertTrue(result.text.contains("Example"))
        language.select(.simplifiedChinese)
        XCTAssertTrue(result.text.contains("2 个密码"))
        XCTAssertTrue(result.text.contains("Example"))
        XCTAssertTrue(result.text.contains("无法解密"))
    }

    func testSwitchKeepsThePageFormFocusAndScroll() async throws {
        _ = NSApplication.shared
        let language = Language.shared
        let before = language.selection
        let browser = Browser(record: WindowRecord())
        let window = NSWindow(contentRect: NSRect(x: -20_000, y: -20_000, width: 800, height: 600),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: LanguageRoot(content: ContentView(browser: browser)))
        window.makeKeyAndOrderFront(nil)
        defer {
            language.select(before)
            window.contentView = nil
            window.close()
            browser.closeAll()
        }

        let tab = browser.open(try XCTUnwrap(URL(string: "about:blank")), foreground: true)
        let web = tab.web
        web.loadHTMLString("""
            <!doctype html><style>body { height: 4000px } input { position: absolute; top: 650px }</style>
            <input id="draft"><script>window.fixtureReady = true</script>
            """, baseURL: URL(string: "https://language-test.invalid/"))
        var ready = false
        for _ in 0..<200 {
            if (try? await web.evaluateJavaScript("window.fixtureReady")) as? Bool == true { ready = true; break }
            try await Task.sleep(for: .milliseconds(25))
        }
        XCTAssertTrue(ready, "fixture must load before switching")
        _ = window.makeFirstResponder(web)
        _ = try await web.evaluateJavaScript("document.querySelector('#draft').value = 'unsent draft'; window.scrollTo(0, 600); document.querySelector('#draft').focus({preventScroll:true}); true")
        try await Task.sleep(for: .milliseconds(100))
        let state = "JSON.stringify({value: document.querySelector('#draft').value, focus: document.activeElement.id, scroll: window.scrollY})"
        let stateValue = try await web.evaluateJavaScript(state)
        let original = try XCTUnwrap(stateValue as? String)
        XCTAssertTrue(original.contains("unsent draft"))
        XCTAssertTrue(original.contains("\"focus\":\"draft\""))
        let scrollValue = try await web.evaluateJavaScript("window.scrollY")
        let scroll = try XCTUnwrap(scrollValue as? Double)
        XCTAssertGreaterThan(scroll, 0)
        let responder = window.firstResponder
        for choice in [InterfaceLanguage.english, .simplifiedChinese, .english] {
            language.select(choice)
            try await Task.sleep(for: .milliseconds(100))
            XCTAssertTrue(tab.built === web)
            XCTAssertTrue(window.firstResponder === responder)
            let after = try await web.evaluateJavaScript(state) as? String
            XCTAssertEqual(after, original)
        }
    }
}

private struct LocaleProbe: View {
    @Environment(\.locale) private var locale
    let changed: (String) -> Void

    var body: some View {
        Text("settings.general.language.title", bundle: Language.resources)
            .onAppear { changed(locale.identifier) }
            .onChange(of: locale.identifier) { _, value in changed(value) }
    }
}
