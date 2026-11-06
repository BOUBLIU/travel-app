import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/plan_builder.dart';
import '../../state/app_state.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'tracking_screen.dart';

/// Une couleur par jour.
/// Couleurs système Apple, une par jour.
const kDayColors = [
  Color(0xFF007AFF), Color(0xFFFF9500), Color(0xFF34C759), Color(0xFFFF2D55),
  Color(0xFF5856D6), Color(0xFF5AC8FA), Color(0xFFAF52DE), Color(0xFFFFCC00),
  Color(0xFF30B0C7), Color(0xFFFF3B30), Color(0xFF00C7BE), Color(0xFFA2845E),
];

Color dayColor(int day) => kDayColors[day % kDayColors.length];

IconData planIcon(PlanKind k) => switch (k) {
      PlanKind.flightArrival => CupertinoIcons.arrow_down_right_circle_fill,
      PlanKind.flightDeparture => CupertinoIcons.arrow_up_right_circle_fill,
      PlanKind.transfer => CupertinoIcons.arrow_right_arrow_left,
      PlanKind.checkIn => CupertinoIcons.bed_double_fill,
      PlanKind.checkOut => CupertinoIcons.square_arrow_right,
      PlanKind.activity => CupertinoIcons.ticket_fill,
      PlanKind.train => CupertinoIcons.train_style_one,
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

    final c = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(trip.name),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => TrackingScreen(tripId: trip.id))),
            icon: const Icon(CupertinoIcons.creditcard, size: 18),
            label: const Text('Dépenses'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          filter,
          Expanded(
            child: wide
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      SizedBox(
                        width: 460,
                        child: Container(
                          decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(20), boxShadow: softShadow(context)),
                          clipBehavior: Clip.antiAlias,
                          child: list,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: softShadow(context)),
                          clipBehavior: Clip.antiAlias,
                          child: map,
                        ),
                      ),
                    ]),
                  )
                : Column(children: [
                    Expanded(flex: 5, child: map),
                    Expanded(flex: 6, child: Container(color: c.card, child: list)),
                  ]),
          ),
        ],
      ),
    );
  }

  Widget _buildDayFilter(Trip trip, List<int> days, List<PlanStep> all, Map<int, LatLng> pos) {
    return SizedBox(
      height: 58,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        children: [
          Tag(
            label: 'Tout le séjour',
            selected: _day == null,
            onTap: () {
              setState(() => _day = null);
              _fit(all.map((s) => pos[s.number]!));
            },
          ),
          ...days.map((d) {
            final date = Trip.dateOnly(trip.startDate).add(Duration(days: d));
            final sel = _day == d;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Material(
                color: sel ? dayColor(d) : AppColors.of(context).fill,
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () {
                    setState(() => _day = d);
                    _fit(all.where((s) => s.day == d).map((s) => pos[s.number]!));
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: sel ? Colors.white : dayColor(d), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 7),
                      Text('J${d + 1} · ${dayShort(date)}',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: sel ? Colors.white : AppColors.of(context).label)),
                    ]),
                  ),
                ),
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
          child: Icon(Icons.play_arrow_rounded, color: color, size: 24,
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
              border: Border.all(color: Colors.white, width: sel ? 3.5 : 2.5),
              boxShadow: const [BoxShadow(blurRadius: 6, color: Color(0x40000000), offset: Offset(0, 2))],
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
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          retinaMode: MediaQuery.devicePixelRatioOf(context) > 1.5,
          userAgentPackageName: 'com.budgetvoyage.app',
        ),
        PolylineLayer(polylines: segments),
        MarkerLayer(markers: arrows),
        MarkerLayer(markers: markers),
        const RichAttributionWidget(attributions: [
          TextSourceAttribution('© contributeurs OpenStreetMap'),
          TextSourceAttribution('© CARTO'),
        ]),
      ],
    );
  }

  Widget _buildList(Trip trip, List<PlanStep> steps, Map<int, LatLng> pos) {
    final c = AppColors.of(context);
    if (steps.isEmpty) return Center(child: Text('Aucune étape ce jour-là.', style: TextStyle(color: c.secondary)));
    final children = <Widget>[];
    int? lastDay;
    for (final s in steps) {
      if (s.day != lastDay) {
        lastDay = s.day;
        final date = Trip.dateOnly(trip.startDate).add(Duration(days: s.day));
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text('Jour ${s.day + 1}',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: dayColor(s.day))),
            const SizedBox(width: 8),
            Expanded(child: Text(dayLong(date), style: TextStyle(fontSize: 15, color: c.secondary))),
          ]),
        ));
      }
      final key = _itemKeys.putIfAbsent(s.number, () => GlobalKey());
      final sel = s.number == _selected;
      children.add(AnimatedContainer(
        key: key,
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        decoration: BoxDecoration(
          color: sel ? dayColor(s.day).withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _selectFromList(s, pos[s.number]!),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: dayColor(s.day), shape: BoxShape.circle),
                child: Text('${s.number}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 46,
                child: Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(hm(s.time), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(children: [
                      Icon(planIcon(s.kind), size: 15, color: c.secondary),
                      const SizedBox(width: 6),
                      Expanded(child: Text(s.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: -0.2))),
                    ]),
                  ),
                  if (s.subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(s.subtitle,
                          maxLines: sel ? 12 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: c.secondary, height: 1.35)),
                    ),
                ]),
              ),
              if (s.cost != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 8),
                  child: Text(s.cost == 0 ? 'Gratuit' : eur(s.cost!),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: s.cost == 0 ? c.green : c.label)),
                ),
            ]),
          ),
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
