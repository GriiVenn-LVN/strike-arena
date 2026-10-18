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
local killcamEvent = remoteEvent("KillcamHold") -- victime -> serveur : kill-cam en cours (true) / finie ou passée (false)
local KILLCAM_MAX = 9                          -- la réapparition n'attend jamais plus longtemps la kill-cam
local kcHold: { [Player]: boolean? } = {}
killcamEvent.OnServerEvent:Connect(function(p: Player, on: any) kcHold[p] = if on == true then true else nil end)
Players.PlayerRemoving:Connect(function(p: Player) kcHold[p] = nil end)
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
	if M.map and M.map.cellToWorld then return M.map.cellToWorld(cx, cz) end   -- origine de la carte + hauteur du sol (toits, plateformes)
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
	local chosen = p:GetAttribute("Primary")
	local secondary = p:GetAttribute("Secondary")
	local primary = M.chosen[p] or (if typeof(chosen) == "string" then chosen else base.primary)
	return { primary, if typeof(secondary) == "string" then secondary else base.secondary, "knife" }
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
			-- la réapparition attend la fin de la kill-cam (comme sur le web), sans jamais dépasser KILLCAM_MAX
			local deadline = os.clock() + KILLCAM_MAX - TDM.respawnDelay
			while kcHold[p] and os.clock() < deadline do task.wait(0.1) end
			kcHold[p] = nil
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

