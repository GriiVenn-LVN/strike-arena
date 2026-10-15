/* =====================================================================
   MAINS RÉALISTES (vue subjective)
   Gants tactiques modelés : paume arrondie, quatre doigts en trois
   phalanges qui s'enroulent autour de la poignée, pouce opposé,
   coque de protection des jointures, sangle de poignet, coutures.
   La main droite tient la poignée (axe vertical), la gauche tient le
   garde-main (axe le long du canon).
   ===================================================================== */
const HANDG={};
// capsule (cylindre + demi-sphères) le long de Y, longueur totale L
function capsGeo(r,L){const k=r.toFixed(4)+'_'+L.toFixed(4);if(HANDG[k])return HANDG[k];
 const pts=[],h=Math.max(0,L/2-r),n=6;
 for(let i=0;i<=n;i++){const a=-Math.PI/2+i/n*Math.PI/2;pts.push(new THREE.Vector2(Math.cos(a)*r+1e-4,-h+Math.sin(a)*r));}
 for(let i=0;i<=n;i++){const a=i/n*Math.PI/2;pts.push(new THREE.Vector2(Math.cos(a)*r+1e-4,h+Math.sin(a)*r));}
 return HANDG[k]=new THREE.LatheGeometry(pts,12);}
// pavé arrondi « gonflé » (paume, coque)
function puffGeo(w,h,d,round){const k='p'+w+'_'+h+'_'+d+'_'+round;if(HANDG[k])return HANDG[k];
 const g=new THREE.BoxGeometry(w,h,d,6,6,6),p=g.attributes.position,v=new THREE.Vector3(),hw=w/2,hh=h/2,hd=d/2,r=Math.min(hw,hh,hd)*round;
 for(let i=0;i<p.count;i++){v.fromBufferAttribute(p,i);
  const cx=Math.max(-hw+r,Math.min(hw-r,v.x)),cy=Math.max(-hh+r,Math.min(hh-r,v.y)),cz=Math.max(-hd+r,Math.min(hd-r,v.z));
  const dx=v.x-cx,dy=v.y-cy,dz=v.z-cz,l=Math.hypot(dx,dy,dz)||1;p.setXYZ(i,cx+dx/l*r,cy+dy/l*r,cz+dz/l*r);}
 g.computeVertexNormals();return HANDG[k]=g;}
// tissu du gant : trame fine + coutures
function gloveTex(){return cached('gloveFab',()=>canvasTex(128,128,(c,w,h)=>{
 c.fillStyle='#bdbdbd';c.fillRect(0,0,w,h);
 for(let y=0;y<h;y+=2)for(let x=0;x<w;x+=2){const v=150+((x*7+y*13)%5)*12+Math.random()*30;c.fillStyle='rgb('+v+','+v+','+v+')';c.fillRect(x,y,1.5,1.5);}
 c.strokeStyle='rgba(60,60,60,.7)';c.setLineDash([2,2]);c.lineWidth=1;for(let x=16;x<w;x+=32){c.beginPath();c.moveTo(x,0);c.lineTo(x,h);c.stroke();}c.setLineDash([]);
},true));}
const HAND_MATS=new Map();
function handMats(glove){
 if(HAND_MATS.has(glove))return HAND_MATS.get(glove);
 const fab=gloveTex();
 const m={fab:new THREE.MeshStandardMaterial({color:glove.color.clone().lerp(new THREE.Color(1,1,1),.08),map:fab,roughness:.86,metalness:0}),
  palm:new THREE.MeshStandardMaterial({color:glove.color.clone().multiplyScalar(.75),roughness:.6,metalness:0}),
  pad:new THREE.MeshStandardMaterial({color:new THREE.Color(.025,.027,.03),roughness:.35,metalness:.15}),
  strap:new THREE.MeshStandardMaterial({color:glove.color.clone().multiplyScalar(.6),roughness:.7,metalness:0}),
  skin:new THREE.MeshStandardMaterial({color:C('#c58c64'),roughness:.55,metalness:0})};
 HAND_MATS.set(glove,m);return m;}
