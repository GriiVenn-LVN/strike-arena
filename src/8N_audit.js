/* =====================================================================
   CORRECTIFS DE L'AUDIT (2026-10-14)
   - Points d'apparition / d'errance placés dans un décor (caisse sous
     un toit au Port, haut de mur à l'Entrepôt et au Métro) : déplacés
     automatiquement sur la case libre la plus proche au chargement de
     la carte. Avant, on pouvait réapparaître coincé dans une caisse et
     les bots marchaient vers un mur jusqu'à abandonner.
   ===================================================================== */
function mapPointOk(cx,cz){
 if(cx<0||cz<0||cx>=N||cz>=N||!walkableCell(cz*N+cx))return false;
 const x=cc(cx),z=cc(cz);return !blocked(x,z,groundH(x,z),PR);
}
function mapPointFix(c){
 if(mapPointOk(c[0],c[1]))return;
 for(let r=1;r<8;r++)for(let dz=-r;dz<=r;dz++)for(let dx=-r;dx<=r;dx++){
  if(Math.max(Math.abs(dx),Math.abs(dz))!==r)continue;
  if(mapPointOk(c[0]+dx,c[1]+dz)){c[0]+=dx;c[1]+=dz;return;}
 }
}
const _buildWorldAudit=buildWorld;
buildWorld=function(id){
 const r=_buildWorldAudit(id);
 if(MAP&&!MAP._ptsOk){
  for(const L of ['spawnT','spawnCT','spawnDM','roam','holdCT'])if(MAP[L])for(const c of MAP[L])mapPointFix(c);
  MAP._ptsOk=true;
 }
 return r;
};
