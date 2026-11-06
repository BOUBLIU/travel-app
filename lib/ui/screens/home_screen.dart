import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/tracking.dart';
import '../../state/app_state.dart';
import '../format.dart';
import 'plan_screen.dart';
import 'planner/planner_screen.dart';
import 'tracking_screen.dart';

/// Écran d'accueil : "Nouveau voyage" et "Mes voyages".
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final today = Trip.dateOnly(DateTime.now());
    final current = app.trips
        .where((t) => !today.isBefore(Trip.dateOnly(t.startDate)) && !today.isAfter(Trip.dateOnly(t.endDate)))
        .firstOrNull;

    Widget bigButton(IconData icon, String label, String sub, VoidCallback onTap, {bool primary = false}) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 360, maxWidth: 360, minHeight: 180),
        child: Card(
          color: primary ? scheme.primary : scheme.secondaryContainer,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 52, color: primary ? scheme.onPrimary : scheme.onSecondaryContainer),
                  const SizedBox(height: 10),
                  Text(label,
                      style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: primary ? scheme.onPrimary : scheme.onSecondaryContainer,
                      )),
                  Text(sub,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: primary ? scheme.onPrimary : scheme.onSecondaryContainer)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.luggage_outlined, size: 72, color: scheme.primary),
                const SizedBox(height: 8),
                Text('Budget Voyage', style: tt.displaySmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('Planifiez votre séjour sans dépasser votre budget',
                    style: tt.titleMedium?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 32),
                if (current != null) ...[
                  _CurrentTripCard(trip: current),
                  const SizedBox(height: 24),
                ],
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  alignment: WrapAlignment.center,
                  children: [
                    bigButton(Icons.add_location_alt_outlined, 'Nouveau voyage',
                        'Budget, vol, hôtels, repas, activités…',
                        () => Navigator.push(context, PlannerScreen.route(app)),
                        primary: true),
                    bigButton(Icons.map_outlined, 'Mes voyages',
                        app.trips.isEmpty
                            ? 'Aucun voyage enregistré'
                            : '${app.trips.length} voyage${app.trips.length > 1 ? 's' : ''} enregistré${app.trips.length > 1 ? 's' : ''}',
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TripsScreen()))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrentTripCard extends StatelessWidget {
  final Trip trip;
  const _CurrentTripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final tr = TripTracker(trip);
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 740),
      child: Card(
        color: scheme.tertiaryContainer,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: const Icon(Icons.flight, size: 36),
          title: Text('En voyage : ${trip.name}', style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('Restant ${eur(tr.remaining)} · disponible aujourd\'hui ${eur(tr.availableToday)}'),
          trailing: FilledButton.icon(
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => TrackingScreen(tripId: trip.id))),
            icon: const Icon(Icons.add),
            label: const Text('Dépense'),
          ),
        ),
      ),
    );
  }
}

/// "Mes voyages" : liste des voyages enregistrés.
class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final trips = app.trips;
    return Scaffold(
      appBar: AppBar(title: const Text('Mes voyages')),
      body: trips.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Aucun voyage enregistré pour l\'instant.'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => Navigator.pushReplacement(context, PlannerScreen.route(app)),
                  icon: const Icon(Icons.add),
                  label: const Text('Nouveau voyage'),
                ),
              ]),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: trips.length,
              itemBuilder: (context, i) {
                final t = trips[i];
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: const CircleAvatar(child: Icon(Icons.place_outlined)),
                        title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${dateFr(t.startDate)} → ${dateFr(t.endDate)} · '
                            '${t.travelers} voyageur${t.travelers > 1 ? 's' : ''}\n'
                            'Prévu ${eur(t.plannedTotal)} sur ${eur(t.budget)}'
                            '${t.expenses.isNotEmpty ? ' · ${t.expenses.length} dépense(s) saisie(s)' : ''}'),
                        isThreeLine: true,
                        onTap: () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => PlanScreen(tripId: t.id))),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'track') {
                              Navigator.push(
                                  context, MaterialPageRoute(builder: (_) => TrackingScreen(tripId: t.id)));
                            } else if (v == 'delete') {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('Supprimer ce voyage ?'),
                                  content: Text('« ${t.name} » et ses dépenses seront supprimés.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
                                    FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Supprimer')),
                                  ],
                                ),
                              );
                              if (ok == true) await app.deleteTrip(t.id);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'track', child: Text('Suivi des dépenses')),
                            PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
