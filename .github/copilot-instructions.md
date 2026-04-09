# Copilot Instructions - Ollama Benchmark Suite

## Repository Overview

This is a benchmarking suite for testing Large Language Model (LLM) performance using Ollama across various hardware configurations. The primary focus is AMD Ryzen AI 300 series with Radeon 890M iGPU, but the scripts are hardware-agnostic.

## Running Scripts

### Prerequisites
- Ollama must be running (locally or remotely)
- Required tools: `jq`, `curl`, `bc`

### Main Benchmarking Scripts

**Compare multiple models:**
```bash
./scripts/benchmark_compare.sh
```

**Benchmark a single model:**
```bash
# Edit MODEL variable in the script first
./scripts/benchmark_single.sh
```

**Test benchmark with model pull:**
```bash
./scripts/benchmark_test.sh
```

**Test remote Ollama connectivity:**
```bash
./scripts/test_ollama_remote.sh
```

### GPU Configuration

**Auto-detect GPU and configure Ollama:**
```bash
sudo ./scripts/setup_ollama_gpu.sh
```

Detects gfx1103 (Radeon 780M) or gfx1151 (Radeon 890M) and applies optimal settings.

### Security Setup (Optional)

**Setup API key protection for remote Ollama:**
```bash
sudo ./scripts/setup_api_key.sh
```

## Architecture

### Benchmarking Flow

1. **Script sends HTTP request** to Ollama API (`/api/generate` endpoint)
2. **Ollama processes** the prompt with specified model
3. **Response includes metrics:**
   - `eval_count`: Number of tokens generated
   - `eval_duration`: Time spent generating tokens (nanoseconds)
   - `load_duration`: Time to load model into memory (nanoseconds)
4. **Script calculates** tokens/second from response data
5. **Results displayed** in formatted table

### API Communication

All scripts communicate with Ollama via HTTP REST API:
- **Default endpoint:** `http://localhost:11434`
- **Format:** JSON requests with `{"model": "...", "prompt": "...", "stream": false}`
- **Response parsing:** Uses `jq` to extract metrics from JSON

### Script Patterns

**Temporary files:** Scripts use `mktemp` for response storage to avoid pipe issues with large outputs

**Duration conversion:** All timing metrics arrive in nanoseconds and are converted to seconds using `bc -l` for floating-point math

**Error handling:** Check for `"null"` in parsed JSON to detect API failures

## Key Conventions

### Model Naming
Models follow Ollama's naming convention: `model-name:size` (e.g., `qwen2.5:0.5b`, `llama3.1:70b`)

### Metric Calculations
```bash
# Nanoseconds to seconds
DURATION_SEC=$(echo "$DURATION_NS / 1000000000" | bc -l)

# Tokens per second
TOKENS_PER_SEC=$(echo "$EVAL_COUNT / $EVAL_DURATION_SEC" | bc -l)

# Formatted output
printf "%.2f" $TOKENS_PER_SEC
```

### Testing Prompt
Default benchmark prompt: `"Write a short story about a robot discovering nature."`
This generates consistent token counts across models for comparison.

## Hardware Context

### Multi-System Support
This repository supports benchmarking on **two different AMD systems**:

#### System 1: AMD Ryzen AI Max 395 (Strix Point)
- **GPU:** Radeon 890M (gfx1151)
- **Memory:** 96GB unified
- **ROCm:** Requires `HSA_OVERRIDE_GFX_VERSION=11.5.1` on Linux (experimental)
- **Performance:** ~225 t/s (0.5B), 20-40 t/s (8B-20B), ~4 t/s (70B)

#### System 2: AMD Ryzen 7 8845HS (Hawk Point)
- **GPU:** Radeon 780M (gfx1103)
- **Memory:** 16-32GB unified (typical)
- **ROCm:** Officially supported, no override needed
- **Performance:** ~150-200 t/s (0.5B), 15-30 t/s (8B-20B), 2-3 t/s (70B)

### GPU Configuration

**Auto-detect and configure:**
```bash
sudo ./scripts/setup_ollama_gpu.sh
```

**Manual configuration files:**
- gfx1103: No HSA_OVERRIDE needed (officially supported)
- gfx1151: Use `HSA_OVERRIDE_GFX_VERSION=11.5.1`

See `docs/GPU_CONFIGURATION.md` for detailed setup and troubleshooting.

### ROCm Support Status (2026)
- **gfx1103 (Radeon 780M):** Fully supported by ROCm
- **gfx1151 (Radeon 890M):** Not in official support matrix; requires workaround on Linux
- **Windows:** AMD Adrenalin 26.2.2+ includes AI Bundle with native Ollama support for both GPUs
- **NPU:** Not used by Ollama - inference runs on iGPU via ROCm/HIP

## Remote Ollama Setup

For remote benchmarking, Ollama service requires:
```ini
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="HSA_OVERRIDE_GFX_VERSION=11.0.0"
```

Security options documented in `docs/OLLAMA_SETUP.md`:
- UFW firewall rules
- Nginx/Caddy reverse proxy with API key validation
- Basic auth
- SSH tunneling

## Documentation Structure

- `docs/GPU_CONFIGURATION.md` - Multi-GPU setup guide for gfx1103 and gfx1151
- `docs/AMD_GPU_DRIVER_SETUP.md` - ROCm driver installation for Ryzen AI 300
- `docs/OLLAMA_SETUP.md` - Complete Ollama remote server setup with security options
- `docs/API_KEY_QUICK_START.md` - Quick reference for API key setup
- `results/BENCHMARK_RESULTS.md` - Performance data on specific hardware
