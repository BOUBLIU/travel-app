import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/travel_data.dart';

/// Brouillon du voyage pendant le parcours "Nouveau voyage".
///
/// Le budget dépensé est toujours recalculé à partir des choix actuels
/// ([Trip.budgetLines]) : remplacer un choix remet automatiquement
/// l'ancien prix avant de déduire le nouveau.
class PlannerController extends ChangeNotifier {
  final TravelDataSource data;
  final Trip trip;

  PlannerController(this.data, {Trip? trip})
      : trip = trip ??
            Trip(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              startDate: Trip.dateOnly(DateTime.now().add(const Duration(days: 30))),
              endDate: Trip.dateOnly(DateTime.now().add(const Duration(days: 37))),
              travelers: 2,
              budget: 2000,
            );

  bool get hasBudget => trip.hasBudget;
  double get spent => trip.plannedTotal;
  double get remaining => trip.budget - spent;
  double get progress =>
      !hasBudget || trip.budget <= 0 ? 0 : (spent / trip.budget).clamp(0, 1).toDouble();
  bool get lowBudget => hasBudget && trip.budget > 0 && remaining < trip.budget * 0.1;

  /// Une option est "hors budget" si elle coûte plus que le budget restant,
  /// en tenant compte du prix du choix actuel qu'elle remplacerait.
  /// Sans budget de départ, tout est permis.
  bool fits(double price, {double replacing = 0}) => !hasBudget || price <= remaining + replacing + 0.001;

  void touch() => notifyListeners();

  // ---- Étape 1 -------------------------------------------------------------
  void setBasics({
    required Place origin,
    required Place destination,
    required DateTime start,
    required DateTime end,
    required int travelers,
    required double budget,
    required bool hasBudget,
  }) {
    final changed = trip.destination?.name != destination.name ||
        trip.origin?.name != origin.name ||
        trip.startDate != start ||
        trip.endDate != end ||
        trip.travelers != travelers;
    trip
      ..origin = origin
      ..destination = destination
      ..startDate = start
      ..endDate = end
      ..travelers = travelers
      ..budget = hasBudget ? budget : 0
      ..hasBudget = hasBudget;
    if (trip.name.isEmpty || changed) trip.name = '${destination.name} — ${destination.country}';
    if (changed) {
      // Les prix dépendent de ces paramètres : on repart de zéro.
      trip
        ..flight = null
        ..arrivalTransfer = null
        ..departureTransfer = null
        ..multiCity = false
        ..stays = [CityStay(place: destination, nights: trip.nights)]
        ..activities = []
        ..localTransport = []
        ..intercity = [];
    }
    notifyListeners();
  }

  // ---- Étape 2 -------------------------------------------------------------
  void setTravelMode(TravelMode m) {
    if (trip.travelMode == m) return;
    trip
      ..travelMode = m
      ..flight = null
      ..arrivalTransfer = null
      ..departureTransfer = null;
    notifyListeners();
  }

  void setFlight(FlightOption f) {
    if (trip.flight?.id != f.id) {
      // Les horaires des trajets dépendent du vol.
      trip.arrivalTransfer = null;
      trip.departureTransfer = null;
    }
    trip.flight = f;
    notifyListeners();
  }

  // ---- Étape 3 -------------------------------------------------------------
  void setArrivalTransfer(TransferOption? t) {
    trip.arrivalTransfer = t;
    notifyListeners();
  }

  void setDepartureTransfer(TransferOption? t) {
    trip.departureTransfer = t;
    notifyListeners();
  }

  // ---- Étape 4 -------------------------------------------------------------
  void setStays(bool multi, List<CityStay> stays) {
    final keep = {for (final s in trip.stays) s.place.name: s};
    trip.multiCity = multi;
    trip.stays = stays.map((s) {
      final old = keep[s.place.name];
      // On garde l'hôtel déjà choisi si la ville et le nombre de nuits sont identiques.
      if (old != null && old.nights == s.nights) return old;
      return s;
    }).toList();
    final names = trip.stays.map((s) => s.place.name).toSet();
    trip.activities.removeWhere((a) => !names.contains(a.city));
    trip.localTransport.removeWhere((t) => !names.contains(t.city));
    _rescheduleActivities();
    rebuildIntercity();
    notifyListeners();
  }

