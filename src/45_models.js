/* =====================================================================
   MODÈLES : armes détaillées (silhouettes extrudées, matériaux PBR),
   skins, soldats animés (squelette + IK des bras), viewmodel
   ===================================================================== */
function woodTex(){return cached('wood',()=>canvasTex(128,64,(c,w,h)=>{
 c.fillStyle='#7a4a24';c.fillRect(0,0,w,h);
 for(let y=0;y<h;y+=2){c.fillStyle='rgba('+(Math.random()<.5?'40,20,6':'200,130,70')+','+rand(.05,.22)+')';c.fillRect(0,y,w,1+Math.random()*2);}
 for(let i=0;i<6;i++){c.strokeStyle='rgba(30,14,4,.35)';c.beginPath();c.ellipse(rand(0,w),rand(0,h),rand(8,20),rand(2,5),0,0,TAU);c.stroke();}
},true));}

/* ---------- géométries partagées ---------- */
const RBC={},CYC={};
function rbGeo(w,h,d,r){
 r=Math.max(.0005,Math.min(r,w/2-1e-4,h/2-1e-4,d/2-1e-4));
 const key=w.toFixed(4)+'_'+h.toFixed(4)+'_'+d.toFixed(4)+'_'+r.toFixed(4);
 if(RBC[key])return RBC[key];
 const sw=w-2*r,sh=h-2*r,sd=Math.max(d-2*r,1e-4);
 const s=new THREE.Shape();s.moveTo(-sw/2,-sh/2);s.lineTo(sw/2,-sh/2);s.lineTo(sw/2,sh/2);s.lineTo(-sw/2,sh/2);s.closePath();
 const g=new THREE.ExtrudeGeometry(s,{depth:sd,bevelEnabled:true,bevelThickness:r,bevelSize:r,bevelSegments:2,curveSegments:2});
 g.translate(0,0,-sd/2);g.computeVertexNormals();return RBC[key]=g;
}
function rb(w,h,d,mat,x,y,z,r,rx,ry,rz){
 const m=new THREE.Mesh(rbGeo(w,h,d,r===undefined?Math.min(w,h,d)*.28:r),mat);
 m.position.set(x||0,y||0,z||0);if(rx||ry||rz)m.rotation.set(rx||0,ry||0,rz||0);return m;
}
// cylindre le long de Z : rF = rayon avant (-z), rB = rayon arrière (+z)
function czGeo(rF,rB,len,seg){const key=rF+'_'+rB+'_'+len+'_'+seg;if(CYC[key])return CYC[key];const g=new THREE.CylinderGeometry(rB,rF,len,seg||14);g.rotateX(Math.PI/2);return CYC[key]=g;}
function cz(rF,rB,len,mat,x,y,z,seg){const m=new THREE.Mesh(czGeo(rF,rB,len,seg),mat);m.position.set(x||0,y||0,z||0);return m;}
// silhouette (z,y) extrudée sur x
function polyZY(pts,thick,mat,x,bevel){
 const s=new THREE.Shape();pts.forEach((p,i)=>i?s.lineTo(-p[0],p[1]):s.moveTo(-p[0],p[1]));s.closePath();
 const b=bevel===undefined?.0025:bevel;
 const g=new THREE.ExtrudeGeometry(s,{depth:Math.max(thick-2*b,1e-4),bevelEnabled:b>0,bevelThickness:b,bevelSize:b,bevelSegments:1,curveSegments:2});
 g.translate(0,0,-(thick-2*b)/2);g.rotateY(Math.PI/2);g.computeVertexNormals();
 const m=new THREE.Mesh(g,mat);m.position.x=x||0;return m;
}
const _gm={};
function gunMats(sk,w){
 const dflt=!sk||sk.def,M={};
 M.blk=new THREE.MeshStandardMaterial({color:C(0x17181b),roughness:.55,metalness:.3});
 M.steel=new THREE.MeshStandardMaterial({color:C(0xb4bcc6),roughness:.25,metalness:1});
 M.dark=new THREE.MeshStandardMaterial({color:C(0x24272c),roughness:.4,metalness:.85});
 M.rubber=new THREE.MeshStandardMaterial({color:C(0x101113),roughness:.9,metalness:0});
 M.glass=new THREE.MeshStandardMaterial({color:C(0x3a6fb0),roughness:.05,metalness:.2,emissive:C(0x1a3a66),emissiveIntensity:.5,transparent:true,opacity:.75});
 M.red=new THREE.MeshBasicMaterial({color:0xff2a2a,toneMapped:false});
 if(sk&&!dflt&&sk.tex){
  const fin=FIN[sk.fin||'gloss'],tc=skinTex(sk.tex,false).clone();tc.needsUpdate=true;
  const o={map:tc,roughness:fin.r,metalness:fin.m};
  if(sk.glow){const tg=skinTex(sk.tex,true).clone();tg.needsUpdate=true;o.emissiveMap=tg;o.emissive=C(sk.ge||'#ffffff');o.emissiveIntensity=sk.ei||1;}
  M.body=new THREE.MeshStandardMaterial(o);M.body.userData.skinned=true;
  {const ta=tc.clone();ta.needsUpdate=true;M.acc=new THREE.MeshStandardMaterial({map:ta,color:C(sk.tint||'#8c8c8c'),roughness:Math.min(1,fin.r+.1),metalness:fin.m});M.acc.userData.skinned=true;}M.wood=M.body;
 }
 else if(dflt){const base=new THREE.Color(w.col||0x3a3d44);M.body=new THREE.MeshStandardMaterial({color:base.clone().convertSRGBToLinear(),roughness:.38,metalness:.82});M.acc=new THREE.MeshStandardMaterial({color:base.clone().multiplyScalar(.5).convertSRGBToLinear(),roughness:.45,metalness:.8});
  const wt=woodTex().clone();wt.needsUpdate=true;wt.repeat.set(3,3);M.wood=new THREE.MeshStandardMaterial({map:wt,roughness:.55,metalness:0});}
 else{const fin=FIN[sk.fin||'matte'];M.body=new THREE.MeshStandardMaterial({color:C(sk.b),roughness:fin.r,metalness:fin.m});M.acc=new THREE.MeshStandardMaterial({color:C(sk.a),roughness:Math.min(1,fin.r+.1),metalness:fin.m});M.wood=M.acc;}
 return M;
}

