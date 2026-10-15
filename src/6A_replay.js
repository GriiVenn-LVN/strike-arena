/* =====================================================================
   REDIFFUSION DU DERNIER KILL (fin de manche, mode compétitif)
   On enregistre les 8 dernières secondes (positions, visée, tirs) puis,
   à la fin de la manche, on rejoue l'élimination en caméra cinéma :
   épaule du tueur -> ralenti au moment du tir -> orbite autour de la
   victime. ESPACE pour passer.
   ===================================================================== */
// fp : rediffusions en première personne, par les yeux du tueur (voir 8R_killcam.js)
const RP={fp:true,buf:[],acc:0,step:1/30,keep:8,tracers:[],kill:null,on:false,wait:0,rt:0,t0:0,t1:0,prev:0,el:null,cam:null,look:null,orbit:0,saved:null};
function rpRecord(dt){
 if(G.state!=='live'&&G.state!=='end')return;
 if(RP.on&&RP.wait<=0)return;
 RP.acc+=dt;if(RP.acc<RP.step)return;RP.acc=0;
 const fr={t:G.t,s:[]};
 for(const e of ents){if(!e.rig||e.dummy)continue;
  fr.s.push({e,x:e.x,y:e.y,z:e.z,yaw:e.yaw,pitch:e.pitch,alive:e.alive,crouch:e.crouch,speed:e.speed,vx:e.vx,vz:e.vz,fire:e.fireAnim,onGround:e.onGround,reload:e.reload,reloadMax:e.reloadMax,dieDir:e.dieDir,wk:(curWi(e)||{k:'knife'}).k,mag:(curWi(e)||{mag:1}).mag});}
 RP.buf.push(fr);
 while(RP.buf.length&&G.t-RP.buf[0].t>RP.keep)RP.buf.shift();
 while(RP.tracers.length&&G.t-RP.tracers[0].t>RP.keep)RP.tracers.shift();
}
function rpTracer(x0,y0,z0,x1,y1,z1,col){if(RP.on||!G.running)return;RP.tracers.push({t:G.t,x0,y0,z0,x1,y1,z1,col});}
function rpKill(att,v,w,hs){
 if(!att||att===v||!att.rig||!v.rig)return;
 RP.kill={t:G.t,att,v,w,hs,round:G.round,wk:Object.keys(W).find(k=>W[k]===w)||curWi(att).k};
}
function rpReset(){RP.buf.length=0;RP.tracers.length=0;RP.kill=null;RP.on=false;rpOverlay(false);}
/* lancé par endRound */
function rpStart(){
 const k=RP.kill;
 if(!k||k.round!==G.round||G.mode!=='bomb'||!RP.buf.length)return;
 if(G.t-k.t>9)return;
 RP.t0=Math.max(RP.buf[0].t,k.t-3.2);RP.t1=k.t+1.4;
 if(k.t-RP.t0<.8)return;
 RP.on=true;RP.wait=1.5;RP.rt=RP.t0;RP.prev=RP.t0;RP.cam=null;RP.orbit=0;RP.blood=false;
 G.endT=Math.max(G.endT,RP.wait+(RP.t1-RP.t0)+2.2+1);
}
function rpEnd(){
 RP.on=false;rpOverlay(false);
 for(const e of ents)if(e.rig&&!e.alive)e.rig.dieT=9;
 G.endT=Math.min(G.endT,1.2);
}
function rpUpdate(dt){if(RP.on&&RP.wait>0)RP.wait-=dt;}
addEventListener('keydown',e=>{if(RP.on&&RP.wait<=0&&(e.code==='Space'||e.code==='Escape')){e.preventDefault();rpEnd();}},true);
/* ---------- rendu ---------- */
function rpFrame(rt){
 const b=RP.buf;let i=0;while(i<b.length-2&&b[i+1].t<rt)i++;
 const a=b[i],c=b[Math.min(b.length-1,i+1)],k=c.t>a.t?clamp((rt-a.t)/(c.t-a.t),0,1):0;
 return {a,c,k};
}
const lerpAng=(a,b,k)=>a+angDiff(a,b)*k;
function rpRender(dt,t){
 const kill=RP.kill;
 // vitesse : normale, ralenti autour du tir, puis normale
 const near=Math.abs(RP.rt-kill.t);const sp=near<.55?.28:near<1?.55:1;
 RP.t1=Math.min(RP.t1,RP.buf[RP.buf.length-1].t);
 RP.prev=RP.rt;RP.rt=Math.min(RP.t1,RP.rt+dt*sp);
 const {a,c,k}=rpFrame(RP.rt);
 // appliquer l'état enregistré aux soldats
 const cmap=new Map();for(const s of c.s)cmap.set(s.e,s);
 for(const e of ents){if(e.rig)e.rig.root.visible=false;}
 for(const s of a.s){
  const e=s.e,R=e.rig;if(!R||!ents.includes(e))continue;const n=cmap.get(e)||s;
  const x=lerp(s.x,n.x,k),y=lerp(s.y,n.y,k),z=lerp(s.z,n.z,k),yaw=lerpAng(s.yaw,n.yaw,k),alive=k<.5?s.alive:n.alive;
  R.root.visible=true;R.root.position.x=x;R.root.position.z=z;R.root.rotation.y=yaw;
  if(R.gk!==s.wk)setSoldierGun(R,s.wk);
  animateSoldier(R,{vx:s.vx,vz:s.vz,yaw,pitch:lerp(s.pitch,n.pitch,k),speed:s.speed,onGround:s.onGround,crouch:s.crouch,alive,reload:s.reload,reloadMax:s.reloadMax,fire:s.fire,ready:1,alert:1,hurt:false,dieDir:s.dieDir,y,dance:null,danceT:0,seated:0},dt*sp,t);
  if(R.label)R.label.visible=false;
  s._x=x;s._y=y;s._z=z;s._yaw=yaw;s._pitch=lerp(s.pitch,n.pitch,k);
 }
 // tirs rejoués
 for(const tr of RP.tracers){if(tr.t>RP.prev&&tr.t<=RP.rt){addTracer(tr.x0,tr.y0,tr.z0,tr.x1,tr.y1,tr.z1,tr.col);
  if(Math.hypot(tr.x0-camera.position.x,tr.z0-camera.position.z)<30)sfx(W[RP.kill.wk]?W[RP.kill.wk].cat:'rifle',tr.x0,tr.z0,.45);}}
 const ka=a.s.find(s=>s.e===kill.att),va=a.s.find(s=>s.e===kill.v);
 if(!ka||!va){rpEnd();return;}
 if(!RP.blood&&RP.rt>=kill.t){RP.blood=true;const d=dirOf(ka._yaw,0);fxBlood(va._x,va._y+(kill.hs?1.6:1.2),va._z,[-d[0],0,-d[2]],kill.hs?14:8,kill.hs);if(kill.hs)sfx('hs');}
 // caméra (kill-cam en première personne : yeux du tueur, voir 8R_killcam.js)
 if(RP.fp)rpFPCam(ka,dt*sp);else{
 const d=dirOf(ka._yaw,ka._pitch),rx=Math.cos(ka._yaw),rz=-Math.sin(ka._yaw);
 const eye=ka._y+(ka.crouch?1.15:1.6);
 let cx,cy,cz,lx,ly,lz;
 if(RP.rt<kill.t+.15){
  // par-dessus l'épaule du tueur
  cx=ka._x-d[0]*2.1+rx*.65;cy=eye+.32-d[1]*1.2;cz=ka._z-d[2]*2.1+rz*.65;
  const vd=Math.hypot(va._x-ka._x,va._z-ka._z);lx=ka._x+d[0]*vd;ly=eye+d[1]*vd;lz=ka._z+d[2]*vd;
  // ne pas traverser les murs : on rapproche la caméra si besoin
  const bx=cx-ka._x,by=cy-eye,bz=cz-ka._z,bl=Math.hypot(bx,by,bz),hit=rayWall(ka._x,eye,ka._z,bx/bl,by/bl,bz/bl,bl);
  if(hit<bl){const f=Math.max(.3,hit-.25)/bl;cx=ka._x+bx*f;cy=eye+by*f;cz=ka._z+bz*f;}
 }else{
  // orbite lente autour de la victime
  RP.orbit+=dt*.35;const base=Math.atan2(ka._x-va._x,ka._z-va._z)+.9+RP.orbit;
  let r=3.4;const vy=va._y+1.6;
  for(;r>1;r-=.4){const ox=Math.sin(base),oz=Math.cos(base);if(rayWall(va._x,vy,va._z,ox,.35,oz,r)>=r)break;}
  cx=va._x+Math.sin(base)*r;cy=vy+r*.35;cz=va._z+Math.cos(base)*r;lx=va._x;ly=va._y+.5;lz=va._z;
 }
 if(!RP.cam){RP.cam=new THREE.Vector3(cx,cy,cz);RP.look=new THREE.Vector3(lx,ly,lz);}
 const sm=Math.min(1,dt*6);RP.cam.lerp(_rpv.set(cx,cy,cz),sm);RP.look.lerp(_rpv.set(lx,ly,lz),sm);
 camera.position.copy(RP.cam);camera.lookAt(RP.look);camera.fov+=((RP.rt>kill.t-.5&&RP.rt<kill.t+.6?48:62)-camera.fov)*Math.min(1,dt*3);camera.updateProjectionMatrix();
 lis.x=RP.cam.x;lis.z=RP.cam.z;lis.yaw=Math.atan2(-(RP.look.x-RP.cam.x),-(RP.look.z-RP.cam.z));
 }
 if(skyG)skyG.position.copy(camera.position);
 updateFX(dt*sp,t);
 renderer.clear();renderer.render(scene,camera);
 if(RP.fp)rpFPView(dt*sp,t);
 rpOverlay(true,(RP.rt-RP.t0)/(RP.t1-RP.t0));
 if(RP.rt>=RP.t1){RP.hold=(RP.hold||0)+dt;if(RP.hold>1){RP.hold=0;rpEnd();}}
}
const _rpv=new THREE.Vector3();
function rpOverlay(on,prog){
 if(!RP.el){
  const d=document.createElement('div');d.id='rpov';
  d.innerHTML='<div class="bt"></div><div class="bb"></div><div class="tag"><i></i>REDIFFUSION · DERNIÈRE ÉLIMINATION</div><div class="who"></div><div class="pg"><b></b></div><div class="skip">ESPACE — PASSER</div>';
  document.body.appendChild(d);RP.el=d;
  const s=document.createElement('style');s.textContent='#rpov{position:fixed;inset:0;z-index:14;pointer-events:none;display:none;font-family:Bahnschrift,Arial}#rpov.on{display:block}#rpov .bt,#rpov .bb{position:absolute;left:0;right:0;height:10vh;background:#000}#rpov .bt{top:0}#rpov .bb{bottom:0}'+
   '#rpov .tag{position:absolute;top:12.5vh;left:4vw;font-weight:900;letter-spacing:5px;font-size:.95rem;color:#fff;text-shadow:0 0 10px #000}#rpov .tag i{display:inline-block;width:12px;height:12px;border-radius:50%;background:#ff2a3a;margin-right:10px;vertical-align:-1px;animation:rec 1s infinite}@keyframes rec{50%{opacity:.2}}'+
   '#rpov .who{position:absolute;bottom:13vh;left:0;right:0;text-align:center;font-size:1.7rem;font-weight:900;letter-spacing:4px;color:#fff;text-shadow:0 0 18px #000;animation:ovin .5s}#rpov .who img{height:1.9rem;vertical-align:middle;margin:0 16px;filter:drop-shadow(0 0 4px #000)}#rpov .who em{font-style:normal;color:#ff4655}#rpov .who .hs{display:inline-block;margin-left:14px;font-size:.8rem;padding:3px 9px;background:#ff4655;letter-spacing:2px;vertical-align:middle}'+
   '#rpov .pg{position:absolute;bottom:10.6vh;left:30vw;right:30vw;height:3px;background:#ffffff30}#rpov .pg b{display:block;height:100%;background:#ff4655;width:0}#rpov .skip{position:absolute;bottom:4vh;right:4vw;color:#fff9;font-size:.75rem;letter-spacing:3px}';
  document.head.appendChild(s);
 }
 const el=RP.el;el.classList.toggle('on',!!on);$('hud').style.visibility=on?'hidden':'';$('sb').style.visibility=on?'hidden':'';
 if(!on)return;
 if(!el._k||el._k!==RP.kill){el._k=RP.kill;const k=RP.kill,me=k.att.isPlayer,vic=k.v.isPlayer;
  el.querySelector('.who').innerHTML=(me?'<em>'+k.att.name+'</em>':k.att.name)+'<img src="'+weaponImg(k.wk)+'">'+(vic?'<em>'+k.v.name+'</em>':k.v.name)+(k.hs?'<span class="hs">TÊTE</span>':'');}
 el.querySelector('.pg b').style.width=Math.round(clamp(prog,0,1)*100)+'%';
}
