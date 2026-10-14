/* =====================================================================
   PANNEAU ADMIN (touche Insert, F2 en secours, ou bouton ADMIN du menu pause)
   - Joueurs : liste en direct (humains + bots), ping, expulser / bannir /
     rendre muet, tuer, soigner, faire réapparaître, changer d'équipe,
     ajouter / retirer des bots, observer.
   - Partie : état, score, chrono ; finir la manche, terminer la partie,
     +1 minute, figer les bots, annonce à tous.
   - Vision : silhouettes et étiquettes à travers les murs. Autorisée en
     solo, contre les bots et en spectateur ; en ligne contre d'autres
     joueurs elle ne marche que quand on est mort (pour ne pas tricher).
   - Journal : arrivées, départs, éliminations, discussion, actions admin.
   - Visée auto : la visée se cale sur la tête de l'ennemi visible le plus
     proche du réticule (clic droit ou en permanence). Mêmes règles que
     la vision, sauf qu'elle ne sert à rien en spectateur.
   Accès : rien ne s'affiche tant qu'on n'a pas ouvert le jeu avec #admin à
   la fin de l'adresse et tapé le code (16 caractères). Seule son empreinte
   SHA-256 est ici ; le code reste ensuite mémorisé sur ce navigateur. Le
   jeu étant un site public, quelqu'un qui modifie sa copie du jeu peut
   toujours tricher chez lui, mais il ne peut pas toucher aux salons des
   autres. Les actions sur les joueurs ne
   marchent que pour l'hôte du salon (c'est lui qui fait tourner la partie).
   ===================================================================== */
