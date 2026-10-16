--!strict
-- ServerScriptService/TDMService (ModuleScript, lancé par Main quand ModeConfig.MODE = "tdm")
-- Match à mort par équipe sur Village : 5 contre 5 (bots pour compléter), réapparition, protection d'apparition,
-- objets à ramasser, fil des éliminations, séries, assistances, tableau des scores (Tab), écran de fin avec récompenses.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Config = require(ReplicatedStorage.Shared.Config)
local ModeConfig = require(ReplicatedStorage.Shared.ModeConfig)
local CommunityConfig = require(ReplicatedStorage.Shared.CommunityConfig)
local ShopCatalog = require(ReplicatedStorage.Shared.ShopCatalog)
local DataService = require(script.Parent.DataService)
local RewardService = require(script.Parent.RewardService)
local ProgressService = require(script.Parent.ProgressService)
local MapBuilder = require(script.Parent.MapBuilder)
local WeaponService = require(script.Parent.WeaponService)
local BotService = require(script.Parent.BotService)
local NetService = require(script.Parent.NetService)

local TDM = ModeConfig.TDM
local U = Config.STUDS_PER_METER
local CELL = Config.CELL * U

local function remoteEvent(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent"); r.Name = name; r.Parent = ReplicatedStorage; return r
end
local stateEvent = remoteEvent("TDMState")     -- serveur -> tous : score, temps, tableau
local feedEvent = remoteEvent("KillFeed")      -- serveur -> tous : une élimination
local bannerEvent = remoteEvent("KillBanner")  -- serveur -> tueur : « +100 Élimination », séries
local deathEvent = remoteEvent("DeathInfo")    -- serveur -> victime : par qui, réapparition dans…
local endEvent = remoteEvent("MatchEnd")       -- serveur -> chaque joueur : victoire/défaite + récompenses
local loadoutFn = Instance.new("RemoteFunction"); loadoutFn.Name = "SetLoadout"; loadoutFn.Parent = ReplicatedStorage

local TDMService = {}

-- ---------- équipes ----------
local teamObjs: { [string]: Team } = {}
local TEAM_BRICK = { Attaquants = "Deep orange", ["Défenseurs"] = "Bright blue" }
local function ensureTeams()
	for _, name in ipairs(TDM.teams) do
		local t = Teams:FindFirstChild(name) :: Team?
		if not t then
			local nt = Instance.new("Team"); nt.Name = name; nt.TeamColor = BrickColor.new(TEAM_BRICK[name] or "White")
			nt.AutoAssignable = false; nt.Parent = Teams
			t = nt
		end
		teamObjs[name] = t :: Team
	end
end

-- ---------- état du match ----------
type Stat = {
	name: string, team: string, bot: boolean, player: Player?, k: number, d: number, a: number, hs: number,
	dmg: number, shots: number, hits: number, streak: number, bestStreak: number, score: number, weaponKills: { [string]: number },
}
local M = {
	state = "idle", score = {} :: { [string]: number }, endsAt = 0, startedAt = 0,
	stats = {} :: { [any]: Stat }, dmgBy = {} :: { [any]: { [any]: number } },
	map = nil :: any, roam = {} :: { Vector3 }, chosen = {} :: { [Player]: string },
}

-- Joueurs qui participent au match (attribut Zone = "tdm") ; les autres sont dans le lobby ou en duel
local function participants(): { Player }
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("Zone") == "tdm" then table.insert(list, p) end
	end
	return list
end

-- Un combattant compte pour ce match : bot, ou joueur dans la zone « tdm »
local function inTDM(c: any): boolean
	if typeof(c) ~= "Instance" then return false end
	if c:IsA("Model") then return true end
	return c:IsA("Player") and c:GetAttribute("Zone") == "tdm"
end

local function keyOf(c: any): any
	if typeof(c) == "Instance" and c:IsA("Model") then return "bot:" .. c.Name end
	return c
end

local function statOf(c: any): Stat?
	local k = keyOf(c)
	local s = M.stats[k]
	if not s then
		local team = WeaponService.teamOf(c)
		if not team then return nil end
		local isBot = typeof(c) == "Instance" and c:IsA("Model")
		s = { name = WeaponService.nameOf(c), team = team, bot = isBot, player = if isBot then nil else c,
			k = 0, d = 0, a = 0, hs = 0, dmg = 0, shots = 0, hits = 0, streak = 0, bestStreak = 0, score = 0, weaponKills = {} }
		M.stats[k] = s
	end
	return s
end

local function cellToWorld(cx: number, cz: number): Vector3
	return Vector3.new((cx + 0.5) * CELL, 0, (cz + 0.5) * CELL)
end

-- ---------- apparition ----------
local function enemyPositions(team: string): { Vector3 }
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if r and p.Team and p.Team.Name ~= team then table.insert(list, r.Position) end
	end
	for _, b in ipairs(BotService.list()) do
		local r = b:FindFirstChild("HumanoidRootPart") :: BasePart?
		if r and b:GetAttribute("Team") ~= team then table.insert(list, r.Position) end
	end
	return list
end

-- Choisit le point d'apparition le plus éloigné des ennemis parmi ceux de l'équipe et ceux du mode « chacun pour soi »
local function spawnPoint(team: string): Vector3
	local own = if team == TDM.teams[1] then M.map.spawns.T else M.map.spawns.CT
	local candidates = table.clone(own)
	if M.state == "live" then for _, p in ipairs(M.map.spawns.DM) do table.insert(candidates, p) end end
	local enemies = enemyPositions(team)
	local best, bestScore = candidates[math.random(#candidates)], -1
	for _ = 1, 6 do
		local c = candidates[math.random(#candidates)]
		local minD = math.huge
		for _, e in ipairs(enemies) do minD = math.min(minD, (e - c).Magnitude) end
		if minD > bestScore then best, bestScore = c, minD end
	end
	return best
end

local function protect(char: Model)
	char:SetAttribute("ProtectedUntil", workspace:GetServerTimeNow() + TDM.spawnProtection)
	local h = Instance.new("Highlight"); h.Name = "SpawnShield"; h.FillColor = Color3.fromRGB(255, 255, 255)
	h.FillTransparency = 0.75; h.OutlineColor = Color3.fromRGB(140, 220, 255); h.Parent = char
	task.delay(TDM.spawnProtection, function() if h.Parent then h:Destroy() end end)
	char:GetAttributeChangedSignal("ProtectedUntil"):Connect(function()
		if (char:GetAttribute("ProtectedUntil") :: number? or 0) <= 0 and h.Parent then h:Destroy() end
	end)
end

local function loadoutFor(p: Player, team: string): { string }
	local base = TDM.loadout[team]
	local primary = M.chosen[p] or base.primary
	return { primary, base.secondary, "knife" }
end

local spawnPlayer: (Player) -> ()
spawnPlayer = function(p: Player)
	if not p.Parent or not p.Team or p:GetAttribute("Zone") ~= "tdm" then return end
	p:LoadCharacter()
	local char = p.Character or p.CharacterAdded:Wait()
	local team = p.Team.Name
	char:PivotTo(CFrame.new(spawnPoint(team) + Vector3.new(0, 1, 0)))
	protect(char)
	WeaponService.giveLoadout(p, loadoutFor(p, team))
	statOf(p)
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	hum.Died:Connect(function()
		WeaponService.reset(p)
		if M.state ~= "live" then return end
		task.delay(TDM.respawnDelay, function()
			if M.state == "live" and p.Parent and p.Character == char and p:GetAttribute("Zone") == "tdm" then spawnPlayer(p) end
		end)
	end)
end

local spawnBot: (string, string?) -> ()
spawnBot = function(team: string, name: string?)
	local model = BotService.spawn(team, spawnPoint(team), M.roam, name)
	protect(model)
	statOf(model)
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.Died:Connect(function()
		local botName = model.Name
		task.delay(2, function() if model.Parent then BotService.remove(model) end end)
		task.delay(TDM.respawnDelay, function()
			if M.state ~= "live" then return end
			-- n'est réapparu que s'il a toujours sa place (un joueur a pu le remplacer entre-temps)
			if M.stats["bot:" .. botName] then
				local humans = #teamObjs[team]:GetPlayers()
				local bots = 0
				for _, b in ipairs(BotService.list()) do
					if b:GetAttribute("Team") == team and b ~= model then
						local bh = b:FindFirstChildOfClass("Humanoid")
						if bh and bh.Health > 0 then bots += 1 end
					end
				end
				if humans + bots < TDM.teamSize then spawnBot(team, botName) end
			end
		end)
	end)
end

-- Ajuste le nombre de bots pour que chaque équipe ait TDM.teamSize combattants
local function balanceBots()
	if M.state ~= "live" then return end
	for _, team in ipairs(TDM.teams) do
		local humans = #teamObjs[team]:GetPlayers()
		local mine = {}
		for _, b in ipairs(BotService.list()) do
			local h = b:FindFirstChildOfClass("Humanoid")
			if b:GetAttribute("Team") == team and h and h.Health > 0 then table.insert(mine, b) end
		end
		local want = math.max(0, TDM.teamSize - humans)
		while #mine > want do
			local b = table.remove(mine) :: Model
			M.stats["bot:" .. b.Name] = nil
			BotService.remove(b)
		end
		for _ = #mine + 1, want do spawnBot(team) end
	end
end

local function smallestTeam(): string
	local a, b = #teamObjs[TDM.teams[1]]:GetPlayers(), #teamObjs[TDM.teams[2]]:GetPlayers()
	if a == b then return TDM.teams[math.random(2)] end
	return if a < b then TDM.teams[1] else TDM.teams[2]
end

-- ---------- objets à ramasser (santé, bouclier, munitions) ----------
local PICKUP_COLORS = { health = Color3.fromRGB(110, 255, 140), shield = Color3.fromRGB(90, 180, 255), ammo = Color3.fromRGB(255, 205, 90) }
local function spawnPickups()
	for _, pk in ipairs(M.map.data.pickups or {}) do
		local kind = pk[3]
		local part = Instance.new("Part"); part.Name = "Pickup_" .. kind; part.Anchored = true; part.CanCollide = false; part.CanQuery = false
		part.Size = Vector3.new(2, 2, 2); part.Shape = Enum.PartType.Ball; part.Material = Enum.Material.Neon
		part.Color = PICKUP_COLORS[kind] or Color3.new(1, 1, 1)
		part.Position = cellToWorld(pk[1], pk[2]) + Vector3.new(0, 2.2, 0)
		local light = Instance.new("PointLight"); light.Color = part.Color; light.Range = 8; light.Parent = part
		part.Parent = M.map.folder
		local ready = true
		part.Touched:Connect(function(hit)
			if not ready or M.state ~= "live" then return end
			local model = hit:FindFirstAncestorOfClass("Model")
			local hum = model and model:FindFirstChildOfClass("Humanoid")
			if not model or not hum or hum.Health <= 0 then return end
			local c = WeaponService.combatantOf(model)
			if not WeaponService.teamOf(c) then return end
			if kind == "health" then
				if hum.Health >= hum.MaxHealth then return end
				hum.Health = math.min(hum.MaxHealth, hum.Health + 50)
			elseif kind == "shield" then
				if WeaponService.shieldOf(c) >= Config.SHIELD_MAX then return end
				WeaponService.addShield(c, Config.SHIELD_MAX)
			else
				WeaponService.resupply(c)
			end
			ready = false; part.Transparency = 0.85; light.Enabled = false
			task.delay(20, function()
				if part.Parent then ready = true; part.Transparency = 0; light.Enabled = true end
			end)
		end)
	end
end

-- ---------- éliminations ----------
local function weaponName(key: string): string
	if key == "frag" then return "Grenade" end
	local w = Config.WEAPONS[key]
	return w and w.name or key
end

WeaponService.Damaged:Connect(function(attacker, victim, amount: number, _headshot: boolean)
	if M.state ~= "live" or not inTDM(attacker) or not inTDM(victim) then return end
	local s = statOf(attacker)
	if s then s.dmg += amount; s.hits += 1 end
	local vk = keyOf(victim)
	local by = M.dmgBy[vk] or {}; M.dmgBy[vk] = by
	local ak = keyOf(attacker)
	by[ak] = (by[ak] or 0) + amount
end)

WeaponService.ShotFired:Connect(function(shooter, _key: string)
	if M.state ~= "live" or not inTDM(shooter) then return end
	local s = statOf(shooter)
	if s then s.shots += 1 end
end)

WeaponService.Killed:Connect(function(killer, victim, key: string, headshot: boolean)
	if M.state ~= "live" or not inTDM(killer) or not inTDM(victim) then return end
	local ks, vs = statOf(killer), statOf(victim)
	if not ks or not vs then return end
	vs.d += 1; vs.streak = 0
	ks.k += 1; ks.streak += 1; ks.bestStreak = math.max(ks.bestStreak, ks.streak)
	ks.score += TDM.scorePerKill + (if headshot then 25 else 0)
	if headshot then ks.hs += 1 end
	ks.weaponKills[key] = (ks.weaponKills[key] or 0) + 1
	M.score[ks.team] = (M.score[ks.team] or 0) + 1

	-- assistances : au moins 30 dégâts sur la victime pendant cette vie
	local vk, kk = keyOf(victim), keyOf(killer)
	for ak, amount in pairs(M.dmgBy[vk] or {}) do
		local as = M.stats[ak]
		if ak ~= kk and as and amount >= 30 then as.a += 1; as.score += TDM.scorePerAssist end
	end
	M.dmgBy[vk] = nil

	feedEvent:FireAllClients({ killer = ks.name, killerTeam = ks.team, victim = vs.name, victimTeam = vs.team, weapon = weaponName(key), headshot = headshot })

	local kp = ks.player
	if kp then
		bannerEvent:FireClient(kp, { victim = vs.name, headshot = headshot, points = TDM.scorePerKill + (if headshot then 25 else 0), streak = ks.streak, streakName = TDM.streaks[ks.streak] })
		RewardService.missionEvent(kp, "kills")
		if headshot then RewardService.missionEvent(kp, "hs") end
		if key == "knife" then RewardService.missionEvent(kp, "knife") end
	end
	local vp = vs.player
	if vp then
		deathEvent:FireClient(vp, { killer = ks.name, weapon = weaponName(key), headshot = headshot, respawn = TDM.respawnDelay })
	end
end)

-- ---------- diffusion de l'état (score, temps, tableau Tab) ----------
local function board()
	local list = {}
	for _, s in pairs(M.stats) do
		table.insert(list, { name = s.name, team = s.team, bot = s.bot, k = s.k, d = s.d, a = s.a, score = s.score,
			userId = s.player and s.player.UserId or 0, ping = if s.player then math.floor(NetService.pingOf(s.player) * 1000) else 0 })
	end
	table.sort(list, function(x, y) return x.score > y.score end)
	return list
end

local function broadcast()
	stateEvent:FireAllClients({
		state = M.state, score = M.score, teams = TDM.teams, killsToWin = TDM.killsToWin,
		timeLeft = math.max(0, math.floor(M.endsAt - os.clock())), mapName = M.map and M.map.data.name or "", board = board(),
	})
end

-- ---------- choix de l'arme principale (menu de chargement) ----------
loadoutFn.OnServerInvoke = function(player: Player, key: any)
	if typeof(key) ~= "string" then return false end
	local w = Config.WEAPONS[key]
	if not w or w.slot ~= 0 then return false end
	local profile = DataService.get(player)
	if not ShopCatalog.STARTER_WEAPONS[key] and not (profile and ShopCatalog.ownsWeapon(profile, key)) then return false end
	M.chosen[player] = key       -- appliquée à la prochaine apparition
	player:SetAttribute("Primary", key)   -- reprise aussi par les duels et le stand de tir du lobby
	return true
end

-- ---------- arrivées / départs en cours de partie ----------
-- Entrer dans le match en cours (depuis le lobby, ou directement à l'arrivée si le lobby est désactivé)
function TDMService.join(p: Player)
	if p:GetAttribute("Zone") == "tdm" then return end
	p:SetAttribute("Zone", "tdm")
	if M.state ~= "live" and M.state ~= "intermission" then return end   -- la prochaine partie le placera
	ensureTeams()
	p.Team = teamObjs[smallestTeam()]
	if M.state == "live" then
		balanceBots()
		task.spawn(spawnPlayer, p)
	end
end

-- Quitter le match (retour au lobby) : un bot reprend la place
function TDMService.leave(p: Player)
	if p:GetAttribute("Zone") ~= "tdm" then return end
	p:SetAttribute("Zone", "lobby")
	p.Team = nil
	M.chosen[p] = nil
	M.stats[p] = nil
	WeaponService.reset(p)
	task.delay(0.2, balanceBots)
end

function TDMService.state(): string
	return M.state
end

Players.PlayerAdded:Connect(function(p)
	if CommunityConfig.LOBBY_ENABLED then return end   -- avec le lobby, on rejoint par le portail (LobbyService)
	TDMService.join(p)
end)
Players.PlayerRemoving:Connect(function(p)
	M.chosen[p] = nil
	local s = M.stats[p]
	if s then M.stats[p] = nil end
	task.delay(0.5, balanceBots)   -- laisse le temps au joueur de quitter son équipe
end)

-- ---------- une partie ----------
function TDMService.playMatch()
	ensureTeams()
	for _, pk in ipairs(workspace:GetChildren()) do if pk.Name == "Pumpkin" then pk:Destroy() end end
	BotService.removeAll()
	BotService.setPaused(false)
	M.map = MapBuilder.build(TDM.map)
	M.roam = {}
	for _, c in ipairs(M.map.data.roam or {}) do table.insert(M.roam, cellToWorld(c[1], c[2]) + Vector3.new(0, 3, 0)) end
	if #M.roam == 0 then M.roam = table.clone(M.map.spawns.DM) end
	M.stats = {}; M.dmgBy = {}
	M.score = {}; for _, t in ipairs(TDM.teams) do M.score[t] = 0 end
	spawnPickups()
	pcall(ProgressService.spawnPumpkins, M.map.data, cellToWorld)   -- décor Halloween si l'événement est actif

	-- équipes équilibrées (les groupes d'amis pourront être gardés ensemble via PartyService plus tard)
	local list = participants()
	for i = #list, 2, -1 do local j = math.random(i); list[i], list[j] = list[j], list[i] end
	for i, p in ipairs(list) do p.Team = teamObjs[TDM.teams[(i - 1) % 2 + 1]] end

	M.state = "live"
	M.startedAt = os.clock(); M.endsAt = os.clock() + TDM.matchTime
	for _, p in ipairs(list) do task.spawn(spawnPlayer, p) end
	balanceBots()

	local winner: string? = nil
	while true do
		task.wait(0.5)
		broadcast()
		for _, t in ipairs(TDM.teams) do
			if M.score[t] >= TDM.killsToWin then winner = t end
		end
		if winner or os.clock() >= M.endsAt then break end
		if #participants() == 0 then break end
	end
	if not winner then
		local a, b = M.score[TDM.teams[1]], M.score[TDM.teams[2]]
		winner = if a > b then TDM.teams[1] elseif b > a then TDM.teams[2] else nil
	end

	-- fin : tout le monde s'arrête, récompenses, écran de fin
	M.state = "over"
	broadcast()
	local seconds = math.floor(os.clock() - M.startedAt)
	local finalBoard = board()
	local mvp = finalBoard[1]
	for _, p in ipairs(participants()) do
		local s = M.stats[p]
		local won = winner ~= nil and p.Team ~= nil and p.Team.Name == winner
		local rewards, progress = nil, nil
		if s then
			local okR, r = pcall(RewardService.finishMatch, p, { kills = s.k, deaths = s.d, hs = s.hs, dmg = s.dmg, shots = s.shots, hits = s.hits,
				plants = 0, defuses = 0, won = won, seconds = seconds, mode = "tdm", map = TDM.map, bestStreak = s.bestStreak, weaponKills = s.weaponKills })
			if okR then rewards = r end
			if rewards then
				local okP, pr = pcall(ProgressService.finishMatch, p, { xp = rewards.xp, won = won, mode = "tdm", kills = s.k, weaponKills = s.weaponKills })
				if okP then progress = pr end
			end
		end
		endEvent:FireClient(p, { won = won, draw = winner == nil, winner = winner, score = M.score, rewards = rewards, progress = progress,
			mvp = mvp, board = finalBoard, me = s and { k = s.k, d = s.d, a = s.a, hs = s.hs, dmg = s.dmg, score = s.score, bestStreak = s.bestStreak } or nil,
			next = TDM.intermission })
	end
	BotService.setPaused(true)
	for _, p in ipairs(participants()) do
		local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid"); if h then h.WalkSpeed = 0 end
	end

	M.state = "intermission"
	M.endsAt = os.clock() + TDM.intermission
	for _ = 1, TDM.intermission * 2 do task.wait(0.5); broadcast() end
	BotService.removeAll()
end

-- Boucle infinie : une partie, l'écran de fin, la suivante. Attend qu'il y ait assez de joueurs.
function TDMService.run()
	Players.CharacterAutoLoads = false
	while true do
		if not CommunityConfig.LOBBY_ENABLED then
			for _, p in ipairs(Players:GetPlayers()) do p:SetAttribute("Zone", "tdm") end
		end
		while #participants() < TDM.minHumans do task.wait(1) end
		task.wait(2)
		local ok, err = pcall(TDMService.playMatch)
		if not ok then warn("[TDMService] partie interrompue :", err); M.state = "idle"; BotService.removeAll(); task.wait(3) end
	end
end

return TDMService
