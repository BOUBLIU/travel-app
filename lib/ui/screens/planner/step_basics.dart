import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../models/models.dart';
import '../../../services/places.dart';
import '../../../state/app_state.dart';
import '../../../state/planner.dart';
import '../../format.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'planner_screen.dart';

/// Étape 1 : budget (ou pas), itinéraire, dates et voyageurs.
class BasicsStep extends StatefulWidget {
  const BasicsStep({super.key});

  @override
  State<BasicsStep> createState() => _BasicsStepState();
}

class _BasicsStepState extends State<BasicsStep> implements SubmittableStep {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _budget;
  TextEditingController? _origin;
  TextEditingController? _destination;
  late DateTimeRange _dates;
  late int _travelers;
  late bool _hasBudget;

  @override
  void initState() {
    super.initState();
    final t = context.read<PlannerController>().trip;
    _budget = TextEditingController(text: t.budget > 0 ? t.budget.toStringAsFixed(0) : '');
    _dates = DateTimeRange(start: t.startDate, end: t.endDate);
    _travelers = t.travelers;
    _hasBudget = t.hasBudget;
  }

  @override
  void dispose() {
    _budget.dispose();
    super.dispose();
  }

  double? get _budgetValue => double.tryParse(_budget.text.replaceAll(' ', '').replaceAll(',', '.'));

  @override
  Future<bool> submit() async {
    if (!_form.currentState!.validate()) return false;
    final app = context.read<AppState>();
    final planner = context.read<PlannerController>();
    final messenger = ScaffoldMessenger.of(context);
    final originName = _origin!.text.trim();
    final destName = _destination!.text.trim();
    final results = await Future.wait([app.places.resolve(originName), app.places.resolve(destName)]);
    if (results[0] == null || results[1] == null) {
      messenger.showSnackBar(SnackBar(
        content: Text('Ville introuvable : ${results[0] == null ? originName : destName}. '
            'Vérifiez l\'orthographe ou votre connexion.'),
      ));
      return false;
    }
    planner.setBasics(
      origin: results[0]!,
      destination: results[1]!,
      start: Trip.dateOnly(_dates.start),
      end: Trip.dateOnly(_dates.end),
      travelers: _travelers,
      budget: _hasBudget ? _budgetValue! : 0,
      hasBudget: _hasBudget,
    );
    return true;
  }

  Widget _cityField({
    required String label,
    required IconData icon,
    required String initial,
    required void Function(TextEditingController) bind,
  }) {
    return Autocomplete<Place>(
      initialValue: TextEditingValue(text: initial),
      displayStringForOption: (p) => p.name,
      optionsBuilder: (v) => PlaceService.suggest(v.text),
      fieldViewBuilder: (context, controller, focus, onSubmit) {
        bind(controller);
        return TextFormField(
          controller: controller,
          focusNode: focus,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, size: 20),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Indiquez une ville' : null,
        );
      },
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          color: AppColors.of(context).card,
          elevation: 8,
          shadowColor: Colors.black26,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320, maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              shrinkWrap: true,
              children: options
                  .map((p) => ListTile(
                        leading: Icon(CupertinoIcons.location_solid, size: 18, color: AppColors.of(context).accent),
                        title: Text(p.name),
                        subtitle: Text(p.country),
                        onTap: () => onSelected(p),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.read<PlannerController>().trip;
    final c = AppColors.of(context);
    final wide = MediaQuery.sizeOf(context).width > 900;
    final nights = _dates.end.difference(_dates.start).inDays;

    final budgetCard = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const GroupHeader('Budget'),
      SurfaceCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Segmented<bool>(
            options: const {true: 'Avec un budget', false: 'Sans budget'},
            value: _hasBudget,
            onChanged: (v) => setState(() => _hasBudget = v),
          ),
          const SizedBox(height: 18),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _hasBudget ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Budget maximum, tout compris', style: TextStyle(color: c.secondary, fontSize: 14)),
              TextFormField(
                controller: _budget,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ,.]'))],
                style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w700, letterSpacing: -1.5),
                decoration: InputDecoration(
                  hintText: '2 000',
                  suffixText: '€',
                  suffixStyle: TextStyle(fontSize: 30, fontWeight: FontWeight.w600, color: c.secondary),
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                validator: (v) {
                  if (!_hasBudget) return null;
                  final n = _budgetValue;
                  if (n == null || n <= 0) return 'Indiquez un budget';
                  return null;
                },
              ),
              Text('Chaque choix sera déduit de ce montant en temps réel.',
                  style: TextStyle(color: c.secondary, fontSize: 13)),
            ]),
            secondChild: Row(children: [
              IconTile(CupertinoIcons.infinite, c.accent, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Planifiez librement : l\'app additionne le coût de vos choix au fur et à mesure, sans rien bloquer.',
                  style: TextStyle(color: c.secondary, fontSize: 14.5, height: 1.35),
                ),
              ),
            ]),
          ),
        ]),
      ),
    ]);

    final route = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const GroupHeader('Itinéraire'),
      _cityField(
        label: 'Départ',
        icon: CupertinoIcons.location,
        initial: t.origin?.name ?? 'Paris',
        bind: (c) => _origin = c,
      ),
      const SizedBox(height: 10),
      _cityField(
        label: 'Destination',
        icon: CupertinoIcons.map_pin_ellipse,
        initial: t.destination?.name ?? '',
        bind: (c) => _destination = c,
      ),
    ]);

    final when = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const GroupHeader('Dates et voyageurs'),
      GroupedList(children: [
        GroupedRow(
          leading: IconTile(CupertinoIcons.calendar, c.red),
          title: '${dateFr(_dates.start)} → ${dateFr(_dates.end)}',
          subtitle: '$nights nuit${nights > 1 ? 's' : ''}',
          onTap: () async {
            final now = Trip.dateOnly(DateTime.now());
            final r = await showDateRangePicker(
              context: context,
              firstDate: now,
              lastDate: now.add(const Duration(days: 365 * 2)),
              initialDateRange: _dates.start.isBefore(now)
                  ? DateTimeRange(start: now, end: now.add(const Duration(days: 7)))
                  : _dates,
              helpText: 'Dates du séjour',
              saveText: 'Valider',
            );
            if (r != null && r.end.isAfter(r.start)) setState(() => _dates = r);
          },
        ),
        GroupedRow(
          leading: IconTile(CupertinoIcons.person_2_fill, c.green),
          title: 'Voyageurs',
          trailing: CountStepper(
            value: _travelers,
            max: 12,
            format: (v) => '$v',
            onChanged: (v) => setState(() => _travelers = v),
          ),
        ),
      ]),
    ]);

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('Votre voyage', subtitle: 'Où allez-vous, quand, et avec quel budget ?'),
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: budgetCard),
              const SizedBox(width: 24),
              Expanded(child: Column(children: [route, when])),
            ])
          else ...[
            budgetCard,
            route,
            when,
          ],
        ],
      ),
    );
  }
}
