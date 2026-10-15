/* =====================================================================
   MODE MASTODONTE (façon Call of Duty « Juggernaut » / Roblox)
   - Chacun pour soi. Le premier qui élimine quelqu'un devient le
     Mastodonte : 400 PV, gilet, mitrailleuse M249 (lourde), halo rouge.
   - Tout le monde chasse le Mastodonte. Celui qui l'élimine prend sa place.
   - Points : seul le Mastodonte marque. +1 par élimination et +1 toutes
     les 5 secondes passées en Mastodonte. Premier à la limite gagne.
   Variante du mode « ffa » : réutilise ses réapparitions.
   ===================================================================== */
MODES.jug={n:'Mastodonte',ic:'🛡',c:'#ff5a3c',team:false,respawn:2,desc:'Le premier à éliminer devient le Mastodonte : 400 PV et une mitrailleuse. Lui seul marque des points. Élimine-le pour prendre sa place.',limitLabel:'Points pour gagner',limits:[25,40,60]};
VARIANT_BASE.jug='ffa';NOKILLSCORE.jug=1;
MODE_GROUPS[2][1].splice(2,0,'jug');MODE_TAG.jug='Deviens le Mastodonte et tiens';
if(typeof RTIME!=='undefined')RTIME.jug={l:'Durée de la partie',o:[5,8,10],d:8,u:'min'};
const JUG={who:null,tick:0,hp:400,wpn:'m249'};
const isJug=()=>G.variant==='jug';

