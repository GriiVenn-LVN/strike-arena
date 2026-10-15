/* =====================================================================
   SKINS HAUTE QUALITÉ
   - textures 512 px (au lieu de 256) avec un vrai grain de surface
   - peintures refaites au pixel (bruit fractal sans couture, voronoï) :
     carbone tissé, damas forgé, marbre veiné, bois de loupe, lave
     craquelée, cristal à facettes, galaxie, camos organiques…
   - chaque skin reçoit une carte de rugosité (traces, usure) et, pour
     les gravés (or, filigrane, vapeur, écailles, carbone…), un relief
   Les numéros des skins ne changent pas : les sauvegardes restent bonnes.
   ===================================================================== */
const HQ={};          // HQ[kind]=(c,w,h,g)=>… : dessin pleine résolution
const HQH={};         // HQH[kind]=(u,v)=>0..1 : hauteur (relief gravé)
const HQS=512;

/* ---------- bruit sans couture ---------- */
function hqHash(x,y,s){let h=(Math.imul(x,374761393)+Math.imul(y,668265263)+Math.imul(s+1,1442695041))|0;h=Math.imul(h^(h>>>13),1274126177);return((h^(h>>>16))>>>0)/4294967296;}
function vnoise(u,v,P,s){
 const x=u*P,y=v*P,ix=Math.floor(x),iy=Math.floor(y),fx=x-ix,fy=y-iy;
 const x0=((ix%P)+P)%P,y0=((iy%P)+P)%P,x1=(x0+1)%P,y1=(y0+1)%P;
 const a=hqHash(x0,y0,s),b=hqHash(x1,y0,s),c=hqHash(x0,y1,s),d=hqHash(x1,y1,s);
 const sx=fx*fx*(3-2*fx),sy=fy*fy*(3-2*fy);
 return a+(b-a)*sx+(c-a)*sy+(a-b-c+d)*sx*sy;
}
function fbm(u,v,P,oct,s){let t=0,amp=.5,n=0;for(let i=0;i<oct;i++){t+=amp*vnoise(u,v,P,s+i*31);n+=amp;amp*=.5;P*=2;}return t/n;}
// fbm « tourbillonnée » (domaine déformé) : marbre, nébuleuses, trempe
function warp(u,v,P,oct,s,k){const a=fbm(u,v,P,3,s+101),b=fbm(u,v,P,3,s+202);return fbm(u+(a-.5)*k,v+(b-.5)*k,P,oct,s);}
// voronoï sans couture : distance au 1er et 2e point, identifiant de cellule
const _vo={d1:0,d2:0,id:0,cx:0,cy:0};
function voro(u,v,N,s,jit){
 const x=u*N,y=v*N,ix=Math.floor(x),iy=Math.floor(y);let d1=9,d2=9,id=0,cx=0,cy=0;const j=jit===undefined?.9:jit;
 for(let oy=-1;oy<=1;oy++)for(let ox=-1;ox<=1;ox++){
  const gx=ix+ox,gy=iy+oy,wx=((gx%N)+N)%N,wy=((gy%N)+N)%N;
  const px=gx+.5+(hqHash(wx,wy,s)-.5)*j,py=gy+.5+(hqHash(wx,wy,s+7)-.5)*j;
  const d=Math.hypot(px-x,py-y);
  if(d<d1){d2=d1;d1=d;id=wy*N+wx;cx=px;cy=py;}else if(d<d2)d2=d;
 }
 _vo.d1=d1;_vo.d2=d2;_vo.id=id;_vo.cx=cx/N;_vo.cy=cy/N;return _vo;
}
const sat=x=>x<0?0:x>1?1:x;
const sstep=(a,b,x)=>{const t=sat((x-a)/(b-a));return t*t*(3-2*t);};
const hx=s=>{const n=parseInt(s.slice(1),16);return[n>>16&255,n>>8&255,n&255];};
function mixc(a,b,t,o){o[0]=a[0]+(b[0]-a[0])*t;o[1]=a[1]+(b[1]-a[1])*t;o[2]=a[2]+(b[2]-a[2])*t;return o;}
// rampe de couleurs : [[t,'#rrggbb'],…]
function ramp(st){const s=st.map(x=>[x[0],hx(x[1])]);return(t,o)=>{t=sat(t);let i=0;while(i<s.length-2&&t>s[i+1][0])i++;const a=s[i],b=s[i+1];return mixc(a[1],b[1],sat((t-a[0])/(b[0]-a[0]||1)),o);};}
// dessin pixel par pixel : fn(u,v,o) remplit o=[r,g,b] (0..255)
function hqPix(c,w,h,fn){
 const img=c.createImageData(w,h),d=img.data,o=[0,0,0];
 for(let y=0;y<h;y++){const v=y/h;for(let x=0;x<w;x++){o[0]=o[1]=o[2]=0;fn(x/w,v,o);const i=(y*w+x)*4;d[i]=o[0];d[i+1]=o[1];d[i+2]=o[2];d[i+3]=255;}}
 c.putImageData(img,0,0);
}
const shade=(o,k)=>{o[0]*=k;o[1]*=k;o[2]*=k;return o;};
const addc=(o,r,g,b,k)=>{o[0]=Math.min(255,o[0]+r*k);o[1]=Math.min(255,o[1]+g*k);o[2]=Math.min(255,o[2]+b*k);return o;};

