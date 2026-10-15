/* =====================================================================
   ÉVÉNEMENT D'HALLOWEEN « NUIT D'HALLOWEEN »
   - carte « Manoir hanté » (tous les modes classiques) et son ambiance
   - décorations d'Halloween sur toutes les cartes pendant l'événement
   - 7 skins d'armes, 2 tenues et 3 effets d'élimination à débloquer
     en ramassant des citrouilles (paliers de l'événement)
   - effets d'élimination visibles en multijoueur (hôte et clients)
   Tout est procédural (canvas + Three.js) : aucun fichier externe.
   ===================================================================== */

/* ---------- thème : nuit violette, pleine lune orange ---------- */
THEMES.halloween={base:'haunt',sky:[[0,'#05030b'],[.24,'#160a2a'],[.4,'#3a1748'],[.47,'#8a3a3a'],[.5,'#e8762e'],[.52,'#1c0e16'],[1,'#060408']],
 fog:0x1d1028,fogN:10,fogF:92,hemiS:0x8a70c8,hemiG:0x160c08,hemiI:.52,sunC:0xd8c8ff,sunI:.5,sunPos:[-50,48,-62],exp:1.05,env:.14,cloud:'80,50,100',cov:.55,tint:0xa898a8};

/* ---------- carte : Manoir Ravenhollow ---------- */
const HW_PROP=.74,HW_HAY=1.4; // hauteurs réservées : PROP = bloc invisible sous un décor (citrouille géante, chaudron…)
MAPS.manoir={
 id:'manoir',n:'Manoir hanté',theme:'halloween',ev:'hw',
 desc:'Carte d\'Halloween : le manoir Ravenhollow une nuit de pleine lune. Site A dans le cimetière, site B sous la grange de la sorcière, le manoir au centre, l\'allée des sorcières à l\'ouest, le champ de citrouilles à l\'est et la fête foraine au sud.',
 build(){
  const R=GB.rect,T=TY,Wl=T.WALL,P=(x,z)=>R(T.LOW,x,z,x,z,HW_PROP),H=(x,z)=>R(T.CRATE,x,z,x,z,HW_HAY);
  R(Wl,0,0,39,0);R(Wl,0,39,39,39);R(Wl,0,0,0,39);R(Wl,39,0,39,39);
  // cour du manoir (départ CT) : puits et bottes de foin
  R(Wl,13,1,13,11);GB.clear(13,4,13,5);R(Wl,26,1,26,11);GB.clear(26,4,26,5);
  R(T.LOW,19,7,20,8,.95);H(16,9);H(23,9);H(15,6);H(24,6);
  // site A : cimetière, mausolée, tombes
  R(Wl,1,13,12,13);GB.clear(3,13,4,13);GB.clear(9,13,10,13);
  R(T.HOUSE,9,2,11,4,4.2);
  for(const [x,z] of [[3,3],[5,3],[3,6],[5,6],[3,9],[5,9],[7,9],[10,8],[11,10],[7,11]])R(T.LOW,x,z,x,z,.9);
  P(2,11);P(12,6);
  // site B : grange de la sorcière (toit sur piliers), chaudron
  R(Wl,27,13,38,13);GB.clear(29,13,30,13);GB.clear(35,13,36,13);
  GB.ceil(29,2,37,9,4.6);for(const [x,z] of [[29,2],[37,2],[29,9],[37,9],[33,2],[33,9]])R(T.PILLAR,x,z,x,z,4.6);
  H(31,4);H(31,5);H(35,7);H(36,7);H(30,11);H(37,11);H(34,10);P(33,5);
  // manoir : quatre portes, grand hall, piliers, table, bibliothèques, cercueils
  R(Wl,14,12,25,12);GB.clear(19,12,20,12);R(Wl,14,26,25,26);GB.clear(19,26,20,26);
  R(Wl,14,12,14,26);GB.clear(14,18,14,19);R(Wl,25,12,25,26);GB.clear(25,18,25,19);
  GB.ceil(15,13,24,25,5.6);
  for(const [x,z] of [[16,15],[23,15],[16,23],[23,23]])R(T.PILLAR,x,z,x,z,5.6);
  R(T.LOW,18,19,21,19,.9);R(T.CRATE,15,21,15,22);R(T.CRATE,24,13,24,14);R(T.LOW,17,25,17,25,.7);R(T.LOW,22,25,22,25,.7);
  // allée des sorcières (ouest) : cabane, clôture, foin, arbres morts
  H(4,17);H(5,17);H(10,21);H(2,24);H(11,29);H(3,31);R(T.LOW,6,21,8,21,1);
  R(T.HOUSE,5,25,8,27,3.8);P(12,15);P(1,28);
  R(Wl,13,27,13,32);GB.clear(13,29,13,30);
  // champ de citrouilles (est) : citrouilles géantes, épouvantail, foin
  for(const [x,z] of [[28,17],[31,16],[34,18],[37,17],[29,21],[36,22],[30,26],[34,28],[28,30],[37,30],[32,21]])P(x,z);
  H(35,25);H(36,25);H(27,23);
  R(Wl,26,27,26,32);GB.clear(26,29,26,30);
  // place du marché (devant le manoir) : étals, charrette
  H(16,29);H(23,29);R(T.LOW,19,30,20,30,.9);
  // fête foraine (départ T)
  R(Wl,1,33,38,33);GB.clear(3,33,5,33);GB.clear(15,33,16,33);GB.clear(23,33,24,33);GB.clear(34,33,36,33);
  H(8,36);H(31,36);P(12,35);P(27,35);
  // sols : 0 herbe, 1 pavés, 2 damier, 3 terre, 4 dalles claires, 5 carrelage
  GB.tag(1,1,12,12,0);GB.tag(14,1,25,11,1);GB.tag(27,1,38,12,3);GB.tag(15,13,24,25,2);
  GB.tag(1,14,13,32,0);GB.tag(26,14,38,32,3);GB.tag(14,27,25,32,5);GB.tag(1,34,38,38,4);
 },
 sites:[{n:'A',cx:6,cz:7,r:6},{n:'B',cx:33,cz:6,r:6}],
 spawnCT:[[15,2],[17,2],[19,2],[21,2],[23,2],[24,3],[16,4],[18,4],[21,4],[23,4]],
 spawnT:[[15,37],[17,37],[19,37],[21,37],[23,37],[24,36],[16,35],[20,35],[22,35],[18,36]],
 spawnDM:[[6,7],[33,6],[3,20],[36,20],[17,17],[22,21],[10,18],[30,19],[6,36],[33,37],[20,4],[19,28],[2,30],[37,27],[12,23],[28,9]],
 pickups:[[6,10,'shield'],[33,11,'health'],[19,16,'shield'],[2,19,'health'],[37,19,'shield'],[21,28,'ammo'],[10,35,'health'],[29,36,'shield'],[20,10,'ammo']],
 holdCT:[[6,8],[33,7],[19,14],[20,24]],
 roam:[[6,7],[33,6],[19,5],[19,15],[19,23],[4,20],[10,24],[3,29],[30,18],[36,26],[29,31],[21,28],[8,35],[30,37],[13,14],[26,14]],
 koth:[[19,21,4],[6,7,4],[33,6,4],[21,29,4]],
 arches:[],
 locName(cx,cz){
  if(cz<=12&&cx<=12)return 'Cimetière';
  if(cz<=12&&cx>=27)return 'Grange de la sorcière';
  if(cz<=11)return 'Cour du manoir';
  if(cx>=14&&cx<=25&&cz<=26)return 'Manoir';
  if(cz<=32)return cx<=13?'Allée des sorcières':cx>=26?'Champ de citrouilles':'Place du marché';
  return 'Fête foraine';
 }
};
buildMapSnapshot('manoir');

/* ---------- matières de la carte ---------- */
function texHay(hm){return cached('hay'+hm,()=>canvasTex(128,Math.round(PX*hm),(c,w,h)=>{
 c.fillStyle='#b8933e';c.fillRect(0,0,w,h);
 for(let i=0;i<900;i++){c.strokeStyle='hsla('+rand(38,52)+','+rand(45,70)+'%,'+rand(35,70)+'%,.8)';c.lineWidth=rand(.6,1.6);const x=rand(0,w),y=rand(0,h),a=rand(-.5,.5);c.beginPath();c.moveTo(x,y);c.lineTo(x+Math.cos(a)*rand(6,16),y+Math.sin(a)*rand(6,16));c.stroke();}
 c.fillStyle='rgba(60,35,10,.75)';c.fillRect(0,h*.28,w,3);c.fillRect(0,h*.7,w,3);
 const g=c.createLinearGradient(0,0,0,h);g.addColorStop(0,'rgba(0,0,0,0)');g.addColorStop(1,'rgba(30,20,5,.35)');c.fillStyle=g;c.fillRect(0,0,w,h);
}));}
const HW_INV=new THREE.MeshBasicMaterial({visible:false});
const _hauntMatsHw=hauntMats;
hauntMats=function(t,h,sideM,topM,boxMats){
 if(MAP&&MAP.id==='manoir'){
  if(t===TY.LOW&&Math.abs(h-HW_PROP)<.01)return [HW_INV,HW_INV,HW_INV,HW_INV,HW_INV,HW_INV];
  if(t===TY.CRATE&&Math.abs(h-HW_HAY)<.01)return boxMats(sideM(texHay(h)),topM(texHay(.6)));
  if(t===TY.LOW&&Math.abs(h-1)<.01)return boxMats(sideM(texWoodDeck(h)),topM(null,0x3a2a1c));
 }
 return _hauntMatsHw(t,h,sideM,topM,boxMats);
};

