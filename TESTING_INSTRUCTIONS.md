# SkyGuardian - Testing Instructions

## Prerequisites

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd hackathon-devpost
   ```

2. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```
   
   Required packages include:
   - `boto3` - AWS SDK for Rekognition, S3, OpenSearch, CloudWatch
   - `kubernetes` - EKS cluster management
   - `requests` - HTTP client for NIM API calls
   - `numpy`, `opencv-python` - Image processing
   - `opensearch-py` - OpenSearch Serverless client

3. **Set up AWS credentials:**
   ```bash
   aws configure
   ```
   - Use provided AWS promotional credits ($100)
   - Region: `us-west-2`
   - Ensure IAM permissions for: EKS, S3, Rekognition, OpenSearch, CloudWatch

4. **Set up NVIDIA NGC API key:**
   ```bash
   export NGC_API_KEY=your_nvidia_api_key
   ```

5. **Install kubectl and eksctl:**
   ```bash
   # macOS
   brew install kubectl eksctl
   
   # Linux
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   chmod +x kubectl && sudo mv kubectl /usr/local/bin/
   
   eksctl version
   ```

---

## Deployment Options

### Option 1: EKS Deployment (Recommended)

1. **Create EKS cluster:**
   ```bash
   eksctl create cluster -f infrastructure/eks/cluster.yaml
   ```
   Wait for cluster creation (~15-20 minutes).

2. **Deploy NIM services:**
   ```bash
   # Create namespace and secrets
   kubectl apply -f infrastructure/eks/nim.yaml
   
   # Set NGC API key
   kubectl -n skyguardian create secret generic ngc-secret \
     --from-literal=api-key=$NGC_API_KEY \
     --dry-run=client -o yaml | kubectl apply -f -
   ```

3. **Scale up services for testing:**
   ```bash
   kubectl -n skyguardian scale deploy nemotron-8b-reasoning --replicas=1
   kubectl -n skyguardian scale deploy embedding-nim --replicas=1
   ```

4. **Verify deployment:**
   ```bash
   kubectl -n skyguardian get pods,svc
   ```
   Wait for pods to be in `Running` state (may take 5-10 minutes for image pull).

5. **Port forward for local testing:**
   ```bash
   # Terminal 1: Nemotron 8B NIM
   kubectl -n skyguardian port-forward svc/nemotron-reasoning-service 8000:8000
   
   # Terminal 2: Embedding NIM
   kubectl -n skyguardian port-forward svc/embedding-nim-service 8001:8000
   ```

### Option 2: SageMaker Deployment

1. **Deploy via SageMaker:**
   ```bash
   python scripts/deploy_sagemaker.py \
     --nemotron-endpoint-config ml.g5.2xlarge \
     --embedding-endpoint-config ml.m5.4xlarge \
     --region us-west-2
   ```

2. **Get endpoint URLs:**
   ```bash
   aws sagemaker describe-endpoint --endpoint-name nemotron-8b-reasoning-endpoint
   aws sagemaker describe-endpoint --endpoint-name embedding-nim-endpoint
   ```

---

## Testing the Application

### 1. Test Nemotron 8B Reasoning NIM

**Test reasoning mode with thinking budget:**

```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta/llama-3.1-nemotron-nano-8b-instruct",
    "messages": [
      {
        "role": "user",
        "content": "Plan a search pattern for a missing person in a 10km² forest area. Consider terrain, weather conditions, and time of day. Use step-by-step reasoning."
      }
    ],
    "thinking_budget": 4096,
    "temperature": 0.7,
    "max_tokens": 1024
  }'
```

**Expected output:**
- JSON response with reasoning trace (thinking process)
- Step-by-step search pattern planning
- Consideration of terrain, weather, time constraints
- Resource allocation recommendations

**Verify:**
- Check response includes `thinking` field with reasoning steps
- Response time: ~1.5-2.5 seconds
- Quality: Logical, multi-step reasoning about search strategy

---

### 2. Test Retrieval Embedding NIM

**Test embedding generation:**

```bash
curl -X POST http://localhost:8001/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{
    "input": [
      "Search and rescue protocol for wilderness areas",
      "Thermal imaging detection techniques",
      "Emergency response coordination"
    ],
    "model": "nvidia/nv-embedqa-e5-v5"
  }'
```

**Expected output:**
- JSON with embedding vectors (1024 dimensions each)
- Three separate embeddings for the three input texts

**Verify:**
- Embedding dimension: 1024
- Response time: < 500ms
- Different inputs produce different embeddings

---

### 3. Test RAG Pipeline (Embedding + OpenSearch)

**Prerequisites:**
- OpenSearch Serverless collection created
- Sample documents ingested

**Test retrieval:**

```python
python scripts/test_rag.py \
  --query "What are the best practices for thermal imaging in search and rescue?" \
  --opensearch-endpoint https://<your-opensearch-endpoint> \
  --embedding-endpoint http://localhost:8001/v1/embeddings \
  --index skyguardian-rag \
  --top-k 5
```

