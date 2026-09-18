# PRACTICAL BUILD & ASSEMBLY MANUAL
## AI Refrigerator Dual-Zone Retrofit Module (2nd-Year IDP Implementation Guide)
**System Architecture:** Dual-Zone Split-Cantilever Smart Tray (2x 5kg Load Cells + 2x HX711)  
**Target Budget:** ₹1,800 – ₹2,300 | **Build Time:** 2–3 Weeks

---

## 1. COMPLETE BILL OF MATERIALS (WHAT TO BUY)

### A. Electronics & Sensors
| Component | Specification | Purpose | Indian Source | Cost (INR) |
|---|---|---|---|---|
| **ESP32-CAM** | AI-Thinker Module with Upgraded OV3660 3MP Camera | Overhead vision capture & synchronized flash strobe | Robu.in / ElectronicsComp | ₹550 – ₹650 |
| **Programmer / Cable**| ESP32-CAM-MB Micro-USB Shield or Type-C Cable | Flashing code onto ESP32-CAM | Robu.in / Amazon | ₹100 – ₹180 |
| **ESP32 Micro-Hub** | ESP32-S2-DevKitM-1 (240MHz Xtensa LX7, 2.4GHz Wi-Fi) | High-speed dual HX711, reed switch & DHT reader | Robu.in | ₹290 – ₹350 |
| **Scale Kits (2x)** | 2x Pre-Fabricated 5kg Cantilever Scale Kits with HX711 ADCs | Pre-bolted cantilever beams with pre-soldered 24-bit ADCs | Robu.in / Amazon | ₹480 – ₹580 (₹240–₹290 x 2) |
| **Door Switch** | MC-38 Magnetic Reed Switch with Magnet | Detects door opening and closing events | Robu.in | ₹75 – ₹95 |
| **Temperature Sensor**| DHT11 or DHT22 Module | Internal compartment temperature & humidity | Robu.in | ₹85 – ₹120 |
| **Jumper Wires** | Female-to-Female DuPont Jumpers (20cm) | Circuit interconnects from HX711 to ESP32-S2 | Local / Robu.in | ₹80 – ₹100 |
| **USB Cables** | 2x Micro-USB / Type-C cables | Powering ESP32 boards from laptop or 5V USB | Already available | ₹0 |

### B. Mechanical & Hardware Materials
| Item | Specification | Purpose | Source | Cost (INR) |
|---|---|---|---|---|
| **Base Acrylic Plate** | 1 piece of 3mm White/Clear Acrylic ($24 \times 16\text{ cm}$) | Bottom stationary base plate resting on shelf | Local acrylic / framing shop | ₹120 – ₹150 |
| **Dual Top Plates** | 2 pieces of 3mm White/Clear Acrylic ($11.5 \times 16\text{ cm}$) | Zone 1 (Dairy) & Zone 2 (Drinks) independent trays (2mm gap) | Local acrylic / framing shop | ₹120 – ₹150 |
| **Fasteners / Tape** | 3M VHB Double-Sided Foam Tape or M4/M5 screws | Securing scale kits to base and top trays | Hardware / Amazon | ₹50 – ₹80 |
| **Silicone Feet** | 4x self-adhesive rubber/silicone bumper pads | Anti-vibration feet for base plate | Hardware / Amazon | ₹40 – ₹60 |
| **Suction Mounts** | 2x medium heavy-duty suction cups with hooks | Fastening camera pod to fridge ceiling | Local utility store | ₹30 – ₹50 |
| **Cardboard Box** | Standard shipping box (~$35 \times 25 \times 30\text{ cm}$) | Mock refrigerator enclosure for lab testing | Any delivery box | ₹0 |
| **TOTAL ESTIMATED COST:** | | | | **₹1,940 – ₹2,470** |

---

## 2. MECHANICAL DUAL-ZONE ASSEMBLY (STEP-BY-STEP)

