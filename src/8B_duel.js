/* =====================================================================
   MODE DUEL (façon RIVALS) : 1v1 à 5v5, manches courtes sans bombe,
   sans réapparition. Premier à 5 manches (3 / 5 / 7 au choix).
   - Phase de préparation de 6 s : on choisit son arme (touche B, gratuit).
   - Manche de 60 s ; à 20 s de la fin, les positions sont révélées.
   - Temps écoulé : l'équipe avec le plus de survivants, puis le plus de
     points de vie, gagne la manche.
   Variante du mode « bomb » : réutilise le flux de manche existant en
   neutralisant la bombe, sans modifier les fichiers de base.
   ===================================================================== */
MODES.duel={n:'Duel',ic:'🤺',c:'#ff7ad9',team:true,desc:'Manches courtes sans bombe ni réapparition. Choisis ton arme, élimine l\'adversaire. Premier à 5.',limitLabel:'Manches pour gagner',limits:[3,5,7]};
VARIANT_BASE.duel='bomb';
RANKED_MODES.duel=1;
const DUEL={ROUND:60,FREEZE:6,REVEAL:20,revealed:false};
const isDuel=()=>G.variant==='duel';

// nombre de manches : réglage propre au duel
const _limitOfBase=limitOf;
limitOf=function(mode){return mode==='bomb'&&cfg.mode==='duel'?_limitOfBase('duel'):_limitOfBase(mode);};
// taille des équipes : réglage propre au duel (1 v 1 par défaut)
const _startMatchBase=startMatch;
startMatch=function(){
 if(cfg.mode!=='duel')return _startMatchBase();
 const s=cfg.size;cfg.size=cfg.duelSize||1;
 try{_startMatchBase();}finally{cfg.size=s;}
};
const _variantInitBase=variantInit;
variantInit=function(){
 _variantInitBase();
 if(!isDuel())return;
 G.roundT=DUEL.ROUND;G.freezeT=DUEL.FREEZE;
 for(const e of ents)e.money=16000;
};
const _resetRoundBase=resetRound;
resetRound=function(){
 _resetRoundBase();
 if(!isDuel())return;
 DUEL.revealed=false;G.pistolRound=false;
 BM.state='none';BM.carrier=-1;if(BM.mesh)BM.mesh.visible=false;
 for(const e of ents){
  e.money=16000;
  if(e.isPlayer&&!e.keep){const ld=cfg.loadout;if(ld.p)giveWeapon(e,ld.p);if(ld.s)giveWeapon(e,ld.s);e.armor=100;e.cur=bestSlot(e);}
  else if(!e.isPlayer)e.armor=100;
 }
 NET.mute=1;uiBanner('MANCHE '+G.round,'Premier à '+G.limit+' — touche B pour changer d\'arme ('+G.freezeT+' s)',2600,'#ff7ad9');NET.mute=0;
};
// fin de manche : raison lisible + départage au temps
const _endRoundBase=endRound;
endRound=function(win,reason){
 if(!isDuel()||G.state!=='live')return _endRoundBase(win,reason);
 if(reason==='Temps écoulé'){
  const al=[0,0],hp=[0,0];for(const e of ents)if(e.alive){al[e.team]++;hp[e.team]+=e.hp;}
  win=al[0]!==al[1]?(al[0]>al[1]?0:1):hp[0]!==hp[1]?(hp[0]>hp[1]?0:1):(Math.random()<.5?0:1);
  reason='Temps écoulé — '+(al[0]!==al[1]?'plus de survivants':'plus de points de vie');
 }else reason=win===P.team?'Adversaire éliminé':'Ton équipe est éliminée';
 _endRoundBase(win,reason);
};
// bots : ils chassent l'adversaire au lieu de tenir un site
const _botGoalBase=botGoal;
botGoal=function(b){
 if(!isDuel())return _botGoalBase(b);
 const ls=b.lastSeen;
 if(ls){b.holdX=ls.x;b.holdZ=ls.z;}
 if(ls&&G.t-ls.t<6)return {x:ls.x,z:ls.z};
 if(G.t>b.roamT||Math.hypot(b.roamX-b.x,b.roamZ-b.z)<1.6){
  const foes=ents.filter(e=>e.alive&&e.team!==b.team);
  if(foes.length){const f=pick(foes),r=DUEL.revealed?3:10;b.roamX=f.x+rand(-r,r);b.roamZ=f.z+rand(-r,r);}
  else{const r=pick(MAP.roam);b.roamX=cc(r[0]);b.roamZ=cc(r[1]);}
  b.roamT=G.t+rand(4,7);
 }
 return {x:b.roamX,z:b.roamZ};
};
// révélation des positions en fin de manche
const _variantUpdateBase=variantUpdate;
variantUpdate=function(dt,t){
 _variantUpdateBase(dt,t);
 if(!isDuel()||G.state!=='live')return;
 if(G.timer<=DUEL.REVEAL){
  if(!DUEL.revealed){DUEL.revealed=true;uiBanner('POSITIONS RÉVÉLÉES','Plus que '+DUEL.REVEAL+' s',1800,'#ff7ad9');sfx('tick');for(const b of ents)if(!b.isPlayer)b.roamT=0;}
  for(const e of ents)if(e.alive){e.spotT=G.t+.5;for(const o of ents)if(!o.isPlayer&&o.alive&&o.team!==e.team)o.lastSeen={x:e.x,z:e.z,t:G.t-6.5};}
 }
};
// cinématique d'ouverture : titres adaptés
const _updateCineBase=updateCine;
updateCine=function(dt,t){
 _updateCineBase(dt,t);
 if(isDuel()&&$('cine').classList.contains('t2')){setHTML('cineT','ÉLIMINE L\'ADVERSAIRE');setHTML('cineS','Premier à '+G.limit+' manches');}
};
const _endCineBase=endCine;
endCine=function(){
 _endCineBase();
 if(isDuel())uiBanner('DUEL','Premier à '+G.limit+' — touche B pour changer d\'arme',2400,'#ff7ad9');
};
// menu : tuile dans « Compétitif », taille 1 v 1 à 5 v 5
MODE_GROUPS[0][1].push('duel');
MODE_TAG.duel='Manches courtes, 1 v 1 à 5 v 5, sans bombe';
const _drawMenuBase=drawMenu;
drawMenu=function(){
 _drawMenuBase();
 if(cfg.mode!=='duel')return;
 $('lSize').textContent='Joueurs par équipe';
 chipsRow('cSize',[1,2,3,4,5].map(n=>[n+' v '+n,n]),()=>cfg.duelSize||1,v=>cfg.duelSize=v);
};
const _updSummaryDuel=updSummary;
updSummary=function(){
 if(cfg.mode!=='duel')return _updSummaryDuel();
 const s=cfg.size;cfg.size=cfg.duelSize||1;
 try{_updSummaryDuel();}finally{cfg.size=s;}
};