/* ---------- objets d'Halloween réutilisables ---------- */
const HWM={};
function hwMat(k){
 if(HWM[k])return HWM[k];
 const M={
  pumpkin:()=>new THREE.MeshStandardMaterial({color:C(0xe8701a),roughness:.55,emissive:C(0x3a1000),emissiveIntensity:.6}),
  stem:()=>new THREE.MeshStandardMaterial({color:C(0x4a5a22),roughness:.85}),
  face:()=>new THREE.MeshBasicMaterial({color:0xffd060,toneMapped:false}),
  iron:()=>new THREE.MeshStandardMaterial({color:C(0x1a1a1e),roughness:.5,metalness:.8}),
  brew:()=>new THREE.MeshBasicMaterial({color:0x6dff4a,toneMapped:false}),
  wood:()=>stdMat(0x3a2818,{roughness:1}),
  stone:()=>new THREE.MeshStandardMaterial({map:texTomb(1),color:C(0xe0e4e0),roughness:1,envMapIntensity:.05}),
  tower:()=>new THREE.MeshStandardMaterial({map:texBrick(6),color:C(0x8a8090),roughness:1}),
  roof:()=>stdMat(0x241a26,{roughness:.9}),
  cloth:()=>new THREE.MeshStandardMaterial({color:C(0x5a3a5a),roughness:1,side:THREE.DoubleSide})
 }[k]();
 return HWM[k]=M;
}
// citrouille sculptée (s = diamètre en mètres) ; lit=true : visage lumineux + halo
function jackO(s,lit){
 const g=new THREE.Group(),pm=hwMat('pumpkin');
 for(let i=0;i<8;i++){const a=i/8*TAU,l=new THREE.Mesh(new THREE.SphereGeometry(.5,12,10),pm);l.scale.set(.42,.82,.62);l.position.set(Math.cos(a)*.24,.4,Math.sin(a)*.24);l.rotation.y=-a;l.castShadow=true;g.add(l);}
 const core=new THREE.Mesh(new THREE.SphereGeometry(.44,14,10),pm);core.scale.y=.85;core.position.y=.4;g.add(core);
 const st=new THREE.Mesh(new THREE.CylinderGeometry(.04,.07,.22,6),hwMat('stem'));st.position.y=.83;st.rotation.z=.25;g.add(st);
 if(lit){
  const fm=hwMat('face'),tri=new THREE.Shape();tri.moveTo(-.07,0);tri.lineTo(.07,0);tri.lineTo(0,.11);tri.lineTo(-.07,0);
  const tg=new THREE.ShapeGeometry(tri);
  for(const sx of [-1,1]){const e=new THREE.Mesh(tg,fm);e.position.set(sx*.13,.48,-.47);e.rotation.y=Math.PI;g.add(e);}
  const mo=new THREE.Shape();mo.moveTo(-.2,.0);for(let i=0;i<=8;i++)mo.lineTo(-.2+i*.05,i%2?-.05:0);mo.lineTo(.2,-.06);mo.quadraticCurveTo(0,-.2,-.2,-.06);mo.lineTo(-.2,0);
  const m=new THREE.Mesh(new THREE.ShapeGeometry(mo),fm);m.position.set(0,.34,-.47);m.rotation.y=Math.PI;g.add(m);
  const nose=new THREE.Mesh(tg,fm);nose.scale.setScalar(.6);nose.position.set(0,.39,-.475);nose.rotation.y=Math.PI;g.add(nose);
 }
 g.scale.setScalar(s);return g;
}
// lanterne-citrouille posée dans le décor de la carte
function hwPumpkin(x,y,z,s,ry,light){
 const p=jackO(s,true);p.position.set(x,y,z);p.rotation.y=ry===undefined?rand(0,TAU):ry;worldG.add(p);
 glowSprite(x,y+s*.42,z,'orange',s*3.2,.55,true);
 if(light){const L=new THREE.PointLight(0xff8a30,light,10+s*6,2);L.position.set(x,y+s*.6,z);worldG.add(L);const ph=rand(0,6);worldAnim.push(t=>{L.intensity=light*(.82+.18*Math.sin(t*9+ph)*Math.sin(t*3.7+ph));});}
 return p;
}
function hwBatTex(){return cached('hwbat',()=>canvasTex(64,32,(c,w,h)=>{
 c.fillStyle='#0b0710';c.beginPath();c.moveTo(32,12);
 c.quadraticCurveTo(22,2,4,6);c.quadraticCurveTo(10,12,8,18);c.quadraticCurveTo(14,14,18,20);c.quadraticCurveTo(22,16,27,22);c.lineTo(32,26);
 c.lineTo(37,22);c.quadraticCurveTo(42,16,46,20);c.quadraticCurveTo(50,14,56,18);c.quadraticCurveTo(54,12,60,6);c.quadraticCurveTo(42,2,32,12);c.fill();
 c.beginPath();c.arc(32,15,5,0,TAU);c.fill();c.beginPath();c.moveTo(28,11);c.lineTo(29,6);c.lineTo(31,10);c.moveTo(36,11);c.lineTo(35,6);c.lineTo(33,10);c.fill();
 c.fillStyle='#ff3030';c.fillRect(29,14,2,2);c.fillRect(33,14,2,2);
}));}
// nuée de chauves-souris qui tournent autour d'un point
function hwBats(cx,cy,cz,n,rad){
 const tex=hwBatTex();
 for(let i=0;i<n;i++){
  const s=new THREE.Sprite(new THREE.SpriteMaterial({map:tex,transparent:true,depthWrite:false,fog:true}));const sz=rand(.7,1.2);s.scale.set(sz,sz/2,1);worldG.add(s);
  const r=rad*rand(.5,1.1),h=cy+rand(-2,3),sp=rand(.35,.7)*(Math.random()<.5?-1:1),ph=rand(0,TAU),fl=rand(14,20);
  worldAnim.push(t=>{const a=ph+t*sp;s.position.set(cx+Math.cos(a)*r,h+Math.sin(t*1.3+ph)*1.2,cz+Math.sin(a*1.3)*r*.8);s.scale.y=sz/2*(.35+.65*Math.abs(Math.sin(t*fl+ph)));});
 }
}
function hwGhostTex(){return cached('hwghost',()=>canvasTex(64,64,(c)=>{
 const g=c.createRadialGradient(32,26,2,32,30,30);g.addColorStop(0,'rgba(240,250,255,.95)');g.addColorStop(1,'rgba(200,230,255,.55)');c.fillStyle=g;
 c.beginPath();c.arc(32,26,18,Math.PI,0);c.lineTo(50,56);for(let i=0;i<4;i++){c.lineTo(50-i*6-3,50);c.lineTo(50-i*6-6,56);}c.closePath();c.fill();
 c.fillStyle='#1a1028';c.beginPath();c.ellipse(25,26,3.5,5,0,0,TAU);c.ellipse(39,26,3.5,5,0,0,TAU);c.fill();c.beginPath();c.ellipse(32,37,4,5,0,0,TAU);c.fill();
}));}
function hwGhost(x0,y0,z0,rx,rz){
 const s=new THREE.Sprite(new THREE.SpriteMaterial({map:hwGhostTex(),transparent:true,depthWrite:false,opacity:.7,fog:true}));s.scale.set(1.3,1.3,1);worldG.add(s);
 const gl=glowSprite(x0,y0,z0,'cool',3,.25,false),ph=rand(0,TAU);
 worldAnim.push(t=>{const x=x0+Math.sin(t*.23+ph)*rx,z=z0+Math.cos(t*.17+ph)*rz,y=y0+Math.sin(t*1.1+ph)*.35;s.position.set(x,y,z);gl.position.set(x,y,z);s.material.opacity=.45+.3*Math.sin(t*.7+ph);});
}
function hwCobwebTex(){return cached('hwweb',()=>canvasTex(128,128,(c,w)=>{
 c.strokeStyle='rgba(230,230,240,.75)';c.lineWidth=1.2;
 for(let i=0;i<=8;i++){const a=i/8*Math.PI/2;c.beginPath();c.moveTo(0,0);c.lineTo(Math.cos(a)*w*1.4,Math.sin(a)*w*1.4);c.stroke();}
 for(let r=14;r<w*1.3;r+=14){c.beginPath();for(let i=0;i<=8;i++){const a=i/8*Math.PI/2,rr=r*(i%2?.92:1);const x=Math.cos(a)*rr,y=Math.sin(a)*rr;i?c.quadraticCurveTo(Math.cos(a-.1)*rr*.9,Math.sin(a-.1)*rr*.9,x,y):c.moveTo(x,y);}c.stroke();}
}));}
function hwCobweb(x,y,z,ry,s){
 const m=new THREE.Mesh(new THREE.PlaneGeometry(s,s),new THREE.MeshBasicMaterial({map:hwCobwebTex(),transparent:true,depthWrite:false,side:THREE.DoubleSide}));
 m.position.set(x,y,z);m.rotation.set(0,ry,Math.PI);worldG.add(m);
}
// guirlande lumineuse entre deux points (ampoules orange et violettes)
function hwGarland(a,b,sag,n){
 const pts=[];for(let i=0;i<=n;i++){const k=i/n;pts.push(new THREE.Vector3(lerp(a[0],b[0],k),lerp(a[1],b[1],k)-Math.sin(k*Math.PI)*sag,lerp(a[2],b[2],k)));}
 worldG.add(new THREE.Line(new THREE.BufferGeometry().setFromPoints(pts),new THREE.LineBasicMaterial({color:0x111111})));
 const cols=[0xff8a20,0xb04aff,0x7dff5a];
 pts.forEach((p,i)=>{if(!i||i===n)return;const col=cols[i%3],m=new THREE.Mesh(new THREE.SphereGeometry(.07,8,6),new THREE.MeshBasicMaterial({color:col,toneMapped:false}));m.position.copy(p);m.position.y-=.08;worldG.add(m);
  const gs=new THREE.Sprite(new THREE.SpriteMaterial({map:GLOW.white,color:col,blending:THREE.AdditiveBlending,transparent:true,depthWrite:false,opacity:.55}));gs.scale.set(.9,.9,1);gs.position.copy(m.position);worldG.add(gs);
  const ph=i*.7;worldAnim.push(t=>{gs.material.opacity=.3+.35*(.5+.5*Math.sin(t*2.4+ph));});});
}
function hwMoon(th,size){
 const mt=canvasTex(128,128,(c,w,h)=>{const g=c.createRadialGradient(56,56,6,64,64,62);g.addColorStop(0,'#fff0c8');g.addColorStop(.6,'#ffb44a');g.addColorStop(.92,'#e8762e');g.addColorStop(1,'rgba(232,118,46,0)');c.fillStyle=g;c.beginPath();c.arc(64,64,62,0,TAU);c.fill();
  for(let i=0;i<10;i++){c.fillStyle='rgba(150,70,20,'+rand(.12,.25)+')';c.beginPath();c.arc(rand(30,98),rand(30,98),rand(4,12),0,TAU);c.fill();}});
 const dir=new THREE.Vector3(...th.sunPos).normalize();
 const moon=new THREE.Sprite(new THREE.SpriteMaterial({map:mt,fog:false,depthWrite:false,toneMapped:false}));moon.scale.set(size,size,1);moon.position.copy(dir.clone().multiplyScalar(175));skyG.add(moon);
 const halo=new THREE.Sprite(new THREE.SpriteMaterial({map:GLOW.orange,fog:false,depthWrite:false,toneMapped:false,blending:THREE.AdditiveBlending,transparent:true,opacity:.45}));halo.scale.set(size*3,size*3,1);halo.position.copy(moon.position).multiplyScalar(1.01);skyG.add(halo);
 // silhouette de sorcière sur son balai qui passe devant la lune
 const wt=canvasTex(128,64,(c)=>{c.fillStyle='#08040c';c.fillRect(10,40,108,3);c.beginPath();c.moveTo(100,36);c.lineTo(126,30);c.lineTo(124,48);c.fill();
  c.beginPath();c.moveTo(48,41);c.lineTo(58,18);c.lineTo(72,41);c.fill();c.beginPath();c.arc(62,16,6,0,TAU);c.fill();c.beginPath();c.moveTo(52,12);c.lineTo(74,12);c.lineTo(60,-4);c.fill();c.fillRect(48,10,30,3);c.beginPath();c.moveTo(58,26);c.lineTo(40,30);c.lineTo(58,30);c.fill();});
 const witch=new THREE.Sprite(new THREE.SpriteMaterial({map:wt,fog:false,depthWrite:false,transparent:true}));witch.scale.set(size*.5,size*.25,1);skyG.add(witch);
 const side=new THREE.Vector3(-dir.z,0,dir.x).normalize();
 worldAnim.push(t=>{const k=((t*.025)%1.6)-.8;witch.position.copy(dir).multiplyScalar(170).addScaledVector(side,k*size*2.4).add(new THREE.Vector3(0,Math.sin(t*.8)*size*.12-k*size*.3,0));});
}
function hwDeadTree(x,z,s){if(typeof deadTree==='function')deadTree(x,z,s);}
function hwScrawl(txt,x,y,z,ry,w,col,font){
 const t=canvasTex(512,128,(c,W,H)=>{c.font=font||'bold 70px Georgia';c.textAlign='center';c.fillStyle=col||'#8a0a0a';c.fillText(txt,W/2,82);if(!col)for(let i=0;i<22;i++){c.fillRect(rand(40,W-40),rand(70,85),rand(2,5),rand(10,40));}});
 const m=new THREE.Mesh(new THREE.PlaneGeometry(w,w/4),new THREE.MeshBasicMaterial({map:t,transparent:true,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-2,toneMapped:false}));m.position.set(x,y,z);m.rotation.y=ry;worldG.add(m);return m;
}
function hwFog(n,col,area){
 const ft=canvasTex(128,128,(c,w,h)=>{for(let i=0;i<12;i++){const x=rand(20,108),y=rand(20,108),r=rand(20,50),g=c.createRadialGradient(x,y,0,x,y,r);g.addColorStop(0,'rgba('+col+',.35)');g.addColorStop(1,'rgba('+col+',0)');c.fillStyle=g;c.fillRect(0,0,w,h);}});
 for(let i=0;i<n;i++){const m=new THREE.Mesh(new THREE.PlaneGeometry(14,14),new THREE.MeshBasicMaterial({map:ft,transparent:true,opacity:rand(.25,.5),depthWrite:false}));
  m.rotation.x=-Math.PI/2;const x0=rand(area[0],area[2]),z0=rand(area[1],area[3]);m.position.set(x0,rand(.25,.6),z0);worldG.add(m);const ph=rand(0,6);
  worldAnim.push(t=>{m.position.x=x0+Math.sin(t*.07+ph)*3;m.rotation.z=t*.02+ph;});}
}
// éclairs violets + tonnerre (comme l'Asile)
function hwLightning(col){
 const flash=new THREE.DirectionalLight(col||0xc8b0ff,0);flash.position.set(-30,80,-20);worldG.add(flash);
 let next=-1,fT=-99,boomAt=-1;
 worldAnim.push(t=>{
  if(next<0)next=t+rand(8,16);
  if(t>next){fT=t;next=t+rand(14,30);boomAt=t+rand(.6,2.2);}
  const a=t-fT;flash.intensity=a<.5?(a<.08?2.6:a<.16?.3:a<.24?2:Math.max(0,2-(a-.24)*8)):0;
  if(boomAt>0&&t>boomAt){boomAt=-1;if(G.running)sfx('thunder',undefined,undefined,.3);}
 });
}

