--!strict
-- ServerScriptService/ShopService (Script)
-- Boutique : achats en pièces (armes, skins, viseurs, tenues), offres du jour, équipement, produits Robux et exclusifs payants.
-- Le catalogue est dans ReplicatedStorage/Shared/ShopCatalog. Le serveur revérifie TOUT (prix, possession, pièces) : ne jamais croire le client.
-- C'est le SEUL ProcessReceipt du jeu (Roblox n'en accepte qu'un) : pièces, caisses, passe de combat et abonnement Premium passent tous par ici.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local X = require(ReplicatedStorage.Shared.ConfigExtra)
local Catalog = require(ReplicatedStorage.Shared.ShopCatalog)
local DataService = require(script.Parent.DataService)
local ProgressService = require(script.Parent.ProgressService)
local LoyaltyService = require(script.Parent.LoyaltyService)
local LoyaltyConfig = require(ReplicatedStorage.Shared.LoyaltyConfig)
local KillFxConfig = require(ReplicatedStorage.Shared.KillFxConfig)

local receipts = require(script.Parent.Stores).get("StrikeArenaReceipts_v1")

local function remoteFunction(name: string): RemoteFunction
	local r = Instance.new("RemoteFunction"); r.Name = name; r.Parent = ReplicatedStorage; return r
end

-- ---------- Robux (Developer Products) ----------
local byProduct: { [number]: any } = {}
for _, it in ipairs(Catalog.ITEMS) do
	if (it.kind == "devproduct" or it.kind == "exclusive" or it.kind == "vip" or (it.kind == "killfx" and it.source == "robux")) and it.productId > 0 then
		byProduct[it.productId] = it
	end
end

