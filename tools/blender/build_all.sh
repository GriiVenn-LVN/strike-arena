#!/bin/bash
# Retélécharge et prépare toutes les armes listées dans weapons_list.txt
# Format : clé uid longueur catégorie [poignée (0,y,z)] [INVERT]
cd "$(dirname "$0")/../.."
while read -r k u l c g inv; do
  [ -z "$k" ] && continue
  extra="CAT='$c'"
  if [ -n "$g" ] && [ "$g" != "INVERT" ]; then extra="$extra
GRIP=$g"; fi
  if [ "$g" = "INVERT" ] || [ "$inv" = "INVERT" ]; then extra="$extra
INVERT=True"; fi
  printf '%-10s ' "$k"
  timeout 400 bash tools/blender/fetch.sh "$k" "$u" "$l" "$extra" | grep -o '"tris": [0-9]*' || echo ECHEC
done < tools/blender/weapons_list.txt
