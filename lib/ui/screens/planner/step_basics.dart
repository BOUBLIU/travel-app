import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../models/models.dart';
import '../../../services/places.dart';
import '../../../state/app_state.dart';
import '../../../state/planner.dart';
import '../../format.dart';
import '../../widgets/common.dart';
import 'planner_screen.dart';

/// Étape 1 : budget, destination, dates et voyageurs.
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

  @override
  void initState() {
    super.initState();
    final t = context.read<PlannerController>().trip;
    _budget = TextEditingController(text: t.budget > 0 ? t.budget.toStringAsFixed(0) : '');
    _dates = DateTimeRange(start: t.startDate, end: t.endDate);
    _travelers = t.travelers;
  }

  @override
  void dispose() {
    _budget.dispose();
    super.dispose();
  }

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
      budget: double.parse(_budget.text.replaceAll(' ', '').replaceAll(',', '.')),
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
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            border: const OutlineInputBorder(),
            helperText: 'Ville (ex. Tokyo, Lisbonne, New York…)',
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null,
        );
      },
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320, maxWidth: 520),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: options
                  .map((p) => ListTile(
                        leading: const Icon(Icons.location_city),
                        title: Text(p.name),
                        subtitle: Text('${p.country} · ${p.currency}'),
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
    final wide = MediaQuery.sizeOf(context).width > 800;
    final nights = _dates.end.difference(_dates.start).inDays;

    final budgetField = TextFormField(
      controller: _budget,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ,.]'))],
      style: Theme.of(context).textTheme.headlineSmall,
      decoration: const InputDecoration(
        labelText: 'Budget maximum (tout compris)',
        suffixText: '€',
        prefixIcon: Icon(Icons.savings_outlined),
        border: OutlineInputBorder(),
      ),
      validator: (v) {
        final n = double.tryParse((v ?? '').replaceAll(' ', '').replaceAll(',', '.'));
        if (n == null || n <= 0) return 'Indiquez un budget';
        return null;
      },
    );

    final origin = _cityField(
      label: 'Ville de départ',
      icon: Icons.flight_takeoff,
      initial: t.origin?.name ?? 'Paris',
      bind: (c) => _origin = c,
    );
    final dest = _cityField(
      label: 'Destination',
      icon: Icons.flight_land,
      initial: t.destination?.name ?? '',
      bind: (c) => _destination = c,
    );

    final dates = InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () async {
        final now = DateTime.now();
        final r = await showDateRangePicker(
          context: context,
          firstDate: Trip.dateOnly(now),
          lastDate: now.add(const Duration(days: 365 * 2)),
          initialDateRange: _dates.start.isBefore(Trip.dateOnly(now))
              ? DateTimeRange(start: Trip.dateOnly(now), end: Trip.dateOnly(now).add(const Duration(days: 7)))
              : _dates,
          helpText: 'Dates du séjour',
          saveText: 'Valider',
        );
        if (r != null && r.end.isAfter(r.start)) setState(() => _dates = r);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Dates',
          prefixIcon: Icon(Icons.date_range),
          border: OutlineInputBorder(),
        ),
        child: Text('${dateFr(_dates.start)} → ${dateFr(_dates.end)}  ($nights nuit${nights > 1 ? 's' : ''})'),
      ),
    );

    final travelers = InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Voyageurs',
        prefixIcon: Icon(Icons.group_outlined),
        border: OutlineInputBorder(),
      ),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: _travelers > 1 ? () => setState(() => _travelers--) : null,
            icon: const Icon(Icons.remove),
          ),
          Expanded(
            child: Text('$_travelers voyageur${_travelers > 1 ? 's' : ''}',
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          ),
          IconButton.filledTonal(
            onPressed: _travelers < 12 ? () => setState(() => _travelers++) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );

    Widget pair(Widget a, Widget b) => wide
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: a),
            const SizedBox(width: 16),
            Expanded(child: b),
          ])
        : Column(children: [a, const SizedBox(height: 16), b]);

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('Où partez-vous, et avec quel budget ?',
              subtitle: 'Chaque choix des étapes suivantes sera déduit de ce budget en temps réel.'),
          budgetField,
          const SizedBox(height: 16),
          pair(origin, dest),
          const SizedBox(height: 16),
          pair(dates, travelers),
        ],
      ),
    );
  }
}
