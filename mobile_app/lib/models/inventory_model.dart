class InventoryItem {
  final String zoneId;
  final String itemName;
  final String category;
  final double currentWeight;
  final double tareWeight;
  final double fullVolume;
  final double fillPercentage;
  final double remainingVolume;
  final String status;
  final String expiryDate;
  final int daysToExpiry;
  final String lastUpdated;

  InventoryItem({
    required this.zoneId,
    required this.itemName,
    required this.category,
    required this.currentWeight,
    required this.tareWeight,
    required this.fullVolume,
    required this.fillPercentage,
    required this.remainingVolume,
    required this.status,
    required this.expiryDate,
    required this.daysToExpiry,
    required this.lastUpdated,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      zoneId: json['zone_id'] ?? '',
      itemName: json['item_name'] ?? 'Unknown Item',
      category: json['category'] ?? 'General',
      currentWeight: (json['current_weight'] as num?)?.toDouble() ?? 0.0,
      tareWeight: (json['tare_weight'] as num?)?.toDouble() ?? 0.0,
      fullVolume: (json['full_volume'] as num?)?.toDouble() ?? 1000.0,
      fillPercentage: (json['fill_percentage'] as num?)?.toDouble() ?? 0.0,
      remainingVolume: (json['remaining_volume'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'OPTIMAL',
      expiryDate: json['expiry_date'] ?? 'N/A',
      daysToExpiry: (json['days_to_expiry'] as num?)?.toInt() ?? 99,
      lastUpdated: json['last_updated'] ?? '',
    );
  }
}

class TelemetryData {
  final String doorState;
  final double temperatureC;
  final int humidityPct;
  final double lastDeltaDairy;
  final double lastDeltaDrinks;
  final String latestImagePath;
  final List<String> detectedObjects;

  TelemetryData({
    required this.doorState,
    required this.temperatureC,
    required this.humidityPct,
    required this.lastDeltaDairy,
    required this.lastDeltaDrinks,
    required this.latestImagePath,
    required this.detectedObjects,
  });

  factory TelemetryData.fromJson(Map<String, dynamic> json) {
    var rawDetections = json['detected_objects'];
    List<String> objects = [];
    if (rawDetections is List) {
      objects = rawDetections.map((e) => e.toString()).toList();
    }

    return TelemetryData(
      doorState: json['door_state'] ?? 'CLOSED',
      temperatureC: (json['temperature_c'] as num?)?.toDouble() ?? 4.0,
      humidityPct: (json['humidity_pct'] as num?)?.toInt() ?? 65,
      lastDeltaDairy: (json['last_delta_dairy'] as num?)?.toDouble() ?? 0.0,
      lastDeltaDrinks: (json['last_delta_drinks'] as num?)?.toDouble() ?? 0.0,
      latestImagePath: json['latest_image_path'] ?? '/static/placeholder.jpg',
      detectedObjects: objects,
    );
  }
}

class ShoppingItem {
  final int id;
  final String itemName;
  final String reason;
  bool isBought;
  final String addedAt;

  ShoppingItem({
    required this.id,
    required this.itemName,
    required this.reason,
    required this.isBought,
    required this.addedAt,
  });

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    return ShoppingItem(
      id: json['id'] ?? 0,
      itemName: json['item_name'] ?? '',
      reason: json['reason'] ?? '',
      isBought: (json['is_bought'] == 1),
      addedAt: json['added_at'] ?? '',
    );
  }
}

class FridgeStatus {
  final String fridgeName;
  final String hardwareMode;
  final bool hardwareConnected;
  final String lastSync;
  final String doorState;
  final int doorOpenDurationSec;
  final double temperatureC;
  final int humidityPct;
  final double shelfMassG;
  final double maxRatedShelfG;
  final List<String> alerts;

  FridgeStatus({
    required this.fridgeName,
    required this.hardwareMode,
    required this.hardwareConnected,
    required this.lastSync,
    required this.doorState,
    required this.doorOpenDurationSec,
    required this.temperatureC,
    required this.humidityPct,
    required this.shelfMassG,
    required this.maxRatedShelfG,
    required this.alerts,
  });

  factory FridgeStatus.fromJson(Map<String, dynamic> json) {
    final door = json['door'] as Map<String, dynamic>? ?? {};
    final climate = json['climate'] as Map<String, dynamic>? ?? {};
    final shelf = json['shelf'] as Map<String, dynamic>? ?? {};
    final alertsRaw = json['alerts'] as List? ?? [];

    return FridgeStatus(
      fridgeName: json['fridge_name'] ?? 'Primary Refrigerator',
      hardwareMode: json['hardware_mode'] ?? json['mode'] ?? 'SIMULATION',
      hardwareConnected: json['hardware_connected'] ?? false,
      lastSync: json['last_sync'] ?? 'Just now',
      doorState: json['door_state'] ?? door['state'] ?? 'CLOSED',
      doorOpenDurationSec: (door['open_duration_sec'] as num?)?.toInt() ?? 0,
      temperatureC: (json['temperature_c'] as num?)?.toDouble() ?? (climate['temperature_c'] as num?)?.toDouble() ?? 4.0,
      humidityPct: (json['humidity_pct'] as num?)?.toInt() ?? (climate['humidity_pct'] as num?)?.toInt() ?? 60,
      shelfMassG: (json['total_shelf_weight_g'] as num?)?.toDouble() ?? (shelf['total_mass_g'] as num?)?.toDouble() ?? 0.0,
      maxRatedShelfG: (shelf['max_rated_g'] as num?)?.toDouble() ?? 10000.0,
      alerts: alertsRaw.map((e) => e.toString()).toList(),
    );
  }
}

class SensorDiagnostic {
  final String id;
  final String name;
  final String type;
  final String status;
  final String value;
  final String detail;
  final String lastReading;

  SensorDiagnostic({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.value,
    required this.detail,
    required this.lastReading,
  });

  factory SensorDiagnostic.fromJson(Map<String, dynamic> json) {
    return SensorDiagnostic(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      status: json['status'] ?? 'UNKNOWN',
      value: json['value'] ?? '',
      detail: json['detail'] ?? '',
      lastReading: json['last_reading'] ?? '',
    );
  }
}

class ActivityEvent {
  final int id;
  final String timestamp;
  final String eventType;
  final String message;
  final String metadata;

  ActivityEvent({
    required this.id,
    required this.timestamp,
    required this.eventType,
    required this.message,
    required this.metadata,
  });

  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    return ActivityEvent(
      id: json['id'] ?? 0,
      timestamp: json['timestamp'] ?? '',
      eventType: json['event_type'] ?? '',
      message: json['message'] ?? json['description'] ?? '',
      metadata: (json['metadata'] ?? json['zone_id'] ?? '').toString(),
    );
  }
}

