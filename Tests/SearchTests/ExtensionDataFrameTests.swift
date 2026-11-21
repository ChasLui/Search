import AppKit
import WebKit
import XCTest
@testable import Search

/// A data: frame is a document with no address of its own: WebKit reads it
/// through the frame that made it (`match_origin_as_fallback`), but only
/// once data: is a scheme its patterns know (Extensions.init). Until then a
/// content script importing its own module in such a frame failed, which is
/// where Immersive Translate lost pages that embed one.
@available(macOS 15.4, *)
@MainActor
final class ExtensionDataFrameTests: XCTestCase {
    override class func setUp() {
        setenv("SEARCH_PROBE", "data-frame-\(getpid())", 1)
        super.setUp()
    }

    private func fixture(hosts: [String] = ["<all_urls>"]) async throws -> (URL, WKWebExtension) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("data-frame-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let manifest: [String: Any] = [
            "manifest_version": 3, "name": "Data frames", "version": "1",
            "host_permissions": hosts,
            "content_scripts": [[
                "matches": hosts,
                "js": ["guard.js"],
                "run_at": "document_start",
                "all_frames": true,
                "match_origin_as_fallback": true,
            ]],
            "web_accessible_resources": [[
                "resources": ["module.js"],
                "matches": hosts,
            ]],
        ]
        try JSONSerialization.data(withJSONObject: manifest).write(to: folder.appendingPathComponent("manifest.json"))
        try Data("""
        (async () => {
          let value;
          try { const module = await import(chrome.runtime.getURL('module.js')); value = module.value; }
          catch (error) { value = 'error: ' + String(error); }
          if (window !== top) parent.postMessage({ probe: 'data-frame', value }, '*');
        })();
        """.utf8).write(to: folder.appendingPathComponent("guard.js"))
        try Data("export const value = 'module-ok';".utf8).write(to: folder.appendingPathComponent("module.js"))
        return (folder, try await WKWebExtension(resourceBaseURL: folder))
    }

    /// <all_urls> would cover data: URLs once the scheme is known, which no
    /// browser gives an extension: fence takes that grant out and leaves
    /// *://*/*, so a data: frame is reached by its site alone.
    func testFenceKeepsAllURLsOffDataURLs() async throws {
        _ = Extensions.shared
        let (folder, ext) = try await fixture()
        defer { try? FileManager.default.removeItem(at: folder) }
        let dataURL = try XCTUnwrap(URL(string: "data:text/html,%3Cp%3Eframe%3C/p%3E"))
        let context = WKWebExtensionContext(for: ext)
        Extensions.grantSites(context)
        XCTAssertTrue(context.hasAccess(to: dataURL), "data: is a scheme WebKit knows: <all_urls> covers it")
        Extensions.fence(context)
        let granted = Set(context.grantedPermissionMatchPatterns.keys.map(\.string))
        XCTAssertFalse(granted.contains("<all_urls>"), "\(granted)")
        XCTAssertTrue(granted.contains("*://*/*"), "\(granted)")
        XCTAssertFalse(context.hasAccess(to: dataURL), "no extension is given a data: URL")
        XCTAssertTrue(context.hasAccess(to: try XCTUnwrap(URL(string: "https://example.com/"))))
    }

    /// A manifest that names data: itself is kept out too: a data: URL is
    /// not a site, and Chrome grants no extension one.
    func testDataURLsAreNeverGrantedByName() async throws {
        _ = Extensions.shared
        let (folder, ext) = try await fixture(hosts: ["data://*/*"])
        defer { try? FileManager.default.removeItem(at: folder) }
        let context = WKWebExtensionContext(for: ext)
        Extensions.grantSites(context)
        Extensions.fence(context)
        XCTAssertFalse(context.grantedPermissionMatchPatterns.keys.contains { $0.scheme?.lowercased() == "data" },
                       "\(context.grantedPermissionMatchPatterns.keys.map(\.string))")
        XCTAssertFalse(context.hasAccess(to: try XCTUnwrap(URL(string: "data:text/html,x"))))
    }

    /// The frame is reached through its site and the extension's module
    /// loads in it — the part Immersive Translate needs to run there.
    func testDataFrameLoadsExtensionModuleWhenItsSiteIsGranted() async throws {
        _ = NSApplication.shared
        _ = Extensions.shared
        let (folder, ext) = try await fixture()
        defer { try? FileManager.default.removeItem(at: folder) }
        let controller = WKWebExtensionController(configuration: .nonPersistent())
        let context = WKWebExtensionContext(for: ext)
        Extensions.grantSites(context)
        Extensions.fence(context)
        context.hasAccessToPrivateData = true
        try controller.load(context)
        defer { try? controller.unload(context) }
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.webExtensionController = controller
        let web = WKWebView(frame: .zero, configuration: config)
        web.loadHTMLString("""
        <html><head><script>
        addEventListener('message', event => {
          if (event.data && event.data.probe === 'data-frame') document.documentElement.dataset.frameReport = event.data.value;
        });
        </script></head><body><iframe id="data" src="data:text/html,%3Cp%3Eframe%3C/p%3E" width="300" height="150"></iframe></body></html>
        """, baseURL: URL(string: "https://example.com/")!)
        var report = ""
        for _ in 0..<100 {
            try await Task.sleep(for: .milliseconds(100))
            report = (try? await web.evaluateJavaScript("document.documentElement.dataset.frameReport || ''")) as? String ?? ""
            if !report.isEmpty { break }
        }
        XCTAssertEqual(report, "module-ok", "a module import in the data: frame")
    }
}
