# Cloud Deployment Guide: 24/7 Free Hosting
**Project:** AI Refrigerator Retrofit Module Using Multi-Sensor Fusion  
**Platform:** [Render.com](https://render.com) (100% Free Tier)  
**Location of Config Files:** [`software/`](file:///Users/ashwathsathish/Library/Mobile%20Documents/com~apple~CloudDocs/AI%20Refridgerator%20Retrofit%20Module/software/)

---

## What This Enables

* **Laptop Can Be Powered Off:** Your backend server runs 24/7 in the cloud.
* **Access Anywhere in the World:** Open the mobile app at the supermarket or on 4G/5G mobile data to check remaining milk/juice levels.
* **Automatic Free SSL Certificate:** Secure `https://` domain provided at zero cost.

```
┌────────────────────────┐         ┌───────────────────────────────┐         ┌────────────────────────┐
│  ESP32-CAM & DUAL TRAY │ ──────► │       CLOUD WEB SERVICE       │ ◄────── │   FLUTTER MOBILE APP   │
│  (Home Wi-Fi Network)  │  HTTP   │  (Hosted 24/7 on Render.com)  │  HTTPS  │  (Anywhere on 4G / 5G) │
└────────────────────────┘  POST   │ https://smart-fridge.onrender │         └────────────────────────┘
                                   └───────────────────────────────┘
```

---

## Step-by-Step Deployment (5 Minutes)

### Step 1: Create a Free Render Account
1. Go to **[https://render.com](https://render.com)**.
2. Sign up using your GitHub, GitLab, or Google account (100% free, no credit card required).

---

### Step 2: Push Your Code to GitHub
If your project is not already on GitHub:
1. Go to [github.com](https://github.com) and click **New Repository** (e.g. `smart-fridge-retrofit`).
2. In your Mac terminal, initialize and push:
   ```bash
   cd "/Users/ashwathsathish/Library/Mobile Documents/com~apple~CloudDocs/AI Refridgerator Retrofit Module"
   git init
   git add .
   git commit -m "Complete AI Refrigerator Retrofit Module with 24/7 Cloud Support"
   git branch -M main
   git remote add origin https://github.com/YOUR_GITHUB_USERNAME/YOUR_REPO_NAME.git
   git push -u origin main
   ```
*(Or drag and drop your project into the free [GitHub Desktop](https://desktop.github.com/) app).*

---

### Step 3: Deploy on Render
1. On your Render Dashboard, click the blue button: **"New +"** and select **"Web Service"**.
2. Select **"Build and deploy from a Git repository"** and connect your GitHub repo.
3. Fill in the settings:
   * **Name:** `smart-fridge-retrofit` (or your choice)
   * **Region:** Singapore / Frankfurt / Oregon (any)
   * **Root Directory:** `software` *(Very important! Type `software`)*
   * **Runtime:** `Python 3`
   * **Build Command:** `pip install -r requirements.txt`
   * **Start Command:** `gunicorn server:app --bind 0.0.0.0:$PORT`
   * **Instance Type:** Select **Free ($0/month)**.
4. Click **"Deploy Web Service"** at the bottom.

---

### Step 4: Get Your Permanent Live URL
In about 1–2 minutes, Render will finish building and display:
```text
==> Your service is live 🎉
https://smart-fridge-retrofit.onrender.com
```

Copy this URL!

---

### Step 5: Connect Your Mobile App & Hardware to the Cloud

#### A. In Your Flutter Mobile App:
1. Open the **Smart Fridge** app on your phone.
2. Tap the **Settings icon (⚙️)** in the top-right corner.
3. Replace the local IP with your Render URL (without `https://`):
   ```text
   smart-fridge-retrofit.onrender.com
   ```
4. Tap **Save & Connect**.  
   *The status pill will turn **🟢 ESP32 HUB LIVE**! You can now access your fridge from anywhere in the world on 4G/5G!*

#### B. In Your ESP32 Hardware Firmware:
When you flash your hardware, set the `serverUrl` in:
* [`software/firmware/esp32_sensor_hub.ino`](file:///Users/ashwathsathish/Library/Mobile%20Documents/com~apple~CloudDocs/AI%20Refridgerator%20Retrofit%20Module/software/firmware/esp32_sensor_hub.ino):
  ```cpp
  const char* serverUrl = "https://smart-fridge-retrofit.onrender.com/api/sensor-event";
  ```
* [`software/firmware/esp32_cam_strobe.ino`](file:///Users/ashwathsathish/Library/Mobile%20Documents/com~apple~CloudDocs/AI%20Refridgerator%20Retrofit%20Module/software/firmware/esp32_cam_strobe.ino):
  ```cpp
  const char* serverUrl = "https://smart-fridge-retrofit.onrender.com/api/upload-image";
  ```

---

## Shortcut: Instant 5-Second Public Tunnel (Without GitHub)

If you want an instant public link right now without pushing to GitHub first:
1. Start your server locally: `python3 software/server.py`
2. In a second terminal window, run:
   ```bash
   npx localtunnel --port 5050
   ```
   It will generate a live public URL like:
   `https://fresh-fridge-123.loca.lt`
3. Enter that URL into your mobile app, and you can test over 4G/5G immediately!
