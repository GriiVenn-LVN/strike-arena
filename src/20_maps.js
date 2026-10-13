/* =====================================================================
   CARTES : "Village" (désert) et "Entrepôt" (industriel)
   ===================================================================== */
const MAPS={};
const MAPDATA={};
let MAP=null;

/* ---------- Carte 1 : Village ---------- */
MAPS.village={
 id:'village',n:'Village',theme:'sand',
 desc:'Un village ocre avec toits-terrasses, ruelles étroites, un grand couloir ouvert côté A, un souk couvert côté B et des nids de sniper en hauteur.',
 build(){
  const R=GB.rect,T=TY;
  R(T.WALL,0,0,39,0);R(T.WALL,0,39,39,39);R(T.WALL,0,0,0,39);R(T.WALL,39,0,39,39);
  // salle CT
  R(T.WALL,13,1,13,2);R(T.WALL,13,5,13,10);R(T.WALL,26,1,26,2);R(T.WALL,26,5,26,10);
  R(T.WALL,13,9,20,10);R(T.WALL,23,9,26,10);
  R(T.CRATE,17,6,17,6);R(T.LOW,22,6,23,6);R(T.BARREL,15,6,15,6);
  // site A (nord-ouest)
  R(T.WALL,1,11,1,12);R(T.WALL,6,11,8,12);R(T.WALL,11,11,13,12);
  R(T.PLAT,2,1,5,2,2.4);GB.ramp(6,1,8,2,'x',2.4,0);
  R(T.LOW,4,6,5,6);R(T.LOW,7,4,7,5);R(T.CRATE,8,8,8,8);R(T.CRATE,9,8,9,8,);R(T.BARREL,2,9,3,9);R(T.BARREL,10,3,10,3);R(T.BARREL,2,5,2,5);
  // site B (nord-est)
  R(T.WALL,26,11,28,12);R(T.WALL,31,11,31,12);R(T.WALL,36,11,38,12);
  GB.ceil(31,1,35,4,3.4);R(T.PILLAR,33,3,33,3,3.4);
  R(T.CRATE,29,5,29,6);R(T.CRATE,30,6,30,6);R(T.CRATE,36,7,37,7);R(T.CRATE,37,8,37,8);
  R(T.BARREL,28,9,28,9);R(T.BARREL,38,9,38,9);R(T.BARREL,31,8,31,8);R(T.LOW,33,8,34,8);
  // moyeu central
  R(T.HOUSE,18,16,21,20);
  R(T.PLAT,14,11,16,13,3.0);GB.ramp(17,11,19,12,'x',3.0,0);
  R(T.PLAT,26,13,28,15,3.0);GB.ramp(23,13,25,14,'x',0,3.0);
  R(T.CRATE,15,24,16,24);R(T.LOW,23,22,24,22);R(T.BARREL,14,26,14,26);R(T.BARREL,25,25,25,25);R(T.BARREL,17,26,17,26);
  R(T.CRATE,22,26,23,26);R(T.LOW,15,18,15,19);R(T.LOW,24,17,24,18);R(T.CRATE,16,14,16,14);
  // bloc de maisons ouest (+ ruelle, portes, terrasse)
  R(T.HOUSE,7,13,13,28);GB.clear(9,13,10,27);GB.clear(7,20,8,21);GB.clear(11,17,13,18);
  R(T.PLAT,7,23,8,26,2.4);GB.ramp(5,24,6,25,'x',0,2.4);
  R(T.CRATE,10,26,10,26);R(T.BARREL,9,15,9,15);R(T.LOW,10,22,10,22);
  // grand couloir ouest
  R(T.LOW,3,16,4,16);R(T.CRATE,2,19,2,20);R(T.BARREL,5,22,5,22);R(T.LOW,3,26,4,26);R(T.CRATE,1,14,1,14);R(T.LOW,5,17,5,17);R(T.BARREL,2,24,2,24);
  // bloc de maisons est (+ rue, portes, tunnel)
  R(T.HOUSE,26,13,32,28);R(T.PLAT,26,13,28,15,3.0);GB.ramp(23,13,25,14,'x',0,3.0);
  GB.clear(29,13,30,28);GB.clear(26,22,28,23);GB.clear(31,19,32,20);
  GB.ceil(33,17,38,24,3.4);R(T.PILLAR,35,20,35,20,3.4);
  R(T.CRATE,34,14,34,14);R(T.LOW,36,15,37,15);R(T.BARREL,38,27,38,27);R(T.CRATE,33,26,34,26);R(T.LOW,36,22,36,22);R(T.BARREL,29,26,29,26);R(T.CRATE,30,16,30,16);
  // rangée sud
  R(T.WALL,1,29,1,30);R(T.WALL,6,29,13,30);R(T.WALL,14,29,18,30);R(T.WALL,21,29,26,30);R(T.WALL,27,29,28,30);R(T.WALL,31,29,32,30);R(T.WALL,37,29,38,30);
  // salle T + cours
  R(T.WALL,13,31,13,34);R(T.WALL,13,37,13,38);R(T.WALL,26,31,26,34);R(T.WALL,26,37,26,38);
  R(T.CRATE,18,33,18,34);R(T.CRATE,21,33,21,34);R(T.BARREL,15,36,15,36);R(T.LOW,23,37,24,37);
  R(T.CRATE,3,34,4,34);R(T.CRATE,9,32,9,33);R(T.BARREL,6,36,6,36);R(T.LOW,10,36,11,36);R(T.BARREL,2,31,2,31);
  R(T.CRATE,29,34,30,34);R(T.BARREL,35,32,35,32);R(T.LOW,32,36,33,36);R(T.CRATE,37,35,37,36);R(T.BARREL,28,32,28,32);
  // zones de sol
  GB.tag(14,11,25,28,1);GB.tag(1,1,12,10,2);GB.tag(27,1,38,10,2);GB.tag(14,1,25,8,3);GB.tag(14,31,25,38,4);
  GB.tag(33,17,38,24,5);GB.tag(31,1,35,4,5);
 },
 sites:[{n:'A',cx:6,cz:5,r:7},{n:'B',cx:33,cz:6,r:7}],
 spawnCT:[[15,2],[17,2],[19,2],[21,2],[23,2],[24,3],[16,4],[18,4],[20,4],[22,4]],
 spawnT:[[15,37],[17,37],[19,37],[21,37],[23,37],[24,36],[16,35],[20,36],[22,35],[18,36]],
 pickups:[[6,7,'shield'],[33,7,'health'],[20,25,'shield'],[4,20,'health'],[36,21,'shield'],[16,12,'ammo'],[24,12,'health'],[9,34,'shield'],[31,34,'health'],[20,6,'ammo'],[10,18,'shield']],
 spawnDM:[[6,5],[33,5],[3,20],[36,20],[16,22],[24,24],[10,18],[30,18],[6,34],[32,34],[20,12],[3,2],[15,12],[27,14],[9,33],[34,28]],
 holdCT:[[5,7],[34,7],[21,12],[3,2],[15,12],[9,6],[36,8],[27,14]],
 roam:[[6,5],[33,5],[4,20],[36,20],[15,12],[24,13],[22,22],[16,25],[9,18],[30,18],[6,34],[32,34],[20,10],[3,2],[27,14],[5,26],[35,26],[20,24],[18,32],[10,7],[34,8]],
 arches:[[21,9,2,2,5.25,6],[2,11,4,2,5.25,6],[9,11,2,2,5.25,6],[29,11,2,2,5.25,6],[32,11,4,2,5.25,6],[13,3,1,2,5.25,6],[26,3,1,2,5.25,6],
  [7,20,2,2,3.6,4.6],[11,17,3,2,3.6,4.6],[26,22,3,2,3.6,4.6],[31,19,2,2,3.6,4.6],[2,29,4,2,5.25,6],[19,29,2,2,5.25,6],[29,29,2,2,5.25,6],[33,29,4,2,5.25,6],[13,35,1,2,5.25,6],[26,35,1,2,5.25,6]]
};

