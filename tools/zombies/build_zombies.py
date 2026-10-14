#!/usr/bin/env python3
"""
Zombies réalistes : prépare les modèles du mode Zombies.

Source : personnages photo-réalistes et animations de Mesh2Motion
(https://github.com/scottpetrovic/mesh2motion-app, dossier static/),
tous en CC0 (modèles d'elbolilloduro, animations Quaternius / Mesh2Motion).
Tous partagent le même squelette humain (66 os), donc une seule
banque d'animations sert à tous les modèles.

Sorties (dans models/characters/, intégrées par tools/embed_models.pl) :
  zanim_game.glb      squelette + clips choisis (sans maillage)
  z_<nom>_game.glb    maillage + texture « zombifiée » en JPEG

Usage : python3 tools/zombies/build_zombies.py <dossier static de mesh2motion-app>
Dépendances : numpy, Pillow.
"""
import io, json, struct, sys, os
import numpy as np
from PIL import Image, ImageFilter

SRC = sys.argv[1] if len(sys.argv) > 1 else 'mesh2motion-app/static'
OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'models', 'characters')

# modèle source -> (nom dans le jeu, traitement de la texture)
MODELS = {
    'male_5': ('civ1', 'civil'), 'male_6': ('civ2', 'civil'), 'male_10': ('civ3', 'civil'),
    'male_15': ('civ4', 'civil'), 'male_32': ('civ5', 'civil'),
    'female_8': ('civ6', 'civil'), 'female_9': ('civ7', 'civil'), 'female_31': ('civ8', 'civil'),
    'doctor_m': ('doc', 'civil'), 'police_male': ('cop1', 'civil'), 'police_female': ('cop2', 'civil'),
    'hazmat_suit_male': ('hazmat', 'suit'), 'swat_male': ('swat', 'suit'),
    'monster_3': ('ghoul', 'monster'), 'monster_5': ('rotten', 'monster'), 'monster_4': ('brute', 'monster'),
}
# (fichier, clip source, nom dans le jeu)
CLIPS = [
    ('human-base', 'Zombie_Walk', 'Walk'), ('human-addon', 'Zombie_Walk_2', 'Walk2'),
    ('human-addon', 'Walk_Large', 'Stomp'),
    ('human-base', 'Sprint', 'Run'), ('human-base', 'Jog', 'Jog'),
    ('human-base', 'Zombie_Idle', 'Idle'), ('human-addon', 'Zombie Yell', 'Yell'),
    ('human-base', 'Zombie_Scratch', 'Punch'), ('human-addon', 'Crawl', 'Crawl'),
    ('human-addon', 'Zombie_Rise', 'Rise'),
    ('human-addon', 'Death_A', 'Death'), ('human-addon', 'Death_B', 'Death2'), ('human-base', 'Death_D', 'Death3'),
    ('human-base', 'Hit_Chest', 'HitReact'), ('human-base', 'Hit_Head', 'HitHead'),
]
FPS = 15  # images clés gardées par seconde

TY = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5122: np.int16, 5121: np.uint8, 5120: np.int8}
NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}


def read_glb(path):
    b = open(path, 'rb').read()
    jl = struct.unpack('<I', b[12:16])[0]
    j = json.loads(b[20:20 + jl])
    bl = struct.unpack('<I', b[20 + jl:24 + jl])[0]
    return j, b[28 + jl:28 + jl + bl]


def bv_bytes(j, binb, i):
    bv = j['bufferViews'][i]
    o = bv.get('byteOffset', 0)
    return binb[o:o + bv['byteLength']]


def accessor(j, binb, i):
    a = j['accessors'][i]
    bv = j['bufferViews'][a['bufferView']]
    T, n = TY[a['componentType']], NC[a['type']]
    o = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    st = bv.get('byteStride', 0)
    es = np.dtype(T).itemsize
    if st and st != n * es:
        raw = np.frombuffer(binb, np.uint8, a['count'] * st, o).reshape(a['count'], st)[:, :n * es]
        return np.ascontiguousarray(raw).view(T).reshape(a['count'], n)
    return np.frombuffer(binb, T, a['count'] * n, o).reshape(a['count'], n)


