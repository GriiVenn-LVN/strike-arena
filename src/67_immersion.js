/* =====================================================================
   IMMERSION : météo & heure, musique dynamique, annonceur & radio des
   bots, killcam, podium MVP, tonneaux explosifs, taches de sang.
   ===================================================================== */
cfg.weather=cfg.weather||'clear';cfg.tod=cfg.tod||'day';
cfg.music=cfg.music===undefined?1:cfg.music;cfg.announcer=cfg.announcer===undefined?1:cfg.announcer;cfg.gore=cfg.gore===undefined?1:cfg.gore;
const WEATHERS=[{id:'clear',n:'Dégagé'},{id:'rain',n:'Pluie'},{id:'storm',n:'Orage'},{id:'fog',n:'Brouillard'}];
const TODS=[{id:'day',n:'Jour'},{id:'dusk',n:'Crépuscule'},{id:'night',n:'Nuit'}];

/* ---------- météo & heure ---------- */
const RAIN={n:900,mesh:null,geo:null,on:false,amt:0,lt:0,thunderAt:0,src:null,gain:null};
function ensureRain(){
 if(RAIN.mesh)return;
 const pos=new Float32Array(RAIN.n*6);RAIN.geo=new THREE.BufferGeometry();RAIN.geo.setAttribute('position',new THREE.BufferAttribute(pos,3));
 RAIN.seed=new Float32Array(RAIN.n*3);for(let i=0;i<RAIN.n;i++){RAIN.seed[i*3]=Math.random();RAIN.seed[i*3+1]=Math.random();RAIN.seed[i*3+2]=Math.random();}
 RAIN.mesh=new THREE.LineSegments(RAIN.geo,new THREE.LineBasicMaterial({color:0xb7cbe6,transparent:true,opacity:.24,depthWrite:false,fog:true}));
 RAIN.mesh.frustumCulled=false;RAIN.mesh.visible=false;scene.add(RAIN.mesh);
}
function applyAtmosphere(){
 ensureRain();
 const th=THEMES[MAP.theme],night=MAP.theme==='night'||MAP.base==='haunt';
 let fogC=new THREE.Color(th.fog),fogN=th.fogN,fogF=th.fogF,sunI=th.sunI,hemiI=th.hemiI,exp=th.exp,sunC=new THREE.Color(th.sunC),hemiS=new THREE.Color(th.hemiS);
 if(!night){
  if(cfg.tod==='dusk'){sunC.set(0xff8a4a);sunI*=.65;hemiI*=.85;fogC.lerp(new THREE.Color(0xd77a58),.55);hemiS.lerp(new THREE.Color(0xa78ad8),.4);exp*=.95;}
  else if(cfg.tod==='night'){sunC.set(0x7d97ff);sunI*=.14;hemiI*=.42;fogC.lerp(new THREE.Color(0x0b1424),.88);hemiS.lerp(new THREE.Color(0x4a66b0),.7);exp*=.85;}
 }
 const w=cfg.weather;
 RAIN.on=w==='rain'||w==='storm';RAIN.storm=w==='storm';
 if(w==='rain'||w==='storm'){sunI*=w==='storm'?.3:.55;hemiI*=.85;fogC.lerp(new THREE.Color(0x6c7684),w==='storm'?.7:.45);fogF*=w==='storm'?.55:.72;exp*=.92;}
 if(w==='fog'){fogC.lerp(new THREE.Color(0xcfd6de),.7);fogN=4;fogF=75;sunI*=.6;}
 scene.fog=new THREE.Fog(fogC.getHex(),fogN,fogF);scene.background=fogC.clone();
 sun.color.copy(sunC);sun.intensity=sunI;hemi.intensity=hemiI;hemi.color.copy(hemiS);renderer.toneMappingExposure=exp;vmSun.color.copy(sunC);
 RAIN.base={hemi:hemiI,sun:sunI};RAIN.mesh.visible=RAIN.on;RAIN.mesh.material.opacity=w==='storm'?.5:.36;
 RAIN.thunderAt=G.t+rand(6,14);RAIN.lt=0;
 rainAudio(RAIN.on);
}
function rainAudio(on){
 if(!AC||!noiseBuf)return;
 if(on&&!RAIN.src){
  const s=AC.createBufferSource();s.buffer=noiseBuf;s.loop=true;const f=AC.createBiquadFilter();f.type='bandpass';f.frequency.value=3200;f.Q.value=.5;
  const g=AC.createGain();g.gain.value=RAIN.storm?.11:.07;s.connect(f);f.connect(g);g.connect(master);s.start();RAIN.src=s;RAIN.gain=g;
 }else if(!on&&RAIN.src){try{RAIN.src.stop();}catch(e){}RAIN.src=null;}
 else if(on&&RAIN.gain)RAIN.gain.gain.value=RAIN.storm?.11:.07;
}
function weatherUpdate(dt){
 if(!RAIN.mesh)return;
 if(!G.running||G.over){if(RAIN.src)rainAudio(false);RAIN.mesh.visible=false;return;}
 if(!RAIN.on){RAIN.mesh.visible=false;return;}
 if(!RAIN.src)rainAudio(true);
 RAIN.mesh.visible=true;
 const p=RAIN.geo.attributes.position.array,cx=camera.position.x,cy=camera.position.y,cz=camera.position.z,t=G.t,wind=RAIN.storm?.35:.12;
 for(let i=0;i<RAIN.n;i++){
  const sx=RAIN.seed[i*3],sy=RAIN.seed[i*3+1],sz=RAIN.seed[i*3+2];
  const y=((sy*28-t*(RAIN.storm?32:26)+1000)%28),x=cx+(sx-.5)*44+Math.sin(sz*9)*0,z=cz+(sz-.5)*44;
  const yy=cy-10+y+ (sx*0);
  p[i*6]=x;p[i*6+1]=yy;p[i*6+2]=z;p[i*6+3]=x-wind;p[i*6+4]=yy+.55;p[i*6+5]=z;
 }
 RAIN.geo.attributes.position.needsUpdate=true;
 if(RAIN.storm&&RAIN.base){
  if(G.t>RAIN.thunderAt){RAIN.lt=.22;RAIN.thunderAt=G.t+rand(7,16);setTimeout(()=>{if(AC&&G.running)sfx('boom',lis.x+rand(-60,60),lis.z+rand(-60,60),.5);},rand(300,1400));}
  if(RAIN.lt>0){RAIN.lt-=dt;hemi.intensity=RAIN.base.hemi+3.2*Math.max(0,RAIN.lt/.22)*(Math.random()<.6?1:.4);}
  else hemi.intensity=RAIN.base.hemi;
 }
}

