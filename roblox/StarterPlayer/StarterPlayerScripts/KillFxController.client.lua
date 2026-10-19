--!strict
-- StarterPlayerScripts/KillFxController (LocalScript)
-- Joue les effets d'élimination (KillFxConfig) : le corps de l'ennemi éliminé disparaît en confettis, en pixels,
-- s'envole, gèle, se fait foudroyer… Tout est local et purement visuel : chaque client joue l'effet de son côté.
-- Le corps réel est seulement masqué (LocalTransparencyModifier) : le serveur le supprime ensuite comme d'habitude.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local fxEvent = ReplicatedStorage:WaitForChild("KillFx") :: RemoteEvent

local fxFolder = Instance.new("Folder"); fxFolder.Name = "KillFxLocal"; fxFolder.Parent = workspace

-- ---------- outils ----------
type Snap = { cf: CFrame, size: Vector3, color: Color3 }

local function snapshot(char: Model): { Snap }
	local list = {}
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and not d:FindFirstAncestor("HeldWeapon") and d.Transparency < 0.9 then
			table.insert(list, { cf = d.CFrame, size = d.Size, color = d.Color })
		end
	end
	return list
end

local function hideBody(char: Model)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then d.LocalTransparencyModifier = 1
		elseif d:IsA("Decal") then pcall(function() (d :: any).LocalTransparencyModifier = 1 end) end
	end
end

local function sound(id: string, pos: Vector3, volume: number, pitch: number)
	local a = Instance.new("Attachment"); a.WorldPosition = pos; a.Parent = workspace.Terrain
	local s = Instance.new("Sound"); s.SoundId = id; s.Volume = volume; s.PlaybackSpeed = pitch
	s.RollOffMaxDistance = 220; s.Parent = a
	s:Play()
	Debris:AddItem(a, 4)
end

local function newPart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do (p :: any)[k] = v end
	p.Parent = fxFolder
	return p
end

local function tween(o: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- copie « fantôme » de chaque partie du corps (sert à plusieurs effets)
local function ghostCopies(snaps: { Snap }, color: Color3?, material: Enum.Material, transparency: number): { Part }
	local out = {}
	for _, s in ipairs(snaps) do
		table.insert(out, newPart({ CFrame = s.cf, Size = s.size, Color = color or s.color, Material = material, Transparency = transparency }))
	end
	return out
end

local function burstEmitter(pos: Vector3, props: { [string]: any }, count: number, life: number)
	local holder = newPart({ Size = Vector3.one, Transparency = 1, Position = pos })
	local pe = Instance.new("ParticleEmitter")
	pe.Rate = 0; pe.Enabled = true
	for k, v in pairs(props) do (pe :: any)[k] = v end
	pe.Parent = holder
	pe:Emit(count)
	Debris:AddItem(holder, life)
end

local function light(pos: Vector3, color: Color3, range: number, brightness: number, t: number)
	local holder = newPart({ Size = Vector3.one, Transparency = 1, Position = pos })
	local l = Instance.new("PointLight"); l.Color = color; l.Range = range; l.Brightness = brightness; l.Parent = holder
	tween(l, t, { Brightness = 0 })
	Debris:AddItem(holder, t + 0.1)
end

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)), ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 210, 60)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 140)), ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 170, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 90, 255)),
})

-- ---------- effets ----------
local EFFECTS: { [string]: (Model, Vector3, { Snap }) -> () } = {}

-- Confettis : le corps éclate en une pluie de confettis multicolores
EFFECTS.confetti = function(char, pos, _snaps)
	hideBody(char)
	burstEmitter(pos, { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = RAINBOW, Lifetime = NumberRange.new(1.2, 2),
		Speed = NumberRange.new(14, 30), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -25, 0), Drag = 2,
		Size = NumberSequence.new(0.5, 0.2), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-300, 300) }, 120, 3)
	sound("rbxasset://sounds/electronicpingshort.wav", pos, 0.7, 1.8)
end

