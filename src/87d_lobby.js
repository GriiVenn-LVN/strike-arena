/* =====================================================================
   ACCUEIL, JOUER AVEC DES AMIS, TABLEAU DES SCORES (Tab)
   - Nouvelle rubrique « Accueil » ouverte au lancement : grand bouton
     JOUER, mode de la semaine, défis du jour et de la semaine (récupérables
     directement), passe de saison, récompense du jour, nouveautés.
     #lobbyRewards : emplacement libre pour les récompenses de fidélité /
     Premium (rempli par un autre module, masqué tant qu'il est vide).
   - « Jouer » devient un seul écran avec un interrupteur SOLO / AVEC DES
     AMIS : le salon (créer, code, lien d'invitation, joueurs) s'affiche à
     la place des réglages, l'hôte choisit mode et carte au même endroit
     et le bouton JOUER lance la partie pour tout le monde. Un lien
     #join=CODE rejoint le salon tout seul.
   - Tableau des scores (Tab) refait : en-tête avec score et chrono,
     rangs, MVP, joueurs en ligne, mise à jour en direct.
   ===================================================================== */
const LOBBY={friends:false,newsKey:'sa_news_seen'};
const NEWS=[
 {id:'n_lobby',ic:'🏠',t:'Nouvel accueil',d:'Défis, nouveautés et récompenses dès l\'ouverture du jeu.'},
 {id:'n_friends',ic:'👥',t:'Jouer avec des amis, en un écran',d:'Crée un salon, envoie le lien, lance la partie.',go:'friends'},
 {id:'n_tab',ic:'📋',t:'Nouveau tableau des scores',d:'Maintiens Tab en partie : score, chrono, MVP en direct.'},
 {id:'n_perk',ic:'🍹',t:'Boissons d\'atout et caisses animées',d:'Nouvelles animations d\'ouverture et de boisson.',go:'boxes'},
 {id:'n_csgo',ic:'🔪',t:'Skins façon CS:GO et couteaux',d:'Nouvelles finitions d\'armes et couteaux à collectionner.',go:'arms'},
 {id:'n_camo',ic:'✨',t:'Camos animés',d:'Des camouflages qui bougent, exclusifs.',go:'arms'},
 {id:'n_modes',ic:'🏳',t:'Domination et Infecté',d:'Deux nouveaux modes : tiens A, B, C ou survis aux infectés.',go:'mode:dom'},
 {id:'n_kc',ic:'🎥',t:'Kill-cam du tueur',d:'Revois comment tu t\'es fait éliminer.'}
];
function newsSeen(){try{return JSON.parse(localStorage.getItem(LOBBY.newsKey)||'[]');}catch(e){return [];}}
function newsMarkSeen(){try{localStorage.setItem(LOBBY.newsKey,JSON.stringify(NEWS.map(n=>n.id)));}catch(e){}}
// nombre de choses à récupérer / voir (pastille sur « Accueil »)
function lobbyPending(){
 let n=0;
 try{ensureMissions();n+=PROF.missions.list.filter(m=>m.done&&!m.claimed).length;}catch(e){}
 try{if(typeof ensureWeekly==='function'){ensureWeekly();n+=PROF.wmis.list.filter(m=>m.done&&!m.claimed).length;}}catch(e){}
 try{if(dailyStatus().can)n++;}catch(e){}
 const seen=newsSeen();if(NEWS.some(x=>!seen.includes(x.id)))n++;
 try{if(typeof loyPending==='function')n+=loyPending()||0;}catch(e){}
 return n;
}
const untilMidnight=()=>{const d=new Date(),m=new Date(d.getFullYear(),d.getMonth(),d.getDate()+1),h=Math.floor((m-d)/36e5),mn=Math.floor((m-d)%36e5/6e4);return h?h+' h '+String(mn).padStart(2,'0'):mn+' min';};
const modeName=k=>MODES[k]?MODES[k].n.replace(/\s*\(.*\)/,''):k;

