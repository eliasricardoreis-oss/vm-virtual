#!/usr/bin/env python3
"""Servidor local com os cabeçalhos COOP/COEP exigidos pelo QEMU-wasm."""
import http.server, os
os.chdir(os.path.dirname(os.path.abspath(__file__)))
class H(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map, ".js": "text/javascript", ".wasm": "application/wasm"}
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()
print("Abra http://localhost:8080")
http.server.ThreadingHTTPServer(("", 8080), H).serve_forever()
