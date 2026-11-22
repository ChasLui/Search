import AppKit
import WebKit
import XCTest
@testable import Search

@available(macOS 15.4, *)
@MainActor
final class ExtensionPopupMotionTests: XCTestCase {
    override class func setUp() {
        setenv("SEARCH_PROBE", "popup-motion-\(getpid())", 1)
        super.setUp()
    }

    func testSidebarPopupOpeningInLightAppearance() async throws {
        try await checkSidebarPopupOpening(.aqua)
    }

    func testSidebarPopupOpeningInDarkAppearance() async throws {
        try await checkSidebarPopupOpening(.darkAqua)
    }

    private func checkSidebarPopupOpening(_ appearance: NSAppearance.Name) async throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        let window = NSWindow(contentRect: NSRect(x: -20_000, y: -20_000, width: 800, height: 600),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = try XCTUnwrap(NSAppearance(named: appearance))
        let anchor = NSView(frame: NSRect(x: 60, y: 25, width: 26, height: 26))
        window.contentView?.addSubview(anchor)
        window.orderFrontRegardless()
        defer { window.close() }

        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Fixtures/ExtensionPopup")
        let ext = try await WKWebExtension(resourceBaseURL: fixture)
        let context = WKWebExtensionContext(for: ext)
        let configuration = WKWebExtensionController.Configuration.nonPersistent()
        configuration.defaultWebsiteDataStore = .nonPersistent()
        let controller = WKWebExtensionController(configuration: configuration)
        try controller.load(context)
        defer { try? controller.unload(context) }

        let popup = ExtensionPopup.shared
        popup.show(context.baseURL.appendingPathComponent("popup.html"), for: context, from: anchor)
        defer { popup.close() }

        var sizes: [NSSize] = []
        var contentAppearedAt: TimeInterval?
        let deadline = ProcessInfo.processInfo.systemUptime + 5
        while true {
            let now = ProcessInfo.processInfo.systemUptime
            if let web = popup.view, let popupWindow = web.window {
                if sizes.last != popupWindow.frame.size { sizes.append(popupWindow.frame.size) }
                if web.alphaValue > 0, contentAppearedAt == nil { contentAppearedAt = now }
            }
            if let appearedAt = contentAppearedAt {
                if now - appearedAt >= 1 { break }
            } else if now >= deadline {
                break
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertNotNil(contentAppearedAt, "the popup content never appeared")
        XCTAssertEqual(popup.view?.frame.size, NSSize(width: 500, height: 300))
        let first = try XCTUnwrap(sizes.first)
        let last = try XCTUnwrap(sizes.last)
        XCTAssertLessThanOrEqual(first.width, last.width + 2, "the popup opened wider than its settled size")
        XCTAssertLessThanOrEqual(first.height, last.height + 2, "the popup opened taller than its settled size")
        func progresses(_ values: [CGFloat]) -> Bool {
            guard let first = values.first, let last = values.last else { return false }
            return zip(values, values.dropFirst()).allSatisfy { before, after in
                last >= first ? after >= before - 2 : after <= before + 2
            }
        }
        XCTAssertTrue(progresses(sizes.map(\.width)), "the popup width reversed while opening: \(sizes)")
        XCTAssertTrue(progresses(sizes.map(\.height)), "the popup height reversed while opening: \(sizes)")

        let web = try XCTUnwrap(popup.view)
        XCTAssertEqual(web.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]), appearance)
        _ = try await web.evaluateJavaScript("document.documentElement.style.width = document.body.style.width = '620px'; document.documentElement.style.height = document.body.style.height = '400px'")
        for _ in 0..<120 {
            if web.frame.size == NSSize(width: 620, height: 400) { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(web.frame.size, NSSize(width: 620, height: 400), "later page changes must still resize the popup")

        popup.show(context.baseURL.appendingPathComponent("popup.html"), for: context, from: anchor)
        let abandoned = try XCTUnwrap(popup.view)
        popup.show(context.baseURL.appendingPathComponent("scrollbars.html"), for: context, from: anchor)
        let reopened = try XCTUnwrap(popup.view)
        XCTAssertFalse(abandoned === reopened)
        for _ in 0..<300 {
            if reopened.alphaValue > 0, reopened.frame.width == 375 { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(reopened.frame.width, 375, "a scrollbar requested by the page must remain in the popup size")

        popup.show(context.baseURL.appendingPathComponent("overflow.html"), for: context, from: anchor)
        let overflow = try XCTUnwrap(popup.view)
        var overflowSizes: [NSSize] = []
        var overflowAppearedAt: TimeInterval?
        let overflowDeadline = ProcessInfo.processInfo.systemUptime + 5
        while true {
            let now = ProcessInfo.processInfo.systemUptime
            if overflow.alphaValue > 0 {
                if overflowSizes.last != overflow.frame.size { overflowSizes.append(overflow.frame.size) }
                if overflowAppearedAt == nil { overflowAppearedAt = now }
            }
            if let appearedAt = overflowAppearedAt {
                if now - appearedAt >= 2.8 { break }
            } else if now >= overflowDeadline {
                break
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        let overflowFirst = try XCTUnwrap(overflowSizes.first, "the overflow popup never appeared")
        // The page names 500×300 and its div is 10 points taller. Since
        // #1311 no scroll bar's room is added, so the popup opens at the
        // named size and follows the div once, growing to 310 within its
        // first eight ticks; after that it only grows. What it must not do
        // is rock back — the 500↔515 loop the measurement once had.
        XCTAssertTrue(overflowSizes.allSatisfy { abs($0.width - overflowFirst.width) <= 2 },
                      "static overflow moved the popup sideways: \(overflowSizes)")
        XCTAssertTrue(progresses(overflowSizes.map(\.height)),
                      "static overflow made the popup shrink again: \(overflowSizes)")
        _ = try await overflow.evaluateJavaScript("document.querySelector('div').style.cssText = 'width:490px;height:290px'")
        for _ in 0..<120 {
            if overflow.frame.width == 500 { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(overflow.frame.width, 500, "the popup must shrink when the overflow goes away")
    }
}
