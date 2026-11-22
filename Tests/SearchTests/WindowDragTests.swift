import AppKit
import SwiftUI
import XCTest
@testable import Search

@MainActor
final class WindowDragTests: XCTestCase {
    private var windows: [DragWindow] = []
    private var activationPolicy: NSApplication.ActivationPolicy?

    override class func setUp() {
        setenv("SEARCH_PROBE", "window-drag-\(getpid())", 1)
        super.setUp()
    }

    override func tearDown() async throws {
        for window in windows {
            window.contentView = nil
            window.close()
        }
        windows.removeAll()
        if let activationPolicy { NSApp.setActivationPolicy(activationPolicy) }
        try await super.tearDown()
    }

    func testInactiveWindowAcceptsTheFirstPress() async throws {
        let (_, strip) = try await makeWindow()
        XCTAssertTrue(strip.acceptsFirstMouse(for: nil))
    }

    func testDragLetsTheSystemMoveTheWindowThenRestoresTheHoverGuard() async throws {
        let (window, strip) = try await makeWindow()
        try enterTitleBand(strip, in: window)
        XCTAssertFalse(window.isMovable)

        let down = try mouse(.leftMouseDown, at: NSPoint(x: 20, y: 20), window: window)
        strip.mouseDown(with: down)
        strip.mouseDragged(with: try mouse(.leftMouseDragged, at: NSPoint(x: 35, y: 20), window: window))

        XCTAssertTrue(window.movableAtDrag)
        XCTAssertTrue(window.dragEvent === down)
        XCTAssertFalse(window.isMovable)
        strip.mouseExited(with: try crossing(.mouseExited, window: window))
        XCTAssertTrue(window.isMovable)
    }