/* ---------- styles ---------- */
function lobbyCss(){
 if($('lobbyCss'))return;const s=document.createElement('style');s.id='lobbyCss';s.textContent=`
/* barre de navigation */
#mnav{gap:2px!important;background:#0b111c99;border:1px solid #ffffff12;border-radius:12px;padding:4px}
.nv{position:relative;border-radius:9px!important;padding:10px 14px!important;letter-spacing:2px!important}
#menu .mtop{gap:14px!important}
#menu .logo h1{font-size:26px!important}
.nv.on{background:linear-gradient(180deg,#ff4655,#d8323f)!important;border-color:transparent!important;box-shadow:0 6px 22px -8px #ff4655}
.nv .ndot{position:absolute;top:4px;right:6px;min-width:16px;height:16px;border-radius:8px;background:#ffd23a;color:#111;font:900 .58rem/16px system-ui;text-align:center;padding:0 4px;font-style:normal;animation:ndot 1.6s infinite}
@keyframes ndot{50%{transform:scale(1.18)}}
#msub{border-bottom:none!important;margin-bottom:8px!important}
/* accueil */
#tab-home{height:100%}
.lobby{display:grid;grid-template-columns:minmax(0,1.3fr) minmax(0,1fr) minmax(0,1fr);gap:18px;height:100%;min-height:0}
.lcol{display:flex;flex-direction:column;gap:14px;min-height:0;overflow:auto;padding-right:4px}
.lcard{background:linear-gradient(180deg,#121b2cdd,#0b111ccc);border:1px solid #ffffff14;border-radius:14px;padding:16px 18px;backdrop-filter:blur(10px);-webkit-backdrop-filter:blur(10px);opacity:0;transform:translateY(14px);animation:lcIn .5s cubic-bezier(.2,.8,.2,1) forwards}
.lcol:nth-child(2) .lcard{animation-delay:.08s}.lcol:nth-child(3) .lcard{animation-delay:.16s}
.lcard+.lcard{animation-delay:.12s}
@keyframes lcIn{to{opacity:1;transform:none}}
.lcard h4{display:flex;align-items:center;gap:8px;font-size:.72rem;letter-spacing:3px;color:#fff;margin-bottom:12px;font-weight:900}
.lcard h4 small{margin-left:auto;font-size:.62rem;letter-spacing:1px;color:#8da0bd;font-weight:600}
.hero{position:relative;overflow:hidden;padding:26px 26px 22px;border:1px solid #ff465544;background:radial-gradient(120% 140% at 0% 0%,#ff465540,transparent 55%),radial-gradient(120% 120% at 100% 100%,#4aa3ff30,transparent 60%),linear-gradient(160deg,#151f33ee,#0a0f1aee)}
.hero::after{content:'';position:absolute;inset:0;background:linear-gradient(105deg,transparent 30%,#ffffff12 45%,transparent 60%);transform:translateX(-100%);animation:hshine 5s 1s infinite;pointer-events:none}
@keyframes hshine{40%,100%{transform:translateX(100%)}}
#menu.theme-hw .hero{border-color:#ff8a2a66;background:radial-gradient(120% 140% at 0% 0%,#ff7a1a50,transparent 55%),radial-gradient(120% 120% at 100% 100%,#8a3dff40,transparent 60%),linear-gradient(160deg,#1d1426ee,#0b0a12ee)}
.hero .htag{display:inline-flex;gap:8px;align-items:center;font-size:.66rem;letter-spacing:2px;font-weight:900;color:#ffd23a;background:#ffd23a1a;border:1px solid #ffd23a55;border-radius:20px;padding:5px 12px;margin:0 6px 12px 0;cursor:pointer}
.hero .htag.hw{color:#ffae5a;background:#ff7a1a22;border-color:#ff7a1a66}
.hero h2{font-size:2.1rem;line-height:1.05;letter-spacing:2px;margin-bottom:6px;font-weight:900}
.hero h2 span{color:var(--accent)}
.hero p{color:#b8c5da;font-size:.82rem;margin-bottom:18px}
.hero .hplay{display:block;width:100%;font-size:1.7rem;padding:20px;letter-spacing:6px}
.hero .hplay small{display:block;font-size:.66rem;letter-spacing:2px;opacity:.85;margin-top:4px;font-weight:700}
.hero .hrow{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-top:10px}
.hero .hrow .btn{font-size:.95rem;padding:13px 8px}
.lmini{display:grid;grid-template-columns:1fr 1fr;gap:14px}
.lmini .lcard{cursor:pointer;transition:transform .15s,border-color .15s}
.lmini .lcard:hover{transform:translateY(-2px);border-color:#ffffff33}
.lbig{font-size:1.5rem;font-weight:900;letter-spacing:1px}
.lbar{height:6px;background:#ffffff12;border-radius:3px;overflow:hidden;margin-top:8px}
.lbar i{display:block;height:100%;background:linear-gradient(90deg,#ff4655,#ffd23a);border-radius:3px;transition:width .6s}
.lsub{font-size:.7rem;color:#8da0bd;margin-top:6px}
.lmis{padding:10px 12px;background:#ffffff08;border:1px solid #ffffff10;border-radius:10px;margin-bottom:8px;font-size:.78rem}
.lmis .lt{display:flex;justify-content:space-between;gap:8px;align-items:center}
.lmis .lr{font-size:.66rem;color:#8da0bd;white-space:nowrap}
.lglow{border-color:#ffd23a88!important;animation:lcIn .5s forwards,lglow 1.8s .5s infinite!important}
.lmis.done{border-color:#ffd23a88;background:#ffd23a14;animation:lglow 1.8s infinite}
.lmis.claimed{opacity:.5}
.lmis.claimed .lbar i{background:#7dff9f}
.lmis.wk .lbar i{background:linear-gradient(90deg,#8a5bff,#c77dff)}
@keyframes lglow{50%{box-shadow:0 0 18px -4px #ffd23a}}
.lmis button,.lclaim{background:#ffd23a;color:#111;border:none;border-radius:6px;font:900 .64rem system-ui;letter-spacing:1px;padding:6px 10px;cursor:pointer}
.lmis button:hover,.lclaim:hover{filter:brightness(1.1)}
.lnews{display:flex;gap:12px;align-items:flex-start;padding:10px 4px;border-bottom:1px solid #ffffff0d;cursor:default}
.lnews:last-child{border-bottom:none}
.lnews[data-go]{cursor:pointer}.lnews[data-go]:hover{background:#ffffff08;border-radius:8px}
.lnews .ni{font-size:1.4rem;width:34px;height:34px;flex:none;display:flex;align-items:center;justify-content:center;background:#ffffff0d;border-radius:9px}
.lnews b{display:block;font-size:.8rem;letter-spacing:.5px}
.lnews span{font-size:.7rem;color:#8da0bd;line-height:1.35}
.lnews em{font-style:normal;font-size:.55rem;font-weight:900;letter-spacing:1px;background:var(--accent);color:#fff;border-radius:4px;padding:1px 5px;margin-left:6px;vertical-align:2px}
#lobbyRewards:empty{display:none}
/* interrupteur SOLO / AVEC DES AMIS */
.pmode{display:inline-flex;background:#0b111c;border:1px solid #ffffff18;border-radius:12px;padding:4px;gap:4px}
.pmode div{padding:9px 20px;border-radius:9px;cursor:pointer;font-weight:900;font-size:.76rem;letter-spacing:2px;color:#8da0bd;transition:.15s;white-space:nowrap}
.pmode div:hover{color:#fff}
.pmode div.on{background:#fff;color:#0b1018}
.pmode div.on.fr{background:linear-gradient(180deg,#4aa3ff,#2c7fe0);color:#fff}
.pmode div i{font-style:normal;background:#7dff9f;color:#111;border-radius:8px;padding:1px 6px;margin-left:6px;font-size:.62rem}
/* salon */
.frbox{background:linear-gradient(180deg,#132036,#0d1626)!important;border:1px solid #4aa3ff55!important;border-radius:12px!important;padding:14px!important}
.frbox>h4{color:#9fd0ff!important}
.frbox .btn{width:100%;font-size:1rem;padding:13px}
.frjoin{display:flex;gap:8px;margin-top:10px}
.frjoin input{flex:1;min-width:0;text-transform:uppercase;letter-spacing:5px;font-weight:900;text-align:center}
.frjoin .btn{width:auto;padding:10px 16px;font-size:.85rem}
.frcode{display:flex;align-items:center;gap:10px;background:#0a1120;border:1px dashed #4aa3ff88;border-radius:10px;padding:10px 12px;margin-bottom:10px}
.frcode span{font-size:.6rem;letter-spacing:2px;color:#8da0bd}
.frcode b{font-size:1.9rem;letter-spacing:8px;color:#ffd23a;flex:1}
.frcode button{background:#4aa3ff;color:#fff;border:none;border-radius:7px;padding:8px 10px;font:800 .66rem system-ui;letter-spacing:1px;cursor:pointer;white-space:nowrap}
.frpl{display:flex;flex-direction:column;gap:5px;margin:8px 0}
.frpl div{display:flex;align-items:center;gap:8px;background:#ffffff0a;border-radius:8px;padding:7px 10px;font-size:.8rem;font-weight:700}
.frpl div small{margin-left:auto;font-size:.6rem;letter-spacing:1px;color:#ffd23a}
.frpl div.wait{color:#6f819e;font-weight:500;font-style:italic}
#mpStatus{font-size:.72rem;color:#9fb4d2;margin:6px 0;line-height:1.4}
.frbox .frl{display:block;text-align:center;font-size:.7rem;color:#8da0bd;cursor:pointer;margin-top:8px;text-decoration:underline}
.frbox .frl:hover{color:#fff}
.frbox details.adv{margin-top:10px}
.frbox .chips{display:flex;flex-wrap:wrap;gap:6px}
.frbox .chip{padding:8px 10px!important;font-size:.72rem!important}
.frmsg{font-size:.72rem;color:#b8c5da;line-height:1.5;margin-top:4px}
body.lfr #modeCards .mcard.nonet{opacity:.3;filter:grayscale(1)}
body.lfr #modeCards .mcard.nonet::after{content:'Solo';position:absolute;bottom:6px;left:50%;transform:translateX(-50%);font-size:.55rem;letter-spacing:1px;color:#8da0bd}
body.lfr.lcli #tab-play .playgrid>.col:nth-child(-n+2){pointer-events:none;opacity:.55}
#hostSel{display:none;margin:0 0 10px;padding:10px 12px;border-radius:10px;background:#4aa3ff1a;border:1px solid #4aa3ff55;font-size:.78rem;color:#cfe5ff}
body.lfr.lcli #hostSel{display:block}
body.lfr #quickBtn{display:none!important}
body.lfr.lcli .cfgscroll>*:not(#frBox),body.lfr.lcli #sumbar{display:none!important}
#playBtn small{display:block;font-size:.7rem;letter-spacing:2px;opacity:.85;margin-top:3px}
#playBtn.wait{filter:grayscale(.8);opacity:.7;animation:none}
@media(max-width:1150px){.lobby{grid-template-columns:1fr 1fr;height:auto}.lobby .lcol:first-child{grid-column:1/-1}.lcol{overflow:visible}}
@media(max-width:760px){.lobby{grid-template-columns:1fr}.lmini{grid-template-columns:1fr}}
/* tableau des scores */
#sb{width:min(900px,96vw)!important;padding:0!important;background:linear-gradient(180deg,#0e1524f2,#090d16f2)!important;border:1px solid #ffffff1c!important;border-radius:16px;overflow:hidden;box-shadow:0 30px 80px -20px #000;animation:sbIn .18s ease-out}
@keyframes sbIn{from{opacity:0;transform:translate(-50%,-48%) scale(.97)}}
.sbhd{display:flex;align-items:center;gap:14px;padding:14px 20px;background:#ffffff08;border-bottom:1px solid #ffffff12}
.sbhd .sbm{font-size:.72rem;letter-spacing:2px;color:#b8c5da;font-weight:800;text-transform:uppercase}
.sbhd .sbm b{color:#fff;font-size:.9rem;margin-right:6px}
.sbhd .sbt{margin-left:auto;font:900 1.2rem system-ui;letter-spacing:2px;color:#fff;background:#ffffff10;border-radius:8px;padding:4px 12px}
.sbvs{display:flex;align-items:center;justify-content:center;gap:18px;padding:12px 0 4px}
.sbvs b{font:900 2.4rem system-ui;min-width:60px;text-align:center}
.sbvs span{font-size:.62rem;letter-spacing:3px;font-weight:900}
.sbvs i{font-style:normal;color:#5b6b85;font-weight:900}
.sbx{padding:6px 16px 14px}
.sbtm{margin-top:10px;border-radius:10px;overflow:hidden;border:1px solid #ffffff10}
.sbtm .sbth{display:flex;justify-content:space-between;align-items:center;padding:7px 12px;font-size:.66rem;letter-spacing:3px;font-weight:900;background:color-mix(in srgb,var(--tc) 22%,transparent);border-left:4px solid var(--tc);color:#fff}
.sbx table{width:100%;border-collapse:collapse;font-size:.82rem;margin:0!important;table-layout:fixed}
.sbx th:first-child{width:38px}.sbx th:nth-child(2){width:36%}
.sbx th{font-size:.56rem!important;letter-spacing:2px;color:#6f819e!important;padding:6px 10px!important;text-align:right;font-weight:800;background:#ffffff05;border:none!important}
.sbx th:nth-child(2),.sbx td:nth-child(2){text-align:left!important}
.sbx td{padding:7px 10px!important;border-top:1px solid #ffffff0b!important;text-align:right;font-variant-numeric:tabular-nums}
.sbx td.sbrk{color:#6f819e;font-weight:900;text-align:center!important;background:none;border-radius:0}
.sbx td:nth-child(2){white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.sbx tr.me td{background:#ffd23a1f!important}
.sbx tr.me td:nth-child(2){color:#ffd23a;font-weight:900}
.sbx tr.dead td{opacity:.42}
.sbx tr.dead td:nth-child(2)::before{content:'☠ ';}
.sbx td em{font-style:normal;font-size:.55rem;font-weight:900;letter-spacing:1px;border-radius:4px;padding:1px 5px;margin-left:6px;vertical-align:1px}
.sbx td em.mvp{background:#ffd23a;color:#111}
.sbx td em.on{background:#4aa3ff;color:#fff}
.sbx td em.bot{background:#ffffff14;color:#8da0bd}
.sbx td.kk{font-weight:900;color:#fff}
.sbft{padding:8px 20px 12px;font-size:.62rem;letter-spacing:1.5px;color:#5b6b85;text-align:center}
#oTable .sbx{padding:0}
`;document.head.appendChild(s);
}

