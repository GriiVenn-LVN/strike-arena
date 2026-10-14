/* =====================================================================
   ZOMBIES — façon « Black Ops »
   - points : +10 par touche, +60 élimination, +100 tête, +130 couteau
   - armes murales (contours à la craie), boîte mystère (950), Forge
     Arcane (Pack-a-Punch, 5000), atouts (Mastodonte, Turbo Cola,
     Double Détente, Second Souffle, Pas de Course)
   - armes prodiges : Rayon X, Canon Tonnerre, Souffle Givré
     (surpuissantes, très peu de munitions)
   - bonus lâchés par les zombies : Munitions max, Mort instantanée,
     Points doubles, Bombe, Vente de feu
   ===================================================================== */

/* ---------- armes prodiges ---------- */
Object.assign(W,{
 raygun:{n:'Rayon X',slot:0,cat:'wonder',wonder:'ray',price:0,dmg:300,hs:1,rpm:180,auto:0,mag:8,res:24,rel:2.6,spr:.3,mv:2,rec:1.2,spd:1,kill:10,len:.32,ap:1,fo:999,fr:0,col:0xc0392b},
 thunder:{n:'Canon Tonnerre',slot:0,cat:'wonder',wonder:'thunder',price:0,dmg:2000,hs:1,rpm:40,auto:0,mag:2,res:6,rel:4,spr:0,mv:2,rec:6,spd:.92,kill:10,len:.6,ap:1,fo:999,fr:0,col:0x8a6a3a},
 winter:{n:'Souffle Givré',slot:0,cat:'wonder',wonder:'ice',price:0,dmg:140,hs:1,rpm:120,auto:1,mag:6,res:18,rel:3,spr:0,mv:2,rec:2,spd:.95,kill:10,len:.5,ap:1,fo:999,fr:0,col:0x6ed6ff}
});
function buildWonder(k,M){
 const g=new THREE.Group(),glow=c=>new THREE.MeshStandardMaterial({color:c,emissive:c,emissiveIntensity:1.4,roughness:.3,toneMapped:false});
 const metal=c=>new THREE.MeshStandardMaterial({color:c,metalness:.8,roughness:.32});
 if(k==='raygun'){            // pistolet rétro-futuriste : corps bombé rouge, anneaux verts
  const red=metal(0xb3261e),chrome=metal(0xd8dde4),grn=glow(0x4dff6a);
  const body=new THREE.Mesh(new THREE.SphereGeometry(.06,20,14),red);body.scale.set(.75,.9,1.6);body.position.set(0,.02,-.06);g.add(body);
  g.add(cz(.016,.03,.2,chrome,0,.03,-.22,16));
  for(let i=0;i<3;i++){const r=new THREE.Mesh(new THREE.TorusGeometry(.03-i*.003,.007,8,20),grn);r.position.set(0,.03,-.16-i*.05);g.add(r);}
  g.add(cz(.012,.012,.05,grn,0,.03,-.33,12));
  const fin=rb(.006,.05,.09,red,0,.085,-.08,.003);g.add(fin);
  g.add(polyZY([[.0,-.02],[.04,-.02],[.06,-.13],[.02,-.14]],.03,metal(0x2b2b2b),0,.004));
  const tank=new THREE.Mesh(new THREE.CylinderGeometry(.018,.018,.07,12),glow(0x4dff6a));tank.rotation.x=Math.PI/2;tank.position.set(.045,.03,-.03);g.add(tank);
  return finishGun(g,{len:.36,muzzle:-.36,right:V3(0,-.075,-.0),left:V3(0,-.05,-.12),twoHand:false,sight:.09,eject:V3(0,0,0)});
 }
 if(k==='thunder'){           // canon à air : tambour cuivré, turbine à l'avant
  const brass=metal(0xb08a4a),dark=metal(0x2e2a26),blue=glow(0x9fd8ff);
  g.add(cz(.07,.07,.32,brass,0,0,-.18,22));
  for(let i=0;i<5;i++){const r=new THREE.Mesh(new THREE.TorusGeometry(.072,.008,8,24),dark);r.position.set(0,0,-.05-i*.065);g.add(r);}
  const bell=new THREE.Mesh(new THREE.CylinderGeometry(.1,.07,.12,22,1,true),new THREE.MeshStandardMaterial({color:0xb08a4a,metalness:.8,roughness:.3,side:THREE.DoubleSide}));bell.rotation.x=Math.PI/2;bell.position.set(0,0,-.4);g.add(bell);
  for(let i=0;i<8;i++){const b=rb(.006,.07,.03,dark,0,0,-.4,.002);b.rotation.z=i*Math.PI/8;g.add(b);}
  const core=new THREE.Mesh(new THREE.SphereGeometry(.03,12,10),blue);core.position.set(0,0,-.37);g.add(core);
  g.add(rb(.05,.04,.22,dark,0,.08,-.12,.01),cz(.02,.02,.16,blue,.07,.02,-.16,10));
  g.add(polyZY([[.0,-.06],[.05,-.06],[.07,-.17],[.02,-.18]],.035,dark,0,.004),rb(.05,.09,.16,brass,0,-.02,.1,.01));
  return finishGun(g,{len:.6,muzzle:-.46,right:V3(0,-.11,.01),left:V3(0,-.075,-.25),sight:.13,eject:V3(0,0,0)});
 }
 // souffle givré : canon de cristal bleu, pointes de glace
 const steel=metal(0x8fa3b8),ice=new THREE.MeshStandardMaterial({color:0xa8ecff,emissive:0x3fb8ff,emissiveIntensity:.7,roughness:.08,metalness:.1,transparent:true,opacity:.85});
 g.add(rb(.05,.07,.26,steel,0,0,-.08,.012));
 const crys=new THREE.Mesh(new THREE.CylinderGeometry(.04,.025,.3,6),ice);crys.rotation.x=Math.PI/2;crys.position.set(0,.01,-.36);g.add(crys);
 for(let i=0;i<6;i++){const c=new THREE.Mesh(new THREE.ConeGeometry(.012,.07,5),ice);const a=i*Math.PI/3;c.position.set(Math.cos(a)*.045,.01+Math.sin(a)*.045,-.3-i%2*.08);c.rotation.set(Math.PI/2,0,a);g.add(c);}
 g.add(cz(.03,.03,.08,steel,0,.01,-.22,14),rb(.03,.03,.16,steel,0,.065,-.1,.008));
 g.add(polyZY([[.0,-.035],[.04,-.035],[.055,-.15],[.015,-.16]],.032,metal(0x2b3138),0,.004),rb(.04,.08,.13,steel,0,-.01,.11,.01));
 return finishGun(g,{len:.55,muzzle:-.5,right:V3(0,-.085,.0),left:V3(0,-.03,-.24),sight:.085,eject:V3(0,0,0)});
}
BUILDERS.wonder=buildWonder;

