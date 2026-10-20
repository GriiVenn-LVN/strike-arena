--!strict
-- ServerScriptService/Main (Script) — point d'entrée serveur
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataService = require(script.Parent.DataService)
local RewardService = require(script.Parent.RewardService)
require(script.Parent.WeaponService)
require(script.Parent.CodeService)        -- codes promo + récompense du groupe Roblox
require(script.Parent.KillFxService)      -- effets d'élimination
local ProgressService = require(script.Parent.ProgressService)
require(script.Parent.MenuService)        -- menu principal : défis de la semaine, réglages gardés, titre
require(script.Parent.MedalService)       -- médailles, bilan perso et défis de fin de partie (src/8G_medals.js, src/8O_defis.js)
require(script.Parent.RecapService)       -- écran de fin : détail des gains, barre de niveau, défis terminés (après MedalService)
require(script.Parent.AdminService)       -- panneau admin (propriétaire du jeu + code, src/8M_admin.js)
require(script.Parent.HalloweenService)   -- décor d'Halloween du lobby et des cartes, citrouilles lâchées (src/8W_halloween.js)
require(script.Parent.SprayService)       -- sprays sur les murs (touche J, src/64_extras.js)
require(script.Parent.TeamCommsService)   -- ping et messages rapides d'équipe (touches molette/K et N)
require(script.Parent.PerkDrinkService)   -- boisson d'atout (src/8U_perkdrink.js), appelée quand on prend un atout en Zombies
local LeaderboardService = require(script.Parent.LeaderboardService)
local ModeConfig = require(ReplicatedStorage.Shared.ModeConfig)
local CommunityConfig = require(ReplicatedStorage.Shared.CommunityConfig)

-- ---------- Remotes pour l'interface (profil, récompense quotidienne, défis) ----------
local function remoteFunction(name: string): RemoteFunction
	local r = Instance.new("RemoteFunction"); r.Name = name; r.Parent = ReplicatedStorage; return r
end

local getProfile = remoteFunction("GetProfile")
getProfile.OnServerInvoke = function(player: Player)
	local profile = DataService.get(player)
	if not profile then return nil end
	RewardService.ensureMissions(profile)
	RewardService.ensureWeekly(profile)
	ProgressService.ensure(profile)              -- passe de saison, classement, événement (affichés par le menu)
	local level, cur, need = RewardService.levelInfo(profile)
	return { profile = profile, level = level, xp = cur, xpNeed = need, daily = RewardService.dailyStatus(profile),
		eventActive = ProgressService.eventActive(), now = os.time(), weekend = RewardService.weekend() }
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

-- liste complète des défis du jour et de la semaine avec leurs textes (ClaimWeekly est dans MenuService)
local getChallenges = remoteFunction("GetChallenges")
getChallenges.OnServerInvoke = function(player: Player) return RewardService.challenges(player) end

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
	if profile.equipped and profile.equipped.animCamo then profile.equipped.animCamo[weapon] = nil end   -- un skin remplace le camo animé
	DataService.syncSkins(player)
	return true
end

-- ---------- Parties (MatchService) et lobby ----------
-- Chaque joueur lance sa partie depuis le menu (mode, carte, bots, comme l'écran « Jouer » du web) ou passe par
-- « Partie rapide » ; plusieurs parties tournent en même temps sur le serveur, chacune sur sa propre carte.
local MatchService = require(script.Parent.MatchService)
Players.CharacterAutoLoads = false
if CommunityConfig.LOBBY_ENABLED then
	-- lobby jouable (stand de tir, parcours, classement géant, bornes) + duels 1v1 / 2v2 depuis ses plateformes
	local LobbyService = require(script.Parent.LobbyService)
	LobbyService.start()
	LeaderboardService.start(LobbyService.board)
	require(script.Parent.DuelService).start()
else
	-- sans lobby : on arrive directement dans une partie rapide
	LeaderboardService.start(nil)
	local function arrive(p: Player) task.delay(2, function() if p.Parent then MatchService.quick(p, ModeConfig.MODE) end end) end
	Players.PlayerAdded:Connect(arrive)
	for _, p in ipairs(Players:GetPlayers()) do arrive(p) end
end