-- Désintégration pixel : le corps se décompose en petits cubes de sa couleur
EFFECTS.pixels = function(char, pos, snaps)
	hideBody(char)
	local made = 0
	for _, s in ipairs(snaps) do
		local n = math.clamp(math.floor(s.size.Magnitude * 2), 3, 10)
		for _ = 1, n do
			if made >= 70 then break end
			made += 1
			local offset = Vector3.new((math.random() - 0.5) * s.size.X, (math.random() - 0.5) * s.size.Y, (math.random() - 0.5) * s.size.Z)
			local cube = newPart({ Size = Vector3.one * 0.45, CFrame = s.cf * CFrame.new(offset), Color = s.color, Material = Enum.Material.SmoothPlastic })
			cube.Anchored = false; cube.CanCollide = true
			cube.AssemblyLinearVelocity = ((cube.Position - pos).Unit + Vector3.new(0, 0.8, 0)) * (10 + math.random() * 14)
			task.delay(0.9 + math.random() * 0.5, function() tween(cube, 0.6, { Transparency = 1, Size = Vector3.one * 0.1 }) end)
			Debris:AddItem(cube, 2.2)
		end
	end
	sound("rbxasset://sounds/clickfast.wav", pos, 0.8, 0.7)
end

-- Envol céleste : une silhouette lumineuse monte vers le ciel dans un rayon de lumière
EFFECTS.ascend = function(char, pos, snaps)
	hideBody(char)
	local gold = Color3.fromRGB(255, 236, 170)
	for _, p in ipairs(ghostCopies(snaps, gold, Enum.Material.Neon, 0.25)) do
		tween(p, 2.4, { CFrame = p.CFrame + Vector3.new(0, 26, 0), Transparency = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
		Debris:AddItem(p, 2.5)
	end
	local beam = newPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(80, 5, 5), CFrame = CFrame.new(pos + Vector3.new(0, 38, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = gold, Material = Enum.Material.Neon, Transparency = 0.55 })
	tween(beam, 2.4, { Transparency = 1, Size = Vector3.new(80, 1, 1) })
	Debris:AddItem(beam, 2.5)
	burstEmitter(pos, { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(gold), Lifetime = NumberRange.new(1.5, 2.2),
		Speed = NumberRange.new(4, 10), SpreadAngle = Vector2.new(40, 40), Acceleration = Vector3.new(0, 12, 0), Size = NumberSequence.new(0.6, 0) }, 60, 3)
	light(pos, gold, 22, 4, 2.2)
	sound("rbxasset://sounds/victory.wav", pos, 0.45, 1.5)
end

-- Coup de foudre : un éclair tombe du ciel, le corps est carbonisé puis s'effondre en cendres
EFFECTS.lightning = function(char, pos, snaps)
	hideBody(char)
	local blue = Color3.fromRGB(150, 210, 255)
	local top = pos + Vector3.new(math.random(-6, 6), 70, math.random(-6, 6))
	local prev = top
	for i = 1, 7 do
		local t = i / 7
		local nextPos = top:Lerp(pos, t) + (if i < 7 then Vector3.new(math.random(-4, 4), 0, math.random(-4, 4)) else Vector3.zero)
		local len = (nextPos - prev).Magnitude
		local seg = newPart({ Size = Vector3.new(0.6, 0.6, len), CFrame = CFrame.lookAt(prev, nextPos) * CFrame.new(0, 0, -len / 2), Color = blue, Material = Enum.Material.Neon })
		tween(seg, 0.45, { Transparency = 1 })
		Debris:AddItem(seg, 0.5)
		prev = nextPos
	end
	light(pos, blue, 40, 8, 0.6)
	local burnt = ghostCopies(snaps, Color3.fromRGB(28, 28, 30), Enum.Material.Slate, 0)
	task.delay(0.7, function()
		for _, p in ipairs(burnt) do
			p.Anchored = false; p.CanCollide = true
			p.AssemblyLinearVelocity = Vector3.new(math.random(-4, 4), 2, math.random(-4, 4))
			tween(p, 1.2, { Transparency = 1, Size = p.Size * 0.4 })
			Debris:AddItem(p, 1.3)
		end
		burstEmitter(pos, { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(60, 60, 64)),
			Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(2, 6), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(2, 5),
			Transparency = NumberSequence.new(0.3, 1) }, 25, 2)
	end)
	sound("rbxasset://sounds/Rocket shot.wav", pos, 1, 0.6)
end

-- Statue de glace : le corps gèle sur place puis vole en éclats
EFFECTS.ice = function(char, pos, snaps)
	hideBody(char)
	local frozen = ghostCopies(snaps, Color3.fromRGB(175, 225, 255), Enum.Material.Ice, 0.15)
	sound("rbxasset://sounds/swordhit.wav", pos, 0.7, 1.7)
	task.delay(1.3, function()
		for _, p in ipairs(frozen) do
			for _ = 1, 3 do
				local shard = newPart({ Size = p.Size * Vector3.new(0.45, 0.45, 0.45), CFrame = p.CFrame * CFrame.Angles(math.random() * 3, math.random() * 3, 0),
					Color = p.Color, Material = Enum.Material.Ice, Transparency = 0.15 })
				shard.Anchored = false; shard.CanCollide = true
				shard.AssemblyLinearVelocity = ((shard.Position - pos).Unit + Vector3.new(0, 0.6, 0)) * (12 + math.random() * 10)
				tween(shard, 1.4, { Transparency = 1 })
				Debris:AddItem(shard, 1.5)
			end
			p:Destroy()
		end
		sound("rbxasset://sounds/clickfast.wav", pos, 0.9, 1.3)
	end)
end

-- Trou noir : le corps est aspiré en tournoyant dans une sphère sombre
EFFECTS.blackhole = function(char, pos, snaps)
	hideBody(char)
	local purple = Color3.fromRGB(150, 70, 255)
	local core = newPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.2, Position = pos, Color = Color3.new(0, 0, 0), Material = Enum.Material.Neon })
	local ring = newPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.2, Position = pos, Color = purple, Material = Enum.Material.Neon, Transparency = 0.6 })
	tween(core, 0.35, { Size = Vector3.one * 5 }, Enum.EasingStyle.Back)
	tween(ring, 0.35, { Size = Vector3.one * 7 }, Enum.EasingStyle.Back)
	for _, p in ipairs(ghostCopies(snaps, nil, Enum.Material.SmoothPlastic, 0)) do
		tween(p, 1.1, { CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6), Size = Vector3.one * 0.1 },
			Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Debris:AddItem(p, 1.15)
	end
	task.delay(1.2, function()
		tween(core, 0.3, { Size = Vector3.one * 0.1 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tween(ring, 0.3, { Size = Vector3.one * 0.1, Transparency = 1 })
		burstEmitter(pos, { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(purple), Lifetime = NumberRange.new(0.5, 0.9),
			Speed = NumberRange.new(20, 30), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.5, 0) }, 50, 1.5)
	end)
	Debris:AddItem(core, 1.6); Debris:AddItem(ring, 1.6)
	light(pos, purple, 18, 3, 1.5)
	sound("rbxasset://sounds/electronicpingshort.wav", pos, 0.8, 0.45)
end

-- Pluie de citrouilles : le corps éclate en citrouilles qui rebondissent (code HALLOWEEN25)
EFFECTS.pumpkins = function(char, pos, _snaps)
	hideBody(char)
	local orange = Color3.fromRGB(255, 122, 26)
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local pk = newPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.3, 1.6), Position = pos + Vector3.new(0, 1, 0), Color = orange, Material = Enum.Material.SmoothPlastic })
		local stem = newPart({ Size = Vector3.new(0.25, 0.45, 0.25), Color = Color3.fromRGB(70, 130, 40), CFrame = pk.CFrame * CFrame.new(0, 0.75, 0) })
		stem.Anchored = false; stem.Massless = true
		local w = Instance.new("WeldConstraint"); w.Part0 = pk; w.Part1 = stem; w.Parent = pk
		pk.Anchored = false; pk.CanCollide = true
		pk.AssemblyLinearVelocity = Vector3.new(math.cos(a) * 14, 22 + math.random() * 8, math.sin(a) * 14)
		task.delay(2.2, function() tween(pk, 0.5, { Transparency = 1 }); tween(stem, 0.5, { Transparency = 1 }) end)
		Debris:AddItem(pk, 2.8)
	end
	light(pos, orange, 16, 3, 1.5)
	sound("rbxasset://sounds/swordhit.wav", pos, 0.6, 0.8)
