/* =====================================================================
   GRAPHISMES : rendu, textures procédurales, thèmes, construction du monde
   ===================================================================== */
const canvas=$('c');
const renderer=new THREE.WebGLRenderer({canvas,antialias:true,powerPreference:'high-performance'});
renderer.autoClear=false;
renderer.outputEncoding=THREE.sRGBEncoding;
renderer.toneMapping=THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure=1.05;
renderer.shadowMap.enabled=true;renderer.shadowMap.type=THREE.PCFSoftShadowMap;
const MAXANI=Math.min(8,renderer.capabilities.getMaxAnisotropy());
const scene=new THREE.Scene(),vmScene=new THREE.Scene();
const camera=new THREE.PerspectiveCamera(82,1,.05,260);camera.rotation.order='YXZ';
const vmCam=new THREE.PerspectiveCamera(60,1,.01,10);
const hemi=new THREE.HemisphereLight(0xdfe9ff,0x7a6a50,.6);scene.add(hemi);
const sun=new THREE.DirectionalLight(0xfff0d0,2.2);scene.add(sun);scene.add(sun.target);
sun.shadow.mapSize.set(2048,2048);
{const sc=sun.shadow.camera;sc.left=-62;sc.right=62;sc.top=62;sc.bottom=-62;sc.near=5;sc.far=260;sun.shadow.bias=-.0005;sun.shadow.normalBias=.05;}
const fill=new THREE.DirectionalLight(0xbcd4ff,.45);fill.position.set(-50,40,-30);scene.add(fill);
const vmAmb=new THREE.HemisphereLight(0xffffff,0x555566,.9);vmScene.add(vmAmb);
const vmSun=new THREE.DirectionalLight(0xffffff,2.2);vmSun.position.set(1.5,2.5,1.5);vmScene.add(vmSun);
const vmRim=new THREE.DirectionalLight(0x88aaff,1.2);vmRim.position.set(-2,1,-1);vmScene.add(vmRim);
const GFXRES=[.6,.85,1];
function resize(){
 const w=innerWidth,h=innerHeight;
 renderer.setPixelRatio(Math.min(devicePixelRatio||1,2)*GFXRES[cfg.gfx]);
 renderer.setSize(w,h,false);
 camera.aspect=w/h;vmCam.aspect=w/h;camera.updateProjectionMatrix();vmCam.updateProjectionMatrix();
 sun.castShadow=cfg.gfx>=1;
 const ms=cfg.gfx>=2?4096:2048;
 if(sun.shadow.mapSize.x!==ms){sun.shadow.mapSize.set(ms,ms);if(sun.shadow.map){sun.shadow.map.dispose();sun.shadow.map=null;}}
 if(typeof postSize==='function')postSize();
}
// ombres : en jeu, la zone d'ombre (80 m) suit la caméra -> ombres ~3x plus nettes ; au menu, toute la carte
const SUNOFF=V3(55,80,34);let shFollow=null;
function shadowFollow(x,z,on){
 const R=on?40:62,sc=sun.shadow.camera;
 if(on){const t=(2*R)/sun.shadow.mapSize.x;x=Math.round(x/t)*t;z=Math.round(z/t)*t;}else{x=40;z=40;}
 if(shFollow===R+'|'+x+'|'+z)return;shFollow=R+'|'+x+'|'+z;
 if(sc.right!==R){sc.left=-R;sc.right=R;sc.top=R;sc.bottom=-R;sc.updateProjectionMatrix();}
 sun.position.set(x+SUNOFF.x,SUNOFF.y,z+SUNOFF.z);sun.target.position.set(x,0,z);sun.target.updateMatrixWorld();
}
addEventListener('resize',resize);

/* ---------------- helpers couleurs / textures ---------------- */
const C=hex=>new THREE.Color(hex).convertSRGBToLinear();
function canvasTex(w,h,draw,rep,opts){
 const sc=(opts&&opts.s)||(w===128?2:1);
 const c=document.createElement('canvas');c.width=w*sc;c.height=h*sc;
 const ctx=c.getContext('2d');ctx.scale(sc,sc);draw(ctx,w,h);
 const t=new THREE.CanvasTexture(c);t.encoding=THREE.sRGBEncoding;t.anisotropy=MAXANI;
 if(rep){t.wrapS=t.wrapT=THREE.RepeatWrapping;}
 if(opts&&opts.noSRGB)t.encoding=THREE.LinearEncoding;
 return t;
}
function stdMat(hex,o){return new THREE.MeshStandardMaterial(Object.assign({color:C(hex),roughness:.85,metalness:0},o||{}));}
function speck(c,w,h,n,a0,a1,sz){
 n=Math.floor(n*.5);
 for(let i=0;i<n;i++){const l=Math.random()<.5;c.fillStyle='rgba('+(l?'255,250,235':'40,28,14')+','+rand(a0||.03,a1||.1)+')';c.fillRect(rand(0,w),rand(0,h),rand(1,sz||5),rand(1,(sz||5)*.7));}
}
function blotches(c,w,h,n,rgb,a,rmin,rmax){
 a*=.8;
 for(let i=0;i<n;i++){const x=rand(0,w),y=rand(0,h),r=rand(rmin,rmax),g=c.createRadialGradient(x,y,0,x,y,r);g.addColorStop(0,'rgba('+rgb+','+rand(a*.4,a)+')');g.addColorStop(1,'rgba('+rgb+',0)');c.fillStyle=g;c.fillRect(x-r,y-r,r*2,r*2);}
}
function streaks(c,w,h,n,rgb,a){
 for(let i=0;i<n;i++){const x=rand(0,w),len=rand(h*.15,h*.6),g=c.createLinearGradient(0,0,0,len);g.addColorStop(0,'rgba('+rgb+','+rand(a*.3,a)+')');g.addColorStop(1,'rgba('+rgb+',0)');c.save();c.translate(x,rand(0,h*.3));c.fillStyle=g;c.fillRect(0,0,rand(2,8),len);c.restore();}
}
function cracks(c,w,h,n,rgb){
 c.strokeStyle='rgba('+rgb+',.35)';c.lineWidth=1;
 for(let i=0;i<n;i++){let x=rand(0,w),y=rand(0,h);c.beginPath();c.moveTo(x,y);for(let k=0;k<6;k++){x+=rand(-8,8);y+=rand(2,14);c.lineTo(x,y);}c.stroke();}
}

/* ---------------- thèmes ---------------- */
const THEMES={
 sand:{
  sky:[[0,'#2e68bf'],[.28,'#6ea3df'],[.46,'#cfe0ee'],[.5,'#f0e8d8'],[.52,'#d8cdb4'],[1,'#b9a98a']],
  fog:0xd9c6a3,fogN:55,fogF:210,hemiS:0xdbe8ff,hemiG:0x9a8260,hemiI:.38,sunC:0xfff1d6,sunI:2.3,sunPos:[55,80,34],exp:.82,env:.5,
  cloud:'255,255,255',
 },
 snow:{
  sky:[[0,'#4a6aa5'],[.25,'#8fa6cf'],[.42,'#d7c9d8'],[.48,'#f6d9c6'],[.5,'#f7e3d6'],[.52,'#e6ecf4'],[1,'#d9e2ee']],
  fog:0xc3d3e6,fogN:55,fogF:190,hemiS:0xa8c0ee,hemiG:0xd5e2f5,hemiI:.62,sunC:0xffe0c8,sunI:2.4,sunPos:[62,36,30],exp:.95,env:.8,cloud:'255,236,236',cov:.6,
 },
 industrial:{
  sky:[[0,'#2b2f5e'],[.22,'#6a4a86'],[.38,'#e0775a'],[.47,'#ffb066'],[.5,'#ffd9a0'],[.52,'#5b4a52'],[1,'#2a2530']],
  fog:0xd9966a,fogN:50,fogF:200,hemiS:0x9aa6e8,hemiG:0x6b5a4a,hemiI:.4,sunC:0xffa860,sunI:3.0,sunPos:[75,34,40],exp:.9,env:.6,
  cloud:'255,190,140',cov:.48,
 }
};

/* ---------------- ciel / environnement ---------------- */
let skyG=null,worldG=null,envTex=null;
const worldAnim=[];
function skyTexture(th){
 return canvasTex(8,256,(c,w,h)=>{const g=c.createLinearGradient(0,0,0,h);th.sky.forEach(s=>g.addColorStop(s[0],s[1]));c.fillStyle=g;c.fillRect(0,0,w,h);});
}
function glowTex(rgb){return canvasTex(128,128,(c)=>{const g=c.createRadialGradient(64,64,0,64,64,64);g.addColorStop(0,'rgba('+rgb+',1)');g.addColorStop(.2,'rgba('+rgb+',.7)');g.addColorStop(.5,'rgba('+rgb+',.18)');g.addColorStop(1,'rgba('+rgb+',0)');c.fillStyle=g;c.fillRect(0,0,128,128);});}
const GLOW={warm:glowTex('255,214,150'),white:glowTex('255,255,245'),orange:glowTex('255,150,70'),cool:glowTex('170,210,255')};
let curTheme=null;
// carte d'environnement (reflets PBR) pour un renderer donnÃ© : chaque renderer a son propre contexte WebGL
function makeEnv(rend){
 const th=curTheme||THEMES.sand,st=skyTexture(th),es=new THREE.Scene();
 es.add(new THREE.Mesh(new THREE.SphereGeometry(50,24,12),new THREE.MeshBasicMaterial({map:st,side:THREE.BackSide,toneMapped:false})));
 const sd=new THREE.Mesh(new THREE.SphereGeometry(6,12,8),new THREE.MeshBasicMaterial({color:new THREE.Color(th.sunC).multiplyScalar(6)}));
 sd.position.copy(new THREE.Vector3(...th.sunPos).normalize()).multiplyScalar(40);es.add(sd);
 const pm=new THREE.PMREMGenerator(rend),t=pm.fromScene(es,.02).texture;pm.dispose();return t;
}
// ciel « réel » : dégradé du thème + diffusion autour du soleil + disque solaire + couche de nuages
// (bruit fractal projeté sur un plafond, éclairée côté soleil, assombrie dessous, qui dérive au vent)
function skyMaterial(th,st,sdir){
 const cc=th.cloud.split(',').map(v=>+v/255),hq=cfg.gfx>=1?1:0;
 return new THREE.ShaderMaterial({depthWrite:false,fog:false,toneMapped:false,side:THREE.BackSide,
  uniforms:{uSky:{value:st},uSun:{value:sdir.clone()},uSunC:{value:new THREE.Color(th.sunC)},uCl:{value:new THREE.Vector3(...cc)},
   uCov:{value:th.cov!==undefined?th.cov:.42},uT:{value:0},uSeed:{value:Math.random()*50}},
  vertexShader:'varying vec3 vD;varying vec2 vU;void main(){vD=position;vU=uv;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);gl_Position.z=gl_Position.w*.9999;}',
  fragmentShader:`uniform sampler2D uSky;uniform vec3 uSun,uSunC,uCl;uniform float uCov,uT,uSeed;varying vec3 vD;varying vec2 vU;
float h(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float n(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+1.),f.x),f.y);}
float fbm(vec2 p){float v=0.,a=.5;for(int k=0;k<${hq?6:4};k++){v+=a*n(p);p=mat2(1.6,1.2,-1.2,1.6)*p;a*=.5;}return v;}
vec3 lin(vec3 c){return pow(c,vec3(2.2));}
void main(){
 vec3 d=normalize(vD);vec3 col=texture2D(uSky,vU).rgb;
 float mu=max(dot(d,uSun),0.),up=clamp(d.y,0.,1.);
 vec3 sc=uSunC*(.5+.5*uSun.y);
 // halo de diffusion (Mie) + éclaircissement de l'horizon du côté du soleil
 col+=sc*(pow(mu,6.)*.16+pow(mu,48.)*.32)+sc*pow(1.-up,6.)*pow(mu,2.)*.18;
 col+=sc*smoothstep(.99955,.9998,mu)*2.5;
 if(d.y>0.){
  vec2 p=d.xz/(d.y+.12)*1.4+vec2(uT*.006,uT*.002)+uSeed;
  float c=fbm(p*1.3),c2=fbm(p*1.3+uSun.xz*.09);
  float cov=uCov,dn=smoothstep(1.-cov-.08,1.-cov+.28,c);
  dn*=smoothstep(.0,.16,d.y);
  float lit=clamp(1.-(c2-c)*5.,.25,1.15);            // face au soleil plus claire, dessous plus sombre
  vec3 base=uCl*mix(.55,1.,cov<.55?1.:.7);
  vec3 cl=mix(base*.62*mix(vec3(.85,.9,1.),vec3(1.),uSun.y),base,lit);
  cl+=sc*pow(mu,10.)*(1.-dn)*1.4*.6;                 // liseré argenté près du soleil
  cl=mix(cl,col,pow(1.-up,8.)*.6);                   // brume vers l'horizon
  col=mix(col,cl,dn*.94);
 }
 gl_FragColor=linearToOutputTexel(vec4(lin(clamp(col,0.,4.)),1.));
}`});
}
function buildSky(th){
 if(skyG){scene.remove(skyG);}
 skyG=new THREE.Group();
 const st=skyTexture(th);
 const dome=new THREE.Mesh(new THREE.SphereGeometry(200,32,16),new THREE.MeshBasicMaterial({map:st,side:THREE.BackSide,fog:false,depthWrite:false,toneMapped:false}));
 dome.renderOrder=-10;skyG.add(dome);
 const sdir=new THREE.Vector3(...th.sunPos).normalize();
 const sunS=new THREE.Sprite(new THREE.SpriteMaterial({map:GLOW.white,fog:false,depthWrite:false,transparent:true,blending:THREE.AdditiveBlending,toneMapped:false,color:new THREE.Color(th.sunC)}));
 sunS.scale.set(95,95,1);sunS.position.copy(sdir).multiplyScalar(180);skyG.add(sunS);
 // nuages volumétriques procéduraux (ciel peint en shader, plus de nuages en sprites)
 dome.material=skyMaterial(th,st,sdir);dome.onBeforeRender=()=>{dome.material.uniforms.uT.value=performance.now()*.001;};
 scene.add(skyG);
 curTheme=th;
 if(envTex)envTex.dispose();
 envTex=makeEnv(renderer);scene.environment=envTex;vmScene.environment=envTex;
}
function applyTheme(th){
 scene.fog=new THREE.Fog(th.fog,th.fogN,th.fogF);scene.background=new THREE.Color(th.fog);
 hemi.color.set(th.hemiS);hemi.groundColor.set(th.hemiG);hemi.intensity=th.hemiI;
 sun.color.set(th.sunC);sun.intensity=th.sunI;
 SUNOFF.set(th.sunPos[0],th.sunPos[1],th.sunPos[2]);shFollow=null;shadowFollow(40,40,false);
 renderer.toneMappingExposure=th.exp;
 vmSun.color.set(th.sunC);
}

