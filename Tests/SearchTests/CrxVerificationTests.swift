import Foundation
import XCTest
@testable import Search

final class CrxVerificationTests: XCTestCase {
    // Generated from a one-time RSA-2048 test key and an empty ZIP. The
    // private key was discarded. Its package key maps to this extension ID.
    private let extensionID = "fbeflcoplhlckcpdcenfcdlfnbejghon"
    private let crx = Data(base64Encoded: """
        Q3IyNAMAAABFAgAAEqwECqYCMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAtpHbo7T1
        2+h/Ong6laLAAqYh+QtK5XSFhS/ruGsfLG0m/moaDrrOs1iEXuJfSXVgfPhoj1tMcdkxQjbgw6hc
        jf5qEjM66MNTqc8Mg3Xwj/6uLOYkAzO3l7bJjktL6/4+F2SHg3Fg9gyn7PZux6w8PGFQAwMUaxsz
        DtqsJ5d0MVM4LeGMATnoljJnH6z+bgMEyA7xhXPBsT310G/L01SzSFrbDBBiSil3QnS5FHXgNcb2
        79w+xyoKoKpl70+PnAvMRlcrxgXsO9BLxTkhgdsNHmjYOWInauw+o+XxkRCoGOJa6axuzXuXSEK1
        RDrFWoFKpCEnlNWxThSUfKSNsFIKvQIDAQABEoACQ4GwwLSgR1/dyBCkG+ldkaL/Pp4vy4iqM18T
        Gg5wus1IJehw3R1jFfXHrlHkD401RFdP6DPYmuQgwiSwFPm88Zm13vIgzC+UjZ9VIfc4ImkedRM8
        CQ2j1zDIi6chmVXlROHW7FX7viWoj1kGmciuOxrP4JUL90sCn+7Oyga+cE6xS3bKpbIWssvrbP21
        7CUtPHnAWXffJ8ypE3E8PbKgjFMdMpwrjlORFnLXOMCN0rS+fsKJklc/jlMsRiqzyQES/xPQgfcF
        moXAFz4R8Qd1kKxWTi5yt5b1hB2+JsIuP4QlQYNGxNcm3dhyvFpNOKmdUwTaEZBFK6G2WSwWGR+1
        XYLxBBIKEFFFsu+3sqLzJNUjtdFJZ+1QSwUGAAAAAAAAAAAAAAAAAAAAAAAA
        """, options: .ignoreUnknownCharacters)!

    private let emptyZip = Data([
        0x50, 0x4b, 0x05, 0x06, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    ])

    func testVerifiesRSAProofFromNonzeroIndexDataSlice() throws {
        var wrapped = Data([0xff])
        wrapped.append(crx)
        wrapped.append(0xfe)
        let slice = wrapped[1..<(wrapped.count - 1)]

        XCTAssertNotEqual(slice.startIndex, 0)
        XCTAssertEqual(try Crx.verifiedZip(slice, id: extensionID), emptyZip)
    }

    func testRejectsMismatchedID() {
        let otherID = "a" + extensionID.dropFirst()
        XCTAssertThrowsError(try Crx.verifiedZip(crx, id: otherID))
    }

    func testRejectsChangedZipPayload() {
        var changed = crx
        changed[changed.index(before: changed.endIndex)] ^= 0x01

        XCTAssertThrowsError(try Crx.verifiedZip(changed, id: extensionID))
    }

    private func unsignedPackage(header: [UInt8]) -> Data {
        // These small fixtures use only the low byte of the CRX3 header length.
        Data("Cr24".utf8) + Data([3, 0, 0, 0, UInt8(header.count), 0, 0, 0] + header) + emptyZip
    }

    func testIncompleteProtobufIsReportedAsAnInvalidPackage() {
        let incomplete: [[UInt8]] = [
            [0x4a, 1, 65, 0x52],   // A complete field followed by a missing length.
            [0x4a, 2, 65],         // Missing the end of a length-delimited value.
            [0x48, 0x80],          // Unfinished varint.
            [0x49, 1], [0x4d, 1],  // Incomplete fixed64 and fixed32 values.
            [0x4b], [0x4b, 0x54],  // Unclosed group and mismatched end group.
        ]
        for header in incomplete {
            XCTAssertThrowsError(try Crx.verifiedZip(unsignedPackage(header: header), id: extensionID)) {
                guard case Crx.Refused.notCrx = $0 else { return XCTFail("Expected an invalid header for \(header), got \($0)") }
            }
        }
    }

    func testCompleteUnknownProtobufFieldsAreSkipped() throws {
        // A future writer can put metadata before the proof. The signed data stays the same.
        let unknown: [UInt8] = [0x4b, 0x53, 0x54, 0x4c, 0x48] + Array(repeating: 0xff, count: 9) + [1]
        let length = UInt32(crx.count - 12 - emptyZip.count + unknown.count).littleEndian
        var extended = Data(crx.prefix(8))
        withUnsafeBytes(of: length) { extended.append(contentsOf: $0) }
        extended.append(contentsOf: unknown)
        extended.append(crx.dropFirst(12))
        XCTAssertEqual(try Crx.verifiedZip(extended, id: extensionID), emptyZip)
    }
}
