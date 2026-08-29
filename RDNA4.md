# onchainapps/rocm-llama.cpp

Consumer **RDNA4** (gfx1201) lab fork of [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp).

We push llama.cpp **and** the ROCm/HIP stack it sits on as far as they will go on Radeon AI PRO R9700-class cards (dual GPU tensor-split, long context, MTP). This is a **lab fork**, not a rebrand.

**Start here:** [`scripts/apply-rocm.sh check`](scripts/apply-rocm.sh) then [`docs/rdna4/HIP.md`](docs/rdna4/HIP.md).

## Credits (not ours)

We did not invent these projects. We use them, pin them, and document what actually works on this hardware.

| Project | Who | What we use |
|---|---|---|
| [llama.cpp](https://github.com/ggml-org/llama.cpp) | ggml-org and contributors | The whole inference engine. This GitHub repo is a **fork** of that tree. |
| [llama-cpp-rdna-boosts](https://github.com/stew675/llama-cpp-rdna-boosts) | [stew675](https://github.com/stew675) | Optional RDNA patch quilt (adaptive MTP, GDN kernels, k-quant mmvq, …). We apply **selected** blocks. We do not rebrand them. |
| [ROCm / HIP](https://github.com/ROCm/ROCm) | AMD | Runtime (`libamdhip64`). The gfx1201 tensor-split **load hang** is a HIP blit path, not a llama.cpp bug. |

llama.cpp license remains **MIT** (see `LICENSE`). stew675’s boosts are **MIT**. AMD HIP is **AMD’s** software; we do **not** vendor `libamdhip64.so` in this repo.

## What this fork adds

- Pins: llama SHA × HIP soname × GPU target — [`docs/rdna4/PIN.md`](docs/rdna4/PIN.md)
- HIP overlay recipe (no overwrite of `/opt/rocm`) — [`docs/rdna4/HIP.md`](docs/rdna4/HIP.md)
- Which stew blocks we actually ship vs measured washes — [`docs/rdna4/STEW.md`](docs/rdna4/STEW.md)
- `scripts/apply-rocm.sh` — check HIP `.so`, print a safe overlay env, optional HIP cmake, optional stew **01** only

Default **product** for our Qwen UD-Q8_K_XL coding work: **vanilla llama + HIP 53211 + stew 01 (adaptive MTP)**. Not `apply-all.sh`.

## What this fork is not

- Not AMD’s llama.cpp and not an official ROCm component
- Not stew675’s tree (his quilt stays a **second remote**)
- Not a place to hide llama “hang workarounds” — the load hang is HIP `rocblit` / `hipMemcpy2DAsync` on gfx1201
- Not a dump of every stew block until a named A/B on **this** hardware says it helps

## Hardware this lab actually has

- 2× AMD Radeon AI PRO R9700 (RDNA4, **gfx1201**, 32 GB each)
- Raphael **iGPU** is **not** a third compute card — do not tensor-split onto it
- Host RAM is tight (~30 GB). GGUF mmap is the path that fits; giant BF16 loads will not

## Tracking upstream

- `origin` → `onchainapps/rocm-llama.cpp`
- `upstream` → `ggml-org/llama.cpp` (rebase; don’t merge)
- `stew-boosts` → `stew675/llama-cpp-rdna-boosts` (watch; apply patches, don’t merge the quilt)

When llama.cpp ships a stew feature, **drop our copy** of that patch.