class Builder:
    """Assemble un nouveau .glb : chaque vue de tampon est alignée sur 4 octets."""
    def __init__(self, j):
        self.j = j
        self.bin = bytearray()
        j['bufferViews'] = []
        j['accessors'] = []

    def view(self, data, target=None):
        while len(self.bin) % 4:
            self.bin += b'\0'
        v = {'buffer': 0, 'byteOffset': len(self.bin), 'byteLength': len(data)}
        if target:
            v['target'] = target
        self.bin += data
        self.j['bufferViews'].append(v)
        return len(self.j['bufferViews']) - 1

    def acc(self, arr, typ, minmax=False, target=None, normalized=False):
        arr = np.ascontiguousarray(arr)
        ct = {np.float32: 5126, np.uint32: 5125, np.uint16: 5123, np.int16: 5122, np.uint8: 5121, np.int8: 5120}[arr.dtype.type]
        a = {'bufferView': self.view(arr.tobytes(), target), 'componentType': ct, 'count': int(arr.shape[0]), 'type': typ}
        if normalized:
            a['normalized'] = True
        if minmax:
            a['min'] = arr.min(0).tolist()
            a['max'] = arr.max(0).tolist()
        self.j['accessors'].append(a)
        return len(self.j['accessors']) - 1

    def write(self, path):
        while len(self.bin) % 4:
            self.bin += b'\0'
        self.j['buffers'] = [{'byteLength': len(self.bin)}]
        js = json.dumps(self.j, separators=(',', ':')).encode()
        while len(js) % 4:
            js += b' '
        out = struct.pack('<III', 0x46546C67, 2, 28 + len(js) + len(self.bin))
        out += struct.pack('<II', len(js), 0x4E4F534A) + js
        out += struct.pack('<II', len(self.bin), 0x004E4942) + bytes(self.bin)
        open(path, 'wb').write(out)
        return len(out)