// toit à deux pans (prisme) au-dessus d'un rectangle ; faîtage le long de l'axe donné
function hwGable(x0,x1,z0,z1,y,h,axis){
 const along=axis==='x',L=along?x1-x0:z1-z0,W2=(along?z1-z0:x1-x0)/2,sh=new THREE.Shape();
 sh.moveTo(-W2,0);sh.lineTo(W2,0);sh.lineTo(0,h);sh.lineTo(-W2,0);
 const g=new THREE.ExtrudeGeometry(sh,{depth:L,bevelEnabled:false});g.translate(0,0,-L/2);
 const m=new THREE.Mesh(g,hwMat('roof'));m.position.set((x0+x1)/2,y,(z0+z1)/2);if(along)m.rotation.y=Math.PI/2;m.castShadow=true;worldG.add(m);return m;
}
/* ---------- décor du Manoir hanté ---------- */
DECOR.manoir=function(th){
 stars(220,185);hwMoon(th,34);
 const cw=c=>cc(c);
 // arbres morts autour et dans l'enceinte
 for(let i=0;i<20;i++){const a=rand(0,TAU),r=rand(46,72);hwDeadTree(40+Math.cos(a)*r,40+Math.sin(a)*r,rand(1.6,2.8));}
 for(const [cx,cz,s] of [[2,11,1.1],[12,6,1],[12,15,1.2],[1,28,1]])hwDeadTree(cw(cx),cw(cz),s);
 // cimetière : stèles arrondies et croix sur les tombes
 const stone=hwMat('stone');
 for(let cz=1;cz<13;cz++)for(let cx=1;cx<13;cx++){const i=cz*N+cx;if(G_TYPE[i]!==TY.LOW||Math.abs(G_H[i]-.9)>.01)continue;
  const g=new THREE.Group();g.position.set(cw(cx),.9,cw(cz));g.rotation.y=rand(-.25,.25);g.rotation.z=rand(-.12,.12);
  if((cx+cz)%2){const v=new THREE.Mesh(GBOX,stone);v.scale.set(.18,1.1,.18);v.position.y=.55;const hb=new THREE.Mesh(GBOX,stone);hb.scale.set(.7,.16,.16);hb.position.y=.8;g.add(v,hb);}
  else{const b=new THREE.Mesh(GBOX,stone);b.scale.set(.9,.8,.22);b.position.y=.4;const top=new THREE.Mesh(new THREE.CylinderGeometry(.45,.45,.22,18),stone);top.rotation.x=Math.PI/2;top.position.y=.8;g.add(b,top);
   const rip=hwScrawl('R.I.P.',0,.5,-.12,Math.PI,.8,'#2a2a2a','bold 80px Georgia');worldG.remove(rip);g.add(rip);}
  g.traverse(o=>{if(o.isMesh)o.castShadow=true;});worldG.add(g);}
 // mausolée : fronton, porte noire, lueur verte
 {hwGable(cw(9)-1.2,cw(11)+1.2,cw(2)-1.2,cw(4)+1.2,4.2,1.8,'z');
  const door=new THREE.Mesh(new THREE.PlaneGeometry(1.6,2.6),new THREE.MeshBasicMaterial({color:0x050806}));door.position.set(cw(10),1.3,cw(4)+1.01);worldG.add(door);
  glowSprite(cw(10),1.2,cw(4)+1.3,'cool',3,.35,true);hwScrawl('RAVENHOLLOW',cw(10),3.5,cw(4)+1.02,0,4.5,'#b8b0a0','bold 64px Georgia');}
 for(const [x,z,rx,rz] of [[12,14,4,5],[30,64,6,4],[40,40,4,6]])hwGhost(x,1.8,z,rx,rz);
 // feux follets verts au ras des tombes
 for(let i=0;i<14;i++){const x0=rand(3,24),z0=rand(3,24),s=glowSprite(x0,.6,z0,'cool',.6,.8,false);s.material.color=new THREE.Color(0x7dff9a);const ph=rand(0,TAU);
  worldAnim.push(t=>{s.position.set(x0+Math.sin(t*.4+ph)*1.5,.5+Math.sin(t*1.7+ph)*.3,z0+Math.cos(t*.33+ph)*1.5);s.material.opacity=.4+.4*Math.sin(t*3+ph);});}
 // grange de la sorcière : toit à deux pans, chaudron bouillonnant, balais
 hwGable(cw(29)-1.4,cw(37)+1.4,cw(2)-1.4,cw(9)+1.4,4.85,3.2,'x');
 {const x=cw(33),z=cw(5),pot=new THREE.Mesh(new THREE.SphereGeometry(.85,18,12,0,TAU,Math.PI*.25,Math.PI*.75),hwMat('iron'));pot.position.set(x,.95,z);pot.castShadow=true;worldG.add(pot);
  const rim=new THREE.Mesh(new THREE.TorusGeometry(.62,.08,8,24),hwMat('iron'));rim.rotation.x=Math.PI/2;rim.position.set(x,1.55,z);worldG.add(rim);
  const brew=new THREE.Mesh(new THREE.CircleGeometry(.6,24),hwMat('brew'));brew.rotation.x=-Math.PI/2;brew.position.set(x,1.45,z);worldG.add(brew);
  for(let i=0;i<3;i++){const a=i/3*TAU,l=new THREE.Mesh(new THREE.CylinderGeometry(.05,.05,.6,6),hwMat('iron'));l.position.set(x+Math.cos(a)*.55,.3,z+Math.sin(a)*.55);worldG.add(l);}
  for(let i=0;i<7;i++){const lg=new THREE.Mesh(new THREE.CylinderGeometry(.08,.1,.8,6),hwMat('wood'));const a=i/7*TAU;lg.position.set(x+Math.cos(a)*.35,.12,z+Math.sin(a)*.35);lg.rotation.set(Math.PI/2,0,a);worldG.add(lg);}
  const fire=glowSprite(x,.35,z,'orange',2.4,.8,true);fire.material.color=new THREE.Color(0xff7a20);
  const gl=glowSprite(x,1.9,z,'cool',5,.5,false);gl.material.color=new THREE.Color(0x7dff5a);
  const L=new THREE.PointLight(0x6dff4a,7,16,2);L.position.set(x,2.4,z);worldG.add(L);
  const bubs=[];for(let i=0;i<10;i++){const b=new THREE.Mesh(new THREE.SphereGeometry(1,8,6),hwMat('brew'));worldG.add(b);bubs.push({b,ph:rand(0,1),a:rand(0,TAU),r:rand(0,.45),sp:rand(.4,.8)});}
  worldAnim.push(t=>{L.intensity=6+Math.sin(t*3)*1.5+Math.sin(t*11)*.6;gl.material.opacity=.4+.12*Math.sin(t*2.3);
   for(const o of bubs){const k=(t*o.sp+o.ph)%1;o.b.position.set(x+Math.cos(o.a)*o.r,1.45+k*1.6,z+Math.sin(o.a)*o.r);o.b.scale.setScalar(.06+k*.06);o.b.visible=k<.92;}});
  for(const [bx,bz,r] of [[cw(37)-.4,cw(4),.25],[cw(37)-.4,cw(5),-.2]]){const st=new THREE.Mesh(new THREE.CylinderGeometry(.03,.03,1.6,6),hwMat('wood'));st.position.set(bx,.85,bz);st.rotation.z=r;worldG.add(st);const br=new THREE.Mesh(new THREE.ConeGeometry(.18,.45,8),stdMat(0x8a6a2a));br.position.set(bx+Math.sin(-r)*.8,.1,bz);worldG.add(br);}
  hwScrawl('CHAUDRON MAGIQUE',x,3.7,cw(2)-1.02,0,4,'#7dff5a','bold 56px Georgia');}
 // manoir : toit pointu, tour d'angle, fenêtres éclairées
 {const cx=(cw(14)+cw(25))/2,cz=(cw(12)+cw(26))/2;
  const rf=new THREE.Mesh(new THREE.CylinderGeometry(.01,16.8,6,4,1),hwMat('roof'));rf.rotation.y=Math.PI/4;rf.scale.set(1,1,1.2);rf.position.set(cx,6+3,cz);rf.castShadow=true;worldG.add(rf);
  const tx=cw(25)+.4,tz=cw(12)-.4,tw=new THREE.Mesh(new THREE.CylinderGeometry(1.9,2.1,13,12),hwMat('tower'));tw.position.set(tx,6.5,tz);tw.castShadow=true;worldG.add(tw);
  const tr=new THREE.Mesh(new THREE.ConeGeometry(2.5,5,12),hwMat('roof'));tr.position.set(tx,15.5,tz);worldG.add(tr);
  const win=new THREE.Mesh(new THREE.PlaneGeometry(.9,1.5),new THREE.MeshBasicMaterial({color:0xffb050,toneMapped:false}));win.position.set(tx,10,tz-2.12);win.rotation.y=Math.PI;worldG.add(win);
  glowSprite(tx,10,tz-2.3,'orange',3,.5,true);hwBats(tx,14,tz,22,9);
  for(const [x,z,ry] of [[cw(16),cw(12)-1.02,Math.PI],[cw(23),cw(12)-1.02,Math.PI],[cw(16),cw(26)+1.02,0],[cw(23),cw(26)+1.02,0],[cw(14)-1.02,cw(15),-Math.PI/2],[cw(25)+1.02,cw(22),Math.PI/2]]){
   const w=new THREE.Mesh(new THREE.PlaneGeometry(1.3,1.9),new THREE.MeshBasicMaterial({color:Math.random()<.5?0xffa040:0x9a5aff,toneMapped:false}));w.position.set(x,3.8,z);w.rotation.y=ry;worldG.add(w);
   const fr=new THREE.Mesh(new THREE.PlaneGeometry(1.5,.1),new THREE.MeshBasicMaterial({color:0x111111}));fr.position.set(x,3.8,z+(ry===0?.01:ry===Math.PI?-.01:0));fr.rotation.y=ry;worldG.add(fr);}
  hwScrawl('JOYEUX HALLOWEEN',cx,5,cw(12)-1.03,Math.PI,7,'#ff8a2a','bold 62px Georgia');
  hwScrawl('SORTEZ D\'ICI',cx,3.4,cw(26)+1.03,0,5);
  // hall : lustre aux bougies, table garnie, toiles d'araignées, portraits
  const ch=new THREE.Group();ch.position.set(cx,4.6,cz);worldG.add(ch);
  const ring=new THREE.Mesh(new THREE.TorusGeometry(1.1,.05,6,24),hwMat('iron'));ring.rotation.x=Math.PI/2;ch.add(ring);
  const chain=new THREE.Mesh(new THREE.CylinderGeometry(.02,.02,1,4),hwMat('iron'));chain.position.y=.5;ch.add(chain);
  for(let i=0;i<8;i++){const a=i/8*TAU,cd=new THREE.Mesh(new THREE.CylinderGeometry(.04,.045,.25,6),stdMat(0xeee4c8));cd.position.set(Math.cos(a)*1.1,.15,Math.sin(a)*1.1);ch.add(cd);}
  glowSprite(cx,4.85,cz,'warm',4,.5,true);
  const L=new THREE.PointLight(0xffa860,10,22,2);L.position.set(cx,4.2,cz);worldG.add(L);
  worldAnim.push(t=>{ch.rotation.z=Math.sin(t*.8)*.02;L.intensity=9+Math.sin(t*7)*1.2+Math.sin(t*19)*.6;});
  for(const x of [cw(18),cw(19.5),cw(21)]){candle(x,.9,cw(19));}
  hwPumpkin(cw(20),.9,cw(19),.5,Math.PI,0);
  for(const [x,z,ry] of [[cw(15)-1,cw(13)-1,0],[cw(24)+1,cw(13)-1,-Math.PI/2],[cw(15)-1,cw(25)+1,Math.PI/2],[cw(24)+1,cw(25)+1,Math.PI]])hwCobweb(x,5.5,z,ry+Math.PI/4,3);
  const portrait=(x,z,ry,hue)=>{const t=canvasTex(64,96,(c,w,h)=>{c.fillStyle='#2a1a10';c.fillRect(0,0,w,h);c.fillStyle='hsl('+hue+',25%,18%)';c.fillRect(6,6,w-12,h-12);c.fillStyle='#c8b8a0';c.beginPath();c.ellipse(w/2,h*.4,12,15,0,0,TAU);c.fill();c.fillStyle='#200';c.fillRect(w/2-7,h*.37,4,3);c.fillRect(w/2+3,h*.37,4,3);c.fillStyle='#111';c.fillRect(w/2-16,h*.62,32,30);});
   const m=new THREE.Mesh(new THREE.PlaneGeometry(1.1,1.6),new THREE.MeshStandardMaterial({map:t,roughness:.6}));m.position.set(x,3,z);m.rotation.y=ry;worldG.add(m);};
  portrait(cw(15)-.98,cw(16),Math.PI/2,280);portrait(cw(24)+.98,cw(20),-Math.PI/2,20);portrait(cw(18),cw(13)-.98,0,200);}
 // cabane de la sorcière : toit pointu de travers, fenêtre verte, cheminée
 {const rf=new THREE.Mesh(new THREE.ConeGeometry(5.6,4.2,4),hwMat('roof'));rf.rotation.y=Math.PI/4;rf.rotation.z=.08;rf.scale.set(1,1,.8);rf.position.set(cw(6.5),3.8+2.1,cw(26));worldG.add(rf);
  const wn=new THREE.Mesh(new THREE.PlaneGeometry(1.1,1),new THREE.MeshBasicMaterial({color:0x7dff5a,toneMapped:false}));wn.position.set(cw(8)+1.02,2,cw(26));wn.rotation.y=Math.PI/2;worldG.add(wn);glowSprite(cw(8)+1.3,2,cw(26),'cool',2.4,.4,true);
  const chm=new THREE.Mesh(new THREE.CylinderGeometry(.3,.35,2.2,6),hwMat('stone'));chm.position.set(cw(5),5.6,cw(25));chm.rotation.z=-.15;worldG.add(chm);
  hwScrawl('ENTREZ...',cw(8)+1.02,3.2,cw(26),Math.PI/2,3.2,'#7dff5a','bold 64px Georgia');}
 // champ de citrouilles : citrouilles géantes, épouvantail, petites citrouilles au sol
 let lit=0;
 for(let cz=14;cz<39;cz++)for(let cx=1;cx<39;cx++){const i=cz*N+cx;if(G_TYPE[i]!==TY.LOW||Math.abs(G_H[i]-HW_PROP)>.01)continue;
  if(cx===32&&cz===21)continue;
  hwPumpkin(cw(cx),0,cw(cz),rand(1.5,1.9),rand(-.6,.6)+Math.PI*((cz>33)?0:1),lit<5&&(cz%3===0)?(lit++,3.5):0);}
 for(let i=0;i<40;i++){const x=rand(54,76),z=rand(30,64);if(blocked(x,z,0,.6))continue;const p=jackO(rand(.35,.6),false);p.position.set(x,0,z);p.rotation.y=rand(0,TAU);worldG.add(p);}
 {const sx=cw(32),sz=cw(21),g=new THREE.Group();g.position.set(sx,0,sz);
  const post=new THREE.Mesh(new THREE.CylinderGeometry(.07,.08,2.6,6),hwMat('wood'));post.position.y=1.3;g.add(post);
  const arm=new THREE.Mesh(new THREE.CylinderGeometry(.05,.05,1.9,6),hwMat('wood'));arm.rotation.z=Math.PI/2;arm.position.y=1.9;g.add(arm);
  const coat=new THREE.Mesh(new THREE.CylinderGeometry(.3,.5,1.1,8),hwMat('cloth'));coat.position.y=1.55;g.add(coat);
  const head=jackO(.55,true);head.position.y=2.05;head.rotation.y=Math.PI;g.add(head);
  const hat=new THREE.Mesh(new THREE.ConeGeometry(.35,.6,10),stdMat(0x1a1218));hat.position.y=2.75;hat.rotation.z=.2;g.add(hat);const brim=new THREE.Mesh(new THREE.CylinderGeometry(.5,.5,.03,14),stdMat(0x1a1218));brim.position.y=2.47;g.add(brim);
  g.rotation.y=Math.PI;worldG.add(g);worldAnim.push(t=>{g.rotation.z=Math.sin(t*.9)*.03;});}
 // cour du manoir : puits, citrouilles sur les murets, panneau
 {const x=(cw(19)+cw(20))/2,z=(cw(7)+cw(8))/2;for(const s of [-1,1]){const p=new THREE.Mesh(new THREE.CylinderGeometry(.09,.09,2.2,6),hwMat('wood'));p.position.set(x+s*1.6,2,z);worldG.add(p);}
  const r=new THREE.Mesh(new THREE.ConeGeometry(2.5,1.1,4),hwMat('roof'));r.rotation.y=Math.PI/4;r.position.set(x,3.5,z);worldG.add(r);}
 for(const [cx,cz] of [[16,9],[23,9],[15,6],[24,6],[16,29],[23,29],[8,36],[31,36],[4,17],[10,21],[35,25],[31,4],[36,7]])hwPumpkin(cw(cx),HW_HAY,cw(cz),.55,rand(0,TAU),0);
 // jack-o'-lanterns sur le haut des murs du manoir et de la fête
 for(const x of [14,17,22,25])for(const z of [12,26])hwPumpkin(cw(x),6,cw(z),.6,z===12?0:Math.PI,0);
 for(const x of [2,6,10,14,17,22,25,29,33,37])hwPumpkin(cw(x),6,cw(33),.6,0,0);
 // fête foraine : guirlandes, lampions, grande roue en silhouette
 for(const [a,b] of [[[4,34],[17,34]],[[22,34],[36,34]],[[15,30],[24,30]],[[14,36],[25,36]]])hwGarland([cw(a[0]),5.2,cw(a[1])],[cw(b[0]),5.2,cw(b[1])],1.1,14);
 for(const [cx,cz] of [[14,34],[25,34],[2,37],[37,37],[14,30],[25,30]])lantern(cw(cx),2.6,cw(cz),0xff8a30);
 {const g=new THREE.Group();g.position.set(40,15,96);const rm=hwMat('iron');
  const rim=new THREE.Mesh(new THREE.TorusGeometry(11,.25,6,48),rm);g.add(rim);
  for(let i=0;i<16;i++){const a=i/16*TAU,sp=new THREE.Mesh(new THREE.CylinderGeometry(.1,.1,11,4),rm);sp.position.set(Math.cos(a)*5.5,Math.sin(a)*5.5,0);sp.rotation.z=a+Math.PI/2;g.add(sp);
   const b=new THREE.Mesh(new THREE.SphereGeometry(.22,6,4),new THREE.MeshBasicMaterial({color:i%2?0xff8a20:0xb04aff,toneMapped:false}));b.position.set(Math.cos(a)*11,Math.sin(a)*11,0);g.add(b);}
  for(const s of [-1,1]){const l=new THREE.Mesh(new THREE.CylinderGeometry(.3,.3,17,6),rm);l.position.set(s*4,-7,0);l.rotation.z=s*.28;worldG.add(l);l.position.add(g.position);}
  worldG.add(g);worldAnim.push(t=>{g.rotation.z=t*.06;});}
 // fête : enseigne, chapiteaux rayés, lumières chaudes au départ T
 hwScrawl('FÊTE FORAINE',40,3.6,cw(33)+1.03,0,8,'#ffb050','bold 66px Georgia');
 hwScrawl('NE VOUS RETOURNEZ PAS',40,2.2,cw(33)+1.03,0,6.5,'#b04aff','bold 38px Georgia');
 const stripe=canvasTex(128,64,(c,w,h)=>{for(let i=0;i<8;i++){c.fillStyle=i%2?'#1a0d24':'#e8701a';c.fillRect(i*w/8,0,w/8,h);}});
 for(const [cx,cz] of [[8,36],[31,36],[16,29],[23,29]]){const x=cw(cx),z=cw(cz),cn=new THREE.Mesh(new THREE.ConeGeometry(1.9,1.3,8,1,true),new THREE.MeshStandardMaterial({map:stripe,side:THREE.DoubleSide,roughness:.8}));cn.position.set(x,3.6,z);worldG.add(cn);
  for(let k=0;k<4;k++){const a=k/4*TAU+Math.PI/4,pl=new THREE.Mesh(new THREE.CylinderGeometry(.04,.04,2.95,5),hwMat('wood'));pl.position.set(x+Math.cos(a)*1.3,1.47,z+Math.sin(a)*1.3);worldG.add(pl);}}
 for(const [x,z] of [[30,74],[52,74]]){const L=new THREE.PointLight(0xff9a50,9,20,2);L.position.set(x,4,z);worldG.add(L);}
 // brume violette, chauves-souris au-dessus de la fête, éclairs
 hwFog(34,'150,120,190',[2,2,78,78]);
 hwBats(40,10,72,12,18);hwBats(12,8,12,8,8);
 hwLightning(0xc8b0ff);
};

