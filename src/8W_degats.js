/* =====================================================================
   DÉGÂTS : synchronisation en ligne, sons d'impact, interface
   - En ligne, le client qui tire envoie ce qu'il a touché (cible, zone,
     distance). L'hôte vérifie (cible vivante, distance, ligne de vue sur
     une position récente de la cible, cadence de l'arme) puis applique
     les dégâts et renvoie tout de suite une confirmation au tireur
     (dégâts réels, tête, bouclier, élimination).
   - Avant, l'hôte retirait le tir avec sa propre dispersion : le client
     voyait des touches qui ne comptaient pas (et l'inverse).
   - Les dégâts de chute du client sont transmis à l'hôte.
   - Sons : impact corps, tête (tintement de casque), élimination,
     bouclier, bris de bouclier, dégâts reçus.
   - Interface : marqueur de touche, chiffres de dégâts accrochés à la
     cible et cumulés, indicateurs de direction qui suivent le tireur,
     voile rouge proportionnel, barre de vie avec traînée blanche.
   ===================================================================== */
const DG={col:null,pend:null,batch:null,nums:new Map(),dirs:[],snd:{},combo:0,comboT:0,ghost:100,ghostT:0,hp0:0,sh0:0,histT:0,last:0};

/* ---------- styles et éléments ---------- */
(function dgInit(){
 const st=document.createElement('style');
 st.textContent=`
#hitm{display:none!important}
#dirs{display:none}
#dgHit{position:absolute;left:50%;top:50%;width:0;height:0;pointer-events:none;z-index:6}
#dgHit i{position:absolute;left:-1.5px;top:0;width:3px;height:11px;background:var(--c,#fff);border-radius:2px;box-shadow:0 0 3px rgba(0,0,0,.9),0 0 8px var(--g,rgba(255,255,255,.35));transform-origin:50% 0;opacity:0}
#dgHit i:nth-child(1){transform:rotate(45deg) translateY(var(--gap,7px))}
#dgHit i:nth-child(2){transform:rotate(135deg) translateY(var(--gap,7px))}
#dgHit i:nth-child(3){transform:rotate(225deg) translateY(var(--gap,7px))}
#dgHit i:nth-child(4){transform:rotate(315deg) translateY(var(--gap,7px))}
#dgHit.on i{animation:dgHitA var(--dur,.32s) ease-out forwards}
#dgHit.kill i{width:4px;left:-2px;height:15px}
#dgHit b{position:absolute;left:-22px;top:-22px;width:44px;height:44px;border-radius:50%;border:2px solid #ff3b47;opacity:0;box-shadow:0 0 10px #ff3b47}
#dgHit.kill.on b{animation:dgRing .45s ease-out forwards}
@keyframes dgHitA{0%{opacity:1;--gap:13px;filter:brightness(1.6)}18%{opacity:1;--gap:6px}70%{opacity:.9}100%{opacity:0;--gap:9px}}
@keyframes dgRing{0%{opacity:.95;transform:scale(.35)}100%{opacity:0;transform:scale(1.5)}}
@property --gap{syntax:'<length>';inherits:true;initial-value:7px}
#dgNums{position:fixed;inset:0;pointer-events:none;overflow:hidden;z-index:6}
#dgNums div{position:absolute;left:0;top:0;font:italic 900 22px Bahnschrift,'Arial Black',Arial,sans-serif;color:#fff;white-space:nowrap;
 -webkit-text-stroke:1px rgba(0,0,0,.85);text-shadow:0 2px 0 rgba(0,0,0,.55),0 0 10px rgba(0,0,0,.45);letter-spacing:.5px;will-change:transform,opacity}
#dgNums div.hs{color:#ffd23f;text-shadow:0 2px 0 rgba(0,0,0,.55),0 0 14px rgba(255,170,0,.75)}
#dgNums div.sh{color:#5fd6ff;text-shadow:0 2px 0 rgba(0,0,0,.55),0 0 12px rgba(40,170,255,.7)}
#dgNums div.kill{color:#ff4655;text-shadow:0 2px 0 rgba(0,0,0,.55),0 0 16px rgba(255,40,60,.85)}
#dgNums div small{font-size:.6em;margin-left:3px;vertical-align:.35em;-webkit-text-stroke:0}
#dgDirs{position:absolute;left:50%;top:50%;width:0;height:0;pointer-events:none;z-index:5}
#dgDirs svg{position:absolute;left:-170px;top:-170px;width:340px;height:340px;opacity:0;overflow:visible}
#dgHurt{position:absolute;inset:0;pointer-events:none;opacity:0;z-index:4;
 background:radial-gradient(ellipse at center,rgba(0,0,0,0) 48%,rgba(120,0,0,.35) 72%,rgba(170,0,0,.85) 100%)}
.vital .meter .dgGhost{position:absolute;left:0;top:0;bottom:0;background:#fff;opacity:.75;width:0}
.vital .meter i{position:relative;z-index:1}
`;
 document.head.appendChild(st);
 const hud=$('hud')||document.body;
 const h=document.createElement('div');h.id='dgHit';h.innerHTML='<i></i><i></i><i></i><i></i><b></b>';hud.appendChild(h);
 const n=document.createElement('div');n.id='dgNums';document.body.appendChild(n); // hors du HUD : il peut être mis à l'échelle, les chiffres suivent l'écran
 const d=document.createElement('div');d.id='dgDirs';hud.appendChild(d);
 const v=document.createElement('div');v.id='dgHurt';hud.appendChild(v);
 const m=$('hpm');if(m){const g=document.createElement('b');g.className='dgGhost';m.insertBefore(g,m.firstChild);}
 for(let i=0;i<6;i++){
  const s=document.createElementNS('http://www.w3.org/2000/svg','svg');s.setAttribute('viewBox','-170 -170 340 340');
  // arc rouge en dégradé + chevron vers l'extérieur
  s.innerHTML='<defs><linearGradient id="dgG'+i+'" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#ff2636" stop-opacity="0"/><stop offset=".5" stop-color="#ff2636"/><stop offset="1" stop-color="#ff2636" stop-opacity="0"/></linearGradient></defs>'+
   '<path d="M -56 -140 A 151 151 0 0 1 56 -140" fill="none" stroke="url(#dgG'+i+')" stroke-width="9" stroke-linecap="round" style="filter:drop-shadow(0 0 6px #ff0018)"/>'+
   '<path d="M -13 -152 L 0 -166 L 13 -152 Z" fill="#ff3442" style="filter:drop-shadow(0 0 4px #000)"/>';
  d.appendChild(s);DG.dirs.push({el:s,att:null,x:0,z:0,t:9,k:0});
 }
})();

