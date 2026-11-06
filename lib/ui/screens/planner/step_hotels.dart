import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/models.dart';
import '../../../state/planner.dart';
import '../../format.dart';
import '../../widgets/common.dart';

/// Étape 5 : préférences hôtel pour une ville.
class HotelPrefsStep extends StatelessWidget {
  final int stayIndex;
  const HotelPrefsStep({super.key, required this.stayIndex});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlannerController>();
    final s = p.trip.stays[stayIndex];
    final tt = Theme.of(context).textTheme;
    final perNightBudget = p.remaining > 0 ? p.remaining / s.nights : 0.0;

    Widget priority(HotelPriority v, IconData icon, String title, String sub) => OptionCard(
          selected: s.priority == v,
          onTap: () => p.setHotelPrefs(stayIndex, v, s.priceRange),
          child: Row(children: [
            Icon(icon, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                Text(sub),
              ]),
            ),
          ]),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle('Votre hôtel à ${s.place.name}',
            subtitle: '${s.nights} nuit${s.nights > 1 ? 's' : ''} à partir du ${dateFr(p.trip.stayStart(stayIndex))}. '
                'Budget restant : ${eur(p.remaining)}, soit ${eur(perNightBudget)} max. par nuit.'),
        ResponsiveGrid(minItemWidth: 380, children: [
          priority(HotelPriority.cheapest, Icons.savings_outlined, 'Le moins cher',
              'Les hôtels classés par prix croissant'),
          priority(HotelPriority.comfort, Icons.king_bed_outlined, 'Le plus confortable',
              'Les mieux notés et les plus étoilés en premier'),
        ]),
        const SizedBox(height: 20),
        Text('Gamme de prix par nuit', style: tt.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PriceRange.values
              .map((r) => ChoiceChip(
                    label: Text(r.label),
                    selected: s.priceRange == r,
                    onSelected: (_) => p.setHotelPrefs(stayIndex, s.priority, r),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

enum _HotelSort { price, rating }

/// Étape 6 : liste des hôtels d'une ville.
class HotelsStep extends StatefulWidget {
  final int stayIndex;
  const HotelsStep({super.key, required this.stayIndex});

  @override
  State<HotelsStep> createState() => _HotelsStepState();
}

class _HotelsStepState extends State<HotelsStep> {
  late Future<List<HotelOption>> _future;
  late _HotelSort _sort;
  late PriceRange _range;

  @override
  void initState() {
    super.initState();
    final p = context.read<PlannerController>();
    final s = p.trip.stays[widget.stayIndex];
    _sort = s.priority == HotelPriority.cheapest ? _HotelSort.price : _HotelSort.rating;
    _range = s.priceRange;
    _future = p.data.searchHotels(
      city: s.place,
      checkIn: p.trip.stayStart(widget.stayIndex),
      nights: s.nights,
      travelers: p.trip.travelers,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlannerController>();
    final s = p.trip.stays[widget.stayIndex];
    final tt = Theme.of(context).textTheme;
    final rooms = (p.trip.travelers / 2).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle('Hôtels à ${s.place.name}',
            subtitle: 'Prix pour $rooms chambre${rooms > 1 ? 's' : ''} (${p.trip.travelers} voyageur${p.trip.travelers > 1 ? 's' : ''}). '
                'Total déduit = prix par nuit × ${s.nights} nuit${s.nights > 1 ? 's' : ''}.'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<_HotelSort>(
              segments: const [
                ButtonSegment(value: _HotelSort.price, label: Text('Prix'), icon: Icon(Icons.euro)),
                ButtonSegment(value: _HotelSort.rating, label: Text('Avis'), icon: Icon(Icons.star_outline)),
              ],
              selected: {_sort},
              onSelectionChanged: (v) => setState(() => _sort = v.first),
            ),
            ...PriceRange.values.map((r) => ChoiceChip(
                  label: Text(r.label),
                  selected: _range == r,
                  onSelected: (_) => setState(() => _range = r),
                )),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<HotelOption>>(
          future: _future,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
            }
            final list = snap.data!.where((h) => _range.accepts(h.pricePerNight)).toList()
              ..sort((a, b) => _sort == _HotelSort.price
                  ? a.pricePerNight.compareTo(b.pricePerNight)
                  : (b.rating * 10 + b.stars).compareTo(a.rating * 10 + a.stars));
            final current = s.hotelCost;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (p.data.isSimulated) const SimulatedDataNotice(),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Aucun hôtel dans cette gamme de prix. Essayez « ${PriceRange.any.label} ».'),
                  ),
                ResponsiveGrid(
                  minItemWidth: 420,
                  children: list.map((h) {
                    final total = h.pricePerNight * s.nights;
                    return OptionCard(
                      selected: s.hotel?.id == h.id,
                      outOfBudget: !p.fits(total, replacing: current),
                      onTap: () => p.setHotel(widget.stayIndex, h),
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(eur(h.pricePerNight), style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                          Text('/ nuit', style: tt.bodySmall),
                          Text('Total ${eur(total)}', style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                          TextButton(onPressed: () => openLink(context, h.bookingUrl), child: const Text('Voir l\'offre')),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(h.name, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          StarRow(h.stars),
                          const SizedBox(height: 6),
                          RatingBadge(h.rating, h.reviews),
                          const SizedBox(height: 6),
                          Row(children: [
                            const Icon(Icons.place_outlined, size: 16),
                            const SizedBox(width: 4),
                            Expanded(child: Text(h.address, style: tt.bodySmall)),
                          ]),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
