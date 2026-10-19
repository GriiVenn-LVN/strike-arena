--!strict
-- ReplicatedStorage/Shared/MenuConfig (ModuleScript, client + serveur)
-- Textes et listes du menu principal, repris du jeu web : nouveautés (src/87d_lobby.js NEWS), libellés des défis
-- (src/62_meta.js MPOOL, src/8O_defis.js WPOOL), titres de profil (Profil > Style), liste des touches (Réglages > Touches),
-- liste des options et leur nettoyage (Menu/Options côté client, OptionsService côté serveur).
local M = {}

-- Nouveautés de l'accueil ; go = où mène un clic (onglet du menu)
M.NEWS = {
	{ id = "n_rewards", ic = "🎁", t = "Récompenses et passe de combat", d = "Bilan détaillé en fin de partie, calendrier de 7 jours, XP ×2 le week-end et nouveau passe de combat." },
	{ id = "n_gunfight", ic = "🔫", t = "Nouveaux modes : Gunfight et Survolté", d = "Gunfight : 2 contre 2, mêmes armes pour tous. Survolté : élimine toutes les 30 s ou explose !", go = "mode:gunfight" },
	{ id = "n_lobby", ic = "🏠", t = "Nouvel accueil", d = "Défis, nouveautés et récompenses dès l'ouverture du jeu." },
	{ id = "n_online", ic = "🌐", t = "Parties en ligne", d = "JOUER te met avec les autres joueurs du serveur. Les bots complètent s'il en manque.", go = "play" },
	{ id = "n_friends", ic = "👥", t = "Jouer avec des amis, en un écran", d = "Crée un groupe, invite tes amis, lance la partie.", go = "friends" },
	{ id = "n_tab", ic = "📋", t = "Nouveau tableau des scores", d = "Maintiens Tab en partie : score, chrono, MVP en direct." },
	{ id = "n_perk", ic = "🍹", t = "Boissons d'atout et caisses animées", d = "Nouvelles animations d'ouverture et de boisson.", go = "boxes" },
	{ id = "n_csgo", ic = "🔪", t = "Skins façon CS:GO et couteaux", d = "Nouvelles finitions d'armes et couteaux à collectionner.", go = "arms" },
	{ id = "n_camo", ic = "✨", t = "Camos animés", d = "Des camouflages qui bougent, exclusifs.", go = "arms" },
	{ id = "n_modes", ic = "🏳", t = "Domination et Infecté", d = "Deux nouveaux modes : tiens A, B, C ou survis aux infectés.", go = "mode:dom" },
	{ id = "n_kc", ic = "🎥", t = "Kill-cam du tueur", d = "Revois comment tu t'es fait éliminer." },
}

-- Libellés des défis ({t} = objectif)
M.MISSIONS = {
	kills = "Élimine {t} adversaires", hs = "Fais {t} headshots", win = "Gagne {t} partie", matches = "Joue {t} parties",
	plant = "Pose ou désamorce la bombe {t} fois", nade = "Élimine {t} adversaires avec une grenade", knife = "Élimine {t} adversaire au couteau",
	dmg = "Inflige {t} dégâts",
	-- src/8O_defis.js : par type d'arme, par mode, Zombies, Infecté (RewardService.MISSION_POOL)
	k_shotgun = "Élimine {t} adversaires au fusil à pompe", k_sniper = "Élimine {t} adversaires au fusil de précision",
	k_smg = "Élimine {t} adversaires au pistolet-mitrailleur", k_pistol = "Élimine {t} adversaires au pistolet",
	k_rifle = "Élimine {t} adversaires au fusil d'assaut", w_duel = "Gagne {t} Duel", w_dom = "Gagne {t} partie de Domination",
	w_gg = "Gagne {t} Course aux armes", z_wave = "Survis à {t} manches de Zombies", inf_surv = "Termine {t} partie d'Infecté sans être infecté",
	kcTag = "Ramasse {t} plaques en Élimination confirmée",
	w_gunfight = "Gagne {t} Gunfight", w_survolte = "Gagne {t} partie de Survolté",
}
M.WEEKLY = {
	kills = "Élimine {t} adversaires", hs = "Fais {t} headshots", win = "Gagne {t} parties", matches = "Joue {t} parties",
	knife = "Élimine {t} adversaires au couteau", dmg = "Inflige {t} dégâts",
	k_sniper = "Élimine {t} adversaires au fusil de précision", k_shotgun = "Élimine {t} adversaires au fusil à pompe",
	w_duel = "Gagne {t} Duels", w_dom = "Gagne {t} parties de Domination", z_wave = "Survis à {t} manches de Zombies",
	inf_surv = "Termine {t} parties d'Infecté sans être infecté",
}
function M.missionText(id: string, target: number, weekly: boolean?): string
	local t = (if weekly then M.WEEKLY[id] else M.MISSIONS[id]) or M.MISSIONS[id] or id
	return (string.gsub(t, "{t}", tostring(target)))
