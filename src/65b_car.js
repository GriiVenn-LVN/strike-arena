/* =====================================================================
   ARRIVÉE EN VÉHICULE (cartes intérieures : métro, laboratoire, asile…)
   Au lieu de l'hélicoptère, l'équipe arrive en blindé de transport sur
   une route longeant la carte : plan extérieur, vue assise à l'intérieur
   avec les coéquipiers sur les banquettes, freinage, portes arrière qui
   s'ouvrent, descente, puis fondu vers le point de départ.
   Réutilise CINE (65_cine.js) : CINE.heli porte le véhicule, CINE.seats
   les coéquipiers, endCine() remet tout en place.
   ===================================================================== */
// carte -> véhicule (modèles Blender de tools/blender/vehicles.py) ; les autres cartes gardent l'hélicoptère
const CAR_MAPS={metro:'blinde',labo:'blinde',asile:'blinde',harbor:'blinde',village:'camion_sable',station:'camion_vert'};
function carKind(){return MAP&&CAR_MAPS[MAP.id]||'blinde';}
function carWanted(){return !!(MAP&&(CAR_MAPS[MAP.id]||ceilAt(P.x,P.z)<90));}
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

/* ---------- véhicules modélisés dans Blender (GLB intégré : VEH_DATA / VEH_INFO) ----------
   Les pièces fixes sont fusionnées par matériau (peu d'appels de dessin) ; roues, portes, hayon
   et gyrophares restent des objets séparés pour être animés. Les matériaux sont reconnus par leur
   nom (paint, tarp, inner…) et reçoivent les textures du jeu ; UV en projection cubique. */