/* ---------- état du mode ---------- */
const ZB={spots:[],box:null,boxIdx:0,boxUses:0,wall:[],perks:[],pap:null,inter:[],drops:[],useLatch:false,insta:0,dbl:0,fire:0,objs:[],hudEl:null,dropsWave:0};
const PERKS={
 jugg:{n:'Mastodonte',price:2500,c:'#e0383e',ic:'✚',d:'Encaisse 2× plus de coups'},
 speed:{n:'Turbo Cola',price:3000,c:'#33d17a',ic:'⟳',d:'Rechargement 2× plus rapide'},
 dtap:{n:'Double Détente',price:2000,c:'#f5c542',ic:'❚❚',d:'+33 % cadence, +50 % dégâts'},
 revive:{n:'Second Souffle',price:1500,c:'#4aa3ff',ic:'♥',d:'Te relève une fois quand tu tombes'},
 stamin:{n:'Pas de Course',price:2000,c:'#ff9a3a',ic:'»',d:'Course 18 % plus rapide'}
};
const ZSTART_RES=104;          // réserve du pistolet de départ (8 chargeurs de P250 au lieu de 2)
const WALLBUYS=[['mac10',500],['mp9',1000],['ump',1200],['nova',900],['famas',1500],['galil',1400],['m4',2000],['xm',1800],['deagle',800]];
const BOXPOOL=['mac10','mp9','ump','p90','nova','xm','sawedoff','galil','famas','ak','m4','sg553','aug','ssg','awp','scar','negev','m249','deagle','fiveseven','raygun','raygun','thunder','winter','winter'];
const PAP_PRICE=5000,BOX_PRICE=950;
const zOn=()=>G.variant==='zombies';
const spdMul=e=>(e.perks&&e.perks.stamin?1.18:1);
const papOf=(e,k)=>{if(!e||!e.wp)return false;const wi=e.wp[slotOf(k)];return !!(wi&&wi.k===k&&wi.pap);};

/* ---------- points ---------- */
function zPts(e,n,x,z){
 if(!e||e.zombie)return;n=Math.round(n*(ZB.dbl>G.t?2:1));e.pts=(e.pts||0)+n;
 if(e.isPlayer){const el=zHud();const s=document.createElement('span');s.className='zgain';s.textContent='+'+n;el.pts.appendChild(s);setTimeout(()=>s.remove(),900);}
}
function zSpend(e,n){if((e.pts||0)<n){zTell(e,'Pas assez de points ('+n+')','deny');return false;}e.pts-=n;return true;}

/* ---------- crochets appelés par le jeu ---------- */
function zHurtHook(v,att,raw,w){
 if(v.zombie){
  if(att&&!att.zombie){
   const wi=att.wp&&att.wp[att.cur];if(wi&&wi.pap)raw*=w&&w.wonder?1.5:2;
   if(att.perks&&att.perks.dtap&&w&&!w.melee&&!w.wonder)raw*=1.5;
   if(ZB.insta>G.t)raw=v.hp+999;
   zPts(att,10);
  }
 }else if(att&&att.zombie&&v.perks&&v.perks.jugg)raw*=.45;
 return raw;
}
function zSave(v){            // à terre (alliés présents) ou Second Souffle (seul)
 if(v.zombie)return false;
 if(v.downed)return true;
 if(zDown(v))return true;
 if(!v.perks||!v.perks.revive)return false;
 v.perks={};v.hp=100;v.invuln=2.5;if(v.isPlayer){uiBanner('SECOND SOUFFLE','Tu te relèves… atouts perdus',2200,'#4aa3ff');sfx('perk');}
 for(const z of ents)if(z.zombie&&z.alive&&Math.hypot(z.x-v.x,z.z-v.z)<4){const d=Math.hypot(z.x-v.x,z.z-v.z)||1;z.x+=(z.x-v.x)/d*2;z.z+=(z.z-v.z)/d*2;}
 return true;
}
function zKillHook(att,v,w,hs){
 if(v.zombie){
  if(att&&!att.zombie)zPts(att,w&&w.melee?120:hs?90:50,v.x,v.z);
  if(v.ztype==='boss'){if(att&&!att.zombie)zPts(att,1000);zDrop(v.x,v.z);uiBanner('BRUTE ÉLIMINÉE','+1000',2000,'#ffd23a');}
  if(Math.random()<.035&&ZB.dropsWave<4){ZB.dropsWave++;zDrop(v.x,v.z);}
 }else{v.perks={};zPerkHud();}
}

