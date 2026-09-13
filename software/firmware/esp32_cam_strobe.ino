/*
 * AI REFRIGERATOR RETROFIT MODULE - OVERHEAD FLASH CAMERA POD
 * Target Board: AI Thinker ESP32-CAM (OV2640)
 * Function: Enclosed flash strobe & HTTP multipart image upload
 */

#include "esp_camera.h"
#include <WiFi.h>
#include <HTTPClient.h>

// --- PIN DEFINITIONS FOR AI THINKER ESP32-CAM ---
#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27
#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22

#define FLASH_LED_PIN      4  // High-Power Onboard White Flash LED

// --- NETWORK CONFIGURATION ---
const char* ssid = "YOUR_HOTSPOT_OR_WIFI_NAME";
const char* password = "YOUR_HOTSPOT_PASSWORD";
// Set to your laptop's Local IP
const char* serverUrl = "http://192.168.1.23:5050/api/upload-image";

void setup() {
  Serial.begin(115200);
  pinMode(FLASH_LED_PIN, OUTPUT);
  digitalWrite(FLASH_LED_PIN, LOW);

  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sscb_sda = SIOD_GPIO_NUM;
  config.pin_sscb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;
  config.frame_size = FRAMESIZE_VGA; // 640x480 (Ideal for edge YOLO)
  config.jpeg_quality = 12;          // 0-63 (Lower = higher quality)
  config.fb_count = 1;

  // Initialize Camera
  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("[!] Camera init failed with error 0x%x\n", err);
    return;
  }
  Serial.println("[OK] OV2640 Camera Sensor Initialized.");

  // Connect to Wi-Fi
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\n[OK] ESP32-CAM Wi-Fi Connected. IP: " + WiFi.localIP().toString());
}

void captureAndSend() {
  Serial.println("[*] Triggering Enclosed Flash Strobe...");
  digitalWrite(FLASH_LED_PIN, HIGH); // Flash ON
  delay(100);                         // 100ms exposure window

  camera_fb_t *fb = esp_camera_fb_get();
  digitalWrite(FLASH_LED_PIN, LOW);  // Flash OFF

  if (!fb) {
    Serial.println("[!] Camera capture failed!");
    return;
  }

  Serial.printf("[*] Image captured: %d bytes. Uploading to server...\n", fb->len);

  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    http.begin(serverUrl);

    String boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW";
    http.addHeader("Content-Type", "multipart/form-data; boundary=" + boundary);

    String bodyStart = "--" + boundary + "\r\n" +
                       "Content-Disposition: form-data; name=\"image\"; filename=\"capture.jpg\"\r\n" +
                       "Content-Type: image/jpeg\r\n\r\n";
    String bodyEnd = "\r\n--" + boundary + "--\r\n";

    int totalLen = bodyStart.length() + fb->len + bodyEnd.length();
    uint8_t *payload = (uint8_t *)malloc(totalLen);
    memcpy(payload, bodyStart.c_str(), bodyStart.length());
    memcpy(payload + bodyStart.length(), fb->buf, fb->len);
    memcpy(payload + bodyStart.length() + fb->len, bodyEnd.c_str(), bodyEnd.length());

    int httpCode = http.POST(payload, totalLen);
    Serial.printf("[*] Upload HTTP Response: %d\n", httpCode);

    free(payload);
    http.end();
  }

  esp_camera_fb_return(fb);
}

void loop() {
  // Listen for serial trigger or timed capture
  if (Serial.available()) {
    char cmd = Serial.read();
    if (cmd == 'c' || cmd == 'C') {
      captureAndSend();
    }
  }
  delay(100);
}
