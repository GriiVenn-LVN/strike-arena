/* =====================================================================
   EXTRAS D'ARME & PROFIL : accessoires, charms, compteur de kills,
   sprays, traînées de balles, titres, styles de couteau.
   Les choix sont gratuits ou liés au niveau (lv) et se règlent dans
   l'onglet « Style ».
   ===================================================================== */
const CHARMS=[
 {id:'',n:'Aucun',lv:1},{id:'cube',n:'Dé',lv:1,c:0xf5f5f5},{id:'heart',n:'Cœur',lv:2,c:0xff4d6d},{id:'star',n:'Étoile',lv:3,c:0xffd23a},
 {id:'bear',n:'Nounours',lv:4,c:0xc98a55},{id:'orb',n:'Orbe',lv:5,c:0x6ee7ff},{id:'skull',n:'Crâne',lv:6,c:0xe8e8e8},{id:'bolt',n:'Éclair',lv:8,c:0xfff04a}
];
const SPRAYS=['smile','heart','skull','bolt','flame','crown','target','ghost'];
const SPRAY_N={smile:'Sourire',heart:'Cœur',skull:'Crâne',bolt:'Éclair',flame:'Flamme',crown:'Couronne',target:'Cible',ghost:'Fantôme'};
const TRAILS=[
 {id:'',n:'Standard',lv:1},{id:'cyan',n:'Cyan',lv:2,c:0x55e6ff},{id:'red',n:'Rouge',lv:3,c:0xff4655},{id:'lime',n:'Lime',lv:4,c:0x9dff5a},
 {id:'gold',n:'Or',lv:6,c:0xffc933},{id:'violet',n:'Violet',lv:7,c:0xb36bff},{id:'rainbow',n:'Arc-en-ciel',lv:10}
];
const TITLES=[
 {id:'',n:'—',lv:1},{id:'rookie',n:'Recrue',lv:1},{id:'sharp',n:'Œil de lynx',lv:3},{id:'ace',n:'As de l\'arène',lv:5},
 {id:'bomb',n:'Artificier',lv:7},{id:'ghost',n:'Fantôme',lv:9},{id:'legend',n:'Légende vivante',lv:12}
];
const KNIVES=[{id:'classic',n:'Tactique',lv:1},{id:'karambit',n:'Karambit',lv:3},{id:'bayonet',n:'Baïonnette',lv:5},{id:'tanto',n:'Tanto',lv:7},
 {id:'flip',n:'Pliant',lv:10},{id:'butterfly',n:'Papillon',lv:12},{id:'huntsman',n:'Chasseur',lv:15},{id:'falchion',n:'Fauchon',lv:18},
 {id:'bowie',n:'Bowie',lv:22},{id:'gut',n:'Éviscérateur',lv:26},{id:'stiletto',n:'Stylet',lv:30},{id:'talon',n:'Serre',lv:35}];
cfg.att=cfg.att||{};cfg.charm=cfg.charm||'';cfg.spray=cfg.spray||'smile';cfg.trail=cfg.trail||'';cfg.title=cfg.title||'';cfg.knife=cfg.knife||'classic';cfg.counter=cfg.counter===undefined?1:cfg.counter;
PROF.wk=PROF.wk||{};
const myLv=()=>levelInfo().level;
const magMax=(e,k)=>Math.ceil(W[k].mag*attMods(e,k).mag*(papOf(e,k)?1.5:1));

