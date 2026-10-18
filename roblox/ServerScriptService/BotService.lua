--!strict
-- ServerScriptService/BotService (ModuleScript, requis par MatchService)
-- Bots R15 qui complètent les équipes : patrouille sur les points de passage de la carte (PathfindingService),
-- repérage des ennemis (champ de vision + rayon), temps de réaction, rafales et imprécision réglables (ModeConfig.BOT).
-- Ils tirent avec WeaponService.fire, exactement comme les joueurs.
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local ModeConfig = require(ReplicatedStorage.Shared.ModeConfig)
local WeaponService = require(script.Parent.WeaponService)

local BOT = ModeConfig.BOT
local BotService = {}

type Brain = {
	model: Model, hum: Humanoid, root: BasePart, team: string,
	roam: { Vector3 }, waypoints: { PathWaypoint }, wpIndex: number, goal: Vector3?, repathAt: number,
	target: Model?, seenAt: number, lastSeen: Vector3?, lastSeenAt: number, burstLeft: number, nextBurst: number, alive: boolean,
	match: number?, diff: any, goalFn: ((Model) -> Vector3?)?,
	nades: boolean, nadeT: number, mineT: number,
}
-- Réglages d'une apparition (MatchService) : partie, niveau (Modes.DIFFS), armes, but de déplacement imposé par le mode
-- nades = grenades et mines lancées par BotService lui-même (modes à mort ; les modes à manches ont les leurs)
export type SpawnOpts = { match: number?, diff: any?, loadout: { string }?, goal: ((Model) -> Vector3?)?, nades: boolean? }
local brains: { [Model]: Brain } = {}
local usedNames: { [string]: boolean } = {}
local folder: Folder? = nil
local paused = false

local TEAM_COLORS = {
	Attaquants = { torso = Color3.fromRGB(196, 110, 52), legs = Color3.fromRGB(92, 70, 52) },
	["Défenseurs"] = { torso = Color3.fromRGB(58, 96, 168), legs = Color3.fromRGB(44, 52, 70) },
}

