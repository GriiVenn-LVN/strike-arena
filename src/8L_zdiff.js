/* =====================================================================
   ZOMBIES : LA DIFFICULTÉ S'APPLIQUE AUX ZOMBIES
   - Avant, les zombies étaient identiques quel que soit le niveau.
   - Maintenant : PV, vitesse, dégâts, cadence des coups et nombre de
     zombies par manche dépendent du niveau choisi.
   - Les bots alliés visent au moins comme en Normal (en Novice ils
     ratent tout et ne servent à rien contre les zombies).
   ===================================================================== */
const ZDIFF=[
 {hp:.6, spd:.78,dmg:.5, atk:1.3, n:.6},  // Novice
 {hp:.8, spd:.88,dmg:.7, atk:1.05,n:.8},  // Facile
 {hp:1,  spd:1,  dmg:1,  atk:.85, n:1},   // Normal (réglage d'origine)
 {hp:1.15,spd:1.05,dmg:1.2,atk:.75,n:1.15},// Pro
 {hp:1.3,spd:1.1,dmg:1.4, atk:.65,n:1.3}  // Légende
];
const zDiff=()=>ZDIFF[clamp(cfg.diff|0,0,ZDIFF.length-1)];
const _zStyleDiff=zStyleZombie;
zStyleZombie=function(z){
 _zStyleDiff(z);
 const d=zDiff();
 z.hp=Math.max(1,Math.round(z.hp*d.hp));z.zspeed*=d.spd;z.zdmg=Math.max(1,Math.round(z.zdmg*d.dmg));z.zatk=d.atk;
};
const _zOnWaveDiff=zOnWave;
zOnWave=function(){
 _zOnWaveDiff();
 Z.queue=Math.max(4,Math.round(Z.queue*zDiff().n));
 for(const e of ents)if(!e.zombie&&!e.isPlayer&&e.team===0)e.diff=DIFFS[Math.max(2,cfg.diff|0)];
};
