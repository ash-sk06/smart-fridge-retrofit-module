# 3D Printing & Assembly Guide: 2-Part Anti-Fog Camera Pod
**Project:** AI Refrigerator Retrofit Module Using Multi-Sensor Fusion  
**Target Hardware:** AI-Thinker ESP32-CAM (OV2640 Sensor)  
**Location:** [`cad/`](file:///Users/ashwathsathish/Library/Mobile%20Documents/com~apple~CloudDocs/AI%20Refridgerator%20Retrofit%20Module/cad/)

---

## 1. File Inventory (Strictly 2 Parts - Optically Optimized)

| File | Description | Material & Quantity |
| :--- | :--- | :---: |
| [**`camera_pod_main_body.stl`**](file:///Users/ashwathsathish/Library/Mobile%20Documents/com~apple~CloudDocs/AI%20Refridgerator%20Retrofit%20Module/cad/camera_pod_main_body.stl) | **Part 1:** Main housing with **$65^\circ$ conical flared baffle** (zero corner vignetting), **internal optical isolation collar** (stops flash LED bleed), $25\times25\text{ mm}$ acrylic pocket, ESP32 slide rails, and desiccant bay. | PLA / PETG (1x) |
| [**`camera_pod_back_lid.stl`**](file:///Users/ashwathsathish/Library/Mobile%20Documents/com~apple~CloudDocs/AI%20Refridgerator%20Retrofit%20Module/cad/camera_pod_back_lid.stl) | **Part 2:** Snap-fit rear cover with dual $10\text{ mm}$ Neodymium magnet sockets and S-curve cable strain relief. | PLA / PETG (1x) |
| [**`anti_fog_camera_pod.scad`**](file:///Users/ashwathsathish/Library/Mobile%20Documents/com~apple~CloudDocs/AI%20Refridgerator%20Retrofit%20Module/cad/anti_fog_camera_pod.scad) | Parametric OpenSCAD source file with 3D exploded assembly view. | Source |
| [**`generate_stl.py`**](file:///Users/ashwathsathish/Library/Mobile%20Documents/com~apple~CloudDocs/AI%20Refridgerator%20Retrofit%20Module/cad/generate_stl.py) | Python script to regenerate binary STLs directly. | Script |

---

## 2. 3D Slicer Settings (Cura / PrusaSlicer / Bambu Studio)

Both parts are engineered to print with **ZERO supports (0% supports needed)**.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        RECOMMENDED SLICE PROFILE                       │
├─────────────────────────┬──────────────────────────────────────────────┤
│ Material                │ PETG (Preferred for cold/moisture) or PLA    │
│ Layer Height            │ 0.20 mm (Standard)                           │
│ Wall Line Count (Perim) │ 3 to 4 walls (≥ 1.2 mm solid perimeter)      │
│ Top / Bottom Layers     │ 4 top / 4 bottom layers                      │
│ Infill Density          │ 20%                                          │
│ Infill Pattern          │ Gyroid or Grid                               │
│ Print Speed             │ 50 mm/s                                      │
│ Supports                │ NONE (Disabled - 0% supports needed)         │
│ Build Plate Adhesion    │ Skirt (or 3mm Brim if bed adhesion is weak)  │
│ Bed Temperature         │ PLA: 60°C | PETG: 75°C - 80°C                │
│ Nozzle Temperature      │ PLA: 205°C | PETG: 235°C - 240°C             │
└─────────────────────────┴──────────────────────────────────────────────┘
```

### Print Orientation by Part:
1. **`camera_pod_main_body.stl`**: Place flat on its front face (baffle tube rim resting down on the build plate).
2. **`camera_pod_back_lid.stl`**: Place flat with the exterior face down on the bed.

### Print Statistics:
* **Total Filament Weight:** ~32 grams (~₹25 INR of filament).
* **Total Print Time:** ~1 hour 15 minutes on an Ender-3; ~25 minutes on a Bambu / K1.

---

## 3. Physical Assembly Steps

```
Step 1: Drop in Acrylic Window (25x25x2mm) from inside into molded pocket.
Step 2: Attach Foil Thermal Ribbon to ESP32 RF shield & route to window edge.
Step 3: Slide ESP32-CAM PCB into internal guide rails (lens 2mm behind window).
Step 4: Place 1g Silica Gel Pouch in the bottom bay.
Step 5: Press 2x 10mm Neodymium Magnets into back lid & snap lid shut.
Step 6: Buff outer acrylic face with half a drop of dish soap (surfactant film).
```

### Detailed Assembly:
1. **Optical Window:** Cut a $25\text{ mm} \times 25\text{ mm}$ square from 2.0mm clear acrylic (or scrap CD jewel case). Clean with alcohol, drop into the internal pocket behind the baffle, and seal edges with 2 drops of hot glue or silicone.
2. **Parasitic Heat Conductor (Claim 3):** Tape a strip of folded kitchen aluminum foil (or copper tape) to the ESP32's silver metal shield. Route it to touch the edge of the acrylic pane.
3. **Slide Board In:** Slide the ESP32-CAM (27.0mm wide) into the molded rails. The OV2640 lens sits centered directly behind the optical aperture.
4. **Desiccant:** Drop a 1g silica gel sachet into the lower compartment.
5. **Magnetic Mount:** Press two $10\text{ mm} \times 2\text{ mm}$ Neodymium magnets into the back lid sockets. Route the power cable through the strain-relief slot and press the lid shut!

---

## 4. Outer Hydrophilic Coating Application

Before sticking the pod inside the refrigerator:
1. Put half a drop of liquid dish soap (**Vim / Pril / Colin**) onto the outer face of the acrylic window (inside the baffle cone).
2. Spread evenly with a cotton bud. Let dry for 60 seconds.
3. Buff vigorously with a clean, dry microfiber cloth until completely transparent.
4. Water condensation will now form a flat transparent liquid sheet (contact angle $< 10^\circ$) instead of scattering droplets.

---

## 5. Critical Lens Macro Focus Adjustment (25 cm Shelf Height)

> [!IMPORTANT]
> **Why this is necessary:** All stock OV2640 modules from the factory are pre-focused at **1 meter to infinity**. At the 22–25 cm distance inside a refrigerator, the food cartons and labels will be slightly blurry unless you perform this 10-second adjustment:

1. Look at the threaded circular lens barrel on the OV2640 sensor. There is a tiny dot of yellow glue locking the thread.
2. Use tweezers or a hobby knife to gently pick away the glue dot.
3. Power up the ESP32-CAM and open the live stream on your laptop screen.
4. Hold a milk or juice carton **$25\text{ cm}$ away**.
5. Slowly rotate the lens barrel **counter-clockwise by approximately $60^\circ\text{ to }90^\circ$ (about a 1/4 turn)**.
6. The carton text and barcode will snap into razor-sharp macro focus!
