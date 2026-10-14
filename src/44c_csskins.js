/* =====================================================================
   SKINS « STYLE CS:GO » : 15 peintures originales dans l'esprit des
   grandes familles de skins (dégradés, sci-fi blanc/orange, trempe,
   Doppler, toile, néo-noir…). Noms et dessins propres au jeu : aucune
   copie de Valve (le jeu est public et passera sur Roblox).
   Ils entrent dans les caisses pour toutes les armes, couteaux compris.
   ===================================================================== */
const CS_SKINS=[
 {n:'Orbite',tex:'cs_orbit',a:'#1b1b1f',fin:'gloss',q:3},
 {n:'Dégradé solaire',tex:'cs_fade',a:'#3a1650',fin:'chrome',q:3},
 {n:'Bête néon',tex:'cs_beast',a:'#0d2a2a',fin:'gloss',q:2},
 {n:'Ligne rouge',tex:'cs_redline',a:'#0b0b0d',fin:'gloss',q:1},
 {n:'Dragon d\'or',tex:'cs_lore',a:'#5a4a22',fin:'paint',q:3},
 {n:'Loup hurleur',tex:'cs_howl',a:'#2a0a06',fin:'gloss',q:3},
 {n:'Trempe',tex:'cs_hardened',a:'#3a3a40',fin:'anod',q:2},
 {n:'Doppler',tex:'cs_doppler',a:'#140818',fin:'chrome',q:3},
 {n:'Dent de tigre',tex:'cs_tooth',a:'#5a3a08',fin:'chrome',q:2},
 {n:'Marbre flamme',tex:'cs_mfade',a:'#2a1030',fin:'chrome',q:2},
 {n:'Toile cramoisie',tex:'cs_web',a:'#140406',fin:'matte',q:2},
 {n:'Abattoir',tex:'cs_slaughter',a:'#3a0c10',fin:'chrome',q:2},
 {n:'Néo-noir',tex:'cs_noir',a:'#0a0a0a',fin:'gloss',q:1},
 {n:'Volcan bleu',tex:'cs_vulcan',a:'#0a1430',fin:'gloss',q:2},
 {n:'Imprimé nacré',tex:'cs_print',a:'#d8d8de',fin:'pearl',q:1}
];
for(const s of CS_SKINS)SKINS.push(s);

PAINT.cs_orbit=(c,w,h,g,r)=>{c.fillStyle='#ecebe6';c.fillRect(0,0,w,h);
 c.fillStyle='#1c1c20';c.beginPath();c.moveTo(0,h*.62);c.lineTo(w*.55,h*.62);c.lineTo(w*.7,h);c.lineTo(0,h);c.fill();
 c.beginPath();c.moveTo(w*.62,0);c.lineTo(w,0);c.lineTo(w,h*.35);c.lineTo(w*.78,h*.35);c.fill();
 c.fillStyle='#ff6a1a';c.fillRect(0,h*.54,w*.5,h*.05);c.beginPath();c.moveTo(w*.5,h*.54);c.lineTo(w*.56,h*.54);c.lineTo(w*.68,h*.82);c.lineTo(w*.62,h*.82);c.fill();
 c.fillRect(w*.7,h*.4,w*.3,h*.04);c.beginPath();c.arc(w*.3,h*.3,h*.16,0,TAU);c.strokeStyle='#1c1c20';c.lineWidth=6;c.stroke();c.fillStyle='#ff6a1a';c.beginPath();c.arc(w*.3,h*.3,h*.07,0,TAU);c.fill();
 c.strokeStyle='rgba(28,28,32,.55)';c.lineWidth=1.5;for(let i=0;i<9;i++){const y=r(0,h*.5);c.beginPath();c.moveTo(r(w*.45,w*.6),y);c.lineTo(r(w*.6,w),y);c.stroke();}
 c.fillStyle='#1c1c20';c.font='bold 13px monospace';c.fillText('ORB-07',w*.05,h*.95);if(!g)scratches(c,w,h,r,14);};
