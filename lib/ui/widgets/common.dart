import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';

/// Ombre très douce, façon iOS.
List<BoxShadow> softShadow(BuildContext context) => Theme.of(context).brightness == Brightness.dark
    ? const []
    : const [
        BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 2)),
        BoxShadow(color: Color(0x08000000), blurRadius: 2, offset: Offset(0, 1)),
      ];

/// Carte blanche arrondie, sans bordure.
class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;
  const SurfaceCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: color ?? c.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: color == null ? softShadow(context) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

/// Carte d'option sélectionnable. Atténuée avec la mention « Hors budget »
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
    final c = AppColors.of(context);
    final disabled = outOfBudget && !selected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: disabled ? 0.42 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? c.accent : Colors.transparent, width: 2),
            boxShadow: softShadow(context),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: disabled ? null : onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: child),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ?trailing,
                        if (disabled) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: c.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('Hors budget',
                                style: TextStyle(color: c.red, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(width: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        selected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                        key: ValueKey(selected),
                        color: selected ? c.accent : c.tertiary,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
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
    return LayoutBuilder(builder: (context, box) {
      final cols = (box.maxWidth / minItemWidth).floor().clamp(1, 3);
      if (cols == 1) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
      const gap = 12.0;
      final w = (box.maxWidth - (cols - 1) * gap) / cols;
      return Wrap(
        spacing: gap,
        children: children.map((e) => SizedBox(width: w, child: e)).toList(),
      );
    });
  }
}

/// Grand titre d'écran (style « Large Title » d'iOS).
class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? eyebrow;
  const SectionTitle(this.title, {super.key, this.subtitle, this.eyebrow});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(eyebrow!.toUpperCase(),
                  style: t.labelSmall?.copyWith(color: c.accent, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
            ),
          Text(title, style: t.displaySmall),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: t.bodyLarge?.copyWith(color: c.secondary)),
          ],
        ],
      ),
    );
  }
}

/// Petit en-tête de groupe, en capitales grises (comme les Réglages iOS).
class GroupHeader extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const GroupHeader(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(children: [
        Expanded(
          child: Text(text.toUpperCase(),
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: c.secondary)),
        ),
        ?trailing,
      ]),
    );
  }
}

/// Liste groupée « inset » avec séparateurs fins.
class GroupedList extends StatelessWidget {
  final List<Widget> children;
  const GroupedList({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i < children.length - 1) {
        items.add(Padding(padding: const EdgeInsets.only(left: 16), child: Divider(color: c.separator)));
      }
    }
    return Container(
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16), boxShadow: softShadow(context)),
      clipBehavior: Clip.antiAlias,
      child: Material(type: MaterialType.transparency, child: Column(children: items)),
    );
  }
}

/// Ligne de liste groupée.
class GroupedRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final int subtitleLines;
  const GroupedRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.subtitleLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          if (leading != null) ...[leading!, const SizedBox(width: 14)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: -0.2)),
              if (subtitle != null && subtitle!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle!,
                      maxLines: subtitleLines,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5, color: c.secondary, height: 1.3)),
                ),
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          if (onTap != null && trailing == null) Icon(CupertinoIcons.chevron_forward, size: 18, color: c.tertiary),
        ]),
      ),
    );
  }
}

/// Icône dans un carré arrondi coloré (style Réglages iOS).
class IconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const IconTile(this.icon, this.color, {super.key, this.size = 32});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(size * 0.26)),
        child: Icon(icon, color: Colors.white, size: size * 0.58),
      );
}

/// Contrôle segmenté iOS.
class Segmented<T extends Object> extends StatelessWidget {
  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;
  const Segmented({super.key, required this.options, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return CupertinoSlidingSegmentedControl<T>(
      groupValue: value,
      backgroundColor: c.fill,
      thumbColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF636366) : Colors.white,
      padding: const EdgeInsets.all(3),
      children: options.map((k, v) => MapEntry(
            k,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.label)),
            ),
          )),
      onValueChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

