import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/tracking.dart';
import '../../state/app_state.dart';
import '../format.dart';
import '../widgets/common.dart';
import 'quick_expense.dart';

/// Pendant le voyage : suivi des dépenses réelles.
class TrackingScreen extends StatelessWidget {
  final String tripId;
  const TrackingScreen({super.key, required this.tripId});

  Future<void> _add(BuildContext context, Trip trip, [ExpenseCategory? c]) async {
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    final e = await showQuickExpense(context, trip, category: c);
    if (e == null) return;
    final alerts = await app.addExpense(trip, e);
    messenger.showSnackBar(SnackBar(
      content: Text(alerts.isEmpty
          ? '${e.category.label} : ${eur(e.amountEur, cents: true)} ajouté'
          : '⚠️ ${alerts.map((a) => a.title).join(' · ')}'),
      backgroundColor: alerts.isEmpty ? null : errorColor,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final trip = app.tripById(tripId);
    if (trip == null) return const Scaffold(body: Center(child: Text('Voyage introuvable.')));
    final tr = TripTracker(trip);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final tt = Theme.of(context).textTheme;

    final figures = ResponsiveGrid(minItemWidth: 240, children: [
      _Figure('Budget restant', eur(tr.remaining), Icons.account_balance_wallet_outlined,
          danger: tr.remaining < trip.budget * 0.1),
      _Figure('Disponible aujourd\'hui', eur(tr.availableToday), Icons.today_outlined,
          danger: tr.availableToday < 0),
      _Figure('Budget par jour', eur(tr.dailyBudget), Icons.calendar_view_day_outlined,
          sub: '${eur(tr.remaining + tr.spentToday)} ÷ ${tr.remainingDays} jour${tr.remainingDays > 1 ? 's' : ''} restant${tr.remainingDays > 1 ? 's' : ''}'),
      _Figure('Dépensé sur place', eur(tr.spent), Icons.receipt_long_outlined,
          sub: 'Réservations : ${eur(tr.booked)}'),
    ]);

    final quick = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ExpenseCategory.meals,
        ExpenseCategory.groceries,
        ExpenseCategory.transport,
        ExpenseCategory.activities,
        ExpenseCategory.other,
      ]
          .map((c) => FilledButton.tonalIcon(
                onPressed: () => _add(context, trip, c),
                icon: Icon(expenseIcon(c)),
                label: Text(c.label),
              ))
          .toList(),
    );

    final comparison = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Prévu / réel', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...tr.comparisons.map((c) => _ComparisonRow(c)),
          ],
        ),
      ),
    );

    final expenses = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Dépenses (${trip.expenses.length})', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            if (trip.expenses.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Aucune dépense pour l\'instant. Utilisez les boutons rapides ou « Ajouter ».'),
              ),
            ..._grouped(context, app, trip),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text('Suivi · ${trip.name}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, trip),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter une dépense'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1300),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                figures,
                const SizedBox(height: 12),
                quick,
                const SizedBox(height: 12),
                if (wide)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: comparison),
                    const SizedBox(width: 12),
                    Expanded(child: expenses),
                  ])
                else ...[
                  comparison,
                  const SizedBox(height: 12),
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
    final out = <Widget>[];
    DateTime? last;
    for (final e in trip.expenses) {
      final d = Trip.dateOnly(e.date);
      if (d != last) {
        last = d;
        final total = trip.expenses.where((x) => Trip.dateOnly(x.date) == d).fold(0.0, (a, x) => a + x.amountEur);
        out.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Row(children: [
            Expanded(child: Text(dayLong(d), style: const TextStyle(fontWeight: FontWeight.w700))),
            Text(eur(total, cents: true), style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ));
      }
      out.add(Dismissible(
        key: ValueKey(e.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          color: Theme.of(context).colorScheme.errorContainer,
          child: const Icon(Icons.delete_outline),
        ),
        onDismissed: (_) => app.removeExpense(trip, e.id),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(child: Icon(expenseIcon(e.category))),
          title: Text(e.note.isEmpty ? e.category.label : e.note),
          subtitle: Text('${e.category.label} · ${hm(e.date)}'
              '${e.currency != 'EUR' ? ' · ${money(e.originalAmount, e.currency)}' : ''}'),
          trailing: Text(eur(e.amountEur, cents: true), style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ));
    }
    return out;
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String? sub;
  final bool danger;
  const _Figure(this.label, this.value, this.icon, {this.sub, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      color: danger ? scheme.errorContainer : scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, size: 20), const SizedBox(width: 6), Text(label, style: tt.labelLarge)]),
            const SizedBox(height: 6),
            Text(value, style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            if (sub != null) Text(sub!, style: tt.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final CategoryComparison c;
  const _ComparisonRow(this.c);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = c.ratio.isFinite ? c.ratio : 1.0;
    final color = ratio >= 1
        ? scheme.error
        : ratio >= 0.8
            ? Colors.orange.shade800
            : scheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text(c.label, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text('${eur(c.actual)} / ${eur(c.planned)}', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio.clamp(0, 1).toDouble(),
              minHeight: 8,
              color: color,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}