```
                    DUAL-ZONE SPLIT TRAY (TOP VIEW)
+══════════════════════════════════════════════════════════════════════+
║ BASE PLATE: Fixed Acrylic Sheet (24 cm x 16 cm) resting on shelf     ║
║                                                                      ║
║   +──────────────────────────+  2mm  +──────────────────────────+   ║
║   │ ZONE 1: TRAY A (DAIRY)   │  GAP  │ ZONE 2: TRAY B (DRINKS)  │   ║
║   │ (11.5 cm x 16 cm Plate)  │       │ (11.5 cm x 16 cm Plate)  │   ║
║   │                          │       │                          │   ║
║   │       [ MILK BOTTLE ]    │       │     [ JUICE BOTTLE ]     │   ║
║   │                          │       │                          │   ║
║   +─────────────┬────────────+       +────────────┬─────────────+   ║
║                 │                                 │                 ║
║         Load Cell 1 (5kg)                 Load Cell 2 (5kg)         ║
║                 │                                 │                 ║
║                 └────────► [ HX711 / ESP32 ] ◄────┘                 ║
+══════════════════════════════════════════════════════════════════════+

                       SIDE ELEVATION OF EACH ZONE
  
    [  FOOD ITEM (e.g. Milk)  ]
                 │
    +════════════╪══════════════════════════════════════════════+  <-- TOP PLATE (11.5 x 16 cm)
    +────────────╪──────────────────────────────────────────────+
                 │
           (2x M5 Screws)
                 │
           +─────┴──────────────────────+
           │  5kg Straight Bar Load Cell │  <── (Arrow on label pointing DOWN)
           +──────────────────────┬─────+
                                  │
                             (2x M4 Screws)
                                  │
                           +──────┴──────+  <-- Acrylic Riser Block (10mm thick)
    +══════════════════════╪═════════════╧══════════════════════+
    +──────────────────────╪────────────────────────────────────+  <-- SHARED BASE PLATE (24 x 16 cm)
        [Silicone Pad]                            [Silicone Pad]
```

### Step 1: Prepare the Acrylic Plates
1. Go to any local acrylic, sign-board, or photo-framing shop.
2. Get **three pieces of 3mm white acrylic**:
   * **1x Base Plate:** $24\text{ cm} \times 16\text{ cm}$
   * **2x Top Plates:** $11.5\text{ cm} \times 16\text{ cm}$ each
3. Drill mounting holes:
   * **Base Plate:** Drill four 4.5mm holes (two on the left side for Load Cell 1, two on the right side for Load Cell 2).
   * **Top Plate 1 (Dairy):** Drill two 5.5mm holes at one end for Load Cell 1.
   * **Top Plate 2 (Drinks):** Drill two 5.5mm holes at one end for Load Cell 2.

### Step 2: Mount the Load Cells
1. Check the arrows on both aluminum load cells: **The arrows must point DOWN**.
2. Place a $10\text{ mm}$ spacer block under the anchor end of each load cell.
3. Pass M4 bolts through the base plate and spacer blocks, tightening them into the load cells.
4. Fasten Top Plate 1 to Load Cell 1 using two M5 screws.
5. Fasten Top Plate 2 to Load Cell 2 using two M5 screws.
6. **CRITICAL VERIFICATION:**
   * Ensure there is a **$2\text{ mm}$ gap between Top Plate 1 and Top Plate 2**. They must never touch each other!
   * Ensure there is a **$3\text{ mm}$ to $5\text{ mm}$ air gap between each top plate and the base plate**. Each top plate must float freely on its load cell!
7. Stick 4 rubber silicone feet under the bottom base plate.

