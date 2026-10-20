// Fabrique la DEUXIÈME planche de sons pour Roblox (« strike-arena-sons-2 »), plus réaliste que la première :
// sons synthétisés ici même (bruit filtré, résonances métalliques, grains, enveloppes, couches), sans navigateur
// ni son pris ailleurs. Tirs en couches (détonation proche, mécanique, queue dehors / dedans, tir lointain),
// claquement supersonique, douilles selon le sol, pas selon le matériau, glissade, escalade, vêtements et
// équipement, recharge en étapes, impacts (métal, bois, béton, chair, terre), touché confirmé, sifflement d'oreille.
// Tirage au hasard à graine fixe : relancer donne exactement le même fichier.
// Usage (depuis la racine du dépôt) : node tools/render_sounds_real.js
//   -> roblox/assets/strike-arena-sons-2.ogg (à envoyer sur Roblox, voir roblox/README_ROBLOX.md)
//   -> roblox/ReplicatedStorage/Shared/SoundSheet2.lua (position de chaque son ; numéro dans ModeConfig.SOUND_SHEET_2)
// Il faut ffmpeg pour l'.ogg (sinon seul le .wav est écrit, à côté).
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
const SR = 44100, GAP = 0.2;
const ROOT = path.join(__dirname, '..');

// ---------- hasard à graine fixe ----------
let seed = 20261019;
function rnd() { seed = seed + 0x6D2B79F5 | 0; let t = Math.imul(seed ^ seed >>> 15, 1 | seed); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }
const R = (a, b) => a + rnd() * (b - a);

