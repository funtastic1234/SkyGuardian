## SageMaker Deployment (Alternative to EKS)

### Overview
- Deploy NVIDIA NIM containers as SageMaker Real-Time Endpoints
- Endpoints:
  - Nemotron 8B Reasoning NIM
  - Retrieval Embedding NIM

### Prerequisites
- AWS CLI configured for `us-west-2`
- NGC API key available

### Steps
1) Create ECR pull permissions (optional if using NGC directly through SageMaker prebuilt URIs)
2) Create SageMaker models with container image and env vars:
   - `NGC_API_KEY`
3) Create endpoints (ml.g5.2xlarge recommended for 8B NIM; ml.m5.4xlarge for Embedding NIM)
4) Store endpoint names in environment variables consumed by AgentCore MCP

### Example (boto3 skeleton)
```python
import boto3

sm = boto3.client('sagemaker', region_name='us-west-2')

# 1) Create Model (Nemotron 8B)
# 2) Create EndpointConfig
# 3) Create Endpoint

# Repeat for Embedding NIM
```

### Networking
- Place endpoints in VPC; call from AgentCore MCP via VPC endpoints

### Cost Controls
- Delete endpoints immediately after demos
- Use single-instance endpoints and short demo windows

