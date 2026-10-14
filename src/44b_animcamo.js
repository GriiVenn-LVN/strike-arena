/* =====================================================================
   CAMOS ANIMÉS (rareté « Exclusif », réservés aux joueurs qui paient)
   Chaque camo a une texture 128 px partagée, redessinée ~30 fois par
   seconde tant qu'une arme l'utilise. Les motifs bouclent (tuiles sans
   couture) pour la projection continue sur l'arme.
   Sur le web il n'y a pas de paiement : ils sont visibles avec un
   cadenas « exclusif ». Sur Roblox ils s'achètent en Robux
   (roblox/ReplicatedStorage/Shared/ConfigExtra.lua, X.EXCLUSIVES).
   ===================================================================== */
const ANIM_CAMOS=[
 {id:'plasma',n:'Plasma',a:'#12061f',fin:'gloss',ei:.55,rbx:299},
 {id:'magma',n:'Magma vivant',a:'#140604',fin:'matte',ei:.9,rbx:349},
 {id:'code',n:'Code vivant',a:'#021008',fin:'gloss',ei:.8,rbx:249},
 {id:'nebula',n:'Nébuleuse',a:'#07051a',fin:'gloss',ei:.6,rbx:399},
 {id:'prism',n:'Prisme',a:'#2a2a3a',fin:'chrome',ei:.35,rbx:449},
 {id:'storm',n:'Tempête électrique',a:'#05080f',fin:'anod',ei:1,rbx:349}
];
for(const c of ANIM_CAMOS)SKINS.push({n:c.n,tex:'anim_'+c.id,anim:c.id,a:c.a,fin:c.fin,glow:1,ge:'#ffffff',ei:c.ei,q:4,rbx:c.rbx});

