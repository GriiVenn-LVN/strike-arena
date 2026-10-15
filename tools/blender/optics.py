# Modélise les viseurs (optiques montées sur les armes) et les exporte en GLB.
# Lancement (Blender en module Python, sans interface) :
#   python -P tools/blender/optics.py          (avec le paquet pip « bpy »)
# ou dans Blender : blender -b -P tools/blender/optics.py
# Repère Blender : +Y = avant (vers la cible), +Z = haut, mètres. L'export glTF passe en Y-haut
# (avant = -Z dans le jeu). Origine : dessous de l'embase, au milieu de la longueur du viseur.
# Les fenêtres et les tubes restent ouverts sur la ligne de visée : la lentille et le réticule
# sont ajoutés par le jeu (src/64d_optics3d.js) aux positions données dans le .json.
import bpy, bmesh, math, os, json
from mathutils import Vector, Matrix

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'models', 'optics')

def clear():
    for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials):
        for d in list(coll): coll.remove(d)
    MATS.clear()

MATS = {}
def mat(name, col, metal=0.0, rough=0.6, emit=None):
    if name in MATS: return MATS[name]
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes.get('Principled BSDF')
    b.inputs['Base Color'].default_value = (*col, 1)
    b.inputs['Metallic'].default_value = metal; b.inputs['Roughness'].default_value = rough
    if emit:
        b.inputs['Emission Color'].default_value = (*emit, 1); b.inputs['Emission Strength'].default_value = 3.0
    MATS[name] = m; return m

def M_body():  return mat('body', (0.035, 0.037, 0.04), 0.35, 0.5)     # aluminium anodisé noir
def M_dark():  return mat('dark', (0.07, 0.075, 0.08), 0.75, 0.32)      # pièces usinées
def M_rub():   return mat('rubber', (0.02, 0.02, 0.022), 0.0, 0.9)      # caoutchouc
def M_metal(): return mat('metal', (0.55, 0.56, 0.58), 1.0, 0.25)       # vis, leviers
def M_tan():   return mat('tan', (0.36, 0.30, 0.2), 0.3, 0.55)          # boutons de réglage
def M_red():   return mat('emit_red', (0.9, 0.05, 0.03), 0.0, 0.4, emit=(1.0, 0.06, 0.03))
def M_fiber(): return mat('emit_fiber', (0.9, 0.2, 0.05), 0.0, 0.3, emit=(1.0, 0.25, 0.05))

def finish(name, bm, m, bevel=0.0, seg=2, smooth=True, angle=40):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    me.materials.append(m)
    if bevel > 0:
        b = o.modifiers.new('Bevel', 'BEVEL'); b.width = bevel; b.segments = seg
        b.limit_method = 'ANGLE'; b.angle_limit = math.radians(angle); b.harden_normals = True
    if smooth:
        for p in me.polygons: p.use_smooth = True
        o.modifiers.new('WN', 'WEIGHTED_NORMAL').keep_sharp = True
    return o

def box(name, sx, sy, sz, x, y, z, m, bevel=0.0012, taper=None, seg=2):
    """Boîte centrée en (x,y,z) ; sx = largeur, sy = longueur (avant), sz = hauteur. taper=(fx,fy) rétrécit le dessus."""
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        cx, cy, cz = v.co
        if taper and cz > 0: cx *= taper[0]; cy *= taper[1]
        v.co = Vector((cx * sx + x, cy * sy + y, cz * sz + z))
    return finish(name, bm, m, bevel, seg)

def lathe(name, prof, m, x=0.0, z=0.0, seg=48, axis='y', bevel=0.0, smooth=True):
    """Révolution d'un profil fermé [(rayon, position)] autour d'un axe passant par (x, z).
    axis='y' : axe avant-arrière (tubes) ; axis='z' : axe vertical (tourelles, boutons)."""
    bm = bmesh.new(); rings = []
    for i in range(seg):
        a = 2 * math.pi * i / seg; ca, sa = math.cos(a), math.sin(a)
        ring = []
        for r, t in prof:
            if axis == 'y': ring.append(bm.verts.new((x + r * ca, t, z + r * sa)))
            elif axis == 'x': ring.append(bm.verts.new((t, x + r * ca, z + r * sa)))
            else: ring.append(bm.verts.new((x + r * ca, z + r * sa, t)))
        rings.append(ring)
    n = len(prof)
    for i in range(seg):
        A, B = rings[i], rings[(i + 1) % seg]
        for j in range(n):
            k = (j + 1) % n
            try: bm.faces.new((A[j], A[k], B[k], B[j]))
            except ValueError: pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return finish(name, bm, m, bevel, smooth=smooth, angle=35)

