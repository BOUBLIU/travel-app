import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/models.dart';
import '../../../state/planner.dart';
import '../../format.dart';
import '../../widgets/common.dart';

/// Étape 9 : transports sur place, calculés selon les villes et les activités.
class LocalTransportStep extends StatefulWidget {
  const LocalTransportStep({super.key});

  @override
  State<LocalTransportStep> createState() => _LocalTransportStepState();
}

class _LocalTransportStepState extends State<LocalTransportStep> {
  @override
  void initState() {
    super.initState();
    // Les activités ont pu changer : on recalcule le prix des choix existants.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = context.read<PlannerController>();
      for (var i = 0; i < p.trip.stays.length; i++) {
        final city = p.trip.stays[i].place.name;
        final cur = p.localTransportFor(city);
        if (cur == null) continue;
        final fresh = _options(p, i).firstWhere((o) => o.mode == cur.mode);
        if (fresh.amount != cur.amount) p.setLocalTransport(city, fresh);
      }
    });
  }

  List<LocalTransportChoice> _options(PlannerController p, int i) {
    final s = p.trip.stays[i];
    return p.data.localTransportOptions(
      city: s.place,
      days: p.daysIn(i),
      activityCount: p.trip.activities.where((a) => a.city == s.place.name).length,
      travelers: p.trip.travelers,
    );
  }

  IconData _icon(LocalTransportMode m) => switch (m) {
        LocalTransportMode.publicPass => Icons.directions_subway,
        LocalTransportMode.carRental => Icons.directions_car,
        LocalTransportMode.taxi => Icons.local_taxi,
      };

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlannerController>();
    final t = p.trip;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Se déplacer sur place',
            subtitle: 'Estimations selon la durée dans chaque ville et le nombre d\'activités prévues.'),
        for (var i = 0; i < t.stays.length; i++) ...[
          Text('À ${t.stays[i].place.name} · ${p.daysIn(i)} jour${p.daysIn(i) > 1 ? 's' : ''}, '
              '${t.activities.where((a) => a.city == t.stays[i].place.name).length} activité(s)',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ResponsiveGrid(
            minItemWidth: 340,
            children: _options(p, i).map((o) {
              final cur = p.localTransportFor(o.city);
              final sel = cur?.mode == o.mode;
              return OptionCard(
                selected: sel,
                outOfBudget: !p.fits(o.amount, replacing: cur?.amount ?? 0),
                onTap: () => p.setLocalTransport(o.city, sel ? null : o),
                trailing: Text(eur(o.amount), style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_icon(o.mode), size: 32),
                    const SizedBox(height: 6),
                    Text(o.mode.label, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    Text(o.detail, style: tt.bodySmall),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
        Text('Trajets déjà prévus', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Card(
          child: Column(
            children: [
              if (t.arrivalTransfer != null)
                ListTile(
                  leading: const Icon(Icons.flight_land),
                  title: Text('Aéroport → ${t.stays.first.place.name} · ${t.arrivalTransfer!.label}'),
                  subtitle: Text('${dayLong(t.arrivalTransfer!.start)}, ${hm(t.arrivalTransfer!.start)} → ${hm(t.arrivalTransfer!.end)}'),
                  trailing: Text(eur(t.arrivalTransfer!.price)),
                ),
              ...t.intercity.map((l) => ListTile(
                    leading: const Icon(Icons.train),
                    title: Text('Train ${l.from.name} → ${l.to.name}'),
                    subtitle: Text('${dayLong(l.depart)}, ${hm(l.depart)} → ${hm(l.arrive)}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(eur(l.price)),
                      IconButton(
                        tooltip: 'Voir l\'offre',
                        onPressed: () => openLink(context, l.bookingUrl),
                        icon: const Icon(Icons.open_in_new),
                      ),
                    ]),
                  )),
              if (t.departureTransfer != null)
                ListTile(
                  leading: const Icon(Icons.flight_takeoff),
                  title: Text('${t.destination!.name} → aéroport · ${t.departureTransfer!.label}'),
                  subtitle: Text('${dayLong(t.departureTransfer!.start)}, ${hm(t.departureTransfer!.start)} → ${hm(t.departureTransfer!.end)}'),
                  trailing: Text(eur(t.departureTransfer!.price)),
                ),
              if (t.arrivalTransfer == null && t.intercity.isEmpty && t.departureTransfer == null)
                const ListTile(title: Text('Aucun trajet prévu.')),
            ],
          ),
        ),
      ],
    );
  }
}
