// Modèles de données de l'application.
// Tous les montants sont stockés en euros.

import 'dart:math';

DateTime? _dt(dynamic v) => v == null ? null : DateTime.parse(v as String);
double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;

/// Ville / lieu géolocalisé avec ses informations de coût.
class Place {
  final String name;
  final String country;
  final String currency; // code ISO 4217, ex. JPY
  final String? iata; // code aéroport principal
  final double lat;
  final double lng;

  /// Indice de coût de la vie (1.0 = moyenne Europe de l'Ouest).
  final double costIndex;

  const Place({
    required this.name,
    required this.country,
    required this.currency,
    required this.lat,
    required this.lng,
    this.iata,
    this.costIndex = 1.0,
  });

  /// Position approximative de l'aéroport (décalée du centre-ville).
  double get airportLat => lat + 0.12;
  double get airportLng => lng + 0.15;

  /// Position approximative de la gare principale.
  double get stationLat => lat + 0.006;
  double get stationLng => lng - 0.008;

  Map<String, dynamic> toJson() => {
        'name': name,
        'country': country,
        'currency': currency,
        'iata': iata,
        'lat': lat,
        'lng': lng,
        'costIndex': costIndex,
      };

  factory Place.fromJson(Map<String, dynamic> j) => Place(
        name: j['name'],
        country: j['country'] ?? '',
        currency: j['currency'] ?? 'EUR',
        iata: j['iata'],
        lat: _d(j['lat']),
        lng: _d(j['lng']),
        costIndex: j['costIndex'] == null ? 1.0 : _d(j['costIndex']),
      );

  /// Distance en km (formule de haversine).
  double distanceTo(Place o) {
    const r = 6371.0;
    final dLat = _rad(o.lat - lat);
    final dLng = _rad(o.lng - lng);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat)) * cos(_rad(o.lat)) * sin(dLng / 2) * sin(dLng / 2);
    return 2 * r * asin(sqrt(a));
  }

  static double _rad(double d) => d * pi / 180;
}

/// Moyen de transport pour se rendre à destination.
enum TravelMode { plane, train, bus, car }

extension TravelModeX on TravelMode {
  String get label => switch (this) {
        TravelMode.plane => 'Avion',
        TravelMode.train => 'Train',
        TravelMode.bus => 'Car',
        TravelMode.car => 'Voiture',
      };

  /// Nom du trajet (« le vol », « le train »…).
  String get tripNoun => switch (this) {
        TravelMode.plane => 'vol',
        TravelMode.train => 'train',
        TravelMode.bus => 'car',
        TravelMode.car => 'trajet',
      };

  /// Lieu d'arrivée en ville.
  String get hubName => switch (this) {
        TravelMode.plane => 'l\'aéroport',
        TravelMode.train => 'la gare',
        TravelMode.bus => 'la gare routière',
        TravelMode.car => 'votre logement',
      };

  bool get needsTransfer => this != TravelMode.car;
}

/// Option de transport aller-retour (vol, train, car ou voiture).
class FlightOption {
  final String id;
  final TravelMode mode;
  final String airline;
  final String flightNumber;
  final String fromCode;
  final String toCode;
  final DateTime outDepart;
  final DateTime outArrive;
  final List<String> outStops;
  final DateTime? retDepart;
  final DateTime? retArrive;
  final List<String> retStops;
  final double pricePerPerson;
  final double totalPrice;
  final String bookingUrl;

  FlightOption({
    required this.id,
    this.mode = TravelMode.plane,
    required this.airline,
    required this.flightNumber,
    required this.fromCode,
    required this.toCode,
    required this.outDepart,
    required this.outArrive,
    required this.outStops,
    this.retDepart,
    this.retArrive,
    this.retStops = const [],
    required this.pricePerPerson,
    required this.totalPrice,
    required this.bookingUrl,
  });