end

-- Titres de profil débloqués par le niveau (Profil > Style du web) ; les titres de fidélité viennent de LoyaltyConfig.TITLES
M.TITLES = {
	{ id = "recrue", n = "Recrue", lvl = 1 },
	{ id = "lynx", n = "Œil de lynx", lvl = 3 },
	{ id = "ace", n = "As de l'arène", lvl = 5 },
	{ id = "artificier", n = "Artificier", lvl = 7 },
	{ id = "fantome", n = "Fantôme", lvl = 9 },
	{ id = "legende", n = "Légende vivante", lvl = 12 },
}

-- Commandes du jeu Roblox (Réglages > Touches) : clavier, manette
M.KEYS = {
	{ "Avancer / reculer / côtés", "W A S D (Z Q S D)", "Stick gauche" },
	{ "Sauter", "Espace", "A" },
	{ "Sprint", "Maj gauche", "L3" },
	{ "S'accroupir / glissade", "C ou Ctrl gauche", "B" },
	{ "Tirer", "Clic gauche", "RT" },
	{ "Viser (ADS) / lunette", "Clic droit", "LT" },
	{ "Recharger", "R", "X" },
	{ "Arme principale / pistolet / couteau", "1 / 2 / 3", "—" },
	{ "Arme suivante", "Molette", "Y" },
	{ "Inspecter l'arme", "V", "Croix haut" },
	{ "Choisir ses armes", "B", "Croix gauche" },
	{ "Danse / emote", "T", "—" },
	{ "Spray", "J", "—" },
	{ "Mode photo", "F4", "—" },
	{ "Tableau des scores", "Tab (maintenir)", "Select" },
	{ "Libérer la souris", "M", "Start" },
	{ "Menu principal (lobby) / pause (en partie)", "P ou Échap", "Croix bas" },
	{ "Passer la kill-cam", "Espace / clic", "A" },
}

-- Onglets des Réglages (menu principal et pause) : nom affiché et phrase d'aide. La clé reste le nom utilisé par
-- Menu/Options (O.SUBS) ; « Viseur » s'affiche « Point de visée » pour ne pas le confondre avec Arsenal › Viseurs.
M.SETTINGS_TABS = {
	{ id = "Général", n = "Général", help = "Qualité de l'image, sensibilité, champ de vision, compteurs FPS et ping." },
	{ id = "Viseur", n = "Point de visée", help = "La forme et la couleur du repère au centre de l'écran." },
	{ id = "Son", n = "Son", help = "Le volume général et celui de chaque type de son." },
	{ id = "Touches", n = "Touches", help = "Toutes les commandes, au clavier et à la manette." },
	{ id = "Accessibilité", n = "Accessibilité", help = "Couleurs pour daltoniens, sous-titres des sons, taille de l'interface." },
}
function M.settingsTab(id: string): { id: string, n: string, help: string }?
	for _, t in ipairs(M.SETTINGS_TABS) do if t.id == id then return t end end
	return nil
end

