--!strict
-- ServerScriptService/ZombieService (ModuleScript, requis par Modes/zombies)
-- Les zombies du mode Zombies (web : zSpawn / zombieUpdate de src/61_variants.js, apparence de src/49_charmodels.js) :
-- ils sortent du sol (1,1 s), foncent vers le survivant le plus proche (ligne droite s'il est en vue à moins de 9 m,
-- sinon PathfindingService), mordent quand ils sont à moins de 1,8 m (cadence propre au niveau), peuvent être gelés
-- (Souffle Givré) et repoussés (Canon Tonnerre). Types : normal, runner (coureur), tank, crawler (rôdeur), boss (la Brute).
-- Ce ne sont pas des bots : ils n'ont pas d'équipe (attribut Team absent), MatchService ne les compte donc pas au tableau.
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local U = Config.STUDS_PER_METER
local SPEED_K = 16 / 5.2          -- 1 m/s du web en studs/s (le joueur Roblox court à 16 studs/s, le web à 5,2 m/s)
local ZombieService = {}

export type SpawnOpts = {
	match: number, parent: Instance, pos: Vector3, ztype: string, hp: number, speed: number, dmg: number, atk: number,
	carrier: boolean?, id: number,
	targets: () -> { Model },                       -- personnages que les zombies peuvent viser (vivants, debout, sans protection)
	onHit: (Model, Model, number) -> (),            -- (zombie, cible, dégâts)
}
type Brain = {
	model: Model, hum: Humanoid, root: BasePart, opts: SpawnOpts, alive: boolean, riseT: number, atkT: number, frozenT: number,
	waypoints: { PathWaypoint }, wp: number, pathGoal: Vector3?, repathAt: number, pathBusy: boolean, home: Vector3,
	tracks: { [string]: AnimationTrack }, cur: string?, punchT: number,
}
local brains: { [Model]: Brain } = {}

-- animations R15 du « Zombie Animation Package » de Roblox
local ANIMS = { idle = "rbxassetid://616158929", walk = "rbxassetid://616168032", run = "rbxassetid://616163682" }

local function hsv(h: number, s: number, v: number): Color3 return Color3.fromHSV(h % 1, math.clamp(s, 0, 1), math.clamp(v, 0, 1)) end

-- apparence : peau pâle verdâtre ou violacée propre à chaque zombie, vêtements sales ; la Brute est rougeâtre
local function look(ztype: string, id: number): HumanoidDescription
	local r = Random.new(id * 7919 + 7)
	local desc = Instance.new("HumanoidDescription")
	local skin = if ztype == "boss" then Color3.fromRGB(242, 184, 178) else hsv(0.2 + r:NextNumber() * 0.16, 0.22 + r:NextNumber() * 0.2, 0.5 + r:NextNumber() * 0.18)
	desc.HeadColor = skin; desc.LeftArmColor = skin; desc.RightArmColor = skin
	local cloth = if ztype == "tank" then Color3.fromRGB(38, 44, 52) elseif ztype == "boss" then Color3.fromRGB(70, 30, 26)
		else hsv(0.05 + r:NextNumber() * 0.12, 0.2 + r:NextNumber() * 0.3, 0.2 + r:NextNumber() * 0.25)
	desc.TorsoColor = cloth
	local legs = hsv(0.6, 0.1, 0.12 + r:NextNumber() * 0.15)
	desc.LeftLegColor = legs; desc.RightLegColor = legs
	return desc
end

local function play(b: Brain, name: string, speed: number)
	if b.cur ~= name then
		local old = b.cur and b.tracks[b.cur]
		if old then old:Stop(0.25) end
		local t = b.tracks[name]
		if t then t:Play(0.25) end
		b.cur = name
	end
	local t = b.tracks[name]
	if t then t:AdjustSpeed(speed) end
end

local function headOf(m: Model): BasePart?
	return (m:FindFirstChild("Head") or m:FindFirstChild("HumanoidRootPart")) :: BasePart?
