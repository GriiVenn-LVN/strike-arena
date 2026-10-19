--!strict
-- ServerScriptService/OptionsService (Script)
-- Options du joueur (Réglages du menu principal et panneau Options de la pause) gardées dans le profil (DataService) :
--   OptionsSave(data)   remplace profile.options par la version nettoyée (MenuConfig.cleanOptions : clés connues, nombres bornés)
-- À l'arrivée, l'accessibilité enregistrée est recopiée dans l'attribut « Access » que lit AccessibilityController.
-- Le reste est relu par le client dans GetProfile (profile.options). MenuSave("opts") de MenuService reste en place pour
-- les cinq anciens réglages (champ de vision, sensibilités, volume, qualité).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local MenuConfig = require(ReplicatedStorage.Shared.MenuConfig)
local DataService = require(script.Parent:WaitForChild("DataService"))

local lastSave: { [Player]: number } = {}

local save = Instance.new("RemoteFunction"); save.Name = "OptionsSave"; save.Parent = ReplicatedStorage
-- un enregistrement toutes les 0,5 s au plus, rien qui ne soit pas une table
save.OnServerInvoke = function(p: Player, data: any): boolean
	if typeof(data) ~= "table" then return false end
	if os.clock() - (lastSave[p] or 0) < 0.5 then return false end
	local profile = DataService.get(p)
	if not profile then return false end
	lastSave[p] = os.clock()
	profile.options = MenuConfig.cleanOptions(data)
	return true
end

-- accessibilité enregistrée -> attribut « Access » (daltonisme, taille de l'interface… appliqués dès l'arrivée)
local function publish(p: Player)
	for _ = 1, 30 do
		if not p.Parent then return end
		local profile = DataService.get(p)
		if profile then
			if typeof(profile.options) == "table" and typeof(profile.options.access) == "table" then
				local acc = MenuConfig.cleanOptions(profile.options).access
				local ok, raw = pcall(HttpService.JSONEncode, HttpService, acc)
				if ok then p:SetAttribute("Access", raw) end
			end
			return
		end
		task.wait(1)
	end
end
Players.PlayerAdded:Connect(publish)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(publish, p) end
Players.PlayerRemoving:Connect(function(p: Player) lastSave[p] = nil end)