MarketplaceService.ProcessReceipt = function(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local key = info.PlayerId .. "_" .. info.PurchaseId
	local done = false
	pcall(function() done = receipts:GetAsync(key) == true end)
	if done then return Enum.ProductPurchaseDecision.PurchaseGranted end       -- déjà crédité (anti-doublon)
	local it = byProduct[info.ProductId]
	local profile = DataService.get(player)
	if not it or not profile then return Enum.ProductPurchaseDecision.NotProcessedYet end
	if it.coins then profile.coins += it.coins end
	if it.box then profile.boxes[it.box] = (profile.boxes[it.box] or 0) + (it.boxes or 1) end
	if it.premium then ProgressService.grantPremium(player) end
	if it.kind == "vip" then LoyaltyService.grantVip(player, it.days) end   -- abonnement Premium : jours ajoutés + caisse offerte
	if it.kind == "exclusive" then                                            -- camos animés : ajoutés pour toujours
		profile.inv.exclusive = profile.inv.exclusive or {}
		for _, c in ipairs(it.camos) do
			if not table.find(profile.inv.exclusive, c) then table.insert(profile.inv.exclusive, c) end
		end
	end
	if it.kind == "killfx" then                                               -- effet d'élimination exclusif : pour toujours
		profile.inv.killfx = profile.inv.killfx or {}
		if not table.find(profile.inv.killfx, it.fx) then table.insert(profile.inv.killfx, it.fx) end
	end
	local ok = pcall(function() receipts:SetAsync(key, true) end)
	if not ok then return Enum.ProductPurchaseDecision.NotProcessedYet end
	DataService.save(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- ---------- Ajout à l'inventaire ----------
local function grant(profile: any, it: any)
	local inv = profile.inv
	local function push(list: string, value: any)
		inv[list] = inv[list] or {}
		table.insert(inv[list], value)
	end
	if it.kind == "weapon" then push("weapons", it.weapon)
	elseif it.kind == "skin" then
		inv.skins[it.weapon] = inv.skins[it.weapon] or {}
		table.insert(inv.skins[it.weapon], it.skin)
	elseif it.kind == "outfit" then push("outfits", it.outfit)
	elseif it.kind == "sight" then push("sights", it.sight)
	elseif it.kind == "reticle" then push("reticles", it.reticle)
	elseif it.kind == "killfx" then push("killfx", it.fx)
	else push("misc", it.id) end
end

-- ---------- Remotes ----------
-- État de la boutique pour l'interface : pièces, offres du jour (avec prix réduit), objets possédés et équipés
local getShop = remoteFunction("GetShop")
getShop.OnServerInvoke = function(player: Player)
	local profile = DataService.get(player)
	if not profile then return nil end
	local day = Catalog.today()
	local owned = {}
	for _, it in ipairs(Catalog.ITEMS) do
		if Catalog.owns(profile, it) then owned[it.id] = true end
	end
	local offers = {}
	for _, id in ipairs(Catalog.dailyOffers(day)) do
		table.insert(offers, { id = id, price = Catalog.priceFor(Catalog.get(id), day) })
	end
	return { coins = profile.coins, owned = owned, offers = offers, equipped = profile.equipped, equippedSkins = profile.equippedSkins or {},
		secondsToReset = 86400 - os.time() % 86400 }
end

local buy = remoteFunction("ShopBuy")
buy.OnServerInvoke = function(player: Player, id: any)
	if typeof(id) ~= "string" then return { ok = false, err = "Objet inconnu" } end
	local profile = DataService.get(player)
	if not profile then return { ok = false, err = "Profil pas encore chargé" } end
	local it = Catalog.get(id)
	if not it then return { ok = false, err = "Objet inconnu" } end

	-- objets d'événement (skins, tenues et effets d'Halloween) : seulement avec les paliers de citrouilles
	if it.event then return { ok = false, err = if Catalog.owns(profile, it) then "Déjà possédé" else "Récompense de l'événement d'Halloween (citrouilles)" } end

	if it.kind == "devproduct" or it.kind == "exclusive" or it.kind == "vip" then
		if it.kind == "exclusive" and Catalog.owns(profile, it) then return { ok = false, err = "Déjà possédé" } end
		if it.productId <= 0 then return { ok = false, err = "Bientôt disponible" } end
		MarketplaceService:PromptProductPurchase(player, it.productId)   -- le crédit se fait dans ProcessReceipt
		return { ok = true, pending = true }
	end

	if it.kind == "killfx" and it.source ~= "coins" then
		if Catalog.owns(profile, it) then return { ok = false, err = "Déjà possédé" } end
		if it.source == "code" then return { ok = false, err = "S'obtient avec un code promo" } end
		if it.source == "group" then return { ok = false, err = "S'obtient en rejoignant le groupe Roblox" } end
		if it.productId <= 0 then return { ok = false, err = "Bientôt disponible" } end
		MarketplaceService:PromptProductPurchase(player, it.productId)
		return { ok = true, pending = true }
	end

	if Catalog.owns(profile, it) then return { ok = false, err = "Déjà possédé" } end
	local price = Catalog.priceFor(it, Catalog.today())
	if profile.coins < price then return { ok = false, err = "Pièces insuffisantes" } end
	profile.coins -= price
	grant(profile, it)
	task.spawn(DataService.save, player)      -- sauvegarde tout de suite : un achat ne doit jamais se perdre
	return { ok = true, coins = profile.coins }
end

-- Pour le futur menu d'achat en partie : Catalog.ownsWeapon(profile, key) dit si une arme est débloquée.

-- Équiper : tenue, réticule, traînée, ou viseur d'une arme (les skins utilisent le remote EquipSkin de Main)
local equip = remoteFunction("ShopEquip")
equip.OnServerInvoke = function(player: Player, id: any, weapon: any)
	if typeof(id) ~= "string" then return false end
	local profile = DataService.get(player)
	local it = Catalog.get(id)
	if not profile or not it or not Catalog.owns(profile, it) then return false end
	local eq = profile.equipped
	if it.kind == "outfit" then eq.outfit = it.outfit
	elseif it.kind == "reticle" then eq.reticle = it.reticle
	elseif it.kind == "trail" then
		eq.trail = it.trail
		ProgressService.ensure(profile)
		profile.cosmetics.trail = it.trail
	elseif it.kind == "sight" then
		if typeof(weapon) ~= "string" or not Config.WEAPONS[weapon] or Config.WEAPONS[weapon].melee then return false end
		eq.sights[weapon] = it.sight
	elseif it.kind == "exclusive" and it.camo then   -- un camo animé se pose arme par arme (le lot se possède, il ne s'équipe pas)
		if typeof(weapon) ~= "string" or not Config.WEAPONS[weapon] or Config.WEAPONS[weapon].melee then return false end
		eq.animCamo = eq.animCamo or {}
		eq.animCamo[weapon] = it.camo
		DataService.syncSkins(player)
	elseif it.kind == "killfx" then
		eq.killFx = it.fx
	else
		return false
	end
	return true
end

-- Vérification au démarrage : un productId en double ferait créditer le mauvais produit
do
	local seen = {}
	for _, list in ipairs({ X.SHOP, X.EXCLUSIVES, LoyaltyConfig.VIP.offers, KillFxConfig.LIST }) do for _, it in ipairs(list) do
		if (it.productId or 0) > 0 then
			if seen[it.productId] then warn("[ShopService] productId en double dans ConfigExtra.SHOP :", it.productId) end
			seen[it.productId] = true
		end
	end end
end
