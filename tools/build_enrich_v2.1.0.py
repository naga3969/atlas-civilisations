#!/usr/bin/env python3
"""build_enrich_v2.1.0.py
Construit les emprises territoriales de l'atlas à partir des cartes historiques
« historical-basemaps » d'A. Ourednik (GPL-3.0) : une emprise par instantané
daté, valable du milieu de l'intervalle précédent au milieu du suivant.
Usage : python3 build_enrich_v2.1.0.py <dossier geojson historical-basemaps> <specs.json> <sortie.json>
"""
import glob, json, re, sys
from shapely.geometry import shape, mapping
from shapely.geometry.polygon import orient
from shapely.ops import unary_union
from shapely.validation import make_valid

SRC, SPECS, OUT = sys.argv[1:4]
TOL, MIN_AREA = 0.025, 0.02          # ≈ 2,5 km ; parties < ≈ 250 km² écartées (sauf la plus grande)
REACH = 100                          # portée minimale d'un instantané en tête et en queue de série
PRE = 10                             # un instantané jusqu'à 10 ans avant le début reste pertinent


def year_of(f):
    m = re.search(r"world_(bc)?(\d+)\.geojson$", f)
    y = int(m.group(2))
    return -y if m.group(1) else y


SNAP = {}
for f in glob.glob(SRC + "/world_*.geojson"):
    y = year_of(f)
    if -3000 <= y <= 1900:
        SNAP[y] = json.load(open(f))["features"]
YEARS = sorted(SNAP)


def polys(g):
    if g.is_empty: return []
    if g.geom_type == "Polygon": return [g]
    if hasattr(g, "geoms"): return [p for x in g.geoms for p in polys(x)]
    return []


def rings_of(geom):
    ps = polys(geom.simplify(TOL, preserve_topology=True))
    if not ps: return []
    big = max(ps, key=lambda p: p.area)
    keep = [p for p in ps if p.area >= MIN_AREA or p is big]
    out = []
    for p in keep:
        p = orient(p, 1.0)
        for r in [p.exterior] + list(p.interiors):
            pts, last = [], None
            for c in r.coords:
                x, y = c[0], c[1]
                q = [round(x, 2), round(y, 2)]
                if q != last: pts.append(q); last = q
            if len(pts) >= 4: out.append(pts[:-1])        # l'application referme elle-même
    return out


def fmt(y):
    return f"{-y} av. J.-C." if y < 0 else str(y)


def build(spec):
    name_re = re.compile("^(?:" + spec["names"] + ")$", re.I)
    subj_re = re.compile("^(?:" + spec["subj"] + ")$", re.I) if spec.get("subj") else None
    s, e = spec["start"], spec["end"]
    lo, hi = spec.get("years", [s, e])
    hits = []
    for y in YEARS:
        if not (max(s, lo) - PRE <= y <= min(e, hi)): continue
        gs = []
        for ft in SNAP[y]:
            pr = ft["properties"]; n = (pr.get("NAME") or "").strip(); sj = (pr.get("SUBJECTO") or "").strip()
            if not ft["geometry"]: continue
            if name_re.match(n) or (subj_re and subj_re.match(sj)):
                gs.append(make_valid(shape(ft["geometry"])))
        if gs:
            hits.append((y, unary_union(gs)))
    terrs = []
    for i, (y, g) in enumerate(hits):
        a = s if i == 0 else (hits[i - 1][0] + y) // 2 + 1
        b = e if i == len(hits) - 1 else (y + hits[i + 1][0]) // 2
        # aux extrémités, pas d'extrapolation au-delà d'un siècle ou de l'écart avec l'instantané voisin
        if i == 0: a = max(a, y - max(REACH, hits[1][0] - y if len(hits) > 1 else 0))
        if i == len(hits) - 1: b = min(b, y + max(REACH, y - hits[i - 1][0] if i else 0))
        a, b = max(a, s), min(b, e)
        if a > b: continue
        rs = rings_of(g)
        if not rs: continue
        terrs.append({"id": f"ter-hb-{spec['id']}-{'m' if y < 0 else ''}{abs(y)}", "civId": spec["id"],
                      "label": "vers " + fmt(y), "start": a, "end": b, "rings": rs,
                      "source": f"historical-basemaps world_{'bc' if y < 0 else ''}{abs(y)}"})
    return terrs


if __name__ == "__main__":
    specs = json.load(open(SPECS))
    out, stats = {}, []
    for sp in specs:
        t = build(sp)
        if t:
            out[sp["id"]] = t
        stats.append(f"{sp['id']}: {len(t)} ({', '.join(x['label'][5:] for x in t)})")
    json.dump(out, open(OUT, "w"), separators=(",", ":"))
    print("\n".join(stats))