// ---------- briques de traitement ----------
const buf = sec => new Float32Array(Math.max(1, Math.ceil(sec * SR)));
function add(dst, src, at = 0, g = 1) {
  const o = Math.round(at * SR);
  for (let i = 0; i < src.length; i++) { const j = o + i; if (j >= 0 && j < dst.length) dst[j] += src[i] * g; }
  return dst;
}
function noise(sec) { const b = buf(sec); for (let i = 0; i < b.length; i++) b[i] = rnd() * 2 - 1; return b; }
// filtre biquad (formules RBJ) ; freq = nombre ou fonction du temps (balayage)
function bq(x, type, freq, Q = 0.707, db = 0) {
  const y = new Float32Array(x.length);
  let x1 = 0, x2 = 0, y1 = 0, y2 = 0, b0 = 0, b1 = 0, b2 = 0, a1 = 0, a2 = 0;
  const fn = typeof freq === 'function' ? freq : null;
  const coef = f => {
    f = Math.min(Math.max(f, 15), SR * 0.45);
    const w = 2 * Math.PI * f / SR, c = Math.cos(w), s = Math.sin(w), al = s / (2 * Q), A = Math.pow(10, db / 40);
    let B0, B1, B2, A0, A1, A2;
    if (type === 'lp') { B0 = (1 - c) / 2; B1 = 1 - c; B2 = B0; A0 = 1 + al; A1 = -2 * c; A2 = 1 - al; }
    else if (type === 'hp') { B0 = (1 + c) / 2; B1 = -(1 + c); B2 = B0; A0 = 1 + al; A1 = -2 * c; A2 = 1 - al; }
    else if (type === 'bp') { B0 = al; B1 = 0; B2 = -al; A0 = 1 + al; A1 = -2 * c; A2 = 1 - al; }
    else { B0 = 1 + al * A; B1 = -2 * c; B2 = 1 - al * A; A0 = 1 + al / A; A1 = -2 * c; A2 = 1 - al / A; }
    b0 = B0 / A0; b1 = B1 / A0; b2 = B2 / A0; a1 = A1 / A0; a2 = A2 / A0;
  };
  if (!fn) coef(freq);
  for (let i = 0; i < x.length; i++) {
    if (fn && (i & 31) === 0) coef(fn(i / SR));
    const v = b0 * x[i] + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
    x2 = x1; x1 = x[i]; y2 = y1; y1 = v; y[i] = v;
  }
  return y;
}
// enveloppe : montée a, palier hold, puis décroissance exponentielle tau (s)
function env(x, a, tau, hold = 0) {
  for (let i = 0; i < x.length; i++) {
    const t = i / SR;
    x[i] *= t < a ? t / a : t < a + hold ? 1 : Math.exp(-(t - a - hold) / tau);
  }
  return x;
}
function sine(sec, f, tau = 1e9) {
  const b = buf(sec); let p = rnd() * 6.283;
  for (let i = 0; i < b.length; i++) { const t = i / SR; p += 2 * Math.PI * (typeof f === 'function' ? f(t) : f) / SR; b[i] = Math.sin(p) * Math.exp(-t / tau); }
  return b;
}
// résonances (métal, bois…) : [fréquence, amplitude, durée de décroissance]
function modal(sec, modes, attack = 0.0004) {
  const b = buf(sec);
  for (const [f, a, tau] of modes) {
    const ph = rnd() * 6.283, w = 2 * Math.PI * f / SR;
    for (let i = 0; i < b.length; i++) { const t = i / SR; b[i] += a * Math.sin(ph + w * i) * Math.exp(-t / tau) * Math.min(1, t / attack); }
  }
  return b;
}
// grains : petites impulsions au hasard (rate(t) par seconde, amp(t)), puis filtrées (gravier, neige, débris)
function grains(sec, rate, amp, f, Q = 1.2) {
  const b = buf(sec);
  for (let i = 0; i < b.length; i++) {
    const t = i / SR;
    if (rnd() < rate(t) / SR) b[i] += (rnd() < 0.5 ? -1 : 1) * amp(t) * (0.3 + rnd() * 0.7);
  }
  return bq(b, 'bp', f, Q);
}
function drive(x, k) { const n = Math.tanh(k); for (let i = 0; i < x.length; i++) x[i] = Math.tanh(x[i] * k) / n; return x; }
function scale(x, g) { for (let i = 0; i < x.length; i++) x[i] *= g; return x; }
function mix(sec, layers) { const b = buf(sec); for (const [src, at, g] of layers) add(b, src, at || 0, g === undefined ? 1 : g); return b; }
function peak(x) { let m = 0; for (const v of x) m = Math.max(m, Math.abs(v)); return m; }
function norm(x, p = 1) { const m = peak(x) || 1; return scale(x, p / m); }
// échos discrets (mur, colline) : [retard s, gain, coupure du passe-bas]
function echoes(x, sec, taps) {
  const b = buf(sec); add(b, x);
  for (const [d, g, f] of taps) add(b, bq(bq(x, 'lp', f), 'lp', f), d, g);
  return b;
}
// petite salle (peignes en parallèle puis passe-tout) pour les queues d'intérieur
function room(x, sec, decay, bright) {
  const out = buf(sec), combs = [0.0297, 0.0371, 0.0411, 0.0437, 0.0253, 0.0331];
  for (const c of combs) {
    const d = Math.round(c * SR * (0.9 + rnd() * 0.2)), g = Math.pow(0.001, c / decay), line = new Float32Array(d);
    let k = 0, lp = 0;
    for (let i = 0; i < out.length; i++) {
      const v = line[k]; lp = v * bright + lp * (1 - bright);
      line[k] = (i < x.length ? x[i] : 0) + lp * g; k = (k + 1) % d; out[i] += v / combs.length;
    }
  }
  return out;
}
// mouvement d'air lent (vent, vêtements) : bruit très grave pour moduler un volume
function slowMod(len, rate, depth) {
  const n = bq(noise(len / SR + 0.1), 'lp', rate, 0.7), m = norm(n);
  return i => 1 - depth + depth * Math.abs(m[i] || 0);
}

// ---------- sons ----------
const SOUNDS = [];        // [nom, échantillons, volume relatif]
const put = (name, x, lvl) => SOUNDS.push([name, x, lvl]);

