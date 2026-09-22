import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/inventory_model.dart';

class FridgeApiService {
  static const String _prefKey = 'fridge_server_ip';
  static const String defaultHost = '192.168.1.23:5050';

  String _host = defaultHost;

  FridgeApiService() {
    _loadHost();
  }

  Future<void> _loadHost() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _host = prefs.getString(_prefKey) ?? defaultHost;
    } catch (_) {}
  }

  Future<String> getHost() async {
    final prefs = await SharedPreferences.getInstance();
    _host = prefs.getString(_prefKey) ?? defaultHost;
    return _host;
  }

  Future<void> setHost(String newHost) async {
    _host = newHost.trim();
    if (_host.endsWith('/')) {
      _host = _host.substring(0, _host.length - 1);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, _host);
  }

  String get baseUrl {
    if (_host.startsWith('http://') || _host.startsWith('https://')) {
      return _host;
    }
    if (_host.contains('onrender.com')) {
      return 'https://$_host';
    }
    return 'http://$_host';
  }

  /// Fetches system status, connection health, and climate
  Future<FridgeStatus?> fetchStatus() async {
    try {
      final uri = Uri.parse('$baseUrl/api/status');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return FridgeStatus.fromJson(data);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Fetches live dual-zone inventory, telemetry, and smart shopping list
  Future<FridgeInventoryState?> fetchInventory() async {
    try {
      final uri = Uri.parse('$baseUrl/api/inventory');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return FridgeInventoryState.fromJson(data);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Fetches hardware sensor telemetry & diagnostic health
  Future<List<SensorDiagnostic>> fetchSensors() async {
    try {
      final uri = Uri.parse('$baseUrl/api/sensors');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['sensors'] is List) {
          return (data['sensors'] as List)
              .map((s) => SensorDiagnostic.fromJson(s))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Fetches chronological activity audit trail
  Future<List<ActivityEvent>> fetchActivity() async {
    try {
      final uri = Uri.parse('$baseUrl/api/activity');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['events'] is List) {
          return (data['events'] as List)
              .map((e) => ActivityEvent.fromJson(e))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Fetches hardware device settings
  Future<DeviceSettings?> fetchSettings() async {
    try {
      final uri = Uri.parse('$baseUrl/api/settings');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['settings'] != null) {
          return DeviceSettings.fromJson(data['settings']);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Saves hardware device settings
  Future<bool> updateSettings(DeviceSettings settings) async {
    try {
      final uri = Uri.parse('$baseUrl/api/settings');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(settings.toJson()),
      ).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Triggers OV3660 camera capture and YOLO inference
  Future<Map<String, dynamic>?> triggerScan() async {
    try {
      final uri = Uri.parse('$baseUrl/api/scan');
      final response = await http.post(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (_) {}
    return null;
  }

  /// Calibrates / tares both HX711 load cell channels
  Future<bool> calibrateScales() async {
    try {
      final uri = Uri.parse('$baseUrl/api/calibrate');
      final response = await http.post(uri).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Calibrates or customizes a specific zone container
  Future<bool> updateItemCalibration({
    required String zone,
    String? itemName,
    double? fullVolume,
    double? tareWeight,
    String? expiryDate,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/inventory/update');
      final body = <String, dynamic>{'zone': zone};
      if (itemName != null) body['item_name'] = itemName;
      if (fullVolume != null) body['full_volume'] = fullVolume;
      if (tareWeight != null) body['tare_weight'] = tareWeight;
      if (expiryDate != null) body['expiry_date'] = expiryDate;

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Toggles shopping item checkbox
  Future<bool> toggleShoppingItem(int id) async {
    try {
      final uri = Uri.parse('$baseUrl/api/shopping-list/toggle');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id': id}),
      ).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Adds a shopping item manually
  Future<bool> addShoppingItem(String name, String reason) async {
    try {
      final uri = Uri.parse('$baseUrl/api/shopping-list/add');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'item_name': name, 'reason': reason}),
      ).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Deletes a single shopping item
  Future<bool> deleteShoppingItem(int id) async {
    try {
      final uri = Uri.parse('$baseUrl/api/shopping-list/$id');
      final response = await http.delete(uri).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Clears the shopping list
  Future<bool> clearShoppingList() async {
    try {
      final uri = Uri.parse('$baseUrl/api/shopping-list/clear');
      final response = await http.post(uri).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Prototype simulation triggers
  Future<bool> triggerSimulation(String action) async {
    try {
      final uri = Uri.parse('$baseUrl/api/test-simulate');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'action': action}),
      ).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Sends a simulated liquid pour event
  Future<bool> simulatePour(String zoneId, double deltaWeight) async {
    try {
      final uri = Uri.parse('$baseUrl/api/simulate-pour');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'zone': zoneId, 'delta': deltaWeight}),
      ).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Sends a door event (OPEN / CLOSED)
  Future<bool> simulateDoor(String doorState) async {
    try {
      final uri = Uri.parse('$baseUrl/api/simulate-door');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'door': doorState}),
      ).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Triggers low stock simulation for a specific zone
  Future<bool> triggerLowStock(String zoneId) async {
    final action = zoneId == 'zone2' ? 'low_stock_juice' : 'low_stock_milk';
    return triggerSimulation(action);
  }
}
