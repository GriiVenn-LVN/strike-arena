/* =====================================================================
   CARTES SUPPLÉMENTAIRES : Port de nuit, Métro, Temple (jungle), Stand de tir
   ===================================================================== */
const STD_CT=[[15,2],[17,2],[19,2],[21,2],[23,2],[24,3],[16,4],[18,4],[20,4],[22,4]];
const STD_T=[[15,37],[17,37],[19,37],[21,37],[23,37],[24,36],[16,36],[20,36],[22,36],[18,36]];

/* ---------- Port de nuit ---------- */
MAPS.harbor={
 id:'harbor',n:'Port de nuit',theme:'night',
 desc:'Un port industriel éclairé aux projecteurs : piles de conteneurs, grutier en hauteur, entrepôt couvert à l\'est (B) et quai ouvert à l\'ouest (A).',
 build(){
  const R=GB.rect,T=TY,K=T.CONC;
  R(K,0,0,39,0);R(K,0,39,39,39);R(K,0,0,0,39);R(K,39,0,39,39);
  // base CT
  R(K,13,1,13,2);R(K,13,5,13,8);R(K,26,1,26,2);R(K,26,5,26,8);R(K,13,7,15,8);R(K,18,7,21,8);R(K,24,7,26,8);
  R(T.CRATE,15,3,15,3);R(T.CRATE,24,4,24,4);R(T.LOW,19,5,20,5);
  // site A : quai
  R(K,1,11,3,12);R(K,8,11,12,12);R(K,13,9,13,12);
  R(T.CONT,2,2,5,3);R(T.PLAT,2,5,5,8,2.7);GB.ramp(6,6,8,7,'x',2.7,0);
  R(T.CRATE,9,3,9,4);R(T.BARREL,10,8,10,8);R(T.CRATE,7,10,7,10);R(T.BARREL,11,5,11,5);R(T.LOW,3,10,5,10);
  // site B : entrepôt
  R(K,26,11,29,12);R(K,34,11,38,12);R(K,26,9,26,12);
  GB.ceil(28,1,38,8,3.6);R(T.CRATE,30,2,30,5);R(T.CRATE,33,2,33,5);R(T.CRATE,36,2,36,5);R(T.BARREL,29,7,29,7);R(T.CRATE,35,8,36,8);
  R(T.LOW,31,9,32,9);R(T.BARREL,37,10,37,10);
  // milieu
  R(T.CONT,15,13,16,18);R(T.CONT,23,13,24,18);R(T.CONT,18,21,21,22);R(T.CRATE,19,16,20,16);R(T.BARREL,14,24,14,24);R(T.CRATE,24,25,25,25);R(T.LOW,16,26,18,26);R(T.CRATE,21,26,21,27);
  R(T.PLAT,23,10,25,12,2.7);GB.ramp(21,10,22,11,'x',0,2.7);
  // couloirs ouest / est
  R(K,9,13,13,28);GB.clear(9,19,13,20);GB.clear(9,24,13,25);
  R(K,26,13,30,28);GB.clear(26,19,30,20);GB.clear(26,24,30,25);
  R(T.CONT,2,16,3,21);R(T.CRATE,5,15,6,15);R(T.LOW,5,22,6,22);R(T.BARREL,7,19,7,19);R(T.CRATE,2,25,3,25);R(T.LOW,6,27,7,27);
  GB.ceil(31,20,38,26,3.4);R(T.PILLAR,34,23,34,23,3.4);R(T.CONT,36,14,37,17);R(T.CRATE,31,15,32,15);R(T.LOW,33,18,33,18);R(T.BARREL,38,28,38,28);R(T.CRATE,34,27,35,27);
  // rangée sud + base T + cours
  R(K,1,29,1,30);R(K,6,29,18,30);R(K,21,29,32,30);R(K,37,29,38,30);
  R(K,13,31,13,34);R(K,13,37,13,38);R(K,26,31,26,34);R(K,26,37,26,38);R(T.CONT,16,34,17,34);R(T.CONT,22,34,23,34);R(T.CRATE,19,35,20,35);
  R(T.CONT,3,33,6,34);R(T.CRATE,9,36,9,36);R(T.BARREL,2,37,2,37);R(T.CRATE,29,33,30,33);R(T.CONT,33,35,36,36);R(T.BARREL,38,32,38,32);
  GB.tag(14,9,25,28,1);GB.tag(14,1,25,6,2);GB.tag(1,1,12,10,3);GB.tag(27,1,38,10,4);GB.tag(14,31,25,38,5);GB.tag(1,13,8,30,6);GB.tag(31,13,38,30,6);
 },
 sites:[{n:'A',cx:7,cz:4,r:7},{n:'B',cx:33,cz:8,r:7}],
 spawnCT:STD_CT,spawnT:STD_T,
 spawnDM:[[7,4],[33,8],[4,20],[35,20],[20,12],[16,24],[22,24],[6,34],[32,34],[3,6],[36,3],[19,19],[24,11],[9,33],[30,30],[12,10]],
 pickups:[[7,6,'shield'],[33,7,'health'],[20,25,'shield'],[4,22,'health'],[35,22,'shield'],[20,10,'ammo'],[24,13,'health'],[8,34,'shield'],[31,34,'health'],[20,5,'ammo']],
 koth:[[20,19,5],[7,5,5],[33,6,5]],
 holdCT:[[7,6],[33,9],[20,12],[3,6],[24,11],[9,6],[36,3],[16,10]],
 roam:[[7,4],[33,8],[4,20],[35,20],[20,12],[16,24],[22,24],[6,34],[32,34],[3,6],[36,3],[19,19],[24,11],[9,33],[30,30],[12,10],[20,26],[5,27],[36,27]],
 arches:[[16,7,2,2,3.6,5.4],[22,7,2,2,3.6,5.4],[4,11,4,2,3.6,5.4],[30,11,4,2,3.6,5.4],[9,19,5,2,3.6,5.4],[9,24,5,2,3.6,5.4],[26,19,5,2,3.6,5.4],[26,24,5,2,3.6,5.4],[2,29,4,2,3.6,5.4],[19,29,2,2,3.6,5.4],[33,29,4,2,3.6,5.4]],
 locName(cx,cz,x,z){
  if(cz<=8)return cx>=13&&cx<=26?'Base CT':cx<13?'Quai A':'Entrepôt B';
  if(cz>=31)return cx>=13&&cx<=26?'Base T':'Cours sud';
  if(groundH(x,z)>2)return 'Grue';
  if(cx<=8)return 'Quai ouest';if(cx>=31)return cz>=20&&cz<=26?'Tunnel de fret':'Quai est';
  return 'Parc à conteneurs';
 }
};

