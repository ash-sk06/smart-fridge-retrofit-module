// =============================================================================
// AI REFRIGERATOR RETROFIT MODULE: 2-PART ANTI-FOG OPTIMIZED CAMERA POD
// Project: Dual-Zone Multi-Sensor Food Inventory System
// Target Hardware: AI-Thinker ESP32-CAM (OV2640 Module)
// Optical Upgrades:
//   1. 65-Degree Conical Flared Baffle (Zero Corner Vignetting / No Cut-Off)
//   2. Internal Optical Isolation Collar (Zero Flash LED Glare Bleed / No Milky Glare)
//   3. Retains Parasitic Heat Channel (Patent Claim 3) & Desiccant Bay
// =============================================================================

$fn = 60; // Smooth circular curves for 3D printing

// -----------------------------------------------------------------------------
// USER CONFIGURATION / DIMENSIONAL PARAMETERS (All dimensions in mm)
// -----------------------------------------------------------------------------
wall_th = 2.5;                // Structural wall thickness
box_w = 48.0;                 // Outer width
box_h = 64.0;                 // Outer height
box_d = 26.0;                 // Outer depth of cavity body

// Optical Aperture & Conical Anti-Fog Baffle
baffle_len = 12.0;            // 12mm forward extension for stagnant dead-air zone
baffle_base_id = 18.0;        // Inner diameter at optical window
baffle_mouth_id = 30.0;       // Flared inner diameter at mouth (accommodates 66° FOV cone)
baffle_wall = 2.0;            // Wall thickness of the baffle cone
lens_y_offset = 16.0;         // Offset from top edge to camera optical center

// Internal Optical Isolation Collar (Isolates Lens from Flash LED)
collar_id = 11.0;             // Inner diameter (clears 8.5mm OV2640 lens)
collar_od = 14.5;             // Outer diameter (physically blocks adjacent flash LED)
collar_h = 2.8;               // Extends backward to meet OV2640 sensor face

// Acrylic Optical Window Retention Pocket (Internal)
window_w = 26.0;              // Square pocket for 25x25mm acrylic square (+1mm clearance)
window_h = 26.0;              // Square pocket height
window_th = 2.2;              // Pocket depth for standard 2.0mm acrylic pane

// ESP32-CAM Module (AI-Thinker Standard: 27.0mm x 40.5mm)
pcb_w = 27.5;                 // PCB slot width (+0.5mm slide clearance)
pcb_th = 1.6;                 // Standard FR4 PCB thickness
pcb_h = 40.5;                 // PCB height

// Desiccant Bay (Silica Gel 1g-2g Pouch)
desiccant_w = 40.0;
desiccant_h = 14.0;
desiccant_d = 18.0;

// Back Lid & Magnetic Retrofit Mounts
lid_th = 2.5;
magnet_diam = 10.3;           // Sized for standard 10mm Neodymium disc magnets
magnet_depth = 2.2;           // Depth for 2mm thick disc magnets
cable_diam = 4.5;             // Micro-USB / power cable diameter

// -----------------------------------------------------------------------------
// SELECT WHAT TO RENDER (Change number to render specific part)
// 1 = Complete 2-Part Exploded Assembly (Visualization)
// 2 = Part 1: Main Housing with Flared Baffle & Light Collar (Print 1x)
// 3 = Part 2: Back Lid with Magnetic Mounts (Print 1x)
// -----------------------------------------------------------------------------
RENDER_PART = 1;

if (RENDER_PART == 1) {
    exploded_assembly_2part();
} else if (RENDER_PART == 2) {
    part1_main_housing_integrated();
} else if (RENDER_PART == 3) {
    part2_back_lid();
}

