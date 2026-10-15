/* =====================================================================
   VISEURS EN 3D : modèles faits dans Blender (tools/blender/optics.py, GLB intégrés : OPT_DATA / OPT_INFO)
   - remplacent la géométrie procédurale des optiques posées par attBuild (point rouge, holo, mini réflex,
     ACOG, lunettes ×4 à ×10) ; la lentille et le réticule restent ceux du jeu (même ligne de visée)
   - cfg.optics3d=0 pour revenir aux viseurs simples
   ===================================================================== */
const OPT3D_KEY={reddot:'reddot',holo:'holo',mini:'mini',acog:'acog',sc4:'scope',sc6:'scope',sc8:'scope',sc10:'scope'};
const OPT3D_MAT={
 body:()=>new THREE.MeshStandardMaterial({color:C(0x17191c),roughness:.5,metalness:.35}),
 dark:()=>new THREE.MeshStandardMaterial({color:C(0x2a2e34),roughness:.32,metalness:.75}),
 rubber:()=>new THREE.MeshStandardMaterial({color:C(0x0d0d0f),roughness:.92,metalness:0}),
 metal:()=>new THREE.MeshStandardMaterial({color:C(0x9a9ca2),roughness:.25,metalness:1}),
 tan:()=>new THREE.MeshStandardMaterial({color:C(0x7a6a4c),roughness:.55,metalness:.3}),
 emit_red:()=>new THREE.MeshStandardMaterial({color:C(0x400404),emissive:C(0xff2010),emissiveIntensity:1.6,roughness:.4}),
 emit_fiber:()=>new THREE.MeshStandardMaterial({color:C(0x401004),emissive:C(0xff4a10),emissiveIntensity:1.8,roughness:.3})
};
const OPT3D_TPL={},OPT3D_MATS={};
// GLB -> groupe (un maillage par matériau), lu une fois puis cloné
function opt3dTemplate(key){
 if(OPT3D_TPL[key]!==undefined)return OPT3D_TPL[key];
 OPT3D_TPL[key]=null;
 if(typeof OPT_DATA==='undefined'||!OPT_DATA[key])return null;
 try{
  const buf=b64buf(OPT_DATA[key]),dv=new DataView(buf),jl=dv.getUint32(12,true);
  const json=JSON.parse(new TextDecoder().decode(new Uint8Array(buf,20,jl)));
  const bl=dv.getUint32(20+jl,true),bin=buf.slice(28+jl,28+jl+bl);
  const TY={5126:Float32Array,5125:Uint32Array,5123:Uint16Array,5121:Uint8Array},NC={SCALAR:1,VEC2:2,VEC3:3,VEC4:4};
  const acc=i=>{const a=json.accessors[i],bv=json.bufferViews[a.bufferView],T=TY[a.componentType],o=(bv.byteOffset||0)+(a.byteOffset||0);return new T(bin.slice(o,o+a.count*NC[a.type]*T.BYTES_PER_ELEMENT));};
  const names=(json.materials||[]).map(m=>m.name),buckets=new Map(),v=new THREE.Vector3();
  const walk=(ni,PM)=>{
   const n=json.nodes[ni],L=new THREE.Matrix4();
   if(n.matrix)L.fromArray(n.matrix);else L.compose(V3().fromArray(n.translation||[0,0,0]),new THREE.Quaternion().fromArray(n.rotation||[0,0,0,1]),V3().fromArray(n.scale||[1,1,1]));
   const M=new THREE.Matrix4().multiplyMatrices(PM,L),nm=new THREE.Matrix3().getNormalMatrix(M);
   if(n.mesh!==undefined)for(const p of json.meshes[n.mesh].primitives){
    const P0=acc(p.attributes.POSITION),N0=acc(p.attributes.NORMAL),I=p.indices!==undefined?acc(p.indices):null,cnt=I?I.length:P0.length/3;
    const pos=new Float32Array(cnt*3),nrm=new Float32Array(cnt*3);
    for(let k=0;k<cnt;k++){const j=I?I[k]:k;v.set(P0[j*3],P0[j*3+1],P0[j*3+2]).applyMatrix4(M);pos[k*3]=v.x;pos[k*3+1]=v.y;pos[k*3+2]=v.z;
     v.set(N0[j*3],N0[j*3+1],N0[j*3+2]).applyMatrix3(nm).normalize();nrm[k*3]=v.x;nrm[k*3+1]=v.y;nrm[k*3+2]=v.z;}
    const mn=names[p.material||0]||'body';if(!buckets.has(mn))buckets.set(mn,[]);buckets.get(mn).push([pos,nrm]);}
   for(const c of n.children||[])walk(c,M);
  };
  for(const r of json.scenes[json.scene||0].nodes)walk(r,new THREE.Matrix4());
  const g=new THREE.Group();
  for(const [mn,Ls] of buckets){
   let n=0;for(const [a] of Ls)n+=a.length;const pos=new Float32Array(n),nrm=new Float32Array(n);let o=0;
   for(const [a,b] of Ls){pos.set(a,o);nrm.set(b,o);o+=a.length;}
   const geo=new THREE.BufferGeometry();geo.setAttribute('position',new THREE.BufferAttribute(pos,3));geo.setAttribute('normal',new THREE.BufferAttribute(nrm,3));
   const mat=OPT3D_MATS[mn]||(OPT3D_MATS[mn]=(OPT3D_MAT[mn]||OPT3D_MAT.body)());
   const m=new THREE.Mesh(geo,mat);m.castShadow=true;g.add(m);}
  return OPT3D_TPL[key]=g;
 }catch(e){console.warn('viseur 3D',key,e);return null;}
}
// lentille / réticule du viseur procédural (matériaux « basic ») : on garde, le reste est remplacé par le modèle
const opt3dKeep=m=>m.isMesh&&m.material&&m.material.isMeshBasicMaterial;
function opt3dApply(o,a){
 const key=OPT3D_KEY[a],tpl=key&&opt3dTemplate(key),inf=key&&typeof OPT_INFO!=='undefined'&&OPT_INFO[key];
 if(!tpl||!inf||o.userData.o3d)return;
 // centre de la lentille (repère du groupe) : la ligne de visée passe par là
 let n=0;const c=V3();o.traverse(m=>{if(opt3dKeep(m)&&m.geometry&&(m.geometry.type==='CircleGeometry'||m.geometry.type==='PlaneGeometry')&&m.parent===o){c.add(m.position);n++;}});
 if(!n)return;c.divideScalar(n);
 // les lunettes ×4 sont un peu plus petites que les ×6 à ×10
 const s=key==='scope'?(a==='sc4'?.88:1):1;
 const m=tpl.clone();m.scale.setScalar(s);
 // la lentille du jeu est posée devant (avant = -Z) : le modèle est recalé pour que sa fenêtre tombe dessus
 m.position.set(0,c.y-inf.cy*s,c.z+inf.lensY*s);
 for(const ch of o.children.slice())if(!opt3dKeep(ch))ch.visible=false;
 m.userData.o3d=1;o.add(m);o.userData.o3d=m;
}
{const _attBuild=attBuild;attBuild=function(g,k,sel,opt){
 const list=_attBuild(g,k,sel,opt);
 if(cfg.optics3d!==0)for(const o of g.children){const a=o.userData&&o.userData.att;if(a&&OPT3D_KEY[a])opt3dApply(o,a);}
 return list;};}