class DeviceSettings {
  double tempMaxThreshold;
  double humidityMaxThreshold;
  double lowStockThresholdPct;
  int doorAlarmDelaySec;
  bool ledStrobeOnOpen;
  bool autoShoppingList;
  double yoloConfidenceThreshold;

  DeviceSettings({
    required this.tempMaxThreshold,
    required this.humidityMaxThreshold,
    required this.lowStockThresholdPct,
    required this.doorAlarmDelaySec,
    required this.ledStrobeOnOpen,
    required this.autoShoppingList,
    required this.yoloConfidenceThreshold,
  });

  factory DeviceSettings.fromJson(Map<String, dynamic> json) {
    return DeviceSettings(
      tempMaxThreshold: double.tryParse(json['temp_max_threshold']?.toString() ?? '') ??
          double.tryParse(json['target_temp_max']?.toString() ?? '') ?? 4.5,
      humidityMaxThreshold: double.tryParse(json['humidity_max_threshold']?.toString() ?? '') ?? 80.0,
      lowStockThresholdPct: double.tryParse(json['low_stock_threshold_pct']?.toString() ?? '') ?? 20.0,
      doorAlarmDelaySec: int.tryParse(json['door_alarm_delay_sec']?.toString() ?? '') ?? 45,
      ledStrobeOnOpen: json['led_strobe_on_open'] == true || json['alert_door_open'] == 'true',
      autoShoppingList: json['auto_shopping_list'] == true || json['alert_low_stock'] == 'true',
      yoloConfidenceThreshold: double.tryParse(json['yolo_confidence_threshold']?.toString() ?? '') ?? 0.45,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temp_max_threshold': tempMaxThreshold,
      'humidity_max_threshold': humidityMaxThreshold,
      'low_stock_threshold_pct': lowStockThresholdPct,
      'door_alarm_delay_sec': doorAlarmDelaySec,
      'led_strobe_on_open': ledStrobeOnOpen,
      'auto_shopping_list': autoShoppingList,
      'yolo_confidence_threshold': yoloConfidenceThreshold,
    };
  }
}

class FridgeInventoryState {
  final Map<String, InventoryItem> inventory;
  final TelemetryData telemetry;
  final List<ShoppingItem> shoppingList;

  FridgeInventoryState({
    required this.inventory,
    required this.telemetry,
    required this.shoppingList,
  });

  factory FridgeInventoryState.fromJson(Map<String, dynamic> json) {
    Map<String, InventoryItem> items = {};
    if (json['inventory'] is Map) {
      json['inventory'].forEach((k, v) {
        items[k.toString()] = InventoryItem.fromJson(v);
      });
    }

    TelemetryData telemetry = json['telemetry'] != null
        ? TelemetryData.fromJson(json['telemetry'])
        : TelemetryData(
            doorState: 'CLOSED',
            temperatureC: 4.0,
            humidityPct: 65,
            lastDeltaDairy: 0.0,
            lastDeltaDrinks: 0.0,
            latestImagePath: '',
            detectedObjects: [],
          );

    List<ShoppingItem> shopping = [];
    if (json['shopping_list'] is List) {
      shopping = (json['shopping_list'] as List)
          .map((e) => ShoppingItem.fromJson(e))
          .toList();
    }

    return FridgeInventoryState(
      inventory: items,
      telemetry: telemetry,
      shoppingList: shopping,
    );
  }
}
