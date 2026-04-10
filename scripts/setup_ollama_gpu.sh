#!/bin/bash

echo "🔍 Detecting AMD GPU..."

# Detect GPU architecture
GFX_VERSION=$(rocminfo 2>/dev/null | grep -oP 'Name:\s+gfx\K[0-9]+' | head -1)

if [ -z "$GFX_VERSION" ]; then
    echo "❌ Error: Could not detect AMD GPU. Is ROCm installed?"
    exit 1
fi

echo "✅ Detected: gfx$GFX_VERSION"

# Determine GPU model and optimal settings
case "$GFX_VERSION" in
    1103)
        GPU_NAME="Radeon 780M (Ryzen 8845HS)"
        HSA_OVERRIDE=""
        COMMENT="# gfx1103 is supported directly by the current ROCm/Ollama stack"
        ;;
    1151)
        GPU_NAME="Radeon 8060S / gfx1151 (Ryzen AI Max 395 class APU)"
        HSA_OVERRIDE='Environment="HSA_OVERRIDE_GFX_VERSION=11.0.0"'
        COMMENT="# gfx1151 uses the stable gfx1100 compatibility override for Ollama + ROCm"
        ;;
    1150)
        GPU_NAME="Ryzen AI 300 series iGPU (gfx1150)"
        HSA_OVERRIDE='Environment="HSA_OVERRIDE_GFX_VERSION=11.0.0"'
        COMMENT="# gfx1150 uses the stable gfx1100 compatibility override for Ollama + ROCm"
        ;;
    *)
        GPU_NAME="AMD GPU gfx$GFX_VERSION"
        HSA_OVERRIDE=""
        COMMENT="# Unknown GPU - using auto-detection"
        echo "⚠️  Warning: Unknown GPU architecture. Proceeding without override."
        ;;
esac

if [ -n "$FORCE_HSA_OVERRIDE_GFX_VERSION" ]; then
    HSA_OVERRIDE="Environment=\"HSA_OVERRIDE_GFX_VERSION=$FORCE_HSA_OVERRIDE_GFX_VERSION\""
    COMMENT="# HSA override forced by FORCE_HSA_OVERRIDE_GFX_VERSION"
fi

echo "📋 GPU: $GPU_NAME"
echo ""

# Create override configuration
OVERRIDE_DIR="/etc/systemd/system/ollama.service.d"
OVERRIDE_FILE="$OVERRIDE_DIR/override.conf"

echo "📝 Creating Ollama service override configuration..."
echo ""
echo "Configuration to be applied:"
echo "-----------------------------------"

CONFIG="[Service]
Environment=\"OLLAMA_HOST=0.0.0.0:11434\"
$COMMENT"

if [ -n "$HSA_OVERRIDE" ]; then
    CONFIG="$CONFIG
$HSA_OVERRIDE"
fi

echo "$CONFIG"
echo "-----------------------------------"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "⚠️  This script needs sudo privileges to modify systemd configuration."
    echo ""
    echo "Please run: sudo $0"
    echo ""
    echo "Or manually create $OVERRIDE_FILE with the content above."
    exit 1
fi

# Create directory if it doesn't exist
mkdir -p "$OVERRIDE_DIR"

# Write configuration
echo "$CONFIG" > "$OVERRIDE_FILE"

echo "✅ Configuration written to $OVERRIDE_FILE"
echo ""

# Reload systemd and restart Ollama
echo "🔄 Reloading systemd daemon..."
systemctl daemon-reload

echo "🔄 Restarting Ollama service..."
systemctl restart ollama

sleep 2

# Check status
if systemctl is-active --quiet ollama; then
    echo "✅ Ollama service is running"
else
    echo "❌ Ollama service failed to start"
    echo ""
    echo "Check logs with: journalctl -u ollama -n 50"
    exit 1
fi

echo ""
echo "🧪 Testing GPU acceleration..."
sleep 2

# Test GPU offloading
LOGS=$(journalctl -u ollama -n 50 --no-pager)

if echo "$LOGS" | grep -q "offloaded.*layers to GPU"; then
    OFFLOAD_INFO=$(echo "$LOGS" | grep "offloaded.*layers to GPU" | tail -1)
    echo "✅ GPU Acceleration: ENABLED"
    echo "   $OFFLOAD_INFO"
else
    echo "⚠️  GPU offloading not detected in recent logs"
    echo "   Try running a model to verify: ollama run qwen2.5:0.5b"
fi

echo ""
echo "🎉 Setup complete for $GPU_NAME"
echo ""
echo "Verify with:"
echo "  journalctl -u ollama -f | grep -E 'GPU|offload|ROCm'"
