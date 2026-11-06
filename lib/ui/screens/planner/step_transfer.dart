import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/models.dart';
import '../../../state/planner.dart';
import '../../format.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Étape 3 : trajets aéroport / gare → ville (selon l'heure d'arrivée),
/// et ville → aéroport / gare pour le retour.
class TransferStep extends StatefulWidget {
  const TransferStep({super.key});

  @override
  State<TransferStep> createState() => _TransferStepState();
}

class _TransferStepState extends State<TransferStep> {
  late Future<List<TransferOption>> _arrival;
  late Future<List<TransferOption>> _departure;
  late TravelMode _mode;

  @override
  void initState() {
    super.initState();
    final p = context.read<PlannerController>();
    final t = p.trip;
    final f = t.flight!;
    _mode = f.mode;
    final ret = f.retDepart ?? DateTime(t.endDate.year, t.endDate.month, t.endDate.day, 17);
    if (_mode == TravelMode.plane) {
      _arrival = p.data.airportTransfers(city: t.destination!, start: f.outArrive, toAirport: false, travelers: t.travelers);
      // Arrivée à l'aéroport 2 h 30 avant le vol retour.
      _departure = p.data.airportTransfers(
          city: t.destination!, start: ret.subtract(const Duration(minutes: 150)), toAirport: true, travelers: t.travelers);
    } else {
      _arrival = p.data.stationTransfers(
          city: t.destination!, start: f.outArrive, toStation: false, travelers: t.travelers, mode: _mode);
      _departure = p.data.stationTransfers(
          city: t.destination!, start: ret.subtract(const Duration(minutes: 20)), toStation: true, travelers: t.travelers, mode: _mode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlannerController>();
    final t = p.trip;
    final f = t.flight!;
    final hub = _mode.hubName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle('Depuis $hub',
            subtitle: 'Votre ${_mode.tripNoun} arrive le ${dayLong(f.outArrive)} à ${hm(f.outArrive)}. '
                'Les horaires ci-dessous partent de cette heure.'),
        if (p.data.isSimulated) const SimulatedDataNotice(),
        _TransferList(future: _arrival, selected: t.arrivalTransfer, onSelect: p.setArrivalTransfer),
        const GroupHeader('Retour (optionnel)'),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            _mode == TravelMode.plane
                ? 'Pour être à l\'aéroport 2 h 30 avant le vol retour${f.retDepart != null ? ' de ${hm(f.retDepart!)}' : ''}.'
                : 'Pour être à $hub 20 min avant le départ${f.retDepart != null ? ' de ${hm(f.retDepart!)}' : ''}.',
            style: TextStyle(color: AppColors.of(context).secondary),
          ),
        ),
        _TransferList(future: _departure, selected: t.departureTransfer, onSelect: p.setDepartureTransfer, allowNone: true),
      ],
    );
  }
}

class _TransferList extends StatelessWidget {
  final Future<List<TransferOption>> future;
  final TransferOption? selected;
  final void Function(TransferOption?) onSelect;
  final bool allowNone;

  const _TransferList({required this.future, required this.selected, required this.onSelect, this.allowNone = false});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlannerController>();
    final c = AppColors.of(context);
    return FutureBuilder<List<TransferOption>>(
      future: future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(padding: EdgeInsets.all(32), child: Center(child: CupertinoActivityIndicator()));
        }
        final cards = snap.data!.map((o) {
          final isSel = selected?.id == o.id;
          final (icon, color) = switch (o.mode) {
            TransferMode.train => (CupertinoIcons.train_style_two, const Color(0xFF5856D6)),
            TransferMode.bus => (CupertinoIcons.bus, c.green),
            TransferMode.taxi => (CupertinoIcons.car_fill, c.orange),
            TransferMode.walk => (Icons.directions_walk_rounded, c.accent),
          };
          return OptionCard(
            selected: isSel,
            outOfBudget: !p.fits(o.price, replacing: selected?.price ?? 0),
            onTap: () => onSelect(isSel && allowNone ? null : o),
            trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              PriceLabel(o.price == 0 ? 'Gratuit' : eur(o.price), caption: duration(o.duration)),
              const SizedBox(height: 4),
              OfferLink(o.mapsUrl, label: 'Plan'),
            ]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  IconTile(icon, color, size: 30),
                  const SizedBox(width: 10),
                  Flexible(child: Text(o.label, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600))),
                ]),
                const SizedBox(height: 12),
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

/// Étape intermédiaire avec frise verticale fine.
class _StepLine extends StatelessWidget {
  final DateTime time;
  final String text;
  final bool first;
  final bool last;
  const _StepLine({required this.time, required this.text, required this.first, required this.last});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 46,
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(hm(time), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
            ),
          ),
          SizedBox(
            width: 16,
            child: Column(children: [
              Container(width: 1.5, height: 8, color: first ? Colors.transparent : c.tertiary),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: first || last ? c.accent : c.card,
                  border: Border.all(color: first || last ? c.accent : c.tertiary, width: 1.5),
                ),
              ),
              Expanded(child: Container(width: 1.5, color: last ? Colors.transparent : c.tertiary)),
            ]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 6),
              child: Text(text, style: TextStyle(fontSize: 13.5, color: c.label.withValues(alpha: 0.85))),
            ),
          ),
        ],
      ),
    );
  }
}
