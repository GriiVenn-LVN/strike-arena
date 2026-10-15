/* =====================================================================
   CORRECTIONS DU 15/10
   - Quitter vers le menu pendant une kill-cam ou une rediffusion :
     les bandes noires et « KILL-CAM » restaient affichées sur le menu,
     et la kill-cam suivante était bloquée.
   - Quitter vers le menu laissait les objets du mode dans le décor du
     menu (drapeaux de Domination, plaques, objets Zombies, zone…).
   - Recommencer pendant une kill-cam la laissait active (la suivante
     ne se lançait plus).
   - Armes prodiges (Zombies) : les tirs comptaient, jamais les touches,
     donc la précision affichée chutait.
   ===================================================================== */
function fixStopReplay(){
 if(typeof KCAM!=='undefined'&&KCAM.on){KCAM.on=false;KCAM.px=null;}
 if(typeof POTG!=='undefined')POTG.playing=false;
 if(RP.on){RP.on=false;rpOverlay(false);}
}
const _toMenuFix=toMenu;
toMenu=function(){
 fixStopReplay();
 try{variantCleanup();}catch(e){console.error(e);}
 if(typeof VOTE!=='undefined'){VOTE.timers.forEach(clearTimeout);VOTE.timers.length=0;VOTE.on=false;}
 return _toMenuFix.apply(this,arguments);
};
$('toMenu').onclick=()=>toMenu();$('oMenu').onclick=()=>toMenu();
const _rpResetFix=rpReset;
rpReset=function(){if(typeof KCAM!=='undefined'&&KCAM.on){KCAM.on=false;KCAM.px=null;}return _rpResetFix.apply(this,arguments);};
// armes prodiges : une touche = au moins un ennemi blessé par le tir
const _wonderFireFix=wonderFire;
wonderFire=function(e,w,wi){
 if(!e||!e.isPlayer)return _wonderFireFix(e,w,wi);
 const hp=new Map();for(const v of ents)if(v.alive&&v!==e)hp.set(v,v.hp);
 const r=_wonderFireFix(e,w,wi);
 for(const [v,h] of hp)if(v.hp<h||!v.alive){MS.hits++;break;}
 return r;
};