/* ---------- accueil ---------- */
function lobbyBuild(){
 if($('tab-home'))return;
 const body=document.querySelector('#menu .mbody');if(!body)return;
 const tp=document.createElement('div');tp.className='tp';tp.id='tab-home';
 tp.innerHTML='<div class="lobby"><div class="lcol" id="lcA"></div><div class="lcol" id="lcB"></div><div class="lcol" id="lcC"></div></div>';
 body.insertBefore(tp,body.firstChild);
}
function lobbyDraw(){
 if(!$('tab-home'))return;
 const A=$('lcA'),B=$('lcB'),C=$('lcC');
 const name=cfg.name&&cfg.name!=='Vous'?cfg.name:'soldat';
 const f=typeof featuredMode==='function'?featuredMode():null;
 // colonne 1 : JOUER
 let tags='';
 if(typeof eventActive==='function'&&eventActive()){
  const pk=PROF.ev&&PROF.ev.id===EVENT.id?PROF.ev.pk:0,days=Math.max(0,Math.ceil((new Date(EVENT.to+'T23:59:59')-new Date())/864e5));
  tags+='<span class="htag hw" data-go="career">🎃 '+EVENT.n.toUpperCase()+' · '+pk+' citrouille'+(pk>1?'s':'')+' · encore '+days+' j</span>';
 }
 if(f&&MODES[f])tags+='<span class="htag" data-go="feat">★ MODE DE LA SEMAINE : '+modeName(f).toUpperCase()+' · XP ×2</span>';
 const sel=MODES[cfg.mode]?modeName(cfg.mode)+' · '+MAPS[cfg.map].n:'';
 let h='<div class="lcard hero">'+tags+'<h2>PRÊT AU COMBAT,<br><span>'+String(name).replace(/</g,'&lt;').toUpperCase()+'</span> ?</h2><p>Lance une partie, relève les défis du jour et débloque de nouveaux skins.</p>'+
  '<button class="btn cut hplay" data-go="playnow">▶ JOUER<small>'+sel+'</small></button>'+
  '<div class="hrow"><button class="btn alt cut" data-go="quick">⚡ PARTIE RAPIDE</button><button class="btn alt cut" data-go="friends">👥 AVEC DES AMIS</button></div>'+
  '<div class="hrow"><button class="btn alt cut" data-go="choose" style="grid-column:1/-1;font-size:.8rem;padding:10px">CHOISIR LE MODE ET LA CARTE</button></div></div>';
 h+='<div class="lmini">';
 if(typeof SEASON!=='undefined'&&typeof ensureBP==='function'){ensureBP();const pc=Math.round((PROF.bp.xp%SEASON.xpPer)/SEASON.xpPer*100);
  h+='<div class="lcard" data-go="career"><h4>★ '+SEASON.n.toUpperCase()+'</h4><div class="lbig">Palier '+bpTier()+' <small style="font-size:.8rem;color:#8da0bd">/ '+SEASON.tiers+'</small></div><div class="lbar"><i style="width:'+pc+'%"></i></div><div class="lsub">'+pc+' % vers le palier suivant</div></div>';}
 const ds=dailyStatus();
 h+='<div class="lcard" data-go="daily"><h4>🎁 CADEAU DU JOUR</h4><div class="lbig">Jour '+(ds.can?ds.day+1:((ds.streak-1)%7+1))+' <small style="font-size:.8rem;color:#8da0bd">/ 7</small></div><div class="lbar"><i style="width:'+Math.round(((ds.can?ds.day:((ds.streak-1)%7+1)))/7*100)+'%"></i></div><div class="lsub">'+(ds.can?'<button class="lclaim">RÉCUPÉRER</button>':'Série de '+ds.streak+' jour'+(ds.streak>1?'s':'')+' · reviens demain')+'</div></div>';
 h+='</div>';
 A.innerHTML=h;
 // colonne 2 : défis
 ensureMissions();
 const mis=(m,d,i,wk)=>'<div class="lmis'+(wk?' wk':'')+(m.claimed?' claimed':m.done?' done':'')+'"><div class="lt"><span>'+d.n.replace('{t}',d.t)+'</span>'+(m.done&&!m.claimed?'<button data-'+(wk?'w':'d')+'="'+i+'">RÉCUPÉRER</button>':m.claimed?'<span class="lr">✔</span>':'')+'</div><div class="lbar"><i style="width:'+Math.round(m.p/d.t*100)+'%"></i></div><div class="lr" style="margin-top:5px">'+m.p+' / '+d.t+' · 🪙 '+d.coins+' · '+d.xp+' XP</div></div>';
 let b='<div class="lcard"><h4>🎯 DÉFIS DU JOUR <small>nouveaux dans '+untilMidnight()+'</small></h4>'+PROF.missions.list.map((m,i)=>mis(m,missionDef(m.id),i,false)).join('')+'</div>';
 if(typeof ensureWeekly==='function'){ensureWeekly();b+='<div class="lcard"><h4>🏆 DÉFIS DE LA SEMAINE <small>nouveaux dans '+weekLeft()+'</small></h4>'+PROF.wmis.list.map((m,i)=>mis(m,wDef(m.id),i,true)).join('')+'</div>';}
 B.innerHTML=b;
 // colonne 3 : nouveautés + emplacement récompenses
 const seen=newsSeen();
 let rw=$('lobbyRewards');if(rw)rw.remove();else{rw=document.createElement('div');rw.id='lobbyRewards';}
 C.innerHTML='<div class="lcard"><h4>📰 NOUVEAUTÉS</h4>'+NEWS.map(n=>'<div class="lnews"'+(n.go?' data-go="'+n.go+'"':'')+'><div class="ni">'+n.ic+'</div><div><b>'+n.t+(seen.includes(n.id)?'':'<em>NOUVEAU</em>')+'</b><span>'+n.d+'</span></div></div>').join('')+'</div>';
 C.insertBefore(rw,C.firstChild);
 // cadeaux de fidélité / Premium (module 8W_loyalty, s'il est présent)
 if(typeof loyOpen==='function'){
  const lp=typeof loyPending==='function'?loyPending()||0:0,vip=typeof vipOn==='function'&&vipOn();
  const lc=document.createElement('div');lc.className='lmini';
  lc.innerHTML='<div class="lcard'+(lp?' lglow':'')+'" data-go="loy"><h4>🎁 CADEAUX</h4><div class="lbig">'+(lp?lp+' <small style="font-size:.8rem;color:#8da0bd">à récupérer</small>':'✔')+'</div><div class="lsub">'+(lp?'<button class="lclaim">OUVRIR</button>':'Plus tu joues, plus tu gagnes')+'</div></div>'+
   (typeof vipOpen==='function'?'<div class="lcard" data-go="vip" style="border-color:#ffd23a55"><h4>👑 PREMIUM</h4><div class="lbig" style="color:#ffd23a">'+(vip?'Actif':'Découvrir')+'</div><div class="lsub">Récompenses et pseudo en couleur</div></div>':'');
  C.insertBefore(lc,rw.nextSibling);
 }
 // actions
 const go=g=>{
  initAudio();sfxUI();
  if(g==='playnow'){fixMapForMode();if(LOBBY.friends)lobbySetFriends(false);startMatch();buildRadarMap();}
  else if(g==='quick')quickPlay();
  else if(g==='friends'){lobbySetFriends(true);navGo('play');}
  else if(g==='choose'){lobbySetFriends(false);navGo('play');}
  else if(g==='feat'&&f){cfg.mode=f;saveCfg();fixMapForMode();lobbySetFriends(false);drawMenu();navGo('play');}
  else if(g==='career')navGo('career');
  else if(g==='daily')showDaily();
  else if(g==='loy'&&typeof loyOpen==='function')loyOpen();
  else if(g==='vip'&&typeof vipOpen==='function')vipOpen();
  else if(g==='boxes'){navGo('arsenal');navTab('boxes');}
  else if(g==='arms'){navGo('arsenal');navTab('arms');}
  else if(g.startsWith('mode:')){const k=g.slice(5);if(MODES[k]){cfg.mode=k;saveCfg();fixMapForMode();drawMenu();}lobbySetFriends(false);navGo('play');}
 };
 $('tab-home').querySelectorAll('[data-go]').forEach(el=>el.onclick=e=>{e.stopPropagation();go(el.dataset.go);});
 B.querySelectorAll('button[data-d]').forEach(x=>x.onclick=e=>{e.stopPropagation();const r=claimMission(+x.dataset.d);if(r){sfx('pickup');confetti(['#ffd23a','#ffffff','#ff4655'],90,.5,.4);showLevelUps(r.ups);refreshProfile();renderMissions();lobbyDraw();navRender();}});
 B.querySelectorAll('button[data-w]').forEach(x=>x.onclick=e=>{e.stopPropagation();const r=claimWeekly(+x.dataset.w);if(r){sfx('pickup');confetti(['#c77dff','#ffffff','#ffd23a'],110,.5,.4);showLevelUps(r.ups);refreshProfile();renderMissions();lobbyDraw();navRender();}});
}
// la récompense quotidienne met aussi l'accueil à jour
const _refreshProfileLobby=refreshProfile;
refreshProfile=function(){_refreshProfileLobby();if(tabNow==='home'&&!G.running)try{lobbyDraw();}catch(e){}};

