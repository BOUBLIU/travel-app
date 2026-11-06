import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

/// Catalogue intégré de villes (fonctionne hors ligne).
const List<Place> kPlaces = [
  // France & Europe francophone
  Place(name: 'Paris', country: 'France', currency: 'EUR', iata: 'CDG', lat: 48.8566, lng: 2.3522, costIndex: 1.15),
  Place(name: 'Lyon', country: 'France', currency: 'EUR', iata: 'LYS', lat: 45.7640, lng: 4.8357, costIndex: 1.0),
  Place(name: 'Marseille', country: 'France', currency: 'EUR', iata: 'MRS', lat: 43.2965, lng: 5.3698, costIndex: 0.95),
  Place(name: 'Nice', country: 'France', currency: 'EUR', iata: 'NCE', lat: 43.7102, lng: 7.2620, costIndex: 1.05),
  Place(name: 'Toulouse', country: 'France', currency: 'EUR', iata: 'TLS', lat: 43.6047, lng: 1.4442, costIndex: 0.95),
  Place(name: 'Bordeaux', country: 'France', currency: 'EUR', iata: 'BOD', lat: 44.8378, lng: -0.5792, costIndex: 1.0),
  Place(name: 'Nantes', country: 'France', currency: 'EUR', iata: 'NTE', lat: 47.2184, lng: -1.5536, costIndex: 0.95),
  Place(name: 'Lille', country: 'France', currency: 'EUR', iata: 'LIL', lat: 50.6292, lng: 3.0573, costIndex: 0.95),
  Place(name: 'Bruxelles', country: 'Belgique', currency: 'EUR', iata: 'BRU', lat: 50.8503, lng: 4.3517, costIndex: 1.05),
  Place(name: 'Genève', country: 'Suisse', currency: 'CHF', iata: 'GVA', lat: 46.2044, lng: 6.1432, costIndex: 1.6),
  Place(name: 'Zurich', country: 'Suisse', currency: 'CHF', iata: 'ZRH', lat: 47.3769, lng: 8.5417, costIndex: 1.65),
  // Europe
  Place(name: 'Londres', country: 'Royaume-Uni', currency: 'GBP', iata: 'LHR', lat: 51.5074, lng: -0.1278, costIndex: 1.35),
  Place(name: 'Édimbourg', country: 'Royaume-Uni', currency: 'GBP', iata: 'EDI', lat: 55.9533, lng: -3.1883, costIndex: 1.15),
  Place(name: 'Dublin', country: 'Irlande', currency: 'EUR', iata: 'DUB', lat: 53.3498, lng: -6.2603, costIndex: 1.25),
  Place(name: 'Amsterdam', country: 'Pays-Bas', currency: 'EUR', iata: 'AMS', lat: 52.3676, lng: 4.9041, costIndex: 1.25),
  Place(name: 'Berlin', country: 'Allemagne', currency: 'EUR', iata: 'BER', lat: 52.5200, lng: 13.4050, costIndex: 1.0),
  Place(name: 'Munich', country: 'Allemagne', currency: 'EUR', iata: 'MUC', lat: 48.1351, lng: 11.5820, costIndex: 1.15),
  Place(name: 'Vienne', country: 'Autriche', currency: 'EUR', iata: 'VIE', lat: 48.2082, lng: 16.3738, costIndex: 1.05),
  Place(name: 'Prague', country: 'Tchéquie', currency: 'CZK', iata: 'PRG', lat: 50.0755, lng: 14.4378, costIndex: 0.75),
  Place(name: 'Budapest', country: 'Hongrie', currency: 'HUF', iata: 'BUD', lat: 47.4979, lng: 19.0402, costIndex: 0.65),
  Place(name: 'Cracovie', country: 'Pologne', currency: 'PLN', iata: 'KRK', lat: 50.0647, lng: 19.9450, costIndex: 0.6),
  Place(name: 'Copenhague', country: 'Danemark', currency: 'DKK', iata: 'CPH', lat: 55.6761, lng: 12.5683, costIndex: 1.4),
  Place(name: 'Stockholm', country: 'Suède', currency: 'SEK', iata: 'ARN', lat: 59.3293, lng: 18.0686, costIndex: 1.25),
  Place(name: 'Oslo', country: 'Norvège', currency: 'NOK', iata: 'OSL', lat: 59.9139, lng: 10.7522, costIndex: 1.45),
  Place(name: 'Reykjavik', country: 'Islande', currency: 'ISK', iata: 'KEF', lat: 64.1466, lng: -21.9426, costIndex: 1.6),
  Place(name: 'Madrid', country: 'Espagne', currency: 'EUR', iata: 'MAD', lat: 40.4168, lng: -3.7038, costIndex: 0.9),
  Place(name: 'Barcelone', country: 'Espagne', currency: 'EUR', iata: 'BCN', lat: 41.3874, lng: 2.1686, costIndex: 1.0),
  Place(name: 'Séville', country: 'Espagne', currency: 'EUR', iata: 'SVQ', lat: 37.3891, lng: -5.9845, costIndex: 0.8),
  Place(name: 'Valence', country: 'Espagne', currency: 'EUR', iata: 'VLC', lat: 39.4699, lng: -0.3763, costIndex: 0.8),
  Place(name: 'Lisbonne', country: 'Portugal', currency: 'EUR', iata: 'LIS', lat: 38.7223, lng: -9.1393, costIndex: 0.85),
  Place(name: 'Porto', country: 'Portugal', currency: 'EUR', iata: 'OPO', lat: 41.1579, lng: -8.6291, costIndex: 0.8),
  Place(name: 'Rome', country: 'Italie', currency: 'EUR', iata: 'FCO', lat: 41.9028, lng: 12.4964, costIndex: 1.0),
  Place(name: 'Florence', country: 'Italie', currency: 'EUR', iata: 'FLR', lat: 43.7696, lng: 11.2558, costIndex: 1.05),
  Place(name: 'Venise', country: 'Italie', currency: 'EUR', iata: 'VCE', lat: 45.4408, lng: 12.3155, costIndex: 1.2),
  Place(name: 'Milan', country: 'Italie', currency: 'EUR', iata: 'MXP', lat: 45.4642, lng: 9.1900, costIndex: 1.1),
  Place(name: 'Naples', country: 'Italie', currency: 'EUR', iata: 'NAP', lat: 40.8518, lng: 14.2681, costIndex: 0.85),
  Place(name: 'Athènes', country: 'Grèce', currency: 'EUR', iata: 'ATH', lat: 37.9838, lng: 23.7275, costIndex: 0.8),
  Place(name: 'Istanbul', country: 'Turquie', currency: 'TRY', iata: 'IST', lat: 41.0082, lng: 28.9784, costIndex: 0.6),
  Place(name: 'Dubrovnik', country: 'Croatie', currency: 'EUR', iata: 'DBV', lat: 42.6507, lng: 18.0944, costIndex: 1.0),
  // Afrique & Moyen-Orient
  Place(name: 'Marrakech', country: 'Maroc', currency: 'MAD', iata: 'RAK', lat: 31.6295, lng: -7.9811, costIndex: 0.5),
  Place(name: 'Casablanca', country: 'Maroc', currency: 'MAD', iata: 'CMN', lat: 33.5731, lng: -7.5898, costIndex: 0.5),
  Place(name: 'Tunis', country: 'Tunisie', currency: 'TND', iata: 'TUN', lat: 36.8065, lng: 10.1815, costIndex: 0.45),
  Place(name: 'Le Caire', country: 'Égypte', currency: 'EGP', iata: 'CAI', lat: 30.0444, lng: 31.2357, costIndex: 0.4),
  Place(name: 'Dakar', country: 'Sénégal', currency: 'XOF', iata: 'DSS', lat: 14.7167, lng: -17.4677, costIndex: 0.6),
  Place(name: 'Le Cap', country: 'Afrique du Sud', currency: 'ZAR', iata: 'CPT', lat: -33.9249, lng: 18.4241, costIndex: 0.6),
  Place(name: 'Dubaï', country: 'Émirats arabes unis', currency: 'AED', iata: 'DXB', lat: 25.2048, lng: 55.2708, costIndex: 1.3),
  // Amériques
  Place(name: 'New York', country: 'États-Unis', currency: 'USD', iata: 'JFK', lat: 40.7128, lng: -74.0060, costIndex: 1.6),
  Place(name: 'Los Angeles', country: 'États-Unis', currency: 'USD', iata: 'LAX', lat: 34.0522, lng: -118.2437, costIndex: 1.45),
  Place(name: 'San Francisco', country: 'États-Unis', currency: 'USD', iata: 'SFO', lat: 37.7749, lng: -122.4194, costIndex: 1.6),
  Place(name: 'Miami', country: 'États-Unis', currency: 'USD', iata: 'MIA', lat: 25.7617, lng: -80.1918, costIndex: 1.4),
  Place(name: 'Montréal', country: 'Canada', currency: 'CAD', iata: 'YUL', lat: 45.5017, lng: -73.5673, costIndex: 1.05),
  Place(name: 'Québec', country: 'Canada', currency: 'CAD', iata: 'YQB', lat: 46.8139, lng: -71.2080, costIndex: 1.0),
  Place(name: 'Mexico', country: 'Mexique', currency: 'MXN', iata: 'MEX', lat: 19.4326, lng: -99.1332, costIndex: 0.55),
  Place(name: 'Cancún', country: 'Mexique', currency: 'MXN', iata: 'CUN', lat: 21.1619, lng: -86.8515, costIndex: 0.75),
  Place(name: 'Rio de Janeiro', country: 'Brésil', currency: 'BRL', iata: 'GIG', lat: -22.9068, lng: -43.1729, costIndex: 0.6),
  Place(name: 'Buenos Aires', country: 'Argentine', currency: 'ARS', iata: 'EZE', lat: -34.6037, lng: -58.3816, costIndex: 0.55),
  Place(name: 'Lima', country: 'Pérou', currency: 'PEN', iata: 'LIM', lat: -12.0464, lng: -77.0428, costIndex: 0.5),
  // Asie & Océanie
  Place(name: 'Tokyo', country: 'Japon', currency: 'JPY', iata: 'HND', lat: 35.6762, lng: 139.6503, costIndex: 1.05),
  Place(name: 'Kyoto', country: 'Japon', currency: 'JPY', iata: 'KIX', lat: 35.0116, lng: 135.7681, costIndex: 1.0),
  Place(name: 'Osaka', country: 'Japon', currency: 'JPY', iata: 'KIX', lat: 34.6937, lng: 135.5023, costIndex: 0.95),
  Place(name: 'Séoul', country: 'Corée du Sud', currency: 'KRW', iata: 'ICN', lat: 37.5665, lng: 126.9780, costIndex: 0.95),
  Place(name: 'Pékin', country: 'Chine', currency: 'CNY', iata: 'PEK', lat: 39.9042, lng: 116.4074, costIndex: 0.7),
  Place(name: 'Shanghai', country: 'Chine', currency: 'CNY', iata: 'PVG', lat: 31.2304, lng: 121.4737, costIndex: 0.8),
  Place(name: 'Hong Kong', country: 'Hong Kong', currency: 'HKD', iata: 'HKG', lat: 22.3193, lng: 114.1694, costIndex: 1.25),
  Place(name: 'Bangkok', country: 'Thaïlande', currency: 'THB', iata: 'BKK', lat: 13.7563, lng: 100.5018, costIndex: 0.5),
  Place(name: 'Chiang Mai', country: 'Thaïlande', currency: 'THB', iata: 'CNX', lat: 18.7883, lng: 98.9853, costIndex: 0.4),
  Place(name: 'Phuket', country: 'Thaïlande', currency: 'THB', iata: 'HKT', lat: 7.8804, lng: 98.3923, costIndex: 0.6),
  Place(name: 'Hanoï', country: 'Vietnam', currency: 'VND', iata: 'HAN', lat: 21.0278, lng: 105.8342, costIndex: 0.4),
  Place(name: 'Hô Chi Minh-Ville', country: 'Vietnam', currency: 'VND', iata: 'SGN', lat: 10.8231, lng: 106.6297, costIndex: 0.4),
  Place(name: 'Singapour', country: 'Singapour', currency: 'SGD', iata: 'SIN', lat: 1.3521, lng: 103.8198, costIndex: 1.35),
  Place(name: 'Bali', country: 'Indonésie', currency: 'IDR', iata: 'DPS', lat: -8.6500, lng: 115.2167, costIndex: 0.5),
  Place(name: 'Delhi', country: 'Inde', currency: 'INR', iata: 'DEL', lat: 28.6139, lng: 77.2090, costIndex: 0.35),
  Place(name: 'Sydney', country: 'Australie', currency: 'AUD', iata: 'SYD', lat: -33.8688, lng: 151.2093, costIndex: 1.35),
  Place(name: 'Melbourne', country: 'Australie', currency: 'AUD', iata: 'MEL', lat: -37.8136, lng: 144.9631, costIndex: 1.3),
  // Îles
  Place(name: 'La Réunion', country: 'France', currency: 'EUR', iata: 'RUN', lat: -20.8823, lng: 55.4504, costIndex: 1.0),
  Place(name: 'Pointe-à-Pitre', country: 'France', currency: 'EUR', iata: 'PTP', lat: 16.2411, lng: -61.5331, costIndex: 1.05),
  Place(name: 'Fort-de-France', country: 'France', currency: 'EUR', iata: 'FDF', lat: 14.6161, lng: -61.0588, costIndex: 1.05),
  Place(name: 'Maurice', country: 'Maurice', currency: 'MUR', iata: 'MRU', lat: -20.1609, lng: 57.5012, costIndex: 0.75),
];

