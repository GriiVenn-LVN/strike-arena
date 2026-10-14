/* =====================================================================
   QUALITÉ AUTOMATIQUE
   Si les images par seconde restent basses en jeu, la résolution de
   rendu baisse par paliers (jusqu'à 55 %), puis la qualité graphique
   descend d'un cran (Haute → Moyenne → Basse). Quand ça redevient
   fluide longtemps, la résolution remonte. Réglage : Réglages ›
   Qualité automatique (activée par défaut).
   ===================================================================== */
cfg.autoGfx=cfg.autoGfx===undefined?1:cfg.autoGfx;
const AQ={scale:1,acc:0,n:0,low:0,high:0,last:performance.now(),cool:0};
const AQ_LOW=40,AQ_HIGH=57,AQ_MIN=.55;
const _resizeAQ=resize;
resize=function(){
 _resizeAQ();
 if(AQ.scale<1)renderer.setPixelRatio(renderer.getPixelRatio()*AQ.scale);
 if(typeof postSize==='function')postSize();
};
function aqApply(msg){resize();if(msg)uiToast(msg);}
function aqStep(dt){
 const fps=AQ.n/AQ.acc;AQ.acc=0;AQ.n=0;
 if(AQ.cool>0){AQ.cool-=1;return;}
 if(fps<AQ_LOW){AQ.low++;AQ.high=0;}else if(fps>AQ_HIGH){AQ.high++;AQ.low=0;}else{AQ.low=0;AQ.high=0;}
 if(AQ.low>=3){ // ~3 s sous 40 FPS
  AQ.low=0;AQ.cool=3;
  if(AQ.scale>AQ_MIN+.01){AQ.scale=Math.max(AQ_MIN,AQ.scale-.15);aqApply('Qualité auto : résolution '+Math.round(AQ.scale*100)+' %');}
  else if(cfg.gfx>0){cfg.gfx--;AQ.scale=.85;saveCfg();aqApply('Qualité auto : graphismes '+['Basse','Moyenne','Haute'][cfg.gfx]);if(typeof buildOpts==='function')try{buildOpts();}catch(e){}}
 }else if(AQ.high>=12&&AQ.scale<1){ // ~12 s au-dessus de 57 FPS
  AQ.high=0;AQ.cool=3;AQ.scale=Math.min(1,AQ.scale+.15);aqApply();
 }
}
const _renderAQ=render;
render=function(dt,t){
 _renderAQ(dt,t);
 const now=performance.now(),rd=(now-AQ.last)/1000;AQ.last=now;
 if(!cfg.autoGfx||!G.running||G.paused||document.hidden||rd>.5)return; // pause, onglet caché : on ne compte pas
 AQ.acc+=rd;AQ.n++;
 if(AQ.acc>=1)aqStep();
};
// réglage
const _buildOptsAQ=buildOpts;
buildOpts=function(){
 _buildOptsAQ();
 let g=$('gAutoGfx');
 if(!g){
  const anchor=$('cGfx')&&$('cGfx').closest('.grp');if(!anchor)return;
  g=document.createElement('div');g.className='grp';g.id='gAutoGfx';g.innerHTML='<label>Qualité automatique</label><div class="chips" id="cAutoGfx"></div><small>Baisse la résolution puis la qualité si le jeu rame.</small>';
  anchor.parentNode.insertBefore(g,anchor.nextSibling);
 }
 chipsRow('cAutoGfx',[['Activée',1],['Désactivée',0]],()=>cfg.autoGfx?1:0,v=>{cfg.autoGfx=v;if(!v&&AQ.scale<1){AQ.scale=1;resize();}},buildOpts);
};
