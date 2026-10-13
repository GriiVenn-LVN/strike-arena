/* =====================================================================
   JEU : entités, physique, combat, boutique, grenades, bombe, modes
   ===================================================================== */
const G={running:false,paused:false,state:'menu',t:0,timer:0,round:0,score:[0,0],loss:[0,0],endT:0,shake:0,spec:null,defuserId:-1,fetchId:-1,plan:0,mode:'bomb',over:false,
 limit:7,timeLeft:0,winner:null,roundWinner:-1,fall:0,countdownN:0,mvpName:''};
const BM={state:'carried',carrier:-1,x:0,y:0,z:0,timer:0,site:-1,beep:0,mesh:null};
let ents=[],P=null,pickups=[],buyOpen=false,focusLocked=false;
const ROUND_T=100,FREEZE_T=12,PLANT_T=3.2,DEFUSE_T=5,BOMB_T=40,RUN=5.2;
const defT=e=>e.kit?DEFUSE_T/2:DEFUSE_T;
const keys={};let mouseL=false,mouseR=false,clickLatch=false;
const NAMES=['Ghost','Nova','Rex','Kilo','Echo','Blaze','Hawk','Frost','Storm','Wolf','Zed','Bolt','Rook','Pixel','Onyx','Viper','Dash','Lynx','Sable','Maverick','Orion','Raven','Titan','Cobra'];
const MODE=()=>MODES[G.mode];
const isDM=()=>G.mode!=='bomb';
/* hooks UI (définis dans 80_ui.js) */
function newEnt(name,team,isPlayer,idx){
 return {id:0,name,team,col:idx%PALETTE.length,tone:SKIN_TONES[idx%SKIN_TONES.length],isPlayer,x:0,y:0,z:0,vx:0,vz:0,vy:0,yaw:0,pitch:0,hp:100,armor:0,shield:0,alive:true,money:0,
  wp:{p:null,s:null,k:{k:'knife',mag:0,res:0}},cur:'s',lastSlot:'p',kills:0,deaths:0,hsKills:0,dmg:0,streak:0,rig:null,crouch:false,eyeH:1.6,speed:0,onGround:true,
  reload:0,reloadMax:0,reloadWi:null,nextShot:0,switchT:0,spray:0,lastShot:-9,ads:0,punchP:0,punchY:0,prog:0,progMsg:'',useMsg:'',spotT:0,keep:false,kit:false,nade:{f:0,fl:0,sm:0,mn:0},blindT:0,nadeT:0,
  fireAnim:0,ready:0,alertT:0,hurtFlag:false,dieDir:0,stepT:0,respT:0,invuln:0,ggLevel:0,lastHurtT:-9,lastAttacker:null,inspectT:0,
  diff:isPlayer?null:DIFFS[cfg.diff],target:null,targetT:0,seeT:0,aimHead:false,lastSeen:null,faceT:0,faceYaw:0,visT:rand(0,.1),
  path:null,pi:0,gx:0,gz:0,repathT:0,mvMode:0,mvT:0,strafeDir:1,burstN:0,burstMax:4,burstPause:0,holdX:0,holdZ:0,watch:0,
  startDelay:0,bought:false,buyAt:0,stuckT:0,sx:0,sz:0,retX:0,retZ:0,roamX:0,roamZ:0,roamT:0,peekT:0};
}
const curWi=e=>e.wp[e.cur],curW=e=>W[e.wp[e.cur].k];
const eyeOf=e=>e.isPlayer?e.eyeH:(e.crouch?1.12:1.55);
function giveWeapon(e,k,keepCur){
 const w=W[k],slot=w.slot===0?'p':'s';
 e.wp[slot]={k,mag:magMax(e,k),res:w.res};if(!keepCur){e.lastSlot=e.cur;e.cur=slot;}e.reload=0;e.ads=0;
}
function switchTo(e,slot){
 if(!e.wp[slot]||e.cur===slot)return;
 e.lastSlot=e.cur;e.cur=slot;e.reload=0;e.switchT=.45;e.burstN=0;e.ads=0;if(e.isPlayer){vmDraw();sfx('draw');}
}
const bestSlot=e=>e.wp.p?'p':e.wp.s?'s':'k';
const slotOf=k=>W[k].slot===0?'p':W[k].slot===1?'s':'k';
function buyItem(e,k){
 if(NET.role==='client'&&e.isPlayer&&G.netClient){netSend({t:'buy',k},'host');return true;}
 const free=!cfg.eco||isDM();
 const pay=pr=>{if(free)return true;if(e.money<pr)return false;e.money-=pr;return true;};
 if(k==='armor'){if(e.armor>=100)return false;if(!pay(650))return false;e.armor=100;return true;}
 if(k==='shield1'){if(e.shield>=25)return false;if(!pay(400))return false;e.shield=25;return true;}
 if(k==='shield2'){if(e.shield>=50)return false;if(!pay(1000))return false;e.shield=50;return true;}
 if(k==='kit'){if(e.team!==1||e.kit||!G.mode||G.mode!=='bomb')return false;if(!pay(400))return false;e.kit=true;return true;}
 if(k==='frag'){if(e.nade.f>=1)return false;if(!pay(300))return false;e.nade.f=1;return true;}
 if(k==='flash'){if(e.nade.fl>=2)return false;if(!pay(200))return false;e.nade.fl++;return true;}
 if(k==='mine'){if((e.nade.mn||0)>=MINE_MAX)return false;if(!pay(MINE_PRICE))return false;e.nade.mn=(e.nade.mn||0)+1;return true;}
 if(k==='smoke'){if(e.nade.sm>=1)return false;if(!pay(300))return false;e.nade.sm=1;return true;}
 const w=W[k];if(!w)return false;
 if(G.pistolRound&&G.mode==='bomb'&&w.slot===0)return false;
 const slot=slotOf(k);if(e.wp[slot]&&e.wp[slot].k===k)return false;
 if(!pay(w.price))return false;giveWeapon(e,k);return true;
}
const SHIELDMAX=50;

/* ---------- physique ---------- */
function moveEnt(e,vx,vz,dt){
 const nx=e.x+vx*dt;if(!blocked(nx,e.z,e.y,PR))e.x=nx;
 const nz=e.z+vz*dt;if(!blocked(e.x,nz,e.y,PR))e.z=nz;
}
function physics(e,dt){
 const g=groundH(e.x,e.z);
 if(e.onGround){if(e.y-g>STEPDOWN){e.onGround=false;}else{e.y=g;e.vy=0;}}
 if(!e.onGround){
  e.vy-=GRAV*dt;e.y+=e.vy*dt;
  const hh=e.crouch?1.3:1.75,ce=ceilAt(e.x,e.z);
  if(e.y+hh>ce&&e.vy>0){e.vy=0;e.y=ce-hh-.01;}
  if(e.y<=g){
   if(e.vy<-8.5){const d=Math.round((-e.vy-8.5)*10);if(d>0)selfDamage(e,d);if(e.isPlayer){sfx('land');G.fall=.4;}}
   else if(e.isPlayer&&e.vy<-3)sfx('land',undefined,undefined,.5);
   e.y=g;e.vy=0;e.onGround=true;
  }
 }
}
function selfDamage(e,d){
 if(e.invuln>0)return;
 e.hp-=d;if(e.isPlayer)uiDamage(null);
 if(e.hp<=0&&e.alive)killEnt(e,e,{n:'Chute',kill:0},false);
}
function surfaceAt(x,z){
 if(MAP.base==='industrial'){const i=Math.floor(z/S)*N+Math.floor(x/S);return(G_TYPE[i]===TY.PLAT||G_RAMP[i])?'metal':'stone';}
 if(MAP.base==='snow')return 'snow';
 return G_TAG[Math.floor(z/S)*N+Math.floor(x/S)]===0?'sand':'stone';
}