/* ---------- décorations d'Halloween sur les autres cartes pendant l'événement ---------- */
function hwEventDeco(){
 if(!MAP||MAP.id==='manoir'||typeof eventActive!=='function'||!eventActive())return;
 // citrouilles sur le haut des murs qui bordent une zone ouverte
 const cand=[];
 for(let cz=1;cz<N-1;cz++)for(let cx=1;cx<N-1;cx++){const i=cz*N+cx;if(G_TYPE[i]!==TY.WALL||G_H[i]>7)continue;
  let open=0;for(const [dx,dz] of [[1,0],[-1,0],[0,1],[0,-1]]){const j=(cz+dz)*N+cx+dx;if(!G_TYPE[j]&&G_CEIL[j]>90)open++;}
  if(open)cand.push([cx,cz]);}
 shuffle(cand);
 const used=[];
 for(const [cx,cz] of cand){if(used.length>=16)break;if(used.some(u=>Math.abs(u[0]-cx)+Math.abs(u[1]-cz)<5))continue;used.push([cx,cz]);
  hwPumpkin(cc(cx),G_H[cz*N+cx],cc(cz),.95,rand(0,TAU),used.length<=4?2.5:0);}
 // groupes de citrouilles au pied des murs et des caisses (collées à l'obstacle pour ne pas gêner)
 const foot=[];
 for(let cz=1;cz<N-1;cz++)for(let cx=1;cx<N-1;cx++){const i=cz*N+cx;if(G_TYPE[i]||G_RAMP[i])continue;
  for(const [dx,dz] of [[1,0],[-1,0],[0,1],[0,-1]]){const t=G_TYPE[(cz+dz)*N+cx+dx];if(t===TY.WALL||t===TY.CRATE||t===TY.HOUSE){foot.push([cx,cz,dx,dz]);break;}}}
 shuffle(foot);const fu=[];
 for(const [cx,cz,dx,dz] of foot){if(fu.length>=14)break;if(fu.some(u=>Math.abs(u[0]-cx)+Math.abs(u[1]-cz)<6))continue;fu.push([cx,cz]);
  const x=cc(cx)+dx*.62,z=cc(cz)+dz*.62,y=groundH(x,z);hwPumpkin(x,y,z,.75,Math.atan2(-dx,-dz)+Math.PI,0);
  const p2=jackO(.45,false);p2.position.set(x-dz*.6+rand(-.1,.1),y,z+dx*.6);p2.rotation.y=rand(0,TAU);worldG.add(p2);}
 // petites citrouilles au pied des points de départ
 for(const s of [MAP.spawnCT[0],MAP.spawnT[0]])if(s){const x=cc(s[0])+1.2,z=cc(s[1])+.6;if(!blocked(x,z,groundH(x,z),.5))hwPumpkin(x,groundH(x,z),z,.7,rand(0,TAU),2);}
 hwBats(N*S/2,16,N*S/2,14,20);
}
const _buildWorldHw=buildWorld;
buildWorld=function(id){_buildWorldHw(id);try{hwEventDeco();}catch(e){console.warn('[halloween] décor',e);}};

