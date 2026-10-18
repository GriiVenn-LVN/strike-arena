// Exporte les 10 cartes du jeu web (grille de jeu + décor 3D complet) pour la version Roblox.
// Le vrai code du jeu construit chaque carte (buildWorld, navigateur sans fenêtre Playwright), puis tout ce qui est
// visible dans le monde est relevé en coordonnées monde : blocs, sphères, cylindres, maillages (instances développées),
// matériaux (couleur, émission, opacité, rugosité, métal), textures canvas (réduites), lumières et halos.
// Usage (depuis la racine du dépôt, après bash build.sh) :
//   NODE_PATH=$(npm root -g) node tools/export_scene.js <dossier>
//   -> <dossier>/<carte>.json, <dossier>/tex/<id>.png, <dossier>/maps.json
//   puis : python3 tools/scene_to_lua.py <dossier>
const fs = require('fs'), path = require('path');
let chromium;
try { ({ chromium } = require('playwright')); } catch (e) {
  ({ chromium } = require(path.join(require('child_process').execSync('npm root -g').toString().trim(), 'playwright')));
}
const OUT = process.argv[2] || 'scene_out';
const ORDER = ['village', 'warehouse', 'station', 'harbor', 'metro', 'jungle', 'range', 'labo', 'asile', 'manoir'];