def tube_prof(ro, ri, y0, y1):
    """Profil d'un tube creux (anneau) de y0 à y1."""
    return [(ri, y0), (ro, y0), (ro, y1), (ri, y1)]

def cyl(name, r, L, x, y, z, m, axis='z', seg=24, bevel=0.0):
    """Cylindre plein : axe 'z' (vertical), 'y' (avant) ou 'x' (latéral), centré en (x,y,z)."""
    if axis == 'z': return lathe(name, [(0, z - L/2), (r, z - L/2), (r, z + L/2), (0, z + L/2)], m, x=x, z=y, seg=seg, axis='z', bevel=bevel)
    if axis == 'y': return lathe(name, [(0, y - L/2), (r, y - L/2), (r, y + L/2), (0, y + L/2)], m, x=x, z=z, seg=seg, axis='y', bevel=bevel)
    return lathe(name, [(0, x - L/2), (r, x - L/2), (r, x + L/2), (0, x + L/2)], m, x=y, z=z, seg=seg, axis='x', bevel=bevel)

def knurl_turret(name, r, h, x, y, z, m, axis='z', ribs=18):
    """Tourelle de réglage moletée : cylindre dont un sommet sur deux est creusé (cannelures)."""
    seg = ribs * 2
    o = cyl(name, r, h, x, y, z, m, axis=axis, seg=seg)
    for v in o.data.vertices:
        c = v.co
        if axis == 'z': d = Vector((c.x - x, c.y - y, 0)); a = math.atan2(d.y, d.x)
        elif axis == 'x': d = Vector((0, c.y - y, c.z - z)); a = math.atan2(d.z, d.y)
        else: d = Vector((c.x - x, 0, c.z - z)); a = math.atan2(d.z, d.x)
        if d.length > r * 0.9 and round(a / (2 * math.pi / seg)) % 2:
            v.co = c - d.normalized() * r * 0.09
    return o

def rail_clamp(L, w, h, y=0.0, m=None, lever=True):
    """Embase pour rail Picatinny : semelle, mâchoires en queue d'aronde, vis ou levier rapide."""
    m = m or M_dark()
    box('clamp_base', w, L, h * 0.55, 0, y, h * 0.275, m, bevel=0.0015)
    box('clamp_jaw_L', w * 0.18, L * 0.92, h * 0.5, -w * 0.5, y, h * 0.2, m, bevel=0.001, taper=(1.0, 1.0))
    box('clamp_jaw_R', w * 0.18, L * 0.92, h * 0.5, w * 0.5, y, h * 0.2, m, bevel=0.001)
    for i, dy in enumerate((-L * 0.25, L * 0.25)):
        cyl('clamp_screw%d' % i, h * 0.18, w * 0.25, w * 0.62, y + dy, h * 0.25, M_metal(), axis='x', seg=12)
    if lever:
        box('qd_lever', w * 0.12, L * 0.55, h * 0.32, w * 0.68, y, h * 0.32, M_dark(), bevel=0.001)

def bore(o, r, z, y0, y1, x=0.0):
    """Perce un trou cylindrique le long de l'axe de visée (Y) : la ligne de visée reste dégagée."""
    c = cyl(o.name + '_bore', r, y1 - y0, x, (y0 + y1) / 2, z, M_body(), axis='y', seg=48)
    b = o.modifiers.new('Bore', 'BOOLEAN'); b.operation = 'DIFFERENCE'; b.object = c; b.solver = 'EXACT'
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
    o.modifiers.clear(); o.data = me
    bpy.data.objects.remove(c, do_unlink=True)
    for p in me.polygons: p.use_smooth = True
    o.modifiers.new('WN', 'WEIGHTED_NORMAL').keep_sharp = True
    return o

def export(key, info):
    os.makedirs(OUT, exist_ok=True)
    for o in bpy.data.objects: o.select_set(True)
    path = os.path.join(OUT, key + '.glb')
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=False, export_apply=True,
                              export_yup=True, export_materials='EXPORT', export_normals=True, export_texcoords=False)
    tris = sum(len(o.data.polygons) for o in bpy.data.objects if o.type == 'MESH')
    info['key'] = key; info['faces'] = tris
    with open(os.path.join(OUT, key + '.json'), 'w') as f: json.dump(info, f)
    print(key, 'faces', tris, os.path.getsize(path), 'octets')

