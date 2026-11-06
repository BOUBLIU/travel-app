import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/models.dart';
import '../../../state/planner.dart';
import '../../format.dart';
import '../../widgets/common.dart';

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

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: Text(a.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quand ?', style: Theme.of(c).textTheme.titleSmall),
              const SizedBox(height: 8),
              DropdownButtonFormField<DateTime>(
                initialValue: day,
                decoration: const InputDecoration(labelText: 'Jour', border: OutlineInputBorder()),
                items: days.map((d) => DropdownMenuItem(value: d, child: Text(dayLong(d)))).toList(),
                onChanged: (v) => setD(() => day = v ?? day),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.schedule),
                label: Text('Heure : ${time.format(c)}'),
                onPressed: () async {
                  final r = await showTimePicker(context: c, initialTime: time, helpText: 'Heure de début');
                  if (r != null) setD(() => time = r);
                },
              ),
              const SizedBox(height: 12),
              Text(a.isFree ? 'Gratuit' : 'Coût : ${eur(a.totalPrice)} (${eur(a.pricePerPerson)} / pers.)'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(existing == null ? 'Ajouter' : 'Modifier')),
          ],
        ),
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
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Vos envies',
            subtitle: 'Choisissez ce qui vous plaît : les activités gratuites sont affichées en premier.'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: Interest.values
              .map((i) => FilterChip(
                    label: Text(i.label),
                    selected: t.interests.contains(i),
                    onSelected: (_) => p.toggleInterest(i),
                  ))
              .toList(),
        ),
        if (t.activities.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Au programme (${t.activities.length}) · ${eur(t.plannedFor(BudgetCategory.activities))}',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ...t.activities.map((a) => ListTile(
                dense: true,
                leading: const Icon(Icons.event_available),
                title: Text(a.name),
                subtitle: Text('${a.city} · ${a.scheduledAt != null ? '${dayLong(a.scheduledAt!)} à ${hm(a.scheduledAt!)}' : 'à placer'}'),
                trailing: Text(a.isFree ? 'Gratuit' : eur(a.totalPrice)),
              )),
        ],
        for (var i = 0; i < t.stays.length; i++) ...[
          const SizedBox(height: 16),
          Text('À ${t.stays[i].place.name}', style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          FutureBuilder<List<Activity>>(
            future: _load(p, t.stays[i].place),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
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
                    trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (a.isFree)
                          Chip(
                            label: const Text('GRATUIT'),
                            backgroundColor: Colors.green.shade100,
                            labelStyle: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.w800),
                            visualDensity: VisualDensity.compact,
                          )
                        else ...[
                          Text(eur(a.totalPrice), style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          Text('${eur(a.pricePerPerson)} / pers.', style: tt.bodySmall),
                        ],
                        if (added)
                          TextButton(onPressed: () => p.removeActivity(a.id), child: const Text('Retirer')),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.name, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('${a.interest.label} · ${duration(Duration(minutes: a.durationMin))}',
                            style: tt.bodySmall?.copyWith(color: scheme.primary)),
                        const SizedBox(height: 4),
                        Text(a.description),
                        if (scheduled != null) ...[
                          const SizedBox(height: 6),
                          Text('📅 ${dayLong(scheduled)} à ${hm(scheduled)}',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
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
