/* =====================================================================
   VIEWMODEL : arme + mains en vue subjective, animations
   ===================================================================== */
vmScene.add(vmCam);
const VM={root:new THREE.Group(),gun:null,gk:null,skin:-1,look:'',kick:0,drawT:0,reloadMax:0,inspectT:0,throwT:0,swingT:0,flashT:0,boltT:0,pumpT:0,
 sx:0,sy:0,ly:0,lp:0,landT:0,bph:0,prevGround:true,swayR:0};
vmCam.add(VM.root);
{
 const look={kind:'ct',acc:'#3498db',tone:SKIN_TONES[0]};
 VM.setLook=(lk)=>{
  const key=lk.kind+lk.acc+lk.tone+(lk.outfit||0);if(VM.look===key)return;VM.look=key;initSoldierGeos();
  const M=lookMats(lk);
  if(VM.parts)for(const o of VM.parts)VM.root.remove(o);
  VM.fR=new THREE.Mesh(SG.farm,M.shirt);VM.fL=new THREE.Mesh(SG.farm,M.shirt);
  VM.cR=rb(.06,.06,.06,M.vest,0,0,0,.015);VM.cL=rb(.06,.06,.06,M.vest,0,0,0,.015);
  VM.hR=makeHandMesh(M.glove,true);VM.hL=makeHandMesh(M.glove,true);VM.hL.scale.x=-1;
  VM.parts=[VM.fR,VM.fL,VM.hR,VM.hL];
  for(const o of VM.parts){o.traverse(c=>{if(c.isMesh){c.castShadow=false;}});VM.root.add(o);}
 };
 VM.setLook(look);
}
function vmSetGun(k){
 if(VM.gun)VM.root.remove(VM.gun);
 const sk=skinOf(k),g=gunParts(k,sk);VM.gun=g;VM.gk=k;VM.skin=cfg.skins[k]||0;VM.pap=!!(P&&P.wp&&curWi(P)&&curWi(P).pap);if(VM.pap)papCamo(g);decorateVM(g,k);
 const u=g.userData;
 // bornes de l'arme (repère local) : sert à garder la crosse devant la caméra en visée
 // la crosse (pièces entièrement derrière la poignée) est masquée en visée : vue de 15 cm, elle boucherait l'écran
 g.updateMatrixWorld(true);u.stock=[];u.backZ=0;
 for(const c of g.children){const b=new THREE.Box3().setFromObject(c);if(b.isEmpty())continue;if(b.min.z>0&&!W[k].melee)u.stock.push(c);else u.backZ=Math.max(u.backZ,b.max.z);}
 VM.root.add(g);
 if(!VM.flashSprite){VM.flashSprite=new THREE.Sprite(flashSpriteMat.clone());VM.flashSprite.scale.set(.42,.42,1);
  VM.flashMesh=new THREE.Group();const m1=new THREE.Mesh(new THREE.PlaneGeometry(.34,.34),new THREE.MeshBasicMaterial({map:FLASHTEX,transparent:true,blending:THREE.AdditiveBlending,depthWrite:false,side:THREE.DoubleSide,toneMapped:false}));VM.flashMesh.add(m1);const m2=m1.clone();m2.rotation.y=1.57;VM.flashMesh.add(m2);}
 g.add(VM.flashSprite);g.add(VM.flashMesh);
 VM.flashSprite.position.set(0,.02,u.muzzle-.03);VM.flashMesh.position.set(0,.02,u.muzzle-.05);VM.flashSprite.visible=false;VM.flashMesh.visible=false;
 VM.drawT=.45;
}
function papCamo(g){
 // arme améliorée : reflets violets animés
 g.traverse(o=>{if(o.isMesh&&o.material&&!o.material.isMeshBasicMaterial){const m=o.material.clone();m.color.lerp(new THREE.Color(0x6a2cff),.45);m.emissive=new THREE.Color(0x7a2cff);m.emissiveIntensity=.35;m.metalness=Math.max(m.metalness||0,.6);o.material=m;}});
}
function vmDraw(){VM.drawT=.45;VM.inspectT=0;}
function vmFire(w){
 VM.kick=Math.min(1.4,VM.kick+(w.cat==='sniper'||w.cat==='shotgun'?1:.55));VM.flashT=.05;
 if(w.cat==='sniper'&&!w.auto){VM.boltT=.8;setTimeout(()=>sfx('bolt',undefined,undefined,.6),380);}
 if(w.cat==='shotgun'&&!w.auto){VM.pumpT=.6;setTimeout(()=>sfx('pump',undefined,undefined,.6),300);}
}
function vmReload(w){VM.reloadMax=w.rel;VM.inspectT=0;}
function vmThrow(){VM.throwT=.7;}
function vmKnifeSwing(){VM.swingT=.38;}
function vmInspect(){if(VM.inspectT<=0&&VM.drawT<=0)VM.inspectT=2.6;}
const _vp=V3(),_vq=new THREE.Quaternion(),_vr=V3(),_vl=V3(),_ve=new THREE.Euler();
function vmUpdate(dt,t){
 extrasVmUpdate(t);
 const p=P,w=curW(p),k=curWi(p).k;
 const lk=entLook(p);VM.setLook(lk.kind==='ffa'?{kind:'ct',acc:lk.acc,tone:lk.tone,outfit:lk.outfit}:lk);
 if(VM.gk!==k||VM.skin!==(cfg.skins[k]||0)||VM.pap!==!!curWi(p).pap)vmSetGun(k);
 const g=VM.gun,u=g.userData;
 VM.kick=Math.max(0,VM.kick-dt*11);VM.flashT=Math.max(0,VM.flashT-dt);VM.drawT=Math.max(0,VM.drawT-dt);VM.throwT=Math.max(0,VM.throwT-dt);VM.swingT=Math.max(0,VM.swingT-dt);VM.inspectT=Math.max(0,VM.inspectT-dt);
 VM.boltT=Math.max(0,VM.boltT-dt);VM.pumpT=Math.max(0,VM.pumpT-dt);
 const ads=p.ads,spd=clamp(p.speed/5.2,0,1.3);
 VM.bph+=dt*p.speed*1.7;
 // balancement selon la vue
 const dy=angDiff(VM.ly,p.yaw),dp=p.pitch-VM.lp;VM.ly=p.yaw;VM.lp=p.pitch;
 VM.sx+=(clamp(dy*1.1,-.06,.06)-VM.sx)*Math.min(1,dt*10);VM.sy+=(clamp(-dp*1.1,-.05,.05)-VM.sy)*Math.min(1,dt*10);
 if(p.onGround&&!VM.prevGround)VM.landT=.25;VM.prevGround=p.onGround;VM.landT=Math.max(0,VM.landT-dt);
 const bobk=cfg.bob?1-ads*.85:.3,bx=Math.sin(VM.bph)*.006*spd*bobk,by=Math.abs(Math.cos(VM.bph))*.008*spd*bobk;
 let sightY=u.sight||.06;
 // position de base : hanche -> visée
 // en visée, la crosse reste à au moins 14 cm devant l'œil (sinon elle remplit l'écran)
 const adsZ=Math.min(-.46,-.38-(u.backZ||0));
 let px=lerp(.16,0,ads),py=lerp(-.165,-sightY,ads),pz=lerp(-.44,adsZ,ads);
 // position de hanche : canon légèrement tourné vers le centre, arme un peu inclinée
 let rx=.02*(1-ads),ry=.06*(1-ads),rz=-.05*(1-ads);
 px+=bx+VM.sx*(1-ads*.7);py+=by+VM.sy*(1-ads*.7)+(p.crouch?.02:0);
 py-=VM.landT*.12;rx-=VM.landT*.3;
 // recul
 const kk=VM.kick;pz+=kk*.06;rx+=kk*.1;rz+=Math.sin(G.t*60)*kk*.01;py+=kk*.012;
 // sortie de l'arme
 if(VM.drawT>0){const a=VM.drawT/.45,e=a*a;py-=e*.28;rx-=e*.9;px+=e*.05;}
 // lancer de grenade
 if(VM.throwT>0){const a=Math.sin((1-VM.throwT/.7)*Math.PI);py-=a*.32;rx-=a*.4;}
 // couteau
 let leftOff=0,leftX=0;
 if(VM.swingT>0){const a=1-VM.swingT/.38,s=Math.sin(a*Math.PI);rz+=s*1.1;ry+=s*.7;px-=s*.18;rx-=s*.5;pz-=s*.06;}
 // inspection
 if(VM.inspectT>0){const a=1-VM.inspectT/2.6,s=smooth01(a<.15?a/.15:a>.85?(1-a)/.15:1);ry+=s*(1.15+Math.sin(a*8)*.15);rz+=s*(.4+Math.sin(a*6)*.2);rx+=s*.25;px-=s*.04;py+=s*.03;pz-=s*.05;}
 // rechargement
 let rl=-1;
 if(p.reload>0&&p.reloadMax>0){rl=1-p.reload/p.reloadMax;const a=Math.sin(rl*Math.PI);rx+=a*.45;rz+=a*.4;py-=a*.05;px-=a*.02;leftOff=a;}
 for(const c of u.stock)c.visible=ads<.55;
 g.position.set(px,py,pz);_ve.set(rx,ry,rz);g.quaternion.setFromEuler(_ve);
 // pièces mobiles
 if(u.mag){
  let out=0;
  if(rl>=0){out=rl<.25?0:rl<.45?smooth01((rl-.25)/.2):rl<.7?1-smooth01((rl-.5)/.2)*.0:1;
   if(rl>=.25&&rl<.5)out=smooth01((rl-.25)/.25);else if(rl>=.5&&rl<.75)out=1-smooth01((rl-.5)/.25);else out=0;}
  u.mag.position.y=-out*.2;u.mag.position.x=out*.04;u.mag.position.z=0;
  u.mag.visible=!(rl>=.3&&rl<.45);
 }
 if(u.slide)u.slide.position.z=kk*.03;
 if(u.bolt){const bt=VM.boltT>0?Math.sin((1-VM.boltT/.8)*Math.PI):0;u.bolt.position.z=bt*.06;u.bolt.rotation.z=bt*.8;}
 if(u.pump){const pt=VM.pumpT>0?Math.sin((1-VM.pumpT/.6)*Math.PI):0;u.pump.position.z=pt*.09;}
 VM.flashSprite.visible=VM.flashT>0;VM.flashMesh.visible=VM.flashT>0;
 if(VM.flashT>0){VM.flashSprite.material.rotation=Math.random()*6;VM.flashMesh.rotation.z=Math.random()*6;const s=.8+Math.random()*.5;VM.flashMesh.scale.set(s,s,s);}
 // mains
 g.updateMatrix();
 const gm=g.matrix;
 _vr.copy(u.right).applyMatrix4(gm);
 if(u.twoHand){_vl.copy(u.left);_vl.y-=leftOff*.12;_vl.applyMatrix4(gm);}
 else _vl.set(-.18,-.3,-.05);
 // main droite
 VM.hR.position.copy(_vr);VM.hR.quaternion.copy(g.quaternion);
 VM.hL.visible=u.twoHand;VM.hL.position.copy(_vl);_vq.copy(g.quaternion);VM.hL.quaternion.copy(_vq);
 // avant-bras
 const place=(f,c,hand,sx)=>{
  _vp.set(sx*(.3-.06*ads),-.5-.14*ads,-.05);
  const dx=hand.x-_vp.x,dy=hand.y-_vp.y,dz=hand.z-_vp.z,L=Math.hypot(dx,dy,dz);
  f.position.copy(_vp);_vl.set(dx/L,dy/L,dz/L);f.quaternion.setFromUnitVectors(_dn,_vl);f.scale.set(1.15,L/.27,1.15);
 };
 const hrp=VM.hR.position.clone();place(VM.fR,VM.cR,hrp,1);
 if(u.twoHand){const hlp=VM.hL.position.clone();place(VM.fL,VM.cL,hlp,-1);VM.fL.visible=true;}else VM.fL.visible=false;
 VM.cR.visible=VM.cL.visible=false;
 // masquer en lunette
 VM.root.visible=!(p.scoped)&&p.alive;
}
