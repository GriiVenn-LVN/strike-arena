/* =====================================================================
   MODE PHOTO (façon Fortnite / Call of Duty Théâtre)
   Depuis le menu pause : bouton « MODE PHOTO ».
   - La partie reste figée (en solo), l'interface disparaît.
   - Caméra libre : ZQSD / WASD ou flèches pour bouger, glisser la souris
     pour regarder, Espace / C pour monter / descendre, Maj = plus vite,
     molette = zoom, curseurs zoom et inclinaison.
   - Filtres : Aucun, Noir et blanc, Sépia, Cinéma, Éclatant, Nocturne,
     Rétro. Ton soldat est visible pour les photos.
   - « CAPTURER » (ou Entrée) enregistre l'image en PNG.
   - Échap ou « RETOUR » revient au menu pause.
   ===================================================================== */
const PH={on:false,x:0,y:0,z:0,yaw:0,pit:0,roll:0,fov:60,filter:0,keys:{},drag:null,last:0,raf:0,pVis:false};
const PH_FILTERS=[
 {n:'Aucun',f:''},
 {n:'Noir et blanc',f:'grayscale(1) contrast(1.25) brightness(1.05)'},
 {n:'Sépia',f:'sepia(.85) contrast(1.1) brightness(1.05)'},
 {n:'Cinéma',f:'contrast(1.18) saturate(.82) brightness(.95)',bars:true},
 {n:'Éclatant',f:'saturate(1.7) contrast(1.12)'},
 {n:'Nocturne',f:'hue-rotate(175deg) saturate(.55) brightness(.75) contrast(1.3)'},
 {n:'Rétro',f:'sepia(.35) saturate(1.4) hue-rotate(-12deg) contrast(.92) brightness(1.08)',vig:true}
];
function phBuild(){
 if($('photoUI'))return;
 const d=document.createElement('div');d.id='photoUI';
 d.innerHTML='<div class="phbars"><i></i><i></i></div><div class="phvig"></div><div class="phflash"></div>'+
  '<div class="phtop">📷 MODE PHOTO</div>'+
  '<div class="phhelp">ZQSD / flèches : bouger · Glisser : regarder · Espace / C : monter / descendre · Maj : vite · Molette : zoom · Entrée : capturer · Échap : retour</div>'+
  '<div class="phbar"><div class="phf"></div><label>ZOOM <input type="range" id="phFov" min="15" max="100" step="1"></label>'+
  '<label>INCLINAISON <input type="range" id="phRoll" min="-30" max="30" step="1"></label>'+
  '<button class="btn alt cut" id="phHide">MASQUER</button><button class="btn cut" id="phShot">📸 CAPTURER</button><button class="btn alt cut" id="phBack">RETOUR</button></div>';
 document.body.appendChild(d);
 const f=d.querySelector('.phf');
 PH_FILTERS.forEach((x,i)=>{const b=document.createElement('button');b.textContent=x.n;b.onclick=()=>{PH.filter=i;phApply();};f.appendChild(b);});
 $('phFov').oninput=e=>{PH.fov=+e.target.value;};
 $('phRoll').oninput=e=>{PH.roll=+e.target.value*RAD;};
 $('phShot').onclick=phShot;$('phBack').onclick=phExit;
 $('phHide').onclick=()=>{d.classList.toggle('bare');};
 d.addEventListener('mousedown',e=>{if(e.target.closest('.phbar'))return;PH.drag={x:e.clientX,y:e.clientY};d.classList.add('grab');});
 d.addEventListener('wheel',e=>{PH.fov=clamp(PH.fov+(e.deltaY>0?3:-3),15,100);$('phFov').value=PH.fov;e.preventDefault();},{passive:false});
}
addEventListener('mousemove',e=>{if(!PH.on||!PH.drag)return;const s=.0042*(PH.fov/60);PH.yaw-=(e.clientX-PH.drag.x)*s;PH.pit=clamp(PH.pit-(e.clientY-PH.drag.y)*s,-1.5,1.5);PH.drag={x:e.clientX,y:e.clientY};});
addEventListener('mouseup',()=>{if(!PH.on)return;PH.drag=null;const d=$('photoUI');if(d)d.classList.remove('grab');});
// en mode photo, les clics et les touches ne vont pas au jeu (sinon la souris serait recapturée et la partie reprendrait)
addEventListener('mousedown',e=>{if(PH.on)e.stopPropagation();},true);
addEventListener('keydown',e=>{
 if(!PH.on)return;e.stopPropagation();
 if(e.target&&e.target.tagName==='INPUT'&&e.code!=='Escape'&&e.code!=='Enter')return;
 e.preventDefault();
 if(e.code==='Escape'){phExit();return;}
 if(e.code==='Enter'||e.code==='NumpadEnter'){phShot();return;}
 if(e.code==='KeyH'){$('photoUI').classList.toggle('bare');return;}
 PH.keys[e.code]=true;
},true);
addEventListener('keyup',e=>{if(!PH.on)return;e.stopPropagation();PH.keys[e.code]=false;},true);

