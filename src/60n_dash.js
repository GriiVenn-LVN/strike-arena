/* =====================================================================
   ESQUIVE (façon RIVALS / Bad Business)
   - Touche Esquive (Z physique par défaut, réassignable) ou double appui
     sur Gauche / Droite : courte poussée dans la direction du mouvement.
   - Utilisable au sol et une fois en l'air, recharge de 1,6 s.
   - Se greffe sur mvPre / mvSlide (60m_move.js) sans les modifier.
   ===================================================================== */
const DASH={T:.17,V:13.5,CD:1.6,TAP:.24};
DEFBINDS.dash='KeyZ';BINDLABEL.dash='Esquive (ou 2× Gauche / Droite)';
if(!cfg.binds.dash)cfg.binds.dash=DEFBINDS.dash;
const _dashPrev={l:false,r:false,d:false},_dashTap={l:-9,r:-9};
function dashTry(p,fx,fz,dir){
 const M=mvState(p);
 if(p.dash||p.mantle||p.downed||p.emote||(M.dashCd||0)>G.t)return;
 if(G.state==='freeze'&&G.mode==='bomb'||G.state==='cine'||buyOpen)return;
 if(!p.onGround&&M.airDash)return;
 // direction : celle des touches, sinon le côté demandé, sinon vers l'avant
 let ix=fx,iz=fz;if(!ix&&!iz){if(dir)ix=dir;else iz=1;}
 const L=Math.hypot(ix,iz)||1;ix/=L;iz/=L;
 const dx=-Math.sin(p.yaw)*iz+Math.cos(p.yaw)*ix,dz=-Math.cos(p.yaw)*iz-Math.sin(p.yaw)*ix;
 p.slide=null;mvStopSprint(p);
 p.dash={t:0,dx,dz};M.dashCd=G.t+DASH.CD;if(!p.onGround)M.airDash=true;
 if(!p.onGround&&p.vy<1.5)p.vy=1.5;
 sfx('slide',p.x,p.z,.55);if(p.isPlayer)G.shake=Math.max(G.shake,.12);
}
const _mvPreBase=mvPre;
mvPre=function(p,dt,fx,fz){
 const r=_mvPreBase(p,dt,fx,fz);
 if(!p.isPlayer)return r;
 const M=mvState(p);if(p.onGround)M.airDash=false;
 const l=K('left'),rt=K('right'),d=K('dash');
 if(d&&!_dashPrev.d)dashTry(p,fx,fz,0);
 if(l&&!_dashPrev.l){if(G.t-_dashTap.l<DASH.TAP)dashTry(p,-1,0,-1);_dashTap.l=G.t;}
 if(rt&&!_dashPrev.r){if(G.t-_dashTap.r<DASH.TAP)dashTry(p,1,0,1);_dashTap.r=G.t;}
 _dashPrev.l=l;_dashPrev.r=rt;_dashPrev.d=d;
 return p.dash?1:r;
};
const _mvSlideBase=mvSlide;
mvSlide=function(p,dt){
 const s=p.dash;
 if(s&&G.state==='freeze'&&G.mode==='bomb')p.dash=null;
 else if(s){
  s.t+=dt;const k=s.t/DASH.T,v=lerp(DASH.V,RUN,k*k);
  p.vx=s.dx*v;p.vz=s.dz*v;
  if(s.t>=DASH.T)p.dash=null;
  return true;
 }
 return _mvSlideBase(p,dt);
};
const _mvWeightsBase=mvWeights;
mvWeights=function(p,dt){
 const w=_mvWeightsBase(p,dt);
 if(p.dash)w.sld=Math.max(w.sld,.8);
 return w;
};
// petite jauge d'esquive à côté de la jauge de sprint
const _mvHudBase=mvHud;
mvHud=function(){
 _mvHudBase();if(!P)return;
 let el=$('dashbar');
 if(!el){el=document.createElement('div');el.id='dashbar';el.style.cssText='position:fixed;left:50%;top:calc(50% + 54px);width:40px;height:3px;margin-left:-20px;border-radius:2px;background:#0008;overflow:hidden;pointer-events:none;z-index:6;transition:opacity .3s';el.innerHTML='<i style="display:block;height:100%;background:#5cd6ff;width:100%"></i>';($('hud')||document.body).appendChild(el);}
 const M=P.mv,left=M&&M.dashCd?M.dashCd-G.t:0,show=G.running&&P.alive&&left>0;
 el.style.opacity=show?1:0;if(show)el.firstChild.style.width=Math.round((1-left/DASH.CD)*100)+'%';
};
const _mvResetBase=mvReset;
mvReset=function(p){_mvResetBase(p);p.dash=null;};