/* ---------- tirs ---------- */
function hitEnt(e,ox,oy,oz,dx,dy,dz,maxT){
 const k=e.crouch?.74:1;let bestT=maxT,zone=null;
 const cx=e.x,cy=e.y+1.64*k,cz=e.z,r=.22;
 const ocx=ox-cx,ocy=oy-cy,ocz=oz-cz,b=ocx*dx+ocy*dy+ocz*dz,c2=ocx*ocx+ocy*ocy+ocz*ocz-r*r,disc=b*b-c2;
 if(disc>0){const t=-b-Math.sqrt(disc);if(t>0&&t<bestT){bestT=t;zone='h';}}
 const a=dx*dx+dz*dz;
 if(a>1e-8){
  const px=ox-e.x,pz=oz-e.z,bb=px*dx+pz*dz,cc2=px*px+pz*pz-.34*.34,d2=bb*bb-a*cc2;
  if(d2>=0){const t=(-bb-Math.sqrt(d2))/a;if(t>0&&t<bestT){const y=oy+dy*t-e.y;if(y>=0&&y<=1.42*k){bestT=t;zone=y<.7*k?'l':'b';}}}
 }
 return zone?{t:bestT,z:zone}:null;
}
const dirOf=(yaw,pit)=>[-Math.sin(yaw)*Math.cos(pit),Math.sin(pit),-Math.cos(yaw)*Math.cos(pit)];
function spreadOf(e,w){
 if(e.isPlayer||e.remote){
  let s=w.spr+w.mv*Math.min(1,e.speed/4.8);
  if(!e.onGround)s+=w.mv*.8+2.5;
  if(e.crouch)s*=.6;
  if(w.overlay&&e.ads<.9)s+=5;
  s*=1-.4*e.ads;
  return s+e.spray*.02;
 }
 const d=e.diff;
 return d.spread*(1+Math.min(1,e.speed/4)*1.3)+w.spr*.4+e.spray*.1*(d.spread/3+.3);
}
let lastSpreadShown=0;
function muzzlePos(e,d){
 const ex=e.x,ey=e.y+eyeOf(e),ez=e.z,cy=Math.cos(e.yaw),sy=Math.sin(e.yaw);
 return [ex+d[0]*.7+cy*.14,ey-.15+d[1]*.7,ez+d[2]*.7-sy*.14];
}
function shoot(e){
 const wi=curWi(e),w=W[wi.k];
 if(e.reload>0||e.switchT>0||G.t<e.nextShot||!e.alive)return false;
 const ox=e.x,oy=e.y+eyeOf(e),oz=e.z;
 if(w.melee){
  e.nextShot=G.t+60/w.rpm;e.fireAnim=1;
  const dr=dirOf(e.yaw,e.pitch);
  if(NET.role==='client'&&e.isPlayer&&G.netClient)netShot(e);
  let bt=rayWall(ox,oy,oz,dr[0],dr[1],dr[2],2.5),hv=null,hz=null;
  for(const v of ents){if(!v.alive||v.team===e.team||v===e)continue;const h=hitEnt(v,ox,oy,oz,dr[0],dr[1],dr[2],bt);if(h&&h.t<bt){bt=h.t;hv=v;hz=h.z;}}
  if(hv){
   // coup dans le dos = mortel
   const fx=-Math.sin(hv.yaw),fz=-Math.cos(hv.yaw),back=(fx*dr[0]+fz*dr[2])>.5;
   hurt(hv,e,w,'b',bt,back?100:w.dmg);sfx('knifehit',hv.x,hv.z);
  }else sfx('knife',e.x,e.z);
  minesNear(ox+dr[0]*1.4,oz+dr[2]*1.4,1.1,e);
  if(e.isPlayer)vmKnifeSwing();
  return true;
 }
 if(wi.mag<=0){if(e.isPlayer)sfx('click');startReload(e);e.nextShot=G.t+.25;return false;}
 wi.mag--;e.nextShot=G.t+60/w.rpm/(e.perks&&e.perks.dtap?1.33:1);e.lastShot=G.t;
 if(NET.role==='client'&&e.isPlayer&&G.netClient)netShot(e);
 if(w.wonder){wonderFire(e,w,wi);return true;}
 const sil=hasAtt(e,wi.k,'sil'),sp=spreadOf(e,w)*(hasAtt(e,wi.k,'opt')&&e.ads>.5?.75:1),rcm=hasAtt(e,wi.k,'grip')?.82:1,dmm=sil?.92:1;lastSpreadShown=sp;
 const pel=w.pel||1;
 let hitAny=false;
 for(let i=0;i<pel;i++){
  let yaw=e.yaw+(e.isPlayer?e.punchY*RAD:0),pit=e.pitch+(e.isPlayer?e.punchP*RAD:0);
  const a=Math.random()*TAU,r=Math.sqrt(Math.random())*sp*RAD;
  yaw+=Math.cos(a)*r;pit+=Math.sin(a)*r;
  const d=dirOf(yaw,pit);
  let bt=rayWall(ox,oy,oz,d[0],d[1],d[2],170),hv=null,hz=null;
  for(const v of ents){if(!v.alive||v.team===e.team||v===e||v.invuln>0)continue;const h=hitEnt(v,ox,oy,oz,d[0],d[1],d[2],bt);if(h&&h.t<bt){bt=h.t;hv=v;hz=h.z;}}
  {const mt=mineRayHit(e,ox,oy,oz,d[0],d[1],d[2],bt);if(mt>=0){bt=mt;hv=null;}}
  const ex=ox+d[0]*bt,ey=oy+d[1]*bt,ez=oz+d[2]*bt;
  if(i<3||!e.isPlayer){const m=muzzlePos(e,d);addTracer(m[0],m[1],m[2],ex,ey,ez,trailCol(e));}
  if(NET.role==='host'&&i===0){const m=muzzlePos(e,d);netEvent({t:'tr',a:[+m[0].toFixed(2),+m[1].toFixed(2),+m[2].toFixed(2),+ex.toFixed(2),+ey.toFixed(2),+ez.toFixed(2)],c:w.cat,s:e.id});}
  if(hv){hitAny=true;bodyHitFX(ex,ey,ez,d,hv.shield>0,hz==='h');fxBlood(ex,ey,ez,d,hz==='h'?7:4,hz==='h');hurt(hv,e,w,hz,bt,w.dmg*dmm);}
  else if(bt<170){
   barrelHit(ex+d[0]*.15,ey+d[1]*.15,ez+d[2]*.15,e);
   impactFX(ex-d[0]*.05,ey-d[1]*.05,ez-d[2]*.05,d,MAP.base==='industrial'?'metal':MAP.base);addHole(ex-d[0]*.04,ey-d[1]*.04,ez-d[2]*.04);
   if(e.isPlayer||Math.hypot(ex-lis.x,ez-lis.z)<14)sfx('step',ex,ez,.25,'stone');
  }
 }
 e.spray=Math.min(e.spray+1,30);e.fireAnim=1;
 if(e.isPlayer){MS.shots++;if(hitAny)MS.hits++;}
 if(e.isPlayer){
  const pat=Math.sin(e.spray*.9)*w.rec*.55;
  e.punchP+=w.rec*rcm*(1.9+Math.min(e.spray,12)*.07)*(1-.25*e.ads);e.punchY+=(pat+(Math.random()-.5)*w.rec*.5)*rcm;
  vmFire(w);G.shake=Math.max(G.shake,.04+w.rec*.012);
  const d0=dirOf(e.yaw,e.pitch);muzzleLight(ox+d0[0]*.6,oy-.1+d0[1]*.6,oz+d0[2]*.6);
  // douille
  const cy=Math.cos(e.yaw),sy=Math.sin(e.yaw);if(w.cat!=='shotgun'||w.auto)ejectShell(ox+cy*.1+d0[0]*.3,oy-.12,oz-sy*.1+d0[2]*.3,e.yaw,1);
 }else{
  const d0=dirOf(e.yaw,e.pitch),m=muzzlePos(e,d0);fxMuzzleSmoke(m[0],m[1],m[2],d0[0],d0[1],d0[2]);muzzleFlash3D(m[0],m[1],m[2],w.cat==='sniper'||w.cat==='shotgun'?.8:.5);
  if(Math.random()<.5)ejectShell(ox,oy-.2,oz,e.yaw,1);
 }
 sfx(w.cat==='melee'?'knife':w.cat,e.x,e.z,(e.isPlayer?.85:1)*(sil?.4:1));
 // les bots adverses entendent le tir
 for(const b of ents){
  if(!b.alive||b.isPlayer||b.team===e.team||b===e||b.target)continue;
  const dd=Math.hypot(b.x-e.x,b.z-e.z);
  if(dd<(sil?16:42)&&Math.random()<b.diff.hear*.5){b.lastSeen={x:e.x+rand(-3,3),z:e.z+rand(-3,3),t:G.t};b.faceT=.7;b.faceYaw=Math.atan2(-(e.x-b.x),-(e.z-b.z));}
 }
 if(wi.mag===0&&!e.isPlayer)startReload(e);
 return true;
}
function startReload(e){
 if(NET.role==='client'&&e.isPlayer&&G.netClient)netSend({t:'reload'},'host');
 const wi=curWi(e),w=W[wi.k];
 if(w.melee||e.reload>0||wi.mag>=magMax(e,wi.k)||wi.res<=0)return;
 const rm=e.perks&&e.perks.speed?.5:1;e.reload=w.rel*rm;e.reloadMax=w.rel*rm;e.reloadWi=wi;e.ads=0;
 sfx('reload',e.x,e.z,.8);if(e.isPlayer)vmReload(w);
}
function tickWeapon(e,dt){
 if(e.switchT>0)e.switchT-=dt;
 if(e.reload>0){e.reload-=dt;if(e.reload<=0){e.reload=0;const wi=e.reloadWi,w=W[wi.k],n=Math.min(magMax(e,wi.k)-wi.mag,wi.res);wi.mag+=n;wi.res-=n;}}
 if(G.t-e.lastShot>.25)e.spray=Math.max(0,e.spray-dt*18);
 e.fireAnim=Math.max(0,e.fireAnim-dt*9);
 if(e.invuln>0)e.invuln-=dt;
}
function hurt(v,att,w,zone,dist,raw){
 if(NET.role==='client'&&G.netClient){if(att&&att.isPlayer&&v!==P){uiHit(zone,false,false);sfx(zone==='h'?'hs':'hit');}return;}
 if(v.invuln>0||!v.alive)return;
 if(G.variant==='zombies')raw=zHurtHook(v,att,raw,w);
 let dmg=raw*(v.domeT>G.t?.5:1)*(zone==='h'?w.hs:zone==='l'?.75:1);
 const fo=w.fo||40,fr=w.fr||.004;
 if(dist>fo)dmg*=Math.max(w.fmin||.5,1-(dist-fo)*fr);
 if(att.diff&&!att.remote)dmg*=att.diff.dmg;
 const total=dmg;let shieldHit=0;
 if(v.shield>0){shieldHit=Math.min(v.shield,dmg);v.shield-=shieldHit;dmg-=shieldHit;}
 let hpd=dmg;
 if(dmg>0&&v.armor>0){const ap=w.ap||.6;hpd=dmg*ap;v.armor=Math.max(0,v.armor-(dmg-hpd)*.5);}
 hpd=dmg>0?Math.max(1,Math.round(hpd)):0;v.hp-=hpd;v.prog=0;v.lastHurtT=G.t;v.lastAttacker=att;v.hurtFlag=true;
 att.dmg+=Math.round(total);
 if(v.hp<=0&&G.variant==='zombies'&&zSave(v))return;
 const kill=v.hp<=0;
 if(att.isPlayer){uiHit(zone,kill,shieldHit>0&&hpd===0);uiDmgNum(Math.round(total),zone==='h',shieldHit>0&&hpd===0,v);sfx(shieldHit>0&&hpd===0?'shield':zone==='h'?'hs':'hit');}
 if(v.remote)netEvent({t:'hurt',to:v.id,f:att.id});
 if(v.isPlayer){uiDamage(att);sfx(shieldHit>0&&hpd===0?'shield':'dmg');G.shake=Math.max(G.shake,.25);}
 else if(!v.target){v.lastSeen={x:att.x,z:att.z,t:G.t};v.faceT=.9;v.faceYaw=Math.atan2(-(att.x-v.x),-(att.z-v.z));}
 if(v.shield<=0&&shieldHit>0&&v.isPlayer)sfx('shieldbreak');
 if(kill)killEnt(v,att,w,zone==='h');
}
/* ---------- morts & scores ---------- */
function killEnt(v,att,w,hs){
 rpKill(att,v,w,hs);
 v.alive=false;v.hp=0;v.deaths++;v.scoped=false;v.prog=0;v.streak=0;v.shield=0;v.ads=0;
 v.dieDir=Math.floor(Math.random()*4);
 if(att!==v){att.kills++;att.streak++;if(hs)att.hsKills++;att.bestStreak=Math.max(att.bestStreak||0,att.streak);
  if(att.isPlayer){const wk=Object.keys(W).find(k=>W[k]===w);if(wk)MS.wkills[wk]=(MS.wkills[wk]||0)+1;metaEvent('kills');if(hs)metaEvent('hs');if(w===NADEW)metaEvent('nade');if(w.melee)metaEvent('knife');}}
 if(v.rig)v.rig.dieT=-1;
 if(v.rig&&v.isPlayer)v.rig.root.visible=true;
 if(BM.state==='carried'&&BM.carrier===v.id){BM.state='dropped';BM.x=v.x;BM.z=v.z;BM.y=v.y;BM.carrier=-1;}
 uiFeed(att,v,w,hs);
 netEvent({t:'feed',a:att.id,v:v.id,w:Object.keys(W).find(k=>W[k]===w)||'knife',hs});
 if(att.isPlayer&&att!==v){uiKillMsg(v,hs,att.streak);sfx('kill');}
 if(v.isPlayer){G.spec=null;uiDeath(att);}
 if(G.mode==='bomb'){
  if(att!==v)att.money=Math.min(16000,att.money+(w.kill||300));
  extrasKill(att,w);if(cfg.gore&&!v.zombie)stain(v.x,groundH(v.x,v.z)+.03,v.z,6);
  if(G.state==='live')checkEnd();
 }else{
  v.respT=variantRespawn(v);
  if(G.mode==='tdm'&&att!==v&&att.team!==v.team&&!NOKILLSCORE[G.variant]){G.score[att.team]++;checkDMEnd();}
  else if(G.mode==='ffa'&&att!==v&&G.variant==='ffa'){checkDMEnd();}
  else if(G.mode==='gg'&&att!==v){ggKill(att,v,w);}
  variantKill(att,v,w,hs);
  if(G.variant!=='train'&&G.variant!=='zombies'&&G.variant!=='br'&&(v.shield>0||Math.random()<.18))dropPickup(v.x,v.z,'shield');
 }
}
function ggKill(att,v,w){
 if(att.ggLevel<GG_LADDER.length-1){
  att.ggLevel++;ggEquip(att);
  if(att.isPlayer){uiToast('Niveau '+(att.ggLevel+1)+' / '+GG_LADDER.length+' — '+W[GG_LADDER[att.ggLevel]].n);sfx('pickup');}
 }else{G.winner=att;endDM();return;}
 if(w&&w.melee&&v.ggLevel>0){v.ggLevel--;if(v.isPlayer)uiToast('Rétrogradé par un coup de couteau !');}
}
function ggEquip(e){
 const k=GG_LADDER[e.ggLevel],w=W[k];
 e.wp.p=null;e.wp.s=null;
 if(w.melee){e.cur='k';}else giveWeapon(e,k);
 e.switchT=.3;
}
function checkDMEnd(){
 if(G.state!=='live')return;
 if(G.mode==='tdm'){if(G.score[0]>=G.limit||G.score[1]>=G.limit){G.winner=G.score[0]>G.score[1]?0:1;endDM();}}
 else if(G.mode==='ffa'){for(const e of ents)if(e.kills>=G.limit){G.winner=e;endDM();return;}}
}
function endDM(){
 if(G.state==='over')return;
 G.state='end';G.endT=4.5;
 let mine=false,txt='';
 if(G.mode==='tdm'){mine=G.winner===P.team;txt=mine?'VICTOIRE':'DÉFAITE';}
 else{mine=G.winner===P;txt=G.winner?(mine?'VICTOIRE':G.winner.name+' GAGNE'):'ÉGALITÉ';}
 uiBanner(txt,'Fin de la partie',4200,mine?'#7dff9f':'#ff6b6b');sfx(mine?'win':'lose');
 G.final=true;
}
function timeUpDM(){
 if(variantTimeUp())return;
 if(G.mode==='tdm'){G.winner=G.score[0]===G.score[1]?-1:G.score[0]>G.score[1]?0:1;}
 else if(G.mode==='gg'){let b=null;for(const e of ents)if(!b||e.ggLevel>b.ggLevel||(e.ggLevel===b.ggLevel&&e.kills>b.kills))b=e;G.winner=b;}
 else{let b=null;for(const e of ents)if(!b||e.kills>b.kills||(e.kills===b.kills&&e.deaths<b.deaths))b=e;G.winner=b;}
 if(G.mode==='tdm'&&G.winner===-1){G.state='end';G.endT=4.5;G.final=true;uiBanner('ÉGALITÉ','Temps écoulé',4000);return;}
 endDM();
}
/* ---------- apparition / réapparition ---------- */
function visibleFromEnemies(x,z,team){
 for(const e of ents){if(!e.alive||e.team===team)continue;if(Math.hypot(e.x-x,e.z-z)<30&&losClear(e.x,e.y+1.5,e.z,x,groundH(x,z)+1.5,z,true))return true;}
 return false;
}
function safeSpawn(e){
 let list;
 if(G.mode==='tdm')list=(e.team===0?MAP.spawnT:MAP.spawnCT).concat(MAP.spawnDM);
 else list=MAP.spawnDM.concat(MAP.spawnT,MAP.spawnCT);
 let best=null,bs=-1e9;
 for(let i=0;i<8;i++){
  const c=pick(list),x=cc(c[0]),z=cc(c[1]);let md=1e9;
  for(const o of ents){if(o===e||!o.alive||o.team===e.team)continue;md=Math.min(md,Math.hypot(o.x-x,o.z-z));}
  let sc=Math.min(md,60)+Math.random()*6;if(visibleFromEnemies(x,z,e.team))sc-=40;
  if(sc>bs){bs=sc;best=c;}
 }
 return best;
}
function dmLoadout(e){
 e.wp.p=null;e.wp.s=null;
 if(G.mode==='gg'){ggEquip(e);e.nade={f:0,fl:0,sm:0,mn:0};return;}
 if(e.isPlayer){
  const ld=cfg.loadout;giveWeapon(e,e.team===0?'glock':'usp');
  if(ld.s)giveWeapon(e,ld.s);if(ld.p)giveWeapon(e,ld.p);
  e.nade={f:1,fl:1,sm:1,mn:1};
 }else{
  giveWeapon(e,e.team===0?'glock':'usp');
  const cats=cfg.diff<=1?['smg','shotgun','rifle','pistol','sniper']:['rifle','rifle','rifle','smg','sniper','lmg','shotgun','rifle'];
  const pool=Object.keys(W).filter(k=>W[k].slot===0&&cats.includes(W[k].cat));if(pool.length)giveWeapon(e,pick(pool));
  if(Math.random()<.5){const pp=['p250','fiveseven','deagle'];giveWeapon(e,pick(pp),true);}
  e.nade={f:Math.random()<.5?1:0,fl:0,sm:Math.random()<.2?1:0,mn:Math.random()<.35?1:0};
 }
 e.cur=bestSlot(e);
}
function respawn(e){
 e.tp=(e.tp||0)+1;
 const c=safeSpawn(e);e.x=cc(c[0]);e.z=cc(c[1]);e.y=groundH(e.x,e.z);e.vy=0;e.vx=e.vz=0;e.onGround=true;
 e.hp=100;e.armor=0;e.shield=0;e.alive=true;e.reload=0;e.switchT=.3;e.scoped=false;e.ads=0;e.crouch=false;e.eyeH=1.6;e.speed=0;e.target=null;e.lastSeen=null;e.path=null;e.prog=0;e.spray=0;e.nextShot=0;e.blindT=0;
 e.emote=null;e.punchP=e.punchY=0;e.invuln=2.2;e.pitch=0;
 const f=nearestFree(Math.floor(cc(N/2)/S),Math.floor(cc(N/2)/S));e.yaw=Math.atan2(-(cc(N/2)-e.x),-(cc(N/2)-e.z));
 if(G.mode==='gg'&&!e.isPlayer||G.mode==='gg'&&e.isPlayer)ggEquip(e);else dmLoadout(e);
 if(e.rig){e.rig.dieT=-1;e.rig.root.visible=!e.isPlayer;e.rig.root.rotation.x=0;e.rig.root.rotation.z=0;e.rig.root.position.y=0;}
 if(e.isPlayer){G.spec=null;uiRespawned();}
}