end

local function losClear(b: Brain, target: Model): boolean
	local a, t = headOf(b.model), headOf(target)
	if not a or not t then return false end
	local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { b.opts.parent }
	local r = workspace:Raycast(a.Position, t.Position - a.Position, params)
	return r == nil or r.Instance:IsDescendantOf(target)
end

local function repath(b: Brain, goal: Vector3)
	if b.pathBusy then return end
	b.pathBusy = true; b.repathAt = os.clock() + 1.2 + math.random() * 0.6
	task.spawn(function()
		local path = PathfindingService:CreatePath({ AgentRadius = 1.6, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 5 })
		local ok = pcall(function() path:ComputeAsync(b.root.Position, goal) end)
		b.pathBusy = false
		if ok and path.Status == Enum.PathStatus.Success and b.alive then
			b.waypoints = path:GetWaypoints(); b.wp = 2; b.pathGoal = goal
		end
	end)
end

-- bras qui frappent (petite rotation des épaules)
local function punch(b: Brain)
	b.punchT = 0.35
	for _, n in ipairs({ { "RightUpperArm", "RightShoulder" }, { "LeftUpperArm", "LeftShoulder" } }) do
		local arm = b.model:FindFirstChild(n[1])
		local j = arm and arm:FindFirstChild(n[2])
		if j and j:IsA("Motor6D") then
			local base = j:GetAttribute("BaseC0")
			if typeof(base) ~= "CFrame" then base = j.C0; j:SetAttribute("BaseC0", base) end
			j.C0 = (base :: CFrame) * CFrame.Angles(math.rad(70), 0, 0)
			task.delay(0.25, function() if j.Parent then j.C0 = base :: CFrame end end)
		end
	end
end

local function think(b: Brain, dt: number)
	if not b.alive then return end
	local o = b.opts
	-- sortie du sol
	if b.riseT > 0 then
		b.riseT -= dt
		local pv = b.model:GetPivot()
		b.model:PivotTo(CFrame.new(b.home - Vector3.new(0, math.max(0, b.riseT) * 1.6 * U, 0)) * (pv - pv.Position))
		if b.riseT <= 0 then
			b.root.Anchored = false
			pcall(function() b.root:SetNetworkOwner(nil) end)
		end
		return
	end
	if b.frozenT > 0 then
		b.frozenT -= dt
		b.hum:Move(Vector3.zero); b.hum.WalkSpeed = 0
		play(b, "idle", 0)
		if b.frozenT <= 0 then
			b.hum.WalkSpeed = o.speed
			local h = b.model:FindFirstChild("Frost"); if h then h:Destroy() end
		end
		return
	end
	if b.punchT > 0 then b.punchT -= dt end
	-- survivant le plus proche
	local best, bd = nil :: Model?, math.huge
	for _, t in ipairs(o.targets()) do
		local r = t:FindFirstChild("HumanoidRootPart") :: BasePart?
		if r then
			local d = (Vector3.new(r.Position.X, 0, r.Position.Z) - Vector3.new(b.root.Position.X, 0, b.root.Position.Z)).Magnitude
			if d < bd then best, bd = t, d end
		end
	end
	b.atkT -= dt
	if not best then b.hum:Move(Vector3.zero); play(b, "idle", 1); return end
	local tr = best:FindFirstChild("HumanoidRootPart") :: BasePart
	local dy = math.abs(tr.Position.Y - b.root.Position.Y)
	local scale = b.model:GetScale()
	if bd < 1.8 * U * math.max(1, scale * 0.8) and dy < 2.2 * U then
		b.hum:Move(Vector3.zero)
		b.root.CFrame = CFrame.lookAt(b.root.Position, Vector3.new(tr.Position.X, b.root.Position.Y, tr.Position.Z))
		play(b, "idle", 1)
		if b.atkT <= 0 then
			b.atkT = o.atk
			punch(b)
			o.onHit(b.model, best, o.dmg)
		end
		return
	end
	local run = o.ztype == "runner" or o.speed > 3.8 * SPEED_K
	play(b, if run then "run" else "walk", math.clamp(o.speed / (if run then 18 else 8), 0.6, 1.6))
	if bd < 9 * U and dy < 1.2 * U and losClear(b, best) then
		b.hum:MoveTo(tr.Position)
		b.waypoints = {}
		return
	end
	if #b.waypoints == 0 or os.clock() > b.repathAt or (b.pathGoal and (b.pathGoal - tr.Position).Magnitude > 4 * U) then
		repath(b, tr.Position)
	end
	local wp = b.waypoints[b.wp]
	if wp then
		if wp.Action == Enum.PathWaypointAction.Jump then b.hum.Jump = true end
		b.hum:MoveTo(wp.Position)
		local flat = (Vector3.new(wp.Position.X, 0, wp.Position.Z) - Vector3.new(b.root.Position.X, 0, b.root.Position.Z)).Magnitude
		if flat < 2.5 then b.wp += 1 end
	else
		b.hum:MoveTo(tr.Position)
	end