function phEnter(){
 if(!G.running||PH.on)return;
 phBuild();
 PH.on=true;PH.keys={};PH.drag=null;PH.roll=0;
 PH.x=camera.position.x;PH.y=camera.position.y;PH.z=camera.position.z;
 const r=new THREE.Euler().setFromQuaternion(camera.quaternion,'YXZ');PH.yaw=r.y;PH.pit=r.x;PH.fov=Math.round(camera.fov);
 $('phFov').value=PH.fov;$('phRoll').value=0;
 $('pause').classList.remove('show');$('hud').style.visibility='hidden';
 const d=$('photoUI');d.classList.remove('bare');d.classList.add('show');
 if(P&&P.rig){PH.pVis=P.rig.root.visible;if(P.alive)P.rig.root.visible=true;}
 if(typeof VM!=='undefined'&&VM.root)VM.root.visible=false;
 phApply();PH.last=performance.now();cancelAnimationFrame(PH.raf);PH.raf=requestAnimationFrame(phTick);
 if(typeof sfxUI==='function')sfxUI();
}
function phExit(){
 if(!PH.on)return;
 PH.on=false;cancelAnimationFrame(PH.raf);
 $('photoUI').classList.remove('show');$('hud').style.visibility='';
 renderer.domElement.style.filter='';
 if(P&&P.rig)P.rig.root.visible=P.alive?PH.pVis:P.rig.root.visible;
 if(G.running&&G.paused)$('pause').classList.add('show');
}
function phApply(){
 const F=PH_FILTERS[PH.filter],d=$('photoUI');
 renderer.domElement.style.filter=F.f;
 d.classList.toggle('cine',!!F.bars);d.classList.toggle('vig',!!F.vig);
 d.querySelectorAll('.phf button').forEach((b,i)=>b.classList.toggle('on',i===PH.filter));
}
function phTick(){
 if(!PH.on)return;PH.raf=requestAnimationFrame(phTick);
 const now=performance.now(),dt=Math.min(.05,(now-PH.last)/1000);PH.last=now;
 const k=PH.keys,sp=(k.ShiftLeft||k.ShiftRight?14:4.5)*dt;
 let f=0,s=0,u=0;
 if(k.KeyW||k.KeyZ||k.ArrowUp)f++;if(k.KeyS||k.ArrowDown)f--;
 if(k.KeyD||k.ArrowRight)s++;if(k.KeyA||k.KeyQ||k.ArrowLeft)s--;
 if(k.Space)u++;if(k.KeyC||k.ControlLeft)u--;
 const cy=Math.cos(PH.yaw),sy=Math.sin(PH.yaw),cp=Math.cos(PH.pit);
 PH.x+=(-sy*cp*f+cy*s)*sp;PH.z+=(-cy*cp*f-sy*s)*sp;PH.y+=(Math.sin(PH.pit)*f+u)*sp;
 PH.y=Math.max(groundH(PH.x,PH.z)+.25,PH.y);
 // on reste dans la carte
 const lim=N*S;PH.x=clamp(PH.x,-10,lim+10);PH.z=clamp(PH.z,-10,lim+10);
}
// la caméra suit le mode photo
const _placeCameraPh=placeCamera;
placeCamera=function(dt,t){
 if(!PH.on)return _placeCameraPh(dt,t);
 camera.position.set(PH.x,PH.y,PH.z);camera.rotation.order='YXZ';camera.rotation.set(PH.pit,PH.yaw,PH.roll);
 camera.fov=PH.fov;camera.updateProjectionMatrix();
};
// ton soldat est visible sur les photos (en jeu, il est caché en vue subjective)
const _syncRigsPh=syncRigs;
syncRigs=function(dt,t){
 if(!(PH.on&&P&&P.rig&&P.alive))return _syncRigsPh(dt,t);
 // le temps d'une mise à jour, le joueur est animé comme les autres soldats
 P.isPlayer=false;try{_syncRigsPh(dt,t);}finally{P.isPlayer=true;}
};
// pas d'arme en vue subjective pendant les photos
const _vmUpdatePh=vmUpdate;
vmUpdate=function(dt,t,ent){if(PH.on){VM.root.visible=false;return;}return _vmUpdatePh(dt,t,ent);};
function phShot(){
 const F=PH_FILTERS[PH.filter],src=renderer.domElement;
 render(0,performance.now()/1000); // image fraîche : on la copie avant que le navigateur n'efface le tampon
 const W0=src.width,H0=src.height,c=document.createElement('canvas');c.width=W0;c.height=H0;const g=c.getContext('2d');
 g.filter=F.f||'none';g.drawImage(src,0,0);g.filter='none';
 if(F.vig){const r=g.createRadialGradient(W0/2,H0/2,Math.min(W0,H0)*.35,W0/2,H0/2,Math.max(W0,H0)*.75);r.addColorStop(0,'rgba(0,0,0,0)');r.addColorStop(1,'rgba(20,8,0,.6)');g.fillStyle=r;g.fillRect(0,0,W0,H0);}
 if(F.bars){const h=Math.round(H0*.11);g.fillStyle='#000';g.fillRect(0,0,W0,h);g.fillRect(0,H0-h,W0,h);}
 // petite signature en bas à droite
 g.font='800 '+Math.round(H0*.022)+'px Bahnschrift,Arial';g.textAlign='right';g.fillStyle='rgba(255,255,255,.75)';g.shadowColor='#000';g.shadowBlur=6;
 g.fillText('STRIKE ARENA · '+(MAP&&MAP.n?MAP.n.toUpperCase():''),W0-H0*.03,H0-H0*.03-(F.bars?Math.round(H0*.11):0));
 const a=document.createElement('a');const d=new Date(),p=n=>String(n).padStart(2,'0');
 a.download='strike-arena-'+d.getFullYear()+p(d.getMonth()+1)+p(d.getDate())+'-'+p(d.getHours())+p(d.getMinutes())+p(d.getSeconds())+'.png';
 a.href=c.toDataURL('image/png');a.click();
 const fl=document.querySelector('#photoUI .phflash');fl.classList.remove('go');void fl.offsetWidth;fl.classList.add('go');
 if(typeof sfx==='function')sfx('click');
 PH.lastShot=c;
}
// bouton dans le menu pause
(function(){
 const row=document.querySelector('#pause .row');if(!row)return;
 const b=document.createElement('button');b.className='btn alt cut';b.id='photoBtn';b.textContent='📷 MODE PHOTO';b.onclick=phEnter;
 row.insertBefore(b,row.children[1]||null);
})();
// on quitte proprement si la partie s'arrête
const _toMenuPh=toMenu;
toMenu=function(){if(PH.on)phExit();return _toMenuPh.apply(this,arguments);};
(function(){const s=document.createElement('style');s.textContent=`
#photoUI{position:fixed;inset:0;z-index:60;display:none;cursor:grab;user-select:none}
#photoUI.show{display:block}
#photoUI.grab{cursor:grabbing}
#photoUI .phtop{position:absolute;top:16px;left:50%;transform:translateX(-50%);font:900 1rem Bahnschrift,Arial;letter-spacing:4px;color:#fff;text-shadow:0 2px 8px #000;padding:6px 16px;border-radius:999px;background:#0007;border:1px solid #ffffff22}
#photoUI .phhelp{position:absolute;top:56px;left:50%;transform:translateX(-50%);font-size:.7rem;color:#c8d3e6;text-shadow:0 1px 4px #000;white-space:nowrap}
#photoUI .phbar{position:absolute;left:50%;bottom:18px;transform:translateX(-50%);display:flex;align-items:center;gap:14px;flex-wrap:wrap;justify-content:center;max-width:94vw;padding:12px 16px;border-radius:14px;background:#0a1020cc;border:1px solid #ffffff1a;backdrop-filter:blur(8px);cursor:default}
#photoUI .phf{display:flex;gap:6px;flex-wrap:wrap}
#photoUI .phf button{background:#16203a;color:#cfd8e6;border:2px solid #ffffff14;border-radius:8px;padding:7px 10px;font:800 .66rem Bahnschrift,Arial;letter-spacing:1px;cursor:pointer;text-transform:uppercase}
#photoUI .phf button.on{border-color:#ffd23a;color:#fff;background:#2a2a18}
#photoUI label{font:800 .62rem Bahnschrift,Arial;letter-spacing:2px;color:#8da0bd;display:flex;align-items:center;gap:6px}
#photoUI input[type=range]{width:90px;accent-color:#ffd23a}
#photoUI .btn{padding:9px 14px;font-size:.8rem}
#photoUI.bare .phbar,#photoUI.bare .phhelp,#photoUI.bare .phtop{display:none}
#photoUI .phbars i{position:absolute;left:0;right:0;height:11%;background:#000;display:none}
#photoUI .phbars i:first-child{top:0}#photoUI .phbars i:last-child{bottom:0}
#photoUI.cine .phbars i{display:block}
#photoUI .phvig{position:absolute;inset:0;pointer-events:none;display:none;background:radial-gradient(ellipse at center,transparent 45%,rgba(20,8,0,.6) 100%)}
#photoUI.vig .phvig{display:block}
#photoUI .phflash{position:absolute;inset:0;background:#fff;opacity:0;pointer-events:none}
#photoUI .phflash.go{animation:phFlash .45s ease-out}
@keyframes phFlash{0%{opacity:.85}100%{opacity:0}}
`;document.head.appendChild(s);})();
