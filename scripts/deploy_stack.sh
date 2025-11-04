#!/usr/bin/env bash
set -euo pipefail

REGION=${REGION:-us-west-2}
STACK_EKS=${STACK_EKS:-skyg-eks}
STACK_OS=${STACK_OS:-skyg-opensearch}
STACK_IRSA=${STACK_IRSA:-skyg-irsa}

echo "[+] Deploying OpenSearch Serverless"
aws cloudformation deploy \
  --region "$REGION" \
  --template-file cloudformation/opensearch.yaml \
  --stack-name "$STACK_OS" \
  --capabilities CAPABILITY_NAMED_IAM

echo "[+] Deploying EKS Cluster (provide VPC/Subnets via parameters)"
echo "    Example: aws cloudformation deploy --parameter-overrides VpcId=vpc-xxxx PrivateSubnets=subnet-a,subnet-b"

echo "[i] Skipping EKS deploy auto-run to avoid accidental charges. Use the command above with your VPC/Subnets."

echo "[+] To deploy IRSA after EKS is ready, run:"
echo "    aws cloudformation deploy --region $REGION --template-file cloudformation/iam-irsa.yaml --stack-name $STACK_IRSA --capabilities CAPABILITY_NAMED_IAM --parameter-overrides ClusterOIDCProviderArn=arn:aws:iam::<acct>:oidc-provider/oidc.eks..."

echo "[+] After cluster is ready: kubectl apply -f k8s/nim.yaml and set NGC secret"

