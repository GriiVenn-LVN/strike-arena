/* =====================================================================
   SOL DÉTAILLÉ : texture de détail fine répétée tous les 3 m (grain,
   graviers, pores du béton, neige tassée…) + relief, mélangée au plan
   du sol, et petits objets posés au sol (cailloux, débris, touffes
   d'herbe, feuilles mortes) instanciés en un seul appel de rendu chacun.
   ===================================================================== */
function groundKind(th){
 const b=th.base||(th===THEMES.sand?'sand':th===THEMES.snow?'snow':'industrial');
 if(th===THEMES.jungle)return 'jungle';
 return b==='sand'?'sand':b==='snow'?'snow':b==='haunt'?'haunt':'concrete';
}
// texture de détail centrée sur le gris moyen (multipliée par 2 dans le shader : ne change pas la teinte du plan)
function groundDetailTex(kind){return cached('gdet'+kind,()=>canvasTex(256,256,(c,w,h)=>{
 c.fillStyle='#808080';c.fillRect(0,0,w,h);
 const dot=(n,r0,r1,a0,a1,light)=>{for(let i=0;i<n;i++){const l=light===undefined?Math.random()<.5:light;c.fillStyle='rgba('+(l?'255,255,255':'0,0,0')+','+rand(a0,a1)+')';c.beginPath();c.arc(rand(0,w),rand(0,h),rand(r0,r1),0,TAU);c.fill();}};
 const blob=(n,r0,r1,a)=>{for(let i=0;i<n;i++){const x=rand(0,w),y=rand(0,h),r=rand(r0,r1),l=Math.random()<.5;
  for(const [ox,oy] of [[0,0],[w,0],[-w,0],[0,h],[0,-h]]){const g=c.createRadialGradient(x+ox,y+oy,0,x+ox,y+oy,r);g.addColorStop(0,'rgba('+(l?'255,255,255':'0,0,0')+','+a+')');g.addColorStop(1,'rgba(128,128,128,0)');c.fillStyle=g;c.fillRect(x+ox-r,y+oy-r,r*2,r*2);}}};
 if(kind==='sand'||kind==='jungle'){
  blob(14,20,60,.12);dot(4200,.4,1.1,.08,.25);
  // graviers : petites pierres ombrées en bas à droite
  for(let i=0;i<70;i++){const x=rand(0,w),y=rand(0,h),r=rand(1.2,3.2);c.fillStyle='rgba(0,0,0,.35)';c.beginPath();c.ellipse(x+.8,y+.8,r,r*.8,0,0,TAU);c.fill();c.fillStyle='rgba(255,255,255,'+rand(.2,.45)+')';c.beginPath();c.ellipse(x,y,r,r*.8,rand(0,3),0,TAU);c.fill();}
  if(kind==='jungle'){c.strokeStyle='rgba(0,0,0,.18)';c.lineWidth=.8;for(let i=0;i<40;i++){const x=rand(0,w),y=rand(0,h);c.beginPath();c.moveTo(x,y);c.lineTo(x+rand(-4,4),y-rand(4,9));c.stroke();}}
 }else if(kind==='snow'){
  blob(16,25,70,.1);dot(2600,.3,.9,.05,.18);dot(300,.4,.8,.5,.8,true);   // cristaux qui brillent
  c.strokeStyle='rgba(0,0,0,.08)';c.lineWidth=3;for(let i=0;i<6;i++){c.beginPath();c.moveTo(rand(0,w),0);c.bezierCurveTo(rand(0,w),h*.3,rand(0,w),h*.7,rand(0,w),h);c.stroke();}   // traces tassées
 }else if(kind==='haunt'){
  blob(18,15,50,.18);dot(3600,.4,1.3,.1,.3);
  c.strokeStyle='rgba(0,0,0,.25)';c.lineWidth=.9;for(let i=0;i<120;i++){const x=rand(0,w),y=rand(0,h);c.beginPath();c.moveTo(x,y);c.lineTo(x+rand(-3,3),y-rand(3,7));c.stroke();}
 }else{   // béton : pores, granulats, taches d'huile, micro-fissures
  blob(12,20,55,.1);dot(3800,.3,.9,.06,.2);dot(500,.6,1.4,.25,.45,false);
  for(let i=0;i<4;i++){const x=rand(0,w),y=rand(0,h),r=rand(12,28),g=c.createRadialGradient(x,y,0,x,y,r);g.addColorStop(0,'rgba(0,0,0,.16)');g.addColorStop(1,'rgba(128,128,128,0)');c.fillStyle=g;c.fillRect(x-r,y-r,r*2,r*2);}
  c.strokeStyle='rgba(0,0,0,.3)';c.lineWidth=.7;for(let i=0;i<5;i++){let x=rand(0,w),y=rand(0,h);c.beginPath();c.moveTo(x,y);for(let k=0;k<6;k++){x+=rand(-7,7);y+=rand(-7,7);c.lineTo(x,y);}c.stroke();}
 }
},true,{s:1,noSRGB:true}));}
const GD_REP=3;   // mètres par répétition de la texture de détail
function groundDetail(floor,th){
 if(cfg.gfx<1)return;
 const kind=groundKind(th),dt=groundDetailTex(kind),mat=floor.material;
 const rep=N*S/GD_REP,str=kind==='snow'?.55:kind==='concrete'?.8:1;
 const nrm=autoNormal(dt,kind==='snow'?3:5);
 if(nrm){mat.normalMap=nrm;mat.normalScale=new THREE.Vector2(str,str);}
 mat.onBeforeCompile=sh=>{
  sh.uniforms.uDet={value:dt};sh.uniforms.uDRep={value:rep};sh.uniforms.uDStr={value:kind==='sand'||kind==='jungle'?1.7:str*(kind==='snow'?.6:1)};
  sh.fragmentShader='uniform sampler2D uDet;uniform float uDRep,uDStr;\n'+sh.fragmentShader
   .replace('#include <map_fragment>','#include <map_fragment>\n diffuseColor.rgb*=mix(vec3(1.),texture2D(uDet,vUv*uDRep).rgb*2.,uDStr);')
   .replace('texture2D( normalMap, vUv )','texture2D( normalMap, vUv*uDRep )');
 };
 mat.customProgramCacheKey=()=>'gdet';mat.needsUpdate=true;
 groundClutter(kind);
}
// petits objets au sol, seulement sur les cases libres, loin des points de départ
function groundClutter(kind){
 const free=[];for(let i=0;i<NC;i++){if(G_TYPE[i]||G_RAMP[i]||G_CEIL[i]<90&&kind!=='concrete')continue;free.push(i);}
 if(!free.length)return;
 const nearWall=i=>{const x=i%N,z=(i/N)|0;for(const [dx,dz] of [[1,0],[-1,0],[0,1],[0,-1]]){const X=x+dx,Z=z+dz;if(X>=0&&Z>=0&&X<N&&Z<N&&G_TYPE[Z*N+X]&&G_TYPE[Z*N+X]!==TY.BARREL)return [dx,dz];}return null;};
 const mt=new THREE.Matrix4(),q=new THREE.Quaternion(),e=new THREE.Euler(),p=V3(),s=V3(),col=new THREE.Color();
 const place=(geo,mat,n,pick2,colFn)=>{const m=new THREE.InstancedMesh(geo,mat,n);let k=0;
  for(let t=0;t<n*3&&k<n;t++){const r=pick2();if(!r)continue;const [x,z,sc,ry,y]=r;
   p.set(x,(y||0)+groundH(x,z),z);e.set(rand(-.3,.3),ry,rand(-.3,.3));q.setFromEuler(e);s.set(sc,sc*rand(.6,1),sc);mt.compose(p,q,s);m.setMatrixAt(k,mt);
   if(colFn){col.set(colFn());m.setColorAt(k,col);}k++;}
  m.count=k;m.receiveShadow=true;worldG.add(m);return m;};
 const anyCell=()=>{const i=free[(Math.random()*free.length)|0];return [cc(i%N)+rand(-S/2,S/2),cc((i/N)|0)+rand(-S/2,S/2)];};
 const wallCell=()=>{const i=free[(Math.random()*free.length)|0],w=nearWall(i);if(!w)return null;return [cc(i%N)+w[0]*rand(.55,.92)+(w[0]?0:rand(-.95,.95)),cc((i/N)|0)+w[1]*rand(.55,.92)+(w[1]?0:rand(-.95,.95))];};
 // cailloux (pierres plus nombreuses au pied des murs)
 const pg=new THREE.IcosahedronGeometry(1,0);pg.translate(0,.35,0);
 const pc={sand:[0x9c8b6c,0xb6a27e,0x7e6f56],jungle:[0x6f6a5a,0x857c66,0x5a5648],snow:[0x6c727c,0x858b95,0x9aa1ab],haunt:[0x4a4842,0x3b3a36,0x5a574f],concrete:[0x6a6d72,0x7d8086,0x55585d]}[kind];
 place(pg,stdMat(0xffffff,{roughness:.95}),kind==='snow'?60:260,()=>{const w=Math.random()<.6?wallCell():anyCell();return w?[w[0],w[1],rand(.05,.17),rand(0,TAU),-.05]:null;},()=>pick(pc));
 if(kind==='concrete'){   // débris : éclats de béton, papiers, mégots de chantier
  const dg=new THREE.BoxGeometry(1,1,1);place(dg,stdMat(0xffffff,{roughness:.9}),60,()=>{const w=wallCell();return w?[w[0],w[1],rand(.05,.16),rand(0,TAU),.02]:null;},()=>pick([0x8d9096,0x6e7176,0xa7a9ad]));
  const paper=new THREE.PlaneGeometry(1,1);paper.rotateX(-Math.PI/2);
  place(paper,stdMat(0xffffff,{roughness:.85,side:THREE.DoubleSide}),35,()=>{const a=anyCell();return [a[0],a[1],rand(.15,.3),rand(0,TAU),.012];},()=>pick([0xe8e4da,0xd9d2c0,0xc9c0a8]));
 }
 // touffes d'herbe sèche ou verte au pied des murs (pas sur la neige ni dans les halles)
 if(kind==='sand'||kind==='jungle'||kind==='haunt'){
  const tex=cached('tuft'+kind,()=>{const t=canvasTex(64,64,(c,w,h)=>{c.clearRect(0,0,w,h);
   for(let i=0;i<34;i++){const x=w/2+rand(-20,20),hh=rand(h*.45,h*.98),lean=rand(-14,14);
    c.strokeStyle=kind==='sand'?'hsl('+rand(38,55)+','+rand(30,50)+'%,'+rand(42,62)+'%)':kind==='jungle'?'hsl('+rand(85,110)+','+rand(40,60)+'%,'+rand(25,40)+'%)':'hsl('+rand(60,90)+','+rand(15,30)+'%,'+rand(18,30)+'%)';
    c.lineWidth=rand(1,2);c.beginPath();c.moveTo(x,h);c.quadraticCurveTo(x+lean*.3,h-hh*.6,x+lean,h-hh);c.stroke();}},false,{s:1});t.premultiplyAlpha=false;return t;});
  const tm=new THREE.MeshStandardMaterial({map:tex,alphaTest:.4,side:THREE.DoubleSide,roughness:.9});
  const tg=new THREE.PlaneGeometry(.7,.55);tg.translate(0,.27,0);const t2=tg.clone();t2.rotateY(Math.PI/2);
  const merged=new THREE.BufferGeometry();
  for(const a of ['position','normal','uv'])merged.setAttribute(a,new THREE.BufferAttribute(new Float32Array([...tg.attributes[a].array,...t2.attributes[a].array]),tg.attributes[a].itemSize));
  merged.setIndex([...tg.index.array,...t2.index.array.map(v=>v+tg.attributes.position.count)]);
  place(merged,tm,kind==='jungle'?260:170,()=>{const w=wallCell();return w?[w[0],w[1],rand(.7,1.4),rand(0,TAU),0]:null;},()=>{const v=rand(.8,1.1);return new THREE.Color(v,v,v);});
 }
 // feuilles mortes plaquées au sol
 if(kind==='jungle'||kind==='haunt'||kind==='sand'){
  const lt=leafTex('broad'),lg=new THREE.PlaneGeometry(1,1.6);lg.rotateX(-Math.PI/2);
  const lm=new THREE.MeshStandardMaterial({map:lt,alphaTest:.45,side:THREE.DoubleSide,roughness:.9});
  place(lg,lm,kind==='sand'?40:140,()=>{const a=Math.random()<.5?wallCell():anyCell();return a?[a[0],a[1],rand(.08,.16),rand(0,TAU),.015]:null;},()=>pick(kind==='jungle'?[0x9a7a40,0x7a8a40,0xb08a50,0x6a5a30]:[0x8a6a40,0x6a5a3a,0xa08050]));
 }
}
