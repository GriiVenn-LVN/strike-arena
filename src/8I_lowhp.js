/* =====================================================================
   ALERTE SANTÉ BASSE
   - Le bord rouge existant (#lowhp, sous 30 PV) bat plus vite et plus
     fort quand la santé baisse, avec des battements de cœur.
   ===================================================================== */
let beatT=0;
function lowHpUpdate(dt){
 const el=$('lowhp');if(!el)return;
 const on=G.running&&P&&P.alive&&P.hp>0&&P.hp<30&&G.state!=='potg'&&G.state!=='over';
 if(!on){if(el.style.animationDuration){el.style.animationDuration='';el.style.filter='';}beatT=0;return;}
 const k=1-P.hp/30,per=1.1-.4*k;
 el.style.animationDuration=per.toFixed(2)+'s';el.style.filter='brightness('+(1+.8*k).toFixed(2)+')';
 beatT-=dt;
 if(beatT<=0){beatT=per;sfx('step',P.x,P.z,.55);setTimeout(()=>{if(G.running&&P.alive)sfx('step',P.x,P.z,.4);},160);}
}
let _lhpT=performance.now();
const _updateFXLow=updateFX;
updateFX=function(dt,t){
 _updateFXLow(dt,t);
 const n=performance.now(),rdt=Math.min(.1,(n-_lhpT)/1000);_lhpT=n;
 lowHpUpdate(rdt);
};
