import XCTest
@testable import Search

@available(macOS 15.4, *)
final class ExtensionShimGenerationTests: XCTestCase {
    func testShimListsJavaScriptFilesAndEventsFromReadableScripts() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("shim-generation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        try "chrome.tabs.onUpdated.addListener(() => {});".write(to: folder.appendingPathComponent("events.js"), atomically: true, encoding: .utf8)
        let carriedShim = "\(ExtensionShims.marker)\nchrome.tabs.onIgnored.addListener(() => {});\n\(ExtensionShims.ender)\nchrome.runtime.onStartup.addListener(() => {});"
        try carriedShim.write(to: folder.appendingPathComponent("worker.js"), atomically: true, encoding: .utf8)
        try " \n\u{2003}\t".write(to: folder.appendingPathComponent("empty.js"), atomically: true, encoding: .utf8)
        try Data().write(to: folder.appendingPathComponent("empty-file.js"))
        try Data([0xff, 0xfe]).write(to: folder.appendingPathComponent("invalid-utf8.js"))
        try "chrome.searchShim.onIgnored.addListener(() => {});".write(to: folder.appendingPathComponent(ExtensionShims.file), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("unreadable.js"), withIntermediateDirectories: true)

        let generated = ExtensionShims.shim(for: folder)
        XCTAssertTrue(generated.contains("const mentioned = new Set([\"runtime.onStartup\",\"tabs.onUpdated\"]);"))
        XCTAssertFalse(generated.contains("tabs.onIgnored"))
        XCTAssertFalse(generated.contains("searchShim.onIgnored"))

        let shippedLine = try XCTUnwrap(generated.components(separatedBy: .newlines).first(where: { $0.contains("const shipped = new Set(") }))
        XCTAssertTrue(shippedLine.contains(#"new Set(["-\/empty-file.js","-\/empty.js","\/events.js","\/invalid-utf8.js","\/search-shim.js","\/unreadable.js","\/worker.js"]"#), shippedLine)
    }
}
