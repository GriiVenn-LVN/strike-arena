--!strict
-- ServerScriptService/RoundService (ModuleScript)
-- Mode "Compétitif" 5v5 : cinématique -> achat (freeze) -> manche -> fin ; pose/désamorçage de la bombe, économie.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local RewardService = require(script.Parent.RewardService)
local MapBuilder = require(script.Parent.MapBuilder)
local WeaponService = require(script.Parent.WeaponService)

local cineEvent = Instance.new("RemoteEvent"); cineEvent.Name = "PlayCinematic"; cineEvent.Parent = ReplicatedStorage
local stateEvent = Instance.new("RemoteEvent"); stateEvent.Name = "RoundState"; stateEvent.Parent = ReplicatedStorage
local resultEvent = Instance.new("RemoteEvent"); resultEvent.Name = "MatchResult"; resultEvent.Parent = ReplicatedStorage

local RoundService = {}

local teamT, teamCT
local function ensureTeams()
	if teamT then return end
	teamT = Teams:FindFirstChild("Attaquants") or Instance.new("Team"); teamT.Name = "Attaquants"; teamT.TeamColor = BrickColor.new("Deep orange"); teamT.AutoAssignable = false; teamT.Parent = Teams
	teamCT = Teams:FindFirstChild("Défenseurs") or Instance.new("Team"); teamCT.Name = "Défenseurs"; teamCT.TeamColor = BrickColor.new("Bright blue"); teamCT.AutoAssignable = false; teamCT.Parent = Teams
end

local M: any = { score = { 0, 0 }, round = 0, state = "idle", planted = false, bombSite = nil, bombTime = 0, money = {} }
local mapInfo

local function aliveCount(team: Team): number
	local n = 0
	for _, p in ipairs(team:GetPlayers()) do
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then n += 1 end
	end
	return n
end

local function spawnTeam(team: Team, spots: { Vector3 })
	for i, p in ipairs(team:GetPlayers()) do
		p:LoadCharacter()
		local char = p.Character or p.CharacterAdded:Wait()
		char:PivotTo(CFrame.new(spots[((i - 1) % #spots) + 1]))
		WeaponService.giveWeapon(p, team == teamT and "glock" or "usp")
	end
end

local function setState(s: string, extra: any?)
	M.state = s
	stateEvent:FireAllClients(s, extra)
end

local function endRound(winner: Team, reason: string)
	if M.state ~= "live" then return end
	M.score[winner == teamT and 1 or 2] += 1
	setState("end", { winner = winner.Name, reason = reason, score = M.score })
	for _, p in ipairs(Players:GetPlayers()) do
		local bonus = (p.Team == winner) and 3250 or 1400
		M.money[p] = math.min(Config.MAX_MONEY, (M.money[p] or Config.START_MONEY) + bonus)
	end
	task.wait(5.5)
end

function RoundService.startMatch(mapId: string)
	ensureTeams()
	mapInfo = MapBuilder.build(mapId)
	-- répartition 5v5
	local list = Players:GetPlayers()
	for i, p in ipairs(list) do p.Team = (i % 2 == 1) and teamT or teamCT; M.money[p] = Config.START_MONEY end
	M.score = { 0, 0 }; M.round = 0

	-- cinématique d'arrivée en hélicoptère (jouée côté client, une fois par partie)
	for _, p in ipairs(list) do
		local north = p.Team == teamCT
		cineEvent:FireClient(p, {
			team = p.Team.Name,
			hover = (north and mapInfo.spawns.CT[1] or mapInfo.spawns.T[1]) + Vector3.new(0, 11 * Config.STUDS_PER_METER, 0),
			north = north,
			duration = 10,
			mapName = mapInfo.data.name,
		})
	end
	task.wait(10.5)

	while M.score[1] < Config.WIN_ROUNDS and M.score[2] < Config.WIN_ROUNDS do
		M.round += 1; M.planted = false
		spawnTeam(teamT, mapInfo.spawns.T); spawnTeam(teamCT, mapInfo.spawns.CT)
		setState("freeze", { round = M.round, money = M.money, time = Config.FREEZE_TIME })
		task.wait(Config.FREEZE_TIME)
		setState("live", { time = Config.ROUND_TIME })
		local t0 = os.clock()
		while M.state == "live" do
			task.wait(0.25)
			if aliveCount(teamT) == 0 and not M.planted then endRound(teamCT, "Attaquants éliminés") break end
			if aliveCount(teamCT) == 0 then endRound(teamT, "Défenseurs éliminés") break end
			if M.planted and os.clock() - M.bombTime >= Config.BOMB_TIME then endRound(teamT, "La bombe a explosé") break end
			if not M.planted and os.clock() - t0 >= Config.ROUND_TIME then endRound(teamCT, "Temps écoulé") break end
		end
	end

	-- fin de partie : récompenses (XP, pièces, niveaux)
	for _, p in ipairs(Players:GetPlayers()) do
		local won = (p.Team == teamT and M.score[1] > M.score[2]) or (p.Team == teamCT and M.score[2] > M.score[1])
		local rewards = RewardService.finishMatch(p, { kills = 0, deaths = 0, hs = 0, dmg = 0, shots = 0, hits = 0, plants = 0, defuses = 0, won = won, seconds = 900, mode = "bomb", map = mapId })
		resultEvent:FireClient(p, won, M.score, rewards)
	end
	setState("over")
end

-- Pose / désamorçage : ProximityPrompt sur chaque site (ici : exemple pour le premier site)
function RoundService.setupBombPrompts()
	if not mapInfo then return end
	for _, site in ipairs(mapInfo.sites) do
		local anchor = Instance.new("Part"); anchor.Anchored = true; anchor.CanCollide = false; anchor.Transparency = 1
		anchor.Size = Vector3.new(2, 2, 2); anchor.Position = site.pos; anchor.Parent = mapInfo.folder
		local pp = Instance.new("ProximityPrompt")
		pp.ActionText = "Poser la bombe"; pp.HoldDuration = Config.PLANT_TIME; pp.MaxActivationDistance = site.radius; pp.RequiresLineOfSight = false
		pp.Parent = anchor
		pp.Triggered:Connect(function(player)
			if player.Team == teamT and M.state == "live" and not M.planted then
				M.planted = true; M.bombTime = os.clock(); M.bombSite = site.name
				pp.ActionText = "Désamorcer"; pp.HoldDuration = Config.DEFUSE_TIME
				stateEvent:FireAllClients("planted", { site = site.name })
			elseif player.Team == teamCT and M.planted then
				M.planted = false
				endRound(teamCT, "Bombe désamorcée")
			end
		end)
	end
end

return RoundService
