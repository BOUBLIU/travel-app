import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Carte d'option sélectionnable. Grisée avec la mention "Hors budget"
/// si elle coûte plus que le budget restant.
class OptionCard extends StatelessWidget {
  final bool selected;
  final bool outOfBudget;
  final VoidCallback? onTap;
  final Widget child;
  final Widget? trailing;

  const OptionCard({
    super.key,
    required this.child,
    this.selected = false,
    this.outOfBudget = false,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = outOfBudget && !selected;
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Card(
        elevation: selected ? 3 : 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: disabled ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: child),
                if (trailing != null || disabled || selected)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ?trailing,
                      if (disabled)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Chip(
                            label: const Text('Hors budget'),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: scheme.errorContainer,
                            labelStyle: TextStyle(color: scheme.onErrorContainer, fontWeight: FontWeight.w600),
                          ),
                        ),
                      if (selected)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Icon(Icons.check_circle, color: scheme.primary, size: 28),
                        ),
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

/// Grille responsive : 1 colonne sur téléphone, 2 ou 3 sur tablette.
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  const ResponsiveGrid({super.key, required this.children, this.minItemWidth = 420});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = (c.maxWidth / minItemWidth).floor().clamp(1, 3);
      if (cols == 1) return Column(children: children);
      final w = (c.maxWidth - (cols - 1) * 8) / cols;
      return Wrap(
        spacing: 8,
        runSpacing: 0,
        children: children.map((e) => SizedBox(width: w, child: e)).toList(),
      );
    });
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const SectionTitle(this.title, {super.key, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

class SimulatedDataNotice extends StatelessWidget {
  const SimulatedDataNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: scheme.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Prix et horaires indicatifs (données simulées). Vérifiez sur le site de réservation.',
              style: TextStyle(color: scheme.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> openLink(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible d\'ouvrir le lien.')));
  }
}

class StarRow extends StatelessWidget {
  final int stars;
  const StarRow(this.stars, {super.key});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(stars, (_) => const Icon(Icons.star_rounded, size: 16, color: Colors.amber)),
      );
}

/// Pastille de note sur 10.
class RatingBadge extends StatelessWidget {
  final double rating;
  final int reviews;
  const RatingBadge(this.rating, this.reviews, {super.key});

  @override
  Widget build(BuildContext context) {
    final label = rating >= 9
        ? 'Exceptionnel'
        : rating >= 8.5
            ? 'Fabuleux'
            : rating >= 8
                ? 'Très bien'
                : rating >= 7
                    ? 'Bien'
                    : 'Correct';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(color: const Color(0xFF003B95), borderRadius: BorderRadius.circular(6)),
          child: Text(rating.toStringAsFixed(1),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 6),
        Flexible(child: Text('$label · $reviews avis', overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
