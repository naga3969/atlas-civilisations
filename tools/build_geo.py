#!/usr/bin/env python3
"""
build_geo.py — v2.0.0
Génère les fonds de carte de l'Atlas des civilisations à partir de Natural Earth
(domaine public) :
  data/geo/base.json        vue d'ensemble (1:50 000 000)
  data/geo/t/<x>_<y>.json   tuiles de détail 10° × 10° (1:10 000 000)
                            l = terres, k = lacs, r = fleuves ; les traits de côte
                            sont déduits à l'affichage (segments hors bord de tuile)

Choix historiques : les réservoirs (barrages modernes) sont retirés, la mer
d'Aral et le lac Tchad reprennent leur emprise historique.

Usage : python3 build_geo.py <dossier_naturalearth_geojson> <dossier_sortie_data_geo>
"""
import json, math, os, sys
from shapely.geometry import shape, box, LineString, MultiLineString, Polygon, MultiPolygon
from shapely.validation import make_valid

SRC, OUT = sys.argv[1], sys.argv[2]
TILE = 10
HISTORIC = {"South Aral Sea", "North Aral Sea", "Lake Chad"}


def load(name):
    with open(os.path.join(SRC, name + ".geojson")) as f:
        return json.load(f)["features"]


def polys(geom):
    if geom.is_empty:
        return []
    if isinstance(geom, Polygon):
        return [geom]
    if isinstance(geom, MultiPolygon):
        return list(geom.geoms)
    if hasattr(geom, "geoms"):
        return [p for g in geom.geoms for p in polys(g)]
    return []


def lines(geom):
    if geom.is_empty:
        return []
    if isinstance(geom, LineString):
        return [geom]
    if isinstance(geom, MultiLineString):
        return list(geom.geoms)
    if hasattr(geom, "geoms"):
        return [l for g in geom.geoms for l in lines(g)]
    return []


def rnd(coords, nd):
    out, last = [], None
    for x, y in coords:
        p = [round(x, nd), round(y, nd)]
        if p != last:
            out.append(p)
            last = p
    return out


def ring_list(p, nd):
    rs = [rnd(p.exterior.coords, nd)] + [rnd(i.coords, nd) for i in p.interiors]
    return [r for r in rs if len(r) >= 4]


def land_geoms(name):
    return [make_valid(shape(f["geometry"])) for f in load(name)]


def lake_geoms(scale):
    gs = []
    for f in load(f"ne_{scale}_lakes"):
        pr = f["properties"]
        if pr.get("featurecla") == "Reservoir" or pr.get("name") in HISTORIC:
            continue
        gs.append(make_valid(shape(f["geometry"])))
    for f in load(f"ne_{scale}_lakes_historic"):
        gs.append(make_valid(shape(f["geometry"])))
    return gs


def river_geoms(scale):
    return [shape(f["geometry"]) for f in load(f"ne_{scale}_rivers_lake_centerlines")]


# ----------------------------------------------------------------- base 1:50m
def build_base():
    tol, nd = 0.02, 2
    land = []
    for g in land_geoms("ne_50m_land"):
        for p in polys(g.simplify(tol, preserve_topology=True)):
            land += ring_list(p, nd)
    lakes = []
    for g in lake_geoms("50m"):
        for p in polys(g.simplify(tol, preserve_topology=True)):
            lakes += ring_list(p, nd)
    rivers = []
    for g in river_geoms("50m"):
        for l in lines(g.simplify(tol)):
            c = rnd(l.coords, nd)
            if len(c) > 1:
                rivers.append(c)
    return {"land": land, "lakes": lakes, "rivers": rivers}


# ------------------------------------------------------------- tuiles 1:10m
def build_tiles():
    tol, nd = 0.003, 3
    land = [g.simplify(tol, preserve_topology=True) for g in land_geoms("ne_10m_land")]
    lakes = [g.simplify(tol, preserve_topology=True) for g in lake_geoms("10m")]
    rivers = [g.simplify(tol) for g in river_geoms("10m")]

    def idx(geoms):
        return [(g, g.bounds) for g in geoms if not g.is_empty]

    L, K, R = idx(land), idx(lakes), idx(rivers)

    def hits(items, bx):
        x0, y0, x1, y1 = bx.bounds
        return [g for g, (a, b, c, d) in items if c >= x0 and a <= x1 and d >= y0 and b <= y1]

    tiles = []
    for tx in range(-180, 180, TILE):
        for ty in range(-90, 90, TILE):
            bx = box(tx, ty, tx + TILE, ty + TILE)
            t = {"l": [], "k": [], "r": []}
            for g in hits(L, bx):
                for p in polys(g.intersection(bx)):
                    t["l"] += ring_list(p, nd)
            for g in hits(K, bx):
                for p in polys(g.intersection(bx)):
                    t["k"] += ring_list(p, nd)
            for g in hits(R, bx):
                for l in lines(g.intersection(bx)):
                    c = rnd(l.coords, nd)
                    if len(c) > 1:
                        t["r"].append(c)
            if any(t.values()):
                key = f"{tx}_{ty}"
                t = {k: v for k, v in t.items() if v}
                with open(os.path.join(OUT, "t", key + ".json"), "w") as f:
                    json.dump(t, f, separators=(",", ":"))
                tiles.append(key)
    return tiles


if __name__ == "__main__":
    os.makedirs(os.path.join(OUT, "t"), exist_ok=True)
    base = build_base()
    base["tile"] = TILE
    base["tiles"] = build_tiles()
    base["v"] = "2.0.0"
    base["source"] = "Natural Earth (domaine public) — naturalearthdata.com"
    with open(os.path.join(OUT, "base.json"), "w") as f:
        json.dump(base, f, separators=(",", ":"))
    print("base:", {k: len(v) for k, v in base.items() if isinstance(v, list)})