// détonation proche : claquement (1 à 3 ms), corps (bruit filtré), coup grave (sinus qui descend), saturé
const GUN = {
  pistol: { crack: .8, body: 1900, q: .9, bodyT: .018, thump: 150, thumpT: .04, low: 3800, len: .32, drv: 2.2, lvl: .8 },
  smg: { crack: .7, body: 2100, q: .9, bodyT: .014, thump: 135, thumpT: .035, low: 4200, len: .28, drv: 2.0, lvl: .62 },
  rifle: { crack: 1, body: 1500, q: .8, bodyT: .024, thump: 100, thumpT: .055, low: 3600, len: .42, drv: 2.6, lvl: 1 },
  lmg: { crack: 1, body: 1250, q: .8, bodyT: .028, thump: 85, thumpT: .065, low: 3200, len: .46, drv: 2.8, lvl: 1.1 },
  sniper: { crack: 1.2, body: 1000, q: .7, bodyT: .045, thump: 62, thumpT: .11, low: 2800, len: .7, drv: 3.2, lvl: 1.6 },
  shotgun: { crack: .9, body: 850, q: .7, bodyT: .05, thump: 66, thumpT: .1, low: 2400, len: .65, drv: 3.0, lvl: 1.45 },
};
function gunClose(p) {
  const L = p.len, tr = env(noise(.004), .0002, .0009);
  const body = env(bq(noise(L), 'bp', p.body * R(.92, 1.08), p.q), .0008, p.bodyT * R(.9, 1.1));
  const air = env(bq(noise(L), 'lp', t => p.low * Math.exp(-t * 9) + 500), .0005, p.bodyT * 2.2);
  const f0 = p.thump * R(.94, 1.06);
  const thump = sine(L, t => f0 * (0.55 + 0.45 * Math.exp(-t * 30)), p.thumpT);
  const sub = env(bq(noise(L), 'lp', 180), .002, p.thumpT * 1.4);
  const x = mix(L, [[tr, 0, p.crack], [body, 0, .9], [air, 0, .55], [thump, 0, .9], [sub, 0, .7]]);
  // première réflexion très courte (sol tout près) : épaissit le coup
  add(x, bq(x.slice(0, Math.round(SR * .06)), 'lp', 2500), .0045, .35);
  return drive(norm(x), p.drv);
}
for (const k in GUN) { put(k + '#1', gunClose(GUN[k]), GUN[k].lvl); put(k + '#2', gunClose(GUN[k]), GUN[k].lvl); }

// mécanique de l'arme (culasse qui recule et revient) : claquements métalliques courts
function clack(f, tau, a = 1) {
  return mix(.12, [[env(bq(noise(.05), 'bp', f, 2.5), .0003, tau), 0, a],
    [modal(.12, [[f * 1.37, .25 * a, tau * 2], [f * 2.11, .15 * a, tau * 1.4], [f * .61, .2 * a, tau * 1.6]]), 0, 1]]);
}
put('mech_light', mix(.14, [[clack(3200, .006), 0, 1], [clack(2600, .008, .8), .028, 1]]), .3);
put('mech_heavy', mix(.17, [[clack(2400, .008), 0, 1], [clack(1900, .011, .9), .042, 1], [env(bq(noise(.05), 'bp', 900, 1), .001, .01), .042, .4]]), .38);

// queue dehors : grondement grave qui roule, puis renvois d'un mur ou d'une colline
function tailOut(heavy) {
  const L = heavy ? 2.6 : 2.0, n = noise(L), m = slowMod(n.length, 9, .55);
  const rumble = bq(bq(n, 'lp', t => (heavy ? 700 : 950) * Math.exp(-t * 1.1) + 120), 'lp', 1400);
  for (let i = 0; i < rumble.length; i++) rumble[i] *= m(i);
  env(rumble, .012, heavy ? .55 : .4);
  const slap = env(bq(noise(.3), 'lp', 1200), .002, .05);
  const taps = [[.21 + R(0, .05), .55, 1500], [.47 + R(0, .08), .38, 1000], [.86 + R(0, .1), .22, 700]];
  return mix(L, [[echoes(rumble, L, taps.map(([d, g, f]) => [d, g * .6, f])), 0, 1], [echoes(slap, L, taps), 0, .8]]);
}
put('tail_out_light', norm(tailOut(false)), .4);
put('tail_out_heavy', norm(tailOut(true)), .5);
// queue dedans : salle dense et plus claire, plus courte
function tailIn(heavy) {
  const ex = env(bq(noise(.08), 'bp', heavy ? 1300 : 1800, .7), .0005, .018);
  return norm(bq(room(ex, heavy ? 1.3 : 1.0, heavy ? .9 : .65, .55), 'hp', 160));
}
put('tail_in_light', tailIn(false), .45);
put('tail_in_heavy', tailIn(true), .55);

