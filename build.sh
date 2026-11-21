#!/usr/bin/env bash
# Compila o QEMU-wasm (x86_64) com Emscripten. Roda dentro do WSL/Linux.
# Uso: build.sh <em++> <fonte> <saida> <sdl s/n> <wasm32|wasm64> <memoria max> <jobs>
set -euo pipefail
clean(){ printf '%s' "${1:-}" | tr -d '\r"'; }
topath(){ local p; p="$(clean "$1")"; if [[ "$p" =~ ^[A-Za-z]:[\\/] ]]; then wslpath -u "$p"; else echo "$p"; fi; }
HERE="$(cd "$(dirname "$0")" && pwd)"
EMPP="$(clean "${1:-}")"; SRC="$(clean "${2:-}")"; OUT="$(topath "${3:-$HERE/dist}")"
SDL="$(clean "${4:-n}")"; ARCH="$(clean "${5:-wasm32}")"; MAXMEM="$(clean "${6:-4GB}")"; JOBS="$(clean "${7:-$(nproc)}")"
[ -z "$SDL" ] && SDL=n; [ -z "$ARCH" ] && ARCH=wasm32; [ -z "$MAXMEM" ] && MAXMEM=4GB; [ -z "$JOBS" ] && JOBS="$(nproc)"
[ -n "$SRC" ] && SRC="$(topath "$SRC")" || SRC="$HOME/qemu-wasm-src"
mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"
say(){ printf '\n\033[1;36m== %s\033[0m\n' "$*"; }

say "Checando ferramentas do Linux"
need=""; for t in git python3 curl make ninja meson pkg-config autoconf automake libtoolize xz; do command -v $t >/dev/null || need="$need $t"; done
if [ -n "$need" ]; then
  echo "Faltam:$need"
  echo "Instale com: sudo apt-get update && sudo apt-get install -y git python3 python3-pip curl make ninja-build meson pkg-config autoconf automake libtool xz-utils build-essential"
  exit 1
fi

say "Emscripten"
if [ -z "$EMPP" ]; then
  [ -d "$HOME/emsdk" ] || git clone --depth 1 https://github.com/emscripten-core/emsdk.git "$HOME/emsdk"
  (cd "$HOME/emsdk" && ./emsdk install 4.0.10 && ./emsdk activate 4.0.10)
  EMPP="$HOME/emsdk/upstream/emscripten/em++"
else EMPP="$(topath "$EMPP")"; fi
[ -f "$EMPP" ] || { echo "em++ nao encontrado em: $EMPP (precisa ser um caminho do Linux/WSL)"; exit 1; }
d="$(dirname "$(readlink -f "$EMPP")")"; envsh=""
for i in 1 2 3 4; do [ -f "$d/emsdk_env.sh" ] && { envsh="$d/emsdk_env.sh"; break; }; d="$(dirname "$d")"; done
if [ -n "$envsh" ]; then (cd "$(dirname "$envsh")" && true); source "$envsh" >/dev/null 2>&1 || true; else export PATH="$(dirname "$EMPP"):$PATH"; fi
em++ --version | head -1 || { echo "em++ nao executa. Use o emsdk do Linux (nao o do Windows)."; exit 1; }

say "Codigo-fonte: $SRC"
[ -d "$SRC/.git" ] || [ -f "$SRC/configure" ] || git clone --depth 1 https://github.com/ktock/qemu-wasm "$SRC"