/* ---------- construction des rigs ---------- */
function entLook(e){
 if(e.isPlayer&&PROF.outfit&&ownsOutfit(PROF.outfit)){return {kind:'ct',acc:PALETTE[e.col],tone:e.tone,outfit:PROF.outfit};}
 if(G.mode==='ffa'||G.mode==='gg')return {kind:'ffa',acc:PALETTE[e.col],tone:e.tone};
 return {kind:e.team===0?'t':'ct',acc:PALETTE[e.team===0?5:1],tone:e.tone};
}
function attachRig(e){
 if(e.rig){scene.remove(e.rig.root);}
 const R=makeSoldier(entLook(e));scene.add(R.root);e.rig=R;setSoldierGun(R,curWi(e).k);
 if(!e.isPlayer){
  const friendly=G.mode==='bomb'||G.mode==='tdm'?e.team===P.team:false;
  if(friendly){
   const col=G.mode==='ffa'?PALETTE[e.col]:TEAMCSS[e.team];
   const t=canvasTex(256,64,(c,w,h)=>{c.font='bold 32px "Segoe UI",Arial';c.textAlign='center';c.fillStyle='rgba(0,0,0,.6)';c.fillRect(30,12,w-60,38);c.fillStyle=col;c.fillText(e.name,w/2,43);});
   const sp=new THREE.Sprite(new THREE.SpriteMaterial({map:t,transparent:true,depthTest:false,toneMapped:false}));sp.scale.set(1.2,.3,1);sp.position.y=2.15;sp.renderOrder=8;R.root.add(sp);R.label=sp;
  }
 }else R.root.visible=false;
}
const TEAMCSS=['#ff7a4a','#4aa3ff'];
function syncRigs(dt,t){
 const sp=P&&!P.alive?specTarget():null;
 for(const e of ents){
  const R=e.rig;if(!R)continue;
  if(G.state==='cine'){R.root.visible=!!e.cineSeat;}
  else if(e.isPlayer){R.root.visible=!e.alive||!!e.emote;}else R.root.visible=e!==sp;
  if(e.isPlayer&&e.alive&&!e.emote&&!e.cineSeat)continue;
  if(!e.cineSeat){R.root.position.x=e.x;R.root.position.z=e.z;R.root.rotation.y=e.yaw;}
  const wk=curWi(e).k;if(R.gk!==wk){setSoldierGun(R,wk);R.swT=.35;}
  const st={vx:e.vx,vz:e.vz,yaw:e.yaw,pitch:e.pitch,speed:e.speed,onGround:e.onGround,crouch:e.crouch,alive:e.alive,reload:e.reload,reloadMax:e.reloadMax,fire:e.fireAnim,ready:G.t-e.lastShot<2.5||!!e.target||e.isPlayer,alert:(e.target||G.t-e.lastShot<3)?1:0,hurt:e.hurtFlag,dieDir:e.dieDir,y:e.y,dance:e.emote?e.emote.id:null,danceT:e.emote?e.emote.t:0,seated:e.seated||0};
  e.hurtFlag=false;
  // pour la mort, on garde les positions y du corps ; animateSoldier gère l'inclinaison
  animateSoldier(R,st,dt,t);
  if(R.label){R.label.visible=e.alive&&G.state!=='cine';}
 }
}

