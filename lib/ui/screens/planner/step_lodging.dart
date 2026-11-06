import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/models.dart';
import '../../../services/places.dart';
import '../../../state/app_state.dart';
import '../../../state/planner.dart';
import '../../theme.dart';
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

  Widget _choice(BuildContext context, bool multi, IconData icon, Color color, String title, String sub) {
    return OptionCard(
      selected: _multi == multi,
      onTap: () => setState(() => _multi = multi),
      child: Row(children: [
        IconTile(icon, color, size: 44),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(color: AppColors.of(context).secondary, fontSize: 14)),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<PlannerController>().trip;
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle('Où dormir ?', subtitle: '${t.nights} nuits à répartir.'),
        ResponsiveGrid(minItemWidth: 380, children: [
          _choice(context, false, CupertinoIcons.bed_double_fill, c.accent, 'Un seul hôtel',
              'Toutes les nuits à ${t.destination!.name}'),
          _choice(context, true, CupertinoIcons.map_fill, const Color(0xFF5856D6), 'Plusieurs villes',
              'Un circuit, trains entre les villes inclus'),
        ]),
        if (_multi) ...[
          GroupHeader('Villes, dans l\'ordre du circuit',
              trailing: Text(
                '$_total / ${t.nights} nuits',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _total == t.nights ? c.green : c.red),
              )),
          GroupedList(children: [
            ..._rows.asMap().entries.map((e) {
              final i = e.key;
              final r = e.value;
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                    child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RawAutocomplete<Place>(
                      key: ObjectKey(r),
                      textEditingController: r.name,
                      focusNode: r.focus,
                      displayStringForOption: (p) => p.name,
                      optionsBuilder: (v) => PlaceService.suggest(v.text),
                      fieldViewBuilder: (context, ctl, focus, _) => TextField(
                        controller: ctl,
                        focusNode: focus,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: 'Ville',
                          filled: true,
                          fillColor: c.background,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      optionsViewBuilder: (context, onSelected, options) => Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          color: c.card,
                          elevation: 8,
                          shadowColor: Colors.black26,
                          borderRadius: BorderRadius.circular(14),
                          clipBehavior: Clip.antiAlias,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 280, maxWidth: 420),
                            child: ListView(
                              padding: const EdgeInsets.symmetric(vertical: 6),
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
                  const SizedBox(width: 12),
                  CountStepper(
                    value: r.nights,
                    format: (v) => '$v nuit${v > 1 ? 's' : ''}',
                    onChanged: (v) => setState(() => r.nights = v),
                  ),
                  IconButton(
                    tooltip: 'Retirer',
                    onPressed: _rows.length > 2 ? () => setState(() => _rows.removeAt(i).dispose()) : null,
                    icon: Icon(CupertinoIcons.minus_circle_fill, color: _rows.length > 2 ? c.red : c.tertiary),
                  ),
                ]),
              );
            }),
            GroupedRow(
              leading: Icon(CupertinoIcons.plus_circle_fill, color: c.green, size: 26),
              title: 'Ajouter une ville',
              trailing: const SizedBox.shrink(),
              onTap: () => setState(() => _rows.add(_CityRow('', 1))),
            ),
          ]),
        ],
      ],
    );
  }
}
