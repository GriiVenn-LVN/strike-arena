/* =====================================================================
   ACTION DU MATCH : à la fin de la partie, on rejoue le meilleur moment
   du joueur (série d'éliminations la plus forte) avant l'écran de
   résultats. Réutilise le moteur de rediffusion de 6A_replay.js.
   ESPACE ou un toucher pour passer.
   ===================================================================== */
const POTG={best:null,score:0,run:[],pending:null,playing:false,skipAt:0};
function potgReset(){POTG.best=null;POTG.score=0;POTG.run=[];if(POTG.pending){clearTimeout(POTG.pending.to);POTG.pending=null;}}
const _startMatchPotg=startMatch;
startMatch=function(){potgReset();return _startMatchPotg();};
// note chaque élimination du joueur ; capture le tampon 1,4 s plus tard
const _rpKillPotg=rpKill;
rpKill=function(att,v,w,hs){
 _rpKillPotg(att,v,w,hs);
 if(!att||!att.isPlayer||att===v||v.dummy||G.netClient)return;
 POTG.run=POTG.run.filter(k=>G.t-k.t<5);POTG.run.push({t:G.t,hs});
 const n=POTG.run.length,sc=n*n*10+POTG.run.filter(k=>k.hs).length*4+(w&&w.melee?6:0)+(w&&w.cat==='sniper'?3:0);
 if(sc<=POTG.score)return;
 const kill=RP.kill,t0=POTG.run[0].t;
 if(POTG.pending)clearTimeout(POTG.pending.to);
 POTG.pending={sc,n,kill,t0,at:G.t};
 // on attend un peu pour avoir la suite de l'action dans le tampon
 POTG.pending.to=setTimeout(potgCapture,1400);
};
function potgCapture(){
 const p=POTG.pending;POTG.pending=null;if(!p||!RP.buf.length)return;
 POTG.score=p.sc;
 POTG.best={n:p.n,kill:p.kill,t0:Math.max(RP.buf[0].t,p.t0-2.2),t1:p.kill.t+1.4,buf:RP.buf.slice(),tracers:RP.tracers.slice()};
}
// fin de partie : on lance la rediffusion avant les résultats
const _matchOverPotg=matchOver;
matchOver=function(){
 if(POTG.pending){clearTimeout(POTG.pending.to);potgCapture();}
 const b=POTG.best;
 if(!b||POTG.playing||NET.role||!b.kill||!ents.includes(b.kill.att)||!ents.includes(b.kill.v)||b.kill.t-b.t0<.6)return _matchOverPotg();
 POTG.playing=true;G.state='potg';G.paused=false;$('pause').classList.remove('show');
 RP.buf.length=0;RP.buf.push(...b.buf);RP.tracers.length=0;RP.tracers.push(...b.tracers);
 RP.kill=b.kill;RP.t0=b.t0;RP.t1=b.t1;RP.on=true;RP.wait=0;RP.rt=RP.t0;RP.prev=RP.t0;RP.cam=null;RP.orbit=0;RP.blood=false;RP.hold=0;
 rpOverlay(true,0);
 const tag=RP.el&&RP.el.querySelector('.tag');if(tag)tag.innerHTML='<i></i>ACTION DU MATCH'+(b.n>1?' · '+(MULTI&&MULTI[Math.min(5,b.n)]||b.n+' éliminations').toUpperCase():'');
 const sk=RP.el&&RP.el.querySelector('.skip');if(sk)sk.textContent=TOUCH&&TOUCH.on?'TOUCHE L\'ÉCRAN — PASSER':'ESPACE — PASSER';
 POTG.skipAt=performance.now()+600;
 sfx('round');
};
function potgFinish(){
 if(!POTG.playing)return;
 POTG.playing=false;RP.on=false;rpOverlay(false);
 const tag=RP.el&&RP.el.querySelector('.tag');if(tag)tag.innerHTML='<i></i>REDIFFUSION · DERNIÈRE ÉLIMINATION';
 G.state='end';_matchOverPotg();
}
const _rpEndPotg=rpEnd;
rpEnd=function(){if(POTG.playing){potgFinish();return;}_rpEndPotg();};
// pendant la rediffusion, la simulation est figée
const _updatePotg=update;
update=function(dt){
 if(G.state==='potg'){if(!RP.on)potgFinish();return;}
 _updatePotg(dt);
};
// Échap pendant la rediffusion : on passe directement aux résultats
document.addEventListener('pointerlockchange',()=>{if(POTG.playing&&!document.pointerLockElement){G.paused=false;$('pause').classList.remove('show');potgFinish();}});
addEventListener('pointerdown',()=>{if(POTG.playing&&performance.now()>POTG.skipAt)potgFinish();});
addEventListener('touchstart',()=>{if(POTG.playing&&performance.now()>POTG.skipAt)potgFinish();},{passive:true});
