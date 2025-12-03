# Benchmarking Results: AMD Ryzen AI 395

## Hardware Configuration
*   **System**: AMD Ryzen AI 395 (Strix Point)
*   **GPU**: AMD Radeon 890M (Integrated, gfx1151)
*   **RAM**: 96 GB
*   **Storage**: ~1TB NVMe (LVM Expanded)

## Software Environment
*   **OS**: Ubuntu 24.04 LTS
*   **Kernel**: 6.14.0-35-generic
*   **Drivers**: Upstream `amdgpu` kernel driver
*   **Compute Stack**: ROCm (User-space libraries only, No DKMS)
*   **Inference Engine**: Ollama v0.13.1

## Performance Summary

| Model | Size | Speed (Tokens/s) | Notes |
| :--- | :--- | :--- | :--- |
| **qwen2.5:0.5b** | 0.5B | **225.00** | Extremely fast, suitable for real-time classification/routing. |
| **gpt-oss:20b** | 20B | **46.66** | Strong performance for a mid-sized model. |
| **czellama3** | ~8B | **40.80** | Optimized Czech model. |
| **gpt-oss:120b** | 120B | **33.98** | **Remarkable speed** for a 120B model on iGPU. Likely highly quantized or sparse. |
| **ministral-3:14b** | 14B | **21.00** | Solid performance for Mistral's edge model. |
| **OpenEuroLLM-Czech** | ~8B | **12.97** | Slower than czellama3, possibly due to architecture or quantization. |
| **gemma3:27b** | 27B | **11.07** | Heavy for its size class on this architecture. |
| **mixtral:8x22b** | 141B | **9.06** | Mixture of Experts (MoE). Good throughput for massive parameter count. |
| **llama3.1:70b** | 70B | **4.29** | Heavy dense model. Usable for batch tasks, slow for chat. |
| **deepseek-r1:70b** | 70B | **4.21** | Similar performance to Llama 3.1 70B. |

## Observations
1.  **iGPU Capability**: The Radeon 890M with 96GB RAM is capable of running massive models (up to 141B params) that would typically require enterprise GPUs.
2.  **Sweet Spot**: Models in the 8B-20B range (like `gpt-oss:20b`, `czellama3`, `ministral-3`) offer a great balance of speed (20-40 t/s) and intelligence.
3.  **Large Model Viability**: While 70B+ dense models run (~4 t/s), they are on the edge of interactive usability. The 120B "gpt-oss" model is an outlier, performing unexpectedly well (33 t/s), suggesting it might be a sparse model or highly optimized.
