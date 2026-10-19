#!/usr/bin/env python3
# Contrôle des armes Roblox (roblox/ReplicatedStorage/Shared/WeaponMeshes/*.lua) : boîte englobante (épaisseur X),
# composantes connexes, part de triangles à normales inversées (volume signé < 0), à arêtes ouvertes, plats (sans épaisseur).
# Usage : python3 tools/check_weapon_meshes.py roblox/ReplicatedStorage/Shared/WeaponMeshes [v]   (v : détail des pièces inversées)
# Voir aussi tools/render_weapon_meshes.py (rendu avec back-face culling : rouge = faces arrière visibles = trou).
import sys, re, base64, struct, glob, os
from collections import defaultdict
D = sys.argv[1]
VERB = len(sys.argv) > 2
Q = 30000.0
def load(fn):
    s = open(fn, encoding='utf8').read()
    out = []
    for m in re.finditer(r'part = "(\w+)", role = "(\w+)", color = \{[^}]*\}, nv = (\d+), nt = (\d+),\s*data = "([^"]*)"', s):
        part, role, nv, nt, d = m.group(1), m.group(2), int(m.group(3)), int(m.group(4)), base64.b64decode(m.group(5))
        V = [tuple(x/Q for x in struct.unpack_from('<hhh', d, i*6)) for i in range(nv)]
        T = [struct.unpack_from('<HHH', d, nv*6 + t*6) for t in range(nt)]
        out.append((part, role, V, T))
    return out
def sub(a,b): return (a[0]-b[0],a[1]-b[1],a[2]-b[2])
def cross(a,b): return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
def dot(a,b): return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]
def analyse(V, T):
    par = list(range(len(V)))
    def f(x):
        while par[x] != x: par[x] = par[par[x]]; x = par[x]
        return x
    for a,b,c in T:
        par[f(a)] = f(b); par[f(b)] = f(c)
    comp = defaultdict(list)
    for t in T: comp[f(t[0])].append(t)
    res = []
    for k, tris in comp.items():
        vol = 0; area = 0
        edges = defaultdict(int)
        for a,b,c in tris:
            pa,pb,pc = V[a],V[b],V[c]
            vol += dot(pa, cross(pb, pc))/6
            n = cross(sub(pb,pa), sub(pc,pa)); area += (dot(n,n)**.5)/2
            edges[(a,b)] += 1; edges[(b,c)] += 1; edges[(c,a)] += 1
        openE = sum(1 for (a,b) in edges if (b,a) not in edges)
        vs = {i for t in tris for i in t}
        lo = [min(V[i][j] for i in vs) for j in range(3)]; hi = [max(V[i][j] for i in vs) for j in range(3)]
        res.append(dict(n=len(tris), vol=vol, area=area, open=openE, ne=len(edges), lo=lo, hi=hi))
    return res
for fn in sorted(glob.glob(D + '/*.lua')):
    key = os.path.basename(fn)[:-4]
    groups = load(fn)
    allv = [v for g in groups for v in g[2]]
    lo = [min(v[j] for v in allv) for j in range(3)]; hi = [max(v[j] for v in allv) for j in range(3)]
    nt = 0; inv = 0; flat = 0; openT = 0; invC = 0; nc = 0; invA = 0; totA = 0
    for part, role, V, T in groups:
        for c in analyse(V, T):
            nt += c['n']; nc += 1; totA += c['area']
            th = min(c['hi'][j]-c['lo'][j] for j in range(3))
            if c['open'] > 0: openT += c['n']
            if c['vol'] < -1e-10: inv += c['n']; invC += 1; invA += c['area']
            if th < 0.0015 or abs(c['vol']) < 1e-10: flat += c['n']
            if VERB and c['vol'] < -1e-10: print('   inv', part, role, c['n'], ['%.3f' % x for x in c['lo']], ['%.3f' % x for x in c['hi']])
    print('%-10s X %.3f Y %.3f Z %.3f | tris %5d comp %4d | inversés %5.1f%% tri %5.1f%% aire (%d comp) | ouverts %5.1f%% | plats %4.1f%%' % (
        key, hi[0]-lo[0], hi[1]-lo[1], hi[2]-lo[2], nt, nc, 100*inv/nt, 100*invA/totA, invC, 100*openT/nt, 100*flat/nt))