  Duration get outDuration => outArrive.difference(outDepart);
  Duration? get retDuration =>
      retDepart != null && retArrive != null ? retArrive!.difference(retDepart!) : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'mode': mode.name,
        'airline': airline,
        'flightNumber': flightNumber,
        'fromCode': fromCode,
        'toCode': toCode,
        'outDepart': outDepart.toIso8601String(),
        'outArrive': outArrive.toIso8601String(),
        'outStops': outStops,
        'retDepart': retDepart?.toIso8601String(),
        'retArrive': retArrive?.toIso8601String(),
        'retStops': retStops,
        'pricePerPerson': pricePerPerson,
        'totalPrice': totalPrice,
        'bookingUrl': bookingUrl,
      };

  factory FlightOption.fromJson(Map<String, dynamic> j) => FlightOption(
        id: j['id'].toString(),
        mode: TravelMode.values.asNameMap()[j['mode']] ?? TravelMode.plane,
        airline: j['airline'] ?? '',
        flightNumber: j['flightNumber'] ?? '',
        fromCode: j['fromCode'] ?? '',
        toCode: j['toCode'] ?? '',
        outDepart: DateTime.parse(j['outDepart']),
        outArrive: DateTime.parse(j['outArrive']),
        outStops: List<String>.from(j['outStops'] ?? const []),
        retDepart: _dt(j['retDepart']),
        retArrive: _dt(j['retArrive']),
        retStops: List<String>.from(j['retStops'] ?? const []),
        pricePerPerson: _d(j['pricePerPerson']),
        totalPrice: _d(j['totalPrice']),
        bookingUrl: j['bookingUrl'] ?? '',
      );
}

class TransferStep {
  final DateTime time;
  final String description;
  TransferStep(this.time, this.description);

  Map<String, dynamic> toJson() => {'time': time.toIso8601String(), 'description': description};
  factory TransferStep.fromJson(Map<String, dynamic> j) =>
      TransferStep(DateTime.parse(j['time']), j['description']);
}

enum TransferMode { train, bus, taxi, walk }

extension TransferModeX on TransferMode {
  String get label => switch (this) {
        TransferMode.train => 'Train',
        TransferMode.bus => 'Bus',
        TransferMode.taxi => 'Taxi',
        TransferMode.walk => 'À pied',
      };
}

/// Trajet aéroport ↔ centre-ville.
class TransferOption {
  final String id;
  final TransferMode mode;
  final String label;
  final List<TransferStep> steps;
  final double price;
  final String mapsUrl;

  TransferOption({
    required this.id,
    required this.mode,
    required this.label,
    required this.steps,
    required this.price,
    required this.mapsUrl,
  });

  DateTime get start => steps.first.time;
  DateTime get end => steps.last.time;
  Duration get duration => end.difference(start);

  Map<String, dynamic> toJson() => {
        'id': id,
        'mode': mode.name,
        'label': label,
        'steps': steps.map((s) => s.toJson()).toList(),
        'price': price,
        'mapsUrl': mapsUrl,
      };

  factory TransferOption.fromJson(Map<String, dynamic> j) => TransferOption(
        id: j['id'],
        mode: TransferMode.values.byName(j['mode']),
        label: j['label'],
        steps: (j['steps'] as List).map((e) => TransferStep.fromJson(e)).toList(),
        price: _d(j['price']),
        mapsUrl: j['mapsUrl'] ?? '',
      );
}

class HotelOption {
  final String id;
  final String name;
  final String city;
  final int stars;
  final double rating; // sur 10
  final int reviews;
  final double pricePerNight; // pour l'ensemble des chambres nécessaires
  final double lat;
  final double lng;
  final String address;
  final String bookingUrl;

  HotelOption({
    required this.id,
    required this.name,
    required this.city,
    required this.stars,
    required this.rating,
    required this.reviews,
    required this.pricePerNight,
    required this.lat,
    required this.lng,
    required this.address,
    required this.bookingUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'city': city,
        'stars': stars,
        'rating': rating,
        'reviews': reviews,
        'pricePerNight': pricePerNight,
        'lat': lat,
        'lng': lng,
        'address': address,
        'bookingUrl': bookingUrl,
      };

  factory HotelOption.fromJson(Map<String, dynamic> j) => HotelOption(
        id: j['id'].toString(),
        name: j['name'],
        city: j['city'] ?? '',
        stars: (j['stars'] as num?)?.toInt() ?? 0,
        rating: _d(j['rating']),
        reviews: (j['reviews'] as num?)?.toInt() ?? 0,
        pricePerNight: _d(j['pricePerNight']),
        lat: _d(j['lat']),
        lng: _d(j['lng']),
        address: j['address'] ?? '',
        bookingUrl: j['bookingUrl'] ?? '',
      );
}

enum HotelPriority { cheapest, comfort }

enum PriceRange { any, under80, from80to150, over150 }

extension PriceRangeX on PriceRange {
  String get label => switch (this) {
        PriceRange.any => 'Tous les prix',
        PriceRange.under80 => 'Moins de 80 €',
        PriceRange.from80to150 => '80 à 150 €',
        PriceRange.over150 => 'Plus de 150 €',
      };