/* ---------------- bibliothèque de textures ---------------- */
const TC={};
function cached(key,fn){return TC[key]||(TC[key]=fn());}
const PX=64; // pixels par mètre
function texPlaster(hm,pal){return cached('plaster'+hm+pal.join(),()=>canvasTex(128,Math.round(PX*hm),(c,w,h)=>{
 const g=c.createLinearGradient(0,0,0,h);g.addColorStop(0,pal[0]);g.addColorStop(1,pal[1]);c.fillStyle=g;c.fillRect(0,0,w,h);
 blotches(c,w,h,26,'120,90,55',.18,10,40);blotches(c,w,h,18,'255,255,240',.12,10,30);speck(c,w,h,900,.03,.1,5);
 for(let i=0;i<4;i++){const x=rand(0,w-36),y=rand(h*.2,h*.82);c.fillStyle=pal[2];c.fillRect(x,y,rand(20,36),rand(14,24));c.strokeStyle='rgba(235,225,200,.8)';c.lineWidth=2;for(let yy=0;yy<24;yy+=8){c.beginPath();c.moveTo(x,y+yy);c.lineTo(x+36,y+yy);c.stroke();}}
 streaks(c,w,h,10,'70,45,25',.28);cracks(c,w,h,5,'60,40,20');
 c.fillStyle='rgba(255,255,255,.22)';c.fillRect(0,0,w,h*.035);c.fillStyle='rgba(60,40,20,.4)';c.fillRect(0,h*.035,w,3);
 const gg=c.createLinearGradient(0,h*.82,0,h);gg.addColorStop(0,'rgba(60,40,20,0)');gg.addColorStop(1,'rgba(60,40,20,.55)');c.fillStyle=gg;c.fillRect(0,h*.82,w,h*.18);
}));}
function texHouse(hm,pal){return cached('house'+hm+pal.join(),()=>canvasTex(128,Math.round(PX*hm),(c,w,h)=>{
 c.fillStyle=pal[0];c.fillRect(0,0,w,h);blotches(c,w,h,24,'120,90,55',.15,10,36);speck(c,w,h,700,.03,.09,5);
 c.fillStyle=pal[1];c.fillRect(0,h*.89,w,h*.11);c.fillStyle='rgba(0,0,0,.22)';c.fillRect(0,h*.89,w,3);
 for(let x=0;x<w;x+=16){c.fillStyle='rgba(0,0,0,.12)';c.fillRect(x,h*.9,2,h*.1);}
 c.fillStyle=pal[1];c.fillRect(0,0,w,h*.065);c.fillStyle='rgba(0,0,0,.28)';c.fillRect(0,h*.065,w,3);
 for(let x=0;x<w;x+=12){c.fillStyle='rgba(0,0,0,.2)';c.fillRect(x,h*.01,2,h*.05);}
 const cnt=hm>3?2:1;
 for(let k=0;k<cnt;k++){
  const wx=w/2,wy=hm>3?h*(k?.3:.64):h*.5;
  c.fillStyle='#8a5a2b';c.fillRect(wx-28,wy-48,56,98);
  c.fillStyle='#1f2a36';c.fillRect(wx-22,wy-37,44,84);c.beginPath();c.arc(wx,wy-37,22,Math.PI,0);c.fill();
  c.fillStyle='rgba(120,170,220,.25)';c.fillRect(wx-18,wy-34,10,70);
  c.fillStyle='#8a5a2b';c.beginPath();c.arc(wx,wy-37,28,Math.PI,0);c.lineTo(wx+22,wy-37);c.arc(wx,wy-37,22,0,Math.PI,true);c.fill();
  c.fillStyle=pal[2];c.fillRect(wx-48,wy-37,19,76);c.fillRect(wx+29,wy-37,19,76);
  c.strokeStyle='rgba(0,0,0,.35)';c.lineWidth=2;for(let i=0;i<6;i++){const y=wy-33+i*13;c.beginPath();c.moveTo(wx-48,y);c.lineTo(wx-29,y);c.moveTo(wx+29,y);c.lineTo(wx+48,y);c.stroke();}
  c.fillStyle='#cfc2a6';c.fillRect(wx-35,wy+49,70,8);c.fillStyle='rgba(0,0,0,.25)';c.fillRect(wx-35,wy+57,70,4);
 }
 streaks(c,w,h,6,'70,45,25',.2);
}));}
function texCrate(hm){return cached('crate'+hm,()=>canvasTex(128,Math.round(PX*hm),(c,w,h)=>{
 const n=Math.max(1,Math.round(hm/1.3)),ch=h/n;
 for(let k=0;k<n;k++){
  const y0=k*ch;c.fillStyle=k&1?'#9a6a38':'#ad7d42';c.fillRect(0,y0,w,ch);
  for(let y=y0+4;y<y0+ch;y+=ch/6){c.fillStyle='rgba(0,0,0,'+rand(.05,.16)+')';c.fillRect(0,y,w,3);}
  for(let i=0;i<80;i++){c.fillStyle='rgba(50,28,8,'+rand(.05,.16)+')';c.fillRect(rand(0,w),rand(y0,y0+ch),rand(8,34),1);}
  c.strokeStyle='#5b3b19';c.lineWidth=9;c.strokeRect(5,y0+5,w-10,ch-10);c.lineWidth=7;c.beginPath();c.moveTo(7,y0+7);c.lineTo(w-7,y0+ch-7);c.moveTo(w-7,y0+7);c.lineTo(7,y0+ch-7);c.stroke();
  c.fillStyle='#8d8f93';for(const [x,y] of [[10,10],[w-10,10],[10,ch-10],[w-10,ch-10]]){c.beginPath();c.arc(x,y0+y,3,0,TAU);c.fill();}
 }
 blotches(c,w,h,10,'30,20,10',.2,10,28);
}));}
function texStone(hm){return cached('stone'+hm,()=>canvasTex(128,Math.round(PX*hm),(c,w,h)=>{
 c.fillStyle='#b9a886';c.fillRect(0,0,w,h);const bh=Math.max(14,h/Math.max(2,Math.round(h/20)));
 for(let r=0;r*bh<h;r++)for(let x=((r&1)?-26:0);x<w;x+=52){c.fillStyle='hsl(38,'+rand(10,22)+'%,'+rand(54,70)+'%)';c.fillRect(x+2,r*bh+2,48,bh-3);}
 speck(c,w,h,260,.03,.12,6);blotches(c,w,h,8,'60,45,25',.2,8,24);c.fillStyle='#d6c9a8';c.fillRect(0,0,w,h*Math.min(.14,12/h*2));c.fillStyle='rgba(0,0,0,.25)';c.fillRect(0,h*Math.min(.14,12/h*2),w,2);
}));}
function texBarrel(){return cached('barrel',()=>canvasTex(128,72,(c,w,h)=>{
 c.fillStyle='#d8d8d8';c.fillRect(0,0,w,h);
 for(let x=0;x<w;x+=6){c.fillStyle='rgba(0,0,0,'+rand(0,.12)+')';c.fillRect(x,0,3,h);c.fillStyle='rgba(255,255,255,'+rand(0,.15)+')';c.fillRect(x+3,0,2,h);}
 for(const y of [.1,.5,.88]){c.fillStyle='rgba(30,30,34,.85)';c.fillRect(0,h*y-4,w,8);c.fillStyle='rgba(255,255,255,.15)';c.fillRect(0,h*y-4,w,2);}
 c.fillStyle='rgba(20,20,20,.5)';c.font='bold 22px Arial';c.textAlign='center';c.fillText('▲',w/2,h*.4);
 blotches(c,w,h,10,'90,50,20',.28,6,16);streaks(c,w,h,6,'120,60,20',.4);
},true));}
function texPlat(){return cached('plat',()=>canvasTex(128,128,(c,w,h)=>{
 c.fillStyle='#c9b48c';c.fillRect(0,0,w,h);
 for(let y=0;y<h;y+=32)for(let x=((y/32)&1)*32;x<w;x+=64){c.fillStyle='hsl(36,'+rand(10,20)+'%,'+rand(58,72)+'%)';c.fillRect(x+2,y+2,60,28);}
 speck(c,w,h,300,.03,.1,5);blotches(c,w,h,6,'90,60,30',.2,10,26);
},true));}
function texRoof(){return cached('roof',()=>canvasTex(128,128,(c,w,h)=>{
 c.fillStyle='#b5683f';c.fillRect(0,0,w,h);
 for(let y=0;y<h;y+=16)for(let x=((y/16)&1)*10;x<w;x+=20){c.fillStyle='hsl(16,'+rand(40,55)+'%,'+rand(38,50)+'%)';c.beginPath();c.arc(x+10,y+4,11,0,Math.PI);c.fill();c.strokeStyle='rgba(0,0,0,.2)';c.stroke();}
 speck(c,w,h,200,.03,.1,5);
},true));}
function texPillar(){return cached('pillar',()=>canvasTex(64,128,(c,w,h)=>{
 const g=c.createLinearGradient(0,0,w,0);g.addColorStop(0,'#9d8a68');g.addColorStop(.4,'#d4c4a0');g.addColorStop(1,'#8a7858');c.fillStyle=g;c.fillRect(0,0,w,h);
 for(let y=0;y<h;y+=20){c.fillStyle='rgba(0,0,0,.14)';c.fillRect(0,y,w,2);}
 speck(c,w,h,200,.03,.1,4);c.fillStyle='rgba(60,40,20,.5)';c.fillRect(0,0,w,8);c.fillRect(0,h-10,w,10);
},true));}
/* industriel */
function texConcrete(hm){return cached('conc'+hm,()=>canvasTex(128,Math.round(PX*hm),(c,w,h)=>{
 const g=c.createLinearGradient(0,0,0,h);g.addColorStop(0,'#aeb4ba');g.addColorStop(1,'#8d949b');c.fillStyle=g;c.fillRect(0,0,w,h);
 blotches(c,w,h,30,'60,64,70',.2,12,40);blotches(c,w,h,16,'255,255,255',.12,10,30);speck(c,w,h,900,.03,.1,5);
 c.strokeStyle='rgba(30,34,40,.5)';c.lineWidth=2;for(let y=h*.34;y<h;y+=h*.33){c.beginPath();c.moveTo(0,y);c.lineTo(w,y);c.stroke();}
 c.beginPath();c.moveTo(1,0);c.lineTo(1,h);c.moveTo(w-1,0);c.lineTo(w-1,h);c.stroke();
 c.fillStyle='rgba(30,34,40,.6)';for(const y of [h*.34,h*.67])for(const x of [10,w-10]){c.beginPath();c.arc(x,y+8,2.5,0,TAU);c.fill();}
 streaks(c,w,h,12,'60,40,25',.3);cracks(c,w,h,5,'30,30,34');
 // bande de danger en bas
 const hz=Math.min(h*.14,34);c.save();c.beginPath();c.rect(0,h-hz,w,hz);c.clip();c.fillStyle='#e8b923';c.fillRect(0,h-hz,w,hz);c.fillStyle='#1a1a1a';
 for(let x=-hz;x<w+hz;x+=22){c.beginPath();c.moveTo(x,h);c.lineTo(x+11,h);c.lineTo(x+11+hz,h-hz);c.lineTo(x+hz,h-hz);c.closePath();c.fill();}
 c.restore();c.fillStyle='rgba(40,40,40,.35)';c.fillRect(0,h-hz,w,hz);
 if(hm>4){c.fillStyle='rgba(235,235,235,.8)';c.font='bold 40px Arial';c.textAlign='center';c.fillText(String(Math.floor(rand(10,99))),w/2,h*.45);}
}));}
function texContainer(hm){return cached('cont'+hm,()=>canvasTex(128,Math.round(PX*hm),(c,w,h)=>{
 c.fillStyle='#cfcfcf';c.fillRect(0,0,w,h);
 for(let x=0;x<w;x+=8){const g=c.createLinearGradient(x,0,x+8,0);g.addColorStop(0,'rgba(0,0,0,.28)');g.addColorStop(.5,'rgba(255,255,255,.2)');g.addColorStop(1,'rgba(0,0,0,.28)');c.fillStyle=g;c.fillRect(x,0,8,h);}
 c.fillStyle='rgba(0,0,0,.55)';c.fillRect(0,0,w,10);c.fillRect(0,h-10,w,10);c.fillStyle='rgba(255,255,255,.2)';c.fillRect(0,10,w,3);
 blotches(c,w,h,20,'80,40,20',.25,10,30);streaks(c,w,h,12,'110,50,20',.35);speck(c,w,h,500,.04,.12,5);
 c.fillStyle='rgba(255,255,255,.75)';c.font='bold 13px Arial';c.textAlign='left';c.fillText('MSKU '+Math.floor(rand(100000,999999)),8,26);
}));}
function texCrateMetal(hm){return cached('mcrate'+hm,()=>canvasTex(128,Math.round(PX*hm),(c,w,h)=>{
 const n=Math.max(1,Math.round(hm/1.3)),ch=h/n;
 for(let k=0;k<n;k++){const y0=k*ch;c.fillStyle='#7d8a6a';c.fillRect(0,y0,w,ch);c.strokeStyle='#2c3326';c.lineWidth=8;c.strokeRect(4,y0+4,w-8,ch-8);
  c.fillStyle='#d0a528';c.fillRect(8,y0+ch*.4,w-16,ch*.2);c.fillStyle='#1a1a1a';c.font='bold 22px Arial';c.textAlign='center';c.fillText('FRAGILE',w/2,y0+ch*.56);
  for(let i=0;i<4;i++){c.fillStyle='#4a5440';c.fillRect(rand(10,100),y0+rand(8,ch-10),rand(10,22),3);}}
 blotches(c,w,h,10,'20,20,10',.25,8,24);speck(c,w,h,300,.03,.1,5);
}));}
function texMetalTop(){return cached('mtop',()=>canvasTex(128,128,(c,w,h)=>{
 c.fillStyle='#6f7882';c.fillRect(0,0,w,h);c.strokeStyle='rgba(20,24,30,.55)';c.lineWidth=3;
 for(let i=0;i<=w;i+=16){c.beginPath();c.moveTo(i,0);c.lineTo(i,h);c.stroke();c.beginPath();c.moveTo(0,i);c.lineTo(w,i);c.stroke();}
 c.fillStyle='rgba(255,255,255,.1)';for(let y=0;y<h;y+=16)for(let x=0;x<w;x+=16)c.fillRect(x+3,y+3,10,10);speck(c,w,h,300,.03,.1,4);
},true));}
function texPlatI(){return cached('platI',()=>canvasTex(128,128,(c,w,h)=>{
 c.fillStyle='#8c939c';c.fillRect(0,0,w,h);speck(c,w,h,600,.03,.1,4);
 c.strokeStyle='rgba(20,24,30,.5)';c.lineWidth=2;for(let i=0;i<=w;i+=64){c.beginPath();c.moveTo(i,0);c.lineTo(i,h);c.stroke();c.beginPath();c.moveTo(0,i);c.lineTo(w,i);c.stroke();}
 c.fillStyle='#e0b020';c.fillRect(0,0,w,10);c.fillRect(0,h-10,w,10);c.fillStyle='#1a1a1a';for(let x=-10;x<w+10;x+=22){c.beginPath();c.moveTo(x,10);c.lineTo(x+11,10);c.lineTo(x+1,0);c.lineTo(x-10,0);c.fill();c.beginPath();c.moveTo(x,h);c.lineTo(x+11,h);c.lineTo(x+1,h-10);c.lineTo(x-10,h-10);c.fill();}
},true));}
function texPillarI(){return cached('pillarI',()=>canvasTex(64,128,(c,w,h)=>{
 c.fillStyle='#b0b6bc';c.fillRect(0,0,w,h);const g=c.createLinearGradient(0,0,w,0);g.addColorStop(0,'rgba(0,0,0,.3)');g.addColorStop(.5,'rgba(255,255,255,.2)');g.addColorStop(1,'rgba(0,0,0,.3)');c.fillStyle=g;c.fillRect(0,0,w,h);
 c.fillStyle='#e8b923';for(let y=h-44;y<h;y+=22){c.fillRect(0,y,w,11);}speck(c,w,h,200,.03,.1,4);
},true));}
function texWoodCeil(){return cached('wceil',()=>canvasTex(128,128,(c,w,h)=>{
 c.fillStyle='#a8844f';c.fillRect(0,0,w,h);for(let x=0;x<w;x+=10){c.fillStyle='rgba(0,0,0,'+rand(.05,.2)+')';c.fillRect(x,0,3,h);}
 for(let i=0;i<60;i++){c.fillStyle='rgba(40,25,10,.2)';c.fillRect(rand(0,w),rand(0,h),rand(8,30),1);}
},true));}
function texCorrug(){return cached('corrug',()=>canvasTex(128,128,(c,w,h)=>{
 c.fillStyle='#8d949b';c.fillRect(0,0,w,h);
 for(let x=0;x<w;x+=8){const g=c.createLinearGradient(x,0,x+8,0);g.addColorStop(0,'rgba(0,0,0,.3)');g.addColorStop(.5,'rgba(255,255,255,.25)');g.addColorStop(1,'rgba(0,0,0,.3)');c.fillStyle=g;c.fillRect(x,0,8,h);}
 blotches(c,w,h,10,'90,50,20',.25,8,24);
},true));}
/* neige / station polaire */
function texRock(hm){return cached('rock'+hm,()=>canvasTex(128,Math.round(PX*hm),(c,w,h)=>{
 const g=c.createLinearGradient(0,0,0,h);g.addColorStop(0,'#8e98a8');g.addColorStop(1,'#667082');c.fillStyle=g;c.fillRect(0,0,w,h);
 blotches(c,w,h,40,'30,36,48',.35,10,34);blotches(c,w,h,30,'210,225,245',.22,8,26);speck(c,w,h,900,.04,.14,5);
 c.strokeStyle='rgba(20,26,36,.45)';c.lineWidth=2;for(let i=0;i<12;i++){let x=rand(0,w),y=rand(0,h);c.beginPath();c.moveTo(x,y);for(let k=0;k<7;k++){x+=rand(-14,14);y+=rand(6,22);c.lineTo(x,y);}c.stroke();}
 for(let i=0;i<14;i++){const x=rand(0,w),g2=c.createLinearGradient(0,0,0,rand(30,90));g2.addColorStop(0,'rgba(245,250,255,.7)');g2.addColorStop(1,'rgba(245,250,255,0)');c.fillStyle=g2;c.fillRect(x,rand(0,h*.5),rand(6,18),90);}
 const sg=c.createLinearGradient(0,0,0,h*.12);sg.addColorStop(0,'rgba(250,252,255,.95)');sg.addColorStop(1,'rgba(250,252,255,0)');c.fillStyle=sg;c.fillRect(0,0,w,h*.12);
 const bg=c.createLinearGradient(0,h*.85,0,h);bg.addColorStop(0,'rgba(240,246,255,0)');bg.addColorStop(1,'rgba(240,246,255,.8)');c.fillStyle=bg;c.fillRect(0,h*.85,w,h*.15);
}));}
function texCabin(hm){return cached('cabin'+hm,()=>canvasTex(128,Math.round(PX*hm),(c,w,h)=>{
 const lh=Math.max(14,h/Math.round(h/20));
 for(let y=0;y<h;y+=lh){const g=c.createLinearGradient(0,y,0,y+lh);g.addColorStop(0,'#8a5a32');g.addColorStop(.5,'#a06a3a');g.addColorStop(1,'#6a4122');c.fillStyle=g;c.fillRect(0,y,w,lh);
  for(let i=0;i<10;i++){c.fillStyle='rgba(30,16,6,'+rand(.1,.28)+')';c.fillRect(rand(0,w),y+rand(2,lh-2),rand(10,40),1);}}
 speck(c,w,h,500,.03,.1,4);
 const cnt=hm>3?2:1;
 for(let k=0;k<cnt;k++){const wx=w/2,wy=hm>3?h*(k?.28:.64):h*.5;
  c.fillStyle='#3a2410';c.fillRect(wx-30,wy-34,60,70);c.fillStyle='#ffcf7a';c.fillRect(wx-24,wy-28,48,58);
  const gg=c.createLinearGradient(0,wy-28,0,wy+30);gg.addColorStop(0,'rgba(255,250,220,.9)');gg.addColorStop(1,'rgba(255,170,70,.6)');c.fillStyle=gg;c.fillRect(wx-24,wy-28,48,58);
  c.fillStyle='#3a2410';c.fillRect(wx-2,wy-28,4,58);c.fillRect(wx-24,wy-2,48,4);c.fillStyle='#e9eef5';c.fillRect(wx-34,wy+36,68,7);}
 const sg=c.createLinearGradient(0,0,0,h*.1);sg.addColorStop(0,'rgba(250,252,255,.95)');sg.addColorStop(1,'rgba(250,252,255,0)');c.fillStyle=sg;c.fillRect(0,0,w,h*.1);
 c.fillStyle='rgba(235,242,252,.55)';c.fillRect(0,h*.92,w,h*.08);
}));}
function texSnowbank(hm){return cached('snowb'+hm,()=>canvasTex(128,Math.round(PX*hm),(c,w,h)=>{
 const g=c.createLinearGradient(0,0,0,h);g.addColorStop(0,'#ffffff');g.addColorStop(1,'#cdd9ea');c.fillStyle=g;c.fillRect(0,0,w,h);
 blotches(c,w,h,24,'150,175,215',.3,8,24);speck(c,w,h,400,.04,.12,4);
}));}
function texWoodDeck(hm){return cached('wdeck'+hm,()=>canvasTex(128,Math.round(PX*hm),(c,w,h)=>{
 for(let y=0;y<h;y+=14){c.fillStyle='hsl(28,'+rand(35,48)+'%,'+rand(30,42)+'%)';c.fillRect(0,y,w,13);c.fillStyle='rgba(0,0,0,.35)';c.fillRect(0,y+13,w,1);}
 speck(c,w,h,400,.03,.12,4);c.fillStyle='rgba(235,242,252,.5)';c.fillRect(0,0,w,h*.06);
}));}
function texDeck(){return cached('deck',()=>canvasTex(128,128,(c,w,h)=>{
 for(let x=0;x<w;x+=16){c.fillStyle='hsl(30,'+rand(30,42)+'%,'+rand(38,50)+'%)';c.fillRect(x,0,15,h);c.fillStyle='rgba(0,0,0,.35)';c.fillRect(x+15,0,1,h);}
 for(let i=0;i<80;i++){c.fillStyle='rgba(240,246,255,'+rand(.15,.4)+')';c.fillRect(rand(0,w),rand(0,h),rand(3,10),rand(2,6));}
 speck(c,w,h,300,.03,.1,4);
},true));}
function texPole(){return cached('pole',()=>canvasTex(64,128,(c,w,h)=>{
 const g=c.createLinearGradient(0,0,w,0);g.addColorStop(0,'#5a3a1e');g.addColorStop(.5,'#8a5c34');g.addColorStop(1,'#4a2e16');c.fillStyle=g;c.fillRect(0,0,w,h);
 for(let y=0;y<h;y+=26){c.fillStyle='rgba(0,0,0,.25)';c.fillRect(0,y,w,2);}speck(c,w,h,200,.03,.1,3);c.fillStyle='rgba(240,246,255,.8)';c.fillRect(0,0,w,10);
},true));}

