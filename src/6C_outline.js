/* =====================================================================
   CONTOURS DES PERSONNAGES (lisibilité / accessibilité)
   Coque inversée gonflée le long des normales : rouge = ennemi,
   bleu = allié. Option dans Options › Accessibilité.
   ===================================================================== */
cfg.outline=cfg.outline===undefined?1:cfg.outline;
const OLM={};
function outlineMat(col,skin){
 const k=col+(skin?'s':'');if(OLM[k])return OLM[k];
 const m=new THREE.MeshBasicMaterial({color:col,side:THREE.BackSide,skinning:!!skin,transparent:true,opacity:.9,depthWrite:true,toneMapped:false});
 m.onBeforeCompile=sh=>{sh.vertexShader=sh.vertexShader.replace('#include <begin_vertex>','#include <begin_vertex>\n transformed += normalize(normal) * 0.03;');};
 return OLM[k]=m;
}
function clearOutline(e){
 const R=e.rig;if(!R||!R.root.userData.ol)return;
 for(const o of R.root.userData.ol)if(o.parent)o.parent.remove(o);
 R.root.userData.ol=null;
}
function applyOutline(e){
 if(!e||!e.rig||e.isPlayer)return;
 clearOutline(e);
 if(!cfg.outline||e.dummy)return;
 const foe=MODE().team?e.team!==P.team:true;
 const col=foe?0xff3040:0x3aa0ff,list=[];
 const meshes=[];e.rig.root.traverse(o=>{if(o.isMesh&&!o.userData.isOl&&o.geometry&&o.geometry.attributes.normal)meshes.push(o);});
 for(const m of meshes){
  let ol;
  if(m.isSkinnedMesh){ol=new THREE.SkinnedMesh(m.geometry,outlineMat(col,true));ol.bind(m.skeleton,m.bindMatrix);ol.frustumCulled=false;}
  else ol=new THREE.Mesh(m.geometry,outlineMat(col,false));
  ol.userData.isOl=true;ol.renderOrder=-1;m.add(ol);list.push(ol);
 }
 e.rig.root.userData.ol=list;
}
function applyOutlinesAll(){if(!P)return;for(const e of ents)applyOutline(e);}