function jugLook(e,on){
 if(!e.rig)return;const r=e.rig.root;
 if(on&&!r.userData.jugGlow&&typeof zGlow==='function'){const g=zGlow(0xff3a2a,2.4);g.position.y=1.1;g.material.opacity=.7;r.add(g);r.userData.jugGlow=g;}
 if(!on&&r.userData.jugGlow){r.remove(r.userData.jugGlow);r.userData.jugGlow=null;}
 r.scale.setScalar(on?1.12:1);
}
function jugMake(e){
 const prev=JUG.who;if(prev&&prev!==e){prev.jug=false;jugLook(prev,false);}
 JUG.who=e;JUG.tick=0;e.jug=true;
 e.hp=JUG.hp;e.jugMax=JUG.hp;e.armor=100;e.shield=0;
 e.wp.p=null;giveWeapon(e,JUG.wpn);if(e.wp.p){e.wp.p.res=999;}e.cur='p';e.switchT=.5;
 if(e.isPlayer&&typeof vmDraw==='function')vmDraw();
 jugLook(e,true);
 if(e.isPlayer){uiBanner('TU ES LE MASTODONTE','Tiens le plus longtemps possible',2400,'#ff5a3c');sfx('pap');G.shake=Math.max(G.shake,.4);}
 else uiBanner(e.name.toUpperCase()+' EST LE MASTODONTE','Élimine-le pour prendre sa place',2000,'#ff5a3c');
 sfx('alarm');
}
function jugPoint(e,n){e.jpts=(e.jpts||0)+n;if(e.jpts>=G.limit&&G.state==='live'){G.winner=e;endDM();}}
function jugUpdate(dt){
 const j=JUG.who;
 if(j&&(!j.alive||!ents.includes(j))){j.jug=false;jugLook(j,false);JUG.who=null;}
 if(G.state==='live'&&JUG.who){JUG.tick+=dt;if(JUG.tick>=5){JUG.tick-=5;jugPoint(JUG.who,1);}}
 jugHud();
}
function jugHud(){
 let el=$('jugHud');if(!el){el=document.createElement('div');el.id='jugHud';$('hud').appendChild(el);}
 el.style.display='';const j=JUG.who;
 const top=ents.slice().sort((a,b)=>(b.jpts||0)-(a.jpts||0)).slice(0,3);
 el.innerHTML='<div class="jw">'+(j?(j===P?'🛡 TU ES LE MASTODONTE':'🛡 MASTODONTE : '+jugEsc(j.name)+' — '+Math.max(0,Math.ceil(j.hp))+' PV'):'Première élimination = Mastodonte')+'</div>'+
  '<div class="jt">'+top.map(e=>'<span'+(e===P?' class="me"':'')+'>'+jugEsc(e.name)+' '+(e.jpts||0)+'</span>').join('')+'<span class="lim">/ '+G.limit+'</span></div>';
}
function jugEsc(s){return String(s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'})[c]);}

const _variantInitJug=variantInit;
variantInit=function(){
 if(JUG.who)jugLook(JUG.who,false);JUG.who=null;JUG.tick=0;
 _variantInitJug();
 const h=$('jugHud');if(h)h.style.display=isJug()?'':'none';
 if(isJug()){G.limit=limitOf('jug');for(const e of ents){e.jpts=0;e.jug=false;}}
};
const _variantKillJug=variantKill;
variantKill=function(att,v,w,hs){
 _variantKillJug(att,v,w,hs);
 if(!isJug())return;
 const wasJ=v.jug;
 if(wasJ){v.jug=false;jugLook(v,false);JUG.who=null;}
 if(!att||att===v||!att.alive||G.state!=='live')return;
 if(wasJ||!JUG.who)jugMake(att);
 else if(att.jug)jugPoint(att,1);
};
const _variantUpdateJug=variantUpdate;
variantUpdate=function(dt,t){_variantUpdateJug(dt,t);if(isJug()&&(G.state==='live'||G.state==='freeze'))jugUpdate(dt);};
const _variantTimeUpJug=variantTimeUp;
variantTimeUp=function(){
 if(!isJug())return _variantTimeUpJug();
 let b=null;for(const e of ents)if(!b||(e.jpts||0)>(b.jpts||0))b=e;G.winner=b;endDM();return true;
};
const _variantSubJug=variantSub;
variantSub=function(){return isJug()?'Élimine pour devenir le Mastodonte — premier à '+G.limit:_variantSubJug();};
const _variantCleanupJug=variantCleanup;
variantCleanup=function(){_variantCleanupJug();if(JUG.who)jugLook(JUG.who,false);JUG.who=null;const h=$('jugHud');if(h)h.style.display='none';};
const _variantRadarJug=variantRadar;
variantRadar=function(c,pt){
 _variantRadarJug(c,pt);
 const j=JUG.who;if(!isJug()||!j||j===P)return;
 const p=pt(j.x,j.z);c.strokeStyle='#ff3a2a';c.lineWidth=2.5;c.beginPath();c.arc(p[0],p[1],7+Math.sin(G.t*6)*1.5,0,TAU);c.stroke();
};
// les bots chassent le Mastodonte ; le Mastodonte, lui, erre
const _botGoalJug=botGoal;
botGoal=function(b){
 const j=JUG.who;
 if(isJug()&&j&&j!==b&&j.alive)return {x:j.x+rand(-2,2),z:j.z+rand(-2,2)};
 return _botGoalJug(b);
};
// barre de vie : 400 PV tiennent dans la barre
const _updateHUDJug=updateHUD;
updateHUD=function(dt,t){
 _updateHUDJug(dt,t);
 const src=!P.alive&&G.spec?G.spec:P;
 if(src&&src.jug){$('hpm').firstElementChild.style.width=Math.max(0,src.hp)/(src.jugMax||400)*100+'%';$('hpm').firstElementChild.style.background='linear-gradient(90deg,#ff3a2a,#ffb02a)';}
 else $('hpm').firstElementChild.style.background='';
};
(function(){const s=document.createElement('style');s.textContent=`
#jugHud{position:absolute;top:58px;left:50%;transform:translateX(-50%);text-align:center;pointer-events:none;text-shadow:0 1px 4px #000}
#jugHud .jw{font:900 .9rem Bahnschrift,Arial;letter-spacing:2px;color:#ff7a5a}
#jugHud .jt{margin-top:4px;display:flex;gap:10px;justify-content:center;font:700 .72rem Bahnschrift,Arial;letter-spacing:1px;color:#dfe6f2}
#jugHud .jt .me{color:#ffd23a}#jugHud .jt .lim{color:#8da0bd}
`;document.head.appendChild(s);})();
