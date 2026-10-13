# STRIKE ARENA — Contexte complet du projet (passation entre conversations)

> À lire en entier par la nouvelle conversation avant de toucher au projet.
> L'utilisateur parle **français** : toujours répondre en français, de façon simple et directe.
> Dernière mise à jour : 13/10/2026.

---

## 1. Ce qu'est le projet

Un **FPS tactique dans le navigateur**, façon Valorant / CS:GO, avec un style **semi-réaliste mais « bon enfant »** (couleurs vives, comme Valorant), entièrement fait en code avec Three.js. Objectif à terme : **porter le jeu sur Roblox** (un kit Luau est déjà prêt dans `roblox/`).

- Dossier local : `D:\Office365_data\NLAVOINE\Onedrive\OneDrive - GROUPEMENT Mousquetaires\Bureau\Claude`
- PC d'entreprise (Groupement Mousquetaires), Windows 11, **pas de Python ni de Node** installés (Python via `uv` seulement, voir §8). On utilise **Perl** (fourni avec Git Bash) pour les scripts.
- Dépôt GitHub (public) : https://github.com/GriiVenn-LVN/strike-arena — compte **GriiVenn-LVN**
- Jeu en ligne (GitHub Pages) : https://griivenn-lvn.github.io/strike-arena/
- Les identifiants GitHub sont dans le gestionnaire d'identifiants Windows (Git Credential Manager) : `git push` fonctionne directement. **Ne jamais afficher le jeton.**

## 2. Préférences de l'utilisateur (important)

- Veut un jeu **beau, plaisant, complet** ; aime quand on « fait tout » sans économiser.
- Menus **propres, cohérents, intuitifs**.
- **A demandé de supprimer** : les capacités d'agents (style Valorant) et **les voix** (annonceur vocal). Ne pas les remettre.
- Veut des **modèles 3D réalistes** pour les armes ; a demandé de **chercher d'abord des modèles existants** sur internet avant d'en créer (voir §8).
- Pense à la monétisation Roblox plus tard (caisses, passe de combat) → respecter les règles Roblox (probabilités affichées, pas de marques réelles à terme, autorité serveur).

## 3. Lancer / construire / tester

- **Jouer** : ouvrir `index.html` (ou `strike-arena.html`, identique) ; `three.min.js` doit être à côté.
- **Construire** : `./build.sh` (Git Bash) concatène `src/*` dans l'ordre défini dans `build.sh` → `strike-arena-v2.html`, `strike-arena.html` et `index.html`.
- **Ne jamais éditer `index.html` / `strike-arena.html` à la main** : modifier `src/`, puis reconstruire.
- **Serveur local de test** : `perl tools/serve.pl 8765` → http://localhost:8765/ (config `.claude/launch.json` nommée `game` pour le volet navigateur de l'app). Le fichier HTML dépasse 512 Ko : le volet navigateur n'ouvre plus le `file://`, il faut passer par ce serveur.
- **Publier** : `./build.sh` puis `git add -A && git commit -m "..." && git push` (Pages se met à jour en 1–2 min).
- **Débogage dans la page** : `window.__dbg` expose `G, P, ents, cfg, update, startMatch, toMenu, shoot, giveWeapon, MODES, MAPS, VM, RP, NET, netHost, netJoin, ZB, PROF, startBoxOpen…` (voir fin de `src/90_main.js`). Astuce de test : appeler `d.update(1/30)` en boucle pour simuler sans attendre ; `d.G.forceAds=true` force la visée.
- Les patchs sont faits avec de petits scripts Perl (`use utf8`, lecture/écriture en `:utf8`) ou l'outil Edit. Attention aux guillemets dans le shell : écrire les scripts dans un fichier plutôt qu'en ligne.

## 4. Architecture du code (`src/`, ordre de `build.sh`)