/* ---------- armes : constructeurs ---------- */
function V3(x,y,z){return new THREE.Vector3(x,y,z);}
function finishGun(g,o){
 g.userData=Object.assign({len:.5,muzzle:-.4,right:V3(0,-.06,.01),left:V3(0,-.03,-.2),eject:V3(.03,.03,-.05),sight:.06,mag:null,slide:null,bolt:null,pump:null,twoHand:true},o);
 return g;
}
function buildPistol(k,M){
 const g=new THREE.Group(),slide=new THREE.Group(),mag=new THREE.Group();
 const dg=k==='deagle',fs=k==='fiveseven',us=k==='usp',p2=k==='p250';
 const SL=dg?.27:us?.21:fs?.2:.19,SH=dg?.05:.036,SW=dg?.032:.028,sz=-.04-SL/2+.06;
 slide.add(rb(SW,SH,SL,M.body,0,.05,sz,.008),rb(SW*.7,.006,SL*.96,M.dark,0,.05+SH/2+.001,sz,.002));
 for(let i=0;i<5;i++)slide.add(rb(SW+.003,.026,.003,M.dark,0,.05,.045-i*.008,.001));       // cannelures arrière
 slide.add(rb(.003,.016,.05,M.blk,SW/2+.0005,.052,sz-.01,.001));                                // fenêtre d'éjection
 slide.add(rb(.012,.014,.014,M.dark,0,.05+SH/2+.007,.055,.003),rb(.01,.014,.012,M.dark,0,.05+SH/2+.007,sz-SL/2+.015,.003));
 g.add(slide);
 // carcasse + poignée
 const fr=[[-SL/2-.04+.06,.036],[.07,.036],[.075,.012],[.082,-.13],[.035,-.135],[.028,-.06],[-.015,-.055],[-.035,-.034],[-SL/2-.04+.06,.01]];
 g.add(polyZY(fr,.026,dg?M.acc:M.blk,0,.003));
 g.add(rb(.012,.03,.07,M.blk,0,-.052,-.03,.003));  // pontet
 g.add(rb(.006,.022,.008,M.steel,0,-.04,-.012,.001)); // détente
 mag.add(rb(.022,.1,.036,M.dark,0,-.13,.055,.003),rb(.026,.012,.042,M.blk,0,-.185,.055,.003));g.add(mag);
 g.add(cz(.0075,.0075,.03,M.steel,0,.05,-SL+.045,10));
 if(us){g.add(cz(.0165,.0165,.13,M.dark,0,.05,-SL+.01,14),cz(.019,.019,.02,M.blk,0,.05,-SL-.05,14));}
 if(dg){g.add(rb(.012,.012,.2,M.steel,0,.082,sz,.003));g.add(rb(.035,.02,.1,M.acc,0,.003,-.1,.004));}
 g.add(rb(.003,.02,.1,M.steel,SW/2+.0003,.056,sz+.01,.001));
 return finishGun(g,{len:SL+.1,muzzle:-SL+.03-(us?.07:0),right:V3(0,-.045,.04),left:V3(.0,-.07,.03),mag,slide,eject:V3(.02,.06,sz),sight:.075,twoHand:true});
}
function buildSMG(k,M){
 const g=new THREE.Group(),mag=new THREE.Group(),bolt=new THREE.Group();
 if(k==='p90'){
  g.add(rb(.058,.1,.4,M.body,0,.005,-.06,.02),rb(.05,.035,.38,M.blk,0,.085,-.06,.01));
  mag.add(rb(.045,.022,.26,M.glass,0,.065,-.07,.006));g.add(mag);
  g.add(rb(.045,.04,.26,M.acc,0,-.03,.04,.01),rb(.035,.1,.05,M.blk,0,-.075,-.15,.005,.12));g.add(polyZY([[.04,.03],[.19,.04],[.2,-.05],[.16,-.07],[.04,-.04]],.034,M.acc,0,.004));
  g.add(cz(.011,.011,.12,M.dark,0,.012,-.3,12),cz(.013,.013,.04,M.blk,0,.012,-.37,12),rb(.014,.02,.1,M.blk,0,.1,-.18,.004));
  return finishGun(g,{len:.46,muzzle:-.38,right:V3(0,-.065,-.15),left:V3(0,-.015,-.27),mag,sight:.1,eject:V3(.03,0,.08)});
 }
 const L=k==='ump'?.32:k==='mp9'?.28:.2;
 g.add(rb(.044,.082,L,M.body,0,.015,-L/2+.03,.012));
 g.add(rb(.04,.016,L*.95,M.acc,0,.065,-L/2+.03,.006));
 bolt.add(rb(.012,.016,.04,M.steel,.026,.03,-.03,.003));g.add(bolt);
 g.add(polyZY([[.06,-.02],[.022,-.026],[.008,-.1],[.04,-.14],[.065,-.13]],.03,M.blk,0,.003));
 const mh=k==='mac10'?.14:k==='mp9'?.17:.16,mz=k==='ump'?-.1:-.08;
 mag.add(rb(.026,mh,.044,M.dark,0,-.045-mh/2,mz,.004),rb(.03,.012,.048,M.blk,0,-.05-mh,mz,.003));g.add(mag);
 g.add(rb(.012,.03,.07,M.blk,0,-.045,-.025,.003));
 const bl=k==='ump'?.18:k==='mp9'?.14:.1;
 g.add(cz(.012,.012,bl,M.dark,0,.02,-L-bl/2+.02,12));
 if(k==='mac10'){g.add(cz(.022,.022,.14,M.blk,0,.02,-L-.1,14));}
 if(k==='mp9'||k==='ump'){g.add(rb(.036,.04,.1,M.acc,0,.018,-L+.02,.006));}
 // crosse
 if(k==='ump')g.add(polyZY([[.04,.05],[.22,.04],[.24,-.04],[.2,-.05],[.04,-.02]],.026,M.blk,0,.003),rb(.03,.075,.012,M.rubber,0,0,.245,.003));
 else if(k==='mp9')g.add(rb(.02,.02,.2,M.blk,0,.03,.14,.004),rb(.026,.06,.012,M.rubber,0,.03,.245,.003));
 else g.add(rb(.012,.012,.14,M.steel,.012,.03,.1,.003));
 g.add(rb(.012,.02,.016,M.dark,0,.088,-.02,.003),rb(.01,.022,.01,M.dark,0,.07,-L+.04,.003));
 return finishGun(g,{len:L+bl+.1,muzzle:-L-bl+.01-(k==='mac10'?.15:0),right:V3(0,-.065,.0),left:V3(0,-.03,-L+.0),mag,bolt,sight:.085,eject:V3(.028,.03,-.05)});
}
function buildShotgun(k,M){
 const g=new THREE.Group(),pump=new THREE.Group();
 if(k==='sawedoff'){
  g.add(rb(.05,.065,.2,M.body,0,0,-.08,.01),cz(.014,.014,.32,M.dark,.014,.025,-.3,12),cz(.014,.014,.32,M.dark,-.014,.025,-.3,12),rb(.044,.01,.3,M.steel,0,.041,-.28,.003));
  g.add(polyZY([[.05,.04],[.2,.03],[.23,-.06],[.17,-.07],[.05,-.04]],.04,M.wood,0,.004),rb(.03,.07,.014,M.rubber,0,-.015,.225,.003,0,0,0));
  g.add(rb(.05,.034,.12,M.wood,0,-.02,-.3,.008));g.add(polyZY([[.01,-.035],[.035,-.035],[.04,-.12],[.0,-.125]],.034,M.wood,0,.003));
  g.add(rb(.036,.02,.05,M.steel,0,.034,-.02,.004));
  return finishGun(g,{len:.5,muzzle:-.46,right:V3(0,-.06,.0),left:V3(0,-.02,-.3),sight:.06,pump:null});
 }
 const L=k==='xm'?.85:.9;
 g.add(rb(.052,.08,.2,M.body,0,.005,-.07,.01),cz(.0125,.0125,L*.72,M.dark,0,.032,-L*.5-.03,12));
 g.add(cz(.011,.011,L*.58,M.acc,0,-.01,-L*.4-.03,12));g.add(cz(.014,.014,.025,M.steel,0,-.01,-L*.4-L*.29-.03,12));
 pump.add(rb(.05,.045,.2,k==='xm'?M.blk:M.wood,0,-.012,-L*.45,.01),rb(.052,.01,.2,M.rubber,0,-.034,-L*.45,.004));g.add(pump);
 const stockM=k==='xm'?M.blk:M.wood;
 g.add(polyZY([[.04,.04],[.32,.045],[.36,-.045],[.3,-.06],[.04,-.03]],.044,stockM,0,.004),rb(.036,.08,.014,M.rubber,0,-.005,.36,.003));
 g.add(polyZY([[.01,-.035],[.04,-.035],[.05,-.125],[.0,-.13]],.034,k==='xm'?M.blk:M.wood,0,.003),rb(.012,.03,.07,M.blk,0,-.05,-.03,.003));
 g.add(rb(.01,.016,.04,M.dark,0,.07,-L+.06,.003),rb(.012,.012,.12,M.steel,0,.052,-.12,.003));
 g.add(rb(.003,.02,.07,M.blk,.027,.01,-.1,.001));
 return finishGun(g,{len:L,muzzle:-L-.04,right:V3(0,-.07,.0),left:V3(0,-.012,-L*.45),pump,sight:.075,eject:V3(.03,.02,-.1)});
}
function buildRifle(k,M){
 const g=new THREE.Group(),mag=new THREE.Group(),bolt=new THREE.Group();
 const w=W[k],L=w.len;
 const ak=k==='ak',gal=k==='galil',m4=k==='m4',fam=k==='famas',sg=k==='sg553',aug=k==='aug';
 const bull=fam||aug;
 if(bull){ // bullpup
  g.add(rb(.058,.1,.5,M.body,0,.0,.04,.018),rb(.05,.04,.5,M.blk,0,.06,.04,.01));
  g.add(polyZY([[.3,.05],[.3,-.05],[.28,-.09],[.0,-.09],[.0,.05]],.052,M.body,0,.004));
  g.add(rb(.048,.07,.1,M.acc,0,-.015,-.28,.01),cz(.0095,.0095,.3,M.dark,0,.02,-.55,12),rb(.036,.05,.2,M.blk,0,.02,-.42,.008));
  g.add(cz(.012,.012,.04,M.blk,0,.02,-.7,12),rb(.012,.03,.012,M.dark,0,.07,-.72,.003));
  mag.add(rb(.03,.15,.05,M.dark,0,-.1,.095,.004),rb(.034,.012,.054,M.blk,0,-.18,.095,.003,.0));g.add(mag);
  g.add(polyZY([[.01,-.045],[.045,-.045],[.05,-.125],[.0,-.13]],.034,M.blk,0,.003),rb(.012,.03,.07,M.blk,0,-.07,-.04,.003));
  if(aug){g.add(cz(.022,.022,.2,M.blk,0,.1,-.12,16),cz(.026,.026,.02,M.glass,0,.1,-.225,16),cz(.026,.026,.02,M.glass,0,.1,-.02,16),rb(.03,.04,.04,M.blk,0,.08,-.12,.004));}
  else{g.add(polyZY([[-.06,.07],[.2,.075],[.22,.1],[-.04,.11],[-.07,.09]],.03,M.blk,0,.003),rb(.014,.016,.03,M.dark,0,.125,.12,.003));}
  g.add(rb(.012,.012,.01,M.steel,.03,.03,.0,.002));
  return finishGun(g,{len:.72,muzzle:-.72,right:V3(0,-.075,-.04),left:V3(0,-.02,-.38),mag,sight:aug?.115:.12,eject:V3(.03,.02,.0)});
 }
 // fusil classique
 g.add(rb(.044,.078,.3,M.body,0,0,-.13,.012));
 g.add(rb(.04,.022,.31,M.body,0,.047,-.135,.008));
 const fz=-.42,fl=w.cat==='rifle'&&gal?.26:.28;
 g.add(rb(.05,.052,fl,ak?M.wood:M.acc,0,-.01,fz,.012),rb(.04,.026,fl*.9,ak?M.wood:M.acc,0,.034,fz-.015,.008));
 if(m4||sg){g.add(rb(.052,.052,fl+.04,M.acc,0,-.002,fz-.01,.01));for(let i=0;i<5;i++)g.add(rb(.054,.003,.004,M.dark,0,.026,fz+.1-i*.045,.001));g.add(rb(.026,.008,.34,M.dark,0,.056,-.2,.002));}
 g.add(cz(.0095,.0095,L*.62,M.dark,0,.012,-L*.6-.06,12));
 g.add(cz(.012,.012,.28,M.steel,0,.038,-L*.5,12));                                   // tube de gaz
 g.add(rb(.022,.045,.03,M.steel,0,.034,-L+.12,.004),rb(.006,.03,.006,M.dark,0,.07,-L+.12,.001)); // guidon
 g.add(cz(.0135,.0135,.055,M.blk,0,.012,-L+.04,12),cz(.0095,.0095,.01,M.rubber,0,.012,-L+.012,10));
 g.add(rb(.032,.022,.05,M.dark,0,.062,-.3,.004));                                    // hausse
 if(m4)g.add(polyZY([[-.28,.052],[.0,.052],[.01,.1],[-.04,.115],[-.26,.11]],.024,M.blk,0,.004),rb(.006,.02,.008,M.dark,0,.125,-.15,.001));
 if(sg){g.add(cz(.02,.02,.16,M.blk,0,.098,-.14,14),cz(.024,.024,.02,M.glass,0,.098,-.225,14),cz(.024,.024,.02,M.glass,0,.098,-.055,14),rb(.03,.03,.03,M.blk,0,.075,-.14,.004));}
 // chargeur
 if(ak||gal){mag.add(polyZY([[-.05,-.04],[-.0,-.04],[.005,-.1],[-.01,-.17],[-.05,-.215],[-.105,-.225],[-.115,-.19],[-.085,-.165],[-.065,-.115]],.028,M.blk,0,.003));}
 else{mag.add(rb(.032,.16,.056,M.dark,0,-.12,-.14,.004,.08),rb(.036,.012,.06,M.blk,0,-.2,-.153,.003,.08));}
 g.add(mag);
 g.add(polyZY([[-.015,-.036],[.025,-.036],[.04,-.13],[.004,-.14],[-.012,-.08]],.03,ak?M.blk:M.rubber,0,.003),rb(.012,.03,.09,M.blk,0,-.05,-.1,.003));
 // crosse
 if(ak)g.add(polyZY([[.01,.048],[.3,.056],[.39,.026],[.41,-.07],[.37,-.078],[.1,-.035],[.03,-.036]],.036,M.wood,0,.004),rb(.037,.1,.012,M.rubber,0,-.015,.4,.003));
 else if(gal)g.add(polyZY([[.01,.044],[.28,.05],[.3,.036],[.29,-.06],[.27,-.064],[.1,-.03]],.014,M.blk,0,.003),rb(.014,.03,.3,M.blk,0,.0,.17,.003),rb(.036,.09,.012,M.rubber,0,-.01,.3,.003));
 else g.add(rb(.042,.045,.12,M.acc,0,.004,.1,.006),cz(.018,.018,.18,M.dark,0,.012,.18,10),polyZY([[.2,.04],[.3,.045],[.32,-.06],[.27,-.065],[.2,-.03]],.044,M.blk,0,.004),rb(.04,.09,.012,M.rubber,0,-.01,.315,.003));
 bolt.add(rb(.012,.014,.03,M.steel,.026,.03,-.1,.003));g.add(bolt);
 g.add(rb(.003,.02,.07,M.blk,.023,.02,-.1,.001));
 return finishGun(g,{len:L,muzzle:-L-.02,right:V3(0,-.075,.0),left:V3(0,-.012,fz),mag,bolt,sight:sg?.12:m4?.125:.075,eject:V3(.03,.03,-.1)});
}
function buildSniper(k,M){
 const g=new THREE.Group(),mag=new THREE.Group(),bolt=new THREE.Group();
 const L=W[k].len,awp=k==='awp',scar=k==='scar';
 g.add(rb(.052,.085,.34,M.body,0,0,-.08,.012),cz(.014,.014,L*.55,M.dark,0,.016,-L*.55-.1,14),cz(.018,.018,.1,M.blk,0,.016,-L-.0,14),cz(.021,.021,.015,M.blk,0,.016,-L+.04,14));
 // lunette
 const sy=.1,sl=.26;
 g.add(cz(.025,.025,sl,M.blk,0,sy,-.12,16),cz(.036,.03,.07,M.blk,0,sy,-.12-sl/2-.025,16),cz(.03,.036,.06,M.blk,0,sy,-.12+sl/2+.02,16));
 g.add(cz(.03,.03,.004,M.glass,0,sy,-.12-sl/2-.062,16),cz(.026,.026,.004,M.glass,0,sy,-.12+sl/2+.05,16));
 g.add(rb(.018,.04,.02,M.dark,0,.07,-.04,.003),rb(.018,.04,.02,M.dark,0,.07,-.22,.003),rb(.024,.016,.016,M.dark,0,sy+.028,-.12,.003));
 bolt.add(cz(.007,.007,.05,M.steel,.032,.022,.0,10),new THREE.Mesh(new THREE.SphereGeometry(.014,10,8),M.dark));bolt.children[1].position.set(.056,.022,.015);g.add(bolt);
 if(scar){mag.add(rb(.03,.1,.05,M.dark,0,-.1,-.1,.004));g.add(mag);g.add(rb(.05,.035,.28,M.acc,0,-.003,-.38,.01),rb(.026,.008,.4,M.dark,0,.058,-.25,.002));}
 else{mag.add(rb(.03,.06,.07,M.dark,0,-.065,-.1,.004));g.add(mag);g.add(rb(.044,.044,.22,awp?M.acc:M.wood,0,-.01,-.34,.01),rb(.016,.012,.2,M.dark,0,-.045,-.34,.003));}
 g.add(polyZY(awp?[[.04,.05],[.2,.05],[.3,.075],[.42,.06],[.42,-.1],[.34,-.1],[.2,-.03],[.04,-.035]]:[[.04,.045],[.3,.05],[.4,.03],[.42,-.07],[.36,-.075],[.04,-.035]],.046,awp?M.acc:M.wood,0,.005),rb(.044,.1,.012,M.rubber,0,-.015,.41,.003));
 g.add(polyZY([[-.015,-.036],[.03,-.036],[.045,-.13],[.0,-.14]],.032,M.blk,0,.003),rb(.012,.03,.08,M.blk,0,-.05,-.04,.003));
 g.add(rb(.012,.012,.12,M.steel,0,-.08,-L*.55,.003,.0));
 for(const sx of [-1,1])g.add(rb(.008,.1,.008,M.dark,sx*.02,-.045,-L*.7,.002,.4*sx*0+.5));
 return finishGun(g,{len:L,muzzle:-L+.03,right:V3(0,-.075,.0),left:V3(0,-.03,-.34),mag,bolt,sight:sy,eject:V3(.03,.03,-.06),scope:true});
}
function buildLMG(k,M){
 const g=new THREE.Group(),mag=new THREE.Group();
 const L=W[k].len,neg=k==='negev';
 g.add(rb(.075,.1,.4,M.body,0,0,-.1,.014),rb(.07,.025,.4,M.acc,0,.062,-.1,.008),cz(.015,.015,L*.5,M.dark,0,.02,-L*.5-.15,14),cz(.034,.034,.3,M.blk,0,.012,-.48,16));
 for(let i=0;i<6;i++)g.add(rb(.072,.006,.012,M.dark,0,.012,-.38-i*.04,.002));
 mag.add(rb(.1,.09,.14,M.acc,0,-.1,-.1,.01),rb(.088,.012,.12,M.blk,0,-.058,-.1,.003));
 for(let i=0;i<8;i++)mag.add(rb(.01,.02,.012,M.steel,.02,-.062,-.04-i*.012,.002));g.add(mag);
 g.add(polyZY([[-.01,-.05],[.04,-.05],[.055,-.14],[.01,-.15]],.036,M.blk,0,.003),rb(.014,.03,.1,M.blk,0,-.055,-.12,.003));
 g.add(polyZY([[.04,.05],[.22,.054],[.34,.01],[.35,-.07],[.3,-.075],[.04,-.04]],.05,M.blk,0,.005),rb(.05,.1,.012,M.rubber,0,-.015,.345,.003));
 g.add(rb(.03,.07,.1,M.blk,0,.1,-.12,.006),rb(.024,.02,.14,M.dark,0,.145,-.12,.004));
 g.add(rb(.012,.12,.012,M.dark,.04,-.07,-.58,.002,.4),rb(.012,.12,.012,M.dark,-.04,-.07,-.58,.002,.4));
 g.add(cz(.0125,.0125,.06,M.blk,0,.02,-L-.12,12),rb(.02,.04,.03,M.dark,0,.06,-L+.04,.004));
 return finishGun(g,{len:L,muzzle:-L-.12,right:V3(0,-.085,.0),left:V3(0,-.015,-.5),mag,sight:.11,eject:V3(.04,.03,-.1)});
}
function buildKnife(k,M){
 const g=new THREE.Group();
 g.add(polyZY([[-.02,.012],[-.2,.014],[-.27,.0],[-.29,-.01],[-.2,-.012],[-.02,-.012]],.006,M.steel,0,.0012),rb(.004,.003,.19,M.dark,0,.0,-.14,.001));
 g.add(polyZY([[0,.016],[-.025,.026],[-.025,-.026],[0,-.016]],.012,M.dark,0,.002),rb(.02,.032,.1,M.blk,0,0,.04,.006),rb(.024,.036,.016,M.dark,0,0,.095,.004));
 for(let i=0;i<4;i++)g.add(rb(.022,.034,.004,M.rubber,0,0,.0+i*.022,.001));
 return finishGun(g,{len:.3,muzzle:-.29,right:V3(0,0,.04),left:V3(0,0,.04),twoHand:false,eject:V3(0,0,0),sight:.0});
}
const BUILDERS={pistol:buildPistol,smg:buildSMG,shotgun:buildShotgun,rifle:buildRifle,sniper:buildSniper,lmg:buildLMG,melee:buildKnife};
function gunParts(k,sk){const w=W[k],g=BUILDERS[w.cat](k,gunMats(sk,w));if(sk&&sk.tex)applyPlanarUV(g);return g;}
const tmplCache={};
function gunTemplate(k){return tmplCache[k]||(tmplCache[k]=gunParts(k,SKINS[0]));}
function cloneGun(src){const c=src.clone(true);c.userData=src.userData;
 // retrouver les sous-groupes animés dans le clone
 const map=new Map();let a=[],b=[];src.traverse(o=>a.push(o));c.traverse(o=>b.push(o));a.forEach((o,i)=>map.set(o,b[i]));
 const u=Object.assign({},src.userData);for(const key of ['mag','slide','bolt','pump'])if(u[key])u[key]=map.get(u[key]);c.userData=u;return c;}

