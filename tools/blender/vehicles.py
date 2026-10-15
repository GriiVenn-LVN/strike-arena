# Modélise les véhicules des arrivées en voiture et les exporte en GLB.
# Lancement (Blender en module Python, sans interface) :
#   python3 tools/blender/vehicles.py          (avec le paquet pip « bpy »)
# ou dans Blender : blender -b -P tools/blender/vehicles.py
# Repère Blender : +Y = avant du véhicule, +Z = haut, mètres. L'export glTF passe en Y-haut
# (avant = -Z dans le jeu). Les objets nommés wheel_*, door_*, tailgate, beacon_* sont animés par
# le jeu (src/65b_car.js) ; les matériaux sont reconnus par leur nom (paint, tarp, inner…).
import bpy, bmesh, math, os, json, sys
from mathutils import Vector, Matrix

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'models', 'vehicles')

def clear():
    # read_factory_settings plante le module bpy (glog initialisé deux fois) : on vide à la main.
    for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.curves, bpy.data.cameras, bpy.data.lights):
        for d in list(coll): coll.remove(d)
    MATS.clear()

MATS = {}
def mat(name, col, metal=0.0, rough=0.6, emit=None, alpha=1.0):
    if name in MATS: return MATS[name]
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes.get('Principled BSDF')
    b.inputs['Base Color'].default_value = (*col, 1)
    b.inputs['Metallic'].default_value = metal; b.inputs['Roughness'].default_value = rough
    if emit:
        b.inputs['Emission Color'].default_value = (*emit, 1); b.inputs['Emission Strength'].default_value = 3.0
    if alpha < 1:
        b.inputs['Alpha'].default_value = alpha
        try: m.surface_render_method = 'BLENDED'
        except Exception: pass
    MATS[name] = m; return m

def obj(name, bm, m, bevel=0.0, seg=2, smooth=True, origin=None):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    if isinstance(m, (list, tuple)):
        for mm in m: me.materials.append(mm)
    elif m: me.materials.append(m)
    if bevel > 0:
        b = o.modifiers.new('Bevel', 'BEVEL'); b.width = bevel; b.segments = seg
        b.limit_method = 'ANGLE'; b.angle_limit = math.radians(40); b.harden_normals = True
    if smooth:
        for p in me.polygons: p.use_smooth = True
        o.modifiers.new('WN', 'WEIGHTED_NORMAL').keep_sharp = True
    if origin is not None:
        # déplace l'origine (pivot des roues / charnières) sans bouger la géométrie
        off = Vector(origin)
        me.transform(Matrix.Translation(-off)); o.location = off
    return o

def box(name, sx, sy, sz, x, y, z, m, bevel=0.02, origin=None, taper=None):
    """Boîte centrée en (x,y,z). taper=(fx,fy) rétrécit le dessus (capots, cabines)."""
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        cx, cy, cz = v.co
        if taper and cz > 0: cx *= taper[0]; cy *= taper[1]
        v.co = Vector((cx * sx + x, cy * sy + y, cz * sz + z))
    return obj(name, bm, m, bevel, origin=origin)

