import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/currency.dart';
import '../../state/app_state.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';

IconData expenseIcon(ExpenseCategory c) => switch (c) {
      ExpenseCategory.meals => Icons.restaurant_rounded,
      ExpenseCategory.groceries => CupertinoIcons.cart_fill,
      ExpenseCategory.transport => CupertinoIcons.tram_fill,
      ExpenseCategory.activities => CupertinoIcons.ticket_fill,
      ExpenseCategory.lodging => CupertinoIcons.bed_double_fill,
      ExpenseCategory.other => CupertinoIcons.ellipsis,
    };

Color expenseColor(AppColors c, ExpenseCategory e) => switch (e) {
      ExpenseCategory.meals => c.orange,
      ExpenseCategory.groceries => c.green,
      ExpenseCategory.transport => const Color(0xFF5856D6),
      ExpenseCategory.activities => const Color(0xFFFF2D55),
      ExpenseCategory.lodging => c.accent,
      ExpenseCategory.other => const Color(0xFF8E8E93),
    };

/// Saisie rapide d'une dépense : catégorie + pavé numérique.
Future<Expense?> showQuickExpense(BuildContext context, Trip trip, {ExpenseCategory? category}) {
  return showModalBottomSheet<Expense>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => QuickExpenseSheet(trip: trip, initialCategory: category ?? ExpenseCategory.meals),
  );
}

class QuickExpenseSheet extends StatefulWidget {
  final Trip trip;
  final ExpenseCategory initialCategory;
  const QuickExpenseSheet({super.key, required this.trip, required this.initialCategory});

  @override
  State<QuickExpenseSheet> createState() => _QuickExpenseSheetState();
}

class _QuickExpenseSheetState extends State<QuickExpenseSheet> {
  late ExpenseCategory _cat = widget.initialCategory;
  late String _currency = widget.trip.destination?.currency ?? 'EUR';
  String _input = '';
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  double get _amount => double.tryParse(_input.replaceAll(',', '.')) ?? 0;

  void _key(String k) {
    setState(() {
      if (k == '⌫') {
        if (_input.isNotEmpty) _input = _input.substring(0, _input.length - 1);
      } else if (k == ',') {
        if (!_input.contains(',')) _input = _input.isEmpty ? '0,' : '$_input,';
      } else {
        final parts = _input.split(',');
        if (parts.length == 2 && parts[1].length >= 2) return; // 2 décimales max.
        if (_input == '0') _input = '';
        if (_input.length < 10) _input += k;
      }
    });
  }

  /// Montant préréglé exprimé dans la devise choisie, arrondi joliment.
  double _preset(CurrencyService fx, double eurValue) {
    final local = fx.fromEur(eurValue, _currency);
    if (local < 20) return local.roundToDouble();
    final mag = local < 200 ? 5 : local < 2000 ? 50 : local < 20000 ? 500 : 5000;
    return (local / mag).round() * mag.toDouble();
  }

  String _fmtInput(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2).replaceAll('.', ',');

  Future<void> _pickCurrency(List<String> currencies) async {
    final r = await showModalBottomSheet<String>(
      context: context,
      constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
      builder: (c) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          GroupedList(
            children: currencies
                .map((cur) => GroupedRow(
                      title: cur,
                      trailing: cur == _currency
                          ? Icon(CupertinoIcons.checkmark_alt, color: AppColors.of(c).accent)
                          : const SizedBox.shrink(),
                      onTap: () => Navigator.pop(c, cur),
                    ))
                .toList(),
          ),
        ],
      ),
    );
    if (r != null) setState(() => _currency = r);
  }

  @override
  Widget build(BuildContext context) {
    final fx = context.read<AppState>().currency;
    final c = AppColors.of(context);
    final eurValue = fx.toEur(_amount, _currency);
    final localCurrency = widget.trip.destination?.currency ?? 'EUR';
    final currencies = {localCurrency, 'EUR', ...CurrencyService.currencies}.toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nouvelle dépense', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: ExpenseCategory.values
                    .map((e) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Tag(icon: expenseIcon(e), label: e.label, selected: _cat == e, onTap: () => setState(() => _cat = e)),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 20),
            // Montant
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _input.isEmpty ? '0' : _input,
                      style: TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -2.5,
                        color: _input.isEmpty ? c.tertiary : c.label,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _pickCurrency(currencies),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(_currency, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: c.accent)),
                      Icon(CupertinoIcons.chevron_down, size: 14, color: c.accent),
                    ]),
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 20,
              child: _currency == 'EUR'
                  ? null
                  : Text(
                      '≈ ${eur(eurValue, cents: true)} · 1 $_currency = ${fx.rateToEur(_currency).toStringAsPrecision(3)} €'
                      '${fx.isLive ? '' : ' (taux hors ligne)'}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.secondary, fontSize: 13),
                    ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: _cat.presets.map((v) {
                final local = _preset(fx, v);
                return Tag(
                  label: money(local, _currency),
                  selected: false,
                  onTap: () => setState(() => _input = _fmtInput(local)),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            _NumPad(onKey: _key),
            const SizedBox(height: 14),
            TextField(
              controller: _note,
              decoration: InputDecoration(
                hintText: 'Note (facultatif) — ex. ramen à Shibuya',
                prefixIcon: const Icon(CupertinoIcons.pencil, size: 18),
                fillColor: c.card,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
              onPressed: _amount <= 0
                  ? null
                  : () => Navigator.pop(
                        context,
                        Expense(
                          id: DateTime.now().microsecondsSinceEpoch.toString(),
                          category: _cat,
                          amountEur: double.parse(eurValue.toStringAsFixed(2)),
                          originalAmount: _amount,
                          currency: _currency,
                          note: _note.text.trim(),
                          date: DateTime.now(),
                        ),
                      ),
              child: Text(_amount <= 0 ? 'Saisissez un montant' : 'Ajouter ${money(_amount, _currency)}',
                  style: const TextStyle(fontSize: 17)),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumPad extends StatelessWidget {
  final void Function(String) onKey;
  const _NumPad({required this.onKey});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', ',', '0', '⌫'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: keys
          .map((k) => Material(
                color: k == '⌫' || k == ',' ? Colors.transparent : c.card,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onKey(k),
                  child: Center(
                    child: k == '⌫'
                        ? Icon(CupertinoIcons.delete_left, color: c.label, size: 24)
                        : Text(k, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w400, color: c.label)),
                  ),
                ),
              ))
          .toList(),
    );
  }
}
