import 'package:budget_voyage/main.dart';
import 'package:budget_voyage/models/models.dart';
import 'package:budget_voyage/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef Shot = Future<void> Function(String name);

/// Parcours complet : train Paris → Lisbonne, hôtel déjà réservé, activité,
/// enregistrement, plan + carte, puis saisie d'une dépense.
/// Écran de Galaxy Tab S11 Ultra en paysage (2960 × 1848, densité 2).
Future<AppState> runFullFlow(WidgetTester tester, {Shot? shot}) async {
  tester.view.physicalSize = const Size(2960, 1848);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  Future<void> snap(String n) async => shot == null ? null : shot(n);

  final app = AppState();
  await tester.runAsync(app.init);
  await tester.pumpWidget(BudgetVoyageApp(state: app));
  await tester.pumpAndSettle();
  await snap('01_accueil');

  expect(find.text('Nouveau voyage'), findsOneWidget);
  expect(find.text('Mes voyages'), findsOneWidget);
  await tester.tap(find.text('Nouveau voyage'));
  await tester.pumpAndSettle();

  Future<void> next() async {
    await tester.tap(find.widgetWithText(FilledButton, 'Continuer'));
    await tester.pump();
    // Laisse les éventuels appels réseau (géocodage) se terminer.
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
  }

  // Étape 1
  await tester.enterText(find.widgetWithText(TextFormField, 'Destination'), 'Lisbonne');
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, 'Lisbonne'));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextFormField, '2 000'), '2500');
  await tester.pumpAndSettle();
  await snap('02_budget');
  await next();

  // Étape 2 : transport en train
  expect(find.text('Restant'), findsOneWidget);
  await tester.tap(find.text('Train'));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('/ pers.').first);
  await tester.pumpAndSettle();
  await snap('03_transport');
  expect(app.trips, isEmpty);
  await next();

  // Étape 3 : depuis la gare
  expect(find.textContaining('Depuis la gare'), findsOneWidget);
  await tester.tap(find.text('Métro / tram').first);
  await tester.pumpAndSettle();
  await next();

  // Étape 4 : un seul hôtel
  await tester.tap(find.text('Un seul hôtel'));
  await tester.pumpAndSettle();
  await next();

  // Étape 5 : hôtel déjà réservé
  await tester.tap(find.text('Déjà réservé'));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextFormField, 'Nom de l\'hôtel'), 'Hôtel Alfama');
  await tester.enterText(find.byWidgetPredicate((w) => w is TextField && (w.decoration?.labelText ?? '').startsWith('Prix total payé')), '540');
  await tester.pumpAndSettle();
  await snap('04_hotel_reserve');
  await next();

  // L'étape « Hôtels » est sautée : on arrive directement aux repas.
  expect(find.text('Quel mangeur êtes-vous ?'), findsOneWidget);
  await tester.tap(find.text('Petit mangeur'));
  await tester.pumpAndSettle();
  await snap('05_repas');
  await next();

  // Activités
  await tester.tap(find.text('Culture'));
  await tester.pumpAndSettle();
  expect(find.text('Gratuit'), findsWidgets);
  await tester.ensureVisible(find.text('Monastère des Hiéronymites'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Monastère des Hiéronymites'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ajouter au programme'));
  await tester.pumpAndSettle();
  expect(find.textContaining('AU PROGRAMME (1)'), findsOneWidget);
  await snap('06_activites');
  await next();

  // Transports sur place
  await tester.ensureVisible(find.text('Transports en commun / pass'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Transports en commun / pass'));
  await tester.pumpAndSettle();
  await next();

  // Récapitulatif
  expect(find.text('Récapitulatif'), findsWidgets);
  await snap('07_recap');
  await tester.tap(find.text('Enregistrer le voyage'));
  await tester.pumpAndSettle();

  expect(app.trips.length, 1);
  final trip = app.trips.first;
  expect(trip.flight!.mode, TravelMode.train);
  expect(trip.stays.single.alreadyBooked, isTrue);
  expect(trip.stays.single.hotel!.name, 'Hôtel Alfama');
  expect(trip.stays.single.hotelCost, closeTo(540, 0.01));
  expect(trip.activities.single.scheduledAt, isNotNull);
  expect(trip.localTransport.length, 1);

  // Plan + carte
  expect(find.textContaining(RegExp(r'^Jour \d')), findsWidgets);
  expect(find.textContaining('Arrivée du train'), findsWidgets);
  await snap('08_plan');

  // Suivi : saisie rapide
  await tester.tap(find.text('Dépenses'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Repas').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('1'));
  await tester.tap(find.text('2'));
  await tester.pumpAndSettle();
  await snap('09_saisie');
  await tester.tap(find.textContaining('Ajouter 12'));
  await tester.pumpAndSettle();
  expect(trip.expenses.single.amountEur, 12);
  await snap('10_suivi');
  return app;
}
