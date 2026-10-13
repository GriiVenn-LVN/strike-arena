/* =====================================================================
   ÉQUIPEMENT : mines de proximité (achetables, touche X)
   - posées au sol, armées après 1 s, explosent au passage d'un ennemi
   - se cassent : une balle, un coup de couteau ou une explosion les détruit
   - les bots en posent, et tirent sur les mines ennemies qu'ils repèrent
   + difficulté adaptative des bots
   ===================================================================== */
const MINES=[],AFX=[];
const MINE_PRICE=350,MINE_MAX=2,MINE_SEE=8;
// compatibilité : plus d'agents ni de capacités
function assignAgents(){for(const e of ents){e.mineSeen=null;e.mineT=0;e.bot_t=rand(0,1);}}
function mineMesh(team){
 const g=new THREE.Group();
 const b=new THREE.Mesh(new THREE.CylinderGeometry(.2,.24,.08,16),new THREE.MeshStandardMaterial({color:0x3a4033,roughness:.6,metalness:.5}));b.position.y=.04;g.add(b);
 const t=new THREE.Mesh(new THREE.CylinderGeometry(.09,.1,.04,12),new THREE.MeshStandardMaterial({color:0x22261f,roughness:.5,metalness:.6}));t.position.y=.1;g.add(t);
 for(let i=0;i<3;i++){const p=new THREE.Mesh(new THREE.CylinderGeometry(.008,.008,.07,5),new THREE.MeshStandardMaterial({color:0x999999,metalness:.9,roughness:.3}));p.position.set(Math.cos(i*2.1)*.05,.14,Math.sin(i*2.1)*.05);g.add(p);}
 const l=new THREE.Mesh(new THREE.SphereGeometry(.028,8,8),new THREE.MeshBasicMaterial({color:0x666666,toneMapped:false}));l.position.set(.13,.09,0);g.add(l);
 g.userData.led=l;return g;
}
function placeMine(e){
 if(NET.role==='client'&&e.isPlayer&&G.netClient){if(!(e.nade.mn>0))return false;netSend({t:'mine'},'host');return true;}
 if(!e.alive||!(e.nade.mn>0))return false;
 if(G.mode==='bomb'&&G.state==='freeze')return false;
 const own=MINES.filter(m=>m.owner===e);if(own.length>=MINE_MAX){removeMine(own[0],false);}
 const d=dirOf(e.yaw,0),x=e.x+d[0]*.8,z=e.z+d[2]*.8;
 if(blocked(x,z,e.y,.2))return false;
 const y=groundH(x,z),m=mineMesh(e.team);m.position.set(x,y,z);m.rotation.y=rand(0,TAU);scene.add(m);
 MINES.push({x,z,y,owner:e,team:e.team,m,l:m.userData.led,armT:1});
 e.nade.mn--;sfx('click',x,z,.7);if(e.isPlayer){vmThrow();uiToast('Mine posée');}
 return true;
}
function removeMine(m,boom){
 const i=MINES.indexOf(m);if(i<0)return;MINES.splice(i,1);scene.remove(m.m);
 if(boom){G.minesBoom=(G.minesBoom||0)+1;explodeMine(m);}
 else{G.minesBroken=(G.minesBroken||0)+1;sfx('click',m.x,m.z,.8);fxSpark(m.x,m.y+.1,m.z,8);fxDust(m.x,m.y+.05,m.z,4,.2);}
}
const isFoeMine=(m,e)=>m.owner!==e&&(!MODE().team||m.team!==e.team);
function explodeMine(m){
 sfx('boom',m.x,m.z,.7);fxExplosion(m.x,m.y+.3,m.z,.55);
 for(const v of ents){
  if(!v.alive)continue;
  const d=Math.hypot(v.x-m.x,v.z-m.z);if(d>5||Math.abs(v.y-m.y)>2.2)continue;
  if(MODE().team&&v.team===m.team&&v!==m.owner)continue;
  hurt(v,m.owner,MINEW,'b',d,Math.round(95*(1-d/5)+10));
 }
}
const MINEW={n:'Mine',kill:300,hs:1,ap:.5,fo:999,fr:0};
/* tir sur une mine : appelé par shoot() avec le rayon de la balle ; renvoie la distance si touchée */
function mineRayHit(e,ox,oy,oz,dx,dy,dz,maxT){
 let best=null,bt=maxT;
 for(const m of MINES){
  if(m.owner===e)continue;
  const cx=m.x-ox,cy=m.y+.08-oy,cz=m.z-oz,t=cx*dx+cy*dy+cz*dz;if(t<0||t>bt)continue;
  const px=cx-dx*t,py=cy-dy*t,pz=cz-dz*t;if(px*px+py*py+pz*pz>.3*.3)continue;
  best=m;bt=t;
 }
 if(best){removeMine(best,false);if(e.isPlayer){uiToast('Mine détruite');sfx('hit');}return bt;}
 return -1;
}
/* coup de couteau / explosion : casse les mines proches */
function minesNear(x,z,r,by){for(const m of MINES.slice())if(Math.hypot(m.x-x,m.z-z)<r&&(!by||isFoeMine(m,by)))removeMine(m,false);}
function agentBot(b,dt){
 // pose de mines : quand le bot ne se bat pas
 b.bot_t-=dt;
 if(b.bot_t<=0){b.bot_t=rand(1.5,3.5);
  if(!b.target&&b.nade.mn>0&&Math.random()<(G.mode==='bomb'?.18:.12)&&(G.mode!=='bomb'||G.state==='live'))placeMine(b);
 }
 // repère une mine ennemie à portée, puis tire dessus
 if(b.target&&b.target.alive){b.mineSeen=null;return;}
 if(!b.mineSeen){
  for(const m of MINES){
   if(m.armT>0||!isFoeMine(m,b))continue;
   const d=Math.hypot(m.x-b.x,m.z-b.z);if(d>MINE_SEE*(.6+.4*b.diff.hear))continue;
   const fa=Math.abs(angDiff(b.yaw,Math.atan2(-(m.x-b.x),-(m.z-b.z))));if(fa>1.1)continue;
   if(Math.random()>.04+b.diff.hear*.06)continue;
   const ey=b.y+1.5,dx=m.x-b.x,dy=m.y+.1-ey,dz=m.z-b.z,L=Math.hypot(dx,dy,dz);
   if(rayWall(b.x,ey,b.z,dx/L,dy/L,dz/L,L)<L-.3)continue;
   b.mineSeen=m;b.mineT=b.diff.react*2+.6;break;
  }
 }else{
  const m=b.mineSeen;if(!MINES.includes(m)){b.mineSeen=null;return;}
  b.faceYaw=Math.atan2(-(m.x-b.x),-(m.z-b.z));b.faceT=.5;
  b.mineT-=dt;
  if(b.mineT<=0){
   const ey=b.y+1.5,wi=curWi(b),w=W[wi.k];
   if(!w.melee&&wi.mag>0){wi.mag--;sfx(w.cat,b.x,b.z,1);addTracer(b.x,ey-.2,b.z,m.x,m.y+.1,m.z);}
   removeMine(m,false);b.mineSeen=null;
  }
 }
}
function agentUpdate(dt){
 if(!ents.length)return;
 const fr=G.state==='freeze'&&G.mode==='bomb';
 if(G.running&&!fr)for(const e of ents)if(!e.isPlayer&&e.alive&&!e.zombie&&!e.dummy)agentBot(e,dt);
 for(let i=MINES.length-1;i>=0;i--){
  const m=MINES[i];m.armT-=dt;m.l.material.color.set(m.armT>0?0x666666:(Math.floor(G.t*2.5)%2?0xff2a2a:0x551010));
  if(fr&&G.t<1){scene.remove(m.m);MINES.splice(i,1);continue;}
  if(!ents.includes(m.owner)){scene.remove(m.m);MINES.splice(i,1);continue;}
  if(m.armT>0)continue;
  for(const v of ents){
   if(!v.alive||!isFoeMine(m,v)||v.dummy)continue;
   if(Math.hypot(v.x-m.x,v.z-m.z)<1.5&&Math.abs(v.y-m.y)<1.6){removeMine(m,true);break;}
  }
 }
 for(let i=AFX.length-1;i>=0;i--){const f=AFX[i];f.t+=dt;if(f.t>=f.life){scene.remove(f.m);AFX.splice(i,1);}}
 adaptBots(dt);mineHud();
}
function agentCleanup(){for(const m of MINES)scene.remove(m.m);MINES.length=0;for(const f of AFX)scene.remove(f.m);AFX.length=0;}
let mhEl=null;
function mineHud(){
 const n=$('nades');if(!n||!P)return;
 if(!mhEl){mhEl=document.createElement('span');mhEl.id='mineHud';mhEl.style.cssText='margin-left:6px;font-weight:800;color:#ffb3b3';n.parentNode.insertBefore(mhEl,n.nextSibling);}
 mhEl.textContent=P.nade&&P.nade.mn>0?'◉ ×'+P.nade.mn+' ['+String(cfg.binds.mine||'').replace('Key','')+']':'';
}
/* options du menu Jouer : comportement des bots + partie classée */
function buildAgentRow(){
 let g=$('gAgent');
 if(!g){const side=$('gSide');g=document.createElement('div');g.className='grp';g.id='gAgent';g.innerHTML='<label>Comportement des bots</label><div class="chips" id="cAdapt"></div><small>Adaptatifs : les bots deviennent plus forts si tu domines, plus faibles si tu perds.</small><label style="margin-top:10px">Partie classée</label><div class="chips" id="cRanked"></div>';side.parentNode.insertBefore(g,side);}
 chipsRow("cAdapt",[["Fixes",0],["Adaptatifs",1]],()=>cfg.adapt,v=>cfg.adapt=v);
 chipsRow("cRanked",[["Non classée",0],["Classée",1]],()=>cfg.ranked,v=>cfg.ranked=v);
}
/* ---------- difficulté adaptative : les bots s'ajustent à ton niveau ---------- */
cfg.adapt=cfg.adapt||0;
let adaptT=0;
function adaptBots(dt){
 if(!cfg.adapt||!P||G.state==='over')return;
 adaptT-=dt;if(adaptT>0)return;adaptT=4;
 const lo=DIFFS[Math.max(0,cfg.diff-1)],hi=DIFFS[Math.min(DIFFS.length-1,cfg.diff+1)],base=DIFFS[cfg.diff];
 const k=clamp(Math.log2((P.kills+1)/(P.deaths+1)),-1,1);   // >0 : le joueur domine
 const tgt=k>=0?hi:lo,w=Math.abs(k);
 const mix={};for(const f in base)mix[f]=typeof base[f]==='number'?base[f]+(tgt[f]-base[f])*w:base[f];
 for(const e of ents)if(!e.isPlayer&&e.diff&&!e.zombie&&!e.dummy)e.diff=mix;
}
