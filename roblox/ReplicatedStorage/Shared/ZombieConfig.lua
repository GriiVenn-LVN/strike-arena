--!strict
-- ReplicatedStorage/Shared/ZombieConfig (ModuleScript, client + serveur)
-- Données des modes Zombies et Bataille royale du jeu web :
--   src/69_zombies.js (armes prodiges, atouts, armes murales, boîte mystère, Forge Arcane, bonus),
--   src/69z_extra.js (portes, manches spéciales, boss), src/8K_zammo.js (porteurs de munitions),
--   src/8L_zdiff.js (difficulté des zombies), src/61_variants.js + src/8G_rounds.js (vagues, zone de la bataille royale, butin).
-- registerWeapons() ajoute les armes prodiges à Config.WEAPONS (emplacement 3 : jamais proposées dans les menus).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Z = {}

local function rgb(hex: number): Color3
	return Color3.fromRGB(bit32.rshift(hex, 16), bit32.band(bit32.rshift(hex, 8), 255), bit32.band(hex, 255))
end
Z.rgb = rgb

-- ---------- armes prodiges (W.raygun / thunder / winter du web) ----------
-- look = arme du jeu dont on reprend le modèle 3D
Z.WONDERS = {
	raygun = { name = "Rayon X", slot = 3, cat = "wonder", wonder = "ray", price = 0, dmg = 300, pellets = 1, hs = 1, rpm = 180, auto = false, mag = 8, reserve = 24,
		reload = 2.6, spread = 0.3, recoil = 1.2, speed = 1, kill = 10, armorPen = 1, zoom = 0, melee = false, look = "deagle", color = rgb(0xc0392b) },
	thunder = { name = "Canon Tonnerre", slot = 3, cat = "wonder", wonder = "thunder", price = 0, dmg = 2000, pellets = 1, hs = 1, rpm = 40, auto = false, mag = 2, reserve = 6,
		reload = 4, spread = 0, recoil = 6, speed = 0.92, kill = 10, armorPen = 1, zoom = 0, melee = false, look = "nova", color = rgb(0x8a6a3a) },
	winter = { name = "Souffle Givré", slot = 3, cat = "wonder", wonder = "ice", price = 0, dmg = 140, pellets = 1, hs = 1, rpm = 120, auto = true, mag = 6, reserve = 18,
		reload = 3, spread = 0, recoil = 2, speed = 0.95, kill = 10, armorPen = 1, zoom = 0, melee = false, look = "p90", color = rgb(0x6ed6ff) },
}

local registered = false
function Z.registerWeapons()
	if registered then return end
	registered = true
	local Config = require(ReplicatedStorage.Shared.Config) :: any
	local okI, Info = pcall(require, ReplicatedStorage.Shared.WeaponInfo)
	for k, w in pairs(Z.WONDERS) do
		if not Config.WEAPONS[k] then Config.WEAPONS[k] = w end
		if okI and typeof(Info) == "table" and not (Info :: any)[k] then (Info :: any)[k] = (Info :: any)[w.look] end
		-- modèle 3D : copie du modèle de l'arme de base (faite par le serveur, elle est répliquée à tout le monde)
		if RunService:IsServer() then
			local folder = ReplicatedStorage.Shared:FindFirstChild("WeaponMeshes")
			local src = folder and folder:FindFirstChild(w.look)
			if folder and src and not folder:FindFirstChild(k) then
				local c = src:Clone(); c.Name = k; c.Parent = folder
			end
		end
	end
end
function Z.isWonder(key: string?): boolean return key ~= nil and Z.WONDERS[key] ~= nil end

-- ---------- atouts ----------
Z.PERK_ORDER = { "jugg", "speed", "dtap", "revive", "stamin" }
Z.PERKS = {
	jugg = { n = "Mastodonte", price = 2500, c = rgb(0xe0383e), ic = "❤️", d = "Encaisse 2× plus de coups" },
	speed = { n = "Turbo Cola", price = 3000, c = rgb(0x33d17a), ic = "🔄", d = "Rechargement 2× plus rapide" },
	dtap = { n = "Double Détente", price = 2000, c = rgb(0xf5c542), ic = "II", d = "+33 % cadence, +50 % dégâts" },
	revive = { n = "Second Souffle", price = 1500, c = rgb(0x4aa3ff), ic = "♥", d = "Te relève une fois quand tu tombes" },
	stamin = { n = "Pas de Course", price = 2000, c = rgb(0xff9a3a), ic = "»", d = "Course 18 % plus rapide" },
}

