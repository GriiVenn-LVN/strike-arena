/* =====================================================================
   ENCHAÎNEMENT DES PARTIES (façon Arsenal / RIVALS)
   - Vote de carte sur l'écran de fin : 3 cartes, les bots votent aussi,
     « REJOUER » lance la carte gagnante.
   - Bouton « PARTIE RAPIDE » dans Jouer : mode et carte au hasard,
     lancement immédiat.
   - Mode de la semaine : un mode change chaque lundi et rapporte XP ×2.
   ===================================================================== */
const FEATURED_ROT=['duel','gg','koth','rapid','ffa','tdm','br'];
function featuredMode(){
 const d=new Date(),day=Math.floor((Date.UTC(d.getFullYear(),d.getMonth(),d.getDate())/864e5+3)/7); // semaines commençant le lundi
 return FEATURED_ROT[day%FEATURED_ROT.length];
}
// XP doublée sur le mode de la semaine
const _commitMatchFeat=commitMatch;
commitMatch=function(win){
 const r=_commitMatchFeat(win);
 if(G.variant===featuredMode()&&!G.netClient){
  r.ups=r.ups.concat(addXP(r.xp));r.xp*=2;r.feat=true;
  if(PROF.history[0])PROF.history[0].xp=r.xp;saveProf();
 }
 return r;
};
const _showMatchRewardsFeat=showMatchRewards;
showMatchRewards=function(win){
 _showMatchRewardsFeat(win);
 if(G.variant===featuredMode()&&!G.netClient){const b=document.querySelector('#oRew .rewbox');if(b)b.insertAdjacentHTML('afterbegin','<div class="featTag">★ MODE DE LA SEMAINE : XP ×2</div>');}
};
// badge sur la tuile du mode
const _buildModeCardsFeat=buildModeCards;
buildModeCards=function(){
 _buildModeCardsFeat();
 const f=featuredMode(),list=[];for(const [,l] of MODE_GROUPS)for(const k of l)if(MODES[k])list.push(k);
 const i=list.indexOf(f),c=$('modeCards')&&$('modeCards').children[i];
 if(c&&!c.querySelector('.featB'))c.insertAdjacentHTML('beforeend','<i class="featB">XP ×2</i>');
 const ln=$('modeLine');if(ln&&cfg.mode===f)ln.textContent+=' · Mode de la semaine : XP ×2';
};

/* ---------- partie rapide ---------- */
const QUICK_MODES=['tdm','ffa','gg','koth','duel','rapid'];
function quickPlay(){
 initAudio();sfxUI();
 const f=featuredMode(),m=QUICK_MODES.includes(f)&&Math.random()<.4?f:pick(QUICK_MODES);
 cfg.mode=m;cfg.map=pick(mapsFor(m));saveCfg();
 if(typeof previewMapWorld==='function')try{previewMapWorld();}catch(e){}
 drawMenu();uiToast('Partie rapide : '+MODES[m].n+' sur '+MAPS[cfg.map].n);
 startMatch();buildRadarMap();
}
function quickBtnEnsure(){
 const pb=$('playBtn');if(!pb||!pb.parentNode)return;
 let q=$('quickBtn');
 if(!q){q=document.createElement('button');q.id='quickBtn';q.className='btn alt cut';q.innerHTML='⚡ PARTIE RAPIDE <small>mode et carte au hasard</small>';q.onclick=quickPlay;}
 if(q.previousElementSibling!==pb)pb.parentNode.insertBefore(q,pb.nextSibling);
}
const _drawMenuFlow=drawMenu;
drawMenu=function(){_drawMenuFlow();quickBtnEnsure();};

