# Benchmarking Results

This repository benchmarks the same models across two different AMD Ryzen AI systems to compare iGPU inference performance.

## Test Methodology

*   **Benchmark prompt**: `"Write a short story about a robot discovering nature."`
*   **Mode**: Single inference, `stream: false`
*   **Metric**: `eval_count / eval_duration` (tokens/second) from Ollama API response
*   **Runs**: Single run per model (no warm-up excluded unless noted)
*   **Context**: Default Ollama context unless noted — for models with very large defaults (e.g. gemma4:31b → 262K), `num_ctx=8192` was set explicitly to avoid GTT exhaustion
*   **Offloading**: All model layers offloaded to iGPU via ROCm unless noted

---

## System 1: AMD Ryzen AI Max 395 — Radeon 890M

### Hardware
| Component | Detail |
| :--- | :--- |
| **CPU** | AMD Ryzen AI Max 395 (Strix Point) |
| **GPU** | AMD Radeon 890M — gfx1151, 40 CUs @ 2900 MHz |
| **RAM** | 96 GB unified DDR5 |
| **Storage** | ~1TB NVMe (LVM) |

### Software
| Component | Detail |
| :--- | :--- |
| **OS** | Ubuntu 24.04 LTS |
| **Kernel** | 6.14.0-35-generic |
| **GPU Driver** | Upstream `amdgpu` kernel driver (no DKMS) |
| **Compute Stack** | ROCm user-space only; `HSA_OVERRIDE_GFX_VERSION=11.5.1` |
| **Inference Engine** | Ollama v0.20.3 |
| **GPU Memory (GTT)** | ~55 GiB available (default, no kernel GTT params set) |

### Performance Results

| Model | Size | Quant | t/s | GPU Layers | GPU Mem Used | num_ctx | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **qwen2.5:0.5b** | 0.5B | Q4_K_M | **225.00** | 100% | ~400 MiB | default | Extremely fast |
| **gpt-oss:20b** | 20B | Q4_K_M | **46.66** | 100% | ~10 GiB | default | Strong mid-size perf |
| **czellama3** | ~8B | Q4_K_M | **40.80** | 100% | ~5 GiB | default | Optimized Czech model |
| **gpt-oss:120b** | 120B | Q4_K_M | **33.98** | 100% | ~65 GiB | default | Remarkable for 120B — likely sparse/MoE |
| **ministral-3:14b** | 14B | Q4_K_M | **21.00** | 100% | ~9 GiB | default | |
| **OpenEuroLLM-Czech** | ~8B | Q4_K_M | **12.97** | 100% | ~8 GiB | default | |
| **gemma3:27b** | 27B | Q4_K_M | **11.07** | 100% | ~17 GiB | default | |
| **mixtral:8x22b** | 141B MoE | Q4_K_M | **9.06** | 100% | ~80 GiB | default | MoE, 39B active params |
| **llama3.1:70b** | 70B | Q4_K_M | **4.29** | 100% | ~40 GiB | default | |
| **deepseek-r1:70b** | 70B | Q4_K_M | **4.21** | 100% | ~43 GiB | default | Reasoning model |

---

## System 2: AMD Ryzen 7 8845HS — Radeon 780M

### Hardware
| Component | Detail |
| :--- | :--- |
| **CPU** | AMD Ryzen 7 8845HS (Hawk Point) |
| **GPU** | AMD Radeon 780M — gfx1103, 12 CUs @ 2700 MHz |
| **RAM** | 78 GiB unified DDR5 |
| **Storage** | NVMe |

### Software
| Component | Detail |
| :--- | :--- |
| **OS** | Ubuntu 24.04.4 LTS |
| **Kernel** | 6.14.0-33-generic |
| **GPU Driver** | Upstream `amdgpu` kernel driver (no DKMS) |
| **Compute Stack** | ROCm; `HSA_OVERRIDE_GFX_VERSION=11.0.0` |
| **Inference Engine** | Ollama v0.20.3 |
| **GPU Memory (GTT)** | ~55.2 GiB available (default, no kernel GTT params set) |
| **Flash Attention** | Disabled |

### Performance Results

| Model | Size | Quant | t/s | GPU Layers | GPU Mem Used | num_ctx | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **gemma4:26b** | 26B MoE (~4B active) | Q4_K_M | **19.09** | 31/31 (100%) | 16.6 GiB weights + 1.0 GiB KV = **18.6 GiB** | 8192 | Sparse MoE — fast despite 26B total |
| **gemma4:31b** | 31B dense | Q4_K_M | **3.28** | 61/61 (100%) | 18.4 GiB weights + 4.1 GiB KV = **23.7 GiB** | 8192 ⚠️ | Default 262K ctx hangs — see GPU_CONFIGURATION.md |

> ⚠️ `gemma4:31b` default context (262K tokens) exhausts GTT and causes Ollama to hang indefinitely. `num_ctx=8192` was set explicitly. For full context support, apply kernel GTT parameters — see [`docs/GPU_CONFIGURATION.md`](../docs/GPU_CONFIGURATION.md).

---

## Cross-System Observations

1.  **iGPU Capability**: Both systems can run models that typically require enterprise GPUs. The 890M (96 GB) extends this to 120B+ parameter models.
2.  **Sweet Spot**: 8B–20B range offers the best speed/quality balance (20–40 t/s on 890M, ~15–25 t/s expected on 780M).
3.  **MoE Advantage**: `gemma4:26b` (MoE, ~4B active) runs at **19 t/s on 780M** — nearly 6× faster than `gemma4:31b` (dense, 3.28 t/s) at similar file sizes. MoE is a major win for APU inference.
4.  **GTT Memory**: Default GTT (~55 GiB on both systems) limits usable GPU memory to ~50 GiB after OS overhead. Large models with large context windows can exhaust this. Apply kernel `ttm.pages_limit` params to unlock more.
5.  **gpt-oss:120b outlier**: Runs at 33 t/s on 890M despite 120B params, suggesting it is a sparse/MoE model behaving like a much smaller active-parameter model.

---

## Notes on gemma4 Model Variants

There is **no gemma4:27b**. Google released gemma4 in four sizes:

| Variant | Total Params | Active Params | Type | Context |
| :--- | :--- | :--- | :--- | :--- |
| gemma4:e2b | ~2B | 2B | Dense | 128K |
| gemma4:e4b | ~4B | 4B | Dense | 128K |
| **gemma4:26b** | 26B | **~4B** | Sparse MoE (128 experts, top-8) | 128K |
| **gemma4:31b** | 31B | 31B | Dense | **256K** |

The `26b` MoE has only ~4B params active per forward pass, making it dramatically faster than the dense `31b` despite similar file sizes on disk.
