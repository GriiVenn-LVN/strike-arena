/* =====================================================================
   MODE INFECTÉ (façon Call of Duty / Roblox)
   - Tout le monde commence survivant (armes normales). Après le compte
     à rebours, un joueur au hasard devient l'infecté.
   - Infectés : couteau seulement, plus rapides, réapparaissent.
   - Un survivant tué rejoint les infectés.
   - Les infectés gagnent s'il ne reste plus de survivant ; les
     survivants gagnent s'il en reste au moins un à la fin du chrono.
   Variante du mode « tdm » (équipes, réapparition).
   ===================================================================== */
MODES.inf={n:'Infecté',ic:'☣',c:'#9dff5a',team:true,respawn:2.5,desc:'Un joueur commence infecté. Chaque survivant tué rejoint les infectés. Tiens jusqu\'à la fin du chrono.',limitLabel:'',limits:[]};
VARIANT_BASE.inf='tdm';NOKILLSCORE.inf=1;
MODE_GROUPS[2][1].splice(1,0,'inf');MODE_TAG.inf='Survis aux infectés';
if(typeof RTIME!=='undefined')RTIME.inf={l:'Durée de la partie',o:[3,5,8],d:5,u:'min'};
const INF={started:false,startT:0,glow:new Map()};
const isInf=()=>G.variant==='inf';

function infCount(){let s=0,i=0;for(const e of ents){if(e.team===0)s++;else i++;}G.score=[s,i];return s;}
function infLook(e){
 if(!e.rig)return;
 if(!e.rig.root.userData.infGlow){const g=zGlow(0x9dff5a,1.1);if(g){g.position.y=1.2;e.rig.root.add(g);e.rig.root.userData.infGlow=g;}}
}
function infArm(e){ // infecté : couteau seulement, plus rapide
 e.wp.p=null;e.wp.s=null;e.cur='k';e.nade={f:0,fl:0,sm:0,mn:0};e.armor=0;e.shield=0;e.perks={stamin:1};
 if(e.isPlayer)vmDraw&&vmDraw();
}
function infTurn(e,first){
 e.team=1;e.keep=false;
 // un mort garde son corps au sol : on change son apparence à la réapparition
 if(e.alive){attachRig(e);infLook(e);infArm(e);}else e._infRig=true;
 if(e.isPlayer)for(const o of ents)if(o.rig&&o.rig.label)o.rig.label.visible=o.team===P.team;
 if(first){
  const me=e.isPlayer;
  uiBanner(me?'TU ES L\'INFECTÉ':e.name.toUpperCase()+' EST INFECTÉ',me?'Contamine tout le monde au couteau':'Survis jusqu\'à la fin du chrono',2600,'#9dff5a');sfx('alarm');
 }else if(e.isPlayer)uiBanner('TU ES INFECTÉ','Contamine les survivants',2000,'#9dff5a');
}
// au départ, tout le monde est survivant
const _variantPostSpawnInf=variantPostSpawn;
variantPostSpawn=function(){
 _variantPostSpawnInf();
 if(!isInf())return;
 INF.started=false;INF.startT=G.t+(G.timer||3)+2;
 for(const e of ents){if(e.team!==0){e.team=0;attachRig(e);}}
 if(P.rig)P.rig.root.visible=false;
 infCount();
};
const _respawnInf=respawn;
respawn=function(e){
 if(isInf()&&e._infRig){e._infRig=false;attachRig(e);}
 _respawnInf(e);
 if(isInf()&&e.team===1){infArm(e);infLook(e);}
};
const _variantKillInf=variantKill;
variantKill=function(att,v,w,hs){
 _variantKillInf(att,v,w,hs);
 if(!isInf())return;
 if(v.team===0&&INF.started){infTurn(v,false);if(att&&att.isPlayer&&att!==v)uiToast('Survivant contaminé');}
 if(infCount()===0&&G.state==='live'){G.winner=1;endDM();}
};
const _variantUpdateInf=variantUpdate;
variantUpdate=function(dt,t){
 _variantUpdateInf(dt,t);
 if(!isInf()||G.state!=='live')return;
 if(!INF.started&&G.t>=INF.startT){
  INF.started=true;const alive=ents.filter(e=>e.alive);const z=pick(alive.length?alive:ents);infTurn(z,true);
  for(const b of ents)if(!b.isPlayer)b.target=null;
 }
 infCount();
};
const _variantTimeUpInf=variantTimeUp;
variantTimeUp=function(){
 if(!isInf())return _variantTimeUpInf();
 G.winner=infCount()>0?0:1;
 if(G.winner===0&&P.team===0&&!G.netClient)metaEvent('inf_surv');
 endDM();return true;
};
const _variantSubInf=variantSub;
variantSub=function(){return isInf()?'Un joueur va être infecté… survis jusqu\'à la fin':_variantSubInf();};
// bots infectés : ils foncent au couteau sur le survivant le plus proche
const _botUpdateInf=botUpdate;
botUpdate=function(b,dt){
 if(!isInf()||b.team!==1||!b.alive||G.state!=='live')return _botUpdateInf(b,dt);
 tickWeapon(b,dt);
 if(b.blindT>0){b.blindT-=dt;b.vx*=.9;b.vz*=.9;physics(b,dt);return;}
 let t=null,bd=1e9;for(const e of ents){if(!e.alive||e.team!==0)continue;const d=Math.hypot(e.x-b.x,e.z-b.z)+(Math.abs(e.y-b.y)>2?6:0);if(d<bd){bd=d;t=e;}}
 if(!t){botMove(b,0,0,dt);return;}
 const sp=RUN*.97*(b.diff?b.diff.speed:1);
 if(bd>1.3)botGo(b,dt,t.x,t.z,sp);else botMove(b,0,0,dt);
 const wy=Math.atan2(-(t.x-b.x),-(t.z-b.z)),wp=Math.atan2(t.y+1.1-(b.y+eyeOf(b)),Math.max(bd,.5));
 if(bd<4)turnTo(b,wy,wp,12,dt);else if(Math.hypot(b.vx,b.vz)>.3)turnTo(b,Math.atan2(-b.vx,-b.vz),0,9,dt);
 if(bd<1.9&&Math.abs(angDiff(b.yaw,wy))<.45)shoot(b);
};
// les infectés ne ramassent pas d'armes
const _updatePickupsInf=updatePickups;
updatePickups=function(dt,t){
 if(!isInf())return _updatePickupsInf(dt,t);
 const inf=ents.filter(e=>e.team===1&&e.alive);for(const e of inf)e._pkA=e.alive,e.alive=false;
 try{_updatePickupsInf(dt,t);}finally{for(const e of inf)e.alive=e._pkA;}
};
const _variantInitInf=variantInit;
variantInit=function(){_variantInitInf();if(isInf())G.limit=1e9;}; // pas de limite de score : fin au chrono ou quand tout le monde est infecté
