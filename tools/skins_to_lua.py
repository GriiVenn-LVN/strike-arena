#!/usr/bin/env python3
"""Convertit les peintures exportées par tools/export_skins.js en modules Luau pour Roblox.

Usage (depuis la racine du dépôt) : python3 tools/skins_to_lua.py <dossier de export_skins.js>
  -> roblox/ReplicatedStorage/Shared/SkinTextures/<motif>.lua  (image 128 px en 256 couleurs, base64)
  -> roblox/ReplicatedStorage/Shared/SkinInfo.lua              (finition, couleurs, motif de chaque skin)

Les numéros Roblox suivent Config.SKINS : 1..54 = skins 0..53 du web, 55.. = skins d'Halloween du web.
Les camos animés (exclusifs) sont dessinés en direct par SkinPaint.lua : ils n'ont pas d'image.
"""
import base64, json, os, sys
from PIL import Image

SRC = sys.argv[1] if len(sys.argv) > 1 else 'skins_out'
ROOT = os.path.join(os.path.dirname(__file__), '..', 'roblox', 'ReplicatedStorage', 'Shared')
OUT = os.path.join(ROOT, 'SkinTextures')
os.makedirs(OUT, exist_ok=True)
for f in os.listdir(OUT):
    if f.endswith('.lua'):
        os.remove(os.path.join(OUT, f))

meta = json.load(open(os.path.join(SRC, 'skins.json')))
total = 0
for s in meta:
    tex = s.get('tex')
    if not tex or s.get('anim'):
        continue
    png = os.path.join(SRC, tex + '.png')
    if not os.path.exists(png) or os.path.exists(os.path.join(OUT, tex + '.lua')):
        continue
    im = Image.open(png).convert('RGB')
    q = im.quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = bytes(q.getpalette()[:768]).ljust(768, b'\0')
    px = q.tobytes()
    body = ('-- Généré par tools/skins_to_lua.py (peinture « %s » du jeu web) : ne pas modifier à la main.\n'
            'return { size = %d, pal = "%s",\n px = "%s" }\n') % (tex, im.width, base64.b64encode(pal).decode(), base64.b64encode(px).decode())
    open(os.path.join(OUT, tex + '.lua'), 'w').write(body)
    total += len(body)

def lua_str(v):
    return 'nil' if v is None else '"%s"' % str(v).replace('"', '\\"')

rows = []
web_to_rbx = {}
n = 0
for s in meta:
    if s.get('anim'):
        continue
    n += 1
    web_to_rbx[s['i']] = n
    rows.append('\t[%d] = { name = %s, tex = %s, fin = %s, a = %s, b = %s, tint = %s, glow = %s },  -- web %d' % (
        n, lua_str(s['n']), lua_str(s.get('tex')), lua_str(s.get('fin')), lua_str(s.get('a')), lua_str(s.get('b')),
        lua_str(s.get('tint')), 'true' if s.get('glow') else 'false', s['i']))
anim = ['\t%s = { name = %s, a = %s, fin = %s },' % (s['anim'], lua_str(s['n']), lua_str(s.get('a')), lua_str(s.get('fin')))
        for s in meta if s.get('anim')]
info = ('-- Généré par tools/skins_to_lua.py depuis les skins du jeu web : ne pas modifier à la main.\n'
        '-- SkinInfo.SKINS[n] suit Config.SKINS ; tex = image de SkinTextures ; fin = finition ; a = couleur des pièces secondaires ;\n'
        '-- b = couleur unie (skin sans peinture) ; glow = skin lumineux. SkinInfo.ANIM = camos animés (exclusifs Robux).\n'
        'local SkinInfo = {}\nSkinInfo.SKINS = {\n' + '\n'.join(rows) + '\n}\nSkinInfo.ANIM = {\n' + '\n'.join(anim) + '\n}\nreturn SkinInfo\n')
open(os.path.join(ROOT, 'SkinInfo.lua'), 'w').write(info)
print('%d skins, %d images, %.1f Ko' % (n, len(os.listdir(OUT)), total / 1024))
