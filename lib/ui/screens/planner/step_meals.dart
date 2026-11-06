import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/models.dart';
import '../../../state/planner.dart';
import '../../format.dart';
import '../../widgets/common.dart';

/// Étape 7 : profil de repas.
class MealsStep extends StatelessWidget {
  const MealsStep({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlannerController>();
    final t = p.trip;
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final current = t.mealProfile == null ? 0.0 : t.mealCost(t.mealProfile!);
    // Budget disponible pour les repas si l'on remplace le choix actuel.
    final available = p.remaining + current;

    // Profil trop cher (choisi, ou tout simplement hors budget) → proposition du profil inférieur.
    MealProfile? tooExpensive;
    if (t.mealProfile != null && current > available - 0.001 && p.remaining < 0) {
      tooExpensive = t.mealProfile;
    }
    MealProfile? suggestion;
    if (tooExpensive != null) {
      var s = tooExpensive.lower;
      while (s != null && t.mealCost(s) > available) {
        s = s.lower;
      }
      suggestion = s;
    }
    final expensiveOnes = MealProfile.values.where((m) => t.mealCost(m) > available).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle('Quel mangeur êtes-vous ?',
            subtitle: 'Budget repas = montant par jour selon le profil et le coût de la vie '
                'en ${t.destination!.country} × ${t.days} jours × ${t.travelers} voyageur${t.travelers > 1 ? 's' : ''}.'),
        if (tooExpensive != null)
          _Alert(
            text: 'Le profil « ${tooExpensive.label} » dépasse votre budget restant de ${eur(-p.remaining)}.'
                '${suggestion != null ? ' Nous vous proposons le profil « ${suggestion.label} ».' : ' Même le profil le plus économique ne rentre pas : revoyez l\'hôtel ou le vol.'}',
            action: suggestion == null ? null : ('Passer à « ${suggestion.label} »', () => p.setMealProfile(suggestion)),
          )
        else if (expensiveOnes.isNotEmpty)
          _Alert(
            text: '${expensiveOnes.map((m) => '« ${m.label} »').join(' et ')} dépasse${expensiveOnes.length > 1 ? 'nt' : ''} '
                'votre budget restant (${eur(available)}).'
                '${expensiveOnes.length < MealProfile.values.length ? ' Choisissez un profil inférieur.' : ' Revoyez l\'hôtel ou le vol pour libérer du budget.'}',
          ),
        ResponsiveGrid(
          minItemWidth: 320,
          children: MealProfile.values.map((m) {
            final total = t.mealCost(m);
            final daily = t.mealDailyCost(m);
            return OptionCard(
              selected: t.mealProfile == m,
              outOfBudget: total > available + 0.001,
              onTap: () => p.setMealProfile(m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    switch (m) {
                      MealProfile.light => Icons.bakery_dining_outlined,
                      MealProfile.big => Icons.restaurant,
                      MealProfile.gourmet => Icons.wine_bar_outlined,
                    },
                    size: 36,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(m.label, style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(m.description),
                  const SizedBox(height: 12),
                  Text('${eur(daily / t.travelers)} / jour / pers.', style: tt.bodyMedium),
                  Text('Total ${eur(total)}', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _Alert extends StatelessWidget {
  final String text;
  final (String, VoidCallback)? action;
  const _Alert({required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: scheme.onErrorContainer))),
          if (action != null) ...[
            const SizedBox(width: 10),
            FilledButton(onPressed: action!.$2, child: Text(action!.$1)),
          ],
        ]),
      ),
    );
  }
}
