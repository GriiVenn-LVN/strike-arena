/* =====================================================================
   MARQUAGE (façon Apex / Valorant / Fortnite) + AIDE À LA VISÉE TACTILE
   + ALERTE SANTÉ BASSE
   - Clic molette (réassignable) : marque l'ennemi visé (visible sur le
     radar de l'équipe 6 s) ou un point du décor (« Allez ici ») ; les
     bots alliés proches s'y dirigent.
   - Sur écran tactile : la visée ralentit près d'un ennemi et suit
     légèrement la cible en visant / en tirant (comme Arsenal / RIVALS).
   - Sous 30 PV : bord de l'écran rouge qui bat et battements de cœur.
   ===================================================================== */
DEFBINDS.ping='Mouse1';BINDLABEL.ping='Marquer (ennemi ou lieu)';
if(!cfg.binds.ping)cfg.binds.ping=DEFBINDS.ping;
const PING={list:[],el:null,cd:0};
function pingCss(){
 if(PING.el)return;
 const d=document.createElement('div');d.id='pingLayer';($('hud')||document.body).appendChild(d);PING.el=d;
 const s=document.createElement('style');s.textContent=`
#pingLayer{position:absolute;inset:0;pointer-events:none;overflow:hidden}
#pingLayer .pg{position:absolute;transform:translate(-50%,-100%);text-align:center;font-family:Bahnschrift,Arial,sans-serif;font-weight:800;font-size:11px;letter-spacing:1px;color:#fff;text-shadow:0 1px 3px #000;white-space:nowrap}
#pingLayer .pg i{display:block;font-style:normal;width:22px;height:22px;margin:0 auto 2px;border-radius:50% 50% 50% 0;transform:rotate(-45deg);background:#ffd23a;box-shadow:0 0 12px #ffd23a}
#pingLayer .pg.en i{background:#ff4655;box-shadow:0 0 12px #ff4655}
#pingLayer .pg.edge{opacity:.75}
#lowhp{position:fixed;inset:0;pointer-events:none;z-index:4;opacity:0;background:radial-gradient(ellipse at center,transparent 55%,rgba(200,0,20,.55) 100%);transition:opacity .4s}
#touchUI .b-ping{width:46px;height:46px;left:150px;top:16px;border-radius:12px}`;document.head.appendChild(s);
}
function pingDo(){
 if(!G.running||!P||!P.alive||PING.cd>G.t)return;
 PING.cd=G.t+.6;pingCss();
 const cp=Math.cos(P.pitch),dx=-Math.sin(P.yaw)*cp,dy=Math.sin(P.pitch),dz=-Math.cos(P.yaw)*cp,ox=P.x,oy=P.y+P.eyeH,oz=P.z;
 // ennemi proche de la ligne de visée ?
 let best=null,ba=.07;
 for(const e of ents){
  if(!e.alive||e===P||(MODE().team&&e.team===P.team))continue;
  const ex=e.x-ox,ey=e.y+1.1-oy,ez=e.z-oz,d=Math.hypot(ex,ey,ez);if(d>90)continue;
  const a=Math.acos(clamp((ex*dx+ey*dy+ez*dz)/d,-1,1));
  if(a<ba&&losClear(ox,oy,oz,e.x,e.y+1.1,e.z)){ba=a;best=e;}
 }
 if(best){
  best.spotT=G.t+6;PING.list.push({e:best,t:G.t+6,en:true});
  uiToast('Ennemi marqué : '+best.name);
 }else{
  const pt=ksAimPoint();
  PING.list.push({x:pt.x,z:pt.z,y:groundH(pt.x,pt.z),t:G.t+8,en:false});
  // les bots alliés les plus proches y vont
  if(MODE().team){const al=ents.filter(b=>!b.isPlayer&&b.alive&&b.team===P.team&&!b.target&&!b.remote).sort((a,b)=>Math.hypot(a.x-pt.x,a.z-pt.z)-Math.hypot(b.x-pt.x,b.z-pt.z)).slice(0,2);for(const b of al){b.lastSeen={x:pt.x,z:pt.z,t:G.t};b.roamX=pt.x;b.roamZ=pt.z;b.roamT=G.t+8;}}
 }
 while(PING.list.length>4)PING.list.shift();
 sfx('tick');
}
const _pingV=new THREE.Vector3();
function pingRender(){
 if(!PING.el)return;
 const live=G.running&&G.state!=='potg'&&P;
 PING.list=PING.list.filter(p=>live&&p.t>G.t&&(!p.e||p.e.alive));
 let h='';
 for(const p of PING.list){
  const x=p.e?p.e.x:p.x,y=p.e?p.e.y+2.1:p.y+.4,z=p.e?p.e.z:p.z;
  _pingV.set(x,y,z).project(camera);
  let sx=(_pingV.x*.5+.5)*innerWidth,sy=(-_pingV.y*.5+.5)*innerHeight,edge=false;
  if(_pingV.z>1){sx=innerWidth-sx;sy=innerHeight-20;edge=true;}
  if(sx<20||sx>innerWidth-20||sy<40||sy>innerHeight-10)edge=true;
  sx=clamp(sx,20,innerWidth-20);sy=clamp(sy,40,innerHeight-10);
  const d=Math.round(Math.hypot(x-P.x,z-P.z));
  h+='<div class="pg'+(p.en?' en':'')+(edge?' edge':'')+'" style="left:'+sx+'px;top:'+sy+'px"><i></i>'+(p.en?'ENNEMI · ':'ICI · ')+d+' m</div>';
 }
 if(PING.el._h!==h){PING.el._h=h;PING.el.innerHTML=h;}
}
const _inputDownPing=inputDown;
inputDown=function(code){
 _inputDownPing(code);
 if(code===cfg.binds.ping&&G.running&&(focusLocked||TOUCH.on)&&!buyOpen)pingDo();
};
touchAddBtn(['ping','MARQUER','b-ping','tap']);pingCss();

