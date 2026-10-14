/* =====================================================================
   RÉGÉNÉRATION DE SANTÉ
   - Après 3 s sans subir de dégâts, les PV remontent de 20 PV/s
     jusqu'à 100 (joueur, bots, alliés).
   - Zombies et tous les modes à réapparition (match à mort, équipes,
     roi de la colline, bataille royale…).
   - Pas dans les modes à manches sans réapparition (Compétitif,
     Désamorçage rapide, Duel) : la santé y reste tactique.
   - Coupé quand on est à terre ; le timer repart à chaque dégât
     (coups, chute, explosions…). En multijoueur, seul l'hôte calcule.
   ===================================================================== */
const REGEN_DELAY=3,REGEN_RATE=20,REGEN_MAX=100;
const regenOn=()=>G.running&&G.mode!=='bomb'&&G.variant!=='train'&&NET.role!=='client';
function regenUpdate(dt){
 if(!regenOn())return;
 for(const h of ents){
  if(h.zombie||h.dummy||!h.alive||h.downed)continue;
  if(h._rgHp===undefined||h.hp<h._rgHp)h._rgT=G.t; // tout dégât relance le délai
  if(h.hp<REGEN_MAX&&G.t-Math.max(h._rgT,h.lastHurtT||-9)>=REGEN_DELAY)h.hp=Math.min(REGEN_MAX,h.hp+REGEN_RATE*dt);
  h._rgHp=h.hp;
 }
}
const _zUpdateRegen=zUpdate;
zUpdate=function(dt){
 _zUpdateRegen(dt);
 regenUpdate(dt);
};
