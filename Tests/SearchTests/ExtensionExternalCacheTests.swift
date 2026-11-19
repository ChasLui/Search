import AppKit
import XCTest
@testable import Search

@available(macOS 15.4, *)
@MainActor
final class ExtensionExternalCacheTests: XCTestCase {
    override class func setUp() {
        setenv("SEARCH_PROBE", "extension-external-cache-\(getpid())", 1)
        super.setUp()
    }

    private func waitForContext(_ id: String, patterns: [String]?, in extensions: Extensions, limit: TimeInterval = 5) async throws -> Bool {
        let end = Date().addingTimeInterval(limit)
        while Date() < end {
            if extensions.contexts[id] != nil, ExtensionExternal.listings[id] == patterns { return true }
            try await Task.sleep(for: .milliseconds(20))
        }
        return false
    }

    func testUnloadAndReloadWithChangedManifestRefreshesPageScript() async throws {
        _ = NSApplication.shared
        let extensions = Extensions.shared
        let source = FileManager.default.temporaryDirectory.appendingPathComponent("external-cache-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: source) }
        let id = Crx.unpackedID(for: source)
        let firstPattern = "http://127.0.0.1/*"
        let secondPattern = "https://*.example.test/*"

        func install(_ pattern: String) async throws {
            let manifest: [String: Any] = [
                "manifest_version": 3,
                "name": "External cache",
                "version": "1.0",
                "externally_connectable": ["matches": [pattern]],
            ]
            try JSONSerialization.data(withJSONObject: manifest).write(to: source.appendingPathComponent("manifest.json"))
            extensions.installFolder(at: source, confirm: false)
            let patterns = ExtensionExternal.allowed(pattern) ? [pattern] : nil
            let loaded = try await waitForContext(id, patterns: patterns, in: extensions)
            XCTAssertTrue(loaded, "the extension did not load its current manifest")
        }

        defer { extensions.remove(id) }

        let before = ExtensionExternal.script
        try await install(firstPattern)
        XCTAssertEqual(ExtensionExternal.listings[id], [firstPattern])
        let firstScript = try XCTUnwrap(ExtensionExternal.script)
        XCTAssertEqual(ExtensionExternal.script, firstScript)

        extensions.remove(id)
        XCTAssertNil(extensions.contexts[id])
        XCTAssertNil(ExtensionExternal.listings[id])
        XCTAssertEqual(ExtensionExternal.script, before)

        try await install(secondPattern)
        XCTAssertEqual(ExtensionExternal.listings[id], [secondPattern])
        let secondScript = try XCTUnwrap(ExtensionExternal.script)
        XCTAssertNotEqual(secondScript, firstScript)
        XCTAssertEqual(ExtensionExternal.script, secondScript)

        extensions.remove(id)
        try await install("*://*/*")
        XCTAssertNil(ExtensionExternal.listings[id])
        XCTAssertEqual(ExtensionExternal.script, before)
        XCTAssertEqual(ExtensionExternal.script, before, "the cached nil result should remain stable")
    }
}
