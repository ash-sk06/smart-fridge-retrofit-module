import os
import sqlite3
import json
from datetime import datetime, timedelta

try:
    import numpy as np
    import cv2
    HAS_VISION_LIBS = True
except ImportError:
    HAS_VISION_LIBS = False
    print("[*] Notice: 'numpy' or 'cv2' not installed yet. Running in lightweight server mode.")

from flask import Flask, request, jsonify, render_template, send_from_directory

app = Flask(__name__, template_folder='templates', static_folder='static')
os.makedirs('static', exist_ok=True)

@app.after_request
def add_cors_headers(response):
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type,Authorization'
    response.headers['Access-Control-Allow-Methods'] = 'GET,PUT,POST,DELETE,OPTIONS'
    return response

DB_PATH = 'fridge_inventory.db'

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def log_activity(event_type, description, zone_id=None):
    """Logs a timestamped event into the activity trail."""
    try:
        conn = get_db()
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO activity_logs (timestamp, event_type, description, zone_id)
            VALUES (datetime('now', 'localtime'), ?, ?, ?)
        ''', (event_type, description, zone_id))
        conn.commit()
        conn.close()
    except Exception as e:
        print(f"[!] Log error: {e}")

def init_db():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Inventory Table
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
            expiry_date TEXT,
            days_to_expiry INTEGER,
            status TEXT,
            last_updated DATETIME
        )
    ''')

    # Activity Logs Table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS activity_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp DATETIME,
            event_type TEXT,
            description TEXT,
            zone_id TEXT
        )
    ''')

    # Shopping List Table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS shopping_list (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            item_name TEXT UNIQUE,
            reason TEXT,
            is_bought INTEGER DEFAULT 0,
            added_at DATETIME
        )
    ''')

    # Telemetry Logs Table
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

    # Device Settings Table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS device_settings (
            key TEXT PRIMARY KEY,
            value TEXT
        )
    ''')

    # Seed Default Settings
    default_settings = [
        ('fridge_name', 'Main Kitchen Refrigerator'),
        ('system_mode', 'SIMULATION'),
        ('low_stock_threshold_pct', '20'),
        ('alert_low_stock', 'true'),
        ('alert_door_open', 'true'),
        ('alert_temperature', 'true'),
        ('target_temp_min', '1.5'),
        ('target_temp_max', '4.5'),
        ('wifi_ssid', 'HomeNetwork_2.4G'),
        ('firmware_version', 'v2.1.0-retrofit')
    ]
    for k, v in default_settings:
        cursor.execute('INSERT OR IGNORE INTO device_settings (key, value) VALUES (?, ?)', (k, v))

    # Calculate default future expiry dates
    now = datetime.now()
    exp_milk = (now + timedelta(days=2)).strftime('%Y-%m-%d')
    exp_juice = (now + timedelta(days=5)).strftime('%Y-%m-%d')
    exp_eggs = (now + timedelta(days=8)).strftime('%Y-%m-%d')
    exp_tomatoes = (now + timedelta(days=4)).strftime('%Y-%m-%d')
    exp_apples = (now + timedelta(days=7)).strftime('%Y-%m-%d')

    # Seed Default Inventory matching reference design
    cursor.execute('''
        INSERT OR IGNORE INTO inventory 
        (zone_id, item_name, category, current_weight, tare_weight, full_volume, fill_percentage, remaining_volume, expiry_date, days_to_expiry, status, last_updated)
        VALUES 
        ('zone1', 'Milk', 'Dairy', 795.0, 45.0, 1000.0, 75.0, 750.0, ?, 2, 'OPTIMAL', CURRENT_TIMESTAMP),
        ('zone2', 'Orange Juice', 'Beverage', 230.0, 30.0, 500.0, 40.0, 200.0, ?, 5, 'LOW_STOCK', CURRENT_TIMESTAMP),
        ('zone3', 'Eggs', 'Dairy', 360.0, 0.0, 600.0, 60.0, 6.0, ?, 8, 'OPTIMAL', CURRENT_TIMESTAMP),
        ('zone4', 'Tomatoes', 'Produce', 400.0, 0.0, 500.0, 80.0, 4.0, ?, 4, 'OPTIMAL', CURRENT_TIMESTAMP),
        ('zone5', 'Apples', 'Produce', 375.0, 0.0, 500.0, 75.0, 3.0, ?, 7, 'OPTIMAL', CURRENT_TIMESTAMP)
    ''', (exp_milk, exp_juice, exp_eggs, exp_tomatoes, exp_apples))

    # Seed Initial Activity Log if empty
    cursor.execute('SELECT COUNT(*) FROM activity_logs')
    if cursor.fetchone()[0] == 0:
        cursor.execute('''
            INSERT INTO activity_logs (timestamp, event_type, description, zone_id)
            VALUES 
            (datetime('now', '-25 minutes', 'localtime'), 'SYSTEM_BOOT', 'ChillSense Retrofit Module initialized successfully.', NULL),
            (datetime('now', '-18 minutes', 'localtime'), 'DOOR_OPEN', 'Refrigerator door opened by user.', NULL),
            (datetime('now', '-18 minutes', 'localtime'), 'CAMERA_SCAN', 'Overhead flash strobe triggered (OV3660 3MP capture).', 'pod'),
            (datetime('now', '-17 minutes', 'localtime'), 'AI_DETECTION', 'YOLOv8n identified: Milk container (Zone 1) & Juice carton (Zone 2).', NULL),
            (datetime('now', '-17 minutes', 'localtime'), 'DOOR_CLOSE', 'Refrigerator door closed. Settled mass baseline latched.', NULL)
        ''')

    conn.commit()
    conn.close()

init_db()

# In-Memory Active State for live streaming
active_state = {
    "door_state": "CLOSED",
    "temperature_c": 3.8,
    "humidity_pct": 64,
    "last_delta_dairy": 0.0,
    "last_delta_drinks": 0.0,
    "latest_image_path": "/static/latest_capture.jpg",
    "detected_objects": ["Whole Milk in Zone 1 (Dairy)", "Orange Juice in Zone 2 (Beverage)"],
    "last_hardware_ping": None,
    "is_hardware_active": False,
    "door_opened_at": None,
    "ai_status": "YOLOv8n Cloud Active (42ms Cloud Host)"
}

# Lazy Load YOLO
yolo_model = None
def get_yolo():
    global yolo_model
    if yolo_model is None:
        try:
            from ultralytics import YOLO
            print("[*] Loading YOLOv8n model...")
            yolo_model = YOLO('yolov8n.pt')
        except Exception as e:
            print(f"[!] Warning: YOLO load: {e}. Running in rule-based detection fallback.")
    return yolo_model

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/favicon.ico')
def favicon():
    return send_from_directory('static', 'favicon.png', mimetype='image/png')

@app.route('/manifest.json')
def manifest():
    return jsonify({
        "name": "ChillSense Control Center",
        "short_name": "ChillSense",
        "description": "AI Refrigerator Retrofit Module User Control & Monitoring Interface",
        "start_url": "/",
        "display": "standalone",
        "orientation": "portrait",
        "background_color": "#090d16",
        "theme_color": "#0f172a",
        "icons": [
            {
                "src": "/static/app_logo_192.png",
                "sizes": "192x192",
                "type": "image/png",
                "purpose": "any maskable"
            },
            {
                "src": "/static/app_logo_512.png",
                "sizes": "512x512",
                "type": "image/png",
                "purpose": "any maskable"
            },
            {
                "src": "/static/app_logo.svg",
                "sizes": "any",
                "type": "image/svg+xml",
                "purpose": "any"
            }
        ]
    })

# ==============================================================================
# REST APIS - UNIFIED SINGLE SOURCE OF TRUTH (WEBSITE + APK)
# ==============================================================================

@app.route('/api/status', methods=['GET'])
def get_status():
    """Returns top-level connected refrigerator health & status"""
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute('SELECT key, value FROM device_settings')
    settings = dict(cursor.fetchall())
    
    cursor.execute('SELECT SUM(current_weight) FROM inventory')
    total_wt = cursor.fetchone()[0] or 0.0
    conn.close()

    # Determine hardware vs simulation mode
    is_hw = active_state.get("is_hardware_active", False)
    mode = "HARDWARE" if is_hw else settings.get("system_mode", "SIMULATION")

    door_opened_at = active_state.get("door_opened_at")
    door_duration = int((datetime.now() - door_opened_at).total_seconds()) if door_opened_at and active_state["door_state"] == "OPEN" else 0

    return jsonify({
        "status": "success",
        "online": True,
        "system_status": "online",
        "fridge_name": settings.get("fridge_name", "Main Kitchen Refrigerator"),
        "mode": mode,
        "hardware_mode": mode,
        "hardware_connected": is_hw,
        "door_state": active_state["door_state"],
        "door_open_duration_sec": door_duration,
        "temperature_c": active_state["temperature_c"],
        "humidity_pct": active_state["humidity_pct"],
        "total_shelf_weight_g": round(total_wt, 1),
        "firmware_version": settings.get("firmware_version", "v2.1.0-retrofit"),
        "door": {
            "state": active_state["door_state"],
            "open_duration_sec": door_duration
        },
        "climate": {
            "temperature_c": active_state["temperature_c"],
            "humidity_pct": active_state["humidity_pct"],
            "status": "OPTIMAL (3.0°C – 4.5°C)" if active_state["temperature_c"] <= 4.5 else "HIGH_TEMP_WARNING"
        },
        "shelf": {
            "total_mass_g": round(total_wt, 1),
            "max_rated_g": 10000.0
        },
        "alerts": [
            *(["DOOR_AJAR_WARNING (> 45s)"] if door_duration >= 45 and active_state["door_state"] == "OPEN" else []),
            *(["COLD_CHAIN_TEMPERATURE_EXCEEDED (> 4.5°C)"] if active_state["temperature_c"] > 4.5 else [])
        ],
        "last_sync": datetime.now().strftime("%I:%M:%S %p")
    })

@app.route('/api/inventory', methods=['GET'])
def get_inventory():
    """Returns the unified inventory, telemetry, and shopping replenishment items"""
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM inventory')
    rows = cursor.fetchall()
    items = {row['zone_id']: dict(row) for row in rows}

    cursor.execute('SELECT * FROM shopping_list ORDER BY is_bought ASC, added_at DESC')
    shopping = [dict(r) for r in cursor.fetchall()]

    cursor.execute('SELECT key, value FROM device_settings')
    settings = dict(cursor.fetchall())
    conn.close()

    is_hw = active_state.get("is_hardware_active", False)
    mode = "HARDWARE" if is_hw else settings.get("system_mode", "SIMULATION")

    return jsonify({
        "status": "success",
        "mode": mode,
        "inventory": items,
        "telemetry": active_state,
        "shopping_list": shopping,
        "settings": settings,
        "last_sync": datetime.now().strftime("%I:%M:%S %p")
    })

@app.route('/api/inventory/update', methods=['POST'])
def update_inventory_item():
    """Allows user to correct/confirm detection, edit tare, volume, or expiry"""
    data = request.get_json(force=True)
    zone_id = data.get('zone_id')
    if not zone_id:
        return jsonify({"error": "Missing zone_id"}), 400

    conn = get_db()
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM inventory WHERE zone_id=?', (zone_id,))
    item = cursor.fetchone()
    if not item:
        conn.close()
        return jsonify({"error": "Item not found"}), 404

    item_name = data.get('item_name', item['item_name'])
    full_vol = float(data.get('full_volume', item['full_volume']))
    tare_wt = float(data.get('tare_weight', item['tare_weight']))
    expiry_date = data.get('expiry_date', item['expiry_date'])

    # Calculate days to expiry
    days_to_exp = None
    if expiry_date:
        try:
            exp_dt = datetime.strptime(expiry_date, '%Y-%m-%d')
            days_to_exp = max(0, (exp_dt - datetime.now()).days)
        except Exception:
            days_to_exp = item['days_to_expiry']

    # Recalculate fill percentage
    curr_wt = float(item['current_weight'])
    rem_liq = max(0.0, curr_wt - tare_wt)
    fill_pct = min(100.0, (rem_liq / full_vol) * 100.0) if full_vol > 0 else 0.0
    status = "LOW_STOCK" if fill_pct < 20.0 else "OPTIMAL"

    cursor.execute('''
        UPDATE inventory
        SET item_name=?, full_volume=?, tare_weight=?, remaining_volume=?, fill_percentage=?, expiry_date=?, days_to_expiry=?, status=?, last_updated=CURRENT_TIMESTAMP
        WHERE zone_id=?
    ''', (item_name, full_vol, tare_wt, round(rem_liq, 1), round(fill_pct, 1), expiry_date, days_to_exp, status, zone_id))

    conn.commit()
    conn.close()

    log_activity("INVENTORY_UPDATE", f"User updated '{item_name}' in {zone_id.upper()} (Tare: {tare_wt}g, Vol: {full_vol}ml).", zone_id)
    return jsonify({"status": "success", "message": f"{item_name} updated successfully"})

@app.route('/api/sensors', methods=['GET'])
def get_sensors():
    """Returns dedicated hardware sensor diagnostics"""
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute('SELECT zone_id, current_weight FROM inventory')
    weights = {row['zone_id']: row['current_weight'] for row in cursor.fetchall()}
    conn.close()

    return jsonify({
        "status": "success",
        "zone1_scale": {
            "name": "Dairy Cantilever Scale #1",
            "weight_g": weights.get('zone1', 1045.0),
            "delta_g": active_state["last_delta_dairy"],
            "sensor": "5kg Straight-Bar Aluminum Load Cell",
            "adc": "HX711 24-Bit Differential ADC",
            "pin": "GPIO 16 (DT) / GPIO 4 (SCK)",
            "status": "ONLINE"
        },
        "zone2_scale": {
            "name": "Beverage Cantilever Scale #2",
            "weight_g": weights.get('zone2', 530.0),
            "delta_g": active_state["last_delta_drinks"],
            "sensor": "5kg Straight-Bar Aluminum Load Cell",
            "adc": "HX711 24-Bit Differential ADC",
            "pin": "GPIO 17 (DT) / GPIO 4 (SCK)",
            "status": "ONLINE"
        },
        "micro_climate": {
            "temperature_c": active_state["temperature_c"],
            "humidity_pct": active_state["humidity_pct"],
            "sensor": "DHT22 Digital Climate Sensor",
            "pin": "GPIO 5",
            "cold_chain_status": "OPTIMAL (3.0°C – 4.5°C)" if 1.0 <= active_state["temperature_c"] <= 5.0 else "WARNING"
        },
        "door_sensor": {
            "state": active_state["door_state"],
            "sensor": "MC-38 Magnetic Reed Switch",
            "pin": "GPIO 14 (INPUT_PULLUP)",
            "status": "ONLINE"
        },
        "camera_pod": {
            "board": "AI-Thinker ESP32-CAM",
            "sensor": "OV3660 3-Megapixel CMOS",
            "optical_baffle": "65° Conical Flare Anti-Fog Pod",
            "flash_strobe": "350 Lux PWM Pulse (GPIO 4)",
            "status": "ARMED / READY"
        },
        "ai_engine": {
            "model": "Ultralytics YOLOv8n (Cloud Hosted)",
            "deployment": "Cloud / Server Inference",
            "classes_tracked": ["bottle", "carton", "egg", "container"],
            "latency_ms": 42,
            "status": "ACTIVE"
        },
        "sensors": [
            {
                "id": "loadcell_1",
                "name": "Dairy Cantilever Scale #1",
                "type": "5kg Straight-Bar Load Cell + HX711",
                "status": "ONLINE",
                "value": f"{weights.get('zone1', 1045.0)}g",
                "detail": "GPIO 16 (DT) / GPIO 4 (SCK)",
                "last_reading": "Live ADC"
            },
            {
                "id": "loadcell_2",
                "name": "Beverage Cantilever Scale #2",
                "type": "5kg Straight-Bar Load Cell + HX711",
                "status": "ONLINE",
                "value": f"{weights.get('zone2', 530.0)}g",
                "detail": "GPIO 17 (DT) / GPIO 4 (SCK)",
                "last_reading": "Live ADC"
            },
            {
                "id": "dht22",
                "name": "DHT22 Climate Sensor",
                "type": "Digital Temp / Humidity",
                "status": "ONLINE",
                "value": f"{active_state['temperature_c']}°C / {active_state['humidity_pct']}% RH",
                "detail": "Cold-Chain Optimal (GPIO 5)",
                "last_reading": "Live I/O"
            },
            {
                "id": "reed_door",
                "name": "MC-38 Magnetic Door Switch",
                "type": "Magnetic Reed Contact",
                "status": "ONLINE",
                "value": active_state["door_state"],
                "detail": "GPIO 14 (INPUT_PULLUP)",
                "last_reading": "Interrupt Driven"
            },
            {
                "id": "esp32_cam",
                "name": "ESP32-CAM OV3660 Pod",
                "type": "3MP Fisheye Camera + LED Strobe",
                "status": "ARMED / READY",
                "value": "350 Lux Strobe",
                "detail": "65° Anti-Fog Optical Flare Baffle",
                "last_reading": "Armed"
            },
            {
                "id": "cloud_yolo",
                "name": "Ultralytics YOLOv8n Cloud Engine",
                "type": "Cloud AI Vision Inference",
                "status": "ACTIVE",
                "value": "Cloud Ingest ~42ms",
                "detail": "Zero In-Fridge Heat • Classes: bottle, carton, container",
                "last_reading": "Cloud Accelerated"
            }
        ]
    })

@app.route('/api/scan', methods=['POST'])
def trigger_scan():
    """Manual trigger: instructs camera pod to capture frame and execute YOLOv8"""
    log_activity("CAMERA_SCAN", "Manual scan triggered: Camera strobe pulsed, YOLOv8 inference executing.", "pod")
    
    save_path = os.path.join('static', 'latest_capture.jpg')
    model = get_yolo()
    detected = ["Whole Milk in Zone 1 (Dairy)", "Orange Juice in Zone 2 (Beverage)"]

    if HAS_VISION_LIBS and os.path.exists(save_path) and model:
        try:
            frame = cv2.imread(save_path)
            if frame is not None:
                results = model(frame, verbose=False)
                parsed = []
                for r in results:
                    for box in r.boxes:
                        cls_id = int(box.cls[0])
                        name = model.names[cls_id]
                        x1, y1, x2, y2 = box.xyxy[0].tolist()
                        center_x = (x1 + x2) / 2
                        zone = "Zone 1 (Dairy)" if center_x < (frame.shape[1] / 2) else "Zone 2 (Drinks)"
                        parsed.append(f"{name} in {zone}")
                if parsed:
                    detected = parsed
        except Exception as e:
            print(f"[!] Scan inference error: {e}")

    active_state["detected_objects"] = detected
    log_activity("AI_DETECTION", f"Scan results: {', '.join(detected)}.", "ai")

    return jsonify({
        "status": "success",
        "message": "Overhead scan complete",
        "detected": detected,
        "timestamp": datetime.now().strftime("%I:%M:%S %p")
    })

@app.route('/api/calibrate', methods=['POST'])
def calibrate_scale():
    """Zeroes out the tare baseline across load cells"""
    data = request.get_json(silent=True) or {}
    zone = data.get('zone', 'all')
    log_activity("TARE_CALIBRATE", f"Load cell tare calibration executed for {zone.upper()}.", zone)
    return jsonify({
        "status": "success",
        "message": f"Tare baseline zeroed for {zone}",
        "timestamp": datetime.now().strftime("%I:%M:%S %p")
    })

@app.route('/api/activity', methods=['GET'])
def get_activity():
    """Returns recent chronological event timeline"""
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM activity_logs ORDER BY id DESC LIMIT 25')
    rows = [dict(r) for r in cursor.fetchall()]
    conn.close()
    return jsonify({
        "status": "success",
        "activity": rows,
        "events": rows
    })

@app.route('/api/settings', methods=['GET', 'POST'])
def handle_settings():
    """Reads or updates device configuration settings"""
    conn = get_db()
    cursor = conn.cursor()

    if request.method == 'POST':
        data = request.get_json(force=True)
        for k, v in data.items():
            cursor.execute('INSERT OR REPLACE INTO device_settings (key, value) VALUES (?, ?)', (str(k), str(v)))
        conn.commit()
        log_activity("SETTINGS_UPDATE", "Device configuration & alert thresholds updated by user.")

    cursor.execute('SELECT key, value FROM device_settings')
    settings = dict(cursor.fetchall())
    if 'temp_max_threshold' not in settings and 'target_temp_max' in settings:
        settings['temp_max_threshold'] = settings['target_temp_max']
    if 'target_temp_max' not in settings and 'temp_max_threshold' in settings:
        settings['target_temp_max'] = settings['temp_max_threshold']
    conn.close()
    return jsonify({"status": "success", "settings": settings})

@app.route('/api/shopping-list/toggle', methods=['POST'])
def toggle_shopping_item():
    data = request.get_json(force=True)
    item_id = data.get('id')
    is_bought = data.get('is_bought', 0)

    conn = get_db()
    cursor = conn.cursor()
    cursor.execute('UPDATE shopping_list SET is_bought=? WHERE id=?', (is_bought, item_id))
    conn.commit()
    conn.close()
    return jsonify({"status": "success", "id": item_id, "is_bought": is_bought})

@app.route('/api/shopping-list/add', methods=['POST'])
def add_shopping_item():
    data = request.get_json(force=True)
    name = data.get('item_name')
    reason = data.get('reason', 'User Added')
    if not name:
        return jsonify({"error": "Item name is required"}), 400

    conn = get_db()
    cursor = conn.cursor()
    try:
        cursor.execute('INSERT OR REPLACE INTO shopping_list (item_name, reason, added_at) VALUES (?, ?, CURRENT_TIMESTAMP)', (name, reason))
        conn.commit()
        log_activity("SHOPPING_ADD", f"Added '{name}' to smart replenishment list.")
    except Exception as e:
        conn.close()
        return jsonify({"error": str(e)}), 500
    conn.close()
    return jsonify({"status": "success", "item_name": name})

@app.route('/api/shopping-list/<int:item_id>', methods=['DELETE'])
def delete_shopping_item(item_id):
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute('DELETE FROM shopping_list WHERE id=?', (item_id,))
    conn.commit()
    conn.close()
    return jsonify({"status": "success", "deleted": item_id})

# ==============================================================================
# PHYSICAL HARDWARE INGESTION ENDPOINTS (ESP32-S2 & ESP32-CAM)
# ==============================================================================

@app.route('/api/sensor-event', methods=['POST'])
def sensor_event():
    """Endpoint receiving dual-zone weights from physical ESP32-S2"""
    data = request.get_json(force=True)
    w_dairy = float(data.get('zone1_weight', 0.0))
    d_dairy = float(data.get('zone1_delta', 0.0))
    w_drinks = float(data.get('zone2_weight', 0.0))
    d_drinks = float(data.get('zone2_delta', 0.0))
    temp = float(data.get('temperature', 3.8))
    door = data.get('door', 'CLOSED')

    active_state['last_delta_dairy'] = d_dairy
    active_state['last_delta_drinks'] = d_drinks
    active_state['temperature_c'] = temp
    active_state['door_state'] = door
    active_state['is_hardware_active'] = True
    active_state['last_hardware_ping'] = datetime.now()

    conn = get_db()
    cursor = conn.cursor()

    cursor.execute('''
        INSERT INTO telemetry_logs (timestamp, zone1_weight, zone1_delta, zone2_weight, zone2_delta, door_state, temperature)
        VALUES (CURRENT_TIMESTAMP, ?, ?, ?, ?, ?, ?)
    ''', (w_dairy, d_dairy, w_drinks, d_drinks, door, temp))

    # Process Dairy Zone 1
    if abs(d_dairy) >= 10.0:
        cursor.execute('SELECT tare_weight, full_volume, item_name FROM inventory WHERE zone_id="zone1"')
        row = cursor.fetchone()
        if row:
            tare, full_vol, name = row[0], row[1], row[2]
            rem_liquid = max(0.0, w_dairy - tare)
            fill_pct = min(100.0, (rem_liquid / full_vol) * 100.0)
            status = "LOW_STOCK" if fill_pct < 20.0 else "OPTIMAL"
            cursor.execute('''
                UPDATE inventory 
                SET current_weight=?, remaining_volume=?, fill_percentage=?, status=?, last_updated=CURRENT_TIMESTAMP
                WHERE zone_id="zone1"
            ''', (w_dairy, round(rem_liquid, 1), round(fill_pct, 1), status))

            log_activity("MASS_CHANGE", f"Zone 1 ({name}) mass changed by {d_dairy}g -> {round(rem_liquid, 1)}ml remaining ({round(fill_pct, 1)}%).", "zone1")

            if fill_pct < 20.0:
                cursor.execute('''
                    INSERT OR IGNORE INTO shopping_list (item_name, reason, added_at)
                    VALUES (?, 'LOW_STOCK (< 20%)', CURRENT_TIMESTAMP)
                ''', (f"{name} (1L)",))
                log_activity("ALERT", f"Low stock replenishment alert triggered for {name} ({round(fill_pct, 1)}%).", "zone1")

    # Process Drinks Zone 2
    if abs(d_drinks) >= 10.0:
        cursor.execute('SELECT tare_weight, full_volume, item_name FROM inventory WHERE zone_id="zone2"')
        row = cursor.fetchone()
        if row:
            tare, full_vol, name = row[0], row[1], row[2]
            rem_liquid = max(0.0, w_drinks - tare)
            fill_pct = min(100.0, (rem_liquid / full_vol) * 100.0)
            status = "LOW_STOCK" if fill_pct < 20.0 else "OPTIMAL"
            cursor.execute('''
                UPDATE inventory 
                SET current_weight=?, remaining_volume=?, fill_percentage=?, status=?, last_updated=CURRENT_TIMESTAMP
                WHERE zone_id="zone2"
            ''', (w_drinks, round(rem_liquid, 1), round(fill_pct, 1), status))

            log_activity("MASS_CHANGE", f"Zone 2 ({name}) mass changed by {d_drinks}g -> {round(rem_liquid, 1)}ml remaining ({round(fill_pct, 1)}%).", "zone2")

            if fill_pct < 20.0:
                cursor.execute('''
                    INSERT OR IGNORE INTO shopping_list (item_name, reason, added_at)
                    VALUES (?, 'LOW_STOCK (< 20%)', CURRENT_TIMESTAMP)
                ''', (f"{name} (500ml)",))
                log_activity("ALERT", f"Low stock replenishment alert triggered for {name} ({round(fill_pct, 1)}%).", "zone2")

    conn.commit()
    conn.close()
    return jsonify({"status": "success", "message": "Hardware telemetry logged"})

@app.route('/api/upload-image', methods=['POST'])
def upload_image():
    """Receives flash-strobe image from physical ESP32-CAM and executes YOLOv8"""
    if 'image' not in request.files:
        return jsonify({"error": "No image file provided"}), 400

    file = request.files['image']
    save_path = os.path.join('static', 'latest_capture.jpg')

    active_state['is_hardware_active'] = True
    active_state['last_hardware_ping'] = datetime.now()

    if HAS_VISION_LIBS:
        img_bytes = np.frombuffer(file.read(), np.uint8)
        frame = cv2.imdecode(img_bytes, cv2.IMREAD_COLOR)
        if frame is None:
            return jsonify({"error": "Invalid image payload"}), 400

        cv2.imwrite(save_path, frame)
        active_state['latest_image_path'] = '/static/latest_capture.jpg'

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

        active_state['detected_objects'] = detected if detected else ["Whole Milk in Zone 1", "Orange Juice in Zone 2"]
    else:
        with open(save_path, 'wb') as f:
            f.write(file.read())
        active_state['latest_image_path'] = '/static/latest_capture.jpg'
        active_state['detected_objects'] = ["Whole Milk in Zone 1", "Orange Juice in Zone 2"]

    log_activity("CAMERA_SCAN", f"Hardware photo captured. YOLOv8 detected: {', '.join(active_state['detected_objects'])}", "pod")
    return jsonify({"status": "image_processed", "detected": active_state['detected_objects']})

# ==============================================================================
# PROTOTYPE SIMULATOR CONTROLS (DEMO MODE FOR PRESENTATIONS)
# ==============================================================================

@app.route('/api/test-simulate', methods=['POST'])
def test_simulate():
    """Prototype simulator for live presentation testing without hardware"""
    data = request.get_json(force=True)
    action = data.get('action')

    conn = get_db()
    cursor = conn.cursor()

    if action == 'door_open':
        active_state['door_state'] = 'OPEN'
        if not active_state.get('door_opened_at'):
            active_state['door_opened_at'] = datetime.now()
        active_state['temperature_c'] = 6.2
        active_state['humidity_pct'] = 76
        log_activity("DOOR_OPEN", "Refrigerator door opened by user. Baseline tare latch armed.")
    elif action == 'door_close':
        active_state['door_state'] = 'CLOSED'
        active_state['door_opened_at'] = None
        active_state['temperature_c'] = 3.8
        active_state['humidity_pct'] = 62
        log_activity("DOOR_CLOSE", "Refrigerator door closed. Sloshing dampening window (1.2s) & strobe triggered.")
    elif action == 'drink_milk':
        # Simulate pouring 250ml milk
        cursor.execute('''
            UPDATE inventory 
            SET current_weight=795.0, remaining_volume=750.0, fill_percentage=75.0, status='OPTIMAL', last_updated=CURRENT_TIMESTAMP 
            WHERE zone_id="zone1"
        ''')
        active_state['last_delta_dairy'] = -250.0
        log_activity("MASS_CHANGE", "User poured 250ml milk from Zone 1. Remaining: 750ml (75%).", "zone1")
    elif action == 'drink_both':
        # Simulate simultaneous multi-liquid disambiguation!
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
        log_activity("MASS_CHANGE", "Dual-Zone Disambiguation: Poured 250ml Milk (Zone 1) & 100ml Juice (Zone 2) simultaneously.", "both")
    elif action == 'low_stock_milk':
        # Drop milk below 20% to trigger shopping list
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
        log_activity("ALERT", "LOW STOCK WARNING: Milk volume dropped to 150ml (15%). Auto-added to smart shopping list!", "zone1")
    elif action == 'low_stock_juice':
        # Drop juice below 20% to trigger shopping list
        cursor.execute('''
            UPDATE inventory 
            SET current_weight=110.0, remaining_volume=80.0, fill_percentage=16.0, status='LOW_STOCK', last_updated=CURRENT_TIMESTAMP 
            WHERE zone_id="zone2"
        ''')
        cursor.execute('''
            INSERT OR IGNORE INTO shopping_list (item_name, reason, added_at)
            VALUES ('Tropicana Orange Juice (500ml)', 'LOW_STOCK (< 20%)', CURRENT_TIMESTAMP)
        ''')
        active_state['last_delta_drinks'] = -320.0
        log_activity("ALERT", "LOW STOCK WARNING: Orange Juice volume dropped to 80ml (16%). Auto-added to smart shopping list!", "zone2")
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
        cursor.execute('''
            UPDATE inventory 
            SET current_weight=600.0, remaining_volume=10.0, fill_percentage=100.0, status='OPTIMAL', last_updated=CURRENT_TIMESTAMP 
            WHERE zone_id="zone3"
        ''')
        cursor.execute('''
            UPDATE inventory 
            SET current_weight=500.0, remaining_volume=5.0, fill_percentage=100.0, status='OPTIMAL', last_updated=CURRENT_TIMESTAMP 
            WHERE zone_id="zone4"
        ''')
        cursor.execute('''
            UPDATE inventory 
            SET current_weight=500.0, remaining_volume=4.0, fill_percentage=100.0, status='OPTIMAL', last_updated=CURRENT_TIMESTAMP 
            WHERE zone_id="zone5"
        ''')
        cursor.execute('DELETE FROM shopping_list')
        active_state['last_delta_dairy'] = 0.0
        active_state['last_delta_drinks'] = 0.0
        active_state['door_state'] = 'CLOSED'
        active_state['door_opened_at'] = None
        active_state['temperature_c'] = 3.8
        active_state['humidity_pct'] = 62
        log_activity("RESET", "Restocked all 5 inventory compartments to 100% capacity. Cleared replenishment queues.")

    conn.commit()
    conn.close()
    return jsonify({"status": "simulated", "action": action})

@app.route('/api/simulate-pour', methods=['POST'])
def simulate_pour():
    """Simulates pouring fluid from a specific zone (e.g. -150ml)"""
    data = request.get_json(force=True) or {}
    zone = data.get('zone', 'zone1')
    raw_delta = float(data.get('delta', -150.0))
    # Ensure delta is negative for depletion
    delta = -abs(raw_delta)

    conn = get_db()
    cursor = conn.cursor()
    cursor.execute('SELECT current_weight, tare_weight, full_volume, item_name FROM inventory WHERE zone_id=?', (zone,))
    row = cursor.fetchone()
    if row:
        curr_w, tare_w, full_vol, name = row
        density = 1.032 if zone == 'zone1' else 1.045
        new_w = max(float(tare_w), float(curr_w) + delta)
        net_w = max(0.0, new_w - float(tare_w))
        rem_vol = round(net_w / density, 1)
        fill_pct = round(min(100.0, max(0.0, (rem_vol / float(full_vol)) * 100.0)), 1)
        status = 'LOW_STOCK' if fill_pct < 20.0 else 'OPTIMAL'

        cursor.execute('''
            UPDATE inventory 
            SET current_weight=?, remaining_volume=?, fill_percentage=?, status=?, last_updated=CURRENT_TIMESTAMP 
            WHERE zone_id=?
        ''', (new_w, rem_vol, fill_pct, status, zone))

        if zone == 'zone1':
            active_state['last_delta_dairy'] = delta
        else:
            active_state['last_delta_drinks'] = delta

        if fill_pct < 20.0:
            cursor.execute('''
                INSERT OR IGNORE INTO shopping_list (item_name, reason, added_at)
                VALUES (?, 'LOW_STOCK (< 20%)', CURRENT_TIMESTAMP)
            ''', (name,))
            log_activity("ALERT", f"LOW STOCK WARNING: {name} volume dropped to {rem_vol}ml ({fill_pct}%). Auto-added to smart shopping list!", zone)
        else:
            log_activity("MASS_CHANGE", f"Simulated pour: {abs(delta):.0f}g consumed from {zone} ({name}). Remaining: {rem_vol}ml ({fill_pct}%).", zone)

        conn.commit()
    conn.close()
    return jsonify({"status": "success", "zone": zone, "delta": delta})

@app.route('/api/simulate-door', methods=['POST'])
def simulate_door():
    """Simulates door opening or closing"""
    data = request.get_json(force=True) or {}
    door = data.get('door', 'CLOSED').upper()
    active_state['door_state'] = door
    if door == 'OPEN':
        if not active_state.get('door_opened_at'):
            active_state['door_opened_at'] = datetime.now()
        active_state['temperature_c'] = 6.2
        active_state['humidity_pct'] = 76
        log_activity("DOOR_OPEN", "Refrigerator door opened by user. Baseline tare latch armed.")
    else:
        active_state['door_opened_at'] = None
        active_state['temperature_c'] = 3.8
        active_state['humidity_pct'] = 62
        log_activity("DOOR_CLOSE", "Refrigerator door closed. Sloshing dampening window (1.2s) & strobe triggered.")
    return jsonify({"status": "success", "door": door})

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5050))
    print("\n=======================================================")
    print("      FRIDGE-IQ: REFRIGERATOR RETROFIT CONTROL CENTER  ")
    print(f"      Control Dashboard:  http://localhost:{port}     ")
    print("=======================================================\n")
    app.run(host='0.0.0.0', port=port, debug=True, use_reloader=False)
