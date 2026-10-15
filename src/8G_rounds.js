/* =====================================================================
   TEMPS DE MANCHE / DURÉE DE PARTIE
   - Réglage « Durée » dans le menu pour chaque mode (sauf Zombies).
   - Bataille royale : la zone suit la durée choisie, la partie se termine
     à la fin du chrono (le survivant le plus en forme gagne).
   - Chrono qui passe en rouge dans les 30 dernières secondes, alerte
     sonore et tic-tac sur les 10 dernières.
   - Compétitif : changement de camp à la mi-temps.
   - Zombies : durée de survie affichée en fin de partie.
   ===================================================================== */
const RTIME={
 bomb:{l:'Durée d\'une manche',o:[60,100,115],d:100,u:'s'},
 rapid:{l:'Durée d\'une manche',o:[30,45,60],d:45,u:'s'},
 duel:{l:'Durée d\'une manche',o:[45,60,90],d:60,u:'s'},
 tdm:{l:'Durée de la partie',o:[5,8,10,15],d:8,u:'min'},
 ffa:{l:'Durée de la partie',o:[5,8,10,15],d:8,u:'min'},
 gg:{l:'Durée de la partie',o:[5,8,10,15],d:10,u:'min'},
 koth:{l:'Durée de la partie',o:[5,10,15],d:10,u:'min'},
 br:{l:'Durée maximale',o:[3,5,8],d:5,u:'min'}
};
function rtVal(mode){const r=RTIME[mode];if(!r)return 0;const v=cfg.rt&&cfg.rt[mode];return r.o.includes(v)?v:r.d;}
function rtSec(mode){const r=RTIME[mode];return r?rtVal(mode)*(r.u==='min'?60:1):0;}
function rtLabel(mode){const r=RTIME[mode];return r?rtVal(mode)+(r.u==='min'?' min':' s'):'';}

/* ---------- application au lancement ---------- */
const BR_BASE=BR_PHASES.map(p=>({wait:p.wait,shrink:p.shrink}));
const BR_BASE_T=BR_BASE.reduce((a,p)=>a+p.wait+p.shrink,0);
const _variantInitRT=variantInit;
variantInit=function(){
 G.halfDone=false;G.rtWarn=false;G.rtTick=-1;G.rtTotal=0;
 const v=G.variant;
 if(v==='br'){ // la zone se ferme vers 80 % du chrono, il reste ensuite la zone finale
  const T=rtSec('br'),k=T*.8/BR_BASE_T;
  BR_PHASES.forEach((p,i)=>{p.wait=Math.round(BR_BASE[i].wait*k);p.shrink=Math.round(BR_BASE[i].shrink*k);});
 }
 _variantInitRT();
 if(!RTIME[v])return;
 if(G.mode==='bomb'){G.roundT=rtSec(v);G.rtTotal=G.roundT;}
 else{G.timeLeft=rtSec(v);G.rtTotal=G.timeLeft;}
};
const _variantSubRT=variantSub;
variantSub=function(){
 const v=G.variant;
 if(v==='train')return 'Entraînement libre : quitte quand tu veux (Échap)';
 const s=_variantSubRT();
 return RTIME[v]&&G.mode!=='bomb'?s+' — '+rtLabel(v):s;
};

/* ---------- fin du chrono ---------- */
const _variantTimeUpRT=variantTimeUp;
variantTimeUp=function(){
 if(G.variant==='br'){
  let b=null,bs=-1;for(const e of ents)if(e.alive){const s=e.hp+e.armor+(e.shield||0);if(s>bs){bs=s;b=e;}}
  G.winner=b;uiToast('Temps écoulé !');endDM();return true;
 }
 return _variantTimeUpRT();
};

