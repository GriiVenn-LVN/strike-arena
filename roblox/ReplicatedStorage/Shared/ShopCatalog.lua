--!strict
-- ReplicatedStorage/Shared/ShopCatalog (ModuleScript)
-- Catalogue de la boutique, partagé client + serveur : le client l'affiche, le serveur s'en sert pour vérifier chaque achat.
-- Armes, skins, viseurs et tenues s'achètent avec les pièces gagnées en jouant (lentement : voir Config.xpNeeded et RewardService).
-- Les Robux achètent des pièces, des caisses, le passe Premium, et les EXCLUSIFS (camos animés) qu'on ne peut obtenir qu'en payant.
local Config = require(script.Parent.Config)
local X = require(script.Parent.ConfigExtra)
local LoyaltyConfig = require(script.Parent.LoyaltyConfig)

local Catalog = {}

-- ---------- Prix ----------
Catalog.PRICE_BY_RARITY = { 0, 800, 2000, 5000 }  -- commun (gratuit), rare, épique, légendaire (~35 pièces gagnées par partie)
Catalog.OFFER_DISCOUNT = 0.25                     -- -25 % sur les offres du jour

-- Armes disponibles dès le départ ; les autres se débloquent une fois pour toutes avec des pièces
Catalog.STARTER_WEAPONS = { knife = true, glock = true, usp = true, p250 = true, mac10 = true, nova = true, galil = true, famas = true }

function Catalog.weaponPrice(key: string): number
	if Catalog.STARTER_WEAPONS[key] then return 0 end
	local w = Config.WEAPONS[key]
	return math.max(500, math.floor(w.price * 0.6 / 50 + 0.5) * 50)   -- ex. AK-47 (2700 $ en partie) -> 1600 pièces
end

-- Onglets dans l'ordre d'affichage
Catalog.TABS = {
	{ id = "weapons", name = "Armes" },
	{ id = "skins", name = "Skins" },
	{ id = "sights", name = "Viseurs" },
	{ id = "style", name = "Tenues & style" },
	{ id = "premium", name = "Premium ⭐" },
	{ id = "exclusive", name = "Exclusifs ✨" },
	{ id = "robux", name = "Robux" },
}

-- ---------- Liste des objets ----------
-- Chaque objet : id unique, tab, kind, name, rarity (1..4), price (pièces) ou robux + productId, champs propres au kind.
local items: { any } = {}
local byId: { [string]: any } = {}
local function add(it)
	table.insert(items, it)
	byId[it.id] = it
end

-- Armes (ordre du tableau Config.WEAPONS pas garanti : on trie par prix en partie)
local weaponKeys = {}
for key in pairs(Config.WEAPONS) do table.insert(weaponKeys, key) end
table.sort(weaponKeys, function(a, b)
	local pa, pb = Config.WEAPONS[a].price, Config.WEAPONS[b].price
	if pa == pb then return a < b end
	return pa < pb
end)
Catalog.WEAPON_KEYS = weaponKeys
for _, key in ipairs(weaponKeys) do
	local price = Catalog.weaponPrice(key)
	add({ id = "weapon_" .. key, tab = "weapons", kind = "weapon", weapon = key, name = Config.WEAPONS[key].name,
		rarity = if price == 0 then 1 elseif price < 1000 then 2 elseif price < 1800 then 3 else 4, price = price })
end

-- Skins : un objet par couple arme + skin (les skins communs sont déjà gratuits pour toutes les armes)
for _, key in ipairs(weaponKeys) do
	if not Config.WEAPONS[key].melee then
		for i, skin in ipairs(Config.SKINS) do
			if skin.rarity > 1 then
				add({ id = "skin_" .. key .. "_" .. i, tab = "skins", kind = "skin", weapon = key, skin = i,
					name = skin.name .. " · " .. Config.WEAPONS[key].name, rarity = skin.rarity, price = Catalog.PRICE_BY_RARITY[skin.rarity] })
			end
		end
	end
end

-- Viseurs : modèle d'optique + réticule (définis dans ConfigExtra.SIGHTS / RETICLES)
for _, s in ipairs(X.SIGHTS) do
	add({ id = "sight_" .. s.id, tab = "sights", kind = "sight", sight = s.id, name = s.name, rarity = s.rarity, price = Catalog.PRICE_BY_RARITY[s.rarity] })
end
for _, r in ipairs(X.RETICLES) do
	add({ id = "reticle_" .. r.id, tab = "sights", kind = "reticle", reticle = r.id, name = "Réticule " .. r.name, rarity = r.rarity, price = Catalog.PRICE_BY_RARITY[r.rarity] })
end

-- Tenues de soldat, traînées de balle, titres de profil
for i, o in ipairs(Config.OUTFITS) do
	add({ id = "outfit_" .. i, tab = "style", kind = "outfit", outfit = i, name = o.name, rarity = o.rarity, price = Catalog.PRICE_BY_RARITY[o.rarity] })
