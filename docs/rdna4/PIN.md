# Version pins (this lab)

One line of truth. Bump here when a named A/B lands — not from vibes.

| Key | Pin | Notes |
|---|---|---|
| llama.cpp (GitHub default branch) | `master` of this fork = ggml-org `master` at fork time | Keep up with upstream. |
| llama.cpp (lab-measured HIP vehicle) | `5ea1b124e` | LOAD_OK with HIP **53211** on dual R9700. Vanilla discriminator. |
| GPU target | `gfx1201` | RDNA4 R9700. |
| ROCm development (current) | [ROCm/TheRock](https://github.com/ROCm/TheRock) | Superbuild. CLR is `rocm-systems` submodule. Not the 7.2.4 overlay pin. |
| ROCm distro package | **7.2.4** (`/opt/rocm` → distro) | Do **not** overwrite `/opt/rocm`. |
| HIP soname that LOAD_OKs tensor-split | `libamdhip64.so.7.2.53211` | gfx1201 rect-DMA rocblit (userspace). |
| HIP soname that **hangs** load | `libamdhip64.so.7.2.70204` | Stock distro HIP. `hipMemcpy2DAsync` / `copyBufferRect` hang class. |
| stew quilt | [stew675/llama-cpp-rdna-boosts](https://github.com/stew675/llama-cpp-rdna-boosts) | His README current checkpoint is `baseline/fe235f434` on **ROCm 7.14**. That is **not** this box. |
| stew blocks in **our** product | **01 only** (`01-adaptive-mtp`) | Coding decode. See `STEW.md`. |
| Model used for the coding bar | `Qwen3.8-27B-UD-Q8_K_XL` | Stay on XL. stew **10** is Q8_0/Q4/Q5/Q6 mmvq, not this file. |

## CMake (HIP, this lab)

```text
-DGGML_HIP=ON
-DGPU_TARGETS=gfx1201
-DCMAKE_HIP_COMPILER=/opt/rocm/lib/llvm/bin/clang++
-DGGML_HIP_GRAPHS=ON
-DGGML_HIP_MMQ_MFMA=ON
-DGGML_HIP_NO_VMM=ON
-DGGML_CUDA_FA=ON
-DGGML_HIP_RCCL=OFF
-DLLAMA_BUILD_SERVER=ON
```

`scripts/apply-rocm.sh cmake` prints the same flags.
