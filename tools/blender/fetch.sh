#!/bin/bash
# Usage : tools/blender/fetch.sh <clé> <uid_sketchfab> <longueur_réelle_m> [FLIP=1] [GRIP="(0,y,z)"]
cd "$(dirname "$0")/../.."
KEY=$1; UID_=$2; LEN=$3; EXTRA=$4
perl tools/bl.pl -c "import bpy
for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)
for m in list(bpy.data.meshes): bpy.data.meshes.remove(m)
for m in list(bpy.data.materials):
    if not m.users: bpy.data.materials.remove(m)
print('vide')" > /dev/null
R=$(perl tools/bl.pl -t download_sketchfab_model "{\"uid\":\"$UID_\"}")
echo "$R" | grep -q '"success": true' || { echo "ECHEC TELECHARGEMENT $KEY : $(echo "$R" | head -c 300)"; exit 1; }
{ echo "KEY=\"$KEY\""; echo "REAL_LEN=$LEN"; [ -n "$EXTRA" ] && echo "$EXTRA"; cat tools/blender/run_prep.py; } > /tmp/job_$KEY.py
perl tools/bl.pl /tmp/job_$KEY.py | tail -c 600