end
local TRAIL_NAMES = { cyan = "Cyan", red = "Rouge", lime = "Citron vert", gold = "Or", violet = "Violet", rainbow = "Arc-en-ciel" }
for _, t in ipairs(X.TRAILS) do
	if t ~= "" then
		local rarity = if t == "rainbow" then 4 elseif t == "gold" then 3 else 2
		add({ id = "trail_" .. t, tab = "style", kind = "trail", trail = t, name = "Traînée " .. (TRAIL_NAMES[t] or t), rarity = rarity, price = Catalog.PRICE_BY_RARITY[rarity] })
	end
end
add({ id = "title_pack", tab = "style", kind = "misc", name = "Pack de titres de profil", rarity = 2, price = 800 })

-- Robux (Developer Products) : renseigne productId après création dans le Creator Hub (0 = désactivé)
for _, it in ipairs(X.SHOP) do
	if it.kind == "devproduct" then
		add({ id = it.id, tab = "robux", kind = "devproduct", name = it.name, rarity = 1, robux = it.robux, productId = it.productId,
			coins = it.coins, box = it.box, boxes = it.boxes, premium = it.premium })
	end
end

-- Exclusifs (Robux uniquement, permanents) : camos animés, ou lot de plusieurs camos
for _, it in ipairs(X.EXCLUSIVES) do
	add({ id = it.id, tab = "exclusive", kind = "exclusive", name = it.name, rarity = 5, robux = it.robux, productId = it.productId,
		camos = it.camos or { it.camo }, camo = it.camo })
end

-- Abonnement Premium (Robux, jours cumulables) : couleur de pseudo, +20 % XP et pièces, cadeau quotidien. Voir LoyaltyConfig.VIP.
for _, o in ipairs(LoyaltyConfig.VIP.offers) do
	add({ id = o.id, tab = "premium", kind = "vip", name = o.name, rarity = 5, robux = o.robux, productId = o.productId, days = o.days, best = o.best })
end

Catalog.ITEMS = items
function Catalog.get(id: string): any
	return byId[id]
end

-- ---------- Possession ----------
-- Inventaire du profil (voir DataService) : inv.weapons, inv.skins[arme], inv.outfits, inv.sights, inv.reticles, inv.misc
function Catalog.owns(profile: any, it: any): boolean
	if it.kind == "devproduct" or it.kind == "vip" then return false end   -- se rachète (jours cumulables)
	local inv = profile.inv
	if it.kind == "exclusive" then
		for _, c in ipairs(it.camos) do
			if not table.find(inv.exclusive or {}, c) then return false end
		end
		return true
	end
	if it.price == 0 then return true end
	if it.kind == "weapon" then return table.find(inv.weapons or {}, it.weapon) ~= nil end
	if it.kind == "skin" then return table.find(inv.skins[it.weapon] or {}, it.skin) ~= nil end
	if it.kind == "outfit" then return table.find(inv.outfits or {}, it.outfit) ~= nil end
	if it.kind == "sight" then return table.find(inv.sights or {}, it.sight) ~= nil end
	if it.kind == "reticle" then return table.find(inv.reticles or {}, it.reticle) ~= nil end
	return table.find(inv.misc or {}, it.id) ~= nil
end

-- À utiliser par le futur menu d'achat en partie : une arme non débloquée ne doit pas y être proposée
function Catalog.ownsWeapon(profile: any, key: string): boolean
	local it = byId["weapon_" .. key]
	return it ~= nil and Catalog.owns(profile, it)
end

-- ---------- Offres du jour ----------
-- Même tirage côté client et serveur grâce à la graine = jour UTC. Une offre n'est jamais une arme de départ ni un objet gratuit.
function Catalog.today(): number
	return math.floor(os.time() / 86400)
end

local offersCache: { day: number, ids: { string } } = { day = -1, ids = {} }
function Catalog.dailyOffers(day: number): { string }
	if offersCache.day == day then return offersCache.ids end
	local rng = Random.new(day * 7919 + 17)
	local picked = {}
	for _, tab in ipairs({ "weapons", "skins", "sights", "style" }) do   -- une offre par onglet
		local pool = {}
		for _, it in ipairs(items) do
			if it.tab == tab and it.price > 0 then table.insert(pool, it.id) end
		end
		if #pool > 0 then table.insert(picked, pool[rng:NextInteger(1, #pool)]) end
	end
	offersCache = { day = day, ids = picked }
	return picked
end

function Catalog.priceFor(it: any, day: number): number
	if table.find(Catalog.dailyOffers(day), it.id) then
		return math.floor(it.price * (1 - Catalog.OFFER_DISCOUNT) / 10 + 0.5) * 10
	end
	return it.price
end

return Catalog
