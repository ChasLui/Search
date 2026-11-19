import AppKit
import XCTest
@testable import Search

@MainActor
final class TabGroupDropTests: XCTestCase {
    override class func setUp() {
        setenv("SEARCH_PROBE", "tab-group-drop-\(getpid())", 1)
        super.setUp()
    }

    func testGroupedRowKeepsPinsOrderAndSplitVisibility() {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        Session.write(now: true, Session.Shape(tabs: [], active: 0))
        let browser = Browser(record: WindowRecord())
        let grouped = browser.prefs.usesTabGroups
        let split = browser.prefs.splitView
        defer {
            browser.closeAll()
            Session.write(now: true, Session.Shape(tabs: [], active: 0))
            browser.prefs.usesTabGroups = grouped
            browser.prefs.splitView = split
        }
        browser.prefs.usesTabGroups = true
        browser.prefs.splitView = true
        for number in 0..<8 {
            if number > 0 { browser.newTab() }
            browser.tabs.last?.restore(url: URL(string: "search://history/\(number)")!, title: "\(number)")
        }
        let tabs = browser.tabs
        defer { browser.unpin(tabs[0]) }
        let first = TabGroup(id: UUID(), name: "First", collapsed: false)
        let second = TabGroup(id: UUID(), name: "Second", collapsed: false)
        let empty = TabGroup(id: UUID(), name: "Empty", collapsed: false)
        browser.tabGroups = [second, first, empty]
        tabs[0].pin = "Pinned"
        tabs[0].groupID = first.id
        for tab in tabs[1...3] { tab.groupID = first.id }
        for tab in tabs[4...5] { tab.groupID = second.id }
        tabs[7].groupID = UUID()
        browser.pair(tabs[1], with: tabs[2], onLeft: true)

        var row = browser.groupedTabRow
        XCTAssertEqual(row.pins.map(\.id), [tabs[0].id])
        XCTAssertEqual(row.groups.map(\.id), [second.id, first.id, empty.id])
        XCTAssertEqual(row.groups[0].tabs.map(\.id), [tabs[4].id, tabs[5].id])
        XCTAssertEqual(row.groups[1].tabs.map(\.id), [tabs[1].id, tabs[3].id])
        XCTAssertTrue(row.groups[2].tabs.isEmpty)
        XCTAssertEqual(row.ungrouped.map(\.id), [tabs[6].id, tabs[7].id])
        XCTAssertEqual(row.pins.map(\.id) + row.groups.flatMap(\.tabs).map(\.id) + row.ungrouped.map(\.id),
                       browser.shownTabs.map(\.id))

        browser.toggleTabGroup(first.id)
        browser.activeID = tabs[2].id
        row = browser.groupedTabRow
        XCTAssertEqual(row.groups[1].tabs.map(\.id), [tabs[1].id], "The right pane shows its left representative")
        browser.activeID = tabs[6].id
        XCTAssertTrue(browser.groupedTabRow.groups[1].tabs.isEmpty)

        browser.toggleTabGroup(first.id)
        browser.prefs.splitView = false
        XCTAssertEqual(browser.groupedTabRow.groups[1].tabs.map(\.id), [tabs[1].id, tabs[2].id, tabs[3].id])
    }

    func testPositionalMovesAndSourceCleanup() throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        let browser = Browser(record: WindowRecord())
        let grouped = browser.prefs.usesTabGroups
        let split = browser.prefs.splitView
        defer {
            browser.prefs.usesTabGroups = grouped
            browser.prefs.splitView = split
        }
        browser.prefs.usesTabGroups = true
        for number in 0..<6 {
            if number > 0 { browser.newTab() }
            browser.tabs.last?.restore(url: URL(string: "https://\(number).example/")!, title: "\(number)")
        }
        let tabs = browser.tabs
        let group = browser.addTabGroup(containing: tabs[0])
        for tab in tabs[1...2] { browser.move(tab, toGroup: group) }
        browser.move(tabs[3], toGroup: GroupDropTarget(group: group, member: tabs[0].id))
        browser.move(tabs[4], toGroup: GroupDropTarget(group: group, member: tabs[1].id))
        let source = browser.addTabGroup(containing: tabs[5])
        let active = browser.activeID
        browser.move(tabs[5], toGroup: GroupDropTarget(group: group, member: tabs[2].id, after: true))
        XCTAssertEqual(browser.tabs(in: group).map(\.id), [3, 0, 4, 1, 2, 5].map { tabs[$0].id })
        XCTAssertFalse(browser.tabGroups.contains { $0.id == source })
        XCTAssertEqual(browser.activeID, active)