/* ---------- peintures refaites ---------- */
// Carbone : sergé 2×2 avec vernis
HQ.hex=(c,w,h,g)=>hqPix(c,w,h,(u,v,o)=>{if(g)return;
 const N=32,x=u*N,y=v*N,cx=Math.floor(x),cy=Math.floor(y),fx=x-cx,fy=y-cy;
 const warpOn=((cx+cy)>>1)&1,f=warpOn?fx:fy,fa=warpOn?fy:fx;
 const tube=Math.sin(f*Math.PI),fib=.85+.15*Math.sin(fa*Math.PI*14+(warpOn?1:2));
 let l=14+tube*44*fib;const sh=warpOn?1.08:.92;
 o[0]=l*sh;o[1]=l*sh*1.02;o[2]=l*sh*1.1;addc(o,40,44,52,Math.pow(tube,6)*.6);});
HQH.hex=(u,v)=>{const N=32,x=u*N,y=v*N,cx=Math.floor(x),cy=Math.floor(y),on=((cx+cy)>>1)&1;return Math.sin((on?x-cx:y-cy)*Math.PI)*.8+(on?.2:0);};

// Damas : acier forgé replié
HQ.damascus=(c,w,h,g)=>hqPix(c,w,h,(u,v,o)=>{if(g)return;
 const n=warp(u,v,3,4,11,.55),b=.5+.5*Math.sin((v*9+n*6)*Math.PI*2);
 const l=60+b*150+fbm(u,v,16,2,3)*30;o[0]=l*.96;o[1]=l*.98;o[2]=l*1.04;});
HQH.damascus=(u,v)=>{const n=warp(u,v,3,4,11,.55);return .5+.5*Math.sin((v*9+n*6)*Math.PI*2);};

// Marbre : veines tourbillonnées + filets d'or
{const R=ramp([[0,'#f6f5f2'],[.55,'#e2e0e6'],[.8,'#a9a7b4'],[1,'#3c3c48']]);
HQ.marble=(c,w,h,g)=>hqPix(c,w,h,(u,v,o)=>{if(g)return;
 const n=warp(u,v,2,6,21,1.3),vein=1-Math.abs(Math.sin((u+v*.5+n*2.2)*Math.PI*2)),v2=1-Math.abs(Math.sin((u*2-v+n*3.1)*Math.PI*2));
 R(Math.pow(vein,5)*.85+Math.pow(v2,12)*.45+fbm(u,v,4,4,5)*.25,o);
 const gold=Math.pow(1-Math.abs(Math.sin((v*1+n*4+.3)*Math.PI*2)),28);if(gold>.2)mixc(o,[216,168,62],sstep(.2,.6,gold),o);});}

// Bois de loupe : nœuds, cernes, vernis
{const R=ramp([[0,'#3a1a08'],[.4,'#7a3e16'],[.7,'#b06a2c'],[1,'#e0a060']]);
HQ.burl=(c,w,h,g)=>hqPix(c,w,h,(u,v,o)=>{if(g)return;
 const n=warp(u,v,3,4,41,1.2),ring=.5+.5*Math.sin(n*60),vo=voro(u,v,6,9,.8),knot=sstep(.22,0,vo.d1);
 R(ring*.6+fbm(u,v,8,3,4)*.35-knot*.45,o);shade(o,.85+fbm(u*1,v*6,32,2,8)*.3);});}

// Lave : croûte noire craquelée, fissures incandescentes
HQ.lava=(c,w,h,g)=>hqPix(c,w,h,(u,v,o)=>{
 const vo=voro(u,v,7,5,.95),e=vo.d2-vo.d1,crack=sstep(.12,0,e),heat=crack*(.6+.4*fbm(u,v,4,3,6));
 if(g){o[0]=255*heat;o[1]=150*heat*heat;o[2]=40*heat*heat*heat;return;}
 const rock=26+fbm(u,v,12,4,7)*40;o[0]=rock*1.15;o[1]=rock*.8;o[2]=rock*.7;
 addc(o,255,110,20,heat);addc(o,255,220,120,Math.pow(heat,3));});
HQH.lava=(u,v)=>{const vo=voro(u,v,7,5,.95);return sstep(0,.15,vo.d2-vo.d1)*.8+fbm(u,v,12,3,7)*.2;};

// Cristal : facettes taillées
HQ.ice=(c,w,h,g)=>hqPix(c,w,h,(u,v,o)=>{if(g)return;
 const vo=voro(u,v,6,13,.9),f=hqHash(vo.id,1,3),edge=sstep(.05,0,vo.d2-vo.d1);
 const dx=u-vo.cx,dy=v-vo.cy,lit=.5+.5*Math.sin(Math.atan2(dy,dx)*2+f*6);
 mixc([60,150,215],[220,248,255],f*.5+lit*.4,o);addc(o,255,255,255,edge*.8);});
HQH.ice=(u,v)=>{const vo=voro(u,v,6,13,.9);return 1-sstep(0,.12,vo.d2-vo.d1)*.2-vo.d1*1.5;};

