import Foundation
import XCTest
@testable import Search

final class CrxDownloadTests: XCTestCase {
    private func fetch(status: Int, withBody: Bool = false) async throws -> Data {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StoreReply.self]
        configuration.httpAdditionalHeaders = [
            "X-Test-Status": String(status),
            "X-Test-Body": withBody ? "yes" : "no",
        ]
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        return try await Crx.fetch(String(repeating: "a", count: 32), using: session)
    }

    func testBytesRemainReadableAfterFetchReturns() async throws {
        let fetched = try await fetch(status: 200, withBody: true)
        XCTAssertEqual(fetched, StoreReply.body)
    }

    func testRejectsHTTPErrorEvenWhenThereIsABody() async throws {
        do {
            _ = try await fetch(status: 404, withBody: true)
            XCTFail("Expected the HTTP status to take precedence over the body")
        } catch Crx.Refused.download(404) {}
    }

    func testRejectsEmptySuccessfulResponses() async throws {
        for status in [200, 204] {
            do {
                _ = try await fetch(status: status)
                XCTFail("Expected an empty response for HTTP \(status) to be rejected")
            } catch Crx.Refused.empty {}
        }
    }
}

private final class StoreReply: URLProtocol {
    static let body = Data(repeating: 0x5a, count: 2 * 1024 * 1024)

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, url.host == "clients2.google.com",
              let status = request.value(forHTTPHeaderField: "X-Test-Status").flatMap(Int.init),
              let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if request.value(forHTTPHeaderField: "X-Test-Body") == "yes" {
            client?.urlProtocol(self, didLoad: Self.body)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
