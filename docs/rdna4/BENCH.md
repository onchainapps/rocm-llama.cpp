# Benchmarks (this lab)

One vehicle. Numbers are **tok/s**. They do **not** transfer across GGUF family, quant, or `-c`.

| Pin | Value |
|---|---|
| llama | `5ea1b124e` |
| HIP | `libamdhip64.so.7.2.53211` |
| GPU | 2× Radeon AI PRO R9700 (`gfx1201`), tensor-split `1,1` |
| Model | `Qwen3.8-27B-UD-Q8_K_XL` |
| Context | `-c 262144`, FA on, KV q8_0 |

## Metric

| Name | What |
|---|---|
| **open** | median decode-512 on three essay prompts (river stones / copper wire / pine resin) |
| **code** | median decode-512 on three coding prompts |
| **10k pp** | prefill tok/s at ~10k prompt tokens |

VOID=false, 512/512 on every decode leg. “Open” is **not** prefill.

## Decode / 10k prefill

| stack | open | code | 10k pp |
|---|---:|---:|---:|
| spec none | 27.13 | 27.33 | — |
| vanilla mtp2 (`draft-mtp` n-max 2) | 42.95 | 56.17 | 1249 |
| vanilla mtp3 | 40.50 | 61.56 | 1240 |
| stew **01** adaptive | 42.89 | **61.79** | 1203 |
| 01+10 | 43.53 | 59.85 | 1201 |
| 01+10+02 | 43.59 | 59.71 | 1191 |

Product on this GGUF: **vanilla llama + HIP 53211 + 01**. 10 and 02 are wash here.

## Prefill ladder (spec none)

| prompt | tok/s |
|---|---:|
| 8k | 1234 |
| 16k | 1359 |
| 40k | 1080 |
| 80k | 800 |

## Notes

- Jump from ~27 → ~56 **code** is in-tree MTP, not stew.
- **01** is adaptive draft depth. Helps **code**. Essays stay ~43.
- stew **10** is mmvq for Q8_0 / Q4_K / Q5_K / Q6_K. This file is **Q8_K_XL**.
- 1337hero 53.1 open was a **Q8_0** path, not this XL file.
- GitHub Actions does **not** GPU-bench. These numbers are this box only.
