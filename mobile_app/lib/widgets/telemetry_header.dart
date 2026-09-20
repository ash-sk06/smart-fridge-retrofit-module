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
    final doorState = status?.doorState ?? telemetry.doorState;
    final isDoorOpen = doorState.toUpperCase() == 'OPEN';
    final tempC = status?.temperatureC ?? telemetry.temperatureC;
    final humidity = status?.humidityPct ?? telemetry.humidityPct;
    final isTempWarm = tempC > 7.0;
    final isHardware = status?.hardwareMode == 'HARDWARE';
    final shelfMass = status?.shelfMassG ?? (telemetry.lastDeltaDairy + telemetry.lastDeltaDrinks);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDoorOpen
              ? const Color(0xFFF59E0B).withOpacity(0.8)
              : const Color(0xFF1E293B),
          width: isDoorOpen ? 1.5 : 1,
        ),
        boxShadow: [
          if (isDoorOpen)
            BoxShadow(
              color: const Color(0xFFF59E0B).withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: System Title + Hardware Status Pill + Last Sync
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status?.fridgeName ?? 'Primary Refrigerator',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF8FAFC),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Sync: ${status?.lastSync ?? "Just now"}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              // Connection Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isConnected
                      ? (isHardware
                          ? const Color(0xFF10B981).withOpacity(0.15)
                          : const Color(0xFF06B6D4).withOpacity(0.15))
                      : const Color(0xFFEF4444).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isConnected
                        ? (isHardware ? const Color(0xFF10B981) : const Color(0xFF06B6D4))
                        : const Color(0xFFEF4444),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isConnected
                            ? (isHardware ? const Color(0xFF10B981) : const Color(0xFF06B6D4))
                            : const Color(0xFFEF4444),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      !isConnected
                          ? 'OFFLINE'
                          : (isHardware ? 'HARDWARE ONLINE' : 'SIMULATION MODE'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                        color: isConnected
                            ? (isHardware ? const Color(0xFF10B981) : const Color(0xFF06B6D4))
                            : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Row 2: 4 Telemetry Metrics Grid (Temp, Humidity, Door, Shelf Load)
          Row(
            children: [
              // Temperature
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.thermostat_outlined,
                  iconColor: isTempWarm ? const Color(0xFFEF4444) : const Color(0xFF06B6D4),
                  label: 'TEMP (DHT22)',
                  value: '${tempC.toStringAsFixed(1)}°C',
                  statusColor: isTempWarm ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 8),
              // Humidity
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.water_drop_outlined,
                  iconColor: const Color(0xFF38BDF8),
                  label: 'HUMIDITY',
                  value: '$humidity%',
                  statusColor: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 8),
              // Door Status
              Expanded(
                child: InkWell(
                  onTap: onToggleDoor,
                  borderRadius: BorderRadius.circular(10),
                  child: _buildMetricTile(
                    icon: isDoorOpen
                        ? Icons.meeting_room_outlined
                        : Icons.door_front_door_outlined,
                    iconColor: isDoorOpen ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    label: 'DOOR SWITCH',
                    value: isDoorOpen ? 'OPEN' : 'CLOSED',
                    statusColor: isDoorOpen ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Total Shelf Load
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.scale_outlined,
                  iconColor: const Color(0xFFA855F7),
                  label: 'SHELF LOAD',
                  value: '${shelfMass.toStringAsFixed(0)}g',
                  statusColor: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Row 3: Quick Action Buttons (Scan Now + Tare Scale)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isScanning ? null : onScanNow,
                  icon: isScanning
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF06B6D4)),
                        )
                      : const Icon(Icons.camera_alt_outlined, size: 16),
                  label: Text(
                    isScanning ? 'Capturing...' : 'Scan Now (OV3660)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF06B6D4),
                    side: const BorderSide(color: Color(0xFF0284C7)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF94A3B8),
                    side: const BorderSide(color: Color(0xFF334155)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    required String label,
    required String value,
    required Color statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1120),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