# ---------------------------------------------------------------- point rouge (tube type Aimpoint)
def build_reddot():
    clear()
    R, L, CY = 0.0215, 0.056, 0.036
    rail_clamp(0.05, 0.026, 0.012)
    box('riser', 0.016, 0.034, CY - 0.012 - R + 0.006, 0, 0, 0.012 + (CY - 0.012 - R + 0.006) / 2, M_body(), bevel=0.002, taper=(0.8, 0.9))
    # corps : tube avec bagues avant/arrière plus larges (pare-soleil) et gorges
    prof = [(R - 0.0035, -L/2), (R + 0.002, -L/2), (R + 0.002, -L/2 + 0.006), (R, -L/2 + 0.008), (R, -0.004),
            (R - 0.0006, -0.003), (R - 0.0006, 0.003), (R, 0.004), (R, L/2 - 0.008), (R + 0.0025, L/2 - 0.006),
            (R + 0.0025, L/2), (R - 0.0035, L/2)]
    lathe('tube', prof, M_body(), z=CY, seg=64)
    # tourelles (hauteur dessus, dérive à droite) avec capuchons
    knurl_turret('turret_top', 0.0085, 0.008, 0, 0.002, CY + R + 0.003, M_dark())
    cyl('turret_top_cap', 0.0075, 0.0025, 0, 0.002, CY + R + 0.0085, M_body(), seg=24, bevel=0.0006)
    knurl_turret('turret_side', 0.0085, 0.008, R + 0.003, 0.002, CY, M_dark(), axis='x')
    # bouton de luminosité (gauche) + compartiment pile
    knurl_turret('dial', 0.009, 0.007, -R - 0.0025, -0.006, CY, M_dark(), axis='x', ribs=14)
    cyl('dial_cap', 0.006, 0.002, -R - 0.007, -0.006, CY, M_metal(), axis='x', seg=20)
    cyl('led', 0.0011, 0.002, -R - 0.0081, -0.006, CY, M_red(), axis='x', seg=10)
    # protège-lentilles rabattus (caoutchouc, articulés sous le tube)
    for nm, y, s in (('cap_front', L/2 + 0.002, 1), ('cap_rear', -L/2 - 0.002, -1)):
        lathe(nm, tube_prof(R + 0.0035, R + 0.0018, y - 0.004, y + 0.004), M_rub(), z=CY, seg=40)
    export('reddot', {'cy': CY, 'lensY': L/2 - 0.004, 'lensR': R - 0.004, 'len': L})

# ---------------------------------------------------------------- holographique (type EOTech)
def build_holo():
    clear()
    CY, W, LEN = 0.027, 0.036, 0.09
    rail_clamp(0.06, 0.028, 0.008, y=-0.008, lever=False)
    # corps bas (logement des piles), avant légèrement incliné
    box('body', W, LEN, 0.013, 0, 0, 0.008 + 0.0065, M_body(), bevel=0.002, taper=(0.96, 0.97))
    # vis transversale de fixation
    cyl('crossbolt', 0.0035, W + 0.008, 0, -0.012, 0.007, M_metal(), axis='x', seg=16)
    box('crossbolt_nut', 0.006, 0.006, 0.006, -W / 2 - 0.004, -0.012, 0.007, M_dark())
    # boutons sur l'arrière (luminosité / NV)
    for i, x in enumerate((-0.008, 0.008)):
        box('button%d' % i, 0.007, 0.004, 0.005, x, -LEN / 2 - 0.001, 0.016, M_rub(), bevel=0.001)
    # capot (hood) : arceau ouvert qui protège la fenêtre
    WIN_W, WIN_H, YW0, YW1 = 0.030, 0.026, -0.006, 0.034
    th = 0.0032
    box('hood_top', WIN_W + 2 * th + 0.004, YW1 - YW0 + 0.006, th, 0, (YW0 + YW1) / 2, CY + WIN_H / 2 + th / 2, M_body(), bevel=0.0012)
    for s in (-1, 1):
        box('hood_side%d' % (s > 0), th, YW1 - YW0 + 0.006, WIN_H + th, s * (WIN_W / 2 + th / 2 + 0.002), (YW0 + YW1) / 2, CY + th / 2 - 0.0015, M_body(), bevel=0.0012)
        # trous d'allègement dans les flancs
        box('hood_rib%d' % (s > 0), th * 1.15, 0.012, 0.005, s * (WIN_W / 2 + th / 2 + 0.002), (YW0 + YW1) / 2, CY - 0.004, M_dark(), bevel=0.0006)
    # cadres des deux vitres (avant / arrière)
    for nm, y in (('frame_front', YW1 - 0.002), ('frame_rear', YW0 + 0.002)):
        box(nm + '_b', WIN_W + 0.004, 0.003, 0.003, 0, y, CY - WIN_H / 2 + 0.0015, M_dark(), bevel=0.0005)
    # logo / plaque sur le côté
    box('plate', 0.0006, 0.03, 0.006, W / 2 + 0.0003, 0.002, 0.0145, M_tan(), bevel=0.0002)
    export('holo', {'cy': CY, 'lensY': YW0 + 0.003, 'lensW': WIN_W - 0.002, 'lensH': WIN_H - 0.002, 'len': LEN})