// Galaxie : nébuleuses superposées, amas d'étoiles
HQ.galaxy=(c,w,h,g)=>{hqPix(c,w,h,(u,v,o)=>{
  const n1=warp(u,v,2,5,51,1.1),n2=warp(u,v,3,4,61,.9);
  if(g){o[0]=o[1]=o[2]=0;return;}
  o[0]=8+Math.pow(n1,3)*420*.6;o[1]=6+Math.pow(n2,3)*160;o[2]=24+Math.pow(n1,2)*200+Math.pow(n2,3)*240;
  const dust=sstep(.55,.75,fbm(u,v,6,4,71));shade(o,1-dust*.6);});
 const r=mkRng(99);
 for(let i=0;i<520;i++){const x=r(0,w),y=r(0,h),s=r()<.94?r(.5,1.4):r(1.6,3.2),a=r(.4,1);c.fillStyle='rgba(255,255,255,'+a+')';c.beginPath();c.arc(x,y,s,0,TAU);c.fill();
  if(s>2){const gg=c.createRadialGradient(x,y,0,x,y,s*6);gg.addColorStop(0,'rgba(200,220,255,.5)');gg.addColorStop(1,'rgba(200,220,255,0)');c.fillStyle=gg;c.fillRect(x-s*6,y-s*6,s*12,s*12);c.fillStyle='rgba(255,255,255,.7)';c.fillRect(x-s*4,y-.5,s*8,1);c.fillRect(x-.5,y-s*4,1,s*8);}}};

// Camos organiques (formes « éponge » réalistes, 4 couches)
function hqCamo(cols,P,s){const C4=cols.map(hx);return(c,w,h,g)=>hqPix(c,w,h,(u,v,o)=>{if(g)return;
 let k=0;for(let L=1;L<C4.length;L++){if(warp(u,v,P,4,s+L*13,.35)>.53+L*.01)k=L;}
 const e=C4[k];o[0]=e[0];o[1]=e[1];o[2]=e[2];shade(o,.9+fbm(u,v,48,2,s)*.2);});}
HQ.camoForest=hqCamo(['#56692f','#2f3d1a','#7d8c48','#1b2310'],3,301);
HQ.camoDesert=hqCamo(['#cdb07a','#a08250','#e0c896','#6e5434'],3,401);
// Digital : bruit quantifié en pixels (style uniforme moderne)
HQ.digital=(c,w,h,g)=>{const pal=[[75,90,71],[47,58,45],[111,125,98],[28,36,32]];hqPix(c,w,h,(u,v,o)=>{if(g)return;
 const S=64,qu=(Math.floor(u*S)+.5)/S,qv=(Math.floor(v*S)+.5)/S,n=fbm(qu,qv,4,4,501)+(hqHash(Math.floor(u*S),Math.floor(v*S),5)-.5)*.12;
 const e=pal[n<.42?3:n<.5?1:n<.58?0:2];o[0]=e[0];o[1]=e[1];o[2]=e[2];shade(o,.94+fbm(u,v,64,1,2)*.12);});};
// Arctique : neige poudreuse, plaques gris-bleu
HQ.frost=(c,w,h,g)=>hqPix(c,w,h,(u,v,o)=>{if(g)return;
 const n=warp(u,v,3,5,601,.4),k=sstep(.5,.56,n),k2=sstep(.6,.64,n);
 mixc([240,245,250],[160,178,198],k,o);mixc(o,[86,100,120],k2,o);shade(o,.92+fbm(u,v,64,2,4)*.14);});
// Tigre : rayures organiques déformées
HQ.tiger=(c,w,h,g)=>hqPix(c,w,h,(u,v,o)=>{if(g)return;
 const n=warp(u,v,2,4,701,.7),st=Math.sin((v*7+n*2.2)*Math.PI*2),thin=fbm(u,v,4,3,709);
 mixc([244,150,40],[214,96,14],fbm(u,v,3,3,703),o);
 if(st>.55+thin*.45)mixc(o,[20,12,6],sstep(.55+thin*.45,.7+thin*.45,st),o);shade(o,.92+fbm(u*3,v,48,2,7)*.16);});
// Léopard : rosettes (voronoï creux)
HQ.leopard=(c,w,h,g)=>hqPix(c,w,h,(u,v,o)=>{if(g)return;
 const vo=voro(u+fbm(u,v,8,2,801)*.03,v,9,801,.85),r=vo.d1,ring=sstep(.28,.24,r)*sstep(.12,.17,r)*(fbm(u,v,24,2,803)>.42?1:.15);
 mixc([226,166,72],[176,108,40],sstep(.25,0,r)*.6,o);mixc(o,[34,18,8],ring,o);shade(o,.94+fbm(u,v,64,2,5)*.12);});
// Écailles : écailles rondes qui se chevauchent, irisées
const _sc={k:0,id:0,d:0};
function scaleAt(u,v,N){
 const x=u*N,y=v*N*2,row=Math.floor(y);_sc.k=0;
 for(let r=row-1;r<=row+1;r++){const off=(r&1)?.5:0,cx=Math.floor(x-off)+.5+off,cy=(r+.5);
  for(const c2 of [cx-1,cx,cx+1]){const d=Math.hypot(x-c2,(y-cy)*.5)/.62;if(d<1){_sc.k=1-d;_sc.d=d;_sc.id=r*97+Math.floor(c2);}}}
 return _sc;}
