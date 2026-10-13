import sys, importlib, bpy, json
sys.path.insert(0, r'D:\Office365_data\NLAVOINE\Onedrive\OneDrive - GROUPEMENT Mousquetaires\Bureau\Claude\tools\blender')
import prep_weapon, common; importlib.reload(prep_weapon); importlib.reload(common)
ROOT = r'D:\Office365_data\NLAVOINE\Onedrive\OneDrive - GROUPEMENT Mousquetaires\Bureau\Claude'
info = prep_weapon.run(KEY, REAL_LEN, ROOT + r'\models\weapons', FLIP=globals().get('FLIP', False), GRIP_OVERRIDE=globals().get('GRIP', None), CAT=globals().get('CAT','rifle'), INVERT=globals().get('INVERT', False))
# repères de contrôle : rouge = main droite (origine), vert = main gauche, bleu = ligne de visée
mk = []
for name, pos, col in (('mk_r', (0, 0, 0), (1, 0, 0)), ('mk_l', (info['left'][0], -info['left'][2], info['left'][1]), (0, 1, 0)), ('mk_s', (0, -info['muzzle'] - .06, info['sight']), (0, .4, 1))):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=.012, location=pos); o = bpy.context.active_object; o.name = name
    m = bpy.data.materials.new(name); m.use_nodes = True; e = m.node_tree.nodes['Principled BSDF']; e.inputs['Emission Color'].default_value = (*col, 1); e.inputs['Emission Strength'].default_value = 8; o.data.materials.append(m); mk.append(o)
from mathutils import Vector
VV=[o.matrix_world @ Vector(c) for o in bpy.context.scene.objects if o.type=='MESH' and not o.name.startswith('mk_') for c in o.bound_box]
mn=Vector([min(v[i] for v in VV) for i in range(3)]);mx=Vector([max(v[i] for v in VV) for i in range(3)]);cen=(mn+mx)/2
L = max(info['len'], (mx.z-mn.z)*2)
common.render_preview(r'C:\Users\NLAVOINE\AppData\Local\Temp\claude\D--Office365-data-NLAVOINE-Onedrive-OneDrive---GROUPEMENT-Mousquetaires-Bureau-Claude\aa5d23a3-229f-4b14-ba35-89579344992a\scratchpad\prev_' + KEY + '.png',
    objs_center=tuple(cen), dist=L*1.9, res=(1000, 500), views=('side',))
for o in mk: bpy.data.objects.remove(o, do_unlink=True)
print(json.dumps(info))
