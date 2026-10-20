#!/usr/bin/env node
/*
 Mains de la vue subjective du jeu web -> module Luau pour Roblox.
 Exécute le vrai code des gants (src/55b_hands.js : makeRealHand, gants modelés) avec three.min.js dans Node,
 regroupe les maillages par matière (tissu, paume, coque des jointures, sangle) dans le repère de la main
 (poignée en 0, -z vers l'avant, comme le web), et ajoute les manches coniques du soldat (SG.uarm / SG.farm de
 src/45_models.js : taper(rHaut, rBas, longueur, 12)), couchées sur l'axe X (épaule en -X, coude/poignet en +X).
 Les doigts ne sont pas animés sur le web (la main est un bloc rigide) : un maillage par matière suffit.
 Sortie : roblox/ReplicatedStorage/Shared/HandMeshes.lua ; par sommet 9 octets (position int16 ×3 en 1/10000 m,
 normale int8 ×3), puis les triangles (uint16 ×3).
 Usage (depuis la racine du dépôt) : node tools/hands/export_hands.js
*/
const fs = require('fs'), path = require('path'), vm = require('vm');
const ROOT = path.join(__dirname, '..', '..');
const OUT = path.join(ROOT, 'roblox', 'ReplicatedStorage', 'Shared', 'HandMeshes.lua');
const Q = 10000;

const ctx = { console, Math, Map, Set, Object, Array, Float32Array, Uint16Array, Uint32Array, Int8Array };
ctx.self = ctx; ctx.globalThis = ctx; ctx.window = ctx;
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(path.join(ROOT, 'three.min.js'), 'utf8'), ctx);
// bouchons des fonctions du jeu dont les gants ont besoin (textures de toile : sans objet ici)
const pre = 'var makeHandMesh=function(){return null};var VM={setLook:function(){}};' +
  'function cached(k,f){return null}function canvasTex(){return null}' +
  'const C=h=>new THREE.Color(h).convertSRGBToLinear();\n';
const post = '\n;globalThis.__h={makeRealHand,handMats,THREE};';
vm.runInContext(pre + fs.readFileSync(path.join(ROOT, 'src', '55b_hands.js'), 'utf8') + post, ctx);
const { makeRealHand, handMats, THREE } = ctx.__h;

// une pièce : sommets dédoublonnés (position + normale quantifiées) et triangles
function Piece() { this.key = new Map(); this.v = []; this.t = []; }
Piece.prototype.vert = function (p, n) {
  const q = [p.x, p.y, p.z].map(x => Math.max(-32767, Math.min(32767, Math.round(x * Q))))
    .concat([n.x, n.y, n.z].map(x => Math.max(-127, Math.min(127, Math.round(x * 127)))));
  const k = q.join(',');
  let i = this.key.get(k);
  if (i === undefined) { i = this.v.length; this.v.push(q); this.key.set(k, i); }
  return i;
};
Piece.prototype.add = function (geo, M) {
  const g = geo.index ? geo.toNonIndexed() : geo;
  const P = g.attributes.position, N = g.attributes.normal, nm = new THREE.Matrix3().getNormalMatrix(M);
  const a = new THREE.Vector3(), n = new THREE.Vector3();
  for (let i = 0; i < P.count; i += 3) {
    const ids = [];
    for (let j = 0; j < 3; j++) {
      a.fromBufferAttribute(P, i + j).applyMatrix4(M);
      n.fromBufferAttribute(N, i + j).applyMatrix3(nm).normalize();
      ids.push(this.vert(a, n));
    }
    if (ids[0] !== ids[1] && ids[1] !== ids[2] && ids[0] !== ids[2]) this.t.push(ids);
  }
};
Piece.prototype.lua = function () {
  if (this.v.length > 65535) throw new Error('trop de sommets');
  const b = Buffer.alloc(this.v.length * 9 + this.t.length * 6);
  this.v.forEach((q, i) => { const o = i * 9; for (let k = 0; k < 3; k++) b.writeInt16LE(q[k], o + k * 2); for (let k = 0; k < 3; k++) b.writeInt8(q[3 + k], o + 6 + k); });
  const base = this.v.length * 9;
  this.t.forEach((t, i) => { for (let k = 0; k < 3; k++) b.writeUInt16LE(t[k], base + i * 6 + k * 2); });
  return `{ nv = ${this.v.length}, nt = ${this.t.length}, data = "${b.toString('base64')}" }`;
};

// ---------- gant (main droite ; la gauche est son reflet, fait sur Roblox) ----------
const glove = { color: new THREE.Color(0.5, 0.5, 0.5) };
const hand = makeRealHand(glove), M = handMats(glove);
const matName = new Map(Object.entries(M).map(([k, m]) => [m, k]));
const pieces = {};
hand.updateMatrixWorld(true);
hand.traverse(o => {
  if (!o.isMesh) return;
  const k = matName.get(o.material);
  if (!k) throw new Error('matière inconnue');
  (pieces[k] = pieces[k] || new Piece()).add(o.geometry, o.matrixWorld);
});
const wrist = hand.userData.wristL;

// ---------- manches (cônes du soldat) ----------
function sleeve(rT, rB, len, seg) {
  const g = new THREE.CylinderGeometry(rT, rB, len, seg);   // centré, haut (rT) en +Y
  const M2 = new THREE.Matrix4().makeRotationZ(Math.PI / 2); // +Y -> -X : épaule (rT) en -X
  const p = new Piece(); p.add(g, M2); return p;
}
const up = sleeve(.063, .052, .29, 12), fore = sleeve(.054, .043, .27, 12);

// rugosité / métal des matières du web (choix de la matière Roblox)
const mat = Object.entries(M).map(([k, m]) => `${k} = { rough = ${m.roughness}, metal = ${m.metalness} }`).join(', ');
const f = v => v.toFixed(5);
let s = '-- Généré par tools/hands/export_hands.js (gants modelés de src/55b_hands.js et manches du soldat) : ne pas modifier à la main.\n';
s += '-- par sommet 9 octets : position int16 ×3 (1/10000 m, repère de la main droite), normale int8 ×3 ; puis triangles uint16 ×3\n';
s += 'return {\n\tQ = ' + Q + ',\n';
s += `\twrist = Vector3.new(${f(wrist.x)}, ${f(wrist.y)}, ${f(wrist.z)}),\n`;
s += `\tmats = { ${mat} },\n`;
s += '\tglove = {\n';
for (const k of ['fab', 'palm', 'pad', 'strap']) if (pieces[k]) s += `\t\t${k} = ${pieces[k].lua()},\n`;
s += '\t},\n';
s += `\tsleeve = {\n\t\tu = ${up.lua()},\n\t\tf = ${fore.lua()},\n\t},\n}\n`;
fs.writeFileSync(OUT, s);
const n = Object.entries(pieces).map(([k, p]) => `${k} ${p.v.length}/${p.t.length}`).join(', ');
console.log('écrit', OUT, (s.length / 1024).toFixed(0) + ' Ko', '|', n, '| manches', up.v.length + '/' + up.t.length, fore.v.length + '/' + fore.t.length);