// segment entre deux points
const _hY=new THREE.Vector3(0,1,0);
function handSeg(grp,a,b,r,mat){const d=new THREE.Vector3().subVectors(b,a),L=d.length();const m=new THREE.Mesh(capsGeo(r,L+r*1.6),mat);
 m.position.copy(a).addScaledVector(d,.5);m.quaternion.setFromUnitVectors(_hY,d.normalize());m.castShadow=false;grp.add(m);return m;}
/* main droite autour d'un cylindre vertical (poignée) de centre (0,0,0) ; -z = vers l'avant */
function makeRealHand(glove){
 const M=handMats(glove),root=new THREE.Group(),inner=new THREE.Group();root.add(inner);root.userData.inner=inner;
 const R=.026,P=(phi,y,rr)=>new THREE.Vector3(Math.cos(phi)*(rr||R),y,Math.sin(phi)*(rr||R));
 const D=Math.PI/180;
 // paume + dos de la main (côté droit et arrière de la poignée)
 const palm=new THREE.Mesh(puffGeo(.026,.084,.07,.75),M.fab);palm.position.set(.03,-.036,.018);palm.rotation.y=-.62;inner.add(palm);
 // coque des jointures + sangle du poignet
 const pad=new THREE.Mesh(puffGeo(.012,.07,.026,.9),M.pad);pad.position.set(.046,-.034,-.006);pad.rotation.y=-.35;inner.add(pad);
 const strap=new THREE.Mesh(puffGeo(.03,.05,.02,.6),M.strap);strap.position.set(.03,-.03,.05);strap.rotation.y=-.9;inner.add(strap);
 // doigts : index en haut, auriculaire en bas ; chaque phalange suit l'enroulement autour de la poignée
 const F=[{y:-.008,L:[.042,.026,.021],r:.0088},{y:-.027,L:[.046,.029,.022],r:.0092},{y:-.046,L:[.043,.027,.021],r:.0088},{y:-.063,L:[.034,.021,.018],r:.0076}];
 for(const f of F){
  let phi=-14*D,a=P(phi,f.y);const k=new THREE.Mesh(capsGeo(f.r*1.12,f.r*2.4),M.fab);k.position.copy(a);inner.add(k);   // jointure
  f.L.forEach((L,i)=>{const dphi=-L/R*(i?1.05:.95);phi+=dphi;const b=P(phi,f.y-.002*i,R-.002*i);handSeg(inner,a,b,f.r*(1-i*.08),i?M.fab:M.fab);a=b;});
  const tip=new THREE.Mesh(capsGeo(f.r*.86,f.r*1.7),M.palm);tip.position.copy(a);inner.add(tip);   // bout renforcé
 }
 // pouce : de la base de la paume, autour de l'arrière et du côté gauche, au-dessus de l'index
 {let a=new THREE.Vector3(.03,-.03,.042),pts=[P(118*D,-.004,.03),P(168*D,.004,.028),P(205*D,.008,.026)],rr=[.0125,.0105,.0095];
  pts.forEach((b,i)=>{handSeg(inner,a,b,rr[i],i===2?M.palm:M.fab);a=b;});}
 inner.traverse(o=>{if(o.isMesh)o.castShadow=false;});
 return root;
}
{const _mh=makeHandMesh;
 makeHandMesh=function(mat,detail){return detail?makeRealHand(mat):_mh(mat,detail);};}
// la main gauche tient le garde-main : poignée couchée le long du canon, paume dessous
{const _sl=VM.setLook;
 VM.setLook=function(lk){const key=lk.kind+lk.acc+lk.tone+(lk.outfit||0),fresh=VM.look!==key;_sl(lk);
  if(fresh&&VM.hL&&VM.hL.userData.inner){const i=VM.hL.userData.inner;i.rotation.set(-Math.PI/2,0,-1.1);i.position.set(0,-.006,0);}};
 VM.look='';}
