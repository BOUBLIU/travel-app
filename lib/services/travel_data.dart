import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/models.dart';

/// URL du petit serveur qui appelle les API (SerpApi, Google Maps…).
/// À fournir au build : `flutter build apk --dart-define=API_BASE_URL=https://…`
/// Sans serveur, l'application utilise des données simulées réalistes.
const String kApiBaseUrl = String.fromEnvironment('API_BASE_URL');

/// Interface commune aux sources de données.
abstract class TravelDataSource {
  bool get isSimulated;

  Future<List<FlightOption>> searchFlights({
    required Place origin,
    required Place destination,
    required DateTime departDate,
    required DateTime returnDate,
    required int travelers,
  });

  Future<List<TransferOption>> airportTransfers({
    required Place city,
    required DateTime start,
    required bool toAirport,
    required int travelers,
  });

  Future<List<HotelOption>> searchHotels({
    required Place city,
    required DateTime checkIn,
    required int nights,
    required int travelers,
  });

  Future<List<Activity>> activities({
    required Place city,
    required List<Interest> interests,
    required int travelers,
  });

  List<LocalTransportChoice> localTransportOptions({
    required Place city,
    required int days,
    required int activityCount,
    required int travelers,
  });

  IntercityLeg intercityLeg({
    required Place from,
    required Place to,
    required DateTime date,
    required int travelers,
  });
}

/// Données simulées déterministes (mêmes paramètres → mêmes résultats).
class SimulatedTravelData implements TravelDataSource {
  @override
  bool get isSimulated => true;