/* ---------- interface : marqueur, chiffres, direction ---------- */
uiHit=function(zone,kill,shieldOnly){
 const h=$('dgHit');if(!h)return;
 const c=kill?'#ff3b47':shieldOnly?'#5fd6ff':zone==='h'?'#ffd23f':'#ffffff';
 h.style.setProperty('--c',c);h.style.setProperty('--g',kill?'rgba(255,40,60,.8)':zone==='h'?'rgba(255,190,40,.6)':'rgba(255,255,255,.35)');
 h.style.setProperty('--dur',kill?'.55s':zone==='h'?'.4s':'.3s');
 h.className=kill?'kill':'';void h.offsetWidth;h.className=(kill?'kill ':'')+'on';
};
// un chiffre par cible, cumulé tant que les touches s'enchaînent (fusil à pompe, rafales)
uiDmgNum=function(d,hs,shield,v,kill){
 if(DG.inHurt)return; // le chiffre est posé après coup avec les dégâts réellement infligés
 d=Math.round(d);if(!(d>0))return;
 const now=performance.now(),key=v?v.id:'c';let o=DG.nums.get(key);
 if(!o||now-o.tu>650||o.kill){
  if(o)DG.nums.set(key+'_'+now,o); // l'ancien chiffre finit de s'effacer
  const el=document.createElement('div');$('dgNums').appendChild(el);
  o={el,v,total:0,hs:false,sh:true,kill:false,t0:now,tu:now,ox:rand(-26,26),bump:0};
  DG.nums.set(key,o);
 }
 o.total+=d;o.hs=o.hs||!!hs;o.sh=o.sh&&!!shield;o.tu=now;o.bump=1;
 if(kill||(v&&v.hp<=0&&!v.downed&&!G.netClient))o.kill=true;
 dgNumDraw(o);
};
function dgNumDraw(o){
 o.el.className=o.kill?'kill':o.hs?'hs':o.sh?'sh':'';
 o.el.innerHTML=o.total+(o.kill?'<small>☠</small>':o.hs?'<small>✦</small>':'');
 o.size=Math.min(40,20+Math.sqrt(o.total)*1.5+(o.hs?4:0)+(o.kill?5:0));
}
// direction des dégâts reçus : l'indicateur suit la position du tireur pendant qu'on se retourne
uiDamage=function(att,dmg){
 if(dmg===undefined)dmg=Math.max(0,(DG.hp0-P.hp)+(DG.sh0-P.shield));
 if(!(dmg>0))dmg=12;
 const k=Math.min(1,.35+dmg/45);
 const v=$('dgHurt');if(v){v.style.transition='none';v.style.opacity=Math.min(.95,.25+dmg/50);void v.offsetWidth;v.style.transition='opacity .7s ease-out';v.style.opacity=0;}
 DG.ghostT=performance.now()+450;
 if(att&&att!==P){
  let s=DG.dirs.find(x=>x.att===att&&x.t<1.4)||DG.dirs.reduce((a,b)=>b.t>a.t?b:a);
  s.att=att;s.x=att.x;s.z=att.z;s.t=0;s.k=Math.max(s.t<1.4&&s.att===att?s.k:0,k);
 }
};
function dgFrame(){
 requestAnimationFrame(dgFrame);
 const now=performance.now(),dt=Math.min(.1,(now-(DG.last||now))/1000);DG.last=now;
 if(!G.running||!P){for(const [k,o] of DG.nums){o.el.remove();DG.nums.delete(k);}for(const s of DG.dirs){s.el.style.opacity=0;s.t=9;}return;}
 // chiffres de dégâts accrochés au-dessus de la cible
 const W2=innerWidth/2,H2=innerHeight/2,vv=dgFrame.v||(dgFrame.v=new THREE.Vector3()),fw=camera.getWorldDirection(dgFrame.f||(dgFrame.f=new THREE.Vector3())); // derrière la caméra = caché
 for(const [k,o] of DG.nums){
  const age=(now-o.tu)/1000,life=(now-o.t0)/1000;
  if(age>1.05){o.el.remove();DG.nums.delete(k);continue;}
  let x=W2,y=H2-60;
  if(o.v){vv.set(o.v.x,o.v.y+(o.v.crouch?1.65:2.05),o.v.z);if(vv.clone().sub(camera.position).dot(fw)<.2){o.el.style.opacity=0;continue;}vv.project(camera);x=(vv.x+1)*W2;y=(1-vv.y)*H2;}
  o.bump=Math.max(0,o.bump-dt*7);
  const rise=Math.min(life,1.6)*26+age*30,sc=(1+o.bump*.45)*(life<.08?1.6-life*7.5:1),op=age<.7?1:1-(age-.7)/.35;
  o.el.style.fontSize=o.size+'px';o.el.style.opacity=op;
  o.el.style.transform='translate('+(x+o.ox-o.size*.6).toFixed(1)+'px,'+(y-rise-o.size).toFixed(1)+'px) scale('+sc.toFixed(3)+')';
 }
 // indicateurs de direction
 for(const s of DG.dirs){
  s.t+=dt;if(s.t>1.6){s.el.style.opacity=0;continue;}
  if(s.att&&s.att.alive){s.x=s.att.x;s.z=s.att.z;}
  const a=Math.atan2(-(s.x-P.x),-(s.z-P.z)),rel=angDiff(P.yaw,a);
  s.el.style.transform='rotate('+(-rel).toFixed(3)+'rad)';
  s.el.style.opacity=(s.k*(s.t<1?1:1-(s.t-1)/.6)).toFixed(3);
 }
 // barre de vie : traînée blanche qui rattrape la vie restante
 const m=$('hpm'),g=m&&m.querySelector('.dgGhost');
 if(g){const hp=clamp(P.hp,0,100);if(hp>=DG.ghost||!P.alive)DG.ghost=hp;else if(now>DG.ghostT)DG.ghost=Math.max(hp,DG.ghost-dt*70);g.style.width=DG.ghost+'%';}
}
requestAnimationFrame(dgFrame);

