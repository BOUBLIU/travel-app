import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/models.dart';
import '../../../state/app_state.dart';
import '../../../state/planner.dart';
import '../../format.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../plan_screen.dart';
import 'step_flight.dart';

(IconData, Color) categoryLook(AppColors c, BudgetCategory cat) => switch (cat) {
      BudgetCategory.flight => (CupertinoIcons.airplane, c.accent),
      BudgetCategory.transfer => (CupertinoIcons.arrow_right_arrow_left, const Color(0xFF5AC8FA)),
      BudgetCategory.hotel => (CupertinoIcons.bed_double_fill, const Color(0xFF5856D6)),
      BudgetCategory.meals => (Icons.restaurant_rounded, c.orange),
      BudgetCategory.activities => (CupertinoIcons.ticket_fill, const Color(0xFFFF2D55)),
      BudgetCategory.localTransport => (CupertinoIcons.tram_fill, c.green),
      BudgetCategory.intercity => (CupertinoIcons.train_style_one, const Color(0xFFAF52DE)),
    };

/// Étape 10 : récapitulatif et enregistrement.
class SummaryStep extends StatefulWidget {
  const SummaryStep({super.key});

  @override
  State<SummaryStep> createState() => _SummaryStepState();
}

class _SummaryStepState extends State<SummaryStep> {
  late final TextEditingController _name;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: context.read<PlannerController>().trip.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final p = context.read<PlannerController>();
    final app = context.read<AppState>();
    final nav = Navigator.of(context);
    setState(() => _saving = true);
    final trip = p.trip.copy()..name = _name.text.trim().isEmpty ? p.trip.name : _name.text.trim();
    await app.saveTrip(trip);
    nav.pushReplacement(MaterialPageRoute(builder: (_) => PlanScreen(tripId: trip.id)));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlannerController>();
    final t = p.trip;
    final c = AppColors.of(context);
    final lines = t.budgetLines;
    final cats = BudgetCategory.values.where((cat) => lines.any((l) => l.category == cat)).toList();
    final over = p.hasBudget && p.remaining < 0;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final total = SurfaceCard(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Total prévu', style: TextStyle(color: c.secondary, fontSize: 14, fontWeight: FontWeight.w500)),
        Text(eur(t.plannedTotal), style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w700, letterSpacing: -1.6)),
        const SizedBox(height: 16),
        if (p.hasBudget) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: p.progress,
              minHeight: 8,
              color: over ? c.red : (p.lowBudget ? c.orange : c.accent),
              backgroundColor: c.fill,
            ),
          ),
          const SizedBox(height: 14),
          _Row('Budget', eur(t.budget)),
          _Row(over ? 'Dépassement' : 'Marge restante', eur(p.remaining.abs()),
              color: over ? c.red : c.green, bold: true),
        ] else
          Text('Voyage planifié sans budget de départ. Ce total servira de référence pendant le séjour.',
              style: TextStyle(color: c.secondary, fontSize: 14)),
        const SizedBox(height: 18),
        TextField(
          controller: _name,
          decoration: InputDecoration(
            labelText: 'Nom du voyage',
            filled: true,
            fillColor: c.background,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
            onPressed: _saving ? null : _save,
            icon: const Icon(CupertinoIcons.checkmark_alt, size: 20),
            label: const Text('Enregistrer le voyage', style: TextStyle(fontSize: 17)),
          ),
        ),
      ]),
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: cats.map((cat) {
        final items = lines.where((l) => l.category == cat).toList();
        var (icon, color) = categoryLook(c, cat);
        if (cat == BudgetCategory.flight) {
          icon = travelModeIcon(t.travelMode);
          color = travelModeColor(c, t.travelMode);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          GroupHeader(cat.label,
              trailing: Text(eur(t.plannedFor(cat)),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.label))),
          GroupedList(
            children: items
                .map((l) => GroupedRow(
                      leading: IconTile(icon, color, size: 28),
                      title: l.label,
                      trailing: Text(l.amount == 0 ? 'Gratuit' : eur(l.amount),
                          style: TextStyle(fontWeight: FontWeight.w500, color: l.amount == 0 ? c.green : c.label)),
                    ))
                .toList(),
          ),
        ]);
      }).toList(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle('Récapitulatif',
            subtitle: '${t.destination!.name} · ${dateFr(t.startDate)} → ${dateFr(t.endDate)} · '
                '${t.travelers} voyageur${t.travelers > 1 ? 's' : ''}'),
        if (wide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 3, child: details),
            const SizedBox(width: 24),
            Expanded(flex: 2, child: Padding(padding: const EdgeInsets.only(top: 20), child: total)),
          ])
        else ...[
          total,
          details,
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool bold;
  const _Row(this.label, this.value, {this.color, this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 15, color: AppColors.of(context).secondary))),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: color)),
        ]),
      );
}
