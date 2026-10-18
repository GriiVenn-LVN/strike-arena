--!strict
-- ServerScriptService/DataService (ModuleScript)
-- Sauvegarde du profil joueur : XP, pièces, inventaire (skins/danses), caisses, pitié, stats, défis, série quotidienne.
-- Ne JAMAIS faire confiance au client : toutes les modifications passent par le serveur.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Stores = require(script.Parent.Stores)
local STORE = Stores.get("StrikeArenaProfile_v1")
local AUTOSAVE_INTERVAL = 60

local DataService = {}
local profiles: { [Player]: any } = {}
local loadFailed: { [Player]: boolean } = {}   -- lecture ratée : on ne sauvegarde pas, sinon on écraserait le vrai profil

local function template()
	return {
		version = 1,
		xp = 0,
		coins = 250,
		lastLoginDay = 0,            -- jour UTC (os.time() // 86400)
		streak = 0,
		inv = { skins = {}, dances = { "wave", "clap" }, weapons = {}, outfits = {}, sights = {}, reticles = {}, misc = {}, exclusive = {}, killfx = {} },   -- exclusive = camos animés achetés en Robux   -- skins[weaponKey] = { skinIndex, ... } ; voir Shared/ShopCatalog
		equippedDance = "wave",
		equipped = { outfit = 1, reticle = "dot_red", trail = "", sights = {}, animCamo = {}, killFx = "none" },   -- animCamo[weaponKey] = camo animé (ConfigExtra.EXCLUSIVES)   -- sights[weaponKey] = id de ConfigExtra.SIGHTS
		boxes = { std = 1, prem = 0 },
		pity = { epic = 0, legend = 0 },
		opened = 0,
		stats = { matches = 0, wins = 0, kills = 0, deaths = 0, hs = 0, dmg = 0, shots = 0, hits = 0, seconds = 0, bestStreak = 0, byMode = {}, byMap = {}, byWeapon = {} },
		history = {},
		missions = { day = 0, list = {} },
		binds = {},                 -- touches personnalisées (synchronisées avec le client)
		codes = {},                 -- codes promo déjà utilisés (CodeService)
		social = {},                -- social.group = date de la récompense du groupe Roblox
		duel = { elo = 1000, w = 0, l = 0, best = 1000 },   -- duels 1v1 / 2v2 (DuelService)
		lobby = { rangeBest = 0, rangeRewarded = false, parkourBest = 0, parkourRewarded = false },
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
	local data, loaded = nil, false
	for attempt = 1, 4 do
		local ok, res = pcall(function() return STORE:GetAsync(key) end)
		if ok then data = res; loaded = true break end
		warn("[DataService] lecture échouée (" .. attempt .. ")", res)
		task.wait(1.5 * attempt)
	end
	if not loaded then
		loadFailed[player] = true
		warn("[DataService] profil de " .. player.Name .. " non chargé : partie jouable, mais rien ne sera sauvegardé")
	end
	data = data or template()
	reconcile(data, template())
	profiles[player] = data
	-- armes choisies dans le menu de chargement (LoadoutUI), gardées d'une session à l'autre
	if typeof(data.loadout) == "table" then
		if typeof(data.loadout.primary) == "string" then player:SetAttribute("Primary", data.loadout.primary) end
		if typeof(data.loadout.secondary) == "string" then player:SetAttribute("Secondary", data.loadout.secondary) end
	end
	return data
end

function DataService.save(player: Player)
	local data = profiles[player]
	if not data or loadFailed[player] then return end
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
Players.PlayerRemoving:Connect(function(p) DataService.save(p); profiles[p] = nil; loadFailed[p] = nil end)
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
