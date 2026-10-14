/* =====================================================================
   META-JEU : profil, niveaux/XP, récompenses quotidiennes, missions,
   caisses (loot boxes avec probabilités affichées + pitié), statistiques
   (structure pensée pour être portée sur Roblox DataStore)
   ===================================================================== */
const PKEY="sa2_profile";
const rcol=q=>RARITY[q].c;
function newProfile(){
 return {v:2,xp:0,coins:250,lastLogin:'',streak:0,inv:{skins:{},dances:['wave','clap'],outfits:[]},dance:'wave',outfit:0,boxes:{std:1,prem:0},pity:{epic:0,legend:0},opened:0,
  stats:{matches:0,wins:0,kills:0,deaths:0,hs:0,dmg:0,shots:0,hits:0,secs:0,bestStreak:0,plants:0,defuses:0,byMode:{},byMap:{},byWeapon:{}},
  history:[],missions:{date:'',list:[]}};
}
function loadProfile(){
 try{const p=JSON.parse(localStorage.getItem(PKEY)||'null');
  if(p&&p.v){const d=newProfile();return Object.assign(d,p,{stats:Object.assign(d.stats,p.stats||{}),inv:Object.assign(d.inv,p.inv||{}),boxes:Object.assign(d.boxes,p.boxes||{}),pity:Object.assign(d.pity,p.pity||{})});}}catch(e){}
 return newProfile();
}
let PROF=loadProfile();
const saveProf=()=>{try{localStorage.setItem(PKEY,JSON.stringify(PROF));}catch(e){}};
/* ---------- niveaux ---------- */
/* économie réaliste : ~4 parties pour le niveau 3, ~28 pour le niveau 10, ~260 pour le niveau 30 */
const xpNeed=l=>300+l*80+l*l*2;
let _liC=null;
function levelInfo(){if(_liC&&_liC.xp===PROF.xp)return Object.assign({},_liC.r);let l=1,x=PROF.xp;while(x>=xpNeed(l)){x-=xpNeed(l);l++;}const r={level:l,cur:x,need:xpNeed(l)};_liC={xp:PROF.xp,r};return Object.assign({},r);}
function levelReward(l){if(l%25===0)return {box:'prem',coins:250};if(l%10===0)return {box:'std',coins:150};if(l%5===0)return {coins:120};return {coins:30+l*3};}
function applyReward(r){
 if(r.coins)PROF.coins+=r.coins;
 if(r.box)PROF.boxes[r.box]=(PROF.boxes[r.box]||0)+(r.n||1);
 if(r.dance&&!PROF.inv.dances.includes(r.dance))PROF.inv.dances.push(r.dance);
}
function addXP(n){
 const before=levelInfo().level;PROF.xp+=n;const after=levelInfo().level,ups=[];
 for(let l=before+1;l<=after;l++){const r=levelReward(l);applyReward(r);ups.push({level:l,reward:r});}
 saveProf();return ups;
}
function rewardText(r){const a=[];if(r.coins)a.push('+'+r.coins+' pièces');if(r.box)a.push('1 '+BOXES[r.box].n);if(r.dance)a.push('Danse '+DANCES.find(d=>d.id===r.dance).n);return a.join(' • ');}
/* ---------- récompense quotidienne ---------- */
const DAILY=[{coins:40},{coins:60},{coins:80},{dance:'disco',coins:40},{coins:120},{coins:150},{box:'std',coins:200}];
const todayStr=()=>{const d=new Date();return d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0');};
function dailyStatus(){
 const t=todayStr();
 if(PROF.lastLogin===t)return {can:false,day:((PROF.streak-1)%7+7)%7,streak:PROF.streak};
 const y=new Date(Date.now()-864e5),ys=y.getFullYear()+'-'+String(y.getMonth()+1).padStart(2,'0')+'-'+String(y.getDate()).padStart(2,'0');
 const next=PROF.lastLogin===ys?PROF.streak+1:1;
 return {can:true,day:(next-1)%7,next,streak:next};
}
function claimDaily(){const st=dailyStatus();if(!st.can)return null;PROF.streak=st.next;PROF.lastLogin=todayStr();const r=DAILY[st.day];applyReward(r);saveProf();return r;}
/* ---------- missions du jour ---------- */
const MPOOL=[
 {id:'kills',n:'Élimine {t} adversaires',t:15,coins:50,xp:60},{id:'hs',n:'Fais {t} headshots',t:5,coins:40,xp:50},
 {id:'win',n:'Gagne {t} partie',t:1,coins:65,xp:80},{id:'matches',n:'Joue {t} parties',t:3,coins:60,xp:60},
 {id:'plant',n:'Pose ou désamorce la bombe {t} fois',t:2,coins:50,xp:60},{id:'nade',n:'Élimine {t} adversaires avec une grenade',t:2,coins:65,xp:70},
 {id:'knife',n:'Élimine {t} adversaire au couteau',t:1,coins:85,xp:90},{id:'dmg',n:'Inflige {t} dégâts',t:1500,coins:50,xp:60}
];
const missionDef=id=>MPOOL.find(m=>m.id===id);
function ensureMissions(){
 const t=todayStr();
 if(PROF.missions.date!==t){PROF.missions.date=t;PROF.missions.list=shuffle(MPOOL.slice()).slice(0,3).map(m=>({id:m.id,p:0,done:false,claimed:false}));saveProf();}
}
function metaEvent(id,n){
 ensureMissions();let ch=false;
 for(const m of PROF.missions.list){if(m.id===id&&!m.done){m.p+=n||1;const d=missionDef(id);if(m.p>=d.t){m.p=d.t;m.done=true;if(typeof uiMissionDone==='function')uiMissionDone(d);}ch=true;}}
 if(ch)saveProf();
}
function claimMission(i){const m=PROF.missions.list[i];if(!m||!m.done||m.claimed)return null;m.claimed=true;const d=missionDef(m.id);applyReward({coins:d.coins});const ups=addXP(d.xp);saveProf();return {d,ups};}
/* ---------- caisses ---------- */
const BOXES={std:{n:'Caisse Standard',price:1200,w:[70,24,5,1],c:'#4aa3ff'},prem:{n:'Caisse Premium',price:3500,w:[30,45,20,5],c:'#ffb938'}};
const DUPV=[0,40,120,350];
let LOOT=null;
function lootPool(){
 if(LOOT)return LOOT;const items=[];
 for(const k in W)if(!W[k].wonder)for(let i=1;i<SKINS.length;i++){const q=SKINS[i].q;if(q>0&&q<4)items.push({t:'skin',w:k,s:i,q});}
 for(const d of DANCES){if(d.q>0)items.push({t:'dance',id:d.id,q:d.q});}
 for(let i=1;i<OUTFITS.length;i++){if(OUTFITS[i].q>0)items.push({t:'outfit',o:i,q:OUTFITS[i].q});}
 return LOOT=items;
}
function ownsSkin(k,i){const s=SKINS[i];if(!s)return false;if(i===0||(PROF.inv.skins[k]||[]).includes(i))return true;
 if(s.kreq)return (PROF.wk&&PROF.wk[k]||0)>=s.kreq; // camos de base : défis d'éliminations par arme
 return s.q===0;}
// texte affiché quand un skin est verrouillé
function skinLockTxt(k,i){const s=SKINS[i];if(s.q===4)return 'Camo animé exclusif : réservé aux joueurs qui l\'achètent ('+s.rbx+' R$ sur la version Roblox)';
 if(s.kreq)return 'Camo verrouillé : '+s.kreq+' éliminations avec cette arme ('+(PROF.wk&&PROF.wk[k]||0)+'/'+s.kreq+')';return 'Skin verrouillé : trouve-le dans les caisses !';}
function ownsOutfit(i){return i===0||OUTFITS[i].q===0||(PROF.inv.outfits||[]).includes(i);}
function ownsItem(it){return it.t==='skin'?ownsSkin(it.w,it.s):it.t==='outfit'?ownsOutfit(it.o):PROF.inv.dances.includes(it.id);}
function itemName(it){return it.t==='skin'?W[it.w].n+' — '+SKINS[it.s].n:it.t==='outfit'?'Tenue « '+OUTFITS[it.o].n+' »':'Danse « '+DANCES.find(d=>d.id===it.id).n+' »';}
function rollBox(type){
 const b=BOXES[type];let q;
 if(PROF.pity.legend>=59)q=3;
 else if(PROF.pity.epic>=9){const a=b.w[2],c=b.w[3];q=Math.random()*(a+c)<c?3:2;}
 else{const tot=b.w.reduce((s,x)=>s+x,0);let r=Math.random()*tot;q=0;for(let i=0;i<4;i++){r-=b.w[i];if(r<=0){q=i;break;}}}
 PROF.pity.epic=q>=2?0:PROF.pity.epic+1;PROF.pity.legend=q===3?0:PROF.pity.legend+1;
 let item,dup=false,coins=0;
 if(q===0){item={t:'coins',n:Math.round(rand(40,90)),q:0};coins=item.n;PROF.coins+=coins;}
 else{
  const pool=lootPool().filter(i=>i.q===q);item=pick(pool);
  if(ownsItem(item)){dup=true;coins=DUPV[q];PROF.coins+=coins;}
  else if(item.t==='skin'){(PROF.inv.skins[item.w]||(PROF.inv.skins[item.w]=[])).push(item.s);}
  else if(item.t==='outfit'){(PROF.inv.outfits||(PROF.inv.outfits=[])).push(item.o);}
  else PROF.inv.dances.push(item.id);
 }
 PROF.opened++;saveProf();
 return {q,item,dup,coins};
}
function openBox(type){
 const b=BOXES[type];
 if((PROF.boxes[type]||0)>0)PROF.boxes[type]--;
 else if(PROF.coins>=b.price)PROF.coins-=b.price;
 else return null;
 saveProf();return rollBox(type);
}
/* ---------- statistiques ---------- */
const MS={shots:0,hits:0,wkills:{},plants:0,defuses:0,nadeKills:0,knifeKills:0,start:0};
function resetMatchStats(){MS.shots=0;MS.hits=0;MS.wkills={};MS.plants=0;MS.defuses=0;MS.nadeKills=0;MS.knifeKills=0;MS.start=performance.now();}
function commitMatch(win){
 const s=PROF.stats,secs=Math.round((performance.now()-MS.start)/1000);
 const xp=Math.round(40+P.kills*10+P.hsKills*5+(win?120:0)+MS.plants*25+MS.defuses*25);
 const coinsGain=Math.round(xp*.15);
 s.matches++;if(win)s.wins++;s.kills+=P.kills;s.deaths+=P.deaths;s.hs+=P.hsKills;s.dmg+=P.dmg;s.shots+=MS.shots;s.hits+=MS.hits;s.secs+=secs;
 s.bestStreak=Math.max(s.bestStreak,P.bestStreak||0);s.plants+=MS.plants;s.defuses+=MS.defuses;
 const m=(s.byMode[G.mode]||(s.byMode[G.mode]={m:0,w:0,k:0,d:0}));m.m++;if(win)m.w++;m.k+=P.kills;m.d+=P.deaths;
 const mp=(s.byMap[cfg.map]||(s.byMap[cfg.map]={m:0,w:0}));mp.m++;if(win)mp.w++;
 for(const k in MS.wkills)s.byWeapon[k]=(s.byWeapon[k]||0)+MS.wkills[k];
 PROF.history.unshift({t:Date.now(),mode:G.mode,map:cfg.map,diff:cfg.diff,win:!!win,k:P.kills,d:P.deaths,hs:P.hsKills,dmg:P.dmg,xp});
 PROF.history.length=Math.min(PROF.history.length,25);
 PROF.coins+=coinsGain;
 metaEvent('matches');if(win)metaEvent('win');metaEvent('dmg',P.dmg);
 const ups=addXP(xp);saveProf();
 const pr=progressMatch(win,xp);
 return {xp,coins:coinsGain,ups,secs,pr};
}
function resetStats(){PROF.stats=newProfile().stats;PROF.history=[];saveProf();}
