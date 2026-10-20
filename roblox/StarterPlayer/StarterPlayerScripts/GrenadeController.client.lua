--!strict
-- StarterPlayerScripts/GrenadeController (LocalScript)
-- Grenades et mines côté joueur, comme le jeu web : touches G (frag), F (flash), H (fumigène), X (mine),
-- bras qui lancent (ViewmodelController, S.throwStart), trajectoire affichée (même simulation que le serveur),
-- explosion, éclair, nuage de fumée, aveuglement + sifflement d'oreilles, secousse de la caméra,
-- compteur en bas à droite (#nades du web) et alerte grenade (src/8Zf_confort.js : icône 💣 autour du viseur
-- qui indique d'où vient une frag qui va sauter près de toi).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local G = require(ReplicatedStorage.Shared.Grenades)
local S = require(ReplicatedStorage.Shared.ClientState)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local ShotFx = require(ReplicatedStorage.Shared.ShotFx)
local M = G.M

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local fxRemote = ReplicatedStorage:WaitForChild("GrenadeFx") :: RemoteEvent
local throwRemote = ReplicatedStorage:WaitForChild("ThrowGrenade") :: RemoteEvent
local mineRemote = ReplicatedStorage:WaitForChild("PlaceMine") :: RemoteEvent
local toastRemote = ReplicatedStorage:WaitForChild("GrenadeToast") :: RemoteEvent
local flashRemote = ReplicatedStorage:WaitForChild("FlashFeedback") :: RemoteEvent

local folder = Instance.new("Folder"); folder.Name = "GrenadesFx"; folder.Parent = workspace

-- ---------- interface ----------
local function rgb(h: number): Color3 return Color3.fromRGB(bit32.rshift(h, 16), bit32.band(bit32.rshift(h, 8), 255), bit32.band(h, 255)) end
local gui = Instance.new("ScreenGui"); gui.Name = "GrenadeHud"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.DisplayOrder = 11
gui.Parent = player:WaitForChild("PlayerGui")
-- voile blanc de la flash (#flashfx)
local white = Instance.new("Frame"); white.Size = UDim2.fromScale(1, 1); white.BackgroundColor3 = Color3.new(1, 1, 1); white.BackgroundTransparency = 1
white.BorderSizePixel = 0; white.ZIndex = 20; white.Parent = gui
-- compteur (#nades), au-dessus des emplacements d'armes du HUD
local count = Instance.new("TextLabel"); count.AnchorPoint = Vector2.new(1, 1); count.Position = UDim2.new(1, -19, 1, -152)
count.Size = UDim2.fromOffset(320, 18); count.BackgroundTransparency = 1; count.Font = Enum.Font.GothamBold; count.TextSize = 13
count.TextColor3 = rgb(0xdbe5f5); count.TextStrokeTransparency = 0.5; count.TextXAlignment = Enum.TextXAlignment.Right; count.Text = ""
count.Parent = gui
local toast = Instance.new("TextLabel"); toast.AnchorPoint = Vector2.new(.5, 1); toast.Position = UDim2.new(.5, 0, 1, -170)
toast.Size = UDim2.fromOffset(300, 30); toast.BackgroundColor3 = rgb(0x161f33); toast.BackgroundTransparency = 0.1; toast.Font = Enum.Font.GothamBold
toast.TextSize = 14; toast.TextColor3 = Color3.new(1, 1, 1); toast.Visible = false; toast.Parent = gui
do local s = Instance.new("UIStroke"); s.Color = rgb(0xffd75e); s.Parent = toast end
local toastId = 0
local function showToast(t: string)
	toastId += 1
	local my = toastId
	toast.Text = t; toast.Visible = true
	task.delay(1.8, function() if toastId == my then toast.Visible = false end end)
end
toastRemote.OnClientEvent:Connect(function(t: any) if typeof(t) == "string" then showToast(t) end end)

local function stock(): (number, number, number, number)
	local raw = player:GetAttribute("Nades")
	if typeof(raw) ~= "string" then return 0, 0, 0, 0 end
	local f, fl, sm, mn = string.match(raw, "^(%d+),(%d+),(%d+),(%d+)$")
	return tonumber(f) or 0, tonumber(fl) or 0, tonumber(sm) or 0, tonumber(mn) or 0
end
local function drawCount()
	local f, fl, sm, mn = stock()
	if player:GetAttribute("Nades") == nil then count.Text = "" return end
	local t = (if f > 0 then "●G " else "○G ") .. (if fl > 0 then "●F×" .. fl .. " " else "○F ") .. (if sm > 0 then "●H" else "○H")
	if mn > 0 then t ..= "    ◉ ×" .. mn .. " [X]" end
	count.Text = t
end
player:GetAttributeChangedSignal("Nades"):Connect(drawCount)
drawCount()

-- ---------- commandes ----------
local function canUse(): boolean
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0 and player:GetAttribute("UiOpen") ~= true and player:GetAttribute("MenuOpen") ~= true and S.kc == nil
end
local IDX = { frag = 1, flash = 2, smoke = 3 }
local function throw(kind: string)
	if not canUse() then return end
	local n = ({ stock() })[IDX[kind]]
	if (n or 0) <= 0 then return end
	throwRemote:FireServer(kind, camera.CFrame.LookVector)
	S.throwStart = os.clock(); S.inspectStart = -1
	Sfx.play(G.SFX.throw)
end
local function onAction(name: string, st: Enum.UserInputState)
	if st ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	if name == "NadeFrag" then throw("frag")
	elseif name == "NadeFlash" then throw("flash")
	elseif name == "NadeSmoke" then throw("smoke")
	elseif name == "NadeMine" then
		local _, _, _, mn = stock()
		if canUse() and mn > 0 then mineRemote:FireServer(); S.throwStart = os.clock() end
	end
	return Enum.ContextActionResult.Sink
end
ContextActionService:BindAction("NadeFrag", onAction, true, Enum.KeyCode.G, Enum.KeyCode.ButtonL1)
ContextActionService:BindAction("NadeFlash", onAction, false, Enum.KeyCode.F)
ContextActionService:BindAction("NadeSmoke", onAction, false, Enum.KeyCode.H)
ContextActionService:BindAction("NadeMine", onAction, false, Enum.KeyCode.X)
ContextActionService:SetTitle("NadeFrag", "GRENADE")
ContextActionService:SetPosition("NadeFrag", UDim2.new(1, -208, 1, -224))

-- ---------- grenades en vol (affichage) ----------
type Vis = { n: G.Nade, model: Model, rot: CFrame, mine: boolean }
local flying: { [number]: Vis } = {}
local shake = 0

local function emitBurst(pos: Vector3, color: Color3, n: number, speed: number, size: number, life: number)
	local a = Instance.new("Attachment"); a.WorldPosition = pos; a.Parent = workspace.Terrain
	local pe = Instance.new("ParticleEmitter"); pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"; pe.Color = ColorSequence.new(color)
	pe.LightEmission = 1; pe.Size = NumberSequence.new(size, 0); pe.Speed = NumberRange.new(speed * .3, speed); pe.SpreadAngle = Vector2.new(180, 180)
	pe.Lifetime = NumberRange.new(life * .5, life); pe.Rate = 0; pe.Parent = a
	pe:Emit(n)
	Debris:AddItem(a, life + .5)
end
local function lightBurst(pos: Vector3, color: Color3, brightness: number, range: number, t: number)
	local a = Instance.new("Attachment"); a.WorldPosition = pos; a.Parent = workspace.Terrain
	local l = Instance.new("PointLight"); l.Color = color; l.Brightness = brightness; l.Range = range; l.Shadows = false; l.Parent = a
	TweenService:Create(l, TweenInfo.new(t), { Brightness = 0 }):Play()
	Debris:AddItem(a, t + .1)
end
local function explosionFx(pos: Vector3, scale: number)
	local ex = Instance.new("Explosion"); ex.Position = pos; ex.BlastRadius = 0; ex.BlastPressure = 0; ex.DestroyJointRadiusPercent = 0
	ex.ExplosionType = Enum.ExplosionType.NoCraters; ex.Visible = true; ex.Parent = workspace
	emitBurst(pos + Vector3.new(0, .3 * M, 0), rgb(0xffa040), math.floor(30 * scale), 30 * scale, .8 * M * scale, .6)
	lightBurst(pos + Vector3.new(0, M, 0), rgb(0xffa050), 8, 30 * scale, .35)
	ShotFx.explosion(pos, scale)                       -- boule de feu, fumée sombre et débris du web
	-- anneau au sol (boomRings du web)
	local ring = Instance.new("Part"); ring.Shape = Enum.PartType.Cylinder; ring.Anchored = true; ring.CanCollide = false; ring.CanQuery = false; ring.CanTouch = false
	ring.Material = Enum.Material.Neon; ring.Color = rgb(0xffd9a0); ring.Transparency = .3; ring.Size = Vector3.new(.05, 1, 1)
	ring.CFrame = CFrame.new(pos + Vector3.new(0, .15 * M, 0)) * CFrame.Angles(0, 0, math.rad(90)); ring.Parent = folder
	local d = 9 * scale * M * 2
	TweenService:Create(ring, TweenInfo.new(.6, Enum.EasingStyle.Quad), { Size = Vector3.new(.05, d, d), Transparency = 1 }):Play()
	Debris:AddItem(ring, .65)
	local me = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if me then
		local dist = Vector3.new(me.Position.X - pos.X, 0, me.Position.Z - pos.Z).Magnitude / M
		if dist < 14 then shake = math.max(shake, .7 * (1 - dist / 14)) end
	end
end
-- nuage de fumée du web : 3,6 m de rayon, émis 3,2 s, particules de 13 à 17 s, gris clair
local function smokeFx(pos: Vector3)
	local cloud = Instance.new("Part"); cloud.Anchored = true; cloud.CanCollide = false; cloud.CanQuery = false; cloud.CanTouch = false
	cloud.Transparency = 1; cloud.Size = Vector3.one * G.SMOKE_R * 2 * .85 * M; cloud.Position = pos + Vector3.new(0, .5 * M, 0); cloud.Parent = folder
	local pe = Instance.new("ParticleEmitter"); pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
	pe.Shape = Enum.ParticleEmitterShape.Sphere; pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	pe.Rate = 60; pe.Lifetime = NumberRange.new(13, 17); pe.Speed = NumberRange.new(.1, .9); pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6 * M), NumberSequenceKeypoint.new(.15, 3.2 * M), NumberSequenceKeypoint.new(1, 3.8 * M) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(.06, .38), NumberSequenceKeypoint.new(.8, .45), NumberSequenceKeypoint.new(1, 1) })
	pe.Color = ColorSequence.new(Color3.new(.78, .8, .82)); pe.RotSpeed = NumberRange.new(-10, 10); pe.Rotation = NumberRange.new(0, 360)
	pe.Parent = cloud
	task.delay(3.2, function() pe.Enabled = false end)
	Debris:AddItem(cloud, G.SMOKE_T + 1)
