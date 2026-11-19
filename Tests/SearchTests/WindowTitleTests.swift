import XCTest
import AppKit
import SwiftUI
@testable import Search

@MainActor
final class WindowTitleTests: XCTestCase {
    func testWindowIsNamedForItsPage() {
        XCTAssertEqual(WindowTitle.name(page: "Example Domain", private: false), "Example Domain")
        XCTAssertEqual(WindowTitle.name(page: "  Example Domain \n", private: false), "Example Domain")
    }

    func testWindowWithoutAPageTitleIsNamedForTheApp() {
        XCTAssertEqual(WindowTitle.name(page: "", private: false), "Search")
        XCTAssertEqual(WindowTitle.name(page: "   ", private: false), "Search")
    }

    func testPrivateTabNeverGivesItsPageAway() {
        XCTAssertEqual(WindowTitle.name(page: "Something personal", private: true), "Private Tab")
    }

    func testInternalPageWindowTitleFollowsLanguageAndKeepsUserName() {
        _ = NSApplication.shared
        let language = Language.shared
        let before = language.selection
        let tab = Tab()
        tab.show(InternalPage(.settings))
        let window = NSWindow(contentRect: NSRect(x: -20_000, y: -20_000, width: 300, height: 120),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: LanguageRoot(content: WindowTitle(tab: tab, window: window)))
        defer {
            language.select(before)
            window.contentView = nil
            window.close()
        }
        language.select(.english)
        window.orderFrontRegardless()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(window.title, "Settings")
        language.select(.simplifiedChinese)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(window.title, "设置")
        tab.name = "My Settings"
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(window.title, "My Settings")
        language.select(.english)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(window.title, "My Settings")
    }
}
