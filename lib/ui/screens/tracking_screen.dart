import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/tracking.dart';
import '../../state/app_state.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'quick_expense.dart';

/// Pendant le voyage : suivi des dépenses réelles.
class TrackingScreen extends StatelessWidget {
  final String tripId;
  const TrackingScreen({super.key, required this.tripId});

  Future<void> _add(BuildContext context, Trip trip, [ExpenseCategory? cat]) async {
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final e = await showQuickExpense(context, trip, category: cat);
    if (e == null) return;
    final alerts = await app.addExpense(trip, e);
    messenger.showSnackBar(SnackBar(
      content: Text(alerts.isEmpty
          ? '${e.category.label} · ${eur(e.amountEur, cents: true)} ajouté'
          : alerts.map((a) => a.title).join(' · ')),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final trip = app.tripById(tripId);
    if (trip == null) return const Scaffold(body: Center(child: Text('Voyage introuvable.')));
    final tr = TripTracker(trip);
    final c = AppColors.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final ref = trip.effectiveBudget;
    final low = tr.remaining < ref * 0.1;

    final hero = SurfaceCard(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(trip.hasBudget ? 'Budget restant' : 'Restant sur vos prévisions',
            style: TextStyle(color: c.secondary, fontSize: 14, fontWeight: FontWeight.w500)),
        Text(eur(tr.remaining),
            style: TextStyle(
                fontSize: 52, fontWeight: FontWeight.w700, letterSpacing: -2, color: tr.remaining < 0 ? c.red : (low ? c.orange : c.label))),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ref <= 0 ? 0 : ((ref - tr.remaining) / ref).clamp(0, 1).toDouble(),
            minHeight: 8,
            color: tr.remaining < 0 ? c.red : (low ? c.orange : c.accent),
            backgroundColor: c.fill,
          ),
        ),
        const SizedBox(height: 18),
        Row(children: [
          _Metric('Aujourd\'hui', eur(tr.availableToday), color: tr.availableToday < 0 ? c.red : c.green),
          _Metric('Par jour', eur(tr.dailyBudget),
              caption: '${tr.remainingDays} jour${tr.remainingDays > 1 ? 's' : ''} restant${tr.remainingDays > 1 ? 's' : ''}'),
          _Metric('Dépensé', eur(tr.spent), caption: 'réservations ${eur(tr.booked)}'),
        ]),
      ]),
    );

    final quick = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ExpenseCategory.meals,
        ExpenseCategory.groceries,
        ExpenseCategory.transport,
        ExpenseCategory.activities,
        ExpenseCategory.other,
      ].map((e) => Tag(icon: expenseIcon(e), label: e.label, selected: false, onTap: () => _add(context, trip, e))).toList(),
    );

    final comparison = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const GroupHeader('Prévu et réel'),
      GroupedList(children: tr.comparisons.map((x) => _ComparisonRow(x)).toList()),
    ]);

    final expenses = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupHeader('Dépenses (${trip.expenses.length})'),
        if (trip.expenses.isEmpty)
          SurfaceCard(
            child: Text('Aucune dépense pour l\'instant. Touchez une catégorie ou « Ajouter ».',
                style: TextStyle(color: c.secondary)),
          )
        else
          ..._grouped(context, app, trip),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(trip.name)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, trip),
        icon: const Icon(CupertinoIcons.add),
        label: const Text('Ajouter', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Dépenses', style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 16),
                if (wide)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        hero,
                        const SizedBox(height: 16),
                        quick,
                        comparison,
                      ]),
                    ),
                    const SizedBox(width: 24),
                    Expanded(child: expenses),
                  ])
                else ...[
                  hero,
                  const SizedBox(height: 16),
                  quick,
                  comparison,
                  expenses,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _grouped(BuildContext context, AppState app, Trip trip) {
    final c = AppColors.of(context);
    final days = <DateTime>[];
    for (final e in trip.expenses) {
      final d = Trip.dateOnly(e.date);
      if (!days.contains(d)) days.add(d);
    }
    return days.map((d) {
      final items = trip.expenses.where((x) => Trip.dateOnly(x.date) == d).toList();
      final total = items.fold(0.0, (a, x) => a + x.amountEur);
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: Row(children: [
              Expanded(child: Text(dayLong(d), style: TextStyle(fontSize: 13, color: c.secondary, fontWeight: FontWeight.w500))),
              Text(eur(total, cents: true), style: TextStyle(fontSize: 13, color: c.secondary, fontWeight: FontWeight.w600)),
            ]),
          ),
          GroupedList(
            children: items
                .map((e) => Dismissible(
                      key: ValueKey(e.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: c.red,
                        child: const Icon(CupertinoIcons.trash, color: Colors.white),
                      ),
                      onDismissed: (_) => app.removeExpense(trip, e.id),
                      child: GroupedRow(
                        leading: IconTile(expenseIcon(e.category), expenseColor(c, e.category), size: 32),
                        title: e.note.isEmpty ? e.category.label : e.note,
                        subtitle: '${hm(e.date)}${e.currency != 'EUR' ? ' · ${money(e.originalAmount, e.currency)}' : ''}',
                        trailing: Text(eur(e.amountEur, cents: true), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ))
                .toList(),
          ),
        ]),
      );
    }).toList();
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final String? caption;
  final Color? color;
  const _Metric(this.label, this.value, {this.caption, this.color});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 13, color: c.secondary)),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: color)),
        if (caption != null) Text(caption!, style: TextStyle(fontSize: 12, color: c.secondary)),
      ]),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final CategoryComparison x;
  const _ComparisonRow(this.x);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final ratio = x.ratio.isFinite ? x.ratio : 1.0;
    final color = ratio >= 1
        ? c.red
        : ratio >= 0.8
            ? c.orange
            : c.accent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            IconTile(expenseIcon(x.categories.first), expenseColor(c, x.categories.first), size: 26),
            const SizedBox(width: 10),
            Expanded(child: Text(x.label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15))),
            Text.rich(TextSpan(children: [
              TextSpan(text: eur(x.actual), style: TextStyle(color: color, fontWeight: FontWeight.w700)),
              TextSpan(text: ' / ${eur(x.planned)}', style: TextStyle(color: c.secondary)),
            ])),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio.clamp(0, 1).toDouble(),
              minHeight: 5,
              color: color,
              backgroundColor: c.fill,
            ),
          ),
        ],
      ),
    );
  }
}