/* ---------- navigation : « Accueil » en premier, « Jouer » sans sous-onglets ---------- */
NAV.unshift({id:'home',n:'Accueil',ic:'⌂',sub:[['home','Accueil']]});
NAV.find(g=>g.id==='play').sub=[['play','Jouer']];
const _navTabLobby=navTab;
navTab=function(t){
 if(t==='home'){
  initAudio();tabNow='home';pvOn=lkOn=false;
  document.querySelectorAll('.tp').forEach(p=>p.classList.toggle('on',p.id==='tab-home'));
  navSub[navGroup]=t;lobbyDraw();navRender();
  setTimeout(newsMarkSeen,4000); // le badge NOUVEAU reste visible le temps d'être lu
  return;
 }
 if(t==='mp'){lobbySetFriends(true);t='play';}
 _navTabLobby(t);
};
const _navRenderLobby=navRender;
navRender=function(){
 _navRenderLobby();
 const nav=$('mnav');if(!nav)return;
 const n=lobbyPending(),hv=nav.children[NAV.findIndex(g=>g.id==='home')];
 if(hv&&n&&navGroup!=='home')hv.insertAdjacentHTML('beforeend','<em class="ndot">'+n+'</em>');
 const sub=$('msub');
 if(navGroup==='play'&&sub){
  const pm=document.createElement('div');pm.className='pmode';
  const inRoom=NET.role?'<i>'+(NET.role==='host'?NET.players.size+1:(NET.lobby||[]).length||1)+'</i>':'';
  pm.innerHTML='<div data-f="0"'+(LOBBY.friends?'':' class="on"')+'>🎮 SOLO</div><div data-f="1" class="fr'+(LOBBY.friends?' on':'')+'">👥 AVEC DES AMIS'+inRoom+'</div>';
  pm.querySelectorAll('div').forEach(d=>d.onclick=()=>{sfxUI();lobbySetFriends(d.dataset.f==='1');});
  sub.insertBefore(pm,sub.firstChild);
  const hint=sub.querySelector('.hint');if(hint){hint.style.display='';hint.textContent=LOBBY.friends?(NET.role==='client'?'L\'hôte choisit le mode et la carte':'Crée un salon, envoie le lien à tes amis, puis lance'):'Choisis un mode, une carte, puis clique sur JOUER';}
 }
};

