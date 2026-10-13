/* =====================================================================
   MENU ÉPURÉ : seules les options principales sont visibles,
   le reste est rangé dans des « Plus d'options » repliés.
   - Réglages › Général : qualité, sensibilité, champ de vision, volume
     (+ effets, FPS, balancement, cinématique, ambiance dans le repli)
   - Le pseudo passe dans Profil › Style ; Crédits en lien dans le pied
   ===================================================================== */
function menuSimplifyCss(){
 if($('menuSimpCss'))return;const s=document.createElement('style');s.id='menuSimpCss';s.textContent=`
#tab-opts .optmain{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:4px 34px;max-width:900px}
#tab-opts details.adv{max-width:900px;margin-top:18px}
#tab-opts details.adv .advgrid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:4px 34px;margin-top:10px}
#tab-opts details.adv small{display:block}
#ambBox .stl{margin-bottom:12px}
#tab-style .pnameRow{max-width:420px;margin-bottom:18px}
#menu .mfoot a{color:#8da0bd;cursor:pointer;text-decoration:underline;margin-left:10px}
#menu .mfoot a:hover{color:#fff}
@media(max-width:900px){#tab-opts .optmain,#tab-opts details.adv .advgrid{grid-template-columns:1fr}}
`;document.head.appendChild(s);
}
function menuSimplify(){
 if($('optMain'))return;
 menuSimplifyCss();
 const grpOf=id=>{const e=$(id);return e?(e.classList.contains('grp')?e:e.closest('.grp')):null;};
 // Réglages › Général
 const tp=$('tab-opts');
 if(tp){
  const main=['cGfx','rSens','rFov','rVol'].map(grpOf),more=['cFx','cFps','cBob','cCine'].map(grpOf);
  const box=document.createElement('div');box.className='optmain';box.id='optMain';main.forEach(g=>g&&box.appendChild(g));
  const adv=document.createElement('details');adv.className='adv';adv.innerHTML='<summary>PLUS D\'OPTIONS</summary><div class="advgrid"><div class="advL"></div><div class="advR" id="ambBox"></div></div>';
  more.forEach(g=>g&&adv.querySelector('.advL').appendChild(g));
  tp.innerHTML='';tp.appendChild(box);tp.appendChild(adv);
  drawAmbiance();
 }
 // pseudo : en tête de Profil › Style
 const pn=grpOf('pname'),st=$('tab-style');
 if(pn&&st){pn.classList.add('pnameRow');st.insertBefore(pn,st.firstChild);}
 // Crédits : simple lien en bas du menu
 const ft=document.querySelector('#menu .mfoot');
 if(ft&&$('tab-credits')){const a=document.createElement('a');a.textContent='Crédits';a.onclick=()=>{sfxUI();navGroup='options';navTab('credits');navSub.options='opts';};ft.appendChild(a);}
}