/* sols */
function floorTexture(th,id){
 const ppu=24,fs=N*S*ppu,cs=S*ppu;
 return canvasTex(fs,fs,(f)=>{
  const bt=th.base||(th===THEMES.sand?'sand':th===THEMES.snow?'snow':'industrial'),sand=bt==='sand',snow=bt==='snow';
  for(let cz=0;cz<N;cz++)for(let cx=0;cx<N;cx++){
   const tag=G_TAG[cz*N+cx],x0=cx*cs,y0=cz*cs,ch=((cx*7+cz*13)%3);
   if(sand){
    if(tag===0){f.fillStyle=ch?'#c9b18a':'#c3aa83';f.fillRect(x0,y0,cs,cs);}
    else if(tag===1){f.fillStyle='#8f877b';f.fillRect(x0,y0,cs,cs);for(let sy=0;sy<5;sy++)for(let sx=0;sx<5;sx++){const ox=(sy&1)*cs/10;f.fillStyle='hsl(36,'+rand(5,14)+'%,'+rand(54,70)+'%)';f.fillRect(x0+sx*cs/5+ox+1.5,y0+sy*cs/5+1.5,cs/5-3,cs/5-3);}}
    else{const pal=tag===2?['#dcc47f','#c7aa5f']:tag===3?['#93b3da','#7e9fcb']:tag===4?['#dba886','#c6916b']:['#a89a80','#9a8c72'];const n=tag===2?6:tag===5?2:3,tw=cs/n;
     for(let sy=0;sy<n;sy++)for(let sx=0;sx<n;sx++){f.fillStyle=pal[(sx+sy+cx+cz)&1];f.fillRect(x0+sx*tw,y0+sy*tw,tw,tw);}
     f.strokeStyle='rgba(0,0,0,.14)';f.lineWidth=1.5;for(let i=0;i<=n;i++){f.beginPath();f.moveTo(x0+i*tw,y0);f.lineTo(x0+i*tw,y0+cs);f.moveTo(x0,y0+i*tw);f.lineTo(x0+cs,y0+i*tw);f.stroke();}}
   }else if(snow){
    const base=[['#eef3fa','#e6edf6'],['#c9d0da','#c0c8d3'],['#9fc8e6','#94bedf'],['#8b6a46','#7f5f3e'],['#58606a','#525a64'],['#7c8088','#767a82']][tag]||['#eef3fa','#e6edf6'];
    f.fillStyle=base[(cx+cz)&1];f.fillRect(x0,y0,cs,cs);
    if(tag===0){for(let i=0;i<14;i++){f.fillStyle='rgba(190,205,230,'+rand(.1,.3)+')';f.beginPath();f.ellipse(x0+rand(0,cs),y0+rand(0,cs),rand(6,22),rand(3,10),rand(0,3),0,TAU);f.fill();}}
    else if(tag===2){f.strokeStyle='rgba(255,255,255,.55)';f.lineWidth=2;for(let i=0;i<5;i++){let x=x0+rand(0,cs),y=y0+rand(0,cs);f.beginPath();f.moveTo(x,y);for(let k=0;k<4;k++){x+=rand(-14,14);y+=rand(-14,14);f.lineTo(x,y);}f.stroke();}}
    else if(tag===3){f.strokeStyle='rgba(0,0,0,.35)';f.lineWidth=2;for(let i=1;i<6;i++){f.beginPath();f.moveTo(x0,y0+i*cs/6);f.lineTo(x0+cs,y0+i*cs/6);f.stroke();}}
    else if(tag===4){f.strokeStyle='rgba(20,24,30,.5)';f.lineWidth=2;f.strokeRect(x0+2,y0+2,cs-4,cs-4);}
   }else if(bt==='haunt'){
    const pal={0:['#2c3a26','#27341f'],1:['#4a4640','#433f3a'],2:['#6c6a62','#2a2a28'],3:['#3a3324','#2f3a24'],4:['#7d8580','#727a75'],5:['#47443e','#3e3b36'],6:['#2b2a2c','#262528']}[tag]||['#2c3a26','#27341f'];
    if(tag===2||tag===4){const n=tag===2?6:5,tw=cs/n;for(let sy=0;sy<n;sy++)for(let sx=0;sx<n;sx++){f.fillStyle=pal[tag===2?(sx+sy)&1:0];f.fillRect(x0+sx*tw,y0+sy*tw,tw,tw);}
     f.strokeStyle='rgba(0,0,0,.3)';f.lineWidth=1;for(let i=0;i<=n;i++){f.beginPath();f.moveTo(x0+i*tw,y0);f.lineTo(x0+i*tw,y0+cs);f.moveTo(x0,y0+i*tw);f.lineTo(x0+cs,y0+i*tw);f.stroke();}
     if(Math.random()<.18){const x=x0+rand(10,cs-10),y=y0+rand(10,cs-10),r=rand(8,20);f.fillStyle='rgba(90,8,8,.55)';f.beginPath();f.ellipse(x,y,r,r*.7,rand(0,3),0,TAU);f.fill();for(let k=0;k<6;k++){f.beginPath();f.arc(x+rand(-30,30),y+rand(-30,30),rand(1,4),0,TAU);f.fill();}}}
    else if(tag===1||tag===5||tag===6){f.fillStyle=pal[0];f.fillRect(x0,y0,cs,cs);const n=tag===5?6:3,tw=cs/n;for(let sy=0;sy<n;sy++)for(let sx=0;sx<n;sx++){f.fillStyle=pal[(sx*3+sy+cx+cz)%2];f.fillRect(x0+sx*tw+1.5,y0+sy*tw+1.5,tw-3,tw-3);}}
    else{f.fillStyle=pal[(cx+cz)&1];f.fillRect(x0,y0,cs,cs);for(let i=0;i<40;i++){f.fillStyle=tag===0?'rgba('+(Math.random()<.5?'70,90,50':'25,22,15')+','+rand(.2,.5)+')':'rgba(60,50,30,'+rand(.2,.4)+')';f.fillRect(x0+rand(0,cs),y0+rand(0,cs),rand(1,3),rand(3,8));}}
   }else{
    const pal={0:['#6e747b','#686e75'],1:['#7a8088','#737982'],2:['#3e4a5c','#39455a'],3:['#8f949a','#878c92'],4:['#6a7078','#656b73'],5:['#4d4f54','#48494e'],6:['#7a7f86','#72777e']}[tag]||['#6e747b','#686e75'];
    f.fillStyle=pal[(cx+cz)&1];f.fillRect(x0,y0,cs,cs);
    if(tag===2){for(let i=0;i<30;i++){f.fillStyle='rgba(255,255,255,'+rand(.01,.05)+')';f.fillRect(x0+rand(0,cs),y0+rand(0,cs),rand(2,8),1);}}
    if(tag===4){f.strokeStyle='rgba(20,22,26,.45)';f.lineWidth=2;for(let i=1;i<4;i++){f.beginPath();f.moveTo(x0+i*cs/4,y0);f.lineTo(x0+i*cs/4,y0+cs);f.moveTo(x0,y0+i*cs/4);f.lineTo(x0+cs,y0+i*cs/4);f.stroke();}}
    f.strokeStyle='rgba(0,0,0,.18)';f.lineWidth=2;f.strokeRect(x0,y0,cs,cs);
   }
  }
  const sand2=sand;
  for(let i=0;i<(sand2?70000:60000);i++){f.fillStyle='rgba('+(Math.random()<.5?'255,245,225':'40,30,20')+','+rand(.02,.08)+')';f.fillRect(rand(0,fs),rand(0,fs),rand(1,4),rand(1,4));}
  for(let i=0;i<110;i++){const x=rand(0,fs),y=rand(0,fs),r=rand(25,120),g=f.createRadialGradient(x,y,0,x,y,r);g.addColorStop(0,sand2?'rgba(95,65,30,.15)':'rgba(15,15,20,.22)');g.addColorStop(1,'rgba(0,0,0,0)');f.fillStyle=g;f.fillRect(x-r,y-r,r*2,r*2);}
  // marquages
  f.textAlign='center';f.textBaseline='middle';
  if(!sand&&!snow&&bt!=='haunt'){ // lignes jaunes dans la halle, flèches, hachures
   f.strokeStyle='rgba(232,185,35,.75)';f.lineWidth=9;f.setLineDash([60,40]);
   for(const [ax,az,bx2,bz] of [[19,11,19,30],[21,11,21,30],[12,21,27,21]]){f.beginPath();f.moveTo(cc(ax)*ppu,cc(az)*ppu);f.lineTo(cc(bx2)*ppu,cc(bz)*ppu);f.stroke();}
   f.setLineDash([]);
  }
  if(bt!=='haunt')for(const s of MAP.sites){
   const x=s.x*ppu,y=s.z*ppu;
   f.lineWidth=14;f.strokeStyle=sand?'rgba(120,80,15,.6)':'rgba(255,200,40,.7)';f.beginPath();f.arc(x,y,s.rw*ppu-8,0,TAU);f.stroke();
   f.lineWidth=5;f.beginPath();f.arc(x,y,s.rw*ppu-34,0,TAU);f.stroke();
   f.font='bold 300px Georgia,serif';f.fillStyle=sand?'rgba(120,80,15,.6)':'rgba(255,200,40,.75)';f.fillText(s.n,x,y+14);
  }
  if(bt!=='haunt'){f.font='bold 120px Arial';f.fillStyle='rgba(30,70,150,.4)';f.fillText('CT',40*ppu,cc(2.5)*ppu);f.fillStyle='rgba(160,60,15,.4)';f.fillText('T',40*ppu,cc(36)*ppu);}
 });
}

