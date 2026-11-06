import 'package:intl/intl.dart';

import '../models/models.dart';

enum PlanKind { flightArrival, transfer, checkIn, checkOut, activity, train, flightDeparture }

/// Une étape du plan chronologique (et un point sur la carte).
class PlanStep {
  final DateTime time;
  final PlanKind kind;
  final String title;
  final String subtitle;
  final double lat;
  final double lng;
  final double? cost;
  int day = 0; // 0 = premier jour du voyage
  int number = 0; // numéro affiché sur la carte (1, 2, 3…)

  PlanStep({
    required this.time,
    required this.kind,
    required this.title,
    this.subtitle = '',
    required this.lat,
    required this.lng,
    this.cost,
  });
}

final _hm = DateFormat('HH:mm');

/// Construit le plan jour par jour à partir des choix du voyage.
List<PlanStep> buildPlan(Trip t) {
  final steps = <PlanStep>[];
  final dest = t.destination;
  if (dest == null) return steps;
  final stays = t.stays.isEmpty ? [CityStay(place: dest, nights: t.nights)] : t.stays;
  final start = Trip.dateOnly(t.startDate);

  double sLat(CityStay s) => s.hotel?.lat ?? s.place.lat;
  double sLng(CityStay s) => s.hotel?.lng ?? s.place.lng;

  // 1. Arrivée du vol
  var cursor = DateTime(start.year, start.month, start.day, 14);
  if (t.flight != null) {
    final f = t.flight!;
    cursor = f.outArrive;
    steps.add(PlanStep(
      time: f.outArrive,
      kind: PlanKind.flightArrival,
      title: 'Arrivée du vol ${f.flightNumber}',
      subtitle: '${f.airline} · ${f.fromCode} → ${f.toCode}'
          '${f.outStops.isEmpty ? ' · direct' : ' · via ${f.outStops.join(', ')}'}',
      lat: dest.airportLat,
      lng: dest.airportLng,
    ));
  }

  // 2. Trajet aéroport → ville
  if (t.arrivalTransfer != null) {
    final tr = t.arrivalTransfer!;
    cursor = tr.end;
    steps.add(PlanStep(
      time: tr.start.add(const Duration(minutes: 1)),
      kind: PlanKind.transfer,
      title: 'Trajet aéroport → ${stays.first.place.name} (${tr.label})',
      subtitle: tr.steps.map((s) => '${_hm.format(s.time)} ${s.description}').join('\n'),
      lat: (dest.airportLat + stays.first.place.lat) / 2,
      lng: (dest.airportLng + stays.first.place.lng) / 2,
      cost: tr.price,
    ));
  }

  for (var i = 0; i < stays.length; i++) {
    final s = stays[i];
    final stayStart = t.stayStart(i);
    // 3. Check-in
    final checkIn = i == 0 ? cursor.add(const Duration(minutes: 5)) : cursor;
    steps.add(PlanStep(
      time: checkIn,
      kind: PlanKind.checkIn,
      title: 'Check-in ${s.hotel?.name ?? 'logement'}',
      subtitle: '${s.place.name} · ${s.nights} nuit${s.nights > 1 ? 's' : ''}'
          '${s.hotel != null ? ' · ${s.hotel!.address}' : ''}',
      lat: sLat(s),
      lng: sLng(s),
      cost: s.hotel == null ? null : s.hotelCost,
    ));

    // 4. Activités de la ville
    for (final a in t.activities.where((a) => a.city == s.place.name && a.scheduledAt != null)) {
      steps.add(PlanStep(
        time: a.scheduledAt!,
        kind: PlanKind.activity,
        title: a.name,
        subtitle: '${a.interest.label} · ${a.durationMin ~/ 60} h${(a.durationMin % 60).toString().padLeft(2, '0')}'
            '${a.isFree ? ' · gratuit' : ''}',
        lat: a.lat,
        lng: a.lng,
        cost: a.totalPrice,
      ));
    }

    // 5. Départ de la ville : vers la suivante, ou retour vers l'aéroport
    final leaveDay = stayStart.add(Duration(days: s.nights));
    final isLast = i == stays.length - 1;
    final legOut = t.intercity.where((l) => l.from.name == s.place.name).toList();
    final leg = isLast
        ? (legOut.where((l) => l.to.name == dest.name).firstOrNull)
        : (legOut.where((l) => l.to.name == stays[i + 1].place.name).firstOrNull);
    final checkOutTime = DateTime(leaveDay.year, leaveDay.month, leaveDay.day, 10);
    steps.add(PlanStep(
      time: checkOutTime,
      kind: PlanKind.checkOut,
      title: 'Check-out ${s.hotel?.name ?? 'logement'}',
      subtitle: s.place.name,
      lat: sLat(s),
      lng: sLng(s),
    ));
    if (leg != null) {
      steps.add(PlanStep(
        time: leg.depart,
        kind: PlanKind.train,
        title: 'Train ${leg.from.name} → ${leg.to.name}',
        subtitle: 'Départ ${_hm.format(leg.depart)} · arrivée ${_hm.format(leg.arrive)}',
        lat: leg.from.lat,
        lng: leg.from.lng,
        cost: leg.price,
      ));
      cursor = leg.arrive;
    }
  }

  // 6. Trajet vers l'aéroport et vol retour
  final retDepart = t.flight?.retDepart ??
      DateTime(t.endDate.year, t.endDate.month, t.endDate.day, 17);
  if (t.departureTransfer != null) {
    final tr = t.departureTransfer!;
    final from = stays.last.place.name == dest.name ? stays.last : CityStay(place: dest, nights: 0);
    steps.add(PlanStep(
      time: tr.start,
      kind: PlanKind.transfer,
      title: 'Trajet ${dest.name} → aéroport (${tr.label})',
      subtitle: tr.steps.map((s) => '${_hm.format(s.time)} ${s.description}').join('\n'),
      lat: (sLat(from) + dest.airportLat) / 2,
      lng: (sLng(from) + dest.airportLng) / 2,
      cost: tr.price,
    ));
  }
  if (t.flight != null) {
    final f = t.flight!;
    steps.add(PlanStep(
      time: retDepart,
      kind: PlanKind.flightDeparture,
      title: 'Vol retour ${f.airline}',
      subtitle: '${f.toCode} → ${f.fromCode}'
          '${f.retArrive != null ? ' · arrivée ${DateFormat('E d MMM HH:mm', 'fr_FR').format(f.retArrive!)}' : ''}',
      lat: dest.airportLat,
      lng: dest.airportLng,
      cost: f.totalPrice,
    ));
  }

  // Tri chronologique stable, puis numérotation et rattachement à un jour.
  final indexed = steps.asMap().entries.toList()
    ..sort((a, b) {
      final c = a.value.time.compareTo(b.value.time);
      return c != 0 ? c : a.key.compareTo(b.key);
    });
  final sorted = indexed.map((e) => e.value).toList();
  for (var i = 0; i < sorted.length; i++) {
    sorted[i].number = i + 1;
    final d = Trip.dateOnly(sorted[i].time).difference(start).inDays;
    sorted[i].day = d < 0 ? 0 : d;
  }
  return sorted;
}
