/* =====================================================================
   STRIKE ARENA — noyau : utilitaires, configuration, armes, grille 3D,
   collisions, lancers de rayons, pathfinding
   ===================================================================== */
const $=id=>document.getElementById(id);
const rand=(a,b)=>a+Math.random()*(b-a);
const clamp=(v,a,b)=>v<a?a:v>b?b:v;
const lerp=(a,b,t)=>a+(b-a)*t;
const RAD=Math.PI/180,TAU=Math.PI*2;
const angDiff=(a,b)=>{let d=b-a;while(d>Math.PI)d-=TAU;while(d<-Math.PI)d+=TAU;return d;};
const pick=a=>a[Math.floor(Math.random()*a.length)];
const smooth01=t=>{t=clamp(t,0,1);return t*t*(3-2*t);};
function shuffle(a){for(let i=a.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[a[i],a[j]]=[a[j],a[i]];}return a;}
const setText=(id,v)=>{const e=$(id);if(e&&e._v!==v){e._v=v;e.textContent=v;}};
const setHTML=(id,v)=>{const e=$(id);if(e&&e._h!==v){e._h=v;e.innerHTML=v;}};

/* ---------------- configuration ---------------- */
const cfg={cine:1,mode:'bomb',map:'village',diff:2,side:'rnd',size:5,ffa:7,rounds:7,tdmKills:40,ffaKills:25,eco:1,
 sens:1,fov:82,gfx:2,fx:1,vol:.7,fps:0,bob:1,name:'Vous',
 xh:{c:'#3dffa8',len:8,th:2,gap:5,dot:0,out:1},skins:{},loadout:{p:'ak',s:'deagle'}};
try{const s=JSON.parse(localStorage.getItem('sa2_cfg')||'{}');for(const k in s){if(k==='xh')Object.assign(cfg.xh,s.xh);else if(k==='skins')Object.assign(cfg.skins,s.skins);else if(k==='loadout')Object.assign(cfg.loadout,s.loadout);else cfg[k]=s[k];}}catch(e){}
const saveCfg=()=>{try{localStorage.setItem('sa2_cfg',JSON.stringify(cfg));}catch(e){}};
const DEFBINDS={forward:'KeyW',back:'KeyS',left:'KeyA',right:'KeyD',jump:'Space',crouch:'KeyC',sprint:'ShiftLeft',walk:'AltLeft',reload:'KeyR',use:'KeyE',buy:'KeyB',score:'Tab',slot1:'Digit1',slot2:'Digit2',slot3:'Digit3',last:'KeyQ',frag:'KeyG',flash:'KeyF',smoke:'KeyH',inspect:'KeyV',emote:'KeyT',mine:'KeyX',spray:'KeyJ',fire:'Mouse0',ads:'Mouse2',next:'WheelDown',prev:'WheelUp'};
const BINDLABEL={forward:'Avancer',back:'Reculer',left:'Gauche',right:'Droite',jump:'Sauter',crouch:"S'accroupir",sprint:'Sprint (2× : sprint tactique)',walk:'Marcher (silencieux)',fire:'Tirer',ads:'Viser (ADS) / lunette',reload:'Recharger',use:'Poser / désamorcer',buy:'Boutique / armurerie',score:'Tableau des scores',slot1:'Arme principale',slot2:'Pistolet',slot3:'Couteau',last:'Dernière arme',next:'Arme suivante',prev:'Arme précédente',frag:'Grenade frag',flash:'Flashbang',smoke:'Fumigène',inspect:"Inspecter l'arme",emote:'Danse / emote',spray:'Spray',mine:'Poser une mine'};
// ancienne config : Maj servait à marcher -> Maj = sprint, Alt = marcher
if(cfg.binds&&!cfg.binds.sprint&&(cfg.binds.walk==='ShiftLeft'||cfg.binds.walk==='ShiftRight')){cfg.binds.sprint=cfg.binds.walk;cfg.binds.walk=cfg.binds.walk==='ShiftLeft'?'AltLeft':'AltRight';}
cfg.binds=Object.assign({},DEFBINDS,cfg.binds||{});
const K=a=>!!keys[cfg.binds[a]];

