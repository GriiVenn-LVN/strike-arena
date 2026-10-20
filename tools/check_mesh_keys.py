#!/usr/bin/env python3
"""
Vérifie que les clés que le jeu Roblox demande à MeshStore (meshPart / image) pour les armes, les viseurs et les
soldats sont bien dans roblox/ReplicatedStorage/Shared/MeshAssets.lua (assets déjà envoyés par ServerStorage/MeshUploader).
Une clé absente = la pièce est refabriquée en EditableMesh / EditableImage chez le joueur (mémoire très limitée),
ou retombe sur son repli : il faut relancer require(game.ServerStorage.MeshUploader).start() dans Studio.

Les clés sont recalculées comme dans WeaponModels, AttachmentModels.opticBase et SoldierModels :
  w:<arme>#<groupe>/<nv>/<nt>         o:<viseur>#<groupe>/<nv>/<nt>
  w:real:<arme>#<pièce>/<nv>/<nt>     i:wr:<arme>:<matériau>:c|n|m|r     i:mat:<bruni|anod|poly|bois|acier>:c|n|r|m
  s:real:<équipe>/body|gear/<n>[/c<couleur>]/<nv>/<nt>   s:obody:g|n/<n>[/c<couleur>]/<nv>/<nt>   s:ohead:<tenue>/<n>[/c<couleur>]/<nv>/<nt>
  i:s:tex:<équipe>[<teinte>]  i:s:pal:g:<équipe>  i:s:pal:o<tenue>:<teint>
(décor des cartes, véhicules et skins : voir le banc de démarrage, qui journalise toutes les clés envoyées.)
Usage (depuis la racine du dépôt) : python3 tools/check_mesh_keys.py
"""
import os, re, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
SH = os.path.join(ROOT, 'roblox', 'ReplicatedStorage', 'Shared')
PIECE = re.compile(r'nv = (\d+), nt = (\d+),\s*data = "([^"]+)"')


def read(p):
    with open(p, encoding='utf-8') as f:
        return f.read()


def pieces(path):
    """(nv, nt, données base64) de chaque morceau, dans l'ordre du module."""
    return [(int(m.group(1)), int(m.group(2)), m.group(3)) for m in PIECE.finditer(read(path))]


def colors(b64, nv):
    import base64
    raw = base64.b64decode(b64)
    return sorted({raw[v * 14 + 13] for v in range(nv)})


known = set(re.findall(r'\["([^"]+)"\]\s*=', read(os.path.join(SH, 'MeshAssets.lua'))))
want = []          # (clé, origine)

# armes (WeaponMeshes/<clé>.lua : groupes)
for f in sorted(os.listdir(os.path.join(SH, 'WeaponMeshes'))):
    name = f[:-4]
    for gi, (nv, nt, _) in enumerate(pieces(os.path.join(SH, 'WeaponMeshes', f)), 1):
        want.append(('w:%s#%d/%d/%d' % (name, gi, nv, nt), 'arme ' + name))

# viseurs (OpticMeshes/<clé>.lua : groups = { ... })
for f in sorted(os.listdir(os.path.join(SH, 'OpticMeshes'))):
    name = f[:-4]
    for gi, (nv, nt, _) in enumerate(pieces(os.path.join(SH, 'OpticMeshes', f)), 1):
        want.append(('o:%s#%d/%d/%d' % (name, gi, nv, nt), 'viseur ' + name))

# soldats
SM = os.path.join(SH, 'SoldierMeshes')
rig = read(os.path.join(SM, 'Rig.lua'))
slots = re.findall(r'"(\w+)"', re.search(r'Rig\.SLOTS = \{([^}]*)\}', rig).group(1))
tones = re.findall(r'"#(\w{6})"', re.search(r'Rig\.TONES = \{([^}]*)\}', rig).group(1))
palette = re.findall(r'"#(\w{6})"', re.search(r'Rig\.PALETTE = \{([^}]*)\}', rig).group(1))
outfits = []
for m in re.finditer(r'\["[^"]+"\] = \{ web = (\d+), glow = (\w+), metal = \w+, colors = \{(.*?)\} \},?\n', rig):
    cls = dict(re.findall(r'(\w+) = \{ c = \{[^}]*\}, cls = "(\w+)" \}', m.group(3)))
    outfits.append((int(m.group(1)), m.group(2) == 'true', cls))


def add_soldier(prefix, path, cls_of, origin):
    for pi, (nv, nt, data) in enumerate(pieces(path), 1):
        special = [c for c in colors(data, nv) if cls_of(c) != 'base']
        if len(special) < len(colors(data, nv)):
            want.append(('s:%s/%d/%d/%d' % (prefix, pi, nv, nt), origin))
        for c in special:
            want.append(('s:%s/%d/c%d/%d/%d' % (prefix, pi, c, nv, nt), origin))