/* ---------- musique dynamique (générative) ---------- */
const MUS={on:false,next:0,step:0,int:0,gain:null,tmr:null};
const SCALE=[0,3,5,7,10,12,15];            // gamme mineure pentatonique étendue
function musIntensity(dt){
 let t=.12;
 if(G.running&&!G.over&&P&&P.alive){
  if(P.target||P.lastHurtT>G.t-4)t+=.4;
  if(P.lastShot>G.t-2.5)t+=.25;
  if(G.mode==='bomb'&&BM.state==='planted')t+=.35;
  for(const e of ents)if(e!==P&&e.alive&&e.team!==P.team&&!e.dummy&&(e.spotT>G.t))t+=.1;
 }
 if(G.variant==='zombies'||G.variant==='br')t+=.15;
 MUS.int+=(clamp(t,0,1)-MUS.int)*Math.min(1,dt*.6);
}
function musNote(f,when,len,type,vol,dest){
 const o=AC.createOscillator(),g=AC.createGain();o.type=type;o.frequency.value=f;
 g.gain.setValueAtTime(0,when);g.gain.linearRampToValueAtTime(vol,when+.02);g.gain.exponentialRampToValueAtTime(.0008,when+len);
 o.connect(g);g.connect(dest);o.start(when);o.stop(when+len+.05);
}
function musTick(){
 if(!AC||!MUS.on)return;
 const bpm=108+MUS.int*28,spb=60/bpm/4;
 while(MUS.next<AC.currentTime+.35){
  const w=MUS.next,s=MUS.step%16,bar=Math.floor(MUS.step/16)%4,root=[110,98,87.3,98][bar],it=MUS.int,dst=MUS.gain;
  if(s===0)musNote(root,w,spb*15,'sine',.1,dst),musNote(root*1.5,w,spb*15,'triangle',.05,dst),musNote(root*2,w,spb*15,'sine',.035,dst);   // nappe
  if(it>.28&&s%2===0)musNote(root/2*Math.pow(2,SCALE[(s*3+bar)%4]/12),w,spb*1.7,'sawtooth',.045*Math.min(1,it*1.5),dst);                  // basse
  if(it>.35&&s%4===2){const nb=AC.createBufferSource();nb.buffer=noiseBuf;const hp=AC.createBiquadFilter();hp.type='highpass';hp.frequency.value=7000;const g=AC.createGain();g.gain.setValueAtTime(.025,w);g.gain.exponentialRampToValueAtTime(.0005,w+.05);nb.connect(hp);hp.connect(g);g.connect(dst);nb.start(w,Math.random(),.06);}
  if(it>.55&&(s===0||s===8||(s===10&&it>.8))){const o=AC.createOscillator(),g=AC.createGain();o.frequency.setValueAtTime(130,w);o.frequency.exponentialRampToValueAtTime(40,w+.12);g.gain.setValueAtTime(.2,w);g.gain.exponentialRampToValueAtTime(.001,w+.16);o.connect(g);g.connect(dst);o.start(w);o.stop(w+.2);}
  if(it>.75&&s%2===1)musNote(root*2*Math.pow(2,SCALE[(MUS.step*5+bar*2)%7]/12),w,spb*1.4,'square',.018,dst);                                // arpège
  MUS.next+=spb;MUS.step++;
 }
}
function musicUpdate(dt){
 const want=!!cfg.music&&AC&&G.running&&!G.over&&G.state!=='cine'&&!(typeof CINE!=='undefined'&&CINE.on);
 if(want&&!MUS.on){
  MUS.gain=AC.createGain();MUS.gain.gain.value=.55*(cfg.vol||.6);MUS.gain.connect(master);MUS.on=true;MUS.next=AC.currentTime+.1;MUS.step=0;MUS.tmr=setInterval(musTick,90);
 }else if(!want&&MUS.on){MUS.on=false;clearInterval(MUS.tmr);try{MUS.gain.gain.linearRampToValueAtTime(0,AC.currentTime+.6);}catch(e){}}
 if(MUS.on){musIntensity(dt);MUS.gain.gain.value=.55*(cfg.vol||.6);}
}

