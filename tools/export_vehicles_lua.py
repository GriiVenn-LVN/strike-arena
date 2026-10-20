#!/usr/bin/env python3
# Convertit les véhicules du jeu web (models/vehicles/*.glb, modèles Blender de tools/blender/vehicles.py)
# en modules Luau pour Roblox : ReplicatedStorage/Shared/VehicleMeshes/<véhicule>/
#   Info.lua  dimensions du web (models/vehicles/<véhicule>.json : plancher, places assises…), liste des maillages,
#             pivots des pièces animées, et la version « en pièces » (une Part par objet du modèle) qui sert
#             tant que les maillages ne sont pas envoyés par ServerStorage/MeshUploader
#   G<n>.lua  un maillage : sommets (int16), normales (int8) et triangles (uint16) encodés en base64
# Comme loadVehicle() du web (src/65b_car.js) : les pièces fixes sont fusionnées par matériau ; roues, portes et hayon
# restent à part, géométrie locale autour de leur pivot (les quatre roues partagent un seul maillage).
# Usage (depuis la racine du dépôt) : python3 tools/export_vehicles_lua.py
import json, struct, base64, os, re, math

SRC = 'models/vehicles'
OUT = 'roblox/ReplicatedStorage/Shared/VehicleMeshes'
Q = 8000.0  # 1 m = 8000 unités int16 (véhicules < 4 m autour de l'origine)
ANIM = re.compile(r'^(wheel_|door_|tailgate)')

def srgb(x): return max(0, min(255, round(255*(12.92*x if x <= .0031308 else 1.055*x**(1/2.4) - .055))))

def read(fn):
    b = open(fn, 'rb').read()
    l = struct.unpack('<I', b[12:16])[0]; j = json.loads(b[20:20+l])
    off = 20 + l; bl = struct.unpack('<I', b[off:off+4])[0]; binc = b[off+8:off+8+bl]
    def acc(i):
        a = j['accessors'][i]; v = j['bufferViews'][a['bufferView']]
        o = v.get('byteOffset', 0) + a.get('byteOffset', 0)
        n = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[a['type']]; ct = a['componentType']
        fmt = {5126: 'f', 5123: 'H', 5125: 'I', 5121: 'B'}[ct]; sz = struct.calcsize(fmt)
        stride = v.get('byteStride', sz*n)
        return [struct.unpack_from('<'+fmt*n, binc, o + k*stride) for k in range(a['count'])]
    return j, acc

# ---------- petite algèbre ----------
def quat_mat(q):
    x, y, z, w = q
    return [[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)],
            [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)],
            [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]]
def mv(m, v): return tuple(sum(m[r][c]*v[c] for c in range(3)) for r in range(3))
def sub(a, b): return (a[0]-b[0], a[1]-b[1], a[2]-b[2])
def add(a, b): return (a[0]+b[0], a[1]+b[1], a[2]+b[2])
def dot(a, b): return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]
def cross(a, b): return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
def norm(a):
    l = math.sqrt(dot(a, a)); return (a[0]/l, a[1]/l, a[2]/l) if l > 1e-12 else (0.0, 1.0, 0.0)

def obb(tris):
    """boîte orientée d'un objet en blocs : axes tirés des faces les plus grandes"""
    cl = []  # [direction, aire]
    for a, b, c in tris:
        n = cross(sub(b, a), sub(c, a)); ar = math.sqrt(dot(n, n))
        if ar < 1e-12: continue
        n = norm(n)
        for e in cl:
            if abs(dot(e[0], n)) > .985: e[1] += ar; break
        else: cl.append([n, ar])
    cl.sort(key=lambda e: -e[1])
    if not cl: return None
    a1 = cl[0][0]; a2 = None
    for d, _ in cl[1:]:
        if abs(dot(d, a1)) < .15: a2 = norm(sub(d, tuple(x*dot(d, a1) for x in a1))); break
    if a2 is None:  # plaque seule (vitre) : second axe le long de l'arête la plus longue
        best = None
        for a, b, c in tris:
            for p, q in ((a, b), (b, c), (c, a)):
                e = sub(q, p); e = sub(e, tuple(x*dot(e, a1) for x in a1))
                if best is None or dot(e, e) > dot(best, best): best = e
        a2 = norm(best)
    a3 = cross(a1, a2)
    # axes rangés au plus près de x, y, z (rotation la plus petite possible)
    axes = [a1, a2, a3]; out = []
    for ref in ((1, 0, 0), (0, 1, 0), (0, 0, 1)):
        k = max(range(len(axes)), key=lambda i: abs(dot(axes[i], ref)))
        ax = axes.pop(k); out.append(ax if dot(ax, ref) >= 0 else tuple(-x for x in ax))
    if dot(cross(out[0], out[1]), out[2]) < 0: out[2] = tuple(-x for x in out[2])
    pts = [p for t in tris for p in t]
    lo = [min(dot(p, ax) for p in pts) for ax in out]; hi = [max(dot(p, ax) for p in pts) for ax in out]
    cen = [(lo[i]+hi[i])/2 for i in range(3)]
    c = tuple(sum(out[i][k]*cen[i] for i in range(3)) for k in range(3))
    size = [max(.02, hi[i]-lo[i]) for i in range(3)]
    rot = [out[0][0], out[1][0], out[2][0], out[0][1], out[1][1], out[2][1], out[0][2], out[1][2], out[2][2]]
    return c, rot, size

