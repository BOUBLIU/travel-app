import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/models.dart';
import '../../../state/planner.dart';
import '../../format.dart';
import '../../widgets/common.dart';

/// Étape 3 : trajets aéroport → ville (selon l'heure d'arrivée du vol)
/// et ville → aéroport pour le vol retour.
class TransferStep extends StatefulWidget {
  const TransferStep({super.key});

  @override
  State<TransferStep> createState() => _TransferStepState();
}

class _TransferStepState extends State<TransferStep> {
  late Future<List<TransferOption>> _arrival;
  late Future<List<TransferOption>> _departure;

  @override
  void initState() {
    super.initState();
    final p = context.read<PlannerController>();
    final t = p.trip;
    final f = t.flight!;
    _arrival = p.data.airportTransfers(
      city: t.destination!,
      start: f.outArrive,
      toAirport: false,
      travelers: t.travelers,
    );
    // Arrivée à l'aéroport 2 h 30 avant le vol retour.
    final ret = f.retDepart ?? DateTime(t.endDate.year, t.endDate.month, t.endDate.day, 17);
    _departure = p.data.airportTransfers(
      city: t.destination!,
      start: ret.subtract(const Duration(minutes: 150)),
      toAirport: true,
      travelers: t.travelers,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlannerController>();
    final t = p.trip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle('Depuis l\'aéroport de ${t.destination!.name}',
            subtitle: 'Votre vol arrive le ${dayLong(t.flight!.outArrive)} à ${hm(t.flight!.outArrive)}. '
                'Options calculées à partir de cette heure (sortie de l\'avion et bagages compris).'),
        if (p.data.isSimulated) const SimulatedDataNotice(),
        _TransferList(
          future: _arrival,
          selected: t.arrivalTransfer,
          onSelect: p.setArrivalTransfer,
        ),
        const SizedBox(height: 24),
        SectionTitle('Retour vers l\'aéroport (optionnel)',
            subtitle: 'Pour arriver 2 h 30 avant le vol retour'
                '${t.flight!.retDepart != null ? ' de ${hm(t.flight!.retDepart!)}' : ''}.'),
        _TransferList(
          future: _departure,
          selected: t.departureTransfer,
          onSelect: p.setDepartureTransfer,
          allowNone: true,
        ),
      ],
    );
  }
}

class _TransferList extends StatelessWidget {
  final Future<List<TransferOption>> future;
  final TransferOption? selected;
  final void Function(TransferOption?) onSelect;
  final bool allowNone;

  const _TransferList({
    required this.future,
    required this.selected,
    required this.onSelect,
    this.allowNone = false,
  });

  IconData _icon(TransferMode m) => switch (m) {
        TransferMode.train => Icons.train,
        TransferMode.bus => Icons.directions_bus,
        TransferMode.taxi => Icons.local_taxi,
      };

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlannerController>();
    return FutureBuilder<List<TransferOption>>(
      future: future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
        }
        final tt = Theme.of(context).textTheme;
        final cards = snap.data!.map((o) {
          final isSel = selected?.id == o.id;
          return OptionCard(
            selected: isSel,
            outOfBudget: !p.fits(o.price, replacing: selected?.price ?? 0),
            onTap: () => onSelect(isSel && allowNone ? null : o),
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(eur(o.price), style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                Text(duration(o.duration), style: tt.bodySmall),
                TextButton.icon(
                  onPressed: () => openLink(context, o.mapsUrl),
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('Google Maps'),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(_icon(o.mode)),
                  const SizedBox(width: 8),
                  Flexible(child: Text(o.label, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                ]),
                const SizedBox(height: 8),
                ...o.steps.asMap().entries.map((e) => _StepLine(
                      time: e.value.time,
                      text: e.value.description,
                      first: e.key == 0,
                      last: e.key == o.steps.length - 1,
                    )),
              ],
            ),
          );
        }).toList();
        return ResponsiveGrid(minItemWidth: 380, children: cards);
      },
    );
  }
}

/// Ligne d'étape intermédiaire avec frise verticale.
class _StepLine extends StatelessWidget {
  final DateTime time;
  final String text;
  final bool first;
  final bool last;
  const _StepLine({required this.time, required this.text, required this.first, required this.last});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.primary;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 44, child: Text(hm(time), style: const TextStyle(fontWeight: FontWeight.w600))),
          SizedBox(
            width: 18,
            child: Column(
              children: [
                Expanded(child: Container(width: 2, color: first ? Colors.transparent : c)),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: first || last ? c : Colors.white, border: Border.all(color: c, width: 2)),
                ),
                Expanded(child: Container(width: 2, color: last ? Colors.transparent : c)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(text))),
        ],
      ),
    );
  }
}
