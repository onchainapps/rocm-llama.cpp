# RDNA4 lab charter

Consumer **gfx1201** (Radeon AI PRO R9700) lab fork of [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp).

**Front door:** [README.md](README.md) · **agents:** [AGENTS.md](AGENTS.md)

Fork of [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp). HIP overlay is ours. stew **01** is optional. No `libamdhip64.so` in git.

| Doc | |
|---|---|
| [docs/rdna4/PIN.md](docs/rdna4/PIN.md) | version pins |
| [docs/rdna4/HIP.md](docs/rdna4/HIP.md) | hang is HIP; overlay |
| [docs/rdna4/HIP-BUILD.md](docs/rdna4/HIP-BUILD.md) | isolated CLR rebuild |
| [docs/rdna4/STEW.md](docs/rdna4/STEW.md) | 01 only in product |
| [docs/rdna4/BENCH.md](docs/rdna4/BENCH.md) | tok/s, this box only |
| [docs/rdna4/ROCM-PR.md](docs/rdna4/ROCM-PR.md) | rocblit PR draft — not filed |
