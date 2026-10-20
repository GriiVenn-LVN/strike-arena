#!/usr/bin/env python3
"""Peintures haute qualité des skins (512 px, comme le web) et leurs cartes, pour l'envoi depuis Studio (MeshUploader).

Usage (depuis la racine du dépôt) : python3 tools/skins_hq_to_lua.py <dossier de export_skins.js>
  -> roblox/ServerStorage/SkinTexturesHQ/<motif>.lua    peinture 512 px (clé « i:sk3:<motif> »), usure comprise
  -> roblox/ServerStorage/SkinTexturesHQ/<motif>#r.lua  rugosité du skin (skinRough du web × finition, 256 px, « #r »)
  -> roblox/ServerStorage/SkinTexturesHQ/<motif>#m.lua  métal : finition du skin, métal nu dans les éclats d'usure (« #m »)
  -> roblox/ServerStorage/SkinTexturesHQ/<motif>#n.lua  carte de normales des skins gravés (relief HQH du web, « #n »)
  -> roblox/ServerStorage/SkinTexturesHQ/<motif>#g.lua  masque lumineux des skins néon (gris 256 px, « #g »)
Rangées dans ServerStorage : seul MeshUploader les lit (rien n'est envoyé aux joueurs). Tant qu'une image n'est pas envoyée,
SkinPaint garde la peinture 128 px de ReplicatedStorage/Shared/SkinTextures (tools/skins_to_lua.py) et les cartes par finition.

Compression (décodée par ServerStorage/SkinInflate + SkinPaint.hqFill, en Studio seulement) :
  * le grain d'un pixel du web (hqFinish) est retiré puis recalculé à l'identique au décodage (même générateur xorshift) ;
  * peinture en YCoCg : luminance 512 px, couleur 256 px (comme un JPEG), luminance quantifiée par pas de 3,
    couleur et cartes par pas de 2 ;
  * chaque plan est prédit (MED, comme PNG/JPEG-LS : reste = valeur - prédiction) puis compressé en deflate, en base64.
"""
import base64, json, os, sys, zlib
import numpy as np
from PIL import Image

SRC = sys.argv[1] if len(sys.argv) > 1 else 'skins_out'
OUT = os.path.join(os.path.dirname(__file__), '..', 'roblox', 'ServerStorage', 'SkinTexturesHQ')
STEP = 2
YSTEP = 3        # luminance de la peinture : pas de 3 (le grain recalculé par-dessus cache les marches)
# finitions du web (FIN, src/44_skins.js) : m = metalness, r = roughness
FIN = {'matte': (.5, .55), 'gloss': (.65, .24), 'chrome': (1, .12), 'anod': (.9, .3), 'pearl': (.85, .16), 'paint': (.3, .42)}

def hash_str(s):
    h = 2166136261
    for ch in s:
        h ^= ord(ch); h = (h * 16777619) & 0xffffffff
    return h

# ---------- grain de hqFinish (src/44d_skinhq.js) : x ^= x<<13, x ^= x>>>17, x ^= x<<5 ----------
def grain(kind, n):
    x = ((hash_str(kind) & 1023) * 9973) & 0xffffffff
    seed = x
    out = np.empty(n, np.float32)
    for i in range(n):
        x ^= (x << 13) & 0xffffffff; x ^= x >> 17; x ^= (x << 5) & 0xffffffff
        out[i] = ((x & 255) - 128) * .04
    return out, seed

# ---------- bruit du web (hqHash, vnoise, fbm), à l'identique en entiers 32 bits ----------
def hq_hash(x, y, s):
    U = np.uint32
    h = (x.astype(U) * U(374761393) + y.astype(U) * U(668265263) + U((s + 1) & 0xffffffff) * U(1442695041))
    h = (h ^ (h >> U(13))) * U(1274126177)
    return (h ^ (h >> U(16))).astype(np.float64) / 4294967296

def vnoise(u, v, P, s):
    x, y = u * P, v * P
    ix, iy = np.floor(x), np.floor(y)
    fx, fy = x - ix, y - iy
    x0, y0 = (ix % P).astype(np.int64), (iy % P).astype(np.int64)
    x1, y1 = (x0 + 1) % P, (y0 + 1) % P
    a, b, c, d = hq_hash(x0, y0, s), hq_hash(x1, y0, s), hq_hash(x0, y1, s), hq_hash(x1, y1, s)
    sx, sy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    return a + (b - a) * sx + (c - a) * sy + (a - b - c + d) * sx * sy

def fbm(u, v, P, oct, s):
    t, amp, n = 0, .5, 0
    for i in range(oct):
        t = t + amp * vnoise(u, v, P, s + i * 31); n += amp; amp *= .5; P *= 2
    return t / n

def sstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)

def grid(n):
    v, u = np.mgrid[0:n, 0:n] / n
    return u, v

# usure (même zones que la carte de rugosité du web : wear = sstep(.6,.75,fbm(u,v,3,4,s+17))) : dans ces zones, la
# peinture s'écaille par petites plaques (éclats) qui laissent voir l'acier, avec un liseré plus clair sur le bord
def chips(kind, n):
    s = hash_str(kind) & 1023
    u, v = grid(n)
    wear = sstep(.6, .75, fbm(u, v, 3, 4, s + 17))
    f = fbm(u, v, 32, 3, s + 29)
    bare = wear * sstep(.55, .565, f)
    rim = wear * sstep(.5, .55, f) * (1 - bare)
    return bare, rim, u, v, s

