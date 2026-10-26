/* build_patch_v2.1.0.js — v2.1.0 : assemble data/enrichissement_v2.1.0.json */
const fs = require("fs");
const { buildSeed } = require("./seed_origine_v1.js");
const canon = v => Array.isArray(v) ? "[" + v.map(x => x === undefined ? "null" : canon(x)).join(",") + "]"
  : (v && typeof v === "object") ? "{" + Object.keys(v).filter(k => v[k] !== undefined).sort().map(k => JSON.stringify(k) + ":" + canon(v[k])).join(",") + "}"
  : JSON.stringify(v === undefined ? null : v);
const cyrb53 = (str, seed = 0) => { let h1 = 0xdeadbeef ^ seed, h2 = 0x41c6ce57 ^ seed;
  for (let i = 0; i < str.length; i++) { const ch = str.charCodeAt(i); h1 = Math.imul(h1 ^ ch, 2654435761); h2 = Math.imul(h2 ^ ch, 1597334677); }
  h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507) ^ Math.imul(h2 ^ (h2 >>> 13), 3266489909);
  h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507) ^ Math.imul(h1 ^ (h1 >>> 13), 3266489909);
  return (4294967296 * (2097151 & h2) + (h1 >>> 0)).toString(36); };
const seed = buildSeed();
const terr = JSON.parse(fs.readFileSync(process.argv[2] || "enrich_terr.json"));
const raw = JSON.parse(fs.readFileSync(__dirname + "/nouvelles_civilisations_v2.1.0.json"));
const wiki = t => ({ label: "Wikipédia — " + t, url: "https://fr.wikipedia.org/wiki/" + encodeURIComponent(t.replace(/ /g, "_")) });
const civs = [], pois = [];
for (const [id, name, start, end, color, region, description, wt, cap] of raw) {
  civs.push({ id, name, start, end, color, region, description, links: [wiki(wt)] });
  if (cap) pois.push({ id: "poi-hb-" + id, civId: id, kind: "capitale", name: cap[0], lon: cap[1], lat: cap[2], start, end, description: "", links: [] });
  if (!terr[id]) console.warn("sans territoire :", id);
}
const seedHashes = {}, seedTerrByCiv = {};
for (const t of seed.territories) (seedTerrByCiv[t.civId] = seedTerrByCiv[t.civId] || []).push(t.id);
for (const k of ["civs", "territories"]) for (const o of seed[k]) seedHashes[k + "/" + o.id] = cyrb53(canon(o));
const out = {
  kind: "atlas-enrichissement", version: "2.1.0", created: new Date().toISOString().slice(0, 10),
  sources: {
    territories: "historical-basemaps, A. Ourednik — github.com/aourednik/historical-basemaps — GPL-3.0",
    note: "Instantanés datés ; une emprise vaut du milieu de l'intervalle précédent au milieu du suivant."
  },
  hash: "cyrb53(canon(objet)) des éléments du fonds d'origine v1, pour reconnaître ceux qui n'ont pas été retouchés",
  seedHashes, seedTerrByCiv, civs, pois, territoriesByCiv: terr
};
const dest = process.argv[3] || "enrichissement_v2.1.0.json";
fs.writeFileSync(dest, JSON.stringify(out));
console.log("civs", civs.length, "pois", pois.length, "terr", Object.values(terr).flat().length, (fs.statSync(dest).size / 1e6).toFixed(2) + " Mo");
/* contrôle facultatif : node build_patch_v2.1.0.js <terr.json> <sortie.json> <export_atlas.json> */
if (process.argv[4]) {
  const u = JSON.parse(fs.readFileSync(process.argv[4])).db;
  let intact = 0; for (const t of u.territories) if (seedHashes["territories/" + t.id] === cyrb53(canon(t))) intact++;
  console.log("territoires d'origine intacts :", intact, "/", u.territories.length);
}