PAINT.cs_fade=(c,w,h,g,r)=>{c.fillStyle=grad(c,0,h,w,0,[[0,'#ffd23a'],[.35,'#ff5aa8'],[.7,'#8a4bff'],[1,'#3a6aff']]);c.fillRect(0,0,w,h);
 for(let i=0;i<60;i++){c.fillStyle='rgba(255,255,255,'+r(.03,.1)+')';c.fillRect(r(0,w),r(0,h),r(10,40),1);}};
PAINT.cs_beast=(c,w,h,g,r)=>{c.fillStyle='#16d6c2';c.fillRect(0,0,w,h);const cols=['#ff3fa4','#ffe14a','#1a1a2a','#7a3bff','#ff7a1a'];
 for(let i=0;i<18;i++){c.strokeStyle=cols[i%5];c.lineWidth=r(6,16);c.lineCap='round';c.beginPath();const x=r(0,w),y=r(0,h);c.moveTo(x,y);c.bezierCurveTo(x+r(-80,80),y+r(-80,80),x+r(-80,80),y+r(-80,80),x+r(-90,90),y+r(-90,90));c.stroke();}
 c.fillStyle='#fff';for(let k=0;k<2;k++){const y=h*(.35+k*.3);c.beginPath();c.moveTo(w*.2,y);for(let x=w*.2;x<w*.8;x+=14){c.lineTo(x+7,y+(k?-14:14));c.lineTo(x+14,y);}c.fill();}
 c.fillStyle='#1a1a2a';c.beginPath();c.ellipse(w*.5,h*.5,26,12,0,0,TAU);c.fill();c.fillStyle='#ff3fa4';c.beginPath();c.arc(w*.5,h*.5,7,0,TAU);c.fill();};
PAINT.cs_redline=(c,w,h,g,r)=>{PAINT.hex(c,w,h,g,r);c.fillStyle='rgba(8,8,10,.55)';c.fillRect(0,0,w,h);
 c.fillStyle='#d01020';c.fillRect(0,h*.46,w,h*.035);c.fillRect(0,h*.53,w,h*.012);c.fillRect(w*.66,0,w*.02,h);c.fillStyle='#fff';c.fillRect(0,h*.505,w,1.5);};
PAINT.cs_lore=(c,w,h,g,r)=>{c.fillStyle=grad(c,0,0,w,h,[[0,'#e8d8a8'],[1,'#c8b07a']]);c.fillRect(0,0,w,h);
 for(let i=0;i<40;i++)blob(c,r(0,w),r(0,h),r(6,24),r(4,14),r(0,3),'rgba(120,90,40,'+r(.05,.15)+')');
 c.strokeStyle='#4a6a2a';c.lineWidth=7;c.beginPath();c.moveTo(-10,h*.7);c.bezierCurveTo(w*.25,h*.2,w*.5,h*.95,w*.75,h*.35);c.bezierCurveTo(w*.85,h*.15,w*.95,h*.3,w+10,h*.25);c.stroke();
 c.fillStyle='#5a7a30';for(let t=0;t<1;t+=.06){const x=-10+t*(w+20),y=h*.55-Math.sin(t*6)*h*.18;c.beginPath();c.moveTo(x,y);c.lineTo(x+8,y-16);c.lineTo(x+14,y);c.fill();}
 c.fillStyle='#b88a2a';c.beginPath();c.moveTo(w*.78,h*.32);c.lineTo(w*.92,h*.18);c.lineTo(w*.88,h*.34);c.lineTo(w*.98,h*.4);c.lineTo(w*.82,h*.42);c.fill();
 c.strokeStyle='rgba(90,60,20,.6)';c.lineWidth=1;c.strokeRect(6,6,w-12,h-12);scratches(c,w,h,r,10);};