# ---------------------------------------------------------------- mini réflex (type RMR)
def build_mini():
    clear()
    CY, W, LEN = 0.019, 0.026, 0.042
    # semelle
    box('base', W, LEN, 0.008, 0, 0, 0.004, M_body(), bevel=0.0018, taper=(0.95, 0.96))
    # capot en arceau (forme en « bouclier »), ouvert devant et derrière
    WIN_W, WIN_H, Y0, Y1 = 0.021, 0.019, -0.009, 0.006
    t = 0.0034
    for s in (-1, 1):
        box('wing%d' % (s > 0), t, Y1 - Y0 + 0.012, WIN_H + 0.004, s * (WIN_W / 2 + t / 2), (Y0 + Y1) / 2 - 0.003, 0.008 + (WIN_H + 0.004) / 2, M_body(), bevel=0.0012, taper=(0.75, 0.75))
    box('arch', WIN_W + 2 * t, 0.009, t, 0, Y1 - 0.001, CY + WIN_H / 2 + t / 2 - 0.001, M_body(), bevel=0.0012)
    # bouton de luminosité, vis de réglage
    box('btn_L', 0.0016, 0.006, 0.004, -W / 2 - 0.0008, -0.012, 0.007, M_rub(), bevel=0.0005)
    box('btn_R', 0.0016, 0.006, 0.004, W / 2 + 0.0008, -0.012, 0.007, M_rub(), bevel=0.0005)
    cyl('adj_top', 0.0022, 0.0012, 0, -0.014, 0.0086, M_metal(), seg=12)
    cyl('adj_side', 0.0022, 0.0012, W / 2 + 0.0004, -0.004, 0.006, M_metal(), axis='x', seg=12)
    # LED (émetteur) au fond de la fenêtre
    box('emitter', 0.005, 0.004, 0.003, 0, -0.012, 0.0095, M_dark(), bevel=0.0006)
    cyl('led', 0.0008, 0.0012, 0, -0.0098, 0.0105, M_red(), axis='y', seg=8)
    export('mini', {'cy': CY, 'lensY': Y1 - 0.002, 'lensW': WIN_W - 0.002, 'lensH': WIN_H - 0.002, 'len': LEN})

# ---------------------------------------------------------------- lunette à prisme ×2,5 (type ACOG)
def build_acog():
    clear()
    R, CY, LEN = 0.0215, 0.038, 0.13
    rail_clamp(0.07, 0.026, 0.012, y=-0.004)
    box('neck', 0.018, 0.05, CY - R - 0.012 + 0.005, 0, -0.004, 0.012 + (CY - R - 0.012 + 0.005) / 2, M_body(), bevel=0.002, taper=(0.85, 0.9))
    # corps : objectif évasé à l'avant, boîtier de prisme au milieu, oculaire en caoutchouc à l'arrière
    prof = [(R * 0.82, -LEN / 2), (R * 1.08, -LEN / 2), (R * 1.08, -LEN / 2 + 0.018), (R * 0.82, -LEN / 2 + 0.026),
            (R * 0.82, LEN / 2 - 0.04), (R * 1.22, LEN / 2 - 0.022), (R * 1.22, LEN / 2), (R * 1.0, LEN / 2)]
    lathe('tube', prof, M_body(), z=CY, seg=64)
    bore(box('prism_box', 0.034, 0.05, 0.03, 0, -0.004, CY, M_body(), bevel=0.004, seg=3), R * 0.82, CY, -0.04, 0.032)
    lathe('eyecup', tube_prof(R * 1.12, R * 0.86, -LEN / 2 - 0.012, -LEN / 2 + 0.002), M_rub(), z=CY, seg=48)
    # fibre optique sur le dessus (tube rouge lumineux) + garde
    box('fiber_rail', 0.007, 0.05, 0.003, 0, -0.002, CY + 0.0165, M_dark(), bevel=0.0008)
    cyl('fiber', 0.0016, 0.046, 0, -0.002, CY + 0.0192, M_fiber(), axis='y', seg=10)
    # bouchons de réglage
    knurl_turret('cap_top', 0.0065, 0.006, 0, 0.012, CY + 0.018, M_dark())
    knurl_turret('cap_side', 0.0065, 0.006, 0.0195, 0.012, CY, M_dark(), axis='x')
    # viseur de secours sur le dessus (petit réflex)
    box('backup', 0.012, 0.016, 0.008, 0, -0.03, CY + 0.019, M_body(), bevel=0.0012)
    export('acog', {'cy': CY, 'lensY': LEN / 2 - 0.006, 'lensR': R * 1.1, 'len': LEN})