// tir lointain : plus d'aigus (l'air les absorbe), un coup sourd puis un long grondement
function gunFar(heavy) {
  const L = heavy ? 2.2 : 1.7;
  const thud = env(bq(noise(L), 'lp', heavy ? 420 : 600, .9), .004, heavy ? .07 : .05);
  const boom = sine(L, t => (heavy ? 70 : 95) * (.7 + .3 * Math.exp(-t * 12)), heavy ? .12 : .08);
  const n = noise(L), m = slowMod(n.length, 6, .6), roll = bq(n, 'lp', heavy ? 300 : 400);
  for (let i = 0; i < roll.length; i++) roll[i] *= m(i);
  env(roll, .05, heavy ? .7 : .5);
  return norm(mix(L, [[thud, 0, 1], [boom, 0, .7], [roll, .02, .55], [bq(thud, 'lp', 300), .35 + R(0, .1), .35]]));
}
put('far_light#1', gunFar(false), .9); put('far_light#2', gunFar(false), .9);
put('far_heavy#1', gunFar(true), 1.1); put('far_heavy#2', gunFar(true), 1.1);

// balle supersonique qui passe tout près : claquement sec (onde en N) puis souffle qui retombe
function crack() {
  const L = .22, x = buf(L), n = Math.round(SR * .0006);
  for (let i = 0; i < 2 * n; i++) x[i] = i < n ? 1 - i / n * 2 : -1 + (i - n) / n * 2;
  const whiz = env(bq(noise(L), 'bp', t => 5200 * Math.exp(-t * 7) + 1400, 1.4), .001, .05);
  return norm(mix(L, [[bq(x, 'hp', 900), 0, 1], [whiz, .0015, .35], [env(bq(noise(.02), 'hp', 3000), .0002, .002), 0, .5]]));
}
put('crack#1', crack(), .75); put('crack#2', crack(), .75);
// balle plus lente (pistolet de loin) : sifflement qui passe
put('whiz', norm(env(bq(noise(.35), 'bp', t => 3800 * (1 - t * 1.6) + 600, 3), .09, .06)), .35);

// douilles qui tombent : laiton qui sonne (résonances inharmoniques) et rebondit
function brass(kind, shotgun) {
  const L = .55, out = buf(L);
  const bright = { hard: 1, metal: 1, wood: .75, soft: .35 }[kind];
  let t = 0, a = 1, gapT = R(.09, .13);
  const hits = kind === 'soft' ? 2 : kind === 'wood' ? 3 : 5;
  for (let h = 0; h < hits; h++) {
    const f = (shotgun ? 1150 : 3600) * R(.93, 1.07);
    const modes = shotgun ? [[f, .5, .012], [f * 1.7, .25, .008]]
      : [[f, .6, .05 * bright], [f * 1.48, .4, .035 * bright], [f * 2.27, .3, .025 * bright], [f * 2.9, .2, .018 * bright]];
    let x = modal(.12, modes);
    if (kind === 'soft') x = bq(x, 'lp', 1800);
    add(x, env(bq(noise(.02), 'bp', kind === 'wood' ? 900 : 2500, 1.2), .0002, .003), 0, .5);
    if (kind === 'metal') add(x, modal(.15, [[880 * R(.9, 1.1), .25, .06], [1460, .15, .04]]), 0, 1);
    add(out, x, t, a);
    t += gapT; gapT *= R(.55, .75); a *= R(.45, .6);
  }
  return norm(out);
}
for (const k of ['hard', 'metal', 'wood', 'soft']) { put('brass_' + k + '#1', brass(k), .14); put('brass_' + k + '#2', brass(k), .14); }
put('brass_hull', brass('hard', true), .14);

