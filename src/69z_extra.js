/* =====================================================================
   ZOMBIES (suite) : portes / débris à acheter, joueurs à terre et
   réanimation, manches spéciales (rôdeurs), boss, easter egg
   ===================================================================== */
const ZD={doors:[],reach:null,frags:[],fragGot:0,egg:false,hud:null};
/* ---------- zones accessibles depuis le départ ---------- */
function zReach(extraBlock){
 const sp=MAP.spawnCT[0],s0=nearestFree(sp[0],sp[1]),start=s0[1]*N+s0[0];
 const R=new Uint8Array(NC),q=[start];R[start]=1;
 while(q.length){const c=q.pop(),cx=c%N,cz=(c/N)|0;
  for(const [dx,dz] of [[1,0],[-1,0],[0,1],[0,-1]]){const nx=cx+dx,nz=cz+dz;if(nx<0||nz<0||nx>=N||nz>=N)continue;const ni=nz*N+nx;
   if(R[ni]||(extraBlock&&extraBlock.has(ni))||edgeCost(c,ni,false)<0)continue;R[ni]=1;q.push(ni);}}
 return R;
}
const zCount=R=>{let n=0;for(let i=0;i<NC;i++)n+=R[i];return n;};
/* ---------- portes : passages de 1 à 3 cases qui coupent la carte ---------- */
function zDoorCandidates(){
 const out=[],seen=new Set(),wall=i=>!walkableCell(i);
 for(let cz=1;cz<N-1;cz++)for(let cx=1;cx<N-1;cx++){
  const i=cz*N+cx;if(!walkableCell(i)||G_RAMP[i]||G_H[i]>0)continue;
  for(const horiz of [true,false]){
   // la porte s'étend perpendiculairement au passage
   const dx=horiz?1:0,dz=horiz?0:1;let a=0,b=0;
   while(a<4&&walkableCell((cz-dz*(a+1))*N+cx-dx*(a+1)))a++;
   while(b<4&&walkableCell((cz+dz*(b+1))*N+cx+dx*(b+1)))b++;
   const len=a+b+1;if(len>3)continue;
   const cells=[];for(let k=-a;k<=b;k++)cells.push((cz+dz*k)*N+cx+dx*k);
   const key=cells.join(',');if(seen.has(key))continue;seen.add(key);
   // il faut des murs aux deux bouts et un passage libre devant / derrière
   const e1=(cz-dz*(a+1))*N+cx-dx*(a+1),e2=(cz+dz*(b+1))*N+cx+dx*(b+1);
   if(!wall(e1)||!wall(e2))continue;
   const f=(cz+dx)*N+cx+dz,bk=(cz-dx)*N+cx-dz;if(!walkableCell(f)||!walkableCell(bk))continue;
   out.push({cells,horiz,cx,cz});
  }
 }
 return out;
}
function zSetupDoors(){
 zClearDoors();
 if(G.variant!=='zombies'||MAP.id==='range')return;
 // portes définies par la carte (MAP.zdoors) : passages à dégager contre des points
 if(!MAP.zdoors)return;
 const chosen=MAP.zdoors.map(dd=>{const xs=dd.cells.map(c=>c[0]),zs=dd.cells.map(c=>c[1]);
  return {cells:dd.cells.map(c=>c[1]*N+c[0]),price:dd.price,horiz:(Math.max(...xs)-Math.min(...xs))>=(Math.max(...zs)-Math.min(...zs)),cx:xs.reduce((a,b)=>a+b)/xs.length,cz:zs.reduce((a,b)=>a+b)/zs.length};});
 const prices=[750,1000,1250,1500];
 chosen.forEach((c,k)=>{
  const d={cells:c.cells,save:c.cells.map(i=>[G_TYPE[i],G_H[i],G_CEIL[i]]),price:c.price||prices[k]||1500,mesh:null,x:0,z:0,open:false,idx:k};
  for(const i of c.cells){G_TYPE[i]=TY.CRATE;G_H[i]=2.4;}
  let sx=0,sz=0;for(const i of c.cells){sx+=cc(i%N);sz+=cc((i/N)|0);}d.x=sx/c.cells.length;d.z=sz/c.cells.length;
  d.mesh=zDebrisMesh(c);scene.add(d.mesh);
  ZD.doors.push(d);
  ZB.inter.push({x:d.x,z:d.z,r:2.6,kind:'door',door:d});
 });
 ZD.reach=zReach();
}
function zDebrisMesh(c){
 const g=new THREE.Group(),wood=new THREE.MeshStandardMaterial({color:0x6b4a2b,roughness:.9}),dark=new THREE.MeshStandardMaterial({color:0x3b2a1a,roughness:1}),metal=new THREE.MeshStandardMaterial({color:0x555b62,metalness:.7,roughness:.5});
 const n=c.cells.length,W2=n*S;
 for(let k=0;k<6;k++){const p=new THREE.Mesh(new THREE.BoxGeometry(W2*1.05,.22,.08),k%2?wood:dark);p.position.set(0,.3+k*.36,(k%2?.12:-.12));p.rotation.z=rand(-.18,.18);g.add(p);}
 for(let k=0;k<n*2;k++){const cr=new THREE.Mesh(new THREE.BoxGeometry(.8,.8,.8),k%3?wood:metal);cr.position.set(rand(-W2/2+.4,W2/2-.4),.4+(k%2)*.8,rand(-.6,.6));cr.rotation.y=rand(0,3);g.add(cr);}
 const sign=new THREE.Mesh(new THREE.PlaneGeometry(1.2,.4),new THREE.MeshBasicMaterial({map:cvTex(256,86,(x,w,h)=>{x.fillStyle='#ffd23a';x.fillRect(0,0,w,h);x.fillStyle='#111';for(let i=-2;i<10;i++){x.beginPath();x.moveTo(i*32,h);x.lineTo(i*32+20,0);x.lineTo(i*32+36,0);x.lineTo(i*32+16,h);x.fill();}}),toneMapped:false}));
 sign.position.set(0,2.2,.2);g.add(sign);
 let sx=0,sz=0;for(const i of c.cells){sx+=cc(i%N);sz+=cc((i/N)|0);}
 g.position.set(sx/n,groundH(sx/n,sz/n),sz/n);g.rotation.y=c.horiz?0:Math.PI/2;
 g.traverse(o=>{if(o.isMesh)o.castShadow=true;});
 return g;
}
function zOpenDoor(d){
 if(d.open)return;d.open=true;
 d.cells.forEach((i,k)=>{G_TYPE[i]=d.save[k][0];G_H[i]=d.save[k][1];G_CEIL[i]=d.save[k][2];});
 if(d.mesh){const m=d.mesh;let t=0;const f=()=>{t+=.05;m.position.y-=.12;m.rotation.x+=.02;if(t<1.2)requestAnimationFrame(f);else scene.remove(m);};f();}
 ZB.inter=ZB.inter.filter(it=>it.door!==d);
 ZD.reach=zReach();sfx('boom',d.x,d.z,.5);fxDust(d.x,1,d.z,20,.5);
 uiBanner('ZONE OUVERTE','',1400,'#ffd23a');
}
function zClearDoors(){
 for(const d of ZD.doors){if(!d.open)d.cells.forEach((i,k)=>{G_TYPE[i]=d.save[k][0];G_H[i]=d.save[k][1];G_CEIL[i]=d.save[k][2];});if(d.mesh)scene.remove(d.mesh);}
 ZD.doors=[];ZD.reach=null;
}
/* ---------- joueurs à terre / réanimation ---------- */
function zDown(v){
 // appelé quand un humain tombe à 0 PV en zombies (après Second Souffle)
 const others=ents.filter(e=>!e.zombie&&e!==v&&e.alive&&!e.downed);
 if(!others.length)return false;
 v.downed=true;v.hp=1;v.downT=30;v.revP=0;v.perks={};v.seated=1;v.target=null;
 if(v.wp.s)v.cur='s';
 if(v.isPlayer){uiBanner('À TERRE !','Un allié doit te réanimer — tu peux encore tirer',2400,'#ff4655');sfx('dmg');zPerkHud();}
 else radio(v,'Je suis à terre ! Aidez-moi !');
 return true;
}
function zRevive(v,by){
 v.downed=false;v.hp=60;v.seated=0;v.invuln=1.5;v.revP=0;
 if(v.isPlayer)uiBanner('RÉANIMÉ','',1400,'#7dff9f');
 if(by&&by.isPlayer){zPts(by,100);uiToast('Allié réanimé (+100)');}
 sfx('pickup',v.x,v.z);
}
function zDownUpdate(dt){
 const humans=ents.filter(e=>!e.zombie);
 for(const v of humans){
  if(!v.downed||!v.alive)continue;
  v.invuln=Math.max(v.invuln,.3);v.speed=v.isPlayer?v.speed:0;
  v.downT-=dt;
  // un bot vient réanimer
  let best=null,bd=1e9;for(const b of humans){if(b===v||b.isPlayer||!b.alive||b.downed)continue;const d=Math.hypot(b.x-v.x,b.z-v.z);if(d<bd){bd=d;best=b;}}
  if(best){
   const danger=ents.some(z=>z.zombie&&z.alive&&Math.hypot(z.x-best.x,z.z-best.z)<3.5);
   if(bd<1.6&&!danger){v.revP+=dt;best.vx=best.vz=0;}
   else if(!danger||bd<12)botGo(best,dt,v.x,v.z,RUN*.95);
  }
  if(v.revP>=(v.perks&&v.perks.revive?1.5:3)){zRevive(v,best);continue;}
  if(v.downT<=0){v.downed=false;v.seated=0;v.invuln=0;killEnt(v,v.lastAttacker||v,{n:'Saignement',kill:0,hs:1},false);}
 }
 // plus personne debout : fin de partie
 const up=humans.filter(e=>e.alive&&!e.downed);
 if(!up.length)for(const v of humans)if(v.alive&&v.downed){v.downed=false;v.seated=0;v.invuln=0;killEnt(v,v.lastAttacker||v,{n:'Saignement',kill:0,hs:1},false);}
 // HUD « à terre »
 if(!ZD.hud){ZD.hud=document.createElement('div');ZD.hud.style.cssText='position:absolute;left:0;right:0;top:30%;text-align:center;font:900 2rem Bahnschrift,Arial;color:#ff4655;text-shadow:0 0 18px #000;letter-spacing:6px;display:none';$('hud').appendChild(ZD.hud);}
 ZD.hud.style.display=P&&P.downed?'block':'none';
 if(P&&P.downed)ZD.hud.innerHTML='À TERRE<small style="display:block;font-size:1rem;letter-spacing:3px;color:#fff">'+Math.ceil(P.downT)+' s — réanimation '+Math.round(P.revP/3*100)+' %</small>';
 $('lowhp').style.display=P&&P.downed?'block':($('lowhp').style.display);
}
/* ---------- manches spéciales et boss ---------- */
function zRoundType(){
 Z.special=Z.wave%5===0;Z.boss=Z.wave%10===0?1:0;
 if(Z.special){Z.queue=Math.round(Z.queue*1.3);uiBanner('MANCHE DES RÔDEURS','Ils rampent… et ils sont rapides',2600,'#b06bff');}
 if(Z.boss)setTimeout(()=>uiBanner('LA BRUTE ARRIVE','Un boss rejoint la manche',2600,'#ff3030'),2800);
}
function zSpecialType(def){
 if(Z.boss>0&&(Math.random()<.12||Z.queue<6)){Z.boss--;return 'boss';}
 if(Z.special&&Math.random()<.75)return 'crawler';
 return def;
}
function zStyleZombie(z){
 if(z.ztype==='crawler'){z.hp=Math.round(z.hp*.55);z.zspeed=4.6;z.zdmg=Math.round(z.zdmg*.7);if(z.rig&&!z.rig.real)z.rig.root.scale.setScalar(.95);}
 if(z.ztype==='boss'){z.hp=Math.round(1500+Z.wave*400);z.zspeed=2.9;z.zdmg=45;
  if(z.rig&&z.rig.real)z.rig.root.scale.setScalar(1.15);   // la Brute est déjà un grand monstre
  else if(z.rig){z.rig.root.scale.setScalar(1.8);z.rig.root.traverse(o=>{if(o.isMesh){o.material=o.material.clone();o.material.color.setHex(0xff9a8a);o.material.emissive=new THREE.Color(0x550000);o.material.emissiveIntensity=.6;}});}
  sfx('growl',z.x,z.z,1.4);}
}
/* ---------- easter egg : 3 fragments de l'Orbe ---------- */
function zSetupEgg(){
 for(const f of ZD.frags)scene.remove(f.m);ZD.frags=[];ZD.fragGot=0;ZD.egg=false;
 if(G.variant!=='zombies')return;
 const sp=MAP.spawnCT[0],pts=(MAP.roam||[]).concat(MAP.spawnDM||[]).slice().sort((a,b)=>Math.hypot(b[0]-sp[0],b[1]-sp[1])-Math.hypot(a[0]-sp[0],a[1]-sp[1]));
 const chosen=[];for(const p of pts){if(chosen.length>=3)break;if(chosen.every(c=>Math.hypot(c[0]-p[0],c[1]-p[1])>8))chosen.push(p);}
 for(const c of chosen){
  const f=nearestFree(c[0],c[1]),x=cc(f[0])+rand(-.6,.6),z=cc(f[1])+rand(-.6,.6),y=groundH(x,z);
  const m=new THREE.Group(),core=new THREE.Mesh(new THREE.OctahedronGeometry(.16,0),new THREE.MeshStandardMaterial({color:0xc77dff,emissive:0x9b3dff,emissiveIntensity:1.6,roughness:.2,toneMapped:false}));m.add(core);
  const gl=new THREE.Sprite(new THREE.SpriteMaterial({map:GLOW.white,color:0xb46bff,blending:THREE.AdditiveBlending,transparent:true,depthWrite:false,opacity:.7,toneMapped:false}));gl.scale.set(1.1,1.1,1);m.add(gl);
  m.position.set(x,y+.45,z);scene.add(m);ZD.frags.push({m,x,z,y,ph:rand(0,6)});
 }
}
function zEggUpdate(dt){
 for(let i=ZD.frags.length-1;i>=0;i--){const f=ZD.frags[i];f.m.rotation.y+=dt*2;f.m.position.y=f.y+.45+Math.sin(G.t*2+f.ph)*.08;
  if(P&&P.alive&&!P.downed&&Math.hypot(P.x-f.x,P.z-f.z)<1.2){scene.remove(f.m);ZD.frags.splice(i,1);ZD.fragGot++;sfx('powerup');
   if(ZD.fragGot<3)uiToast('Fragment de l\'Orbe '+ZD.fragGot+' / 3');
   else{ZD.egg=true;uiBanner('EASTER EGG RÉUSSI !','L\'Orbe est reconstituée — arme prodige améliorée + 5000 pts',3600,'#c77dff');sfx('pap');
    zGive(P,'raygun');const wi=P.wp.p;if(wi){wi.pap=true;wi.mag=magMax(P,'raygun');wi.res=W.raygun.res*2;}zPts(P,5000);
    if(typeof PROF!=='undefined'){PROF.ach=PROF.ach||{};if(!PROF.ach.egg){PROF.ach.egg=Date.now();PROF.coins+=500;saveProf();uiToast('Succès : Chasseur de secrets (+500 🪙)');}}
    if(typeof confetti==='function')confetti(['#c77dff','#9b3dff','#ffffff'],200,.5,.4);}}}
}
if(typeof ACH!=='undefined')ACH.push({id:'egg',n:'Chasseur de secrets',d:'Termine l\'easter egg du mode Zombies',c:500,f:()=>false});
/* ---------- boucle ---------- */
function zExtraUpdate(dt){
 if(G.variant!=='zombies'||!G.running)return;
 zDownUpdate(dt);zEggUpdate(dt);
}
/* point d'apparition des zombies : case accessible la plus éloignée des humains (ils sortent du sol) */
function zReachSpot(humans){
 if(!ZD.reach)return null;
 if(!ZD.cells||ZD.cellsFor!==ZD.reach){ZD.cells=[];for(let i=0;i<NC;i++)if(ZD.reach[i]&&walkableCell(i)&&!G_RAMP[i])ZD.cells.push(i);ZD.cellsFor=ZD.reach;}
 let best=null,bd=-1;
 for(let k=0;k<40&&ZD.cells.length;k++){const i=pick(ZD.cells),x=cc(i%N),z=cc((i/N)|0);let md=1e9;for(const h of humans)md=Math.min(md,Math.hypot(h.x-x,h.z-z));if(md>bd){bd=md;best=[i%N,(i/N)|0];}}
 return best;
}
