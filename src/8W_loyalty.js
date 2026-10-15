/* =====================================================================
   FIDÉLITÉ ET PREMIUM
   Plus on joue, plus on gagne :
   - Cadeaux de temps de jeu : 5 cadeaux par jour selon les minutes
     réellement jouées en partie (remis à zéro chaque jour).
   - Paliers de série : la série de connexion (récompense quotidienne,
     62_meta.js) débloque de gros cadeaux à 3, 7, 14, 30, 60 et 100 jours.
   - Rang de fidélité : chaque jour où l'on joue au moins une partie
     compte ; chaque rang donne un cadeau et un bonus d'XP permanent.
   - Bonus : première victoire du jour, boost d'XP (quelques parties),
     cadeau « bon retour » après 3 jours d'absence.
   - Abonnement Premium (Robux, version Roblox) : couleur de pseudo,
     +20 % XP et pièces, cadeau Premium chaque jour, série protégée.
     Sur le web il n'y a pas de paiement : l'offre est affichée verrouillée
     (le panneau admin peut l'activer pour tester).
   Économie lente conservée : ~35 pièces par partie, ces cadeaux
   ajoutent environ 150 pièces par longue journée de jeu.
   Point d'entrée pour le lobby : loyPending() (nombre de cadeaux à
   récupérer), loyOpen() (centre des cadeaux), vipOpen() (Premium).
   ===================================================================== */
const PLAYTIME_GIFTS=[
 {m:10,r:{coins:15},ic:'🪙'},
 {m:20,r:{boost:2},ic:'⚡'},
 {m:35,r:{coins:30},ic:'💰'},
 {m:50,r:{coins:45},ic:'💎'},
 {m:75,r:{coins:70,boost:2},ic:'🎁'}
];
const STREAK_GOALS=[
 {d:3,r:{coins:100},ic:'🔥'},
 {d:7,r:{coins:200,boost:3},ic:'🔥'},
 {d:14,r:{box:'std',coins:150},ic:'📦'},
 {d:30,r:{box:'prem',title:'loy_flame'},ic:'👑'},
 {d:60,r:{box:'prem',coins:600},ic:'💠'},
 {d:100,r:{box:'prem',n:2,title:'loy_100'},ic:'🏆'}
];
const LOY_TIERS=[
 {d:0,n:'Nouvelle recrue',c:'#8da0bd',xp:0},
 {d:3,n:'Habitué',c:'#7dff9f',xp:2,r:{coins:100}},
 {d:7,n:'Régulier',c:'#4aa3ff',xp:4,r:{box:'std'}},
 {d:14,n:'Vétéran',c:'#c77dff',xp:6,r:{coins:300,title:'loy_vet'}},
 {d:30,n:'Fidèle',c:'#ffd75e',xp:8,r:{box:'prem',coins:200}},
 {d:60,n:'Pilier de l\'arène',c:'#ff7a4a',xp:10,r:{box:'prem',coins:500,title:'loy_pillar'}},
 {d:100,n:'Légende fidèle',c:'#ff4655',xp:12,r:{box:'prem',n:2,coins:800,title:'loy_legend'}}
];
const LOY_TITLES={loy_flame:'Flamme éternelle',loy_100:'Centurion',loy_vet:'Vétéran',loy_pillar:'Pilier de l\'arène',loy_legend:'Légende fidèle',vip:'⭐ Premium'};
const FIRST_WIN={xp:100,coins:25};
const BOOST_MULT=.5;            // +50 % d'XP pendant le boost
const BACK_DAYS=3,BACK_GIFT={coins:150,boost:3};
const VIP={xp:.2,coins:.2,daily:{coins:60},
 offers:[{id:'vip30',days:30,rbx:349,n:'30 jours'},{id:'vip90',days:90,rbx:899,n:'90 jours',best:true}],
 colors:[{id:'gold',n:'Or'},{id:'neon',n:'Néon'},{id:'rose',n:'Rose'},{id:'emerald',n:'Émeraude'},{id:'rainbow',n:'Arc-en-ciel'}]};

/* ---------- données ---------- */
function loyData(){
 const L=PROF.loy||(PROF.loy={});
 if(L.day===undefined)Object.assign(L,{day:'',secs:0,got:[],days:0,lastDay:'',total:0,tiers:[0],streakGot:[],boost:0,win:'',back:'',vip:{until:0,col:'gold',daily:'',shield:''}});
 L.vip=L.vip||{until:0,col:'gold',daily:'',shield:''};
 const t=todayStr();if(L.day!==t){L.day=t;L.secs=0;L.got=[];}
 return L;
}
loyData();
const vipOn=()=>loyData().vip.until>Date.now();
const vipDaysLeft=()=>Math.max(0,Math.ceil((loyData().vip.until-Date.now())/864e5));
const loyMin=()=>Math.floor(loyData().secs/60);
function loyTierIdx(){const d=loyData().days;let i=0;LOY_TIERS.forEach((t,k)=>{if(d>=t.d)i=k;});return i;}
const loyXpBonus=()=>LOY_TIERS[loyTierIdx()].xp/100;
function loyGiftText(r){
 const a=[];if(r.coins)a.push('+'+r.coins+' pièces');if(r.box)a.push((r.n||1)+' '+BOXES[r.box].n);
 if(r.boost)a.push('Boost XP ×1,5 ('+r.boost+' parties)');if(r.title)a.push('Titre « '+LOY_TITLES[r.title]+' »');return a.join(' • ');
}
function loyApply(r){
 const L=loyData();applyReward({coins:r.coins,box:r.box,n:r.n});
 if(r.boost)L.boost+=r.boost;
 if(r.title)loyAddTitle(r.title);
}
// titres gagnés : ajoutés à la liste de Profil › Style (niveau 1, donc toujours choisissables)
function loyAddTitle(id){
 const L=loyData();L.titles=L.titles||[];if(!L.titles.includes(id))L.titles.push(id);
 if(typeof TITLES!=='undefined'&&!TITLES.some(t=>t.id===id))TITLES.push({id,n:LOY_TITLES[id],lv:1});
}
(loyData().titles||[]).forEach(loyAddTitle);
function loyVipTitle(){
 if(typeof TITLES==='undefined')return;const i=TITLES.findIndex(t=>t.id==='vip');
 if(vipOn()&&i<0)TITLES.push({id:'vip',n:LOY_TITLES.vip,lv:1});
 if(!vipOn()&&i>=0){TITLES.splice(i,1);if(cfg.title==='vip'){cfg.title='';saveCfg();}}
}
loyVipTitle();

