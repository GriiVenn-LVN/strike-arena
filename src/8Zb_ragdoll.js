/* =====================================================================
   RAGDOLLS PHYSIQUES
   À la mort, le soldat devient un pantin articulé simulé (Verlet) :
   15 points (bassin, buste, tête, hanches, genoux, pieds, épaules,
   coudes, mains) reliés par des contraintes de longueur, un tronc rigide,
   des articulations limitées, la gravité, le sol et les murs de la carte.
   Le corps part dans le sens du tir (plus fort au fusil à pompe et au
   sniper, sur la tête pour un tir à la tête), les genoux lâchent, et le
   pantin s'affaisse puis se pose. Le squelette du soldat (et le modèle
   réaliste par-dessus) suit ensuite les points.
   Les rediffusions rejouent la même chute. Réglage : Options › Ragdolls.
   ===================================================================== */
cfg.ragdoll=cfg.ragdoll===undefined?1:cfg.ragdoll;
const RD_G=-15,RD_R=.09,RD_STEP=1/120;
// liaisons : [a,b,raideur]  (1 = os rigide)
const RD_LINKS=[
 [0,1,1],[0,3,1],[0,6,1],[3,6,1],[1,9,1],[1,12,1],[9,12,1],[0,9,1],[0,12,1],[3,9,.6],[6,12,.6],[3,12,.6],[6,9,.6],  // tronc
 [1,2,1],[9,2,.5],[12,2,.5],                                                                                      // cou
 [3,4,1],[4,5,1],[6,7,1],[7,8,1],                                                                                 // jambes
 [9,10,1],[10,11,1],[12,13,1],[13,14,1]                                                                           // bras
];
// distances minimales (articulations qui ne se replient pas entièrement) : [a,b,fraction de la longueur d'origine]
const RD_MIN=[[3,5,.55],[6,8,.55],[9,11,.35],[12,14,.35],[0,2,.8],[2,4,.9],[2,7,.9],[5,8,.15],[11,14,.1],[4,7,.12]];
const _rdA=V3(),_rdB=V3(),_rdC=V3(),_rdQ=new THREE.Quaternion(),_rdQ2=new THREE.Quaternion(),_rdM=new THREE.Matrix4(),_rdM2=new THREE.Matrix4();
const rdOk=R=>cfg.ragdoll!==0&&R&&R.hips&&R.spine&&R.head&&R.legL&&R.legR&&R.arm&&R.arm.L&&R.arm.R&&!R.zm;

// élan donné au corps par l'arme qui tue (direction : du tueur vers la victime)
const _killEntRd=killEnt;
killEnt=function(v,att,w,hs){
 const was=v&&v.alive;
 _killEntRd(v,att,w,hs);
 if(!was||!v||v.alive)return;
 let dx=0,dz=0;
 if(att&&att!==v){dx=v.x-att.x;dz=v.z-att.z;const l=Math.hypot(dx,dz)||1;dx/=l;dz/=l;}
 else{dx=Math.sin(v.yaw);dz=Math.cos(v.yaw);}   // sans tireur (chute, bombe…) : en arrière
 const c=w&&w.cat,f=c==='shotgun'?3.2:c==='sniper'?2.9:w&&w.melee?1.1:c==='pistol'?1.3:1.7;
 v.rdImp={x:dx,z:dz,f,hs:!!hs};
};

function rdWorld(o,out){return o.getWorldPosition(out||V3());}
function rdBasis(up,right,out){
 _rdA.copy(up).normalize();_rdB.copy(right).addScaledVector(_rdA,-right.dot(_rdA)).normalize();_rdC.crossVectors(_rdB,_rdA);
 return out.makeBasis(_rdB,_rdA,_rdC);
}
function rdSetWorldQ(o,q){o.parent.getWorldQuaternion(_rdQ2).invert();o.quaternion.copy(_rdQ2).multiply(q);o.updateMatrixWorld(true);}

