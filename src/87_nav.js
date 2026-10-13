/* =====================================================================
   MENU PRINCIPAL : navigation claire en 5 rubriques + sous-onglets,
   écran « Jouer » en 3 étapes (Mode → Carte → Réglages → JOUER)
   ===================================================================== */
const NAV=[
 {id:'play',n:'Jouer',ic:'▶',sub:[['play','Partie solo'],['mp','Multijoueur']]},
 {id:'arsenal',n:'Arsenal',ic:'⌖',sub:[['arms','Armes & skins'],['style','Accessoires & style'],['custom','Viseur & pseudo']]},
 {id:'locker',n:'Casier',ic:'◈',sub:[['locker','Tenues & danses'],['boxes','Caisses']]},
 {id:'career',n:'Carrière',ic:'★',sub:[['prog','Progression & défis'],['stats','Statistiques']]},
 {id:'options',n:'Options',ic:'⚙',sub:[['opts','Graphismes & son'],['keys','Touches'],['acc','Accessibilité'],['credits','Crédits']]}
];
const MODE_GROUPS=[['Compétitif',['bomb','rapid']],['Action',['tdm','ffa','gg','koth']],['Spécial',['zombies','br','train']]];
const MODE_TAG={bomb:'Bombe · économie · manches',rapid:'Manches courtes, armes fournies',tdm:'Équipes, réapparition',ffa:'Chacun pour soi',gg:'Une arme par élimination',koth:'Tiens la zone',zombies:'Coop contre des vagues',br:'Un seul survivant',train:'Stand de tir chronométré'};
let navGroup='play';
const navSub={};
function navCss(){
 const s=document.createElement('style');s.textContent=`
#menu .wrap{height:100%;width:min(1320px,100%);padding:18px 28px 12px}
#menu .mtop{align-items:center;gap:22px;margin-bottom:10px;flex-wrap:nowrap}
#menu .logo h1{font-size:30px;letter-spacing:5px;white-space:nowrap}
#menu .logo .sub{white-space:nowrap}
#profile{flex:none;padding:6px 12px;gap:10px}
#profile .xpb{width:110px}
#profile .lvl{width:38px;height:38px;font-size:1.05rem}
#profile #dailyBtn{white-space:nowrap}
.mapbig{display:flex;flex-direction:column;align-items:center}
#mapThumb{width:auto!important;height:auto;max-width:100%;max-height:calc(100vh - 330px);aspect-ratio:1}
#mapInfo{align-self:stretch}
.mapchips .chip{flex:1 1 auto;padding:8px 6px;font-size:.72rem}
#mtabs{display:none!important}
#mnav{display:flex;gap:4px;margin:0 auto}
.nv{display:flex;align-items:center;gap:8px;padding:11px 20px;cursor:pointer;font-weight:900;font-size:.82rem;letter-spacing:3px;text-transform:uppercase;color:var(--dim);border:1px solid transparent;border-radius:4px;transition:.15s}
.nv i{font-style:normal;font-size:1rem;opacity:.8}
.nv:hover{color:#fff;background:#ffffff0a}
.nv.on{color:#fff;background:linear-gradient(180deg,#ff465533,#ff465511);border-color:#ff465566}
#msub{display:flex;gap:6px;margin:0 0 12px;padding-bottom:10px;border-bottom:1px solid var(--line);min-height:44px;align-items:center}
#msub .sp{padding:7px 15px;border-radius:20px;cursor:pointer;font-size:.74rem;font-weight:800;letter-spacing:1.5px;color:#b8c5da;background:#141c2c;border:1px solid var(--line);transition:.12s}
#msub .sp:hover{background:#1e2a42;color:#fff}
#msub .sp.on{background:#fff;color:#0b1018;border-color:#fff}
#msub .hint{margin-left:auto;font-size:.68rem;color:#6f819e;letter-spacing:1px}
#menu .mbody{min-height:0}
#tab-play{height:100%}
.playgrid{grid-template-columns:300px minmax(320px,1fr) 380px;gap:20px;height:100%}
.playgrid>.col{min-height:0;overflow:auto;padding-right:4px}
.col>h3.step{display:flex;align-items:center;gap:9px;font-size:.72rem;letter-spacing:3px;color:#fff;margin-bottom:10px}
.col>h3.step b{width:22px;height:22px;border-radius:50%;background:var(--accent);display:inline-flex;align-items:center;justify-content:center;font-size:.72rem}
.mgrp{font-size:.58rem;letter-spacing:3px;color:#6f819e;margin:10px 0 6px;text-transform:uppercase;font-weight:800}
.mcard{padding:9px 11px;margin-bottom:6px}
.mcard .ic{font-size:1.25rem;width:28px}
.mcard b{font-size:.8rem}
.mcard span{font-size:.64rem}
#modeInfo{margin-top:12px;padding:12px 14px;background:#101827;border:1px solid var(--line);border-left:3px solid var(--c,#ff4655);font-size:.74rem;line-height:1.5;color:#b8c5da}
#modeInfo b{display:block;color:#fff;font-size:.86rem;letter-spacing:2px;margin-bottom:4px;text-transform:uppercase}
.cfgbox{display:flex;flex-direction:column;overflow:hidden!important}
.cfgscroll{flex:1;min-height:0;overflow:auto;padding-right:6px}
.csec{background:#0f1624;border:1px solid var(--line);padding:11px 13px 3px;margin-bottom:10px;border-radius:3px}
.csec>h4{font-size:.6rem;letter-spacing:3px;color:var(--gold);margin-bottom:10px;font-weight:800}
.cfgfoot{padding-top:8px;border-top:1px solid var(--line);background:linear-gradient(0deg,#05080dee,#05080d99)}
.cfgfoot #sumbar{margin-top:0}
.cfgfoot .tut{display:block;text-align:center;margin-top:8px;font-size:.7rem;color:#8da0bd;cursor:pointer;letter-spacing:1px}
.cfgfoot .tut:hover{color:#fff}
#tab-play .card2#missionsCard{display:none}
@media(max-width:1150px){.playgrid{grid-template-columns:1fr 1fr;height:auto}.playgrid>.col{overflow:visible}.cfgbox{grid-column:1/-1}.nv{padding:9px 12px;letter-spacing:1.5px}.nv span{display:none}}
`;document.head.appendChild(s);
}
function navRender(){
 const nav=$('mnav');nav.innerHTML='';
 for(const g of NAV){const d=document.createElement('div');d.className='nv'+(g.id===navGroup?' on':'');d.innerHTML='<i>'+g.ic+'</i><span>'+g.n+'</span>';d.title=g.n;d.onclick=()=>navGo(g.id);nav.appendChild(d);}
 const grp=NAV.find(g=>g.id===navGroup),sub=$('msub');sub.innerHTML='';
 if(grp.sub.length>1)for(const [t,n] of grp.sub){const p=document.createElement('div');p.className='sp'+(tabNow===t?' on':'');p.textContent=n;p.onclick=()=>navTab(t);sub.appendChild(p);}
 const hints={play:'Choisis un mode, une carte, règle la partie puis clique sur JOUER',arsenal:'Les changements sont enregistrés automatiquement',locker:'Ouvre des caisses pour débloquer skins, tenues et danses',career:'Niveau, passe de combat, classement, succès et statistiques',options:'Les réglages sont enregistrés automatiquement'};
 const h=document.createElement('div');h.className='hint';h.textContent=hints[navGroup]||'';sub.appendChild(h);
 if(typeof themeRibbon==='function')themeRibbon();
}
function navTab(t){
 const orig=document.querySelector('#mtabs .mtab[data-t="'+t+'"]');if(orig)orig.click();
 navSub[navGroup]=t;navRender();
}
function navGo(id){
 navGroup=id;const grp=NAV.find(g=>g.id===id);
 navTab(navSub[id]||grp.sub[0][0]);
}
/* cartes de mode regroupées (remplace la version du menu) */
function buildModeCards(){
 const el=$('modeCards');el.innerHTML='';
 for(const [gn,list] of MODE_GROUPS){
  const h=document.createElement('div');h.className='mgrp';h.textContent=gn;el.appendChild(h);
  for(const k of list){
   const m=MODES[k];if(!m)continue;const c=document.createElement('div');c.className='mcard'+(cfg.mode===k?' on':'');c.style.setProperty('--c',m.c);
   c.innerHTML='<div class="ic">'+m.ic+'</div><div><b>'+m.n+'</b><span>'+(MODE_TAG[k]||'')+'</span></div>';
   c.onclick=()=>{initAudio();sfxUI();cfg.mode=k;saveCfg();drawMenu();};el.appendChild(c);
  }
 }
 let info=$('modeInfo');if(!info){info=document.createElement('div');info.id='modeInfo';el.parentNode.insertBefore(info,el.nextSibling);}
 const m=MODES[cfg.mode];info.style.setProperty('--c',m.c);info.innerHTML='<b>'+m.ic+' '+m.n+'</b>'+m.desc;
}
function restructurePlay(){
 const cols=document.querySelectorAll('#tab-play .playgrid>.col');if(cols.length<3)return;
 const [cMode,cMap,cCfg]=cols;
 cMode.querySelector('h3').outerHTML='<h3 class="step"><b>1</b>MODE DE JEU</h3>';
 cMap.querySelector('h3').outerHTML='<h3 class="step"><b>2</b>CARTE</h3>';
 // défis du jour : déplacés dans Carrière > Progression
 const mc=cMode.querySelector('.card2');if(mc){mc.id='missionsCard';const prog=$('tab-prog');if(prog){prog.insertBefore(mc,prog.firstChild);mc.style.display='block';mc.style.maxWidth='620px';}}
 // réglages en sections + pied fixe avec le bouton JOUER
 buildAgentRow();
 const get=id=>$(id),grpOf=id=>{const e=$(id);return e?(e.classList.contains('grp')?e:e.closest('.grp')):null;};
 const diff=grpOf('cDiff'),agent=$('gAgent'),side=$('gSide'),size=grpOf('cSize'),lim=$('gLimit'),eco=$('gEco'),sum=$('sumbar'),play=$('playBtn');
 cCfg.innerHTML='';
 cCfg.insertAdjacentHTML('beforeend','<h3 class="step"><b>3</b>RÉGLAGES</h3><div class="cfgscroll"></div><div class="cfgfoot"></div>');
 const sc=cCfg.querySelector('.cfgscroll'),ft=cCfg.querySelector('.cfgfoot');
 const sec=(title,els)=>{const d=document.createElement('div');d.className='csec';d.innerHTML='<h4>'+title+'</h4>';els.forEach(e=>e&&d.appendChild(e));sc.appendChild(d);};
 sec('ADVERSAIRES',[diff,agent]);
 sec('ÉQUIPES',[side,size]);
 sec('RÈGLES',[lim,eco]);
 ft.appendChild(sum);ft.appendChild(play);
 const tut=document.createElement('a');tut.className='tut';tut.textContent='Première partie ? ▶ Lancer le tutoriel guidé (2 min)';tut.onclick=()=>{initAudio();sfxUI();startTutorial();};ft.appendChild(tut);
}
function menuNavInit(){
 if($('mnav'))return;
 navCss();
 const top=document.querySelector('#menu .mtop'),tabs=$('mtabs');
 const nav=document.createElement('div');nav.id='mnav';top.insertBefore(nav,tabs);
 const sub=document.createElement('div');sub.id='msub';const body=document.querySelector('#menu .mbody');body.parentNode.insertBefore(sub,body);
 const lg=document.querySelector('#menu .logo .sub');if(lg)lg.textContent='FPS tactique • '+Object.keys(MODES).length+' modes • '+Object.keys(MAPS).length+' cartes • bots IA';
 const ft=document.querySelector('#menu .mfoot');if(ft)ft.textContent='Échap en jeu : pause • Tous les réglages sont sauvegardés automatiquement';
 restructurePlay();
 drawMenu();
 navGroup='play';navRender();
 bpUi();
 netLobbyWire();
}
