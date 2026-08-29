#!/usr/bin/env bash
# apply-rocm.sh — help a machine get on par with this lab's HIP/.so + optional stew 01.
# Does NOT overwrite /opt/rocm. Does NOT vendor AMD HIP. Does NOT apply-all stew.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HANG_SONAME="libamdhip64.so.7.2.70204"
GOOD_SONAME="libamdhip64.so.7.2.53211"
GPU_TARGET="gfx1201"

usage() {
  cat <<'EOF'
Usage: scripts/apply-rocm.sh <command> [options]

  check                 HIP soname, hang vs LOAD_OK pin, GPU list (no writes)
  env [--prefix DIR]    print export lines for a HIP overlay prefix (eval-able)
  cmake [--print]       print (or --run) gfx1201 HIP cmake into ./build-rocm
  stew-01 --boosts-dir DIR
                        git apply stew675 01-adaptive-mtp only (opt-in)

Never copies a .so onto /opt/rocm. Never runs stew apply-all.

See RDNA4.md, docs/rdna4/HIP.md, docs/rdna4/STEW.md, docs/rdna4/PIN.md.
EOF
}

die() { echo "apply-rocm: $*" >&2; exit 1; }

hip_resolved() {
  local lib
  for lib in /opt/rocm/lib/libamdhip64.so.7 /opt/rocm/lib/libamdhip64.so; do
    if [[ -e "$lib" ]]; then
      readlink -f "$lib" 2>/dev/null || realpath "$lib" 2>/dev/null || echo "$lib"
      return 0
    fi
  done
  echo "MISSING"
}

cmd_check() {
  echo "== llama tree =="
  echo "ROOT=$ROOT"
  if git -C "$ROOT" rev-parse --short HEAD >/dev/null 2>&1; then
    echo "HEAD=$(git -C "$ROOT" rev-parse --short HEAD)"
  fi
  echo
  echo "== HIP soname (lab hang vs LOAD_OK) =="
  echo "hang pin : $HANG_SONAME  (stock 7.2.70204 — gfx1201 tensor-split load hang class)"
  echo "good pin : $GOOD_SONAME  (53211 product-clean rocblit)"
  local resolved
  resolved="$(hip_resolved)"
  echo "resolved : $resolved"
  if [[ "$resolved" == *53211* ]]; then
    echo "verdict  : HIP looks like the LOAD_OK soname"
  elif [[ "$resolved" == *70204* ]]; then
    echo "verdict  : HANG PATH — do not expect dual-GPU tensor load to finish"
    echo "           overlay 53211 via:  eval \"\$(scripts/apply-rocm.sh env --prefix /path/to/hip-prefix)\""
    echo "           do NOT overwrite /opt/rocm"
  elif [[ "$resolved" == MISSING ]]; then
    echo "verdict  : no /opt/rocm HIP library found"
  else
    echo "verdict  : unknown HIP build — run named A/B before trusting tensor-split load"
  fi
  echo
  echo "== AMD GPUs (iGPU is not a 3rd R9700) =="
  if command -v rocm-smi >/dev/null 2>&1; then
    rocm-smi --showproductname 2>/dev/null | sed 's/^/  /'
  elif command -v rocminfo >/dev/null 2>&1; then
    rocminfo 2>/dev/null | awk '
      /Device Type:/ { t=$0 }
      /Marketing Name:/ { m=$0 }
      /Name:[[:space:]]+gfx/ { print t; print m; print $0; print "---" }
    ' | sed 's/^/  /'
  else
    echo "  (rocm-smi/rocminfo not found)"
  fi
  echo
  echo "Tensor-split only discrete gfx1201 cards. Raphael/iGPU = skip."
}

cmd_env() {
  local prefix=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --prefix) prefix="${2:-}"; shift 2 ;;
      *) die "unknown env option: $1" ;;
    esac
  done
  [[ -n "$prefix" ]] || die "env requires --prefix DIR (HIP install prefix with lib/)"
  local libdir="$prefix/lib"
  [[ -d "$libdir" ]] || die "no lib dir: $libdir"
  if [[ ! -e "$libdir/$GOOD_SONAME" && ! -e "$libdir/libamdhip64.so.7" && ! -e "$libdir/libamdhip64.so" ]]; then
    die "no libamdhip64 in $libdir — this repo does not ship AMD's .so"
  fi
  # Refuse if prefix IS /opt/rocm (we don't mutate distro; env overlay is still ok to *read*)
  echo "export LD_LIBRARY_PATH=$(printf '%q' "$libdir")\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
  echo "export HIP_VISIBLE_DEVICES=\${HIP_VISIBLE_DEVICES:-0,1}"
  echo "# eval this. Does not write /opt/rocm." >&2
}

cmd_cmake() {
  local run=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --run) run=1; shift ;;
      --print) shift ;;
      *) die "unknown cmake option: $1" ;;
    esac
  done
  local hip_cc="${CMAKE_HIP_COMPILER:-/opt/rocm/lib/llvm/bin/clang++}"
  local flags=(
    -DGGML_HIP=ON
    -DGPU_TARGETS="$GPU_TARGET"
    "-DCMAKE_HIP_COMPILER=$hip_cc"
    -DGGML_HIP_GRAPHS=ON
    -DGGML_HIP_MMQ_MFMA=ON
    -DGGML_HIP_NO_VMM=ON
    -DGGML_CUDA_FA=ON
    -DGGML_HIP_RCCL=OFF
    -DLLAMA_BUILD_SERVER=ON
  )
  echo "cmake -S $ROOT -B $ROOT/build-rocm ${flags[*]}"
  if [[ "$run" -eq 1 ]]; then
    cmake -S "$ROOT" -B "$ROOT/build-rocm" "${flags[@]}"
    cmake --build "$ROOT/build-rocm" -j"$(nproc)"
  fi
}

cmd_stew01() {
  local boosts=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --boosts-dir) boosts="${2:-}"; shift 2 ;;
      *) die "unknown stew-01 option: $1" ;;
    esac
  done
  [[ -n "$boosts" ]] || die "stew-01 requires --boosts-dir (clone of stew675/llama-cpp-rdna-boosts)"
  local patch="$boosts/patches/01-adaptive-mtp.patch"
  [[ -f "$patch" ]] || die "missing $patch"
  echo "Applying stew675 01-adaptive-mtp (MIT, his work) onto $ROOT"
  git -C "$ROOT" apply --check "$patch" || die "patch does not apply to this SHA — stop (see docs/rdna4/STEW.md)"
  git -C "$ROOT" apply "$patch"
  echo "OK: 01-adaptive-mtp applied. Credit stew675. Not apply-all."
}

main() {
  local cmd="${1:-}"
  shift || true
  case "$cmd" in
    check) cmd_check "$@" ;;
    env) cmd_env "$@" ;;
    cmake) cmd_cmake "$@" ;;
    stew-01) cmd_stew01 "$@" ;;
    -h|--help|help|"") usage ;;
    *) usage; die "unknown command: $cmd" ;;
  esac
}

main "$@"
