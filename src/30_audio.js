/* =====================================================================
   AUDIO : synthèse procédurale, spatialisation, réverbération
   ===================================================================== */
let AC=null,noiseBuf=null,master=null,comp=null,reverb=null,revSend=null,lpf=null,windG=null;
const lis={x:0,z:0,yaw:0};
function initAudio(){
 if(AC){if(AC.state==='suspended')AC.resume();return;}
 try{
  AC=new (window.AudioContext||window.webkitAudioContext)();
  master=AC.createGain();master.gain.value=cfg.vol;
  comp=AC.createDynamicsCompressor();comp.threshold.value=-14;comp.ratio.value=6;comp.attack.value=.003;comp.release.value=.2;
  lpf=AC.createBiquadFilter();lpf.type='lowpass';lpf.frequency.value=20000;
  master.connect(lpf);lpf.connect(comp);comp.connect(AC.destination);
  noiseBuf=AC.createBuffer(1,AC.sampleRate*2,AC.sampleRate);
  const d=noiseBuf.getChannelData(0);for(let i=0;i<d.length;i++)d[i]=Math.random()*2-1;
  // réverbération (impulsion bruitée à décroissance exponentielle)
  reverb=AC.createConvolver();
  const len=AC.sampleRate*1.6,ib=AC.createBuffer(2,len,AC.sampleRate);
  for(let c=0;c<2;c++){const ch=ib.getChannelData(c);for(let i=0;i<len;i++)ch[i]=(Math.random()*2-1)*Math.pow(1-i/len,2.8)*(i<AC.sampleRate*.02?.3:1);}
  reverb.buffer=ib;revSend=AC.createGain();revSend.gain.value=.55;reverb.connect(revSend);revSend.connect(master);
  // vent ambiant
  const ws=AC.createBufferSource();ws.buffer=noiseBuf;ws.loop=true;
  const wf=AC.createBiquadFilter();wf.type='bandpass';wf.frequency.value=380;wf.Q.value=.6;
  windG=AC.createGain();windG.gain.value=.05;ws.connect(wf);wf.connect(windG);windG.connect(master);ws.start();
 }catch(e){AC=null;}
}
function setVolume(v){if(master)master.gain.value=v;}
function panOf(x,z){
 const dx=x-lis.x,dz=z-lis.z,d=Math.hypot(dx,dz);
 return {d,pan:d>.5?clamp((Math.cos(lis.yaw)*dx-Math.sin(lis.yaw)*dz)/d,-1,1):0};
}
function out(vol,pan,wet){
 const g=AC.createGain();g.gain.value=vol;let last=g;
 if(AC.createStereoPanner&&pan){const p=AC.createStereoPanner();p.pan.value=pan;g.connect(p);last=p;}
 last.connect(master);
 if(wet>0.01&&reverb){const w=AC.createGain();w.gain.value=wet;last.connect(w);w.connect(reverb);}
 return g;
}
function nz(dur,freq,type,vol,pan,wet,q,delay,attack){
 const t=AC.currentTime+(delay||0),src=AC.createBufferSource();src.buffer=noiseBuf;
 const f=AC.createBiquadFilter();f.type=type||'lowpass';f.frequency.value=freq;f.Q.value=q||1;
 const g=out(0,pan,wet);g.gain.setValueAtTime(.0001,t);g.gain.linearRampToValueAtTime(vol,t+(attack||.002));g.gain.exponentialRampToValueAtTime(.0005,t+dur);
 src.connect(f);f.connect(g);src.start(t,Math.random()*1.5);src.stop(t+dur+.05);
}
function tn(freq,dur,type,vol,pan,end,wet,delay){
 const t=AC.currentTime+(delay||0),o=AC.createOscillator();o.type=type||'sine';o.frequency.setValueAtTime(freq,t);
 if(end)o.frequency.exponentialRampToValueAtTime(Math.max(20,end),t+dur);
 const g=out(0,pan,wet||0);g.gain.setValueAtTime(vol,t);g.gain.exponentialRampToValueAtTime(.0005,t+dur);
 o.connect(g);o.start(t);o.stop(t+dur+.05);
}
function tinnitus(sec){
 if(!AC)return;const t=AC.currentTime;
 lpf.frequency.cancelScheduledValues(t);lpf.frequency.setValueAtTime(700,t);lpf.frequency.exponentialRampToValueAtTime(20000,t+sec);
 const o=AC.createOscillator();o.type='sine';o.frequency.value=4200;const g=AC.createGain();g.gain.setValueAtTime(.12,t);g.gain.exponentialRampToValueAtTime(.0005,t+sec);o.connect(g);g.connect(master);o.start(t);o.stop(t+sec+.1);
}
const SURF={snow:[520,'lowpass',.42],sand:[650,'lowpass',.5],stone:[1500,'bandpass',.45],metal:[2400,'bandpass',.5]};
// coup de feu en couches : claquement supersonique, corps, grave, mécanique, écho
function gunShot(vol,pan,wet,dull,o){
 const indoor=MAP&&(MAP.theme==='metro'||MAP.id==='labo');
 nz(.035,7500,'highpass',o.crack*vol,pan,wet*.5,.7);
 nz(o.len,o.body*dull,'bandpass',o.bodyV*vol,pan,wet,.75);
 tn(o.thump,o.len*1.1,'sine',o.thumpV*vol,pan,o.thump*.38,wet);
 if(o.mech)nz(.025,3200,'bandpass',o.mech*vol,pan,0,3,.045);
 nz(o.tail*(indoor?.6:1),(indoor?900:520)*dull,'lowpass',o.tailV*vol*(indoor?1.3:1),pan,Math.min(1,wet*2+.25),.8,.03,.02);
}
function sfx(type,x,z,vol,extra){
 if(!AC)return;subtitle(type,x,z);vol=vol===undefined?1:vol;let pan=0,wet=0,d=0;
 if(x!==undefined){
  const p=panOf(x,z);d=p.d;pan=p.pan;
  vol*=Math.pow(clamp(1-d/85,0,1),1.5);if(vol<.01)return;
  wet=clamp(d/50,.05,.55);
 }
 const dull=d>30?clamp(1-(d-30)/70,.4,1):1;  // sons lointains plus sourds
 switch(type){
  case 'pistol':gunShot(vol,pan,wet,dull,{crack:.55,body:2400,bodyV:.7,thump:150,thumpV:.35,len:.09,tail:.45,tailV:.25,mech:.07});break;
  case 'smg':gunShot(vol,pan,wet,dull,{crack:.45,body:2600,bodyV:.55,thump:140,thumpV:.25,len:.07,tail:.35,tailV:.18,mech:.05});break;
  case 'rifle':gunShot(vol,pan,wet,dull,{crack:.7,body:1700,bodyV:.9,thump:95,thumpV:.55,len:.13,tail:.75,tailV:.32,mech:.06});break;
  case 'lmg':gunShot(vol,pan,wet,dull,{crack:.65,body:1450,bodyV:1,thump:80,thumpV:.65,len:.15,tail:.8,tailV:.35,mech:.05});break;
  case 'sniper':gunShot(vol,pan,wet,dull,{crack:1,body:1100,bodyV:1.2,thump:60,thumpV:.9,len:.4,tail:1.4,tailV:.5,mech:0});break;
  case 'shotgun':gunShot(vol,pan,wet,dull,{crack:.6,body:950,bodyV:1.15,thump:62,thumpV:.85,len:.28,tail:1.1,tailV:.45,mech:0});break;
  case 'knife':nz(.12,4000,'highpass',.3*vol,pan,wet);tn(900,.1,'sine',.06*vol,pan,300);break;
  case 'knifehit':nz(.08,2400,'bandpass',.6*vol,pan,wet);tn(200,.08,'square',.2*vol,pan,80);break;
  case 'hit':tn(1700,.05,'square',.16*vol,0);tn(2300,.04,'sine',.1*vol,0,null,0,.02);break;
  case 'hs':tn(2400,.06,'square',.22*vol,0);tn(1800,.08,'square',.2*vol,0,null,0,.05);nz(.05,3000,'highpass',.3*vol,0);break;
  case 'kill':tn(880,.12,'triangle',.3*vol,0);tn(1320,.2,'triangle',.3*vol,0,null,0,.09);break;
  case 'dmg':tn(120,.18,'sawtooth',.28*vol,0,55);nz(.15,400,'lowpass',.3*vol,0);break;
  case 'shield':tn(1200,.18,'sine',.25*vol,0,500);tn(1800,.12,'triangle',.12*vol,0,900);break;
  case 'shieldbreak':tn(900,.3,'sawtooth',.25*vol,0,100);nz(.25,3000,'bandpass',.3*vol,0);break;
  case 'reload':nz(.04,2200,'bandpass',.45*vol,pan,wet*.5,2);nz(.05,1800,'bandpass',.5*vol,pan,wet*.5,2,.42);nz(.03,4000,'highpass',.4*vol,pan,wet*.4,1,.85);break;
  case 'bolt':nz(.05,2800,'bandpass',.5*vol,pan,wet*.5,3);nz(.05,2000,'bandpass',.55*vol,pan,wet*.5,3,.14);break;
  case 'pump':nz(.06,1500,'bandpass',.6*vol,pan,wet*.6,2);nz(.07,1100,'bandpass',.65*vol,pan,wet*.6,2,.13);break;
  case 'draw':nz(.07,3000,'highpass',.25*vol,pan,wet*.3);tn(1500,.04,'sine',.05*vol,pan);break;
  case 'click':nz(.03,4200,'highpass',.3*vol,pan,wet*.3);break;
  case 'shell':tn(4200+Math.random()*900,.05,'sine',.07*vol,pan,2600,wet);break;
  case 'step':{const s=SURF[extra||'sand'];nz(.07,s[0],s[1],s[2]*vol,pan,wet*.5,1.5);if(extra==='metal')tn(300,.08,'square',.05*vol,pan,150);break;}
  case 'jump':nz(.06,700,'lowpass',.3*vol,pan,wet*.4);break;
  case 'land':nz(.1,400,'lowpass',.5*vol,pan,wet*.5);tn(80,.1,'sine',.3*vol,pan,40);break;
  case 'beep':tn(1100,.09,'square',.3*vol,pan,null,wet);break;
  case 'plant':tn(700,.12,'square',.3*vol,pan,null,wet);tn(1000,.15,'square',.3*vol,pan,null,wet,.13);break;
  case 'defused':tn(600,.12,'triangle',.4*vol,0);tn(900,.12,'triangle',.4*vol,0,null,0,.12);tn(1200,.3,'triangle',.4*vol,0,null,0,.24);break;
  case 'boom':nz(1.8,300*dull,'lowpass',2.2*vol,pan,wet*1.3);tn(48,1.3,'sine',1.1*vol,pan,18,wet);nz(.3,5000,'highpass',.8*vol,pan,wet);break;
  case 'bang':nz(.4,5200,'highpass',1.2*vol,pan,wet);tn(3200,.4,'sine',.2*vol,pan,1200);break;
  case 'pop':nz(.12,900,'bandpass',.5*vol,pan,wet,1.5);tn(220,.12,'sine',.3*vol,pan,90);break;
  case 'smoke':nz(.9,1800,'bandpass',.35*vol,pan,wet,.7);break;
  case 'throw':nz(.12,1400,'bandpass',.25*vol,pan,wet*.3);break;
  case 'growl':nz(.7,380,'bandpass',.5*vol,pan,wet,3);tn(rand(70,95),.6,'sawtooth',.18*vol,pan,rand(50,60),wet);break;
  case 'zap':tn(1600,.22,'square',.25*vol,pan,220,wet);tn(800,.3,'sawtooth',.15*vol,pan,120,wet,.02);nz(.15,3000,'bandpass',.3*vol,pan,wet);break;
  case 'thunder':nz(1.2,600,'lowpass',1.4*vol,pan,wet*1.5);tn(45,.9,'sine',.9*vol,pan,25,wet);nz(.4,2500,'bandpass',.6*vol,pan,wet,.6,.05);break;
  case 'ice':nz(.5,6000,'highpass',.5*vol,pan,wet);tn(2400,.3,'sine',.12*vol,pan,3200,wet);tn(1800,.4,'triangle',.1*vol,pan,900,wet,.08);break;
  case 'jingle':[523,659,784,1047,784,880,1047,1319].forEach((f,i)=>tn(f,.22,'triangle',.22*vol,pan,null,wet,i*.24));break;
  case 'perk':nz(.12,1800,'bandpass',.4,0);tn(300,.25,'sine',.25,0,180,0,.15);[659,784,988].forEach((f,i)=>tn(f,.2,'square',.12,0,null,0,.35+i*.12));break;
  case 'powerup':[880,1175,1568].forEach((f,i)=>tn(f,.3,'triangle',.25*vol,pan,null,wet,i*.09));break;
  case 'pap':nz(1.2,500,'lowpass',.6,pan,wet);[392,523,659,784,1047].forEach((f,i)=>tn(f,.35,'sawtooth',.12,pan,null,wet,.3+i*.15));break;
  case 'teddy':[784,659,523,392].forEach((f,i)=>tn(f,.3,'triangle',.25*vol,pan,null,wet,i*.2));break;
  case 'pickup':tn(700,.07,'triangle',.25*vol,0);tn(1000,.1,'triangle',.25*vol,0,null,0,.06);break;
  case 'buy':tn(900,.06,'square',.18*vol,0);tn(1300,.05,'square',.14*vol,0,null,0,.05);break;
  case 'deny':tn(180,.14,'sawtooth',.25*vol,0,120);break;
  case 'win':tn(523,.18,'triangle',.4,0);tn(659,.18,'triangle',.4,0,null,0,.16);tn(784,.4,'triangle',.4,0,null,0,.32);tn(1047,.5,'triangle',.3,0,null,0,.5);break;
  case 'lose':tn(392,.25,'triangle',.4,0);tn(311,.5,'triangle',.4,0,null,0,.22);tn(247,.7,'triangle',.3,0,null,0,.5);break;
  case 'round':tn(660,.1,'square',.2,0);tn(880,.2,'square',.2,0,null,0,.12);break;
  case 'tick':tn(1000,.05,'square',.15,0);break;
  case 'alarm':tn(880,.3,'sawtooth',.2*vol,pan,660,wet);break;
  case 'heal':tn(500,.15,'sine',.25*vol,0,900);break;
  case 'ui':tn(1200,.04,'sine',.12,0);break;
 }
}

/* hélicoptère : bruit de pales (modulation de bruit filtré + basse) */
function startHeli(){
 if(!AC)return null;
 const src=AC.createBufferSource();src.buffer=noiseBuf;src.loop=true;
 const f=AC.createBiquadFilter();f.type='lowpass';f.frequency.value=320;
 const g=AC.createGain();g.gain.value=.25;
 const lfo=AC.createOscillator();lfo.frequency.value=12;const lg=AC.createGain();lg.gain.value=.22;lfo.connect(lg);lg.connect(g.gain);
 src.connect(f);f.connect(g);g.connect(master);
 const o=AC.createOscillator();o.type='sawtooth';o.frequency.value=46;const og=AC.createGain();og.gain.value=.05;o.connect(og);og.connect(master);
 src.start();lfo.start();o.start();
 return {set(v){g.gain.value=.12+.35*v;og.gain.value=.03+.1*v;f.frequency.value=220+260*v;},stop(){try{src.stop();lfo.stop();o.stop();}catch(e){}}};
}
