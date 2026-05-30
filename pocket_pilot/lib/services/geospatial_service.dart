import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

class DwellLog {
  final String storeName;
  final int dwellMinutes;
  final DateTime visitTime;
  final bool isLogged;
  final double estimatedCost;
  final double? latitude;
  final double? longitude;

  DwellLog({
    required this.storeName,
    required this.dwellMinutes,
    required this.visitTime,
    this.isLogged = false,
    required this.estimatedCost,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'storeName': storeName,
        'dwellMinutes': dwellMinutes,
        'visitTime': visitTime.toIso8601String(),
        'isLogged': isLogged,
        'estimatedCost': estimatedCost,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory DwellLog.fromJson(Map<String, dynamic> json) => DwellLog(
        storeName: json['storeName'],
        dwellMinutes: json['dwellMinutes'],
        visitTime: DateTime.parse(json['visitTime']),
        isLogged: json['isLogged'] ?? false,
        estimatedCost: (json['estimatedCost'] as num).toDouble(),
        latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
        longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      );
}

class GeospatialService {
  static const String _dwellKey = 'geo_dwell_logs';
  static const String _enabledKey = 'geo_tracker_enabled';

  static Future<bool> requestLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Position?> getCurrentPosition() async {
    try {
      final allowed = await requestLocationPermission();
      if (!allowed) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 6),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isTrackerEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  static Future<void> setTrackerEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  static Future<List<DwellLog>> getDwellLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_dwellKey);

    if (data == null) {
      // Mock initial logs to populate the premium UI immediately!
      final list = [
        DwellLog(
          storeName: 'Starbucks Coffee',
          dwellMinutes: 14,
          visitTime: DateTime.now().subtract(const Duration(hours: 2)),
          isLogged: false,
          estimatedCost: 6.50,
        ),
        DwellLog(
          storeName: 'Walmart Supercenter',
          dwellMinutes: 45,
          visitTime: DateTime.now().subtract(const Duration(days: 1)),
          isLogged: true,
          estimatedCost: 48.20,
        ),
        DwellLog(
          storeName: 'Shell Gas Station',
          dwellMinutes: 8,
          visitTime: DateTime.now().subtract(const Duration(days: 2)),
          isLogged: true,
          estimatedCost: 35.00,
        ),
      ];
      await saveDwellLogs(list);
      return list;
    }

    return data.map((item) => DwellLog.fromJson(jsonDecode(item))).toList();
  }

  static Future<void> saveDwellLogs(List<DwellLog> logs) async {
    final prefs = await SharedPreferences.getInstance();
    final data = logs.map((log) => jsonEncode(log.toJson())).toList();
    await prefs.setStringList(_dwellKey, data);
  }

  static Future<void> addDwellLog(DwellLog log) async {
    final logs = await getDwellLogs();
    logs.insert(0, log);
    await saveDwellLogs(logs);
  }

  static Future<void> markAsLogged(String storeName) async {
    final logs = await getDwellLogs();
    final updated = logs.map((log) {
      if (log.storeName == storeName) {
        return DwellLog(
          storeName: log.storeName,
          dwellMinutes: log.dwellMinutes,
          visitTime: log.visitTime,
          isLogged: true,
          estimatedCost: log.estimatedCost,
        );
      }
      return log;
    }).toList();
    await saveDwellLogs(updated);
  }
}