/* ---------- ramassables (bouclier / santé / munitions) ---------- */
const pickupGeo={};
function makePickup(type,x,z){
 const g=new THREE.Group();g.position.set(x,groundH(x,z)+.9,z);
 const col=type==='shield'?0x31c8ff:type==='health'?0xff4a5a:0xffd24a;
 const core=new THREE.Mesh(type==='shield'?new THREE.OctahedronGeometry(.28,0):type==='health'?new THREE.BoxGeometry(.4,.4,.4):new THREE.BoxGeometry(.5,.28,.32),new THREE.MeshStandardMaterial({color:C(col),emissive:C(col),emissiveIntensity:1.3,roughness:.3,metalness:.4,transparent:true,opacity:.92}));
 g.add(core);
 if(type==='health'){const a=new THREE.Mesh(GBOX,new THREE.MeshBasicMaterial({color:0xffffff,toneMapped:false}));a.scale.set(.5,.12,.12);g.add(a);const b=a.clone();b.scale.set(.12,.5,.12);g.add(b);}
 const glow=new THREE.Sprite(new THREE.SpriteMaterial({map:GLOW.cool,color:new THREE.Color(col),blending:THREE.AdditiveBlending,transparent:true,depthWrite:false,opacity:.8,toneMapped:false}));glow.scale.set(1.8,1.8,1);g.add(glow);
 const ring=new THREE.Mesh(new THREE.RingGeometry(.55,.65,24),new THREE.MeshBasicMaterial({color:col,transparent:true,opacity:.5,side:THREE.DoubleSide,toneMapped:false}));ring.rotation.x=-Math.PI/2;ring.position.y=-.85;g.add(ring);
 scene.add(g);return g;
}
function dropPickup(x,z,type){
 if(pickups.length>14){const old=pickups.find(p=>p.temp);if(old){scene.remove(old.mesh);pickups.splice(pickups.indexOf(old),1);}}
 pickups.push({type,x,z,mesh:makePickup(type,x,z),t:0,on:true,temp:true,life:25});
}
function setupPickups(){
 for(const p of pickups)scene.remove(p.mesh);pickups=[];
 if(!isDM())return;
 const spots=MAP.pickups||[];
 spots.forEach(s=>{const f=nearestFree(s[0],s[1]);pickups.push({type:s[2],x:cc(f[0]),z:cc(f[1]),mesh:makePickup(s[2],cc(f[0]),cc(f[1])),t:0,on:true,temp:false});});
}
function updatePickups(dt,t){
 for(let i=pickups.length-1;i>=0;i--){
  const p=pickups[i];
  if(p.temp){p.life-=dt;if(p.life<=0){scene.remove(p.mesh);pickups.splice(i,1);continue;}}
  if(!p.on){p.t-=dt;if(p.t<=0){p.on=true;p.mesh.visible=true;}continue;}
  p.mesh.rotation.y=t*1.6;p.mesh.position.y=groundH(p.x,p.z)+.9+Math.sin(t*2+p.x)*.1;
  for(const e of ents){
   if(!e.alive||Math.hypot(e.x-p.x,e.z-p.z)>1.3||Math.abs(e.y-groundH(p.x,p.z))>1.5)continue;
   let used=false;
   if(p.type==='shield'&&e.shield<SHIELDMAX){e.shield=Math.min(SHIELDMAX,e.shield+25);used=true;}
   else if(p.type==='health'&&e.hp<100){e.hp=Math.min(100,e.hp+35);used=true;}
   else if(p.type==='ammo'){for(const k of ['p','s']){const wi=e.wp[k];if(wi){const w=W[wi.k];wi.mag=w.mag;wi.res=w.res;}}used=true;}
   else if(p.type==='armor'&&e.armor<100){e.armor=100;used=true;}
   else if(p.type==='weapon'){const slot=slotOf(p.key);if(!e.wp[slot]||e.wp[slot].k!==p.key){giveWeapon(e,p.key);used=true;}}
   if(used){
    if(e.isPlayer){sfx(p.type==='health'?'heal':'pickup');uiToast(p.type==='shield'?'+25 bouclier':p.type==='health'?'+35 santé':p.type==='armor'?'Gilet récupéré':p.type==='weapon'?'Arme : '+W[p.key].n:'Munitions');}
    if(p.temp||p.single){scene.remove(p.mesh);pickups.splice(i,1);}else{p.on=false;p.t=20;p.mesh.visible=false;}
    break;
   }
  }
 }
}

