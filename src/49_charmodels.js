/* =====================================================================
   PERSONNAGES 3D ANIMÉS (glTF binaire avec squelette + animations)
   Lecteur glTF complet minimal : os, poids, textures, clips d'animation.
   Utilisé pour les zombies (modèle Quaternius, domaine public).
   ===================================================================== */
const CHARF={};
function charFactory(key){
 if(CHARF[key]!==undefined)return CHARF[key];
 if(typeof CHAR_DATA==='undefined'||!CHAR_DATA[key])return CHARF[key]=null;
 try{CHARF[key]=buildCharFactory(b64buf(CHAR_DATA[key]));}catch(e){console.warn('modèle',key,e);CHARF[key]=null;}
 return CHARF[key];
}
function buildCharFactory(buf){
 const dv=new DataView(buf),jl=dv.getUint32(12,true);
 const json=JSON.parse(new TextDecoder().decode(new Uint8Array(buf,20,jl)));
 const bl=dv.getUint32(20+jl,true),bin=buf.slice(28+jl,28+jl+bl);
 const TY={5126:Float32Array,5125:Uint32Array,5123:Uint16Array,5122:Int16Array,5121:Uint8Array,5120:Int8Array},NC={SCALAR:1,VEC2:2,VEC3:3,VEC4:4,MAT4:16};
 const acc=i=>{const a=json.accessors[i],bv=json.bufferViews[a.bufferView],T=TY[a.componentType],n=NC[a.type],off=(bv.byteOffset||0)+(a.byteOffset||0),es=T.BYTES_PER_ELEMENT;
  if(bv.byteStride&&bv.byteStride!==n*es){const out=new T(a.count*n),src=new DataView(bin);
   for(let k=0;k<a.count;k++)for(let c=0;c<n;c++){const o=off+k*bv.byteStride+c*es;out[k*n+c]=T===Float32Array?src.getFloat32(o,true):T===Uint16Array?src.getUint16(o,true):T===Uint8Array?src.getUint8(o):src.getUint32(o,true);}
   return {arr:out,a};}
  return {arr:new T(bin.slice(off,off+a.count*n*es)),a};};
 // textures
 const texs=(json.textures||[]).map(t=>{
  const im=json.images[t.source],bv=json.bufferViews[im.bufferView];
  const blob=new Blob([new Uint8Array(bin,bv.byteOffset||0,bv.byteLength)],{type:im.mimeType||'image/png'});
  const tex=new THREE.Texture();tex.flipY=false;tex.encoding=THREE.sRGBEncoding;
  const img=new Image();img.onload=()=>{tex.image=img;tex.needsUpdate=true;};img.src=URL.createObjectURL(blob);return tex;});
 const mats=(json.materials||[]).map(m=>{const pb=m.pbrMetallicRoughness||{},f=pb.baseColorFactor||[1,1,1,1];
  const mt=new THREE.MeshStandardMaterial({color:new THREE.Color(f[0],f[1],f[2]),roughness:pb.roughnessFactor!==undefined?pb.roughnessFactor:.8,metalness:pb.metallicFactor!==undefined?pb.metallicFactor:0,skinning:true});
  if(pb.baseColorTexture)mt.map=texs[pb.baseColorTexture.index];return mt;});
 // géométries
 const geos={};
 const prim=(mi,pi)=>{const key=mi+'_'+pi;if(geos[key])return geos[key];const p=json.meshes[mi].primitives[pi],g=new THREE.BufferGeometry(),at=p.attributes;
  const add=(name,id,norm)=>{if(id===undefined)return;const r=acc(id);g.setAttribute(name,new THREE.BufferAttribute(r.arr,NC[r.a.type],!!(norm||r.a.normalized)));};
  add('position',at.POSITION);add('normal',at.NORMAL);add('uv',at.TEXCOORD_0);add('skinIndex',at.JOINTS_0);add('skinWeight',at.WEIGHTS_0);
  if(p.indices!==undefined)g.setIndex(new THREE.BufferAttribute(acc(p.indices).arr,1));
  if(!at.NORMAL)g.computeVertexNormals();return geos[key]=g;};
 // os
 const jointSet=new Set();for(const s of json.skins||[])for(const j of s.joints)jointSet.add(j);
 const nodeName=i=>THREE.PropertyBinding.sanitizeNodeName(json.nodes[i].name||('node_'+i));
 // clips
 const clips={};
 for(const an of json.animations||[]){
  const tracks=[];
  for(const ch of an.channels){const s=an.samplers[ch.sampler],t=acc(s.input).arr,v=acc(s.output).arr,nm=nodeName(ch.target.node),path=ch.target.path;
   const interp=s.interpolation==='STEP'?THREE.InterpolateDiscrete:THREE.InterpolateLinear;
   if(path==='rotation')tracks.push(new THREE.QuaternionKeyframeTrack(nm+'.quaternion',Array.from(t),Array.from(v),interp));
   else if(path==='translation')tracks.push(new THREE.VectorKeyframeTrack(nm+'.position',Array.from(t),Array.from(v),interp));
   else if(path==='scale')tracks.push(new THREE.VectorKeyframeTrack(nm+'.scale',Array.from(t),Array.from(v),interp));}
  clips[an.name.split('|').pop()]=new THREE.AnimationClip(an.name.split('|').pop(),-1,tracks);
 }
 const ibm=(json.skins||[]).map(s=>{const m=acc(s.inverseBindMatrices).arr,out=[];for(let k=0;k<s.joints.length;k++)out.push(new THREE.Matrix4().fromArray(m,k*16));return out;});
 // nouvelle instance (os et maillages propres, géométries/matériaux partagés)
 function instance(){
  const objs=json.nodes.map((n,i)=>{const o=jointSet.has(i)?new THREE.Bone():new THREE.Group();o.name=nodeName(i);
   if(n.matrix){new THREE.Matrix4().fromArray(n.matrix).decompose(o.position,o.quaternion,o.scale);}
   if(n.translation)o.position.fromArray(n.translation);if(n.rotation)o.quaternion.fromArray(n.rotation);if(n.scale)o.scale.fromArray(n.scale);return o;});
  json.nodes.forEach((n,i)=>{for(const c of n.children||[])objs[i].add(objs[c]);});
  const root=new THREE.Group();for(const ni of json.scenes[json.scene||0].nodes)root.add(objs[ni]);
  root.updateMatrixWorld(true);
  const skinned=[];
  json.nodes.forEach((n,i)=>{if(n.mesh===undefined)return;
   json.meshes[n.mesh].primitives.forEach((p,pi)=>{const g=prim(n.mesh,pi),mt=p.material!==undefined?mats[p.material]:new THREE.MeshStandardMaterial({skinning:true});
    let m;if(n.skin!==undefined){m=new THREE.SkinnedMesh(g,mt);skinned.push([m,n.skin]);}else m=new THREE.Mesh(g,mt);
    m.castShadow=true;m.frustumCulled=false;objs[i].add(m);});});
  root.updateMatrixWorld(true);
  for(const [m,si] of skinned){const s=json.skins[si];m.bind(new THREE.Skeleton(s.joints.map(j=>objs[j]),ibm[si]),m.matrixWorld);}
  return root;
 }
 return {instance,clips};
}
/* ---------- zombies animés ---------- */
const zombieModelReady=()=>!!charFactory('zombie');
function attachZombieModel(e){
 const F=charFactory('zombie');
 const root=new THREE.Group(),inner=F.instance();inner.rotation.y=Math.PI;root.add(inner);   // le modèle regarde vers +Z, le jeu vers -Z
 scene.add(root);
 const mixer=new THREE.AnimationMixer(inner),act={};
 for(const k in F.clips){act[k]=mixer.clipAction(F.clips[k]);}
 if(act.Death){act.Death.setLoop(THREE.LoopOnce,1);act.Death.clampWhenFinished=true;}
 if(act.Punch){act.Punch.setLoop(THREE.LoopOnce,1);}
 if(act.HitReact){act.HitReact.setLoop(THREE.LoopOnce,1);}
 const R={root,zm:true,mixer,act,cur:null,dieT:-1,label:null,ph:Math.random()*3};
 e.rig=R;zmPlay(R,'Walk',0);
 return R;
}
function zmPlay(R,name,fade){
 const a=R.act[name];if(!a||R.cur===name)return;
 const old=R.cur&&R.act[R.cur];a.reset();a.enabled=true;a.setEffectiveWeight(1);a.play();
 if(old&&fade>0)a.crossFadeFrom(old,fade,false);else if(old)old.stop();
 R.cur=name;
}
function zmUpdate(e,R,dt){
 R.root.visible=true;R.root.position.set(e.x,e.y,e.z);R.root.rotation.y=e.yaw;
 let sp=1;
 if(!e.alive){if(R.cur!=='Death'){zmPlay(R,'Death',.15);}}
 else if(e.frozenT>0){sp=0;}
 else if(e.fireAnim>.6&&R.cur!=='Punch'){zmPlay(R,'Punch',.1);R.punchT=.7;}
 else if(R.punchT>0){R.punchT-=dt;}
 else if(e.hurtFlag&&R.cur!=='HitReact'&&Math.random()<.3){zmPlay(R,'HitReact',.08);R.punchT=.35;}
 else if(e.ztype==='crawler'&&R.act.Crawl){zmPlay(R,'Crawl',.2);sp=clamp((e.speed||0)/2.5,.6,1.8);}
 else{const s=e.speed||0;zmPlay(R,s>3.8?(R.act.Run_Attack&&e.target&&Math.hypot(e.target.x-e.x,e.target.z-e.z)<5?'Run_Attack':'Run'):s>.3?'Walk':'Idle',.25);
  if(R.cur==='Walk')sp=clamp(s/2.4,.6,1.6);else if(R.cur==='Run')sp=clamp(s/5,.8,1.4);}
 e.hurtFlag=false;
 R.mixer.timeScale=sp;R.mixer.update(dt);
}
