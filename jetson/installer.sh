#!/usr/bin/env bash
set -euo pipefail

echo "[+] Updating system packages"
sudo apt-get update -y
sudo apt-get install -y python3-pip python3-venv git curl jq

echo "[+] Creating Python venv"
python3 -m venv ~/skyg-venv
source ~/skyg-venv/bin/activate

echo "[+] Installing Python dependencies"
pip install --upgrade pip
pip install numpy opencv-python torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu118
pip install boto3 requests

echo "[+] Optimizing power mode (requires sudo)"
sudo nvpmodel -m 2 || true

echo "[+] Installing YOLOv8 (ultralytics)"
pip install ultralytics

echo "[+] Done. To run edge agent:"
echo "    source ~/skyg-venv/bin/activate && python jetson/edge_agent.py"

