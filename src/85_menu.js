/* =====================================================================
   MENU : modes, cartes, difficulté, armurerie 3D, personnalisation
   ===================================================================== */
const DCOL=['#7dff9f','#b6e65a','#ffd75e','#ff9a4a','#ff4655'];
function chipsRow(id,opts,get,set,redraw){
 const el=$(id);el.innerHTML='';
 opts.forEach(o=>{const b=document.createElement('div');b.className='chip';b.textContent=o[0];b.onclick=()=>{sfxUI();set(o[1]);saveCfg();(redraw||drawMenu)();};el.appendChild(b);});
 [...el.children].forEach((c,i)=>c.classList.toggle('on',opts[i][1]===get()));
}
function sfxUI(){if(AC)sfx('ui');}
function buildModeCards(){
 const el=$('modeCards');el.innerHTML='';
 for(const k in MODES){
  const m=MODES[k],c=document.createElement('div');c.className='mcard'+(cfg.mode===k?' on':'');c.style.setProperty('--c',m.c);
  c.innerHTML='<div class="ic">'+m.ic+'</div><div><b>'+m.n+'</b><span>'+m.desc+'</span></div>';
  c.onclick=()=>{initAudio();sfxUI();cfg.mode=k;saveCfg();drawMenu();};el.appendChild(c);
 }
}
function buildMapChips(){
 const el=$('mapChips');el.innerHTML='';
 for(const k in MAPS){const c=document.createElement('div');c.className='chip'+(cfg.map===k?' on':'');c.textContent=MAPS[k].n;c.onclick=()=>{initAudio();sfxUI();cfg.map=k;saveCfg();drawMenu();previewMapWorld();};el.appendChild(c);}
}
let previewMapId=null;
function previewMapWorld(){if(G.running||previewMapId===cfg.map)return;previewMapId=cfg.map;buildWorld(cfg.map);buildRadarMap();}
function buildDiffCards(){
 const el=$('cDiff');el.innerHTML='';
 DIFFS.forEach((d,i)=>{
  const c=document.createElement('div');c.className='dc'+(cfg.diff===i?' on':'');c.style.setProperty('--c',DCOL[i]);
  const bars=[(1-d.react)*100,clamp(100-d.spread*11,5,100),d.strafe*60+d.hear*40];
  c.innerHTML='<b>'+d.n.toUpperCase()+'</b>'+bars.map(b=>'<div class="bar"><i style="width:'+Math.round(b)+'%"></i></div>').join('');
  c.onclick=()=>{sfxUI();cfg.diff=i;saveCfg();drawMenu();};el.appendChild(c);
 });
 $('dDesc').textContent=DIFFS[cfg.diff].desc;
}
function drawMenu(){
 const m=MODES[cfg.mode];
 buildModeCards();buildMapChips();buildDiffCards();buildAgentRow();
 drawMapThumb($('mapThumb'),cfg.map);
 $('mapInfo').innerHTML='<b>'+MAPS[cfg.map].n+'</b><p>'+MAPS[cfg.map].desc+'</p>';
 $('gSide').style.display=m.team?'':'none';
 chipsRow('cSide',[['Attaquants (T)','t'],['Défenseurs (CT)','ct'],['Aléatoire','rnd']],()=>cfg.side,v=>cfg.side=v);
 if(m.team){
  $('lSize').textContent='Joueurs par équipe';
  const mx=(cfg.mode==='bomb'||cfg.mode==='rapid')?5:8;chipsRow('cSize',Array.from({length:mx},(_,i)=>[(i+1)+' v '+(i+1),i+1]),()=>Math.min(cfg.size,mx),v=>cfg.size=v);
 }else{
  $('lSize').textContent='Nombre de joueurs';
  chipsRow('cSize',[4,6,8,10,12].map(n=>[n+'',n]),()=>cfg.ffa,v=>cfg.ffa=v);
 }
 const lim=m.limits||[];$('gLimit').style.display=lim.length?'':'none';
 if(lim.length){
  $('lLimit').textContent=m.limitLabel;
  cfg.lim=cfg.lim||{};const key=({bomb:'rounds',tdm:'tdmKills',ffa:'ffaKills'})[cfg.mode];
  chipsRow('cLimit',lim.map(n=>[n+'',n]),()=>key?cfg[key]:(cfg.lim[cfg.mode]||lim[Math.floor(lim.length/2)]),v=>{if(key)cfg[key]=v;else cfg.lim[cfg.mode]=v;});
 }
 $('gEco').style.display=cfg.mode==='bomb'?'':'none';
 chipsRow('cEco',[['Réaliste',1],['Armes libres',0]],()=>cfg.eco,v=>cfg.eco=v);
 $('eDesc').textContent=cfg.eco?'Argent gagné à chaque manche, achats en boutique.':'Argent illimité : tu choisis n\'importe quelle arme.';
 updSummary();
}
function updSummary(){
 const e=$('sumbar');if(!e)return;
 const ld=cfg.loadout,m=MODES[cfg.mode];
 const size=m.team?cfg.size+' v '+cfg.size:cfg.ffa+' joueurs';
 const lim=cfg.mode==='train'?'60 s':cfg.mode==='br'?'dernier survivant':(MODES[cfg.mode].limits||[]).length&&!({bomb:1,tdm:1,ffa:1})[cfg.mode]?limitOf(cfg.mode)+' '+MODES[cfg.mode].limitLabel.split(' ')[0].toLowerCase():cfg.mode==='bomb'?cfg.rounds+' manches':cfg.mode==='tdm'?cfg.tdmKills+' éliminations':cfg.mode==='ffa'?cfg.ffaKills+' éliminations':GG_LADDER.length+' niveaux';
 e.innerHTML='<b>'+m.n+'</b> · '+MAPS[cfg.map].n+' · '+size+' · bots <b>'+DIFFS[cfg.diff].n+'</b> · '+lim+(cfg.mode==='bomb'?' · '+(cfg.eco?'économie réaliste':'armes libres'):'')+'<br>Loadout de départ : <b>'+(ld.p?W[ld.p].n:'—')+'</b> + <b>'+(ld.s?W[ld.s].n:'—')+'</b>';
}
/* ---------- onglets ---------- */
let tabNow='play',pvOn=false,lkOn=false;
document.querySelectorAll('.mtab').forEach(t=>t.onclick=()=>{
 initAudio();sfxUI();tabNow=t.dataset.t;
 document.querySelectorAll('.mtab').forEach(x=>x.classList.toggle('on',x===t));
 document.querySelectorAll('.tp').forEach(p=>p.classList.toggle('on',p.id==='tab-'+tabNow));
 pvOn=tabNow==='arms';if(pvOn){pvSet(pvKey);refreshArms();}
 lkOn=tabNow==='locker';if(lkOn){lkInit();buildLocker();}
 if(tabNow==='custom')drawXhPrev();
 if(tabNow==='boxes')buildBoxesTab();
 if(tabNow==='stats')buildStats();
 if(tabNow==='keys')buildBinds();
 refreshProfile();
});
/* ---------- armurerie 3D ---------- */
let pvKey=cfg.loadout.p||'ak',pvR=null,pvS=null,pvC=null,pvPivot=null;
function pvInit(){
 if(pvR)return;
 try{pvR=new THREE.WebGLRenderer({canvas:$('pv'),antialias:true,alpha:true});}catch(e){pvR=null;return;}
 pvR.setPixelRatio(Math.min(devicePixelRatio||1,2));pvR.setSize(560,320,false);pvR.outputEncoding=THREE.sRGBEncoding;pvR.toneMapping=THREE.ACESFilmicToneMapping;
 pvS=new THREE.Scene();pvC=new THREE.PerspectiveCamera(30,560/320,.05,20);pvC.position.set(0,.28,2.6);pvC.lookAt(0,0,0);
 pvS.add(new THREE.HemisphereLight(0xffffff,0x445566,1.1));
 const d=new THREE.DirectionalLight(0xffffff,2.6);d.position.set(2,3,2);pvS.add(d);
 const d2=new THREE.DirectionalLight(0x88aaff,1.6);d2.position.set(-3,1,-2);pvS.add(d2);
 const d3=new THREE.DirectionalLight(0xffb070,1.2);d3.position.set(0,-2,2);pvS.add(d3);
 pvS.environment=makeEnv(pvR);
 const fl=new THREE.Mesh(new THREE.CircleGeometry(1.3,40),new THREE.MeshStandardMaterial({color:C(0x1a2438),roughness:.4,metalness:.6}));fl.rotation.x=-Math.PI/2;fl.position.y=-.34;pvS.add(fl);
}
function pvSet(k){
 pvKey=k;pvInit();if(!pvR)return;
 if(pvPivot)pvS.remove(pvPivot);
 const g=gunParts(k,skinOf(k)),box=new THREE.Box3().setFromObject(g),c=box.getCenter(new THREE.Vector3()),sz=box.getSize(new THREE.Vector3());
 g.position.set(-c.x,-c.y,-c.z);pvPivot=new THREE.Group();pvPivot.add(g);pvPivot.scale.setScalar(1.9/Math.max(sz.x,sz.z,.3));pvPivot.rotation.y=Math.PI*.55;pvS.add(pvPivot);
}
function refreshArms(){
 const k=pvKey,w=W[k];
 document.querySelectorAll('#wlist .chip').forEach(c=>c.classList.toggle('on',c.dataset.k===k));
 drawSkins();
 $('pvName').textContent=w.n.toUpperCase();
 const bar=(l,v,mx,txt)=>'<div class="stat1"><em>'+l+'</em><b>'+txt+'</b><div class="bar"><i style="width:'+clamp(v/mx*100,3,100)+'%"></i></div></div>';
 $('pvStats').innerHTML=w.melee?bar('DÉGÂTS',w.dmg,120,w.dmg):bar('DÉGÂTS',w.dmg*(w.pel||1),150,Math.round(w.dmg*(w.pel||1))+(w.pel?'×'+w.pel:''))+bar('CADENCE',w.rpm,1000,w.rpm)+bar('CHARGEUR',w.mag,150,w.mag)+bar('PRÉCISION',100-w.spr*14,100,Math.round(100-w.spr*14)+'%')+bar('PRIX',w.price,5200,'$'+w.price);
 const eq=$('eqBtn'),slotKey=w.slot===0?'p':w.slot===1?'s':null;
 eq.style.display=slotKey?'':'none';
 if(slotKey){const cur=cfg.loadout[slotKey]===k;eq.textContent=cur?'✔ Équipée au départ':'Équiper au départ';eq.classList.toggle('on',cur);}
 $('eqInfo').textContent=slotKey?(w.slot===0?'Arme principale de départ (mode « Armes libres », Match à mort).':'Pistolet de départ ; en mode réaliste seuls les pistolets ≤ $300 sont équipés gratuitement.'):'Le skin du couteau est visible en jeu.';
 updSummary();
}
(function buildArms(){
 const wl=$('wlist');
 for(const [cn,list] of [['COUTEAU',['knife']]].concat(CATS.map(c=>[c[0].toUpperCase(),c[1]]))){
  const h=document.createElement('h5');h.textContent=cn;wl.appendChild(h);
  for(const k of list){const d=document.createElement('div');d.className='chip';d.dataset.k=k;d.innerHTML='<img src="'+weaponIcon(k,0)+'"><span>'+W[k].n+'</span>';d.onclick=()=>{sfxUI();pvSet(k);refreshArms();};wl.appendChild(d);}
 }
 drawSkins();
 $('eqBtn').onclick=()=>{sfxUI();const w=W[pvKey];cfg.loadout[w.slot===0?'p':'s']=pvKey;saveCfg();refreshArms();};
})();
function menuToast(msg){let t=$('mtoast');if(!t){t=document.createElement('div');t.id='mtoast';t.style.cssText='position:fixed;left:50%;bottom:6vh;transform:translateX(-50%);background:#161f33;border:1px solid var(--gold);color:#fff;padding:10px 20px;z-index:60;font-size:.85rem;letter-spacing:2px;transition:opacity .3s';document.body.appendChild(t);}t.textContent=msg;t.style.opacity=1;clearTimeout(t._h);t._h=setTimeout(()=>t.style.opacity=0,2400);}
function drawSkins(){
 const sk=$('skins');sk.innerHTML='';
 SKINS.forEach((s,i)=>{
  const own=ownsSkin(pvKey,i),d=document.createElement('div');
  d.style.borderColor=i===(cfg.skins[pvKey]||0)?'':'';d.style.borderLeft='3px solid '+rcol(s.q);
  d.innerHTML='<i style="background:'+skinSwatch(i)+'"></i>'+s.n+(own?'':' 🔒');
  if(!own)d.style.opacity=.45;
  if(i===(cfg.skins[pvKey]||0)&&own)d.classList.add('on');
  d.onclick=()=>{if(!own){sfx('deny');menuToast('Skin verrouillé — trouve-le dans les caisses !');return;}sfxUI();cfg.skins[pvKey]=i;saveCfg();iconCache={};pvSet(pvKey);refreshArms();};
  sk.appendChild(d);
 });
}

