/* =====================================================================
   INSPECTION D'ARME (touche V)
   Armes à chargeur : on montre un flanc, on retourne l'arme, puis la
   main gauche sort le chargeur, l'amène devant les yeux (on voit les
   cartouches dedans, autant que de balles restantes), le remet et le
   claque. Fusils à pompe / à verrou : double rotation + coup d'œil
   dans la chambre. Couteau : moulinet et présentation de la lame.
   Un reflet balaie l'arme pendant la présentation (le skin brille).
   ===================================================================== */
// clés : [instant, px, py, pz, rx, ry, rz]
const INSK={
 mag:[[0,0,0,0,0,0,0],[.08,-.03,.03,-.02,.2,1.05,.45],[.22,-.045,.035,-.03,.26,1.32,.52],[.31,.015,.02,-.02,.1,-.5,-.55],[.39,-.01,0,-.02,.15,.38,.32],
      [.78,-.01,-.02,0,.1,.3,.26],[.83,-.01,-.012,0,.02,.26,.2],[.9,-.01,0,0,.06,.2,.12],[1,0,0,0,0,0,0]],
 plain:[[0,0,0,0,0,0,0],[.12,-.03,.03,-.03,.22,1.1,.45],[.4,-.05,.04,-.04,.28,1.35,.55],[.55,.02,.02,-.02,.1,-.5,-.6],[.8,.01,.02,-.02,.15,-.62,-.5],[1,0,0,0,0,0,0]],
 knife:[[0,0,0,0,0,0,0],[.12,-.06,.06,-.04,.3,.2,.2],[.5,-.08,.07,-.05,.3,.3,.2+TAU*2],[.72,-.08,.06,-.06,.2,1.3,.3+TAU*2],[.88,-.06,.05,-.05,.25,-.4,TAU*2-.3],[1,0,0,0,0,0,TAU*2]]
};
const INSD={mag:4.4,plain:3,knife:2.2};
function inspectKind(e){const wi=e&&e.wp?curWi(e):null,w=wi?W[wi.k]:null;if(!w)return 'plain';if(w.melee)return 'knife';
 const u=VM.gun&&VM.gun.userData;return u&&u.mag?'mag':'plain';}
