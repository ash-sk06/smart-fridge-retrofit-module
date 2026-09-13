# SOFTWARE IMPLEMENTATION GUIDE
## Complete Software Pipeline Setup, Firmware Flashing & Laptop AI Server
**System Architecture:** Dual-Zone Visual-Gravimetric Retrofit System  
**Estimated Setup Time:** 1 to 2 Hours | **Cost:** 100% Free / Open Source

---

## 1. SOFTWARE ARCHITECTURE OVERVIEW

The system software consists of four lightweight, decoupled layers:

```
[ ESP32 NodeMCU (Dual Load Cells) ] ──(HTTP POST / JSON)──┐
                                                          ├──► [ Laptop Python Flask Server ]
[ ESP32-CAM (Overhead Flash Strobe) ] ─(HTTP POST / JPEG)─┘            │
                                                                       ├─► YOLOv8n (Inference Engine)
                                                                       ├─► Dual-Zone Depletion Math
                                                                       ├─► SQLite Local Database
                                                                       └─► Web Dashboard (Tailwind UI)
```

1. **Firmware Layer 1 (`software/firmware/esp32_sensor_hub.ino`):**
   * Runs on ESP32 NodeMCU.
   * Reads Load Cell 1 (Dairy) and Load Cell 2 (Drinks) in parallel via two HX711 ADCs sharing clock pin `GPIO 4`.
   * Handles door state interrupts (`GPIO 14`) and enforces the $1.2\text{ s}$ mechanical vibration settling delay.
   * Transmits compact JSON payloads to the laptop: `{"zone1_weight": 795, "zone1_delta": -250, ...}`.
2. **Firmware Layer 2 (`software/firmware/esp32_cam_strobe.ino`):**
   * Runs on the AI-Thinker ESP32-CAM.
   * Triggers the high-power onboard flash LED on `GPIO 4` for a $100\text{ ms}$ strobe in complete darkness.
   * Captures a $640 \times 480$ JPEG image and uploads it via multipart HTTP POST to `/api/upload-image`.
3. **Backend & AI Engine (`software/server.py`):**
   * Runs on your everyday student laptop using Python 3.10+ and Flask.
   * Runs quantized **YOLOv8n** on your laptop CPU (~150 ms inference).
   * Calculates fluid depletion percentages and updates the local SQLite database (`fridge_inventory.db`).
   * Automatically populates the replenishment shopping list when items drop below $20\%$.
4. **Frontend Dashboard (`software/templates/index.html`):**
   * Modern, responsive web application styled with Tailwind CSS.
   * Live environmental telemetry header (Door state, temperature, humidity).
   * Animated circular fill gauges for Zone 1 (Milk) and Zone 2 (Juice).
   * Includes an interactive **Demo Simulator** to test all features even before hardware arrives!

---

## 2. PREREQUISITES & INSTALLATION (ON YOUR LAPTOP)

### Step 1: Install Python & Project Dependencies
Open your terminal (Command Prompt / PowerShell on Windows, or Terminal on Mac):

```bash
# 1. Navigate to the project directory
cd "/Users/ashwathsathish/Library/Mobile Documents/com~apple~CloudDocs/AI Refridgerator Retrofit Module"

# 2. (Optional but recommended) Create a virtual environment
python3 -m venv venv
source venv/bin/activate    # On Mac/Linux
# .\venv\Scripts\activate   # On Windows

# 3. Install all required dependencies
pip install -r software/requirements.txt
```

