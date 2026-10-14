/* =====================================================================
   PERSONNAGES 3D ANIMÉS (glTF binaire avec squelette + animations)
   Lecteur glTF complet minimal : os, poids, textures, clips d'animation.
   Utilisé pour les zombies (modèles CC0, voir plus bas).
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
  if(pb.baseColorTexture)mt.map=texs[pb.baseColorTexture.index];if(m.doubleSided)mt.side=THREE.DoubleSide;return mt;});
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
 // le squelette a été remis à l'échelle (1,8 m) mais pas les translations des clips :
 // on retrouve le facteur en comparant la pose de repos aux clés d'animation
 const ratios=[];
 for(const an of json.animations||[])for(const ch of an.channels){if(ch.target.path!=='translation')continue;
  const rest=json.nodes[ch.target.node].translation;if(!rest)continue;const v=acc(an.samplers[ch.sampler].output).arr;
  const lr=Math.hypot(rest[0],rest[1],rest[2]),lk=Math.hypot(v[0],v[1],v[2]);if(lr>1e-4&&lk>1e-4)ratios.push(lr/lk);}
 ratios.sort((a,b)=>a-b);
 const tScale=ratios.length?ratios[ratios.length>>1]:1,fixT=Math.abs(tScale-1)>.1;
 for(const an of json.animations||[]){
  const tracks=[];
  for(const ch of an.channels){const s=an.samplers[ch.sampler],t=acc(s.input).arr,v=acc(s.output).arr,nm=nodeName(ch.target.node),path=ch.target.path;
   const interp=s.interpolation==='STEP'?THREE.InterpolateDiscrete:THREE.InterpolateLinear;
   if(path==='rotation')tracks.push(new THREE.QuaternionKeyframeTrack(nm+'.quaternion',Array.from(t),Array.from(v),interp));
   else if(path==='translation')tracks.push(new THREE.VectorKeyframeTrack(nm+'.position',Array.from(t),Array.from(v,x=>fixT?x*tScale:x),interp));
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
  for(const [m,si] of skinned){const s=json.skins[si];m.bind(new THREE.Skeleton(s.joints.map(j=>objs[j]),ibm[si]),new THREE.Matrix4());}   // glTF : la transformation du nœud du maillage est ignorée, seuls les os comptent
  return root;
 }
 return {instance,clips};
}
/* ---------- zombies animés (réalistes, variés) ----------
   Modèles photo-réalistes CC0 (elbolilloduro, via Mesh2Motion) avec des
   textures « zombifiées » par tools/zombies/build_zombies.py. Tous partagent
   un squelette : une seule banque d'animations (zanim) sert à tous. */
