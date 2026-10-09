// Mengambil geometri rute asli Surabaya dari server demo OSRM, lalu menuliskannya
// sebagai data mock di lib/data/route_geometry.dart. Jalankan sekali saja:
//   node tool/gen_routes.mjs
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const OSRM = 'https://router.project-osrm.org/route/v1/driving';
const origin = { lat: -7.2893, lng: 112.8003 }; // Jalan Keputih
const places = [
  { id: 'tp', lat: -7.2622, lng: 112.7391 },
  { id: 'gubeng', lat: -7.2653, lng: 112.752 },
  { id: 'purabaya', lat: -7.3508, lng: 112.7247 },
  { id: 'kbs', lat: -7.296, lng: 112.7366 },
  { id: 'balaikota', lat: -7.259, lng: 112.7474 },
];
const busFrom = { lat: -7.2795, lng: 112.7905 }; // Halte ITS
const busTo = { lat: -7.2622, lng: 112.7391 }; // Halte Tunjungan

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function osrm(points, alternatives) {
  const coords = points.map((p) => `${p.lng},${p.lat}`).join(';');
  const url = `${OSRM}/${coords}?alternatives=${alternatives}&geometries=geojson&overview=full&steps=true`;
  for (let attempt = 0; attempt < 4; attempt++) {
    const res = await fetch(url, { headers: { 'User-Agent': 'sparta-hoplite-demo' } });
    if (res.ok) {
      const json = await res.json();
      if (json.code === 'Ok') return json.routes;
    }
    await sleep(1500 * (attempt + 1));
  }
  throw new Error(`OSRM gagal: ${url}`);
}

// Buang titik yang terlalu rapat agar file tidak membengkak.
function thin(coords) {
  const out = [coords[0]];
  for (const c of coords.slice(1, -1)) {
    const last = out[out.length - 1];
    const d = Math.hypot((c[0] - last[0]) * 110540, (c[1] - last[1]) * 111320);
    if (d >= 25) out.push(c);
  }
  out.push(coords[coords.length - 1]);
  return out;
}

const short = (name) =>
  name
    .replace(/^(Jalan|Jl\.?)\s+/i, '')
    .replace('Doktor Insinyur Haji Soekarno', 'Dr. Ir. H. Soekarno (MERR)')
    .replace('Moehammad Jasin Polisi Istimewa', 'Polisi Istimewa')
    .replace('Panglima Besar Sudirman', 'Panglima Sudirman')
    .replace('Jenderal ', 'Jend. ')
    .replace('Rachmat', 'Rahmat')
    .trim();
// Gang bernomor romawi (mis. "Mojo IV") bukan simpang berlampu.
const isGang = (name) => /\s[IVX]+$/.test(name);

// Simpang diambil dari manuver OSRM tempat nama jalan berganti, lalu dipilih lima yang tersebar.
function crossings(r) {
  const full = r.geometry.coordinates;
  const cum = [0];
  for (let i = 1; i < full.length; i++) {
    cum.push(cum[i - 1] + Math.hypot((full[i][1] - full[i - 1][1]) * 110540, (full[i][0] - full[i - 1][0]) * 111320));
  }
  const total = cum[cum.length - 1];
  const fracOf = ([lng, lat]) => {
    let best = 0, bestD = Infinity;
    full.forEach((c, i) => {
      const d = Math.hypot(c[0] - lng, c[1] - lat);
      if (d < bestD) { bestD = d; best = i; }
    });
    return cum[best] / total;
  };
  const steps = r.legs.flatMap((l) => l.steps);
  const cands = [];
  for (let i = 1; i < steps.length; i++) {
    const a = short(steps[i - 1].name || ''), b = short(steps[i].name || '');
    if (!a || !b || a === b || isGang(a) || isGang(b)) continue;
    const frac = fracOf(steps[i].maneuver.location);
    if (frac > 0.06 && frac < 0.96) cands.push({ name: `Simpang ${a} – ${b}`, frac });
  }
  const picked = [];
  for (const target of [0.15, 0.33, 0.5, 0.68, 0.86]) {
    const free = cands.filter((c) => picked.every((p) => Math.abs(p.frac - c.frac) > 0.07));
    if (!free.length) break;
    picked.push(free.reduce((x, y) => (Math.abs(y.frac - target) < Math.abs(x.frac - target) ? y : x)));
  }
  const byRoad = new Map();
  for (const st of steps) {
    const n = short(st.name || '');
    if (n) byRoad.set(n, (byRoad.get(n) || 0) + st.distance);
  }
  const via = [...byRoad.entries()].sort((x, y) => y[1] - x[1]).slice(0, 2).map(([n]) => `Jl. ${n}`).join(' & ');
  return { via, cross: picked.sort((x, y) => x.frac - y.frac) };
}

