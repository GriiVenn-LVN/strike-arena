/* =====================================================================
   FINITIONS : confettis & récompenses animées, ouverture de caisse plus
   spectaculaire, thème/événement en cours bien visible, interface plus
   propre (panneaux vitrés, survols, animations)
   ===================================================================== */
/* ---------- confettis ---------- */
let cfCv=null,cfP=[],cfRun=false;
function confetti(colors,n,ox,oy){
 if(!cfCv){cfCv=document.createElement('canvas');cfCv.style.cssText='position:fixed;inset:0;width:100%;height:100%;pointer-events:none;z-index:70';document.body.appendChild(cfCv);}
 cfCv.width=innerWidth;cfCv.height=innerHeight;
 colors=colors||['#ff4655','#ffd75e','#4aa3ff','#7dff9f','#c77dff','#ffffff'];
 const x0=(ox===undefined?.5:ox)*innerWidth,y0=(oy===undefined?.42:oy)*innerHeight;
 for(let i=0;i<(n||160);i++){const a=rand(0,TAU),s=rand(4,15);cfP.push({x:x0,y:y0,vx:Math.cos(a)*s,vy:Math.sin(a)*s-rand(4,9),r:rand(0,TAU),vr:rand(-.3,.3),w:rand(6,12),h:rand(3,7),c:pick(colors),life:rand(1.6,2.8)});}
 if(!cfRun){cfRun=true;let last=performance.now();const f=()=>{const now=performance.now(),dt=Math.min(.05,(now-last)/1000);last=now;const c=cfCv.getContext('2d');c.clearRect(0,0,cfCv.width,cfCv.height);
  for(let i=cfP.length-1;i>=0;i--){const p=cfP[i];p.life-=dt;if(p.life<=0){cfP.splice(i,1);continue;}p.vy+=22*dt;p.vx*=.985;p.x+=p.vx*dt*60;p.y+=p.vy*dt*60;p.r+=p.vr;
   c.save();c.translate(p.x,p.y);c.rotate(p.r);c.globalAlpha=Math.min(1,p.life*1.5);c.fillStyle=p.c;c.fillRect(-p.w/2,-p.h/2,p.w,Math.abs(Math.cos(p.r*2))*p.h+1);c.restore();}
  if(cfP.length)requestAnimationFrame(f);else{cfRun=false;c.clearRect(0,0,cfCv.width,cfCv.height);}};requestAnimationFrame(f);}
}
/* ---------- compteurs qui défilent ---------- */
function countUp(el,to,dur,prefix,suffix){
 const t0=performance.now();prefix=prefix||'';suffix=suffix||'';
 const f=()=>{const k=Math.min(1,(performance.now()-t0)/(dur||1200)),e=1-Math.pow(1-k,3);el.textContent=prefix+Math.round(to*e).toLocaleString('fr-FR')+suffix;if(k<1)requestAnimationFrame(f);};f();
}
/* écran de fin : titre qui claque, XP / pièces qui défilent, confettis si victoire */
function juiceRewards(win){
 const t=$('oT');t.classList.remove('jpop');void t.offsetWidth;t.classList.add('jpop');
 document.querySelectorAll('#oRew .rewbox b').forEach(b=>{const m=b.textContent.match(/^\+(\d+)\s*(.*)$/);if(m){countUp(b,+m[1],1400,'+',' '+m[2]);}});
 if(win){setTimeout(()=>confetti(null,220,.5,.25),250);sfx('win');}
}
/* ---------- thème / événement en cours ---------- */
function themeRibbon(){
 const sub=$('msub');if(!sub)return;
 let r=$('evRibbon');
 if(navGroup!=='play'){if(r)r.remove();return;}
 const hint=sub.querySelector('.hint');if(hint)hint.style.display='none';
 if(!r){r=document.createElement('div');r.id='evRibbon';sub.appendChild(r);}
 let h='';
 if(typeof eventActive==='function'&&eventActive()){
  const pk=PROF.ev&&PROF.ev.id===EVENT.id?PROF.ev.pk:0,days=Math.max(0,Math.ceil((new Date(EVENT.to+'T23:59:59')-new Date())/864e5));
  const next=EVENT.goals.find(g=>pk<g.n);
  h+='<div class="evp hw" data-go="career">🎃 <b>'+EVENT.n.toUpperCase()+'</b><span>Citrouilles '+pk+(next?' / '+next.n:'')+' · encore '+days+' j</span></div>';
 }
 if(typeof SEASON!=='undefined'){ensureBP();h+='<div class="evp ss" data-go="career">★ <b>'+SEASON.n.toUpperCase()+'</b><span>Palier '+bpTier()+' / '+SEASON.tiers+'</span><i style="--p:'+Math.round((PROF.bp.xp%SEASON.xpPer)/SEASON.xpPer*100)+'%"></i></div>';}
 if(dailyStatus().can)h+='<div class="evp dl" data-go="daily">🎁 <b>RÉCOMPENSE DU JOUR</b><span>à récupérer !</span></div>';
 r.innerHTML=h;
 r.querySelectorAll('.evp').forEach(p=>p.onclick=()=>{sfxUI();if(p.dataset.go==='daily')showDaily();else navGo('career');});
 const menu=$('menu');menu.classList.toggle('theme-hw',typeof eventActive==='function'&&eventActive());
}
/* badge d'événement en jeu */
let evHud=null;
function eventHudUpdate(){
 if(typeof eventActive!=='function'||!eventActive()||!G.running||typeof PUMPK==='undefined'){if(evHud)evHud.style.display='none';return;}
 if(!evHud){evHud=document.createElement('div');evHud.id='evHud';$('hud').appendChild(evHud);}
 evHud.style.display=PUMPK.length?'block':'none';evHud.textContent='🎃 '+PUMPK.length+' citrouille'+(PUMPK.length>1?'s':'')+' cachée'+(PUMPK.length>1?'s':'')+' sur la carte';
}
/* ---------- styles ---------- */
(function juiceCss(){
 const s=document.createElement('style');s.textContent=`
/* panneaux en verre dépoli */
#top>div,.vital,#wpanel,#slots div,#feed div,#sb,.panel,#profile,.csec,.mcard,.card2,.boxcard{backdrop-filter:blur(8px) saturate(1.2);-webkit-backdrop-filter:blur(8px) saturate(1.2)}
#top>div{background:linear-gradient(180deg,rgba(18,24,38,.88),rgba(9,13,21,.82));border-radius:3px;box-shadow:0 6px 20px #0006}
.vital,#wpanel{background:linear-gradient(90deg,rgba(14,19,30,.9),rgba(14,19,30,.6));border-radius:3px;box-shadow:0 6px 20px #0005;border-left:3px solid #ffffff22}
#wpanel{border-left:none;border-bottom:3px solid var(--accent)}
#ammo{text-shadow:0 0 18px #ffffff30}
#banner{text-shadow:0 0 30px #000,0 0 60px rgba(255,70,85,.35)}
.panel{border-radius:6px;border-color:#33415e;box-shadow:0 30px 80px #000c,inset 0 1px 0 #ffffff10}
.btn{border-radius:2px;background:linear-gradient(180deg,#ff5a68,#e53a4a);box-shadow:0 8px 24px -8px #ff4655aa}
.btn:hover{background:linear-gradient(180deg,#ff7380,#ff4655)}
.btn::after{content:"";position:absolute;inset:0;background:linear-gradient(110deg,transparent 30%,#ffffff40 50%,transparent 70%);transform:translateX(-120%);transition:transform .6s}
.btn:hover::after{transform:translateX(120%)}
#playBtn{animation:playglow 2.4s infinite}
@keyframes playglow{50%{box-shadow:0 0 34px -4px #ff4655}}
.mcard,.chip,.nv,.sp,.dc{transition:all .18s cubic-bezier(.2,.8,.3,1)}
.mcard:hover{box-shadow:0 0 0 1px var(--c),0 10px 26px -12px var(--c)}
.chip.on{box-shadow:0 0 18px -4px var(--accent),inset 0 1px 0 #ffffff40}
.tp.on{animation:tpin .35s cubic-bezier(.2,.8,.3,1)}
/* menu : fond animé + thème d'événement */
#menu::before{content:"";position:absolute;inset:0;pointer-events:none;background:radial-gradient(ellipse at 15% 110%,#ff465522,transparent 55%),radial-gradient(ellipse at 90% -10%,#4aa3ff1c,transparent 50%);animation:bgmove 14s ease-in-out infinite alternate}
@keyframes bgmove{to{transform:translate(2%,-2%) scale(1.05)}}
#menu.theme-hw::before{background:radial-gradient(ellipse at 10% 110%,#ff7a1a33,transparent 55%),radial-gradient(ellipse at 95% -10%,#8a3dff30,transparent 50%)}
#menu.theme-hw .logo{border-left-color:#ff7a1a}
#menu.theme-hw .logo h1 span{color:#ff8a2a;text-shadow:0 0 22px #ff7a1a88}
#menu .wrap{position:relative}
/* rubans d'événement */
#evRibbon{display:flex;gap:8px;margin-left:auto;flex-wrap:wrap}
#msub{flex-wrap:wrap;row-gap:6px}
.evp b,.evp span{white-space:nowrap}
@media(max-width:1100px){.evp span{display:none}}
.evp{display:flex;align-items:center;gap:8px;padding:6px 14px 6px 10px;border-radius:20px;cursor:pointer;font-size:.72rem;position:relative;overflow:hidden;border:1px solid;transition:.15s}
.evp:hover{transform:translateY(-2px)}
.evp b{letter-spacing:2px;font-size:.68rem}.evp span{color:#ffffffb0;font-size:.66rem}
.evp.hw{background:linear-gradient(90deg,#3a1a06,#26122f);border-color:#ff7a1a88;color:#ffb36a;box-shadow:0 0 18px -6px #ff7a1a;animation:evglow 2s infinite}
@keyframes evglow{50%{box-shadow:0 0 26px -2px #ff7a1a}}
.evp.ss{background:#141c2c;border-color:#ffd75e66;color:#ffd75e}
.evp.ss i{position:absolute;left:0;bottom:0;height:2px;width:var(--p);background:#ffd75e}
.evp.dl{background:linear-gradient(90deg,#ff4655,#ff8a3a);border-color:transparent;color:#fff;animation:glowp 1.4s infinite}
#evHud{position:absolute;top:4.4rem;right:.8rem;font-size:.72rem;font-weight:800;letter-spacing:1px;color:#ffb36a;background:linear-gradient(90deg,#3a1a06cc,#26122fcc);border:1px solid #ff7a1a66;padding:4px 10px;border-radius:12px;display:none}
/* récompenses */
#oT.jpop{animation:jpop .7s cubic-bezier(.2,1.8,.4,1)}
@keyframes jpop{0%{transform:scale(2.2);opacity:0;letter-spacing:30px}100%{transform:none;opacity:1}}
#lvlup .panel{animation:lvpop .6s cubic-bezier(.2,1.6,.4,1);background:radial-gradient(ellipse at 50% 0%,#5a3a10,#121a2a 70%)}
#lvlup h1{font-size:3.4rem!important;text-shadow:0 0 30px #ffd75e88}
#lvN{display:inline-block;color:#ffd75e;animation:lvnum 1s ease-out}
@keyframes lvpop{from{transform:scale(.6);opacity:0}}
@keyframes lvnum{0%{transform:scale(3) rotate(-20deg);opacity:0}60%{transform:scale(.9)}100%{transform:none}}
.dday.today{animation:tdy 1.4s infinite,dbounce 2.2s infinite}
@keyframes dbounce{0%,100%{transform:scale(1.07)}50%{transform:scale(1.12) translateY(-4px)}}
/* caisse */
#boxFlash{position:fixed;inset:0;background:#fff;opacity:0;pointer-events:none;z-index:41;transition:opacity .5s}
#boxTxt .rar{font-size:1rem;letter-spacing:10px;animation:rarin .5s cubic-bezier(.2,1.6,.4,1)}
#boxTxt h2{font-size:2.4rem;text-shadow:0 0 30px currentColor}
@keyframes rarin{from{transform:scale(2.4);opacity:0;letter-spacing:30px}}
.rarq3 #boxTxt h2{animation:legend 1.2s ease-in-out infinite alternate}
@keyframes legend{to{text-shadow:0 0 50px currentColor,0 0 90px currentColor}}
`;document.head.appendChild(s);
 const fl=document.createElement('div');fl.id='boxFlash';document.body.appendChild(fl);
})();
function boxFlash(col,strength){const f=$('boxFlash');f.style.transition='none';f.style.background=col||'#fff';f.style.opacity=strength||.85;void f.offsetWidth;f.style.transition='opacity .7s';f.style.opacity=0;}
/* rafraîchissement régulier des rubans (menu) et du badge d'événement (jeu) */
setInterval(()=>{try{if(!G.running)themeRibbon();eventHudUpdate();}catch(e){}},1000);
