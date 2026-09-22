# Smart Fridge Retrofit Module (FridgeIQ)
### AI Refrigerator Retrofit Module Using Multi-Sensor Fusion & Cloud Vision for Food Inventory Management

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://python.org)
[![Flask](https://img.shields.io/badge/Flask-3.0+-000000?style=for-the-badge&logo=flask&logoColor=white)](https://flask.palletsprojects.com/)
[![YOLOv8](https://img.shields.io/badge/AI%20Vision-Ultralytics%20YOLOv8-blueviolet?style=for-the-badge)](https://ultralytics.com)
[![ESP32](https://img.shields.io/badge/Hardware-ESP32%20%7C%20ESP32--CAM-E7352C?style=for-the-badge&logo=espressif&logoColor=white)](https://espressif.com)
[![IP Status](https://img.shields.io/badge/IP%20Status-Patent%20Pending%20(Form%202)-success?style=for-the-badge)](#-intellectual-property-framework)

---

## 📌 Overview

The **Smart Fridge Retrofit Module** (**FridgeIQ**) is a non-invasive, low-cost (₹2,000 – ₹3,000 INR / ~$25–$35 USD) hardware-software upgrade package designed to transform any conventional household refrigerator into an intelligent, cloud-connected inventory management appliance.

Commercial smart refrigerators retail at prohibitive price points ($2,000–$4,000 USD). This retrofit module achieves continuous liquid volume tracking inside opaque cartons, real-time shelf telemetry, condensation-free overhead image capture, and automated restocking notifications through **synchronized multi-sensor IoT fusion** and **Cloud YOLOv8 AI vision**.

---

## 🚀 Key Features

- **Anti-Fog Conical Camera Pod (`cad/`):**
  - Custom 3D-printable dual-part enclosure designed for 4°C humid refrigeration environments.
  - Features a 65° conical anti-fog optical baffle, internal flash isolation collar (eliminating optical lens flare), and magnetic mounting.
- **Embedded IoT Micro-Hub Firmware (`software/firmware/`):**
  - **ESP32-CAM (with Upgraded OV3660 3MP Sensor):** Door-switch interrupt triggered image capture with synchronized 100ms flash strobe, sending JPEG frames via HTTP POST to the cloud/server.
  - **ESP32 Sensor Hub (ESP32-WROOM-32 / ESP32-S2):** Samples dual HX711 24-bit differential ADCs across dedicated 5kg cantilever scale trays, DHT22 climate sensor (temperature & humidity), and MC-38 magnetic door reed switch.
- **Central Telemetry & Cloud Vision Engine (`software/`):**
  - Lightweight Python Flask backend with SQLite inventory audit trails and RESTful APIs.
  - **Cloud AI Vision:** Ultralytics YOLOv8n inference pipeline for item identification and bounding-box tagging.
  - Automated low-stock trigger and grocery reordering pipeline.
  - Cloud-ready architecture (deployable on Render, Railway, AWS, or local host).
- **Mobile Companion App (`mobile_app/`):**
  - Cross-platform Flutter application (Android/iOS) with industrial dark-theme HUD.
  - **Native Android Push Notifications:** Delivers heads-up sound & vibration alerts with item name and remaining volume when containers fall below 20%.
  - Dual-zone animated liquid fill gauge (Milk & Beverage).
  - 2×2 responsive telemetry metric grid (DHT22 climate, MC-38 door switch, HX711 shelf mass) optimized for mobile portrait view.
  - Built-in live interactive simulation controls for faculty demonstration.

---

## 📂 Repository Structure

```text
.
├── cad/                                # 3D CAD models & 3D printing specifications
│   ├── anti_fog_camera_pod.scad        # Parametric OpenSCAD design source
│   ├── camera_pod_main_body.stl        # 3D-printable camera housing
│   ├── camera_pod_back_lid.stl         # Snap-fit backplate with magnet wells
│   ├── camera_pod_3d_render.jpg        # Photorealistic CAD preview
│   ├── generate_stl.py                 # Automated STL build script
│   └── 3D_PRINTING_AND_SLICING_GUIDE.md# PETG/PLA slicer specifications
│
├── software/                           # Cloud backend server, APIs, and firmware
│   ├── server.py                       # Core Flask REST server & YOLOv8 CV pipeline
│   ├── requirements.txt                # Python dependencies
│   ├── run_server.sh                   # One-click startup script
│   ├── render.yaml & Procfile          # Cloud deployment configuration
│   ├── templates/                      # Web dashboard interface (HTML5 / Tailwind CSS)
│   └── firmware/                       # Embedded C++ Arduino firmware
│       ├── esp32_cam_strobe.ino        # ESP32-CAM strobe & capture client
│       └── esp32_sensor_hub.ino        # ESP32 multi-sensor telemetry client
│
├── mobile_app/                         # Flutter companion mobile application (FridgeIQ)
│   ├── lib/                            # Application source (Layered MVVM Architecture)
│   │   ├── models/                     # Telemetry, inventory & sensor data models
│   │   ├── services/                   # HTTP REST API client & native notifications
│   │   ├── widgets/                    # Responsive telemetry grid & liquid gauges
│   │   └── screens/                    # Dashboard, sensors & live review demo
│   ├── pubspec.yaml                    # Dart package dependencies
│   ├── FridgeIQ-v1.0-release.apk       # Production Android release APK
│   └── android/                        # Native Android build & notification manifests
│
└── README.md                           # Master project documentation
```

---

## 🛠️ Quick Start Guide

### 1. Run the Backend & Cloud Vision Server
```bash
cd software
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python server.py
# Server runs at http://0.0.0.0:5050 with live Web HUD
```

### 2. Build or Install the Mobile App
```bash
cd mobile_app
flutter pub get
flutter run
# Or build production APK:
flutter build apk --release
```
*A pre-compiled production APK is also provided in `mobile_app/FridgeIQ-v1.0-release.apk`.*

### 3. 3D Print the Enclosure
Open `cad/anti_fog_camera_pod.scad` in OpenSCAD or slice the pre-rendered STL files:
- `cad/camera_pod_main_body.stl`
- `cad/camera_pod_back_lid.stl`
- Recommended material: **PETG** (moisture and condensation resistant in 4°C environments).

### 4. Flash Embedded Firmware
1. Open `software/firmware/esp32_sensor_hub.ino` and `software/firmware/esp32_cam_strobe.ino` in Arduino IDE.
2. Configure local Wi-Fi credentials and the server host address.
3. Flash to the respective ESP32 boards.

---

## 📜 Intellectual Property Framework

- **Inventive Step:** Event-Gated Differential Gravimetric Sampling & Anti-Fog Optical Enclosure for Retrofit Smart Refrigeration.
- **Core Problem Solved:** Eliminates load-cell thermal resistance drift across refrigeration temperature cycles through door-transit baseline calibration, while accurately quantifying fluid depletion inside opaque packaging without internal food immersion probes.
- Drafted in accordance with the **Indian Patents Act, 1970 (Form 2)**.

---

## 👥 Authors & Academic Context
Developed as an engineering capstone project focusing on sustainable embedded systems, Cloud AI vision, and household food waste reduction.
