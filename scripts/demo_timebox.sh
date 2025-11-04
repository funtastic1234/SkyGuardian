#!/usr/bin/env bash
set -euo pipefail

MINUTES=${1:-15}
NS=skyguardian

echo "[+] Scaling NIM services up (demo window: ${MINUTES} min)"
kubectl -n "$NS" scale deploy nemotron-8b-reasoning --replicas=1 || true
kubectl -n "$NS" scale deploy embedding-nim --replicas=1 || true

echo "[i] Waiting for pods to become Ready..."
kubectl -n "$NS" wait --for=condition=available deploy/nemotron-8b-reasoning --timeout=15m || true
kubectl -n "$NS" wait --for=condition=available deploy/embedding-nim --timeout=10m || true

echo "[i] Demo running. Auto scale-down in ${MINUTES} minutes. Press Ctrl+C to cancel timer."
sleep $(( MINUTES * 60 )) || true

echo "[+] Auto scale-down now"
kubectl -n "$NS" scale deploy nemotron-8b-reasoning --replicas=0 || true
kubectl -n "$NS" scale deploy embedding-nim --replicas=0 || true
echo "[✓] Done"

