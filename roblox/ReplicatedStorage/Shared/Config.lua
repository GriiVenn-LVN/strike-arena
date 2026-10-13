--!strict
-- Config partagée client + serveur (ReplicatedStorage/Shared/Config)
-- Reprend exactement les valeurs du prototype web pour garder le même "feeling".
local Config = {}

Config.STUDS_PER_METER = 3.571      -- 1 stud ≈ 0.28 m
Config.CELL = 2                     -- 1 case de la grille = 2 mètres
Config.TEAM_SIZE = 5                -- 5 contre 5
Config.ROUND_TIME = 100
Config.FREEZE_TIME = 12
Config.BOMB_TIME = 40
Config.PLANT_TIME = 3.2
Config.DEFUSE_TIME = 5
Config.WIN_ROUNDS = 7
Config.START_MONEY = 800
Config.MAX_MONEY = 16000
Config.SHIELD_MAX = 50

Config.RARITY = {
	{ id = "common", name = "Commun", color = Color3.fromRGB(154, 166, 184) },
	{ id = "rare", name = "Rare", color = Color3.fromRGB(74, 163, 255) },
	{ id = "epic", name = "Épique", color = Color3.fromRGB(179, 107, 255) },
	{ id = "legend", name = "Légendaire", color = Color3.fromRGB(255, 185, 56) },
}

-- Probabilités affichées au joueur (obligatoire pour les objets aléatoires payants sur Roblox)
Config.BOXES = {
	std = { name = "Caisse Standard", coins = 500, weights = { 62, 27, 9, 2 } },
	prem = { name = "Caisse Premium", coins = 1500, weights = { 20, 45, 27, 8 } },
}
Config.PITY = { epic = 10, legend = 40 }          -- Épique garanti toutes les 10 ouvertures, Légendaire toutes les 40
Config.DUPLICATE_VALUE = { 0, 120, 350, 900 }     -- pièces rendues pour un doublon, par rareté

Config.DAILY = {                                  -- série de 7 jours
	{ coins = 200 }, { box = "std" }, { coins = 350 }, { dance = "disco", coins = 150 },
	{ coins = 500 }, { box = "prem" }, { box = "prem", coins = 1000 },
}

Config.DANCES = {                                 -- remplace animationId par tes propres animations (Animation Editor)
	wave = { name = "Salut", rarity = 1, animationId = "rbxassetid://0", length = 3 },
	clap = { name = "Applaudissements", rarity = 1, animationId = "rbxassetid://0", length = 3.4 },
	disco = { name = "Disco", rarity = 2, animationId = "rbxassetid://0", length = 4 },
	robot = { name = "Robot", rarity = 2, animationId = "rbxassetid://0", length = 4 },
	floss = { name = "Floss", rarity = 3, animationId = "rbxassetid://0", length = 4 },
	twist = { name = "Toupie", rarity = 3, animationId = "rbxassetid://0", length = 3.4 },
	moonwalk = { name = "Moonwalk", rarity = 4, animationId = "rbxassetid://0", length = 4.2 },
	break_ = { name = "Breakdance", rarity = 4, animationId = "rbxassetid://0", length = 4 },
}