function inspectDur(e){VM.inspKind=inspectKind(e);return INSD[VM.inspKind];}
const _ik=[0,0,0,0,0,0];
function inspectPose(u,w){
 const K=INSK[VM.inspKind||'plain'],a=1-VM.inspectT/(VM.inspDur||3);
 let i=0;while(i<K.length-2&&a>K[i+1][0])i++;
 const A=K[i],B=K[i+1],t=smooth01(clamp((a-A[0])/(B[0]-A[0]),0,1));
 for(let j=0;j<6;j++)_ik[j]=A[j+1]+(B[j+1]-A[j+1])*t;
 const r={a,px:_ik[0],py:_ik[1],pz:_ik[2],rx:_ik[3],ry:_ik[4],rz:_ik[5],out:0,hold:0,lh:0};
 // petit tremblement de main vivant
 r.rx+=Math.sin(a*23)*.006;r.rz+=Math.sin(a*17+1)*.008;
 if(VM.inspKind==='mag'){
  const seg=(x0,x1)=>smooth01(clamp((a-x0)/(x1-x0),0,1));
  r.lh=seg(.36,.42)*(1-seg(.82,.9));                                 // main gauche : va au chargeur, revient au garde-main
  r.out=seg(.42,.48)*(1-seg(.76,.8));                                 // chargeur qui glisse hors du puits
  r.hold=seg(.47,.56)*(1-seg(.69,.77));                               // chargeur amené devant les yeux
  r.tilt=Math.sin(clamp((a-.56)/.13,0,1)*Math.PI)*.35;               // on le tourne un peu pour voir les cartouches
  if(a>.79&&a<.84)r.py+=-.012*Math.sin((a-.79)/.05*Math.PI);          // claque
  const snd=(k,at,n,v)=>{if(VM.inspSnd<k&&a>=at){VM.inspSnd=k;sfx(n,undefined,undefined,v||.7);}};
  snd(1,.37,'magout',.35);snd(2,.43,'magout',.7);snd(3,.79,'magin',.85);
 }else if(VM.inspKind==='knife'){if(VM.inspSnd<1&&a>.14){VM.inspSnd=1;sfx('knife',undefined,undefined,.3);}}
 inspectGlint(a,u);
 return r;
}
/* ---------- le chargeur dans la main ---------- */
const _im={m:new THREE.Matrix4(),m2:new THREE.Matrix4(),p:new THREE.Vector3(),q:new THREE.Quaternion(),s:new THREE.Vector3(),p2:new THREE.Vector3(),q2:new THREE.Quaternion(),s2:new THREE.Vector3()};
// matrice de l'objet dans le repère de VM.root (g = arme, enfant direct de VM.root)
function vmRel(o,g,out){out.identity();const chain=[];for(let x=o;x&&x!==VM.root;x=x.parent)chain.push(x);for(let i=chain.length-1;i>=0;i--){chain[i].updateMatrix();out.multiply(chain[i].matrix);}return out;}
function inspectPrep(u,g){
 if(u.insPrep)return;u.insPrep=true;
 const mag=u.mag;
 // orientation du chargeur dans le repère de l'arme (arme non tournée), boîte englobante dans son propre repère
 const gq=g.quaternion.clone(),gp=g.position.clone(),gs=g.scale.clone();g.position.set(0,0,0);g.quaternion.identity();g.scale.set(1,1,1);
 const M=vmRel(mag,g,new THREE.Matrix4()),inv=M.clone().invert();M.decompose(_im.p,_im.q,_im.s);
 u.insQmg=_im.q.clone();u.insSmg=_im.s.clone();
 const box=new THREE.Box3();mag.updateMatrixWorld(true);const mi=new THREE.Matrix4().copy(mag.matrixWorld).invert();
 mag.traverse(o=>{if(o.isMesh&&o.geometry){o.geometry.computeBoundingBox();box.union(o.geometry.boundingBox.clone().applyMatrix4(new THREE.Matrix4().multiplyMatrices(mi,o.matrixWorld)));}});
 g.position.copy(gp);g.quaternion.copy(gq);g.scale.copy(gs);
 if(box.isEmpty())box.set(new THREE.Vector3(-.01,-.05,-.02),new THREE.Vector3(.01,.05,.02));
 u.insC=box.getCenter(new THREE.Vector3());
 // haut du chargeur (côté arme) et sens du tir, exprimés dans le repère du chargeur
 const iq=u.insQmg.clone().invert(),up=new THREE.Vector3(0,1,0).applyQuaternion(iq),fw=new THREE.Vector3(0,0,-1).applyQuaternion(iq);
 const hs=box.getSize(new THREE.Vector3()).multiplyScalar(.5),ext=Math.abs(up.x)*hs.x+Math.abs(up.y)*hs.y+Math.abs(up.z)*hs.z;
 const top=u.insC.clone().addScaledVector(up,ext*.96),side=new THREE.Vector3().crossVectors(up,fw).normalize();
 // cartouches : deux rangées en quinconce, laiton + ogive cuivre (taille réelle quelle que soit l'échelle du modèle)
 const sc=1/Math.max(1e-4,(_im.s.x+_im.s.y+_im.s.z)/3),pistol=W[VM.gk]&&W[VM.gk].cat==='pistol';
 const R=(pistol?.0036:.0037)*sc,L=(pistol?.013:.021)*sc,TL=(pistol?.006:.009)*sc;
 const caseG=new THREE.CylinderGeometry(R,R*1.04,L,12),tipG=new THREE.ConeGeometry(R*.98,TL,12);tipG.translate(0,TL/2,0);
 const brass=new THREE.MeshStandardMaterial({color:C('#c9a24a'),metalness:1,roughness:.25}),cu=new THREE.MeshStandardMaterial({color:C('#b8643a'),metalness:1,roughness:.3});
 const grp=new THREE.Group(),qd=new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0,1,0),fw);
 u.insRounds=[];
 for(let i=0;i<5;i++){const c=new THREE.Group(),m1=new THREE.Mesh(caseG,brass),m2=new THREE.Mesh(tipG,cu);m2.position.y=L/2;c.add(m1,m2);
  c.quaternion.copy(qd);c.position.copy(top).addScaledVector(up,-R*.7-i*R*1.6).addScaledVector(side,(i&1?1:-1)*R*.95).addScaledVector(fw,L*.1);grp.add(c);u.insRounds.push(c);}
 grp.visible=false;mag.add(grp);u.rounds=grp;
}
const _iA=new THREE.Vector3(),_iB=new THREE.Vector3(),_iBasis1=new THREE.Matrix4(),_iBasis2=new THREE.Matrix4();
function inspectMag(u,g,ins,p){
 if(!u.mag)return;inspectPrep(u,g);
 const mag=u.mag,show=ins.out>0||ins.hold>0;
 if(u.rounds){u.rounds.visible=show;const n=p&&p.wp?curWi(p).mag:5;u.insRounds.forEach((r,i)=>r.visible=i<n);}
 if(!show){u.insMagC=null;return;}
 // pose « sortie » : glissée dans le prolongement du puits
 const d=u.magDir;mag.position.set(u.magP0.x+d.x*ins.out*.24,u.magP0.y+d.y*ins.out*.24,u.magP0.z+d.z*ins.out*.24);mag.rotation.copy(u.magR0);mag.visible=true;
 const Mout=vmRel(mag,g,_im.m);
 // pose « devant les yeux » : haut du chargeur vers la caméra, cartouches pointées vers le haut
 _iA.set(0,.45,1).normalize();_iB.set(.25,1,-.35).normalize();
 const up=new THREE.Vector3(0,1,0),fw=new THREE.Vector3(0,0,-1);
 const tA=ins.tilt||0;_iA.applyAxisAngle(up,tA);_iB.applyAxisAngle(up,tA);
 const c1=new THREE.Vector3().crossVectors(up,fw),c2=new THREE.Vector3().crossVectors(_iA,_iB).normalize();_iB.crossVectors(c2,_iA).normalize();
 _iBasis1.makeBasis(up,fw,c1);_iBasis2.makeBasis(_iA,_iB,c2);
 const Rq=new THREE.Quaternion().setFromRotationMatrix(_iBasis2.multiply(_iBasis1.transpose()));
 const tq=Rq.multiply(u.insQmg.clone()),ts=u.insSmg;
 const tp=new THREE.Vector3(-.04,-.06,-.28).sub(u.insC.clone().multiply(ts).applyQuaternion(tq));
 Mout.decompose(_im.p,_im.q,_im.s);
 const h=ins.hold;_im.p.lerp(tp,h);_im.q.slerp(tq,h);
 // retour dans le repère du parent du chargeur
 const Mp=vmRel(mag.parent,g,_im.m2).invert();_im.m.compose(_im.p,_im.q,_im.s);_im.m.premultiply(Mp);
 _im.m.decompose(mag.position,mag.quaternion,_im.s2);
 // centre du chargeur (repère VM.root) : la main gauche le tient par le bas
 u.insMagC=u.insC.clone().addScaledVector(new THREE.Vector3(0,-1,0).applyQuaternion(u.insQmg.clone().invert()),.02/Math.max(1e-4,ts.y)).multiply(ts).applyQuaternion(_im.q).add(_im.p);
}
/* ---------- reflet qui balaie l'arme ---------- */
const INS_LIGHT=new THREE.PointLight(0xfff1d6,0,.9,2);VM.root.add(INS_LIGHT);
function inspectGlint(a,u){
 const k=Math.sin(clamp((a-.04)/.3,0,1)*Math.PI);
 INS_LIGHT.intensity=k*2.4;INS_LIGHT.position.set(lerp(-.25,.45,clamp((a-.04)/.3,0,1)),.05,-.25);
 if(VM.inspectT<=.05)INS_LIGHT.intensity=0;
}
{const _vu=vmUpdate;vmUpdate=function(dt,t,ent){if(VM.inspectT<=0)INS_LIGHT.intensity=0;return _vu(dt,t,ent);};}
