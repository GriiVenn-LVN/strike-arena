--!strict
-- ServerScriptService/DataService (ModuleScript)
-- Sauvegarde du profil joueur : XP, pièces, inventaire (skins/danses), caisses, pitié, stats, défis, série quotidienne.
-- Ne JAMAIS faire confiance au client : toutes les modifications passent par le serveur.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local STORE = DataStoreService:GetDataStore("StrikeArenaProfile_v1")
local AUTOSAVE_INTERVAL = 60

local DataService = {}
local profiles: { [Player]: any } = {}

local function template()
	return {
		version = 1,
		xp = 0,
		coins = 250,
		lastLoginDay = 0,            -- jour UTC (os.time() // 86400)
		streak = 0,
		inv = { skins = {}, dances = { "wave", "clap" }, weapons = {}, outfits = {}, sights = {}, reticles = {}, misc = {}, exclusive = {} },   -- exclusive = camos animés achetés en Robux   -- skins[weaponKey] = { skinIndex, ... } ; voir Shared/ShopCatalog
		equippedDance = "wave",
		equipped = { outfit = 1, reticle = "dot_red", trail = "", sights = {}, animCamo = {} },   -- animCamo[weaponKey] = camo animé (ConfigExtra.EXCLUSIVES)   -- sights[weaponKey] = id de ConfigExtra.SIGHTS
		boxes = { std = 1, prem = 0 },
		pity = { epic = 0, legend = 0 },
		opened = 0,
		stats = { matches = 0, wins = 0, kills = 0, deaths = 0, hs = 0, dmg = 0, shots = 0, hits = 0, seconds = 0, bestStreak = 0, byMode = {}, byMap = {}, byWeapon = {} },
		history = {},
		missions = { day = 0, list = {} },
		binds = {},                 -- touches personnalisées (synchronisées avec le client)
	}
end

local function reconcile(data: any, tpl: any)
	for k, v in pairs(tpl) do
		if data[k] == nil then
			data[k] = if type(v) == "table" then table.clone(v) else v
		elseif type(v) == "table" and type(data[k]) == "table" then
			reconcile(data[k], v)
		end
	end
end

function DataService.load(player: Player)
	local key = "u_" .. player.UserId
	local data
	for attempt = 1, 4 do
		local ok, res = pcall(function() return STORE:GetAsync(key) end)
		if ok then data = res break end
		warn("[DataService] lecture échouée (" .. attempt .. ")", res)
		task.wait(1.5 * attempt)
	end
	data = data or template()
	reconcile(data, template())
	profiles[player] = data
	return data
end

function DataService.save(player: Player)
	local data = profiles[player]
	if not data then return end
	local key = "u_" .. player.UserId
	for attempt = 1, 4 do
		local ok, err = pcall(function() STORE:SetAsync(key, data) end)
		if ok then return true end
		warn("[DataService] écriture échouée (" .. attempt .. ")", err)
		task.wait(1.5 * attempt)
	end
	return false
end

function DataService.get(player: Player)
	return profiles[player]
end

Players.PlayerAdded:Connect(function(p) DataService.load(p) end)
Players.PlayerRemoving:Connect(function(p) DataService.save(p); profiles[p] = nil end)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(DataService.load, p) end

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for p in pairs(profiles) do task.spawn(DataService.save, p) end
	end
end)

game:BindToClose(function()
	if RunService:IsStudio() then return end
	for p in pairs(profiles) do DataService.save(p) end
end)

return DataService
