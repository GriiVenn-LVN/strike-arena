# Nettoie le zombie Quaternius (domaine public) : garde les animations utiles, hauteur 1,8 m, texture 512 px
import bpy, os
ROOT = r'D:\Office365_data\NLAVOINE\Onedrive\OneDrive - GROUPEMENT Mousquetaires\Bureau\Claude'
for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)
for a in list(bpy.data.actions): bpy.data.actions.remove(a)
bpy.ops.import_scene.gltf(filepath=ROOT + r'\models\characters\zombie.glb')
KEEP = {'Walk', 'Run', 'Run_Attack', 'Punch', 'Death', 'HitReact', 'Crawl', 'Idle'}
for a in list(bpy.data.actions):
    if a.name not in KEEP: bpy.data.actions.remove(a)
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
meshes = [o for o in bpy.data.objects if o.type == 'MESH']
# hauteur
from mathutils import Vector
bpy.context.view_layer.update()
zs = [(o.matrix_world @ Vector(c)).z for o in meshes for c in o.bound_box]
h = max(zs) - min(zs)
s = 1.8 / h
arm.scale = [x * s for x in arm.scale]
bpy.ops.object.select_all(action='DESELECT'); arm.select_set(True); bpy.context.view_layer.objects.active = arm
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
for img in bpy.data.images:
    if img.size[0] > 512: img.scale(512, 512)
# chaque action dans une piste NLA pour l'export
if arm.animation_data is None: arm.animation_data_create()
out = ROOT + r'\models\characters\zombie_game.glb'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', use_selection=True, export_animations=True, export_animation_mode='ACTIONS',
                          export_image_format='JPEG', export_jpeg_quality=80, export_apply=False)
print('hauteur', round(h, 3), 'echelle', round(s, 4), 'actions', [a.name for a in bpy.data.actions], os.path.getsize(out))