# ---------- encodage ----------
def med(q):
    a = np.zeros_like(q); b = np.zeros_like(q); c = np.zeros_like(q)
    a[:, 1:] = q[:, :-1]; b[1:, :] = q[:-1, :]; c[1:, 1:] = q[:-1, :-1]
    mx, mn = np.maximum(a, b), np.minimum(a, b)
    p = np.where(c >= mx, mn, np.where(c <= mn, mx, a + b - c))
    return ((q - p) & 255).astype(np.uint8).tobytes()

def planes(chs, steps=None):
    steps = steps or [STEP] * len(chs)
    return b''.join(med(np.clip(np.round(c / st), 0, 255 // st).astype(np.int32)) for c, st in zip(chs, steps))

def deflate(data):
    co = zlib.compressobj(9, zlib.DEFLATED, -15, 9)
    return base64.b64encode(co.compress(data) + co.flush()).decode()

def half(x):
    n = x.shape[0] // 2
    return x.reshape(n, 2, n, 2).mean(axis=(1, 3))

def write(name, what, kind, size, z, seed=None, step=STEP):
    extra = (', cstep = %d' % STEP if kind == 'ycc' else '') + (', seed = %d' % seed if seed is not None else '')
    body = ('-- Généré par tools/skins_hq_to_lua.py (%s) : ne pas modifier à la main.\n'
            'return { kind = "%s", size = %d, step = %d%s,\n z = "%s" }\n') % (what, kind, size, step, extra, z)
    open(os.path.join(OUT, name + '.lua'), 'w').write(body)
    return len(body)

def main():
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.endswith('.lua'):
            os.remove(os.path.join(OUT, f))
    meta = json.load(open(os.path.join(SRC, 'skins.json')))
    fin_of = {s['tex']: (s.get('fin') or 'gloss') for s in meta if s.get('tex') and not s.get('anim')}
    total, n, cover = 0, 0, []
    for f in sorted(os.listdir(SRC)):
        if not f.endswith('@512.png'):
            continue
        tex = f[:-len('@512.png')]
        m, r = FIN.get(fin_of.get(tex, 'gloss'), FIN['gloss'])
        # peinture : grain retiré (recalculé au décodage), éclats d'usure, YCoCg
        a = np.asarray(Image.open(os.path.join(SRC, f)).convert('RGB')).astype(np.float64)
        N = a.shape[0]
        g, seed = grain(tex, N * N)
        a = np.clip(np.round(a - g.reshape(N, N, 1)), 0, 255)
        bare, rim, u, v, s = chips(tex, N)
        steel = 128 + 30 * fbm(u, v, 8, 2, s + 41)
        k = bare[..., None]
        a = a * (1 - k) + steel[..., None] * np.array([1, 1.02, 1.06]) * k
        a = np.clip(a + rim[..., None] * 22, 0, 255)
        cover.append(float((bare > .5).mean()))
        R, G, B = a[..., 0], a[..., 1], a[..., 2]
        Y = (R + 2 * G + B) / 4
        Co = (R - B) / 2 + 128
        Cg = (-R + 2 * G - B) / 4 + 128
        total += write(tex, 'peinture « %s » du jeu web, 512 px' % tex, 'ycc', N, deflate(planes([Y, half(Co), half(Cg)], [YSTEP, STEP, STEP])), seed, YSTEP)
        n += 1
        # rugosité du skin (web : roughness = r × 1,5 × carte)
        rp = os.path.join(SRC, tex + '#r.png')
        if os.path.exists(rp):
            l = np.asarray(Image.open(rp).convert('L')).astype(np.float64)
            total += write(tex + '#r', 'rugosité « %s » du jeu web' % tex, 'gray', l.shape[0], deflate(planes([l * min(1, r * 1.5)])))
            n += 1
        # métal : celui de la finition, acier nu (1) dans les éclats
        b2, _, _, _, _ = chips(tex, 256)
        total += write(tex + '#m', 'métal « %s » et usure' % tex, 'gray', 256, deflate(planes([255 * (m + (1 - m) * b2)])))
        n += 1
        np_ = os.path.join(SRC, tex + '#n.png')
        if os.path.exists(np_):
            nm = np.asarray(Image.open(np_).convert('RGB')).astype(np.float64)
            total += write(tex + '#n', 'relief « %s » du jeu web (carte de normales)' % tex, 'rgb', nm.shape[0],
                           deflate(planes([nm[..., 0], nm[..., 1], nm[..., 2]])))
            n += 1
        gp = os.path.join(SRC, tex + '#g.png')
        if os.path.exists(gp):
            gm = np.asarray(Image.open(gp).convert('L')).astype(np.float64)
            total += write(tex + '#g', 'masque lumineux « %s » du jeu web' % tex, 'gray', gm.shape[0], deflate(planes([gm])))
            n += 1
    print('%d images, %.1f Ko ; usure : %.1f %% de la surface en moyenne (max %.1f %%)'
          % (n, total / 1024, 100 * sum(cover) / max(1, len(cover)), 100 * max(cover or [0])))

if __name__ == '__main__':
    main()
