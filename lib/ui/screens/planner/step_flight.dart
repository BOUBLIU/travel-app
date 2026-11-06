import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/models.dart';
import '../../../state/planner.dart';
import '../../format.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

enum _Sort { price, duration, departure }

IconData travelModeIcon(TravelMode m) => switch (m) {
      TravelMode.plane => CupertinoIcons.airplane,
      TravelMode.train => CupertinoIcons.train_style_one,
      TravelMode.bus => CupertinoIcons.bus,
      TravelMode.car => CupertinoIcons.car_detailed,
    };

Color travelModeColor(AppColors c, TravelMode m) => switch (m) {
      TravelMode.plane => c.accent,
      TravelMode.train => const Color(0xFF5856D6),
      TravelMode.bus => c.green,
      TravelMode.car => c.orange,
    };

/// Étape 2 : moyen de transport puis choix du trajet aller-retour.
class TransportStep extends StatefulWidget {
  const TransportStep({super.key});

  @override
  State<TransportStep> createState() => _TransportStepState();
}

class _TransportStepState extends State<TransportStep> {
  final Map<TravelMode, Future<List<FlightOption>>> _futures = {};
  _Sort _sort = _Sort.price;
  bool _directOnly = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<PlannerController>();
    final t = p.trip;
    for (final m in TravelMode.values) {
      _futures[m] = m == TravelMode.plane
          ? p.data.searchFlights(
              origin: t.origin!,
              destination: t.destination!,
              departDate: t.startDate,
              returnDate: t.endDate,
              travelers: t.travelers,
            )
          : p.data.searchGroundTransport(
              mode: m,
              origin: t.origin!,
              destination: t.destination!,
              departDate: t.startDate,
              returnDate: t.endDate,
              travelers: t.travelers,
            );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlannerController>();
    final t = p.trip;
    final c = AppColors.of(context);
    final mode = t.travelMode;
    final km = t.origin!.distanceTo(t.destination!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle('${t.origin!.name} → ${t.destination!.name}',
            subtitle: 'Aller le ${dateFr(t.startDate)}, retour le ${dateFr(t.endDate)} · '
                '${km.round()} km à vol d\'oiseau. Prix aller-retour pour ${t.travelers} voyageur${t.travelers > 1 ? 's' : ''}.'),
        // Choix du moyen de transport
        LayoutBuilder(builder: (context, box) {
          final cols = box.maxWidth > 700 ? 4 : 2;
          final w = (box.maxWidth - (cols - 1) * 12) / cols;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: TravelMode.values
                .map((m) => SizedBox(
                      width: w,
                      child: _ModeTile(
                        mode: m,
                        selected: m == mode,
                        future: _futures[m]!,
                        onTap: () => p.setTravelMode(m),
                      ),
                    ))
                .toList(),
          );
        }),
        const SizedBox(height: 20),
        Row(children: [
          Segmented<_Sort>(
            options: const {_Sort.price: 'Prix', _Sort.duration: 'Durée', _Sort.departure: 'Départ'},
            value: _sort,
            onChanged: (v) => setState(() => _sort = v),
          ),
          const SizedBox(width: 12),
          if (mode != TravelMode.car)
            Tag(
              label: mode == TravelMode.plane ? 'Vols directs' : 'Sans correspondance',
              selected: _directOnly,
              onTap: () => setState(() => _directOnly = !_directOnly),
            ),
        ]),
        const SizedBox(height: 16),
        FutureBuilder<List<FlightOption>>(
          key: ValueKey(mode),
          future: _futures[mode],
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(padding: EdgeInsets.all(48), child: Center(child: CupertinoActivityIndicator(radius: 14)));
            }
            final all = snap.data ?? const <FlightOption>[];
            if (all.isEmpty) {
              return SurfaceCard(
                child: Row(children: [
                  Icon(CupertinoIcons.map, color: c.secondary, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      mode == TravelMode.plane
                          ? 'Aucun vol trouvé pour ces dates.'
                          : 'Pas de trajet en ${mode.label.toLowerCase()} réaliste sur cette distance '
                              '(${km.round()} km). Essayez l\'avion.',
                      style: TextStyle(color: c.secondary, fontSize: 15),
                    ),
                  ),
                ]),
              );
            }
            final list = all.where((f) => !_directOnly || f.outStops.isEmpty).toList()
              ..sort((a, b) => switch (_sort) {
                    _Sort.price => a.totalPrice.compareTo(b.totalPrice),
                    _Sort.duration => a.outDuration.compareTo(b.outDuration),
                    _Sort.departure => a.outDepart.compareTo(b.outDepart),
                  });
            final current = t.flight?.totalPrice ?? 0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (p.data.isSimulated || mode != TravelMode.plane) const SimulatedDataNotice(),
                ResponsiveGrid(
                  minItemWidth: 540,
                  children: list
                      .map((f) => _TripCard(
                            option: f,
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

class _ModeTile extends StatelessWidget {
  final TravelMode mode;
  final bool selected;
  final Future<List<FlightOption>> future;
  final VoidCallback onTap;
  const _ModeTile({required this.mode, required this.selected, required this.future, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: selected ? c.accent : Colors.transparent, width: 2),
        boxShadow: softShadow(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              IconTile(travelModeIcon(mode), travelModeColor(c, mode), size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(mode.label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  FutureBuilder<List<FlightOption>>(
                    future: future,
                    builder: (context, snap) {
                      final txt = !snap.hasData
                          ? '…'
                          : snap.data!.isEmpty
                              ? 'Indisponible'
                              : 'dès ${eur(snap.data!.map((f) => f.totalPrice).reduce((a, b) => a < b ? a : b))}';
                      return Text(txt, style: TextStyle(color: c.secondary, fontSize: 13.5));
                    },
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final FlightOption option;
  final bool selected;
  final bool outOfBudget;
  final VoidCallback onTap;

  const _TripCard({required this.option, required this.selected, required this.outOfBudget, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final f = option;
    final c = AppColors.of(context);
    final perGroup = f.mode == TravelMode.car && !f.airline.startsWith('Covoiturage');
    return OptionCard(
      selected: selected,
      outOfBudget: outOfBudget,
      onTap: onTap,
      trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        PriceLabel(eur(f.totalPrice), caption: perGroup ? 'pour le groupe' : '${eur(f.pricePerPerson)} / pers.'),
        const SizedBox(height: 4),
        OfferLink(f.bookingUrl, label: f.mode == TravelMode.car && perGroup ? 'Itinéraire' : 'Voir l\'offre'),
      ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(f.airline, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600, letterSpacing: -0.3)),
          Text(f.flightNumber, style: TextStyle(fontSize: 13, color: c.secondary)),
          const SizedBox(height: 12),
          _Leg(label: 'Aller', depart: f.outDepart, arrive: f.outArrive, stops: f.outStops, mode: f.mode),
          if (f.retDepart != null && f.retArrive != null) ...[
            const SizedBox(height: 10),
            _Leg(label: 'Retour', depart: f.retDepart!, arrive: f.retArrive!, stops: f.retStops, mode: f.mode),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('Retour : horaires sur le site de réservation', style: TextStyle(fontSize: 13, color: c.secondary)),
            ),
        ],
      ),
    );
  }
}

class _Leg extends StatelessWidget {
  final String label;
  final DateTime depart;
  final DateTime arrive;
  final List<String> stops;
  final TravelMode mode;

  const _Leg({required this.label, required this.depart, required this.arrive, required this.stops, required this.mode});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final plusDays = Trip.dateOnly(arrive).difference(Trip.dateOnly(depart)).inDays;
    final stopTxt = mode == TravelMode.car
        ? 'Route'
        : stops.isEmpty
            ? 'Direct'
            : '${stops.length} ${mode == TravelMode.plane ? 'escale' : 'correspondance'}${stops.length > 1 ? 's' : ''} · ${stops.join(', ')}';
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 64,
        child: Text(label, style: TextStyle(fontSize: 13, color: c.secondary, fontWeight: FontWeight.w500)),
      ),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text.rich(TextSpan(children: [
            TextSpan(text: '${hm(depart)}  →  ${hm(arrive)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.3)),
            if (plusDays > 0) TextSpan(text: ' +$plusDays', style: TextStyle(fontSize: 12, color: c.orange, fontWeight: FontWeight.w600)),
          ])),
          Text('${dayShort(depart)} · ${duration(arrive.difference(depart))} · $stopTxt',
              style: TextStyle(fontSize: 13, color: c.secondary)),
        ]),
      ),
    ]);
  }
}
