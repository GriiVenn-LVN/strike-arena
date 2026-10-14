/* =====================================================================
   THÈMES ET DÉCORS : nuit (port), métro, jungle, stand de tir
   ===================================================================== */
THEMES.night={base:'industrial',sky:[[0,'#03050c'],[.28,'#091028'],[.45,'#1b2c58'],[.5,'#2c4284'],[.52,'#0b1220'],[1,'#05080f']],
 fog:0x0b1426,fogN:22,fogF:120,hemiS:0x4a5aa0,hemiG:0x141a2a,hemiI:.36,sunC:0x9ab4ff,sunI:.95,sunPos:[-55,60,35],exp:1.15,env:.35,cloud:'90,110,170',cov:.32};
THEMES.metro={base:'industrial',sky:[[0,'#0a0c12'],[.5,'#1a1e28'],[1,'#0a0c12']],
 fog:0x161a22,fogN:18,fogF:90,hemiS:0xdfe8ff,hemiG:0x40454f,hemiI:1.05,sunC:0xdde6ff,sunI:.2,sunPos:[10,80,10],exp:1.3,env:.5,cloud:'60,70,90',cov:0};
THEMES.jungle={base:'sand',sky:[[0,'#1f78d8'],[.3,'#58b0ee'],[.46,'#bfe6f4'],[.5,'#e8f6e0'],[.52,'#a8c898'],[1,'#6f9a6a']],
 fog:0xa6cfa0,fogN:30,fogF:145,hemiS:0xcfe8ff,hemiG:0x4a6a3a,hemiI:.78,sunC:0xfff4d0,sunI:2.5,sunPos:[40,85,30],exp:.95,env:.6,cloud:'255,255,255',tint:0xdde8cf,cov:.5};
THEMES.range={base:'industrial',sky:[[0,'#4a86d0'],[.3,'#8cbcea'],[.46,'#dfeaf4'],[.5,'#f2f2ee'],[.52,'#c8c8c4'],[1,'#a0a09a']],
 fog:0xd3dee8,fogN:55,fogF:195,hemiS:0xdfe9ff,hemiG:0x8a8f96,hemiI:.72,sunC:0xfff6e0,sunI:2.3,sunPos:[50,80,30],exp:.95,env:.7,cloud:'255,255,255'};