/* ---------- grenades ---------- */
const nades=[],fxsM=[];
const nadeGeo=new THREE.SphereGeometry(.07,12,10),nadeCyl=new THREE.CylinderGeometry(.045,.045,.15,10);
function nadeMesh(type){
 const g=new THREE.Group();const col=type==='f'?0x3f5a2e:type==='fl'?0xdddddd:0x9aa0a8;
 const b=new THREE.Mesh(type==='f'?nadeGeo:nadeCyl,new THREE.MeshStandardMaterial({color:C(col),roughness:.4,metalness:.6}));g.add(b);
 const l=new THREE.Mesh(GBOX,new THREE.MeshStandardMaterial({color:C(0x999999),metalness:1,roughness:.3}));l.scale.set(.015,.05,.015);l.position.y=.09;g.add(l);
 return g;
}
function throwNade(e,type,tx,tz){
 if(NET.role==='client'&&e.isPlayer&&G.netClient){if(!e.nade[type])return false;netSend({t:'nade',k:type},'host');vmThrow();return true;}
 if(!e.nade[type]||!e.alive)return false;
 e.nade[type]--;
 const ox=e.x,oy=e.y+eyeOf(e)-.2,oz=e.z;let vx,vy,vz;
 if(tx===undefined){const d=dirOf(e.yaw,e.pitch+.16);vx=d[0]*15+e.vx*.4;vy=d[1]*15+2.5;vz=d[2]*15+e.vz*.4;}
 else{const dx=tx-ox,dz=tz-oz,L=Math.hypot(dx,dz)||1,s=clamp(L*.85,6,17);vx=dx/L*s;vz=dz/L*s;vy=5;}
 const m=nadeMesh(type);m.position.set(ox,oy,oz);m.traverse(o=>{if(o.isMesh)o.castShadow=true;});scene.add(m);
 nades.push({type,x:ox,y:oy,z:oz,vx,vy,vz,t:type==='f'?1.9:type==='fl'?1.5:1.3,m,owner:e,rest:false});
 sfx('throw',e.x,e.z);if(e.isPlayer)vmThrow();return true;
}
const blockedAt=(x,y,z)=>groundH(x,z)>y||ceilAt(x,z)<y;
function updateNades(dt){
 for(let i=nades.length-1;i>=0;i--){
  const n=nades[i];n.t-=dt;
  if(!n.rest){
   n.vy-=18*dt;
   const nx=n.x+n.vx*dt;if(blockedAt(nx,n.y,n.z)){n.vx*=-.45;sfx('click',n.x,n.z,.4);}else n.x=nx;
   const nz=n.z+n.vz*dt;if(blockedAt(n.x,n.y,nz)){n.vz*=-.45;}else n.z=nz;
   let ny=n.y+n.vy*dt;const h=groundH(n.x,n.z);
   if(ny<h+.07){ny=h+.07;if(n.vy<-2)sfx('click',n.x,n.z,.4);n.vy=Math.abs(n.vy)*.35;n.vx*=.72;n.vz*=.72;if(n.vy<1)n.vy=0;}
   n.y=ny;
   n.m.rotation.x+=dt*8;n.m.rotation.z+=dt*5;
  }
  n.m.position.set(n.x,n.y,n.z);
  if(n.t>0)continue;
  scene.remove(n.m);nades.splice(i,1);
  explodeNade(n);
 }
}
function explodeNade(n){
 if(NET.role==='host')netEvent({t:'nx',k:n.type,x:+n.x.toFixed(2),y:+n.y.toFixed(2),z:+n.z.toFixed(2),o:n.owner.id});
 if(n.type==='f'){
  sfx('boom',n.x,n.z,.8);fxExplosion(n.x,n.y+.2,n.z,.75);
  minesNear(n.x,n.z,4.5);
  for(const v of ents){
   if(!v.alive)continue;
   const dx=v.x-n.x,dz=v.z-n.z,dy=v.y+1-n.y,d=Math.hypot(dx,dy,dz);if(d>9)continue;
   if(rayWall(n.x,n.y+.4,n.z,dx/d,dy/d,dz/d,d)<d-.4)continue;
   const self=v===n.owner,fr=v.team===n.owner.team&&!self;if(fr&&MODE().team)continue;
   hurt(v,n.owner,NADEW,'b',d,Math.round(140*(1-d/9)*(self?.6:1)));
  }
  if(P&&P.alive&&Math.hypot(P.x-n.x,P.z-n.z)<14)G.shake=Math.max(G.shake,.7*(1-Math.hypot(P.x-n.x,P.z-n.z)/14));
 }else if(n.type==='fl'){
  sfx('bang',n.x,n.z,1);
  if(fxReady){for(let k=0;k<10;k++)fxA.emit(n.x,n.y+.3,n.z,rand(-3,3),rand(0,3),rand(-3,3),rand(.15,.3),.3,.8,1,1,.9,1,0,3);}
  flashLight.position.set(n.x,n.y+.5,n.z);flashLight.intensity=40;flashLight.color.set(0xffffff);flashLight.userData.t=.25;flashLight.userData.base=40;
  for(const v of ents){
   if(!v.alive)continue;
   const dx=n.x-v.x,dz=n.z-v.z,dy=n.y-(v.y+1.5),d=Math.hypot(dx,dy,dz);if(d>34)continue;
   if(rayWall(v.x,v.y+1.5,v.z,dx/d,dy/d,dz/d,d)<d-.4)continue;
   const fx=-Math.sin(v.yaw),fz=-Math.cos(v.yaw),facing=(fx*dx+fz*dz)/(Math.hypot(dx,dz)||1);
   const dur=(facing>.1?3.4:1.1)*clamp(1.25-d/30,.2,1);
   v.blindT=Math.max(v.blindT,dur);
   if(v.isPlayer){uiFlashBlind(dur);tinnitus(Math.min(5,dur*1.6));}
  }
 }else{
  sfx('smoke',n.x,n.z,.9);sfx('pop',n.x,n.z,.8);spawnSmoke(n.x,n.y,n.z);
 }
}
function clearNades(){for(const n of nades)scene.remove(n.m);nades.length=0;}
function locName(x,z){
 const cx=Math.floor(x/S),cz=Math.floor(z/S);
 for(const s of MAP.sites)if(Math.hypot(x-s.x,z-s.z)<s.rw)return 'Site '+s.n;
 return MAP.locName?MAP.locName(cx,cz,x,z):'';
}
MAPS.village.locName=(cx,cz,x,z)=>{
 if(cz<=10)return cx>=13&&cx<=26?'Spawn CT':cx<13?'Accès A':'Accès B';
 if(cz>=29)return cz>=31&&cx>=13&&cx<=26?'Spawn T':'Départ T';
 if(groundH(x,z)>2)return 'Hauteurs';
 if(cx<=6)return 'Grand couloir';if(cx>=33)return cz>=17&&cz<=24?'Souk couvert':'Couloir est';
 if(cx>=7&&cx<=13)return 'Ruelle';if(cx>=26&&cx<=32)return 'Rue du marché';
 return 'Place centrale';
};
MAPS.warehouse.locName=(cx,cz,x,z)=>{
 if(cz<=10)return cx>=13&&cx<=26?'Bureaux CT':cx<13?'Vestiaires':'Salle serveurs';
 if(cz>=31)return cx>=10&&cx<=29?'Quai T':cx<10?'Couloir ouest':'Couloir est';
 if(groundH(x,z)>2)return 'Mezzanine';
 if(cx<=9)return 'Stockage';if(cx>=30)return 'Contrôle';
 return 'Halle centrale';
};

