--!strict
-- StarterPlayerScripts/KillcamController (LocalScript)
-- KILL-CAM façon Call of Duty, comme le jeu web (src/8R_killcam.js + 6A_replay.js) :
-- quand on se fait éliminer en match à mort par équipe, on revoit les dernières secondes par les yeux du tueur,
-- avec son arme et ses bras en vue subjective, au ralenti autour du tir. La cible est zoomée quand le tueur la vise,
-- surlignée en rouge seulement quand un mur la cache, et un repère avec son nom flotte au-dessus d'elle.
-- ESPACE ou clic pour passer. La réapparition attend la fin de la kill-cam (KillcamHold, MatchService).
--
-- Enregistrement : chaque client garde en mémoire les 4 dernières secondes de tous les soldats (position de chaque
-- pièce du corps, regard, arme) et des tirs. À la mort, on fait des copies des soldats et on les rejoue.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local ModeConfig = require(ReplicatedStorage.Shared.ModeConfig)
local WeaponModels = require(ReplicatedStorage.Shared.WeaponModels)
local SkinPaint = require(ReplicatedStorage.Shared.SkinPaint)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local S = require(ReplicatedStorage.Shared.ClientState)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local deathRemote = ReplicatedStorage:WaitForChild("DeathInfo") :: RemoteEvent
local tracerRemote = ReplicatedStorage:WaitForChild("Tracer") :: RemoteEvent
local holdRemote = ReplicatedStorage:WaitForChild("KillcamHold", 30) :: RemoteEvent?
local pitchRemote = ReplicatedStorage:WaitForChild("AimPitch", 30) :: UnreliableRemoteEvent?

local REC_DT = 1 / 20          -- 20 images par seconde
local KEEP = 4                 -- secondes gardées
local BEFORE, AFTER = 2.2, 0.5 -- fenêtre rejouée autour de l'élimination (web : 2,2 s avant, 0,6 s après)
local WAIT = 0.6               -- petite pause sur l'écran de mort avant la kill-cam (l'enregistrement continue)
local WORLD_SCALE = 2.9        -- arme tenue (même valeur que WeaponService)
local GRIP = CFrame.new(0, -0.1, 0) * CFrame.Angles(math.rad(-90), 0, 0)
local BASE_FOV = 70

-- ---------- regard envoyé au serveur (sert à la kill-cam des autres) ----------
local lastPitch, pitchT = 99, 0
RunService.Heartbeat:Connect(function(dt: number)
	pitchT += dt
	if pitchT < 0.1 or not pitchRemote then return end
	pitchT = 0
	-- kill-cam, arrivée, spectateur, mode photo : la caméra n'est pas notre regard
	if S.kc ~= nil or camera.CameraType ~= Enum.CameraType.Custom then return end
	local p = math.asin(math.clamp(camera.CFrame.LookVector.Y, -1, 1))
	if math.abs(p - lastPitch) > 0.01 then lastPitch = p; (pitchRemote :: UnreliableRemoteEvent):FireServer(p) end
end)

-- ---------- enregistrement ----------
type Snap = { cf: { [BasePart]: CFrame }, pitch: number, key: string?, speed: number, grounded: boolean, vy: number, alive: boolean }
type Frame = { t: number, m: { [Model]: Snap } }
local frames: { Frame } = {}
type Shot = { t: number, from: Vector3, to: Vector3, shooter: Instance? }
local shots: { Shot } = {}
local recording = true

local function soldiers(): { Model }
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		if c and c.Parent then table.insert(list, c) end
	end
	local bots = workspace:FindFirstChild("Bots")
	if bots then for _, b in ipairs(bots:GetChildren()) do if b:IsA("Model") then table.insert(list, b) end end end
	return list
end

