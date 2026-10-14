/* =====================================================================
   KILL-CAM (façon Call of Duty)
   Quand tu meurs dans un mode avec réapparition (MàM, Capture, Domination,
   Infecté, Course aux armes…) ou en Bataille royale, on rejoue les
   dernières secondes vues par-dessus l'épaule de celui qui t'a tué.
   ESPACE ou clic pour passer. Réglage : Réglages › Plus d'options.
   Réutilise le moteur de rediffusion de 6A_replay.js.
   ===================================================================== */
cfg.killcam=cfg.killcam===undefined?1:cfg.killcam;
const KCAM={on:false,respT:0};
const kcMode=()=>G.mode!=='bomb'&&G.variant!=='zombies'&&G.variant!=='train';
function kcStart(){
 const k=RP.kill;
 if(!cfg.killcam||!kcMode()||G.netClient||NET.role||RP.on||POTG.playing)return;
 if(!k||k.v!==P||!k.att||k.att===P||!k.att.rig||!RP.buf.length)return;
 RP.t0=Math.max(RP.buf[0].t,k.t-2.2);RP.t1=k.t+.6;
 if(k.t-RP.t0<.6)return;
 KCAM.on=true;RP.on=true;RP.wait=.5;RP.rt=RP.t0;RP.prev=RP.t0;RP.cam=null;RP.orbit=0;RP.blood=false;RP.hold=.6;
 // la réapparition attend la fin de la kill-cam
 KCAM.respT=P.respT;if(isFinite(P.respT))P.respT=99;
}
function kcFinish(){
 KCAM.on=false;
 if(P&&!P.alive&&isFinite(KCAM.respT)&&P.respT>KCAM.respT)P.respT=Math.min(KCAM.respT,.4);
 const tag=RP.el&&RP.el.querySelector('.tag');if(tag)tag.innerHTML='<i></i>REDIFFUSION · DERNIÈRE ÉLIMINATION';
}
const _killEntKc=killEnt;
killEnt=function(v,att,w,hs){
 const was=v.alive;_killEntKc(v,att,w,hs);
 if(was&&!v.alive&&v===P&&G.state==='live')kcStart();
};
// pendant la kill-cam, les autres éliminations ne remplacent pas celle qu'on rejoue
const _rpKillKc=rpKill;
rpKill=function(att,v,w,hs){if(KCAM.on)return;_rpKillKc(att,v,w,hs);};
const _rpEndKc=rpEnd;
rpEnd=function(){
 if(!KCAM.on)return _rpEndKc();
 RP.on=false;rpOverlay(false);kcFinish();
 for(const e of ents)if(e.rig&&!e.alive)e.rig.dieT=9; // corps déjà au sol après la rediffusion
};
const _rpOverlayKc=rpOverlay;
rpOverlay=function(on,prog){
 _rpOverlayKc(on,prog);
 if(on&&KCAM.on){const tag=RP.el.querySelector('.tag');if(tag&&!tag.dataset.kc){tag.innerHTML='<i></i>KILL-CAM';}}
};
// fin de partie ou retour au menu : on coupe proprement
const _matchOverKc=matchOver;
matchOver=function(){if(KCAM.on){RP.on=false;rpOverlay(false);kcFinish();}return _matchOverKc();};
const _endDMKc=endDM;
endDM=function(){if(KCAM.on){RP.on=false;rpOverlay(false);kcFinish();}return _endDMKc();};
addEventListener('mousedown',()=>{if(KCAM.on&&RP.on&&RP.wait<=0)rpEnd();});
// réglage
const _buildOptsKc=buildOpts;
buildOpts=function(){
 _buildOptsKc();
 let g=$('gKillcam');
 if(!g){
  const anchor=$('cCine')&&$('cCine').closest('.grp');if(!anchor)return;
  g=document.createElement('div');g.className='grp';g.id='gKillcam';g.innerHTML='<label>Kill-cam</label><div class="chips" id="cKillcam"></div><small>Rejoue ta mort du point de vue du tueur (modes avec réapparition).</small>';
  anchor.parentNode.insertBefore(g,anchor.nextSibling);
 }
 chipsRow('cKillcam',[['Activée',1],['Désactivée',0]],()=>cfg.killcam?1:0,v=>cfg.killcam=v,buildOpts);
};