/* ---------- bombe ---------- */
function bombVisual(){
 if(BM.mesh)return BM.mesh;
 const g=new THREE.Group();
 g.add(rb(.5,.14,.32,stdMat(0x2a2d33,{roughness:.5,metalness:.5}),0,.07,0,.02));
 const scr=new THREE.Mesh(GBOX,new THREE.MeshBasicMaterial({color:0xff2020,toneMapped:false}));scr.scale.set(.18,.05,.07);scr.position.set(0,.145,0);g.add(scr);g.userData.scr=scr;
 for(let i=0;i<3;i++){const b=cz(.03,.03,.28,stdMat(0xb8452a,{roughness:.6}),-.15+i*.15,.18,0,10);b.rotation.y=Math.PI/2;g.add(b);}
 const gl=new THREE.Sprite(new THREE.SpriteMaterial({map:GLOW.orange,color:0xff3030,blending:THREE.AdditiveBlending,transparent:true,depthWrite:false,toneMapped:false}));gl.scale.set(1.2,1.2,1);gl.position.y=.2;g.add(gl);g.userData.gl=gl;
 g.visible=false;scene.add(g);BM.mesh=g;return g;
}
function plantBomb(e){
 BM.state='planted';BM.x=e.x;BM.z=e.z;BM.y=groundH(e.x,e.z);BM.timer=BOMB_T;BM.site=inSite(e.x,e.z);BM.carrier=-1;BM.beep=0;
 const m=bombVisual();m.position.set(e.x,BM.y,e.z);m.visible=true;
 e.money=Math.min(16000,e.money+300);if(e.isPlayer){MS.plants++;metaEvent('plant');}
 sfx('plant',e.x,e.z,1.2);uiBanner('BOMBE POSÉE','Site '+MAP.sites[Math.max(0,BM.site)].n,2400,'#ffb938');
 const spots=[];
 for(let cz=0;cz<N;cz++)for(let cx=0;cx<N;cx++){if(!walkableCell(cz*N+cx))continue;const d=Math.hypot(cc(cx)-BM.x,cc(cz)-BM.z);if(d>5&&d<10&&Math.abs(NODEH[cz*N+cx]-BM.y)<.6)spots.push([cc(cx),cc(cz)]);}
 shuffle(spots);let i=0;
 for(const b of ents){if(b.isPlayer||!b.alive||b.team!==1)continue;const s=spots[i++%Math.max(1,spots.length)]||[BM.x,BM.z];b.retX=s[0];b.retZ=s[1];}
}
function inSite(x,z){for(let i=0;i<MAP.sites.length;i++){const s=MAP.sites[i];if(Math.hypot(x-s.x,z-s.z)<s.rw&&Math.abs(groundH(x,z)-groundH(s.x,s.z))<3.5)return i;}return -1;}
function defuseBomb(e){
 BM.state='defused';if(BM.mesh)BM.mesh.visible=false;e.money=Math.min(16000,e.money+300);if(e.isPlayer){MS.defuses++;metaEvent('plant');}
 sfx('defused');endRound(1,'Bombe désamorcée');
}
function explode(){
 netEvent({t:'boom',x:BM.x,y:BM.y,z:BM.z});
 BM.state='exploded';if(BM.mesh)BM.mesh.visible=false;
 sfx('boom',BM.x,BM.z,1.6);fxExplosion(BM.x,BM.y+.3,BM.z,2.2);G.shake=1;uiFlashBlind(.4);
 endRound(0,'La bombe a explosé');
 for(const v of ents){if(!v.alive)continue;const d=Math.hypot(v.x-BM.x,v.z-BM.z);if(d<16){v.hp-=Math.round(240*(1-d/16));if(v.hp<=0){v.alive=false;v.hp=0;v.deaths++;v.scoped=false;v.dieDir=Math.floor(Math.random()*4);if(v.rig)v.rig.dieT=-1;}}}
}
function handleUse(e,dt,holding){
 if(NET.role==='client'&&e.isPlayer&&G.netClient){e.useMsg='';return;}
 e.useMsg='';
 if(G.state!=='live'||G.mode!=='bomb'){e.prog=0;return;}
 let need=0,msg='';
 if(e.team===0&&BM.state==='carried'&&BM.carrier===e.id&&inSite(e.x,e.z)>=0&&e.onGround){need=PLANT_T;msg='POSE DE LA BOMBE';e.useMsg='Maintenez E : poser la bombe';}
 else if(e.team===1&&BM.state==='planted'&&Math.hypot(e.x-BM.x,e.z-BM.z)<1.8&&Math.abs(e.y-BM.y)<1.5){need=defT(e);msg='DÉSAMORÇAGE';e.useMsg='Maintenez E : désamorcer';}
 if(!need){e.prog=0;return;}
 if(holding){e.prog+=dt;e.progMsg=msg;if(e.prog>=need){e.prog=0;if(e.team===0)plantBomb(e);else defuseBomb(e);}}
 else e.prog=0;
}