| Fichier | Rôle |
|---|---|
| `00_head.html` | HTML + CSS (menus, HUD, overlays). Le JS est dans une IIFE `'use strict'` (`function main(){…}`) |
| `10_core.js` | utilitaires, `cfg` (réglages sauvegardés), `DEFBINDS`/`BINDLABEL` (touches), `DIFFS` (5 niveaux de bots), `MODES` (9 modes), table des armes `W` (24 armes), grille de collision, raycast, A* |
| `20_maps.js`, `21_maps_extra.js` | 7 cartes : village, warehouse (Entrepôt), station (Station polaire), harbor (Port de nuit), metro, jungle (Temple perdu), range (Stand de tir) |
| `30_audio.js` | sons 100 % synthétisés (WebAudio), `sfx(type,x,z,vol)` |
| `40_gfx.js`, `41_gfx_themes.js` | rendu, thèmes, construction du monde |
| `44_skins.js`, `45_models.js`, `47_outfits.js` | 39 skins d'armes (peintures procédurales), modèles d'armes procéduraux (`BUILDERS`), soldats riggés (IK), danses, tenues |
| `50_fx.js`, `51_fx2.js` | particules, impacts, douilles ; v2 : **balles traçantes volumétriques qui voyagent**, éclairs d'impact par surface, flash de bouche 3D (bots inclus) |
| `55_vm.js` | arme en vue subjective (viewmodel). Correctif visée : la crosse est masquée en ADS et l'arme avancée (sinon grosse zone noire) |
| `60_game.js` | cœur du jeu : entités, tir, dégâts, bombe, manches, achats, joueur |
| `61_variants.js` | `startMatch` + variantes : Désamorçage rapide, Capture de zone, Zombies, Bataille royale, Entraînement |
| `62_meta.js` | profil (`PROF`, localStorage), XP/niveaux, récompense quotidienne, défis, caisses (probabilités + pitié), stats |
| `63_agents.js` | **ancien fichier agents, réécrit** : maintenant **mines de proximité** achetables (touche X, max 2, 350 $), destructibles par balle/couteau/grenade ; les bots en posent et tirent dessus ; + difficulté adaptative des bots |
| `64_extras.js` | accessoires d'armes (silencieux, point rouge creux, chargeur étendu, poignée), charms, compteur de kills, sprays (J), traînées, titres, styles de couteau, onglet Style |
| `65_cine.js` | cinématique d'arrivée en hélicoptère |
| `66_progress.js` | passe de combat (30 paliers), classement Bronze→Légende, 18 succès, événement Halloween (citrouilles) |
| `67_immersion.js` | météo (pluie/orage/brouillard), jour/crépuscule/nuit, musique dynamique, radio texte des bots, killcam, podium MVP, tonneaux explosifs, sang. **Annonceur vocal désactivé** (`announce()` retourne immédiatement) |
| `68_access.js` | accessibilité (daltonisme, sous-titres sonores, taille HUD, secousses), sensibilité par arme, profils de touches, **tutoriel guidé** |
| `69_zombies.js` | **Zombies façon Black Ops** : points, armes murales à la craie, boîte mystère (950), Forge Arcane = Pack-a-Punch (5000), 5 atouts (Mastodonte, Turbo Cola, Double Détente, Second Souffle, Pas de Course), armes prodiges (Rayon X, Canon Tonnerre, Souffle Givré — très puissantes, peu de munitions), bonus (Munitions max, Mort instantanée, Points doubles, Bombe, Vente de feu), manches en chiffres rouges |
| `6A_replay.js` | **rediffusion du dernier kill** en fin de manche (enregistrement 8 s, caméra cinéma, ralenti, Espace pour passer) |
| `6B_net.js` | **multijoueur** : « Même PC » (BroadcastChannel entre onglets) ou « En ligne » (PeerJS/WebRTC via code de salon). L'hôte simule tout ; les clients envoient déplacement/tirs/achats et affichent l'état reçu (15 Hz). Modes compatibles : bomb, rapid, tdm, ffa, gg, koth |
| `70_ai.js` | IA des bots (vision, objectifs bombe, grenades, achats) |
| `80_ui.js` | HUD, entrées clavier/souris, boutique, tableau des scores, fin de partie |
| `85_menu.js`, `86_meta_ui.js` | menus (cartes de mode, armurerie 3D, casier, caisses 3D, stats, touches) |
| `87_nav.js` | **nouvelle navigation** : 5 rubriques (Jouer / Arsenal / Casier / Carrière / Options) + sous-onglets ; écran Jouer en 3 étapes (Mode → Carte → Réglages → JOUER) ; Jouer › Multijoueur |
| `88_blueprint.js` | armurerie : vue **Schéma 3D** (plan technique annoté), **vue éclatée**, rotation à la souris |
| `8A_juice.js` | finitions : confettis, compteurs animés, rubans d'événement/saison/récompense dans le menu, thème Halloween du menu, panneaux vitrés, animations de caisse (montée de rareté, rayons, onde de choc) |
| `90_main.js` | boucle principale `update()` / `render()`, démarrage, `window.__dbg` |