PAINT.cs_howl=(c,w,h,g,r)=>{c.fillStyle=grad(c,0,0,0,h,[[0,'#ff7a1a'],[1,'#c41a10']]);c.fillRect(0,0,w,h);
 for(let i=0;i<20;i++){c.strokeStyle='rgba(255,220,120,'+r(.15,.4)+')';c.lineWidth=r(2,5);c.beginPath();const x=r(0,w);c.moveTo(x,h);c.quadraticCurveTo(x+r(-30,30),h*.5,x+r(-20,20),r(0,h*.4));c.stroke();}
 c.fillStyle='#14080a';c.beginPath();const P=[[.3,.85],[.34,.5],[.3,.3],[.38,.12],[.44,.3],[.5,.26],[.6,.08],[.6,.3],[.72,.38],[.66,.46],[.74,.56],[.6,.6],[.62,.85]];P.forEach((p,i)=>i?c.lineTo(p[0]*w,p[1]*h):c.moveTo(p[0]*w,p[1]*h));c.closePath();c.fill();
 c.fillStyle='#ffd23a';c.beginPath();c.arc(w*.58,h*.36,4,0,TAU);c.fill();};
PAINT.cs_hardened=(c,w,h,g,r)=>{c.fillStyle='#8a8f96';c.fillRect(0,0,w,h);
 for(let i=0;i<90;i++){const blue=r()<.6;blob(c,r(0,w),r(0,h),r(8,40),r(6,26),r(0,3),blue?'rgba('+Math.floor(r(30,70))+','+Math.floor(r(70,120))+','+Math.floor(r(170,230))+','+r(.25,.6)+')':'rgba('+Math.floor(r(200,240))+','+Math.floor(r(160,200))+',60,'+r(.2,.5)+')');}
 scratches(c,w,h,r,26);};
PAINT.cs_doppler=(c,w,h,g,r)=>{c.fillStyle='#120616';c.fillRect(0,0,w,h);
 for(let i=0;i<26;i++){const x=r(0,w),y=r(0,h),s=r(20,60),gg=c.createRadialGradient(x,y,0,x,y,s),cl=r()<.5?'190,30,90':'90,40,200';gg.addColorStop(0,'rgba('+cl+',.7)');gg.addColorStop(1,'rgba('+cl+',0)');c.fillStyle=gg;c.fillRect(x-s,y-s,s*2,s*2);}
 for(let i=0;i<300;i++){c.fillStyle='rgba('+(r()<.5?'255,80,140':'200,170,255')+','+r(.3,.9)+')';c.fillRect(r(0,w),r(0,h),r(.6,2),r(.6,2));}};
PAINT.cs_tooth=(c,w,h,g,r)=>{c.fillStyle=grad(c,0,0,w,h,[[0,'#ffcf4a'],[1,'#e8961a']]);c.fillRect(0,0,w,h);c.fillStyle='#b8580a';
 for(let i=0;i<10;i++){const x=i*w/9+r(-6,6);c.beginPath();c.moveTo(x,0);c.lineTo(x+r(10,18),h*r(.3,.6));c.lineTo(x+r(-4,4),h);c.lineTo(x-6,h);c.lineTo(x+4,h*.5);c.lineTo(x-8,0);c.fill();}};
PAINT.cs_mfade=(c,w,h,g,r)=>{c.fillStyle=grad(c,0,0,w,0,[[0,'#ff2a3a'],[.5,'#ffd23a'],[1,'#2a5aff']]);c.fillRect(0,0,w,h);
 for(let i=0;i<14;i++){c.strokeStyle=['rgba(255,40,60,.6)','rgba(255,220,60,.6)','rgba(40,90,255,.6)'][i%3];c.lineWidth=r(6,14);c.beginPath();let x=r(0,w),y=0;c.moveTo(x,y);for(let k=0;k<8;k++){x+=r(-30,30);y+=h/8;c.lineTo(x,y);}c.stroke();}};
