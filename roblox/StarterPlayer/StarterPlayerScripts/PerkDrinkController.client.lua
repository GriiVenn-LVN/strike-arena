--!strict
-- StarterPlayerScripts/PerkDrinkController (LocalScript)
-- Animation de la boisson d'atout (src/8U_perkdrink.js), lancée par PerkDrinkService (remote PerkDrink) :
--   • vue subjective (soi) : l'arme descend et disparaît (0 – 0,3 s), le flacon de la couleur de l'atout sort par le bas
--     (0,28 s), petite gorgée d'essai, la capsule saute (0,7 s), on porte le flacon à la bouche et on boit (le liquide
--     baisse de 1,02 à 1,6 s, glouglous), « ahh » + lueur de la couleur de l'atout sur les bords de l'écran (1,6 s),
--     le flacon est jeté (1,84 s) et l'arme revient (1,85 s). Ni tir ni visée pendant 2,3 s (ClientState.drinkUntil).
--   • vu par les autres : le flacon dans la main, porté à la bouche et incliné, le liquide qui baisse.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local S = require(ReplicatedStorage.Shared.ClientState)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local okZ, Z = pcall(require, ReplicatedStorage.Shared:WaitForChild("ZombieConfig", 5) :: ModuleScript)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local U = Config.STUDS_PER_METER
local GOLDM = Color3.fromRGB(216, 178, 90)

local function perkOf(key: string): (Color3, string, string)
	local p = okZ and Z and (Z :: any).PERKS and (Z :: any).PERKS[key]
	if p then return p.c, p.ic or "?", p.n or key end
	return Color3.new(1, 1, 1), "?", key
end

local function snd(id: string, pitch: number, vol: number, at: Vector3?)
	pcall(function() Sfx.play({ id = id, volume = vol, pitch = pitch }, at) end)
end

-- ---------- flacon ----------
type Bottle = { folder: Model, parts: { { p: BasePart, off: CFrame } }, liq: BasePart, cap: BasePart, scale: number, liqH: number }
local function newPart(parent: Instance, size: Vector3, color: Color3, mat: Enum.Material?, shape: Enum.PartType?, transp: number?): BasePart
	local p = Instance.new("Part")
	p.Size = size; p.Color = color; p.Material = mat or Enum.Material.SmoothPlastic; p.Transparency = transp or 0
	if shape then p.Shape = shape end
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Parent = parent
	return p
