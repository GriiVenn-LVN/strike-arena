/* =====================================================================
   KILL-CAM (façon Call of Duty)
   Quand tu meurs dans un mode avec réapparition (MàM, Capture, Domination,
   Infecté, Course aux armes…) ou en Bataille royale, on rejoue les
   dernières secondes vues par les yeux de celui qui t'a tué (arme et bras
   en vue subjective, comme le spectateur).
   ESPACE ou clic pour passer. Réglage : Réglages › Plus d'options.
   Réutilise le moteur de rediffusion de 6A_replay.js.
   ===================================================================== */
cfg.killcam=cfg.killcam===undefined?1:cfg.killcam;
const KCAM={on:false,respT:0,zoom:1,mk:null,gv:null,gl:null};
const kcMode=()=>G.mode!=='bomb'&&G.variant!=='zombies'&&G.variant!=='train';
function kcStart(){
 const k=RP.kill;
 if(!cfg.killcam||!kcMode()||G.netClient||NET.role||RP.on||POTG.playing)return;
 if(!k||k.v!==P||!k.att||k.att===P||!k.att.rig||!RP.buf.length)return;
 RP.t0=Math.max(RP.buf[0].t,k.t-2.2);RP.t1=k.t+.6;
 if(k.t-RP.t0<.6)return;
 KCAM.on=true;RP.on=true;KCAM.px=null;KCAM.rl=0;KCAM.zoom=1;RP.wait=.5;RP.rt=RP.t0;RP.prev=RP.t0;RP.cam=null;RP.orbit=0;RP.blood=false;RP.hold=.6;
 // la réapparition attend la fin de la kill-cam
 KCAM.respT=P.respT;if(isFinite(P.respT))P.respT=99;
}
function kcFinish(){
 KCAM.on=false;KCAM.px=null;
 if(P&&!P.alive&&isFinite(KCAM.respT)&&P.respT>KCAM.respT)P.respT=Math.min(KCAM.respT,.4);
 const tag=RP.el&&RP.el.querySelector('.tag');if(tag)tag.innerHTML='<i></i>REDIFFUSION · DERNIÈRE ÉLIMINATION';
}
const _killEntKc=killEnt;
killEnt=function(v,att,w,hs){
 const was=v.alive;_killEntKc(v,att,w,hs);
 if(was&&!v.alive&&v===P&&G.state==='live')kcStart();
};
// pendant la kill-cam, les autres éliminations ne remplacent pas celle qu'on rejoue
const _rpKillKc=rpKill;
rpKill=function(att,v,w,hs){if(KCAM.on)return;_rpKillKc(att,v,w,hs);};
const _rpEndKc=rpEnd;
rpEnd=function(){
 if(!KCAM.on)return _rpEndKc();
 RP.on=false;rpOverlay(false);kcFinish();
 for(const e of ents)if(e.rig&&!e.alive)e.rig.dieT=9; // corps déjà au sol après la rediffusion
};
const _rpOverlayKc=rpOverlay;
rpOverlay=function(on,prog){
 _rpOverlayKc(on,prog);
 if(!on){if(KCAM.mk)KCAM.mk.style.display='none';kcGhostClear();}
 if(on&&KCAM.on){const tag=RP.el.querySelector('.tag');if(tag&&!tag.dataset.kc){tag.innerHTML='<i></i>KILL-CAM';}}
};
// fin de partie ou retour au menu : on coupe proprement
const _matchOverKc=matchOver;
matchOver=function(){if(KCAM.on){RP.on=false;rpOverlay(false);kcFinish();}KCAM.px=null;KCAM.rl=0;KCAM.zoom=1;return _matchOverKc();};
const _endDMKc=endDM;
endDM=function(){if(KCAM.on){RP.on=false;rpOverlay(false);kcFinish();}return _endDMKc();};
addEventListener('mousedown',()=>{if(KCAM.on&&RP.on&&RP.wait<=0)rpEnd();});
/* ---------- vue subjective du tueur ----------
   Sert à toutes les rediffusions : kill-cam, dernière élimination de manche (Compétitif)
   et meilleure action de fin de match. */
