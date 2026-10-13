/* =====================================================================
   SKINS D'ARMES : catalogue (39 skins) + peintures procédurales 256 px
   (couleur + carte d'émission pour les skins lumineux), projection
   continue sur toute l'arme, aperçus réels
   ===================================================================== */
const RARITY=[{id:'common',n:'Commun',c:'#9aa6b8'},{id:'rare',n:'Rare',c:'#4aa3ff'},{id:'epic',n:'Épique',c:'#b36bff'},{id:'legend',n:'Légendaire',c:'#ffb938'}];
const FIN={matte:{m:.5,r:.55},gloss:{m:.65,r:.24},chrome:{m:1,r:.12},anod:{m:.9,r:.3},pearl:{m:.85,r:.16},paint:{m:.3,r:.42}};
// n : nom ; q : rareté ; tex : peinture ; fin : finition ; a : couleur des pièces secondaires ; glow : carte d'émission (couleur ge)
const SKINS=[
 {n:'Défaut',def:1,q:0},
 {n:'Noir mat',b:'#202327',a:'#0c0d0f',fin:'matte',q:0},
 {n:'Or royal',tex:'goldleaf',a:'#6a4a10',fin:'chrome',q:3},
 {n:'Rouge sang',tex:'bloodfade',a:'#1a0406',fin:'gloss',q:1},
 {n:'Bleu néon',tex:'neonlines',a:'#050c22',fin:'gloss',glow:1,ge:'#35d6ff',ei:1.1,q:2},
 {n:'Arctique',tex:'frost',a:'#7f93a8',fin:'gloss',q:0},
 {n:'Violet nacré',tex:'pearl',a:'#2b1450',fin:'pearl',q:2},
 {n:'Cœurs',tex:'hearts',a:'#b0306a',fin:'paint',q:1},
 {n:'Camo forêt',tex:'camoForest',a:'#1f2810',fin:'paint',q:0},
 {n:'Camo désert',tex:'camoDesert',a:'#5e4726',fin:'paint',q:0},
 {n:'Carbone',tex:'hex',a:'#0b0b0d',fin:'gloss',q:1},
 {n:'Vapeur',tex:'brass',a:'#3a1c0c',fin:'anod',q:1},
 {n:'Dragon',tex:'flame',a:'#1a0606',fin:'gloss',q:2},
 {n:'Galaxie',tex:'galaxy',a:'#090720',fin:'gloss',glow:1,ge:'#ffffff',ei:.9,q:3},
 {n:'Tigre',tex:'tiger',a:'#3a1d08',fin:'paint',q:1},
 {n:'Toxique',tex:'toxic',a:'#0b1f06',fin:'gloss',glow:1,ge:'#6dff2e',ei:1,q:2},
 {n:'Circuit',tex:'circuit',a:'#06181b',fin:'anod',glow:1,ge:'#28f0ff',ei:1.2,q:2},
 {n:'Marbre',tex:'marble',a:'#8a7a52',fin:'chrome',q:2},
 {n:'Damas',tex:'damascus',a:'#2a2e33',fin:'chrome',q:1},
 {n:'Bois précieux',tex:'burl',a:'#2a1608',fin:'gloss',q:1},
 {n:'Coucher de soleil',tex:'sunset',a:'#3a1630',fin:'gloss',q:1},
 {n:'Course',tex:'racing',a:'#160608',fin:'gloss',q:1},
 {n:'Danger',tex:'hazard',a:'#1a1a1a',fin:'paint',q:0},
 {n:'Léopard',tex:'leopard',a:'#2a1606',fin:'paint',q:1},
 {n:'Écailles',tex:'scales',a:'#0a2a1a',fin:'anod',q:2},
 {n:'Cristal',tex:'ice',a:'#244a66',fin:'chrome',q:2},
 {n:'Lave',tex:'lava',a:'#120806',fin:'matte',glow:1,ge:'#ff7a1a',ei:1.4,q:3},
 {n:'Graffiti',tex:'graffiti',a:'#15161a',fin:'paint',q:1},
 {n:'Matrice',tex:'matrix',a:'#03140a',fin:'gloss',glow:1,ge:'#45ff7a',ei:1.1,q:2},
 {n:'Sakura',tex:'sakura',a:'#8a3a58',fin:'paint',q:2},
 {n:'Bonbon',tex:'candy',a:'#ff8fb8',fin:'paint',q:1},
 {n:'Océan',tex:'ocean',a:'#06284a',fin:'gloss',q:1},
 {n:'Étoilé',tex:'stars',a:'#0a1233',fin:'paint',q:0},
 {n:'Hologramme',tex:'holo',a:'#2a2a3a',fin:'chrome',q:3},
 {n:'Digital',tex:'digital',a:'#1c2420',fin:'paint',q:0},
 {n:'Damier',tex:'checker',a:'#161616',fin:'gloss',q:0},
 {n:'Nuages',tex:'clouds',a:'#3a6fb0',fin:'paint',q:1},
 {n:'Filigrane royal',tex:'royal',a:'#07102a',fin:'chrome',q:3},
 {n:'Arcade',tex:'pixel8',a:'#0a0612',fin:'gloss',glow:1,ge:'#ffffff',ei:.7,q:2}
];
const skinOf=k=>SKINS[cfg.skins[k]||0]||SKINS[0];