/* ---------- sons ---------- */
const DG_SND={hit:1,hs:1,kill:1,killhs:1,shield:1,shieldbreak:1,dmg:1,bodyimp:1};
const _sfxDg=sfx;
sfx=function(type,x,z,vol,extra){
 if(!DG_SND[type]||!AC)return _sfxDg(type,x,z,vol,extra);
 const now=performance.now();
 // plombs du fusil à pompe : un seul son par salve
 if((type==='hit'||type==='hs'||type==='shield')&&now-(DG.snd.hit||0)<45&&!(type==='hs'&&DG.snd.last!=='hs'))return;
 if(type==='hit'||type==='hs'||type==='shield'){DG.snd.hit=now;DG.snd.last=type;}
 if(typeof subtitle==='function')subtitle(type,x,z);
 vol=vol===undefined?1:vol;let pan=0,wet=0;
 if(x!==undefined){const p=panOf(x,z);pan=p.pan;vol*=Math.pow(clamp(1-p.d/45,0,1),1.5);if(vol<.01)return;wet=clamp(p.d/40,.05,.5);}
 // touches enchaînées : légère montée de hauteur (sensation de « combo »)
 if(type==='hit'||type==='hs'){DG.combo=now-DG.comboT<420?Math.min(DG.combo+1,8):0;DG.comboT=now;}
 const up=1+DG.combo*.025,r=()=>.94+Math.random()*.12;
 switch(type){
  case 'hit': // impact chair : coup sourd + claque + petit clic net
   tn(185*r(),.09,'sine',.55*vol,0,70);
   nz(.07,1300*r(),'bandpass',.6*vol,0,.04,1.3);
   nz(.016,5600,'highpass',.3*vol,0);
   tn(2650*up,.035,'triangle',.11*vol,0,2100*up);
   break;
  case 'hs': // tête : tintement de casque métallique + craquement
   tn(160,.11,'sine',.5*vol,0,60);
   nz(.04,6500,'highpass',.45*vol,0,.05);
   nz(.07,1900,'bandpass',.4*vol,0,.04,1.6);
   [[3150,.34,.2],[4710,.24,.12],[2140,.42,.09],[6280,.12,.05]].forEach(([f,d,a])=>tn(f*up,d,'sine',a*vol,0,null,.12));
   break;
  case 'kill': // élimination : gros impact + carillon qui monte
   tn(92,.3,'sine',.75*vol,0,38);
   nz(.14,650,'lowpass',.5*vol,0,.1);
   nz(.03,4500,'highpass',.3*vol,0);
   tn(784,.16,'triangle',.22*vol,0,null,.25,.03);
   tn(1175,.32,'triangle',.24*vol,0,null,.3,.1);
   tn(2350,.38,'sine',.08*vol,0,null,.3,.1);
   break;
  case 'killhs': // élimination à la tête : version plus brillante
   tn(88,.32,'sine',.8*vol,0,36);
   nz(.16,700,'lowpass',.5*vol,0,.1);
   nz(.05,7000,'highpass',.4*vol,0,.1);
   [[3150,.4,.16],[4710,.3,.1]].forEach(([f,d,a])=>tn(f,d,'sine',a*vol,0,null,.15));
   tn(880,.14,'triangle',.22*vol,0,null,.25,.05);
   tn(1319,.2,'triangle',.24*vol,0,null,.3,.12);
   tn(1760,.42,'triangle',.22*vol,0,null,.35,.19);
   break;
  case 'shield': // bouclier : impact d'énergie
   tn(1500*r(),.13,'sine',.26*vol,0,650);
   nz(.09,3600,'bandpass',.32*vol,0,.06,4);
   tn(3100,.05,'square',.04*vol,0,2400);
   break;
  case 'shieldbreak': // bris de bouclier : verre qui éclate
   nz(.38,4200,'highpass',.55*vol,0,.25);
   tn(620,.32,'sawtooth',.16*vol,0,110,.1);
   for(let i=0;i<7;i++)tn(2400+Math.random()*4200,.09+Math.random()*.12,'sine',.08*vol,(Math.random()-.5)*.6,null,.2,Math.random()*.14);
   break;
  case 'dmg': // dégâts reçus : choc grave et étouffé
   tn(86*r(),.26,'sine',.85*vol,0,36);
   nz(.22,480,'lowpass',.6*vol,0,.05);
   nz(.05,1500,'bandpass',.25*vol,0,0,1.2);
   tn(52,.35,'sine',.35*vol,0,30,0,.05);
   break;
  case 'bodyimp': // impact entendu au loin (bots qui se touchent)
   nz(.06,1100*r(),'bandpass',.5*vol,pan,wet,1.4);tn(150*r(),.07,'sine',.3*vol,pan,70,wet);
   break;
 }
};

