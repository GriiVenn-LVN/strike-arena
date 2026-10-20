#!/usr/bin/env python3
# Rendu logiciel (z-buffer) des armes Roblox : faces avant en gris éclairé, faces ARRIÈRE visibles en rouge
# (avec le back-face culling de Roblox, le rouge = trou : on voit à travers). Sortie : une planche PNG par arme.
# Usage : python3 tools/render_weapon_meshes.py <dossier WeaponMeshes> <dossier sortie> [armes...]
import sys, glob, os, re, base64, struct, math
import numpy as np
from PIL import Image
Q = 30000.0
def load(fn):
    s = open(fn, encoding='utf8').read()
    P, T, G = [], [], []
    for m in re.finditer(r'part = "(\w+)", role = "(\w+)", color = \{([^}]*)\}, nv = (\d+), nt = (\d+),\s*data = "([^"]*)"', s):
        nv, nt, d = int(m.group(4)), int(m.group(5)), base64.b64decode(m.group(6))
        V = np.frombuffer(d[:nv*6], dtype='<i2').reshape(-1, 3).astype(float) / Q
        I = np.frombuffer(d[nv*6:nv*6+nt*6], dtype='<u2').reshape(-1, 3).astype(int)
        P.append(V[I])
    return np.concatenate(P)
def rot(yaw, pitch):
    cy, sy, cp, sp = math.cos(yaw), math.sin(yaw), math.cos(pitch), math.sin(pitch)
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]); Rx = np.array([[1, 0, 0], [0, cp, -sp], [0, sp, cp]])
    return Rx @ Ry
def render(tri, yaw, pitch, W=360, H=300):
    R = rot(yaw, pitch)
    t = tri @ R.T                       # caméra regardant vers -Z
    c = (t.reshape(-1, 3).min(0) + t.reshape(-1, 3).max(0)) / 2
    t = t - c
    ext = max(np.ptp(t[..., 0]), np.ptp(t[..., 1]) * W / H) * 1.08
    k = W / ext
    sx = t[..., 0] * k + W / 2; sy = -t[..., 1] * k + H / 2; z = t[..., 2]
    n = np.cross(t[:, 1] - t[:, 0], t[:, 2] - t[:, 0])
    nl = n / (np.linalg.norm(n, axis=1, keepdims=True) + 1e-12)
    zb = np.full((H, W), -1e9); col = np.zeros((H, W, 3), dtype=np.uint8) + 255
    L = np.array([.4, .7, .6]); L /= np.linalg.norm(L)
    for i in range(len(t)):
        x0, y0 = sx[i], sy[i]
        xmin, xmax = int(max(0, math.floor(x0.min()))), int(min(W - 1, math.ceil(x0.max())))
        ymin, ymax = int(max(0, math.floor(y0.min()))), int(min(H - 1, math.ceil(y0.max())))
        if xmin > xmax or ymin > ymax: continue
        X, Y = np.meshgrid(np.arange(xmin, xmax + 1) + .5, np.arange(ymin, ymax + 1) + .5)
        (ax, bx, cx), (ay, by, cy) = x0, y0
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-12: continue
        w1 = ((by - cy) * (X - cx) + (cx - bx) * (Y - cy)) / den
        w2 = ((cy - ay) * (X - cx) + (ax - cx) * (Y - cy)) / den
        w3 = 1 - w1 - w2
        ins = (w1 >= 0) & (w2 >= 0) & (w3 >= 0)
        if not ins.any(): continue
        zz = w1 * z[i, 0] + w2 * z[i, 1] + w3 * z[i, 2]
        sub = zb[ymin:ymax + 1, xmin:xmax + 1]
        upd = ins & (zz > sub)
        sub[upd] = zz[upd]
        front = nl[i, 2] > 0
        if front:
            s = 60 + 170 * max(0.0, float(nl[i] @ L)); cc = (s, s, s)
        else:
            cc = (230, 30, 30)
        col[ymin:ymax + 1, xmin:xmax + 1][upd] = cc
    return col
VIEWS = [('côté', math.pi / 2, 0), ('3/4 avant', math.radians(35), math.radians(-12)), ('face', 0, 0),
         ('joueur', math.pi + math.radians(15), math.radians(-20)), ('dessus', math.pi / 2, math.radians(-80))]
if __name__ == '__main__':
    src, out = sys.argv[1], sys.argv[2]
    keys = sys.argv[3:] or [os.path.basename(f)[:-4] for f in sorted(glob.glob(src + '/*.lua'))]
    os.makedirs(out, exist_ok=True)
    for key in keys:
        tri = load(os.path.join(src, key + '.lua'))
        imgs = [render(tri, y, p) for _, y, p in VIEWS]
        im = np.concatenate(imgs, axis=1)
        red = [(np.all(i == (230, 30, 30), axis=2).sum() / max(1, (i != 255).any(axis=2).sum())) for i in imgs]
        Image.fromarray(im).save(os.path.join(out, key + '.png'))
        print('%-10s rouge (faces arrière visibles) par vue : %s' % (key, ' '.join('%s %.1f%%' % (VIEWS[j][0], 100 * r) for j, r in enumerate(red))))
