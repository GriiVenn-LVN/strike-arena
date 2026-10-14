/* =====================================================================
   PROGRESSION : passe de combat, classement, succès, événement
   ===================================================================== */
const SEASON={id:'s1',n:'Saison 1 · Néon',tiers:30,xpPer:900,price:3500};
function ensureBP(){
 if(!PROF.bp||PROF.bp.id!==SEASON.id)PROF.bp={id:SEASON.id,xp:0,prem:false,cf:[],cp:[]};
 if(!PROF.rank)PROF.rank={rp:0,best:0};
 if(!PROF.ach)PROF.ach={};
 if(!PROF.ev)PROF.ev={id:'',pk:0,claimed:[]};
}
ensureBP();
const bpTier=()=>Math.min(SEASON.tiers,Math.floor(PROF.bp.xp/SEASON.xpPer));
function grantItem(it){
 if(it.t==='skin'){const a=PROF.inv.skins[it.w]||(PROF.inv.skins[it.w]=[]);if(a.includes(it.s))return false;a.push(it.s);return true;}
 if(it.t==='outfit'){const a=PROF.inv.outfits||(PROF.inv.outfits=[]);if(a.includes(it.o))return false;a.push(it.o);return true;}
 if(it.t==='dance'){if(PROF.inv.dances.includes(it.id))return false;PROF.inv.dances.push(it.id);return true;}
 return false;
}
function seedPick(arr,seed){let s=seed*9301+49297;s=(s*233280+11)%233280;return arr[Math.floor(s/233280*arr.length)];}
function bpReward(t,prem){
 if(!prem){
  if(t===SEASON.tiers)return {box:'prem',coins:200};
  if(t%10===0)return {box:'std',coins:60};
  return {coins:20+t*2};
 }
 if(t===1)return {box:'prem'};
 if(t%5===0){
  const q=t>=25?3:t>=10?2:1;
  const pool=lootPool().filter(i=>i.q===q&&(t%10===5?i.t!=='outfit':true));
  return {item:seedPick(pool,t*17+q)};
 }
 return {coins:40+t*4};
}
function bpRewardText(r){
 if(r.item){const it=r.item;return it.t==='skin'?W[it.w].n+' · '+SKINS[it.s].n:it.t==='outfit'?'Tenue '+OUTFITS[it.o].n:'Danse '+DANCES.find(d=>d.id===it.id).n;}
 return rewardText(r);
}
function bpClaim(t,prem){
 ensureBP();const arr=prem?PROF.bp.cp:PROF.bp.cf;
 if(t>bpTier()||arr.includes(t)||(prem&&!PROF.bp.prem))return null;
 const r=bpReward(t,prem);applyReward(r);let dup=false;
 if(r.item){if(!grantItem(r.item)){dup=true;PROF.coins+=DUPV[r.item.q];}}
 arr.push(t);saveProf();return {r,dup};
}
function bpBuy(){if(PROF.bp.prem||PROF.coins<SEASON.price)return false;PROF.coins-=SEASON.price;PROF.bp.prem=true;saveProf();return true;}

/* ---------- classement ---------- */
const RANKS=['Bronze','Argent','Or','Platine','Diamant','Maître'];
const rankIdx=()=>Math.min(18,Math.floor(PROF.rank.rp/100));
function rankName(i){i=i===undefined?rankIdx():i;return i>=18?'Légende':RANKS[Math.floor(i/3)]+' '+['I','II','III'][i%3];}
const RANK_COL=['#b07a4a','#c5ced9','#ffd23a','#5ee6d8','#6aa5ff','#c77dff','#ff4655'];
const rankCol=i=>RANK_COL[Math.min(6,Math.floor((i===undefined?rankIdx():i)/3))];
const RANKED_MODES={bomb:1,rapid:1,tdm:1,koth:1};
cfg.ranked=cfg.ranked||0;
function rankedEligible(){return cfg.ranked&&RANKED_MODES[cfg.mode]&&cfg.diff>=1;}
function rankUpdate(win){
 if(!rankedEligible())return null;
 const before=rankIdx(),d=cfg.diff;
 const delta=win?18+d*4:-Math.max(8,20-d*3);
 PROF.rank.rp=Math.max(0,PROF.rank.rp+delta);PROF.rank.best=Math.max(PROF.rank.best,PROF.rank.rp);
 const after=rankIdx();
 return {delta,before,after,name:rankName(after)};
}

