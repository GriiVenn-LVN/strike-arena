/* =====================================================================
   ARMURIER (façon Gunsmith de Call of Duty)
   6 emplacements (bouche, optique, canon, sous-canon, chargeur, crosse),
   5 accessoires max par arme. Chaque accessoire a un modèle 3D posé sur
   l'arme (aperçu de l'Arsenal ET vue subjective) et des effets réels.
   cfg.att[k] = {muzzle:'sil', optic:'reddot', ...}
   ===================================================================== */
const ATT_SLOTS=[
 {id:'muzzle',n:'Bouche',ic:'◉'},{id:'optic',n:'Optique',ic:'⌖'},{id:'barrel',n:'Canon',ic:'═'},
 {id:'under',n:'Sous-canon',ic:'⊥'},{id:'mag',n:'Chargeur',ic:'▮'},{id:'stock',n:'Crosse',ic:'◣'}
];
const ATT_MAX=5;
/* m : multiplicateurs. rec = recul vertical, recH = horizontal, adsSpr = dispersion en visée,
   hip = dispersion à la hanche, mob = vitesse de déplacement, ads = vitesse de visée,
   rng = portée efficace, rel = durée de rechargement, mag = taille du chargeur, snd = volume du tir */
const ATTS={
 sil:{s:'muzzle',n:'Silencieux',lv:1,d:'Tir discret : son très réduit, les ennemis vous entendent de moins loin, pas de flamme.',m:{snd:.35,rng:.9,ads:.95,dmg:.95},sil:1,noFlash:1},
 comp:{s:'muzzle',n:'Compensateur',lv:2,d:'Canalise les gaz vers le haut : recul vertical réduit.',m:{rec:.85,ads:.97}},
 brake:{s:'muzzle',n:'Frein de bouche',lv:3,d:'Gaz sur les côtés : recul horizontal fortement réduit, tir plus bruyant.',m:{recH:.68,snd:1.15}},
 flash:{s:'muzzle',n:'Cache-flamme',lv:1,d:'Masque la flamme de bouche, léger gain de stabilité.',m:{rec:.95},noFlash:1},
 reddot:{s:'optic',n:'Point rouge',lv:1,d:'Visée nette et dégagée : dispersion en visée −25 %.',m:{adsSpr:.75}},
 holo:{s:'optic',n:'Holographique',lv:2,d:'Réticule cerclé, grande fenêtre : dispersion en visée −20 %, visée plus rapide.',m:{adsSpr:.8,ads:1.05}},
 acog:{s:'optic',n:'Lunette ×2,5',lv:4,d:'Grossissement ×2,5 pour la moyenne distance. Visée plus lente.',m:{adsSpr:.7,ads:.85,zoom:1.9}},
 long:{s:'barrel',n:'Canon long',lv:3,d:'Portée efficace +30 %, balles plus précises. Arme plus lourde.',m:{rng:1.3,hip:.92,adsSpr:.92,mob:.96,ads:.92}},
 heavy:{s:'barrel',n:'Canon lourd',lv:5,d:'Recul −12 %, portée +10 %. Mobilité réduite.',m:{rec:.88,recH:.9,rng:1.1,mob:.93,ads:.9}},
 grip:{s:'under',n:'Poignée verticale',lv:2,d:'Meilleure tenue : recul −18 %.',m:{rec:.82,recH:.85,ads:.96}},
 angled:{s:'under',n:'Poignée inclinée',lv:3,d:'Épaulement rapide : vitesse de visée +20 %.',m:{ads:1.2,rec:.94}},
 laser:{s:'under',n:'Laser tactique',lv:4,d:'Précision à la hanche +30 %, visée plus rapide. Le laser est visible.',m:{hip:.7,ads:1.06}},
 ext:{s:'mag',n:'Chargeur étendu',lv:2,d:'+30 % de munitions par chargeur. Rechargement un peu plus lent.',m:{mag:1.3,rel:1.12,mob:.98}},
 fast:{s:'mag',n:'Chargeurs jumelés',lv:3,d:'Deux chargeurs scotchés : rechargement −30 %.',m:{rel:.7}},
 light:{s:'stock',n:'Crosse squelette',lv:4,d:'Mobilité +7 %, visée plus rapide. Un peu plus de recul.',m:{mob:1.07,ads:1.08,rec:1.08}},
 tac:{s:'stock',n:'Crosse tactique',lv:5,d:'Crosse rembourrée : recul −10 %. Mobilité réduite.',m:{rec:.9,recH:.92,mob:.96}}
};
// emplacements autorisés par catégorie d'arme
const ATT_CAT={
 pistol:{muzzle:['sil','comp','flash'],optic:['reddot'],under:['laser'],mag:['ext','fast']},
 smg:null,rifle:null,lmg:null,
 shotgun:{muzzle:['brake','flash'],optic:['reddot','holo'],barrel:['long'],under:['grip','laser'],mag:['ext','fast'],stock:['light','tac']},
 sniper:{muzzle:['sil','brake','flash'],barrel:['long','heavy'],under:['grip','laser'],mag:['ext','fast'],stock:['light','tac']}
};
function attAllowed(k){
 const w=W[k];if(!w||w.melee||w.wonder||w.cat==='wonder'||w.cat==='melee')return {};
 const lim=ATT_CAT[w.cat],out={};
 for(const s of ATT_SLOTS){const l=lim===undefined||lim===null?Object.keys(ATTS).filter(a=>ATTS[a].s===s.id):(lim[s.id]||[]);if(l.length)out[s.id]=l;}
 return out;
}
// ancien format {sil:true,opt:true,ext:true,grip:true} -> nouveau format par emplacement
(function attMigrate(){
 const conv={sil:['muzzle','sil'],opt:['optic','reddot'],ext:['mag','ext'],grip:['under','grip']};
 for(const k in cfg.att){const a=cfg.att[k];if(!a||typeof a!=='object')continue;
  for(const o in conv)if(a[o]===true||a[o]===false){if(a[o])a[conv[o][0]]=conv[o][1];delete a[o];}}
})();
function attSel(e,k){return e&&e.isPlayer&&cfg.att[k]?cfg.att[k]:{};}
// liste des accessoires actifs (respecte le niveau et la catégorie)
function attList(k,sel){
 const ok=attAllowed(k),lv=myLv(),out=[];
 for(const s in sel){const a=sel[s];if(a&&ATTS[a]&&ATTS[a].s===s&&ok[s]&&ok[s].includes(a)&&lv>=ATTS[a].lv)out.push(a);}
 return out;
}
const ATT_NEUTRAL={dmg:1,rec:1,recH:1,adsSpr:1,hip:1,mob:1,ads:1,rng:1,rel:1,mag:1,snd:1,zoom:0,sil:0,noFlash:0};
function attModsOf(k,sel){
 const r=Object.assign({},ATT_NEUTRAL);
 for(const a of attList(k,sel)){const d=ATTS[a];for(const x in d.m){if(x==='zoom')r.zoom=d.m.zoom;else r[x]*=d.m[x];}if(d.sil)r.sil=1;if(d.noFlash)r.noFlash=1;}
 return r;
}
function attMods(e,k){return e&&e.isPlayer?attModsOf(k,cfg.att[k]||{}):ATT_NEUTRAL;}
const hasAtt=(e,k,a)=>attList(k,attSel(e,k)).includes(a);

