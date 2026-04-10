# GPU Detection and Configuration

## Supported Hardware

This repository supports benchmarking on multiple AMD Ryzen AI systems:

### System 1: AMD Ryzen AI Max 395 (Strix Point)
- **GPU:** Radeon 8060S / gfx1151
- **VRAM:** 96 GB unified memory
- **ROCm Support:** Use `HSA_OVERRIDE_GFX_VERSION=11.0.0` with the current Ollama + ROCm stack in this repo
- **Status:** Works via gfx1100 compatibility override

### System 2: AMD Ryzen 7 8845HS (Hawk Point)
- **GPU:** Radeon 780M (gfx1103)
- **VRAM:** Variable (typically 16-32 GB unified memory)
- **ROCm Support:** Officially supported by ROCm
- **Status:** Native ROCm support, no override needed

## Automatic GPU Setup

Use the auto-detection script to configure Ollama for your specific GPU:

```bash
sudo ./scripts/setup_ollama_gpu.sh
```

This script will:
1. ✅ Detect your GPU architecture (gfx1103 or gfx1151)
2. ✅ Apply the correct machine-specific `HSA_OVERRIDE_GFX_VERSION` only when needed
3. ✅ Configure Ollama service for remote access
4. ✅ Restart Ollama and verify GPU acceleration

Because this repo is shared across multiple machines, do not copy one machine's `/etc/systemd/system/ollama.service.d/*.conf` to another. Re-run `sudo ./scripts/setup_ollama_gpu.sh` on each host so the override matches the local GPU.

## Manual Configuration

### For Radeon 780M (gfx1103) - Ryzen 8845HS

```bash
# Edit Ollama service override
sudo nano /etc/systemd/system/ollama.service.d/override.conf

# Add:
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
# gfx1103 is supported directly - no override needed

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

### For Radeon 8060S / gfx1151 - Ryzen AI Max 395 class systems

```bash
# Edit Ollama service override
sudo nano /etc/systemd/system/ollama.service.d/override.conf

# Add:
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="HSA_OVERRIDE_GFX_VERSION=11.0.0"

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

## Verify GPU Acceleration

Check that models are offloading to GPU:

```bash
# Watch logs for GPU offloading
journalctl -u ollama -f | grep -E "offload|ROCm"

# Expected output:
# load_tensors: offloaded 25/25 layers to GPU
# load_tensors: ROCm0 model buffer size = 373.73 MiB
```

## Performance Expectations

### Radeon 780M (gfx1103)
- **Tiny models (0.5B):** ~150-200 tokens/s
- **Small models (8B-20B):** 15-30 tokens/s
- **Large models (70B):** 2-3 tokens/s

### Radeon 8060S / gfx1151
- **Tiny models (0.5B):** ~225 tokens/s
- **Small models (8B-20B):** 20-40 tokens/s
- **Large models (70B):** ~4 tokens/s

## GTT Memory Configuration (Critical for Large Models)

### Background: VRAM vs GTT

AMD Ryzen APUs use system RAM as GPU memory via two pools:

| Pool | Description | Set By |
|------|-------------|--------|
| **VRAM** | Statically reserved at boot | BIOS/UEFI (`UMA Frame Buffer Size`) |
| **GTT** | Dynamic GPU access to system RAM | Kernel parameters |

**BIOS limitation:** Most firmware caps VRAM allocation at **32 GB**. For systems with 96+ GB RAM, this leaves most memory unreachable by the GPU — causing large model loads to hang or fail silently.

**Symptom:** Ollama appears to hang indefinitely when loading a model (e.g. `gemma4:31b`), with Ollama logs showing:
```
failure during GPU discovery: failed to finish discovery before timeout
model failed to load: context canceled
```

This is NOT a model or driver bug — it's the default GTT limit being too small for the model + context window.

### Checking Your Current GTT Size

```bash
# After boot, check what GTT was allocated
sudo dmesg | grep "amdgpu.*memory"
# Example output:
# [drm] amdgpu: 512M of VRAM memory ready
# [drm] amdgpu: 48000M of GTT memory ready.   <-- this is your usable GPU memory
```

Also visible via `radeontop` or `amdgpu_top` in the "Memory usage" section.

### Solution: Override GTT via Kernel Parameters

There are two strategies depending on your BIOS VRAM setting:

#### Strategy A — Low BIOS VRAM + High GTT (Recommended)

