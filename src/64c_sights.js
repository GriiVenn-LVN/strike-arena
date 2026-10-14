/* =====================================================================
   VISEURS PERSONNALISABLES
   - chaque arme a un emplacement « Optique » (liste par catégorie dans
     OPTIC_CAT, 64b_gunsmith) ; les lunettes (ov:1) passent en vue plein écran
   - chaque viseur a son réticule : forme + couleur (cfg.ret[optique])
   - onglet Arsenal › Viseurs : choix du viseur par arme, du réticule,
     aperçu en direct, « appliquer à toutes les armes compatibles »
   ===================================================================== */
const RET_SHAPES=[['dot','Point'],['circle','Cercle'],['cross','Croix'],['chevron','Chevron'],['duplex','Duplex'],['mildot','Mil-dot']];
const RET_COLS=['#ff2a3a','#3dff6e','#33e0ff','#ffe03a','#ff4fd8','#ffffff','#101010'];
// 'scope' = lunette d'origine des snipers (aucune optique choisie)
const RET_DEF={reddot:{s:'dot',c:'#ff2a3a'},mini:{s:'dot',c:'#ff2a3a'},holo:{s:'circle',c:'#ff2a3a'},acog:{s:'chevron',c:'#ff3a2a'},
 sc4:{s:'duplex',c:'#101010'},sc6:{s:'duplex',c:'#101010'},sc8:{s:'mildot',c:'#101010'},sc10:{s:'mildot',c:'#101010'},scope:{s:'cross',c:'#101010'}};
cfg.ret=cfg.ret||{};
const retOf=o=>Object.assign({},RET_DEF[o]||RET_DEF.reddot,cfg.ret[o]||{});
const opticNone=k=>W[k]&&W[k].cat==='sniper'?'Lunette d\'origine':'Mires d\'origine';
// optique réellement montée (respecte niveau et catégorie)
function optOf(e,k){const o=attSel(e,k).optic;return o&&hasAtt(e,k,o)?o:null;}
// visée plein écran ? (lunettes, ou sniper sans optique)
function sightOv(e,w){
 if(e&&e.isPlayer){const wi=curWi(e);if(wi&&W[wi.k]===w){const o=optOf(e,wi.k);if(o)return !!ATTS[o].ov;}}
 return !!w.overlay;
}
function sightZoom(e,w){const wi=e&&e.isPlayer?curWi(e):null;return (wi&&W[wi.k]===w&&attMods(e,wi.k).zoom)||w.zoom||ADS_ZOOM[w.cat]||1.1;}