HQ.scales=(c,w,h,g)=>hqPix(c,w,h,(u,v,o)=>{if(g)return;
 const s2=scaleAt(u,v,10),k=s2.k,hue=.36+.14*Math.sin(u*7+v*4)+hqHash(s2.id&1023,3,7)*.04;
 hsl2rgb(hue,.7,.1+Math.pow(k,.6)*.36,o);addc(o,210,255,230,Math.pow(k,6)*.4);if(k<.08)shade(o,.35+k*6);});
HQH.scales=(u,v)=>Math.pow(scaleAt(u,v,10).k,.5);
// Violet nacré : nacre irisée
HQ.pearl=(c,w,h,g)=>hqPix(c,w,h,(u,v,o)=>{if(g)return;
 const n=warp(u,v,2,4,901,1),b=Math.sin(n*22);hsl2rgb(.72+n*.5+b*.04,.6,.62+b*.12,o);addc(o,255,255,255,Math.pow(sat(b),12)*.4);});
// Hologramme : feuille de diffraction arc-en-ciel
HQ.holo=(c,w,h,g)=>hqPix(c,w,h,(u,v,o)=>{if(g)return;
 const n=fbm(u,v,4,3,1001),d=u*1.4+v*.8+n*.6,cell=voro(u,v,10,1003,.8),sp=hqHash(cell.id,2,9);
 hsl2rgb(d*1.2+sp*.12,.7,.68+.08*Math.sin(d*60),o);addc(o,255,255,255,sstep(.04,0,cell.d1)*.8*sp);});
// Vapeur : plaques de cuivre brossé, rivets, engrenages en relief
function hqGear(u,v,cx,cy,R,t){let dx=u-cx,dy=v-cy;dx-=Math.round(dx);dy-=Math.round(dy);const d=Math.hypot(dx,dy),a=Math.atan2(dy,dx),tooth=R*(sat(Math.sin(a*t)*3)*.14+.86);return d<tooth&&d>R*.3?(d<R*.42?.5:1):d<R*.22?.8:0;}
const GEARS=[[.22,.27,.2,12],[.62,.2,.14,9],[.55,.68,.24,14],[.12,.8,.1,8],[.88,.75,.13,10]];
HQH.brass=(u,v)=>{let m=0;for(const G2 of GEARS)m=Math.max(m,hqGear(u,v,G2[0],G2[1],G2[2],G2[3]));const px=(u*4)%1,py=(v*4)%1,riv=Math.hypot(px-.06,py-.06)<.025?1:0;return Math.max(m*.8,riv)+(Math.min(px,py)<.008?-.3:0);};
HQ.brass=(c,w,h,g)=>hqPix(c,w,h,(u,v,o)=>{if(g)return;
 const ht=HQH.brass(u,v),br=fbm(u*.05,v,128,2,1101);mixc([150,78,34],[222,140,78],.5+br*.5,o);
 if(ht>.4)mixc(o,[214,172,92],.75,o);if(ht<0)shade(o,.5);shade(o,.85+fbm(u,v,6,3,1103)*.3);});
// Or royal : or brossé, rinceaux gravés
function scroll(u,v){const N=4,x=u*N%1-.5,y=v*N%1-.5,r=Math.hypot(x,y),a=Math.atan2(y,x),sp=Math.abs(Math.sin(a*1+r*22))<.18&&r<.42&&r>.06,leaf=Math.abs(Math.sin(a*5))*.12+.36,ring=Math.abs(r-leaf)<.015;return sp||ring?1:0;}
HQH.goldleaf=(u,v)=>1-scroll(u,v)*.8-scroll(u+.125,v+.125)*.0;
HQ.goldleaf=(c,w,h,g)=>hqPix(c,w,h,(u,v,o)=>{if(g)return;
 const br=fbm(u,v*.04,128,2,1201),s=scroll(u,v);mixc([170,112,26],[252,222,128],.45+br*.4+fbm(u,v,3,3,1203)*.25,o);if(s)mixc(o,[96,58,10],.8,o);});
// Filigrane royal : bleu nuit, treillis doré en relief, fleurons
HQH.royal=(u,v)=>{const N=8,x=(u+v)*N%1,y=(u-v+1)*N%1,l=Math.min(Math.abs(x-.5),Math.abs(y-.5)),fl=Math.hypot(((u*N*2+.5)%1)-.5,((v*N*2+.5)%1)-.5);return l<.04?1:fl<.12&&((Math.floor(u*N*2+.5)+Math.floor(v*N*2+.5))&1)?.8:0;};
HQ.royal=(c,w,h,g)=>hqPix(c,w,h,(u,v,o)=>{if(g)return;
 const ht=HQH.royal(u,v);mixc([10,22,72],[6,12,40],v+fbm(u,v,4,3,1301)*.3,o);if(ht>.5)mixc([200,150,50],[255,226,140],fbm(u,v,16,2,1303),o);});
// Rouge sang : rouge bonbon métallisé, voile sombre
HQ.bloodfade=(c,w,h,g)=>hqPix(c,w,h,(u,v,o)=>{if(g)return;
 const n=warp(u,v,2,5,1401,.8),fl=hqHash(Math.floor(u*512),Math.floor(v*512),3);
 mixc([250,44,54],[40,4,8],sstep(.3,.75,n*.6+u*.5),o);addc(o,255,180,180,(fl>.985?1:0)*.25);});
