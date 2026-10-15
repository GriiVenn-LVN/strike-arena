/* =====================================================================
   CONFORT DE JEU (idées reprises de CS2, Valorant, Call of Duty)
   - Sensibilité en visée : multiplicateur réglable (Réglages), appliqué
     en visée et à la lunette, en plus de la sensibilité normale.
   - Alerte grenade : une icône autour du centre de l'écran indique d'où
     vient une grenade explosive qui va sauter près de toi.
   - Bouton RECOMMENCER dans la pause (parties solo).
   - Bilan perso en fin de partie : précision, tirs à la tête, dégâts,
     meilleure série.
   ===================================================================== */
cfg.adsSens=typeof cfg.adsSens==='number'?cfg.adsSens:1;

/* ---------- sensibilité en visée ---------- */
const _wsensMulCf=wsensMul;
wsensMul=function(){
 const b=_wsensMulCf();
 return P&&P.alive&&P.ads>0?b*lerp(1,cfg.adsSens,clamp(P.ads,0,1)):b;
};
// le curseur se place sous « Sensibilité » ; le menu simplifié (87c) reconstruit l'onglet, d'où le second appel
function adsSensUI(){
 if($('rAdsS'))return;
 const r=$('rSens');if(!r)return;const grp=r.closest('.grp');if(!grp)return;
 const g=document.createElement('div');g.className='grp';
 g.innerHTML='<label>Sensibilité en visée <b id="vAdsS"></b></label><input type="range" id="rAdsS" min="0.3" max="1.5" step="0.05">';
 grp.after(g);
 const ra=$('rAdsS'),va=$('vAdsS');
 const show=()=>{ra.value=cfg.adsSens;va.textContent='×'+(+cfg.adsSens).toFixed(2);};
 ra.oninput=()=>{cfg.adsSens=+ra.value;show();saveCfg();};show();
}
if(typeof menuSimplify==='function'){const _menuSimplifyCf=menuSimplify;menuSimplify=function(){const r=_menuSimplifyCf.apply(this,arguments);adsSensUI();return r;};}
adsSensUI();

/* ---------- alerte grenade ---------- */
const NADEWARN={els:[],R:9.5};
function nadeWarnUpdate(){
 const host=$('hud');if(!host)return;
 const list=[];
 if(P&&P.alive&&G.running&&!RP.on)for(const n of nades){
  if(n.type!=='f'||n.owner===P&&!G.netClient)continue;
  const dx=n.x-P.x,dz=n.z-P.z,d=Math.hypot(dx,dz);if(d>NADEWARN.R||Math.abs(n.y-P.y)>4)continue;
  list.push({n,dx,dz,d});
 }
 while(NADEWARN.els.length<list.length){const e=document.createElement('div');e.className='nwarn';e.innerHTML='<i>💣</i><b></b>';host.appendChild(e);NADEWARN.els.push(e);}
 NADEWARN.els.forEach((el,i)=>{
  const it=list[i];if(!it){el.style.display='none';return;}
  const y=P.yaw,fwd=it.dx*-Math.sin(y)+it.dz*-Math.cos(y),rgt=it.dx*Math.cos(y)+it.dz*-Math.sin(y),L=Math.hypot(fwd,rgt)||1;
  const R=it.d<1.2?0:118;
  el.style.display='';
  el.style.transform='translate(-50%,-50%) translate('+(rgt/L*R).toFixed(1)+'px,'+(-fwd/L*R).toFixed(1)+'px)';
  el.style.opacity=(.55+.45*Math.abs(Math.sin(G.t*(it.n.t<1?18:9)))).toFixed(2);
  el.classList.toggle('near',it.d<5);
  const ar=el.querySelector('b');ar.style.transform='rotate('+Math.atan2(rgt,fwd).toFixed(3)+'rad)';ar.style.display=R?'':'none';
 });
}
const _updateHUDCf=updateHUD;
updateHUD=function(dt,t){_updateHUDCf(dt,t);try{nadeWarnUpdate();}catch(e){}};

/* ---------- RECOMMENCER (pause, solo) ---------- */
{
 const row=$('toMenu').parentNode,b=document.createElement('button');
 b.className='btn alt cut';b.id='pRestart';b.textContent='RECOMMENCER';b.style.display='none';
 row.insertBefore(b,$('toMenu'));
 b.onclick=()=>{
  if(!G.running||NET.role||G.netClient)return;
  $('pause').classList.remove('show');G.paused=false;
  if(typeof initAudio==='function')initAudio();
  startMatch();buildRadarMap();lockMouse();
 };
 new MutationObserver(()=>{b.style.display=$('pause').classList.contains('show')&&G.running&&!NET.role&&!G.netClient&&!(typeof TUT!=='undefined'&&TUT.on)?'':'none';})
  .observe($('pause'),{attributes:true,attributeFilter:['class']});
}

/* ---------- bilan perso en fin de partie ---------- */
const _uiMatchOverCf=uiMatchOver;
uiMatchOver=function(){
 _uiMatchOverCf.apply(this,arguments);
 try{
  let el=$('oPerso');
  if(!el){el=document.createElement('div');el.id='oPerso';$('oS').after(el);}
  if(!P||G.variant==='train'){el.innerHTML='';return;}
  const pc=(a,b)=>b?Math.round(a/b*100)+' %':'—';
  const tiles=[['PRÉCISION',pc(MS.hits,MS.shots)],['TÊTES',pc(P.hsKills||0,P.kills||0)],['DÉGÂTS',Math.round(P.dmg||0)],['MEILLEURE SÉRIE',P.bestStreak||0]];
  el.innerHTML=tiles.map(t=>'<div><small>'+t[0]+'</small><b>'+t[1]+'</b></div>').join('');
 }catch(e){console.error(e);}
};

(function(){const s=document.createElement('style');s.textContent=`
.nwarn{position:absolute;left:50%;top:50%;width:44px;height:44px;pointer-events:none;z-index:6}
.nwarn i{position:absolute;inset:0;display:flex;align-items:center;justify-content:center;font-style:normal;font-size:1.35rem;border-radius:50%;background:#000a;border:2px solid #ffb23a;box-shadow:0 0 14px #ff8a2a99}
.nwarn.near i{border-color:#ff4655;box-shadow:0 0 18px #ff4655}
.nwarn b{position:absolute;left:50%;top:50%;width:0;height:0;margin:-34px 0 0 -7px;border:7px solid transparent;border-bottom:10px solid #ffb23a;transform-origin:7px 34px}
.nwarn.near b{border-bottom-color:#ff4655}
#oPerso{display:flex;gap:10px;justify-content:center;flex-wrap:wrap;margin:12px 0 4px}
#oPerso div{min-width:104px;padding:7px 12px;border-radius:8px;background:#0f1726;border:1px solid #ffffff14;text-align:center}
#oPerso small{display:block;font-size:.6rem;letter-spacing:2px;color:#8da0bd}
#oPerso b{font-size:1.15rem;color:#fff}
`;document.head.appendChild(s);})();
