/* =====================================================================
   MODE ÉLIMINATION CONFIRMÉE (façon Call of Duty « Kill Confirmed »)
   - Chaque joueur éliminé lâche une plaque à sa couleur.
   - Ramasser la plaque d'un ADVERSAIRE confirme l'élimination : +1 point
     pour ton équipe. Ramasser celle d'un ALLIÉ la refuse : l'adversaire
     ne marque pas.
   - Les éliminations seules ne rapportent rien : il faut aller chercher
     les plaques. Une plaque disparaît au bout de 30 s.
   Variante du mode « tdm » : réutilise ses réapparitions et sa fin.
   ===================================================================== */
MODES.kc={n:'Élimination confirmée',ic:'🏷',c:'#ffcf4a',team:true,respawn:3,desc:'Chaque adversaire éliminé lâche une plaque : ramasse-la pour marquer. Ramasse celles de tes alliés pour priver l\'adversaire du point.',limitLabel:'Plaques pour gagner',limits:[30,50,75]};
VARIANT_BASE.kc='tdm';NOKILLSCORE.kc=1;
MODE_GROUPS[1][1].push('kc');MODE_TAG.kc='Ramasse les plaques pour marquer';
if(typeof RTIME!=='undefined')RTIME.kc={l:'Durée de la partie',o:[5,8,10,15],d:10,u:'min'};
if(typeof QUICK_MODES!=='undefined')QUICK_MODES.push('kc');
MPOOL.push({id:'kcTag',n:'Ramasse {t} plaques en Élimination confirmée',t:10,coins:150,xp:70});
const KCF={tags:[],conf:0,deny:0};
const KC_LIFE=30,KC_R=1.35,KC_COL=[0xff7a4a,0x4aa3ff];