/* ---------- peintures ---------- */
function mkRng(seed){let s=seed>>>0||1;return(a,b)=>{s=(s+0x6D2B79F5)>>>0;let t=s;t=Math.imul(t^t>>>15,t|1);t^=t+Math.imul(t^t>>>7,t|61);const v=((t^t>>>14)>>>0)/4294967296;return a===undefined?v:a+v*(b-a);};}
const hashStr=s=>{let h=2166136261;for(let i=0;i<s.length;i++){h^=s.charCodeAt(i);h=Math.imul(h,16777619);}return h>>>0;};
const PAINT={};
const grad=(c,x0,y0,x1,y1,stops)=>{const g=c.createLinearGradient(x0,y0,x1,y1);stops.forEach(s=>g.addColorStop(s[0],s[1]));return g;};
function scratches(c,w,h,r,n){c.lineWidth=1;for(let i=0;i<(n||30);i++){c.strokeStyle='rgba(255,255,255,'+r(.04,.16)+')';const x=r(0,w),y=r(0,h);c.beginPath();c.moveTo(x,y);c.lineTo(x+r(-30,30),y+r(-6,6));c.stroke();}}
function blob(c,x,y,rx,ry,rot,col){c.fillStyle=col;c.beginPath();c.ellipse(x,y,rx,ry,rot,0,TAU);c.fill();}
function star(c,x,y,R,rr,col,rot){c.fillStyle=col;c.beginPath();for(let i=0;i<10;i++){const a=rot+i*Math.PI/5-Math.PI/2,d=i&1?rr:R;c.lineTo(x+Math.cos(a)*d,y+Math.sin(a)*d);}c.closePath();c.fill();}
function heart(c,x,y,s,col){c.fillStyle=col;c.beginPath();c.moveTo(x,y+s*.35);c.bezierCurveTo(x-s,y-s*.3,x-s*.3,y-s*.9,x,y-s*.35);c.bezierCurveTo(x+s*.3,y-s*.9,x+s,y-s*.3,x,y+s*.35);c.fill();}
function camoPaint(cols,blobs,sz){return(c,w,h,g,r)=>{c.fillStyle=g?'#000':cols[0];c.fillRect(0,0,w,h);for(let L=1;L<cols.length;L++){for(let i=0;i<blobs;i++){const x=r(-20,w+20),y=r(-20,h+20),a=r(sz*.6,sz*1.6),b=r(sz*.4,sz),rot=r(0,3);for(const [ox,oy] of [[0,0],[w,0],[-w,0],[0,h],[0,-h]])blob(c,x+ox,y+oy,a,b,rot,g?'#000':cols[L]);}}if(!g)scratches(c,w,h,r,24);};}
PAINT.camoForest=camoPaint(['#55692f','#3a4b22','#7a8a45','#222d12'],26,26);
PAINT.camoDesert=camoPaint(['#cdb07a','#9a7b47','#b89a62','#6a5030'],26,26);
PAINT.digital=(c,w,h,g,r)=>{const pal=['#4b5a47','#2f3a2d','#6f7d62','#1c2420'];const s=12;for(let y=0;y<h;y+=s)for(let x=0;x<w;x+=s){const v=Math.floor(r(0,4));c.fillStyle=g?'#000':pal[v];c.fillRect(x,y,s,s);}if(!g)scratches(c,w,h,r,20);};
PAINT.checker=(c,w,h,g,r)=>{const s=32;for(let y=0;y<h;y+=s)for(let x=0;x<w;x+=s){c.fillStyle=g?'#000':(((x+y)/s)&1?'#f2f2f2':'#17171a');c.fillRect(x,y,s,s);}if(!g){c.fillStyle='#d6192b';c.fillRect(0,h/2-3,w,6);scratches(c,w,h,r,18);}};
PAINT.hazard=(c,w,h,g,r)=>{c.fillStyle=g?'#000':'#f0c020';c.fillRect(0,0,w,h);c.fillStyle=g?'#000':'#16161a';for(let x=-h;x<w+h;x+=44){c.beginPath();c.moveTo(x,h);c.lineTo(x+22,h);c.lineTo(x+22+h,0);c.lineTo(x+h,0);c.fill();}if(!g){for(let i=0;i<60;i++)blob(c,r(0,w),r(0,h),r(1,4),r(1,3),r(0,3),'rgba(30,30,30,'+r(.15,.5)+')');scratches(c,w,h,r,40);}};
PAINT.goldleaf=(c,w,h,g,r)=>{c.fillStyle=g?'#000':grad(c,0,0,w,h,[[0,'#fbe38a'],[.5,'#d5a032'],[1,'#8a5f12']]);c.fillRect(0,0,w,h);
 c.strokeStyle=g?'#000':'rgba(110,70,10,.55)';c.lineWidth=2.2;
 for(let gy=0;gy<h;gy+=64)for(let gx=0;gx<w;gx+=64){c.beginPath();c.arc(gx+32,gy+32,22,0,Math.PI*1.5);c.stroke();c.beginPath();c.arc(gx+32,gy+32,10,Math.PI*.5,Math.PI*2);c.stroke();c.beginPath();c.moveTo(gx,gy+32);c.quadraticCurveTo(gx+16,gy+8,gx+32,gy+10);c.stroke();c.fillStyle=g?'#000':'rgba(255,240,190,.7)';c.beginPath();c.arc(gx+32,gy+32,2.5,0,TAU);c.fill();}
 if(!g)scratches(c,w,h,r,34);};
