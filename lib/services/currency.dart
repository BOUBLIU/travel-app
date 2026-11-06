import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Conversion de devises vers l'euro.
/// Taux récupérés auprès de la BCE (via api.frankfurter.app, gratuit, sans clé),
/// mis en cache 12 h, avec des taux de secours intégrés hors connexion.
class CurrencyService {
  static const _cacheKey = 'fx_rates_v1';

  /// Combien d'euros vaut 1 unité de la devise (taux de secours approximatifs).
  static const Map<String, double> fallbackToEur = {
    'EUR': 1, 'USD': 0.92, 'GBP': 1.17, 'CHF': 1.05, 'JPY': 0.0061, 'CAD': 0.67,
    'AUD': 0.60, 'NZD': 0.55, 'CNY': 0.13, 'HKD': 0.12, 'SGD': 0.69, 'KRW': 0.00067,
    'THB': 0.026, 'VND': 0.000036, 'IDR': 0.000057, 'INR': 0.011, 'AED': 0.25,
    'TRY': 0.026, 'MAD': 0.092, 'TND': 0.30, 'EGP': 0.019, 'XOF': 0.0015, 'ZAR': 0.051,
    'MXN': 0.050, 'BRL': 0.17, 'ARS': 0.00095, 'PEN': 0.25, 'CZK': 0.040, 'HUF': 0.0025,
    'PLN': 0.23, 'DKK': 0.134, 'SEK': 0.087, 'NOK': 0.085, 'ISK': 0.0066, 'MUR': 0.020,
  };

  final http.Client _client;
  Map<String, double> _rates = Map.of(fallbackToEur);
  DateTime? _fetchedAt;

  CurrencyService([http.Client? client]) : _client = client ?? http.Client();

  bool get isLive => _fetchedAt != null;
  DateTime? get fetchedAt => _fetchedAt;

  static List<String> get currencies => fallbackToEur.keys.toList()..sort();

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        _fetchedAt = DateTime.parse(j['at']);
        _rates = {
          ..._rates,
          ...(j['rates'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toDouble())),
        };
      }
    } catch (_) {}
    if (_fetchedAt == null || DateTime.now().difference(_fetchedAt!) > const Duration(hours: 12)) {
      await refresh();
    }
  }

  Future<void> refresh() async {
    try {
      final res = await _client
          .get(Uri.https('api.frankfurter.app', '/latest', {'from': 'EUR'}))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;
      final rates = (jsonDecode(res.body)['rates'] as Map<String, dynamic>);
      // L'API donne 1 EUR = x devise ; on stocke 1 devise = 1/x EUR.
      final toEur = <String, double>{'EUR': 1};
      rates.forEach((k, v) => toEur[k] = 1 / (v as num).toDouble());
      _rates = {..._rates, ...toEur};
      _fetchedAt = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode({'at': _fetchedAt!.toIso8601String(), 'rates': toEur}));
    } catch (_) {}
  }

  double rateToEur(String currency) => _rates[currency] ?? 1;

  double toEur(double amount, String currency) => amount * rateToEur(currency);

  double fromEur(double eur, String currency) => eur / rateToEur(currency);
}