/* ---------------- difficulté des bots ---------------- */
const DIFFS=[
 {n:'Novice', react:1.25,turn:70,  spread:10,  aimHead:0,   speed:.78, strafe:0,   hear:.2, dmg:.55,sight:40, bmin:2,bmax:5, pmin:.6,pmax:1.2,semi:.55,crouch:0,  nade:.2,desc:'Pour découvrir le jeu : réagit lentement, vise très mal, fait peu de dégâts. En Zombies : zombies lents et fragiles.'},
 {n:'Facile', react:.8,  turn:130, spread:6,   aimHead:.02, speed:.86, strafe:.1,  hear:.4, dmg:.8, sight:55, bmin:3,bmax:7, pmin:.4,pmax:.8, semi:.4, crouch:0,  nade:.4,desc:'Un adversaire facile à battre, tire en rafales imprécises. En Zombies : zombies moins forts et moins nombreux.'},
 {n:'Normal', react:.45, turn:240, spread:3,   aimHead:.12, speed:.95, strafe:.45, hear:.7, dmg:1,  sight:70, bmin:4,bmax:9, pmin:.25,pmax:.55,semi:.28,crouch:.1, nade:.6,desc:'Équilibré : se déplace, entend les tirs, vise correctement.'},
 {n:'Pro',    react:.26, turn:380, spread:1.6, aimHead:.3,  speed:1,   strafe:.8,  hear:.9, dmg:1,  sight:90, bmin:5,bmax:12,pmin:.12,pmax:.3, semi:.16,crouch:.3, nade:.8,desc:'Réflexes rapides, strafe + arrêt pour tirer, vise la tête.'},
 {n:'Légende',react:.13, turn:650, spread:.75, aimHead:.55, speed:1.05,strafe:1,   hear:1,  dmg:1.05,sight:110,bmin:6,bmax:16,pmin:.05,pmax:.18,semi:.1, crouch:.5, nade:1,desc:'Réaction quasi instantanée, headshots constants, grenades utiles.'}
];

/* ---------------- modes de jeu ---------------- */
const MODES={
 bomb:{n:'Compétitif',ic:'💣',c:'#ff4655',team:true,bomb:true,desc:'Pose ou désamorce la bombe. Économie, boutique, manches.',limitLabel:'Manches pour gagner',limits:[3,5,7,13]},
 tdm:{n:'Match à mort par équipe',ic:'⚔',c:'#4aa3ff',team:true,respawn:3,desc:'Deux équipes, réapparition rapide. Premier à atteindre le score.',limitLabel:'Éliminations pour gagner',limits:[20,30,40,60]},
 ffa:{n:'Match à mort',ic:'☠',c:'#ffb938',team:false,respawn:2,desc:'Chacun pour soi. Le meilleur score gagne.',limitLabel:'Éliminations pour gagner',limits:[15,25,35]},
 gg:{n:'Course aux armes',ic:'🔫',c:'#7dff9f',team:false,respawn:1.5,gun:true,desc:'Chaque élimination change ton arme. Termine avec le couteau.',limitLabel:'Niveaux',limits:[]},
 rapid:{n:'Désamorçage rapide',ic:'⚡',c:'#ffd23a',team:true,bomb:true,desc:'Manches de 45 s, armes fournies, bombe dès le début. Pur gunfight.',limitLabel:'Manches pour gagner',limits:[5,7,9]},
 koth:{n:'Capture de zone',ic:'🚩',c:'#35e0c0',team:true,respawn:3,desc:'Tiens la zone qui change de place pour marquer des points.',limitLabel:'Points pour gagner',limits:[100,200,300]},
 zombies:{n:'Zombies (coop)',ic:'🧟',c:'#8fd14f',team:true,respawn:0,desc:'Façon Black Ops : points, armes aux murs, boîte mystère, atouts, Forge Arcane et armes prodiges.',limitLabel:'Manches à survivre',limits:[10,15,25,99]},
 br:{n:'Bataille royale',ic:'🪂',c:'#c77dff',team:false,respawn:0,desc:'Un seul survivant. Ramasse des armes, évite la zone qui se resserre.',limitLabel:'',limits:[]},
 train:{n:'Entraînement',ic:'🎯',c:'#ff9a3a',team:false,respawn:1,desc:'Cibles mobiles, chronomètre 60 s. Mesure précision et réflexes.',limitLabel:'',limits:[]}
};
const GG_LADDER=['glock','p250','fiveseven','deagle','mac10','mp9','ump','nova','xm','galil','famas','ak','m4','sg553','ssg','awp','knife'];
const DM_TIME=480;

