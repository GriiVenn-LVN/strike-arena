--!strict
-- ReplicatedStorage/Shared/Modes (ModuleScript, client + serveur)
-- Les modes de jeu, les cartes et les niveaux de bots du jeu web (src/10_core.js MODES, DIFFS ; src/87_nav.js
-- MODE_GROUPS / MODE_TAG ; src/87b_playui.js mapsFor ; src/85_menu.js réglages de l'écran « Jouer »).
-- Le menu (MainMenu) lit ces tables pour afficher les tuiles ; MatchService les lit pour lancer la partie.
local Modes = {}

export type ModeDef = {
	id: string, n: string, ic: string, c: Color3, team: boolean, respawn: number?, desc: string,
	limitLabel: string, limits: { number }, tag: string, time: number?, bomb: boolean?,
}

local function rgb(hex: number): Color3
	return Color3.fromRGB(bit32.rshift(hex, 16), bit32.band(bit32.rshift(hex, 8), 255), bit32.band(hex, 255))
end

-- time = durée de la partie en secondes (web : DM_TIME = 480 s, RTIME des variantes) ; nil = pas de chrono global
Modes.LIST = {
	bomb = { n = "Compétitif", ic = "💣", c = rgb(0xff4655), team = true, bomb = true, desc = "Pose ou désamorce la bombe. Économie, boutique, manches.", limitLabel = "Manches pour gagner", limits = { 3, 5, 7, 13 }, tag = "Bombe · économie · manches" },
	rapid = { n = "Désamorçage rapide", ic = "⚡", c = rgb(0xffd23a), team = true, bomb = true, desc = "Manches de 45 s, armes fournies, bombe dès le début. Pur gunfight.", limitLabel = "Manches pour gagner", limits = { 5, 7, 9 }, tag = "Manches courtes, armes fournies" },
	duel = { n = "Duel", ic = "🤺", c = rgb(0xff7ad9), team = true, desc = "Manches courtes sans bombe ni réapparition. Choisis ton arme, élimine l'adversaire. Premier à 5.", limitLabel = "Manches pour gagner", limits = { 3, 5, 7 }, tag = "Manches courtes, 1 v 1 à 5 v 5, sans bombe" },
	tdm = { n = "Match à mort par équipe", ic = "⚔", c = rgb(0x4aa3ff), team = true, respawn = 3, desc = "Deux équipes, réapparition rapide. Premier à atteindre le score.", limitLabel = "Éliminations pour gagner", limits = { 20, 30, 40, 60 }, tag = "Équipes, réapparition", time = 480 },
	ffa = { n = "Match à mort", ic = "☠", c = rgb(0xffb938), team = false, respawn = 2, desc = "Chacun pour soi. Le meilleur score gagne.", limitLabel = "Éliminations pour gagner", limits = { 15, 25, 35 }, tag = "Chacun pour soi", time = 480 },
	gg = { n = "Course aux armes", ic = "🔫", c = rgb(0x7dff9f), team = false, respawn = 1.5, desc = "Chaque élimination change ton arme. Termine avec le couteau.", limitLabel = "Niveaux", limits = {}, tag = "Une arme par élimination", time = 480 },
	koth = { n = "Capture de zone", ic = "🚩", c = rgb(0x35e0c0), team = true, respawn = 3, desc = "Tiens la zone qui change de place pour marquer des points.", limitLabel = "Points pour gagner", limits = { 100, 200, 300 }, tag = "Tiens la zone", time = 480 },
	dom = { n = "Domination", ic = "🏳", c = rgb(0xffd23a), team = true, respawn = 3, desc = "Trois drapeaux A, B, C à capturer et à tenir. Chaque drapeau tenu rapporte des points.", limitLabel = "Points pour gagner", limits = { 100, 200, 300 }, tag = "Tiens A, B et C", time = 480 },
	kc = { n = "Élimination confirmée", ic = "🏷", c = rgb(0xffcf4a), team = true, respawn = 3, desc = "Chaque adversaire éliminé lâche une plaque : ramasse-la pour marquer. Ramasse celles de tes alliés pour priver l'adversaire du point.", limitLabel = "Plaques pour gagner", limits = { 30, 50, 75 }, tag = "Ramasse les plaques pour marquer", time = 480 },
	ctf = { n = "Capture du drapeau", ic = "🚩", c = rgb(0xff9f43), team = true, respawn = 3, desc = "Va prendre le drapeau adverse et ramène-le dans ta base. Ton drapeau doit être chez toi pour marquer.", limitLabel = "Captures pour gagner", limits = { 3, 5, 7 }, tag = "Ramène le drapeau adverse", time = 600 },
	shp = { n = "Arme tournante", ic = "🎲", c = rgb(0xffa94d), team = false, respawn = 2, desc = "Tout le monde a la même arme, tirée au sort toutes les 30 secondes. Adapte-toi vite !", limitLabel = "Éliminations pour gagner", limits = { 15, 25, 35 }, tag = "Même arme pour tous, elle change", time = 480 },
	zombies = { n = "Zombies (coop)", ic = "🧟", c = rgb(0x8fd14f), team = true, respawn = 0, desc = "Façon Black Ops : points, armes aux murs, boîte mystère, atouts, Forge Arcane et armes prodiges.", limitLabel = "Manches à survivre", limits = { 10, 15, 25, 99 }, tag = "Coop contre des vagues" },
	inf = { n = "Infecté", ic = "☣", c = rgb(0x9dff5a), team = true, respawn = 2.5, desc = "Un joueur commence infecté. Chaque survivant tué rejoint les infectés. Tiens jusqu'à la fin du chrono.", limitLabel = "", limits = {}, tag = "Survis aux infectés", time = 300 },
	jug = { n = "Mastodonte", ic = "🛡", c = rgb(0xff5a3c), team = false, respawn = 2, desc = "Le premier à éliminer devient le Mastodonte : 400 PV et une mitrailleuse. Lui seul marque des points. Élimine-le pour prendre sa place.", limitLabel = "Points pour gagner", limits = { 25, 40, 60 }, tag = "Deviens le Mastodonte et tiens", time = 480 },
	br = { n = "Bataille royale", ic = "🪂", c = rgb(0xc77dff), team = false, respawn = 0, desc = "Un seul survivant. Ramasse des armes, évite la zone qui se resserre.", limitLabel = "", limits = {}, tag = "Un seul survivant" },
	train = { n = "Entraînement", ic = "🎯", c = rgb(0xff9a3a), team = false, respawn = 1, desc = "Cibles mobiles, chronomètre 60 s. Mesure précision et réflexes.", limitLabel = "", limits = {}, tag = "Stand de tir, sans limite de temps" },
} :: { [string]: ModeDef }
for id, m in pairs(Modes.LIST) do m.id = id end

-- ordre des tuiles de l'écran « Jouer » (MODE_GROUPS du web, avec les modes ajoutés par les extensions)
Modes.GROUPS = ({
	{ "Compétitif", { "bomb", "rapid", "duel" } },
	{ "Action", { "tdm", "ffa", "gg", "koth", "dom", "kc", "ctf", "shp" } },
	{ "Spécial", { "zombies", "inf", "jug", "br", "train" } },
} :: any) :: { { any } }

-- Mode de la semaine (FEATURED_ROT du web, src/8D_matchflow.js) : XP ×2, change chaque lundi
Modes.FEATURED_ROT = { "duel", "gg", "koth", "rapid", "ffa", "tdm", "br" }
function Modes.featured(): string
	local week = math.floor((math.floor(os.time() / 86400) + 3) / 7)
	return Modes.FEATURED_ROT[week % #Modes.FEATURED_ROT + 1]
end

-- Partie rapide : modes tirés au hasard (QUICK_MODES du web)
Modes.QUICK = { "tdm", "ffa", "gg", "koth", "dom", "kc", "shp" }

-- Cartes, dans l'ordre du web (MAPS) ; zombie = réservée au mode Zombies
Modes.MAPS = {
	{ id = "village", n = "Village", theme = "sand", desc = "Un village ocre avec toits-terrasses, ruelles étroites, un grand couloir ouvert côté A, un souk couvert côté B et des nids de sniper en hauteur." },
	{ id = "warehouse", n = "Entrepôt", theme = "industrial", desc = "Un dépôt logistique : grande halle de conteneurs, mezzanines, zone de stockage ouest (A) et salle de contrôle sur plateforme à l'est (B)." },
	{ id = "station", n = "Station polaire", theme = "snow", desc = "Un avant-poste de recherche enneigé : base CT sur plateau, hangar à l'ouest (A), salle des générateurs à l'est (B), étang gelé au centre, tour de guet et passerelle en hauteur." },
	{ id = "harbor", n = "Port de nuit", theme = "night", desc = "Un port industriel éclairé aux projecteurs : piles de conteneurs, grutier en hauteur, entrepôt couvert à l'est (B) et quai ouvert à l'ouest (A)." },
	{ id = "metro", n = "Métro", theme = "metro", desc = "Une station souterraine : salle de contrôle des CT, quais surélevés, rames à l'arrêt sur les voies et deux grands halls (A à l'ouest, B à l'est). Tout est couvert." },
	{ id = "jungle", n = "Temple perdu", theme = "jungle", desc = "Des ruines envahies par la jungle : pyramide à gradins au centre (contrôle du milieu), temple couvert côté B, cour aux colonnes côté A." },
	{ id = "range", n = "Stand de tir", theme = "range", desc = "Terrain d'entraînement : cibles fixes, mobiles et surgissantes à toutes les distances, nid de sniper et couvertures pour tester armes et skins." },
	{ id = "labo", n = "Laboratoire", theme = "night", desc = "Un laboratoire abandonné, de nuit : on démarre dans le hall, puis on dégage les débris pour ouvrir la salle des machines, l'infirmerie et le grand labo. Idéal pour les Zombies." },
	{ id = "asile", n = "Asile hanté", theme = "haunt", zombie = true, desc = "Carte Zombies : un asile abandonné une nuit d'orage. On démarre dans la chapelle, puis on dégage les barricades vers le cimetière, le jardin, l'aile des malades et son clocher, l'infirmerie et la crypte." },
	{ id = "manoir", n = "Manoir hanté", theme = "halloween", desc = "Carte d'Halloween : le manoir Ravenhollow une nuit de pleine lune. Site A dans le cimetière, site B sous la grange de la sorcière, le manoir au centre, l'allée des sorcières à l'ouest, le champ de citrouilles à l'est et la fête foraine au sud." },
}
Modes.MAP = {} :: { [string]: any }
for i, m in ipairs(Modes.MAPS) do m.index = i; Modes.MAP[m.id] = m end

-- cartes proposées pour chaque mode (mapsFor du web) : Zombies = Asile, Entraînement = Stand de tir
function Modes.mapsFor(mode: string): { string }
	if mode == "zombies" then return { "asile" } end
	if mode == "train" then return { "range" } end
	local list = {}
	for _, m in ipairs(Modes.MAPS) do if not m.zombie and m.id ~= "range" then table.insert(list, m.id) end end
	return list
end

-- niveaux des bots (DIFFS du web) : react = temps de réaction (s), spread = imprécision (degrés), aimHead = part de tirs à la tête,
-- speed = vitesse, strafe = esquive latérale, hear = ouïe, dmg = dégâts, sight = portée de vue (m), b = rafales, nade = grenades
Modes.DIFFS = {
	{ n = "Novice", react = 1.25, spread = 10, aimHead = 0, speed = 0.78, strafe = 0, hear = 0.2, dmg = 0.55, sight = 40, bmin = 2, bmax = 5, nade = 0.2, desc = "Pour découvrir le jeu : réagit lentement, vise très mal, fait peu de dégâts. En Zombies : zombies lents et fragiles." },
	{ n = "Facile", react = 0.8, spread = 6, aimHead = 0.02, speed = 0.86, strafe = 0.1, hear = 0.4, dmg = 0.8, sight = 55, bmin = 3, bmax = 7, nade = 0.4, desc = "Un adversaire facile à battre, tire en rafales imprécises. En Zombies : zombies moins forts et moins nombreux." },
	{ n = "Normal", react = 0.45, spread = 3, aimHead = 0.12, speed = 0.95, strafe = 0.45, hear = 0.7, dmg = 1, sight = 70, bmin = 4, bmax = 9, nade = 0.6, desc = "Équilibré : se déplace, entend les tirs, vise correctement." },
	{ n = "Pro", react = 0.26, spread = 1.6, aimHead = 0.3, speed = 1, strafe = 0.8, hear = 0.9, dmg = 1, sight = 90, bmin = 5, bmax = 12, nade = 0.8, desc = "Réflexes rapides, strafe + arrêt pour tirer, vise la tête." },
	{ n = "Légende", react = 0.13, spread = 0.75, aimHead = 0.55, speed = 1.05, strafe = 1, hear = 1, dmg = 1.05, sight = 110, bmin = 6, bmax = 16, nade = 1, desc = "Réaction quasi instantanée, headshots constants, grenades utiles." },
}

-- modificateurs de partie (src/8Y_mutators.js), cumulables, pour les parties contre les bots
Modes.MUTATORS = {
	{ k = "lune", ic = "🌙", n = "Gravité lunaire", d = "Sauts géants, chute lente" },
	{ k = "turbo", ic = "⚡", n = "Turbo", d = "Tout le monde court 30 % plus vite" },
	{ k = "tetes", ic = "🎯", n = "Têtes seulement", d = "Seuls les tirs à la tête blessent" },
	{ k = "balle", ic = "💥", n = "Une balle", d = "Chaque touche élimine" },
	{ k = "vamp", ic = "🩸", n = "Vampire", d = "Chaque élimination rend 50 PV" },
	{ k = "nades", ic = "💣", n = "Grenades à volonté", d = "Une grenade revient toutes les 5 s" },
}

-- réglages possibles de l'écran « Jouer » (src/85_menu.js)
function Modes.sizes(mode: string): { number }
	local m = Modes.LIST[mode]
	if mode == "duel" then return { 1, 2, 3, 4, 5 } end
	if m and m.team then
		local mx = if mode == "bomb" or mode == "rapid" then 5 else 8
		local l = {}; for i = 1, mx do l[i] = i end
		return l
	end
	return { 4, 6, 8, 10, 12 }
end
function Modes.defaultLimit(mode: string): number?
	local l = Modes.LIST[mode] and Modes.LIST[mode].limits or {}
	if #l == 0 then return nil end
	if mode == "bomb" then return 5 end
	return l[math.floor(#l / 2) + 1]
end

-- réglages d'une partie, vérifiés (le client peut envoyer n'importe quoi)
export type Settings = { mode: string, map: string, diff: number, size: number, limit: number?, side: string, eco: number, private: boolean, mut: { [string]: boolean } }
function Modes.sanitize(s: any): Settings
	local t = if typeof(s) == "table" then s else {}
	local mode = if typeof(t.mode) == "string" and Modes.LIST[t.mode] then t.mode else "tdm"
	local maps = Modes.mapsFor(mode)
	local map = if typeof(t.map) == "string" and table.find(maps, t.map) then t.map else maps[1]
	local diff = if typeof(t.diff) == "number" then math.clamp(math.floor(t.diff), 1, #Modes.DIFFS) else 3
	local sizes = Modes.sizes(mode)
	local size = if typeof(t.size) == "number" and table.find(sizes, t.size) then t.size else (if Modes.LIST[mode].team then math.min(5, sizes[#sizes]) else 8)
	local lims = Modes.LIST[mode].limits
	local limit = if typeof(t.limit) == "number" and table.find(lims, t.limit) then t.limit else Modes.defaultLimit(mode)
	local side = if t.side == "t" or t.side == "ct" then t.side else "rnd"
	local eco = if t.eco == 0 then 0 else 1
	local mut = {}
	if typeof(t.mut) == "table" then
		for _, m in ipairs(Modes.MUTATORS) do if t.mut[m.k] == true then mut[m.k] = true end end
	end
	return { mode = mode, map = map, diff = diff, size = size, limit = limit, side = side, eco = eco, private = t.private == true, mut = mut }
end

return Modes
