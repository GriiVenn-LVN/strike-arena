/* =====================================================================
   ARMURERIE : schéma technique 3D, vue éclatée, rotation à la souris
   ===================================================================== */
let pvHold=false,pvSpin=1,bpMode='real';
const BP={labels:null,parts:[],explode:0,target:0,drag:null};
const REAL_LEN={glock:.19,usp:.24,p250:.19,fiveseven:.21,deagle:.27,mac10:.55,mp9:.52,ump:.69,p90:.5,nova:1.0,sawedoff:.66,xm:1.0,galil:.97,famas:.76,ak:.88,m4:.84,sg553:.98,aug:.79,ssg:1.12,awp:1.23,scar:1.07,negev:1.02,m249:1.04,raygun:.35,thunder:.9,winter:.8,knife:.3};
const CALIBRE={glock:'9×19 mm',usp:'.45 ACP',p250:'9×19 mm',fiveseven:'5,7×28 mm',deagle:'.50 AE',mac10:'.45 ACP',mp9:'9×19 mm',ump:'.45 ACP',p90:'5,7×28 mm',nova:'Cal. 12',sawedoff:'Cal. 12',xm:'Cal. 12',galil:'5,56×45 mm',famas:'5,56×45 mm',ak:'7,62×39 mm',m4:'5,56×45 mm',sg553:'5,56×45 mm',aug:'5,56×45 mm',ssg:'7,62×51 mm',awp:'.338 Lapua',scar:'7,62×51 mm',negev:'5,56×45 mm',m249:'5,56×45 mm',raygun:'Énergie',thunder:'Air comprimé',winter:'Cryogénique',knife:'—'};
/* redéfinit pvSet : applique le mode de vue courant au nouveau modèle */
function pvSet(k){
 pvKey=k;pvInit();if(!pvR)return;
 if(pvPivot)pvS.remove(pvPivot);
 const g=gunParts(k,skinOf(k)),box=new THREE.Box3().setFromObject(g),c=box.getCenter(new THREE.Vector3()),sz=box.getSize(new THREE.Vector3());
 g.position.set(-c.x,-c.y,-c.z);pvPivot=new THREE.Group();pvPivot.add(g);pvPivot.scale.setScalar(1.9/Math.max(sz.x,sz.z,.3));pvPivot.rotation.y=Math.PI*.55;pvS.add(pvPivot);
 BP.size=sz;BP.gun=g;BP.parts=[];
 for(const ch of g.children){const b=new THREE.Box3().setFromObject(ch);if(b.isEmpty())continue;const cc=b.getCenter(new THREE.Vector3());BP.parts.push({o:ch,base:ch.position.clone(),c:cc.sub(c)});}
 BP.explode=0;bpApply();
}
function bpApply(){
 if(!pvPivot)return;
 const g=BP.gun,schem=bpMode==='schema';
 g.traverse(o=>{
  if(!o.isMesh)return;
  if(!o.userData.mat0)o.userData.mat0=o.material;
  if(schem){
   o.material=new THREE.MeshBasicMaterial({color:0x0e3d6e,transparent:true,opacity:.28,depthWrite:false});
   if(!o.userData.edges){const e=new THREE.LineSegments(new THREE.EdgesGeometry(o.geometry,22),new THREE.LineBasicMaterial({color:0x9fe3ff,transparent:true,opacity:.95}));o.add(e);o.userData.edges=e;}
   o.userData.edges.visible=true;
  }else{o.material=o.userData.mat0;if(o.userData.edges)o.userData.edges.visible=false;}
 });
 const fl=pvS.children.find(o=>o.isMesh&&o.geometry&&o.geometry.type==='CircleGeometry');if(fl)fl.visible=!schem;
 $('pv').style.background=schem?'#0a2a4d linear-gradient(#ffffff14 1px,transparent 1px) 0 0/22px 22px,linear-gradient(90deg,#ffffff14 1px,transparent 1px) 0 0/22px 22px':'';
 if(schem)$('pv').style.backgroundColor='#0a2a4d';
 BP.target=bpMode==='explode'?1:0;
 bpLabels();
}
function bpUi(){
 const prev=document.querySelector('#tab-arms .prev');if(!prev||$('bpBar'))return;
 const wrap=document.createElement('div');wrap.style.cssText='position:relative';
 const cv=$('pv');cv.parentNode.insertBefore(wrap,cv);wrap.appendChild(cv);
 const lab=document.createElement('div');lab.id='bpLab';lab.style.cssText='position:absolute;inset:0;pointer-events:none;font:700 11px Bahnschrift,Arial;color:#cfefff;letter-spacing:1px';wrap.appendChild(lab);BP.labels=lab;
 const bar=document.createElement('div');bar.id='bpBar';bar.className='chips';bar.style.cssText='justify-content:center;margin-top:8px';
 wrap.parentNode.insertBefore(bar,wrap.nextSibling);
 const draw=()=>{bar.innerHTML='';
  [['real','Rendu réaliste'],['schema','Schéma 3D'],['explode','Vue éclatée']].forEach(([id,n])=>{const c=document.createElement('div');c.className='chip'+(bpMode===id?' on':'');c.textContent=n;c.onclick=()=>{sfxUI();bpMode=id;bpApply();draw();};bar.appendChild(c);});
  const r=document.createElement('div');r.className='chip'+(pvSpin?' on':'');r.textContent=pvSpin?'⟳ Rotation auto':'⟳ Rotation fixe';r.onclick=()=>{sfxUI();pvSpin=pvSpin?0:1;draw();};bar.appendChild(r);
 };draw();
 const tip=document.createElement('div');tip.style.cssText='font-size:.64rem;color:#6f819e;margin-top:5px';tip.textContent='Clique-glisse sur l\'arme pour la tourner';bar.parentNode.insertBefore(tip,bar.nextSibling);
 cv.addEventListener('mousedown',e=>{BP.drag={x:e.clientX,y:e.clientY};pvHold=true;});
 addEventListener('mousemove',e=>{if(!BP.drag||!pvPivot)return;pvPivot.rotation.y+=(e.clientX-BP.drag.x)*.01;pvPivot.rotation.x=clamp(pvPivot.rotation.x+(e.clientY-BP.drag.y)*.006,-.6,.6);BP.drag={x:e.clientX,y:e.clientY};});
 addEventListener('mouseup',()=>{BP.drag=null;pvHold=false;});
}
function bpLabels(){
 if(!BP.labels)return;BP.labels.innerHTML='';
 if(bpMode==='real')return;
 const k=pvKey,w=W[k],u=BP.gun.userData;
 const parts=[];
 if(!w.melee){
  parts.push(['Bouche du canon',new THREE.Vector3(0,.02,u.muzzle)]);
  parts.push(['Organes de visée',new THREE.Vector3(0,u.sight||.06,(u.muzzle||-.4)*.45)]);
  if(u.mag){const b=new THREE.Box3().setFromObject(u.mag);if(!b.isEmpty())parts.push(['Chargeur ('+w.mag+' coups)',b.getCenter(new THREE.Vector3()).sub(BP.gun.position.clone().multiplyScalar(0))]);}
  parts.push(['Poignée',u.right.clone().add(new THREE.Vector3(0,-.04,.03))]);
  if(u.backZ!==undefined||true)parts.push(['Crosse',new THREE.Vector3(0,0,BP.size.z*.5-.06)]);
 }else{parts.push(['Lame',new THREE.Vector3(0,0,-.2)]);parts.push(['Manche',new THREE.Vector3(0,0,.05)]);}
 BP.pts=parts.map(([n,v])=>{const d=document.createElement('div');d.style.cssText='position:absolute;white-space:nowrap;padding:2px 6px;border:1px solid #9fe3ff88;background:#0a2a4dcc;transform:translate(-50%,-140%)';d.textContent=n;BP.labels.appendChild(d);
  const dot=document.createElement('div');dot.style.cssText='position:absolute;width:7px;height:7px;border-radius:50%;background:#9fe3ff;box-shadow:0 0 8px #9fe3ff;transform:translate(-50%,-50%)';BP.labels.appendChild(dot);return {v,d,dot};});
 const spec=document.createElement('div');spec.style.cssText='position:absolute;left:10px;top:10px;padding:8px 10px;border:1px solid #9fe3ff66;background:#06203dcc;text-align:left;line-height:1.55;font-weight:600';
 const len=(REAL_LEN[k]||BP.size.z).toFixed(2).replace('.',',');
 spec.innerHTML='<div style="font-weight:900;letter-spacing:3px;color:#fff">'+w.n.toUpperCase()+'</div>'+
  (w.melee?'Arme blanche':'Calibre : '+(CALIBRE[k]||'—')+'<br>Longueur : '+len+' m<br>Cadence : '+w.rpm+' coups/min<br>Chargeur : '+w.mag+' / réserve '+w.res+'<br>Mode : '+(w.auto?'automatique':'semi-auto')+'<br>Portée efficace : '+Math.round((w.fo||20)*1.2)+' m');
 BP.labels.appendChild(spec);
 const dim=document.createElement('div');dim.id='bpDim';dim.style.cssText='position:absolute;height:0;border-top:1px dashed #9fe3ff;font-size:10px;text-align:center';dim.innerHTML='<span style="position:relative;top:-14px">'+len+' m</span>';BP.labels.appendChild(dim);BP.dim=dim;
}
const _bpv=new THREE.Vector3();
function bpTick(dt){
 if(!pvOn||!pvPivot||!BP.gun)return;
 // vue éclatée : chaque pièce s'écarte du centre de l'arme
 BP.explode+=(BP.target-BP.explode)*Math.min(1,dt*5);
 for(const p of BP.parts){const e=BP.explode;p.o.position.set(p.base.x+p.c.x*e*.6,p.base.y+p.c.y*e*2.2+(p.o===BP.gun.userData.mag?-e*.12:0),p.base.z+p.c.z*e*.55);}
 if(bpMode==='real'||!BP.pts)return;
 const cv=$('pv'),W2=cv.clientWidth,H2=cv.clientHeight;
 pvPivot.updateMatrixWorld(true);
 for(const p of BP.pts){
  _bpv.copy(p.v);BP.gun.localToWorld(_bpv);_bpv.project(pvC);
  const x=(_bpv.x*.5+.5)*W2,y=(-_bpv.y*.5+.5)*H2;
  p.dot.style.left=x+'px';p.dot.style.top=y+'px';p.d.style.left=x+'px';p.d.style.top=y+'px';
 }
 // cote de longueur sous l'arme
 const b=new THREE.Box3().setFromObject(BP.gun),a=new THREE.Vector3(),c=new THREE.Vector3();
 a.set(b.min.x,b.min.y,b.min.z).project(pvC);c.set(b.max.x,b.min.y,b.max.z).project(pvC);
 const x1=(Math.min(a.x,c.x)*.5+.5)*W2,x2=(Math.max(a.x,c.x)*.5+.5)*W2,y=(-Math.min(a.y,c.y)*.5+.5)*H2+18;
 BP.dim.style.left=x1+'px';BP.dim.style.width=Math.max(10,x2-x1)+'px';BP.dim.style.top=Math.min(H2-6,y)+'px';
}
(function bpLoop(){let last=performance.now();const f=()=>{const n=performance.now();const dt=Math.min(.05,(n-last)/1000);last=n;try{bpTick(dt);}catch(e){}requestAnimationFrame(f);};requestAnimationFrame(f);})();