/* ---------------- armes ---------------- */
// slot : 0 principale, 1 secondaire, 2 couteau
const W={
 knife:{n:'Couteau',slot:2,cat:'melee',price:0,dmg:40,hs:1,rpm:110,auto:1,mag:0,res:0,rel:0,spr:0,mv:0,rec:0,spd:1.08,kill:1500,melee:1,len:.3,ap:.8},
 glock:{n:'Glock-18',slot:1,cat:'pistol',price:0,dmg:27,hs:3.2,rpm:400,auto:0,mag:20,res:120,rel:2.2,spr:.5,mv:3,rec:.9,spd:1,kill:300,len:.2,ap:.47,fo:15,fr:.012,col:0x2b2f35},
 usp:{n:'USP-S',slot:1,cat:'pistol',price:0,dmg:32,hs:3.4,rpm:340,auto:0,mag:12,res:24,rel:2.2,spr:.4,mv:3,rec:1,spd:1,kill:300,len:.24,ap:.5,fo:15,fr:.012,col:0x3a3f47},
 p250:{n:'P250',slot:1,cat:'pistol',price:300,dmg:38,hs:3.4,rpm:380,auto:0,mag:13,res:26,rel:2.2,spr:.5,mv:3,rec:1.1,spd:1,kill:300,len:.21,ap:.64,fo:15,fr:.012,col:0x4a4f57},
 fiveseven:{n:'Five-SeveN',slot:1,cat:'pistol',price:500,dmg:31,hs:3.4,rpm:380,auto:0,mag:20,res:100,rel:2.2,spr:.45,mv:3,rec:.9,spd:1,kill:300,len:.21,ap:.91,fo:18,fr:.011,col:0x5b6168},
 deagle:{n:'Desert Eagle',slot:1,cat:'pistol',price:700,dmg:62,hs:3,rpm:150,auto:0,mag:7,res:35,rel:2.2,spr:.6,mv:5,rec:4,spd:.97,kill:300,len:.28,ap:.93,fo:20,fr:.01,col:0xb9bec6},
 mac10:{n:'MAC-10',slot:0,cat:'smg',price:1050,dmg:29,hs:2.8,rpm:800,auto:1,mag:30,res:100,rel:2.6,spr:1.3,mv:5,rec:.5,spd:1,kill:600,len:.3,ap:.57,fo:10,fr:.014,col:0x2c3036},
 mp9:{n:'MP9',slot:0,cat:'smg',price:1250,dmg:26,hs:2.8,rpm:800,auto:1,mag:30,res:120,rel:2.1,spr:1,mv:4,rec:.45,spd:1,kill:600,len:.4,ap:.6,fo:12,fr:.012,col:0x30343a},
 ump:{n:'UMP-45',slot:0,cat:'smg',price:1200,dmg:35,hs:2.6,rpm:600,auto:1,mag:25,res:100,rel:3.5,spr:.9,mv:4,rec:.55,spd:.95,kill:600,len:.5,ap:.65,fo:15,fr:.011,col:0x3d4249},
 p90:{n:'P90',slot:0,cat:'smg',price:2350,dmg:25,hs:2.6,rpm:900,auto:1,mag:50,res:100,rel:3.3,spr:1.1,mv:3,rec:.4,spd:.96,kill:300,len:.46,ap:.69,fo:14,fr:.012,col:0x4a4f55},
 nova:{n:'Nova',slot:0,cat:'shotgun',price:1050,dmg:10,pel:9,hs:1.5,rpm:70,auto:0,mag:8,res:32,rel:3.2,spr:3.8,mv:2,rec:4,spd:.97,kill:900,len:.9,ap:.5,fo:5,fr:.07,fmin:.1,col:0x3a3a3a},
 sawedoff:{n:'Sawed-Off',slot:0,cat:'shotgun',price:1100,dmg:12,pel:8,hs:1.5,rpm:60,auto:0,mag:2,res:32,rel:3.4,spr:6,mv:2,rec:5,spd:.96,kill:900,len:.5,ap:.5,fo:4,fr:.09,fmin:.08,col:0x4a3a2a},
 xm:{n:'XM1014',slot:0,cat:'shotgun',price:2000,dmg:10,pel:8,hs:1.5,rpm:190,auto:1,mag:7,res:32,rel:3.6,spr:4,mv:2,rec:3,spd:.96,kill:900,len:.85,ap:.5,fo:5,fr:.07,fmin:.1,col:0x33363a},
 galil:{n:'Galil AR',slot:0,cat:'rifle',price:1800,dmg:30,hs:3.5,rpm:650,auto:1,mag:35,res:90,rel:3.2,spr:.4,mv:6,rec:.6,spd:.92,kill:300,len:.78,ap:.775,fo:40,fr:.004,col:0x5b5f45},
 famas:{n:'FAMAS',slot:0,cat:'rifle',price:2050,dmg:30,hs:3.5,rpm:666,auto:1,mag:25,res:90,rel:3.3,spr:.35,mv:6,rec:.55,spd:.94,kill:300,len:.7,ap:.7,fo:40,fr:.004,col:0x4a5058},
 ak:{n:'AK-47',slot:0,cat:'rifle',price:2700,dmg:36,hs:4,rpm:600,auto:1,mag:30,res:90,rel:2.5,spr:.25,mv:6,rec:.8,spd:.9,kill:300,len:.88,ap:.775,fo:50,fr:.003,col:0x4b4f55},
 m4:{n:'M4A4',slot:0,cat:'rifle',price:3100,dmg:33,hs:3.8,rpm:666,auto:1,mag:30,res:90,rel:3.1,spr:.2,mv:6,rec:.6,spd:.92,kill:300,len:.82,ap:.7,fo:50,fr:.003,col:0x2c3036},
 sg553:{n:'SG 553',slot:0,cat:'rifle',price:3000,dmg:30,hs:4,rpm:600,auto:1,mag:30,res:90,rel:3.1,spr:.25,mv:6,rec:.5,spd:.9,kill:300,len:.8,ap:.8,zoom:1.8,fo:50,fr:.003,col:0x3a4a5a},
 aug:{n:'AUG',slot:0,cat:'rifle',price:3300,dmg:28,hs:3.8,rpm:600,auto:1,mag:30,res:90,rel:3.8,spr:.25,mv:6,rec:.45,spd:.9,kill:300,len:.72,ap:.85,zoom:1.8,fo:50,fr:.003,col:0x5a6b55},
 ssg:{n:'SSG 08',slot:0,cat:'sniper',price:1700,dmg:88,hs:3,rpm:48,auto:0,mag:10,res:90,rel:3.7,spr:.05,mv:8,rec:5,spd:.96,kill:300,len:1,ap:.85,zoom:3,overlay:1,fo:90,fr:.001,col:0x4f5a44},
 awp:{n:'AWP',slot:0,cat:'sniper',price:4750,dmg:115,hs:4,rpm:42,auto:0,mag:5,res:30,rel:3.7,spr:.02,mv:8,rec:7,spd:.88,kill:100,len:1.2,ap:.95,zoom:3.5,overlay:1,fo:120,fr:.001,col:0x2f4a3a},
 scar:{n:'SCAR-20',slot:0,cat:'sniper',price:5000,dmg:80,hs:3.5,rpm:240,auto:1,mag:20,res:90,rel:3.1,spr:.1,mv:8,rec:3,spd:.84,kill:300,len:1,ap:.825,zoom:2.6,overlay:1,fo:90,fr:.001,col:0x3a3d3a},
 negev:{n:'Negev',slot:0,cat:'lmg',price:1700,dmg:30,hs:3.3,rpm:1000,auto:1,mag:150,res:300,rel:5.8,spr:1.5,mv:9,rec:.6,spd:.78,kill:300,len:.9,ap:.75,fo:40,fr:.004,col:0x4a4a40},
 m249:{n:'M249',slot:0,cat:'lmg',price:5200,dmg:32,hs:3.5,rpm:750,auto:1,mag:100,res:200,rel:5.7,spr:.6,mv:8,rec:.5,spd:.82,kill:300,len:.95,ap:.8,fo:45,fr:.003,col:0x3a3d33}
};
const CATS=[['Pistolets',['glock','usp','p250','fiveseven','deagle']],['SMG',['mac10','mp9','ump','p90']],['Pompes',['nova','sawedoff','xm']],['Fusils',['galil','famas','ak','m4','sg553','aug']],['Snipers',['ssg','awp','scar']],['Lourd',['negev','m249']]];
const ADS_ZOOM={pistol:1.12,smg:1.2,shotgun:1.1,rifle:1.3,lmg:1.2,sniper:1,melee:1};
const NADEW={n:'Grenade',kill:300,hs:1,ap:.5,fo:999,fr:0};
const CATFR={pistol:'Pistolet',smg:'SMG',shotgun:'Fusil à pompe',rifle:'Fusil d\'assaut',sniper:'Sniper',lmg:'Mitrailleuse',melee:'Mêlée'};

