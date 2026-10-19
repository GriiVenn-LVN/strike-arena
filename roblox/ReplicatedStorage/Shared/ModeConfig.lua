--!strict
-- ReplicatedStorage/Shared/ModeConfig (ModuleScript)
-- Réglages du mode de jeu lancé par Main, des bots et des sons de combat.
-- Partagé client / serveur : le HUD lit les mêmes valeurs que le serveur.
local ModeConfig = {}

-- Mode de la « Partie rapide » quand le lobby est désactivé (CommunityConfig.LOBBY_ENABLED = false) ; sinon chacun choisit dans le menu
ModeConfig.MODE = "tdm"

ModeConfig.TDM = {
	map = "village",
	killsToWin = 50,           -- première équipe à 50 éliminations
	matchTime = 480,           -- 8 minutes maximum
	respawnDelay = 3,
	spawnProtection = 2,       -- secondes d'invulnérabilité après l'apparition (annulée dès qu'on tire)
	teamSize = 5,              -- 5 contre 5 : les places vides sont prises par des bots
	minHumans = 1,             -- une partie démarre dès qu'un joueur est là (les bots complètent)
	intermission = 15,         -- écran de fin puis nouvelle partie
	teams = { "Attaquants", "Défenseurs" },
	-- armes de départ : la principale peut être changée (SetLoadout) parmi les armes possédées
	loadout = {
		Attaquants = { primary = "galil", secondary = "glock" },
		["Défenseurs"] = { primary = "famas", secondary = "usp" },
	},
	scorePerKill = 100,
	scorePerAssist = 50,
	streaks = { [3] = "Série de 3", [5] = "Inarrêtable", [7] = "Déchaîné", [10] = "Légendaire" },
}

-- Viseur : pas de croix de hanche (comme sur le web), seulement un petit point central.
-- Mets false pour l'enlever aussi ; il disparaît de toute façon quand tu vises (clic droit).
ModeConfig.CENTER_DOT = true

ModeConfig.BOT = {
	names = { "Renard", "Faucon", "Loup", "Vipère", "Ours", "Lynx", "Corbeau", "Puma", "Requin", "Cobra" },
	reaction = 0.45,           -- délai avant le premier tir quand un ennemi apparaît (s)
	aimErrorDeg = 3.2,         -- imprécision de visée (degrés)
	viewDistance = 160,        -- studs
	fov = 0.25,                -- produit scalaire minimum (≈ 150° de champ de vision)
	burst = { 3, 7 },          -- balles par rafale pour les armes automatiques
	thinkRate = 0.1,           -- le cerveau des bots tourne à 10 Hz
	-- armes des bots, tirées au hasard à chaque apparition
	primaries = { "galil", "famas", "ak", "m4", "ump", "mac10", "nova" },
}

-- Sons. Les vrais sons du jeu web sont dans UN fichier, « strike-arena-sons.ogg » (fait par tools/render_sounds.js) :
-- importe-le dans le Creator Hub (Créations → Audio) et colle son numéro ici. Tant que SOUND_SHEET vaut 0,
-- les sons rbxasset:// fournis avec Roblox (champ id) servent de remplacement.
-- sheet = nom du son dans la planche (ReplicatedStorage/Shared/SoundSheet.lua).
ModeConfig.SOUND_SHEET = 99180356518561
ModeConfig.SOUNDS = {
	fire = {
		pistol = { sheet = "pistol", id = "rbxasset://sounds/snap.wav", volume = 0.6, pitch = 1.25 },
		smg = { sheet = "smg", id = "rbxasset://sounds/snap.wav", volume = 0.55, pitch = 1.4 },
		rifle = { sheet = "rifle", id = "rbxasset://sounds/snap.wav", volume = 0.7, pitch = 1.0 },
		shotgun = { sheet = "shotgun", id = "rbxasset://sounds/Rocket shot.wav", volume = 0.6, pitch = 1.6 },
		sniper = { sheet = "sniper", id = "rbxasset://sounds/Rocket shot.wav", volume = 0.8, pitch = 1.2 },
		lmg = { sheet = "lmg", id = "rbxasset://sounds/snap.wav", volume = 0.65, pitch = 0.9 },
		melee = { sheet = "knife", id = "rbxasset://sounds/swordlunge.wav", volume = 0.6, pitch = 1.0 },
	},
	reload = { sheet = "reload", id = "rbxasset://sounds/clickfast.wav", volume = 0.5, pitch = 0.8 },
	empty = { sheet = "click", id = "rbxasset://sounds/clickfast.wav", volume = 0.4, pitch = 1.6 },
	-- touches : un « clac » sourd sur le corps, un « ding » métallique à la tête, un coup grave à l'élimination
	hitBody = { sheet = "hit", id = "rbxasset://sounds/swordhit.wav", volume = 0.55, pitch = 1.5 },
	hitHead = { sheet = "hs", id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.7, pitch = 1.35 },
	kill = { sheet = "kill", id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.9, pitch = 0.75 },
	hurt = { sheet = "dmg", id = "rbxasset://sounds/swordhit.wav", volume = 0.6, pitch = 0.7 },
	streak = { sheet = "round", id = "rbxasset://sounds/victory.wav", volume = 0.5, pitch = 1.1 },
	-- animations d'arme et déplacements
	magout = { sheet = "magout", id = "rbxasset://sounds/clickfast.wav", volume = 0.35, pitch = 0.7 },
	magin = { sheet = "magin", id = "rbxasset://sounds/clickfast.wav", volume = 0.45, pitch = 0.9 },
	rack = { sheet = "rack", id = "rbxasset://sounds/clickfast.wav", volume = 0.45, pitch = 1.2 },
	bolt = { sheet = "bolt", id = "rbxasset://sounds/clickfast.wav", volume = 0.45, pitch = 1.0 },
	pump = { sheet = "pump", id = "rbxasset://sounds/clickfast.wav", volume = 0.5, pitch = 0.75 },
	shellin = { sheet = "shellin", id = "rbxasset://sounds/clickfast.wav", volume = 0.3, pitch = 1.3 },
	draw = { sheet = "draw", id = "rbxasset://sounds/unsheath.wav", volume = 0.3, pitch = 1.2 },
	knife = { sheet = "knife", id = "rbxasset://sounds/swordlunge.wav", volume = 0.5, pitch = 1.0 },
	slide = { sheet = "slide" },
	land = { sheet = "land" },
	jump = { sheet = "jump" },
}

-- Réglages du mixage (lus par Sfx et AmbienceController). Les volumes réglables par le joueur passent par Sfx.setVolume.
-- MIX : niveau de base et égaliseur (dB : graves, médiums, aigus) de chaque groupe, comme l'égaliseur du jeu web
-- (graves un peu renforcés, aigus perçants adoucis).
ModeConfig.SOUNDS.MIX = {
	weapons = { vol = 1, low = 2, mid = -2.5, high = -5 },
	steps = { vol = 1, low = 1, mid = 0, high = -4 },
	ui = { vol = 1, low = 0, mid = -1, high = -3 },
	ambient = { vol = 1, low = 0, mid = 0, high = -6 },
	music = { vol = 0.7, low = 0, mid = 0, high = 0 },
}

-- Réverbération selon le lieu : decay = durée (s), wet / dry = niveau de la salle / du son direct (dB),
-- echo = écho lointain ajouté à la queue des tirs (dehors seulement : un mur ou une colline renvoie le coup).
ModeConfig.SOUNDS.ACOUSTICS = {
	lobby = { decay = 0.8, wet = -16, dry = 0, density = 0.6, diffusion = 0.5 },
	open = { decay = 0.7, wet = -18, dry = 0, density = 0.5, diffusion = 0.4, echo = { delay = 0.34, feedback = 0.3, wet = -10 } },
	town = { decay = 1.0, wet = -14, dry = 0, density = 0.7, diffusion = 0.6, echo = { delay = 0.22, feedback = 0.35, wet = -9 } },
	snow = { decay = 0.6, wet = -20, dry = 0, density = 0.4, diffusion = 0.3, echo = { delay = 0.45, feedback = 0.25, wet = -13 } },
	forest = { decay = 1.1, wet = -15, dry = 0, density = 0.9, diffusion = 1, echo = { delay = 0.28, feedback = 0.3, wet = -12 } },
	covered = { decay = 1.2, wet = -9, dry = 0, density = 0.8, diffusion = 0.7, indoor = true },
	hall = { decay = 1.9, wet = -8, dry = 0, density = 0.8, diffusion = 0.8, indoor = true },
	tunnel = { decay = 2.6, wet = -6, dry = -1, density = 0.9, diffusion = 0.7, indoor = true },
	lab = { decay = 1.3, wet = -9, dry = 0, density = 1, diffusion = 0.9, indoor = true },
	stone = { decay = 2.0, wet = -7, dry = 0, density = 0.7, diffusion = 0.6, indoor = true },
}

-- Fonds sonores en boucle (sons fournis avec Roblox) : rate = vitesse de lecture (plus bas = plus grave),
-- vol = volume, high / mid = égaliseur (dB), gust = force des rafales (variation lente du volume, 0 = constant).
ModeConfig.SOUNDS.AMBIENCE = {
	wind = { { id = "rbxasset://sounds/action_falling.mp3", rate = 0.45, vol = 0.16, high = -14, mid = -3, gust = 0.4 } },
	windSoft = { { id = "rbxasset://sounds/action_falling.mp3", rate = 0.38, vol = 0.1, high = -18, mid = -4, gust = 0.3 } },
	windStrong = { { id = "rbxasset://sounds/action_falling.mp3", rate = 0.52, vol = 0.24, high = -10, mid = -2, gust = 0.55 } },
	hum = { { id = "rbxasset://sounds/action_falling.mp3", rate = 0.22, vol = 0.11, high = -30, mid = -6, gust = 0.06 } },
	harbor = {
		{ id = "rbxasset://sounds/action_falling.mp3", rate = 0.42, vol = 0.12, high = -16, mid = -3, gust = 0.4 },
		{ id = "rbxasset://sounds/action_swim.mp3", rate = 0.55, vol = 0.07, high = -12, mid = -2, gust = 0.5 },
	},
	haunt = { { id = "rbxasset://sounds/action_falling.mp3", rate = 0.3, vol = 0.13, high = -20, mid = -4, gust = 0.65 } },
}

-- Cartes : out = acoustique à l'air libre, inn = sous un toit (plafond détecté au-dessus de la caméra),
-- floor / raised = sol de la carte / dessus des caisses, plateformes et rampes, ambience = fond sonore (AMBIENCE).
ModeConfig.SOUNDS.MAPS = {
	village = { out = "town", inn = "covered", floor = "sand", raised = "stone", ambience = "wind" },
	warehouse = { out = "town", inn = "hall", floor = "stone", raised = "metal", ambience = "hum" },
	station = { out = "snow", inn = "covered", floor = "snow", raised = "snow", ambience = "windStrong" },
	harbor = { out = "town", inn = "covered", floor = "stone", raised = "metal", ambience = "harbor" },
	metro = { out = "tunnel", inn = "tunnel", floor = "stone", raised = "metal", ambience = "hum" },
	jungle = { out = "forest", inn = "stone", floor = "grass", raised = "stone", ambience = "windSoft" },
	range = { out = "town", inn = "hall", floor = "stone", raised = "metal", ambience = "hum" },
	labo = { out = "lab", inn = "lab", floor = "stone", raised = "metal", ambience = "hum" },
	asile = { out = "open", inn = "stone", floor = "sand", raised = "wood", ambience = "haunt" },
	manoir = { out = "open", inn = "stone", floor = "sand", raised = "wood", ambience = "haunt" },
}

-- Pas : couches jouées pour un pas sur chaque sol (sheet = son de la planche, rate = vitesse, vol = volume,
-- delay = décalage en s). Le volume se donne comme pour sfx('step') du web (0,28 en marchant, 0,36 en sprint).
ModeConfig.SOUNDS.STEPS = {
	sand = { { sheet = "jump", rate = 0.93, vol = 1.7 } },
	grass = { { sheet = "jump", rate = 0.85, vol = 1.5 } },
	snow = { { sheet = "jump", rate = 0.72, vol = 1.45 }, { sheet = "slide", rate = 2.2, vol = 0.12 } },
	stone = { { sheet = "jump", rate = 1.75, vol = 1.5 } },
	wood = { { sheet = "jump", rate = 1.25, vol = 1.5 }, { sheet = "land", rate = 1.9, vol = 0.25 } },
	metal = { { sheet = "jump", rate = 2.1, vol = 1.6 }, { sheet = "shellin", rate = 0.6, vol = 0.55, delay = 0.01 } },
}

return ModeConfig
