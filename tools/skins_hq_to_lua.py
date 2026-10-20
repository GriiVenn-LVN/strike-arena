#!/usr/bin/env python3
"""Peintures haute qualité des skins (256 px) et masques lumineux, pour l'envoi depuis Studio (MeshUploader).

Usage (depuis la racine du dépôt) : python3 tools/skins_hq_to_lua.py <dossier de export_skins.js>
  -> roblox/ServerStorage/SkinTexturesHQ/<motif>.lua       (image 256 px en 256 couleurs, base64 ; clé « i:sk2:<motif> »)
  -> roblox/ServerStorage/SkinTexturesHQ/<motif>#g.lua     (masque lumineux 128 px en gris des skins néon ; clé « i:sk2:<motif>#g »)
Rangées dans ServerStorage : seul MeshUploader les lit (rien n'est envoyé aux joueurs). Tant qu'une image n'est pas envoyée,
SkinPaint garde la peinture 128 px de ReplicatedStorage/Shared/SkinTextures (tools/skins_to_lua.py).
"""
import base64, os, sys
from PIL import Image

SRC = sys.argv[1] if len(sys.argv) > 1 else 'skins_out'
OUT = os.path.join(os.path.dirname(__file__), '..', 'roblox', 'ServerStorage', 'SkinTexturesHQ')
os.makedirs(OUT, exist_ok=True)
for f in os.listdir(OUT):
    if f.endswith('.lua'):
        os.remove(os.path.join(OUT, f))

total, n = 0, 0
for f in sorted(os.listdir(SRC)):
    if f.endswith('@256.png'):
        tex = f[:-len('@256.png')]
        im = Image.open(os.path.join(SRC, f)).convert('RGB')
        # tramage léger : sans lui, les dégradés (Dégradé solaire, Rouge sang…) font des marches en 256 couleurs
        q = im.quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG)
        pal = bytes(q.getpalette()[:768]).ljust(768, b'\0')
        body = ('-- Généré par tools/skins_hq_to_lua.py (peinture « %s » du jeu web, 256 px) : ne pas modifier à la main.\n'
                'return { size = %d, pal = "%s",\n px = "%s" }\n') % (tex, im.width, base64.b64encode(pal).decode(), base64.b64encode(q.tobytes()).decode())
        name = tex
    elif f.endswith('#g.png'):
        tex = f[:-len('#g.png')]
        im = Image.open(os.path.join(SRC, f)).convert('L')
        body = ('-- Généré par tools/skins_hq_to_lua.py (masque lumineux « %s » du jeu web) : ne pas modifier à la main.\n'
                'return { size = %d, gray = "%s" }\n') % (tex, im.width, base64.b64encode(im.tobytes()).decode())
        name = tex + '#g'
    else:
        continue
    open(os.path.join(OUT, name + '.lua'), 'w').write(body)
    total += len(body); n += 1
print('%d images, %.1f Ko' % (n, total / 1024))