/// Pastille à cocher (choix multiples ou simples).
class Tag extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  const Tag({super.key, required this.label, required this.selected, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fg = selected ? Colors.white : c.label;
    return Material(
      color: selected ? c.accent : c.fill,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
            Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: -0.15)),
          ]),
        ),
      ),
    );
  }
}

/// Prix mis en valeur.
class PriceLabel extends StatelessWidget {
  final String price;
  final String? caption;
  const PriceLabel(this.price, {super.key, this.caption});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(price, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
      if (caption != null) Text(caption!, style: TextStyle(fontSize: 12.5, color: c.secondary)),
    ]);
  }
}

/// Lien discret « Voir l'offre ↗ ».
class OfferLink extends StatelessWidget {
  final String url;
  final String label;
  const OfferLink(this.url, {super.key, this.label = 'Voir l\'offre'});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => openLink(context, url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(color: c.accent, fontWeight: FontWeight.w500, fontSize: 14)),
          const SizedBox(width: 2),
          Icon(CupertinoIcons.arrow_up_right, size: 13, color: c.accent),
        ]),
      ),
    );
  }
}

class SimulatedDataNotice extends StatelessWidget {
  const SimulatedDataNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        Icon(CupertinoIcons.info_circle, size: 15, color: c.secondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text('Prix et horaires indicatifs. Vérifiez sur le site de réservation.',
              style: TextStyle(color: c.secondary, fontSize: 13)),
        ),
      ]),
    );
  }
}

Future<void> openLink(BuildContext context, String url) async {
  if (url.isEmpty) return;
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
        children: List.generate(
            stars, (_) => Icon(CupertinoIcons.star_fill, size: 12, color: AppColors.of(context).orange)),
      );
}

/// Note sur 10, sobre.
class RatingBadge extends StatelessWidget {
  final double rating;
  final int reviews;
  const RatingBadge(this.rating, this.reviews, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final label = rating >= 9
        ? 'Exceptionnel'
        : rating >= 8.5
            ? 'Fabuleux'
            : rating >= 8
                ? 'Très bien'
                : rating >= 7
                    ? 'Bien'
                    : 'Correct';
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
        child: Text(rating.toStringAsFixed(1),
            style: TextStyle(color: c.accent, fontWeight: FontWeight.w700, fontSize: 13)),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text('$label · $reviews avis',
            overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: c.secondary)),
      ),
    ]);
  }
}

/// Bandeau d'alerte discret (orange ou rouge).
class InlineAlert extends StatelessWidget {
  final String text;
  final bool severe;
  final (String, VoidCallback)? action;
  const InlineAlert(this.text, {super.key, this.severe = false, this.action});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = severe ? c.red : c.orange;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(CupertinoIcons.exclamationmark_triangle_fill, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: c.label, fontSize: 14))),
        if (action != null) ...[
          const SizedBox(width: 8),
          TextButton(onPressed: action!.$2, child: Text(action!.$1)),
        ],
      ]),
    );
  }
}

/// Stepper « – 2 + » compact.
class CountStepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final String Function(int)? format;
  const CountStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 99,
    this.format,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    Widget btn(IconData i, VoidCallback? f) => SizedBox(
          width: 40,
          height: 34,
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: f,
            icon: Icon(i, size: 16),
            color: c.label,
            disabledColor: c.tertiary,
          ),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (format != null)
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Text(format!(value), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ),
      Container(
        decoration: BoxDecoration(color: c.fill, borderRadius: BorderRadius.circular(9)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          btn(CupertinoIcons.minus, value > min ? () => onChanged(value - 1) : null),
          Container(width: 1, height: 18, color: c.tertiary.withValues(alpha: 0.6)),
          btn(CupertinoIcons.plus, value < max ? () => onChanged(value + 1) : null),
        ]),
      ),
    ]);
  }
}