// détente à vide : déclic de la détente puis le chien qui tombe
put('dryfire', norm(mix(.1, [[clack(2600, .004, .7), 0, 1], [modal(.08, [[4300, .5, .012], [6100, .3, .008]]), .018, 1]])), .22);

// ---------- pas ----------
// coup de talon (grave) + texture du sol ; 3 variantes par sol
function heel(f = 380, tau = .018) { return env(bq(noise(.12), 'lp', f, .9), .002, tau); }
const STEP = {
  stone: () => mix(.22, [[heel(420), 0, 1], [env(bq(noise(.05), 'bp', 2900 * R(.9, 1.1), 1.4), .0005, .006), .002, .55],
    [grains(.12, t => 300 * Math.exp(-t * 30), () => .6, 3500, 1), .004, .45]]),
  wood: () => mix(.25, [[heel(320), 0, .9], [modal(.2, [[190 * R(.9, 1.1), .5, .035], [410 * R(.9, 1.1), .35, .025], [870, .15, .015]]), .002, 1],
    [env(bq(noise(.08), 'bp', 1500, 2), .001, .008), .002, .3]]),
  metal: () => mix(.35, [[heel(360), 0, .8], [modal(.32, [[420 * R(.93, 1.07), .35, .09], [1130 * R(.95, 1.05), .3, .07], [2350, .18, .05], [3700, .1, .03]]), .002, .9]]),
  sand: () => mix(.25, [[heel(300, .02), 0, .8], [grains(.2, t => 2500 * Math.exp(-t * 18), t => Math.exp(-t * 12), 2600, .8), 0, 1.4]]),
  grass: () => mix(.3, [[heel(260, .02), 0, .6], [env(bq(noise(.25), 'bp', 4200, .6), .015, .05), 0, .55],
    [grains(.2, t => 900 * Math.exp(-t * 14), () => .6, 5200, .9), .01, .5]]),
  snow: () => mix(.32, [[heel(240, .025), 0, .7], [grains(.26, t => 4500 * Math.exp(-t * 10), t => Math.exp(-t * 8), 1500, .9), .01, 1.6]]),
};
for (const k in STEP) for (let v = 1; v <= 3; v++) put('step_' + k + '#' + v, norm(STEP[k]()), .35);
// raclement de la semelle en sprint
for (let v = 1; v <= 2; v++) put('scuff#' + v, norm(env(bq(noise(.2), 'bp', t => 1800 + 1200 * t, .9), .02, .05)), .16);

