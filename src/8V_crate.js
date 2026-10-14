/* =====================================================================
   OUVERTURE DE CAISSE, VERSION SOIGNÉE
   - Vraie caisse : coque métal brossé, coins renforcés, poignées,
     loquets, couvercle sur charnières, emblème lumineux.
   - Étapes : chute + poussière, suspense (les loquets sautent un par un,
     la lumière fuit par les joints en changeant de couleur), ouverture,
     révélation sur un socle holographique.
   - La révélation change selon la rareté :
     Commun : couvercle qui s'ouvre, petite lueur.
     Rare : faisceau bleu, étincelles.
     Épique : faisceau + rayons, tourbillon violet, confettis.
     Légendaire / Exclusif : le couvercle est soufflé, rayons dorés,
     pluie de pièces, onde de choc, ralenti de caméra.
   Remplace startBoxOpen / bxLoop / bxClear (86_meta_ui.js).
   ===================================================================== */
const BX2={env:null,tex:{}};
function bx2Grad(key,inner,outer){
 if(BX2.tex[key])return BX2.tex[key];
 return BX2.tex[key]=canvasTex(128,128,(c,w,h)=>{const g=c.createRadialGradient(64,64,0,64,64,64);g.addColorStop(0,inner);g.addColorStop(1,outer);c.fillStyle=g;c.fillRect(0,0,w,h);});
}
// rayon : dégradé doux (bord transparent) au lieu d'un aplat
function bx2RayTex(){
 if(BX2.tex.ray)return BX2.tex.ray;
 return BX2.tex.ray=canvasTex(64,256,(c,w,h)=>{
  const g=c.createLinearGradient(0,0,0,h);g.addColorStop(0,'rgba(255,255,255,0)');g.addColorStop(.5,'rgba(255,255,255,1)');g.addColorStop(1,'rgba(255,255,255,0)');
  c.fillStyle=g;c.fillRect(0,0,w,h);c.globalCompositeOperation='destination-in';
  const g2=c.createLinearGradient(0,0,w,0);g2.addColorStop(0,'rgba(0,0,0,0)');g2.addColorStop(.5,'rgba(0,0,0,1)');g2.addColorStop(1,'rgba(0,0,0,0)');c.fillStyle=g2;c.fillRect(0,0,w,h);
 });
}
function bx2PanelTex(acc,prem){
 const key='pan'+acc+prem;if(BX2.tex[key])return BX2.tex[key];
 return BX2.tex[key]=canvasTex(512,256,(c,w,h)=>{
  c.fillStyle='#1c2333';c.fillRect(0,0,w,h);
  // métal brossé
  for(let i=0;i<900;i++){c.fillStyle='rgba(255,255,255,'+(Math.random()*.05)+')';c.fillRect(0,Math.random()*h,w,1);}
  // panneau creux
  c.strokeStyle='rgba(0,0,0,.6)';c.lineWidth=6;c.strokeRect(26,26,w-52,h-52);c.strokeStyle='rgba(255,255,255,.12)';c.lineWidth=2;c.strokeRect(30,30,w-60,h-60);
  // bandes d'avertissement
  c.save();c.beginPath();c.rect(30,h-62,w-60,26);c.clip();for(let x=-40;x<w;x+=34){c.fillStyle=acc;c.beginPath();c.moveTo(x,h-36);c.lineTo(x+17,h-36);c.lineTo(x+43,h-62);c.lineTo(x+26,h-62);c.fill();}c.restore();
  // emblème : chevron dans un écu
  c.save();c.translate(w/2,108);c.fillStyle='rgba(0,0,0,.45)';c.beginPath();c.moveTo(-46,-50);c.lineTo(46,-50);c.lineTo(46,8);c.lineTo(0,52);c.lineTo(-46,8);c.closePath();c.fill();
  c.strokeStyle=acc;c.lineWidth=5;c.stroke();c.fillStyle=acc;c.beginPath();c.moveTo(-28,-18);c.lineTo(0,6);c.lineTo(28,-18);c.lineTo(28,-2);c.lineTo(0,22);c.lineTo(-28,-2);c.fill();
  if(prem){c.beginPath();for(let i=0;i<5;i++){const a=-Math.PI/2+i*TAU/5,b=a+TAU/10;c.lineTo(Math.cos(a)*12,-32+Math.sin(a)*12);c.lineTo(Math.cos(b)*5,-32+Math.sin(b)*5);}c.fill();}
  c.restore();
  c.font='bold 22px Bahnschrift,Arial';c.textAlign='left';c.fillStyle='rgba(255,255,255,.55)';c.fillText(prem?'PREMIUM':'STANDARD',44,58);
  c.textAlign='right';c.fillText('SA-'+(prem?'77':'12'),w-44,58);
 });
}
function bx2CoinTex(){
 if(BX2.tex.coin)return BX2.tex.coin;
 return BX2.tex.coin=canvasTex(128,128,(c,w,h)=>{
  const g=c.createRadialGradient(50,46,6,64,64,64);g.addColorStop(0,'#fff3b0');g.addColorStop(.55,'#f2b928');g.addColorStop(1,'#a8700a');c.fillStyle=g;c.fillRect(0,0,w,h);
  c.strokeStyle='rgba(120,70,0,.7)';c.lineWidth=6;c.beginPath();c.arc(64,64,50,0,TAU);c.stroke();
  c.fillStyle='rgba(120,70,0,.75)';c.beginPath();for(let i=0;i<5;i++){const a=-Math.PI/2+i*TAU/5,b=a+TAU/10;c.lineTo(64+Math.cos(a)*32,64+Math.sin(a)*32);c.lineTo(64+Math.cos(b)*13,64+Math.sin(b)*13);}c.fill();
  c.fillStyle='rgba(255,255,230,.6)';c.beginPath();for(let i=0;i<5;i++){const a=-Math.PI/2+i*TAU/5,b=a+TAU/10;c.lineTo(62+Math.cos(a)*30,62+Math.sin(a)*30);c.lineTo(62+Math.cos(b)*12,62+Math.sin(b)*12);}c.fill();
 });
}
let _bx2CoinGeo=null;
function bx2Coin(r){
 if(!_bx2CoinGeo)_bx2CoinGeo=new THREE.CylinderGeometry(1,1,.16,28);
 if(!BX2.coinM){const face=new THREE.MeshStandardMaterial({map:bx2CoinTex(),metalness:.85,roughness:.28,emissive:0x5a3a00,emissiveIntensity:.35}),rim=new THREE.MeshStandardMaterial({color:0xd9a520,metalness:1,roughness:.3,emissive:0x4a3000,emissiveIntensity:.3});BX2.coinM=[rim,face,face];}
 const m=new THREE.Mesh(_bx2CoinGeo,BX2.coinM);m.scale.set(r,r,r);return m;
}
/* ---------- décor fixe : socle, sol qui s'estompe, halo ---------- */
function bx2Env(){
 if(BX2.env)return;
 const s=BXS.s,g=new THREE.Group();
 if(BXS.floor)BXS.floor.visible=false;
 const fl=new THREE.Mesh(new THREE.CircleGeometry(4.6,64),new THREE.MeshStandardMaterial({color:C(0x0d1424),roughness:.3,metalness:.8,transparent:true,alphaMap:bx2Grad('fade','#fff','#000')}));fl.rotation.x=-Math.PI/2;g.add(fl);
 // socle hexagonal à deux étages avec liseré lumineux
 const ped=new THREE.MeshStandardMaterial({color:C(0x1a2236),metalness:.85,roughness:.32});
 const p1=new THREE.Mesh(new THREE.CylinderGeometry(1.75,1.9,.16,6),ped);p1.position.y=.08;p1.rotation.y=Math.PI/6;g.add(p1);
 const p2=new THREE.Mesh(new THREE.CylinderGeometry(1.45,1.55,.1,6),ped);p2.position.y=.21;p2.rotation.y=Math.PI/6;g.add(p2);
 const rimM=new THREE.MeshBasicMaterial({color:0x4aa3ff,toneMapped:false});
 const rim=new THREE.Mesh(new THREE.TorusGeometry(1.62,.018,6,6),rimM);rim.rotation.x=Math.PI/2;rim.rotation.z=Math.PI/6;rim.position.y=.165;g.add(rim);
 BX2.rimM=rimM;
 // halo derrière la caisse
 const halo=new THREE.Sprite(new THREE.SpriteMaterial({map:bx2Grad('halo','rgba(255,255,255,.9)','rgba(255,255,255,0)'),color:0x4aa3ff,transparent:true,opacity:.35,depthWrite:false,blending:THREE.AdditiveBlending}));halo.scale.set(5.5,5.5,1);halo.position.set(0,1.6,-2.5);g.add(halo);BX2.halo=halo;
 // poussières qui flottent
 const n=90,pos=new Float32Array(n*3);for(let i=0;i<n;i++){pos[i*3]=rand(-5,5);pos[i*3+1]=rand(0,4.5);pos[i*3+2]=rand(-4,2);}
 const pg=new THREE.BufferGeometry();pg.setAttribute('position',new THREE.BufferAttribute(pos,3));
 BX2.motes=new THREE.Points(pg,new THREE.PointsMaterial({color:0x9fc8ff,size:.03,transparent:true,opacity:.5,depthWrite:false,blending:THREE.AdditiveBlending}));g.add(BX2.motes);
 if(BXS.ring)BXS.ring.position.y=.27;
 s.add(g);BX2.env=g;
 BXS.s.fog=new THREE.Fog(0x070b14,9,22);
}
/* ---------- la caisse ---------- */
function bx2Crate(type){
 const prem=type==='prem',acc=BOXES[type].c,col=new THREE.Color(acc);
 const g=new THREE.Group();
 const shell=new THREE.MeshStandardMaterial({color:C(prem?0x2a2418:0x222b3d),metalness:.82,roughness:.36});
 const panel=new THREE.MeshStandardMaterial({map:bx2PanelTex(acc,prem),metalness:.7,roughness:.42});
 const trim=new THREE.MeshStandardMaterial({color:prem?C(0xe0b040):C(0x9aa6b8),metalness:1,roughness:.22});
 const dark=new THREE.MeshStandardMaterial({color:C(0x0b0e14),metalness:.6,roughness:.6});
 const glowM=new THREE.MeshBasicMaterial({color:col,toneMapped:false,transparent:true,opacity:.85});
 const W=1.7,H=.9,D=1.1;
 // corps
 const body=new THREE.Group();g.add(body);
 body.add(rb(W,H,D,shell,0,H/2,0,.06));
 const front=new THREE.Mesh(new THREE.PlaneGeometry(W-.24,H-.18),panel);front.position.set(0,H/2+.01,D/2+.006);body.add(front);
 const back=front.clone();back.position.z=-D/2-.006;back.rotation.y=Math.PI;body.add(back);
 // nervures et coins renforcés
 body.add(rb(W+.04,.08,D+.04,trim,0,.06,0,.02),rb(W+.04,.06,D+.04,trim,0,H-.03,0,.02));
 for(const sx of [-1,1])for(const sz of [-1,1]){body.add(rb(.2,.2,.2,trim,sx*(W/2-.06),.1,sz*(D/2-.06),.04),rb(.2,.16,.2,trim,sx*(W/2-.06),H-.08,sz*(D/2-.06),.04));}
 // poignées latérales
 for(const sx of [-1,1]){const hd=new THREE.Mesh(new THREE.TorusGeometry(.14,.025,8,16,Math.PI),dark);hd.position.set(sx*(W/2+.02),H*.62,0);hd.rotation.set(0,sx*Math.PI/2,Math.PI);body.add(hd);body.add(rb(.04,.08,.34,trim,sx*(W/2+.01),H*.62,0,.015));}
 // joint lumineux entre le corps et le couvercle
 const seam=new THREE.Mesh(new THREE.BoxGeometry(W-.02,.035,D-.02),new THREE.MeshBasicMaterial({color:col,transparent:true,opacity:0,toneMapped:false}));seam.position.y=H+.005;g.add(seam);
 // intérieur lumineux (vu quand le couvercle s'ouvre)
 const inner=new THREE.Mesh(new THREE.PlaneGeometry(W-.16,D-.16),new THREE.MeshBasicMaterial({color:col,transparent:true,opacity:0,toneMapped:false}));inner.rotation.x=-Math.PI/2;inner.position.y=H-.04;g.add(inner);
 // loquets (2 devant)
 const latches=[];
 for(const sx of [-.42,.42]){const L=new THREE.Group();L.position.set(sx,H-.02,D/2+.03);
  L.add(rb(.16,.1,.05,trim,0,-.02,0,.015));const lev=new THREE.Group();lev.add(rb(.12,.2,.035,dark,0,-.1,.02,.012),rb(.13,.04,.04,trim,0,-.19,.03,.01));L.add(lev);
  const led=new THREE.Mesh(new THREE.SphereGeometry(.022,8,6),new THREE.MeshBasicMaterial({color:0xff3344,toneMapped:false}));led.position.set(0,.04,.03);L.add(led);
  L.userData={lev,led,open:0};body.add(L);latches.push(L);}
 // couvercle sur charnières (pivot sur l'arête arrière)
 const lid=new THREE.Group();lid.position.set(0,H,-D/2);g.add(lid);
 const lidIn=new THREE.Group();lidIn.position.z=D/2;lid.add(lidIn);
 lidIn.add(rb(W+.02,.2,D+.02,shell,0,.1,0,.06),rb(W-.3,.06,D-.3,shell,0,.22,0,.03),rb(W+.06,.05,D+.06,trim,0,.02,0,.02));
 for(const sx of [-1,1])for(const sz of [-1,1])lidIn.add(rb(.2,.16,.2,trim,sx*(W/2-.06),.11,sz*(D/2-.06),.04));
 const emb=new THREE.Mesh(new THREE.CircleGeometry(.2,6),glowM);emb.rotation.x=-Math.PI/2;emb.rotation.z=Math.PI/6;emb.position.y=.256;lidIn.add(emb);
 const embR=new THREE.Mesh(new THREE.RingGeometry(.22,.26,6),new THREE.MeshStandardMaterial({color:trim.color,metalness:1,roughness:.2}));embR.rotation.copy(emb.rotation);embR.position.y=.257;lidIn.add(embR);
 for(const sx of [-.55,.55])lid.add(rb(.22,.1,.1,trim,sx,.02,-.02,.03));   // charnières
 // fuites de lumière par les joints (rayons fins le long des arêtes)
 const leaks=new THREE.Group();g.add(leaks);
 const rayM=new THREE.MeshBasicMaterial({map:bx2RayTex(),color:col,transparent:true,opacity:0,blending:THREE.AdditiveBlending,depthWrite:false,side:THREE.DoubleSide,toneMapped:false});
 for(let i=0;i<10;i++){const r=new THREE.Mesh(new THREE.PlaneGeometry(.12,1.6),rayM);const a=i/10*TAU;r.position.set(Math.cos(a)*.75,H+.3,Math.sin(a)*.5);r.rotation.set(0,-a,Math.cos(a)*.6);leaks.add(r);}
 g.traverse(o=>{if(o.isMesh)o.castShadow=false;});
 g.userData={body,lid,seam,inner,latches,leaks,rayM,glowM,H};
 return g;
}
/* ---------- départ ---------- */
startBoxOpen=function(type){
 initAudio();bxInit();if(!BXS.r)return;
 const res=openBox(type);if(!res){sfx('deny');uiToast('Pas assez de pièces');return;}
 refreshProfile();buildBoxesTab();
 bx2Env();
 BXS.type=type;BXS.res=res;BXS.t=0;BXS.run=true;BXS.burst=false;BXS.shown=false;BXS.sq=-1;BXS.pulse=0;BXS.hit=false;BXS.shake=0;BXS.latchN=0;
 $('boxov').classList.remove('rarq0','rarq1','rarq2','rarq3','rarq4');BXS.last=performance.now()/1000;
 bxClear();
 const col=new THREE.Color(BOXES[type].c);
 BXS.crate=bx2Crate(type);BXS.crate.position.y=6.5;BXS.crate.rotation.y=-2.6;BXS.s.add(BXS.crate);
 BXS.lid=BXS.crate.userData.lid;BXS.seamM=BXS.crate.userData.seam;
 BXS.lightP.color.copy(col);BXS.lightP.intensity=0;BXS.lightP.position.set(0,1.4,1.6);
 BXS.ring.material.color.copy(col);BX2.rimM.color.copy(col);BX2.halo.material.color.copy(col);BX2.halo.material.opacity=.25;
 $('boxTxt').innerHTML='<div class="rar" style="color:'+BOXES[type].c+'">OUVERTURE…</div>';$('boxAgain').style.display='none';$('boxClose').style.display='none';
 $('boxov').classList.add('show');
 sfx('throw');bxLoop();
};
bxClear=function(){
 const s=BXS.s;for(const o of [BXS.crate,BXS.item,BXS.parts,BXS.beam,BXS.rays,BXS.sw,BXS.dustR,BXS.coins,BXS.glow,BXS.holo,BXS.swirl,BXS.lidFree])if(o)s.remove(o);BXS.lidFree=null;
 BXS.crate=BXS.item=BXS.parts=BXS.beam=BXS.rays=BXS.sw=BXS.dustR=BXS.coins=BXS.glow=BXS.holo=BXS.swirl=null;BXS.lid=null;BXS.rig=null;
};
// pièces : une pile qui tourne + pluie de pièces pour les gros gains
const _bxItemBase=bxItemObject;
bxItemObject=function(){
 const it=BXS.res.item;
 if(it.t!=='coins')return _bxItemBase();
 const g=new THREE.Group(),big=bx2Coin(.42);big.rotation.x=Math.PI/2;g.add(big);
 for(let i=0;i<4;i++){const c=bx2Coin(.24);c.position.set(Math.cos(i*1.7)*.62,Math.sin(i*2.3)*.25-.1,Math.sin(i*1.7)*.3-.1);c.rotation.set(Math.PI/2+rand(-.5,.5),rand(-.6,.6),0);c.userData.spin=rand(1,3);g.add(c);}
 return g;
};
function bx2Burst(){
 const res=BXS.res,q=res.q,col=new THREE.Color(rcol(q)),s=BXS.s,U=BXS.crate.userData;
 BXS.burst=true;BXS.crate.rotation.z=0;BXS.crate.rotation.x=0;BXS.crate.position.y=0;
 sfx(q>=2?'win':'pop');sfx('bang',undefined,undefined,q>=3?.6:.25);
 BXS.lid.userData.blast=q>=3;
 if(q>=3){BXS.lid.userData.v=V3(rand(-.6,.6),6.5,-2.5);BXS.lid.userData.w=V3(rand(-5,-3),rand(-2,2),rand(-2,2));
  // le couvercle part : on le détache du pivot dans la scène
  BXS.crate.updateMatrixWorld(true);const m=BXS.lid.matrixWorld.clone();BXS.crate.remove(BXS.lid);s.add(BXS.lid);m.decompose(BXS.lid.position,BXS.lid.quaternion,BXS.lid.scale);BXS.lidFree=BXS.lid;}
 else BXS.lidFree=null;
 // étincelles
 const n=60+q*60,pos=new Float32Array(n*3);BXS.partV=[];
 for(let i=0;i<n;i++){pos[i*3]=rand(-.5,.5);pos[i*3+1]=1;pos[i*3+2]=rand(-.3,.3);const a=rand(0,TAU),sp=rand(1,2.5+q);BXS.partV.push(V3(Math.cos(a)*sp,rand(2,5+q),Math.sin(a)*sp*.6));}
 const pg=new THREE.BufferGeometry();pg.setAttribute('position',new THREE.BufferAttribute(pos,3));
 BXS.parts=new THREE.Points(pg,new THREE.PointsMaterial({color:col,size:.07+q*.015,map:GLOW.white,transparent:true,opacity:1,blending:THREE.AdditiveBlending,depthWrite:false}));s.add(BXS.parts);
 // faisceau (rare et +)
 if(q>=1){const bm=new THREE.Mesh(new THREE.CylinderGeometry(.55+q*.12,.9+q*.15,14,32,1,true),new THREE.MeshBasicMaterial({map:bx2RayTex(),color:col,transparent:true,opacity:.0,blending:THREE.AdditiveBlending,side:THREE.DoubleSide,depthWrite:false,toneMapped:false}));bm.position.y=7;s.add(bm);BXS.beam=bm;}
 // rayons tournants (épique et +)
 if(q>=2){const rays=new THREE.Group(),rm=new THREE.MeshBasicMaterial({map:bx2RayTex(),color:col,transparent:true,opacity:.0,blending:THREE.AdditiveBlending,depthWrite:false,side:THREE.DoubleSide,toneMapped:false});
  const nr=q>=3?16:10;for(let i=0;i<nr;i++){const pl=new THREE.Mesh(new THREE.PlaneGeometry(.5+Math.random()*.5,10),rm);pl.rotation.z=i/nr*Math.PI+rand(-.05,.05);rays.add(pl);}
  rays.position.set(0,2.3,-1.2);rays.userData.m=rm;s.add(rays);BXS.rays=rays;}
 // tourbillon (épique et +)
 if(q>=2){const sw=new THREE.Group();for(let i=0;i<3;i++){const r=new THREE.Mesh(new THREE.TorusGeometry(.7+i*.18,.012,6,48),new THREE.MeshBasicMaterial({color:col,transparent:true,opacity:.7,blending:THREE.AdditiveBlending,depthWrite:false,toneMapped:false}));r.rotation.x=Math.PI/2+rand(-.5,.5);r.rotation.y=rand(-.5,.5);sw.add(r);}sw.position.y=2.3;s.add(sw);BXS.swirl=sw;}
 // onde de choc au sol
 const sw=new THREE.Mesh(new THREE.RingGeometry(.9,1,64),new THREE.MeshBasicMaterial({color:col,transparent:true,opacity:.9,side:THREE.DoubleSide,blending:THREE.AdditiveBlending,depthWrite:false,toneMapped:false}));sw.rotation.x=-Math.PI/2;sw.position.y=.3;s.add(sw);BXS.sw=sw;
 // lueur derrière l'objet + socle holographique
 BXS.glow=new THREE.Sprite(new THREE.SpriteMaterial({map:bx2Grad('halo','rgba(255,255,255,.9)','rgba(255,255,255,0)'),color:col,transparent:true,opacity:0,depthWrite:false,blending:THREE.AdditiveBlending}));BXS.glow.scale.set(3.2,3.2,1);BXS.glow.position.set(0,2.3,-.4);s.add(BXS.glow);
 const holo=new THREE.Group();for(let i=0;i<2;i++){const r=new THREE.Mesh(new THREE.RingGeometry(.55+i*.14,.6+i*.14,48),new THREE.MeshBasicMaterial({color:col,transparent:true,opacity:.6,side:THREE.DoubleSide,blending:THREE.AdditiveBlending,depthWrite:false,toneMapped:false}));r.rotation.x=-Math.PI/2;holo.add(r);}holo.position.y=1.45;s.add(holo);BXS.holo=holo;
 // pluie de pièces (légendaire, ou gros gain en pièces)
 if(q>=3||res.item.t==='coins'&&res.item.n>=300){const cg=new THREE.Group();BXS.coinV=[];const nc=q>=3?40:18;for(let i=0;i<nc;i++){const c=bx2Coin(.07);c.position.set(rand(-2.5,2.5),rand(4,9),rand(-1.5,1));cg.add(c);BXS.coinV.push({v:V3(0,-rand(1,3),0),w:V3(rand(-8,8),rand(-8,8),rand(-8,8))});}s.add(cg);BXS.coins=cg;}
 // l'objet
 BXS.item=bxItemObject();BXS.item.position.y=1.0;BXS.item.scale.setScalar(.01);s.add(BXS.item);
 BXS.lightP.intensity=45;BXS.lightP.color.copy(col);
 boxFlash(rcol(q),q>=3?1:q>=2?.7:q>=1?.45:.25);$('boxov').classList.add('rarq'+Math.min(q,3));if(q>=4)$('boxov').classList.add('rarq4');
 U.inner.material.color.copy(col);U.inner.material.opacity=.9;U.seam.material.color.copy(col);
 if(q>=2)setTimeout(()=>confetti([rcol(q),'#ffffff',rcol(Math.max(0,q-1))],q>=3?280:140,.5,.42),300);
 BXS.shake=q>=3?.5:q>=2?.25:.1;
}
bxLoop=function(){
 if(!BXS.run)return;requestAnimationFrame(bxLoop);
 const now=performance.now()/1000;let dt=Math.min(.05,now-BXS.last);BXS.last=now;
 // petit ralenti au moment où un légendaire sort
 const res=BXS.res,q=res.q;
 if(BXS.burst&&q>=3&&BXS.t-2.9<.5)dt*=.45;
 BXS.t+=dt;const T=BXS.t,c=BXS.crate,U=c.userData,tc=new THREE.Color(BOXES[BXS.type].c);
 BXS.shake=Math.max(0,(BXS.shake||0)-dt*1.5);
 // 1) chute en tournant, réception avec écrasement et poussière
 if(T<.9){const k=T/.9;c.position.y=6.5*(1-k*k);c.rotation.y=-2.6+smooth01(k)*2.25;}
 else if(!BXS.hit){BXS.hit=true;c.position.y=0;c.rotation.y=-.35;sfx('land');sfx('bang',undefined,undefined,.15);BXS.shake=.35;
  const dr=new THREE.Mesh(new THREE.RingGeometry(.6,1.2,48),new THREE.MeshBasicMaterial({map:bx2Grad('dust','rgba(200,190,170,.0)','rgba(200,190,170,.5)'),transparent:true,opacity:.6,depthWrite:false,side:THREE.DoubleSide}));dr.rotation.x=-Math.PI/2;dr.position.y=.28;BXS.s.add(dr);BXS.dustR=dr;}
 if(T>=.9&&T<1.3){const k=(T-.9)/.4;c.scale.set(1+Math.sin(k*Math.PI)*.06*(1-k),1-Math.sin(k*Math.PI)*.1*(1-k),1+Math.sin(k*Math.PI)*.06*(1-k));}else c.scale.set(1,1,1);
 if(BXS.dustR){const k=(T-.9)/1.2;BXS.dustR.scale.setScalar(1+k*2.5);BXS.dustR.material.opacity=Math.max(0,.6-k*.6);}
 // 2) suspense : loquets, tremblement, lumière qui fuit et change de couleur
 if(T>=1.1&&T<2.9){
  const k=(T-1.1)/1.8;
  const sq=Math.min(q,Math.floor(k*k*(q+1.3)));const sc=new THREE.Color(rcol(sq));
  if(sq!==BXS.sq){BXS.sq=sq;sfx('tick');sfx('pickup',undefined,undefined,.4+sq*.2);BXS.pulse=1;}
  BXS.pulse=Math.max(0,(BXS.pulse||0)-dt*3);
  // loquets qui sautent à 1,5 s et 2,1 s
  for(let i=0;i<U.latches.length;i++){const L=U.latches[i],at=1.5+i*.6;if(T>=at&&!L.userData.popped){L.userData.popped=true;sfx('click',undefined,undefined,1);sfx('tick');BXS.shake=Math.max(BXS.shake,.12);L.userData.led.material.color.set(0x3dff7a);}
   if(L.userData.popped)L.userData.open=Math.min(1,L.userData.open+dt*9);L.userData.lev.rotation.x=L.userData.open*1.3;}
  const sh=k*k;c.position.y=Math.abs(Math.sin(T*(9+k*20)))*.05*sh;c.rotation.z=Math.sin(T*(21+k*30))*.05*sh;c.rotation.x=Math.cos(T*(17+k*25))*.035*sh;
  BXS.lid.rotation.x=-Math.max(0,Math.sin(T*(14+k*22)))*.05*sh;   // le couvercle se soulève par à-coups
  BXS.lightP.intensity=2+k*16+BXS.pulse*25;BXS.lightP.color.copy(sc);
  U.seam.material.opacity=.15+k*.85;U.seam.material.color.copy(sc);U.rayM.opacity=k*k*.5+BXS.pulse*.3;U.rayM.color.copy(sc);
  U.glowM.color.copy(sc);BXS.ring.material.color.copy(sc);BX2.rimM.color.copy(sc);BX2.halo.material.color.copy(sc);BX2.halo.material.opacity=.25+k*.35;
  U.leaks.rotation.y+=dt*(.5+k*2);
  if(Math.random()<k*.35)sfx('tick');
 }
 // 3) ouverture
 if(T>=2.9&&!BXS.burst)bx2Burst();
 if(BXS.burst){
  const k=T-2.9,col=new THREE.Color(rcol(q));
  // couvercle : s'ouvre sur ses charnières, ou part en l'air
  if(BXS.lidFree){const l=BXS.lidFree,u=l.userData;u.v.y-=12*dt;l.position.addScaledVector(u.v,dt);l.rotation.x+=u.w.x*dt;l.rotation.y+=u.w.y*dt;l.rotation.z+=u.w.z*dt;if(l.position.y<-2)l.visible=false;}
  else{const a=Math.min(1,k/.45),ov=a<1?smooth01(a)*1.18:1.18-Math.sin(Math.min(1,(k-.45)/.5)*Math.PI)*.08*Math.exp(-(k-.45)*3);BXS.lid.rotation.x=-ov*1.62;}
  U.rayM.opacity=Math.max(0,U.rayM.opacity-dt*1.5);U.seam.material.opacity=Math.max(0,.9-k*2);U.inner.material.opacity=Math.max(.35,.9-k*.4);
  const pp=BXS.parts.geometry.attributes.position;for(let i=0;i<BXS.partV.length;i++){const v=BXS.partV[i];v.y-=6*dt;v.multiplyScalar(1-dt*.6);pp.setXYZ(i,pp.getX(i)+v.x*dt,pp.getY(i)+v.y*dt,pp.getZ(i)+v.z*dt);}pp.needsUpdate=true;BXS.parts.material.opacity=Math.max(0,1-k/2.4);
  BXS.lightP.intensity=Math.max(6+q*2,45*Math.exp(-k*2));
  if(BXS.beam)BXS.beam.material.opacity=Math.min(.55,k*3)*Math.max(.25,1-k*.3)*(.6+q*.15);
  if(BXS.rays){BXS.rays.rotation.z+=dt*(q>=3?.6:.35);BXS.rays.scale.setScalar(Math.min(1,k*1.8));BXS.rays.userData.m.opacity=Math.min(.32+q*.05,k*1.2);if(q>=4)BXS.rays.userData.m.color.setHSL((T*.15)%1,.9,.6);}
  if(BXS.swirl){BXS.swirl.rotation.y+=dt*2.2;BXS.swirl.children.forEach((r,i)=>{r.rotation.z+=dt*(1+i);r.material.opacity=Math.min(.7,k)*(.6+.4*Math.sin(T*3+i));});BXS.swirl.scale.setScalar(Math.min(1,k*1.5));}
  if(BXS.sw){const sk=Math.min(1,k/.9);BXS.sw.scale.setScalar(1+sk*(5+q*1.5));BXS.sw.material.opacity=Math.max(0,.9-sk);}
  if(BXS.glow){BXS.glow.material.opacity=Math.min(.42,k)*(.85+.15*Math.sin(T*3));if(q>=4)BXS.glow.material.color.setHSL((T*.15)%1,.9,.6);}
  if(BXS.coins){BXS.coins.children.forEach((cn,i)=>{const v=BXS.coinV[i];v.v.y-=6*dt;cn.position.addScaledVector(v.v,dt);cn.rotation.x+=v.w.x*dt;cn.rotation.z+=v.w.z*dt;if(cn.position.y<.32){cn.position.y=.32;v.v.y=Math.abs(v.v.y)*.3;v.w.multiplyScalar(.7);if(Math.random()<.04)sfx('click',undefined,undefined,.25);}});}
  // l'objet sort de la caisse et flotte au-dessus du socle
  const ik=smooth01(Math.min(1,k/.9));BXS.item.position.y=1.0+ik*1.3+Math.sin(T*2)*.05;BXS.item.scale.setScalar(.01+ik*.99);
  if(BXS.holo){BXS.holo.position.y=1.0+ik*.45;BXS.holo.rotation.y+=dt;BXS.holo.children.forEach((r,i)=>{r.material.opacity=ik*.55;r.scale.setScalar(1+Math.sin(T*3+i)*.04);});}
  if(!BXS.rig)BXS.item.rotation.y=T*1.1;
  BXS.item.children.forEach(o=>{if(o.userData.spin)o.rotation.z+=dt*o.userData.spin;});
  if(BXS.rig){animateSoldier(BXS.rig,{vx:0,vz:0,yaw:0,pitch:0,speed:0,onGround:true,crouch:false,alive:true,reload:0,reloadMax:0,fire:0,ready:0,alert:0,hurt:false,y:0,dance:BXS.danceId,danceT:k,seated:0},dt,T);BXS.rig.root.rotation.y=Math.PI*.15;}
  BXS.ring.material.opacity=.3+.25*Math.sin(T*4);
  if(k>.95&&!BXS.shown){
   BXS.shown=true;const it=res.item;
   $('boxTxt').innerHTML='<div class="rar" style="color:'+rcol(q)+'">'+RARITY[q].n.toUpperCase()+'</div><h2 style="color:'+rcol(q)+'">'+(it.t==='coins'?'+'+it.n+' pièces':itemName(it))+'</h2><div class="sub">'+(res.dup?'Doublon — converti en <b style="color:var(--gold)">'+res.coins+' pièces</b>':it.t==='coins'?'Pièces ajoutées à ton solde':'<b style="color:var(--good)">NOUVEAU !</b> Ajouté à ta collection')+'</div>';
   $('boxAgain').style.display='';$('boxClose').style.display='';refreshProfile();buildBoxesTab();
   $('boxAgain').textContent=((PROF.boxes[BXS.type]||0)>0)?'OUVRIR UNE AUTRE':'ACHETER UNE AUTRE (🪙 '+BOXES[BXS.type].price+')';
   $('boxAgain').onclick=()=>{if((PROF.boxes[BXS.type]||0)>0||PROF.coins>=BOXES[BXS.type].price)startBoxOpen(BXS.type);else sfx('deny');};
  }
 }
 // poussières qui flottent
 if(BX2.motes){const pp=BX2.motes.geometry.attributes.position;for(let i=0;i<pp.count;i++){let y=pp.getY(i)+dt*.12;if(y>4.5)y=0;pp.setY(i,y);}pp.needsUpdate=true;}
 // caméra : s'approche pendant le suspense, recule à l'ouverture, tremble aux chocs
 let cz=6.4,cy=2.0;
 if(T>1.1&&T<2.9)cz-=smooth01((T-1.1)/1.8)*.9;
 if(BXS.burst){const k=T-2.9;cz=5.5+smooth01(Math.min(1,k/.6))*.9;cy=2.0+smooth01(Math.min(1,k/.8))*.35;}
 const shk=BXS.shake*BXS.shake;
 BXS.c.position.set(Math.sin(T*.45)*.5+rand(-1,1)*shk*.3,cy+Math.sin(T*.4)*.1+rand(-1,1)*shk*.3,cz);BXS.c.lookAt(0,BXS.burst?1.7:1.0,0);
 BXS.r.render(BXS.s,BXS.c);
};
// bords du rendu fondus : les rayons ne s'arrêtent plus net au bord du cadre
{const st=document.createElement('style');st.textContent='#boxCv{-webkit-mask-image:radial-gradient(ellipse 50% 50% at 50% 50%,#000 62%,transparent 100%);mask-image:radial-gradient(ellipse 50% 50% at 50% 50%,#000 62%,transparent 100%)}';document.head.appendChild(st);}