/// Devise et indice de coût par pays, pour les villes trouvées par géocodage.
const Map<String, (String, double)> _countryInfo = {
  'fr': ('EUR', 1.0), 'be': ('EUR', 1.05), 'ch': ('CHF', 1.6), 'gb': ('GBP', 1.25),
  'ie': ('EUR', 1.2), 'nl': ('EUR', 1.2), 'de': ('EUR', 1.0), 'at': ('EUR', 1.05),
  'it': ('EUR', 0.95), 'es': ('EUR', 0.85), 'pt': ('EUR', 0.8), 'gr': ('EUR', 0.8),
  'hr': ('EUR', 0.85), 'cz': ('CZK', 0.75), 'hu': ('HUF', 0.65), 'pl': ('PLN', 0.6),
  'dk': ('DKK', 1.4), 'se': ('SEK', 1.2), 'no': ('NOK', 1.45), 'is': ('ISK', 1.6),
  'tr': ('TRY', 0.6), 'ma': ('MAD', 0.5), 'tn': ('TND', 0.45), 'eg': ('EGP', 0.4),
  'sn': ('XOF', 0.6), 'za': ('ZAR', 0.6), 'ae': ('AED', 1.3), 'us': ('USD', 1.4),
  'ca': ('CAD', 1.05), 'mx': ('MXN', 0.6), 'br': ('BRL', 0.6), 'ar': ('ARS', 0.55),
  'pe': ('PEN', 0.5), 'jp': ('JPY', 1.0), 'kr': ('KRW', 0.95), 'cn': ('CNY', 0.7),
  'th': ('THB', 0.5), 'vn': ('VND', 0.4), 'sg': ('SGD', 1.35), 'id': ('IDR', 0.5),
  'in': ('INR', 0.35), 'au': ('AUD', 1.3), 'nz': ('NZD', 1.25), 'mu': ('MUR', 0.75),
};