  bool accepts(double perNight) => switch (this) {
        PriceRange.any => true,
        PriceRange.under80 => perNight < 80,
        PriceRange.from80to150 => perNight >= 80 && perNight <= 150,
        PriceRange.over150 => perNight > 150,
      };
}

/// Séjour dans une ville (une ou plusieurs selon le choix de logement).
class CityStay {
  Place place;
  int nights;
  HotelPriority priority;
  PriceRange priceRange;
  HotelOption? hotel;

  /// L'utilisateur a réservé son hôtel avant d'utiliser l'application.
  bool alreadyBooked;

  CityStay({
    required this.place,
    required this.nights,
    this.priority = HotelPriority.cheapest,
    this.priceRange = PriceRange.any,
    this.hotel,
    this.alreadyBooked = false,
  });

  double get hotelCost => (hotel?.pricePerNight ?? 0) * nights;

  Map<String, dynamic> toJson() => {
        'place': place.toJson(),
        'nights': nights,
        'priority': priority.name,
        'priceRange': priceRange.name,
        'hotel': hotel?.toJson(),
        'alreadyBooked': alreadyBooked,
      };

  factory CityStay.fromJson(Map<String, dynamic> j) => CityStay(
        place: Place.fromJson(j['place']),
        nights: j['nights'],
        priority: HotelPriority.values.byName(j['priority'] ?? 'cheapest'),
        priceRange: PriceRange.values.byName(j['priceRange'] ?? 'any'),
        hotel: j['hotel'] == null ? null : HotelOption.fromJson(j['hotel']),
        alreadyBooked: j['alreadyBooked'] ?? false,
      );
}

enum MealProfile { light, big, gourmet }

extension MealProfileX on MealProfile {
  String get label => switch (this) {
        MealProfile.light => 'Petit mangeur',
        MealProfile.big => 'Gros mangeur',
        MealProfile.gourmet => 'Gourmet',
      };

  String get description => switch (this) {
        MealProfile.light => 'Boulangeries, street food, supermarché, un repas simple par jour',
        MealProfile.big => 'Trois vrais repas par jour dans des restaurants abordables',
        MealProfile.gourmet => 'Bonnes tables, spécialités locales, un restaurant réputé de temps en temps',
      };

  /// Coût par personne et par jour pour un indice de coût de 1.0.
  double get baseDailyCost => switch (this) {
        MealProfile.light => 25,
        MealProfile.big => 45,
        MealProfile.gourmet => 85,
      };

  MealProfile? get lower => switch (this) {
        MealProfile.light => null,
        MealProfile.big => MealProfile.light,
        MealProfile.gourmet => MealProfile.big,
      };
}

enum Interest { culture, nature, nightlife, food, shopping, sport }

extension InterestX on Interest {
  String get label => switch (this) {
        Interest.culture => 'Culture',
        Interest.nature => 'Nature',
        Interest.nightlife => 'Sorties',
        Interest.food => 'Gastronomie',
        Interest.shopping => 'Shopping',
        Interest.sport => 'Sport',
      };
}

class Activity {
  final String id;
  final String name;
  final String city;
  final Interest interest;
  final double pricePerPerson;
  final int durationMin;
  final double lat;
  final double lng;
  final String description;
  final double totalPrice; // prix × voyageurs
  DateTime? scheduledAt;

  Activity({
    required this.id,
    required this.name,
    required this.city,
    required this.interest,
    required this.pricePerPerson,
    required this.durationMin,
    required this.lat,
    required this.lng,
    required this.description,
    required this.totalPrice,
    this.scheduledAt,
  });

  bool get isFree => pricePerPerson == 0;

  Activity copyWith({DateTime? scheduledAt}) => Activity(
        id: id,
        name: name,
        city: city,
        interest: interest,
        pricePerPerson: pricePerPerson,
        durationMin: durationMin,
        lat: lat,
        lng: lng,
        description: description,
        totalPrice: totalPrice,
        scheduledAt: scheduledAt ?? this.scheduledAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'city': city,
        'interest': interest.name,
        'pricePerPerson': pricePerPerson,
        'durationMin': durationMin,
        'lat': lat,
        'lng': lng,
        'description': description,
        'totalPrice': totalPrice,
        'scheduledAt': scheduledAt?.toIso8601String(),
      };