        browser.move(tabs[3], toGroup: GroupDropTarget(group: group, member: tabs[5].id, after: true))
        browser.move(tabs[3], toGroup: GroupDropTarget(group: group, member: tabs[0].id))
        browser.move(tabs[4], toGroup: GroupDropTarget(group: group, member: tabs[1].id, after: true))
        let order = [3, 0, 1, 4, 2, 5].map { tabs[$0].id }
        XCTAssertEqual(browser.tabs.map(\.id), order)
        browser.move(tabs[4], toGroup: GroupDropTarget(group: group, member: tabs[4].id))
        browser.move(tabs[4], toGroup: GroupDropTarget(group: UUID()))
        browser.move(tabs[4], toGroup: GroupDropTarget(group: group, member: UUID()))
        XCTAssertEqual(browser.tabs.map(\.id), order)
        let foreign = Tab(configuration: Web.configuration())
        browser.move(foreign, toGroup: GroupDropTarget(group: group))
        tabs[4].pin = "pin"
        browser.move(tabs[4], toGroup: GroupDropTarget(group: group))
        tabs[4].pin = nil
        XCTAssertEqual(browser.tabs.map(\.id), order)
        browser.toggleTabGroup(group)
        browser.move(tabs[3], toGroup: GroupDropTarget(group: group))
        XCTAssertFalse(browser.tabGroups[0].collapsed)
        XCTAssertEqual(browser.tabs.last?.id, tabs[3].id)

        browser.prefs.splitView = true
        browser.pair(tabs[1], with: tabs[0], onLeft: false)
        browser.move(tabs[0], toGroup: GroupDropTarget(group: group))
        XCTAssertEqual(Array(browser.tabs.suffix(2)).map(\.id), [tabs[0].id, tabs[1].id])
        browser.move(tabs[1], toGroup: GroupDropTarget(group: group, member: tabs[4].id), detaching: true)
        XCTAssertEqual(browser.tabs.first?.id, tabs[1].id)
        XCTAssertEqual(browser.tabs.last?.id, tabs[0].id)
        XCTAssertNil(browser.split(for: tabs[1]))
        browser.leaveFiles()
        let saved = try XCTUnwrap(browser.record.rows[browser.spaceID.uuidString])
        let restored = Browser(record: browser.record)
        XCTAssertEqual(restored.tabs.map { $0.address?.absoluteString }, saved.tabs.map { Optional($0.url) })
        XCTAssertEqual(restored.tabs.map(\.groupID), saved.tabs.map(\.groupID))
    }

    func testVisibleGeometryInBothLayouts() {
        let group = TabGroup(id: UUID(), name: "Group", collapsed: false)
        let first = UUID(), last = UUID(), source = UUID()
        // Unequal lengths and a negative origin also exercise scrolled coordinates.
        for vertical in [false, true] {
            let rect: (CGFloat, CGFloat) -> CGRect = { start, length in
                vertical ? CGRect(x: 10, y: start, width: 80, height: length)
                    : CGRect(x: start, y: 10, width: length, height: 80)
            }
            let point: (CGFloat) -> CGPoint = { position in
                vertical ? CGPoint(x: 30, y: position) : CGPoint(x: position, y: 30)
            }
            let frames = [
                group.id: GroupDropFrame(group: group.id, rect: rect(-40, 20)),
                first: GroupDropFrame(group: group.id, tab: first, rect: rect(-10, 30)),
                last: GroupDropFrame(group: group.id, tab: last, rect: rect(30, 80)),
                source: GroupDropFrame(group: group.id, tab: source, rect: rect(120, 30))
            ]
            for (position, target) in [
                (-30.0, GroupDropTarget(group: group.id)),
                (-5.0, GroupDropTarget(group: group.id, member: first)),
                (25.0, GroupDropTarget(group: group.id, member: last)),
                (100.0, GroupDropTarget(group: group.id, member: last, after: true))
            ] {
                XCTAssertEqual(GroupDropFrames.resolve(point(position), frames: frames, groups: [group],
                                                       excluding: source, vertical: vertical), target)
            }
            XCTAssertNil(GroupDropFrames.resolve(point(140), frames: frames, groups: [group],
                                                 excluding: source, vertical: vertical))
            var collapsed = group
            collapsed.collapsed = true
            XCTAssertEqual(GroupDropFrames.resolve(point(40), frames: frames, groups: [collapsed],
                                                    excluding: source, vertical: vertical), GroupDropTarget(group: group.id))
        }
    }
}