// Toxique : boue radioactive lumineuse
HQ.toxic=(c,w,h,g)=>hqPix(c,w,h,(u,v,o)=>{
 const n=warp(u,v,3,4,1501,.6),goo=sstep(.55,.6,n),bub=voro(u,v,12,1503,.9),b=sstep(.18,.12,bub.d1)*goo;
 if(g){o[0]=80*goo+120*b;o[1]=255*goo;o[2]=40*goo;return;}
 mixc([18,30,14],[8,14,8],fbm(u,v,8,3,1505),o);const s=(u*4+v*4)%1<.25&&!goo;if(s)mixc(o,[232,208,32],.85,o);mixc(o,[120,255,60],goo*.9,o);addc(o,220,255,200,b*.6);});
// Circuit : circuit imprimé, pistes, puces, vias
HQ.circuit=(c,w,h,g)=>{
 c.fillStyle=g?'#000':'#062a2c';c.fillRect(0,0,w,h);
 if(!g){hqPix(c,w,h,(u,v,o)=>{const n=fbm(u,v,16,3,1601);o[0]=6+n*10;o[1]=36+n*24;o[2]=40+n*24;});}
 const r=mkRng(1607),S=w/32;c.lineCap='round';c.lineJoin='round';
 for(let i=0;i<70;i++){let x=Math.floor(r(0,32))*S,y=Math.floor(r(0,32))*S;c.beginPath();c.moveTo(x,y);
  for(let k=0;k<4;k++){const L=Math.floor(r(1,6))*S,d=Math.floor(r(0,4));if(d===0)x+=L;else if(d===1)x-=L;else if(d===2)y+=L;else y-=L;const dg=Math.floor(r(0,2))*S;x+=dg*(r()<.5?1:-1);y+=dg;c.lineTo(x,y);}
  c.strokeStyle=g?'#28f0ff':'#c99a3a';c.lineWidth=g?S*.35:S*.28;c.stroke();if(!g){c.strokeStyle='rgba(255,230,160,.35)';c.lineWidth=S*.08;c.stroke();}
  c.fillStyle=g?'#bff':'#e0c070';c.beginPath();c.arc(x,y,S*.32,0,TAU);c.fill();c.fillStyle=g?'#28f0ff':'#062a2c';c.beginPath();c.arc(x,y,S*.13,0,TAU);c.fill();}
 for(let i=0;i<7;i++){const x=Math.floor(r(1,26))*S,y=Math.floor(r(1,26))*S,cw=Math.floor(r(3,6))*S,ch=Math.floor(r(2,5))*S;
  c.fillStyle=g?'rgba(40,240,255,.15)':'#121416';c.fillRect(x,y,cw,ch);if(!g){c.fillStyle='rgba(255,255,255,.06)';c.fillRect(x,y,cw,S*.2);}
  c.fillStyle=g?'#28f0ff':'#cfcfcf';for(let p=S*.5;p<cw;p+=S*.6){c.fillRect(x+p,y-S*.3,S*.25,S*.3);c.fillRect(x+p,y+ch,S*.25,S*.3);}
  if(!g){c.fillStyle='rgba(220,220,220,.5)';c.font=Math.round(S*.7)+'px monospace';c.fillText('SA-'+Math.floor(r(10,99)),x+S*.3,y+ch*.6);}}};
HQ.neonlines=(c,w,h,g)=>{const S=w/256;c.save();c.scale(S,S);PAINT.neonlines(c,256,256,g,mkRng(hashStr('neonlines')));c.restore();
 if(!g)hqOver(c,w,h,(u,v,o)=>{const n=fbm(u,v,8,3,1701);o[3]=n*30;o[0]=o[1]=o[2]=0;});};
// Océan : houle, écume, reflets
HQ.ocean=(c,w,h,g)=>hqPix(c,w,h,(u,v,o)=>{if(g)return;
 const n=warp(u,v,3,5,1801,.5),wv=Math.sin((v*8+n*3)*Math.PI*2),foam=sstep(.86,.97,wv)*sstep(.4,.6,fbm(u,v,16,3,1803));
 mixc([10,58,122],[82,200,240],sat(.3+wv*.25+n*.5-v*.25),o);mixc(o,[240,250,255],foam,o);});
// Dragon : écailles rouges, flammes dorées
HQ.flame=(c,w,h,g)=>hqPix(c,w,h,(u,v,o)=>{if(g)return;
 const sc=Math.pow(scaleAt(u,v,8).k,.5),n=warp(u,v,2,4,1901,.8),fl=sstep(.2,.9,v*.9+n*.6-.35);
 mixc([30,4,6],[170,20,14],sc,o);if(sc<.12)mixc(o,[230,170,60],sstep(.12,.02,sc)*.8,o);const fc=[0,0,0];hsl2rgb(.02+fl*.1,1,.35+fl*.3,fc);mixc(o,fc,sstep(.45,.75,fl),o);addc(o,255,240,160,Math.pow(fl,6)*.6);});
HQH.flame=(u,v)=>Math.pow(scaleAt(u,v,8).k,.5);
// Danger : bandes usées, peinture écaillée
HQ.hazard=(c,w,h,g)=>hqPix(c,w,h,(u,v,o)=>{if(g)return;
 const s=((u+v)*6)%1<.5,chip=sstep(.62,.66,fbm(u,v,8,5,2001));
 if(s){o[0]=236;o[1]=186;o[2]=28;}else{o[0]=o[1]=22;o[2]=24;}
 if(chip>0)mixc(o,[120,124,128],chip,o);shade(o,.88+fbm(u,v,32,3,2003)*.2);});
