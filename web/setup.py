#!/usr/bin/env python3
"""Prepara o projeto. Uso:
   python3 setup.py          -> baixa tudo (QEMU 64 bits + modo gráfico v86)
   python3 setup.py v86      -> só o modo gráfico (leve, ~20 MB)
   python3 setup.py qemu     -> só o QEMU-wasm (~150 MB, dividido em partes de 20 MB)
"""
import json, os, sys, urllib.request

ROOT = os.path.dirname(os.path.abspath(__file__))
UA = {"User-Agent": "Mozilla/5.0 vm-virtual-setup"}

def get(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120).read()

def get_any(urls):
    err = None
    for u in urls:
        try:
            print("  ->", u, flush=True)
            return get(u)
        except Exception as e:
            err = e
    raise SystemExit("Falhou em todas as fontes (%s). Veja sua conexão e rode de novo." % err)

# ---------------- QEMU-wasm (64 bits, só terminal) ----------------
def setup_qemu():
    RAW = "https://raw.githubusercontent.com/ktock/qemu-wasm-demo-images/main/alpine-x86_64/"
    FILES = ["out.js", "qemu-system-x86_64.wasm", "qemu-system-x86_64.worker.js",
             "load-rom.js", "load-rom.data", "load-kernel.js", "load-kernel.data",
             "load-initramfs.js", "load-initramfs.data", "load-rootfs.js", "load-rootfs.data"]
    PART = 20 * 1024 * 1024
    dest = os.path.join(ROOT, "images"); os.makedirs(dest, exist_ok=True)
    manifest = {}
    for name in FILES:
        print("Baixando", name, "...", flush=True)
        data = get(RAW + name)
        if name.endswith(".data") or name.endswith(".wasm"):
            parts = []
            for i in range(0, len(data), PART):
                p = "%s.part%03d" % (name, i // PART)
                open(os.path.join(dest, p), "wb").write(data[i:i + PART]); parts.append(p)
            manifest[name] = {"size": len(data), "parts": parts}
        else:
            open(os.path.join(dest, name), "wb").write(data)
    json.dump(manifest, open(os.path.join(dest, "manifest.json"), "w"))

# ---------------- v86 (32 bits, com tela gráfica) ----------------
def setup_v86():
    lib = os.path.join(ROOT, "vendor", "v86"); img = os.path.join(ROOT, "images", "v86")
    os.makedirs(lib, exist_ok=True); os.makedirs(img, exist_ok=True)
    NPM = ["https://cdn.jsdelivr.net/npm/v86@latest/build/%s", "https://unpkg.com/v86@latest/build/%s"]
    GH = ["https://cdn.jsdelivr.net/gh/copy/v86@master/bios/%s", "https://raw.githubusercontent.com/copy/v86/master/bios/%s"]
    for name, srcs in [("libv86.js", NPM), ("v86.wasm", NPM), ("seabios.bin", GH), ("vgabios.bin", GH)]:
        print("Baixando", name, flush=True)
        open(os.path.join(lib, name), "wb").write(get_any([s % name for s in srcs]))
    for name in ["linux4.iso", "buildroot-bzimage68.bin", "kolibri.img", "freedos722.img"]:
        print("Baixando imagem", name, flush=True)
        open(os.path.join(img, name), "wb").write(get_any(["https://i.copy.sh/" + name]))

what = sys.argv[1] if len(sys.argv) > 1 else "all"
if what in ("all", "v86"): setup_v86()
if what in ("all", "qemu"): setup_qemu()
print("Pronto! Agora rode: python3 serve.py")