/* ---------- Carte 2 : Entrepôt ---------- */
MAPS.warehouse={
 id:'warehouse',n:'Entrepôt',theme:'industrial',
 desc:'Un dépôt logistique : grande halle de conteneurs, mezzanines, zone de stockage ouest (A) et salle de contrôle sur plateforme à l\'est (B).',
 build(){
  const R=GB.rect,T=TY,K=T.CONC;
  R(K,0,0,39,0);R(K,0,39,39,39);R(K,0,0,0,39);R(K,39,0,39,39);
  // bureaux CT
  R(K,13,1,13,2);R(K,13,5,13,10);R(K,26,1,26,2);R(K,26,5,26,10);R(K,13,9,18,10);R(K,21,9,26,10);
  R(T.LOW,16,5,17,5);R(T.LOW,22,5,23,5);R(T.CRATE,15,7,15,7);
  // salles supérieures (ouest / est)
  R(K,5,11,12,12);R(K,27,11,33,12);
  R(T.LOW,3,4,6,4);R(T.LOW,3,7,6,7);R(T.CRATE,10,8,10,8);R(T.BARREL,2,9,2,9);
  R(T.LOW,29,4,32,4);R(T.LOW,29,7,32,7);R(T.CRATE,36,3,36,3);R(T.BARREL,37,9,37,9);R(T.CRATE,28,9,28,9);
  // halle centrale : murs et portes
  R(K,10,11,11,30);GB.clear(10,16,11,18);GB.clear(10,24,11,25);
  R(K,28,11,29,30);GB.clear(28,14,29,16);GB.clear(28,23,29,24);
  // mezzanines nord de la halle
  R(T.PLAT,12,11,18,12,3.2);R(T.PLAT,21,11,27,12,3.2);
  GB.ramp(12,13,13,15,'z',3.2,0);GB.ramp(26,13,27,15,'z',3.2,0);
  R(T.CRATE,15,11,15,11,3.2+1.2);R(T.CRATE,24,11,24,11,3.2+1.2);
  // conteneurs
  R(T.CONT,13,17,14,22);R(T.CONT,17,14,18,19,5.4);R(T.CONT,21,17,22,22);R(T.CONT,24,18,27,19);
  R(T.CONT,15,25,20,26);R(T.CONT,23,25,26,26);R(T.CRATE,16,22,16,22);R(T.BARREL,12,24,12,24);R(T.BARREL,27,28,27,28);R(T.CRATE,19,29,20,29);R(T.BARREL,12,13,12,13);
  // rangée sud de la halle (3 passages)
  R(K,12,31,12,32);R(K,16,31,18,32);R(K,21,31,23,32);R(K,27,31,27,32);
  // quai T
  R(K,10,31,11,34);R(K,10,37,11,38);R(K,28,31,29,34);R(K,28,37,29,38);
  R(T.CONT,14,34,16,34);R(T.CONT,23,34,25,34);R(T.CRATE,19,35,20,35);R(T.BARREL,13,37,13,37);R(T.BARREL,26,37,26,37);
  // site A : stockage (rayonnages)
  R(T.CRATE,3,15,3,18);R(T.CRATE,6,15,6,18);R(T.CRATE,3,21,3,24);R(T.CRATE,6,21,6,24);R(T.LOW,8,19,8,20);R(T.BARREL,1,14,1,14);R(T.BARREL,9,14,9,14);R(T.BARREL,9,26,9,26);R(T.CRATE,1,26,2,26);
  GB.ceil(1,27,9,32,3.4);R(T.PILLAR,5,29,5,29,3.4);R(T.CRATE,2,31,2,31);R(T.CRATE,8,28,8,28);R(T.LOW,3,34,5,34);R(T.CRATE,8,36,8,36);R(T.BARREL,2,37,2,37);
  // site B : salle de contrôle (plateforme + rampe)
  R(T.PLAT,34,16,38,21,3.0);GB.ramp(34,22,36,24,'z',3.0,0);
  R(T.CRATE,36,17,37,17,3.0+1.2);R(T.LOW,34,16,34,16,3.0+.9);
  R(T.CRATE,31,15,31,16);R(T.CRATE,31,20,32,20);R(T.BARREL,30,13,30,13);R(T.BARREL,38,13,38,13);R(T.LOW,32,17,32,18);R(T.CRATE,37,26,37,27);R(T.BARREL,31,25,31,25);
  GB.ceil(31,29,38,32,3.4);R(T.PILLAR,34,31,34,31,3.4);R(T.CRATE,37,31,37,31);R(T.LOW,31,34,33,34);R(T.CRATE,36,36,36,36);R(T.BARREL,30,37,30,37);
  // rangée sud de B
  R(K,27,29,30,30);R(K,34,29,38,30);
  // sol
  GB.tag(12,11,27,30,1);GB.tag(14,1,25,8,2);GB.tag(1,1,12,10,2);GB.tag(27,1,38,10,2);GB.tag(1,13,9,26,3);GB.tag(30,11,38,28,4);GB.tag(12,33,27,38,5);GB.tag(1,27,9,38,6);GB.tag(30,31,38,38,6);
 },
 sites:[{n:'A',cx:4,cz:19,r:7},{n:'B',cx:33,cz:15,r:7}],
 spawnCT:[[15,2],[17,2],[19,2],[21,2],[23,2],[24,3],[16,4],[18,4],[20,4],[22,4]],
 spawnT:[[15,37],[17,37],[19,37],[21,37],[23,37],[24,36],[16,36],[20,36],[22,36],[18,36]],
 pickups:[[4,22,'shield'],[33,13,'health'],[20,20,'shield'],[3,6,'health'],[35,6,'shield'],[22,12,'ammo'],[7,34,'health'],[33,34,'shield'],[20,6,'health'],[31,25,'ammo'],[14,28,'shield']],
 spawnDM:[[4,19],[33,15],[3,6],[34,6],[20,22],[14,14],[25,16],[5,34],[34,35],[20,36],[20,6],[36,19],[9,25],[22,29],[13,28],[31,26]],
 holdCT:[[4,20],[32,14],[20,12],[13,11],[36,18],[8,18],[25,12],[3,26]],
 roam:[[4,19],[33,15],[3,6],[34,6],[20,22],[14,14],[25,16],[5,34],[34,35],[20,36],[20,6],[36,19],[9,25],[22,29],[13,28],[31,26],[19,12],[7,30],[35,30],[24,20]],
 arches:[[19,9,2,2,3.6,5.4],[4,11,1,2,3.6,5.4],[13,3,1,2,3.6,5.4],[26,3,1,2,3.6,5.4],[10,16,2,3,3.6,5.4],[10,24,2,2,3.6,5.4],[28,14,2,3,3.6,5.4],[28,23,2,2,3.6,5.4],
  [13,31,3,2,3.6,5.4],[19,31,2,2,3.6,5.4],[24,31,3,2,3.6,5.4],[10,35,2,2,3.6,5.4],[28,35,2,2,3.6,5.4],[34,11,5,2,3.6,5.4]]
};

