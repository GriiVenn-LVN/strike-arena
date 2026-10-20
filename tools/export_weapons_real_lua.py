#!/usr/bin/env python3
# Convertit les armes réalistes du jeu web (models/weapons_real/{ak,m4,awp,deagle}.glb, Sketchfab CC BY, voir
# credits_real.json) pour Roblox :
#   * ReplicatedStorage/Shared/WeaponInfoReal.lua : ce que le jeu lit chez le joueur (dimensions, ligne de visée, viseur
#     intégré, pièces : clé MeshAssets, centre et taille, profil pour les accessoires de l'armurier) ;
#   * ServerStorage/WeaponRealData/<clé>/ : ce que seul l'envoi depuis Studio (ServerStorage/MeshUploader) lit :
#     les maillages (sommets, normales lissées, coordonnées de texture, triangles) et les textures JPEG d'origine
#     (couleur, normales) plus les cartes de métal et de rugosité tirées de la carte glTF « metallicRoughness »
#     (bleu = métal, vert = rugosité), redimensionnées à 1024 px au plus. ServerStorage/JpegDecode les décode dans Studio.
# Une pièce = un nœud du modèle (body / bolt / mag) × un matériau ; le viseur holographique intégré du M4 (optic dans
# m4.json) est séparé du corps comme glbSplit() de src/46_glb.js, pour être masqué quand on monte une optique.
# Usage (depuis la racine du dépôt) : python3 tools/export_weapons_real_lua.py
import json, struct, base64, os, re, io, math
from PIL import Image, ImageChops, ImageStat

SRC = 'models/weapons_real'
OUT_INFO = 'roblox/ReplicatedStorage/Shared/WeaponInfoReal.lua'
OUT_DATA = 'roblox/ServerStorage/WeaponRealData'
KEYS = ['ak', 'awp', 'deagle', 'm4']
Q = 20000.0          # 1 m = 20000 unités int16 (AWP : 1,58 m, de -1,22 à +0,36 m)
UVQ = 8192.0         # coordonnées de texture en int16 / 8192 (de -4 à +4)
CHUNK = 190000       # caractères base64 par module (< 200 Ko, comme tools/scene_to_lua.py)
MAXTEX = 1024        # Roblox : 1024 × 1024 au plus
HEAD = '-- Généré par tools/export_weapons_real_lua.py depuis models/weapons_real (Sketchfab, CC BY) : ne pas modifier à la main.\n'


def sight_fix_real():
    s = open('src/46_glb.js', encoding='utf8').read()
    m = re.search(r'const SIGHT_FIX_REAL=\{(.*?)\};', s, re.S)
    return {k: float(v) for k, v in re.findall(r'(\w+):([\d.]+)', m.group(1))}


def read(fn):
    b = open(fn, 'rb').read()
    l = struct.unpack('<I', b[12:16])[0]; j = json.loads(b[20:20 + l])
    off = 20 + l; bl = struct.unpack('<I', b[off:off + 4])[0]; binc = b[off + 8:off + 8 + bl]
    def acc(i):
        a = j['accessors'][i]; v = j['bufferViews'][a['bufferView']]
        o = v.get('byteOffset', 0) + a.get('byteOffset', 0)
        n = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[a['type']]
        fmt = {5126: 'f', 5123: 'H', 5125: 'I', 5121: 'B'}[a['componentType']]; sz = struct.calcsize(fmt)
        stride = v.get('byteStride', sz * n)
        return [struct.unpack_from('<' + fmt * n, binc, o + k * stride) for k in range(a['count'])]
    def image(ti):
        im = j['images'][j['textures'][ti]['source']]; v = j['bufferViews'][im['bufferView']]
        o = v.get('byteOffset', 0)
        return binc[o:o + v['byteLength']]
    return j, acc, image


def glb_split(P, I, b):
    """même règle que glbSplit() du web : triangles entre z0 et z1 posés au-dessus du rail (hauteur y0) = viseur"""
    A, B = [], []
    for t in range(0, len(I), 3):
        lo, hi, ok = 1e9, -1e9, True
        for k in range(3):
            x, y, z = P[I[t + k]]
            if z < b[0] or z > b[1]: ok = False; break
            lo = min(lo, y); hi = max(hi, y)
        (B if ok and lo > b[2] - .007 and hi > b[2] + .001 else A).append((I[t], I[t + 1], I[t + 2]))
    return A, B