/* ---------- modèles : accessoires, charms, compteur ---------- */
const attMat={blk:new THREE.MeshStandardMaterial({color:0x1b1e24,roughness:.45,metalness:.8}),glass:new THREE.MeshStandardMaterial({color:0xff2a2a,emissive:0xff2a2a,emissiveIntensity:.9,roughness:.2}),dark:new THREE.MeshStandardMaterial({color:0x2c3138,roughness:.5,metalness:.7})};
function charmMesh(id){
 const ch=CHARMS.find(c=>c.id===id);if(!ch||!id)return null;
 const g=new THREE.Group(),m=new THREE.MeshStandardMaterial({color:ch.c,roughness:.35,metalness:.2,emissive:ch.c,emissiveIntensity:.15});
 let b;
 switch(id){
  case 'cube':b=new THREE.Mesh(new THREE.BoxGeometry(.035,.035,.035),m);break;
  case 'heart':b=new THREE.Group();[-1,1].forEach(s=>{const l=new THREE.Mesh(new THREE.SphereGeometry(.02,10,8),m);l.position.set(s*.015,.012,0);b.add(l);});{const t=new THREE.Mesh(new THREE.ConeGeometry(.034,.045,4),m);t.rotation.z=Math.PI;t.position.y=-.012;b.add(t);}break;
  case 'star':b=new THREE.Mesh(new THREE.OctahedronGeometry(.032,0),m);b.scale.set(1,1,.45);break;
  case 'bear':b=new THREE.Group();{const h=new THREE.Mesh(new THREE.SphereGeometry(.026,12,10),m);b.add(h);[-1,1].forEach(s=>{const e=new THREE.Mesh(new THREE.SphereGeometry(.011,8,8),m);e.position.set(s*.02,.021,0);b.add(e);});}break;
  case 'orb':b=new THREE.Mesh(new THREE.SphereGeometry(.03,14,12),new THREE.MeshStandardMaterial({color:ch.c,emissive:ch.c,emissiveIntensity:.8,roughness:.1}));break;
  case 'skull':b=new THREE.Group();{const h=new THREE.Mesh(new THREE.SphereGeometry(.027,12,10),m);const j=new THREE.Mesh(new THREE.BoxGeometry(.022,.014,.02),m);j.position.y=-.026;b.add(h,j);[-1,1].forEach(s=>{const e=new THREE.Mesh(new THREE.SphereGeometry(.007,6,6),attMat.blk);e.position.set(s*.01,.003,.022);b.add(e);});}break;
  default:b=new THREE.Mesh(new THREE.TetrahedronGeometry(.03,0),m);
 }
 const cord=new THREE.Mesh(new THREE.CylinderGeometry(.002,.002,.06,4),attMat.dark);cord.position.y=.03;
 b.position.y=-.03;g.add(cord,b);g.userData.sw=b;return g;
}
function counterMesh(k){
 const cv=document.createElement('canvas');cv.width=128;cv.height=48;
 const tex=new THREE.CanvasTexture(cv),m=new THREE.Mesh(new THREE.PlaneGeometry(.1,.0375),new THREE.MeshBasicMaterial({map:tex,transparent:true}));
 m.userData={cv,tex,k,last:-1};m.rotation.y=Math.PI/2;return m;
}
function counterDraw(m){
 const n=PROF.wk[m.userData.k]||0;if(n===m.userData.last)return;m.userData.last=n;
 const c=m.userData.cv.getContext('2d');c.fillStyle='#0b1018';c.fillRect(0,0,128,48);c.strokeStyle='#ff4655';c.lineWidth=3;c.strokeRect(2,2,124,44);
 c.fillStyle='#8aa';c.font='bold 11px monospace';c.textAlign='center';c.fillText('ÉLIMINATIONS',64,15);
 c.fillStyle='#fff';c.font='bold 24px monospace';c.fillText(String(n).padStart(4,'0'),64,40);m.userData.tex.needsUpdate=true;
}
function redDot(u){
 // viseur point rouge creux : on voit à travers, le point est au centre de la ligne de visée
 const o=new THREE.Group(),base=(u.sight||.07),cy=base+.034,z=-.15;
 o.add(rb(.03,.012,.07,attMat.dark,0,base+.006,z,.003));
 o.add(rb(.012,.024,.05,attMat.blk,0,base+.018,z,.003));
 const hous=new THREE.Mesh(new THREE.CylinderGeometry(.024,.024,.05,28,1,true),new THREE.MeshStandardMaterial({color:0x1b1e24,roughness:.45,metalness:.8,side:THREE.DoubleSide}));
 hous.rotation.x=Math.PI/2;hous.position.set(0,cy,z);o.add(hous);
 const ring=new THREE.Mesh(new THREE.TorusGeometry(.024,.004,8,28),attMat.blk);ring.position.set(0,cy,z-.025);o.add(ring);
 const ring2=ring.clone();ring2.position.z=z+.025;o.add(ring2);
 const lens=new THREE.Mesh(new THREE.CircleGeometry(.0225,28),new THREE.MeshBasicMaterial({color:0x9fffe0,transparent:true,opacity:.1,depthWrite:false,side:THREE.DoubleSide}));
 lens.position.set(0,cy,z-.024);o.add(lens);
 const dot=new THREE.Mesh(new THREE.SphereGeometry(.0013,8,6),new THREE.MeshBasicMaterial({color:0xff2030,toneMapped:false}));
 dot.position.set(0,cy,z-.023);o.add(dot);
 u.sight=cy;u.optic=true;
 return o;
}
function decorateVM(g,k){
 const u=g.userData,w=W[k];if(w.melee)return;
 attBuild(g,k,attSel(P,k));
 if(cfg.charm&&cfg.charm!==''){const ch=charmMesh(cfg.charm);if(ch){ch.position.set(.032,-.07,.05);g.add(ch);g.userData.charm=ch;}}
 if(cfg.counter&&(w.cat!=='pistol'||true)){const c=counterMesh(k);c.position.set(.031,.045,-.12);g.add(c);g.userData.counter=c;counterDraw(c);}
}
function extrasVmUpdate(t){
 const g=VM&&VM.gun;if(!g||!g.userData)return;
 const ch=g.userData.charm;if(ch){const s=ch.userData.sw;ch.rotation.z=Math.sin(t*3.1)*.28+(VM.sway?VM.sway.x||0:0)*.8;ch.rotation.x=Math.cos(t*2.3)*.18;s.rotation.y=t*1.2;}
 if(g.userData.counter)counterDraw(g.userData.counter);
}
/* couteaux : variantes de lame (vue arme uniquement) */
const _buildKnife=BUILDERS.melee;
BUILDERS.melee=function(k,M){
 const st=cfg.knife;if(!st||st==='classic'||myLv()<(KNIVES.find(x=>x.id===st)||{lv:1}).lv)return _buildKnife(k,M);
 const g=new THREE.Group(),BL=M.body&&M.body.userData&&M.body.userData.skinned?M.body:M.steel; // le skin couvre aussi la lame
 const fin=(len,mz)=>finishGun(g,{len,muzzle:mz,right:V3(0,0,.04),left:V3(0,0,.04),twoHand:false,eject:V3(0,0,0),sight:.0});
 const grip=(z0,L,mat)=>{g.add(rb(.021,.032,L,mat||M.blk,0,0,z0+L/2,.006),rb(.024,.035,.014,M.dark,0,0,z0+L,.004));};
 if(st==='flip'){
  g.add(polyZY([[-.02,.014],[-.17,.016],[-.24,.004],[-.25,-.006],[-.16,-.014],[-.02,-.014]],.006,BL,0,.0012));
  {const t=new THREE.Mesh(new THREE.TorusGeometry(.009,.003,6,12),BL);t.position.set(0,.02,-.04);t.rotation.y=Math.PI/2;g.add(t);}
  grip(-.01,.11);return fin(.29,-.25);
 }
 if(st==='butterfly'){
  g.add(polyZY([[-.02,.012],[-.2,.012],[-.25,.0],[-.2,-.01],[-.02,-.012]],.005,BL,0,.001),rb(.003,.003,.17,M.dark,0,.0,-.12,.001));
  for(const s of [-1,1]){g.add(rb(.008,.03,.12,M.dark,s*.007,0,.05,.003));for(let i=0;i<4;i++)g.add(rb(.009,.012,.014,M.rubber,s*.007,0,.0+i*.028,.002));}
  return fin(.3,-.25);
 }
 if(st==='huntsman'){
  g.add(polyZY([[-.02,.018],[-.2,.018],[-.25,.03],[-.3,.006],[-.3,-.004],[-.24,-.018],[-.02,-.018]],.007,BL,0,.0012));
  for(let i=0;i<8;i++)g.add(rb(.004,.006,.006,BL,0,.022,-.05-i*.016,.001,.7));
  g.add(rb(.012,.07,.012,M.dark,0,0,-.012,.003));grip(-.005,.12,M.wood);return fin(.35,-.3);
 }
 if(st==='falchion'){
  g.add(polyZY([[-.02,.014],[-.14,.02],[-.24,.03],[-.29,.02],[-.27,-.004],[-.18,-.016],[-.02,-.016]],.006,BL,0,.0012));
  grip(-.005,.11);return fin(.32,-.29);
 }
 if(st==='bowie'){
  g.add(polyZY([[-.02,.02],[-.22,.02],[-.27,.032],[-.34,.004],[-.33,-.008],[-.26,-.022],[-.02,-.022]],.008,BL,0,.0014));
  g.add(rb(.012,.08,.014,new THREE.MeshStandardMaterial({color:0xc9a040,metalness:1,roughness:.3}),0,0,-.012,.003));grip(-.005,.13,M.wood);return fin(.38,-.34);
 }
 if(st==='gut'){
  g.add(polyZY([[-.02,.016],[-.12,.016],[-.15,.026],[-.17,.016],[-.16,.008],[-.2,.012],[-.25,-.004],[-.2,-.016],[-.02,-.016]],.006,BL,0,.0012));
  grip(-.005,.11);return fin(.3,-.25);
 }
 if(st==='stiletto'){
  g.add(polyZY([[-.02,.008],[-.28,.006],[-.33,.0],[-.28,-.006],[-.02,-.008]],.005,BL,0,.001),rb(.004,.05,.008,M.steel,0,0,-.014,.002));
  grip(-.005,.12,M.dark);return fin(.36,-.33);
 }
 if(st==='talon'){
  g.add(polyZY([[-.02,.012],[-.12,.04],[-.21,.03],[-.25,-.03],[-.21,-.07],[-.19,-.035],[-.14,-.006],[-.04,-.014]],.008,BL,0,.0014));
  {const t=new THREE.Mesh(new THREE.TorusGeometry(.026,.005,8,16),M.dark);t.position.set(0,-.02,.075);t.rotation.y=Math.PI/2;g.add(t);}
  grip(-.005,.07);return fin(.3,-.25);
 }
 if(st==='karambit'){
  g.add(polyZY([[-.02,.01],[-.1,.03],[-.17,.012],[-.2,-.04],[-.17,-.075],[-.15,-.04],[-.12,-.01],[-.04,-.01]],.007,BL,0,.0012),new THREE.Mesh(new THREE.TorusGeometry(.02,.004,6,14),M.dark));
  g.children[1].position.set(0,-.02,.0);g.children[1].rotation.y=Math.PI/2;
  g.add(rb(.022,.034,.1,M.blk,0,0,.04,.007),rb(.024,.036,.016,M.dark,0,0,.095,.004));
  return finishGun(g,{len:.3,muzzle:-.2,right:V3(0,0,.04),left:V3(0,0,.04),twoHand:false,eject:V3(0,0,0),sight:.0});
 }
 if(st==='bayonet'){
  g.add(polyZY([[-.02,.017],[-.25,.017],[-.31,.003],[-.31,-.006],[-.02,-.017]],.006,BL,0,.0012),rb(.004,.003,.22,M.dark,0,.0,-.14,.001),rb(.01,.012,.07,M.dark,0,.0,-.2,.001));
  g.add(rb(.036,.03,.016,M.dark,0,0,-.012,.003),rb(.02,.032,.1,M.rubber,0,0,.04,.006),rb(.026,.036,.014,M.dark,0,0,.095,.004));
  return finishGun(g,{len:.34,muzzle:-.32,right:V3(0,0,.04),left:V3(0,0,.04),twoHand:false,eject:V3(0,0,0),sight:.0});
 }
 g.add(polyZY([[-.02,.016],[-.2,.016],[-.27,-.004],[-.27,-.014],[-.02,-.016]],.007,BL,0,.0012),rb(.003,.004,.2,M.dark,0,.0,-.14,.001));
 g.add(rb(.03,.04,.012,M.dark,0,0,-.012,.003),rb(.02,.03,.11,M.blk,0,0,.045,.006),rb(.024,.034,.014,M.dark,0,0,.105,.004));
 return finishGun(g,{len:.3,muzzle:-.27,right:V3(0,0,.04),left:V3(0,0,.04),twoHand:false,eject:V3(0,0,0),sight:.0});
};
/* ---------- compteur / traînées / sprays ---------- */
function extrasKill(att,w){
 if(!att.isPlayer||!w||!w.n)return;
 const k=Object.keys(W).find(x=>W[x]===w);if(!k)return;
 PROF.wk[k]=(PROF.wk[k]||0)+1;
}
function trailCol(e){
 if(!e.isPlayer||myLv()<(TRAILS.find(x=>x.id===cfg.trail)||{lv:1}).lv)return undefined;
 if(cfg.trail==='rainbow'){const c=new THREE.Color().setHSL((G.t*1.7)%1,1,.6);return c.getHex();}
 const t=TRAILS.find(x=>x.id===cfg.trail);return t&&t.c;
}
const SPRAYS_ON=[];let sprayCd=0;
function drawSpray(id){
 const cv=document.createElement('canvas');cv.width=cv.height=128;const c=cv.getContext('2d');
 c.translate(64,64);c.lineWidth=7;c.lineJoin=c.lineCap='round';
 const col={smile:'#ffd23a',heart:'#ff4d6d',skull:'#f2f2f2',bolt:'#fff04a',flame:'#ff7a2a',crown:'#ffc933',target:'#ff4655',ghost:'#e8f1ff'}[id];
 c.fillStyle=c.strokeStyle=col;
 switch(id){
  case 'smile':c.beginPath();c.arc(0,0,48,0,TAU);c.stroke();c.beginPath();c.arc(0,6,28,.15*Math.PI,.85*Math.PI);c.stroke();c.beginPath();c.arc(-17,-14,6,0,TAU);c.arc(17,-14,6,0,TAU);c.fill();break;
  case 'heart':c.beginPath();c.moveTo(0,40);c.bezierCurveTo(-60,-5,-30,-50,0,-18);c.bezierCurveTo(30,-50,60,-5,0,40);c.fill();break;
  case 'skull':c.beginPath();c.arc(0,-8,36,0,TAU);c.fill();c.fillRect(-20,20,40,22);c.fillStyle='#000';c.beginPath();c.arc(-14,-8,10,0,TAU);c.arc(14,-8,10,0,TAU);c.fill();c.fillRect(-4,8,8,10);break;
  case 'bolt':c.beginPath();c.moveTo(14,-56);c.lineTo(-26,6);c.lineTo(-2,6);c.lineTo(-14,56);c.lineTo(28,-10);c.lineTo(4,-10);c.closePath();c.fill();break;
  case 'flame':c.beginPath();c.moveTo(0,-56);c.bezierCurveTo(40,-20,50,10,30,38);c.bezierCurveTo(14,56,-30,56,-36,28);c.bezierCurveTo(-42,0,-14,-14,-8,-36);c.bezierCurveTo(-4,-28,0,-40,0,-56);c.fill();break;
  case 'crown':c.beginPath();c.moveTo(-50,32);c.lineTo(-50,-20);c.lineTo(-24,6);c.lineTo(0,-34);c.lineTo(24,6);c.lineTo(50,-20);c.lineTo(50,32);c.closePath();c.fill();break;
  case 'target':[46,30,14].forEach((r,i)=>{c.beginPath();c.arc(0,0,r,0,TAU);i%2?c.fill():c.stroke();});break;
  default:c.beginPath();c.arc(0,-8,38,Math.PI,0);c.lineTo(38,44);for(let i=0;i<4;i++)c.lineTo(38-(i+1)*19,i%2?44:30);c.closePath();c.fill();c.fillStyle='#223';c.beginPath();c.arc(-13,-10,7,0,TAU);c.arc(13,-10,7,0,TAU);c.fill();
 }
 const t=new THREE.CanvasTexture(cv);return t;
}
const sprayTex={};
function doSpray(){
 if(!P||!P.alive||G.t<sprayCd||G.state==='freeze'&&G.mode==='bomb')return;
 const d=dirOf(P.yaw,P.pitch),ox=P.x,oy=P.y+P.eyeH,oz=P.z,t=rayWall(ox,oy,oz,d[0],d[1],d[2],4.5);
 if(t>=4.5){uiToast('Trop loin d\'une surface');return;}
 const hx=ox+d[0]*t,hy=oy+d[1]*t,hz=oz+d[2]*t;
 const ax=Math.abs(d[0])>Math.abs(d[2]),nx=ax?-Math.sign(d[0]):0,nz=ax?0:-Math.sign(d[2]);
 if(Math.abs(d[1])>.8){uiToast('Vise un mur');return;}
 const tex=sprayTex[cfg.spray]||(sprayTex[cfg.spray]=drawSpray(cfg.spray));
 const m=new THREE.Mesh(new THREE.PlaneGeometry(1.1,1.1),new THREE.MeshBasicMaterial({map:tex,transparent:true,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-2}));
 m.position.set(hx+nx*.03,hy,hz+nz*.03);m.rotation.y=Math.atan2(nx,nz);scene.add(m);
 SPRAYS_ON.push(m);if(SPRAYS_ON.length>12)scene.remove(SPRAYS_ON.shift());
 sprayCd=G.t+4;sfx('smoke',P.x,P.z,.25);
}
function clearSprays(){for(const m of SPRAYS_ON)scene.remove(m);SPRAYS_ON.length=0;}

