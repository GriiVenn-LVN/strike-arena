/* =====================================================================
   PRÉSENTATION DES SKINS (armurerie)
   Quand on équipe un skin : l'arme tourne vite puis se pose avec un
   rebond, un éclair de la couleur de la rareté traverse l'aperçu et un
   bandeau « RARETÉ — nom du skin » glisse sous l'arme. Plus la rareté
   est haute, plus l'effet est appuyé (paillettes pour Légendaire et
   Exclusif).
   ===================================================================== */
(function(){
 const st=document.createElement('style');st.textContent=`
 .prev{position:relative;overflow:hidden}
 .scFlash{position:absolute;inset:0;pointer-events:none;opacity:0;mix-blend-mode:screen}
 .scFlash.go{animation:scFl .9s ease-out}
 @keyframes scFl{0%{opacity:0}12%{opacity:1}100%{opacity:0}}
 .scShine{position:absolute;top:-20%;bottom:-20%;width:28%;left:-40%;pointer-events:none;transform:skewX(-18deg);background:linear-gradient(90deg,transparent,rgba(255,255,255,.55),transparent);opacity:0}
 .scShine.go{animation:scSh .85s cubic-bezier(.3,.6,.3,1) .12s}
 @keyframes scSh{0%{left:-40%;opacity:1}100%{left:120%;opacity:0}}
 .scTag{position:absolute;left:50%;bottom:14px;transform:translate(-50%,30px);padding:6px 18px;font:800 .78rem/1 inherit;letter-spacing:3px;color:#fff;pointer-events:none;opacity:0;white-space:nowrap;
  background:linear-gradient(90deg,transparent,rgba(10,14,24,.85) 18%,rgba(10,14,24,.85) 82%,transparent);border-top:1px solid;border-bottom:1px solid}
 .scTag.go{animation:scTg 2.4s cubic-bezier(.2,.9,.3,1.2)}
 @keyframes scTg{0%{opacity:0;transform:translate(-50%,30px)}14%{opacity:1;transform:translate(-50%,0)}80%{opacity:1;transform:translate(-50%,0)}100%{opacity:0;transform:translate(-50%,-6px)}}
 .scSpark{position:absolute;width:6px;height:6px;border-radius:50%;pointer-events:none;animation:scSp 1.1s ease-out forwards}
 @keyframes scSp{0%{opacity:1;transform:translate(0,0) scale(1)}100%{opacity:0;transform:translate(var(--dx),var(--dy)) scale(.2)}}
 #skins>div{transition:transform .15s,box-shadow .15s}
 #skins>div:hover{transform:translateX(3px)}
 #skins>div.on{box-shadow:inset 0 0 0 1px rgba(255,255,255,.35),0 0 14px rgba(255,255,255,.08)}
 #skins>div i{transition:transform .2s}
 #skins>div:hover i{transform:scale(1.15) rotate(-4deg)}`;
 document.head.appendChild(st);
})();
const SC={t:-1,base:1,q:0,spin:0,light:null};
function scReveal(k,i){
 const s=SKINS[i];if(!s||s.def||!pvPivot)return;
 const box=$('pv')&&$('pv').parentNode;if(!box)return;
 const q=s.q||0,col=rcol(q);
 SC.t=0;SC.base=pvPivot.scale.x;SC.q=q;SC.spin=0;
 if(!SC.light&&pvS){SC.light=new THREE.PointLight(0xffffff,0,6,2);pvS.add(SC.light);}
 if(SC.light)SC.light.color.set(col);
 const mk=(c)=>{let e=box.querySelector('.'+c);if(!e){e=document.createElement('div');e.className=c;box.appendChild(e);}e.classList.remove('go');void e.offsetWidth;e.classList.add('go');return e;};
 const fl=mk('scFlash');fl.style.background='radial-gradient(ellipse at 50% 50%,'+col+'88,transparent 65%)';
 mk('scShine');
 const tg=mk('scTag');tg.style.borderColor=col;tg.innerHTML='<span style="color:'+col+'">'+RARITY[q].n.toUpperCase()+'</span> — '+s.n.toUpperCase();
 if(q>=3){for(let n=0;n<26;n++){const p=document.createElement('div');p.className='scSpark';const a=Math.random()*TAU,d=60+Math.random()*140;
   p.style.cssText+='left:'+(50+Math.cos(a)*6)+'%;top:'+(48+Math.sin(a)*6)+'%;background:'+(n%3?col:'#fff')+';box-shadow:0 0 8px '+col+';--dx:'+Math.cos(a)*d+'px;--dy:'+Math.sin(a)*d*.6+'px;animation-delay:'+(Math.random()*.15)+'s';
   box.appendChild(p);setTimeout(()=>p.remove(),1400);}}
 sfx(q>=3?'powerup':q>=2?'pickup':'ui',undefined,undefined,.45);
}
// animation : appelée à chaque image tant que l'aperçu est visible
function scTick(dt){
 if(SC.t<0||!pvPivot)return;SC.t+=dt;const t=SC.t,D=1.1;
 if(t>=D){SC.t=-1;pvPivot.scale.setScalar(SC.base);if(SC.light)SC.light.intensity=0;return;}
 const a=t/D,el=1-Math.pow(2,-9*a)*Math.cos(a*14);         // rebond élastique
 pvPivot.scale.setScalar(SC.base*(.62+.38*el));
 const sp=(1-a)*(1-a)*(9+SC.q*3)*dt;pvPivot.rotation.y+=sp;
 if(SC.light){SC.light.intensity=Math.sin(Math.min(1,a*1.4)*Math.PI)*(1.5+SC.q*.9);SC.light.position.set(Math.cos(t*6)*1.4,.6,Math.sin(t*6)*1.4+.6);}
}
{const _ds=drawSkins;
 drawSkins=function(){_ds();
  const sk=$('skins');if(!sk)return;
  [...sk.children].forEach((d,i)=>{const o=d.onclick;if(!o)return;d.onclick=e=>{const before=cfg.skins[pvKey]||0;o(e);const now=cfg.skins[pvKey]||0;if(now!==before)scReveal(pvKey,now);};});
 };}
(function scLoop(){let last=performance.now();const f=now=>{requestAnimationFrame(f);const dt=Math.min(.05,(now-last)/1000);last=now;if(!G.running)scTick(dt);};requestAnimationFrame(f);})();