/* ---------- ce qui peut être récupéré ---------- */
const ptReady=i=>loyMin()>=PLAYTIME_GIFTS[i].m&&!loyData().got.includes(i);
const stReady=i=>(PROF.streak||0)>=STREAK_GOALS[i].d&&!loyData().streakGot.includes(STREAK_GOALS[i].d);
const tierReady=i=>i>0&&loyData().days>=LOY_TIERS[i].d&&!loyData().tiers.includes(i);
const vipDailyReady=()=>vipOn()&&loyData().vip.daily!==todayStr();
function loyPending(){
 let n=0;PLAYTIME_GIFTS.forEach((g,i)=>{if(ptReady(i))n++;});STREAK_GOALS.forEach((g,i)=>{if(stReady(i))n++;});
 LOY_TIERS.forEach((t,i)=>{if(tierReady(i))n++;});if(vipDailyReady())n++;return n;
}
function loyClaim(kind,i){
 const L=loyData();let r=null;
 if(kind==='pt'&&ptReady(i)){r=PLAYTIME_GIFTS[i].r;L.got.push(i);}
 else if(kind==='st'&&stReady(i)){r=STREAK_GOALS[i].r;L.streakGot.push(STREAK_GOALS[i].d);}
 else if(kind==='tier'&&tierReady(i)){r=LOY_TIERS[i].r;L.tiers.push(i);}
 else if(kind==='vip'&&vipDailyReady()){r=VIP.daily;L.vip.daily=todayStr();}
 if(!r)return null;loyApply(r);saveProf();return r;
}

/* ---------- temps de jeu : seulement en partie, fenêtre visible, pas en pause ---------- */
let loySaveT=0;
setInterval(()=>{
 if(!G.running||G.paused||document.hidden)return;
 const L=loyData(),before=loyMin();L.secs++;L.total++;
 const now=loyMin();
 if(now!==before){const g=PLAYTIME_GIFTS.find(x=>x.m===now);if(g)loyInGameNotice(g);}
 if(++loySaveT>=15){loySaveT=0;saveProf();}
},1000);
function loyInGameNotice(g){
 sfx('pickup');
 const d=document.createElement('div');d.className='loyNote';
 d.innerHTML='<span class="gi">'+g.ic+'</span><div><b>CADEAU DÉBLOQUÉ !</b><small>'+g.m+' min de jeu aujourd\'hui · '+loyGiftText(g.r)+'<br>Récupère-le au menu (🎁 Cadeaux)</small></div>';
 document.body.appendChild(d);setTimeout(()=>d.classList.add('out'),4200);setTimeout(()=>d.remove(),4900);
}

/* ---------- bonus de fin de partie ---------- */
const _loyCommit=commitMatch;
commitMatch=function(win){
 const r=_loyCommit(win),L=loyData(),t=todayStr();
 r.bonus=[];
 if(L.lastDay!==t){L.lastDay=t;L.days++;}                       // un jour de jeu de plus pour la fidélité
 const base=r.xp;let xp=0,coins=0;
 const fx=loyXpBonus();if(fx>0){const v=Math.round(base*fx);xp+=v;r.bonus.push('Fidélité +'+Math.round(fx*100)+' % ('+v+' XP)');}
 if(vipOn()){const v=Math.round(base*VIP.xp),c=Math.round(r.coins*VIP.coins);xp+=v;coins+=c;r.bonus.push('⭐ Premium +'+v+' XP, +'+c+' 🪙');}
 if(L.boost>0){const v=Math.round(base*BOOST_MULT);xp+=v;L.boost--;r.bonus.push('⚡ Boost +'+v+' XP ('+L.boost+' restante'+(L.boost>1?'s':'')+')');}
 if(win&&L.win!==t){L.win=t;xp+=FIRST_WIN.xp;coins+=FIRST_WIN.coins;r.bonus.push('🏆 Première victoire du jour +'+FIRST_WIN.xp+' XP, +'+FIRST_WIN.coins+' 🪙');}
 if(coins){PROF.coins+=coins;r.coins+=coins;}
 if(xp){r.ups=r.ups.concat(addXP(xp));r.xp+=xp;ensureBP();PROF.bp.xp+=xp;}
 saveProf();loyLastBonus=r.bonus;return r;
};
let loyLastBonus=null;
// lignes de bonus sous les récompenses de fin de partie
const _loyLines=progressLines;
progressLines=function(p){
 let h=_loyLines(p);const b=loyLastBonus;loyLastBonus=null;
 if(b&&b.length)h+=b.map(x=>'<div class="loyBonusLn">'+x+'</div>').join('');
 const n=loyPending();if(n)h+='<div class="loyBonusLn gift">🎁 '+n+' cadeau'+(n>1?'x':'')+' à récupérer au menu</div>';
 return h;
};

