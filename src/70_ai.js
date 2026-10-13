/* =====================================================================
   IA DES BOTS : objectifs (bombe), combat, déplacement avec relief,
   grenades, modes à mort (errance, ramassables)
   ===================================================================== */
const carrier2=b=>BM.state==='carried'&&BM.carrier===b.id;
function botBuy(b){
 b.bought=true;
 const aff=Object.keys(W).filter(k=>W[k].slot===0&&!W[k].wonder&&W[k].price<=b.money);
 if(!b.wp.p&&aff.length&&!(cfg.eco&&b.money<1800&&Math.random()<.5)){
  const wt={rifle:5,smg:2.4,sniper:1,shotgun:1,lmg:.5};
  const weighted=aff.map(k=>[k,cfg.diff<=1?1:(wt[W[k].cat]||1)*(k==='awp'?.8:1)]);
  const tot=weighted.reduce((s,a)=>s+a[1],0);let r=Math.random()*tot,ch=weighted[0][0];
  for(const a of weighted){r-=a[1];if(r<=0){ch=a[0];break;}}
  buyItem(b,ch);
 }else if(!b.wp.p&&b.money>=700&&Math.random()<.5)buyItem(b,pick(['p250','fiveseven','deagle']));
 if(b.armor<100&&b.money>=650&&Math.random()<.85)buyItem(b,'armor');
 if(b.money>=1000&&Math.random()<.35)buyItem(b,'shield2');else if(b.money>=400&&Math.random()<.4)buyItem(b,'shield1');
 if(b.team===1&&b.money>=400&&Math.random()<.6)buyItem(b,'kit');
 if(b.money>=300&&Math.random()<.55)buyItem(b,'frag');
 if(b.money>=300&&Math.random()<.3)buyItem(b,'smoke');
 if(b.money>=200&&Math.random()<.3)buyItem(b,'flash');
 if(b.money>=MINE_PRICE&&Math.random()<.25)buyItem(b,'mine');
 b.cur=bestSlot(b);
}
function botSee(b){
 if(b.blindT>0)return;
 const d=b.diff,ex=b.x,ey=b.y+eyeOf(b),ez=b.z;let best=null,bd=1e9;
 const fwx=-Math.sin(b.yaw),fwz=-Math.cos(b.yaw);
 for(const e of ents){
  if(!e.alive||e.team===b.team||e.invuln>0)continue;
  const dx=e.x-b.x,dz=e.z-b.z,dist=Math.hypot(dx,dz);
  if(dist>d.sight)continue;
  if((dx*fwx+dz*fwz)/(dist||1)<.35&&dist>3)continue;
  if(!losClear(ex,ey,ez,e.x,e.y+(e.crouch?.85:1.15),e.z))continue;
  if(dist<bd){bd=dist;best=e;}
 }
 if(best){
  if(b.target!==best){b.target=best;b.seeT=0;b.aimHead=Math.random()<d.aimHead;b.mvT=0;}
  b.targetT=G.t;b.lastSeen={x:best.x,z:best.z,t:G.t};best.spotT=G.t+1.4;
  for(const m of ents){if(m!==b&&m.alive&&!m.isPlayer&&m.team===b.team&&!m.target&&Math.hypot(m.x-b.x,m.z-b.z)<30&&Math.random()<.5)m.lastSeen={x:best.x,z:best.z,t:G.t};}
 }
}
function botGoal(b){
 if(G.mode==='bomb'){
  if(b.team===0){
   if(BM.state==='dropped'&&G.fetchId===b.id)return {x:BM.x,z:BM.z};
   if(BM.state==='carried'&&BM.carrier===b.id){const s=MAP.sites[G.plan];return {x:s.x,z:s.z,plant:true};}
   return {x:b.holdX,z:b.holdZ,watch:0};
  }
  if(BM.state==='planted'){
   if(G.defuserId===b.id)return {x:BM.x,z:BM.z,defuse:true};
   return {x:b.retX||BM.x,z:b.retZ||BM.z,watch:Math.atan2(-(BM.x-b.retX),-(BM.z-b.retZ))};
  }
  return {x:b.holdX,z:b.holdZ,watch:Math.PI};
 }
 // variantes : bataille royale (zone + butin) et capture de zone
 if(G.variant==='br'){
  const z=BRZ,dz=Math.hypot(b.x-z.cx,b.z-z.cz);
  if(dz>z.r-5)return {x:z.cx+rand(-3,3),z:z.cz+rand(-3,3)};
  if(!b.wp.p){let best=null,bd=70;for(const p of pickups){if(!p.on||p.type!=='weapon')continue;const dd=Math.hypot(p.x-b.x,p.z-b.z);if(dd<bd){bd=dd;best=p;}}if(best)return {x:best.x,z:best.z,pick:true};}
  if(b.armor<1||b.hp<60){let best=null,bd=40;for(const p of pickups){if(!p.on||p.type==='weapon'||p.type==='ammo')continue;const dd=Math.hypot(p.x-b.x,p.z-b.z);if(dd<bd){bd=dd;best=p;}}if(best)return {x:best.x,z:best.z,pick:true};}
 }
 // modes à mort : errance + ramassables + chasse
 if((b.hp<55||b.shield<=0&&b.hp<100)&&pickups.length){
  let best=null,bd=40;for(const p of pickups){if(!p.on)continue;if(p.type==='ammo'&&b.hp<55)continue;if(p.type==='health'&&b.hp>=95)continue;const dd=Math.hypot(p.x-b.x,p.z-b.z);if(dd<bd){bd=dd;best=p;}}
  if(best)return {x:best.x,z:best.z,pick:true};
 }
 if(G.t>b.roamT||Math.hypot(b.roamX-b.x,b.roamZ-b.z)<1.6){
  let tx,tz;
  if(G.variant==='koth'){const z=kothZone();tx=z.x+rand(-z.r*.7,z.r*.7);tz=z.z+rand(-z.r*.7,z.r*.7);}
  else if(Math.random()<.45){const foes=ents.filter(e=>e.alive&&e.team!==b.team);if(foes.length){const f=pick(foes);tx=f.x+rand(-6,6);tz=f.z+rand(-6,6);}}
  if(tx===undefined){const r=pick(MAP.roam);tx=cc(r[0]);tz=cc(r[1]);}
  b.roamX=tx;b.roamZ=tz;b.roamT=G.t+rand(7,15);
 }
 return {x:b.roamX,z:b.roamZ};
}
function botGo(b,dt,gx,gz,spd){
 if(!b.path||Math.hypot(b.gx-gx,b.gz-gz)>1.5||G.t>b.repathT){
  const p=findPath(b.x,b.z,gx,gz);
  b.path=p||[[b.x,b.z],[gx,gz]];b.pi=1;b.gx=gx;b.gz=gz;b.repathT=G.t+rand(2.5,4);
 }
 if(Math.hypot(gx-b.x,gz-b.z)<.8)return true;
 while(b.pi<b.path.length-1&&Math.hypot(b.path[b.pi][0]-b.x,b.path[b.pi][1]-b.z)<.6)b.pi++;
 const p=b.path[Math.min(b.pi,b.path.length-1)],dx=p[0]-b.x,dz=p[1]-b.z,L=Math.hypot(dx,dz)||1;
 botMove(b,dx/L*spd,dz/L*spd,dt);
 return false;
}
function botMove(b,vx,vz,dt){
 for(const o of ents){if(o===b||!o.alive)continue;const dx=b.x-o.x,dz=b.z-o.z,d=Math.hypot(dx,dz);if(d<.8&&d>.01&&Math.abs(o.y-b.y)<1.5){vx+=dx/d*(.8-d)*4;vz+=dz/d*(.8-d)*4;}}
 b.vx+=(vx-b.vx)*Math.min(1,dt*10);b.vz+=(vz-b.vz)*Math.min(1,dt*10);
 const ox=b.x,oz=b.z;moveEnt(b,b.vx,b.vz,dt);physics(b,dt);
 b.speed=Math.hypot(b.vx,b.vz);
 b.stuckT+=Math.hypot(b.x-ox,b.z-oz);
 if(b.speed>3.2&&b.onGround&&!b.crouch){b.stepT-=dt;if(b.stepT<=0){b.stepT=.4;sfx('step',b.x,b.z,.5,surfaceAt(b.x,b.z));}}
}
function turnTo(b,wy,wp,rate,dt){
 const k=Math.min(1,dt*12),mx=rate*dt;
 b.yaw+=clamp(angDiff(b.yaw,wy)*k,-mx,mx);
 if(wp!==null)b.pitch+=clamp((wp-b.pitch)*k,-mx,mx);
}
function botUpdate(b,dt){
 if(!b.alive){return;}
 tickWeapon(b,dt);
 if(b.emote){b.emote.t+=dt;b.speed=0;b.vx*=.8;b.vz*=.8;physics(b,dt);if(b.emote.t>b.emote.dur)b.emote=null;return;}
 const d=b.diff;
 if(G.state==='freeze'){
  if(G.mode==='bomb'){if(!b.bought&&G.t>=b.buyAt)botBuy(b);}
  physics(b,dt);b.speed=0;turnTo(b,b.watch,0,3,dt);return;
 }
 if(G.state!=='live'){physics(b,dt);b.speed=0;b.vx*=.8;b.vz*=.8;return;}
 if(b.startDelay>0){b.startDelay-=dt;b.speed=0;physics(b,dt);return;}
 if(b.blindT>0){b.blindT-=dt;b.target=null;b.vx*=.9;b.vz*=.9;b.speed*=.9;b.prog=0;physics(b,dt);return;}
 b.visT-=dt;if(b.visT<=0){b.visT=.09+Math.random()*.04;botSee(b);}
 if(b.target&&(!b.target.alive||G.t-b.targetT>.4||b.target.invuln>0))b.target=null;
 if(b.faceT>0)b.faceT-=dt;
 const w=curW(b),wi=curWi(b);
 if(b.team===0&&G.mode==='bomb'&&BM.state==='dropped'&&Math.hypot(BM.x-b.x,BM.z-b.z)<1.4){BM.state='carried';BM.carrier=b.id;}
 b.sx=(b.sx||0)+dt;if(b.sx>1){if(b.stuckT<.4&&b.path&&b.speed<.5&&!b.target)b.repathT=0;b.stuckT=0;b.sx=0;}
 // bots sans arme principale utilisable → pistolet / couteau
 if(!w.melee&&wi.mag<=0&&wi.res<=0){if(b.wp.s&&b.cur!=='s')switchTo(b,'s');else if(b.cur!=='k')switchTo(b,'k');}

 if(b.target){
  b.seeT+=dt;
  const t=b.target,dx=t.x-b.x,dz=t.z-b.z,dist=Math.hypot(dx,dz);
  const ty=t.y+(b.aimHead?1.64:1.1)*(t.crouch?.75:1);
  const wy=Math.atan2(-dx,-dz),wp=Math.atan2(ty-(b.y+eyeOf(b)),dist);
  const ready=b.seeT>=d.react;
  turnTo(b,wy,wp,ready?d.turn*RAD:d.turn*RAD*.25,dt);
  const carrier=carrier2(b);
  const atObj=G.mode==='bomb'&&((carrier&&inSite(b.x,b.z)>=0)||(BM.state==='planted'&&b.team===1&&G.defuserId===b.id&&Math.hypot(b.x-BM.x,b.z-BM.z)<1.8));
  if(atObj&&dist>13&&b.hp>35){handleUse(b,dt,true);botMove(b,0,0,dt);if(b.prog>0)return;}
  // grenades en combat : flash avant de pousser, fumée quand on est blessé
  if(G.t>b.nadeT){
   if(b.nade.fl&&dist>9&&dist<24&&Math.random()<dt*.5*d.nade){b.nadeT=G.t+4;throwNade(b,'fl',t.x,t.z);}
   else if(b.nade.sm&&b.hp<40&&dist>6&&Math.random()<dt*1.2*d.nade){b.nadeT=G.t+6;throwNade(b,'sm',b.x+(t.x-b.x)*.35,b.z+(t.z-b.z)*.35);}
  }
  // mouvement de combat
  b.mvT-=dt;
  if(b.mvT<=0){
   if(b.mvMode===1){b.mvMode=0;b.mvT=rand(.3,.7);}
   else if(Math.random()<d.strafe&&!w.overlay){b.mvMode=1;b.strafeDir=-b.strafeDir;b.mvT=rand(.25,.5);}
   else b.mvT=rand(.3,.8);
  }
  // accroupi pour tirer (pros)
  const wantCr=!w.overlay&&dist>12&&b.mvMode===0&&Math.random()<d.crouch*dt*3?true:(b.mvMode===1?false:b.crouch);
  b.crouch=d.crouch>0&&wantCr&&dist>10;
  const sp=RUN*d.speed*w.spd*(b.crouch?.5:1)*spdMul(b);
  let mvx=0,mvz=0;
  const prefer=w.cat==='shotgun'?7:w.cat==='smg'?14:w.cat==='pistol'?20:70;
  if(b.mvMode===1&&!b.crouch){mvx=-dz/dist*b.strafeDir*sp*.6;mvz=dx/dist*b.strafeDir*sp*.6;}
  else if(dist>prefer){mvx=dx/dist*sp*.6;mvz=dz/dist*sp*.6;}
  const site=MAP.sites[G.plan];
  // repli quand on est presque mort (modes à mort)
  if(G.mode!=='bomb'&&b.hp<28&&dist<30){mvx=-dx/dist*sp*.9;mvz=-dz/dist*sp*.9;}
  if(G.mode==='bomb'&&carrier&&dist>14&&Math.hypot(site.x-b.x,site.z-b.z)>3&&b.mvMode===0)botGo(b,dt,site.x,site.z,sp*.8);
  else if(G.mode==='bomb'&&BM.state==='planted'&&G.defuserId===b.id&&b.team===1&&dist>16&&b.mvMode===0&&Math.hypot(BM.x-b.x,BM.z-b.z)>1.5)botGo(b,dt,BM.x,BM.z,sp*.8);
  else botMove(b,mvx,mvz,dt);
  const ey=Math.abs(angDiff(b.yaw,wy)),ep=Math.abs(wp-b.pitch);
  const tol=Math.atan(.3/Math.max(dist,1.5))+d.spread*RAD*.4+.01;
  const canFire=ready&&ey<tol*1.4&&ep<tol*2&&!(d.strafe>=.8&&b.mvMode===1&&w.cat!=='shotgun');
  if(b.burstPause>0)b.burstPause-=dt;
  else if(canFire){
   if(wi.mag<=0){if(wi.res<=0){}else startReload(b);}
   else{
    const gap=w.auto?0:d.semi;
    if(G.t>=b.nextShot&&(w.auto||G.t-b.lastShot>=gap)){
     if(shoot(b)){b.burstN++;if(b.burstN>=b.burstMax){b.burstN=0;b.burstMax=Math.floor(rand(d.bmin,d.bmax+1));b.burstPause=rand(d.pmin,d.pmax);}}
    }
   }
  }
  // couteau : charger l'ennemi proche
  if(w.melee&&dist<3)shoot(b);
  b.prog=0;
  return;
 }
 b.spray=Math.max(0,b.spray-dt*10);b.crouch=false;
 if(wi.mag<w.mag*.35&&!w.melee&&wi.res>0)startReload(b);
 let goal=botGoal(b),watch=goal.watch;
 if(b.faceT>0){turnTo(b,b.faceYaw,0,d.turn*RAD,dt);b.speed*=.9;b.vx*=.85;b.vz*=.85;physics(b,dt);return;}
 // grenade sur la dernière position connue
 if(b.nade.f&&G.t>b.nadeT&&b.lastSeen&&G.t-b.lastSeen.t<4){
  const dd=Math.hypot(b.lastSeen.x-b.x,b.lastSeen.z-b.z);
  if(dd>9&&dd<26&&Math.random()<dt*.8*d.nade){b.nadeT=G.t+5;throwNade(b,'f',b.lastSeen.x,b.lastSeen.z);}
 }
 const ls=b.lastSeen;
 const farFromJob=G.mode==='bomb'&&ls&&((b.team===0&&BM.state==='planted'&&Math.hypot(ls.x-BM.x,ls.z-BM.z)>16)||(b.team===1&&BM.state!=='planted'&&Math.hypot(ls.x-b.holdX,ls.z-b.holdZ)>16)||carrier2(b));
 if(ls&&!farFromJob&&G.t-ls.t<7&&Math.hypot(b.x-ls.x,b.z-ls.z)>3&&!goal.plant&&!goal.defuse&&!goal.pick){goal={x:ls.x,z:ls.z};watch=undefined;}
 const arrived=Math.hypot(goal.x-b.x,goal.z-b.z)<.8;
 if(!arrived){
  const sp=RUN*d.speed*w.spd*(ls&&G.t-ls.t<7?1:.9)*spdMul(b);
  botGo(b,dt,goal.x,goal.z,sp);
  if(Math.hypot(b.vx,b.vz)>.3)turnTo(b,Math.atan2(-b.vx,-b.vz),0,9,dt);
  b.prog=0;
 }else{
  b.vx*=.8;b.vz*=.8;b.speed=0;physics(b,dt);
  if(goal.plant||goal.defuse){handleUse(b,dt,true);if(b.prog>0)turnTo(b,b.yaw,0,1,dt);}
  else{handleUse(b,dt,false);turnTo(b,(watch===undefined?b.yaw:watch)+Math.sin(G.t*.6+b.id*2)*.55,0,2.2,dt);}
 }
}
