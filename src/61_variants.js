/* =====================================================================
   VARIANTES DE MODES : Désamorçage rapide, Capture de zone, Zombies
   (coop), Bataille royale, Entraînement
   ===================================================================== */
const VARIANT_BASE={rapid:'bomb',koth:'tdm',zombies:'tdm',br:'ffa',train:'ffa'};
function limitOf(mode){const d=MODES[mode].limits||[];const v=({bomb:cfg.rounds,tdm:cfg.tdmKills,ffa:cfg.ffaKills})[mode]||(cfg.lim&&cfg.lim[mode]);return d.includes(v)?v:(d[Math.floor(d.length/2)]||0);}
G.variant='bomb';G.roundT=100;G.freezeT=12;
const Z={wave:0,queue:0,state:'wait',breakT:0,spawnT:0,nextId:100,bonus:0};
const KO={idx:0,owner:-1,contested:false,t:0,ring:null,pts:[0,0],holdT:0,moveT:0};
const BRZ={phase:0,t:0,r:62,from:62,to:62,cx:40,cz:40,tx:40,tz:40,ring:null,alive:0,placed:0,wait:0,dmg:2};
const TR={score:0,streak:0,best:0,t:0,dummies:[],started:false,hits:0};

/* ---------- démarrage de partie (remplace l'ancienne version) ---------- */
function startMatch(){
 initAudio();initFX();
 G.variant=cfg.mode;G.mode=VARIANT_BASE[cfg.mode]||cfg.mode;resetMatchStats();
 G.roundT=G.variant==='rapid'?45:100;G.freezeT=G.variant==='rapid'?10:20;
 for(const k in cfg.skins)if(!ownsSkin(k,cfg.skins[k]))cfg.skins[k]=0;
 for(const e of ents)if(e.rig)scene.remove(e.rig.root);
 for(const p of pickups)scene.remove(p.mesh);pickups=[];variantCleanup();
 clearNades();ents=[];G.score=[0,0];G.loss=[0,0];G.round=0;G.t=0;G.over=false;G.final=false;G.winner=null;G.state='freeze';
 G.timeLeft=({koth:600,zombies:1e9,br:1e9,train:60}[G.variant])||DM_TIME;
 buildWorld(cfg.map);barrelClear();applyAtmosphere();
 const names=shuffle(NAMES.slice());let idx=0;
 const m=MODE(),v=G.variant;
 if(m.team){
  let pt=cfg.side==='rnd'?(Math.random()<.5?0:1):(cfg.side==='t'?0:1);
  if(v==='zombies')pt=0;
  P=newEnt(cfg.name||'Vous',pt,true,idx++);ents.push(P);
  for(let i=0;i<cfg.size-1;i++)ents.push(newEnt(names.pop(),pt,false,idx++));
  if(v!=='zombies')for(let i=0;i<cfg.size;i++)ents.push(newEnt(names.pop(),1-pt,false,idx++));
  G.limit=G.mode==='bomb'?limitOf(cfg.mode==='rapid'?'rapid':'bomb'):v==='koth'?limitOf('koth'):v==='zombies'?limitOf('zombies'):limitOf('tdm');
 }else{
  P=newEnt(cfg.name||'Vous',0,true,idx++);ents.push(P);
  if(v!=='train')for(let i=0;i<cfg.ffa-1;i++)ents.push(newEnt(names.pop(),i+1,false,idx++));
  G.limit=G.mode==='ffa'?limitOf('ffa'):GG_LADDER.length;
 }
 ents.forEach((e,i)=>{e.id=i;e.money=cfg.eco&&G.mode==='bomb'&&v!=='rapid'?800:16000;e.ggLevel=0;giveWeapon(e,e.team===0?'glock':'usp');});
 for(const e of ents)attachRig(e);
 agentCleanup();clearSprays();rpReset();assignAgents();spawnPumpkins();
 G.running=true;
 variantInit();
 if(G.mode==='bomb'){resetRound();}
 else{
  G.state='freeze';G.timer=v==='br'?6:3;
  for(const e of ents)respawn(e);
  variantPostSpawn();
  if(P.rig)P.rig.root.visible=false;
  uiBanner(MODES[v].n.toUpperCase(),variantSub(),2400);sfx('round');
 }
 uiMatchStart();
 if(MODE().team&&cfg.cine!==0&&v!=='train')startCine();
}
function variantSub(){
 const v=G.variant;
 return v==='gg'?'Termine avec le couteau':v==='koth'?'Contrôle la zone — premier à '+G.limit:v==='zombies'?'Survis à '+(G.limit>=99?'l\'infini':G.limit+' manches'):v==='br'?'Ramasse une arme, reste dans la zone':v==='train'?'Touche un maximum de cibles en 60 s':G.mode==='gg'?'Termine avec le couteau':'Premier à '+G.limit;
}
/* ---------- initialisation / nettoyage ---------- */
function variantCleanup(){
 zCleanup();
 if(KO.ring){scene.remove(KO.ring);KO.ring=null;}
 if(BRZ.ring){scene.remove(BRZ.ring);BRZ.ring=null;}
}
function ringMesh(col,height){
 const g=new THREE.Group();
 const wall=new THREE.Mesh(new THREE.CylinderGeometry(1,1,height,64,1,true),new THREE.MeshBasicMaterial({color:col,transparent:true,opacity:.2,side:THREE.DoubleSide,blending:THREE.AdditiveBlending,depthWrite:false,toneMapped:false}));wall.position.y=height/2;g.add(wall);
 const ring=new THREE.Mesh(new THREE.RingGeometry(.97,1,64),new THREE.MeshBasicMaterial({color:col,transparent:true,opacity:.9,side:THREE.DoubleSide,depthWrite:false,toneMapped:false}));ring.rotation.x=-Math.PI/2;ring.position.y=.12;g.add(ring);
 const disc=new THREE.Mesh(new THREE.CircleGeometry(1,64),new THREE.MeshBasicMaterial({color:col,transparent:true,opacity:.1,side:THREE.DoubleSide,depthWrite:false,toneMapped:false}));disc.rotation.x=-Math.PI/2;disc.position.y=.1;g.add(disc);
 g.userData={wall,ring,disc};scene.add(g);return g;
}
function ringColor(g,col){const u=g.userData;for(const m of [u.wall,u.ring,u.disc])m.material.color.set(col);}
function variantInit(){
 const v=G.variant;
 if(v==='koth'){KO.idx=0;KO.owner=-1;KO.pts=[0,0];KO.moveT=60;KO.holdT=0;KO.ring=ringMesh(0xffffff,9);kothPlace();}
 if(v==='zombies'){Z.wave=0;Z.queue=0;Z.state='wait';Z.breakT=6;Z.nextId=100;}
 if(v==='br'){brInit();}
 if(v==='train'){trInit();}
 if(v==='rapid'){for(const e of ents)e.bought=true;}
 if(MAP.pickups&&G.mode!=='bomb'&&v!=='br'&&v!=='train'&&v!=='zombies')setupPickups();
 else if(v==='zombies')zSetup();
}
function variantPostSpawn(){
 const v=G.variant;
 if(v==='br'){for(const e of ents){e.wp.p=null;e.wp.s=null;e.cur='k';e.armor=0;e.shield=0;e.nade={f:0,fl:0,sm:0};}}
 if(v==='train'){trPlaceDummies();P.wp.p&&(P.wp.p.res=999);}
 if(v==='zombies'){for(const e of ents){e.nade={f:2,fl:0,sm:0,mn:1};if(e.isPlayer){e.wp.p=null;giveWeapon(e,'p250');e.cur='s';}e.pts=500;e.perks={};}}
}
function variantRespawn(v){ // délai de réapparition (Infinity = jamais)
 const g=G.variant;
 if(g==='zombies'||g==='br')return Infinity;
 if(g==='train'&&v.dummy)return Infinity;
 return MODE().respawn;
}
const NOKILLSCORE={koth:1,zombies:1,br:1,train:1};
function variantKill(att,v,w,hs){
 extrasKill(att,w);immKill(att,v,w,hs);
 const g=G.variant;
 if(g==='train'&&v.dummy){
  TR.hits++;TR.streak++;TR.best=Math.max(TR.best,TR.streak);TR.score+=(hs?150:100)+Math.min(100,TR.streak*5);v.popT=rand(.7,1.4);
  uiToast((hs?'TÊTE ! ':'')+'+'+((hs?150:100)+Math.min(100,TR.streak*5)));
 }
 if(g==='zombies'){if(v.zombie)v.corpseT=4;zKillHook(att,v,w,hs);}
 if(g==='br'){BRZ.alive=ents.filter(e=>e.alive).length;}
}
function variantTimeUp(){
 const g=G.variant;
 if(g==='koth'){G.winner=KO.pts[0]===KO.pts[1]?-1:KO.pts[0]>KO.pts[1]?0:1;G.score=KO.pts.slice();if(G.winner===-1){G.state='end';G.endT=4.5;G.final=true;uiBanner('ÉGALITÉ','Temps écoulé',4000);return true;}endDM();return true;}
 if(g==='train'){trEnd();return true;}
 if(g==='zombies'||g==='br')return true;
 return false;
}
function variantCheckEnd(){return false;}
/* ---------- boucle ---------- */
function variantUpdate(dt,t){
 const v=G.variant;
 if(G.state!=='live'&&G.state!=='freeze')return;
 if(v==='koth')kothUpdate(dt,t);
 else if(v==='zombies')zombieWaves(dt);
 else if(v==='br')brUpdate(dt,t);
 else if(v==='train')trUpdate(dt);
}
/* ---------- CAPTURE DE ZONE ---------- */
function kothZone(){const z=MAP.koth[KO.idx%MAP.koth.length];return {x:cc(z[0]),z:cc(z[1]),r:z[2]*1.45,y:groundH(cc(z[0]),cc(z[1])),n:z[3]||''};}
function kothPlace(){
 const z=kothZone();KO.ring.position.set(z.x,z.y,z.z);KO.ring.scale.set(z.r,1,z.r);KO.owner=-1;KO.holdT=0;
}
function kothUpdate(dt,t){
 const z=kothZone(),r=KO.ring;
 r.userData.ring.rotation.z+=dt*.5;r.userData.wall.material.opacity=.14+Math.sin(t*3)*.05;
 if(G.state!=='live')return;
 KO.moveT-=dt;if(KO.moveT<=0){KO.idx++;KO.moveT=75;kothPlace();uiToast('La zone se déplace !');sfx('alarm');}
 let c=[0,0];for(const e of ents){if(e.alive&&Math.hypot(e.x-z.x,e.z-z.z)<z.r&&Math.abs(e.y-z.y)<3)c[e.team]++;}
 KO.contested=c[0]>0&&c[1]>0;
 let owner=-1;if(c[0]>0&&c[1]===0)owner=0;else if(c[1]>0&&c[0]===0)owner=1;
 if(owner!==KO.owner){KO.owner=owner;ringColor(r,owner===-1?(KO.contested?0xffd23a:0xffffff):[0xff7a4a,0x4aa3ff][owner]);}
 else if(KO.contested&&owner===-1)ringColor(r,0xffd23a);
 if(owner>=0){KO.holdT+=dt;if(KO.holdT>=1){KO.holdT-=1;KO.pts[owner]++;G.score=KO.pts.slice();checkDMEnd();}}
}
/* ---------- ZOMBIES ---------- */
function zStartWave(){
 Z.wave++;Z.queue=7+Z.wave*5;Z.state='spawn';Z.spawnT=1.2;
 uiBanner('MANCHE '+Z.wave,Z.wave===1?'Gagne des points, achète des armes aux murs, tente la boîte mystère':'Ils sont plus nombreux…',2600,'#d0202a');sfx('alarm');
 const humans=ents.filter(e=>e.team===0);
 for(const h of humans){
  if(!h.alive){const f=humans.find(x=>x.alive&&x!==h);const c=f?[Math.floor(f.x/S),Math.floor(f.z/S)]:MAP.spawnCT[0];const n=nearestFree(c[0]+1,c[1]);respawn(h);if(h.isPlayer){h.wp.p=null;giveWeapon(h,'p250');h.cur='s';}h.perks={};h.x=cc(n[0]);h.z=cc(n[1]);h.y=groundH(h.x,h.z);h.hp=60;}
  else h.hp=Math.min(100,h.hp+35);
  h.nade.f=Math.max(2,h.nade.f||0);if(!h.perks)h.perks={};if(h.isPlayer)h.invuln=1.5;
 }
 zOnWave();
}
function zSpawn(){
 const humans=ents.filter(e=>e.alive&&e.team===0);if(!humans.length)return;
 const cand=MAP.roam.concat(MAP.spawnDM);let best=null,bd=-1;
 for(let i=0;i<8;i++){const c=pick(cand),x=cc(c[0]),z=cc(c[1]);let md=1e9;for(const h of humans)md=Math.min(md,Math.hypot(h.x-x,h.z-z));if(md>bd&&md>14){bd=md;best=c;}}
 if(!best)best=pick(cand);
 const r=Math.random(),w=Z.wave,type=(w>=4&&r<.07)?'tank':(r<Math.min(.7,(w-2)*.12))?'runner':'normal';
 const z=newEnt('Zombie',1,false,Z.nextId);z.id=Z.nextId++;z.zombie=true;z.ztype=type;z.col=0;z.tone='#7ba35a';
 z.hp=Math.round((type==='tank'?3:type==='runner'?.7:1)*(w<10?100+55*(w-1):595*Math.pow(1.08,w-9)));
 z.zspeed=(type==='runner'?5+Math.min(1,w*.05):type==='tank'?2.6:2.3+Math.min(1.6,w*.13));z.zdmg=type==='tank'?28:12+w;z.atkT=0;
 z.wp.p=null;z.wp.s=null;z.cur='k';z.x=cc(best[0]);z.z=cc(best[1]);z.y=groundH(z.x,z.z);z.alive=true;z.yaw=rand(0,TAU);z.diff=DIFFS[2];
 ents.push(z);attachRig(z);
 if(z.rig&&type==='tank')z.rig.root.scale.setScalar(1.3);
 if(z.rig&&type==='runner')z.rig.root.scale.setScalar(.92);
 fxDust(z.x,z.y+.1,z.z,6,.3);sfx('growl',z.x,z.z,.9);
}
function zombieWaves(dt){
 if(G.state!=='live')return;
 const humansAlive=ents.filter(e=>e.team===0&&e.alive).length;
 if(humansAlive===0&&!G.final){G.winner=1;endDM();return;}
 const zAlive=ents.filter(e=>e.zombie&&e.alive).length;
 if(Z.state==='wait'){Z.breakT-=dt;if(Z.breakT<=0)zStartWave();}
 else if(Z.state==='spawn'){
  Z.spawnT-=dt;
  if(Z.spawnT<=0&&Z.queue>0&&zAlive<Math.min(24,6+Z.wave*2)){zSpawn();Z.queue--;Z.spawnT=Math.max(.35,1.1-Z.wave*.06);}
  if(Z.queue<=0&&zAlive===0){
   if(Z.wave>=G.limit){G.winner=0;endDM();return;}
   Z.state='break';Z.breakT=9;uiBanner('MANCHE '+Z.wave+' TERMINÉE','La suivante arrive…',3000,'#d0202a');sfx('win');
  }
 }else if(Z.state==='break'){Z.breakT-=dt;if(Z.breakT<=0)zStartWave();}
 // nettoyage des cadavres
 for(let i=ents.length-1;i>=0;i--){const e=ents[i];if(e.zombie&&!e.alive){e.corpseT=(e.corpseT||4)-dt;if(e.corpseT<=0){if(e.rig)scene.remove(e.rig.root);ents.splice(i,1);}}}
}
function zombieUpdate(z,dt){
 if(!z.alive){return;}
 if(z.frozenT>0){z.target=null;botMove(z,0,0,dt);return;}
 let best=null,bd=1e9;
 for(const e of ents){if(!e.alive||e.team===z.team||e.invuln>0)continue;const d=Math.hypot(e.x-z.x,e.z-z.z);if(d<bd){bd=d;best=e;}}
 tickWeapon(z,dt);
 if(!best){z.speed=0;physics(z,dt);return;}
 z.target=best;z.atkT-=dt;
 const dx=best.x-z.x,dz=best.z-z.z,wy=Math.atan2(-dx,-dz);
 z.yaw+=clamp(angDiff(z.yaw,wy)*Math.min(1,dt*9),-dt*9,dt*9);
 if(bd<1.8){botMove(z,0,0,dt);if(z.atkT<=0){z.atkT=.85;z.fireAnim=1;hurt(best,z,{n:'Morsure',kill:15,hs:1,ap:.3,fo:999,fr:0},'b',1,z.zdmg);sfx('knifehit',z.x,z.z);}}
 else{
  if(bd<9&&losClear(z.x,z.y+1.2,z.z,best.x,best.y+1.2,best.z,true)&&Math.abs(best.y-z.y)<1.2)botMove(z,dx/bd*z.zspeed,dz/bd*z.zspeed,dt);
  else botGo(z,dt,best.x,best.z,z.zspeed);
 }
 if(Math.random()<dt*.15)sfx('growl',z.x,z.z,.6);
}
/* ---------- BATAILLE ROYALE ---------- */
const BR_PHASES=[{wait:45,shrink:30,r:44,dmg:2},{wait:30,shrink:25,r:26,dmg:4},{wait:25,shrink:20,r:12,dmg:7},{wait:15,shrink:20,r:0,dmg:12}];
function brInit(){
 BRZ.phase=0;BRZ.r=64;BRZ.from=64;BRZ.cx=40;BRZ.cz=40;BRZ.tx=40;BRZ.tz=40;BRZ.wait=BR_PHASES[0].wait;BRZ.state='wait';BRZ.dmg=2;
 BRZ.ring=ringMesh(0x35d6ff,14);BRZ.alive=ents.length;
 // butin
 const tiers=[['glock','usp','p250','fiveseven','deagle'],['mac10','mp9','ump','nova','sawedoff','galil','famas'],['ak','m4','sg553','aug','xm','p90','ssg','negev'],['awp','scar','m249']];
 const cells=[];for(let cz=2;cz<N-2;cz++)for(let cx=2;cx<N-2;cx++)if(G_TYPE[cz*N+cx]===0&&!G_RAMP[cz*N+cx])cells.push([cx,cz]);shuffle(cells);
 let placed=0;const taken=[];
 for(const c of cells){
  if(placed>=Math.max(26,ents.length*3))break;
  if(taken.some(t=>Math.hypot(t[0]-c[0],t[1]-c[1])<3.2))continue;
  taken.push(c);
  const dc=Math.hypot(c[0]-20,c[1]-20)/28,r=Math.random();
  let key=null,type='weapon';
  if(r<.7){const tr=r<.30?0:r<.52?1:r<.66?2:3;key=pick(tiers[Math.min(3,tr+(dc<.5&&Math.random()<.4?1:0))]);}
  else{type=pick(['armor','shield','health','ammo']);}
  addLoot(type,key,cc(c[0]),cc(c[1]));placed++;
 }
}
function addLoot(type,key,x,z){
 const p={type,key,x,z,t:0,on:true,temp:false,single:true,mesh:type==='weapon'?makeWeaponPickup(key,x,z):makePickup(type==='armor'?'shield':type,x,z)};pickups.push(p);
}
function makeWeaponPickup(key,x,z){
 const g=new THREE.Group();g.position.set(x,groundH(x,z)+.9,z);
 const gun=cloneGun(gunTemplate(key));gun.scale.setScalar(1.15);gun.rotation.y=Math.PI/2;g.add(gun);
 const q=['pistol','smg','shotgun','rifle','sniper','lmg'].indexOf(W[key].cat),col=[0x9aa6b8,0x4aa3ff,0x4aa3ff,0xb36bff,0xffb938,0xffb938][Math.max(0,q)];
 const glow=new THREE.Sprite(new THREE.SpriteMaterial({map:GLOW.cool,color:new THREE.Color(col),blending:THREE.AdditiveBlending,transparent:true,depthWrite:false,opacity:.75,toneMapped:false}));glow.scale.set(2.4,2.4,1);g.add(glow);
 const ring=new THREE.Mesh(new THREE.RingGeometry(.6,.7,24),new THREE.MeshBasicMaterial({color:col,transparent:true,opacity:.6,side:THREE.DoubleSide,toneMapped:false}));ring.rotation.x=-Math.PI/2;ring.position.y=-.85;g.add(ring);
 scene.add(g);return g;
}
function brUpdate(dt,t){
 const z=BRZ,R=z.ring;
 R.position.set(z.cx,0,z.cz);R.scale.set(Math.max(.01,z.r),1,Math.max(.01,z.r));R.userData.wall.material.opacity=.16+Math.sin(t*2)*.04;
 if(G.state!=='live')return;
 const ph=BR_PHASES[Math.min(z.phase,BR_PHASES.length-1)];
 if(z.state==='wait'){z.wait-=dt;if(z.wait<=0){z.state='shrink';z.t=ph.shrink;z.from=z.r;z.to=ph.r;const a=rand(0,TAU),d=ph.r>0?rand(0,Math.max(0,z.r-ph.r)*.6):0;z.tx=clamp(z.cx+Math.cos(a)*d,20,60);z.tz=clamp(z.cz+Math.sin(a)*d,20,60);z.fx=z.cx;z.fz=z.cz;uiToast('La zone se réduit !');sfx('alarm');}}
 else if(z.state==='shrink'){z.t-=dt;const k=1-Math.max(0,z.t)/ph.shrink;z.r=lerp(z.from,z.to,k);z.cx=lerp(z.fx,z.tx,k);z.cz=lerp(z.fz,z.tz,k);z.dmg=ph.dmg;
  if(z.t<=0){z.phase++;if(z.phase>=BR_PHASES.length){z.state='final';}else{z.state='wait';z.wait=BR_PHASES[z.phase].wait;}}}
 // dégâts hors zone
 z.dtick=(z.dtick||0)+dt;
 if(z.dtick>=1){z.dtick-=1;for(const e of ents){if(!e.alive)continue;if(Math.hypot(e.x-z.cx,e.z-z.cz)>z.r+.5){hurt(e,e,{n:'Zone',kill:0,hs:1,ap:1,fo:999,fr:0},'b',1,z.dmg+z.phase*1.5);}}}
 z.alive=ents.filter(e=>e.alive).length;
 if(z.alive<=1&&!G.final){const w=ents.find(e=>e.alive);G.winner=w||null;endDM();}
}
/* ---------- ENTRAÎNEMENT ---------- */
function trInit(){TR.score=0;TR.streak=0;TR.best=0;TR.t=0;TR.hits=0;TR.dummies=[];TR.started=false;}
function trPlaceDummies(){
 const list=MAP.targets||MAP.roam.map((c,i)=>[c[0],c[1],['s','m','p'][i%3]]);
 list.forEach((tg,i)=>{
  const d=newEnt('Cible',1,false,50+i);d.id=500+i;d.dummy=true;d.kind=tg[2];d.diff=DIFFS[0];
  const n=nearestFree(tg[0],tg[1]);d.x=cc(n[0]);d.z=cc(n[1]);d.y=groundH(d.x,d.z);d.hx=d.x;d.hz=d.z;d.yaw=0;d.hp=100;d.alive=true;
  d.wp.p=null;d.wp.s=null;d.cur='k';d.popT=0;d.ph=rand(0,6);
  ents.push(d);attachRig(d);TR.dummies.push(d);
 });
}
function trUpdate(dt){
 if(G.state==='freeze'&&!TR.started)return;
 TR.t+=dt;
 for(const d of TR.dummies){
  if(d.kind==='m'&&d.alive){d.x=d.hx+Math.sin(G.t*.9+d.ph)*5;d.z=d.hz;d.speed=2;d.vx=Math.cos(G.t*.9+d.ph)*4.5*.9;d.vz=0;d.yaw=d.vx>0?-Math.PI/2:Math.PI/2;}
  else if(d.alive){d.vx=d.vz=0;d.speed=0;}
  if(d.kind==='p'){d.ph+=dt;if(d.alive&&d.ph>2.6){d.alive=false;d.ph=0;}else if(!d.alive&&d.popT<=0&&d.ph>1.2){d.alive=true;d.hp=100;d.ph=0;}}
  if(!d.alive&&d.kind!=='p'){d.popT-=dt;if(d.popT<=0){d.alive=true;d.hp=100;d.rig.dieT=-1;}}
  if(d.alive)d.invuln=0;
  if(d.rig){d.rig.root.visible=d.alive||(d.rig.dieT>=0&&d.rig.dieT<1.2);}
 }
 if(P.alive){const wi=curWi(P);if(wi&&wi.res<30&&!W[wi.k].melee)wi.res=999;}
}
function trEnd(){
 if(G.state==='over')return;G.state='end';G.endT=1.2;G.final=true;
 const acc=MS.shots?Math.round(MS.hits/MS.shots*100):0;
 uiBanner('TEMPS ÉCOULÉ','Score '+TR.score+' • précision '+acc+' % • série max '+TR.best,4500,'#ffd75e');
}
/* ---------- affichage ---------- */
function variantHud(){
 const v=G.variant;
 if(v==='koth'){const z=kothZone(),mine=P.team;const own=KO.owner;
  return {L:KO.pts[mine],R:KO.pts[1-mine],tm:G.timeLeft,tl:'POINTS — PREMIER À '+G.limit,aL:'Prochaine zone '+Math.max(0,Math.ceil(KO.moveT))+' s',aR:'',ph:KO.contested?'ZONE DISPUTÉE':own===-1?'ZONE LIBRE — allez dessus !':own===mine?'VOTRE ÉQUIPE TIENT LA ZONE':'L\'ENNEMI TIENT LA ZONE'};}
 if(v==='zombies'){const zl=ents.filter(e=>e.zombie&&e.alive).length+Z.queue;return {L:'Vague '+Z.wave+'/'+G.limit,R:zl,tm:Z.state==='break'||Z.state==='wait'?Math.max(0,Z.breakT):G.t,tl:Z.state==='break'||Z.state==='wait'?'PROCHAINE VAGUE':'ZOMBIES RESTANTS',aL:ents.filter(e=>e.team===0&&e.alive).length+' survivants',aR:'zombies',ph:''};}
 if(v==='br'){const z=BRZ;return {L:ents.filter(e=>e.alive).length,R:P.kills,tm:z.state==='wait'?z.wait:z.state==='shrink'?z.t:0,tl:z.state==='wait'?'ZONE STABLE':z.state==='shrink'?'LA ZONE SE RÉDUIT':'ZONE FINALE',aL:'en vie',aR:'éliminations',ph:Math.hypot(P.x-z.cx,P.z-z.cz)>z.r?'⚠ VOUS ÊTES HORS DE LA ZONE':''};}
 if(v==='train'){const acc=MS.shots?Math.round(MS.hits/MS.shots*100):0;return {L:TR.score,R:acc+' %',tm:G.timeLeft,tl:'SCORE',aL:'série '+TR.streak,aR:'précision',ph:G.state==='freeze'?'Prêt ? Le chrono démarre…':''};}
 return null;
}
function variantRadar(c,pt){
 const v=G.variant;
 if(v==='koth'){const z=kothZone(),p=pt(z.x,z.z);c.strokeStyle=KO.owner===-1?'#fff':TEAMCSS[KO.owner];c.lineWidth=2.5;c.beginPath();c.arc(p[0],p[1],z.r*4.2,0,TAU);c.stroke();}
 if(v==='br'){const p=pt(BRZ.cx,BRZ.cz);c.strokeStyle='#35d6ff';c.lineWidth=3;c.beginPath();c.arc(p[0],p[1],BRZ.r*4.2,0,TAU);c.stroke();}
}
