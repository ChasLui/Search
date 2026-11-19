import Foundation
import CryptoKit
import Security

// Chrome extensions, straight from the Chrome Web Store.
//
// An extension there is a .crx: a zip with a signed header in front of it.
// It is fetched from the same public update address every Chromium browser
// asks, the header is checked, and the zip is unpacked into the app's own
// folder for WebKit to load.
//
// The check that matters: a Chrome extension's id is not a name anybody
// chose — it is the first sixteen bytes of the SHA-256 of its public key,
// written as letters a to p. So the header must carry a public key that
// hashes to the id that was asked for, and a signature by that key over the
// zip that came with it. A file that was altered on the way, or an
// extension passed off under another's id, fails one or the other.

enum Crx {
    enum Refused: LocalizedError {
        case notAnID, download(Int), empty, notCrx, unsignedOrWrong, unpack

        var errorDescription: String? {
            switch self {
            case .notAnID: return "That isn't a Chrome Web Store link or extension id"
            case .download(let code): return "The Chrome Web Store answered \(code)"
            case .empty: return "The Chrome Web Store has nothing for that id — it may have been taken down, or only exist for old versions of Chrome"
            case .notCrx: return "What came back isn't a Chrome extension"
            case .unsignedOrWrong: return "The extension's signature doesn't hold up"
            case .unpack: return "The extension couldn't be unpacked"
            }
        }
    }

    /// The version of Chrome the store is told it is talking to, and the one
    /// extensions see in navigator.userAgent (ExtensionShims). Some set a
    /// minimum; the store refuses to hand those to a browser that says it
    /// is older, and some turn a feature off below a version: 1Password
    /// opens its popup to unlock only from Chrome 149, so at 140 its button
    /// in a field did nothing while it was locked (#685). Kept at Chrome's
    /// stable version (156 on 24 Oct 2026); look again every few releases.
    static let chromeVersion = "156.0.0.0"

    /// The id Chrome gives a folder loaded unpacked, from its real path:
    /// native messaging hosts shipped for such a folder list this id. The
    /// manifest's "key" is ignored, as nothing checks it and store keys are
    /// public, so a folder could otherwise take any extension's id.
    static func unpackedID(for folder: URL) -> String {
        letters(SHA256.hash(data: Data(realPath(of: folder).utf8)).prefix(16))
    }

    /// Where a folder really is, every link on the way resolved.
    static func realPath(of folder: URL) -> String {
        realpath(folder.path, nil).map { real in defer { free(real) }; return String(cString: real) } ?? folder.standardizedFileURL.path
    }