### Step 3: Fabricate & Mount the Anti-Fog Camera Pod (2-Part 3D Model)
1. 3D print the **2-Part Anti-Fog Pod** from [`cad/`](file:///Users/ashwathsathish/Library/Mobile%20Documents/com~apple~CloudDocs/AI%20Refridgerator%20Retrofit%20Module/cad/):
   * [`camera_pod_main_body.stl`](file:///Users/ashwathsathish/Library/Mobile%20Documents/com~apple~CloudDocs/AI%20Refridgerator%20Retrofit%20Module/cad/camera_pod_main_body.stl) (Main body with integrated 15mm baffle tube)
   * [`camera_pod_back_lid.stl`](file:///Users/ashwathsathish/Library/Mobile%20Documents/com~apple~CloudDocs/AI%20Refridgerator%20Retrofit%20Module/cad/camera_pod_back_lid.stl) (Snap lid with dual 10mm magnet sockets)
2. Drop a $25\text{ mm} \times 25\text{ mm}$ clear 2mm acrylic square into the internal pocket behind the baffle.
3. Attach a folded aluminum foil ribbon to the ESP32-CAM metal RF shield and route it to touch the edge of the acrylic window (Parasitic Thermal Bridge — Patent Claim 3).
4. Slide the ESP32-CAM PCB into the internal guide rails and place a 1g silica gel sachet in the lower desiccant bay.
5. Buff the outer acrylic face with a trace of dish soap (surfactant monolayer), press two 10mm Neodymium magnets into the rear sockets, and snap the lid shut.
6. Magnetically attach the pod to the refrigerator ceiling or wire shelf frame ($22\text{--}25\text{ cm}$ directly above the dual tray).
7. Mount the MC-38 reed switch: stationary switch on the frame, moving magnet on the door edge (within $5\text{ mm}$ when closed).

---

## 3. ELECTRICAL WIRING (DUAL LOAD CELLS + SHARED CLOCK)

Using two HX711 modules sharing the clock line requires only **3 GPIO pins** on the ESP32:

```
[Load Cell 1 (Milk)]  ──► [HX711 #1] ──► DT to GPIO 16 ──┐
                                     ──► SCK to GPIO 4  ──┼──► [ESP32 NodeMCU]
[Load Cell 2 (Juice)] ──► [HX711 #2] ──► DT to GPIO 17 ──┤
                                     ──► SCK to GPIO 4  ──┘ (Shared Clock Pin!)
```

### Complete Pin-to-Pin Table:

| Component & Pin | ESP32 GPIO Pin | Function / Description |
|---|---|---|
| **HX711 #1 VCC & GND** | **3.3V & GND** | Power for Zone 1 (Dairy) |
| **HX711 #1 DT (Data)** | **GPIO 16** | 24-bit Data for Zone 1 (Milk) |
| **HX711 #1 SCK (Clock)**| **GPIO 4** | Shared Clock Pulse for both ADCs |
| **HX711 #2 VCC & GND** | **3.3V & GND** | Power for Zone 2 (Beverages) |
| **HX711 #2 DT (Data)** | **GPIO 17** | 24-bit Data for Zone 2 (Juice) |
| **HX711 #2 SCK (Clock)**| **GPIO 4** | Shared Clock Pulse (Connected to same GPIO 4!) |
| **MC-38 Reed Switch** | **GPIO 14 & GND** | Door state (Configured as `INPUT_PULLUP`) |
| **DHT11 Sensor** | **GPIO 27, 3.3V, GND** | Compartment temperature & relative humidity |

#### Load Cell Wire Color Code to HX711:
* **RED** $\rightarrow$ `E+`
* **BLACK** $\rightarrow$ `E-`
* **WHITE** $\rightarrow$ `A-`
* **GREEN** $\rightarrow$ `A+`

---

## 4. COMPLETE SOFTWARE IMPLEMENTATION

### Step 1: Calibrate Both Load Cells (ESP32 Arduino Code)
```cpp
#include "HX711.h"

// Zone 1: Dairy (Milk)
HX711 scale_dairy;
const int DT_DAIRY = 16;

// Zone 2: Drinks (Juice)
HX711 scale_drinks;
const int DT_DRINKS = 17;

const int SCK_PIN = 4; // Shared clock line

void setup() {
  Serial.begin(115200);
  scale_dairy.begin(DT_DAIRY, SCK_PIN);
  scale_drinks.begin(DT_DRINKS, SCK_PIN);

  // Calibration factors determined using a known 500g water bottle
  scale_dairy.set_scale(420.0);  // Adjust for Zone 1
  scale_drinks.set_scale(415.0); // Adjust for Zone 2

  scale_dairy.tare();
  scale_drinks.tare();
  Serial.println("Dual-Zone Smart Tray Ready! Place 500g weight on each zone to verify.");
}

void loop() {
  float milk_weight = scale_dairy.get_units(5);
  float juice_weight = scale_drinks.get_units(5);

  Serial.print("Zone 1 (Dairy): ");
  Serial.print(milk_weight, 1);
  Serial.print(" g  |  Zone 2 (Drinks): ");
  Serial.print(juice_weight, 1);
  Serial.println(" g");
  delay(500);
}
```

### Step 2: Complete Event-Gated Dual-Zone Firmware
```cpp
#include "HX711.h"
#include <WiFi.h>
#include <HTTPClient.h>

const int REED_PIN = 14;
const int DT_DAIRY = 16;
const int DT_DRINKS = 17;
const int SCK_PIN = 4;

HX711 scale_dairy;
HX711 scale_drinks;

float W0_dairy = 0.0;
float W0_drinks = 0.0;
bool wasDoorOpen = false;

const char* ssid = "YourWiFiOrHotspot";
const char* password = "YourPassword";
const char* serverUrl = "http://192.168.1.100:5000/api/sensor-event"; // Laptop IP

void setup() {
  Serial.begin(115200);
  pinMode(REED_PIN, INPUT_PULLUP);

  scale_dairy.begin(DT_DAIRY, SCK_PIN);
  scale_drinks.begin(DT_DRINKS, SCK_PIN);
  scale_dairy.set_scale(420.0);
  scale_drinks.set_scale(415.0);
  scale_dairy.tare();
  scale_drinks.tare();

  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi Connected!");
}

void loop() {
  int doorState = digitalRead(REED_PIN); // HIGH = OPEN, LOW = CLOSED

  if (doorState == HIGH && !wasDoorOpen) {
    // PHASE 1: DOOR OPENED -> Latch baseline tare weights instantly
    wasDoorOpen = true;
    W0_dairy = scale_dairy.get_units(5);
    W0_drinks = scale_drinks.get_units(5);
    Serial.println("Door OPENED. Latched W0_Dairy=" + String(W0_dairy) + "g, W0_Drinks=" + String(W0_drinks) + "g");
  } 
  else if (doorState == LOW && wasDoorOpen) {
    // PHASE 2: DOOR CLOSED -> Wait 1.2s damping delay, then sample settled weights
    wasDoorOpen = false;
    Serial.println("Door CLOSED. Waiting 1.2s damping delay...");
    delay(1200); // Mechanical settling delay

    float W1_dairy = scale_dairy.get_units(10);
    float W1_drinks = scale_drinks.get_units(10);

    float delta_dairy = W1_dairy - W0_dairy;
    float delta_drinks = W1_drinks - W0_drinks;

    Serial.println("Settled Dairy: " + String(W1_dairy) + "g (Delta: " + String(delta_dairy) + "g)");
    Serial.println("Settled Drinks: " + String(W1_drinks) + "g (Delta: " + String(delta_drinks) + "g)");

    sendDualZoneTelemetry(W1_dairy, delta_dairy, W1_drinks, delta_drinks);
  }
  delay(100);
}

void sendDualZoneTelemetry(float w_dairy, float d_dairy, float w_drinks, float d_drinks) {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    http.begin(serverUrl);
    http.addHeader("Content-Type", "application/json");

    String json = "{\"zone1_weight\":" + String(w_dairy) +
                  ",\"zone1_delta\":" + String(d_dairy) +
                  ",\"zone2_weight\":" + String(w_drinks) +
                  ",\"zone2_delta\":" + String(d_drinks) + "}";

    int httpCode = http.POST(json);
    Serial.println("HTTP POST Response: " + String(httpCode));
    http.end();
  }
}
```

### Step 3: Laptop Backend (Python Flask + YOLOv8n)
Install dependencies on your laptop:
```bash
pip install flask opencv-python ultralytics requests
```

Create `server.py` on your laptop:
```python
from flask import Flask, request, jsonify, render_template_string
from ultralytics import YOLO
import cv2
import numpy as np

app = Flask(__name__)
model = YOLO('yolov8n.pt') # Lightweight local model running on CPU

# Active dual-zone inventory
inventory = {
    "zone1_dairy": {
        "item_name": "Pasteurized Cow Milk (1L)",
        "current_weight_g": 1045.0,
        "tare_g": 45.0,
        "full_liquid_g": 1000.0,
        "fill_percentage": 100.0,
        "volume_ml": 1000.0,
        "status": "OPTIMAL"
    },
    "zone2_drinks": {
        "item_name": "Fresh Orange Juice (500ml)",
        "current_weight_g": 530.0,
        "tare_g": 30.0,
        "full_liquid_g": 500.0,
        "fill_percentage": 100.0,
        "volume_ml": 500.0,
        "status": "OPTIMAL"
    },
    "shopping_list": []
}

@app.route('/api/sensor-event', methods=['POST'])
def sensor_event():
    data = request.json
    d_dairy = data.get('zone1_delta', 0.0)
    w_dairy = data.get('zone1_weight', 0.0)
    d_drinks = data.get('zone2_delta', 0.0)
    w_drinks = data.get('zone2_weight', 0.0)

    print(f"[*] Zone 1 (Dairy): W={w_dairy}g, Delta={d_dairy}g | Zone 2 (Drinks): W={w_drinks}g, Delta={d_drinks}g")

    # Update Zone 1 (Milk)
    if d_dairy < -15.0: # Fluid consumed
        rem_milk = max(0.0, w_dairy - inventory['zone1_dairy']['tare_g'])
        pct_milk = min(100.0, (rem_milk / inventory['zone1_dairy']['full_liquid_g']) * 100.0)
        inventory['zone1_dairy']['current_weight_g'] = w_dairy
        inventory['zone1_dairy']['volume_ml'] = round(rem_milk, 1)
        inventory['zone1_dairy']['fill_percentage'] = round(pct_milk, 1)
        if pct_milk < 20.0:
            inventory['zone1_dairy']['status'] = "LOW_STOCK"
            if "Milk (1L)" not in inventory['shopping_list']:
                inventory['shopping_list'].append("Milk (1L)")

    # Update Zone 2 (Juice)
    if d_drinks < -15.0: # Fluid consumed
        rem_juice = max(0.0, w_drinks - inventory['zone2_drinks']['tare_g'])
        pct_juice = min(100.0, (rem_juice / inventory['zone2_drinks']['full_liquid_g']) * 100.0)
        inventory['zone2_drinks']['current_weight_g'] = w_drinks
        inventory['zone2_drinks']['volume_ml'] = round(rem_juice, 1)
        inventory['zone2_drinks']['fill_percentage'] = round(pct_juice, 1)
        if pct_juice < 20.0:
            inventory['zone2_drinks']['status'] = "LOW_STOCK"
            if "Orange Juice (500ml)" not in inventory['shopping_list']:
                inventory['shopping_list'].append("Orange Juice (500ml)")

    return jsonify({"status": "success", "inventory": inventory})

@app.route('/')
def dashboard():
    return jsonify(inventory)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
```

---

## 5. 3-WEEK EXECUTION SCHEDULE FOR YOUR TEAM

* **Week 1 (Mechanical Dual-Zone Fabrication - Member 2):**
  * Cut 1 base plate ($24 \times 16\text{ cm}$) and 2 top plates ($11.5 \times 16\text{ cm}$).
  * Mount the two 5kg load cells with spacers, verifying the $2\text{ mm}$ center gap.
  * Wire both HX711s to the ESP32 and calibrate using a 500 mL water bottle.
* **Week 2 (Firmware & Camera Setup - Member 1 & 2):**
  * Wire the MC-38 reed switch. Verify door open latches $W_0$ and door close latches $W_1$ after $1.2\text{ s}$.
  * Flash the ESP32-CAM using the FTDI programmer. Test flash capture in a dark box.
* **Week 3 (Flask Backend & Web UI - Member 3):**
  * Write the Flask server on the laptop to receive HTTP POST payloads.
  * Test simultaneous consumption (pour from both bottles) and verify independent fill gauge drops.
  * Rehearse the 5-minute live demonstration script for your faculty.