// =============================================================================
// PART 1: MAIN HOUSING WITH CONICAL BAFFLE & OPTICAL ISOLATION COLLAR
// =============================================================================
module part1_main_housing_integrated() {
    union() {
        // --- Main Housing Body ---
        difference() {
            // Outer Rounded Box
            hull() {
                translate([2, 2, 0]) cylinder(r=2, h=box_d);
                translate([box_w - 2, 2, 0]) cylinder(r=2, h=box_d);
                translate([box_w - 2, box_h - 2, 0]) cylinder(r=2, h=box_d);
                translate([2, box_h - 2, 0]) cylinder(r=2, h=box_d);
            }

            // Main Internal Cavity
            translate([wall_th, wall_th, wall_th])
                cube([box_w - 2 * wall_th, box_h - 2 * wall_th, box_d]);

            // Optical Aperture Through Front Face
            translate([box_w / 2, box_h - lens_y_offset, -1])
                cylinder(d=baffle_base_id, h=wall_th + 2);

            // Acrylic Window Retention Recess (Inside front wall: 26x26x2.2mm)
            translate([(box_w - window_w) / 2, (box_h - lens_y_offset) - window_h / 2, wall_th - window_th + 0.01])
                cube([window_w, window_h, window_th + 0.1]);

            // Parasitic Thermal Conduction Channel (Claim 3)
            translate([(box_w - 12) / 2, (box_h - lens_y_offset) - window_h / 2 - 10, wall_th - 1.2])
                cube([12, 12, 1.5]);

            // Rear Lid Inset Lip Chamfer
            translate([wall_th - 0.4, wall_th - 0.4, box_d - 2.5])
                cube([box_w - 2 * wall_th + 0.8, box_h - 2 * wall_th + 0.8, 3.0]);
        }

        // --- Integrated 65-Degree Conical Anti-Fog Baffle (Monolithic) ---
        // Flares outward from 18mm at the glass to 30mm at the mouth
        translate([box_w / 2, box_h - lens_y_offset, -baffle_len])
            difference() {
                // Outer tapered cone (63° angle from horizontal — 100% printable with NO supports)
                cylinder(d1=baffle_mouth_id + 2 * baffle_wall, d2=baffle_base_id + 2 * baffle_wall, h=baffle_len + 0.05);
                
                // Conical optical tunnel through-hole
                translate([0, 0, -1])
                    cylinder(d1=baffle_mouth_id, d2=baffle_base_id, h=baffle_len + 3);
            }

        // --- Internal Optical Isolation Collar (Blocks Flash LED Bleed) ---
        // Extends backwards from the acrylic window to hug the OV2640 lens barrel
        translate([box_w / 2, box_h - lens_y_offset, wall_th + window_th - 0.1])
            difference() {
                cylinder(d=collar_od, h=collar_h);
                translate([0, 0, -0.5])
                    cylinder(d=collar_id, h=collar_h + 1);
            }

        // --- Internal ESP32-CAM Guide Rails ---
        rail_x_left = (box_w - pcb_w) / 2 - 2.0;
        rail_x_right = (box_w + pcb_w) / 2;
        rail_y_start = box_h - wall_th - pcb_h - 1.0;
        rail_z_pos = wall_th + window_th + 2.0; // Keeps OV2640 lens 2mm behind acrylic

        difference() {
            union() {
                // Left Guide Rail
                translate([rail_x_left, rail_y_start, rail_z_pos - 1])
                    cube([2.0, pcb_h, 5.0]);
                // Right Guide Rail
                translate([rail_x_right, rail_y_start, rail_z_pos - 1])
                    cube([2.0, pcb_h, 5.0]);

                // Bottom Desiccant Bay Separator Rib
                translate([wall_th, wall_th + desiccant_h, wall_th])
                    cube([box_w - 2 * wall_th, 1.8, 12.0]);
            }
            // Slot for PCB to slide into smoothly
            translate([(box_w - pcb_w) / 2, rail_y_start - 1, rail_z_pos])
                cube([pcb_w, pcb_h + 2, pcb_th + 0.4]);
            
            // Air circulation cutout in desiccant rib
            translate([box_w / 2 - 8, wall_th + desiccant_h - 1, wall_th])
                cube([16, 4, 8]);
        }
    }
}

