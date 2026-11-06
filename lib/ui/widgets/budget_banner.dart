import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/planner.dart';
import '../format.dart';

/// Bandeau budget affiché en haut de chaque écran du parcours.
class BudgetBanner extends StatelessWidget {
  const BudgetBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlannerController>();
    final scheme = Theme.of(context).colorScheme;
    final over = p.remaining < 0;
    final color = over
        ? scheme.error
        : p.lowBudget
            ? Colors.orange.shade800
            : scheme.primary;
    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _Figure(label: 'Budget initial', value: eur(p.trip.budget)),
                _Figure(label: 'Dépensé', value: eur(p.spent)),
                _Figure(label: 'Restant', value: eur(p.remaining), color: color, bold: true),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: p.progress),
                duration: const Duration(milliseconds: 350),
                builder: (_, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 10,
                  color: color,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            ),
            if (p.lowBudget) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: color, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      over
                          ? 'Budget dépassé de ${eur(-p.remaining)} : revoyez un de vos choix.'
                          : 'Attention : il reste moins de 10 % de votre budget.',
                      style: TextStyle(color: color, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool bold;
  const _Figure({required this.label, required this.value, this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.labelMedium),
          Text(value,
              style: t.titleLarge?.copyWith(
                color: color,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              )),
        ],
      ),
    );
  }
}
