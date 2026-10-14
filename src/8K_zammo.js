/* =====================================================================
   ZOMBIES : PORTEURS DE MUNITIONS
   - À chaque manche, quelques zombies (un par humain, bots compris,
     5 au maximum) brillent en jaune.
   - Celui qui en tue un récupère des chargeurs pleins et la réserve
     maximale pour toutes ses armes.
   - Les porteurs sont répartis sur toute la manche (pas tous au début).
   ===================================================================== */
const ZAMMO={left:0,max:5};
const _zOnWaveAmmo=zOnWave;
zOnWave=function(){
 _zOnWaveAmmo();
 ZAMMO.left=Math.min(ZAMMO.max,ents.filter(e=>!e.zombie&&e.team===0).length);
};
const _zStyleAmmo=zStyleZombie;
zStyleZombie=function(z){
 _zStyleAmmo(z);
 // chance = porteurs restants / zombies restants à faire apparaître : tous sortent avant la fin
 if(ZAMMO.left>0&&z.ztype!=='boss'&&Math.random()<ZAMMO.left/Math.max(1,Z.queue)){
  ZAMMO.left--;z.ammoCarrier=true;
  if(z.rig){const g=zGlow(0xffd23a,1.3);if(g){g.position.y=1.15;z.rig.root.add(g);z._ammoGlow=g;}}
 }
};
function zRefillAll(h){
 for(const s of ['p','s']){const wi=h.wp[s];if(wi){wi.mag=magMax(h,wi.k);wi.res=Math.max(wi.res,W[wi.k].res*(wi.pap?2:1),s==='s'&&wi.k==='p250'?ZSTART_RES:0);}}
}
const _zKillAmmo=zKillHook;
zKillHook=function(att,v,w,hs){
 _zKillAmmo(att,v,w,hs);
 if(!v.zombie||!v.ammoCarrier)return;
 v.ammoCarrier=false;if(v._ammoGlow){v._ammoGlow.parent&&v._ammoGlow.parent.remove(v._ammoGlow);v._ammoGlow=null;}
 // tué par une explosion ou un piège : le survivant le plus proche en profite
 let h=att&&!att.zombie&&att.alive?att:null;
 if(!h){let bd=1e9;for(const e of ents)if(!e.zombie&&e.alive){const d=Math.hypot(e.x-v.x,e.z-v.z);if(d<bd){bd=d;h=e;}}}
 if(!h)return;
 zRefillAll(h);sfx('pickup',v.x,v.z);
 if(fxReady)for(let i=0;i<14;i++)fxA.emit(v.x,v.y+rand(.4,1.6),v.z,rand(-1,1),rand(.5,2),rand(-1,1),.7,.15,.05,1,.82,.23,1,-2,1);
 if(h.isPlayer)uiBanner('MUNITIONS RECHARGÉES','Zombie porteur éliminé',1600,'#ffd23a');
};
