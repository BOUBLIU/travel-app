import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/models.dart';
import '../../../state/planner.dart';
import '../../format.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Étape 7 : profil de repas.
class MealsStep extends StatelessWidget {
  const MealsStep({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlannerController>();
    final t = p.trip;
    final c = AppColors.of(context);
    final current = t.mealProfile == null ? 0.0 : t.mealCost(t.mealProfile!);
    // Budget disponible pour les repas si l'on remplace le choix actuel.
    final available = p.remaining + current;

    // Profil choisi qui fait dépasser le budget → proposition du profil inférieur.
    MealProfile? tooExpensive;
    MealProfile? suggestion;
    if (p.hasBudget && t.mealProfile != null && p.remaining < 0) {
      tooExpensive = t.mealProfile;
      var s = tooExpensive!.lower;
      while (s != null && t.mealCost(s) > available) {
        s = s.lower;
      }
      suggestion = s;
    }
    final expensiveOnes = p.hasBudget ? MealProfile.values.where((m) => t.mealCost(m) > available).toList() : <MealProfile>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle('Quel mangeur êtes-vous ?',
            subtitle: 'Montant par jour adapté au coût de la vie (${t.destination!.country}), '
                '× ${t.days} jours × ${t.travelers} voyageur${t.travelers > 1 ? 's' : ''}.'),
        if (tooExpensive != null)
          InlineAlert(
            'Le profil « ${tooExpensive.label} » dépasse votre budget de ${eur(-p.remaining)}.'
            '${suggestion != null ? ' Nous vous proposons « ${suggestion.label} ».' : ' Même le profil le plus léger ne rentre pas : revoyez l\'hôtel ou le transport.'}',
            severe: true,
            action: suggestion == null ? null : ('Choisir', () => p.setMealProfile(suggestion)),
          )
        else if (expensiveOnes.isNotEmpty)
          InlineAlert(
            '${expensiveOnes.map((m) => '« ${m.label} »').join(' et ')} dépasse${expensiveOnes.length > 1 ? 'nt' : ''} '
            'votre budget restant (${eur(available)}).'
            '${expensiveOnes.length < MealProfile.values.length ? ' Choisissez un profil inférieur.' : ''}',
          ),
        ResponsiveGrid(
          minItemWidth: 320,
          children: MealProfile.values.map((m) {
            final total = t.mealCost(m);
            final daily = t.mealDailyCost(m);
            final (icon, color) = switch (m) {
              MealProfile.light => (CupertinoIcons.leaf_arrow_circlepath, c.green),
              MealProfile.big => (Icons.restaurant_rounded, c.orange),
              MealProfile.gourmet => (Icons.wine_bar_rounded, const Color(0xFFAF52DE)),
            };
            return OptionCard(
              selected: t.mealProfile == m,
              outOfBudget: p.hasBudget && total > available + 0.001,
              onTap: () => p.setMealProfile(m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconTile(icon, color, size: 44),
                  const SizedBox(height: 14),
                  Text(m.label, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600, letterSpacing: -0.4)),
                  const SizedBox(height: 4),
                  Text(m.description, style: TextStyle(color: c.secondary, fontSize: 14, height: 1.35)),
                  const SizedBox(height: 16),
                  Text(eur(total), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.8)),
                  Text('${eur(daily / t.travelers)} par jour et par personne',
                      style: TextStyle(color: c.secondary, fontSize: 13)),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
