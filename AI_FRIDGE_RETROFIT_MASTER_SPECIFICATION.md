# AI Refrigerator Retrofit Module Using Multi-Sensor Fusion
## 2nd-Year IDP Engineering Specification & Patentable Blueprint (Budget: ₹2,000 – ₹3,000)

---

### EXECUTIVE PIVOT SUMMARY (2ND YEAR CONSTRAINTS & REALISTIC BUDGET)
* **Target Budget:** ₹2,000 – ₹3,000 Total (Strictly enforced, actual BOM ~₹1,950).
* **Target Audience:** 2nd-Year Undergraduate Students (Sophomores - 3rd/4th Semester).
* **Architecture:** Dual-Zone Split Cantilever Tray (2x 5kg Load Cells, 2x HX711 ADCs, ESP32 NodeMCU, ESP32-CAM, Laptop Local Server).
* **Core Patentable Contribution:** **"An Event-Gated Dual-Zone Split-Cantilever Smart Tray and Optical Strobe Pod for Independent Multi-Liquid Depletion Tracking in Domestic Refrigerators."**

---

## 1. WHY THIS DIRECTION IS GENUINELY PATENTABLE (YET FEASIBLE FOR 2ND YEARS)

### The Real Problem in Existing Smart Fridges
1. **The "Opaque Container Blindspot":** Smart fridges from Samsung and LG cost ₹1.5 Lakh to ₹3 Lakh and use wide-angle internal cameras. If a user puts an opaque plastic milk bottle or juice carton inside, the camera sees "Milk", but has **zero way of knowing if it has 1000 mL, 200 mL, or is empty**.
2. **The "Multiple Liquids" Ambiguity:** A single scale cannot mathematically isolate two simultaneous fluid changes ($x + y = 250\text{g}$). By introducing an independent **Dual-Zone Split Tray (Zone 1: Dairy, Zone 2: Beverages)**, both liquids are tracked with 100% mathematical certainty.
3. **The Thermal Drift Problem:** In the cold (4°C), strain gauges drift by 50g–80g over hours. Our **Event-Gated Differential Tare Latch** subtracts $W_0$ (door open) from $W_1$ (door close), completely canceling drift over the 10-second access window.
4. **The Lens Fogging Problem:** The camera pod uses parasitic standby heat ($0.26\text{W}$) from the ESP32 to maintain the lens window above the internal dew-point, passively preventing condensation.

---

## 2. HARDWARE BILL OF MATERIALS (BOM) — DUAL-ZONE ARCHITECTURE

All components are readily available on Indian electronics websites (Robu.in, ElectronicsComp.com, QuartzComponents, Amazon India):

| # | Component | Exact Model / Spec | Purpose | Indian Source / Cost (INR) |
|---|---|---|---|---|
| 1 | **Vision & Wireless Microcontroller** | **ESP32-CAM (AI-Thinker Module)** with OV2640 2MP Camera | Overhead vision capture, onboard high-power flash LED, Wi-Fi | ₹520 – ₹580 (Robu.in) |
| 2 | **Sensor Controller** | **ESP32 NodeMCU (30-pin)** | High-precision parallel HX711 reading and door interrupt handling | ₹280 – ₹340 (Robu.in) |
| 3 | **Dual Load Cells** | **2x 5kg Straight-Bar Load Cells** | Measures Zone 1 (Milk) and Zone 2 (Juice) independently ($\pm 1\text{g}$) | ₹320 (₹160 x 2 - ElectronicsComp) |
| 4 | **Dual Load Cell Amplifiers** | **2x HX711 24-bit ADC Modules** | Amplifies microvolt strain signals on shared clock line | ₹140 (₹70 x 2 - Robu.in) |
| 5 | **Door Sensor** | **MC-38 Magnetic Reed Switch** | Detects door open and door close events | ₹75 – ₹95 (Robu.in) |
| 6 | **Environmental Sensor** | **DHT11 Temperature & Humidity Sensor** | Monitors basic fridge temperature (0–50°C) and moisture | ₹85 – ₹110 (Robu.in) |
| 7 | **Dual-Zone Tray Plates** | **3mm Acrylic Sheets (1 Base: $24\times16\text{cm}$, 2 Trays: $11.5\times16\text{cm}$)** | Laser-cut / hand-cut white acrylic with 2mm center gap | ₹200 – ₹250 (Local shop) |
| 8 | **USB Programmer & Cables** | FTDI USB-to-TTL programmer (for ESP32-CAM) + Jumpers | Flashing code and USB power | ₹220 – ₹280 (Robu.in) |
| 9 | **Hardware & Fasteners** | 4x M4 bolts, 4x M5 bolts, nylon spacers, rubber feet | Mechanical assembly of dual cantilever scales | ₹100 – ₹150 (Local hardware) |
| **TOTAL** | | | | **₹1,940 – ₹2,265** |

