# Smart Fridge Retrofit: Mobile Companion App (Flutter)
**Project:** AI Refrigerator Retrofit Module Using Multi-Sensor Fusion  
**Framework:** Flutter (Material 3)  
**Supported Platforms:** Android, iOS, Web (Chrome)

---

## 1. Features Overview

* **Real-Time Dual-Zone Fill Gauges:** Live animated liquid gradient bars showing milliliters ($ml$) and percentage ($%$) remaining for milk (Zone 1) and orange juice (Zone 2).
* **Dynamic Low-Stock Warnings:** Color-coded indicators:
  * **Green (Optimal):** $\ge 45\%$ fill
  * **Amber (Moderate):** $20\% - 44\%$ fill
  * **Red (Low Stock):** $< 20\%$ fill (triggers auto-shopping list insertion)
* **Live Environmental Telemetry:** Real-time monitoring of internal fridge temperature ($^\circ\text{C}$), relative humidity ($\% \text{RH}$), and door state (`OPEN` / `CLOSED`).
* **Overhead Vision AI Feed:** Displays the latest snapshot taken by the ESP32-CAM when the door was last closed, along with YOLOv8 detection tags (`bottle (Dairy)`, etc.).
* **Smart Automated Grocery List:** Automatically populates when liquid drops below $20\%$. Features interactive checkboxes to cross off items while shopping.
* **Faculty Review Demo Sandbox:** Floating action button with one-tap simulated events ("Pour 150ml Milk", "Toggle Door Event", "Trigger Low Stock Alert") to demonstrate dynamic UI updates during viva/reviews even without hardware powered on.

---

## 2. Quick Start: Running the App

### Step 1: Start Your Flask Backend on Your Laptop
In your terminal, launch the server:
```bash
cd "/Users/ashwathsathish/Library/Mobile Documents/com~apple~CloudDocs/AI Refridgerator Retrofit Module/software"
python3 server.py
```
Find your laptop's local IP address:
* **macOS / Linux:** Run `ifconfig | grep "inet "` (look for `192.168.x.x` or `10.x.x.x`).
* **Windows:** Run `ipconfig` (look for `IPv4 Address`).

### Step 2: Open & Run the Flutter App
Make sure your phone and laptop are on the **same Wi-Fi network or Mobile Hotspot**.

#### Option A: Run Directly on Your Android Phone (USB Debugging)
1. Enable **Developer Options** and **USB Debugging** on your Android phone.
2. Connect your phone to your laptop via USB cable.
3. Open a terminal in the `mobile_app/` folder:
   ```bash
   cd mobile_app
   flutter pub get
   flutter run
   ```
4. Once the app launches on your phone, tap the **Settings icon** (top right) and enter your laptop's IP address (e.g. `192.168.1.105:5000`).

#### Option B: Run in Chrome / Browser (Zero Phone Setup)
If you don't have an Android device plugged in, you can run the app directly in your desktop browser:
```bash
cd mobile_app
flutter pub get
flutter run -d chrome
```

#### Option C: Build the Standalone Android APK (To Share With Teammates)
To generate an installable `.apk` file:
```bash
cd mobile_app
flutter build apk --release
```
The installable APK will be created at:  
`mobile_app/build/app/outputs/flutter-apk/app-release.apk`  
You can send this APK to your teammates via WhatsApp or Google Drive and install it on any Android phone!

---

## 3. Directory Structure

```
mobile_app/
├── pubspec.yaml               # Flutter package configuration
├── README.md                  # This build & user guide
└── lib/
    ├── main.dart              # App entry point with Material 3 theme
    ├── models/
    │   └── inventory_model.dart  # Parsers for inventory, telemetry & shopping list
    ├── services/
    │   └── api_service.dart      # HTTP REST client communicating with Flask
    ├── widgets/
    │   ├── liquid_gauge_card.dart  # Animated liquid progress bar & metrics
    │   ├── telemetry_header.dart   # Live door, temp & humidity status
    │   ├── shopping_list_card.dart # Automated grocery list with checkboxes
    │   └── camera_vision_card.dart # ESP32-CAM overhead photo & YOLO tags
    └── screens/
        └── home_screen.dart       # Main dashboard with auto-polling & demo sandbox
```

---

## 4. Viva / Review Demonstration Script

When presenting to your faculty guide:
1. **Show the live connection:** Point out the green **"ESP32 HUB LIVE"** pill and the real-time temperature ($4.1^\circ\text{C}$).
2. **Demonstrate liquid depletion:** 
   * Lift a carton off the dual load-cell tray (or tap **"Pour 150ml Milk"** in the Demo Sandbox).
   * Within 2 seconds, watch the **liquid gauge drop** from $1000\text{ ml}$ to $850\text{ ml}$ on your phone in real-time.
3. **Demonstrate the automated trigger:**
   * Tap **"Trigger Low Stock Alert (< 20%)"**.
   * Show how the gauge turns **red**, the status changes to `LOW STOCK`, and the item **instantly appears on the Smart Shopping List** at the bottom of the screen.
4. **Demonstrate the door alarm:**
   * Open the mock fridge door (or tap **"Toggle Door Event"**).
   * Show the header flash yellow/red: **`DOOR OPEN`**.
