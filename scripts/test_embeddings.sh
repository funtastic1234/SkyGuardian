#!/usr/bin/env bash
set -euo pipefail

URL=${1:-http://localhost:8001/v1/embeddings}

curl -s -X POST "$URL" \
  -H "Content-Type: application/json" \
  -d '{
    "input": [
      "Search and rescue protocol for wilderness areas",
      "Thermal imaging detection techniques"
    ],
    "model": "nvidia/nv-embedqa-e5-v5"
  }' | jq .

