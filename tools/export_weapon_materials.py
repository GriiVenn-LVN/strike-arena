#!/usr/bin/env python3
# Matériaux réalistes des armes stylisées (Roblox) : petites cartes génériques qui se répètent sans couture, posées en
# SurfaceAppearance sur les pièces que le skin ne peint pas (ReplicatedStorage/Shared/WeaponMaterials).
#   bruni  acier bruni / parkérisé (carcasses, culasses) : grain fin, micro-rayures, plaques d'usure plus claires
#   anod   aluminium anodisé (carcasses M4 / SCAR) : grain de sablage très fin, quelques rayures
#   poly   polymère grenu (poignées, garde-mains, chargeurs) : relief pointillé, usure lustrée
#   bois   bois vernis (crosses, garde-mains en bois) : veines le long de l'arme, vernis brillant
#   acier  acier poli / brossé (canons, culasses, pièces claires) : stries le long du canon, rayures
# Par matériau : c = carte de couleur en niveaux de gris (multipliée par la couleur de la pièce : SurfaceAppearance.Color),
# n = carte de normales (OpenGL, comme Roblox), r = rugosité. Le métal (m) est uni : MeshUploader le fabrique lui-même.
# Bruit périodique (filtré par FFT) et rayures tracées en boucle : les bords se raccordent. Les coordonnées de texture
# des armes stylisées (WeaponModels) suivent l'arme : u le long du canon, une répétition tous les 0,58 m.
# Sortie : roblox/ServerStorage/WeaponMatData (Info + modules D1..Dn en base64), lue seulement par l'envoi depuis Studio.
# Aperçus : python3 tools/export_weapon_materials.py <dossier> écrit aussi les cartes en PNG dans <dossier>.
# Usage (depuis la racine du dépôt) : python3 tools/export_weapon_materials.py
import io, os, sys, base64
import numpy as np
from PIL import Image

N = 512
OUT = 'roblox/ServerStorage/WeaponMatData'
CHUNK = 190000
HEAD = '-- Généré par tools/export_weapon_materials.py (cartes procédurales des matériaux des armes) : ne pas modifier à la main.\n'
rng = np.random.default_rng(20261020)


def noise(scale, aniso=1.0, seed=None):
    """bruit périodique : bruit blanc filtré dans l'espace des fréquences (scale = taille des grains en pixels ;
    aniso > 1 étire le grain le long de u, l'axe horizontal de la carte)"""
    r = np.random.default_rng(seed) if seed is not None else rng
    w = r.standard_normal((N, N))
    fy = np.fft.fftfreq(N)[:, None]; fx = np.fft.fftfreq(N)[None, :]
    f = np.sqrt((fx * aniso) ** 2 + fy ** 2) * scale
    F = np.fft.fft2(w) * np.exp(-(f ** 2) * 4)
    n = np.real(np.fft.ifft2(F))
    n -= n.mean(); n /= (n.std() + 1e-9)
    return n


def fbm(scale, octaves=4, aniso=1.0):
    t = np.zeros((N, N)); a = 1.0; s = 0
    for _ in range(octaves):
        t += a * noise(scale, aniso); s += a; a *= 0.5; scale /= 2
    return t / s


def scratches(count, length, width, angle_spread, depth_rng=(0.4, 1.0)):
    """micro-rayures : segments fins tracés en boucle (bords raccordés) ; renvoie (profondeur 0..1)"""
    img = np.zeros((N, N))
    for _ in range(count):
        x, y = rng.uniform(0, N, 2)
        a = rng.normal(0, angle_spread) + (np.pi if rng.random() < .5 else 0)
        L = rng.uniform(.3, 1) * length
        d = rng.uniform(*depth_rng)
        steps = int(L * 2) + 1
        # légère courbure : la main ne trace pas droit
        bend = rng.normal(0, .002)
        for s in range(steps):
            t = s / 2
            aa = a + bend * t
            px, py = x + np.cos(aa) * t, y + np.sin(aa) * t
            fade = min(1, s / 6, (steps - s) / 6)            # pointes effilées
            ix, iy = int(px) % N, int(py) % N
            img[iy, ix] = max(img[iy, ix], d * fade)
            if width > 1:
                img[(iy + 1) % N, ix] = max(img[(iy + 1) % N, ix], d * fade * .5)
    return img


def blur(a, r):
    """flou périodique (gaussien, par FFT)"""
    fy = np.fft.fftfreq(N)[:, None]; fx = np.fft.fftfreq(N)[None, :]
    return np.real(np.fft.ifft2(np.fft.fft2(a) * np.exp(-2 * (np.pi * r) ** 2 * (fx ** 2 + fy ** 2))))


def normal_map(h, strength):
    """hauteur -> normales (différences centrées, périodiques), convention OpenGL (vert = +y vers le haut de la carte)"""
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * .5 * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * .5 * strength
    nx, ny, nz = -dx, dy, np.ones_like(h)
    L = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2)
    rgb = np.stack([nx / L, ny / L, nz / L], -1) * .5 + .5
    return (np.clip(rgb, 0, 1) * 255 + .5).astype(np.uint8)


def g8(a):
    return (np.clip(a, 0, 1) * 255 + .5).astype(np.uint8)


def wear(scale, cover):
    """plaques d'usure : bruit fractal seuillé en douceur (cover = part de la surface usée)"""
    f = fbm(scale, 5)
    th = np.quantile(f, 1 - cover)
    return np.clip((f - th) / (f.std() * .35), 0, 1)


