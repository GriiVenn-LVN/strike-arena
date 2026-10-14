/* =====================================================================
   CONTRÔLES TACTILES (téléphone / tablette)
   Activés automatiquement sur écran tactile (ou avec ?touch=1 dans l'URL).
   - Moitié gauche : joystick flottant (pousser à fond vers l'avant = sprint)
   - Moitié droite : glisser pour viser ; le bouton TIR vise aussi
   - Boutons : tir, viser, saut, accroupi / glissade, esquive, recharger,
     changer d'arme, grenade, action, boutique, pause
   Les boutons passent par inputDown / inputUp : mêmes règles qu'au clavier.
   ===================================================================== */
const TOUCH={on:false,ui:null,stick:null,look:{},btn:{},sens:.0062,keysOn:{}};
(function(){
 let q=null;try{q=new URLSearchParams(location.search).get('touch');}catch(e){}
 TOUCH.on=q==='1'||(q!=='0'&&!!(window.matchMedia&&matchMedia('(pointer: coarse)').matches&&navigator.maxTouchPoints>0));
})();
// sans souris capturée : on considère le jeu « verrouillé » tant qu'il n'est pas en pause
const _lockMouseBase=lockMouse;
lockMouse=function(){
 if(!TOUCH.on)return _lockMouseBase();
 focusLocked=true;G.paused=false;$('pause').classList.remove('show');touchFullscreen();
};
function touchFullscreen(){
 const d=document.documentElement;
 if(document.fullscreenElement||!d.requestFullscreen)return;
 try{const p=d.requestFullscreen({navigationUI:'hide'});if(p&&p.then)p.then(()=>{try{screen.orientation.lock('landscape').catch(()=>{});}catch(e){}}).catch(()=>{});}catch(e){}
}
function touchPause(){
 if(!G.running||G.state==='over')return;
 focusLocked=false;G.paused=true;$('pause').classList.add('show');touchReleaseAll();
}
function touchKey(act,down){
 const code=cfg.binds[act];if(!code)return;
 if(down){if(TOUCH.keysOn[act])return;TOUCH.keysOn[act]=1;inputDown(code);}
 else{if(!TOUCH.keysOn[act])return;delete TOUCH.keysOn[act];inputUp(code);}
}
function touchReleaseAll(){for(const a in TOUCH.keysOn)touchKey(a,false);TOUCH.stick=null;TOUCH.look={};TOUCH.btn={};if(TOUCH.ui)touchDrawStick();}
const TOUCH_BTNS=[
 // [action, libellé, classe de position, comportement]
 ['fire','TIR','b-fire','hold'],['ads','VISER','b-ads','toggle'],['jump','SAUT','b-jump','hold'],['crouch','ACCROUPI','b-crouch','hold'],
 ['dash','ESQUIVE','b-dash','tap'],['reload','RECH.','b-reload','tap'],['next','ARME','b-swap','tap'],['frag','GRENADE','b-nade','tap'],
 ['use','ACTION','b-use','hold'],['buy','BOUTIQUE','b-buy','tap'],['score','SCORES','b-score','hold']
];
// ajoute un bouton (utilisé par les autres modules, même après la construction de l'interface)
function touchAddBtn(b){
 TOUCH_BTNS.push(b);
 if(TOUCH.ui){const d=document.createElement('div');d.className='tb '+b[2];d.dataset.a=b[0];d.dataset.m=b[3];d.textContent=b[1];TOUCH.ui.appendChild(d);}
}
function touchCss(){
 const s=document.createElement('style');s.textContent=`
body.touch,body.touch canvas{touch-action:none;-webkit-user-select:none;user-select:none;-webkit-touch-callout:none}
#touchUI{position:fixed;inset:0;z-index:30;display:none;touch-action:none;font-family:Bahnschrift,Arial,sans-serif}
#touchUI.on{display:block}
#touchUI .tb{position:absolute;display:flex;align-items:center;justify-content:center;border-radius:50%;background:#0b111c88;border:2px solid #ffffff40;color:#fff;font-weight:800;font-size:10px;letter-spacing:1px;text-shadow:0 1px 2px #000;backdrop-filter:blur(2px)}
#touchUI .tb.on{background:#ff465599;border-color:#ff8a95}
#touchUI .b-fire{width:92px;height:92px;right:120px;bottom:70px;font-size:13px;background:#ff465566;border-color:#ff8a95aa}
#touchUI .b-ads{width:60px;height:60px;right:30px;bottom:150px}
#touchUI .b-jump{width:64px;height:64px;right:28px;bottom:66px}
#touchUI .b-crouch{width:56px;height:56px;right:224px;bottom:30px}
#touchUI .b-dash{width:56px;height:56px;right:216px;bottom:104px}
#touchUI .b-reload{width:50px;height:50px;right:30px;bottom:226px}
#touchUI .b-swap{width:50px;height:50px;right:96px;bottom:186px}
#touchUI .b-nade{width:46px;height:46px;right:162px;bottom:178px}
#touchUI .b-use{width:50px;height:50px;right:240px;bottom:176px;display:none}
#touchUI .b-buy{width:58px;height:46px;right:72px;top:84px;border-radius:12px;display:none}
#touchUI .b-score{width:46px;height:46px;right:16px;top:84px;border-radius:12px}
#touchUI .b-pause{width:46px;height:46px;left:16px;top:16px;border-radius:12px;font-size:16px}
#touchUI .stk{position:absolute;width:120px;height:120px;margin:-60px 0 0 -60px;border-radius:50%;border:2px solid #ffffff38;background:#0b111c55;pointer-events:none;display:none}
#touchUI .stk i{position:absolute;left:50%;top:50%;width:52px;height:52px;margin:-26px 0 0 -26px;border-radius:50%;background:#ffffff55;border:2px solid #fff8}
#touchUI .stk.spr i{background:#ffb35caa}
#touchUI .hintL{position:absolute;left:8%;bottom:16%;color:#fff6;font-size:12px;letter-spacing:2px;pointer-events:none}
#touchUI .hintL.off{display:none}
@media(max-height:520px){#menu .wrap{padding:10px 16px}#menu .mtop{margin-bottom:6px}}
body.touch #pause .panel,body.touch #over .panel{max-height:94vh;overflow:auto}
@media(max-width:1000px){.playgrid{grid-template-columns:1fr!important}#modeCards{grid-template-columns:repeat(4,minmax(0,1fr))!important}#mapChips.mapcards{grid-template-columns:repeat(4,minmax(0,1fr))!important}}
@media(max-height:520px){#touchUI .b-fire{width:80px;height:80px;bottom:52px}#touchUI .b-reload{bottom:196px}#touchUI .b-swap{bottom:160px}#touchUI .b-nade{bottom:152px}#touchUI .b-use{bottom:150px}#touchUI .b-ads{bottom:128px}}
`;document.head.appendChild(s);
}
function touchBuild(){
 if(TOUCH.ui)return;
 touchCss();document.body.classList.add('touch');
 const ui=document.createElement('div');ui.id='touchUI';
 ui.innerHTML='<div class="stk"><i></i></div><div class="hintL">DÉPLACEMENT</div>'+TOUCH_BTNS.map(b=>'<div class="tb '+b[2]+'" data-a="'+b[0]+'" data-m="'+b[3]+'">'+b[1]+'</div>').join('')+'<div class="tb b-pause" data-a="pause" data-m="tap">❚❚</div>';
 document.body.appendChild(ui);TOUCH.ui=ui;
 const opt={passive:false};
 ui.addEventListener('touchstart',touchStart,opt);
 ui.addEventListener('touchmove',touchMove,opt);
 ui.addEventListener('touchend',touchEnd,opt);
 ui.addEventListener('touchcancel',touchEnd,opt);
}
function touchLookDelta(dx,dy){
 if(!G.running||!P||!P.alive||buyOpen||P.emote||!focusLocked)return;
 const w=curW(P),z=P.scoped?1/(typeof sightZoom==='function'?sightZoom(P,w):(w.zoom||2)):1-.25*P.ads,s=TOUCH.sens*cfg.sens*z*wsensMul();
 P.yaw-=dx*s;P.pitch=clamp(P.pitch-dy*s,-1.5,1.5);
}
function touchStart(e){
 e.preventDefault();
 if(!focusLocked&&G.running&&!buyOpen&&G.state!=='over')return;
 for(const t of e.changedTouches){
  const el=document.elementFromPoint(t.clientX,t.clientY),b=el&&el.closest&&el.closest('.tb');
  if(b){
   const a=b.dataset.a,m=b.dataset.m;
   TOUCH.btn[t.identifier]={a,m,el:b,x:t.clientX,y:t.clientY};
   if(a==='pause'){touchPause();continue;}
   if(G.state==='cine'){skipCine();continue;}
   if(m==='toggle'){if(TOUCH.keysOn[a])touchKey(a,false);else touchKey(a,true);b.classList.toggle('on',!!TOUCH.keysOn[a]);}
   else if(m==='hold'){touchKey(a,true);b.classList.add('on');}
   else{touchKey(a,true);touchKey(a,false);b.classList.add('on');setTimeout(()=>b.classList.remove('on'),120);}
   continue;
  }
  if(G.state==='cine'){skipCine();continue;}
  if(!P||!P.alive){inputDown(cfg.binds.fire);inputUp(cfg.binds.fire);continue;}
  if(t.clientX<innerWidth*.42&&!TOUCH.stick){const h=TOUCH.ui.querySelector('.hintL');if(h)h.classList.add('off');}
  if(t.clientX<innerWidth*.42&&!TOUCH.stick)TOUCH.stick={id:t.identifier,x0:t.clientX,y0:t.clientY,x:t.clientX,y:t.clientY};
  else TOUCH.look[t.identifier]={x:t.clientX,y:t.clientY};
 }
 touchApplyStick();
}
function touchMove(e){
 e.preventDefault();
 for(const t of e.changedTouches){
  const id=t.identifier;
  if(TOUCH.stick&&TOUCH.stick.id===id){TOUCH.stick.x=t.clientX;TOUCH.stick.y=t.clientY;continue;}
  const l=TOUCH.look[id]||(TOUCH.btn[id]&&TOUCH.btn[id].a==='fire'?TOUCH.btn[id]:null);
  if(l){touchLookDelta(t.clientX-l.x,t.clientY-l.y);l.x=t.clientX;l.y=t.clientY;}
 }
 touchApplyStick();
}
function touchEnd(e){
 e.preventDefault();
 for(const t of e.changedTouches){
  const id=t.identifier;
  if(TOUCH.stick&&TOUCH.stick.id===id){TOUCH.stick=null;}
  delete TOUCH.look[id];
  const b=TOUCH.btn[id];
  if(b){delete TOUCH.btn[id];if(b.m==='hold'){touchKey(b.a,false);b.el.classList.remove('on');}}
 }
 touchApplyStick();
}
function touchApplyStick(){
 const s=TOUCH.stick;let fx=0,fy=0;
 if(s){const R=50;let dx=s.x-s.x0,dy=s.y-s.y0;const L=Math.hypot(dx,dy);if(L>R){s.x0+=dx*(1-R/L);s.y0+=dy*(1-R/L);dx=s.x-s.x0;dy=s.y-s.y0;}fx=dx/R;fy=dy/R;}
 touchKey('forward',fy<-.3);touchKey('back',fy>.3);touchKey('left',fx<-.3);touchKey('right',fx>.3);
 touchKey('sprint',fy<-.92&&Math.abs(fx)<.5);
 touchDrawStick();
}
function touchDrawStick(){
 const st=TOUCH.ui&&TOUCH.ui.querySelector('.stk');if(!st)return;const s=TOUCH.stick;
 if(!s){st.style.display='none';return;}
 st.style.display='block';st.style.left=s.x0+'px';st.style.top=s.y0+'px';
 st.firstChild.style.transform='translate('+(s.x-s.x0)+'px,'+(s.y-s.y0)+'px)';
 st.classList.toggle('spr',!!TOUCH.keysOn.sprint);
}
// affichage selon l'état de la partie
let touchT=0;
function touchUpdate(dt){
 if(!TOUCH.on)return;
 touchBuild();
 const show=G.running&&G.state!=='over'&&G.state!=='potg'&&!G.paused&&!buyOpen;
 TOUCH.ui.classList.toggle('on',show);
 if(!show){if(Object.keys(TOUCH.keysOn).length&&!buyOpen)touchReleaseAll();return;}
 touchT-=dt;if(touchT>0)return;touchT=.2;
 // HUD plus compact sur petit écran (sauf si l'échelle a été réglée dans Accessibilité)
 const h=$('hud');if(h&&(!cfg.hudS||cfg.hudS===1)&&innerHeight<600&&h.style.zoom!=='0.7')h.style.zoom='0.7';
 const q=s=>TOUCH.ui.querySelector(s);
 q('.b-buy').style.display=(G.mode==='bomb'&&G.state==='freeze'||isDM()&&G.variant!=='zombies'&&G.variant!=='br')?'flex':'none';
 q('.b-use').style.display=P&&P.alive&&P.useMsg?'flex':'none';
 q('.b-ads').classList.toggle('on',!!TOUCH.keysOn.ads);
}
if(TOUCH.on){let tl=performance.now();(function tl1(){requestAnimationFrame(tl1);const n=performance.now();touchUpdate(Math.min(.1,(n-tl)/1000));tl=n;})();}
// boutique et menus : un toucher suffit (pas de capture de souris)
const _closeBuyTouch=closeBuy;
closeBuy=function(silent){_closeBuyTouch(silent);if(TOUCH.on&&G.running&&!silent){focusLocked=true;}};
addEventListener('touchstart',()=>{if(TOUCH.on)initAudio();},{passive:true});
if(TOUCH.on)addEventListener('DOMContentLoaded',()=>document.body.classList.add('touch'));
if(TOUCH.on&&document.body)document.body.classList.add('touch');
