# rocm-llama.cpp

Lab fork of [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp) for **consumer RDNA4 (gfx1201)** — dual Radeon AI PRO R9700, ROCm/HIP tensor-split, long context, MTP.

**Point an AI agent at [`AGENTS.md`](AGENTS.md).** Humans can follow the same commands below.

## Credits

| Project | Who | What |
|---|---|---|
| [llama.cpp](https://github.com/ggml-org/llama.cpp) | ggml-org | The engine. This GitHub repo is a **fork** of that tree. |
| [llama-cpp-rdna-boosts](https://github.com/stew675/llama-cpp-rdna-boosts) | [stew675](https://github.com/stew675) | **01-adaptive-mtp** only (optional). Not `apply-all`. |
| [TheRock](https://github.com/ROCm/TheRock) | AMD | Current ROCm/HIP **development** home. CLR is the `rocm-systems` submodule. |
| HIP runtime | AMD | `libamdhip64`. gfx1201 tensor-split **load hang** is HIP `rocblit`, not llama.cpp. We do **not** vendor the `.so`. |

License: llama.cpp **MIT**. stew675 boosts **MIT**. AMD HIP is AMD’s.

## Pins (bump only after a named A/B)

| Key | Pin |
|---|---|
| GPU target | `gfx1201` |
| Distro ROCm | **7.2.4** (`/opt/rocm` → distro). **Never overwrite `/opt/rocm`.** |
| HIP LOAD_OK (tensor-split) | `libamdhip64.so.7.2.53211` |
| HIP hang class | `libamdhip64.so.7.2.70204` (stock 7.2.4) |
| llama vehicle we measured | `5ea1b124e` + HIP 53211, dual R9700 |
| stew quilt (his world) | `baseline/fe235f434` on **ROCm 7.14** — **not** this box |
| stew in **our** product | **01 only** (`01-adaptive-mtp`) |
| coding bar GGUF | `Qwen3.8-27B-UD-Q8_K_XL` (stay on XL; stew 10 is Q8_0/Q4/Q5/Q6 mmvq) |

Full table: [`docs/rdna4/PIN.md`](docs/rdna4/PIN.md).

## Layout

```
├── README.md                 # this file
├── AGENTS.md                 # fail-closed contract for AI agents
├── RDNA4.md                  # one-page charter
├── docs/rdna4/
│   ├── PIN.md                # version pins
│   ├── HIP.md                # hang is HIP, overlay recipe
│   ├── HIP-BUILD.md          # isolated CLR prefix (no /opt/rocm writes)
│   ├── STEW.md               # which stew blocks, measured
│   ├── ROCM-PR.md            # CLR rocblit PR draft — not filed
│   └── patches/rocblit-gfx1201-rect-dma.patch
├── scripts/
│   ├── apply-rocm.sh         # check / env / cmake / stew-01
│   └── build-hip-overlay.sh  # isolated libamdhip64 from CLR + patch
└── .github/workflows/rdna4-stew01-apply.yml   # apply-canary, no GPU
```

The rest of the tree is upstream llama.cpp. Engine docs live **there**: [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp).

## Hard rules

1. **Do not overwrite `/opt/rocm`.** Overlay = extra prefix + `LD_LIBRARY_PATH`.
2. **Do not vendor or copy AMD `.so` files into this repo.**
3. **Do not run stew `apply-all.sh` as product.** 01 only unless a named A/B on **this** GGUF says otherwise.
4. Tensor-split **discrete gfx1201 only**. Raphael / iGPU is **not** a third R9700.
5. Load hang fix is **HIP `rocblit`**, not a llama memcpy patch. Do not upstream llama “hang workarounds” as the answer.
6. Do **not** open a GitHub issue/PR against ROCm or llama.cpp unless the human names that action. Draft: [`docs/rdna4/ROCM-PR.md`](docs/rdna4/ROCM-PR.md).

## Consumer / agent workflow

```bash
git clone https://github.com/onchainapps/rocm-llama.cpp
cd rocm-llama.cpp

# 0. what HIP is actually loaded?
./scripts/apply-rocm.sh check
```

`check` prints the resolved `libamdhip64` path and hang vs LOAD_OK soname.

### If resolved HIP is `*.70204` (hang path)

Stock ROCm 7.2.4 dual-GPU tensor-split can stick at weight load:

`load_all_data` → `hipMemcpy2DAsync` → `KernelBlitManager::writeBufferRect` pin+`copyBufferRect` → HSA wait.

Same llama binary, swap HIP soname to **53211** (gfx1201 → line DMA) → LOAD_OK. HSA *why* is still **unproven**.

Build an **isolated** HIP prefix (needs ROCm 7.2.4 headers/clang already installed):

```bash
git clone https://github.com/ROCm/rocm-systems.git "$HOME/src/rocm-systems-7.2.4"
git -C "$HOME/src/rocm-systems-7.2.4" checkout 97f5574fe2fdc7bef44fb01545347912ee9f1779   # rocm-7.2.4

PREFIX="$HOME/.cache/rocm-llama-hip-53211"
./scripts/build-hip-overlay.sh \
  --systems-dir "$HOME/src/rocm-systems-7.2.4" \
  --prefix "$PREFIX"

eval "$(./scripts/apply-rocm.sh env --prefix "$PREFIX")"
./scripts/apply-rocm.sh check
# ldd on libggml-hip.so must realpath to libamdhip64.so.7.2.53211
```

Exact cmake and refuse-`/opt/rocm` gates: [`docs/rdna4/HIP-BUILD.md`](docs/rdna4/HIP-BUILD.md).

This lab’s measured overlay (example, **your** box will differ):

```text
/home/don/.cache/hermes-builds/hip-gfx1201-rect-dma-20260829b/prefix/lib/libamdhip64.so.7.2.53211
```

Shipping tree still contains the hang soname:

```text
/opt/rocm/lib/libamdhip64.so.7.2.70204     # hang class — leave it
/opt/rocm/lib/libamdhip64.so.7.2.53211     # LOAD_OK if the linker actually picks this
```

Always `readlink -f /opt/rocm/lib/libamdhip64.so.7` — do not assume.

### Build llama.cpp (HIP, gfx1201)

```bash
./scripts/apply-rocm.sh cmake --run
# flags: see docs/rdna4/PIN.md
```

### Optional: stew 01 (adaptive MTP) — product for coding

```bash
git clone https://github.com/stew675/llama-cpp-rdna-boosts "$HOME/src/llama-cpp-rdna-boosts"
./scripts/apply-rocm.sh stew-01 --boosts-dir "$HOME/src/llama-cpp-rdna-boosts"
# if git apply fails: STOP. Do not --reject. See docs/rdna4/STEW.md
./scripts/apply-rocm.sh cmake --run
```

Credit in any binary you ship: **llama.cpp + stew675 01-adaptive-mtp + HIP 53211**.

### Serve (this lab)

Discrete cards only. mmap GGUF. Lab tensor port here is `:18080`.

```bash
# HIP overlay already in the environment from apply-rocm.sh env
./build-rocm/bin/llama-server \
  -m /path/to/Qwen3.8-27B-UD-Q8_K_XL.gguf \
  --device ROCm0,ROCm1 \
  --split-mode tensor --tensor-split 1,1 \
  -c 262144 --flash-attn on \
  --cache-type-k q8_0 --cache-type-v q8_0 \
  --spec-type draft-mtp-adaptive \
  --spec-draft-n-max 3 --spec-draft-n-min-adaptive 2 --spec-draft-p-min 0.0 \
  --parallel 1 --port 18080
```

Vanilla in-tree MTP (`--spec-type draft-mtp`) is the big jump vs spec none. 01 is adaptive depth on top of that.

## What we measured (honest)

Vehicle: llama `5ea1b124e`, HIP **53211**, dual R9700 tensor-split, **UD-Q8_K_XL**, `-c 262144`.

| stack | open (essay decode-512) | code (decode-512) | 10k prefill |
|---|---|---|---|
| spec none | ~27.3 | ~27.3 | — |
| vanilla mtp2 | 43.0 | 56.2 | **1249** |
| stew **01** adaptive | 42.9 | **61.8** | 1203 |
| 01+10 | 43.5 | 59.9 | 1201 |
| 01+10+02 | 43.6 | 59.7 | 1191 |

- Real jump = **stock llama MTP**, not stew.
- **01** helps **code**. Essays stay ~43.
- **10** / **02** = wash on this GGUF. Not product.
- 1337hero **53.1** open was a **Q8_0** path, not this XL file.

## ROCm PR (HIP `.so` for everyone)

**Ships in AMD HIP**, not in this llama fork. Current AMD tree: [TheRock](https://github.com/ROCm/TheRock) (`rocm-systems` submodule). Measured patch is CLR `rocblit.cpp` @ `97f5574` / rocm-7.2.4. gfx1201 skips kernel blit pin+`copyBufferRect` and uses `DmaBlitManager` line DMA.

- Patch in-tree: [`docs/rdna4/patches/rocblit-gfx1201-rect-dma.patch`](docs/rdna4/patches/rocblit-gfx1201-rect-dma.patch)
- Draft body (not filed): [`docs/rdna4/ROCM-PR.md`](docs/rdna4/ROCM-PR.md)
- Unique HSA/kernel *why* still **UNPROVEN**. Do not claim a kernel fix.

Post-merge: distro HIP; any HIP-built llama works. Pre-merge: overlay as above.

## Tracking remotes

```bash
git remote add upstream https://github.com/ggml-org/llama.cpp.git
git remote add stew-boosts https://github.com/stew675/llama-cpp-rdna-boosts.git
# rebase onto upstream; do not merge. When llama ships 01, drop our copy of that patch.
```

GitHub CI only checks whether stew 01 still **applies**. Real LOAD_OK + code-512 is this lab’s dual R9700 + 53211.

## Hardware this lab actually has

- 2× AMD Radeon AI PRO R9700 (RDNA4, **gfx1201**, 32 GB)
- Raphael iGPU **gfx1036** — skip for tensor-split
- ~30 GB host RAM — GGUF mmap; giant BF16 loads will not fit

## License

MIT, same as llama.cpp.
