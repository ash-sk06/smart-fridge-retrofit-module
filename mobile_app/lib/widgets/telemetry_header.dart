import 'package:flutter/material.dart';
import '../models/inventory_model.dart';

class TelemetryHeader extends StatelessWidget {
  final FridgeStatus? status;
  final TelemetryData telemetry;
  final bool isConnected;
  final VoidCallback onToggleDoor;
  final VoidCallback onScanNow;
  final VoidCallback onTareScale;
  final bool isScanning;

  const TelemetryHeader({
    super.key,
    required this.status,
    required this.telemetry,
    required this.isConnected,
    required this.onToggleDoor,
    required this.onScanNow,
    required this.onTareScale,
    this.isScanning = false,
  });

  @override
  Widget build(BuildContext context) {
    final doorState = (telemetry.doorState.isNotEmpty ? telemetry.doorState : (status?.doorState ?? 'CLOSED')).toUpperCase();
    final isDoorOpen = doorState == 'OPEN';
    final tempC = status?.temperatureC ?? telemetry.temperatureC;
    final humidity = status?.humidityPct ?? telemetry.humidityPct;
    final isTempWarm = tempC > 4.5;
    final isHardware = status?.hardwareMode == 'HARDWARE';
    final shelfMass = status?.shelfMassG ?? (telemetry.lastDeltaDairy + telemetry.lastDeltaDrinks);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDoorOpen
              ? const Color(0xFFEF4444)
              : const Color(0xFFE2E8F0),
          width: isDoorOpen ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: System Title + Hardware Status Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status?.fridgeName ?? 'Main Kitchen Refrigerator',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ESP32-S2 Hub • ${status?.lastSync ?? "Live"}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Connection Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isConnected
                      ? (isHardware ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF))
                      : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isConnected
                        ? (isHardware ? const Color(0xFF10B981) : const Color(0xFF3B82F6))
                        : const Color(0xFFEF4444),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isConnected
                            ? (isHardware ? const Color(0xFF10B981) : const Color(0xFF3B82F6))
                            : const Color(0xFFEF4444),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      !isConnected
                          ? 'OFFLINE'
                          : (isHardware ? 'ONLINE' : 'CONNECTED'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                        color: isConnected
                            ? (isHardware ? const Color(0xFF065F46) : const Color(0xFF1D4ED8))
                            : const Color(0xFF991B1B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Row 2: 2x2 Telemetry Metrics Grid (Temp, Humidity, Door, Shelf Load)
          Row(
            children: [
              // Temperature
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.thermostat,
                  iconColor: isTempWarm ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
                  label: 'Ideal: 1°C - 5°C',
                  title: 'Temperature',
                  value: '${tempC.toStringAsFixed(1)}°C',
                  statusText: isTempWarm ? 'Warm' : 'Normal',
                  statusColor: isTempWarm ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 10),
              // Humidity
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.water_drop,
                  iconColor: const Color(0xFF06B6D4),
                  label: 'Ideal: 50% - 70%',
                  title: 'Humidity',
                  value: '$humidity%',
                  statusText: 'Normal',
                  statusColor: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Door Status
              Expanded(
                child: InkWell(
                  onTap: onToggleDoor,
                  borderRadius: BorderRadius.circular(14),
                  child: _buildMetricTile(
                    icon: isDoorOpen ? Icons.door_sliding : Icons.meeting_room_outlined,
                    iconColor: isDoorOpen ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    label: isDoorOpen ? 'Buzzer >45s' : 'Magnetic Safe',
                    title: 'Door Switch',
                    value: isDoorOpen ? 'OPEN' : 'Closed',
                    statusText: isDoorOpen ? 'Open' : 'Safe',
                    statusColor: isDoorOpen ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Total Shelf Load
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.scale_outlined,
                  iconColor: const Color(0xFF8B5CF6),
                  label: 'Dual Cantilever',
                  title: 'Shelf Load',
                  value: '${shelfMass.toStringAsFixed(0)}g',
                  statusText: 'Optimal',
                  statusColor: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Row 3: Quick Action Buttons (Scan Now + Tare Scale)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isScanning ? null : onScanNow,
                  icon: isScanning
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.camera_alt_outlined, size: 16),
                  label: Text(
                    isScanning ? 'Scanning...' : 'Scan Now (OV3660)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onTareScale,
                  icon: const Icon(Icons.exposure_zero_outlined, size: 16),
                  label: const Text(
                    'Tare Scale (HX711)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF475569),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String label,
    required String statusText,
    required Color statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}
