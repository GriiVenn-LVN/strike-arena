/* =====================================================================
   MÉDAILLES ET ASSISTANCES (façon Call of Duty / Halo / Phantom Forces)
   - Médailles affichées en jeu : Premier sang, Vengeance, Tir lointain,
     Humiliation (couteau), Grenadier, Acrobate, Sur le fil, Sauveur,
     Doublé, As (toute l'équipe adverse dans une manche), Inarrêtable…
   - Assistance : avoir infligé au moins 25 dégâts à un adversaire achevé
     par un autre joueur. +15 XP par assistance en fin de partie.
   - Écran de fin : liste des médailles du match ; total dans le profil.
   ===================================================================== */
const MEDALS={
 first:{n:'Premier sang',ic:'🩸',xp:20},
 revenge:{n:'Vengeance',ic:'😤',xp:15},
 long:{n:'Tir lointain',ic:'🎯',xp:15},
 knife:{n:'Humiliation',ic:'🔪',xp:20},
 nade:{n:'Grenadier',ic:'💥',xp:10},
 air:{n:'Acrobate',ic:'🤸',xp:15},
 clutchhp:{n:'Sur le fil',ic:'❤️‍🩹',xp:15},
 save:{n:'Sauveur',ic:'🛡️',xp:15},
 collat:{n:'Doublé',ic:'⚡',xp:25},
 ace:{n:'As',ic:'🂡',xp:50},
 s5:{n:'Inarrêtable',ic:'🔥',xp:25},
 s10:{n:'Légende',ic:'👑',xp:60},
 assist:{n:'Assistance',ic:'🤝',xp:15}
};
const MED={got:{},fb:false,lastKill:null,roundKills:0,queue:[],el:null,showT:0,killer:null};
function medalReset(){MED.got={};MED.fb=false;MED.lastKill=null;MED.roundKills=0;MED.queue.length=0;MED.killer=null;if(MED.el)MED.el.className='';}
function medalAward(id){
 const m=MEDALS[id];if(!m)return;
 MED.got[id]=(MED.got[id]||0)+1;
 PROF.medals=PROF.medals||{};PROF.medals[id]=(PROF.medals[id]||0)+1;
 MED.queue.push(id);medalShowNext();
}
function medalShowNext(){
 if(!MED.el){
  const d=document.createElement('div');d.id='medalPop';document.body.appendChild(d);MED.el=d;
  const s=document.createElement('style');s.textContent=`
#medalPop{position:fixed;left:50%;top:21%;transform:translateX(-50%) scale(.6);opacity:0;z-index:12;pointer-events:none;text-align:center;font-family:Bahnschrift,Arial,sans-serif;transition:opacity .2s,transform .25s cubic-bezier(.2,1.6,.4,1)}
#medalPop.on{opacity:1;transform:translateX(-50%) scale(1)}
#medalPop i{display:block;font-style:normal;font-size:2.4rem;filter:drop-shadow(0 0 10px #ffd23a88)}
#medalPop b{display:block;font-size:.85rem;letter-spacing:3px;color:#ffd23a;text-shadow:0 1px 3px #000;margin-top:2px}
#medalPop small{display:block;font-size:.65rem;color:#fff;opacity:.8;letter-spacing:1px}
.medrow{display:flex;flex-wrap:wrap;gap:8px;justify-content:center;margin:10px 0 2px}
.medrow span{background:#0f1726;border:1px solid #ffd23a44;border-radius:8px;padding:5px 9px;font-size:.75rem;color:#fff}
.medrow span em{font-style:normal;color:#ffd23a;margin-left:4px}
#oTable table{width:100%;border-collapse:collapse;font-size:.85rem;margin-bottom:.8rem}
#oTable td,#oTable th{padding:.3rem .6rem}
#oTable td{border-top:1px solid #1d283d}
#oTable td:nth-child(n+2),#oTable th:nth-child(n+2){text-align:right}
#oTable h4{display:flex;justify-content:space-between;letter-spacing:2px}`;document.head.appendChild(s);
 }
 if(performance.now()<MED.showT||!MED.queue.length)return;
 const id=MED.queue.shift(),m=MEDALS[id];
 MED.el.innerHTML='<i>'+m.ic+'</i><b>'+m.n.toUpperCase()+'</b><small>+'+m.xp+' XP</small>';
 MED.el.className='';void MED.el.offsetWidth;MED.el.className='on';sfx('pickup');
 MED.showT=performance.now()+1300;
 setTimeout(()=>{if(MED.el)MED.el.className='';},1150);
 setTimeout(medalShowNext,1350);
}
// mémorise les dégâts du joueur pour les assistances
const _hurtMed=hurt;
hurt=function(v,att,w,zone,dist,raw){
 const hp0=v.hp,sh0=v.shield;
 _hurtMed(v,att,w,zone,dist,raw);
 if(att&&att.isPlayer&&v!==att){const d=(hp0-Math.max(0,v.hp))+(sh0-v.shield);if(d>0){v._pDmg=(v._pDmg&&G.t-v._pDmgT<8?v._pDmg:0)+d;v._pDmgT=G.t;}}
};
const _killEntMed=killEnt;
killEnt=function(v,att,w,hs){
 const was=v.alive,pAir=P&&(!P.onGround||!!P.slide||!!P.dash),tgt=v.target;
 _killEntMed(v,att,w,hs);
 if(!was||v.alive||!P||G.netClient||v.dummy)return;
 const enemyOfP=MODE().team?v.team!==P.team:v!==P;
 if(v===P){MED.killer=att&&att!==P?att:null;return;}
 // assistance
 if(att!==P&&enemyOfP&&v._pDmg>=25&&G.t-v._pDmgT<8){MS.assists=(MS.assists||0)+1;medalAward('assist');}
 v._pDmg=0;
 if(att!==P||v.zombie)return;
 if(!MED.fb){MED.fb=true;medalAward('first');}
 MED.fb=true;
 if(MED.killer===v){MED.killer=null;medalAward('revenge');}
 if(Math.hypot(v.x-P.x,v.z-P.z)>38&&!w.melee)medalAward('long');
 if(w&&w.melee)medalAward('knife');
 if(w===NADEW)medalAward('nade');
 if(pAir&&!w.melee&&w!==NADEW)medalAward('air');
 if(P.alive&&P.hp<=20)medalAward('clutchhp');
 if(tgt&&tgt!==P&&tgt.alive&&tgt.team===P.team&&MODE().team&&G.t-(tgt.lastHurtT||-9)<2)medalAward('save');
 if(MED.lastKill&&G.t-MED.lastKill.t<.2&&MED.lastKill.w===w&&!w.melee)medalAward('collat');
 MED.lastKill={t:G.t,w};
 if(P.streak===5)medalAward('s5');if(P.streak===10)medalAward('s10');
 if(G.mode==='bomb'){MED.roundKills++;const foes=ents.filter(e=>e.team!==P.team).length;if(foes>=3&&MED.roundKills===foes)medalAward('ace');}
};
// le premier sang compte pour tout le monde
const _killEntFb=killEnt;
killEnt=function(v,att,w,hs){const was=v.alive;_killEntFb(v,att,w,hs);if(was&&!v.alive&&att&&att!==v&&!v.dummy&&!v.zombie)MED.fb=true;};
const _startMatchMed=startMatch;
startMatch=function(){medalReset();return _startMatchMed();};
const _resetRoundMed=resetRound;
resetRound=function(){MED.roundKills=0;return _resetRoundMed();};
// XP des médailles et assistances en fin de partie
const _commitMatchMed=commitMatch;
commitMatch=function(win){
 const r=_commitMatchMed(win);
 let xp=0;for(const id in MED.got)xp+=MEDALS[id].xp*MED.got[id];
 if(xp>0&&!G.netClient){r.ups=r.ups.concat(addXP(xp));r.xp+=xp;r.medXp=xp;if(PROF.history[0])PROF.history[0].xp=r.xp;saveProf();}
 return r;
};
const _showMatchRewardsMed=showMatchRewards;
showMatchRewards=function(win){
 _showMatchRewardsMed(win);
 const ids=Object.keys(MED.got);if(!ids.length)return;
 const b=document.querySelector('#oRew .rewbox');if(!b)return;
 b.insertAdjacentHTML('beforeend','<div class="medrow">'+ids.map(id=>'<span>'+MEDALS[id].ic+' '+MEDALS[id].n+(MED.got[id]>1?'<em>×'+MED.got[id]+'</em>':'')+'</span>').join('')+'</div>');
};
medalShowNext(); // prépare l'affichage et les styles
