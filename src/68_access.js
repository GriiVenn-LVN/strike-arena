/* =====================================================================
   ACCESSIBILITÉ & CONTRÔLES : daltonisme, sous-titres sonores, taille
   du HUD, secousses, sensibilité par arme, profils de touches, tutoriel
   ===================================================================== */
cfg.cb=cfg.cb||'none';cfg.subs=cfg.subs||0;cfg.hudS=cfg.hudS||1;cfg.shakeS=cfg.shakeS===undefined?1:cfg.shakeS;cfg.wsens=cfg.wsens||{};cfg.kprof=cfg.kprof||{};cfg.tutDone=cfg.tutDone||0;
/* ---------- daltonisme : filtres SVG sur le canvas ---------- */
const CB_MATS={
 deut:'0.625 0.375 0 0 0  0.7 0.3 0 0 0  0 0.3 0.7 0 0  0 0 0 1 0',
 prot:'0.567 0.433 0 0 0  0.558 0.442 0 0 0  0 0.242 0.758 0 0  0 0 0 1 0',
 trit:'0.95 0.05 0 0 0  0 0.433 0.567 0 0  0 0.475 0.525 0 0  0 0 0 1 0'
};
(function(){
 const s=document.createElementNS('http://www.w3.org/2000/svg','svg');s.setAttribute('width','0');s.setAttribute('height','0');s.style.position='absolute';
 // daltonisation : correction = image + (image - simulation) redistribuée vers les canaux visibles
 s.innerHTML='<defs>'+Object.keys(CB_MATS).map(k=>'<filter id="cb-'+k+'" color-interpolation-filters="sRGB"><feColorMatrix type="matrix" values="'+({deut:'1 0 0 0 0  0.7 0.3 0 0 0  0.7 0 0.3 0 0  0 0 0 1 0',prot:'0.3 0.7 0 0 0  0 1 0 0 0  0 0.7 0.3 0 0  0 0 0 1 0',trit:'1 0 0 0 0  0 1 0 0 0  0.7 0.7 -0.4 0 0  0 0 0 1 0'})[k]+'"/></filter>').join('')+'</defs>';
 document.body.appendChild(s);
})();
function applyAccess(){
 const cv=$('c');if(cv)cv.style.filter=cfg.cb&&cfg.cb!=='none'?'url(#cb-'+cfg.cb+')':'';
 const h=$('hud');if(h)h.style.zoom=cfg.hudS||1;
}
/* ---------- sous-titres sonores ---------- */
const SUBN={rifle:'Tir de fusil',smg:'Tir de mitraillette',pistol:'Tir de pistolet',shotgun:'Fusil à pompe',sniper:'Tir de sniper',lmg:'Mitrailleuse',boom:'Explosion',bang:'Flash',smoke:'Fumigène',step:'Pas',knife:'Couteau',reload:'Rechargement',beep:'Bip de la bombe',throw:'Lancer'};
let subEl=null,subCd=0;
function subtitle(type,x,z){
 if(!cfg.subs||!SUBN[type]||x===undefined||!P||!G.running)return;
 const dx=x-P.x,dz=z-P.z,d=Math.hypot(dx,dz);if(d<1.5||d>60||G.t<subCd)return;subCd=G.t+.25;
 if(!subEl){subEl=document.createElement('div');subEl.style.cssText='position:fixed;left:50%;bottom:150px;transform:translateX(-50%);z-index:6;pointer-events:none;display:flex;flex-direction:column;align-items:center;gap:3px;font:700 13px system-ui;color:#fff';document.body.appendChild(subEl);}
 const ang=Math.atan2(-dx,-dz)-P.yaw;let a=((ang+Math.PI)%TAU+TAU)%TAU-Math.PI; // 0 = devant
 const arrow=Math.abs(a)<.5?'▲':Math.abs(a)>2.6?'▼':a>0?'◀':'▶';
 const l=document.createElement('div');l.style.cssText='background:rgba(0,0,0,.65);padding:3px 12px;border-radius:3px;transition:opacity .5s';
 l.textContent=(arrow==='◀'?'◀ ':'')+(arrow==='▲'||arrow==='▼'?arrow+' ':'')+SUBN[type]+' · '+Math.round(d)+' m'+(arrow==='▶'?' ▶':'');
 subEl.appendChild(l);while(subEl.children.length>3)subEl.removeChild(subEl.firstChild);
 setTimeout(()=>{l.style.opacity=0;setTimeout(()=>l.remove(),520);},1300);
}
/* ---------- sensibilité par arme ---------- */
function wsensMul(){const wi=P&&P.alive?curWi(P):null;return wi&&cfg.wsens[wi.k]?cfg.wsens[wi.k]:1;}
/* ---------- profils de touches ---------- */
const KPRESETS={
 'Valorant':{forward:'KeyW',back:'KeyS',left:'KeyA',right:'KeyD',crouch:'ControlLeft',walk:'ShiftLeft',jump:'Space',reload:'KeyR',use:'KeyE',buy:'KeyB',frag:'KeyG',flash:'KeyF',smoke:'KeyH',mine:'KeyC',last:'KeyV',spray:'KeyJ'},
 'CS':{forward:'KeyW',back:'KeyS',left:'KeyA',right:'KeyD',crouch:'ControlLeft',walk:'ShiftLeft',jump:'Space',reload:'KeyR',use:'KeyE',buy:'KeyB',frag:'Digit4',flash:'Digit5',smoke:'Digit6',mine:'KeyX',last:'KeyQ',spray:'KeyT'},
 'Gaucher (flèches)':{forward:'ArrowUp',back:'ArrowDown',left:'ArrowLeft',right:'ArrowRight',crouch:'ControlRight',walk:'ShiftRight',jump:'Space',reload:'KeyR',use:'KeyE',buy:'KeyB',frag:'KeyG',flash:'KeyF',smoke:'KeyH',mine:'KeyX',last:'KeyQ',spray:'KeyJ'},
 'Azerty':{forward:'KeyW',back:'KeyS',left:'KeyA',right:'KeyD'}
};
function loadBinds(b){cfg.binds=Object.assign({},DEFBINDS,b);saveCfg();if(typeof buildBinds==='function')buildBinds();}
/* ---------- tutoriel guidé ---------- */
const TUT={on:false,step:0,t:0,base:null,el:null,done:{}};
const TUT_STEPS=[
 {t:'Déplace-toi',d:()=>'Avance, recule et strafe avec '+kn('forward')+kn('left')+kn('back')+kn('right'),ok:()=>TUT.moved>=4},
 {t:'Regarde autour de toi',d:()=>'Bouge la souris pour viser',ok:()=>TUT.looked>2.5},
 {t:'Saute',d:()=>'Appuie sur '+kn('jump'),ok:()=>TUT.did.jump},
 {t:'Accroupis-toi',d:()=>'Maintiens '+kn('crouch')+' : plus précis, plus discret',ok:()=>TUT.did.crouch},
 {t:'Tire sur les cibles',d:()=>'Clic gauche — touche 5 cibles',ok:()=>TR.hits-TUT.h0>=5},
 {t:'Vise la tête',d:()=>'Un headshot fait beaucoup plus de dégâts',ok:()=>P.hsKills-TUT.hs0>=1},
 {t:'Recharge',d:()=>'Appuie sur '+kn('reload'),ok:()=>TUT.did.reload},
 {t:'Change d\'arme',d:()=>'Touches '+kn('slot1')+' '+kn('slot2')+' '+kn('slot3'),ok:()=>TUT.did.slot},
 {t:'Lance un fumigène',d:()=>'Touche '+kn('smoke')+' : bloque la vision',ok:()=>TUT.did.nade},
 {t:'Pose une mine',d:()=>'Touche '+kn('mine')+' : elle explose au passage d\'un ennemi. Tire sur les mines ennemies pour les détruire !',ok:()=>TUT.did.mine},
 {t:'Pose ton spray',d:()=>'Approche-toi d\'un mur et appuie sur '+kn('spray'),ok:()=>TUT.did.spray}
];
const kn=a=>'['+String(cfg.binds[a]||'?').replace('Key','').replace('Digit','').replace('Arrow','↑').replace('Left','←').replace('Space','ESPACE')+'] ';
function startTutorial(){
 TUT.base={mode:cfg.mode,map:cfg.map,cine:cfg.cine};
 cfg.mode='train';cfg.map='range';cfg.cine=0;startMatch();buildRadarMap();
 cfg.mode=TUT.base.mode;cfg.map=TUT.base.map;cfg.cine=TUT.base.cine;
 G.timeLeft=1e9;TUT.on=true;P.nade.mn=2;TUT.step=0;TUT.moved=0;TUT.looked=0;TUT.did={};TUT.h0=TR.hits;TUT.hs0=P.hsKills;TUT.ly=P.yaw;TUT.done={};
 if(!TUT.el){TUT.el=document.createElement('div');TUT.el.style.cssText='position:fixed;left:14px;top:190px;z-index:8;width:270px;background:rgba(10,14,22,.82);border:1px solid #ffffff30;border-left:4px solid #35e0c0;padding:10px 14px;font:600 12px system-ui;color:#fff;pointer-events:none;border-radius:3px';document.body.appendChild(TUT.el);}
 uiBanner('TUTORIEL','Suis les consignes à gauche',2200);
}
function tutDown(code){
 if(!TUT.on)return;const b=cfg.binds;
 if(code===b.jump)TUT.did.jump=1;if(code===b.crouch)TUT.did.crouch=1;if(code===b.reload)TUT.did.reload=1;
 if(code===b.slot1||code===b.slot2||code===b.slot3)TUT.did.slot=1;
 if(code===b.smoke||code===b.frag||code===b.flash)TUT.did.nade=1;if(code===b.mine)TUT.did.mine=1;if(code===b.spray)TUT.did.spray=1;
}
function tutUpdate(dt){
 if(!TUT.on)return;
 if(G.variant!=='train'||!G.running){TUT.on=false;if(TUT.el)TUT.el.style.display='none';return;}
 const sp=Math.hypot(P.vx||0,P.vz||0);if(sp>1)TUT.moved+=dt;
 TUT.looked+=Math.abs(P.yaw-TUT.ly);TUT.ly=P.yaw;
 const st=TUT_STEPS[TUT.step];
 if(st&&st.ok()){TUT.step++;sfx('pickup');if(TUT.step>=TUT_STEPS.length){PROF.coins+=300;cfg.tutDone=1;saveCfg();saveProf();uiBanner('TUTORIEL TERMINÉ','+300 🪙',3000);TUT.on=false;TUT.el.style.display='none';return;}}
 const cur=TUT_STEPS[TUT.step];
 TUT.el.style.display='block';
 TUT.el.innerHTML='<div style="color:#35e0c0;letter-spacing:2px;font-size:10px">TUTORIEL '+(TUT.step+1)+' / '+TUT_STEPS.length+'</div><div style="font-size:15px;margin:2px 0">'+cur.t+'</div><div style="color:#c5d1e4;font-weight:500">'+cur.d()+'</div>';
}
/* ---------- onglet « Accès » ---------- */
function buildAccessTab(){
 const tabs=$('mtabs');if(!tabs||$('tab-acc'))return;
 const tb=document.createElement('div');tb.className='mtab';tb.dataset.t='acc';tb.textContent='Accès';
 tabs.insertBefore(tb,tabs.querySelector('[data-t="stats"]'));
 const p=document.createElement('div');p.className='tp';p.id='tab-acc';p.innerHTML='<div class="custgrid" id="accGrid"></div>';
 $('tab-keys').parentNode.appendChild(p);
}
function drawAccessTab(){
 const el=$('accGrid');if(!el)return;el.innerHTML='';
 const sec=(title,items,get,set,fmt)=>{
  const d=document.createElement('div');d.className='stl grp';d.innerHTML='<h4>'+title+'</h4><div class="chips"></div>';const box=d.querySelector('.chips');
  items.forEach(it=>{const c=document.createElement('div');c.className='chip'+(get(it)?' on':'');c.innerHTML=fmt(it);c.onclick=()=>{sfxUI();set(it);saveCfg();applyAccess();drawAccessTab();};box.appendChild(c);});el.appendChild(d);
 };
 sec('Mode daltonien',[{id:'none',n:'Aucun'},{id:'deut',n:'Deutéranopie'},{id:'prot',n:'Protanopie'},{id:'trit',n:'Tritanopie'}],it=>cfg.cb===it.id,it=>cfg.cb=it.id,it=>it.n);
 sec('Sous-titres sonores (direction des bruits)',[{id:0,n:'Désactivés'},{id:1,n:'Activés'}],it=>cfg.subs===it.id,it=>cfg.subs=it.id,it=>it.n);
 sec('Taille de l\'interface (HUD)',[.8,.9,1,1.15,1.3].map(v=>({id:v,n:Math.round(v*100)+' %'})),it=>cfg.hudS===it.id,it=>cfg.hudS=it.id,it=>it.n);
 sec('Contours des personnages (rouge = ennemi, bleu = allié)',[{id:1,n:'Activés'},{id:0,n:'Désactivés'}],it=>cfg.outline===it.id,it=>{cfg.outline=it.id;applyOutlinesAll();},it=>it.n);
 sec('Secousses de l\'écran',[{id:0,n:'Aucune'},{id:.4,n:'Réduites'},{id:1,n:'Normales'}],it=>cfg.shakeS===it.id,it=>cfg.shakeS=it.id,it=>it.n);
 // profils de touches
 const kp=document.createElement('div');kp.className='stl grp';kp.innerHTML='<h4>Profils de touches</h4><div class="chips" id="kpRow"></div><div class="chips" id="kpPre" style="margin-top:6px"></div><small>Enregistre ta configuration actuelle dans un emplacement ou charge une disposition prête à l\'emploi.</small>';el.appendChild(kp);
 const row=kp.querySelector('#kpRow');
 [1,2,3].forEach(i=>{const has=cfg.kprof[i];
  const sv=document.createElement('div');sv.className='chip';sv.textContent='💾 Enregistrer '+i;sv.onclick=()=>{cfg.kprof[i]=Object.assign({},cfg.binds);saveCfg();uiToast('Profil '+i+' enregistré');drawAccessTab();};row.appendChild(sv);
  const ld=document.createElement('div');ld.className='chip'+(has?'':' lock');ld.textContent='Charger '+i;ld.onclick=()=>{if(!has)return uiToast('Emplacement vide');loadBinds(cfg.kprof[i]);uiToast('Profil '+i+' chargé');};row.appendChild(ld);});
 const pre=kp.querySelector('#kpPre');
 Object.keys(KPRESETS).forEach(k=>{const c=document.createElement('div');c.className='chip';c.textContent=k;c.onclick=()=>{loadBinds(Object.assign({},DEFBINDS,KPRESETS[k]));uiToast('Disposition « '+k+' » appliquée');};pre.appendChild(c);});
 // sensibilité par arme
 const ws=document.createElement('div');ws.className='stl grp';ws.innerHTML='<h4>Sensibilité par arme (multiplicateur)</h4><div id="wsGrid" style="display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:6px 18px"></div><small>1.00 = sensibilité générale des Réglages.</small>';el.appendChild(ws);
 const gr=ws.querySelector('#wsGrid');
 Object.keys(W).filter(k=>!W[k].melee).forEach(k=>{
  const v=cfg.wsens[k]||1,r=document.createElement('div');r.style.cssText='display:flex;align-items:center;gap:8px;font-size:.7rem';
  r.innerHTML='<span style="width:92px;color:#c5d1e4">'+W[k].n+'</span><input type="range" min="40" max="200" value="'+Math.round(v*100)+'" style="flex:1"><b style="width:36px;text-align:right">'+v.toFixed(2)+'</b>';
  const inp=r.querySelector('input'),b=r.querySelector('b');inp.oninput=()=>{const m=inp.value/100;b.textContent=m.toFixed(2);if(Math.abs(m-1)<.03)delete cfg.wsens[k];else cfg.wsens[k]=m;saveCfg();};
  gr.appendChild(r);
 });
 // tutoriel
 const tu=document.createElement('div');tu.className='stl grp';tu.innerHTML='<h4>Tutoriel</h4><div class="chips"><div class="chip on" id="tutGo">▶ Lancer le tutoriel guidé</div></div><small>Apprends les bases sur le stand de tir : déplacements, tir, recharge, grenades, capacités, spray. +300 🪙 à la fin.'+(cfg.tutDone?' (déjà terminé)':'')+'</small>';el.appendChild(tu);
 tu.querySelector('#tutGo').onclick=()=>{initAudio();sfxUI();startTutorial();};
}
buildAccessTab();
document.querySelectorAll('.mtab[data-t="acc"]').forEach(t=>t.addEventListener('click',drawAccessTab));
applyAccess();