/* ---------- flux de manche (mode compétitif) ---------- */
const TSPAWN_CACHE=[],CTSPAWN_CACHE=[];
function resetRound(){
 rpReset();netEvent({t:'rr'});for(const e of ents)e.tp=(e.tp||0)+1;
 G.round++;G.pistolRound=G.round===1;G.state='freeze';G.timer=G.freezeT;G.defuserId=-1;G.fetchId=-1;G.spec=null;G.countdownN=0;
 clearNades();resetFX();uiRoundStart();
 BM.state='carried';BM.carrier=-1;if(BM.mesh)BM.mesh.visible=false;
 const ts=shuffle(MAP.spawnT.slice()),cts=shuffle(MAP.spawnCT.slice());
 for(const e of ents){
  if(!e.keep){
   e.armor=0;e.shield=0;e.kit=false;e.nade={f:0,fl:0,sm:0,mn:0};e.wp.p=null;e.wp.s=null;giveWeapon(e,e.team===0?'glock':'usp');
   if(e.isPlayer){
    const ld=cfg.loadout;
    if(!cfg.eco){if(ld.p&&!G.pistolRound)giveWeapon(e,ld.p);if(ld.s)giveWeapon(e,ld.s);e.armor=100;}
    else if(ld.s&&W[ld.s].price<=300)giveWeapon(e,ld.s);
   }
  }
  for(const s of ['p','s']){const wi=e.wp[s];if(wi){const w=W[wi.k];wi.mag=w.mag;wi.res=w.res;}}
  if(!cfg.eco)e.money=16000;
  const sp=(e.team===0?ts:cts).pop()||[20,20];
  e.x=cc(sp[0]);e.z=cc(sp[1]);e.y=groundH(e.x,e.z);e.vy=0;e.onGround=true;e.alive=true;e.hp=100;e.reload=0;e.switchT=0;e.scoped=false;e.vx=e.vz=0;e.crouch=false;e.eyeH=1.6;e.speed=0;
  e.punchP=e.punchY=0;e.prog=0;e.target=null;e.lastSeen=null;e.path=null;e.spray=0;e.nextShot=0;e.bought=false;e.faceT=0;e.blindT=0;e.ads=0;e.invuln=0;
  e.emote=null;e.yaw=e.team===0?0:Math.PI;e.pitch=0;e.watch=e.yaw;e.buyAt=G.t+rand(.5,4);e.startDelay=rand(0,1.5);e.cur=bestSlot(e);e.keep=false;
  if(e.rig){e.rig.dieT=-1;e.rig.root.visible=!e.isPlayer;e.rig.root.rotation.x=0;e.rig.root.rotation.z=0;if(e.rig.gk!==curWi(e).k)setSoldierGun(e.rig,curWi(e).k);}
 }
 const tAlive=ents.filter(e=>e.team===0);BM.carrier=pick(tAlive).id;
 // plans
 G.plan=Math.floor(Math.random()*MAP.sites.length);
 const site=MAP.sites[G.plan],cand=[];
 for(let cz=0;cz<N;cz++)for(let cx=0;cx<N;cx++){if(!walkableCell(cz*N+cx))continue;const d=Math.hypot(cc(cx)-site.x,cc(cz)-site.z);if(d>2.5&&d<site.rw-.5&&Math.abs(NODEH[cz*N+cx]-groundH(site.x,site.z))<1)cand.push([cc(cx),cc(cz)]);}
 shuffle(cand);let ti=0,ci=0;
 for(const b of ents){
  if(b.isPlayer)continue;
  if(b.team===0){const s=cand[ti++%cand.length];b.holdX=s[0];b.holdZ=s[1];}
  else{const h=MAP.holdCT[ci++%MAP.holdCT.length],f=nearestFree(h[0],h[1]);b.holdX=cc(f[0]);b.holdZ=cc(f[1]);}
 }
 G.reportBuy=!buyOpen;
 if(G.pistolRound)uiBanner('MANCHE AU PISTOLET','Pistolets uniquement — achète avec B ('+G.freezeT+' s)',3200,'#ffd75e');
 else uiBanner('MANCHE '+G.round,'Phase d\'achat — touche B ('+G.freezeT+' s)',2600);sfx('round');
}
function checkEnd(){
 if(G.state!=='live'||G.mode!=='bomb')return;
 let aT=0,aC=0;for(const e of ents)if(e.alive){if(e.team===0)aT++;else aC++;}
 if(BM.state==='planted'){if(aC===0)endRound(0,'Défenseurs éliminés');}
 else{if(aT===0)endRound(1,'Attaquants éliminés');else if(aC===0)endRound(0,'Défenseurs éliminés');}
}
function endRound(win,reason){
 if(G.state!=='live')return;
 G.state='end';G.endT=5.5;G.score[win]++;G.roundWinner=win;
 // MVP
 let mvp=null;for(const e of ents)if(e.team===win&&(!mvp||e.kills>mvp.kills))mvp=e;G.mvpName=mvp?mvp.name:'';
 for(const e of ents){
  const bonus=e.team===win?3250:1400+500*Math.min(4,G.loss[e.team]);
  if(cfg.eco)e.money=Math.min(16000,e.money+bonus);
  e.keep=e.alive;
 }
 G.loss[win]=0;G.loss[1-win]++;celebrate(win);
 const mine=win===P.team;
 NET.mute=1;uiBanner(mine?'MANCHE GAGNÉE':'MANCHE PERDUE',reason,4600,mine?'#7dff9f':'#ff6b6b');NET.mute=0;netEvent({t:'rend',w:win,r:reason});
 sfx(mine?'win':'lose');uiRoundEnd();closeBuy(true);
 rpStart();
}
function afterEnd(){
 if(G.mode==='bomb'){
  if(G.score[0]>=G.limit||G.score[1]>=G.limit){matchOver();return;}
  resetRound();
 }else matchOver();
}
function matchOver(){
 G.state='over';G.running=false;
 netMatchOver();
 if(document.pointerLockElement)document.exitPointerLock();
 uiMatchOver();
}

