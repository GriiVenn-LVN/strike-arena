/* =====================================================================
   MODÈLES 3D D'ARMES (glTF binaire intégré, préparés dans Blender)
   Lecteur GLB minimal (positions + matériaux de couleur), puis
   remplacement des armes procédurales. Les skins s'appliquent aux
   matériaux classés par couleur (corps / accessoires / bois / acier).
   Les armes sans modèle (couteau, armes prodiges) restent procédurales.
   ===================================================================== */
const GLBT={};
function b64buf(s){const bin=atob(s),u=new Uint8Array(bin.length);for(let i=0;i<bin.length;i++)u[i]=bin.charCodeAt(i);return u.buffer;}
/* textures d'un GLB (modèles réalistes) : image intégrée -> THREE.Texture (chargée en arrière-plan) */
function glbTexture(json,bin,ti,srgb){
 const t=json.textures[ti],im=json.images[t.source],bv=json.bufferViews[im.bufferView];
 const blob=new Blob([new Uint8Array(bin,bv.byteOffset||0,bv.byteLength)],{type:im.mimeType||'image/jpeg'});
 const tex=new THREE.Texture();tex.flipY=false;tex.anisotropy=typeof MAXANI!=='undefined'?MAXANI:4;if(srgb)tex.encoding=THREE.sRGBEncoding;
 const img=new Image();img.onload=()=>{tex.image=img;tex.needsUpdate=true;};img.src=URL.createObjectURL(blob);
 return tex;
}
function parseGLB(buf,real){
 const dv=new DataView(buf),jl=dv.getUint32(12,true);
 const json=JSON.parse(new TextDecoder().decode(new Uint8Array(buf,20,jl)));
 const bl=dv.getUint32(20+jl,true),bin=buf.slice(28+jl,28+jl+bl);
 const TY={5126:Float32Array,5125:Uint32Array,5123:Uint16Array,5121:Uint8Array},NC={SCALAR:1,VEC2:2,VEC3:3,VEC4:4};
 const acc=i=>{const a=json.accessors[i],bv=json.bufferViews[a.bufferView],T=TY[a.componentType];return new T(bin.slice((bv.byteOffset||0)+(a.byteOffset||0),(bv.byteOffset||0)+(a.byteOffset||0)+a.count*NC[a.type]*T.BYTES_PER_ELEMENT));};
 const root=new THREE.Group();
 const mk=(ni,parent)=>{
  const n=json.nodes[ni],g=new THREE.Group();g.name=n.name||'';
  if(n.translation)g.position.fromArray(n.translation);if(n.rotation)g.quaternion.fromArray(n.rotation);if(n.scale)g.scale.fromArray(n.scale);
  if(n.mesh!==undefined)for(const p of json.meshes[n.mesh].primitives){
   let geo=new THREE.BufferGeometry();geo.setAttribute('position',new THREE.BufferAttribute(acc(p.attributes.POSITION),3));
   if(p.indices!==undefined)geo.setIndex(new THREE.BufferAttribute(acc(p.indices),1));
   const mt=p.material!==undefined?json.materials[p.material]:null,pb=mt&&mt.pbrMetallicRoughness||{};
   if(real){
    // modèle réaliste : normales lissées et textures d'origine (couleur, normales, métal/rugosité)
    if(p.attributes.NORMAL!==undefined)geo.setAttribute('normal',new THREE.BufferAttribute(acc(p.attributes.NORMAL),3));else geo.computeVertexNormals();
    if(p.attributes.TEXCOORD_0!==undefined)geo.setAttribute('uv',new THREE.BufferAttribute(acc(p.attributes.TEXCOORD_0),2));
    const o={color:new THREE.Color().fromArray(pb.baseColorFactor||[1,1,1]),metalness:pb.metallicFactor!==undefined?pb.metallicFactor:1,roughness:pb.roughnessFactor!==undefined?pb.roughnessFactor:1};
    if(pb.baseColorTexture)o.map=glbTexture(json,bin,pb.baseColorTexture.index,true);
    if(pb.metallicRoughnessTexture){const t=glbTexture(json,bin,pb.metallicRoughnessTexture.index,false);o.metalnessMap=t;o.roughnessMap=t;}
    if(mt&&mt.normalTexture)o.normalMap=glbTexture(json,bin,mt.normalTexture.index,false);
    if(mt&&mt.occlusionTexture&&geo.attributes.uv){o.aoMap=glbTexture(json,bin,mt.occlusionTexture.index,false);geo.setAttribute('uv2',geo.attributes.uv);}
    const m=new THREE.Mesh(geo,new THREE.MeshStandardMaterial(o));m.userData.real=true;g.add(m);continue;
   }
   geo=geo.index?geo.toNonIndexed():geo;geo.computeVertexNormals();     // facettes nettes (style low-poly)
   const m=new THREE.Mesh(geo);m.userData.col=pb.baseColorFactor||[.5,.5,.5,1];m.userData.metal=pb.metallicFactor!==undefined?pb.metallicFactor:0;m.userData.rough=pb.roughnessFactor!==undefined?pb.roughnessFactor:.6;
   g.add(m);
  }
  for(const c of n.children||[])mk(c,g);
  parent.add(g);
 };
 for(const ni of json.scenes[json.scene||0].nodes)mk(ni,root);
 return root;
}
function glbTemplate(k,real){
 const id=(real?'r:':'')+k;
 if(GLBT[id]!==undefined)return GLBT[id];
 try{GLBT[id]=parseGLB(b64buf(real?GLB_REAL_DATA[k]:GLB_DATA[k]),real);}catch(e){console.warn('GLB',id,e);GLBT[id]=null;}
 return GLBT[id];
}
/* modèle réaliste texturé : seulement avec la finition d'usine (un skin repasse sur le modèle stylisé, qu'il peut peindre) */
let GLB_ICON=0;
function useRealGun(k,sk){return !GLB_ICON&&cfg.realGuns!==0&&typeof GLB_REAL_DATA!=='undefined'&&!!GLB_REAL_DATA[k]&&(!sk||sk.def);}
/* sépare les triangles d'une géométrie indexée : ceux entre z0 et z1 posés au-dessus du rail (hauteur y0), et le reste */
function glbSplit(geo,b){
 const P=geo.attributes.position,I=geo.index.array,A=[],B=[];
 const inb=t=>{let lo=1e9,hi=-1e9;for(let j=0;j<3;j++){const i=I[t+j],z=P.getZ(i),y=P.getY(i);if(z<b[0]||z>b[1])return false;lo=Math.min(lo,y);hi=Math.max(hi,y);}return lo>b[2]-.007&&hi>b[2]+.001;};
 for(let t=0;t<I.length;t+=3)(inb(t)?B:A).push(I[t],I[t+1],I[t+2]);
 const mk=ix=>{const g=new THREE.BufferGeometry();for(const n in geo.attributes)g.setAttribute(n,geo.attributes[n]);g.setIndex(ix);return g;};
 return [mk(A),mk(B)];
}
/* couleur source -> rôle du matériau (pour appliquer le skin) */
function glbRole(c){
 const r=c[0],g=c[1],b=c[2],lum=.3*r+.59*g+.11*b,mx=Math.max(r,g,b),mn=Math.min(r,g,b),sat=mx>0?(mx-mn)/mx:0;
 if(r>b*1.5&&r>.04&&sat>.3&&g<r)return 'wood';
 if(sat>.45&&mx>.15)return 'keep';            // couleurs vives d'origine (laiton, détails)
 if(lum>.3)return 'steel';
 if(lum<.035)return 'body';
 return 'acc';
}
function glbGun(k,M,sk,real){
 const tpl=glbTemplate(k,real);if(!tpl)return null;
 const info=(real?GLB_REAL_INFO[k]:GLB_INFO[k])||{},w=W[k],g=new THREE.Group();
 const keepMat={};
 let builtin=null;
 const copy=(src,dst)=>{for(const c of src.children){
  if(c.isMesh&&c.userData.real&&info.optic&&src.name==='body'){
   // viseur intégré au modèle (ex. holographique du M4) : pièce séparée, masquée quand on monte une optique
   const sp=c.userData.split||(c.userData.split=glbSplit(c.geometry,info.optic));
   const m=new THREE.Mesh(sp[0],c.material);m.castShadow=true;dst.add(m);
   builtin=new THREE.Mesh(sp[1],c.material);builtin.castShadow=true;builtin.userData.builtinOptic=1;dst.add(builtin);}
  else if(c.isMesh&&c.userData.real){const m=new THREE.Mesh(c.geometry,c.material);m.castShadow=true;dst.add(m);}
  else if(c.isMesh){const role=glbRole(c.userData.col);let mt=M[role];
   if(role==='keep'||!mt){const key=c.userData.col.join();mt=keepMat[key]||(keepMat[key]=new THREE.MeshStandardMaterial({color:new THREE.Color(c.userData.col[0],c.userData.col[1],c.userData.col[2]),metalness:Math.max(.3,c.userData.metal),roughness:Math.min(.6,c.userData.rough)}));}
   const m=new THREE.Mesh(c.geometry,mt);m.castShadow=true;dst.add(m);}
  else{const n=new THREE.Group();n.name=c.name;n.position.copy(c.position);n.quaternion.copy(c.quaternion);n.scale.copy(c.scale);dst.add(n);copy(c,n);}
 }};
 copy(tpl,g);
 const find=n=>{let r=null;g.traverse(o=>{if(!r&&o.name===n)r=o;});return r;};
 const mag=find('mag'),bolt=find('bolt'),pistol=w.cat==='pistol';
 const L=info.left||[0,0,-.2];
 // ligne de visée : on vise par-dessus les organes de visée (sinon la hausse pleine du modèle masque le centre)
 if(!tpl.userData.top){const bb=new THREE.Box3().setFromObject(tpl);tpl.userData.top=bb.max.y;}
 // modèles réalistes : ligne de visée réglée à la préparation (centre du viseur holographique / de la lunette)
 const sightY=info.ads!==undefined?info.ads:real&&info.sight?info.sight:Math.max(info.sight||.06,tpl.userData.top+.004);
 return finishGun(g,{len:info.len||w.len,muzzle:info.muzzle||-.4,glb:true,
  right:V3(0,-.03,.012),left:pistol?V3(-.012,-.04,.02):V3(L[0],L[1]-.012,L[2]),
  sight:sightY,eject:V3(.025,sightY*.6,(info.muzzle||-.4)*.18),
  mag:mag,slide:pistol?bolt:null,bolt:pistol?null:bolt,twoHand:true,real:!!real,builtinOptic:builtin,
  optSlot:builtin?{z:(info.optic[0]+info.optic[1])/2,y:info.optic[2]-.002}:null});
}
/* icônes (HUD, listes) : toujours le modèle stylisé — les textures du modèle réaliste se chargent en différé et l'icône, mise en cache, resterait noire */
{const wi0=weaponIcon;weaponIcon=function(k,s){GLB_ICON=1;try{return wi0(k,s);}finally{GLB_ICON=0;}};}
/* remplace la fabrique d'armes : modèle 3D si disponible, sinon procédural */
function gunParts(k,sk){
 const w=W[k];let g=null;
 if(!cfg.procGuns&&useRealGun(k,sk))g=glbGun(k,null,sk,true);
 if(!g&&typeof GLB_DATA!=='undefined'&&GLB_DATA[k]&&!cfg.procGuns)g=glbGun(k,gunMats(sk,w),sk);
 if(!g)g=BUILDERS[w.cat](k,gunMats(sk,w));
 if(sk&&sk.tex&&!g.userData.real)applyPlanarUV(g);
 return g;
}
/* ---------- écran Crédits (licence CC BY : citer les auteurs) ---------- */
(function creditsTab(){
 const tabs=$('mtabs');if(!tabs)return;
 const tb=document.createElement('div');tb.className='mtab';tb.dataset.t='credits';tb.textContent='Crédits';tabs.appendChild(tb);
 const p=document.createElement('div');p.className='tp';p.id='tab-credits';
 const rows=(typeof GLB_CREDITS!=='undefined'?GLB_CREDITS:[]).map(c=>'<tr><td>'+(W[c.key]?W[c.key].n:c.key)+'</td><td><a href="'+c.m.url+'" target="_blank" rel="noopener" style="color:#9fe3ff">'+c.m.title+'</a></td><td>'+c.m.author+'</td><td>'+c.m.license+'</td></tr>').join('');
 p.innerHTML='<div class="csec" style="max-width:900px"><h4>MODÈLES 3D DES ARMES</h4><div style="font-size:.74rem;color:#b8c5da;margin-bottom:10px;line-height:1.6">Modèles téléchargés sur Sketchfab sous licence <b>Creative Commons Attribution (CC BY 4.0)</b> ou CC0, adaptés pour le jeu (échelle, orientation, pièces animées). Merci aux auteurs !</div>'+
  '<table class="hist"><tr><th>ARME DANS LE JEU</th><th>MODÈLE</th><th>AUTEUR</th><th>LICENCE</th></tr>'+rows+'</table></div>'+
  '<div class="csec" style="max-width:900px"><h4>LE RESTE</h4><div style="font-size:.74rem;color:#b8c5da;line-height:1.6">Zombie animé : modèle « Zombie » de <b>Quaternius</b> (poly.pizza, domaine public / CC0). Moteur 3D : Three.js (licence MIT). Cartes, soldats, sons, effets, interface et armes prodiges : créés dans le code du jeu.</div></div>';
 $('tab-keys').parentNode.appendChild(p);
})();
