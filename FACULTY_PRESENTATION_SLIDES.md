# FACULTY PRESENTATION DECK: AI REFRIGERATOR DUAL-ZONE RETROFIT MODULE
## Innovative Design Project (IDP) — 2nd Year Undergraduate Engineering
**Duration:** 7–10 Minutes | **Style:** Minimal, High-Impact, Technical

---

### SLIDE 1: TITLE SLIDE
* **Project Title:**  
  **An Event-Gated Dual-Zone Differential Gravimetric & Optical Retrofit Module for Domestic Refrigerators**
* **Project Type:** 2nd-Year Innovative Design Project (IDP) / Prototype & Patent Track
* **Team Members:**  
  1. [Student Name 1] — AI & Vision Subsystem
  2. [Student Name 2] — Embedded Hardware & Sensors
  3. [Student Name 3] — Backend Server & Dashboard UI
* **Faculty Guide:** Prof. [Guide Name]
* **Department:** Department of [Computer Science / Electronics Engineering]

---

### SLIDE 2: THE PROBLEM (WHY EXISTING SMART FRIDGES FAIL)
* **The Reality:** Factory-integrated smart refrigerators (Samsung Family Hub, LG InstaView) cost ₹1.5L to ₹3.0L, locking out 95% of consumers who own conventional refrigerators.
* **The Fatal Technical Blindspots:**
  1. **The "Opaque Container Blindspot":** Cameras cannot see fluid levels inside opaque plastic milk jugs, tetra-paks, or juice cartons. They know the bottle exists, but have **zero knowledge of remaining volume**.
  2. **The "Cold Drift" Problem:** Piezoresistive load cells drift by **50g to 80g** in a 4°C cold environment, causing false readings.
  3. **The "Lens Fogging" Problem:** Opening a fridge in humid Indian climates immediately condenses moisture onto cold camera lenses.
  4. **The "Multi-Liquid Ambiguity":** A single scale cannot mathematically isolate simultaneous usage across multiple fluid containers ($x + y = \Delta W$).

---

### SLIDE 3: OUR PROPOSED SOLUTION
* **Concept:** A low-cost (< ₹2,000), non-invasive **Dual-Zone Smart Tray Insert** and an **Overhead Flash Optical Pod** that retrofits inside any existing refrigerator.
* **How It Works:**
  * Sits flat on any standard wire or glass shelf with zero structural modifications.
  * Captures post-transit settled weight and synchronized flash imagery inside the closed, light-sealed refrigerator.
  * Relays lightweight telemetry over local Wi-Fi to a student laptop running local edge AI (YOLOv8n).
  * Continuously displays remaining fluid percentages on a modern web dashboard and auto-generates grocery shopping lists.

---

### SLIDE 4: SENSOR MATRIX (WHAT WE USE & EXACTLY WHAT FOR)

| Sensor / Component | Exact Model | Physical Placement | Purpose & Function |
|---|---|---|---|
| **Dual Load Cells** | 2x 5kg Straight-Bar Strain Gauges | Under Zone 1 & Zone 2 Cantilever Plates | Measures mass changes ($\pm 1\text{g}$) independently for Dairy vs. Beverages |
| **ADC Amplifiers** | 2x HX711 (24-bit ADCs) | Shared Clock Bus on Base Plate | Amplifies microvolt differential signals with 10-sample median noise filtering |
| **Door State Sensor** | MC-38 Magnetic Reed Switch | Refrigerator Door Frame & Liner | Triggers pre-access baseline tare latch and post-closure acquisition sequence |
| **Overhead Camera** | OV2640 2MP (ESP32-CAM) | Interior Ceiling (Suction Pod) | Captures 120° wide-angle top-down frame for YOLOv8n object bounding boxes |
| **Active Strobe** | High-Power White Flash LED | Integrated on Camera Pod (GPIO 4) | Fires 100ms flash in closed darkroom compartment (eliminates ambient shadows) |
| **Micro-Climate** | DHT11 / DHT22 Sensor | Interior Compartment Wall | Logs ambient internal temperature and relative humidity |

---

### SLIDE 5: SYSTEM ARCHITECTURE & DATA FLOW
```
[ DOOR OPENS ]   ──► Reed Switch Trips ──► Latch Baseline Tare: W0_dairy & W0_drinks
       │
[ USER ACCESS ]  ──► Pours milk from Zone 1 and/or juice from Zone 2
       │
[ DOOR CLOSES ]  ──► Reed Switch Contacts Close
       │
       ├─► 1.2s Mechanical Settling Delay (Liquid sloshing & vibration dampens)
       ├─► Enclosed Flash Strobe fires (100ms) ──► Camera captures frame (I1)
       └─► Dual HX711s sample settled masses ──► Reads W1_dairy & W1_drinks
       │
(HTTP POST over Wi-Fi / Hotspot)
       ▼
[ LAPTOP SERVER ] ──► YOLOv8n verifies container categories & zone coordinates
                  ──► Calculates: Volume = (W1 - W_tare) / Density
                   ──► Updates SQLite Database
                   ──► Pushes live telemetry to Web Dashboard & Flutter Mobile Companion App (Android/iOS)
```

---

### SLIDE 6: THE FOUR PATENTABLE INNOVATIONS (THE CORE DEFENSE)
*To overcome Section 3(f) [Mere Aggregation] and Section 3(k) [Software per se] of the Indian Patents Act, 1970, our patent claims protect four physical-mechanical mechanisms:*