-- pièces du corps (sans l'arme tenue, refaite à part avec WeaponModels)
local function bodyParts(model: Model): { BasePart }
	local out = {}
	local held = model:FindFirstChild("HeldWeapon")
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and not (held and d:IsDescendantOf(held)) and d ~= held then table.insert(out, d) end
	end
	return out
end

local function snapshot(model: Model): Snap?
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return nil end
	local cf = {}
	for _, p in ipairs(bodyParts(model)) do cf[p] = p.CFrame end
	local held = model:FindFirstChild("HeldWeapon")
	local key = held and held:GetAttribute("Key")
	local v = root.AssemblyLinearVelocity
	return { cf = cf, pitch = (model:GetAttribute("Pitch") :: number?) or 0, key = if typeof(key) == "string" then key else nil,
		speed = Vector3.new(v.X, 0, v.Z).Magnitude, grounded = hum.FloorMaterial ~= Enum.Material.Air, vy = v.Y, alive = hum.Health > 0 }
end

local recAcc = 0
RunService.Heartbeat:Connect(function(dt: number)
	if not recording then return end
	recAcc += dt
	if recAcc < REC_DT then return end
	recAcc = 0
	local t = os.clock()
	local f: Frame = { t = t, m = {} }
	for _, m in ipairs(soldiers()) do
		local s = snapshot(m)
		if s then f.m[m] = s end
	end
	table.insert(frames, f)
	while #frames > 0 and frames[1].t < t - KEEP do table.remove(frames, 1) end
	while #shots > 0 and shots[1].t < t - KEEP do table.remove(shots, 1) end
end)

tracerRemote.OnClientEvent:Connect(function(origin: Vector3, endPos: Vector3, shooter: Instance?)
	if recording then table.insert(shots, { t = os.clock(), from = origin, to = endPos, shooter = shooter }) end
end)

-- ---------- interface (mêmes éléments que #rpov du web) ----------
local C = { red = Color3.fromRGB(255, 70, 85), text = Color3.new(1, 1, 1), dim = Color3.fromRGB(200, 205, 215) }
local gui = Instance.new("ScreenGui"); gui.Name = "Killcam"; gui.IgnoreGuiInset = true; gui.ResetOnSpawn = false
gui.DisplayOrder = 40; gui.Enabled = false; gui.Parent = player:WaitForChild("PlayerGui")
local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local o: any = Instance.new(class)
	if class == "TextLabel" then o.BackgroundTransparency = 1; o.Font = Enum.Font.GothamBlack; o.TextColor3 = C.text end
	if o:IsA("GuiObject") then o.BorderSizePixel = 0 end   -- UICorner, UIStroke… n'ont pas de bordure (l'erreur arrêtait toute la kill-cam)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
make("Frame", { Size = UDim2.fromScale(1, 0.1), BackgroundColor3 = Color3.new() }, gui)
make("Frame", { Size = UDim2.fromScale(1, 0.1), Position = UDim2.fromScale(0, 0.9), BackgroundColor3 = Color3.new() }, gui)
local tag = make("Frame", { Position = UDim2.fromScale(0.04, 0.125), Size = UDim2.fromOffset(260, 22), BackgroundTransparency = 1 }, gui)
local recDot = make("Frame", { Size = UDim2.fromOffset(12, 12), Position = UDim2.fromOffset(0, 5), BackgroundColor3 = Color3.fromRGB(255, 42, 58) }, tag)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, recDot)
make("TextLabel", { Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -22, 1, 0), Text = "K I L L - C A M", TextSize = 16,
	TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 0.6 }, tag)
local who = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.87), Size = UDim2.new(1, 0, 0, 36),
	TextSize = 28, RichText = true, Text = "", TextStrokeTransparency = 0.5 }, gui)
local pg = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.894), Size = UDim2.new(0.4, 0, 0, 3),
	BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.8 }, gui)
local pgFill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.red }, pg)
make("TextLabel", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.96, 0, 0.96, 0), Size = UDim2.fromOffset(300, 16),
	Text = "ESPACE — PASSER", TextSize = 12, Font = Enum.Font.GothamBold, TextColor3 = C.dim, TextTransparency = 0.3,
	TextXAlignment = Enum.TextXAlignment.Right }, gui)

-- repère au-dessus de la cible : nom sur fond rouge + chevron qui rebondit
local marker = Instance.new("BillboardGui"); marker.Name = "KillcamTarget"; marker.AlwaysOnTop = true
marker.Size = UDim2.fromOffset(160, 46); marker.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0); marker.LightInfluence = 0
local mName = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(0, 20),
	AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 0.2, BackgroundColor3 = Color3.fromRGB(255, 59, 75), TextSize = 13, Text = "" }, marker)
