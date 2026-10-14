/* =====================================================================
   EFFETS D'ÉLIMINATION (cosmétiques, façon RIVALS / Arsenal)
   Joués sur l'adversaire quand c'est toi qui élimines. Aucun avantage :
   ils se débloquent avec le niveau du profil (Citrouilles : pendant
   l'événement d'Halloween). À choisir dans Arsenal › Casier › Effets.
   ===================================================================== */
const KILLFX=[
 {id:'none',n:'Classique',lv:1,c:'#8da0bd',d:'Pas d\'effet particulier.'},
 {id:'confetti',n:'Confettis',lv:2,c:'#ffd23a',d:'Une pluie de confettis multicolores.'},
 {id:'pixel',n:'Désintégration',lv:5,c:'#35e0c0',d:'L\'adversaire part en cubes lumineux.'},
 {id:'flame',n:'Combustion',lv:10,c:'#ff9a3a',d:'Une gerbe de flammes et de braises.'},
 {id:'bolt',n:'Foudre',lv:15,c:'#7fb8ff',d:'Un éclair tombe du ciel.'},
 {id:'ghost',n:'Âme errante',lv:20,c:'#e6f0ff',d:'Un petit fantôme s\'envole.'},
 {id:'pumpkin',n:'Citrouilles',lv:1,ev:true,c:'#ff7a1a',d:'Événement d\'Halloween : des citrouilles rebondissent.'}
];
const KFX={parts:[],bolts:[],tex:{}};
function killFxOwned(f){return f.ev?(typeof eventActive==='function'&&eventActive()):levelInfo().level>=f.lv;}
function killFxCur(){const f=KILLFX.find(x=>x.id===PROF.killfx);return f&&killFxOwned(f)?f:KILLFX[0];}
function kfxTex(kind){
 if(KFX.tex[kind])return KFX.tex[kind];
 const c=document.createElement('canvas');c.width=c.height=64;const g=c.getContext('2d');
 if(kind==='ghost'){g.fillStyle='rgba(235,245,255,.95)';g.beginPath();g.arc(32,26,18,Math.PI,0);g.lineTo(50,54);for(let i=0;i<4;i++){g.lineTo(50-i*6-3,48);g.lineTo(50-i*6-6,54);}g.closePath();g.fill();g.fillStyle='#223';g.beginPath();g.arc(25,26,3.5,0,TAU);g.arc(39,26,3.5,0,TAU);g.fill();}
 else if(kind==='pumpkin'){g.font='48px serif';g.textAlign='center';g.textBaseline='middle';g.fillText('🎃',32,36);}
 const t=new THREE.CanvasTexture(c);KFX.tex[kind]=t;return t;
}
function kfxPart(x,y,z,o){
 const m=new THREE.SpriteMaterial({color:o.col||0xffffff,map:o.map||null,transparent:true,depthWrite:false,blending:o.add?THREE.AdditiveBlending:THREE.NormalBlending,toneMapped:false});
 const s=new THREE.Sprite(m);s.position.set(x,y,z);s.scale.setScalar(o.size||.12);scene.add(s);
 KFX.parts.push({s,vx:o.vx||0,vy:o.vy||0,vz:o.vz||0,g:o.g===undefined?-9:o.g,life:o.life||1.2,t:0,drag:o.drag||0,grow:o.grow||0,spin:o.spin||0,bounce:o.bounce||0,floor:y-1.2});
}
function killFx(v,id){
 const f=id?KILLFX.find(x=>x.id===id):killFxCur();if(!f||f.id==='none')return;
 const x=v.x,y=v.y+1,z=v.z;
 if(f.id==='confetti'){
  const cols=[0xff4655,0xffd23a,0x35e0c0,0x4aa3ff,0xc77dff,0x7dff9f];
  for(let i=0;i<46;i++){const a=rand(0,TAU),sp=rand(1.5,4.5);kfxPart(x,y+.3,z,{col:pick(cols),size:rand(.06,.11),vx:Math.cos(a)*sp,vz:Math.sin(a)*sp,vy:rand(3,6.5),g:-6,drag:1.6,life:rand(1.2,2),spin:rand(-8,8)});}
  sfx('pop',x,z,.6);
 }else if(f.id==='pixel'){
  for(let i=0;i<40;i++){kfxPart(x+rand(-.35,.35),y+rand(-.9,.7),z+rand(-.35,.35),{col:pick([0x35e0c0,0x7dfff0,0x1aa8ff]),add:true,size:rand(.08,.15),vx:rand(-.5,.5),vz:rand(-.5,.5),vy:rand(.8,2.6),g:0,drag:.5,life:rand(.9,1.6),grow:-.05});}
  sfx('zap',x,z,.5);
 }else if(f.id==='flame'){
  for(let i=0;i<34;i++){kfxPart(x+rand(-.3,.3),y+rand(-.9,.4),z+rand(-.3,.3),{map:GLOW.orange,col:pick([0xffa040,0xff6a20,0xffd060]),add:true,size:rand(.35,.7),vx:rand(-.4,.4),vz:rand(-.4,.4),vy:rand(1.5,3.5),g:1,drag:1,life:rand(.6,1.1),grow:-.3});}
  for(let i=0;i<18;i++){kfxPart(x,y,z,{col:0xffc070,add:true,size:.05,vx:rand(-2,2),vz:rand(-2,2),vy:rand(2,5),g:-4,life:rand(1,1.6)});}
  sfx('boom',x,z,.25);
 }else if(f.id==='bolt'){
  const pts=[];let px=x,pz=z;for(let h=y+22;h>y-1;h-=1.6){pts.push(new THREE.Vector3(px,h,pz));px=x+rand(-.8,.8)*(h-y)/22*3;pz=z+rand(-.8,.8)*(h-y)/22*3;}pts.push(new THREE.Vector3(x,y-1,z));
  const ln=new THREE.Group(),mat=new THREE.MeshBasicMaterial({color:0xd8ecff,transparent:true,blending:THREE.AdditiveBlending,depthWrite:false,toneMapped:false});
  for(let i=0;i<pts.length-1;i++){const a=pts[i],c=pts[i+1],L=a.distanceTo(c),m=new THREE.Mesh(new THREE.CylinderGeometry(.06,.06,L,5,1),mat);m.position.copy(a).add(c).multiplyScalar(.5);m.quaternion.setFromUnitVectors(new THREE.Vector3(0,1,0),c.clone().sub(a).normalize());ln.add(m);}
  scene.add(ln);KFX.bolts.push({o:ln,t:0,mat});
  kfxPart(x,y,z,{map:GLOW.cool,col:0xbfe0ff,add:true,size:4,g:0,life:.35,grow:-6});
  for(let i=0;i<20;i++){const a=rand(0,TAU);kfxPart(x,y-.9,z,{col:0xcfe6ff,add:true,size:.06,vx:Math.cos(a)*rand(2,5),vz:Math.sin(a)*rand(2,5),vy:rand(1,4),g:-9,life:rand(.4,.8)});}
  if(typeof muzzleLight==='function')muzzleLight(x,y+1,z);
  sfx('thunder',x,z,.5);
 }else if(f.id==='ghost'){
  kfxPart(x,y+.2,z,{map:kfxTex('ghost'),size:.9,vy:1.4,g:0,life:2.2,drag:.2});
  for(let i=0;i<14;i++)kfxPart(x+rand(-.3,.3),y+rand(-.6,.4),z+rand(-.3,.3),{map:GLOW.white,add:true,size:rand(.2,.35),vy:rand(.6,1.4),g:0,life:rand(.8,1.5),grow:-.15});
  sfx('jingle',x,z,.35);
 }else if(f.id==='pumpkin'){
  for(let i=0;i<7;i++){const a=rand(0,TAU),sp=rand(1.2,3);kfxPart(x,y+.2,z,{map:kfxTex('pumpkin'),size:rand(.35,.5),vx:Math.cos(a)*sp,vz:Math.sin(a)*sp,vy:rand(3,5),g:-12,life:2.2,bounce:.55});}
  sfx('pop',x,z,.5);
 }
}
function killFxUpdate(dt){
 for(let i=KFX.parts.length-1;i>=0;i--){
  const p=KFX.parts[i];p.t+=dt;
  if(p.t>=p.life){scene.remove(p.s);p.s.material.dispose();KFX.parts.splice(i,1);continue;}
  const dr=Math.max(0,1-p.drag*dt);p.vx*=dr;p.vz*=dr;p.vy=p.vy*dr+p.g*dt;
  p.s.position.x+=p.vx*dt;p.s.position.y+=p.vy*dt;p.s.position.z+=p.vz*dt;
  if(p.bounce&&p.s.position.y<p.floor){p.s.position.y=p.floor;p.vy=Math.abs(p.vy)*p.bounce;}
  if(p.grow)p.s.scale.setScalar(Math.max(.01,p.s.scale.x+p.grow*dt));
  if(p.spin)p.s.material.rotation+=p.spin*dt;
  p.s.material.opacity=Math.min(1,(p.life-p.t)/(p.life*.35));
 }
 for(let i=KFX.bolts.length-1;i>=0;i--){const b=KFX.bolts[i];b.t+=dt;b.mat.opacity=b.t<.08||(b.t>.14&&b.t<.2)?1:Math.max(0,.6-b.t*2);if(b.t>.4){scene.remove(b.o);b.o.children.forEach(m=>m.geometry.dispose());b.mat.dispose();KFX.bolts.splice(i,1);}}
}
function killFxClear(){for(const p of KFX.parts){scene.remove(p.s);p.s.material.dispose();}KFX.parts.length=0;for(const b of KFX.bolts)scene.remove(b.o);KFX.bolts.length=0;}
// déclenchement : uniquement sur les éliminations du joueur
const _killEntFx=killEnt;
killEnt=function(v,att,w,hs){
 const was=v.alive;_killEntFx(v,att,w,hs);
 if(was&&!v.alive&&att&&att.isPlayer&&att!==v&&!v.dummy)killFx(v);
};
const _updateFXKfx=updateFX;
updateFX=function(dt,t){_updateFXKfx(dt,t);killFxUpdate(dt);};
const _resetFXKfx=resetFX;
resetFX=function(){_resetFXKfx();killFxClear();};

