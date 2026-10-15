/* =====================================================================
   MODE ARME TOURNANTE (façon Call of Duty « Sharpshooter » / Krunker)
   - Chacun pour soi, tout le monde a la MÊME arme.
   - Toutes les 30 s, une nouvelle arme est tirée au sort et remplace
     celle de tous les joueurs (munitions en réserve illimitées).
   - Pas de grenades. Premier au nombre d'éliminations gagne.
   Variante du mode « ffa » : réutilise ses réapparitions et sa fin.
   ===================================================================== */
MODES.shp={n:'Arme tournante',ic:'🎲',c:'#ffa94d',team:false,respawn:2,desc:'Tout le monde a la même arme, tirée au sort toutes les 30 secondes. Adapte-toi vite !',limitLabel:'Éliminations pour gagner',limits:[15,25,35]};
VARIANT_BASE.shp='ffa';
MODE_GROUPS[1][1].push('shp');MODE_TAG.shp='Même arme pour tous, elle change';
if(typeof RTIME!=='undefined')RTIME.shp={l:'Durée de la partie',o:[5,8,10],d:8,u:'min'};
if(typeof QUICK_MODES!=='undefined')QUICK_MODES.push('shp');
const SHP={k:null,t:0,every:30,last:[]};
const isShp=()=>G.variant==='shp';
const SHP_CATS=['pistol','smg','shotgun','rifle','sniper','lmg'];
function shpPool(){return Object.keys(W).filter(k=>{const w=W[k];return w&&!w.wonder&&!w.melee&&w.slot!==2&&w.price>0&&SHP_CATS.includes(w.cat);});}
function shpPick(){
 const pool=shpPool().filter(k=>!SHP.last.includes(k));
 const k=pick(pool.length?pool:shpPool());SHP.last.push(k);if(SHP.last.length>4)SHP.last.shift();return k;
}
function shpEquip(e){
 if(!SHP.k)return;
 e.wp.p=null;e.wp.s=null;giveWeapon(e,SHP.k);
 const sl=W[SHP.k].slot===0?'p':'s';e.wp[sl].res=999;e.cur=sl;e.reload=0;e.switchT=.35;
 e.nade={f:0,fl:0,sm:0,mn:0};
 if(e.isPlayer&&typeof vmDraw==='function')vmDraw();
}
function shpRoll(first){
 SHP.k=shpPick();SHP.t=SHP.every;
 for(const e of ents)if(e.alive)shpEquip(e);
 if(!first){uiBanner('NOUVELLE ARME',W[SHP.k].n,1500,'#ffa94d');sfx('draw');}
}
function shpHud(){
 let el=$('shpHud');if(!el){el=document.createElement('div');el.id='shpHud';$('hud').appendChild(el);}
 el.style.display='';
 const s=Math.ceil(SHP.t),warn=s<=5&&G.state==='live';
 el.innerHTML='🎲 '+(SHP.k?W[SHP.k].n.toUpperCase():'—')+'<small class="'+(warn?'w':'')+'">nouvelle arme dans '+s+' s</small>';
}
const _variantInitShp=variantInit;
variantInit=function(){
 SHP.k=null;SHP.last=[];
 _variantInitShp();
 const h=$('shpHud');if(h)h.style.display=isShp()?'':'none';
 if(!isShp())return;
 G.limit=limitOf('shp');shpRoll(true);
};
const _dmLoadoutShp=dmLoadout;
dmLoadout=function(e){if(isShp()&&SHP.k)return shpEquip(e);return _dmLoadoutShp(e);};
const _variantUpdateShp=variantUpdate;
variantUpdate=function(dt,t){
 _variantUpdateShp(dt,t);
 if(!isShp())return;
 if(G.state==='live'){SHP.t-=dt;if(SHP.t<=0)shpRoll(false);}
 // l'arme du tour reste la seule : pas de ramassage ni d'achat d'une autre
 if(SHP.k)for(const e of ents){if(!e.alive)continue;const sl=W[SHP.k].slot===0?'p':'s',o=sl==='p'?'s':'p';if(e.wp[o]){e.wp[o]=null;if(e.cur===o){e.cur=sl;if(e.isPlayer&&typeof vmDraw==='function')vmDraw();}}const wi=e.wp[sl];if(wi&&wi.res<200)wi.res=999;}
 shpHud();
};
const _variantSubShp=variantSub;
variantSub=function(){return isShp()?'Même arme pour tous, elle change toutes les 30 s — premier à '+G.limit:_variantSubShp();};
const _variantCleanupShp=variantCleanup;
variantCleanup=function(){_variantCleanupShp();const h=$('shpHud');if(h)h.style.display='none';};
(function(){const s=document.createElement('style');s.textContent=`
#shpHud{position:absolute;top:86px;left:50%;transform:translateX(-50%);text-align:center;pointer-events:none;font:900 .9rem Bahnschrift,Arial;letter-spacing:2px;color:#ffa94d;text-shadow:0 1px 4px #000}
#shpHud small{display:block;font:700 .66rem Bahnschrift,Arial;letter-spacing:1.5px;color:#dfe6f2;margin-top:2px}
#shpHud small.w{color:#ff6b6b}
`;document.head.appendChild(s);})();