String _norm(String s) {
  const from = 'àâäáãéèêëíìîïóòôöõúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final lower = s.toLowerCase().trim();
  final b = StringBuffer();
  for (final ch in lower.split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString();
}

class PlaceService {
  final http.Client _client;
  PlaceService([http.Client? client]) : _client = client ?? http.Client();

  /// Suggestions pour l'autocomplétion (catalogue intégré).
  static List<Place> suggest(String query) {
    final q = _norm(query);
    if (q.isEmpty) return const [];
    return kPlaces
        .where((p) => _norm(p.name).startsWith(q) || _norm(p.country).startsWith(q))
        .take(8)
        .toList();
  }

  static Place? findLocal(String name) {
    final q = _norm(name);
    for (final p in kPlaces) {
      if (_norm(p.name) == q) return p;
    }
    return null;
  }

  /// Résout un nom de ville : catalogue d'abord, puis géocodage OpenStreetMap.
  Future<Place?> resolve(String name) async {
    final local = findLocal(name);
    if (local != null) return local;
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': name,
        'format': 'json',
        'limit': '1',
        'addressdetails': '1',
        'accept-language': 'fr',
      });
      final res = await _client
          .get(uri, headers: {'User-Agent': 'BudgetVoyage/1.0 (application mobile)'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final list = jsonDecode(res.body) as List;
      if (list.isEmpty) return null;
      final r = list.first as Map<String, dynamic>;
      final addr = (r['address'] as Map?) ?? const {};
      final cc = (addr['country_code'] as String?)?.toLowerCase() ?? '';
      final info = _countryInfo[cc] ?? ('EUR', 1.0);
      final display = (addr['city'] ?? addr['town'] ?? addr['village'] ?? name) as String;
      return Place(
        name: display,
        country: (addr['country'] as String?) ?? '',
        currency: info.$1,
        lat: double.parse(r['lat']),
        lng: double.parse(r['lon']),
        costIndex: info.$2,
      );
    } catch (_) {
      return null;
    }
  }
}