*(Leaves ₹750+ margin within your ₹3,000 budget for mock-fridge cardboard box and delivery charges!)*

---

## 3. DUAL-ZONE MECHANICAL RETROFIT DESIGN

```
                    MOCK FRIDGE / ACTUAL FRIDGE
+───────────────────────────────────────────────────────────────────+
| CEILING:                                                          |
|   [ESP32-CAM] ──► Built-in Onboard High-Power Flash LED           |
|         │                                                         |
|         ▼ (120° Downward Visual Cone)                             |
|                                                                   |
|   +──────────────────────────+  2mm  +──────────────────────────+ |
|   │ ZONE 1: TRAY A (DAIRY)   │  GAP  │ ZONE 2: TRAY B (DRINKS)  │ |
|   │ (11.5 cm x 16 cm Plate)  │       │ (11.5 cm x 16 cm Plate)  │ |
|   │       [ MILK BOTTLE ]    │       │     [ JUICE BOTTLE ]     │ |
|   +─────────────┬────────────+       +────────────┬─────────────+ |
|         │ (Screwed to end)                  │ (Screwed to end)    |
|      +──┴───────────────────────+        +──┴───────────────────+ |
|      | 5kg Load Cell #1 (Dairy) │        | 5kg Load Cell #2     | |
|      +──┬───────────────────────+        +──┬───────────────────+ |
|         │ (Screwed to base)                 │ (Screwed to base)   |
|   +─────┴───────────────────────────────────┴─────────────────+   |
|   | BOTTOM BASE PLATE: 24 cm x 16 cm Acrylic with Rubber Feet |   |
|   +═══════════════════════════════════════════════════════════+   |
+───────────────────────────────────────────────────────────────────+
     Door Frame: [Magnet]  <───>  [MC-38 Reed Switch on Body]
```

* **Physical Isolation:** The two top plates ($11.5 \times 16\text{ cm}$ each) sit side-by-side separated by a $2\text{ mm}$ air gap. If a bottle on Zone 1 is picked up or poured, Zone 2 experiences zero physical force transfer.
* **Shared Base Plate:** A single $24 \times 16\text{ cm}$ bottom plate rests on any standard refrigerator shelf using 4 non-slip rubber vibration damping feet.

---

## 4. ELECTRICAL WIRING & PIN CONNECTIONS

Using two HX711 modules sharing the clock line requires only **3 GPIO pins** on the ESP32:

| Component & Pin | ESP32 GPIO Pin | Function |
|---|---|---|
| **HX711 #1 VCC & GND** | **3.3V & GND** | Power for Zone 1 (Dairy) |
| **HX711 #1 DT (Data)** | **GPIO 16** | 24-bit Data for Zone 1 (Milk) |
| **HX711 #1 SCK (Clock)**| **GPIO 4** | Shared Clock Pulse |
| **HX711 #2 VCC & GND** | **3.3V & GND** | Power for Zone 2 (Beverages) |
| **HX711 #2 DT (Data)** | **GPIO 17** | 24-bit Data for Zone 2 (Juice) |
| **HX711 #2 SCK (Clock)**| **GPIO 4** | Shared Clock Pulse (Same pin!) |
| **MC-38 Reed Switch** | **GPIO 14 & GND** | Door state (Configured as `INPUT_PULLUP`) |
| **DHT11 Sensor** | **GPIO 27, 3.3V, GND** | Compartment temperature & relative humidity |

