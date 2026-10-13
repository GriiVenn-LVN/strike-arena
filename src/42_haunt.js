/* =====================================================================
   ASILE HANTÉ (carte Zombies) : orage, brume verdâtre, lune, bougies
   ===================================================================== */
THEMES.haunt={base:'haunt',sky:[[0,'#020406'],[.3,'#08120f'],[.44,'#16261f'],[.5,'#2c4236'],[.52,'#08100c'],[1,'#030605']],
 fog:0x0b1512,fogN:8,fogF:78,hemiS:0x5a7a8c,hemiG:0x0a0d09,hemiI:.28,sunC:0xb8ccff,sunI:.38,sunPos:[-45,62,-55],exp:1,env:.12,cloud:'45,60,58',tint:0x8f9a92};
function texBrick(hm){return cached('brick'+hm,()=>canvasTex(128,Math.round(PX*hm),(c,w,h)=>{
 c.fillStyle='#3a2620';c.fillRect(0,0,w,h);const bh=10,bw=32;
 for(let y=0,r=0;y<h;y+=bh,r++)for(let x=-(r&1)*bw/2;x<w;x+=bw){c.fillStyle='hsl('+rand(6,16)+','+rand(25,40)+'%,'+rand(18,28)+'%)';c.fillRect(x+1,y+1,bw-2,bh-2);}
 blotches(c,w,h,30,'20,30,20',.3,10,40);streaks(c,w,h,14,'10,14,10',.35);cracks(c,w,h,6,'10,8,6');speck(c,w,h,600,.04,.12,3);
 const g=c.createLinearGradient(0,h*.7,0,h);g.addColorStop(0,'rgba(30,50,25,0)');g.addColorStop(1,'rgba(30,50,25,.6)');c.fillStyle=g;c.fillRect(0,h*.7,w,h*.3);
}));}
function texTomb(hm){return cached('tomb'+hm,()=>canvasTex(128,Math.round(PX*hm),(c,w,h)=>{
 c.fillStyle='#5d625f';c.fillRect(0,0,w,h);blotches(c,w,h,22,'40,60,40',.3,8,30);speck(c,w,h,500,.05,.15,3);cracks(c,w,h,4,'25,25,25');
}));}
function texShelf(hm){return cached('shelf'+hm,()=>canvasTex(128,Math.round(PX*hm),(c,w,h)=>{
 c.fillStyle='#2a1a10';c.fillRect(0,0,w,h);const n=Math.max(2,Math.round(hm/.45));
 for(let k=0;k<n;k++){const y0=k*h/n;let x=6;while(x<w-8){const bw=rand(5,11);c.fillStyle='hsl('+pick([0,20,35,120,210,280])+','+rand(25,55)+'%,'+rand(15,35)+'%)';c.fillRect(x,y0+rand(4,9),bw,h/n-rand(6,10));x+=bw+1;}
  c.fillStyle='#4a2e1a';c.fillRect(0,y0+h/n-4,w,4);}
 c.fillStyle='#4a2e1a';c.fillRect(0,0,5,h);c.fillRect(w-5,0,5,h);blotches(c,w,h,12,'0,0,0',.3,8,30);
}));}
// matériaux des blocs pour la carte hantée (null = rendu standard)
function hauntMats(t,h,sideM,topM,boxMats){
 if(t===TY.WALL||t===TY.CONC||t===TY.HOUSE)return boxMats(sideM(texBrick(h)),topM(null,0x2a2622));
 if(t===TY.LOW)return h<=.55?boxMats(sideM(texWoodDeck(h)),topM(texDeck())):boxMats(sideM(texTomb(h)),topM(null,0x4d524f));
 if(t===TY.CRATE)return boxMats(sideM(texShelf(h)),topM(null,0x2a1a10));
 if(t===TY.PLAT)return boxMats(sideM(texBrick(h)),topM(texWoodCeil()));
 return null;
}
function deadTree(x,z,s){
 const g=new THREE.Group(),bark=stdMat(0x2a2420,{roughness:1});g.position.set(x,0,z);g.scale.setScalar(s||1);
 const tr=new THREE.Mesh(new THREE.CylinderGeometry(.12,.3,4.4,7),bark);tr.position.y=2.2;tr.rotation.z=rand(-.08,.08);tr.castShadow=true;g.add(tr);
 for(let i=0;i<6;i++){const L=rand(1.2,2.4),b=new THREE.Mesh(new THREE.CylinderGeometry(.03,.09,L,5),bark);const a=rand(0,TAU),y=rand(2.4,4.1);
  b.position.set(Math.cos(a)*L*.35,y+L*.3,Math.sin(a)*L*.35);b.rotation.set(Math.sin(a)*.9,0,-Math.cos(a)*.9);b.castShadow=true;g.add(b);}
 worldG.add(g);const ph=rand(0,6);worldAnim.push(t=>{g.rotation.z=Math.sin(t*.9+ph)*.015;});
}
function candle(x,y,z){
 const m=new THREE.Mesh(new THREE.CylinderGeometry(.035,.04,.22,6),stdMat(0xeee4c8));m.position.set(x,y+.11,z);worldG.add(m);
 glowSprite(x,y+.27,z,'warm',.55,.9,true);
}
DECOR.asile=function(th){
 stars(160,185);
 // lune
 const mt=canvasTex(128,128,(c,w,h)=>{const g=c.createRadialGradient(54,54,8,64,64,62);g.addColorStop(0,'#f4f6ff');g.addColorStop(.85,'#c8d2e6');g.addColorStop(1,'rgba(200,210,230,0)');c.fillStyle=g;c.beginPath();c.arc(64,64,62,0,TAU);c.fill();
  for(let i=0;i<9;i++){c.fillStyle='rgba(120,130,150,'+rand(.15,.3)+')';c.beginPath();c.arc(rand(30,98),rand(30,98),rand(4,12),0,TAU);c.fill();}});
 const moon=new THREE.Sprite(new THREE.SpriteMaterial({map:mt,fog:false,depthWrite:false,toneMapped:false}));moon.scale.set(26,26,1);
 moon.position.copy(new THREE.Vector3(...th.sunPos).normalize().multiplyScalar(175));skyG.add(moon);
 // arbres morts : cimetière, cour nord, jardin, et derrière les murs
 for(const [cx,cz,s] of [[2,21,1.1],[12,29,.9],[4,38,1],[12,38,1.2],[15,11,1],[24,11,.9],[36,21,1],[29,29,.9],[37,30,1.1]])deadTree(cc(cx),cc(cz),s);
 for(let i=0;i<16;i++){const a=rand(0,TAU),r=rand(48,70);deadTree(40+Math.cos(a)*r,40+Math.sin(a)*r,rand(1.6,2.6));}
 // croix sur les tombes
 const stone=stdMat(0x6a6f6b,{roughness:1});
 for(let cz=20;cz<39;cz++)for(let cx=1;cx<13;cx++){const i=cz*N+cx;if(G_TYPE[i]!==TY.LOW)continue;
  const g=new THREE.Group();g.position.set(cc(cx),.9,cc(cz));g.rotation.y=rand(-.2,.2);g.rotation.z=rand(-.1,.1);
  const v=new THREE.Mesh(GBOX,stone);v.scale.set(.18,1.1,.18);v.position.y=.55;const hb=new THREE.Mesh(GBOX,stone);hb.scale.set(.7,.16,.16);hb.position.y=.8;g.add(v,hb);v.castShadow=hb.castShadow=true;worldG.add(g);}
 // chapelle : bougies sur l'autel, vitrail, croix, éclairage chaud vacillant
 for(const [x,z] of [[35,53],[37,53],[43,53],[45,53],[34.5,54],[45.5,54]])candle(x,.45,z);
 for(const [x,z] of [[29,77.4],[51,77.4]])for(let k=0;k<5;k++)candle(x+rand(-.6,.6),0,z-rand(0,.6));
 const vt=canvasTex(128,256,(c,w,h)=>{c.fillStyle='#111';c.fillRect(0,0,w,h);const cols=['#c0392b','#2e86c1','#d4ac0d','#27ae60','#8e44ad','#e67e22'];
  for(let y=8;y<h-8;y+=24)for(let x=8;x<w-8;x+=24){c.fillStyle=pick(cols);c.fillRect(x+2,y+2,20,20);}
  c.strokeStyle='#111';c.lineWidth=6;c.beginPath();c.arc(w/2,60,52,0,TAU);c.stroke();c.fillStyle='#f5e6b0';c.fillRect(w/2-6,30,12,190);c.fillRect(w/2-40,80,80,12);});
 const vit=new THREE.Mesh(new THREE.PlaneGeometry(3.4,6.4),new THREE.MeshBasicMaterial({map:vt,toneMapped:false,transparent:true,opacity:.9}));vit.position.set(40,3.6,77.9);vit.rotation.y=Math.PI;worldG.add(vit);
 glowSprite(40,3.6,77,'warm',9,.25,false);
 const cross=new THREE.Group(),gold=new THREE.MeshStandardMaterial({color:C(0xc9a24a),metalness:.9,roughness:.3});
 {const a=new THREE.Mesh(GBOX,gold);a.scale.set(.18,1.6,.12);const b=new THREE.Mesh(GBOX,gold);b.scale.set(.9,.18,.12);b.position.y=.3;cross.add(a,b);}cross.position.set(40,1.6,52.6);worldG.add(cross);
 const PL=(x,y,z,col,I,d)=>{const L=new THREE.PointLight(col,I,d||18,2);L.position.set(x,y,z);worldG.add(L);return L;};
 const ch1=PL(36,2.2,56,0xffa860,5),ch2=PL(44,2.2,56,0xffa860,5),ch3=PL(40,2.6,72,0xff9a50,5,20);
 // infirmerie : néon qui grésille ; crypte : lueur verte ; aile des malades : lampe rouge
 const inf=PL(13,3.8,18,0xd8f0ff,16,24),cr=PL(66,2,20,0x40ff90,10,22),wd=PL(40,3.6,38,0xff3030,8,20);
 const neon=new THREE.Mesh(GBOX,new THREE.MeshStandardMaterial({color:0x222222,emissive:new THREE.Color(0xd8f0ff),emissiveIntensity:2}));neon.scale.set(2.4,.06,.25);neon.position.set(13,4.3,18);worldG.add(neon);
 glowSprite(66,1.4,20,'cool',4,.35,true);
 // lanternes du jardin, de la cour et du cimetière
 for(const [cx,cz] of [[28,24],[37,24],[28,35],[37,35],[16,6],[23,6],[3,20],[11,20]])lantern(cc(cx),2.6,cc(cz),0xffb050);
 // cloche du clocher
 const bell=new THREE.Mesh(new THREE.CylinderGeometry(.35,.75,1,14,1,true),new THREE.MeshStandardMaterial({color:C(0x8a6a2a),metalness:.9,roughness:.35,side:THREE.DoubleSide}));bell.position.set(40,6.4,7);worldG.add(bell);
 for(const [dx,dz] of [[-2.5,-2],[2.5,-2],[-2.5,2],[2.5,2]]){const p=new THREE.Mesh(GBOX,stdMat(0x3a2a20));p.scale.set(.25,3.4,.25);p.position.set(40+dx,4.3,7+dz);worldG.add(p);}
 {const r=new THREE.Mesh(new THREE.ConeGeometry(4.2,2.4,4),stdMat(0x2a1e18));r.position.set(40,7.2,7);r.rotation.y=Math.PI/4;worldG.add(r);}
 // inscriptions sanglantes
 const scrawl=(txt,x,y,z,ry,w)=>{const t=canvasTex(512,128,(c,W,H)=>{c.font='bold 70px Georgia';c.textAlign='center';c.fillStyle='#8a0a0a';c.fillText(txt,W/2,80);for(let i=0;i<22;i++){const x=rand(40,W-40);c.fillRect(x,rand(70,85),rand(2,5),rand(10,40));}});
  const m=new THREE.Mesh(new THREE.PlaneGeometry(w,w/4),new THREE.MeshBasicMaterial({map:t,transparent:true,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-2}));m.position.set(x,y,z);m.rotation.y=ry;worldG.add(m);};
 scrawl('ILS ARRIVENT',40,3.6,52.06,0,6);scrawl('NE SORTEZ PAS',51.94,2.4,32,-Math.PI/2,5);scrawl('115',54.06,2.2,12,Math.PI/2,2.4);
 // brume au sol
 const ft=canvasTex(128,128,(c,w,h)=>{for(let i=0;i<12;i++){const x=rand(20,108),y=rand(20,108),r=rand(20,50),g=c.createRadialGradient(x,y,0,x,y,r);g.addColorStop(0,'rgba(150,190,170,.35)');g.addColorStop(1,'rgba(150,190,170,0)');c.fillStyle=g;c.fillRect(0,0,w,h);}});
 for(let i=0;i<30;i++){const m=new THREE.Mesh(new THREE.PlaneGeometry(14,14),new THREE.MeshBasicMaterial({map:ft,transparent:true,opacity:rand(.25,.5),depthWrite:false}));
  m.rotation.x=-Math.PI/2;const x0=rand(2,78),z0=rand(2,78);m.position.set(x0,rand(.25,.6),z0);worldG.add(m);const ph=rand(0,6);
  worldAnim.push(t=>{m.position.x=x0+Math.sin(t*.07+ph)*3;m.rotation.z=t*.02+ph;});}
 // éclairs : flash bleuté puis tonnerre
 const flash=new THREE.DirectionalLight(0xbfd4ff,0);flash.position.set(-30,80,-20);worldG.add(flash);
 let next=-1,fT=-99,boomAt=-1;
 worldAnim.push(t=>{
  if(next<0)next=t+rand(6,14);
  inf.intensity=Math.sin(t*41)>.92||Math.sin(t*2.3)>.97?1:9;neon.material.emissiveIntensity=inf.intensity>5?2:.2;
  ch1.intensity=4.5+Math.sin(t*9)*1+Math.sin(t*23)*.6;ch2.intensity=4.5+Math.sin(t*8.2+1)*1;ch3.intensity=5+Math.sin(t*6+2)*.9;
  wd.intensity=4+Math.max(0,Math.sin(t*2.5))*7;cr.intensity=8+Math.sin(t*1.3)*3;
  if(t>next){fT=t;next=t+rand(9,22);boomAt=t+rand(.6,2.2);}
  const a=t-fT;flash.intensity=a<.5?(a<.08?3.2:a<.16?.4:a<.24?2.4:Math.max(0,2.4-(a-.24)*9)):0;
  if(boomAt>0&&t>boomAt){boomAt=-1;if(G.running)sfx('thunder',undefined,undefined,.35);}
 });
};
