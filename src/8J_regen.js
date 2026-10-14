/* =====================================================================
   ZOMBIES : RÉGÉNÉRATION DE SANTÉ
   - Après 3 s sans subir de dégâts, les PV des humains (joueur et
     alliés) remontent de 20 PV/s jusqu'à 100.
   - Coupé quand on est à terre ; le timer repart à chaque dégât
     (coups de zombies, chute, explosions…).
   ===================================================================== */
const REGEN_DELAY=3,REGEN_RATE=20,REGEN_MAX=100;
function zRegenUpdate(dt){
 if(!zOn()||!G.running)return;
 for(const h of ents){
  if(h.zombie||!h.alive||h.downed)continue;
  if(h._rgHp===undefined||h.hp<h._rgHp)h._rgT=G.t; // tout dégât relance le délai
  if(h.hp<REGEN_MAX&&G.t-Math.max(h._rgT,h.lastHurtT||-9)>=REGEN_DELAY)h.hp=Math.min(REGEN_MAX,h.hp+REGEN_RATE*dt);
  h._rgHp=h.hp;
 }
}
const _zUpdateRegen=zUpdate;
zUpdate=function(dt){
 _zUpdateRegen(dt);
 zRegenUpdate(dt);
};