const _rpStartKc=rpStart;
rpStart=function(){KCAM.px=null;KCAM.rl=0;KCAM.zoom=1;return _rpStartKc();};
// double du tueur : hérite de son équipement (tenue, accessoires) mais prend l'état enregistré
function kcProxy(s){
 const k=RP.kill;let p=KCAM.px;
 if(!p||p._src!==k.att){p=KCAM.px=Object.create(k.att);p._src=k.att;p.cur=0;p.mv=null;p.emote=null;p.alive=true;p.ads=0;p.vy=0;p.downed=false;p.wp=null;}
 if(!p.wp||p.wp[0].k!==s.wk)p.wp=[{k:s.wk,mag:s.mag,res:99,pap:false}];
 p.wp[0].mag=s.mag;
 p.x=s._x;p.y=s._y;p.z=s._z;p.yaw=s._yaw;p.pitch=s._pitch;p.speed=s.speed||0;p.vx=s.vx||0;p.vz=s.vz||0;
 p.onGround=s.onGround!==false;p.crouch=!!s.crouch;p.eyeH=p.crouch?1.12:1.6;p.reload=s.reload||0;p.reloadMax=s.reloadMax||0;
 return p;
}
function rpFPCam(ka,dt){
 const k=RP.kill,p=kcProxy(ka);
 if(k.att.rig)k.att.rig.root.visible=false;   // sinon on verrait l'intérieur de sa tête
 camera.position.set(p.x,p.y+eyeOf(p),p.z);camera.rotation.set(p.pitch,p.yaw,0);
 // la cible : zoom selon la distance quand le tueur la vise (sinon, à 25 m, elle ne fait que quelques pixels),
 // silhouette rouge seulement derrière les murs et repère au-dessus de sa tête
 camera.updateMatrixWorld();const vr=k.v.rig&&k.v.rig.root,tz=kcTargetZoom(vr);
 p.ads=0;p.scoped=false;   // arme à la hanche : en visée, le viseur cacherait la cible
 KCAM.zoom+=(tz-KCAM.zoom)*Math.min(1,dt*5);
 camera.fov+=(cfg.fov/KCAM.zoom-camera.fov)*Math.min(1,dt*18);camera.updateProjectionMatrix();
 kcGhost(k.v);kcMarker(vr,k.v);
 lis.x=p.x;lis.z=p.z;lis.yaw=p.yaw;
 // tirs et recharges rejoués : recul et animation de l'arme
 const w=W[ka.wk];
 if(w)for(const tr of RP.tracers)if(tr.t>RP.prev&&tr.t<=RP.rt&&Math.hypot(tr.x0-p.x,tr.z0-p.z)<1.6){vmFire(w);break;}
 if(w&&p.reload>0&&KCAM.rl<=0&&VM.ent===p)vmReload(w);
 KCAM.rl=p.reload;
}
function kcTargetZoom(vr){
 if(!vr||!vr.visible)return 1;
 _kcv.set(vr.position.x,vr.position.y+1.2,vr.position.z).sub(camera.position);
 const d=_kcv.length();if(d<1)return 1;
 camera.getWorldDirection(_kcf);
 if(_kcv.dot(_kcf)/d<.94)return 1;            // cible hors de la ligne de visée (> 20°) : vue normale
 return clamp(d/7,1,2.6);
}
// repère au-dessus de la cible : chevron rouge et nom, collé à sa tête à l'écran
function kcMarker(vr,v){
 let m=KCAM.mk;
 if(!m){m=KCAM.mk=document.createElement('div');m.id='kcTgt';m.innerHTML='<span></span><i></i>';document.body.appendChild(m);
  const st=document.createElement('style');st.textContent='#kcTgt{position:fixed;z-index:15;pointer-events:none;transform:translate(-50%,-100%);text-align:center;font-family:Bahnschrift,Arial;display:none}'+
   '#kcTgt span{display:block;font-size:.8rem;font-weight:900;letter-spacing:2px;color:#fff;background:#ff3b4bcc;padding:2px 8px;border-radius:3px;white-space:nowrap;text-shadow:0 1px 2px #000}'+
   '#kcTgt i{display:block;width:0;height:0;margin:3px auto 0;border-left:9px solid transparent;border-right:9px solid transparent;border-top:12px solid #ff3b4b;filter:drop-shadow(0 0 3px #000);animation:kcB .7s infinite alternate}@keyframes kcB{to{transform:translateY(4px)}}';
  document.head.appendChild(st);}
 if(!vr||!vr.visible){m.style.display='none';return;}
 _kcv.set(vr.position.x,vr.position.y+2.05,vr.position.z).project(camera);
 if(_kcv.z>1||_kcv.z<-1){m.style.display='none';return;}
 const x=clamp((_kcv.x*.5+.5)*innerWidth,20,innerWidth-20),y=clamp((-_kcv.y*.5+.5)*innerHeight,40,innerHeight-20);
 m.style.display='block';m.style.left=x+'px';m.style.top=y+'px';
 if(m._v!==v){m._v=v;m.firstChild.textContent=v.name;}
}
// silhouette « rayons X » de la cible : copie de ses pièces, rouge translucide, dessinée seulement là où un mur la cache
// (à découvert, on voit son vrai modèle jouer : déplacements, tirs, recharges, chute rejoués depuis l'enregistrement)
const KC_GM={};
function kcGhostMat(skin){return KC_GM[skin?1:0]||(KC_GM[skin?1:0]=new THREE.MeshBasicMaterial({color:0xff3040,transparent:true,opacity:.45,depthTest:true,depthFunc:THREE.GreaterDepth,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-2,polygonOffsetUnits:-8,skinning:skin,toneMapped:false,fog:false}));}
function kcGhost(v){
 if(KCAM.gv===v&&KCAM.gr===(v&&v.rig))return;
 kcGhostClear();if(!v||!v.rig)return;
 const list=[],all=[];v.rig.root.traverse(o=>{if(o.isMesh&&!o.userData.isOl&&!o.userData.isKcG&&o.geometry)all.push(o);});
 // le corps seul : le modèle animé s'il existe (sinon les pièces du soldat), sans l'arme, l'ombre au sol ni les accessoires larges
 const skin=all.filter(o=>o.isSkinnedMesh);
 const meshes=skin.length?skin:all.filter(o=>{if(!o.geometry.boundingSphere)o.geometry.computeBoundingSphere();return o.geometry.boundingSphere.radius<.6;});
 for(const m of meshes){
  let g;
  if(m.isSkinnedMesh){g=new THREE.SkinnedMesh(m.geometry,kcGhostMat(true));g.bind(m.skeleton,m.bindMatrix);g.frustumCulled=false;}
  else g=new THREE.Mesh(m.geometry,kcGhostMat(false));
  g.userData.isKcG=true;g.renderOrder=999;m.add(g);list.push(g);
 }
 KCAM.gv=v;KCAM.gr=v.rig;KCAM.gl=list;
}
function kcGhostClear(){if(KCAM.gl)for(const g of KCAM.gl)if(g.parent)g.parent.remove(g);KCAM.gl=null;KCAM.gv=null;}
const _kcv=new THREE.Vector3(),_kcf=new THREE.Vector3();
function rpFPView(dt,t){
 const p=KCAM.px;if(!p||!W[p.wp[0].k])return;
 vmUpdate(dt,t,p);
 if(VM.root.visible){renderer.clearDepth();renderer.render(vmScene,vmCam);}
}
// réglage
const _buildOptsKc=buildOpts;
buildOpts=function(){
 _buildOptsKc();
 let g=$('gKillcam');
 if(!g){
  const anchor=$('cCine')&&$('cCine').closest('.grp');if(!anchor)return;
  g=document.createElement('div');g.className='grp';g.id='gKillcam';g.innerHTML='<label>Kill-cam</label><div class="chips" id="cKillcam"></div><small>Rejoue ta mort par les yeux du tueur (modes avec réapparition).</small>';
  anchor.parentNode.insertBefore(g,anchor.nextSibling);
 }
 chipsRow('cKillcam',[['Activée',1],['Désactivée',0]],()=>cfg.killcam?1:0,v=>cfg.killcam=v,buildOpts);
};