/* ---------- joueur ---------- */
let bobT=0;
function updatePlayer(dt){
 const p=P;
 tickWeapon(p,dt);
 if(!p.alive){p.speed=0;return;}
 const w=curW(p);
 const dr=(G.t-p.lastShot<.2)?3.5:9;
 p.punchP-=p.punchP*Math.min(1,dt*dr);p.punchY-=p.punchY*Math.min(1,dt*dr);
 if(buyOpen){p.speed=0;return;}
 let fx=0,fz=0;
 if(K('forward'))fz+=1;if(K('back'))fz-=1;if(K('right'))fx+=1;if(K('left'))fx-=1;
 const L=Math.hypot(fx,fz)||1;fx/=L;fz/=L;
 if(p.emote){updateEmote(dt,fx||fz);if(p.emote)return;}
 const wantCrouch=K('crouch');
 if(p.crouch&&!wantCrouch&&ceilAt(p.x,p.z)-p.y<1.8){}else p.crouch=wantCrouch;
 p.eyeH+=((p.crouch?1.15:1.6)-p.eyeH)*Math.min(1,dt*14);
 let spd=RUN*w.spd*spdMul(p);if(K('walk'))spd*=.5;if(p.crouch)spd*=.5;spd*=1-.25*p.ads;
 if(G.state==='freeze'&&G.mode==='bomb')spd=0;
 const tx=(-Math.sin(p.yaw)*fz+Math.cos(p.yaw)*fx)*spd,tz=(-Math.cos(p.yaw)*fz-Math.sin(p.yaw)*fx)*spd;
 const ac=Math.min(1,dt*(p.onGround?12:2.2));
 p.vx+=(tx-p.vx)*ac;p.vz+=(tz-p.vz)*ac;
 moveEnt(p,p.vx,p.vz,dt);
 p.speed=Math.hypot(p.vx,p.vz);
 if(K('jump')&&p.onGround&&!(G.state==='freeze'&&G.mode==='bomb')){p.vy=JUMPV;p.onGround=false;sfx('jump');}
 physics(p,dt);
 if(p.onGround&&p.speed>3.2&&!K('walk')&&!p.crouch){p.stepT-=dt;if(p.stepT<=0){p.stepT=.4;sfx('step',p.x,p.z,.28,surfaceAt(p.x,p.z));}}
 bobT+=dt*p.speed*1.6;
 if(mouseL&&G.state!=='end'||clickLatch){
  if(w.auto||clickLatch){if(shoot(p))clickLatch=false;else if(!w.auto)clickLatch=false;}
 }
 if(!mouseL)clickLatch=false;
 const wantAds=(mouseR||G.forceAds)&&p.reload<=0&&p.switchT<=0&&!w.melee;
 p.ads+=((wantAds?1:0)-p.ads)*Math.min(1,dt*(w.overlay?7:12));
 p.scoped=!!(w.overlay&&p.ads>.92);
 handleUse(p,dt,K('use')&&p.speed<1.2);
}

/* ---------- vision du joueur pour le radar ---------- */
let radarT=0;
function updateSpotting(dt){
 radarT-=dt;if(radarT>0)return;radarT=.12;
 if(!P.alive)return;
 const ex=P.x,ey=P.y+P.eyeH,ez=P.z,fx=-Math.sin(P.yaw),fz=-Math.cos(P.yaw);
 for(const e of ents){
  if(!e.alive||e.team===P.team)continue;
  const dx=e.x-ex,dz=e.z-ez,dist=Math.hypot(dx,dz);
  if((dx*fx+dz*fz)/(dist||1)<.2)continue;
  if(losClear(ex,ey,ez,e.x,e.y+1.1,e.z))e.spotT=G.t+1.4;
 }
}

/* ---------- démarrage de partie ---------- */
MAPS.station.locName=(cx,cz,x,z)=>{
 if(cz<=8&&cx>=13&&cx<=26)return 'Base CT';
 if(cz<=12)return cx<13?'Accès hangar':'Accès générateurs';
 if(cz>=31)return cz>=33&&cx>=13&&cx<=26?'Camp T':'Cours sud';
 if(groundH(x,z)>2)return 'Hauteurs';
 if(cx<=10)return 'Sentier ouest';if(cx>=29)return cz>=20&&cz<=26?'Tunnel de glace':'Sentier est';
 if(cx>=16&&cx<=23&&cz>=19&&cz<=25)return 'Étang gelé';
 return 'Cour centrale';
};

/* ---------- emotes / danses ---------- */
function startEmote(){
 if(!P.alive||P.emote||buyOpen||!P.onGround||(G.mode==='bomb'&&G.state==='live'&&P.target))return;
 const d=DANCES.find(x=>x.id===PROF.dance)||DANCES[0];
 P.emote={id:d.id,t:0,dur:d.len};P.rig.root.visible=true;mouseL=false;clickLatch=false;P.scoped=false;P.ads=0;
}
function updateEmote(dt,mv){
 const p=P,em=p.emote;em.t+=dt;p.vx*=.8;p.vz*=.8;p.speed=0;physics(p,dt);
 if(em.t>em.dur||(em.t>.45&&(mv||mouseL))||G.t-p.lastHurtT<.06||!p.alive){p.emote=null;if(p.rig)p.rig.root.visible=false;}
}
function celebrate(win){
 for(const e of ents){
  if(!e.alive||e.team!==win)continue;
  const d=pick(DANCES);
  if(e.isPlayer){if(!e.emote){const dd=DANCES.find(x=>x.id===PROF.dance)||DANCES[0];e.emote={id:dd.id,t:0,dur:Math.min(dd.len,4)};e.rig.root.visible=true;}}
  else e.emote={id:d.id,t:rand(0,.6),dur:5};
 }
}
