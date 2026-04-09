# Ollama Benchmark Suite

A comprehensive benchmarking suite for running and analyzing Large Language Models (LLMs) using [Ollama](https://ollama.com/). This repository contains scripts to automate performance testing across various models and hardware configurations.

## 📂 Structure

*   **`scripts/`**: Bash scripts for running benchmarks and setting up the environment.
    *   `benchmark_compare.sh`: Main script to benchmark multiple models.
    *   `benchmark_single.sh`: Script to benchmark a single model.
    *   `setup_api_key.sh`: Helper to set up API keys (if needed).
    *   `test_ollama_remote.sh`: Test remote Ollama connectivity.
*   **`docs/`**: Documentation for setup and configuration.
    *   `AMD_GPU_DRIVER_SETUP.md`: Guide for setting up AMD ROCm drivers (specifically for Ryzen AI 300 series).
    *   `OLLAMA_SETUP.md`: General Ollama setup instructions.
*   **`results/`**: Markdown files containing benchmark results.

## 🚀 Getting Started

### Prerequisites
*   [Ollama](https://ollama.com/) installed and running.
*   `jq` and `curl` installed (`sudo apt install jq curl`).

### Running the Benchmark

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/jenicek001/ollama-benchmark-suite.git
    cd ollama-benchmark-suite
    ```

2.  **Make scripts executable:**
    ```bash
    chmod +x scripts/*.sh
    ```

3.  **Run the comparison benchmark:**
    ```bash
    ./scripts/benchmark_compare.sh
    ```

## 📊 Results

Check the `results/` directory for detailed performance reports on specific hardware.

*   [AMD Ryzen AI 395 (Strix Point) Results](results/BENCHMARK_RESULTS.md)

## 🛠️ Hardware Support

This suite is designed to be hardware-agnostic but includes specific setup guides for:
*   **AMD Ryzen AI Max 395** (Strix Point) with Radeon 890M iGPU (gfx1151)
*   **AMD Ryzen 7 8845HS** (Hawk Point) with Radeon 780M iGPU (gfx1103)

### GPU Auto-Configuration

Automatically detect and configure GPU acceleration:
```bash
sudo ./scripts/setup_ollama_gpu.sh
```

See `docs/GPU_CONFIGURATION.md` for manual setup and troubleshooting.

## 📄 License

MIT