/* ---------- dessin d'un réticule (canvas 2D) ---------- */
// big = réticule de lunette plein écran (R = rayon de la lunette)
function drawReticle(c,cx,cy,R,sh,col,big){
 const lw=big?2:Math.max(2,R*.07),dark=col==='#101010';
 c.save();c.strokeStyle=c.fillStyle=col;c.lineCap='round';
 if(!dark){c.shadowColor=col;c.shadowBlur=big?5:R*.12;}
 const dot=r=>{c.beginPath();c.arc(cx,cy,r,0,Math.PI*2);c.fill();};
 const line=(x1,y1,x2,y2,w)=>{c.lineWidth=w||lw;c.beginPath();c.moveTo(x1,y1);c.lineTo(x2,y2);c.stroke();};
 switch(sh){
  case 'dot':dot(big?Math.max(3,R*.012):R*.14);break;
  case 'circle':c.lineWidth=lw;c.beginPath();c.arc(cx,cy,R*(big?.14:.72),0,Math.PI*2);c.stroke();dot(big?Math.max(2.5,R*.009):R*.09);break;
  case 'cross':{const g=R*(big?.025:.16),e=R*(big?1:.9);line(cx-e,cy,cx-g,cy);line(cx+g,cy,cx+e,cy);line(cx,cy-e,cx,cy-g);line(cx,cy+g,cx,cy+e);dot(big?2:lw*.7);break;}
  case 'chevron':{const s=R*(big?.07:.38);line(cx-s,cy+s*.85,cx,cy);line(cx,cy,cx+s,cy+s*.85);line(cx,cy+s*1.4,cx,cy+R*(big?1:.95),big?lw:lw*.6);
   line(cx-R*(big?1:.95),cy,cx-s*1.5,cy,big?lw:lw*.6);line(cx+s*1.5,cy,cx+R*(big?1:.95),cy,big?lw:lw*.6);break;}
  case 'duplex':{const t=lw*(big?3:2.2),a=R*.4,e=R;
   line(cx-e,cy,cx-a,cy,t);line(cx+a,cy,cx+e,cy,t);line(cx,cy+a,cx,cy+e,t);line(cx,cy-e,cx,cy-a,t);
   line(cx-a,cy,cx+a,cy,big?1.3:lw*.6);line(cx,cy-a,cx,cy+a,big?1.3:lw*.6);break;}
  case 'mildot':{const e=R,th=big?1.3:lw*.6;line(cx-e,cy,cx+e,cy,th);line(cx,cy-e,cx,cy+e,th);
   const st=R*.13,r=big?Math.max(2.5,R*.01):R*.04;
   for(let i=1;i<=4;i++)for(const [dx,dy] of [[1,0],[-1,0],[0,1],[0,-1]]){c.beginPath();c.arc(cx+dx*st*i,cy+dy*st*i,r,0,Math.PI*2);c.fill();}break;}
 }
 c.restore();
}
/* ---------- réticules 3D (texture sur la lentille) ---------- */
const RET_TEX={};
function retTex(sh,col){
 const key=sh+col;if(RET_TEX[key])return RET_TEX[key];
 const cv=document.createElement('canvas');cv.width=cv.height=128;drawReticle(cv.getContext('2d'),64,64,58,sh,col,false);
 return RET_TEX[key]=new THREE.CanvasTexture(cv);
}
function retMesh(o,size){
 const r=retOf(o);
 return new THREE.Mesh(new THREE.PlaneGeometry(size,size),new THREE.MeshBasicMaterial({map:retTex(r.s,r.c),transparent:true,depthWrite:false,toneMapped:false,side:THREE.DoubleSide}));
}
// remplace le point rouge sphérique de redDot() par le réticule choisi
function retSwapDot(g,o,size){
 let dot=null;g.traverse(m=>{if(!dot&&m.isMesh&&m.geometry&&m.geometry.type==='SphereGeometry')dot=m;});
 if(!dot)return;dot.visible=false;const r=retMesh(o,size);r.position.copy(dot.position);dot.parent.add(r);
}
/* ---------- réticule de la lunette plein écran ---------- */
function scopeRetUpdate(){
 const el=$('scope');if(!el||el.style.display==='none'||!P)return;
 let cv=$('scopeRet');
 if(!cv){cv=document.createElement('canvas');cv.id='scopeRet';cv.style.cssText='position:absolute;inset:0;width:100%;height:100%;pointer-events:none';el.appendChild(cv);el.classList.add('cret');
  const s=document.createElement('style');s.textContent='#scope.cret::before,#scope.cret::after{display:none}';document.head.appendChild(s);}
 const wi=curWi(P),o=(wi&&optOf(P,wi.k))||'scope',r=retOf(o),key=r.s+r.c+innerWidth+'x'+innerHeight;
 if(cv._k===key)return;cv._k=key;cv.width=innerWidth;cv.height=innerHeight;
 drawReticle(cv.getContext('2d'),innerWidth/2,innerHeight/2,innerHeight*.335,r.s,r.c,true);
}

