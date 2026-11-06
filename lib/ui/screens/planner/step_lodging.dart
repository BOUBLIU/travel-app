import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/models.dart';
import '../../../services/places.dart';
import '../../../state/app_state.dart';
import '../../../state/planner.dart';
import '../../widgets/common.dart';
import 'planner_screen.dart';

class _CityRow {
  final TextEditingController name;
  final FocusNode focus = FocusNode();
  int nights;
  _CityRow(String n, this.nights) : name = TextEditingController(text: n);

  void dispose() {
    name.dispose();
    focus.dispose();
  }
}

/// Étape 4 : un seul hôtel ou plusieurs villes.
class LodgingStep extends StatefulWidget {
  const LodgingStep({super.key});

  @override
  State<LodgingStep> createState() => _LodgingStepState();
}

class _LodgingStepState extends State<LodgingStep> implements SubmittableStep {
  late bool _multi;
  late List<_CityRow> _rows;

  @override
  void initState() {
    super.initState();
    final t = context.read<PlannerController>().trip;
    _multi = t.multiCity;
    if (t.multiCity && t.stays.length > 1) {
      _rows = t.stays.map((s) => _CityRow(s.place.name, s.nights)).toList();
    } else {
      final half = (t.nights / 2).ceil();
      _rows = [_CityRow(t.destination!.name, half), _CityRow('', t.nights - half)];
    }
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  int get _total => _rows.fold(0, (a, r) => a + r.nights);

  @override
  Future<bool> submit() async {
    final p = context.read<PlannerController>();
    final t = p.trip;
    final messenger = ScaffoldMessenger.of(context);
    if (!_multi) {
      p.setStays(false, [CityStay(place: t.destination!, nights: t.nights)]);
      return true;
    }
    if (_rows.any((r) => r.name.text.trim().isEmpty || r.nights < 1)) {
      messenger.showSnackBar(const SnackBar(content: Text('Indiquez chaque ville et au moins 1 nuit.')));
      return false;
    }
    if (_total != t.nights) {
      messenger.showSnackBar(SnackBar(
          content: Text('Le total des nuits ($_total) doit être égal à la durée du séjour (${t.nights} nuits).')));
      return false;
    }
    final app = context.read<AppState>();
    final stays = <CityStay>[];
    for (final r in _rows) {
      final name = r.name.text.trim();
      final place = name.toLowerCase() == t.destination!.name.toLowerCase()
          ? t.destination!
          : await app.places.resolve(name);
      if (place == null) {
        messenger.showSnackBar(SnackBar(content: Text('Ville introuvable : $name')));
        return false;
      }
      stays.add(CityStay(place: place, nights: r.nights));
    }
    p.setStays(true, stays);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<PlannerController>().trip;
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle('Où allez-vous dormir ?',
            subtitle: '${t.nights} nuits à répartir. Vous pourrez choisir un hôtel pour chaque ville.'),
        ResponsiveGrid(minItemWidth: 380, children: [
          OptionCard(
            selected: !_multi,
            onTap: () => setState(() => _multi = false),
            child: Row(children: [
              const Icon(Icons.hotel, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Un seul hôtel', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  Text('Toutes les nuits à ${t.destination!.name}'),
                ]),
              ),
            ]),
          ),
          OptionCard(
            selected: _multi,
            onTap: () => setState(() => _multi = true),
            child: Row(children: [
              const Icon(Icons.route, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Plusieurs villes', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const Text('Un road-trip ou un circuit, trains entre les villes inclus'),
                ]),
              ),
            ]),
          ),
        ]),
        if (_multi) ...[
          const SizedBox(height: 16),
          Text('Villes, dans l\'ordre du circuit', style: tt.titleMedium),
          const SizedBox(height: 8),
          ..._rows.asMap().entries.map((e) {
            final i = e.key;
            final r = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CircleAvatar(radius: 14, child: Text('${i + 1}')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RawAutocomplete<Place>(
                      key: ObjectKey(r),
                      textEditingController: r.name,
                      focusNode: r.focus,
                      displayStringForOption: (p) => p.name,
                      optionsBuilder: (v) => PlaceService.suggest(v.text),
                      fieldViewBuilder: (context, c, focus, _) => TextField(
                        controller: c,
                        focusNode: focus,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Ville', border: OutlineInputBorder()),
                      ),
                      optionsViewBuilder: (context, onSelected, options) => Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(8),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 280, maxWidth: 420),
                            child: ListView(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              children: options
                                  .map((p) => ListTile(
                                        title: Text(p.name),
                                        subtitle: Text(p.country),
                                        onTap: () => onSelected(p),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    onPressed: r.nights > 1 ? () => setState(() => r.nights--) : null,
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text('${r.nights} nuit${r.nights > 1 ? 's' : ''}', textAlign: TextAlign.center),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => setState(() => r.nights++),
                    icon: const Icon(Icons.add),
                  ),
                  IconButton(
                    tooltip: 'Retirer',
                    onPressed: _rows.length > 2 ? () => setState(() => _rows.removeAt(i).dispose()) : null,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            );
          }),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _rows.add(_CityRow('', 1))),
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Ajouter une ville'),
              ),
              const Spacer(),
              Text(
                'Total : $_total / ${t.nights} nuits',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _total == t.nights ? scheme.primary : scheme.error,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
