#!/usr/bin/env python3
"""Convertit les cartes exportées par tools/export_scene.js en modules Luau pour Roblox.

Usage (depuis la racine du dépôt) : python3 tools/scene_to_lua.py <dossier de export_scene.js>
  -> roblox/ReplicatedStorage/Shared/MapData.lua                 grille de jeu exacte des 10 cartes (+ points, sites, zones)
  -> roblox/ReplicatedStorage/Shared/MapScenes/<carte>/Info.lua  matériaux, lumières, halos, ambiance, liste des blocs binaires
  -> roblox/ReplicatedStorage/Shared/MapScenes/<carte>/B<n>.lua  données binaires (base64) : primitives et maillages
  -> roblox/ReplicatedStorage/Shared/MapScenes/_Tex/<id>.lua      textures canvas du web (palette 256 couleurs, 128 px ; sol 512 px)

Primitives (construites par le serveur, MapBuilder) : un enregistrement de 62 octets
  u8 genre (0 bloc, 1 boule, 2 cylindre), u8 drapeaux (1 plan, 2 ombre, 4 couleur d'instance),
  f32x3 position (m), f32x3 taille (m ; cylindre : hauteur, diamètre, diamètre), f32x3 taille d'une répétition de texture,
  i16x4 quaternion (/32767), u16x6 matériaux des faces (+x -x +y -y +z -z ; 65535 = aucune), u8x3 couleur, u8 libre.
Maillages (construits par le client, MapDetailController) : en-tête u32 nbGéo, u32 nbInstances, puis les géométries
  (u32 nv, u32 ni, u8 drapeaux 1 normales 2 uv 4 couleurs, u8 nbGroupes, f32x6 boîte, groupes u32 début u32 nombre u8 matériau,
  positions u16x3, normales i8x3, uv i16x2 (/2048), couleurs u8x3, indices u16 ou u32 si nv > 65535),
  puis les instances (u16 géo, u16 liste de matériaux, u8x3 couleur, u8 drapeaux 1 couleur 2 ombre, f32x12 matrice monde).
"""
import base64, json, math, os, struct, sys
from PIL import Image

SRC = sys.argv[1] if len(sys.argv) > 1 else 'scene_out'
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'roblox', 'ReplicatedStorage', 'Shared')
OUTS = os.path.join(ROOT, 'MapScenes')
CHUNK = 190000          # caractères base64 par module (< 200 Ko)
NONE = 65535

maps = json.load(open(os.path.join(SRC, 'maps.json')))
texmeta = json.load(open(os.path.join(SRC, 'textures.json')))


def rm_tree(d):
    if not os.path.isdir(d):
        return
    for f in os.listdir(d):
        p = os.path.join(d, f)
        if os.path.isdir(p):
            rm_tree(p); os.rmdir(p)
        else:
            os.remove(p)


rm_tree(OUTS)
os.makedirs(os.path.join(OUTS, '_Tex'), exist_ok=True)
HEAD = '-- Généré par tools/scene_to_lua.py depuis le jeu web (tools/export_scene.js) : ne pas modifier à la main.\n'


def lua(v, ind=''):
    if v is None:
        return 'nil'
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, (int,)):
        return str(v)
    if isinstance(v, float):
        if v == int(v) and abs(v) < 1e9:
            return str(int(v))
        return ('%.4f' % v).rstrip('0').rstrip('.')
    if isinstance(v, str):
        return json.dumps(v, ensure_ascii=False)
    if isinstance(v, (list, tuple)):
        return '{' + ', '.join(lua(x, ind) for x in v) + '}'
    if isinstance(v, dict):
        items = []
        for k, x in v.items():
            key = k if k.isidentifier() and k not in ('end', 'and', 'or', 'not', 'nil', 'true', 'false', 'function', 'local', 'then', 'do', 'repeat', 'until', 'in', 'for', 'if', 'else', 'elseif', 'while', 'break', 'return') else '[%s]' % json.dumps(k)
            items.append('%s = %s' % (key, lua(x, ind)))
        return '{ ' + ', '.join(items) + ' }'
    raise TypeError(type(v))


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)
    return len(text.encode('utf-8'))


