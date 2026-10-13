/* =====================================================================
   DÉPLACEMENTS FAÇON CALL OF DUTY
   - Sprint (Maj) : on appuie une fois en avançant, il reste actif tant
     qu'on avance. Impossible de tirer en sprintant (délai de sortie).
   - Sprint tactique : double appui sur Maj. Plus rapide, arme levée,
     jauge limitée qui se recharge.
   - Glissade : s'accroupir en sprintant. Sauter pendant la glissade
     l'annule en gardant l'élan (slide cancel).
   - Escalade : sauter face à un rebord (caisse, muret, plateforme)
     pour grimper dessus, y compris en plein saut.
   ===================================================================== */
const MV={SPR:1.36,TAC:1.62,TAC_DUR:3,TAC_REC:5,SLIDE_T:.8,SLIDE_CD:.9,OUT:.13,OUT_TAC:.24};
function mvState(p){return p.mv||(p.mv={spr:0,tac:0,tacE:1,lastTap:-9,prevS:false,prevC:false,slideCd:0,w:{spr:0,tac:0,sld:0,mnt:0}});}
function mvReset(p){p.mv=null;p.slide=null;p.mantle=null;}
// sortie de sprint : l'arme met un instant à revenir en position de tir
function mvStopSprint(p){const M=mvState(p);if(!M.spr)return;p.switchT=Math.max(p.switchT,M.tac?MV.OUT_TAC:MV.OUT);M.spr=0;M.tac=0;}
// cherche un rebord escaladable devant le joueur
function mvLedge(p){
 const dx=-Math.sin(p.yaw),dz=-Math.cos(p.yaw);
 for(const d of [.45,.65,.85,1.05]){
  const x=p.x+dx*d,z=p.z+dz*d,h=groundH(x,z),rel=h-p.y;
  if(rel<=.56)continue;
  if(rel>2.15)return null;
  const lx=p.x+dx*(d+.4),lz=p.z+dz*(d+.4),lh=groundH(lx,lz);
  if(Math.abs(lh-h)>.35)return null;
  if(blocked(lx,lz,h+.02)||ceilAt(lx,lz)-h<1.8||ceilAt(p.x,p.z)-h<1.75)return null;
  return {x:lx,z:lz,y:h,rel};
 }
 return null;
}
// renvoie le multiplicateur de vitesse ; gère sprint / sprint tactique / glissade
function mvPre(p,dt,fx,fz){
 const M=mvState(p),frozen=G.state==='freeze'&&G.mode==='bomb';
 const sk=K('sprint'),press=sk&&!M.prevS;M.prevS=sk;
 const ck=K('crouch'),cPress=ck&&!M.prevC;M.prevC=ck;
 const fwd=fz>.3;
 M.slideCd=Math.max(0,M.slideCd-dt);
 if(!M.tac)M.tacE=Math.min(1,M.tacE+dt/MV.TAC_REC);
 // départ du sprint / double appui = sprint tactique
 if(press&&fwd&&p.onGround&&!p.downed&&!frozen&&!p.slide&&!p.mantle){
  if(M.spr&&G.t-M.lastTap<.35&&M.tacE>.3)M.tac=1;
  M.spr=1;M.lastTap=G.t;
 }
 // ce qui coupe le sprint
 if(M.spr&&(!fwd||mouseR||p.downed||frozen||buyOpen||p.crouch&&!cPress))mvStopSprint(p);
 if(M.spr&&mouseL){mvStopSprint(p);}
 if(M.tac){const dur=MV.TAC_DUR*(p.perks&&p.perks.stamin?2:1);M.tacE-=dt/dur;if(M.tacE<=0){M.tacE=0;M.tac=0;}}
 // glissade
 if(cPress&&M.spr&&p.onGround&&M.slideCd<=0&&p.speed>RUN*.95){
  const L=Math.hypot(p.vx,p.vz)||1;
  p.slide={t:0,dx:p.vx/L,dz:p.vz/L,v:Math.max(p.speed*1.22,8.6)};
  M.spr=0;M.tac=0;M.slideCd=MV.SLIDE_CD;sfx('slide',p.x,p.z,.7);
 }
 if(p.slide){
  p.slide.t+=dt;
  if(p.slide.t>=MV.SLIDE_T||!p.onGround&&p.slide.t>.15)p.slide=null;
 }
 return M.spr?(M.tac?MV.TAC:MV.SPR):1;
}
// glissade : vitesse imposée qui décroît ; renvoie true si elle pilote le mouvement
function mvSlide(p,dt){
 const s=p.slide;if(!s)return false;
 const k=s.t/MV.SLIDE_T,v=lerp(s.v,RUN*.45,k*k);
 // léger contrôle à la souris
 const yx=-Math.sin(p.yaw),yz=-Math.cos(p.yaw);s.dx+=(yx-s.dx)*dt*.8;s.dz+=(yz-s.dz)*dt*.8;const L=Math.hypot(s.dx,s.dz)||1;s.dx/=L;s.dz/=L;
 p.vx=s.dx*v;p.vz=s.dz*v;
 if(K('jump')&&s.t>.08){p.slide=null;p.vy=JUMPV;p.onGround=false;p.crouch=false;sfx('jump');}
 return true;
}
// escalade
function mvTryMantle(p,fz){
 if(p.mantle||p.downed||fz<.2||!K('jump')||G.state==='freeze'&&G.mode==='bomb')return false;
 if(!p.onGround&&p.vy>4.5)return false;
 const l=mvLedge(p);if(!l)return false;
 p.mantle={t:0,dur:.26+.12*l.rel,x0:p.x,y0:p.y,z0:p.z,x1:l.x,y1:l.y,z1:l.z};
 p.slide=null;mvStopSprint(p);p.switchT=Math.max(p.switchT,p.mantle.dur+.05);p.ads=0;
 sfx('land',p.x,p.z,.45);return true;
}
function mvMantle(p,dt){
 const m=p.mantle;if(!m)return false;
 m.t+=dt;const a=Math.min(1,m.t/m.dur);
 const up=smooth01(Math.min(1,a/.6)),fw=smooth01(clamp((a-.25)/.75,0,1));
 p.y=m.y0+(m.y1+.04-m.y0)*up;p.x=m.x0+(m.x1-m.x0)*fw;p.z=m.z0+(m.z1-m.z0)*fw;
 p.vx=p.vz=p.vy=0;p.speed=0;p.onGround=false;
 if(a>=1){p.y=m.y1;p.onGround=true;p.mantle=null;mvState(p).jl=G.t+.35;sfx('step',p.x,p.z,.3,surfaceAt(p.x,p.z));}
 return true;
}
// poids lissés pour la vue subjective et la caméra
function mvWeights(p,dt){
 const M=mvState(p),w=M.w,f=Math.min(1,dt*9);
 w.spr+=((M.spr&&!M.tac&&p.speed>RUN*.8?1:0)-w.spr)*f;
 w.tac+=((M.tac&&p.speed>RUN*.8?1:0)-w.tac)*f;
 w.sld+=((p.slide?1:0)-w.sld)*Math.min(1,dt*12);
 w.mnt+=((p.mantle?1:0)-w.mnt)*Math.min(1,dt*14);
 return w;
}
// petite jauge de sprint tactique sous le viseur
function mvHud(){
 if(!P)return;let el=$('tacbar');
 if(!el){el=document.createElement('div');el.id='tacbar';el.style.cssText='position:fixed;left:50%;top:calc(50% + 46px);width:64px;height:4px;margin-left:-32px;border-radius:3px;background:#0008;overflow:hidden;pointer-events:none;z-index:6;transition:opacity .3s';el.innerHTML='<i style="display:block;height:100%;background:#ffb35c;width:100%"></i>';($('hud')||document.body).appendChild(el);}
 const M=P.mv,show=G.running&&P.alive&&M&&(M.tac||M.tacE<.999);
 el.style.opacity=show?1:0;if(show)el.firstChild.style.width=Math.round(M.tacE*100)+'%';
}