function rdInit(R,e){
 R.root.rotation.x=0;R.root.rotation.z=0;R.root.updateMatrixWorld(true);
 const A=R.arm,X=R.rb,p=[];
 const elb=k=>X&&X.arm[k]?rdWorld(X.arm[k].fa):rdWorld(A[k].elbow);
 const hnd=k=>X&&X.arm[k]?rdWorld(X.arm[k].hd):rdWorld(A[k].hand);
 p[0]=rdWorld(R.hips);p[1]=rdWorld(R.neckG);p[2]=R.head.localToWorld(V3(0,.06,0));
 p[3]=rdWorld(R.legL.th);p[4]=rdWorld(R.legL.sh);p[5]=rdWorld(R.legL.foot);
 p[6]=rdWorld(R.legR.th);p[7]=rdWorld(R.legR.sh);p[8]=rdWorld(R.legR.foot);
 p[9]=R.spine.localToWorld(A.L.S.clone());p[10]=elb('L');p[11]=hnd('L');
 p[12]=R.spine.localToWorld(A.R.S.clone());p[13]=elb('R');p[14]=hnd('R');
 const len=RD_LINKS.map(([a,b])=>p[a].distanceTo(p[b])),mn=RD_MIN.map(([a,b,f])=>p[a].distanceTo(p[b])*f);
 // vitesse de départ : celle du soldat + l'élan du tir (plus fort sur la zone touchée), les genoux lâchent vers l'avant
 const imp=e&&e.rdImp||{x:0,z:0,f:1,hs:false},vx=(e&&e.vx)||0,vz=(e&&e.vz)||0,fw=V3(-Math.sin(R.root.rotation.y),0,-Math.cos(R.root.rotation.y));
 const W=imp.hs?[.6,.9,1.3,.4,.2,.1,.4,.2,.1,.8,.6,.5,.8,.6,.5]:[.9,1,.8,.5,.3,.15,.5,.3,.15,.8,.6,.5,.8,.6,.5];
 const pp=p.map((q,i)=>{const k=W[i]*imp.f*(.85+Math.random()*.3),v=V3(vx+imp.x*k,(i===0||i===1)?.6:.2,vz+imp.z*k);
  if(i===4||i===7)v.addScaledVector(fw,.9);
  return q.clone().addScaledVector(v,-RD_STEP);});
 // pose de référence de chaque groupe (pour le reporter ensuite)
 const B=rdBasis(_rdA.subVectors(p[1],p[0]).clone(),V3().subVectors(p[6],p[3]),new THREE.Matrix4());
 const BS=rdBasis(_rdA.subVectors(p[1],p[0]).clone(),V3().subVectors(p[12],p[9]),new THREE.Matrix4());
 const BH=rdBasis(_rdA.subVectors(p[2],p[1]).clone(),V3().subVectors(p[12],p[9]),new THREE.Matrix4());
 const wq=o=>o.getWorldQuaternion(new THREE.Quaternion());
 R.rd={p,pp,len,mn,acc:0,t:0,rest:0,
  hips:{q:wq(R.hips),b:B},spine:{q:wq(R.spine),b:BS},head:{q:wq(R.head),b:BH},
  limbs:[[R.legL.th,3,4],[R.legL.sh,4,5],[R.legR.th,6,7],[R.legR.sh,7,8]].map(([o,a,b])=>({o,a,b,q:wq(o),d:V3().subVectors(p[b],p[a]).normalize()}))};
}

function rdStep(rd){
 const p=rd.p,pp=rd.pp,h=RD_STEP;
 for(let i=0;i<p.length;i++){
  const q=p[i],o=pp[i];
  let vx=(q.x-o.x)*.996,vy=(q.y-o.y)*.996,vz=(q.z-o.z)*.996;
  const gy=groundH(q.x,q.z);
  if(q.y-RD_R<=gy+.005){vx*=.7;vz*=.7;}   // frottement au sol
  o.copy(q);q.x+=vx;q.y+=vy+RD_G*h*h;q.z+=vz;
 }
 for(let it=0;it<6;it++){
  for(let k=0;k<RD_LINKS.length;k++){
   const [a,b,s]=RD_LINKS[k],A=p[a],Bp=p[b];_rdA.subVectors(Bp,A);const d=_rdA.length()||1e-4,c=(d-rd.len[k])/d*.5*s;
   A.addScaledVector(_rdA,c);Bp.addScaledVector(_rdA,-c);
  }
  for(let k=0;k<RD_MIN.length;k++){
   const [a,b]=RD_MIN[k],A=p[a],Bp=p[b];_rdA.subVectors(Bp,A);const d=_rdA.length()||1e-4;if(d>=rd.mn[k])continue;
   const c=(d-rd.mn[k])/d*.5;A.addScaledVector(_rdA,c);Bp.addScaledVector(_rdA,-c);
  }
  // sol, caisses et murs : le point reste hors du décor
  for(let i=0;i<p.length;i++){
   const q=p[i],o=pp[i],gy=groundH(q.x,q.z);
   if(gy>q.y+.35||ceilAt(q.x,q.z)<q.y){q.x=o.x;q.z=o.z;}   // dans un mur : retour en arrière à l'horizontale
   const g2=groundH(q.x,q.z);if(q.y<g2+RD_R)q.y=g2+RD_R;
  }
 }
}

