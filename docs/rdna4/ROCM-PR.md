# ROCm PR draft — gfx1201 rocblit rect-DMA (NOT FILED)

**Status:** prepared for a human to paste. **Do not** `gh pr create` / open an issue unless the repo owner says so.

**Current ROCm development home:** [ROCm/TheRock](https://github.com/ROCm/TheRock) (HIP Environment and ROCm Kit). CLR still lives in the **`rocm-systems` submodule** (`https://github.com/ROCm/rocm-systems.git` → TheRock path `rocm-systems/`).

**File:** `rocclr/device/rocm/rocblit.cpp` (CLR-root). In the 7.2.4 monorepo checkout we measured: `projects/clr/rocclr/device/rocm/rocblit.cpp`.

**Where to file (human decides, agent does not open):** prefer TheRock’s contributing path so it lands with current ROCm; the diff itself is CLR/`rocblit`. Do **not** file a llama.cpp PR.

**Reviewers (when filing):** `@ROCm/clr-reviewers`

**Not:** ggml-org/llama.cpp. **Not** a llama hang workaround. **Not** GitHub issue #4817 (education only; different story).

**Pin:** CLR / rocm-systems `97f5574fe2fdc7bef44fb01545347912ee9f1779` (`rocm-7.2.4`). HIP version string 7.2.53211 vs packaged hang soname `libamdhip64.so.7.2.70204`.

**Patch:** [`patches/rocblit-gfx1201-rect-dma.patch`](patches/rocblit-gfx1201-rect-dma.patch)

---

## Suggested title

`gfx1201: skip KernelBlit pin+copyBufferRect for BufferRect; use line DMA`

## Suggested body

```markdown
## Summary

On RDNA4 **gfx1201** (Radeon AI PRO R9700), dual-GPU llama.cpp tensor-split
weight load can hang in userspace HIP:

`hipMemcpy2DAsync` → `KernelBlitManager::writeBufferRect` → pin + `copyBufferRect`
→ HSA wait.

Same llama.cpp binary (`5ea1b124e`), **soname swap only**:

| HIP | Result |
|---|---|
| `libamdhip64.so.7.2.70204` (stock 7.2.4, this rocblit skip **absent**) | hang (300s timeout class) |
| `libamdhip64.so.7.2.53211` rebuilt from CLR `97f5574` **with this patch** | LOAD_OK |

The change is gfx1201-only: `KernelBlitManager::{write,read}BufferRect` call
`DmaBlitManager::{write,read}BufferRect` + `synchronize()` instead of the
kernel-blit pin+`copyBufferRect` path.

## What this is not

- Not a llama.cpp bug / not a llama memcpy workaround.
- Not a kernel-module patch.
- We have **not** proven *why* `copyBufferRect` deadlocks in HSA on this ASIC.
  Unique HIP-layer cause (this blit path) **was** matched A/B’d.

## Hardware

2× AMD Radeon AI PRO R9700 (gfx1201, 32 GB), ROCm 7.2.4, host RAM ~30 GB.
Raphael iGPU not in the tensor-split set.

## Test

llama.cpp HIP, `--split-mode tensor --tensor-split 1,1`, GGUF mmap load.
Unpatched matched 53211 prefix: hang. Patched overlay: LOAD_OK.

Please apply on `rocclr/device/rocm/rocblit.cpp`.
```

---

## A/B shape (attach when filing)

- Unpatched matched 53211 prefix hang vs overlay LOAD_OK (same CLR githash `97f5574`).
- Shipping `/opt/rocm` `libamdhip64.so.7.2.70204` is the hang class until AMD ships the branch.
- Do **not** claim kernel root cause.

## Ownership

Human files. Agent may refresh this draft + patch from lab evidence only.
