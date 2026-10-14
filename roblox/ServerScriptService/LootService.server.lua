--!strict
-- ServerScriptService/LootService (Script)
-- Ouverture des caisses : tirage pondéré + système de pitié, doublons convertis en pièces.
-- Les probabilités DOIVENT être affichées dans l'interface (règle Roblox pour les objets aléatoires payants).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

local remote = Instance.new("RemoteFunction")
remote.Name = "OpenBox"
remote.Parent = ReplicatedStorage

-- Construit le pool d'objets une seule fois
local pool: { { kind: string, weapon: string?, skin: number?, dance: string?, outfit: number?, rarity: number } } = {}
for weaponKey in pairs(Config.WEAPONS) do
	for i, skin in ipairs(Config.SKINS) do
		if skin.rarity > 1 then
			table.insert(pool, { kind = "skin", weapon = weaponKey, skin = i, rarity = skin.rarity })
		end
	end
end
for id, d in pairs(Config.DANCES) do
	if d.rarity > 1 then table.insert(pool, { kind = "dance", dance = id, rarity = d.rarity }) end
end
for i, o in ipairs(Config.OUTFITS) do
	if o.rarity > 1 then table.insert(pool, { kind = "outfit", outfit = i, rarity = o.rarity }) end
end

local function owns(profile, item): boolean
	if item.kind == "skin" then
		local list = profile.inv.skins[item.weapon]
		return list ~= nil and table.find(list, item.skin) ~= nil
	end
	if item.kind == "outfit" then return table.find(profile.inv.outfits or {}, item.outfit) ~= nil end
	return table.find(profile.inv.dances, item.dance) ~= nil
end

local function rollRarity(profile, weights: { number }): number
	if profile.pity.legend >= Config.PITY.legend - 1 then return 4 end
	if profile.pity.epic >= Config.PITY.epic - 1 then
		return (math.random() * (weights[3] + weights[4]) < weights[4]) and 4 or 3
	end
	local total = 0
	for _, w in ipairs(weights) do total += w end
	local r = math.random() * total
	for i, w in ipairs(weights) do
		r -= w
		if r <= 0 then return i end
	end
	return 1
end

local function openBox(player: Player, boxType: string)
	local def = Config.BOXES[boxType]
	local profile = DataService.get(player)
	if not def or not profile then return { ok = false, err = "invalid" } end

	-- paiement : caisse en stock sinon pièces
	if (profile.boxes[boxType] or 0) > 0 then
		profile.boxes[boxType] -= 1
	elseif profile.coins >= def.coins then
		profile.coins -= def.coins
	else
		return { ok = false, err = "not_enough_coins" }
	end

	local rarity = rollRarity(profile, def.weights)
	profile.pity.epic = (rarity >= 3) and 0 or profile.pity.epic + 1
	profile.pity.legend = (rarity == 4) and 0 or profile.pity.legend + 1
	profile.opened += 1

	local result: any = { ok = true, rarity = rarity, duplicate = false, coins = 0 }
	if rarity == 1 then
		result.item = { kind = "coins" }
		result.coins = math.random(40, 90)
		profile.coins += result.coins
	else
		local candidates = {}
		for _, it in ipairs(pool) do if it.rarity == rarity then table.insert(candidates, it) end end
		local item = candidates[math.random(#candidates)]
		result.item = item
		if owns(profile, item) then
			result.duplicate = true
			result.coins = Config.DUPLICATE_VALUE[rarity]
			profile.coins += result.coins
		elseif item.kind == "skin" then
			profile.inv.skins[item.weapon] = profile.inv.skins[item.weapon] or {}
			table.insert(profile.inv.skins[item.weapon], item.skin)
		elseif item.kind == "outfit" then
			profile.inv.outfits = profile.inv.outfits or {}
			table.insert(profile.inv.outfits, item.outfit)
		else
			table.insert(profile.inv.dances, item.dance)
		end
	end
	return result
end

remote.OnServerInvoke = function(player: Player, boxType: any)
	if typeof(boxType) ~= "string" then return { ok = false, err = "invalid" } end
	return openBox(player, boxType)
end

-- Les caisses achetées en Robux passent par ShopService (un seul ProcessReceipt possible par jeu) : voir ConfigExtra.SHOP.
