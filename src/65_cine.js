/* =====================================================================
   CINÉMATIQUE D'ARRIVÉE EN HÉLICOPTÈRE (style Call of Duty) pour les
   modes en équipe : approche, caméra de poursuite, descente en rappel
   ===================================================================== */
const CINE={on:false,t:0,dur:10.2,heli:null,team:0,seats:[],ropes:[],snd:null,from:null,to:null,yaw:0,skipped:false,title:false};
let heliModel=null;
function makeHeli(){
 if(heliModel)return heliModel;
 const g=new THREE.Group();
 const body=stdMat(0x4c5b3d,{roughness:.55,metalness:.45}),dark=stdMat(0x23282b,{roughness:.6,metalness:.4}),glass=new THREE.MeshStandardMaterial({color:C(0x6aa8d8),roughness:.05,metalness:.3,transparent:true,opacity:.55});
 g.add(rb(2.5,2.3,5.6,body,0,0,0,.5));                       // cabine
 const nose=new THREE.Mesh(new THREE.SphereGeometry(1,20,14),body);nose.scale.set(1.2,1.0,2.1);nose.position.set(0,-.15,-3.3);g.add(nose);
 const dome=new THREE.Mesh(new THREE.SphereGeometry(1,20,12,0,Math.PI*2,0,Math.PI*.58),glass);dome.scale.set(1.05,.85,1.25);dome.position.set(0,.28,-3.7);dome.rotation.x=-.28;g.add(dome);
 g.add(rb(.9,.9,5.4,body,0,.35,5.0,.3),rb(.16,1.9,1.4,body,0,1.3,7.5,.05,-.35)); // queue + dérive
 g.add(rb(2.2,.12,5.2,dark,0,1.2,0,.04));                     // toit
 const mast=new THREE.Mesh(new THREE.CylinderGeometry(.16,.2,.7,10),dark);mast.position.set(0,1.65,0);g.add(mast);
 // sol de la cabine + banquettes
 g.add(rb(2.3,.12,4.6,dark,0,-.9,.2,.03));
 // portes ouvertes (panneaux repoussés)
 for(const s of [-1,1])g.add(rb(.08,1.4,1.7,body,s*1.27,.05,-.7,.03));
 // rotor principal
 const rotor=new THREE.Group();rotor.position.set(0,2.05,0);
 for(let i=0;i<4;i++){const bl=rb(.5,.07,7.2,dark,0,0,0,.02);bl.position.set(Math.cos(i*Math.PI/2)*3.6,0,Math.sin(i*Math.PI/2)*3.6);bl.rotation.y=-i*Math.PI/2+Math.PI/2;rotor.add(bl);}
 const blur=new THREE.Mesh(new THREE.CircleGeometry(7.4,40),new THREE.MeshBasicMaterial({color:0xffffff,transparent:true,opacity:.07,side:THREE.DoubleSide,depthWrite:false}));blur.rotation.x=-Math.PI/2;rotor.add(blur);
 g.add(rotor);g.userData.rotor=rotor;
 // rotor de queue
 const tr=new THREE.Group();tr.position.set(.35,1.3,7.6);for(let i=0;i<2;i++){const b=rb(.06,1.7,.18,dark,0,0,0,.01);b.rotation.x=i*Math.PI/2;tr.add(b);}g.add(tr);g.userData.tail=tr;
 // patins
 for(const s of [-1,1]){g.add(rb(.14,.12,5.2,dark,s*1.15,-1.55,.2,.04));for(const z of [-1.1,1.5])g.add(rb(.1,.7,.1,dark,s*1.15,-1.2,z,.03));}
 // phares
 const spot=new THREE.Sprite(new THREE.SpriteMaterial({map:GLOW.white,blending:THREE.AdditiveBlending,transparent:true,depthWrite:false,opacity:.9,toneMapped:false}));spot.scale.set(3.4,3.4,1);spot.position.set(0,-.9,-4.5);g.add(spot);
 const navR=glowSprite(0,0,0,'orange',.6,1,false);navR.parent.remove(navR);navR.position.set(1.3,.4,-3);g.add(navR);
 const navG=new THREE.Sprite(new THREE.SpriteMaterial({map:GLOW.cool,blending:THREE.AdditiveBlending,transparent:true,depthWrite:false,color:0x66ff88,toneMapped:false}));navG.scale.set(.7,.7,1);navG.position.set(-1.3,.4,-3);g.add(navG);
 g.traverse(o=>{if(o.isMesh)o.castShadow=true;});
 // écusson d'équipe
 heliModel=g;return g;
}
function easeOut(t){t=clamp(t,0,1);return 1-Math.pow(1-t,3);}
function startCine(){
 CINE.on=true;CINE.t=0;CINE.skipped=false;CINE.team=P.team;
 const H=makeHeli();scene.add(H);CINE.heli=H;
 const north=P.team===1&&G.mode==='bomb'||(G.mode==='tdm'&&P.team===1);
 const zHover=north?12:68,zStart=north?-70:150;
 // approche
 CINE.from=V3(40+rand(-4,4),30,zStart);CINE.to=V3(40,11.5,zHover);CINE.yaw=north?Math.PI:0;
 // passagers
 const roster=ents.filter(e=>e.team===P.team);CINE.seats=[];
 roster.forEach((e,i)=>{
  const side=i%2?1:-1,z=-1.2+Math.floor(i/2)*1.05;
  e.cineSeat=true;e.seated=2;
  e.rig.root.visible=true;
  CINE.seats.push({e,side,z,drop:7.4+i*.22});
 });
 for(const e of ents)if(e.team!==P.team||!e.cineSeat)e.rig&&(e.rig.root.visible=e.cineSeat);
 // cordes
 CINE.ropes=roster.map(()=>{const l=new THREE.Line(new THREE.BufferGeometry().setFromPoints([V3(),V3(0,-1,0)]),new THREE.LineBasicMaterial({color:0x222222}));l.frustumCulled=false;l.visible=false;scene.add(l);return l;});
 hudEl.style.visibility='hidden';
 const c=$('cine');c.classList.add('on');
 $('cineT').textContent='';$('cineS').textContent='';
 setHTML('cineT',MAP.n.toUpperCase());setHTML('cineS',MODES[G.mode].n+' — '+(G.mode==='bomb'?(P.team===0?'ATTAQUANTS':'DÉFENSEURS'):(P.team===0?'ÉQUIPE ORANGE':'ÉQUIPE BLEUE')));
 c.classList.remove('t2');
 CINE.snd=typeof startHeli==='function'?startHeli():null;
 G.cinePrev=G.state;G.state='cine';
}
function skipCine(){if(!CINE.on||CINE.skipped)return;CINE.skipped=true;CINE.t=Math.max(CINE.t,CINE.dur-.5);}
function endCine(){
 CINE.on=false;if(CINE.heli){scene.remove(CINE.heli);}
 for(const r of CINE.ropes)scene.remove(r);CINE.ropes=[];
 for(const s of CINE.seats){s.e.cineSeat=false;s.e.seated=0;s.e.rig.root.rotation.x=0;s.e.rig.root.rotation.z=0;}
 CINE.seats=[];if(CINE.snd){CINE.snd.stop();CINE.snd=null;}
 hudEl.style.visibility='';$('cine').classList.remove('on');
 const fl=$('flashfx');fl.style.opacity=.9;
 G.state=G.cinePrev||'freeze';
 if(G.mode==='bomb'){G.state='freeze';G.timer=G.freezeT;}
 else{G.state='freeze';G.timer=3;}
 sfx('round');
 uiBanner(G.mode==='bomb'?'MANCHE AU PISTOLET':MODES[G.mode].n.toUpperCase(),G.mode==='bomb'?'Phase d\'achat — touche B':'Premier à '+G.limit,2400);
}
const _hp=V3(),_hq=new THREE.Quaternion(),_he=new THREE.Euler();
function updateCine(dt,t){
 CINE.t+=dt;const T=CINE.t,H=CINE.heli;
 // trajectoire de l'hélicoptère
 const k=easeOut(T/6.6);
 H.position.lerpVectors(CINE.from,CINE.to,k);
 const hov=T>6.6;H.position.y+=hov?Math.sin(T*1.7)*.12:0;H.position.x+=hov?Math.sin(T*1.1)*.2:0;
 const lift=T>9.0?easeOut((T-9.0)/1.4)*10:0;H.position.y+=lift;
 const pitch=(1-k)*.16;
 _he.set(pitch,CINE.yaw,Math.sin(T*1.3)*.03,'YXZ');H.quaternion.setFromEuler(_he);
 H.userData.rotor.rotation.y+=dt*34;H.userData.tail.rotation.x+=dt*40;
 H.updateMatrixWorld(true);
 if(CINE.snd)CINE.snd.set(clamp(.35+k*.65,0,1));
 // passagers
 CINE.seats.forEach((s,i)=>{
  const e=s.e,R=e.rig;
  const dropK=clamp((T-s.drop)/1.35,0,1),landed=dropK>=1;
  _hp.set(s.side*1.25,-1.4,s.z);H.localToWorld(_hp);
  const doorX=_hp.x,doorY=_hp.y,doorZ=_hp.z;
  if(!landed){
   const gx=e.x,gz=e.z,gy=groundH(e.x,e.z);
   const ease=dropK*dropK*(3-2*dropK);
   R.root.position.set(lerp(doorX,gx,ease),lerp(doorY,gy,ease),lerp(doorZ,gz,ease));
   e.seated=dropK>0?0:2;
   R.root.rotation.y=CINE.yaw+(dropK>0?(e.team===0?0:Math.PI):(s.side>0?-Math.PI/2:Math.PI/2));
   if(dropK>0){R.root.rotation.y=e.yaw;}
  }else{R.root.position.set(e.x,groundH(e.x,e.z),e.z);R.root.rotation.y=e.yaw;e.seated=0;}
  e.y=R.root.position.y;
  // corde
  const rope=CINE.ropes[i];
  if(T>s.drop-.4&&!landed){rope.visible=true;const p=rope.geometry.attributes.position;p.setXYZ(0,doorX,doorY+.3,doorZ);p.setXYZ(1,lerp(doorX,e.x,dropK),lerp(doorY,groundH(e.x,e.z),dropK),lerp(doorZ,e.z,dropK));p.needsUpdate=true;}
  else if(T>s.drop+1.35){const p=rope.geometry.attributes.position;p.setXYZ(0,doorX,doorY+.3,doorZ);p.setXYZ(1,doorX+.1,doorY-8,doorZ);p.needsUpdate=true;rope.visible=T<s.drop+3.4;}
 });
 // poussière du rotor au sol
 if(fxReady&&T>3.5&&T<9.8&&Math.random()<.7){const gy=groundH(H.position.x,H.position.z);for(let i=0;i<3;i++){const a=rand(0,TAU),r=rand(2,6);fxN.emit(H.position.x+Math.cos(a)*r,gy+.2,H.position.z+Math.sin(a)*r,Math.cos(a)*rand(3,6),rand(.2,1),Math.sin(a)*rand(3,6),rand(.8,1.6),.5,2.4,.8,.72,.58,.35,0,1.2);}}
 // titres
 const c=$('cine');
 if(T>3.6&&!c.classList.contains('t2')){c.classList.add('t2');setHTML('cineT',G.mode==='bomb'?(P.team===0?'POSEZ LA BOMBE':'PROTÉGEZ LES SITES'):'ÉLIMINEZ L\'ÉQUIPE ADVERSE');setHTML('cineS',G.mode==='bomb'?'Site A ou B':'Premier à '+G.limit);}
 if(T>=CINE.dur){endCine();return;}
 // caméra
 camera.fov=60;
 const hp=H.position,north=CINE.yaw>1;
 if(T<3.2){ // plan 1 : passage devant la caméra au sol
  const base=V3(CINE.to.x+16,5.5,CINE.to.z+(north?-6:6));
  camera.position.copy(base);camera.lookAt(hp);camera.fov=lerp(46,62,T/3.2);
 }else if(T<6.6){ // plan 2 : poursuite
  const a=T*.12;_hp.set(Math.sin(a)*7+6,3.6,(north?-1:1)*16);_hp.applyAxisAngle(V3(0,1,0),0);camera.position.set(hp.x+_hp.x,hp.y+_hp.y,hp.z+(north?-1:1)*(-16));camera.lookAt(hp.x,hp.y-.5,hp.z);
  camera.position.set(hp.x+Math.sin(a+1)*9,hp.y+3.5,hp.z-(north?-1:1)*15);camera.lookAt(hp.x,hp.y-.3,hp.z);camera.fov=58;
 }else{ // plan 3 : vue d'en bas sur la descente en rappel
  const gy=groundH(CINE.to.x,CINE.to.z);
  camera.position.set(CINE.to.x-8+(T-6.6)*.3,gy+1.4,CINE.to.z+(north?1:-1)*9);camera.lookAt(hp.x,hp.y-4+(T-6.6)*.4,hp.z);camera.fov=lerp(70,58,(T-6.6)/3.6);
 }
 camera.updateProjectionMatrix();
 lis.x=hp.x;lis.z=hp.z;lis.yaw=0;
 camera.rotation.z+=Math.sin(T*2)*.004;
 // flash blanc de transition à la fin
 if(T>CINE.dur-.5)$('flashfx').style.opacity=Math.min(1,(T-(CINE.dur-.5))/.5);
}
