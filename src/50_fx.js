/* =====================================================================
   EFFETS : particules (GPU Points), impacts, douilles, tracers,
   fumée, explosions, poussière ambiante
   ===================================================================== */
const PSOFT=canvasTex(64,64,(c)=>{const g=c.createRadialGradient(32,32,0,32,32,32);g.addColorStop(0,'rgba(255,255,255,1)');g.addColorStop(.35,'rgba(255,255,255,.7)');g.addColorStop(1,'rgba(255,255,255,0)');c.fillStyle=g;c.fillRect(0,0,64,64);});
const PSMOKE=canvasTex(128,128,(c)=>{
 const g=c.createRadialGradient(64,64,0,64,64,64);g.addColorStop(0,'rgba(255,255,255,.9)');g.addColorStop(.6,'rgba(255,255,255,.45)');g.addColorStop(1,'rgba(255,255,255,0)');c.fillStyle=g;c.fillRect(0,0,128,128);
 for(let i=0;i<30;i++){const x=rand(20,108),y=rand(20,108),r=rand(8,22),gg=c.createRadialGradient(x,y,0,x,y,r);gg.addColorStop(0,'rgba(255,255,255,.25)');gg.addColorStop(1,'rgba(255,255,255,0)');c.globalCompositeOperation='source-atop';c.fillStyle=gg;c.fillRect(x-r,y-r,r*2,r*2);}
});
class PSys{
 constructor(cap,tex,additive){
  this.cap=cap;this.i=0;
  this.pos=new Float32Array(cap*3);this.col=new Float32Array(cap*4);this.size=new Float32Array(cap);
  this.vel=new Float32Array(cap*3);this.life=new Float32Array(cap);this.max=new Float32Array(cap);this.s0=new Float32Array(cap);this.s1=new Float32Array(cap);this.a0=new Float32Array(cap);this.grav=new Float32Array(cap);this.drag=new Float32Array(cap);this.rgb=new Float32Array(cap*3);
  const g=new THREE.BufferGeometry();
  g.setAttribute('position',new THREE.BufferAttribute(this.pos,3).setUsage(THREE.DynamicDrawUsage));
  g.setAttribute('color',new THREE.BufferAttribute(this.col,4).setUsage(THREE.DynamicDrawUsage));
  g.setAttribute('size',new THREE.BufferAttribute(this.size,1).setUsage(THREE.DynamicDrawUsage));
  this.geo=g;
  this.mat=new THREE.ShaderMaterial({uniforms:{map:{value:tex},scale:{value:500}},transparent:true,depthWrite:false,blending:additive?THREE.AdditiveBlending:THREE.NormalBlending,
   vertexShader:'attribute float size;attribute vec4 color;varying vec4 vC;uniform float scale;void main(){vC=color;vec4 mv=modelViewMatrix*vec4(position,1.0);gl_PointSize=size*scale/max(0.1,-mv.z);gl_Position=projectionMatrix*mv;}',
   fragmentShader:'uniform sampler2D map;varying vec4 vC;void main(){vec4 t=texture2D(map,gl_PointCoord);gl_FragColor=vec4(vC.rgb,vC.a*t.a);if(gl_FragColor.a<0.004)discard;}'});
  this.pts=new THREE.Points(g,this.mat);this.pts.frustumCulled=false;this.pts.renderOrder=3;
  for(let k=0;k<cap;k++){this.life[k]=0;this.col[k*4+3]=0;this.pos[k*3+1]=-999;}
 }
 emit(x,y,z,vx,vy,vz,life,s0,s1,r,g,b,a,grav,drag){
  const k=this.i;this.i=(this.i+1)%this.cap;
  this.pos[k*3]=x;this.pos[k*3+1]=y;this.pos[k*3+2]=z;this.vel[k*3]=vx;this.vel[k*3+1]=vy;this.vel[k*3+2]=vz;
  this.life[k]=life;this.max[k]=life;this.s0[k]=s0;this.s1[k]=s1;this.rgb[k*3]=r;this.rgb[k*3+1]=g;this.rgb[k*3+2]=b;this.a0[k]=a;this.grav[k]=grav||0;this.drag[k]=drag||0;
 }
 update(dt){
  const n=this.cap;let any=false;
  for(let k=0;k<n;k++){
   if(this.life[k]<=0)continue;any=true;
   this.life[k]-=dt;
   if(this.life[k]<=0){this.col[k*4+3]=0;this.pos[k*3+1]=-999;continue;}
   const t=1-this.life[k]/this.max[k],dr=Math.exp(-this.drag[k]*dt);
   this.vel[k*3]*=dr;this.vel[k*3+2]*=dr;this.vel[k*3+1]=this.vel[k*3+1]*dr-this.grav[k]*dt;
   this.pos[k*3]+=this.vel[k*3]*dt;this.pos[k*3+1]+=this.vel[k*3+1]*dt;this.pos[k*3+2]+=this.vel[k*3+2]*dt;
   if(this.pos[k*3+1]<.02&&this.grav[k]>0){this.pos[k*3+1]=.02;this.vel[k*3+1]*=-.2;this.vel[k*3]*=.6;this.vel[k*3+2]*=.6;}
   this.size[k]=this.s0[k]+(this.s1[k]-this.s0[k])*t;
   const fade=t<.12?t/.12:Math.pow(1-t,1.3);
   this.col[k*4]=this.rgb[k*3];this.col[k*4+1]=this.rgb[k*3+1];this.col[k*4+2]=this.rgb[k*3+2];this.col[k*4+3]=this.a0[k]*fade;
  }
  if(any){this.geo.attributes.position.needsUpdate=true;this.geo.attributes.color.needsUpdate=true;this.geo.attributes.size.needsUpdate=true;}
 }
}
let fxN=null,fxA=null,fxSmoke=null,decals=null,motes=null,fxReady=false;
const flashLight=new THREE.PointLight(0xffc880,0,16,2);
const shells=[],tracers=[];let shellMesh=null;
function initFX(){
 if(fxReady)return;fxReady=true;
 fxN=new PSys(900,PSOFT,false);fxA=new PSys(900,PSOFT,true);fxSmoke=new PSys(1400,PSMOKE,false);
 scene.add(fxN.pts,fxA.pts,fxSmoke.pts,flashLight);
 // décalques
 const dtex=canvasTex(32,32,(c)=>{const g=c.createRadialGradient(16,16,0,16,16,16);g.addColorStop(0,'rgba(10,8,5,.95)');g.addColorStop(.45,'rgba(20,14,8,.7)');g.addColorStop(1,'rgba(20,14,8,0)');c.fillStyle=g;c.fillRect(0,0,32,32);});
 decals=new PSys(160,dtex,false);for(let k=0;k<160;k++){decals.life[k]=0;}decals.pts.renderOrder=2;scene.add(decals.pts);
 decals.persist=true;decals.dI=0;
 // poussière ambiante
 const mg=new THREE.BufferGeometry(),mp=new Float32Array(260*3),mc=new Float32Array(260*4),ms=new Float32Array(260);
 for(let i=0;i<260;i++){mp[i*3]=rand(-25,25);mp[i*3+1]=rand(.3,12);mp[i*3+2]=rand(-25,25);mc[i*4]=1;mc[i*4+1]=.95;mc[i*4+2]=.85;mc[i*4+3]=rand(.1,.35);ms[i]=rand(.025,.07);}
 mg.setAttribute('position',new THREE.BufferAttribute(mp,3));mg.setAttribute('color',new THREE.BufferAttribute(mc,4));mg.setAttribute('size',new THREE.BufferAttribute(ms,1));
 motes={geo:mg,pos:mp,pts:new THREE.Points(mg,new THREE.ShaderMaterial({uniforms:{map:{value:PSOFT},scale:{value:500}},transparent:true,depthWrite:false,blending:THREE.AdditiveBlending,vertexShader:fxN.mat.vertexShader,fragmentShader:fxN.mat.fragmentShader}))};
 motes.pts.frustumCulled=false;scene.add(motes.pts);
 // douilles
 shellMesh=new THREE.InstancedMesh(new THREE.CylinderGeometry(.006,.006,.03,6),new THREE.MeshStandardMaterial({color:C(0xd4a73a),metalness:1,roughness:.3}),48);
 shellMesh.frustumCulled=false;shellMesh.count=0;scene.add(shellMesh);
 for(let i=0;i<48;i++)shells.push({on:false,x:0,y:0,z:0,vx:0,vy:0,vz:0,rx:0,rz:0,wx:0,wz:0,t:0,bounced:0});
 // tracers
 for(let i=0;i<40;i++){
  const geo=new THREE.BufferGeometry();geo.setAttribute('position',new THREE.BufferAttribute(new Float32Array(6),3));geo.setAttribute('color',new THREE.BufferAttribute(new Float32Array([1,.85,.4,1,.95,.8]),3));
  const l=new THREE.Line(geo,new THREE.LineBasicMaterial({vertexColors:true,transparent:true,opacity:0,blending:THREE.AdditiveBlending,depthWrite:false,toneMapped:false}));
  l.visible=false;l.frustumCulled=false;l.userData.life=0;scene.add(l);tracers.push(l);
 }
}
let tIdx=0,shIdx=0;
function updateFXUniforms(){
 const s=renderer.domElement.height/(2*Math.tan(camera.fov*RAD/2));
 for(const p of [fxN,fxA,fxSmoke,decals])if(p)p.mat.uniforms.scale.value=s;
 if(motes)motes.pts.material.uniforms.scale.value=s;
}
const fxMul=()=>cfg.fx?1:.25;
function addTracer(x0,y0,z0,x1,y1,z1,col){
 if(!fxReady)return;
 const l=tracers[tIdx++%tracers.length],p=l.geometry.attributes.position.array;
 if(l.userData.d===undefined)l.userData.d=l.material.color.getHex();l.material.color.setHex(col!==undefined?col:l.userData.d);
 // segment court qui voyage (30 m max de traînée)
 const dx=x1-x0,dy=y1-y0,dz=z1-z0,L=Math.hypot(dx,dy,dz),tail=Math.min(L,22);
 p[0]=x1-dx/L*tail;p[1]=y1-dy/L*tail;p[2]=z1-dz/L*tail;p[3]=x1;p[4]=y1;p[5]=z1;
 l.geometry.attributes.position.needsUpdate=true;l.visible=true;l.userData.life=.09;l.material.opacity=.9;
}
function fxDust(x,y,z,n,sz){if(!fxReady)return;n=Math.ceil(n*fxMul());for(let i=0;i<n;i++)fxN.emit(x+rand(-.05,.05),y,z+rand(-.05,.05),rand(-.5,.5),rand(.2,1),rand(-.5,.5),rand(.5,.9),(sz||.12)*.6,(sz||.12)*2.4,.78,.68,.52,.42,-.2,1.5);}
function fxSpark(x,y,z,n,dir){if(!fxReady)return;n=Math.ceil(n*fxMul());for(let i=0;i<n;i++){const s=rand(1.5,4.5);fxA.emit(x,y,z,(dir?-dir[0]:0)*s*.5+rand(-1,1)*s*.6,(dir?-dir[1]:0)*s*.3+rand(.4,1.4)*s*.6,(dir?-dir[2]:0)*s*.5+rand(-1,1)*s*.6,rand(.15,.4),.05,.02,1,.78,.35,1,9,.5);}}
function fxBlood(x,y,z,dir,n,big){if(!fxReady)return;n=Math.ceil(n*fxMul());for(let i=0;i<n;i++){const s=rand(1,3.5);fxN.emit(x,y,z,-dir[0]*s*.4+rand(-1,1)*s*.5,-dir[1]*s*.3+rand(-.2,1)*s*.5,-dir[2]*s*.4+rand(-1,1)*s*.5,rand(.35,.7),(big?.09:.06),(big?.2:.12),.62,.04,.05,.9,9,1.2);}}
function fxMuzzleSmoke(x,y,z,dx,dy,dz){if(!fxReady)return;fxN.emit(x,y,z,dx*.8+rand(-.2,.2),dy*.8+.2,dz*.8+rand(-.2,.2),rand(.5,.9),.05,.28,.75,.75,.75,.26,-.1,1.6);}
function addHole(x,y,z){
 if(!fxReady)return;const k=decals.dI++%decals.cap;decals.pos[k*3]=x;decals.pos[k*3+1]=y;decals.pos[k*3+2]=z;decals.size[k]=.16+Math.random()*.06;decals.col[k*4]=1;decals.col[k*4+1]=1;decals.col[k*4+2]=1;decals.col[k*4+3]=.95;
 decals.geo.attributes.position.needsUpdate=true;decals.geo.attributes.color.needsUpdate=true;decals.geo.attributes.size.needsUpdate=true;
}
function clearDecals(){if(!decals)return;for(let k=0;k<decals.cap;k++){decals.col[k*4+3]=0;decals.pos[k*3+1]=-999;}decals.geo.attributes.color.needsUpdate=true;decals.geo.attributes.position.needsUpdate=true;}
function ejectShell(x,y,z,yaw,side){
 if(!fxReady||!cfg.fx)return;const s=shells[shIdx++%shells.length];
 s.on=true;s.x=x;s.y=y;s.z=z;const sp=rand(1.6,2.6);
 s.vx=Math.cos(yaw)*sp*(side||1)+rand(-.3,.3);s.vy=rand(1.6,2.6);s.vz=-Math.sin(yaw)*sp*(side||1)+rand(-.3,.3);
 s.wx=rand(-14,14);s.wz=rand(-14,14);s.rx=rand(0,6);s.rz=rand(0,6);s.t=2.4;s.bounced=0;
}
const _sm=new THREE.Matrix4(),_sq=new THREE.Quaternion(),_se=new THREE.Euler(),_sp=new THREE.Vector3(),_ss=new THREE.Vector3(1,1,1);
function updateShells(dt){
 if(!shellMesh)return;let n=0;
 for(const s of shells){
  if(!s.on)continue;s.t-=dt;if(s.t<=0){s.on=false;continue;}
  s.vy-=14*dt;s.x+=s.vx*dt;s.y+=s.vy*dt;s.z+=s.vz*dt;s.rx+=s.wx*dt;s.rz+=s.wz*dt;
  const g=groundH(s.x,s.z)+.006;
  if(s.y<g){s.y=g;if(Math.abs(s.vy)>1&&s.bounced<2){s.vy*=-.35;s.vx*=.5;s.vz*=.5;s.bounced++;if(Math.random()<.5)sfx('shell',s.x,s.z,.5);}else{s.vy=0;s.vx*=.7;s.vz*=.7;s.wx*=.5;s.wz*=.5;}}
  _se.set(s.rx,0,s.rz);_sq.setFromEuler(_se);_sp.set(s.x,s.y,s.z);_sm.compose(_sp,_sq,_ss);shellMesh.setMatrixAt(n++,_sm);
 }
 shellMesh.count=n;shellMesh.instanceMatrix.needsUpdate=true;
}
/* fumée */
function spawnSmoke(x,y,z){
 smokes.push({x,y:y+1.3,z,r:3.6,t:18,age:0,em:0});
}
function updateSmokes(dt){
 for(let i=smokes.length-1;i>=0;i--){
  const s=smokes[i];s.age+=dt;s.t-=dt;
  if(s.age<3.2&&fxReady){const n=Math.ceil(36*dt*60/60);for(let k=0;k<n;k++){const a=rand(0,TAU),b=rand(-.4,1),rr=rand(0,s.r*.85);fxSmoke.emit(s.x+Math.cos(a)*rr,s.y-1+Math.max(0,b)*2.4,s.z+Math.sin(a)*rr,rand(-.25,.25),rand(.05,.3),rand(-.25,.25),rand(13,17),1.6,2.8+rand(0,1),.78,.8,.82,.62,0,.2);}}
  if(s.t<=0)smokes.splice(i,1);
 }
}
/* explosion */
let boomRings=[];
function fxExplosion(x,y,z,scale){
 if(!fxReady)return;scale=scale||1;
 for(let i=0;i<Math.ceil(16*fxMul());i++)fxA.emit(x+rand(-.3,.3),y+rand(0,.6),z+rand(-.3,.3),rand(-2,2)*scale,rand(1,5)*scale,rand(-2,2)*scale,rand(.4,.8),1.2*scale,2.8*scale,1,.55,.15,.95,-.5,2);
 for(let i=0;i<Math.ceil(26*fxMul());i++)fxN.emit(x+rand(-.5,.5),y+rand(0,.8),z+rand(-.5,.5),rand(-3,3)*scale,rand(.5,4)*scale,rand(-3,3)*scale,rand(1.2,2.6),1,3.6*scale,.25,.23,.22,.7,-.4,1.2);
 fxSpark(x,y+.3,z,Math.ceil(30*fxMul()),null);
 for(let i=0;i<Math.ceil(20*fxMul());i++)fxN.emit(x,y+.2,z,rand(-9,9),rand(1,7),rand(-9,9),rand(.5,1),.12,.2,.55,.5,.45,.9,12,.3);
 const ring=new THREE.Mesh(new THREE.RingGeometry(.85,1,32),new THREE.MeshBasicMaterial({color:0xffd9a0,transparent:true,opacity:.7,side:THREE.DoubleSide,depthWrite:false,blending:THREE.AdditiveBlending,toneMapped:false}));
 ring.rotation.x=-Math.PI/2;ring.position.set(x,y+.15,z);scene.add(ring);boomRings.push({m:ring,t:0,max:.6,r:9*scale});
 flashLight.position.set(x,y+1,z);flashLight.intensity=60;flashLight.color.set(0xffa050);flashLight.userData.t=.35;flashLight.userData.base=60;
}
function updateFX(dt,t){
 if(!fxReady)return;
 updateFXUniforms();
 fxN.update(dt);fxA.update(dt);fxSmoke.update(dt);
 updateShells(dt);updateSmokes(dt);fx2Update(dt);
 for(const l of tracers){if(l.visible){l.userData.life-=dt;l.material.opacity=Math.max(0,l.userData.life/.09)*.9;if(l.userData.life<=0)l.visible=false;}}
 for(let i=boomRings.length-1;i>=0;i--){const b=boomRings[i];b.t+=dt;const k=b.t/b.max;b.m.scale.setScalar(.5+k*b.r);b.m.material.opacity=Math.max(0,.7*(1-k));if(b.t>=b.max){scene.remove(b.m);boomRings.splice(i,1);}}
 if(flashLight.userData.t>0){flashLight.userData.t-=dt;flashLight.intensity=Math.max(0,(flashLight.userData.base||6)*(flashLight.userData.t/ (flashLight.userData.base>20?.35:.06)));}
 else flashLight.intensity=0;
 // poussière ambiante (autour de la caméra)
 if(motes){const p=motes.pos,cx=camera.position.x,cy=camera.position.y,cz=camera.position.z,snowing=MAP&&MAP.base==='snow';
  for(let i=0;i<260;i++){p[i*3]+=Math.sin(t*.3+i)*.12*dt+(snowing?.5*dt:0);p[i*3+1]+=snowing?-(.9+(i%5)*.15)*dt:Math.sin(t*.2+i*1.7)*.05*dt;if(snowing&&p[i*3+1]<.1)p[i*3+1]=14;p[i*3+2]+=Math.cos(t*.25+i)*.1*dt;
   if(p[i*3]-cx>25)p[i*3]-=50;else if(p[i*3]-cx<-25)p[i*3]+=50;if(p[i*3+2]-cz>25)p[i*3+2]-=50;else if(p[i*3+2]-cz<-25)p[i*3+2]+=50;
   if(p[i*3+1]>14)p[i*3+1]=.3;}
  motes.geo.attributes.position.needsUpdate=true;motes.pts.visible=!!cfg.fx;}
}
// flash de bouche pour le joueur (lumière dynamique)
function muzzleLight(x,y,z){flashLight.position.set(x,y,z);flashLight.color.set(0xffc880);flashLight.intensity=16;flashLight.userData.t=.07;flashLight.userData.base=16;}
function resetFX(){
 if(!fxReady)return;
 for(const p of [fxN,fxA,fxSmoke]){for(let k=0;k<p.cap;k++){p.life[k]=0;p.col[k*4+3]=0;p.pos[k*3+1]=-999;}p.geo.attributes.color.needsUpdate=true;p.geo.attributes.position.needsUpdate=true;}
 clearDecals();smokes.length=0;for(const s of shells)s.on=false;for(const b of boomRings)scene.remove(b.m);boomRings=[];
}