def blobs(folder, prefix, data, start):
    """Découpe des octets en modules base64 ; renvoie (noms, prochain numéro, taille)."""
    b = base64.b64encode(data).decode()
    names, size, n = [], 0, start
    for i in range(0, len(b), CHUNK):
        name = '%s%d' % (prefix, n); n += 1
        size += write(os.path.join(folder, name + '.lua'), HEAD + 'return "%s"\n' % b[i:i + CHUNK])
        names.append(name)
    return names, n, size


# ---------- textures ----------
used_tex = set()
mapdata = {}
for m in maps:
    d = json.load(open(os.path.join(SRC, m['id'] + '.json')))
    mapdata[m['id']] = d
    for mt in d['mats']:
        for k in ('map', 'amap'):
            if mt.get(k):
                used_tex.add(mt[k])
        if mt.get('det'):
            used_tex.add(mt['det']['map'])

tex_avg, tex_alpha = {}, {}
tex_size = 0
for tid in sorted(used_tex):
    meta = texmeta[tid]
    im = Image.open(os.path.join(SRC, 'tex', tid + '.png')).convert('RGBA')
    w, h = im.size
    alpha = im.getchannel('A')
    amin = alpha.getextrema()[0]
    grey = meta['kind'].startswith('gdet')
    info = {'w': w, 'h': h, 'kind': meta['kind']}
    # couleur moyenne (pixels opaques) : sert de teinte quand la texture n'est pas posée
    px = list(im.getdata())
    sr = sg = sb = sa = 0.0
    for r, g, b, a in px:
        k = a / 255.0
        sr += r * k; sg += g * k; sb += b * k; sa += k
    sa = max(sa, 1e-6)
    avg = [round(sr / sa), round(sg / sa), round(sb / sa)]
    info['avg'] = avg
    tex_avg[tid] = avg
    if grey:   # texture de détail du sol : gris centré sur 128 (multipliée par 2 dans le shader du web)
        info['fmt'] = 'g'
        raw = im.convert('L').tobytes()
        pal = b''
    elif amin < 250:
        info['fmt'] = 'pa'
        q = im.quantize(256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
        palr = q.getpalette('RGBA') or []
        pal = bytes(palr[:1024]).ljust(1024, b'\0')
        raw = q.tobytes()
    else:
        info['fmt'] = 'p'
        q = im.convert('RGB').quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
        pal = bytes(q.getpalette()[:768]).ljust(768, b'\0')
        raw = q.tobytes()
    tex_alpha[tid] = info['fmt'] == 'pa'
    info['pal'] = base64.b64encode(pal).decode()
    b = base64.b64encode(raw).decode()
    parts = [b[i:i + CHUNK] for i in range(0, len(b), CHUNK)]
    info['px'] = parts[0]
    info['parts'] = len(parts)
    tex_size += write(os.path.join(OUTS, '_Tex', tid + '.lua'), HEAD + 'return ' + lua(info) + '\n')
    for k, p in enumerate(parts[1:], start=2):
        tex_size += write(os.path.join(OUTS, '_Tex', '%s_%d.lua' % (tid, k)), HEAD + 'return "%s"\n' % p)

# ---------- matériau Roblox d'après la texture du web ----------
KIND_MAT = {
    'plaster': 'Plaster', 'house': 'Plaster', 'crate': 'WoodPlanks', 'stone': 'Sandstone', 'barrel': 'Metal', 'plat': 'Pavement',
    'roof': 'Slate', 'pillar': 'Sandstone', 'conc': 'Concrete', 'cont': 'Metal', 'mcrate': 'Metal', 'mtop': 'DiamondPlate',
    'platI': 'DiamondPlate', 'pillarI': 'Concrete', 'wceil': 'WoodPlanks', 'corrug': 'CorrodedMetal', 'rock': 'Rock',
    'cabin': 'WoodPlanks', 'snowb': 'Snow', 'wdeck': 'WoodPlanks', 'deck': 'WoodPlanks', 'pole': 'Wood', 'bark': 'Wood',
    'brick': 'Brick', 'tomb': 'Slate', 'hay': 'Fabric', 'train': 'Metal', 'shelf': 'WoodPlanks', 'tuftsand': 'Grass',
    'tuftjungle': 'Grass', 'tufthaunt': 'Grass', 'leafbroad': 'Grass', 'leafMpalm': 'Grass', 'leafMfern': 'Grass', 'hwweb': 'Fabric',
}


def lum(c):
    return 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]