// Coucher de soleil : synthwave (soleil rayé, grille)
HQ.sunset=(c,w,h,g)=>hqPix(c,w,h,(u,v,o)=>{if(g)return;
 const sky=ramp([[0,'#1c0a40'],[.4,'#7a1e7a'],[.62,'#ff4a7a'],[.75,'#ffb048']]);sky(v,o);
 const d=Math.hypot(u-.5,(v-.55)*1.1);if(d<.22&&v<.62&&!(v>.42&&((v*60)%1)<(v-.42)*3))mixc([255,240,120],[255,90,140],sat((v-.33)/.29),o);
 if(v>.62){mixc([20,4,40],[60,10,70],v,o);const gx=Math.abs(((u-.5)/(v-.55)*.6*8)%1-.5),gy=Math.abs((1/(v-.58)*.6)%1-.5);if(gx>.46||gy>.44)mixc(o,[255,80,220],.9,o);}});
// Étoilé (ciel de nuit) : on garde le dessin, en mieux défini
// Nuages : cumulus volumineux
HQ.clouds=(c,w,h,g)=>hqPix(c,w,h,(u,v,o)=>{if(g)return;
 const n=warp(u,v,3,6,2101,.4),k=sstep(.45,.62,n),top=sstep(.5,.7,fbm(u,v-.01,6,4,2101));
 mixc([40,120,220],[150,205,255],v,o);mixc(o,[250,252,255],k,o);shade(o,1-k*(1-top)*.18);});

/* ---------- skins « style CS » refaits ---------- */
// Trempe (acier cémenté) : bleus et ors au hasard de la chauffe
HQ.cs_hardened=(c,w,h,g)=>hqPix(c,w,h,(u,v,o)=>{if(g)return;
 const n=warp(u,v,2,5,2201,1.1),m=warp(u,v,3,4,2203,.8);
 mixc([128,134,142],[48,92,200],sstep(.42,.62,n),o);mixc(o,[226,184,70],sstep(.55,.7,m)*.85,o);shade(o,.82+fbm(u,v,24,3,2205)*.3);});
// Doppler : volutes rouge-violet, paillettes
HQ.cs_doppler=(c,w,h,g)=>hqPix(c,w,h,(u,v,o)=>{if(g)return;
 const n=warp(u,v,2,5,2301,1.4),b=Math.sin(n*16);hsl2rgb(.86+b*.07+n*.1,.85,.12+sat(b)*.32,o);
 const sp=hqHash(Math.floor(u*400),Math.floor(v*400),2307);if(sp>.992)addc(o,255,170,240,.8);});
// Marbre flamme : rouge, or, bleu fondus
HQ.cs_mfade=(c,w,h,g)=>hqPix(c,w,h,(u,v,o)=>{if(g)return;
 const n=warp(u,v,2,5,2401,1),t=sat(u*.8+(n-.5)*1.2+.1);ramp([[0,'#ff2030'],[.45,'#ffc020'],[.6,'#ffe070'],[1,'#2050ff']])(t,o);
 shade(o,.8+.3*Math.abs(Math.sin(n*14)));});
// Abattoir : rose et cramoisi en volutes
HQ.cs_slaughter=(c,w,h,g)=>hqPix(c,w,h,(u,v,o)=>{if(g)return;
 const n=warp(u,v,2,5,2501,1.2);mixc([236,150,158],[150,12,30],sstep(.3,.55,n),o);addc(o,255,240,240,Math.pow(1-Math.abs(Math.sin(n*30)),40)*.6);});
// Dégradé solaire : dégradé métal + paillettes
HQ.cs_fade=(c,w,h,g)=>hqPix(c,w,h,(u,v,o)=>{if(g)return;
 ramp([[0,'#ffd23a'],[.35,'#ff5aa8'],[.7,'#8a4bff'],[1,'#3a6aff']])(sat(u*.7+(1-v)*.5-.1+fbm(u,v,4,3,2601)*.15),o);
 const sp=hqHash(Math.floor(u*512),Math.floor(v*512),2603);if(sp>.99)addc(o,255,255,255,.35);});

/* ---------- surimpression (alpha) pixel par pixel ---------- */
function hqOver(c,w,h,fn){const img=c.getImageData(0,0,w,h),d=img.data,o=[0,0,0,0];
 for(let y=0;y<h;y++)for(let x=0;x<w;x++){o[3]=0;fn(x/w,y/h,o);if(o[3]<=0)continue;const i=(y*w+x)*4,a=o[3]/255;d[i]+= (o[0]-d[i])*a;d[i+1]+=(o[1]-d[i+1])*a;d[i+2]+=(o[2]-d[i+2])*a;}
 c.putImageData(img,0,0);}