end

-- Esprit du groupe : un esprit turquoise s'élève en ondulant (récompense du groupe Roblox)
EFFECTS.spirit = function(char, pos, snaps)
	hideBody(char)
	local teal = Color3.fromRGB(80, 255, 220)
	for _, p in ipairs(ghostCopies(snaps, teal, Enum.Material.ForceField, 0.1)) do
		local start = p.CFrame
		task.spawn(function()
			local t0 = os.clock()
			while p.Parent and os.clock() - t0 < 2.2 do
				local t = os.clock() - t0
				p.CFrame = start + Vector3.new(math.sin(t * 5) * 1.2, t * 9, math.cos(t * 4) * 0.6)
				p.Transparency = math.min(1, 0.1 + t / 2.2)
				task.wait()
			end
			p:Destroy()
		end)
	end
	burstEmitter(pos, { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(teal), Lifetime = NumberRange.new(1.2, 2),
		Speed = NumberRange.new(2, 5), SpreadAngle = Vector2.new(60, 60), Acceleration = Vector3.new(0, 6, 0), Size = NumberSequence.new(1.5, 3),
		Transparency = NumberSequence.new(0.5, 1) }, 30, 2.5)
	light(pos, teal, 18, 3, 2)
	sound("rbxasset://sounds/electronicpingshort.wav", pos, 0.6, 1.2)
