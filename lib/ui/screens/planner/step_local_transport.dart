import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../../models/models.dart';
import '../../../state/planner.dart';
import '../../format.dart';
import '../../theme.dart';
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
        final fresh = _options(p, i).where((o) => o.mode == cur.mode).firstOrNull;
        if (fresh == null) {
          p.setLocalTransport(city, null);
        } else if (fresh.amount != cur.amount) {
          p.setLocalTransport(city, fresh);
        }
      }
    });
  }

  /// Le voyageur vient avec sa propre voiture (hors covoiturage et location).
  bool _ownCar(PlannerController p) {
    final f = p.trip.flight;
    return f != null && f.mode == TravelMode.car && f.airline.startsWith('Votre voiture');
  }

  List<LocalTransportChoice> _options(PlannerController p, int i) {
    final s = p.trip.stays[i];
    final opts = p.data.localTransportOptions(
      city: s.place,
      days: p.daysIn(i),
      activityCount: p.trip.activities.where((a) => a.city == s.place.name).length,
      travelers: p.trip.travelers,
    );
    if (_ownCar(p)) {
      final days = p.daysIn(i);
      final amount = ((12 + 8) * s.place.costIndex * days).roundToDouble();
      opts.insert(
        0,
        LocalTransportChoice(
          city: s.place.name,
          mode: LocalTransportMode.ownCar,
          amount: amount,
          detail: 'Parking et carburant sur place, ${days}j',
        ),
      );
    }
    return opts;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlannerController>();
    final t = p.trip;
    final c = AppColors.of(context);
    (IconData, Color) look(LocalTransportMode m) => switch (m) {
          LocalTransportMode.publicPass => (CupertinoIcons.tram_fill, const Color(0xFF5856D6)),
          LocalTransportMode.carRental => (CupertinoIcons.car_detailed, c.accent),
          LocalTransportMode.taxi => (CupertinoIcons.car_fill, c.orange),
          LocalTransportMode.ownCar => (CupertinoIcons.car_detailed, c.green),
        };
    final mode = t.flight?.mode ?? t.travelMode;
    final hub = switch (mode) {
      TravelMode.plane => 'Aéroport',
      TravelMode.train => 'Gare',
      TravelMode.bus => 'Gare routière',
      TravelMode.car => 'Arrivée',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Se déplacer sur place',
            subtitle: 'Estimations selon la durée dans chaque ville et vos activités. Touchez à nouveau pour désélectionner.'),
        for (var i = 0; i < t.stays.length; i++) ...[
          GroupHeader('${t.stays[i].place.name} · ${p.daysIn(i)} jour${p.daysIn(i) > 1 ? 's' : ''} · '
              '${t.activities.where((a) => a.city == t.stays[i].place.name).length} activité(s)'),
          ResponsiveGrid(
            minItemWidth: 340,
            children: _options(p, i).map((o) {
              final cur = p.localTransportFor(o.city);
              final sel = cur?.mode == o.mode;
              final (icon, color) = look(o.mode);
              return OptionCard(
                selected: sel,
                outOfBudget: !p.fits(o.amount, replacing: cur?.amount ?? 0),
                onTap: () => p.setLocalTransport(o.city, sel ? null : o),
                trailing: PriceLabel(eur(o.amount)),
                child: Row(children: [
                  IconTile(icon, color, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(o.mode.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      Text(o.detail, style: TextStyle(fontSize: 13, color: c.secondary)),
                    ]),
                  ),
                ]),
              );
            }).toList(),
          ),
        ],
        const GroupHeader('Trajets déjà prévus'),
        GroupedList(children: [
          if (t.arrivalTransfer != null)
            GroupedRow(
              leading: IconTile(CupertinoIcons.arrow_down_right, c.accent, size: 30),
              title: '$hub → ${t.stays.first.place.name} · ${t.arrivalTransfer!.label}',
              subtitle: '${dayLong(t.arrivalTransfer!.start)}, ${hm(t.arrivalTransfer!.start)} → ${hm(t.arrivalTransfer!.end)}',
              trailing: Text(eur(t.arrivalTransfer!.price), style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ...t.intercity.map((l) => GroupedRow(
                leading: IconTile(CupertinoIcons.train_style_one, const Color(0xFF5856D6), size: 30),
                title: 'Train ${l.from.name} → ${l.to.name}',
                subtitle: '${dayLong(l.depart)}, ${hm(l.depart)} → ${hm(l.arrive)}',
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(eur(l.price), style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  OfferLink(l.bookingUrl, label: 'Offre'),
                ]),
              )),
          if (t.departureTransfer != null)
            GroupedRow(
              leading: IconTile(CupertinoIcons.arrow_up_right, c.accent, size: 30),
              title: '${t.destination!.name} → ${hub.toLowerCase()} · ${t.departureTransfer!.label}',
              subtitle: '${dayLong(t.departureTransfer!.start)}, ${hm(t.departureTransfer!.start)} → ${hm(t.departureTransfer!.end)}',
              trailing: Text(eur(t.departureTransfer!.price), style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          if (t.arrivalTransfer == null && t.intercity.isEmpty && t.departureTransfer == null)
            const GroupedRow(title: 'Aucun trajet prévu'),
        ]),
      ],
    );
  }
}