end

local function removeVis(id: number)
	local v = flying[id]
	if v then v.model:Destroy(); flying[id] = nil end
end

fxRemote.OnClientEvent:Connect(function(e: any)
	if typeof(e) ~= "table" then return end
	if e.op == "throw" then
		local model = G.mesh(e.kind)
		model.Parent = folder
		local n: G.Nade = { id = e.id, kind = e.kind, p = e.p, v = e.v, t = e.t, owner = e.owner, team = e.team }
		flying[e.id] = { n = n, model = model, rot = CFrame.identity, mine = e.owner == player.Character }
		if e.owner ~= player.Character then Sfx.play(G.SFX.throw, e.p, .6) end
	elseif e.op == "boom" then
		local v = flying[e.id]
		local pos = e.p :: Vector3
		removeVis(e.id)
		if e.kind == "frag" then Sfx.play(G.SFX.boom, pos, .8); explosionFx(pos, .75)
		elseif e.kind == "flash" then
			Sfx.play(G.SFX.bang, pos, 1)
			emitBurst(pos + Vector3.new(0, .3 * M, 0), Color3.new(1, 1, .9), 10, 3 * M, .5 * M, .3)
			lightBurst(pos + Vector3.new(0, .5 * M, 0), Color3.new(1, 1, 1), 20, 40, .25)
		else Sfx.play(G.SFX.smoke, pos, .9); Sfx.play(G.SFX.pop, pos, .8); smokeFx(pos) end
		local _ = v
	elseif e.op == "mine" then
		Sfx.play(G.SFX.click, e.p, .7)
	elseif e.op == "mineOff" then
		if e.boom then Sfx.play(G.SFX.boom, e.p, .7); explosionFx(e.p, .55)
		else Sfx.play(G.SFX.click, e.p, .8); emitBurst(e.p + Vector3.new(0, .1 * M, 0), rgb(0xffd080), 8, 2 * M, .1 * M, .3) end
	end
end)