**Règles de jeu notables** : phase d'achat de **20 s** (10 s en Désamorçage rapide) ; **1re manche au pistolet uniquement** (mode compétitif) ; mines destructibles ; armes prodiges hors boutique / hors caisses.

## 5. Kit Roblox (`roblox/`)

Luau + Rojo (`default.project.json`). Services : DataService, RewardService, LootService, WeaponService (tir validé serveur, compensation de latence, grenades), RoundService, MapBuilder, AgentService (**obsolète** depuis la suppression des agents), ProgressService, NetService, PartyService, ShopService, ClanService, WeatherService. Clients : Cinematic, Emote, LobbyUI, Ability (obsolète), Accessibility, Net, Weather. `MapData.lua` est généré par `perl tools/export_maps_lua.pl > roblox/ReplicatedStorage/Shared/MapData.lua` (7 cartes).
**Pas encore branché** : appels de WeatherService/ProgressService dans RoundService, `Main.server.lua`, champs de profil manquants dans DataService, zombies Black Ops côté Roblox. L'utilisateur a demandé si on peut piloter **Roblox Studio** (serveur MCP officiel Roblox) : pas encore installé.

## 6. Ce qui a été vérifié / limites connues

- Les 9 modes tournent sans erreur sur les cartes testées ; multijoueur testé entre 2 onglets (lobby, achat, tir distant qui tue).
- Mode « En ligne » (PeerJS) **jamais testé entre deux vrais PC** ; le réseau d'entreprise peut le bloquer.
- Multijoueur : pas de vol de grenade visible chez les invités (juste l'explosion), mines invisibles chez les invités, si l'hôte quitte la partie s'arrête.
- Zombies : pas de portes à débloquer ni de réanimation par alliés.
- itch.io et opengameart.org sont **bloqués** sur le réseau de l'entreprise ; Sketchfab et poly.pizza sont accessibles.

## 7. Historique des demandes récentes (dans l'ordre)

1. Supprimer les agents et les voix ✔ — mines achetables et destructibles ✔ — viseur avec zone noire corrigé ✔ — menus refaits ✔ — schéma 3D des armes ✔ — zombies façon Black Ops ✔
2. Effets de tir, menus/interfaces, animations de caisse, récompenses, thème/événement visibles ✔ — phase d'achat plus longue ✔ — rediffusion du dernier kill ✔ — manche au pistolet ✔ — multijoueur local + en ligne ✔ — publication GitHub Pages ✔
3. **En cours : vrais modèles 3D d'armes** via Blender (voir §8).

## 8. Travail EN COURS : modèles 3D d'armes (Blender + Sketchfab)

**Installé** : Blender 5.2.2 (`C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`), uv 0.13.0 (`%LOCALAPPDATA%\Microsoft\WinGet\Packages\astral-sh.uv_…\uvx.exe`), extension **MCP for Blender** activée (port 9876, télémétrie désactivée). `.mcp.json` (non versionné) déclare le serveur MCP `blender` (uvx + Python 3.12 local, car uv n'arrive pas à créer ses liens Python standards sur ce PC → on passe le chemin explicite `%LOCALAPPDATA%\uv\python\cpython-3.12.15-windows-x86_64-none\python.exe` et `UV_PYTHON_INSTALL_DIR`).

**Pilotage de Blender sans redémarrer la session** : `perl tools/bl.pl script.py` (exécute du Python dans Blender), `perl tools/bl.pl -c "code"`, ou `perl tools/bl.pl -t <commande> '<json>'` (ex. `get_sketchfab_status`, `download_sketchfab_model {"uid":"…"}`). Blender doit être ouvert avec le panneau MCP connecté. **Sketchfab est activé** dans Blender (compte de l'utilisateur, jeton saisi par lui — ne jamais le demander/afficher).

**Choix validé par l'utilisateur** : série **« Low-Poly » de TastyTony** sur Sketchfab (licence **CC BY** → **créditer l'auteur** dans un écran Crédits), style cohérent, sans textures (nos skins s'appliqueront), 2 000–16 000 faces ; puis éventuellement des modèles réalistes texturés pour les armes phares (ex. AKM réaliste de dan741vlasov `409c8845a8034f92b860fdff752dc2dc`). Éviter les modèles « CS2 » (probablement extraits du jeu).

**Correspondance arme du jeu → UID Sketchfab (TastyTony)** :
glock `60efc54ac59e47d18bdff94b2f5144ff` (G17) · usp `0d90f858e9f74c418ce3aae61cef9f4e` (Sig P226) · p250 `7cf2a3a662d344ee989e343ccaee56e9` (CZ-75 SP-01) · fiveseven `b896f7b001864805ae09bb2280b1795a` · deagle `b81da261345f4462b2c4412352162287` · mac10 `833e1c5fb1c4414c83c531bacfa1cffb` (Micro Uzi) · mp9 `80980f757c2c463ebc73460a31611652` (MP5) · ump `4e8e3535e9d74c06b82066129ec18769` · p90 `96b61ebbbf154843b621ebf7f48647fc` · nova `c0551a6b841145f7a8e59e9304728f1f` (Mossberg 590) · sawedoff `c6dc60f453fc4abf88d2691159bdd8f4` (Chiappa Double Eagle) · xm `9e5d30e1cbc3472485f95d860de383b7` (AA-12) · galil `4bc3146c48d34171ab0ea879757000b7` · famas `bbd20712667e49088f5c9960b97c3d83` · ak `849b7cdf8622487485febc40db89e734` (AKM) · m4 `8cab1cbeb82c4396a154f9fc8771417b` · sg553 `6d9fa654362c417f941004732c5445e3` (SG 542) · aug `a2716d53ea844d9a85fb9060bbf24352` · ssg `70b2eaf52c364e8a82093496097083fc` (SV-98) · awp `a795adf5f8dd4a2294210d427cbb0e58` (L115A3) · scar `c52bc2a8ddaa47caa34e94d69ff72d96` · negev `0d4aab1cd2dc4fd2866c2a96fb6b6fee` (Ultimax 100) · m249 `76011c365636451c90a8e3a46c2d8ca5` (M249 SAW). Couteau et armes prodiges : garder les modèles procéduraux.

**Pipeline** (`tools/blender/`) :
- `prep_weapon.py` → `run(KEY, REAL_LEN, OUT_DIR)` : sépare les pièces animées d'après les os (chargeur/culasse), supprime squelette/caméra/lampe, oriente le canon vers +Y Blender (= −Z glTF, convention du jeu), met à l'échelle réelle, calcule les ancrages (main droite = origine, main gauche, bouche, ligne de visée), allège au-delà de 19 000 triangles (limite Roblox 20 000), exporte `models/weapons/<clé>.glb` + `<clé>.json`.
- `run_prep.py` : lanceur (préfixer `KEY="ak"` et `REAL_LEN=0.88`), ajoute des repères colorés et rend un aperçu PNG dans le dossier scratchpad.
- `common.py` + `ak.py` : outils de modélisation procédurale et une AK modélisée à la main (mise de côté au profit des modèles Sketchfab ; utile pour les armes introuvables).
- `inspect.py` : liste objets/os/matériaux de la scène.

**État exact** : l'AKM (`849b7cdf…`) est importé dans Blender (13 os : body, bolt, mag, bullet(s), magrelease, selector ; unités ≈ ×1000, canon sur +X). Le premier lancement de `prep_weapon.run` a **planté** à la ligne `sight = max(…)` (« max() iterable argument is empty ») : la fenêtre de recherche de la ligne de visée près de la bouche ne contient aucun bin rempli. À corriger (élargir la fenêtre / fallback sur le max global du tiers avant), puis vérifier visuellement l'aperçu (orientation, repères), puis traiter les 22 autres armes.

**Reste à faire ensuite** :
1. Côté jeu web : charger les `.glb` (GLTFLoader, Three.js r128 — version de `three.min.js`) à la place de `gunParts()` dans le viewmodel, les soldats (`setSoldierGun`), l'armurerie et les icônes ; mapper les matériaux par couleur (bois / acier / accessoires) pour que les **skins** s'appliquent ; utiliser `left/right/sight/muzzle` du JSON pour les mains, la visée et le flash ; animer la pièce `mag` au rechargement.
2. Écran **Crédits** (auteur, titre, lien, licence CC BY pour chaque modèle).
3. Export `.fbx` pour Roblox (MeshPart) et mise à jour du kit.
4. Publier (`./build.sh`, commit, push).

## 9. Fichiers à ne pas versionner

`.gitignore` : `backup/`, `strike-arena-v2.html`, `.claude/`, `.mcp.json`. Les sauvegardes de sources sont dans `backup/`.
