--!strict
-- ServerScriptService/Main (Script) — point d'entrée serveur
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataService = require(script.Parent.DataService)
local RewardService = require(script.Parent.RewardService)
require(script.Parent.WeaponService)
local RoundService = require(script.Parent.RoundService)

-- ---------- Remotes pour l'interface (profil, récompense quotidienne, défis) ----------
local function remoteFunction(name: string): RemoteFunction
	local r = Instance.new("RemoteFunction"); r.Name = name; r.Parent = ReplicatedStorage; return r
end

local getProfile = remoteFunction("GetProfile")
getProfile.OnServerInvoke = function(player: Player)
	local profile = DataService.get(player)
	if not profile then return nil end
	RewardService.ensureMissions(profile)
	local level, cur, need = RewardService.levelInfo(profile)
	return { profile = profile, level = level, xp = cur, xpNeed = need, daily = RewardService.dailyStatus(profile) }
end

local claimDaily = remoteFunction("ClaimDaily")
claimDaily.OnServerInvoke = function(player: Player)
	local reward, day = RewardService.claimDaily(player)
	return reward and { reward = reward, day = day } or nil
end

local claimMission = remoteFunction("ClaimMission")
claimMission.OnServerInvoke = function(player: Player, index: any)
	if typeof(index) ~= "number" then return nil end
	return RewardService.claimMission(player, index)
end

local equipDance = remoteFunction("EquipDance")
equipDance.OnServerInvoke = function(player: Player, id: any)
	local profile = DataService.get(player)
	if not profile or typeof(id) ~= "string" or not table.find(profile.inv.dances, id) then return false end
	profile.equippedDance = id
	return true
end

local equipSkin = remoteFunction("EquipSkin")
equipSkin.OnServerInvoke = function(player: Player, weapon: any, skinIndex: any)
	local profile = DataService.get(player)
	if not profile or typeof(weapon) ~= "string" or typeof(skinIndex) ~= "number" then return false end
	local Config = require(ReplicatedStorage.Shared.Config)
	local skin = Config.SKINS[skinIndex]
	if not skin or not Config.WEAPONS[weapon] then return false end
	local owned = skin.rarity == 1 or (profile.inv.skins[weapon] and table.find(profile.inv.skins[weapon], skinIndex))
	if not owned then return false end
	profile.equippedSkins = profile.equippedSkins or {}
	profile.equippedSkins[weapon] = skinIndex
	return true
end

-- ---------- Lancement automatique d'une partie quand assez de joueurs sont là ----------
local MIN_PLAYERS = 2     -- mets 10 pour de vrais 5v5 ; complète avec des bots (PathfindingService) si besoin
local started = false
local function tryStart()
	if started or #Players:GetPlayers() < MIN_PLAYERS then return end
	started = true
	task.spawn(function()
		RoundService.startMatch("village")
		started = false
	end)
end
Players.PlayerAdded:Connect(function() task.wait(5); tryStart() end)