make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, mName)
make("UICorner", { CornerRadius = UDim.new(0, 3) }, mName)
local chevron = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20), Size = UDim2.fromOffset(30, 22),
	Text = "▼", TextSize = 20, TextColor3 = Color3.fromRGB(255, 59, 75), TextStrokeTransparency = 0.4 }, marker)

-- ---------- rediffusion ----------
type Ghost = { model: Model, map: { [BasePart]: BasePart }, alpha: { [BasePart]: number }, gun: Model?, gunKey: string?, hand: BasePart?, src: Model, skin: number?, camo: string? }
local KC = {
	on = false, setup = false, rt = 0, prev = 0, t0 = 0, t1 = 0, tk = 0, hold = 0, wait = 0, blood = false, zoom = 1,
	killer = nil :: Model?, victim = nil :: Model?, ghosts = {} :: { [Model]: Ghost }, hidden = {} :: { BasePart },
	guis = {} :: { ScreenGui }, info = nil :: any, highlight = nil :: Highlight?, rpShots = {} :: { Shot },
	skin = nil :: number?, camo = nil :: string?, savedType = Enum.CameraType.Custom, savedFov = BASE_FOV,
}

-- copie d'un soldat : pièces ancrées, sans articulations, sans scripts ; reliée pièce à pièce à l'original
local function makeGhost(src: Model): Ghost?
	local was = src.Archivable
	src.Archivable = true
	local ok, copy = pcall(function() return src:Clone() end)
	src.Archivable = was
	if not ok or not copy then return nil end
	local model = copy :: Model
	local held = model:FindFirstChild("HeldWeapon"); if held then held:Destroy() end
	local a, b = src:GetDescendants(), model:GetDescendants()
	-- même ordre des descendants des deux côtés, sauf l'arme retirée de la copie
	local srcHeld = src:FindFirstChild("HeldWeapon")
	local filtered = {}
	for _, d in ipairs(a) do if not (srcHeld and (d == srcHeld or d:IsDescendantOf(srcHeld))) then table.insert(filtered, d) end end
	local map: { [BasePart]: BasePart } = {}
	for i, d in ipairs(b) do
		local o = filtered[i]
		if d:IsA("BasePart") and o and o:IsA("BasePart") then map[o] = d end
	end
	for _, d in ipairs(b) do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript")
			or d:IsA("Highlight") or d:IsA("BillboardGui") or d:IsA("Sound") or d:IsA("ForceField") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true; d.CanCollide = false; d.CanQuery = false; d.CanTouch = false; d.LocalTransparencyModifier = 0
		elseif d:IsA("Humanoid") then
			d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			d.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
			d.EvaluateStateMachine = false
		end
	end
	model.Name = "Killcam_" .. src.Name
	local alpha: { [BasePart]: number } = {}
	for _, c in pairs(map) do alpha[c] = c.Transparency end
	local g: Ghost = { model = model, map = map, alpha = alpha, src = src, hand = (model:FindFirstChild("RightHand") or model:FindFirstChild("Right Arm")) :: BasePart?,
		skin = srcHeld and srcHeld:GetAttribute("Skin") :: number?, camo = srcHeld and srcHeld:GetAttribute("Camo") :: string? }
	return g
end

local function setGhostGun(g: Ghost, key: string?)
	if g.gunKey == key then return end
	g.gunKey = key
	if g.gun then g.gun:Destroy(); g.gun = nil end
	if not key or not Config.WEAPONS[key] then return end
	local ok, m = pcall(WeaponModels.build, key, WORLD_SCALE)
	if ok and m then
		SkinPaint.apply(m, g.skin, g.camo)
		m.Parent = g.model; g.gun = m
	end
end

