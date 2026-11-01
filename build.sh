#!/bin/bash
# Build the plush module, and optionally a full Magic Lantern build for one camera.
#
#   ./build.sh ML_DIR              plush.mo + images in out/addon/ (add to an existing ML card)
#   ./build.sh ML_DIR 550D.109     also Magic Lantern for that camera, in out/card-550D.109/
#
# ML_DIR is a checkout of https://github.com/reticulatedpines/magiclantern_simplified
# CAMERA is a folder name under ML_DIR/platform/ (model.firmware, e.g. 600D.102).
#
# Optional environment:
#   ARM_TC    ARM GNU toolchain folder (has bin/arm-none-eabi-gcc)
#   ML_VENV   Python venv with docutils and pillow (default ~/opt/ml-venv, if present)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ML="$(cd "${1:?usage: ./build.sh ML_DIR [CAMERA]}" && pwd)"
CAM="${2:-}"
OUT="$HERE/out"

[ -f "$ML/modules/Makefile" ] || { echo "$ML doesn't look like a Magic Lantern checkout"; exit 1; }
[ -z "$CAM" ] || [ -d "$ML/platform/$CAM" ] || { echo "no such camera: $ML/platform/$CAM"; exit 1; }

# --- tools -------------------------------------------------------------------

VENV="${ML_VENV:-$HOME/opt/ml-venv}"
[ -d "$VENV/bin" ] && export PATH="$VENV/bin:$PATH"
python3 -c "import docutils, PIL" 2>/dev/null ||
    { echo "python3 needs docutils and pillow (see README)"; exit 1; }

if [ -n "${ARM_TC:-}" ]; then
    ARM_BIN="$ARM_TC/bin"
elif command -v arm-none-eabi-gcc >/dev/null; then
    ARM_BIN="$(dirname "$(command -v arm-none-eabi-gcc)")"
else
    ARM_BIN="$(ls -d "$HOME"/opt/arm-gnu-toolchain-*-arm-none-eabi/bin 2>/dev/null | tail -1)"
fi
# Homebrew's arm-none-eabi-gcc has no C library headers, so check for them
echo '#include <stdint.h>' | "$ARM_BIN/arm-none-eabi-gcc" -E - >/dev/null 2>&1 ||
    { echo "need an arm-none-eabi-gcc with C library headers (see README)"; exit 1; }

MAKE_ARGS=(ARM_BINPATH="$ARM_BIN" READELF="$ARM_BIN/arm-none-eabi-readelf")
if [ "$(uname)" = Darwin ]; then
    MAKE_ARGS+=(STAT_CMD='stat -f "%N: %z bytes"')
fi

# --- images ------------------------------------------------------------------

echo "== images"
mkdir -p "$OUT"
python3 -I "$HERE/tools/make_cropmark.py" "$HERE/images/plush.webp" "$OUT/STICKER.BMP" --sticker --height 288
python3 -I "$HERE/tools/make_cropmark.py" "$HERE/images/plush.webp" "$OUT/PLUSH.BMP" --preview "$OUT/preview.png"

# --- module ------------------------------------------------------------------

echo "== plush module"
mkdir -p "$ML/modules/plush"
cp "$HERE"/plush/* "$ML/modules/plush/"
make -C "$ML/modules/plush" "${MAKE_ARGS[@]}" > "$OUT/build-module.log" 2>&1 ||
    { tail -30 "$OUT/build-module.log"; exit 1; }

rm -rf "$OUT/addon"
mkdir -p "$OUT/addon/ML/modules" "$OUT/addon/ML/data" "$OUT/addon/ML/cropmks"
cp "$ML/modules/plush/build/plush.mo" "$OUT/addon/ML/modules/"
cp "$OUT/STICKER.BMP" "$OUT/addon/ML/data/PLUSH.BMP"
cp "$OUT/PLUSH.BMP" "$OUT/addon/ML/cropmks/PLUSH.BMP"
echo "out/addon/: copy onto a card that already has Magic Lantern"

[ -z "$CAM" ] && exit 0

# --- full Magic Lantern build --------------------------------------------------

echo "== Magic Lantern $CAM"
# ML's default modules, minus lua (doesn't compile with newer ARM toolchains), plus plush
MODS="$(sed -n '/^ML_MODULES = /,/^$/p' "$ML/modules/Makefile" | tr -d '\\' |
        sed 's/ML_MODULES =//' | tr -s ' \n' ' ' | sed 's/ lua / /') plush"

# the camera's bundled-module list names lua too; swap it for plush during the build
INCLUDED="$ML/platform/$CAM/modules.included"
cp "$INCLUDED" "$OUT/modules.included.orig"
trap 'cp "$OUT/modules.included.orig" "$INCLUDED"' EXIT
grep -v '^lua$' "$OUT/modules.included.orig" | grep -v '^plush$' > "$INCLUDED"
echo plush >> "$INCLUDED"

make -C "$ML/platform/$CAM" "${MAKE_ARGS[@]}" ML_MODULES="$MODS" -j8 > "$OUT/build-$CAM.log" 2>&1 ||
    { tail -30 "$OUT/build-$CAM.log"; exit 1; }

CARD="$OUT/card-$CAM"
rm -rf "$CARD"
mkdir -p "$CARD"
(cd "$CARD" && unzip -q "$ML/platform/$CAM/build/magiclantern.zip")
cp -R "$OUT/addon/ML/." "$CARD/ML/"
echo "out/card-$CAM/: copy onto a freshly formatted card"