Z.START_PTS = 500
Z.START_RES = 104            -- réserve du pistolet de départ (8 chargeurs de P250)
Z.WALLBUYS = { { "mac10", 500 }, { "mp9", 1000 }, { "ump", 1200 }, { "nova", 900 }, { "famas", 1500 }, { "galil", 1400 }, { "m4", 2000 }, { "xm", 1800 }, { "deagle", 800 } } :: { { any } }
Z.BOXPOOL = { "mac10", "mp9", "ump", "p90", "nova", "xm", "sawedoff", "galil", "famas", "ak", "m4", "sg553", "aug", "ssg", "awp", "scar", "negev", "m249", "deagle",
	"fiveseven", "raygun", "raygun", "thunder", "winter", "winter" }
Z.BOX_PRICE = 950
Z.PAP_PRICE = 5000
Z.DOOR_PRICES = { 750, 1000, 1250, 1500 }

-- bonus lâchés par les zombies
Z.DROP_ORDER = { "ammo", "insta", "dbl", "nuke", "fire" }
Z.DROPS = {
	ammo = { n = "MUNITIONS MAX", c = rgb(0x7dff6a), ic = "📦" },
	insta = { n = "MORT INSTANTANÉE", c = rgb(0xff3a3a), ic = "☠" },
	dbl = { n = "POINTS DOUBLES", c = rgb(0xffd23a), ic = "×2" },
	nuke = { n = "BOMBE", c = rgb(0xff9a3a), ic = "☢" },
	fire = { n = "VENTE DE FEU", c = rgb(0x7fe0ff), ic = "$" },
}

-- difficulté appliquée aux zombies (src/8L_zdiff.js), dans l'ordre de Modes.DIFFS
Z.ZDIFF = {
	{ hp = 0.6, spd = 0.78, dmg = 0.5, atk = 1.3, n = 0.6 },
	{ hp = 0.8, spd = 0.88, dmg = 0.7, atk = 1.05, n = 0.8 },
	{ hp = 1, spd = 1, dmg = 1, atk = 0.85, n = 1 },
	{ hp = 1.15, spd = 1.05, dmg = 1.2, atk = 0.75, n = 1.15 },
	{ hp = 1.3, spd = 1.1, dmg = 1.4, atk = 0.65, n = 1.3 },
}
Z.ZSLOW = 0.88
Z.RUN = 5.2                  -- vitesse de course du web (m/s) ; un joueur Roblox court à 16 studs/s

-- I, II, III, IIII, IIIII puis chiffres (compteur de manche « Black Ops »)
function Z.tally(n: number): string
	if n > 5 then return tostring(n) end
	return ({ "I", "II", "III", "IIII", "IIIII" })[n] or tostring(n)
end

-- ---------- Bataille royale ----------
-- phases de la zone (src/61_variants.js BR_PHASES), étirées pour que la zone se ferme vers 80 % du chrono (src/8G_rounds.js)
Z.BR_TIME = 300              -- durée maximale par défaut du web (5 min)
local BR_BASE = { { wait = 45, shrink = 30, r = 44, dmg = 2 }, { wait = 30, shrink = 25, r = 26, dmg = 4 }, { wait = 25, shrink = 20, r = 12, dmg = 7 }, { wait = 15, shrink = 20, r = 0, dmg = 12 } }
function Z.brPhases(total: number): { { wait: number, shrink: number, r: number, dmg: number } }
	local base = 0
	for _, p in ipairs(BR_BASE) do base += p.wait + p.shrink end
	local k = total * 0.8 / base
	local out = {}
	for i, p in ipairs(BR_BASE) do
		out[i] = { wait = math.floor(p.wait * k + 0.5), shrink = math.floor(p.shrink * k + 0.5), r = p.r, dmg = p.dmg }
	end
	return out
end
Z.BR_START_R = 64            -- rayon de départ (m), centre de la carte (40 m, 40 m)
Z.BR_TIERS = {
	{ "glock", "usp", "p250", "fiveseven", "deagle" },
	{ "mac10", "mp9", "ump", "nova", "sawedoff", "galil", "famas" },
	{ "ak", "m4", "sg553", "aug", "xm", "p90", "ssg", "negev" },
	{ "awp", "scar", "m249" },
}
-- couleur du halo d'une arme posée au sol (makeWeaponPickup du web)
function Z.lootColor(cat: string?): Color3
	if cat == "smg" or cat == "shotgun" then return rgb(0x4aa3ff) end
	if cat == "rifle" then return rgb(0xb36bff) end
	if cat == "sniper" or cat == "lmg" then return rgb(0xffb938) end
	return rgb(0x9aa6b8)
end
Z.ZONE_COLOR = rgb(0x35d6ff)

return Z
