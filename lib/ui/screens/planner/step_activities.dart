import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/models.dart';
import '../../../state/planner.dart';
import '../../format.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

IconData interestIcon(Interest i) => switch (i) {
      Interest.culture => CupertinoIcons.building_2_fill,
      Interest.nature => CupertinoIcons.tree,
      Interest.nightlife => CupertinoIcons.moon_stars_fill,
      Interest.food => Icons.restaurant_rounded,
      Interest.shopping => CupertinoIcons.bag_fill,
      Interest.sport => Icons.directions_bike_rounded,
    };

/// Étape 8 : envies, puis activités par ville placées à un jour et une heure.
class ActivitiesStep extends StatefulWidget {
  const ActivitiesStep({super.key});

  @override
  State<ActivitiesStep> createState() => _ActivitiesStepState();
}

class _ActivitiesStepState extends State<ActivitiesStep> {
  final Map<String, Future<List<Activity>>> _cache = {};

  Future<List<Activity>> _load(PlannerController p, Place city) {
    final key = '${city.name}|${p.trip.interests.map((i) => i.name).join(',')}';
    return _cache.putIfAbsent(
        key, () => p.data.activities(city: city, interests: p.trip.interests, travelers: p.trip.travelers));
  }

  Future<void> _schedule(PlannerController p, int stayIndex, Activity a) async {
    final t = p.trip;
    final from = t.stayStart(stayIndex);
    final nights = t.stays[stayIndex].nights;
    final days = List.generate(nights + 1, (i) => from.add(Duration(days: i)));
    final existing = t.activities.where((x) => x.id == a.id).firstOrNull?.scheduledAt;
    var day = existing != null ? Trip.dateOnly(existing) : (nights >= 1 ? days[1] : days[0]);
    if (!days.contains(day)) day = days.first;
    var time = existing != null ? TimeOfDay.fromDateTime(existing) : const TimeOfDay(hour: 10, minute: 0);

    final ok = await showModalBottomSheet<bool>(
      context: context,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (c) => StatefulBuilder(
        builder: (c, setD) {
          final col = AppColors.of(c);
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(a.name, style: Theme.of(c).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(a.isFree ? 'Gratuit' : '${eur(a.totalPrice)} · ${eur(a.pricePerPerson)} par personne',
                    style: TextStyle(color: col.secondary)),
                const GroupHeader('Jour'),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: days
                        .map((d) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Tag(label: dayShort(d), selected: d == day, onTap: () => setD(() => day = d)),
                            ))
                        .toList(),
                  ),
                ),
                const GroupHeader('Heure'),
                SizedBox(
                  height: 150,
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: true,
                    minuteInterval: 5,
                    initialDateTime: DateTime(2000, 1, 1, time.hour, time.minute - time.minute % 5),
                    onDateTimeChanged: (d) => time = TimeOfDay.fromDateTime(d),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: Text(existing == null ? 'Ajouter au programme' : 'Modifier'),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (ok == true) {
      p.addActivity(a, DateTime(day.year, day.month, day.day, time.hour, time.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlannerController>();
    final t = p.trip;
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Vos envies', subtitle: 'Les activités gratuites apparaissent en premier.'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: Interest.values
              .map((i) => Tag(
                    icon: interestIcon(i),
                    label: i.label,
                    selected: t.interests.contains(i),
                    onTap: () => p.toggleInterest(i),
                  ))
              .toList(),
        ),
        if (t.activities.isNotEmpty) ...[
          GroupHeader('Au programme (${t.activities.length})',
              trailing: Text(eur(t.plannedFor(BudgetCategory.activities)),
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: c.secondary))),
          GroupedList(
            children: t.activities
                .map((a) => GroupedRow(
                      leading: IconTile(interestIcon(a.interest), c.accent, size: 30),
                      title: a.name,
                      subtitle: '${a.city} · ${a.scheduledAt != null ? '${dayLong(a.scheduledAt!)} à ${hm(a.scheduledAt!)}' : 'à placer'}',
                      trailing: Text(a.isFree ? 'Gratuit' : eur(a.totalPrice),
                          style: TextStyle(color: a.isFree ? c.green : c.label, fontWeight: FontWeight.w600)),
                    ))
                .toList(),
          ),
        ],
        for (var i = 0; i < t.stays.length; i++) ...[
          GroupHeader('Idées à ${t.stays[i].place.name}'),
          FutureBuilder<List<Activity>>(
            future: _load(p, t.stays[i].place),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(padding: EdgeInsets.all(24), child: Center(child: CupertinoActivityIndicator()));
              }
              return ResponsiveGrid(
                minItemWidth: 380,
                children: snap.data!.map((a) {
                  final added = p.hasActivity(a.id);
                  final scheduled = t.activities.where((x) => x.id == a.id).firstOrNull?.scheduledAt;
                  return OptionCard(
                    selected: added,
                    outOfBudget: !added && !p.fits(a.totalPrice),
                    onTap: () => _schedule(p, i, a),
                    trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      if (a.isFree)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: c.green.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
                          child: Text('Gratuit', style: TextStyle(color: c.green, fontWeight: FontWeight.w700, fontSize: 13)),
                        )
                      else
                        PriceLabel(eur(a.totalPrice), caption: '${eur(a.pricePerPerson)} / pers.'),
                      if (added)
                        TextButton(
                          onPressed: () => p.removeActivity(a.id),
                          style: TextButton.styleFrom(foregroundColor: c.red),
                          child: const Text('Retirer'),
                        ),
                    ]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.name, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600, letterSpacing: -0.3)),
                        const SizedBox(height: 3),
                        Text('${a.interest.label} · ${duration(Duration(minutes: a.durationMin))}',
                            style: TextStyle(fontSize: 13, color: c.accent, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        Text(a.description, style: TextStyle(fontSize: 14, color: c.secondary, height: 1.35)),
                        if (scheduled != null) ...[
                          const SizedBox(height: 8),
                          Row(children: [
                            Icon(CupertinoIcons.calendar, size: 14, color: c.label),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text('${dayLong(scheduled)} à ${hm(scheduled)}',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                            ),
                          ]),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ],
    );
  }
}
