import sys, importlib, bpy, json, os
sys.path.insert(0, r'D:\Office365_data\NLAVOINE\Onedrive\OneDrive - GROUPEMENT Mousquetaires\Bureau\Claude\tools\blender')
import prep_weapon, common; importlib.reload(prep_weapon); importlib.reload(common)
ROOT = r'D:\Office365_data\NLAVOINE\Onedrive\OneDrive - GROUPEMENT Mousquetaires\Bureau\Claude'
OUT = ROOT + r'\models\weapons_real'
# Série « réaliste » : comme run_prep.py mais textures conservées (TEX=True) et sortie dans models/weapons_real
# DROP : noms (sous-chaînes, minuscules) d'objets à supprimer avant préparation (chargeur de rechange, balle posée à côté…)
for o in list(bpy.context.scene.objects):
    if o.type == 'MESH' and any(d in o.name.lower() for d in globals().get('DROP', ())):
        bpy.data.objects.remove(o, do_unlink=True)
info = prep_weapon.run(KEY, REAL_LEN, OUT, FLIP=globals().get('FLIP', False), GRIP_OVERRIDE=globals().get('GRIP', None), CAT=globals().get('CAT', 'rifle'), INVERT=globals().get('INVERT', False), TEX=True, TEX_MAX=globals().get('TEX_MAX', 1024))
info['bytes'] = os.path.getsize(os.path.join(OUT, KEY + '.glb'))
# repères de contrôle : rouge = main droite (origine), vert = main gauche, bleu = ligne de visée
mk = []
for name, pos, col in (('mk_r', (0, 0, 0), (1, 0, 0)), ('mk_l', (info['left'][0], -info['left'][2], info['left'][1]), (0, 1, 0)), ('mk_s', (0, -info['muzzle'] - .06, info['sight']), (0, .4, 1))):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=.012, location=pos); o = bpy.context.active_object; o.name = name
    m = bpy.data.materials.new(name); m.use_nodes = True; e = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'); e.inputs['Emission Color'].default_value = (*col, 1); e.inputs['Emission Strength'].default_value = 8; o.data.materials.append(m); mk.append(o)
from mathutils import Vector
VV = [o.matrix_world @ Vector(c) for o in bpy.context.scene.objects if o.type == 'MESH' and not o.name.startswith('mk_') for c in o.bound_box]
mn = Vector([min(v[i] for v in VV) for i in range(3)]); mx = Vector([max(v[i] for v in VV) for i in range(3)]); cen = (mn+mx)/2
L = max(info['len'], (mx.z-mn.z)*2)
os.makedirs(os.path.join(OUT, 'apercu'), exist_ok=True)
common.render_preview(os.path.join(OUT, 'apercu', KEY + '.png'), objs_center=tuple(cen), dist=L*2.6, res=(1000, 500), views=('side', 'three'), light=globals().get('LIGHT', 1.0))
for o in mk: bpy.data.objects.remove(o, do_unlink=True)
print(json.dumps(info))
