/* =====================================================================
   EFFETS DE TIR (v2)
   - balles traçantes en volume qui voyagent réellement (tête brillante
     + traînée qui s'efface), visibles sous tous les angles
   - impacts : éclair, gerbe d'étincelles, poussière et éclats selon la
     surface, impact sur cible (sang / étincelles bleues du bouclier)
   - flash de bouche en 3D pour tous les tireurs (bots compris)
   ===================================================================== */
const FX2={streaks:[],flashes:[],ready:false,tex:null,ftex:null,geo:null,idx:0,fidx:0};
function fx2Init(){
 if(FX2.ready)return;FX2.ready=true;
 // dégradé : tête blanche brillante -> traînée transparente
 FX2.tex=canvasTex(16,128,(c,w,h)=>{const g=c.createLinearGradient(0,0,0,h);g.addColorStop(0,'rgba(255,255,255,1)');g.addColorStop(.06,'rgba(255,240,200,.95)');g.addColorStop(.35,'rgba(255,190,90,.45)');g.addColorStop(1,'rgba(255,150,40,0)');c.fillStyle=g;c.fillRect(0,0,w,h);
  const r=c.createLinearGradient(0,0,w,0);r.addColorStop(0,'rgba(0,0,0,1)');r.addColorStop(.5,'rgba(0,0,0,0)');r.addColorStop(1,'rgba(0,0,0,1)');c.globalCompositeOperation='destination-out';c.fillStyle=r;c.fillRect(0,0,w,h);});
 FX2.ftex=canvasTex(64,64,(c,w,h)=>{const g=c.createRadialGradient(32,32,0,32,32,32);g.addColorStop(0,'rgba(255,255,240,1)');g.addColorStop(.25,'rgba(255,210,120,.9)');g.addColorStop(.6,'rgba(255,120,30,.35)');g.addColorStop(1,'rgba(255,80,0,0)');c.fillStyle=g;c.fillRect(0,0,w,h);
  c.globalCompositeOperation='lighter';c.strokeStyle='rgba(255,230,170,.8)';c.lineWidth=3;for(let i=0;i<6;i++){const a=i/6*TAU+.3;c.beginPath();c.moveTo(32,32);c.lineTo(32+Math.cos(a)*30,32+Math.sin(a)*30);c.stroke();}});
 FX2.geo=new THREE.CylinderGeometry(1,1,1,6,1,true);FX2.geo.rotateX(Math.PI/2);FX2.geo.translate(0,0,-.5); // axe -Z, origine = tête
 for(let i=0;i<56;i++){
  const m=new THREE.Mesh(FX2.geo,new THREE.MeshBasicMaterial({map:FX2.tex,color:0xffd28a,transparent:true,blending:THREE.AdditiveBlending,depthWrite:false,toneMapped:false,side:THREE.DoubleSide}));
  m.visible=false;m.frustumCulled=false;scene.add(m);FX2.streaks.push({m,on:false});
 }
 for(let i=0;i<16;i++){
  const s=new THREE.Sprite(new THREE.SpriteMaterial({map:FX2.ftex,blending:THREE.AdditiveBlending,transparent:true,depthWrite:false,toneMapped:false}));
  s.visible=false;scene.add(s);FX2.flashes.push({s,t:0,life:.05,size:1});
 }
}
const _fv=new THREE.Vector3(),_fq=new THREE.Quaternion(),_fz=new THREE.Vector3(0,0,-1);
/* remplace la traçante d'origine : une vraie balle qui file vers la cible */
function addTracer(x0,y0,z0,x1,y1,z1,col){
 if(!fxReady)return;fx2Init();
 if(typeof rpTracer==='function')rpTracer(x0,y0,z0,x1,y1,z1,col);
 const dx=x1-x0,dy=y1-y0,dz=z1-z0,L=Math.hypot(dx,dy,dz);if(L<.5)return;
 const s=FX2.streaks[FX2.idx++%FX2.streaks.length];
 s.on=true;s.x0=x0;s.y0=y0;s.z0=z0;s.dx=dx/L;s.dy=dy/L;s.dz=dz/L;s.L=L;s.d=0;s.speed=col!==undefined&&col!==null&&W.raygun&&col===0x4dff6a?120:420;s.fade=0;
 s.len=Math.min(L,col!==undefined&&col!==null?6:4.5);s.w=col!==undefined&&col!==null?.03:.018;
 s.m.material.color.setHex(col!==undefined&&col!==null?col:0xffd28a);s.m.material.opacity=1;
 _fv.set(s.dx,s.dy,s.dz);_fq.setFromUnitVectors(_fz,_fv);s.m.quaternion.copy(_fq);s.m.visible=true;
}
function muzzleFlash3D(x,y,z,size){
 if(!fxReady)return;fx2Init();
 const f=FX2.flashes[FX2.fidx++%FX2.flashes.length];f.s.position.set(x,y,z);f.t=0;f.life=.05;f.size=size||.55;f.s.visible=true;f.s.material.rotation=Math.random()*TAU;
}
/* impact sur surface : éclair + étincelles + poussière + éclats */
function impactFX(x,y,z,d,surf){
 if(!fxReady)return;fx2Init();
 const f=FX2.flashes[FX2.fidx++%FX2.flashes.length];f.s.position.set(x,y,z);f.t=0;f.life=.06;f.size=.35;f.s.visible=true;
 const n=Math.ceil((surf==='metal'?10:5)*fxMul());
 for(let i=0;i<n;i++){const s=rand(2,6);fxA.emit(x,y,z,-d[0]*s*.6+rand(-1,1)*s*.5,-d[1]*s*.4+rand(.2,1.4)*s*.5,-d[2]*s*.6+rand(-1,1)*s*.5,rand(.12,.35),.045,.015,1,.82,.45,1,10,.4);}
 const dc=surf==='snow'?[.95,.97,1]:surf==='sand'?[.82,.7,.52]:surf==='metal'?[.5,.5,.52]:[.62,.6,.56];
 for(let i=0;i<Math.ceil(5*fxMul());i++)fxN.emit(x,y,z,-d[0]*rand(.6,1.8)+rand(-.4,.4),-d[1]*rand(.3,1)+rand(.1,.7),-d[2]*rand(.6,1.8)+rand(-.4,.4),rand(.5,1.1),.06,.32,dc[0],dc[1],dc[2],.5,-.15,1.8);
 for(let i=0;i<Math.ceil(4*fxMul());i++)fxN.emit(x,y,z,-d[0]*rand(2,4)+rand(-1.5,1.5),rand(1,3),-d[2]*rand(2,4)+rand(-1.5,1.5),rand(.4,.8),.035,.03,dc[0]*.6,dc[1]*.6,dc[2]*.6,1,14,.2);
}
/* impact sur une cible vivante */
function bodyHitFX(x,y,z,d,shield,hs){
 if(!fxReady)return;
 if(shield){for(let i=0;i<10;i++){const s=rand(1.5,4);fxA.emit(x,y,z,-d[0]*s+rand(-1,1)*s*.6,rand(-.5,1.5)*s*.5,-d[2]*s+rand(-1,1)*s*.6,rand(.15,.35),.07,.02,.3,.8,1,1,4,.6);}return;}
 for(let i=0;i<(hs?10:5);i++)fxN.emit(x,y,z,d[0]*rand(.5,2)+rand(-.6,.6),rand(-.2,.8),d[2]*rand(.5,2)+rand(-.6,.6),rand(.25,.5),.05,hs?.4:.28,.55,.03,.04,.75,2,1.5);
}
function fx2Update(dt){
 if(!FX2.ready)return;
 for(const s of FX2.streaks){
  if(!s.on)continue;
  s.d+=s.speed*dt;
  if(s.d>=s.L){s.fade+=dt;s.d=s.L;s.m.material.opacity=Math.max(0,1-s.fade/.05);if(s.fade>.05){s.on=false;s.m.visible=false;continue;}}
  const len=Math.min(s.len,s.d);
  s.m.position.set(s.x0+s.dx*s.d,s.y0+s.dy*s.d,s.z0+s.dz*s.d);
  // épaisseur constante à l'écran (plus large au loin)
  const cd=Math.max(1,Math.hypot(s.m.position.x-camera.position.x,s.m.position.y-camera.position.y,s.m.position.z-camera.position.z));
  const w=s.w*Math.min(3,.6+cd*.06);s.m.scale.set(w,w,Math.max(.05,len));
 }
 for(const f of FX2.flashes){if(!f.s.visible)continue;f.t+=dt;const k=f.t/f.life;if(k>=1){f.s.visible=false;continue;}const sz=f.size*(1+k*.6);f.s.scale.set(sz,sz,1);f.s.material.opacity=1-k;}
}
