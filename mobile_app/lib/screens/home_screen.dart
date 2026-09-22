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
  int _currentTabIndex = 0;

  FridgeStatus? _status = FridgeStatus.defaultInitial();
  FridgeInventoryState? _state = FridgeInventoryState.defaultInitial();
  List<SensorDiagnostic> _sensors = [];
  List<ActivityEvent> _activity = [];
  DeviceSettings? _settings;

  bool _isConnected = false;
  bool _isScanning = false;
  Timer? _pollingTimer;
  String _currentHost = FridgeApiService.defaultHost;

  @override
  void initState() {
    super.initState();
    _initConnection();
  }

  Future<void> _initConnection() async {
    _currentHost = await _apiService.getHost();
    await _refreshAll();
    // Background polling every 2.5s for live hardware telemetry sync
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      _refreshAll(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshAll({bool silent = false}) async {
    if (!mounted) return;
    try {
      final statusFuture = _apiService.fetchStatus();
      final inventoryFuture = _apiService.fetchInventory();

      final status = await statusFuture;
      final inventory = await inventoryFuture;

      if (!mounted) return;
      setState(() {
        if (status != null || inventory != null) {
          if (status != null) _status = status;
          if (inventory != null) _state = inventory;
          _isConnected = true;
        } else {
          _isConnected = false;
        }
      });

      // Also refresh sensors, activity, settings if current tab requires it
      if (_currentTabIndex == 2) {
        final sensors = await _apiService.fetchSensors();
        if (mounted) setState(() => _sensors = sensors);
      } else if (_currentTabIndex == 3) {
        final activity = await _apiService.fetchActivity();
        if (mounted) setState(() => _activity = activity);
      } else if (_currentTabIndex == 4 && _settings == null) {
        final settings = await _apiService.fetchSettings();
        if (mounted) setState(() => _settings = settings);
      }
    } catch (_) {
      if (mounted) setState(() => _isConnected = false);
    }
  }

  Future<void> _triggerScan() async {
    setState(() => _isScanning = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Triggering OV3660 camera strobe & YOLOv8 inference...'),
        duration: Duration(seconds: 2),
      ),
    );
    final result = await _apiService.triggerScan();
    setState(() => _isScanning = false);
    await _refreshAll();
    if (result != null && mounted) {
      final count = result['detections_count'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scan complete! $count items tagged by YOLOv8.'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _calibrateScales() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        title: const Text('Tare Load Cells', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Ensure both Zone 1 and Zone 2 shelves are completely empty or have only the empty tray before zeroing.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            child: const Text('Zero Scales'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _apiService.calibrateScales();
      await _refreshAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Scales successfully zeroed!' : 'Tare calibration failed.'),
            backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _simulateLocalResetFull() {
    setState(() {
      _state = FridgeInventoryState.defaultInitial();
      _status = FridgeStatus.defaultInitial();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ Reset Complete! All containers restored to 100% full capacity.'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
    _apiService.triggerSimulation('reset_full').then((_) => _refreshAll(silent: true));
  }

  void _simulateLocalToggleDoor() {
    _state ??= FridgeInventoryState.defaultInitial();
    _status ??= FridgeStatus.defaultInitial();
    final currentDoor = _state!.telemetry.doorState;
    final nextDoor = currentDoor == 'CLOSED' ? 'OPEN' : 'CLOSED';

    setState(() {
      _state = FridgeInventoryState(
        inventory: _state!.inventory,
        telemetry: TelemetryData(
          doorState: nextDoor,
          temperatureC: nextDoor == 'OPEN' ? 6.2 : 3.8,
          humidityPct: nextDoor == 'OPEN' ? 76 : 62,
          lastDeltaDairy: _state!.telemetry.lastDeltaDairy,
          lastDeltaDrinks: _state!.telemetry.lastDeltaDrinks,
          latestImagePath: _state!.telemetry.latestImagePath,
          detectedObjects: _state!.telemetry.detectedObjects,
        ),
        shoppingList: _state!.shoppingList,
      );
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nextDoor == 'OPEN' ? '🚪 Door OPENED! Hall sensor triggered & strobe active.' : '🚪 Door CLOSED. Vision scan triggered.'),
          duration: const Duration(seconds: 2),
          backgroundColor: nextDoor == 'OPEN' ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
        ),
      );
    }
    final simAction = nextDoor == 'OPEN' ? 'door_open' : 'door_close';
    _apiService.triggerSimulation(simAction).then((_) => _refreshAll(silent: true));
  }

  void _simulateLocalPour(String zoneId, double deltaWeight) {
    _state ??= FridgeInventoryState.defaultInitial();
    final item = _state!.inventory[zoneId];
    if (item != null) {
      setState(() {
        final newWeight = (item.currentWeight + deltaWeight).clamp(item.tareWeight, 5000.0);
        final netWeight = (newWeight - item.tareWeight).clamp(0.0, 5000.0);
        final density = zoneId == 'zone1' ? 1.032 : 1.045;
        final remainingVol = (netWeight / density).clamp(0.0, item.fullVolume);
        final fillPct = ((remainingVol / item.fullVolume) * 100.0).clamp(0.0, 100.0);
        final isLow = fillPct < 20.0;
        item.currentWeight = newWeight;
        item.remainingVolume = remainingVol;
        item.fillPercentage = fillPct;
        item.status = isLow ? 'LOW_STOCK' : 'OPTIMAL';
        if (isLow && !_state!.shoppingList.any((s) => s.itemName.contains(item.itemName))) {
          _state!.shoppingList.insert(0, ShoppingItem(
            id: DateTime.now().millisecondsSinceEpoch,
            itemName: item.itemName,
            reason: 'AUTO-REORDER: Low Stock (${fillPct.toInt()}%)',
            isBought: false,
            addedAt: 'Just now',
          ));
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🥛 Poured ${deltaWeight.abs().toInt()}ml from ${item.itemName} (${item.fillPercentage.toInt()}% remaining)'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF06B6D4),
          ),
        );
      }
    }
    _apiService.simulatePour(zoneId, deltaWeight).then((_) => _refreshAll(silent: true));
  }

  void _simulateLocalLowStock(String zoneId) {
    _state ??= FridgeInventoryState.defaultInitial();
    final item = _state!.inventory[zoneId];
    if (item != null) {
      setState(() {
        item.currentWeight = zoneId == 'zone1' ? 195.0 : 110.0;
        item.remainingVolume = zoneId == 'zone1' ? 145.0 : 75.0;
        item.fillPercentage = zoneId == 'zone1' ? 15.0 : 15.0;
        item.status = 'LOW_STOCK';
        if (!_state!.shoppingList.any((s) => s.itemName.contains(item.itemName))) {
          _state!.shoppingList.insert(0, ShoppingItem(
            id: DateTime.now().millisecondsSinceEpoch,
            itemName: item.itemName,
            reason: 'AUTO-REORDER: Low Stock (15%)',
            isBought: false,
            addedAt: 'Just now',
          ));
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🚨 LOW STOCK ALERT: ${item.itemName} at 15%! Auto-reorder queued.'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
    _apiService.triggerLowStock(zoneId).then((_) => _refreshAll(silent: true));
  }

  Widget _buildDemoChip(String label, VoidCallback onTap, {bool isAlert = false, bool isSuccess = false}) {
    Color bg = const Color(0xFF1E293B);
    Color fg = const Color(0xFFE2E8F0);
    Color border = const Color(0xFF334155);

    if (isAlert) {
      bg = const Color(0xFFEF4444).withOpacity(0.18);
      fg = const Color(0xFFEF4444);
      border = const Color(0xFFEF4444).withOpacity(0.4);
    } else if (isSuccess) {
      bg = const Color(0xFF10B981).withOpacity(0.18);
      fg = const Color(0xFF10B981);
      border = const Color(0xFF10B981).withOpacity(0.4);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
        ),
      ),
    );
  }

  void _showCalibrateDialog(InventoryItem item) {
    final nameCtrl = TextEditingController(text: item.itemName);
    final volCtrl = TextEditingController(text: item.fullVolume.toInt().toString());
    final tareCtrl = TextEditingController(text: item.tareWeight.toInt().toString());
    final expiryCtrl = TextEditingController(text: item.expiryDate);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        title: Row(
          children: [
            const Icon(Icons.tune, color: Color(0xFF10B981), size: 20),
            const SizedBox(width: 8),
            Text('Calibrate ${item.zoneId.toUpperCase()}',
                style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: volCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Full Rated Volume (ml)',
                  labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: tareCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Container Tare Mass (g)',
                  labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: expiryCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Expiry Date (YYYY-MM-DD)',
                  labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final vol = double.tryParse(volCtrl.text.trim());
              final tare = double.tryParse(tareCtrl.text.trim());
              final name = nameCtrl.text.trim();
              final expiry = expiryCtrl.text.trim();

              await _apiService.updateItemCalibration(
                zone: item.zoneId,
                itemName: name.isNotEmpty ? name : null,
                fullVolume: vol,
                tareWeight: tare,
                expiryDate: expiry.isNotEmpty ? expiry : null,
              );
              if (mounted) {
                Navigator.pop(ctx);
                _refreshAll();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save Calibration'),
          ),
        ],
      ),
    );
  }

  void _showAddShoppingDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        title: const Text('Add Replenishment Item', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Grocery / Item Name',
            labelStyle: TextStyle(color: Color(0xFF94A3B8)),
            hintText: 'e.g. Greek Yogurt, Milk',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                await _apiService.addShoppingItem(name, 'Manual');
                if (mounted) {
                  Navigator.pop(ctx);
                  _refreshAll();
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            child: const Text('Add Item'),
          ),
        ],
      ),
    );
  }

  void _showSandboxSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
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
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.science_outlined, color: Color(0xFFA78BFA), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Prototype Demonstration Sandbox',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF8FAFC),
                        ),
                      ),
                      Text(
                        '[DEMO MODE] Triggers hardware events for review presentation',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      if (context.mounted) Navigator.pop(context);
                      _simulateLocalPour('zone1', -150.0);
                    },
                    icon: const Text('🥛'),
                    label: const Text('Pour 150ml Milk'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: const Color(0xFFF8FAFC),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (context.mounted) Navigator.pop(context);
                      _simulateLocalPour('zone2', -120.0);
                    },
                    icon: const Text('🍊'),
                    label: const Text('Pour 120ml Juice'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: const Color(0xFFF8FAFC),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (context.mounted) Navigator.pop(context);
                      _simulateLocalPour('zone1', -150.0);
                      _simulateLocalPour('zone2', -120.0);
                    },
                    icon: const Icon(Icons.local_drink, size: 16, color: Color(0xFF06B6D4)),
                    label: const Text('Pour Both'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: const Color(0xFFF8FAFC),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (context.mounted) Navigator.pop(context);
                      _simulateLocalToggleDoor();
                    },
                    icon: const Icon(Icons.sensor_door_outlined, size: 16, color: Color(0xFFF59E0B)),
                    label: const Text('Toggle Door Event'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: const Color(0xFFF8FAFC),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (context.mounted) Navigator.pop(context);
                      _simulateLocalLowStock('zone1');
                    },
                    icon: const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFEF4444)),
                    label: const Text('Low Stock Milk (<20%)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444).withOpacity(0.2),
                      foregroundColor: const Color(0xFFEF4444),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (context.mounted) Navigator.pop(context);
                      _simulateLocalLowStock('zone2');
                    },
                    icon: const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFEF4444)),
                    label: const Text('Low Stock Juice (<20%)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444).withOpacity(0.2),
                      foregroundColor: const Color(0xFFEF4444),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (context.mounted) Navigator.pop(context);
                      _simulateLocalResetFull();
                    },
                    icon: const Icon(Icons.replay_rounded, size: 16, color: Color(0xFF10B981)),
                    label: const Text('Reset All Full (100%)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981).withOpacity(0.2),
                      foregroundColor: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSettingsDialog() {
    final controller = TextEditingController(text: _currentHost);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131B2E),
          title: const Row(
            children: [
              Icon(Icons.wifi_tethering, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text('Server Connection', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the IP address or host running server.py:',
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Server Host / IP:Port',
                  labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                  hintText: 'e.g. smart-fridge-retrofit-module.onrender.com',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.router, color: Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 10),
              const Text('Quick Connection Presets:',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        controller.text = 'smart-fridge-retrofit-module.onrender.com';
                      },
                      icon: const Icon(Icons.cloud_outlined, size: 14),
                      label: const Text('Live Cloud', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF38BDF8),
                        side: const BorderSide(color: Color(0xFF0284C7)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        controller.text = '192.168.1.23:5050';
                      },
                      icon: const Icon(Icons.laptop_chromebook, size: 14),
                      label: const Text('Local Host', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFA78BFA),
                        side: const BorderSide(color: Color(0xFF7C3AED)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Tip: Cloud uses secure HTTPS; Local uses HTTP port 5050.',
                style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
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
                  setState(() => _currentHost = newHost);
                  if (mounted) {
                    Navigator.pop(context);
                    _refreshAll();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
              child: const Text('Save & Connect'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.kitchen, color: Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FridgeIQ Console',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'Retrofit Module Interface',
                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.science_outlined, color: Color(0xFFA78BFA)),
            tooltip: 'Demo Sandbox',
            onPressed: _showSandboxSheet,
          ),
          IconButton(
            icon: const Icon(Icons.wifi_tethering, color: Color(0xFF64748B)),
            tooltip: 'Connection IP',
            onPressed: _showSettingsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => _refreshAll(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refreshAll(),
        color: const Color(0xFF10B981),
        backgroundColor: const Color(0xFF131B2E),
        child: IndexedStack(
          index: _currentTabIndex,
          children: [
            _buildDashboardTab(),
            _buildInventoryTab(),
            _buildSensorsTab(),
            _buildActivityTab(),
            _buildSettingsTab(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) {
          setState(() => _currentTabIndex = index);
          _refreshAll(silent: true);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sensors_outlined),
            activeIcon: Icon(Icons.sensors),
            label: 'Sensors',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'Activity',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  // --- TAB 0: DASHBOARD ---
  Widget _buildDashboardTab() {
    final zone1 = _state?.inventory['zone1'];
    final zone2 = _state?.inventory['zone2'];
    final telemetry = _state?.telemetry ??
        TelemetryData(
          doorState: _status?.doorState ?? 'CLOSED',
          temperatureC: _status?.temperatureC ?? 4.0,
          humidityPct: _status?.humidityPct ?? 65,
          lastDeltaDairy: 0.0,
          lastDeltaDrinks: 0.0,
          latestImagePath: '',
          detectedObjects: [],
        );

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // Offline Warning banner if disconnected
        if (!_isConnected)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEF4444)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFEF4444)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hardware Module Offline',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                      ),
                      Text(
                        'Cannot reach server at $_currentHost. Tap the Wi-Fi icon top-right to edit server IP.',
                        style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Environmental Glance & Controls Header
        TelemetryHeader(
          status: _status,
          telemetry: telemetry,
          isConnected: _isConnected,
          isScanning: _isScanning,
          onToggleDoor: () => _simulateLocalToggleDoor(),
          onScanNow: _triggerScan,
          onTareScale: _calibrateScales,
        ),

        // Prototype Live Review Demo Dock
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.35)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.science_outlined, size: 14, color: Color(0xFFA78BFA)),
                  SizedBox(width: 6),
                  Text(
                    'FACULTY REVIEW & DEMO CONTROLS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: Color(0xFFA78BFA),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildDemoChip('🥛 Pour 150ml Milk', () {
                      _simulateLocalPour('zone1', -150.0);
                    }),
                    const SizedBox(width: 6),
                    _buildDemoChip('🍊 Pour 120ml Juice', () {
                      _simulateLocalPour('zone2', -120.0);
                    }),
                    const SizedBox(width: 6),
                    _buildDemoChip('🚨 Low Stock Milk', () {
                      _simulateLocalLowStock('zone1');
                    }, isAlert: true),
                    const SizedBox(width: 6),
                    _buildDemoChip('🚨 Low Stock Juice', () {
                      _simulateLocalLowStock('zone2');
                    }, isAlert: true),
                    const SizedBox(width: 6),
                    _buildDemoChip('🚪 Toggle Door', () {
                      _simulateLocalToggleDoor();
                    }),
                    const SizedBox(width: 6),
                    _buildDemoChip('🔄 Reset All 100%', () {
                      _simulateLocalResetFull();
                    }, isSuccess: true),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Dual Load Cell Liquid Tray Section
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            'DUAL-ZONE LIQUID LEVEL (HX711 LOAD CELLS)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: Color(0xFF64748B),
            ),
          ),
        ),

        if (zone1 != null)
          LiquidGaugeCard(
            item: zone1,
            iconEmoji: '🥛',
            onPour: () => _simulateLocalPour('zone1', -150.0),
            onLowStock: () => _simulateLocalLowStock('zone1'),
            onCalibrate: () => _showCalibrateDialog(zone1),
          ),

        if (zone2 != null)
          LiquidGaugeCard(
            item: zone2,
            iconEmoji: '🍊',
            onPour: () => _simulateLocalPour('zone2', -120.0),
            onLowStock: () => _simulateLocalLowStock('zone2'),
            onCalibrate: () => _showCalibrateDialog(zone2),
          ),

        // Vision Pod Card
        CameraVisionCard(
          telemetry: telemetry,
          baseUrl: _apiService.baseUrl,
          isScanning: _isScanning,
          onRefresh: () => _refreshAll(),
          onTriggerScan: _triggerScan,
        ),

        // Replenishment / Shopping List
        if (_state != null)
          ShoppingListCard(
            items: _state!.shoppingList,
            onToggleItem: (item) async {
              setState(() => item.isBought = !item.isBought);
              await _apiService.toggleShoppingItem(item.id);
              _refreshAll(silent: true);
            },
            onDeleteItem: (item) async {
              await _apiService.deleteShoppingItem(item.id);
              _refreshAll();
            },
            onClear: () async {
              await _apiService.clearShoppingList();
              _refreshAll();
            },
            onAddItem: _showAddShoppingDialog,
          ),
      ],
    );
  }

  // --- TAB 1: INVENTORY & CALIBRATION ---
  Widget _buildInventoryTab() {
    final items = _state?.inventory.values.toList() ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Container Calibrations',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _calibrateScales,
              icon: const Icon(Icons.exposure_zero, size: 14),
              label: const Text('Tare Scales', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                foregroundColor: const Color(0xFF10B981),
                side: const BorderSide(color: Color(0xFF10B981)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Each liquid zone uses a dedicated 5kg strain-gauge load cell with HX711 24-bit ADC. Calibrate container tare mass and full volume capacity below.',
          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 16),

        if (items.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          )
        else
          ...items.map((item) {
            return LiquidGaugeCard(
              item: item,
              iconEmoji: item.zoneId == 'zone1' ? '🥛' : '🍊',
              onPour: () {
                final delta = item.zoneId == 'zone1' ? -150.0 : -120.0;
                _simulateLocalPour(item.zoneId, delta);
              },
              onLowStock: () {
                _simulateLocalLowStock(item.zoneId);
              },
              onCalibrate: () => _showCalibrateDialog(item),
            );
          }),
      ],
    );
  }

  // --- TAB 2: SENSORS DIAGNOSTICS ---
  Widget _buildSensorsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Hardware Telemetry Pod',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF10B981)),
              onPressed: () async {
                final s = await _apiService.fetchSensors();
                setState(() => _sensors = s);
              },
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Real-time diagnostic health across all physical retrofit sensors and computing pods.',
          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 16),

        if (_sensors.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          )
        else
          ..._sensors.map((s) {
            final isOnline = s.status == 'ONLINE' || s.status == 'READY';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF131B2E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isOnline
                          ? const Color(0xFF10B981).withOpacity(0.15)
                          : const Color(0xFFEF4444).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      s.id.contains('loadcell')
                          ? Icons.scale
                          : (s.id.contains('dht')
                              ? Icons.thermostat
                              : (s.id.contains('door')
                                  ? Icons.sensor_door
                                  : (s.id.contains('cam') ? Icons.camera_alt : Icons.psychology))),
                      color: isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              s.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isOnline
                                    ? const Color(0xFF10B981).withOpacity(0.15)
                                    : const Color(0xFFEF4444).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isOnline
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444),
                                ),
                              ),
                              child: Text(
                                s.status,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isOnline
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.type,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Value: ${s.value}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF38BDF8),
                              ),
                            ),
                            Text(
                              s.lastReading,
                              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // --- TAB 3: ACTIVITY LOG ---
  Widget _buildActivityTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Physical Event Audit Trail',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF10B981)),
              onPressed: () async {
                final a = await _apiService.fetchActivity();
                setState(() => _activity = a);
              },
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Chronological log of door transitions, camera strobe triggers, and calibration events.',
          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 16),

        if (_activity.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'No activity events recorded yet.',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _activity.length,
            itemBuilder: (context, index) {
              final ev = _activity[index];
              final isDoor = ev.eventType.contains('DOOR');
              final isScan = ev.eventType.contains('SCAN');

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF131B2E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDoor
                            ? const Color(0xFFF59E0B).withOpacity(0.15)
                            : (isScan
                                ? const Color(0xFF8B5CF6).withOpacity(0.15)
                                : const Color(0xFF10B981).withOpacity(0.15)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isDoor
                            ? Icons.sensor_door
                            : (isScan ? Icons.camera_alt : Icons.bolt),
                        size: 16,
                        color: isDoor
                            ? const Color(0xFFF59E0B)
                            : (isScan
                                ? const Color(0xFFA78BFA)
                                : const Color(0xFF10B981)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                ev.eventType,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              Text(
                                ev.timestamp,
                                style: const TextStyle(
                                    fontSize: 10, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ev.message,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  // --- TAB 4: SETTINGS ---
  Widget _buildSettingsTab() {
    final settings = _settings;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Hardware Configuration',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 4),
        const Text(
          'Fine-tune physical sensor thresholds and automated alerting policies.',
          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 16),

        if (settings == null)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Temp threshold
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Max Safe Temperature (°C)',
                        style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 13)),
                    Text('${settings.tempMaxThreshold.toStringAsFixed(1)}°C',
                        style: const TextStyle(
                            color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: settings.tempMaxThreshold,
                  min: 2.0,
                  max: 15.0,
                  divisions: 26,
                  activeColor: const Color(0xFF06B6D4),
                  onChanged: (val) {
                    setState(() => settings.tempMaxThreshold = val);
                  },
                ),
                const Divider(color: Color(0xFF1E293B)),

                // Low stock threshold
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Low Stock Alert Threshold (%)',
                        style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 13)),
                    Text('${settings.lowStockThresholdPct.toStringAsFixed(0)}%',
                        style: const TextStyle(
                            color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: settings.lowStockThresholdPct,
                  min: 5.0,
                  max: 50.0,
                  divisions: 9,
                  activeColor: const Color(0xFFF59E0B),
                  onChanged: (val) {
                    setState(() => settings.lowStockThresholdPct = val);
                  },
                ),
                const Divider(color: Color(0xFF1E293B)),

                // Door alarm delay
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Door Ajar Alarm Delay (seconds)',
                        style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 13)),
                    Text('${settings.doorAlarmDelaySec}s',
                        style: const TextStyle(
                            color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: settings.doorAlarmDelaySec.toDouble(),
                  min: 15.0,
                  max: 180.0,
                  divisions: 11,
                  activeColor: const Color(0xFFEF4444),
                  onChanged: (val) {
                    setState(() => settings.doorAlarmDelaySec = val.toInt());
                  },
                ),
                const Divider(color: Color(0xFF1E293B)),

                // LED Strobe toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('LED Strobe On Door Open',
                      style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 13)),
                  subtitle: const Text('Flashes auxiliary illuminator for camera capture',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                  value: settings.ledStrobeOnOpen,
                  activeColor: const Color(0xFF10B981),
                  onChanged: (val) {
                    setState(() => settings.ledStrobeOnOpen = val);
                  },
                ),
                const Divider(color: Color(0xFF1E293B)),

                // Auto Shopping List toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Automated Grocery Replenishment',
                      style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 13)),
                  subtitle: const Text('Pushes depleted liquids directly to shopping list',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                  value: settings.autoShoppingList,
                  activeColor: const Color(0xFF10B981),
                  onChanged: (val) {
                    setState(() => settings.autoShoppingList = val);
                  },
                ),
                const SizedBox(height: 16),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final ok = await _apiService.updateSettings(settings);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'Hardware settings saved!'
                                : 'Failed to save settings.'),
                            backgroundColor:
                                ok ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save Hardware Settings'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 20),

        // Server Connection card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF131B2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'IoT Module Network Connection',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                'Active Host: $_currentHost',
                style: const TextStyle(fontSize: 12, color: Color(0xFF38BDF8)),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _showSettingsDialog,
                icon: const Icon(Icons.wifi_tethering, size: 16),
                label: const Text('Change Server Host / IP'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: const Color(0xFFE2E8F0),
                  side: const BorderSide(color: Color(0xFF334155)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