/* ---------- mi-temps (Compétitif et Désamorçage rapide) ---------- */
function halfTimeDue(){
 return G.mode==='bomb'&&G.variant!=='duel'&&!G.netClient&&!G.halfDone&&G.limit>1&&
  G.round===G.limit-1&&G.score[0]<G.limit&&G.score[1]<G.limit;
}
const _afterEndRT=afterEnd;
afterEnd=function(){
 if(!halfTimeDue())return _afterEndRT();
 G.halfDone=true;
 for(const e of ents){e.team=1-e.team;e.keep=false;if(cfg.eco&&G.variant!=='rapid')e.money=800;}
 G.score=[G.score[1],G.score[0]];G.loss=[0,0];
 for(const e of ents)attachRig(e);
 _afterEndRT();
 if(cfg.eco&&G.variant!=='rapid')G.pistolRound=true;
 const side=P.team===0?'ATTAQUANTS':'DÉFENSEURS';
 uiBanner('MI-TEMPS','Changement de camp — vous êtes maintenant '+side+(G.pistolRound?' · manche au pistolet':''),3600,'#ffd75e');
 sfx('round');
};

/* ---------- alerte de fin de chrono ---------- */
function rtRemaining(){
 if(G.state!=='live')return null;
 if(G.mode==='bomb')return BM.state==='planted'?null:G.timer;
 if(G.variant==='zombies'||G.variant==='br'||G.timeLeft>1e8)return null;
 return G.timeLeft;
}
const _updateHUDRT=updateHUD;
updateHUD=function(dt,t){
 _updateHUDRT(dt,t);
 const el=$('timer');if(!el)return;
 const r=rtRemaining(),hurry=r!==null&&r>0&&r<=30&&G.rtTotal>30;
 el.classList.toggle('hurry',hurry);
 if(r===null||r<=0)return;
 if(r<=30&&!G.rtWarn&&G.rtTotal>=60){G.rtWarn=true;uiToast(G.mode==='bomb'?'30 secondes !':'Plus que 30 secondes !');sfx('alarm');}
 if(r<=10){const n=Math.ceil(r);if(n!==G.rtTick){G.rtTick=n;sfx('tick');}}
 if(G.mode==='bomb'&&r>30){G.rtWarn=false;G.rtTick=-1;}
 if(G.variant==='br'&&G.timeLeft<=60&&!G.rtWarn){G.rtWarn=true;uiToast('Plus qu\'une minute !');sfx('alarm');}
};

/* ---------- écran de fin ---------- */
const _uiMatchOverRT=uiMatchOver;
uiMatchOver=function(){
 _uiMatchOverRT();
 const m=MODES[G.variant];
 let s=$('oS').textContent;
 if(m&&MODE()!==m)s=s.replace(MODE().n,m.n); // nom de la variante (Capture de zone…) au lieu du mode de base
 if(G.variant==='zombies')s+='   •   survie '+fmt(G.t);
 $('oS').textContent=s;
};

/* ---------- menu : réglage Durée ---------- */
function rtMenu(){
 const lim=$('gLimit');if(!lim)return;
 let g=$('gTime');
 if(!g){g=document.createElement('div');g.className='grp';g.id='gTime';g.innerHTML='<label id="lTime"></label><div class="chips" id="cTime"></div>';}
 if(g.previousElementSibling!==lim)lim.parentNode.insertBefore(g,lim.nextSibling);
 const r=RTIME[cfg.mode];g.style.display=r?'':'none';if(!r)return;
 $('lTime').textContent=r.l;cfg.rt=cfg.rt||{};
 chipsRow('cTime',r.o.map(n=>[n+(r.u==='min'?' min':' s'),n]),()=>rtVal(cfg.mode),v=>{cfg.rt[cfg.mode]=v;});
}
const _drawMenuRT=drawMenu;
drawMenu=function(){_drawMenuRT();try{rtMenu();}catch(e){console.error(e);}};
const _updSummaryRT=updSummary;
updSummary=function(){
 _updSummaryRT();
 const e=$('sumbar');if(e&&RTIME[cfg.mode]){const b=e.querySelector('br');const t=' · '+rtLabel(cfg.mode)+(['bomb','rapid','duel'].includes(cfg.mode)?' par manche':'');if(b)b.insertAdjacentText('beforebegin',t);else e.insertAdjacentText('beforeend',t);}
};
(function(){const s=document.createElement('style');s.textContent=`
#timer.hurry{color:#ff5050!important;animation:rtPulse 1s ease-in-out infinite}
@keyframes rtPulse{0%,100%{transform:scale(1)}50%{transform:scale(1.08)}}
`;document.head.appendChild(s);})();