/* ---------------- construction du monde ---------------- */
const GBOX=new THREE.BoxGeometry(1,1,1);
let stairTrimM=null;
function stairsMesh(R,th,mat){
 const g=new THREE.Group();
 const Lm=(R.axis==='x'?(R.x2-R.x1+1):(R.z2-R.z1+1))*S,Wm=(R.axis==='x'?(R.z2-R.z1+1):(R.x2-R.x1+1))*S;
 const dh=Math.abs(R.hB-R.hA),n=Math.max(2,Math.round(dh/.2)),sd=Lm/n;
 const cx0=(R.axis==='x'?R.x1*S:R.z1*S);
 const up=R.hB>R.hA,nose=stairTrimM||(stairTrimM=stdMat(0x3b3f45,{roughness:.6,metalness:.4}));
 const put=(m,along,w,h,y,d)=>{ // along = position le long de l'escalier, w = largeur, d = profondeur
  if(R.axis==='x'){m.scale.set(d,h,w);m.position.set(along,y,R.z1*S+Wm/2);}else{m.scale.set(w,h,d);m.position.set(R.x1*S+Wm/2,y,along);}
 };
 for(let i=0;i<n;i++){
  const t=(i+.5)/n,h=R.hA+(R.hB-R.hA)*t,top=Math.max(.05,h);
  const m=new THREE.Mesh(GBOX,mat);put(m,cx0+sd*(i+.5),Wm,top,top/2,sd);
  m.castShadow=m.receiveShadow=true;g.add(m);
  // nez de marche : petite bande sombre sur l'arête avant
  const nm=new THREE.Mesh(GBOX,nose),edge=cx0+sd*(up?i:i+1);
  put(nm,edge+(up?.04:-.04),Wm-.04,.05,top-.02,.1);nm.receiveShadow=true;g.add(nm);
 }
 // limons : poutres le long des deux bords, suivent la pente
 const ang=Math.atan2(R.hB-R.hA,Lm),len=Math.hypot(Lm,R.hB-R.hA),mid=(R.hA+R.hB)/2;
 for(const side of [-1,1]){
  const b=new THREE.Mesh(GBOX,nose);
  if(R.axis==='x'){b.scale.set(len,.22,.1);b.position.set(cx0+Lm/2,mid+.04,R.z1*S+Wm/2+side*(Wm/2-.05));b.rotation.z=ang;}
  else{b.scale.set(.1,.22,len);b.position.set(R.x1*S+Wm/2+side*(Wm/2-.05),mid+.04,cx0+Lm/2);b.rotation.x=-ang;}
  b.castShadow=b.receiveShadow=true;g.add(b);
 }
 return g;
}
function lintelMesh(a,mat,trim){
 const [cx,cz,w,d,y0,y1]=a,h=y1-y0;
 const m=new THREE.Mesh(GBOX,mat);m.scale.set(w*S,h,d*S);m.position.set((cx+w/2)*S,y0+h/2,(cz+d/2)*S);m.castShadow=m.receiveShadow=true;
 const g=new THREE.Group();g.add(m);
 const t=new THREE.Mesh(GBOX,trim);t.scale.set(w*S+.2,.16,d*S+.2);t.position.set((cx+w/2)*S,y0-.05,(cz+d/2)*S);t.castShadow=true;g.add(t);
 return g;
}
function addInstances(geo,mat,list,yFn,opt){
 const m=new THREE.InstancedMesh(geo,mat,list.length),mt=new THREE.Matrix4(),q=new THREE.Quaternion(),sc=new THREE.Vector3(1,1,1),pos=new THREE.Vector3();
 const col=new THREE.Color();
 list.forEach((p,i)=>{
  pos.set(cc(p[0]),yFn(p),cc(p[1]));
  if(opt&&opt.scale)sc.copy(opt.scale(p));else sc.set(1,1,1);
  q.setFromEuler(new THREE.Euler(0,opt&&opt.rot?opt.rot(p):0,0));
  mt.compose(pos,q,sc);m.setMatrixAt(i,mt);
  if(opt&&opt.color){col.set(opt.color(p));m.setColorAt(i,col);}
 });
 m.frustumCulled=false;m.castShadow=true;m.receiveShadow=true;
 worldG.add(m);return m;
}
// assombrit le sol au pied des blocs : les objets ne semblent plus flotter
function contactShadows(){
 const px=12,c=document.createElement('canvas');c.width=c.height=N*px;const x=c.getContext('2d');
 x.filter='blur('+Math.round(px*.45)+'px)';x.fillStyle='#000';
 for(let i=0;i<NC;i++){if(G_TYPE[i]&&!G_RAMP[i]&&G_H[i]>.5){const cx=i%N,cz=(i/N)|0;x.fillRect(cx*px-1,cz*px-1,px+2,px+2);}}
 const t=new THREE.CanvasTexture(c);
 const m=new THREE.Mesh(new THREE.PlaneGeometry(N*S,N*S),new THREE.MeshBasicMaterial({map:t,transparent:true,opacity:.42,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-1,polygonOffsetUnits:-1}));
 m.rotation.x=-Math.PI/2;m.position.set(N*S/2,.012,N*S/2);m.renderOrder=1;
 return m;
}
function buildWorld(id){
 if(worldG)scene.remove(worldG);
 worldG=new THREE.Group();scene.add(worldG);worldAnim.length=0;
 loadMap(id);
 const th=THEMES[MAP.theme],sand=MAP.base==='sand',snow=MAP.base==='snow',haunt=MAP.base==='haunt';
 applyTheme(th);buildSky(th);
 // sol
 const floor=new THREE.Mesh(new THREE.PlaneGeometry(N*S,N*S),stdMat(0xffffff,{map:floorTexture(th,id),roughness:.95}));
 floor.rotation.x=-Math.PI/2;floor.position.set(N*S/2,0,N*S/2);floor.receiveShadow=true;worldG.add(floor);
 // grand sol extérieur
 const ext=new THREE.Mesh(new THREE.PlaneGeometry(600,600),(MAP.theme==='night'?stdMat(0x0c1d36,{roughness:.12,metalness:.7}):haunt?stdMat(0x1c2618,{roughness:1}):stdMat(sand?(MAP.theme==='jungle'?0x4d6b3a:0xb89d76):snow?0xe9f0f8:0x3a3d44,{roughness:1})));ext.rotation.x=-Math.PI/2;ext.position.set(N*S/2,-.02,N*S/2);worldG.add(ext);
 worldG.add(contactShadows());
 if(MAP.theme==='night'){floor.material.color.set(0x6a7284);floor.material.roughness=.85;}
 // blocs : groupés par (type, hauteur)
 const groups={};
 for(let i=0;i<NC;i++){const t=G_TYPE[i];if(!t||G_RAMP[i])continue;const key=t+'|'+G_H[i].toFixed(2);(groups[key]||(groups[key]=[])).push([i%N,(i/N)|0]);}
 const roughM={};
 const wallPal=sand?['#e6d6ae','#cdb98c','#a8603e']:null;
 const housePal=['#ebe1cb','#b9633d','#2f7d78'];
 for(const key in groups){
  const [ts,hs]=key.split('|'),t=+ts,h=+hs,list=groups[key];
  let geo,mats;
  const sideM=(tex,o)=>new THREE.MeshStandardMaterial(Object.assign({map:tex,roughness:.9,metalness:0},o||{}));
  const topM=(tex,col)=>tex?stdMat(0xffffff,{map:tex,roughness:.9}):stdMat(col,{roughness:.95});
  const boxMats=(sm,tm)=>[sm,sm,tm,tm,sm,sm];
  let opt={};
  if(t===TY.BARREL){
   geo=new THREE.CylinderGeometry(.82,.78,h,18);
   const bt=texBarrel(),side=new THREE.MeshStandardMaterial({map:bt,roughness:.45,metalness:.6});
   mats=[side,stdMat(0x6d6f73,{metalness:.8,roughness:.4}),stdMat(0x4a4c50,{metalness:.8,roughness:.5})];
   opt={color:p=>pick([0xb13a22,0x2e5fa8,0x2f7d4a,0xc79a2c,0x6b6f76]),rot:p=>rand(0,TAU)};
   addInstances(geo,mats,list,()=>h/2,opt);continue;
  }
  if(t===TY.PILLAR){
   geo=new THREE.CylinderGeometry(.75,.8,h,16);
   const side=sideM(sand||MAP.base==='haunt'?texPillar():snow?texPole():texPillarI(),{roughness:.8});
   mats=[side,stdMat(sand?0xd4c4a0:0x9aa0a6),stdMat(0x4a4c50)];
   addInstances(geo,mats,list,()=>h/2);
   // chapiteau + base
   const capM=stdMat(sand?0xcdb98c:0x7c838b),cap=new THREE.BoxGeometry(2,.3,2);
   addInstances(cap,capM,list,()=>h-.15);addInstances(cap,capM,list,()=>.15);
   continue;
  }
  geo=new THREE.BoxGeometry(S,h,S);
  if(haunt&&(mats=hauntMats(t,h,sideM,topM,boxMats))){}
  else if(snow){
   if(t===TY.WALL)mats=boxMats(sideM(texRock(h)),topM(null,0xf4f8fd));
   else if(t===TY.HOUSE)mats=boxMats(sideM(texCabin(h)),topM(null,0xf4f8fd));
   else if(t===TY.CRATE)mats=boxMats(sideM(texCrateMetal(h)),topM(null,0xf1f5fa));
   else if(t===TY.LOW)mats=boxMats(sideM(texSnowbank(h)),topM(null,0xffffff));
   else if(t===TY.PLAT)mats=boxMats(sideM(texWoodDeck(h)),topM(texDeck()));
   else if(t===TY.CONT){mats=boxMats(sideM(texContainer(h),{roughness:.55,metalness:.5}),topM(null,0xf1f5fa));opt={color:p=>pick([0xc0392b,0x2e86c1,0xd68910,0x239b56,0xe5e8e8,0x6c7a89,0xb9770e])};}
   else mats=boxMats(sideM(texConcrete(h)),topM(null,0xf4f8fd));
  }else if(t===TY.WALL)mats=boxMats(sideM(texPlaster(h,wallPal||['#e6d6ae','#cdb98c','#a8603e'])),topM(null,0xcdb78d));
  else if(t===TY.HOUSE)mats=boxMats(sideM(texHouse(h,housePal)),topM(texRoof()));
  else if(t===TY.CRATE){mats=boxMats(sideM(sand?texCrate(h):texCrateMetal(h)),topM(null,sand?0x9a6a38:0x6a7458));}
  else if(t===TY.LOW){mats=boxMats(sideM(sand?texStone(h):texConcrete(h)),topM(null,sand?0xcdbf9d:0x8f949a));}
  else if(t===TY.PLAT){mats=boxMats(sideM(sand?texPlaster(h,['#e6d6ae','#cdb98c','#a8603e']):texConcrete(h)),topM(sand?texPlat():texPlatI()));}
  else if(t===TY.CONT){mats=boxMats(sideM(MAP.theme==='metro'?texTrain(h):texContainer(h),{roughness:.55,metalness:.5}),topM(texCorrug()));opt={color:p=>pick([0xc0392b,0x2e86c1,0xd68910,0x239b56,0xe5e8e8,0x6c7a89,0x8e44ad,0xb9770e])};}
  else if(t===TY.CONC){mats=boxMats(sideM(texConcrete(h)),topM(null,0x8d949b));}
  else mats=boxMats(sideM(texPlaster(h,['#e6d6ae','#cdb98c','#a8603e'])),topM(null,0xcdb78d));
  const m=addInstances(geo,mats,list,()=>h/2,opt);
  if(opt.color&&m.instanceColor)m.instanceColor.needsUpdate=true;
  // corniches / socles
  if(t===TY.WALL||t===TY.HOUSE||t===TY.CONC||t===TY.PLAT){
   const capG=new THREE.BoxGeometry(S+.28,.28,S+.28),baseG=new THREE.BoxGeometry(S+.12,.42,S+.12);
   const capC=snow?0xf7faff:t===TY.HOUSE?0xa04a2c:sand?0xbfa97f:0x6b727a;
   if(t!==TY.PLAT)addInstances(capG,stdMat(capC,{roughness:.8}),list,()=>h+.14);
   addInstances(baseG,stdMat(sand?0x7b6948:0x4d535b,{roughness:.9}),list,()=>.21);
  }
 }
 // rampes
 const stoneM=stdMat(sand?0xcdb98c:snow?0xffffff:0x8c939c,{roughness:.9,map:sand?texPlat():snow?texDeck():texPlatI()});
 for(const R of RAMPS){const s=stairsMesh(R,th,stoneM);worldG.add(s);}
 // plafonds
 const ceilCells={};
 for(let i=0;i<NC;i++){if(G_CEIL[i]<90&&!G_TYPE[i]){const k=G_CEIL[i].toFixed(2);(ceilCells[k]||(ceilCells[k]=[])).push([i%N,(i/N)|0]);}}
 for(const k in ceilCells){
  const h=+k,list=ceilCells[k];
  const slab=addInstances(new THREE.BoxGeometry(S,.4,S),stdMat(0xffffff,{map:(sand||snow||haunt)?texWoodCeil():texCorrug(),roughness:.8,metalness:(sand||snow)?0:.5}),list,()=>h+.2);
  addInstances(new THREE.BoxGeometry(S,.22,.22),stdMat((sand||snow)?0x5b3b19:0x3a3f46),list,()=>h-.11,{rot:()=>0});
  addInstances(new THREE.BoxGeometry(.22,.22,S),stdMat(sand?0x5b3b19:0x3a3f46),list,()=>h-.11);
 }
 // arches
 const archM=stdMat(sand?0xcdb78d:0x8d949b,{roughness:.9}),trimM=stdMat(sand?0x7b6948:0x4d535b);
 for(const a of MAP.arches)worldG.add(lintelMesh(a,archM,trimM));
 // décors
 (DECOR[id]||(()=>{}))(th);
 buildSkyline(th,sand);
 {const seen=new Set(),tc=th.tint?C(th.tint):null;worldG.traverse(o=>{if(!o.material)return;(Array.isArray(o.material)?o.material:[o.material]).forEach(m=>{if(m.isMeshStandardMaterial){m.envMapIntensity=th.env;if(tc&&!seen.has(m)&&m.map){seen.add(m);m.color.multiply(tc);}}});});}
 sun.shadow.needsUpdate=true;
}
// relief lointain réaliste : anneau de terrain (bruit fractal en crêtes), couleurs selon l'altitude et la pente
function terrainRing(o){
 const AS=180,RS=34,cx=N*S/2,cz=N*S/2,sd=o.seed||1;
 const hs=(x,y)=>{const v=Math.sin(x*127.1+y*311.7+sd*17.3)*43758.5453;return v-Math.floor(v);};
 const vn=(x,y)=>{const ix=Math.floor(x),iy=Math.floor(y);let fx=x-ix,fy=y-iy;fx=fx*fx*(3-2*fx);fy=fy*fy*(3-2*fy);
  return lerp(lerp(hs(ix,iy),hs(ix+1,iy),fx),lerp(hs(ix,iy+1),hs(ix+1,iy+1),fx),fy);};
 const ridge=(x,y)=>{let v=0,a=.5,f=1;for(let k=0;k<6;k++){const n=1-Math.abs(vn(x*f,y*f)*2-1);v+=a*n*n;a*=.5;f*=2.03;}return v;};
 const pos=[],col=[],idx=[],c=new THREE.Color(),cr=new THREE.Color(o.rock),H=[];
 for(let j=0;j<=RS;j++){const k=j/RS,r=lerp(o.r0,o.r1,Math.pow(k,1.3));
  for(let i=0;i<=AS;i++){const a=i/AS*TAU,x=Math.cos(a)*r,z=Math.sin(a)*r;
   // enveloppe : nul au pied, crêtes au milieu, plus bas au loin (le brouillard fait le reste)
   const env=Math.sin(Math.min(1,k*1.25)*Math.PI*.5)*(1-.35*k);
   const u=Math.cos(a)*3.2*o.rough+sd,v=Math.sin(a)*3.2*o.rough+k*2.4;
   const h=Math.max(0,ridge(u,v)-.18)*1.4*o.hMax*env+(k>0?0:-2);
   H.push(h);pos.push(cx+x,h-1.5,cz+z);}}
 for(let j=0;j<RS;j++)for(let i=0;i<AS;i++){const a=j*(AS+1)+i,b=a+AS+1;idx.push(a,b,a+1,a+1,b,b+1);}
 const g=new THREE.BufferGeometry();g.setAttribute('position',new THREE.Float32BufferAttribute(pos,3));g.setIndex(idx);g.computeVertexNormals();
 const nr=g.attributes.normal;
 for(let n=0;n<H.length;n++){const t=clamp(H[n]/o.hMax,0,1),ny=nr.getY(n);
  let ci=0;while(ci<o.cols.length-2&&t>o.cols[ci+1][0])ci++;const A=o.cols[ci],B=o.cols[ci+1];
  c.set(A[1]).lerp(new THREE.Color(B[1]),clamp((t-A[0])/(B[0]-A[0]),0,1));
  const steep=clamp((.82-ny)*3.5,0,1);c.lerp(cr,o.snowSlope&&t>.45?steep*.85:steep*.7);
  const jit=.92+hs(n*.37,n*.11)*.16;col.push(c.r*jit,c.g*jit,c.b*jit);}
 g.setAttribute('color',new THREE.Float32BufferAttribute(col,3));
 const m=new THREE.Mesh(g,new THREE.MeshStandardMaterial({vertexColors:true,roughness:1,flatShading:false}));
 m.frustumCulled=false;worldG.add(m);return m;
}
function buildSkyline(th,sand){
 if(MAP.base==='haunt')return;
 if(MAP.theme==='jungle'){terrainRing({r0:68,r1:210,hMax:46,rough:1,cols:[[0,0x2e4a2a],[.45,0x3d6236],[.8,0x5b7a46],[1,0x7a7f6a]],rock:0x5d5a4c,seed:3});return;}
 if(MAP.base==='snow'){terrainRing({r0:70,r1:215,hMax:58,rough:1.2,cols:[[0,0x58627a],[.35,0x6d7890],[.5,0xe8eef8],[1,0xffffff]],rock:0x55606f,snowSlope:1,seed:7});return;}
 const list=[];for(let i=0;i<90;i++){const a=rand(0,TAU),r=rand(58,115);list.push({x:N*S/2+Math.cos(a)*r,z:N*S/2+Math.sin(a)*r,w:rand(6,14),h:rand(sand?6:8,sand?18:30),d:rand(6,14)});}
 const sk=new THREE.InstancedMesh(GBOX,new THREE.MeshStandardMaterial({color:0xffffff,roughness:1}),list.length);
 const mt=new THREE.Matrix4(),q=new THREE.Quaternion(),col=new THREE.Color();
 list.forEach((b,i)=>{mt.compose(new THREE.Vector3(b.x,b.h/2-1,b.z),q,new THREE.Vector3(b.w,b.h,b.d));sk.setMatrixAt(i,mt);
  if(sand)col.setHSL(.09+rand(-.01,.02),rand(.25,.4),rand(.55,.72));else col.setHSL(.62+rand(-.03,.03),rand(.05,.15),rand(.22,.4));sk.setColorAt(i,col);});
 sk.frustumCulled=false;worldG.add(sk);
 if(MAP.theme!=='metro')terrainRing(sand?{r0:125,r1:230,hMax:30,rough:.8,cols:[[0,0xb59a72],[.6,0xa58660],[1,0x8e7556]],rock:0x8a6a4c,seed:5}:
  {r0:125,r1:230,hMax:34,rough:.9,cols:[[0,0x4c4a52],[.6,0x5a5560],[1,0x6a6470]],rock:0x403c44,seed:9});
 if(sand){
  for(let i=0;i<8;i++){const a=rand(0,TAU),r=rand(62,100),x=N*S/2+Math.cos(a)*r,z=N*S/2+Math.sin(a)*r;
   const t=new THREE.Mesh(new THREE.CylinderGeometry(1.2,1.7,28,12),stdMat(0xe9dfc8));t.position.set(x,13,z);worldG.add(t);
   const d=new THREE.Mesh(new THREE.ConeGeometry(1.9,5.5,12),stdMat(0x3f8f86,{metalness:.3,roughness:.5}));d.position.set(x,30.5,z);worldG.add(d);
   const b=new THREE.Mesh(new THREE.TorusGeometry(1.5,.18,6,16),stdMat(0xd9c9a0));b.rotation.x=Math.PI/2;b.position.set(x,22,z);worldG.add(b);}
 }else{
  for(let i=0;i<7;i++){const a=rand(0,TAU),r=rand(60,100),x=N*S/2+Math.cos(a)*r,z=N*S/2+Math.sin(a)*r;
   const sl=new THREE.Mesh(new THREE.CylinderGeometry(3.2,3.2,34,14),stdMat(0x9aa0a6,{metalness:.5,roughness:.5}));sl.position.set(x,16,z);worldG.add(sl);
   const cap=new THREE.Mesh(new THREE.ConeGeometry(3.4,4,14),stdMat(0x6b727a));cap.position.set(x,35,z);worldG.add(cap);}
  for(let i=0;i<4;i++){const a=rand(0,TAU),r=rand(62,95),x=N*S/2+Math.cos(a)*r,z=N*S/2+Math.sin(a)*r;
   const st=new THREE.Mesh(new THREE.CylinderGeometry(1.4,2,44,10),stdMat(0x5a5f66));st.position.set(x,21,z);worldG.add(st);
   const sm=new THREE.Mesh(new THREE.CylinderGeometry(1.6,1.4,3,10),stdMat(0xc0392b));sm.position.set(x,41,z);worldG.add(sm);}
 }
}