end

function ZombieService.metersToSpeed(ms: number): number return ms * SPEED_K end

function ZombieService.spawn(o: SpawnOpts): Model
	local model = Players:CreateHumanoidModelFromDescription(look(o.ztype, o.id), Enum.HumanoidRigType.R15)
	model.Name = "Zombie_" .. o.id
	model:SetAttribute("MatchId", o.match)
	model:SetAttribute("Zombie", true)
	model:SetAttribute("ZType", o.ztype)
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.MaxHealth = o.hp; hum.Health = o.hp
	hum.WalkSpeed = o.speed
	hum.AutoJumpEnabled = true
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local scale = if o.ztype == "boss" then 1.8 elseif o.ztype == "tank" then 1.3 elseif o.ztype == "runner" then 0.92 elseif o.ztype == "crawler" then 0.95 else 0.93 + (o.id * 0.137 % 1) * 0.14
	pcall(function() model:ScaleTo(scale) end)
	-- rôdeur : à quatre pattes (corps basculé vers l'avant, plus bas)
	if o.ztype == "crawler" then
		local lt = model:FindFirstChild("LowerTorso")
		local j = lt and lt:FindFirstChild("Root")
		if j and j:IsA("Motor6D") then j.C0 = j.C0 * CFrame.new(0, -1.2, 0) * CFrame.Angles(math.rad(-70), 0, 0) end
		hum.HipHeight = math.max(0.4, hum.HipHeight * 0.4)
	end
	if o.ztype == "boss" then
		local hl = Instance.new("Highlight"); hl.Name = "BossGlow"; hl.FillColor = Color3.fromRGB(255, 60, 40); hl.FillTransparency = 0.8
		hl.OutlineColor = Color3.fromRGB(255, 80, 60); hl.DepthMode = Enum.HighlightDepthMode.Occluded; hl.Parent = model
	end
	if o.carrier then
		local hl = Instance.new("Highlight"); hl.Name = "AmmoGlow"; hl.FillColor = Color3.fromRGB(255, 210, 58); hl.FillTransparency = 0.55
		hl.OutlineColor = Color3.fromRGB(255, 225, 120); hl.DepthMode = Enum.HighlightDepthMode.Occluded; hl.Parent = model
		local head = model:FindFirstChild("Head")
		if head then local l = Instance.new("PointLight"); l.Name = "AmmoLight"; l.Color = Color3.fromRGB(255, 210, 58); l.Range = 10; l.Brightness = 2; l.Parent = head end
		model:SetAttribute("AmmoCarrier", true)
	end
	root.Anchored = true
	local home = o.pos + Vector3.new(0, hum.HipHeight + root.Size.Y / 2, 0)
	model:PivotTo(CFrame.new(home - Vector3.new(0, 1.1 * 1.6 * U, 0)) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
	model.Parent = o.parent
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = hum
	local tracks = {}
	for k, id in pairs(ANIMS) do
		local a = Instance.new("Animation"); a.AnimationId = id
		local ok, t = pcall(function() return animator:LoadAnimation(a) end)
		if ok and t then t.Looped = true; tracks[k] = t end
	end
	local b: Brain = { model = model, hum = hum, root = root, opts = o, alive = true, riseT = 1.1, atkT = 0, frozenT = 0,
		waypoints = {}, wp = 1, pathGoal = nil, repathAt = 0, pathBusy = false, home = home, tracks = tracks, cur = nil, punchT = 0 }
	brains[model] = b
	play(b, "idle", 1)
	hum.Died:Connect(function()
		b.alive = false
		for _, t in pairs(b.tracks) do t:Stop(0.1) end
		root.Anchored = false
		for _, n in ipairs({ "AmmoGlow", "AmmoLight", "Frost" }) do local x = model:FindFirstChild(n, true); if x then x:Destroy() end end
	end)
	return model
end

function ZombieService.isZombie(m: any): boolean
	return typeof(m) == "Instance" and brains[m :: any] ~= nil
end
function ZombieService.alive(m: Model): boolean
	local b = brains[m]; return b ~= nil and b.alive
end
function ZombieService.ofMatch(id: number): { Model }
	local l = {}
	for m, b in pairs(brains) do if b.alive and b.opts.match == id then table.insert(l, m) end end
	return l
end
-- tous les zombies vivants (grenades et mines : WeaponService.extraVictims)
function ZombieService.all(): { Model }
	local l = {}
	for m, b in pairs(brains) do if b.alive then table.insert(l, m) end end
	return l
end
function ZombieService.typeOf(m: Model): string?
	local b = brains[m]; return b and b.opts.ztype
end
-- gel (Souffle Givré) : immobile, halo bleu
function ZombieService.freeze(m: Model, t: number)
	local b = brains[m]
	if not b or not b.alive then return end
	b.frozenT = math.max(b.frozenT, t)
	if not m:FindFirstChild("Frost") then
		local hl = Instance.new("Highlight"); hl.Name = "Frost"; hl.FillColor = Color3.fromRGB(150, 220, 255); hl.FillTransparency = 0.35
		hl.OutlineColor = Color3.fromRGB(200, 240, 255); hl.Parent = m
	end
end
function ZombieService.frozen(m: Model): number
	local b = brains[m]; return b and b.frozenT or 0
end
-- repousse (Canon Tonnerre, Second Souffle)
function ZombieService.push(m: Model, dir: Vector3, studs: number)
	local b = brains[m]
	if not b or not b.alive or b.riseT > 0 then return end
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 1e-3 then return end
	local to = b.root.Position + flat.Unit * studs
	local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances = { b.opts.parent }
	if workspace:Raycast(b.root.Position, to - b.root.Position, params) then return end
	b.model:PivotTo(b.model:GetPivot() + (to - b.root.Position))
end
function ZombieService.remove(m: Model)
	brains[m] = nil
	if m.Parent then m:Destroy() end
end
function ZombieService.removeMatch(id: number)
	for m, b in pairs(brains) do if b.opts.match == id then ZombieService.remove(m) end end
end

task.spawn(function()
	local last = os.clock()
	while true do
		task.wait(0.1)
		local now = os.clock()
		local dt = now - last; last = now
		for m, b in pairs(brains) do
			if not m.Parent then brains[m] = nil
			elseif b.alive and not m:GetAttribute("Frozen") then
				local ok, err = pcall(function() think(b, dt) end)
				if not ok then warn("[ZombieService]", err) end
			end
		end
	end
end)

do
	local WS = require(script.Parent.WeaponService) :: any
	WS.extraVictims = ZombieService.all
end
return ZombieService