-- ---------- Options (Réglages du menu et panneau Réglages de la pause) ----------
-- Même liste côté client (Menu/Options) et côté serveur (OptionsService, qui borne tout avant de l'enregistrer).
-- { "num", min, max, défaut } · { "int", min, max, défaut } · { "bool", défaut } · { "enum", { valeurs }, défaut }
M.OPTIONS = ({
	fov = { "num", 60, 110, 70 }, sens = { "num", 0.1, 4, 1 }, aimSens = { "num", 0.2, 2, 1 },
	quality = { "int", 1, 3, 3 },
	invertY = { "bool", false }, showFps = { "bool", false }, showPing = { "bool", false },
	-- viseur (cfg.xh du web : couleur XHCOL, forme)
	xhColor = { "int", 1, 8, 2 }, xhStyle = { "enum", { "dot", "cross", "circle", "none" }, "dot" },
	-- volumes : vol = général (0,7 = niveau d'origine, comme le curseur du web), les autres multiplient leur groupe (1 = origine)
	vol = { "num", 0, 1, 0.7 }, volWeapons = { "num", 0, 2, 1 }, volSteps = { "num", 0, 2, 1 }, volUi = { "num", 0, 2, 1 },
	volAmbient = { "num", 0, 2, 1 }, volMusic = { "num", 0, 2, 1 },
} :: { [string]: { any } })
-- curseur de volume -> groupe de Shared/Sfx (Sfx.setVolume) -> libellé
M.VOLUME_GROUPS = { { "volWeapons", "weapons", "ARMES" }, { "volSteps", "steps", "PAS" }, { "volUi", "ui", "INTERFACE" },
	{ "volAmbient", "ambient", "AMBIANCE" }, { "volMusic", "music", "MUSIQUE" } }
-- couleurs du viseur (XHCOL de src/85_menu.js) et formes
M.XH_COLORS = { 0x3dffa8, 0xffffff, 0x27e8ff, 0xffe14a, 0xff3b3b, 0xff58d6, 0x8a6bff, 0xff9a2a }
M.XH_STYLES = { { "dot", "Point" }, { "cross", "Croix" }, { "circle", "Cercle" }, { "none", "Aucun" } }
-- accessibilité (AccessibilityController, attribut « Access ») : gardée dans le profil avec les options
M.ACCESS = ({
	colorblind = { "enum", { "none", "deut", "prot", "trit" }, "none" }, subtitles = { "bool", false },
	hudScale = { "num", 0.7, 1.4, 1 }, shake = { "num", 0, 1, 1 },
} :: { [string]: { any } })

local function cleanOne(r: { any }, v: any): any
	local kind = r[1]
	if kind == "num" or kind == "int" then
		if typeof(v) ~= "number" or v ~= v then return r[4] end
		local x = math.clamp(v, r[2], r[3])
		return if kind == "int" then math.floor(x + 0.5) else x
	elseif kind == "bool" then
		return if typeof(v) == "boolean" then v else r[2]
	elseif kind == "enum" then
		return if typeof(v) == "string" and table.find(r[2], v) then v else r[3]
	end
	return nil
end
-- options reçues (client ou profil) -> table propre : seulement les clés connues, bornées, valeur par défaut sinon
function M.cleanOptions(data: any): { [string]: any }
	local src = if typeof(data) == "table" then data else {}
	local out: { [string]: any } = {}
	for k, r in pairs(M.OPTIONS) do out[k] = cleanOne(r, src[k]) end
	local acc = if typeof(src.access) == "table" then src.access else {}
	local a: { [string]: any } = {}
	for k, r in pairs(M.ACCESS) do a[k] = cleanOne(r, acc[k]) end
	-- sensibilité par arme (AccessibilityController) : 40 armes au plus, noms courts
	local ws: { [string]: number } = {}
	local n = 0
	if typeof(acc.weaponSens) == "table" then
		for w, v in pairs(acc.weaponSens) do
			if n >= 40 then break end
			if typeof(w) == "string" and #w <= 24 and typeof(v) == "number" and v == v then ws[w] = math.clamp(v, 0.2, 3); n += 1 end
		end
	end
	a.weaponSens = ws
	out.access = a
	return out
end

return M