1. **Dual-Zone Split Cantilever Platform (Claim 1 & 6):**  
   Two independent cantilever plates separated by a $2\text{ mm}$ air gap. Eliminates multi-liquid ambiguity ($x + y = \Delta W$) with 100% mathematical certainty at just ₹160 extra cost.
2. **Event-Gated Differential Tare Latch (Claim 2):**  
   Latching $W_0$ at the door-open transition and subtracting it from $W_1$ post-closure cancels long-term piezoresistive thermal drift across the brief 10-second access window:
   $$\Delta W = W_1 - W_0 = (W_{\text{new}} + \text{Drift}) - (W_{\text{old}} + \text{Drift}) = W_{\text{new}} - W_{\text{old}}$$
3. **Passive Parasitic-Heat Anti-Condensation Pod (Claim 3):**  
   Continuous standby heat ($0.26\text{W}$) from the ESP32 microcontroller is thermally coupled via a copper spreader to the optical aperture window, keeping it above the dew point and preventing lens fogging with **zero active heaters and zero extra power**.
4. **Non-Invasive Opaque Liquid Quantification (Claim 4 & 5):**  
   Couples visual bounding-box persistence with load cell mass delta ($\Delta W < 0$) to compute remaining fluid volume without requiring internal immersion probes or container transparency.

---

### SLIDE 7: MULTI-LIQUID DISAMBIGUATION (HERO DEMO FEATURE)
* **The Scenario:** Milk (1000 mL) on Zone 1; Orange Juice (500 mL) on Zone 2. User drinks from both simultaneously.
* **Why Single Scales Fail:** A single load cell records $-350\text{g}$, but cannot determine whether Milk lost 250g and Juice lost 100g, or vice versa.
* **Our Dual-Zone Solution:**
  * **Zone 1 (Dairy Cantilever):** Directly registers $\Delta W_1 = -250\text{g} \implies \text{Milk drops } 100\% \to 75\% \text{ (750 mL)}$.
  * **Zone 2 (Drinks Cantilever):** Directly registers $\Delta W_2 = -100\text{g} \implies \text{Juice drops } 100\% \to 80\% \text{ (400 mL)}$.
  * Independent parallel sampling via shared clock line (`GPIO 4`) ensures zero crosstalk.

---

### SLIDE 8: BILL OF MATERIALS (BOM) — STRICTLY UNDER ₹2,000

| Component | Quantity | Sourcing | Cost (INR) |
|---|---|---|---|
| ESP32-CAM (AI-Thinker OV2640) | 1 pc | Robu.in | ₹540 |
| ESP32 NodeMCU (30-pin) | 1 pc | Robu.in | ₹290 |
| 5kg Straight-Bar Load Cells | 2 pcs | ElectronicsComp | ₹320 (₹160 x 2) |
| HX711 24-bit ADC Modules | 2 pcs | Robu.in | ₹140 (₹70 x 2) |
| MC-38 Magnetic Door Reed Switch | 1 set | Robu.in | ₹85 |
| DHT11 Temperature & Humidity Sensor | 1 pc | Robu.in | ₹90 |
| 3mm White Acrylic Plates (1 Base, 2 Top Trays) | 3 pcs | Local Acrylic Shop | ₹220 |
| FTDI Programmer + Screws + Jumpers | - | Robu.in / Local Hardware | ₹260 |
| **TOTAL HARDWARE BUDGET:** | | | **₹1,945** |

*Compute Cost:* ₹0 (Utilizes student laptop over local Wi-Fi / Hotspot).

---

### SLIDE 9: SOFTWARE ARCHITECTURE & 5-MINUTE LIVE DEMO

#### Software Stack (100% Free & Open-Source)
* **Firmware:** Arduino C++ (ESP32 parallel reading + ESP32-CAM strobe upload).
* **AI & Backend:** Python 3.10, Flask REST API, YOLOv8n CPU inference (~150ms), SQLite3 local database.
* **Dashboard:** Responsive Tailwind CSS web UI running locally on laptop (`http://localhost:5000`).

#### 5-Minute Demonstration Script for Review:
1. **Minute 1:** Show empty smart tray ($0\text{g}$ baseline, temp 4.1°C, door CLOSED).
2. **Minute 2:** Add full 1L Milk Bottle $\rightarrow$ Dashboard displays 100% Full (1000 mL).
3. **Minute 3:** Add full 500mL Juice Bottle $\rightarrow$ Dashboard displays Zone 2 at 100% Full (500 mL).
4. **Minute 4:** Pour $250\text{mL}$ from Milk and $100\text{mL}$ from Juice simultaneously $\rightarrow$ Both fill rings drop independently in real time!
5. **Minute 5:** Pour milk below 20% $\rightarrow$ Milk gauge turns red (LOW STOCK) and auto-populates the Smart Shopping List!

---

### SLIDE 10: DELIVERABLES & REVIEW 1 CONCLUSION
* **Current Status:**
  * Complete mechanical blueprints and 3-pin wiring schematics finalized.
  * Working software repository built: Flask backend, SQLite database, Tailwind dashboard, and Arduino firmware ready.
  * Form 2 Complete Patent Specification drafted (8 claims, 5 figure descriptions).
* **Next Milestones for Review 2:**
  * Mechanical fabrication of the dual-zone acrylic cantilever tray.
  * Logging 24-hour thermal drift cancellation plots for official patent submission.
  * Submission of Provisional Patent Application (Form 1 & Form 2, ₹1,600) via the University IPR Cell.
* **Thank You! Open for Questions.**