---

## 5. SOFTWARE ARCHITECTURE (SIMPLE, RELIABLE, ZERO-COST)

```
[ESP32 Dual Load Cells] ──(Wi-Fi / HTTP Post)──► [Student Laptop (Local Server)]
[ESP32-CAM Image Frame] ──(Wi-Fi / HTTP Post)            │
                                                         ├─► YOLOv8n (Object Detection)
                                                         ├─► Dual-Zone ΔW Depletion Math
                                                         ├─► SQLite Local Database
                                                         └─► Web Dashboard (HTML5/Tailwind)
```

1. **Firmware (Arduino C++):**
   * Reads both HX711 channels in parallel in under $100\text{ ms}$.
   * When door opens $\rightarrow$ records $W_{0,\text{dairy}}$ and $W_{0,\text{drinks}}$.
   * When door closes $\rightarrow$ enforces $1.2\text{ s}$ settling delay $\rightarrow$ triggers ESP32-CAM flash strobe $\rightarrow$ samples $W_{1,\text{dairy}}$ and $W_{1,\text{drinks}}$.
   * Sends JSON payload to laptop over local Wi-Fi:
     ```json
     {"zone1_weight": 795.0, "zone1_delta": -250.0, "zone2_weight": 400.0, "zone2_delta": -100.0}
     ```
2. **Backend (Python Flask running on Student Laptop):**
   * Runs lightweight YOLOv8n locally on CPU (~150ms).
   * Verifies bottle classes: `milk_bottle` in Zone 1, `juice_bottle` in Zone 2.
   * Calculates remaining liquid volumes:
     $$\text{Milk Remaining (mL)} = 795\text{g} - 45\text{g (tare)} = 750\text{mL (75% Full)}$$
     $$\text{Juice Remaining (mL)} = 400\text{g} - 30\text{g (tare)} = 370\text{mL (74% Full)}$$
3. **Frontend Dashboard:**
   * Responsive HTML/JS web dashboard (`http://localhost:5000`) displaying animated fill rings for both liquids and auto-populating the shopping list when either drops below 20%.

---

## 6. THE 5-MINUTE FLAWLESS LIVE DEMONSTRATION SCRIPT

* **Minute 1: Setup & Zero Baseline**  
  Show the dual-zone smart tray inside your mock fridge. Laptop dashboard displays: *Zone 1: 0g, Zone 2: 0g, Temp: 4°C, Door: CLOSED*.
* **Minute 2: Both Bottles Placed on Shelf**  
  Open door. Place 1L Milk on Zone 1 ($1045\text{g}$) and 500mL Juice on Zone 2 ($530\text{g}$). Close door.  
  Flash fires inside the dark box; camera snaps.  
  *Dashboard immediately displays:*  
  * **Zone 1:** Milk Bottle | 1000 mL | 100% Full (Green ring)  
  * **Zone 2:** Orange Juice | 500 mL | 100% Full (Green ring)
* **Minute 3: Adding Solid Produce**  
  Open door. Place an Apple ($160\text{g}$) next to the Juice bottle on Zone 2. Close door.  
  Dashboard updates Zone 2: Total mass $+160\text{g}$, camera identifies Apple. Juice fill remains at 100%.
* **Minute 4: The Hero Feature — Simultaneous Multi-Liquid Depletion**  
  Open door. Take out **both** the Milk bottle and the Juice bottle. Pour $250\text{ mL}$ out of the Milk and $100\text{ mL}$ out of the Juice. Place both back on their respective zones. Close door.  
  Flash fires; camera clicks.  
  *Faculty Explanation:* *"Notice both liquids were consumed simultaneously. Because of our dual-zone cantilever split, Scale 1 registers $\Delta W = -250\text{g}$ and Scale 2 registers $\Delta W = -100\text{g}$ completely independently without mathematical ambiguity!"*  
  * **Milk drops from 100% $\to$ 75% (750 mL)**.  
  * **Juice drops from 100% $\to$ 80% (400 mL)**.
