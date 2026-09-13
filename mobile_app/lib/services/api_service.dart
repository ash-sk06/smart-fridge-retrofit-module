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
    _host = newHost.trim().replaceAll('http://', '').replaceAll('/', '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, _host);
  }

  String get baseUrl => 'http://$_host';

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
    } catch (e) {
      // Return null on network error so caller can display offline banner
      return null;
    }
    return null;
  }

  /// Sends a simulated liquid pour event to the Flask backend
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

  /// Clears the grocery shopping list
  Future<bool> clearShoppingList() async {
    try {
      final uri = Uri.parse('$baseUrl/api/shopping-list/clear');
      final response = await http.post(uri).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