(async () => {
  fs.mkdirSync(path.join(OUT, 'tex'), { recursive: true });
  const browser = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const page = await browser.newPage();
  page.on('pageerror', e => console.log('page:', e.message));
  await page.addInitScript(() => { setInterval(() => { const d = document.getElementById('daily'); if (d) d.classList.remove('show'); }, 100); });
  // copie du jeu qui expose ce qu'il faut relever (le code du jeu est dans une fonction : rien n'est global)
  let html = fs.readFileSync(path.join(__dirname, '../strike-arena.html'), 'utf8');
  html = html.replace('window.__dbg={', 'window.__SCN={EVENT,TC,THEMES,G_TYPE,G_H,G_CEIL,G_RAMP,G_TAG,groundKind,GD_REP,get RAMPS(){return RAMPS},get worldG(){return worldG},get skyG(){return skyG}};window.__dbg={');
  const tmp = path.join(__dirname, '../.scene_export.html');
  fs.writeFileSync(tmp, html);
  await page.goto('file://' + tmp);
  await page.waitForFunction(() => window.__dbg && window.__dbg.buildWorld, null, { timeout: 60000 });
  await page.waitForTimeout(2500);
  // préparation : pas de décor d'événement (citrouilles sur toutes les cartes), qualité graphique maximale
  await page.evaluate(() => {
    window.__SCN.EVENT.from = '9999'; window.__SCN.EVENT.to = '0000';
    try { window.__dbg.cfg.gfx = 2; } catch (e) {}
    window.__SX = { texIds: new Map(), texOut: {}, n: 0 };
  });
  const index = [];
  for (const id of ORDER) {
    const r = await page.evaluate((id) => {
      const D = window.__dbg, SX = window.__SX, T = THREE, Z = window.__SCN;
      const { TC, THEMES, G_TYPE, G_H, G_CEIL, G_RAMP, G_TAG, groundKind, GD_REP, MAPS } = Object.assign({}, Z, { MAPS: D.MAPS });
      D.buildWorld(id);
      const worldG = Z.worldG, skyG = Z.skyG, RAMPS = Z.RAMPS, MAP = D.MAP;
      const R6 = v => Math.round(v * 1e4) / 1e4;
      const srgb = c => { const k = c.clone().convertLinearToSRGB(); return [R6(k.r), R6(k.g), R6(k.b)]; };
      // ---------- textures (partagées entre cartes, réduites dans le navigateur) ----------
      const keyOf = new Map(); for (const k in TC) { const v = TC[k]; if (v && v.isTexture) keyOf.set(v, k); else if (v && v.map) keyOf.set(v.map, k); }
      const texRef = (tex, maxSide) => {
        if (!tex || !tex.image) return null;
        const im = tex.image, w0 = im.width, h0 = im.height; if (!w0 || !h0) return null;
        const ms = maxSide || (Math.max(w0, h0) >= 1024 ? 512 : 128);
        const ck = tex.uuid + '@' + ms;
        if (SX.texIds.has(ck)) return SX.texIds.get(ck);
        const k = Math.min(1, ms / Math.max(w0, h0)), w = Math.max(4, Math.round(w0 * k)), h = Math.max(4, Math.round(h0 * k));
        const c = document.createElement('canvas'); c.width = w; c.height = h; const x = c.getContext('2d');
        x.imageSmoothingEnabled = true; x.imageSmoothingQuality = 'high';
        try { x.drawImage(im, 0, 0, w, h); } catch (e) { return null; }
        const data = c.toDataURL('image/png');
        let hsh = 0; for (let i = 0; i < data.length; i += 7) hsh = (hsh * 31 + data.charCodeAt(i)) | 0;
        const tid = 't' + (hsh >>> 0).toString(36) + '_' + w + 'x' + h;
        const kind = (keyOf.get(tex) || '').replace(/[0-9.,#].*$/, '') || 'misc';
        if (!SX.texOut[tid]) SX.texOut[tid] = { png: data, w, h, kind, srgb: tex.encoding === T.sRGBEncoding };
        SX.texIds.set(ck, tid); return tid;
      };
      // ---------- matériaux ----------
      const mats = [], matIdx = new Map();
      const matRef = (m) => {
        if (matIdx.has(m)) return matIdx.get(m);
        const o = { t: m.type.replace('Mesh', '').replace('Material', ''), c: m.color ? srgb(m.color) : [1, 1, 1], o: R6(m.opacity), tr: !!m.transparent, at: R6(m.alphaTest || 0),
          ds: m.side === T.DoubleSide, bs: m.side === T.BackSide, r: R6(m.roughness !== undefined ? m.roughness : 1), mt: R6(m.metalness || 0), vc: !!m.vertexColors, fs: !!m.flatShading };
        if (m.emissive && (m.emissive.r + m.emissive.g + m.emissive.b) > 0.001) { o.e = srgb(m.emissive); o.ei = R6(m.emissiveIntensity !== undefined ? m.emissiveIntensity : 1); }
        if (m.blending === T.AdditiveBlending) o.add = true;
        if (m.map) {
          o.map = texRef(m.map); if (o.map) { o.kind = SX.texOut[o.map].kind; o.rep = [R6(m.map.repeat.x), R6(m.map.repeat.y)]; o.off = [R6(m.map.offset.x), R6(m.map.offset.y)]; o.rot = R6(m.map.rotation || 0); }
        }
        if (m.alphaMap) o.amap = texRef(m.alphaMap);
        if (m.customProgramCacheKey && m.customProgramCacheKey() === 'gdet') {   // sol : texture de détail répétée tous les GD_REP m (40c_ground.js)
          const kind = groundKind(THEMES[MAP.theme]), dt = TC['gdet' + kind];
          if (dt) o.det = { map: texRef(dt, 256), rep: GD_REP, str: kind === 'sand' || kind === 'jungle' ? 1.7 : (kind === 'snow' ? .55 * .6 : kind === 'concrete' ? .8 : 1) };
        }
        mats.push(o); const i = mats.length - 1; matIdx.set(m, i); return i;
      };
      // ---------- géométries (maillages non primitifs) ----------
      const geos = [], geoIdx = new Map();
      const geoRef = (g) => {
        if (geoIdx.has(g)) return geoIdx.get(g);
        const a = g.attributes, P = a.position, rd = (attr, n) => { const out = new Array(attr.count * n); for (let i = 0; i < attr.count; i++) for (let k = 0; k < n; k++) out[i * n + k] = R6(attr.getComponent ? attr.getComponent(i, k) : attr.array[i * attr.itemSize + k]); return out; };
        const o = { kind: g.type, nv: P.count, pos: rd(P, 3) };
        if (a.normal) o.nrm = rd(a.normal, 3);
        if (a.uv) o.uv = rd(a.uv, 2);
        if (a.color) { const cl = new T.Color(), out = []; for (let i = 0; i < a.color.count; i++) { cl.setRGB(a.color.getX(i), a.color.getY(i), a.color.getZ(i)); const s = srgb(cl); out.push(s[0], s[1], s[2]); } o.col = out; }
        o.idx = g.index ? Array.from(g.index.array) : null;
        o.groups = (g.groups && g.groups.length) ? g.groups.map(gr => [gr.start, gr.count, gr.materialIndex || 0]) : null;
        geos.push(o); const i = geos.length - 1; geoIdx.set(g, i); return i;
      };
      // ---------- classement : bloc / boule / cylindre / maillage ----------
      const boxes = [], balls = [], cyls = [], meshes = [], lights = [], glows = [];
      const p = new T.Vector3(), q = new T.Quaternion(), s = new T.Vector3(), M2 = new T.Matrix4();
      const ortho = (M) => { M.decompose(p, q, s); M2.compose(p, q, s); const a = M.elements, b = M2.elements; let d = 0, sc = 1e-3 + Math.max(Math.abs(s.x), Math.abs(s.y), Math.abs(s.z)); for (let i = 0; i < 16; i++) d = Math.max(d, Math.abs(a[i] - b[i])); return d < 1e-4 * sc; };
      const bboxAxis = (g) => {   // vrai si chaque sommet est sur une face de sa boîte englobante (géométrie alignée sur les axes)
        g.computeBoundingBox(); const bb = g.boundingBox, P = g.attributes.position, e = 1e-4;
        for (let i = 0; i < P.count; i++) { const x = P.getX(i), y = P.getY(i), z = P.getZ(i);
          if ((Math.abs(x - bb.min.x) > e && Math.abs(x - bb.max.x) > e) || (Math.abs(y - bb.min.y) > e && Math.abs(y - bb.max.y) > e) || (Math.abs(z - bb.min.z) > e && Math.abs(z - bb.max.z) > e)) return null; }
        return bb;
      };
      const TAU2 = Math.PI * 2 - 1e-3;
      const matsOf = (o) => Array.isArray(o.material) ? o.material : [o.material];
      const visibleChain = (o) => { for (let x = o; x; x = x.parent) if (!x.visible) return false; return true; };
      const addMesh = (o, M, col) => {
        const g = o.geometry, pr = g.parameters || {}, ml = matsOf(o);
        if (ml.some(m => !m || m.isShaderMaterial || m.isPointsMaterial || m.isLineBasicMaterial)) return;
        if (ml.every(m => m.visible === false || m.colorWrite === false)) return;
        const mi = ml.map(matRef);
        const isO = ortho(M);
        M.decompose(p, q, s);
        const P3 = [R6(p.x), R6(p.y), R6(p.z)], Q4 = [R6(q.x), R6(q.y), R6(q.z), R6(q.w)];
        const c = col ? srgb(col) : null;
        // matériau d'une face de boîte (groupes de BoxGeometry : +x -x +y -y +z -z)
        if (isO && (g.type === 'BoxGeometry' || (g.type === 'PlaneGeometry' && g.attributes.position.count === 4))) {
          const bb = bboxAxis(g);
          if (bb) {
            const ctr = new T.Vector3(), sz = new T.Vector3(); bb.getCenter(ctr); bb.getSize(sz);
            const wc = ctr.clone().applyMatrix4(M);
            let faces;
            if (g.type === 'BoxGeometry') {
              faces = [0, 0, 0, 0, 0, 0];
              if (g.groups && g.groups.length) g.groups.forEach((gr, k) => { if (k < 6) faces[k] = mi[Math.min(mi.length - 1, gr.materialIndex || 0)]; });
              else faces = faces.map(() => mi[0]);
              if (s.x < 0) faces = [faces[1], faces[0], faces[2], faces[3], faces[4], faces[5]];
            } else {   // plan : boîte fine, la face texturée est celle de sa normale (les deux si double face)
              const n = g.attributes.normal ? new T.Vector3(g.attributes.normal.getX(0), g.attributes.normal.getY(0), g.attributes.normal.getZ(0)) : new T.Vector3(0, 0, 1);
              const ax = sz.x < 1e-5 ? 0 : sz.y < 1e-5 ? 1 : 2; const sgn = ([n.x, n.y, n.z][ax] * [s.x, s.y, s.z][ax]) >= 0 ? 0 : 1;
              faces = [-1, -1, -1, -1, -1, -1]; faces[ax * 2 + sgn] = mi[0]; if (ml[0].side !== T.FrontSide) faces[ax * 2 + 1 - sgn] = mi[0];
              if (ml[0].side === T.BackSide) faces[ax * 2 + sgn] = -1;
              sz.setComponent(ax, 0);
            }
            const S3 = [R6(Math.max(Math.abs(sz.x * s.x), .002)), R6(Math.max(Math.abs(sz.y * s.y), .002)), R6(Math.max(Math.abs(sz.z * s.z), .002))];
            boxes.push({ p: [R6(wc.x), R6(wc.y), R6(wc.z)], q: Q4, s: S3, f: faces, c, pl: g.type === 'PlaneGeometry' ? 1 : 0, sh: o.castShadow ? 1 : 0 });
            return;
          }
        }
        if (isO && g.type === 'SphereGeometry' && (pr.phiLength || TAU2 + 1) >= TAU2 && (pr.thetaLength || 4) >= Math.PI - 1e-3 && !(pr.thetaStart > 1e-3) && mi.length === 1) {
          g.computeBoundingBox(); const ctr = new T.Vector3(); g.boundingBox.getCenter(ctr); ctr.applyMatrix4(M);
          balls.push({ p: [R6(ctr.x), R6(ctr.y), R6(ctr.z)], q: Q4, s: [R6(Math.abs(2 * pr.radius * s.x)), R6(Math.abs(2 * pr.radius * s.y)), R6(Math.abs(2 * pr.radius * s.z))], m: mi[0], c, sh: o.castShadow ? 1 : 0 });
          return;
        }
        if (isO && g.type === 'CylinderGeometry' && Math.abs(pr.radiusTop - pr.radiusBottom) <= .03 * Math.max(pr.radiusTop, pr.radiusBottom) && !pr.openEnded && (pr.thetaLength || 7) >= TAU2 && Math.abs(Math.abs(s.x) - Math.abs(s.z)) <= .03 * Math.abs(s.x) && pr.radialSegments >= 8) {
          g.computeBoundingBox(); const ctr = new T.Vector3(); g.boundingBox.getCenter(ctr); ctr.applyMatrix4(M);
          const rr = (pr.radiusTop + pr.radiusBottom) / 2;
          cyls.push({ p: [R6(ctr.x), R6(ctr.y), R6(ctr.z)], q: Q4, h: R6(Math.abs(pr.height * s.y)), d: R6(Math.abs(2 * rr * s.x)), m: mi[0], mc: mi.length > 1 ? mi[1] : mi[0], c, sh: o.castShadow ? 1 : 0 });
          return;
        }
        const e = M.elements;
        meshes.push({ g: geoRef(g), m: mi, M: [e[0], e[1], e[2], e[4], e[5], e[6], e[8], e[9], e[10], e[12], e[13], e[14]].map(R6), c, sh: o.castShadow ? 1 : 0 });
      };
      worldG.updateMatrixWorld(true);
      const mt = new T.Matrix4(), cl = new T.Color();
      worldG.traverse(o => {
        if (!visibleChain(o)) return;
        if (o.isInstancedMesh) {
          for (let i = 0; i < o.count; i++) { o.getMatrixAt(i, mt); const M = new T.Matrix4().multiplyMatrices(o.matrixWorld, mt); let c = null; if (o.instanceColor) { o.getColorAt(i, cl); c = cl.clone(); } addMesh(o, M, c); }
        } else if (o.isMesh) addMesh(o, o.matrixWorld.clone(), null);
        else if (o.isLine && !o.isLineSegments) {   // fils (guirlandes) : petits segments
          const P = o.geometry.attributes.position, a = new T.Vector3(), b = new T.Vector3(), c = o.material.color ? srgb(o.material.color) : [0, 0, 0];
          for (let i = 0; i + 1 < P.count; i++) { a.fromBufferAttribute(P, i).applyMatrix4(o.matrixWorld); b.fromBufferAttribute(P, i + 1).applyMatrix4(o.matrixWorld);
            glows.push({ line: 1, a: [R6(a.x), R6(a.y), R6(a.z)], b: [R6(b.x), R6(b.y), R6(b.z)], c }); }
        } else if (o.isSprite) {
          const wp = new T.Vector3(), ws = new T.Vector3(); o.getWorldPosition(wp); o.getWorldScale(ws);
          let c = o.material.color ? srgb(o.material.color) : [1, 1, 1];
          const im = o.material.map && o.material.map.image;
          if (im && im.getContext) { const d = im.getContext('2d').getImageData(Math.floor(im.width / 2), Math.floor(im.height / 2), 1, 1).data; c = [R6(c[0] * d[0] / 255), R6(c[1] * d[1] / 255), R6(c[2] * d[2] / 255)]; }
          glows.push({ p: [R6(wp.x), R6(wp.y), R6(wp.z)], s: R6(Math.max(ws.x, ws.y)), c, o: R6(o.material.opacity), add: o.material.blending === T.AdditiveBlending ? 1 : 0 });
        } else if (o.isPointLight || o.isSpotLight) {
          const wp = new T.Vector3(); o.getWorldPosition(wp);
          lights.push({ k: o.isSpotLight ? 'spot' : 'point', p: [R6(wp.x), R6(wp.y), R6(wp.z)], c: srgb(o.color), i: R6(o.intensity), d: R6(o.distance || 0) });
        }
      });
      // ---------- données de jeu (grille exacte du web, points corrigés par l'audit) ----------
      const m = MAPS[id], meta = {};
      for (const k in m) { const v = m[k]; if (typeof v === 'function' || k === 'base' || k.startsWith('_')) continue; meta[k] = JSON.parse(JSON.stringify(v)); }
      meta.base = MAP.base;
      const grid = { type: Array.from(G_TYPE), h: Array.from(G_H).map(R6), ceil: Array.from(G_CEIL).map(R6), ramp: Array.from(G_RAMP), tag: Array.from(G_TAG), ramps: RAMPS.map(r => Object.assign({}, r)) };
      const th = THEMES[m.theme], theme = {};
      for (const k in th) { const v = th[k]; if (typeof v !== 'function') theme[k] = JSON.parse(JSON.stringify(v)); }
      // couleurs hexadécimales du thème -> [r,g,b] 0..1
      for (const k of ['fog', 'hemiS', 'hemiG', 'sunC', 'tint']) if (typeof th[k] === 'number') { const cc2 = new T.Color(th[k]); theme[k] = [R6(cc2.r), R6(cc2.g), R6(cc2.b)]; }
      theme.stars = 0; if (typeof skyG !== 'undefined' && skyG) skyG.traverse(o => { if (o.isPoints) theme.stars += o.geometry.attributes.position.count; });
      const nv = meshes.reduce((a, x) => a + geos[x.g].nv, 0);
      return { id, meta, grid, theme, mats, geos, boxes, balls, cyls, meshes, lights, glows, stats: { boxes: boxes.length, balls: balls.length, cyls: cyls.length, meshes: meshes.length, geos: geos.length, meshVerts: nv, mats: mats.length, lights: lights.length, glows: glows.length } };
    }, id);
    fs.writeFileSync(path.join(OUT, id + '.json'), JSON.stringify(r));
    console.log(id, JSON.stringify(r.stats));
    index.push({ id, name: r.meta.n, desc: r.meta.desc || '', theme: r.meta.theme });
  }
  const tex = await page.evaluate(() => { const o = window.__SX.texOut; window.__SX.texOut = {}; return o; });
  for (const tid in tex) {
    const t = tex[tid];
    fs.writeFileSync(path.join(OUT, 'tex', tid + '.png'), Buffer.from(t.png.split(',')[1], 'base64'));
    delete t.png;
  }
  fs.writeFileSync(path.join(OUT, 'textures.json'), JSON.stringify(tex));
  fs.writeFileSync(path.join(OUT, 'maps.json'), JSON.stringify(index, null, 1));
  console.log(Object.keys(tex).length + ' textures');
  fs.unlinkSync(tmp);
  await browser.close();
})();