/* =====================================================================
   SKINS D'ARMES D'HALLOWEEN (toutes les armes, couteau compris)
   ev:'hw' : jamais dans les caisses, gagnés avec les paliers de citrouilles
   ===================================================================== */
const HW_SKINS=[
 {n:'Bonbon d\'Halloween',tex:'hw_candy',a:'#3a1a08',fin:'gloss',q:1},
 {n:'Citrouille',tex:'hw_pumpkin',a:'#1a0c04',fin:'paint',glow:1,ge:'#ffb040',ei:1.2,q:2},
 {n:'Toile maudite',tex:'hw_web',a:'#12061a',fin:'matte',q:2},
 {n:'Ossuaire',tex:'hw_bones',a:'#141216',fin:'matte',q:2},
 {n:'Ectoplasme',tex:'hw_ecto',a:'#03100a',fin:'gloss',glow:1,ge:'#6dff6a',ei:1.1,q:3},
 {n:'Sang de vampire',tex:'hw_vampire',a:'#0a0204',fin:'gloss',q:3},
 {n:'Nuit des sorcières',tex:'hw_witch',a:'#120820',fin:'gloss',glow:1,ge:'#ffc070',ei:1,q:3}
];
for(const s of HW_SKINS){s.ev='hw';SKINS.push(s);}
const hwSkinIdx=tex=>SKINS.findIndex(s=>s.tex===tex);
function hwBone(c,x,y,L,a,col){c.save();c.translate(x,y);c.rotate(a);c.fillStyle=col;c.fillRect(-L/2,-L*.09,L,L*.18);for(const sx of [-1,1])for(const sy of [-1,1]){c.beginPath();c.arc(sx*L/2,sy*L*.1,L*.13,0,TAU);c.fill();}c.restore();}
function hwSkull(c,x,y,s,col,eye){c.fillStyle=col;c.beginPath();c.arc(x,y,s,0,TAU);c.fill();c.fillRect(x-s*.55,y+s*.5,s*1.1,s*.6);
 c.fillStyle=eye||'#120c10';c.beginPath();c.ellipse(x-s*.38,y+s*.05,s*.26,s*.3,0,0,TAU);c.ellipse(x+s*.38,y+s*.05,s*.26,s*.3,0,0,TAU);c.fill();
 c.beginPath();c.moveTo(x,y+s*.35);c.lineTo(x-s*.12,y+s*.58);c.lineTo(x+s*.12,y+s*.58);c.fill();for(let i=-2;i<=2;i++)c.fillRect(x+i*s*.2-1,y+s*.75,2,s*.32);}
