import 'package:intl/intl.dart';

final _eur0 = NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 0);
final _eur2 = NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 2);

String eur(double v, {bool cents = false}) => (cents ? _eur2 : _eur0).format(v);

String money(double v, String currency) {
  if (currency == 'EUR') return eur(v, cents: true);
  final digits = v.abs() >= 1000 ? 0 : 2;
  return NumberFormat.currency(locale: 'fr_FR', name: currency, symbol: currency, decimalDigits: digits).format(v);
}

String hm(DateTime d) => DateFormat('HH:mm').format(d);
String dayLong(DateTime d) => toBeginningOfSentenceCase(DateFormat('EEEE d MMMM', 'fr_FR').format(d));
String dayShort(DateTime d) => DateFormat('E d MMM', 'fr_FR').format(d);
String dateFr(DateTime d) => DateFormat('d MMM yyyy', 'fr_FR').format(d);

String duration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  return h == 0 ? '$m min' : '$h h ${m.toString().padLeft(2, '0')}';
}
