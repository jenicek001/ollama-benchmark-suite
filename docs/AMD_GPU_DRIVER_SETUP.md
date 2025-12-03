# AMD GPU Driver Setup & Testing Guide (Secure Boot Compatible)

This guide documents the process for setting up AMD GPU drivers for AI/Compute tasks (ROCm) on Ubuntu systems, specifically designed to work **with Secure Boot enabled**.

## 🎯 The Strategy
Instead of using the proprietary kernel driver (which gets blocked by Secure Boot), we use:
1.  **Upstream Kernel Driver**: The open-source `amdgpu` driver built into the Linux kernel (works with Secure Boot).
2.  **ROCm User-Space Libraries**: The proprietary compute libraries needed for AI/LLM workloads, installed without the kernel module.

---

## 1. Installation Steps

### Step 1: Remove Broken/Blocked Drivers
If you previously tried to install `amdgpu-install` with the default settings and got "Key rejected by service" errors, you must uninstall them first.

```bash
sudo amdgpu-install --uninstall -y
```

### Step 2: Install ROCm Libraries (No DKMS)
Install the ROCm compute libraries but explicitly tell the installer **not** to install the kernel driver (`--no-dkms`). This forces it to use the upstream kernel driver.

```bash
sudo amdgpu-install --usecase=rocm --no-dkms -y
```

### Step 3: Configure User Permissions
Add your user to the `render` and `video` groups to allow access to the GPU hardware.

```bash
sudo usermod -aG render,video $USER
```

### Step 4: Reboot
A reboot is required to unload any broken modules and load the correct upstream driver.

```bash
sudo reboot
```

---

## 2. Verification & Testing

After rebooting, perform these checks to ensure everything is working.

### A. Check Kernel Driver
Verify that the `amdgpu` module is loaded.

```bash
lsmod | grep amdgpu
```
*Expected Output:* You should see `amdgpu` listed with a size and usage count.

### B. Check ROCm Status
Use the System Management Interface to check if the GPU is detected by the ROCm stack.

```bash
rocm-smi
```
*Expected Output:* A table listing your GPU (e.g., "Device 0x1586"), temperature, and power usage.

### C. Verify Ollama GPU Detection
If you are using Ollama, check the logs to confirm it sees the GPU.

```bash
# Restart Ollama to force a re-check
sudo systemctl restart ollama

# Check logs for "inference compute"
sudo journalctl -u ollama -n 50 | grep "inference compute"
```
*Expected Output:*
`msg="inference compute" ... library=ROCm compute=gfx1100 ... type=iGPU`

### D. Run an Inference Test
Run a small model to verify actual computation works.

```bash
curl http://localhost:11434/api/generate -d '{
  "model": "qwen2.5:0.5b",
  "prompt": "System check: respond with OK.",
  "stream": false
}'
```

---

## 3. Troubleshooting

### Issue: "Key was rejected by service"
*   **Cause:** You installed the proprietary kernel driver (`amdgpu-dkms`) while Secure Boot is enabled.
*   **Fix:** Follow **Step 1** and **Step 2** above to switch to the `--no-dkms` installation method.

### Issue: `rocm-smi` returns "No devices found"
*   **Cause:** The user might not be in the `render` group, or the firmware is missing.
*   **Fix:**
    1.  Check groups: `groups` (look for `render`).
    2.  If missing, run Step 3 and log out/log in.
    3.  Check firmware: `ls /lib/firmware/amdgpu/`

### Issue: Ollama uses CPU instead of GPU
*   **Cause:** Ollama might not detect the ROCm library path or the GPU is unsupported by the default ROCm version.
*   **Fix:**
    1.  Ensure `HSA_OVERRIDE_GFX_VERSION` is set if using a consumer GPU (like Radeon 780M/890M).
    2.  Check `/etc/systemd/system/ollama.service.d/remote.conf` for:
        ```ini
        Environment="HSA_OVERRIDE_GFX_VERSION=11.0.0"
        ```
