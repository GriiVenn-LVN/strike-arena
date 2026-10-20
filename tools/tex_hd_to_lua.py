#!/usr/bin/env python3
"""Textures des cartes en haute définition pour Roblox (à côté des textures réduites de tools/scene_to_lua.py).

Usage (depuis la racine du dépôt) : python3 tools/tex_hd_to_lua.py <dossier de export_scene.js>
  -> roblox/ServerStorage/MapTexturesHQ/<id>.lua   même format que MapScenes/_Tex (palette 256 couleurs), 512 px au plus
     (dans ServerStorage : seul MeshUploader, dans Studio, a besoin des pixels ; les joueurs chargent l'image envoyée)

Chaque texture HD est rangée sous le numéro <id> de la texture réduite déjà dans _Tex (celui que citent les matériaux
des Info.lua) : les cartes ne changent pas, MapDress prend la version HD quand elle a été envoyée sur Roblox (clés
MeshStore « m:t2:<id> »), sinon garde la réduite. Le web dessine certaines textures avec du hasard (fissures, taches) :
un nouvel export ne redonne pas toujours les mêmes numéros. La texture réduite du nouvel export la plus proche
(même taille, même genre, écart moyen des pixels) est alors prise, et sa version HD rangée sous l'ancien numéro.
Seules les textures posées telles quelles en jeu sont gardées : celles que MapScene.hdMaterial remplace par un
matériau PBR de Roblox (enduit, briques, bois…) ne servent pas.
"""
import base64, json, os, re, sys
import numpy as np
from PIL import Image

SRC = sys.argv[1] if len(sys.argv) > 1 else 'scene_out'
RB = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'roblox')
OLD = os.path.join(RB, 'ReplicatedStorage', 'Shared', 'MapScenes', '_Tex')
OUT = os.path.join(RB, 'ServerStorage', 'MapTexturesHQ')
CHUNK = 190000
MAXERR = 40.0           # écart moyen (0..255) au-delà duquel deux textures ne sont pas la même
HEAD = '-- Généré par tools/tex_hd_to_lua.py depuis le jeu web (tools/export_scene.js) : ne pas modifier à la main.\n'
# genres remplacés par un matériau PBR (MapScene.lua, table HD) : garder les deux d'accord
PBR = {'plaster', 'crate', 'stone', 'plat', 'roof', 'pillar', 'conc', 'platI', 'pillarI', 'wceil', 'corrug', 'rock', 'cabin',
       'snowb', 'wdeck', 'deck', 'pole', 'bark', 'brick', 'tomb', 'shelf', 'barrel'}


def field(src, name):
    m = re.search(r'\b%s = ("([^"]*)"|\{([^}]*)\}|([0-9.]+))' % name, src)
    if not m:
        return None
    if m.group(2) is not None:
        return m.group(2)
    if m.group(3) is not None:
        return [int(x) for x in m.group(3).split(',')]
    return float(m.group(4))


def load_old(tid):
    """Texture réduite de _Tex -> (genre, image RGBA numpy)."""
    src = open(os.path.join(OLD, tid + '.lua'), encoding='utf-8').read()
    w, h, kind, fmt = int(field(src, 'w')), int(field(src, 'h')), field(src, 'kind'), field(src, 'fmt')
    px = field(src, 'px')
    for k in range(2, int(field(src, 'parts')) + 1):
        more = open(os.path.join(OLD, '%s_%d.lua' % (tid, k)), encoding='utf-8').read()
        px += re.search(r'return "([^"]*)"', more).group(1)
    raw = np.frombuffer(base64.b64decode(px), dtype=np.uint8)
    if fmt == 'g':
        return kind, fmt, None
    stride = 4 if fmt == 'pa' else 3
    pal = np.frombuffer(base64.b64decode(field(src, 'pal')), dtype=np.uint8).reshape(-1, stride)
    img = pal[raw].reshape(h, w, stride).astype(np.float32)
    if stride == 3:
        img = np.concatenate([img, np.full((h, w, 1), 255, np.float32)], axis=2)
    return kind, fmt, img


