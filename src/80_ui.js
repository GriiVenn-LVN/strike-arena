/* =====================================================================
   INTERFACE EN JEU : HUD, radar, scoreboard, boutique, entrées, overlays
   ===================================================================== */
const hudEl=$('hud');
let toastTO=0,bannerTO=0,killTO=0;
(function(){const t=document.createElement('div');t.id='toast';t.style.cssText='position:absolute;left:50%;top:7.8rem;transform:translateX(-50%);font-size:.85rem;letter-spacing:2px;font-weight:700;color:#fff;background:rgba(9,13,21,.85);padding:.35rem 1.1rem;border-left:3px solid var(--gold);opacity:0;transition:opacity .3s;text-transform:uppercase';hudEl.appendChild(t);})();
function uiToast(txt){const t=$('toast');t.textContent=txt;t.style.opacity=1;clearTimeout(toastTO);toastTO=setTimeout(()=>t.style.opacity=0,2400);}
function uiBanner(title,sub,ms,col){
 if(NET.role==='host'&&!NET.mute)netEvent({t:'ban',a:[title,sub||'',ms||2000,col||'']});
 const b=$('banner');b.innerHTML=title+(sub?'<small>'+sub+'</small>':'');b.style.color=col||'#fff';b.className='';void b.offsetWidth;b.className='on';
 clearTimeout(bannerTO);bannerTO=setTimeout(()=>b.className='',ms||2000);
}
function uiFeed(a,v,w,hs){
 const d=document.createElement('div');if(a.isPlayer||v.isPlayer)d.className='me';
 const col=e=>G.mode==='bomb'||G.mode==='tdm'?TEAMCSS[e.team]:PALETTE[e.col];
 d.style.borderRightColor=col(a);
 const wk=Object.keys(W).find(k=>W[k]===w);
 d.innerHTML='<span style="color:'+col(a)+'">'+(a===v?'☠':a.name)+'</span>'+(wk?'<img src="'+weaponIcon(wk,0)+'">':'<span>['+w.n+']</span>')+(hs?'<span style="color:#ff5050">★</span>':'')+'<span style="color:'+col(v)+'">'+v.name+'</span>';
 const f=$('feed');f.appendChild(d);while(f.children.length>6)f.removeChild(f.firstChild);setTimeout(()=>d.remove(),7000);
}
function uiHit(zone,kill,shieldOnly){
 const h=$('hitm');h.className='on'+(kill?' kill':zone==='h'?' hs':'');void h.offsetWidth;
 if(shieldOnly)h.style.filter='hue-rotate(180deg)';else h.style.filter='';
 setTimeout(()=>{h.className=kill?'kill':zone==='h'?'hs':'';},kill?160:90);
}
function uiDmgNum(d,hs,shield,v){
 const n=document.createElement('div');n.textContent=Math.round(d);if(hs)n.className='hs';if(shield)n.style.color='#5ad8ff';
 n.style.setProperty('--x',(rand(-40,40))+'px');n.style.left='0';n.style.top=(-30+rand(-10,10))+'px';
 const c=$('dmgnums');c.appendChild(n);setTimeout(()=>n.remove(),900);
}
let dirIdx=0;
(function(){const c=$('dirs');for(let i=0;i<5;i++){c.appendChild(document.createElement('i'));}})();
function uiDamage(att){
 const v=$('vig');v.className='on';void v.offsetWidth;setTimeout(()=>v.className='',70);
 if(att&&att!==P){
  const a=Math.atan2(-(att.x-P.x),-(att.z-P.z));let rel=angDiff(P.yaw,a);
  const i=$('dirs').children[dirIdx++%5];i.style.transition='none';i.style.opacity=1;i.style.transform='rotate('+(-rel)+'rad)';
  void i.offsetWidth;i.style.transition='opacity 1.1s ease-out';i.style.opacity=0;
 }
}
function uiKillMsg(v,hs,streak){
 const m=$('killmsg'),st=['','','DOUBLE ÉLIMINATION','TRIPLE ÉLIMINATION','QUADRUPLE ÉLIMINATION','SÉRIE DE '+streak+' !'][Math.min(streak,5)];
 m.innerHTML='ÉLIMINÉ <b>'+v.name+'</b>'+(hs?' ★':'')+(st&&G.mode!=='bomb'?'<br><span style="color:#ff5050;font-size:.9em">'+st+'</span>':'');m.className='on';
 clearTimeout(killTO);killTO=setTimeout(()=>m.className='',1800);
 if(G.mode==='bomb'||true){const gain=G.mode==='bomb'?(curW(P).kill||300):0;if(gain>0)uiMoney(gain);}
}
function uiMoney(g){const m=$('money'),s=document.createElement('span');s.className='gain';s.textContent='+$'+g;m.appendChild(s);m.classList.remove('up');void m.offsetWidth;m.classList.add('up');setTimeout(()=>s.remove(),2400);}
function uiDeath(att){
 const m=$('killmsg');m.innerHTML=att&&att!==P?'ÉLIMINÉ PAR <b style="color:#ff6b6b">'+att.name+'</b>':'VOUS ÊTES MORT';m.className='on';clearTimeout(killTO);killTO=setTimeout(()=>m.className='',3000);
 $('scope').style.display='none';
}
function uiRespawned(){$('respawn').style.display='none';$('fadefx').style.opacity=0;}
function uiFlashBlind(d){P.blindT=Math.max(P.blindT,d);$('flashfx').style.opacity=1;}
function uiRoundStart(){$('sb').style.display='none';$('feed').innerHTML='';}
function uiRoundEnd(){scoreboard();$('sb').style.display='block';}
function uiMatchStart(){
 $('menu').classList.remove('show');$('over').classList.remove('show');$('pause').classList.remove('show');hudEl.classList.add('show');$('loading').style.display='none';
 $('feed').innerHTML='';$('sb').style.display='none';
 setHTML('bTitle',isDM()?'ARMURERIE <span style="font-size:.5em;color:var(--good);letter-spacing:3px">GRATUITE</span>':'BOUTIQUE');
 lockMouse();
}
function uiMatchOver(){
 hudEl.classList.remove('show');$('sb').style.display='none';
 let win=false,title='',sub='';
 if(G.variant==='train'){const acc=MS.shots?Math.round(MS.hits/MS.shots*100):0;win=false; // pas une victoire : ne gonfle plus le taux de victoire ni l'XP
 title='ENTRAÎNEMENT';sub='Score '+TR.score+'  •  précision '+acc+' %  •  série max '+TR.best;}
 else if(G.variant==='zombies'){win=G.winner===0;title=win?'VICTOIRE':'DÉFAITE';sub='Vague '+Z.wave+' / '+G.limit;}
 else if(G.variant==='br'){win=G.winner===P;title=win?'VICTOIRE ROYALE':(G.winner?G.winner.name+' GAGNE':'ÉGALITÉ');sub='Éliminations : '+P.kills;}
 else if(G.mode==='bomb'){win=G.score[P.team]>G.score[1-P.team];title=win?'VICTOIRE':'DÉFAITE';sub=G.score[P.team]+'  –  '+G.score[1-P.team];}
 else if(G.mode==='tdm'){win=G.winner===P.team;title=G.winner===-1?'ÉGALITÉ':win?'VICTOIRE':'DÉFAITE';sub=G.score[P.team]+'  –  '+G.score[1-P.team];}
 else{win=G.winner===P;title=win?'VICTOIRE':(G.winner?G.winner.name+' GAGNE':'ÉGALITÉ');sub=P.kills+' éliminations';}
 $('oT').textContent=title;$('oT').style.color=win||G.variant==='train'?'#7dff9f':G.winner===-1?'#ffd75e':'#ff6b6b';
 $('oS').textContent=sub+'   •   '+MODE().n+'   •   '+MAP.n+'   •   '+DIFFS[cfg.diff].n;
 $('oTable').innerHTML=scoreTable(true);showMatchRewards(win);
 $('over').classList.add('show');
}
/* ---------- scoreboard ---------- */
function scoreTable(final){
 const row=e=>{const kd=e.deaths?(e.kills/e.deaths).toFixed(2):e.kills.toFixed(2),hsr=e.kills?Math.round(e.hsKills/e.kills*100)+'%':'-';
  return '<tr style="opacity:'+(e.alive||final?1:.45)+';'+(e.isPlayer?'background:#ffffff14':'')+'"><td>'+e.name+(e.isPlayer&&e.name!=='Vous'?' (vous)':'')+(e.isPlayer?''+(titleName()?' ['+titleName()+']':''):'')+'</td><td>'+e.kills+'</td><td>'+e.deaths+'</td><td>'+kd+'</td><td>'+hsr+'</td><td>'+e.dmg+'</td><td>'+(G.mode==='bomb'&&(e.team===P.team||final)?'$'+e.money:G.mode==='gg'?(e.ggLevel+1):'-')+'</td></tr>';};
 const head='<tr><th>Joueur</th><th>K</th><th>D</th><th>K/D</th><th>HS</th><th>Dégâts</th><th>'+(G.mode==='gg'?'Niv.':'$')+'</th></tr>';
 if(MODE().team){
  const mk=team=>'<h4 style="color:'+TEAMCSS[team]+'"><span>'+(team===0?'ATTAQUANTS':'DÉFENSEURS')+'</span><span>'+G.score[team]+'</span></h4><table>'+head+ents.filter(e=>e.team===team&&!e.zombie&&!e.dummy).sort((a,b)=>b.kills-a.kills).map(row).join('')+'</table>';
  return mk(P.team)+(G.variant==='zombies'?'':mk(1-P.team)); // en Zombies, pas d'équipe adverse à lister
 }
 return '<table>'+head+ents.filter(e=>!e.dummy&&!e.zombie).sort((a,b)=>(b.ggLevel-a.ggLevel)||(b.kills-a.kills)).map(row).join('')+'</table>';
}
function scoreboard(){$('sb').innerHTML=scoreTable(false);}
/* ---------- viseur ---------- */
function drawCrosshair(c,cx,cy,gap){
 const x=cfg.xh;c.lineCap='butt';
 const segs=[[0,-1],[0,1],[-1,0],[1,0]];
 const draw=(w,col)=>{c.strokeStyle=col;c.lineWidth=w;for(const [dx,dy] of segs){if(x.len<=0)break;c.beginPath();c.moveTo(cx+dx*gap,cy+dy*gap);c.lineTo(cx+dx*(gap+x.len),cy+dy*(gap+x.len));c.stroke();}};
 if(x.out)draw(x.th+2,'rgba(0,0,0,.75)');draw(x.th,x.c);
 if(x.dot){if(x.out){c.fillStyle='rgba(0,0,0,.75)';c.fillRect(cx-x.th/2-1,cy-x.th/2-1,x.th+2,x.th+2);}c.fillStyle=x.c;c.fillRect(cx-x.th/2,cy-x.th/2,x.th,x.th);}
}
const XH_OFF=true;
const xhC=$('xh').getContext('2d');
function updateCrosshair(){
 const c=xhC;c.clearRect(0,0,220,220);
 // viseur de hanche désactivé (demande de Noa) : seuls les viseurs d'arme et les lunettes servent à viser
 if(XH_OFF||!P.alive||P.scoped||P.emote||G.state==='cine')return;
 const w=curW(P),sp=spreadOf(P,w),gap=clamp(cfg.xh.gap+sp*(innerHeight/55)+Math.abs(P.punchP)*2.5,2,80);
 drawCrosshair(c,110,110,gap*(1-.5*P.ads));
}
/* ---------- radar ---------- */
const radarCv=$('radar'),radarC=radarCv.getContext('2d');let radarMap=null;
function buildRadarMap(){
 const cv=document.createElement('canvas');cv.width=cv.height=N*8;const c=cv.getContext('2d');
 c.fillStyle='rgba(70,85,110,.55)';c.fillRect(0,0,N*8,N*8);
 const col=[null,'#0a0e15','#3a3f4a','#161c28','#8a97aa','#55402a','#6d8fb5','#2a3340','#0a0e15','#2a3340'];
 for(let z=0;z<N;z++)for(let x=0;x<N;x++){
  const i=z*N+x,t=G_TYPE[i];
  if(G_RAMP[i]){c.fillStyle='#caa85a';c.fillRect(x*8,z*8,8,8);continue;}
  if(G_CEIL[i]<90&&!t){c.fillStyle='rgba(0,0,0,.25)';c.fillRect(x*8,z*8,8,8);}
  if(!t)continue;
  if(t===TY.PLAT){c.fillStyle='#6d8fb5';c.fillRect(x*8,z*8,8,8);continue;}
  c.fillStyle=(t===TY.LOW||t===TY.BARREL||t===TY.CRATE)?'#566175':'#05080d';c.fillRect(x*8,z*8,8,8);
 }
 c.font='bold 44px Arial';c.fillStyle='rgba(255,215,94,.7)';c.textAlign='center';c.textBaseline='middle';
 for(const s of MAP.sites)c.fillText(s.n,s.x*4,s.z*4);
 radarMap=cv;
}
function drawRadar(){
 const c=radarC,W2=260,sc=4.2,src=!P.alive&&G.spec?G.spec:P;
 c.clearRect(0,0,W2,W2);c.save();c.beginPath();c.arc(130,130,127,0,TAU);c.clip();
 const cy=Math.cos(src.yaw),sy=Math.sin(src.yaw),a=sc*cy,b=sc*sy,cc2=-sc*sy,d=sc*cy,e=130-(a*src.x+cc2*src.z),f=130-(b*src.x+d*src.z);
 if(radarMap){c.setTransform(a,b,cc2,d,e,f);c.drawImage(radarMap,0,0,N*S,N*S);c.setTransform(1,0,0,1,0,0);}
 const pt=(x,z)=>[a*x+cc2*z+e,b*x+d*z+f];
 // cône de vision
 c.fillStyle='rgba(255,255,255,.1)';c.beginPath();c.moveTo(130,130);c.arc(130,130,70,-Math.PI/2-.7,-Math.PI/2+.7);c.closePath();c.fill();
 const dot=(x,z,col,r,yaw,ring)=>{const p=pt(x,z);c.fillStyle=col;c.beginPath();c.arc(p[0],p[1],r,0,TAU);c.fill();if(ring){c.strokeStyle='#fff';c.lineWidth=1.5;c.stroke();}
  if(yaw!==undefined){const ang=yaw-src.yaw;c.strokeStyle=col;c.lineWidth=2.5;c.beginPath();c.moveTo(p[0],p[1]);c.lineTo(p[0]-Math.sin(ang)*14,p[1]-Math.cos(ang)*14);c.stroke();}};
 for(const o of ents){
  if(!o.alive||o===src)continue;
  const friendly=(G.mode==='bomb'||G.mode==='tdm')&&o.team===src.team;
  if(friendly)dot(o.x,o.z,TEAMCSS[o.team],5.5,o.yaw);
  else if(o.spotT>G.t)dot(o.x,o.z,'#ff2a2a',6,undefined,true);
 }
 for(const p of pickups)if(p.on)dot(p.x,p.z,p.type==='shield'?'#31c8ff':p.type==='health'?'#ff4a5a':'#ffd24a',3.5);
 if(G.mode==='bomb'&&(BM.state==='planted'||BM.state==='dropped')){if(BM.state==='dropped'||Math.floor(G.t*3)%2)dot(BM.x,BM.z,'#ff9a00',7,undefined,true);}
 variantRadar(c,pt);
 c.restore();
 c.fillStyle='#fff';c.beginPath();c.moveTo(130,118);c.lineTo(124,136);c.lineTo(136,136);c.closePath();c.fill();
}
/* ---------- HUD ---------- */
const fmt=s=>{s=Math.max(0,Math.ceil(s));return Math.floor(s/60)+':'+String(s%60).padStart(2,'0');};
let lastWk='',iconCache={},fpsT=0,fpsN=0,hudAcc=0;
function weaponImg(k){const sk=cfg.skins[k]||0,key=k+':'+sk;return iconCache[key]||(iconCache[key]=weaponIcon(k,sk));}
function updateHUD(dt,t){
 const src=!P.alive&&G.spec?G.spec:P,isP=src===P;
 const wi=curWi(src),w=W[wi.k];
 // vitaux
 const hp=Math.max(0,Math.ceil(src.hp));
 setText('hpb',hp);$('hpb').classList.toggle('low',hp>0&&hp<30);
 $('hpm').firstElementChild.style.width=hp+'%';
 const sh=Math.ceil(src.shield),ar=Math.ceil(src.armor);
 const val=sh>0?sh:ar;
 setText('arb',val);
 const arm=$('arm').firstElementChild;arm.style.width=(sh>0?sh/SHIELDMAX*100:ar)+'%';arm.style.background=sh>0?'linear-gradient(90deg,#16b8ff,#9af0ff)':'linear-gradient(90deg,#4aa3ff,#9ad0ff)';
 $('arv').firstElementChild.textContent=sh>0?'🛡':'⛨';
 $('lowhp').style.display=hp>0&&hp<30&&P.alive?'block':'none';
 setHTML('money',(G.mode==='bomb'?'$'+P.money:'')+'');
 // arme
 if(wi.k!==lastWk||true){const im=$('wicon'),u=weaponImg(wi.k);if(im._u!==u){im._u=u;im.src=u;}lastWk=wi.k;}
 setText('wname',w.n);
 setText('ammo',w.melee?'∞':wi.mag);setText('ammo2',w.melee?'':' / '+wi.res);
 $('ammo').classList.toggle('low',!w.melee&&wi.mag<=w.mag*.25);
 if(!w.melee&&w.mag<=40){const pips=Array.from({length:w.mag},(_,i)=>'<i style="'+(i<wi.mag?'':'opacity:.15')+'"></i>').join('');setHTML('pips',pips);}else setHTML('pips','');
 const sl=$('slots');let sh2='';
 for(const [kk,lab] of [['p','1'],['s','2'],['k','3']]){const ww=src.wp[kk];if(!ww)continue;sh2+='<div class="'+(src.cur===kk?'on':'')+'">'+lab+' <img src="'+weaponImg(ww.k)+'"></div>';}
 setHTML('slots',sh2);
 setText('nades',(src.nade.f?'●G ':'○G ')+(src.nade.fl?'●F×'+src.nade.fl+' ':'○F ')+(src.nade.sm?'●H':'○H')+(src.kit?'   ✚ KIT':''));
 // haut
 const mode=G.mode;let L='',Rr='',tm='',tl='';
 if(mode==='bomb'||mode==='tdm'){
  const mine=P.team,A=ents.filter(e=>e.team===mine&&e.alive).length,B=ents.filter(e=>e.team!==mine&&e.alive).length;
  L=G.score[mine];Rr=G.score[1-mine];setText('aliveL',A+' en vie');setText('aliveR',B+' en vie');
  $('top').children[0].style.borderBottomColor=TEAMCSS[mine];$('top').children[2].style.borderBottomColor=TEAMCSS[1-mine];
  if(mode==='bomb'){tm=G.state==='freeze'?G.timer:BM.state==='planted'?BM.timer:G.timer;tl='MANCHE '+G.round+' / '+(G.limit*2-1);}
  else{tm=G.timeLeft;tl='PREMIER À '+G.limit;}
 }else if(mode==='ffa'){
  const top=ents.filter(e=>e!==P).sort((a,b)=>b.kills-a.kills)[0];L=P.kills;Rr=top?top.kills:0;setText('aliveL','VOUS');setText('aliveR',top?top.name:'');tm=G.timeLeft;tl='PREMIER À '+G.limit;
  $('top').children[0].style.borderBottomColor='#ffb938';$('top').children[2].style.borderBottomColor='#888';
 }else{
  const top=ents.filter(e=>e!==P).sort((a,b)=>b.ggLevel-a.ggLevel)[0];L=(P.ggLevel+1)+'/'+GG_LADDER.length;Rr=top?(top.ggLevel+1):0;setText('aliveL','VOUS');setText('aliveR',top?top.name:'');tm=G.timeLeft;tl='COURSE AUX ARMES';
  $('top').children[0].style.borderBottomColor='#7dff9f';$('top').children[2].style.borderBottomColor='#888';
 }
 const vh=variantHud();if(vh){L=vh.L;Rr=vh.R;tm=vh.tm;tl=vh.tl;setText('aliveL',vh.aL||'');setText('aliveR',vh.aR||'');}
 setText('sL',L);setText('sR',Rr);
 const tmEl=$('timer');const ts=fmt(tm);if(tmEl._t!==ts+tl){tmEl._t=ts+tl;tmEl.innerHTML=ts+'<small>'+tl+'</small>';}
 tmEl.style.color=(mode==='bomb'&&BM.state==='planted')?'#ff5050':'#fff';
 // phase
 let ph='';
 if(mode==='bomb'){
  if(G.state==='freeze')ph='Phase d\'achat — B pour la boutique';
  else if(BM.state==='planted')ph='BOMBE POSÉE — '+(P.team===1?'DÉSAMORCEZ':'PROTÉGEZ')+' ('+MAP.sites[Math.max(0,BM.site)].n+')';
  else if(G.state==='live'&&P.team===0&&BM.carrier===P.id)ph='Vous portez la bombe — allez sur un site';
  else if(G.state==='live'&&P.team===0&&BM.state==='dropped')ph='La bombe est tombée au sol';
 }else if(G.state==='freeze')ph='Préparez-vous…';
 if(vh&&vh.ph!==undefined)ph=vh.ph;
 setText('phase',ph);
 // action
 const bar=$('bar');
 if(P.alive&&P.prog>0){bar.style.display='block';bar.firstElementChild.nextElementSibling.style.width=(P.prog/(P.team===0?PLANT_T:defT(P))*100)+'%';setText('barT',P.progMsg||'');}
 else bar.style.display='none';
 const hint=$('hint');const hm=P.alive?(P.useMsg||''):'';if(hint._m!==hm){hint._m=hm;hint.textContent=hm;hint.style.display=hm?'block':'none';}
 // scope / divers
 $('scope').style.display=(P.alive&&P.scoped)?'block':'none';scopeRetUpdate();
 // aveuglement
 if(P.blindT>0){P.blindT-=dt;$('flashfx').style.opacity=Math.min(1,P.blindT*1.3);}
 else{const o=parseFloat($('flashfx').style.opacity||0);if(o>0)$('flashfx').style.opacity=Math.max(0,o-dt*1.4);}
 // spectateur / respawn
 const spE=$('spec');
 if(!P.alive&&G.state!=='over'){
  if(isDM()){spE.style.display='none';const r=$('respawn');r.style.display='block';setText('rsT',Math.max(0,Math.ceil(P.respT)));}
  else if(G.spec){spE.style.display='block';setText('spec','SPECTATEUR : '+G.spec.name+'   (clic = suivant)');}
  else spE.style.display='none';
 }else spE.style.display='none';
 setText('loc',locName(src.x,src.z));
 // compte à rebours
 if(G.state==='freeze'&&G.mode==='bomb'&&G.timer<=3.2&&G.timer>0){const n=Math.ceil(G.timer);if(n!==G.countdownN){G.countdownN=n;const c=$('countdown');c.textContent=n;c.className='';void c.offsetWidth;c.className='on';sfx('tick');}}
 // fps
 fpsN++;fpsT+=dt;if(fpsT>=.5){if(cfg.fps){const f=$('fps');f.style.display='block';f.textContent=Math.round(fpsN/fpsT)+' FPS';}else $('fps').style.display='none';fpsN=0;fpsT=0;}
 updateCrosshair();
}
/* ---------- boutique ---------- */
let lastBuyset=null;
function renderBuy(){
 const free=!cfg.eco||isDM();let h='';
 for(const [cn,list] of CATS){
  h+='<div class="col"><h3>'+cn.toUpperCase()+'</h3>';
  for(const k of list){
   const w=W[k],slot=slotOf(k),own=P.wp[slot]&&P.wp[slot].k===k,pr=G.pistolRound&&G.mode==='bomb'&&w.slot===0,can=(free||P.money>=w.price)&&!own&&!pr;
   h+='<button class="it'+(own?' own':'')+'" data-k="'+k+'"'+(can?'':' disabled')+'><div class="t"><span>'+w.n+'</span><em>'+(own?'ÉQUIPÉ':pr?'MANCHE PISTOLET':free?'GRATUIT':'$'+w.price)+'</em></div><img src="'+weaponImg(k)+'"><div class="st"><i style="width:'+clamp(w.dmg*(w.pel?w.pel*.45:1)*.8,8,100)+'%"></i><i style="width:'+clamp(w.rpm/10,6,100)+'%;background:#4aa3ff"></i><i style="width:'+clamp(100-w.spr*14,8,100)+'%;background:#7dff9f"></i></div></button>';
  }
  h+='</div>';
 }
 const items=[['armor','Gilet pare-balles',650,P.armor>=100],['shield1','Bouclier léger (+25)',400,P.shield>=25],['shield2','Bouclier lourd (+50)',1000,P.shield>=50]];
 if(G.mode==='bomb'&&P.team===1)items.push(['kit','Kit de désamorçage',400,P.kit]);
 items.push(['frag','Grenade frag (G)',300,P.nade.f>=1],['flash','Flashbang (F) ×2',200,P.nade.fl>=2],['smoke','Fumigène (H)',300,P.nade.sm>=1],['mine','Mine de proximité (X) — max 2',MINE_PRICE,(P.nade.mn||0)>=MINE_MAX]);
 h+='<div class="col"><h3>ÉQUIPEMENT</h3>'+items.map(([k,n,pr,own])=>'<button class="it'+(own?' own':'')+'" data-k="'+k+'"'+((free||P.money>=pr)&&!own?'':' disabled')+'><div class="t"><span>'+n+'</span><em>'+(own?'ÉQUIPÉ':free?'GRATUIT':'$'+pr)+'</em></div></button>').join('')+
  '<div style="font-size:.66rem;color:#7b8ca6;margin-top:8px;line-height:1.5">Barres : <span style="color:#ff4655">dégâts</span> · <span style="color:#4aa3ff">cadence</span> · <span style="color:#7dff9f">précision</span><br>Le <b style="color:#5ad8ff">bouclier</b> absorbe les dégâts avant le gilet et la santé.</div></div>';
 $('bgrid').innerHTML=h;setText('bmoney',free?'':'$'+P.money);
 $('bgrid').querySelectorAll('.it').forEach(b=>b.onclick=()=>{if(buyItem(P,b.dataset.k)){sfx('buy');renderBuy();}else sfx('deny');});
}
function quickBuy(){
 const free=!cfg.eco||isDM();
 const order=['m4','ak','famas','galil','mp9','ump'];
 if(!P.wp.p){for(const k of order){if((free||P.money>=W[k].price)&&buyItem(P,k))break;}}
 buyItem(P,'armor');if(P.money>=1000||free)buyItem(P,'shield2');else buyItem(P,'shield1');
 if(P.team===1)buyItem(P,'kit');buyItem(P,'frag');buyItem(P,'flash');buyItem(P,'smoke');
 sfx('buy');renderBuy();
}
function rebuy(){
 const ld=cfg.loadout;if(ld.p)buyItem(P,ld.p);if(ld.s)buyItem(P,ld.s);buyItem(P,'armor');buyItem(P,'frag');sfx('buy');renderBuy();
}
function openBuy(){
 if(G.variant==='zombies'){uiToast('Zombies : achète aux murs (craie), à la boîte mystère et aux machines');return;}
 if(!G.running)return;
 if(G.mode==='bomb'&&G.state!=='freeze'){uiToast('Achats possibles seulement en début de manche');return;}
 buyOpen=true;renderBuy();$('buy').classList.add('show');
 if(document.pointerLockElement)document.exitPointerLock();
}
function closeBuy(silent){
 if(!buyOpen)return;buyOpen=false;$('buy').classList.remove('show');
 if(!silent&&G.running)lockMouse();
}
/* ---------- entrées (touches personnalisables) ---------- */
function lockMouse(){try{const p=canvas.requestPointerLock();if(p&&p.catch)p.catch(()=>{});}catch(e){}}
document.addEventListener('pointerlockchange',()=>{
 focusLocked=document.pointerLockElement===canvas;
 if(focusLocked){$('pause').classList.remove('show');G.paused=false;}
 else if(G.running&&!buyOpen&&G.state!=='over'&&G.state!=='cine'){G.paused=true;$('pause').classList.add('show');mouseL=mouseR=false;for(const k in keys)keys[k]=false;}
});
addEventListener('mousemove',e=>{
 if(!focusLocked||!G.running||!P.alive||buyOpen||P.emote)return;
 const w=curW(P),z=P.scoped?1/sightZoom(P,w):1-.25*P.ads,s=.0022*cfg.sens*z*wsensMul();
 P.yaw-=e.movementX*s;P.pitch=clamp(P.pitch-e.movementY*s,-1.5,1.5);
});
// un clic sur le jeu reprend la capture de la souris (utile au joueur invité, qui n'a pas cliqué sur « Jouer »)
addEventListener('mousedown',e=>{const t=e.target;if(t&&t.closest&&t.closest('button,input,select,textarea,a,#menu,#buy,.ov'))return;if(G.running&&!focusLocked&&!buyOpen&&G.state!=='over')lockMouse();});
let rebindCb=null;
function inputDown(code){
 tutDown(code);
 keys[code]=true;
 if(!G.running)return;
 const b=cfg.binds;
 if(G.state==='cine'){if(code==='Space'||code==='Escape'||code===b.fire)skipCine();return;}
 if(code===b.score){scoreboard();$('sb').style.display='block';return;}
 if(code===b.buy){if(buyOpen)closeBuy();else openBuy();return;}
 if(code==='Escape'&&buyOpen){closeBuy();return;}
 if(!focusLocked||buyOpen)return;
 if(!P.alive){if(code===b.fire)cycleSpec();return;}
 if(code===b.fire){if(P.emote&&P.emote.t>.4){P.emote=null;P.rig.root.visible=false;}mouseL=true;clickLatch=true;}
 if(code===b.ads)mouseR=true;
 if(P.emote)return;
 if(code===b.reload)startReload(P);
 const free=!(G.mode==='bomb'&&G.state==='freeze');
 if(code===b.frag&&free)throwNade(P,'f');
 if(code===b.flash&&free)throwNade(P,'fl');
 if(code===b.smoke&&free)throwNade(P,'sm');
 if(code===b.spray)doSpray();
 if(code===b.mine&&free)placeMine(P);
 if(code===b.inspect)vmInspect();
 if(code===b.slot1&&P.wp.p)switchTo(P,'p');
 if(code===b.slot2&&P.wp.s)switchTo(P,'s');
 if(code===b.slot3)switchTo(P,'k');
 if(code===b.last&&P.wp[P.lastSlot])switchTo(P,P.lastSlot);
 if(code===b.emote)startEmote();
 if(code===b.next||code===b.prev){const order=['p','s','k'].filter(k=>P.wp[k]),i=order.indexOf(P.cur);switchTo(P,order[(i+(code===b.next?1:-1)+order.length)%order.length]);}
}
function inputUp(code){
 keys[code]=false;const b=cfg.binds;
 if(code===b.fire)mouseL=false;
 if(code===b.ads)mouseR=false;
 if(code===b.score&&G.state!=='end')$('sb').style.display='none';
}
addEventListener('keydown',e=>{
 if(rebindCb){e.preventDefault();rebindCb(e.code);return;}
 if(e.target&&(e.target.tagName==='INPUT'||e.target.tagName==='TEXTAREA'))return;
 const b=cfg.binds;
 if(G.running&&(e.code==='Tab'||e.code===b.score||e.code==='Space'||e.code===b.buy||e.code===b.walk||e.code===b.sprint||e.code==='AltLeft'))e.preventDefault();
 if(e.repeat)return;
 inputDown(e.code);
});
addEventListener('keyup',e=>{inputUp(e.code);});
addEventListener('mousedown',e=>{
 if(rebindCb){e.preventDefault();rebindCb('Mouse'+e.button);return;}
 if(!focusLocked||!G.running)return;
 inputDown('Mouse'+e.button);
});
addEventListener('mouseup',e=>{inputUp('Mouse'+e.button);});
addEventListener('contextmenu',e=>e.preventDefault());
addEventListener('wheel',e=>{
 if(rebindCb){rebindCb(e.deltaY>0?'WheelDown':'WheelUp');return;}
 if(!focusLocked||!G.running||!P.alive)return;
 const c=e.deltaY>0?'WheelDown':'WheelUp';inputDown(c);inputUp(c);
});
function cycleSpec(){
 const l=ents.filter(e=>e.alive&&e.team===P.team&&e!==P);if(!l.length)return;
 const i=l.indexOf(G.spec);G.spec=l[(i+1)%l.length];
}
function specTarget(){
 if(P.alive)return null;
 if(G.spec&&G.spec.alive)return G.spec;
 const l=ents.filter(e=>e.alive&&e!==P&&(!MODE().team||e.team===P.team));
 G.spec=l.length?l[0]:(ents.find(e=>e.alive&&e!==P)||null);return G.spec;
}
$('resume').onclick=()=>lockMouse();
$('buyClose').onclick=()=>closeBuy();
$('bQuick').onclick=quickBuy;$('bRe').onclick=rebuy;
function toMenu(){
 if(NET.role==='host'&&G.running)netMatchOver();G.netClient=false;
 G.running=false;G.state='menu';G.paused=false;
 $('pause').classList.remove('show');$('over').classList.remove('show');hudEl.classList.remove('show');
 closeBuy(true);if(document.pointerLockElement)document.exitPointerLock();
 for(const e of ents)if(e.rig)scene.remove(e.rig.root);ents=[];
 for(const p of pickups)scene.remove(p.mesh);pickups=[];clearNades();resetFX();
 buildWorld(cfg.map);buildRadarMap();
 $('menu').classList.add('show');
}
$('toMenu').onclick=toMenu;$('oMenu').onclick=toMenu;$('again').onclick=()=>{startMatch();buildRadarMap();};
