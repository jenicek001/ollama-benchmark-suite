#!/bin/bash

MODEL="ministral-3:14b"
PROMPT="Write a short story about a robot discovering nature."

echo "🚀 Benchmarking $MODEL"
echo "--------------------------------------------------"

# Run Inference
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

if [ "$EVAL_COUNT" == "null" ]; then
    echo "Error running $MODEL"
    cat "$RESPONSE_FILE"
else
    EVAL_DURATION_SEC=$(echo "$EVAL_DURATION_NS / 1000000000" | bc -l)
    LOAD_DURATION_SEC=$(echo "$LOAD_DURATION_NS / 1000000000" | bc -l)
    
    if (( $(echo "$EVAL_DURATION_SEC > 0" | bc -l) )); then
        TOKENS_PER_SEC=$(echo "$EVAL_COUNT / $EVAL_DURATION_SEC" | bc -l)
    else
        TOKENS_PER_SEC=0
    fi

    printf "%-20s | %-15s | %-15s | %-15s\n" "Model" "Tokens/Sec" "Eval Time (s)" "Load Time (s)"
    echo "-------------------------------------------------------------------------"
    printf "%-20s | %-15s | %-15s | %-15s\n" "$MODEL" "$(printf "%.2f" $TOKENS_PER_SEC)" "$(printf "%.2f" $EVAL_DURATION_SEC)" "$(printf "%.2f" $LOAD_DURATION_SEC)"
fi

rm "$RESPONSE_FILE"
