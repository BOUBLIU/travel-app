import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Sauvegarde locale des voyages (version 1 : sur l'appareil uniquement).
class TripStorage {
  static const _key = 'trips_v1';

  Future<List<Trip>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => Trip.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<Trip> trips) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(trips.map((t) => t.toJson()).toList()));
  }
}
