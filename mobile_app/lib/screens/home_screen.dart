import 'dart:async';
import 'package:flutter/material.dart';
import '../models/inventory_model.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
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
  final NotificationService _notificationService = NotificationService();
  final Set<String> _alertedLowStockZones = {};
  int _currentTabIndex = 0;

  DateTime? _doorOpenedTimestamp;
  bool _doorAjarAlertSent = false;
  bool _coldChainAlertSent = false;
  Timer? _doorCheckTimer;

  FridgeStatus? _status = FridgeStatus.defaultInitial();
  FridgeInventoryState? _state = FridgeInventoryState.defaultInitial();
  List<SensorDiagnostic> _sensors = SensorDiagnostic.defaultSensors();
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
    await _notificationService.initialize();
    await _refreshAll();
    // Background polling every 2.5s for live hardware telemetry sync
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      _refreshAll(silent: true);
    });
    // 1-second interval timer for precise Door-Ajar (> 45s) and Microclimate alerts
    _doorCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _evaluateAlerts();
    });
  }

  @override
  void dispose() {
    _doorCheckTimer?.cancel();
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
          if (inventory != null) {
            _state = inventory;
            for (final item in inventory.inventory.values) {
              _checkAndNotifyLowStock(item);
            }
          }
          if (status != null) {
            _status = status;
          } else if (inventory != null) {
            _status = FridgeStatus(
              fridgeName: _status?.fridgeName ?? 'Smart Retrofit Refrigerator',
              hardwareMode: _status?.hardwareMode ?? 'Cloud AI Vision Inference',
              hardwareConnected: true,
              lastSync: 'Live',
              doorState: inventory.telemetry.doorState,
              doorOpenDurationSec: _doorOpenedTimestamp != null
                  ? DateTime.now().difference(_doorOpenedTimestamp!).inSeconds
                  : 0,
              temperatureC: inventory.telemetry.temperatureC,
              humidityPct: inventory.telemetry.humidityPct,
              shelfMassG: _status?.shelfMassG ?? 1575.0,
              maxRatedShelfG: _status?.maxRatedShelfG ?? 10000.0,
              alerts: _status?.alerts ?? [],
            );
          }
          _isConnected = true;
        } else {
          _isConnected = false;
        }
      });

      _evaluateAlerts();

      // Also refresh sensors, activity, settings if current tab requires it
      if (_currentTabIndex == 2) {
        final sensors = await _apiService.fetchSensors();
        if (mounted && sensors.isNotEmpty) setState(() => _sensors = sensors);
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

  /// Core evaluator for Door-Ajar Buzzer (> 45s) and Cold-Chain Microclimate (> 4.5°C) alerts
  void _evaluateAlerts() {
    final doorState = (_state?.telemetry.doorState.isNotEmpty == true
            ? _state!.telemetry.doorState
            : (_status?.doorState ?? 'CLOSED'))
        .toUpperCase();
    final tempC = _state?.telemetry.temperatureC ?? _status?.temperatureC ?? 3.8;

    // 1. Door-Ajar Buzzer & Alert (> 45 seconds threshold)
    if (doorState == 'OPEN') {
      _doorOpenedTimestamp ??= DateTime.now();
      final durationSec = DateTime.now().difference(_doorOpenedTimestamp!).inSeconds;
      if (durationSec >= 45 && !_doorAjarAlertSent) {
        _doorAjarAlertSent = true;
        _notificationService.showDoorAjarNotification(durationSec: durationSec);
      }
    } else {
      if (_doorAjarAlertSent) {
        _notificationService.cancelDoorAjarNotification();
      }
      _doorOpenedTimestamp = null;
      _doorAjarAlertSent = false;
    }

    // 2. Cold-Chain Microclimate Alert (> 4.5°C threshold)
    if (tempC > 4.5) {
      if (!_coldChainAlertSent) {
        _coldChainAlertSent = true;
        _notificationService.showColdChainAlertNotification(temperatureC: tempC);
      }
    } else {
      _coldChainAlertSent = false;
    }
  }

  void _checkAndNotifyLowStock(InventoryItem item) {
    if (item.fillPercentage < 20.0 || item.status == 'LOW_STOCK') {
      if (!_alertedLowStockZones.contains(item.zoneId)) {
        _alertedLowStockZones.add(item.zoneId);
        _notificationService.showLowStockNotification(
          itemName: item.itemName,
          remainingVolumeMl: item.remainingVolume.toInt(),
          fillPercentage: item.fillPercentage.toInt(),
          zoneId: item.zoneId,
        );
      }
    } else {
      // Re-arm alert when container is refilled / restocked above 20%
      _alertedLowStockZones.remove(item.zoneId);
    }
  }

  void _simulateLocalResetFull() {
    _alertedLowStockZones.clear();
    _doorOpenedTimestamp = null;
    _doorAjarAlertSent = false;
    _coldChainAlertSent = false;
    _notificationService.cancelDoorAjarNotification();
    setState(() {
      _state = FridgeInventoryState.defaultInitial();
      _status = FridgeStatus.defaultInitial();
      _sensors = SensorDiagnostic.defaultSensors();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ Reset Complete! All containers & sensors restored to 100% capacity.'),
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
    final currentDoor = (_state!.telemetry.doorState.isNotEmpty
            ? _state!.telemetry.doorState
            : _status!.doorState)
        .toUpperCase();
    final nextDoor = currentDoor == 'CLOSED' ? 'OPEN' : 'CLOSED';
    final nextTemp = nextDoor == 'OPEN' ? 6.2 : 3.8;
    final nextHum = nextDoor == 'OPEN' ? 76 : 62;

    if (nextDoor == 'OPEN') {
      _doorOpenedTimestamp = DateTime.now();
      _doorAjarAlertSent = false;
    } else {
      if (_doorAjarAlertSent) {
        _notificationService.cancelDoorAjarNotification();
      }
      _doorOpenedTimestamp = null;
      _doorAjarAlertSent = false;
    }

    setState(() {
      _state = FridgeInventoryState(
        inventory: _state!.inventory,
        telemetry: TelemetryData(
          doorState: nextDoor,
          temperatureC: nextTemp,
          humidityPct: nextHum,
          lastDeltaDairy: _state!.telemetry.lastDeltaDairy,
          lastDeltaDrinks: _state!.telemetry.lastDeltaDrinks,
          latestImagePath: _state!.telemetry.latestImagePath,
          detectedObjects: _state!.telemetry.detectedObjects,
        ),
        shoppingList: _state!.shoppingList,
      );
      _status = FridgeStatus(
        fridgeName: _status!.fridgeName,
        hardwareMode: _status!.hardwareMode,
        hardwareConnected: _status!.hardwareConnected,
        lastSync: 'Live',
        doorState: nextDoor,
        doorOpenDurationSec: nextDoor == 'OPEN' ? 1 : 0,
        temperatureC: nextTemp,
        humidityPct: nextHum,
        shelfMassG: _status!.shelfMassG,
        maxRatedShelfG: _status!.maxRatedShelfG,
        alerts: [
          if (nextTemp > 4.5) 'COLD_CHAIN_TEMPERATURE_EXCEEDED (> 4.5°C)',
        ],
      );
      _sensors = _sensors.map((s) {
        if (s.id == 'reed_door') {
          return SensorDiagnostic(
            id: s.id,
            name: s.name,
            type: s.type,
            status: s.status,
            value: nextDoor,
            detail: s.detail,
            lastReading: 'Live Interrupt',
          );
        } else if (s.id == 'dht22') {
          return SensorDiagnostic(
            id: s.id,
            name: s.name,
            type: s.type,
            status: s.status,
            value: '$nextTemp°C / $nextHum% RH',
            detail: s.detail,
            lastReading: 'Live I/O',
          );
        }
        return s;
      }).toList();
    });

    _evaluateAlerts();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nextDoor == 'OPEN'
              ? '🚪 Door OPENED! Hall sensor triggered & microclimate warming.'
              : '🚪 Door CLOSED. Camera strobe triggered & temperature stabilized.'),
          duration: const Duration(seconds: 2),
          backgroundColor:
              nextDoor == 'OPEN' ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
        ),
      );
    }
    _apiService.simulateDoor(nextDoor).then((_) {
      final simAction = nextDoor == 'OPEN' ? 'door_open' : 'door_close';
      _apiService.triggerSimulation(simAction).then((_) => _refreshAll(silent: true));
    });
  }

  /// Instant test trigger: simulates leaving door open for > 45s
  void _simulateDoorAjarDemo() {
    _doorOpenedTimestamp = DateTime.now().subtract(const Duration(seconds: 48));
    _doorAjarAlertSent = false;
    _simulateLocalToggleDoorForceOpen();
  }

  void _simulateLocalToggleDoorForceOpen() {
    _state ??= FridgeInventoryState.defaultInitial();
    _status ??= FridgeStatus.defaultInitial();
    const nextDoor = 'OPEN';
    const nextTemp = 6.4;
    const nextHum = 78;

    _doorOpenedTimestamp ??= DateTime.now().subtract(const Duration(seconds: 48));
    _doorAjarAlertSent = false;

    setState(() {
      _state = FridgeInventoryState(
        inventory: _state!.inventory,
        telemetry: TelemetryData(
          doorState: nextDoor,
          temperatureC: nextTemp,
          humidityPct: nextHum,
          lastDeltaDairy: _state!.telemetry.lastDeltaDairy,
          lastDeltaDrinks: _state!.telemetry.lastDeltaDrinks,
          latestImagePath: _state!.telemetry.latestImagePath,
          detectedObjects: _state!.telemetry.detectedObjects,
        ),
        shoppingList: _state!.shoppingList,
      );
      _status = FridgeStatus(
        fridgeName: _status!.fridgeName,
        hardwareMode: _status!.hardwareMode,
        hardwareConnected: _status!.hardwareConnected,
        lastSync: 'Live',
        doorState: nextDoor,
        doorOpenDurationSec: 48,
        temperatureC: nextTemp,
        humidityPct: nextHum,
        shelfMassG: _status!.shelfMassG,
        maxRatedShelfG: _status!.maxRatedShelfG,
        alerts: const [
          'DOOR_AJAR_WARNING (> 45s)',
          'COLD_CHAIN_TEMPERATURE_EXCEEDED (> 4.5°C)',
        ],
      );
    });

    _evaluateAlerts();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚨 Simulated Door-Ajar (> 45s) & Microclimate rise! Buzzer triggered.'),
          duration: Duration(seconds: 3),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  /// Instant test trigger: simulates cold-chain temperature rise (> 4.5°C)
  void _simulateColdChainDemo() {
    _coldChainAlertSent = false;
    const nextTemp = 6.4;
    setState(() {
      if (_state != null) {
        _state = FridgeInventoryState(
          inventory: _state!.inventory,
          telemetry: TelemetryData(
            doorState: _state!.telemetry.doorState,
            temperatureC: nextTemp,
            humidityPct: 78,
            lastDeltaDairy: _state!.telemetry.lastDeltaDairy,
            lastDeltaDrinks: _state!.telemetry.lastDeltaDrinks,
            latestImagePath: _state!.telemetry.latestImagePath,
            detectedObjects: _state!.telemetry.detectedObjects,
          ),
          shoppingList: _state!.shoppingList,
        );
      }
      if (_status != null) {
        _status = FridgeStatus(
          fridgeName: _status!.fridgeName,
          hardwareMode: _status!.hardwareMode,
          hardwareConnected: _status!.hardwareConnected,
          lastSync: 'Live',
          doorState: _status!.doorState,
          doorOpenDurationSec: _status!.doorOpenDurationSec,
          temperatureC: nextTemp,
          humidityPct: 78,
          shelfMassG: _status!.shelfMassG,
          maxRatedShelfG: _status!.maxRatedShelfG,
          alerts: const ['COLD_CHAIN_TEMPERATURE_EXCEEDED (> 4.5°C)'],
        );
      }
    });

    _evaluateAlerts();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Temperature increased to 6.4°C (> 4.5°C threshold)! Alert fired.'),
          duration: Duration(seconds: 3),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
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
        if (isLow) {
          _checkAndNotifyLowStock(item);
          if (!_state!.shoppingList.any((s) => s.itemName.contains(item.itemName))) {
            _state!.shoppingList.insert(0, ShoppingItem(
              id: DateTime.now().millisecondsSinceEpoch,
              itemName: item.itemName,
              reason: 'AUTO-REORDER: Low Stock (${fillPct.toInt()}%)',
              isBought: false,
              addedAt: 'Just now',
            ));
          }
        } else {
          _alertedLowStockZones.remove(item.zoneId);
        }
        _sensors = _sensors.map((s) {
          if (s.id == (zoneId == 'zone1' ? 'loadcell_1' : 'loadcell_2')) {
            return SensorDiagnostic(
              id: s.id,
              name: s.name,
              type: s.type,
              status: s.status,
              value: '${newWeight.toStringAsFixed(1)}g',
              detail: s.detail,
              lastReading: 'Live ADC',
            );
          }
          return s;
        }).toList();
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
        _checkAndNotifyLowStock(item);
        if (!_state!.shoppingList.any((s) => s.itemName.contains(item.itemName))) {
          _state!.shoppingList.insert(0, ShoppingItem(
            id: DateTime.now().millisecondsSinceEpoch,
            itemName: item.itemName,
            reason: 'AUTO-REORDER: Low Stock (15%)',
            isBought: false,
            addedAt: 'Just now',
          ));
        }
        _sensors = _sensors.map((s) {
          if (s.id == (zoneId == 'zone1' ? 'loadcell_1' : 'loadcell_2')) {
            return SensorDiagnostic(
              id: s.id,
              name: s.name,
              type: s.type,
              status: s.status,
              value: '${item.currentWeight.toStringAsFixed(1)}g',
              detail: s.detail,
              lastReading: 'Live ADC',
            );
          }
          return s;
        }).toList();
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

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning, Arya 👋';
    if (hour < 17) return 'Good Afternoon, Arya 👋';
    return 'Good Evening, Arya 👋';
  }

  String _getItemEmoji(String zoneId, String name) {
    final lower = name.toLowerCase();
    if (lower.contains('milk')) return '🥛';
    if (lower.contains('juice') || lower.contains('orange')) return '🍊';
    if (lower.contains('egg')) return '🥚';
    if (lower.contains('tomato')) return '🍅';
    if (lower.contains('apple')) return '🍏';
    if (lower.contains('yogurt')) return '🥣';
    if (lower.contains('cheese')) return '🧀';
    if (lower.contains('soda') || lower.contains('coke') || lower.contains('can')) return '🥤';
    return '📦';
  }

  Widget _buildDemoChip(
    String label,
    VoidCallback onTap, {
    bool isAlert = false,
    bool isSuccess = false,
    bool isExpanded = false,
  }) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF334155);
    Color border = const Color(0xFFE2E8F0);

    if (isAlert) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFDC2626);
      border = const Color(0xFFFCA5A5);
    } else if (isSuccess) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF16A34A);
      border = const Color(0xFF86EFAC);
    }

    final chip = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
        ),
      ),
    );

    if (isExpanded) {
      return Expanded(child: chip);
    }
    return chip;
  }

  void _showCalibrateDialog(InventoryItem item) {
    final nameCtrl = TextEditingController(text: item.itemName);
    final volCtrl = TextEditingController(text: item.fullVolume.toInt().toString());
    final tareCtrl = TextEditingController(text: item.tareWeight.toInt().toString());
    final expiryCtrl = TextEditingController(text: item.expiryDate);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.tune, color: Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 10),
            Text('Calibrate ${item.zoneId.toUpperCase()}',
                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Color(0xFF0F172A)),
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  labelStyle: TextStyle(color: Color(0xFF64748B)),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: volCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Color(0xFF0F172A)),
                decoration: const InputDecoration(
                  labelText: 'Full Rated Volume (ml)',
                  labelStyle: TextStyle(color: Color(0xFF64748B)),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tareCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Color(0xFF0F172A)),
                decoration: const InputDecoration(
                  labelText: 'Container Tare Mass (g)',
                  labelStyle: TextStyle(color: Color(0xFF64748B)),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: expiryCtrl,
                style: const TextStyle(color: Color(0xFF0F172A)),
                decoration: const InputDecoration(
                  labelText: 'Expiry Date (YYYY-MM-DD)',
                  labelStyle: TextStyle(color: Color(0xFF64748B)),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Replenishment Item',
            style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: const TextStyle(color: Color(0xFF0F172A)),
          decoration: const InputDecoration(
            labelText: 'Grocery / Item Name',
            labelStyle: TextStyle(color: Color(0xFF64748B)),
            hintText: 'e.g. Greek Yogurt, Milk',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.science_outlined, color: Color(0xFF7C3AED), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Faculty Demo & Sensor Sandbox',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '[DEMO MODE] Triggers physical hardware events for live evaluation',
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
                      backgroundColor: const Color(0xFFF8FAFC),
                      foregroundColor: const Color(0xFF0F172A),
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
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
                      backgroundColor: const Color(0xFFF8FAFC),
                      foregroundColor: const Color(0xFF0F172A),
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (context.mounted) Navigator.pop(context);
                      _simulateLocalPour('zone1', -150.0);
                      _simulateLocalPour('zone2', -120.0);
                    },
                    icon: const Icon(Icons.local_drink, size: 16, color: Color(0xFF0284C7)),
                    label: const Text('Pour Both'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF8FAFC),
                      foregroundColor: const Color(0xFF0F172A),
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (context.mounted) Navigator.pop(context);
                      _simulateLocalToggleDoor();
                    },
                    icon: const Icon(Icons.sensor_door_outlined, size: 16, color: Color(0xFFD97706)),
                    label: const Text('Toggle Door Event'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF8FAFC),
                      foregroundColor: const Color(0xFF0F172A),
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (context.mounted) Navigator.pop(context);
                      _simulateLocalLowStock('zone1');
                    },
                    icon: const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFDC2626)),
                    label: const Text('Low Stock Milk (<20%)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFEE2E2),
                      foregroundColor: const Color(0xFFDC2626),
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (context.mounted) Navigator.pop(context);
                      _simulateLocalLowStock('zone2');
                    },
                    icon: const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFDC2626)),
                    label: const Text('Low Stock Juice (<20%)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFEE2E2),
                      foregroundColor: const Color(0xFFDC2626),
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (context.mounted) Navigator.pop(context);
                      _simulateLocalResetFull();
                    },
                    icon: const Icon(Icons.replay_rounded, size: 16, color: Color(0xFF16A34A)),
                    label: const Text('Reset All Full (100%)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDCFCE7),
                      foregroundColor: const Color(0xFF16A34A),
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFF86EFAC)),
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
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  width: 24,
                  height: 24,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.wifi_tethering, color: Color(0xFF10B981), size: 24),
                ),
              ),
              const SizedBox(width: 10),
              const Text('Server Connection',
                  style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the IP address or host running server.py:',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                style: const TextStyle(color: Color(0xFF0F172A)),
                decoration: const InputDecoration(
                  labelText: 'Server Host / IP:Port',
                  labelStyle: TextStyle(color: Color(0xFF64748B)),
                  hintText: 'e.g. smart-fridge-retrofit-module.onrender.com',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.router, color: Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Quick Connection Presets:',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
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
                        foregroundColor: const Color(0xFF0284C7),
                        side: const BorderSide(color: Color(0xFFBAE6FD)),
                        backgroundColor: const Color(0xFFF0F9FF),
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
                        foregroundColor: const Color(0xFF7C3AED),
                        side: const BorderSide(color: Color(0xFFDDD6FE)),
                        backgroundColor: const Color(0xFFF5F3FF),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Tip: Cloud uses secure HTTPS; Local uses HTTP port 5050.',
                style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await _notificationService.showTestNotification();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🔔 Low stock notification sent! Check phone status bar.'),
                          backgroundColor: Color(0xFF10B981),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.notifications_active_outlined, size: 16),
                  label: const Text('🔔 Test Low Stock Alert',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD97706),
                    side: const BorderSide(color: Color(0xFFFDE68A)),
                    backgroundColor: const Color(0xFFFFFBEB),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await _notificationService.showTestDoorAjarNotification();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🚨 Door-Ajar Buzzer (>45s) notification sent!'),
                          backgroundColor: Color(0xFFEF4444),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.meeting_room_outlined, size: 16),
                  label: const Text('🚨 Test Door-Ajar Buzzer (>45s)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFECACA)),
                    backgroundColor: const Color(0xFFFEF2F2),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await _notificationService.showTestColdChainNotification();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🌡️ Cold-Chain (>4.5°C) alert notification sent!'),
                          backgroundColor: Color(0xFFEF4444),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.thermostat_outlined, size: 16),
                  label: const Text('🌡️ Test Cold-Chain Alert (>4.5°C)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0284C7),
                    side: const BorderSide(color: Color(0xFFBAE6FD)),
                    backgroundColor: const Color(0xFFF0F9FF),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/app_logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.kitchen, color: Color(0xFF10B981), size: 20),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ChillSense Console',
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
        color: const Color(0xFF2563EB),
        backgroundColor: Colors.white,
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

    final inventoryList = _state?.inventory.values.toList() ?? [];

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        // Offline Warning banner if disconnected
        if (!_isConnected)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hardware Module Offline',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                      ),
                      Text(
                        'Cannot reach server at $_currentHost. Tap the Wi-Fi icon top-right to edit server IP.',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // User Greeting & Weather pill
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getTimeGreeting(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Smart Retrofit Module • Node ESP32-S3',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x050F172A),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wb_sunny_outlined, size: 14, color: Color(0xFFF59E0B)),
                    SizedBox(width: 5),
                    Text(
                      '22°C Clear',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Executive Spotlight Card ("All Systems Working")
        Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 13, color: Color(0xFF16A34A)),
                        SizedBox(width: 4),
                        Text(
                          'ONLINE & ARMED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'ChillSense Pro HUD',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'All Systems Working',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Dual load cells, OV3660 camera pod, and cold-chain environmental sensors operating at peak efficiency.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _isScanning ? null : _triggerScan,
                              icon: _isScanning
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.camera_alt, size: 14),
                              label: Text(
                                _isScanning ? 'Analyzing...' : 'Scan Now',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _simulateLocalToggleDoor,
                              icon: const Icon(Icons.sensor_door_outlined, size: 14),
                              label: Text(
                                telemetry.doorState.toUpperCase() == 'OPEN' ? 'Close Door' : 'Open Door',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0F172A),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 72,
                    height: 96,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.kitchen_outlined, size: 36, color: Color(0xFF0284C7)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${telemetry.temperatureC.toStringAsFixed(1)}°C',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Environmental Glance & Telemetry Metrics
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x060F172A),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.science_outlined, size: 14, color: Color(0xFF7C3AED)),
                  SizedBox(width: 6),
                  Text(
                    'FACULTY REVIEW & DEMO CONTROLS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Column(
                children: [
                  Row(
                    children: [
                      _buildDemoChip('🥛 Pour 150ml Milk', () {
                        _simulateLocalPour('zone1', -150.0);
                      }, isExpanded: true),
                      const SizedBox(width: 8),
                      _buildDemoChip('🍊 Pour 120ml Juice', () {
                        _simulateLocalPour('zone2', -120.0);
                      }, isExpanded: true),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildDemoChip('🚨 Low Stock Milk', () {
                        _simulateLocalLowStock('zone1');
                      }, isAlert: true, isExpanded: true),
                      const SizedBox(width: 8),
                      _buildDemoChip('🚨 Low Stock Juice', () {
                        _simulateLocalLowStock('zone2');
                      }, isAlert: true, isExpanded: true),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildDemoChip('🚪 Toggle Door', () {
                        _simulateLocalToggleDoor();
                      }, isExpanded: true),
                      const SizedBox(width: 8),
                      _buildDemoChip('🔄 Reset All 100%', () {
                        _simulateLocalResetFull();
                      }, isSuccess: true, isExpanded: true),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildDemoChip('🚨 Door Ajar (>45s)', () {
                        _simulateDoorAjarDemo();
                      }, isAlert: true, isExpanded: true),
                      const SizedBox(width: 8),
                      _buildDemoChip('🌡️ Warm (>4.5°C)', () {
                        _simulateColdChainDemo();
                      }, isAlert: true, isExpanded: true),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        // Live Inventory Section
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 6),
          child: Text(
            'CHILLSENSE SMART INVENTORY (LOAD CELLS & AI VISION)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: Color(0xFF64748B),
            ),
          ),
        ),

        if (inventoryList.isNotEmpty)
          ...inventoryList.map((item) {
            return LiquidGaugeCard(
              item: item,
              iconEmoji: _getItemEmoji(item.zoneId, item.itemName),
              onPour: () => _simulateLocalPour(item.zoneId, -120.0),
              onLowStock: () => _simulateLocalLowStock(item.zoneId),
              onCalibrate: () => _showCalibrateDialog(item),
            );
          })
        else
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(child: CircularProgressIndicator()),
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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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
        const SizedBox(height: 6),
        const Text(
          'Each liquid zone uses a dedicated 5kg strain-gauge load cell with HX711 24-bit ADC. Calibrate container tare mass and full volume capacity below.',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
              iconEmoji: _getItemEmoji(item.zoneId, item.itemName),
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
            final isOnline = s.status == 'ONLINE' || s.status == 'READY' || s.status == 'ACTIVE' || s.status == 'ARMED / READY';
            final isArmed = s.status == 'ARMED / READY';
            final statusColor = isArmed
                ? const Color(0xFF0284C7)
                : (isOnline ? const Color(0xFF16A34A) : const Color(0xFFDC2626));
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x060F172A),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      s.id.contains('loadcell')
                          ? Icons.scale
                          : (s.id.contains('dht')
                              ? Icons.thermostat
                              : (s.id.contains('door')
                                  ? Icons.sensor_door
                                  : (s.id.contains('cam') ? Icons.camera_alt : Icons.psychology))),
                      color: statusColor,
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
                            Expanded(
                              child: Text(
                                s.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: statusColor.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                s.status,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.type,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Value: ${s.value}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0284C7),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              s.lastReading,
                              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x040F172A),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDoor
                            ? const Color(0xFFF59E0B).withOpacity(0.12)
                            : (isScan
                                ? const Color(0xFF8B5CF6).withOpacity(0.12)
                                : const Color(0xFF10B981).withOpacity(0.12)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isDoor
                            ? Icons.sensor_door
                            : (isScan ? Icons.camera_alt : Icons.bolt),
                        size: 16,
                        color: isDoor
                            ? const Color(0xFFD97706)
                            : (isScan
                                ? const Color(0xFF7C3AED)
                                : const Color(0xFF16A34A)),
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
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                ev.timestamp,
                                style: const TextStyle(
                                    fontSize: 10, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ev.message,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
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
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 4),
        const Text(
          'Fine-tune physical sensor thresholds and automated alerting policies.',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
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
                // Temp threshold
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Max Safe Temperature (°C)',
                        style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('${settings.tempMaxThreshold.toStringAsFixed(1)}°C',
                        style: const TextStyle(
                            color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: settings.tempMaxThreshold,
                  min: 2.0,
                  max: 15.0,
                  divisions: 26,
                  activeColor: const Color(0xFF0284C7),
                  onChanged: (val) {
                    setState(() => settings.tempMaxThreshold = val);
                  },
                ),
                const Divider(color: Color(0xFFF1F5F9)),

                // Low stock threshold
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Low Stock Alert Threshold (%)',
                        style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('${settings.lowStockThresholdPct.toStringAsFixed(0)}%',
                        style: const TextStyle(
                            color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
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
                const Divider(color: Color(0xFFF1F5F9)),

                // Door alarm delay
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Door Ajar Alarm Delay (seconds)',
                        style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('${settings.doorAlarmDelaySec}s',
                        style: const TextStyle(
                            color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
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
                const Divider(color: Color(0xFFF1F5F9)),

                // LED Strobe toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('LED Strobe On Door Open',
                      style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Flashes auxiliary illuminator for camera capture',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                  value: settings.ledStrobeOnOpen,
                  activeColor: const Color(0xFF10B981),
                  onChanged: (val) {
                    setState(() => settings.ledStrobeOnOpen = val);
                  },
                ),
                const Divider(color: Color(0xFFF1F5F9)),

                // Auto Shopping List toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Automated Grocery Replenishment',
                      style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600)),
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
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x060F172A),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'IoT Module Network Connection',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              Text(
                'Active Host: $_currentHost',
                style: const TextStyle(fontSize: 12, color: Color(0xFF0284C7)),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _showSettingsDialog,
                icon: const Icon(Icons.wifi_tethering, size: 16),
                label: const Text('Change Server Host / IP'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF8FAFC),
                  foregroundColor: const Color(0xFF0F172A),
                  elevation: 0,
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
