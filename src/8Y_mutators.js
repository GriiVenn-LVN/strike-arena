/* =====================================================================
   MODIFICATEURS DE PARTIE (façon Krunker / parties perso Roblox)
   À cocher dans Jouer › Réglages › Modificateurs, cumulables, pour une
   partie solo contre les bots (désactivés en multijoueur) :
   - Gravité lunaire : on saute haut et on retombe lentement.
   - Turbo : tout le monde court 30 % plus vite.
   - Têtes seulement : seuls les tirs à la tête blessent (couteau et
     grenades restent normaux).
   - Une balle : chaque touche élimine.
   - Vampire : chaque élimination rend 50 PV.
   - Grenades à volonté : une grenade revient toutes les 5 s.
   Les parties avec modificateurs ne comptent pas pour le classé.
   ===================================================================== */
const MUTS=[
 {k:'lune',ic:'🌙',n:'Gravité lunaire',d:'Sauts géants, chute lente'},
 {k:'turbo',ic:'⚡',n:'Turbo',d:'Tout le monde court 30 % plus vite'},
 {k:'tetes',ic:'🎯',n:'Têtes seulement',d:'Seuls les tirs à la tête blessent'},
 {k:'balle',ic:'💥',n:'Une balle',d:'Chaque touche élimine'},
 {k:'vamp',ic:'🩸',n:'Vampire',d:'Chaque élimination rend 50 PV'},
 {k:'nades',ic:'💣',n:'Grenades à volonté',d:'Une grenade revient toutes les 5 s'}
];
cfg.mut=cfg.mut&&typeof cfg.mut==='object'?cfg.mut:{};
const MUT={on:{},nadeT:0};
const mutOn=k=>!!MUT.on[k];
function mutList(){return MUTS.filter(m=>cfg.mut[m.k]);}
function mutActive(){return Object.keys(MUT.on).length>0;}

// au lancement de la partie : on fige les modificateurs (solo uniquement)
const _variantInitMut=variantInit;
variantInit=function(){
 MUT.on={};MUT.nadeT=0;
 if(!(typeof NET!=='undefined'&&NET.role))for(const m of mutList())MUT.on[m.k]=1;
 _variantInitMut();
 mutBadge();
};
const _variantSubMut=variantSub;
variantSub=function(){const s=_variantSubMut();const l=MUTS.filter(m=>MUT.on[m.k]);return l.length?s+'  ·  '+l.map(m=>m.ic+' '+m.n).join('  '):s;};
const _variantCleanupMut=variantCleanup;
variantCleanup=function(){_variantCleanupMut();MUT.on={};mutBadge();};

// gravité lunaire : on rend une partie de la gravité avant chaque pas de physique
const MUT_GRAV=.5;
const _physicsMut=physics;
physics=function(e,dt){
 if(MUT.on.lune&&G.running&&!e.onGround&&!e.zombie)e.vy+=GRAV*(1-MUT_GRAV)*dt;
 _physicsMut(e,dt);
};
// turbo
const _moveEntMut=moveEnt;
moveEnt=function(e,vx,vz,dt){
 if(MUT.on.turbo&&G.running&&!e.zombie){vx*=1.3;vz*=1.3;}
 _moveEntMut(e,vx,vz,dt);
};
// têtes seulement / une balle
const _hurtMut=hurt;
hurt=function(v,att,w,zone,dist,raw){
 if(G.running&&att&&att!==v&&!att.zombie&&w&&!w.melee&&w!==NADEW&&!(NET.role==='client'&&G.netClient)){
  if(MUT.on.tetes&&zone!=='h'){
   if(att.isPlayer){uiHit(zone,false,true);sfx('shield');}
   return;
  }
  if(MUT.on.balle)raw=9999;
 }
 _hurtMut(v,att,w,zone,dist,raw);
};
// vampire
const _variantKillMut=variantKill;
variantKill=function(att,v,w,hs){
 _variantKillMut(att,v,w,hs);
 if(MUT.on.vamp&&att&&att!==v&&att.alive&&att.team!==v.team){
  const cap=Math.max(100,att.jugMax||0);att.hp=Math.min(cap,att.hp+50);
  if(att.isPlayer){uiToast('🩸 +50 PV');sfx('heal');}
 }
};
// grenades à volonté
const _variantUpdateMut=variantUpdate;
variantUpdate=function(dt,t){
 _variantUpdateMut(dt,t);
 if(MUT.on.nades&&G.state==='live'){MUT.nadeT+=dt;if(MUT.nadeT>=5){MUT.nadeT=0;for(const e of ents)if(e.alive&&!e.zombie&&e.nade&&!e.nade.f){e.nade.f=1;if(e.isPlayer)uiToast('💣 Grenade rechargée');}}}
};
// pas de classé avec des modificateurs
const _rankedEligibleMut=rankedEligible;
rankedEligible=function(){return _rankedEligibleMut()&&!mutList().length;};