function hwWitchSil(c,x,y,s,col){c.fillStyle=col;c.fillRect(x-s,y,s*2.1,s*.06);c.beginPath();c.moveTo(x+s*.9,y-s*.08);c.lineTo(x+s*1.4,y-s*.22);c.lineTo(x+s*1.36,y+s*.24);c.fill();
 c.beginPath();c.moveTo(x-s*.25,y+s*.02);c.lineTo(x-s*.05,y-s*.5);c.lineTo(x+s*.25,y+s*.02);c.fill();c.beginPath();c.arc(x-s*.05,y-s*.55,s*.12,0,TAU);c.fill();
 c.beginPath();c.moveTo(x-s*.3,y-s*.62);c.lineTo(x+s*.2,y-s*.62);c.lineTo(x-s*.12,y-s*1);c.fill();c.beginPath();c.moveTo(x-s*.1,y-s*.3);c.lineTo(x-s*.5,y-s*.2);c.lineTo(x-s*.1,y-s*.18);c.fill();}
function hwBatSil(c,x,y,s,col){c.fillStyle=col;c.beginPath();c.moveTo(x,y);c.quadraticCurveTo(x-s*.4,y-s*.45,x-s,y-s*.3);c.quadraticCurveTo(x-s*.75,y-s*.05,x-s*.8,y+s*.15);c.quadraticCurveTo(x-s*.55,y,x-s*.4,y+s*.2);c.quadraticCurveTo(x-s*.2,y+s*.05,x,y+s*.3);
 c.quadraticCurveTo(x+s*.2,y+s*.05,x+s*.4,y+s*.2);c.quadraticCurveTo(x+s*.55,y,x+s*.8,y+s*.15);c.quadraticCurveTo(x+s*.75,y-s*.05,x+s,y-s*.3);c.quadraticCurveTo(x+s*.4,y-s*.45,x,y);c.fill();}
PAINT.hw_candy=(c,w,h,g,r)=>{const cols=['#fff2dc','#ff8a1a','#ffcf2a','#ff8a1a'];
 for(let i=-8;i<16;i++){c.fillStyle=cols[((i%4)+4)%4];c.beginPath();c.moveTo(i*24,0);c.lineTo(i*24+24,0);c.lineTo(i*24+24+h*.6,h);c.lineTo(i*24+h*.6,h);c.fill();}
 const sh=c.createLinearGradient(0,0,0,h);sh.addColorStop(0,'rgba(255,255,255,.22)');sh.addColorStop(.5,'rgba(255,255,255,0)');sh.addColorStop(1,'rgba(0,0,0,.18)');c.fillStyle=sh;c.fillRect(0,0,w,h);
 for(let i=0;i<70;i++){c.fillStyle=pick(['#b04aff','#5a2a0a','#7dff5a','#ffffff']);c.save();c.translate(r(0,w),r(0,h));c.rotate(r(0,TAU));c.fillRect(-3,-1,6,2);c.restore();}};
PAINT.hw_pumpkin=(c,w,h,g,r)=>{
 if(!g){for(let x=0;x<w;x+=32){const gr=c.createLinearGradient(x,0,x+32,0);gr.addColorStop(0,'#a8420a');gr.addColorStop(.5,'#ff8a20');gr.addColorStop(1,'#a8420a');c.fillStyle=gr;c.fillRect(x,0,32,h);}
  for(let i=0;i<220;i++){c.fillStyle='rgba(90,30,0,'+r(.05,.15)+')';c.fillRect(r(0,w),r(0,h),r(1,3),r(4,14));}}
 else{c.fillStyle='#000';c.fillRect(0,0,w,h);}
 const face=(x,y,s)=>{const col=g?'#ffd060':'#1a0800';c.fillStyle=col;
  for(const sx of [-1,1]){c.beginPath();c.moveTo(x+sx*s*.42-s*.2,y-s*.05);c.lineTo(x+sx*s*.42+s*.2,y-s*.05);c.lineTo(x+sx*s*.42,y-s*.38);c.fill();}
  c.beginPath();c.moveTo(x,y+s*.05);c.lineTo(x-s*.1,y+s*.2);c.lineTo(x+s*.1,y+s*.2);c.fill();
  c.beginPath();c.moveTo(x-s*.7,y+s*.3);for(let i=0;i<=8;i++)c.lineTo(x-s*.7+i*s*.175,y+s*.3+(i%2?s*.14:0));c.quadraticCurveTo(x,y+s*.95,x-s*.7,y+s*.3);c.fill();
  if(!g){c.fillStyle='rgba(255,200,80,.55)';c.beginPath();c.arc(x,y+s*.45,s*.12,0,TAU);c.fill();}};
 face(w*.27,h*.3,44);face(w*.75,h*.72,44);face(w*.78,h*.18,26);face(w*.2,h*.8,26);};
PAINT.hw_web=(c,w,h,g,r)=>{c.fillStyle=grad(c,0,0,w,h,[[0,'#3a0f52'],[.6,'#160622'],[1,'#07020a']]);c.fillRect(0,0,w,h);
 const web=(cx,cy,R,n)=>{c.strokeStyle='rgba(235,230,250,.7)';c.lineWidth=1.3;for(let i=0;i<n;i++){const a=i/n*TAU;c.beginPath();c.moveTo(cx,cy);c.lineTo(cx+Math.cos(a)*R,cy+Math.sin(a)*R);c.stroke();}
  for(let rr=R/7;rr<R;rr+=R/7){c.beginPath();for(let i=0;i<=n;i++){const a=i/n*TAU,x=cx+Math.cos(a)*rr,y=cy+Math.sin(a)*rr;if(!i)c.moveTo(x,y);else{const am=(i-.5)/n*TAU;c.quadraticCurveTo(cx+Math.cos(am)*rr*.86,cy+Math.sin(am)*rr*.86,x,y);}}c.stroke();}};
 web(w*.3,h*.35,110,12);web(w*.85,h*.85,80,10);web(w*.9,h*.1,50,9);
 for(let i=0;i<6;i++){const x=r(20,w-20),y=r(20,h-20);c.strokeStyle='rgba(235,230,250,.5)';c.beginPath();c.moveTo(x,0);c.lineTo(x,y);c.stroke();c.fillStyle='#050205';c.beginPath();c.ellipse(x,y,6,8,0,0,TAU);c.fill();c.strokeStyle='#050205';c.lineWidth=1.5;for(let k=0;k<4;k++)for(const s of [-1,1]){c.beginPath();c.moveTo(x,y-2+k*2);c.lineTo(x+s*12,y-6+k*5);c.stroke();}c.fillStyle='#ff2030';c.fillRect(x-1,y+1,2,2);}
 if(!g)scratches(c,w,h,r,10);};
PAINT.hw_bones=(c,w,h,g,r)=>{c.fillStyle='#16131a';c.fillRect(0,0,w,h);for(let i=0;i<400;i++){c.fillStyle='rgba(255,255,255,'+r(.01,.04)+')';c.fillRect(r(0,w),r(0,h),r(1,3),r(1,3));}
 for(let i=0;i<26;i++)hwBone(c,r(0,w),r(0,h),r(26,46),r(0,TAU),pick(['#e8dcc0','#d8c8a4','#f0e6d0']));
 for(let i=0;i<7;i++)hwSkull(c,r(20,w-20),r(20,h-20),r(11,17),pick(['#efe4c8','#e0d2b0']));
 if(!g)scratches(c,w,h,r,16);};
PAINT.hw_ecto=(c,w,h,g,r)=>{c.fillStyle=g?'#000':grad(c,0,0,0,h,[[0,'#0a2a1c'],[1,'#030c08']]);c.fillRect(0,0,w,h);
 for(let i=0;i<16;i++){const x=r(0,w),L=r(40,h*.9),wd=r(8,18),col=g?'#7dff6a':'#3ad84a';c.fillStyle=col;c.fillRect(x-wd/2,0,wd,L);c.beginPath();c.arc(x,L,wd*.75,0,TAU);c.fill();
  if(!g){c.fillStyle='rgba(200,255,190,.45)';c.fillRect(x-wd/2+2,0,2,L*.9);}}
 c.fillStyle=g?'#5aff5a':'#2bb83a';c.fillRect(0,0,w,14);for(let i=0;i<30;i++){const x=r(0,w),y=r(20,h),s=r(2,6);c.beginPath();c.arc(x,y,s,0,TAU);c.fill();}
 if(!g)scratches(c,w,h,r,10);};
PAINT.hw_vampire=(c,w,h,g,r)=>{c.fillStyle=grad(c,0,0,w,h,[[0,'#1a0408'],[.5,'#080204'],[1,'#120206']]);c.fillRect(0,0,w,h);
 for(let i=0;i<12;i++)hwBatSil(c,r(10,w-10),r(h*.35,h-10),r(14,26),'rgba(120,8,20,.75)');
 for(let i=0;i<18;i++){const x=r(0,w),L=r(20,h*.55),wd=r(4,10),gr=c.createLinearGradient(0,0,0,L);gr.addColorStop(0,'#8a0010');gr.addColorStop(1,'#d01020');c.fillStyle=gr;c.fillRect(x-wd/2,0,wd,L);c.beginPath();c.arc(x,L,wd*.8,0,TAU);c.fill();c.fillStyle='rgba(255,140,140,.4)';c.fillRect(x-wd/2+1,0,1.5,L*.9);}
 c.fillStyle='#a00818';c.fillRect(0,0,w,10);
 const sh=c.createLinearGradient(0,0,w,h);sh.addColorStop(0,'rgba(255,255,255,0)');sh.addColorStop(.48,'rgba(255,255,255,.08)');sh.addColorStop(.52,'rgba(255,255,255,0)');c.fillStyle=sh;c.fillRect(0,0,w,h);};
PAINT.hw_witch=(c,w,h,g,r)=>{
 if(!g){c.fillStyle=grad(c,0,0,0,h,[[0,'#0c0420'],[.55,'#3a1458'],[.85,'#c0502a'],[1,'#ff9a3a']]);c.fillRect(0,0,w,h);}else{c.fillStyle='#000';c.fillRect(0,0,w,h);}
 for(let i=0;i<60;i++){c.fillStyle=g?'#fff2c0':'rgba(255,255,230,'+r(.4,1)+')';const s=r(1,2.4);c.fillRect(r(0,w),r(0,h*.6),s,s);}
 const mg=c.createRadialGradient(w*.62,h*.36,4,w*.62,h*.36,52);mg.addColorStop(0,g?'#ffe0a0':'#fff2cc');mg.addColorStop(.8,g?'#ff9a3a':'#ffb050');mg.addColorStop(1,'rgba(255,150,60,0)');c.fillStyle=mg;c.beginPath();c.arc(w*.62,h*.36,52,0,TAU);c.fill();
 hwWitchSil(c,w*.6,h*.4,40,'#06020a');for(let i=0;i<5;i++)hwBatSil(c,r(20,w*.4),r(20,h*.5),r(6,10),'#06020a');
 c.fillStyle='#06020a';for(let x=0;x<w;x+=r(14,26)){const hh=r(10,24);c.fillRect(x,h-hh,10,hh);c.beginPath();c.arc(x+5,h-hh,5,Math.PI,0);c.fill();}
 c.beginPath();c.moveTo(0,h);for(let x=0;x<=w;x+=16)c.lineTo(x,h-6-Math.sin(x*.05)*4);c.lineTo(w,h);c.fill();};