def aabb(pts):
    lo = [min(p[i] for p in pts) for i in range(3)]; hi = [max(p[i] for p in pts) for i in range(3)]
    return [(lo[i]+hi[i])/2 for i in range(3)], [max(.02, hi[i]-lo[i]) for i in range(3)]

def f3(v): return '{ %s }' % ', '.join('%.4f' % x for x in v)
def f9(v): return '{ %s }' % ', '.join('%.5f' % x for x in v)

def main():
    os.makedirs(OUT, exist_ok=True)
    for fn in sorted(os.listdir(SRC)):
        if not fn.endswith('.glb'): continue
        key = fn[:-4]
        meta = json.load(open(os.path.join(SRC, key + '.json')))
        j, acc = read(os.path.join(SRC, fn))
        mats = j['materials']
        groups = {}   # (pièce, matériau) -> sommets, triangles
        boxes = []    # version en pièces
        pivots = {}   # pièce animée -> pivot (m)
        wheel_done = False
        for node in j['nodes']:
            if 'mesh' not in node: continue
            name = node.get('name', '')
            T = node.get('translation', [0, 0, 0]); R = quat_mat(node.get('rotation', [0, 0, 0, 1])); S = node.get('scale', [1, 1, 1])
            anim = bool(ANIM.match(name))
            piece = 'wheel' if name.startswith('wheel_') else (name if anim else 'static')
            if anim: pivots[name] = T
            if piece == 'wheel' and wheel_done: continue
            hasT = 'translation' in node or 'rotation' in node or 'scale' in node
            for p in j['meshes'][node['mesh']]['primitives']:
                mn = mats[p['material']]['name'] if 'material' in p else 'dark'
                P0 = acc(p['attributes']['POSITION']); N0 = acc(p['attributes']['NORMAL']); I = [i[0] for i in acc(p['indices'])]
                def place(v, n=False):
                    v = (v[0]*S[0], v[1]*S[1], v[2]*S[2]) if not n else v
                    v = mv(R, v)
                    return v if (anim or n) else add(v, T)
                g = groups.setdefault((piece, mn), {'v': [], 'vi': {}, 't': []})
                remap = {}
                for i in set(I):
                    pv = place(P0[i]); nv = norm(place(N0[i], True))
                    q = tuple(max(-32767, min(32767, round(x*Q))) for x in pv) + tuple(max(-127, min(127, round(x*127))) for x in nv)
                    if q not in g['vi']: g['vi'][q] = len(g['v']); g['v'].append(q)
                    remap[i] = g['vi'][q]
                for t in range(0, len(I), 3):
                    a, b, c = remap[I[t]], remap[I[t+1]], remap[I[t+2]]
                    if a != b and b != c and a != c: g['t'].append((a, b, c))
                # ---------- version en pièces ----------
                tris = [tuple(place(P0[I[t+k]]) for k in range(3)) for t in range(0, len(I), 3)]
                if piece == 'wheel':
                    c, s = aabb([v for t in tris for v in t])
                    boxes.append({'m': mn, 'p': 'wheel', 'c': c, 's': s, 'cyl': True})
                elif name == 'tarp':
                    # bâche bombée : profil extérieur (rayon maximal par tranche de 15° autour du bas de la bâche),
                    # puis un panneau par segment du profil, sur toute la longueur
                    pts = [v for t in tris for v in t]
                    x0 = (min(v[0] for v in pts) + max(v[0] for v in pts)) / 2; y0 = min(v[1] for v in pts)
                    z0 = min(v[2] for v in pts); z1 = max(v[2] for v in pts)
                    prof = {}
                    for v in pts:
                        dx, dy = v[0]-x0, v[1]-y0; r = math.hypot(dx, dy)
                        k = max(0, min(11, int(math.degrees(math.atan2(dy, dx)) // 15)))
                        if k not in prof or r > prof[k][0]: prof[k] = (r, v[0], v[1])
                    pr = [prof[k] for k in sorted(prof)]
                    for (_, xa, ya), (_, xb, yb) in zip(pr, pr[1:]):
                        L = math.hypot(xb-xa, yb-ya)
                        if L < .02: continue
                        ux, uy = (xb-xa)/L, (yb-ya)/L   # axe x de la pièce le long du segment
                        boxes.append({'m': mn, 'p': 'static', 'c': ((xa+xb)/2, (ya+yb)/2, (z0+z1)/2),
                                      'r': [ux, -uy, 0, uy, ux, 0, 0, 0, 1], 's': [L + .04, .03, z1 - z0]})
                elif hasT and not anim:
                    # objet tourné dans Blender : boîte exacte dans son repère, puis transformation du nœud
                    loc = [(v[0]*S[0], v[1]*S[1], v[2]*S[2]) for v in (P0[i] for i in set(I))]
                    c, s = aabb(loc)
                    cw = add(mv(R, c), T)
                    rot = [R[0][0], R[0][1], R[0][2], R[1][0], R[1][1], R[1][2], R[2][0], R[2][1], R[2][2]]
                    boxes.append({'m': mn, 'p': 'static', 'c': cw, 'r': rot, 's': s})
                else:
                    o = obb(tris)
                    if o: boxes.append({'m': mn, 'p': piece, 'c': o[0], 'r': o[1], 's': o[2]})
            if piece == 'wheel': wheel_done = True
        # ---------- écriture ----------
        d = os.path.join(OUT, key); os.makedirs(d, exist_ok=True)
        for f in os.listdir(d):
            if f.endswith('.lua'): os.remove(os.path.join(d, f))
        glist = []; tot = 0
        for gi, ((piece, mn), g) in enumerate(sorted(groups.items()), 1):
            if not g['t']: continue
            assert len(g['v']) < 65536 and len(g['t']) < 20000
            raw = b''.join(struct.pack('<hhh', *v[:3]) for v in g['v']) + b''.join(struct.pack('<bbb', *v[3:]) for v in g['v']) \
                + b''.join(struct.pack('<HHH', *t) for t in g['t'])
            mod = 'G%d' % gi
            open(os.path.join(d, mod + '.lua'), 'w', encoding='utf8').write(
                '-- Généré par tools/export_vehicles_lua.py depuis models/vehicles/%s.glb : ne pas modifier à la main.\n'
                'return "%s"\n' % (key, base64.b64encode(raw).decode()))
            lo = [min(v[i] for v in g['v'])/Q for i in range(3)]; hi = [max(v[i] for v in g['v'])/Q for i in range(3)]
            glist.append((piece, mn, len(g['v']), len(g['t']), mod, [(lo[i]+hi[i])/2 for i in range(3)], [hi[i]-lo[i] for i in range(3)]))
            tot += len(g['t'])
        L = ['-- Généré par tools/export_vehicles_lua.py depuis models/vehicles/%s.glb (+ .json) : ne pas modifier à la main.' % key,
             '-- Mètres, repère du web (avant = -Z, haut = +Y). groups : maillages (pièce, matériau, sommets, triangles, module,',
             '-- centre, taille) ; pivots : pièces animées ; boxes : version en pièces (centre, rotation, taille, cyl = roue).',
             'return {',
             '\tCF = %.3f, W = %.3f, rear = %.3f, roof = %.3f, wheelR = %.3f, doors = "%s",' % (meta['CF'], meta['W'], meta['rear'], meta['roof'], meta['wheelR'], meta['doors']),
             '\tseats = { %s },' % ', '.join('{ %.2f, %.2f }' % (s[0], s[1]) for s in meta['seats']),
             '\tplayer = { %.2f, %.2f },' % tuple(meta['player']),
             '\tdriver = %s,' % ('{ %.2f, %.2f }' % tuple(meta['driver']) if meta.get('driver') else 'nil'),
             '\tQ = %d,' % Q,
             '\tmats = {']
        for m in mats:
            pb = m.get('pbrMetallicRoughness', {}); c = pb.get('baseColorFactor', [.5, .5, .5, 1])
            L.append('\t\t["%s"] = { color = { %d, %d, %d }, alpha = %.2f, metal = %.2f, rough = %.2f },'
                     % (m['name'], srgb(c[0]), srgb(c[1]), srgb(c[2]), c[3] if len(c) > 3 else 1, pb.get('metallicFactor', 1), pb.get('roughnessFactor', 1)))
        L.append('\t},')
        L.append('\tgroups = {')
        for piece, mn, nv, nt, mod, cen, size in glist:
            L.append('\t\t{ piece = "%s", mat = "%s", nv = %d, nt = %d, mod = "%s", center = %s, size = %s },' % (piece, mn, nv, nt, mod, f3(cen), f3(size)))
        L.append('\t},')
        L.append('\tpivots = {')
        for k in sorted(pivots): L.append('\t\t%s = %s,' % (k, f3(pivots[k])))
        L.append('\t},')
        L.append('\tboxes = {')
        for b in boxes:
            extra = ', r = %s' % f9(b['r']) if 'r' in b else ''
            if b.get('cyl'): extra += ', cyl = true'
            L.append('\t\t{ m = "%s", p = "%s", c = %s, s = %s%s },' % (b['m'], b['p'], f3(b['c']), f3(b['s']), extra))
        L.append('\t},')
        L.append('}')
        open(os.path.join(d, 'Info.lua'), 'w', encoding='utf8').write('\n'.join(L) + '\n')
        print(key, len(glist), 'maillages', tot, 'triangles', len(boxes), 'pièces de repli')

main()