/* ---------- profil de l'arme (hauteur du dessus / du dessous le long du canon) ---------- */
const GPROF={};
function gunProfile(g,k){
 const key=k+(g.userData.glb?'g':'p');if(GPROF[key])return GPROF[key];
 g.updateMatrixWorld(true);
 const inv=new THREE.Matrix4().copy(g.matrixWorld).invert(),v=new THREE.Vector3(),pts=[];
 g.traverse(o=>{if(!o.isMesh||!o.geometry||!o.geometry.attributes.position)return;
  const m=new THREE.Matrix4().multiplyMatrices(inv,o.matrixWorld),p=o.geometry.attributes.position,st=Math.max(1,Math.floor(p.count/4000));
  for(let i=0;i<p.count;i+=st){v.fromBufferAttribute(p,i).applyMatrix4(m);pts.push(v.x,v.y,v.z);}});
 let z0=1e9,z1=-1e9;for(let i=2;i<pts.length;i+=3){z0=Math.min(z0,pts[i]);z1=Math.max(z1,pts[i]);}
 const NB=48,top=new Array(NB).fill(-1e9),bot=new Array(NB).fill(1e9),bin=z=>clamp(Math.floor((z-z0)/(z1-z0+1e-6)*NB),0,NB-1);
 for(let i=0;i<pts.length;i+=3){const b=bin(pts[i+2]);top[b]=Math.max(top[b],pts[i+1]);bot[b]=Math.min(bot[b],pts[i+1]);}
 const at=(arr,z,f)=>{let b=bin(z),r=arr[b];for(let d=1;!isFinite(r)||Math.abs(r)>1e8;d++){if(d>NB)return 0;r=arr[clamp(b-d,0,NB-1)];if(Math.abs(r)>1e8)r=arr[clamp(b+d,0,NB-1)];}return r;};
 // hauteur de l'âme du canon : milieu de la section à la bouche
 const mz=g.userData.muzzle||z0,bore=(at(top,mz+.01)+at(bot,mz+.01))/2;
 return GPROF[key]={z0,z1,top:z=>at(top,z),bot:z=>at(bot,z),bore,
  topR:(za,zb)=>{let m=-1e9;for(let z=za;z<=zb;z+=.01)m=Math.max(m,at(top,z));return m;}};
}

