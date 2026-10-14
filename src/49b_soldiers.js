/* =====================================================================
   SOLDATS RÉALISTES (joueurs et bots, équipes T / CT / chacun-pour-soi)
   Personnage photo-réaliste CC0 (Mesh2Motion, retexturé par
   tools/soldiers/build_soldiers.py) posé sur le soldat procédural :
   le squelette du modèle recopie à chaque image la pose du soldat
   (jambes, bassin, buste, tête, morts, danses, places assises…) et les
   bras sont recalculés (IK) pour tenir l'arme. Toute l'animation reste
   celle de 45_models.js ; seul l'habillage change.
   Les tenues de la boutique (OUTFITS) gardent le modèle d'origine.
   ===================================================================== */
cfg.realChars=cfg.realChars===undefined?1:cfg.realChars;
// os du modèle <- groupe du soldat procédural (même pose de repos : debout, jambes droites)
const SOLD_MAP=[['pelvis',R=>R.hips],['spine_01',R=>R.spine],['neck_01',R=>R.neckG],['head',R=>R.head],
 ['thigh_l',R=>R.legL.th],['calf_l',R=>R.legL.sh],['foot_l',R=>R.legL.foot],
 ['thigh_r',R=>R.legR.th],['calf_r',R=>R.legR.sh],['foot_r',R=>R.legR.foot]];