const ACAMO={live:{},buf:null,last:0};
// petite grille 64×64 calculée pixel par pixel puis agrandie (lissée) : économique et sans couture
function acPix(ctx,w,h,fn,t){
 if(!ACAMO.buf){const b=document.createElement('canvas');b.width=b.height=64;ACAMO.buf={cv:b,ctx:b.getContext('2d'),img:b.getContext('2d').createImageData(64,64)};}
 const B=ACAMO.buf,d=B.img.data,o=[0,0,0];
 for(let y=0;y<64;y++)for(let x=0;x<64;x++){fn(x/64,y/64,t,o);const i=(y*64+x)*4;d[i]=o[0];d[i+1]=o[1];d[i+2]=o[2];d[i+3]=255;}
 B.ctx.putImageData(B.img,0,0);ctx.imageSmoothingEnabled=true;ctx.drawImage(B.cv,0,0,w,h);
}
const P2=Math.PI*2;
function hsl2rgb(h,s,l,o){h=((h%1)+1)%1;const a=s*Math.min(l,1-l),f=n=>{const k=(n+h*12)%12;return 255*(l-a*Math.max(-1,Math.min(k-3,9-k,1)));};o[0]=f(0);o[1]=f(8);o[2]=f(4);return o;}
const ANIM_DRAW={
 plasma:(c,w,h,t)=>acPix(c,w,h,(u,v,t,o)=>{
  const s=Math.sin(P2*u+t)+Math.sin(P2*2*v-t*1.3)+Math.sin(P2*(u+v)+t*.7)+Math.sin(P2*(u-v)*2+t*.4);
  hsl2rgb(.72+s*.09+t*.03,.95,.32+.18*Math.sin(s*1.7+t),o);},t),
 magma:(c,w,h,t)=>acPix(c,w,h,(u,v,t,o)=>{
  const f=Math.abs(Math.sin(P2*2*u+Math.sin(P2*v+t*.6)*1.6+Math.sin(P2*2*v-t*.35)*.8));
  const g=Math.abs(Math.sin(P2*3*v+Math.sin(P2*2*u-t*.5)*1.2));
  const crack=Math.max(0,1-Math.min(f,g)*5.5),pulse=.75+.25*Math.sin(t*2.2+u*P2);
  const k=crack*pulse;o[0]=40+215*k;o[1]=14+170*k*k;o[2]=10+60*k*k*k;},t),
 nebula:(c,w,h,t)=>{acPix(c,w,h,(u,v,t,o)=>{
   const s=Math.sin(P2*u+Math.sin(P2*v+t*.25)*2)+Math.sin(P2*2*v+Math.cos(P2*u-t*.2)*1.5);
   const k=Math.max(0,s*.35+.25);hsl2rgb(.64+s*.1+Math.sin(t*.15)*.06,.85,.05+k*.42,o);},t);
  const r=mkRng(77);for(let i=0;i<70;i++){const x=r(0,w),y=r(0,h),ph=r(0,P2),sp=r(1.5,4),a=.35+.65*Math.max(0,Math.sin(t*sp+ph));c.fillStyle='rgba(255,255,255,'+a.toFixed(2)+')';const s=r(.6,1.8)*w/128;c.fillRect(x,y,s,s);}},
 prism:(c,w,h,t)=>acPix(c,w,h,(u,v,t,o)=>{
  const d=u+v,band=.5+.5*Math.sin(P2*6*d-t*4);
  hsl2rgb(d*.5+t*.12,.9,.5+band*.22,o);},t),
 code:(c,w,h,t)=>{
  c.fillStyle='#021209';c.fillRect(0,0,w,h);const S=w/128,r=mkRng(31),ch='01アイウエオカキクケコ<>$#';
  c.font='bold '+Math.round(11*S)+'px monospace';c.textAlign='center';c.textBaseline='top';
  for(let x=4;x<128;x+=8){const sp=r(18,46),len=Math.floor(r(6,14)),y0=(t*sp+r(0,128))%128;
   for(let k=0;k<len;k++){const y=((y0-k*10)%128+128)%128,a=1-k/len;c.fillStyle=k===0?'#e6fff0':'rgba(60,230,120,'+(a*.9).toFixed(2)+')';
    const g=ch[(Math.floor(t*6+x*.37+k*1.7)>>>0)%ch.length];c.fillText(g,x*S,y*S);if(y>118)c.fillText(g,x*S,(y-128)*S);}}},
 storm:(c,w,h,t)=>{
  const S=w/128;c.fillStyle='#0a0f1a';c.fillRect(0,0,w,h);
  c.strokeStyle='rgba(60,90,140,.35)';c.lineWidth=S;for(let y=0;y<128;y+=8){c.beginPath();for(let x=0;x<=128;x+=8){const yy=y+((x/8)&1?4:0);x?c.lineTo(x*S,yy*S):c.moveTo(0,yy*S);}c.stroke();}
  const r=mkRng(1000+Math.floor(t*7));c.lineCap='round';
  for(let b=0;b<4;b++){let x=r(0,128),y=r(0,128);const pts=[[x,y]];for(let k=0;k<7;k++){x+=r(-18,18);y+=r(6,18);pts.push([x,y]);}
   for(const [ox,oy] of [[0,0],[-128,0],[128,0],[0,-128],[0,128]]){
    c.beginPath();pts.forEach((p,i)=>i?c.lineTo((p[0]+ox)*S,(p[1]+oy)*S):c.moveTo((p[0]+ox)*S,(p[1]+oy)*S));
    c.strokeStyle='rgba(60,170,255,.35)';c.lineWidth=5*S;c.stroke();c.strokeStyle='#c8f2ff';c.lineWidth=1.4*S;c.stroke();}}
  const fl=.12+.12*Math.max(0,Math.sin(t*9));c.fillStyle='rgba(120,200,255,'+fl.toFixed(2)+')';c.fillRect(0,0,w,h);}
};
// aperçu fixe (pastilles du menu, icônes) : première image du motif
for(const c of ANIM_CAMOS)PAINT['anim_'+c.id]=(ctx,w,h)=>ANIM_DRAW[c.id](ctx,w,h,1.3);
// texture vivante partagée par toutes les armes qui portent ce camo
function animCamoTex(id){
 if(ACAMO.live[id])return ACAMO.live[id].tex;
 const cv=document.createElement('canvas');cv.width=cv.height=128;const ctx=cv.getContext('2d');ANIM_DRAW[id](ctx,128,128,0);
 const tex=new THREE.CanvasTexture(cv);tex.encoding=THREE.sRGBEncoding;tex.wrapS=tex.wrapT=THREE.RepeatWrapping;tex.anisotropy=MAXANI;
 ACAMO.live[id]={tex,ctx};return tex;
}
(function acLoop(){
 const f=now=>{requestAnimationFrame(f);
  if(document.hidden||now-ACAMO.last<33)return;ACAMO.last=now;const t=now/1000;
  for(const id in ACAMO.live){const L=ACAMO.live[id];try{ANIM_DRAW[id](L.ctx,128,128,t);L.tex.needsUpdate=true;}catch(e){}}};
 requestAnimationFrame(f);
})();
(function(){const s=document.createElement('style');s.textContent='@keyframes animSw{to{filter:hue-rotate(360deg)}}.animSw{animation:animSw 3s linear infinite}';document.head.appendChild(s);})();