/* ---------- interface ---------- */
function mutBadge(){
 let el=$('mutBadge');
 if(!el){el=document.createElement('div');el.id='mutBadge';$('hud').appendChild(el);}
 const l=MUTS.filter(m=>MUT.on[m.k]);
 el.style.display=l.length?'':'none';
 el.innerHTML=l.map(m=>'<span title="'+m.n+'">'+m.ic+'</span>').join('');
}
function mutSection(){
 const host=document.querySelector('#tab-play .cfgscroll');if(!host)return;
 let sec=$('mutSec');
 if(!sec){
  sec=document.createElement('div');sec.id='mutSec';sec.className='csec';
  const adv=host.querySelector('details.adv');if(adv)host.insertBefore(sec,adv);else host.appendChild(sec);
 }
 const n=mutList().length;
 sec.innerHTML='<h4>MODIFICATEURS'+(n?' <em>'+n+' actif'+(n>1?'s':'')+'</em>':'')+'</h4><div class="mutgrid">'+
  MUTS.map(m=>'<div class="mutc'+(cfg.mut[m.k]?' on':'')+'" data-k="'+m.k+'" title="'+m.d+'"><i>'+m.ic+'</i><b>'+m.n+'</b><span>'+m.d+'</span></div>').join('')+
  '</div><div class="mutnote">Solo uniquement · ne compte pas pour le classé</div>';
 sec.querySelectorAll('.mutc').forEach(c=>c.onclick=()=>{
  const k=c.dataset.k;if(cfg.mut[k])delete cfg.mut[k];else cfg.mut[k]=1;
  if(typeof initAudio==='function')initAudio();if(typeof sfxUI==='function')sfxUI();
  saveCfg();mutSection();if(typeof updSummary==='function')updSummary();
 });
}
const _drawMenuMut=drawMenu;
drawMenu=function(){_drawMenuMut.apply(this,arguments);try{mutSection();}catch(e){console.error(e);}};
const _updSummaryMut=updSummary;
updSummary=function(){
 _updSummaryMut.apply(this,arguments);
 const e=$('sumbar'),l=mutList();if(!e||!l.length)return;
 e.insertAdjacentHTML('beforeend','<div class="mutsum">'+l.map(m=>m.ic+' '+m.n).join(' · ')+'</div>');
};
(function(){const s=document.createElement('style');s.textContent=`
#mutSec h4 em{font-style:normal;color:#ffd23a;margin-left:6px;letter-spacing:1px}
.mutgrid{display:grid;grid-template-columns:1fr 1fr;gap:6px}
.mutc{display:grid;grid-template-columns:28px 1fr;align-items:center;column-gap:6px;padding:7px 8px;border:2px solid #ffffff12;border-radius:8px;background:#0f1726;cursor:pointer;transition:.15s}
.mutc:hover{background:#152036;transform:translateY(-1px)}
.mutc i{font-style:normal;font-size:1.25rem;grid-row:span 2;text-align:center;filter:grayscale(.7);opacity:.7;transition:.15s}
.mutc b{font-size:.68rem;letter-spacing:1px;text-transform:uppercase;color:#cfd8e6}
.mutc span{font-size:.6rem;color:#7f90aa;line-height:1.2}
.mutc.on{border-color:#ffd23a;background:color-mix(in srgb,#ffd23a 14%,#0f1726);box-shadow:0 0 18px -8px #ffd23a}
.mutc.on i{filter:none;opacity:1;transform:scale(1.12)}
.mutc.on b{color:#fff}
.mutnote{font-size:.6rem;color:#6d7e98;margin-top:6px;letter-spacing:1px}
.mutsum{font-size:.72rem;color:#ffd23a;margin-top:3px}
#mutBadge{position:absolute;top:12px;left:12px;display:flex;gap:4px;pointer-events:none}
#mutBadge span{width:26px;height:26px;display:flex;align-items:center;justify-content:center;border-radius:6px;background:#000a;border:1px solid #ffd23a88;font-size:.9rem}
`;document.head.appendChild(s);})();
