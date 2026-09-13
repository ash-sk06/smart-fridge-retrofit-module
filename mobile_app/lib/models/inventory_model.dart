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