/* ---------- icônes d'armes (rendu hors-écran) ---------- */
const ICONS={};
let iconR=null,iconS=null,iconC=null;
function weaponIcon(k,skinIdx){
 const key=k+':'+(skinIdx||0);if(ICONS[key])return ICONS[key];
 if(!iconR){
  const cv=document.createElement('canvas');cv.width=320;cv.height=130;
  iconR=new THREE.WebGLRenderer({canvas:cv,alpha:true,antialias:true,preserveDrawingBuffer:true});iconR.setSize(320,130,false);iconR.outputEncoding=THREE.sRGBEncoding;iconR.toneMapping=THREE.ACESFilmicToneMapping;
  iconS=new THREE.Scene();iconC=new THREE.OrthographicCamera(-.8,.8,.325,-.325,.1,10);iconC.position.set(0,0,3);
  iconS.add(new THREE.HemisphereLight(0xffffff,0x667788,1.2));const d=new THREE.DirectionalLight(0xffffff,2.4);d.position.set(1,2,3);iconS.add(d);
  const d2=new THREE.DirectionalLight(0x88aaff,1);d2.position.set(-2,0,2);iconS.add(d2);
  iconS.environment=makeEnv(iconR);
 }
 const sk=(skinIdx&&SKINS[skinIdx])||SKINS[0];
 const g=gunParts(k,sk),box=new THREE.Box3().setFromObject(g),c=box.getCenter(new THREE.Vector3()),sz=box.getSize(new THREE.Vector3());
 g.position.set(-c.z*0,-c.y,-c.z);const pv=new THREE.Group();pv.add(g);g.position.set(0,-c.y,-c.z);
 pv.rotation.y=Math.PI/2;pv.scale.setScalar(1.45/Math.max(sz.z,.2));
 iconS.add(pv);iconR.render(iconS,iconC);const url=iconR.domElement.toDataURL('image/png');iconS.remove(pv);
 ICONS[key]=url;return url;
}

