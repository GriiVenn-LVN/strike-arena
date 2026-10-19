#!/usr/bin/env python3
"""
Soldats du jeu web -> modules Luau pour Roblox (étape 2/2).

Entrée : le JSON écrit par tools/soldiers/export_soldiers_web.js (géométrie au repos des soldats du jeu)
         + les textures des soldats réalistes (models/characters/s_<équipe>_game.glb).
Sortie : roblox/ReplicatedStorage/Shared/SoldierMeshes/
  Rig.lua          squelette (pivots au repos, longueurs des bras), couleurs des tenues, palette du jeu (lu aussi par le serveur)
  Body.lua         soldat réaliste découpé en 15 membres R15 (os dominant de chaque triangle), coordonnées de texture
  Tex_t/ct/ffa.lua texture de chaque équipe (256 px, 256 couleurs)
  Gear_t/ct/ffa.lua équipement gardé par-dessus (gilet, casque, poches, sac), couleur par sommet (index de palette)
  Outfit.lua       soldat procédural des tenues (corps commun), couleur par sommet = emplacement (chemise, gilet…)
  Head_<n>.lua     coiffe de chaque tenue (n = numéro de la tenue du jeu web)

Format d'un morceau : { seg = membre R15, nv, nt, data = base64 } ; par sommet 14 octets
(position int16 ×3 en 1/10000 m depuis le pivot du membre, normale int8 ×3, uv uint16 ×2, couleur uint8),
puis les triangles (uint16 ×3).
Usage (depuis la racine du dépôt) : python3 tools/soldiers/soldiers_to_lua.py <json>
"""
import base64, io, json, os, struct, sys
from collections import defaultdict
from PIL import Image
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'zombies'))
from build_zombies import read_glb, bv_bytes

ROOT = os.path.join(os.path.dirname(__file__), '..', '..')
OUT = os.path.join(ROOT, 'roblox', 'ReplicatedStorage', 'Shared', 'SoldierMeshes')
Q = 10000.0
TEX = 256

# os du modèle réaliste -> membre R15 (et nom du pivot dans Rig.real.bones)
SEG_OF_BONE = {}
for b in ('root', 'pelvis'): SEG_OF_BONE[b] = 'LowerTorso'
for b in ('spine_01', 'spine_02', 'spine_03', 'clavicle_l', 'clavicle_r'): SEG_OF_BONE[b] = 'UpperTorso'
for b in ('neck_01', 'head', 'head_leaf'): SEG_OF_BONE[b] = 'Head'
for s, S in (('l', 'Left'), ('r', 'Right')):
    SEG_OF_BONE['thigh_' + s] = S + 'UpperLeg'; SEG_OF_BONE['calf_' + s] = S + 'LowerLeg'
    for b in ('foot_', 'ball_', 'ball_leaf_'): SEG_OF_BONE[b + s] = S + 'Foot'
    SEG_OF_BONE['upperarm_' + s] = S + 'UpperArm'; SEG_OF_BONE['lowerarm_' + s] = S + 'LowerArm'
    SEG_OF_BONE['hand_' + s] = S + 'LowerArm'   # la main suit l'avant-bras (comme syncRealBody du web)
def seg_of_bone(n):
    if n in SEG_OF_BONE: return SEG_OF_BONE[n]
    side = 'Left' if n.endswith('_l') else 'Right'
    return side + 'LowerArm'                     # doigts
PIVOT = {'LowerTorso': 'pelvis', 'UpperTorso': 'spine', 'Head': 'head',
         'LeftUpperLeg': 'thighL', 'LeftLowerLeg': 'calfL', 'LeftFoot': 'footL',
         'RightUpperLeg': 'thighR', 'RightLowerLeg': 'calfR', 'RightFoot': 'footR',
         'LeftUpperArm': 'uarmL', 'LeftLowerArm': 'farmL', 'LeftHand': 'handL',
         'RightUpperArm': 'uarmR', 'RightLowerArm': 'farmR', 'RightHand': 'handR'}

def clamp(v, a, b): return max(a, min(b, v))

class Piece:
    """Accumule sommets (dédoublonnés) et triangles d'un membre."""
    def __init__(self, seg):
        self.seg = seg; self.key = {}; self.v = []; self.t = []
    def vert(self, p, n, uv, c):
        q = (tuple(int(round(clamp(x * Q, -32767, 32767))) for x in p),
             tuple(int(round(clamp(x * 127, -127, 127))) for x in n),
             (int(round(clamp(uv[0], 0, 1) * 65535)), int(round(clamp(uv[1], 0, 1) * 65535))), c)
        q = (tuple(q[0]), tuple(q[1]), q[2], q[3])
        i = self.key.get(q)
        if i is None:
            i = len(self.v); self.key[q] = i; self.v.append(q)
        return i
    def tri(self, a, b, c):
        if a != b and b != c and a != c: self.t.append((a, b, c))
    def lua(self, extra=''):
        raw = bytearray()
        for (p, n, uv, c) in self.v:
            raw += struct.pack('<hhhbbbHHB', *p, *n, *uv, c)
        for t in self.t: raw += struct.pack('<HHH', *t)
        return '\t{ seg = "%s", nv = %d, nt = %d,%s\n\t  data = "%s" },\n' % (self.seg, len(self.v), len(self.t), extra, base64.b64encode(bytes(raw)).decode())

