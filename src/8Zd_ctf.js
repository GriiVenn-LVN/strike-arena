/* =====================================================================
   MODE CAPTURE DU DRAPEAU (façon Halo / Call of Duty / Roblox)
   - Chaque équipe a un drapeau dans sa base (près de son point de départ).
   - Touche le drapeau adverse pour le prendre, ramène-le dans ta base
     pendant que ton propre drapeau y est : +1 capture.
   - Le porteur éliminé lâche le drapeau. Un adversaire qui le touche le
     ramène aussitôt à sa base ; un allié du porteur peut le reprendre.
     Un drapeau lâché revient seul au bout de 25 s.
   - Les éliminations ne donnent pas de points. Réapparition rapide.
   Variante du mode « tdm » : réutilise ses réapparitions et sa fin.
   ===================================================================== */
MODES.ctf={n:'Capture du drapeau',ic:'🚩',c:'#ff9f43',team:true,respawn:3,desc:'Va prendre le drapeau adverse et ramène-le dans ta base. Ton drapeau doit être chez toi pour marquer.',limitLabel:'Captures pour gagner',limits:[3,5,7]};
VARIANT_BASE.ctf='tdm';NOKILLSCORE.ctf=1;
MODE_GROUPS[1][1].push('ctf');MODE_TAG.ctf='Ramène le drapeau adverse';
if(typeof RTIME!=='undefined')RTIME.ctf={l:'Durée de la partie',o:[8,10,15],d:10,u:'min'};
if(typeof QUICK_MODES!=='undefined')QUICK_MODES.push('ctf');
const CTF={flags:[],caps:[0,0]};
const CTF_R=1.5,CTF_BACK=25,CTF_COL=[0xff7a4a,0x4aa3ff];
const isCtf=()=>G.variant==='ctf';

