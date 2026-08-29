# stew675 RDNA boosts — what we take, what we don’t

**Source of truth for the patches:** [stew675/llama-cpp-rdna-boosts](https://github.com/stew675/llama-cpp-rdna-boosts) (MIT). All kernel/MTP work in those files is **his**. This fork only records **which** blocks we applied on **this** hardware and what we measured.

His `scripts/apply-all.sh` is **not** our default. His validation pin is **ROCm 7.14** / llama `fe235f434`. This lab is **ROCm 7.2.4** + HIP **53211** + llama `5ea1b124e` for the measured vehicle.

## Product (coding agents, UD-Q8_K_XL)

| Block | In our default? | Why |
|---|---|---|
| **01** adaptive MTP | **Yes** | Real code: `--spec-type draft-mtp-adaptive`. Helped **code** decode (~56 → ~62 tok/s). Essays stayed ~43. |
| 02 chunked GDN | No | Prefill-oriented. Wash / slight pp drop on this Q8. |
| 10 k-quant boosts | No | Decode claim is **Q8_0 / Q4_K / Q5_K / Q6_K** mmvq. Our file is **Q8_K_XL**. Wash. |
| 03–09, 11 | No | Not A/B’d here. Don’t vendor hope. |

Vanilla **in-tree MTP** (`--spec-type draft-mtp`) was the big jump (code ~27 → ~56). That is **llama.cpp**, not stew. 01 sits on top of that.

## Apply (opt-in)

```bash
# clone his quilt somewhere, then:
./scripts/apply-rocm.sh stew-01 --boosts-dir /path/to/llama-cpp-rdna-boosts
```

If `git apply` fuzzes or fails, **stop**. Do not `--reject` your way to a silent tree. Rebase or wait — his quilt tracks a different SHA than `master`.

## Credit in binaries / docs

When we ship a binary with 01 applied, say so: **llama.cpp + stew675 01-adaptive-mtp + HIP 53211**. Never “our kernels” for his diffs.