PAINT.royal=(c,w,h,g,r)=>{c.fillStyle=g?'#000':grad(c,0,0,0,h,[[0,'#0e1c4a'],[1,'#060e2a']]);c.fillRect(0,0,w,h);c.strokeStyle=g?'#000':'#e8c050';c.lineWidth=1.6;
 for(let i=-h;i<w+h;i+=32){c.beginPath();c.moveTo(i,0);c.lineTo(i+h,h);c.stroke();c.beginPath();c.moveTo(i+h,0);c.lineTo(i,h);c.stroke();}
 for(let gy=16;gy<h;gy+=32)for(let gx=16;gx<w;gx+=32){c.fillStyle=g?'#000':'#f2d27a';c.beginPath();c.moveTo(gx,gy-5);c.lineTo(gx+5,gy);c.lineTo(gx,gy+5);c.lineTo(gx-5,gy);c.fill();}
 if(!g)scratches(c,w,h,r,20);};
PAINT.bloodfade=(c,w,h,g,r)=>{c.fillStyle=g?'#000':grad(c,0,0,w,h,[[0,'#ee2a36'],[.55,'#a0101c'],[1,'#2a0508']]);c.fillRect(0,0,w,h);
 for(let i=0;i<70;i++){const x=r(0,w),y=r(0,h),s=r(1,9);blob(c,x,y,s,s*r(.6,1.2),r(0,3),g?'#000':'rgba(30,2,4,'+r(.3,.8)+')');}
 for(let i=0;i<14;i++){const x=r(0,w),y=r(0,h);c.fillStyle=g?'#000':'rgba(255,200,200,.18)';c.fillRect(x,y,r(1,3),r(20,60));}if(!g)scratches(c,w,h,r,24);};
PAINT.neonlines=(c,w,h,g,r)=>{c.fillStyle=g?'#000':grad(c,0,0,0,h,[[0,'#0d2160'],[1,'#050c28']]);c.fillRect(0,0,w,h);
 c.strokeStyle=g?'#35d6ff':'#35d6ff';c.lineWidth=g?3:2.4;c.shadowColor='#35d6ff';c.shadowBlur=g?0:8;
 for(let x=0;x<=w;x+=32){c.beginPath();c.moveTo(x,0);c.lineTo(x,h);c.stroke();}for(let y=0;y<=h;y+=32){c.beginPath();c.moveTo(0,y);c.lineTo(w,y);c.stroke();}
 c.shadowBlur=0;for(let i=0;i<10;i++){c.fillStyle=g?'#fff':'#bff6ff';c.fillRect(Math.floor(r(0,8))*32-3,Math.floor(r(0,8))*32-3,6,6);}if(!g)scratches(c,w,h,r,14);};
PAINT.frost=(c,w,h,g,r)=>{c.fillStyle=g?'#000':grad(c,0,0,w,h,[[0,'#ffffff'],[1,'#c7dcf0']]);c.fillRect(0,0,w,h);
 for(let i=0;i<40;i++){const x=r(0,w),y=r(0,h),s=r(10,36),a=r(0,TAU);c.fillStyle=g?'#000':'rgba('+(r()<.5?'160,200,240':'255,255,255')+','+r(.15,.4)+')';c.beginPath();c.moveTo(x,y);c.lineTo(x+Math.cos(a)*s,y+Math.sin(a)*s);c.lineTo(x+Math.cos(a+1.1)*s*.7,y+Math.sin(a+1.1)*s*.7);c.closePath();c.fill();}
 for(let i=0;i<50;i++){c.fillStyle=g?'#000':'rgba(255,255,255,.9)';c.beginPath();c.arc(r(0,w),r(0,h),r(.6,1.8),0,TAU);c.fill();}if(!g)scratches(c,w,h,r,12);};
PAINT.pearl=(c,w,h,g,r)=>{c.fillStyle=g?'#000':grad(c,0,0,w,h,[[0,'#7a4bff'],[.35,'#ff6bd6'],[.65,'#5ad8ff'],[1,'#8b4bff']]);c.fillRect(0,0,w,h);
 for(let i=0;i<22;i++){const x=r(0,w),y=r(0,h),s=r(30,80),gg=c.createRadialGradient(x,y,0,x,y,s);gg.addColorStop(0,g?'#000':'rgba(255,255,255,.35)');gg.addColorStop(1,'rgba(255,255,255,0)');c.fillStyle=gg;c.fillRect(x-s,y-s,s*2,s*2);}if(!g)scratches(c,w,h,r,16);};
PAINT.hearts=(c,w,h,g,r)=>{c.fillStyle=g?'#000':'#ff6fb0';c.fillRect(0,0,w,h);for(let gy=0;gy<h+30;gy+=36)for(let gx=0;gx<w+30;gx+=36){heart(c,gx+((gy/36)&1?18:0),gy,11,g?'#000':(r()<.25?'#ffe14a':'#fff3fa'));}
 for(let i=0;i<30;i++)blob(c,r(0,w),r(0,h),r(1,3),r(1,3),0,g?'#000':'rgba(255,255,255,.5)');if(!g)scratches(c,w,h,r,10);};