function texTrain(hm){return cached('train'+hm,()=>canvasTex(128,Math.round(PX*hm),(c,w,h)=>{
 const g=c.createLinearGradient(0,0,0,h);g.addColorStop(0,'#e8edf4');g.addColorStop(1,'#b9c4d4');c.fillStyle=g;c.fillRect(0,0,w,h);
 c.fillStyle='#2a63c4';c.fillRect(0,h*.62,w,h*.12);c.fillStyle='#ffd23a';c.fillRect(0,h*.74,w,4);
 c.fillStyle='#1d2736';c.fillRect(10,h*.14,w-20,h*.34);c.fillStyle='rgba(140,200,255,.35)';c.fillRect(14,h*.16,40,h*.3);c.fillRect(w/2+6,h*.16,40,h*.3);
 c.fillStyle='#8a97a8';c.fillRect(w/2-2,h*.1,4,h*.4);speck(c,w,h,300,.03,.1,4);streaks(c,w,h,8,'60,60,70',.25);
 c.fillStyle='rgba(255,255,255,.8)';c.font='bold 13px Arial';c.textAlign='center';c.fillText('M'+Math.floor(rand(1,9)),w/2,h*.95);
}));}
function signTex(txt,bg,fg){return canvasTex(256,96,(c,w,h)=>{c.fillStyle=bg;c.fillRect(0,0,w,h);c.strokeStyle=fg;c.lineWidth=5;c.strokeRect(6,6,w-12,h-12);c.fillStyle=fg;c.font='bold 54px Arial';c.textAlign='center';c.textBaseline='middle';c.fillText(txt,w/2,h/2+3);});}
const bannerTex=(txt,c1,c2)=>canvasTex(256,128,(c,w,h)=>{const g=c.createLinearGradient(0,0,0,h);g.addColorStop(0,c1);g.addColorStop(1,c2);c.fillStyle=g;c.fillRect(0,0,w,h);c.strokeStyle='rgba(255,255,255,.85)';c.lineWidth=6;c.strokeRect(8,8,w-16,h-16);c.fillStyle='#fff';c.font='bold 74px Arial';c.textAlign='center';c.textBaseline='middle';c.fillText(txt,w/2,h/2+4);});
const mapBanners=(y)=>{clothMesh(7,3.5,bannerTex('CT','#3a7de0','#1b3f86'),40,y||3.6,2.05,0,.1);clothMesh(7,3.5,bannerTex('T','#e0662d','#8a2f10'),40,y||3.6,N*S-2.05,Math.PI,.1);};
function floodlight(x,z,h,col,pl){
 const steel=stdMat(0x4a525c,{metalness:.7,roughness:.45});
 const p=new THREE.Mesh(new THREE.CylinderGeometry(.12,.16,h,8),steel);p.position.set(x,h/2,z);p.castShadow=true;worldG.add(p);
 const lamp=new THREE.Mesh(GBOX,new THREE.MeshStandardMaterial({color:0x222222,emissive:new THREE.Color(col||0xffe2b0),emissiveIntensity:2.4}));lamp.scale.set(1,.35,.55);lamp.position.set(x,h+.1,z);worldG.add(lamp);
 glowSprite(x,h+.1,z,'warm',4,.7,true);
 if(pl){const L=new THREE.PointLight(col||0xffe2b0,pl,26,2);L.position.set(x,h-.5,z);worldG.add(L);}
}
function stars(n,rad){
 const pos=new Float32Array(n*3);for(let i=0;i<n;i++){const a=rand(0,TAU),e=rand(.08,1.2),r=rad;pos[i*3]=Math.cos(a)*r*Math.cos(e);pos[i*3+1]=r*Math.sin(e);pos[i*3+2]=Math.sin(a)*r*Math.cos(e);}
 const g=new THREE.BufferGeometry();g.setAttribute('position',new THREE.BufferAttribute(pos,3));
 const p=new THREE.Points(g,new THREE.PointsMaterial({color:0xffffff,size:1.6,sizeAttenuation:false,transparent:true,opacity:.9,fog:false,depthWrite:false}));skyG.add(p);
}
DECOR.harbor=function(th){
 stars(380,185);
 mapBanners(3.8);
 for(const [cx,cz] of [[2,2],[12,2],[27,2],[37,2],[10,14],[29,14],[20,10],[20,26],[2,26],[37,27],[12,34],[27,34],[2,38],[37,38]])floodlight(cc(cx),cc(cz),6.6,0xffe2b0,0);
 for(const [x,z] of [[20,20],[20,56],[14,40],[66,40]]){const L=new THREE.PointLight(0xffe2b0,14,30,2);L.position.set(x,6,z);worldG.add(L);}
 // grue portuaire (hors de l'enceinte)
 const red=stdMat(0xb8321e,{metalness:.5,roughness:.5}),dk=stdMat(0x2a2f36,{metalness:.6,roughness:.5});
 const crane=new THREE.Group();crane.position.set(-12,0,48);
 for(const [x,z] of [[-3,-4],[3,-4],[-3,4],[3,4]]){const l=new THREE.Mesh(GBOX,red);l.scale.set(.8,26,.8);l.position.set(x,13,z);crane.add(l);}
 const beam=new THREE.Mesh(GBOX,red);beam.scale.set(8,1.6,44);beam.position.set(0,26,10);crane.add(beam);
 const cab=new THREE.Mesh(GBOX,dk);cab.scale.set(3,3,3.5);cab.position.set(2.6,23.6,-2);crane.add(cab);
 const cable=new THREE.Mesh(GBOX,dk);cable.scale.set(.15,10,.15);cable.position.set(0,20,22);crane.add(cable);
 const lt=new THREE.Mesh(GBOX,new THREE.MeshStandardMaterial({color:0x222222,emissive:0xff2a2a,emissiveIntensity:2}));lt.scale.set(.6,.6,.6);lt.position.set(0,27,31);crane.add(lt);
 worldG.add(crane);let ph=rand(0,6);worldAnim.push(t=>{lt.material.emissiveIntensity=1+Math.sin(t*3+ph)*1;crane.rotation.y=Math.sin(t*.05)*.02;});
 // cargo à quai
 const hull=new THREE.Mesh(GBOX,stdMat(0x7a1f1f,{metalness:.4,roughness:.6}));hull.scale.set(22,9,80);hull.position.set(-32,2,40);worldG.add(hull);
 const sup=new THREE.Mesh(GBOX,stdMat(0xe8ecf2,{roughness:.5}));sup.scale.set(14,12,16);sup.position.set(-32,12,70);worldG.add(sup);
 for(let i=0;i<30;i++){const c=new THREE.Mesh(GBOX,stdMat(pick([0xc0392b,0x2e86c1,0xd68910,0x239b56,0x6c7a89]),{roughness:.6,metalness:.4}));c.scale.set(5,2.6,12);c.position.set(-30+((i%3)-1)*5.2,7.8+Math.floor(i/15)*2.7,12+((i%15))*4.2);worldG.add(c);}
 // eau : vagues animées
 const w=worldG.children.find(o=>o.geometry&&o.geometry.type==='PlaneGeometry'&&o.geometry.parameters.width===600);
 if(w){w.position.y=-.35;worldAnim.push(t=>{w.material.color.setHSL(.6,.65,.07+Math.sin(t*.6)*.01);});}
};
DECOR.metro=function(th){
 mapBanners(3.0);
 // tubes fluorescents au plafond
 const tube=new THREE.MeshStandardMaterial({color:0xffffff,emissive:new THREE.Color(0xe6f0ff),emissiveIntensity:2.4});
 const tubes=new THREE.InstancedMesh(GBOX,tube,70),mt=new THREE.Matrix4(),q=new THREE.Quaternion(),v=new THREE.Vector3();let n=0;
 for(let cz=3;cz<38;cz+=5)for(let cx=3;cx<38;cx+=6){mt.compose(v.set(cc(cx),4.28,cc(cz)),q,new THREE.Vector3(2.4,.06,.26));tubes.setMatrixAt(n++,mt);}
 tubes.count=n;tubes.frustumCulled=false;worldG.add(tubes);
 const flick=[];for(const [cx,cz] of [[6,6],[33,6],[20,4],[6,20],[33,20],[20,12],[20,26],[6,34],[33,34],[20,36]]){const L=new THREE.PointLight(0xe6f0ff,22,22,2);L.position.set(cc(cx),3.9,cc(cz));worldG.add(L);flick.push(L);}
 worldAnim.push(t=>{flick.forEach((L,i)=>{L.intensity=20+(Math.sin(t*(2+i))*0.0+((Math.sin(t*37+i*5)>.985)?-14:0));});});
 // panneaux de station
 const sg=(txt,bg,fg,x,y,z,ry)=>{const m=new THREE.Mesh(new THREE.PlaneGeometry(5,1.9),new THREE.MeshStandardMaterial({map:signTex(txt,bg,fg),emissive:0xffffff,emissiveMap:signTex(txt,bg,fg),emissiveIntensity:.8}));m.position.set(x,y,z);m.rotation.y=ry||0;worldG.add(m);};
 sg('SITE A','#12202f','#ffd23a',2.1,3.5,40,Math.PI/2);sg('SITE B','#12202f','#ffd23a',N*S-2.1,3.5,40,-Math.PI/2);
 sg('VOIES 1 · 2','#0f1d44','#ffffff',40,3.4,34.2,0);sg('SORTIE','#0f4a2a','#c8ffd8',40,3.4,46,Math.PI);
 // affiches publicitaires
 for(const [x,z,ry,c1,c2,t] of [[2.1,20,Math.PI/2,'#ff6a8a','#ffd86a','PIZZA'],[2.1,60,Math.PI/2,'#6ad0ff','#2a6aff','TAXI'],[N*S-2.1,20,-Math.PI/2,'#7aff9a','#1a8a4a','FRUITS'],[N*S-2.1,60,-Math.PI/2,'#ffb86a','#ff4a2a','JAZZ']]){const m=new THREE.Mesh(new THREE.PlaneGeometry(4,2.6),new THREE.MeshStandardMaterial({map:bannerTex(t,c1,c2)}));m.position.set(x,2.6,z);m.rotation.y=ry;worldG.add(m);}
 // bandes jaunes au bord des quais
 const strip=stdMat(0xe8c020,{roughness:.6});for(const z of [30.1,47.9]){const s=new THREE.Mesh(GBOX,strip);s.scale.set(28,.04,.5);s.position.set(40,1.24,z);worldG.add(s);}
};
DECOR.jungle=function(th){
 mapBanners(3.6);
 for(const [px,pz,s] of [[1,1,1.2],[38,1,1.3],[12,1,1],[25,1,1.1],[1,38,1.2],[38,38,1.2],[13,38,1],[26,38,1.1],[12,13,1.3],[27,13,1.2],[13,28,1.1],[26,28,1.2],[1,20,1.1],[38,20,1.2],[10,31,1],[30,31,1.1]])palmTree(px,pz,s);
 for(const [cx,cz] of [[16,3],[23,3],[3,8],[8,6],[34,3],[37,3],[28,9],[6,29],[33,29]])lantern(cc(cx),3.0,cc(cz),0xff9a30);
 // sous-bois : fougères et feuilles larges au pied des murs (décor, sans collision)
 let nf=0;for(let i=0;i<NC&&nf<110;i++){if(G_TYPE[i]||G_RAMP[i])continue;const x=i%N,z=(i/N)|0;
  for(const [dx,dz] of [[1,0],[-1,0],[0,1],[0,-1]]){const j=(z+dz)*N+x+dx;if(x+dx<0||z+dz<0||x+dx>=N||z+dz>=N||G_TYPE[j]!==TY.WALL||Math.random()>.3)continue;
   fernClump(cc(x)+dx*(S/2-.45)+rand(-.5,.5),cc(z)+dz*(S/2-.45)+rand(-.5,.5),rand(.9,1.4),Math.random()<.3?'broad':'fern');nf++;break;}}
 // lianes : chapelets de feuilles qui pendent des murs
 const vm=leafMat('broad'),vg=leafGeo(.32,.2,.3,2),stem=stdMat(0x3d5a26,{roughness:1});
 for(let i=0;i<22;i++){const x=cc(rand(28,38)),z=cc(rand(1,5)),h=rand(1.5,3.2),g=new THREE.Group();g.position.set(x,3.6,z);
  const st=new THREE.Mesh(new THREE.CylinderGeometry(.015,.015,h,4),stem);st.position.y=-h/2;g.add(st);
  for(let y=.2;y<h;y+=rand(.18,.3))addLeaf(g,vg,vm,rand(-.03,.03),-y,0,rand(0,TAU),-rand(1.8,2.6));
  mergeLeaves(g);worldG.add(g);const ph=rand(0,TAU);worldAnim.push(t=>{g.rotation.z=Math.sin(t*1.2+ph)*.05;});}
 // idole d'or au sommet de la pyramide
 const gold=new THREE.MeshStandardMaterial({color:C(0xf3c040),metalness:1,roughness:.2});
 const ped=new THREE.Mesh(GBOX,stdMat(0x8a8a7a));ped.scale.set(1.4,.6,1.4);ped.position.set(40,3.9,37);worldG.add(ped);
 const idol=new THREE.Mesh(new THREE.OctahedronGeometry(.5,0),gold);idol.position.set(40,4.7,37);worldG.add(idol);glowSprite(40,4.7,37,'warm',3.5,.9,true);
 worldAnim.push(t=>{idol.rotation.y=t*.8;idol.position.y=4.7+Math.sin(t*1.5)*.1;});
 // brume au sol
 for(let i=0;i<14;i++){if(typeof fxReady!=='undefined'&&fxReady)continue;}
};
DECOR.range=function(th){
 mapBanners(3.6);
 for(const [cx,cz] of [[5,5],[35,5],[5,20],[35,20],[20,33]])floodlight(cc(cx),cc(cz),6,0xfff0d0,0);
 // panneaux de distance
 for(const [m,cz] of [[10,29],[20,24],[30,19],[40,14],[50,9]]){const s=new THREE.Mesh(new THREE.PlaneGeometry(2.4,.9),new THREE.MeshStandardMaterial({map:signTex(m+' m','#14202c','#ffe14a')}));s.position.set(2.2,1.6,cc(cz));s.rotation.y=Math.PI/2;worldG.add(s);}
};