/* ---------- modèles 3D des accessoires ---------- */
const AM={
 blk:new THREE.MeshStandardMaterial({color:C(0x17191d),roughness:.5,metalness:.75}),
 dark:new THREE.MeshStandardMaterial({color:C(0x2b3037),roughness:.45,metalness:.7}),
 tan:new THREE.MeshStandardMaterial({color:C(0x6b6150),roughness:.7,metalness:.2}),
 rub:new THREE.MeshStandardMaterial({color:C(0x101114),roughness:.9,metalness:0}),
 lensB:new THREE.MeshBasicMaterial({color:0x7fd8ff,transparent:true,opacity:.12,depthWrite:false,side:THREE.DoubleSide}),
 red:new THREE.MeshBasicMaterial({color:0xff2030,toneMapped:false}),
 beam:new THREE.MeshBasicMaterial({color:0xff2030,transparent:true,opacity:.55,blending:THREE.AdditiveBlending,depthWrite:false,toneMapped:false}),
 tape:new THREE.MeshStandardMaterial({color:C(0x2d2d24),roughness:1,metalness:0})
};
const cylZ=(r1,r2,l,mat,x,y,z,seg,open)=>{const m=new THREE.Mesh(new THREE.CylinderGeometry(r1,r2,l,seg||16,1,!!open),mat);m.rotation.x=Math.PI/2;m.position.set(x,y,z);return m;};
const boxA=(w,h,d,mat,x,y,z)=>{const m=new THREE.Mesh(new THREE.BoxGeometry(w,h,d),mat);m.position.set(x,y,z);return m;};
function ringReticle(r){
 const cv=document.createElement('canvas');cv.width=cv.height=128;const c=cv.getContext('2d');
 c.strokeStyle='#ff2a3a';c.fillStyle='#ff2a3a';c.lineWidth=5;c.shadowColor='#ff2a3a';c.shadowBlur=8;
 c.beginPath();c.arc(64,64,44,0,Math.PI*2);c.stroke();c.beginPath();c.arc(64,64,5,0,Math.PI*2);c.fill();
 const m=new THREE.Mesh(new THREE.PlaneGeometry(r,r),new THREE.MeshBasicMaterial({map:new THREE.CanvasTexture(cv),transparent:true,depthWrite:false,toneMapped:false,side:THREE.DoubleSide}));return m;
}
function chevronReticle(r){
 const cv=document.createElement('canvas');cv.width=cv.height=128;const c=cv.getContext('2d');
 c.strokeStyle='#ff3a2a';c.lineWidth=5;c.shadowColor='#ff3a2a';c.shadowBlur=6;
 c.beginPath();c.moveTo(44,76);c.lineTo(64,56);c.lineTo(84,76);c.stroke();
 c.strokeStyle='#111';c.lineWidth=3;c.shadowBlur=0;c.beginPath();c.moveTo(64,62);c.lineTo(64,120);c.moveTo(4,64);c.lineTo(40,64);c.moveTo(88,64);c.lineTo(124,64);c.stroke();
 return new THREE.Mesh(new THREE.PlaneGeometry(r,r),new THREE.MeshBasicMaterial({map:new THREE.CanvasTexture(cv),transparent:true,depthWrite:false,toneMapped:false,side:THREE.DoubleSide}));
}
// pose les accessoires sur l'arme g ; met à jour userData (bouche, ligne de visée, main gauche…)
function attBuild(g,k,sel,opt){
 opt=opt||{};
 const u=g.userData,w=W[k];if(!w||w.melee||w.wonder)return [];
 const list=attList(k,sel||{});if(!list.length)return list;
 const pr=gunProfile(g,k),pistol=w.cat==='pistol',S=pistol?.7:1,bore=pr.bore;
 u.att=list;
 const add=(o,tag)=>{o.userData.att=tag;g.add(o);return o;};
 for(const a of list){
  switch(a){
   case 'sil':{const L=pistol?.13:.19,r=pistol?.017:.022,z=u.muzzle-L/2+.01;const o=new THREE.Group();
    o.add(cylZ(r,r,L,AM.blk,0,0,0,20));o.add(cylZ(r*1.08,r*1.08,.012,AM.dark,0,0,-L/2+.006,20));o.add(cylZ(r*1.08,r*1.08,.012,AM.dark,0,0,L/2-.006,20));
    for(let i=0;i<3;i++)o.add(cylZ(r*1.03,r*1.03,.004,AM.dark,0,0,-L/4+i*L/4,20));
    o.position.set(0,bore,z);add(o,a);u.muzzle-=L-.01;break;}
   case 'comp':{const L=.05*S,r=.016*S,o=new THREE.Group();o.add(cylZ(r,r,L,AM.dark,0,0,0,14));
    for(let i=0;i<3;i++)o.add(boxA(r*.9,.004,.006,AM.blk,0,r*.95,-L/2+.01+i*.014));
    o.position.set(0,bore,u.muzzle-L/2+.005);add(o,a);u.muzzle-=L-.005;break;}
   case 'brake':{const L=.065*S,r=.019*S,o=new THREE.Group();o.add(boxA(r*2.2,r*1.6,L,AM.dark,0,0,0));
    for(let i=0;i<3;i++){o.add(boxA(r*2.4,r*.5,.008,AM.blk,0,0,-L/2+.012+i*.018));}
    o.position.set(0,bore,u.muzzle-L/2+.005);add(o,a);u.muzzle-=L-.005;break;}
   case 'flash':{const L=.045*S,r=.014*S,o=new THREE.Group();o.add(cylZ(r,r*.9,L*.5,AM.blk,0,0,L*.25,12));
    for(let i=0;i<4;i++){const an=i*Math.PI/2+Math.PI/4,p=boxA(.005,.005,L*.6,AM.blk,Math.cos(an)*r*.8,Math.sin(an)*r*.8,-L*.2);o.add(p);}
    o.position.set(0,bore,u.muzzle-L/2+.005);add(o,a);u.muzzle-=L-.005;break;}
   case 'reddot':{const z=clamp(u.muzzle*.28,-.2,-.03);const o=redDot({sight:pr.topR(z-.04,z+.04)-.002});o.position.z=z+.15;o.userData.att=a;g.add(o);   // redDot() construit à z=-.15 : recalé sur le rail
    u.sight=pr.topR(z-.04,z+.04)-.002+.034;u.optic=a;break;}
   case 'holo':{const z=clamp(u.muzzle*.3,-.22,-.05),base=pr.topR(z-.05,z+.05),o=new THREE.Group(),h=.04,cy=base+.026;
    o.add(boxA(.034,.012,.085,AM.dark,0,base+.006,z));
    // cadre ouvert (fenêtre rectangulaire)
    o.add(boxA(.005,h,.05,AM.blk,-.02,cy+.003,z),boxA(.005,h,.05,AM.blk,.02,cy+.003,z),boxA(.045,.006,.054,AM.blk,0,cy+h/2+.003,z));
    o.add(boxA(.045,.006,.034,AM.dark,0,base+.012,z+.016));
    const lens=new THREE.Mesh(new THREE.PlaneGeometry(.035,.034),AM.lensB);lens.position.set(0,cy,z-.023);o.add(lens);
    const ret=ringReticle(.017);ret.position.set(0,cy,z-.024);o.add(ret);
    add(o,a);u.sight=cy;u.optic=a;break;}
   case 'acog':{const z=clamp(u.muzzle*.3,-.24,-.06),base=pr.topR(z-.06,z+.06),o=new THREE.Group(),r=.021,cy=base+.036;
    o.add(boxA(.028,.016,.07,AM.dark,0,base+.008,z));
    o.add(cylZ(r,r,.12,new THREE.MeshStandardMaterial({color:C(0x1a1c20),roughness:.5,metalness:.7,side:THREE.DoubleSide}),0,cy,z,22,true));
    o.add(cylZ(r*1.25,r,.03,AM.blk,0,cy,z-.07,22,true),cylZ(r,r*1.15,.02,AM.blk,0,cy,z+.065,22,true));
    o.add(boxA(.014,.014,.02,AM.blk,0,cy+r+.004,z),boxA(.014,.014,.02,AM.blk,r+.004,cy,z));
    const lens=new THREE.Mesh(new THREE.CircleGeometry(r*.95,22),AM.lensB);lens.position.set(0,cy,z-.05);o.add(lens);
    const ret=chevronReticle(.022);ret.position.set(0,cy,z-.051);o.add(ret);
    add(o,a);u.sight=cy;u.optic=a;break;}
   case 'long':{const L=.09*S,r=.012*S,o=new THREE.Group();o.add(cylZ(r,r,L,AM.blk,0,0,0,14));o.add(cylZ(r*1.5,r*1.5,.025,AM.dark,0,0,L/2-.012,14));
    o.position.set(0,bore,u.muzzle-L/2+.005);add(o,a);u.muzzle-=L-.005;break;}
   case 'heavy':{const L=.07*S,r=.016*S,o=new THREE.Group();o.add(cylZ(r,r,L,AM.dark,0,0,0,14));
    for(let i=0;i<4;i++)o.add(cylZ(r*1.15,r*1.15,.006,AM.blk,0,0,-L/2+.01+i*.016,14));
    o.position.set(0,bore,u.muzzle-L/2+.005);add(o,a);u.muzzle-=L-.005;break;}
   case 'grip':{const z=u.left?u.left.z:-.25,b=pr.bot(z),o=new THREE.Group();
    o.add(boxA(.022,.012,.04,AM.dark,0,b-.004,z),cylZ(.012,.012,.075,AM.rub,0,b-.045,z,12));o.children[1].rotation.x=0;
    add(o,a);u.left=V3(u.left?u.left.x:0,b-.05,z);break;}
   case 'angled':{const z=u.left?u.left.z:-.25,b=pr.bot(z),o=new THREE.Group();
    const p=boxA(.02,.03,.07,AM.dark,0,b-.016,z+.005);p.rotation.x=-.5;o.add(p);o.add(boxA(.022,.008,.075,AM.blk,0,b-.002,z));
    add(o,a);u.left=V3(u.left?u.left.x:0,b-.03,z+.01);break;}
   case 'laser':{const z=pistol?clamp(u.muzzle*.55,-.12,-.03):(u.left?u.left.z-.06:-.3),b=pistol?pr.bot(z):(pr.top(z)+pr.bot(z))/2,x=pistol?0:.024,o=new THREE.Group();
    o.add(boxA(pistol?.022:.016,pistol?.018:.022,pistol?.045:.06,AM.blk,x,pistol?b-.01:b,z));
    const dot=new THREE.Mesh(new THREE.CircleGeometry(.004,10),AM.red);dot.position.set(x,pistol?b-.01:b,z-(pistol?.023:.031));dot.rotation.y=Math.PI;o.add(dot);
    const BL=opt.preview?.3:6,beam=cylZ(.0012,.0012,BL,AM.beam,x,pistol?b-.01:b,z-.03-BL/2,4);beam.userData.beam=1;o.add(beam);u.laser=beam;
    add(o,a);break;}
   case 'ext':{if(u.mag){u.mag.scale.y*=1.28;u.mag.userData.extMag=1;}else{const z=u.left?u.left.z*.4:-.08;add(boxA(.022,.06,.035,AM.dark,0,pr.bot(z)-.03,z),a);}break;}
   case 'fast':{if(u.mag){const tw=u.mag.clone(true);tw.position.x+=.03;tw.position.y+=.012;tw.userData.att=a;(u.mag.parent||g).add(tw);
     // bande adhésive entre les deux chargeurs
     const bb=new THREE.Box3().setFromObject(u.mag),c=bb.getCenter(new THREE.Vector3());g.worldToLocal(c);
     add(boxA(.05,.018,.04,AM.tape,c.x+.015,c.y,c.z),a);u.twinMag=tw;}break;}
   case 'light':case 'tac':{if(pistol)break;const z=pr.z1-.012,t=pr.top(z),b=pr.bot(z),y=(t+b)/2,o=new THREE.Group(),stocked=pr.z1>.12;
    // arme qui a déjà une crosse : on habille la crosse existante (plaque de couche, busc, anneau de sangle)
    if(stocked){
     if(a==='tac'){o.add(boxA(.036,Math.max(.05,t-b+.01),.028,AM.rub,0,y,pr.z1+.012));o.add(boxA(.028,.02,.09,AM.tape,0,pr.top(pr.z1-.08)+.008,pr.z1-.07));}
     else{o.add(boxA(.03,.016,.07,new THREE.MeshStandardMaterial({color:C(0x8a7a5a),roughness:.8}),0,pr.top(pr.z1-.07)+.006,pr.z1-.06));const r=new THREE.Mesh(new THREE.TorusGeometry(.012,.003,6,12),AM.blk);r.position.set(.02,b+.01,pr.z1-.05);r.rotation.y=Math.PI/2;o.add(r);}
    }else if(a==='light'){o.add(boxA(.008,.008,.16,AM.blk,0,y+.02,z+.08),boxA(.008,.008,.17,AM.blk,0,y-.035,z+.085),boxA(.01,.075,.012,AM.blk,0,y-.006,z+.165),boxA(.014,.08,.02,AM.rub,0,y-.006,z+.18));}
    else{o.add(boxA(.03,.05,.14,AM.dark,0,y,z+.07),boxA(.034,.085,.03,AM.rub,0,y-.01,z+.15),boxA(.026,.012,.09,AM.blk,0,y+.03,z+.07));}
    add(o,a);break;}
  }
 }
 const m=attModsOf(k,sel||{});u.noFlash=m.noFlash;u.sil=m.sil;
 return list;
}