PAINT.hex=(c,w,h,g,r)=>{c.fillStyle=g?'#000':'#121317';c.fillRect(0,0,w,h);const s=18,hh=s*Math.sqrt(3);
 for(let row=-1;row<h/hh+1;row++)for(let col=-1;col<w/(s*1.5)+1;col++){const x=col*s*1.5,y=row*hh+(col&1?hh/2:0);c.beginPath();for(let i=0;i<6;i++){const a=i*Math.PI/3;c.lineTo(x+Math.cos(a)*s*.9,y+Math.sin(a)*s*.9);}c.closePath();c.fillStyle=g?'#000':grad(c,x-s,y-s,x+s,y+s,[[0,'#2f3138'],[1,'#17181c']]);c.fill();c.strokeStyle=g?'#000':'rgba(255,255,255,.07)';c.stroke();}if(!g)scratches(c,w,h,r,18);};
PAINT.brass=(c,w,h,g,r)=>{c.fillStyle=g?'#000':grad(c,0,0,w,h,[[0,'#d98a4a'],[.5,'#b3652c'],[1,'#7a3f1a']]);c.fillRect(0,0,w,h);
 const gear=(x,y,R,teeth)=>{c.beginPath();for(let i=0;i<teeth*2;i++){const a=i*Math.PI/teeth,d=i&1?R*.82:R;c.lineTo(x+Math.cos(a)*d,y+Math.sin(a)*d);}c.closePath();c.strokeStyle=g?'#000':'rgba(60,24,6,.7)';c.lineWidth=2.2;c.stroke();c.beginPath();c.arc(x,y,R*.28,0,TAU);c.stroke();};
 gear(60,70,44,10);gear(170,60,30,8);gear(130,170,50,12);gear(40,200,26,8);gear(225,200,34,9);
 for(let i=0;i<40;i++){c.fillStyle=g?'#000':'rgba(255,225,170,.55)';c.beginPath();c.arc(r(0,w),r(0,h),r(1,2.4),0,TAU);c.fill();}if(!g)scratches(c,w,h,r,34);};
PAINT.flame=(c,w,h,g,r)=>{c.fillStyle=g?'#000':'#14080a';c.fillRect(0,0,w,h);
 const cols=['#7a1208','#d2340c','#ff8a1a','#ffd84a'];
 for(let L=0;L<4;L++){for(let i=0;i<18;i++){const x=r(0,w),t=r(40,150)*(1-L*.18);c.fillStyle=g?'#000':cols[L];c.beginPath();c.moveTo(x-r(8,16),h);c.quadraticCurveTo(x-r(0,14),h-t*.55,x+r(-10,10),h-t);c.quadraticCurveTo(x+r(0,14),h-t*.5,x+r(8,16),h);c.fill();}}
 if(!g)scratches(c,w,h,r,16);};
PAINT.galaxy=(c,w,h,g,r)=>{c.fillStyle=g?'#000':grad(c,0,0,w,h,[[0,'#2a1060'],[.5,'#0f1450'],[1,'#07061c']]);c.fillRect(0,0,w,h);
 for(let i=0;i<7;i++){const x=r(0,w),y=r(0,h),s=r(40,100),gg=c.createRadialGradient(x,y,0,x,y,s),cl=r()<.5?'255,80,200':'90,140,255';gg.addColorStop(0,g?'rgba(0,0,0,0)':'rgba('+cl+',.38)');gg.addColorStop(1,'rgba('+cl+',0)');c.fillStyle=gg;c.fillRect(x-s,y-s,s*2,s*2);}
 for(let i=0;i<220;i++){const x=r(0,w),y=r(0,h),s=r(.4,1.9),a=r(.4,1);c.fillStyle='rgba(255,255,255,'+a+')';c.beginPath();c.arc(x,y,s,0,TAU);c.fill();}
 for(let i=0;i<9;i++){const x=r(0,w),y=r(0,h);star(c,x,y,r(3,6),1.4,'rgba(255,240,200,.95)',r(0,1));}};
PAINT.tiger=(c,w,h,g,r)=>{c.fillStyle=g?'#000':grad(c,0,0,w,h,[[0,'#f08a1e'],[1,'#d96a10']]);c.fillRect(0,0,w,h);c.fillStyle=g?'#000':'#150c06';
 for(let i=0;i<13;i++){const y=i*h/12+r(-5,5);c.beginPath();c.moveTo(0,y);c.bezierCurveTo(w*.3,y-r(10,22),w*.6,y+r(10,22),w,y+r(-8,8));c.lineTo(w,y+r(8,17));c.bezierCurveTo(w*.6,y+r(18,34),w*.3,y-r(0,8),0,y+r(8,17));c.fill();}
 for(let i=0;i<30;i++)blob(c,r(0,w),r(0,h),r(2,6),r(1,3),r(0,3),g?'#000':'rgba(255,240,210,.35)');if(!g)scratches(c,w,h,r,20);};
