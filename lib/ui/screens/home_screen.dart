import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/tracking.dart';
import '../../state/app_state.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'plan_screen.dart';
import 'planner/planner_screen.dart';
import 'tracking_screen.dart';

/// Écran d'accueil : « Nouveau voyage » et « Mes voyages ».
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = AppColors.of(context);
    final today = Trip.dateOnly(DateTime.now());
    final current = app.trips
        .where((t) => !today.isBefore(Trip.dateOnly(t.startDate)) && !today.isAfter(Trip.dateOnly(t.endDate)))
        .firstOrNull;
    final upcoming = app.trips.where((t) => Trip.dateOnly(t.startDate).isAfter(today)).firstOrNull;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Budget Voyage', style: Theme.of(context).textTheme.displayLarge),
                  const SizedBox(height: 6),
                  Text('Votre séjour, au juste prix.', style: TextStyle(fontSize: 20, color: c.secondary, letterSpacing: -0.4)),
                  const SizedBox(height: 36),
                  if (current != null) ...[
                    _CurrentTripCard(trip: current),
                    const SizedBox(height: 20),
                  ],
                  LayoutBuilder(builder: (context, box) {
                    final wide = box.maxWidth > 600;
                    final a = _HeroCard(
                      icon: CupertinoIcons.add,
                      color: c.accent,
                      title: 'Nouveau voyage',
                      subtitle: 'Budget, transport, hôtels, repas et activités, étape par étape.',
                      filled: true,
                      onTap: () => Navigator.push(context, PlannerScreen.route(app)),
                    );
                    final b = _HeroCard(
                      icon: CupertinoIcons.map,
                      color: const Color(0xFF5856D6),
                      title: 'Mes voyages',
                      subtitle: app.trips.isEmpty
                          ? 'Vos voyages enregistrés apparaîtront ici.'
                          : '${app.trips.length} voyage${app.trips.length > 1 ? 's' : ''} enregistré${app.trips.length > 1 ? 's' : ''}'
                              '${upcoming != null ? ' · prochain : ${upcoming.destination?.name ?? upcoming.name}' : ''}',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TripsScreen())),
                    );
                    return wide
                        ? IntrinsicHeight(
                            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              Expanded(child: a),
                              const SizedBox(width: 16),
                              Expanded(child: b),
                            ]),
                          )
                        : Column(children: [a, const SizedBox(height: 16), b]);
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool filled;
  final VoidCallback onTap;
  const _HeroCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fg = filled ? Colors.white : c.label;
    return Container(
      constraints: const BoxConstraints(minHeight: 200),
      decoration: BoxDecoration(
        color: filled ? null : c.card,
        gradient: filled
            ? LinearGradient(
                colors: [color, Color.lerp(color, const Color(0xFF5856D6), 0.45)!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(26),
        boxShadow: softShadow(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: filled ? Colors.white.withValues(alpha: 0.22) : color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                const SizedBox(height: 28),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(title,
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.8, color: fg)),
                    ),
                    Icon(CupertinoIcons.arrow_right, color: filled ? Colors.white : c.tertiary),
                  ]),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(fontSize: 15, color: filled ? Colors.white.withValues(alpha: 0.85) : c.secondary, height: 1.35)),
                ]),
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
    final c = AppColors.of(context);
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrackingScreen(tripId: trip.id))),
      child: Row(children: [
        IconTile(CupertinoIcons.location_fill, c.green, size: 40),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('En voyage · ${trip.name}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            Text('Disponible aujourd\'hui ${eur(tr.availableToday)} · restant ${eur(tr.remaining)}',
                style: TextStyle(color: c.secondary, fontSize: 13.5)),
          ]),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 18)),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrackingScreen(tripId: trip.id))),
          child: const Text('Dépense'),
        ),
      ]),
    );
  }
}

/// « Mes voyages » : liste des voyages enregistrés.
class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key});

  Future<void> _delete(BuildContext context, AppState app, Trip t) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: const Text('Supprimer ce voyage ?'),
        content: Text('« ${t.name} » et ses dépenses seront supprimés.'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          CupertinoDialogAction(isDestructiveAction: true, onPressed: () => Navigator.pop(c, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok == true) await app.deleteTrip(t.id);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = AppColors.of(context);
    final trips = app.trips;
    return Scaffold(
      appBar: AppBar(title: const Text('Mes voyages')),
      body: trips.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(CupertinoIcons.map, size: 56, color: c.tertiary),
                const SizedBox(height: 12),
                Text('Aucun voyage pour l\'instant', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pushReplacement(context, PlannerScreen.route(app)),
                  child: const Text('Planifier un voyage'),
                ),
              ]),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text('Mes voyages', style: Theme.of(context).textTheme.displaySmall),
                      const SizedBox(height: 16),
                      GroupedList(
                        children: trips.map((t) {
                          final today = Trip.dateOnly(DateTime.now());
                          final status = today.isAfter(Trip.dateOnly(t.endDate))
                              ? 'Terminé'
                              : today.isBefore(Trip.dateOnly(t.startDate))
                                  ? 'Dans ${Trip.dateOnly(t.startDate).difference(today).inDays} j'
                                  : 'En cours';
                          return GroupedRow(
                            leading: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: c.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(CupertinoIcons.airplane, color: c.accent),
                            ),
                            title: t.name,
                            subtitle: '${dateFr(t.startDate)} → ${dateFr(t.endDate)} · $status\n'
                                '${eur(t.plannedTotal)} prévus${t.hasBudget ? ' sur ${eur(t.budget)}' : ''}'
                                '${t.expenses.isNotEmpty ? ' · ${t.expenses.length} dépense(s)' : ''}',
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlanScreen(tripId: t.id))),
                            trailing: PopupMenuButton<String>(
                              icon: Icon(CupertinoIcons.ellipsis_circle, color: c.accent),
                              onSelected: (v) {
                                if (v == 'track') {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => TrackingScreen(tripId: t.id)));
                                } else if (v == 'delete') {
                                  _delete(context, app, t);
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'track', child: Text('Suivi des dépenses')),
                                PopupMenuItem(value: 'delete', child: Text('Supprimer', style: TextStyle(color: c.red))),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }
}