/* ---------- casier : onglet « Effets » ---------- */
let kfxSel=null;
const _buildLockerKfx=buildLocker;
buildLocker=function(){
 const mine=lkTab==='killfx';
 if(mine)lkTab='dance';
 _buildLockerKfx();
 if(mine)lkTab='killfx';
 const seg=$('lkSeg'),el=$('danceList'),eq=$('danceEq');if(!seg||!el)return;
 const chip=document.createElement('div');chip.className='chip'+(mine?' on':'');chip.dataset.t='killfx';chip.textContent='Effets d\'élimination';
 chip.onclick=()=>{lkTab='killfx';sfxUI();buildLocker();};seg.appendChild(chip);
 if(!mine)return;
 seg.querySelectorAll('.chip').forEach(c=>{if(c!==chip)c.classList.remove('on');});
 const lv=levelInfo().level,cur=killFxCur().id;kfxSel=kfxSel||cur;
 el.innerHTML=KILLFX.filter(f=>!f.ev||killFxOwned(f)).map(f=>{const own=killFxOwned(f);return '<div class="dcard'+(kfxSel===f.id?' on':'')+(own?'':' lock')+'" data-id="'+f.id+'" style="--c:'+f.c+'"><b>'+f.n+'</b><span>'+(f.ev?'ÉVÉNEMENT':'NIVEAU '+f.lv)+'</span>'+(cur===f.id?'<em>ÉQUIPÉ</em>':own?'':'<em style="color:#ff6b6b">🔒 niv. '+f.lv+'</em>')+'</div>';}).join('')+
  '<div style="grid-column:1/-1;font-size:.78rem;color:#b8c5da;margin-top:6px" id="kfxDesc"></div>';
 const f=KILLFX.find(x=>x.id===kfxSel)||KILLFX[0];$('kfxDesc').textContent=f.d+(killFxOwned(f)?'':' Se débloque au niveau '+f.lv+' (tu es niveau '+lv+').');
 el.querySelectorAll('.dcard').forEach(c=>c.onclick=()=>{kfxSel=c.dataset.id;sfxUI();buildLocker();});
 if(eq){
  const own=killFxOwned(f);
  eq.textContent=cur===f.id?'✔ Effet équipé':own?'Équiper cet effet':'🔒 Niveau '+f.lv+' requis';eq.classList.toggle('on',cur===f.id);
  eq.onclick=()=>{if(!killFxOwned(f)){sfx('deny');return;}PROF.killfx=f.id;saveProf();sfxUI();buildLocker();};
 }
};
