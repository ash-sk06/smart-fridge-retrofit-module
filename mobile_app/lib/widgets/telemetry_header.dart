import 'package:flutter/material.dart';
import '../models/inventory_model.dart';

class TelemetryHeader extends StatelessWidget {
  final TelemetryData telemetry;
  final bool isConnected;
  final VoidCallback onToggleDoor;

  const TelemetryHeader({
    super.key,
    required this.telemetry,
    required this.isConnected,
    required this.onToggleDoor,
  });

  @override
  Widget build(BuildContext context) {
    final isDoorOpen = telemetry.doorState.toUpperCase() == 'OPEN';
    final isTempWarm = telemetry.temperatureC > 7.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDoorOpen ? Colors.amber.shade50 : Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDoorOpen ? Colors.amber.shade300 : Colors.blueGrey.shade200,
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          // Row 1: Connection status & Door State
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Server status
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isConnected ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isConnected ? 'ESP32 HUB LIVE' : 'BACKEND OFFLINE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: isConnected ? Colors.green.shade800 : Colors.red.shade800,
                    ),
                  ),
                ],
              ),
              // Door Status Button
              InkWell(
                onTap: onToggleDoor,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDoorOpen ? Colors.red.shade600 : Colors.teal.shade700,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: (isDoorOpen ? Colors.red : Colors.teal).withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isDoorOpen ? Icons.meeting_room_outlined : Icons.door_front_door_outlined,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isDoorOpen ? 'DOOR OPEN (Tap to Close)' : 'DOOR CLOSED (Tap)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 2: Sensor Metrics (Temperature, Humidity, Vision Objects)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Temperature
              Row(
                children: [
                  Icon(
                    Icons.thermostat,
                    size: 20,
                    color: isTempWarm ? Colors.deepOrange : Colors.blue.shade700,
                  ),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${telemetry.temperatureC.toStringAsFixed(1)} °C',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isTempWarm ? Colors.deepOrange : Colors.black87,
                        ),
                      ),
                      const Text(
                        'Fridge Temp',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              // Divider
              Container(height: 24, width: 1, color: Colors.grey.shade300),

              // Humidity
              Row(
                children: [
                  Icon(Icons.water_drop_outlined, size: 20, color: Colors.cyan.shade700),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${telemetry.humidityPct}% RH',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const Text(
                        'Humidity',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              // Divider
              Container(height: 24, width: 1, color: Colors.grey.shade300),

              // Vision AI Status
              Row(
                children: [
                  Icon(Icons.camera_alt_outlined, size: 20, color: Colors.purple.shade700),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${telemetry.detectedObjects.length} Items',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const Text(
                        'YOLO Vision',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