/* ---------- Métro ---------- */
MAPS.metro={
 id:'metro',n:'Métro',theme:'metro',
 desc:'Une station souterraine : salle de contrôle des CT, quais surélevés, rames à l\'arrêt sur les voies et deux grands halls (A à l\'ouest, B à l\'est). Tout est couvert.',
 build(){
  const R=GB.rect,T=TY,K=T.CONC;
  GB.ceil(1,1,38,38,4.4);
  R(K,0,0,39,0);R(K,0,39,39,39);R(K,0,0,0,39);R(K,39,0,39,39);
  // salle de contrôle CT
  R(K,13,1,13,2);R(K,13,5,13,8);R(K,26,1,26,2);R(K,26,5,26,8);R(K,14,8,18,8);R(K,21,8,25,8);GB.ramp(19,8,20,9,'z',0,1.2);
  R(T.LOW,16,4,17,4);R(T.LOW,22,4,23,4);R(T.CRATE,15,6,15,6);
  // quais + voies + rames
  R(T.PLAT,13,10,26,15,1.2);R(T.PLAT,13,23,26,28,1.2);
  GB.ramp(11,11,12,12,'x',0,1.2);GB.ramp(27,11,28,12,'x',1.2,0);GB.ramp(11,24,12,25,'x',0,1.2);GB.ramp(27,24,28,25,'x',1.2,0);GB.ramp(19,29,20,30,'z',1.2,0);
  R(T.PILLAR,17,12,17,12,4.4);R(T.PILLAR,22,12,22,12,4.4);R(T.PILLAR,17,26,17,26,4.4);R(T.PILLAR,22,26,22,26,4.4);
  R(T.CONT,14,18,18,20);R(T.CONT,20,18,24,20);R(T.LOW,15,16,16,16);R(T.LOW,23,22,24,22);
  R(K,13,29,18,30);R(K,21,29,26,30);
  // murs entre station et halls
  R(K,11,9,12,10);R(K,11,13,12,23);R(K,11,26,12,30);R(K,27,9,28,10);R(K,27,13,28,23);R(K,27,26,28,30);
  // hall A (ouest) : hall des billets
  R(T.LOW,3,12,6,12);R(T.LOW,3,26,6,26);R(K,2,16,4,18,3.0);R(T.PILLAR,7,15,7,15,4.4);R(T.PILLAR,7,25,7,25,4.4);R(T.PILLAR,9,20,9,20,4.4);R(T.CRATE,8,12,8,12);R(T.CRATE,2,22,3,22);R(T.BARREL,9,28,9,28);
  R(T.CRATE,3,3,4,3);R(T.BARREL,8,5,8,5);R(T.LOW,6,7,10,7);R(T.CRATE,10,2,10,2);
  R(T.CRATE,3,33,4,33);R(T.LOW,8,35,10,35);R(T.BARREL,2,37,2,37);
  // hall B (est) : quai de service
  R(T.CONT,31,13,32,16);R(T.CONT,35,24,36,27);R(T.PILLAR,31,20,31,20,4.4);R(T.PILLAR,36,20,36,20,4.4);R(T.PILLAR,33,28,33,28,4.4);R(T.CRATE,37,12,37,12);R(T.CRATE,29,22,29,23);R(T.LOW,33,24,34,24);
  R(T.CRATE,30,3,31,3);R(T.CRATE,35,5,36,6);R(T.LOW,28,7,31,7);R(T.BARREL,37,2,37,2);
  R(T.CRATE,35,33,36,33);R(T.LOW,30,35,32,35);R(T.BARREL,38,37,38,37);
  // base T
  R(K,13,31,13,34);R(K,13,37,13,38);R(K,26,31,26,34);R(K,26,37,26,38);R(T.CRATE,17,33,18,33);R(T.CRATE,21,33,22,33);R(T.LOW,15,36,15,36);
  GB.tag(13,10,26,15,1);GB.tag(13,23,26,28,1);GB.tag(14,1,25,8,2);GB.tag(1,1,12,30,3);GB.tag(27,1,38,30,4);GB.tag(14,31,25,38,5);GB.tag(13,16,26,22,6);
 },
 sites:[{n:'A',cx:6,cz:20,r:7},{n:'B',cx:33,cz:20,r:7}],
 spawnCT:STD_CT,spawnT:STD_T,
 spawnDM:[[6,20],[33,20],[5,5],[34,5],[19,12],[19,26],[5,34],[34,34],[20,22],[3,13],[36,13],[8,27],[31,27],[20,5],[20,36],[10,10]],
 pickups:[[6,22,'shield'],[33,22,'health'],[20,12,'shield'],[20,26,'health'],[4,8,'ammo'],[35,8,'shield'],[5,34,'health'],[34,34,'shield'],[20,5,'ammo'],[20,21,'health']],
 koth:[[20,21,5],[6,20,5],[33,20,5]],
 holdCT:[[6,22],[33,22],[19,12],[4,6],[35,6],[22,12],[10,14],[30,14]],
 roam:[[6,20],[33,20],[5,5],[34,5],[19,12],[19,26],[5,34],[34,34],[20,22],[3,13],[36,13],[8,27],[31,27],[20,5],[20,36],[10,10],[28,10],[11,30]],
 arches:[],
 locName(cx,cz,x,z){
  if(cz<=8)return cx>=13&&cx<=26?'Salle de contrôle':cx<13?'Couloir ouest':'Couloir est';
  if(cz>=31)return cx>=13&&cx<=26?'Dépôt':'Accès sud';
  if(cx<=12)return 'Hall des billets';if(cx>=27)return 'Quai de service';
  if(cz>=16&&cz<=22)return 'Voies';
  return cz<16?'Quai nord':'Quai sud';
 }
};

