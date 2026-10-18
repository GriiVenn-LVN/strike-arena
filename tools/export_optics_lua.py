#!/usr/bin/env python3
# Convertit les viseurs du jeu web (models/optics/*.glb, faits par tools/blender/optics.py) en modules Luau pour Roblox :
# ReplicatedStorage/Shared/OpticMeshes/<clé>.lua. Même principe que tools/export_weapons_lua.py, mais les normales
# lissées du modèle Blender sont gardées (int8) et chaque groupe correspond à un matériau du .glb
# (body, dark, rubber, metal, tan, emit_red, emit_fiber). Le .json du modèle (cy, lensY…) est recopié dans « info ».
# Usage (depuis la racine du dépôt) : python3 tools/export_optics_lua.py
import json, struct, base64, os, glob, math

SRC = 'models/optics'
OUT = 'roblox/ReplicatedStorage/Shared/OpticMeshes'
Q = 100000.0  # 1 m = 100000 unités int16 (viseurs < 0,32 m)

def mat_mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]

def node_matrix(n):
    if 'matrix' in n:
        m = n['matrix']; return [[m[c * 4 + r] for c in range(4)] for r in range(4)]
    t = n.get('translation', [0, 0, 0]); x, y, z, w = n.get('rotation', [0, 0, 0, 1]); s = n.get('scale', [1, 1, 1])
    R = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
         [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
         [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]
    return [[R[r][0] * s[0], R[r][1] * s[1], R[r][2] * s[2], t[r]] for r in range(3)] + [[0, 0, 0, 1]]

def apply(m, v, w=1.0):
    return [m[r][0] * v[0] + m[r][1] * v[1] + m[r][2] * v[2] + m[r][3] * w for r in range(3)]

def read(fn):
    b = open(fn, 'rb').read()
    l = struct.unpack('<I', b[12:16])[0]; j = json.loads(b[20:20 + l])
    off = 20 + l; bl = struct.unpack('<I', b[off:off + 4])[0]; binc = b[off + 8:off + 8 + bl]
    def acc(i):
        a = j['accessors'][i]; v = j['bufferViews'][a['bufferView']]
        o = v.get('byteOffset', 0) + a.get('byteOffset', 0)
        n = {'SCALAR': 1, 'VEC3': 3}[a['type']]; fmt = {5126: 'f', 5123: 'H', 5125: 'I', 5121: 'B'}[a['componentType']]
        sz = struct.calcsize(fmt); stride = v.get('byteStride', sz * n)
        return [struct.unpack_from('<' + fmt * n, binc, o + k * stride) for k in range(a['count'])]
    return j, acc

def main():
    os.makedirs(OUT, exist_ok=True)
    total = 0
    for fn in sorted(glob.glob(SRC + '/*.glb')):
        key = os.path.basename(fn)[:-4]
        meta = json.load(open(fn[:-4] + '.json'))
        j, acc = read(fn)
        names = [m.get('name', 'body') for m in j.get('materials', [])]
        groups = {}
        def walk(ni, PM):
            n = j['nodes'][ni]; M = mat_mul(PM, node_matrix(n))
            if 'mesh' in n:
                for p in j['meshes'][n['mesh']]['primitives']:
                    mn = names[p.get('material', 0)] if names else 'body'
                    g = groups.setdefault(mn, {'v': [], 'vi': {}, 't': []})
                    P = acc(p['attributes']['POSITION']); N = acc(p['attributes']['NORMAL'])
                    I = [i[0] for i in acc(p['indices'])] if 'indices' in p else list(range(len(P)))
                    remap = {}
                    for i in set(I):
                        pv = apply(M, P[i]); nv = apply(M, N[i], 0.0); L = math.sqrt(sum(c * c for c in nv)) or 1
                        q = tuple(max(-32767, min(32767, round(c * Q))) for c in pv) + tuple(max(-127, min(127, round(c / L * 127))) for c in nv)
                        if q not in g['vi']: g['vi'][q] = len(g['v']); g['v'].append(q)
                        remap[i] = g['vi'][q]
                    for t in range(0, len(I), 3):
                        a, b2, c2 = remap[I[t]], remap[I[t + 1]], remap[I[t + 2]]
                        if a != b2 and b2 != c2 and a != c2: g['t'].append((a, b2, c2))
            for c in n.get('children', []): walk(c, M)
        ident = [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]
        for r in j['scenes'][j.get('scene', 0)]['nodes']: walk(r, ident)
        info = ', '.join('%s = %s' % (k, ('%.4f' % v) if isinstance(v, float) else v) for k, v in sorted(meta.items()) if isinstance(v, (int, float)))
        lines = ['-- Généré par tools/export_optics_lua.py depuis models/optics/%s.glb (tools/blender/optics.py) : ne pas modifier à la main.' % key,
                 '-- sommets : 3 × int16 (1 m = %d) + 3 × int8 (normale) ; triangles : 3 × uint16.' % Q,
                 'return {', '\tinfo = { %s },' % info, '\tgroups = {']
        for mn, g in sorted(groups.items()):
            if not g['t']: continue
            assert len(g['v']) < 65536
            raw = b''.join(struct.pack('<hhhbbb', *v) for v in g['v']) + b''.join(struct.pack('<HHH', *t) for t in g['t'])
            lines.append('\t\t{ mat = "%s", nv = %d, nt = %d,\n\t\t  data = "%s" },' % (mn, len(g['v']), len(g['t']), base64.b64encode(raw).decode()))
            total += len(g['t'])
        lines += ['\t},', '}']
        open(os.path.join(OUT, key + '.lua'), 'w', encoding='utf8').write('\n'.join(lines) + '\n')
    print(len(glob.glob(SRC + '/*.glb')), 'viseurs', total, 'triangles')

main()