/* ---------- onglet « Style » ---------- */
function titleName(){const t=TITLES.find(x=>x.id===cfg.title);return t&&t.id&&myLv()>=t.lv?t.n:'';}
function buildExtrasTab(){
 const tabs=$('mtabs');if(!tabs||$('tab-style'))return;
 const tb=document.createElement('div');tb.className='mtab';tb.dataset.t='style';tb.textContent='Style';
 tabs.insertBefore(tb,tabs.querySelector('[data-t="stats"]'));
 const p=document.createElement('div');p.className='tp';p.id='tab-style';
 p.innerHTML='<div class="custgrid" id="styleGrid"></div>';
 $('tab-keys').parentNode.appendChild(p);
 const css=document.createElement('style');css.textContent='.stl{margin-bottom:16px}.stl h4{font-size:.7rem;letter-spacing:2.5px;color:var(--dim);margin:0 0 8px;text-transform:uppercase}.chip.lock{opacity:.4;cursor:not-allowed}.chip small{display:block;font-size:.6rem;opacity:.7;margin:0}';
 document.head.appendChild(css);
}
// sections de choix (chips) réutilisées par l'onglet Style et par Réglages › Plus d'options
function stlSecMaker(el,redraw){
 const lv=myLv();
 return (title,items,get,set,fmt)=>{
  const d=document.createElement('div');d.className='stl grp';d.innerHTML='<h4>'+title+'</h4><div class="chips"></div>';
  const box=d.querySelector('.chips');
  items.forEach(it=>{const ok=lv>=(it.lv||1),c=document.createElement('div');c.className='chip'+(get(it)?' on':'')+(ok?'':' lock');c.innerHTML=fmt(it)+(ok?'':'<small>Niveau '+it.lv+'</small>');
   c.onclick=()=>{if(!ok){sfxUI();uiToast('Débloqué au niveau '+it.lv);return;}sfxUI();set(it);saveCfg();redraw();};box.appendChild(c);});
  el.appendChild(d);
 };
}
function drawAmbiance(){const el=$('ambBox');if(!el)return;el.innerHTML='';ambianceSections(stlSecMaker(el,drawAmbiance));}
function drawExtrasTab(){
 const el=$('styleGrid');if(!el)return;const lv=myLv();el.innerHTML='';
 const sec=stlSecMaker(el,drawExtrasTab);
 {const d=document.createElement('div');d.className='stl grp';d.innerHTML='<h4>Accessoires d\'armes</h4><small>Silencieux, poignées, chargeurs… se règlent dans <b>Arsenal › Armes</b> (panneau <b>Armurier</b>). Les viseurs et leur réticule : <b>Arsenal › Viseurs</b>.</small>';el.appendChild(d);}
 sec('Charm d\'arme',CHARMS,it=>cfg.charm===it.id,it=>cfg.charm=it.id,it=>it.n);
 sec('Compteur d\'éliminations',[{id:1,n:'Affiché',lv:1},{id:0,n:'Masqué',lv:1}],it=>cfg.counter===it.id,it=>cfg.counter=it.id,it=>it.n);
 sec('Couteau',KNIVES,it=>cfg.knife===it.id,it=>cfg.knife=it.id,it=>it.n);
 sec('Traînée de balles',TRAILS,it=>cfg.trail===it.id,it=>cfg.trail=it.id,it=>it.n);
 sec('Spray (touche J)',SPRAYS.map((s,i)=>({id:s,n:SPRAY_N[s],lv:1+(i>>1)})),it=>cfg.spray===it.id,it=>cfg.spray=it.id,it=>it.n);
 sec('Titre de profil',TITLES,it=>cfg.title===it.id,it=>cfg.title=it.id,it=>it.n);
 if(!$('ambBox'))ambianceSections(sec); // sinon : dans Réglages › Plus d'options
 const kills=Object.keys(PROF.wk).sort((a,b)=>PROF.wk[b]-PROF.wk[a]).slice(0,5).map(k=>W[k].n+' : '+PROF.wk[k]).join(' · ');
 const s=document.createElement('div');s.className='stl grp';s.innerHTML='<h4>Compteurs d\'armes</h4><small>'+(kills||'Aucune élimination enregistrée pour le moment.')+'</small>';el.appendChild(s);
}
buildExtrasTab();
document.querySelectorAll('.mtab[data-t="style"]').forEach(t=>t.addEventListener('click',drawExtrasTab));
