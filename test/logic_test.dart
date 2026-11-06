import 'package:budget_voyage/models/models.dart';
import 'package:budget_voyage/services/places.dart';
import 'package:budget_voyage/services/plan_builder.dart';
import 'package:budget_voyage/services/tracking.dart';
import 'package:budget_voyage/services/travel_data.dart';
import 'package:budget_voyage/state/planner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<PlannerController> _planner({bool multi = false}) async {
  final data = SimulatedTravelData();
  final p = PlannerController(data);
  final paris = PlaceService.findLocal('Paris')!;
  final tokyo = PlaceService.findLocal('Tokyo')!;
  p.setBasics(
    origin: paris,
    destination: tokyo,
    start: DateTime(2027, 4, 1),
    end: DateTime(2027, 4, 8),
    travelers: 2,
    budget: 5000,
  );
  if (multi) {
    p.setStays(true, [
      CityStay(place: tokyo, nights: 4),
      CityStay(place: PlaceService.findLocal('Kyoto')!, nights: 3),
    ]);
  }
  return p;
}

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  test('changer de choix remet l\'ancien prix avant de déduire le nouveau', () async {
    final p = await _planner();
    final flights = await p.data.searchFlights(
      origin: p.trip.origin!,
      destination: p.trip.destination!,
      departDate: p.trip.startDate,
      returnDate: p.trip.endDate,
      travelers: 2,
    );
    expect(p.spent, 0);
    p.setFlight(flights[0]);
    expect(p.spent, flights[0].totalPrice);
    p.setFlight(flights[1]);
    expect(p.spent, flights[1].totalPrice);
    expect(p.remaining, 5000 - flights[1].totalPrice);
  });

  test('hôtel = prix par nuit × nombre de nuits', () async {
    final p = await _planner();
    final hotels = await p.data.searchHotels(
        city: p.trip.stays[0].place, checkIn: p.trip.startDate, nights: 7, travelers: 2);
    p.setHotel(0, hotels.first);
    expect(p.spent, closeTo(hotels.first.pricePerNight * 7, 0.001));
  });

  test('alerte sous 10 % et options hors budget', () async {
    final p = await _planner();
    p.trip.budget = 1000;
    p.setMealProfile(MealProfile.light); // 25 × 1.05 × 2 × 8 = 420
    expect(p.lowBudget, isFalse);
    expect(p.fits(500), isTrue);
    expect(p.fits(700), isFalse);
    // Remplacer le profil actuel libère son prix.
    expect(p.fits(900, replacing: p.trip.mealCost(MealProfile.light)), isTrue);
    p.trip.budget = 450;
    expect(p.lowBudget, isTrue);
  });

  test('plusieurs villes : trains entre villes et retour vers l\'aéroport', () async {
    final p = await _planner(multi: true);
    expect(p.trip.stays.length, 2);
    expect(p.trip.intercity.length, 2);
    expect(p.trip.intercity[0].from.name, 'Tokyo');
    expect(p.trip.intercity[0].to.name, 'Kyoto');
    expect(p.trip.intercity[0].depart.day, 5);
    expect(p.trip.intercity[1].to.name, 'Tokyo');
    expect(p.trip.plannedFor(BudgetCategory.intercity), greaterThan(0));
  });

  test('le plan est chronologique et numéroté', () async {
    final p = await _planner(multi: true);
    final t = p.trip;
    final d = p.data;
    final f = (await d.searchFlights(
            origin: t.origin!, destination: t.destination!, departDate: t.startDate, returnDate: t.endDate, travelers: 2))
        .first;
    p.setFlight(f);
    p.setArrivalTransfer(
        (await d.airportTransfers(city: t.destination!, start: f.outArrive, toAirport: false, travelers: 2)).first);
    p.setDepartureTransfer((await d.airportTransfers(
            city: t.destination!, start: f.retDepart!.subtract(const Duration(hours: 2)), toAirport: true, travelers: 2))
        .last);
    for (var i = 0; i < 2; i++) {
      final h = await d.searchHotels(city: t.stays[i].place, checkIn: t.stayStart(i), nights: t.stays[i].nights, travelers: 2);
      p.setHotel(i, h.first);
    }
    final acts = await d.activities(city: t.stays[1].place, interests: [Interest.culture], travelers: 2);
    p.addActivity(acts.first, DateTime(2027, 4, 6, 10));

    final plan = buildPlan(t);
    expect(plan.first.kind, PlanKind.flightArrival);
    expect(plan.last.kind, PlanKind.flightDeparture);
    for (var i = 1; i < plan.length; i++) {
      expect(!plan[i].time.isBefore(plan[i - 1].time), isTrue, reason: 'étape ${plan[i].title}');
      expect(plan[i].number, i + 1);
    }
    expect(plan.where((s) => s.kind == PlanKind.train).length, 2);
    expect(plan.where((s) => s.kind == PlanKind.checkIn).length, 2);
    final act = plan.firstWhere((s) => s.kind == PlanKind.activity);
    expect(act.day, 5);
  });

  test('suivi : budget par jour, prévu / réel et seuils', () async {
    final p = await _planner();
    p.setMealProfile(MealProfile.big);
    final t = p.trip..budget = 3000;
    final now = DateTime(2027, 4, 3, 12); // 3e jour sur 8 → 6 jours restants
    t.expenses.add(Expense(
        id: '1', category: ExpenseCategory.meals, amountEur: 60, originalAmount: 9800, currency: 'JPY', note: '', date: now));
    final tr = TripTracker(t, now: now);
    expect(tr.remainingDays, 6);
    expect(tr.spent, 60);
    expect(tr.remaining, 3000 - 60);
    expect(tr.dailyBudget, closeTo(3000 / 6, 0.001));
    expect(tr.availableToday, closeTo(500 - 60, 0.001));
    final meals = tr.comparisons.first;
    expect(meals.planned, t.mealCost(MealProfile.big));
    expect(meals.actual, 60);
    expect(tr.crossedThresholds, isEmpty);

    t.expenses.add(Expense(
        id: '2', category: ExpenseCategory.groceries, amountEur: meals.planned, originalAmount: 0, currency: 'EUR', note: '', date: now));
    final keys = TripTracker(t, now: now).crossedThresholds.map((a) => a.key);
    expect(keys, contains('Repas et courses_100'));
  });

  test('sérialisation JSON aller-retour', () async {
    final p = await _planner(multi: true);
    p.setMealProfile(MealProfile.gourmet);
    final copy = Trip.fromJson(p.trip.toJson());
    expect(copy.plannedTotal, p.trip.plannedTotal);
    expect(copy.stays.length, 2);
    expect(copy.mealProfile, MealProfile.gourmet);
  });

  test('autocomplétion insensible aux accents', () {
    expect(PlaceService.suggest('seou').first.name, 'Séoul');
    expect(PlaceService.findLocal('geneve')?.currency, 'CHF');
  });
}
