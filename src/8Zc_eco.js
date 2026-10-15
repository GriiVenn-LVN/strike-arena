/* =====================================================================
   ÉCONOMIE FAÇON VALORANT (Recherche et destruction, économie réaliste)
   800 au départ et à la mi-temps (manche au pistolet), 3000 par manche
   gagnée, 1900 / 2400 / 2900 par défaites d'affilée, 200 par élimination,
   300 à chaque attaquant quand la bombe est posée, plafond 9000.
   ===================================================================== */
const ECO={start:800,win:3000,loss:[1900,2400,2900],kill:200,plant:300,defuse:0,max:9000};
// Désamorçage rapide garde son argent illimité
function ecoOn(){return !!cfg.eco&&G.variant!=='rapid';}
function ecoCap(){return ecoOn()?ECO.max:16000;}
// pose de la bombe : toute l'équipe attaquante touche la prime (en mode armes libres, seul le poseur, comme avant)
function ecoPlant(e){
 if(!ecoOn()){e.money=Math.min(16000,e.money+300);return;}
 for(const o of ents)if(o.team===e.team)o.money=Math.min(ECO.max,o.money+ECO.plant);
 if(e.isPlayer||P&&P.team===e.team)uiMoney&&uiMoney(ECO.plant);
}
// une fois : on repasse en économie réaliste (demande de Noa), l'option « Armes libres » reste dans le menu
if(!cfg.ecoV){cfg.eco=1;cfg.ecoV=1;}