    func testModifiedShortcutsCanMoveTheHoveredWindow() async throws {
        let (window, strip) = try await makeWindow()
        let (other, otherStrip) = try await makeWindow()
        try enterTitleBand(strip, in: window)
        try enterTitleBand(otherStrip, in: other)
        XCTAssertFalse(window.isMovable)
        XCTAssertFalse(other.isMovable)
        let moveLeft = NSMenuItem(title: "", action: NSSelectorFromString("_zoomLeft:"), keyEquivalent: "")
        if #available(macOS 15, *) { XCTAssertFalse(window.validateUserInterfaceItem(moveLeft)) }

        let plainKey = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                                                      timestamp: ProcessInfo.processInfo.systemUptime,
                                                      windowNumber: window.windowNumber, context: nil,
                                                      characters: "", charactersIgnoringModifiers: "",
                                                      isARepeat: false, keyCode: 80))
        NSApp.sendEvent(plainKey)
        XCTAssertFalse(window.isMovable, "An ordinary key must not release the tab drag guard")

        let shortcuts: [(String, NSEvent.ModifierFlags, UInt16, String)] = [
            ("Control", .control, 80, ""),
            ("Command-Option-Right", [.command, .option], 124, "\u{F703}"),
            ("Command", .command, 80, ""),
            ("Option", .option, 80, ""),
        ]
        for (name, flags, code, characters) in shortcuts {
            let key = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
                                                     timestamp: ProcessInfo.processInfo.systemUptime,
                                                     windowNumber: window.windowNumber, context: nil,
                                                     characters: characters, charactersIgnoringModifiers: characters,
                                                     isARepeat: false, keyCode: code))
            XCTAssertTrue(key.window === window)
            NSApp.postEvent(key, atStart: true)
            let event = try XCTUnwrap(NSApp.nextEvent(matching: .keyDown, until: Date(timeIntervalSinceNow: 1),
                                                      inMode: .default, dequeue: true))
            NSApp.sendEvent(event)
            XCTAssertTrue(window.isMovable, "AppKit must see a movable window during the \(name) shortcut")
            XCTAssertFalse(other.isMovable, "Another hovered window stays protected")
            if #available(macOS 15, *) { XCTAssertTrue(window.validateUserInterfaceItem(moveLeft)) }
            try await Task.sleep(for: .milliseconds(50))
            XCTAssertFalse(window.isMovable, "The tab drag guard returns after the \(name) shortcut")
        }
        strip.mouseExited(with: try crossing(.mouseExited, window: window))
        XCTAssertTrue(window.isMovable)
        otherStrip.mouseExited(with: try crossing(.mouseExited, window: other))
        XCTAssertTrue(other.isMovable)
    }

    func testBrowserHandsWindowShortcutToAppKit() async throws {
        _ = NSApplication.shared
        if activationPolicy == nil { activationPolicy = NSApp.activationPolicy() }
        NSApp.setActivationPolicy(.prohibited)
        let browser = Browser(record: WindowRecord())
        let sidebar = browser.prefs.sidebar
        browser.prefs.sidebar = true
        let previousFront = Front.shared.browser
        Front.shared.set(browser)
        let window = DragWindow(contentRect: NSRect(x: -20_000, y: -20_000, width: 900, height: 600),
                                styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                                backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: ContentView(browser: browser))
        window.contentView = host
        window.orderFrontRegardless()
        windows.append(window)
        defer {
            Front.shared.set(previousFront)
            ContentView.forget(browser)
            browser.closeAll()
            browser.prefs.sidebar = sidebar
        }

        var hook: ((NSEvent) -> NSEvent?)?
        for _ in 0..<50 {
            hook = ContentView.keyHooks[ObjectIdentifier(browser)]
            if hook != nil, findStrip(host) != nil { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        let strip = try XCTUnwrap(findStrip(host))
        try enterTitleBand(strip, in: window)
        XCTAssertFalse(window.isMovable)
        let key = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
                                                 modifierFlags: [.command, .option],
                                                 timestamp: ProcessInfo.processInfo.systemUptime,
                                                 windowNumber: window.windowNumber, context: nil,
                                                 characters: "\u{F703}", charactersIgnoringModifiers: "\u{F703}",
                                                 isARepeat: false, keyCode: 124))
        let handle = try XCTUnwrap(hook)
        XCTAssertTrue(handle(key) === key, "The browser must leave the window shortcut to AppKit")
        NSApp.sendEvent(key)
        XCTAssertTrue(window.isMovable, "The window is movable while AppKit handles the shortcut")
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertFalse(window.isMovable)
        strip.mouseExited(with: try crossing(.mouseExited, window: window))
    }

    private func makeWindow() async throws -> (DragWindow, NSView) {
        _ = NSApplication.shared
        if activationPolicy == nil { activationPolicy = NSApp.activationPolicy() }
        NSApp.setActivationPolicy(.prohibited)
        let window = DragWindow(contentRect: NSRect(x: -20_000, y: -20_000, width: 300, height: 60),
                                styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: DragStrip())
        window.contentView = host
        window.orderFrontRegardless()
        windows.append(window)
        try await Task.sleep(for: .milliseconds(100))
        return (window, try XCTUnwrap(findStrip(host)))
    }

    private func findStrip(_ view: NSView) -> NSView? {
        if String(describing: type(of: view)) == "Strip" { return view }
        return view.subviews.lazy.compactMap(findStrip).first
    }

    /// Puts the pointer on the strip over the title band until it is over
    /// something the window is guarded by — a tab or a button — as a real
    /// pointer crossing there would be. The empty strip and the lights leave
    /// the window movable (#1257), and where the tabs sit depends on the
    /// window and its saved session, so the band is tried along its length.
    private func enterTitleBand(_ strip: NSView, in window: NSWindow) throws {
        let y = window.frame.height - 5
        var x = 120.0
        while x < window.frame.width - 20 {
            strip.mouseEntered(with: try crossing(.mouseEntered, at: NSPoint(x: x, y: y), window: window))
            if !window.isMovable { return }
            strip.mouseExited(with: try crossing(.mouseExited, window: window))
            x += 8
        }
        XCTFail("No point in the title band holds the window")
    }

    private func crossing(_ type: NSEvent.EventType, at point: NSPoint = .zero,
                          window: NSWindow) throws -> NSEvent {
        try XCTUnwrap(NSEvent.enterExitEvent(with: type, location: point, modifierFlags: [],
                                             timestamp: ProcessInfo.processInfo.systemUptime,
                                             windowNumber: window.windowNumber, context: nil,
                                             eventNumber: 1, trackingNumber: 1, userData: nil))
    }

    private func mouse(_ type: NSEvent.EventType, at point: NSPoint, window: NSWindow) throws -> NSEvent {
        try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                                         timestamp: ProcessInfo.processInfo.systemUptime,
                                         windowNumber: window.windowNumber, context: nil,
                                         eventNumber: 1, clickCount: 1, pressure: 1))
    }
}

@MainActor
private final class DragWindow: NSWindow {
    var dragEvent: NSEvent?
    var movableAtDrag = false

    override func performDrag(with event: NSEvent) {
        dragEvent = event
        movableAtDrag = isMovable
    }
}
