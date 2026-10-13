/* =====================================================================
   INTERFACE META : profil, récompense quotidienne, défis, caisses
   (animation 3D d'ouverture), casier (danses), statistiques, touches
   ===================================================================== */

function toastBig(txt){uiToast(txt);}
/* ---------- profil ---------- */
function refreshProfile(){
 const li=levelInfo();
 setText('pLvl',li.level);setText('pName',cfg.name||'Vous');
 $('pXp').style.width=Math.round(li.cur/li.need*100)+'%';setText('pXpT',li.cur+' / '+li.need+' XP');
 setText('pCoins','🪙 '+PROF.coins);setText('pBoxes','📦 '+((PROF.boxes.std||0)+(PROF.boxes.prem||0)));
 $('dailyBtn').style.display=dailyStatus().can?'inline-block':'none';
}
function showLevelUps(ups){
 if(!ups||!ups.length)return;
 let i=0;
 const next=()=>{
  if(i>=ups.length){$('lvlup').classList.remove('show');refreshProfile();return;}
  const u=ups[i++];$('lvN').textContent=u.level;$('lvTxt').textContent='Récompense : '+rewardText(u.reward);
  $('lvlup').classList.add('show');sfx('win');confetti(['#ffd75e','#ff8a3a','#ffffff','#ff4655'],180,.5,.35);
  $('lvOk').onclick=next;
 };
 next();
}
/* ---------- récompense quotidienne ---------- */
const DAYICON=['🪙','📦','🪙','💃','🪙','🎁','👑'];
function dayText(r){return rewardText(r).split(' • ').join('<br>');}
function showDaily(){
 const st=dailyStatus();
 let h='';
 DAILY.forEach((r,i)=>{
  const cls=!st.can?(i<=st.day?'done':''):(i<st.day?'done':i===st.day?'today':'');
  h+='<div class="dday '+cls+'"><b>JOUR '+(i+1)+'</b><div class="ico">'+DAYICON[i]+'</div><span>'+dayText(r)+'</span></div>';
 });
 $('dailyGrid').innerHTML=h;
 $('dailySub').textContent=st.can?'Série en cours : '+(st.streak)+' jour'+(st.streak>1?'s':'')+' — reviens chaque jour pour de meilleures récompenses !':'Récompense déjà récupérée aujourd\'hui. Reviens demain !';
 $('dailyClaim').style.display=st.can?'':'none';
 $('daily').classList.add('show');
 $('dailyClaim').onclick=()=>{const r=claimDaily();if(!r)return;sfx('win');confetti(null,160,.5,.45);uiToast('Récompense : '+rewardText(r));refreshProfile();buildBoxesTab();showDaily();};
 $('dailyClose').onclick=()=>$('daily').classList.remove('show');
}
$('dailyBtn').onclick=()=>{initAudio();showDaily();};
/* ---------- défis du jour ---------- */
function renderMissions(){
 ensureMissions();
 $('missions').innerHTML=PROF.missions.list.map((m,i)=>{const d=missionDef(m.id);
  return '<div class="mis'+(m.done?' done':'')+'"><div>'+d.n.replace('{t}',d.t)+'</div><div class="bar"><i style="width:'+Math.round(m.p/d.t*100)+'%"></i></div><div style="display:flex;justify-content:space-between;align-items:center"><span class="rw">'+m.p+' / '+d.t+' • 🪙 '+d.coins+' • '+d.xp+' XP</span>'+(m.done&&!m.claimed?'<button data-i="'+i+'">RÉCUPÉRER</button>':m.claimed?'<span style="color:var(--good);font-size:.66rem">✔ récupéré</span>':'')+'</div></div>';}).join('');
 $('missions').querySelectorAll('button').forEach(b=>b.onclick=()=>{const r=claimMission(+b.dataset.i);if(r){sfx('pickup');showLevelUps(r.ups);renderMissions();refreshProfile();}});
}
function uiMissionDone(d){uiToast('Défi terminé : '+d.n.replace('{t}',d.t));sfx('pickup');}
/* ---------- caisses ---------- */
function oddsHtml(type){
 const b=BOXES[type],tot=b.w.reduce((s,x)=>s+x,0);
 return b.w.map((w,i)=>'<div><b style="color:'+rcol(i)+'">'+RARITY[i].n+'</b><i style="width:'+Math.max(4,w/tot*100)+'px;background:'+rcol(i)+'"></i>'+(w/tot*100).toFixed(0)+' %</div>').join('');
}
function buildBoxesTab(){
 for(const [id,t] of [['Std','std'],['Prem','prem']]){
  $('odds'+id).innerHTML=oddsHtml(t);
  const n=PROF.boxes[t]||0,b=BOXES[t];
  $('own'+id).innerHTML='En stock : <b style="color:#fff">'+n+'</b> • Prix : 🪙 '+b.price;
  const btn=$('open'+id);btn.textContent=n>0?'OUVRIR':'ACHETER & OUVRIR (🪙 '+b.price+')';btn.disabled=n<=0&&PROF.coins<b.price;btn.style.opacity=btn.disabled?.45:1;
  btn.onclick=()=>startBoxOpen(t);
 }
 $('pityTxt').innerHTML='Épique garanti dans <b>'+(10-PROF.pity.epic)+'</b> ouvertures<br>Légendaire garanti dans <b>'+(40-PROF.pity.legend)+'</b> ouvertures<br>Caisses ouvertes : <b>'+PROF.opened+'</b>';
 const pool=lootPool();let own=0;for(const it of pool)if(ownsItem(it))own++;
 $('collTxt').innerHTML='Objets débloqués : <b>'+own+' / '+pool.length+'</b><br>Danses : <b>'+PROF.inv.dances.length+' / '+DANCES.length+'</b>';
}
const BXS={r:null,s:null,c:null,t:0,run:false,type:'std',res:null,crate:null,lid:null,item:null,parts:null,partV:null,beam:null,lightP:null,seamM:null,burst:false,shown:false,rig:null,last:0};
function bxInit(){
 if(BXS.r)return;
 try{BXS.r=new THREE.WebGLRenderer({canvas:$('boxCv'),antialias:true,alpha:true});}catch(e){return;}
 BXS.r.setPixelRatio(Math.min(devicePixelRatio||1,2));BXS.r.setSize(960,560,false);BXS.r.outputEncoding=THREE.sRGBEncoding;BXS.r.toneMapping=THREE.ACESFilmicToneMapping;
 BXS.s=new THREE.Scene();BXS.c=new THREE.PerspectiveCamera(38,960/560,.1,50);BXS.c.position.set(0,1.9,6.2);BXS.c.lookAt(0,1,0);
 BXS.s.add(new THREE.HemisphereLight(0xffffff,0x334466,.9));const d=new THREE.DirectionalLight(0xffffff,2.2);d.position.set(3,6,4);BXS.s.add(d);
 BXS.lightP=new THREE.PointLight(0x4aa3ff,0,12);BXS.lightP.position.set(0,1.4,1.5);BXS.s.add(BXS.lightP);
 BXS.s.environment=makeEnv(BXS.r);
 const fl=new THREE.Mesh(new THREE.CircleGeometry(3.6,48),new THREE.MeshStandardMaterial({color:C(0x10192b),roughness:.35,metalness:.7}));fl.rotation.x=-Math.PI/2;BXS.s.add(fl);BXS.floor=fl;
 const ring=new THREE.Mesh(new THREE.RingGeometry(1.9,2.0,48),new THREE.MeshBasicMaterial({color:0xffffff,transparent:true,opacity:.3,side:THREE.DoubleSide}));ring.rotation.x=-Math.PI/2;ring.position.y=.01;BXS.s.add(ring);BXS.ring=ring;
}
function bxClear(){
 const s=BXS.s;for(const o of [BXS.crate,BXS.item,BXS.parts,BXS.beam,BXS.rays,BXS.sw])if(o)s.remove(o);BXS.crate=BXS.item=BXS.parts=BXS.beam=BXS.rays=BXS.sw=null;BXS.lid=null;BXS.rig=null;
}
function startBoxOpen(type){
 initAudio();bxInit();if(!BXS.r)return;
 const res=openBox(type);if(!res){sfx('deny');uiToast('Pas assez de pièces');return;}
 refreshProfile();buildBoxesTab();
 BXS.type=type;BXS.res=res;BXS.t=0;BXS.run=true;BXS.burst=false;BXS.shown=false;BXS.sq=-1;BXS.pulse=0;$('boxov').classList.remove('rarq0','rarq1','rarq2','rarq3');BXS.last=performance.now()/1000;
 bxClear();
 const col=new THREE.Color(BOXES[type].c);
 const g=new THREE.Group();
 const metal=new THREE.MeshStandardMaterial({color:C(0x2a3550),roughness:.4,metalness:.8}),band=new THREE.MeshStandardMaterial({color:col,roughness:.3,metalness:.6,emissive:col,emissiveIntensity:.15});
 g.add(rb(1.6,1.0,1.6,metal,0,.5,0,.08));
 for(const x of [-.55,.55])g.add(rb(.14,1.02,1.64,band,x,.5,0,.03));
 g.add(rb(1.62,.14,1.62,band,0,.1,0,.03),rb(1.62,.14,1.62,band,0,.9,0,.03));
 const lid=new THREE.Group();lid.add(rb(1.7,.32,1.7,metal,0,0,0,.08));for(const x of [-.55,.55])lid.add(rb(.14,.34,1.74,band,x,0,0,.03));
 lid.add(rb(.5,.2,.1,band,0,0,.88,.03));lid.position.set(0,1.16,0);g.add(lid);BXS.lid=lid;
 const seam=new THREE.Mesh(new THREE.BoxGeometry(1.62,.05,1.62),new THREE.MeshBasicMaterial({color:col,transparent:true,opacity:.0,toneMapped:false}));seam.position.y=1.0;g.add(seam);BXS.seamM=seam;
 g.position.y=7;BXS.s.add(g);BXS.crate=g;
 BXS.lightP.color.copy(col);BXS.lightP.intensity=0;
 BXS.ring.material.color.copy(col);
 $('boxTxt').innerHTML='<div class="rar" style="color:'+BOXES[type].c+'">OUVERTURE…</div>';$('boxAgain').style.display='none';$('boxClose').style.display='none';
 $('boxov').classList.add('show');
 sfx('throw');bxLoop();
}
function bxItemObject(){
 const res=BXS.res,it=res.item,g=new THREE.Group();
 if(it.t==='skin'){const gun=gunParts(it.w,SKINS[it.s]),bx2=new THREE.Box3().setFromObject(gun),c=bx2.getCenter(new THREE.Vector3()),sz=bx2.getSize(new THREE.Vector3());gun.position.set(-c.x,-c.y,-c.z);const pv=new THREE.Group();pv.add(gun);pv.scale.setScalar(2.6/Math.max(sz.z,sz.x,.3));pv.rotation.y=Math.PI/2;g.add(pv);}
 else if(it.t==='dance'||it.t==='outfit'){initSoldierGeos();const R=makeSoldier({kind:'ct',acc:'#ffb938',tone:SKIN_TONES[0],outfit:it.t==='outfit'?it.o:0});R.root.scale.setScalar(1.15);R.root.position.y=-.9;g.add(R.root);BXS.rig=R;BXS.danceId=it.t==='dance'?it.id:'wave';}
 else{for(let i=0;i<5;i++){const c=new THREE.Mesh(new THREE.CylinderGeometry(.5,.5,.12,24),new THREE.MeshStandardMaterial({color:C(0xffd24a),metalness:1,roughness:.25,emissive:C(0x6a4a00),emissiveIntensity:.4}));c.position.set((i%3-1)*.3,(i)*.13-.3,(i%2)*.2);c.rotation.z=.2*(i%3);g.add(c);}}
 return g;
}
function bxLoop(){
 if(!BXS.run)return;requestAnimationFrame(bxLoop);
 const now=performance.now()/1000,dt=Math.min(.05,now-BXS.last);BXS.last=now;BXS.t+=dt;const T=BXS.t,res=BXS.res,col=new THREE.Color(rcol(res.q)),boxCol=new THREE.Color(BOXES[BXS.type].c);
 const c=BXS.crate;
 if(T<1.0){const k=T/1.0,y=7*(1-k*k)+Math.sin(k*3.14)*0;c.position.y=Math.max(0,7*(1-k*k));if(k>.97&&!BXS.hit){BXS.hit=true;sfx('land');}}
 else if(T<2.8){BXS.hit=false;const k=(T-1)/1.8;c.position.y=Math.abs(Math.sin(T*(8+k*18)))*.06*k;c.rotation.z=Math.sin(T*(20+k*30))*.07*k;c.rotation.x=Math.cos(T*(17+k*25))*.05*k;
  BXS.lightP.intensity=2+k*18;BXS.seamM.material.opacity=k*.9;{const sq=Math.min(res.q,Math.floor(k*k*(res.q+1.3)));const sc=new THREE.Color(rcol(sq));if(sq!==BXS.sq){BXS.sq=sq;sfx('tick');sfx('pickup',undefined,undefined,.4+sq*.2);BXS.pulse=1;}BXS.pulse=Math.max(0,(BXS.pulse||0)-dt*3);BXS.lightP.intensity+=BXS.pulse*25;BXS.lightP.color.copy(sc);BXS.seamM.material.color.copy(sc);BXS.ring.material.color.copy(sc);}
  if(Math.random()<k*.4)sfx('tick');}
 if(T>=2.8&&!BXS.burst){
  BXS.burst=true;c.rotation.set(0,0,0);c.position.y=0;
  sfx(res.q>=2?'win':'pop');sfx('bang',undefined,undefined,.25);
  BXS.lid.userData.v=V3(rand(-1,1),5+rand(0,2),rand(-.5,.5));BXS.lid.userData.w=V3(rand(-4,4),rand(-3,3),rand(-4,4));
  // particules
  const n=160,pos=new Float32Array(n*3);BXS.partV=[];for(let i=0;i<n;i++){pos[i*3]=0;pos[i*3+1]=1.1;pos[i*3+2]=0;BXS.partV.push(V3(rand(-1,1)*3,rand(1.5,6),rand(-1,1)*3));}
  const pg=new THREE.BufferGeometry();pg.setAttribute('position',new THREE.BufferAttribute(pos,3));
  BXS.parts=new THREE.Points(pg,new THREE.PointsMaterial({color:col,size:.09,transparent:true,opacity:1,blending:THREE.AdditiveBlending,depthWrite:false}));BXS.s.add(BXS.parts);
  // faisceau
  const bm=new THREE.Mesh(new THREE.CylinderGeometry(.9,1.5,12,24,1,true),new THREE.MeshBasicMaterial({color:col,transparent:true,opacity:.35,blending:THREE.AdditiveBlending,side:THREE.DoubleSide,depthWrite:false,toneMapped:false}));bm.position.y=6;BXS.s.add(bm);BXS.beam=bm;
  // objet
  BXS.item=bxItemObject();BXS.item.position.y=1.1;BXS.item.scale.setScalar(.01);BXS.s.add(BXS.item);
  BXS.lightP.intensity=60;BXS.lightP.color.copy(col);
  boxFlash(rcol(res.q),res.q>=3?1:res.q>=2?.75:.45);$('boxov').classList.add('rarq'+res.q);
  const rays=new THREE.Group();for(let i=0;i<10;i++){const pl=new THREE.Mesh(new THREE.PlaneGeometry(.22,7),new THREE.MeshBasicMaterial({color:col,transparent:true,opacity:.18+res.q*.06,blending:THREE.AdditiveBlending,depthWrite:false,side:THREE.DoubleSide,toneMapped:false}));pl.rotation.z=i/10*Math.PI;rays.add(pl);}rays.position.set(0,2.6,-.8);BXS.s.add(rays);BXS.rays=rays;
  const sw=new THREE.Mesh(new THREE.RingGeometry(.9,1,48),new THREE.MeshBasicMaterial({color:col,transparent:true,opacity:.9,side:THREE.DoubleSide,blending:THREE.AdditiveBlending,depthWrite:false,toneMapped:false}));sw.rotation.x=-Math.PI/2;sw.position.y=.05;BXS.s.add(sw);BXS.sw=sw;
  if(res.q>=2)setTimeout(()=>confetti([rcol(res.q),'#ffffff',rcol(Math.max(0,res.q-1))],res.q>=3?260:140,.5,.4),350);
 }
 if(BXS.burst){
  const k=T-2.8,l=BXS.lid;
  l.userData.v.y-=14*dt;l.position.addScaledVector(l.userData.v,dt);l.rotation.x+=l.userData.w.x*dt;l.rotation.y+=l.userData.w.y*dt;l.rotation.z+=l.userData.w.z*dt;
  const pp=BXS.parts.geometry.attributes.position;for(let i=0;i<BXS.partV.length;i++){const v=BXS.partV[i];v.y-=7*dt;pp.setXYZ(i,pp.getX(i)+v.x*dt,pp.getY(i)+v.y*dt,pp.getZ(i)+v.z*dt);}pp.needsUpdate=true;BXS.parts.material.opacity=Math.max(0,1-k/2.2);
  BXS.lightP.intensity=Math.max(8,60*Math.exp(-k*2));BXS.seamM.material.opacity=Math.max(0,.9-k*2);
  BXS.beam.material.opacity=Math.max(.06,.4-k*.12);
  const ik=smooth01(k/.8);BXS.item.position.y=1.1+ik*1.5+Math.sin(T*2)*.05;BXS.item.scale.setScalar(.01+ik*.99);
  if(BXS.item.children[0]&&!BXS.rig)BXS.item.rotation.y=T*1.3;
  if(BXS.rig){animateSoldier(BXS.rig,{vx:0,vz:0,yaw:0,pitch:0,speed:0,onGround:true,crouch:false,alive:true,reload:0,reloadMax:0,fire:0,ready:0,alert:0,hurt:false,y:0,dance:BXS.danceId,danceT:k,seated:0},dt,T);BXS.rig.root.rotation.y=Math.PI*.15;}
  if(BXS.rays){BXS.rays.rotation.z+=dt*.4;BXS.rays.scale.setScalar(Math.min(1,k*2));}
  if(BXS.sw){const sk=Math.min(1,k/.8);BXS.sw.scale.setScalar(1+sk*6);BXS.sw.material.opacity=Math.max(0,.9-sk);}
  if(k<.35){BXS.c.position.z=6.2-Math.sin(k/.35*Math.PI)*.7;}
  BXS.ring.material.opacity=.3+.25*Math.sin(T*4);BXS.ring.scale.setScalar(1+Math.sin(T*3)*.05);
  if(k>.9&&!BXS.shown){
   BXS.shown=true;const q=res.q,it=res.item;
   $('boxTxt').innerHTML='<div class="rar" style="color:'+rcol(q)+'">'+RARITY[q].n.toUpperCase()+'</div><h2 style="color:'+rcol(q)+'">'+(it.t==='coins'?'+'+it.n+' pièces':itemName(it))+'</h2><div class="sub">'+(res.dup?'Doublon — converti en <b style="color:var(--gold)">'+res.coins+' pièces</b>':it.t==='coins'?'Pièces ajoutées à ton solde':'<b style="color:var(--good)">NOUVEAU !</b> Ajouté à ta collection')+'</div>';
   $('boxAgain').style.display='';$('boxClose').style.display='';refreshProfile();buildBoxesTab();
   $('boxAgain').textContent=((PROF.boxes[BXS.type]||0)>0)?'OUVRIR UNE AUTRE':'ACHETER UNE AUTRE (🪙 '+BOXES[BXS.type].price+')';
   $('boxAgain').onclick=()=>{if((PROF.boxes[BXS.type]||0)>0||PROF.coins>=BOXES[BXS.type].price)startBoxOpen(BXS.type);else sfx('deny');};
  }
 }
 // caméra qui respire
 BXS.c.position.x=Math.sin(T*.5)*.6;BXS.c.position.y=1.9+Math.sin(T*.4)*.12;BXS.c.lookAt(0,1.1,0);
 BXS.r.render(BXS.s,BXS.c);
}
$('boxClose').onclick=()=>{BXS.run=false;$('boxov').classList.remove('show');bxClear();refreshProfile();buildBoxesTab();drawSkins&&drawSkins();buildLocker&&buildLocker();};
/* ---------- casier : danses & tenues ---------- */
let lkSel=PROF.dance,lkOut=PROF.outfit||0,lkTab='dance',lk={r:null,s:null,c:null,R:null,t:0,outShown:-1};
function lkRig(outfit){
 if(lk.R)lk.s.remove(lk.R.root);
 initSoldierGeos();lk.R=makeSoldier({kind:'ct',acc:'#ffb938',tone:SKIN_TONES[0],outfit:outfit||0});lk.s.add(lk.R.root);lk.outShown=outfit||0;
}
function lkInit(){
 if(lk.r)return;
 try{lk.r=new THREE.WebGLRenderer({canvas:$('lkCv'),antialias:true,alpha:true});}catch(e){return;}
 lk.r.setPixelRatio(Math.min(devicePixelRatio||1,2));lk.r.setSize(520,560,false);lk.r.outputEncoding=THREE.sRGBEncoding;lk.r.toneMapping=THREE.ACESFilmicToneMapping;
 lk.s=new THREE.Scene();lk.c=new THREE.PerspectiveCamera(34,520/560,.1,30);lk.c.position.set(0,1.25,6.3);lk.c.lookAt(0,0.95,0);
 lk.s.add(new THREE.HemisphereLight(0xffffff,0x445566,1));const d=new THREE.DirectionalLight(0xffffff,2.4);d.position.set(2,4,3);lk.s.add(d);const d2=new THREE.DirectionalLight(0x88aaff,1.5);d2.position.set(-3,2,-2);lk.s.add(d2);
 lk.s.environment=makeEnv(lk.r);
 const fl=new THREE.Mesh(new THREE.CircleGeometry(1.5,40),new THREE.MeshStandardMaterial({color:C(0x1a2438),roughness:.35,metalness:.6}));fl.rotation.x=-Math.PI/2;lk.s.add(fl);
 lkRig(lkOut);
}
function buildLocker(){
 const el=$('danceList');if(!el)return;
 let seg=$('lkSeg');
 if(!seg){seg=document.createElement('div');seg.id='lkSeg';seg.className='chips';seg.style.marginBottom='10px';el.parentNode.insertBefore(seg,el);}
 seg.innerHTML='<div class="chip'+(lkTab==='dance'?' on':'')+'" data-t="dance">Danses</div><div class="chip'+(lkTab==='outfit'?' on':'')+'" data-t="outfit">Tenues</div>';
 seg.querySelectorAll('.chip').forEach(c=>c.onclick=()=>{lkTab=c.dataset.t;sfxUI();buildLocker();});
 const eq=$('danceEq');
 if(lkTab==='dance'){
  el.innerHTML=DANCES.map(d=>{const own=PROF.inv.dances.includes(d.id),c=rcol(d.q);return '<div class="dcard'+(lkSel===d.id?' on':'')+(own?'':' lock')+'" data-id="'+d.id+'" style="--c:'+c+'"><b>'+d.n+'</b><span>'+RARITY[d.q].n.toUpperCase()+'</span>'+(PROF.dance===d.id?'<em>ÉQUIPÉE</em>':own?'':'<em style="color:#ff6b6b">🔒</em>')+'</div>';}).join('');
  el.querySelectorAll('.dcard').forEach(c=>c.onclick=()=>{lkSel=c.dataset.id;lk.t=0;sfxUI();buildLocker();});
  const own=PROF.inv.dances.includes(lkSel);
  eq.textContent=PROF.dance===lkSel?'✔ Danse équipée':own?'Équiper cette danse':'🔒 À débloquer dans les caisses';eq.classList.toggle('on',PROF.dance===lkSel);
  eq.onclick=()=>{if(!PROF.inv.dances.includes(lkSel)){sfx('deny');return;}PROF.dance=lkSel;saveProf();sfxUI();buildLocker();};
 }else{
  el.innerHTML=OUTFITS.map((o,i)=>{const own=ownsOutfit(i),c=rcol(o.q);return '<div class="dcard'+(lkOut===i?' on':'')+(own?'':' lock')+'" data-i="'+i+'" style="--c:'+c+'"><div style="display:flex;gap:10px;align-items:center"><i style="width:28px;height:28px;border-radius:50%;border:2px solid #fff3;background:'+outfitSwatch(i)+';flex:none"></i><div><b>'+o.n+'</b><span>'+RARITY[o.q].n.toUpperCase()+'</span></div></div>'+((PROF.outfit||0)===i?'<em>ÉQUIPÉE</em>':own?'':'<em style="color:#ff6b6b">🔒</em>')+'</div>';}).join('');
  el.querySelectorAll('.dcard').forEach(c=>c.onclick=()=>{lkOut=+c.dataset.i;lk.t=0;sfxUI();if(lk.r&&lk.outShown!==lkOut)lkRig(lkOut);buildLocker();});
  const own=ownsOutfit(lkOut);
  eq.textContent=(PROF.outfit||0)===lkOut?'✔ Tenue équipée':own?'Équiper cette tenue':'🔒 À débloquer dans les caisses';eq.classList.toggle('on',(PROF.outfit||0)===lkOut);
  eq.onclick=()=>{if(!ownsOutfit(lkOut)){sfx('deny');return;}PROF.outfit=lkOut;saveProf();sfxUI();buildLocker();};
 }
}
function lkFrame(dt,t){
 if(!lk.r)return;lk.t+=dt;
 const dance=lkTab==='dance'?lkSel:(lkOut?(lk.t%6<3.2?'wave':'twist'):'wave'),d=DANCES.find(x=>x.id===dance)||DANCES[0];
 animateSoldier(lk.R,{vx:0,vz:0,yaw:0,pitch:0,speed:0,onGround:true,crouch:false,alive:true,reload:0,reloadMax:0,fire:0,ready:0,alert:0,hurt:false,y:0,dance,danceT:lk.t%(d.len+.8),seated:0},dt,t);
 lk.R.root.rotation.y=Math.PI*.12+(lkTab==='outfit'?t*.5:0);
 lk.r.render(lk.s,lk.c);
}
/* ---------- statistiques ---------- */
function fmtTime(s){const h=Math.floor(s/3600),m=Math.floor(s%3600/60);return h+'h '+String(m).padStart(2,'0');}
function buildStats(){
 const s=PROF.stats,pc=(a,b)=>b?Math.round(a/b*100):0,kd=s.deaths?(s.kills/s.deaths).toFixed(2):s.kills.toFixed(2);
 const tiles=[['PARTIES',s.matches,'#4aa3ff'],['VICTOIRES',pc(s.wins,s.matches)+' %','#7dff9f'],['RATIO K/D',kd,'#ff4655'],['PRÉCISION',pc(s.hits,s.shots)+' %','#ffd75e'],
  ['HEADSHOTS',pc(s.hs,s.kills)+' %','#ff7a4a'],['DÉGÂTS / PARTIE',s.matches?Math.round(s.dmg/s.matches):0,'#b36bff'],['MEILLEURE SÉRIE',s.bestStreak,'#ffb938'],['TEMPS DE JEU',fmtTime(s.secs),'#4aa3ff']];
 $('stTiles').innerHTML=tiles.map(t=>'<div class="stile" style="--c:'+t[2]+'"><b>'+t[1]+'</b><em>'+t[0]+'</em></div>').join('');
 const row=(l,v,mx,txt)=>'<div class="srow"><span>'+l+'</span><div class="bar"><i style="width:'+(mx?Math.round(v/mx*100):0)+'%"></i></div><span style="width:70px;text-align:right">'+txt+'</span></div>';
 $('stModes').innerHTML=Object.keys(MODES).map(k=>{const m=s.byMode[k]||{m:0,w:0,k:0,d:0};return row(MODES[k].n,m.w,Math.max(1,m.m),m.m?pc(m.w,m.m)+' % ('+m.m+')':'—');}).join('');
 $('stMaps').innerHTML=Object.keys(MAPS).map(k=>{const m=s.byMap[k]||{m:0,w:0};return row(MAPS[k].n,m.w,Math.max(1,m.m),m.m?pc(m.w,m.m)+' % ('+m.m+')':'—');}).join('');
 const wk=Object.entries(s.byWeapon).sort((a,b)=>b[1]-a[1]).slice(0,8),mx=wk.length?wk[0][1]:1;
 $('stWeap').innerHTML=wk.length?wk.map(([k,v])=>'<div class="srow"><span><img src="'+weaponIcon(k,0)+'" style="height:20px;vertical-align:middle;margin-right:6px">'+W[k].n+'</span><div class="bar"><i style="width:'+Math.round(v/mx*100)+'%"></i></div><span style="width:40px;text-align:right">'+v+'</span></div>').join(''):'<div style="color:var(--dim);font-size:.75rem">Joue des parties pour voir tes armes favorites.</div>';
 $('stHist').innerHTML='<tr><th>DATE</th><th>MODE</th><th>CARTE</th><th>RÉSULTAT</th><th>K / D</th><th>HS</th><th>DÉGÂTS</th><th>XP</th></tr>'+(PROF.history.length?PROF.history.slice(0,15).map(h=>{const d=new Date(h.t);return '<tr><td>'+d.toLocaleDateString('fr-FR')+' '+d.toLocaleTimeString('fr-FR',{hour:'2-digit',minute:'2-digit'})+'</td><td>'+MODES[h.mode].n+'</td><td>'+MAPS[h.map].n+'</td><td class="'+(h.win?'w':'l')+'">'+(h.win?'VICTOIRE':'DÉFAITE')+'</td><td>'+h.k+' / '+h.d+'</td><td>'+h.hs+'</td><td>'+h.dmg+'</td><td>+'+h.xp+'</td></tr>';}).join(''):'<tr><td colspan="8" style="color:var(--dim)">Aucune partie jouée pour le moment.</td></tr>');
 $('stReset').onclick=()=>{if(confirm('Réinitialiser toutes tes statistiques ?')){resetStats();buildStats();}};
}
/* ---------- touches personnalisables ---------- */
let KEYMAP=null;
try{if(navigator.keyboard&&navigator.keyboard.getLayoutMap)navigator.keyboard.getLayoutMap().then(m=>{KEYMAP=m;if(typeof buildBinds==='function')buildBinds();});}catch(e){}
function keyLabel(code){
 if(!code)return 'Non assignée';
 const sp={Mouse0:'Clic gauche',Mouse1:'Clic molette',Mouse2:'Clic droit',Mouse3:'Souris 4',Mouse4:'Souris 5',WheelUp:'Molette ↑',WheelDown:'Molette ↓',Space:'Espace',ShiftLeft:'Maj gauche',ShiftRight:'Maj droite',ControlLeft:'Ctrl gauche',ControlRight:'Ctrl droit',AltLeft:'Alt gauche',AltRight:'Alt droit',Tab:'Tab',Enter:'Entrée',Backspace:'Retour',ArrowUp:'↑',ArrowDown:'↓',ArrowLeft:'←',ArrowRight:'→',CapsLock:'Verr. maj'};
 if(sp[code])return sp[code];
 if(KEYMAP&&KEYMAP.get(code))return KEYMAP.get(code).toUpperCase();
 return code.replace(/^Key/,'').replace(/^Digit/,'').replace(/^Numpad/,'Pavé ');
}
let rebindFor=null;
function buildBinds(){
 const el=$('bindList');if(!el)return;
 el.innerHTML=Object.keys(BINDLABEL).map(a=>'<div class="bindrow"><span>'+BINDLABEL[a]+'</span><button data-a="'+a+'" class="'+(rebindFor===a?'listen':'')+(cfg.binds[a]?'':' none')+'">'+(rebindFor===a?'Appuie sur une touche…':keyLabel(cfg.binds[a]))+'</button></div>').join('');
 el.querySelectorAll('button').forEach(b=>b.onclick=()=>{
  rebindFor=b.dataset.a;buildBinds();
  rebindCb=(code)=>{
   rebindCb=null;
   if(code!=='Escape'){for(const k in cfg.binds)if(cfg.binds[k]===code)cfg.binds[k]='';cfg.binds[rebindFor]=code;saveCfg();}
   rebindFor=null;buildBinds();
  };
 });
 $('bindReset').onclick=()=>{cfg.binds=Object.assign({},DEFBINDS);saveCfg();buildBinds();};
}
/* ---------- récompenses de fin de partie ---------- */
function progressLines(p){
 if(!p)return '';let h='';
 if(p.gained>0)h+='<div style="margin-top:6px;color:#9dd">Passe de combat : palier '+p.tier+(p.gained>1?' (+'+p.gained+')':' (+1)')+'</div>';
 if(p.rank)h+='<div style="margin-top:4px;color:'+rankCol(p.rank.after)+'">Classement : '+(p.rank.delta>0?'+':'')+p.rank.delta+' PR — '+p.rank.name+(p.rank.after>p.rank.before?' ▲':p.rank.after<p.rank.before?' ▼':'')+'</div>';
 for(const a of p.ach)h+='<div style="margin-top:4px;color:#ffd23a">🏆 Succès : '+a.n+' (+'+a.c+' 🪙)</div>';
 return h;
}
function showMatchRewards(win){
 const r=commitMatch(win),li=levelInfo();
 const before=Math.max(0,li.cur-r.xp);
 $('oRew').innerHTML=podiumHTML()+'<div class="rewbox"><div>Récompenses : <b>+'+r.xp+' XP</b> • <b>+'+r.coins+' 🪙</b></div><div class="xpbar"><i id="oXp" style="width:'+Math.round((r.ups.length?0:before)/li.need*100)+'%"></i></div><small style="color:var(--dim)">Niveau '+li.level+' — '+li.cur+' / '+li.need+' XP</small>'+progressLines(r.pr)+'</div>';
 setTimeout(()=>{const b=$('oXp');if(b)b.style.width=Math.round(li.cur/li.need*100)+'%';},120);
 juiceRewards(win);
 if(r.ups.length)setTimeout(()=>showLevelUps(r.ups),1800);
 refreshProfile();
}
function buildMetaUI(){
 ensureMissions();refreshProfile();renderMissions();buildBoxesTab();buildLocker();buildStats();buildBinds();
 if(dailyStatus().can)setTimeout(()=>showDaily(),900);
}
