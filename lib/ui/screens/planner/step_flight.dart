import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/models.dart';
import '../../../state/planner.dart';
import '../../format.dart';
import '../../widgets/common.dart';

enum _FlightSort { price, duration, departure }

/// Étape 2 : recherche et choix du vol aller-retour.
class FlightStep extends StatefulWidget {
  const FlightStep({super.key});

  @override
  State<FlightStep> createState() => _FlightStepState();
}

class _FlightStepState extends State<FlightStep> {
  late Future<List<FlightOption>> _future;
  _FlightSort _sort = _FlightSort.price;
  bool _directOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final p = context.read<PlannerController>();
    final t = p.trip;
    _future = p.data.searchFlights(
      origin: t.origin!,
      destination: t.destination!,
      departDate: t.startDate,
      returnDate: t.endDate,
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
        SectionTitle('Vol ${t.origin!.name} ⇄ ${t.destination!.name}',
            subtitle: 'Aller le ${dateFr(t.startDate)}, retour le ${dateFr(t.endDate)} · '
                '${t.travelers} voyageur${t.travelers > 1 ? 's' : ''}. Prix aller-retour pour tout le groupe.'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<_FlightSort>(
              segments: const [
                ButtonSegment(value: _FlightSort.price, label: Text('Prix'), icon: Icon(Icons.euro)),
                ButtonSegment(value: _FlightSort.duration, label: Text('Durée'), icon: Icon(Icons.timer_outlined)),
                ButtonSegment(value: _FlightSort.departure, label: Text('Départ'), icon: Icon(Icons.schedule)),
              ],
              selected: {_sort},
              onSelectionChanged: (s) => setState(() => _sort = s.first),
            ),
            FilterChip(
              label: const Text('Vols directs uniquement'),
              selected: _directOnly,
              onSelected: (v) => setState(() => _directOnly = v),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<FlightOption>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError || (snap.data?.isEmpty ?? true)) {
              return Column(children: [
                const Padding(padding: EdgeInsets.all(24), child: Text('Aucun vol trouvé.')),
                FilledButton(onPressed: () => setState(_load), child: const Text('Réessayer')),
              ]);
            }
            var list = snap.data!.where((f) => !_directOnly || f.outStops.isEmpty).toList();
            list.sort((a, b) => switch (_sort) {
                  _FlightSort.price => a.totalPrice.compareTo(b.totalPrice),
                  _FlightSort.duration => a.outDuration.compareTo(b.outDuration),
                  _FlightSort.departure => a.outDepart.compareTo(b.outDepart),
                });
            final current = t.flight?.totalPrice ?? 0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (p.data.isSimulated) const SimulatedDataNotice(),
                if (list.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Aucun vol direct.')),
                ResponsiveGrid(
                  minItemWidth: 520,
                  children: list
                      .map((f) => _FlightCard(
                            flight: f,
                            selected: t.flight?.id == f.id,
                            outOfBudget: !p.fits(f.totalPrice, replacing: current),
                            onTap: () => p.setFlight(f),
                          ))
                      .toList(),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _FlightCard extends StatelessWidget {
  final FlightOption flight;
  final bool selected;
  final bool outOfBudget;
  final VoidCallback onTap;

  const _FlightCard({
    required this.flight,
    required this.selected,
    required this.outOfBudget,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final f = flight;
    final tt = Theme.of(context).textTheme;
    return OptionCard(
      selected: selected,
      outOfBudget: outOfBudget,
      onTap: onTap,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(eur(f.totalPrice), style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          Text('${eur(f.pricePerPerson)} / pers.', style: tt.bodySmall),
          TextButton(onPressed: () => openLink(context, f.bookingUrl), child: const Text('Voir l\'offre')),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${f.airline} · ${f.flightNumber}', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _Leg(
            icon: Icons.flight_takeoff,
            label: 'Aller',
            from: f.fromCode,
            to: f.toCode,
            depart: f.outDepart,
            arrive: f.outArrive,
            stops: f.outStops,
          ),
          if (f.retDepart != null && f.retArrive != null) ...[
            const SizedBox(height: 6),
            _Leg(
              icon: Icons.flight_land,
              label: 'Retour',
              from: f.toCode,
              to: f.fromCode,
              depart: f.retDepart!,
              arrive: f.retArrive!,
              stops: f.retStops,
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Retour : horaires sur le site de réservation', style: tt.bodySmall),
            ),
        ],
      ),
    );
  }
}

class _Leg extends StatelessWidget {
  final IconData icon;
  final String label;
  final String from;
  final String to;
  final DateTime depart;
  final DateTime arrive;
  final List<String> stops;

  const _Leg({
    required this.icon,
    required this.label,
    required this.from,
    required this.to,
    required this.depart,
    required this.arrive,
    required this.stops,
  });

  @override
  Widget build(BuildContext context) {
    final plusDays = Trip.dateOnly(arrive).difference(Trip.dateOnly(depart)).inDays;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 6),
        SizedBox(width: 56, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        Expanded(
          child: Text.rich(TextSpan(children: [
            TextSpan(text: '${dayShort(depart)}  ', style: TextStyle(color: scheme.onSurfaceVariant)),
            TextSpan(text: '${hm(depart)} $from → ${hm(arrive)} $to', style: const TextStyle(fontWeight: FontWeight.w600)),
            if (plusDays > 0) TextSpan(text: ' +$plusDays', style: TextStyle(color: scheme.error)),
            TextSpan(
              text: '  ·  ${duration(arrive.difference(depart))}  ·  '
                  '${stops.isEmpty ? 'Direct' : '${stops.length} escale${stops.length > 1 ? 's' : ''} (${stops.join(', ')})'}',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ])),
        ),
      ],
    );
  }
}