def ray_hits(tris, P, o, d, far):
    """rayon (o, d unitaire) contre des triangles (deux faces), Möller-Trumbore"""
    for a, b, c in tris:
        p0, p1, p2 = P[a], P[b], P[c]
        e1 = [p1[i] - p0[i] for i in range(3)]; e2 = [p2[i] - p0[i] for i in range(3)]
        h = [d[1] * e2[2] - d[2] * e2[1], d[2] * e2[0] - d[0] * e2[2], d[0] * e2[1] - d[1] * e2[0]]
        det = e1[0] * h[0] + e1[1] * h[1] + e1[2] * h[2]
        if abs(det) < 1e-12: continue
        f = 1 / det
        s = [o[i] - p0[i] for i in range(3)]
        u = f * (s[0] * h[0] + s[1] * h[1] + s[2] * h[2])
        if u < 0 or u > 1: continue
        q = [s[1] * e1[2] - s[2] * e1[1], s[2] * e1[0] - s[0] * e1[2], s[0] * e1[1] - s[1] * e1[0]]
        v = f * (d[0] * q[0] + d[1] * q[1] + d[2] * q[2])
        if v < 0 or u + v > 1: continue
        t = f * (e2[0] * q[0] + e2[1] * q[1] + e2[2] * q[2])
        if 0 < t < far: return True
    return False


def window_y(tris, P, optic):
    """fenêtre du viseur holographique intégré : rayons de l'arrière vers l'avant, à x = 0 (comme glbGun() du web)"""
    z0, z1 = optic[1] + .04, optic[0] - .04
    lo = hi = run = None
    y = optic[2]
    while y < optic[2] + .09:
        free = not ray_hits(tris, P, (0, y, z0), (0, 0, -1 if z1 < z0 else 1), abs(z1 - z0))
        if free and run is None: run = y
        if not free and run is not None:
            if lo is None: lo, hi = run, y
            run = None
        y += .001
    if lo is not None and hi - lo > .006: return (lo + hi) / 2
    return None


def jpeg(im, q=92):
    bio = io.BytesIO()
    im.save(bio, 'JPEG', quality=q, progressive=False, optimize=False, subsampling=0 if im.mode == 'RGB' else -1)
    return bio.getvalue()


def fit(im):
    if max(im.size) > MAXTEX:
        im = im.resize((min(MAXTEX, im.size[0]), min(MAXTEX, im.size[1])), Image.LANCZOS)
    return im


def lua(v):
    if isinstance(v, bool): return 'true' if v else 'false'
    if isinstance(v, int): return str(v)
    if isinstance(v, float): return ('%.5f' % v).rstrip('0').rstrip('.') if v != 0 else '0'
    if isinstance(v, str): return json.dumps(v, ensure_ascii=False)
    if isinstance(v, (list, tuple)): return '{ ' + ', '.join(lua(x) for x in v) + ' }'
    if isinstance(v, dict):
        return '{ ' + ', '.join('%s = %s' % (k, lua(x)) for k, x in v.items()) + ' }'
    raise TypeError(type(v))