PAINT.toxic=(c,w,h,g,r)=>{c.fillStyle=g?'#000':grad(c,0,0,0,h,[[0,'#143a0a'],[1,'#07180a']]);c.fillRect(0,0,w,h);
 c.fillStyle=g?'#000':'#e8d020';for(let x=-h;x<w+h;x+=50){c.save();c.globalAlpha=.9;c.beginPath();c.moveTo(x,h);c.lineTo(x+14,h);c.lineTo(x+14+h,0);c.lineTo(x+h,0);c.fill();c.restore();}
 for(let i=0;i<40;i++){const x=r(0,w),y=r(0,h),s=r(3,12),gg=c.createRadialGradient(x,y,0,x,y,s);gg.addColorStop(0,g?'#8cff3a':'rgba(160,255,80,.9)');gg.addColorStop(1,g?'rgba(80,255,40,0)':'rgba(80,255,40,0)');c.fillStyle=gg;c.fillRect(x-s,y-s,s*2,s*2);}if(!g)scratches(c,w,h,r,18);};
PAINT.circuit=(c,w,h,g,r)=>{c.fillStyle=g?'#000':'#0a2a30';c.fillRect(0,0,w,h);c.lineWidth=g?3:2.2;
 for(let i=0;i<46;i++){let x=Math.floor(r(0,16))*16,y=Math.floor(r(0,16))*16;c.strokeStyle=g?'#28f0ff':'#1a9aa8';c.beginPath();c.moveTo(x,y);for(let k=0;k<5;k++){const d=Math.floor(r(0,4)),L=Math.floor(r(1,5))*16;if(d===0)x+=L;else if(d===1)x-=L;else if(d===2)y+=L;else y-=L;c.lineTo(x,y);}c.stroke();c.fillStyle=g?'#bff':'#7fe9f2';c.beginPath();c.arc(x,y,4,0,TAU);c.fill();}
 for(let i=0;i<6;i++){const x=r(10,w-50),y=r(10,h-50);c.fillStyle=g?'rgba(40,240,255,.25)':'#0d1c20';c.fillRect(x,y,34,34);c.strokeStyle=g?'#28f0ff':'#1a9aa8';c.strokeRect(x,y,34,34);}if(!g)scratches(c,w,h,r,12);};
PAINT.marble=(c,w,h,g,r)=>{c.fillStyle=g?'#000':grad(c,0,0,w,h,[[0,'#fbfbfd'],[1,'#dcdde6']]);c.fillRect(0,0,w,h);
 for(let i=0;i<14;i++){let x=r(0,w),y=0;c.strokeStyle=g?'#000':'rgba(110,112,128,'+r(.25,.6)+')';c.lineWidth=r(.6,2.4);c.beginPath();c.moveTo(x,y);for(let k=0;k<9;k++){x+=r(-18,18);y+=h/9;c.lineTo(x,y);}c.stroke();}
 for(let i=0;i<4;i++){let x=r(0,w),y=0;c.strokeStyle=g?'#000':'#d8aa3a';c.lineWidth=1.4;c.beginPath();c.moveTo(x,y);for(let k=0;k<9;k++){x+=r(-22,22);y+=h/9;c.lineTo(x,y);}c.stroke();}if(!g)scratches(c,w,h,r,10);};
PAINT.damascus=(c,w,h,g,r)=>{c.fillStyle=g?'#000':'#6d737c';c.fillRect(0,0,w,h);for(let y=0;y<h;y+=3){c.beginPath();for(let x=0;x<=w;x+=6){const yy=y+Math.sin(x*.045+y*.09)*7+Math.sin(x*.11)*3;x===0?c.moveTo(x,yy):c.lineTo(x,yy);}const v=Math.floor(r(70,200));c.strokeStyle=g?'#000':'rgb('+v+','+(v+4)+','+(v+10)+')';c.lineWidth=2;c.stroke();}if(!g)scratches(c,w,h,r,16);};
PAINT.burl=(c,w,h,g,r)=>{c.fillStyle=g?'#000':'#8a4f22';c.fillRect(0,0,w,h);for(let k=0;k<5;k++){const cx=r(0,w),cy=r(0,h);for(let i=1;i<18;i++){c.beginPath();c.ellipse(cx+Math.sin(i)*3,cy,i*7,i*3.6,.3*k,0,TAU);c.strokeStyle=g?'#000':'rgba('+(r()<.5?'50,22,6':'210,140,70')+','+r(.15,.45)+')';c.lineWidth=r(1,3);c.stroke();}}
 for(let i=0;i<120;i++){c.fillStyle=g?'#000':'rgba(40,20,6,'+r(.1,.3)+')';c.fillRect(r(0,w),r(0,h),r(6,26),1);}if(!g)scratches(c,w,h,r,8);};
PAINT.sunset=(c,w,h,g,r)=>{c.fillStyle=g?'#000':grad(c,0,0,0,h,[[0,'#3a1f7a'],[.35,'#c43a8a'],[.7,'#ff8a3a'],[1,'#ffd860']]);c.fillRect(0,0,w,h);
 blob(c,w*.5,h*.72,50,50,0,g?'#000':'rgba(255,248,200,.95)');for(let y=h*.72;y<h;y+=9){c.fillStyle=g?'#000':'rgba(58,20,60,.55)';c.fillRect(0,y,w,3);}
 for(let i=0;i<40;i++){c.fillStyle=g?'#000':'rgba(255,255,255,'+r(.2,.7)+')';c.fillRect(r(0,w),r(0,h*.5),1.5,1.5);}if(!g)scratches(c,w,h,r,8);};
