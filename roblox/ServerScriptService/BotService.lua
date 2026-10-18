--!strict
-- ServerScriptService/BotService (ModuleScript, requis par TDMService)
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
	target: Model?, seenAt: number, burstLeft: number, nextBurst: number, alive: boolean,
}
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
local function enemiesOf(team: string): { Model }
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if c and h and h.Health > 0 and p.Team and p.Team.Name ~= team then table.insert(list, c) end
	end
	for m, b in pairs(brains) do
		if b.alive and b.team ~= team then table.insert(list, m) end
	end
	return list
end

local function canSee(b: Brain, target: Model): (boolean, Vector3?)
	local head = target:FindFirstChild("Head") :: BasePart?
	local myHead = b.model:FindFirstChild("Head") :: BasePart?
	if not head or not myHead then return false, nil end
	local to = head.Position - myHead.Position
	if to.Magnitude > BOT.viewDistance then return false, nil end
	if b.root.CFrame.LookVector:Dot(to.Unit) < BOT.fov and to.Magnitude > 14 then return false, nil end
	local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { b.model }
	local r = workspace:Raycast(myHead.Position, to, params)
	if r and not r.Instance:IsDescendantOf(target) then return false, nil end
	-- vise le torse la plupart du temps, la tête de temps en temps
	local torso = (target:FindFirstChild("UpperTorso") or target:FindFirstChild("HumanoidRootPart")) :: BasePart?
	return true, if math.random() < 0.25 or not torso then head.Position else torso.Position
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

local function aimError(dir: Vector3): Vector3
	local e = math.rad(BOT.aimErrorDeg)
	return (CFrame.lookAlong(Vector3.zero, dir.Unit) * CFrame.Angles((math.random() - 0.5) * 2 * e, (math.random() - 0.5) * 2 * e, 0)).LookVector
end

local function think(b: Brain)
	if not b.alive then return end
	local t = os.clock()
	-- 1) chercher l'ennemi visible le plus proche
	local best, bestPos, bestD = nil, nil, math.huge
	for _, e in ipairs(enemiesOf(b.team)) do
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

	local key, mag = WeaponService.current(b.model)
	if key and mag <= 0 and not Config.WEAPONS[key].melee then WeaponService.reload(b.model) end

	if best and bestPos then
		-- 2) combat : se tourner, s'arrêter un peu, tirer après le temps de réaction
		local flat = Vector3.new(bestPos.X, b.root.Position.Y, bestPos.Z)
		b.root.CFrame = CFrame.lookAt(b.root.Position, flat)
		b.hum:Move(Vector3.zero)
		if t - b.seenAt >= BOT.reaction and t >= b.nextBurst then
			local head = b.model:FindFirstChild("Head") :: BasePart?
			if head and key then
				local w = Config.WEAPONS[key]
				-- inclinaison du regard, pour la kill-cam (vue par les yeux du bot)
				b.model:SetAttribute("Pitch", math.asin(math.clamp((bestPos - head.Position).Unit.Y, -1, 1)))
				if w.melee and bestD > 9 then
					b.hum:MoveTo(bestPos)
				elseif WeaponService.fire(b.model, head.Position, aimError(bestPos - head.Position)) then
					if w.auto then
						b.burstLeft -= 1
						if b.burstLeft <= 0 then
							b.burstLeft = math.random(BOT.burst[1], BOT.burst[2])
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

	-- 3) patrouille : point de passage au hasard, chemin calculé par PathfindingService
	if not b.goal or t > b.repathAt + 8 then
		pathTo(b, b.roam[math.random(#b.roam)])
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
function BotService.spawn(team: string, at: Vector3, roam: { Vector3 }, name: string?): Model
	local desc = Instance.new("HumanoidDescription")
	local col = TEAM_COLORS[team] or TEAM_COLORS.Attaquants
	desc.HeadColor = Color3.fromRGB(234, 184, 146); desc.LeftArmColor = desc.HeadColor; desc.RightArmColor = desc.HeadColor
	desc.TorsoColor = col.torso; desc.LeftLegColor = col.legs; desc.RightLegColor = col.legs
	local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	model.Name = name or pickName()
	model:SetAttribute("Team", team)
	model:SetAttribute("Bot", true)
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.DisplayName = "[BOT] " .. model.Name
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	hum.NameDisplayDistance = 40
	hum.WalkSpeed = 15
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	model.Parent = getFolder()
	model:PivotTo(CFrame.new(at + Vector3.new(0, 3, 0)))
	pcall(function() root:SetNetworkOwner(nil) end)   -- physique gérée par le serveur (pas de triche possible)

	local b: Brain = {
		model = model, hum = hum, root = root, team = team, roam = roam, waypoints = {}, wpIndex = 1, goal = nil, repathAt = 0,
		target = nil, seenAt = 0, burstLeft = math.random(BOT.burst[1], BOT.burst[2]), nextBurst = 0, alive = true,
	}
	brains[model] = b
	local secondary = if team == "Attaquants" then "glock" else "usp"
	WeaponService.giveLoadout(model, { BOT.primaries[math.random(#BOT.primaries)], secondary, "knife" })
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
		end
	end
end)

return BotService