// vêtements (frottement de tissu) et équipement (boucles, chargeurs dans les poches)
function cloth() {
  const L = .38, n = bq(bq(noise(L), 'bp', R(1400, 2200), .5), 'hp', 500), m = slowMod(n.length, 30, .8);
  for (let i = 0; i < n.length; i++) n[i] *= m(i);
  return norm(env(n, R(.06, .1), .08, .05));
}
for (let v = 1; v <= 3; v++) put('cloth#' + v, cloth(), .12);
function gear() {
  const L = .3, out = buf(L);
  for (let k = 0; k < 6; k++) {
    const f = R(2200, 5200);
    add(out, modal(.06, [[f, .4, .008], [f * 1.6, .2, .005]]), R(0, .14), R(.3, 1));
  }
  add(out, env(bq(noise(.05), 'bp', 700, 1.5), .001, .012), R(0, .05), .5);
  return norm(out);
}
for (let v = 1; v <= 3; v++) put('gear#' + v, gear(), .1);
// glissade : frottement sur le sol (grains serrés), tissu, et le corps qui se pose
{
  const L = .9, n = bq(noise(L), 'bp', t => 900 + 700 * Math.exp(-t * 3), .6), m = slowMod(n.length, 40, .5);
  for (let i = 0; i < n.length; i++) n[i] *= m(i);
  env(n, .03, .3, .15);
  put('slide_rub', norm(mix(L, [[n, 0, 1], [grains(L, t => 1800 * Math.exp(-t * 2.5), () => .5, 2400, .8), 0, .8], [heel(220, .05), 0, .7], [cloth(), .05, .3]])), .45);
}
// réception : choc sourd du corps, sol, et équipement qui bouge
for (let v = 1; v <= 2; v++) {
  const thud = mix(.5, [[heel(240, .05), 0, 1], [sine(.3, t => 75 * (.6 + .4 * Math.exp(-t * 20)), .06), 0, .8],
    [grains(.18, t => 1500 * Math.exp(-t * 25), () => .6, 2200, .9), .003, .5], [gear(), .02, .35]]);
  put('land_heavy#' + v, norm(thud), .5);
}
// escalade : les mains attrapent le rebord, le corps se hisse (tissu + équipement)
put('climb', norm(mix(.7, [[heel(500, .015), 0, .9], [env(bq(noise(.04), 'bp', 2400, 1.5), .0005, .006), .001, .4], [heel(450, .015), .09, .7],
  [cloth(), .1, .6], [gear(), .2, .5], [heel(300, .03), .42, .6]])), .4);

// ---------- recharge ----------
// glissement métal / polymère (le chargeur dans son puits)
function slideRub(len, f) { return env(bq(noise(len), 'bp', t => f * (1 + t * 2), 1.2), len * .3, len * .25); }
function rlOut(heavy) {
  return norm(mix(.3, [[clack(heavy ? 2100 : 2800, .004, .6), 0, 1], [slideRub(.09, heavy ? 1000 : 1300), .02, .6],
    [env(bq(noise(.05), 'lp', 800), .001, .012), .1, .5]]));
}
function rlIn(heavy) {
  return norm(mix(.3, [[slideRub(.06, heavy ? 900 : 1200), 0, .5], [clack(heavy ? 1800 : 2400, .007, 1), .06, 1],
    [env(bq(noise(.06), 'lp', 600), .001, .02), .06, .7], [modal(.15, [[heavy ? 650 : 900, .3, .03]]), .061, 1]]));
}
function rlBolt(heavy) {
  return norm(mix(.38, [[clack(heavy ? 2000 : 2700, .005, .7), 0, 1], [slideRub(.07, heavy ? 1500 : 1900), .005, .5],
    [clack(heavy ? 1700 : 2300, .012, 1.1), heavy ? .19 : .14, 1], [env(bq(noise(.05), 'lp', 900), .001, .02), heavy ? .19 : .14, .6]]));
}
put('rl_out_light', rlOut(false), .3); put('rl_in_light', rlIn(false), .38); put('rl_bolt_light', rlBolt(false), .42);
put('rl_out_heavy', rlOut(true), .34); put('rl_in_heavy', rlIn(true), .42); put('rl_bolt_heavy', rlBolt(true), .48);
put('rl_shell', norm(mix(.18, [[slideRub(.05, 1600), 0, .5], [clack(1900, .006, .9), .04, 1], [modal(.1, [[1250, .3, .02]]), .041, 1]])), .26);
put('rl_pump', norm(mix(.42, [[slideRub(.1, 900), 0, .7], [clack(1500, .01, 1), .1, 1], [slideRub(.08, 1100), .17, .6], [clack(1800, .014, 1.2), .25, 1]])), .55);
put('rl_bolt_sniper', norm(mix(.55, [[clack(3000, .004, .7), 0, 1], [slideRub(.1, 1700), .05, .6], [clack(2200, .006, .6), .16, 1],
  [slideRub(.08, 1400), .22, .5], [clack(2000, .012, 1), .31, 1], [clack(3200, .004, .6), .4, 1]])), .45);

