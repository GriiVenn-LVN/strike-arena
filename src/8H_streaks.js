/* =====================================================================
   RÉCOMPENSES DE SÉRIE (façon Call of Duty / Phantom Forces)
   Dans les modes avec réapparition (équipe, chacun pour soi, zone) :
   - 3 éliminations sans mourir : DRONE RADAR (ennemis visibles 15 s)
   - 5 : FRAPPE D'ARTILLERIE sur le point visé (6 obus après 2,5 s)
   - 8 : BLINDAGE (PV, armure et bouclier au max + vitesse 10 s)
   Touche 4 (réassignable) pour utiliser la récompense prête.
   ===================================================================== */
const KS_LIST=[
 {id:'uav',n:'Drone radar',ic:'📡',k:3},
 {id:'arty',n:'Frappe d\'artillerie',ic:'🎯',k:5},
 {id:'armor',n:'Blindage',ic:'🛡️',k:8}
];
const KS={ready:[],got:{},uavT:0,boostT:0,strikes:[],el:null};
const KS_MODES={tdm:1,ffa:1,koth:1};
DEFBINDS.streak='Digit4';BINDLABEL.streak='Utiliser la récompense de série';
if(!cfg.binds.streak)cfg.binds.streak=DEFBINDS.streak;
const ksOn=()=>KS_MODES[G.variant]&&!G.netClient&&!NET.role;
function ksReset(){KS.ready.length=0;KS.got={};KS.uavT=0;KS.boostT=0;for(const s of KS.strikes)if(s.mk)scene.remove(s.mk);KS.strikes.length=0;ksHud();}
function ksOnKill(){
 if(!ksOn()||!P)return;
 for(const r of KS_LIST)if(P.streak>=r.k&&!KS.got[r.id]){
  KS.got[r.id]=1;KS.ready.push(r.id);
  uiBanner(r.ic+' '+r.n.toUpperCase()+' PRÊT','Touche '+keyLabel(cfg.binds.streak)+' pour l\'utiliser',2200,'#ffd23a');sfx('powerup');
 }
 ksHud();
}
function ksUse(){
 if(!ksOn()||!P||!P.alive||!KS.ready.length)return;
 const id=KS.ready.shift();
 if(id==='uav'){KS.uavT=G.t+15;uiBanner('📡 DRONE RADAR','Ennemis visibles pendant 15 s',1800,'#5cd6ff');sfx('zap');}
 else if(id==='arty'){
  const pt=ksAimPoint();
  const mk=new THREE.Mesh(new THREE.RingGeometry(5.6,6,48),new THREE.MeshBasicMaterial({color:0xff3030,transparent:true,opacity:.8,side:THREE.DoubleSide,depthWrite:false,toneMapped:false}));
  mk.rotation.x=-Math.PI/2;mk.position.set(pt.x,groundH(pt.x,pt.z)+.12,pt.z);scene.add(mk);
  KS.strikes.push({x:pt.x,z:pt.z,t:G.t+2.5,n:6,next:0,mk});
  uiBanner('🎯 FRAPPE D\'ARTILLERIE','Impact dans 2 s — reste à l\'écart !',1800,'#ff6b6b');sfx('alarm');
 }else if(id==='armor'){
  P.hp=100;P.armor=100;P.shield=typeof SHIELDMAX!=='undefined'?SHIELDMAX:50;KS.boostT=G.t+10;
  uiBanner('🛡️ BLINDAGE','Santé et protections au max, vitesse +15 % (10 s)',1800,'#7dff9f');sfx('heal');
 }
 ksHud();
}
// point visé : on avance le long du regard jusqu'à un mur ou au sol
function ksAimPoint(){
 const cp=Math.cos(P.pitch),dx=-Math.sin(P.yaw)*cp,dy=Math.sin(P.pitch),dz=-Math.cos(P.yaw)*cp;
 const ox=P.x,oy=P.y+P.eyeH,oz=P.z;
 const tw=rayWall(ox,oy,oz,dx,dy,dz,70);
 let x=ox,z=oz;
 for(let t=0;t<Math.min(70,tw);t+=.5){x=ox+dx*t;z=oz+dz*t;if(oy+dy*t<=groundH(x,z)+.05)break;}
 return {x,z};
}
function ksUpdate(dt){
 if(!G.running||!P)return;
 if(KS.uavT>G.t)for(const e of ents)if(e.alive&&(MODE().team?e.team!==P.team:e!==P))e.spotT=G.t+.3;
 for(let i=KS.strikes.length-1;i>=0;i--){
  const s=KS.strikes[i];s.mk.material.opacity=.45+.4*Math.abs(Math.sin(G.t*8));
  if(G.t<s.t)continue;
  if(G.t>=s.next&&s.n>0){
   s.n--;s.next=G.t+rand(.2,.4);
   const a=rand(0,TAU),r=rand(0,5),x=s.x+Math.cos(a)*r,z=s.z+Math.sin(a)*r,y=groundH(x,z);
   sfx('boom',x,z,1);fxExplosion(x,y+.2,z,1.1);
   for(const v of ents){
    if(!v.alive)continue;
    const fr=MODE().team&&v.team===P.team&&v!==P;if(fr)continue;
    const d=Math.hypot(v.x-x,v.y+1-y,v.z-z);if(d>6.5)continue;
    if(rayWall(x,y+.4,z,(v.x-x)/d,(v.y+1-y)/d,(v.z-z)/d,d)<d-.4)continue;
    hurt(v,P,NADEW,'b',d,Math.round(150*(1-d/6.5)));
   }
   if(P.alive){const d=Math.hypot(P.x-x,P.z-z);if(d<18)G.shake=Math.max(G.shake,.8*(1-d/18));}
  }
  if(s.n<=0&&G.t>s.next+.3){scene.remove(s.mk);s.mk.geometry.dispose();s.mk.material.dispose();KS.strikes.splice(i,1);}
 }
}
function ksHud(){
 if(!KS.el){
  const d=document.createElement('div');d.id='ksHud';($('hud')||document.body).appendChild(d);KS.el=d;
  const s=document.createElement('style');s.textContent=`
#ksHud{position:absolute;right:18px;bottom:calc(var(--ui,14px)*13);display:flex;gap:6px;pointer-events:none;font-family:Bahnschrift,Arial,sans-serif}
#ksHud .k{width:46px;height:46px;border-radius:8px;background:#0b111ccc;border:2px solid #ffffff22;display:flex;flex-direction:column;align-items:center;justify-content:center;font-size:1.1rem;opacity:.55;position:relative}
#ksHud .k small{font-size:.55rem;color:#b8c5da;letter-spacing:1px}
#ksHud .k.rdy{opacity:1;border-color:#ffd23a;box-shadow:0 0 14px -4px #ffd23a;animation:ksp 1s infinite alternate}
#ksHud .k.used{opacity:.25}
#ksHud .k b{position:absolute;top:-8px;right:-6px;background:#ffd23a;color:#111;font-size:.55rem;border-radius:4px;padding:1px 4px}
@keyframes ksp{to{transform:translateY(-2px)}}
body.touch #ksHud{right:auto;left:50%;transform:translateX(-50%);top:calc(var(--ui,14px)*5.6);bottom:auto}
#touchUI .b-streak{width:50px;height:50px;right:300px;bottom:150px;display:none;background:#ffd23a55;border-color:#ffd23a}`;document.head.appendChild(s);
 }
 const show=G.running&&ksOn();KS.el.style.display=show?'flex':'none';if(!show)return;
 const st=P?P.streak:0;
 KS.el.innerHTML=KS_LIST.map(r=>{const rdy=KS.ready.includes(r.id),used=KS.got[r.id]&&!rdy;return '<div class="k'+(rdy?' rdy':used?' used':'')+'">'+r.ic+'<small>'+(rdy?'PRÊT':used?'✔':Math.min(st,r.k)+'/'+r.k)+'</small>'+(rdy&&KS.ready[0]===r.id?'<b>'+keyLabel(cfg.binds.streak)+'</b>':'')+'</div>';}).join('');
 const tb=document.querySelector('#touchUI .b-streak');if(tb)tb.style.display=KS.ready.length?'flex':'none';
}
// branchements
const _killEntKs=killEnt;
killEnt=function(v,att,w,hs){
 const was=v.alive;_killEntKs(v,att,w,hs);
 if(was&&!v.alive){if(att===P&&v!==P)ksOnKill();if(v===P){KS.got={};ksHud();}}
};
const _startMatchKs=startMatch;
startMatch=function(){const r=_startMatchKs();ksReset();return r;};
const _updateKs=update;
update=function(dt){_updateKs(dt);ksUpdate(dt);};
const _inputDownKs=inputDown;
inputDown=function(code){_inputDownKs(code);if(code===cfg.binds.streak&&G.running&&focusLocked&&!buyOpen)ksUse();};
const _mvPreKs=mvPre;
mvPre=function(p,dt,fx,fz){const r=_mvPreKs(p,dt,fx,fz);return p===P&&KS.boostT>G.t?r*1.15:r;};
const _respawnKs=respawn;
respawn=function(e){_respawnKs(e);if(e===P)ksHud();};
touchAddBtn(['streak','SÉRIE','b-streak','tap']);