/* ---------- Carte 3 : Station polaire ---------- */
MAPS.station={
 id:'station',n:'Station polaire',theme:'snow',
 desc:'Un avant-poste de recherche enneigé : base CT sur plateau, hangar à l\'ouest (A), salle des générateurs à l\'est (B), étang gelé au centre, tour de guet et passerelle en hauteur.',
 build(){
  const R=GB.rect,T=TY,K=T.CONC,Wl=T.WALL;
  R(Wl,0,0,39,0);R(Wl,0,39,39,39);R(Wl,0,0,0,39);R(Wl,39,0,39,39);
  // plateau de la base CT
  R(T.PLAT,14,1,25,6,1.5);
  R(K,13,1,13,2);R(K,13,5,13,8);R(K,26,1,26,2);R(K,26,5,26,8);
  R(T.LOW,14,7,18,7,2.4);R(T.LOW,21,7,25,7,2.4);
  R(T.CRATE,17,3,17,3,1.5+1.3);R(T.CRATE,22,3,22,3,1.5+1.3);R(T.LOW,19,2,20,2,1.5+.9);
  GB.ramp(19,7,20,9,'z',1.5,0);GB.ramp(11,3,13,4,'x',0,1.5);GB.ramp(26,3,28,4,'x',1.5,0);
  // aile ouest : hangar (site A)
  R(Wl,11,1,12,2);R(Wl,11,5,12,12);
  R(K,1,13,1,14);R(K,5,13,7,14);R(K,10,13,12,14);
  R(T.CONT,2,2,5,3);R(T.CONT,8,2,9,5);R(T.LOW,3,6,5,6);R(T.CRATE,2,10,3,10);R(T.BARREL,9,9,9,9);R(T.BARREL,10,12,10,12);R(T.CRATE,6,11,6,11);
  R(T.PLAT,1,8,3,11,2.4);GB.ramp(4,9,6,10,'x',2.4,0);R(T.LOW,1,8,1,8,2.4+.9);
  // aile est : générateurs (site B)
  R(Wl,27,1,28,2);R(Wl,27,5,28,12);
  R(K,27,13,28,14);R(K,31,13,33,14);R(K,37,13,38,14);
  GB.ceil(33,1,38,5,3.4);R(T.CONT,34,2,35,3);R(T.PILLAR,37,4,37,4,3.4);R(T.BARREL,36,2,36,2);R(T.BARREL,38,2,38,2);
  R(T.PLAT,36,7,38,10,3.0);GB.ramp(33,8,35,9,'x',0,3.0);R(T.CRATE,37,8,37,8,3.0+1.3);
  R(T.LOW,30,7,30,8);R(T.BARREL,29,11,29,11);R(T.BARREL,29,6,29,6);R(T.CRATE,31,11,31,11);R(T.LOW,32,5,32,5);
  // cour centrale : cabanes, murs de séparation et portes
  R(T.HOUSE,12,15,15,19);R(T.HOUSE,24,15,27,19);R(T.HOUSE,12,26,15,30);R(T.HOUSE,24,26,27,30);
  R(Wl,11,15,11,30);GB.clear(11,21,11,23);R(Wl,28,15,28,30);GB.clear(28,21,28,23);
  R(T.CONT,18,21,21,22);R(T.CRATE,16,17,16,17);R(T.CRATE,23,28,23,28);R(T.LOW,17,25,19,25);R(T.LOW,21,18,23,18);R(T.BARREL,14,23,14,23);R(T.BARREL,25,23,25,23);R(T.LOW,16,28,17,28);R(T.CRATE,21,16,22,16);
  // sentier ouest + tour de guet
  R(T.PLAT,1,16,3,18,3.0);GB.ramp(4,16,6,17,'x',3.0,0);
  R(T.LOW,5,20,5,22);R(T.CRATE,2,22,3,22);R(T.BARREL,8,25,8,25);R(T.LOW,4,26,6,26);R(T.CRATE,9,17,9,17);R(T.LOW,8,29,9,29);R(T.BARREL,2,28,2,28);
  // sentier est + tunnel couvert
  GB.ceil(31,20,38,26,3.4);R(T.PILLAR,34,23,34,23,3.4);R(T.CONT,36,16,37,17);R(T.LOW,31,17,32,17);R(T.CRATE,35,28,36,28);R(T.BARREL,30,19,30,19);R(T.LOW,36,22,36,22);R(T.CRATE,31,24,31,24);R(T.BARREL,38,26,38,26);
  // rangée sud de la cour
  R(K,11,31,13,32);R(K,16,31,18,32);R(K,21,31,23,32);R(K,26,31,28,32);
  // camp T
  R(K,13,33,13,34);R(K,13,37,13,38);R(K,26,33,26,34);R(K,26,37,26,38);
  R(T.CONT,16,34,17,34);R(T.CONT,22,34,23,34);R(T.CRATE,19,35,20,35);R(T.BARREL,15,37,15,37);R(T.BARREL,24,37,24,37);
  // cours sud
  R(T.CRATE,3,34,4,34);R(T.LOW,7,36,9,36);R(T.BARREL,2,31,2,31);R(T.CRATE,9,32,9,33);R(T.CRATE,29,34,30,34);R(T.LOW,33,36,35,36);R(T.BARREL,36,32,36,32);R(T.CRATE,38,35,38,36);
  GB.tag(14,1,25,6,4);GB.tag(1,1,10,12,3);GB.tag(29,1,38,12,3);GB.tag(16,19,23,25,2);GB.tag(14,33,25,38,5);GB.tag(31,20,38,26,1);GB.tag(11,15,28,30,0);
 },
 sites:[{n:'A',cx:6,cz:7,r:7},{n:'B',cx:32,cz:8,r:7}],
 pickups:[[6,8,'shield'],[32,9,'health'],[19,18,'shield'],[5,20,'health'],[35,22,'shield'],[18,13,'ammo'],[22,24,'health'],[7,34,'shield'],[32,34,'health'],[20,5,'ammo'],[8,16,'shield']],
 spawnCT:[[15,2],[17,2],[19,3],[21,2],[23,2],[24,3],[16,5],[18,5],[22,5],[20,4]],
 spawnT:[[15,37],[17,37],[19,37],[21,37],[23,37],[24,36],[16,36],[20,36],[22,36],[18,36]],
 spawnDM:[[6,7],[32,8],[5,20],[35,22],[19,18],[22,24],[8,17],[31,17],[7,34],[33,34],[20,5],[2,5],[2,17],[37,8],[16,28],[24,16]],
 holdCT:[[6,9],[31,9],[19,12],[2,9],[37,8],[9,5],[30,6],[20,15]],
 roam:[[6,7],[32,8],[5,20],[35,22],[19,18],[22,24],[8,17],[31,17],[7,34],[33,34],[20,5],[2,17],[37,8],[16,28],[24,16],[4,26],[34,28],[19,12],[10,5],[30,5]],
 arches:[[11,21,1,3,4.2,5.4],[28,21,1,3,4.2,5.4],[14,31,2,2,3.8,5.4],[19,31,2,2,3.8,5.4],[24,31,2,2,3.8,5.4],[2,13,3,2,3.8,5.4],[8,13,2,2,3.8,5.4],[29,13,2,2,3.8,5.4],[34,13,3,2,3.8,5.4],[13,35,1,2,3.8,5.4],[26,35,1,2,3.8,5.4]]
};
MAPS.station.post=function(){
 GB.clear(2,13,4,14);GB.clear(8,13,9,14);GB.clear(29,13,30,14);GB.clear(34,13,36,14);
 GB.clear(14,31,15,32);GB.clear(19,31,20,32);GB.clear(24,31,25,32);GB.clear(13,35,13,36);GB.clear(26,35,26,36);
};