def build():
    M = {}
    # ---------- acier bruni ----------
    grain = noise(1.2); mott = fbm(90, 4)
    sc = scratches(170, 80, 1, .35) + scratches(45, 35, 1, 1.4, (.2, .6))
    sc = np.clip(sc, 0, 1)
    w = wear(70, .08)
    h = grain * .06 + mott * .08 - blur(sc, .6) * 1.2 - w * .25
    c = .70 + mott * .035 + grain * .015 + sc * .22 + w * .16
    r = .46 + grain * .03 + mott * .04 - sc * .2 - w * .14
    M['bruni'] = dict(c=c, n=normal_map(h, 2.2), r=r, metal=.9)
    # ---------- aluminium anodisé ----------
    grain = noise(.9); mott = fbm(120, 3)
    sc = np.clip(scratches(90, 70, 1, .5, (.25, .7)), 0, 1)
    w = wear(180, .06)
    h = grain * .1 + mott * .05 - blur(sc, .6) * .9 - w * .15
    c = .76 + mott * .025 + grain * .02 + sc * .18 + w * .2
    r = .55 + grain * .04 + mott * .03 - sc * .18 - w * .2
    M['anod'] = dict(c=c, n=normal_map(h, 2.0), r=r, metal=.7)
    # ---------- polymère grenu ----------
    st = noise(2.2) + noise(5) * .5            # pointillé (texture moulée)
    st = np.tanh(st * 1.4)
    mott = fbm(110, 3)
    w = blur(wear(60, .05), 3)
    h = st * .55 * (1 - w * .6) + mott * .05
    c = .74 + st * .03 + mott * .04 + w * .06
    r = .74 + st * .05 + mott * .04 - w * .2
    M['poly'] = dict(c=c, n=normal_map(h, 1.6), r=r, metal=0)
    # ---------- bois vernis ----------
    warp = fbm(140, 3) * 18
    yy = np.arange(N)[:, None] + warp
    rings = np.sin(yy / N * np.pi * 2 * 9 + fbm(60, 3, 6) * 2.5)
    fib = noise(1.5, 12)                       # fibres étirées le long de u
    pores = np.clip(noise(1.4, 5) - 1.6, 0, None)
    tone = rings * .5 + .5
    c = .62 + tone * .3 + fib * .03 - pores * .12 + fbm(200, 3) * .04
    h = fib * .12 + tone * .05 - pores * .35
    r = .3 + (1 - tone) * .08 + pores * .25 + fib * .02
    M['bois'] = dict(c=c, n=normal_map(h, 1.4), r=r, metal=0)
    # ---------- acier poli / brossé ----------
    brush = noise(1.0, 40) * .7 + noise(2.5, 25) * .3     # stries le long du canon
    mott = fbm(100, 3)
    sc = np.clip(scratches(160, 110, 1, .2, (.3, .8)) + scratches(40, 40, 1, 1.5, (.2, .5)), 0, 1)
    h = brush * .07 - blur(sc, .5) * .9 + mott * .03
    c = .86 + brush * .03 + mott * .03 + sc * .1
    r = .26 + brush * .04 + mott * .03 - sc * .1
    M['acier'] = dict(c=c, n=normal_map(h, 2.4), r=r, metal=1)
    return M


def jpeg(arr, q):
    im = Image.fromarray(arr)
    bio = io.BytesIO()
    im.save(bio, 'JPEG', quality=q, progressive=False, subsampling=0 if im.mode == 'RGB' else -1)
    return bio.getvalue()


def main():
    prev = sys.argv[1] if len(sys.argv) > 1 else None
    M = build()
    blob = bytearray()
    lines = [HEAD + '-- chunks = modules D1..Dn (base64 mis bout à bout) ; c / n / r = JPEG { début, longueur, largeur, hauteur } dans les',
             '-- octets décodés ; avg = valeur moyenne de la carte de couleur (la teinte de la pièce est divisée par elle) ; metal = métal uni.',
             'return {']
    mats = []
    for name, m in M.items():
        ent = {}
        for k, arr, q in (('c', g8(m['c']), 92), ('n', m['n'], 90), ('r', g8(m['r']), 92)):
            b = jpeg(arr, q)
            o = len(blob); blob.extend(b)
            while len(blob) % 4: blob.append(0)
            ent[k] = (o, len(b))
            if prev:
                os.makedirs(prev, exist_ok=True)
                Image.fromarray(arr).save(os.path.join(prev, '%s_%s.png' % (name, k)))
        avg = float(np.clip(m['c'], 0, 1).mean())
        mats.append((name, ent, avg, m['metal']))
        print(name, 'c %.2f..%.2f moy %.2f' % (m['c'].min(), m['c'].max(), avg), 'r %.2f..%.2f' % (m['r'].min(), m['r'].max()),
              ' '.join('%s %d Ko' % (k, v[1] // 1024) for k, v in ent.items()))
    b64 = base64.b64encode(bytes(blob)).decode()
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT): os.remove(os.path.join(OUT, f))
    n = 0
    for i in range(0, len(b64), CHUNK):
        n += 1
        open(os.path.join(OUT, 'D%d.lua' % n), 'w', encoding='utf8').write(HEAD + 'return "%s"\n' % b64[i:i + CHUNK])
    lines.append('\tchunks = %d, size = %d,' % (n, N))
    for name, ent, avg, metal in mats:
        lines.append('\t%s = { c = { %d, %d, %d, %d }, n = { %d, %d, %d, %d }, r = { %d, %d, %d, %d }, avg = %.3f, metal = %.2f },'
                     % (name, ent['c'][0], ent['c'][1], N, N, ent['n'][0], ent['n'][1], N, N, ent['r'][0], ent['r'][1], N, N, avg, metal))
    lines.append('}')
    open(os.path.join(OUT, 'Info.lua'), 'w', encoding='utf8').write('\n'.join(lines) + '\n')
    print(len(blob) // 1024, 'Ko,', n, 'modules')


main()
