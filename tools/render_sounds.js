// Rend les sons synthétisés du jeu web (src/30_audio.js) dans un seul fichier audio pour Roblox (« planche de sons »),
// avec un navigateur sans fenêtre (Playwright + OfflineAudioContext). Roblox lit chaque son avec Sound.PlaybackRegion.
// Usage (depuis la racine du dépôt) : node tools/render_sounds.js <dossier de sortie>
//   -> <dossier>/strike-arena-sons.wav et roblox/ReplicatedStorage/Shared/SoundSheet.lua (positions de chaque son)
const fs = require('fs'), path = require('path');
const { chromium } = require('playwright');
const OUT = process.argv[2] || '.';
const NAMES = ['pistol', 'smg', 'rifle', 'lmg', 'sniper', 'shotgun', 'knife', 'knifehit', 'hit', 'hs', 'kill', 'dmg', 'shield', 'shieldbreak',
  'reload', 'magout', 'magin', 'rack', 'shellin', 'bolt', 'pump', 'draw', 'click', 'shell', 'jump', 'slide', 'land',
  'pickup', 'buy', 'deny', 'win', 'lose', 'round', 'tick', 'beep', 'heal', 'ui', 'boom', 'bang', 'pop'];
const SR = 44100, GAP = 0.25;

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  const audio = fs.readFileSync(path.join(__dirname, '../src/30_audio.js'), 'utf8');
  await page.setContent('<html><body></body></html>');
  await page.addScriptTag({ content: 'var cfg={vol:1},MAP=null;function subtitle(){}function clamp(x,a,b){return Math.max(a,Math.min(b,x))}function rand(a,b){return a+Math.random()*(b-a)}\n' + audio });
  const res = await page.evaluate(async ({ names, SR }) => {
    const out = {};
    for (const n of names) {
      const len = 2.2;
      const ctx = new OfflineAudioContext(1, Math.ceil(SR * len), SR);
      // même chaîne que initAudio() (sans le vent ambiant)
      AC = ctx; master = ctx.createGain(); master.gain.value = 1;
      comp = ctx.createDynamicsCompressor(); comp.threshold.value = -14; comp.ratio.value = 6; comp.attack.value = .003; comp.release.value = .2;
      lpf = ctx.createBiquadFilter(); lpf.type = 'lowpass'; lpf.frequency.value = 20000;
      const lowS = ctx.createBiquadFilter(); lowS.type = 'lowshelf'; lowS.frequency.value = 160; lowS.gain.value = 2;
      const highS = ctx.createBiquadFilter(); highS.type = 'highshelf'; highS.frequency.value = 5500; highS.gain.value = -5;
      const pres = ctx.createBiquadFilter(); pres.type = 'peaking'; pres.frequency.value = 3200; pres.Q.value = 1; pres.gain.value = -2.5;
      master.connect(lowS); lowS.connect(pres); pres.connect(highS); highS.connect(lpf); lpf.connect(comp); comp.connect(ctx.destination);
      noiseBuf = ctx.createBuffer(1, SR * 2, SR); const d = noiseBuf.getChannelData(0); for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
      reverb = ctx.createConvolver(); const rl = SR * 1.6, ib = ctx.createBuffer(2, rl, SR);
      for (let c = 0; c < 2; c++) { const ch = ib.getChannelData(c); for (let i = 0; i < rl; i++) ch[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / rl, 2.8) * (i < SR * .02 ? .3 : 1); }
      reverb.buffer = ib; revSend = ctx.createGain(); revSend.gain.value = .55; reverb.connect(revSend); revSend.connect(master);
      sfx(n);
      const buf = await ctx.startRendering();
      const data = buf.getChannelData(0);
      // coupe le silence de fin
      let end = data.length - 1; while (end > 0 && Math.abs(data[end]) < 0.0015) end--;
      out[n] = Array.from(data.subarray(0, Math.min(data.length, end + Math.floor(SR * 0.02))));
    }
    return out;
  }, { names: NAMES, SR });
  await browser.close();
  // assemblage : chaque son est normalisé (meilleure qualité en 16 bits) ; son volume d'origine, relatif au fusil
  // d'assaut, est noté dans SoundSheet.lua pour que Roblox garde les mêmes écarts de volume que le web
  const pk = d => { let m = 0; for (const v of d) m = Math.max(m, Math.abs(v)); return m; };
  const ref = pk(res.rifle) || 1;
  const regions = []; let all = [];
  for (const n of NAMES) {
    const d = res[n]; if (!d || d.length < 10) { console.warn('vide', n); continue; }
    const p = pk(d) || 1, g = 0.95 / p;
    const start = all.length / SR;
    all = all.concat(d.map(v => v * g)); regions.push([n, start, d.length / SR, p / ref]);
    all = all.concat(new Array(Math.floor(SR * GAP)).fill(0));
  }
  const gain = 1;
  const pcm = Buffer.alloc(44 + all.length * 2);
  pcm.write('RIFF', 0); pcm.writeUInt32LE(36 + all.length * 2, 4); pcm.write('WAVE', 8); pcm.write('fmt ', 12);
  pcm.writeUInt32LE(16, 16); pcm.writeUInt16LE(1, 20); pcm.writeUInt16LE(1, 22); pcm.writeUInt32LE(SR, 24); pcm.writeUInt32LE(SR * 2, 28);
  pcm.writeUInt16LE(2, 32); pcm.writeUInt16LE(16, 34); pcm.write('data', 36); pcm.writeUInt32LE(all.length * 2, 40);
  all.forEach((v, i) => pcm.writeInt16LE(Math.round(Math.max(-1, Math.min(1, v * gain)) * 32767), 44 + i * 2));
  fs.mkdirSync(OUT, { recursive: true });
  fs.writeFileSync(path.join(OUT, 'strike-arena-sons.wav'), pcm);
  const lua = ['-- Généré par tools/render_sounds.js : position de chaque son du jeu web dans la planche « strike-arena-sons ».',
    '-- { début (s), durée (s), volume relatif au fusil d\'assaut } ; le numéro de la planche est dans ModeConfig.SOUND_SHEET.',
    'return {'].concat(regions.map(([n, s, d, v]) => `\t${n} = { ${s.toFixed(4)}, ${d.toFixed(4)}, ${v.toFixed(3)} },`)).concat(['}']).join('\n') + '\n';
  fs.writeFileSync(path.join(__dirname, '../roblox/ReplicatedStorage/Shared/SoundSheet.lua'), lua);
  console.log(regions.length, 'sons,', (all.length / SR).toFixed(1), 's');
})();