// ---------- impacts ----------
function impMetal() {
  const f = R(1100, 1700);
  return norm(mix(.5, [[env(noise(.01), .0002, .0015), 0, 1], [modal(.5, [[f, .5, .12], [f * 1.57, .35, .09], [f * 2.43, .3, .06], [f * 3.6, .2, .04]]), 0, .8]]));
}
function impWood() {
  return norm(mix(.3, [[env(bq(noise(.04), 'bp', 1200, .9), .0003, .006), 0, 1], [modal(.2, [[R(280, 360), .5, .03], [R(700, 860), .3, .018]]), 0, .8],
    [grains(.18, t => 800 * Math.exp(-t * 20), () => .6, 3000, 1), .004, .5]]));
}
function impConcrete() {
  return norm(mix(.45, [[env(bq(noise(.02), 'hp', 1800), .0002, .003), 0, 1], [env(bq(noise(.08), 'bp', 900, .9), .0005, .012), 0, .6],
    [grains(.4, t => 1600 * Math.exp(-t * 9), t => Math.exp(-t * 6), 3200, .9), .006, .8]]));
}
function impFlesh() {
  return norm(mix(.25, [[env(bq(noise(.12), 'lp', 650, 1.2), .001, .02), 0, 1], [sine(.15, t => 140 * (.6 + .4 * Math.exp(-t * 40)), .025), 0, .7],
    [env(bq(noise(.06), 'bp', t => 900 - t * 4000, 3), .003, .015), .004, .4]]));
}
function impDirt() {
  return norm(mix(.35, [[env(bq(noise(.1), 'lp', 900), .001, .02), 0, 1], [grains(.3, t => 1400 * Math.exp(-t * 14), t => Math.exp(-t * 8), 1800, .8), .003, .9]]));
}
const IMP = { metal: impMetal, wood: impWood, concrete: impConcrete, flesh: impFlesh, dirt: impDirt };
for (const k in IMP) { put('imp_' + k + '#1', IMP[k](), .35); put('imp_' + k + '#2', IMP[k](), .35); }
// ricochet : la balle repart en sifflant
put('ricochet', norm(mix(.6, [[env(noise(.008), .0002, .001), 0, .6], [sine(.6, t => 3300 * Math.exp(-t * 1.6) * (1 + .02 * Math.sin(t * 90)), .17), .003, 1]])), .3);

// ---------- touché confirmé (interface) ----------
put('hit_body', norm(mix(.1, [[env(bq(noise(.03), 'bp', 3400, 1.6), .0002, .004), 0, 1], [modal(.06, [[2600, .35, .01]]), 0, 1],
  [env(bq(noise(.05), 'lp', 500), .0005, .008), 0, .6]])), .2);
put('hit_head', norm(mix(.3, [[env(bq(noise(.02), 'bp', 4000, 1.4), .0002, .003), 0, .8], [modal(.3, [[2150, .5, .07], [4710, .35, .05], [6900, .15, .03]]), 0, 1]])), .4);
put('hit_kill', norm(mix(.4, [[env(bq(noise(.05), 'lp', 700), .0005, .02), 0, 1], [sine(.3, t => 110 * (.7 + .3 * Math.exp(-t * 25)), .06), 0, .9],
  [modal(.35, [[1650, .3, .08], [3300, .15, .05]]), .01, 1]])), .55);

// ---------- explosions ----------
// sifflement d'oreille : aigu pur qui bat légèrement et s'éteint
put('ring', norm(mix(3.4, [[env(sine(3.4, 3720), .04, .9, .5), 0, 1], [env(sine(3.4, 3790), .05, .8, .4), 0, .5],
  [env(bq(noise(3.4), 'bp', 3700, 8), .1, .7, .3), 0, .2]])), .3);
