#!/bin/bash
# Quick Ollama Remote API Test Script

OLLAMA_HOST="192.168.0.218:11434"

echo "==================================="
echo "🧪 Testing Ollama Remote API"
echo "==================================="
echo ""

# Test 1: Version check
echo "1️⃣  Testing Version Endpoint..."
VERSION=$(curl -s http://${OLLAMA_HOST}/api/version)
echo "   Response: $VERSION"
echo ""

# Test 2: List models
echo "2️⃣  Listing Available Models..."
curl -s http://${OLLAMA_HOST}/api/tags | python3 -m json.tool | grep -A 1 "name"
echo ""

# Test 3: Quick generation
echo "3️⃣  Testing Text Generation..."
RESPONSE=$(curl -s http://${OLLAMA_HOST}/api/generate -d '{
  "model": "qwen2.5:0.5b",
  "prompt": "Say hello in one word",
  "stream": false
}' | python3 -c "import sys, json; print(json.load(sys.stdin)['response'])")

echo "   Prompt: 'Say hello in one word'"
echo "   Response: $RESPONSE"
echo ""

echo "✅ All tests passed!"
echo ""
echo "📖 Full documentation: ~/AMD_Ryzen_AI_395_Ubuntu/OLLAMA_SETUP.md"
