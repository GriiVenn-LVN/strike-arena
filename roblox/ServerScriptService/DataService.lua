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
		purchases = {},             -- offres uniques déjà achetées en Robux (pack de départ : ShopService)
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

-- Verrou de session (champ _lock du profil enregistré) : un joueur qui change vite de serveur ne doit pas voir
-- l'ancien serveur écraser, en sauvegardant en retard, ce que le nouveau a déjà chargé. Le verrou est posé au chargement,
-- rafraîchi à chaque sauvegarde et levé au départ ; au-delà de LOCK_STALE secondes (serveur planté), il est repris.
local LOCK_STALE = 300
local function lockedByOther(old: any): boolean
	local lk = typeof(old) == "table" and old._lock
	return typeof(lk) == "table" and lk.job ~= game.JobId and typeof(lk.t) == "number" and os.time() - lk.t < LOCK_STALE
end

function DataService.load(player: Player)
	local key = "u_" .. player.UserId
	local data, loaded = nil, false
	for attempt = 1, 6 do
		local claimed, busy = false, false
		local ok, res = pcall(function()
			return STORE:UpdateAsync(key, function(old: any)
				claimed, busy = false, false
				-- encore ouvert sur un autre serveur : on attend qu'il sauvegarde (on le reprend au dernier essai)
				if lockedByOther(old) and attempt < 6 then busy = true; return nil end
				local out = if typeof(old) == "table" then old else template()
				out._lock = { job = game.JobId, t = os.time() }
				claimed = true
				return out
			end)
		end)
		if ok and claimed then data = res; loaded = true; break end
		if not ok then warn("[DataService] lecture échouée (" .. attempt .. ")", res) end
		if not player.Parent then return nil end
		task.wait(if busy then 3 else 1.5 * attempt)
	end
	if not loaded then
		loadFailed[player] = true
		warn("[DataService] profil de " .. player.Name .. " non chargé : partie jouable, mais rien ne sera sauvegardé")
	end
	data = if typeof(data) == "table" then table.clone(data) else template()
	data._lock = nil
	reconcile(data, template())
	profiles[player] = data
	-- parti pendant le chargement : PlayerRemoving est déjà passé, on enregistre (verrou levé) et on oublie le profil
	if not player.Parent then
		DataService.save(player, true)
		profiles[player] = nil; loadFailed[player] = nil
		return nil
	end
	-- armes choisies dans le menu de chargement (LoadoutUI), gardées d'une session à l'autre
	if typeof(data.loadout) == "table" then
		if typeof(data.loadout.primary) == "string" then player:SetAttribute("Primary", data.loadout.primary) end
		if typeof(data.loadout.secondary) == "string" then player:SetAttribute("Secondary", data.loadout.secondary) end
	end
	DataService.syncSkins(player)
	return data
end

-- Skins équipés recopiés en attributs du joueur (Skin_<arme> = numéro de Config.SKINS, Camo_<arme> = camo animé) :
-- l'arme en main (vue subjective) et l'arme vue par les autres sont peintes d'après eux.
function DataService.syncSkins(player: Player)
	local data = profiles[player]
	if not data then return end
	local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
	local camos = data.equipped and data.equipped.animCamo or {}
	for key in pairs(Config.WEAPONS) do
		local sk = data.equippedSkins and data.equippedSkins[key]
		player:SetAttribute("Skin_" .. key, if typeof(sk) == "number" and sk > 1 then sk else nil)
		player:SetAttribute("Camo_" .. key, if typeof(camos[key]) == "string" then camos[key] else nil)
	end
end

-- Sauvegarde : une seule écriture à la fois par joueur, au plus une toutes les WRITE_GAP secondes (limite Roblox par clé) ;
-- les demandes qui arrivent pendant une écriture sont regroupées dans la suivante. Renvoie true si le profil est enregistré.
-- release = départ du joueur : le verrou de session est levé.
local WRITE_GAP = 6
local inflight: { [Player]: boolean } = {}
local again: { [Player]: boolean } = {}
local lastWrite: { [Player]: number } = {}
local lastOk: { [Player]: boolean } = {}
local releasing: { [Player]: boolean } = {}

function DataService.canSave(player: Player): boolean
	return profiles[player] ~= nil and not loadFailed[player]
end

function DataService.save(player: Player, release: boolean?): boolean
	local data = profiles[player]
	if not data or loadFailed[player] then return false end
	if release then releasing[player] = true end
	if inflight[player] then
		again[player] = true
		while inflight[player] do task.wait(0.2) end
		return lastOk[player] == true
	end
	inflight[player] = true
	local key = "u_" .. player.UserId
	local saved = false
	repeat
		again[player] = nil
		local gap = WRITE_GAP - (os.clock() - (lastWrite[player] or -WRITE_GAP))
		if gap > 0 then task.wait(gap) end
		saved = false
		for attempt = 1, 4 do
			local stolen = false
			local free = releasing[player] == true
			local ok, err = pcall(function()
				STORE:UpdateAsync(key, function(old: any)
					stolen = false
					if lockedByOther(old) then stolen = true; return nil end   -- repris par un autre serveur : on n'écrase rien
					local out = table.clone(data)
					out._lock = if free then nil else { job = game.JobId, t = os.time() }
					return out
				end)
			end)
			lastWrite[player] = os.clock()
			if ok and stolen then
				warn("[DataService] profil de " .. player.Name .. " ouvert sur un autre serveur : sauvegarde coupée ici")
				loadFailed[player] = true
				break
			end
			if ok then saved = true; break end
			warn("[DataService] écriture échouée (" .. attempt .. ")", err)
			task.wait(1.5 * attempt)
		end
	until not again[player] or loadFailed[player]
	lastOk[player] = saved
	inflight[player] = nil
	return saved
end

function DataService.get(player: Player)
	return profiles[player]
end

local function forget(p: Player)
	profiles[p] = nil; loadFailed[p] = nil
	again[p] = nil; lastWrite[p] = nil; lastOk[p] = nil; releasing[p] = nil
end
Players.PlayerAdded:Connect(function(p) DataService.load(p) end)
Players.PlayerRemoving:Connect(function(p) DataService.save(p, true); forget(p) end)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(DataService.load, p) end

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for p in pairs(profiles) do task.spawn(DataService.save, p) end
	end
end)

-- fermeture du serveur : toutes les sauvegardes en parallèle (30 s au plus), verrous levés
game:BindToClose(function()
	if RunService:IsStudio() then return end
	local left = 0
	for p in pairs(profiles) do
		left += 1
		task.spawn(function() pcall(DataService.save, p, true); left -= 1 end)
	end
	local t0 = os.clock()
	while left > 0 and os.clock() - t0 < 26 do task.wait(0.2) end
end)

return DataService