const ADM={on:false,ok:false,tab:'players',log:[],vision:false,allies:false,tags:true,freeze:false,muted:new Set(),banned:new Set(),pingT:0,drawT:0,el:null,tagEl:null,tagMap:new Map()};
const ADM_HASH='c3305d1fef32b4a6a887b3695f33d4a89cf38cfb4a0f69290aa83f3299b47849';
async function admHash(code){
 const b=await crypto.subtle.digest('SHA-256',new TextEncoder().encode('strike-arena-admin:'+code));
 return [...new Uint8Array(b)].map(x=>x.toString(16).padStart(2,'0')).join('');
}
const admNorm=c=>String(c||'').toUpperCase().replace(/[^A-Z0-9]/g,'').replace(/(.{4})(?=.)/g,'$1-');
async function admCheck(code){try{return (await admHash(admNorm(code)))===ADM_HASH;}catch(e){return false;}}
// le code mémorisé est revérifié à chaque chargement (recopier l'empreinte ne suffit pas)
try{const c=localStorage.getItem('sa_admin');if(c)admCheck(c).then(ok=>{ADM.ok=ok;if(ok)admPauseBtn();else localStorage.removeItem('sa_admin');});}catch(e){}
const admAsked=()=>/(^|[#?&])admin\b/i.test(location.hash+location.search);
const admEsc=s=>String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/"/g,'&quot;');
function admLog(txt,col){
 const d=new Date(),t=('0'+d.getHours()).slice(-2)+':'+('0'+d.getMinutes()).slice(-2)+':'+('0'+d.getSeconds()).slice(-2);
 ADM.log.push({t,txt,col:col||''});if(ADM.log.length>150)ADM.log.shift();
 if(ADM.on&&ADM.tab==='log')admDraw();
}
/* ---------- droits ---------- */
// actions sur la partie : en solo, ou hôte du salon
const admCanAct=()=>NET.role!=='client';
// '' = vision autorisée, sinon la raison
function admVisionWhy(){
 if(!G.running||!P)return 'Lance une partie pour l\'utiliser';
 if(!NET.role||!P.alive)return '';
 if(NET.role==='client')return 'En ligne, la vision ne marche qu\'en spectateur (quand tu es éliminé)';
 const team=MODE().team;
 for(const p of NET.players.values())if(p.ent&&(!team||p.ent.team!==P.team))return 'Des joueurs humains sont en face : la vision ne marche qu\'en spectateur (quand tu es éliminé)';
 return '';
}
/* ---------- réseau : ping, expulsion, bannissement, muet ---------- */
const _admHostMsg=netHostMsg;
netHostMsg=function(m,from){
 if(m.t==='pong'){const p=NET.players.get(from);if(p&&m.ts)p.ping=Math.round(performance.now()-m.ts);return;}
 if(m.t==='hello'){
  const nm=String(m.name||'Joueur').slice(0,14);
  if(ADM.banned.has(nm.toLowerCase())){netSend({t:'kick',r:'Tu es banni de ce salon'},from);admLog(nm+' (banni) a essayé de revenir','#ff6b6b');return;}
  if(!NET.players.has(from))admLog(nm+' a rejoint le salon','#7dff9f');
 }
 if(m.t==='bye'){const p=NET.players.get(from);if(p)admLog(p.name+' a quitté le salon','#ffb36b');}
 if(m.t==='chat'&&ADM.muted.has(from))return;
 {const p=NET.players.get(from);if(p&&p.ent&&p.ent.admFrozen&&/^(shot|nade|mine|buy|reload|slot)$/.test(m.t))return;}
 _admHostMsg(m,from);
};
const _admClientMsg=netClientMsg;
netClientMsg=function(m){
 if(m.t==='ping'){netSend({t:'pong',ts:m.ts},'host');return;}
 if(m.t==='frz'){G.admFrozenMe=!!m.on;uiToast(m.on?'L\'hôte t\'a gelé':'L\'hôte t\'a dégelé');return;}
 if(m.t==='kick'){const r=m.r||'L\'hôte t\'a expulsé du salon';if(G.running)toMenu();netLeave();netStatus(r);uiToast(r);admLog(r,'#ff6b6b');return;}
 _admClientMsg(m);
};
// client : l'hôte peut changer mon équipe en cours de partie
const _admSnap=netApplySnap;
netApplySnap=function(m){
 _admSnap(m);
 const me=(m.e||[]).find(o=>o.i===NET.myEnt);
 if(me&&MODE().team&&me.tm!==P.team){P.team=me.tm;if(P.rig)scene.remove(P.rig.root);attachRig(P);P.rig.root.visible=!P.alive;uiToast('L\'hôte t\'a changé d\'équipe');}
};
function admKick(id,ban){
 const p=NET.players.get(id);if(!p||NET.role!=='host')return;
 netSend({t:'kick',r:ban?'L\'hôte t\'a banni du salon':'L\'hôte t\'a expulsé du salon'},id);
 if(ban)ADM.banned.add(p.name.toLowerCase());
 ADM.muted.delete(id);
 admLog(p.name+(ban?' banni':' expulsé'),'#ff6b6b');
 _admHostMsg({t:'bye'},id); // même nettoyage qu'un départ : sa place repasse à un bot
}
function admMute(id){
 const p=NET.players.get(id);if(!p)return;
 if(ADM.muted.has(id)){ADM.muted.delete(id);admLog(p.name+' peut de nouveau écrire');}
 else{ADM.muted.add(id);admLog(p.name+' rendu muet','#ffb36b');}
}
/* ---------- actions sur les personnages ---------- */
const admEnt=id=>ents.find(e=>e.id===id);
function admKill(e){if(!e||!e.alive||!admCanAct())return;killEnt(e,e,W.knife,false);admLog(e.name+' éliminé par l\'admin','#ffb36b');}
function admHeal(e){if(!e||!e.alive||!admCanAct())return;e.hp=100;e.armor=100;admLog(e.name+' soigné');}
function admRevive(e){if(!e||e.alive||!admCanAct())return;respawn(e);admLog(e.name+' réapparu');}
function admTeam(e){
 if(!e||!MODE().team||!admCanAct())return;
 e.team=1-e.team;
 if(e.rig){scene.remove(e.rig.root);e.rig=null;}attachRig(e);
 if(e.isPlayer)e.rig.root.visible=!e.alive;
 if(e.alive){if(G.mode==='bomb')killEnt(e,e,W.knife,false);else respawn(e);}
 applyOutlinesAll();
 admLog(e.name+' passe chez les '+(e.team===0?'Attaquants':'Défenseurs'));
}
function admRemoveBot(e){
 if(!e||e.isPlayer||e.remote||!admCanAct())return;
 if(BM.state==='carried'&&BM.carrier===e.id){BM.state='dropped';BM.x=e.x;BM.y=e.y;BM.z=e.z;BM.carrier=-1;}
 if(e.rig)scene.remove(e.rig.root);ents.splice(ents.indexOf(e),1);
 admLog('Bot '+e.name+' retiré');
 if(G.mode==='bomb'&&G.state==='live')checkEnd();
}
function admAddBot(team){
 if(!G.running||!admCanAct())return;
 const used=new Set(ents.map(e=>e.name)),nm=NAMES.find(n=>!used.has(n))||('Bot'+ents.length);
 const id=ents.reduce((m,x)=>Math.max(m,x.id),0)+1;
 if(!MODE().team)team=id;
 const e=newEnt(nm,team,false,id);e.id=id;e.money=P.money;e.ggLevel=0;giveWeapon(e,e.team===0?'glock':'usp');ents.push(e);attachRig(e);
 if(G.mode==='bomb'){e.alive=false;e.keep=false;}else respawn(e);
 admLog('Bot '+nm+' ajouté'+(MODE().team?' ('+(team===0?'Attaquants':'Défenseurs')+')':''));
}
function admSpec(e){if(!e||P.alive||!e.alive)return;G.spec=e;}
const _admBot=botUpdate;
botUpdate=function(b,dt){if(ADM.freeze||b.admFrozen){b.speed=0;tickWeapon(b,dt);return;}_admBot(b,dt);};
/* ---------- actions sur la partie ---------- */
function admEndRound(win){if(!admCanAct()||G.mode!=='bomb'||G.state!=='live')return;endRound(win,'Décision de l\'admin');admLog('Manche donnée aux '+(win===0?'Attaquants':'Défenseurs'));}
function admEndMatch(){
 if(!admCanAct()||!G.running)return;
 admLog('Partie terminée par l\'admin','#ffb36b');
 // modes à score : le meilleur gagne, comme à la fin du chrono ; sinon fin immédiate
 if(isDM()&&!{zombies:1,br:1,train:1}[G.variant]){G.state='live';G.timeLeft=0;}
 else matchOver();
}
function admTime(){if(!admCanAct()||!G.running)return;if(isDM())G.timeLeft+=60;else G.timer+=60;admLog('+1 minute');}
function admAnnounce(txt){
 txt=String(txt||'').trim().slice(0,90);if(!txt)return;
 if(NET.role==='client'){uiToast('Seul l\'hôte peut faire une annonce');return;}
 uiBanner('ANNONCE',txt,4500,'#ffd75e');
 if(NET.role==='host')netSend({t:'chat',n:'ADMIN',m:txt,c:'#ffd75e'});
 admLog('Annonce : '+txt,'#ffd75e');
}
/* ---------- journal ---------- */
const _admFeed=uiFeed;
uiFeed=function(a,v,w,hs){_admFeed(a,v,w,hs);if(a&&v)admLog(a===v?v.name+' est mort':a.name+' ➜ '+v.name+' ('+((w&&w.n)||'?')+(hs?', tête':'')+')');};
const _admChat=chatAdd;
chatAdd=function(name,msg,col){_admChat(name,msg,col);ADM.log.push({t:'💬',txt:name+' : '+msg,col:'#9fe3ff'});if(ADM.log.length>150)ADM.log.shift();};
const _admStart=startMatch;
startMatch=function(){G.admFrozenMe=false;_admStart();admLog('Partie lancée : '+((MODES[G.variant]||{}).n||G.variant)+' sur '+((MAPS[cfg.map]||{}).n||cfg.map),'#7dff9f');};
/* ---------- vision à travers les murs ---------- */
const XRM={};
function xrMat(col,skin){
 const k=col+(skin?'s':'');if(XRM[k])return XRM[k];
 return XRM[k]=new THREE.MeshBasicMaterial({color:col,skinning:!!skin,transparent:true,opacity:.5,depthTest:false,depthWrite:false,toneMapped:false});
}
function xrClear(e){
 const R=e.rig;if(!R||!R.root.userData.xr)return;
 for(const o of R.root.userData.xr)if(o.parent)o.parent.remove(o);
 R.root.userData.xr=null;R.root.userData.xrCol=null;
}
function xrApply(e,col){
 xrClear(e);
 const meshes=[],list=[];
 e.rig.root.traverse(o=>{if(o.isMesh&&!o.userData.isOl&&o.geometry&&o.visible)meshes.push(o);});
 for(const m of meshes){
  let x;
  if(m.isSkinnedMesh){x=new THREE.SkinnedMesh(m.geometry,xrMat(col,true));x.bind(m.skeleton,m.bindMatrix);x.frustumCulled=false;}
  else x=new THREE.Mesh(m.geometry,xrMat(col,false));
  x.userData.isOl=true;x.userData.isXr=true;x.renderOrder=999;m.add(x);list.push(x);
 }
 e.rig.root.userData.xr=list;e.rig.root.userData.xrCol=col;
}
const _admV=new THREE.Vector3();
function admVisionUpdate(){
 const on=ADM.vision&&admVisionWhy()==='';
 if(!ADM.tagEl){ADM.tagEl=document.createElement('div');ADM.tagEl.id='admTags';ADM.tagEl.style.cssText='position:fixed;inset:0;pointer-events:none;z-index:6;font:700 11px system-ui';document.body.appendChild(ADM.tagEl);}
 const seen=new Set();ADM.xrOn=false;
 if(G.running&&P)for(const e of ents){
  if(e.isPlayer||!e.rig)continue;
  const foe=MODE().team?e.team!==P.team:true,want=on&&(foe||ADM.allies);
  if(!want){xrClear(e);continue;}
  ADM.xrOn=true;
  const col=foe?0xff2a3a:0x37a6ff;
  if(e.rig.root.userData.xrCol!==col)xrApply(e,col);
  for(const x of e.rig.root.userData.xr)x.visible=e.alive;
  if(!ADM.tags||!e.alive)continue;
  _admV.set(e.x,e.y+(e.crouch?1.6:2.05),e.z).project(camera);
  if(_admV.z>1)continue;
  seen.add(e);
  let t=ADM.tagMap.get(e);
  if(!t){t=document.createElement('div');t.style.cssText='position:absolute;transform:translate(-50%,-100%);text-align:center;white-space:nowrap;text-shadow:0 1px 2px #000';ADM.tagEl.appendChild(t);ADM.tagMap.set(e,t);}
  const d=Math.round(Math.hypot(e.x-camera.position.x,e.z-camera.position.z)),hp=Math.max(0,Math.round(e.hp)),c=foe?'#ff6b78':'#7cc4ff';
  const h='<div style="color:'+c+'">'+admEsc(e.name)+(e.remote?' 👤':'')+' · '+d+' m</div><div style="width:46px;height:4px;margin:2px auto 0;background:#0009"><div style="width:'+hp+'%;height:100%;background:'+(hp>50?'#7dff9f':hp>25?'#ffd75e':'#ff4655')+'"></div></div>';
  if(t._h!==h){t.innerHTML=h;t._h=h;}
  t.style.left=((_admV.x+1)/2*innerWidth).toFixed(0)+'px';t.style.top=((1-_admV.y)/2*innerHeight).toFixed(0)+'px';t.style.display='';
 }
 for(const [e,t] of ADM.tagMap)if(!seen.has(e)){if(!ents.includes(e)){t.remove();ADM.tagMap.delete(e);}else t.style.display='none';}
}
/* ---------- visée auto ---------- */
Object.assign(ADM,{aim:false,aimMode:'ads',aimForce:2,aimFov:25});
// '' = visée auto autorisée, sinon la raison (même règle que la vision, mais il faut être en vie)
function admAimWhy(){
 if(!G.running||!P)return 'Lance une partie pour l\'utiliser';
 if(!P.alive)return 'Tu es éliminé';
 if(!NET.role)return '';
 if(NET.role==='client'||admVisionWhy())return 'Des joueurs humains sont en face : la visée auto est coupée pour ne pas fausser leur partie';
 return '';
}
function admAimUpdate(dt){
 if(!ADM.aim||!ADM.ok||ADM.on||!P||!P.alive||G.state==='cine'||admAimWhy())return;
 const act=ADM.aimMode==='always'||(ADM.aimMode==='fire'?mouseL:(mouseR||P.ads>.1));
 if(!act)return;
 const ex=P.x,ey=P.y+P.eyeH,ez=P.z,team=MODE().team,lim=ADM.aimMode==='always'?ADM.aimFov*RAD:ADM.aimFov*RAD*1.6;
 let best=null,bd=lim,by=0,bp=0;
 for(const e of ents){
  if(e===P||!e.alive||(team&&e.team===P.team))continue;
  const hx=e.x,hy=e.y+eyeOf(e)+.06,hz=e.z,dx=hx-ex,dy=hy-ey,dz=hz-ez,hd=Math.hypot(dx,dz);
  if(hd<.3||hd>120)continue;
  const yw=Math.atan2(-dx,-dz),pt=Math.atan2(dy,hd),d=Math.hypot(angDiff(P.yaw,yw),pt-P.pitch);
  if(d>=bd||!losClear(ex,ey,ez,hx,hy,hz))continue;
  best=e;bd=d;by=yw;bp=pt;
 }
 if(!best)return;
 // on vise en tenant compte du recul, pour que la balle parte bien sur la tête
 const ty=by-(P.punchY||0)*RAD,tp=bp-(P.punchP||0)*RAD,k=ADM.aimForce>=3?1:Math.min(1,dt*(ADM.aimForce===2?14:6));
 P.yaw+=angDiff(P.yaw,ty)*k;P.pitch=clamp(P.pitch+(tp-P.pitch)*k,-1.5,1.5);
}
const _admUpdPlayer=updatePlayer;
updatePlayer=function(dt){
 if(G.admFrozenMe&&NET.role==='client'&&P.alive){P.vx=P.vz=0;P.speed=0;tickWeapon(P,dt);return;}
 _admUpdPlayer(dt);admAimUpdate(dt);admCheatTick();
};
/* ---------- se donner des choses (profil local : ne touche personne d'autre) ---------- */
function admProfSaved(msg){
 saveProf();
 for(const f of [()=>refreshProfile(),()=>buildLocker(),()=>buildBoxesTab(),()=>drawProgressTab()])try{f();}catch(e){}
 admLog(msg,'#7dff9f');uiToast(msg);
}
function admGiveAll(){
 let n=0;
 for(const k in W)for(let i=1;i<SKINS.length;i++)if(grantItem({t:'skin',w:k,s:i}))n++;
 for(let i=1;i<OUTFITS.length;i++)if(grantItem({t:'outfit',o:i}))n++;
 for(const d of DANCES)if(grantItem({t:'dance',id:d.id}))n++;
 ensureBP();PROF.bp.prem=true;PROF.bp.xp=Math.max(PROF.bp.xp,SEASON.tiers*SEASON.xpPer);
 admProfSaved('Tout débloqué ('+n+' objets, passe de combat premium au max)');
}
function admGiveCoins(n){PROF.coins+=n;admProfSaved('+'+n+' pièces');}
function admGiveLevels(n){
 const li=levelInfo();let x=li.need-li.cur;for(let l=li.level+1;l<li.level+n;l++)x+=xpNeed(l);
 addXP(x);admProfSaved('+'+n+' niveau'+(n>1?'x':'')+' (niveau '+levelInfo().level+')');
}
function admGiveBoxes(){PROF.boxes.std=(PROF.boxes.std||0)+5;PROF.boxes.prem=(PROF.boxes.prem||0)+5;admProfSaved('+5 caisses standard et +5 premium');}
/* ---------- triches en partie ---------- */
Object.assign(ADM,{god:false,ammo:false,nades:false});
const admHumansFacing=()=>{if(!NET.role)return false;if(NET.role==='client')return true;const team=MODE().team;for(const p of NET.players.values())if(p.ent&&(!team||p.ent.team!==P.team))return true;return false;};
// '' = triche autorisée (solo, ou salon sans humain en face)
function admCheatWhy(){
 if(!G.running||!P)return 'Lance une partie pour l\'utiliser';
 return admHumansFacing()?'Des joueurs humains sont en face : coupé pour ne pas fausser leur partie':'';
}
function admTakeWeapon(k){
 if(!W[k]||admCheatWhy()||!P.alive)return;
 giveWeapon(P,k);P.cur=slotOf(k);admLog('Arme prise : '+W[k].n);
}
function admMoney(){if(admCheatWhy())return;P.money=16000;admLog('Argent de partie au max');}
const _admHurt=hurt;
hurt=function(v,att,w,zone,dist,raw){if(ADM.god&&v===P&&!admCheatWhy())return;_admHurt(v,att,w,zone,dist,raw);};
function admCheatTick(){
 if(!G.running||!P||!P.alive||admCheatWhy())return;
 if(ADM.god)P.hp=Math.max(P.hp,100);
 if(ADM.ammo)for(const sl of ['p','s']){const wi=P.wp[sl];if(wi&&!W[wi.k].melee){wi.mag=magMax(P,wi.k);wi.res=Math.max(wi.res,W[wi.k].res||90);}}
 if(ADM.nades){const n=P.nade;n.f=Math.max(n.f||0,1);n.fl=Math.max(n.fl||0,1);n.sm=Math.max(n.sm||0,1);n.mn=Math.max(n.mn||0,1);}
}
/* ---------- geler un joueur (modération : l'hôte peut toujours le faire) ---------- */
function admFreeze(e){
 if(!e||e.isPlayer||!admCanAct())return;
 e.admFrozen=!e.admFrozen;e.speed=0;e.vx=e.vz=0;
 if(e.remote)netSend({t:'frz',on:e.admFrozen?1:0},e.remote);
 admLog(e.name+(e.admFrozen?' gelé':' dégelé'),'#9fe3ff');
}
const _admNetEnt=netEntUpdate;
netEntUpdate=function(e,dt){if(e.admFrozen){tickWeapon(e,dt);e.speed=0;return;}_admNetEnt(e,dt);};
/* ---------- panneau ---------- */
function admBuild(){
 if(ADM.el)return;
 const st=document.createElement('style');
 st.textContent='#admin{position:fixed;top:50%;left:50%;transform:translate(-50%,-50%);width:min(640px,94vw);max-height:88vh;overflow:auto;z-index:30;background:var(--panel2);border:1px solid var(--line);border-top:3px solid var(--gold);padding:14px 16px;display:none;font-size:.8rem;color:var(--txt);box-shadow:0 20px 60px #000a}'+
  '#admin h3{margin:0 0 10px;letter-spacing:4px;font-size:1rem;color:var(--gold);display:flex;justify-content:space-between;align-items:center}'+
  '#admin .chip{padding:5px 9px;font-size:.7rem;transition:none}#admin .chip:hover{transform:none}#admin .chips{display:flex;gap:5px;flex-wrap:wrap}'+
  '#admin table{width:100%;border-collapse:collapse;margin-top:8px}#admin td,#admin th{padding:5px 4px;border-bottom:1px solid #ffffff12;text-align:left;vertical-align:middle}#admin th{color:var(--dim);font-size:.66rem;letter-spacing:1px}'+
  '#admin .acts{display:flex;gap:3px;flex-wrap:wrap}#admin .acts .chip{padding:3px 6px;font-size:.64rem}#admin .note{color:var(--dim);font-size:.7rem;line-height:1.5;margin-top:8px}'+
  '#admin input[type=text],#admin input[type=password]{background:#0d1422;border:1px solid var(--line);color:#fff;padding:8px 10px;font-weight:700}#admin .sec{margin-top:12px}#admin .sec h4{margin:0 0 6px;font-size:.7rem;letter-spacing:2px;color:var(--dim)}';
 document.head.appendChild(st);
 const el=document.createElement('div');el.id='admin';document.body.appendChild(el);ADM.el=el;
 el.addEventListener('click',ev=>{
  const b=ev.target.closest('[data-a]');if(!b)return;
  sfxUI();
  const a=b.dataset.a,id=b.dataset.id,e=id!==undefined?admEnt(+id):null;
  switch(a){
   case 'close':admClose();return;
   case 'tab':ADM.tab=b.dataset.t;break;
   case 'unlock':admUnlock();return;
   case 'lock':try{localStorage.removeItem('sa_admin');}catch(_){}ADM.ok=false;ADM.vision=false;ADM.aim=false;{const b=$('admPauseBtn');if(b)b.remove();}admClose();return;
   case 'kick':admKick(b.dataset.id,false);break;
   case 'ban':admKick(b.dataset.id,true);break;
   case 'unban':ADM.banned.delete(b.dataset.id);admLog(b.dataset.id+' débanni');break;
   case 'mute':admMute(b.dataset.id);break;
   case 'kill':admKill(e);break;
   case 'heal':admHeal(e);break;
   case 'revive':admRevive(e);break;
   case 'team':admTeam(e);break;
   case 'rmbot':admRemoveBot(e);break;
   case 'spec':admSpec(e);break;
   case 'addbot':admAddBot(+b.dataset.t);break;
   case 'endround':admEndRound(+b.dataset.t);break;
   case 'endmatch':admEndMatch();break;
   case 'time':admTime();break;
   case 'freeze':ADM.freeze=!ADM.freeze;admLog(ADM.freeze?'Bots figés':'Bots libérés');break;
   case 'announce':{const i=$('admAnn');admAnnounce(i.value);i.value='';break;}
   case 'vision':ADM.vision=!ADM.vision;admLog('Vision à travers les murs '+(ADM.vision?'activée':'coupée'));break;
   case 'allies':ADM.allies=!ADM.allies;break;
   case 'freeze1':admFreeze(e);break;
   case 'giveall':admGiveAll();break;
   case 'coins':admGiveCoins(+b.dataset.t);break;
   case 'lvl':admGiveLevels(+b.dataset.t);break;
   case 'boxes':admGiveBoxes();break;
   case 'god':ADM.god=!ADM.god;admLog('Immortel '+(ADM.god?'activé':'coupé'));break;
   case 'ammo':ADM.ammo=!ADM.ammo;admLog('Balles infinies '+(ADM.ammo?'activées':'coupées'));break;
   case 'nades':ADM.nades=!ADM.nades;admLog('Grenades infinies '+(ADM.nades?'activées':'coupées'));break;
   case 'money':admMoney();break;
   case 'weapon':admTakeWeapon(b.dataset.t);break;
   case 'aim':ADM.aim=!ADM.aim;admLog('Visée auto '+(ADM.aim?'activée':'coupée'));break;
   case 'aimmode':ADM.aimMode=b.dataset.t;break;
   case 'aimforce':ADM.aimForce=+b.dataset.t;break;
   case 'tags':ADM.tags=!ADM.tags;break;
   case 'clearlog':ADM.log=[];break;
  }
  admDraw();
 });
 // pas de rafraîchissement pendant un clic (sinon le bouton serait remplacé avant le « click »)
 el.addEventListener('mousedown',()=>{ADM.md=true;});addEventListener('mouseup',()=>{setTimeout(()=>{ADM.md=false;},0);});
}
function admUnlock(){
 const i=$('admCode');if(!i)return;
 const code=admNorm(i.value);
 admCheck(code).then(ok=>{
  if(ok){ADM.ok=true;try{localStorage.setItem('sa_admin',code);}catch(_){}admLog('Accès admin ouvert','#7dff9f');admDraw();admPauseBtn();}
  else{i.value='';i.placeholder=window.crypto&&crypto.subtle?'Code incorrect':'Ouvre le jeu par son lien internet';i.style.borderColor='var(--accent)';}
 });
}
const admChip=(a,txt,o)=>'<button class="chip'+(o&&o.on?' on':'')+'" data-a="'+a+'"'+(o&&o.id!==undefined?' data-id="'+admEsc(o.id)+'"':'')+(o&&o.t!==undefined?' data-t="'+o.t+'"':'')+(o&&o.tip?' title="'+admEsc(o.tip)+'"':'')+'>'+txt+'</button>';
function admTeamName(e){if(!MODE().team)return '—';return '<span style="color:'+TEAMCSS[e.team]+'">'+(e.team===0?'Attaquants':'Défenseurs')+'</span>';}
function admPlayersHTML(){
 const act=admCanAct();let h='';
 if(NET.role==='client')h+='<div class="note">Tu es client dans le salon de quelqu\'un d\'autre : seul l\'hôte peut expulser ou modifier la partie. Tu peux quand même regarder.</div>';
 if(NET.role==='host'&&!G.running){
  h+='<table><tr><th>JOUEUR</th><th>PING</th><th></th></tr>';
  for(const p of NET.players.values())h+='<tr><td>👤 '+admEsc(p.name)+(ADM.muted.has(p.id)?' 🔇':'')+'</td><td>'+(p.ping!==undefined?p.ping+' ms':'…')+'</td><td class="acts">'+admChip('kick','Expulser',{id:p.id})+admChip('ban','Bannir',{id:p.id})+admChip('mute',ADM.muted.has(p.id)?'Rendre la parole':'Muet',{id:p.id})+'</td></tr>';
  h+='</table>';if(!NET.players.size)h+='<div class="note">Personne dans le salon pour l\'instant.</div>';
 }else if(!G.running){h+='<div class="note">Aucune partie en cours. Lance une partie (solo ou en salon) pour gérer les joueurs et les bots.</div>';}
 if(G.running&&P){
  const rows=ents.filter(e=>!e.dummy).slice().sort((a,b)=>(a.team-b.team)||(b.kills-a.kills));
  h+='<table><tr><th>NOM</th><th>ÉQUIPE</th><th>K / M</th><th>PV</th><th>PING</th><th>ACTIONS</th></tr>';
  for(const e of rows){
   const np=e.remote?NET.players.get(e.remote):null,kind=e.isPlayer?'⭐':e.remote?'👤':'🤖';
   let a='';
   if(act&&!e.zombie){
    if(np)a+=admChip('kick','Expulser',{id:np.id})+admChip('ban','Bannir',{id:np.id})+admChip('mute',ADM.muted.has(np.id)?'Parole':'Muet',{id:np.id});
    if(!e.isPlayer)a+=admChip('freeze1',e.admFrozen?'Dégeler':'Geler',{id:e.id,on:!!e.admFrozen});
    a+=e.alive?admChip('kill','Tuer',{id:e.id})+admChip('heal','Soigner',{id:e.id}):admChip('revive','Réapparaître',{id:e.id});
    if(MODE().team&&!e.zombie)a+=admChip('team','Équipe',{id:e.id,tip:'Changer d\'équipe'});
    if(!e.isPlayer&&!e.remote)a+=admChip('rmbot','Retirer',{id:e.id});
   }
   if(!P.alive&&e.alive&&!e.isPlayer)a+=admChip('spec','Observer',{id:e.id});
   h+='<tr style="opacity:'+(e.alive?1:.55)+'"><td>'+kind+' '+admEsc(e.name)+(np&&ADM.muted.has(np.id)?' 🔇':'')+'</td><td>'+admTeamName(e)+'</td><td>'+e.kills+' / '+e.deaths+'</td><td>'+(e.alive?Math.round(e.hp):'💀')+'</td><td>'+(np&&np.ping!==undefined?np.ping+' ms':'')+'</td><td class="acts">'+a+'</td></tr>';
  }
  h+='</table>';
  if(act){
   h+='<div class="sec"><h4>BOTS</h4><div class="chips">'+(MODE().team?admChip('addbot','+ Bot attaquant',{t:0})+admChip('addbot','+ Bot défenseur',{t:1}):admChip('addbot','+ Bot',{t:0}))+admChip('freeze',ADM.freeze?'Bots figés ✓':'Figer les bots',{on:ADM.freeze})+'</div></div>';
  }
 }
 if(ADM.banned.size)h+='<div class="sec"><h4>BANNIS (par pseudo, jusqu\'à la fermeture du salon)</h4><div class="chips">'+[...ADM.banned].map(n=>admChip('unban',admEsc(n)+' ✕',{id:n,tip:'Débannir'})).join('')+'</div></div>';
 return h;
}
function admGameHTML(){
 if(!G.running)return '<div class="note">Aucune partie en cours.</div>';
 const dm=isDM(),hum=NET.role==='host'?NET.players.size+1:1;
 const alive=t=>ents.filter(e=>e.alive&&e.team===t&&!e.dummy).length;
 const tm=Math.max(0,Math.ceil(dm?G.timeLeft:G.timer)),clock=tm>1e6?'∞':Math.floor(tm/60)+':'+('0'+tm%60).slice(-2);
 let h='<table>'+
  '<tr><td>Mode</td><td><b>'+admEsc((MODES[G.variant]||{}).n||G.variant)+'</b></td></tr>'+
  '<tr><td>Carte</td><td><b>'+admEsc((MAPS[cfg.map]||{}).n||cfg.map)+'</b></td></tr>'+
  '<tr><td>Phase</td><td>'+({freeze:'Préparation',live:'En cours',end:'Fin de manche',over:'Terminée',cine:'Arrivée',potg:'Action du match'}[G.state]||G.state)+(G.mode==='bomb'?' · manche '+G.round:'')+'</td></tr>'+
  '<tr><td>Chrono</td><td>'+clock+'</td></tr>'+
  (MODE().team?'<tr><td>Score</td><td><span style="color:'+TEAMCSS[0]+'">Attaquants '+G.score[0]+'</span> — <span style="color:'+TEAMCSS[1]+'">'+G.score[1]+' Défenseurs</span> (premier à '+G.limit+')</td></tr><tr><td>En vie</td><td>'+alive(0)+' contre '+alive(1)+'</td></tr>':'')+
  (G.mode==='bomb'?'<tr><td>Bombe</td><td>'+({carried:'Portée',dropped:'Au sol',planted:'Posée ('+Math.ceil(BM.timer)+' s)',defused:'Désamorcée',exploded:'Explosée'}[BM.state]||'—')+'</td></tr>':'')+
  '<tr><td>Joueurs humains</td><td>'+hum+(NET.role?' (salon '+admEsc(NET.room)+')':' (solo)')+'</td></tr></table>';
 if(admCanAct()){
  h+='<div class="sec"><h4>CONTRÔLE</h4><div class="chips">'+
   (G.mode==='bomb'?admChip('endround','Manche aux attaquants',{t:0})+admChip('endround','Manche aux défenseurs',{t:1}):'')+
   admChip('time','+1 minute')+admChip('endmatch','Terminer la partie')+admChip('freeze',ADM.freeze?'Bots figés ✓':'Figer les bots',{on:ADM.freeze})+'</div></div>';
 }
 return h;
}
function admAimHTML(){
 const why=admAimWhy();
 return '<div class="sec"><h4>VISÉE AUTO</h4><div class="chips">'+admChip('aim',ADM.aim?'Visée auto activée ✓':'Activer la visée auto',{on:ADM.aim})+'</div>'+
  '<div class="chips" style="margin-top:6px">'+[['ads','En visant (clic droit)'],['fire','En tirant'],['always','Toujours']].map(o=>admChip('aimmode',o[1],{t:o[0],on:ADM.aimMode===o[0]})).join('')+'</div>'+
  '<div class="chips" style="margin-top:6px">'+[[1,'Douce'],[2,'Forte'],[3,'Verrouillée']].map(o=>admChip('aimforce',o[1],{t:o[0],on:ADM.aimForce===o[0]})).join('')+'</div>'+
  '<div class="note" style="color:'+(why?'#ffb36b':'#7dff9f')+'">'+(why?admEsc(why):ADM.aim?'Active : la visée se cale sur la tête de l\'ennemi visible le plus proche du réticule.':'Disponible ici.')+'</div>'+
  '<div class="note">Marche en solo et contre les bots. En ligne contre d\'autres joueurs, elle reste coupée.</div></div>';
}
function admGiveHTML(){
 const li=levelInfo();
 return '<div class="note" style="margin-top:0">Ton profil : niveau '+li.level+' · 🪙 '+PROF.coins+' · 📦 '+((PROF.boxes.std||0)+(PROF.boxes.prem||0))+'</div>'+
  '<div class="sec"><h4>DÉBLOQUER</h4><div class="chips">'+admChip('giveall','Tout débloquer (camos, tenues, danses, passe premium)')+admChip('boxes','+5 caisses de chaque')+'</div></div>'+
  '<div class="sec"><h4>PIÈCES</h4><div class="chips">'+[1000,10000,100000].map(n=>admChip('coins','+'+n.toLocaleString('fr-FR'),{t:n})).join('')+'</div></div>'+
  '<div class="sec"><h4>NIVEAUX</h4><div class="chips">'+[1,10,50].map(n=>admChip('lvl','+'+n+' niveau'+(n>1?'x':''),{t:n})).join('')+'</div></div>'+
  '<div class="note">Ça ne change que ton profil sur ce navigateur, personne d\'autre n\'est touché.</div>';
}
function admCheatsHTML(){
 const why=admCheatWhy();let h='<div class="sec" style="margin-top:0"><h4>TRICHES EN PARTIE</h4><div class="chips">'+
  admChip('god',ADM.god?'Immortel ✓':'Immortel',{on:ADM.god})+admChip('ammo',ADM.ammo?'Balles infinies ✓':'Balles infinies',{on:ADM.ammo})+admChip('nades',ADM.nades?'Grenades infinies ✓':'Grenades infinies',{on:ADM.nades})+admChip('money','Argent de partie au max')+'</div>';
 if(G.running&&P&&!why){
  h+='<div class="note">Prendre une arme :</div><div class="chips" style="margin-top:4px">'+Object.keys(W).filter(k=>!W[k].melee&&W[k].n&&(W[k].slot===0||W[k].slot===1)).map(k=>admChip('weapon',admEsc(W[k].n),{t:k})).join('')+'</div>';
 }
 return h+'<div class="note" style="color:'+(why?'#ffb36b':'#7dff9f')+'">'+(why?admEsc(why):'Disponible ici.')+'</div></div>';
}
function admVisionHTML(){
 const why=admVisionWhy();
 return admCheatsHTML()+'<div class="sec"><h4>VISION À TRAVERS LES MURS</h4></div><div class="chips">'+admChip('vision',ADM.vision?'Vision activée ✓':'Activer la vision',{on:ADM.vision})+admChip('allies','Voir aussi mes alliés',{on:ADM.allies})+admChip('tags','Noms, PV et distance',{on:ADM.tags})+'</div>'+
  '<div class="note" style="color:'+(why?'#ffb36b':'#7dff9f')+'">'+(why?admEsc(why):ADM.vision?'Actif : ennemis en rouge, alliés en bleu, visibles à travers les murs.':'Disponible ici.')+'</div>'+
  '<div class="note">Marche en solo, contre les bots, et en spectateur. En ligne contre d\'autres joueurs, elle se coupe tant que tu es en vie, pour ne pas fausser leur partie.</div>'+
  admAimHTML();
}
function admLogHTML(){
 if(!ADM.log.length)return '<div class="note">Rien pour l\'instant.</div>';
 return '<div style="max-height:46vh;overflow:auto;font-family:ui-monospace,monospace;font-size:.72rem;line-height:1.6">'+ADM.log.slice().reverse().map(l=>'<div><span style="color:var(--dim)">'+l.t+'</span> <span style="color:'+(l.col||'#c5d1e4')+'">'+admEsc(l.txt)+'</span></div>').join('')+'</div><div class="chips" style="margin-top:8px">'+admChip('clearlog','Vider le journal')+'</div>';
}
function admDraw(){
 admBuild();
 const el=ADM.el;
 if(!ADM.ok){
  ADM.html='';el.innerHTML='<h3>ACCÈS ADMIN '+admChip('close','Fermer ✕')+'</h3><div style="display:flex;gap:8px"><input type="password" id="admCode" placeholder="XXXX-XXXX-XXXX-XXXX" autocomplete="off" style="flex:1"><button class="btn cut" data-a="unlock" style="font-size:.8rem;padding:9px 16px">ENTRER</button></div><div class="note">Entre ton code admin. Il reste mémorisé sur ce navigateur.</div>';
  {const i=$('admCode');if(i)i.focus();}setTimeout(()=>{const i=$('admCode');if(i&&document.activeElement!==i)i.focus();},50);return;
 }
 const ann=$('admAnn'),annVal=ann?ann.value:'',focus=document.activeElement&&document.activeElement.id==='admAnn';
 const tabs=[['players','Joueurs'],['game','Partie'],['give','Donner'],['vision','Triche'],['log','Journal']];
 const body=ADM.tab==='players'?admPlayersHTML():ADM.tab==='game'?admGameHTML():ADM.tab==='vision'?admVisionHTML():ADM.tab==='give'?admGiveHTML():admLogHTML();
 const html='<h3>PANNEAU ADMIN <span>'+admChip('lock','Verrouiller',{tip:'Oublier le code sur ce navigateur'})+' '+admChip('close','Fermer (Inser) ✕')+'</span></h3>'+
  '<div class="chips">'+tabs.map(t=>admChip('tab',t[1],{t:t[0],on:ADM.tab===t[0]})).join('')+'</div>'+
  '<div id="admBody" style="margin-top:6px">'+body+'</div>'+
  (ADM.tab==='game'&&NET.role!=='client'?'<div class="sec"><h4>ANNONCE À TOUS</h4><div style="display:flex;gap:6px"><input type="text" id="admAnn" maxlength="90" placeholder="Message affiché en grand à tout le monde" style="flex:1"><button class="chip" data-a="announce">Envoyer</button></div></div>':'');
 if(html===ADM.html&&el.firstChild)return;ADM.html=html;el.innerHTML=html;
 const a2=$('admAnn');if(a2){a2.value=annVal;if(focus)a2.focus();}
}
function admOpen(){
 admBuild();ADM.on=true;ADM.el.style.display='block';admDraw();
 if(document.pointerLockElement)document.exitPointerLock();
 for(const k in keys)keys[k]=false;mouseL=mouseR=false;
}
function admClose(){
 ADM.on=false;if(ADM.el)ADM.el.style.display='none';
 if(G.running&&G.state!=='over')lockMouse();
}
// le panneau ne met pas le jeu en pause (en salon, ça figerait tout le monde)
document.addEventListener('pointerlockchange',()=>{if(ADM.on&&!document.pointerLockElement&&G.running){G.paused=false;$('pause').classList.remove('show');}});
addEventListener('keydown',e=>{
 // sans code mémorisé ni #admin dans l'adresse, Insert et F2 ne font rien : le panneau reste invisible pour les autres
 if((e.code==='Insert'||e.code==='F2')&&(ADM.on||ADM.ok||admAsked())){e.preventDefault();e.stopPropagation();if(ADM.on)admClose();else admOpen();return;}
 if(!ADM.on)return;
 if(e.code==='Escape'){e.preventDefault();e.stopPropagation();admClose();return;}
 if(e.code==='Enter'||e.code==='NumpadEnter'){const id=e.target&&e.target.id;if(id==='admCode')admUnlock();if(id==='admAnn'){admAnnounce(e.target.value);e.target.value='';}}
 // tant que le panneau est ouvert, les touches ne pilotent pas le personnage
 e.stopPropagation();
},true);
function admPauseBtn(){
 if(!ADM.ok||$('admPauseBtn'))return;
 const row=$('resume')&&$('resume').parentNode;if(!row)return;
 const b=document.createElement('button');b.className='btn alt cut';b.id='admPauseBtn';b.textContent='ADMIN (Inser)';b.onclick=()=>{$('pause').classList.remove('show');admOpen();};row.appendChild(b);
}
admPauseBtn();
// lien avec #admin : la fenêtre du code s'ouvre toute seule à la fin du chargement (pas besoin de touche)
(function admAutoOpen(){
 if(!admAsked())return;
 const tryOpen=()=>{const l=$('loading');if(l&&l.style.display!=='none'){setTimeout(tryOpen,300);return;}if(!ADM.ok&&!ADM.on)admOpen();};
 setTimeout(tryOpen,800);
})();
addEventListener('hashchange',()=>{if(admAsked()&&!ADM.ok&&!ADM.on)admOpen();});
/* ---------- boucle : ping des joueurs, vision, rafraîchissement ---------- */
let _admT=performance.now();
const _updateFXAdm=updateFX;
updateFX=function(dt,t){
 _updateFXAdm(dt,t);
 const n=performance.now(),rdt=Math.min(.1,(n-_admT)/1000);_admT=n;
 if(NET.role==='host'&&NET.players.size){ADM.pingT-=rdt;if(ADM.pingT<=0){ADM.pingT=2;netSend({t:'ping',ts:performance.now()});}}
 if(ADM.vision||ADM.xrOn||ADM.tagMap.size)admVisionUpdate();
 if(ADM.on&&ADM.ok&&ADM.tab!=='log'){ADM.drawT-=rdt;if(ADM.drawT<=0){ADM.drawT=.5;const ae=document.activeElement;if(!ADM.md&&!(ae&&ae.id==='admAnn'))admDraw();}}
};
window.__adm={ADM,admOpen,admClose,admKick,admAddBot,admVisionWhy,admCheck,admAimWhy};