def main():
    sf = sight_fix_real()
    info_lines = [HEAD.rstrip('\n'),
                  '-- Par arme : len, muzzle (bout du canon, z), sight (ligne de visée), bore (hauteur de l\'âme du canon), left (main gauche),',
                  '-- min / max (boîte), en mètres ;',
                  '-- optic = viseur intégré { z0, z1, y0 } et optSlot = place d\'une optique montée ; mats = matériaux (clés des images',
                  '-- « i:wr:<arme>:<n°>:c|n|m|r ») ; groups = pièces (clé du maillage « w:real:… », centre, taille, viseur intégré) ;',
                  '-- pts = points du profil (int16 / 20000, base64) pour poser les accessoires de l\'armurier (AttachmentModels).',
                  'return {']
    total = 0
    for key in KEYS:
        fn = os.path.join(SRC, key + '.glb')
        meta = json.load(open(os.path.join(SRC, key + '.json')))
        j, acc, image = read(fn)
        blob = bytearray()
        def put(b):
            o = len(blob); blob.extend(b)
            while len(blob) % 4: blob.append(0)          # alignement (lecture int16 / uint16)
            return [o, len(b)]
        groups, prof_pts = [], []
        builtin = None
        for node in j['nodes']:
            if 'mesh' not in node: continue
            part = node.get('name', 'body')
            for p in j['meshes'][node['mesh']]['primitives']:
                P = acc(p['attributes']['POSITION']); N = acc(p['attributes']['NORMAL']); T = acc(p['attributes']['TEXCOORD_0'])
                I = [i[0] for i in acc(p['indices'])]
                split = [(part, False, [(I[t], I[t + 1], I[t + 2]) for t in range(0, len(I), 3)])]
                if part == 'body' and meta.get('optic') and p.get('material', 0) == 0:
                    A, B = glb_split(P, I, meta['optic'])
                    split = [(part, False, A), (part, True, B)]
                    builtin = (B, P)
                for pname, isopt, tris in split:
                    if not tris: continue
                    used = sorted({i for t in tris for i in t})
                    remap = {v: k for k, v in enumerate(used)}
                    assert len(used) < 65536
                    raw = bytearray()
                    lo = [1e9] * 3; hi = [-1e9] * 3
                    for v in used:
                        x = P[v]
                        for a in range(3): lo[a] = min(lo[a], x[a]); hi[a] = max(hi[a], x[a])
                        n = N[v]; L = math.sqrt(n[0] ** 2 + n[1] ** 2 + n[2] ** 2) or 1
                        u = T[v]
                        assert abs(u[0]) < 4 and abs(u[1]) < 4, 'coordonnée de texture hors de -4..4'
                        raw += struct.pack('<hhhbbbxhh', *[max(-32767, min(32767, round(c * Q))) for c in x],
                                           *[max(-127, min(127, round(c / L * 127))) for c in n],
                                           *[max(-32767, min(32767, round(c * UVQ))) for c in u])
                        if not isopt: prof_pts.append(x)
                    for t in tris:
                        a, b, c = remap[t[0]], remap[t[1]], remap[t[2]]
                        if a != b and b != c and a != c: raw += struct.pack('<HHH', a, b, c)
                    nt = (len(raw) - len(used) * 14) // 6
                    groups.append({'part': pname, 'mat': p.get('material', 0) + 1, 'nv': len(used), 'nt': nt,
                                   'center': [(lo[a] + hi[a]) / 2 for a in range(3)], 'size': [hi[a] - lo[a] for a in range(3)],
                                   'optic': isopt, 'at': put(raw)})
                    total += nt
        # textures de chaque matériau
        mats = []
        for mi, mt in enumerate(j['materials']):
            pb = mt.get('pbrMetallicRoughness', {})
            col_b = image(pb['baseColorTexture']['index'])
            nrm_b = image(mt['normalTexture']['index'])
            mr = Image.open(io.BytesIO(image(pb['metallicRoughnessTexture']['index']))).convert('RGB')
            col = Image.open(io.BytesIO(col_b)).convert('RGB')
            nrm = Image.open(io.BytesIO(nrm_b))
            m = {'double': bool(mt.get('doubleSided'))}
            if mt.get('occlusionTexture'):
                # occlusion ambiante (aoMap du web) : cuite dans la couleur, adoucie (Roblox n'a pas de carte d'occlusion)
                ao = Image.open(io.BytesIO(image(mt['occlusionTexture']['index']))).convert('RGB').getchannel('R').resize(col.size, Image.BILINEAR)
                aok = ao.point(lambda v: round(255 * (.45 + .55 * v / 255)))
                col = Image.merge('RGB', [ImageChops.multiply(c, aok) for c in col.split()])
                col_b = jpeg(fit(col), 93)
            elif max(col.size) > MAXTEX:
                col_b = jpeg(fit(col), 93)
            if max(nrm.size) > MAXTEX: nrm_b = jpeg(fit(nrm.convert('RGB')), 95)
            rough = fit(mr.getchannel('G')); metal = mr.getchannel('B')
            metal = metal.resize((min(512, metal.size[0]), min(512, metal.size[1])), Image.LANCZOS)
            for k2, b2, im2 in (('c', col_b, None), ('n', nrm_b, None), ('r', jpeg(rough), rough), ('m', jpeg(metal), metal)):
                w, h = (im2.size if im2 else Image.open(io.BytesIO(b2)).size)
                m[k2] = put(b2) + [w, h]
            # valeur moyenne (repli : couleur unie de la pièce, matériau Roblox)
            avg = [round(x) for x in ImageStat.Stat(col).mean]
            m['avg'] = avg
            m['metal'] = round(ImageStat.Stat(metal).mean[0] / 255, 3)
            mats.append(m)
        # modules de données (ServerStorage) : chaînes base64 de 190 000 caractères au plus
        folder = os.path.join(OUT_DATA, key)
        os.makedirs(folder, exist_ok=True)
        for f in os.listdir(folder): os.remove(os.path.join(folder, f))
        b64 = base64.b64encode(bytes(blob)).decode()
        chunks = 0
        for i in range(0, len(b64), CHUNK):
            chunks += 1
            open(os.path.join(folder, 'D%d.lua' % chunks), 'w', encoding='utf8').write(HEAD + 'return "%s"\n' % b64[i:i + CHUNK])
        dl = [HEAD + '-- Données de l\'arme réaliste « %s » : chunks = modules D1..Dn (base64 mis bout à bout) ; at = { début, longueur }' % key,
              '-- dans les octets décodés. Pièce : par sommet int16 ×3 (position / 20000), int8 ×3 (normale / 127), 1 octet vide,',
              '-- int16 ×2 (texture / 8192), puis les triangles en uint16 ×3. Image : JPEG { début, longueur, largeur, hauteur }.',
              'return {', '\tchunks = %d,' % chunks, '\tgroups = {']
        for g in groups:
            dl.append('\t\t{ part = "%s", mat = %d, nv = %d, nt = %d, at = %s },' % (g['part'], g['mat'], g['nv'], g['nt'], lua(g['at'])))
        dl.append('\t},'); dl.append('\tmats = {')
        for m in mats:
            dl.append('\t\t{ c = %s, n = %s, m = %s, r = %s },' % (lua(m['c']), lua(m['n']), lua(m['m']), lua(m['r'])))
        dl.append('\t},'); dl.append('}')
        open(os.path.join(folder, 'Info.lua'), 'w', encoding='utf8').write('\n'.join(dl) + '\n')
        # ligne de visée : mire mesurée (SIGHT_FIX_REAL), sinon celle de la préparation ; viseur intégré : milieu de la fenêtre
        sight = sf.get(key, meta['sight'])
        slot = None
        if builtin:
            wy = window_y(builtin[0], builtin[1], meta['optic'])
            if wy is not None: sight = wy
            slot = [(meta['optic'][0] + meta['optic'][1]) / 2, meta['optic'][2] - .002]
        # âme du canon : milieu de la section à la bouche (départ des balles et de l'éclair)
        near = [x[1] for x in prof_pts if x[2] < meta['muzzle'] + .012]
        bore = (max(near) + min(near)) / 2 if near else sight * .6
        step = max(1, len(prof_pts) // 2500)
        pts = b''.join(struct.pack('<hhh', *[max(-32767, min(32767, round(c * Q))) for c in x]) for x in prof_pts[::step])
        il = ['\t%s = {' % key,
              '\t\tlen = %s, muzzle = %s, sight = %s, bore = %s, left = %s, min = %s, max = %s,' % (lua(float(meta['len'])), lua(float(meta['muzzle'])), lua(float(sight)), lua(round(bore, 4)),
                                                                                     lua([float(x) for x in meta['left']]), lua([float(x) for x in meta['min']]), lua([float(x) for x in meta['max']]))]
        if slot:
            il.append('\t\toptic = %s, optSlot = { z = %s, y = %s },' % (lua([float(x) for x in meta['optic']]), lua(slot[0]), lua(slot[1])))
        il.append('\t\tmats = {')
        for m in mats:
            il.append('\t\t\t{ double = %s, avg = %s, metal = %s },' % (lua(m['double']), lua(m['avg']), lua(float(m['metal']))))
        il.append('\t\t},'); il.append('\t\tgroups = {')
        for g in groups:
            il.append('\t\t\t{ part = "%s", mat = %d, nv = %d, nt = %d, center = %s, size = %s%s },'
                      % (g['part'], g['mat'], g['nv'], g['nt'], lua([round(x, 5) for x in g['center']]), lua([round(x, 5) for x in g['size']]),
                         ', optic = true' if g['optic'] else ''))
        il.append('\t\t},')
        il.append('\t\tpts = "%s",' % base64.b64encode(pts).decode())
        il.append('\t},')
        info_lines += il
        print(key, len(groups), 'pièces', sum(g['nt'] for g in groups), 'triangles', len(blob) // 1024, 'Ko', chunks, 'modules', 'visée', round(sight, 4))
    info_lines.append('}')
    open(OUT_INFO, 'w', encoding='utf8').write('\n'.join(info_lines) + '\n')
    print(total, 'triangles en tout')


main()
