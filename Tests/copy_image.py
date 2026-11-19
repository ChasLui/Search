#!/usr/bin/env python3
"""Copy Image is quick on a large picture, in a hidden probe.

Build first (`./build.sh`), then `python3 Tests/copy_image.py`. A 3 MB
picture is served from 127.0.0.1 and fetched the way Copy Image fetches it
(`imageData`, which never touches the pasteboard: a test run must not take
the person's clipboard). Read a byte at a time, it took twenty seconds; it
should take well under one. Blob images are read in the page, while non-images
and pictures over the 50 MB limit are let go.
"""
import base64
import struct
import sys
import threading
import time
import zlib
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import split_view as sv  # noqa: E402

sv.use("bug-copy-image")
t = sv.T()
PORT = 8841


def png(w, h):
    raw = b"".join(b"\x00" + bytes((x * 7 + y * 13) % 256 for x in range(w * 3)) for y in range(h))
    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 0)) + chunk(b"IEND", b""))


BIG = png(1000, 1000)


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith("/huge"):
            self.send_response(200); self.send_header("Content-Type", "image/png"); self.end_headers()
            try:
                for _ in range(60):
                    self.wfile.write(b"\x00" * 1_000_000)
            except Exception:
                pass
            return
        self.send_response(200); self.send_header("Content-Type", "image/png")
        self.send_header("Content-Length", str(len(BIG))); self.end_headers(); self.wfile.write(BIG)

    def log_message(self, *a): pass


server = ThreadingHTTPServer(("127.0.0.1", PORT), H)
threading.Thread(target=server.serve_forever, daemon=True).start()
try:
    sv.setup()
    sv.launch()
    a = sv.page("home"); sv.sp("select", id=a); time.sleep(0.5)
    r = sv.cmd({"do": "imageData", "id": a, "url": f"http://127.0.0.1:{PORT}/big.png"})
    t.ok(f"a {len(BIG) // 1_000_000} MB picture is fetched whole", r.get("bytes") == len(BIG), r)
    t.ok("in well under a second", 0 <= r.get("ms", 99999) < 1000, r)
    t.ok("and is a picture that may be decoded", r.get("reasonable") is True, r)
    r = sv.cmd({"do": "imageData", "id": a, "url": f"http://127.0.0.1:{PORT}/huge"})
    t.ok("one past the 50 MB limit is let go", r.get("bytes") == -1, r)

    small = png(5, 5)
    encoded = base64.b64encode(small).decode("ascii")
    url = sv.cmd({
        "do": "eval", "id": a,
        "js": f"URL.createObjectURL(new Blob([Uint8Array.from(atob('{encoded}'), c => c.charCodeAt(0))], {{type: 'image/png'}}))",
    })["value"]
    r = sv.cmd({"do": "imageData", "id": a, "url": url})
    t.ok("a blob image is returned whole and decodable", r.get("bytes") == len(small) and r.get("reasonable") is True, r)
    sv.cmd({"do": "eval", "id": a, "js": f"URL.revokeObjectURL('{url}')"})

    url = sv.cmd({
        "do": "eval", "id": a,
        "js": f"URL.createObjectURL(new Blob([Uint8Array.from(atob('{encoded}'), c => c.charCodeAt(0))], {{type: 'image/png;name=a,b'}}))",
    })["value"]
    r = sv.cmd({"do": "imageData", "id": a, "url": url})
    t.ok("a comma in a blob image's type keeps the bytes", r.get("bytes") == len(small) and r.get("reasonable") is True, r)
    sv.cmd({"do": "eval", "id": a, "js": f"URL.revokeObjectURL('{url}')"})

    url = sv.cmd({
        "do": "eval", "id": a,
        "js": "URL.createObjectURL(new Blob(['hello'], {type: 'text/plain'}))",
    })["value"]
    r = sv.cmd({"do": "imageData", "id": a, "url": url})
    t.ok("a non-image blob is refused", r.get("bytes") == -1, r)
    sv.cmd({"do": "eval", "id": a, "js": f"URL.revokeObjectURL('{url}')"})

    url = sv.cmd({
        "do": "eval", "id": a,
        "js": "URL.createObjectURL(new Blob([new Uint8Array(50000000)], {type: 'image/png'}))",
    })["value"]
    r = sv.cmd({"do": "imageData", "id": a, "url": url})
    t.ok("a blob at the 50 MB limit is returned", r.get("bytes") == 50000000, r)
    sv.cmd({"do": "eval", "id": a, "js": f"URL.revokeObjectURL('{url}')"})

    url = sv.cmd({
        "do": "eval", "id": a,
        "js": "URL.createObjectURL(new Blob([new Uint8Array(50000001)], {type: 'image/png'}))",
    })["value"]
    r = sv.cmd({"do": "imageData", "id": a, "url": url})
    t.ok("a blob over 50 MB is refused", r.get("bytes") == -1, r)
    sv.cmd({"do": "eval", "id": a, "js": f"URL.revokeObjectURL('{url}')"})
finally:
    server.shutdown()
    sv.finish()
t.done()