    private static let idExpression = try! NSRegularExpression(pattern: "(?<![a-z])([a-p]{32})(?![a-z])")
    private static let storeDetailExpression = try! NSRegularExpression(pattern: #"^/detail/(?:[^/]+/)?([a-p]{32})(?:/.*)?$"#)
    private static let webstoreDetailExpression = try! NSRegularExpression(pattern: #"^/webstore/detail/(?:[^/]+/)?([a-p]{32})(?:/.*)?$"#)

    /// Thirty-two letters from a to p, wherever they are — a bare id, a store
    /// link, an old chrome.google.com/webstore link.
    static func id(in text: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = idExpression.firstMatch(in: text.lowercased(), range: range),
              let found = Range(match.range(at: 1), in: text)
        else { return nil }
        return text[found].lowercased()
    }

    /// The extension a store page is about: the id in its /detail/ path
    /// and nowhere else — the listing the page shows is that one. Only on
    /// the store itself, over https, with nothing before its host.
    static func storeID(of url: URL) -> String? {
        guard url.scheme?.lowercased() == "https", url.user == nil, url.password == nil else { return nil }
        let host = url.host()?.lowercased() ?? ""
        let expression: NSRegularExpression
        switch host {
        case "chromewebstore.google.com": expression = storeDetailExpression
        case "chrome.google.com": expression = webstoreDetailExpression
        default: return nil
        }
        let path = url.path
        guard let match = expression.firstMatch(in: path, range: NSRange(path.startIndex..., in: path)),
              let found = Range(match.range(at: 1), in: path)
        else { return nil }
        return String(path[found])
    }

    static func downloadURL(for id: String) -> URL {
        var parts = URLComponents(string: "https://clients2.google.com/service/update2/crx")!
        parts.queryItems = [
            URLQueryItem(name: "response", value: "redirect"),
            URLQueryItem(name: "prodversion", value: chromeVersion),
            URLQueryItem(name: "acceptformat", value: "crx3"),
            URLQueryItem(name: "x", value: "id=\(id)&installsource=ondemand&uc"),
        ]
        return parts.url!
    }

    static func fetch(_ id: String, using session: URLSession = ProxyNetwork.session) async throws -> Data {
        var request = URLRequest(url: downloadURL(for: id))
        request.timeoutInterval = 60
        // Not URLSession.shared, which takes no configuration and so could
        // never be proxied: the Web Store would name every extension you add.
        let (file, response) = try await session.download(for: request)
        defer { try? FileManager.default.removeItem(at: file) }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw Refused.download(http.statusCode)
        }
        // A mapping keeps the downloaded bytes available after unlinking the temporary file.
        let data = try Data(contentsOf: file, options: .mappedIfSafe)
        guard !data.isEmpty else { throw Refused.empty }
        return data
    }

    /// A slice of the CRX3 containing the zip authenticated for `id`.
    static func verifiedZip(_ crx: Data, id: String) throws -> Data {
        guard crx.count > 12, crx.starts(with: "Cr24".utf8) else { throw Refused.notCrx }
        let version = le32(crx, 4)
        guard version == 3 else { throw Refused.notCrx }
        let headerSize = Int(le32(crx, 8))
        guard headerSize <= crx.count - 12 else { throw Refused.notCrx }
        let header = crx.dropFirst(12).prefix(headerSize)
        let zip = crx[header.endIndex...]

        // CrxFileHeader: 2 = sha256_with_rsa proofs, 3 = sha256_with_ecdsa
        // proofs, 10000 = signed_header_data (SignedData: 1 = crx_id).
        let fields = try protobuf(header)
        guard let signedHeader = fields.first(where: { $0.0 == 10000 })?.1 else { throw Refused.unsignedOrWrong }
        guard let crxID = try protobuf(signedHeader).first(where: { $0.0 == 1 })?.1,
              crxID.count == 16, letters(crxID) == id
        else { throw Refused.unsignedOrWrong }
        let proofs = try fields.filter { $0.0 == 2 }.map { try protobuf($0.1) }
        guard !proofs.isEmpty else { throw Refused.unsignedOrWrong }

        // Hash the signed parts in order so the archive never needs a second buffer.
        var hash = SHA256()
        hash.update(data: Data("CRX3 SignedData\0".utf8))
        let length = UInt32(signedHeader.count).littleEndian
        withUnsafeBytes(of: length) { hash.update(bufferPointer: $0) }
        hash.update(data: signedHeader)
        hash.update(data: zip)
        let digest = Data(hash.finalize())

        // One RSA proof, whose key is the one the id is made from, and whose
        // signature holds over the message. The store adds a proof of its
        // own; that one is fine to hold too but is not the one that counts.
        let owns = proofs.contains { proof in
            guard let key = proof.first(where: { $0.0 == 1 })?.1,
                  let signature = proof.first(where: { $0.0 == 2 })?.1,
                  letters(SHA256.hash(data: key).prefix(16)) == id
            else { return false }
            return verify(rsaSPKI: key, signature: signature, digest: digest)
        }
        guard owns else { throw Refused.unsignedOrWrong }
        return zip
    }

    /// Unpacks a zip into `folder`, which is replaced whole.
    static func unpack(_ zip: Data, into folder: URL) throws {
        let files = FileManager.default
        let scratch = files.temporaryDirectory.appendingPathComponent("search-crx-\(UUID().uuidString)")
        try files.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: scratch) }
        let archive = scratch.appendingPathComponent("x.zip")
        try zip.write(to: archive)
        let out = scratch.appendingPathComponent("out", isDirectory: true)
        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-x", "-k", archive.path, out.path]
        try ditto.run()
        ditto.waitUntilExit()
        guard ditto.terminationStatus == 0,
              files.fileExists(atPath: out.appendingPathComponent("manifest.json").path)
        else { throw Refused.unpack }
        // `ditto` keeps a symbolic link as a link, and the shim is installed
        // by rewriting the pages a package ships: a link among them would
        // have that rewrite land wherever it points. Nothing an extension
        // needs is a link, so one is refused whole.
        let carried = files.enumerator(at: out, includingPropertiesForKeys: [.isSymbolicLinkKey])
        while let item = carried?.nextObject() as? URL {
            guard (try? item.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true
            else { throw Refused.unpack }
        }
        try? files.removeItem(at: folder)
        try files.createDirectory(at: folder.deletingLastPathComponent(), withIntermediateDirectories: true)
        try files.moveItem(at: out, to: folder)
    }

