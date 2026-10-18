#!/usr/bin/env node
/*
 Soldats du jeu web -> données brutes pour Roblox (étape 1/2).
 Ouvre strike-arena.html dans Chromium (Playwright), fabrique les soldats exactement comme le jeu
 (makeSoldier : soldat réaliste T / CT / chacun-pour-soi + équipement, et les 13 tenues procédurales),
 puis écrit leur géométrie au repos, découpée par membre R15, dans un fichier JSON.
 L'étape 2 (tools/soldiers/soldiers_to_lua.py) en fait les modules Luau de roblox/ReplicatedStorage/Shared/SoldierMeshes.

 Usage (depuis la racine du dépôt) : node tools/soldiers/export_soldiers_web.js [sortie.json]
 Playwright et Chromium doivent être installés (npm i -g playwright ; NODE_PATH=$(npm root -g) si besoin).
*/
const fs = require('fs'), os = require('os'), path = require('path');
let chromium;
try { ({ chromium } = require('playwright')); } catch (e) {
  const g = require('child_process').execSync('npm root -g').toString().trim();
  ({ chromium } = require(path.join(g, 'playwright')));
}
const ROOT = path.join(__dirname, '..', '..');
const OUT = process.argv[2] || path.join(os.tmpdir(), 'soldiers_web.json');

// le jeu est enfermé dans une fonction : on expose ce qu'il faut dans une copie temporaire de la page
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'soldats-'));
let html = fs.readFileSync(path.join(ROOT, 'strike-arena.html'), 'utf8');
const tail = '\n}\n})();\n</script>', at = html.lastIndexOf(tail);
if (at < 0) throw new Error('fin de main() introuvable dans strike-arena.html');
html = html.slice(0, at) + '\nwindow.__sx={makeSoldier,lookMats,PALETTE,SKIN_TONES,OUTFITS,THREE};\n' + html.slice(at);
fs.writeFileSync(path.join(tmp, 'sa.html'), html);
fs.copyFileSync(path.join(ROOT, 'three.min.js'), path.join(tmp, 'three.min.js'));