end
-- s = taille en mètres du flacon (0,2 m sur le web) ; origine = fond du flacon, axe Y = goulot
local function bottle(key: string, sc: number, parent: Instance): Bottle
	local col, ic = perkOf(key)
	local m = Instance.new("Model"); m.Name = "PerkBottle"
	local k = sc * U
	local cyl = CFrame.Angles(0, 0, math.pi / 2)   -- un cylindre Roblox est couché sur X : on le redresse
	local parts = {}
	local function add(p: BasePart, off: CFrame) table.insert(parts, { p = p, off = off }) end
	local glass = col:Lerp(Color3.new(1, 1, 1), 0.25)
	add(newPart(m, Vector3.new(0.118 * k, 0.072 * k, 0.072 * k), glass, Enum.Material.Glass, Enum.PartType.Cylinder, 0.55), CFrame.new(0, 0.059 * k, 0) * cyl)
	add(newPart(m, Vector3.new(0.03 * k, 0.06 * k, 0.06 * k), glass, Enum.Material.Glass, Enum.PartType.Cylinder, 0.55), CFrame.new(0, 0.128 * k, 0) * cyl)
	add(newPart(m, Vector3.new(0.045 * k, 0.024 * k, 0.024 * k), glass, Enum.Material.Glass, Enum.PartType.Cylinder, 0.5), CFrame.new(0, 0.165 * k, 0) * cyl)
	local label = newPart(m, Vector3.new(0.06 * k, 0.0745 * k, 0.0745 * k), Color3.fromRGB(22, 17, 12), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	add(label, CFrame.new(0, 0.06 * k, 0) * cyl)
	local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Front; sg.CanvasSize = Vector2.new(64, 64); sg.LightInfluence = 0.5; sg.Parent = label
	local t = Instance.new("TextLabel"); t.Size = UDim2.fromScale(1, 1); t.BackgroundColor3 = col; t.BackgroundTransparency = 0.2; t.Text = ic
	t.TextScaled = true; t.Font = Enum.Font.GothamBlack; t.TextColor3 = Color3.new(1, 1, 1); t.Parent = sg
	add(newPart(m, Vector3.new(0.004 * k, 0.025 * k, 0.025 * k), GOLDM, Enum.Material.Metal, Enum.PartType.Cylinder), CFrame.new(0, 0.188 * k, 0) * cyl)
	local cap = newPart(m, Vector3.new(0.012 * k, 0.029 * k, 0.029 * k), GOLDM, Enum.Material.Metal, Enum.PartType.Cylinder)
	add(cap, CFrame.new(0, 0.204 * k, 0) * cyl)
	local liq = newPart(m, Vector3.new(0.096 * k, 0.064 * k, 0.064 * k), col, Enum.Material.Neon, Enum.PartType.Cylinder, 0.1)
	add(liq, CFrame.new(0, 0.052 * k, 0) * cyl)
	m.Parent = parent
	return { folder = m, parts = parts, liq = liq, cap = cap, scale = k, liqH = 0.096 * k }
end
local function place(b: Bottle, base: CFrame, level: number)
	for _, e in ipairs(b.parts) do
		if e.p == b.liq then
			local h = math.max(0.002 * b.scale, b.liqH * level)
			e.p.Size = Vector3.new(h, e.p.Size.Y, e.p.Size.Z)
			e.p.CFrame = base * CFrame.new(0, 0.004 * b.scale + h / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
			e.p.Transparency = if level < 0.02 then 1 else 0.1
		else
			e.p.CFrame = base * e.off
		end
	end
end

local function smooth(x: number): number x = math.clamp(x, 0, 1); return x * x * (3 - 2 * x) end
local function lerp(a: number, b: number, t: number): number return a + (b - a) * t end

-- ---------- lueur sur les bords de l'écran ----------
local gui = Instance.new("ScreenGui"); gui.Name = "PerkDrink"; gui.IgnoreGuiInset = true; gui.ResetOnSpawn = false; gui.DisplayOrder = 7
gui.Parent = player:WaitForChild("PlayerGui")
local glow = Instance.new("Frame"); glow.Size = UDim2.fromScale(1, 1); glow.BackgroundTransparency = 1; glow.BorderSizePixel = 0; glow.Parent = gui
local stroke = Instance.new("UIStroke"); stroke.Thickness = 90; stroke.Transparency = 1; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; stroke.Parent = glow
local function screenGlow(col: Color3)
	stroke.Color = col; stroke.Transparency = 0.25
	TweenService:Create(stroke, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1 }):Play()
end

-- ---------- vue subjective ----------
type Fly = { p: Bottle | BasePart, cf: CFrame, v: Vector3, spin: Vector3, t: number, life: number }
local me: { on: boolean, t0: number, key: string, b: Bottle?, capOff: boolean, glug: number, ahh: boolean, tossed: boolean }? = nil
local flying: { Fly } = {}

local function pose(t: number): (Vector3, number, number)
	local a = smooth((t - 0.28) / 0.3)    -- sort par le bas
	local b = smooth((t - 0.78) / 0.3)    -- monte à la bouche
	local d = smooth((t - 1.62) / 0.22)   -- redescend pour être jeté
	local x, y, z = lerp(0.24, 0.1, a), lerp(-0.52, -0.2, a), lerp(-0.42, -0.47, a)
	local rx, rz = lerp(-0.4, 0.18, a), lerp(0.5, 0.22, a)
	x = lerp(x, 0.055, b); y = lerp(y, 0.012, b); z = lerp(z, -0.25, b)
	rx = lerp(rx, 1.95, b); rz = lerp(rz, 0.1, b)
	if t > 0.6 and t < 0.74 then local j = math.sin((t - 0.6) / 0.14 * math.pi); rx -= j * 0.25; y += j * 0.012 end
	if b > 0.9 and d < 0.05 then local g = math.sin((t - 1.08) * 14); y += g * 0.004; rx += g * 0.04 end
	x = lerp(x, 0.34, d); y = lerp(y, -0.32, d); z = lerp(z, -0.42, d); rx = lerp(rx, 0.6, d); rz = lerp(rz, -0.9, d)
	return Vector3.new(x, y, z) * U, rx, rz
end

local function stopMine()
	if me and me.b and not me.tossed then me.b.folder:Destroy() end
	me = nil
end

local function startMine(key: string, dur: number)
	stopMine()
	local now = os.clock()
	S.drinkUntil = now + dur; S.drinkHideUntil = now + 1.85
	S.aiming = false; S.inspectStart = -1
	me = { on = true, t0 = now, key = key, b = nil, capOff = false, glug = 0, ahh = false, tossed = false }
	snd("rbxasset://sounds/swoosh.wav", 1.3, 0.35)
end

RunService:BindToRenderStep("PerkDrink", Enum.RenderPriority.Camera.Value + 3, function(dt: number)
	-- objets lancés (capsule, flacon) : dans le repère de la caméra
	for i = #flying, 1, -1 do
		local f = flying[i]
		f.t += dt
		f.v += Vector3.new(0, -3.2 * U * dt, 0)
		f.cf = (f.cf + f.v * dt) * CFrame.Angles(f.spin.X * dt, f.spin.Y * dt, f.spin.Z * dt)
		local world = camera.CFrame * f.cf
		if typeof(f.p) == "Instance" then (f.p :: BasePart).CFrame = world else place(f.p :: Bottle, world, 0) end
		if f.t > f.life then
			if typeof(f.p) == "Instance" then (f.p :: BasePart):Destroy() else (f.p :: Bottle).folder:Destroy() end
			table.remove(flying, i)
		end
	end
	local d = me
	if not d then return end
	local ch = player.Character
	local h = ch and ch:FindFirstChildOfClass("Humanoid")
	if not h or h.Health <= 0 or player:GetAttribute("Zone") ~= "match" then S.drinkUntil = 0; S.drinkHideUntil = 0; stopMine(); return end
	local t = os.clock() - d.t0
	if t >= 2.3 then stopMine(); return end
	if t < 0.28 or d.tossed then return end
	if not d.b then d.b = bottle(d.key, 0.88, camera) end
	local b = d.b :: Bottle
	local pos, rx, rz = pose(t)
	local local_ = CFrame.new(pos) * CFrame.fromEulerAnglesXYZ(rx, 0, rz)
	local level = 1 - math.clamp((t - 1.02) / 0.58, 0, 1)
	place(b, camera.CFrame * local_, level)
	b.cap.Transparency = if d.capOff then 1 else 0
	if not d.capOff and t >= 0.7 then
		d.capOff = true
		snd("rbxasset://sounds/clickfast.wav", 2.2, 0.6)
		local c = newPart(camera, b.cap.Size, GOLDM, Enum.Material.Metal, Enum.PartType.Cylinder)
		table.insert(flying, { p = c, cf = local_ * CFrame.new(0, 0.205 * b.scale, 0), v = Vector3.new(-0.35, 0.9, -0.1) * U, spin = Vector3.new(18, 9, 4), t = 0, life = 0.8 })
	end
	if t > 1.05 and t < 1.6 then
		d.glug -= dt
		if d.glug <= 0 then d.glug = 0.17; snd("rbxasset://sounds/swoosh.wav", 0.35 + math.random() * 0.08, 0.3) end
	end
	if t >= 1.6 and not d.ahh then
		d.ahh = true
		local col = perkOf(d.key)
		screenGlow(col)
		snd("rbxasset://sounds/electronicpingshort.wav", 0.6, 0.4)
	end
	if t >= 1.84 and not d.tossed then
		d.tossed = true
		snd("rbxasset://sounds/swoosh.wav", 1.6, 0.3)
		task.delay(0.42, function() snd("rbxasset://sounds/clickfast.wav", 3, 0.35) end)
		table.insert(flying, { p = b, cf = local_, v = Vector3.new(0.9, 0.6, -0.4) * U, spin = Vector3.new(9, 3, 11), t = 0, life = 0.7 })
	end
end)

-- ---------- vu par les autres ----------
type Other = { p: Player, b: Bottle?, t0: number, dur: number, key: string }
local others: { [Player]: Other } = {}
RunService.RenderStepped:Connect(function()
	for p, o in pairs(others) do
		local ch = p.Character
		local head = ch and ch:FindFirstChild("Head") :: BasePart?
		local root = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
		local t = os.clock() - o.t0
		if not head or not root or t >= o.dur * 0.8 then
			if o.b then o.b.folder:Destroy() end
			others[p] = nil
		else
			if not o.b then o.b = bottle(o.key, 1.3, workspace) end
			local k = smooth(math.min(1, t / 0.6)) * (1 - smooth((t - o.dur * 0.8 + 0.3) / 0.3))
			local rx = lerp(0.15, 2.1, k)
			local face = CFrame.new(head.Position) * root.CFrame.Rotation
			local hand = face * CFrame.new(lerp(0.9, 0.2, k), lerp(-2.6, -0.45, k), lerp(-0.9, -1.0, k))
			place(o.b :: Bottle, hand * CFrame.Angles(rx, 0, lerp(0.25, 0.05, k)) * CFrame.new(0, -0.12 * U * 1.3 * 0.5, 0), 1 - k * 0.85)
		end
	end
end)

local ev = ReplicatedStorage:WaitForChild("PerkDrink") :: RemoteEvent
ev.OnClientEvent:Connect(function(p: Player, key: string, dur: number)
	if p == player then startMine(key, dur)
	else
		local o = others[p]
		if o and o.b then o.b.folder:Destroy() end
		others[p] = { p = p, b = nil, t0 = os.clock(), dur = dur, key = key }
	end
end)
Players.PlayerRemoving:Connect(function(p: Player)
	local o = others[p]
	if o and o.b then o.b.folder:Destroy() end
	others[p] = nil
end)
