# ROCm PR draft — gfx1201 rocblit rect-DMA (NOT FILED)

**Status:** prepared for a human to paste. **Do not** `gh pr create` unless the repo owner says **file it**.

## Where it goes

| | |
|---|---|
| **Repo** | **[ROCm/rocm-systems](https://github.com/ROCm/rocm-systems)** |
| **Base branch** | `develop` |
| **File** | `projects/clr/rocclr/device/rocm/rocblit.cpp` |
| **Functions** | `KernelBlitManager::readBufferRect` and `writeBufferRect` |
| **Reviewers** | CODEOWNERS on that path (`@ROCm/clr-reviewers` when the bot routes) |
| **Branch name** | `users/<github-username>/gfx1201-rocblit-rect-dma` (their convention) |

**Not these:**

| Repo | Why not |
|---|---|
| [ROCm/TheRock](https://github.com/ROCm/TheRock) | Superbuild. CLR arrives later as a **`rocm-systems` submodule bump**. Do not put this diff in TheRock. |
| [ROCm/clr](https://github.com/ROCm/clr) | Legacy/mirror. Commits there are **patched back from** `rocm-systems` (`[rocm-systems] ROCm/rocm-systems#NNNN`). Filing on `ROCm/clr` is the old world. |
| ggml-org/llama.cpp | Hang is HIP, not llama. |

Lab overlay pin stays **rocm-systems `97f5574` / rocm-7.2.4**. Filing is against **today’s `develop`** (line numbers moved; lock is `std::scoped_lock`). `develop` still has **no** `gfx1201` skip (checked 2026-08-29).

## Patches in this tree

| Patch | Against |
|---|---|
| [`patches/rocblit-gfx1201-rect-dma.patch`](patches/rocblit-gfx1201-rect-dma.patch) | CLR-root, **7.2.4 / `97f5574`** — what we measured |
| [`patches/rocblit-gfx1201-rect-dma-rocm-systems-develop.patch`](patches/rocblit-gfx1201-rect-dma-rocm-systems-develop.patch) | **rocm-systems `develop`** — what to file |

## Suggested title

`gfx1201: skip KernelBlit pin+copyBufferRect for BufferRect; use line DMA`

## Suggested body

```markdown
## Summary

On RDNA4 **gfx1201**, dual-GPU llama.cpp tensor-split weight load can hang
in userspace HIP:

`hipMemcpy2DAsync` → `KernelBlitManager::writeBufferRect` → pin + `copyBufferRect`
→ HSA wait.

Same llama.cpp binary (`5ea1b124e`), **soname swap only**:

| HIP | Result |
|---|---|
| `libamdhip64.so.7.2.70204` (stock 7.2.4, this skip **absent**) | hang (300s timeout class) |
| `libamdhip64.so.7.2.53211` rebuilt from CLR `97f5574` **with this change** | LOAD_OK |

gfx1201-only: `KernelBlitManager::{write,read}BufferRect` call
`DmaBlitManager::{write,read}BufferRect` + `synchronize()` instead of the
kernel-blit pin+`copyBufferRect` path.

## What this is not

- Not a llama.cpp bug / not a llama memcpy workaround.
- Not a kernel-module patch.
- We have **not** proven *why* `copyBufferRect` deadlocks in HSA on this ASIC.
  Unique HIP-layer cause (this blit path) **was** matched A/B’d.

## Hardware

2× AMD Radeon AI PRO R9700 (gfx1201, 32 GB), ROCm 7.2.4, host RAM ~30 GB.
iGPU not in the tensor-split set.

## Test

llama.cpp HIP, `--split-mode tensor --tensor-split 1,1`, GGUF mmap load.
Unpatched matched 53211 prefix: hang. Patched overlay: LOAD_OK.

Please apply on `projects/clr/rocclr/device/rocm/rocblit.cpp` (`develop`).
```

## A/B (attach when filing)

- Unpatched matched 53211 prefix hang vs overlay LOAD_OK (same CLR `97f5574`).
- Shipping `/opt/rocm` `libamdhip64.so.7.2.70204` is the hang class until AMD ships this.
- Do **not** claim kernel root cause.

## Ownership

Human files. Agent may refresh draft + patches from lab evidence only.