local function pickName(): string
	for _ = 1, 20 do
		local n = BOT.names[math.random(#BOT.names)]
		if not usedNames[n] then usedNames[n] = true; return n end
	end
	local n = BOT.names[math.random(#BOT.names)] .. " " .. math.random(10, 99)
	usedNames[n] = true
	return n
end

local function getFolder(): Folder
	if folder and folder.Parent then return folder end
	local f = Instance.new("Folder"); f.Name = "Bots"; f.Parent = workspace
	folder = f
	return f
end

-- Toutes les cibles possibles : joueurs vivants + autres bots vivants
-- (seulement ceux de la même partie : plusieurs parties tournent en même temps sur le serveur)
local function enemiesOf(team: string, match: number?): { Model }
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		local pt = WeaponService.teamOf(p)
		if c and h and h.Health > 0 and pt and pt ~= team and p:GetAttribute("MatchId") == match then table.insert(list, c) end
	end
	for m, b in pairs(brains) do
		if b.alive and b.team ~= team and b.match == match then table.insert(list, m) end
	end
	return list
end

local function canSee(b: Brain, target: Model): (boolean, Vector3?)
	local head = target:FindFirstChild("Head") :: BasePart?
	local myHead = b.model:FindFirstChild("Head") :: BasePart?
	if not head or not myHead then return false, nil end
	local to = head.Position - myHead.Position
	local sight = if b.diff then b.diff.sight * Config.STUDS_PER_METER else BOT.viewDistance
	if to.Magnitude > sight then return false, nil end
	if b.root.CFrame.LookVector:Dot(to.Unit) < BOT.fov and to.Magnitude > 14 then return false, nil end
	local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { b.model }
	local r = workspace:Raycast(myHead.Position, to, params)
	if r and not r.Instance:IsDescendantOf(target) then return false, nil end
	if WeaponService.smokeBlocks(myHead.Position, head.Position) then return false, nil end   -- la fumée coupe la vue (web : smokeBlocks)
	-- vise le torse la plupart du temps, la tête de temps en temps
	local torso = (target:FindFirstChild("UpperTorso") or target:FindFirstChild("HumanoidRootPart")) :: BasePart?
	local headRate = if b.diff then 0.1 + b.diff.aimHead else 0.25
	return true, if math.random() < headRate or not torso then head.Position else torso.Position
end

local function pathTo(b: Brain, goal: Vector3)
	b.goal = goal; b.waypoints = {}; b.wpIndex = 1
	b.repathAt = os.clock() + 4
	task.spawn(function()
		local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 6 })
		local ok = pcall(function() path:ComputeAsync(b.root.Position, goal) end)
		if ok and path.Status == Enum.PathStatus.Success and b.goal == goal then
			b.waypoints = path:GetWaypoints(); b.wpIndex = 2
		end
	end)
end

local function aimError(b: Brain, dir: Vector3): Vector3
	local e = math.rad(if b.diff then b.diff.spread else BOT.aimErrorDeg)
	return (CFrame.lookAlong(Vector3.zero, dir.Unit) * CFrame.Angles((math.random() - 0.5) * 2 * e, (math.random() - 0.5) * 2 * e, 0)).LookVector
end

-- Grenades et mines d'un bot, aux mêmes moments que le web (src/70_ai.js botUpdate, src/63_agents.js agentBot) et que
-- Modes/rounds (botNades) : en combat, flash entre 9 et 24 m, fumigène quand il est blessé ; hors combat, frag sur la
-- dernière position vue (moins de 4 s, entre 9 et 26 m) ; de temps en temps, une mine quand il ne se bat pas.
-- timers = { nadeT, mineT } (prochain lancer, prochain essai de mine) ; mineChance : 0,12 (modes à mort), 0,18 (bombe)
function BotService.nadeStep(bot: Model, dt: number, nadeSkill: number, mineChance: number, timers: { nadeT: number, mineT: number })
	local b = brains[bot]
	if not b or not b.alive or bot:GetAttribute("Frozen") then return end
	local stock = WeaponService.grenadesOf(bot)
	if not stock then return end
	local t = os.clock()
	local r = b.root
	local target, seen, ago = b.target, b.lastSeen, t - b.lastSeenAt
	local tr = target and target:FindFirstChild("HumanoidRootPart") :: BasePart?
	local function flat(a: Vector3, c: Vector3): number return Vector3.new(a.X - c.X, 0, a.Z - c.Z).Magnitude / Config.STUDS_PER_METER end
	if t > timers.nadeT then
		if tr then
			local dist = flat(tr.Position, r.Position)
			if stock.flash > 0 and dist > 9 and dist < 24 and math.random() < dt * 0.5 * nadeSkill then
				timers.nadeT = t + 4; WeaponService.throwGrenade(bot, "flash", false, tr.Position)
			elseif stock.smoke > 0 and b.hum.Health < 40 and dist > 6 and math.random() < dt * 1.2 * nadeSkill then
				timers.nadeT = t + 6; WeaponService.throwGrenade(bot, "smoke", false, r.Position:Lerp(tr.Position, 0.35))
			end
		elseif stock.frag > 0 and seen and ago < 4 then
			local dd = flat(seen, r.Position)
			if dd > 9 and dd < 26 and math.random() < dt * 0.8 * nadeSkill then
				timers.nadeT = t + 5; WeaponService.throwGrenade(bot, "frag", false, seen)
			end
		end
	end
	timers.mineT -= dt
	if timers.mineT <= 0 then
		timers.mineT = 1.5 + math.random() * 2
		if not target and stock.mine > 0 and math.random() < mineChance then WeaponService.placeMine(bot) end
	end
end

local function think(b: Brain)
	if not b.alive or b.model:GetAttribute("Frozen") then return end
	local t = os.clock()
	-- aveuglé par une flash (GrenadeService : attribut BlindUntil) : il perd sa cible et ralentit
	local blind = b.model:GetAttribute("BlindUntil")
	if typeof(blind) == "number" and blind > workspace:GetServerTimeNow() then
		b.target = nil
		b.hum:Move(Vector3.zero)
		return
	end
	b.team = (b.model:GetAttribute("Team") :: string?) or b.team    -- le mode peut changer l'équipe (Infecté)
	-- 1) chercher l'ennemi visible le plus proche
	local best, bestPos, bestD = nil, nil, math.huge
	for _, e in ipairs(enemiesOf(b.team, b.match)) do
		local er = e:FindFirstChild("HumanoidRootPart") :: BasePart?
		if er then
			local d = (er.Position - b.root.Position).Magnitude
			if d < bestD then
				local ok, aimAt = canSee(b, e)
				if ok then best, bestPos, bestD = e, aimAt, d end
			end
		end
	end
	if best ~= b.target then b.target = best; b.seenAt = t end
	if best then local br = best:FindFirstChild("HumanoidRootPart") :: BasePart?; if br then b.lastSeen = br.Position; b.lastSeenAt = t end end
	-- occupé par l'objectif du mode (pose / désamorçage de la bombe) : il reste sur place tant qu'aucun ennemi n'est en vue
	if not best and b.model:GetAttribute("Busy") then b.hum:Move(Vector3.zero); b.goal = nil; return end

	local key, mag = WeaponService.current(b.model)
	if key and mag <= 0 and not Config.WEAPONS[key].melee then WeaponService.reload(b.model) end

	if best and bestPos then
		-- 2) combat : se tourner, s'arrêter un peu, tirer après le temps de réaction
		local flat = Vector3.new(bestPos.X, b.root.Position.Y, bestPos.Z)
		b.root.CFrame = CFrame.lookAt(b.root.Position, flat)
		b.hum:Move(Vector3.zero)
		if t - b.seenAt >= (if b.diff then b.diff.react else BOT.reaction) and t >= b.nextBurst then
			local head = b.model:FindFirstChild("Head") :: BasePart?
			if head and key then
				local w = Config.WEAPONS[key]
				-- inclinaison du regard, pour la kill-cam (vue par les yeux du bot)
				b.model:SetAttribute("Pitch", math.asin(math.clamp((bestPos - head.Position).Unit.Y, -1, 1)))
				if w.melee and bestD > 9 then
					b.hum:MoveTo(bestPos)
				elseif WeaponService.fire(b.model, head.Position, aimError(b, bestPos - head.Position)) then
					if w.auto then
						b.burstLeft -= 1
						if b.burstLeft <= 0 then
							b.burstLeft = if b.diff then math.random(b.diff.bmin, b.diff.bmax) else math.random(BOT.burst[1], BOT.burst[2])
							b.nextBurst = t + 0.25 + math.random() * 0.3
						end
					else
						b.nextBurst = t + 60 / w.rpm + 0.1 + math.random() * 0.25
					end
				end
			end
		end
		b.goal = nil
		return
	end

	-- 3) objectif du mode (zone, drapeau, Mastodonte…) sinon patrouille : point de passage au hasard (PathfindingService)
	local want = if b.goalFn then b.goalFn(b.model) else nil
	if want and (not b.goal or (b.goal - want).Magnitude > 12) then
		pathTo(b, want)
		return
	end
	if not b.goal or t > b.repathAt + 8 then
		if #b.roam > 0 then pathTo(b, b.roam[math.random(#b.roam)]) end
		return
	end
	local wp = b.waypoints[b.wpIndex]
	if wp then
		if wp.Action == Enum.PathWaypointAction.Jump then b.hum.Jump = true end
		b.hum:MoveTo(wp.Position)
		local flatD = (Vector3.new(wp.Position.X, 0, wp.Position.Z) - Vector3.new(b.root.Position.X, 0, b.root.Position.Z)).Magnitude
		if flatD < 3 then b.wpIndex += 1 end
	elseif b.goal and (b.goal - b.root.Position).Magnitude < 8 then
		b.goal = nil
	elseif t > b.repathAt and b.goal then
		pathTo(b, b.goal)
	end
