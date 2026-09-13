import 'dart:async';
import 'package:flutter/material.dart';
import '../models/inventory_model.dart';
import '../services/api_service.dart';
import '../widgets/liquid_gauge_card.dart';
import '../widgets/telemetry_header.dart';
import '../widgets/shopping_list_card.dart';
import '../widgets/camera_vision_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FridgeApiService _apiService = FridgeApiService();
  FridgeInventoryState? _state;
  bool _isConnected = false;
  Timer? _pollingTimer;
  String _currentHost = FridgeApiService.defaultHost;

  @override
  void initState() {
    super.initState();
    _initConnection();
  }

  Future<void> _initConnection() async {
    _currentHost = await _apiService.getHost();
    await _refreshData();
    // Start background polling every 2.5 seconds for live real-time sync
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      _refreshData(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshData({bool silent = false}) async {
    final result = await _apiService.fetchInventory();
    if (mounted) {
      setState(() {
        if (result != null) {
          _state = result;
          _isConnected = true;
        } else {
          _isConnected = false;
        }
      });
      if (!silent && !_isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot reach Flask server at $_currentHost'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showSettingsDialog() {
    final controller = TextEditingController(text: _currentHost);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.wifi_tethering, color: Colors.teal),
              SizedBox(width: 8),
              Text('Server Connection'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the IP address and port of your laptop running server.py:',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Laptop Server Host:Port',
                  hintText: 'e.g. 192.168.1.105:5050',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.computer),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tip: Make sure your phone and laptop are on the same Wi-Fi / Hotspot!',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newHost = controller.text.trim();
                if (newHost.isNotEmpty) {
                  await _apiService.setHost(newHost);
                  setState(() {
                    _currentHost = newHost;
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    _refreshData();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save & Connect'),
            ),
          ],
        );
      },
    );
  }

  void _showDemoSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.science_outlined, color: Colors.purple.shade700),
                  const SizedBox(width: 8),
                  const Text(
                    'Faculty Review Demo Sandbox',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Trigger live inventory and hardware events to demonstrate dynamic UI updates:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              // Action Buttons Grid
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _apiService.simulatePour('zone1', -150.0);
                      _refreshData();
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Text('🥛'),
                    label: const Text('Pour 150ml Milk'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _apiService.simulatePour('zone2', -120.0);
                      _refreshData();
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Text('🍊'),
                    label: const Text('Pour 120ml Juice'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade50),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final currentDoor = _state?.telemetry.doorState ?? 'CLOSED';
                      final nextDoor = currentDoor == 'CLOSED' ? 'OPEN' : 'CLOSED';
                      await _apiService.simulateDoor(nextDoor);
                      _refreshData();
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.sensor_door_outlined, size: 16),
                    label: const Text('Toggle Door Event'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade50),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      // Trigger Low Stock Alert (< 20%)
                      await _apiService.simulatePour('zone1', -850.0);
                      _refreshData();
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                    label: const Text('Trigger Low Stock Alert (<20%)'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final zone1 = _state?.inventory['zone1'];
    final zone2 = _state?.inventory['zone2'];
    final telemetry = _state?.telemetry;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.kitchen_outlined, color: Colors.teal),
            SizedBox(width: 8),
            Text(
              'Smart Fridge Retrofit',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Server Settings',
            onPressed: _showSettingsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => _refreshData(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refreshData(),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 80),
          children: [
            // 1. Climate & Telemetry Status Header
            if (telemetry != null)
              TelemetryHeader(
                telemetry: telemetry,
                isConnected: _isConnected,
                onToggleDoor: () async {
                  final nextDoor =
                      telemetry.doorState == 'CLOSED' ? 'OPEN' : 'CLOSED';
                  await _apiService.simulateDoor(nextDoor);
                  _refreshData();
                },
              )
            else
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Backend Offline',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, color: Colors.red)),
                          Text(
                            'Connecting to $_currentHost...\nTap settings (top right) to change server IP.',
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Section Label
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Text(
                'REAL-TIME LIQUID MONITOR (DUAL-ZONE TRAY)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: Colors.grey,
                ),
              ),
            ),

            // 2. Dual-Zone Liquid Tracking Cards
            if (zone1 != null)
              LiquidGaugeCard(
                item: zone1,
                iconEmoji: '🥛',
                onPour: () async {
                  await _apiService.simulatePour('zone1', -150.0);
                  _refreshData();
                },
              ),

            if (zone2 != null)
              LiquidGaugeCard(
                item: zone2,
                iconEmoji: '🍊',
                onPour: () async {
                  await _apiService.simulatePour('zone2', -120.0);
                  _refreshData();
                },
              ),

            // Section Label
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Text(
                'VISION & PANTRY INVENTORY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: Colors.grey,
                ),
              ),
            ),

            // 3. Overhead Camera Vision Snapshot
            if (telemetry != null)
              CameraVisionCard(
                telemetry: telemetry,
                baseUrl: _apiService.baseUrl,
                onRefresh: () => _refreshData(),
              ),

            // 4. Smart Automated Grocery / Shopping List
            if (_state != null)
              ShoppingListCard(
                items: _state!.shoppingList,
                onToggleItem: (item) {
                  setState(() {
                    item.isBought = !item.isBought;
                  });
                },
                onClear: () async {
                  await _apiService.clearShoppingList();
                  _refreshData();
                },
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showDemoSheet,
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Demo Sandbox'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
    );
  }
}
