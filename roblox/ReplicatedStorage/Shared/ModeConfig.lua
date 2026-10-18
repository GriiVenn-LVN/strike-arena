--!strict
-- ReplicatedStorage/Shared/ModeConfig (ModuleScript)
-- Réglages du mode de jeu lancé par Main, des bots et des sons de combat.
-- Partagé client / serveur : le HUD lit les mêmes valeurs que le serveur.
local ModeConfig = {}

-- "tdm" = match à mort par équipe (premier mode jouable) ; "bomb" = compétitif 5v5 (RoundService, bombe pas encore branchée)
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
ModeConfig.SOUND_SHEET = 0
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
}

return ModeConfig