for k in ('t', 'ct', 'ffa'):
    add_soldier('real:%s/body' % k, os.path.join(SM, 'Body.lua'), lambda c: 'base', 'soldier ' + k)
    gtxt = read(os.path.join(SM, 'Gear_%s.lua' % k))
    gcls = re.findall(r'cls = "(\w+)"', gtxt.split('\n\t{')[0])
    add_soldier('real:%s/gear' % k, os.path.join(SM, 'Gear_%s.lua' % k), lambda c, g=gcls: g[c], 'équipement ' + k)
    want.append(('i:s:pal:g:' + k, 'palette ' + k))
want.append(('i:s:tex:t', 'texture t')); want.append(('i:s:tex:ct', 'texture ct'))
for p in palette:
    want.append(('i:s:tex:ffa' + p.lower(), 'texture chacun-pour-soi'))
for glow in sorted({o[1] for o in outfits}):
    g = 'g' if glow else 'n'
    add_soldier('obody:' + g, os.path.join(SM, 'Outfit.lua'),
                lambda c, gl=glow: 'neon' if c < len(slots) and slots[c] == 'accent' and gl else 'base', 'tenues (corps)')
for web, glow, cls in outfits:
    htxt = read(os.path.join(SM, 'Head_%d.lua' % web))
    hpal = re.search(r'pal = \{(.*?)\},\n', htxt).group(1)
    ents = re.findall(r'\{ (s = "\w+"|c = \{[^}]*\}, cls = "\w+") \}', hpal)
    def hcls(c, ents=ents, cls=cls):
        e = ents[c]
        if e.startswith('s ='):
            return cls.get(re.search(r'"(\w+)"', e).group(1), 'base')
        return re.search(r'cls = "(\w+)"', e).group(1)
    add_soldier('ohead:%d' % web, os.path.join(SM, 'Head_%d.lua' % web), hcls, 'tenue %d' % web)
    for t in tones:
        want.append(('i:s:pal:o%d:%s' % (web, t.lower()), 'palette tenue %d' % web))
    for m in ('rgh', 'mtl'):
        want.append(('i:s:%s:o%d' % (m, web), 'matière tenue %d' % web))

# cartes de matière des soldats réalistes (SurfaceAppearance de SoldierModels) : relief et rugosité du corps, palettes
for k in ('t', 'ct', 'ffa'):
    for m in ('nrm:', 'rgh:', 'rgh:g:', 'mtl:g:'):
        want.append(('i:s:' + m + k, 'matière soldat ' + k))

# gants et manches de la vue subjective (HandModels / HandMeshes.lua) : h:glove:<R|L>:<matière>/<nv>/<nt>, h:sleeve:<u|f>/<nv>/<nt>
htxt = read(os.path.join(SH, 'HandMeshes.lua'))
for side in ('R', 'L'):
    for m, nv, nt in re.findall(r'\t\t(fab|palm|pad|strap) = \{ nv = (\d+), nt = (\d+)', htxt):
        want.append(('h:glove:%s:%s/%s/%s' % (side, m, nv, nt), 'gant ' + side))
for m, nv, nt in re.findall(r'\t\t(u|f) = \{ nv = (\d+), nt = (\d+)', htxt):
    want.append(('h:sleeve:%s/%s/%s' % (m, nv, nt), 'manche'))

# armes réalistes (WeaponInfoReal : pièces et matériaux) et matériaux des armes stylisées (WeaponMaterials)
real = read(os.path.join(SH, 'WeaponInfoReal.lua'))
for m in re.finditer(r'\n\t(\w+) = \{\n(.*?)\n\t\},', real, re.S):
    name, body = m.group(1), m.group(2)
    for gi, (nv, nt) in enumerate(re.findall(r'part = "\w+", mat = \d+, nv = (\d+), nt = (\d+)', body), 1):
        want.append(('w:real:%s#%d/%s/%s' % (name, gi, nv, nt), 'arme réaliste ' + name))
    for mi in range(1, len(re.findall(r'double = ', body)) + 1):
        for k in 'cnmr':
            want.append(('i:wr:%s:%d:%s' % (name, mi, k), 'textures arme réaliste ' + name))
for name in re.findall(r'"(\w+)"', re.search(r'WM\.NAMES = \{([^}]*)\}', read(os.path.join(SH, 'WeaponMaterials.lua'))).group(1)):
    for k in 'cnrm':
        want.append(('i:mat:%s:%s' % (name, k), 'matériau ' + name))

missing = [(k, o) for k, o in want if k not in known]
print('clés demandées : %d ; présentes dans MeshAssets : %d ; manquantes : %d' % (len(want), len(want) - len(missing), len(missing)))
for k, o in missing:
    print('  MANQUANTE %-48s (%s)' % (k, o))
sys.exit(1 if missing else 0)