end

-- ---------- effets de l'événement d'Halloween (src/8W_halloween.js HWFX) : le corps reste, l'effet s'y ajoute ----------
local RunService = game:GetService("RunService")
-- petite boucle d'animation : fn(t) renvoie false quand c'est fini
local function animate(life: number, fn: (number, number) -> ())
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt)
		local t = os.clock() - t0
		if t >= life then conn:Disconnect(); fn(life, dt); return end
		fn(t, dt)
	end)
end
local BAT = Color3.fromRGB(11, 7, 16)
-- Nuée de chauves-souris : 22 chauves-souris s'échappent en battant des ailes, lueur violette
EFFECTS.bats = function(_char, pos, _snaps)
	local origin = pos + Vector3.new(0, 1.5, 0)
	for _ = 1, 22 do
		local body = newPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.35, 0.3, 0.45), Color = BAT, Material = Enum.Material.SmoothPlastic,
			Position = origin + Vector3.new(math.random() - 0.5, math.random() - 0.6, math.random() - 0.5) * 0.8 })
		local wl = newPart({ Size = Vector3.new(0.9, 0.05, 0.4), Color = BAT, Material = Enum.Material.SmoothPlastic })
		local wr = newPart({ Size = Vector3.new(0.9, 0.05, 0.4), Color = BAT, Material = Enum.Material.SmoothPlastic })
		local eye = newPart({ Size = Vector3.new(0.18, 0.06, 0.04), Color = Color3.fromRGB(255, 48, 48), Material = Enum.Material.Neon })
		local a, sp, vy, sw, fl = math.random() * math.pi * 2, 4 + math.random() * 6, 3.5 + math.random() * 5.5, (math.random() - 0.5) * 6, 16 + math.random() * 8
		local life = 1.4 + math.random() * 0.8
		local p0 = body.Position
		animate(life, function(t, _dt)
			if t >= life then body:Destroy(); wl:Destroy(); wr:Destroy(); eye:Destroy(); return end
			local aa = a + sw * t * 0.4
			local p = p0 + Vector3.new(math.cos(aa) * sp * t, vy * t * (1 - t / life * 0.25), math.sin(aa) * sp * t)
			local cf = CFrame.lookAt(p, p + Vector3.new(math.cos(aa), 0.2, math.sin(aa)))
			local flap = math.sin(t * fl) * 0.9
			body.CFrame = cf
			wl.CFrame = cf * CFrame.new(-0.45, 0, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(-0.2, 0, 0)
			wr.CFrame = cf * CFrame.new(0.45, 0, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(0.2, 0, 0)
			eye.CFrame = cf * CFrame.new(0, 0.05, -0.22)
			local fade = math.clamp((life - t) / 0.4, 0, 1)
			body.Transparency = 1 - fade; wl.Transparency = 1 - fade; wr.Transparency = 1 - fade; eye.Transparency = 1 - fade
		end)
	end
	burstEmitter(origin, { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(Color3.fromRGB(138, 61, 255)),
		LightEmission = 1, Lifetime = NumberRange.new(0.7, 1.2), Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(1.6, 0.2), Transparency = NumberSequence.new(0.2, 1) }, 10, 1.5)
	sound("rbxasset://sounds/electronicpingshort.wav", pos, 0.5, 2.6)
end
-- Âme damnée : un crâne spectral vert monte en spirale, traînée d'étincelles vertes
EFFECTS.soul = function(_char, pos, _snaps)
	local green = Color3.fromRGB(109, 255, 122)
	local base = pos + Vector3.new(0, 1, 0)
	local skull = newPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.3, 1.3, 1.3), Color = Color3.fromRGB(190, 255, 200), Material = Enum.Material.Neon, Transparency = 0.15 })
	local jaw = newPart({ Size = Vector3.new(0.75, 0.4, 0.6), Color = Color3.fromRGB(190, 255, 200), Material = Enum.Material.Neon, Transparency = 0.15 })
	local eyes: { { p: Part, x: number } } = {}
	for _, sx in ipairs({ -0.25, 0.25 }) do
		table.insert(eyes, { p = newPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.34, 0.4, 0.2), Color = Color3.fromRGB(10, 58, 24), Material = Enum.Material.SmoothPlastic }), x = sx })
	end
	local glow = Instance.new("PointLight"); glow.Color = green; glow.Range = 14; glow.Brightness = 3; glow.Parent = skull
	local cam = workspace.CurrentCamera
	animate(2.4, function(t, _dt)
		if t >= 2.4 then skull:Destroy(); jaw:Destroy(); for _, e in ipairs(eyes) do e.p:Destroy() end; return end
		local sc = 0.5 + t * 0.45
		local p = base + Vector3.new(math.cos(t * 5) * 0.35 * t * 3.6, t * 1.3 * 3.6, math.sin(t * 5) * 0.35 * t * 3.6)
		local look = if cam then cam.CFrame.Position else p + Vector3.new(0, 0, -1)
		local cf = CFrame.lookAt(p, Vector3.new(look.X, p.Y, look.Z))
		skull.Size = Vector3.new(1.3, 1.3, 1.3) * sc; skull.CFrame = cf
		jaw.Size = Vector3.new(0.75, 0.4, 0.6) * sc; jaw.CFrame = cf * CFrame.new(0, -0.6 * sc, -0.1 * sc)
		for _, e in ipairs(eyes) do e.p.Size = Vector3.new(0.34, 0.4, 0.2) * sc; e.p.CFrame = cf * CFrame.new(e.x * sc, 0.05 * sc, -0.55 * sc) end
		local fade = 1 - math.clamp((2.4 - t) / 0.6, 0, 1)
		skull.Transparency = 0.15 + fade * 0.85; jaw.Transparency = skull.Transparency
		for _, e in ipairs(eyes) do e.p.Transparency = fade end
		glow.Brightness = 3 * (1 - fade)
	end)
	burstEmitter(base - Vector3.new(0, 2, 0), { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(green, Color3.fromRGB(184, 255, 176)),
		LightEmission = 1, Lifetime = NumberRange.new(1, 1.8), Speed = NumberRange.new(4, 9), SpreadAngle = Vector2.new(25, 25),
		Acceleration = Vector3.new(0, 4, 0), Drag = 1, Size = NumberSequence.new(0.6, 0.1), Transparency = NumberSequence.new(0, 1) }, 36, 2.2)
	light(base, green, 18, 3, 1.6)
	sound("rbxasset://sounds/electronicpingshort.wav", pos, 0.7, 0.55)
