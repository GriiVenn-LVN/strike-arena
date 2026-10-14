/* =====================================================================
   ARRIVÉE EN VÉHICULE (cartes intérieures : métro, laboratoire, asile…)
   Au lieu de l'hélicoptère, l'équipe arrive en blindé de transport sur
   une route longeant la carte : plan extérieur, vue assise à l'intérieur
   avec les coéquipiers sur les banquettes, freinage, portes arrière qui
   s'ouvrent, descente, puis fondu vers le point de départ.
   Réutilise CINE (65_cine.js) : CINE.heli porte le véhicule, CINE.seats
   les coéquipiers, endCine() remet tout en place.
   ===================================================================== */
const CAR_INDOOR={metro:1,labo:1,asile:1};
function carWanted(){return !!(MAP&&(CAR_INDOOR[MAP.id]||ceilAt(P.x,P.z)<90));}
function carPaintTex(){return cached('carPaint',()=>canvasTex(128,128,(c,w,h)=>{
 c.fillStyle='#2a2f2a';c.fillRect(0,0,w,h);
 for(let i=0;i<1400;i++){c.fillStyle='rgba('+(Math.random()<.5?'255,255,255':'0,0,0')+','+rand(.02,.06)+')';c.fillRect(rand(0,w),rand(0,h),rand(.5,1.5),rand(.5,1.5));}
 blotches(c,w,h,10,'90,80,60',.12,6,22);   // poussière
 c.fillStyle='rgba(0,0,0,.45)';for(let y=8;y<h;y+=30)for(let x=6;x<w;x+=30){c.beginPath();c.arc(x,y,1.3,0,TAU);c.fill();}   // rivets du blindage
},true));}
function carInTex(){return cached('carIn',()=>canvasTex(128,128,(c,w,h)=>{
 c.fillStyle='#4a4f55';c.fillRect(0,0,w,h);
 for(let y=0;y<h;y+=32){c.fillStyle='rgba(0,0,0,.35)';c.fillRect(0,y,w,2);c.fillStyle='rgba(255,255,255,.08)';c.fillRect(0,y+2,w,1);}
 for(let y=6;y<h;y+=32)for(let x=6;x<w;x+=16){c.fillStyle='rgba(20,20,20,.6)';c.beginPath();c.arc(x,y,1.4,0,TAU);c.fill();}
 for(let i=0;i<500;i++){c.fillStyle='rgba(0,0,0,'+rand(.03,.1)+')';c.fillRect(rand(0,w),rand(0,h),rand(1,3),rand(1,2));}
},true));}
function roadTex(){return cached('road',()=>canvasTex(128,128,(c,w,h)=>{
 c.fillStyle='#3a3b3d';c.fillRect(0,0,w,h);
 for(let i=0;i<2600;i++){c.fillStyle='rgba('+(Math.random()<.5?'200,200,200':'10,10,10')+','+rand(.05,.18)+')';c.fillRect(rand(0,w),rand(0,h),rand(.5,1.6),rand(.5,1.6));}
 blotches(c,w,h,6,'15,15,15',.25,8,26);
 c.fillStyle='rgba(235,235,225,.85)';c.fillRect(w/2-1.5,0,3,h*.55);   // ligne médiane pointillée
 c.fillStyle='rgba(235,235,225,.8)';c.fillRect(4,0,2.5,h);c.fillRect(w-6.5,0,2.5,h);
},true));}
let carModel=null;
// blindé de transport (type véhicule d'intervention) : avant = -z, plancher de la cellule à CF
function makeCar(){
 if(carModel)return carModel;
 const g=new THREE.Group(),U=g.userData;
 const pt=carPaintTex();pt.repeat.set(.5,.5);
 const paint=new THREE.MeshStandardMaterial(Object.assign({map:pt,roughness:.55,metalness:.45},reliefOf(pt,3)));
 const dark=stdMat(0x17191b,{roughness:.6,metalness:.4}),rubber=stdMat(0x101010,{roughness:.95}),rim=stdMat(0x3c4044,{roughness:.4,metalness:.8});
 const chrome=stdMat(0xb8bcc0,{roughness:.2,metalness:1});
 const glass=new THREE.MeshStandardMaterial({color:C(0x1a2630),roughness:.05,metalness:.8,transparent:true,opacity:.35,depthWrite:false,side:THREE.DoubleSide});
 const inner=new THREE.MeshStandardMaterial({map:carInTex(),roughness:.85,metalness:.3});
 const seatM=stdMat(0x2b2b2d,{roughness:.9}),floorM=new THREE.MeshStandardMaterial({map:heliFloorTex(),roughness:.95});
 const head=new THREE.MeshStandardMaterial({color:C(0xffffff),emissive:C(0xfff4dd),emissiveIntensity:2.2});
 const tail=new THREE.MeshStandardMaterial({color:C(0x550000),emissive:C(0xff2010),emissiveIntensity:1.4});
 const CF=.62,CR=2.25,W=1.05,Z0=-2.75,Z1=2.75,ZC=-1.15;   // plancher, toit, demi-largeur, avant, arrière, cloison cabine
 U.CF=CF;U.CW=W;U.Z1=Z1;
 // châssis, bas de caisse, pare-chocs
 g.add(rb(W*2+.1,.42,Z1-Z0,dark,0,CF-.2,0,.06));
 g.add(rb(W*2+.3,.3,.3,dark,0,.62,Z0-.1,.05),rb(W*2+.2,.28,.25,dark,0,.6,Z1+.08,.05));
 // capot moteur + calandre + phares
 g.add(rb(W*2,.62,1.25,paint,0,CF+.3,Z0+.62,.12));
 g.add(rb(W*1.6,.4,.06,dark,0,CF+.3,Z0-.02,.02));
 for(let i=-5;i<=5;i++)g.add(rb(.05,.34,.04,chrome,i*.15,CF+.3,Z0-.05,.01));
 for(const s of [-1,1]){g.add(rb(.32,.2,.06,head,s*(W-.25),CF+.48,Z0-.03,.05));const gl=new THREE.Sprite(new THREE.SpriteMaterial({map:GLOW.white,blending:THREE.AdditiveBlending,transparent:true,depthWrite:false,opacity:.8}));gl.scale.set(1.6,1.6,1);gl.position.set(s*(W-.25),CF+.48,Z0-.2);g.add(gl);}
 // cabine (pare-brise incliné) et cellule arrière blindée
 g.add(rb(W*2,.12,Z1-ZC+.05,paint,0,CR+.06,(ZC+Z1)/2,.05));                       // toit cellule
 g.add(rb(W*2,.1,1.0,paint,0,CR-.02,ZC-.45,.04));                                  // toit cabine
 const ws=rb(W*2-.12,1.0,.04,glass,0,CF+1.12,Z0+1.42,.01);ws.rotation.x=-.32;g.add(ws);
 g.add(rb(W*2,.1,.12,paint,0,CF+.66,Z0+1.3,.03));
 for(const s of [-1,1]){
  // flancs : bas plein, vitre de cabine, meurtrières sur la cellule
  g.add(rb(.1,CR-CF,Z1-ZC,paint,s*W,(CR+CF)/2,(ZC+Z1)/2,.04));
  g.add(rb(.03,CR-CF-.1,Z1-ZC-.1,inner,s*(W-.07),(CR+CF)/2,(ZC+Z1)/2,.01));
  g.add(rb(.1,.7,1.05,paint,s*W,CF+.35,ZC-.5,.04),rb(.1,.12,1.05,paint,s*W,CR-.08,ZC-.5,.03));
  g.add(rb(.05,.75,.95,glass,s*W,CF+1.1,ZC-.5,.01));
  g.add(rb(.12,.75,.08,paint,s*W,CF+1.1,ZC-1.0,.02),rb(.12,.75,.08,paint,s*W,CF+1.1,ZC,.02));
  for(const z of [-.2,1.2])g.add(rb(.12,.14,.4,dark,s*(W+.02),CF+1.25,z,.03));
  g.add(rb(.06,.24,.14,dark,s*(W+.22),CF+1.15,ZC-1.05,.03));                        // rétroviseur
  g.add(rb(.12,.06,Z1-ZC-.3,dark,s*(W+.05),CR-.25,(ZC+Z1)/2,.02));                  // poignée de flanc
  g.add(rb(.18,.16,.05,tail,s*(W-.15),CF+.25,Z1+.02,.03));
  // banquettes de la cellule
  g.add(rb(.45,.1,Z1-ZC-.4,seatM,s*(W-.3),CF+.42,(ZC+Z1)/2+.1,.04),rb(.08,.55,Z1-ZC-.4,seatM,s*(W-.12),CF+.75,(ZC+Z1)/2+.1,.03));
  // sièges avant
  g.add(rb(.5,.1,.5,seatM,s*.5,CF+.42,ZC-.55,.04),rb(.5,.7,.1,seatM,s*.5,CF+.8,ZC-.28,.04));
 }
 g.add(rb(W*2-.1,.04,Z1-Z0-1.4,floorM,0,CF+.02,(ZC+Z1)/2-.3,.01));
 g.add(rb(W*2-.1,.03,Z1-ZC,inner,0,CR-.02,(ZC+Z1)/2,.01));
 // cloison cabine/cellule avec large passage
 for(const s of [-1,1])g.add(rb(.45,CR-CF,.06,inner,s*(W-.25),(CR+CF)/2,ZC,.01));
 g.add(rb(W*2,.3,.06,inner,0,CR-.15,ZC,.01));
 // tableau de bord + volant
 g.add(rb(W*2-.2,.25,.4,dark,0,CF+.68,Z0+1.12,.05));
 const sw=new THREE.Mesh(new THREE.TorusGeometry(.17,.025,6,18),dark);sw.position.set(-.5,CF+.92,Z0+1.42);sw.rotation.x=-.5;g.add(sw);
 // portes arrière (deux battants)
 U.doors=[];
 for(const s of [-1,1]){const d=new THREE.Group();d.position.set(s*W,CF,Z1);
  d.add(rb(W,CR-CF,.1,paint,-s*W/2,(CR-CF)/2,0,.03),rb(W-.1,CR-CF-.1,.03,inner,-s*W/2,(CR-CF)/2,-.06,.01),rb(.3,.22,.04,glass,-s*W/2,(CR-CF)*.7,.06,.01));
  g.add(d);U.doors.push(d);}
 // roues
 U.wheels=[];
 const tg=new THREE.CylinderGeometry(.48,.48,.36,22);tg.rotateZ(Math.PI/2);const hg=new THREE.CylinderGeometry(.28,.28,.38,12);hg.rotateZ(Math.PI/2);
 for(const [x,z] of [[-W,-1.85],[W,-1.85],[-W,1.75],[W,1.75]]){const wg=new THREE.Group();wg.position.set(x,.48,z);
  const t=new THREE.Mesh(tg,rubber),h=new THREE.Mesh(hg,rim);t.castShadow=true;wg.add(t,h);
  for(let k=0;k<6;k++){const b=rb(.04,.08,.04,chrome,Math.sign(x)*.19,Math.cos(k/6*TAU)*.17,Math.sin(k/6*TAU)*.17,.01);wg.add(b);}
  g.add(wg);U.wheels.push(wg);g.add(rb(.5,.14,1.2,paint,x*1.02,1.0,z,.05));}           // ailes
 // rampe de gyrophares
 g.add(rb(1.3,.12,.25,dark,0,CR+.18,ZC-.6,.04));
 U.beacons=[];for(const s of [-1,1]){const m=new THREE.MeshStandardMaterial({color:C(s<0?0x001a55:0x550000),emissive:C(s<0?0x2a6bff:0xff2a2a),emissiveIntensity:0});const b=rb(.45,.11,.2,m,s*.36,CR+.27,ZC-.6,.04);g.add(b);U.beacons.push(m);}
 g.traverse(o=>{if(o.isMesh&&o.material!==glass)o.castShadow=true;});
 return carModel=g;
}
// ruban de route (asphalte + accotements) sur lequel roule le véhicule
function carRoad(E,u,len){
 const t=roadTex();t.repeat.set(1,len/7);
 const m=new THREE.Mesh(new THREE.PlaneGeometry(7,len),new THREE.MeshStandardMaterial(Object.assign({map:t,roughness:.92},reliefOf(t,2))));
 m.rotation.x=-Math.PI/2;m.rotation.z=Math.atan2(u.x,u.z);m.position.set(E.x-u.x*(len/2-15),.03,E.z-u.z*(len/2-15));m.receiveShadow=true;
 const g=new THREE.Group();g.add(m);
 const kerb=stdMat(0x9a9890,{roughness:.9});
 for(const s of [-1,1]){const k=new THREE.Mesh(GBOX,kerb);k.scale.set(.3,.18,len);k.rotation.y=Math.atan2(u.x,u.z);k.position.set(m.position.x+u.z*s*3.65,.09,m.position.z-u.x*s*3.65);g.add(k);}
 return g;
}
function startCarCine(){
 CINE.on=true;CINE.t=0;CINE.skipped=false;CINE.team=P.team;CINE.car=true;CINE.covered=true;CINE.dur=9.2;
 const H=makeCar();scene.add(H);CINE.heli=H;
 for(const d of H.userData.doors)d.rotation.y=0;
 // arrêt : juste à l'extérieur du bord de carte le plus proche du camp de l'équipe ; la route longe ce bord
 const roster=ents.filter(e=>e.team===P.team);
 let hx=0,hz=0;for(const e of roster){hx+=e.x;hz+=e.z;}hx/=roster.length||1;hz/=roster.length||1;
 const M=N*S,cx=M/2,cz=M/2,dx=hx-cx,dz=hz-cz;
 let E,u,n;
 if(Math.abs(dx)>Math.abs(dz)){const s=dx>0?1:-1;n=V3(s,0,0);E=V3(s>0?M+5:-5,0,clamp(hz,12,M-12));u=V3(0,0,hz<cz?1:-1);}
 else{const s=dz>0?1:-1;n=V3(0,0,s);E=V3(clamp(hx,12,M-12),0,s>0?M+5:-5);u=V3(hx<cx?1:-1,0,0);}
 CINE.E=E;CINE.u=u;CINE.n=n;CINE.yaw=Math.atan2(-u.x,-u.z);CINE.dist=70;
 CINE.road=carRoad(E,u,140);scene.add(CINE.road);
 // chauffeur
 for(const R of CINE.pilots)if(R.root.parent)R.root.parent.remove(R.root);CINE.pilots=[];
 {const look={kind:P.team===0?'t':'ct',acc:PALETTE[P.team===0?5:1],tone:SKIN_TONES[1]};const R=makeSoldier(look);setSoldierGun(R,'usp');R.gunObj.visible=false;
  R.root.position.set(-.5,H.userData.CF,-1.62);H.add(R.root);CINE.pilots.push(R);}
 // coéquipiers sur les banquettes (le joueur est assis à gauche, au milieu)
 const mates=roster.filter(e=>!e.isPlayer);
 const SEATS=[{x:-.72,z:-.35,f:-Math.PI/2},{x:.72,z:-.35,f:Math.PI/2},{x:.72,z:.55,f:Math.PI/2},{x:.72,z:1.45,f:Math.PI/2}];
 CINE.seats=[];
 mates.forEach((e,i)=>{
  e.cineSeat=true;e.seated=1;
  const st=SEATS[i];if(!st){e.cineSeat=false;e.seated=0;e.rig.root.visible=false;CINE.seats.push({e,hidden:true});return;}
  H.add(e.rig.root);e.rig.root.position.set(st.x,H.userData.CF,st.z);e.rig.root.rotation.set(0,st.f,0);e.y=H.userData.CF;
  CINE.seats.push({e,x:st.x,z:st.z,f:st.f,drop:6.7+i*.35});
 });
 for(const e of ents){if(!e.cineSeat&&e.rig)e.rig.root.visible=false;const ol=e.rig&&e.rig.root.userData.ol;if(ol)for(const o of ol)o.visible=false;}
 CINE.ropes=[];CINE.hands=null;
 hudEl.style.visibility='hidden';
 const c=$('cine');c.classList.add('on');c.classList.remove('t2');
 setHTML('cineT',MAP.n.toUpperCase());setHTML('cineS',MODES[G.mode].n+' — '+(G.mode==='bomb'?(P.team===0?'ATTAQUANTS':'DÉFENSEURS'):(P.team===0?'ÉQUIPE ORANGE':'ÉQUIPE BLEUE')));
 CINE.snd=typeof startEngine==='function'?startEngine():null;
 G.cinePrev=G.state;G.state='cine';
}
// moteur : grondement grave dont le régime suit la vitesse
function startEngine(){
 if(!AC)return null;
 const o=AC.createOscillator();o.type='sawtooth';o.frequency.value=38;const f=AC.createBiquadFilter();f.type='lowpass';f.frequency.value=260;
 const g=AC.createGain();g.gain.value=.08;o.connect(f);f.connect(g);g.connect(master);
 const src=AC.createBufferSource();src.buffer=noiseBuf;src.loop=true;const nf=AC.createBiquadFilter();nf.type='lowpass';nf.frequency.value=500;const ng=AC.createGain();ng.gain.value=.05;src.connect(nf);nf.connect(ng);ng.connect(master);
 o.start();src.start();
 return {set(v){o.frequency.value=32+40*v;g.gain.value=.05+.08*v;ng.gain.value=.02+.08*v;},stop(){try{o.stop();src.stop();}catch(e){}}};
}
const CAR_STOP=6.0;
function carDist(T){const k=clamp(T/CAR_STOP,0,1);return CINE.dist*(1-(1-(1-k)*(1-k)));}   // distance restant avant l'arrêt
const CLOOKA=[[2.4,.05],[3.3,-.1],[4.3,-1.15],[5.3,-1.25],[6.0,-.2],[6.6,2.6]];
const CLOOKP=[[2.4,-.08],[3.3,-.1],[4.3,-.22],[5.3,-.2],[6.0,-.1],[6.6,-.05]];
function updateCarCine(dt,t){
 CINE.t+=dt;const T=CINE.t,H=CINE.heli,U=H.userData,E=CINE.E,u=CINE.u,n=CINE.n;
 const d=carDist(T),d2=carDist(T+.05),v=(d-d2)/.05;
 H.position.set(E.x-u.x*d,0,E.z-u.z*d);
 // tangage au freinage, petites secousses de la route
 const brake=T>CAR_STOP-1.6&&T<CAR_STOP+.4?Math.sin(clamp((T-(CAR_STOP-1.6))/2,0,1)*Math.PI)*.025:0;
 H.position.y=Math.sin(T*11)*.012*Math.min(1,v/8);
 _he.set(-brake+Math.sin(T*7.3)*.003*Math.min(1,v/8),CINE.yaw,Math.sin(T*5.1)*.004*Math.min(1,v/8),'YXZ');H.quaternion.setFromEuler(_he);
 for(const w of U.wheels)w.rotation.x-=v*dt/.48;
 for(let i=0;i<2;i++)U.beacons[i].emissiveIntensity=((T*3+i*.5)%1)<.5?2.5:0;
 // portes arrière qui s'ouvrent
 const ko=easeIO((T-6.2)/.7);U.doors[0].rotation.y=-ko*1.9;U.doors[1].rotation.y=ko*1.9;
 H.updateMatrixWorld(true);
 if(CINE.snd)CINE.snd.set(clamp(v/22,0,1));
 for(const R of CINE.pilots)animateSoldier(R,{vx:0,vz:0,yaw:0,pitch:-.05,speed:0,onGround:true,crouch:false,alive:true,reload:0,reloadMax:0,fire:0,ready:1,alert:0,y:U.CF,seated:1},dt,T);
 // coéquipiers : assis, puis sortent par l'arrière et s'écartent vers la carte
 CINE.seats.forEach((s,i)=>{
  if(s.hidden)return;const e=s.e,R=e.rig;
  const tGo=s.drop,tOut=tGo+.7,tEnd=tOut+1.2;
  if(T<tOut){
   if(R.root.parent!==H)H.add(R.root);
   const k=easeIO((T-tGo)/.7);e.seated=k>0?0:1;
   R.root.position.set(lerp(s.x,s.x*.3,k),U.CF,lerp(s.z,U.Z1+.3,k));R.root.rotation.set(0,lerp(s.f,Math.PI,k),0);e.y=U.CF;
  }else{
   if(R.root.parent!==scene)scene.add(R.root);
   _hp.set(s.x*.3,0,U.Z1+.8);H.localToWorld(_hp);
   const k=easeIO((T-tOut)/1.2),gx=_hp.x-n.x*(2+i*1.2)+u.x*(i-1.5),gz=_hp.z-n.z*(2+i*1.2)+u.z*(i-1.5);
   R.root.position.set(lerp(_hp.x,gx,k),Math.max(0,U.CF*(1-k*3)),lerp(_hp.z,gz,k));
   R.root.rotation.set(0,Math.atan2(n.x,n.z),0);e.y=R.root.position.y;e.seated=0;
   animateSoldier(R,{vx:0,vz:0,yaw:Math.atan2(n.x,n.z),pitch:0,speed:T<tEnd?4:0,onGround:true,crouch:false,alive:true,reload:0,reloadMax:0,fire:0,ready:1,alert:0,y:e.y},dt,T);
  }
 });
 // titres
 const c=$('cine');
 if(T>3.2&&!c.classList.contains('t2')){c.classList.add('t2');setHTML('cineT',G.mode==='bomb'?(P.team===0?'POSEZ LA BOMBE':'PROTÉGEZ LES SITES'):'ÉLIMINEZ L\'ÉQUIPE ADVERSE');setHTML('cineS',G.mode==='bomb'?'Site A ou B':'Premier à '+G.limit);}
 if(T>=CINE.dur){endCine();return;}
 // ---------------- caméra ----------------
 if(T<2.4){ // plan 1 : au bord de la route, le blindé arrive gyrophares allumés
  const cp=V3(E.x-u.x*18+n.x*6.5,1.1+T*.1,E.z-u.z*18+n.z*6.5);
  camera.position.copy(cp);camera.lookAt(H.position.x,1.3,H.position.z);camera.fov=lerp(38,46,T/2.4);
 }else if(T<6.6){ // plan 2 : assis dans la cellule, on regarde la route puis les coéquipiers
  const a=keyAt(CLOOKA,T),p=keyAt(CLOOKP,T),vib=Math.min(1,v/8);
  _hp.set(-.68+Math.sin(T*13.1)*.004*vib,U.CF+1.12+Math.sin(T*17.3)*.006*vib,.55);H.localToWorld(_hp);camera.position.copy(_hp);
  _he.set(p+Math.sin(T*9.7)*.004*vib,a,Math.sin(T*1.9)*.006,'YXZ');_hq.setFromEuler(_he);
  camera.quaternion.copy(H.quaternion).multiply(_hq);camera.fov=70;
 }else{ // plan 3 : on se lève, on sort par l'arrière et on se tourne vers l'objectif
  const k=easeIO((T-6.6)/1.6);
  _hp.set(lerp(-.68,0,k),lerp(U.CF+1.12,1.6,k),lerp(.55,U.Z1+2.2,k));H.localToWorld(_hp);
  camera.position.copy(_hp);
  _he.set(-.08,CINE.yaw+Math.PI,0,'YXZ');_hq.setFromEuler(_he);
  _he.set(-.03,Math.atan2(n.x,n.z),0,'YXZ');_hq2.setFromEuler(_he);
  camera.quaternion.copy(_hq).slerp(_hq2,easeIO((T-7.6)/1.0));camera.fov=72;
 }
 camera.updateProjectionMatrix();
 lis.x=camera.position.x;lis.z=camera.position.z;lis.yaw=0;
 if(T>CINE.dur-.5)$('flashfx').style.opacity=Math.min(1,(T-(CINE.dur-.5))/.5);
}
{
 const s0=startCine,u0=updateCine,e0=endCine;
 startCine=function(){if(cfg.carIntro!==0&&carWanted())return startCarCine();CINE.car=false;return s0();};
 updateCine=function(dt,t){return CINE.car?updateCarCine(dt,t):u0(dt,t);};
 endCine=function(){
  const car=CINE.car;
  if(car)for(const R of CINE.pilots)if(R.root.parent)R.root.parent.remove(R.root);
  e0();
  if(car){if(CINE.road){scene.remove(CINE.road);CINE.road=null;}CINE.pilots=[];CINE.car=false;}
 };
}