/* ---------- finition commune : grain, voile de vernis, micro-rayures ---------- */
let _hqSmudge=null;
function hqFinish(c,w,h,kind){
 const s=hashStr(kind)&1023;
 if(!_hqSmudge){_hqSmudge=document.createElement('canvas');_hqSmudge.width=_hqSmudge.height=128;hqPix(_hqSmudge.getContext('2d'),128,128,(u,v,o)=>{const n=fbm(u,v,4,4,77);o[0]=o[1]=o[2]=n*255;});}
 // traces de manipulation (taches douces) : même motif décalé selon le skin
 c.save();c.globalCompositeOperation='overlay';c.globalAlpha=.16;const ox=(s%7)/7*w,oy=(s%5)/5*h;
 for(const [dx,dy] of [[0,0],[-w,0],[0,-h],[-w,-h]])c.drawImage(_hqSmudge,ox+dx,oy+dy,w,h);c.restore();
 const img=c.getImageData(0,0,w,h),d=img.data;let x=s*9973|0;
 for(let i=0;i<d.length;i+=4){x^=x<<13;x^=x>>>17;x^=x<<5;const gr=((x&255)-128)*.04;d[i]+=gr;d[i+1]+=gr;d[i+2]+=gr;}
 c.putImageData(img,0,0);
 const r=mkRng(s+3);c.lineWidth=.7;
 for(let i=0;i<70;i++){c.strokeStyle='rgba(255,255,255,'+r(.03,.12)+')';const x0=r(0,w),y0=r(0,h),a=r(-.3,.3),L=r(8,50);c.beginPath();c.moveTo(x0,y0);c.lineTo(x0+Math.cos(a)*L,y0+Math.sin(a)*L);c.stroke();}
}

/* ---------- illustrations refaites ---------- */
// Loup hurleur : silhouette de loup qui hurle devant la lune, ciel de braise
HQ.cs_howl=(c,w,h,g)=>{if(g){c.fillStyle='#000';c.fillRect(0,0,w,h);return;}
 hqPix(c,w,h,(u,v,o)=>{const n=warp(u,v,2,5,2701,.9),f=sat(v*1.1-.1+(n-.5)*.9);ramp([[0,'#3a0606'],[.35,'#b0180c'],[.7,'#ff6a10'],[1,'#ffd040']])(f,o);
  const ember=hqHash(Math.floor(u*300),Math.floor(v*300),2703);if(ember>.996)addc(o,255,220,120,.9);});
 const X=x=>x*w,Y=y=>y*h;
 const mg=c.createRadialGradient(X(.42),Y(.3),0,X(.42),Y(.3),X(.32));mg.addColorStop(0,'rgba(255,240,200,.95)');mg.addColorStop(.55,'rgba(255,220,150,.85)');mg.addColorStop(.6,'rgba(255,190,90,.35)');mg.addColorStop(1,'rgba(255,160,60,0)');c.fillStyle=mg;c.fillRect(0,0,w,h);
 c.fillStyle='#120406';c.beginPath();c.moveTo(X(.22),Y(1));
 c.bezierCurveTo(X(.2),Y(.78),X(.24),Y(.6),X(.3),Y(.48));c.quadraticCurveTo(X(.33),Y(.4),X(.36),Y(.36));
 c.lineTo(X(.37),Y(.16));c.lineTo(X(.45),Y(.31));                         // oreille
 c.quadraticCurveTo(X(.52),Y(.27),X(.58),Y(.24));c.lineTo(X(.8),Y(.06));c.quadraticCurveTo(X(.84),Y(.06),X(.83),Y(.1));  // museau levé
 c.lineTo(X(.69),Y(.24));c.lineTo(X(.79),Y(.25));c.lineTo(X(.66),Y(.33));                                             // gueule ouverte
 c.quadraticCurveTo(X(.6),Y(.4),X(.58),Y(.46));
 for(let i=0;i<6;i++){const y=.48+i*.085;c.lineTo(X(.64-i*.012),Y(y+.03));c.lineTo(X(.57-i*.01),Y(y+.06));}
 c.lineTo(X(.6),Y(1));c.closePath();c.fill();
 c.fillStyle='#ffcc30';c.beginPath();c.ellipse(X(.53),Y(.3),X(.018),Y(.008),-.6,0,TAU);c.fill();
 c.strokeStyle='rgba(255,150,60,.55)';c.lineWidth=w*.006;c.beginPath();c.moveTo(X(.3),Y(.5));c.bezierCurveTo(X(.25),Y(.65),X(.24),Y(.82),X(.22),Y(1));c.stroke();};