/* ---------- tenues d'Halloween ---------- */
OUTFITS.push(
 {n:'Tête de citrouille',q:3,ev:'hw',shirt:['stripes','#1a1218','#e8701a'],pants:['solid','#1a1218'],vest:'#2a1a2a',helm:'#e8701a',glove:'#1a1218',boot:'#120c10',acc:'#ffb030',glow:true,head:'pumpkin'},
 {n:'Faucheuse',q:3,ev:'hw',shirt:['solid','#0e0c12'],pants:['solid','#0e0c12'],vest:'#16131c',helm:'#0e0c12',glove:'#e8e0d0',boot:'#0a090c',acc:'#6dff7a',glow:true,head:'reaper'}
);
const hwOutfitIdx=n=>OUTFITS.findIndex(o=>o.n===n);
const _buildOutfitHeadHw=buildOutfitHead;
buildOutfitHead=function(R,M,O){
 const H=R.head;
 if(O.head==='pumpkin'){const p=jackO(.36,true);p.position.set(0,-.16,0);H.add(p);return;}
 if(O.head==='reaper'){
  const hood=new THREE.Mesh(new THREE.SphereGeometry(1,20,14,Math.PI*.62,Math.PI*.76,0,Math.PI*.92),M.helm);hood.scale.set(.19,.2,.2);hood.position.set(0,.01,.02);H.add(hood);
  const peak=new THREE.Mesh(new THREE.ConeGeometry(.1,.14,10),M.helm);peak.position.set(0,.2,.05);peak.rotation.x=.5;H.add(peak);
  const bone=hwMat('bone');H.add(ball(new THREE.SphereGeometry(1,16,12),bone,0,.005,-.015,.12,.13,.125));
  H.add(rb(.12,.05,.07,bone,0,-.11,-.08,.015));
  for(const s of [-1,1]){H.add(ball(new THREE.SphereGeometry(1,10,8),M.blk,s*.045,.02,-.115,.034,.04,.02));H.add(ball(new THREE.SphereGeometry(1,8,6),M.accent,s*.045,.02,-.13,.012,.012,.01));}
  return;
 }
 _buildOutfitHeadHw(R,M,O);
};
HWM.bone=new THREE.MeshStandardMaterial({color:C(0xeee2c4),roughness:.6});

/* ---------- ni dans les caisses, ni dans le passe : uniquement l'événement ---------- */
const _lootPoolHw=lootPool;
lootPool=function(){return _lootPoolHw().filter(i=>!(i.t==='skin'&&SKINS[i.s].ev)&&!(i.t==='outfit'&&OUTFITS[i.o].ev));};
const hwPk=()=>PROF.ev&&PROF.ev.id===EVENT.id?PROF.ev.pk:0;
const _skinLockTxtHw=skinLockTxt;
skinLockTxt=function(k,i){const s=SKINS[i];if(s&&s.ev){const g=EVENT.goals.find(g=>(g.r.hw||[]).some(x=>x.t==='skin'&&x.tex===s.tex));
 return 'Skin d\'Halloween : '+(eventActive()?'ramasse '+(g?g.n:'?')+' citrouilles pendant l\'événement ('+hwPk()+'/'+(g?g.n:'?')+')':'événement terminé');}
 return _skinLockTxtHw(k,i);};

/* =====================================================================
   PALIERS DE CITROUILLES : récompenses d'Halloween
   ===================================================================== */
const HW_GOALS=[
 [5,[{t:'skin',tex:'hw_candy'}]],
 [10,[{t:'skin',tex:'hw_pumpkin'}]],
 [15,[{t:'fx',id:'bats'}]],
 [25,[{t:'skin',tex:'hw_web'}]],
 [35,[{t:'outfit',n:'Tête de citrouille'}]],
 [50,[{t:'skin',tex:'hw_bones'}]],
 [60,[{t:'fx',id:'soul'}]],
 [70,[{t:'skin',tex:'hw_ecto'}]],
 [85,[{t:'fx',id:'grave'},{t:'skin',tex:'hw_vampire'}]],
 [100,[{t:'outfit',n:'Faucheuse'},{t:'skin',tex:'hw_witch'}]]
];
for(const [n,hw] of HW_GOALS){const g=EVENT.goals.find(g=>g.n===n);if(g)g.r.hw=hw;else EVENT.goals.push({n,r:{hw}});}
EVENT.goals.sort((a,b)=>a.n-b.n);
const _applyRewardHw=applyReward;
applyReward=function(r){_applyRewardHw(r);
 for(const it of r.hw||[]){
  if(it.t==='skin'){const i=hwSkinIdx(it.tex);if(i>0)for(const k in W)if(!W[k].wonder)grantItem({t:'skin',w:k,s:i});}
  else if(it.t==='outfit'){const i=hwOutfitIdx(it.n);if(i>0)grantItem({t:'outfit',o:i});}
 }};
const _rewardTextHw=rewardText;
rewardText=function(r){const a=[];const b=_rewardTextHw(r);if(b)a.push(b);
 for(const it of r.hw||[]){if(it.t==='skin')a.push('Skin '+SKINS[hwSkinIdx(it.tex)].n);else if(it.t==='outfit')a.push('Tenue '+it.n);else if(it.t==='fx'){const f=KILLFX.find(f=>f.id===it.id);a.push('Effet '+(f?f.n:it.id));}}
 return a.join(' • ');};
// rattrapage : paliers déjà atteints avant la mise à jour
(function(){if(!eventActive()||!PROF.ev||PROF.ev.id!==EVENT.id)return;let ch=false;
 for(const g of EVENT.goals)if(PROF.ev.pk>=g.n&&g.r.hw){const tag='hw'+g.n;if(!PROF.ev.claimed.includes(tag)){PROF.ev.claimed.push(tag);applyReward({hw:g.r.hw});ch=true;}}
 if(ch)saveProf();})();

/* =====================================================================
   EFFETS D'ÉLIMINATION D'HALLOWEEN
   ===================================================================== */
KILLFX.find(f=>f.id==='pumpkin').d='Événement d\'Halloween : des citrouilles sculptées rebondissent dans une gerbe de flammes.';
KILLFX.push(
 {id:'bats',n:'Nuée de chauves-souris',lv:1,ev:true,pk:15,c:'#b04aff',d:'Événement d\'Halloween : une nuée de chauves-souris s\'échappe de l\'adversaire.'},
 {id:'soul',n:'Âme damnée',lv:1,ev:true,pk:60,c:'#6dff7a',d:'Événement d\'Halloween : un crâne spectral vert s\'élève en spirale.'},
 {id:'grave',n:'Pierre tombale',lv:1,ev:true,pk:85,c:'#c8c8d0',d:'Événement d\'Halloween : une tombe à son nom sort de terre.'}
);
killFxOwned=function(f){return f.ev?(typeof eventActive==='function'&&eventActive()&&hwPk()>=(f.pk||0)):levelInfo().level>=f.lv;};
// citrouille dessinée (l'émoji ne s'affiche pas partout)
KFX.tex.pumpkin=canvasTex(64,64,(c)=>{
 for(let i=0;i<5;i++){const x=14+i*9,g=c.createRadialGradient(x,36,2,x,36,16);g.addColorStop(0,'#ffa040');g.addColorStop(1,'#c0500c');c.fillStyle=g;c.beginPath();c.ellipse(x,36,10,20,0,0,TAU);c.fill();}
 c.fillStyle='#4a5a22';c.fillRect(30,10,5,9);c.fillStyle='#ffe070';
 c.beginPath();c.moveTo(20,32);c.lineTo(28,32);c.lineTo(24,24);c.fill();c.beginPath();c.moveTo(36,32);c.lineTo(44,32);c.lineTo(40,24);c.fill();
 c.beginPath();c.moveTo(18,40);for(let i=0;i<=7;i++)c.lineTo(18+i*4,i%2?44:40);c.quadraticCurveTo(32,54,18,40);c.fill();});
const HWK=[];
function hwSkullTex(){return cached('hwskull',()=>canvasTex(64,64,(c)=>{
 const g=c.createRadialGradient(32,30,4,32,30,30);g.addColorStop(0,'rgba(200,255,200,.95)');g.addColorStop(1,'rgba(80,255,120,.2)');
 hwSkull(c,32,28,18,'rgba(190,255,200,.95)','#0a3a18');c.globalCompositeOperation='destination-over';c.fillStyle=g;c.beginPath();c.arc(32,32,30,0,TAU);c.fill();}));}
