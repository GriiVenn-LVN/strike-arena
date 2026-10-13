--!strict
-- ServerScriptService/ShopService (Script)
-- Boutique cosmétique (aucun avantage de gameplay) : pièces via DevProducts, passe Premium, achats en pièces.
-- Renseigne les productId dans ConfigExtra.SHOP après création dans le Creator Hub.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")

local X = require(ReplicatedStorage.Shared.ConfigExtra)
local DataService = require(script.Parent.DataService)
local ProgressService = require(script.Parent.ProgressService)

local receipts = DataStoreService:GetDataStore("StrikeArenaReceipts_v1")

local byProduct: { [number]: any } = {}
for _, item in ipairs(X.SHOP) do if item.kind == "devproduct" and item.productId > 0 then byProduct[item.productId] = item end end

MarketplaceService.ProcessReceipt = function(info)
	local player = game:GetService("Players"):GetPlayerByUserId(info.PlayerId)
	if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local key = info.PlayerId .. "_" .. info.PurchaseId
	local done = false
	pcall(function() done = receipts:GetAsync(key) == true end)
	if done then return Enum.ProductPurchaseDecision.PurchaseGranted end       -- déjà crédité (anti-doublon)
	local item = byProduct[info.ProductId]
	local profile = DataService.get(player)
	if not item or not profile then return Enum.ProductPurchaseDecision.NotProcessedYet end
	if item.coins then profile.coins += item.coins end
	if item.id == "pass_premium" then ProgressService.grantPremium(player) end
	local ok = pcall(function() receipts:SetAsync(key, true) end)
	if not ok then return Enum.ProductPurchaseDecision.NotProcessedYet end
	DataService.save(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local buy = Instance.new("RemoteFunction"); buy.Name = "ShopBuy"; buy.Parent = ReplicatedStorage
buy.OnServerInvoke = function(player: Player, id: any)
	if typeof(id) ~= "string" then return false, "bad" end
	local profile = DataService.get(player); if not profile then return false, "no profile" end
	for _, item in ipairs(X.SHOP) do
		if item.id == id then
			if item.kind == "coins" then
				if profile.coins < item.price then return false, "pièces insuffisantes" end
				profile.coins -= item.price
				profile.cosmetics = profile.cosmetics or {}
				profile.cosmetics.owned = profile.cosmetics.owned or {}
				table.insert(profile.cosmetics.owned, id)
				return true
			elseif item.kind == "devproduct" and item.productId > 0 then
				MarketplaceService:PromptProductPurchase(player, item.productId)   -- le crédit se fait dans ProcessReceipt
				return true
			end
		end
	end
	return false, "inconnu"
end