Config.SKINS = {                                  -- rarity 1..4 ; rarity 1 = gratuit pour toutes les armes ; pattern = nom de la peinture du prototype
	{ name = "Défaut", rarity = 1, pattern = "" },
	{ name = "Noir mat", rarity = 1, pattern = "" },
	{ name = "Or royal", rarity = 4, pattern = "goldleaf" },
	{ name = "Rouge sang", rarity = 2, pattern = "bloodfade" },
	{ name = "Bleu néon", rarity = 3, pattern = "neonlines" },
	{ name = "Arctique", rarity = 1, pattern = "frost" },
	{ name = "Violet nacré", rarity = 3, pattern = "pearl" },
	{ name = "Cœurs", rarity = 2, pattern = "hearts" },
	{ name = "Camo forêt", rarity = 1, pattern = "camoForest" },
	{ name = "Camo désert", rarity = 1, pattern = "camoDesert" },
	{ name = "Carbone", rarity = 2, pattern = "hex" },
	{ name = "Vapeur", rarity = 2, pattern = "brass" },
	{ name = "Dragon", rarity = 3, pattern = "flame" },
	{ name = "Galaxie", rarity = 4, pattern = "galaxy" },
	{ name = "Tigre", rarity = 2, pattern = "tiger" },
	{ name = "Toxique", rarity = 3, pattern = "toxic" },
	{ name = "Circuit", rarity = 3, pattern = "circuit" },
	{ name = "Marbre", rarity = 3, pattern = "marble" },
	{ name = "Damas", rarity = 2, pattern = "damascus" },
	{ name = "Bois précieux", rarity = 2, pattern = "burl" },
	{ name = "Coucher de soleil", rarity = 2, pattern = "sunset" },
	{ name = "Course", rarity = 2, pattern = "racing" },
	{ name = "Danger", rarity = 1, pattern = "hazard" },
	{ name = "Léopard", rarity = 2, pattern = "leopard" },
	{ name = "Écailles", rarity = 3, pattern = "scales" },
	{ name = "Cristal", rarity = 3, pattern = "ice" },
	{ name = "Lave", rarity = 4, pattern = "lava" },
	{ name = "Graffiti", rarity = 2, pattern = "graffiti" },
	{ name = "Matrice", rarity = 3, pattern = "matrix" },
	{ name = "Sakura", rarity = 3, pattern = "sakura" },
	{ name = "Bonbon", rarity = 2, pattern = "candy" },
	{ name = "Océan", rarity = 2, pattern = "ocean" },
	{ name = "Étoilé", rarity = 1, pattern = "stars" },
	{ name = "Hologramme", rarity = 4, pattern = "holo" },
	{ name = "Digital", rarity = 1, pattern = "digital" },
	{ name = "Damier", rarity = 1, pattern = "checker" },
	{ name = "Nuages", rarity = 2, pattern = "clouds" },
	{ name = "Filigrane royal", rarity = 4, pattern = "royal" },
	{ name = "Arcade", rarity = 3, pattern = "pixel8" },
}

-- Tenues de soldat (rarity 1 = gratuit)
Config.OUTFITS = {
	{ name = "Équipe", rarity = 1, head = "team" },
	{ name = "Opérateur nocturne", rarity = 1, head = "helm" },
	{ name = "Ranger forêt", rarity = 1, head = "helm" },
	{ name = "Patrouille polaire", rarity = 1, head = "hood" },
	{ name = "Urbain", rarity = 2, head = "cap" },
	{ name = "Pilote de course", rarity = 2, head = "cap" },
	{ name = "Pirate", rarity = 2, head = "bandana" },
	{ name = "Chef étoilé", rarity = 2, head = "toque" },
	{ name = "Samouraï", rarity = 3, head = "horns" },
	{ name = "Cyber néon", rarity = 3, head = "visor" },
	{ name = "Astronaute", rarity = 3, head = "bubble" },
	{ name = "Roi doré", rarity = 4, head = "crown" },
	{ name = "Licorne", rarity = 4, head = "unicorn" },
	{ name = "Robot chrome", rarity = 4, head = "robot" },
}

