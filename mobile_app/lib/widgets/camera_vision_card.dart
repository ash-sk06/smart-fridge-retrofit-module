import 'package:flutter/material.dart';
import '../models/inventory_model.dart';

class CameraVisionCard extends StatelessWidget {
  final TelemetryData telemetry;
  final String baseUrl;
  final VoidCallback onRefresh;

  const CameraVisionCard({
    super.key,
    required this.telemetry,
    required this.baseUrl,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = '$baseUrl${telemetry.latestImagePath}';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.camera_alt,
                          size: 18, color: Colors.purple.shade700),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Overhead Vision (OV2640)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: 'Refresh Snapshot',
                  onPressed: onRefresh,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Image Preview Container
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 180,
                width: double.infinity,
                color: Colors.black87,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image_outlined,
                              size: 40, color: Colors.grey.shade500),
                          const SizedBox(height: 6),
                          Text(
                            'No overhead capture yet',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                          ),
                          Text(
                            'Triggers automatically when door closes',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                          ),
                        ],
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Detected Objects Tags (YOLOv8)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'YOLOv8 Detections:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: telemetry.detectedObjects.map((obj) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Text(
                          obj,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.purple.shade900,
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
