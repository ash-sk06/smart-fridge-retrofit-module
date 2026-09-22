import 'package:flutter/material.dart';
import '../models/inventory_model.dart';

class CameraVisionCard extends StatelessWidget {
  final TelemetryData telemetry;
  final String baseUrl;
  final VoidCallback onRefresh;
  final VoidCallback? onTriggerScan;
  final bool isScanning;

  const CameraVisionCard({
    super.key,
    required this.telemetry,
    required this.baseUrl,
    required this.onRefresh,
    this.onTriggerScan,
    this.isScanning = false,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = '$baseUrl${telemetry.latestImagePath}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.camera_alt_outlined,
                          size: 18, color: Color(0xFFA78BFA)),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Overhead Vision Pod',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF8FAFC),
                          ),
                        ),
                        Text(
                          'ESP32-CAM OV3660 • 1080p LED Strobe',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (onTriggerScan != null)
                      IconButton(
                        icon: isScanning
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Color(0xFFA78BFA)),
                              )
                            : const Icon(Icons.flash_on_outlined, size: 20),
                        tooltip: 'Trigger Strobe Scan',
                        style: IconButton.styleFrom(
                          foregroundColor: const Color(0xFFA78BFA),
                        ),
                        onPressed: isScanning ? null : onTriggerScan,
                      ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      tooltip: 'Refresh Snapshot',
                      style: IconButton.styleFrom(
                        foregroundColor: const Color(0xFF94A3B8),
                      ),
                      onPressed: onRefresh,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Image Preview Container
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 190,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1120),
                  border: Border.all(color: const Color(0xFF1E293B)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_outlined,
                                    size: 40, color: Colors.grey.shade600),
                                const SizedBox(height: 8),
                                const Text(
                                  'OV3660 Camera Feed Standby',
                                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                ),
                                const Text(
                                  'Captures automatically when door closes',
                                  style: TextStyle(color: Color(0xFF64748B), fontSize: 10),
                                ),
                              ],
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                          );
                        },
                      ),
                    ),
                    // Live Overlay Pill
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.circle, color: Color(0xFF10B981), size: 8),
                            SizedBox(width: 5),
                            Text(
                              'DOOR-TRIGGERED STROBE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Detected Objects Tags (YOLOv8)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_outlined, size: 14, color: Color(0xFF06B6D4)),
                const SizedBox(width: 6),
                const Text(
                  'YOLOv8 Cloud Engine:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE2E8F0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: telemetry.detectedObjects.isEmpty
                        ? [
                            const Text(
                              'Awaiting door close scan...',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            )
                          ]
                        : telemetry.detectedObjects.map((obj) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFF8B5CF6).withOpacity(0.4)),
                              ),
                              child: Text(
                                obj,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFC4B5FD),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
