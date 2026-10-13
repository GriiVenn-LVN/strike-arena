/* =====================================================================
   MODÈLES 3D D'ARMES (glTF binaire intégré, préparés dans Blender)
   Lecteur GLB minimal (positions + matériaux de couleur), puis
   remplacement des armes procédurales. Les skins s'appliquent aux
   matériaux classés par couleur (corps / accessoires / bois / acier).
   Les armes sans modèle (couteau, armes prodiges) restent procédurales.
   ===================================================================== */
const GLBT={};
function b64buf(s){const bin=atob(s),u=new Uint8Array(bin.length);for(let i=0;i<bin.length;i++)u[i]=bin.charCodeAt(i);return u.buffer;}
function parseGLB(buf){
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
   geo=geo.index?geo.toNonIndexed():geo;geo.computeVertexNormals();     // facettes nettes (style low-poly)
   const mt=p.material!==undefined?json.materials[p.material]:null,pb=mt&&mt.pbrMetallicRoughness||{};
   const m=new THREE.Mesh(geo);m.userData.col=pb.baseColorFactor||[.5,.5,.5,1];m.userData.metal=pb.metallicFactor!==undefined?pb.metallicFactor:0;m.userData.rough=pb.roughnessFactor!==undefined?pb.roughnessFactor:.6;
   g.add(m);
  }
  for(const c of n.children||[])mk(c,g);
  parent.add(g);
 };
 for(const ni of json.scenes[json.scene||0].nodes)mk(ni,root);
 return root;
}
function glbTemplate(k){
 if(GLBT[k])return GLBT[k];
 try{GLBT[k]=parseGLB(b64buf(GLB_DATA[k]));}catch(e){console.warn('GLB',k,e);GLBT[k]=null;}
 return GLBT[k];
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
function glbGun(k,M,sk){
 const tpl=glbTemplate(k);if(!tpl)return null;
 const info=GLB_INFO[k]||{},w=W[k],g=new THREE.Group();
 const keepMat={};
 const copy=(src,dst)=>{for(const c of src.children){
  if(c.isMesh){const role=glbRole(c.userData.col);let mt=M[role];
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
 const sightY=Math.max(info.sight||.06,tpl.userData.top+.004);
 return finishGun(g,{len:info.len||w.len,muzzle:info.muzzle||-.4,glb:true,
  right:V3(0,-.03,.012),left:pistol?V3(-.012,-.04,.02):V3(L[0],L[1]-.012,L[2]),
  sight:sightY,eject:V3(.025,sightY*.6,(info.muzzle||-.4)*.18),
  mag:mag,slide:pistol?bolt:null,bolt:pistol?null:bolt,twoHand:true});
}
/* remplace la fabrique d'armes : modèle 3D si disponible, sinon procédural */
function gunParts(k,sk){
 const w=W[k];let g=null;
 if(typeof GLB_DATA!=='undefined'&&GLB_DATA[k]&&!cfg.procGuns)g=glbGun(k,gunMats(sk,w),sk);
 if(!g)g=BUILDERS[w.cat](k,gunMats(sk,w));
 if(sk&&sk.tex)applyPlanarUV(g);
 return g;
}
/* ---------- écran Crédits (licence CC BY : citer les auteurs) ---------- */
(function creditsTab(){
 const tabs=$('mtabs');if(!tabs)return;
 const tb=document.createElement('div');tb.className='mtab';tb.dataset.t='credits';tb.textContent='Crédits';tabs.appendChild(tb);
 const p=document.createElement('div');p.className='tp';p.id='tab-credits';
 const rows=(typeof GLB_CREDITS!=='undefined'?GLB_CREDITS:[]).map(c=>'<tr><td>'+(W[c.key]?W[c.key].n:c.key)+'</td><td><a href="'+c.m.url+'" target="_blank" rel="noopener" style="color:#9fe3ff">'+c.m.title+'</a></td><td>'+c.m.author+'</td><td>'+c.m.license+'</td></tr>').join('');
 p.innerHTML='<div class="csec" style="max-width:900px"><h4>MODÈLES 3D DES ARMES</h4><div style="font-size:.74rem;color:#b8c5da;margin-bottom:10px;line-height:1.6">Modèles téléchargés sur Sketchfab sous licence <b>Creative Commons Attribution (CC BY 4.0)</b>, adaptés pour le jeu (échelle, orientation, pièces animées). Merci aux auteurs !</div>'+
  '<table class="hist"><tr><th>ARME DANS LE JEU</th><th>MODÈLE</th><th>AUTEUR</th><th>LICENCE</th></tr>'+rows+'</table></div>'+
  '<div class="csec" style="max-width:900px"><h4>LE RESTE</h4><div style="font-size:.74rem;color:#b8c5da;line-height:1.6">Zombie animé : modèle « Zombie » de <b>Quaternius</b> (poly.pizza, domaine public / CC0). Moteur 3D : Three.js (licence MIT). Cartes, soldats, sons, effets, interface et armes prodiges : créés dans le code du jeu.</div></div>';
 $('tab-keys').parentNode.appendChild(p);
})();