PAINT.racing=(c,w,h,g,r)=>{c.fillStyle=g?'#000':'#d41a28';c.fillRect(0,0,w,h);c.fillStyle=g?'#000':'#f6f6f6';c.fillRect(0,h*.4,w,h*.16);c.fillStyle=g?'#000':'#101014';c.fillRect(0,h*.4-8,w,6);c.fillRect(0,h*.56+2,w,6);
 blob(c,w*.5,h*.48,30,30,0,g?'#000':'#fff');c.fillStyle=g?'#000':'#14141a';c.font='bold 36px Arial';c.textAlign='center';c.textBaseline='middle';c.fillText('07',w*.5,h*.49);
 for(let i=0;i<8;i++){c.fillStyle=g?'#000':'#fff';c.fillRect(i*32,8,16,8);c.fillRect(i*32+16,16,16,8);}if(!g)scratches(c,w,h,r,18);};
PAINT.leopard=(c,w,h,g,r)=>{c.fillStyle=g?'#000':'#e0a040';c.fillRect(0,0,w,h);for(let i=0;i<46;i++){const x=r(0,w),y=r(0,h),s=r(7,15);c.strokeStyle=g?'#000':'#2a1608';c.lineWidth=r(3,5);c.beginPath();c.arc(x,y,s,r(0,2),r(4,6.3));c.stroke();c.fillStyle=g?'#000':'#a8651c';c.beginPath();c.arc(x,y,s*.5,0,TAU);c.fill();}if(!g)scratches(c,w,h,r,12);};
PAINT.scales=(c,w,h,g,r)=>{c.fillStyle=g?'#000':'#0c3a24';c.fillRect(0,0,w,h);const s=26;for(let y=-s;y<h+s;y+=s*.55)for(let x=-s;x<w+s;x+=s){const ox=((y/(s*.55))|0)&1?s/2:0;const gg=c.createRadialGradient(x+ox,y,2,x+ox,y,s*.6);gg.addColorStop(0,g?'#000':'#4fe08a');gg.addColorStop(1,g?'#000':'#0c4a2a');c.fillStyle=gg;c.beginPath();c.arc(x+ox,y,s*.58,0,Math.PI);c.fill();c.strokeStyle=g?'#000':'rgba(0,30,15,.7)';c.lineWidth=1.4;c.stroke();}if(!g)scratches(c,w,h,r,10);};
PAINT.ice=(c,w,h,g,r)=>{c.fillStyle=g?'#000':grad(c,0,0,w,h,[[0,'#bff0ff'],[1,'#58b4e6']]);c.fillRect(0,0,w,h);for(let i=0;i<50;i++){const x=r(0,w),y=r(0,h),s=r(15,50),a=r(0,TAU);c.fillStyle=g?'#000':'rgba('+(r()<.5?'255,255,255':'60,150,220')+','+r(.15,.45)+')';c.beginPath();c.moveTo(x,y);c.lineTo(x+Math.cos(a)*s,y+Math.sin(a)*s);c.lineTo(x+Math.cos(a+1.4)*s*.8,y+Math.sin(a+1.4)*s*.8);c.closePath();c.fill();c.strokeStyle=g?'#000':'rgba(255,255,255,.35)';c.stroke();}if(!g)scratches(c,w,h,r,12);};
PAINT.lava=(c,w,h,g,r)=>{c.fillStyle=g?'#000':'#1a0c0a';c.fillRect(0,0,w,h);for(let i=0;i<30;i++){const a=r(.3,.7);blob(c,r(0,w),r(0,h),r(8,30),r(6,20),r(0,3),g?'#000':'rgba(70,34,26,'+a+')');};
 c.lineCap='round';for(let i=0;i<20;i++){let x=r(0,w),y=r(0,h);c.beginPath();c.moveTo(x,y);for(let k=0;k<7;k++){x+=r(-26,26);y+=r(-26,26);c.lineTo(x,y);}c.strokeStyle=g?'#ff7a1a':'#ff6a14';c.lineWidth=r(2,5);c.shadowColor='#ff7a1a';c.shadowBlur=g?0:10;c.stroke();c.shadowBlur=0;c.strokeStyle=g?'#ffd070':'#ffc050';c.lineWidth=1.2;c.stroke();}if(!g)scratches(c,w,h,r,8);};
PAINT.graffiti=(c,w,h,g,r)=>{c.fillStyle=g?'#000':'#2b2f3a';c.fillRect(0,0,w,h);const cols=['#ff3b6b','#ffd23a','#35d6ff','#7dff6a','#b36bff','#ff8a2a'];for(let i=0;i<22;i++){const x=r(0,w),y=r(0,h),s=r(10,36),cl=cols[Math.floor(r(0,6))];blob(c,x,y,s,s*r(.5,1),r(0,3),g?'#000':cl);for(let k=0;k<5;k++)blob(c,x+r(-s,s),y+r(-s,s),r(1,3),r(1,3),0,g?'#000':cl);}
 c.font='bold 54px Arial';c.fillStyle=g?'#000':'#fff';c.strokeStyle=g?'#000':'#14141a';c.lineWidth=5;c.save();c.translate(w*.5,h*.55);c.rotate(-.18);c.textAlign='center';c.strokeText('GG',0,0);c.fillText('GG',0,0);c.restore();if(!g)scratches(c,w,h,r,12);};
