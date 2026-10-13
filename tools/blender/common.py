# Outils communs pour modéliser les armes (unités : mètres ; canon vers +Y, haut = +Z)
import bpy, bmesh, math
from mathutils import Vector

def clear_scene():
    for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)
    for m in list(bpy.data.meshes): bpy.data.meshes.remove(m)
    for c in list(bpy.data.collections): bpy.data.collections.remove(c)

def coll(name):
    c = bpy.data.collections.get(name) or bpy.data.collections.new(name)
    if c.name not in bpy.context.scene.collection.children: bpy.context.scene.collection.children.link(c)
    return c

def _obj(name, bm, mat, col, bevel=0.0012, seg=2, smooth=True):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); (col or bpy.context.scene.collection).objects.link(o)
    if mat: me.materials.append(mat)
    if bevel > 0:
        b = o.modifiers.new('Bevel', 'BEVEL'); b.width = bevel; b.segments = seg; b.limit_method = 'ANGLE'; b.angle_limit = math.radians(35); b.harden_normals = True
    if smooth:
        for p in me.polygons: p.use_smooth = True
        o.modifiers.new('WN', 'WEIGHTED_NORMAL').keep_sharp = True
    return o

def box(name, sx, sy, sz, x, y, z, mat, col=None, bevel=0.0012):
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts: v.co = Vector((v.co.x*sx + x, v.co.y*sy + y, v.co.z*sz + z))
    return _obj(name, bm, mat, col, bevel)

def cyl(name, r1, r2, length, x, y, z, mat, col=None, axis='Y', seg=24, bevel=0.0008, cap=True):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=cap, cap_tris=False, segments=seg, radius1=r1, radius2=r2, depth=length)
    # le cône est sur Z : on l'oriente
    for v in bm.verts:
        cx, cy, cz = v.co
        if axis == 'Y': v.co = Vector((cx, cz, -cy))
        elif axis == 'X': v.co = Vector((cz, cy, cx))
        v.co += Vector((x, y, z))
    return _obj(name, bm, mat, col, bevel)

def tube(name, r_out, r_in, length, x, y, z, mat, col=None, seg=28):
    bm = bmesh.new()
    for rr in (r_out, r_in):
        pass
    # tube = anneau extrudé
    ring_o = [Vector((math.cos(i/seg*math.tau)*r_out, 0, math.sin(i/seg*math.tau)*r_out)) for i in range(seg)]
    ring_i = [Vector((math.cos(i/seg*math.tau)*r_in, 0, math.sin(i/seg*math.tau)*r_in)) for i in range(seg)]
    vs = []
    for yy in (-length/2, length/2):
        vs.append([bm.verts.new(p + Vector((x, y+yy, z))) for p in ring_o])
        vs.append([bm.verts.new(p + Vector((x, y+yy, z))) for p in ring_i])
    oa, ia, ob, ib = vs
    for i in range(seg):
        j = (i+1) % seg
        bm.faces.new((oa[i], oa[j], ob[j], ob[i]))
        bm.faces.new((ia[j], ia[i], ib[i], ib[j]))
        bm.faces.new((oa[j], oa[i], ia[i], ia[j]))
        bm.faces.new((ob[i], ob[j], ib[j], ib[i]))
    return _obj(name, bm, mat, col, 0.0006)