/* ---------------- grille 3D (champ de hauteur) ----------------
   Chaque case a une hauteur de sol/dessus (G_H), éventuellement un plafond
   (G_CEIL) et peut appartenir à une rampe (hauteur continue).               */
const N=40,S=2,NC=N*N;
const G_TYPE=new Uint8Array(NC),G_H=new Float32Array(NC),G_CEIL=new Float32Array(NC),G_RAMP=new Uint8Array(NC),G_TAG=new Uint8Array(NC);
let RAMPS=[];
const TY={OPEN:0,WALL:1,CRATE:2,HOUSE:3,LOW:4,BARREL:5,PLAT:6,CONT:7,CONC:8,PILLAR:9};
const TYH=[0,6,2.6,4.6,.9,1.1,3,2.7,5.4,6];
const STEP=.55,STEPDOWN=.6,PR=.36,GRAV=20,JUMPV=6.2;
const cc=c=>(c+.5)*S;
const cellOf=(x,z)=>[Math.floor(x/S),Math.floor(z/S)];
function resetGrid(){G_TYPE.fill(0);G_H.fill(0);G_CEIL.fill(99);G_RAMP.fill(0);G_TAG.fill(0);RAMPS=[];}
const GB={ // API de construction de map
 rect(t,x1,z1,x2,z2,h){const hh=h===undefined?TYH[t]:h;for(let z=z1;z<=z2;z++)for(let x=x1;x<=x2;x++){if(x<0||z<0||x>=N||z>=N)continue;const i=z*N+x;G_TYPE[i]=t;G_H[i]=t===0?0:hh;G_RAMP[i]=0;}},
 clear(x1,z1,x2,z2){for(let z=z1;z<=z2;z++)for(let x=x1;x<=x2;x++){const i=z*N+x;G_TYPE[i]=0;G_H[i]=0;G_RAMP[i]=0;G_CEIL[i]=99;}},
 ramp(x1,z1,x2,z2,axis,hA,hB){RAMPS.push({x1,z1,x2,z2,axis,hA,hB});const id=RAMPS.length;for(let z=z1;z<=z2;z++)for(let x=x1;x<=x2;x++){const i=z*N+x;G_TYPE[i]=0;G_RAMP[i]=id;G_H[i]=(hA+hB)/2;}},
 ceil(x1,z1,x2,z2,h){for(let z=z1;z<=z2;z++)for(let x=x1;x<=x2;x++)G_CEIL[z*N+x]=h;},
 tag(x1,z1,x2,z2,t){for(let z=z1;z<=z2;z++)for(let x=x1;x<=x2;x++)G_TAG[z*N+x]=t;}
};
function groundH(x,z){
 const cx=Math.floor(x/S),cz=Math.floor(z/S);
 if(cx<0||cz<0||cx>=N||cz>=N)return 99;
 const i=cz*N+cx,r=G_RAMP[i];
 if(r){const R=RAMPS[r-1];const t=R.axis==='x'?(x-R.x1*S)/((R.x2-R.x1+1)*S):(z-R.z1*S)/((R.z2-R.z1+1)*S);return R.hA+(R.hB-R.hA)*clamp(t,0,1);}
 return G_H[i];
}
function ceilAt(x,z){const cx=Math.floor(x/S),cz=Math.floor(z/S);if(cx<0||cz<0||cx>=N||cz>=N)return 0;return G_CEIL[cz*N+cx];}
// vrai si un cylindre de rayon r à (x,z) dont les pieds sont à y est bloqué
function blocked(x,z,y,r){
 r=r||PR;
 if(groundH(x,z)-y>STEP)return true;
 if(groundH(x+r,z)-y>STEP||groundH(x-r,z)-y>STEP||groundH(x,z+r)-y>STEP||groundH(x,z-r)-y>STEP)return true;
 const d=r*.72;
 if(groundH(x+d,z+d)-y>STEP||groundH(x-d,z+d)-y>STEP||groundH(x+d,z-d)-y>STEP||groundH(x-d,z-d)-y>STEP)return true;
 if(ceilAt(x,z)-groundH(x,z)<1.75)return true;
 return false;
}

