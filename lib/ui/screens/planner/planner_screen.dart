import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/app_state.dart';
import '../../../state/planner.dart';
import '../../widgets/budget_banner.dart';
import 'step_activities.dart';
import 'step_basics.dart';
import 'step_flight.dart';
import 'step_hotels.dart';
import 'step_local_transport.dart';
import 'step_lodging.dart';
import 'step_meals.dart';
import 'step_summary.dart';
import 'step_transfer.dart';

/// Interface commune des étapes qui doivent valider/enregistrer avant de continuer.
abstract class SubmittableStep {
  Future<bool> submit();
}

class _StepDef {
  final String title;
  final Widget Function(GlobalKey key) build;
  final bool Function(PlannerController p) canContinue;
  final String? blockedHint;
  final String id;
  late GlobalKey key;
  _StepDef(this.title, this.build, this.canContinue, {this.blockedHint, String? id}) : id = id ?? title;
}

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  static Route<void> route(AppState app) => MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => PlannerController(app.data),
          child: const PlannerScreen(),
        ),
      );

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  int _index = 0;
  bool _busy = false;
  final _scroll = ScrollController();
  // Clés stables par étape, pour conserver l'état des formulaires entre deux reconstructions.
  final Map<String, GlobalKey> _keys = {};

  List<_StepDef> _steps(PlannerController p) {
    final steps = <_StepDef>[
      _StepDef('Budget et destination', (k) => BasicsStep(key: k), (_) => true),
      _StepDef('Vol', (k) => FlightStep(key: k), (p) => p.trip.flight != null,
          blockedHint: 'Choisissez un vol pour continuer'),
      _StepDef('Trajets depuis l\'aéroport', (k) => TransferStep(key: k),
          (p) => p.trip.arrivalTransfer != null,
          blockedHint: 'Choisissez au moins le trajet d\'arrivée'),
      _StepDef('Choix du logement', (k) => LodgingStep(key: k), (_) => true),
    ];
    for (var i = 0; i < p.trip.stays.length; i++) {
      final city = p.trip.stays[i].place.name;
      final multi = p.trip.stays.length > 1;
      steps.add(_StepDef(
        multi ? 'Préférences hôtel — $city' : 'Préférences hôtel',
        (k) => HotelPrefsStep(key: k, stayIndex: i),
        (_) => true,
        id: 'prefs$i$city',
      ));
      steps.add(_StepDef(
        multi ? 'Hôtels — $city' : 'Hôtels',
        (k) => HotelsStep(key: k, stayIndex: i),
        (p) => i < p.trip.stays.length && p.trip.stays[i].hotel != null,
        blockedHint: 'Choisissez un hôtel pour continuer',
        id: 'hotels$i$city',
      ));
    }
    steps.addAll([
      _StepDef('Repas', (k) => MealsStep(key: k), (p) => p.trip.mealProfile != null,
          blockedHint: 'Choisissez un profil de repas'),
      _StepDef('Activités', (k) => ActivitiesStep(key: k), (_) => true),
      _StepDef('Transports sur place', (k) => LocalTransportStep(key: k), (_) => true),
      _StepDef('Récapitulatif', (k) => SummaryStep(key: k), (_) => true),
    ]);
    for (final s in steps) {
      s.key = _keys.putIfAbsent(s.id, () => GlobalKey());
    }
    return steps;
  }

  Future<void> _next(List<_StepDef> steps) async {
    final state = steps[_index].key.currentState;
    if (state is SubmittableStep) {
      setState(() => _busy = true);
      final ok = await (state as SubmittableStep).submit();
      if (!mounted) return;
      setState(() => _busy = false);
      if (!ok) return;
    }
    if (!mounted) return;
    final fresh = _steps(context.read<PlannerController>());
    setState(() => _index = (_index + 1).clamp(0, fresh.length - 1));
    _scrollTop();
  }

  void _back() {
    if (_index == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _index--);
    _scrollTop();
  }

  void _scrollTop() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<bool> _confirmQuit() async {
    final r = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Quitter la planification ?'),
        content: const Text('Le voyage en cours n\'est pas enregistré. Vos choix seront perdus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Continuer')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Quitter')),
        ],
      ),
    );
    return r ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlannerController>();
    final steps = _steps(p);
    if (_index >= steps.length) _index = steps.length - 1;
    final step = steps[_index];
    final isLast = _index == steps.length - 1;
    final can = step.canContinue(p);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_index > 0) {
          _back();
        } else if (await _confirmQuit() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Étape ${_index + 1}/${steps.length} · ${step.title}'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Quitter',
            onPressed: () async {
              if (await _confirmQuit() && context.mounted) Navigator.of(context).pop();
            },
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(value: (_index + 1) / steps.length, minHeight: 4),
          ),
        ),
        body: Column(
          children: [
            if (_index > 0) const BudgetBanner(),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: KeyedSubtree(
                      key: ValueKey(step.key),
                      child: step.build(step.key),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: isLast
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _index == 0 ? null : _back,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Précédent'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          can ? '' : (step.blockedHint ?? ''),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: can && !_busy ? () => _next(steps) : null,
                        icon: _busy
                            ? const SizedBox(
                                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.arrow_forward),
                        label: const Text('Suivant'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
