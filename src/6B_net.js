/* =====================================================================
   MULTIJOUEUR
   - « Même PC » : plusieurs onglets du navigateur (BroadcastChannel)
   - « En ligne » : code de salon via PeerJS (WebRTC pair-à-pair) — marche
     aussi quand le jeu est publié sur GitHub Pages
   L'HÔTE fait tourner la partie (bots, dégâts, manches, bombe) ; chaque
   CLIENT gère son propre déplacement et envoie ses tirs / achats / actions,
   puis affiche l'état reçu de l'hôte (15 fois par seconde).
   ===================================================================== */
const NET={role:null,mode:'local',room:'',myId:'',tr:null,players:new Map(),ev:[],sendT:0,inT:0,myEnt:-1,peerLib:false,status:'',teams:'coop',lastSnap:0,hostId:'host',view:new Map()};
const NET_OK_MODES={bomb:1,rapid:1,tdm:1,ffa:1,gg:1,koth:1};
const netId=()=>Math.random().toString(36).slice(2,8);
function netEvent(e){if(NET.role==='host')NET.ev.push(e);}
/* ---------- transports ---------- */
function trLocal(room,onMsg){
 const bc=new BroadcastChannel('strike-arena-'+room);
 bc.onmessage=ev=>{const m=ev.data;if(!m||m._from===NET.myId)return;if(m._to&&m._to!==NET.myId)return;onMsg(m,m._from);};
 return {send:(m,to)=>{m._from=NET.myId;if(to)m._to=to;else delete m._to;bc.postMessage(m);},close:()=>bc.close()};
}
function loadPeer(cb){
 if(window.Peer)return cb(true);
 const s=document.createElement('script');s.src='https://unpkg.com/peerjs@1.5.4/dist/peerjs.min.js';
 s.onload=()=>cb(!!window.Peer);s.onerror=()=>cb(false);document.head.appendChild(s);
}
function trOnline(room,host,onMsg,onReady){
 const conns=new Map();let peer;
 const wire=c=>{c.on('data',m=>{if(m&&m._from)onMsg(m,m._from);});c.on('close',()=>{for(const [id,cc] of conns)if(cc===c){conns.delete(id);onMsg({t:'bye'},id);}});};
 if(host){
  peer=new Peer('strikearena-'+room);
  peer.on('open',()=>onReady(true));
  peer.on('connection',c=>{c.on('open',()=>{conns.set(c.label||c.peer,c);});wire(c);c.on('data',m=>{if(m&&m._from&&!conns.has(m._from))conns.set(m._from,c);});});
 }else{
  peer=new Peer();
  peer.on('open',()=>{const c=peer.connect('strikearena-'+room,{reliable:true,label:NET.myId});c.on('open',()=>{conns.set('host',c);onReady(true);});wire(c);});
 }
 peer.on('error',e=>{netStatus('Erreur réseau : '+(e.type||e));onReady(false);});
 return {send:(m,to)=>{m._from=NET.myId;if(to){const c=conns.get(to)||conns.get('host');if(c&&c.open)c.send(m);}else for(const c of conns.values())if(c.open)c.send(m);},close:()=>{try{peer.destroy();}catch(e){}}};
}
function netSend(m,to){if(NET.tr)NET.tr.send(m,to);}
/* ---------- salon ---------- */
function netHost(){
 netLeave();NET.role='host';NET.myId='host';NET.room=Math.random().toString(36).slice(2,7).toUpperCase();NET.players.clear();
 const go=()=>{netStatus('Salon ouvert — code '+NET.room);netLobbyDraw();};
 if(NET.mode==='local'){NET.tr=trLocal(NET.room,netOnMsg);go();}
 else{netStatus('Connexion au service en ligne…');loadPeer(ok=>{if(!ok){netStatus('Impossible de charger le module en ligne (connexion internet ?)');return;}NET.tr=trOnline(NET.room,true,netOnMsg,r=>{if(r)go();});});}
}
function netJoin(code){
 code=(code||'').trim().toUpperCase();if(code.length<4){netStatus('Entre le code du salon');return;}
 netLeave();NET.role='client';NET.myId=netId();NET.room=code;
 const hello=()=>{netSend({t:'hello',name:cfg.name||'Joueur'});netStatus('Connecté au salon '+code+' — en attente de l\'hôte…');netLobbyDraw();};
 if(NET.mode==='local'){NET.tr=trLocal(code,netOnMsg);hello();}
 else{netStatus('Connexion…');loadPeer(ok=>{if(!ok){netStatus('Impossible de charger le module en ligne');return;}NET.tr=trOnline(code,false,netOnMsg,r=>{if(r)hello();else netStatus('Salon introuvable');});});}
}
function netLeave(){
 if(NET.tr){try{netSend({t:'bye'});}catch(e){}NET.tr.close();}
 NET.tr=null;NET.role=null;NET.players.clear();NET.view.clear();NET.myEnt=-1;
 for(const e of ents)if(e.remote)e.remote=null;
 netLobbyDraw();
}
function netStatus(s){NET.status=s;const el=$('mpStatus');if(el)el.textContent=s;}
/* ---------- réception ---------- */
function netOnMsg(m,from){
 if(NET.role==='host')netHostMsg(m,from);else if(NET.role==='client')netClientMsg(m);
}
function netHostMsg(m,from){
 const p=NET.players.get(from);
 if(m.t==='chat'||m.t==='pref'){netChatHost(m,from);return;}
 if(m.t==='hello'){
  NET.players.set(from,{id:from,name:String(m.name||'Joueur').slice(0,14),ent:null,in:null});
  netLobbyBroadcast();netLobbyDraw();
  if(G.running&&NET_OK_MODES[G.variant]){netAttach(NET.players.get(from));}
  return;
 }
 if(m.t==='bye'){if(p){if(p.ent){p.ent.remote=null;p.ent.name=p.ent.name+' (bot)';}NET.players.delete(from);netLobbyBroadcast();netLobbyDraw();uiToast(p.name+' a quitté la partie');}return;}
 if(!p||!p.ent||!G.running)return;
 const e=p.ent;
 if(m.t==='in'){p.in=m;}
 else if(m.t==='shot'&&e.alive){netShoot(e,m.yaw,m.pitch);}
 else if(m.t==='buy'){buyItem(e,m.k);}
 else if(m.t==='nade'&&e.alive){throwNade(e,m.k);}
 else if(m.t==='reload'){startReload(e);}
 else if(m.t==='slot'&&e.wp[m.s]){switchTo(e,m.s);}
 else if(m.t==='mine'){placeMine(e);}
}
function netLobbyBroadcast(){netSend({t:'lobby',players:[{name:cfg.name||'Hôte',host:1}].concat([...NET.players.values()].map(p=>({name:p.name})))});}
/* ---------- HÔTE : intégrer les joueurs distants ---------- */
function netHostStart(){
 if(NET.role!=='host')return;
 if(!NET_OK_MODES[G.variant]){uiToast('Mode non disponible en multijoueur : partie locale uniquement');return;}
 let n=0;for(const p of NET.players.values()){p.ent=null;netAttach(p,n++);}
}
function netAttach(p,n){
 let team=MODE().team?(NET.teams==='coop'?P.team:((n||0)%2===0?1-P.team:P.team)):null;
 if(team!==null&&(p.pref===0||p.pref===1))team=p.pref;
 let e=ents.find(b=>!b.isPlayer&&!b.remote&&!b.zombie&&!b.dummy&&(team===null||b.team===team));
 if(!e){
  const id=ents.reduce((m,x)=>Math.max(m,x.id),0)+1;
  e=newEnt(p.name,team===null?id:team,false,id);e.id=id;e.money=P.money;giveWeapon(e,e.team===0?'glock':'usp');ents.push(e);attachRig(e);
  if(G.mode!=='bomb')respawn(e);else{e.alive=false;e.keep=false;}
 }
 e.remote=p.id;e.name=p.name;p.ent=e;e.tp=(e.tp||0)+1;
 netSend({t:'start',cfg:{mode:cfg.mode,map:cfg.map,diff:cfg.diff,size:cfg.size,ffa:cfg.ffa,eco:cfg.eco,rounds:cfg.rounds,tdmKills:cfg.tdmKills,ffaKills:cfg.ffaKills,lim:cfg.lim,weather:cfg.weather,tod:cfg.tod},ent:e.id,team:e.team},p.id);
 uiToast(p.name+' a rejoint la partie');
}
function netShoot(e,yaw,pitch){
 e.yaw=yaw;e.pitch=pitch;const wi=curWi(e);if(!wi)return;
 if(wi.mag<=0&&!W[wi.k].melee)wi.mag=1;
 e.nextShot=0;e.reload=0;e.switchT=0;shoot(e);
}
function netEntUpdate(e,dt){
 const p=[...NET.players.values()].find(x=>x.ent===e),m=p&&p.in;
 tickWeapon(e,dt);
 if(!m||!e.alive){e.speed=0;return;}
 if(m.tp===e.tp){e.x=m.x;e.y=m.y;e.z=m.z;}
 e.yaw=m.yaw;e.pitch=m.pitch;e.crouch=!!m.cr;e.speed=m.sp;e.vx=m.vx;e.vz=m.vz;e.onGround=!!m.og;e.ads=m.ads||0;
 if(e.wp[m.cur]&&e.cur!==m.cur)switchTo(e,m.cur);
 handleUse(e,dt,!!m.use&&e.speed<1.2);
}
function netHostTick(dt){
 NET.sendT-=dt;if(NET.sendT>0||!NET.players.size)return;NET.sendT=1/15;
 const es=ents.filter(e=>!e.dummy).map(e=>{const o={i:e.id,n:e.name,tm:e.team,x:+e.x.toFixed(2),y:+e.y.toFixed(2),z:+e.z.toFixed(2),yw:+e.yaw.toFixed(3),pt:+e.pitch.toFixed(3),a:e.alive?1:0,hp:Math.round(e.hp),ar:Math.round(e.armor),sh:Math.round(e.shield),cw:curWi(e).k,fa:+(e.fireAnim||0).toFixed(2),cr:e.crouch?1:0,sp:+(e.speed||0).toFixed(2),k:e.kills,d:e.deaths,dm:e.dmg,tp:e.tp||0,m:e.money};
  if(e.zombie)o.z=1;if(e.remote){o.r=e.remote;o.wp=['p','s'].map(s=>e.wp[s]?[e.wp[s].k,e.wp[s].mag,e.wp[s].res]:null);o.nd=[e.nade.f,e.nade.fl,e.nade.sm,e.nade.mn||0];o.pg=e.prog||0;o.pm=e.progMsg||'';o.um=e.useMsg||'';o.kit=e.kit?1:0;}
  return o;});
 const g={st:G.state,tm:+(G.timer||0).toFixed(2),tl:+(G.timeLeft||0).toFixed(1),sc:G.score,rd:G.round,pr:G.pistolRound?1:0,lim:G.limit,ko:typeof KO!=='undefined'?KO.idx:0,kp:typeof KO!=='undefined'?KO.pts:null,
  bm:{s:BM.state,x:BM.x,y:BM.y,z:BM.z,t:BM.timer,c:BM.carrier}};
 netSend({t:'snap',g,e:es,ev:NET.ev});NET.ev=[];
}
/* ---------- CLIENT ---------- */
function netClientMsg(m){
 if(m.t==='chat'){chatAdd(m.n,m.m,m.c);return;}
 if(m.t==='lobby'){NET.lobby=m.players;netLobbyDraw();return;}
 if(m.t==='bye'){uiToast('L\'hôte a fermé le salon');if(G.running)toMenu();netLeave();netStatus('Salon fermé');return;}
 if(m.t==='start'){netClientStart(m);return;}
 if(m.t==='snap'&&G.running&&NET.myEnt>=0){netApplySnap(m);}
}
function netClientStart(m){
 Object.assign(cfg,m.cfg);cfg.cine=0;
 startMatch();buildRadarMap();
 for(const e of ents)if(e!==P&&e.rig)scene.remove(e.rig.root);
 ents=[P];NET.view.clear();NET.myEnt=m.ent;P.id=m.ent;
 if(P.team!==m.team){P.team=m.team;if(P.rig)scene.remove(P.rig.root);attachRig(P);P.rig.root.visible=false;}
 P.tp=-1;G.netClient=true;
 netStatus('En partie (client)');
}
function netEnt(o){
 let e=NET.view.get(o.i);
 if(!e){e=newEnt(o.n,o.tm,false,o.i);e.id=o.i;if(o.z){e.zombie=true;e.tone='#7ba35a';}e.wp={p:null,s:null,k:{k:'knife',mag:0,res:0}};const sl=slotOf(o.cw);e.wp[sl]={k:o.cw,mag:30,res:90};e.cur=sl;ents.push(e);attachRig(e);e.netT={x:o.x,y:o.y,z:o.z,yw:o.yw};e.x=o.x;e.y=o.y;e.z=o.z;NET.view.set(o.i,e);}
 return e;
}
function netApplySnap(m){
 const g=m.g;G.state=g.st==='over'?'end':g.st;G.timer=g.tm;G.timeLeft=g.tl;G.score=g.sc;G.round=g.rd;G.pistolRound=!!g.pr;G.limit=g.lim;
 if(typeof KO!=='undefined'&&KO.ring&&g.ko!==KO.idx){KO.idx=g.ko;kothPlace();}if(g.kp&&typeof KO!=='undefined'){KO.pts=g.kp;}
 const prevBM=BM.state;BM.state=g.bm.s;BM.x=g.bm.x;BM.y=g.bm.y;BM.z=g.bm.z;BM.timer=g.bm.t;BM.carrier=g.bm.c;
 if(BM.state==='planted'||BM.state==='dropped'){const mm=bombVisual();mm.position.set(BM.x,BM.y,BM.z);mm.visible=true;}else if(BM.mesh)BM.mesh.visible=false;
 if(prevBM!==BM.state){if(BM.state==='planted')sfx('plant',BM.x,BM.z,1.2);if(BM.state==='defused')sfx('defused');}
 const seen=new Set();
 for(const o of m.e){
  seen.add(o.i);
  if(o.i===NET.myEnt){
   // moi : vie, argent, armes et téléportations viennent de l'hôte
   const wasAlive=P.alive;P.alive=!!o.a;P.hp=o.hp;P.armor=o.ar;P.shield=o.sh;P.money=o.m;P.kills=o.k;P.deaths=o.d;P.dmg=o.dm;P.kit=!!o.kit;
   if(o.tp!==P.tp){P.tp=o.tp;P.x=o.x;P.y=o.y;P.z=o.z;P.yaw=o.yw;P.vx=P.vz=0;}
   if(o.wp)['p','s'].forEach((s,i)=>{const w=o.wp[i];if(!w){if(P.wp[s]){P.wp[s]=null;if(P.cur===s)P.cur=bestSlot(P);}return;}
    if(!P.wp[s]||P.wp[s].k!==w[0]){P.wp[s]={k:w[0],mag:w[1],res:w[2]};}else if(Math.abs(P.wp[s].mag-w[1])>2&&P.reload<=0){P.wp[s].mag=w[1];P.wp[s].res=w[2];}});
   if(o.nd)P.nade={f:o.nd[0],fl:o.nd[1],sm:o.nd[2],mn:o.nd[3]};
   P.prog=o.pg;P.progMsg=o.pm;P.netUseMsg=o.um;
   if(wasAlive&&!P.alive){P.rig&&(P.rig.root.visible=true);}
   continue;
  }
  const e=netEnt(o);
  e.name=o.n;e.team=o.tm;e.netT={x:o.x,y:o.y,z:o.z,yw:o.yw};e.pitch=o.pt;e.hp=o.hp;e.armor=o.ar;e.shield=o.sh;e.kills=o.k;e.deaths=o.d;e.dmg=o.dm;e.money=o.m;
  if(e.alive&&!o.a){e.dieDir=Math.floor(Math.random()*4);if(e.rig)e.rig.dieT=-1;}
  if(!e.alive&&o.a){e.x=o.x;e.y=o.y;e.z=o.z;}
  if(o.tp!==e.tp){e.tp=o.tp;e.x=o.x;e.y=o.y;e.z=o.z;e.yaw=o.yw;}
  e.alive=!!o.a;e.crouch=!!o.cr;e.speed=o.sp;e.fireAnim=Math.max(e.fireAnim||0,o.fa);
  {const cw=curWi(e);if(!cw||cw.k!==o.cw){const sl=slotOf(o.cw);e.wp[sl]={k:o.cw,mag:30,res:90};e.cur=sl;}}
 }
 for(const [id,e] of NET.view)if(!seen.has(id)){if(e.rig)scene.remove(e.rig.root);ents.splice(ents.indexOf(e),1);NET.view.delete(id);}
 for(const ev of m.ev||[])netClientEvent(ev);
}
function netById(id){return id===NET.myEnt?P:NET.view.get(id);}
function netClientEvent(ev){
 switch(ev.t){
  case 'tr':if(ev.s===NET.myEnt)break;{const a=ev.a;addTracer(a[0],a[1],a[2],a[3],a[4],a[5]);sfx(ev.c,a[0],a[2],1);muzzleFlash3D(a[0],a[1],a[2],.5);break;}
  case 'feed':{const a=netById(ev.a),v=netById(ev.v),w=W[ev.w]||W.knife;if(a&&v){uiFeed(a,v,w,ev.hs);rpKill(a,v,w,ev.hs);if(a===P&&v!==P){uiKillMsg(v,ev.hs,1);sfx('kill');}if(v===P)uiDeath(a);}break;}
  case 'hurt':if(ev.to===NET.myEnt){const a=netById(ev.f);if(a)uiDamage(a);sfx('dmg');G.shake=Math.max(G.shake,.25);}break;
  case 'ban':uiBanner(ev.a[0],ev.a[1],ev.a[2],ev.a[3]);break;
  case 'rend':{const mine=ev.w===P.team;uiBanner(mine?'MANCHE GAGNÉE':'MANCHE PERDUE',ev.r,4600,mine?'#7dff9f':'#ff6b6b');sfx(mine?'win':'lose');uiRoundEnd();closeBuy(true);rpStart();break;}
  case 'rr':clearNades();resetFX();uiRoundStart();rpReset();break;
  case 'nx':{const o=netById(ev.o)||P;explodeNade({type:ev.k,x:ev.x,y:ev.y,z:ev.z,owner:o});break;}
  case 'boom':sfx('boom',ev.x,ev.z,1.6);fxExplosion(ev.x,ev.y+.3,ev.z,2.2);G.shake=1;break;
  case 'over':G.winner=ev.w===null?null:netById(ev.w)||ev.w;G.score=ev.sc;G.state='over';G.running=false;if(document.pointerLockElement)document.exitPointerLock();uiMatchOver();break;
 }
}
function netClientTick(dt){
 // interpolation douce des autres joueurs
 for(const e of NET.view.values()){
  if(!e.netT)continue;const k=Math.min(1,dt*12);
  e.x+=(e.netT.x-e.x)*k;e.y+=(e.netT.y-e.y)*k;e.z+=(e.netT.z-e.z)*k;e.yaw+=angDiff(e.yaw,e.netT.yw)*k;
  e.fireAnim=Math.max(0,(e.fireAnim||0)-dt*9);
 }
 NET.inT-=dt;
 if(NET.inT<=0){NET.inT=1/20;
  netSend({t:'in',x:+P.x.toFixed(2),y:+P.y.toFixed(2),z:+P.z.toFixed(2),yaw:+P.yaw.toFixed(3),pitch:+P.pitch.toFixed(3),cr:P.crouch?1:0,sp:+P.speed.toFixed(2),vx:P.vx,vz:P.vz,og:P.onGround?1:0,ads:P.ads,cur:P.cur,use:K('use')?1:0,tp:P.tp},'host');
 }
 if(P.netUseMsg!==undefined)P.useMsg=P.netUseMsg;
}
/* tir local du client : visuel immédiat, les dégâts sont calculés par l'hôte */
function netShot(e){netSend({t:'shot',yaw:e.yaw+(e.punchY||0)*RAD,pitch:e.pitch+(e.punchP||0)*RAD},'host');}
/* fin de partie côté hôte */
function netMatchOver(){if(NET.role==='host'&&NET.players.size){netSend({t:'snap',g:{st:'over',tm:0,tl:0,sc:G.score,rd:G.round,lim:G.limit,bm:{s:BM.state}},e:[],ev:[{t:'over',w:G.winner&&G.winner.id!==undefined?G.winner.id:G.winner,sc:G.score}]});}}

