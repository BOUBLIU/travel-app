import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/planner.dart';
import '../format.dart';
import '../theme.dart';

/// Bandeau budget affiché en haut de chaque écran du parcours.
class BudgetBanner extends StatelessWidget {
  const BudgetBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlannerController>();
    final c = AppColors.of(context);
    final over = p.hasBudget && p.remaining < 0;
    final color = over
        ? c.red
        : p.lowBudget
            ? c.orange
            : c.label;

    final Widget main = p.hasBudget
        ? _Big(label: over ? 'Dépassement' : 'Restant', value: eur(p.remaining.abs()), color: color)
        : _Big(label: 'Total prévu', value: eur(p.spent), color: c.label);

    final Widget side = p.hasBudget
        ? Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _Small('Dépensé', eur(p.spent)),
            const SizedBox(height: 2),
            _Small('Budget', eur(p.trip.budget)),
          ])
        : Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(CupertinoIcons.infinite, size: 18, color: c.secondary),
            const SizedBox(width: 6),
            Text('Sans budget fixe', style: TextStyle(color: c.secondary, fontSize: 13.5)),
          ]);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: c.background.withValues(alpha: 0.82),
            border: Border(bottom: BorderSide(color: c.separator, width: 0.6)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: main), side]),
                  if (p.hasBudget) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: p.progress),
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, _) => LinearProgressIndicator(
                          value: v,
                          minHeight: 6,
                          color: over || p.lowBudget ? color : c.accent,
                          backgroundColor: c.fill,
                        ),
                      ),
                    ),
                  ],
                  if (p.lowBudget) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(CupertinoIcons.exclamationmark_triangle_fill, color: color, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          over
                              ? 'Budget dépassé : revoyez l\'un de vos choix.'
                              : 'Il reste moins de 10 % de votre budget.',
                          style: TextStyle(color: color, fontWeight: FontWeight.w500, fontSize: 13),
                        ),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Big extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Big({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(color: c.secondary, fontSize: 13, fontWeight: FontWeight.w500)),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, a) => FadeTransition(opacity: a, child: child),
        child: Text(value,
            key: ValueKey(value),
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -1, color: color, height: 1.1)),
      ),
    ]);
  }
}

class _Small extends StatelessWidget {
  final String label;
  final String value;
  const _Small(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Text.rich(TextSpan(children: [
      TextSpan(text: '$label  ', style: TextStyle(color: c.secondary, fontSize: 13.5)),
      TextSpan(text: value, style: TextStyle(color: c.label, fontSize: 13.5, fontWeight: FontWeight.w600)),
    ]));
  }
}
