#!/bin/bash

# Define models to compare
MODELS=(
    "qwen2.5:0.5b"
    "llama3.1:70b"
    "gemma3:27b"
    "gemma4:31b"
    "gpt-oss:20b"
    "gpt-oss:120b"
    "mixtral:8x22b"
    "deepseek-r1:70b"
    "ministral-3:14b"
    "jobautomation/OpenEuroLLM-Czech"
    "hollis9/czellama3"
)
PROMPT="Write a short story about a robot discovering nature."

echo "📋 Model Information:"
echo "--------------------------------------------------"
echo "1. qwen2.5:0.5b         - 0.5B params, ~400MB (Tiny, fast)"
echo "2. llama3.1:70b         - 70B params, ~40GB (Large, high reasoning)"
echo "3. gemma3:27b           - 27B params, ~17GB (Google's latest open model)"
echo "4. gemma4:31b           - 31B params, ~19GB (Google Gemma 4, improved)"
echo "5. gpt-oss:20b          - 20B params, ~10GB (OpenAI Open Source)"
echo "6. gpt-oss:120b         - 120B params, ~65GB (OpenAI Open Source Large)"
echo "7. mixtral:8x22b        - 141B params (39B active), ~80GB (MoE)"
echo "8. deepseek-r1:70b      - 70B params, ~43GB (Reasoning model)"
echo "9. ministral-3:14b      - 14B params, ~9GB (Mistral's edge model)"
echo "10. OpenEuroLLM-Czech   - ~8B params, ~8.1GB (Czech optimized)"
echo "11. czellama3           - ~8B params, ~4.7GB (Czech Llama3)"
echo "--------------------------------------------------"
echo ""

echo "🚀 Starting Performance Comparison"
echo "=================================================="

# Header for results
printf "%-20s | %-15s | %-15s | %-15s\n" "Model" "Tokens/Sec" "Eval Time (s)" "Load Time (s)"
echo "-------------------------------------------------------------------------"

for MODEL in "${MODELS[@]}"; do
    # Warmup / Ensure model is loaded (optional, but good for accurate timing if we want to exclude load time from first run, 
    # but here we capture load time separately so it's fine)
    
    # Run Inference
    # We use a temporary file to store the response to avoid pipe issues with large outputs
    RESPONSE_FILE=$(mktemp)
    
    curl -s http://localhost:11434/api/generate -d "{
      \"model\": \"$MODEL\",
      \"prompt\": \"$PROMPT\",
      \"stream\": false
    }" > "$RESPONSE_FILE"

    # Parse Results
    EVAL_COUNT=$(jq '.eval_count' "$RESPONSE_FILE")
    EVAL_DURATION_NS=$(jq '.eval_duration' "$RESPONSE_FILE")
    LOAD_DURATION_NS=$(jq '.load_duration' "$RESPONSE_FILE")
    
    # Check if we got valid numbers (in case of error)
    if [ "$EVAL_COUNT" == "null" ]; then
        echo "Error running $MODEL"
        cat "$RESPONSE_FILE"
        rm "$RESPONSE_FILE"
        continue
    fi

    # Calculate metrics
    EVAL_DURATION_SEC=$(echo "$EVAL_DURATION_NS / 1000000000" | bc -l)
    LOAD_DURATION_SEC=$(echo "$LOAD_DURATION_NS / 1000000000" | bc -l)
    
    # Avoid division by zero
    if (( $(echo "$EVAL_DURATION_SEC > 0" | bc -l) )); then
        TOKENS_PER_SEC=$(echo "$EVAL_COUNT / $EVAL_DURATION_SEC" | bc -l)
    else
        TOKENS_PER_SEC=0
    fi

    # Format output
    FMT_TPS=$(printf "%.2f" $TOKENS_PER_SEC)
    FMT_EVAL=$(printf "%.2f" $EVAL_DURATION_SEC)
    FMT_LOAD=$(printf "%.2f" $LOAD_DURATION_SEC)

    printf "%-20s | %-15s | %-15s | %-15s\n" "$MODEL" "$FMT_TPS" "$FMT_EVAL" "$FMT_LOAD"

    # Cleanup
    rm "$RESPONSE_FILE"
done

echo "=================================================="
echo "✅ Comparison Complete"