/* ---------- série : protégée une fois par semaine avec Premium ---------- */
const dayStr=ms=>{const d=new Date(ms);return d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0');};
function loyShieldOk(){
 const L=loyData();if(!vipOn()||!PROF.streak||PROF.lastLogin!==dayStr(Date.now()-2*864e5))return false;
 return L.vip.shield!==weekKeyLoy();
}
function weekKeyLoy(){const d=new Date();return 'w'+Math.floor((Date.UTC(d.getFullYear(),d.getMonth(),d.getDate())/864e5+3)/7);}
const _loyDaily=dailyStatus;
dailyStatus=function(){
 const st=_loyDaily();
 if(st.can&&st.next===1&&loyShieldOk()){const next=PROF.streak+1;return {can:true,day:(next-1)%7,next,streak:next,shield:true};}
 return st;
};
const _loyClaimDaily=claimDaily;
claimDaily=function(){
 const st=dailyStatus(),r=_loyClaimDaily();
 if(r&&st.shield){loyData().vip.shield=weekKeyLoy();saveProf();uiToast('⭐ Premium : ta série est protégée malgré le jour manqué !');}
 return r;
};

/* ---------- bon retour ---------- */
function loyWelcomeBack(){
 const L=loyData();if(!PROF.lastLogin||L.back===todayStr())return false;
 const last=new Date(PROF.lastLogin+'T12:00:00').getTime();if(!(last>0))return false;
 const gap=Math.floor((Date.now()-last)/864e5);if(gap<BACK_DAYS)return false;
 L.back=todayStr();loyApply(BACK_GIFT);saveProf();
 setTimeout(()=>loyBigGift('🎉','BON RETOUR !','Tu nous as manqué ('+gap+' jours). Cadeau : '+loyGiftText(BACK_GIFT)),1400);
 return true;
}

/* ---------- interface ---------- */
function loyCss(){
 if($('loyCss'))return;const s=document.createElement('style');s.id='loyCss';s.textContent=`
#msub{padding-right:270px}
#loyBar{position:absolute;top:88px;right:max(28px,calc((100% - 1320px) / 2 + 28px));display:flex;gap:8px;z-index:5}
#loyBtn,#vipBtn{position:relative;border:0;font-weight:900;letter-spacing:2px;padding:8px 14px;cursor:pointer;font-size:.7rem;white-space:nowrap;border-radius:6px}
#loyBtn{background:linear-gradient(135deg,#3a1d6e,#7a2cff);color:#fff;box-shadow:0 0 0 1px #b48cff55 inset}
#loyBtn.has{animation:loyWig 2.6s infinite}
#loyBtn .bdg{position:absolute;top:-7px;right:-7px;min-width:19px;height:19px;border-radius:10px;background:#ff4655;color:#fff;font-size:.66rem;display:flex;align-items:center;justify-content:center;padding:0 5px;box-shadow:0 0 10px #ff4655;animation:loyPulse 1.2s infinite}
#vipBtn{color:#2a1a00;background:linear-gradient(110deg,#ffb300 0%,#ffe680 35%,#fff6c9 50%,#ffd24a 65%,#ff9d00 100%);background-size:250% 100%;animation:vipShine 3s linear infinite;box-shadow:0 0 16px #ffb30055}
@keyframes vipShine{0%{background-position:100% 0}100%{background-position:-150% 0}}
@keyframes loyPulse{50%{transform:scale(1.18)}}
@keyframes loyWig{0%,84%,100%{transform:rotate(0)}87%{transform:rotate(-6deg)}90%{transform:rotate(6deg)}93%{transform:rotate(-4deg)}96%{transform:rotate(3deg)}}
.vipn{font-weight:900}
.vipn::before{content:"⭐ ";-webkit-text-fill-color:#ffd24a;filter:drop-shadow(0 0 4px #ffb300)}
.vipn-gold{background:linear-gradient(90deg,#ffb300,#fff2a8,#ffcf3a,#ffb300);background-size:200% 100%;-webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent;animation:vipShine 2.4s linear infinite}
.vipn-neon{color:#5ff6ff!important;-webkit-text-fill-color:#5ff6ff;text-shadow:0 0 6px #00e5ff,0 0 14px #00b3ff}
.vipn-rose{color:#ff6ad5!important;-webkit-text-fill-color:#ff6ad5;text-shadow:0 0 6px #ff2fb4,0 0 14px #ff2fb488}
.vipn-emerald{color:#4dffa6!important;-webkit-text-fill-color:#4dffa6;text-shadow:0 0 6px #00ff88,0 0 14px #00c86488}
.vipn-rainbow{background:linear-gradient(90deg,#ff4655,#ffb300,#fff36a,#4dff88,#4aa3ff,#c77dff,#ff4655);background-size:300% 100%;-webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent;animation:vipShine 2s linear infinite}
#loyOv .panel,#vipOv .panel{width:min(1020px,96vw);padding:0;overflow:auto;position:relative;border-radius:10px}
.loyHead{padding:22px 28px 16px;background:radial-gradient(circle at 15% 0,#7a2cff55,transparent 55%),radial-gradient(circle at 90% 20%,#ff465533,transparent 50%),#0d1220;border-bottom:1px solid var(--line)}
.loyHead h1{font-size:1.9rem;letter-spacing:5px;margin:0}.loyHead h1 span{color:#c9a4ff}
.loyHead p{margin:6px 0 0;color:var(--dim);font-size:.78rem;letter-spacing:1px}
.loyBody{padding:16px 28px 22px;display:grid;gap:16px}
.loySec{background:#0f1624;border:1px solid var(--line);border-radius:8px;padding:14px 16px}
.loySec>h3{margin:0 0 12px;font-size:.72rem;letter-spacing:3px;color:#fff;display:flex;align-items:center;gap:8px}
.loySec>h3 small{margin-left:auto;color:var(--dim);font-weight:600;letter-spacing:1px;font-size:.68rem}
.ptTrack{position:relative;height:118px;margin:4px 10px 0}
.ptBar{position:absolute;left:0;right:0;top:44px;height:8px;border-radius:5px;background:#1e2840;overflow:hidden}
.ptBar i{display:block;height:100%;background:linear-gradient(90deg,#7a2cff,#ff4655,#ffd75e);box-shadow:0 0 12px #ff4655;transition:width .8s}
.ptG{position:absolute;top:0;transform:translateX(-50%);text-align:center;width:96px;cursor:default}
.ptG .box{width:60px;height:60px;margin:0 auto;border-radius:14px;display:flex;align-items:center;justify-content:center;font-size:1.8rem;background:#161f33;border:2px solid #2d3a57;filter:grayscale(.85) brightness(.7);transition:.2s;position:relative}
.ptG b{display:block;font-size:.66rem;letter-spacing:1px;margin-top:6px;color:#fff}.ptG small{display:block;font-size:.6rem;color:var(--dim);line-height:1.3}
.ptG.ready{cursor:pointer}.ptG.ready .box{filter:none;background:radial-gradient(circle,#ffd75e55,#2a1640);border-color:#ffd75e;animation:loyBounce 1s infinite;box-shadow:0 0 22px #ffd75e88}
.ptG.ready .box::after{content:"";position:absolute;inset:-10px;border-radius:20px;border:2px solid #ffd75e;animation:loyRing 1.3s infinite}
.ptG.done .box{filter:none;opacity:.55;border-color:#7dff9f66}.ptG.done .box::before{content:"✔";position:absolute;right:-6px;top:-8px;background:#7dff9f;color:#062012;border-radius:50%;width:20px;height:20px;font-size:.7rem;display:flex;align-items:center;justify-content:center;font-weight:900}
@keyframes loyBounce{0%,100%{transform:translateY(0) rotate(0)}30%{transform:translateY(-8px) rotate(-5deg)}60%{transform:translateY(0) rotate(4deg)}}
@keyframes loyRing{0%{transform:scale(.85);opacity:1}100%{transform:scale(1.35);opacity:0}}
.stRow{display:grid;grid-template-columns:150px 1fr;gap:16px;align-items:center}
.flame{text-align:center}.flame .f{font-size:3rem;filter:drop-shadow(0 0 14px #ff7a1a);animation:loyFlame 1.6s ease-in-out infinite}.flame b{display:block;font-size:1.5rem;font-weight:900;color:#ffb36b}.flame small{color:var(--dim);font-size:.64rem;letter-spacing:2px}
@keyframes loyFlame{50%{transform:scale(1.1) rotate(-3deg)}}
.cards{display:grid;grid-template-columns:repeat(auto-fill,minmax(118px,1fr));gap:8px}
.lc{border:1px solid var(--line);background:#141c2c;border-radius:8px;padding:10px 8px;text-align:center;font-size:.64rem;color:#c5d1e4;position:relative;transition:.2s}
.lc .i{font-size:1.5rem}.lc b{display:block;color:#fff;font-size:.74rem;margin:2px 0 4px}
.lc .pb{height:4px;background:#243049;border-radius:3px;margin-top:6px;overflow:hidden}.lc .pb i{display:block;height:100%;background:#ff7a1a}
.lc.ready{border-color:#ffd75e;box-shadow:0 0 18px #ffd75e44;cursor:pointer;animation:loyGlow 1.4s infinite}
.lc.ready::after{content:"RÉCUPÉRER";display:block;margin-top:6px;background:#ffd75e;color:#2a1a00;border-radius:3px;font-weight:900;font-size:.6rem;padding:3px}
.lc.done{opacity:.5}.lc.done::after{content:"✔ REÇU";display:block;margin-top:6px;color:#7dff9f;font-weight:900;font-size:.6rem}
@keyframes loyGlow{50%{box-shadow:0 0 28px #ffd75e88;transform:translateY(-2px)}}
.tierHead{display:flex;align-items:center;gap:16px;margin-bottom:12px}
.tierBadge{width:66px;height:66px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:1.9rem;background:radial-gradient(circle at 30% 25%,var(--tc),#0b1018 75%);box-shadow:0 0 22px var(--tc);animation:loyFlame 3s ease-in-out infinite}
.tierHead .nm{font-size:1.2rem;font-weight:900;letter-spacing:2px}.tierHead small{color:var(--dim);font-size:.68rem}
.tierHead .tb{height:7px;width:260px;max-width:100%;border-radius:4px;background:#243049;overflow:hidden;margin-top:6px}.tierHead .tb i{display:block;height:100%}
.bonusRow{display:flex;flex-wrap:wrap;gap:8px}
.bchip{padding:7px 12px;border-radius:20px;font-size:.7rem;font-weight:800;letter-spacing:1px;background:#141c2c;border:1px solid var(--line);color:#7b8ca6}
.bchip.on{color:#fff;border-color:#7dff9f88;background:#12261c}
.bchip.gold.on{border-color:#ffd24a;background:linear-gradient(90deg,#3a2a00,#1a1400);color:#ffe27a}
.loyClose{position:absolute;top:14px;right:16px;background:#ffffff12;border:1px solid var(--line);color:#fff;width:34px;height:34px;border-radius:50%;cursor:pointer;font-size:1rem;z-index:2}
.loyClose:hover{background:#ff4655}
.loyNote{position:fixed;left:50%;top:84px;transform:translateX(-50%);z-index:60;display:flex;gap:12px;align-items:center;padding:12px 20px;border-radius:10px;background:linear-gradient(135deg,#2a1640ee,#1a0f2aee);border:1px solid #ffd75e;box-shadow:0 0 30px #ffd75e55;color:#fff;animation:loyIn .5s cubic-bezier(.2,1.6,.4,1);transition:.6s;pointer-events:none}
.loyNote.out{opacity:0;transform:translate(-50%,-30px)}
.loyNote .gi{font-size:2rem;animation:loyBounce 1s infinite}.loyNote b{display:block;letter-spacing:3px;font-size:.85rem;color:#ffd75e}.loyNote small{font-size:.68rem;color:#e5dcff}
@keyframes loyIn{from{opacity:0;transform:translate(-50%,-40px) scale(.7)}}
.loyBonusLn{margin-top:4px;color:#c9a4ff;font-size:.78rem}.loyBonusLn.gift{color:#ffd75e;font-weight:800}
#loyBig{position:fixed;inset:0;z-index:80;display:flex;align-items:center;justify-content:center;background:radial-gradient(circle,#2a164099,#05080dee);animation:ovin .25s}
#loyBig .card{text-align:center;color:#fff;animation:loyIn2 .6s cubic-bezier(.2,1.6,.4,1)}
#loyBig .ic{font-size:6rem;display:inline-block;animation:loyBounce 1.2s infinite;filter:drop-shadow(0 0 30px #ffd75e)}
#loyBig .rays{position:absolute;left:50%;top:50%;width:900px;height:900px;margin:-450px 0 0 -450px;background:repeating-conic-gradient(#ffd75e18 0 8deg,transparent 8deg 22deg);animation:loySpin 14s linear infinite;pointer-events:none;-webkit-mask:radial-gradient(circle,#000 20%,transparent 65%);mask:radial-gradient(circle,#000 20%,transparent 65%)}
#loyBig h2{font-size:2.4rem;letter-spacing:6px;margin:10px 0 6px;background:linear-gradient(90deg,#ffd75e,#fff,#ffb300);-webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent}
#loyBig p{color:#e5dcff;font-size:.95rem;max-width:520px;margin:0 auto 18px}
@keyframes loyIn2{from{transform:scale(.3);opacity:0}}
@keyframes loySpin{to{transform:rotate(360deg)}}
/* Premium */
.vipHero{position:relative;padding:28px 30px 22px;background:radial-gradient(circle at 80% 10%,#ffb30055,transparent 55%),linear-gradient(135deg,#1e1400,#0d1220 65%);overflow:hidden;border-bottom:1px solid #ffd24a55}
.vipHero::after{content:"";position:absolute;top:0;bottom:0;width:40%;left:-60%;background:linear-gradient(100deg,transparent,#fff5,transparent);transform:skewX(-20deg);animation:vipSweep 3.8s ease-in-out infinite}
@keyframes vipSweep{0%,40%{left:-60%}100%{left:130%}}
.vipHero h1{margin:0;font-size:2.4rem;letter-spacing:6px}.vipHero h1 span{background:linear-gradient(90deg,#ffb300,#fff2a8,#ffcf3a);-webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent}
.vipHero p{color:#f0e2b8;margin:6px 0 0;font-size:.82rem}
.vipHero .star{position:absolute;color:#ffd24a;animation:vipStar 3s ease-in-out infinite;pointer-events:none}
@keyframes vipStar{0%,100%{opacity:.2;transform:scale(.6) rotate(0)}50%{opacity:1;transform:scale(1.1) rotate(40deg)}}
.vipGrid{display:grid;grid-template-columns:1.2fr 1fr;gap:16px;padding:16px 28px 24px}
.perk{display:flex;gap:12px;align-items:flex-start;padding:10px 12px;border-radius:8px;background:#141c2c;border:1px solid var(--line);margin-bottom:8px}
.perk .pi{font-size:1.5rem;width:34px;text-align:center}.perk b{display:block;color:#fff;font-size:.8rem}.perk small{color:var(--dim);font-size:.68rem}
.vipPrev{background:#0b111c;border:1px solid var(--line);border-radius:8px;padding:12px 14px;margin-bottom:12px}
.vipPrev .row{display:flex;justify-content:space-between;align-items:center;padding:7px 10px;background:#ffffff08;margin-top:6px;font-size:.8rem;border-radius:4px}
.vipCols{display:flex;flex-wrap:wrap;gap:6px;margin-top:10px}
.vipCols .chip{cursor:pointer}.vipCols .chip.on{background:#2a1d00;border-color:#ffd24a;box-shadow:0 0 12px #ffb30055}
.offer{position:relative;display:flex;justify-content:space-between;align-items:center;padding:14px 16px;border-radius:10px;border:1px solid #ffd24a66;background:linear-gradient(135deg,#2a1d00,#141c2c);margin-bottom:10px}
.offer.best{border-color:#ffd24a;box-shadow:0 0 22px #ffb30044}
.offer .tag{position:absolute;top:-9px;left:14px;background:#ff4655;color:#fff;font-size:.58rem;font-weight:900;letter-spacing:2px;padding:2px 8px;border-radius:3px}
.offer b{font-size:1rem;color:#fff}.offer small{display:block;color:#d9c48f;font-size:.66rem}
.offer button{border:0;border-radius:6px;padding:10px 16px;font-weight:900;letter-spacing:1px;cursor:pointer;color:#2a1a00;background:linear-gradient(90deg,#ffb300,#ffe680);font-size:.78rem}
.offer button.lock{background:#2a354a;color:#9fb0cc}
.vipActive{padding:12px 16px;border-radius:10px;background:linear-gradient(90deg,#3a2a00,#1a1400);border:1px solid #ffd24a;color:#ffe27a;font-weight:800;margin-bottom:12px}
@media(max-width:860px){.vipGrid{grid-template-columns:1fr}.stRow{grid-template-columns:1fr}.ptTrack{height:150px}.ptG{width:64px}.ptG .box{width:46px;height:46px;font-size:1.3rem}}
`;document.head.appendChild(s);
}
function loyOverlays(){
 if($('loyOv'))return;
 const a=document.createElement('div');a.id='loyOv';a.className='ov';a.innerHTML='<div class="panel"><button class="loyClose" data-x="loyOv">✕</button><div id="loyBox"></div></div>';
 const b=document.createElement('div');b.id='vipOv';b.className='ov';b.innerHTML='<div class="panel"><button class="loyClose" data-x="vipOv">✕</button><div id="vipBox"></div></div>';
 document.body.appendChild(a);document.body.appendChild(b);
 for(const o of [a,b]){o.addEventListener('click',e=>{if(e.target===o||e.target.dataset.x){sfxUI();o.classList.remove('show');refreshProfile();}});}
}
function loyButtons(){
 const pr=$('profile');if(!pr||$('loyBtn'))return;
 const g=document.createElement('button');g.id='loyBtn';g.innerHTML='🎁 CADEAUX<span class="bdg" style="display:none"></span>';g.onclick=()=>{initAudio();sfxUI();loyOpen();};
 const v=document.createElement('button');v.id='vipBtn';v.onclick=()=>{initAudio();sfxUI();vipOpen();};
 const bar=document.createElement('div');bar.id='loyBar';bar.appendChild(g);bar.appendChild(v);$('menu').appendChild(bar);
}
function loyRefreshButtons(){
 loyButtons();const n=loyPending(),g=$('loyBtn'),v=$('vipBtn');
 if(g){const b=g.querySelector('.bdg');b.style.display=n?'flex':'none';b.textContent=n;g.classList.toggle('has',n>0);}
 if(v)v.textContent=vipOn()?'⭐ PREMIUM · '+vipDaysLeft()+' J':'⭐ PREMIUM';
 const pn=$('pName');if(pn)pn.className='pn'+(vipOn()?' vipn vipn-'+loyData().vip.col:'');
}
const _loyRefresh=refreshProfile;
refreshProfile=function(){_loyRefresh();loyRefreshButtons();};

function loyDraw(){
 const el=$('loyBox');if(!el)return;const L=loyData(),min=loyMin(),last=PLAYTIME_GIFTS[PLAYTIME_GIFTS.length-1].m;
 const nextG=PLAYTIME_GIFTS.find(g=>min<g.m);
 let h='<div class="loyHead"><h1>CENTRE DES <span>CADEAUX</span></h1><p>Plus tu joues, plus tu gagnes. Les cadeaux de temps de jeu reviennent chaque jour.</p></div><div class="loyBody">';
 // temps de jeu
 h+='<div class="loySec"><h3>⏱ CADEAUX DE TEMPS DE JEU<small>'+min+' min jouées aujourd\'hui'+(nextG?' · prochain cadeau dans '+(nextG.m-min)+' min':' · tous débloqués !')+'</small></h3><div class="ptTrack"><div class="ptBar"><i style="width:'+Math.min(100,min/last*100)+'%"></i></div>';
 PLAYTIME_GIFTS.forEach((g,i)=>{const st=L.got.includes(i)?'done':min>=g.m?'ready':'';
  h+='<div class="ptG '+st+'" data-k="pt" data-i="'+i+'" style="left:'+(g.m/last*100*.92+4)+'%"><div class="box">'+g.ic+'</div><b>'+g.m+' MIN</b><small>'+loyGiftText(g.r)+'</small></div>';});
 h+='</div></div>';
 // série
 const sk=PROF.streak||0,ds=dailyStatus();
 h+='<div class="loySec"><h3>🔥 SÉRIE DE CONNEXION<small>'+(ds.can?'<a id="loyDaily" style="color:#ffd75e;cursor:pointer;text-decoration:underline">Récompense du jour disponible !</a>':'Reviens demain pour continuer')+'</small></h3><div class="stRow"><div class="flame"><div class="f">🔥</div><b>'+sk+'</b><small>JOUR'+(sk>1?'S':'')+' D\'AFFILÉE</small></div><div class="cards">';
 STREAK_GOALS.forEach((g,i)=>{const done=L.streakGot.includes(g.d),ready=stReady(i);
  h+='<div class="lc '+(done?'done':ready?'ready':'')+'" data-k="st" data-i="'+i+'"><div class="i">'+g.ic+'</div><b>'+g.d+' JOURS</b>'+loyGiftText(g.r)+(done||ready?'':'<div class="pb"><i style="width:'+Math.min(100,sk/g.d*100)+'%"></i></div>')+'</div>';});
 h+='</div></div>'+(vipOn()?'<div style="margin-top:8px;font-size:.68rem;color:#ffe27a">⭐ Premium : un jour manqué par semaine ne casse pas ta série.</div>':'')+'</div>';
 // fidélité
 const ti=loyTierIdx(),t=LOY_TIERS[ti],nt=LOY_TIERS[ti+1];
 h+='<div class="loySec"><h3>💠 RANG DE FIDÉLITÉ<small>Chaque jour où tu joues au moins une partie compte</small></h3><div class="tierHead"><div class="tierBadge" style="--tc:'+t.c+'">💠</div><div><div class="nm" style="color:'+t.c+'">'+t.n.toUpperCase()+'</div><small>'+L.days+' jour'+(L.days>1?'s':'')+' de jeu · bonus permanent +'+t.xp+' % XP</small>'+(nt?'<div class="tb"><i style="width:'+Math.round((L.days-t.d)/(nt.d-t.d)*100)+'%;background:'+nt.c+'"></i></div><small>Prochain rang : '+nt.n+' dans '+(nt.d-L.days)+' jour'+(nt.d-L.days>1?'s':'')+' de jeu</small>':'<small style="display:block;color:#ffd75e">Rang maximum atteint !</small>')+'</div></div><div class="cards">';
 LOY_TIERS.forEach((x,i)=>{if(!i)return;const done=L.tiers.includes(i),ready=tierReady(i);
  h+='<div class="lc '+(done?'done':ready?'ready':'')+'" data-k="tier" data-i="'+i+'" style="border-top:3px solid '+x.c+'"><b style="color:'+x.c+'">'+x.n+'</b>'+x.d+' jours · +'+x.xp+' % XP<br>'+loyGiftText(x.r)+(done||ready?'':'<div class="pb"><i style="width:'+Math.min(100,L.days/x.d*100)+'%;background:'+x.c+'"></i></div>')+'</div>';});
 h+='</div></div>';
 // bonus actifs
 const fw=L.win!==todayStr();
 h+='<div class="loySec"><h3>✨ BONUS ACTIFS</h3><div class="bonusRow">'+
  '<span class="bchip'+(t.xp?' on':'')+'">💠 Fidélité +'+t.xp+' % XP</span>'+
  '<span class="bchip'+(L.boost?' on':'')+'">⚡ Boost XP ×1,5 : '+(L.boost?L.boost+' partie'+(L.boost>1?'s':''):'aucun')+'</span>'+
  '<span class="bchip'+(fw?' on':'')+'">🏆 Première victoire du jour : '+(fw?'+'+FIRST_WIN.xp+' XP dispo':'déjà prise')+'</span>'+
  '<span class="bchip gold'+(vipOn()?' on':'')+'" id="loyVipChip" style="cursor:pointer">⭐ Premium : '+(vipOn()?'+20 % XP et pièces · '+vipDaysLeft()+' j':'inactif, voir l\'offre')+'</span>'+
  (vipOn()?'<span class="bchip gold'+(vipDailyReady()?' on':'')+'" data-k="vip" data-i="0" style="cursor:pointer">🎁 Cadeau Premium du jour : '+(vipDailyReady()?'+'+VIP.daily.coins+' pièces, clique !':'reçu')+'</span>':'')+
  '</div></div></div>';
 el.innerHTML=h;
 el.querySelectorAll('[data-k]').forEach(n=>n.onclick=()=>loyClaimUI(n.dataset.k,+n.dataset.i,n));
 const d=$('loyDaily');if(d)d.onclick=()=>{$('loyOv').classList.remove('show');showDaily();};
 $('loyVipChip').onclick=()=>{$('loyOv').classList.remove('show');vipOpen();};
}
function loyClaimUI(k,i,node){
 const r=loyClaim(k,i);if(!r)return;
 sfx('win');const b=node.getBoundingClientRect();confetti(null,120,(b.left+b.width/2)/innerWidth,(b.top+b.height/2)/innerHeight);
 uiToast('🎁 '+loyGiftText(r));refreshProfile();try{buildBoxesTab();}catch(e){}
 if(r.box)loyBigGift('📦','CAISSE OBTENUE !',loyGiftText(r));
 loyDraw();
}
function loyBigGift(ic,title,txt){
 const o=document.createElement('div');o.id='loyBig';o.innerHTML='<div class="rays"></div><div class="card"><div class="ic">'+ic+'</div><h2>'+title+'</h2><p>'+txt+'</p><button class="btn cut">GÉNIAL !</button></div>';
 document.body.appendChild(o);sfx('win');confetti(['#ffd75e','#ffffff','#c77dff','#ff4655'],220,.5,.4);
 o.querySelector('button').onclick=()=>{sfxUI();o.remove();refreshProfile();};
}
function loyOpen(){loyCss();loyOverlays();loyDraw();$('loyOv').classList.add('show');}

function vipNameHTML(name,col){return '<span class="vipn vipn-'+(col||loyData().vip.col)+'">'+name+'</span>';}
function vipDraw(){
 const el=$('vipBox');if(!el)return;const L=loyData(),on=vipOn(),nm=String(cfg.name||'Vous').replace(/</g,'&lt;');
 let h='<div class="vipHero">';
 for(let i=0;i<9;i++)h+='<span class="star" style="left:'+(8+i*11)+'%;top:'+(12+(i*37)%70)+'%;font-size:'+(.7+(i%3)*.4)+'rem;animation-delay:'+(i*.37).toFixed(2)+'s">✦</span>';
 h+='<h1>STRIKE <span>PREMIUM</span> ⭐</h1><p>Le statut des joueurs qui soutiennent le jeu : un pseudo qui brille, plus d\'XP, plus de pièces et des cadeaux chaque jour.</p></div><div class="vipGrid"><div>';
 const perks=[['🌈','Couleur de pseudo exclusive','Ton pseudo brille avec une étoile ⭐ dans le tableau des scores, le fil des éliminations et le chat.'],
  ['⚡','+20 % d\'XP et +20 % de pièces','À chaque fin de partie, en plus des autres bonus.'],
  ['🎁','Cadeau Premium chaque jour','+'+VIP.daily.coins+' pièces à récupérer dans le Centre des cadeaux.'],
  ['🛡','Série protégée','Un jour manqué par semaine ne remet pas ta série de connexion à zéro.'],
  ['🏷','Titre « ⭐ Premium »','À afficher dans Profil › Style.'],
  ['📦','1 Caisse Premium offerte','À chaque achat d\'abonnement (version Roblox).']];
 h+=perks.map(p=>'<div class="perk"><div class="pi">'+p[0]+'</div><div><b>'+p[1]+'</b><small>'+p[2]+'</small></div></div>').join('');
 h+='</div><div>';
 if(on)h+='<div class="vipActive">⭐ PREMIUM ACTIF · encore '+vipDaysLeft()+' jour'+(vipDaysLeft()>1?'s':'')+'</div>';
 h+='<div class="vipPrev"><div style="font-size:.66rem;letter-spacing:2px;color:var(--dim)">APERÇU DE TON PSEUDO</div>'+
  '<div class="row"><span>'+vipNameHTML(nm)+'</span><span style="color:var(--dim)">24 / 9</span></div>'+
  '<div class="row" style="justify-content:flex-end;gap:8px"><span>'+vipNameHTML(nm)+'</span><span style="color:#ff5050">★</span><span style="color:#8da0bd">AK-47</span><span style="color:#4aa3ff">Bot Alpha</span></div>'+
  '<div class="vipCols">'+VIP.colors.map(c=>'<span class="chip'+(L.vip.col===c.id?' on':'')+'" data-col="'+c.id+'">'+vipNameHTML(c.n,c.id)+'</span>').join('')+'</div>'+
  (on?'':'<div style="font-size:.64rem;color:var(--dim);margin-top:8px">Essaie les couleurs : elles s\'appliquent quand le Premium est actif.</div>')+'</div>';
 h+=VIP.offers.map(o=>'<div class="offer'+(o.best?' best':'')+'">'+(o.best?'<span class="tag">MEILLEURE OFFRE</span>':'')+'<div><b>'+o.n+'</b><small>'+(o.days===90?'≈ 300 R$ par mois · ':'')+'1 Caisse Premium offerte</small></div><button class="lock" data-buy="'+o.id+'">🔒 '+o.rbx+' R$</button></div>').join('');
 h+='<div style="font-size:.66rem;color:var(--dim);line-height:1.5">Le paiement en Robux existe seulement sur la version Roblox du jeu. Sur le web, l\'offre est affichée pour la découvrir.</div></div></div>';
 el.innerHTML=h;
 el.querySelectorAll('[data-col]').forEach(c=>c.onclick=()=>{sfxUI();L.vip.col=c.dataset.col;saveProf();vipDraw();refreshProfile();});
 el.querySelectorAll('[data-buy]').forEach(b=>b.onclick=()=>{sfxUI();uiToast('Achat en Robux : disponible sur la version Roblox du jeu');});
}
function vipOpen(){loyCss();loyOverlays();vipDraw();$('vipOv').classList.add('show');}
// test et admin : active ou coupe le Premium sur ce navigateur
function vipGrant(days){const L=loyData();L.vip.until=Math.max(Date.now(),L.vip.until)+days*864e5;loyVipTitle();saveProf();refreshProfile();}
function vipRevoke(){loyData().vip.until=0;loyVipTitle();saveProf();refreshProfile();}

/* ---------- pseudo en couleur : tableau des scores, fil des éliminations, chat ---------- */
{const _f=uiFeed;uiFeed=function(a,v,w,hs){
 const r=_f(a,v,w,hs);
 if(vipOn()&&((a&&a.isPlayer)||(v&&v.isPlayer))){const d=$('feed').lastChild;if(d)d.querySelectorAll('span').forEach(s=>{if(s.textContent===P.name)s.innerHTML=vipNameHTML(s.innerHTML);});}
 return r;};}
{const _s=scoreTable;scoreTable=function(final){
 const h=_s(final);if(!vipOn()||typeof P==='undefined'||!P)return h;
 const k='<td>'+P.name;const i=h.indexOf(k);return i<0?h:h.slice(0,i)+'<td>'+vipNameHTML(P.name)+h.slice(i+k.length);};}
if(typeof chatAdd==='function'){const _c=chatAdd;chatAdd=function(name,msg,col){const r=_c(name,msg,col);
 if(vipOn()&&name===(cfg.name||'Joueur')){const ls=document.querySelector('#chatLines');const b=ls&&ls.lastChild&&ls.lastChild.querySelector('b');if(b)b.className='vipn vipn-'+loyData().vip.col;}return r;};}

/* ---------- panneau admin : Premium de test ---------- */
if(typeof admGiveHTML==='function'){
 const _g=admGiveHTML;admGiveHTML=function(){return _g()+'<div class="sec"><h4>PREMIUM (TEST)</h4><div class="chips"><span class="chip" data-vipadm="30">Activer 30 jours</span><span class="chip" data-vipadm="0">Couper</span></div><div class="note">'+(vipOn()?'Actif, encore '+vipDaysLeft()+' jours.':'Inactif.')+'</div></div>';};
 document.addEventListener('click',e=>{const c=e.target.closest&&e.target.closest('[data-vipadm]');if(!c)return;const d=+c.dataset.vipadm;
  if(d)vipGrant(d);else vipRevoke();try{admLog(d?'Premium activé '+d+' jours':'Premium coupé','#ffd24a');admDraw();}catch(err){}});
}

/* ---------- démarrage ---------- */
loyCss();loyOverlays();loyButtons();
{const _b=buildMetaUI;buildMetaUI=function(){_b();loyRefreshButtons();loyWelcomeBack();};}
loyRefreshButtons();