/* ---------- dégâts : hôte et solo ---------- */
const _hurtDg=hurt;
hurt=function(v,att,w,zone,dist,raw){
 if(!v)return;
 if(NET.role==='client'&&G.netClient){
  // client : on note ce que le tir a touché, l'hôte décidera
  if(DG.col&&att===P&&v!==P&&v.alive&&DG.col.length<16)DG.col.push([v.id,zone,+(+dist||0).toFixed(2),w&&w.melee&&raw>w.dmg?1:0]);
  return;
 }
 // tir d'un joueur distant qui a envoyé ses touches : la simulation de l'hôte ne compte pas
 if(att&&att.dgNoDmg){const cw=curWi(att);if(cw&&W[cw.k]===w)return;}
 const hp0=v.hp,sh0=v.shield,al=v.alive&&!v.downed;
 if(v.isPlayer){DG.hp0=hp0;DG.sh0=sh0;}
 DG.inHurt=true;try{_hurtDg(v,att,w,zone,dist,raw);}finally{DG.inHurt=false;}
 const d=Math.max(0,hp0-Math.max(0,v.hp))+Math.max(0,sh0-v.shield);
 if(!(d>0))return;
 const kill=al&&!v.alive,shOnly=v.hp===hp0;
 if(att&&att.isPlayer&&att!==v)uiDmgNum(d,zone==='h',shOnly,v,kill);
 if(att&&att.remote&&att!==v)dgConfirm(att,v,d,zone,kill,shOnly);
 if(v.remote){for(let i=NET.ev.length-1;i>=0;i--){const e=NET.ev[i];if(e.t==='hurt'&&e.to===v.id&&e.d===undefined){e.d=Math.round(d);break;}}}
 // impact entendu quand deux bots s'affrontent près du joueur
 if(att&&!att.isPlayer&&!v.isPlayer&&att!==v&&!v.zombie)sfx('bodyimp',v.x,v.z,.6);
};
function dgConfirm(att,v,d,zone,kill,shOnly){
 if(DG.batch){
  let b=DG.batch.get(v.id);if(!b){b={to:att.remote,v:v.id,d:0,h:0,k:0,s:1};DG.batch.set(v.id,b);}
  b.d+=d;if(zone==='h')b.h=1;if(kill)b.k=1;if(!shOnly)b.s=0;return;
 }
 netSend({t:'hc',v:v.id,d:Math.round(d),z:zone,k:kill?1:0,s:shOnly?1:0,p:0},att.remote);
}
// vérifie une touche annoncée par un client (positions récentes de la cible pour compenser la latence)
function dgValid(e,v,zone,dist,w){
 if(!v||v===e||!v.alive||v.invuln>0||v.team===e.team)return false;
 if(zone!=='h'&&zone!=='b'&&zone!=='l')return false;
 if(!(dist>=0)||dist>(w.melee?3.5:172))return false;
 const ey=e.y+eyeOf(e),cands=[v].concat(v.dgHist||[]);
 for(const p of cands){
  const ty=p.y+(zone==='h'?1.6:zone==='l'?.45:1.1)*(v.crouch?.8:1),dx=p.x-e.x,dy=ty-ey,dz=p.z-e.z,L=Math.hypot(dx,dy,dz);
  if(Math.abs(L-dist)>(w.melee?1.6:3+L*.06))continue;
  if(L<.05)return true;
  if(rayWall(e.x,ey,e.z,dx/L,dy/L,dz/L,L)>=L-.8)return true;
 }
 return false;
}
function dgApplyHits(e,hits){
 const wi=curWi(e),w=wi&&W[wi.k];if(!w||!e.alive)return;
 // cadence : pas plus de touches que l'arme ne peut tirer de balles (petite réserve pour la gigue réseau)
 const now=performance.now(),per=60000/w.rpm/(e.perks&&e.perks.dtap?1.33:1);
 e.dgBud=Math.min(4,(e.dgBud===undefined?4:e.dgBud)+(now-(e.dgBudT||now))/per);e.dgBudT=now;
 if(e.dgBud<.9)return;e.dgBud-=1;
 const max=w.melee?1:(w.pel||1),dmm=w.melee?1:attMods(e,wi.k).dmg;
 DG.batch=new Map();
 try{
  for(const h of hits.slice(0,max)){
   if(!Array.isArray(h))continue;
   const v=ents.find(x=>x.id===h[0]),zone=h[1],dist=+h[2];
   if(!dgValid(e,v,zone,dist,w))continue;
   let raw=w.dmg*dmm;
   if(w.melee&&h[3]){const dr=dirOf(e.yaw,e.pitch),back=(-Math.sin(v.yaw)*dr[0]-Math.cos(v.yaw)*dr[2])>.2;if(back)raw=100;}
   const dx=v.x-e.x,dz=v.z-e.z,L=Math.hypot(dx,dz)||1,hy=v.y+(zone==='h'?1.6:1.1);
   if(!w.melee)fxBlood(v.x,hy,v.z,[dx/L,0,dz/L],zone==='h'?7:4,zone==='h');
   hurt(v,e,w,zone,dist,raw);
   if(w.melee)sfx('knifehit',v.x,v.z);
  }
 }finally{
  for(const b of DG.batch.values())netSend({t:'hc',v:b.v,d:Math.round(b.d),z:b.h?'h':'b',k:b.k,s:b.s,p:1},b.to);
  DG.batch=null;
 }
}
const _netShootDg=netShoot;
netShoot=function(e,yaw,pitch,hits){
 if(!Array.isArray(hits))return _netShootDg(e,yaw,pitch); // ancien client : l'hôte simule le tir
 const w=W[curWi(e).k];
 if(w&&w.wonder)return _netShootDg(e,yaw,pitch);
 e.dgNoDmg=true;try{_netShootDg(e,yaw,pitch);}finally{e.dgNoDmg=false;}
 dgApplyHits(e,hits);
};
// positions récentes de chaque combattant (~0,4 s) pour valider les touches malgré la latence
const _netHostTickDg=netHostTick;
netHostTick=function(dt){
 DG.histT-=dt;
 if(DG.histT<=0&&NET.players.size){DG.histT=1/15;for(const e of ents){if(!e.alive){e.dgHist=null;continue;}const h=e.dgHist||(e.dgHist=[]);h.unshift({x:e.x,y:e.y,z:e.z});if(h.length>6)h.pop();}}
 _netHostTickDg(dt);
};
// chute d'un joueur distant : l'hôte applique les dégâts
function dgFallHost(e,d){if(e&&e.alive)selfDamage(e,clamp(d|0,0,200));}

