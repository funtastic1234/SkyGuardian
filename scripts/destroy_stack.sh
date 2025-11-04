#!/usr/bin/env bash
set -euo pipefail

REGION=${REGION:-us-west-2}
STACK_EKS=${STACK_EKS:-skyg-eks}
STACK_OS=${STACK_OS:-skyg-opensearch}
STACK_IRSA=${STACK_IRSA:-skyg-irsa}

echo "[+] Scale down k8s services (if cluster active)"
kubectl -n skyguardian scale deploy nemotron-8b-reasoning --replicas=0 || true
kubectl -n skyguardian scale deploy embedding-nim --replicas=0 || true

echo "[+] Delete IRSA stack"
aws cloudformation delete-stack --region "$REGION" --stack-name "$STACK_IRSA" || true

echo "[+] Delete EKS stack (if created via CFN)"
aws cloudformation delete-stack --region "$REGION" --stack-name "$STACK_EKS" || true

echo "[+] Delete OpenSearch stack"
aws cloudformation delete-stack --region "$REGION" --stack-name "$STACK_OS" || true

echo "[✓] Cleanup initiated"