function ctfFlagMesh(team){
 const g=new THREE.Group(),col=[0xd8400f,0x1660d8][team];
 const pole=new THREE.Mesh(new THREE.CylinderGeometry(.035,.035,2.3,8),new THREE.MeshStandardMaterial({color:0xd8dde4,metalness:.8,roughness:.3}));pole.position.y=1.15;g.add(pole);
 const tip=new THREE.Mesh(new THREE.SphereGeometry(.07,10,8),new THREE.MeshStandardMaterial({color:0xffd23a,metalness:.9,roughness:.25}));tip.position.y=2.33;g.add(tip);
 const geo=new THREE.PlaneGeometry(1.1,.7,8,4);geo.translate(.55,0,0);
 const cloth=new THREE.Mesh(geo,new THREE.MeshStandardMaterial({color:col,roughness:.9,side:THREE.DoubleSide}));
 cloth.position.set(.03,1.92,0);g.add(cloth);g.userData.cloth=cloth;g.userData.base=geo.attributes.position.array.slice();
 return g;
}
function ctfWave(f,t){
 const c=f.mesh.userData.cloth,p=c.geometry.attributes.position,b=f.mesh.userData.base;
 for(let i=0;i<p.count;i++){const x=b[i*3];p.array[i*3+2]=Math.sin(x*6-t*7+f.team)*.09*x;}
 p.needsUpdate=true;
}
function ctfBase(team){
 const l=team===0?MAP.spawnT:MAP.spawnCT;let x=0,z=0;for(const c of l){x+=c[0];z+=c[1];}
 const o=team===0?MAP.spawnCT:MAP.spawnT;let ox=0,oz=0;for(const c of o){ox+=c[0];oz+=c[1];}
 x/=l.length;z/=l.length;ox/=o.length;oz/=o.length;
 // un peu en avant du point de départ, vers le milieu de la carte
 const c=typeof domSpot==='function'?domSpot(x+(ox-x)*.12,z+(oz-z)*.12):[Math.round(x),Math.round(z)];
 return [cc(c[0]),cc(c[1])];
}
function ctfSetup(){
 ctfCleanup();
 for(const team of [0,1]){
  const [x,z]=ctfBase(team),y=groundH(x,z);
  const mesh=ctfFlagMesh(team);mesh.position.set(x,y,z);scene.add(mesh);
  // la toile fait face au milieu de la carte (d'où arrivent les attaquants)
  const rot=Math.atan2(cc(N/2)-x,cc(N/2)-z)-Math.PI/4;mesh.rotation.y=rot;
  const ring=ringMesh(CTF_COL[team],.9);ring.position.set(x,y,z);ring.scale.set(CTF_R+.3,1,CTF_R+.3);scene.add(ring);
  if(ring.userData.wall)ring.userData.wall.material.opacity=.07;
  CTF.flags.push({team,hx:x,hz:z,hy:y,x,z,y,rot,state:'home',carrier:null,backT:0,mesh,ring});
 }
 CTF.caps=[0,0];
}
function ctfCleanup(){
 for(const f of CTF.flags){if(f.mesh.parent)f.mesh.parent.remove(f.mesh);scene.remove(f.ring);}
 CTF.flags.length=0;const h=$('ctfHud');if(h)h.style.display='none';
}
function ctfHome(f){
 if(f.mesh.parent!==scene){if(f.mesh.parent)f.mesh.parent.remove(f.mesh);scene.add(f.mesh);f.mesh.scale.setScalar(1);f.mesh.rotation.set(0,0,0);}
 f.state='home';f.carrier=null;f.x=f.hx;f.z=f.hz;f.y=f.hy;f.mesh.position.set(f.hx,f.hy,f.hz);f.mesh.rotation.y=f.rot||0;
}
function ctfDrop(f){
 const c=f.carrier;f.carrier=null;if(c)c.ctfFlag=null;
 if(f.mesh.parent!==scene){if(f.mesh.parent)f.mesh.parent.remove(f.mesh);scene.add(f.mesh);f.mesh.scale.setScalar(1);f.mesh.rotation.set(0,0,0);}
 f.state='dropped';f.backT=CTF_BACK;f.x=c?c.x:f.x;f.z=c?c.z:f.z;f.y=groundH(f.x,f.z);f.mesh.position.set(f.x,f.y,f.z);
}
function ctfTake(f,e){
 f.state='carried';f.carrier=e;e.ctfFlag=f;
 if(f.mesh.parent)f.mesh.parent.remove(f.mesh);
 if(e.rig&&e.rig.root&&!e.isPlayer){e.rig.root.add(f.mesh);f.mesh.position.set(-.18,.55,.22);f.mesh.rotation.set(.18,0,-.12);f.mesh.scale.setScalar(.75);}
 else{scene.add(f.mesh);f.mesh.scale.setScalar(.75);}
}
function ctfSay(txt,good){uiBanner(txt,'',1500,good?'#7dff9f':'#ff6b6b');sfx(good?'pickup':'alarm');}
function ctfUpdate(dt,t){
 for(const f of CTF.flags){
  ctfWave(f,t);f.ring.userData.ring.rotation.z+=dt*.6;
  if(f.state==='carried'&&f.mesh.parent===scene&&f.carrier){f.mesh.position.set(f.carrier.x+.25,f.carrier.y+.35,f.carrier.z+.25);f.mesh.visible=!(f.carrier.isPlayer&&P.alive);}
  else f.mesh.visible=true;
 }
 if(G.state!=='live'){ctfHud();return;}
 for(const f of CTF.flags){
  const mine=f.team===P.team;
  if(f.state==='carried'){
   const c=f.carrier;
   if(!c||!c.alive||c.downed||!ents.includes(c)){ctfDrop(f);ctfSay(mine?'NOTRE DRAPEAU EST TOMBÉ':'DRAPEAU ENNEMI LÂCHÉ',!mine);continue;}
   f.x=c.x;f.z=c.z;f.y=c.y;
   const own=CTF.flags[c.team];
   if(own.state==='home'&&Math.hypot(c.x-own.hx,c.z-own.hz)<CTF_R+.6&&Math.abs(c.y-own.hy)<2){
    G.score[c.team]++;CTF.caps[c.team]++;c.ctfCaps=(c.ctfCaps||0)+1;c.ctfFlag=null;ctfHome(f);
    const us=c.team===P.team;uiBanner(us?'DRAPEAU CAPTURÉ !':'L\'ENNEMI A CAPTURÉ NOTRE DRAPEAU',(c===P?'Bien joué ! ':'')+G.score[P.team]+' – '+G.score[1-P.team],2200,us?'#7dff9f':'#ff6b6b');
    sfx(us?'powerup':'alarm');if(c===P&&typeof uiToast==='function')uiToast('+1 capture');
    for(const b of ents)if(!b.isPlayer)b.ctfT=0;
    checkDMEnd();
   }
   continue;
  }
  if(f.state==='dropped'){f.backT-=dt;f.mesh.position.y=f.y+Math.sin(t*3)*.05;if(f.backT<=0){ctfHome(f);ctfSay(mine?'NOTRE DRAPEAU EST REVENU':'LE DRAPEAU ENNEMI EST REVENU',mine);continue;}}
  for(const e of ents){
   if(!e.alive||e.downed||e.dummy||Math.hypot(e.x-f.x,e.z-f.z)>CTF_R||Math.abs(e.y-f.y)>2)continue;
   if(e.team!==f.team){if(e.ctfFlag)continue;ctfTake(f,e);ctfSay(e===P?'TU AS LE DRAPEAU ! RAMÈNE-LE À TA BASE':mine?'NOTRE DRAPEAU EST PRIS':'DRAPEAU ENNEMI PRIS',!mine);break;}
   if(f.state==='dropped'){ctfHome(f);ctfSay(mine?'DRAPEAU RÉCUPÉRÉ':'L\'ENNEMI A RÉCUPÉRÉ SON DRAPEAU',mine);if(e===P&&typeof uiToast==='function')uiToast('Drapeau ramené');break;}
  }
 }
 ctfHud();
}
function ctfHud(){
 let el=$('ctfHud');if(!el){el=document.createElement('div');el.id='ctfHud';$('hud').appendChild(el);}
 el.style.display='';
 const st=f=>f.state==='home'?'à la base':f.state==='dropped'?'à terre '+Math.ceil(f.backT)+' s':(f.carrier===P?'TU LE PORTES':'porté par '+ctfEsc(f.carrier.name));
 const me=CTF.flags[P.team],them=CTF.flags[1-P.team];if(!me||!them){el.innerHTML='';return;}
 el.innerHTML='<span style="color:'+TEAMCSS[P.team]+'">🚩 Le nôtre : '+st(me)+'</span><span style="color:'+TEAMCSS[1-P.team]+'">🚩 Le leur : '+st(them)+'</span>'+
  (P.ctfFlag?'<div class="cg">RAMÈNE LE DRAPEAU À TA BASE'+(me.state!=='home'?' — RÉCUPÈRE D\'ABORD LE TIEN':'')+'</div>':'');
}
function ctfEsc(s){return String(s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'})[c]);}

// branchements sur le moteur de variantes
const _variantInitCtf=variantInit;
variantInit=function(){
 ctfCleanup();for(const e of ents)e.ctfFlag=null;
 _variantInitCtf();
 if(!isCtf())return;
 G.limit=limitOf('ctf');ctfSetup();
};
const _variantUpdateCtf=variantUpdate;
variantUpdate=function(dt,t){_variantUpdateCtf(dt,t);if(isCtf()&&CTF.flags.length&&(G.state==='live'||G.state==='freeze'||G.state==='end'))ctfUpdate(dt,t);};
const _variantTimeUpCtf=variantTimeUp;
variantTimeUp=function(){
 if(!isCtf())return _variantTimeUpCtf();
 G.winner=G.score[0]===G.score[1]?-1:G.score[0]>G.score[1]?0:1;
 if(G.winner===-1){G.state='end';G.endT=4.5;G.final=true;uiBanner('ÉGALITÉ','Temps écoulé',4000);return true;}
 endDM();return true;
};
const _variantSubCtf=variantSub;
variantSub=function(){return isCtf()?'Ramène le drapeau adverse — premier à '+G.limit+' captures':_variantSubCtf();};
const _variantCleanupCtf=variantCleanup;
variantCleanup=function(){_variantCleanupCtf();ctfCleanup();};
const _variantRadarCtf=variantRadar;
variantRadar=function(c,pt){
 _variantRadarCtf(c,pt);
 if(!isCtf())return;
 for(const f of CTF.flags){
  const p=pt(f.x,f.z);c.fillStyle=TEAMCSS[f.team];c.strokeStyle='#000';c.lineWidth=1;
  c.fillRect(p[0]-1,p[1]-9,2,11);c.beginPath();c.moveTo(p[0]+1,p[1]-9);c.lineTo(p[0]+9,p[1]-6);c.lineTo(p[0]+1,p[1]-3);c.closePath();c.fill();c.stroke();
  if(f.state==='carried'){c.strokeStyle='#ffd23a';c.lineWidth=2;c.beginPath();c.arc(p[0],p[1],8+Math.sin(G.t*6)*1.5,0,TAU);c.stroke();}
 }
};
// bots : un tiers défend, le reste attaque ; tout le monde poursuit le voleur
const _botGoalCtf=botGoal;
botGoal=function(b){
 if(!isCtf()||CTF.flags.length<2)return _botGoalCtf(b);
 const own=CTF.flags[b.team],foe=CTF.flags[1-b.team];
 // pick : l'objectif passe avant la traque du dernier ennemi aperçu
 if(b.ctfFlag)return {x:own.hx,z:own.hz,pick:true};
 if(G.t<(b.ctfT||0)&&b.ctfX!==undefined)return {x:b.ctfX,z:b.ctfZ,pick:b.ctfP};
 const def=b.id%3===0;let x,z,hold=1.2,pk=true;
 if(own.state==='carried'&&own.carrier&&(def||Math.random()<.6)){x=own.carrier.x;z=own.carrier.z;hold=.8;}
 else if(own.state==='dropped'&&(def||Math.hypot(own.x-b.x,own.z-b.z)<28)){x=own.x;z=own.z;}
 else if(def){x=own.hx+rand(-5,5);z=own.hz+rand(-5,5);hold=rand(4,8);pk=false;}
 else if(foe.state==='carried'&&foe.carrier){x=foe.carrier.x+rand(-3,3);z=foe.carrier.z+rand(-3,3);}
 else{x=foe.x;z=foe.z;}
 b.ctfX=x;b.ctfZ=z;b.ctfT=G.t+hold;b.ctfP=pk;
 return {x,z,pick:pk};
};
// un bot porteur file vers sa base : il ne s'arrête que pour un ennemi tout proche
const _botUpdateCtf=botUpdate;
botUpdate=function(b,dt){
 if(isCtf()&&b.ctfFlag&&b.target&&Math.hypot(b.target.x-b.x,b.target.z-b.z)>12)b.target=null;
 return _botUpdateCtf(b,dt);
};
(function(){const s=document.createElement('style');s.textContent=`
#ctfHud{position:absolute;top:86px;left:50%;transform:translateX(-50%);display:flex;gap:16px;padding:4px 12px;border-radius:6px;background:#000000a0;flex-wrap:wrap;justify-content:center;pointer-events:none;font:800 .74rem Bahnschrift,Arial;letter-spacing:1.5px;text-shadow:0 1px 4px #000;white-space:nowrap}
#ctfHud .cg{flex-basis:100%;text-align:center;color:#ffd23a;font-size:.86rem;letter-spacing:2.5px;animation:ctfP 1s ease-in-out infinite alternate}
@keyframes ctfP{from{opacity:.65}to{opacity:1}}
`;document.head.appendChild(s);})();