/* ---------- onglet Arsenal › Viseurs ---------- */
const SIGHT_CATS=[['pistol','Pistolets'],['smg','Mitraillettes'],['shotgun','Pompes'],['rifle','Fusils'],['lmg','Mitrailleuses'],['sniper','Snipers']];
let svKey=null;
function sightsTabBuild(){
 const tabs=$('mtabs');if(!tabs||$('tab-sights'))return;
 const tb=document.createElement('div');tb.className='mtab';tb.dataset.t='sights';tb.textContent='Viseurs';tabs.appendChild(tb);
 const p=document.createElement('div');p.className='tp';p.id='tab-sights';
 p.innerHTML='<div class="svgrid"><div class="svw" id="svWeap"></div><div class="svmid"><canvas id="svCv" width="640" height="400"></canvas><div id="svInfo"></div></div><div class="svopt"><div id="svList"></div><div id="svRet"></div></div></div>';
 $('tab-keys').parentNode.appendChild(p);
 const s=document.createElement('style');s.textContent=`
.svgrid{display:grid;grid-template-columns:230px minmax(320px,1fr) 330px;gap:22px;height:100%;min-height:0}
.svgrid>div{min-height:0;overflow:auto;padding-right:4px}
.svw h5,.svopt h5{font-size:.6rem;letter-spacing:3px;color:#8da0bd;margin:12px 0 6px;text-transform:uppercase}
.svw h5:first-child,.svopt h5:first-child{margin-top:0}
.svw .chips{display:flex;flex-wrap:wrap;gap:5px}
.svw .chip{padding:6px 9px;font-size:.72rem}
.svw .chip em{font-style:normal;color:#ffb35c;margin-left:4px}
#svCv{width:100%;aspect-ratio:16/10;border-radius:10px;background:#0b1220;display:block}
#svInfo{margin-top:10px;font-size:.8rem;color:#b8c5da;line-height:1.5}
#svInfo b{color:#fff;letter-spacing:1.5px}
.svo{padding:9px 11px;margin-bottom:6px;border:1px solid #ffffff22;border-radius:8px;background:#121b2b;cursor:pointer;font-size:.78rem;color:#dfe8f5;display:flex;justify-content:space-between;align-items:center;gap:8px}
.svo:hover{border-color:#ff9a3c}.svo.on{border-color:#5dff8a;background:#142619}.svo.lock{opacity:.4;cursor:not-allowed}
.svo small{color:#8fa3c0;font-size:.64rem}
.svo i{font-style:normal;font-size:.66rem;color:#ffb35c;white-space:nowrap}
#svRet .chips{display:flex;flex-wrap:wrap;gap:5px}
#svRet .chip{padding:6px 10px;font-size:.72rem}
#svRet .swc{display:flex;gap:7px;flex-wrap:wrap}
#svRet .swc i{width:26px;height:26px;border-radius:50%;cursor:pointer;border:2px solid #ffffff33;display:block}
#svRet .swc i.on{border-color:#fff;box-shadow:0 0 0 2px #ff9a3c}
#svAll{margin-top:14px;width:100%}
@media(max-width:1150px){.svgrid{grid-template-columns:1fr;height:auto}.svgrid>div{overflow:visible}}`;
 document.head.appendChild(s);
}
function sightWeapons(){
 const out={};for(const k in W){const w=W[k];if(!w||!attAllowed(k).optic)continue;(out[w.cat]=out[w.cat]||[]).push(k);}
 return out;
}
function svCurOpt(k){const o=(cfg.att[k]||{}).optic;return o&&(attAllowed(k).optic||[]).includes(o)?o:null;}
function svZoomTxt(k,o){if(o)return o.startsWith('sc')?'×'+o.slice(2):o==='acog'?'×2,5':'';return W[k].overlay?'×'+Math.round(W[k].zoom*2):'';}
function drawSightsTab(){
 const host=$('svWeap');if(!host)return;
 const ws=sightWeapons(),lv=myLv();
 if(!svKey||!W[svKey]||!attAllowed(svKey).optic)svKey=(W[pvKey]&&attAllowed(pvKey).optic)?pvKey:(ws.rifle||ws.smg||Object.values(ws)[0])[0];
 // armes
 host.innerHTML='';
 for(const [cat,n] of SIGHT_CATS){const l=ws[cat];if(!l)continue;
  const h=document.createElement('h5');h.textContent=n;host.appendChild(h);
  const box=document.createElement('div');box.className='chips';
  for(const k of l){const c=document.createElement('div'),o=svCurOpt(k);c.className='chip'+(k===svKey?' on':'');c.innerHTML=W[k].n+(o?'<em>⌖</em>':'');c.title=o?ATTS[o].n:opticNone(k);
   c.onclick=()=>{sfxUI();svKey=k;drawSightsTab();};box.appendChild(c);}
  host.appendChild(box);
 }
 // viseurs disponibles
 const k=svKey,cur=svCurOpt(k),list=$('svList');
 let h='<h5>Viseur — '+W[k].n+'</h5>';
 h+='<div class="svo'+(!cur?' on':'')+'" data-a=""><div><b>'+opticNone(k)+'</b><br><small>Viseur de base de l\'arme</small></div><i>'+svZoomTxt(k,null)+'</i></div>';
 for(const a of attAllowed(k).optic){const d=ATTS[a],lock=lv<d.lv;
  h+='<div class="svo'+(cur===a?' on':'')+(lock?' lock':'')+'" data-a="'+a+'" title="'+d.d.replace(/"/g,'&quot;')+'"><div><b>'+d.n+(lock?' 🔒':'')+'</b><br><small>'+(lock?'Niveau '+d.lv:d.d.split(':')[0].split('.')[0])+'</small></div><i>'+svZoomTxt(k,a)+'</i></div>';}
 list.innerHTML=h;
 list.querySelectorAll('.svo').forEach(el=>el.onclick=()=>{
  const a=el.dataset.a;if(el.classList.contains('lock')){sfxUI();uiToast('Débloqué au niveau '+ATTS[a].lv);return;}
  if(!svSetOpt(k,a))return;sfx('reload',undefined,undefined,.3);drawSightsTab();
 });
 // réticule
 const o=cur||(W[k].cat==='sniper'?'scope':null),rt=$('svRet');
 if(!o){rt.innerHTML='<h5>Réticule</h5><small style="color:#8da0bd">Les mires d\'origine n\'ont pas de réticule réglable. Choisis un viseur pour personnaliser son réticule.</small>';}
 else{
  const r=retOf(o);
  rt.innerHTML='<h5>Forme du réticule</h5><div class="chips" id="svShape"></div><h5>Couleur</h5><div class="swc" id="svCol"></div><button class="chip" id="svAll">Mettre ce viseur sur toutes les armes compatibles</button>';
  const sh=$('svShape');for(const [id,n] of RET_SHAPES){const c=document.createElement('div');c.className='chip'+(r.s===id?' on':'');c.textContent=n;c.onclick=()=>{sfxUI();svSetRet(o,{s:id});};sh.appendChild(c);}
  const sw=$('svCol');for(const col of RET_COLS){const i=document.createElement('i');i.style.background=col;if(r.c===col)i.className='on';i.onclick=()=>{sfxUI();svSetRet(o,{c:col});};sw.appendChild(i);}
  const all=$('svAll');if(!cur)all.style.display='none';
  all.onclick=()=>{sfxUI();let n=0;for(const kk in W){if(kk===k||!(attAllowed(kk).optic||[]).includes(cur))continue;const s=Object.assign({},cfg.att[kk]||{});s.optic=cur;if(gsCount(s)>ATT_MAX)continue;cfg.att[kk]=s;n++;}
   saveCfg();if(typeof VM!=='undefined')VM.gk=null;uiToast(ATTS[cur].n+' posé sur '+n+' autre'+(n>1?'s':'')+' arme'+(n>1?'s':''));drawSightsTab();};
 }
 $('svInfo').innerHTML='<b>'+(cur?ATTS[cur].n:opticNone(k)).toUpperCase()+'</b><br>'+(cur?ATTS[cur].d:W[k].cat==='sniper'?'Lunette montée d\'usine. Choisis un autre grossissement à droite.':'Visée par les organes de visée de l\'arme.');
 svPreview();
}
function svSetOpt(k,a){
 const s=Object.assign({},cfg.att[k]||{});if(a)s.optic=a;else delete s.optic;
 if(gsCount(s)>ATT_MAX){sfxUI();uiToast('Maximum '+ATT_MAX+' accessoires : retire-en un dans l\'armurier');return false;}
 cfg.att[k]=s;saveCfg();if(typeof VM!=='undefined')VM.gk=null;if(pvKey===k&&typeof pvSet==='function')pvSet(k);return true;
}
function svSetRet(o,ch){
 cfg.ret[o]=Object.assign(retOf(o),ch);saveCfg();if(typeof VM!=='undefined')VM.gk=null;if(typeof pvSet==='function'&&W[pvKey])pvSet(pvKey);drawSightsTab();
}
// aperçu : petite scène de stand de tir vue à travers le viseur choisi
function svScene(c,Wd,H,z){
 c.save();c.translate(Wd/2,H/2);c.scale(z,z);c.translate(-Wd/2,-H/2);
 const g=c.createLinearGradient(0,0,0,H*.55);g.addColorStop(0,'#5d7ea6');g.addColorStop(1,'#b9c9d8');c.fillStyle=g;c.fillRect(-Wd,-H,Wd*3,H*1.55+H*.55);
 c.fillStyle='#6d6250';c.fillRect(-Wd,H*.55,Wd*3,H*2);
 c.fillStyle='#857a66';for(let i=-6;i<12;i++){c.beginPath();c.moveTo(Wd/2+i*90,H*.55);c.lineTo(Wd/2+i*260,H*2);c.lineTo(Wd/2+i*260+6,H*2);c.lineTo(Wd/2+i*90+2,H*.55);c.fill();}
 const box=(x,y,w,h,col)=>{c.fillStyle=col;c.fillRect(x,y,w,h);c.strokeStyle='#00000040';c.lineWidth=1;c.strokeRect(x,y,w,h);};
 box(Wd*.08,H*.42,Wd*.12,H*.16,'#8a6a42');box(Wd*.78,H*.4,Wd*.14,H*.18,'#8a6a42');box(Wd*.3,H*.47,Wd*.06,H*.09,'#7a5d3a');
 // cible au centre
 const cx=Wd/2,cy=H*.5;c.fillStyle='#2b2f36';c.fillRect(cx-1.5,cy,3,H*.06);
 c.fillStyle='#e9e3d4';c.beginPath();c.arc(cx,cy-H*.035,H*.028,0,Math.PI*2);c.fill();c.fillRect(cx-H*.03,cy-H*.01,H*.06,H*.07);
 c.strokeStyle='#c23b3b';c.lineWidth=1.5;c.beginPath();c.arc(cx,cy+H*.02,H*.018,0,Math.PI*2);c.stroke();
 c.restore();
}
function svPreview(){
 const cv=$('svCv');if(!cv)return;const c=cv.getContext('2d'),Wd=cv.width,H=cv.height,k=svKey,o=svCurOpt(k);
 const ov=o?!!ATTS[o].ov:!!W[k].overlay,z=ov?(o?ATTS[o].m.zoom:W[k].zoom)*.8:o==='acog'?2:1.15;
 c.clearRect(0,0,Wd,H);svScene(c,Wd,H,z);
 const cx=Wd/2,cy=H/2,dk='#16191e';
 if(ov){
  const R=H*.44,r=retOf(o||'scope');
  c.save();c.fillStyle='#000';c.beginPath();c.rect(0,0,Wd,H);c.arc(cx,cy,R,0,Math.PI*2,true);c.fill();
  const v=c.createRadialGradient(cx,cy,R*.75,cx,cy,R);v.addColorStop(0,'#0000');v.addColorStop(1,'#000c');c.fillStyle=v;c.beginPath();c.arc(cx,cy,R,0,Math.PI*2);c.fill();c.restore();
  drawReticle(c,cx,cy,R,r.s,r.c,true);return;
 }
 if(!o){ // mires : guidon + cran de mire
  c.fillStyle=dk;c.fillRect(cx-3,cy,6,H*.2);c.fillRect(cx-80,cy+H*.1,62,H*.4);c.fillRect(cx+18,cy+H*.1,62,H*.4);
  c.fillRect(cx-18,cy+H*.16,36,H*.4);return;
 }
 const r=retOf(o);c.save();c.fillStyle=dk;c.strokeStyle='#2c3138';
 if(o==='acog'){const R=H*.36;c.beginPath();c.rect(0,0,Wd,H);c.arc(cx,cy,R,0,Math.PI*2,true);c.fill();c.lineWidth=10;c.beginPath();c.arc(cx,cy,R+5,0,Math.PI*2);c.stroke();c.restore();drawReticle(c,cx,cy,R*.55,r.s,r.c,false);return;}
 if(o==='reddot'){const R=H*.3;c.lineWidth=16;c.beginPath();c.arc(cx,cy,R,0,Math.PI*2);c.stroke();c.fillRect(cx-R*.7,cy+R+4,R*1.4,H);}
 else if(o==='holo'){const w=H*.62,h=H*.44;c.lineWidth=14;c.strokeRect(cx-w/2,cy-h/2,w,h);c.fillRect(cx-w/2-7,cy+h/2,w+14,H);}
 else{const w=H*.38,h=H*.3;c.lineWidth=9;c.strokeRect(cx-w/2,cy-h/2,w,h);c.fillRect(cx-w/2-5,cy+h/2,w+10,H);}
 c.fillStyle='#7fd8ff10';c.fillRect(0,0,Wd,H);c.restore();
 drawReticle(c,cx,cy,o==='holo'?H*.1:H*.08,r.s,r.c,false);
}
sightsTabBuild();
document.querySelectorAll('.mtab[data-t="sights"]').forEach(t=>t.addEventListener('click',drawSightsTab));