function rdApply(R){
 const rd=R.rd,p=rd.p,M=_rdM;
 R.root.rotation.x=0;R.root.rotation.z=0;R.root.updateMatrixWorld(true);
 // bassin : position et orientation
 const lp=R.root.worldToLocal(_rdC.copy(p[0]));R.hips.position.copy(lp);R.hips.updateMatrixWorld(true);
 const set=(o,ref,up,right)=>{
  rdBasis(up,right,M);_rdM2.copy(ref.b).invert();M.multiply(_rdM2);_rdQ.setFromRotationMatrix(M).multiply(ref.q);rdSetWorldQ(o,_rdQ);
 };
 set(R.hips,rd.hips,V3().subVectors(p[1],p[0]),V3().subVectors(p[6],p[3]));
 set(R.spine,rd.spine,V3().subVectors(p[1],p[0]),V3().subVectors(p[12],p[9]));
 set(R.head,rd.head,V3().subVectors(p[2],p[1]),V3().subVectors(p[12],p[9]));
 for(const L of rd.limbs){
  _rdA.subVectors(p[L.b],p[L.a]).normalize();_rdQ.setFromUnitVectors(L.d,_rdA).multiply(L.q);rdSetWorldQ(L.o,_rdQ);
 }
 // bras : épaule -> coude -> main, dans le repère du buste
 for(const [k,ie,ih] of [['L',10,11],['R',13,14]]){
  const A=R.arm[k],E=R.spine.worldToLocal(_rdA.copy(p[ie])).clone(),H=R.spine.worldToLocal(_rdB.copy(p[ih])).clone();
  placeLimb(A.ua,A.S,E);placeLimb(A.fa,E,H);A.elbow.position.copy(E);A.hand.position.copy(H);
  A.band.position.copy(A.S).lerp(E,.55);A.band.quaternion.copy(A.ua.quaternion);A.pad.position.copy(E);A.pad.quaternion.copy(A.ua.quaternion);
  A.pole.copy(E).sub(_rdC.copy(A.S).lerp(H,.5));if(A.pole.lengthSq()<1e-6)A.pole.set(0,-1,0);
 }
 R.gunMount.visible=false;   // l'arme tombe des mains
}

// os que le ragdoll déplace : leur pose de repos est remise quand le soldat se relève
function rdBones(R){const b=[R.hips,R.spine,R.head,R.neckG,R.legL.th,R.legL.sh,R.legL.foot,R.legR.th,R.legR.sh,R.legR.foot];
 for(const k of ['L','R']){const A=R.arm[k];b.push(A.ua,A.fa,A.elbow,A.hand,A.band,A.pad);}
 return b.filter(Boolean);}
const _anRd=animateSoldier;
animateSoldier=function(R,st,dt,t){
 if(st.alive||st.dance||!rdOk(R)){
  if(!R.rdRest&&rdOk(R))R.rdRest=rdBones(R).map(o=>[o,o.position.clone(),o.quaternion.clone()]);
  // relevé (nouvelle manche, réapparition) : les os gardaient l'orientation du ragdoll et le soldat marchait couché
  if(R.rd){R.rd=null;if(R.rdRest)for(const [o,ps,q] of R.rdRest){o.position.copy(ps);o.quaternion.copy(q);}R.gunMount.visible=true;}
  _anRd(R,st,dt,t);return;}
 if(!R.rd||R.dieT<0)rdInit(R,R.ent);
 _anRd(R,st,dt,t);   // pose de mort d'origine (sert de base), remplacée ci-dessous
 const rd=R.rd;
 if(rd.rest<1.2){
  rd.acc+=Math.min(dt,.1);
  while(rd.acc>=RD_STEP){rd.acc-=RD_STEP;rdStep(rd);rd.t+=RD_STEP;}
  // corps posé : on arrête de simuler
  let e2=0;for(let i=0;i<rd.p.length;i++)e2+=rd.p[i].distanceToSquared(rd.pp[i]);
  rd.rest=e2<1e-6&&rd.t>.6?rd.rest+dt:0;
 }
 rdApply(R);
 if(R.rb)syncRealBody(R);
};

// réglage
const _buildOptsRd=buildOpts;
buildOpts=function(){
 _buildOptsRd();
 let g=$('gRagdoll');
 if(!g){
  const anchor=$('gKillcam')||($('cCine')&&$('cCine').closest('.grp'));if(!anchor)return;
  g=document.createElement('div');g.className='grp';g.id='gRagdoll';g.innerHTML='<label>Ragdolls</label><div class="chips" id="cRagdoll"></div><small>Chute physique des corps (membres articulés, selon l\'impact).</small>';
  anchor.parentNode.insertBefore(g,anchor.nextSibling);
 }
 chipsRow('cRagdoll',[['Activés',1],['Désactivés',0]],()=>cfg.ragdoll!==0?1:0,v=>cfg.ragdoll=v,buildOpts);
};
