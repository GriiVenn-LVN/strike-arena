# Prépare un modèle d'arme importé (Sketchfab) pour le jeu :
#  - sépare les pièces animées (chargeur, culasse) d'après les os du squelette
#  - supprime squelette / caméras / lampes, applique les transformations
#  - oriente le canon vers +Y (=> -Z en glTF), haut = +Z, met à l'échelle réelle
#  - calcule les points d'ancrage (poignée, main gauche, bouche, ligne de visée)
#  - exporte models/weapons/<clé>.glb et un fichier d'infos JSON
# Variables attendues avant exécution : KEY, REAL_LEN, OUT_DIR, (FLIP=False)
import bpy, bmesh, json, math, os
from mathutils import Vector, Matrix

def run(KEY, REAL_LEN, OUT_DIR, FLIP=False, GRIP_OVERRIDE=None, CAT='rifle', INVERT=False, TEX=False, TEX_MAX=1024, JPEG_Q=82):
    # TEX=True : modèle texturé (série « réaliste ») -> on garde UV, normales et textures (réduites à TEX_MAX px, JPEG)
    scn = bpy.context.scene
    meshes = [o for o in scn.objects if o.type == 'MESH' and o.name != 'Icosphere']
    # --- 1. figer la pose et séparer les pièces selon l'os dominant ---
    parts = {}
    for o in meshes:
        dg = bpy.context.evaluated_depsgraph_get()
        oe = o.evaluated_get(dg)
        me = bpy.data.meshes.new_from_object(oe, preserve_all_data_layers=True, depsgraph=dg)
        me.transform(o.matrix_world)
        groups = {g.index: g.name for g in o.vertex_groups}
        bm = bmesh.new(); bm.from_mesh(me)
        deform = bm.verts.layers.deform.active
        # os dominant par face
        buckets = {}
        for f in bm.faces:
            w = {}
            if deform:
                for v in f.verts:
                    for gi, wt in v[deform].items(): w[gi] = w.get(gi, 0) + wt
            gname = groups.get(max(w, key=w.get), 'body') if w else (o.name if not groups else 'body')
            lname = gname.lower()
            role = 'mag' if ('mag' in lname and 'release' not in lname) or 'bullet' in lname else 'bolt' if ('bolt' in lname or 'charg' in lname or 'slide' in lname) else 'body'
            buckets.setdefault(role, []).append(f.index)
        for role, idxs in buckets.items():
            b2 = bm.copy(); keep = set(idxs)
            bmesh.ops.delete(b2, geom=[f for f in b2.faces if f.index not in keep], context='FACES')
            m2 = bpy.data.meshes.new(KEY + '_' + role); b2.to_mesh(m2); b2.free()
            for mt in me.materials: m2.materials.append(mt)
            parts.setdefault(role, []).append(m2)
        bm.free(); bpy.data.meshes.remove(me)
    # --- 2. nettoyer la scène ---
    for o in list(scn.objects): bpy.data.objects.remove(o, do_unlink=True)
    objs = {}
    for role, mlist in parts.items():
        obs = []
        for m in mlist:
            if not len(m.polygons): continue
            ob = bpy.data.objects.new(KEY + '_' + role, m); scn.collection.objects.link(ob); obs.append(ob)
        if not obs: continue
        bpy.ops.object.select_all(action='DESELECT')
        for ob in obs: ob.select_set(True)
        bpy.context.view_layer.objects.active = obs[0]
        if len(obs) > 1: bpy.ops.object.join()
        o = bpy.context.view_layer.objects.active; o.name = role; objs[role] = o
    allv = [o.matrix_world @ v.co for o in objs.values() for v in o.data.vertices]
    mn = Vector([min(v[i] for v in allv) for i in range(3)]); mx = Vector([max(v[i] for v in allv) for i in range(3)])
    size = mx - mn
    # --- 3. orientation : axe le plus long = canon. On l'aligne sur +Y ---
    ax = max(range(3), key=lambda i: size[i])
    R = Matrix.Identity(4)
    if ax == 0: R = Matrix.Rotation(math.radians(90), 4, 'Z')        # +X -> +Y
    elif ax == 2: R = Matrix.Rotation(math.radians(-90), 4, 'X')
    if FLIP: R = Matrix.Rotation(math.pi, 4, 'Z') @ R
    c = (mn + mx) / 2
    s = REAL_LEN / size[ax]
    M = Matrix.Scale(s, 4) @ R @ Matrix.Translation(-c)
    for o in objs.values(): o.data.transform(M); o.matrix_world = Matrix.Identity(4)
    V = [v.co.copy() for o in objs.values() for v in o.data.vertices]
    mn = Vector([min(v[i] for v in V) for i in range(3)]); mx = Vector([max(v[i] for v in V) for i in range(3)])
    # la bouche est le côté le plus fin : on compare l'épaisseur des 15 % avant / arrière
    def thick(y0, y1):
        zs = [v.z for v in V if y0 <= v.y <= y1]
        return (max(zs) - min(zs)) if zs else 0
    L = mx.y - mn.y
    if thick(mx.y - L*.15, mx.y) > thick(mn.y, mn.y + L*.15):
        Rf = Matrix.Rotation(math.pi, 4, 'Z')
        for o in objs.values(): o.data.transform(Rf)
        V = [v.co.copy() for o in objs.values() for v in o.data.vertices]
        mn = Vector([min(v[i] for v in V) for i in range(3)]); mx = Vector([max(v[i] for v in V) for i in range(3)])
    if INVERT:
        Rf = Matrix.Rotation(math.pi, 4, 'Z')
        for o in objs.values(): o.data.transform(Rf)
        V = [v.co.copy() for o in objs.values() for v in o.data.vertices]
        mn = Vector([min(v[i] for v in V) for i in range(3)]); mx = Vector([max(v[i] for v in V) for i in range(3)])
    # --- 4. points d'ancrage ---
    nb = 120; step = (mx.y - mn.y) / nb
    minz = [None]*nb; maxz = [None]*nb
    # échantillonnage le long des arêtes (les longues faces n'ont pas de sommets au milieu)
    S = []
    for o in objs.values():
        vs = o.data.vertices
        for e in o.data.edges:
            a = vs[e.vertices[0]].co; b = vs[e.vertices[1]].co
            n = max(1, int(abs(b.y - a.y) / (step*.5)))
            for k in range(n+1): S.append(a.lerp(b, k/n))
    for v in S:
        i = min(nb-1, int((v.y - mn.y) / step))
        minz[i] = v.z if minz[i] is None else min(minz[i], v.z)
        maxz[i] = v.z if maxz[i] is None else max(maxz[i], v.z)
    filled = [z for z in minz if z is not None]
    yof = lambda i: mn.y + (i+.5)*step
    bin_of = lambda y: min(nb-1, max(0, int((y - mn.y)/step)))
    magv = [v.co for v in objs['mag'].data.vertices] if 'mag' in objs else []
    magy = (sum(v.y for v in magv)/len(magv)) if magv else None
    def lowest(y0, y1):
        best = None
        for i in range(bin_of(y0), bin_of(y1)+1):
            if minz[i] is not None and (best is None or minz[i] < minz[best]): best = i
        return best
    def med(y0, y1):
        zs = sorted(minz[i] for i in range(bin_of(y0), bin_of(y1)+1) if minz[i] is not None)
        return zs[len(zs)//2] if zs else mn.z
    base = sorted(filled)[int(len(filled)*.7)]
    if CAT == 'pistol':
        gi = lowest(mn.y, mn.y + L*.55)
        gy = magy if magy is not None else yof(gi)
        top = med(mx.y - L*.35, mx.y)            # dessous de la glissière / du canon
        grip = Vector((0, gy + .012, top - .012))
    else:
        if magy is None:
            gi = lowest(mn.y + L*.2, mn.y + L*.6)
            magy = yof(gi) + .1
        if CAT == 'bullpup': gi = lowest(magy + .04, magy + .30)
        else: gi = lowest(magy - .26, magy - .035)
        gy = yof(gi)
        top = med(magy + .05, magy + .22) if CAT != 'bullpup' else med(gy + .04, gy + .2)
        grip = Vector((0, gy + .025, top - .01))
    if GRIP_OVERRIDE: grip = Vector(GRIP_OVERRIDE)
    muzzle_y = mx.y
    ly = grip.y + (muzzle_y - grip.y) * (.45 if CAT != 'pistol' else .0)
    li = bin_of(ly)
    # ne pas poser la main gauche sur le chargeur : on avance jusqu'au garde-main
    while CAT != 'pistol' and li < nb-2 and minz[li] is not None and minz[li] < grip.z - .05: li += 1
    ly = yof(li)
    left = Vector((0, ly, (minz[li] if minz[li] is not None else base) + .005)) if CAT != 'pistol' else grip.copy()
    fi = min(nb-1, max(0, int((muzzle_y - .06 - mn.y)/step)))
    win = [z for z in maxz[max(0, fi-10):fi+1] if z is not None]
    if not win: win = [z for z in maxz[nb//2:] if z is not None]
    sight = max(win) if win else mx.z
    # recentrer : origine = poignée (main droite)
    T = Matrix.Translation(-grip)
    for o in objs.values(): o.data.transform(T)
    mn -= grip; mx -= grip; left -= grip; muzzle_y -= grip.y; sight -= grip.z
    # --- 5. allègement si trop de triangles (Roblox : 20 000 max par mesh) ---
    tri = sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objs.values())
    if tri > 19000:
        for o in objs.values():
            d = o.modifiers.new('Dec', 'DECIMATE'); d.ratio = 18000/tri
            bpy.context.view_layer.objects.active = o; bpy.ops.object.modifier_apply(modifier='Dec')
    if not TEX:
        for o in objs.values():
            for p in o.data.polygons: p.use_smooth = False
        # fusion des sommets en double (le modèle source est découpé face par face)
        for o in objs.values():
            bm = bmesh.new(); bm.from_mesh(o.data); bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=.0002); bm.to_mesh(o.data); bm.free()
    else:
        # textures réduites (le HTML embarque les modèles en base64)
        for img in bpy.data.images:
            if img.size[0] > TEX_MAX or img.size[1] > TEX_MAX:
                k = TEX_MAX / max(img.size); img.scale(max(1, int(img.size[0]*k)), max(1, int(img.size[1]*k)))
    # --- 6. export ---
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action='SELECT')
    opts = dict(export_normals=False, export_texcoords=False)
    if TEX:
        opts = dict(export_normals=True, export_texcoords=True, export_jpeg_quality=JPEG_Q)
        fmts = [i.identifier for i in bpy.ops.export_scene.gltf.get_rna_type().properties['export_image_format'].enum_items]
        if 'JPEG' in fmts: opts['export_image_format'] = 'JPEG'
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT_DIR, KEY + '.glb'), export_format='GLB', use_selection=True, export_yup=True, export_apply=True, **opts)
    # coordonnées glTF : x = x, y = z, z = -y
    g = lambda v: [round(v[0], 4), round(v[2], 4), round(-v[1], 4)]
    info = {'key': KEY, 'parts': list(objs.keys()), 'tris': tri, 'muzzle': round(-muzzle_y, 4), 'left': g(left), 'right': [0, 0, 0], 'sight': round(sight, 4),
            'min': g(Vector((mn.x, mn.y, mn.z))), 'max': g(Vector((mx.x, mx.y, mx.z))), 'len': round(mx.y - mn.y, 4)}
    with open(os.path.join(OUT_DIR, KEY + '.json'), 'w') as f: json.dump(info, f)
    return info