/* ---------- interface de l'armurier (onglet Arsenal) ---------- */
let gsPrev=null,gsSlot='muzzle';
function gsSel(k){return gsPrev||cfg.att[k]||{};}
function gsCount(sel){return Object.values(sel).filter(Boolean).length;}
function gsStatsHTML(k){
 const w=W[k];if(!w||w.melee)return null;
 const base=attModsOf(k,{}),cur=attModsOf(k,cfg.att[k]||{}),nw=attModsOf(k,gsSel(k));
 const rows=[
  ['DÉGÂTS',m=>w.dmg*(w.pel||1)*m.dmg,150,v=>Math.round(v)+(w.pel?'×':''),1],
  ['CADENCE',m=>w.rpm,1000,v=>Math.round(v),1],
  ['CHARGEUR',m=>Math.ceil(w.mag*m.mag),150,v=>v,1],
  ['PRÉCISION',m=>clamp(100-w.spr*14*m.hip,0,100),100,v=>Math.round(v)+'%',1],
  ['VISÉE',m=>clamp(100-(w.spr*14*m.adsSpr*.6)-(1-m.ads)*30-(w.overlay?15:0),0,100),100,v=>Math.round(v)+'%',1],
  ['CONTRÔLE',m=>clamp(100-w.rec*40*(m.rec*.7+m.recH*.3),0,100),100,v=>Math.round(v)+'%',1],
  ['PORTÉE',m=>(w.fo||40)*m.rng*1.2,120,v=>Math.round(v)+' m',1],
  ['MOBILITÉ',m=>RUN*w.spd*m.mob,6.5,v=>v.toFixed(1)+' m/s',1],
  ['RECHARGEMENT',m=>w.rel*m.rel,5,v=>v.toFixed(1)+' s',-1],
  ['PRIX',m=>w.price,5200,v=>'$'+v,0]
 ];
 return rows.map(([l,f,mx,fmt,dir])=>{
  const v0=f(cur),v1=f(nw),diff=v1-v0,good=dir&&Math.abs(diff)>1e-6?(diff*dir>0):null;
  const a=clamp(Math.min(v0,v1)/mx*100,2,100),b=clamp(Math.max(v0,v1)/mx*100,2,100);
  const col=good===null?'':good?'#5dff8a':'#ff5a5a';
  return '<div class="stat1"><em>'+l+'</em><b'+(col?' style="color:'+col+'"':'')+'>'+fmt(v1)+(good!==null?(good?' ▲':' ▼'):'')+'</b><div class="bar" style="position:relative"><i style="width:'+a+'%"></i>'+
   (good!==null?'<i style="position:absolute;left:'+a+'%;top:0;bottom:0;width:'+(b-a)+'%;background:'+col+'"></i>':'')+'</div></div>';
 }).join('');
}
function gsCss(){
 if($('gsCss'))return;const s=document.createElement('style');s.id='gsCss';
 s.textContent='#gsPanel{margin-top:10px;padding:10px;border:1px solid #ffffff1a;border-radius:10px;background:#0b1220cc;text-align:left}'+
 '#gsPanel h4{margin:0 0 8px;font-size:.72rem;letter-spacing:3px;color:#ff9a3c;display:flex;justify-content:space-between;align-items:center}'+
 '#gsPanel h4 small{color:#8fa3c0;letter-spacing:1px;font-size:.66rem}'+
 '.gsSlots{display:grid;grid-template-columns:repeat(6,1fr);gap:6px}'+
 '.gsSlot{padding:7px 6px;border:1px solid #ffffff22;border-radius:8px;background:#121b2b;cursor:pointer;min-height:48px;transition:.15s}'+
 '.gsSlot:hover{border-color:#ff9a3c88}.gsSlot.on{border-color:#ff9a3c;box-shadow:0 0 0 1px #ff9a3c inset;background:#1d1a17}'+
 '.gsSlot.off{opacity:.3;cursor:not-allowed}.gsSlot em{display:block;font-style:normal;font-size:.58rem;letter-spacing:2px;color:#8fa3c0}'+
 '.gsSlot b{display:block;font-size:.72rem;color:#fff;margin-top:3px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.gsSlot.has b{color:#ffb35c}'+
 '.gsOpts{display:flex;gap:6px;flex-wrap:wrap;margin-top:8px}'+
 '.gsOpt{flex:1 1 150px;padding:8px 9px;border:1px solid #ffffff22;border-radius:8px;background:#121b2b;cursor:pointer;font-size:.74rem;color:#dfe8f5}'+
 '.gsOpt:hover{border-color:#ff9a3c}.gsOpt.on{border-color:#5dff8a;background:#142619}.gsOpt.lock{opacity:.4;cursor:not-allowed}'+
 '.gsOpt small{display:block;color:#8fa3c0;font-size:.62rem;margin-top:3px;line-height:1.3}'+
 '#pvStats{display:grid!important;grid-template-columns:repeat(5,1fr);gap:6px}'+
 '@media(max-width:900px){.gsSlots{grid-template-columns:repeat(3,1fr)}#pvStats{grid-template-columns:repeat(2,1fr)}}';
 document.head.appendChild(s);
}
function gsDraw(){
 const k=pvKey,host=$('gsPanel');if(!host)return;
 const ok=attAllowed(k),sel=cfg.att[k]||{},lv=myLv();
 if(!Object.keys(ok).length){host.innerHTML='<h4>ARMURIER</h4><small style="color:#8fa3c0">Pas d\'accessoires pour cette arme.</small>';return;}
 if(!ok[gsSlot])gsSlot=Object.keys(ok)[0];
 const n=gsCount(sel);
 let h='<h4>ARMURIER <small>'+n+' / '+ATT_MAX+' accessoires · survole pour comparer, clique pour équiper</small></h4><div class="gsSlots">';
 for(const s of ATT_SLOTS){const a=sel[s.id],has=a&&ATTS[a];
  h+='<div class="gsSlot'+(ok[s.id]?'':' off')+(gsSlot===s.id?' on':'')+(has?' has':'')+'" data-s="'+s.id+'"><em>'+s.ic+' '+s.n.toUpperCase()+'</em><b>'+(has?ATTS[a].n:ok[s.id]?'—':'Indisponible')+'</b></div>';}
 h+='</div><div class="gsOpts">';
 const cur=sel[gsSlot];
 h+='<div class="gsOpt'+(!cur?' on':'')+'" data-a=""><b>Aucun</b><small>Retirer l\'accessoire</small></div>';
 for(const a of ok[gsSlot]||[]){const d=ATTS[a],lock=lv<d.lv;
  h+='<div class="gsOpt'+(cur===a?' on':'')+(lock?' lock':'')+'" data-a="'+a+'"><b>'+d.n+(lock?' 🔒':'')+'</b><small>'+(lock?'Débloqué au niveau '+d.lv+'. ':'')+d.d+'</small></div>';}
 h+='</div>';host.innerHTML=h;
 host.querySelectorAll('.gsSlot').forEach(el=>el.onclick=()=>{if(el.classList.contains('off'))return;sfxUI();gsSlot=el.dataset.s;gsDraw();});
 host.querySelectorAll('.gsOpt').forEach(el=>{
  const a=el.dataset.a,lock=el.classList.contains('lock');
  const trial=()=>{const s=Object.assign({},cfg.att[k]||{});if(a)s[gsSlot]=a;else delete s[gsSlot];return s;};
  el.onmouseenter=()=>{if(lock)return;gsPrev=trial();pvSet(k);gsStats();};
  el.onmouseleave=()=>{if(!gsPrev)return;gsPrev=null;pvSet(k);gsStats();};
  el.onclick=()=>{
   if(lock){sfxUI();uiToast('Débloqué au niveau '+ATTS[a].lv);return;}
   const s=trial();
   if(gsCount(s)>ATT_MAX){sfxUI();uiToast('Maximum '+ATT_MAX+' accessoires : retire-en un d\'abord');return;}
   cfg.att[k]=s;saveCfg();gsPrev=null;sfx('reload',undefined,undefined,.35);pvSet(k);gsDraw();gsStats();
   if(typeof VM!=='undefined')VM.gk=null; // force la reconstruction de l'arme en main
  };
 });
}
function gsStats(){const k=pvKey,el=$('pvStats');if(!el||!W[k])return;const h=gsStatsHTML(k);if(h)el.innerHTML=h;}
function gsUi(){
 gsCss();
 if($('gsPanel'))return;
 const st=$('pvStats');if(!st)return;
 const p=document.createElement('div');p.id='gsPanel';st.parentNode.insertBefore(p,st.nextSibling);
}