/* ---------------- lancer de rayon (murs, sol, plafonds, rampes) ---------------- */
const smokes=[]; // {x,y,z,r,t}
function rayWall(ox,oy,oz,dx,dy,dz,maxT){
 let cx=Math.floor(ox/S),cz=Math.floor(oz/S);
 const sx=dx>0?1:-1,sz=dz>0?1:-1;
 const tdx=dx!==0?Math.abs(S/dx):1e9,tdz=dz!==0?Math.abs(S/dz):1e9;
 let tmx=dx!==0?((dx>0?(cx+1)*S-ox:ox-cx*S)/Math.abs(dx)):1e9;
 let tmz=dz!==0?((dz>0?(cz+1)*S-oz:oz-cz*S)/Math.abs(dz)):1e9;
 const blk=t=>{const px=ox+dx*t,py=oy+dy*t,pz=oz+dz*t;if(py<groundH(px,pz))return true;if(py>ceilAt(px,pz))return true;return false;};
 if(blk(0))return 0;
 let t0=0,tp=0;
 for(let it=0;it<300;it++){
  if(cx<0||cz<0||cx>=N||cz>=N)return Math.min(t0,maxT);
  const t1=Math.min(tmx,tmz,maxT),i=cz*N+cx;
  const flat=G_H[i]===0&&!G_RAMP[i]&&G_CEIL[i]>=99;
  let hit=-1;
  if(flat){if(dy<0&&blk(t1-1e-4))hit=t1-1e-4;}
  else{
   if(blk(t0+1e-4))hit=t0+1e-4;
   else{const tm=(t0+t1)*.5;if(blk(tm))hit=tm;else if(blk(t1-1e-4))hit=t1-1e-4;}
  }
  if(hit>=0){let lo=tp,hi=hit;for(let k=0;k<7;k++){const m=(lo+hi)*.5;if(blk(m))hi=m;else lo=m;}return Math.min(hi,maxT);}
  tp=t1-1e-4;
  if(t1>=maxT)return maxT;
  t0=t1;
  if(tmx<tmz){tmx+=tdx;cx+=sx;}else{tmz+=tdz;cz+=sz;}
 }
 return maxT;
}
// la fumée gêne la vue des bots (pas les balles)
function smokeBlocks(ox,oy,oz,dx,dy,dz,L){
 for(const s of smokes){
  if(s.t<=0)continue;
  const ocx=ox-s.x,ocy=oy-s.y,ocz=oz-s.z,b=ocx*dx+ocy*dy+ocz*dz,c=ocx*ocx+ocy*ocy+ocz*ocz-s.r*s.r,disc=b*b-c;
  if(disc<0)continue;
  const t=-b-Math.sqrt(disc),t2=-b+Math.sqrt(disc);
  if(t2>0&&t<L)return true;
 }
 return false;
}
function losClear(ax,ay,az,bx,by,bz,ignoreSmoke){
 const dx=bx-ax,dy=by-ay,dz=bz-az,L=Math.hypot(dx,dy,dz);if(L<.01)return true;
 const ux=dx/L,uy=dy/L,uz=dz/L;
 if(rayWall(ax,ay,az,ux,uy,uz,L)<L-.3)return false;
 if(!ignoreSmoke&&smokes.length&&smokeBlocks(ax,ay,az,ux,uy,uz,L))return false;
 return true;
}

