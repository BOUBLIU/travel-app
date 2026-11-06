import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/currency.dart';
import '../../state/app_state.dart';
import '../format.dart';

IconData expenseIcon(ExpenseCategory c) => switch (c) {
      ExpenseCategory.meals => Icons.restaurant,
      ExpenseCategory.groceries => Icons.shopping_basket_outlined,
      ExpenseCategory.transport => Icons.directions_bus_outlined,
      ExpenseCategory.activities => Icons.local_activity_outlined,
      ExpenseCategory.lodging => Icons.hotel_outlined,
      ExpenseCategory.other => Icons.more_horiz,
    };

/// Saisie rapide d'une dépense : catégorie + pavé numérique.
/// Ouvre une feuille modale et renvoie la dépense créée (ou null).
Future<Expense?> showQuickExpense(BuildContext context, Trip trip, {ExpenseCategory? category}) {
  return showModalBottomSheet<Expense>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
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

  @override
  Widget build(BuildContext context) {
    final fx = context.read<AppState>().currency;
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final eurValue = fx.toEur(_amount, _currency);
    final localCurrency = widget.trip.destination?.currency ?? 'EUR';
    final currencies = {localCurrency, 'EUR', ...CurrencyService.currencies}.toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nouvelle dépense', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ExpenseCategory.values
                  .map((c) => ChoiceChip(
                        avatar: Icon(expenseIcon(c), size: 18),
                        label: Text(c.label),
                        selected: _cat == c,
                        onSelected: (_) => setState(() => _cat = c),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    _input.isEmpty ? '0' : _input,
                    textAlign: TextAlign.right,
                    style: tt.displayMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _currency,
                  items: currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _currency = v ?? _currency),
                ),
              ],
            ),
            if (_currency != 'EUR')
              Text(
                '≈ ${eur(eurValue, cents: true)}  (1 $_currency = ${fx.rateToEur(_currency).toStringAsPrecision(3)} €'
                '${fx.isLive ? '' : ', taux hors ligne'})',
                textAlign: TextAlign.right,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.end,
              children: _cat.presets.map((v) {
                final local = _preset(fx, v);
                return ActionChip(
                  label: Text(money(local, _currency)),
                  onPressed: () => setState(() => _input = _fmtInput(local)),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            _NumPad(onKey: _key),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Note (optionnel)',
                hintText: 'Ex. : ramen à Shibuya',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
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
              icon: const Icon(Icons.check),
              label: Text(_amount <= 0 ? 'Saisissez un montant' : 'Ajouter ${money(_amount, _currency)}'),
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
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', ',', '0', '⌫'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.4,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: keys
          .map((k) => FilledButton.tonal(
                onPressed: () => onKey(k),
                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: k == '⌫'
                    ? const Icon(Icons.backspace_outlined)
                    : Text(k, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
              ))
          .toList(),
    );
  }
}