/* ---------- dégâts : client ---------- */
const _shootDg=shoot;
shoot=function(e){
 if(!(NET.role==='client'&&G.netClient&&e&&e.isPlayer))return _shootDg(e);
 const wi=curWi(e),w=wi&&W[wi.k];
 DG.col=w&&!w.wonder?[]:null;DG.pend=null;DG.inShot=true;
 let r;
 try{r=_shootDg(e);}finally{
  DG.inShot=false;const hits=DG.col;DG.col=null;
  if(DG.pend){if(hits)DG.pend.h=hits;netSend(DG.pend,'host');DG.pend=null;}
  // retour immédiat (prédiction) ; les chiffres arrivent avec la confirmation de l'hôte
  if(hits&&hits.length){const hs=hits.some(h=>h[1]==='h');uiHit(hs?'h':'b',false,false);sfx(hs?'hs':'hit');}
 }
 return r;
};
const _netShotDg=netShot;
netShot=function(e){
 if(!DG.inShot)return _netShotDg(e);
 DG.pend={t:'shot',yaw:e.yaw+(e.punchY||0)*RAD,pitch:e.pitch+(e.punchP||0)*RAD};
};
const _selfDamageDg=selfDamage;
selfDamage=function(e,d){
 if(NET.role==='client'&&G.netClient&&e===P){if(e.invuln>0||!e.alive)return;netSend({t:'fall',d:Math.round(d)},'host');uiDamage(null,d);sfx('dmg');return;}
 if(e===P){DG.hp0=P.hp;DG.sh0=P.shield;}
 _selfDamageDg(e,d);
};
const _netClientMsgDg=netClientMsg;
netClientMsg=function(m){
 if(m&&m.t==='hc'){
  if(!G.running)return;
  const v=netById(m.v);
  uiDmgNum(m.d,m.z==='h',!!m.s,v&&v!==P?v:null,!!m.k);
  if(m.k){uiHit(m.z,true,false);sfx(m.z==='h'?'killhs':'kill');}
  else if(!m.p){uiHit(m.z,false,!!m.s);sfx(m.s?'shield':m.z==='h'?'hs':'hit');}
  return;
 }
 _netClientMsgDg(m);
};
const _netClientEventDg=netClientEvent;
netClientEvent=function(ev){
 if(ev&&ev.t==='hurt'){
  if(ev.to===NET.myEnt){const a=netById(ev.f);uiDamage(a&&a!==P?a:null,ev.d);sfx('dmg');G.shake=Math.max(G.shake,.15+Math.min(.25,(ev.d||20)/200));}
  return;
 }
 _netClientEventDg(ev);
};
