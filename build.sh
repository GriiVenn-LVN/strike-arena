#!/bin/bash
cd "$(dirname "$0")"
mkdir -p build && perl tools/embed_models.pl > build/models_data.js
# liste des fichiers : build.order + fichiers de src/ non listés (insérés avant src/90_main.js)
listed=$(grep -v '^#' build.order | grep -v '^$')
extra=$(ls src/*.js src/*.html 2>/dev/null | LC_ALL=C sort | while read f; do grep -qxF "$f" <<< "$listed" || echo "$f"; done)
files=$(while read f; do [ "$f" = src/90_main.js ] && [ -n "$extra" ] && echo "$extra"; echo "$f"; done <<< "$listed")
cat $files > strike-arena-v2.html
for f in strike-arena.html index.html; do for t in 1 2 3 4 5; do cp strike-arena-v2.html $f 2>/dev/null && break; sleep 1; done; done
echo "built $(wc -l < strike-arena-v2.html) lines"