end

-- Crée un bot de l'équipe donnée à la position donnée, armé. Renvoie son Model (= le « combattant »).
function BotService.spawn(team: string, at: Vector3, roam: { Vector3 }, name: string?, opts: SpawnOpts?): Model
	local desc = Instance.new("HumanoidDescription")
	local col = TEAM_COLORS[team] or TEAM_COLORS.Attaquants
	desc.HeadColor = Color3.fromRGB(234, 184, 146); desc.LeftArmColor = desc.HeadColor; desc.RightArmColor = desc.HeadColor
	desc.TorsoColor = col.torso; desc.LeftLegColor = col.legs; desc.RightLegColor = col.legs
	local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	model.Name = name or pickName()
	model:SetAttribute("Team", team)
	model:SetAttribute("Bot", true)
	if opts and opts.match then model:SetAttribute("MatchId", opts.match) end
	if opts and opts.diff then model:SetAttribute("DmgMult", opts.diff.dmg) end
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.DisplayName = "[BOT] " .. model.Name
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	hum.NameDisplayDistance = 40
	hum.WalkSpeed = 15 * (if opts and opts.diff then opts.diff.speed else 1)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	model.Parent = getFolder()
	model:PivotTo(CFrame.new(at + Vector3.new(0, 3, 0)))
	pcall(function() root:SetNetworkOwner(nil) end)   -- physique gérée par le serveur (pas de triche possible)

	local b: Brain = {
		model = model, hum = hum, root = root, team = team, roam = roam, waypoints = {}, wpIndex = 1, goal = nil, repathAt = 0,
		target = nil, seenAt = 0, lastSeen = nil, lastSeenAt = -99, burstLeft = math.random(BOT.burst[1], BOT.burst[2]), nextBurst = 0, alive = true,
		match = opts and opts.match, diff = opts and opts.diff, goalFn = opts and opts.goal,
		nades = opts ~= nil and opts.nades == true, nadeT = 0, mineT = 1.5 + math.random() * 2,
	}
	brains[model] = b
	local secondary = if team == "Attaquants" then "glock" else "usp"
	WeaponService.giveLoadout(model, if opts and opts.loadout then opts.loadout else { BOT.primaries[math.random(#BOT.primaries)], secondary, "knife" })
	hum.Died:Connect(function() b.alive = false end)
	return model
end

function BotService.remove(model: Model)
	brains[model] = nil
	usedNames[model.Name] = nil
	WeaponService.reset(model)
	model:Destroy()
end

function BotService.removeAll()
	for m in pairs(brains) do BotService.remove(m) end
end

function BotService.list(): { Model }
	local l = {}
	for m in pairs(brains) do table.insert(l, m) end
	return l
end

-- En pause (fin de partie) : les bots ne bougent plus et ne tirent plus.
function BotService.setPaused(on: boolean)
	paused = on
	for _, b in pairs(brains) do b.hum:Move(Vector3.zero); b.hum.WalkSpeed = if on then 0 else 15 end
end

-- Bots d'une partie ; pause d'une seule partie (fin de match) ; suppression de tous ses bots
function BotService.ofMatch(id: number): { Model }
	local l = {}
	for m, b in pairs(brains) do if b.match == id then table.insert(l, m) end end
	return l
end
function BotService.freezeMatch(id: number, on: boolean)
	for m, b in pairs(brains) do
		if b.match == id then
			m:SetAttribute("Frozen", if on then true else nil)
			b.hum:Move(Vector3.zero); b.hum.WalkSpeed = if on then 0 else 15 * (if b.diff then b.diff.speed else 1) * ((b.model:GetAttribute("SpeedMult") :: number?) or 1)
		end
	end
end
function BotService.removeMatch(id: number)
	for m, b in pairs(brains) do if b.match == id then BotService.remove(m) end end
end
function BotService.setGoal(model: Model, fn: ((Model) -> Vector3?)?)
	local b = brains[model]; if b then b.goalFn = fn end
end

-- combat d'un bot (grenades des modes à manches) : ennemi visé, dernière position vue d'un ennemi et quand
function BotService.combatOf(model: Model): (Model?, Vector3?, number)
	local b = brains[model]
	if not b then return nil, nil, -99 end
	return b.target, b.lastSeen, os.clock() - b.lastSeenAt
end

function BotService.isBot(m: any): boolean
	return typeof(m) == "Instance" and brains[m] ~= nil
end

task.spawn(function()
	while true do
		task.wait(BOT.thinkRate)
		if paused then continue end
		for _, b in pairs(brains) do
			local ok, err = pcall(think, b)
			if not ok then warn("[BotService]", err) end
			if b.nades and b.alive then
				if not pcall(BotService.nadeStep, b.model, BOT.thinkRate, if b.diff and b.diff.nade then b.diff.nade else 0.6, 0.12, b :: any) then
					warn("[BotService] grenades : erreur pour", b.model.Name)
				end
			end
		end
	end
end)

return BotService