/* ---------- vote de carte ---------- */
const VOTE={opts:[],votes:[],mine:-1,timers:[],on:false};
function voteSetup(){
 VOTE.timers.forEach(clearTimeout);VOTE.timers=[];VOTE.on=false;VOTE.mine=-1;
 let box=$('mapVote');
 if(!box){box=document.createElement('div');box.id='mapVote';const row=document.querySelector('#over .row');row.parentNode.insertBefore(box,row);}
 const all=mapsFor(cfg.mode);
 if(NET.role||all.length<2||G.variant==='train'){box.style.display='none';return;}
 const others=shuffle(all.filter(k=>k!==cfg.map)).slice(0,2);
 VOTE.opts=[cfg.map].concat(others);VOTE.votes=VOTE.opts.map(()=>0);VOTE.on=true;
 box.style.display='';
 box.innerHTML='<h4>VOTE POUR LA PROCHAINE CARTE</h4><div class="mvrow">'+VOTE.opts.map((k,i)=>'<div class="mvc" data-i="'+i+'"><canvas width="120" height="120"></canvas><b>'+MAPS[k].n+(i===0?' <small>(rejouer)</small>':'')+'</b><span class="mvn">0</span><div class="mvbar"><i></i></div></div>').join('')+'</div>';
 box.querySelectorAll('.mvc').forEach((c,i)=>{try{drawMapThumb(c.querySelector('canvas'),VOTE.opts[i]);}catch(e){}c.onclick=()=>voteCast(i);});
 // les bots votent petit à petit
 const bots=ents.filter(e=>!e.isPlayer&&!e.dummy&&!e.zombie).length;
 for(let n=0;n<Math.min(9,bots);n++)VOTE.timers.push(setTimeout(()=>{VOTE.votes[Math.floor(Math.random()*VOTE.opts.length)]++;voteDraw();},600+n*rand(250,600)));
 voteDraw();
}
function voteCast(i){
 if(!VOTE.on)return;sfxUI();
 if(VOTE.mine>=0)VOTE.votes[VOTE.mine]--;
 VOTE.mine=i;VOTE.votes[i]++;voteDraw();
}
function voteWinner(){
 let b=0;for(let i=1;i<VOTE.votes.length;i++)if(VOTE.votes[i]>VOTE.votes[b]||(VOTE.votes[i]===VOTE.votes[b]&&i===VOTE.mine))b=i;
 return VOTE.opts[b];
}
function voteDraw(){
 const box=$('mapVote');if(!box)return;
 const tot=Math.max(1,VOTE.votes.reduce((a,b)=>a+b,0)),win=voteWinner();
 box.querySelectorAll('.mvc').forEach((c,i)=>{
  c.classList.toggle('mine',VOTE.mine===i);c.classList.toggle('lead',VOTE.opts[i]===win&&VOTE.votes[i]>0);
  c.querySelector('.mvn').textContent=VOTE.votes[i]+' vote'+(VOTE.votes[i]>1?'s':'');
  c.querySelector('.mvbar i').style.width=Math.round(VOTE.votes[i]/tot*100)+'%';
 });
 const a=$('again');if(a)a.textContent=VOTE.on?'REJOUER — '+MAPS[win].n.toUpperCase():'REJOUER';
}
const _uiMatchOverFlow=uiMatchOver;
uiMatchOver=function(){_uiMatchOverFlow();try{voteSetup();}catch(e){console.error(e);}};
$('again').onclick=()=>{
 if(VOTE.on){const m=voteWinner();VOTE.timers.forEach(clearTimeout);VOTE.on=false;if(m!==cfg.map){cfg.map=m;saveCfg();}}
 startMatch();buildRadarMap();
};
(function(){const s=document.createElement('style');s.textContent=`
#mapVote{margin-top:16px}
#mapVote h4{font-size:.72rem;letter-spacing:3px;color:#8da0bd;margin-bottom:8px}
#mapVote .mvrow{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:10px}
#mapVote .mvc{background:#0f1726;border:2px solid #ffffff14;border-radius:10px;padding:8px;cursor:pointer;transition:.15s;position:relative}
#mapVote .mvc:hover{transform:translateY(-2px);background:#152036}
#mapVote .mvc.mine{border-color:#4aa3ff}
#mapVote .mvc.lead{box-shadow:0 0 22px -8px #ffd23a}
#mapVote .mvc canvas{width:100%;max-width:120px;aspect-ratio:1;border-radius:6px;display:block;margin:0 auto}
#mapVote .mvc b{display:block;margin-top:6px;font-size:.78rem;letter-spacing:1.5px;text-transform:uppercase}
#mapVote .mvc b small{color:#8da0bd;font-size:.62rem;text-transform:none;letter-spacing:0}
#mapVote .mvn{font-size:.7rem;color:#b8c5da}
#mapVote .mvbar{height:4px;background:#ffffff14;border-radius:2px;margin-top:5px;overflow:hidden}
#mapVote .mvbar i{display:block;height:100%;width:0;background:#ffd23a;transition:width .4s}
#quickBtn{width:100%;margin-top:8px;font-size:1rem;padding:12px}
#quickBtn small{display:block;font-size:.62rem;letter-spacing:2px;opacity:.7;margin-top:2px}
.featB{position:absolute;top:6px;right:6px;font-style:normal;font-size:.58rem;font-weight:900;letter-spacing:1px;background:#ffd23a;color:#111;border-radius:4px;padding:2px 5px}
#modeCards .mcard{position:relative}
.featTag{color:#ffd23a;font-weight:900;letter-spacing:2px;font-size:.78rem;margin-bottom:6px}
`;document.head.appendChild(s);})();