local function frameAt(t: number): (Frame?, Frame?, number)
	if #frames == 0 then return nil, nil, 0 end
	local i = 1
	while i < #frames - 1 and frames[i + 1].t < t do i += 1 end
	local a, b = frames[i], frames[math.min(#frames, i + 1)]
	local k = if b.t > a.t then math.clamp((t - a.t) / (b.t - a.t), 0, 1) else 0
	return a, b, k
end

local function hideLive(on: boolean)
	if on then
		KC.hidden = {}
		for _, m in ipairs(soldiers()) do
			for _, p in ipairs(m:GetDescendants()) do
				if p:IsA("BasePart") and p.LocalTransparencyModifier < 1 then p.LocalTransparencyModifier = 1; table.insert(KC.hidden, p) end
			end
		end
	else
		for _, p in ipairs(KC.hidden) do if p.Parent then p.LocalTransparencyModifier = 0 end end
		KC.hidden = {}
	end
end

local function hideHud(on: boolean)
	local pgui = player:FindFirstChildOfClass("PlayerGui")
	if not pgui then return end
	if on then
		KC.guis = {}
		for _, g in ipairs(pgui:GetChildren()) do
			if g:IsA("ScreenGui") and g ~= gui and g.Enabled then g.Enabled = false; table.insert(KC.guis, g) end
		end
	else
		for _, g in ipairs(KC.guis) do if g.Parent then g.Enabled = true end end
		KC.guis = {}
	end
end

local function stop()
	if not KC.on then return end
	KC.on = false
	recording = true
	S.kc = nil
	if S.onSkin then S.onSkin() end
	gui.Enabled = false
	(marker :: any).Parent = nil; (marker :: any).Adornee = nil
	if KC.highlight then KC.highlight:Destroy(); KC.highlight = nil end
	for _, g in pairs(KC.ghosts) do g.model:Destroy() end
	KC.ghosts = {}
	hideLive(false)
	hideHud(false)
	-- la caméra n'a été prise qu'à la fin de la petite pause (finishSetup) : avant, rien à rendre
	if KC.setup then
		KC.setup = false
		camera.CameraType = if KC.savedType == Enum.CameraType.Scriptable then Enum.CameraType.Custom else KC.savedType
		camera.FieldOfView = KC.savedFov
	end
	if holdRemote then holdRemote:FireServer(false) end
end

local function begin(info: any)
	local killer = info.killerChar
	if typeof(killer) ~= "Instance" or not killer:IsA("Model") or killer == player.Character then return end
	if #frames < 10 then return end
	KC.tk = os.clock()
	if KC.tk - frames[1].t < 0.6 then return end
	KC.info = info; KC.killer = killer :: Model; KC.victim = player.Character
	local held = killer:FindFirstChild("HeldWeapon")
	KC.skin = held and held:GetAttribute("Skin") :: number?
	KC.camo = held and held:GetAttribute("Camo") :: string?
	KC.on = true; KC.wait = WAIT; KC.hold = 0; KC.blood = false; KC.zoom = 1
	if holdRemote then holdRemote:FireServer(true) end
	-- copies des soldats enregistrés (faites tout de suite : le corps du tueur ou d'un bot peut disparaître)
	local seen: { [Model]: boolean } = {}
	for _, f in ipairs(frames) do for m in pairs(f.m) do seen[m] = true end end
	for m in pairs(seen) do
		if m.Parent then
			local g = makeGhost(m)
			if g then KC.ghosts[m] = g end
		end
	end
	local kname = tostring(info.killer or killer.Name)
	local vname = tostring(info.victimName or player.DisplayName)
	who.Text = string.format('%s  <font color="#9aa6b8">[%s]</font>  <font color="#ff4655">%s</font>%s', kname, tostring(info.weapon or ""), vname,
		if info.headshot then '  <font color="#ff4655">· TÊTE</font>' else "")
	mName.Text = vname
end

local function finishSetup()
	-- fin de la pause : on passe en rediffusion
	recording = false
	KC.t0 = math.max(frames[1].t, KC.tk - BEFORE)
	KC.t1 = math.min(frames[#frames].t, KC.tk + AFTER)
	KC.rt = KC.t0; KC.prev = KC.t0
	KC.rpShots = table.clone(shots)
	for _, g in pairs(KC.ghosts) do g.model.Parent = workspace end
	hideLive(true); hideHud(true)
	KC.savedType = camera.CameraType; KC.savedFov = camera.FieldOfView; KC.setup = true
	camera.CameraType = Enum.CameraType.Scriptable
	gui.Enabled = true
	local vg = KC.victim and KC.ghosts[KC.victim]
	if vg then
		local h = Instance.new("Highlight"); h.FillColor = Color3.fromRGB(255, 48, 64); h.FillTransparency = 0.55
		h.OutlineColor = Color3.fromRGB(255, 48, 64); h.OutlineTransparency = 0.2; h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		h.Enabled = false; h.Adornee = vg.model; h.Parent = vg.model
		KC.highlight = h
		marker.Adornee = (vg.model:FindFirstChild("Head") or vg.model.PrimaryPart) :: any
		marker.Parent = player:FindFirstChildOfClass("PlayerGui")
	end
	S.kc = { key = nil, skin = KC.skin, camo = KC.camo }
end

local function tracer(from: Vector3, to: Vector3)
	local len = (to - from).Magnitude
	if len < 1 then return end
	local p = Instance.new("Part"); p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
	p.Material = Enum.Material.Neon; p.Color = Color3.fromRGB(255, 190, 120)
	p.Size = Vector3.new(0.06, 0.06, len); p.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -len / 2)
	p.Transparency = 0.15; p.Parent = workspace
	TweenService:Create(p, TweenInfo.new(0.25), { Transparency = 1 }):Play()
	Debris:AddItem(p, 0.3)
end

local function blood(at: Vector3, head: boolean)
	local a = Instance.new("Attachment"); a.WorldPosition = at; a.Parent = workspace.Terrain
	local e = Instance.new("ParticleEmitter"); e.Color = ColorSequence.new(Color3.fromRGB(150, 10, 18)); e.LightEmission = 0
	e.Size = NumberSequence.new(0.35, 0); e.Speed = NumberRange.new(6, 14); e.SpreadAngle = Vector2.new(60, 60)
	e.Lifetime = NumberRange.new(0.25, 0.5); e.Acceleration = Vector3.new(0, -40, 0); e.Rate = 0; e.Parent = a
	e:Emit(if head then 22 else 12)
	Debris:AddItem(a, 1.2)
end

local losParams = RaycastParams.new(); losParams.FilterType = Enum.RaycastFilterType.Exclude

RunService:BindToRenderStep("Killcam", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	if not KC.on then return end
	if KC.wait > 0 then
		KC.wait -= dt
		if KC.wait <= 0 then finishSetup() end
		return
	end
	-- vitesse : normale, ralenti autour du tir, puis normale (comme le web)
	local near = math.abs(KC.rt - KC.tk)
	local sp = if near < 0.55 then 0.28 elseif near < 1 then 0.55 else 1
	KC.prev = KC.rt; KC.rt = math.min(KC.t1, KC.rt + dt * sp)
	local a, b, k = frameAt(KC.rt)
	if not a or not b then stop(); return end
	-- soldiers
	for src, g in pairs(KC.ghosts) do
		local sa, sb = a.m[src], b.m[src] or a.m[src]
		if not sa then
			g.model.Parent = nil
		else
			g.model.Parent = workspace
			for o, c in pairs(g.map) do
				local ca, cb = sa.cf[o], sb and sb.cf[o]
				if ca then c.CFrame = if cb then ca:Lerp(cb, k) else ca; c.Transparency = g.alpha[c] else c.Transparency = 1 end
			end
			setGhostGun(g, sa.key)
			if g.gun and g.hand then WeaponModels.place(g.gun, g.hand.CFrame * GRIP) end
		end
	end
	-- tirs rejoués
	local kg = KC.killer and KC.ghosts[KC.killer]
	for _, s in ipairs(KC.rpShots) do
		if s.t > KC.prev and s.t <= KC.rt then
			local mine = s.shooter == KC.killer
			local key = if mine then S.kc and S.kc.key else s.shooter and s.shooter:GetAttribute("Weapon")
			local w = typeof(key) == "string" and Config.WEAPONS[key]
			tracer(if mine and S.muzzle then S.muzzle else s.from, s.to)
			if w then
				local snd = ModeConfig.SOUNDS.fire[if w.melee then "melee" else w.cat] or ModeConfig.SOUNDS.fire.rifle
				if mine then Sfx.play(snd); S.shot:Fire(key) else Sfx.play(snd, s.from, 0.45) end
			end
		end
	end
	-- caméra : les yeux du tueur
	local ka = KC.killer and a.m[KC.killer]
	local kb = KC.killer and b.m[KC.killer] or ka
	if not ka or not kg then stop(); return end
	local head = kg.model:FindFirstChild("Head") :: BasePart?
	local root = kg.model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not head or not root then stop(); return end
	for _, c in pairs(kg.map) do c.Transparency = 1 end      -- sinon on verrait l'intérieur de sa tête
	if kg.gun then for _, c in ipairs(kg.gun:GetDescendants()) do if c:IsA("BasePart") then c.LocalTransparencyModifier = 1 end end end
	local pitch = ka.pitch + ((kb and kb.pitch or ka.pitch) - ka.pitch) * k
	local look = root.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	local eye = head.Position + Vector3.new(0, 0.25, 0)
	camera.CFrame = CFrame.new(eye) * CFrame.fromOrientation(pitch, yaw, 0)
	-- l'arme du tueur en vue subjective
	if S.kc then
		S.kc.key = ka.key
		S.speed = ka.speed; S.grounded = ka.grounded; S.vy = ka.vy; S.aiming = false
	end
	-- la cible : zoom selon la distance quand le tueur la vise, silhouette rouge seulement derrière un mur
	local vg = KC.victim and KC.ghosts[KC.victim]
	local vHead = vg and (vg.model:FindFirstChild("Head") :: BasePart?)
	local tz = 1
	if vHead and vHead.Transparency < 1 then
		local to = vHead.Position - eye
		local d = to.Magnitude
		if d > 3 and to.Unit:Dot(camera.CFrame.LookVector) > 0.94 then tz = math.clamp(d / 20, 1, 2.6) end
		if KC.highlight then
			local ignore: { Instance } = {}
			for _, g in pairs(KC.ghosts) do table.insert(ignore, g.model) end
			for _, m in ipairs(soldiers()) do table.insert(ignore, m) end
			losParams.FilterDescendantsInstances = ignore
			KC.highlight.Enabled = workspace:Raycast(eye, to, losParams) ~= nil
		end
		marker.Enabled = true
	else
		marker.Enabled = false
		if KC.highlight then KC.highlight.Enabled = false end
	end
	KC.zoom += (tz - KC.zoom) * math.min(1, dt * 5)
	camera.FieldOfView += (BASE_FOV / KC.zoom - camera.FieldOfView) * math.min(1, dt * 18)
	chevron.Position = UDim2.new(0.5, 0, 0, 20 + math.abs(math.sin(os.clock() * 4.5)) * 4)
	recDot.BackgroundTransparency = if os.clock() % 1 < 0.5 then 0 else 0.8
	-- l'impact
	if not KC.blood and KC.rt >= KC.tk and vHead then
		KC.blood = true
		blood(vHead.Position - (if KC.info.headshot then Vector3.zero else Vector3.new(0, 1.2, 0)), KC.info.headshot == true)
		if KC.info.headshot then Sfx.play("hs") end
	end
	pgFill.Size = UDim2.fromScale(math.clamp((KC.rt - KC.t0) / math.max(0.01, KC.t1 - KC.t0), 0, 1), 1)
	if KC.rt >= KC.t1 then
		KC.hold += dt
		if KC.hold > 1 then stop() end
	end
end)

-- ---------- déclenchement ----------
deathRemote.OnClientEvent:Connect(function(info: any)
	if typeof(info) ~= "table" or not info.killcam or KC.on then return end
	if player:GetAttribute("KillcamOff") == true then return end
	begin(info)
end)

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed or not KC.on or KC.wait > 0 then return end   -- pas quand on tape dans le chat
	if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA or input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		stop()
	end
end)

-- réapparition, fin de partie, téléportation au salon : on coupe proprement
player.CharacterAdded:Connect(function() stop() end)
player:GetAttributeChangedSignal("Zone"):Connect(function() stop() end)