def rm_tree(d):
    if os.path.isdir(d):
        for f in os.listdir(d):
            os.remove(os.path.join(d, f))


def encode(im):
    """Même format que tools/scene_to_lua.py : palette 256 couleurs, alpha si la texture en a."""
    w, h = im.size
    px = list(im.convert('RGBA').get_flattened_data() if hasattr(im, 'get_flattened_data') else im.getdata())
    sr = sg = sb = sa = 0.0
    for r, g, b, a in px:
        k = a / 255.0
        sr += r * k; sg += g * k; sb += b * k; sa += k
    sa = max(sa, 1e-6)
    info = {'w': w, 'h': h}
    if im.getchannel('A').getextrema()[0] < 250:
        info['fmt'] = 'pa'
        q = im.quantize(256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
        pal = bytes((q.getpalette('RGBA') or [])[:1024]).ljust(1024, b'\0')
    else:
        info['fmt'] = 'p'
        q = im.convert('RGB').quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
        pal = bytes(q.getpalette()[:768]).ljust(768, b'\0')
    info['avg'] = [round(sr / sa), round(sg / sa), round(sb / sa)]
    return info, pal, q.tobytes()


def lua_info(tid, kind, info, pal, first, parts):
    return (HEAD + 'return { w = %d, h = %d, kind = "%s", avg = {%d, %d, %d}, fmt = "%s", pal = "%s", px = "%s", parts = %d }\n'
            % (info['w'], info['h'], kind, info['avg'][0], info['avg'][1], info['avg'][2], info['fmt'], base64.b64encode(pal).decode(), first, parts))


def main():
    newmeta = json.load(open(os.path.join(SRC, 'textures.json')))
    hdmeta = json.load(open(os.path.join(SRC, 'textures_hd.json')))
    new_imgs = {}
    for tid in newmeta:
        new_imgs[tid] = np.asarray(Image.open(os.path.join(SRC, 'tex', tid + '.png')).convert('RGBA'), dtype=np.float32)
    olds = sorted(f[:-4] for f in os.listdir(OLD) if f.endswith('.lua') and not re.search(r'_\d+\.lua$', f))
    os.makedirs(OUT, exist_ok=True)
    rm_tree(OUT)
    total, n, skipped = 0, 0, []
    for tid in olds:
        kind, fmt, img = load_old(tid)
        if fmt == 'g' or kind in PBR:
            continue
        best, be = None, 1e9
        for nt, nm in newmeta.items():
            if nt not in hdmeta or nm['kind'] != kind:
                continue
            ni = new_imgs[nt]
            if ni.shape != img.shape:
                continue
            e = 0.0 if nt == tid else float(np.abs(ni - img).mean())
            if e < be:
                best, be = nt, e
        if best is None or be > MAXERR:
            skipped.append((tid, kind, None if best is None else round(be, 1)))
            continue
        im = Image.open(os.path.join(SRC, 'texhd', best + '.png')).convert('RGBA')
        info, pal, raw = encode(im)
        b = base64.b64encode(raw).decode()
        parts = [b[i:i + CHUNK] for i in range(0, len(b), CHUNK)]
        text = lua_info(tid, kind, info, pal, parts[0], len(parts))
        with open(os.path.join(OUT, tid + '.lua'), 'w', encoding='utf-8') as f:
            f.write(text)
        total += len(text.encode('utf-8'))
        for k, p in enumerate(parts[1:], start=2):
            t2 = HEAD + 'return "%s"\n' % p
            with open(os.path.join(OUT, '%s_%d.lua' % (tid, k)), 'w', encoding='utf-8') as f:
                f.write(t2)
            total += len(t2.encode('utf-8'))
        n += 1
        print('%-20s %-10s -> %4dx%-4d %s (écart %.1f)' % (tid, kind, info['w'], info['h'], best, be))
    print('%d textures HD, %.1f Mo ; sans équivalent : %s' % (n, total / 1e6, skipped))


main()
