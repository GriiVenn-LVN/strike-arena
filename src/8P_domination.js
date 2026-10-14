/* =====================================================================
   MODE DOMINATION (façon Call of Duty)
   - Trois drapeaux A, B, C. Reste seul dans le cercle pour le capturer
     (5 s depuis neutre, 8 s pour retourner un drapeau adverse) ; un
     adversaire dans le cercle bloque la capture.
   - Chaque drapeau tenu rapporte 1 point par seconde. Premier à la
     limite (100 / 200 / 300) ou meilleur score à la fin du chrono.
   - Les éliminations ne donnent pas de points. Réapparition rapide.
   Variante du mode « tdm » : réutilise ses réapparitions et sa fin.
   ===================================================================== */
MODES.dom={n:'Domination',ic:'🏳',c:'#ffd23a',team:true,respawn:3,desc:'Trois drapeaux A, B, C à capturer et à tenir. Chaque drapeau tenu rapporte des points.',limitLabel:'Points pour gagner',limits:[100,200,300]};
VARIANT_BASE.dom='tdm';NOKILLSCORE.dom=1;
MODE_GROUPS[1][1].push('dom');MODE_TAG.dom='Tiens A, B et C';
if(typeof RTIME!=='undefined')RTIME.dom={l:'Durée de la partie',o:[5,10,15],d:10,u:'min'};
const DOM={flags:[],pts:[0,0],tick:0};
const DOM_R=3.4,DOM_CAP=5,DOM_COL=[0xff7a4a,0x4aa3ff];