def prof(name, pts, width, mat, col=None, x=0.0, bevel=0.0018, taper=None):
    """Profil 2D (y,z) extrudé en épaisseur X. taper(y,z)->facteur de largeur optionnel."""
    bm = bmesh.new()
    L, R = [], []
    for (yy, zz) in pts:
        w = width * (taper(yy, zz) if taper else 1.0)
        L.append(bm.verts.new((x - w/2, yy, zz))); R.append(bm.verts.new((x + w/2, yy, zz)))
    n = len(pts)
    bm.faces.new(list(reversed(L))); bm.faces.new(R)
    for i in range(n):
        j = (i+1) % n
        bm.faces.new((L[i], L[j], R[j], R[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _obj(name, bm, mat, col, bevel, seg=3)

def sweep(name, path, w_fn, d_fn, mat, col=None, bevel=0.001):
    """Balaye un rectangle (largeur X = w_fn(t), profondeur dans le plan YZ = d_fn(t)) le long d'une courbe (y,z)."""
    bm = bmesh.new(); rings = []
    n = len(path)
    for i, (yy, zz) in enumerate(path):
        t = i/(n-1)
        a = path[max(0, i-1)]; b = path[min(n-1, i+1)]
        ty, tz = b[0]-a[0], b[1]-a[1]; l = math.hypot(ty, tz) or 1; ty, tz = ty/l, tz/l
        ny, nz = -tz, ty                      # normale dans le plan YZ
        w, d = w_fn(t)/2, d_fn(t)/2
        rings.append([bm.verts.new((sx*w, yy + ny*sd*d, zz + nz*sd*d)) for (sx, sd) in ((-1,-1),(1,-1),(1,1),(-1,1))])
    for i in range(n-1):
        a, b = rings[i], rings[i+1]
        for k in range(4):
            m = (k+1) % 4
            bm.faces.new((a[k], a[m], b[m], b[k]))
    bm.faces.new(list(reversed(rings[0]))); bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _obj(name, bm, mat, col, bevel)

def mat(name, color, metal=0.0, rough=0.5, kind=None):
    m = bpy.data.materials.get(name)
    if m: return m
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; p = nt.nodes['Principled BSDF']
    p.inputs['Base Color'].default_value = (*color, 1); p.inputs['Metallic'].default_value = metal; p.inputs['Roughness'].default_value = rough
    if kind == 'wood':
        tc = nt.nodes.new('ShaderNodeTexCoord'); mp = nt.nodes.new('ShaderNodeMapping'); mp.inputs['Scale'].default_value = (60, 6, 60)
        wv = nt.nodes.new('ShaderNodeTexWave'); wv.wave_type = 'RINGS'; wv.inputs['Scale'].default_value = 1.2; wv.inputs['Distortion'].default_value = 6; wv.inputs['Detail'].default_value = 3
        nz = nt.nodes.new('ShaderNodeTexNoise'); nz.inputs['Scale'].default_value = 40
        cr = nt.nodes.new('ShaderNodeValToRGB'); cr.color_ramp.elements[0].color = (color[0]*.55, color[1]*.5, color[2]*.45, 1); cr.color_ramp.elements[1].color = (*color, 1)
        mix = nt.nodes.new('ShaderNodeMath'); mix.operation = 'MULTIPLY_ADD'; mix.inputs[1].default_value = .8
        nt.links.new(tc.outputs['Object'], mp.inputs['Vector']); nt.links.new(mp.outputs['Vector'], wv.inputs['Vector'])
        nt.links.new(wv.outputs['Fac'], mix.inputs[0]); nt.links.new(nz.outputs['Fac'], mix.inputs[2])
        nt.links.new(mix.outputs[0], cr.inputs['Fac']); nt.links.new(cr.outputs['Color'], p.inputs['Base Color'])
    if kind == 'steel':
        nz = nt.nodes.new('ShaderNodeTexNoise'); nz.inputs['Scale'].default_value = 300; nz.inputs['Detail'].default_value = 8
        rr = nt.nodes.new('ShaderNodeMapRange'); rr.inputs['To Min'].default_value = rough*.7; rr.inputs['To Max'].default_value = rough*1.35
        nt.links.new(nz.outputs['Fac'], rr.inputs['Value']); nt.links.new(rr.outputs['Result'], p.inputs['Roughness'])
    return m

def render_preview(path, objs_center=(0,0.1,0), dist=1.5, res=(1400,700), views=('side',)):
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_EEVEE' if 'BLENDER_EEVEE' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE_NEXT'
    sc.render.resolution_x, sc.render.resolution_y = res; sc.render.film_transparent = False
    w = sc.world or bpy.data.worlds.new('W'); sc.world = w; w.use_nodes = True
    bg = w.node_tree.nodes.get('Background'); bg.inputs['Color'].default_value = (0.035, 0.045, 0.065, 1); bg.inputs['Strength'].default_value = 1.0
    for n, (loc, en, sz) in {'Key': ((1.2, -0.6, 1.0), 160, 1.2), 'Fill': ((-1.2, 0.4, 0.5), 60, 1.5), 'Rim': ((0.2, 1.4, 1.2), 120, 1.0), 'Under': ((0.6, 0.2, -1.0), 25, 1.5)}.items():
        o = bpy.data.objects.get('L_'+n)
        if not o:
            l = bpy.data.lights.new('L_'+n, 'AREA'); o = bpy.data.objects.new('L_'+n, l); sc.collection.objects.link(o)
        o.data.energy = en; o.data.size = sz; o.location = loc
        d = Vector(objs_center) - o.location; o.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    cam = bpy.data.objects.get('CamP')
    if not cam:
        cd = bpy.data.cameras.new('CamP'); cam = bpy.data.objects.new('CamP', cd); sc.collection.objects.link(cam)
    cam.data.lens = 70; sc.camera = cam
    out = []
    for v in views:
        if v == 'side': cam.location = (dist, objs_center[1], objs_center[2]+0.02)
        elif v == 'three': cam.location = (dist*.75, objs_center[1]+dist*.55, objs_center[2]+dist*.3)
        elif v == 'left': cam.location = (-dist, objs_center[1], objs_center[2]+0.02)
        d = Vector(objs_center) - cam.location; cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
        p = path.replace('.png', '_'+v+'.png'); sc.render.filepath = p; bpy.ops.render.render(write_still=True); out.append(p)
    return out