/* ---------- placement des éléments sur la carte ---------- */
function zFindSpots(){
 const out=[],seen=new Set();
 const free=(cx,cz)=>cx>0&&cz>0&&cx<N-1&&cz<N-1&&G_TYPE[cz*N+cx]===TY.OPEN&&G_H[cz*N+cx]===0&&!G_RAMP[cz*N+cx];
 const wallAt=(cx,cz)=>cx<0||cz<0||cx>=N||cz>=N||G_H[cz*N+cx]>=2.4;
 for(const r of (MAP.roam||[]).concat(MAP.spawnDM||[])){
  for(let dz=-2;dz<=2;dz++)for(let dx=-2;dx<=2;dx++){
   const cx=r[0]+dx,cz=r[1]+dz,key=cx+','+cz;if(seen.has(key)||!free(cx,cz))continue;seen.add(key);
   for(const [ox,oz] of [[1,0],[-1,0],[0,1],[0,-1]]){
    if(!wallAt(cx+ox,cz+oz)||!free(cx-ox,cz-oz))continue;
    const x=cc(cx),z=cc(cz);
    if(!losClear(cc(r[0]),1.2,cc(r[1]),x,1.2,z,true))continue;
    out.push({cx,cz,x,z,dx:ox,dz:oz});break;
   }
  }
 }
 // éloigner du point d'apparition des zombies n'est pas nécessaire : ils viennent de partout
 return out;
}
function zPickSpread(list,n,avoid){
 const res=[];const pool=list.slice();
 while(res.length<n&&pool.length){
  let best=-1,bd=-1;
  for(let i=0;i<pool.length;i++){let md=1e9;for(const p of res.concat(avoid))md=Math.min(md,Math.hypot(p.x-pool[i].x,p.z-pool[i].z));if(!res.length&&!avoid.length)md=Math.random();if(md>bd){bd=md;best=i;}}
  res.push(pool.splice(best,1)[0]);
 }
 return res;
}
/* ---------- textures ---------- */
function cvTex(w,h,draw){const c=document.createElement('canvas');c.width=w;c.height=h;draw(c.getContext('2d'),w,h);const t=new THREE.CanvasTexture(c);t.encoding=THREE.sRGBEncoding;return t;}
function chalkTex(k,price){
 const c=document.createElement('canvas');c.width=512;c.height=256;const t=new THREE.CanvasTexture(c);t.encoding=THREE.sRGBEncoding;
 const img=new Image();img.onload=()=>{const x=c.getContext('2d');x.clearRect(0,0,512,256);
  x.filter='brightness(0) invert(1)';x.globalAlpha=.85;x.drawImage(img,26,30,460,187);x.filter='none';
  // effet craie : on gratte le dessin
  x.globalCompositeOperation='destination-out';for(let i=0;i<2600;i++){x.globalAlpha=Math.random()*.5;x.fillRect(Math.random()*512,Math.random()*256,2,1);}
  x.globalCompositeOperation='source-over';x.globalAlpha=1;x.fillStyle='#f4f4f0';x.font='bold 34px Bahnschrift,Arial';x.textAlign='center';x.fillText(W[k].n.toUpperCase()+' — '+price,256,244);t.needsUpdate=true;};
 img.src=weaponIcon(k,0);return t;
}
function perkTex(p){return cvTex(256,512,(x,w,h)=>{
 const gr=x.createLinearGradient(0,0,0,h);gr.addColorStop(0,p.c);gr.addColorStop(1,'#14100c');x.fillStyle=gr;x.fillRect(0,0,w,h);
 x.fillStyle='rgba(0,0,0,.35)';x.fillRect(14,14,w-28,h-28);x.strokeStyle='#fff8';x.lineWidth=4;x.strokeRect(14,14,w-28,h-28);
 x.fillStyle='#fff';x.textAlign='center';x.font='bold 120px Arial';x.fillText(p.ic,w/2,200);
 x.font='bold 30px Bahnschrift,Arial';x.fillText(p.n.toUpperCase(),w/2,290);x.font='22px Arial';x.fillStyle='#ffe9b0';x.fillText(p.price+' points',w/2,330);
 x.fillStyle='#0008';x.fillRect(60,380,136,70);x.fillStyle=p.c;x.fillRect(70,390,116,50);
});}
function boxTex(){return cvTex(256,128,(x,w,h)=>{x.fillStyle='#3a2a18';x.fillRect(0,0,w,h);for(let i=0;i<8;i++){x.fillStyle=i%2?'#4a3520':'#2f2214';x.fillRect(0,i*16,w,16);}
 x.fillStyle='#7fe0ff';x.font='bold 96px Georgia';x.textAlign='center';x.shadowColor='#7fe0ff';x.shadowBlur=18;x.fillText('?',w/2,h/2+34);});}
function papTex(){return cvTex(512,256,(x,w,h)=>{x.fillStyle='#1d1430';x.fillRect(0,0,w,h);x.strokeStyle='#b46bff';x.lineWidth=8;x.strokeRect(8,8,w-16,h-16);
 x.fillStyle='#e7c8ff';x.textAlign='center';x.font='bold 54px Bahnschrift,Arial';x.fillText('FORGE ARCANE',w/2,110);x.font='28px Arial';x.fillStyle='#ffd75e';x.fillText('Améliore ton arme — '+PAP_PRICE+' pts',w/2,170);});}
