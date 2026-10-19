--!strict
-- ReplicatedStorage/Shared/ShopCatalog (ModuleScript)
-- Catalogue de la boutique, partagé client + serveur : le client l'affiche, le serveur s'en sert pour vérifier chaque achat.
-- Armes, skins, viseurs et tenues s'achètent avec les pièces gagnées en jouant (lentement : voir Config.xpNeeded et RewardService).
-- Les Robux achètent des pièces, des caisses, le passe Premium, et les EXCLUSIFS (camos animés) qu'on ne peut obtenir qu'en payant.
local Config = require(script.Parent.Config)
local X = require(script.Parent.ConfigExtra)
local LoyaltyConfig = require(script.Parent.LoyaltyConfig)
local KillFxConfig = require(script.Parent.KillFxConfig)

local Catalog = {}

-- ---------- Prix ----------
Catalog.PRICE_BY_RARITY = { 0, 800, 2000, 5000 }  -- commun (gratuit), rare, épique, légendaire (~35 pièces gagnées par partie)
Catalog.OFFER_DISCOUNT = 0.25                     -- -25 % sur les offres du jour
Catalog.FEATURED_DISCOUNT = 0.4                   -- -40 % sur l'offre vedette du jour (un objet épique ou légendaire)

-- Armes disponibles dès le départ ; les autres se débloquent une fois pour toutes avec des pièces
Catalog.STARTER_WEAPONS = { knife = true, glock = true, usp = true, p250 = true, mac10 = true, nova = true, galil = true, famas = true }

function Catalog.weaponPrice(key: string): number
	if Catalog.STARTER_WEAPONS[key] then return 0 end
	local w = Config.WEAPONS[key]
	return math.max(500, math.floor(w.price * 0.6 / 50 + 0.5) * 50)   -- ex. AK-47 (2700 $ en partie) -> 1600 pièces
end

-- Onglets dans l'ordre d'affichage
Catalog.TABS = {
	{ id = "featured", name = "À la une 🔥" },
	{ id = "weapons", name = "Armes" },
	{ id = "skins", name = "Skins" },
	{ id = "sights", name = "Viseurs" },
	{ id = "style", name = "Tenues & style" },
	{ id = "killfx", name = "Effets 💥" },
	{ id = "premium", name = "Premium ⭐" },
	{ id = "exclusive", name = "Exclusifs ✨" },
	{ id = "robux", name = "Pièces 🪙" },
}

-- Présentation des lots de pièces (onglet « Pièces ») : étiquette et bonus calculé par rapport au plus petit lot
Catalog.BUNDLE_TAGS = { coins_m = "POPULAIRE", coins_xl = "MEILLEURE VALEUR" } :: { [string]: string }

-- Pack de départ (offre unique par compte, comme les « Starter Packs » de Fortnite / COD) : Developer Product à 99 R$,
-- crédité dans ShopService.ProcessReceipt ; après l'achat il disparaît de la boutique (profile.purchases.pack_starter).
-- Valeur ~4× un lot de pièces : 1 500 pièces, 2 caisses Premium, 5 boosts d'XP (+50 % sur 5 parties), titre « Pionnier ».
Catalog.STARTER = { id = "pack_starter", robux = 99, name = "Pack de départ", coins = 1500, box = "prem", boxes = 2, boost = 5, title = "starter",
	lines = { "1 500 pièces", "2 caisses Premium", "5 boosts d'XP (+50 %)", "Titre « 🎖 Pionnier »" } }

-- Passe de jeu (Game Pass, acheté une fois pour toutes) : XP ×2 en fin de partie. Les pièces ne sont pas doublées.
-- Vérifié par ShopService (UserOwnsGamePassAsync) qui pose l'attribut PassXp2 lu par RewardService.
Catalog.GAMEPASSES = {
	{ id = "gp_xp2", name = "XP ×2 pour toujours", robux = 299, attr = "PassXp2", desc = "Double l'XP de base de chaque partie (niveaux et passe de combat plus rapides). Les pièces ne sont pas doublées." },
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
					name = skin.name .. " · " .. Config.WEAPONS[key].name, rarity = skin.rarity, price = Catalog.PRICE_BY_RARITY[skin.rarity],
					event = (skin :: any).ev })      -- event : récompense d'événement, ne s'achète pas (ShopService refuse)
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
	add({ id = "outfit_" .. i, tab = "style", kind = "outfit", outfit = i, name = o.name, rarity = o.rarity, price = Catalog.PRICE_BY_RARITY[o.rarity], event = (o :: any).ev })
end
local TRAIL_NAMES = { cyan = "Cyan", red = "Rouge", lime = "Citron vert", gold = "Or", violet = "Violet", rainbow = "Arc-en-ciel" }
for _, t in ipairs(X.TRAILS) do
	if t ~= "" then
		local rarity = if t == "rainbow" then 4 elseif t == "gold" then 3 else 2
		add({ id = "trail_" .. t, tab = "style", kind = "trail", trail = t, name = "Traînée " .. (TRAIL_NAMES[t] or t), rarity = rarity, price = Catalog.PRICE_BY_RARITY[rarity] })
	end