-- ---------- aveuglement (flash) + sifflement ----------
local blindT = 0
local ring = Instance.new("Sound"); ring.SoundId = "rbxasset://sounds/electronicpingshort.wav"; ring.Looped = true; ring.PlaybackSpeed = 2.6
ring.Volume = 0; ring.Parent = gui
flashRemote.OnClientEvent:Connect(function(dur: any)
	if typeof(dur) ~= "number" then return end
	blindT = math.max(blindT, dur)
	white.BackgroundTransparency = 0
	ring.Volume = .25; if not ring.IsPlaying then ring:Play() end
	TweenService:Create(ring, TweenInfo.new(math.min(5, dur * 1.6)), { Volume = 0 }):Play()
end)

-- ---------- alerte grenade ----------
type Warn = { root: Frame, icon: TextLabel, stroke: UIStroke, arrow: Frame }
local warns: { Warn } = {}
local function newWarn(): Warn
	local root = Instance.new("Frame"); root.AnchorPoint = Vector2.new(.5, .5); root.Size = UDim2.fromOffset(44, 44); root.BackgroundTransparency = 1
	root.Position = UDim2.fromScale(.5, .5); root.ZIndex = 6; root.Parent = gui
	local icon = Instance.new("TextLabel"); icon.Size = UDim2.fromScale(1, 1); icon.BackgroundColor3 = Color3.new(); icon.BackgroundTransparency = .35
	icon.Text = "💣"; icon.TextSize = 21; icon.Font = Enum.Font.GothamBold; icon.TextColor3 = Color3.new(1, 1, 1); icon.ZIndex = 6; icon.Parent = root
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = icon
	local st = Instance.new("UIStroke"); st.Thickness = 2; st.Color = rgb(0xffb23a); st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st.Parent = icon
	-- flèche (triangle) qui tourne autour de l'icône vers la grenade
	local pivot = Instance.new("Frame"); pivot.AnchorPoint = Vector2.new(.5, .5); pivot.Position = UDim2.fromScale(.5, .5); pivot.Size = UDim2.fromOffset(0, 0)
	pivot.BackgroundTransparency = 1; pivot.ZIndex = 6; pivot.Parent = root
	local arrow = Instance.new("ImageLabel"); arrow.AnchorPoint = Vector2.new(.5, 1); arrow.Position = UDim2.fromOffset(0, -24); arrow.Size = UDim2.fromOffset(14, 10)
	arrow.BackgroundTransparency = 1; arrow.Image = "rbxasset://textures/ui/Controls/DesignSystem/ArrowUp.png"; arrow.ImageColor3 = rgb(0xffb23a); arrow.ZIndex = 6
	arrow.Parent = pivot
	return { root = root, icon = icon, stroke = st, arrow = pivot }
