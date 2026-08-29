#!/usr/bin/env bash
# Isolated HIP/CLR prefix: gfx1201 skip pin+copyBufferRect → line DMA.
# NEVER writes /opt/rocm. Does not vendor AMD .so into git.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCH="$ROOT/docs/rdna4/patches/rocblit-gfx1201-rect-dma.patch"
CLANG="${CLANG:-/opt/rocm/lib/llvm/bin/clang}"
CLANGXX="${CLANGXX:-/opt/rocm/lib/llvm/bin/clang++}"
SYSTEMS=""
PREFIX=""

usage() {
  cat <<'EOF'
Usage: scripts/build-hip-overlay.sh --systems-dir DIR --prefix DIR

  --systems-dir   clone of ROCm/rocm-systems at 97f5574 (rocm-7.2.4)
  --prefix        isolated install prefix (libamdhip64 lands here)

Refuses prefix /opt/rocm and /usr. See docs/rdna4/HIP-BUILD.md.
EOF
}

die() { echo "build-hip-overlay: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --systems-dir) SYSTEMS="${2:-}"; shift 2 ;;
    --prefix) PREFIX="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

[[ -n "$SYSTEMS" && -n "$PREFIX" ]] || { usage; die "need --systems-dir and --prefix"; }
[[ -f "$PATCH" ]] || die "missing $PATCH"
[[ -x "$CLANGXX" ]] || die "no HIP clang++ at $CLANGXX — install ROCm 7.2.4 first"

# resolve prefix; refuse distro
PREFIX="$(mkdir -p "$PREFIX" && cd "$PREFIX" && pwd)"
case "$PREFIX" in
  /opt/rocm|/opt/rocm/*|/usr|/usr/*)
    die "refusing prefix $PREFIX (would touch distro ROCm)"
    ;;
esac

CLR="$SYSTEMS/projects/clr"
HIP="$SYSTEMS/projects/hip"
[[ -d "$CLR/rocclr/device/rocm" ]] || die "not a rocm-systems tree (missing projects/clr): $SYSTEMS"
[[ -d "$HIP" ]] || die "missing projects/hip in $SYSTEMS"

command -v ninja >/dev/null || die "ninja not found"
command -v python3 >/dev/null || die "python3 not found"

WORK="${BUILD_HIP_WORK:-$PREFIX/.build-clr}"
SRC="$WORK/clr-src"
BUILD="$WORK/build"
VENV="$WORK/venv"
mkdir -p "$SRC" "$BUILD" "$PREFIX"

echo "==== rsync CLR → $SRC ===="
rsync -a --delete --exclude '.git' --exclude 'build' --exclude '.cache' "$CLR/" "$SRC/"

echo "==== apply rocblit gfx1201 rect-DMA ===="
if grep -q 'gfx1201: KernelBlit pin+copyBufferRect' "$SRC/rocclr/device/rocm/rocblit.cpp"; then
  echo "patch already present in worktree"
else
  (cd "$SRC" && patch -p1 < "$PATCH")
fi
grep -q 'gfx1201: KernelBlit pin+copyBufferRect' "$SRC/rocclr/device/rocm/rocblit.cpp" \
  || die "patch did not land on rocblit.cpp"

echo "==== venv CppHeaderParser ===="
if [[ ! -x "$VENV/bin/python" ]]; then
  python3 -m venv "$VENV"
fi
"$VENV/bin/pip" install -q CppHeaderParser

echo "==== cmake (install → $PREFIX) ===="
cmake "$SRC" -G Ninja \
  -B "$BUILD" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER="$CLANG" \
  -DCMAKE_CXX_COMPILER="$CLANGXX" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="/opt/rocm" \
  -DCLR_BUILD_HIP=ON \
  -DCLR_BUILD_OCL=OFF \
  -DHIP_PLATFORM=amd \
  -DHIP_COMMON_DIR="$HIP" \
  -DHIPCC_BIN_DIR="/opt/rocm/bin" \
  -D__HIP_ENABLE_PCH=OFF \
  -DUSE_PROF_API=OFF \
  -DPython3_EXECUTABLE="$VENV/bin/python"

echo "==== ninja install ===="
cmake --build "$BUILD" -j"$(nproc)"
cmake --install "$BUILD"

LIB="$(find "$PREFIX" -name 'libamdhip64.so*' -type f | head -1 || true)"
[[ -n "$LIB" ]] || die "install produced no libamdhip64 under $PREFIX"
echo "LIB=$LIB"
sha256sum "$LIB"
readlink -f "$LIB" || true
echo "==== prove /opt/rocm untouched ===="
stat -c '%y %s %n' /opt/rocm/lib/libamdhip64.so.7.2.70204 2>/dev/null || true
echo "OK: overlay prefix $PREFIX"
echo "next: eval \"\$( $ROOT/scripts/apply-rocm.sh env --prefix $PREFIX )\""
