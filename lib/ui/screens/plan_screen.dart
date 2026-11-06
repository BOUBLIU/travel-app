import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/plan_builder.dart';
import '../../state/app_state.dart';
import '../format.dart';
import 'tracking_screen.dart';

/// Une couleur par jour.
const kDayColors = [
  Color(0xFF1E88E5), Color(0xFFE53935), Color(0xFF43A047), Color(0xFFFB8C00),
  Color(0xFF8E24AA), Color(0xFF00ACC1), Color(0xFF6D4C41), Color(0xFFD81B60),
  Color(0xFF3949AB), Color(0xFF7CB342), Color(0xFFF4511E), Color(0xFF546E7A),
];

Color dayColor(int day) => kDayColors[day % kDayColors.length];

IconData planIcon(PlanKind k) => switch (k) {
      PlanKind.flightArrival => Icons.flight_land,
      PlanKind.flightDeparture => Icons.flight_takeoff,
      PlanKind.transfer => Icons.airport_shuttle,
      PlanKind.checkIn => Icons.login,
      PlanKind.checkOut => Icons.logout,
      PlanKind.activity => Icons.local_activity,
      PlanKind.train => Icons.train,
    };

/// Écran final : plan chronologique jour par jour + carte synchronisée.
class PlanScreen extends StatefulWidget {
  final String tripId;
  const PlanScreen({super.key, required this.tripId});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final _map = MapController();
  final _itemKeys = <int, GlobalKey>{};
  int? _day; // null = tous les jours
  int? _selected; // numéro de l'étape sélectionnée
  bool _mapReady = false;

  List<PlanStep> _visible(List<PlanStep> all) => _day == null ? all : all.where((s) => s.day == _day).toList();

  /// Décale légèrement les étapes au même endroit pour qu'elles restent visibles.
  Map<int, LatLng> _positions(List<PlanStep> steps) {
    final seen = <String, int>{};
    final out = <int, LatLng>{};
    for (final s in steps) {
      final k = '${s.lat.toStringAsFixed(4)},${s.lng.toStringAsFixed(4)}';
      final n = seen[k] ?? 0;
      seen[k] = n + 1;
      final angle = n * 2.1;
      final r = n == 0 ? 0.0 : 0.0009 * sqrt(n.toDouble());
      out[s.number] = LatLng(s.lat + r * sin(angle), s.lng + r * cos(angle));
    }
    return out;
  }

  void _fit(Iterable<LatLng> pts) {
    if (!_mapReady || pts.isEmpty) return;
    _map.fitCamera(CameraFit.coordinates(
      coordinates: pts.toList(),
      padding: const EdgeInsets.all(56),
      maxZoom: 15,
    ));
  }

  void _selectFromList(PlanStep s, LatLng pos) {
    setState(() => _selected = s.number);
    if (_mapReady) _map.move(pos, max(_map.camera.zoom, 14));
  }

  void _selectFromMap(PlanStep s) {
    setState(() => _selected = s.number);
    final ctx = _itemKeys[s.number]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 350), alignment: 0.3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final trip = app.tripById(widget.tripId);
    if (trip == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Voyage introuvable.')));
    }
    final all = buildPlan(trip);
    final steps = _visible(all);
    final pos = _positions(all);
    final days = all.map((s) => s.day).toSet().toList()..sort();
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final map = _buildMap(trip, steps, pos);
    final list = _buildList(trip, steps, pos);
    final filter = _buildDayFilter(trip, days, all, pos);