Set BIOS `UMA Frame Buffer Size` to **512 MB**, then allocate GTT via kernel:

```bash
# Create a grub drop-in config
sudo mkdir -p /etc/default/grub.d
sudo nano /etc/default/grub.d/amd_ttm.cfg
```

Add this single line:
```
GRUB_CMDLINE_LINUX="${GRUB_CMDLINE_LINUX:+$GRUB_CMDLINE_LINUX }transparent_hugepage=always numa_balancing=disable ttm.pages_limit=32768000 amdttm.pages_limit=32768000"
```

Apply and reboot:
```bash
sudo update-grub && sudo reboot
```

Verify after reboot:
```bash
sudo dmesg | grep "amdgpu.*memory"
# Expected: [drm] amdgpu: 128000M of GTT memory ready.
```

#### Strategy B — High BIOS VRAM (32 GB) + Moderate GTT

Keep BIOS VRAM at 32 GB. Set GTT to cover the remaining RAM (e.g. ~55 GB on a 96 GB system):

```bash
sudo nano /etc/default/grub.d/amd_ttm.cfg
```
```
GRUB_CMDLINE_LINUX="${GRUB_CMDLINE_LINUX:+$GRUB_CMDLINE_LINUX }amdgpu.gttsize=57344 ttm.pages_limit=14745600 amdttm.pages_limit=14745600"
```

### Kernel Version Compatibility

| Kernel version | Effective parameter |
|----------------|---------------------|
| < 6.12 | `amdgpu.gttsize=<MiB>` |
| ≥ 6.12 (ROCm 7.x) | `ttm.pages_limit=<pages>` + `amdttm.pages_limit=<pages>` |
| 6.14+ (this repo) | Use **both** for compatibility |

**Pages → MiB conversion:** `pages × 4096 / 1048576 = MiB`

Common GTT values (in pages):
```
131072      =   512 MiB  (disable GTT)
2097152     =     8 GiB
14745600    =    ~56 GiB
27648000    =   ~105 GiB (safe for desktop use, leaves room for OS)
32768000    =   ~125 GiB (headless/server — maximum usable on 128+ GB systems)
```

### Impact on Model Loading

| BIOS VRAM | GTT | Max model size | Notes |
|-----------|-----|----------------|-------|
| 32 GB (default) | ~48 GB (default) | ~60 GB | gemma4:31b with large context may fail |
| 512 MB | 125 GB (tuned) | ~115 GB | Loads gemma4:31b, gpt-oss:120b reliably |
| 64–96 GB | 512 MB (low) | 64–96 GB | Slightly faster TPS, no large-model GTT fallback |

> **Note:** Strategy A (GTT mode) is slightly slower (~5% fewer TPS) than pinned BIOS VRAM but is far more flexible and supports models larger than the 32 GB BIOS cap.

---

## Troubleshooting

### GPU Not Detected

```bash
# Check ROCm can see GPU
rocminfo | grep -E "gfx|Name:"

# Should show:
# Name: gfx1103 (for 780M)
# Name: gfx1151 (for 8060S)
```

### No GPU Offloading

```bash
# Check Ollama service environment
systemctl show ollama | grep Environment

# Restart with debug logging
sudo systemctl edit ollama
# Add: Environment="OLLAMA_DEBUG=1"
sudo systemctl daemon-reload
sudo systemctl restart ollama
journalctl -u ollama -f
```

### Models Running on CPU Only

- Verify ROCm installation: `rocminfo`
- Check `HSA_OVERRIDE_GFX_VERSION` matches the guidance for your local GPU in this repo
- Try Ollama-Vulkan backend as alternative: `OLLAMA_USE_VULKAN=1`

### Model Load Hangs Indefinitely (Large Models)

If Ollama hangs silently when loading a large model (no progress, no error for minutes), the GTT memory window is too small. See **[GTT Memory Configuration](#gtt-memory-configuration-critical-for-large-models)** above.

Quick diagnosis:
```bash
# Check if GTT is the bottleneck
sudo dmesg | grep "amdgpu.*memory"
# If GTT < model size → increase via kernel parameters
```

## Additional Resources

- [AMD ROCm Documentation](https://rocm.docs.amd.com/)
- [Ollama GPU Support](https://docs.ollama.com/gpu)
- [gfx1151 Workaround Guide](https://dev.webonomic.nl/how-to-use-amd-rocm-on-krackan-point-ryzen-ai-300-series)
