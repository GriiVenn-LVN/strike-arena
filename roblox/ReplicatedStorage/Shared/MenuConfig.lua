--!strict
-- ReplicatedStorage/Shared/MenuConfig (ModuleScript, client + serveur)
-- Textes et listes du menu principal, repris du jeu web : nouveautés (src/87d_lobby.js NEWS), libellés des défis
-- (src/62_meta.js MPOOL, src/8O_defis.js WPOOL), titres de profil (Profil > Style), liste des touches (Réglages > Touches).
local M = {}

-- Nouveautés de l'accueil ; go = où mène un clic (onglet du menu)
M.NEWS = {
	{ id = "n_lobby", ic = "🏠", t = "Nouvel accueil", d = "Défis, nouveautés et récompenses dès l'ouverture du jeu." },
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
	{ "Menu principal", "P", "Croix bas" },
	{ "Passer la kill-cam", "Espace / clic", "A" },
}

return M
