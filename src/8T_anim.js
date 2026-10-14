/* =====================================================================
   ANIMATIONS DES SOLDATS EN 3E PERSONNE (vues par les autres joueurs)
   - Sprint : buste penché, grandes foulées, arme en travers du torse.
   - Sprint tactique : arme levée vers le ciel, bras gauche qui balance.
   - Glissade : corps couché en arrière, jambe avant tendue, main gauche
     qui frotte le sol, traînée de poussière.
   - Esquive : corps penché dans la direction, traînée de vitesse.
   - Saut : jambes repliées à la montée, tendues à la descente,
     réception amortie (genoux qui plient) avec poussière.
   - Escalade : mains posées sur le rebord, jambes repliées.
   - Poids : le buste bascule à l'accélération et au freinage.
   L'état (glissade, sprint…) est envoyé en multijoueur (bits « an »),
   pour que chacun voie les autres glisser pour de vrai.
   Se greffe sur animateSoldier / attachRig / netSend sans les modifier.
   ===================================================================== */
const AN={SLIDE:1,SPR:2,TAC:4,DASH:8,MANT:16,DRINK:32};
// bits d'animation d'une entité : simulés ici, ou reçus du réseau
function anBits(e){
 if(e.anNet)return e.anB||0;
 let b=0;const M=e.mv;
 if(e.slide)b|=AN.SLIDE;if(e.dash)b|=AN.DASH;if(e.mantle)b|=AN.MANT;
 if(M&&M.spr&&e.speed>RUN*.8){b|=AN.SPR;if(M.tac)b|=AN.TAC;}
 else if(!e.isPlayer&&!e.remote&&!e.zombie&&e.speed>RUN*1.05)b|=AN.SPR;   // bots qui foncent
 if(e.drinkT>0)b|=AN.DRINK;
 return b;
}
// le rig connaît son entité
const _anAttach=attachRig;
attachRig=function(e){_anAttach(e);if(e.rig)e.rig.ent=e;};
/* ---------- réseau : bits d'animation, vitesse, au sol ---------- */
const _anSend=netSend;
netSend=function(m,to){
 if(m&&m.t==='in'&&P){m.an=anBits(P);m.vy=+(P.vy||0).toFixed(1);}
 else if(m&&m.t==='snap'&&m.e){for(const o of m.e){const e=ents.find(x=>x.id===o.i);if(!e)continue;const b=anBits(e);if(b)o.an=b;o.vx=+(e.vx||0).toFixed(1);o.vz=+(e.vz||0).toFixed(1);if(!e.onGround){o.og=0;o.vy=+(e.vy||0).toFixed(1);}}}
 return _anSend(m,to);
};
const _anApply=netApplySnap;
netApplySnap=function(m){
 _anApply(m);
 for(const o of m.e){if(o.i===NET.myEnt)continue;const e=NET.view.get(o.i);if(!e)continue;
  e.anNet=true;e.anB=o.an||0;e.vx=o.vx||0;e.vz=o.vz||0;e.onGround=o.og!==0;e.vy=o.vy||0;}
};
const _anEntUp=netEntUpdate;
netEntUpdate=function(e,dt){
 _anEntUp(e,dt);
 const p=[...NET.players.values()].find(x=>x.ent===e),m=p&&p.in;
 if(m){e.anNet=true;e.anB=m.an||0;e.vy=m.vy||0;}
};
/* ---------- petits effets visibles de tous ---------- */
const ANFX={pool:[],mat:null};
function anStreak(x,y,z,dx,dz,len){
 if(!cfg.fx&&Math.random()<.6)return;
 if(!ANFX.mat)ANFX.mat=new THREE.MeshBasicMaterial({color:0xdfefff,transparent:true,opacity:.5,blending:THREE.AdditiveBlending,depthWrite:false,side:THREE.DoubleSide,toneMapped:false,fog:true});
 let s=ANFX.pool.find(o=>o.t<=0);
 if(!s){if(ANFX.pool.length>40)return;const gm=new THREE.PlaneGeometry(.025,1);gm.rotateX(Math.PI/2);gm.rotateZ(Math.PI/2);const m=new THREE.Mesh(gm,ANFX.mat.clone());m.frustumCulled=false;scene.add(m);s={m,t:0};ANFX.pool.push(s);}
 s.t=.28;s.m.visible=true;s.m.position.set(x,y,z);s.m.scale.set(1,len,1);
 // ruban vertical aligné sur la vitesse
 s.m.rotation.set(0,Math.atan2(dx,dz),0);
}
function anFxUpdate(dt){
 for(const s of ANFX.pool){if(s.t<=0)continue;s.t-=dt;s.m.material.opacity=Math.max(0,s.t/.28)*.5;if(s.t<=0)s.m.visible=false;}
}
/* ---------- couche d'animation ---------- */
const _anGp=V3(),_anGq=new THREE.Quaternion(),_anQ2=new THREE.Quaternion(),_anE=new THREE.Euler(),_anV=V3(),_anW=V3(),_anL=V3(),_anR=V3();
const AN_SPR_P=V3(.02,.13,-.2),AN_SPR_Q=new THREE.Quaternion().setFromEuler(new THREE.Euler(.32,1.05,.3));
const AN_TAC_P=V3(.17,.36,-.14),AN_TAC_Q=new THREE.Quaternion().setFromEuler(new THREE.Euler(1.3,.25,-.15));
const AN_SLD_P=V3(.1,.22,-.3),AN_SLD_Q=new THREE.Quaternion().setFromEuler(new THREE.Euler(-.6,.12,-.3));   // canon à l'horizontale malgré le buste couché
const AN_MNT_P=V3(.16,.05,-.12),AN_MNT_Q=new THREE.Quaternion().setFromEuler(new THREE.Euler(-1.25,.2,.3));
// place un bras (épaule -> coude -> main) vers une cible dans le repère de la colonne
function anArmTo(R,key,tgt){
 const A=R.arm[key];ik2(A.S,tgt,.29,.27,A.pole,_el);A.E.copy(_el);
 placeLimb(A.ua,A.S,A.E);placeLimb(A.fa,A.E,tgt);A.elbow.position.copy(A.E);A.hand.position.copy(tgt);
 _d.subVectors(tgt,A.E).normalize();A.hand.quaternion.setFromUnitVectors(V3(0,0,-1),_d);
 A.band.position.copy(A.S).lerp(A.E,.55);A.band.quaternion.copy(A.ua.quaternion);A.pad.position.copy(A.E);A.pad.quaternion.copy(A.ua.quaternion);
}
const _anBase=animateSoldier;
animateSoldier=function(R,st,dt,t){
 _anBase(R,st,dt,t);
 const e=R.ent;
 if(!e||!st.alive||st.dance||st.seated||R.zm||!R.legL){if(R.aw)R.aw=null;if(R.btl)R.btl.visible=false;return;}
 const b=anBits(e),w=R.aw||(R.aw={spr:0,tac:0,sld:0,dsh:0,mnt:0,drk:0,air:0,lnd:0,lv:0,acc:0,pfw:0,og:true,vy:0,ly:st.y||0,fxT:0,stepS:0,dx:0,dz:0});
 const f=1-Math.exp(-dt*10),fs=1-Math.exp(-dt*16);
 const air=!st.onGround&&!(b&AN.MANT);
 w.spr+=((b&AN.SPR&&!(b&AN.TAC)?1:0)-w.spr)*f;
 w.tac+=((b&AN.TAC?1:0)-w.tac)*f;
 w.sld+=((b&AN.SLIDE?1:0)-w.sld)*fs;
 w.dsh+=((b&AN.DASH?1:0)-w.dsh)*(1-Math.exp(-dt*22));
 w.mnt+=((b&AN.MANT?1:0)-w.mnt)*fs;
 w.drk+=((b&AN.DRINK?1:0)-w.drk)*f;
 w.air+=((air?1:0)-w.air)*(1-Math.exp(-dt*12));
 // vitesse verticale (estimée si elle ne vient pas de la simulation)
 const y=st.y||0;let vy=e.vy;if(vy===undefined||e.anNet&&!e.vy)vy=(y-w.ly)/Math.max(dt,1e-3);w.ly=y;
 w.vy+=(vy-w.vy)*Math.min(1,dt*10);
 // réception : ressort amorti, d'autant plus fort que la chute est rapide
 if(st.onGround&&!w.og&&w.fall<-3){w.lv-=Math.min(9,-w.fall*.9);if(w.fall<-6&&cfg.fx!==0)fxDust(R.root.position.x,y+.05,R.root.position.z,6,.18);}
 w.fall=st.onGround?0:Math.min(w.fall||0,w.vy);w.og=st.onGround;
 {const sd=Math.min(dt,.033);w.lv+=(-w.lnd*160-w.lv*15)*sd;w.lnd=clamp(w.lnd+w.lv*sd,-1,.15);}
 const land=Math.max(0,-w.lnd);
 // accélération avant : le buste bascule (démarrage) puis se redresse (freinage)
 const fwv=R.fw||0;w.acc+=(clamp((fwv-w.pfw)/Math.max(dt,1e-3)*.08,-1,1)-w.acc)*(1-Math.exp(-dt*6));w.pfw=fwv;
 const hips=R.hips,sp=R.spine,ph=R.ph,s=Math.sin;
 const S=w.spr*(1-w.sld),T=w.tac*(1-w.sld),L=w.sld,D=w.dsh*(1-L),Mn=w.mnt,A=w.air*(1-Mn)*(1-L),K=w.drk;
 // --- jambes ---
 const legs=[R.legL,R.legR];
 if(S+T>.01){const g=S+T*1.15;for(const Lg of legs){Lg.th.rotation.x*=1+.4*g;Lg.sh.rotation.x*=1+.35*g;}
  hips.position.y-=.03*g;hips.position.y+=Math.abs(s(ph))*.025*g;}
 if(A>.01){
  const up=clamp(w.vy/5,-1,1),r=up>0?up:0,dn=up<0?-up:0;
  const tuck=(Lg,side)=>{const th=.25+r*.75+(side>0?.25:-.1)*r-dn*.05,sh=-.35-r*1.15-(side>0?.3:0)*r-dn*.05;
   Lg.th.rotation.x+=(th-Lg.th.rotation.x)*A;Lg.sh.rotation.x+=(sh-Lg.sh.rotation.x)*A;Lg.foot.rotation.x+=(.2+r*.25-Lg.foot.rotation.x)*A;Lg.th.rotation.z+=(-side*.06*dn)*A;};
  tuck(R.legL,-1);tuck(R.legR,1);
 }
 if(land>.001){for(const Lg of legs){Lg.th.rotation.x+=land*.75;Lg.sh.rotation.x-=land*1.3;Lg.foot.rotation.x+=land*.5;}hips.position.y-=land*.17;}
 if(L>.01){
  // glissade : jambe droite tendue devant, jambe gauche repliée dessous
  const lp=(Lg,th,sh,ft,tz)=>{Lg.th.rotation.x+=(th-Lg.th.rotation.x)*L;Lg.sh.rotation.x+=(sh-Lg.sh.rotation.x)*L;Lg.foot.rotation.x+=(ft-Lg.foot.rotation.x)*L;Lg.th.rotation.z+=(tz-Lg.th.rotation.z)*L;};
  lp(R.legR,1.42,-.12,.55,-.05);lp(R.legL,.45,-2.15,.25,.2);
  hips.position.y+=(.36-hips.position.y)*L;hips.rotation.y+=(.38-hips.rotation.y)*L;hips.rotation.z+=(-.08-hips.rotation.z)*L;
 }
 if(D>.01){
  // esquive : jambe d'appui poussée en arrière, l'autre genou monté
  const sd=clamp(R.sd||0,-1,1),fw=clamp(R.fw||0,-1,1);
  R.legL.th.rotation.z+=(-.45*Math.max(0,-sd)+.15*Math.max(0,sd))*D;R.legR.th.rotation.z+=(.45*Math.max(0,sd)-.15*Math.max(0,-sd))*D;
  R.legR.th.rotation.x+=(.9*fw-R.legR.th.rotation.x*.5)*D;R.legL.th.rotation.x+=(-.55*fw-R.legL.th.rotation.x*.5)*D;R.legR.sh.rotation.x-=.9*D;
 }
 if(Mn>.01){for(const Lg of legs){Lg.th.rotation.x+=(1.25-Lg.th.rotation.x)*Mn;Lg.sh.rotation.x+=(-1.7-Lg.sh.rotation.x)*Mn;}}
 // --- buste et corps ---
 sp.rotation.x+=-.3*S-.2*T+.62*L-.12*A*clamp(-w.vy/5,0,1)-.18*land-w.acc*.12*(1-L)+.25*Mn*-1;
 sp.rotation.y-=.4*L;sp.rotation.z+=s(ph)*.05*S;
 R.neckG.rotation.x+=.22*S+.12*T-.4*L+.2*Mn;   // la tête reste vers l'avant
 if(D>.01){const sd=clamp(R.sd||0,-1,1),fw=clamp(R.fw||0,-1,1);R.root.rotation.z=-sd*.42*D;R.root.rotation.x=-fw*.28*D;}
 // --- arme et bras ---
 _anGp.copy(R.gunMount.position);_anGq.copy(R.gunMount.quaternion);
 const mix=(P0,Q0,k)=>{if(k<=.001)return;_anGp.lerp(P0,k);_anGq.slerp(Q0,k);};
 const bob=s(ph*2)*.02;
 if(S>.01){AN_SPR_P.y=.13+bob;mix(AN_SPR_P,AN_SPR_Q,S);}
 if(T>.01){AN_TAC_P.y=.36+bob*.6;mix(AN_TAC_P,AN_TAC_Q,T);}
 mix(AN_SLD_P,AN_SLD_Q,L);mix(AN_MNT_P,AN_MNT_Q,Mn);
 R.gunMount.position.copy(_anGp);R.gunMount.quaternion.copy(_anGq);
 R.gunMount.visible=K<.5;
 if(R.gunU)updateArmsIK(R,_anGp,_anGq,1,0);
 // bras libres
 if(T>.3&&!K){_anL.set(-.24,.12+s(ph)*.08,-.06-s(ph)*.26);anArmTo(R,'L',_anL);}
 if(L>.3&&!K){
  // main gauche qui frotte le sol, sur le côté et un peu derrière
  R.root.updateMatrixWorld(true);_anW.set(-.42,.04,.18);R.root.localToWorld(_anW);sp.worldToLocal(_anW);
  _anL.copy(_anW);if(_anL.distanceTo(R.arm.L.S)>.55){_anL.sub(R.arm.L.S).setLength(.55).add(R.arm.L.S);}anArmTo(R,'L',_anL);
 }
 if(Mn>.3){_anL.set(-.22,.72,-.36);_anR.set(.22,.72,-.36);anArmTo(R,'L',_anL);anArmTo(R,'R',_anR);}
 // atout : bouteille à la bouche (Zombies)
 if(K>.01)anDrink3P(R,e,K,t);else if(R.btl)R.btl.visible=false;
 // --- effets : poussière de glissade, traînée d'esquive, foulées de sprint ---
 w.fxT-=dt;
 const px=R.root.position.x,pz=R.root.position.z;
 if(L>.5&&w.fxT<=0){w.fxT=.045;fxDust(px-Math.sin(R.vyaw||st.yaw)*.4,y+.04,pz-Math.cos(R.vyaw||st.yaw)*.4,2,.14);}
 if(D>.4&&w.fxT<=0){w.fxT=.03;const L2=Math.hypot(e.vx||0,e.vz||0)||1;for(let i=0;i<2;i++)anStreak(px+rand(-.25,.25),y+rand(.5,1.6),pz+rand(-.25,.25),(e.vx||0)/L2,(e.vz||0)/L2,rand(.6,1.2));}
 if(S+T>.6&&st.onGround){const sg=s(ph)>0;if(sg!==w.stepS){w.stepS=sg;if(Math.random()<.5)fxDust(px,y+.03,pz,1,.08);}}
};
const _anSync=syncRigs;
syncRigs=function(dt,t){_anSync(dt,t);anFxUpdate(dt);};