/* ---------- Temple (jungle) ---------- */
MAPS.jungle={
 id:'jungle',n:'Temple perdu',theme:'jungle',
 desc:'Des ruines envahies par la jungle : pyramide à gradins au centre (contrôle du milieu), temple couvert côté B, cour aux colonnes côté A.',
 build(){
  const R=GB.rect,T=TY,K=T.WALL;
  R(K,0,0,39,0);R(K,0,39,39,39);R(K,0,0,0,39);R(K,39,0,39,39);
  // porte du temple CT
  R(K,13,1,13,2);R(K,13,5,13,8);R(K,26,1,26,2);R(K,26,5,26,8);R(K,13,7,18,8);R(K,21,7,26,8);
  R(T.PILLAR,16,3,16,3,3.2);R(T.PILLAR,23,3,23,3,3.2);R(T.LOW,18,5,21,5);
  // ruines A (ouest)
  R(K,1,11,4,12);R(K,9,11,13,12);R(K,13,9,13,12);
  R(T.PLAT,2,2,5,4,1.5);GB.ramp(6,3,7,4,'x',1.5,0);R(T.PILLAR,3,8,3,8,2.5);R(T.PILLAR,8,6,8,6,2.5);R(T.CRATE,9,3,10,3);R(T.LOW,3,6,5,6);R(T.CRATE,10,9,10,9);
  // ruines B (est) : temple couvert
  R(K,26,11,29,12);R(K,34,11,38,12);R(K,26,9,26,12);
  GB.ceil(31,1,38,5,3.8);R(T.PILLAR,34,3,34,3,3.8);R(T.PILLAR,37,3,37,3,3.8);R(T.PLAT,32,1,33,2,1.2);
  R(T.CRATE,29,5,29,6);R(T.LOW,30,8,32,8);R(T.CRATE,36,8,37,8);R(T.PILLAR,28,9,28,9,2.5);
  // pyramide à gradins
  R(T.PLAT,15,14,24,23,1.2);R(T.PLAT,16,15,23,22,2.4);R(T.PLAT,17,16,22,21,3.6);
  GB.ramp(19,12,20,13,'z',0,1.2);GB.ramp(19,14,20,14,'z',1.2,2.4);GB.ramp(19,15,20,15,'z',2.4,3.6);
  GB.ramp(19,22,20,22,'z',3.6,2.4);GB.ramp(19,23,20,23,'z',2.4,1.2);GB.ramp(19,24,20,25,'z',1.2,0);
  GB.ramp(23,18,23,19,'x',3.6,2.4);GB.ramp(24,18,24,19,'x',2.4,1.2);GB.ramp(25,18,26,19,'x',1.2,0);
  GB.ramp(16,18,16,19,'x',2.4,3.6);GB.ramp(15,18,15,19,'x',1.2,2.4);GB.ramp(13,18,14,19,'x',0,1.2);
  // murs en ruine et couverts
  R(K,5,17,8,18);R(K,2,23,6,24);R(K,9,26,12,27);R(K,31,17,34,18);R(K,33,23,37,24);R(K,27,26,30,27);
  R(T.CRATE,3,15,3,15);R(T.LOW,9,20,10,21);R(T.PILLAR,6,29,6,29,2.5);R(T.CRATE,36,14,36,15);R(T.LOW,29,21,30,22);R(T.PILLAR,33,29,33,29,2.5);R(T.CRATE,12,10,12,10);R(T.CRATE,27,10,27,10);
  // rangée sud, camp T, cours
  R(K,1,29,1,30);R(K,6,29,18,30);R(K,21,29,32,30);R(K,37,29,38,30);
  R(K,13,31,13,34);R(K,13,37,13,38);R(K,26,31,26,34);R(K,26,37,26,38);R(T.CRATE,17,33,18,33);R(T.CRATE,21,33,22,33);R(T.LOW,15,36,15,36);
  R(T.CRATE,3,33,4,34);R(T.LOW,8,36,10,36);R(T.CRATE,29,33,30,34);R(T.LOW,33,36,35,36);R(T.PILLAR,2,37,2,37,2.5);R(T.PILLAR,37,37,37,37,2.5);
  GB.tag(15,14,24,23,1);GB.tag(14,1,25,8,2);GB.tag(1,1,12,10,3);GB.tag(27,1,38,10,4);GB.tag(14,31,25,38,5);
 },
 sites:[{n:'A',cx:7,cz:8,r:7},{n:'B',cx:33,cz:8,r:7}],
 spawnCT:STD_CT,spawnT:STD_T,
 spawnDM:[[7,8],[33,8],[4,20],[35,20],[20,19],[11,22],[28,22],[6,34],[32,34],[3,5],[36,4],[20,10],[19,26],[9,14],[30,15],[20,5]],
 pickups:[[7,7,'shield'],[33,7,'health'],[20,19,'shield'],[4,22,'health'],[35,22,'shield'],[20,10,'ammo'],[11,24,'health'],[28,24,'ammo'],[8,34,'shield'],[31,34,'health']],
 koth:[[20,19,5],[7,8,5],[33,8,5]],
 holdCT:[[7,9],[33,9],[20,11],[3,6],[36,6],[11,13],[28,13],[20,10]],
 roam:[[7,8],[33,8],[4,20],[35,20],[20,19],[11,22],[28,22],[6,34],[32,34],[3,5],[36,4],[20,10],[19,26],[9,14],[30,15],[20,5],[12,30],[27,30]],
 arches:[],
 locName(cx,cz,x,z){
  if(cz<=8)return cx>=13&&cx<=26?'Porte du temple':cx<13?'Ruines A':'Temple B';
  if(cz>=31)return cx>=13&&cx<=26?'Camp T':'Cours sud';
  if(groundH(x,z)>3)return 'Sommet de la pyramide';
  if(cx>=15&&cx<=24&&cz>=12&&cz<=25)return 'Pyramide';
  return cx<13?'Jungle ouest':cx>26?'Jungle est':'Esplanade';
 }
};