-- ---------- objets à ramasser (bouclier, santé, munitions), comme makePickup() du web ----------
-- bouclier : cristal bleu (+25, jusqu'à 50) ; santé : cube rouge à croix blanche (+35) ; munitions : boîte jaune.
-- Un soldat éliminé lâche parfois un bouclier (toujours s'il en avait encore) qui reste 25 s.
-- Le client fait tourner et flotter les objets (ShieldController) ; le serveur gère la prise.
local PICKUP_COLORS = { shield = Color3.fromRGB(49, 200, 255), health = Color3.fromRGB(255, 74, 90), ammo = Color3.fromRGB(255, 210, 74) }
local pickupToast = remoteEvent("PickupToast")  -- serveur -> joueur : objet ramassé (sorte)
local tempPickups: { Model } = {}

local function pickupPart(name: string, size: Vector3, color: Color3, cf: CFrame, parent: Instance, transparency: number?): Part
	local p = Instance.new("Part"); p.Name = name; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
	p.CastShadow = false; p.Size = size; p.Color = color; p.Material = Enum.Material.Neon; p.CFrame = cf
	p.Transparency = transparency or 0.08; p.Parent = parent
	return p
end

local function makePickup(kind: string, pos: Vector3, temp: boolean)
	local col = PICKUP_COLORS[kind] or Color3.new(1, 1, 1)
	local model = Instance.new("Model"); model.Name = "Pickup_" .. kind
	model:SetAttribute("Pickup", kind)
	local corePos = pos + Vector3.new(0, 0.9 * U, 0)
	local core: Part
	if kind == "shield" then       -- octaèdre du web : un cube posé sur une pointe
		core = pickupPart("Core", Vector3.new(0.4, 0.4, 0.4) * U, col, CFrame.new(corePos) * CFrame.Angles(math.rad(45), 0, math.rad(35.26)), model)
	elseif kind == "health" then
		core = pickupPart("Core", Vector3.new(0.4, 0.4, 0.4) * U, col, CFrame.new(corePos), model)
		pickupPart("CrossA", Vector3.new(0.5, 0.12, 0.12) * U, Color3.new(1, 1, 1), CFrame.new(corePos), model, 0)
		pickupPart("CrossB", Vector3.new(0.12, 0.5, 0.12) * U, Color3.new(1, 1, 1), CFrame.new(corePos), model, 0)
	else
		core = pickupPart("Core", Vector3.new(0.5, 0.28, 0.32) * U, col, CFrame.new(corePos), model)
	end
	local light = Instance.new("PointLight"); light.Color = col; light.Range = 2.4 * U; light.Brightness = 1.6; light.Parent = core
	-- anneau au sol
	local ring = pickupPart("Ring", Vector3.new(0.04 * U, 1.3 * U, 1.3 * U), col, CFrame.new(pos + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)), model, 0.5)
	ring.Shape = Enum.PartType.Cylinder
	-- zone de prise (invisible) : 1,3 m autour, comme le web
	local zone = pickupPart("Zone", Vector3.new(2.6, 3, 2.6) * U, col, CFrame.new(pos + Vector3.new(0, 1.5 * U, 0)), model, 1)
	zone.CanTouch = true
	model.PrimaryPart = core
	model.Parent = M.map.folder
	if temp then
		table.insert(tempPickups, model)
		if #tempPickups > 6 then local old = table.remove(tempPickups, 1); if old and old.Parent then old:Destroy() end end
		task.delay(25, function() if model.Parent then model:Destroy() end end)
	end
	local ready = true
	local function setShown(on: boolean)
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and d.Name ~= "Zone" then d.LocalTransparencyModifier = 0; d.Transparency = if on then (if d.Name == "Ring" then 0.5 elseif d.Name:sub(1, 5) == "Cross" then 0 else 0.08) else 1 end
		end
		light.Enabled = on
		model:SetAttribute("Ready", on)
	end
	model:SetAttribute("Ready", true)
	zone.Touched:Connect(function(hit)
		if not ready or M.state ~= "live" then return end
		local m = hit:FindFirstAncestorOfClass("Model")
		local hum = m and m:FindFirstChildOfClass("Humanoid")
		if not m or not hum or hum.Health <= 0 then return end
		local c = WeaponService.combatantOf(m)
		if not WeaponService.teamOf(c) then return end
		if kind == "health" then
			if hum.Health >= hum.MaxHealth then return end
			hum.Health = math.min(hum.MaxHealth, hum.Health + 35)
		elseif kind == "shield" then
			if WeaponService.shieldOf(c) >= Config.SHIELD_MAX then return end
			WeaponService.addShield(c, 25)
		else
			WeaponService.resupply(c)
		end
		local pl = Players:GetPlayerFromCharacter(m)
		if pl then pickupToast:FireClient(pl, kind) end
		if temp then model:Destroy(); return end
		ready = false; setShown(false)
		task.delay(20, function()
			if model.Parent then ready = true; setShown(true) end
		end)
	end)
end

local function spawnPickups()
	for _, pk in ipairs(M.map.data.pickups or {}) do
		makePickup(pk[3], cellToWorld(pk[1], pk[2]), false)
	end
end

-- bouclier lâché par un soldat éliminé (web : s'il en avait encore, ou 18 % du temps)
local function dropShield(victim: any)
	local char = WeaponService.charOf(victim)
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not M.map then return end
	if WeaponService.shieldOf(victim) > 0 or math.random() < 0.18 then
		local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = { char :: Instance }
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -20, 0), rp)
		makePickup("shield", if hit then hit.Position else root.Position - Vector3.new(0, 3, 0), true)
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
	dropShield(victim)
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
		deathEvent:FireClient(vp, { killer = ks.name, weapon = weaponName(key), headshot = headshot, respawn = TDM.respawnDelay,
			killerChar = WeaponService.charOf(killer), victimName = vs.name, key = key, killcam = true })
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
		timeLeft = math.max(0, math.floor(M.endsAt - os.clock())), mapName = M.map and M.map.data.name or "", mapId = M.map and M.map.data.id or "", board = board(),
	})
end

-- ---------- choix de l'arme principale (menu de chargement) ----------
-- arme principale (slot 0) ou pistolet (slot 1) ; gardé dans le profil, appliqué à la prochaine apparition
loadoutFn.OnServerInvoke = function(player: Player, key: any)
	if typeof(key) ~= "string" then return false end
	local w = Config.WEAPONS[key]
	if not w or (w.slot ~= 0 and w.slot ~= 1) then return false end
	local profile = DataService.get(player)
	if not ShopCatalog.STARTER_WEAPONS[key] and not (profile and ShopCatalog.ownsWeapon(profile, key)) then return false end
	if w.slot == 0 then
		M.chosen[player] = key
		player:SetAttribute("Primary", key)   -- reprise aussi par les duels et le stand de tir du lobby
	else
		player:SetAttribute("Secondary", key)
	end
	if profile then
		profile.loadout = profile.loadout or {}
		profile.loadout[if w.slot == 0 then "primary" else "secondary"] = key
	end
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