function soldierKey(look){
 if(!look||(look.outfit&&typeof OUTFITS!=='undefined'&&OUTFITS[look.outfit]))return null;
 const k=look.kind==='ct'?'s_ct':look.kind==='t'?'s_t':'s_ffa';
 return charFactory(k)?k:null;
}
const _rbq=new THREE.Quaternion(),_rbq2=new THREE.Quaternion(),_rbq3=new THREE.Quaternion(),_rbv=V3(),_rbv2=V3(),_rbS=V3(),_rbH=V3(),_rbE=V3(),_rbP=V3();
const RB_MAT={};
function attachRealBody(R,key,look){
 const F=charFactory(key);if(!F)return;
 // le soldat procédural reste (pose, arme, contours) mais n'est plus dessiné
 // on garde l'équipement (casque, gilet, poches, sac) porté par le buste et la tête : il suit les mêmes os
 const keep=new Set(),M=lookMats(look),gear=new Set([M.vest,M.dark,M.helm,M.lens,M.blk]),noGear=new Set([R.eyeL,R.eyeR]);
 R.gunMount.traverse(o=>keep.add(o));
 for(const k in R.arm){const A=R.arm[k];for(const o of [A.ua,A.fa,A.elbow,A.hand,A.pad,A.band])o.traverse(x=>noGear.add(x));}
 for(const g of [R.spine,R.head,R.hips])for(const o of g.children)if(o.isMesh&&gear.has(o.material)&&!noGear.has(o)&&!(g===R.head&&o.material===M.blk))keep.add(o);
 R.root.traverse(o=>{if((o.isMesh||o.isSprite)&&!keep.has(o))o.visible=false;});
 for(const o of R.spine.children)if(keep.has(o)&&o.material===M.vest){o.scale.x*=.86;o.scale.z*=.85;}   // gilet ajusté au gabarit du modèle
 // couvre-chef : toile sable (T) ou casque gris mat (chacun-pour-soi) au lieu du motif / de la couleur vive
 const hm=look.kind==='t'?(RB_MAT.t||(RB_MAT.t=new THREE.MeshStandardMaterial({color:C(0x8c7a58),roughness:.95}))):
  look.kind==='ct'?null:(RB_MAT.f||(RB_MAT.f=new THREE.MeshStandardMaterial({color:C(0x34383e),roughness:.6,metalness:.1})));
 if(hm)R.head.traverse(o=>{if(o.isMesh&&keep.has(o)&&o.material===M.helm)o.material=hm;});
 const inner=F.instance();inner.rotation.y=Math.PI;   // le modèle regarde vers +Z, le soldat vers -Z
 if(!F.matFixed){F.matFixed=1;inner.traverse(o=>{if(o.isMesh){o.material.roughness=.88;o.material.metalness=0;}});}
 R.root.add(inner);
 if(look.kind!=='ct'&&look.kind!=='t'){   // chacun-pour-soi : tenue grise teintée de la couleur du joueur
  const tint=new THREE.Color(1,1,1).lerp(C(look.acc),.5);
  inner.traverse(o=>{if(o.isMesh){o.material=o.material.clone();o.material.color.copy(tint);}});
 }
 const q0=R.root.quaternion.clone(),p0=R.root.position.clone(),s0=R.root.scale.clone();
 R.root.position.set(0,0,0);R.root.quaternion.identity();R.root.scale.set(1,1,1);
 R.root.updateMatrixWorld(true);
 const bone=n=>inner.getObjectByName(n),X={inner,map:[],arm:{}};
 for(const [n,g] of SOLD_MAP){const b=bone(n);if(!b)continue;X.map.push({b,g:g(R),B0:b.getWorldQuaternion(new THREE.Quaternion())});}
 const pel=bone('pelvis');X.pelOff=pel?pel.getWorldPosition(V3()).sub(R.hips.getWorldPosition(V3())):V3();
 for(const [s,key2] of [['l','L'],['r','R']]){
  const ua=bone('upperarm_'+s),fa=bone('lowerarm_'+s),hd=bone('hand_'+s);if(!ua||!fa||!hd)continue;
  const pu=ua.getWorldPosition(V3()),pf=fa.getWorldPosition(V3()),ph=hd.getWorldPosition(V3());
  X.arm[key2]={ua,fa,hd,la:pu.distanceTo(pf),lb:pf.distanceTo(ph),
   dU:pf.clone().sub(pu).normalize(),dF:ph.clone().sub(pf).normalize(),
   QU:ua.getWorldQuaternion(new THREE.Quaternion()),QF:fa.getWorldQuaternion(new THREE.Quaternion()),QH:hd.getWorldQuaternion(new THREE.Quaternion())};
 }
 R.root.position.copy(p0);R.root.quaternion.copy(q0);R.root.scale.copy(s0);
 R.rb=X;R.realBody=key;
}
// oriente l'os b pour que sa rotation monde vaille q (le parent est déjà à jour)
function setBoneWorldQ(b,q){
 b.parent.getWorldQuaternion(_rbq3).invert();b.quaternion.copy(_rbq3).multiply(q);b.updateMatrixWorld(true);
}
function syncRealBody(R){
 const X=R.rb;if(!X)return;
 R.root.updateMatrixWorld(true);
 const rq=R.root.getWorldQuaternion(_rbq2);
 for(const m of X.map){
  // pose de repos du groupe = identité dans le repère du soldat : os(monde) = groupe(monde) · os au repos
  m.g.getWorldQuaternion(_rbq).multiply(m.B0);
  setBoneWorldQ(m.b,_rbq);
  if(m.b.name==='pelvis'){
   // le bassin suit aussi la hauteur du soldat (accroupi, chute, places assises)
   _rbv.copy(X.pelOff).multiply(R.root.scale).applyQuaternion(rq).add(R.hips.getWorldPosition(_rbv2));
   m.b.parent.worldToLocal(_rbv);m.b.position.copy(_rbv);m.b.updateMatrixWorld(true);
  }
 }
 // bras : IK sur les vraies longueurs du modèle, mains sur les poignées de l'arme
 for(const k of ['L','R']){
  const A=X.arm[k],P2=R.arm[k];if(!A||!P2)continue;
  A.ua.getWorldPosition(_rbS);P2.hand.getWorldPosition(_rbH);
  const sc=R.root.scale.x;
  R.spine.getWorldQuaternion(_rbq);_rbP.copy(P2.pole).applyQuaternion(_rbq);
  ik2(_rbS,_rbH,A.la*sc,A.lb*sc,_rbP,_rbE);
  const H=_h2;   // main atteinte (bras tendu au maximum si la cible est trop loin)
  _rbv.copy(A.dU).applyQuaternion(rq);_rbv2.subVectors(_rbE,_rbS).normalize();
  _rbq.setFromUnitVectors(_rbv,_rbv2).multiply(_rbq3.copy(rq).multiply(A.QU));setBoneWorldQ(A.ua,_rbq);
  _rbv.copy(A.dF).applyQuaternion(rq);_rbv2.subVectors(H,_rbE).normalize();
  _rbq.setFromUnitVectors(_rbv,_rbv2).multiply(_rbq3.copy(rq).multiply(A.QF));setBoneWorldQ(A.fa,_rbq);
  _rbq.setFromUnitVectors(_rbv,_rbv2).multiply(_rbq3.copy(rq).multiply(A.QH));setBoneWorldQ(A.hd,_rbq);
 }
}
{
 const mk0=makeSoldier;
 makeSoldier=function(look){
  const R=mk0(look);
  if(cfg.realChars!==0){const k=soldierKey(look);if(k){try{attachRealBody(R,k,look);}catch(e){console.warn('soldat réaliste',e);}}}
  return R;
 };
 const an0=animateSoldier;
 animateSoldier=function(R,st,dt,t){an0(R,st,dt,t);if(R.rb)syncRealBody(R);};
}