/* ---------- Stand de tir (entraînement) ---------- */
MAPS.range={
 id:'range',n:'Stand de tir',theme:'range',
 desc:'Terrain d\'entraînement : cibles fixes, mobiles et surgissantes à toutes les distances, nid de sniper et couvertures pour tester armes et skins.',
 build(){
  const R=GB.rect,T=TY,K=T.CONC;
  R(K,0,0,39,0);R(K,0,39,39,39);R(K,0,0,0,39);R(K,39,0,39,39);R(K,1,1,38,2);
  for(const x of [8,16,24,32])R(T.LOW,x,9,x,28);
  R(T.CRATE,5,18,6,18);R(T.CRATE,13,22,14,22);R(T.CRATE,21,14,22,14);R(T.CRATE,29,20,30,20);R(T.BARREL,36,26,36,26);R(T.BARREL,2,12,2,12);
  R(T.PLAT,2,32,6,37,2.4);GB.ramp(7,34,8,35,'x',2.4,0);
  R(T.PLAT,30,33,37,37,1.2);GB.ramp(28,34,29,35,'x',0,1.2);
  R(T.LOW,12,31,27,31);
  GB.tag(1,3,38,30,1);GB.tag(1,32,38,38,3);
 },
 sites:[{n:'A',cx:8,cz:10,r:6},{n:'B',cx:32,cz:10,r:6}],
 spawnCT:[[18,36],[20,36],[22,36],[16,36],[24,36],[14,36],[26,36],[19,34],[21,34],[23,34]],
 spawnT:[[18,36],[20,36],[22,36],[16,36],[24,36],[14,36],[26,36],[19,34],[21,34],[23,34]],
 spawnDM:[[20,36],[10,36],[30,35],[4,34],[18,34]],
 targets:[[4,28,'s'],[12,24,'m'],[20,20,'p'],[28,16,'m'],[36,12,'s'],[4,8,'p'],[12,5,'s'],[20,8,'m'],[28,5,'p'],[36,5,'s'],[20,26,'p'],[12,12,'p']],
 pickups:[[20,32,'ammo'],[10,34,'shield']],
 koth:[[20,20,5]],
 holdCT:[[20,34]],
 roam:[[20,20],[10,10],[30,10],[20,34]],
 arches:[],
 locName(cx,cz,x,z){return cz>=32?'Ligne de tir':cz>=20?'Zone proche':cz>=10?'Zone moyenne':'Longue distance';}
};
['harbor','metro','jungle','range'].forEach(buildMapSnapshot);

