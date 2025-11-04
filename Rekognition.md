# Alternate Managed-Services Path: Amazon Rekognition Backup Vision

This document defines an alternate path that uses fully managed AWS services to provide redundant person-detection and scene understanding when edge vision has low confidence or is unavailable.

## Goals
- Increase reliability of human detection with a managed service backup
- Reduce operational burden (no custom model hosting required)
- Keep costs bounded by invoking Rekognition only on low-confidence frames

## Architecture

1. Edge device (Jetson) performs primary detection using YOLOv8-nano (fast, local).
2. If no person is detected or confidence < 0.70:
   - Frame is JPEG-encoded and sent to Amazon Rekognition via the AgentCore MCP vision tool.
3. Rekognition returns labels and confidence scores; if `Person` is present, the system raises a detection event.
4. Events are logged to CloudWatch; optional S3 archive of evidential frames.

```
Jetson (YOLOv8) → confidence check → [low?] → Rekognition DetectLabels → combine results → event
```

## API Usage

- `DetectLabels`: person detection + scene context ("Person", "Outdoor", etc.)
- (Optional) `DetectFaces`: additional metadata if needed and allowed by policy

Python example (server-side fallback):
```python
import boto3

def rekognition_fallback(image_bytes: bytes, min_conf=70):
    rek = boto3.client('rekognition')
    resp = rek.detect_labels(Image={'Bytes': image_bytes}, MaxLabels=10, MinConfidence=min_conf)
    labels = {l['Name']: l['Confidence'] for l in resp.get('Labels', [])}
    has_person = 'Person' in labels
    return {
        'has_person': has_person,
        'labels': labels,
    }
```

## Cost Controls
- Invoke Rekognition only on low-confidence frames.
- Throttle rate per drone (e.g., max 1 call/2s under low confidence).
- Optionally subsample frames (e.g., every 10th frame) during extended low-confidence periods.

## Security & Compliance
- Use IRSA to grant minimal Rekognition permissions to the MCP service account.
- Log access in CloudTrail; store evidential frames in an encrypted S3 bucket with limited retention.

## Operational Runbook
- Alarm on elevated Rekognition error rates or throttling.
- Track percentage of frames requiring fallback; investigate when >10% for a sustained period.

## Testing
- Use `scripts/test_rekognition.py <image.jpg>` to validate local credentials and output.
- Validate end-to-end by forcing a high threshold on the edge to trigger fallback and confirm Person detection via Rekognition.