def wedge(name, pts_yz, width, x, m, bevel=0.015):
    """Profil (y,z) extrudé sur la largeur (axe X), centré en x."""
    bm = bmesh.new()
    vs0 = [bm.verts.new((x - width / 2, y, z)) for y, z in pts_yz]
    vs1 = [bm.verts.new((x + width / 2, y, z)) for y, z in pts_yz]
    bm.faces.new(vs0[::-1]); bm.faces.new(vs1)
    n = len(pts_yz)
    for i in range(n):
        j = (i + 1) % n; bm.faces.new((vs0[i], vs0[j], vs1[j], vs1[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return obj(name, bm, m, bevel)

def cyl(name, r, depth, x, y, z, m, axis='X', seg=24, bevel=0.0, r2=None, origin=None):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=depth)
    for v in bm.verts:
        cx, cy, cz = v.co
        if axis == 'X': v.co = Vector((cz, cy, cx))
        elif axis == 'Y': v.co = Vector((cx, cz, cy))
        v.co += Vector((x, y, z))
    return obj(name, bm, m, bevel, origin=origin)

def join(name, objs, origin=None):
    """Fusionne des objets (modificateurs appliqués) en un seul maillage."""
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active; o.name = name
    if origin is not None:
        bpy.context.scene.cursor.location = origin
        bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    return o

def tire(name, r, w, x, y, z, rubber, rim, nut):
    """Pneu à crampons + jante + écrous, pivot au centre de la roue (axe X)."""
    bm = bmesh.new()
    seg, blocks = 40, 20
    # profil du pneu (r,dx) tourné autour de l'axe X : flanc arrondi
    prof = [(r * .62, -w / 2), (r * .9, -w / 2), (r * .98, -w * .42), (r, -w * .3), (r, w * .3), (r * .98, w * .42), (r * .9, w / 2), (r * .62, w / 2)]
    rings = []
    for i in range(seg):
        a = i / seg * math.tau; ca, sa = math.cos(a), math.sin(a)
        tread = 1.0 + (0.035 if (i * blocks // seg) % 2 == 0 else 0.0)
        ring = []
        for k, (rr, dx) in enumerate(prof):
            f = tread if 2 <= k <= 5 else 1.0
            ring.append(bm.verts.new((dx, ca * rr * f, sa * rr * f)))
        rings.append(ring)
    for i in range(seg):
        a, b = rings[i], rings[(i + 1) % seg]
        for k in range(len(prof) - 1): bm.faces.new((a[k], b[k], b[k + 1], a[k + 1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    t = obj(name + '_t', bm, rubber, 0, smooth=True)
    parts = [t]
    for s in (-1, 1):
        parts.append(cyl(name + '_r%d' % s, r * .62, w * .9, 0, 0, 0, rim, 'X', 28, 0.01, r2=r * .55))
        parts.append(cyl(name + '_h%d' % s, r * .2, w * .95, 0, 0, 0, rim, 'X', 16, 0.008))
    for i in range(8):
        a = i / 8 * math.tau
        for s in (-1, 1): parts.append(cyl(name + '_n%d%d' % (i, s), .025, w * .98, 0, math.cos(a) * r * .32, math.sin(a) * r * .32, nut, 'X', 6))
    o = join(name, parts)
    o.location = (x, y, z)
    return o

def export(name, meta):
    os.makedirs(OUT, exist_ok=True)
    for o in bpy.context.scene.objects: o.select_set(True)
    path = os.path.join(OUT, name + '.glb')
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', export_apply=True, export_yup=True,
                              export_texcoords=True, export_normals=True, export_materials='EXPORT',
                              use_selection=False, export_animations=False)
    with open(os.path.join(OUT, name + '.json'), 'w') as f: json.dump(meta, f)
    tris = sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type == 'MESH')
    print(name, os.path.getsize(path), 'octets', tris, 'faces')

def lights(paint, W, yf, zl):
    pass

# ----------------------------------------------------------------------------------------------
#  Blindé d'intervention (type BearCat) : caisse blindée à facettes, pare-buffle, meurtrières
# ----------------------------------------------------------------------------------------------
def build_blinde():
    clear(); MATS.clear()
    paint = mat('paint', (.05, .055, .06), .45, .5)
    dark = mat('dark', (.02, .02, .022), .3, .6)
    chrome = mat('chrome', (.7, .7, .72), 1, .25)
    rubber = mat('rubber', (.015, .015, .015), 0, .92)
    rim = mat('rim', (.08, .085, .09), .8, .4)
    glass = mat('glass', (.05, .08, .1), .6, .05, alpha=.35)
    inner = mat('inner', (.2, .21, .23), .3, .7)
    seat = mat('seat', (.06, .06, .065), 0, .9)
    floor = mat('floor', (.1, .1, .11), .6, .7)
    head = mat('headlight', (1, 1, .95), 0, .2, emit=(1, .97, .9))
    tail = mat('taillight', (.5, 0, 0), 0, .3, emit=(1, .1, .05))
    amber = mat('amber', (.6, .35, 0), 0, .3, emit=(1, .55, .05))
    W, CF, YR, YF = 1.12, .78, -2.95, 3.05      # demi-largeur, plancher cellule, arrière, avant
    # châssis et marchepieds
    box('frame', W * 1.6, 5.6, .22, 0, 0, .62, dark, .02)
    for s in (-1, 1):
        box('step%d' % s, .32, 1.1, .05, s * (W + .1), -.2, .55, chrome, .01)
        box('steparm%d' % s, .06, .9, .2, s * (W - .05), -.2, .62, dark, .01)
    # capot moteur à pans coupés + calandre
    wedge('hood', [(1.45, CF), (YF - .05, CF), (YF, CF + .25), (YF - .1, CF + .78), (1.45, CF + .9)], W * 1.9, 0, paint, .03)
    box('grille', W * 1.4, .05, .5, 0, YF + .02, CF + .45, dark, .01)
    for i in range(9): box('slat%d' % i, .04, .07, .44, -W * .62 + i * W * 1.24 / 8, YF + .05, CF + .45, chrome, .005)
    for s in (-1, 1):
        cyl('hl%d' % s, .11, .06, s * (W - .32), YF + .03, CF + .58, head, 'Y', 20, .01)
        cyl('hlr%d' % s, .14, .05, s * (W - .32), YF + .01, CF + .58, chrome, 'Y', 20, .01)
        box('turn%d' % s, .14, .05, .07, s * (W - .1), YF + .02, CF + .3, amber, .01)
    # pare-buffle (barres tubulaires) + treuil
    for s in (-1, 1): cyl('pbv%d' % s, .045, .9, s * .55, YF + .35, CF + .1, chrome, 'Z', 12)
    cyl('pbh1', .05, W * 2.0, 0, YF + .35, CF + .5, chrome, 'X', 12)
    cyl('pbh2', .05, W * 1.6, 0, YF + .35, CF - .1, chrome, 'X', 12)
    box('bumper', W * 2.1, .22, .28, 0, YF + .12, CF - .2, dark, .03)
    box('winch', .5, .2, .2, 0, YF + .25, CF - .02, dark, .02)
    # caisse blindée : profil à pans (cabine + cellule), creusée par des panneaux séparés pour voir dedans
    zR = 2.72
    # flancs (épais), avec ouverture de vitre cabine
    for s in (-1, 1):
        wedge('side%d' % s, [(YR, CF), (1.45, CF), (1.45, CF + .9), (1.25, CF + 1.1), (1.25, CF + 1.15), (YR, CF + 1.15)], .08, s * W, paint, .02)
        wedge('sideup%d' % s, [(YR, CF + 1.15), (.2, CF + 1.15), (.2, zR - .05), (YR, zR - .05)], .08, s * W, paint, .02)
        wedge('pillar%d' % s, [(.2, CF + 1.15), (1.25, CF + 1.15), (1.05, zR - .2), (.2, zR - .2)], .08, s * W, paint, .02)
        wedge('winframe%d' % s, [(.35, CF + 1.25), (1.1, CF + 1.25), (.95, zR - .32), (.35, zR - .32)], .1, s * W, dark, .01)
        wedge('win%d' % s, [(.4, CF + 1.3), (1.05, CF + 1.3), (.92, zR - .36), (.4, zR - .36)], .02, s * (W + .02), glass, 0)
        # meurtrières rondes + vitres blindées de la cellule
        for y in (-.6, -1.9):
            cyl('port%d%d' % (s, int(y * 10)), .09, .06, s * (W + .04), y, CF + 1.45, dark, 'X', 16, .005)
            box('swin%d%d' % (s, int(y * 10)), .03, .5, .28, s * (W + .02), y + .35, CF + 1.6, glass, 0)
            box('swinf%d%d' % (s, int(y * 10)), .05, .58, .36, s * (W + .01), y + .35, CF + 1.6, dark, .01)
        # rétroviseur
        box('mirarm%d' % s, .35, .04, .04, s * (W + .18), 1.15, CF + 1.35, dark, .01)
        box('mirror%d' % s, .06, .14, .26, s * (W + .36), 1.12, CF + 1.35, dark, .02)
        # poignées de flanc, ailes avant/arrière
        cyl('handle%d' % s, .02, 2.2, s * (W + .06), -1.2, CF + 1.95, chrome, 'Y', 8)
        for yw in (1.95, -1.75):
            wedge('fender%d%d' % (s, int(yw)), [(yw - .7, CF - .05), (yw + .7, CF - .05), (yw + .55, CF + .22), (yw - .55, CF + .22)], .22, s * (W + .02), dark, .02)
        box('tail%d' % s, .2, .05, .12, s * (W - .18), YR - .02, CF + .4, tail, .01)
    # toit, pare-brise, trappe tourelle, rampe lumineuse
    wedge('roof', [(YR, zR - .05), (1.05, zR - .2), (1.05, zR - .08), (YR, zR + .05)], W * 2 + .08, 0, paint, .03)
    wedge('wsframe', [(1.25, CF + 1.12), (1.45, CF + .9), (1.48, CF + .92), (1.08, zR - .18), (1.02, zR - .2)], W * 2, 0, paint, .02)
    bm = bmesh.new()
    for v in [(-W + .1, 1.38, CF + 1.0), (W - .1, 1.38, CF + 1.0), (W - .1, 1.08, zR - .25), (-W + .1, 1.08, zR - .25)]: bm.verts.new(v)
    bm.faces.new(bm.verts); obj('windshield', bm, glass, 0, smooth=False)
    cyl('hatch', .42, .12, 0, -1.2, zR + .08, paint, 'Z', 28, .015)
    cyl('hatchring', .5, .06, 0, -1.2, zR + .03, dark, 'Z', 28, .01)
    box('lbar', 1.5, .25, .1, 0, .7, zR + .1, dark, .02)
    for s in (-1, 1):
        b = box('beacon_%s' % ('L' if s < 0 else 'R'), .55, .2, .1, s * .4, .7, zR + .2, mat('beacon_%s' % ('L' if s < 0 else 'R'), (.05, .1, .6) if s < 0 else (.6, .05, .05), 0, .2), .02)
        cyl('antenna%d' % s, .008, 1.2, s * (W - .1), -2.6, zR + .6, dark, 'Z', 6)
    # arrière : pare-chocs, marchepied, plaque
    box('rbumper', W * 2, .25, .22, 0, YR - .1, CF - .1, dark, .03)
    box('rstep', 1.1, .3, .05, 0, YR - .25, CF - .25, chrome, .01)
    # portes arrière (pivot sur les charnières, ouvrent vers l'extérieur)
    for s, nm in ((-1, 'door_L'), (1, 'door_R')):
        hx = s * W
        parts = [box(nm + '_p', W - .02, .08, zR - CF - .1, hx - s * (W / 2), YR, (zR + CF) / 2, paint, .02),
                 box(nm + '_i', W - .1, .02, zR - CF - .2, hx - s * (W / 2), YR + .05, (zR + CF) / 2, inner, .005),
                 box(nm + '_w', .3, .03, .25, hx - s * (W / 2), YR - .05, CF + 1.45, glass, 0),
                 box(nm + '_wf', .38, .04, .33, hx - s * (W / 2), YR - .04, CF + 1.45, dark, .01),
                 cyl(nm + '_port', .08, .05, hx - s * (W / 2), YR - .05, CF + 1.0, dark, 'Y', 14),
                 box(nm + '_hd', .05, .06, .25, hx - s * (W - .15), YR - .06, CF + 1.0, chrome, .01)]
        for zh in (CF + .4, zR - .4): parts.append(cyl(nm + '_hg%d' % int(zh * 10), .03, .18, hx, YR - .03, zh, chrome, 'Z', 10))
        join(nm, parts, origin=(hx, YR, CF))
    # intérieur : plancher, plafond, parois, banquettes, cloison, sièges avant, tableau de bord, volant
    box('ifloor', W * 2 - .12, 4.25, .04, 0, YR + 2.13, CF + .02, floor, .005)
    box('iceil', W * 2 - .12, 4.3, .03, 0, YR + 2.15, zR - .1, inner, .005)
    for s in (-1, 1):
        box('iwall%d' % s, .03, 3.0, zR - CF - .25, s * (W - .06), YR + 1.55, (zR + CF) / 2, inner, .005)
        box('bench%d' % s, .45, 2.6, .08, s * (W - .32), YR + 1.55, CF + .46, seat, .02)
        box('benchleg%d' % s, .35, 2.5, .38, s * (W - .32), YR + 1.55, CF + .22, inner, .01)
        box('back%d' % s, .07, 2.6, .6, s * (W - .11), YR + 1.55, CF + .85, seat, .02)
        box('fseat%d' % s, .5, .5, .12, s * .5, .45, CF + .45, seat, .03)
        box('fback%d' % s, .5, .1, .75, s * .5, .2, CF + .85, seat, .03)
        box('part%d' % s, .42, .05, zR - CF, s * (W - .25), .05, (zR + CF) / 2, inner, .005)
        # étagères et équipement accroché
        box('rack%d' % s, .25, 2.4, .04, s * (W - .2), YR + 1.55, zR - .45, dark, .01)
        for k in range(3): box('bag%d%d' % (s, k), .22, .35, .25, s * (W - .2), YR + .8 + k * .75, zR - .3, mat('gear', (.12, .13, .1), 0, .9), .04)
    box('partop', W * 2, .05, .35, 0, .05, zR - .2, inner, .005)
    box('dash', W * 2 - .2, .45, .3, 0, 1.15, CF + .75, dark, .04)
    bm = bmesh.new(); bmesh.ops.create_cone(bm, cap_ends=False, segments=24, radius1=.18, radius2=.18, depth=.03)
    st = obj('steer', bm, dark, 0); st.location = (-.5, .9, CF + 1.05); st.rotation_euler = (math.radians(60), 0, 0)
    # roues (pivot au centre)
    for nm, x, y in (('wheel_FL', -W + .02, 1.95), ('wheel_FR', W - .02, 1.95), ('wheel_RL', -W + .02, -1.75), ('wheel_RR', W - .02, -1.75)):
        tire(nm, .5, .36, x, y, .5, rubber, rim, chrome)
    meta = {'CF': CF, 'W': W, 'rear': -YR, 'roof': zR, 'wheelR': .5, 'doors': 'twin',
            # places dans le repère du jeu (x, z ; arrière = +z) : coéquipiers, joueur, chauffeur
            'seats': [[-.8, .75], [.8, .75], [.8, 1.55], [.8, 2.35]], 'player': [-.8, 1.65], 'driver': [-.5, -.45]}
    export('blinde', meta)

# ----------------------------------------------------------------------------------------------
#  Camion militaire bâché (2 essieux) : cabine avancée, plateau à ridelles, bâche sur arceaux
# ----------------------------------------------------------------------------------------------
def build_camion(sand):
    clear(); MATS.clear()
    base = (.33, .29, .19) if sand else (.17, .2, .13)
    paint = mat('paint', base, .2, .6)
    tarp = mat('tarp', ((.42, .37, .26) if sand else (.22, .25, .17)), 0, .95)
    dark = mat('dark', (.025, .025, .025), .3, .6)
    chrome = mat('chrome', (.6, .6, .6), 1, .3)
    rubber = mat('rubber', (.015, .015, .015), 0, .92)
    rim = mat('rim', tuple(c * .7 for c in base), .5, .5)
    glass = mat('glass', (.05, .08, .1), .6, .05, alpha=.3)
    inner = mat('inner', tuple(c * .8 for c in base), .2, .7)
    wood = mat('wood', (.28, .2, .12), 0, .85)
    seat = mat('seat', (.07, .07, .06), 0, .9)
    head = mat('headlight', (1, 1, .95), 0, .2, emit=(1, .97, .9))
    tail = mat('taillight', (.5, 0, 0), 0, .3, emit=(1, .1, .05))
    W, CF, YR, YF = 1.2, 1.18, -3.3, 3.2
    zT = CF + 1.95   # haut des arceaux
    # châssis, réservoirs, roue de secours, échappement
    box('frame', W * 1.3, 6.4, .25, 0, 0, .95, dark, .02)
    for s in (-1, 1):
        cyl('tank%d' % s, .25, .9, s * (W - .25), .6, .85, paint, 'Y', 18, .02)
        box('box%d' % s, .5, .7, .4, s * (W - .3), -.6, .85, paint, .03)
    cyl('exhaust', .06, 1.4, W - .05, 1.55, CF + 1.0, dark, 'Z', 10)
    # cabine avancée (face plate), pare-brise deux parties, phares ronds, calandre
    cab_y0, cab_y1, cab_z1 = 1.65, YF, CF + 1.75
    wedge('cab', [(cab_y0, CF - .25), (cab_y1, CF - .25), (cab_y1, CF + .55), (cab_y1 - .25, cab_z1), (cab_y0, cab_z1)], W * 2, 0, paint, .04)
    box('grille', W * 1.2, .06, .5, 0, cab_y1 + .02, CF + .2, dark, .01)
    for i in range(11): box('gslat%d' % i, W * 1.15, .07, .02, 0, cab_y1 + .04, CF + .0 + i * .042, paint, .003)
    for s in (-1, 1):
        cyl('hl%d' % s, .14, .08, s * (W - .3), cab_y1 + .05, CF + .25, head, 'Y', 22, .01)
        cyl('hlr%d' % s, .18, .1, s * (W - .3), cab_y1 + .02, CF + .25, dark, 'Y', 22, .01)
        bm = bmesh.new()
        for v in [(s * .06, cab_y1 - .04, CF + .65), (s * (W - .12), cab_y1 - .04, CF + .65), (s * (W - .12), cab_y1 - .22, cab_z1 - .12), (s * .06, cab_y1 - .22, cab_z1 - .12)]: bm.verts.new(v)
        bm.faces.new(bm.verts); obj('ws%d' % s, bm, glass, 0, smooth=False)
        box('door%d' % s, .04, .9, .8, s * (W + .01), cab_y0 + .55, CF + .85, paint, .01)
        box('dwin%d' % s, .02, .7, .45, s * (W + .02), cab_y0 + .6, CF + 1.3, glass, 0)
        box('mirarm%d' % s, .3, .04, .04, s * (W + .15), cab_y1 - .3, CF + 1.4, dark, .01)
        box('mirror%d' % s, .05, .16, .3, s * (W + .32), cab_y1 - .3, CF + 1.35, dark, .02)
        box('cstep%d' % s, .3, .5, .05, s * (W + .05), cab_y0 + .55, CF - .45, dark, .01)
        wedge('ffender%d' % s, [(1.6, .9), (2.9, .9), (2.75, 1.3), (1.75, 1.3)], .4, s * (W - .05), paint, .03)
    box('fbumper', W * 2.1, .25, .3, 0, cab_y1 + .15, CF - .35, dark, .03)
    box('roofrack', W * 1.6, .9, .06, 0, 2.4, cab_z1 + .05, dark, .01)
    # plateau : plancher, ridelles (planches), hayon, bancs, arceaux et bâche
    box('bed', W * 2, YR * -1 + 1.45, .1, 0, (YR + 1.5) / 2, CF - .05, dark, .02)
    box('ifloor', W * 2 - .1, 4.6, .04, 0, (YR + 1.5) / 2, CF + .02, wood, .005)
    for s in (-1, 1):
        for k in range(3): box('plank%d%d' % (s, k), .06, 4.75, .16, s * (W - .02), (YR + 1.5) / 2, CF + .12 + k * .18, wood, .01)
        for y in (-2.9, -1.6, -.3, 1.0): box('post%d%d' % (s, int(y * 10)), .08, .08, .6, s * W, y, CF + .3, paint, .01)
        box('bench%d' % s, .38, 4.2, .07, s * (W - .3), (YR + 1.5) / 2 + .1, CF + .46, wood, .01)
        box('benchleg%d' % s, .3, 4.1, .38, s * (W - .3), (YR + 1.5) / 2 + .1, CF + .22, inner, .01)
        box('tail%d' % s, .2, .05, .12, s * (W - .2), YR - .05, CF - .2, tail, .01)
        wedge('rfender%d' % s, [(-2.6, .9), (-1.0, .9), (-1.15, 1.25), (-2.45, 1.25)], .36, s * (W - .05), paint, .03)
    box('front_board', W * 2, .06, .55, 0, 1.5, CF + .28, wood, .01)
    # arceaux
    for i, y in enumerate((-3.2, -2.1, -1.0, .1, 1.35)):
        prev = None
        for n, p in enumerate([(-W, y, CF + .6), (-W, y, zT - .25), (-W * .6, y, zT - .02), (0, y, zT + .05), (W * .6, y, zT - .02), (W, y, zT - .25), (W, y, CF + .6)]):
            if prev is not None:
                d = Vector(p) - Vector(prev)
                c = cyl('bow%d_%d' % (i, n), .03, d.length, 0, 0, 0, dark, 'Z', 8)
                c.location = (Vector(p) + Vector(prev)) / 2
                c.rotation_euler = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_euler()
            prev = p
    # bâche : surface subdivisée qui s'affaisse entre les arceaux, ouverte à l'arrière (rabat roulé)
    bm = bmesh.new(); ny, nu = 26, 18
    prof = [(-W - .03, CF + .55), (-W - .03, zT - .25), (-W * .6, zT - .02), (0, zT + .07), (W * .6, zT - .02), (W + .03, zT - .25), (W + .03, CF + .55)]
    def along(t):
        # point du profil (x,z) au paramètre t ∈ [0,1]
        segL = [(Vector(prof[i + 1]) - Vector(prof[i])).length for i in range(len(prof) - 1)]; tot = sum(segL); d = t * tot
        for i, L in enumerate(segL):
            if d <= L or i == len(segL) - 1:
                f = d / L if L else 0; a, b = Vector(prof[i]), Vector(prof[i + 1]); return a.lerp(b, min(f, 1))
            d -= L
    grid = []
    for j in range(ny + 1):
        y = YR + .08 + (1.45 - (YR + .08)) * j / ny
        bows = (-3.2, -2.1, -1.0, .1, 1.35); dist = min(abs(y - b) for b in bows)
        sag = .06 * math.sin(min(1, dist / .55) * math.pi / 2)
        row = []
        for k in range(nu + 1):
            p = along(k / nu)
            inward = Vector((-p.x, 0, -(p.y - (CF + .8)))).normalized() if k not in (0, nu) else Vector((0, 0, 0))
            q = Vector((p.x, y, p.y)) + inward * sag
            row.append(bm.verts.new(q))
        grid.append(row)
    for j in range(ny):
        for k in range(nu): bm.faces.new((grid[j][k], grid[j][k + 1], grid[j + 1][k + 1], grid[j + 1][k]))
    # avant fermé : panneau de bâche contre la cabine
    fr = [bm.verts.new((along(k / nu).x, 1.45, along(k / nu).y)) for k in range(nu + 1)]
    bm.faces.new(fr[::-1])
    o = obj('tarp', bm, tarp, 0)
    mod = o.modifiers.new('sol', 'SOLIDIFY'); mod.thickness = .02
    # rabat roulé au-dessus de l'ouverture arrière, sangles
    cyl('roll', .1, W * 2.05, 0, YR + .05, zT - .05, tarp, 'X', 16, .01)
    for s in (-1, 1): box('strap%d' % s, .05, .02, .35, s * .6, YR + .02, zT - .22, dark, .005)
    # hayon (pivot en bas, s'abaisse vers l'arrière)
    parts = [box('tg_p', W * 2 - .04, .06, .55, 0, YR, CF + .27, paint, .015)]
    for k in range(3): parts.append(box('tg_r%d' % k, W * 2 - .1, .03, .04, 0, YR - .04, CF + .1 + k * .18, dark, .005))
    for s in (-1, 1): parts.append(box('tg_l%d' % s, .08, .05, .12, s * (W - .15), YR - .05, CF + .45, chrome, .01))
    join('tailgate', parts, origin=(0, YR, CF))
    box('rbumper', W * 1.6, .2, .18, 0, YR - .05, CF - .5, dark, .02)
    # échelle d'accès arrière
    for s in (-1, 1): cyl('ladder%d' % s, .02, .55, s * .25, YR - .15, CF - .5, chrome, 'Z', 8)
    for k in range(3): cyl('rung%d' % k, .02, .5, 0, YR - .15, CF - .7 + k * .2, chrome, 'X', 8)
    # roues (pivot au centre) : grosses roues tout-terrain
    for nm, x, y in (('wheel_FL', -W + .05, 2.25), ('wheel_FR', W - .05, 2.25), ('wheel_RL', -W + .05, -1.85), ('wheel_RR', W - .05, -1.85)):
        tire(nm, .58, .42, x, y, .58, rubber, rim, chrome)
    meta = {'CF': CF, 'W': W, 'rear': -YR, 'roof': zT, 'wheelR': .58, 'doors': 'tailgate',
            'seats': [[-.9, -.5], [.9, -.5], [.9, .55], [.9, 1.6]], 'player': [-.9, .6], 'driver': None}
    export('camion', meta)

if __name__ == '__main__':
    which = sys.argv[-1] if len(sys.argv) > 1 else 'all'
    if which in ('all', 'blinde'): build_blinde()
    if which in ('all', 'camion'): build_camion(True)