/* ---------- succès ---------- */
const ACH=[
 {id:'first',n:'Premier sang',d:'Élimine un adversaire',c:50,f:(s)=>s.kills>=1},
 {id:'k100',n:'Centurion',d:'100 éliminations au total',c:200,f:(s)=>s.kills>=100},
 {id:'k500',n:'Machine de guerre',d:'500 éliminations au total',c:500,f:(s)=>s.kills>=500},
 {id:'hs50',n:'Chasseur de têtes',d:'50 headshots',c:250,f:(s)=>s.hs>=50},
 {id:'win1',n:'Première victoire',d:'Gagne une partie',c:100,f:(s)=>s.wins>=1},
 {id:'win10',n:'Champion',d:'Gagne 10 parties',c:400,f:(s)=>s.wins>=10},
 {id:'bomb10',n:'Artificier',d:'Pose ou désamorce 10 bombes',c:250,f:(s)=>s.plants+s.defuses>=10},
 {id:'play20',n:'Habitué',d:'Joue 20 parties',c:300,f:(s)=>s.matches>=20},
 {id:'acc',n:'Œil de lynx',d:'40 % de précision (300 tirs min.)',c:300,f:(s)=>s.shots>=300&&s.hits/s.shots>=.4},
 {id:'streak8',n:'Série infernale',d:'8 éliminations sans mourir',c:300,f:(s)=>s.bestStreak>=8},
 {id:'ace',n:'Ace',d:'10 éliminations dans une partie',c:300,f:(s,c)=>c&&c.kills>=10},
 {id:'royal',n:'Dernier survivant',d:'Gagne une bataille royale',c:350,f:(s,c)=>c&&c.variant==='br'&&c.win},
 {id:'zomb',n:'Exterminateur',d:'Survis à 5 vagues de zombies',c:350,f:(s,c)=>c&&c.variant==='zombies'&&c.wave>=5},
 {id:'koth',n:'Roi de la colline',d:'Gagne une capture de zone',c:300,f:(s,c)=>c&&c.variant==='koth'&&c.win},
 {id:'train',n:'Sur cible',d:'3000 points en entraînement',c:250,f:(s,c)=>c&&c.variant==='train'&&c.score>=3000},
 {id:'gold',n:'Chasseur d\'or',d:'Atteins le rang Or',c:400,f:()=>rankIdx()>=6},
 {id:'rich',n:'Fortune',d:'Possède 5000 pièces',c:200,f:()=>PROF.coins>=5000},
 {id:'bp15',n:'Passe en main',d:'Atteins le palier 15 du passe',c:300,f:()=>bpTier()>=15}
];
function checkAch(ctx){
 ensureBP();const s=PROF.stats,out=[];
 for(const a of ACH){if(PROF.ach[a.id])continue;let ok=false;try{ok=a.f(s,ctx);}catch(e){}if(ok){PROF.ach[a.id]=Date.now();PROF.coins+=a.c;out.push(a);}}
 if(out.length)saveProf();return out;
}

/* ---------- événement limité : Nuit d'Halloween ---------- */
const EVENT={id:'hw',n:'Nuit d\'Halloween',from:'2026-10-01',to:'2026-11-07',
 goals:[{n:10,r:{coins:300}},{n:25,r:{box:'std',coins:200}},{n:50,r:{box:'prem'}},{n:100,r:{box:'prem',coins:800,dance:'moonwalk'}}]};