def convert_mat(mt):
    c = mt.get('c', [1, 1, 1])
    o = {'c': [round(min(1, max(0, v)) * 255) for v in c]}
    tex = mt.get('map')
    kind = mt.get('kind') or ''
    rmat = KIND_MAT.get(kind)
    if not rmat:
        rmat = 'Metal' if mt.get('mt', 0) >= 0.45 else 'SmoothPlastic'
        if 'leaf' in kind or 'tuft' in kind:
            rmat = 'Grass'
    e = mt.get('e')
    ei = mt.get('ei', 1)
    neon = False
    if e and max(e) * ei >= 0.45:
        neon = True
        o['c'] = [round(min(1, v * min(ei, 1.5) + c[i] * 0.2) * 255) for i, v in enumerate(e)]
    if mt.get('t') == 'Basic' and not tex and lum(c) > 0.6 and mt.get('o', 1) >= 0.99:
        neon = True
    if neon:
        rmat = 'Neon'
    alpha = 0.0
    if mt.get('tr') or mt.get('o', 1) < 1:
        alpha = 1 - mt.get('o', 1)
    if mt.get('add'):
        alpha = max(alpha, 0.6)
    if tex:
        o['tex'] = tex
        o['rep'] = mt.get('rep', [1, 1])
        if any(abs(v) > 1e-4 for v in mt.get('off', [0, 0])):
            o['off'] = mt['off']
        a = tex_avg[tex]
        o['avg'] = [round(o['c'][i] * a[i] / 255) for i in range(3)]
        if tex_alpha.get(tex) or mt.get('at', 0) > 0:
            o['cut'] = True    # texture découpée (feuilles, toiles, ombres) : seule la texture se voit
    else:
        o['avg'] = o['c']
    if mt.get('det'):
        o['det'] = {'tex': mt['det']['map'], 'rep': mt['det']['rep'], 'str': mt['det']['str']}
    if alpha > 0.01:
        o['a'] = round(alpha, 3)
    if mt.get('ds'):
        o['ds'] = True
    if mt.get('vc'):
        o['vc'] = True
    if mt.get('fs'):
        o['fs'] = True
    o['rm'] = rmat
    if rmat in ('Metal', 'SmoothPlastic') and mt.get('r', 1) < 0.3:
        o['refl'] = round(min(0.35, (0.3 - mt['r']) * (0.5 + mt.get('mt', 0))), 3)
    return o


def quat_z_to(d):
    """Quaternion qui amène l'axe +Z sur le vecteur unitaire d."""
    x, y, z = d
    # rotation de (0,0,1) vers d
    dot = z
    if dot > 0.999999:
        return (0, 0, 0, 1)
    if dot < -0.999999:
        return (0, 1, 0, 0)
    ax = (-y, x, 0.0)
    s = math.sqrt((1 + dot) * 2)
    return (ax[0] / s, ax[1] / s, ax[2] / s, s / 2)


def c8(c):
    return [max(0, min(255, round(v * 255))) for v in c]


# ---------- primitives : fusion des blocs identiques et voisins (murs, plafonds, poutres) ----------
def merge_boxes(boxes):
    out = [b for b in boxes if not is_axis(b)]
    groups = {}
    for b in boxes:
        if not is_axis(b):
            continue
        key = (tuple(round(v, 3) for v in b['s']), tuple(b['f']), tuple(b['c']) if b.get('c') else None, b.get('pl', 0), b.get('sh', 0))
        groups.setdefault(key, []).append(b)
    for key, lst in groups.items():
        # chaque bloc : [x0,x1,y,z0,z1] (bornes en m) + taille d'une répétition
        items = [{'x0': b['p'][0] - b['s'][0] / 2, 'x1': b['p'][0] + b['s'][0] / 2, 'y': b['p'][1], 'z0': b['p'][2] - b['s'][2] / 2,
                  'z1': b['p'][2] + b['s'][2] / 2, 'b': b} for b in lst]
        for axis in ('x', 'z'):
            a0, a1, o0, o1 = (('x0', 'x1', 'z0', 'z1') if axis == 'x' else ('z0', 'z1', 'x0', 'x1'))
            items.sort(key=lambda it: (round(it['y'], 3), round(it[o0], 3), round(it[o1], 3), it[a0]))
            res = []
            for it in items:
                if res:
                    pr = res[-1]
                    if (abs(pr['y'] - it['y']) < 1e-3 and abs(pr[o0] - it[o0]) < 1e-3 and abs(pr[o1] - it[o1]) < 1e-3
                            and abs(pr[a1] - it[a0]) < 1e-3 and (pr[a1] - pr[a0]) < 60):
                        pr[a1] = it[a1]
                        continue
                res.append(dict(it))
            items = res
        for it in items:
            b = it['b']
            nb = dict(b)
            nb['p'] = [(it['x0'] + it['x1']) / 2, it['y'], (it['z0'] + it['z1']) / 2]
            nb['s'] = [it['x1'] - it['x0'], b['s'][1], it['z1'] - it['z0']]
            nb['ts'] = b['s']
            out.append(nb)
    return out


