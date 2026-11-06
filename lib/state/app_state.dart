import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/currency.dart';
import '../services/notifications.dart';
import '../services/places.dart';
import '../services/storage.dart';
import '../services/tracking.dart';
import '../services/travel_data.dart';

/// État global : voyages enregistrés et services partagés.
class AppState extends ChangeNotifier {
  final TripStorage storage;
  final TravelDataSource data;
  final CurrencyService currency;
  final NotificationService notifications;
  final PlaceService places;

  List<Trip> _trips = [];
  bool loaded = false;

  AppState({
    TripStorage? storage,
    TravelDataSource? data,
    CurrencyService? currency,
    NotificationService? notifications,
    PlaceService? places,
  })  : storage = storage ?? TripStorage(),
        data = data ?? createDataSource(),
        currency = currency ?? CurrencyService(),
        notifications = notifications ?? NotificationService(),
        places = places ?? PlaceService();

  List<Trip> get trips => List.unmodifiable(_trips);

  Trip? tripById(String id) => _trips.where((t) => t.id == id).firstOrNull;

  Future<void> init() async {
    _trips = await storage.load();
    _trips.sort((a, b) => a.startDate.compareTo(b.startDate));
    loaded = true;
    notifyListeners();
    // Les services réseau ne bloquent pas le démarrage.
    currency.init().then((_) => notifyListeners());
    notifications.init();
  }

  Future<void> saveTrip(Trip trip) async {
    final i = _trips.indexWhere((t) => t.id == trip.id);
    if (i >= 0) {
      _trips[i] = trip;
    } else {
      _trips.add(trip);
    }
    _trips.sort((a, b) => a.startDate.compareTo(b.startDate));
    await storage.save(_trips);
    notifyListeners();
  }

  Future<void> deleteTrip(String id) async {
    _trips.removeWhere((t) => t.id == id);
    await storage.save(_trips);
    notifyListeners();
  }

  /// Ajoute une dépense réelle puis vérifie les seuils d'alerte.
  Future<List<ThresholdAlert>> addExpense(Trip trip, Expense e) async {
    trip.expenses.add(e);
    trip.expenses.sort((a, b) => b.date.compareTo(a.date));
    final alerts = _newAlerts(trip);
    await saveTrip(trip);
    return alerts;
  }

  Future<void> removeExpense(Trip trip, String expenseId) async {
    trip.expenses.removeWhere((e) => e.id == expenseId);
    // Si l'on repasse sous un seuil, il pourra être de nouveau notifié.
    final active = TripTracker(trip).crossedThresholds.map((a) => a.key).toSet();
    trip.notifiedThresholds.retainWhere(active.contains);
    await saveTrip(trip);
  }

  List<ThresholdAlert> _newAlerts(Trip trip) {
    final crossed = TripTracker(trip).crossedThresholds;
    final fresh = crossed.where((a) => !trip.notifiedThresholds.contains(a.key)).toList();
    for (final a in fresh) {
      trip.notifiedThresholds.add(a.key);
      notifications.show(a.key.hashCode & 0x7fffffff, a.title, a.body);
    }
    return fresh;
  }
}
