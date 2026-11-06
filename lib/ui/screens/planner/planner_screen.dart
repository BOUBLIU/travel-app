import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/models.dart' hide TransferStep;
import '../../../state/app_state.dart';
import '../../../state/planner.dart';
import '../../theme.dart';
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
        fullscreenDialog: true,
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
    final mode = p.trip.travelMode;
    final steps = <_StepDef>[
      _StepDef('Budget et destination', (k) => BasicsStep(key: k), (_) => true),
      _StepDef('Transport', (k) => TransportStep(key: k), (p) => p.trip.flight != null,
          blockedHint: 'Choisissez un trajet'),
      if (mode.needsTransfer)
        _StepDef('Arrivée en ville', (k) => TransferStep(key: k), (p) => p.trip.arrivalTransfer != null,
            blockedHint: 'Choisissez le trajet d\'arrivée', id: 'transfer-${mode.name}'),
      _StepDef('Logement', (k) => LodgingStep(key: k), (_) => true),
    ];
    for (var i = 0; i < p.trip.stays.length; i++) {
      final s = p.trip.stays[i];
      final city = s.place.name;
      final multi = p.trip.stays.length > 1;
      steps.add(_StepDef(
        multi ? 'Hôtel à $city' : 'Votre hôtel',
        (k) => HotelPrefsStep(key: k, stayIndex: i),
        (_) => true,
        id: 'prefs$i$city',
      ));
      if (!s.alreadyBooked) {
        steps.add(_StepDef(
          multi ? 'Hôtels à $city' : 'Hôtels',
          (k) => HotelsStep(key: k, stayIndex: i),
          (p) => i < p.trip.stays.length && p.trip.stays[i].hotel != null,
          blockedHint: 'Choisissez un hôtel',
          id: 'hotels$i$city',
        ));
      }
    }
    steps.addAll([
      _StepDef('Repas', (k) => MealsStep(key: k), (p) => p.trip.mealProfile != null,
          blockedHint: 'Choisissez un profil'),
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
    // Retrouve la position de l'étape courante dans la liste à jour (elle peut avoir changé).
    final currentId = steps[_index].id;
    final pos = fresh.indexWhere((s) => s.id == currentId);
    setState(() => _index = ((pos < 0 ? _index : pos) + 1).clamp(0, fresh.length - 1));
    _scrollTop();
  }

  void _back() {
    if (_index == 0) return;
    setState(() => _index--);
    _scrollTop();
  }

  void _scrollTop() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<bool> _confirmQuit() async {
    final r = await showCupertinoDialog<bool>(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: const Text('Quitter la planification ?'),
        content: const Text('Ce voyage n\'est pas encore enregistré. Vos choix seront perdus.'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(c, false), child: const Text('Continuer')),
          CupertinoDialogAction(
              isDestructiveAction: true, onPressed: () => Navigator.pop(c, true), child: const Text('Quitter')),
        ],
      ),
    );
    return r ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlannerController>();
    final c = AppColors.of(context);
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
          leadingWidth: 64,
          leading: IconButton(
            icon: const Icon(CupertinoIcons.xmark, size: 20),
            tooltip: 'Quitter',
            onPressed: () async {
              if (await _confirmQuit() && context.mounted) Navigator.of(context).pop();
            },
          ),
          title: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(step.title),
            Text('Étape ${_index + 1} sur ${steps.length}',
                style: TextStyle(fontSize: 12, color: c.secondary, fontWeight: FontWeight.w500)),
          ]),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: (_index + 1) / steps.length),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 3, backgroundColor: Colors.transparent),
            ),
          ),
        ),
        body: Column(
          children: [
            if (_index > 0) const BudgetBanner(),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, a) => FadeTransition(
                        opacity: a,
                        child: SlideTransition(
                          position: Tween(begin: const Offset(0.02, 0), end: Offset.zero).animate(a),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(key: ValueKey(step.id), child: step.build(step.key)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: isLast
            ? null
            : ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.background.withValues(alpha: 0.85),
                      border: Border(top: BorderSide(color: c.separator, width: 0.6)),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 24, 10),
                        child: Row(
                          children: [
                            TextButton.icon(
                              onPressed: _index == 0 ? null : _back,
                              icon: const Icon(CupertinoIcons.chevron_back, size: 18),
                              label: const Text('Retour'),
                            ),
                            Expanded(
                              child: Text(
                                can ? '' : (step.blockedHint ?? ''),
                                textAlign: TextAlign.center,
                                style: TextStyle(color: c.secondary, fontSize: 13.5),
                              ),
                            ),
                            FilledButton(
                              onPressed: can && !_busy ? () => _next(steps) : null,
                              child: _busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Continuer'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