// =============================================================================
// PART 2: BACK LID WITH MAGNETIC RETROFIT MOUNTS & CABLE STRAIN RELIEF
// =============================================================================
module part2_back_lid() {
    difference() {
        union() {
            hull() {
                translate([2, 2, 0]) cylinder(r=2, h=lid_th);
                translate([box_w - 2, 2, 0]) cylinder(r=2, h=lid_th);
                translate([box_w - 2, box_h - 2, 0]) cylinder(r=2, h=lid_th);
                translate([2, box_h - 2, 0]) cylinder(r=2, h=lid_th);
            }

            translate([wall_th + 0.25, wall_th + 0.25, lid_th])
                cube([box_w - 2 * wall_th - 0.5, box_h - 2 * wall_th - 0.5, 2.5]);
        }

        // Dual 10mm Neodymium Magnet Recesses
        translate([box_w / 2, box_h * 0.28, -0.1])
            cylinder(d=magnet_diam, h=magnet_depth);
        translate([box_w / 2, box_h * 0.72, -0.1])
            cylinder(d=magnet_diam, h=magnet_depth);

        // Optional M3 Countersunk Screw Holes
        translate([box_w / 2, box_h * 0.28, -1])
            cylinder(d=3.4, h=lid_th + 5);
        translate([box_w / 2, box_h * 0.72, -1])
            cylinder(d=3.4, h=lid_th + 5);

        // Cable Strain Relief Notch
        translate([box_w - wall_th - 6.0, -1, lid_th - 0.5])
            cube([cable_diam, wall_th + 6.0, 3.5]);
        translate([box_w - wall_th - 8.0, wall_th + 2.0, lid_th - 0.5])
            cube([6.0, cable_diam, 3.5]);
            
        // Finger Notch for lid removal
        translate([box_w / 2 - 6, box_h - 3, 0.5])
            cube([12, 4, 3]);
    }
}

// =============================================================================
// EXPLODED 2-PART ASSEMBLY VIEW (Visualization & Presentation)
// =============================================================================
module exploded_assembly_2part() {
    // 1. PART 1: Main Housing with Flared Baffle & Light Collar (Cyan-Blue)
    color([0.22, 0.52, 0.82, 0.9])
        part1_main_housing_integrated();

    // Internal 25x25mm Clear Acrylic Window
    color([0.5, 0.9, 1.0, 0.45])
        translate([(box_w - 25) / 2, (box_h - lens_y_offset) - 25 / 2, wall_th - window_th + 0.2])
            cube([25, 25, 2.0]);

    // Internal ESP32-CAM PCB
    color([0.1, 0.5, 0.2, 1.0])
        translate([(box_w - 27.0) / 2, box_h - wall_th - pcb_h, wall_th + window_th + 2.0]) {
            cube([27.0, pcb_h, 1.6]);
            // Camera Lens Barrel (Inside the isolation collar)
            color([0.05, 0.05, 0.05])
                translate([27.0 / 2 - 4.25, pcb_h - 14.0 - 4.25, -4.5])
                    cube([8.5, 8.5, 4.5]);
            // Flash SMD LED (Outside the collar)
            color([0.95, 0.95, 0.4])
                translate([27.0 / 2 + 5.5, pcb_h - 14.0 - 1.5, -1.0])
                    cube([3.5, 3.5, 1.0]);
            // ESP32 Metal RF Shield
            color([0.8, 0.8, 0.8])
                translate([27.0 / 2 - 8.0, 6.0, 1.6])
                    cube([16.0, 18.0, 2.5]);
        }

    // Silica Gel Pouch
    color([0.95, 0.95, 0.95, 0.9])
        translate([wall_th + 2, wall_th + 1, wall_th + 1])
            cube([desiccant_w - 4, desiccant_h - 2, 8.0]);

    // 2. PART 2: Back Lid (Exploded backward +30mm)
    color([0.22, 0.25, 0.3, 0.95])
        translate([0, 0, box_d + 30])
            part2_back_lid();
}