def add_geo(pieces, g, seg, col, pivot=(0, 0, 0), uv=False):
    pc = pieces.setdefault(seg, Piece(seg))
    P, N, U, I = g['pos'], g['nrm'], g['uv'], g['idx']
    ids = {}
    for k in range(0, len(I), 3):
        tri = []
        for vi in I[k:k + 3]:
            if vi not in ids:
                p = (P[vi * 3] - pivot[0], P[vi * 3 + 1] - pivot[1], P[vi * 3 + 2] - pivot[2])
                ids[vi] = pc.vert(p, N[vi * 3:vi * 3 + 3], (U[vi * 2], U[vi * 2 + 1]) if uv else (0, 0), col)
            tri.append(ids[vi])
        pc.tri(*tri)

def write(name, header, body):
    path = os.path.join(OUT, name + '.lua')
    txt = '-- Généré par tools/soldiers/soldiers_to_lua.py (%s) : ne pas modifier à la main.\n%s' % (header, body)
    open(path, 'w', encoding='utf8').write(txt)
    return len(txt)

def v3(a): return 'Vector3.new(%.5f, %.5f, %.5f)' % tuple(a)
def rgb(c): return '{ %d, %d, %d }' % tuple(c)

def main():
    d = json.load(open(sys.argv[1] if len(sys.argv) > 1 else '/tmp/soldiers_web.json'))
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.endswith('.lua'): os.remove(os.path.join(OUT, f))
    sizes = {}
    real = d['real']; bones = real['bones']

    # ---------- corps réaliste ----------
    b = d['body']; pieces = {}
    P, N, U, I, Wt = b['pos'], b['nrm'], b['uv'], b['idx'], b['w']
    for k in range(0, len(I), 3):
        acc = defaultdict(float)
        for vi in I[k:k + 3]:
            for bn, w in Wt[vi].items(): acc[seg_of_bone(bn)] += w
        seg = max(acc, key=acc.get)
        piv = bones[PIVOT[seg]]
        pc = pieces.setdefault(seg, Piece(seg))
        tri = [pc.vert((P[vi * 3] - piv[0], P[vi * 3 + 1] - piv[1], P[vi * 3 + 2] - piv[2]), N[vi * 3:vi * 3 + 3], (U[vi * 2], U[vi * 2 + 1]), 0) for vi in I[k:k + 3]]
        pc.tri(*tri)
    sizes['Body'] = write('Body', 'soldat réaliste CC0 Mesh2Motion du jeu web', 'return {\n' + ''.join(pieces[s].lua() for s in sorted(pieces)) + '}\n')

    # ---------- textures des équipes ----------
    for k in ('t', 'ct', 'ffa'):
        j, binb = read_glb(os.path.join(ROOT, 'models', 'characters', 's_%s_game.glb' % k))
        im = Image.open(io.BytesIO(bv_bytes(j, binb, j['images'][0]['bufferView']))).convert('RGB').resize((TEX, TEX), Image.LANCZOS)
        q = im.quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
        pal = bytes(q.getpalette()[:768]).ljust(768, b'\0')
        sizes['Tex_' + k] = write('Tex_' + k, 'texture du soldat %s du jeu web' % k,
            'return { size = %d, pal = "%s",\n px = "%s" }\n' % (TEX, base64.b64encode(pal).decode(), base64.b64encode(q.tobytes()).decode()))

    # ---------- équipement des équipes ----------
    for k, gear in d['gear'].items():
        pal, pid, pieces = [], {}, {}
        for g in gear:
            cl = 'glass' if g['cls'] == 'glass' else 'neon' if g['cls'] == 'neon' else 'base'
            key = (tuple(g['color']), cl)
            if key not in pid: pid[key] = len(pal); pal.append(key)
            seg = g['seg']
            add_geo(pieces, g, seg, pid[key])
        pl = ', '.join('{ c = %s, cls = "%s" }' % (rgb(c), cl) for c, cl in pal)
        sizes['Gear_' + k] = write('Gear_' + k, 'équipement du soldat %s du jeu web' % k,
            'return { pal = { %s },\n' % pl + ''.join(pieces[s].lua() for s in sorted(pieces)) + '}\n')

    # ---------- tenues : corps procédural commun ----------
    slots = d['slots']; proc = d['proc']; pieces = {}
    for g in proc['body']:
        seg = g['seg']; piv = (0, 0, 0) if ('Arm' in seg or 'Hand' in seg) else proc['piv'][seg]
        add_geo(pieces, g, seg, slots.index(g['slot']), piv)
    sizes['Outfit'] = write('Outfit', 'soldat procédural des tenues du jeu web, src/45_models.js',
        'return {\n' + ''.join(pieces[s].lua() for s in sorted(pieces)) + '}\n')
    outfit_rows = []
    for o in d['outfits']:
        pal, pid, pieces = [], {}, {}
        for g in o['head']:
            key = ('s', g['slot']) if g['slot'] else ('c', tuple(g['color']), g['cls'])
            if key not in pid: pid[key] = len(pal); pal.append(key)
            add_geo(pieces, g, 'Head', pid[key], proc['piv']['Head'])
        pl = ', '.join('{ s = "%s" }' % e[1] if e[0] == 's' else '{ c = %s, cls = "%s" }' % (rgb(e[1]), 'glass' if e[2] == 'glass' else 'neon' if e[2] == 'neon' else 'base') for e in pal)
        sizes['Head_%d' % o['i']] = write('Head_%d' % o['i'], 'coiffe de la tenue « %s » du jeu web' % o['name'],
            'return { pal = { %s },\n' % pl + ''.join(pieces[s].lua() for s in sorted(pieces)) + '}\n')
        cols = ', '.join('%s = { c = %s, cls = "%s" }' % (s, rgb(v['c']), 'glass' if v['cls'] == 'glass' else 'neon' if (v['cls'] == 'neon' and o['glow']) else 'base') for s, v in o['colors'].items())
        outfit_rows.append('\t["%s"] = { web = %d, glow = %s, metal = %s, colors = { %s } },' % (
            o['name'].replace('"', '\\"'), o['i'], 'true' if o['glow'] else 'false', 'true' if o['metal'] else 'false', cols))

    # ---------- squelette ----------
    arm = real['arm']
    rig = ['local Rig = {}', 'Rig.Q = %d                  -- unités par mètre des positions int16' % Q,
           '-- soldat réaliste : position au repos des os (m, repère du soldat : pieds en 0, regard vers -Z), bras en croix',
           'Rig.real = {', '\tbones = {']
    rig += ['\t\t%s = %s,' % (k, v3(v)) for k, v in bones.items()]
    rig += ['\t},', '\tpelOff = %s,      -- bassin du modèle - bassin du soldat procédural' % v3(real['pelOff'])]
    rig += ['\tarm = {'] + ['\t\t%s = { la = %.5f, lb = %.5f, dU = %s, dF = %s },' % (K, a['la'], a['lb'], v3(a['dU']), v3(a['dF'])) for K, a in arm.items()] + ['\t},', '}']
    rig += ['-- soldat procédural (tenues) : pivots au repos des groupes, épaules dans le repère du buste, porte-arme',
            'Rig.proc = {', '\tpiv = {'] + ['\t\t%s = %s,' % (k, v3(v)) for k, v in proc['piv'].items()] + ['\t},',
            '\tS = { L = %s, R = %s },' % (v3(proc['S']['L']), v3(proc['S']['R'])),
            '\thips = %s, spine = %s, neck = %s, gun = %s,' % (v3(proc['hips']), v3(proc['spine']), v3(proc['neck']), v3(proc['gun'])), '}']
    rig += ['-- emplacements de couleur du soldat procédural (Outfit.lua : couleur du sommet = index + 1)',
            'Rig.SLOTS = { %s }' % ', '.join('"%s"' % s for s in slots),
            '-- tenues du jeu web, par nom (Config.OUTFITS[n].name)', 'Rig.OUTFITS = {'] + outfit_rows + ['}']
    rig += ['-- couleurs des joueurs (PALETTE) et teints de peau (SKIN_TONES) du jeu web',
            'Rig.PALETTE = { %s }' % ', '.join('"%s"' % c for c in d['palette']),
            'Rig.TONES = { %s }' % ', '.join('"%s"' % c for c in d['tones']), 'return Rig', '']
    sizes['Rig'] = write('Rig', 'squelette et couleurs des soldats du jeu web', '\n'.join(rig))
    tot = sum(sizes.values())
    for k, v in sorted(sizes.items()): print('%-10s %6.1f Ko' % (k, v / 1024))
    print('total %.1f Ko' % (tot / 1024))

if __name__ == '__main__':
    main()