/* correctifs : l'Entrepôt a des passages sud différents ; on les ajuste après construction */
MAPS.warehouse.post=function(){
 // passages dans la rangée sud de B
 GB.clear(31,29,33,30);
 // ouverture entre quai T et cours
 GB.clear(10,35,11,36);GB.clear(28,35,29,36);
 // ouverture haute salle ouest -> site A
 GB.clear(1,11,4,12);
 // ouverture haute salle est -> site B
 GB.clear(34,11,38,12);
};
MAPS.village.post=function(){
 GB.clear(2,11,5,12);GB.clear(9,11,10,12);GB.clear(29,11,30,12);GB.clear(32,11,35,12);
 GB.clear(2,29,5,30);GB.clear(19,29,20,30);GB.clear(29,29,30,30);GB.clear(33,29,36,30);
 GB.clear(13,3,13,4);GB.clear(26,3,26,4);GB.clear(21,9,22,10);GB.clear(13,35,13,36);GB.clear(26,35,26,36);
};

function buildMapSnapshot(id){
 resetGrid();const m=MAPS[id];m.build();if(m.post)m.post();
 MAPDATA[id]={type:G_TYPE.slice(),h:G_H.slice(),ceil:G_CEIL.slice(),ramp:G_RAMP.slice(),tag:G_TAG.slice(),ramps:RAMPS.map(r=>Object.assign({},r))};
}
function loadMap(id){
 const d=MAPDATA[id];G_TYPE.set(d.type);G_H.set(d.h);G_CEIL.set(d.ceil);G_RAMP.set(d.ramp);G_TAG.set(d.tag);RAMPS=d.ramps.map(r=>Object.assign({},r));
 computeNodeHeights();MAP=MAPS[id];
 MAP.base=(typeof THEMES!=='undefined'&&THEMES[MAP.theme]&&THEMES[MAP.theme].base)||MAP.theme;
 if(!MAP.koth)MAP.koth=[[20,20,5]].concat(MAP.sites.map(s=>[s.cx,s.cz,5]));
 for(const s of MAP.sites){s.x=cc(s.cx);s.z=cc(s.cz);s.rw=s.r;}
}
Object.keys(MAPS).forEach(buildMapSnapshot);