/* ---------------- décors spécifiques ---------------- */
const DECOR={};
function glowSprite(x,y,z,kind,size,op,flicker){
 const s=new THREE.Sprite(new THREE.SpriteMaterial({map:GLOW[kind],blending:THREE.AdditiveBlending,transparent:true,depthWrite:false,opacity:op||1,fog:false}));
 s.scale.set(size,size,1);s.position.set(x,y,z);worldG.add(s);
 if(flicker){const ph=rand(0,TAU),base=op||1;worldAnim.push(t=>{s.material.opacity=base*(.8+.2*Math.sin(t*7+ph)*Math.sin(t*3.1+ph));});}
 return s;
}
function clothMesh(w,h,tex,x,y,z,ry,amp){
 const geo=new THREE.PlaneGeometry(w,h,14,6),m=new THREE.Mesh(geo,new THREE.MeshStandardMaterial({map:tex,side:THREE.DoubleSide,roughness:.9}));
 m.position.set(x,y,z);m.rotation.y=ry||0;m.castShadow=true;worldG.add(m);
 const p=geo.attributes.position,base=Float32Array.from(p.array),ph=rand(0,TAU);
 worldAnim.push(t=>{for(let i=0;i<p.count;i++){const bx=base[i*3],by=base[i*3+1];p.setZ(i,Math.sin(bx*2.2+t*3+ph)*amp*(.4+(bx/w+.5))+Math.sin(by*3+t*2)*amp*.2);}p.needsUpdate=true;});
 return m;
}
function palmTree(cx,cz,sc){
 const g=new THREE.Group();g.position.set(cc(cx),0,cc(cz));g.scale.setScalar(sc||1);
 const trunk=new THREE.Mesh(new THREE.CylinderGeometry(.14,.24,4,10),stdMat(0x7a5a3a,{roughness:1}));trunk.position.y=2;trunk.rotation.z=.07;trunk.castShadow=true;g.add(trunk);
 const lt=canvasTex(64,128,(c,w,h)=>{const gr=c.createLinearGradient(0,0,w,0);gr.addColorStop(0,'#2d6d2a');gr.addColorStop(.5,'#58a042');gr.addColorStop(1,'#2d6d2a');c.fillStyle=gr;c.fillRect(0,0,w,h);for(let y=0;y<h;y+=5){c.fillStyle='rgba(0,0,0,.2)';c.fillRect(w/2-1,y,2,3);}});
 const lg=new THREE.PlaneGeometry(.6,2.6,1,6);lg.translate(0,1.3,0);
 const pp=lg.attributes.position;for(let i=0;i<pp.count;i++){const y=pp.getY(i);pp.setZ(i,-y*y*.12);}lg.computeVertexNormals();
 const lm=new THREE.MeshStandardMaterial({map:lt,side:THREE.DoubleSide,roughness:.8});
 for(let i=0;i<9;i++){const l=new THREE.Mesh(lg,lm);l.position.set(.25,4,0);l.rotation.order='YXZ';l.rotation.y=i*.7+rand(-.2,.2);l.rotation.x=-.9-rand(0,.4);l.castShadow=true;g.add(l);}
 const ph=rand(0,TAU);worldAnim.push(t=>{g.rotation.z=Math.sin(t*.8+ph)*.012;g.rotation.x=Math.cos(t*.7+ph)*.01;});
 worldG.add(g);
}
function bunting(x1,y1,z1,x2,y2,z2,cols){
 const n=14,g=new THREE.Group();
 const pts=[];for(let i=0;i<=n;i++){const t=i/n;pts.push(new THREE.Vector3(lerp(x1,x2,t),lerp(y1,y2,t)-Math.sin(t*Math.PI)*.45,lerp(z1,z2,t)));}
 g.add(new THREE.Line(new THREE.BufferGeometry().setFromPoints(pts),new THREE.LineBasicMaterial({color:0x3a2a1a})));
 const tri=new THREE.BufferGeometry();tri.setAttribute('position',new THREE.Float32BufferAttribute([-.14,0,0,.14,0,0,0,-.3,0],3));tri.computeVertexNormals();
 for(let i=1;i<n;i++){const m=new THREE.Mesh(tri,new THREE.MeshStandardMaterial({color:C(pick(cols)),side:THREE.DoubleSide,roughness:.9}));m.position.copy(pts[i]);m.rotation.y=Math.atan2(x2-x1,z2-z1)+Math.PI/2;g.add(m);}
 worldG.add(g);worldAnim.push(t=>{g.rotation.z=Math.sin(t*1.5+x1)*.01;});
}
function lantern(x,y,z,col){
 const m=new THREE.Mesh(new THREE.CylinderGeometry(.12,.12,.28,8),new THREE.MeshStandardMaterial({color:C(0x333333),emissive:new THREE.Color(col||0xffc060),emissiveIntensity:1.6,roughness:.5}));m.position.set(x,y,z);worldG.add(m);
 glowSprite(x,y,z,'warm',1.8,.7,true);
}
DECOR.village=function(th){
 // palmiers
 for(const [px,pz,s] of [[1,1,1],[38,1,1.1],[12,1,.9],[25,1,1],[14,38,1],[25,38,1.05],[1,38,1.1],[38,38,1],[25,12,.9],[20,12,1]])palmTree(px,pz,s);
 // bannières CT / T
 const bn=(txt,c1,c2)=>canvasTex(256,128,(c,w,h)=>{const g=c.createLinearGradient(0,0,0,h);g.addColorStop(0,c1);g.addColorStop(1,c2);c.fillStyle=g;c.fillRect(0,0,w,h);c.strokeStyle='rgba(255,255,255,.85)';c.lineWidth=6;c.strokeRect(8,8,w-16,h-16);c.fillStyle='#fff';c.font='bold 74px Arial';c.textAlign='center';c.textBaseline='middle';c.fillText(txt,w/2,h/2+4);});
 clothMesh(7,3.5,bn('CT','#3a7de0','#1b3f86'),40,3.6,2.05,0,.12);
 clothMesh(7,3.5,bn('T','#e0662d','#8a2f10'),40,3.6,N*S-2.05,Math.PI,.12);
 // tour de l'horloge sur la maison centrale
 const stone=stdMat(0xc9b88f,{roughness:.9});
 const post=new THREE.Mesh(new THREE.CylinderGeometry(1.15,1.4,6.5,16),stone);post.position.set(40,TYH[3]+3.25,37);post.castShadow=true;worldG.add(post);
 const bal=new THREE.Mesh(new THREE.CylinderGeometry(1.6,1.3,.4,16),stone);bal.position.set(40,TYH[3]+6.6,37);worldG.add(bal);
 const roof=new THREE.Mesh(new THREE.ConeGeometry(1.9,2.8,16),stdMat(0xa04a2c,{roughness:.7}));roof.position.set(40,TYH[3]+8.2,37);roof.castShadow=true;worldG.add(roof);
 const clk=new THREE.Mesh(new THREE.CircleGeometry(.68,24),new THREE.MeshStandardMaterial({color:0xf5efe0,roughness:.5}));
 for(const [dx,dz,ry] of [[0,1.3,0],[0,-1.3,Math.PI],[1.3,0,Math.PI/2],[-1.3,0,-Math.PI/2]]){const c=clk.clone();c.position.set(40+dx,TYH[3]+5,37+dz);c.rotation.y=ry;worldG.add(c);}
 // auvent du souk
 const awnTex=canvasTex(128,128,(c,w,h)=>{for(let i=0;i<8;i++){c.fillStyle=i&1?'#f2e9d8':'#c8412f';c.fillRect(i*16,0,16,h);}});
 const awn=new THREE.Mesh(new THREE.PlaneGeometry(7,4.6),new THREE.MeshStandardMaterial({map:awnTex,side:THREE.DoubleSide,roughness:.9}));
 awn.rotation.x=-Math.PI/2+.12;awn.position.set(74,3.6,16);awn.castShadow=true;worldG.add(awn);
 for(const [px,pz] of [[70.8,13.4],[77.2,13.4],[70.8,18.6],[77.2,18.6]]){const p=new THREE.Mesh(new THREE.CylinderGeometry(.07,.07,3.6,8),stdMat(0x5b3b19));p.position.set(px,1.8,pz);worldG.add(p);}
 // guirlandes entre les maisons et au-dessus du hub
 bunting(28,4.4,30,52,4.4,30,[0xe74c3c,0xf1c40f,0x3498db,0x2ecc71,0xffffff]);
 bunting(28,4.4,56,52,4.4,56,[0xe74c3c,0xf1c40f,0x3498db,0xffffff]);
 bunting(18,4.5,36,22,4.5,36,[0xe74c3c,0xf1c40f,0x2ecc71]);
 bunting(18,4.5,46,22,4.5,46,[0xe74c3c,0xf1c40f,0x2ecc71]);
 bunting(58,4.5,36,62,4.5,36,[0xe74c3c,0xf1c40f,0x2ecc71]);
 // lanternes
 for(const [x,y,z] of [[29,3,30],[51,3,30],[29,3,50],[51,3,50],[27,3,13],[53,3,13],[17,3,40],[63,3,40],[40,3,22],[40,3,58],[26,3,6],[54,3,6],[12,3,70],[68,3,70]])lantern(x,y,z);
 // planteurs / pots près des sites
 for(const [cx,cz] of [[10,1],[12,6],[28,9],[37,3]]){const p=new THREE.Mesh(new THREE.CylinderGeometry(.35,.28,.55,10),stdMat(0xb5683f));p.position.set(cc(cx),.28,cc(cz));p.castShadow=true;worldG.add(p);const b=new THREE.Mesh(new THREE.SphereGeometry(.4,10,8),stdMat(0x3e8a3a));b.position.set(cc(cx),.8,cc(cz));worldG.add(b);}
};
DECOR.warehouse=function(th){
 const bn=(txt,c1,c2)=>canvasTex(256,128,(c,w,h)=>{const g=c.createLinearGradient(0,0,0,h);g.addColorStop(0,c1);g.addColorStop(1,c2);c.fillStyle=g;c.fillRect(0,0,w,h);c.strokeStyle='rgba(255,255,255,.85)';c.lineWidth=6;c.strokeRect(8,8,w-16,h-16);c.fillStyle='#fff';c.font='bold 74px Arial';c.textAlign='center';c.textBaseline='middle';c.fillText(txt,w/2,h/2+4);});
 clothMesh(7,3.5,bn('CT','#3a7de0','#1b3f86'),40,3.6,2.05,0,.1);
 clothMesh(7,3.5,bn('T','#e0662d','#8a2f10'),40,3.6,N*S-2.05,Math.PI,.1);
 // poutres de pont roulant au-dessus de la halle
 const steel=stdMat(0x4a525c,{metalness:.7,roughness:.45});
 for(const z of [26,36,46,56]){const b=new THREE.Mesh(GBOX,steel);b.scale.set(36,.7,.5);b.position.set(40,8.4,z);b.castShadow=true;worldG.add(b);
  const b2=new THREE.Mesh(GBOX,steel);b2.scale.set(36,.2,1.2);b2.position.set(40,8.0,z);worldG.add(b2);
  for(const x of [26,54]){const c=new THREE.Mesh(GBOX,steel);c.scale.set(.6,4,.6);c.position.set(x,6.4,z);worldG.add(c);}}
 const rail=new THREE.Mesh(GBOX,steel);rail.scale.set(.5,.5,32);rail.position.set(26,8.4,41);worldG.add(rail);const rail2=rail.clone();rail2.position.x=54;worldG.add(rail2);
 // projecteurs sur poteaux
 const flood=(x,z,h,col)=>{const p=new THREE.Mesh(new THREE.CylinderGeometry(.12,.16,h,8),steel);p.position.set(x,h/2,z);p.castShadow=true;worldG.add(p);
  const lamp=new THREE.Mesh(GBOX,new THREE.MeshStandardMaterial({color:0x222222,emissive:new THREE.Color(col),emissiveIntensity:2.2}));lamp.scale.set(.9,.35,.5);lamp.position.set(x,h+.1,z);worldG.add(lamp);
  glowSprite(x,h+.1,z,'warm',5,.9,true);};
 for(const [cx,cz] of [[12,2],[27,2],[12,14],[27,14],[12,34],[27,34],[2,10],[37,10],[2,38],[37,38],[19,28],[20,12]])flood(cc(cx),cc(cz),6.4,0xffd9a0);
 // tuyaux le long des murs
 const pipeM=stdMat(0x6f7a85,{metalness:.7,roughness:.45}),pipeRed=stdMat(0xa83a2a,{metalness:.5,roughness:.5});
 for(const [x1,z1,x2,z2,y,r,m] of [[2.3,2,2.3,78,5.2,.14,pipeM],[2,77.7,78,77.7,5.6,.18,pipeRed],[77.7,2,77.7,78,5.0,.14,pipeM]]){
  const L=Math.hypot(x2-x1,z2-z1),p=new THREE.Mesh(new THREE.CylinderGeometry(r,r,L,10),m);p.position.set((x1+x2)/2,y,(z1+z2)/2);p.rotation.set(Math.PI/2,0,Math.atan2(x2-x1,z2-z1)*0);if(x1===x2)p.rotation.x=Math.PI/2;else{p.rotation.set(0,0,Math.PI/2);}worldG.add(p);}
 // palettes décoratives au sol
 const pal=stdMat(0xb08a58,{roughness:.95});
 for(const [cx,cz] of [[2,10],[37,9],[22,2],[2,37],[37,37]]){const p=new THREE.Mesh(GBOX,pal);p.scale.set(1.2,.16,1.0);p.position.set(cc(cx),.08,cc(cz));p.castShadow=true;worldG.add(p);const b=new THREE.Mesh(GBOX,stdMat(0xc9a56b));b.scale.set(1,.7,.8);b.position.set(cc(cx),.5,cc(cz));b.castShadow=true;worldG.add(b);}
 // panneaux de danger lumineux
 for(const [x,z] of [[11.9,36],[28.1,36]]){const s=new THREE.Mesh(GBOX,new THREE.MeshStandardMaterial({color:0xe8b923,emissive:0x7a5a08,emissiveIntensity:.8}));s.scale.set(.1,.7,1.2);s.position.set(x,3.4,z);worldG.add(s);}
};
DECOR.station=function(th){
 // forêt de pins autour de la station (instanciée)
 const trees=[];for(let i=0;i<110;i++){const a=rand(0,TAU),r=rand(48,95);trees.push({x:N*S/2+Math.cos(a)*r*1.0,z:N*S/2+Math.sin(a)*r*1.0,s:rand(.8,1.7)});}
 const keep=trees.filter(t=>t.x<-3||t.x>N*S+3||t.z<-3||t.z>N*S+3);
 const mk=(geo,col,yOff)=>{const m=new THREE.InstancedMesh(geo,new THREE.MeshStandardMaterial({color:C(col),roughness:1}),keep.length);const mt=new THREE.Matrix4(),q=new THREE.Quaternion(),c=new THREE.Color();
  keep.forEach((t,i)=>{mt.compose(new THREE.Vector3(t.x,yOff*t.s,t.z),q,new THREE.Vector3(t.s,t.s,t.s));m.setMatrixAt(i,mt);c.setHSL(.38+rand(-.03,.03),.35,rand(.16,.26));m.setColorAt(i,c);});m.frustumCulled=false;m.castShadow=false;worldG.add(m);return m;};
 mk(new THREE.ConeGeometry(2.3,3.4,8),0x2f5d3a,3.2);mk(new THREE.ConeGeometry(1.8,3,8),0x2f5d3a,4.9);mk(new THREE.ConeGeometry(1.3,2.6,8),0x2f5d3a,6.4);
 const tk=new THREE.InstancedMesh(new THREE.CylinderGeometry(.22,.3,3,6),new THREE.MeshStandardMaterial({color:C(0x4a2e18)}),keep.length);const mt=new THREE.Matrix4(),q=new THREE.Quaternion();
 keep.forEach((t,i)=>{mt.compose(new THREE.Vector3(t.x,1.5*t.s,t.z),q,new THREE.Vector3(t.s,t.s,t.s));tk.setMatrixAt(i,mt);});tk.frustumCulled=false;worldG.add(tk);
 // bannières
 const bn=(txt,c1,c2)=>canvasTex(256,128,(c,w,h)=>{const g=c.createLinearGradient(0,0,0,h);g.addColorStop(0,c1);g.addColorStop(1,c2);c.fillStyle=g;c.fillRect(0,0,w,h);c.strokeStyle='rgba(255,255,255,.85)';c.lineWidth=6;c.strokeRect(8,8,w-16,h-16);c.fillStyle='#fff';c.font='bold 74px Arial';c.textAlign='center';c.textBaseline='middle';c.fillText(txt,w/2,h/2+4);});
 clothMesh(7,3,bn('CT','#3a7de0','#1b3f86'),40,4.2,2.05,0,.12);
 clothMesh(7,3.5,bn('T','#e0662d','#8a2f10'),40,3.6,N*S-2.05,Math.PI,.12);
 // mât radio avec balise
 const steel=stdMat(0x6a7480,{metalness:.7,roughness:.45});
 for(const [x,z,h] of [[51.5,3,12],[3.5,3,9]]){const m=new THREE.Mesh(new THREE.CylinderGeometry(.08,.14,h,8),steel);m.position.set(x,1.5+h/2,z);m.castShadow=true;worldG.add(m);
  for(let k=1;k<5;k++){const r=new THREE.Mesh(new THREE.TorusGeometry(.4+(.4-k*.08),.025,5,12),steel);r.rotation.x=Math.PI/2;r.position.set(x,1.5+k*h/5.4,z);worldG.add(r);}
  const gl=glowSprite(x,1.5+h+.3,z,'orange',1.8,1,false);const ph=rand(0,TAU);worldAnim.push(t=>{gl.material.opacity=.15+.85*Math.max(0,Math.sin(t*3+ph));});}
 // lampadaires
 const lamp=(x,z)=>{const p=new THREE.Mesh(new THREE.CylinderGeometry(.06,.08,4.2,6),stdMat(0x3a3a3a));p.position.set(x,2.1,z);worldG.add(p);
  const l=new THREE.Mesh(GBOX,new THREE.MeshStandardMaterial({color:0x222222,emissive:new THREE.Color(0xffd9a0),emissiveIntensity:2.2}));l.scale.set(.5,.2,.35);l.position.set(x,4.25,z);worldG.add(l);glowSprite(x,4.2,z,'warm',4.2,.85,true);};
 for(const [cx,cz] of [[10,8],[30,8],[10,20],[29,19],[10,34],[30,34],[22,18],[17,27],[2,14],[37,14],[12,2],[38,12]])lamp(cc(cx),cc(cz));
 // tentes
 const tentM=[stdMat(0xd8552b,{roughness:.8}),stdMat(0x2e7dd1,{roughness:.8}),stdMat(0xe0b02a,{roughness:.8})];
 for(const [cx,cz,i] of [[6,34,0],[34,33,1],[8,30,2],[35,30,0]]){const t=new THREE.Mesh(new THREE.SphereGeometry(1.3,14,8,0,TAU,0,Math.PI/2),tentM[i]);t.position.set(cc(cx),0,cc(cz));t.scale.set(1,.8,1);t.castShadow=true;worldG.add(t);
  const d=new THREE.Mesh(new THREE.PlaneGeometry(.5,.7),new THREE.MeshStandardMaterial({color:C(0x15181d)}));d.position.set(cc(cx),.4,cc(cz)+1.28);worldG.add(d);}
 // étang gelé brillant
 const ice=new THREE.Mesh(new THREE.PlaneGeometry(16,12),new THREE.MeshStandardMaterial({color:C(0xaad8f2),roughness:.08,metalness:.3,transparent:true,opacity:.55,envMapIntensity:1.6}));
 ice.rotation.x=-Math.PI/2;ice.position.set(40,.03,45);worldG.add(ice);
 // cheminées fumantes sur les cabanes
 for(const [x,z] of [[27,33],[53,33],[27,57],[53,57]]){const c=new THREE.Mesh(GBOX,stdMat(0x7a4a32));c.scale.set(.6,1.2,.6);c.position.set(x,TYH[3]+.6,z);worldG.add(c);
  let acc=0;worldAnim.push(t=>{acc+=1/60;if(acc>.35&&fxReady&&Math.random()<.5){acc=0;fxSmoke.emit(x,TYH[3]+1.3,z,rand(-.1,.3),rand(.5,1),rand(-.1,.1),rand(2.5,4),.25,1.5,.9,.9,.95,.35,-.1,.4);}});}
 // paraboles sur les toits
 for(const [x,z] of [[27,35],[53,35]]){const d=new THREE.Mesh(new THREE.SphereGeometry(.7,12,6,0,TAU,0,Math.PI/2.4),stdMat(0xe8eef5,{side:THREE.DoubleSide,roughness:.4,metalness:.4}));d.material.side=THREE.DoubleSide;d.rotation.set(Math.PI*.78,0,0);d.position.set(x,TYH[3]+.9,z);worldG.add(d);}
 // aurore dans le ciel
 const au=canvasTex(256,64,(c,w,h)=>{const g=c.createLinearGradient(0,0,w,0);g.addColorStop(0,'rgba(80,255,170,0)');g.addColorStop(.3,'rgba(80,255,170,.8)');g.addColorStop(.6,'rgba(90,200,255,.7)');g.addColorStop(1,'rgba(160,90,255,0)');c.fillStyle=g;c.fillRect(0,0,w,h);const v=c.createLinearGradient(0,0,0,h);v.addColorStop(0,'rgba(0,0,0,1)');v.addColorStop(.5,'rgba(0,0,0,0)');v.addColorStop(1,'rgba(0,0,0,1)');c.globalCompositeOperation='destination-out';c.fillStyle=v;c.fillRect(0,0,w,h);});
 for(let i=0;i<3;i++){const s=new THREE.Sprite(new THREE.SpriteMaterial({map:au,fog:false,transparent:true,depthWrite:false,blending:THREE.AdditiveBlending,opacity:.28,toneMapped:false}));const a=rand(0,TAU);s.scale.set(190,34,1);s.position.set(Math.cos(a)*150,rand(70,110),Math.sin(a)*150);skyG.add(s);worldAnim.push(t=>{s.material.opacity=.2+.12*Math.sin(t*.4+i*2);});}
};