end
add({ id = "title_pack", tab = "style", kind = "misc", name = "Pack de titres de profil", rarity = 2, price = 800 })

-- Effets d'élimination (KillFxConfig) : pièces, Robux, ou seulement via un code promo / le groupe Roblox
for _, fx in ipairs(KillFxConfig.LIST) do
	add({ id = "killfx_" .. fx.id, tab = "killfx", kind = "killfx", fx = fx.id, name = fx.name, rarity = fx.rarity, source = fx.source,
		price = if fx.source == "coins" then fx.price else 0, robux = fx.robux, productId = fx.productId or 0, event = if fx.source == "event" then "hw" else nil })
end

-- Robux (Developer Products) : renseigne productId après création dans le Creator Hub (0 = désactivé)
for _, it in ipairs(X.SHOP) do
	if it.kind == "devproduct" then
		add({ id = it.id, tab = "robux", kind = "devproduct", name = it.name, rarity = 1, robux = it.robux, productId = it.productId,
			coins = it.coins, box = it.box, boxes = it.boxes, premium = it.premium })
	end
end

-- Pack de départ (offre unique) et passes de jeu : onglet « À la une »
do
	local st = Catalog.STARTER
	add({ id = st.id, tab = "featured", kind = "devproduct", name = st.name, rarity = 5, robux = st.robux, productId = 0,
		coins = st.coins, box = st.box, boxes = st.boxes, boost = st.boost, title = st.title, once = true })
	for _, g in ipairs(Catalog.GAMEPASSES) do
		add({ id = g.id, tab = "featured", kind = "gamepass", name = g.name, rarity = 5, robux = g.robux, passId = 0, attr = g.attr, desc = g.desc })
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

-- numéros des produits Robux : ProductIds.lua (un seul fichier à remplir) passe avant les valeurs des fichiers de config
do
	local ids = require(script.Parent.ProductIds) :: { [string]: number }
	for _, it in ipairs(items) do
		local n = ids[it.id]
		if n and n > 0 then
			if it.kind == "gamepass" then it.passId = n else it.productId = n end
		end
	end
end

Catalog.ITEMS = items
function Catalog.get(id: string): any
	return byId[id]
end

-- ---------- Possession ----------
-- Inventaire du profil (voir DataService) : inv.weapons, inv.skins[arme], inv.outfits, inv.sights, inv.reticles, inv.misc
function Catalog.owns(profile: any, it: any): boolean
	if it.once then return profile.purchases ~= nil and profile.purchases[it.id] == true end   -- pack de départ : une seule fois
	if it.kind == "devproduct" or it.kind == "vip" or it.kind == "gamepass" then return false end   -- se rachète (jours cumulables) ; passe : vérifié par Roblox
	local inv = profile.inv
	if it.kind == "exclusive" then
		for _, c in ipairs(it.camos) do
			if not table.find(inv.exclusive or {}, c) then return false end
		end
		return true
	end
	if it.kind == "killfx" then return it.fx == "none" or table.find(inv.killfx or {}, it.fx) ~= nil end
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
	-- jamais un objet d'événement (il ne s'achète pas : ShopService le refuse)
	local function buyable(it: any): boolean return (it.price or 0) > 0 and not it.event end
	for _, tab in ipairs({ "weapons", "skins", "sights", "style" }) do   -- une offre par onglet
		local pool = {}
		for _, it in ipairs(items) do
			if it.tab == tab and buyable(it) then table.insert(pool, it.id) end
		end
		if #pool > 0 then table.insert(picked, pool[rng:NextInteger(1, #pool)]) end
	end
	-- 5e offre = offre vedette (-40 %) : un objet épique ou légendaire, toutes catégories
	local pool = {}
	for _, it in ipairs(items) do
		if buyable(it) and (it.rarity or 0) >= 3 and it.tab ~= "featured" and not table.find(picked, it.id) then table.insert(pool, it.id) end
	end
	if #pool > 0 then table.insert(picked, pool[rng:NextInteger(1, #pool)]) end
	offersCache = { day = day, ids = picked }
	return picked
end

-- offre vedette du jour : la 5e de dailyOffers
function Catalog.featuredOffer(day: number): string?
	return Catalog.dailyOffers(day)[5]
end
function Catalog.discountFor(it: any, day: number): number
	local i = table.find(Catalog.dailyOffers(day), it.id)
	if not i then return 0 end
	return if i == 5 then Catalog.FEATURED_DISCOUNT else Catalog.OFFER_DISCOUNT
end
function Catalog.priceFor(it: any, day: number): number
	local d = Catalog.discountFor(it, day)
	if d > 0 then return math.floor(it.price * (1 - d) / 10 + 0.5) * 10 end
	return it.price
end

return Catalog