// plaque militaire : deux plaques métal sur une chaîne + halo à la couleur de l'équipe
let kcTex=null;
function kcTexture(){
 if(kcTex)return kcTex;
 const c=document.createElement('canvas');c.width=128;c.height=192;const g=c.getContext('2d');
 const grd=g.createLinearGradient(0,0,128,192);grd.addColorStop(0,'#f4f6f8');grd.addColorStop(.5,'#a9b0b8');grd.addColorStop(1,'#e2e6ea');
 g.fillStyle=grd;g.beginPath();g.roundRect(8,8,112,176,36);g.fill();
 g.strokeStyle='#5d646c';g.lineWidth=5;g.stroke();
 g.fillStyle='#3b4148';g.beginPath();g.arc(64,30,9,0,TAU);g.fill();
 g.font='bold 15px monospace';g.textAlign='center';
 ['STRIKE','ARENA','0451-7','O POS'].forEach((t,i)=>g.fillText(t,64,72+i*26));
 kcTex=new THREE.CanvasTexture(c);return kcTex;
}
function kcMesh(team){
 const g=new THREE.Group(),mat=new THREE.MeshStandardMaterial({map:kcTexture(),metalness:.75,roughness:.32});
 const geo=new THREE.BoxGeometry(.24,.36,.02);
 const a=new THREE.Mesh(geo,mat);a.position.set(-.05,0,0);a.rotation.z=.12;g.add(a);
 const b=new THREE.Mesh(geo,mat);b.position.set(.06,-.04,-.03);b.rotation.z=-.18;g.add(b);
 const ch=new THREE.Mesh(new THREE.TorusGeometry(.17,.008,6,24),new THREE.MeshStandardMaterial({color:0xbfc5cc,metalness:.9,roughness:.3}));ch.position.y=.2;ch.scale.y=.6;g.add(ch);
 if(typeof zGlow==='function'){const gl=zGlow(KC_COL[team],1.5);gl.material.opacity=.85;g.add(gl);g.userData.glow=gl;}
 const ring=new THREE.Mesh(new THREE.RingGeometry(.42,.5,32),new THREE.MeshBasicMaterial({color:KC_COL[team],transparent:true,opacity:.75,side:THREE.DoubleSide,depthWrite:false,toneMapped:false}));
 ring.rotation.x=-Math.PI/2;g.userData.ring=ring;
 return g;
}
function kcDrop(v){
 const y=groundH(v.x,v.z),m=kcMesh(v.team);m.position.set(v.x,y+.85,v.z);scene.add(m);
 const r=m.userData.ring;r.position.set(v.x,y+.06,v.z);scene.add(r);
 KCF.tags.push({team:v.team,x:v.x,z:v.z,y,mesh:m,ring:r,life:KC_LIFE,victim:v});
 if(KCF.tags.length>40)kcRemove(0);
}
function kcRemove(i){const t=KCF.tags[i];scene.remove(t.mesh);scene.remove(t.ring);KCF.tags.splice(i,1);}
function kcCleanup(){while(KCF.tags.length)kcRemove(0);const h=$('kcHud');if(h)h.style.display='none';}
function kcPop(txt,col){
 let el=$('kcPop');if(!el){el=document.createElement('div');el.id='kcPop';$('hud').appendChild(el);}
 el.textContent=txt;el.style.color=col;el.classList.remove('go');void el.offsetWidth;el.classList.add('go');
}
function kcUpdate(dt,t){
 for(let i=KCF.tags.length-1;i>=0;i--){
  const k=KCF.tags[i];k.life-=dt;
  k.mesh.rotation.y=t*2.2+k.x;k.mesh.position.y=k.y+.85+Math.sin(t*3+k.z)*.08;
  const fade=k.life<5?(Math.sin(t*14)>0?1:.25):1;k.mesh.visible=fade>.5||k.life>5;
  k.ring.scale.setScalar(1+Math.sin(t*4+k.x)*.08);
  if(k.life<=0){kcRemove(i);continue;}
  if(G.state!=='live')continue;
  for(const e of ents){
   if(!e.alive||e.downed||e.dummy||Math.hypot(e.x-k.x,e.z-k.z)>KC_R||Math.abs(e.y-k.y)>1.6)continue;
   const conf=e.team!==k.team;
   if(conf){G.score[e.team]++;e.kcConf=(e.kcConf||0)+1;}else e.kcDeny=(e.kcDeny||0)+1;
   if(e.isPlayer){
    if(conf){KCF.conf++;kcPop('ÉLIMINATION CONFIRMÉE  +1','#ffd23a');sfx('powerup');}
    else{KCF.deny++;kcPop('ÉLIMINATION REFUSÉE','#7dd8ff');sfx('pickup');}
    if(typeof metaEvent==='function')metaEvent('kcTag');
   }else if(e.team===P.team)sfx('pickup',k.x,k.z,.6);
   kcRemove(i);checkDMEnd();break;
  }
 }
 kcHud();
}
function kcHud(){
 let el=$('kcHud');if(!el){el=document.createElement('div');el.id='kcHud';$('hud').appendChild(el);}
 el.style.display='';
 const mine=KCF.tags.filter(k=>k.team!==P.team).length,ours=KCF.tags.filter(k=>k.team===P.team).length;
 el.innerHTML='<span class="c">🏷 '+mine+' à confirmer</span><span class="d">🏷 '+ours+' à refuser</span>';
}
// branchements sur le moteur de variantes
const _variantInitKc=variantInit;
variantInit=function(){
 kcCleanup();KCF.conf=0;KCF.deny=0;
 _variantInitKc();
 if(G.variant==='kc')G.limit=limitOf('kc');
};
const _variantKillKc=variantKill;
variantKill=function(att,v,w,hs){
 _variantKillKc(att,v,w,hs);
 if(G.variant==='kc'&&!v.dummy)kcDrop(v);
};
const _variantUpdateKc=variantUpdate;
variantUpdate=function(dt,t){_variantUpdateKc(dt,t);if(G.variant==='kc'&&(G.state==='live'||G.state==='freeze'||G.state==='end'))kcUpdate(dt,t);};
const _variantSubKc=variantSub;
variantSub=function(){return G.variant==='kc'?'Ramasse les plaques — premier à '+G.limit:_variantSubKc();};
const _variantCleanupKc=variantCleanup;
variantCleanup=function(){_variantCleanupKc();kcCleanup();};
const _variantRadarKc=variantRadar;
variantRadar=function(c,pt){
 _variantRadarKc(c,pt);
 if(G.variant!=='kc')return;
 for(const k of KCF.tags){const p=pt(k.x,k.z);c.fillStyle=k.team===P.team?'#7dd8ff':'#ffd23a';c.fillRect(p[0]-3,p[1]-4,6,8);c.strokeStyle='#000';c.lineWidth=1;c.strokeRect(p[0]-3,p[1]-4,6,8);}
};
// bots : vont chercher les plaques proches (les leurs pour refuser, celles des autres pour marquer)
const _botGoalKc=botGoal;
botGoal=function(b){
 if(G.variant!=='kc'||!KCF.tags.length)return _botGoalKc(b);
 let best=null,bd=b.hp<45?12:26;
 for(const k of KCF.tags){const d=Math.hypot(k.x-b.x,k.z-b.z)*(k.team===b.team?1.25:1);if(d<bd){bd=d;best=k;}}
 if(best)return {x:best.x,z:best.z,pick:true};
 return _botGoalKc(b);
};
(function(){const s=document.createElement('style');s.textContent=`
#kcHud{position:absolute;top:58px;left:50%;transform:translateX(-50%);display:flex;gap:14px;pointer-events:none;font:800 .74rem Bahnschrift,Arial;letter-spacing:1.5px;text-shadow:0 1px 4px #000}
#kcHud .c{color:#ffd23a}#kcHud .d{color:#7dd8ff}
#kcPop{position:absolute;top:34%;left:50%;transform:translateX(-50%);font:900 1.35rem Bahnschrift,Arial;letter-spacing:3px;text-shadow:0 2px 10px #000,0 0 22px currentColor;opacity:0;pointer-events:none;white-space:nowrap}
#kcPop.go{animation:kcPop 1.4s ease-out}
@keyframes kcPop{0%{opacity:0;transform:translate(-50%,10px) scale(.7)}12%{opacity:1;transform:translate(-50%,0) scale(1.12)}25%{transform:translate(-50%,0) scale(1)}75%{opacity:1}100%{opacity:0;transform:translate(-50%,-18px)}}
`;document.head.appendChild(s);})();
