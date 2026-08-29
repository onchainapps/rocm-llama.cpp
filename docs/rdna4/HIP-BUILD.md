# Isolated HIP overlay (no `/opt/rocm` writes)

Rebuild **userspace** `libamdhip64` from ROCm 7.2.4 CLR with the gfx1201 rect-DMA skip. Distro HSA stays shipping.

Script: [`scripts/build-hip-overlay.sh`](../../scripts/build-hip-overlay.sh).

## Inputs

| | |
|---|---|
| Current ROCm dev | [ROCm/TheRock](https://github.com/ROCm/TheRock) — superbuild; CLR is submodule `rocm-systems` |
| Overlay pin (this hang A/B) | [ROCm/rocm-systems](https://github.com/ROCm/rocm-systems) @ `97f5574fe2fdc7bef44fb01545347912ee9f1779` (`rocm-7.2.4`). Do not mix TheRock HEAD with this 7.2.4 recipe until a named rebuild. |
| CLR tree | `$SYSTEMS/projects/clr` |
| HIP common | `$SYSTEMS/projects/hip` |
| Patch | [`patches/rocblit-gfx1201-rect-dma.patch`](patches/rocblit-gfx1201-rect-dma.patch) applied at CLR root |
| Compiler | `/opt/rocm/lib/llvm/bin/clang` + `clang++` (shipping 7.2.4) |
| Install prefix | **not** `/opt/rocm`, **not** `/usr` |

## CMake (what the script runs)

```bash
cmake "$CLR" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=/opt/rocm/lib/llvm/bin/clang \
  -DCMAKE_CXX_COMPILER=/opt/rocm/lib/llvm/bin/clang++ \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH=/opt/rocm \
  -DCLR_BUILD_HIP=ON \
  -DCLR_BUILD_OCL=OFF \
  -DHIP_PLATFORM=amd \
  -DHIP_COMMON_DIR="$SYSTEMS/projects/hip" \
  -DHIPCC_BIN_DIR=/opt/rocm/bin \
  -D__HIP_ENABLE_PCH=OFF \
  -DUSE_PROF_API=OFF \
  -DPython3_EXECUTABLE="$VENV/bin/python"
ninja -C "$BUILD" install
```

Needs `CppHeaderParser` in that venv (HIP headers).

## Bind

```bash
eval "$(./scripts/apply-rocm.sh env --prefix "$PREFIX")"
# LD_LIBRARY_PATH=$PREFIX/lib:...
```

`ldd` on `libggml-hip.so` must realpath to `$PREFIX/lib/libamdhip64.so.7.2.53211` (or a 53211 soname you just built).

## What this is not

- Not a kernel module. Not a llama.cpp patch.
- Not proof of *why* `copyBufferRect` deadlocks in HSA (still **UNPROVEN**).
- Not bit-identical to AMD’s fat 27 MiB shipping `7.2.70204` (embedded kernels). Overlay is a thin HIP with `libamd_comgr`. Matched A/B still: unpatched hang vs this rocblit skip LOAD_OK.

## Lab example prefix (this machine only)

```text
/home/don/.cache/hermes-builds/hip-gfx1201-rect-dma-20260829b/prefix
```

Other machines must build their own. This repo does not ship the `.so`.