// Graffiti : mur de béton, aplats bombés avec coulures, tag en relief
HQ.graffiti=(c,w,h,g)=>{if(g){c.fillStyle='#000';c.fillRect(0,0,w,h);return;}
 hqPix(c,w,h,(u,v,o)=>{const n=fbm(u,v,8,5,2801),l=60+n*50;o[0]=l;o[1]=l*1.02;o[2]=l*1.08;if(hqHash(Math.floor(u*200),Math.floor(v*200),5)>.97)shade(o,.7);});
 const r=mkRng(2803),cols=['#ff2d6f','#ffd23a','#2ad6ff','#7dff4a','#b45cff','#ff7a1a'];
 const spray=(x,y,R,col)=>{const gg=c.createRadialGradient(x,y,R*.6,x,y,R);gg.addColorStop(0,col);gg.addColorStop(1,col+'00');c.fillStyle=gg;c.beginPath();c.arc(x,y,R,0,TAU);c.fill();
  c.strokeStyle=col;c.lineCap='round';for(let k=0;k<3;k++){const dx=x+r(-R*.6,R*.6),L=r(R*.4,R*1.4);c.lineWidth=r(2,4)*w/512;c.beginPath();c.moveTo(dx,y+R*.5);c.lineTo(dx,y+R*.5+L);c.stroke();c.beginPath();c.arc(dx,y+R*.5+L,c.lineWidth*.9,0,TAU);c.fillStyle=col;c.fill();}
  for(let k=0;k<40;k++){c.fillStyle=col;c.globalAlpha=r(.3,.9);c.fillRect(x+r(-R*1.5,R*1.5),y+r(-R*1.5,R*1.5),1.5*w/512,1.5*w/512);}c.globalAlpha=1;};
 for(let i=0;i<9;i++)spray(r(0,w),r(0,h),r(.07,.14)*w,cols[i%6]);
 c.save();c.translate(w*.5,h*.55);c.rotate(-.15);c.font='900 '+Math.round(w*.3)+'px Impact, Arial Black, sans-serif';c.textAlign='center';c.textBaseline='middle';c.lineJoin='round';
 c.fillStyle='#14141a';c.fillText('SA',w*.025,w*.025);c.lineWidth=w*.03;c.strokeStyle='#14141a';c.strokeText('SA',0,0);
 const tg=c.createLinearGradient(0,-w*.15,0,w*.15);tg.addColorStop(0,'#ffe14a');tg.addColorStop(.5,'#ff5a2a');tg.addColorStop(1,'#ff2d8f');c.fillStyle=tg;c.fillText('SA',0,0);
 c.lineWidth=w*.008;c.strokeStyle='#fff';c.strokeText('SA',0,0);c.restore();
 c.fillStyle='#fff';for(let i=0;i<5;i++)star(c,r(0,w),r(0,h),w*.025,w*.008,'#ffffff',r(0,1));};

/* ---------- textures : couleur 512 px, rugosité, relief ---------- */
skinTex=function(kind,glow){
 return cached('hq_'+kind+(glow?'_g':'_c'),()=>canvasTex(HQS,HQS,(c,w,h)=>{
  if(HQ[kind])HQ[kind](c,w,h,!!glow);
  else{c.save();c.scale(w/256,h/256);(PAINT[kind]||PAINT.checker)(c,256,256,!!glow,mkRng(hashStr(kind)));c.restore();}
  if(!glow&&!/^anim_/.test(kind))hqFinish(c,w,h,kind);
 },true,{s:1}));
};
// rugosité : vernis plus lisse au centre des motifs, usure et traces de doigts plus mates
function skinRough(kind){
 return cached('hqr_'+kind,()=>canvasTex(256,256,(c,w,h)=>{const s=hashStr(kind)&1023;
  hqPix(c,w,h,(u,v,o)=>{const n=fbm(u,v,6,4,s+11),wear=sstep(.6,.75,fbm(u,v,3,4,s+17)),l=150+n*70+wear*35;o[0]=o[1]=o[2]=l;});
  const r=mkRng(s);c.lineWidth=.8;for(let i=0;i<90;i++){c.strokeStyle='rgba(255,255,255,'+r(.2,.5)+')';const x=r(0,w),y=r(0,h),a=r(-.4,.4),L=r(6,30);c.beginPath();c.moveTo(x,y);c.lineTo(x+Math.cos(a)*L,y+Math.sin(a)*L);c.stroke();}
 },true,{s:1,noSRGB:true}));
}
function skinRelief(kind){
 if(!HQH[kind])return null;
 return cached('hqn_'+kind,()=>{const t=canvasTex(256,256,(c,w,h)=>hqPix(c,w,h,(u,v,o)=>{const l=sat(HQH[kind](u,v))*255;o[0]=o[1]=o[2]=l;}),true,{s:1,noSRGB:true});return autoNormal(t,6);});
}
// les matériaux d'arme reçoivent rugosité et relief
{const _gunMats=gunMats;
 gunMats=function(sk,w){const M=_gunMats(sk,w);
  if(sk&&sk.tex&&!sk.anim&&M.body&&M.body.userData.skinned){
   const fin=FIN[sk.fin||'gloss'],rm=skinRough(sk.tex),nm=skinRelief(sk.tex);
   for(const m of [M.body,M.acc]){if(!m)continue;if(m.map)m.map.repeat.set(1.35,1.35);m.roughnessMap=rm;m.roughness=Math.min(1,(m===M.acc?fin.r+.1:fin.r)*1.5);
    if(nm&&cfg.gfx>=1){m.normalMap=nm;m.normalScale=new THREE.Vector2(.9,.9);}m.needsUpdate=true;}
  }
  return M;};
}
// pastilles du menu : petite peinture dédiée (calculer 60 textures 512 px d'un coup figerait le menu)
skinSwatch=function(i){
 const s=SKINS[i];if(s.def)return 'linear-gradient(135deg,#8a8f98 50%,#454a52 50%)';
 if(!s.tex)return 'linear-gradient(135deg,'+s.b+','+s.a+')';
 if(_prevCache[i])return _prevCache[i];
 try{const cv=document.createElement('canvas');cv.width=cv.height=64;const x=cv.getContext('2d');
  if(HQ[s.tex])HQ[s.tex](x,64,64,false);else{x.scale(.25,.25);(PAINT[s.tex]||PAINT.checker)(x,256,256,false,mkRng(hashStr(s.tex)));}
  _prevCache[i]='url('+cv.toDataURL()+') center/cover';}catch(e){_prevCache[i]='#888';}
 return _prevCache[i];
};
