#!/usr/bin/env python3
"""Copia o resultado do build para web/images (out.js + wasm em partes de 20 MB + manifest)."""
import glob, json, os, shutil, sys
build, img = sys.argv[1], sys.argv[2]
os.makedirs(img, exist_ok=True)
found = {}
for root, _, files in os.walk(build):
    for f in files:
        if f in ("qemu-system-x86_64.js", "qemu-system-x86_64.wasm", "qemu-system-x86_64.worker.js"):
            found.setdefault(f, os.path.join(root, f))
if "qemu-system-x86_64.wasm" not in found or "qemu-system-x86_64.js" not in found:
    sys.exit("Nao achei qemu-system-x86_64.js/.wasm em " + build + " (o make terminou sem erro?)")
mp = os.path.join(img, "manifest.json")
manifest = json.load(open(mp)) if os.path.exists(mp) else {}
for old in glob.glob(os.path.join(img, "qemu-system-x86_64.wasm.part*")): os.remove(old)
shutil.copy(found["qemu-system-x86_64.js"], os.path.join(img, "out.js"))
if "qemu-system-x86_64.worker.js" in found:
    shutil.copy(found["qemu-system-x86_64.worker.js"], os.path.join(img, "qemu-system-x86_64.worker.js"))
data = open(found["qemu-system-x86_64.wasm"], "rb").read(); PART = 20 * 1024 * 1024; parts = []
for i in range(0, len(data), PART):
    n = "qemu-system-x86_64.wasm.part%03d" % (i // PART)
    open(os.path.join(img, n), "wb").write(data[i:i + PART]); parts.append(n)
manifest["qemu-system-x86_64.wasm"] = {"size": len(data), "parts": parts}
json.dump(manifest, open(mp, "w"))
print("OK:", img, "(wasm de %.1f MB em %d partes)" % (len(data) / 1048576, len(parts)))