/* ---------------- pathfinding A* sur grille avec relief ---------------- */
let NODEH=new Float32Array(NC);
const walkableCell=i=>{const t=G_TYPE[i];return t===0||t===6;};
function computeNodeHeights(){for(let i=0;i<NC;i++)NODEH[i]=groundH(cc(i%N),cc((i/N)|0));}
// coût de la transition a->b (-1 = impossible)
function edgeCost(a,b,diag){
 if(!walkableCell(b))return -1;
 const d=NODEH[b]-NODEH[a];
 if(G_RAMP[a]||G_RAMP[b])return Math.abs(d)<=1.9?1+Math.abs(d)*.2:-1;
 if(Math.abs(d)<=STEP)return 1;
 if(d<-STEP&&d>=-3.5&&!diag)return 5+(-d)*2; // saut vers le bas
 return -1;
}
const gS=new Float32Array(NC),fS=new Float32Array(NC),came=new Int16Array(NC),clo=new Uint8Array(NC);
const NB=[[1,0,1],[-1,0,1],[0,1,1],[0,-1,1],[1,1,1.414],[1,-1,1.414],[-1,1,1.414],[-1,-1,1.414]];
function nearestFree(cx,cz){
 cx=clamp(cx,0,N-1);cz=clamp(cz,0,N-1);
 if(walkableCell(cz*N+cx))return [cx,cz];
 for(let r=1;r<10;r++)for(let dz=-r;dz<=r;dz++)for(let dx=-r;dx<=r;dx++){
  if(Math.max(Math.abs(dx),Math.abs(dz))!==r)continue;
  const x=cx+dx,z=cz+dz;if(x<0||z<0||x>=N||z>=N)continue;
  if(walkableCell(z*N+x))return [x,z];
 }
 return [cx,cz];
}
function walkClear(ax,az,bx,bz){
 const dx=bx-ax,dz=bz-az,L=Math.hypot(dx,dz);if(L<.01)return true;
 let gp=groundH(ax,az);
 const n=Math.ceil(L/.45);
 for(let k=1;k<=n;k++){
  const t=k/n,x=ax+dx*t,z=az+dz*t,g=groundH(x,z);
  if(Math.abs(g-gp)>.5)return false;
  if(blocked(x,z,gp,.42))return false;
  gp=g;
 }
 return true;
}
function findPath(sx,sz,gx,gz){
 const s=nearestFree(Math.floor(sx/S),Math.floor(sz/S)),g=nearestFree(Math.floor(gx/S),Math.floor(gz/S));
 const si=s[1]*N+s[0],gi=g[1]*N+g[0];
 if(si===gi)return [[sx,sz],[gx,gz]];
 gS.fill(1e9);clo.fill(0);came.fill(-1);
 const open=[si];gS[si]=0;fS[si]=0;let found=false;
 while(open.length){
  let bi=0,bf=fS[open[0]];
  for(let i=1;i<open.length;i++){if(fS[open[i]]<bf){bf=fS[open[i]];bi=i;}}
  const cur=open[bi];open[bi]=open[open.length-1];open.pop();
  if(cur===gi){found=true;break;}
  if(clo[cur])continue;clo[cur]=1;
  const cx=cur%N,cz=(cur/N)|0;
  for(let k=0;k<8;k++){
   const nx=cx+NB[k][0],nz=cz+NB[k][1];
   if(nx<0||nz<0||nx>=N||nz>=N)continue;
   const ni=nz*N+nx;if(clo[ni])continue;
   const diag=NB[k][0]!==0&&NB[k][1]!==0;
   let ec=edgeCost(cur,ni,diag);if(ec<0)continue;
   if(diag){
    const o1=cz*N+nx,o2=nz*N+cx;
    if(edgeCost(cur,o1,false)<0||edgeCost(cur,o2,false)<0)continue;
    ec*=1.414;
   }
   const ng=gS[cur]+ec;
   if(ng<gS[ni]){gS[ni]=ng;came[ni]=cur;const ddx=Math.abs(nx-g[0]),ddz=Math.abs(nz-g[1]);fS[ni]=ng+(ddx+ddz)+(1.414-2)*Math.min(ddx,ddz);open.push(ni);}
  }
 }
 if(!found)return null;
 const pts=[];let c=gi;
 while(c!==-1&&c!==si){pts.push([cc(c%N),cc((c/N)|0)]);c=came[c];}
 pts.push([sx,sz]);pts.reverse();
 if(walkableCell(Math.floor(gz/S)*N+Math.floor(gx/S)))pts[pts.length-1]=[gx,gz];
 const out=[pts[0]];let i=0;
 while(i<pts.length-1){let j=pts.length-1;while(j>i+1&&!walkClear(pts[i][0],pts[i][1],pts[j][0],pts[j][1]))j--;out.push(pts[j]);i=j;}
 return out;
}
