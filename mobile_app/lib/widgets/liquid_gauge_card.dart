import 'package:flutter/material.dart';
import '../models/inventory_model.dart';

class LiquidGaugeCard extends StatelessWidget {
  final InventoryItem item;
  final String iconEmoji;
  final VoidCallback? onPour;
  final VoidCallback? onLowStock;
  final VoidCallback? onCalibrate;

  const LiquidGaugeCard({
    super.key,
    required this.item,
    required this.iconEmoji,
    this.onPour,
    this.onLowStock,
    this.onCalibrate,
  });

  Color _getStatusColor(double pct) {
    if (pct < 20.0) return const Color(0xFFEF4444);
    if (pct < 45.0) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  Color _getLiquidGradientStart(double pct) {
    if (pct < 20.0) return const Color(0xFFEF4444);
    if (pct < 45.0) return const Color(0xFFF59E0B);
    return const Color(0xFF06B6D4);
  }

  Color _getLiquidGradientEnd(double pct) {
    if (pct < 20.0) return const Color(0xFFB91C1C);
    if (pct < 45.0) return const Color(0xFFD97706);
    return const Color(0xFF3B82F6);
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(item.fillPercentage);
    final isLow = item.fillPercentage < 20.0;
    final isExpiringSoon = item.daysToExpiry <= 3;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLow
              ? const Color(0xFFEF4444).withOpacity(0.6)
              : const Color(0xFF1E293B),
          width: isLow ? 1.5 : 1,
        ),
        boxShadow: [
          if (isLow)
            BoxShadow(
              color: const Color(0xFFEF4444).withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Emoji Icon + Title + Category Chip + Status Pill
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Text(
                    iconEmoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.itemName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF8FAFC),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.zoneId.toUpperCase()} • ${item.category}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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
                    color: const Color(0xFF0B1120),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF1E293B)),
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
                            color: statusColor.withOpacity(0.4),
                            blurRadius: 8,
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
                          '${item.fillPercentage.toStringAsFixed(0)}% Fill',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(blurRadius: 4, color: Colors.black87),
                            ],
                          ),
                        ),
                        Text(
                          '${item.remainingVolume.toInt()} ml / ${item.fullVolume.toInt()} ml',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            shadows: [
                              Shadow(blurRadius: 4, color: Colors.black87),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Metadata Chip: Weight and Expiry
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Load: ${item.currentWeight.toStringAsFixed(1)}g (Tare: ${item.tareWeight.toStringAsFixed(0)}g)',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 11,
                        color: isExpiringSoon ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${item.expiryDate} (${item.daysToExpiry}d)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isExpiringSoon ? FontWeight.bold : FontWeight.w500,
                          color: isExpiringSoon ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Action Buttons Row: Pour, Low Stock, Calibrate
            if (onPour != null || onLowStock != null || onCalibrate != null)
              Row(
                children: [
                  if (onPour != null)
                    Expanded(
                      flex: 5,
                      child: ElevatedButton.icon(
                        onPressed: onPour,
                        icon: const Icon(Icons.local_drink_outlined, size: 14),
                        label: Text(
                          item.zoneId == 'zone1' ? 'Pour 150ml' : 'Pour 120ml',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                          backgroundColor: const Color(0xFF1E293B),
                          foregroundColor: const Color(0xFFE2E8F0),
                          elevation: 0,
                          side: const BorderSide(color: Color(0xFF334155)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  if (onPour != null && onLowStock != null)
                    const SizedBox(width: 8),
                  if (onLowStock != null)
                    Expanded(
                      flex: 4,
                      child: ElevatedButton.icon(
                        onPressed: onLowStock,
                        icon: const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFEF4444)),
                        label: const Text(
                          'Low Stock',
                          style: TextStyle(fontSize: 12, color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                          backgroundColor: const Color(0xFFEF4444).withOpacity(0.15),
                          elevation: 0,
                          side: BorderSide(color: const Color(0xFFEF4444).withOpacity(0.4)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  if (onCalibrate != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      height: 38,
                      width: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: onCalibrate,
                        icon: const Icon(Icons.tune, size: 18, color: Color(0xFF94A3B8)),
                        tooltip: 'Calibrate Container',
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}