  factory Activity.fromJson(Map<String, dynamic> j) => Activity(
        id: j['id'],
        name: j['name'],
        city: j['city'],
        interest: Interest.values.byName(j['interest']),
        pricePerPerson: _d(j['pricePerPerson']),
        durationMin: j['durationMin'] ?? 120,
        lat: _d(j['lat']),
        lng: _d(j['lng']),
        description: j['description'] ?? '',
        totalPrice: _d(j['totalPrice']),
        scheduledAt: _dt(j['scheduledAt']),
      );
}

enum LocalTransportMode { publicPass, carRental, taxi, ownCar }

extension LocalTransportModeX on LocalTransportMode {
  String get label => switch (this) {
        LocalTransportMode.publicPass => 'Transports en commun / pass',
        LocalTransportMode.carRental => 'Location de voiture',
        LocalTransportMode.taxi => 'Taxi / VTC',
        LocalTransportMode.ownCar => 'Votre voiture',
      };
}

/// Choix de transport sur place pour une ville.
class LocalTransportChoice {
  final String city;
  final LocalTransportMode mode;
  final double amount;
  final String detail;

  LocalTransportChoice({
    required this.city,
    required this.mode,
    required this.amount,
    required this.detail,
  });

  Map<String, dynamic> toJson() =>
      {'city': city, 'mode': mode.name, 'amount': amount, 'detail': detail};

  factory LocalTransportChoice.fromJson(Map<String, dynamic> j) => LocalTransportChoice(
        city: j['city'],
        mode: LocalTransportMode.values.byName(j['mode']),
        amount: _d(j['amount']),
        detail: j['detail'] ?? '',
      );
}

/// Trajet en train entre deux villes.
class IntercityLeg {
  final Place from;
  final Place to;
  final DateTime depart;
  final DateTime arrive;
  final double price;
  final String bookingUrl;

  IntercityLeg({
    required this.from,
    required this.to,
    required this.depart,
    required this.arrive,
    required this.price,
    required this.bookingUrl,
  });

  Map<String, dynamic> toJson() => {
        'from': from.toJson(),
        'to': to.toJson(),
        'depart': depart.toIso8601String(),
        'arrive': arrive.toIso8601String(),
        'price': price,
        'bookingUrl': bookingUrl,
      };

  factory IntercityLeg.fromJson(Map<String, dynamic> j) => IntercityLeg(
        from: Place.fromJson(j['from']),
        to: Place.fromJson(j['to']),
        depart: DateTime.parse(j['depart']),
        arrive: DateTime.parse(j['arrive']),
        price: _d(j['price']),
        bookingUrl: j['bookingUrl'] ?? '',
      );
}

/// Catégories du budget prévisionnel.
enum BudgetCategory { flight, transfer, hotel, meals, activities, localTransport, intercity }

extension BudgetCategoryX on BudgetCategory {
  String get label => switch (this) {
        BudgetCategory.flight => 'Transport aller-retour',
        BudgetCategory.transfer => 'Trajets d\'arrivée et de départ',
        BudgetCategory.hotel => 'Logement',
        BudgetCategory.meals => 'Repas',
        BudgetCategory.activities => 'Activités',
        BudgetCategory.localTransport => 'Transports sur place',
        BudgetCategory.intercity => 'Trains entre villes',
      };
}

class BudgetLine {
  final BudgetCategory category;
  final String label;
  final double amount;
  BudgetLine(this.category, this.label, this.amount);
}

/// Catégories des dépenses réelles pendant le voyage.
enum ExpenseCategory { meals, groceries, transport, activities, lodging, other }

extension ExpenseCategoryX on ExpenseCategory {
  String get label => switch (this) {
        ExpenseCategory.meals => 'Repas',
        ExpenseCategory.groceries => 'Courses',
        ExpenseCategory.transport => 'Transport',
        ExpenseCategory.activities => 'Activités',
        ExpenseCategory.lodging => 'Logement',
        ExpenseCategory.other => 'Autre',
      };