    return Scaffold(
      appBar: AppBar(
        title: Text(trip.name),
        actions: [
          FilledButton.tonalIcon(
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => TrackingScreen(tripId: trip.id))),
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: const Text('Suivi des dépenses'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          filter,
          Expanded(
            child: wide
                ? Row(children: [
                    SizedBox(width: 440, child: list),
                    const VerticalDivider(width: 1),
                    Expanded(child: map),
                  ])
                : Column(children: [
                    Expanded(flex: 5, child: map),
                    const Divider(height: 1),
                    Expanded(flex: 6, child: list),
                  ]),
          ),
        ],
      ),
    );
  }

  Widget _buildDayFilter(Trip trip, List<int> days, List<PlanStep> all, Map<int, LatLng> pos) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          ChoiceChip(
            label: const Text('Tous les jours'),
            selected: _day == null,
            onSelected: (_) {
              setState(() => _day = null);
              _fit(all.map((s) => pos[s.number]!));
            },
          ),
          ...days.map((d) {
            final date = Trip.dateOnly(trip.startDate).add(Duration(days: d));
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ChoiceChip(
                avatar: CircleAvatar(backgroundColor: dayColor(d), radius: 7),
                label: Text('J${d + 1} · ${dayShort(date)}'),
                selected: _day == d,
                onSelected: (_) {
                  setState(() => _day = d);
                  _fit(all.where((s) => s.day == d).map((s) => pos[s.number]!));
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMap(Trip trip, List<PlanStep> steps, Map<int, LatLng> pos) {
    final pts = steps.map((s) => pos[s.number]!).toList();
    final segments = <Polyline>[];
    final arrows = <Marker>[];
    for (var i = 0; i + 1 < steps.length; i++) {
      final a = pos[steps[i].number]!;
      final b = pos[steps[i + 1].number]!;
      if (a == b) continue;
      final color = dayColor(steps[i + 1].day);
      segments.add(Polyline(points: [a, b], color: color.withValues(alpha: 0.85), strokeWidth: 4));
      // Flèche au milieu du segment, orientée dans le sens du trajet (projection Mercator).
      double y(double lat) => log(tan(pi / 4 + lat * pi / 360)) * 180 / pi;
      final dx = b.longitude - a.longitude;
      final dy = -(y(b.latitude) - y(a.latitude));
      arrows.add(Marker(
        point: LatLng((a.latitude + b.latitude) / 2, (a.longitude + b.longitude) / 2),
        width: 26,
        height: 26,
        child: Transform.rotate(
          angle: atan2(dy, dx),
          child: Icon(Icons.play_arrow_rounded, color: color, size: 26,
              shadows: const [Shadow(color: Colors.white, blurRadius: 3)]),
        ),
      ));
    }

    final markers = steps.map((s) {
      final sel = s.number == _selected;
      final size = sel ? 44.0 : 32.0;
      return Marker(
        point: pos[s.number]!,
        width: size,
        height: size,
        child: GestureDetector(
          onTap: () => _selectFromMap(s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: dayColor(s.day),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: sel ? 4 : 2.5),
              boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black38)],
            ),
            alignment: Alignment.center,
            child: Text('${s.number}',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: sel ? 17 : 13)),
          ),
        ),
      );
    }).toList()
      // L'étape sélectionnée est dessinée au-dessus des autres.
      ..sort((a, b) => (a.width).compareTo(b.width));

    final center = pts.isEmpty ? LatLng(trip.destination?.lat ?? 48.85, trip.destination?.lng ?? 2.35) : pts.first;
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 11,
        initialCameraFit: pts.length > 1
            ? CameraFit.coordinates(coordinates: pts, padding: const EdgeInsets.all(56), maxZoom: 15)
            : null,
        onMapReady: () => _mapReady = true,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.budgetvoyage.app',
        ),
        PolylineLayer(polylines: segments),
        MarkerLayer(markers: arrows),
        MarkerLayer(markers: markers),
        const RichAttributionWidget(attributions: [TextSourceAttribution('© contributeurs OpenStreetMap')]),
      ],
    );
  }

  Widget _buildList(Trip trip, List<PlanStep> steps, Map<int, LatLng> pos) {
    if (steps.isEmpty) return const Center(child: Text('Aucune étape pour ce jour.'));
    final tt = Theme.of(context).textTheme;
    final children = <Widget>[];
    int? lastDay;
    for (final s in steps) {
      if (s.day != lastDay) {
        lastDay = s.day;
        final date = Trip.dateOnly(trip.startDate).add(Duration(days: s.day));
        children.add(Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Row(children: [
            Container(width: 6, height: 22, color: dayColor(s.day)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Jour ${s.day + 1} · ${dayLong(date)}',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ),
          ]),
        ));
      }
      final key = _itemKeys.putIfAbsent(s.number, () => GlobalKey());
      final sel = s.number == _selected;
      children.add(Material(
        key: key,
        color: sel ? dayColor(s.day).withValues(alpha: 0.12) : Colors.transparent,
        child: ListTile(
          onTap: () => _selectFromList(s, pos[s.number]!),
          leading: CircleAvatar(
            backgroundColor: dayColor(s.day),
            foregroundColor: Colors.white,
            child: Text('${s.number}', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          title: Row(children: [
            Icon(planIcon(s.kind), size: 18),
            const SizedBox(width: 6),
            Expanded(child: Text(s.title, style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
          subtitle: Text(
            '${hm(s.time)}${s.subtitle.isNotEmpty ? ' · ${s.subtitle}' : ''}',
            maxLines: sel ? 12 : 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: s.cost == null ? null : Text(s.cost == 0 ? 'Gratuit' : eur(s.cost!)),
        ),
      ));
    }
    // Toutes les étapes sont construites, pour pouvoir faire défiler jusqu'à l'une d'elles.
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}