  /// Retire la date des activités qui ne tombent plus pendant le séjour dans leur ville.
  void _rescheduleActivities() {
    for (final a in trip.activities) {
      final i = trip.stays.indexWhere((s) => s.place.name == a.city);
      if (i < 0 || a.scheduledAt == null) continue;
      final from = trip.stayStart(i);
      final to = from.add(Duration(days: trip.stays[i].nights));
      final d = Trip.dateOnly(a.scheduledAt!);
      if (d.isBefore(from) || d.isAfter(to)) a.scheduledAt = null;
    }
  }

  /// Trains entre villes successives (et retour vers la ville de l'aéroport).
  void rebuildIntercity() {
    final legs = <IntercityLeg>[];
    final dest = trip.destination;
    if (dest == null) return;
    for (var i = 0; i < trip.stays.length; i++) {
      final from = trip.stays[i].place;
      final isLast = i == trip.stays.length - 1;
      final to = isLast ? dest : trip.stays[i + 1].place;
      if (from.name == to.name) continue;
      legs.add(data.intercityLeg(
        from: from,
        to: to,
        date: trip.stayStart(i + 1),
        travelers: trip.travelers,
      ));
    }
    trip.intercity = legs;
  }

  // ---- Étapes 5 et 6 -------------------------------------------------------
  void setHotelPrefs(int stay, HotelPriority p, PriceRange r) {
    trip.stays[stay]
      ..priority = p
      ..priceRange = r;
    notifyListeners();
  }

  void setHotel(int stay, HotelOption? h) {
    trip.stays[stay].hotel = h;
    notifyListeners();
  }

  /// Bascule entre « trouver un hôtel » et « j'ai déjà réservé ».
  void setAlreadyBooked(int stay, bool booked) {
    final s = trip.stays[stay];
    if (s.alreadyBooked == booked) return;
    s
      ..alreadyBooked = booked
      ..hotel = null;
    notifyListeners();
  }

  /// Hôtel réservé avant d'utiliser l'application : nom et prix total payé.
  void setOwnHotel(int stay, {required String name, required double totalPaid, required String address,
      required double lat, required double lng}) {
    final s = trip.stays[stay];
    s
      ..alreadyBooked = true
      ..hotel = HotelOption(
        id: 'own-$stay-${s.place.name}',
        name: name,
        city: s.place.name,
        stars: 0,
        rating: 0,
        reviews: 0,
        pricePerNight: s.nights == 0 ? totalPaid : totalPaid / s.nights,
        lat: lat,
        lng: lng,
        address: address.isEmpty ? s.place.name : address,
        bookingUrl: '',
      );
    notifyListeners();
  }

  // ---- Étape 7 -------------------------------------------------------------
  void setMealProfile(MealProfile? p) {
    trip.mealProfile = p;
    notifyListeners();
  }

  // ---- Étape 8 -------------------------------------------------------------
  void toggleInterest(Interest i) {
    trip.interests.contains(i) ? trip.interests.remove(i) : trip.interests.add(i);
    notifyListeners();
  }

  bool hasActivity(String id) => trip.activities.any((a) => a.id == id);

  void addActivity(Activity a, DateTime when) {
    trip.activities.removeWhere((x) => x.id == a.id);
    trip.activities.add(a.copyWith(scheduledAt: when));
    trip.activities.sort((x, y) => (x.scheduledAt ?? DateTime(0)).compareTo(y.scheduledAt ?? DateTime(0)));
    notifyListeners();
  }

  void removeActivity(String id) {
    trip.activities.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  // ---- Étape 9 -------------------------------------------------------------
  void setLocalTransport(String city, LocalTransportChoice? c) {
    trip.localTransport.removeWhere((t) => t.city == city);
    if (c != null) trip.localTransport.add(c);
    notifyListeners();
  }

  LocalTransportChoice? localTransportFor(String city) =>
      trip.localTransport.where((t) => t.city == city).firstOrNull;

  /// Nombre de jours passés dans une ville (au moins 1).
  int daysIn(int stay) => trip.stays[stay].nights.clamp(1, 365);
}