function boom(far) {
  const L = far ? 2.6 : 2.4;
  const crackB = env(bq(noise(.03), 'hp', 1500), .0002, .004);
  const low = sine(L, t => 48 * (.5 + .5 * Math.exp(-t * 6)), far ? .5 : .35);
  const body = env(bq(noise(L), 'lp', t => (far ? 350 : 1600) * Math.exp(-t * 2) + 120), .004, far ? .5 : .4);
  const n = noise(L), m = slowMod(n.length, 5, .6), roll = bq(n, 'lp', 260);
  for (let i = 0; i < roll.length; i++) roll[i] *= m(i);
  env(roll, .08, .7);
  const debris = grains(1.4, t => t < .25 ? 0 : 500 * Math.exp(-(t - .25) * 3), () => .6, 2500, .9);
  return norm(drive(norm(mix(L, far ? [[low, 0, .8], [body, 0, 1], [roll, .05, .8]]
    : [[crackB, 0, .8], [low, 0, 1], [body, 0, 1], [roll, .04, .6], [debris, 0, .35]])), far ? 1.5 : 2.4));
}
put('boom_near', boom(false), 3.2);
put('boom_far', boom(true), 2.2);

// ---------- assemblage ----------
function trim(x) { let e = x.length - 1; while (e > 0 && Math.abs(x[e]) < 0.0015) e--; return x.subarray(0, Math.min(x.length, e + Math.floor(SR * .02))); }
const regions = []; const parts = []; let pos = 0;
for (const [name, raw, lvl] of SOUNDS) {
  const x = trim(norm(raw, .95));
  // petit fondu au bout (pas de clic si le son est coupé net)
  const f = Math.min(x.length, Math.floor(SR * .006)); for (let i = 0; i < f; i++) x[x.length - 1 - i] *= i / f;
  regions.push([name, pos / SR, x.length / SR, lvl]);
  parts.push(x); pos += x.length;
  const g = new Float32Array(Math.floor(SR * GAP)); parts.push(g); pos += g.length;
}
const pcm = Buffer.alloc(44 + pos * 2);
pcm.write('RIFF', 0); pcm.writeUInt32LE(36 + pos * 2, 4); pcm.write('WAVE', 8); pcm.write('fmt ', 12);
pcm.writeUInt32LE(16, 16); pcm.writeUInt16LE(1, 20); pcm.writeUInt16LE(1, 22); pcm.writeUInt32LE(SR, 24); pcm.writeUInt32LE(SR * 2, 28);
pcm.writeUInt16LE(2, 32); pcm.writeUInt16LE(16, 34); pcm.write('data', 36); pcm.writeUInt32LE(pos * 2, 40);
let o = 44;
for (const x of parts) for (const v of x) { pcm.writeInt16LE(Math.round(Math.max(-1, Math.min(1, v)) * 32767), o); o += 2; }
const outDir = path.join(ROOT, 'roblox/assets');
fs.mkdirSync(outDir, { recursive: true });
const wav = path.join(outDir, 'strike-arena-sons-2.wav'), ogg = path.join(outDir, 'strike-arena-sons-2.ogg');
fs.writeFileSync(wav, pcm);
try {
  execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libvorbis', '-q:a', '6', ogg]);
  fs.unlinkSync(wav);
} catch (e) { console.warn('ffmpeg absent : seul le .wav est écrit', e.message); }
const lua = ['-- Généré par tools/render_sounds_real.js : position de chaque son dans la planche « strike-arena-sons-2 ».',
  '-- { début (s), durée (s), volume relatif au fusil d\'assaut } ; « nom#2 » = variante de « nom » (tirée au hasard).',
  '-- Le numéro de la planche est dans ModeConfig.SOUND_SHEET_2 (0 tant qu\'elle n\'est pas envoyée sur Roblox).',
  'return {'].concat(regions.map(([n, s, d, v]) => `\t[${JSON.stringify(n)}] = { ${s.toFixed(4)}, ${d.toFixed(4)}, ${v.toFixed(3)} },`)).concat(['}']).join('\n') + '\n';
fs.writeFileSync(path.join(ROOT, 'roblox/ReplicatedStorage/Shared/SoundSheet2.lua'), lua);
console.log(regions.length, 'sons,', (pos / SR).toFixed(1), 's');