const ZLOOKS={
 normal:['civ1','civ2','civ3','civ4','civ5','civ6','civ7','civ8','doc','cop1','cop2','civ1','civ3','civ6','hazmat'],
 runner:['ghoul','ghoul','civ2','civ4','civ5','civ7','civ8','cop1'],
 crawler:['rotten','rotten','civ1','civ3','civ6','doc'],
 tank:['swat','swat','hazmat'],
 boss:['brute']
};
const zombieModelReady=()=>!!charFactory('zanim')&&!!charFactory('z_civ1');
const ZCLIPS={};   // clips adaptés à la taille de chaque modèle (hauteur du bassin)
function zClipsFor(key,inner){
 if(ZCLIPS[key])return ZCLIPS[key];
 const A=charFactory('zanim'),pel=inner.getObjectByName('pelvis'),out={};
 const restA=A.restPelvis||(A.restPelvis=(()=>{const r=A.instance().getObjectByName('pelvis');return r?r.position.length():1;})());
 const k=pel?pel.position.length()/restA:1;
 for(const n in A.clips){const c=A.clips[n].clone();
  if(Math.abs(k-1)>.02)for(const t of c.tracks)if(t.name==='pelvis.position'){t.values=t.values.slice();for(let i=0;i<t.values.length;i++)t.values[i]*=k;}
  out[n]=c;}
 return ZCLIPS[key]=out;
}
function zHash(n){n=Math.imul((n|0)^0x5bd1e995,2654435761);n^=n>>>15;n=Math.imul(n,2246822519);n^=n>>>13;return (n>>>0)/4294967296;}
function attachZombieModel(e){
 const type=e.ztype||'normal',pool=ZLOOKS[type]||ZLOOKS.normal,h=zHash((e.id||0)+7);
 let key=pool[Math.floor(h*pool.length)];if(!charFactory('z_'+key))key='civ1';
 const F=charFactory('z_'+key);
 const root=new THREE.Group(),inner=F.instance();
 const sc=type==='boss'?1.08:type==='tank'?1.12:.93+zHash(e.id*3+1)*.14;   // tailles variées
 inner.scale.setScalar(sc);root.add(inner);
 // teinte propre à chaque zombie : plus ou moins pâle, verdâtre ou violacé
 const tint=new THREE.Color().setHSL(.08+zHash(e.id*5+2)*.25,.12+zHash(e.id*11)*.12,.78+zHash(e.id*13)*.14);
 if(type==='boss')tint.setRGB(.95,.72,.7);
 // léger éclairage propre (texture) : ils restent lisibles dans les coins sombres
 inner.traverse(o=>{if(o.isMesh){const m=o.material=o.material.clone();m.color.copy(tint);if(m.map){m.emissiveMap=m.map;m.emissive.setRGB(.24,.24,.24);}}});
 scene.add(root);
 const clips=zClipsFor(key,inner),mixer=new THREE.AnimationMixer(inner),act={};
 for(const k in clips)act[k]=mixer.clipAction(clips[k]);
 for(const k of ['Death','Death2','Death3','Punch','HitReact','HitHead','Yell'])if(act[k]){act[k].setLoop(THREE.LoopOnce,1);act[k].clampWhenFinished=k.startsWith('Death');}
 // démarches variées (deux styles, vitesse propre à chacun) ; les costauds marchent lourdement
 const walks=type==='tank'||type==='boss'?['Stomp']:['Walk','Walk2','Walk'];
 const R={root,inner,zm:true,real:true,look:key,mixer,act,cur:null,label:null,ph:Math.random()*3,
  walk:walks[Math.floor(zHash(e.id*17+3)*walks.length)],death:['Death','Death2','Death3'][Math.floor(zHash(e.id*19)*3)],
  gait:.85+zHash(e.id*23)*.3,yellT:2+Math.random()*6};
 e.rig=R;zmPlay(R,R.walk,0);if(act[R.walk])act[R.walk].time=R.ph;
 return R;
}
function zmPlay(R,name,fade){
 const a=R.act[name];if(!a||R.cur===name)return;
 const old=R.cur&&R.act[R.cur];a.reset();a.enabled=true;a.setEffectiveWeight(1);a.play();
 if(old&&fade>0)a.crossFadeFrom(old,fade,false);else if(old)old.stop();
 R.cur=name;
}
function zmUpdate(e,R,dt){
 R.root.visible=true;R.root.position.set(e.x,e.y,e.z);R.root.rotation.y=e.yaw+Math.PI;   // le modèle regarde vers +Z, le jeu vers -Z
 let sp=1;const s=e.speed||0;
 if(!e.alive){if(R.cur!==R.death)zmPlay(R,R.death,.12);sp=1.15;}
 else if(e.frozenT>0){sp=0;}
 else if(e.fireAnim>.6&&R.cur!=='Punch'){zmPlay(R,'Punch',.1);R.punchT=.75;sp=2;}
 else if(R.punchT>0){R.punchT-=dt;sp=R.cur==='Punch'?2:1.3;}
 else if(e.hurtFlag&&e.ztype!=='boss'&&Math.random()<.3){const h=Math.random()<.5?'HitReact':'HitHead';zmPlay(R,h,.08);R.punchT=.35;sp=1.3;}
 else if(e.ztype==='crawler'&&R.act.Crawl){zmPlay(R,'Crawl',.2);sp=clamp(s/1.6,.7,2.2);}
 else if(s>3.8){zmPlay(R,'Run',.2);sp=clamp(s/5.5,.8,1.3);}
 else if(s>.3){zmPlay(R,R.walk,.25);sp=clamp(s/1.6,.6,2.4)*R.gait;}
 else{R.yellT-=dt;if(R.yellT<=0&&R.act.Yell){zmPlay(R,'Yell',.2);R.punchT=1.6;R.yellT=6+Math.random()*8;}else if(R.cur!=='Yell'||!R.act.Yell.isRunning())zmPlay(R,'Idle',.3);}
 e.hurtFlag=false;
 R.mixer.timeScale=sp;R.mixer.update(dt);
}
