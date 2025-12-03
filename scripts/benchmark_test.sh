#!/bin/bash

MODEL="qwen2.5:0.5b"
PROMPT="Write a short story about a robot discovering nature."

echo "🚀 Starting Benchmark for $MODEL..."
echo "-----------------------------------"

# 1. Pull the model
echo "📦 Pulling model (this may take a while for 70B)..."
ollama pull $MODEL

# 2. Run Inference
echo "-----------------------------------"
echo "🔥 Running inference..."
echo "Prompt: $PROMPT"
echo "-----------------------------------"

# Capture the start time
START=$(date +%s.%N)

# Run curl and capture output
RESPONSE=$(curl -s http://localhost:11434/api/generate -d "{
  \"model\": \"$MODEL\",
  \"prompt\": \"$PROMPT\",
  \"stream\": false
}")

# Capture end time
END=$(date +%s.%N)

# 3. Parse Results
echo "-----------------------------------"
echo "📊 Results:"

# Extract metrics using jq
EVAL_COUNT=$(echo $RESPONSE | jq '.eval_count')
EVAL_DURATION_NS=$(echo $RESPONSE | jq '.eval_duration')
LOAD_DURATION_NS=$(echo $RESPONSE | jq '.load_duration')
TOTAL_DURATION_NS=$(echo $RESPONSE | jq '.total_duration')

# Convert to seconds and calculate rates
# eval_duration is in nanoseconds
EVAL_DURATION_SEC=$(echo "$EVAL_DURATION_NS / 1000000000" | bc -l)
TOKENS_PER_SEC=$(echo "$EVAL_COUNT / $EVAL_DURATION_SEC" | bc -l)

echo "Token Count:      $EVAL_COUNT tokens"
echo "Eval Duration:    $(printf "%.2f" $EVAL_DURATION_SEC) seconds"
echo "Speed:            $(printf "%.2f" $TOKENS_PER_SEC) tokens/sec"
echo "Model Load Time:  $(echo "$LOAD_DURATION_NS / 1000000000" | bc -l | xargs printf "%.2f") seconds"

echo "-----------------------------------"
echo "✅ Benchmark Complete"