* **Minute 5: Low-Stock Automated Shopping List Trigger**  
  Take another $600\text{ mL}$ from the Milk bottle, bringing it below 20%.  
  Dashboard highlights Zone 1 in red: **"LOW STOCK ALERT: Milk at 15%"** and automatically adds "Milk (1L)" to the on-screen Shopping List!

---

## 7. TEAM OF 3 DIVISION (2ND-YEAR ROLES)

* **Member 1 (Computer Vision & Image Capture):**
  * Configures Python, OpenCV, and YOLOv8n on the laptop.
  * Collects 50–70 images of demo items on both zones under the flash LED.
  * Implements bounding box detection and class classification.
* **Member 2 (Embedded Hardware & Sensors):**
  * Wires the ESP32-CAM, ESP32 NodeMCU, 2x HX711 modules, and 2x load cells.
  * Calibrates both load cells independently using a 500 mL water bottle.
  * Writes Arduino C++ firmware for door interrupts, settling delay, and dual-zone reading.
* **Member 3 (Backend Logic & Web Dashboard):**
  * Writes the Flask backend on the laptop to receive HTTP POST payloads from the ESP32.
  * Implements dual-zone $\Delta W$ depletion math and SQLite database.
  * Builds the responsive HTML/CSS web dashboard with dual progress rings and shopping list.

---

## 8. FINAL PROJECT DEFINITION — FREEZE THIS VERSION

* **Final Project Title:**  
  **IoT-Enabled Dual-Zone Retrofit Smart Tray for Opaque Container Food Inventory and Depletion Tracking in Domestic Refrigerators**
* **Total Project Budget:**  
  **₹1,800 – ₹2,300 (Strictly under ₹3,000)**
* **Target Users & Academic Context:**  
  2nd-Year Undergraduate Innovative Design Project (IDP).
* **Core Technical Problem:**  
  Existing smart refrigerator cameras cannot determine fluid quantity inside opaque containers (milk cartons, juice bottles), while single-scale systems cannot isolate multiple liquids consumed simultaneously.
* **Proposed Solution:**  
  A low-cost retrofit dual-zone smart tray combining two independent 5kg cantilever load cells with an overhead ESP32-CAM flash pod. A door reed switch triggers flash photography and settled tare weighing in a closed refrigerator, relaying data to a laptop server running YOLOv8n to compute real-time container depletion.
* **Core Patentable Innovation:**  
  *A dual-phase door-synchronized visual-gravimetric capture protocol on an independent dual-zone split cantilever tray that isolates steady-state enclosed flash imaging from mechanical load cell vibration damping to calculate non-transparent container fill percentages without internal immersion probes or cross-talk.*
* **Hardware Stack:**  
  ESP32-CAM (OV2640), ESP32 NodeMCU, 2x 5kg straight-bar load cells, 2x HX711 amplifiers, MC-38 magnetic reed switch, DHT11 sensor, 3mm acrylic dual-zone cantilever tray ($24 \times 16\text{ cm}$).
* **Software Stack:**  
  Arduino C++ firmware, Python Flask backend (running locally on student laptop), YOLOv8n / OpenCV, SQLite, HTML5/Tailwind web dashboard.
* **Target Demonstration Items:**  
  1. Milk Bottle (Zone 1 - Dairy)  
  2. Juice Bottle (Zone 2 - Beverages)  
  3. Apple / Orange (Solid produce)  
  4. Bread Packet  
  5. Yogurt / Curd Tub
* **What is Explicitly NOT Being Built:**  
  No Raspberry Pi (saved ₹6,000), no complex theoretical Arrhenius biochemistry equations, no live in-fridge OCR, no multi-tier whole-fridge cameras.