/* ---------- personnalisation ---------- */
const XHCOL=['#3dffa8','#ffffff','#27e8ff','#ffe14a','#ff3b3b','#ff58d6','#8a6bff','#ff9a2a'];
function drawXhPrev(){
 const cv=$('xhPrev'),c=cv.getContext('2d');c.clearRect(0,0,400,200);
 c.fillStyle='rgba(255,255,255,.04)';for(let i=0;i<14;i++)c.fillRect(i*30,0,1,200);
 drawCrosshair(c,200,100,cfg.xh.gap);
}
function buildCustom(){
 const sw=$('xhC');sw.innerHTML='';
 XHCOL.forEach(col=>{const i=document.createElement('i');i.style.background=col;i.style.setProperty('--c',col);if(cfg.xh.c===col)i.className='on';i.onclick=()=>{cfg.xh.c=col;saveCfg();buildCustom();drawXhPrev();};sw.appendChild(i);});
 const bind=(r,v,key)=>{const R=$(r);R.value=cfg.xh[key];$(v).textContent=cfg.xh[key];R.oninput=()=>{cfg.xh[key]=+R.value;$(v).textContent=R.value;saveCfg();drawXhPrev();};};
 bind('rXL','vXL','len');bind('rXT','vXT','th');bind('rXG','vXG','gap');
 const o=$('xhOpts');o.innerHTML='';
 [['Point central','dot'],['Contour noir','out']].forEach(([n,k])=>{const c=document.createElement('div');c.className='chip'+(cfg.xh[k]?' on':'');c.textContent=n;c.onclick=()=>{cfg.xh[k]=cfg.xh[k]?0:1;saveCfg();buildCustom();drawXhPrev();};o.appendChild(c);});
 const nm=$('pname');nm.value=cfg.name==='Vous'?'':cfg.name;nm.placeholder='Vous';nm.oninput=()=>{cfg.name=nm.value.trim()||'Vous';saveCfg();};
}
function buildOpts(){
 chipsRow('cGfx',[['Basse',0],['Moyenne',1],['Haute',2]],()=>cfg.gfx,v=>{cfg.gfx=v;resize();},buildOpts);
 chipsRow('cFx',[['Réduits',0],['Complets',1]],()=>cfg.fx,v=>cfg.fx=v,buildOpts);
 chipsRow('cFps',[['Non',0],['Oui',1]],()=>cfg.fps,v=>cfg.fps=v,buildOpts);
 chipsRow('cCine',[['Activée',1],['Désactivée',0]],()=>cfg.cine===0?0:1,v=>cfg.cine=v,buildOpts);
 chipsRow('cBob',[['Minimal',0],['Normal',1]],()=>cfg.bob,v=>cfg.bob=v,buildOpts);
 const rs=$('rSens'),rf=$('rFov'),rv=$('rVol');rs.value=cfg.sens;rf.value=cfg.fov;rv.value=cfg.vol;
 const sync=()=>{cfg.sens=+rs.value;cfg.fov=+rf.value;cfg.vol=+rv.value;$('vSens').textContent=cfg.sens.toFixed(2);$('vFov').textContent=cfg.fov+'°';$('vVol').textContent=Math.round(cfg.vol*100)+'%';setVolume(cfg.vol);saveCfg();};
 rs.oninput=rf.oninput=rv.oninput=sync;sync();
}
function buildAllMenu(){
 drawMenu();buildCustom();buildOpts();
 $('playBtn').onclick=()=>{initAudio();sfxUI();startMatch();buildRadarMap();};
}