**Expected output:**
- Query embedded via Embedding NIM
- Top 5 relevant documents retrieved from OpenSearch
- Context packed and ready for reasoning

**Verify:**
- Retrieved documents are relevant to query
- Embedding similarity scores > 0.7
- Context length appropriate for reasoning

---

### 4. Test Amazon Rekognition Backup

**Test person detection:**

```python
python scripts/test_rekognition.py \
  --image-path test_images/person_detection.jpg \
  --region us-west-2
```

**Expected output:**
- Person detection results from Rekognition
- Bounding boxes for detected persons
- Confidence scores
- Scene labels (optional)

**Verify:**
- Accurate person detection with bounding boxes
- Confidence scores > 0.7
- Fallback works when edge processing has low confidence

**Test fallback mechanism:**

```python
python scripts/test_vision_fallback.py \
  --image-path test_images/low_confidence.jpg \
  --edge-confidence-threshold 0.7
```

**Expected output:**
- Edge processing attempts first (YOLOv8-nano simulation)
- Low confidence detected → fallback to Rekognition
- Combined results returned

---

### 5. Test Multi-Agent Coordination

**Test complete agentic flow:**

```bash
python scripts/test_agentic_flow.py \
  --mission "Search for missing hiker in Sierra Nevada mountains" \
  --area-config '{"size_km2": 25, "terrain": "mountainous", "weather": "clear"}' \
  --nemotron-endpoint http://localhost:8000/v1/chat/completions \
  --embedding-endpoint http://localhost:8001/v1/embeddings
```

**Expected output:**
- Mission Agent creates strategic plan
- Reasoning Agent uses Nemotron 8B with reasoning
- Knowledge Agent retrieves relevant context via RAG
- Response Agent coordinates emergency actions
- Action Agent generates flight commands

**Verify:**
- All agents coordinate successfully
- Reasoning trace shows multi-step thinking
- RAG context is retrieved and used
- Final output includes actionable commands

---

### 6. Test Edge-Cloud Integration (Simulated)

**Test edge sensor data processing:**

```python
python scripts/test_edge_cloud.py \
  --sensor-data test_data/sensor_feed.json \
  --edge-endpoint http://localhost:8080/edge \
  --cloud-endpoint http://localhost:8000/v1/chat/completions
```

**Expected output:**
- Edge processes sensor data (YOLOv8-nano, thermal)
- Data sent to cloud for reasoning
- Cloud returns mission plan
- Edge executes commands

**Verify:**
- Edge processing latency < 100ms
- Cloud reasoning latency < 2s
- End-to-end latency < 3s
- Commands are properly formatted

---

### 7. Test End-to-End Search Scenario

**Complete search and rescue scenario:**

```bash
python scripts/test_search_scenario.py \
  --missing-person "John Doe, 45, last seen near trail marker 7" \
  --area "Sonoma County wilderness, 15km²" \
  --conditions "clear weather, moderate terrain" \
  --nemotron-endpoint http://localhost:8000/v1/chat/completions \
  --embedding-endpoint http://localhost:8001/v1/embeddings \
  --rekognition-enabled true
```

**Expected output:**
1. Mission Agent analyzes situation
2. Reasoning Agent plans search pattern (Nemotron 8B with reasoning)
3. Knowledge Agent retrieves terrain/weather data (RAG)
4. Vision processing detects potential person (YOLOv8 + Rekognition backup)
5. Response Agent coordinates rescue
6. Action Agent generates deployment commands

**Verify:**
- Complete flow executes without errors
- Reasoning trace shows logical progression
- RAG provides relevant context
- Rekognition enhances detection accuracy
- Final output is actionable

---

## Verification Checklist

### ✅ Hackathon Requirements

- [ ] **Nemotron 8B with reasoning mode**: Test shows `thinking_budget` parameter working
- [ ] **NIM inference microservice**: Both Nemotron and Embedding NIMs accessible
- [ ] **Retrieval Embedding NIM**: Embedding generation working correctly
- [ ] **Amazon EKS deployment**: Cluster running with NIM services
- [ ] **Agentic application**: Multi-agent coordination demonstrated

### ✅ AWS Services Integration

- [ ] **Amazon Rekognition**: Person detection working as backup
- [ ] **OpenSearch Serverless**: RAG retrieval functional
- [ ] **S3**: Document storage accessible
- [ ] **CloudWatch**: Metrics and logs visible
- [ ] **IAM/IRSA**: Service accounts properly configured

### ✅ Performance Metrics

- [ ] Nemotron reasoning latency: < 2.5s
- [ ] Embedding generation latency: < 500ms
- [ ] RAG retrieval latency: < 200ms
- [ ] Edge processing latency: < 100ms
- [ ] End-to-end latency: < 3s

### ✅ Cost Management