/* ---------- Laboratoire abandonné (pensé pour le mode Zombies) ---------- */
MAPS.labo={
 id:'labo',n:'Laboratoire',theme:'night',
 desc:'Un laboratoire abandonné, de nuit : on démarre dans le hall, puis on dégage les débris pour ouvrir la salle des machines, l\'infirmerie et le grand labo. Idéal pour les Zombies.',
 build(){
  const R=GB.rect,T=TY,K=T.CONC;
  R(K,0,0,39,0);R(K,0,39,39,39);R(K,0,0,0,39);R(K,39,0,39,39);
  // hall d'entrée (départ)
  R(K,13,19,13,38);R(K,26,19,26,38);R(K,13,26,26,26);GB.clear(13,31,13,32);GB.clear(26,31,26,32);GB.clear(19,26,20,26);
  GB.ceil(14,27,25,38,4.2);
  R(T.LOW,17,33,22,33);R(T.PILLAR,16,29,16,29,4.2);R(T.PILLAR,23,29,23,29,4.2);R(T.PILLAR,16,36,16,36,4.2);R(T.PILLAR,23,36,23,36,4.2);R(T.CRATE,25,37,25,38);R(T.BARREL,14,37,14,37);
  // couloir vers le grand labo
  R(K,14,19,16,25);R(K,23,19,25,25);GB.ceil(17,20,22,25,3.6);R(T.CRATE,17,22,17,22);R(T.BARREL,22,24,22,24);
  // salle des machines (ouest)
  R(K,0,19,12,19);GB.clear(5,19,6,19);GB.ceil(1,20,12,38,4.6);
  R(T.CONT,2,22,4,25);R(T.CONT,8,22,10,24);R(T.CONT,2,33,5,36);R(T.BARREL,10,30,10,30);R(T.BARREL,11,35,11,35);R(T.LOW,7,28,9,28);R(T.CRATE,9,36,10,37);
  R(T.PLAT,6,32,11,34,2.2);GB.ramp(6,35,7,36,'z',2.2,0);
  // infirmerie (est)
  R(K,27,19,39,19);GB.clear(32,19,33,19);GB.ceil(27,20,38,38,4.2);
  for(const z of [22,26,30,34])R(T.LOW,29,z,31,z);
  R(T.CRATE,37,21,38,22);R(T.CRATE,37,36,38,37);R(T.LOW,35,28,36,30);R(T.BARREL,28,37,28,37);
  // grand labo (nord) : cour centrale à ciel ouvert, plateformes, serveurs
  GB.ceil(1,1,14,18,5);GB.ceil(25,1,38,18,5);
  R(T.CRATE,3,3,3,6);R(T.CRATE,6,3,6,6);R(T.CRATE,9,3,9,6);R(T.CRATE,30,3,30,6);R(T.CRATE,33,3,33,6);R(T.CRATE,36,3,36,6);
  R(T.PLAT,15,2,24,5,2.6);GB.ramp(13,3,14,4,'x',0,2.6);GB.ramp(25,3,26,4,'x',2.6,0);
  R(T.LOW,17,9,22,9);R(T.LOW,17,13,22,13);R(T.PILLAR,15,11,15,11);R(T.PILLAR,24,11,24,11);
  R(T.CONT,4,11,6,15);R(T.CONT,33,11,35,15);R(T.LOW,9,14,11,14);R(T.LOW,28,14,30,14);R(T.BARREL,12,8,12,8);R(T.BARREL,27,8,27,8);
  GB.tag(14,27,25,38,1);GB.tag(1,20,12,38,2);GB.tag(27,20,38,38,3);GB.tag(1,1,38,18,4);GB.tag(17,20,22,25,5);
 },
 sites:[{n:'A',cx:6,cz:28,r:6},{n:'B',cx:33,cz:28,r:6}],
 spawnCT:[[17,30],[19,30],[21,30],[23,31],[18,35],[20,35],[22,35],[15,34],[24,33],[19,28]],
 spawnT:[[8,8],[11,10],[14,7],[19,7],[25,7],[28,10],[31,8],[19,11],[16,15],[23,15]],
 spawnDM:[[19,30],[6,29],[33,29],[19,8],[4,9],[35,9],[19,22],[9,37],[30,37],[19,15],[26,12],[12,12]],
 zdoors:[{cells:[[13,31],[13,32]],price:750},{cells:[[26,31],[26,32]],price:750},{cells:[[19,26],[20,26]],price:1000},{cells:[[5,19],[6,19]],price:1250},{cells:[[32,19],[33,19]],price:1250}],
 pickups:[[19,31,'ammo'],[6,29,'shield'],[33,29,'health'],[19,8,'ammo']],
 koth:[[19,31,4],[6,28,4],[33,28,4],[19,11,5]],
 holdCT:[[6,28],[33,28],[19,30],[8,24],[31,24]],
 roam:[[19,30],[16,34],[23,34],[6,28],[9,31],[3,30],[33,28],[30,24],[36,33],[19,22],[19,8],[8,9],[31,9],[19,15],[12,16],[27,16],[4,17],[35,17],[19,3]],
 arches:[],
 locName(cx,cz,x,z){
  if(cz>=27&&cx>=14&&cx<=25)return 'Hall d\'entrée';
  if(cz>=20&&cx<=12)return 'Salle des machines';
  if(cz>=20&&cx>=27)return 'Infirmerie';
  if(cz>=20)return 'Couloir';
  if(groundH(x,z)>2)return 'Passerelle';
  return cx>=15&&cx<=24&&cz>=6&&cz<=14?'Cour du labo':'Grand labo';
 }
};
buildMapSnapshot('labo');
