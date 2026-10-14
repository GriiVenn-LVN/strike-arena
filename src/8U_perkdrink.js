/* =====================================================================
   ZOMBIES : BOIRE UN ATOUT
   Quand on achète un atout, on range l'arme, on sort le flacon de la
   couleur de l'atout, on fait sauter la capsule, on boit (le liquide
   baisse), on jette le flacon, puis on ressort l'arme.
   Vue subjective pour soi, flacon à la bouche vu par les autres.
   Pendant ~2,3 s : pas de tir ni de visée.
   ===================================================================== */
const DRK={T:2.3,on:false,t:0,key:null,col:'#fff',btl:null,cap:null,liq:null,fly:[],capOff:false,glug:0,tossed:false,drawn:false,fx:null};
const _drkGeoCache={};
// flacon original : corps arrondi, épaulement, col cannelé, capsule sertie, étiquette à l'icône de l'atout
function drkBottle(key,scale){
 const p=PERKS[key]||{c:'#fff',ic:'?',n:''};
 if(!_drkGeoCache.body){
  const prof=[[0,0],[.028,0],[.034,.006],[.036,.02],[.036,.1],[.033,.118],[.022,.138],[.012,.152],[.011,.19],[.013,.193],[.013,.2],[0,.2]].map(a=>new THREE.Vector2(a[0],a[1]));
  _drkGeoCache.body=new THREE.LatheGeometry(prof,20);
  const lq=[[0,.004],[.03,.004],[.032,.02],[.032,.1],[0,.1]].map(a=>new THREE.Vector2(a[0],a[1]));
  _drkGeoCache.liq=new THREE.LatheGeometry(lq,18);
  _drkGeoCache.label=new THREE.CylinderGeometry(.0368,.0368,.06,20,1,true);
  _drkGeoCache.cap=new THREE.CylinderGeometry(.0145,.0145,.012,12);
  _drkGeoCache.ring=new THREE.TorusGeometry(.0115,.002,6,16);
 }
 const g=new THREE.Group(),c=new THREE.Color(p.c);
 const glass=new THREE.MeshStandardMaterial({color:c.clone().lerp(new THREE.Color(0xffffff),.25),transparent:true,opacity:.42,roughness:.06,metalness:.2,depthWrite:false});
 const liqM=new THREE.MeshStandardMaterial({color:c,emissive:c,emissiveIntensity:.55,roughness:.2,transparent:true,opacity:.92});
 const lab=new THREE.MeshStandardMaterial({map:drkLabelTex(key),roughness:.6});
 const metal=new THREE.MeshStandardMaterial({color:0xd8b25a,metalness:.9,roughness:.3});
 const body=new THREE.Mesh(_drkGeoCache.body,glass);body.renderOrder=2;
 const liq=new THREE.Mesh(_drkGeoCache.liq,liqM);
 const label=new THREE.Mesh(_drkGeoCache.label,lab);label.position.y=.06;
 const cap=new THREE.Mesh(_drkGeoCache.cap,metal);cap.position.y=.204;
 const ring=new THREE.Mesh(_drkGeoCache.ring,metal);ring.rotation.x=Math.PI/2;ring.position.y=.188;
 g.add(liq,body,label,ring,cap);
 g.userData={liq,cap,body};
 if(scale)g.scale.setScalar(scale);
 g.traverse(o=>{if(o.isMesh)o.castShadow=false;});
 return g;
}
const _drkLab={};
function drkLabelTex(key){
 if(_drkLab[key])return _drkLab[key];
 const p=PERKS[key]||{c:'#fff',ic:'?',n:''};
 return _drkLab[key]=cvTex(256,64,(x,w,h)=>{
  x.fillStyle='#16110c';x.fillRect(0,0,w,h);
  const gr=x.createLinearGradient(0,0,0,h);gr.addColorStop(0,p.c);gr.addColorStop(1,'#000');x.fillStyle=gr;x.fillRect(0,8,w,h-16);
  x.fillStyle='#f5ead2';x.fillRect(0,6,w,3);x.fillRect(0,h-9,w,3);
  x.font='bold 30px Arial';x.textAlign='center';x.fillStyle='#fff';
  for(const cx of [40,168])x.fillText(p.ic,cx,43);
  x.font='bold 15px Bahnschrift,Arial';x.fillText((p.n||'').toUpperCase(),104,40);x.fillText((p.n||'').toUpperCase(),232,40);
 });
}
/* ---------- sons ---------- */
function drkSfx(k){
 if(!AC)return;
 if(k==='out'){nz(.12,900,'bandpass',.25,0,0,1.2);tn(420,.06,'triangle',.08,0,620,0,.05);}
 else if(k==='pop'){nz(.03,2600,'bandpass',.6,0,0,3);tn(1300,.05,'sine',.2,0,700,0,0);tn(2600,.18,'triangle',.05,0,2400,0,.12);}
 else if(k==='glug'){tn(170+Math.random()*40,.09,'sine',.35,0,110,0,0);nz(.06,500,'lowpass',.15,0,0,1);}
 else if(k==='ahh'){tn(220,.35,'sine',.12,0,330,.2,0);nz(.3,1400,'bandpass',.08,0,.2,.8);}
 else if(k==='toss'){nz(.08,1800,'bandpass',.15,0,0,1);}
 else if(k==='clink'){tn(3100,.12,'triangle',.12,.3,2900,.2,0);tn(4200,.1,'sine',.06,.3,4000,.2,.03);nz(.04,6000,'highpass',.2,.3,.1,1);}
}
/* ---------- départ ---------- */
function drkStart(key,col){
 if(!P||!P.alive)return;
 if(DRK.on)drkEnd(true);
 DRK.on=true;DRK.t=0;DRK.key=key;DRK.col=col||(PERKS[key]&&PERKS[key].c)||'#fff';DRK.capOff=false;DRK.glug=0;DRK.tossed=false;DRK.drawn=false;DRK.snd=0;
 DRK.btl=drkBottle(key,.88);VM.root.add(DRK.btl);DRK.btl.visible=false;
 P.drinkT=DRK.T;P.switchT=Math.max(P.switchT,DRK.T);P.ads=0;P.reload=0;
 drkSfx('out');
}
function drkEnd(abort){
 DRK.on=false;if(P)P.drinkT=0;
 if(DRK.ban){const b=DRK.ban;DRK.ban=null;sfx('perk');uiBanner(b[0],b[1],b[2],b[3]);}
 if(DRK.btl&&!DRK.tossed)VM.root.remove(DRK.btl);DRK.btl=null;
 if(VM.gun)VM.gun.visible=true;
 if(!abort&&!DRK.drawn)vmDraw();
}
// quel atout vient d'être pris : on compare avant/après
function drkNewPerk(prev,now){for(const k in now)if(now[k]&&!(prev&&prev[k]))return k;return null;}
const _drkTell=zTell;
zTell=function(e,msg,snd,ban){
 // la bannière et la musique de l'atout viennent quand on a fini de boire
 if(snd==='perk'&&e&&e.isPlayer){const key=drkGuess(ban);drkStart(key,ban&&ban[3]);DRK.ban=ban;return _drkTell(e,msg,null,null);}
 return _drkTell(e,msg,snd,ban);
};
function drkGuess(ban){
 // la bannière porte le nom de l'atout en majuscules
 if(ban&&ban[0])for(const k in PERKS)if(PERKS[k].n.toUpperCase()===ban[0])return k;
 return Object.keys(PERKS)[0];
}
// invité : l'hôte nous dit qu'on vient de boire
if(typeof netClientEvent==='function'){
 const _drkNet=netClientEvent;
 netClientEvent=function(ev){
  if(ev&&ev.t==='msg'&&ev.to===NET.myEnt&&ev.s==='perk'){drkStart(drkGuess(ev.b),ev.b&&ev.b[3]);DRK.ban=ev.b;ev=Object.assign({},ev,{s:'',b:null});}
  return _drkNet(ev);
 };
}
// changer d'arme ne coupe pas la boisson
const _drkSwitch=switchTo;
switchTo=function(e,slot){_drkSwitch(e,slot);if(e===P&&DRK.on){e.switchT=Math.max(e.switchT,DRK.T-DRK.t);}};
/* ---------- vue subjective ---------- */
const _drkP=V3(),_drkQ=new THREE.Quaternion(),_drkE=new THREE.Euler(),_drkA=V3(),_drkB=V3(),_drkH=V3(),_drkUp=V3(0,1,0);
const _drkPose=(t)=>{
 // trajectoire du flacon (repère caméra), par étapes
 const sm=smooth01,cl=clamp;
 const a=sm(cl((t-.28)/.3,0,1)),        // sort par le bas
       b=sm(cl((t-.78)/.3,0,1)),        // monte à la bouche
       d=sm(cl((t-1.62)/.22,0,1));      // redescend pour être jeté
 _drkP.set(lerp(.24,.1,a),lerp(-.52,-.2,a),lerp(-.42,-.47,a));
 let rx=lerp(-.4,.18,a),ry=0,rz=lerp(.5,.22,a);
 // à la bouche : fond du flacon devant et en haut, goulot vers la bouche
 _drkP.x=lerp(_drkP.x,.055,b);_drkP.y=lerp(_drkP.y,.012,b);_drkP.z=lerp(_drkP.z,-.25,b);
 rx=lerp(rx,1.95,b);rz=lerp(rz,.1,b);
 // petites gorgées
 if(t>.6&&t<.74){const j=Math.sin((t-.6)/.14*Math.PI);rx-=j*.25;_drkP.y+=j*.012;}
 if(b>.9&&d<.05){const g=Math.sin((t-1.08)*14);_drkP.y+=g*.004;rx+=g*.04;}
 _drkP.x=lerp(_drkP.x,.34,d);_drkP.y=lerp(_drkP.y,-.32,d);_drkP.z=lerp(_drkP.z,-.42,d);rx=lerp(rx,.6,d);rz=lerp(rz,-.9,d);
 _drkE.set(rx,ry,rz);_drkQ.setFromEuler(_drkE);
 return {a,b,d};
};
// bras de la vue subjective (même principe que vmUpdate : épaule -> coude -> main)
function drkArm(f,up,cuff,hand,sx){
 const seg=(m,a,b,len)=>{_drkA.subVectors(b,a);const L=_drkA.length();_drkA.divideScalar(L||1);m.position.copy(a);m.quaternion.setFromUnitVectors(_dn,_drkA);m.scale.set(1.15,L/len,1.15);};
 _drkB.set(sx*.3,-.5,-.05);
 const LU=.34,LF=.3,d0=_drkB.distanceTo(hand),k=Math.max(1,d0/(LU+LF-.01)),lu=LU*k,lf=LF*k,d=Math.max(d0,1e-4);
 const dir=V3().subVectors(hand,_drkB).divideScalar(d);
 const a=(lu*lu-lf*lf+d*d)/(2*d),h=Math.sqrt(Math.max(0,lu*lu-a*a));
 const pole=V3(sx*.8,-1,.2);pole.addScaledVector(dir,-pole.dot(dir)).normalize();
 const el=_drkB.clone().addScaledVector(dir,a).addScaledVector(pole,h);
 seg(up,_drkB,el,.29);seg(f,el,hand,.27);
 cuff.position.lerpVectors(el,hand,.9);cuff.quaternion.copy(f.quaternion);cuff.scale.set(1.45,.9,1.45);cuff.visible=true;
}
const _drkVm=vmUpdate;
vmUpdate=function(dt,t){
 if(DRK.on){P.ads=0;if(!P.alive||P.downed||G.variant!=='zombies'){drkEnd(true);}}
 _drkVm(dt,t);
 drkFlyUpdate(dt);
 if(!DRK.on)return;
 DRK.t+=dt;const T=DRK.t,g=VM.gun,B=DRK.btl,u=B.userData;
 P.drinkT=Math.max(0,DRK.T-T);
 // 1) l'arme descend hors de l'écran
 const lo=smooth01(clamp(T/.3,0,1)),back=T>1.85;
 const arms=[VM.hR,VM.hL,VM.fR,VM.fL,VM.uR,VM.uL,VM.cR,VM.cL];
 if(!back){_drkA.set(lo*.06,-lo*(lo*.38),lo*.04);for(const o of [g,...arms])o.position.add(_drkA);_drkE.set(-lo*.5,0,lo*.25);_drkQ.setFromEuler(_drkE);g.quaternion.multiply(_drkQ);g.visible=lo<.98;
  if(T>=.28)for(const o of arms)o.visible=false;}
 else if(!DRK.drawn){DRK.drawn=true;g.visible=true;vmDraw();sfx('draw');}
 if(T<.28||DRK.tossed){if(T>=DRK.T)drkEnd();return;}
 // 2) le flacon
 const ph=_drkPose(T);B.visible=true;B.position.copy(_drkP);B.quaternion.copy(_drkQ);
 // liquide qui baisse pendant qu'on boit
 const drink=clamp((T-1.02)/.58,0,1);u.liq.scale.y=Math.max(.02,1-drink);u.liq.visible=drink<.99;
 // main droite autour du corps du flacon
 _drkH.set(.006,.055,.024).applyQuaternion(_drkQ).add(_drkP);
 VM.hR.visible=true;VM.hR.position.copy(_drkH);_drkE.set(-Math.PI/2,0,0);VM.hR.quaternion.copy(_drkQ).multiply(new THREE.Quaternion().setFromEuler(_drkE));
 drkArm(VM.fR,VM.uR,VM.cR,_drkH,1);VM.fR.visible=VM.uR.visible=true;
 // main gauche hors champ : le pouce droit fait sauter la capsule (petit coup de poignet)
 const lk=0;
 if(lk>.01){
  _drkA.set(0,.2,0).applyQuaternion(_drkQ).add(_drkP);
  const flick=T>.62&&T<.78?Math.sin((T-.62)/.16*Math.PI)*.05:0;
  _drkB.set(-.24,-.55,-.3).lerp(_drkA,lk);_drkB.x-=.035*lk;_drkB.y+=flick;
  VM.hL.visible=true;VM.hL.position.copy(_drkB);VM.hL.quaternion.copy(_drkQ);
  const hl=VM.hL.position.clone();drkArm(VM.fL,VM.uL,VM.cL,hl,-1);VM.fL.visible=VM.uL.visible=true;
 }else{VM.cL.visible=false;}
 // capsule qui saute
 if(!DRK.capOff&&T>=.7){DRK.capOff=true;u.cap.visible=false;drkSfx('pop');
  const c=u.cap.clone();c.visible=true;c.position.copy(V3(0,.205,0).applyQuaternion(_drkQ).add(_drkP));VM.root.add(c);
  DRK.fly.push({o:c,v:V3(-.35,.9,-.1),s:V3(18,9,4),t:0,life:.8});}
 // gorgées
 if(T>1.05&&T<1.6){DRK.glug-=dt;if(DRK.glug<=0){DRK.glug=.17;drkSfx('glug');}}
 if(T>=1.6&&DRK.snd<1){DRK.snd=1;drkSfx('ahh');drkScreen(DRK.col);sfx('perk');const b=DRK.ban;if(b)uiBanner(b[0],b[1],b[2],b[3]);DRK.ban=null;}
 // 3) on jette le flacon
 if(T>=1.84&&!DRK.tossed){DRK.tossed=true;drkSfx('toss');setTimeout(()=>drkSfx('clink'),420);
  DRK.fly.push({o:B,v:V3(.9,.6,-.4),s:V3(9,3,11),t:0,life:.7});
  VM.hR.visible=VM.fR.visible=VM.uR.visible=true;}
};
function drkFlyUpdate(dt){
 for(let i=DRK.fly.length-1;i>=0;i--){const f=DRK.fly[i];f.t+=dt;f.v.y-=3.2*dt;f.o.position.addScaledVector(f.v,dt);
  f.o.rotation.x+=f.s.x*dt;f.o.rotation.y+=f.s.y*dt;f.o.rotation.z+=f.s.z*dt;
  if(f.t>f.life){VM.root.remove(f.o);DRK.fly.splice(i,1);}}
}
// lueur de la couleur de l'atout sur les bords de l'écran
function drkScreen(col){
 let el=DRK.fx;
 if(!el){el=DRK.fx=document.createElement('div');el.style.cssText='position:fixed;inset:0;pointer-events:none;z-index:7;opacity:0;transition:opacity .25s';($('hud')||document.body).appendChild(el);}
 el.style.background='radial-gradient(ellipse at 50% 55%,transparent 45%,'+col+'66 80%,'+col+'cc 100%)';
 el.style.transition='none';el.style.opacity=1;void el.offsetWidth;el.style.transition='opacity 1.1s ease-out';el.style.opacity=0;
 if(G.shake!==undefined)G.shake=Math.max(G.shake,.18);
}
/* ---------- vu par les autres : flacon dans la main, porté à la bouche ---------- */
const _drk3T=V3(),_drk3L=V3();
function anDrink3P(R,e,K,t){
 const key=drkKeyOf(e);
 if(!R.btl||R.btlK!==key){if(R.btl)R.spine.remove(R.btl);R.btl=drkBottle(key,1.3);R.btlK=key;R.spine.add(R.btl);}
 R.btl.visible=true;
 // la bouteille monte à la bouche et s'incline, goulot contre les lèvres
 const k=smooth01(K),rx=lerp(.15,2.1,k);
 _drk3T.set(lerp(.22,.05,k),lerp(.22,.62,k),lerp(-.25,-.3,k));
 _drk3L.set(-.2,.12,-.08);
 anArmTo(R,'R',_drk3T);anArmTo(R,'L',_drk3L);
 // la main tient le flacon au milieu : origine (fond) = main - axe × 12 cm
 R.btl.rotation.set(rx,0,lerp(.25,.05,k));
 R.btl.position.set(_drk3T.x,_drk3T.y-Math.cos(rx)*.12,_drk3T.z-Math.sin(rx)*.12);
 R.btl.userData.liq.scale.y=1-k*.85;
 R.neckG.rotation.x-=.35*k;
}
function drkKeyOf(e){
 // dernier atout pris (pour la couleur du flacon)
 if(e.lastPerk)return e.lastPerk;
 const ks=Object.keys(e.perks||{}).filter(k=>e.perks[k]);return ks[ks.length-1]||'jugg';
}
// hôte : bots et joueurs distants qui prennent un atout boivent aussi (vu de tous)
const _drkSyncR=syncRigs;
syncRigs=function(dt,t){
 for(const e of ents){
  if(e.zombie||e===P)continue;
  if(e.drinkT>0)e.drinkT=Math.max(0,e.drinkT-dt);
  if(G.variant==='zombies'&&e.perks&&!e.anNet){const n=Object.keys(e.perks).filter(k=>e.perks[k]);if(e._pkN!==undefined&&n.length>e._pkN){e.lastPerk=n[n.length-1];e.drinkT=DRK.T*.8;}e._pkN=n.length;}
  if(e.anNet&&e.perks){const n=Object.keys(e.perks).filter(k=>e.perks[k]);if(n.length)e.lastPerk=n[n.length-1];}
 }
 _drkSyncR(dt,t);
};