-- Armes (valeurs identiques au prototype web). cat : pistol/smg/shotgun/rifle/sniper/lmg/melee
Config.WEAPONS = {
	knife = { name = "Couteau", slot = 2, cat = "melee", price = 0, dmg = 40, pellets = 1, hs = 1, rpm = 110, auto = true, mag = 0, reserve = 0, reload = 0, spread = 0, recoil = 0, speed = 1.08, kill = 1500, armorPen = 0.8, zoom = 0, melee = true },
	glock = { name = "Glock-18", slot = 1, cat = "pistol", price = 0, dmg = 27, pellets = 1, hs = 3.2, rpm = 400, auto = false, mag = 20, reserve = 120, reload = 2.2, spread = 0.5, recoil = 0.9, speed = 1, kill = 300, armorPen = 0.47, zoom = 0, melee = false },
	usp = { name = "USP-S", slot = 1, cat = "pistol", price = 0, dmg = 32, pellets = 1, hs = 3.4, rpm = 340, auto = false, mag = 12, reserve = 24, reload = 2.2, spread = 0.4, recoil = 1, speed = 1, kill = 300, armorPen = 0.5, zoom = 0, melee = false },
	p250 = { name = "P250", slot = 1, cat = "pistol", price = 300, dmg = 38, pellets = 1, hs = 3.4, rpm = 380, auto = false, mag = 13, reserve = 26, reload = 2.2, spread = 0.5, recoil = 1.1, speed = 1, kill = 300, armorPen = 0.64, zoom = 0, melee = false },
	fiveseven = { name = "Five-SeveN", slot = 1, cat = "pistol", price = 500, dmg = 31, pellets = 1, hs = 3.4, rpm = 380, auto = false, mag = 20, reserve = 100, reload = 2.2, spread = 0.45, recoil = 0.9, speed = 1, kill = 300, armorPen = 0.91, zoom = 0, melee = false },
	deagle = { name = "Desert Eagle", slot = 1, cat = "pistol", price = 700, dmg = 62, pellets = 1, hs = 3, rpm = 150, auto = false, mag = 7, reserve = 35, reload = 2.2, spread = 0.6, recoil = 4, speed = 0.97, kill = 300, armorPen = 0.93, zoom = 0, melee = false },
	mac10 = { name = "MAC-10", slot = 0, cat = "smg", price = 1050, dmg = 29, pellets = 1, hs = 2.8, rpm = 800, auto = true, mag = 30, reserve = 100, reload = 2.6, spread = 1.3, recoil = 0.5, speed = 1, kill = 600, armorPen = 0.57, zoom = 0, melee = false },
	mp9 = { name = "MP9", slot = 0, cat = "smg", price = 1250, dmg = 26, pellets = 1, hs = 2.8, rpm = 800, auto = true, mag = 30, reserve = 120, reload = 2.1, spread = 1, recoil = 0.45, speed = 1, kill = 600, armorPen = 0.6, zoom = 0, melee = false },
	ump = { name = "UMP-45", slot = 0, cat = "smg", price = 1200, dmg = 35, pellets = 1, hs = 2.6, rpm = 600, auto = true, mag = 25, reserve = 100, reload = 3.5, spread = 0.9, recoil = 0.55, speed = 0.95, kill = 600, armorPen = 0.65, zoom = 0, melee = false },
	p90 = { name = "P90", slot = 0, cat = "smg", price = 2350, dmg = 25, pellets = 1, hs = 2.6, rpm = 900, auto = true, mag = 50, reserve = 100, reload = 3.3, spread = 1.1, recoil = 0.4, speed = 0.96, kill = 300, armorPen = 0.69, zoom = 0, melee = false },
	nova = { name = "Nova", slot = 0, cat = "shotgun", price = 1050, dmg = 10, pellets = 9, hs = 1.5, rpm = 70, auto = false, mag = 8, reserve = 32, reload = 3.2, spread = 3.8, recoil = 4, speed = 0.97, kill = 900, armorPen = 0.5, zoom = 0, melee = false },
	sawedoff = { name = "Sawed-Off", slot = 0, cat = "shotgun", price = 1100, dmg = 12, pellets = 8, hs = 1.5, rpm = 60, auto = false, mag = 2, reserve = 32, reload = 3.4, spread = 6, recoil = 5, speed = 0.96, kill = 900, armorPen = 0.5, zoom = 0, melee = false },
	xm = { name = "XM1014", slot = 0, cat = "shotgun", price = 2000, dmg = 10, pellets = 8, hs = 1.5, rpm = 190, auto = true, mag = 7, reserve = 32, reload = 3.6, spread = 4, recoil = 3, speed = 0.96, kill = 900, armorPen = 0.5, zoom = 0, melee = false },
	galil = { name = "Galil AR", slot = 0, cat = "rifle", price = 1800, dmg = 30, pellets = 1, hs = 3.5, rpm = 650, auto = true, mag = 35, reserve = 90, reload = 3.2, spread = 0.4, recoil = 0.6, speed = 0.92, kill = 300, armorPen = 0.775, zoom = 0, melee = false },
	famas = { name = "FAMAS", slot = 0, cat = "rifle", price = 2050, dmg = 30, pellets = 1, hs = 3.5, rpm = 666, auto = true, mag = 25, reserve = 90, reload = 3.3, spread = 0.35, recoil = 0.55, speed = 0.94, kill = 300, armorPen = 0.7, zoom = 0, melee = false },
	ak = { name = "AK-47", slot = 0, cat = "rifle", price = 2700, dmg = 36, pellets = 1, hs = 4, rpm = 600, auto = true, mag = 30, reserve = 90, reload = 2.5, spread = 0.25, recoil = 0.8, speed = 0.9, kill = 300, armorPen = 0.775, zoom = 0, melee = false },
	m4 = { name = "M4A4", slot = 0, cat = "rifle", price = 3100, dmg = 33, pellets = 1, hs = 3.8, rpm = 666, auto = true, mag = 30, reserve = 90, reload = 3.1, spread = 0.2, recoil = 0.6, speed = 0.92, kill = 300, armorPen = 0.7, zoom = 0, melee = false },
	sg553 = { name = "SG 553", slot = 0, cat = "rifle", price = 3000, dmg = 30, pellets = 1, hs = 4, rpm = 600, auto = true, mag = 30, reserve = 90, reload = 3.1, spread = 0.25, recoil = 0.5, speed = 0.9, kill = 300, armorPen = 0.8, zoom = 1.8, melee = false },
	aug = { name = "AUG", slot = 0, cat = "rifle", price = 3300, dmg = 28, pellets = 1, hs = 3.8, rpm = 600, auto = true, mag = 30, reserve = 90, reload = 3.8, spread = 0.25, recoil = 0.45, speed = 0.9, kill = 300, armorPen = 0.85, zoom = 1.8, melee = false },
	ssg = { name = "SSG 08", slot = 0, cat = "sniper", price = 1700, dmg = 88, pellets = 1, hs = 3, rpm = 48, auto = false, mag = 10, reserve = 90, reload = 3.7, spread = 0.05, recoil = 5, speed = 0.96, kill = 300, armorPen = 0.85, zoom = 3, melee = false },
	awp = { name = "AWP", slot = 0, cat = "sniper", price = 4750, dmg = 115, pellets = 1, hs = 4, rpm = 42, auto = false, mag = 5, reserve = 30, reload = 3.7, spread = 0.02, recoil = 7, speed = 0.88, kill = 100, armorPen = 0.95, zoom = 3.5, melee = false },
	scar = { name = "SCAR-20", slot = 0, cat = "sniper", price = 5000, dmg = 80, pellets = 1, hs = 3.5, rpm = 240, auto = true, mag = 20, reserve = 90, reload = 3.1, spread = 0.1, recoil = 3, speed = 0.84, kill = 300, armorPen = 0.825, zoom = 2.6, melee = false },
	negev = { name = "Negev", slot = 0, cat = "lmg", price = 1700, dmg = 30, pellets = 1, hs = 3.3, rpm = 1000, auto = true, mag = 150, reserve = 300, reload = 5.8, spread = 1.5, recoil = 0.6, speed = 0.78, kill = 300, armorPen = 0.75, zoom = 0, melee = false },
	m249 = { name = "M249", slot = 0, cat = "lmg", price = 5200, dmg = 32, pellets = 1, hs = 3.5, rpm = 750, auto = true, mag = 100, reserve = 200, reload = 5.7, spread = 0.6, recoil = 0.5, speed = 0.82, kill = 300, armorPen = 0.8, zoom = 0, melee = false },
}

Config.GUN_GAME_LADDER = { "glock", "p250", "fiveseven", "deagle", "mac10", "mp9", "ump", "nova", "xm", "galil", "famas", "ak", "m4", "sg553", "ssg", "awp", "knife" }

-- Récompenses de progression
function Config.xpNeeded(level: number): number
	return 100 + level * 55
end

return Config