const toGeo = (r) => ({
  km: Math.round(r.distance / 100) / 10,
  pts: thin(r.geometry.coordinates).map(([lng, lat]) => [lat, lng]),
  ...crossings(r),
});

async function threeRoutes(dest) {
  const found = (await osrm([origin, dest], 3)).map(toGeo);
  // Lengkapi sampai tiga rute dengan titik singgah di kiri dan kanan garis lurus.
  const mid = { lat: (origin.lat + dest.lat) / 2, lng: (origin.lng + dest.lng) / 2 };
  const dLat = dest.lat - origin.lat;
  const dLng = dest.lng - origin.lng;
  const len = Math.hypot(dLat, dLng);
  for (const side of [1, -1, 2, -2]) {
    if (found.length >= 3) break;
    const via = {
      lat: mid.lat + (-dLng / len) * 0.012 * side,
      lng: mid.lng + (dLat / len) * 0.012 * side,
    };
    await sleep(1200);
    const geo = toGeo((await osrm([origin, via, dest], false))[0]);
    if (found.every((f) => Math.abs(f.km - geo.km) > 0.3)) found.push(geo);
  }
  return found.sort((a, b) => a.km - b.km).slice(0, 3);
}

const q = (t) => JSON.stringify(t);
const fmtCross = (cs) => cs.map((c) => `CrossGeo(${q(c.name)}, ${c.frac.toFixed(3)})`).join(', ');
const fmtGeo = (r) => `RouteGeo(${r.km}, ${q(r.via)}, [${fmtCross(r.cross)}], [${fmtPts(r.pts)}])`;
const fmtPts = (pts) => pts.map(([a, b]) => `[${a.toFixed(5)},${b.toFixed(5)}]`).join(',');

let dart = `// DIHASILKAN oleh tool/gen_routes.mjs dari OSRM (router.project-osrm.org).
// Data jalan (c) kontributor OpenStreetMap. Jangan diedit manual.

class CrossGeo {
  const CrossGeo(this.name, this.frac);
  final String name;
  final double frac;
}

class RouteGeo {
  const RouteGeo(this.km, this.via, this.cross, this.pts);
  final double km;
  final String via;
  final List<CrossGeo> cross;
  final List<List<double>> pts;
}

const Map<String, List<RouteGeo>> kRouteGeo = {
`;
for (const p of places) {
  const routes = await threeRoutes(p);
  for (const r of routes) console.log(p.id, r.km, 'km |', r.via, '|', r.cross.map((c) => c.name.replace('Simpang ', '')).join('; '));
  dart += `  '${p.id}': [\n`;
  for (const r of routes) dart += `    ${fmtGeo(r)},\n`;
  dart += '  ],\n';
  await sleep(1200);
}
dart += '};\n\n';

const bus = toGeo((await osrm([busFrom, busTo], false))[0]);
console.log('bus', `${bus.km} km / ${bus.pts.length} titik`);
dart += `const RouteGeo kBusLine = ${fmtGeo(bus)};\n`;

const out = join(dirname(fileURLToPath(import.meta.url)), '..', 'lib', 'data', 'route_geometry.dart');
writeFileSync(out, dart);
console.log('ditulis ->', out);