def is_axis(b):
    q = b['q']
    return abs(q[0]) < 1e-4 and abs(q[1]) < 1e-4 and abs(q[2]) < 1e-4


def prim_rec(kind, flags, p, s, ts, q, mats, col):
    q = list(q)
    n = math.sqrt(sum(v * v for v in q)) or 1
    q = [max(-32767, min(32767, round(v / n * 32767))) for v in q]
    mats = [NONE if (m is None or m < 0) else m for m in mats] + [NONE] * (6 - len(mats))
    col = col or [255, 255, 255]
    return struct.pack('<BB3f3f3f4h6H3BB', kind, flags, *p, *s, *ts, *q, *mats[:6], *col, 0)


THEME_KEYS = ('sky', 'fog', 'fogN', 'fogF', 'hemiS', 'hemiG', 'hemiI', 'sunC', 'sunI', 'sunPos', 'exp', 'stars', 'base', 'tint', 'cov', 'cloud')


def grid_str(arr):
    """Tableau de 1600 valeurs -> (palette, chaîne d'un caractère par case)."""
    pal = []
    for v in arr:
        if v not in pal:
            pal.append(v)
    assert len(pal) < 90, len(pal)
    return pal, ''.join(chr(35 + pal.index(v)) for v in arr)


report = []
mapdata_lua = []
total_scene = tex_size
for mm in maps:
    mid = mm['id']
    d = mapdata[mid]
    folder = os.path.join(OUTS, mid)
    os.makedirs(folder, exist_ok=True)
    # matériaux : dédoublonnés par contenu
    mats, mkey, remap = [], {}, []
    for mt in d['mats']:
        cm = convert_mat(mt)
        k = json.dumps(cm, sort_keys=True)
        if k not in mkey:
            mkey[k] = len(mats); mats.append(cm)
        remap.append(mkey[k])
    R = lambda i: remap[i] if (i is not None and i >= 0) else -1
    # primitives
    boxes = []
    for b in d['boxes']:
        nb = dict(b); nb['f'] = [R(f) for f in b['f']]
        if all(f < 0 for f in nb['f']):
            continue
        nb['c'] = c8(b['c']) if b.get('c') else None
        boxes.append(nb)
    for g in d['glows']:   # fils des guirlandes -> fines poutres
        if g.get('line'):
            a, b = g['a'], g['b']
            v = [b[i] - a[i] for i in range(3)]
            L = math.sqrt(sum(x * x for x in v))
            if L < 1e-3:
                continue
            k = len(mats)
            key = json.dumps({'c': c8(g['c']), 'avg': c8(g['c']), 'rm': 'Fabric'}, sort_keys=True)
            if key not in mkey:
                mkey[key] = len(mats); mats.append({'c': c8(g['c']), 'avg': c8(g['c']), 'rm': 'Fabric'})
            boxes.append({'p': [(a[i] + b[i]) / 2 for i in range(3)], 'q': list(quat_z_to([x / L for x in v])), 's': [0.03, 0.03, L],
                          'f': [mkey[key]] * 6, 'c': None, 'pl': 0, 'sh': 0})
    nbox0 = len(boxes)
    boxes = merge_boxes(boxes)
    prim = bytearray()
    for b in boxes:
        fl = (1 if b.get('pl') else 0) | (2 if b.get('sh') else 0) | (4 if b.get('c') else 0)
        prim += prim_rec(0, fl, b['p'], b['s'], b.get('ts', b['s']), b['q'], b['f'], b.get('c'))
    for b in d['balls']:
        fl = (2 if b.get('sh') else 0) | (4 if b.get('c') else 0)
        prim += prim_rec(1, fl, b['p'], b['s'], b['s'], b['q'], [R(b['m'])], c8(b['c']) if b.get('c') else None)
    for b in d['cyls']:
        fl = (2 if b.get('sh') else 0) | (4 if b.get('c') else 0)
        prim += prim_rec(2, fl, b['p'], [b['h'], b['d'], b['d']], [b['h'], b['d'], b['d']], b['q'], [R(b['m']), R(b['mc'])], c8(b['c']) if b.get('c') else None)
    nprim = len(boxes) + len(d['balls']) + len(d['cyls'])
    # maillages
    matlists, mlkey = [], {}
    used_geo = {}
    insts = bytearray()
    for me in d['meshes']:
        ml = [R(x) for x in me['m']]
        k = tuple(ml)
        if k not in mlkey:
            mlkey[k] = len(matlists); matlists.append(ml)
        if me['g'] not in used_geo:
            used_geo[me['g']] = len(used_geo)
        fl = (1 if me.get('c') else 0) | (2 if me.get('sh') else 0)
        insts += struct.pack('<HH3BB12f', used_geo[me['g']], mlkey[k], *(c8(me['c']) if me.get('c') else [255, 255, 255]), fl, *me['M'])
    geob = bytearray()
    nverts = 0
    for gi, _ in sorted(used_geo.items(), key=lambda kv: kv[1]):
        g = d['geos'][gi]
        nv = g['nv']
        P = g['pos']
        idx = g['idx'] if g['idx'] is not None else list(range(nv))
        ni = len(idx)
        groups = g['groups'] or [[0, ni, 0]]
        groups = [[gr[0], min(int(gr[1]) if gr[1] is not None and gr[1] < 1e12 else ni, ni - gr[0]), gr[2]] for gr in groups]
        lo = [min(P[i::3]) for i in range(3)]
        hi = [max(P[i::3]) for i in range(3)]
        fl = (1 if g.get('nrm') else 0) | (2 if g.get('uv') else 0) | (4 if g.get('col') else 0)
        geob += struct.pack('<IIBB6f', nv, ni, fl, len(groups), *lo, *hi)
        for gr in groups:
            geob += struct.pack('<IIB', gr[0], max(0, gr[1]), gr[2])
        for i in range(nv):
            for k in range(3):
                ext = hi[k] - lo[k]
                geob += struct.pack('<H', 0 if ext < 1e-9 else max(0, min(65535, round((P[i * 3 + k] - lo[k]) / ext * 65535))))
        if g.get('nrm'):
            Nn = g['nrm']
            geob += bytes(struct.pack('<%db' % (nv * 3), *[max(-127, min(127, round(v * 127))) for v in Nn]))
        if g.get('uv'):
            geob += struct.pack('<%dh' % (nv * 2), *[max(-32767, min(32767, round(v * 2048))) for v in g['uv']])
        if g.get('col'):
            geob += bytes(c8(g['col']))
        geob += struct.pack('<%d%s' % (ni, 'I' if nv > 65535 else 'H'), *idx)
        nverts += nv
    meshblob = struct.pack('<II', len(used_geo), len(d['meshes'])) + bytes(geob) + bytes(insts)
    n = 1
    pnames, n, s1 = blobs(folder, 'B', bytes(prim), n)
    mnames, n, s2 = blobs(folder, 'B', meshblob, n)
    # lumières (vraies lampes du web) et halos (sprites lumineux)
    lights = [{'p': L['p'], 'c': c8(L['c']), 'i': L['i'], 'd': L['d']} for L in d['lights']]
    glows = [{'p': g['p'], 's': g['s'], 'c': c8([min(1, v) for v in g['c']]), 'o': g.get('o', 1)} for g in d['glows'] if not g.get('line') and g['s'] < 60]
    th = {k: d['theme'][k] for k in THEME_KEYS if k in d['theme']}
    info = {'id': mid, 'mats': mats, 'matlists': matlists, 'prims': pnames, 'nprims': nprim, 'meshes': mnames, 'ninst': len(d['meshes']),
            'lights': lights, 'glows': glows, 'theme': th}
    s3 = write(os.path.join(folder, 'Info.lua'), HEAD + '-- Carte « %s » : matériaux, lampes, halos, ambiance ; les primitives et maillages sont dans les modules B<n>.\nreturn %s\n' % (d['meta']['n'], lua(info)))
    total_scene += s1 + s2 + s3
    report.append('%-9s %4d prim. (%d blocs avant fusion) %4d inst. %3d géo %6d sommets %3d mat. %2d lampes %3d halos  %6.0f Ko' % (
        mid, nprim, nbox0, len(d['meshes']), len(used_geo), nverts, len(mats), len(lights), len(glows), (s1 + s2 + s3) / 1024))
    # ---------- grille de jeu ----------
    G = d['grid']
    meta = d['meta']
    fields = {}
    for k in ('type', 'h', 'ceil', 'ramp', 'tag'):
        pal, s = grid_str(G[k])
        fields[k] = (pal, s)
    md = {'id': mid, 'name': meta['n'], 'theme': meta['theme'], 'base': meta.get('base'), 'desc': meta.get('desc', '')}
    for k in ('sites', 'pickups', 'spawnCT', 'spawnT', 'spawnDM', 'holdCT', 'roam', 'arches', 'koth', 'targets', 'zdoors', 'zombie', 'ev'):
        if k in meta:
            v = meta[k]
            if k == 'sites':
                v = [{'n': s['n'], 'cx': s['cx'], 'cz': s['cz'], 'r': s['r']} for s in v]
            md[k] = v
    md['ramps'] = G['ramps']
    gl = ['\tgrid = {']
    for k in ('type', 'h', 'ceil', 'ramp', 'tag'):
        pal, s = fields[k]
        gl.append('\t\t%s = { %s, "%s" },' % (k, lua(pal), s.replace('\\', '\\\\').replace('"', '\\"')))
    gl.append('\t},')
    body = lua(md)[2:-2]
    mapdata_lua.append('MapData.%s = {\n\t%s,\n%s\n}\n' % (mid, body, '\n'.join(gl)))

