/* =====================================================================
   ENTRAÎNEMENT SANS LIMITE DE TEMPS
   Le chrono compte le temps passé au lieu de décompter. Dans le menu
   pause, « TERMINER L'ENTRAÎNEMENT » affiche le bilan (score, précision,
   série) et valide les succès, « QUITTER VERS LE MENU » sort directement.
   ===================================================================== */
{
 const row=$('toMenu').parentNode,b=document.createElement('button');
 b.className='btn cut';b.id='trFinish';b.textContent='TERMINER L\'ENTRAÎNEMENT';b.style.display='none';
 row.insertBefore(b,$('toMenu'));
 b.onclick=()=>{if(G.variant!=='train'||!G.running)return;$('pause').classList.remove('show');G.paused=false;trEnd();};
 // le bouton n'apparaît qu'en entraînement (hors tutoriel)
 new MutationObserver(()=>{b.style.display=$('pause').classList.contains('show')&&G.variant==='train'&&G.running&&!(typeof TUT!=='undefined'&&TUT.on)?'':'none';})
  .observe($('pause'),{attributes:true,attributeFilter:['class']});
}