/* ---------------- post-traitement (qualité Haute) ----------------
   La scène est rendue dans une texture puis composée : halo lumineux
   (bloom) autour du soleil, des lampes et des flammes, contraste et
   saturation légèrement relevés, vignettage discret. */
const POST={rt:null,bA:null,bB:null,q:null,cam:new THREE.OrthographicCamera(-1,1,1,-1,0,1),mBright:null,mBlur:null,mComp:null};
function postInit(){
 if(POST.q)return;
 const vs='varying vec2 vUv;void main(){vUv=uv;gl_Position=vec4(position.xy,0.,1.);}';
 POST.mBright=new THREE.ShaderMaterial({uniforms:{t:{value:null}},vertexShader:vs,depthTest:false,depthWrite:false,
  fragmentShader:'uniform sampler2D t;varying vec2 vUv;void main(){vec3 c=texture2D(t,vUv).rgb;float l=dot(c,vec3(.2126,.7152,.0722));gl_FragColor=vec4(c*smoothstep(.86,1.,l),1.);}'});
 POST.mBlur=new THREE.ShaderMaterial({uniforms:{t:{value:null},d:{value:new THREE.Vector2()}},vertexShader:vs,depthTest:false,depthWrite:false,
  fragmentShader:'uniform sampler2D t;uniform vec2 d;varying vec2 vUv;void main(){vec3 c=texture2D(t,vUv).rgb*.227;c+=(texture2D(t,vUv+d*1.385).rgb+texture2D(t,vUv-d*1.385).rgb)*.316;c+=(texture2D(t,vUv+d*3.231).rgb+texture2D(t,vUv-d*3.231).rgb)*.07;gl_FragColor=vec4(c,1.);}'});
 POST.mComp=new THREE.ShaderMaterial({uniforms:{t:{value:null},b:{value:null},bs:{value:.55},sat:{value:1.1},con:{value:1.06},vig:{value:.28}},vertexShader:vs,depthTest:false,depthWrite:false,
  fragmentShader:'uniform sampler2D t,b;uniform float bs,sat,con,vig;varying vec2 vUv;void main(){vec3 c=texture2D(t,vUv).rgb;c+=texture2D(b,vUv).rgb*bs;'+
  'float l=dot(c,vec3(.2126,.7152,.0722));c=mix(vec3(l),c,sat);c=(c-.5)*con+.5;'+
  'vec2 q=vUv-.5;c*=1.-vig*smoothstep(.25,.85,dot(q,q)*2.2);gl_FragColor=vec4(clamp(c,0.,1.),1.);}'});
 POST.q=new THREE.Mesh(new THREE.PlaneGeometry(2,2),POST.mComp);POST.q.frustumCulled=false;
 POST.scene=new THREE.Scene();POST.scene.add(POST.q);
}
function postSize(){
 const on=cfg.gfx>=2&&cfg.post!==0;POST.on=on;
 if(!on){for(const k of ['rt','bA','bB'])if(POST[k]){POST[k].dispose();POST[k]=null;}return;}
 postInit();
 const v=renderer.getDrawingBufferSize(new THREE.Vector2()),w=v.x,h=v.y;
 if(POST.rt&&POST.rt.width===w&&POST.rt.height===h)return;
 for(const k of ['rt','bA','bB'])if(POST[k])POST[k].dispose();
 const RT=renderer.capabilities.isWebGL2&&THREE.WebGLMultisampleRenderTarget?THREE.WebGLMultisampleRenderTarget:THREE.WebGLRenderTarget;
 POST.rt=new RT(w,h,{format:THREE.RGBAFormat,encoding:THREE.sRGBEncoding});if(POST.rt.samples!==undefined)POST.rt.samples=4;
 POST.rt.texture.encoding=THREE.sRGBEncoding;
 const bw=Math.max(1,w>>2),bh=Math.max(1,h>>2);
 POST.bA=new THREE.WebGLRenderTarget(bw,bh,{format:THREE.RGBAFormat});POST.bB=new THREE.WebGLRenderTarget(bw,bh,{format:THREE.RGBAFormat});
}
function postPass(m,src,dst){POST.q.material=m;if(m.uniforms.t)m.uniforms.t.value=src;renderer.setRenderTarget(dst);renderer.render(POST.scene,POST.cam);}
// commence le rendu de l'image (dans la texture si le post-traitement est actif)
function postBegin(){if(POST.on&&POST.rt){renderer.setRenderTarget(POST.rt);}renderer.clear();}
function postEnd(){
 if(!POST.on||!POST.rt)return;
 const ae=renderer.autoClear;renderer.autoClear=true;
 postPass(POST.mBright,POST.rt.texture,POST.bA);
 POST.mBlur.uniforms.d.value.set(1/POST.bA.width,0);postPass(POST.mBlur,POST.bA.texture,POST.bB);
 POST.mBlur.uniforms.d.value.set(0,1/POST.bA.height);postPass(POST.mBlur,POST.bB.texture,POST.bA);
 POST.mBlur.uniforms.d.value.set(2/POST.bA.width,0);postPass(POST.mBlur,POST.bA.texture,POST.bB);
 POST.mBlur.uniforms.d.value.set(0,2/POST.bA.height);postPass(POST.mBlur,POST.bB.texture,POST.bA);
 POST.mComp.uniforms.b.value=POST.bA.texture;
 const night=MAP&&(MAP.theme==='night'||MAP.theme==='haunt');POST.mComp.uniforms.bs.value=night?.75:.32;POST.mComp.uniforms.vig.value=night?.38:.26;
 postPass(POST.mComp,POST.rt.texture,null);
 renderer.autoClear=ae;
}