function hwTempLight(x,y,z,col,I,life){const L=new THREE.PointLight(col,I,12,2);L.position.set(x,y,z);scene.add(L);HWK.push({t:0,up(dt){this.t+=dt;L.intensity=I*Math.max(0,1-this.t/life);if(this.t>=life){scene.remove(L);return false;}return true;},kill(){scene.remove(L);}});}
function hwSnd(kind,x,z){
 if(!AC)return;const p=x!==undefined?panOf(x,z):{d:0,pan:0},v=Math.pow(clamp(1-p.d/70,0,1),1.4);if(v<.02)return;
 if(kind==='bats'){for(let i=0;i<7;i++)tn(rand(2600,4200),.07,'square',.05*v,p.pan,rand(1800,3000),.2,i*rand(.04,.09));nz(.5,3000,'bandpass',.12*v,p.pan,.3,3);}
 else if(kind==='soul'){tn(330,1.4,'sine',.22*v,p.pan,660,.6);tn(338,1.4,'triangle',.12*v,p.pan,520,.6,.05);tn(220,1.1,'sine',.15*v,p.pan,140,.5,.3);}
 else if(kind==='grave'){tn(70,.6,'sine',.5*v,p.pan,35,.3);nz(.5,400,'lowpass',.45*v,p.pan,.3);tn(196,2.2,'triangle',.18*v,p.pan,0,.7,.45);tn(392,1.6,'sine',.08*v,p.pan,0,.7,.45);}
}
const HWFX={
 bats(v){
  const x=v.x,y=v.y+1.1,z=v.z,tex=hwBatTex();
  for(let i=0;i<22;i++){const s=new THREE.Sprite(new THREE.SpriteMaterial({map:tex,transparent:true,depthWrite:false}));const sz=rand(.55,.85);s.scale.set(sz,sz/2,1);s.position.set(x+rand(-.2,.2),y+rand(-.4,.3),z+rand(-.2,.2));scene.add(s);
   const a=rand(0,TAU),sp=rand(1.2,2.8),vy=rand(1,2.6),sw=rand(-3,3),fl=rand(16,24),life=rand(1.4,2.2);
   HWK.push({t:0,up(dt){this.t+=dt;const k=this.t;const aa=a+sw*k*.4;s.position.x+=Math.cos(aa)*sp*dt;s.position.z+=Math.sin(aa)*sp*dt;s.position.y+=vy*dt*(1-k/life*.5);s.scale.y=sz/2*(.3+.7*Math.abs(Math.sin(k*fl)));s.material.opacity=Math.min(1,(life-k)/.4);if(k>=life){scene.remove(s);s.material.dispose();return false;}return true;},kill(){scene.remove(s);}});}
  for(let i=0;i<10;i++)kfxPart(x+rand(-.3,.3),y+rand(-.6,.3),z+rand(-.3,.3),{map:GLOW.white,col:0x8a3dff,add:true,size:rand(.5,.9),vy:rand(.3,.9),g:0,life:rand(.7,1.2),grow:-.4});
  hwSnd('bats',x,z);
 },
 soul(v){
  const x=v.x,y=v.y+1,z=v.z;
  const s=new THREE.Sprite(new THREE.SpriteMaterial({map:hwSkullTex(),transparent:true,depthWrite:false,blending:THREE.AdditiveBlending,toneMapped:false}));s.position.set(x,y,z);s.scale.setScalar(.5);scene.add(s);
  HWK.push({t:0,up(dt){this.t+=dt;const k=this.t;s.position.set(x+Math.cos(k*5)*.35*k,y+k*1.3,z+Math.sin(k*5)*.35*k);s.scale.setScalar(.5+k*.45);s.material.opacity=Math.min(1,(2.4-k)/.6);if(k>=2.4){scene.remove(s);return false;}return true;},kill(){scene.remove(s);}});
  for(let i=0;i<36;i++){const a=i/36*TAU*3,r=rand(.2,.6);kfxPart(x+Math.cos(a)*r,y-.8+i*.05,z+Math.sin(a)*r,{map:GLOW.white,col:pick([0x6dff7a,0x3aff9a,0xb8ffb0]),add:true,size:rand(.15,.35),vx:-Math.sin(a)*1.2,vz:Math.cos(a)*1.2,vy:rand(1,2.4),g:0,drag:.8,life:rand(1,1.8),grow:-.1});}
  hwTempLight(x,y+.5,z,0x6dff7a,6,1.6);hwSnd('soul',x,z);
 },
 grave(v){
  const dx=v.x-P.x,dz=v.z-P.z,dl=Math.hypot(dx,dz)||1,x=v.x+dx/dl*.9,z=v.z+dz/dl*.9,y0=groundH(x,z),g=new THREE.Group(),st=hwMat('stone');
  hwTempLight(x-dx/dl*.8,y0+1.4,z-dz/dl*.8,0x9affb0,7,3.2);
  const b=new THREE.Mesh(GBOX,st);b.scale.set(.8,.75,.2);b.position.y=.375;const top=new THREE.Mesh(new THREE.CylinderGeometry(.4,.4,.2,18),st);top.rotation.x=Math.PI/2;top.position.y=.75;g.add(b,top);
  const nm=String(v.name||'').slice(0,12).toUpperCase(),t=canvasTex(256,256,(c,w,h)=>{c.fillStyle='#2a2a2e';c.font='bold 64px Georgia';c.textAlign='center';c.fillText('R.I.P.',w/2,110);c.font='bold '+(nm.length>8?30:40)+'px Georgia';c.fillText(nm,w/2,170);c.fillRect(w/2-50,190,100,4);});
  const pl=new THREE.Mesh(new THREE.PlaneGeometry(.75,.75),new THREE.MeshBasicMaterial({map:t,transparent:true,depthWrite:false}));pl.position.set(0,.55,.105);g.add(pl);
  const pl2=pl.clone();pl2.position.z=-.105;pl2.rotation.y=Math.PI;g.add(pl2);
  g.rotation.y=Math.atan2(P.x-x,P.z-z)+rand(-.2,.2);g.rotation.z=rand(-.08,.08);g.position.set(x,y0-1.1,z);scene.add(g);
  HWK.push({t:0,up(dt){this.t+=dt;const k=this.t;g.position.y=y0+(k<.45?-1.1+1.1*(1-Math.pow(1-k/.45,3)):k>2.6?-1.1*Math.min(1,(k-2.6)/.6):0);if(k>=3.2){scene.remove(g);t.dispose();return false;}return true;},kill(){scene.remove(g);}});
  for(let i=0;i<26;i++){const a=rand(0,TAU),sp=rand(1,3);kfxPart(x,y0+.1,z,{col:pick([0x4a3a28,0x2e241a,0x5a4a32]),size:rand(.08,.16),vx:Math.cos(a)*sp,vz:Math.sin(a)*sp,vy:rand(2,4.5),g:-12,life:rand(.6,1.1)});}
  for(let i=0;i<10;i++)kfxPart(x+rand(-.6,.6),y0+.2,z+rand(-.6,.6),{map:GLOW.white,col:0x4a9a60,add:true,size:rand(.5,.9),vy:rand(.1,.4),g:0,life:rand(1.5,2.5),grow:.2});
  G.shake=Math.max(G.shake,.18);hwSnd('grave',x,z);
 }
};
const _killFxHw=killFx;
killFx=function(v,id){
 const f=id?KILLFX.find(x=>x.id===id):killFxCur();if(!f||!v)return;
 if(HWFX[f.id]){HWFX[f.id](v);return;}
 _killFxHw(v,id);
 if(f.id==='pumpkin'){for(let i=0;i<14;i++)kfxPart(v.x+rand(-.3,.3),v.y+rand(.2,1.2),v.z+rand(-.3,.3),{map:GLOW.orange,col:pick([0xffa040,0xff6a20]),add:true,size:rand(.35,.6),vy:rand(1,2.5),g:1,life:rand(.5,.9),grow:-.3});hwTempLight(v.x,v.y+1,v.z,0xff8a30,5,.9);}
};
const _updateFXHw=updateFX;
updateFX=function(dt,t){_updateFXHw(dt,t);for(let i=HWK.length-1;i>=0;i--)if(!HWK[i].up(dt))HWK.splice(i,1);};
const _resetFXHw=resetFX;
resetFX=function(){_resetFXHw();for(const k of HWK)k.kill();HWK.length=0;};

/* ---------- multijoueur : chacun voit les effets des autres joueurs ---------- */
const _netSendHw=netSend;
netSend=function(m,to){if(m&&m.t==='hello')m.kfx=killFxCur().id;return _netSendHw(m,to);};
const _netHostMsgHw=netHostMsg;
netHostMsg=function(m,from){_netHostMsgHw(m,from);if(m&&m.t==='hello'&&typeof m.kfx==='string'){const p=NET.players.get(from);if(p&&KILLFX.some(f=>f.id===m.kfx))p.kfx=m.kfx;}};
const hwRemoteFx=e=>{const p=e&&e.remote&&NET.players.get(e.remote);return p&&p.kfx||null;};
const _netEventHw=netEvent;
netEvent=function(e){if(e&&e.t==='feed'){const a=ents.find(x=>x.id===e.a);const fx=a&&(a.isPlayer?killFxCur().id:hwRemoteFx(a));if(fx&&fx!=='none')e.fx=fx;}_netEventHw(e);};
const _netClientEventHw=netClientEvent;
netClientEvent=function(ev){_netClientEventHw(ev);
 if(ev&&ev.t==='feed'&&ev.a!==ev.v){const a=netById(ev.a),v=netById(ev.v);if(!v)return;const fx=a===P?killFxCur().id:ev.fx;if(fx&&fx!=='none')killFx(v,fx);}};
const _killEntHw=killEnt;
killEnt=function(v,att,w,hs){
 const was=v.alive;_killEntHw(v,att,w,hs);
 if(!was||v.alive||!att||att===v||v.dummy)return;
 // l'hôte voit aussi l'effet d'un joueur distant
 if(att.remote){const fx=hwRemoteFx(att);if(fx&&fx!=='none')killFx(v,fx);}
 // pendant l'événement, un adversaire éliminé lâche parfois une citrouille
 if(att.isPlayer&&eventActive()&&G.variant!=='train'&&Math.random()<.25&&PUMPK.length<12){
  const y=groundH(v.x,v.z),m=pumpkinMesh();m.position.set(v.x,y,v.z);scene.add(m);PUMPK.push({m,x:v.x,z:v.z,y,ph:rand(0,6)});
 }
};

/* ---------- ambiance sonore du Manoir hanté : corbeaux, loups, chouette ---------- */
let hwAmbT=8;
function hwAmbient(dt){
 if(!AC||!G.running||!MAP||MAP.id!=='manoir')return;hwAmbT-=dt;if(hwAmbT>0)return;hwAmbT=rand(10,22);
 const k=pick(['crow','wolf','owl']),pan=rand(-.8,.8);
 if(k==='crow')for(let i=0;i<3;i++){nz(.18,1200,'bandpass',.12,pan,.4,4,i*.32);tn(rand(700,820),.16,'sawtooth',.035,pan,480,.4,i*.32);}
 else if(k==='wolf'){tn(380,2.6,'sine',.09,pan,640,.7);tn(640,1.4,'sine',.07,pan,420,.7,2.4);tn(760,2.6,'triangle',.025,pan,1280,.7);}
 else{tn(420,.35,'sine',.08,pan,360,.6);tn(400,.6,'sine',.08,pan,330,.6,.5);}
}
const _pumpkinUpdateHw=pumpkinUpdate;
pumpkinUpdate=function(dt){_pumpkinUpdateHw(dt);hwAmbient(dt);};