/* ---------- interface du salon (Jouer > Multijoueur) ---------- */
(function netTabInit(){
 const tabs=$('mtabs');if(!tabs)return;
 const tb=document.createElement('div');tb.className='mtab';tb.dataset.t='mp';tb.textContent='Multijoueur';tabs.appendChild(tb);
 const p=document.createElement('div');p.className='tp';p.id='tab-mp';
 p.innerHTML='<div class="custgrid"><div><div class="csec"><h4>1 · TYPE DE CONNEXION</h4><div class="chips" id="mpMode"></div><small id="mpModeTxt" style="display:block;margin-top:8px;color:#8da0bd;font-size:.72rem;line-height:1.5"></small></div>'+
  '<div class="csec"><h4>2 · CRÉER OU REJOINDRE</h4><div style="display:flex;gap:10px;flex-wrap:wrap;margin-bottom:10px"><button class="btn cut" id="mpHost" style="font-size:.9rem;padding:11px 20px">CRÉER UN SALON</button></div>'+
  '<div style="display:flex;gap:8px"><input type="text" id="mpCode" maxlength="6" placeholder="CODE DU SALON" style="max-width:180px;text-transform:uppercase;letter-spacing:4px;font-weight:800"><button class="btn alt cut" id="mpJoin" style="font-size:.85rem;padding:9px 18px">REJOINDRE</button></div></div>'+
  '<div class="csec"><h4>3 · ÉQUIPES</h4><div class="chips" id="mpTeams"></div><small style="display:block;margin-top:8px;color:#8da0bd;font-size:.72rem">Les places libres sont remplies par des bots.</small></div></div>'+
  '<div><div class="csec"><h4>SALON</h4><div id="mpRoom" style="font-size:2.4rem;font-weight:900;letter-spacing:10px;color:var(--gold);min-height:3rem"></div><div id="mpStatus" style="font-size:.78rem;color:#c5d1e4;margin:6px 0 12px">Hors ligne</div><div id="mpList"></div>'+
  '<button class="btn cut" id="mpStart" style="width:100%;margin-top:12px;display:none">LANCER LA PARTIE</button><button class="chip" id="mpLeave" style="margin-top:10px;display:none">Quitter le salon</button></div>'+
  '<div class="csec"><h4>COMMENT JOUER À PLUSIEURS</h4><div style="font-size:.74rem;color:#b8c5da;line-height:1.6">'+
  '<b>Même PC :</b> ouvre le jeu dans plusieurs onglets / fenêtres, crée un salon dans l\'un et rejoins-le dans les autres.<br>'+
  '<b>En ligne :</b> publie le dossier sur <b>GitHub Pages</b> (ou n\'importe quel hébergeur), envoie le lien à tes amis, crée un salon et donne-leur le code. Connexion directe entre navigateurs (WebRTC).<br>'+
  'L\'hôte choisit le mode et la carte dans « Partie solo ». Modes disponibles : Compétitif, Désamorçage rapide, Match à mort (équipe ou libre), Course aux armes, Capture de zone.</div></div></div></div>';
 $('tab-keys').parentNode.appendChild(p);
})();
function netLobbyDraw(){
 const host=NET.role==='host',cli=NET.role==='client';
 const md=$('mpMode');if(!md)return;
 chipsRow('mpMode',[['Même PC (onglets)','local'],['En ligne (code)','online']],()=>NET.mode,v=>{if(NET.role)netLeave();NET.mode=v;},netLobbyDraw);
 $('mpModeTxt').textContent=NET.mode==='local'?'Pour tester ou jouer à plusieurs sur le même ordinateur (plusieurs onglets ouverts).':'Pour jouer avec des amis sur d\'autres ordinateurs : il faut une connexion internet (service gratuit PeerJS pour se trouver, puis connexion directe).';
 chipsRow('mpTeams',[['Ensemble contre les bots','coop'],['Les uns contre les autres','versus']],()=>NET.teams,v=>NET.teams=v,netLobbyDraw);
 if(!$('mpPref')){const d=document.createElement('div');d.className='chips';d.id='mpPref';d.style.marginTop='8px';$('mpTeams').parentNode.appendChild(d);}
 chipsRow('mpPref',[['Mon équipe : auto',-1],['Attaquants',0],['Défenseurs',1]],()=>NET.pref===undefined?-1:NET.pref,v=>{NET.pref=v;if(NET.role==='client')netSend({t:'pref',v},'host');},netLobbyDraw);
 $('mpRoom').textContent=NET.role?NET.room:'';
 $('mpStart').style.display=host?'':'none';$('mpLeave').style.display=NET.role?'':'none';
 const list=host?[{name:(cfg.name||'Hôte')+' (toi, hôte)'}].concat([...NET.players.values()].map(p=>({name:p.name}))):cli?(NET.lobby||[]).map(p=>({name:p.name+(p.host?' (hôte)':'')})):[];
 $('mpList').innerHTML=list.map(p=>'<div class="chip" style="margin-bottom:5px;cursor:default">👤 '+p.name+'</div>').join('')||'<div style="font-size:.72rem;color:#6f819e">Aucun joueur</div>';
 if(!NET.role)netStatus('Hors ligne');
}
function netLobbyWire(){
 if(!$('mpHost'))return;
 $('mpHost').onclick=()=>{initAudio();sfxUI();netHost();};
 $('mpJoin').onclick=()=>{initAudio();sfxUI();netJoin($('mpCode').value);};
 $('mpLeave').onclick=()=>{sfxUI();netLeave();};
 $('mpStart').onclick=()=>{
  initAudio();sfxUI();
  if(!NET_OK_MODES[cfg.mode]){uiToast('Choisis un mode compatible dans « Partie solo » (pas Zombies / Bataille royale / Entraînement)');return;}
  cfg.cine=0;startMatch();buildRadarMap();netHostStart();
 };
 netLobbyDraw();
}
/* ---------- discussion (Entrée pour écrire) ---------- */
const CHAT={el:null,inp:null};
function chatUi(){
 if(CHAT.el)return;
 const box=document.createElement('div');box.id='chatbox';box.style.cssText='position:fixed;left:14px;bottom:170px;width:340px;z-index:9;font:600 13px system-ui;pointer-events:none';
 box.innerHTML='<div id="chatLines" style="display:flex;flex-direction:column;gap:3px"></div><input id="chatIn" type="text" maxlength="120" placeholder="Message… (Entrée pour envoyer, Échap pour annuler)" style="display:none;margin-top:6px;pointer-events:auto;width:100%">';
 document.body.appendChild(box);CHAT.el=box;CHAT.inp=box.querySelector('#chatIn');
 CHAT.inp.addEventListener('keydown',e=>{
  e.stopPropagation();
  if(e.code==='Enter'){const m=CHAT.inp.value.trim();CHAT.inp.value='';CHAT.inp.style.display='none';if(m)chatSend(m);if(G.running)lockMouse();}
  else if(e.code==='Escape'){CHAT.inp.value='';CHAT.inp.style.display='none';if(G.running)lockMouse();}
 });
}
function chatAdd(name,msg,col){
 chatUi();const l=document.createElement('div');l.style.cssText='background:rgba(10,14,22,.72);padding:4px 9px;border-radius:3px;color:#fff;transition:opacity .6s;text-shadow:0 1px 2px #000';
 l.innerHTML='<b style="color:'+(col||'#ffd75e')+'">'+String(name).replace(/</g,'&lt;')+'</b> : '+String(msg).replace(/</g,'&lt;');
 const ls=CHAT.el.querySelector('#chatLines');ls.appendChild(l);while(ls.children.length>6)ls.removeChild(ls.firstChild);
 setTimeout(()=>{l.style.opacity=0;setTimeout(()=>l.remove(),700);},9000);
 sfx('ui');
}
function chatSend(m){
 const me=cfg.name||'Joueur',col=P&&TEAMCSS[P.team]||'#ffd75e';
 if(NET.role==='host'){chatAdd(me,m,col);netSend({t:'chat',n:me,m,c:col});}
 else if(NET.role==='client'){netSend({t:'chat',m},'host');}
}
addEventListener('keydown',e=>{
 if(!NET.role||e.code!=='Enter'||(e.target&&e.target.tagName==='INPUT'))return;
 chatUi();CHAT.inp.style.display='block';if(document.pointerLockElement)document.exitPointerLock();setTimeout(()=>CHAT.inp.focus(),0);e.preventDefault();
});
/* relais des messages et préférence d'équipe (branchés dans les gestionnaires réseau) */
function netChatHost(m,from){
 const p=NET.players.get(from);if(!p)return;
 if(m.t==='chat'){const col=p.ent?TEAMCSS[p.ent.team]:'#9fe3ff',msg=String(m.m||'').slice(0,120);chatAdd(p.name,msg,col);netSend({t:'chat',n:p.name,m:msg,c:col});}
 if(m.t==='pref'){p.pref=m.v;netLobbyBroadcast();netLobbyDraw();}
}