order = [m['id'] for m in maps]
md_text = '--!nocheck\n' + HEAD.replace('tools/export_scene.js', 'tools/export_scene.js : grille, points, sites, zones') + '''
-- Grille de jeu des 10 cartes du web, relevée sur le jeu en marche (cases, hauteurs, rampes, plafonds, sols),
-- avec les points d'apparition corrigés par l'audit du web. 1 case = 2 m.
local MapData: any = {}

local N = 40
local TY = { OPEN = 0, WALL = 1, CRATE = 2, HOUSE = 3, LOW = 4, BARREL = 5, PLAT = 6, CONT = 7, CONC = 8, PILLAR = 9 }
local TYH = { [0] = 0, 6, 2.6, 4.6, 0.9, 1.1, 3, 2.7, 5.4, 6 }
MapData.N, MapData.TY, MapData.TYH = N, TY, TYH
MapData.ORDER = %s

''' % lua(order) + '\n'.join(mapdata_lua) + '''
-- Grille d'une carte : tableaux indexés de 0 à N*N-1 (comme G_TYPE, G_H, G_CEIL, G_RAMP, G_TAG du web) + rampes
local cache: { [string]: any } = {}
function MapData.buildGrid(id: string): any
	if cache[id] then return cache[id] end
	local m = MapData[id]
	local g: any = { ramps = m.ramps, map = m }
	for k, enc in pairs(m.grid) do
		local pal, s = enc[1], enc[2]
		local t = table.create(N * N)
		for i = 1, #s do t[i - 1] = pal[string.byte(s, i) - 34] end
		g[k] = t
	end
	cache[id] = g
	return g
end

return MapData
'''
md_size = write(os.path.join(ROOT, 'MapData.lua'), md_text)
print('\n'.join(report))
print('textures : %d (%.0f Ko) ; total MapScenes %.1f Mo ; MapData.lua %.0f Ko' % (len(used_tex), tex_size / 1024, total_scene / 1048576, md_size / 1024))
