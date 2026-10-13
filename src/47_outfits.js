/* =====================================================================
   TENUES DE SOLDAT : 14 tenues (matières, coiffes et accessoires uniques)
   ===================================================================== */
const OUTFITS=[
 {n:'Équipe',def:1,q:0},
 {n:'Opérateur nocturne',q:0,shirt:['solid','#2a2d33'],pants:['solid','#24272c'],vest:'#16181c',helm:'#1b1d22',glove:'#101114',boot:'#0e0f11',acc:'#35d6ff',head:'helm'},
 {n:'Ranger forêt',q:0,shirt:['camo','#55692f','#3a4b22','#7a8a45'],pants:['camo','#4b5f2a','#334420','#6c7c3d'],vest:'#3c4a2a',helm:'#3a4a2a',glove:'#2a3320',boot:'#3a2a1a',acc:'#ffd24a',head:'helm'},
 {n:'Patrouille polaire',q:0,shirt:['camo','#e8eef6','#c4d2e4','#ffffff'],pants:['camo','#dfe7f2','#b8c8dc','#ffffff'],vest:'#aebdd0',helm:'#eef3fa',glove:'#cfd9e6',boot:'#8a99ad',acc:'#4aa3ff',head:'hood'},
 {n:'Urbain',q:1,shirt:['digital','#5c6672','#3a424c','#7c8896'],pants:['digital','#4a525c','#2e353d','#6a7684'],vest:'#2a2f36',helm:'#2f353d',glove:'#15181d',boot:'#15171a',acc:'#ff8a2a',head:'cap'},
 {n:'Pilote de course',q:1,shirt:['stripes','#d41a28','#f4f4f4'],pants:['solid','#1a1a1f'],vest:'#d41a28',helm:'#f4f4f4',glove:'#f4f4f4',boot:'#d41a28',acc:'#ffd23a',head:'cap'},
 {n:'Pirate',q:1,shirt:['stripes','#f2f2f2','#1a1d2a'],pants:['solid','#5a3a22'],vest:'#6a3e22',helm:'#c4261c',glove:'#3a2412',boot:'#2a1a0e',acc:'#ffd24a',head:'bandana'},
 {n:'Chef étoilé',q:1,shirt:['solid','#f6f6f6'],pants:['stripes','#2a2e38','#3a3f4c'],vest:'#dedede',helm:'#ffffff',glove:'#ffffff',boot:'#1a1a1a',acc:'#e0402a',head:'toque'},
 {n:'Samouraï',q:2,shirt:['solid','#a8141c'],pants:['solid','#1c1417'],vest:'#2a1014',helm:'#8a0f16',glove:'#14100f',boot:'#14100f',acc:'#ffd24a',head:'horns',metal:true},
 {n:'Cyber néon',q:2,shirt:['solid','#171a26'],pants:['solid','#12151e'],vest:'#0d0f18',helm:'#0d0f18',glove:'#0d0f18',boot:'#0d0f18',acc:'#35f0ff',glow:true,head:'visor'},
 {n:'Astronaute',q:2,shirt:['solid','#f2f4f8'],pants:['solid','#e6e9f0'],vest:'#ffffff',helm:'#f2f4f8',glove:'#ff8a2a',boot:'#cfd4de',acc:'#ff8a2a',head:'bubble'},
 {n:'Roi doré',q:3,shirt:['solid','#d8a028'],pants:['solid','#7a1c2a'],vest:'#f0c040',helm:'#f0c040',glove:'#f6dc7a',boot:'#7a1c2a',acc:'#ffffff',head:'crown',metal:true},
 {n:'Licorne',q:3,shirt:['stripes','#ffb0d8','#b8e0ff'],pants:['stripes','#d0b8ff','#ffe0b0'],vest:'#ffffff',helm:'#ffd0ec',glove:'#ffffff',boot:'#ffb0d8',acc:'#ff6ad5',glow:true,head:'unicorn'},
 {n:'Robot chrome',q:3,shirt:['solid','#aab4c2'],pants:['solid','#8e98a6'],vest:'#c8d0dc',helm:'#d8dfe9',glove:'#6a7482',boot:'#6a7482',acc:'#ff3b3b',glow:true,head:'robot',metal:true}
];
const outfitSwatch=i=>{const o=OUTFITS[i];return o.def?'linear-gradient(135deg,#ff7a4a 50%,#4aa3ff 50%)':'linear-gradient(135deg,'+o.shirt[1]+' 40%,'+o.acc+' 41% 60%,'+o.vest+' 61%)';};
function outTex(spec){
 const kind=spec[0];
 return cached('ot_'+spec.join(),()=>canvasTex(128,128,(c,w,h)=>{
  const r=mkRng(hashStr(spec.join()));
  if(kind==='camo'||kind==='digital'){
   c.fillStyle=spec[1];c.fillRect(0,0,w,h);
   if(kind==='camo'){for(let L=2;L<spec.length;L++)for(let i=0;i<26;i++)blob(c,r(0,w),r(0,h),r(8,20),r(5,13),r(0,3),spec[L]);}
   else{for(let y=0;y<h;y+=8)for(let x=0;x<w;x+=8){c.fillStyle=spec[1+Math.floor(r(0,spec.length-1))];c.fillRect(x,y,8,8);}}
  }else{ // stripes
   c.fillStyle=spec[1];c.fillRect(0,0,w,h);c.fillStyle=spec[2];for(let y=0;y<h;y+=32)c.fillRect(0,y,w,16);
  }
  for(let i=0;i<60;i++){c.fillStyle='rgba(0,0,0,'+r(.03,.1)+')';c.fillRect(r(0,w),r(0,h),r(1,6),1);}
 },true));
}
const OUTM={};
function outfitMats(look){
 const key='o'+look.outfit+'|'+look.tone;if(OUTM[key])return OUTM[key];
 const O=OUTFITS[look.outfit],L={},met=O.metal?{metalness:.85,roughness:.28}:{metalness:0,roughness:.85};
 const spec=(s,rep)=>{if(s[0]==='solid')return new THREE.MeshStandardMaterial(Object.assign({color:C(s[1])},met));const t=outTex(s).clone();t.needsUpdate=true;t.repeat.set(rep||2,rep||2);return new THREE.MeshStandardMaterial({map:t,roughness:.88,metalness:0});};
 L.skin=new THREE.MeshStandardMaterial({color:C(look.tone),roughness:.75});
 L.shirt=spec(O.shirt);L.pants=spec(O.pants);
 L.vest=new THREE.MeshStandardMaterial(Object.assign({color:C(O.vest)},O.metal?{metalness:.8,roughness:.3}:{metalness:.05,roughness:.7}));
 L.helm=new THREE.MeshStandardMaterial(Object.assign({color:C(O.helm)},O.metal?{metalness:.9,roughness:.22}:{metalness:.1,roughness:.55}));
 L.glove=new THREE.MeshStandardMaterial({color:C(O.glove),roughness:.7,metalness:O.metal?.5:0});
 L.boot=new THREE.MeshStandardMaterial({color:C(O.boot),roughness:.65,metalness:O.metal?.5:0});
 L.accent=new THREE.MeshStandardMaterial({color:C(O.acc),roughness:.4,emissive:C(O.acc),emissiveIntensity:O.glow?1.6:.25});
 L.dark=new THREE.MeshStandardMaterial({color:C(0x1b1d22),roughness:.6,metalness:.3});
 L.lens=new THREE.MeshStandardMaterial({color:C(0x0a0c10),roughness:.08,metalness:.9});
 L.blk=new THREE.MeshStandardMaterial({color:C(0x16171a),roughness:.7});
 L.gold=new THREE.MeshStandardMaterial({color:C(0xf3c040),roughness:.2,metalness:1});
 L.glass=new THREE.MeshStandardMaterial({color:C(0x9ad0ff),roughness:.04,metalness:.3,transparent:true,opacity:.32,envMapIntensity:1.6});
 return OUTM[key]=L;
}
const ball=(g,m,x,y,z,sx,sy,sz)=>{const o=new THREE.Mesh(g,m);o.position.set(x,y,z);o.scale.set(sx,sy,sz);return o;};
function buildOutfitHead(R,M,O){
 const H=R.head,S=(a,b,c,d,e)=>new THREE.SphereGeometry(1,20,12,a||0,b===undefined?TAU:b,c||0,d===undefined?Math.PI:d);
 const shell=(mat,sx,sy,sz,y,z,th)=>{const m=new THREE.Mesh(S(0,TAU,0,th||Math.PI*.58),mat);m.scale.set(sx,sy,sz);m.position.set(0,y,z||0);H.add(m);return m;};
 switch(O.head){
  case 'helm':shell(M.helm,.142,.13,.158,.015,.006);H.add(rb(.3,.012,.1,M.helm,0,.01,-.14,.004,.05),rb(.02,.05,.03,M.accent,0,.095,-.1,.006),rb(.19,.04,.05,M.lens,0,.028,-.115,.01),rb(.03,.1,.034,M.dark,-.14,-.03,.02,.008),rb(.03,.1,.034,M.dark,.14,-.03,.02,.008));break;
  case 'cap':shell(M.helm,.128,.095,.14,.07,.0,Math.PI*.5);H.add(rb(.15,.012,.1,M.helm,0,.045,-.14,.004,.12),rb(.03,.03,.012,M.accent,0,.105,-.13,.004));H.add(ball(S(),M.dark,0,-.065,.0,.11,.04,.12));break;
  case 'hood':{const m=new THREE.Mesh(new THREE.SphereGeometry(1,20,14,Math.PI*.58,Math.PI*.84,0,Math.PI*.9),M.helm);m.scale.set(.158,.16,.17);m.position.set(0,-.005,.02);H.add(m);const tri=rb(.2,.05,.03,M.helm,0,.1,-.115,.012);H.add(tri,rb(.22,.03,.03,M.accent,0,.085,-.12,.008));break;}
  case 'bandana':shell(M.helm,.134,.1,.145,.065,.003,Math.PI*.46);H.add(rb(.27,.04,.25,M.helm,0,.03,0,.01),rb(.06,.07,.04,M.helm,.0,.0,.14,.01),rb(.04,.08,.03,M.helm,.04,-.04,.15,.01,.2));H.add(rb(.016,.016,.016,M.accent,.03,.02,-.12,.003));break;
  case 'toque':{const c=new THREE.Mesh(new THREE.CylinderGeometry(.105,.095,.13,16),M.helm);c.position.set(0,.13,0);H.add(c);const t=ball(S(),M.helm,0,.255,0,.125,.09,.125);H.add(t);H.add(rb(.22,.026,.2,M.accent,0,.07,0,.01));break;}
  case 'horns':{shell(M.helm,.14,.122,.155,.02,.006,Math.PI*.55);H.add(rb(.3,.012,.1,M.helm,0,.0,-.14,.004,.05),rb(.2,.07,.03,M.dark,0,-.05,-.125,.012),rb(.02,.1,.2,M.accent,0,.14,0,.006));
   for(const s of [-1,1]){const h=new THREE.Mesh(new THREE.ConeGeometry(.026,.2,10),M.accent);h.position.set(s*.12,.15,-.04);h.rotation.z=-s*.5;H.add(h);}break;}
  case 'visor':shell(M.helm,.14,.12,.155,.015,.006,Math.PI*.55);H.add(rb(.22,.05,.05,M.accent,0,.028,-.118,.012),rb(.016,.07,.016,M.accent,-.14,.0,.02,.004),rb(.016,.07,.016,M.accent,.14,.0,.02,.004),rb(.02,.02,.2,M.accent,0,.14,0,.006));break;
  case 'bubble':{const b=new THREE.Mesh(S(),M.glass);b.scale.set(.19,.19,.2);b.position.set(0,.01,0);H.add(b);H.add(rb(.3,.04,.28,M.vest,0,-.14,0,.014),rb(.02,.02,.02,M.accent,.0,-.12,-.15,.004));const an=new THREE.Mesh(new THREE.CylinderGeometry(.006,.006,.12,6),M.dark);an.position.set(.12,.2,0);H.add(an);break;}
  case 'crown':{H.add(rb(.19,.04,.17,M.gold,0,.115,0,.01));for(let i=0;i<5;i++){const a=i/5*TAU,sp=new THREE.Mesh(new THREE.ConeGeometry(.025,.07,8),M.gold);sp.position.set(Math.cos(a)*.085,.17,Math.sin(a)*.08);H.add(sp);const gem=new THREE.Mesh(new THREE.SphereGeometry(.014,8,6),M.accent);gem.position.set(Math.cos(a)*.085,.215,Math.sin(a)*.08);H.add(gem);}H.add(ball(S(),M.helm,0,-.03,.0,.115,.04,.1));break;}
  case 'unicorn':{shell(M.helm,.138,.12,.15,.02,.004,Math.PI*.55);const hn=new THREE.Mesh(new THREE.ConeGeometry(.032,.22,10),M.gold);hn.position.set(0,.2,-.05);hn.rotation.x=-.25;H.add(hn);
   const cols=['#ff6ad5','#ffd23a','#6af0b0','#6ab8ff','#b36bff'];cols.forEach((cl,i)=>{const m=rb(.05,.05,.06,new THREE.MeshStandardMaterial({color:C(cl),roughness:.5,emissive:C(cl),emissiveIntensity:.25}),0,.1-i*.045,.14+i*.012,.012);H.add(m);});
   for(const s of [-1,1]){const e=new THREE.Mesh(new THREE.ConeGeometry(.026,.07,6),M.helm);e.position.set(s*.075,.15,0);e.rotation.z=-s*.2;H.add(e);}break;}
  case 'robot':{H.add(rb(.23,.22,.06,M.helm,0,.0,-.1,.02));H.add(rb(.2,.07,.05,M.dark,0,.025,-.13,.01),rb(.034,.034,.03,M.accent,-.05,.025,-.16,.006),rb(.034,.034,.03,M.accent,.05,.025,-.16,.006),rb(.12,.014,.03,M.accent,0,-.05,-.13,.004));
   const an=new THREE.Mesh(new THREE.CylinderGeometry(.007,.007,.14,6),M.dark);an.position.set(.07,.17,0);H.add(an);const bl=ball(S(),M.accent,.07,.25,0,.02,.02,.02);H.add(bl);shell(M.helm,.138,.11,.15,.03,.006,Math.PI*.5);break;}
 }
}