/* ---------- jouer avec des amis ---------- */
function lobbySetFriends(on){
 LOBBY.friends=!!on;
 if(on&&!NET_OK_MODES[cfg.mode]&&NET.role!=='client'){cfg.mode='tdm';saveCfg();fixMapForMode();}
 drawMenu();if(typeof navGroup!=='undefined'&&navGroup==='play')navRender();
}
function frEsc(s){return String(s).replace(/[<&]/g,c=>c==='<'?'&lt;':'&amp;');}
function frInvite(){return location.href.split('#')[0]+'#join='+NET.room+(NET.mode==='local'?'&local':'');}
function frDraw(){
 const play=$('playBtn'),sc=document.querySelector('#tab-play .cfgscroll');
 document.body.classList.toggle('lfr',LOBBY.friends);
 document.body.classList.toggle('lcli',LOBBY.friends&&NET.role==='client');
 // tuiles des modes incompatibles avec le jeu en ligne
 const keys=[];for(const [,l] of MODE_GROUPS)for(const k of l)if(MODES[k])keys.push(k);
 const mc=$('modeCards');if(mc)[...mc.children].forEach((c,i)=>c.classList.toggle('nonet',!NET_OK_MODES[keys[i]]));
 // sélection de l'hôte vue par un invité
 const cMode=sc&&document.querySelector('#tab-play .playgrid>.col');
 let hs=$('hostSel');if(!hs&&cMode){hs=document.createElement('div');hs.id='hostSel';cMode.insertBefore(hs,cMode.children[1]);}
 if(hs){const s=NET.hostSel;hs.innerHTML=s&&MODES[s.mode]?'👑 L\'hôte a choisi <b>'+modeName(s.mode)+'</b> sur <b>'+(MAPS[s.map]?MAPS[s.map].n:s.map)+'</b>':'👑 L\'hôte choisit le mode et la carte';}
 let box=$('frBox');
 if(!LOBBY.friends){if(box)box.style.display='none';if(play){play.classList.remove('wait');play.textContent='JOUER';}return;}
 if(!sc)return;
 if(!box){box=document.createElement('div');box.id='frBox';box.className='csec frbox';sc.insertBefore(box,sc.firstChild);}
 box.style.display='';
 const host=NET.role==='host',cli=NET.role==='client',keep=$('frCode')?$('frCode').value:'';
 let h='<h4>👥 SALON</h4>';
 if(!NET.role){
  h+='<button class="btn cut" id="frHost">CRÉER UN SALON</button><div class="frmsg" style="text-align:center;margin:10px 0 0">ou rejoins celui d\'un ami</div>'+
   '<div class="frjoin"><input type="text" id="frCode" maxlength="6" placeholder="CODE" value="'+frEsc(keep)+'"><button class="btn alt cut" id="frJoin">REJOINDRE</button></div>';
 }else{
  h+='<div class="frcode"><div><span>CODE</span><br><b>'+frEsc(NET.room)+'</b></div>'+(host?'<button id="frCopy">🔗 COPIER LE LIEN</button>':'')+'</div>';
  const list=host?[{name:(cfg.name||'Hôte'),tag:'HÔTE · TOI'}].concat([...NET.players.values()].map(p=>({name:p.name}))):(NET.lobby||[]).map(p=>({name:p.name,tag:p.host?'HÔTE':''}));
  h+='<div class="frpl">'+list.map(p=>'<div>👤 '+frEsc(p.name)+(p.tag?'<small>'+p.tag+'</small>':'')+'</div>').join('')+(host&&!NET.players.size?'<div class="wait">En attente d\'amis… envoie-leur le lien</div>':'')+'</div>';
 }
 h+='<div id="mpStatus">'+frEsc(NET.status&&NET.status!=='Hors ligne'?NET.status:'')+'</div>';
 if(!cli)h+='<div class="chips" id="frTeams"></div>';
 h+='<details class="adv"><summary>PLUS D\'OPTIONS</summary><div class="grp"><label>Connexion</label><div class="chips" id="frNet"></div></div><div class="grp"><label>Mon équipe</label><div class="chips" id="frPref"></div></div></details>';
 if(NET.role)h+='<a class="frl" id="frLeave">Quitter le salon</a>';
 const open=box.querySelector('details.adv')&&box.querySelector('details.adv').open;
 box.innerHTML=h;if(open)box.querySelector('details.adv').open=true;
 if(!cli)chipsRow('frTeams',[['Ensemble contre les bots','coop'],['Les uns contre les autres','versus']],()=>NET.teams,v=>{NET.teams=v;if(host)netLobbyBroadcast();},frDraw);
 chipsRow('frNet',[['En ligne (code)','online'],['Même PC (onglets)','local']],()=>NET.mode,v=>{if(NET.role)netLeave();NET.mode=v;},frDraw);
 chipsRow('frPref',[['Auto',-1],['Attaquants',0],['Défenseurs',1]],()=>NET.pref===undefined?-1:NET.pref,v=>{NET.pref=v;if(NET.role==='client')netSend({t:'pref',v},'host');},frDraw);
 const on=(id,f)=>{const e=$(id);if(e)e.onclick=f;};
 on('frHost',()=>{initAudio();sfxUI();netHost();});
 on('frJoin',()=>{initAudio();sfxUI();netJoin($('frCode').value);});
 if($('frCode'))$('frCode').onkeydown=e=>{e.stopPropagation();if(e.code==='Enter'){initAudio();netJoin($('frCode').value);}};
 on('frLeave',()=>{sfxUI();netLeave();});
 on('frCopy',()=>{const u=frInvite();sfxUI();
  const ok=()=>menuToast('Lien copié : envoie-le à tes amis');
  if(navigator.clipboard&&navigator.clipboard.writeText)navigator.clipboard.writeText(u).then(ok,()=>prompt('Lien d\'invitation',u));else prompt('Lien d\'invitation',u);});
 if(play){
  play.classList.toggle('wait',cli||!NET.role);
  const n=NET.players.size+1;
  play.innerHTML=host?'LANCER<small>'+n+' joueur'+(n>1?'s':'')+' + bots</small>':cli?'EN ATTENTE<small>l\'hôte lance la partie</small>':'CRÉER LE SALON';
 }
}
// le salon remplace l'ancien onglet « Multijoueur » : même état, nouvel affichage
function netLobbyDraw(){
 frDraw();
 if(typeof navGroup!=='undefined'&&navGroup==='play'&&$('msub'))navRender();
}
// l'hôte envoie aussi sa sélection (mode, carte) aux invités
function netLobbyBroadcast(){netSend({t:'lobby',players:[{name:cfg.name||'Hôte',host:1}].concat([...NET.players.values()].map(p=>({name:p.name}))),sel:{mode:cfg.mode,map:cfg.map}});}
const _netClientMsgLobby=netClientMsg;
netClientMsg=function(m){
 if(m&&m.t==='lobby'&&m.sel){NET.hostSel=m.sel;
  // l'invité voit la sélection de l'hôte surlignée (la vraie config arrive au lancement)
  if(!G.running&&MODES[m.sel.mode]&&MAPS[m.sel.map]&&(cfg.mode!==m.sel.mode||cfg.map!==m.sel.map)){cfg.mode=m.sel.mode;cfg.map=m.sel.map;try{previewMapWorld();}catch(e){}}}
 _netClientMsgLobby(m);
 if(m&&m.t==='lobby'&&!G.running)drawMenu();
};
const _drawMenuLobby=drawMenu;
drawMenu=function(){
 _drawMenuLobby();
 try{frDraw();}catch(e){console.error(e);}
 if(NET.role==='host'&&!G.running){const k=cfg.mode+'|'+cfg.map;if(LOBBY.lastSel!==k){LOBBY.lastSel=k;netLobbyBroadcast();}}
};
function lobbyPlay(){
 initAudio();sfxUI();
 if(!LOBBY.friends){startMatch();buildRadarMap();return;}
 if(!NET.role){netHost();return;}
 if(NET.role==='client'){menuToast('L\'hôte lance la partie');return;}
 if(!NET_OK_MODES[cfg.mode]){menuToast('Ce mode se joue seul : choisis un autre mode');return;}
 cfg.cine=0;startMatch();buildRadarMap();netHostStart();
}
// clic sur un mode incompatible en mode « avec des amis »
const _buildModeCardsLobby=buildModeCards;
buildModeCards=function(){
 _buildModeCardsLobby();
 const keys=[];for(const [,l] of MODE_GROUPS)for(const k of l)if(MODES[k])keys.push(k);
 [...$('modeCards').children].forEach((c,i)=>{const k=keys[i],f=c.onclick;c.onclick=e=>{if(LOBBY.friends&&!NET_OK_MODES[k]){sfx('deny');menuToast(modeName(k)+' se joue seul');return;}f&&f.call(c,e);};});
};