// code exécuté dans la page
function grab() {
  const { makeSoldier, lookMats, PALETTE, SKIN_TONES, OUTFITS, THREE } = window.__sx;
  const V = () => new THREE.Vector3();
  const arr = v => [+v.x.toFixed(5), +v.y.toFixed(5), +v.z.toFixed(5)];
  const avgCache = new Map();
  // couleur moyenne d'une texture (les tissus camouflés deviennent une teinte unie)
  function avgTex(t) {
    if (!t || !t.image) return [1, 1, 1];
    if (avgCache.has(t.image)) return avgCache.get(t.image);
    const c = document.createElement('canvas'); c.width = c.height = 32;
    const g = c.getContext('2d'); g.drawImage(t.image, 0, 0, 32, 32);
    const d = g.getImageData(0, 0, 32, 32).data; let r = 0, gg = 0, b = 0;
    for (let i = 0; i < d.length; i += 4) { r += d[i]; gg += d[i + 1]; b += d[i + 2]; }
    const n = d.length / 4, out = [r / n / 255, gg / n / 255, b / n / 255];
    avgCache.set(t.image, out); return out;
  }
  // couleur affichée : matériau en linéaire (C() du jeu convertit), textures en sRGB -> résultat en sRGB
  const lin = x => x <= .04045 ? x / 12.92 : Math.pow((x + .055) / 1.055, 2.4), srgb = x => x <= .0031308 ? x * 12.92 : 1.055 * Math.pow(x, 1 / 2.4) - .055;
  const rgb = m => { const a = avgTex(m.map), t = m.map ? a.map(lin) : [1, 1, 1]; return [m.color.r * t[0], m.color.g * t[1], m.color.b * t[2]].map(x => Math.round(srgb(Math.min(1, x)) * 255)); };
  const cls = m => (m.transparent && m.opacity < .6) ? 'glass' : (m.emissiveIntensity > 1 && m.emissive && (m.emissive.r + m.emissive.g + m.emissive.b) > .3) ? 'neon' : (m.metalness > .6 ? 'metal' : 'base');
  // géométrie d'un maillage, transformée par la matrice M puis décalée de -piv
  function geo(mesh, M, piv) {
    const g = mesh.geometry, P = g.attributes.position, N = g.attributes.normal, U = g.attributes.uv;
    const nm = new THREE.Matrix3().getNormalMatrix(M), v = V(), n = V();
    const pos = [], nrm = [], uv = [];
    for (let i = 0; i < P.count; i++) {
      v.fromBufferAttribute(P, i).applyMatrix4(M).sub(piv); pos.push(+v.x.toFixed(5), +v.y.toFixed(5), +v.z.toFixed(5));
      if (N) { n.fromBufferAttribute(N, i).applyMatrix3(nm).normalize(); nrm.push(+n.x.toFixed(3), +n.y.toFixed(3), +n.z.toFixed(3)); } else nrm.push(0, 1, 0);
      if (U) uv.push(+U.getX(i).toFixed(5), +U.getY(i).toFixed(5)); else uv.push(0, 0);
    }
    const idx = g.index ? Array.from(g.index.array) : Array.from({ length: P.count }, (_, i) => i);
    // un maillage à échelle négative retourne ses faces
    if (M.determinant() < 0) for (let i = 0; i < idx.length; i += 3) { const t = idx[i + 1]; idx[i + 1] = idx[i + 2]; idx[i + 2] = t; }
    return { pos, nrm, uv, idx };
  }
  const wpos = o => o.getWorldPosition(V());
  const comp = (A, i, j) => j === 0 ? A.getX(i) : j === 1 ? A.getY(i) : j === 2 ? A.getZ(i) : A.getW(i);
  // groupe procédural -> membre R15 (le cou suit la tête)
  function groups(R) {
    return [[R.hips, 'LowerTorso'], [R.spine, 'UpperTorso'], [R.neckG, 'Head'], [R.head, 'Head'],
      [R.legL.th, 'LeftUpperLeg'], [R.legL.sh, 'LeftLowerLeg'], [R.legL.foot, 'LeftFoot'],
      [R.legR.th, 'RightUpperLeg'], [R.legR.sh, 'RightLowerLeg'], [R.legR.foot, 'RightFoot']];
  }
  function segOf(R, o) {
    const G = groups(R);
    for (let p = o.parent; p; p = p.parent) { const f = G.find(g => g[0] === p); if (f) return f; }
    return null;
  }
  const out = { palette: PALETTE, tones: SKIN_TONES };

  // ---------- soldat réaliste (même maillage pour les trois équipes, seule la texture change) ----------
  const LOOK = { t: { kind: 't', acc: PALETTE[5], tone: SKIN_TONES[0] }, ct: { kind: 'ct', acc: PALETTE[1], tone: SKIN_TONES[0] }, ffa: { kind: 'ffa', acc: PALETTE[0], tone: SKIN_TONES[0] } };
  out.gear = {};
  for (const k of ['t', 'ct', 'ffa']) {
    const R = makeSoldier(LOOK[k]); R.root.updateMatrixWorld(true);
    if (!R.rb) throw new Error('soldat réaliste absent (cfg.realChars ?)');
    const B = n => R.rb.inner.getObjectByName(n);
    const BONE = { pelvis: 'pelvis', spine: 'spine_01', neck: 'neck_01', head: 'head', thighL: 'thigh_l', calfL: 'calf_l', footL: 'foot_l', thighR: 'thigh_r', calfR: 'calf_r', footR: 'foot_r',
      uarmL: 'upperarm_l', farmL: 'lowerarm_l', handL: 'hand_l', uarmR: 'upperarm_r', farmR: 'lowerarm_r', handR: 'hand_r' };
    const bones = {}; for (const b in BONE) bones[b] = arr(wpos(B(BONE[b])));
    if (k === 't') {
      const arm = {};
      for (const [s, K] of [['l', 'L'], ['r', 'R']]) { const A = R.rb.arm[K]; arm[K] = { la: +A.la.toFixed(5), lb: +A.lb.toFixed(5), dU: arr(A.dU), dF: arr(A.dF) }; }
      out.real = { bones, pelOff: arr(R.rb.pelOff), arm, hips: arr(wpos(R.hips)) };
      // maillage : sommets au repos (skinning appliqué), os dominant par triangle
      let sk = null; R.rb.inner.traverse(o => { if (o.isSkinnedMesh) sk = o; });
      const g = sk.geometry, P = g.attributes.position, N = g.attributes.normal, U = g.attributes.uv, SI = g.attributes.skinIndex, SW = g.attributes.skinWeight;
      const bl = sk.skeleton.bones, inv = sk.skeleton.boneInverses, M = new THREE.Matrix4(), tmp4 = new THREE.Matrix4();
      sk.skeleton.update && R.rb.inner.updateMatrixWorld(true);
      const pos = [], nrm = [], uv = [], vb = [];
      for (let i = 0; i < P.count; i++) {
        M.set(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0); const w = {};
        for (let j = 0; j < 4; j++) {
          const bi = comp(SI, i, j), wt = comp(SW, i, j); if (wt <= 0) continue;
          tmp4.multiplyMatrices(bl[bi].matrixWorld, inv[bi]);
          for (let e = 0; e < 16; e++) M.elements[e] += tmp4.elements[e] * wt;
          w[bl[bi].name] = (w[bl[bi].name] || 0) + wt;
        }
        const v = V().fromBufferAttribute(P, i).applyMatrix4(M), n = V().fromBufferAttribute(N, i).applyMatrix3(new THREE.Matrix3().getNormalMatrix(M)).normalize();
        pos.push(...arr(v)); nrm.push(+n.x.toFixed(3), +n.y.toFixed(3), +n.z.toFixed(3)); uv.push(+U.getX(i).toFixed(5), +U.getY(i).toFixed(5)); vb.push(w);
      }
      out.body = { pos, nrm, uv, idx: Array.from(g.index.array), w: vb };
    }
    // équipement gardé (gilet, casque, poches, sac) : maillages visibles hors corps réaliste et hors arme
    const pieces = [];
    R.root.traverse(o => {
      if (!o.isMesh || o.isSkinnedMesh || !o.visible) return;
      let vis = true; for (let p = o; p; p = p.parent) if (p.visible === false) vis = false;
      if (!vis || R.gunMount.getObjectById(o.id)) return;
      const s = segOf(R, o); if (!s) return;
      const pivName = s[1] === 'LowerTorso' ? 'pelvis' : s[1] === 'UpperTorso' ? 'spine' : 'head';
      const piv = new THREE.Vector3(...bones[pivName]);
      const gg = geo(o, o.matrixWorld, piv);
      pieces.push(Object.assign(gg, { seg: s[1], color: rgb(o.material), cls: cls(o.material) }));
    });
    out.gear[k] = pieces;
  }

  // ---------- tenues : soldat procédural (corps commun + coiffe propre à chaque tenue) ----------
  const SLOTS = ['skin', 'shirt', 'pants', 'vest', 'helm', 'glove', 'boot', 'accent', 'dark', 'lens', 'blk', 'gold', 'glass'];
  out.slots = SLOTS; out.outfits = [];
  for (let oi = 1; oi < OUTFITS.length; oi++) {
    const look = { kind: 'ct', acc: PALETTE[1], tone: SKIN_TONES[0], outfit: oi };
    const R = makeSoldier(look); R.root.updateMatrixWorld(true);
    const Mt = lookMats(look), O = OUTFITS[oi];
    const slotOf = m => { for (const s of SLOTS) if (Mt[s] === m) return s; return null; };
    const colors = {}; for (const s of SLOTS) if (Mt[s]) colors[s] = { c: rgb(Mt[s]), cls: cls(Mt[s]) };
    const entry = { i: oi, name: O.n, glow: !!O.glow, metal: !!O.metal, colors, head: [] };
    const headPiv = wpos(R.head);
    R.head.children.forEach((o, ci) => {
      if (ci < 8) return;   // les 8 premiers enfants (visage) font partie du corps commun
      o.traverse(m => {
        if (!m.isMesh) return;
        const s = slotOf(m.material);
        entry.head.push(Object.assign(geo(m, m.matrixWorld, headPiv), { seg: 'Head', slot: s, color: rgb(m.material), cls: cls(m.material) }));
      });
    });
    out.outfits.push(entry);
    if (oi !== 1) continue;
    // corps commun (pris sur la première tenue)
    const piv = {}; for (const [g, seg] of groups(R)) if (!piv[seg] || g === R.head) piv[seg] = wpos(g);
    out.proc = { piv: {}, S: {}, gun: arr(R.gunMount.position) };
    for (const s in piv) out.proc.piv[s] = arr(piv[s]);
    for (const K of ['L', 'R']) out.proc.S[K] = arr(R.arm[K].S);
    out.proc.spine = arr(wpos(R.spine)); out.proc.neck = arr(wpos(R.neckG)); out.proc.hips = arr(wpos(R.hips));
    const body = [];
    const armSet = new Map();
    for (const K of ['L', 'R']) {
      const A = R.arm[K], side = K === 'L' ? 'Left' : 'Right';
      armSet.set(A.ua, [side + 'UpperArm', new THREE.Matrix4()]);
      armSet.set(A.fa, [side + 'LowerArm', new THREE.Matrix4()]);
      armSet.set(A.elbow, [side + 'UpperArm', new THREE.Matrix4().compose(new THREE.Vector3(0, -.29, 0), new THREE.Quaternion(), A.elbow.scale)]);
      armSet.set(A.pad, [side + 'UpperArm', new THREE.Matrix4().makeTranslation(0, -.29, 0)]);
      armSet.set(A.band, [side + 'UpperArm', new THREE.Matrix4().makeTranslation(0, -.29 * .55, 0)]);
      armSet.set(A.hand, [side + 'Hand', new THREE.Matrix4()]);
    }
    const headKids = new Set(R.head.children.slice(8));
    R.root.traverse(o => {
      if (!o.isMesh || R.gunMount.getObjectById(o.id)) return;
      for (let p = o; p; p = p.parent) if (headKids.has(p)) return;
      // pièces des bras : géométrie dans le repère du segment (épaule -> coude, coude -> main, main)
      for (let p = o; p; p = p.parent) {
        const a = armSet.get(p); if (!a) continue;
        const M = new THREE.Matrix4(); if (p !== o) { const rel = new THREE.Matrix4(); let q = o; const ch = []; while (q !== p) { ch.unshift(q); q = q.parent; } for (const c of ch) { c.updateMatrix(); rel.multiply(c.matrix); } M.copy(a[1]).multiply(rel); } else M.copy(a[1]);
        body.push(Object.assign(geo(o, M, new THREE.Vector3()), { seg: a[0], slot: slotOf(o.material), color: rgb(o.material), cls: cls(o.material) }));
        return;
      }
      const s = segOf(R, o); if (!s) return;
      body.push(Object.assign(geo(o, o.matrixWorld, piv[s[1]]), { seg: s[1], slot: slotOf(o.material), color: rgb(o.material), cls: cls(o.material) }));
    });
    out.proc.body = body;
  }
  return out;
}

(async () => {
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await b.newPage();
  await p.addInitScript(() => { setInterval(() => { const d = document.getElementById('daily'); if (d) d.classList.remove('show'); }, 100); });
  p.on('pageerror', e => console.warn('page :', e.message));
  await p.goto('file://' + path.join(tmp, 'sa.html'));
  await p.waitForTimeout(2500);
  await p.waitForFunction(() => window.__sx, null, { timeout: 30000 });
  const data = await p.evaluate(grab);
  fs.writeFileSync(OUT, JSON.stringify(data));
  await b.close();
  fs.rmSync(tmp, { recursive: true, force: true });
  console.log('écrit', OUT, (fs.statSync(OUT).size / 1024).toFixed(0) + ' Ko');
})().catch(e => { console.error(e); process.exit(1); });