PAINT.matrix=(c,w,h,g,r)=>{c.fillStyle=g?'#000':'#03160b';c.fillRect(0,0,w,h);c.font='bold 14px monospace';c.textAlign='center';const chars='01アイウエオカキクケコ#<>$%';for(let x=8;x<w;x+=16){const len=Math.floor(r(6,18)),y0=r(-60,h);for(let k=0;k<len;k++){const y=y0+k*14,a=k/len;c.fillStyle=g?'rgba(80,255,130,'+(a*.95)+')':'rgba(50,200,100,'+(.15+a*.8)+')';c.fillText(chars[Math.floor(r(0,chars.length))],x,((y%h)+h)%h);}c.fillStyle=g?'#e8fff0':'#d8ffe8';c.fillText(chars[Math.floor(r(0,chars.length))],x,((y0+len*14)%h+h)%h);}if(!g)scratches(c,w,h,r,8);};
PAINT.sakura=(c,w,h,g,r)=>{c.fillStyle=g?'#000':grad(c,0,0,0,h,[[0,'#ffd0e2'],[1,'#ff9cc0']]);c.fillRect(0,0,w,h);c.strokeStyle=g?'#000':'#6a3a2a';c.lineWidth=5;c.beginPath();c.moveTo(-10,h*.8);c.bezierCurveTo(w*.3,h*.55,w*.6,h*.9,w+10,h*.4);c.stroke();c.lineWidth=2.5;c.beginPath();c.moveTo(w*.35,h*.62);c.lineTo(w*.5,h*.3);c.moveTo(w*.7,h*.78);c.lineTo(w*.85,h*.55);c.stroke();
 for(let i=0;i<34;i++){const x=r(0,w),y=r(0,h),s=r(6,13);c.fillStyle=g?'#000':(r()<.5?'#fff5f9':'#ffc2da');for(let p=0;p<5;p++){const a=p*TAU/5+r(0,.3);c.beginPath();c.ellipse(x+Math.cos(a)*s*.6,y+Math.sin(a)*s*.6,s*.55,s*.32,a,0,TAU);c.fill();}c.fillStyle=g?'#000':'#e0508a';c.beginPath();c.arc(x,y,s*.2,0,TAU);c.fill();}if(!g)scratches(c,w,h,r,6);};
PAINT.candy=(c,w,h,g,r)=>{c.fillStyle=g?'#000':'#fff3f8';c.fillRect(0,0,w,h);const cols=['#ff7aa8','#8fe6c8','#ffd36a','#9ab8ff'];for(let i=-h;i<w+h;i+=40){c.strokeStyle=g?'#000':cols[((i+h)/40|0)%4];c.lineWidth=18;c.beginPath();c.moveTo(i,0);c.lineTo(i+h,h);c.stroke();}
 for(let i=0;i<60;i++){c.fillStyle=g?'#000':cols[Math.floor(r(0,4))];c.save();c.translate(r(0,w),r(0,h));c.rotate(r(0,3));c.fillRect(-5,-1.5,10,3);c.restore();}if(!g)scratches(c,w,h,r,6);};
PAINT.ocean=(c,w,h,g,r)=>{c.fillStyle=g?'#000':grad(c,0,0,0,h,[[0,'#52c8f0'],[1,'#0a3a7a']]);c.fillRect(0,0,w,h);for(let k=0;k<9;k++){const y0=k*h/8;c.beginPath();for(let x=0;x<=w;x+=6){const y=y0+Math.sin(x*.05+k)*9;x===0?c.moveTo(x,y):c.lineTo(x,y);}c.strokeStyle=g?'#000':'rgba(255,255,255,'+(.12+k*.02)+')';c.lineWidth=3;c.stroke();}
 for(let i=0;i<50;i++){c.fillStyle=g?'#000':'rgba(255,255,255,.7)';c.beginPath();c.arc(r(0,w),r(0,h),r(1,3),0,TAU);c.fill();}if(!g)scratches(c,w,h,r,8);};
PAINT.stars=(c,w,h,g,r)=>{c.fillStyle=g?'#000':grad(c,0,0,0,h,[[0,'#16246a'],[1,'#0a1233']]);c.fillRect(0,0,w,h);for(let i=0;i<22;i++)star(c,r(0,w),r(0,h),r(7,15),r(3,6),g?'#000':(r()<.5?'#ffd84a':'#fff6c0'),r(0,1));for(let i=0;i<90;i++){c.fillStyle=g?'#000':'rgba(255,255,255,'+r(.3,.9)+')';c.fillRect(r(0,w),r(0,h),1.6,1.6);}
 c.fillStyle=g?'#000':'#ffe9a0';c.beginPath();c.arc(w*.78,h*.22,18,0.6,5.7);c.arc(w*.82,h*.2,14,5.2,1.1,true);c.fill();if(!g)scratches(c,w,h,r,8);};