/* ---------- tableau des scores (Tab) ---------- */
function scoreTable(final){
 const team=MODE().team,zm=G.variant==='zombies';
 const all=ents.filter(e=>!e.dummy&&!e.zombie);
 const mvp=all.reduce((b,e)=>!b||e.kills>b.kills||(e.kills===b.kills&&e.dmg>b.dmg)?e:b,null);
 const last=G.mode==='bomb'?'$':G.mode==='gg'?'NIV.':'';
 const head='<tr><th></th><th>JOUEUR</th><th>ÉLIM.</th><th>MORTS</th><th>K/D</th><th>HS</th><th>DÉGÂTS</th>'+(last?'<th>'+last+'</th>':'')+'</tr>';
 const row=(e,i)=>{
  const kd=e.deaths?(e.kills/e.deaths).toFixed(2):e.kills.toFixed(2),hsr=e.kills?Math.round(e.hsKills/e.kills*100)+'%':'–';
  const tags=(mvp===e&&e.kills>0?'<em class="mvp">MVP</em>':'')+(e.remote?'<em class="on">EN LIGNE</em>':'')+(NET.role&&!e.isPlayer&&!e.remote?'<em class="bot">BOT</em>':'');
  const nm=frEsc(e.name)+(e.isPlayer&&typeof titleName==='function'&&titleName()?' <span style="color:#8da0bd;font-weight:500">['+titleName()+']</span>':'');
  const lc=G.mode==='bomb'?(e.team===P.team||final?'$'+e.money:'–'):G.mode==='gg'?(e.ggLevel+1):'';
  return '<tr class="'+(e.isPlayer?'me':'')+(!e.alive&&!final?' dead':'')+'"><td class="sbrk">'+(i+1)+'</td><td>'+nm+tags+'</td><td class="kk">'+e.kills+'</td><td>'+e.deaths+'</td><td>'+kd+'</td><td>'+hsr+'</td><td>'+e.dmg+'</td>'+(last?'<td>'+lc+'</td>':'')+'</tr>';
 };
 let h='';
 if(!final){
  const te=$('timer'),tm=te&&te.firstChild&&te.firstChild.nodeType===3?te.firstChild.textContent:'';
  h+='<div class="sbhd"><div class="sbm"><b>'+(MODE().ic||'')+' '+modeName(G.variant)+'</b>'+(MAP?MAP.n:'')+(NET.role?' · EN LIGNE':'')+'</div>'+(tm?'<div class="sbt">'+tm+'</div>':'')+'</div>';
  if(team&&!zm)h+='<div class="sbvs"><span style="color:'+TEAMCSS[P.team]+'">'+(P.team===0?'ATTAQUANTS':'DÉFENSEURS')+'</span><b style="color:'+TEAMCSS[P.team]+'">'+G.score[P.team]+'</b><i>—</i><b style="color:'+TEAMCSS[1-P.team]+'">'+G.score[1-P.team]+'</b><span style="color:'+TEAMCSS[1-P.team]+'">'+(P.team===0?'DÉFENSEURS':'ATTAQUANTS')+'</span></div>';
 }
 h+='<div class="sbx">';
 if(team){
  const mk=t=>{const l=all.filter(e=>e.team===t).sort((a,b)=>b.kills-a.kills||b.dmg-a.dmg);
   return '<div class="sbtm" style="--tc:'+TEAMCSS[t]+'"><div class="sbth"><span>'+(zm?'SURVIVANTS':t===0?'ATTAQUANTS':'DÉFENSEURS')+' · '+l.filter(e=>e.alive).length+' en vie</span><span>'+(zm?'':G.score[t])+'</span></div><table>'+head+l.map(row).join('')+'</table></div>';};
  h+=mk(P.team)+(zm?'':mk(1-P.team));
 }else{
  const l=all.sort((a,b)=>(b.ggLevel-a.ggLevel)||(b.kills-a.kills));
  h+='<div class="sbtm" style="--tc:#ffd23a"><table>'+head+l.map(row).join('')+'</table></div>';
 }
 h+='</div>';
 if(!final)h+='<div class="sbft">Relâche Tab pour revenir au jeu</div>';
 return h;
}
setInterval(()=>{try{const sb=$('sb');if(G.running&&sb&&sb.style.display==='block'&&G.state!=='end')scoreboard();}catch(e){}},300);

/* ---------- mise en place ---------- */
const _menuNavInitLobby=menuNavInit;
menuNavInit=function(){
 lobbyCss();
 _menuNavInitLobby();
 lobbyBuild();
 // l'ancien onglet « Multijoueur » est remplacé par le salon de l'écran Jouer
 const old=$('tab-mp');if(old)old.remove();
 const ot=document.querySelector('#mtabs .mtab[data-t="mp"]');if(ot)ot.remove();
 $('playBtn').onclick=lobbyPlay;
 navGo('home');
 // lien d'invitation : #join=CODE
 const m=location.hash.match(/join=([A-Za-z0-9]{4,6})/);
 if(m){
  NET.mode=/[#&]local\b/.test(location.hash)?'local':'online';
  try{history.replaceState(null,'',location.href.split('#')[0]);}catch(e){}
  LOBBY.friends=true;navGo('play');
  setTimeout(()=>{netJoin(m[1]);frDraw();},300);
 }
};
setInterval(()=>{try{if(!G.running&&tabNow==='home'&&$('menu').classList.contains('show')){const b=$('lcB');const h=b&&b.querySelector('h4 small');if(h)h.textContent='nouveaux dans '+untilMidnight();}}catch(e){}},30000);