### Step 2: Install Arduino IDE (For Microcontroller Firmware)
1. Download and install **Arduino IDE 2.x** from [arduino.cc](https://www.arduino.cc/en/software).
2. Add ESP32 Board Support:
   * Go to **File $\rightarrow$ Preferences**.
   * In *Additional Board Manager URLs*, paste:
     `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
   * Go to **Tools $\rightarrow$ Board $\rightarrow$ Boards Manager**, search for `esp32` by *Espressif Systems*, and click **Install**.
3. Install Required Arduino Libraries:
   * Go to **Tools $\rightarrow$ Manage Libraries**.
   * Search and install:
     * `HX711` by *Bogdan Necula*
     * `DHT sensor library` by *Adafruit*

---

## 3. HOW TO RUN & TEST THE SOFTWARE IMMEDIATELY (NO HARDWARE NEEDED!)

You can run and test the complete web dashboard and AI logic on your laptop right now:

1. In your terminal, run:
   ```bash
   cd "software"
   python3 server.py
   ```
2. You will see:
   ```
   =======================================================
     AI REFRIGERATOR RETROFIT SERVER (DUAL-ZONE ENGINE)   
     Access Web Dashboard at: http://localhost:5000       
   =======================================================
   ```
3. Open your web browser and visit: **`http://localhost:5000`**
4. **Try the Interactive Demo Simulator Bar at the top of the dashboard:**
   * Click **"Pour Milk (-250ml)"**: Watch the Milk fill ring drop from 100% to 75% in real time!
   * Click **"Pour Both (-250ml & -100ml)"**: Watch both Milk and Juice gauges drop independently!
   * Click **"Trigger Low Stock (<20%)"**: The Milk gauge turns red, and **"Pasteurized Whole Milk (1L)"** is automatically added to your Smart Shopping List!
   * Click **"Reset 100%"**: Everything resets back to full stock.

This simulator guarantees you can practice and present your software anytime!

---

## 4. FLASHING THE FIRMWARE ONTO THE HARDWARE

### A. Flashing the ESP32 NodeMCU (Sensor Hub)
1. Connect the ESP32 NodeMCU to your laptop using a standard Micro-USB cable.
2. Open `software/firmware/esp32_sensor_hub.ino` in Arduino IDE.
3. Configure your network:
   * Edit lines 17–19 with your Wi-Fi name, password, and your laptop's local IP address:
     ```cpp
     const char* ssid = "YOUR_HOTSPOT_NAME";
     const char* password = "YOUR_PASSWORD";
     const char* serverUrl = "http://192.168.1.100:5000/api/sensor-event";
     ```
4. Select **Tools $\rightarrow$ Board $\rightarrow$ ESP32 Arduino $\rightarrow$ NodeMCU-32S** (or ESP32 Dev Module).
5. Select the correct COM/Serial port under **Tools $\rightarrow$ Port**.
6. Click **Upload**.

---

### B. Flashing the ESP32-CAM (Flash Camera Pod)
The ESP32-CAM does not have an onboard USB port, so use your **FTDI Programmer**:

1. **FTDI to ESP32-CAM Wiring:**
   * FTDI `VCC (5V)` $\rightarrow$ ESP32-CAM `5V`
   * FTDI `GND` $\rightarrow$ ESP32-CAM `GND`
   * FTDI `TX` $\rightarrow$ ESP32-CAM `U0R` (RX)
   * FTDI `RX` $\rightarrow$ ESP32-CAM `U0T` (TX)
   * **CRUCIAL FLASHING JUMPER:** Connect **`GPIO 0` to `GND`** on the ESP32-CAM (this puts the chip into bootloader flashing mode).
2. Open `software/firmware/esp32_cam_strobe.ino` in Arduino IDE.
3. Update lines 27–29 with your Wi-Fi credentials and laptop IP:
   ```cpp
   const char* ssid = "YOUR_HOTSPOT_NAME";
   const char* password = "YOUR_PASSWORD";
   const char* serverUrl = "http://192.168.1.100:5000/api/upload-image";
   ```
4. Under **Tools $\rightarrow$ Board**, select **AI Thinker ESP32-CAM**.
5. Set **Tools $\rightarrow$ Upload Speed** to **115200**.
6. Press the tiny **RST (Reset)** button on the ESP32-CAM.
7. Click **Upload** in Arduino IDE.
8. Once flashing is complete ("Leaving... Hard resetting via RTS pin"):
   * **Disconnect the jumper wire between `GPIO 0` and `GND`**.
   * Press the **RST button** once. The camera will connect to Wi-Fi!

---

## 5. THE "HOTSPOT TRICK" (GUARANTEED CONNECTIVITY IN COLLEGE)

> [!TIP]
> **College Wi-Fi Warning:**  
> University Wi-Fi networks often have "client isolation" enabled, which blocks ESP32 devices from talking to laptops.
> 
> **The Solution:**  
> Turn on the **Personal Hotspot** on any team member's smartphone. Connect both the laptop and the two ESP32 modules to this smartphone hotspot.
> * This creates a dedicated local subnet (e.g., `192.168.43.x`).
> * It works 100% reliably anywhere—in your dorm, lab, or during your faculty review!

---

## 6. END-TO-END DEMONSTRATION WORKFLOW

1. Turn on your mobile hotspot.
2. Power the ESP32 and ESP32-CAM (using a USB power bank or 5V phone chargers).
3. On your laptop, run `python3 software/server.py` and open `http://localhost:5000`.
4. Open the mock fridge door (reed switch separates $\rightarrow$ Dashboard shows "DOOR OPEN").
5. Pour water out of the milk bottle on Zone 1.
6. Close the door (reed switch touches):
   * ESP32 waits $1.2\text{ s}$ settling delay.
   * ESP32-CAM pulses its flash LED in the dark box and uploads the photo.
   * ESP32 sends the settled weights to the laptop.
7. Within 1 second, the laptop dashboard updates with the new fill percentage and volume!