# ---------------------------------------------------------------- textures
def fbm(shape, rng, scales=(64, 24, 8), weights=(.6, .3, .1)):
    """bruit doux (somme de bruits agrandis), valeurs ~0..1"""
    h, w = shape
    acc = np.zeros(shape, np.float32)
    for s, wt in zip(scales, weights):
        small = rng.random((max(2, h // s), max(2, w // s))).astype(np.float32)
        im = Image.fromarray((small * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
        acc += wt * np.asarray(im, np.float32) / 255
    return acc / sum(weights)


def zombify(img, kind, seed):
    rng = np.random.default_rng(seed)
    a = np.asarray(img.convert('RGB'), np.float32) / 255
    h, w, _ = a.shape
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    lum = .3 * r + .59 * g + .11 * b
    mx, mn = a.max(2), a.min(2)
    sat = (mx - mn) / np.maximum(mx, 1e-3)
    # peau : rouge > vert > bleu, saturation modérée
    skin = ((r > g) & (g > b * .95) & (sat > .12) & (sat < .72) & (mx > .22)).astype(np.float32)
    skin = np.asarray(Image.fromarray((skin * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2)), np.float32) / 255
    if kind == 'monster':
        skin *= 0
    n1, n2, n3 = fbm((h, w), rng), fbm((h, w), rng, (32, 12, 4)), fbm((h, w), rng, (16, 6, 2))
    out = a.copy()
    # 1) peau morte : grise, verdâtre, marbrée de bleus violacés, veines sombres
    dead = np.stack([lum * .86, lum * .87, lum * .76], -1) * (0.9 + .35 * (n2[..., None] - .5))
    bruise = np.clip((n1 - .55) * 3, 0, 1)[..., None]
    dead = dead * (1 - .55 * bruise) + bruise * .55 * np.stack([lum * .62, lum * .42, lum * .58], -1)
    veins = np.clip(1 - np.abs(n3 - .5) * 22, 0, 1)[..., None] * .35
    dead = dead * (1 - veins) + veins * np.array([.18, .2, .22])
    out = out * (1 - skin[..., None]) + dead * skin[..., None]
    # 2) vêtements : délavés, sales, tachés de terre
    if kind != 'monster':
        cl = 1 - skin[..., None]
        grey = (.3 * out[..., 0] + .59 * out[..., 1] + .11 * out[..., 2])[..., None]
        washed = out * .55 + grey * .45
        dirt = (.62 + .45 * n1)[..., None] * np.array([1, .96, .86])
        mud = np.clip((n2 - .6) * 3, 0, 1)[..., None]
        washed = washed * dirt * (1 - .5 * mud) + mud * .5 * np.array([.22, .17, .1])
        out = out * (1 - cl) + washed * cl
    # 3) sang : éclaboussures irrégulières (+ coulures), en partie sur la peau (visage, mains)
    blood = np.zeros((h, w), np.float32)
    nb = {'civil': 26, 'suit': 22, 'monster': 10}[kind]
    ys, xs = np.nonzero(skin > .5)
    yy, xx = np.mgrid[0:h, 0:w]
    for k in range(nb):
        if len(ys) and k % 3 == 0:
            i = rng.integers(len(ys))
            cy, cx = ys[i], xs[i]
        else:
            cy, cx = rng.integers(h), rng.integers(w)
        rad = rng.uniform(3, 16) * w / 512
        ang = rng.uniform(0, np.pi)
        el = rng.uniform(1, 2.6)   # traînées allongées
        u = ((xx - cx) * np.cos(ang) + (yy - cy) * np.sin(ang)) / (rad * el)
        v = (-(xx - cx) * np.sin(ang) + (yy - cy) * np.cos(ang)) / rad
        d = np.hypot(u, v)
        blob = np.clip((1.05 - d - (n3 - .5) * 2.6 - (n2 - .5) * 1.2) * 2.5, 0, 1)
        blood = np.maximum(blood, blob * rng.uniform(.55, 1))
        for _ in range(rng.integers(0, 4)):   # coulures
            dx = cx + rng.uniform(-rad, rad)
            ln = rng.uniform(2, 6) * rad
            wd = rng.uniform(.8, 2.2) * w / 512
            drip = np.clip(1 - np.abs(xx - dx) / wd, 0, 1) * ((yy > cy) & (yy < cy + ln)) * np.clip(1 - (yy - cy) / ln, 0, 1)
            blood = np.maximum(blood, drip * .8)
    # petites gouttes autour, et texture irrégulière à l'intérieur des taches
    specks = (rng.random((h, w)) > .9985).astype(np.uint8) * 255
    specks = np.asarray(Image.fromarray(specks).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(.8)), np.float32) / 255
    near = np.asarray(Image.fromarray((blood * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(14)), np.float32) / 255
    blood = np.maximum(blood * (.62 + .38 * fbm((h, w), rng, (6, 3, 1))), np.clip(specks * near * 4, 0, 1))
    dry = n2[..., None]
    bcol = np.array([.34, .025, .02]) * (1 - .45 * dry) + np.array([.16, .04, .03]) * .45 * dry
    out = out * (1 - blood[..., None] * .92) + bcol * blood[..., None] * .92 * (.7 + .5 * lum[..., None])
    # 4) assombrissement général et contraste
    out = np.clip((out - .5) * 1.08 + .47, 0, 1) * (.92 if kind != 'monster' else .97)
    return Image.fromarray((out * 255 + .5).astype(np.uint8))


def build_model(src, name, kind, seed):
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
        old = orig[i]
        remap[i] = bld.view(data, old.get('target'))
        st = old.get('byteStride')
        if st:
            j['bufferViews'][remap[i]]['byteStride'] = st
    j['accessors'] = accs
    for a in accs:
        a['bufferView'] = remap[a['bufferView']]
    for im in imgs:
        tex = Image.open(io.BytesIO(views[im['bufferView']]))
        tex = zombify(tex, kind, seed)
        bio = io.BytesIO()
        tex.save(bio, 'JPEG', quality=74, optimize=True)
        im['bufferView'] = bld.view(bio.getvalue())
        im['mimeType'] = 'image/jpeg'
        im['name'] = name
    j.pop('animations', None)
    j['asset'] = {'version': '2.0', 'generator': 'tools/zombies/build_zombies.py (source CC0 Mesh2Motion)'}
    return bld.write(os.path.join(OUT, 'z_%s_game.glb' % name))


def build_anims():
    srcs = {k: read_glb(os.path.join(SRC, 'animations', k + '-animations.glb')) for k in ('human-base', 'human-addon')}
    j0, _ = srcs['human-base']
    skin = j0['skins'][0]
    names = [j0['nodes'][i]['name'] for i in skin['joints']]
    # squelette seul : mêmes noms d'os, hiérarchie d'origine (sans maillage)
    keep = {}
    def walk(i):
        keep[i] = len(keep)
        for c in j0['nodes'][i].get('children', []):
            walk(c)
    root = [n for n in j0['scenes'][0]['nodes']][0]
    walk(root)
    nodes = []
    for old, new in sorted(keep.items(), key=lambda x: x[1]):
        n = j0['nodes'][old]
        nn = {'name': n['name']}
        for k in ('translation', 'rotation', 'scale'):
            if k in n:
                nn[k] = n[k]
        ch = [keep[c] for c in n.get('children', []) if c in keep]
        if ch:
            nn['children'] = ch
        nodes.append(nn)
    out = {'asset': {'version': '2.0', 'generator': 'tools/zombies/build_zombies.py (animations CC0 Mesh2Motion/Quaternius)'},
           'scene': 0, 'scenes': [{'nodes': [0]}], 'nodes': nodes, 'animations': []}
    bld = Builder(out)
    for fk, cname, gname in CLIPS:
        j, binb = srcs[fk]
        an = next(a for a in j['animations'] if a['name'] == cname)
        nidx = {j['nodes'][i]['name']: i for i in range(len(j['nodes']))}
        newnode = {nodes[i]['name']: i for i in range(len(nodes))}
        chans, samps = [], []
        for ch in an['channels']:
            nm = j['nodes'][ch['target']['node']]['name']
            path = ch['target']['path']
            if nm not in newnode or path == 'scale' or any(f in nm for f in ('index_', 'middle_', 'ring_', 'pinky_')) or (path == 'translation' and nm != 'pelvis'):
                continue
            s = an['samplers'][ch['sampler']]
            t = accessor(j, binb, s['input'])[:, 0].astype(np.float32)
            v = accessor(j, binb, s['output']).astype(np.float32)
            if len(t) > 2 and s.get('interpolation', 'LINEAR') == 'LINEAR':
                nt = np.arange(0, t[-1], 1 / FPS, dtype=np.float32)
                nt = np.append(nt[nt < t[-1] - 1e-3], t[-1]).astype(np.float32)
                nv = np.stack([np.interp(nt, t, v[:, c]) for c in range(v.shape[1])], 1).astype(np.float32)
                if path == 'rotation':
                    nv /= np.linalg.norm(nv, axis=1, keepdims=True)
                t, v = nt, nv
            if len(t) > 1 and np.allclose(v, v[0], atol=1e-4):
                t, v = t[:1], v[:1]
            samps.append({'input': bld.acc(t.reshape(-1, 1), 'SCALAR', minmax=True),
                          'output': bld.acc(v, 'VEC4' if path == 'rotation' else 'VEC3'),
                          'interpolation': 'LINEAR'})
            chans.append({'sampler': len(samps) - 1, 'target': {'node': newnode[nm], 'path': path}})
        out['animations'].append({'name': gname, 'channels': chans, 'samplers': samps})
    return bld.write(os.path.join(OUT, 'zanim_game.glb'))


if __name__ == '__main__':
    print('zanim_game.glb', build_anims())
    for i, (src, (name, kind)) in enumerate(MODELS.items()):
        p = os.path.join(SRC, 'models-variation', 'human', src + '.glb')
        print('z_%s_game.glb' % name, build_model(p, name, kind, 1000 + i))