end
-- Pierre tombale : une tombe « R.I.P. » au nom de l'adversaire sort de terre, mottes de terre, lueur verte
EFFECTS.grave = function(char, pos, _snaps)
	local cam = workspace.CurrentCamera
	local from = if cam then cam.CFrame.Position else pos + Vector3.new(0, 0, 5)
	local away = Vector3.new(pos.X - from.X, 0, pos.Z - from.Z)
	away = if away.Magnitude > 0.01 then away.Unit else Vector3.new(0, 0, 1)
	local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances = { fxFolder, char }
	local hit = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -14, 0), params)
	local ground = if hit then hit.Position.Y else pos.Y - 3
	local at = Vector3.new(pos.X, ground, pos.Z) + away * 3.2
	local stone = Color3.fromRGB(176, 180, 176)
	local slab = newPart({ Size = Vector3.new(2.9, 2.7, 0.7), Color = stone, Material = Enum.Material.Slate })
	local top = newPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.7, 2.9, 2.9), Color = stone, Material = Enum.Material.Slate })
	local gui = Instance.new("SurfaceGui"); gui.Face = Enum.NormalId.Front; gui.CanvasSize = Vector2.new(256, 240); gui.LightInfluence = 1; gui.Parent = slab
	local rip = Instance.new("TextLabel"); rip.BackgroundTransparency = 1; rip.Size = UDim2.new(1, 0, 0.45, 0); rip.Font = Enum.Font.Garamond
	rip.TextScaled = true; rip.TextColor3 = Color3.fromRGB(42, 42, 46); rip.Text = "R.I.P."; rip.Parent = gui
	local nm = Instance.new("TextLabel"); nm.BackgroundTransparency = 1; nm.Position = UDim2.fromScale(0, 0.45); nm.Size = UDim2.new(1, 0, 0.3, 0)
	nm.Font = Enum.Font.Garamond; nm.TextScaled = true; nm.TextColor3 = Color3.fromRGB(42, 42, 46); nm.Text = string.upper(string.sub(char.Name, 1, 12)); nm.Parent = gui
	local face = CFrame.lookAt(at, Vector3.new(from.X, at.Y, from.Z)) * CFrame.Angles(0, 0, (math.random() - 0.5) * 0.16)
	animate(3.2, function(t, _dt)
		if t >= 3.2 then slab:Destroy(); top:Destroy(); return end
		local k = if t < 0.45 then -1 + (1 - (1 - t / 0.45) ^ 3) elseif t > 2.6 then -math.min(1, (t - 2.6) / 0.6) else 0
		local y = 1.35 + k * 4
		slab.CFrame = face * CFrame.new(0, y, 0)
		top.CFrame = face * CFrame.new(0, y + 1.35, 0) * CFrame.Angles(0, math.pi / 2, 0)
	end)
	burstEmitter(at + Vector3.new(0, 0.3, 0), { Color = ColorSequence.new(Color3.fromRGB(74, 58, 40), Color3.fromRGB(46, 36, 26)), Lifetime = NumberRange.new(0.6, 1.1),
		Speed = NumberRange.new(8, 16), SpreadAngle = Vector2.new(50, 50), Acceleration = Vector3.new(0, -40, 0), Size = NumberSequence.new(0.35, 0.2) }, 26, 1.5)
	burstEmitter(at + Vector3.new(0, 0.6, 0), { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(74, 154, 96)),
		LightEmission = 0.6, Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(0.5, 1.5), Size = NumberSequence.new(2, 3.5), Transparency = NumberSequence.new(0.5, 1) }, 10, 3)
	light(at + Vector3.new(0, 4, 0) - away * 2.8, Color3.fromRGB(154, 255, 176), 16, 3, 3.2)
	sound("rbxasset://sounds/collide.wav", at, 0.9, 0.5)
end

-- ---------- réception ----------
fxEvent.OnClientEvent:Connect(function(id: string, char: Model?, pos: Vector3, _killerId: number)
	local fn = EFFECTS[id]
	if not fn or typeof(pos) ~= "Vector3" then return end
	local snaps = if char and char.Parent then snapshot(char) else {}
	local ok, err = pcall(fn, char or Instance.new("Model"), pos, snaps)
	if not ok then warn("[KillFx] effet", id, err) end
end)

-- Aperçu depuis la boutique ou le casier : _G.PreviewKillFx("ice", position, personnage)
_G.PreviewKillFx = function(id: string, pos: Vector3, char: Model?)
	local fn = EFFECTS[id]
	if fn then fn(char or Instance.new("Model"), pos, if char then snapshot(char) else {}) end
end