/* ---------- outils de validation / aperçu ---------- */
function mapAscii(){
 const ch=['.','#','x','H','l','o','P','C','K','|'];let out='';
 for(let z=0;z<N;z++){let l='';for(let x=0;x<N;x++){const i=z*N+x;let c=ch[G_TYPE[i]];if(G_RAMP[i])c=G_RAMP[i]>0?'/':c;else if(G_CEIL[i]<90&&G_TYPE[i]===0)c=',';l+=c;}out+=l+'\n';}
 return out;
}
// accessibilité (BFS sur la même logique que l'A*)
function reach(fromCell){
 const seen=new Uint8Array(NC),q=[fromCell];seen[fromCell]=1;
 while(q.length){
  const c=q.shift(),cx=c%N,cz=(c/N)|0;
  for(let k=0;k<8;k++){
   const nx=cx+NB[k][0],nz=cz+NB[k][1];if(nx<0||nz<0||nx>=N||nz>=N)continue;
   const ni=nz*N+nx;if(seen[ni])continue;
   const diag=NB[k][0]!==0&&NB[k][1]!==0;
   if(edgeCost(c,ni,diag)<0)continue;
   if(diag&&(edgeCost(c,cz*N+nx,false)<0||edgeCost(c,nz*N+cx,false)<0))continue;
   seen[ni]=1;q.push(ni);
  }
 }
 return seen;
}
function validateMap(id){
 loadMap(id);const m=MAPS[id],rep=[];
 const a=reach(nearestFree(m.spawnT[0][0],m.spawnT[0][1]).reduce((x,z)=>0,0)||0);
 return rep;
}
function mapReport(id){
 loadMap(id);const m=MAPS[id],o=[];
 const from=nearestFree(m.spawnT[0][0],m.spawnT[0][1]),r=reach(from[1]*N+from[0]);
 const chk=(n,c)=>{const f=nearestFree(c[0],c[1]);o.push(n+' '+(r[f[1]*N+f[0]]?'OK':'INACCESSIBLE')+' @'+c);};
 m.spawnCT.forEach((c,i)=>chk('CT'+i,c));m.spawnT.forEach((c,i)=>chk('T'+i,c));
 m.sites.forEach(s=>chk('site'+s.n,[s.cx,s.cz]));m.holdCT.forEach((c,i)=>chk('hold'+i,c));m.roam.forEach((c,i)=>chk('roam'+i,c));m.spawnDM.forEach((c,i)=>chk('dm'+i,c));
 // lignes de vue directes CT/T
 let los=0,tot=0;
 for(const a of m.spawnCT)for(const b of m.spawnT){tot++;if(losClear(cc(a[0]),1.6+groundH(cc(a[0]),cc(a[1])),cc(a[1]),cc(b[0]),1.6,cc(b[1]),true))los++;}
 o.push('LOS spawn CT<->T: '+los+'/'+tot);
 return o.filter(s=>!/ OK /.test(s)).join('\n');
}
// miniature de carte (menu)
function drawMapThumb(cv,id){
 const d=MAPDATA[id],c=cv.getContext('2d'),W=cv.width,sc=W/N;
 const TH0={night:{bg:'#1a2438',w:'#5a6a86',h:'#3a4a6a',x:'#d39a2b',l:'#6a7a96',p:'#4a6a9a',g:'#4a6a9a'},metro:{bg:'#3a3f47',w:'#9aa4b4',h:'#7a8494',x:'#c9a23a',l:'#7a8494',p:'#6a8ab0',g:'#6a8ab0'},jungle:{bg:'#4a7a3a',w:'#8a9a7a',h:'#7a8a6a',x:'#6a7a5a',l:'#9aa48a',p:'#c9b070',g:'#c9b070'},range:{bg:'#7a8088',w:'#cfd5dd',h:'#8d97a6',x:'#d39a2b',l:'#8d97a6',p:'#6e8fb5',g:'#6e8fb5'}};
 const th=TH0[MAPS[id].theme]||{snow:{bg:'#e8eef6',w:'#7f8998',h:'#8a5a38',x:'#6f7a8a',l:'#ffffff',p:'#b08a5a',g:'#b08a5a'},sand:{bg:'#c9b18a',w:'#f0e6cc',h:'#c56a3e',x:'#8c6a3a',l:'#a89b78',p:'#e0c070',g:'#e8c97a'},industrial:{bg:'#566070',w:'#cfd5dd',h:'#8d97a6',x:'#d39a2b',l:'#8d97a6',p:'#6e8fb5',g:'#7fa6d0'}}[MAPS[id].theme];
 c.fillStyle=th.bg;c.fillRect(0,0,W,W);
 for(let z=0;z<N;z++)for(let x=0;x<N;x++){
  const i=z*N+x,t=d.type[i];
  if(d.ramp[i]){c.fillStyle='#d9b45a';c.fillRect(x*sc,z*sc,sc+.5,sc+.5);continue;}
  if(d.ceil[i]<90){c.fillStyle='rgba(0,0,0,.18)';c.fillRect(x*sc,z*sc,sc+.5,sc+.5);}
  if(t===0)continue;
  c.fillStyle=t===1||t===8?th.w:t===3||t===7?th.h:t===2||t===9?th.x:t===4||t===5?th.l:t===6?th.p:th.w;
  c.fillRect(x*sc,z*sc,sc+.5,sc+.5);
 }
 const m=MAPS[id];
 c.font='bold '+(sc*4.5)+'px Arial';c.textAlign='center';c.textBaseline='middle';
 for(const s of m.sites){c.beginPath();c.arc((s.cx+.5)*sc,(s.cz+.5)*sc,s.r/2*sc,0,TAU);c.strokeStyle='rgba(255,70,85,.9)';c.lineWidth=2;c.stroke();c.fillStyle='rgba(255,70,85,.95)';c.fillText(s.n,(s.cx+.5)*sc,(s.cz+.5)*sc);}
 c.font='bold '+(sc*2.4)+'px Arial';
 c.fillStyle='#4aa3ff';c.fillText('CT',20*sc,5*sc);c.fillStyle='#ff7a4a';c.fillText('T',20*sc,36*sc);
}
