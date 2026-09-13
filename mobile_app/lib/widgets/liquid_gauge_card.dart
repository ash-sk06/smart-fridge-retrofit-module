import 'package:flutter/material.dart';
import '../models/inventory_model.dart';

class LiquidGaugeCard extends StatelessWidget {
  final InventoryItem item;
  final String iconEmoji;
  final VoidCallback? onPour;

  const LiquidGaugeCard({
    super.key,
    required this.item,
    required this.iconEmoji,
    this.onPour,
  });

  Color _getStatusColor(double pct) {
    if (pct < 20.0) return Colors.redAccent;
    if (pct < 45.0) return Colors.amber.shade700;
    return Colors.teal.shade600;
  }

  Color _getLiquidGradientStart(double pct) {
    if (pct < 20.0) return Colors.red.shade400;
    if (pct < 45.0) return Colors.amber.shade400;
    return Colors.cyan.shade400;
  }

  Color _getLiquidGradientEnd(double pct) {
    if (pct < 20.0) return Colors.red.shade700;
    if (pct < 45.0) return Colors.amber.shade700;
    return Colors.blue.shade700;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(item.fillPercentage);
    final isLow = item.fillPercentage < 20.0;

    return Card(
      elevation: isLow ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isLow ? Colors.red.shade300 : Colors.transparent,
          width: isLow ? 1.5 : 0,
        ),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Emoji Icon + Title + Category Chip
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    iconEmoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.itemName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Zone: ${item.zoneId.toUpperCase()} • ${item.category}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLow) ...[
                        Icon(Icons.warning_amber_rounded, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        item.status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Liquid Level Visualization (Liquid Gauge Bar)
            Stack(
              children: [
                // Empty Track Container
                Container(
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                // Animated Liquid Fill Bar
                LayoutBuilder(
                  builder: (context, constraints) {
                    final fillFraction = (item.fillPercentage / 100.0).clamp(0.0, 1.0);
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      height: 32,
                      width: constraints.maxWidth * fillFraction,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _getLiquidGradientStart(item.fillPercentage),
                            _getLiquidGradientEnd(item.fillPercentage),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                // Fill Text Overlay
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${item.fillPercentage.toStringAsFixed(0)}% Remaining',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          '${item.remainingVolume.toInt()} ml / ${item.fullVolume.toInt()} ml',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Telemetry Details & Action Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gross Weight: ${item.currentWeight.toStringAsFixed(1)} g',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    Text(
                      'Container Tare: ${item.tareWeight.toStringAsFixed(1)} g',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                if (onPour != null)
                  ElevatedButton.icon(
                    onPressed: onPour,
                    icon: const Icon(Icons.local_drink_outlined, size: 14),
                    label: const Text('Pour 150ml', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      backgroundColor: Colors.grey.shade100,
                      foregroundColor: Colors.blueGrey.shade800,
                      elevation: 0,
                      side: BorderSide(color: Colors.grey.shade300),
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