/* ---------- construction ---------- */
function zGlow(col,size){const s=new THREE.Sprite(new THREE.SpriteMaterial({map:GLOW.white,color:col,blending:THREE.AdditiveBlending,transparent:true,depthWrite:false,fog:false,toneMapped:false}));s.scale.set(size,size,1);return s;}
function zPlaceObj(spot,obj,depth){
 obj.position.set(spot.x+spot.dx*(S/2-depth/2-.02),0,spot.z+spot.dz*(S/2-depth/2-.02));
 obj.rotation.y=Math.atan2(-spot.dx,-spot.dz);scene.add(obj);ZB.objs.push(obj);return obj;
}
function zBuildBox(spot){
 const g=new THREE.Group(),wood=new THREE.MeshStandardMaterial({map:boxTex(),roughness:.8});
 const base=new THREE.Mesh(new THREE.BoxGeometry(1.5,.62,.75),[wood,wood,new THREE.MeshStandardMaterial({color:0x3a2a18,roughness:.8}),wood,wood,wood]);base.position.y=.31;g.add(base);
 const lid=new THREE.Group(),lm=new THREE.Mesh(new THREE.BoxGeometry(1.52,.12,.77),new THREE.MeshStandardMaterial({color:0x4a3520,roughness:.75}));lm.position.set(0,.06,.385);lid.add(lm);lid.position.set(0,.62,-.385);g.add(lid);
 for(const sx of [-.7,.7])for(const sz of [-.33,.33]){const c=rb(.08,.66,.08,new THREE.MeshStandardMaterial({color:0x8a7a5a,metalness:.7,roughness:.4}),sx,.33,sz,.01);g.add(c);}
 const beam=new THREE.Mesh(new THREE.CylinderGeometry(.35,.6,40,16,1,true),new THREE.MeshBasicMaterial({color:0x7fe0ff,transparent:true,opacity:.18,blending:THREE.AdditiveBlending,depthWrite:false,side:THREE.DoubleSide,toneMapped:false}));beam.position.y=20.6;g.add(beam);
 const glowS=zGlow(0x7fe0ff,2.4);if(glowS){glowS.position.y=.9;g.add(glowS);}
 g.userData={lid,beam};
 zPlaceObj(spot,g,.75);return g;
}
function zBuildPerk(spot,key){
 const p=PERKS[key],g=new THREE.Group();
 const front=new THREE.MeshStandardMaterial({map:perkTex(p),roughness:.45,emissive:0xffffff,emissiveMap:null,emissiveIntensity:0}),side=new THREE.MeshStandardMaterial({color:new THREE.Color(p.c).multiplyScalar(.55),roughness:.5,metalness:.4});
 const body=new THREE.Mesh(new THREE.BoxGeometry(.95,2.05,.7),[side,side,side,side,front,side]);body.position.y=1.025;g.add(body);
 const top=new THREE.Mesh(new THREE.BoxGeometry(1.02,.14,.76),new THREE.MeshStandardMaterial({color:0x222222,metalness:.7,roughness:.35}));top.position.y=2.1;g.add(top);
 const lamp=new THREE.Mesh(new THREE.BoxGeometry(.8,.06,.06),new THREE.MeshBasicMaterial({color:p.c,toneMapped:false}));lamp.position.set(0,1.95,.36);g.add(lamp);
 zPlaceObj(spot,g,.7);return g;
}
function zBuildPap(spot){
 const g=new THREE.Group(),purple=new THREE.MeshStandardMaterial({color:0x3a2560,metalness:.6,roughness:.35}),front=new THREE.MeshStandardMaterial({map:papTex(),roughness:.4});
 const body=new THREE.Mesh(new THREE.BoxGeometry(1.7,1.3,.85),[purple,purple,purple,purple,front,purple]);body.position.y=.65;g.add(body);
 const top=new THREE.Mesh(new THREE.CylinderGeometry(.5,.6,.5,6),new THREE.MeshStandardMaterial({color:0x6b3fb0,emissive:0x8a4dff,emissiveIntensity:.6,metalness:.5,roughness:.3}));top.position.y=1.55;g.add(top);
 const rollers=new THREE.Mesh(new THREE.CylinderGeometry(.12,.12,1.4,12),new THREE.MeshStandardMaterial({color:0x999999,metalness:.9,roughness:.25}));rollers.rotation.z=Math.PI/2;rollers.position.set(0,1.32,.3);g.add(rollers);
 const gl=zGlow(0xb46bff,3);if(gl){gl.position.y=1.9;g.add(gl);}
 g.userData={rollers};
 zPlaceObj(spot,g,.85);return g;
}
function zBuildWall(spot,k,price){
 const m=new THREE.Mesh(new THREE.PlaneGeometry(1.5,.75),new THREE.MeshBasicMaterial({map:chalkTex(k,price),transparent:true,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-2}));
 m.position.set(spot.x+spot.dx*(S/2-.03),1.45,spot.z+spot.dz*(S/2-.03));m.rotation.y=Math.atan2(-spot.dx,-spot.dz);scene.add(m);ZB.objs.push(m);return m;
}
function zSetup(){
 zCleanup();
 zSetupDoors();zSetupEgg();
 const spots=zFindSpots();
 const sp=MAP.spawnCT[0],home={x:cc(sp[0]),z:cc(sp[1])};
 // armes murales proches du départ, puis tout le reste réparti sur la carte
 const near=spots.slice().sort((a,b)=>Math.hypot(a.x-home.x,a.z-home.z)-Math.hypot(b.x-home.x,b.z-home.z));
 // MAC-10 à 500 : le mur le plus proche du départ, dans la zone accessible dès la manche 1
 const inStart=s=>!ZD.reach||!!ZD.reach[Math.floor(s.z/S)*N+Math.floor(s.x/S)];
 const first=near.find(s=>inStart(s)&&Math.hypot(s.x-home.x,s.z-home.z)>2)||near.find(inStart)||near[0];
 const walls=first?[first].concat(zPickSpread(near.slice(0,Math.max(10,near.length>>1)).filter(s=>s!==first),Math.min(WALLBUYS.length,7)-1,[first])):[];
 const rest=spots.filter(s=>!walls.includes(s));
 const boxSpots=zPickSpread(rest,3,walls);
 // la boîte mystère démarre dans la zone de départ (avant d'ouvrir les portes)
 if(ZD.reach){const ok=s=>!!ZD.reach[Math.floor(s.z/S)*N+Math.floor(s.x/S)];const st=rest.filter(s=>ok(s)&&!boxSpots.includes(s));const i0=boxSpots.findIndex(ok);if(i0>0)boxSpots.unshift(boxSpots.splice(i0,1)[0]);else if(i0<0&&st.length)boxSpots.unshift(st[Math.floor(Math.random()*st.length)]);}
 const rest2=rest.filter(s=>!boxSpots.includes(s));
 const machines=zPickSpread(rest2,6,walls.concat(boxSpots));
 walls.forEach((s,i)=>{const [k,pr]=WALLBUYS[i];zBuildWall(s,k,pr);ZB.inter.push({x:s.x,z:s.z,r:1.9,kind:'wall',k,price:pr});});
 ZB.boxSpots=boxSpots;ZB.boxIdx=0;ZB.boxUses=0;
 if(boxSpots.length)zMoveBox(0,true);
 const pk=Object.keys(PERKS);
 machines.forEach((s,i)=>{
  if(i===0){ZB.pap=zBuildPap(s);ZB.inter.push({x:s.x,z:s.z,r:2.2,kind:'pap'});}
  else if(pk[i-1]){const key=pk[i-1];zBuildPerk(s,key);ZB.inter.push({x:s.x,z:s.z,r:1.9,kind:'perk',key});}
 });
 ZB.insta=0;ZB.dbl=0;ZB.fire=0;
 for(const e of ents)if(!e.zombie){e.perks={};e.pts=500;}
 zHud();zPerkHud();
}
function zMoveBox(i,first){
 if(ZB.box){scene.remove(ZB.box.g);ZB.objs=ZB.objs.filter(o=>o!==ZB.box.g);ZB.inter=ZB.inter.filter(o=>o.kind!=='box');if(ZB.box.show)scene.remove(ZB.box.show);}
 const s=ZB.boxSpots[i%ZB.boxSpots.length];ZB.boxIdx=i;
 const g=zBuildBox(s);ZB.box={g,spot:s,state:'idle',t:0,k:null,show:null,teddy:false};
 ZB.inter.push({x:s.x,z:s.z,r:2,kind:'box'});
 if(!first){uiToast('La boîte mystère a changé de place !');sfx('teddy');}
}
function zCleanup(){
 zClearDoors();for(const f of ZD.frags)scene.remove(f.m);ZD.frags=[];
 for(const o of ZB.objs)scene.remove(o);ZB.objs=[];ZB.inter=[];
 for(const d of ZB.drops)scene.remove(d.m);ZB.drops=[];
 if(ZB.box&&ZB.box.show)scene.remove(ZB.box.show);ZB.box=null;ZB.pap=null;
 if(ZB.hudEl)ZB.hudEl.root.style.display='none';
}
/* ---------- boîte mystère ---------- */
function zRollBox(e){
 const b=ZB.box;if(!b||b.state!=='idle')return;
 const price=ZB.fire>G.t?10:BOX_PRICE;
 if(!zSpend(e,price))return;
 b.state='roll';b.t=0;b.owner=e;ZB.boxUses++;sfx('jingle',b.spot.x,b.spot.z);
 b.teddy=ZB.boxUses>3&&Math.random()<.16&&ZB.boxSpots.length>1;
 const pool=BOXPOOL.filter(k=>!(e.wp.p&&e.wp.p.k===k)&&!(e.wp.s&&e.wp.s.k===k));
 b.k=pick(pool);b.lastSwap=0;
}
function zBoxShow(k,teddy){
 const b=ZB.box;if(b.show)scene.remove(b.show);
 let m;
 if(teddy){m=new THREE.Group();const fur=new THREE.MeshStandardMaterial({color:0x8a5a35,roughness:1});const body=new THREE.Mesh(new THREE.SphereGeometry(.18,12,10),fur);body.scale.y=1.2;m.add(body);const head=new THREE.Mesh(new THREE.SphereGeometry(.13,12,10),fur);head.position.y=.27;m.add(head);for(const s of [-1,1]){const e=new THREE.Mesh(new THREE.SphereGeometry(.05,8,8),fur);e.position.set(s*.1,.38,0);m.add(e);}}
 else{m=new THREE.Group();const gun=cloneGun(gunTemplate(k));gun.rotation.y=Math.PI/2;gun.scale.setScalar(1.5);m.add(gun);}
 m.position.copy(b.g.position);m.position.y=.8;m.rotation.y=b.g.rotation.y;scene.add(m);b.show=m;
}
function zBoxUpdate(dt){
 const b=ZB.box;if(!b)return;
 const lid=b.g.userData.lid;
 b.g.userData.beam.material.opacity=.14+Math.sin(G.t*3)*.05;
 if(b.state==='idle'){lid.rotation.x+=(0-lid.rotation.x)*Math.min(1,dt*6);return;}
 b.t+=dt;lid.rotation.x+=(-1.25-lid.rotation.x)*Math.min(1,dt*6);
 if(b.state==='roll'){
  const rate=.08+b.t*.06;
  if(b.t-b.lastSwap>rate&&b.t<4){b.lastSwap=b.t;zBoxShow(pick(BOXPOOL));}
  if(b.show)b.show.position.y=.8+Math.min(1,b.t/4)*.6;
  if(b.t>=4.2){
   if(b.teddy){b.state='teddy';b.t=0;zBoxShow(null,true);b.owner.pts+=BOX_PRICE;if(b.owner.isPlayer)uiToast('Le nounours ! Points remboursés');sfx('teddy',b.spot.x,b.spot.z);}
   else{b.state='ready';b.t=0;zBoxShow(b.k);if(W[b.k].wonder&&b.owner.isPlayer)uiBanner(W[b.k].n.toUpperCase(),'Arme prodige !',2200,'#7dff6a');}
  }
 }else if(b.state==='ready'){
  if(b.show){b.show.position.y=1.4-Math.min(.6,b.t/9*.6);b.show.rotation.y+=dt*.6;}
  if(b.t>9){b.state='idle';if(b.show){scene.remove(b.show);b.show=null;}}
 }else if(b.state==='teddy'){
  if(b.show){b.show.position.y=1.4+b.t*1.4;b.show.rotation.y+=dt*3;}
  if(b.t>3){if(b.show){scene.remove(b.show);b.show=null;}let n=ZB.boxIdx+1+Math.floor(Math.random()*(ZB.boxSpots.length-1));ZB.boxUses=0;zMoveBox(n);}
 }
}
function zTakeBoxWeapon(e){
 const b=ZB.box;if(!b||b.state!=='ready'||b.owner!==e)return;
 zGive(e,b.k);b.state='idle';if(b.show){scene.remove(b.show);b.show=null;}
}
function zGive(e,k){
 const slot=slotOf(k);giveWeapon(e,k);e.cur=slot;if(e.isPlayer){vmDraw();sfx('draw');uiToast(W[k].n);}
}
/* ---------- bonus ---------- */
const DROPS={
 ammo:{n:'MUNITIONS MAX',c:0x7dff6a,ic:'⬢'},insta:{n:'MORT INSTANTANÉE',c:0xff3a3a,ic:'☠'},dbl:{n:'POINTS DOUBLES',c:0xffd23a,ic:'×2'},
 nuke:{n:'BOMBE',c:0xff9a3a,ic:'☢'},fire:{n:'VENTE DE FEU',c:0x7fe0ff,ic:'$'}
};
function dropTex(d){return cvTex(128,128,(x,w,h)=>{x.fillStyle='#'+d.c.toString(16).padStart(6,'0');x.shadowColor=x.fillStyle;x.shadowBlur=24;x.font='bold 78px Arial';x.textAlign='center';x.fillText(d.ic,64,92);});}
function zDrop(x,z){
 const key=pick(Object.keys(DROPS)),d=DROPS[key];
 const m=new THREE.Sprite(new THREE.SpriteMaterial({map:dropTex(d),transparent:true,depthWrite:false,toneMapped:false}));m.scale.set(1,1,1);
 const y=groundH(x,z);m.position.set(x,y+1,z);scene.add(m);ZB.drops.push({key,m,x,z,y,t:26});sfx('powerup',x,z,.7);
}
function zApplyDrop(key,who){
 const d=DROPS[key];uiBanner(d.n,'',1800,'#'+d.c.toString(16).padStart(6,'0'));sfx('powerup');
 const humans=ents.filter(e=>!e.zombie);
 if(key==='ammo'){for(const h of humans)for(const s of ['p','s']){const wi=h.wp[s];if(wi){wi.mag=magMax(h,wi.k);wi.res=Math.max(wi.res,W[wi.k].res*(wi.pap?2:1));}}}
 if(key==='insta')ZB.insta=G.t+30;
 if(key==='dbl')ZB.dbl=G.t+30;
 if(key==='fire')ZB.fire=G.t+30;
 if(key==='nuke'){for(const z of ents)if(z.zombie&&z.alive){fxExplosion(z.x,z.y+1,z.z,.4);killEnt(z,who,NADEW,false);}for(const h of humans)zPts(h,400);G.shake=Math.max(G.shake,1);}
}
function zDropsUpdate(dt){
 for(let i=ZB.drops.length-1;i>=0;i--){
  const d=ZB.drops[i];d.t-=dt;d.m.position.y=d.y+1+Math.sin(G.t*3)*.15;d.m.material.rotation=Math.sin(G.t*2)*.2;
  d.m.visible=d.t>6||Math.floor(G.t*6)%2===0;
  if(d.t<=0){scene.remove(d.m);ZB.drops.splice(i,1);continue;}
  for(const h of ents){if(h.zombie||!h.alive)continue;if(Math.hypot(h.x-d.x,h.z-d.z)<1.3){zApplyDrop(d.key,h);scene.remove(d.m);ZB.drops.splice(i,1);break;}}
 }
}
/* ---------- armes prodiges ---------- */
function wonderFire(e,w,wi){
 const ox=e.x,oy=e.y+eyeOf(e),oz=e.z,d=dirOf(e.yaw+(e.isPlayer?e.punchY*RAD:0),e.pitch+(e.isPlayer?e.punchP*RAD:0)),pap=!!wi.pap;
 const enemies=ents.filter(v=>v.alive&&v!==e&&(v.zombie||(MODE().team?v.team!==e.team:true)));
 if(w.wonder==='ray'){
  let bt=rayWall(ox,oy,oz,d[0],d[1],d[2],120),hv=null;
  for(const v of enemies){const h=hitEnt(v,ox,oy,oz,d[0],d[1],d[2],bt);if(h&&h.t<bt){bt=h.t;hv=v;}}
  const ex=ox+d[0]*bt,ey=oy+d[1]*bt,ez=oz+d[2]*bt,m=muzzlePos(e,d);
  addTracer(m[0],m[1],m[2],ex,ey,ez,pap?0xff3aff:0x4dff6a);addTracer(m[0],m[1],m[2],ex,ey,ez,pap?0xff3aff:0x4dff6a);
  if(fxReady)for(let k=0;k<26;k++)fxA.emit(ex,ey,ez,rand(-4,4),rand(-1,4),rand(-4,4),rand(.2,.5),.25,.05,pap?1:.3,pap?.3:1,pap?1:.4,1,2,1);
  for(const v of enemies){const dd=Math.hypot(v.x-ex,v.y+1-ey,v.z-ez);if(dd<2.8)hurt(v,e,w,'b',dd,w.dmg*(v===hv?1:.6));}
  sfx('zap',e.x,e.z,e.isPlayer?.9:1);
 }else if(w.wonder==='thunder'){
  const range=pap?18:14,cone=pap?.72:.6;
  for(const v of enemies){
   const dx=v.x-ox,dz=v.z-oz,dy=v.y+1-oy,L=Math.hypot(dx,dy,dz);if(L>range||L<.01)continue;
   if((dx*d[0]+dy*d[1]+dz*d[2])/L<Math.cos(cone))continue;
   if(rayWall(ox,oy,oz,dx/L,dy/L,dz/L,L)<L-.5)continue;
   hurt(v,e,w,'b',L,w.dmg);
   v.x+=dx/L*3;v.z+=dz/L*3;if(blocked(v.x,v.z,v.y,.3)){v.x-=dx/L*3;v.z-=dz/L*3;}
  }
  if(fxReady)for(let k=0;k<70;k++){const s=rand(8,22),sp=rand(-.35,.35),sp2=rand(-.25,.25);fxN.emit(ox+d[0]*1.2,oy-.2,oz+d[2]*1.2,(d[0]+sp*d[2])*s,d[1]*s+sp2*s,(d[2]-sp*d[0])*s,rand(.3,.6),.3,2.4,.85,.9,1,.45,0,3);}
  G.shake=Math.max(G.shake,.6);sfx('thunder',e.x,e.z);
 }else{ // givre
  const range=pap?14:11,cone=.42;
  for(const v of enemies){
   const dx=v.x-ox,dz=v.z-oz,dy=v.y+1-oy,L=Math.hypot(dx,dy,dz);if(L>range||L<.01)continue;
   if((dx*d[0]+dy*d[1]+dz*d[2])/L<Math.cos(cone))continue;
   if(rayWall(ox,oy,oz,dx/L,dy/L,dz/L,L)<L-.5)continue;
   v.frozenT=Math.max(v.frozenT||0,pap?4:2.6);hurt(v,e,w,'b',L,w.dmg*(v.frozenT>2?1.5:1));
  }
  if(fxReady)for(let k=0;k<50;k++){const s=rand(6,16),sp=rand(-.3,.3);fxA.emit(ox+d[0]*1,oy-.15,oz+d[2]*1,(d[0]+sp*d[2])*s,d[1]*s+rand(-2,2),(d[2]-sp*d[0])*s,rand(.3,.7),.12,.04,.6,.9,1,1,-1,2);}
  sfx('ice',e.x,e.z);
 }
 if(e.isPlayer){vmFire(w);e.punchP+=w.rec*2;G.shake=Math.max(G.shake,.08);MS.shots++;}
 if(wi.mag===0&&!e.isPlayer)startReload(e);
}
/* ---------- interactions (touche Utiliser) ---------- */
// who = le joueur qui interagit : le joueur local par défaut, ou un joueur distant (appelé par l'hôte)
function zInteract(dt,who,use){zInteractFor(dt,who||P,use===undefined?K('use'):use);}
function zInteractFor(dt,P,use){
 const me=P&&P.isPlayer;
 if(!P||!P.alive){return;}
 if(P.downed){P.useMsg='';return;}
 {const dn=ents.find(e=>!e.zombie&&e!==P&&e.alive&&e.downed&&Math.hypot(e.x-P.x,e.z-P.z)<1.9);
  if(dn){P.useMsg='[E] Maintiens : réanimer '+dn.name+' ('+Math.round(dn.revP/(P.perks.revive?1.5:3)*100)+' %)';if(use)dn.revP+=dt*(P.perks.revive?2:1);if(dn.revP>=3)zRevive(dn,P);return;}}
 let best=null,bd=1e9;
 const fx=-Math.sin(P.yaw),fz=-Math.cos(P.yaw);
 for(const it of ZB.inter){
  const dx=it.x-P.x,dz=it.z-P.z,d=Math.hypot(dx,dz);if(d>it.r)continue;
  const facing=(dx*fx+dz*fz)/(d||1);if(d>1&&facing<.2)continue;
  if(d<bd){bd=d;best=it;}
 }
 let msg='';
 const press=use&&!P.zUseLatch;P.zUseLatch=use;
 if(best){
  const kb='['+(me?String(cfg.binds.use||'E').replace('Key',''):'E')+']';
  if(best.kind==='wall'){
   const own=(P.wp.p&&P.wp.p.k===best.k)||(P.wp.s&&P.wp.s.k===best.k),pr=own?Math.round(best.price/2):best.price;
   msg=kb+' '+(own?'Munitions '+W[best.k].n:'Acheter '+W[best.k].n)+' — '+pr+' pts';
   if(press&&zSpend(P,pr)){if(own){const wi=P.wp[slotOf(best.k)];wi.mag=magMax(P,best.k);wi.res=W[best.k].res*(wi.pap?2:1);zTell(P,'Munitions rechargées','pickup');}else{zGive(P,best.k);zTell(P,'','buy');}}
  }else if(best.kind==='box'){
   const b=ZB.box;
   if(b.state==='idle'){const pr=ZB.fire>G.t?10:BOX_PRICE;msg=kb+' Boîte mystère — '+pr+' pts';if(press)zRollBox(P);}
   else if(b.state==='ready'&&b.owner===P){msg=kb+' Prendre '+W[b.k].n;if(press)zTakeBoxWeapon(P);}
   else msg='Boîte mystère…';
  }else if(best.kind==='perk'){
   const p=PERKS[best.key];
   if(P.perks[best.key])msg=p.n+' (déjà bu)';
   else{msg=kb+' '+p.n+' — '+p.price+' pts · '+p.d;if(press&&zSpend(P,p.price)){P.perks[best.key]=true;zTell(P,'','perk',[p.n.toUpperCase(),p.d,1800,p.c]);if(me)zPerkHud();}}
  }else if(best.kind==='door'){
   msg=kb+' Dégager les débris — '+best.door.price+' pts';if(press&&zSpend(P,best.door.price))zOpenDoor(best.door);
  }else if(best.kind==='pap'){
   const wi=P.wp[P.cur];
   if(!wi||P.cur==='k')msg='Forge Arcane : prends une arme en main';
   else if(wi.pap)msg=W[wi.k].n+' est déjà améliorée';
   else{msg=kb+' Forge Arcane : améliorer '+W[wi.k].n+' — '+PAP_PRICE+' pts';
    if(press&&zSpend(P,PAP_PRICE)){wi.pap=true;wi.mag=magMax(P,wi.k);wi.res=W[wi.k].res*2;sfx('pap',best.x,best.z);zTell(P,'','',['ARME AMÉLIORÉE',W[wi.k].n+' ★ — dégâts ×2, chargeur +50 %',2400,'#c77dff']);
     if(fxReady)for(let k=0;k<40;k++)fxA.emit(best.x,1.4,best.z,rand(-2,2),rand(1,4),rand(-2,2),rand(.4,.9),.15,.05,.75,.4,1,1,-1,1);}}
  }
 }
 P.useMsg=msg;
}
// retour au joueur concerné : directement s'il est local, par le réseau s'il est distant
function zTell(e,msg,snd,ban){
 if(e.isPlayer){if(msg)uiToast(msg);if(snd)sfx(snd);if(ban)uiBanner(ban[0],ban[1],ban[2],ban[3]);}
 else if(e.remote)netEvent({t:'msg',to:e.id,m:msg||'',s:snd||'',b:ban||null});
}
/* ---------- HUD ---------- */
function zHud(){
 if(!ZB.hudEl){
  const root=document.createElement('div');root.id='zhud';
  root.innerHTML='<div id="zround"></div><div id="zpts"><b>0</b></div><div id="zperks"></div><div id="zfx"></div>';
  $('hud').appendChild(root);
  const css=document.createElement('style');css.textContent=
   '#zhud{position:absolute;left:2vw;bottom:calc(2vh + 150px);display:none;pointer-events:none}'+
   '#zround{font:900 4.2rem Georgia,serif;color:#b3121b;text-shadow:0 0 18px #ff000088,2px 2px 0 #300;letter-spacing:4px;line-height:1}'+
   '#zpts{margin-top:6px;font:900 1.6rem Bahnschrift,Arial;color:#ffd75e;text-shadow:0 2px 6px #000;position:relative}'+
   '#zpts .zgain{position:absolute;left:100%;margin-left:10px;top:0;font-size:1rem;color:#ffe9a0;animation:zg .9s ease-out forwards}'+
   '@keyframes zg{from{opacity:1;transform:translate(0,0)}to{opacity:0;transform:translate(26px,-26px)}}'+
   '#zperks{display:flex;gap:6px;margin-top:8px}#zperks i{width:34px;height:34px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-style:normal;font-weight:900;color:#fff;font-size:15px;box-shadow:0 0 10px #0008;border:2px solid #fff6}'+
   '#zfx{margin-top:6px;font:800 .8rem Bahnschrift,Arial;letter-spacing:2px}';
  document.head.appendChild(css);
  ZB.hudEl={root,round:root.querySelector('#zround'),pts:root.querySelector('#zpts'),perks:root.querySelector('#zperks'),fx:root.querySelector('#zfx')};
 }
 return ZB.hudEl;
}
function tally(n){if(n>5)return String(n);return ['','I','II','III','IIII','𝍸'][n]||String(n);}
function zPerkHud(){const h=zHud();if(!P||!P.perks){h.perks.innerHTML='';return;}h.perks.innerHTML=Object.keys(PERKS).filter(k=>P.perks[k]).map(k=>'<i style="background:'+PERKS[k].c+'" title="'+PERKS[k].n+'">'+PERKS[k].ic+'</i>').join('');}
function zHudUpdate(){
 const h=zHud();h.root.style.display=zOn()&&G.running?'block':'none';if(!zOn())return;
 h.round.textContent=tally(Z.wave);h.pts.firstChild.textContent=(P.pts||0).toLocaleString('fr-FR');
 const f=[];if(ZB.insta>G.t)f.push('<span style="color:#ff3a3a">☠ MORT INSTANTANÉE '+Math.ceil(ZB.insta-G.t)+'</span>');if(ZB.dbl>G.t)f.push('<span style="color:#ffd23a">×2 POINTS '+Math.ceil(ZB.dbl-G.t)+'</span>');if(ZB.fire>G.t)f.push('<span style="color:#7fe0ff">$ VENTE DE FEU '+Math.ceil(ZB.fire-G.t)+'</span>');
 h.fx.innerHTML=f.join('<br>');
}
/* ---------- alliés bots : ils dépensent aussi leurs points ---------- */
function zBotsShop(){
 for(const b of ents){
  if(b.isPlayer||b.zombie||!b.alive)continue;
  if(!b.perks.jugg&&b.pts>=PERKS.jugg.price+500){b.pts-=PERKS.jugg.price;b.perks.jugg=true;}
  else if(b.wp.p&&!b.wp.p.pap&&b.pts>=PAP_PRICE+800){b.pts-=PAP_PRICE;b.wp.p.pap=true;b.wp.p.mag=magMax(b,b.wp.p.k);b.wp.p.res=W[b.wp.p.k].res*2;}
  else if(b.pts>=1500){const w=pick(['m4','ak','famas','ump','xm']);if(!b.wp.p||W[b.wp.p.k].price<W[w].price){b.pts-=1500;giveWeapon(b,w);b.cur='p';}}
 }
}
/* ---------- boucle ---------- */
function zUpdate(dt){
 if(!zOn()){if(ZB.hudEl)ZB.hudEl.root.style.display='none';return;}
 if(!G.running)return;
 zBoxUpdate(dt);zDropsUpdate(dt);zInteract(dt);zHudUpdate();zExtraUpdate(dt);
 if(ZB.pap&&ZB.pap.userData.rollers)ZB.pap.userData.rollers.rotation.x+=dt*2;
 for(const z of ents)if(z.zombie&&z.frozenT>0){z.frozenT-=dt;if(fxReady&&Math.random()<dt*6)fxA.emit(z.x,z.y+rand(.3,1.7),z.z,0,.3,0,.6,.1,.03,.7,.9,1,1,-.5,1);}
}
function zOnWave(){
 zRoundType();
 ZB.dropsWave=0;zBotsShop();
 for(const h of ents)if(!h.zombie&&h.isPlayer&&Z.wave>1)h.invuln=1;
}