const eventActive=()=>{const t=todayStr();return t>=EVENT.from&&t<=EVENT.to;};
const PUMPK=[];
function pumpkinMesh(){
 const g=new THREE.Group(),m=new THREE.MeshStandardMaterial({color:0xff7a1a,emissive:0xff4a00,emissiveIntensity:.55,roughness:.55});
 const b=new THREE.Mesh(new THREE.SphereGeometry(.3,14,10),m);b.scale.set(1.1,.85,1.1);b.position.y=.28;g.add(b);
 for(let i=-1;i<=1;i++){const r=new THREE.Mesh(new THREE.TorusGeometry(.29,.03,5,18,Math.PI),m);r.rotation.set(0,i*.9+Math.PI/2,0);r.position.y=.28;r.scale.set(.9,1,.9);g.add(r);}
 const st=new THREE.Mesh(new THREE.CylinderGeometry(.03,.045,.14,6),new THREE.MeshStandardMaterial({color:0x3f6b2a,roughness:.8}));st.position.y=.56;g.add(st);
 const fm=new THREE.MeshBasicMaterial({color:0xffe27a});
 for(const s of [-1,1]){const e=new THREE.Mesh(new THREE.ConeGeometry(.05,.08,3),fm);e.position.set(s*.1,.34,.28);e.rotation.x=Math.PI/2;g.add(e);}
 const mo=new THREE.Mesh(new THREE.BoxGeometry(.2,.04,.02),fm);mo.position.set(0,.2,.3);g.add(mo);
 const gl=new THREE.Sprite(new THREE.SpriteMaterial({map:GLOW.orange,color:0xff8a2a,blending:THREE.AdditiveBlending,transparent:true,depthWrite:false,toneMapped:false,opacity:.9}));gl.scale.set(2.2,2.2,1);gl.position.y=.35;g.add(gl);
 return g;
}
function clearPumpkins(){for(const p of PUMPK)scene.remove(p.m);PUMPK.length=0;}
function spawnPumpkins(){
 clearPumpkins();ensureBP();
 if(!eventActive()||!MAP||G.variant==='train')return;
 if(PROF.ev.id!==EVENT.id)PROF.ev={id:EVENT.id,pk:0,claimed:[]};
 const pts=shuffle((MAP.roam||[]).concat(MAP.holdCT||[]).concat(MAP.spawnDM||[]).slice());
 for(const c of pts.slice(0,7)){
  const x=c[0]*S+S/2+rand(-.6,.6),z=c[1]*S+S/2+rand(-.6,.6);if(blocked(x,z,groundH(x,z),.4))continue;
  const m=pumpkinMesh();m.position.set(x,groundH(x,z),z);m.rotation.y=rand(0,TAU);scene.add(m);PUMPK.push({m,x,z,y:groundH(x,z),ph:rand(0,6)});
 }
}
function pumpkinUpdate(dt){
 if(!PUMPK.length||!P)return;
 for(let i=PUMPK.length-1;i>=0;i--){
  const p=PUMPK[i];p.m.position.y=p.y+.04+Math.sin(G.t*2+p.ph)*.04;p.m.rotation.y+=dt*.8;
  if(P.alive&&Math.hypot(P.x-p.x,P.z-p.z)<1.2&&Math.abs(P.y-p.y)<2){
   scene.remove(p.m);PUMPK.splice(i,1);PROF.ev.pk++;sfx('pickup');uiToast('🎃 Citrouille ! ('+PROF.ev.pk+')');
   for(const g of EVENT.goals)if(PROF.ev.pk>=g.n&&!PROF.ev.claimed.includes(g.n)){PROF.ev.claimed.push(g.n);applyReward(g.r);uiToast('🎃 Palier '+g.n+' : '+rewardText(g.r));}
   saveProf();
  }
 }
}
/* ---------- fin de partie ---------- */
function progressMatch(win,xp){
 ensureBP();
 const before=bpTier();PROF.bp.xp+=xp;
 const rk=rankUpdate(win);
 const ctx={kills:P.kills,win,variant:G.variant,wave:typeof Z!=='undefined'?Z.wave:0,score:typeof TR!=='undefined'?TR.score:0};
 const ach=checkAch(ctx);
 saveProf();
 return {tier:bpTier(),gained:bpTier()-before,rank:rk,ach};
}

