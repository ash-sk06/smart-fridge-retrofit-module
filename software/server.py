import os
import sqlite3
try:
    import numpy as np
    import cv2
    HAS_VISION_LIBS = True
except ImportError:
    HAS_VISION_LIBS = False
    print("[*] Notice: 'numpy' or 'cv2' not installed yet. Running in lightweight server mode.")
from datetime import datetime
from flask import Flask, request, jsonify, render_template, send_from_directory

app = Flask(__name__, template_folder='templates', static_folder='static')
os.makedirs('static', exist_ok=True)

@app.after_request
def add_cors_headers(response):
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type,Authorization'
    response.headers['Access-Control-Allow-Methods'] = 'GET,PUT,POST,DELETE,OPTIONS'
    return response

# Database initialization
DB_PATH = 'fridge_inventory.db'

def init_db():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS inventory (
            zone_id TEXT PRIMARY KEY,
            item_name TEXT,
            category TEXT,
            current_weight REAL,
            tare_weight REAL,
            full_volume REAL,
            fill_percentage REAL,
            remaining_volume REAL,
            status TEXT,
            last_updated DATETIME
        )
    ''')
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS shopping_list (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            item_name TEXT UNIQUE,
            reason TEXT,
            is_bought INTEGER DEFAULT 0,
            added_at DATETIME
        )
    ''')
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS telemetry_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp DATETIME,
            zone1_weight REAL,
            zone1_delta REAL,
            zone2_weight REAL,
            zone2_delta REAL,
            door_state TEXT,
            temperature REAL
        )
    ''')
    # Default seed data
    cursor.execute('''
        INSERT OR IGNORE INTO inventory 
        (zone_id, item_name, category, current_weight, tare_weight, full_volume, fill_percentage, remaining_volume, status, last_updated)
        VALUES 
        ('zone1', 'Pasteurized Whole Milk', 'Dairy', 1045.0, 45.0, 1000.0, 100.0, 1000.0, 'OPTIMAL', CURRENT_TIMESTAMP),
        ('zone2', 'Fresh Orange Juice', 'Beverage', 530.0, 30.0, 500.0, 100.0, 500.0, 'OPTIMAL', CURRENT_TIMESTAMP)
    ''')
    conn.commit()
    conn.close()

init_db()

# In-Memory Active State for ultra-fast polling
active_state = {
    "door_state": "CLOSED",
    "temperature_c": 4.1,
    "humidity_pct": 65,
    "last_delta_dairy": 0.0,
    "last_delta_drinks": 0.0,
    "latest_image_path": "/static/placeholder.jpg",
    "detected_objects": ["bottle (Dairy)", "bottle (Drinks)"]
}

# Load YOLO model (Lazy load or load on startup)
yolo_model = None
def get_yolo():
    global yolo_model
    if yolo_model is None:
        try:
            from ultralytics import YOLO
            print("[*] Loading YOLOv8n model...")
            yolo_model = YOLO('yolov8n.pt')
        except Exception as e:
            print(f"[!] Warning: YOLO load error: {e}. Running in rule-based fallback mode.")
    return yolo_model

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/manifest.json')
def manifest():
    return jsonify({
        "name": "Smart Fridge Retrofit",
        "short_name": "SmartFridge",
        "description": "AI Refrigerator Dual-Zone Retrofit Module",
        "start_url": "/",
        "display": "standalone",
        "orientation": "portrait",
        "background_color": "#0f172a",
        "theme_color": "#0f172a",
        "icons": [
            {
                "src": "https://cdn-icons-png.flaticon.com/512/3757/3757876.png",
                "sizes": "512x512",
                "type": "image/png",
                "purpose": "any maskable"
            }
        ]
    })

@app.route('/api/inventory', methods=['GET'])
def get_inventory():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM inventory')
    rows = cursor.fetchall()
    items = {row['zone_id']: dict(row) for row in rows}

    cursor.execute('SELECT * FROM shopping_list WHERE is_bought = 0')
    shopping = [dict(r) for r in cursor.fetchall()]
    conn.close()

    return jsonify({
        "status": "success",
        "inventory": items,
        "telemetry": active_state,
        "shopping_list": shopping
    })

@app.route('/api/sensor-event', methods=['POST'])
def sensor_event():
    """Endpoint receiving dual-zone weights from ESP32"""
    data = request.get_json(force=True)
    w_dairy = float(data.get('zone1_weight', 0.0))
    d_dairy = float(data.get('zone1_delta', 0.0))
    w_drinks = float(data.get('zone2_weight', 0.0))
    d_drinks = float(data.get('zone2_delta', 0.0))
    temp = float(data.get('temperature', 4.1))
    door = data.get('door', 'CLOSED')

    active_state['last_delta_dairy'] = d_dairy
    active_state['last_delta_drinks'] = d_drinks
    active_state['temperature_c'] = temp
    active_state['door_state'] = door

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # Log telemetry
    cursor.execute('''
        INSERT INTO telemetry_logs (timestamp, zone1_weight, zone1_delta, zone2_weight, zone2_delta, door_state, temperature)
        VALUES (CURRENT_TIMESTAMP, ?, ?, ?, ?, ?, ?)
    ''', (w_dairy, d_dairy, w_drinks, d_drinks, door, temp))

    # Process Zone 1 (Dairy / Milk)
    if abs(d_dairy) >= 10.0:
        cursor.execute('SELECT tare_weight, full_volume FROM inventory WHERE zone_id="zone1"')
        row = cursor.fetchone()
        if row:
            tare, full_vol = row[0], row[1]
            rem_liquid = max(0.0, w_dairy - tare)
            fill_pct = min(100.0, (rem_liquid / full_vol) * 100.0)
            status = "LOW_STOCK" if fill_pct < 20.0 else "OPTIMAL"
            cursor.execute('''
                UPDATE inventory 
                SET current_weight=?, remaining_volume=?, fill_percentage=?, status=?, last_updated=CURRENT_TIMESTAMP
                WHERE zone_id="zone1"
            ''', (w_dairy, round(rem_liquid, 1), round(fill_pct, 1), status))

            if fill_pct < 20.0:
                cursor.execute('''
                    INSERT OR IGNORE INTO shopping_list (item_name, reason, added_at)
                    VALUES ('Pasteurized Whole Milk (1L)', 'LOW_STOCK (< 20%)', CURRENT_TIMESTAMP)
                ''')

    # Process Zone 2 (Drinks / Juice)
    if abs(d_drinks) >= 10.0:
        cursor.execute('SELECT tare_weight, full_volume FROM inventory WHERE zone_id="zone2"')
        row = cursor.fetchone()
        if row:
            tare, full_vol = row[0], row[1]
            rem_liquid = max(0.0, w_drinks - tare)
            fill_pct = min(100.0, (rem_liquid / full_vol) * 100.0)
            status = "LOW_STOCK" if fill_pct < 20.0 else "OPTIMAL"
            cursor.execute('''
                UPDATE inventory 
                SET current_weight=?, remaining_volume=?, fill_percentage=?, status=?, last_updated=CURRENT_TIMESTAMP
                WHERE zone_id="zone2"
            ''', (w_drinks, round(rem_liquid, 1), round(fill_pct, 1), status))

            if fill_pct < 20.0:
                cursor.execute('''
                    INSERT OR IGNORE INTO shopping_list (item_name, reason, added_at)
                    VALUES ('Fresh Orange Juice (500ml)', 'LOW_STOCK (< 20%)', CURRENT_TIMESTAMP)
                ''')

    conn.commit()
    conn.close()

    print(f"[*] Processed Event -> Dairy Wt: {w_dairy}g (Δ {d_dairy}g) | Drinks Wt: {w_drinks}g (Δ {d_drinks}g)")
    return jsonify({"status": "success", "message": "Telemetry logged and inventory updated"})

@app.route('/api/upload-image', methods=['POST'])
def upload_image():
    """Receives image from ESP32-CAM and runs YOLO"""
    if 'image' not in request.files:
        return jsonify({"error": "No image file provided"}), 400

    file = request.files['image']
    save_path = os.path.join('static', 'latest_capture.jpg')

    if HAS_VISION_LIBS:
        img_bytes = np.frombuffer(file.read(), np.uint8)
        frame = cv2.imdecode(img_bytes, cv2.IMREAD_COLOR)
        if frame is None:
            return jsonify({"error": "Invalid image payload"}), 400

        cv2.imwrite(save_path, frame)
        active_state['latest_image_path'] = '/static/latest_capture.jpg'

        # Run YOLO object detection
        model = get_yolo()
        detected = []
        if model:
            results = model(frame, verbose=False)
            for r in results:
                for box in r.boxes:
                    cls_id = int(box.cls[0])
                    name = model.names[cls_id]
                    x1, y1, x2, y2 = box.xyxy[0].tolist()
                    center_x = (x1 + x2) / 2
                    frame_width = frame.shape[1]
                    zone = "Zone 1 (Dairy)" if center_x < (frame_width / 2) else "Zone 2 (Drinks)"
                    detected.append(f"{name} in {zone}")

        active_state['detected_objects'] = detected if detected else ["bottle (Dairy)", "bottle (Drinks)"]
    else:
        # Pure Python fallback without numpy/cv2
        with open(save_path, 'wb') as f:
            f.write(file.read())
        active_state['latest_image_path'] = '/static/latest_capture.jpg'
        active_state['detected_objects'] = ["bottle (Dairy)", "bottle (Drinks)"]

    print(f"[*] Visual Inference: {active_state['detected_objects']}")
    return jsonify({"status": "image_processed", "detected": active_state['detected_objects']})

@app.route('/api/test-simulate', methods=['POST'])
def test_simulate():
    """Simulation helper for testing without hardware"""
    data = request.get_json(force=True)
    action = data.get('action')

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    if action == 'drink_milk':
        # Simulate pouring 250ml milk
        cursor.execute('''
            UPDATE inventory 
            SET current_weight=795.0, remaining_volume=750.0, fill_percentage=75.0, status='OPTIMAL', last_updated=CURRENT_TIMESTAMP 
            WHERE zone_id="zone1"
        ''')
        active_state['last_delta_dairy'] = -250.0
    elif action == 'drink_both':
        # Simulate simultaneous multi-liquid consumption
        cursor.execute('''
            UPDATE inventory 
            SET current_weight=795.0, remaining_volume=750.0, fill_percentage=75.0, status='OPTIMAL', last_updated=CURRENT_TIMESTAMP 
            WHERE zone_id="zone1"
        ''')
        cursor.execute('''
            UPDATE inventory 
            SET current_weight=430.0, remaining_volume=400.0, fill_percentage=80.0, status='OPTIMAL', last_updated=CURRENT_TIMESTAMP 
            WHERE zone_id="zone2"
        ''')
        active_state['last_delta_dairy'] = -250.0
        active_state['last_delta_drinks'] = -100.0
    elif action == 'low_stock_milk':
        # Simulate milk dropping to 15%
        cursor.execute('''
            UPDATE inventory 
            SET current_weight=195.0, remaining_volume=150.0, fill_percentage=15.0, status='LOW_STOCK', last_updated=CURRENT_TIMESTAMP 
            WHERE zone_id="zone1"
        ''')
        cursor.execute('''
            INSERT OR IGNORE INTO shopping_list (item_name, reason, added_at)
            VALUES ('Pasteurized Whole Milk (1L)', 'LOW_STOCK (< 20%)', CURRENT_TIMESTAMP)
        ''')
        active_state['last_delta_dairy'] = -600.0
    elif action == 'reset_full':
        cursor.execute('''
            UPDATE inventory 
            SET current_weight=1045.0, remaining_volume=1000.0, fill_percentage=100.0, status='OPTIMAL', last_updated=CURRENT_TIMESTAMP 
            WHERE zone_id="zone1"
        ''')
        cursor.execute('''
            UPDATE inventory 
            SET current_weight=530.0, remaining_volume=500.0, fill_percentage=100.0, status='OPTIMAL', last_updated=CURRENT_TIMESTAMP 
            WHERE zone_id="zone2"
        ''')
        cursor.execute('DELETE FROM shopping_list')
        active_state['last_delta_dairy'] = 0.0
        active_state['last_delta_drinks'] = 0.0

    conn.commit()
    conn.close()
    return jsonify({"status": "simulated", "action": action})

import socket

def get_clean_port(preferred=5050):
    for candidate in [preferred, 5050, 8080, 8000]:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            try:
                s.bind(('0.0.0.0', candidate))
                return candidate
            except OSError:
                continue
    return preferred

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5050))
    print("\n=======================================================")
    print("  AI REFRIGERATOR RETROFIT SERVER (DUAL-ZONE ENGINE)   ")
    print(f"  Laptop Web Dashboard:  http://localhost:{port}       ")
    print("=======================================================\n")
    # use_reloader=False prevents Flask reloader process from conflicting on port
    app.run(host='0.0.0.0', port=port, debug=True, use_reloader=False)