/* ====================================================================
   SOLDATS
   ==================================================================== */
const SKIN_TONES=['#f0c8a0','#d9a577','#b5835a','#8a5a3b','#e8b896','#6f452c'];
const PALETTE=['#e74c3c','#3498db','#2ecc71','#f1c40f','#9b59b6','#e67e22','#1abc9c','#ff6bd6','#ecf0f1','#95a5a6','#d35400','#16a085'];
function uniformTex(base,dark,light,w,h){return canvasTex(128,128,(c,W2,H2)=>{
 c.fillStyle=base;c.fillRect(0,0,W2,H2);
 for(let i=0;i<70;i++){c.fillStyle=pick([dark,light,base]);c.beginPath();c.ellipse(rand(0,W2),rand(0,H2),rand(6,20),rand(4,11),rand(0,3),0,TAU);c.globalAlpha=.55;c.fill();}
 c.globalAlpha=1;speck(c,W2,H2,300,.03,.1,3);
},true);}
function molleTex(base){return canvasTex(128,128,(c,w,h)=>{
 c.fillStyle=base;c.fillRect(0,0,w,h);
 c.fillStyle='rgba(0,0,0,.35)';for(let y=6;y<h;y+=12)for(let x=4;x<w;x+=10)c.fillRect(x,y,7,3);
 c.strokeStyle='rgba(0,0,0,.3)';c.lineWidth=2;for(let y=0;y<h;y+=32){c.beginPath();c.moveTo(0,y);c.lineTo(w,y);c.stroke();}
 speck(c,w,h,200,.03,.08,3);
},true);}
function shemaghTex(){return cached('shemagh',()=>canvasTex(64,64,(c,w,h)=>{
 c.fillStyle='#e8e2d2';c.fillRect(0,0,w,h);c.strokeStyle='#1c1c1c';c.lineWidth=4;
 for(let i=-h;i<w+h;i+=14){c.beginPath();c.moveTo(i,0);c.lineTo(i+h,h);c.stroke();c.beginPath();c.moveTo(i,h);c.lineTo(i+h,0);c.stroke();}
 c.fillStyle='#a02020';for(let y=0;y<h;y+=16)for(let x=0;x<w;x+=16)c.fillRect(x+6,y+6,4,4);
},true));}
const LOOKS={};
function lookMats(look){
 if(look.outfit&&OUTFITS[look.outfit])return outfitMats(look);
 const key=look.kind+'|'+look.acc+'|'+look.tone;
 if(LOOKS[key])return LOOKS[key];
 const L={},ctk=look.kind==='ct',tk=look.kind==='t';
 const skinC=C(look.tone);
 L.skin=new THREE.MeshStandardMaterial({color:skinC,roughness:.75});
 if(ctk){const tx=uniformTex('#2b3a52','#1e2a3d','#3b4f70');tx.repeat.set(2,2);
  L.shirt=new THREE.MeshStandardMaterial({map:tx,roughness:.9});L.pants=new THREE.MeshStandardMaterial({map:tx,roughness:.9,color:C(0xcfd6e6)});
  const mt=molleTex('#1b1f27');L.vest=new THREE.MeshStandardMaterial({map:mt,roughness:.85});
  L.helm=new THREE.MeshStandardMaterial({color:C(0x232f45),roughness:.5,metalness:.15});L.glove=new THREE.MeshStandardMaterial({color:C(0x15181d),roughness:.8});L.boot=new THREE.MeshStandardMaterial({color:C(0x121316),roughness:.7});}
 else if(tk){const tx=uniformTex('#a99468','#7f6f4a','#c0ab7c');tx.repeat.set(2,2);const tp=uniformTex('#5c6140','#454a2e','#737a52');tp.repeat.set(2,2);
  L.shirt=new THREE.MeshStandardMaterial({map:tx,roughness:.9});L.pants=new THREE.MeshStandardMaterial({map:tp,roughness:.9});
  const mt=molleTex('#4a4a32');L.vest=new THREE.MeshStandardMaterial({map:mt,roughness:.85});
  L.helm=new THREE.MeshStandardMaterial({map:shemaghTex(),roughness:.95});L.glove=new THREE.MeshStandardMaterial({color:C(0x8a7a55),roughness:.85});L.boot=new THREE.MeshStandardMaterial({color:C(0x4a3a2a),roughness:.75});}
 else{const col=look.acc;const tx=uniformTex('#3a4350','#2a313b','#4a5666');tx.repeat.set(2,2);
  L.shirt=new THREE.MeshStandardMaterial({color:C(col),roughness:.85});L.pants=new THREE.MeshStandardMaterial({map:tx,roughness:.9});
  const mt=molleTex('#22262e');L.vest=new THREE.MeshStandardMaterial({map:mt,roughness:.85});
  L.helm=new THREE.MeshStandardMaterial({color:C(col),roughness:.5,metalness:.1});L.glove=new THREE.MeshStandardMaterial({color:C(0x15181d),roughness:.8});L.boot=new THREE.MeshStandardMaterial({color:C(0x121316),roughness:.7});}
 L.accent=new THREE.MeshStandardMaterial({color:C(look.acc),roughness:.6,emissive:C(look.acc),emissiveIntensity:.25});
 L.dark=new THREE.MeshStandardMaterial({color:C(0x1b1d22),roughness:.6,metalness:.3});
 L.lens=new THREE.MeshStandardMaterial({color:C(0x0a0c10),roughness:.08,metalness:.9});
 L.blk=new THREE.MeshStandardMaterial({color:C(0x16171a),roughness:.7});
 return LOOKS[key]=L;
}
/* géométries du soldat (partagées) */
let SG=null;
function initSoldierGeos(){
 if(SG)return;SG={};
 const taper=(rT,rB,len,seg)=>{const g=new THREE.CylinderGeometry(rT,rB,len,seg||10);g.translate(0,-len/2,0);return g;};
 SG.thigh=taper(.088,.066,.46);SG.shin=taper(.064,.046,.45);SG.uarm=taper(.052,.044,.29);SG.farm=taper(.044,.036,.27);SG.neck=taper(.05,.056,.08,10);
 SG.ball=new THREE.SphereGeometry(1,14,10);
 // torse
 const t=new THREE.Shape();t.moveTo(-.15,0);t.lineTo(.15,0);t.lineTo(.2,.34);t.lineTo(.22,.5);t.lineTo(-.22,.5);t.lineTo(-.2,.34);t.closePath();
 SG.torso=new THREE.ExtrudeGeometry(t,{depth:.16,bevelEnabled:true,bevelThickness:.04,bevelSize:.035,bevelSegments:2,curveSegments:2});SG.torso.translate(0,0,-.08);
 SG.hips=rbGeo(.34,.18,.22,.05);
}
function placeLimb(mesh,a,b){
 const dx=b.x-a.x,dy=b.y-a.y,dz=b.z-a.z,L=Math.hypot(dx,dy,dz)||1e-4;
 mesh.position.copy(a);
 _d.set(dx/L,dy/L,dz/L);mesh.quaternion.setFromUnitVectors(_dn,_d);
}
const _d=V3(0,0,0),_dn=V3(0,-1,0),_u=V3(0,0,0),_pp=V3(0,0,0),_e=V3(0,0,0),_h2=V3(0,0,0);
// IK à deux segments ; S, H dans le même repère ; retourne le coude dans out
function ik2(S,H,la,lb,pole,out){
 _u.subVectors(H,S);let L=_u.length();const mx=la+lb-.002,mn=Math.abs(la-lb)+.002;
 if(L>mx){L=mx;}if(L<mn)L=mn;_u.normalize();
 const cosA=clamp((la*la+L*L-lb*lb)/(2*la*L),-1,1),sinA=Math.sqrt(1-cosA*cosA);
 _pp.copy(pole);_pp.addScaledVector(_u,-_pp.dot(_u));if(_pp.lengthSq()<1e-6)_pp.set(0,-1,0);_pp.normalize();
 out.copy(S).addScaledVector(_u,la*cosA).addScaledVector(_pp,la*sinA);
 // main atteinte (clampée)
 _h2.copy(S).addScaledVector(_u,L);
 return _h2;
}
function makeHandMesh(mat,detail){
 const g=new THREE.Group();
 g.add(rb(.075,.03,.09,mat,0,0,-.035,.012));
 if(detail){for(let i=0;i<4;i++){const f=rb(.016,.017,.06,mat,-.028+i*.0185,-.012,-.095,.006,.5);g.add(f);}
  g.add(rb(.02,.02,.055,mat,.045,.0,-.04,.007,0,-.5));}
 else{g.add(rb(.07,.024,.05,mat,0,-.012,-.085,.008,.5),rb(.02,.02,.05,mat,.042,0,-.04,.007));}
 return g;
}
function makeSoldier(look){
 initSoldierGeos();
 const OUT=look.outfit&&OUTFITS[look.outfit]?OUTFITS[look.outfit]:null;
 const M=lookMats(look),ctk=!OUT&&look.kind==='ct',tk=!OUT&&look.kind==='t';
 const R={look,ph:Math.random()*TAU,ck:0,ready:.4,rec:0,flinch:0,dieT:-1,dieStyle:0,gk:null,gunObj:null,reloadP:0,swT:0,lean:0,blink:0};
 const root=new THREE.Group();root.rotation.order='YXZ';R.root=root;
 const mesh=(geo,mat,x,y,z,sx,sy,sz)=>{const m=new THREE.Mesh(geo,mat);m.position.set(x||0,y||0,z||0);if(sx!==undefined)m.scale.set(sx,sy,sz);return m;};
 // bassin
 R.hips=new THREE.Group();R.hips.position.y=.94;root.add(R.hips);
 R.hips.add(mesh(SG.hips,M.pants,0,0,0),rb(.36,.045,.24,M.dark,0,.07,0,.015));
 R.hips.add(rb(.07,.12,.06,M.blk,.2,-.06,.03,.02),rb(.06,.08,.05,M.blk,-.2,-.01,.07,.015)); // holster + pochette
 // jambes
 const mkLeg=side=>{
  const th=new THREE.Group();th.position.set(side*.1,-.02,0);
  th.add(mesh(SG.thigh,M.pants,0,0,0),rb(.085,.14,.11,M.vest,side*.04,-.2,-.04,.02));
  const sh=new THREE.Group();sh.position.y=-.46;th.add(sh);
  sh.add(mesh(SG.shin,M.pants,0,0,0),mesh(SG.ball,M.pants,0,0,0,.062,.062,.062),rb(.1,.12,.1,M.dark,0,-.08,-.055,.025)); // genou + genouillère
  const foot=new THREE.Group();foot.position.y=-.45;sh.add(foot);
  foot.add(rb(.105,.1,.27,M.boot,0,-.04,-.05,.03),rb(.11,.03,.29,M.dark,0,-.1,-.05,.012),rb(.1,.12,.12,M.boot,0,.02,.04,.03));
  R.hips.add(th);return {th,sh,foot};
 };
 R.legL=mkLeg(-1);R.legR=mkLeg(1);
 // colonne
 R.spine=new THREE.Group();R.spine.position.set(0,.07,0);R.hips.add(R.spine);
 R.spine.add(mesh(SG.torso,M.shirt,0,0,0));
 // gilet pare-balles + poches
 R.spine.add(rb(.4,.4,.26,M.vest,0,.28,0,.04));
 R.spine.add(rb(.3,.28,.04,M.dark,0,.3,-.145,.015));
 for(let i=0;i<3;i++)R.spine.add(rb(.075,.1,.05,M.dark,-.11+i*.11,.14,-.15,.014));
 R.spine.add(rb(.09,.07,.05,M.dark,-.17,.3,-.145,.012),rb(.05,.1,.04,M.blk,.17,.32,-.145,.01));
 // bretelles et épaulières
 for(const s of [-1,1]){R.spine.add(rb(.09,.04,.28,M.vest,s*.15,.5,0,.012),mesh(SG.ball,M.shirt,s*.22,.46,0,.07,.07,.07));}
 if(ctk)for(const s of [-1,1])R.spine.add(rb(.12,.05,.14,M.helm,s*.23,.51,0,.02));
 // sac à dos
 if(tk){const roll=cz(.05,.05,.34,M.pants,0,.5,.2,10);roll.rotation.y=Math.PI/2;R.spine.add(rb(.3,.36,.17,M.vest,0,.28,.2,.04),roll);}
 else R.spine.add(rb(.28,.32,.14,M.vest,0,.27,.19,.04),rb(.018,.018,.34,M.dark,.1,.62,.21,.004));
 // radio / lampe
 R.spine.add(rb(.05,.09,.04,M.dark,.19,.18,-.1,.01));
 // cou + tête
 R.neckG=new THREE.Group();R.neckG.position.set(0,.5,0);R.spine.add(R.neckG);
 R.neckG.add(mesh(SG.neck,M.skin,0,.02,0));
 R.head=new THREE.Group();R.head.position.set(0,.14,0);R.neckG.add(R.head);
 R.head.scale.setScalar(1.14);
 const hd=mesh(SG.ball,M.skin,0,0,0,.105,.125,.115);R.head.add(hd);
 R.head.add(mesh(SG.ball,M.skin,-.105,-.01,.01,.02,.035,.03),mesh(SG.ball,M.skin,.105,-.01,.01,.02,.035,.03));
 R.head.add(rb(.026,.032,.04,M.skin,0,-.012,-.115,.008));
 R.eyeL=rb(.022,.014,.012,M.blk,-.04,.02,-.108,.004);R.eyeR=rb(.022,.014,.012,M.blk,.04,.02,-.108,.004);R.head.add(R.eyeL,R.eyeR);
 R.head.add(rb(.05,.01,.01,M.blk,-.04,.04,-.112,.003),rb(.05,.01,.01,M.blk,.04,.04,-.112,.003));
 if(OUT){buildOutfitHead(R,M,OUT);}
 else if(ctk){
  const helm=new THREE.Mesh(new THREE.SphereGeometry(1,18,10,0,TAU,0,Math.PI*.6),M.helm);helm.scale.set(.142,.13,.158);helm.position.set(0,.012,.006);R.head.add(helm);
  R.head.add(rb(.3,.012,.1,M.helm,0,.01,-.14,.004,.05),rb(.02,.05,.03,M.dark,0,.095,-.1,.006),rb(.12,.012,.02,M.dark,0,.07,-.125,.003));
  R.head.add(rb(.03,.1,.034,M.dark,-.14,-.03,.02,.008),rb(.03,.1,.034,M.dark,.14,-.03,.02,.008),rb(.01,.01,.12,M.blk,-.14,-.09,-.06,.003));
  R.head.add(rb(.19,.04,.05,M.lens,0,.028,-.115,.01));  // lunettes
  R.head.add(rb(.012,.07,.012,M.blk,-.05,-.08,-.1,.003),rb(.012,.07,.012,M.blk,.05,-.08,-.1,.003));
 }else if(tk){
  const wr=new THREE.Mesh(new THREE.SphereGeometry(1,18,10,0,TAU,0,Math.PI*.62),M.helm);wr.scale.set(.14,.135,.155);wr.position.set(0,.012,.01);R.head.add(wr);
  R.head.add(rb(.2,.09,.17,M.helm,0,-.065,-.01,.03),rb(.12,.1,.05,M.helm,.04,-.1,.1,.02),rb(.2,.03,.04,M.lens,0,.026,-.115,.01),rb(.016,.07,.2,M.helm,0,-.01,.12,.006));
 }else{
  const helm=new THREE.Mesh(new THREE.SphereGeometry(1,18,10,0,TAU,0,Math.PI*.58),M.helm);helm.scale.set(.138,.12,.15);helm.position.set(0,.02,.005);R.head.add(helm);
  R.head.add(rb(.2,.034,.045,M.lens,0,.025,-.115,.01),rb(.02,.05,.02,M.accent,0,.1,-.08,.005));
 }
 // bras (IK) : segments séparés placés dans le repère de la colonne
 R.arm={};
 for(const s of [-1,1]){
  const A={s,ua:mesh(SG.uarm,M.shirt),fa:mesh(SG.farm,M.shirt),elbow:mesh(SG.ball,M.shirt,0,0,0,.05,.05,.05),hand:makeHandMesh(M.glove,false),pad:rb(.075,.09,.075,M.vest,0,0,0,.015),
   S:V3(s*.215,.44,.0),E:V3(),Hh:V3(),pole:V3(s*.55,-.8,.25)};
  R.spine.add(A.ua,A.fa,A.elbow,A.hand,A.pad);
  A.band=rb(.098,.024,.098,M.accent,0,0,0,.008);R.spine.add(A.band);
  R.arm[s>0?'R':'L']=A;
 }
 // porte-arme
 R.gunMount=new THREE.Group();R.gunMount.position.set(.12,.2,-.2);R.spine.add(R.gunMount);
 R.flash=new THREE.Sprite(flashSpriteMat.clone());R.flash.scale.set(.5,.5,1);R.flash.visible=false;
 R.flashMesh=new THREE.Group();
 const star=new THREE.Mesh(new THREE.PlaneGeometry(.3,.3),new THREE.MeshBasicMaterial({map:FLASHTEX,transparent:true,blending:THREE.AdditiveBlending,depthWrite:false,side:THREE.DoubleSide,toneMapped:false}));
 R.flashMesh.add(star);const star2=star.clone();star2.rotation.z=1.57;R.flashMesh.add(star2);const star3=star.clone();star3.rotation.y=1.57;R.flashMesh.add(star3);
 R.flashMesh.visible=false;
 root.traverse(o=>{if(o.isMesh)o.castShadow=true;});
 R.bone={};R.height=1.0;
 return R;
}
const FLASHTEX=canvasTex(64,64,(c)=>{const g=c.createRadialGradient(32,32,0,32,32,32);g.addColorStop(0,'rgba(255,255,235,1)');g.addColorStop(.25,'rgba(255,210,100,.9)');g.addColorStop(1,'rgba(255,120,0,0)');c.fillStyle=g;c.fillRect(0,0,64,64);});
const flashSpriteMat=new THREE.SpriteMaterial({map:FLASHTEX,blending:THREE.AdditiveBlending,transparent:true,depthWrite:false,toneMapped:false});
function setSoldierGun(R,k){
 if(R.gunObj){R.gunMount.remove(R.gunObj);}
 const g=cloneGun(gunTemplate(k));R.gunObj=g;R.gk=k;R.gunMount.add(g);
 g.traverse(o=>{if(o.isMesh)o.castShadow=true;});
 const u=g.userData;
 R.flash.position.set(0,.02,u.muzzle-.03);R.flashMesh.position.set(0,.02,u.muzzle-.04);
 if(R.flash.parent)R.flash.parent.remove(R.flash);if(R.flashMesh.parent)R.flashMesh.parent.remove(R.flashMesh);
 g.add(R.flash);g.add(R.flashMesh);
 R.gunU=u;R.melee=W[k].melee;
}
const _gp=V3(),_gq=new THREE.Quaternion(),_el=V3(),_t1=V3(),_t2=V3(),_t3=V3();
function updateArmsIK(R,gunPos,gunQuat,gunScale,leftDown){
 // positions des mains dans le repère de la colonne
 const u=R.gunU;if(!u)return;
 _t1.copy(u.right).multiplyScalar(gunScale).applyQuaternion(gunQuat).add(gunPos);
 if(u.twoHand){_t2.copy(u.left).multiplyScalar(gunScale).applyQuaternion(gunQuat).add(gunPos);if(leftDown)_t2.y-=leftDown;}
 else _t2.set(-.2,.0,.1);
 for(const key of ['R','L']){
  const A=R.arm[key],tgt=key==='R'?_t1:_t2;
  ik2(A.S,tgt,.29,.27,A.pole,_el);
  A.E.copy(_el);
  placeLimb(A.ua,A.S,A.E);placeLimb(A.fa,A.E,tgt);
  A.elbow.position.copy(A.E);
  A.hand.position.copy(tgt);
  // orientation de la main : alignée sur le canon pour la main droite / suit l'avant-bras pour la gauche
  _d.subVectors(tgt,A.E).normalize();
  A.hand.quaternion.setFromUnitVectors(V3(0,0,-1),_d);
  if(key==='R'||!u.twoHand){A.hand.quaternion.copy(gunQuat);}
  A.pad.position.copy(A.E).addScaledVector(_d,-.0);A.band.position.copy(A.S).lerp(A.E,.55);A.band.quaternion.copy(A.ua.quaternion);
  A.pad.position.copy(A.E);A.pad.quaternion.copy(A.ua.quaternion);
 }
}
/* animation d'un soldat. st = { vx,vz,yaw,pitch,speed,onGround,crouch,alive,reload,reloadMax,fire(0..1),ready,hurt,dieT } */
const _q1=new THREE.Quaternion(),_e1=new THREE.Euler();
function animateSoldier(R,st,dt,t){
 const hips=R.hips,sp=R.spine;
 if(st.dance&&st.alive){danceAnim(R,st,dt,t);return;}
 // mort
 if(!st.alive){
  if(R.dieT<0){R.dieT=0;R.dieStyle=st.dieDir||0;}
  R.dieT+=dt;const k=smooth01(R.dieT/.55),bounce=R.dieT>.55?Math.exp(-(R.dieT-.55)*6)*Math.sin((R.dieT-.55)*18)*.04:0;
  const sty=R.dieStyle;
  R.root.rotation.x=sty===1?k*1.45:sty===0?-k*1.45:-k*.3;
  R.root.rotation.z=sty===2?k*1.4:sty===3?-k*1.4:0;
  R.root.position.y=(st.y||0)+k*.12+bounce;
  hips.position.y=.94-k*.1;
  R.legL.th.rotation.x=-k*.4;R.legR.th.rotation.x=k*.2;R.legL.sh.rotation.x=k*.6;R.legR.sh.rotation.x=k*.9;
  sp.rotation.x=k*.2;R.head.rotation.x=k*.4;
  R.arm.R.pole.set(.6,-.6,.4);R.arm.L.pole.set(-.6,-.6,.4);
  // arme qui lâche
  _gp.set(.12+k*.18,.2-k*.35,-.2+k*.15);_gq.setFromEuler(_e1.set(k*1.2,0,k*.9));R.gunMount.position.copy(_gp);R.gunMount.quaternion.copy(_gq);
  updateArmsIK(R,_gp,_gq,1,.0);
  R.flash.visible=false;R.flashMesh.visible=false;
  return;
 }
 R.dieT=-1;R.root.rotation.x=0;R.root.rotation.z=0;R.root.position.y=st.y||0;R.gunMount.visible=true;
 const spd=st.speed,k=clamp(spd/5.2,0,1.4);
 // coordonnées locales de la vitesse
 const sy=Math.sin(st.yaw),cy=Math.cos(st.yaw);
 const lf=st.vx*(-sy)+st.vz*(-cy),lr=st.vx*cy+st.vz*(-sy);
 R.ph+=dt*spd*1.7;
 const ph=R.ph,sw=Math.sin(ph),sw2=Math.sin(ph+Math.PI);
 R.ck+=((st.crouch?1:0)-R.ck)*Math.min(1,dt*10);
 const air=!st.onGround;
 const fw=clamp(lf/5.2,-1.2,1.2),sd=clamp(lr/5.2,-1.2,1.2);
 const amp=.75*Math.min(1,k*1.15);
 hips.position.y=.94-R.ck*.4+(air?.03:Math.abs(sw)*.035*k);
 hips.position.x=Math.sin(ph)*.012*k;
 hips.rotation.y=-sd*.18*k;hips.rotation.z=Math.sin(ph)*.03*k;
 const leg=(L,s,swv)=>{
  let hipA=swv*amp*(Math.abs(fw)>.15?Math.sign(fw||1):1);
  let knee=Math.max(0,Math.cos(ph+(s>0?0:Math.PI)))*amp*1.3*(Math.abs(fw)>.15?1:.6)+.06;
  L.th.rotation.x=hipA+R.ck*1.25;L.th.rotation.z=-s*.03-sd*.28*swv*k;L.th.rotation.y=0;
  L.sh.rotation.x=-knee-R.ck*1.7;L.foot.rotation.x=-hipA*.3+knee*.2;
  if(air){L.th.rotation.x=-.5-s*.1;L.sh.rotation.x=-.9;L.foot.rotation.x=.3;}
 };
 leg(R.legL,-1,sw);leg(R.legR,1,sw2);
 if(st.seated){hips.position.y=.55;for(const L of [R.legL,R.legR]){L.th.rotation.x=1.45;L.sh.rotation.x=st.seated===2?-1.2+Math.sin(t*2+R.ph)*.18:-1.5;L.foot.rotation.x=0;}}
 // viser
 R.ready+=((st.ready?1:.35)-R.ready)*Math.min(1,dt*6);
 R.flinch*=Math.max(0,1-dt*8);if(st.hurt){R.flinch=1;}
 R.rec*=Math.max(0,1-dt*14);if(st.fire>0)R.rec=Math.max(R.rec,st.fire);
 const p=clamp(st.pitch,-1.3,1.3);
 const lowered=(1-R.ready);
 sp.rotation.x=p*.5-R.ck*.18+R.flinch*.18+R.rec*.04;
 sp.rotation.z=-sd*.06*k;sp.rotation.y=sd*.25*k*0+Math.sin(t*1.3+R.ph)*.01*(1-k)+R.flinch*(Math.sin(t*40)*.03);
 R.neckG.rotation.x=p*.35;R.head.rotation.x=0;R.head.rotation.y=clamp(Math.sin(t*.6+R.ph*3)*.1*(1-st.alert),-.2,.2);
 // clin d'œil / respiration
 sp.position.y=.07+Math.sin(t*2+R.ph)*.004;
 // pose de l'arme
 const rl=st.reloadMax>0&&st.reload>0?1-st.reload/st.reloadMax:-1;
 let gx=.12,gy=.2-lowered*.08,gz=-.2+lowered*.04;
 let rx=-lowered*.55,rz=0,ry=lowered*.18;
 let leftDown=0;
 if(rl>=0){ // rechargement
  const a=Math.sin(rl*Math.PI);rx+=a*.55;rz+=a*.25;gy-=a*.06;leftDown=a*.2;
  const u=R.gunU;
  if(u&&u.mag){const mp=rl<.3?0:rl<.5?smooth01((rl-.3)/.2):rl<.7?1-smooth01((rl-.5)/.2)*0:1;const out=rl>=.3&&rl<.55?smooth01((rl-.3)/.25):rl>=.55&&rl<.75?1-smooth01((rl-.55)/.2):0;u.mag.position.y=-out*.18;u.mag.position.x=out*.05;}
 }else if(R.gunU&&R.gunU.mag){R.gunU.mag.position.set(0,0,0);}
 if(R.swT>0){R.swT=Math.max(0,R.swT-dt);rx+=R.swT*1.2;gy-=R.swT*.15;}
 gz+=R.rec*.05;rx+=R.rec*.08;
 _gp.set(gx,gy,gz);_gq.setFromEuler(_e1.set(rx,ry,rz));
 R.gunMount.position.copy(_gp);R.gunMount.quaternion.copy(_gq);
 if(R.gunU&&R.gunU.slide)R.gunU.slide.position.z=R.rec*.03;
 if(R.gunU&&R.gunU.pump)R.gunU.pump.position.z=R.rec>0?Math.sin(R.rec*3)*.03:0;
 updateArmsIK(R,_gp,_gq,1,leftDown);
 R.flash.visible=st.fire>.55;R.flashMesh.visible=st.fire>.55;
 if(R.flash.visible){R.flash.material.rotation=Math.random()*6;R.flashMesh.rotation.z=Math.random()*6;const s=.3+Math.random()*.25;R.flashMesh.scale.set(s*2,s*2,s*2);}
}

