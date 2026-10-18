#!/usr/bin/env python3
# Convertit les modèles d'armes du jeu web (models/weapons/*.glb, série Low-Poly de TastyTony, CC BY)
# en modules Luau pour Roblox : ReplicatedStorage/Shared/WeaponMeshes/<clé>.lua
# Chaque module contient, par pièce (body / bolt / mag) et par rôle de matériau (body, acc, steel, wood, keep),
# les sommets (int16) et les triangles (uint16) encodés en base64. WeaponModels.lua les transforme en EditableMesh.
# Usage (depuis la racine du dépôt) : python3 tools/export_weapons_lua.py
import json, struct, base64, os, re, glob

SRC = 'models/weapons'
OUT = 'roblox/ReplicatedStorage/Shared/WeaponMeshes'
Q = 30000.0  # 1 m = 30000 unités int16 (armes < 1,1 m)

def sight_fix():
    s = open('src/46_glb.js', encoding='utf8').read()
    m = re.search(r'const SIGHT_FIX=\{(.*?)\};', s, re.S)
    return {k: float(v) for k, v in re.findall(r'(\w+):([\d.]+)', m.group(1))}

def role(c):  # même règle que glbRole() dans src/46_glb.js
    r, g, b = c[:3]
    lum = .3*r + .59*g + .11*b; mx = max(r, g, b); mn = min(r, g, b); sat = (mx-mn)/mx if mx > 0 else 0
    if r > b*1.5 and r > .04 and sat > .3 and g < r: return 'wood'
    if sat > .45 and mx > .15: return 'keep'
    if lum > .3: return 'steel'
    if lum < .035: return 'body'
    return 'acc'

def srgb(x): return 255*(12.92*x if x <= .0031308 else 1.055*x**(1/2.4) - .055)

def read(fn):
    b = open(fn, 'rb').read()
    l = struct.unpack('<I', b[12:16])[0]; j = json.loads(b[20:20+l])
    off = 20 + l; bl = struct.unpack('<I', b[off:off+4])[0]; binc = b[off+8:off+8+bl]
    def acc(i):
        a = j['accessors'][i]; v = j['bufferViews'][a['bufferView']]
        o = v.get('byteOffset', 0) + a.get('byteOffset', 0)
        n = {'SCALAR': 1, 'VEC3': 3}[a['type']]; ct = a['componentType']
        fmt = {5126: 'f', 5123: 'H', 5125: 'I'}[ct]; sz = struct.calcsize(fmt)
        stride = v.get('byteStride', sz*n)
        return [struct.unpack_from('<'+fmt*n, binc, o + k*stride) for k in range(a['count'])]
    return j, acc

def main():
    sf = sight_fix(); info = {}
    os.makedirs(OUT, exist_ok=True)
    for fn in sorted(glob.glob(SRC + '/*.glb')):
        key = os.path.basename(fn)[:-4]
        meta = json.load(open(fn[:-4] + '.json'))
        j, acc = read(fn)
        groups = {}  # (pièce, rôle) -> {verts, tris, color}
        for node in j['nodes']:
            if 'mesh' not in node: continue
            part = node.get('name', 'body')
            for p in j['meshes'][node['mesh']]['primitives']:
                mat = j['materials'][p['material']] if 'material' in p else {}
                c = mat.get('pbrMetallicRoughness', {}).get('baseColorFactor', [.05, .05, .05, 1])
                rl = role(c)
                g = groups.setdefault((part, rl), {'v': [], 'vi': {}, 't': [], 'c': [0, 0, 0], 'n': 0})
                pos = acc(p['attributes']['POSITION']); idx = [i[0] for i in acc(p['indices'])]
                remap = {}
                for i in set(idx):
                    q = tuple(max(-32767, min(32767, round(x*Q))) for x in pos[i])
                    if q not in g['vi']: g['vi'][q] = len(g['v']); g['v'].append(q)
                    remap[i] = g['vi'][q]
                for t in range(0, len(idx), 3):
                    a, b2, c2 = remap[idx[t]], remap[idx[t+1]], remap[idx[t+2]]
                    if a != b2 and b2 != c2 and a != c2: g['t'].append((a, b2, c2))
                k = len(idx)//3
                for i in range(3): g['c'][i] += srgb(c[i])*k
                g['n'] += k
        lines = ['-- Généré par tools/export_weapons_lua.py depuis models/weapons/%s.glb (TastyTony, CC BY) : ne pas modifier à la main.' % key,
                 'return {']
        tot = 0
        for (part, rl), g in sorted(groups.items()):
            if not g['t']: continue
            assert len(g['v']) < 65536
            raw = b''.join(struct.pack('<hhh', *v) for v in g['v']) + b''.join(struct.pack('<HHH', *t) for t in g['t'])
            col = [round(x/g['n']) for x in g['c']]
            lines.append('\t{ part = "%s", role = "%s", color = { %d, %d, %d }, nv = %d, nt = %d,\n\t  data = "%s" },'
                         % (part, rl, col[0], col[1], col[2], len(g['v']), len(g['t']), base64.b64encode(raw).decode()))
            tot += len(g['t'])
        lines.append('}')
        open(os.path.join(OUT, key + '.lua'), 'w', encoding='utf8').write('\n'.join(lines) + '\n')
        info[key] = {'len': meta['len'], 'muzzle': meta['muzzle'], 'left': meta['left'], 'sight': sf.get(key, meta['sight']),
                     'min': meta['min'], 'max': meta['max'], 'tris': tot}
    out = ['-- Généré par tools/export_weapons_lua.py : dimensions des armes du jeu web, en mètres.',
           '-- muzzle = bout du canon (z), left = main gauche, sight = hauteur de la ligne de visée, la poignée est en (0, 0, 0).',
           'return {']
    v3 = lambda a: '{ %s }' % ', '.join('%.4f' % x for x in a)
    for k, m in sorted(info.items()):
        out.append('\t%s = { len = %.3f, muzzle = %.4f, sight = %.4f, left = %s, min = %s, max = %s },'
                   % (k, m['len'], m['muzzle'], m['sight'], v3(m['left']), v3(m['min']), v3(m['max'])))
    out.append('}')
    open('roblox/ReplicatedStorage/Shared/WeaponInfo.lua', 'w', encoding='utf8').write('\n'.join(out) + '\n')
    print(len(info), 'armes', sum(m['tris'] for m in info.values()), 'triangles')

main()
