# STRIKE ARENA — Kit de portage Roblox

Ce dossier contient tout ce qu'il faut pour transformer le prototype web (`strike-arena.html`) en jeu Roblox :
code **Luau** prêt à coller / synchroniser avec **Rojo**, données de cartes exportées automatiquement, et la liste de ce qu'il reste à créer dans Studio.

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
ReplicatedStorage/Shared/MapData.lua     3 cartes exportées du prototype (généré par tools/export_maps_lua.pl)
ServerScriptService/DataService.lua      DataStore : profil, XP, pièces, inventaire, stats, défis, série quotidienne
ServerScriptService/RewardService.lua    niveaux, récompense quotidienne, défis du jour, récompenses de fin de partie
ServerScriptService/LootService.server.lua  caisses : tirage pondéré + pitié + doublons
ServerScriptService/ShopService.server.lua  boutique : achats en pièces, offres du jour, équiper, achats Robux (seul ProcessReceipt du jeu)
ServerScriptService/WeaponService.lua    tir hitscan validé serveur : cadence, munitions, recharge, 3 armes, couteau, bouclier → gilet → santé (joueurs et bots)
ServerScriptService/BotService.lua       bots R15 : patrouille (PathfindingService), vision, temps de réaction, rafales
ServerScriptService/TDMService.lua       match à mort par équipe : équipes, bots, réapparition, protection, objets, fil, séries, assistances, fin
ServerScriptService/MapBuilder.lua       construit la carte (Parts, rampes en escaliers, plafonds, spawns, sites)
ServerScriptService/RoundService.lua     mode compétitif 5v5 : cinématique → achat → manche → fin, bombe (ProximityPrompt, pas encore branchée ; ModeConfig.MODE = "bomb")
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
3. Tu apparais sur Village, dans l'équipe orange ou bleue, avec Galil/FAMAS + pistolet + couteau ; 9 bots complètent les équipes.

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

Régénérer les cartes après modification du prototype : `perl tools/export_maps_lua.pl > roblox/ReplicatedStorage/Shared/MapData.lua`

## 2. Correspondance prototype web → Roblox

| Prototype web | Roblox |
|---|---|
| Grille 40×40, 1 case = 2 m, hauteurs, rampes, plafonds | `MapData.lua` + `MapBuilder.lua` (1 stud ≈ 0,28 m ⇒ `STUDS_PER_METER = 3.571`) |
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
- **Menu d'achat en partie** (à faire) : ne proposer que les armes débloquées avec `ShopCatalog.ownsWeapon(profile, key)`.

**Activer les achats Robux** (quand tu auras un compte Roblox et un jeu publié) :
1. Creator Hub → ton expérience → **Monetization → Developer Products** → crée un produit par ligne de `ConfigExtra.SHOP` **et** de `ConfigExtra.EXCLUSIVES` (même nom, même prix en Robux).
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
