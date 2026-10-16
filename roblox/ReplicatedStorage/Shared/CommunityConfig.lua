--!strict
-- ReplicatedStorage/Shared/CommunityConfig (ModuleScript)
-- Réglages des ajouts « façon Roblox » : lobby jouable, duels 1v1 / 2v2, classement géant, groupe Roblox.
-- Partagé client / serveur. Les CODES PROMO ne sont PAS ici (le client pourrait les lire) : voir ServerScriptService/CodeList.
local CommunityConfig = {}

-- ---------- Lobby ----------
-- true = les joueurs arrivent dans le lobby et rejoignent le match à mort par le portail (ou le bouton « Jouer »).
-- false = ancien fonctionnement : tout le monde va directement dans le match.
CommunityConfig.LOBBY_ENABLED = true

CommunityConfig.LOBBY = {
	origin = Vector3.new(0, 0, -700),   -- loin de la carte (les bots ne voient qu'à 160 studs)
	size = 240,                         -- côté du sol en studs
	-- armes prêtées dans le lobby pour le stand de tir (personne ne peut blesser personne dans le lobby)
	loadout = { "galil", "glock", "knife" },
	range = {
		duration = 30,                  -- défi « 30 secondes » au stand de tir
		visibleTargets = 3,
		firstReward = 20,               -- cibles à toucher pour la récompense (une seule fois)
		rewardCoins = 50,
	},
	parkour = {
		rewardCoins = 75,               -- premier parcours terminé (une seule fois)
	},
}

-- ---------- Duels façon Rivals ----------
CommunityConfig.DUEL = {
	roundsToWin = 5,                    -- premier à 5 manches
	roundTime = 60,                     -- au-delà, l'équipe qui a le plus de vie gagne la manche
	countdown = 3,
	-- arme principale : celle choisie au menu de chargement si elle existe, sinon celle-ci
	defaultPrimary = "galil",
	secondary = "deagle",
	startElo = 1000,
	eloK = 32,
	-- plateformes dans le lobby : chacune lance un duel quand elle est pleine
	pads = {
		{ id = "1v1", size = 1, stake = 0, name = "Duel 1v1" },
		{ id = "1v1s", size = 1, stake = 100, name = "Duel 1v1 · mise" },
		{ id = "2v2", size = 2, stake = 0, name = "Duel 2v2" },
		{ id = "2v2s", size = 2, stake = 100, name = "Duel 2v2 · mise" },
	},
	arenaOrigin = Vector3.new(2000, 0, 2000),   -- les arènes sont construites ici, espacées de 400 studs
}

-- Rangs de duel (affichés à côté du classement)
CommunityConfig.DUEL_RANKS = {
	{ elo = 0, name = "Bronze", color = Color3.fromRGB(205, 127, 50) },
	{ elo = 1100, name = "Argent", color = Color3.fromRGB(200, 205, 215) },
	{ elo = 1250, name = "Or", color = Color3.fromRGB(255, 200, 60) },
	{ elo = 1400, name = "Platine", color = Color3.fromRGB(90, 220, 220) },
	{ elo = 1600, name = "Diamant", color = Color3.fromRGB(120, 160, 255) },
	{ elo = 1850, name = "Champion", color = Color3.fromRGB(255, 80, 120) },
}
function CommunityConfig.duelRank(elo: number)
	local best = CommunityConfig.DUEL_RANKS[1]
	for _, r in ipairs(CommunityConfig.DUEL_RANKS) do if elo >= r.elo then best = r end end
	return best
end

-- ---------- Classement géant ----------
CommunityConfig.LEADERBOARD = {
	refresh = 120,                      -- secondes entre deux mises à jour du panneau
	top = 10,
}
-- Semaine courante (lundi 00:00 UTC) : sert de nom au classement hebdomadaire
function CommunityConfig.weekId(t: number?): number
	return math.floor(((t or os.time()) - 4 * 86400) / 604800)   -- le 1er janvier 1970 était un jeudi
end
function CommunityConfig.secondsToNextWeek(t: number?): number
	local now = t or os.time()
	return (CommunityConfig.weekId(now) + 1) * 604800 + 4 * 86400 - now
end

-- ---------- Groupe Roblox ----------
-- Crée le groupe sur roblox.com puis colle son identifiant ici (0 = groupe pas encore créé, bouton désactivé).
CommunityConfig.GROUP = {
	id = 0,
	reward = { coins = 200, killfx = "spirit" },   -- donné une seule fois
	-- rappel du « J'aime » : Roblox ne donne aucun moyen de vérifier qu'un joueur a mis un like,
	-- on se contente donc d'un petit rappel, sans récompense (impossible à contrôler, donc facile à tricher).
	likeReminderAfter = 600,            -- secondes de jeu avant le rappel (une fois par session)
}

return CommunityConfig