/* ---------- aide à la visée (tactile uniquement) ---------- */
const AA={t:null};
function aimAssistTarget(){
 const cp=Math.cos(P.pitch),dx=-Math.sin(P.yaw)*cp,dy=Math.sin(P.pitch),dz=-Math.cos(P.yaw)*cp,ox=P.x,oy=P.y+P.eyeH,oz=P.z;
 const cone=(P.ads>.5?9:6)*RAD;let best=null,ba=cone;
 for(const e of ents){
  if(!e.alive||e===P||e.dummy&&G.variant!=='train'||(MODE().team&&e.team===P.team))continue;
  const ex=e.x-ox,ey=e.y+1.2-oy,ez=e.z-oz,d=Math.hypot(ex,ey,ez);if(d>60)continue;
  const a=Math.acos(clamp((ex*dx+ey*dy+ez*dz)/d,-1,1));
  if(a<ba&&losClear(ox,oy,oz,e.x,e.y+1.2,e.z)){ba=a;best=e;}
 }
 return best;
}
if(typeof touchLookDelta==='function'){
 const _tld=touchLookDelta;
 touchLookDelta=function(dx,dy){const k=AA.t&&cfg.aimAssist!==0?.55:1;_tld(dx*k,dy*k);};
}
function aimAssistUpdate(dt){
 AA.t=null;
 if(!TOUCH.on||cfg.aimAssist===0||!G.running||G.paused||!P||!P.alive||G.state==='potg'||buyOpen)return;
 const t=aimAssistTarget();AA.t=t;if(!t||!(P.ads>.3||mouseL))return;
 const ox=P.x,oy=P.y+P.eyeH,oz=P.z,ex=t.x-ox,ey=t.y+(t.crouch?.9:1.25)-oy,ez=t.z-oz,dh=Math.hypot(ex,ez);
 const wy=Math.atan2(-ex,-ez),wp=Math.atan2(ey,dh),k=Math.min(1,dt*2.2);
 P.yaw+=angDiff(P.yaw,wy)*k;P.pitch+=(wp-P.pitch)*k;
}

/* ---------- santé basse ---------- */
let lowEl=null,beatT=0;
function lowHpUpdate(dt){
 if(!lowEl){lowEl=document.createElement('div');lowEl.id='lowhp';document.body.appendChild(lowEl);}
 const on=G.running&&P&&P.alive&&P.hp<=30&&G.state!=='potg'&&G.state!=='over';
 if(!on){lowEl.style.opacity=0;return;}
 const k=1-P.hp/30;beatT-=dt;
 lowEl.style.opacity=(.35+.45*k)*(.75+.25*Math.sin(performance.now()/1000*Math.PI*2*(1+k)));
 if(beatT<=0){beatT=1.05-.35*k;sfx('step',P.x,P.z,.55);setTimeout(()=>{if(G.running&&P.alive)sfx('step',P.x,P.z,.4);},160);}
}
let _ppl=performance.now();
const _updateFXPing=updateFX;
updateFX=function(dt,t){
 _updateFXPing(dt,t);
 const n=performance.now(),rdt=Math.min(.1,(n-_ppl)/1000);_ppl=n;
 pingRender();aimAssistUpdate(rdt);lowHpUpdate(rdt);
};
