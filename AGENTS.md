# AGENTS.md — set up this repo without wrecking the box

You are installing **onchainapps/rocm-llama.cpp**: a **lab fork** of ggml-org/llama.cpp for consumer **RDNA4 / gfx1201** (HIP tensor-split).

Read **this file and [README.md](README.md)** before any command that writes. Detail docs: `docs/rdna4/`.

## Goal

A HIP-built `llama-server` that:

1. Links **`libamdhip64.so.7.2.53211`** (LOAD_OK), not **`7.2.70204`** (hang).
2. Tensor-splits **discrete gfx1201 GPUs only**.
3. Optionally applies stew675 **`01-adaptive-mtp` only**.

## Forbidden (fail closed)

| Do not | Why |
|---|---|
| Write / overwrite `/opt/rocm` | Distro tree stays distro. Overlay = extra prefix + `LD_LIBRARY_PATH`. |
| Copy `libamdhip64.so*` into this git repo | AMD’s binary. We ship a **patch**, not a `.so`. |
| `stew675` `scripts/apply-all.sh` | Not our product. 10/02 washed on UD-Q8_K_XL. |
| `git apply --reject` / force hunks | If stew 01 does not apply, **stop**. |
| Tensor-split onto iGPU / Raphael / gfx1036 | Not a third R9700. |
| Llama memcpy “hang patches” as the product fix | Hang is HIP `rocblit` `hipMemcpy2DAsync` / `copyBufferRect`. |
| `gh pr create` / open ROCm or llama issues | Human owns GitHub prose. Draft only: `docs/rdna4/ROCM-PR.md`. |
| Assume Vulkan / CUDA / extra backends | This lab is **ROCm/HIP** unless the human names another. |
| Invent bench numbers | Cite README table or say unmeasured. |

## Procedure

### 1. Inventory (no writes)

```bash
./scripts/apply-rocm.sh check
rocm-smi --showproductname
readlink -f /opt/rocm /opt/rocm/lib/libamdhip64.so.7
```

Parse `check` verdict:

- `*53211*` → HIP looks LOAD_OK. Skip overlay build unless you still hang.
- `*70204*` → hang path. You **must** overlay 53211 before dual-GPU tensor load.
- `MISSING` → ROCm not installed. Install distro **ROCm 7.2.4** first (packages, not this repo).
- anything else → named A/B before trusting load.

### 2. HIP overlay if hang soname

Needs: distro ROCm 7.2.4 (`clang++` at `/opt/rocm/lib/llvm/bin/clang++`), ninja, python3 venv, network.

Current AMD development repo is [ROCm/TheRock](https://github.com/ROCm/TheRock). **This overlay recipe is pinned to rocm-7.2.4 CLR** (`ROCm/rocm-systems` @ `97f5574`). Do not build the hang overlay from TheRock `main` unless the human names that A/B.

```bash
SYS="${ROCM_SYSTEMS_DIR:-$HOME/src/rocm-systems-7.2.4}"
if [[ ! -d "$SYS/.git" ]]; then
  git clone https://github.com/ROCm/rocm-systems.git "$SYS"
fi
git -C "$SYS" checkout 97f5574fe2fdc7bef44fb01545347912ee9f1779

PREFIX="${HIP_OVERLAY_PREFIX:-$HOME/.cache/rocm-llama-hip-53211}"
./scripts/build-hip-overlay.sh --systems-dir "$SYS" --prefix "$PREFIX"
eval "$(./scripts/apply-rocm.sh env --prefix "$PREFIX")"
```

`build-hip-overlay.sh` **exits non-zero** if `--prefix` is `/opt/rocm` or `/usr`.

Verify:

```bash
readlink -f "$PREFIX/lib/libamdhip64.so.7"
# expect .../libamdhip64.so.7.2.53211
```

Keep this `eval` in the **same shell** as cmake/serve. Do not put overlay `LD_LIBRARY_PATH` in the user’s `~/.bashrc` unless they asked.

### 3. Configure + build llama (HIP)

```bash
./scripts/apply-rocm.sh cmake --run
```

Expect `GPU_TARGETS=gfx1201`. Binary: `./build-rocm/bin/llama-server`.

### 4. Optional stew 01

Only if the human wants adaptive MTP (coding). Clone **his** quilt; do not vendor it.

```bash
./scripts/apply-rocm.sh stew-01 --boosts-dir /path/to/llama-cpp-rdna-boosts
./scripts/apply-rocm.sh cmake --run
```

If `--check` fails: report the SHA mismatch and stop.

### 5. Serve

Devices: names from `./build-rocm/bin/llama-server --list-devices` (or ROCm0,ROCm1 on a dual R9700). **Omit iGPU.**

Flags: README “Serve” section. Port: ask the human; this lab uses **18080** for HIP tensor and does not steal other services.

`--mmap` / GGUF if host RAM is tight (~30 GB class).

## Verify before you declare success

1. `./scripts/apply-rocm.sh check` → LOAD_OK soname.
2. `ldd ./build-rocm/bin/libggml-hip.so` (or `build-rocm/bin/libggml-hip.so` / `build-rocm/src/...`) realpath contains **53211** when overlay is required.
3. Server reaches ready on the chosen port without a 300s load hang.
4. If stew 01 applied, server argv includes `--spec-type draft-mtp-adaptive`.

## What “open” vs “code” means (if you bench)

- **open** = essay decode-512 median (prose).
- **code** = coding decode-512 median.
- Do not call prefill “open”. Do not cite 1337hero 53.1 as this XL GGUF.

## Remotes

```text
origin      onchainapps/rocm-llama.cpp
upstream    ggml-org/llama.cpp          (rebase, don’t merge)
stew-boosts stew675/llama-cpp-rdna-boosts
```

## If you get stuck

- Hang at load + 70204 → overlay missing, not a llama bug.
- Hang + 53211 → new class; do not “fix” with llama B+C; collect logs and ask the human.
- stew 01 fuzz → stop; his pin is ROCm 7.14 / different SHA.
- Want AMD to ship the HIP fix → show `docs/rdna4/ROCM-PR.md`; do not file it.
