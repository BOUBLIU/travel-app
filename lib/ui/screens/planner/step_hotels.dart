import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../models/models.dart';
import '../../../state/app_state.dart';
import '../../../state/planner.dart';
import '../../format.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'planner_screen.dart';

/// Étape 5 : préférences hôtel pour une ville, ou hôtel déjà réservé.
class HotelPrefsStep extends StatefulWidget {
  final int stayIndex;
  const HotelPrefsStep({super.key, required this.stayIndex});

  @override
  State<HotelPrefsStep> createState() => _HotelPrefsStepState();
}

class _HotelPrefsStepState extends State<HotelPrefsStep> implements SubmittableStep {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _address;

  @override
  void initState() {
    super.initState();
    final s = context.read<PlannerController>().trip.stays[widget.stayIndex];
    final own = s.alreadyBooked ? s.hotel : null;
    _name = TextEditingController(text: own?.name ?? '');
    _price = TextEditingController(text: own == null ? '' : s.hotelCost.toStringAsFixed(0));
    _address = TextEditingController(text: own != null && own.address != s.place.name ? own.address : '');
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _address.dispose();
    super.dispose();
  }

  double? get _priceValue => double.tryParse(_price.text.replaceAll(' ', '').replaceAll(',', '.'));

  @override
  Future<bool> submit() async {
    final p = context.read<PlannerController>();
    final s = p.trip.stays[widget.stayIndex];
    if (!s.alreadyBooked) return true;
    if (!_form.currentState!.validate()) return false;
    final places = context.read<AppState>().places;
    final name = _name.text.trim();
    final address = _address.text.trim();
    // Position de l'hôtel pour la carte : adresse, sinon nom + ville, sinon centre-ville.
    final pos = await places.geocode(address.isNotEmpty ? '$address, ${s.place.name}' : '$name, ${s.place.name}');
    p.setOwnHotel(
      widget.stayIndex,
      name: name,
      totalPaid: _priceValue!,
      address: address,
      lat: pos?.$1 ?? s.place.lat,
      lng: pos?.$2 ?? s.place.lng,
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlannerController>();
    final s = p.trip.stays[widget.stayIndex];
    final c = AppColors.of(context);
    final perNightBudget = p.remaining > 0 ? p.remaining / s.nights : 0.0;

    Widget priority(HotelPriority v, IconData icon, Color color, String title, String sub) => OptionCard(
          selected: s.priority == v,
          onTap: () => p.setHotelPrefs(widget.stayIndex, v, s.priceRange),
          child: Row(children: [
            IconTile(icon, color, size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(color: c.secondary, fontSize: 14)),
              ]),
            ),
          ]),
        );

    final find = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const GroupHeader('Priorité'),
      ResponsiveGrid(minItemWidth: 380, children: [
        priority(HotelPriority.cheapest, CupertinoIcons.tag_fill, c.green, 'Le moins cher', 'Classés par prix croissant'),
        priority(HotelPriority.comfort, CupertinoIcons.star_fill, c.orange, 'Le plus confortable',
            'Les mieux notés en premier'),
      ]),
      const GroupHeader('Prix par nuit'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: PriceRange.values
            .map((r) => Tag(
                  label: r.label,
                  selected: s.priceRange == r,
                  onTap: () => p.setHotelPrefs(widget.stayIndex, s.priority, r),
                ))
            .toList(),
      ),
    ]);

    final booked = Form(
      key: _form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const GroupHeader('Votre réservation'),
        TextFormField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nom de l\'hôtel', prefixIcon: Icon(CupertinoIcons.bed_double, size: 20)),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Indiquez le nom de l\'hôtel' : null,
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _price,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ,.]'))],
          decoration: InputDecoration(
            labelText: 'Prix total payé (${s.nights} nuit${s.nights > 1 ? 's' : ''})',
            suffixText: '€',
            prefixIcon: const Icon(CupertinoIcons.creditcard, size: 20),
          ),
          validator: (v) {
            final n = _priceValue;
            if (n == null || n < 0) return 'Indiquez le montant payé';
            return null;
          },
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _address,
          decoration: const InputDecoration(
            labelText: 'Adresse (facultatif, pour la carte)',
            prefixIcon: Icon(CupertinoIcons.location, size: 20),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          p.hasBudget
              ? 'Ce montant sera déduit de votre budget. La liste des hôtels sera ignorée pour cette ville.'
              : 'Ce montant sera ajouté au total prévu. La liste des hôtels sera ignorée pour cette ville.',
          style: TextStyle(color: c.secondary, fontSize: 13),
        ),
      ]),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'Hôtel à ${s.place.name}',
          subtitle: '${s.nights} nuit${s.nights > 1 ? 's' : ''} à partir du ${dateFr(p.trip.stayStart(widget.stayIndex))}'
              '${p.hasBudget && !s.alreadyBooked ? ' · jusqu\'à ${eur(perNightBudget)} par nuit avec le budget restant' : ''}.',
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Segmented<bool>(
            options: const {false: 'Trouver un hôtel', true: 'Déjà réservé'},
            value: s.alreadyBooked,
            onChanged: (v) => p.setAlreadyBooked(widget.stayIndex, v),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(key: ValueKey(s.alreadyBooked), child: s.alreadyBooked ? booked : find),
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
    final c = AppColors.of(context);
    final rooms = (p.trip.travelers / 2).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle('Hôtels à ${s.place.name}',
            subtitle: 'Prix pour $rooms chambre${rooms > 1 ? 's' : ''} · total = prix par nuit × ${s.nights} nuit${s.nights > 1 ? 's' : ''}.'),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Segmented<_HotelSort>(
              options: const {_HotelSort.price: 'Prix', _HotelSort.rating: 'Avis'},
              value: _sort,
              onChanged: (v) => setState(() => _sort = v),
            ),
            const SizedBox(width: 4),
            ...PriceRange.values.map((r) => Tag(
                  label: r.label,
                  selected: _range == r,
                  onTap: () => setState(() => _range = r),
                )),
          ],
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<HotelOption>>(
          future: _future,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Padding(padding: EdgeInsets.all(48), child: Center(child: CupertinoActivityIndicator(radius: 14)));
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
                    child: Text('Aucun hôtel dans cette gamme de prix.', style: TextStyle(color: c.secondary)),
                  ),
                ResponsiveGrid(
                  minItemWidth: 440,
                  children: list.map((h) {
                    final total = h.pricePerNight * s.nights;
                    return OptionCard(
                      selected: s.hotel?.id == h.id,
                      outOfBudget: !p.fits(total, replacing: current),
                      onTap: () => p.setHotel(widget.stayIndex, h),
                      trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        PriceLabel(eur(h.pricePerNight), caption: '/ nuit'),
                        const SizedBox(height: 2),
                        Text('Total ${eur(total)}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                        OfferLink(h.bookingUrl),
                      ]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(h.name, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600, letterSpacing: -0.3)),
                          const SizedBox(height: 4),
                          StarRow(h.stars),
                          const SizedBox(height: 8),
                          RatingBadge(h.rating, h.reviews),
                          const SizedBox(height: 8),
                          Row(children: [
                            Icon(CupertinoIcons.location, size: 13, color: c.secondary),
                            const SizedBox(width: 4),
                            Expanded(child: Text(h.address, style: TextStyle(fontSize: 13, color: c.secondary))),
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
