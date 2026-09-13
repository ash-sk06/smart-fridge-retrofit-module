#!/bin/bash
# =============================================================================
# Quick-Launch Script for AI Refrigerator Retrofit Backend Server
# =============================================================================

cd "$(dirname "$0")"

echo "=================================================================="
echo "Starting AI Refrigerator Retrofit Edge Server..."
echo "=================================================================="

# Check if virtual environment exists; if not, create it
if [ ! -d "venv" ]; then
    echo "[*] Setting up isolated Python virtual environment in software/venv..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Check if flask is installed in venv
if ! python3 -c "import flask" &> /dev/null; then
    echo "[*] Installing dependencies (Flask, NumPy)..."
    pip install flask numpy
fi

# Launch the Flask server
echo "[*] Launching Flask server on http://0.0.0.0:5050 (bypassing macOS AirPlay on 5000)..."
python3 server.py