    // MARK: - pieces

    private static func le32(_ data: Data, _ offset: Int) -> UInt32 {
        data.withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self)) }
    }

    /// The id's letters: each half-byte is a letter from a (0) to p (15).
    static func letters(_ bytes: some Sequence<UInt8>) -> String {
        String(bytes.flatMap { [$0 >> 4, $0 & 0x0f] }.map { Character(UnicodeScalar(UInt8(97) + $0)) })
    }

    /// Return the top-level length-delimited fields only after reading the whole message.
    private static func protobuf(_ b: Data) throws -> [(Int, Data)] {
        var out: [(Int, Data)] = []
        var i = b.startIndex
        func varint() throws -> UInt64 {
            var value: UInt64 = 0
            for shift in stride(from: 0, through: 63, by: 7) {
                guard i < b.endIndex else { break }
                let byte = b[i]
                i += 1
                guard shift < 63 || byte <= 1 else { break }
                value |= UInt64(byte & 0x7f) << shift
                if byte < 0x80 { return value }
            }
            throw Refused.notCrx
        }
        var groups: [Int] = []
        while i < b.endIndex {
            let key = try varint()
            guard key >= 8, key <= UInt32.max else { throw Refused.notCrx }
            let field = Int(key >> 3), wire = key & 7
            switch wire {
            case 0:
                _ = try varint()
            case 1, 5:
                let width = wire == 1 ? 8 : 4
                guard width <= b.endIndex - i else { throw Refused.notCrx }
                i += width
            case 2:
                let length = try varint()
                guard length <= UInt64(b.endIndex - i) else { throw Refused.notCrx }
                let end = i + Int(length)
                if groups.isEmpty { out.append((field, b[i..<end])) }
                i = end
            case 3:
                // Match the usual protobuf nesting limit when skipping unknown groups.
                guard groups.count < 100 else { throw Refused.notCrx }
                groups.append(field)
            case 4:
                guard groups.popLast() == field else { throw Refused.notCrx }
            default:
                throw Refused.notCrx
            }
        }
        guard groups.isEmpty else { throw Refused.notCrx }
        return out
    }

    /// An RSA public key as Chrome writes it (SubjectPublicKeyInfo DER),
    /// checked against a PKCS#1 v1.5 SHA-256 signature.
    private static func verify(rsaSPKI: Data, signature: Data, digest: Data) -> Bool {
        var format = SecExternalFormat.formatOpenSSL
        var type = SecExternalItemType.itemTypePublicKey
        var items: CFArray?
        guard SecItemImport(rsaSPKI as CFData, nil, &format, &type, [], nil, nil, &items) == errSecSuccess,
              let key = (items as? [Any])?.first
        else { return false }
        return SecKeyVerifySignature(
            key as! SecKey, .rsaSignatureDigestPKCS1v15SHA256,
            digest as CFData, signature as CFData, nil
        )
    }
}