  Random _rng(List<Object> parts) {
    var h = 17;
    for (final c in parts.join('|').codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return Random(h);
  }

  static final _fmtDate = DateFormat('yyyy-MM-dd');

  static double _round(double v) => (v * 100).roundToDouble() / 100;

  @override
  Future<List<FlightOption>> searchFlights({
    required Place origin,
    required Place destination,
    required DateTime departDate,
    required DateTime returnDate,
    required int travelers,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final r = _rng([origin.name, destination.name, _fmtDate.format(departDate)]);
    final km = max(origin.distanceTo(destination), 200.0);
    final longHaul = km > 4000;
    const airlines = [
      ('Air France', 'AF'), ('Lufthansa', 'LH'), ('KLM', 'KL'), ('Emirates', 'EK'),
      ('Qatar Airways', 'QR'), ('Turkish Airlines', 'TK'), ('Vueling', 'VY'),
      ('easyJet', 'U2'), ('Transavia', 'TO'), ('Iberia', 'IB'), ('ITA Airways', 'AZ'),
      ('Japan Airlines', 'JL'), ('Finnair', 'AY'), ('Air Canada', 'AC'),
    ];
    const hubs = ['Amsterdam', 'Francfort', 'Istanbul', 'Doha', 'Dubaï', 'Helsinki', 'Munich', 'Madrid'];
    final from = origin.iata ?? origin.name.substring(0, min(3, origin.name.length)).toUpperCase();
    final to = destination.iata ?? destination.name.substring(0, min(3, destination.name.length)).toUpperCase();
    final list = <FlightOption>[];
    for (var i = 0; i < 8; i++) {
      final a = airlines[r.nextInt(airlines.length)];
      final stops = longHaul ? r.nextInt(3) : (r.nextDouble() < 0.6 ? 0 : 1);
      final stopCities = List.generate(stops, (_) => hubs[r.nextInt(hubs.length)]);
      final flyMin = (km / 820 * 60 + 35).round();
      final totalMin = flyMin + stops * (70 + r.nextInt(150));
      final depHour = 6 + r.nextInt(16);
      final dep = DateTime(departDate.year, departDate.month, departDate.day, depHour, r.nextInt(12) * 5);
      final arr = dep.add(Duration(minutes: totalMin));
      final retDep = DateTime(returnDate.year, returnDate.month, returnDate.day, 9 + r.nextInt(12), r.nextInt(12) * 5);
      final retStops = stops == 0 ? 0 : max(0, stops - r.nextInt(2));
      final retArr = retDep.add(Duration(minutes: flyMin + retStops * (70 + r.nextInt(150))));
      // Prix aller-retour par personne : base distance, moins cher avec escales.
      var pp = (70 + km * (longHaul ? 0.075 : 0.11)) * (0.75 + r.nextDouble() * 0.7);
      pp *= 1 - stops * 0.12;
      pp = pp.roundToDouble();
      final q = Uri.encodeComponent(
          'Flights from $from to $to on ${_fmtDate.format(departDate)} through ${_fmtDate.format(returnDate)}');
      list.add(FlightOption(
        id: 'f$i',
        airline: a.$1,
        flightNumber: '${a.$2}${100 + r.nextInt(8900)}',
        fromCode: from,
        toCode: to,
        outDepart: dep,
        outArrive: arr,
        outStops: stopCities,
        retDepart: retDep,
        retArrive: retArr,
        retStops: List.generate(retStops, (_) => hubs[r.nextInt(hubs.length)]),
        pricePerPerson: pp,
        totalPrice: pp * travelers,
        bookingUrl: 'https://www.google.com/travel/flights?q=$q&curr=EUR&hl=fr',
      ));
    }
    list.sort((a, b) => a.totalPrice.compareTo(b.totalPrice));
    return list;
  }

  @override
  Future<List<TransferOption>> airportTransfers({
    required Place city,
    required DateTime start,
    required bool toAirport,
    required int travelers,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final ci = city.costIndex;
    final airport = 'Aéroport ${city.iata ?? city.name}';
    final center = 'Centre de ${city.name}';
    String maps(String mode) => Uri.https('www.google.com', '/maps/dir/', {
          'api': '1',
          'origin': toAirport ? '${city.name} centre' : '${city.iata ?? ''} airport ${city.name}',
          'destination': toAirport ? '${city.iata ?? ''} airport ${city.name}' : '${city.name} centre',
          'travelmode': mode,
        }).toString();

    List<TransferStep> build(List<(int, String)> raw) {
      // Pour un départ vers l'aéroport, [start] est l'heure limite d'arrivée.
      final total = raw.last.$1;
      final t0 = toAirport ? start.subtract(Duration(minutes: total)) : start;
      return raw.map((e) => TransferStep(t0.add(Duration(minutes: e.$1)), e.$2)).toList();
    }

    final train = toAirport
        ? [
            (0, 'Départ de l\'hôtel à pied'),
            (10, 'Métro jusqu\'à la gare centrale'),
            (30, 'Train express vers l\'aéroport'),
            (65, 'Arrivée à l\'$airport'),
          ]
        : [
            (0, 'Atterrissage — $airport'),
            (40, 'Bagages récupérés, direction la gare de l\'aéroport'),
            (55, 'Train express vers la gare centrale'),
            (90, 'Correspondance métro'),
            (110, 'Arrivée — $center'),
          ];
    final bus = toAirport
        ? [
            (0, 'Arrêt de bus près de l\'hôtel'),
            (15, 'Navette aéroport (ligne directe)'),
            (75, 'Arrivée à l\'$airport'),
          ]
        : [
            (0, 'Atterrissage — $airport'),
            (40, 'Bagages récupérés, arrêt de la navette'),
            (55, 'Navette aéroport → centre'),
            (115, 'Arrêt principal, marche jusqu\'au centre'),
            (125, 'Arrivée — $center'),
          ];
    final taxi = toAirport
        ? [(0, 'Prise en charge à l\'hôtel'), (45, 'Dépose à l\'$airport')]
        : [
            (0, 'Atterrissage — $airport'),
            (40, 'Bagages récupérés, station de taxis'),
            (85, 'Dépose — $center'),
          ];
    final cars = (travelers / 4).ceil();
    return [
      TransferOption(
        id: 'train',
        mode: TransferMode.train,
        label: 'Train + métro',
        steps: build(train),
        price: _round(13 * ci * travelers),
        mapsUrl: maps('transit'),
      ),
      TransferOption(
        id: 'bus',
        mode: TransferMode.bus,
        label: 'Navette / bus',
        steps: build(bus),
        price: _round(8 * ci * travelers),
        mapsUrl: maps('transit'),
      ),
      TransferOption(
        id: 'taxi',
        mode: TransferMode.taxi,
        label: 'Taxi',
        steps: build(taxi),
        price: _round(55 * ci * cars),
        mapsUrl: maps('driving'),
      ),
    ];
  }

  @override
  Future<List<HotelOption>> searchHotels({
    required Place city,
    required DateTime checkIn,
    required int nights,
    required int travelers,
  }) async {
    await Future.delayed(const Duration(milliseconds: 350));
    final r = _rng([city.name, 'hotels']);
    const prefixes = ['Hôtel', 'Grand Hôtel', 'Résidence', 'Auberge', 'Hostel', 'Boutique Hôtel', 'Hôtel', 'Appart\'hôtel'];
    const names = [
      'du Centre', 'de la Gare', 'Panorama', 'Le Jardin', 'Belle Vue', 'Royal', 'Les Arts',
      'Central Park', 'du Port', 'Lumière', 'Le Marché', 'Riverside', 'Plaza', 'Le Patio',
    ];
    const streets = ['rue Principale', 'avenue de la Gare', 'place du Marché', 'boulevard Central', 'quai du Port'];
    final rooms = (travelers / 2).ceil();
    final checkOut = checkIn.add(Duration(days: nights));
    final list = <HotelOption>[];
    for (var i = 0; i < 14; i++) {
      final prefix = prefixes[r.nextInt(prefixes.length)];
      final isHostel = prefix == 'Hostel' || prefix == 'Auberge';
      final stars = isHostel ? 1 + r.nextInt(2) : 2 + r.nextInt(4);
      final base = (isHostel ? 22 : 35 + stars * 28) * city.costIndex;
      final perRoom = (base * (0.75 + r.nextDouble() * 0.6)).roundToDouble();
      // Auberge : prix par lit ; hôtel : prix par chambre double.
      final price = isHostel ? perRoom * travelers : perRoom * rooms;
      final rating = min(9.8, 5.8 + stars * 0.5 + r.nextDouble() * 1.8);
      final name = '$prefix ${names[(i + r.nextInt(3)) % names.length]}';
      list.add(HotelOption(
        id: 'h${city.name}$i',
        name: name,
        city: city.name,
        stars: stars,
        rating: (rating * 10).roundToDouble() / 10,
        reviews: 40 + r.nextInt(3200),
        pricePerNight: _round(price),
        lat: city.lat + (r.nextDouble() - 0.5) * 0.04,
        lng: city.lng + (r.nextDouble() - 0.5) * 0.06,
        address: '${1 + r.nextInt(120)} ${streets[r.nextInt(streets.length)]}, ${city.name}',
        bookingUrl: Uri.https('www.booking.com', '/searchresults.fr.html', {
          'ss': '$name ${city.name}',
          'checkin': _fmtDate.format(checkIn),
          'checkout': _fmtDate.format(checkOut),
          'group_adults': '$travelers',
          'no_rooms': '$rooms',
          'selected_currency': 'EUR',
        }).toString(),
      ));
    }
    return list;
  }

  @override
  Future<List<Activity>> activities({
    required Place city,
    required List<Interest> interests,
    required int travelers,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final r = _rng([city.name, 'act']);
    final wanted = interests.isEmpty ? Interest.values : interests;
    final curated = _curated[city.name] ?? const <_A>[];
    final out = <Activity>[];
    var i = 0;
    void add(_A a) {
      final price = a.price == 0 ? 0.0 : (a.price * city.costIndex).roundToDouble();
      out.add(Activity(
        id: '${city.name}-${i++}',
        name: a.name,
        city: city.name,
        interest: a.interest,
        pricePerPerson: price,
        durationMin: a.duration,
        lat: city.lat + (r.nextDouble() - 0.5) * 0.06,
        lng: city.lng + (r.nextDouble() - 0.5) * 0.08,
        description: a.description,
        totalPrice: price * travelers,
      ));
    }

    // Catalogue de la ville d'abord, complété par des idées génériques (5 max. par envie).
    for (final a in curated.where((a) => wanted.contains(a.interest))) {
      add(a);
    }
    for (final a in _generic(city.name).where((a) => wanted.contains(a.interest))) {
      if (out.where((o) => o.interest == a.interest).length < 5) add(a);
    }
    // Les activités gratuites sont mises en avant.
    out.sort((a, b) {
      if (a.isFree != b.isFree) return a.isFree ? -1 : 1;
      return a.pricePerPerson.compareTo(b.pricePerPerson);
    });
    return out;
  }

  @override
  List<LocalTransportChoice> localTransportOptions({
    required Place city,
    required int days,
    required int activityCount,
    required int travelers,
  }) {
    final ci = city.costIndex;
    final d = max(1, days);
    final rides = max(2, activityCount * 2);
    final cars = (travelers / 4).ceil();
    final pass = 8 * ci * d * travelers;
    final car = (48 * ci + 18) * d * cars;
    final taxi = 16 * ci * rides * cars;
    return [
      LocalTransportChoice(
        city: city.name,
        mode: LocalTransportMode.publicPass,
        amount: _round(pass),
        detail: 'Pass illimité ${d}j × $travelers pers. (≈ ${(8 * ci).toStringAsFixed(0)} €/jour/pers.)',
      ),
      LocalTransportChoice(
        city: city.name,
        mode: LocalTransportMode.carRental,
        amount: _round(car),
        detail: '$cars voiture${cars > 1 ? 's' : ''} × ${d}j, carburant et parking inclus',
      ),
      LocalTransportChoice(
        city: city.name,
        mode: LocalTransportMode.taxi,
        amount: _round(taxi),
        detail: '≈ $rides courses (2 par activité prévue)',
      ),
    ];
  }

  @override
  IntercityLeg intercityLeg({
    required Place from,
    required Place to,
    required DateTime date,
    required int travelers,
  }) {
    final km = from.distanceTo(to) * 1.25; // distance par le rail
    final pp = (12 + km * 0.11) * ((from.costIndex + to.costIndex) / 2);
    final dep = DateTime(date.year, date.month, date.day, 11, 0);
    final arr = dep.add(Duration(minutes: (km / 140 * 60 + 25).round()));
    return IntercityLeg(
      from: from,
      to: to,
      depart: dep,
      arrive: arr,
      price: _round(pp * travelers),
      bookingUrl: Uri.https('www.thetrainline.com', '/fr', {
        'origin': from.name,
        'destination': to.name,
        'date': _fmtDate.format(date),
      }).toString(),
    );
  }
}

class _A {
  final String name;
  final Interest interest;
  final double price;
  final int duration;
  final String description;
  const _A(this.name, this.interest, this.price, this.duration, this.description);
}

List<_A> _generic(String city) => [
      _A('Visite à pied du centre historique', Interest.culture, 0, 150, 'Free walking tour (pourboire libre) avec un guide local.'),
      _A('Musée principal de $city', Interest.culture, 14, 150, 'Les grandes collections de la ville.'),
      _A('Monuments et lieux de culte du centre', Interest.culture, 0, 90, 'Balade libre entre les principaux monuments.'),
      _A('Visite guidée d\'un site historique', Interest.culture, 22, 120, 'Accès coupe-file et guide.'),
      _A('Parc principal de $city', Interest.nature, 0, 120, 'Pique-nique et promenade.'),
      _A('Randonnée aux environs de $city', Interest.nature, 0, 240, 'Sentier balisé accessible en transports.'),
      _A('Excursion nature à la journée', Interest.nature, 55, 480, 'Excursion organisée avec transport.'),
      _A('Point de vue panoramique au coucher du soleil', Interest.nature, 0, 60, 'Le meilleur panorama de la ville.'),
      _A('Soirée dans le quartier animé', Interest.nightlife, 0, 180, 'Bars et ambiance locale.'),
      _A('Concert ou spectacle', Interest.nightlife, 38, 150, 'Programmation selon les dates.'),
      _A('Bar en rooftop', Interest.nightlife, 18, 120, 'Une consommation incluse.'),
      _A('Marché couvert de $city', Interest.food, 0, 90, 'Produits locaux et dégustations.'),
      _A('Food tour avec un guide', Interest.food, 55, 180, 'Cinq à six arrêts de spécialités locales.'),
      _A('Cours de cuisine locale', Interest.food, 65, 180, 'Préparation et dégustation d\'un repas typique.'),
      _A('Quartier commerçant et boutiques', Interest.shopping, 0, 150, 'Flânerie dans les rues commerçantes.'),
      _A('Marché d\'artisanat', Interest.shopping, 0, 90, 'Souvenirs et créations locales.'),
      _A('Location de vélo à la journée', Interest.sport, 15, 300, 'Pistes cyclables et balade libre.'),
      _A('Activité nautique (kayak, paddle…)', Interest.sport, 35, 120, 'Encadrement et matériel compris.'),
      _A('Piscine ou bains publics', Interest.sport, 8, 120, 'Un moment de détente.'),
    ];

const Map<String, List<_A>> _curated = {
  'Paris': [
    _A('Musée du Louvre', Interest.culture, 22, 210, 'La Joconde et 35 000 œuvres. Gratuit pour les moins de 26 ans (UE).'),
    _A('Musée d\'Orsay', Interest.culture, 16, 180, 'Les impressionnistes dans une ancienne gare.'),
    _A('Cathédrale Notre-Dame', Interest.culture, 0, 60, 'Visite libre et gratuite de la cathédrale restaurée.'),
    _A('Montmartre et le Sacré-Cœur', Interest.culture, 0, 150, 'Balade dans le quartier des artistes.'),
    _A('Tour Eiffel (sommet)', Interest.culture, 36, 150, 'Ascenseur jusqu\'au sommet.'),
    _A('Jardin du Luxembourg', Interest.nature, 0, 90, 'Le jardin préféré des Parisiens.'),
    _A('Croisière sur la Seine', Interest.nightlife, 17, 60, 'Les monuments illuminés depuis le fleuve.'),
    _A('Marché d\'Aligre', Interest.food, 0, 60, 'Marché populaire et halle Beauvau.'),
  ],
  'Tokyo': [
    _A('Sanctuaire Meiji-jingū', Interest.culture, 0, 90, 'Sanctuaire shinto au cœur d\'une forêt.'),
    _A('Temple Sensō-ji (Asakusa)', Interest.culture, 0, 90, 'Le plus ancien temple de Tokyo.'),
    _A('Musée national de Tokyo', Interest.culture, 7, 150, 'Art et archéologie du Japon.'),
    _A('teamLab Planets', Interest.culture, 26, 120, 'Musée d\'art numérique immersif.'),
    _A('Shinjuku Gyoen', Interest.nature, 3, 120, 'Jardin national, magnifique en saison des cerisiers.'),
    _A('Shibuya Sky', Interest.nightlife, 14, 60, 'Vue à 360° sur la ville.'),
    _A('Marché de Tsukiji (extérieur)', Interest.food, 0, 90, 'Street food de la mer au petit matin.'),
    _A('Golden Gai et Omoide Yokocho', Interest.nightlife, 0, 150, 'Ruelles de minuscules bars.'),
  ],
  'Rome': [
    _A('Colisée, Forum et Palatin', Interest.culture, 18, 210, 'Billet combiné pour la Rome antique.'),
    _A('Musées du Vatican et chapelle Sixtine', Interest.culture, 20, 240, 'Gratuit le dernier dimanche du mois.'),
    _A('Panthéon', Interest.culture, 5, 45, 'Le temple antique le mieux conservé.'),
    _A('Fontaine de Trevi et place d\'Espagne', Interest.culture, 0, 90, 'Balade libre dans le centre.'),
    _A('Villa Borghèse', Interest.nature, 0, 120, 'Grand parc et belvédère du Pincio.'),
    _A('Trastevere en soirée', Interest.nightlife, 0, 180, 'Le quartier le plus vivant de Rome.'),
    _A('Marché de Campo de\' Fiori', Interest.food, 0, 60, 'Produits frais et spécialités.'),
  ],
  'New York': [
    _A('Metropolitan Museum of Art', Interest.culture, 28, 210, 'L\'un des plus grands musées du monde.'),
    _A('Statue de la Liberté (ferry de Staten Island)', Interest.culture, 0, 90, 'Le ferry gratuit passe devant la statue.'),
    _A('High Line et Chelsea Market', Interest.nature, 0, 120, 'Promenade sur une ancienne voie ferrée.'),
    _A('Central Park', Interest.nature, 0, 150, 'Le grand poumon de Manhattan.'),
    _A('Pont de Brooklyn à pied', Interest.culture, 0, 60, 'Vue sur la skyline.'),
    _A('Comédie musicale à Broadway', Interest.nightlife, 95, 165, 'Billets à prix réduit au guichet TKTS.'),
    _A('Top of the Rock', Interest.nightlife, 40, 60, 'Vue sur l\'Empire State Building.'),
  ],
  'Barcelone': [
    _A('Sagrada Família', Interest.culture, 26, 120, 'Le chef-d\'œuvre de Gaudí.'),
    _A('Park Güell', Interest.nature, 10, 120, 'Mosaïques et vue sur la ville.'),
    _A('Quartier gothique', Interest.culture, 0, 120, 'Ruelles médiévales.'),
    _A('Marché de la Boqueria', Interest.food, 0, 60, 'Le marché le plus célèbre de la ville.'),
    _A('Plage de la Barceloneta', Interest.nature, 0, 180, 'Plage urbaine.'),
    _A('Bunkers del Carmel', Interest.nature, 0, 90, 'Le plus beau panorama, gratuit.'),
  ],
  'Lisbonne': [
    _A('Monastère des Hiéronymites', Interest.culture, 18, 120, 'Chef-d\'œuvre manuélin à Belém.'),
    _A('Tram 28 et Alfama', Interest.culture, 3, 120, 'Le tram historique à travers les collines.'),
    _A('Miradouro da Senhora do Monte', Interest.nature, 0, 45, 'Vue panoramique sur Lisbonne.'),
    _A('Time Out Market', Interest.food, 0, 90, 'Les meilleures adresses réunies.'),
    _A('Soirée fado dans l\'Alfama', Interest.nightlife, 30, 150, 'Chant traditionnel portugais.'),
  ],
  'Londres': [
    _A('British Museum', Interest.culture, 0, 180, 'Gratuit : la pierre de Rosette et bien plus.'),
    _A('National Gallery', Interest.culture, 0, 150, 'Gratuit : grands maîtres de la peinture.'),
    _A('Tour de Londres', Interest.culture, 40, 180, 'Les joyaux de la Couronne.'),
    _A('Hyde Park et Kensington Gardens', Interest.nature, 0, 120, 'Grands parcs royaux.'),
    _A('Borough Market', Interest.food, 0, 90, 'Le marché gourmand de Londres.'),
    _A('Comédie musicale dans le West End', Interest.nightlife, 60, 165, 'Billets de dernière minute à Leicester Square.'),
  ],
};

/// Source qui interroge le serveur (voir dossier `server/`), avec repli
/// sur les données simulées en cas d'erreur.
class ApiTravelData implements TravelDataSource {
  final String baseUrl;
  final http.Client _client;
  final SimulatedTravelData _fallback = SimulatedTravelData();
  bool _lastCallSimulated = false;

  ApiTravelData(this.baseUrl, [http.Client? client]) : _client = client ?? http.Client();

  @override
  bool get isSimulated => _lastCallSimulated;

  Future<List<dynamic>?> _get(String path, Map<String, String> params) async {
    try {
      final uri = Uri.parse('$baseUrl$path').replace(queryParameters: params);
      final res = await _client.get(uri).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body);
      return body is List ? body : (body['results'] as List?);
    } catch (_) {
      return null;
    }
  }

  static final _f = DateFormat('yyyy-MM-dd');

  @override
  Future<List<FlightOption>> searchFlights({
    required Place origin,
    required Place destination,
    required DateTime departDate,
    required DateTime returnDate,
    required int travelers,
  }) async {
    final data = await _get('/flights', {
      'origin': origin.iata ?? origin.name,
      'destination': destination.iata ?? destination.name,
      'date': _f.format(departDate),
      'return': _f.format(returnDate),
      'adults': '$travelers',
    });
    if (data == null || data.isEmpty) {
      _lastCallSimulated = true;
      return _fallback.searchFlights(
          origin: origin, destination: destination, departDate: departDate, returnDate: returnDate, travelers: travelers);
    }
    _lastCallSimulated = false;
    return data.map((e) => FlightOption.fromJson(e)).toList();
  }

  @override
  Future<List<HotelOption>> searchHotels({
    required Place city,
    required DateTime checkIn,
    required int nights,
    required int travelers,
  }) async {
    final data = await _get('/hotels', {
      'city': city.name,
      'checkIn': _f.format(checkIn),
      'checkOut': _f.format(checkIn.add(Duration(days: nights))),
      'adults': '$travelers',
    });
    if (data == null || data.isEmpty) {
      _lastCallSimulated = true;
      return _fallback.searchHotels(city: city, checkIn: checkIn, nights: nights, travelers: travelers);
    }
    _lastCallSimulated = false;
    return data.map((e) => HotelOption.fromJson(e)).toList();
  }

  @override
  Future<List<TransferOption>> airportTransfers({
    required Place city,
    required DateTime start,
    required bool toAirport,
    required int travelers,
  }) async {
    final data = await _get('/transfers', {
      'city': city.name,
      'airport': city.iata ?? '',
      'time': start.toIso8601String(),
      'direction': toAirport ? 'toAirport' : 'fromAirport',
      'travelers': '$travelers',
    });
    if (data == null || data.isEmpty) {
      return _fallback.airportTransfers(city: city, start: start, toAirport: toAirport, travelers: travelers);
    }
    return data.map((e) => TransferOption.fromJson(e)).toList();
  }

  @override
  Future<List<Activity>> activities({
    required Place city,
    required List<Interest> interests,
    required int travelers,
  }) =>
      _fallback.activities(city: city, interests: interests, travelers: travelers);

  @override
  List<LocalTransportChoice> localTransportOptions({
    required Place city,
    required int days,
    required int activityCount,
    required int travelers,
  }) =>
      _fallback.localTransportOptions(city: city, days: days, activityCount: activityCount, travelers: travelers);

  @override
  IntercityLeg intercityLeg({
    required Place from,
    required Place to,
    required DateTime date,
    required int travelers,
  }) =>
      _fallback.intercityLeg(from: from, to: to, date: date, travelers: travelers);
}

TravelDataSource createDataSource() =>
    kApiBaseUrl.isEmpty ? SimulatedTravelData() : ApiTravelData(kApiBaseUrl);
