import bpy
from mathutils import Vector
out=[]
for o in bpy.data.objects:
    if o.type=='MESH':
        bb=[o.matrix_world @ Vector(c) for c in o.bound_box]
        mn=[min(v[i] for v in bb) for i in range(3)]; mx=[max(v[i] for v in bb) for i in range(3)]
        out.append('%s v=%d mats=%s parent=%s min=%s max=%s' % (o.name,len(o.data.vertices),[m.name for m in o.data.materials if m],o.parent.name if o.parent else None,[round(x,1) for x in mn],[round(x,1) for x in mx]))
    else:
        out.append('%s type=%s parent=%s' % (o.name,o.type,o.parent.name if o.parent else None))
arm=[o for o in bpy.data.objects if o.type=='ARMATURE']
for a in arm: out.append('BONES '+', '.join(b.name for b in a.data.bones))
for m in bpy.data.materials:
    if m.users:
        p=m.node_tree.nodes.get('Principled BSDF') if m.use_nodes else None
        out.append('MAT %s col=%s tex=%s' % (m.name, tuple(round(c,2) for c in p.inputs['Base Color'].default_value[:3]) if p else None, [n.image.name for n in m.node_tree.nodes if n.type=='TEX_IMAGE' and n.image] if m.use_nodes else []))
print('\n'.join(out))