  /// Montants préréglés proposés à la saisie rapide (en devise locale ≈ euros × indice).
  List<double> get presets => switch (this) {
        ExpenseCategory.meals => [10, 15, 25, 40],
        ExpenseCategory.groceries => [5, 10, 20, 40],
        ExpenseCategory.transport => [2, 5, 10, 25],
        ExpenseCategory.activities => [10, 20, 35, 60],
        ExpenseCategory.lodging => [30, 60, 100, 150],
        ExpenseCategory.other => [5, 10, 20, 50],
      };
}

class Expense {
  final String id;
  final ExpenseCategory category;
  final double amountEur;
  final double originalAmount;
  final String currency;
  final String note;
  final DateTime date;

  Expense({
    required this.id,
    required this.category,
    required this.amountEur,
    required this.originalAmount,
    required this.currency,
    required this.note,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category.name,
        'amountEur': amountEur,
        'originalAmount': originalAmount,
        'currency': currency,
        'note': note,
        'date': date.toIso8601String(),
      };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'],
        category: ExpenseCategory.values.byName(j['category']),
        amountEur: _d(j['amountEur']),
        originalAmount: _d(j['originalAmount']),
        currency: j['currency'] ?? 'EUR',
        note: j['note'] ?? '',
        date: DateTime.parse(j['date']),
      );
}

/// Un voyage (brouillon pendant la planification, puis enregistré).
class Trip {
  String id;
  String name;
  Place? origin;
  Place? destination;
  DateTime startDate;
  DateTime endDate;
  int travelers;
  double budget;

  /// false : l'utilisateur planifie sans budget de départ.
  bool hasBudget;
  TravelMode travelMode;

  FlightOption? flight;
  TransferOption? arrivalTransfer;
  TransferOption? departureTransfer;
  bool multiCity;
  List<CityStay> stays;
  MealProfile? mealProfile;
  List<Interest> interests;
  List<Activity> activities;
  List<LocalTransportChoice> localTransport;
  List<IntercityLeg> intercity;

  List<Expense> expenses;
  Set<String> notifiedThresholds;
  DateTime createdAt;

  Trip({
    required this.id,
    this.name = '',
    this.origin,
    this.destination,
    required this.startDate,
    required this.endDate,
    this.travelers = 1,
    this.budget = 0,
    this.hasBudget = true,
    this.travelMode = TravelMode.plane,
    this.flight,
    this.arrivalTransfer,
    this.departureTransfer,
    this.multiCity = false,
    List<CityStay>? stays,
    this.mealProfile,
    List<Interest>? interests,
    List<Activity>? activities,
    List<LocalTransportChoice>? localTransport,
    List<IntercityLeg>? intercity,
    List<Expense>? expenses,
    Set<String>? notifiedThresholds,
    DateTime? createdAt,
  })  : stays = stays ?? [],
        interests = interests ?? [],
        activities = activities ?? [],
        localTransport = localTransport ?? [],
        intercity = intercity ?? [],
        expenses = expenses ?? [],
        notifiedThresholds = notifiedThresholds ?? {},
        createdAt = createdAt ?? DateTime.now();

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  int get nights => dateOnly(endDate).difference(dateOnly(startDate)).inDays;

  /// Nombre de jours du séjour (jour d'arrivée et jour de départ inclus).
  int get days => nights + 1;

  /// Coût journalier des repas pour tout le groupe.
  double mealDailyCost(MealProfile p) =>
      p.baseDailyCost * (destination?.costIndex ?? 1) * travelers;

  double mealCost(MealProfile p) => mealDailyCost(p) * days;

  /// Date d'arrivée dans chaque ville (index dans [stays]).
  DateTime stayStart(int i) {
    var d = dateOnly(startDate);
    for (var k = 0; k < i; k++) {
      d = d.add(Duration(days: stays[k].nights));
    }
    return d;
  }

