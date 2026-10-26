#!/usr/bin/env python3
"""build_relief_v2.1.0.py
Ombrage du relief de l'Atlas des civilisations, d'après le « Shaded Relief » de
Natural Earth (domaine public, 10800 × 5400, équirectangulaire).
On en garde la seule modulation lumineuse (passe-haut sur la luminance), les mers
et les lacs sont blanchis : l'image se superpose au fond de carte en « produit ».
  data/geo/relief/world.jpg            vue d'ensemble 2700 × 1350
  data/geo/relief/<lon>_<lat>.jpg      tuiles 30° × 30° à pleine résolution (900 px)
Usage : python3 build_relief_v2.1.0.py shadedrelief.jpg ne_50m_land.geojson ne_50m_lakes.geojson sortie/
"""
import json, os, sys
import numpy as np  # + scipy
from PIL import Image, ImageDraw, ImageFilter
Image.MAX_IMAGE_PIXELS = None
SR, LAND, LAKES, OUT = sys.argv[1:5]
os.makedirs(OUT, exist_ok=True)
im = Image.open(SR).convert("L")
W, H = im.size; S = W / 360.0
L = np.asarray(im, dtype=np.float32)
mask = Image.new("L", (W, H), 0); d = ImageDraw.Draw(mask)
def draw(path, val):
    for f in json.load(open(path))["features"]:
        g = f["geometry"]; polys = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
        for poly in polys:
            for i, ring in enumerate(poly):
                pts = [((x + 180) * S, (90 - y) * S) for x, y in ring]
                d.polygon(pts, fill=val if i == 0 else 255 - val)
draw(LAND, 255)
draw(LAKES, 0)
# flou « normalisé » limité aux terres : pas de halo le long des côtes
from scipy.ndimage import gaussian_filter
def gblur(a, r):
    return gaussian_filter(a.astype(np.float32), r / 2.0, mode="wrap")
mk = np.asarray(mask, dtype=np.float32) / 255.0
blur = gblur(L * mk, 14) / np.maximum(gblur(mk, 14), 1e-3)
shade = np.where(mk > 0, L / np.maximum(blur, 1.0), 1.0)
out = np.clip(255.0 * np.power(np.clip(shade, 0, 1.6), 2.2), 0, 255)
out = 255.0 - (255.0 - out) * 0.9            # adoucit les ombres les plus noires
m = np.asarray(mask.filter(ImageFilter.GaussianBlur(1.2)), dtype=np.float32) / 255.0
res = 255.0 - (255.0 - out) * m
img = Image.fromarray(res.astype(np.uint8), "L")
img.resize((W // 4, H // 4), Image.LANCZOS).save(os.path.join(OUT, "world.jpg"), quality=82, optimize=True, progressive=True)
T = 30; px = int(T * S); tiles = []
for lon in range(-180, 180, T):
    for lat in range(90, -90, -T):
        x0, y0 = int((lon + 180) * S), int((90 - lat) * S)
        t = img.crop((x0, y0, x0 + px, y0 + px))
        if np.asarray(t).min() > 247: continue          # pur océan ou relief nul
        key = f"{lon}_{lat - T}"                          # coin sud-ouest
        t.save(os.path.join(OUT, key + ".jpg"), quality=78, optimize=True, progressive=True)
        tiles.append(key)
json.dump({"v": "2.1.0", "tile": T, "px": px, "tiles": tiles,
           "source": "Natural Earth Shaded Relief (domaine public)"}, open(os.path.join(OUT, "index.json"), "w"))
print(len(tiles), "tuiles")
