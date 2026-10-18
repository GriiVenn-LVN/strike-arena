--!strict
-- ServerScriptService/HalloweenService (ModuleScript, requis par Main)
-- Événement d'Halloween hors Manoir hanté (src/8W_halloween.js), seulement pendant l'événement (ProgressService.eventActive) :
--   • décor des autres cartes (hwEventDeco) : citrouilles sculptées sur le haut des murs qui bordent une zone ouverte
--     (16, les 4 premières éclairées), petits groupes au pied des murs / caisses / maisons (14), une à chaque point de
--     départ, nuée de chauves-souris au centre (animée par HalloweenController) ;
--   • un adversaire éliminé par un joueur lâche parfois une citrouille à ramasser (25 %, 12 au plus par partie, pas à
--     l'entraînement) ;
--   • lobby : éclairage de nuit violet / orangé, brouillard, citrouilles et chauves-souris (thème « theme-hw » du menu web).
--     Attribut Workspace « EventTheme » = "hw" pour les écrans du menu.
-- Le décor est fait de Parts sans collision ni requête : il ne gêne ni les tirs ni les déplacements.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MapData = require(ReplicatedStorage.Shared.MapData)
local CommunityConfig = require(ReplicatedStorage.Shared.CommunityConfig)
local X = require(ReplicatedStorage.Shared.ConfigExtra)
local ProgressService = require(script.Parent.ProgressService)
local MatchService = require(script.Parent.MatchService)
local WeaponService = require(script.Parent.WeaponService)

local HalloweenService = {}

local U = Config.STUDS_PER_METER
local CELL = Config.CELL * U
local ORANGE = Color3.fromRGB(232, 112, 26)
local ORANGE2 = Color3.fromRGB(214, 98, 20)
local GLOW = Color3.fromRGB(255, 208, 96)

local function deco(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance, mat: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Material = mat or Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Parent = parent
	return p
end

-- citrouille sculptée décorative (jackO du web) : s = taille en mètres, posée au sol en pos, tournée de ry
function HalloweenService.jackO(pos: Vector3, s: number, ry: number, light: number, parent: Instance): Model
	local m = Instance.new("Model"); m.Name = "HwPumpkin"
	local d = s * U
	local c = CFrame.new(pos + Vector3.new(0, d * 0.4, 0)) * CFrame.Angles(0, ry, 0)
	deco("Body", Vector3.new(d, d * 0.8, d), c, ORANGE, m, nil, Enum.PartType.Ball)
	for i = 0, 5 do
		deco("Rib", Vector3.new(d * 0.4, d * 0.78, d * 1.02), c * CFrame.Angles(0, i / 6 * math.pi, 0), ORANGE2, m, nil, Enum.PartType.Ball)
	end
	deco("Stem", Vector3.new(d * 0.12, d * 0.24, d * 0.12), c * CFrame.new(0, d * 0.46, 0) * CFrame.Angles(0, 0, 0.25), Color3.fromRGB(74, 90, 34), m)
	for _, sx in ipairs({ -0.18, 0.18 }) do
		deco("Eye", Vector3.new(d * 0.15, d * 0.15, d * 0.05), c * CFrame.new(d * sx, d * 0.09, -d * 0.49) * CFrame.Angles(0, 0, math.rad(45)), GLOW, m, Enum.Material.Neon)
	end
	deco("Mouth", Vector3.new(d * 0.42, d * 0.08, d * 0.05), c * CFrame.new(0, -d * 0.13, -d * 0.48), GLOW, m, Enum.Material.Neon)
	local body = m:FindFirstChild("Body") :: BasePart
	m.PrimaryPart = body
	if light > 0 then
		local l = Instance.new("PointLight"); l.Color = Color3.fromRGB(255, 138, 48); l.Brightness = light * 0.6; l.Range = (10 + s * 6) * 0.9; l.Shadows = false
		l.Parent = body
		CollectionService:AddTag(l, "HwFlicker")   -- vacille côté client (HalloweenController)
	end
	m.Parent = parent
	return m
end

-- nuée de chauves-souris (hwBats) : un repère que HalloweenController anime
function HalloweenService.bats(center: Vector3, n: number, radius: number, parent: Instance): Part
	local p = deco("HwBats", Vector3.new(1, 1, 1), CFrame.new(center), Color3.new(), parent)
	p.Transparency = 1
	p:SetAttribute("N", n); p:SetAttribute("Radius", radius)
	CollectionService:AddTag(p, "HwBats")
	return p
end

local function shuffle<T>(t: { T }, rng: Random)
	for i = #t, 2, -1 do local j = rng:NextInteger(1, i); t[i], t[j] = t[j], t[i] end
end

-- ---------- décor d'une carte (hwEventDeco) ----------
function HalloweenService.decorate(m: any)
	if not ProgressService.eventActive() then return end
	if m.settings.map == "manoir" or not m.map or not m.map.grid then return end
	local g = m.map.grid
	local N = MapData.N
	local TY = MapData.TY
	local o: Vector3 = m.map.origin
	local folder = Instance.new("Folder"); folder.Name = "Halloween"; folder.Parent = m.map.folder
	local rng = Random.new()
	local function cellPos(cx: number, cz: number, h: number): Vector3
		return o + Vector3.new((cx + 0.5) * CELL, h * U, (cz + 0.5) * CELL)
	end
	-- haut des murs qui bordent une zone ouverte
	local cand: { { number } } = {}
	for cz = 1, N - 2 do
		for cx = 1, N - 2 do
			local i = cz * N + cx
			if g.type[i] == TY.WALL and g.h[i] <= 7 then
				local open = false
				for _, dd in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
					local j = (cz + dd[2]) * N + cx + dd[1]
					if g.type[j] == 0 and (g.ceil[j] or 99) > 90 then open = true; break end
				end
				if open then table.insert(cand, { cx, cz }) end
			end
		end
	end
	shuffle(cand, rng)
	local used: { { number } } = {}
	for _, c in ipairs(cand) do
		if #used >= 16 then break end
		local near = false
		for _, u in ipairs(used) do if math.abs(u[1] - c[1]) + math.abs(u[2] - c[2]) < 5 then near = true; break end end
		if not near then
			table.insert(used, c)
			HalloweenService.jackO(cellPos(c[1], c[2], g.h[c[2] * N + c[1]]), 0.95, rng:NextNumber() * math.pi * 2, if #used <= 4 then 2.5 else 0, folder)
		end
	end
	-- groupes au pied des murs, caisses et maisons (collés à l'obstacle)
	local foot: { { number } } = {}
	for cz = 1, N - 2 do
		for cx = 1, N - 2 do
			local i = cz * N + cx
			if g.type[i] == 0 and (g.ramp[i] or 0) == 0 then
				for _, dd in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
					local t = g.type[(cz + dd[2]) * N + cx + dd[1]]
					if t == TY.WALL or t == TY.CRATE or t == TY.HOUSE then table.insert(foot, { cx, cz, dd[1], dd[2] }); break end
				end
			end
		end
	end
	shuffle(foot, rng)
	local fu: { { number } } = {}
	for _, f in ipairs(foot) do
		if #fu >= 14 then break end
		local near = false
		for _, u in ipairs(fu) do if math.abs(u[1] - f[1]) + math.abs(u[2] - f[2]) < 6 then near = true; break end end
		if not near then
			table.insert(fu, f)
			local dx, dz = f[3], f[4]
			local base = cellPos(f[1], f[2], 0) + Vector3.new(dx * 0.62 * U, 0, dz * 0.62 * U)
			local y = m.map.groundAt(base)
			HalloweenService.jackO(Vector3.new(base.X, y, base.Z), 0.75, math.atan2(-dx, -dz) + math.pi, 0, folder)
			local b2 = base + Vector3.new(-dz * 0.6 * U + rng:NextNumber(-0.1, 0.1) * U, 0, dx * 0.6 * U)
			HalloweenService.jackO(Vector3.new(b2.X, m.map.groundAt(b2), b2.Z), 0.45, rng:NextNumber() * math.pi * 2, 0, folder)
		end
	end
	-- petites citrouilles au pied des points de départ
	for _, s in ipairs({ (m.map.data.spawnCT or {})[1], (m.map.data.spawnT or {})[1] }) do
		if s then
			local p = cellPos(s[1], s[2], 0) + Vector3.new(1.2 * U, 0, 0.6 * U)
			HalloweenService.jackO(Vector3.new(p.X, m.map.groundAt(p), p.Z), 0.7, rng:NextNumber() * math.pi * 2, 2, folder)
		end
	end
	local half = N * CELL / 2
	HalloweenService.bats(o + Vector3.new(half, 16 * U, half), 14, 20 * U, folder)
end
table.insert(MatchService.buildHooks, HalloweenService.decorate)

-- ---------- citrouille lâchée par un adversaire éliminé ----------
WeaponService.Killed:Connect(function(killer: any, victim: any)
	if not ProgressService.eventActive() then return end
	if typeof(killer) ~= "Instance" or not killer:IsA("Player") or killer == victim then return end
	local m = MatchService.matchOf(killer)
	if not m or m.mode == "train" or not m.map or MatchService.matchOf(victim) ~= m then return end
	if math.random() >= (X.EVENT.killDropChance or 0.25) then return end
	local count = 0
	for _, d in ipairs(m.map.folder:GetDescendants()) do if d.Name == "Pumpkin" and d:IsA("BasePart") then count += 1 end end
	if count >= (X.EVENT.killDropMax or 12) then return end
	local ch = WeaponService.charOf(victim)
	local root = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end
	local pos = root.Position
	ProgressService.pumpkinAt(Vector3.new(pos.X, m.map.groundAt(pos), pos.Z), m.map.folder)
end)

-- ---------- lobby ----------
local function themeLobby()
	if not ProgressService.eventActive() then return end
	workspace:SetAttribute("EventTheme", "hw")
	-- ambiance de nuit d'Halloween (MapDetailController la garde comme éclairage du lobby)
	Lighting.ClockTime = 20.6
	Lighting.Brightness = 1.4
	Lighting.Ambient = Color3.fromRGB(72, 48, 96)
	Lighting.OutdoorAmbient = Color3.fromRGB(96, 64, 128)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 140, 60)
	Lighting.FogColor = Color3.fromRGB(46, 24, 66)
	Lighting.FogStart = 60
	Lighting.FogEnd = 900
	-- citrouilles et chauves-souris autour du lobby
	local L = CommunityConfig.LOBBY
	local o = L.origin
	local half = L.size / 2
	local folder = Instance.new("Folder"); folder.Name = "HalloweenLobby"; folder.Parent = workspace
	local rng = Random.new(31)
	for i = 0, 11 do   -- au pied des murs, entre les attractions
		local side = i % 4
		local t = (math.floor(i / 4) - 1) * 0.55 * half + rng:NextNumber(-8, 8)
		local inset = half - 5
		local p = if side == 0 then Vector3.new(t, 0, inset) elseif side == 1 then Vector3.new(t, 0, -inset)
			elseif side == 2 then Vector3.new(inset, 0, t) else Vector3.new(-inset, 0, t)
		HalloweenService.jackO(o + p, 1.1, rng:NextNumber() * math.pi * 2, if i < 4 then 2.5 else 0, folder)
		HalloweenService.jackO(o + p + Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4)), 0.55, rng:NextNumber() * math.pi * 2, 0, folder)
	end
	for _, c in ipairs({ { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } }) do   -- sur les coins des murs
		HalloweenService.jackO(o + Vector3.new(c[1] * (half - 1), 34, c[2] * (half - 1)), 1.4, rng:NextNumber() * math.pi * 2, 3, folder)
	end
	for _, c in ipairs({ { 0.7, 0.7 }, { -0.7, -0.6 }, { 0.6, -0.7 } }) do   -- autour de l'aire d'apparition
		HalloweenService.jackO(o + Vector3.new(c[1] * 20, 0, c[2] * 20), 0.8, rng:NextNumber() * math.pi * 2, 1.5, folder)
	end
	HalloweenService.bats(o + Vector3.new(0, 30, 0), 18, 60, folder)
end
themeLobby()

return HalloweenService
