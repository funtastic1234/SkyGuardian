import time
import os
import cv2
import boto3
from ultralytics import YOLO


def load_models():
    # Smallest YOLOv8 model for Jetson
    model = YOLO('yolov8n.pt')
    return model


def detect_with_rekognition_fallback(image_bgr, low_conf_threshold=0.7):
    model = load_models()
    results = model.predict(source=image_bgr, verbose=False)

    person_detected = False
    best_conf = 0.0

    for r in results:
        for b in r.boxes:
            cls = int(b.cls[0].item())
            conf = float(b.conf[0].item())
            if cls == 0:  # person
                person_detected = True
                best_conf = max(best_conf, conf)

    if person_detected and best_conf >= low_conf_threshold:
        return {"person": True, "source": "edge", "confidence": best_conf}

    # Fallback to Rekognition
    print("[i] Falling back to Amazon Rekognition")
    rek = boto3.client('rekognition', region_name=os.getenv('AWS_REGION', 'us-west-2'))
    _, jpg = cv2.imencode('.jpg', image_bgr)
    resp = rek.detect_labels(Image={'Bytes': jpg.tobytes()}, MaxLabels=10, MinConfidence=70)
    labels = [l['Name'] for l in resp.get('Labels', [])]
    has_person = any(l == 'Person' for l in labels)
    conf = 0.7 if has_person else 0.0
    return {"person": has_person, "source": "rekognition", "confidence": conf, "labels": labels}


def main():
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        raise RuntimeError("Camera not available")

    print("[+] Edge agent running. Press Ctrl+C to stop.")
    while True:
        ok, frame = cap.read()
        if not ok:
            time.sleep(0.1)
            continue
        result = detect_with_rekognition_fallback(frame)
        if result.get("person"):
            print(f"[PERSON DETECTED] source={result['source']} conf={result['confidence']:.2f}")
        time.sleep(0.1)


if __name__ == '__main__':
    main()