say "Dependencias (zlib, libffi, pixman, glib) -> $OUT/deps"
DEPS="${DEPS_PREFIX:-$OUT/deps}"; W="$OUT/work"; mkdir -p "$DEPS" "$W"
DEPFLAGS="-pthread -O2"; [ "$ARCH" = wasm64 ] && DEPFLAGS="$DEPFLAGS -sMEMORY64=1"
export PKG_CONFIG_LIBDIR="$DEPS/lib/pkgconfig:$DEPS/share/pkgconfig"; export PKG_CONFIG_PATH=""
CPUFAM=wasm32; [ "$ARCH" = wasm64 ] && CPUFAM=wasm64
cat > "$W/emscripten.cross" <<CROSS
[binaries]
c = 'emcc'
cpp = 'em++'
ar = 'emar'
ranlib = 'emranlib'
pkg-config = 'pkg-config'
[built-in options]
c_args = [$(for f in $DEPFLAGS; do printf "'%s'," "$f"; done)]
cpp_args = [$(for f in $DEPFLAGS; do printf "'%s'," "$f"; done)]
c_link_args = [$(for f in $DEPFLAGS; do printf "'%s'," "$f"; done)]
[host_machine]
system = 'emscripten'
cpu_family = '$CPUFAM'
cpu = '$CPUFAM'
endian = 'little'
[properties]
needs_exe_wrapper = true
CROSS
fetch(){ [ -d "$W/$2" ] || (cd "$W" && curl -fL "$1" | tar x${3:-z}f -); }
if [ ! -f "$DEPS/.deps-ok" ]; then
  fetch https://zlib.net/fossils/zlib-1.3.1.tar.gz zlib-1.3.1
  (cd "$W/zlib-1.3.1" && CFLAGS="$DEPFLAGS" emconfigure ./configure --prefix="$DEPS" --static && emmake make -j"$JOBS" install)
  fetch https://github.com/libffi/libffi/releases/download/v3.5.2/libffi-3.5.2.tar.gz libffi-3.5.2
  (cd "$W/libffi-3.5.2" && CFLAGS="$DEPFLAGS" emconfigure ./configure --host=wasm32-unknown-linux --prefix="$DEPS" --enable-static --disable-shared --disable-docs --disable-multi-os-directory --disable-raw-api && emmake make -j"$JOBS" install)
  fetch https://cairographics.org/releases/pixman-0.44.2.tar.gz pixman-0.44.2
  (cd "$W/pixman-0.44.2" && meson setup _b --cross-file "$W/emscripten.cross" --prefix="$DEPS" --default-library=static -Dtests=disabled -Ddemos=disabled -Dgtk=disabled -Dlibpng=disabled -Dopenmp=disabled && ninja -C _b install)
  fetch https://download.gnome.org/sources/glib/2.84/glib-2.84.0.tar.xz glib-2.84.0 J
  (cd "$W/glib-2.84.0" && meson setup _b --cross-file "$W/emscripten.cross" --prefix="$DEPS" --default-library=static -Dtests=false -Dnls=disabled -Dlibmount=disabled -Dselinux=disabled -Dxattr=false -Dlibelf=disabled -Dintrospection=disabled -Dman-pages=disabled -Ddocumentation=false -Dglib_debug=disabled && ninja -C _b install)
  touch "$DEPS/.deps-ok"
else echo "Dependencias ja prontas (apague $DEPS/.deps-ok para refazer)."; fi

EXTRA_CFG=""
if [ "$SDL" = "s" ] || [ "$SDL" = "S" ]; then
  say "SDL2 (experimental): criando sdl2.pc para o port do Emscripten"
  cat > "$DEPS/lib/pkgconfig/sdl2.pc" <<PC
Name: sdl2
Description: SDL2 do Emscripten
Version: 2.30.0
Cflags: -sUSE_SDL=2
Libs: -sUSE_SDL=2
PC
  EXTRA_CFG="--enable-sdl"
fi

say "Configurando QEMU ($ARCH)"
PTY="$W/emscripten-pty.js"
[ -f "$PTY" ] || curl -fL https://cdn.jsdelivr.net/npm/xterm-pty/emscripten-pty.js -o "$PTY"
export CFLAGS="$DEPFLAGS"; export CXXFLAGS="$DEPFLAGS"
export LDFLAGS="-pthread -sALLOW_MEMORY_GROWTH=1 -sMAXIMUM_MEMORY=$MAXMEM -sFORCE_FILESYSTEM=1 -sEXPORTED_RUNTIME_METHODS=FS,TTY --pre-js $PTY ${EXTRA_LDFLAGS:-}"
[ "$ARCH" = wasm64 ] && export LDFLAGS="$LDFLAGS -sMEMORY64=1"
mkdir -p "$OUT/build" && cd "$OUT/build"
emconfigure "$SRC/configure" --static --target-list=x86_64-softmmu --cpu="$ARCH" --enable-tcg-interpreter \
  --disable-tools --disable-docs --disable-gio --disable-slirp --disable-werror $EXTRA_CFG ${EXTRA_CONFIGURE:-}

say "Compilando (demora)"
emmake make -j"$JOBS"

say "Empacotando no projeto web"
python3 "$HERE/make-dist.py" "$OUT/build" "$HERE/web/images"
echo; echo "Pronto! Rode: python3 web/serve.py  (depois rode web/setup.py uma vez para baixar o restante, se ainda nao fez)"