# ---------------------------------------------------------------- lunette de précision (×4 à ×10)
def build_scope():
    clear()
    R, LEN = 0.0125, 0.24
    OBJ, EYE = 0.024, 0.0205
    CY = 0.012 + 0.012 + OBJ  # anneaux bas + rail
    # tube central 25 mm, cloche d'objectif à l'avant, oculaire à l'arrière
    prof = [(EYE - 0.004, -LEN / 2), (EYE, -LEN / 2), (EYE, -LEN / 2 + 0.035), (R + 0.002, -LEN / 2 + 0.06),
            (R, -LEN / 2 + 0.068), (R, -0.015), (R + 0.006, -0.012), (R + 0.006, 0.012), (R, 0.015),
            (R, LEN / 2 - 0.07), (OBJ, LEN / 2 - 0.035), (OBJ, LEN / 2), (OBJ - 0.003, LEN / 2)]
    lathe('tube', prof, M_body(), z=CY, seg=64)
    # bague de grossissement moletée + repère
    lathe('power_ring', tube_prof(EYE + 0.0015, EYE - 0.001, -LEN / 2 + 0.008, -LEN / 2 + 0.026), M_rub(), z=CY, seg=48)
    box('power_mark', 0.002, 0.004, 0.0015, 0, -LEN / 2 + 0.017, CY + EYE + 0.0018, M_tan(), bevel=0.0003)
    # tourelles hauteur / dérive, bouton de parallaxe à gauche
    knurl_turret('turret_top', 0.0095, 0.012, 0, 0, CY + R + 0.009, M_dark(), ribs=22)
    cyl('turret_top_cap', 0.0085, 0.003, 0, 0, CY + R + 0.0165, M_body(), seg=28, bevel=0.0006)
    knurl_turret('turret_side', 0.0095, 0.012, R + 0.009, 0, CY, M_dark(), axis='x', ribs=22)
    knurl_turret('parallax', 0.0085, 0.008, -R - 0.007, 0, CY, M_dark(), axis='x', ribs=18)
    # pare-soleil et protège-lentille avant rabattu
    lathe('sunshade', tube_prof(OBJ + 0.001, OBJ - 0.0015, LEN / 2, LEN / 2 + 0.025), M_body(), z=CY, seg=56)
    # anneaux de montage sur embase
    for i, y in enumerate((-0.05, 0.05)):
        lathe('ring%d' % i, tube_prof(R + 0.0035, R, y - 0.007, y + 0.007), M_dark(), z=CY, seg=48)
        box('ring%d_post' % i, 0.012, 0.014, CY - R - 0.012, 0, y, 0.012 + (CY - R - 0.012) / 2, M_dark(), bevel=0.0012)
        box('ring%d_cap' % i, 0.008, 0.014, 0.004, 0, y, CY + R + 0.002, M_dark(), bevel=0.0008)
        for s in (-1, 1): cyl('ring%d_bolt%d' % (i, s > 0), 0.0016, 0.004, s * (R + 0.003), y, CY + R * 0.6, M_metal(), seg=10)
    rail_clamp(0.13, 0.026, 0.012, lever=False)
    export('scope', {'cy': CY, 'lensY': LEN / 2 - 0.004, 'lensR': OBJ - 0.004, 'eyeY': -LEN / 2, 'eyeR': EYE - 0.004, 'len': LEN + 0.025, 'r': R})

for f in (build_reddot, build_holo, build_mini, build_acog, build_scope):
    f()