  /// Toutes les lignes du budget prévisionnel, calculées à partir des choix
  /// actuels : changer un choix remplace automatiquement l'ancien prix.
  List<BudgetLine> get budgetLines {
    final lines = <BudgetLine>[];
    if (flight != null) {
      lines.add(BudgetLine(BudgetCategory.flight,
          '${flight!.mode.label} · ${flight!.airline} · ${flight!.fromCode} – ${flight!.toCode}', flight!.totalPrice));
    }
    if (arrivalTransfer != null) {
      lines.add(BudgetLine(BudgetCategory.transfer, 'Arrivée → ville (${arrivalTransfer!.label})',
          arrivalTransfer!.price));
    }
    if (departureTransfer != null) {
      lines.add(BudgetLine(BudgetCategory.transfer, 'Ville → départ (${departureTransfer!.label})',
          departureTransfer!.price));
    }
    for (final s in stays) {
      if (s.hotel != null) {
        lines.add(BudgetLine(BudgetCategory.hotel,
            '${s.hotel!.name} (${s.place.name}, ${s.nights} nuit${s.nights > 1 ? 's' : ''}'
            '${s.alreadyBooked ? ', déjà réservé' : ''})', s.hotelCost));
      }
    }
    if (mealProfile != null) {
      lines.add(BudgetLine(BudgetCategory.meals, '${mealProfile!.label} × $days jours', mealCost(mealProfile!)));
    }
    for (final a in activities) {
      lines.add(BudgetLine(BudgetCategory.activities, a.name, a.totalPrice));
    }
    for (final t in localTransport) {
      lines.add(BudgetLine(BudgetCategory.localTransport, '${t.mode.label} (${t.city})', t.amount));
    }
    for (final l in intercity) {
      lines.add(BudgetLine(BudgetCategory.intercity, 'Train ${l.from.name} → ${l.to.name}', l.price));
    }
    return lines;
  }

  double get plannedTotal => budgetLines.fold(0.0, (a, l) => a + l.amount);

  /// Budget de référence : le budget saisi, ou le total prévu si l'utilisateur n'en a pas fixé.
  double get effectiveBudget => hasBudget ? budget : plannedTotal;
  double get plannedRemaining => effectiveBudget - plannedTotal;

  double plannedFor(BudgetCategory c) =>
      budgetLines.where((l) => l.category == c).fold(0.0, (a, l) => a + l.amount);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'origin': origin?.toJson(),
        'destination': destination?.toJson(),
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'travelers': travelers,
        'budget': budget,
        'hasBudget': hasBudget,
        'travelMode': travelMode.name,
        'flight': flight?.toJson(),
        'arrivalTransfer': arrivalTransfer?.toJson(),
        'departureTransfer': departureTransfer?.toJson(),
        'multiCity': multiCity,
        'stays': stays.map((s) => s.toJson()).toList(),
        'mealProfile': mealProfile?.name,
        'interests': interests.map((i) => i.name).toList(),
        'activities': activities.map((a) => a.toJson()).toList(),
        'localTransport': localTransport.map((t) => t.toJson()).toList(),
        'intercity': intercity.map((l) => l.toJson()).toList(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'notifiedThresholds': notifiedThresholds.toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Trip.fromJson(Map<String, dynamic> j) => Trip(
        id: j['id'],
        name: j['name'] ?? '',
        origin: j['origin'] == null ? null : Place.fromJson(j['origin']),
        destination: j['destination'] == null ? null : Place.fromJson(j['destination']),
        startDate: DateTime.parse(j['startDate']),
        endDate: DateTime.parse(j['endDate']),
        travelers: j['travelers'] ?? 1,
        budget: _d(j['budget']),
        hasBudget: j['hasBudget'] ?? true,
        travelMode: TravelMode.values.asNameMap()[j['travelMode']] ?? TravelMode.plane,
        flight: j['flight'] == null ? null : FlightOption.fromJson(j['flight']),
        arrivalTransfer:
            j['arrivalTransfer'] == null ? null : TransferOption.fromJson(j['arrivalTransfer']),
        departureTransfer:
            j['departureTransfer'] == null ? null : TransferOption.fromJson(j['departureTransfer']),
        multiCity: j['multiCity'] ?? false,
        stays: (j['stays'] as List? ?? []).map((e) => CityStay.fromJson(e)).toList(),
        mealProfile: j['mealProfile'] == null ? null : MealProfile.values.byName(j['mealProfile']),
        interests: (j['interests'] as List? ?? []).map((e) => Interest.values.byName(e)).toList(),
        activities: (j['activities'] as List? ?? []).map((e) => Activity.fromJson(e)).toList(),
        localTransport:
            (j['localTransport'] as List? ?? []).map((e) => LocalTransportChoice.fromJson(e)).toList(),
        intercity: (j['intercity'] as List? ?? []).map((e) => IntercityLeg.fromJson(e)).toList(),
        expenses: (j['expenses'] as List? ?? []).map((e) => Expense.fromJson(e)).toList(),
        notifiedThresholds: Set<String>.from(j['notifiedThresholds'] ?? const []),
        createdAt: _dt(j['createdAt']),
      );

  Trip copy() => Trip.fromJson(toJson());
}
