# STRIKE ARENA — Kit de portage Roblox

Ce dossier contient tout ce qu'il faut pour transformer le prototype web (`strike-arena.html`) en jeu Roblox :
code **Luau** prêt à coller / synchroniser avec **Rojo**, données de cartes exportées automatiquement, et la liste de ce qu'il reste à créer dans Studio.

## 0. Publier le jeu sur Roblox (première fois)

Le fichier `StrikeArena.rbxlx` contient tout le code, prêt à ouvrir. On le refabrique depuis ce dossier avec
`rojo build default.project.json -o StrikeArena.rbxlx` (il n'est pas gardé dans le dépôt).

1. Crée un compte sur roblox.com, puis installe **Roblox Studio** et connecte-toi.
2. Ouvre `StrikeArena.rbxlx` dans Studio (*File → Open from File*).
3. Appuie sur **Play** (F5) pour essayer. Si une ligne rouge apparaît dans la fenêtre *Output* (*View → Output*), envoie-la.
   Tant que le jeu n'est pas publié, la sauvegarde est coupée (un avertissement jaune `[Stores]` le dit) : c'est normal.
4. **File → Publish to Roblox** → *Create new experience* : nom « Strike Arena », genre *Shooter*, appareils PC, téléphone, tablette, console.
5. **Home → Game Settings → Security** : coche *Enable Studio Access to API Services*, puis *Save*. La sauvegarde, les classements et les codes marchent alors aussi dans Studio.
6. Sur **create.roblox.com** → ton expérience : remplis le **questionnaire de maturité** (obligatoire avant d'ouvrir le jeu), ajoute une icône et des images, puis **Settings → Privacy → Public** quand tu veux l'ouvrir à tous.
7. Plus tard, pour les achats en Robux et le groupe : section 3 (`productId`) et section 1 ter (`GROUP.id`). En attendant, les boutons Robux affichent « Bientôt ».

Pour les mises à jour suivantes : synchronise avec Rojo (section 1) ou rouvre un `.rbxlx` refabriqué, puis *File → Publish to Roblox* de nouveau (la même expérience est mise à jour).

**Sécurités ajoutées pour le premier lancement** : `ServerScriptService/Stores.lua` remplace la sauvegarde par une mémoire temporaire quand Roblox la refuse (jeu pas encore publié), au lieu d'arrêter tout le serveur ; si la lecture d'un profil échoue, il n'est jamais écrasé ; `default.project.json` coupe l'apparition automatique (le lobby place le joueur) et le *streaming* (la carte est construite par script).

## 0 bis. Comme sur le web : armes, bras, sons, déplacements, menu des armes

- **Vraies armes du web** : les 23 modèles 3D du jeu web (série Low-Poly de TastyTony, CC BY) sont dans `ReplicatedStorage/Shared/WeaponMeshes`
  (générés par `python3 tools/export_weapons_lua.py`) et fabriqués en jeu par `WeaponModels.lua` avec l'API EditableMesh.
  **À faire une fois** : *Game Settings → Security → Allow Mesh / Image APIs* (sinon les armes sont dessinées en blocs simples).
- **Vue à la première personne** (`ViewmodelController`) : bras, arme, balancement, recul, sortie d'arme, recharge en phases
  (chargeur qui tombe, chargeur neuf, armement à vide), inspection (**V**), coup de couteau, douilles, éclair, lunette des fusils de précision.
  Les autres joueurs et les bots tiennent la vraie arme, bras levés (`WeaponVisuals`, pose dans `WeaponService`).
- **Déplacements** (`MovementController`) : **Maj** sprint, double **Maj** sprint tactique, **C** ou **Ctrl** accroupi,
  **C en sprintant** glissade (saut = l'annule en gardant l'élan), **saut face à un rebord** escalade. On ne tire pas en sprintant.
- **Menu des armes** (`LoadoutUI`, touche **B** ou bouton « 🔫 Armes ») : arme principale et pistolet, gardés dans le profil.
- **Vrais sons du web** : les 40 sons synthétisés du jeu web sont rendus dans un seul fichier, `strike-arena-sons.ogg`
  (`node tools/render_sounds.js <dossier>`, positions dans `SoundSheet.lua`). Importe-le sur create.roblox.com (*Créations → Audio*),
  puis mets son numéro dans `ModeConfig.SOUND_SHEET`. En attendant, les sons fournis avec Roblox servent de remplacement.
- **Robux** : tous les numéros de produits se mettent dans un seul fichier, `ReplicatedStorage/Shared/ProductIds.lua` (nom et prix en commentaire).

## 0 ter. Soldats du web : apparence, animations, ragdoll

- **Même soldat que le web** : soldat photo-réaliste CC0 (Mesh2Motion) aux couleurs de l'équipe — Attaquants (T, camouflage désert), Défenseurs (CT, bleu nuit), sans équipe (chacun-pour-soi, gris teinté de la couleur du joueur) — avec gilet, casque, poches et sac du soldat procédural ; les **tenues de la boutique** gardent le soldat procédural du web (couleurs et coiffe de chaque tenue).
  Données dans `ReplicatedStorage/Shared/SoldierMeshes` (≈ 870 Ko), refaites avec
  `node tools/soldiers/export_soldiers_web.js /tmp/soldats.json && python3 tools/soldiers/soldiers_to_lua.py /tmp/soldats.json`
  (Playwright + Chromium, Pillow). Même réglage que les armes : *Allow Mesh / Image APIs* ; sans lui, l'avatar R15 reste visible.
- **Habillage** (`SoldierController`, `SoldierModels`) : chaque client découpe le soldat en 15 morceaux soudés aux membres R15 (cachés sur ce client). Joueurs, bots et soi-même (ombre, kill-cam) ; à la première personne on ne voit que le viewmodel, comme sur le web.
- **Animations du web** (`SoldierAnim`, port de `45_models.js` et `8T_anim.js`) : marche et course selon la vitesse, accroupi, glissade, sprint et sprint tactique, saut/chute/réception, escalade, buste qui suit le regard, recharge, recul, bras qui tiennent l'arme (IK), 8 danses (touche T quand la danse n'a pas d'animation importée), mort. Appliquées aux `Motor6D.Transform` à chaque image : aucune animation à importer. L'état (glissade, sprint, accroupi, visée) passe par le remote `SoldierAnim`, la recharge par l'attribut `ReloadT`, la tenue par l'attribut `Outfit` du joueur (`SoldierService`).
- **Ragdoll** (`SoldierService`, comme `8Zb_ragdoll.js`) : à la mort, les articulations deviennent des `BallSocketConstraint` (limites par articulation) et le corps part dans le sens du tir qui tue (plus fort au fusil à pompe et au sniper, différent sur un tir à la tête). La réapparition et la kill-cam ne changent pas.
- **Pas vérifié dans Studio** : rien n'a pu tourner ici. Points à surveiller : rendu des pièces EditableMesh soudées (orientation, taille) et le passage de l'animation au ragdoll (les membres repartent de la pose « naturelle » vue par le serveur).

## 1. Mise en place (15 minutes)

1. Installe **Roblox Studio** puis **Rojo** (extension VS Code `evaera.vscode-rojo` + plugin Studio).
2. Dans ce dossier : `rojo serve` puis connecte-toi depuis Studio (plugin Rojo → *Connect*).
   Sans Rojo : copie chaque fichier dans l'explorateur Studio selon l'arborescence ci-dessous.
3. Active **Game Settings → Security → Enable Studio Access to API Services** (DataStore en test).
4. Appuie sur **Play** (F5) : `Main.server.lua` lance un **match à mort par équipe sur Village** dès que tu es là, les bots complètent les deux équipes (5 contre 5). Pour tester à plusieurs : *Test → Local Server*, 2 joueurs. Détails et commandes : section 1 bis.

```
ReplicatedStorage/Shared/Config.lua      armes, raretés, caisses, récompenses, danses, skins (valeurs du prototype)
ReplicatedStorage/Shared/ShopCatalog.lua catalogue de la boutique (armes, skins, viseurs, tenues, produits Robux)
ReplicatedStorage/Shared/ModeConfig.lua  mode lancé (tdm / bomb), réglages du match à mort, des bots et des sons de combat
ReplicatedStorage/Shared/MapData.lua     grille de jeu des 10 cartes du web (généré par tools/scene_to_lua.py)
ReplicatedStorage/Shared/MapScenes/      décor 3D des 10 cartes du web (blocs, maillages, textures, lampes, ambiance)
ReplicatedStorage/Shared/MapScene.lua    lecture de MapScenes (client + serveur)
ServerScriptService/DataService.lua      DataStore : profil, XP, pièces, inventaire, stats, défis, série quotidienne
ServerScriptService/RewardService.lua    niveaux, récompense quotidienne, défis du jour, récompenses de fin de partie
ServerScriptService/LootService.server.lua  caisses : tirage pondéré + pitié + doublons
ServerScriptService/ShopService.server.lua  boutique : achats en pièces, offres du jour, équiper, achats Robux (seul ProcessReceipt du jeu)
ServerScriptService/WeaponService.lua    tir hitscan validé serveur : cadence, munitions, recharge, 3 armes, couteau, bouclier → gilet → santé (joueurs et bots)
ServerScriptService/BotService.lua       bots R15 : patrouille (PathfindingService), vision, temps de réaction, rafales
ServerScriptService/TDMService.lua       match à mort par équipe : équipes, bots, réapparition, protection, objets, fil, séries, assistances, fin
ServerScriptService/MapBuilder.lua       construit une carte : collision exacte du web (invisible) + décor du web ; plusieurs cartes à la fois
StarterPlayerScripts/MapDetailController.client.lua  maillages détaillés, textures du web, halos, ciel / brouillard / lumière de la carte
ServerScriptService/Modes/rounds.lua    modes à manches (Compétitif, Désamorçage rapide, Duel) : achat → manche → fin, bombe, économie, mi-temps ; koth / dom / ctf : zone, drapeaux ; HUD : ModeHud.client.lua
ServerScriptService/Main.server.lua      point d'entrée + RemoteFunctions (profil, daily, défis, danses, skins)
StarterPlayerScripts/CinematicController.client.lua   cinématique d'arrivée en hélicoptère (caméra scriptée, barres de cinéma)
StarterPlayerScripts/EmoteController.client.lua       danses (touche T) via Animator
StarterPlayerScripts/WeaponController.client.lua  tir à la première personne : clic gauche/droit, R, 1-2-3, molette, manette, tactile, recul, traceurs, sons
StarterPlayerScripts/HudController.client.lua     HUD : score, vie/bouclier, munitions, marqueur de touche, chiffres de dégâts, direction des dégâts, fil, séries, Tab, fin
StarterPlayerScripts/LobbyUI.client.lua  UI minimale : profil, récompense quotidienne, caisses (avec probabilités)
StarterPlayerScripts/ShopUI.client.lua   écran boutique : 5 onglets, offres du jour, Acheter / Équiper
```

## 1 bis. Premier test : match à mort par équipe sur Village

**Ce que tu dois faire (une fois que tu as un compte Roblox)** :
1. Crée une expérience vide (*Baseplate*) dans Studio, supprime la `Baseplate` et le `SpawnLocation`.
2. Synchronise ce dossier avec Rojo (section 1) et appuie sur **Play**.
3. Tu apparais dans le **lobby** (section 1 ter). Passe le portail rouge (ou bouton « Jouer ») : tu arrives sur Village, dans l'équipe orange ou bleue, avec Galil/FAMAS + pistolet + couteau ; 9 bots complètent les équipes.

**Commandes** : clic gauche tirer · clic droit viser · R recharger · 1/2/3 ou molette changer d'arme · **Tab** tableau des scores · **M** libérer la souris (boutique, profil, caisses) · T danse.
Manette : RT/LT/X/Y, Select pour les scores. Téléphone : boutons Tir / Viser / R / Arme et « Scores ».

**Règles de la partie** (modifiables dans `ModeConfig.TDM`) : première équipe à 50 éliminations ou 8 minutes ; réapparition après 3 s loin des ennemis, avec 2 s de protection (annulée si tu tires) ; santé, bouclier et munitions à ramasser sur la carte (20 s avant de revenir) ; assistance à partir de 30 dégâts ; séries annoncées à 3, 5, 7 et 10 ; écran de fin avec XP, pièces, paliers du passe, puis nouvelle partie après 15 s. Les citrouilles d'Halloween apparaissent si l'événement est actif.

**Bots** (`ModeConfig.BOT`) : temps de réaction, imprécision, distance de vue et armes réglables. Ils tirent avec exactement les mêmes règles que les joueurs (`WeaponService.fire`).

**Ce qui reste provisoire** :
- Armes : un bloc gris dans la main. Mets tes modèles dans `ReplicatedStorage/Assets/Weapons/<clé>` (ex. `ak`, `galil`), ils seront pris automatiquement ; une `Attachment` nommée `Muzzle` place l'éclair de bouche.
- Pas encore de bras/arme à la première personne (viewmodel) ni d'animations de tir/recharge : à faire dans l'Animation Editor.
- Sons : des sons fournis avec Roblox servent de remplacement. Remplace les identifiants de `ModeConfig.SOUNDS` par de vrais sons (tir, touche corps, touche tête, élimination) depuis Creator Store → Audio, en vérifiant la licence.
- Choix de l'arme principale : le serveur accepte déjà `SetLoadout` (armes de départ ou achetées) ; il manque le petit menu qui l'appelle.

**Ce que je n'ai pas pu vérifier** : rien n'a tourné dans Studio (pas de compte). La syntaxe Luau de chaque fichier est vérifiée avec `luau-compile`, mais le premier test dans Studio montrera sûrement des réglages à ajuster (position de l'arme dans la main, vitesse des bots, volume des sons). Envoie-moi la fenêtre *Output* s'il y a une erreur rouge.

Régénérer les cartes après modification du prototype : voir la section 0 ter.

## 0 ter. Les 10 cartes du web, à l'identique

Village, Entrepôt, Station polaire, Port de nuit, Métro, Temple perdu, Stand de tir, Laboratoire, Asile hanté et Manoir hanté
sont relevées **sur le jeu web en marche** (le vrai `buildWorld()` de chaque carte), puis reconstruites dans Roblox :

- **Jeu (serveur, `MapBuilder`)** : la collision vient de la grille du web (cases, hauteurs, rampes en pente continue, plafonds),
  en blocs invisibles. Murs, toits, rampes, plafonds et lignes de vue se comportent comme sur le web ; les balles, les bots et
  l'escalade ne touchent que ces blocs. Le décor (blocs, boules, cylindres du web, ~1 300 à 1 800 pièces par carte) est en Parts
  non collisionnables et ignorées des rayons (`CanQuery = false`), avec les couleurs et une matière Roblox proche de la texture du web.
- **Détails (client, `MapDetailController`)** : textures canvas du web sur les blocs (murs crépis, briques, caisses, sol avec ses
  marquages et son grain), tous les objets non primitifs (fûts, palmiers, feuilles, rochers, statues, citrouilles, relief lointain…)
  en maillages `EditableMesh` regroupés par matériau, halos des lampes, et l'ambiance du thème de la carte où l'on se trouve
  (ciel dégradé, brouillard, couleur et hauteur du soleil). Au lobby, l'éclairage d'origine revient.
  Il faut **Allow Mesh / Image APIs** (comme pour les armes) ; sinon les cartes restent en couleurs unies avec des blocs simples.
- **Plusieurs matchs à la fois** : `MapBuilder.build(id, origine, nom)` construit la carte dans `workspace[nom]` (attributs `MapId`,
  `Origin`, `Theme`), décalée de `origine` ; l'objet renvoyé a `cellToWorld`, `groundAt`, `toCell`, `spawns`, `sites`.
  `MapBuilder.destroy(carte)` la retire, `MapBuilder.list()` donne `{ id, name, desc, theme }` des 10 cartes dans l'ordre du web.
  Le client applique l'ambiance de la carte nommée par l'attribut `MatchMap` du personnage (sinon celle sous la caméra).
- Carte du match à mort : `ModeConfig.TDM.map` (`"village"`, `"warehouse"`, `"station"`, `"harbor"`, `"metro"`, `"jungle"`, `"range"`, `"labo"`, `"asile"`, `"manoir"`).

**Régénérer** (depuis la racine du dépôt, après une modification des cartes du web) :
```
bash build.sh
NODE_PATH=$(npm root -g) node tools/export_scene.js /tmp/cartes      # Playwright + Chromium
python3 tools/scene_to_lua.py /tmp/cartes                            # Pillow ; réécrit MapData.lua et MapScenes/
```

## 1 ter. Lobby, duels, codes, effets d'élimination, classement, groupe

Tout se règle dans `ReplicatedStorage/Shared/CommunityConfig.lua` (sauf les codes, côté serveur). Mets `LOBBY_ENABLED = false` pour revenir à l'ancien fonctionnement (directement dans le match).

- **Lobby jouable** (`LobbyService`) : on y arrive avec son arme. Personne ne peut blesser personne. On y trouve :
  - le **portail** du match à mort (bouton « 🏠 Lobby » pour revenir) ;
  - le **stand de tir** : 15 cibles libres, et un défi de 30 s (borne verte, touche E) ; 20 cibles = 50 🪙 la première fois, record gardé ;
  - le **parcours** : 16 plateformes de plus en plus hautes, chrono du départ vert à l'arrivée dorée ; 75 🪙 au premier parcours, record gardé ;
  - les **bornes Codes et Groupe** (touche E) et le **classement géant**.
- **Duels façon Rivals** (`DuelService`) : 4 plateformes (1v1, 1v1 avec mise, 2v2, 2v2 avec mise). Le duel part quand la plateforme est pleine. Premier à 5 manches, une vie par manche, 60 s par manche. Les mises vont dans un pot partagé par les gagnants. Chaque duel change l'**Elo** (rangs Bronze → Champion).
- **Codes promo** (`ServerScriptService/CodeList.lua`) : ajoute une ligne par code (pièces, caisse, effet, danse, dates de validité). La liste reste sur le serveur pour que personne ne puisse la lire. Déjà prêts : `BIENVENUE`, `HALLOWEEN25` (jusqu'au 8 novembre, donne l'effet Citrouilles), `DUEL`.
- **Effets d'élimination** (`KillFxConfig.lua`, onglet « Effets 💥 » de la boutique) : Confettis, Désintégration pixel et Envol céleste en pièces ; Foudre, Glace et Trou noir en Robux (crée les produits dans le Creator Hub et colle leurs `productId`) ; Citrouilles par code ; Esprit du groupe en rejoignant le groupe.
- **Groupe Roblox** : crée le groupe sur roblox.com et colle son identifiant dans `CommunityConfig.GROUP.id`. Le bouton « Rejoindre » ouvre la fenêtre officielle de Roblox, et le serveur vérifie l'adhésion avant de donner 200 🪙 + l'effet Esprit du groupe. Roblox ne permet pas de vérifier un « J'aime » : il y a seulement un rappel après 10 minutes de jeu, sans récompense.
- **Classement géant** (`LeaderboardService`) : éliminations de la semaine (remise à zéro le lundi) et meilleurs duellistes, partagés par tous les serveurs.

**Pour tester dans Studio** : active *Game Settings → Security → Enable Studio Access to API Services* (sinon les classements et la sauvegarde ne marchent pas). Pour un duel 1v1, lance *Test → Clients and Servers* avec 2 joueurs et mets-les sur la même plateforme. La souris se libère avec **M** pour cliquer sur les boutons de gauche.

## 1 quater. Armurier, viseurs, grenades et mines (comme sur le web)

- **Armurier** (`Attachments.lua` pour les données et les règles, `AttachmentModels.lua` pour la 3D, `ArmoryService` côté serveur). Ce sont les 21 accessoires du web : bouche, viseur, poignée, chargeur, laser et lampe. On en met 5 au maximum, ils se débloquent par niveau et par éliminations, et ils changent les mêmes stats que sur le web : dégâts, portée et chute des dégâts, recul, précision, mobilité, temps de visée, rechargement, chargeur et bruit. Les accessoires se voient en 3D sur l'arme, à la 1re et à la 3e personne. Avec une poignée verticale, la main gauche se place sur la poignée.
- **Viseurs** : les 5 modèles Blender du web (`OpticMeshes/*.lua`, ~222 Ko au total) sont reconstruits en EditableMesh sur le client. Si ça ne marche pas, des pièces simples les remplacent. On choisit la forme et la couleur du réticule pour chaque viseur. Le zoom en visée (ADS) et la sensibilité sont ceux du web. Les lunettes de sniper ont un réticule plein écran.
- **Panneaux** : `ArsenalPanels.arms(frame)` et `ArsenalPanels.sights(frame)`. Pour l'instant, on les ouvre depuis le menu **B**, onglets « Armurier » et « Viseurs ».
- **Grenades et mines** (`Grenades.lua` partagé, `GrenadeService` sur le serveur, `GrenadeController` sur le client) :
  - touches **G** pour la frag, **F** pour la flash, **H** pour la fumigène, **X** pour poser une mine ;
  - même trajectoire, mêmes rebonds, mêmes minuteries et mêmes dégâts que sur le web ;
  - alerte quand une grenade est proche, et le nombre de grenades est affiché en bas à droite.
- **Remotes** : `Armory` (RemoteFunction : get, set, ret, all), `ThrowGrenade`, `PlaceMine`, `GrenadeFx`, `GrenadeToast`.
- **Attributs du joueur** : `Att_<arme>` (« muzzle=sil,optic=reddot »), `Ret_<viseur>` (« forme|#couleur »), `Nades` (« frag,flash,fumi,mine ») et `BlindUntil` pour les bots aveuglés.
- **Régénérer les viseurs** : `python3 tools/export_optics_lua.py` (lit `models/optics/*.glb`).

## 2. Correspondance prototype web → Roblox

| Prototype web | Roblox |
|---|---|
| Grille 40×40, 1 case = 2 m, hauteurs, rampes, plafonds | `MapData.lua` + `MapBuilder.lua` (1 stud ≈ 0,28 m ⇒ `STUDS_PER_METER = 3.571`) |
| `buildWorld()` : décor 3D, textures canvas, thèmes | `MapScenes/` + `MapBuilder.lua` (blocs) + `MapDetailController` (maillages, textures, ambiance) |
| `shoot()` / `hurt()` (client = serveur) | Le **client** envoie origine + direction (`FireWeapon`), le **serveur** valide et applique les dégâts (anti-triche) |
| Bots (A* + vision + objectifs) | `PathfindingService` + PNJ R15 ; la logique d'objectif (poser / défendre / chasser) se porte telle quelle |
| Particules GPU, impacts, douilles | `ParticleEmitter` / `Beam` / `Trail` ; décalques via `Decal` sur `result.Instance` |
| Modèles d'armes procéduraux | `Tool` + `Handle` (MeshPart) ; skins = `SurfaceAppearance` (PBR) |
| Soldats animés | R15 + animations de tir/recharge ; danses = `Animation` (Animation Editor) |
| Cinématique hélicoptère | `CinematicController.client.lua` (Camera Scriptable + TweenService) |
| Récompense quotidienne, défis, XP | `RewardService.lua` + DataStore |
| Caisses 3D | `LootService` (serveur) + `ViewportFrame` côté client pour l'animation |
| Touches personnalisables | `ContextActionService` + `profile.binds` (sauvegardé dans le DataStore) |
| Statistiques | `profile.stats` / `profile.history` (déjà alimentés par `RewardService.finishMatch`) |

## 3. Boutique

- **Monnaie** : les pièces gagnées en jouant (niveaux, récompense du jour, défis, succès, passe de combat) achètent armes, skins, viseurs et tenues. L'économie est volontairement lente (~35 pièces par partie, ~28 parties pour le niveau 10, ~260 pour le niveau 30).
- **Robux** : pièces (49 à 699 R$), caisses Premium (79 / 349 R$), passe Premium (399 R$) et les **Exclusifs** : 6 camos animés (249 à 449 R$, ou 1 299 R$ les six) qu'on ne peut obtenir qu'en payant. Prix alignés sur Arsenal, RIVALS et Phantom Forces.
- **Onglets** : Armes (débloquées pour toujours ; 8 armes de départ gratuites), Skins (par arme), Viseurs (modèle d'optique par arme + réticule commun, purement visuels), Tenues & style (tenues, traînées, titres), Exclusifs ✨ (camos animés, Robux uniquement, à poser arme par arme), Robux.
- **Prix** : par rareté (`ShopCatalog.PRICE_BY_RARITY`) ; armes = 40 % de leur prix en partie (`ShopCatalog.weaponPrice`). 4 **offres du jour** à -25 % (une par onglet), identiques pour tous les joueurs, renouvelées à minuit UTC.
- **Abonnement Premium ⭐** (onglet Premium, `LoyaltyConfig.VIP`) : 30 jours 349 R$, 90 jours 899 R$, jours cumulables. Donne une couleur de pseudo (chat, `LoyaltyConfig.richName` pour le futur HUD), +20 % XP et pièces, +60 pièces par jour, 1 Caisse Premium à l'achat, série protégée un jour par semaine, titre « ⭐ Premium ». Crédité par `LoyaltyService.grantVip` depuis le ProcessReceipt de ShopService.
- **Fidélité** (`LoyaltyService`, `LoyaltyUI`) : 5 cadeaux de temps de jeu par jour (10 à 75 min avec un personnage en vie), paliers de série (3 à 100 jours), rang de fidélité selon les jours joués (bonus d'XP permanent jusqu'à +12 %), boost d'XP, première victoire du jour, cadeau « bon retour » après 3 jours d'absence. Mêmes valeurs que le web (`src/8W_loyalty.js`).
- **Menu d'achat en partie** (à faire) : ne proposer que les armes débloquées avec `ShopCatalog.ownsWeapon(profile, key)`.

**Activer les achats Robux** (quand tu auras un compte Roblox et un jeu publié) :
1. Creator Hub → ton expérience → **Monetization → Developer Products** → crée un produit par ligne de `ConfigExtra.SHOP`, de `ConfigExtra.EXCLUSIVES` **et** de `LoyaltyConfig.VIP.offers` (même nom, même prix en Robux).
2. Copie l'identifiant de chaque produit dans le champ `productId` de la ligne correspondante. Tant qu'il vaut 0, le bouton affiche « Bientôt ».
3. Teste dans Studio : les achats y sont simulés, aucun Robux n'est débité.

## 4. À créer dans Studio (le code ne peut pas le faire à ta place)

- **Hélicoptère** : modèle dans `ReplicatedStorage/Assets/Helicopter` (PrimaryPart = fuselage, une pièce nommée `Rotor`). Un modèle de secours simple est généré sinon.
- **Armes** : un `Tool` par arme de `Config.WEAPONS`, avec `Handle`, sons (tir, recharge) et animations.
- **Animations de danse** : 8 `Animation` R15 → colle les `rbxassetid://…` dans `Config.DANCES[...].animationId`.
- **Camos animés** : `ConfigExtra.EXCLUSIVES[...].anim` donne les couleurs et la vitesse ; sur l'arme, anime un `Texture` (OffsetStudsU/V pour le défilement) et la `Color3` d'un `SurfaceAppearance`/`PointLight` pour la pulsation, depuis un script client. Le rendu de référence est dans le prototype web (`src/44b_animcamo.js`).
- **Textures** : peins/sculpte dans Blender ou utilise `Material`/`SurfaceAppearance` ; garde le style « semi-réaliste et bon enfant » (couleurs vives, formes arrondies, lumière douce) comme dans le prototype.
- **Sons / musique** : mixe-les toi-même ou prends ceux de la Toolbox *en vérifiant la licence*.
- **Interface finale** : le prototype web est ta maquette (menus, HUD, boutique, casier, caisses).

## 5. Règles Roblox à respecter (important)

- **Caisses payantes (Robux)** : les objets aléatoires payants exigent d'**afficher les probabilités** (déjà fait dans `LobbyUI`), de respecter les restrictions d'âge/région de Roblox et de ne jamais promettre de valeur réelle. Garde aussi une voie 100 % gratuite (pièces gagnées en jouant), comme dans ce kit.
- **Autorité serveur** : le client ne décide jamais des dégâts, de l'argent, de l'inventaire ni des récompenses.
- **Contenu** : évite les marques d'armes réelles si tu publies (les noms CS:GO du prototype sont à remplacer : « Glock-18 » → « Pistolet G18 », « AK-47 » → « Fusil K47 », etc.) ; vérifie les règles de contenu violent de Roblox (pas de sang réaliste, ton « bon enfant »).
- **Performance** : < 10 000 Parts visibles (utilise `StreamingEnabled`), `Anchored = true` pour tout le décor, réutilise les `ParticleEmitter`.

## 6. Idées de fonctionnalités à ajouter (classées par impact)

**Rétention (donner envie de revenir)**
1. **Passe de combat saisonnier** (50 paliers gratuits + premium) : skins, danses, traînées, sprays.
2. **Défis hebdomadaires + défis d'équipe** (« Gagnez 3 manches ensemble »).
3. **Classement saisonnier & rangs** (Bronze → Légende) avec récompenses de fin de saison.
4. **Événements limités** (Halloween, Noël) : map décorée, mode spécial, caisse thématique.
5. **Succès / badges** Roblox (`BadgeService`) : premier headshot, ace, désamorçage à 1 s…

**Social**
6. **Parties avec amis** (`TeleportService` + serveurs réservés), **groupes de 5**, vocal (Roblox Voice).
7. **Clans** avec bannière, stats d'équipe et salon.
8. **Replay / caméra de fin de manche** (« play of the game »), **MVP animé** avec la danse du joueur.
9. **Spectateur** : suivre un ami après la mort ; mode streamer.

**Gameplay**
11. **Plus de modes** : Désamorçage rapide (7 manches courtes), Capture de zone, Escorte, Bataille royale 20 joueurs, Zombies (coopératif contre IA).
12. **Plus de cartes** (les 3 actuelles se portent directement ; ajoute une 4ᵉ : port / métro / jungle) + **mini-carte rotative** et callouts vocaux.
13. **Personnalisation d'armes** : accessoires (silencieux, viseur, chargeur étendu), breloques, compteur de kills sur l'arme, inspection (V).
14. **Économie vivante** : rachat rapide, drop d'armes aux alliés, « eco round » indiqué.
15. **Bots adaptatifs** : le niveau suit le skill du joueur (réaction/précision ajustées).

**Confort & qualité**
16. **Entraînement** : stand de tir avec cibles, test des armes, rejouer les trajectoires de grenades.
17. **Accessibilité** : mode daltonien, taille du HUD, sous-titres des sons (« pas à gauche »), sensibilité par arme.
18. **Réglages de réseau** : prédiction client + réconciliation, affichage du ping.
19. **Anti-triche** : limites de vitesse, vérification d'origine du tir (déjà amorcée dans `WeaponService`), signalement.
20. **Boutique cosmétique** (Robux) : skins de personnage, gants, casques, tags de profil — sans avantage de gameplay.