function vehPaintTex(base,rivets){return cached('vpaint'+base+rivets,()=>canvasTex(128,128,(c,w,h)=>{
 c.fillStyle=base;c.fillRect(0,0,w,h);
 for(let i=0;i<1600;i++){c.fillStyle='rgba('+(Math.random()<.5?'255,255,255':'0,0,0')+','+rand(.02,.06)+')';c.fillRect(rand(0,w),rand(0,h),rand(.5,1.5),rand(.5,1.5));}
 blotches(c,w,h,10,'90,80,60',.14,6,22);                                            // poussière
 for(let i=0;i<26;i++){c.strokeStyle='rgba(255,255,255,'+rand(.05,.14)+')';c.lineWidth=rand(.4,.9);const x=rand(0,w),y=rand(0,h);c.beginPath();c.moveTo(x,y);c.lineTo(x+rand(-9,9),y+rand(-3,3));c.stroke();}   // rayures
 c.fillStyle='rgba(0,0,0,.35)';c.fillRect(0,63,w,1.2);c.fillRect(63,0,1.2,h);          // joints de tôle
 if(rivets){c.fillStyle='rgba(0,0,0,.45)';for(let y=8;y<h;y+=30)for(let x=6;x<w;x+=30){c.beginPath();c.arc(x,y,1.3,0,TAU);c.fill();}}
 const g=c.createLinearGradient(0,h*.7,0,h);g.addColorStop(0,'rgba(70,55,35,0)');g.addColorStop(1,'rgba(70,55,35,.35)');c.fillStyle=g;c.fillRect(0,0,w,h);   // boue en bas
},true));}
function vehTarpTex(base){return cached('vtarp'+base,()=>canvasTex(128,128,(c,w,h)=>{
 c.fillStyle=base;c.fillRect(0,0,w,h);
 for(let y=0;y<h;y+=2){c.fillStyle='rgba(0,0,0,'+rand(.03,.08)+')';c.fillRect(0,y,w,1);}
 for(let x=0;x<w;x+=2){c.fillStyle='rgba(255,255,255,'+rand(.02,.05)+')';c.fillRect(x,0,1,h);}    // trame de la toile
 blotches(c,w,h,8,'40,32,20',.16,5,20);blotches(c,w,h,5,'255,250,230',.06,8,26);           // taches, usure
 c.strokeStyle='rgba(0,0,0,.3)';c.lineWidth=1;for(let y=20;y<h;y+=42){c.beginPath();c.moveTo(0,y);c.lineTo(w,y+rand(-2,2));c.stroke();}  // coutures
},true));}
const VEH_T={};
function vehMat(name,pb,kind){
 const col=new THREE.Color().fromArray(pb.baseColorFactor||[.5,.5,.5]),mr=pb.metallicFactor!==undefined?pb.metallicFactor:0,ro=pb.roughnessFactor!==undefined?pb.roughnessFactor:.6;
 const E=(c,i)=>new THREE.MeshStandardMaterial({color:col,emissive:C(c),emissiveIntensity:i,roughness:.3});
 const sand=kind==='camion_sable';
 switch(name){
  case 'paint':{const t=kind==='blinde'?vehPaintTex('#2c312e',1):vehPaintTex(sand?'#a08f68':'#5c6650',0);t.repeat.set(.6,.6);
   return new THREE.MeshStandardMaterial(Object.assign({map:t,roughness:kind==='blinde'?.5:.75,metalness:kind==='blinde'?.45:.25},reliefOf(t,3)));}
  case 'tarp':{const t=vehTarpTex(sand?'#b4a37c':'#5d6648');t.repeat.set(.7,.7);
   return new THREE.MeshStandardMaterial(Object.assign({map:t,roughness:.97,side:THREE.DoubleSide},reliefOf(t,2)));}
  case 'inner':return new THREE.MeshStandardMaterial({map:carInTex(),roughness:.85,metalness:.3});
  case 'floor':return new THREE.MeshStandardMaterial({map:heliFloorTex(),roughness:.95});
  case 'wood':{const t=woodTex().clone();t.needsUpdate=true;t.wrapS=t.wrapT=THREE.RepeatWrapping;t.repeat.set(2.5,2.5);return new THREE.MeshStandardMaterial({map:t,roughness:.85});}
  case 'glass':return new THREE.MeshStandardMaterial({color:C(0x1a2630),roughness:.05,metalness:.8,transparent:true,opacity:.35,depthWrite:false,side:THREE.DoubleSide});
  case 'headlight':return E(0xfff4dd,2.2);
  case 'taillight':return E(0xff2010,1.4);
  case 'amber':return E(0xff8a10,1.2);
  case 'beacon_L':return new THREE.MeshStandardMaterial({color:C(0x001a55),emissive:C(0x2a6bff),emissiveIntensity:0});
  case 'beacon_R':return new THREE.MeshStandardMaterial({color:C(0x550000),emissive:C(0xff2a2a),emissiveIntensity:0});
 }
 return new THREE.MeshStandardMaterial({color:col,metalness:mr,roughness:ro});
}
// UV par projection cubique (axe dominant de la normale), en mètres
function vehBoxUV(pos,nrm,sc){
 const n=pos.length/3,uv=new Float32Array(n*2);
 for(let i=0;i<n;i++){const ax=Math.abs(nrm[i*3]),ay=Math.abs(nrm[i*3+1]),az=Math.abs(nrm[i*3+2]),x=pos[i*3],y=pos[i*3+1],z=pos[i*3+2];
  if(ax>=ay&&ax>=az){uv[i*2]=z*sc;uv[i*2+1]=y*sc;}else if(ay>=az){uv[i*2]=x*sc;uv[i*2+1]=z*sc;}else{uv[i*2]=x*sc;uv[i*2+1]=y*sc;}}
 return uv;
}
const VEH_ANIM=/^(wheel_|door_|tailgate|beacon_)/;
function loadVehicle(kind){
 const file=kind.startsWith('camion')?'camion':kind;
 if(typeof VEH_DATA==='undefined'||!VEH_DATA[file])return null;
 const buf=b64buf(VEH_DATA[file]),dv=new DataView(buf),jl=dv.getUint32(12,true);
 const json=JSON.parse(new TextDecoder().decode(new Uint8Array(buf,20,jl)));
 const bl=dv.getUint32(20+jl,true),bin=buf.slice(28+jl,28+jl+bl);
 const TY={5126:Float32Array,5125:Uint32Array,5123:Uint16Array,5121:Uint8Array},NC={SCALAR:1,VEC2:2,VEC3:3,VEC4:4};
 const acc=i=>{const a=json.accessors[i],bv=json.bufferViews[a.bufferView],T=TY[a.componentType],o=(bv.byteOffset||0)+(a.byteOffset||0);return new T(bin.slice(o,o+a.count*NC[a.type]*T.BYTES_PER_ELEMENT));};
 const mats=json.materials.map(m=>vehMat(m.name,m.pbrMetallicRoughness||{},kind));
 const g=new THREE.Group(),U=g.userData,parts={},buckets=new Map();
 // triangles d'une primitive, transformés par M, versés dans le seau de son matériau (ou un maillage à part)
 const prim=(p,M,into)=>{
  const P0=acc(p.attributes.POSITION),N0=acc(p.attributes.NORMAL),I=p.indices!==undefined?acc(p.indices):null,cnt=I?I.length:P0.length/3;
  const pos=new Float32Array(cnt*3),nrm=new Float32Array(cnt*3),v=new THREE.Vector3(),nm=new THREE.Matrix3().getNormalMatrix(M);
  for(let k=0;k<cnt;k++){const j=I?I[k]:k;v.set(P0[j*3],P0[j*3+1],P0[j*3+2]).applyMatrix4(M);pos[k*3]=v.x;pos[k*3+1]=v.y;pos[k*3+2]=v.z;
   v.set(N0[j*3],N0[j*3+1],N0[j*3+2]).applyMatrix3(nm).normalize();nrm[k*3]=v.x;nrm[k*3+1]=v.y;nrm[k*3+2]=v.z;}
  const mi=p.material||0;if(!into.has(mi))into.set(mi,[]);into.get(mi).push([pos,nrm]);
 };
 const flush=(into,parent)=>{for(const [mi,L] of into){
  let n=0;for(const [a] of L)n+=a.length;const pos=new Float32Array(n),nrm=new Float32Array(n);let o=0;for(const [a,b] of L){pos.set(a,o);nrm.set(b,o);o+=a.length;}
  const geo=new THREE.BufferGeometry();geo.setAttribute('position',new THREE.BufferAttribute(pos,3));geo.setAttribute('normal',new THREE.BufferAttribute(nrm,3));
  geo.setAttribute('uv',new THREE.BufferAttribute(vehBoxUV(pos,nrm,.5),2));
  const m=new THREE.Mesh(geo,mats[mi]);m.castShadow=!mats[mi].transparent;m.receiveShadow=true;parent.add(m);}};
 const walk=(ni,PM)=>{
  const n=json.nodes[ni],L=new THREE.Matrix4().compose(V3().fromArray(n.translation||[0,0,0]),new THREE.Quaternion().fromArray(n.rotation||[0,0,0,1]),V3().fromArray(n.scale||[1,1,1]));
  const M=PM.clone().multiply(L);
  if(n.mesh!==undefined){
   if(VEH_ANIM.test(n.name||'')){
    // pièce animée : son propre groupe à son pivot, géométrie en local
    const pg=new THREE.Group();pg.position.setFromMatrixPosition(M);g.add(pg);parts[n.name]=pg;
    const loc=new Map();for(const p of json.meshes[n.mesh].primitives)prim(p,new THREE.Matrix4().extractRotation(M),loc);flush(loc,pg);
   }else for(const p of json.meshes[n.mesh].primitives)prim(p,M,buckets);
  }
  for(const c of n.children||[])walk(c,M);
 };
 for(const ni of json.scenes[json.scene||0].nodes)walk(ni,new THREE.Matrix4());
 flush(buckets,g);
 const I=VEH_INFO[file]||{};
 U.kind=kind;U.CF=I.CF;U.CW=I.W;U.Z1=I.rear;U.wheelR=I.wheelR||.5;U.tailgate=parts.tailgate||null;
 U.doors=[parts.door_L,parts.door_R].filter(Boolean);
 U.wheels=['wheel_FL','wheel_FR','wheel_RL','wheel_RR'].map(k=>parts[k]).filter(Boolean);
 U.beacons=['beacon_L','beacon_R'].filter(k=>parts[k]).map(k=>parts[k].children[0].material);
 U.seats=I.seats;U.player=I.player;U.driver=I.driver;
 // halo des phares
 const hz=-(file==='blinde'?3.08:3.25),hy=file==='blinde'?1.36:1.25,hx=file==='blinde'?.8:.85;
 for(const s of [-1,1]){const gl=new THREE.Sprite(new THREE.SpriteMaterial({map:GLOW.white,blending:THREE.AdditiveBlending,transparent:true,depthWrite:false,opacity:.75}));gl.scale.set(1.5,1.5,1);gl.position.set(s*hx,hy,hz-.15);g.add(gl);}
 return g;
}
const VEH_CACHE={};
function makeVehicle(){
 const k=carKind();
 if(cfg.vehGlb!==0&&VEH_CACHE[k]===undefined){try{VEH_CACHE[k]=loadVehicle(k);}catch(e){console.warn('véhicule',k,e);VEH_CACHE[k]=null;}}
 return cfg.vehGlb!==0&&VEH_CACHE[k]||makeCar();
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
// dégage le couloir de la route : décors hors carte (immeubles de l'horizon, pins, minarets…) masqués le temps de la cinématique
function carClear(E,u,n){
 const hid=[],m4=new THREE.Matrix4(),p=V3(),q=new THREE.Quaternion(),sc=V3(),Z=new THREE.Matrix4().makeScale(0,0,0);
 const inside=(x,z,r)=>{const dn=(x-E.x)*n.x+(z-E.z)*n.z,du=-((x-E.x)*u.x+(z-E.z)*u.z);return dn>-4.5&&dn<11+r&&du>-30-r&&du<135+r;};
 for(const o of worldG.children){
  if(o.isInstancedMesh){let ch=0;const keep=[];
   for(let i=0;i<o.count;i++){o.getMatrixAt(i,m4);m4.decompose(p,q,sc);if(inside(p.x,p.z,Math.max(sc.x,sc.z)*2.5)){keep.push([i,m4.clone()]);o.setMatrixAt(i,Z);ch=1;}}
   if(ch){o.instanceMatrix.needsUpdate=true;hid.push({o,keep});}
  }else if(o.visible&&!o.isLight){const M=N*S,ps=o.position;
   if((ps.x<-1||ps.x>M+1||ps.z<-1||ps.z>M+1)&&inside(ps.x,ps.z,4)){o.visible=false;hid.push({o});}}
 }
 return hid;
}
function carRestore(hid){for(const h of hid||[]){if(h.keep){for(const [i,m] of h.keep)h.o.setMatrixAt(i,m);h.o.instanceMatrix.needsUpdate=true;}else h.o.visible=true;}}
function startCarCine(){
 CINE.on=true;CINE.t=0;CINE.skipped=false;CINE.team=P.team;CINE.car=true;CINE.covered=true;CINE.dur=9.9;
 const H=makeVehicle();scene.add(H);CINE.heli=H;
 const HU=H.userData;
 for(const d of HU.doors)d.rotation.y=0;if(HU.tailgate)HU.tailgate.rotation.x=0;
 // arrêt : juste à l'extérieur du bord de carte le plus proche du camp de l'équipe ; la route longe ce bord
 const roster=ents.filter(e=>e.team===P.team);
 let hx=0,hz=0;for(const e of roster){hx+=e.x;hz+=e.z;}hx/=roster.length||1;hz/=roster.length||1;
 const M=N*S,cx=M/2,cz=M/2,dx=hx-cx,dz=hz-cz;
 let E,u,n;
 if(Math.abs(dx)>Math.abs(dz)){const s=dx>0?1:-1;n=V3(s,0,0);E=V3(s>0?M+5:-5,0,clamp(hz,12,M-12));u=V3(0,0,hz<cz?1:-1);}
 else{const s=dz>0?1:-1;n=V3(0,0,s);E=V3(clamp(hx,12,M-12),0,s>0?M+5:-5);u=V3(hx<cx?1:-1,0,0);}
 CINE.E=E;CINE.u=u;CINE.n=n;CINE.yaw=Math.atan2(-u.x,-u.z);CINE.dist=70;
 CINE.road=carRoad(E,u,140);scene.add(CINE.road);CINE.hid=carClear(E,u,n);
 // chauffeur
 for(const R of CINE.pilots)if(R.root.parent)R.root.parent.remove(R.root);CINE.pilots=[];
 {const look={kind:P.team===0?'t':'ct',acc:PALETTE[P.team===0?5:1],tone:SKIN_TONES[1]};const R=makeSoldier(look);setSoldierGun(R,'usp');R.gunObj.visible=false;
  const dp=HU.seats?HU.driver:[-.5,-1.62];
  if(dp){R.root.position.set(dp[0],HU.CF,dp[1]);H.add(R.root);CINE.pilots.push(R);}}
 // coéquipiers sur les banquettes (le joueur est assis à gauche, au milieu)
 const mates=roster.filter(e=>!e.isPlayer);
 const SEATS=HU.seats?HU.seats.map(([x,z])=>({x,z,f:x<0?-Math.PI/2:Math.PI/2})):[{x:-.72,z:-.35,f:-Math.PI/2},{x:.72,z:-.35,f:Math.PI/2},{x:.72,z:.55,f:Math.PI/2},{x:.72,z:1.45,f:Math.PI/2}];
 CINE.pp=HU.player?{x:HU.player[0],z:HU.player[1]}:{x:-.68,z:.55};   // place du joueur
 CINE.seats=[];
 mates.forEach((e,i)=>{
  e.cineSeat=true;e.seated=1;
  const st=SEATS[i];if(!st){e.cineSeat=false;e.seated=0;e.rig.root.visible=false;CINE.seats.push({e,hidden:true});return;}
  H.add(e.rig.root);e.rig.root.position.set(st.x,H.userData.CF,st.z);e.rig.root.rotation.set(0,st.f,0);e.y=H.userData.CF;
  CINE.seats.push({e,x:st.x,z:st.z,f:st.f,drop:6.3+i*.3});
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
const CLOOKA=[[2.4,.05],[3.3,-.1],[4.3,-1.15],[5.3,-1.25],[6.0,-.2],[6.8,2.6]];
const CLOOKP=[[2.4,-.08],[3.3,-.1],[4.3,-.22],[5.3,-.2],[6.0,-.1],[6.8,-.12]];
function updateCarCine(dt,t){
 CINE.t+=dt;const T=CINE.t,H=CINE.heli,U=H.userData,E=CINE.E,u=CINE.u,n=CINE.n;
 const d=carDist(T),d2=carDist(T+.05),v=(d-d2)/.05;
 H.position.set(E.x-u.x*d,0,E.z-u.z*d);
 // tangage au freinage, petites secousses de la route
 const brake=T>CAR_STOP-1.6&&T<CAR_STOP+.4?Math.sin(clamp((T-(CAR_STOP-1.6))/2,0,1)*Math.PI)*.025:0;
 H.position.y=Math.sin(T*11)*.012*Math.min(1,v/8);
 _he.set(-brake+Math.sin(T*7.3)*.003*Math.min(1,v/8),CINE.yaw,Math.sin(T*5.1)*.004*Math.min(1,v/8),'YXZ');H.quaternion.setFromEuler(_he);
 for(const w of U.wheels)w.rotation.x-=v*dt/(U.wheelR||.48);
 U.beacons.forEach((b,i)=>b.emissiveIntensity=((T*3+i*.5)%1)<.5?2.5:0);
 // portes arrière qui s'ouvrent (ou hayon du camion qui s'abaisse)
 const ko=easeIO((T-6.0)/.7);if(U.doors.length===2){U.doors[0].rotation.y=-ko*1.9;U.doors[1].rotation.y=ko*1.9;}
 if(U.tailgate)U.tailgate.rotation.x=ko*1.62;
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
 }else if(T<7.6){ // plan 2 : assis dans la cellule, on regarde la route puis les coéquipiers
  const a=keyAt(CLOOKA,T),p=keyAt(CLOOKP,T),vib=Math.min(1,v/8);
  _hp.set(CINE.pp.x+.1+Math.sin(T*13.1)*.004*vib,U.CF+1.12+Math.sin(T*17.3)*.006*vib,CINE.pp.z);H.localToWorld(_hp);camera.position.copy(_hp);
  _he.set(p+Math.sin(T*9.7)*.004*vib,a,Math.sin(T*1.9)*.006,'YXZ');_hq.setFromEuler(_he);
  camera.quaternion.copy(H.quaternion).multiply(_hq);camera.fov=70;
 }else{ // plan 3 : les coéquipiers sont descendus ; on se lève, on sort par l'arrière et on se tourne vers l'objectif
  const k=easeIO((T-7.6)/1.6);
  _hp.set(lerp(CINE.pp.x+.1,0,k),lerp(U.CF+1.12,1.6,k),lerp(CINE.pp.z,U.Z1+2.2,k));H.localToWorld(_hp);
  camera.position.copy(_hp);
  _he.set(-.08,CINE.yaw+Math.PI,0,'YXZ');_hq.setFromEuler(_he);
  _he.set(-.03,Math.atan2(n.x,n.z),0,'YXZ');_hq2.setFromEuler(_he);
  camera.quaternion.copy(_hq).slerp(_hq2,easeIO((T-8.6)/1.0));camera.fov=72;
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
  if(car){if(CINE.road){scene.remove(CINE.road);CINE.road=null;}carRestore(CINE.hid);CINE.hid=null;CINE.pilots=[];CINE.car=false;}
 };
}
