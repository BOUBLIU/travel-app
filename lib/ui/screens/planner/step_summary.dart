import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/models.dart';
import '../../../state/app_state.dart';
import '../../../state/planner.dart';
import '../../format.dart';
import '../../widgets/common.dart';
import '../plan_screen.dart';

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
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final lines = t.budgetLines;
    final cats = BudgetCategory.values.where((c) => lines.any((l) => l.category == c)).toList();
    final over = p.remaining < 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle('Récapitulatif',
            subtitle: '${t.destination!.name} · ${dateFr(t.startDate)} → ${dateFr(t.endDate)} · '
                '${t.travelers} voyageur${t.travelers > 1 ? 's' : ''}'),
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Nom du voyage', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        ResponsiveGrid(
          minItemWidth: 460,
          children: cats.map((c) {
            final items = lines.where((l) => l.category == c).toList();
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(c.label, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                      Text(eur(t.plannedFor(c)), style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    ]),
                    const Divider(),
                    ...items.map((l) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(children: [
                            Expanded(child: Text(l.label)),
                            Text(l.amount == 0 ? 'Gratuit' : eur(l.amount)),
                          ]),
                        )),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Card(
          color: over ? scheme.errorContainer : scheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _TotalRow('Budget', eur(t.budget)),
              _TotalRow('Total prévu', eur(t.plannedTotal), bold: true),
              const Divider(),
              _TotalRow(over ? 'Dépassement' : 'Budget restant (marge)', eur(p.remaining.abs()), bold: true, big: true),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Enregistrer', style: TextStyle(fontSize: 18)),
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final bool big;
  const _TotalRow(this.label, this.value, {this.bold = false, this.big = false});

  @override
  Widget build(BuildContext context) {
    final style = (big ? Theme.of(context).textTheme.titleLarge : Theme.of(context).textTheme.titleMedium)
        ?.copyWith(fontWeight: bold ? FontWeight.w800 : FontWeight.w500);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [Expanded(child: Text(label, style: style)), Text(value, style: style)]),
    );
  }
}