PAINT.holo=(c,w,h,g,r)=>{c.fillStyle=g?'#000':grad(c,0,0,w,h,[[0,'#ff6ad5'],[.2,'#ffd86a'],[.4,'#7dff9a'],[.6,'#5ad8ff'],[.8,'#a06aff'],[1,'#ff6ad5']]);c.fillRect(0,0,w,h);for(let i=-h;i<w+h;i+=14){c.fillStyle=g?'#000':'rgba(255,255,255,'+(.05+((i/14)&1)*.1)+')';c.beginPath();c.moveTo(i,0);c.lineTo(i+8,0);c.lineTo(i+8+h,h);c.lineTo(i+h,h);c.fill();}
 for(let i=0;i<40;i++){star(c,r(0,w),r(0,h),r(2,5),.8,g?'#000':'rgba(255,255,255,.9)',0);}if(!g)scratches(c,w,h,r,10);};
PAINT.clouds=(c,w,h,g,r)=>{c.fillStyle=g?'#000':grad(c,0,0,0,h,[[0,'#3a8ae0'],[1,'#a8d8ff']]);c.fillRect(0,0,w,h);for(let i=0;i<14;i++){const x=r(0,w),y=r(0,h),s=r(14,30);for(let k=0;k<5;k++){const gg=c.createRadialGradient(x+k*s*.5,y+r(-4,4),0,x+k*s*.5,y,s*.7);gg.addColorStop(0,g?'#000':'rgba(255,255,255,.95)');gg.addColorStop(1,'rgba(255,255,255,0)');c.fillStyle=gg;c.fillRect(x+k*s*.5-s,y-s,s*2,s*2);}}if(!g)scratches(c,w,h,r,6);};
PAINT.pixel8=(c,w,h,g,r)=>{c.fillStyle=g?'#000':'#120a24';c.fillRect(0,0,w,h);const cols=['#ff3b6b','#35d6ff','#ffd23a','#7dff6a','#b36bff'];const s=16;
 const inv=[[0,1,0,0,0,1,0],[0,0,1,0,1,0,0],[0,1,1,1,1,1,0],[1,1,0,1,0,1,1],[1,1,1,1,1,1,1],[1,0,1,1,1,0,1],[1,0,1,0,1,0,1]];
 for(let gy=0;gy<2;gy++)for(let gx=0;gx<2;gx++){const col=cols[Math.floor(r(0,5))];for(let y=0;y<7;y++)for(let x=0;x<7;x++)if(inv[y][x]){c.fillStyle=g?col:col;c.fillRect(gx*128+8+x*s*.9,gy*128+8+y*s*.9,s*.85,s*.85);}}
 for(let i=0;i<30;i++){const ci=Math.floor(r(0,5)),px=Math.floor(r(0,16))*16+5,py=Math.floor(r(0,16))*16+5;c.fillStyle=g?'#fff':cols[ci];c.fillRect(px,py,5,5);}if(!g)scratches(c,w,h,r,8);};

function skinTex(kind,glow){
 return cached('sk_'+kind+(glow?'_g':'_c'),()=>canvasTex(256,256,(c,w,h)=>{const r=mkRng(hashStr(kind));(PAINT[kind]||PAINT.checker)(c,w,h,!!glow,r);},true));
}
const _prevCache={};
function skinSwatch(i){
 const s=SKINS[i];if(s.def)return 'linear-gradient(135deg,#8a8f98 50%,#454a52 50%)';
 if(!s.tex)return 'linear-gradient(135deg,'+s.b+','+s.a+')';
 if(_prevCache[i])return _prevCache[i];
 try{const t=skinTex(s.tex,false),cv=document.createElement('canvas');cv.width=cv.height=40;const x=cv.getContext('2d');x.drawImage(t.image,0,0,40,40);_prevCache[i]='url('+cv.toDataURL()+') center/cover';}catch(e){_prevCache[i]='#888';}
 return _prevCache[i];
}
/* projection continue : l'arme est « peinte » d'un seul tenant (plan latéral, dessus/dessous en z-x) */
function applyPlanarUV(g,scale){
 const S0=scale||1/.78;
 g.updateMatrixWorld(true);
 g.traverse(m=>{
  if(!m.isMesh||!m.material||!m.material.userData||!m.material.userData.skinned)return;
  const geo=m.geometry.clone(),pos=geo.attributes.position,nor=geo.attributes.normal,uv=new Float32Array(pos.count*2);
  const nm=new THREE.Matrix3().getNormalMatrix(m.matrixWorld),v=new THREE.Vector3(),n=new THREE.Vector3();
  for(let i=0;i<pos.count;i++){
   v.fromBufferAttribute(pos,i).applyMatrix4(m.matrixWorld);
   n.fromBufferAttribute(nor,i).applyMatrix3(nm).normalize();
   const ax=Math.abs(n.x),ay=Math.abs(n.y),az=Math.abs(n.z);
   let u,w;
   if(ax>=ay&&ax>=az){u=-v.z;w=v.y;}else if(ay>=az){u=-v.z;w=v.x+.37;}else{u=v.x;w=v.y;}
   uv[i*2]=u*S0+.5;uv[i*2+1]=w*S0+.5;
  }
  geo.setAttribute('uv',new THREE.BufferAttribute(uv,2));m.geometry=geo;
 });
}