- [ ] Services scaled down when not in use
- [ ] Cost tracking visible in CloudWatch
- [ ] Within $100 promotional credit budget
- [ ] Cleanup scripts tested

---

## Access Instructions for Judges

**Repository Access:**
- Private repo access granted to:
  - `testing@devpost.com`
  - `dmaltezakis@nvidia.com`
- Invite link provided in repository README

**Demo Access:**
- **EKS Deployment**: Port-forward URLs provided in testing output
- **SageMaker Deployment**: Endpoint URLs shared via AWS console access
- **Local Testing**: `http://localhost:8080` (after port-forward setup)

**Credentials:**
- AWS credentials: Provided via AWS promotional credits
- NGC API key: Included in repository secrets (for judges)
- Test data: Sample images and sensor data in `test_data/` directory

---

## Troubleshooting

### NIM Services Not Starting

```bash
# Check pod logs
kubectl -n skyguardian logs -f deployment/nemotron-8b-reasoning
kubectl -n skyguardian logs -f deployment/embedding-nim

# Verify NGC API key
kubectl -n skyguardian get secret ngc-secret -o jsonpath='{.data.api-key}' | base64 -d

# Check resource allocation
kubectl -n skyguardian describe pod <pod-name>
```

### Rekognition Access Denied

```bash
# Verify IAM permissions
aws rekognition detect-labels --image S3Object={Bucket=test-bucket,Name=test.jpg}

# Check IAM role
aws sts get-caller-identity
```

### OpenSearch Connection Issues

```bash
# Test OpenSearch endpoint
curl -X GET "https://<opensearch-endpoint>/skyguardian-rag/_search" \
  -u "username:password" \
  -H "Content-Type: application/json"
```

### High Latency

```bash
# Check GPU utilization
kubectl -n skyguardian top pod

# Monitor CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/EKS \
  --metric-name CPUUtilization \
  --dimensions Name=ClusterName,Value=skyguardian-cluster \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

---

## Cleanup

After testing, scale down services to save credits:

```bash
# Scale down NIM services
kubectl -n skyguardian scale deploy nemotron-8b-reasoning --replicas=0
kubectl -n skyguardian scale deploy embedding-nim --replicas=0

# Delete cluster (if needed)
eksctl delete cluster --name skyguardian-cluster --region us-west-2

# Delete SageMaker endpoints (if used)
aws sagemaker delete-endpoint --endpoint-name nemotron-8b-reasoning-endpoint
aws sagemaker delete-endpoint --endpoint-name embedding-nim-endpoint
```

---

## Sample Test Queries

### Reasoning Tests

1. **Search Pattern Planning:**
   ```
   "Plan a grid search pattern for a missing person in a 20km² forest. Consider elevation changes, dense vegetation areas, and optimal search altitude for thermal imaging."
   ```

2. **Emergency Response:**
   ```
   "A drone detected a thermal signature at coordinates 38.5°N, 122.8°W. Assess the situation and coordinate rescue response. Consider weather conditions, terrain difficulty, and time constraints."
   ```

3. **Multi-Drone Coordination:**
   ```
   "Coordinate three drones for simultaneous search across three adjacent sectors. Each drone has 20 minutes of battery remaining. Optimize coverage and minimize overlap."
   ```

### RAG Retrieval Tests

1. **Protocol Retrieval:**
   ```
   "What are the standard operating procedures for night-time search and rescue operations?"
   ```

2. **Terrain Analysis:**
   ```
   "What are the challenges of searching in mountainous terrain at high altitude?"
   ```

3. **Medical Emergency:**
   ```
   "What are the signs of hypothermia and how should search drones prioritize detection of these symptoms?"
   ```

---

## Expected Output Examples

### Reasoning Output
```json
{
  "id": "chatcmpl-...",
  "object": "chat.completion",
  "thinking": [
    "Step 1: Analyze search area characteristics...",
    "Step 2: Consider terrain constraints...",
    "Step 3: Optimize search pattern for coverage..."
  ],
  "choices": [{
    "message": {
      "role": "assistant",
      "content": "Based on my reasoning, I recommend a modified expanding square search pattern..."
    }
  }]
}
```

### RAG Output
```json
{
  "query": "thermal imaging best practices",
  "retrieved_docs": [
    {"text": "Thermal imaging is most effective...", "score": 0.89},
    {"text": "Optimal altitude for thermal detection...", "score": 0.85}
  ],
  "context": "Thermal imaging is most effective... Optimal altitude for thermal detection..."
}
```

### Rekognition Output
```json
{
  "persons_detected": 1,
  "bounding_boxes": [{"x": 0.25, "y": 0.30, "width": 0.15, "height": 0.20}],
  "confidence": 0.92,
  "labels": ["Person", "Outdoor", "Wilderness"]
}
```

---

**For questions or issues during testing, contact the team via GitHub Issues or the repository contact information.**

