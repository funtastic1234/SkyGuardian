#!/usr/bin/env bash
set -euo pipefail

URL=${1:-http://localhost:8000/v1/chat/completions}

curl -s -X POST "$URL" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta/llama-3.1-nemotron-nano-8b-instruct",
    "messages": [{"role": "user", "content": "Plan a grid search for a 10km^2 forest."}],
    "thinking_budget": 4096,
    "temperature": 0.7
  }' | jq .