/* ---------- onglet « Progression » ---------- */
function buildProgressTab(){
 const tabs=$('mtabs');if(!tabs||$('tab-prog'))return;
 const tb=document.createElement('div');tb.className='mtab';tb.dataset.t='prog';tb.textContent='Progression';
 tabs.insertBefore(tb,tabs.querySelector('[data-t="stats"]'));
 const p=document.createElement('div');p.className='tp';p.id='tab-prog';p.innerHTML='<div id="progBox"></div>';
 $('tab-keys').parentNode.appendChild(p);
 const css=document.createElement('style');
 css.textContent='.pg-h{display:flex;justify-content:space-between;align-items:center;margin:4px 0 10px}.pg-h h3{margin:0;font-size:.9rem;letter-spacing:3px}.bp{display:flex;gap:8px;overflow-x:auto;padding-bottom:10px}.bpc{flex:0 0 112px;border:1px solid var(--line);background:#121a2a;border-radius:6px;padding:8px;font-size:.68rem;text-align:center}.bpc b{display:block;font-size:.8rem;color:#fff;margin-bottom:5px}.bpc .r{min-height:34px;color:#c5d1e4;margin:3px 0}.bpc .r.p{color:#ffd23a}.bpc button{margin-top:5px;width:100%;padding:4px;border-radius:3px;border:0;background:var(--accent);color:#fff;font-weight:800;font-size:.64rem;cursor:pointer}.bpc button[disabled]{background:#2a354a;color:#7b8ca6;cursor:default}.bpc.cur{border-color:var(--accent)}.agrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(210px,1fr));gap:8px}.ach{border:1px solid var(--line);background:#121a2a;border-radius:6px;padding:9px 11px;font-size:.72rem;opacity:.45}.ach.on{opacity:1;border-color:#ffd23a66}.ach b{display:block;color:#fff;font-size:.8rem}.ach small{color:#7b8ca6}.rk{display:flex;align-items:center;gap:14px;padding:12px 16px;border:1px solid var(--line);border-radius:8px;background:#121a2a;margin-bottom:14px}.rk .big{font-size:1.5rem;font-weight:900;letter-spacing:2px}.rkb{height:7px;border-radius:4px;background:#243049;overflow:hidden;margin-top:6px;width:240px}.rkb i{display:block;height:100%}.evc{padding:12px 16px;border:1px solid #ff7a1a66;background:linear-gradient(135deg,#2a1608,#121a2a);border-radius:8px;margin-bottom:14px;font-size:.78rem}';
 document.head.appendChild(css);
}
function drawProgressTab(){
 const el=$('progBox');if(!el)return;ensureBP();
 const t=bpTier(),pct=Math.round((PROF.bp.xp%SEASON.xpPer)/SEASON.xpPer*100),ri=rankIdx(),rc=rankCol(ri);
 let h='';
 h+='<div class="rk"><div style="font-size:2rem">🏅</div><div><div class="big" style="color:'+rc+'">'+rankName(ri).toUpperCase()+'</div><div style="font-size:.7rem;color:var(--dim)">'+(PROF.rank.rp%100)+' / 100 PR — meilleur : '+rankName(Math.min(18,Math.floor(PROF.rank.best/100)))+'</div><div class="rkb"><i style="width:'+(ri>=18?100:PROF.rank.rp%100)+'%;background:'+rc+'"></i></div></div><div style="margin-left:auto;font-size:.7rem;color:var(--dim);max-width:240px">Active « Partie classée » dans le menu Jouer (mode compétitif, MàM équipe, désamorçage rapide ou capture, bots Facile+).</div></div>';
 if(eventActive()){
  const pk=PROF.ev.id===EVENT.id?PROF.ev.pk:0;
  h+='<div class="evc"><b style="font-size:.9rem;letter-spacing:2px">🎃 ÉVÉNEMENT : '+EVENT.n.toUpperCase()+'</b><div style="margin:4px 0 8px;color:#e8c9a8">Ramasse les citrouilles cachées sur les cartes jusqu\'au '+EVENT.to.split('-').reverse().join('/')+'. Citrouilles : <b>'+pk+'</b></div>'+EVENT.goals.map(g=>'<span class="chip'+(pk>=g.n?' on':'')+'" style="margin-right:6px;display:inline-block">'+g.n+' → '+rewardText(g.r)+'</span>').join('')+'</div>';
 }
 h+='<div class="pg-h"><h3>'+SEASON.n.toUpperCase()+' — PALIER '+t+' / '+SEASON.tiers+'</h3><div>'+(PROF.bp.prem?'<span class="chip on">PASSE PREMIUM ACTIF</span>':'<span class="chip" id="bpBuy">Acheter le passe Premium — '+SEASON.price+' 🪙</span>')+'</div></div>';
 h+='<div class="bpc" style="flex:none;width:auto;margin-bottom:8px;text-align:left"><div class="rkb" style="width:100%"><i style="width:'+pct+'%;background:var(--accent)"></i></div><span style="color:var(--dim)">Prochain palier : '+(t>=SEASON.tiers?'max':PROF.bp.xp%SEASON.xpPer+' / '+SEASON.xpPer+' XP')+'</span></div><div class="bp">';
 for(let i=1;i<=SEASON.tiers;i++){
  const f=bpReward(i,false),p=bpReward(i,true),cf=PROF.bp.cf.includes(i),cp=PROF.bp.cp.includes(i),ok=i<=t;
  h+='<div class="bpc'+(i===t?' cur':'')+'"><b>'+i+'</b><div class="r">'+bpRewardText(f)+'</div><button data-f="'+i+'"'+(!ok||cf?' disabled':'')+'>'+(cf?'RÉCUPÉRÉ':ok?'RÉCUPÉRER':'VERROUILLÉ')+'</button><div class="r p" style="margin-top:8px">'+bpRewardText(p)+'</div><button data-p="'+i+'"'+(!ok||cp||!PROF.bp.prem?' disabled':'')+'>'+(cp?'RÉCUPÉRÉ':!PROF.bp.prem?'PREMIUM':ok?'RÉCUPÉRER':'VERROUILLÉ')+'</button></div>';
 }
 h+='</div><div class="pg-h"><h3>SUCCÈS — '+Object.keys(PROF.ach).length+' / '+ACH.length+'</h3></div><div class="agrid">'+ACH.map(a=>'<div class="ach'+(PROF.ach[a.id]?' on':'')+'"><b>'+(PROF.ach[a.id]?'🏆 ':'🔒 ')+a.n+'</b>'+a.d+'<br><small>+'+a.c+' 🪙</small></div>').join('')+'</div>';
 el.innerHTML=h;
 el.querySelectorAll('button[data-f]').forEach(b=>b.onclick=()=>{const r=bpClaim(+b.dataset.f,false);if(r){sfx('pickup');uiToast('Palier '+b.dataset.f+' : '+rewardText(r.r));}drawProgressTab();});
 el.querySelectorAll('button[data-p]').forEach(b=>b.onclick=()=>{const r=bpClaim(+b.dataset.p,true);if(r){sfx('pickup');uiToast(r.dup?'Doublon → pièces':bpRewardText(r.r));}drawProgressTab();});
 const buy=$('bpBuy');if(buy)buy.onclick=()=>{if(bpBuy()){sfx('pickup');uiToast('Passe Premium débloqué !');}else uiToast('Pièces insuffisantes');drawProgressTab();};
}
buildProgressTab();
document.querySelectorAll('.mtab[data-t="prog"]').forEach(t=>t.addEventListener('click',drawProgressTab));
