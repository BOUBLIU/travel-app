import 'package:budget_voyage/main.dart';
import 'package:budget_voyage/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Parcours complet "Nouveau voyage" sur un écran de tablette (Tab S11 Ultra, paysage).
void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'fr_FR';
    await initializeDateFormatting('fr_FR');
  });

  testWidgets('parcours complet jusqu\'à l\'enregistrement', (tester) async {
    tester.view.physicalSize = const Size(2960, 1848);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    final app = AppState();
    await tester.runAsync(app.init);
    await tester.pumpWidget(BudgetVoyageApp(state: app));
    await tester.pumpAndSettle();

    expect(find.text('Nouveau voyage'), findsOneWidget);
    expect(find.text('Mes voyages'), findsOneWidget);
    await tester.tap(find.text('Nouveau voyage'));
    await tester.pumpAndSettle();

    Future<void> next() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Suivant'));
      await tester.pumpAndSettle();
    }

    // Étape 1
    await tester.enterText(find.widgetWithText(TextFormField, 'Destination'), 'Lisbonne');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Lisbonne')); // suggestion
    await tester.pumpAndSettle();
    await next();

    // Étape 2 : vol — bandeau budget visible
    expect(find.text('Budget initial'), findsOneWidget);
    expect(find.textContaining('Étape 2/'), findsOneWidget);
    // Sélection de la première carte de vol.
    await tester.tap(find.textContaining('/ pers.').first);
    await tester.pumpAndSettle();
    await next();

    // Étape 3 : trajets
    expect(find.textContaining('Depuis l\'aéroport'), findsOneWidget);
    await tester.tap(find.text('Train + métro').first);
    await tester.pumpAndSettle();
    await next();

    // Étape 4 : un seul hôtel
    await tester.tap(find.text('Un seul hôtel'));
    await tester.pumpAndSettle();
    await next();

    // Étape 5 : préférences
    await tester.tap(find.text('Le moins cher'));
    await tester.pumpAndSettle();
    await next();

    // Étape 6 : hôtels
    expect(find.textContaining('Hôtels à Lisbonne'), findsOneWidget);
    await tester.tap(find.text('/ nuit').first);
    await tester.pumpAndSettle();
    await next();

    // Étape 7 : repas
    await tester.tap(find.text('Petit mangeur'));
    await tester.pumpAndSettle();
    await next();

    // Étape 8 : activités
    await tester.tap(find.widgetWithText(FilterChip, 'Culture'));
    await tester.pumpAndSettle();
    expect(find.text('GRATUIT'), findsWidgets);
    await tester.tap(find.text('Monastère des Hiéronymites'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Ajouter'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Au programme (1)'), findsOneWidget);
    await next();

    // Étape 9 : transports
    await tester.tap(find.text('Transports en commun / pass'));
    await tester.pumpAndSettle();
    await next();

    // Étape 10 : récapitulatif
    expect(find.text('Récapitulatif'), findsWidgets);
    expect(find.text('Logement'), findsOneWidget);
    expect(find.text('Activités'), findsOneWidget);
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(app.trips.length, 1);
    final trip = app.trips.first;
    expect(trip.flight, isNotNull);
    expect(trip.stays.single.hotel, isNotNull);
    expect(trip.activities.single.scheduledAt, isNotNull);
    expect(trip.localTransport.length, 1);
    // Écran plan + carte
    expect(find.text('Suivi des dépenses'), findsOneWidget);
    expect(find.textContaining('Jour 1'), findsWidgets);

    // Suivi : saisie rapide
    await tester.tap(find.text('Suivi des dépenses'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Repas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1'));
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Ajouter 12'));
    await tester.pumpAndSettle();
    expect(trip.expenses.single.amountEur, 12);
  });
}