/* ====================================================================
   DANSES (animations procédurales) & POSE ASSISE
   ==================================================================== */
const DANCES=[
 {id:'wave',n:'Salut',q:0,len:3},{id:'clap',n:'Applaudissements',q:0,len:3.4},{id:'disco',n:'Disco',q:1,len:4},{id:'robot',n:'Robot',q:1,len:4},
 {id:'floss',n:'Floss',q:2,len:4},{id:'twist',n:'Toupie',q:2,len:3.4},{id:'moonwalk',n:'Moonwalk',q:3,len:4.2},{id:'break',n:'Breakdance',q:3,len:4}
];
function placeArmsTo(R,tR,tL){
 for(const key of ['R','L']){
  const A=R.arm[key],tgt=key==='R'?tR:tL;
  ik2(A.S,tgt,.29,.27,A.pole,_el);A.E.copy(_el);
  placeLimb(A.ua,A.S,A.E);placeLimb(A.fa,A.E,tgt);A.elbow.position.copy(A.E);A.hand.position.copy(tgt);
  _d.subVectors(tgt,A.E).normalize();A.hand.quaternion.setFromUnitVectors(V3(0,0,-1),_d);
  A.band.position.copy(A.S).lerp(A.E,.55);A.band.quaternion.copy(A.ua.quaternion);A.pad.position.copy(A.E);A.pad.quaternion.copy(A.ua.quaternion);
 }
}
const _dR=V3(),_dL=V3();
function danceAnim(R,st,dt,t){
 const id=st.dance,tt=st.danceT,hips=R.hips,sp=R.spine,s=Math.sin,c=Math.cos;
 R.root.rotation.x=0;R.root.rotation.z=0;R.root.position.y=st.y||0;
 R.gunMount.visible=false;R.flash.visible=false;R.flashMesh.visible=false;
 hips.position.set(0,.94,0);hips.rotation.set(0,0,0);sp.rotation.set(0,0,0);R.neckG.rotation.set(0,0,0);R.head.rotation.set(0,0,0);sp.position.y=.07;
 for(const L of [R.legL,R.legR]){L.th.rotation.set(0,0,0);L.sh.rotation.set(0,0,0);L.foot.rotation.set(0,0,0);}
 let tR=_dR.set(.25,.12,-.1),tL=_dL.set(-.25,.12,-.1);
 const b=tt*8;
 switch(id){
  case 'wave':
   tR.set(.32+s(b*1.2)*.13,.93,-.05);tL.set(-.22,.13,-.02);sp.rotation.z=-.06+s(tt*2)*.03;R.head.rotation.z=.1*s(tt*2);hips.rotation.z=s(tt*3)*.03;
   R.legR.th.rotation.x=.04;break;
  case 'clap':{
   const ph=Math.abs(s(tt*9));tR.set(.04+ph*.15,.38,-.34);tL.set(-.04-ph*.15,.38,-.34);hips.position.y=.94-Math.abs(s(tt*9))*.03;
   R.legL.th.rotation.x=.15;R.legR.th.rotation.x=.15;R.legL.sh.rotation.x=-.2;R.legR.sh.rotation.x=-.2;R.head.rotation.x=.1;break;}
  case 'disco':{
   const beat=Math.floor(tt*2.5)%2,sw=s(tt*5);
   if(beat)tR.set(.3,1.0,-.02);else tR.set(-.12,.05,-.2);tL.set(-.28,.14,.02);
   hips.rotation.z=sw*.12;sp.rotation.z=-sw*.14;hips.position.x=sw*.06;R.head.rotation.z=sw*.1;
   R.legR.th.rotation.x=.25+sw*.25;R.legL.th.rotation.x=.25-sw*.25;R.legR.sh.rotation.x=-.3;R.legL.sh.rotation.x=-.3;break;}
  case 'robot':{
   const stp=Math.floor(tt*2.5)%4;
   const rs=[[.45,.45,0],[.25,.92,-.1],[.4,.45,-.45],[.2,.2,-.1]],ls=[[-.2,.92,-.1],[-.45,.45,0],[-.2,.2,-.1],[-.4,.45,-.45]];
   tR.set(...rs[stp]);tL.set(...ls[stp]);R.head.rotation.y=[0,.6,0,-.6][stp];sp.rotation.y=[0,.2,0,-.2][stp];
   R.legL.th.rotation.x=.1;R.legR.th.rotation.x=.1;break;}
  case 'floss':{
   const sw=s(tt*7);tR.set(.25+sw*.3,.16,-.12-sw*.3);tL.set(-.25+sw*.3,.16,-.12+sw*.3);
   hips.rotation.y=-sw*.38;hips.position.x=sw*.05;hips.position.y=.94-.05;
   for(const L of [R.legL,R.legR]){L.th.rotation.x=.3;L.sh.rotation.x=-.45;}R.head.rotation.y=sw*.2;break;}
  case 'twist':
   tR.set(.62,.5,0);tL.set(-.62,.5,0);R.root.rotation.y+=tt*7;R.root.position.y+=Math.abs(s(tt*5))*.1;hips.position.y=.94-.04;
   for(const L of [R.legL,R.legR]){L.th.rotation.x=.25;L.sh.rotation.x=-.4;}break;
  case 'moonwalk':{
   const ph=tt*3;tR.set(.3,.86,-.16);tL.set(-.2,.14,0);sp.rotation.x=.12;
   R.legR.th.rotation.x=s(ph)*.28;R.legL.th.rotation.x=-s(ph)*.28;R.legR.sh.rotation.x=-Math.max(0,s(ph))*.5;R.legL.sh.rotation.x=-Math.max(0,-s(ph))*.5;
   hips.position.z=Math.min(tt*.12,.5);R.head.rotation.z=.06;break;}
  case 'break':{
   R.root.rotation.order='YXZ';R.root.rotation.x=-1.52;R.root.position.y=(st.y||0)+.2;R.root.rotation.y+=tt*8;
   tR.set(.5,.15,-.35);tL.set(-.5,.15,-.35);
   R.legL.th.rotation.x=1.1+s(tt*6)*.55;R.legR.th.rotation.x=1.1-s(tt*6)*.55;R.legL.sh.rotation.x=-.3;R.legR.sh.rotation.x=-.3;break;}
 }
 placeArmsTo(R,tR,tL);
}
