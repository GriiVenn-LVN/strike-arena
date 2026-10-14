#!/usr/bin/env python3
"""
Soldats réalistes : prépare les modèles des joueurs et des bots (équipes T, CT, chacun-pour-soi).

Source : personnage « swat_male » de Mesh2Motion
(https://github.com/scottpetrovic/mesh2motion-app, dossier static/), CC0 (elbolilloduro).
Même squelette humain que les zombies. Le jeu ne lit pas d'animation : le squelette
suit le soldat procédural (45_models.js), voir src/49b_soldiers.js.

Sorties (dans models/characters/, intégrées par tools/embed_models.pl) :
  s_ct_game.glb   tenue bleu nuit (forces spéciales)
  s_t_game.glb    tenue camouflage désert
  s_ffa_game.glb  tenue gris urbain (teintée en jeu par la couleur du joueur)

Usage : python3 tools/soldiers/build_soldiers.py <dossier static de mesh2motion-app>
Dépendances : numpy, Pillow.
"""
import io, os, sys
import numpy as np
from PIL import Image, ImageFilter
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'zombies'))
from build_zombies import read_glb, bv_bytes, Builder, fbm

SRC = sys.argv[1] if len(sys.argv) > 1 else 'mesh2motion-app/static'
OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'models', 'characters')
SIZE = 1024   # texture agrandie (détails du camouflage), JPEG

def hexc(h):
    return np.array([int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)], np.float32)

def blur(a, r):
    return np.asarray(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r)), np.float32) / 255

def recolor(img, kind, seed):
    rng = np.random.default_rng(seed)
    img = img.convert('RGB').resize((SIZE, SIZE), Image.LANCZOS)
    a = np.asarray(img, np.float32) / 255
    h, w, _ = a.shape
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    lum = .3 * r + .59 * g + .11 * b
    mx, mn = a.max(2), a.min(2)
    sat = (mx - mn) / np.maximum(mx, 1e-3)
    skin = blur(((r > g) & (g > b * .95) & (sat > .12) & (sat < .75) & (mx > .2)).astype(np.float32), 1.5)
    # relief du tissu : luminance rapportée à la moyenne locale (plis, coutures, sangles)
    det = np.clip(lum / np.maximum(blur(lum, 10), .02), .35, 2.2)[..., None]
    # éléments clairs d'origine (écussons, boucles) : gardés plus clairs
    hi = np.clip((lum - .32) * 4, 0, 1)[..., None]
    n1, n2 = fbm((h, w), rng, (96, 40, 12)), fbm((h, w), rng, (64, 24, 8))
    if kind == 'ct':
        base = hexc('#18212f') * (1 - .25 * (n2[..., None] - .5))
        cloth = base * det * 1.05
    elif kind == 't':
        # camouflage désert trois tons, taches irrégulières
        # grandes taches douces (les îlots UV hachent les petites)
        n1, n2 = fbm((h, w), rng, (200, 90)), fbm((h, w), rng, (150, 70))
        c0, c1, c2, c3 = hexc('#ad9a72'), hexc('#94805c'), hexc('#7b7553'), hexc('#c2b28c')
        cam = np.where((n1 > .56)[..., None], c1, c0)
        cam = np.where((n2 > .6)[..., None], c2, cam)
        cam = np.where(((n1 < .36) & (n2 < .45))[..., None], c3, cam)
        cam = blur(cam[..., 0], .8)[..., None] * 0 + cam   # bords nets (tissu imprimé)
        cloth = cam * (1 + (det - 1) * .7) * .78
    else:
        base = hexc('#41464d') * (1 - .2 * (n2[..., None] - .5))
        cloth = base * det
    # le gilet et les sangles (zones les plus sombres d'origine) restent plus foncés
    dark = np.clip((.16 - lum) * 6, 0, 1)[..., None]
    cloth = cloth * (1 - .35 * dark)
    cloth = cloth * (1 - hi * .4) + a * hi * .4
    dirt = (.9 + .2 * fbm((h, w), rng, (24, 8, 3)))[..., None]
    cloth = np.clip(cloth * dirt, 0, 1)
    out = a * skin[..., None] + cloth * (1 - skin[..., None])
    return Image.fromarray((np.clip(out, 0, 1) * 255 + .5).astype(np.uint8))

def build(src, name, kind, seed):
    j, binb = read_glb(src)
    views = [bv_bytes(j, binb, i) for i in range(len(j['bufferViews']))]
    orig = [dict(v) for v in j['bufferViews']]
    accs = j['accessors']
    imgs = j.get('images', [])
    img_views = {im['bufferView'] for im in imgs}
    bld = Builder(j)
    remap = {}
    for i, data in enumerate(views):
        if i in img_views:
            continue
        remap[i] = bld.view(data, orig[i].get('target'))
        if orig[i].get('byteStride'):
            j['bufferViews'][remap[i]]['byteStride'] = orig[i]['byteStride']
    j['accessors'] = accs
    for a in accs:
        a['bufferView'] = remap[a['bufferView']]
    for im in imgs:
        tex = recolor(Image.open(io.BytesIO(views[im['bufferView']])), kind, seed)
        bio = io.BytesIO()
        tex.save(bio, 'JPEG', quality=80, optimize=True)
        im['bufferView'] = bld.view(bio.getvalue())
        im['mimeType'] = 'image/jpeg'
        im['name'] = name
    for m in j.get('materials', []):
        m['name'] = 'soldier_' + kind
    j.pop('animations', None)
    j['asset'] = {'version': '2.0', 'generator': 'tools/soldiers/build_soldiers.py (source CC0 Mesh2Motion)'}
    return bld.write(os.path.join(OUT, 's_%s_game.glb' % name))

if __name__ == '__main__':
    p = os.path.join(SRC, 'models-variation', 'human', 'swat_male.glb')
    for i, k in enumerate(('ct', 't', 'ffa')):
        print('s_%s_game.glb' % k, build(p, k, k, 2000 + i))
