# Profil bas/haut de l'arme courante, en coordonnées « pré-recentrage » (centre de la boîte = 0)
import bpy
from mathutils import Vector
obs=[o for o in bpy.context.scene.objects if o.type=='MESH' and not o.name.startswith('mk_')]
P=[]
for o in obs:
    vs=o.data.vertices
    for e in o.data.edges:
        a=o.matrix_world@vs[e.vertices[0]].co; b=o.matrix_world@vs[e.vertices[1]].co
        n=max(1,int(abs(b.y-a.y)/.005))
        for k in range(n+1): P.append(a.lerp(b,k/n))
mn=Vector([min(p[i] for p in P) for i in range(3)]); mx=Vector([max(p[i] for p in P) for i in range(3)]); c=(mn+mx)/2
nb=30; L=mx.y-mn.y; rows=[]
for i in range(nb):
    y0=mn.y+L*i/nb; y1=y0+L/nb
    zs=[p.z for p in P if y0<=p.y<y1]
    if zs: rows.append('%5.3f  bas=%6.3f  haut=%6.3f' % ((y0+y1)/2-c.y, min(zs)-c.z, max(zs)-c.z))
print('L=%.3f  (y vers la bouche, z vers le haut, centre de la boite = 0)\n' % L + '\n'.join(rows))