PAINT.cs_web=(c,w,h,g,r)=>{c.fillStyle='#8a0e14';c.fillRect(0,0,w,h);c.strokeStyle='#120204';c.lineWidth=2;
 const cx=w*.5,cy=h*.5;for(let i=0;i<14;i++){const a=i/14*TAU;c.beginPath();c.moveTo(cx,cy);c.lineTo(cx+Math.cos(a)*w,cy+Math.sin(a)*h);c.stroke();}
 for(let R=14;R<w*.8;R+=16){c.beginPath();for(let i=0;i<=14;i++){const a=i/14*TAU,rr=R+(i&1?-3:3);i?c.lineTo(cx+Math.cos(a)*rr,cy+Math.sin(a)*rr):c.moveTo(cx+Math.cos(a)*rr,cy+Math.sin(a)*rr);}c.stroke();}
 scratches(c,w,h,r,10);};
PAINT.cs_slaughter=(c,w,h,g,r)=>{c.fillStyle='#e8a0a8';c.fillRect(0,0,w,h);
 for(let i=0;i<40;i++)blob(c,r(0,w),r(0,h),r(10,40),r(6,26),r(0,3),'rgba('+Math.floor(r(160,220))+','+Math.floor(r(10,40))+',40,'+r(.4,.8)+')');
 c.strokeStyle='rgba(255,240,240,.8)';c.lineWidth=1.2;for(let i=0;i<10;i++){let x=r(0,w),y=0;c.beginPath();c.moveTo(x,y);for(let k=0;k<9;k++){x+=r(-20,20);y+=h/9;c.lineTo(x,y);}c.stroke();}};
PAINT.cs_noir=(c,w,h,g,r)=>{c.fillStyle='#f2f0ea';c.fillRect(0,0,w,h);c.fillStyle='#0a0a0a';
 for(let i=0;i<7;i++){c.beginPath();c.moveTo(r(0,w),0);c.lineTo(r(0,w),h);c.lineTo(r(0,w),h);c.lineTo(r(0,w),0);c.fill();}
 for(let y=0;y<h;y+=6)for(let x=(y/6&1)*3;x<w;x+=6){c.fillStyle='rgba(10,10,10,.5)';c.beginPath();c.arc(x,y,1.2,0,TAU);c.fill();}
 c.fillStyle='#d01020';c.beginPath();c.moveTo(w*.1,h*.2);c.lineTo(w*.5,h*.1);c.lineTo(w*.9,h*.45);c.lineTo(w*.55,h*.4);c.fill();c.font='bold 30px Arial';c.fillStyle='#0a0a0a';c.fillText('BAM!',w*.55,h*.85);};
PAINT.cs_vulcan=(c,w,h,g,r)=>{c.fillStyle='#0a1430';c.fillRect(0,0,w,h);
 const band=(y,hh,col)=>{c.fillStyle=col;c.beginPath();c.moveTo(0,y);c.lineTo(w*.6,y);c.lineTo(w*.7,y+hh*2);c.lineTo(w,y+hh*2);c.lineTo(w,y+hh*3);c.lineTo(w*.66,y+hh*3);c.lineTo(w*.56,y+hh);c.lineTo(0,y+hh);c.fill();};
 band(h*.15,h*.06,'#2a6aff');band(h*.42,h*.05,'#ffffff');band(h*.66,h*.04,'#2a6aff');c.fillStyle='#ffd23a';c.fillRect(w*.08,h*.9,w*.2,4);};
PAINT.cs_print=(c,w,h,g,r)=>{c.fillStyle=grad(c,0,0,w,h,[[0,'#ffffff'],[.5,'#e4e2ee'],[1,'#f6f0f8']]);c.fillRect(0,0,w,h);c.strokeStyle='#14141a';c.lineWidth=1.6;
 for(let k=0;k<22;k++){c.beginPath();for(let x=0;x<=w;x+=4){const y=k*12+Math.sin(x*.035+k*.5)*10;x?c.lineTo(x,y):c.moveTo(x,y);}c.stroke();}
 c.fillStyle='rgba(255,255,255,.85)';c.beginPath();c.ellipse(w*.62,h*.42,46,36,.3,0,TAU);c.fill();c.strokeStyle='#14141a';c.lineWidth=3;c.stroke();};
