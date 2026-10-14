/* =====================================================================
   DÉFIS DU JOUR ET DE LA SEMAINE
   - Les défis du jour (3 par jour, 62_meta.js) gagnent de nouveaux
     objectifs : éliminations par type d'arme, victoires par mode,
     manches de Zombies, survie en Infecté.
   - Nouveau : 3 défis de la semaine, plus longs et mieux payés, tirés
     chaque lundi. Affichés sous les défis du jour (Progression).
   ===================================================================== */
MPOOL.push(
 {id:'k_shotgun',n:'Élimine {t} adversaires au fusil à pompe',t:8,coins:180,xp:70},
 {id:'k_sniper',n:'Élimine {t} adversaires au fusil de précision',t:5,coins:200,xp:80},
 {id:'k_smg',n:'Élimine {t} adversaires au pistolet-mitrailleur',t:12,coins:160,xp:60},
 {id:'k_pistol',n:'Élimine {t} adversaires au pistolet',t:8,coins:180,xp:70},
 {id:'k_rifle',n:'Élimine {t} adversaires au fusil d\'assaut',t:15,coins:160,xp:60},
 {id:'w_duel',n:'Gagne {t} Duel',t:1,coins:220,xp:90},
 {id:'w_dom',n:'Gagne {t} partie de Domination',t:1,coins:220,xp:90},
 {id:'w_gg',n:'Gagne {t} Course aux armes',t:1,coins:250,xp:100},
 {id:'z_wave',n:'Survis à {t} manches de Zombies',t:5,coins:200,xp:80},
 {id:'inf_surv',n:'Termine {t} partie d\'Infecté sans être infecté',t:1,coins:250,xp:100}
);
const WPOOL=[
 {id:'kills',n:'Élimine {t} adversaires',t:150,coins:800,xp:300},
 {id:'hs',n:'Fais {t} headshots',t:40,coins:700,xp:280},
 {id:'win',n:'Gagne {t} parties',t:8,coins:900,xp:350},
 {id:'matches',n:'Joue {t} parties',t:15,coins:700,xp:250},
 {id:'k_sniper',n:'Élimine {t} adversaires au fusil de précision',t:25,coins:800,xp:300},
 {id:'k_shotgun',n:'Élimine {t} adversaires au fusil à pompe',t:30,coins:800,xp:300},
 {id:'knife',n:'Élimine {t} adversaires au couteau',t:5,coins:900,xp:350},
 {id:'w_duel',n:'Gagne {t} Duels',t:3,coins:800,xp:300},
 {id:'w_dom',n:'Gagne {t} parties de Domination',t:3,coins:800,xp:300},
 {id:'z_wave',n:'Survis à {t} manches de Zombies',t:20,coins:900,xp:350},
 {id:'dmg',n:'Inflige {t} dégâts',t:15000,coins:700,xp:280},
 {id:'inf_surv',n:'Termine {t} parties d\'Infecté sans être infecté',t:3,coins:900,xp:350}
];
const wDef=id=>WPOOL.find(m=>m.id===id);
// semaine commençant le lundi (même calcul que le mode de la semaine)
function weekKey(){const d=new Date();return 'w'+Math.floor((Date.UTC(d.getFullYear(),d.getMonth(),d.getDate())/864e5+3)/7);}
function weekLeft(){const d=new Date(),dow=(d.getDay()+6)%7,end=new Date(d.getFullYear(),d.getMonth(),d.getDate()+7-dow);const h=Math.ceil((end-d)/36e5);return h>48?Math.ceil(h/24)+' j':h+' h';}
function ensureWeekly(){
 const k=weekKey();
 if(!PROF.wmis||PROF.wmis.wk!==k){PROF.wmis={wk:k,list:shuffle(WPOOL.slice()).slice(0,3).map(m=>({id:m.id,p:0,done:false,claimed:false}))};saveProf();}
}
const _metaEventWk=metaEvent;
metaEvent=function(id,n){
 _metaEventWk(id,n);
 ensureWeekly();let ch=false;
 for(const m of PROF.wmis.list){if(m.id===id&&!m.done){const d=wDef(id);m.p+=n||1;if(m.p>=d.t){m.p=d.t;m.done=true;uiToast('Défi de la semaine terminé : '+d.n.replace('{t}',d.t));sfx('pickup');}ch=true;}}
 if(ch)saveProf();
};
function claimWeekly(i){
 ensureWeekly();const m=PROF.wmis.list[i];if(!m||!m.done||m.claimed)return null;
 m.claimed=true;const d=wDef(m.id);applyReward({coins:d.coins});const ups=addXP(d.xp);saveProf();return {d,ups};
}

/* ---------- ce qui fait avancer les nouveaux défis ---------- */
const _killEntDefis=killEnt;
killEnt=function(v,att,w,hs){
 const was=v.alive;_killEntDefis(v,att,w,hs);
 if(was&&!v.alive&&att&&att.isPlayer&&att!==v&&att.team!==v.team&&!v.dummy&&w&&w.cat&&!G.netClient)metaEvent('k_'+w.cat);
};
const _commitMatchDefis=commitMatch;
commitMatch=function(win){
 const r=_commitMatchDefis(win);
 if(win&&!G.netClient)metaEvent('w_'+G.variant);
 return r;
};
const _zOnWaveDefis=zOnWave;
zOnWave=function(){
 _zOnWaveDefis();
 if(Z.wave>1&&P&&P.alive&&!G.netClient)metaEvent('z_wave'); // manche précédente survécue
};

/* ---------- affichage sous les défis du jour ---------- */
const _renderMissionsWk=renderMissions;
renderMissions=function(){
 _renderMissionsWk();
 const day=$('missions');if(!day)return;
 ensureWeekly();
 let box=$('wmissions');
 if(!box){box=document.createElement('div');box.id='wmissions';day.parentNode.insertBefore(box,day.nextSibling);}
 box.innerHTML='<h4 style="margin-top:14px">DÉFIS DE LA SEMAINE <small style="color:var(--dim);letter-spacing:1px;font-weight:400">· nouveaux dans '+weekLeft()+'</small></h4>'+
  PROF.wmis.list.map((m,i)=>{const d=wDef(m.id);
   return '<div class="mis'+(m.done?' done':'')+'"><div>'+d.n.replace('{t}',d.t)+'</div><div class="bar"><i style="width:'+Math.round(m.p/d.t*100)+'%;background:#c77dff"></i></div><div style="display:flex;justify-content:space-between;align-items:center"><span class="rw">'+m.p+' / '+d.t+' • 🪙 '+d.coins+' • '+d.xp+' XP</span>'+(m.done&&!m.claimed?'<button data-w="'+i+'">RÉCUPÉRER</button>':m.claimed?'<span style="color:var(--good);font-size:.66rem">✔ récupéré</span>':'')+'</div></div>';}).join('');
 box.querySelectorAll('button[data-w]').forEach(b=>b.onclick=()=>{const r=claimWeekly(+b.dataset.w);if(r){sfx('pickup');showLevelUps(r.ups);renderMissions();refreshProfile();}});
};
