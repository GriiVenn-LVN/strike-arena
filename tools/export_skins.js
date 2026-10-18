// Exporte les peintures des skins d'armes du jeu web (src/44_skins.js, 44c_csskins.js, 44d_skinhq.js) pour Roblox.
// Chaque skin est dessiné par le vrai code du jeu (navigateur sans fenêtre, Playwright) en 512 px, la carte
// lumineuse des skins néon est ajoutée par-dessus, puis l'image est réduite en 128 px.
// Usage (depuis la racine du dépôt, après ./build.sh) : node tools/export_skins.js <dossier de sortie>
//   -> <dossier>/<motif>.png et <dossier>/skins.json ; ensuite : python3 tools/skins_to_lua.py <dossier>
const fs = require('fs'), path = require('path');
const { chromium } = require('playwright');
const OUT = process.argv[2] || 'skins_out';
const SIZE = 128;

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  // copie du jeu qui expose les fonctions de peinture
  let html = fs.readFileSync(path.join(__dirname, '../strike-arena.html'), 'utf8');
  html = html.replace('window.__dbg={', 'window.__dbg={HQ,PAINT,hqFinish,mkRng,hashStr,SKINS,FIN,');
  const tmp = path.join(__dirname, '../.skins_export.html');
  fs.writeFileSync(tmp, html);
  const browser = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const page = await browser.newPage();
  page.on('pageerror', e => console.log('page:', e.message));
  await page.goto('file://' + tmp);
  await page.waitForFunction(() => window.__dbg && window.__dbg.PAINT, null, { timeout: 60000 });
  const res = await page.evaluate((SIZE) => {
    const D = window.__dbg, out = [], seen = {};
    const draw = (kind, glow) => {
      const c = document.createElement('canvas'); c.width = c.height = 512; const x = c.getContext('2d');
      if (D.HQ[kind]) D.HQ[kind](x, 512, 512, glow);
      else { x.save(); x.scale(2, 2); (D.PAINT[kind] || D.PAINT.checker)(x, 256, 256, glow, D.mkRng(D.hashStr(kind))); x.restore(); }
      if (!glow) D.hqFinish(x, 512, 512, kind);
      return c;
    };
    D.SKINS.forEach((s, i) => {
      const info = { i, n: s.n, q: s.q, fin: s.fin || null, a: s.a || null, b: s.b || null, tint: s.tint || null, tex: s.tex || null, anim: s.anim || null, glow: !!s.glow, ge: s.ge || null, ei: s.ei || null };
      out.push(info);
      if (!s.tex || s.anim || seen[s.tex]) return;
      seen[s.tex] = true;
      const col = draw(s.tex, false);
      const fin = document.createElement('canvas'); fin.width = fin.height = 512; const f = fin.getContext('2d');
      f.drawImage(col, 0, 0);
      if (s.glow) {   // la carte lumineuse (émission) est éclaircie par-dessus : Roblox n'a pas d'émission par pixel
        const g = draw(s.tex, true), gc = document.createElement('canvas'); gc.width = gc.height = 512; const gx = gc.getContext('2d');
        gx.drawImage(g, 0, 0); gx.globalCompositeOperation = 'multiply'; gx.fillStyle = s.ge || '#ffffff'; gx.fillRect(0, 0, 512, 512);
        f.globalCompositeOperation = 'lighter'; f.globalAlpha = Math.min(1, (s.ei || 1) * 0.55); f.drawImage(gc, 0, 0);
      }
      const sm = document.createElement('canvas'); sm.width = sm.height = SIZE; const sx = sm.getContext('2d');
      sx.imageSmoothingEnabled = true; sx.imageSmoothingQuality = 'high'; sx.drawImage(fin, 0, 0, SIZE, SIZE);
      info.png = sm.toDataURL('image/png');
    });
    return out;
  }, SIZE);
  const meta = [];
  for (const s of res) {
    if (s.png) { fs.writeFileSync(path.join(OUT, s.tex + '.png'), Buffer.from(s.png.split(',')[1], 'base64')); delete s.png; }
    meta.push(s);
  }
  fs.writeFileSync(path.join(OUT, 'skins.json'), JSON.stringify(meta, null, 1));
  fs.unlinkSync(tmp);
  console.log(meta.length + ' skins, ' + meta.filter(s => s.tex && !s.anim).length + ' peintures');
  await browser.close();
})();
