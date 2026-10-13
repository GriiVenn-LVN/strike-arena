/* =====================================================================
   BOUCLE PRINCIPALE
   ===================================================================== */
function update(dt){
 G.t+=dt;
 if(G.netClient&&NET.role==='client'){updatePlayer(dt);netClientTick(dt);updateNades(dt);immersionUpdate(dt);rpRecord(dt);rpUpdate(dt);G.shake=Math.max(0,G.shake-dt*1.6);G.fall=Math.max(0,G.fall-dt*3);return;}
 if(G.state==='cine'){updateCine(dt,G.t);return;}
 const dm=isDM();
 if(G.state==='freeze'){
  G.timer-=dt;
  if(G.timer<=0){G.state='live';G.timer=dm?0:G.roundT;if(!dm){uiBanner('C\'EST PARTI !','',1000);closeBuy(false);}else uiBanner('GO !','',900);sfx('round');}
 }else if(G.state==='live'){
  if(dm){
   G.timeLeft-=dt;if(G.timeLeft<=0)timeUpDM();
   for(const e of ents){if(!e.alive&&G.state==='live'){e.respT-=dt;if(e.respT<=0)respawn(e);}}
  }else{
   G.timer-=dt;
   if(BM.state==='planted'){
    BM.timer-=dt;BM.beep-=dt;
    if(BM.beep<=0){BM.beep=clamp(BM.timer/BOMB_T,.12,1)*.9;sfx('beep',BM.x,BM.z,1.1);if(BM.mesh){const sc=BM.mesh.userData.scr;sc.scale.x=.18;sc.visible=true;setTimeout(()=>{sc.visible=false;},120);}}
    if(BM.timer<=0)explode();
   }else if(G.timer<=0)endRound(1,'Temps écoulé');
  }
 }else if(G.state==='end'){G.endT-=dt;if(G.endT<=0)afterEnd();}
 if(G.mode==='bomb'&&G.state==='live'){
  if(BM.state==='dropped'){let best=null,bd=1e9;for(const e of ents){if(e.isPlayer||!e.alive||e.team!==0)continue;const d=Math.hypot(e.x-BM.x,e.z-BM.z);if(d<bd){bd=d;best=e;}}G.fetchId=best?best.id:-1;}
  if(BM.state==='planted'){let best=null,bd=1e9;for(const e of ents){if(e.isPlayer||!e.alive||e.team!==1)continue;const d=Math.hypot(e.x-BM.x,e.z-BM.z);if(d<bd){bd=d;best=e;}}G.defuserId=best?best.id:-1;}
  if(P.alive&&P.team===0&&BM.state==='dropped'&&Math.hypot(BM.x-P.x,BM.z-P.z)<1.4){BM.state='carried';BM.carrier=P.id;}
 }
 updatePlayer(dt);
 for(const e of ents.slice())if(!e.isPlayer){if(e.remote)netEntUpdate(e,dt);else if(e.zombie)zombieUpdate(e,dt);else if(!e.dummy&&!e.downed)botUpdate(e,dt);}
 variantUpdate(dt,G.t);agentUpdate(dt);pumpkinUpdate(dt);immersionUpdate(dt);tutUpdate(dt);zUpdate(dt);
 updateNades(dt);updatePickups(dt,G.t);updateSpotting(dt);
 G.shake=Math.max(0,G.shake-dt*1.6);G.fall=Math.max(0,G.fall-dt*3);
 rpRecord(dt);rpUpdate(dt);
 if(NET.role==='host')netHostTick(dt);
}
const menuCam={a:0};
function placeCamera(dt,t){
 if(G.state==='cine'&&CINE.on)return;
 if(!G.running&&G.state!=='over'||!P){
  menuCam.a+=dt*.05;const a=menuCam.a,R=58;
  camera.position.set(40+Math.cos(a)*R,26+Math.sin(t*.2)*3,40+Math.sin(a)*R);camera.lookAt(40,2,40);camera.fov=58;camera.updateProjectionMatrix();
  lis.x=40;lis.z=40;lis.yaw=0;return;
 }
 const sp=P.alive?null:specTarget(),src=sp||P;
 if(!P.alive&&!sp){const a=t*.4;camera.position.set(P.x+Math.cos(a)*3.2,P.y+2.4,P.z+Math.sin(a)*3.2);camera.lookAt(P.x,P.y+.5,P.z);camera.fov=cfg.fov;camera.updateProjectionMatrix();lis.x=P.x;lis.z=P.z;lis.yaw=0;return;}
 if(P.alive&&P.emote){const a=P.yaw+Math.PI+Math.sin(P.emote.t*.7)*.5+P.emote.t*.35,d=2.9;camera.position.set(P.x+Math.sin(a)*d*-1,P.y+1.7,P.z+Math.cos(a)*d*-1);camera.lookAt(P.x,P.y+1.15,P.z);camera.fov=52;camera.updateProjectionMatrix();lis.x=P.x;lis.z=P.z;lis.yaw=P.yaw;return;}
 const eye=src.isPlayer?src.eyeH:eyeOf(src);
 lis.x=src.x;lis.z=src.z;lis.yaw=src.yaw;
 let yaw=src.yaw+(src.isPlayer?P.punchY*RAD:0),pit=src.pitch+(src.isPlayer?P.punchP*RAD:0);
 let roll=0;
 if(G.shake>0){const s=G.shake*cfg.shakeS;yaw+=rand(-1,1)*s*.025;pit+=rand(-1,1)*s*.025;roll+=rand(-1,1)*s*.02;}
 if(src.isPlayer){roll+=-clamp((P.vx*Math.cos(P.yaw)-P.vz*Math.sin(P.yaw))/RUN,-1,1)*.012*P.speed/5;if(P.mv)roll+=P.mv.w.sld*.055;}
 const bobY=src.isPlayer&&P.onGround&&cfg.bob?Math.sin(bobT*2)*.014*clamp(P.speed/5,0,1):0;
 camera.position.set(src.x,src.y+eye+bobY-G.fall*.1,src.z);
 camera.rotation.set(pit,yaw,roll);
 const w=curW(src);let zoom=1;
 if(src.isPlayer){const az=attMods(P,curWi(P).k).zoom,zf=w.zoom?w.zoom:az||ADS_ZOOM[w.cat]||1.1;zoom=lerp(1,zf,P.ads);}
 const mw=src.isPlayer&&P.mv?P.mv.w:null,tf=cfg.fov/zoom*(mw?1+mw.spr*.06+mw.tac*.1+mw.sld*.07:1);camera.fov+=(tf-camera.fov)*Math.min(1,dt*18);camera.updateProjectionMatrix();
}
function render(dt,t){
 for(const f of worldAnim)f(t);
 if(RP.on&&RP.wait<=0&&G.running&&!G.paused){rpRender(dt,t);return;}
 placeCamera(dt,t);
 if(skyG)skyG.position.copy(camera.position);
 if(G.running||G.state==='over'){if(P){syncRigs(dt,t);if(P.alive)vmUpdate(dt,t);}}
 updateFX(dt,t);
 renderer.clear();renderer.render(scene,camera);
 if(G.running&&P&&P.alive&&VM.root.visible&&G.state!=='cine'&&!P.emote){renderer.clearDepth();renderer.render(vmScene,vmCam);}
 if(G.running&&P){updateHUD(dt,t);radarT2-=dt;if(radarT2<=0){radarT2=.05;drawRadar();}}
}
let radarT2=0;
let last=performance.now()/1000;
function frame(){
 requestAnimationFrame(frame);
 const now=performance.now()/1000;let dt=Math.min(.05,now-last);last=now;
 if(G.running&&!G.paused)update(dt);else if(!G.running)immersionUpdate(dt);
 if(pvOn&&pvR&&pvPivot&&!G.running){if(!pvHold)pvPivot.rotation.y+=dt*.7*pvSpin;pvR.render(pvS,pvC);}
 if(lkOn&&!G.running)lkFrame(dt,now);
 render(G.paused?0:dt,now);
}
/* ---------- démarrage avec écran de chargement ---------- */
(function boot(){
 const bar=$('lbar'),txt=$('ltxt');
 const steps=[
  ['MONDE',()=>{resize();initFX();previewMapId=cfg.map;buildWorld(cfg.map);buildRadarMap();}],
  ['ARMES',()=>{initSoldierGeos();for(const k in W)gunTemplate(k);}],
  ['INTERFACE',()=>{buildAllMenu();setVolume(cfg.vol);buildMetaUI();menuNavInit();}],
  ['PRÊT',()=>{}]
 ];
 let i=0;
 (function next(){
  if(i>=steps.length){$('loading').style.opacity=0;setTimeout(()=>$('loading').style.display='none',650);requestAnimationFrame(frame);return;}
  txt.textContent='CHARGEMENT — '+steps[i][0];bar.style.width=((i+1)/steps.length*100)+'%';
  setTimeout(()=>{try{steps[i][1]();}catch(e){console.error(e);txt.textContent='ERREUR : '+e.message;}i++;next();},40);
 })();
})();
window.__dbg={charFactory,zSpawn,ZD,zDoorCandidates,zReach,zCount,zSetupDoors,NET,netHost,netJoin,RP,rpStart,endRound,shoot,giveWeapon,ZB,zApplyDrop,zDrop,zRollBox,PERKS,VM,vmCam,TUT,startTutorial,drawAccessTab,subtitle,applyAccess,immersionUpdate,applyAtmosphere,RAIN,MUS,barrelHit,BAR,podiumHTML,announce,progressMatch,bpClaim,bpBuy,ACH,PUMPK,drawProgressTab,doSpray,drawExtrasTab,MINES,placeMine,mineRayHit,update,Z,KO,BRZ,TR,pickups:()=>pickups,lkSetOut:(i)=>{lkTab="outfit";lkOut=i;if(lk.r&&lk.outShown!==i)lkRig(i);buildLocker();},startEmote,CINE,BXS,bxLoop,get PROF(){return PROF},startBoxOpen,startCine,DANCES,lkSetSel:(i)=>{lkSel=i;lk.t=0;buildLocker();},G,BM,get P(){return P},get ents(){return ents},cfg,startMatch,buildWorld,mapReport,mapAscii,camera,scene,renderer,W,MAPS,MODES,get MAP(){return MAP},toMenu,groundH,findPath,rayWall,losClear,weaponIcon,keys};
