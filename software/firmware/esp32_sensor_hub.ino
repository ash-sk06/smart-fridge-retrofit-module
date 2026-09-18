/*
 * AI REFRIGERATOR RETROFIT MODULE - DUAL-ZONE SENSOR HUB
 * Target Board: ESP32-S2-DevKitM-1 (Single-Core Xtensa LX7 @ 240MHz, 2.4GHz Wi-Fi)
 * Arduino IDE Board: "ESP32S2 Dev Module" or "ESP32-S2-DevKitM-1"
 * Hardware: 2x 5kg Pre-Fabricated Cantilever Load Cell Kits with HX711 ADCs, MC-38 Reed Switch, DHT11/DHT22
 */

#include "HX711.h"
#include <WiFi.h>
#include <HTTPClient.h>
#include "DHT.h"

// --- PIN CONFIGURATION (OPTIMIZED FOR ESP32-S2) ---
const int REED_PIN = 14;     // Door Reed Switch (INPUT_PULLUP, other pin to GND)
const int DT_DAIRY = 16;     // HX711 #1 (Dairy Zone 1 Data)
const int DT_DRINKS = 17;    // HX711 #2 (Beverage Zone 2 Data)
const int SCK_PIN = 4;       // Shared Clock Pulse for both HX711s
const int DHT_PIN = 5;       // DHT11/DHT22 Climate Data Pin (Safe GPIO on ESP32-S2)

// --- NETWORK CONFIGURATION ---
const char* ssid = "YOUR_HOTSPOT_OR_WIFI_NAME";
const char* password = "YOUR_HOTSPOT_PASSWORD";
// Set to your laptop's Local IP (Run 'ipconfig' on Windows or 'ifconfig' on Mac)
const char* serverUrl = "http://192.168.1.23:5050/api/sensor-event";

// --- OBJECT INSTANTIATIONS ---
HX711 scale_dairy;
HX711 scale_drinks;
DHT dht(DHT_PIN, DHT11);

// State tracking variables
float W0_dairy = 0.0;
float W0_drinks = 0.0;
bool wasDoorOpen = false;

void setup() {
  Serial.begin(115200);
  pinMode(REED_PIN, INPUT_PULLUP);
  dht.begin();

  // Initialize Dual-Zone Load Cells
  scale_dairy.begin(DT_DAIRY, SCK_PIN);
  scale_drinks.begin(DT_DRINKS, SCK_PIN);

  // Calibrate each zone using a standard 500g water bottle
  scale_dairy.set_scale(420.0);   // Adjust during calibration
  scale_drinks.set_scale(415.0);  // Adjust during calibration

  scale_dairy.tare();
  scale_drinks.tare();
  Serial.println("\n[OK] Dual-Zone Cantilever Scales Initialized and Tared.");

  // Connect to Wi-Fi
  Serial.print("[*] Connecting to Wi-Fi: ");
  Serial.println(ssid);
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\n[OK] Wi-Fi Connected. Node IP: " + WiFi.localIP().toString());
}

void loop() {
  int doorState = digitalRead(REED_PIN); // HIGH = OPEN, LOW = CLOSED

  if (doorState == HIGH && !wasDoorOpen) {
    // PHASE 1: DOOR OPENED -> Latch baseline tare weights immediately
    wasDoorOpen = true;
    W0_dairy = scale_dairy.get_units(5);
    W0_drinks = scale_drinks.get_units(5);
    Serial.println("\n[!] Door OPENED -> Latched W0 (Dairy=" + String(W0_dairy, 1) + "g, Drinks=" + String(W0_drinks, 1) + "g)");
  } 
  else if (doorState == LOW && wasDoorOpen) {
    // PHASE 2: DOOR CLOSED -> Wait 1.2s damping delay for mechanical/liquid settling
    wasDoorOpen = false;
    Serial.println("\n[!] Door CLOSED -> Damping delay (1200ms)...");
    delay(1200); // Wait for liquid sloshing to settle

    // Read settled post-access mass (10-sample median filter)
    float W1_dairy = scale_dairy.get_units(10);
    float W1_drinks = scale_drinks.get_units(10);

    float delta_dairy = W1_dairy - W0_dairy;
    float delta_drinks = W1_drinks - W0_drinks;

    float temp = dht.readTemperature();
    if (isnan(temp)) temp = 4.1; // Default fallback if sensor unplugged

    Serial.println("==================================================");
    Serial.println("  POST-TRANSIT DUAL-ZONE MEASUREMENT ACQUIRED     ");
    Serial.println("  Zone 1 (Dairy): " + String(W1_dairy, 1) + "g (Delta: " + String(delta_dairy, 1) + "g)");
    Serial.println("  Zone 2 (Drinks): " + String(W1_drinks, 1) + "g (Delta: " + String(delta_drinks, 1) + "g)");
    Serial.println("  Compartment Temperature: " + String(temp, 1) + " °C");
    Serial.println("==================================================");

    // Transmit telemetry to Laptop Server
    sendTelemetry(W1_dairy, delta_dairy, W1_drinks, delta_drinks, temp, "CLOSED");
  }

  delay(50);
}

void sendTelemetry(float w_dairy, float d_dairy, float w_drinks, float d_drinks, float temp, String door) {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    http.begin(serverUrl);
    http.addHeader("Content-Type", "application/json");

    String jsonPayload = "{"
      "\"zone1_weight\":" + String(w_dairy, 1) + ","
      "\"zone1_delta\":" + String(d_dairy, 1) + ","
      "\"zone2_weight\":" + String(w_drinks, 1) + ","
      "\"zone2_delta\":" + String(d_drinks, 1) + ","
      "\"temperature\":" + String(temp, 1) + ","
      "\"door\":\"" + door + "\""
    "}";

    int httpCode = http.POST(jsonPayload);
    Serial.println("[*] Telemetry POST Status: " + String(httpCode));
    http.end();
  } else {
    Serial.println("[!] Wi-Fi Disconnected. Telemetry could not be sent.");
  }
}
