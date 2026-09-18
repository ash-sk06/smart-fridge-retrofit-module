# Smart Fridge Retrofit Module
### AI Refrigerator Retrofit Module Using Multi-Sensor Fusion for Food Inventory Management

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://python.org)
[![Flask](https://img.shields.io/badge/Flask-3.0+-000000?style=for-the-badge&logo=flask&logoColor=white)](https://flask.palletsprojects.com/)
[![ESP32](https://img.shields.io/badge/Hardware-ESP32%20%7C%20ESP32--CAM-E7352C?style=for-the-badge&logo=espressif&logoColor=white)](https://espressif.com)
[![Patent](https://img.shields.io/badge/IP%20Status-Patent%20Pending%20(Form%202)-success?style=for-the-badge)](./FINAL_PATENT_APPLICATION_SPECIFICATION.md)

---

## 📌 Overview

The **Smart Fridge Retrofit Module** is a non-invasive, low-cost (₹2,000 – ₹3,000 INR / ~$25–$35 USD) hardware-software upgrade package designed to transform any conventional household refrigerator into an intelligent, cloud-connected inventory management hub.

Conventional smart refrigerators retail at prohibitive price points ($2,000–$4,000 USD). This retrofit module achieves real-time inventory tracking, liquid level monitoring, condensation prevention, and shelf telemetry through **synchronized multi-sensor edge fusion** and **computer vision**.

---

## 🚀 Key Features

- **Anti-Fog Conical Camera Pod (`cad/`):** Custom 3D-printable dual-part enclosure featuring a 65° conical anti-fog baffle, internal flash isolation collar (eliminates optical glare on the lens), and dual neodymium magnet mount.
- **Micro-Hub Edge Firmware (`software/firmware/`):**
  - **ESP32-CAM (with Upgraded OV3660 3MP Sensor):** Door-switch triggered image capture with synchronized 100ms flash strobe, sending JPEG frames via HTTP POST to the processing server.
  - **ESP32-S2 Sensor Hub (ESP32-S2-DevKitM-1):** High-speed 240MHz Wi-Fi hub sampling dual HX711 24-bit ADCs across 2x pre-fabricated 5kg cantilever scale kits with independent acrylic trays (2mm gap), DHT22 climate metrics, and MC-38 magnetic door switch.
- **Central Processing & Telemetry Server (`software/`):**
  - Lightweight Flask backend with SQLite inventory logging.
  - Computer Vision pipeline with YOLOv8 inference fallback for item identification.
  - RESTful APIs powering mobile & web clients with live status, history, and automated grocery triggers.
  - Cloud-ready configuration (Render / Railway / Heroku).
- **Mobile Companion App (`mobile_app/`):**
  - Cross-platform Flutter application (Android/iOS).
  - Dual-zone animated liquid fill gauge (Milk & Beverage).
  - Real-time shelf telemetry (weight, temperature, humidity, door state).
  - Visual snapshot view and automated restocking checklist.
  - Offline Demo / Simulation sandbox for hardware-free presentation testing.

---

## 📂 Repository Structure

```text
.
├── cad/                                # 3D CAD models & 3D printing guides
│   ├── anti_fog_camera_pod.scad        # Parametric OpenSCAD design source
│   ├── camera_pod_main_body.stl        # 3D printable camera housing
│   ├── camera_pod_back_lid.stl         # Snap-fit backplate with magnet wells
│   ├── camera_pod_3d_render.jpg        # Photorealistic CAD preview
│   ├── generate_stl.py                 # Automated STL build script
│   └── 3D_PRINTING_AND_SLICING_GUIDE.md# PETG/PLA slicer specifications
│
├── software/                           # Backend server, APIs, and firmware
│   ├── server.py                       # Core Flask REST server & CV pipeline
│   ├── requirements.txt                # Python dependencies
│   ├── run_server.sh                   # One-click startup script
│   ├── render.yaml & Procfile          # Cloud deployment configuration
│   ├── templates/                      # Web dashboard templates (HTML/Tailwind)
│   └── firmware/                       # Embedded micro-controller source
│       ├── esp32_cam_strobe.ino        # ESP32-CAM strobe & capture client
│       └── esp32_sensor_hub.ino        # ESP32 multi-sensor telemetry client
│
├── mobile_app/                         # Flutter companion application
│   ├── lib/                            # Application source (MVVM Architecture)
│   │   ├── models/                     # Telemetry & Inventory data models
│   │   ├── services/                   # HTTP REST client service
│   │   ├── widgets/                    # Animated liquid gauge & stat cards
│   │   └── screens/                    # Dashboard, Telemetry & Demo screens
│   ├── pubspec.yaml                    # Dart package dependencies
│   ├── mobile_app_ui_mockup.jpg        # High-res UI preview
│   └── android/                        # Native Android build & manifest configs
│
├── AI_FRIDGE_RETROFIT_MASTER_SPECIFICATION.md # Full engineering & system architecture
├── BUILD_AND_ASSEMBLY_MANUAL.md        # Hardware wiring diagrams & assembly steps
├── SOFTWARE_IMPLEMENTATION_GUIDE.md    # API endpoints & server setup guide
├── CLOUD_DEPLOYMENT_GUIDE.md           # Instructions to host the backend on Render
├── FACULTY_PRESENTATION_DECK.html      # Interactive slide presentation for reviews
├── FACULTY_PRESENTATION_SLIDES.md      # Markdown slide notes
├── FINAL_PATENT_APPLICATION_SPECIFICATION.md # Indian Patent Act (Form 2) complete draft
├── PATENT_SPECIFICATION_PROVISIONAL_DRAFT.md # Provisional patent specification
├── PATENTABILITY_SEARCH_AND_PRIOR_ART_REPORT.md # Prior art analysis against LG/Samsung
└── PATENTABILITY_STRATEGY_AND_DEFENSE_GUIDE.md  # Novelty defense & patent claims breakdown
```

---

## 🛠️ Quick Start Guide

### 1. Run the Backend Server
```bash
cd software
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python server.py
# Server runs locally at http://0.0.0.0:5050
```

### 2. Build or Install the Mobile App
```bash
cd mobile_app
flutter pub get
flutter run
# Or build the APK:
flutter build apk --release
```
*Note: A pre-built release APK is generated in `mobile_app/build/app/outputs/flutter-apk/app-release.apk`.*

### 3. 3D Print the Enclosure
Open `cad/anti_fog_camera_pod.scad` in OpenSCAD or directly slice:
- `cad/camera_pod_main_body.stl`
- `cad/camera_pod_back_lid.stl`
Recommended material: **PETG** (due to condensation resistance in 4°C environments). See [`cad/3D_PRINTING_AND_SLICING_GUIDE.md`](cad/3D_PRINTING_AND_SLICING_GUIDE.md) for slicer settings.

### 4. Flash the Firmware
1. Open `software/firmware/esp32_sensor_hub.ino` and `software/firmware/esp32_cam_strobe.ino` in Arduino IDE.
2. Set your local WiFi SSID, password, and the backend server IP (`http://<YOUR_IP>:5050`).
3. Flash to your respective ESP32 boards.

---

## 📜 Intellectual Property & Patents

This project includes a complete patent application draft formulated under the **Indian Patents Act, 1970 (Form 2)**:
- **Core Inventive Step:** Non-destructive retrofit enclosure combining optical anti-fog baffle geometry, synchronized non-thermal flash pulsing, and load-cell + ultrasonic edge-fusion state classification.
- See [`FINAL_PATENT_APPLICATION_SPECIFICATION.md`](FINAL_PATENT_APPLICATION_SPECIFICATION.md) for the full patent claim set and drawings.

---

## 👥 Authors & Academic Context
Developed as an engineering capstone project focusing on sustainable embedded systems, AI on edge IoT, and food waste reduction.
