# HIP / ROCm on RDNA4 (gfx1201)

## The load hang is HIP, not llama.cpp

On shipping ROCm **7.2.70204**, dual-GPU tensor-split can stick at weight load:

`load_all_data` → `hipMemcpy2DAsync` → rocblit `writeBufferRect` / `copyBufferRect` → HSA wait.

**Unique cause we measured:** gfx1201 rect-DMA path in userspace HIP (`rocblit`), not a llama.cpp bug. Do **not** “fix” this with llama memcpy workarounds as the product answer.

**What works here:** HIP **`libamdhip64.so.7.2.53211`** (lab “product-clean” rocblit: gfx1201 → line DMA). Same llama binary, soname swap, LOAD_OK.

Patch: [`patches/rocblit-gfx1201-rect-dma.patch`](patches/rocblit-gfx1201-rect-dma.patch). Isolated rebuild: [`HIP-BUILD.md`](HIP-BUILD.md). AMD PR draft (not filed): [`ROCM-PR.md`](ROCM-PR.md).

HSA *why* copyBufferRect deadlocks on 70204 is still **unproven**. We document the A/B, we don’t invent a kernel story.

## Do not overwrite `/opt/rocm`

- Distro tree stays distro.
- Overlay = extra prefix or a **soname file** + `LD_LIBRARY_PATH` / loader pin.
- `scripts/apply-rocm.sh` will **refuse** to copy a `.so` onto `/opt/rocm`.

On the machine that cut these notes, `libamdhip64.so.7` may already point at **53211**. Other boxes will still be **70204**. Always run:

```bash
./scripts/apply-rocm.sh check
```

## Overlay (safe)

Build or keep a prefix that contains `lib/libamdhip64.so.7.2.53211` (and the usual HIP siblings). Then:

```bash
eval "$(./scripts/apply-rocm.sh env --prefix /path/to/hip-53211-prefix)"
# or:
export LD_LIBRARY_PATH=/path/to/hip-53211-prefix/lib:${LD_LIBRARY_PATH}
```

This repo **does not ship** `libamdhip64.so`. That is AMD’s binary. Point `apply-rocm.sh` at **your** prefix.

## Tensor-split (this lab)

- Devices: discrete R9700s only (`ROCm0,ROCm1` here).
- `--split-mode tensor --tensor-split 1,1`
- Raphael iGPU is **not** a third R9700. Tensor-split onto it is a footgun.
- `--mmap` (or `--load-mode mmap`) for GGUF under a ~30 GB host RAM ceiling.

## Daily vs lab ports (our house)

- Lab HIP tensor port: `:18080`
- Do not assume Vulkan / other backends are in scope unless you name them.