/* ---------- annonceur & radio ---------- */
let lastSpeak=0,voiceFR=null;
function announce(txt,force){return; // voix désactivées

 if(!cfg.announcer||!window.speechSynthesis||!txt)return;
 txt=String(txt).replace(/<[^>]*>/g,' ').replace(/\s+/g,' ').trim();if(!txt||txt.length>60)return;
 const now=performance.now();if(!force&&now-lastSpeak<1500)return;lastSpeak=now;
 try{
  if(!voiceFR){const v=speechSynthesis.getVoices();voiceFR=v.find(x=>/^fr/i.test(x.lang))||null;}
  const u=new SpeechSynthesisUtterance(txt.toLowerCase());u.lang='fr-FR';if(voiceFR)u.voice=voiceFR;u.rate=1.08;u.pitch=.85;u.volume=Math.min(1,(cfg.vol||.6)*1.1);
  speechSynthesis.cancel();speechSynthesis.speak(u);
 }catch(e){}
}
const MULTI=['','','Double élimination','Triple élimination','Quadruple élimination','Ace'];
let multiN=0,multiT=-9;
function immKill(att,v,w,hs){
 if(att&&att.isPlayer&&v!==att){
  if(G.t-multiT<4.5)multiN++;else multiN=1;multiT=G.t;
  if(multiN>=2)announce(MULTI[Math.min(5,multiN)],true);else if(hs&&Math.random()<.4)announce('Tir à la tête');
 }
 if(v.isPlayer&&att&&att!==v&&G.state!=='over'){G.spec=att;KC.t=2.6;KC.name=att.name;KC.w=w&&w.n||'';}
 if(cfg.gore&&!v.zombie&&!v.dummy)stain(v.x,groundH(v.x,v.z)+.03,v.z,6);
 const alive=ents.filter(e=>e.alive&&e.team===P.team&&!e.dummy&&!e.zombie).length;
 if(MODE().team&&G.mode==='bomb'&&alive===1&&P.alive&&v.team===P.team)announce('Dernier survivant');
}
const radioEl=(()=>{const d=document.createElement('div');d.style.cssText='position:fixed;left:14px;top:150px;z-index:6;pointer-events:none;font:700 12px system-ui;color:#fff;text-shadow:0 1px 3px #000;display:flex;flex-direction:column;gap:3px';document.body.appendChild(d);return d;})();
let radioT=0;
function radio(from,txt){
 const l=document.createElement('div');l.style.cssText='background:rgba(10,14,22,.65);padding:3px 8px;border-left:3px solid '+(TEAMCSS[from.team]||'#fff')+';border-radius:2px;transition:opacity .6s';
 l.innerHTML='<b>'+from.name+'</b> : '+txt;radioEl.appendChild(l);while(radioEl.children.length>3)radioEl.removeChild(radioEl.firstChild);
 setTimeout(()=>{l.style.opacity=0;setTimeout(()=>l.remove(),700);},3200);
}
function radioUpdate(dt){
 if(!G.running||!MODE().team||G.variant==='zombies')return;
 radioT-=dt;if(radioT>0)return;
 for(const e of ents){
  if(e.isPlayer||!e.alive||e.team!==P.team||e.dummy)continue;
  const has=e.target&&e.target.alive;
  if(has&&!e._seen){e._seen=true;radioT=rand(2.5,4.5);radio(e,pick(['Contact','Ennemi repéré','Ils sont là'])+' — '+(locName(e.target.x,e.target.z)||locName(e.x,e.z)||'')+'.');return;}
  if(!has)e._seen=false;
  if(e.hp<35&&!e._low&&Math.random()<.5){e._low=true;radioT=3;radio(e,'Je suis blessé !');return;}
  if(e.hp>=60)e._low=false;
 }
}
/* ---------- killcam ---------- */
const KC={t:0,name:'',w:'',el:null};
function killcamUpdate(dt){
 if(!KC.el){KC.el=document.createElement('div');KC.el.style.cssText='position:fixed;left:50%;top:18%;transform:translateX(-50%);z-index:7;pointer-events:none;font:900 15px system-ui;letter-spacing:3px;color:#fff;text-shadow:0 2px 6px #000;background:rgba(160,20,30,.55);padding:6px 18px;border-radius:3px;display:none';document.body.appendChild(KC.el);}
 if(KC.t>0&&!P.alive&&G.running){KC.t-=dt;KC.el.style.display='block';KC.el.textContent='REPLAY — '+KC.name.toUpperCase()+(KC.w?' · '+KC.w:'');if(G.spec&&G.spec.alive===false&&KC.t<2)KC.t=0;}
 else{KC.el.style.display='none';if(P.alive)KC.t=0;}
}
/* ---------- taches de sang (décalcomanies) ---------- */
function stain(x,y,z,n){
 if(!fxReady||!decals||!cfg.gore)return;
 for(let i=0;i<n;i++){
  const k=decals.dI++%decals.cap;
  decals.pos[k*3]=x+rand(-.5,.5);decals.pos[k*3+1]=y;decals.pos[k*3+2]=z+rand(-.5,.5);decals.size[k]=rand(.25,.55);
  decals.col[k*4]=.45;decals.col[k*4+1]=.04;decals.col[k*4+2]=.05;decals.col[k*4+3]=.8;
 }
 decals.geo.attributes.position.needsUpdate=true;decals.geo.attributes.color.needsUpdate=true;decals.geo.attributes.size.needsUpdate=true;
}
/* ---------- tonneaux explosifs ---------- */
const BAR={hp:{},fires:[],wreck:[]};
function barrelHit(x,y,z,att){
 const cx=Math.floor(x/S),cz=Math.floor(z/S);if(cx<0||cz<0||cx>=N||cz>=N)return;
 const i=cz*N+cx;if(G_TYPE[i]!==TY.BARREL||y>G_H[i]+.2||BAR.hp[i]===-1)return;
 if(BAR.hp[i]===undefined)BAR.hp[i]=3;BAR.hp[i]--;
 fxSpark(x,y,z,5);
 if(BAR.hp[i]>0)return;
 BAR.hp[i]=-1;
 const bx=cx*S+S/2,bz=cz*S+S/2,by=G_H[i]*.5;
 sfx('boom',bx,bz,1);fxExplosion(bx,by+.4,bz,1.25);
 if(P&&P.alive&&Math.hypot(P.x-bx,P.z-bz)<16)G.shake=Math.max(G.shake,.8*(1-Math.hypot(P.x-bx,P.z-bz)/16));
 for(const v of ents){
  if(!v.alive)continue;
  const dx=v.x-bx,dz=v.z-bz,dy=v.y+1-by,d=Math.hypot(dx,dy,dz);if(d>6.5)continue;
  if(d>1.2&&rayWall(bx,by+.8,bz,dx/d,dy/d,dz/d,d)<d-.6)continue;
  hurt(v,att,NADEW,'b',d,Math.round(150*(1-d/6.5)+15));
 }
 // épave noircie
 const m=new THREE.Mesh(new THREE.CylinderGeometry(.86,.84,G_H[i]*.96,16),new THREE.MeshStandardMaterial({color:0x151515,roughness:1,emissive:0x2a0c00,emissiveIntensity:.4}));
 m.position.set(bx,G_H[i]*.48,bz);scene.add(m);BAR.wreck.push(m);
 BAR.fires.push({x:bx,y:G_H[i],z:bz,t:11});
 stain(bx,groundH(bx,bz)+.03,bz,0);
}
function barrelUpdate(dt){
 for(let i=BAR.fires.length-1;i>=0;i--){
  const f=BAR.fires[i];f.t-=dt;
  if(fxReady&&Math.random()<dt*28){fxA.emit(f.x+rand(-.3,.3),f.y,f.z+rand(-.3,.3),rand(-.3,.3),rand(1.4,2.6),rand(-.3,.3),rand(.4,.8),.3,.05,1,.55,.1,.9,0,2);}
  if(fxReady&&Math.random()<dt*10)fxN.emit(f.x,f.y+.4,f.z,rand(-.3,.3),rand(.8,1.6),rand(-.3,.3),rand(1.2,2),.2,.9,.2,.2,.2,.35,0,1.5);
  if(f.t<=0)BAR.fires.splice(i,1);
 }
}
function barrelClear(){for(const m of BAR.wreck)scene.remove(m);BAR.wreck.length=0;BAR.fires.length=0;BAR.hp={};}
/* ---------- podium MVP ---------- */
function podiumHTML(){
 if(G.variant==='train'||G.variant==='zombies')return '';
 const l=ents.filter(e=>!e.dummy&&!e.zombie).sort((a,b)=>(b.kills-a.kills)||(b.dmg-a.dmg)).slice(0,3);if(l.length<2)return '';
 const order=l.length===3?[1,0,2]:[1,0],hts=[96,70,52];
 return '<div style="display:flex;align-items:flex-end;justify-content:center;gap:10px;margin:6px 0 12px">'+order.map(i=>{const e=l[i];if(!e)return '';const mvp=i===0;
  return '<div style="text-align:center;width:104px"><div style="font-size:'+(mvp?'1.3':'1')+'rem">'+(mvp?'👑':'')+'</div><div style="font-weight:800;font-size:.76rem;color:'+(e.isPlayer?'#ffd23a':'#fff')+'">'+e.name+'</div><div style="font-size:.66rem;color:var(--dim)">'+e.kills+' / '+e.deaths+' · '+Math.round(e.dmg)+' dgts</div><div style="height:'+hts[i]+'px;margin-top:5px;border-radius:4px 4px 0 0;background:linear-gradient(180deg,'+(mvp?'#ffd23a':i===1?'#c5ced9':'#b07a4a')+',#1a2438);display:flex;align-items:flex-start;justify-content:center;font-weight:900;font-size:1.3rem;color:#0b1018;padding-top:4px">'+(i+1)+'</div></div>';}).join('')+'</div>'+(l[0]?'<div style="text-align:center;font-size:.7rem;letter-spacing:3px;color:#ffd23a;margin-bottom:8px">MVP — '+l[0].name.toUpperCase()+'</div>':'');
}
/* ---------- boucle ---------- */
function immersionUpdate(dt){
 if(!P){musicUpdate(dt);return;}
 weatherUpdate(dt);musicUpdate(dt);radioUpdate(dt);killcamUpdate(dt);barrelUpdate(dt);
}
/* ---------- réglages d'ambiance (onglet Style) ---------- */
function ambianceSections(sec){
 sec('Météo (prochaine partie)',WEATHERS,it=>cfg.weather===it.id,it=>cfg.weather=it.id,it=>it.n);
 sec('Heure de la journée',TODS,it=>cfg.tod===it.id,it=>cfg.tod=it.id,it=>it.n);
 sec('Musique dynamique',[{id:1,n:'Activée'},{id:0,n:'Coupée'}],it=>cfg.music===it.id,it=>cfg.music=it.id,it=>it.n);
 sec('Effets de sang',[{id:1,n:'Activés'},{id:0,n:'Désactivés (version familiale)'}],it=>cfg.gore===it.id,it=>cfg.gore=it.id,it=>it.n);
}
