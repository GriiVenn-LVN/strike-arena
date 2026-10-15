/* =====================================================================
   VIEWMODEL : arme + mains en vue subjective, animations
   ===================================================================== */
vmScene.add(vmCam);
const VM={root:new THREE.Group(),gun:null,gk:null,skin:-1,look:'',kick:0,drawT:0,reloadMax:0,inspectT:0,throwT:0,swingT:0,flashT:0,boltT:0,pumpT:0,ent:null,drops:[],relEmpty:false,relSnd:0,relDrop:false,relShells:3,
 sx:0,sy:0,sxv:0,syv:0,kv:0,lv:0,land:0,ly:0,lp:0,landT:0,bph:0,prevGround:true,swayR:0,airVy:0,strafe:0};
vmCam.add(VM.root);
{
 const look={kind:'ct',acc:'#3498db',tone:SKIN_TONES[0]};
 VM.setLook=(lk)=>{
  const key=lk.kind+lk.acc+lk.tone+(lk.outfit||0);if(VM.look===key)return;VM.look=key;initSoldierGeos();
  const M=lookMats(lk);
  if(VM.parts)for(const o of VM.parts)VM.root.remove(o);
  VM.fR=new THREE.Mesh(SG.farm,M.shirt);VM.fL=new THREE.Mesh(SG.farm,M.shirt);
  VM.uR=new THREE.Mesh(SG.uarm,M.shirt);VM.uL=new THREE.Mesh(SG.uarm,M.shirt);
  VM.cR=rb(.06,.06,.06,M.vest,0,0,0,.015);VM.cL=rb(.06,.06,.06,M.vest,0,0,0,.015);
  VM.hR=makeHandMesh(M.glove,true);VM.hL=makeHandMesh(M.glove,true);VM.hL.scale.x=-1;
  VM.parts=[VM.fR,VM.fL,VM.uR,VM.uL,VM.cR,VM.cL,VM.hR,VM.hL];
  for(const o of VM.parts){o.traverse(c=>{if(c.isMesh){c.castShadow=false;}});VM.root.add(o);}
 };
 VM.setLook(look);
}
// skin affiché : celui du joueur pour sa propre arme (rediffusions comprises), finition d'usine pour un joueur regardé en spectateur
const vmMine=e=>!e||e===P||(!!P&&e._src===P);
const vmSkinId=(e,k)=>vmMine(e)?cfg.skins[k]||0:0;
function vmSetGun(k){
 if(VM.gun)VM.root.remove(VM.gun);
 const e=VM.ent||P,sk=vmMine(e)?skinOf(k):SKINS[0],g=gunParts(k,sk);VM.gun=g;VM.gk=k;VM.skin=vmSkinId(e,k);VM.pap=!!(e&&e.wp&&curWi(e)&&curWi(e).pap);if(VM.pap)papCamo(g);decorateVM(g,k);
 const u=g.userData;
 // bornes de l'arme (repère local) : sert à garder la crosse devant la caméra en visée
 // la crosse (pièces entièrement derrière la poignée) est masquée en visée : vue de 15 cm, elle boucherait l'écran
 g.updateMatrixWorld(true);u.stock=[];u.backZ=0;
 for(const c of g.children){const b=new THREE.Box3().setFromObject(c);if(b.isEmpty())continue;if(b.min.z>0&&!W[k].melee)u.stock.push(c);else u.backZ=Math.max(u.backZ,b.max.z);}
 if(u.glb)u.backZ=0;
 if(u.glb){u.vs=1.12;g.scale.setScalar(u.vs);}   // modÃ¨les 3D : la crosse est coupÃ©e par le plan proche de la camÃ©ra en visÃ©e
 VM.root.add(g);
 if(!VM.flashSprite){VM.flashSprite=new THREE.Sprite(flashSpriteMat.clone());VM.flashSprite.scale.set(.42,.42,1);
  VM.flashMesh=new THREE.Group();const m1=new THREE.Mesh(new THREE.PlaneGeometry(.34,.34),new THREE.MeshBasicMaterial({map:FLASHTEX,transparent:true,blending:THREE.AdditiveBlending,depthWrite:false,side:THREE.DoubleSide,toneMapped:false}));VM.flashMesh.add(m1);const m2=m1.clone();m2.rotation.y=1.57;VM.flashMesh.add(m2);}
 g.add(VM.flashSprite);g.add(VM.flashMesh);
 VM.flashSprite.position.set(0,.02,u.muzzle-.03);VM.flashMesh.position.set(0,.02,u.muzzle-.05);VM.flashSprite.visible=false;VM.flashMesh.visible=false;
 VM.drawMax=VM.drawT=drawDur(k,sk);
}
function papCamo(g){
 // arme améliorée : reflets violets animés
 g.traverse(o=>{if(o.isMesh&&o.material&&!o.material.isMeshBasicMaterial){const m=o.material.clone();m.color.lerp(new THREE.Color(0x6a2cff),.45);m.emissive=new THREE.Color(0x7a2cff);m.emissiveIntensity=.35;m.metalness=Math.max(m.metalness||0,.6);o.material=m;}});
}
function vmDraw(){VM.drawMax=VM.drawT=drawDur(VM.gk,null);VM.inspectT=0;}
function vmFire(w){
 VM.inspectT=0;if(VM.drawFl)VM.drawT=0;
 // recul sur ressort : impulsion, retour amorti (léger rebond)
 const e=VM.ent||P;
 VM.kv+=(w.cat==='sniper'||w.cat==='shotgun'?22:w.cat==='pistol'?14:12)*(1-.45*(e?e.ads:0));VM.flashT=.05;
 if(w.cat==='sniper'&&!w.auto){VM.boltT=.8;setTimeout(()=>sfx('bolt',undefined,undefined,.6),380);}
 if(w.cat==='shotgun'&&!w.auto){VM.pumpT=.6;setTimeout(()=>sfx('pump',undefined,undefined,.6),300);}
}
function vmReload(w){
 VM.reloadMax=w.rel;VM.inspectT=0;
 // recharge « à vide » : on réarme à la fin ; sinon recharge tactique, sans armement
 const e=VM.ent||P,wi=e&&curWi(e);VM.relEmpty=!!wi&&wi.mag<=0;VM.relSnd=0;VM.relDrop=false;
 VM.relShells=wi?clamp(magMax(e,wi.k)-wi.mag,1,4):3;
 const u=VM.gun&&VM.gun.userData;if(!u||(!u.mag&&!(w.cat==='shotgun')))sfx('reload',undefined,undefined,.8);
}
/* chargeur qui tombe : copie de la pièce, lâchée dans la scène de la vue subjective */
function vmDropMag(u){
 const m=u.mag;if(!m||!VM.gun)return;
 VM.gun.updateMatrixWorld(true);VM.root.updateMatrixWorld(true);
 const c=m.clone();c.matrixAutoUpdate=true;
 const mw=new THREE.Matrix4().copy(VM.root.matrixWorld).invert().multiply(m.matrixWorld);
 mw.decompose(c.position,c.quaternion,c.scale);VM.root.add(c);
 const d=u.magDir||V3(0,-1,0),q=VM.gun.quaternion;
 const v=V3(d.x,d.y,d.z).applyQuaternion(q).multiplyScalar(.9);v.x-=.15;
 VM.drops.push({o:c,v,s:V3((Math.random()-.5)*6,(Math.random()-.5)*4,4+Math.random()*3),t:0});
}
function vmDropsUpdate(dt){
 for(let i=VM.drops.length-1;i>=0;i--){const d=VM.drops[i];d.t+=dt;d.v.y-=7*dt;
  d.o.position.addScaledVector(d.v,dt);d.o.rotation.x+=d.s.x*dt;d.o.rotation.y+=d.s.y*dt;d.o.rotation.z+=d.s.z*dt;
  if(d.t>1.2||d.o.position.y<-1.2){VM.root.remove(d.o);VM.drops.splice(i,1);}}
}
function vmThrow(){VM.throwT=.7;}
function vmKnifeSwing(){VM.swingT=.38;}
function vmInspect(){if(VM.inspectT<=0&&VM.drawT<=0){VM.inspDur=inspectDur(VM.ent||P);VM.inspectT=VM.inspDur;VM.inspSnd=0;}}
const _vp=V3(),_vq=new THREE.Quaternion(),_vr=V3(),_vl=V3(),_ve=new THREE.Euler();
// ent : joueur regardé en spectateur (par défaut, le joueur lui-même)
function vmUpdate(dt,t,ent){
 const p=ent||P;
 if(VM.ent!==p){VM.ent=p;VM.gk=null;VM.ly=p.yaw;VM.lp=p.pitch;VM.prevGround=p.onGround;VM.kick=VM.kv=0;VM.reloadMax=0;VM.drops.forEach(d=>VM.root.remove(d.o));VM.drops.length=0;}
 extrasVmUpdate(t);
 const w=curW(p),k=curWi(p).k;
 const lk=entLook(p);VM.setLook(lk.kind==='ffa'?{kind:'ct',acc:lk.acc,tone:lk.tone,outfit:lk.outfit}:lk);
 if(VM.gk!==k||VM.skin!==vmSkinId(p,k)||VM.pap!==!!curWi(p).pap)vmSetGun(k);
 const g=VM.gun,u=g.userData;
 {const sd=Math.min(dt,.033);VM.kv+=(-VM.kick*300-VM.kv*26)*sd;VM.kick=clamp(VM.kick+VM.kv*sd,-.3,1.4);}
 VM.flashT=Math.max(0,VM.flashT-dt);VM.drawT=Math.max(0,VM.drawT-dt);VM.throwT=Math.max(0,VM.throwT-dt);VM.swingT=Math.max(0,VM.swingT-dt);VM.inspectT=Math.max(0,VM.inspectT-dt);
 vmDropsUpdate(dt);VM.boltT=Math.max(0,VM.boltT-dt);VM.pumpT=Math.max(0,VM.pumpT-dt);
 const ads=p.ads||0,spd=clamp((p.speed||0)/5.2,0,1.3);
 VM.bph+=dt*p.speed*1.7;
 // balancement selon la vue : l'arme traîne derrière le mouvement de la souris (ressort amorti, indépendant des fps)
 const dy=angDiff(VM.ly,p.yaw),dp=p.pitch-VM.lp;VM.ly=p.yaw;VM.lp=p.pitch;
 {const sd=Math.min(dt,.033),id=1/Math.max(dt,1e-3),tx=clamp(dy*id*.016,-.07,.07),ty=clamp(-dp*id*.016,-.055,.055);
  VM.sxv+=((tx-VM.sx)*150-VM.sxv*17)*sd;VM.sx+=VM.sxv*sd;VM.syv+=((ty-VM.sy)*150-VM.syv*17)*sd;VM.sy+=VM.syv*sd;
  // atterrissage : l'arme plonge puis revient
  if(p.onGround&&!VM.prevGround&&VM.airVy<-2)VM.lv-=Math.min(2.2,-VM.airVy*.22);
  VM.airVy=p.onGround?0:p.vy;VM.prevGround=p.onGround;
  VM.lv+=(-VM.land*220-VM.lv*19)*sd;VM.land+=VM.lv*sd;
  // déplacement latéral : l'arme s'incline
  const lat=p.vx*Math.cos(p.yaw)-p.vz*Math.sin(p.yaw);VM.strafe+=(clamp(lat/5,-1,1)-VM.strafe)*(1-Math.exp(-dt*8));}
 const bobk=cfg.bob?1-ads*.88:.3,ph=VM.bph;
 // marche en « 8 » + respiration au repos
 const bx=Math.sin(ph)*.009*spd*bobk,by=(Math.sin(ph*2)*.5-.25)*.012*spd*bobk,br=Math.sin(ph)*.018*spd*bobk;
 const idle=(1-clamp(spd,0,1))*(1-ads*.8),brY=Math.sin(t*1.7)*.0028*idle,brX=Math.sin(t*.9)*.0018*idle;
 let sightY=(u.sight||.06)*(u.vs||1);
 // position de base : hanche -> visée
 // en visée, la crosse reste à au moins 14 cm devant l'œil (sinon elle remplit l'écran)
 const adsZ=Math.min(-.46,-.38-(u.backZ||0))+(u.optic?.08:0);   // optique : arme un peu plus près de l'oeil
 let px=lerp(.19,0,ads),py=lerp(u.glb?-.162:-.172,-sightY,ads),pz=lerp(-.47,adsZ,ads);
 // position de hanche : canon légèrement tourné vers le centre, arme un peu inclinée
 let rx=.02*(1-ads),ry=.06*(1-ads),rz=-.05*(1-ads);
 const sw=1-ads*.75;
 px+=bx+brX+VM.sx*sw;py+=by+brY+VM.sy*sw+(p.crouch?.015:0);
 ry+=VM.sx*1.6*sw;rx+=VM.sy*1.2*sw;rz+=br-VM.sx*1.2*sw-VM.strafe*.06*(1-ads*.7);
 if(!p.onGround){const a=clamp(-p.vy*.005,-.035,.03);py+=a*(1-ads*.6);rx-=a*1.5;}
 py+=VM.land*.1;rx+=VM.land*.35;
 // recul
 const kk=VM.kick;pz+=kk*.055;rx+=kk*.09;rz+=Math.sin(G.t*47)*Math.max(0,kk)*.012;py+=kk*.01;
 // sortie de l'arme
 if(VM.drawT>0){const d=drawPose(u,w);px+=d.px;py+=d.py;pz+=d.pz;rx+=d.rx;ry+=d.ry;rz+=d.rz;}
 // lancer de grenade
 if(VM.throwT>0){const a=Math.sin((1-VM.throwT/.7)*Math.PI);py-=a*.32;rx-=a*.4;}
 // couteau
 let leftOff=0,leftX=0;
 if(VM.swingT>0){const a=1-VM.swingT/.38,s=Math.sin(a*Math.PI);rz+=s*1.1;ry+=s*.7;px-=s*.18;rx-=s*.5;pz-=s*.06;}
 // inspection
 // inspection (55c_inspect.js) : chorégraphie par type d'arme, chargeur sorti et montré
 let ins=null;
 if(VM.inspectT>0){if(ads>.3||p.reload>0)VM.inspectT=0;else{ins=inspectPose(u,w);px+=ins.px;py+=ins.py;pz+=ins.pz;rx+=ins.rx;ry+=ins.ry;rz+=ins.rz;}}
 // sprint (arme en travers), sprint tactique (arme levée), glissade (inclinée), escalade (arme baissée)
 {const mw=p.mv?p.mv.w:null;if(mw){const s=mw.spr*(1-ads),T=mw.tac*(1-ads),L=mw.sld,Mn=mw.mnt,sb=Math.sin(VM.bph*.9);
  px+=-s*.045+s*sb*.014;py+=-s*.05+s*Math.abs(sb)*.012;rx-=s*.3;ry+=s*.62;rz+=s*.38;
  px+=T*(.1+sb*.01);py+=T*(-.015+Math.abs(sb)*.015);rx+=T*.8;rz-=T*.6;ry-=T*.12;
  rz+=L*.32;py-=L*.03;px-=L*.02;py-=Mn*.22;rx-=Mn*.7;}}
 // rechargement
 let rl=-1;
 if(p.reload>0&&p.reloadMax>0){rl=1-p.reload/p.reloadMax;
  // rechargement en phases : bascule, chargeur dehors, chargeur dedans (claque), armement, retour
  const tilt=smooth01(clamp(rl/.16,0,1))*(1-smooth01(clamp((rl-.84)/.16,0,1)));
  const bump=(c,w2)=>Math.exp(-Math.pow((rl-c)/w2,2)),slap=bump(.74,.035),rack=VM.relEmpty?bump(.87,.04):0;
  // l'arme pivote pour montrer le puits de chargeur au centre de l'écran (sans ça, le chargeur passe sous le HUD)
  const mw=u.mag?tilt:0;
  rx+=tilt*.12+mw*.1+slap*-.08+rack*.06;rz+=tilt*(u.mag?-.42:.48)+slap*.06;ry-=tilt*.1-mw*.22;px-=tilt*.02+mw*.07;py-=tilt*.055-mw*.05-slap*.014;pz+=rack*.028-tilt*.02;
  leftOff=u.mag?tilt:0;
  // sons calés sur l'animation : chargeur dehors, chargeur dedans, armement
  const snd=(i,at,name)=>{if(VM.relSnd<i&&rl>=at){VM.relSnd=i;sfx(name,undefined,undefined,.8);}};
  if(u.mag){snd(1,.28,'magout');snd(2,.71,'magin');if(VM.relEmpty&&(u.bolt||u.slide))snd(3,u.slide?.84:.85,'rack');}
  else if(!u.mag&&w.cat==='shotgun'){
   // pompe : cartouches glissées une à une sous l'arme
   const n=VM.relShells,a=clamp((rl-.15)/.65,0,.999),ph=a*n%1,i=Math.floor(a*n);
   if(rl>.15&&rl<.8){leftOff=Math.sin(ph*Math.PI)*.6;if(VM.relSnd<=i&&ph>.55){VM.relSnd=i+1;sfx('shellin',undefined,undefined,.7);}}
   if(VM.relEmpty&&u.bolt)snd(99,.85,'pump');
  }}
 for(const c of u.stock)c.visible=ads<.55;
 {const nr=u.glb?.01+.14*ads:.01;if(Math.abs(vmCam.near-nr)>.002){vmCam.near=nr;vmCam.updateProjectionMatrix();}}
 g.position.set(px,py,pz);_ve.set(rx,ry,rz);g.quaternion.setFromEuler(_ve);
 // pièces mobiles
 if(u.mag){
  // base de la pièce (le chargeur d'un modèle 3D n'est pas forcément à l'origine)
  if(!u.magP0){u.magP0=u.mag.position.clone();u.magR0=u.mag.rotation.clone();u.magDir=VM.gk==='p90'?V3(0,.55,.85).normalize():V3(.18,-1,0).normalize();}
  // phases : .26-.36 sort, (tombe), .36-.46 la main descend chercher l'autre, .46-.58 remonte, .58-.72 l'enfonce
  let out=0,tw=0,vis=true;
  if(rl>=0){
   if(rl<.26)out=0;
   else if(rl<.36)out=smooth01((rl-.26)/.1);
   else if(rl<.46){out=1+smooth01((rl-.36)/.1)*1.4;vis=false;}
   else if(rl<.58){out=2.4-smooth01((rl-.46)/.12)*1.25;tw=1-smooth01((rl-.5)/.08);}
   else if(rl<.72)out=1.15*(1-smooth01((rl-.58)/.14));
   if(rl>=.36&&!VM.relDrop){VM.relDrop=true;vmDropMag(u);}
  }
  const d=u.magDir;
  u.mag.position.set(u.magP0.x+d.x*out*.2,u.magP0.y+d.y*out*.2,u.magP0.z+d.z*out*.2);
  u.mag.rotation.set(u.magR0.x+tw*.5,u.magR0.y,u.magR0.z+tw*.35);
  u.mag.visible=vis;
  if(ins)inspectMag(u,g,ins,p);else if(u.rounds)u.rounds.visible=false;
 }
 // armement en fin de recharge à vide (culasse / glissière tirée puis relâchée) ; glissière bloquée en arrière quand le pistolet est vide
 let pull=0;
 if(rl>=0&&VM.relEmpty)pull=rl<.82?0:rl<.87?smooth01((rl-.82)/.05):rl<.895?1-smooth01((rl-.87)/.025):0;
 // pistolet : glissière bloquée en arrière à vide, relâchée (arrêtoir) quand le chargeur neuf est en place
 const lockBack=u.slide&&!w.melee&&(rl<0?curWi(p).mag<=0:VM.relEmpty&&rl<.84);
 if(u.slide){if(u.slideZ0===undefined)u.slideZ0=u.slide.position.z;u.slide.position.z=u.slideZ0+Math.max(kk*.03,lockBack?.028:0);}
 if(u.bolt){if(u.boltZ0===undefined){u.boltZ0=u.bolt.position.z;u.boltRz0=u.bolt.rotation.z;}
  const bt=Math.max(VM.boltT>0?Math.sin((1-VM.boltT/.8)*Math.PI):0,pull);u.bolt.position.z=u.boltZ0+bt*.06;u.bolt.rotation.z=u.boltRz0+(w.cat==='sniper'?bt*.8:0);}
 if(u.pump){const pt=VM.pumpT>0?Math.sin((1-VM.pumpT/.6)*Math.PI):0;u.pump.position.z=pt*.09;}
 VM.flashSprite.visible=VM.flashT>0&&!u.noFlash;VM.flashMesh.visible=VM.flashT>0&&!u.noFlash;
 if(VM.flashT>0){VM.flashSprite.material.rotation=Math.random()*6;VM.flashMesh.rotation.z=Math.random()*6;const s=.8+Math.random()*.5;VM.flashMesh.scale.set(s,s,s);}
 // mains
 g.updateMatrix();
 const gm=g.matrix;
 _vr.copy(u.right).applyMatrix4(gm);
 if(u.twoHand){_vl.copy(u.left);_vl.y-=leftOff*.12;
  if(rl>=0&&u.mag){if(!u.magC){const b=new THREE.Box3();u.mag.updateMatrix();b.setFromObject(u.mag);const inv=new THREE.Matrix4().copy(g.matrixWorld).invert();b.applyMatrix4(inv);u.magC=b.getCenter(new THREE.Vector3());u.magC.sub(u.mag.position);}
   _vp.copy(u.magC).add(u.mag.position);_vp.y-=.02;
   // armement (arme longue vide) : la main droite lâche la poignée et tire le levier d'armement
   const rp=VM.relEmpty&&!u.slide?u.bolt:null;let k;
   if(rp&&rl>=.76){
    if(!u.rackC){const b=new THREE.Box3().setFromObject(rp);const inv=new THREE.Matrix4().copy(g.matrixWorld).invert();b.applyMatrix4(inv);u.rackC=b.getCenter(new THREE.Vector3());u.rackC.sub(rp.position);u.rackC.x=b.max.x-rp.position.x+.012;}
    const kin=smooth01(clamp((rl-.76)/.06,0,1)),hp=V3().copy(u.rackC).add(rp.position);
    k=rl>.8?(1-rl)/.2:1;hp.applyMatrix4(gm);VM.rackR=V3().copy(u.right).applyMatrix4(gm).lerp(hp,kin*(rl<.92?1:smooth01((1-rl)/.08)));
   }else k=rl<.15?rl/.15:rl>.8?(1-rl)/.2:1;
   _vl.lerp(_vp,smooth01(clamp(k,0,1)));}
  _vl.applyMatrix4(gm);
  if(ins&&ins.lh>0&&u.insMagC)_vl.lerp(u.insMagC,ins.lh);}
 else _vl.set(-.18,-.3,-.05);
 // main droite
 if(VM.rackR){_vr.copy(VM.rackR);VM.rackR=null;}
 VM.hR.position.copy(_vr);VM.hR.quaternion.copy(g.quaternion);
 VM.hL.visible=u.twoHand;VM.hL.position.copy(_vl);_vq.copy(g.quaternion);VM.hL.quaternion.copy(_vq);
 // avant-bras
 // bras en deux segments (épaule -> coude -> main) au lieu d'un seul tube étiré
 const seg=(m,a,b,len)=>{_vl.subVectors(b,a);const L=_vl.length();_vl.divideScalar(L||1);m.position.copy(a);m.quaternion.setFromUnitVectors(_dn,_vl);m.scale.set(1.15,L/len,1.15);};
 const place=(f,up,hand,sx)=>{
  _vp.set(sx*(.3-.06*ads),-.5-.14*ads,-.05);
  const LU=.34,LF=.3,d0=_vp.distanceTo(hand),k=Math.max(1,d0/(LU+LF-.01)),lu=LU*k,lf=LF*k,d=Math.max(d0,1e-4);
  const dir=V3().subVectors(hand,_vp).divideScalar(d);
  const a=(lu*lu-lf*lf+d*d)/(2*d),h=Math.sqrt(Math.max(0,lu*lu-a*a));
  const pole=V3(sx*.8,-1,.2);pole.addScaledVector(dir,-pole.dot(dir)).normalize();
  const el=_vp.clone().addScaledVector(dir,a).addScaledVector(pole,h);
  seg(up,_vp,el,.29);seg(f,el,hand,.27);
  // poignet : bande de manche qui sépare le bras du gant
  const c=sx>0?VM.cR:VM.cL;c.position.lerpVectors(el,hand,.9);c.quaternion.copy(f.quaternion);c.scale.set(1.45,.9,1.45);c.visible=true;
 };
 // le bras s'arrête au poignet (mains modelées : point « wrist » dans le repère de la main), pas au centre de la poignée
 const wrist=h=>{const w=h.userData.wrist;if(!w)return h.position.clone();h.updateMatrix();return w.clone().applyMatrix4(h.matrix);};
 const hrp=wrist(VM.hR);place(VM.fR,VM.uR,hrp,1);
 if(u.twoHand){const hlp=wrist(VM.hL);place(VM.fL,VM.uL,hlp,-1);VM.fL.visible=VM.uL.visible=true;}else VM.fL.visible=VM.uL.visible=false;
 if(!u.twoHand)VM.cL.visible=false;
 // en lunette : l'arme reste affichée autour de la lentille (floutée par #scopeBlur) ; un disque invisible
 // posé contre la caméra occupe la profondeur dans la lentille, pour que l'arme n'y soit pas dessinée
 if(!VM.lens){VM.lens=new THREE.Mesh(new THREE.CircleGeometry(1,48),new THREE.MeshBasicMaterial({colorWrite:false}));VM.lens.renderOrder=-10;vmCam.add(VM.lens);}
 VM.lens.visible=!!p.scoped;
 if(p.scoped){const d=vmCam.near*1.05,r=d*Math.tan(vmCam.fov*Math.PI/360)*.665;VM.lens.position.set(0,0,-d);VM.lens.scale.setScalar(r);}
 VM.root.visible=p.alive;
}
