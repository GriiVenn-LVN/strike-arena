/* =====================================================================
   ÉCRAN « JOUER » SIMPLIFIÉ : grandes tuiles de mode, cartes en vignettes
   (seulement celles du mode choisi), réglages essentiels + « Plus d'options »
   ===================================================================== */
// cartes proposées pour chaque mode : Zombies = Asile uniquement, Entraînement = Stand de tir
function mapsFor(mode){
 if(mode==='zombies')return ['asile'];
 if(mode==='train')return ['range'];
 return Object.keys(MAPS).filter(k=>!MAPS[k].zombie&&k!=='range');
}
function fixMapForMode(){
 const l=mapsFor(cfg.mode);
 if(!l.includes(cfg.map)){cfg.map=l[0];saveCfg();if(typeof previewMapWorld==='function')previewMapWorld();}
}
function playCss(){
 if($('playCss'))return;const s=document.createElement('style');s.id='playCss';s.textContent=`
#evRibbon{display:none!important}
.playgrid{grid-template-columns:330px minmax(320px,1fr) 340px!important;gap:26px!important}
.col>h3.step{font-size:.82rem!important;margin-bottom:14px!important}
#modeCards{display:grid;grid-template-columns:1fr 1fr 1fr;gap:10px}
#modeCards .mcard{flex-direction:column;justify-content:center;gap:8px;text-align:center;margin:0;padding:16px 6px;min-height:104px;border:2px solid #ffffff12;border-radius:10px;background:#0f1726}
#modeCards .mcard:hover{transform:translateY(-2px);background:#152036}
#modeCards .mcard.on{border-color:var(--c);background:color-mix(in srgb,var(--c) 18%,#0f1726)}
#modeCards .mcard .ic{font-size:2rem;width:auto}
#modeCards .mcard b{font-size:.74rem;letter-spacing:1px;line-height:1.25}
#modeCards .mcard span{display:none}
#modeInfo{display:none!important}
#modeLine{margin-top:14px;font-size:.8rem;color:#b8c5da;line-height:1.45;min-height:2.6em}
#mapThumb{display:none!important}
#mapChips.mapcards{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px}
.playgrid>.col{overflow-x:hidden!important}
#modeCards{grid-template-columns:repeat(3,minmax(0,1fr))!important}
#mapChips.single{grid-template-columns:minmax(0,420px);justify-content:center}
.mapc{background:#0f1726;border:2px solid #ffffff12;border-radius:10px;padding:8px;cursor:pointer;transition:.15s;text-align:center}
.mapc:hover{transform:translateY(-2px);background:#152036}
.mapc.on{border-color:var(--accent,#ff4655);box-shadow:0 0 24px -10px var(--accent,#ff4655)}
.mapc canvas{width:100%;aspect-ratio:1;display:block;border-radius:6px}
.mapc b{display:block;margin-top:7px;font-size:.82rem;letter-spacing:1.5px;text-transform:uppercase}
#mapInfo{margin-top:14px;font-size:.8rem;color:#b8c5da}
#mapInfo b{display:none}
.csec{background:transparent!important;border:none!important;padding:0 0 6px!important;margin-bottom:14px!important}
.csec>h4{font-size:.72rem!important;color:#fff!important;margin-bottom:8px!important}
#cDiff{display:flex;gap:6px;flex-wrap:wrap}
#cDiff .dc{flex:1 1 0;padding:12px 4px;text-align:center;border-radius:8px}
#cDiff .dc .bar{display:none}
#cDiff .dc b{font-size:.7rem}
#dDesc{font-size:.74rem;color:#8da0bd;margin-top:6px}
.csec .grp>label{display:none}
.csec .chip{padding:10px 14px;font-size:.8rem}
details.adv{margin:4px 0 10px;border-top:1px solid #ffffff14;padding-top:10px}
details.adv summary{cursor:pointer;font-size:.74rem;letter-spacing:2px;color:#8da0bd;font-weight:800;list-style:none}
details.adv summary::before{content:'▸ ';}
details.adv[open] summary::before{content:'▾ ';}
details.adv summary:hover{color:#fff}
details.adv .grp>label{display:block!important;font-size:.62rem;letter-spacing:2px;color:#8da0bd;margin:12px 0 6px}
details.adv small{display:none}
#sumbar{font-size:.84rem!important;text-align:center}
#playBtn{font-size:1.5rem!important;padding:20px!important}
@media(max-width:1150px){#modeCards{grid-template-columns:repeat(3,1fr)}}
`;document.head.appendChild(s);
}
function buildModeCards(){
 playCss();
 const el=$('modeCards');el.innerHTML='';
 for(const [,list] of MODE_GROUPS)for(const k of list){
  const m=MODES[k];if(!m)continue;const c=document.createElement('div');c.className='mcard'+(cfg.mode===k?' on':'');c.style.setProperty('--c',m.c);
  c.innerHTML='<div class="ic">'+m.ic+'</div><b>'+m.n.replace(/\s*\(.*\)/,'')+'</b>';c.title=MODE_TAG[k]||'';
  c.onclick=()=>{initAudio();sfxUI();cfg.mode=k;saveCfg();fixMapForMode();drawMenu();};el.appendChild(c);
 }
 let ln=$('modeLine');if(!ln){ln=document.createElement('div');ln.id='modeLine';el.parentNode.insertBefore(ln,el.nextSibling);}
 ln.textContent=MODE_TAG[cfg.mode]||'';
}
function buildMapChips(){
 fixMapForMode();
 const el=$('mapChips'),list=mapsFor(cfg.mode);el.innerHTML='';
 el.className='mapcards'+(list.length===1?' single':'');
 for(const k of list){
  const c=document.createElement('div');c.className='mapc'+(cfg.map===k?' on':'');
  const cv=document.createElement('canvas');cv.width=cv.height=list.length===1?320:160;c.appendChild(cv);
  try{drawMapThumb(cv,k);}catch(e){}
  const b=document.createElement('b');b.textContent=MAPS[k].n;c.appendChild(b);
  c.onclick=()=>{initAudio();sfxUI();cfg.map=k;saveCfg();drawMenu();previewMapWorld();};el.appendChild(c);
 }
}
function restructurePlay(){
 const cols=document.querySelectorAll('#tab-play .playgrid>.col');if(cols.length<3)return;
 const [cMode,cMap,cCfg]=cols;
 cMode.querySelector('h3').outerHTML='<h3 class="step"><b>1</b>MODE</h3>';
 cMap.querySelector('h3').outerHTML='<h3 class="step"><b>2</b>CARTE</h3>';
 const mc=cMode.querySelector('.card2');if(mc){mc.id='missionsCard';const prog=$('tab-prog');if(prog){prog.insertBefore(mc,prog.firstChild);mc.style.display='block';mc.style.maxWidth='620px';}}
 buildAgentRow();
 const grpOf=id=>{const e=$(id);return e?(e.classList.contains('grp')?e:e.closest('.grp')):null;};
 const diff=grpOf('cDiff'),agent=$('gAgent'),side=$('gSide'),size=grpOf('cSize'),lim=$('gLimit'),eco=$('gEco'),sum=$('sumbar'),play=$('playBtn');
 cCfg.innerHTML='';
 cCfg.insertAdjacentHTML('beforeend','<h3 class="step"><b>3</b>RÉGLAGES</h3><div class="cfgscroll"></div><div class="cfgfoot"></div>');
 const sc=cCfg.querySelector('.cfgscroll'),ft=cCfg.querySelector('.cfgfoot');
 const sec=(title,els)=>{const d=document.createElement('div');d.className='csec';d.innerHTML='<h4>'+title+'</h4>';els.forEach(e=>e&&d.appendChild(e));sc.appendChild(d);};
 sec('DIFFICULTÉ',[diff]);
 sec('JOUEURS',[size]);
 const adv=document.createElement('details');adv.className='adv';adv.innerHTML='<summary>PLUS D\'OPTIONS</summary>';
 [side,lim,eco,agent].forEach(e=>e&&adv.appendChild(e));sc.appendChild(adv);
 ft.appendChild(sum);ft.appendChild(play);
 const tut=document.createElement('a');tut.className='tut';tut.textContent='Première partie ? Tutoriel guidé (2 min)';tut.onclick=()=>{initAudio();sfxUI();startTutorial();};ft.appendChild(tut);
}
// résumé court au-dessus du bouton JOUER
function updSummary(){
 const e=$('sumbar');if(!e)return;const m=MODES[cfg.mode];
 const size=m.team?cfg.size+' v '+cfg.size:cfg.ffa+' joueurs';
 e.innerHTML='<b>'+m.n.replace(/\s*\(.*\)/,'')+'</b> · '+MAPS[cfg.map].n+' · '+DIFFS[cfg.diff].n+(cfg.mode==='zombies'?'':' · '+size);
}
