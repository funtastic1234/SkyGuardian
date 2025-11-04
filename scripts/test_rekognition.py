import sys
import boto3


def main():
    if len(sys.argv) < 2:
        print("Usage: python scripts/test_rekognition.py <image_path>")
        sys.exit(1)
    image_path = sys.argv[1]
    with open(image_path, 'rb') as f:
        data = f.read()
    client = boto3.client('rekognition')
    resp = client.detect_labels(Image={'Bytes': data}, MaxLabels=10, MinConfidence=70)
    print(resp)


if __name__ == '__main__':
    main()

