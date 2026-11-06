import 'dart:math';

import '../models/models.dart';

/// Ligne de comparaison prévu / réel.
class CategoryComparison {
  final String label;
  final double planned;
  final double actual;
  final List<ExpenseCategory> categories;
  CategoryComparison(this.label, this.planned, this.actual, this.categories);

  double get ratio => planned <= 0 ? (actual > 0 ? double.infinity : 0) : actual / planned;
}

/// Alerte de seuil à notifier.
class ThresholdAlert {
  final String key; // identifiant unique pour ne notifier qu'une fois
  final String title;
  final String body;
  ThresholdAlert(this.key, this.title, this.body);
}

/// Calculs du suivi des dépenses réelles pendant le voyage.
///
/// - Les réservations (vol, trajets aéroport, logement, trains) sont considérées payées.
/// - Repas, activités et transports sur place sont des enveloppes prévues,
///   comparées aux dépenses réelles saisies.
/// - Budget restant = budget − réservations − dépenses réelles.
class TripTracker {
  final Trip trip;
  final DateTime now;

  TripTracker(this.trip, {DateTime? now}) : now = now ?? DateTime.now();

  double get booked =>
      trip.plannedFor(BudgetCategory.flight) +
      trip.plannedFor(BudgetCategory.transfer) +
      trip.plannedFor(BudgetCategory.hotel) +
      trip.plannedFor(BudgetCategory.intercity);

  double get spent => trip.expenses.fold(0.0, (a, e) => a + e.amountEur);

  double get remaining => trip.budget - booked - spent;

  double spentOn(DateTime day) => trip.expenses
      .where((e) => Trip.dateOnly(e.date) == Trip.dateOnly(day))
      .fold(0.0, (a, e) => a + e.amountEur);

  double get spentToday => spentOn(now);

  /// Jours restants, aujourd'hui compris (au moins 1).
  int get remainingDays {
    final today = Trip.dateOnly(now);
    final start = Trip.dateOnly(trip.startDate);
    final end = Trip.dateOnly(trip.endDate);
    if (today.isBefore(start)) return trip.days;
    if (today.isAfter(end)) return 1;
    return end.difference(today).inDays + 1;
  }

  /// Budget par jour = budget restant (au début de la journée) ÷ jours restants.
  double get dailyBudget => max(0, remaining + spentToday) / remainingDays;

  /// Ce qu'il reste à dépenser aujourd'hui.
  double get availableToday => dailyBudget - spentToday;

  double _actual(List<ExpenseCategory> cats) =>
      trip.expenses.where((e) => cats.contains(e.category)).fold(0.0, (a, e) => a + e.amountEur);

  List<CategoryComparison> get comparisons => [
        CategoryComparison('Repas et courses', trip.plannedFor(BudgetCategory.meals),
            _actual([ExpenseCategory.meals, ExpenseCategory.groceries]),
            [ExpenseCategory.meals, ExpenseCategory.groceries]),
        CategoryComparison('Transports sur place', trip.plannedFor(BudgetCategory.localTransport),
            _actual([ExpenseCategory.transport]), [ExpenseCategory.transport]),
        CategoryComparison('Activités', trip.plannedFor(BudgetCategory.activities),
            _actual([ExpenseCategory.activities]), [ExpenseCategory.activities]),
        CategoryComparison('Logement (hors réservation)', 0, _actual([ExpenseCategory.lodging]),
            [ExpenseCategory.lodging]),
        CategoryComparison('Autre (marge prévue)', max(0, trip.plannedRemaining),
            _actual([ExpenseCategory.other]), [ExpenseCategory.other]),
      ];

  /// Seuils franchis : 80 % et 100 % d'une catégorie, 90 % et 100 % du budget total.
  List<ThresholdAlert> get crossedThresholds {
    final out = <ThresholdAlert>[];
    for (final c in comparisons) {
      if (c.planned <= 0) continue;
      final pct = (c.ratio * 100).round();
      if (c.ratio >= 1) {
        out.add(ThresholdAlert('${c.label}_100', '${c.label} : budget dépassé',
            '${c.actual.toStringAsFixed(0)} € dépensés pour ${c.planned.toStringAsFixed(0)} € prévus ($pct %).'));
      } else if (c.ratio >= 0.8) {
        out.add(ThresholdAlert('${c.label}_80', '${c.label} : $pct % du budget utilisé',
            'Il reste ${(c.planned - c.actual).toStringAsFixed(0)} € sur ${c.planned.toStringAsFixed(0)} € prévus.'));
      }
    }
    if (trip.budget > 0) {
      if (remaining < 0) {
        out.add(ThresholdAlert('total_100', 'Budget total dépassé',
            'Vous avez dépassé votre budget de ${(-remaining).toStringAsFixed(0)} €.'));
      } else if (remaining < trip.budget * 0.1) {
        out.add(ThresholdAlert('total_90', 'Moins de 10 % du budget restant',
            'Il reste ${remaining.toStringAsFixed(0)} €, soit ${(remaining / remainingDays).toStringAsFixed(0)} € par jour.'));
      }
    }
    return out;
  }
}