// un point de drapeau : case praticable, libre, accessible depuis les deux camps
function domCellOk(cx,cz){
 if(cx<1||cz<1||cx>=N-1||cz>=N-1||!walkableCell(cz*N+cx))return false;
 const x=cc(cx),z=cc(cz);return !blocked(x,z,groundH(x,z),.6);
}
function domSpot(fx,fz){
 const tx=Math.round(fx),tz=Math.round(fz);
 for(let r=0;r<10;r++)for(let dz=-r;dz<=r;dz++)for(let dx=-r;dx<=r;dx++){
  if(Math.max(Math.abs(dx),Math.abs(dz))!==r)continue;
  const cx=tx+dx,cz=tz+dz;if(!domCellOk(cx,cz))continue;
  const x=cc(cx),z=cc(cz);
  if(findPath(cc(MAP.spawnT[0][0]),cc(MAP.spawnT[0][1]),x,z)&&findPath(cc(MAP.spawnCT[0][0]),cc(MAP.spawnCT[0][1]),x,z))return [cx,cz];
 }
 return [tx,tz];
}
function domLabel(letter){
 const c=document.createElement('canvas');c.width=c.height=128;const g=c.getContext('2d');
 g.fillStyle='#000a';g.beginPath();g.arc(64,64,54,0,TAU);g.fill();g.lineWidth=7;g.strokeStyle='#fff';g.stroke();
 g.fillStyle='#fff';g.font='900 72px Arial';g.textAlign='center';g.textBaseline='middle';g.fillText(letter,64,68);
 const s=new THREE.Sprite(new THREE.SpriteMaterial({map:new THREE.CanvasTexture(c),transparent:true,depthTest:false,toneMapped:false}));
 s.scale.set(1.3,1.3,1);s.renderOrder=5;return s;
}
function domSetup(){
 domCleanup();
 const avg=l=>{let x=0,z=0;for(const c of l){x+=c[0];z+=c[1];}return [x/l.length,z/l.length];};
 const t=avg(MAP.spawnT),ct=avg(MAP.spawnCT);
 ['A','B','C'].forEach((n,i)=>{
  const k=[.28,.5,.72][i],c=domSpot(t[0]+(ct[0]-t[0])*k,t[1]+(ct[1]-t[1])*k);
  // A et C décalés sur les côtés pour que les trois drapeaux ne soient pas alignés
  let cx=c[0],cz=c[1];
  if(i!==1){const px=-(ct[1]-t[1]),pz=ct[0]-t[0],L=Math.hypot(px,pz)||1,s=(i===0?1:-1)*7;const c2=domSpot(cx+px/L*s,cz+pz/L*s);cx=c2[0];cz=c2[1];}
  const x=cc(cx),z=cc(cz),y=groundH(x,z),ring=ringMesh(0xffffff,4.5);ring.position.set(x,y,z);ring.scale.set(DOM_R,1,DOM_R);
  const lab=domLabel(n);lab.position.set(x,y+3.2,z);scene.add(lab);
  DOM.flags.push({n,x,z,y,owner:-1,cap:-1,prog:0,ring,lab,contested:false});
 });
 DOM.pts=[0,0];DOM.tick=0;
}
function domCleanup(){for(const f of DOM.flags){scene.remove(f.ring);scene.remove(f.lab);}DOM.flags.length=0;}
function domColor(f){ringColor(f.ring,f.contested?0xffd23a:f.owner<0?0xffffff:DOM_COL[f.owner]);}
function domUpdate(dt,t){
 for(const f of DOM.flags){f.ring.userData.ring.rotation.z+=dt*.5;f.lab.position.y=f.y+3.2+Math.sin(t*2+f.x)*.08;}
 if(G.state!=='live')return;
 for(const f of DOM.flags){
  const c=[0,0];for(const e of ents)if(e.alive&&!e.downed&&Math.hypot(e.x-f.x,e.z-f.z)<DOM_R&&Math.abs(e.y-f.y)<2.5)c[e.team]++;
  f.contested=c[0]>0&&c[1]>0;
  const who=c[0]>0&&!c[1]?0:c[1]>0&&!c[0]?1:-1;
  if(who>=0&&who!==f.owner){
   if(f.cap!==who){f.cap=who;f.prog=0;}
   f.prog+=dt*Math.min(2,1+.25*(c[who]-1))/(f.owner<0?DOM_CAP:DOM_CAP*1.6);
   if(f.prog>=1){
    const prev=f.owner;f.owner=who;f.prog=0;f.cap=-1;
    const mine=who===P.team;uiBanner((mine?'DRAPEAU '+f.n+' CAPTURÉ':'DRAPEAU '+f.n+' PERDU'),'',1400,mine?'#7dff9f':'#ff6b6b');sfx(mine?'pickup':'alarm');
    if(prev>=0)for(const b of ents)if(!b.isPlayer&&b.team===prev)b.domT=0; // les défenseurs réagissent
   }
  }else if(who<0&&!f.contested&&f.prog>0)f.prog=Math.max(0,f.prog-dt*.25);
  domColor(f);
 }
 DOM.tick+=dt;
 if(DOM.tick>=1){DOM.tick-=1;for(const f of DOM.flags)if(f.owner>=0)DOM.pts[f.owner]++;G.score=DOM.pts.slice();checkDMEnd();}
 domHud();
}
function domHud(){
 let el=$('domHud');
 if(!el){el=document.createElement('div');el.id='domHud';$('hud').appendChild(el);}
 const near=DOM.flags.find(f=>P&&P.alive&&Math.hypot(P.x-f.x,P.z-f.z)<DOM_R);
 el.innerHTML=DOM.flags.map(f=>{const col=f.contested?'#ffd23a':f.owner<0?'#ffffff':TEAMCSS[f.owner];return '<i style="border-color:'+col+';color:'+col+'">'+f.n+(f.prog>0?'<b style="width:'+Math.round(f.prog*100)+'%;background:'+(f.cap>=0?TEAMCSS[f.cap]:'#fff')+'"></b>':'')+'</i>';}).join('')+
  (near?'<div class="dn">'+(near.contested?'DRAPEAU '+near.n+' DISPUTÉ':near.owner===P.team?'DRAPEAU '+near.n+' TENU':'CAPTURE DE '+near.n+' — '+Math.round(near.prog*100)+' %')+'</div>':'');
}
// branchements sur le moteur de variantes
const _variantInitDom=variantInit;
variantInit=function(){
 if(G.variant!=='dom')domCleanup();
 _variantInitDom();
 if(G.variant!=='dom'){const h=$('domHud');if(h)h.style.display='none';return;}
 G.limit=limitOf('dom');domSetup();const h=$('domHud');if(h)h.style.display='';
};
const _variantUpdateDom=variantUpdate;
variantUpdate=function(dt,t){_variantUpdateDom(dt,t);if(G.variant==='dom'&&(G.state==='live'||G.state==='freeze'))domUpdate(dt,t);};
const _variantTimeUpDom=variantTimeUp;
variantTimeUp=function(){
 if(G.variant!=='dom')return _variantTimeUpDom();
 G.score=DOM.pts.slice();G.winner=DOM.pts[0]===DOM.pts[1]?-1:DOM.pts[0]>DOM.pts[1]?0:1;
 if(G.winner===-1){G.state='end';G.endT=4.5;G.final=true;uiBanner('ÉGALITÉ','Temps écoulé',4000);return true;}
 endDM();return true;
};
const _variantSubDom=variantSub;
variantSub=function(){return G.variant==='dom'?'Capture A, B et C — premier à '+G.limit+' points':_variantSubDom();};
const _variantCleanupDom=variantCleanup;
variantCleanup=function(){_variantCleanupDom();domCleanup();};
// bots : chacun choisit un drapeau à prendre ou à défendre
const _botGoalDom=botGoal;
botGoal=function(b){
 if(G.variant!=='dom'||!DOM.flags.length)return _botGoalDom(b);
 if(!b.domF||G.t>(b.domT||0)){
  const fl=DOM.flags,mine=fl.filter(f=>f.owner===b.team),other=fl.filter(f=>f.owner!==b.team);
  let f;
  if(other.length&&(Math.random()<.75||!mine.length)){f=other.slice().sort((a,c)=>Math.hypot(a.x-b.x,a.z-b.z)-Math.hypot(c.x-b.x,c.z-b.z))[Math.random()<.7?0:Math.floor(Math.random()*other.length)];}
  else f=pick(mine.length?mine:fl);
  b.domF=f;b.domT=G.t+rand(12,20);b.domX=f.x+rand(-1.8,1.8);b.domZ=f.z+rand(-1.8,1.8);
 }
 if(b.domF.owner===b.team&&!b.domF.contested&&Math.hypot(b.x-b.domF.x,b.z-b.domF.z)<DOM_R&&Math.random()<.002)b.domT=0;
 return {x:b.domX,z:b.domZ};
};
(function(){const s=document.createElement('style');s.textContent=`
#domHud{position:absolute;top:58px;left:50%;transform:translateX(-50%);display:flex;gap:10px;justify-content:center;flex-wrap:wrap;pointer-events:none}
#domHud i{position:relative;width:34px;height:34px;border:3px solid #fff;border-radius:50%;display:flex;align-items:center;justify-content:center;font:900 1rem Bahnschrift,Arial;font-style:normal;background:#0008;overflow:hidden}
#domHud i b{position:absolute;left:0;bottom:0;height:4px;opacity:.9}
#domHud .dn{flex-basis:100%;text-align:center;font:800 .78rem Bahnschrift,Arial;letter-spacing:2px;color:#fff;text-shadow:0 1px 4px #000}
`;document.head.appendChild(s);})();