end

local params = G.params({})
RunService.RenderStepped:Connect(function(dt: number)
	local t = os.clock()
	-- trajectoires
	local chars: { Instance } = { folder, camera }
	for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(chars, p.Character) end end
	params.FilterDescendantsInstances = chars
	for id, v in pairs(flying) do
		local n = v.n
		if n.t > 0 then
			if G.step(n, math.min(dt, 1 / 20), params) then Sfx.play(G.SFX.click, n.p, .4) end
			if n.v.Magnitude > 1 then v.rot *= CFrame.Angles(dt * 8, 0, dt * 5) end
		elseif n.t < -1 then removeVis(id) continue           -- explosion jamais reçue : on nettoie
		else n.t -= dt end
		v.model:PivotTo(CFrame.new(n.p) * v.rot)
	end
	-- voile blanc
	if blindT > 0 then
		blindT -= dt
		white.BackgroundTransparency = 1 - math.min(1, math.max(0, blindT) * 1.3)
	end
	-- alerte grenade : frag des autres, à moins de 9,5 m (et moins de 4 m de hauteur)
	local list = {}
	local me = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if me and canUse() then
		for _, v in pairs(flying) do
			local n = v.n
			if n.kind == "frag" and not v.mine then
				local dx, dz = (n.p.X - me.Position.X) / M, (n.p.Z - me.Position.Z) / M
				local d = math.sqrt(dx * dx + dz * dz)
				if d <= G.WARN_R and math.abs(n.p.Y - me.Position.Y) / M <= 4 then table.insert(list, { n = n, dx = dx, dz = dz, d = d }) end
			end
		end
	end
	while #warns < #list do table.insert(warns, newWarn()) end
	local look = camera.CFrame.LookVector
	local fwdV = Vector3.new(look.X, 0, look.Z)
	fwdV = if fwdV.Magnitude > 1e-3 then fwdV.Unit else Vector3.new(0, 0, -1)
	local rgtV = Vector3.new(-fwdV.Z, 0, fwdV.X)
	for i, w in ipairs(warns) do
		local it = list[i]
		if not it then w.root.Visible = false; continue end
		local fwd = it.dx * fwdV.X + it.dz * fwdV.Z
		local rgt = it.dx * rgtV.X + it.dz * rgtV.Z
		local L = math.max(1e-3, math.sqrt(fwd * fwd + rgt * rgt))
		local R = if it.d < 1.2 then 0 else 118
		w.root.Visible = true
		w.root.Position = UDim2.new(.5, rgt / L * R, .5, -fwd / L * R)
		local near = it.d < 5
		local col = if near then rgb(0xff4655) else rgb(0xffb23a)
		w.stroke.Color = col; (w.arrow:FindFirstChildOfClass("ImageLabel") :: ImageLabel).ImageColor3 = col
		local alpha = .55 + .45 * math.abs(math.sin(t * (if it.n.t < 1 then 18 else 9)))
		w.icon.TextTransparency = 1 - alpha; w.icon.BackgroundTransparency = 1 - alpha * .65; w.stroke.Transparency = 1 - alpha
		w.arrow.Rotation = math.deg(math.atan2(rgt, fwd)); w.arrow.Visible = R > 0
	end
end)

-- secousse de la caméra (G.shake du web), après la caméra Roblox
-- La caméra Roblox repart de la direction de l'image précédente : on n'ajoute que la différence avec la secousse
-- déjà posée (sinon les petits angles au hasard s'additionnaient et la visée restait décalée après l'explosion)
local shX, shY = 0, 0
RunService:BindToRenderStep("GrenadeShake", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	if S.kc ~= nil or camera.CameraType ~= Enum.CameraType.Custom then
		shX, shY = 0, 0; shake *= math.exp(-dt * 4)       -- une autre scène pose la caméra elle-même
		return
	end
	local nx, ny = 0, 0
	if shake > 0.001 then
		nx, ny = (math.random() - .5) * shake * .05, (math.random() - .5) * shake * .05
		shake *= math.exp(-dt * 4)
	end
	if nx ~= shX or ny ~= shY then camera.CFrame *= CFrame.Angles(nx - shX, ny - shY, 0) end
	shX, shY = nx, ny
end)

player.CharacterAdded:Connect(function() blindT = 0; white.BackgroundTransparency = 1; shake = 0 end)
