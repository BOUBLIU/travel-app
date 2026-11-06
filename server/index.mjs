// Petit serveur d'API pour Budget Voyage.
// Il appelle SerpApi (Google Flights / Google Hotels) côté serveur pour ne pas
// exposer la clé dans l'application, et renvoie le format JSON attendu par l'app.
//
//   SERPAPI_KEY=xxxx node server/index.mjs        (Node 18+, aucune dépendance)
//
// Puis construire l'app avec : --dart-define=API_BASE_URL=https://votre-serveur
// Points d'accès : GET /flights, GET /hotels. Toute erreur → l'app bascule sur
// ses données simulées.

import http from 'node:http';

const KEY = process.env.SERPAPI_KEY;
const PORT = Number(process.env.PORT || 8080);

async function serp(params) {
  const url = new URL('https://serpapi.com/search.json');
  for (const [k, v] of Object.entries({ ...params, api_key: KEY, hl: 'fr', currency: 'EUR' })) {
    if (v !== undefined && v !== '') url.searchParams.set(k, String(v));
  }
  const res = await fetch(url);
  if (!res.ok) throw new Error(`SerpApi ${res.status}`);
  return res.json();
}

const iso = (s) => (s ? new Date(s.replace(' ', 'T')).toISOString() : null);

async function flights(q) {
  const adults = Number(q.get('adults') || 1);
  const data = await serp({
    engine: 'google_flights',
    departure_id: q.get('origin'),
    arrival_id: q.get('destination'),
    outbound_date: q.get('date'),
    return_date: q.get('return'),
    adults,
    type: 1, // aller-retour
  });
  const all = [...(data.best_flights || []), ...(data.other_flights || [])];
  return all.slice(0, 15).map((f, i) => {
    const legs = f.flights || [];
    const first = legs[0] || {};
    const last = legs[legs.length - 1] || {};
    const total = Number(f.price || 0); // prix aller-retour pour tous les passagers
    return {
      id: `serp${i}`,
      airline: first.airline || '',
      flightNumber: first.flight_number || '',
      fromCode: first.departure_airport?.id || q.get('origin'),
      toCode: last.arrival_airport?.id || q.get('destination'),
      outDepart: iso(first.departure_airport?.time),
      outArrive: iso(last.arrival_airport?.time),
      outStops: (f.layovers || []).map((l) => l.name),
      retDepart: null, // nécessite un 2e appel (departure_token) : affiché sur le site
      retArrive: null,
      retStops: [],
      pricePerPerson: Math.round(total / adults),
      totalPrice: total,
      bookingUrl: data.search_metadata?.google_flights_url || 'https://www.google.com/travel/flights',
    };
  });
}

async function hotels(q) {
  const adults = Number(q.get('adults') || 2);
  const city = q.get('city');
  const data = await serp({
    engine: 'google_hotels',
    q: `hôtels ${city}`,
    check_in_date: q.get('checkIn'),
    check_out_date: q.get('checkOut'),
    adults,
  });
  const rooms = Math.ceil(adults / 2);
  return (data.properties || [])
    .filter((p) => p.rate_per_night?.extracted_lowest && p.gps_coordinates)
    .slice(0, 20)
    .map((p, i) => ({
      id: `serp${i}`,
      name: p.name,
      city,
      stars: Number(p.extracted_hotel_class || 0),
      rating: Math.round((p.overall_rating || 0) * 20) / 10, // /5 → /10
      reviews: p.reviews || 0,
      pricePerNight: p.rate_per_night.extracted_lowest * rooms,
      lat: p.gps_coordinates.latitude,
      lng: p.gps_coordinates.longitude,
      address: p.description || city,
      bookingUrl: p.link || `https://www.google.com/travel/hotels?q=${encodeURIComponent(p.name)}`,
    }));
}

const routes = { '/flights': flights, '/hotels': hotels };

http
  .createServer(async (req, res) => {
    const url = new URL(req.url, 'http://localhost');
    const handler = routes[url.pathname];
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    if (!handler) return res.writeHead(404).end('[]');
    if (!KEY) return res.writeHead(503).end(JSON.stringify({ error: 'SERPAPI_KEY manquante' }));
    try {
      res.end(JSON.stringify(await handler(url.searchParams)));
    } catch (e) {
      console.error(e);
      res.writeHead(502).end(JSON.stringify({ error: String(e.message || e) }));
    }
  })
  .listen(PORT, () => console.log(`Budget Voyage API sur :${PORT}`));
