/* =====================================================================
   CINÉMATIQUE D'ARRIVÉE EN HÉLICOPTÈRE (style Call of Duty) pour les
   modes en équipe : plan d'ensemble au-dessus des toits, puis vue à la
   première personne depuis la cabine (pilotes, coéquipiers, porte
   ouverte), descente en rappel et arrivée au sol.
   Les plans sont vérifiés par lancer de rayons : la caméra et la
   trajectoire passent au-dessus de tout le décor, rien ne les masque.
   ===================================================================== */
const CINE={on:false,t:0,dur:11.6,heli:null,team:0,seats:[],ropes:[],snd:null,from:null,to:null,yaw:0,skipped:false,title:false,pilots:[]};
let heliModel=null;
function heliTex(){return cached('heli',()=>canvasTex(256,256,(c,w,h)=>{
 c.fillStyle='#4d5a3c';c.fillRect(0,0,w,h);
 blotches(c,w,h,40,'30,36,24',.35,10,40);blotches(c,w,h,25,'110,120,90',.18,8,30);
 c.strokeStyle='rgba(15,18,12,.55)';c.lineWidth=2;
 for(let x=0;x<=w;x+=64){c.beginPath();c.moveTo(x,0);c.lineTo(x,h);c.stroke();}
 for(let y=0;y<=h;y+=85){c.beginPath();c.moveTo(0,y);c.lineTo(w,y);c.stroke();}
 c.fillStyle='rgba(20,22,16,.6)';for(let x=6;x<w;x+=64)for(let y=5;y<h;y+=10){c.fillRect(x,y,2,2);c.fillRect(x+52,y,2,2);}
 streaks(c,w,h,18,'25,25,20',.25);speck(c,w,h,500,.03,.1,3);
},true));}
function heliInTex(){return cached('heliIn',()=>canvasTex(128,128,(c,w,h)=>{
 c.fillStyle='#3a3f38';c.fillRect(0,0,w,h);
 c.strokeStyle='rgba(0,0,0,.4)';c.lineWidth=3;for(let x=0;x<=w;x+=32){c.beginPath();c.moveTo(x,0);c.lineTo(x,h);c.stroke();}
 c.fillStyle='rgba(255,255,255,.06)';for(let x=0;x<w;x+=8)for(let y=0;y<h;y+=8)c.fillRect(x+3,y+3,2,2);
 speck(c,w,h,300,.03,.1,3);
},true));}
function heliFloorTex(){return cached('heliFloor',()=>canvasTex(128,128,(c,w,h)=>{
 c.fillStyle='#2a2c2b';c.fillRect(0,0,w,h);
 c.fillStyle='rgba(255,255,255,.07)';for(let y=0;y<h;y+=8)for(let x=(y/8%2)*4;x<w;x+=8)c.fillRect(x,y,4,2);
 c.strokeStyle='rgba(200,170,40,.5)';c.lineWidth=2;c.strokeRect(4,4,w-8,h-8);
 speck(c,w,h,300,.03,.12,3);
},true));}
function makeHeli(){
 if(heliModel)return heliModel;
 const g=new THREE.Group();
 const tx=heliTex();tx.repeat.set(.45,.45);
 const body=new THREE.MeshStandardMaterial({map:tx,roughness:.62,metalness:.35});
 const dark=stdMat(0x22262a,{roughness:.55,metalness:.5}),black=stdMat(0x111214,{roughness:.7,metalness:.2});
 const inner=new THREE.MeshStandardMaterial({map:heliInTex(),roughness:.9,metalness:.1,emissive:C(0x2a0805),emissiveIntensity:.35});
 const fl=heliFloorTex();fl.repeat.set(2,2);const floorM=new THREE.MeshStandardMaterial({map:fl,roughness:.95,emissive:C(0x200605),emissiveIntensity:.3});
 const seatM=stdMat(0x5a5040,{roughness:.95});
 const glass=new THREE.MeshStandardMaterial({color:C(0x8fb8d8),roughness:.04,metalness:.6,transparent:true,opacity:.28,depthWrite:false,side:THREE.DoubleSide});
 const panel=new THREE.MeshStandardMaterial({color:C(0x0d1210),roughness:.4,emissive:C(0x3cff8a),emissiveIntensity:.0});
 // --- cabine : panneaux séparés pour que l'intérieur soit visible ---
 const CF=-.9,CR=1.15,CZ0=-1.7,CZ1=1.9,CW=1.25;           // plancher, toit, avant, arrière, demi-largeur
 g.add(rb(CW*2+.1,.12,CZ1-CZ0,dark,0,CF-.06,(CZ0+CZ1)/2,.03));               // dessous
 g.add(rb(CW*2-.1,.04,CZ1-CZ0-.1,floorM,0,CF+.02,(CZ0+CZ1)/2,.01));          // plancher antidérapant
 g.add(rb(CW*2+.1,.14,CZ1-CZ0+.1,body,0,CR+.07,(CZ0+CZ1)/2,.06));            // toit
 g.add(rb(CW*2-.1,.03,CZ1-CZ0-.2,inner,0,CR-.02,(CZ0+CZ1)/2,.01));           // plafond intérieur
 g.add(rb(CW*2+.1,CR-CF+.1,.12,body,0,(CR+CF)/2,CZ1,.04));                   // cloison arrière
 g.add(rb(CW*2-.1,CR-CF-.1,.03,inner,0,(CR+CF)/2,CZ1-.08,.01));
 // flancs : montants avant/arrière des portes + bandeau au-dessus
 for(const s of [-1,1]){
  g.add(rb(.1,CR-CF,.5,body,s*CW,(CR+CF)/2,CZ0+.25,.03),rb(.1,CR-CF,.32,body,s*CW,(CR+CF)/2,CZ1-.16,.03));
  g.add(rb(.1,.32,CZ1-CZ0,body,s*CW,CR-.16,(CZ0+CZ1)/2,.03));
  g.add(rb(.03,CR-CF-.1,.26,inner,s*(CW-.07),(CR+CF)/2,CZ1-.2,.01));
  // porte coulissante repoussée vers l'arrière, à l'extérieur, avec hublot
  const door=new THREE.Group();door.position.set(s*(CW+.1),(CR+CF)/2-.08,CZ1+.55);
  door.add(rb(.06,CR-CF-.3,1.7,body,0,0,0,.03),rb(.065,.42,.5,glass,0,.32,-.2,.02));g.add(door);
  g.add(rb(.05,.05,CZ1-CZ0+1.4,dark,s*(CW+.04),CR-.34,CZ1-.3,.01));      // rail de porte
  // poignées de maintien au plafond
  for(let z=-1.2;z<1.4;z+=.6)g.add(rb(.03,.12,.03,black,s*(CW-.3),CR-.1,z,.008));
 }
 // bancs (dossiers sangles rouges) : arrière face à l'avant, avant face à l'arrière
 const strap=stdMat(0x7a2a22,{roughness:.9});
 g.add(rb(2.2,.08,.5,seatM,0,CF+.48,1.45,.02),rb(2.2,.6,.06,strap,0,CF+.85,1.73,.02));
 g.add(rb(1.5,.08,.45,seatM,0,CF+.48,-1.42,.02),rb(1.5,.6,.06,strap,0,CF+.85,-1.66,.02));
 for(const x of [-1,-.35,.35,1])g.add(rb(.04,.46,.04,black,x,CF+.23,1.45,.01));
 for(const x of [-.6,.6])g.add(rb(.04,.46,.04,black,x,CF+.23,-1.42,.01));
 // filet de chargement et extincteur sur la cloison arrière
 const net=canvasTex(64,64,(c,w,h)=>{c.strokeStyle='rgba(30,30,25,.95)';c.lineWidth=3;for(let i=-64;i<128;i+=12){c.beginPath();c.moveTo(i,0);c.lineTo(i+64,64);c.stroke();c.beginPath();c.moveTo(i+64,0);c.lineTo(i,64);c.stroke();}},true);
 net.repeat.set(3,1);
 const nm=new THREE.Mesh(new THREE.PlaneGeometry(1.6,.5),new THREE.MeshStandardMaterial({map:net,transparent:true,alphaTest:.3,side:THREE.DoubleSide,roughness:1}));nm.position.set(0,CR-.45,CZ1-.12);nm.rotation.y=Math.PI;g.add(nm);
 g.add(cz(.07,.07,.4,stdMat(0xb01e1e,{roughness:.5}),1.0,CF+.6,CZ1-.18));
 // lumière de cabine rouge (sprites, aucune lumière dynamique ajoutée)
 for(const z of [-.8,.9]){const l=new THREE.Sprite(new THREE.SpriteMaterial({map:GLOW.orange,color:0xff3020,blending:THREE.AdditiveBlending,transparent:true,depthWrite:false,opacity:.75,toneMapped:false}));l.scale.set(.9,.9,1);l.position.set(0,CR-.08,z);g.add(l);
  g.add(rb(.25,.04,.12,stdMat(0x401010,{emissive:C(0xff2a1a),emissiveIntensity:1.2}),0,CR-.03,z,.01));}
 // --- cockpit : nez bas plein + verrière vitrée, pilotes visibles depuis la cabine ---
 g.add(polyZY([[CZ0,CF-.12],[-3.4,CF-.05],[-4.15,-.45],[-4.3,.05],[CZ0,.05]],CW*2-.05,body,0,.06));
 g.add(polyZY([[CZ0,.05],[-4.3,.05],[-3.75,.75],[-2.9,1.12],[CZ0,CR+.12]],CW*2-.14,glass,0,.02));
 // montants de verrière
 for(const s of [-1,1]){
  g.add(rb(.08,.08,1.4,dark,s*(CW-.08),.92,-3.25,.02,-.5),rb(.08,.9,.08,dark,s*(CW-.08),.55,-2.15,.02));
  g.add(rb(.08,.08,1.15,dark,s*(CW-.08),.1,-3.6,.02,.0));
 }
 g.add(rb(.07,.07,1.6,dark,0,.95,-3.2,.02,-.45),rb(CW*2-.1,.1,.1,dark,0,CR+.06,CZ0-.02,.02));
 // tableau de bord + écrans
 g.add(rb(2.0,.36,.35,black,0,.1,-3.45,.04,-.3));
 const scr=[];for(const x of [-.7,-.25,.25,.7]){const m=new THREE.Mesh(new THREE.PlaneGeometry(.28,.2),panel.clone());m.material.emissiveIntensity=.9;m.material.emissive=C(x<0?0x3cff8a:0xffb040);m.position.set(x,.2,-3.27);m.rotation.x=-.3;m.rotation.y=Math.PI;m.rotation.y=0;g.add(m);scr.push(m);}
 g.userData.screens=scr;
 // sièges pilotes
 for(const x of [-.55,.55]){g.add(rb(.5,.1,.5,seatM,x,CF+.5,-2.45,.03),rb(.5,.75,.1,seatM,x,CF+.9,-2.2,.03),rb(.08,.5,.08,black,x,CF+.25,-2.45,.02));}
 // --- moteurs, mât, rotor ---
 g.add(rb(1.5,.55,3.0,body,0,CR+.42,.4,.22));
 for(const s of [-1,1]){g.add(cz(.28,.32,2.2,body,s*.55,CR+.55,.6,14),cz(.22,.18,.5,black,s*.62,CR+.6,1.85,12));}
 g.add(cz(.12,.12,.25,black,0,CR+.45,-1.1,10));
 const mast=new THREE.Mesh(new THREE.CylinderGeometry(.13,.18,.6,12),dark);mast.position.set(0,CR+.95,.1);g.add(mast);
 const rotor=new THREE.Group();rotor.position.set(0,CR+1.28,.1);
 rotor.add(new THREE.Mesh(new THREE.CylinderGeometry(.32,.28,.18,12),dark));
 for(let i=0;i<4;i++){const arm=new THREE.Group();arm.rotation.y=i*Math.PI/2;const bl=rb(.42,.05,7.6,black,0,-.03,3.9,.02);bl.rotation.x=-.012;arm.add(bl,rb(.2,.04,.14,stdMat(0xd8c020),0,-.03,7.6,.01));rotor.add(arm);}
 const blur=new THREE.Mesh(new THREE.CircleGeometry(7.8,48),new THREE.MeshBasicMaterial({color:0x111111,transparent:true,opacity:.1,side:THREE.DoubleSide,depthWrite:false}));blur.rotation.x=-Math.PI/2;blur.position.y=-.03;rotor.add(blur);
 g.add(rotor);g.userData.rotor=rotor;
 // --- poutre de queue, dérive, stabilisateur, rotor de queue ---
 g.add(polyZY([[CZ1,CF+.02],[CZ1,CR+.2],[3.4,CR+.05],[4.2,.75],[3.6,.15]],1.5,body,0,.08));
 const boom=cz(.62,.26,5.4,body,0,.55,6.4,16);g.add(boom);
 g.add(polyZY([[8.6,.5],[9.6,2.1],[10.1,2.25],[9.7,.55],[9.1,.25]],.14,body,0,.03));
 g.add(rb(3.0,.08,.75,body,0,.55,9.0,.03));
 const tr=new THREE.Group();tr.position.set(-.22,1.9,9.75);
 for(let i=0;i<4;i++){const b=rb(.04,1.5,.13,black,0,0,0,.01);b.rotation.x=i*Math.PI/4;tr.add(b);}
 tr.add(new THREE.Mesh(new THREE.CylinderGeometry(.08,.08,.12,8).rotateZ(Math.PI/2),dark));
 g.add(tr);g.userData.tail=tr;
 // antennes, marchepieds, train d'atterrissage
 g.add(rb(.03,.5,.03,black,.4,CR+.35,-1.0,.008),rb(.6,.03,.03,black,0,CF-.3,-3.2,.008));
 for(const s of [-1,1]){
  g.add(rb(.1,.05,1.5,dark,s*(CW+.12),CF-.18,-.1,.01));
  g.add(rb(.08,.8,.08,dark,s*1.05,CF-.4,-2.6,.02,.0,0,s*.3));
  const wh=new THREE.Mesh(new THREE.CylinderGeometry(.27,.27,.18,16).rotateZ(Math.PI/2),black);wh.position.set(s*1.25,CF-.78,-2.6);g.add(wh);
 }
 {const wh=new THREE.Mesh(new THREE.CylinderGeometry(.16,.16,.12,12).rotateZ(Math.PI/2),black);wh.position.set(0,.05,8.6);g.add(wh);g.add(rb(.06,.4,.06,dark,0,.25,8.55,.01));}
 // feux et phare
 const spot=new THREE.Sprite(new THREE.SpriteMaterial({map:GLOW.white,blending:THREE.AdditiveBlending,transparent:true,depthWrite:false,opacity:.8,toneMapped:false}));spot.scale.set(2.6,2.6,1);spot.position.set(0,CF-.2,-3.9);g.add(spot);
 const nav=(col,x,y,z)=>{const s=new THREE.Sprite(new THREE.SpriteMaterial({map:GLOW.cool,blending:THREE.AdditiveBlending,transparent:true,depthWrite:false,color:col,toneMapped:false}));s.scale.set(.7,.7,1);s.position.set(x,y,z);g.add(s);return s;};
 nav(0xff3030,-CW-.05,.1,-1.8);nav(0x30ff70,CW+.05,.1,-1.8);g.userData.beacon=nav(0xff2020,0,CR+.3,2.6);
 g.traverse(o=>{if(o.isMesh&&o.material!==glass)o.castShadow=true;});
 g.userData.CF=CF;g.userData.CW=CW;
 heliModel=g;return g;
}
function easeOut(t){t=clamp(t,0,1);return 1-Math.pow(1-t,3);}
function easeIO(t){t=clamp(t,0,1);return t*t*(3-2*t);}
// hauteur du décor (grille + objets décoratifs comme les minarets) autour d'un point
const _ray=new THREE.Raycaster();_ray.camera=camera;
function cineTopAt(x,z,r){
 let top=-1e9;const objs=worldG?[worldG]:[];
 for(const [dx,dz] of [[0,0],[r,0],[-r,0],[0,r],[0,-r]]){
  const gx=x+dx,gz=z+dz;if(gx>0&&gz>0&&gx<N*S&&gz<N*S)top=Math.max(top,groundH(gx,gz));
  _ray.set(V3(x+dx,120,z+dz),V3(0,-1,0));_ray.far=140;
  const h=_ray.intersectObjects(objs,true);for(const it of h){if(it.object.isSprite||it.object.isPoints||it.object.isLine)continue;top=Math.max(top,it.point.y);break;}
 }
 return top;
}
// segment dégagé de tout décor ?
function cineClear(a,b){
 const d=V3().subVectors(b,a),L=d.length();if(L<1e-3)return true;d.divideScalar(L);
 _ray.set(a,d);_ray.far=L;
 for(const it of _ray.intersectObjects(worldG?[worldG]:[],true)){if(it.object.isSprite||it.object.isPoints||it.object.isLine)continue;return false;}
 return true;
}
function cinePilots(H){
 for(const R of CINE.pilots)H.remove(R.root);CINE.pilots=[];
 const look={kind:P.team===0?'t':'ct',acc:PALETTE[P.team===0?5:1],tone:SKIN_TONES[1]};
 for(const x of [-.55,.55]){
  const R=makeSoldier(look);setSoldierGun(R,'usp');R.gunObj.visible=false;
  R.root.position.set(x,H.userData.CF,-2.5);H.add(R.root);CINE.pilots.push(R);
 }
}
function startCine(){
 CINE.on=true;CINE.t=0;CINE.skipped=false;CINE.team=P.team;
 const H=makeHeli();scene.add(H);CINE.heli=H;
 // point de stationnaire : au-dessus du centre des points de départ de l'équipe
 const roster=ents.filter(e=>e.team===P.team);
 let hx=0,hz=0;for(const e of roster){hx+=e.x;hz+=e.z;}hx/=roster.length||1;hz/=roster.length||1;
 const cx=N*S/2,cz=N*S/2;let dx=hx-cx,dz=hz-cz,dl=Math.hypot(dx,dz);if(dl<1){dx=0;dz=1;dl=1;}dx/=dl;dz/=dl;
 // la porte gauche se place juste au-dessus du point de départ du joueur : descente verticale, sans traverser de toit
 {const yw=Math.atan2(dx,dz),ox=-(H.userData.CW+.35),oz=.2;hx=P.x-(ox*Math.cos(yw)+oz*Math.sin(yw));hz=P.z-(-ox*Math.sin(yw)+oz*Math.cos(yw));}
 const hoverY=Math.max(cineTopAt(hx,hz,6)+6.5,cineTopAt(P.x,P.z,1.5)+8,groundH(P.x,P.z)+9);
 // trajectoire : arrive de l'extérieur de la carte, côté de l'équipe, au-dessus de tout le décor
 const from=V3(hx+dx*120,0,hz+dz*120);
 let cruise=hoverY;for(let i=0;i<=16;i++){const k=i/16;cruise=Math.max(cruise,cineTopAt(lerp(from.x,hx,k),lerp(from.z,hz,k),5)+7);}
 from.y=cruise+6;
 CINE.from=from;CINE.to=V3(hx,hoverY,hz);CINE.cruise=cruise;
 // départ sous un toit (cartes intérieures) : pas de rappel à travers le plafond, on saute de la porte
 CINE.covered=ceilAt(P.x,P.z)<90||cineTopAt(P.x,P.z,.4)>groundH(P.x,P.z)+2.6;CINE.dur=CINE.covered?9.8:11.6;
 CINE.yaw=Math.atan2(dx,dz);   // nez vers le centre de la carte (avant = -z local)
 CINE.side=V3(Math.cos(CINE.yaw),0,-Math.sin(CINE.yaw));
 cinePilots(H);
 // plan d'ensemble : caméra au-dessus des toits, choisie pour voir l'hélico sans obstacle
 CINE.ext=null;
 {const mid=cinePath(2.2),cands=[];for(const sd of [1,-1])for(const fw of [-14,-24,-6])for(const up of [2,5,9])cands.push([sd,fw,up]);
  for(const [sd,fw,up] of cands){
   const cp=V3(mid.x+CINE.side.x*sd*15-dx*fw,Math.max(mid.y,cruise)+up,mid.z+CINE.side.z*sd*15-dz*fw);
   let ok=true;for(let i=0;i<=8&&ok;i++)ok=cineClear(cp,cinePath(i/8*2.8));
   if(ok){CINE.ext=cp;break;}
  }}
 // passagers : bancs de la cabine (le joueur est assis à l'arrière gauche)
 const mates=roster.filter(e=>!e.isPlayer);
 const SEATS=[{x:.05,z:1.4,f:0},{x:.75,z:1.4,f:0},{x:-.42,z:-1.38,f:Math.PI},{x:.42,z:-1.38,f:Math.PI}];
 CINE.seats=[];
 mates.forEach((e,i)=>{
  e.cineSeat=true;e.seated=1;
  const st=SEATS[i];if(!st){e.cineSeat=false;e.seated=0;e.rig.root.visible=false;CINE.seats.push({e,hidden:true});return;}
  H.add(e.rig.root);e.rig.root.position.set(st.x,H.userData.CF,st.z);e.y=H.userData.CF;
  CINE.seats.push({e,x:st.x,z:st.z,f:st.f,door:st.x>0||(st.x>=0&&st.f)?1:-1,drop:7.9+i*.35});
 });
 for(const e of ents){if(!e.cineSeat&&e.rig)e.rig.root.visible=false;const ol=e.rig&&e.rig.root.userData.ol;if(ol)for(const o of ol)o.visible=false;}
 // cordes : cylindres (bien visibles de près)
 const ropeM=stdMat(0x2b2620,{roughness:1});
 CINE.ropes=CINE.seats.concat([{player:true}]).map(()=>{const m=new THREE.Mesh(new THREE.CylinderGeometry(.022,.022,1,6).translate(0,-.5,0),ropeM);m.visible=false;m.frustumCulled=false;scene.add(m);return m;});
 // mains du joueur pour le rappel
 const M=lookMats(entLook(P));CINE.hands=[makeHandMesh(M.glove,true),makeHandMesh(M.glove,true)];CINE.hands[1].scale.x=-1;
 for(const h of CINE.hands){h.visible=false;scene.add(h);}
 hudEl.style.visibility='hidden';
 const c=$('cine');c.classList.add('on');
 $('cineT').textContent='';$('cineS').textContent='';
 setHTML('cineT',MAP.n.toUpperCase());setHTML('cineS',MODES[G.mode].n+' — '+(G.mode==='bomb'?(P.team===0?'ATTAQUANTS':'DÉFENSEURS'):(P.team===0?'ÉQUIPE ORANGE':'ÉQUIPE BLEUE')));
 c.classList.remove('t2');
 CINE.snd=typeof startHeli==='function'?startHeli():null;
 G.cinePrev=G.state;G.state='cine';
}
// position de l'hélicoptère à l'instant T (approche, arrondi, stationnaire, départ)
const ARR=7.6;
function cinePath(T,out){
 out=out||V3();const F=CINE.from,H=CINE.to;
 const k=easeOut(T/ARR),kd=easeIO(T/ARR);
 out.set(lerp(F.x,H.x,k),0,lerp(F.z,H.z,k));
 // léger virage en S pendant l'approche
 const sw=Math.sin(clamp(T/ARR,0,1)*Math.PI)*7;out.x+=CINE.side.x*sw;out.z+=CINE.side.z*sw;
 out.y=T<ARR*.7?lerp(F.y,CINE.cruise+1,easeIO(T/(ARR*.7))):lerp(CINE.cruise+1,H.y,easeIO((T-ARR*.7)/(ARR*.3)));
 if(T>ARR){out.y+=Math.sin(T*1.6)*.1;out.x+=Math.sin(T*1.1)*.12;}
 if(T>10.4)out.y+=easeOut((T-10.4)/1.6)*9;
 return out;
}
function skipCine(){if(!CINE.on||CINE.skipped)return;CINE.skipped=true;CINE.t=Math.max(CINE.t,CINE.dur-.5);}
function endCine(){
 CINE.on=false;
 for(const s of CINE.seats){const e=s.e,R=e.rig;if(R.root.parent!==scene)scene.add(R.root);e.cineSeat=false;e.seated=0;R.root.rotation.set(0,e.yaw,0);R.root.position.set(e.x,groundH(e.x,e.z),e.z);e.y=groundH(e.x,e.z);R.vy=e.y;R.vyaw=e.yaw;R.root.visible=true;}
 for(const e of ents){const ol=e.rig&&e.rig.root.userData.ol;if(ol)for(const o of ol)o.visible=true;}
 if(CINE.heli){scene.remove(CINE.heli);}
 for(const r of CINE.ropes)scene.remove(r);CINE.ropes=[];
 if(CINE.hands)for(const h of CINE.hands)scene.remove(h);CINE.hands=null;
 CINE.seats=[];if(CINE.snd){CINE.snd.stop();CINE.snd=null;}
 hudEl.style.visibility='';$('cine').classList.remove('on');
 const fl=$('flashfx');fl.style.opacity=.9;
 G.state=G.cinePrev||'freeze';
 if(G.mode==='bomb'){G.state='freeze';G.timer=G.freezeT;}
 else{G.state='freeze';G.timer=3;}
 sfx('round');
 uiBanner(G.mode==='bomb'?'MANCHE AU PISTOLET':MODES[G.mode].n.toUpperCase(),G.mode==='bomb'?'Phase d\'achat — touche B':'Premier à '+G.limit,2400);
}
function ropeSet(m,a,b){const d=V3().subVectors(b,a),L=d.length();m.position.copy(a);m.scale.set(1,Math.max(L,.01),1);m.quaternion.setFromUnitVectors(V3(0,-1,0),d.divideScalar(L||1));}
const _hp=V3(),_hp2=V3(),_hq=new THREE.Quaternion(),_hq2=new THREE.Quaternion(),_he=new THREE.Euler(),_pv=V3();
// interpolation par images-clés [temps, valeur]
function keyAt(K,T){if(T<=K[0][0])return K[0][1];for(let i=1;i<K.length;i++)if(T<=K[i][0]){const a=K[i-1],b=K[i],k=easeIO((T-a[0])/(b[0]-a[0]));return lerp(a[1],b[1],k);}return K[K.length-1][1];}
const LOOKA=[[2.6,.12],[3.4,.12],[4.6,.85],[6.2,1.0],[7.2,-.35],[7.9,-.7],[8.9,-.8],[9.5,1.5]];
const LOOKP=[[2.6,-.1],[3.4,-.12],[4.6,-.45],[6.2,-.55],[7.2,-.18],[7.9,-.38],[8.9,-.42],[9.5,-1.0]];
function updateCine(dt,t){
 CINE.t+=dt;const T=CINE.t,H=CINE.heli,U=H.userData;
 // trajectoire de l'hélicoptère + orientation (cap suivant la vitesse, piqué en approche, cabré à l'arrondi)
 cinePath(T,H.position);cinePath(T+.05,_pv);
 const vx=_pv.x-H.position.x,vz=_pv.z-H.position.z,sp=Math.hypot(vx,vz)/.05;
 const head=sp>2?Math.atan2(-vx,-vz):CINE.yaw;CINE.head=CINE.head===undefined?head:CINE.head+angDiff(CINE.head,head)*Math.min(1,dt*3);
 const pitch=T<ARR-1.2?-clamp(sp/40,0,.16):T<ARR+.6?Math.sin(clamp((T-(ARR-1.2))/1.8,0,1)*Math.PI)*.14:0;
 const roll=Math.cos(clamp(T/ARR,0,1)*Math.PI)*.08*(T<ARR?1:0)+Math.sin(T*1.3)*.02;
 _he.set(pitch,CINE.head,roll,'YXZ');H.quaternion.setFromEuler(_he);
 U.rotor.rotation.y+=dt*34;U.tail.rotation.x+=dt*44;U.beacon.visible=(T%1)<.12;
 for(const s of U.screens)s.material.emissiveIntensity=.7+Math.sin(T*3+s.position.x*9)*.15;
 H.updateMatrixWorld(true);
 if(CINE.snd)CINE.snd.set(clamp(T<2.6?.45:.95,0,1));
 // pilotes : assis, mains sur les commandes
 for(const R of CINE.pilots)animateSoldier(R,{vx:0,vz:0,yaw:0,pitch:-.1,speed:0,onGround:true,crouch:false,alive:true,reload:0,reloadMax:0,fire:0,ready:1,alert:0,y:U.CF,seated:1},dt,T);
 // coéquipiers : assis, puis rejoignent la porte et descendent en rappel
 CINE.seats.forEach((s,i)=>{
  if(s.hidden)return;const e=s.e,R=e.rig,rope=CINE.ropes[i];
  const tGo=s.drop,tDoor=tGo+.4,tLand=tDoor+1.3;
  const dLx=s.door*(U.CW+.15),dLy=U.CF,dLz=s.z>0?.3:-.5;
  if(T<tDoor){
   if(R.root.parent!==H)H.add(R.root);
   const k=easeIO((T-tGo)/.4);e.seated=k>0?0:1;
   R.root.position.set(lerp(s.x,dLx,k),U.CF,lerp(s.z,dLz,k));R.root.rotation.set(0,lerp(s.f,s.door>0?-Math.PI/2:Math.PI/2,k),0);e.y=U.CF;
   rope.visible=false;
  }else if(CINE.covered){
   if(R.root.parent!==scene)scene.add(R.root);e.cineSeat=false;rope.visible=false;
  }else if(T<tLand){
   if(R.root.parent!==scene)scene.add(R.root);
   _hp.set(dLx,dLy,dLz);H.localToWorld(_hp);
   const gy=groundH(e.x,e.z),k=easeIO((T-tDoor)/1.3);e.seated=0;
   R.root.position.set(lerp(_hp.x,e.x,k),lerp(_hp.y,gy,k),lerp(_hp.z,e.z,k));R.root.rotation.set(0,CINE.head+(s.door>0?-Math.PI/2:Math.PI/2),0);e.y=R.root.position.y;
   _hp2.copy(_hp);_hp2.y+=.6;rope.visible=true;ropeSet(rope,_hp2,V3(e.x,gy,e.z));
  }else{
   if(R.root.parent!==scene)scene.add(R.root);
   const gy=groundH(e.x,e.z);R.root.position.set(e.x,gy,e.z);R.root.rotation.set(0,e.yaw,0);e.y=gy;e.seated=0;
   _hp.set(dLx,dLy+.6,dLz);H.localToWorld(_hp);rope.visible=T<tLand+2.2;ropeSet(rope,_hp,V3(_hp.x+.1,_hp.y-9,_hp.z));
  }
 });
 // poussière soulevée par le rotor
 if(fxReady&&T>ARR-1.6&&T<11&&Math.random()<.7){const gy=groundH(H.position.x,H.position.z);for(let i=0;i<3;i++){const a=rand(0,TAU),r=rand(2,6);fxN.emit(H.position.x+Math.cos(a)*r,gy+.2,H.position.z+Math.sin(a)*r,Math.cos(a)*rand(3,6),rand(.2,1),Math.sin(a)*rand(3,6),rand(.8,1.6),.5,2.4,.8,.72,.58,.35,0,1.2);}}
 // titres
 const c=$('cine');
 if(T>3.4&&!c.classList.contains('t2')){c.classList.add('t2');setHTML('cineT',G.mode==='bomb'?(P.team===0?'POSEZ LA BOMBE':'PROTÉGEZ LES SITES'):'ÉLIMINEZ L\'ÉQUIPE ADVERSE');setHTML('cineS',G.mode==='bomb'?'Site A ou B':'Premier à '+G.limit);}
 if(T>=CINE.dur){endCine();return;}
 // ---------------- caméra ----------------
 const pRope=CINE.ropes[CINE.ropes.length-1];
 for(const h of CINE.hands)h.visible=false;pRope.visible=false;
 const tMove=8.9,tRope=9.5,tGround=11.0;
 if(T<2.6&&CINE.ext){ // plan 1 : vue d'ensemble, au-dessus des toits
  camera.position.copy(CINE.ext);camera.position.y+=T*.25;camera.lookAt(H.position.x,H.position.y-.5,H.position.z);camera.fov=lerp(40,48,T/2.6);
 }else if(T<tRope){ // plan 2 : à la première personne, assis dans la cabine
  const a=keyAt(LOOKA,T),p=keyAt(LOOKP,T);
  const mk=easeIO((T-tMove)/(tRope-tMove));
  // tête : siège arrière gauche -> bord de la porte gauche
  _hp.set(lerp(-.72,-U.CW+.05,mk),lerp(U.CF+1.22,U.CF+1.0,mk),lerp(1.32,.2,mk));
  // secousses de vol
  const tb=(T<ARR?1:.5);_hp.x+=Math.sin(T*13.1)*.006*tb;_hp.y+=Math.sin(T*17.3)*.008*tb+Math.sin(T*2.1)*.01;
  H.localToWorld(_hp);camera.position.copy(_hp);
  _he.set(p+Math.sin(T*9.7)*.004*tb,a+Math.sin(T*.7)*.03,Math.sin(T*1.9)*.01,'YXZ');_hq.setFromEuler(_he);
  camera.quaternion.copy(H.quaternion).multiply(_hq);camera.fov=lerp(68,74,mk);
 }else{ // plan 3 : descente en rappel, puis arrivée au sol
  const gy=groundH(P.x,P.z),k=easeIO((T-tRope)/(tGround-tRope));
  _hp.set(-U.CW-.35,U.CF+1.0,.2);H.localToWorld(_hp);
  const ex=P.x,ey=gy+(P.eyeH||1.6),ez=P.z;
  camera.position.set(lerp(_hp.x,ex,k),lerp(_hp.y,ey,k),lerp(_hp.z,ez,k));
  const land=T>tGround?Math.exp(-(T-tGround)*7)*Math.sin((T-tGround)*16)*.08:0;camera.position.y-=land;
  _he.set(-1.0,CINE.head+1.5,0,'YXZ');_hq.setFromEuler(_he);
  _he.set(-.05,P.yaw,0,'YXZ');_hq2.setFromEuler(_he);
  camera.quaternion.copy(_hq).slerp(_hq2,easeIO((T-tRope-.5)/1.3));
  camera.fov=74;
  // corde devant soi + mains qui la tiennent
  const top=V3(-U.CW-.35,U.CF+.6,.2);H.localToWorld(top);
  const fwd=V3(0,0,-1).applyQuaternion(camera.quaternion);fwd.y=0;fwd.normalize();
  const bot=V3(ex+fwd.x*.4,gy,ez+fwd.z*.4);
  if(T<tGround+.15){pRope.visible=true;ropeSet(pRope,top,bot);
   const rp=V3().copy(top).lerp(bot,clamp((top.y-camera.position.y+.35)/Math.max(.1,top.y-bot.y),0,1));
   CINE.hands.forEach((h,i)=>{h.visible=true;h.position.copy(rp);h.position.y+=i?.12:-.05;h.quaternion.copy(camera.quaternion);h.rotateX(-1.2);h.rotateZ(i?-.4:.4);h.position.addScaledVector(V3(1,0,0).applyQuaternion(camera.quaternion),i?-.04:.04);});}
 }
 camera.updateProjectionMatrix();
 lis.x=camera.position.x;lis.z=camera.position.z;lis.yaw=0;
 // flash blanc de transition à la fin
 if(T>CINE.dur-.5)$('flashfx').style.opacity=Math.min(1,(T-(CINE.dur-.5))/.5);
}
