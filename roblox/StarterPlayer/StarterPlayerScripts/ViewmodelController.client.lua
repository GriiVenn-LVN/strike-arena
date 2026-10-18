--!strict
-- StarterPlayerScripts/ViewmodelController (LocalScript)
-- Bras + arme en vue à la première personne, repris du jeu web (src/55_vm.js, 55c_inspect.js) :
-- position hanche → visée, balancement de marche en « 8 », respiration, traînée de la souris, inclinaison en pas
-- de côté, atterrissage, recul sur ressort, sortie d'arme, sprint / sprint tactique / glissade / escalade,
-- recharge en phases (bascule, chargeur dehors qui tombe, chargeur neuf, claque, armement à vide),
-- inspection (touche V), coup de couteau, éclair de bouche, douilles, lunette des fusils de précision.
-- Les distances sont en mètres comme sur le web (1 m = 1 stud ici : tout est relatif à la caméra).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local WeaponModels = require(ReplicatedStorage.Shared.WeaponModels)
local SkinPaint = require(ReplicatedStorage.Shared.SkinPaint)
local S = require(ReplicatedStorage.Shared.ClientState)
local A = require(ReplicatedStorage.Shared.Attachments)
local ReticleGui = require(ReplicatedStorage.Shared.ReticleGui)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local VM_SCALE = 1.12                                   -- le web agrandit les modèles 3D de 12 % en vue subjective
local FOV_K = math.tan(math.rad(35)) / math.tan(math.rad(30))   -- le web dessine l'arme à 60° de champ, Roblox est à 70°
local STUDS_PER_M = Config.STUDS_PER_METER
local NO_MAG_SHOW = { p90 = true, m249 = true }         -- trop gros pour être montrés en inspection (comme sur le web)

local function clamp(x: number, a: number, b: number): number return math.max(a, math.min(b, x)) end
local function lerp(a: number, b: number, t: number): number return a + (b - a) * t end
local function smooth01(x: number): number x = clamp(x, 0, 1); return x * x * (3 - 2 * x) end

local Sfx = require(ReplicatedStorage.Shared.Sfx)
local function sfx(name: string, vol: number?) Sfx.play(name, nil, vol) end

-- ---------- rig : dossier sous la caméra ----------
local rig = Instance.new("Folder"); rig.Name = "Viewmodel"; rig.Parent = camera

local function part(name: string, size: Vector3, color: Color3, mat: Enum.Material?): Part
	local p = Instance.new("Part"); p.Name = name; p.Size = size; p.Color = color; p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false; p.Parent = rig
	return p
end

local GLOVE = Color3.fromRGB(34, 36, 40)
local arms = {
	uR = part("UpperR", Vector3.new(0.1, 0.1, 0.34), Color3.new()), fR = part("ForeR", Vector3.new(0.085, 0.085, 0.3), Color3.new()),
	uL = part("UpperL", Vector3.new(0.1, 0.1, 0.34), Color3.new()), fL = part("ForeL", Vector3.new(0.085, 0.085, 0.3), Color3.new()),
	cR = part("CuffR", Vector3.new(0.095, 0.095, 0.05), Color3.fromRGB(45, 48, 40)), cL = part("CuffL", Vector3.new(0.095, 0.095, 0.05), Color3.fromRGB(45, 48, 40)),
	hR = part("HandR", Vector3.new(0.075, 0.09, 0.11), GLOVE), hL = part("HandL", Vector3.new(0.075, 0.09, 0.11), GLOVE),
}
for _, k in ipairs({ "uR", "fR", "uL", "fL" }) do
	local m = Instance.new("SpecialMesh"); m.MeshType = Enum.MeshType.Cylinder; m.Parent = arms[k]
end
for _, k in ipairs({ "hR", "hL" }) do
	local c = Instance.new("SpecialMesh"); c.MeshType = Enum.MeshType.Brick; c.Parent = arms[k]
end
local flash = part("Flash", Vector3.new(0.12, 0.12, 0.12), Color3.fromRGB(255, 214, 140), Enum.Material.Neon)
flash.Shape = Enum.PartType.Ball
local flashLight = Instance.new("PointLight"); flashLight.Color = Color3.fromRGB(255, 200, 120); flashLight.Range = 12; flashLight.Brightness = 0; flashLight.Parent = flash

-- lunette (fusils de précision en visée)
local scopeGui = Instance.new("ScreenGui"); scopeGui.Name = "Scope"; scopeGui.IgnoreGuiInset = true; scopeGui.ResetOnSpawn = false
scopeGui.DisplayOrder = 5; scopeGui.Enabled = false; scopeGui.Parent = player:WaitForChild("PlayerGui")
do
	local ring = Instance.new("Frame"); ring.AnchorPoint = Vector2.new(0.5, 0.5); ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(0.9, 0.9); ring.BackgroundTransparency = 1; ring.Parent = scopeGui
	local ar = Instance.new("UIAspectRatioConstraint"); ar.Parent = ring
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0.5, 0); corner.Parent = ring
	local stroke = Instance.new("UIStroke"); stroke.Thickness = 2000; stroke.Color = Color3.new(); stroke.Parent = ring
end
-- réticule de la lunette : forme + couleur choisies dans Arsenal › Viseurs (scopeRetUpdate du web)
local scopeRet = Instance.new("Frame"); scopeRet.Name = "Ret"; scopeRet.Size = UDim2.fromScale(1, 1); scopeRet.BackgroundTransparency = 1
scopeRet.Parent = scopeGui
local scopeKey = ""
local function scopeRetUpdate(optic: string?)
	local o = optic or "scope"
	local sh, col = A.retOf(o, player)
	local vs = camera.ViewportSize
	local k = sh .. col .. vs.X .. "x" .. vs.Y
	if k == scopeKey then return end
	scopeKey = k
	for _, c in ipairs(scopeRet:GetChildren()) do c:Destroy() end
	ReticleGui.draw(scopeRet, vs.X / 2, vs.Y / 2, vs.Y * .335, sh, col, true)
end

-- ---------- état ----------
local VM = {
	key = nil :: string?, model = nil :: Model?, magParts = {} :: { BasePart }, magC = Vector3.zero, magDir = Vector3.new(0.18, -1, 0).Unit,
	left = Vector3.zero, twoHand = true, sightY = 0.06, muzzle = Vector3.zero, hasMag = false, hasBolt = false, pistol = false,
	kick = 0, kv = 0, sx = 0, sy = 0, sxv = 0, syv = 0, land = 0, lv = 0, strafe = 0, bph = 0, ads = 0,
	spr = 0, tac = 0, sld = 0, mnt = 0,
	drawT = 0, drawMax = 0.35, flashT = 0, swingT = 0, boltT = 0, pumpT = 0,
	relKey = 0, relSnd = 0, relDrop = false, relEmpty = false, inspSnd = 0,
	sig = "", att = {} :: { string }, mods = A.neutral(), noFlash = false,
	lastLook = Vector3.new(0, 0, -1), prevGround = true, airVy = 0,
}

-- skin de l'arme en main : le nôtre, ou celui du tueur pendant la kill-cam
local function applySkin()
	if not VM.model or not VM.key then return end
	if S.kc then SkinPaint.apply(VM.model, S.kc.skin, S.kc.camo) return end
	SkinPaint.apply(VM.model, player:GetAttribute("Skin_" .. VM.key) :: number?, player:GetAttribute("Camo_" .. VM.key) :: string?)
end
player.AttributeChanged:Connect(function(name: string)
	if VM.key and (name == "Skin_" .. VM.key or name == "Camo_" .. VM.key) then applySkin() end
end)
S.onSkin = applySkin

-- la fabrication d'une arme attend Roblox (CreateMeshPartAsync) : elle se fait hors de la boucle d'affichage
-- signature : arme + accessoires de l'armurier + réticules (une nouvelle combinaison reconstruit l'arme en main)
local function sigOf(key: string): string
	if S.kc then return key end
	local s = key .. "|" .. tostring(player:GetAttribute("Att_" .. key))
	for o in pairs(A.RET_DEF) do s ..= tostring(player:GetAttribute("Ret_" .. o)) end
	return s
end
local building: string? = nil
local function setGun(key: string)
	local sig = sigOf(key)
	if building == sig then return end
	building = sig
	local att = if S.kc then {} else A.activeOf(player, key)
	local ok, m = pcall(WeaponModels.build, key, VM_SCALE, att, { ret = function(o: string) return A.retOf(o, player) end })
	if building ~= sig then if ok and m then (m :: Model):Destroy() end return end   -- une autre arme a été demandée entre-temps
	building = nil
	if not ok then warn("[Viewmodel]", m) return end
	if VM.model then VM.model:Destroy() end
	local model = m :: Model
	for _, c in ipairs(model:GetChildren()) do if c:IsA("BasePart") then c.CastShadow = false end end
	model.Parent = rig
	VM.model = model; VM.key = key; VM.sig = sig
	VM.att = att; VM.mods = A.modsOf(att); VM.noFlash = model:GetAttribute("NoFlash") == true
	applySkin()
	local w = Config.WEAPONS[key]
	VM.pistol = w.cat == "pistol"
	VM.twoHand = not w.melee
	VM.sightY = (model:GetAttribute("SightY") :: number?) or 0.06
	local grip = model.PrimaryPart :: BasePart
	local la = grip:FindFirstChild("LeftHand") :: Attachment?
	VM.left = if la then la.Position else Vector3.zero
	if VM.pistol or VM.left.Magnitude < 0.01 then VM.left = Vector3.new(-0.01, -0.035, 0.005) end   -- pistolet : main gauche sous la droite
	local mz = grip:FindFirstChild("Muzzle") :: Attachment?
	VM.muzzle = if mz then mz.Position else Vector3.new(0, 0.03, -0.4)
	VM.magParts = {}; VM.hasBolt = false
	local sum, n = Vector3.zero, 0
	for _, c in ipairs(model:GetChildren()) do
		if c:IsA("BasePart") then
			if c:GetAttribute("Piece") == "mag" then
				table.insert(VM.magParts, c)
				local off = c:GetAttribute("Offset")
				if typeof(off) == "CFrame" then sum += off.Position; n += 1 end
			elseif c:GetAttribute("Piece") == "bolt" then VM.hasBolt = true end
		end
	end
	VM.hasMag = n > 0
	VM.magC = if n > 0 then sum / n else Vector3.new(0, -0.08, -0.05)
	VM.magDir = if key == "p90" then Vector3.new(0, 0.55, 0.85).Unit else Vector3.new(0.18, -1, 0).Unit
	VM.drawMax = if w.melee then 0.3 elseif VM.pistol then 0.35 else 0.5
	VM.drawT = VM.drawMax
end

-- ---------- événements ----------
S.onDraw:Connect(function(key: string)
	if key ~= VM.key then task.spawn(setGun, key) else VM.drawT = VM.drawMax end
	sfx("draw", 0.6)
end)
S.onShot:Connect(function(key: string)
	local w = Config.WEAPONS[key]
	if not w then return end
	if w.melee then VM.swingT = 0.38; sfx("knife", 0.5); return end
	VM.kv += (if w.cat == "sniper" or w.cat == "shotgun" then 22 elseif w.cat == "pistol" then 14 else 12) * (1 - 0.45 * VM.ads)
	VM.flashT = 0.05
	if w.cat == "sniper" and not w.auto then VM.boltT = 0.8; task.delay(0.38, sfx, "bolt", 0.6) end
	if w.cat == "shotgun" and not w.auto then VM.pumpT = 0.6; task.delay(0.3, sfx, "pump", 0.6) end
	-- douille éjectée à droite
	if VM.model and w.cat ~= "shotgun" then
		local grip = VM.model.PrimaryPart :: BasePart
		local shell = Instance.new("Part"); shell.Size = Vector3.new(0.012, 0.012, 0.035)   -- en mètres, comme tout le viewmodel
		shell.Color = Color3.fromRGB(200, 160, 70); shell.Material = Enum.Material.Metal
		shell.CanCollide = false; shell.CanQuery = false; shell.CanTouch = false; shell.CastShadow = false
		shell.CFrame = grip.CFrame * CFrame.new(0.03, 0.04, -0.05)
		shell.Parent = workspace
		shell.AssemblyLinearVelocity = grip.CFrame:VectorToWorldSpace(Vector3.new(5 + math.random() * 2, 4 + math.random() * 2, 1))
		shell.AssemblyAngularVelocity = Vector3.new(math.random() * 20, math.random() * 20, math.random() * 20)
		Debris:AddItem(shell, 1.2)
	end
end)
S.onReload:Connect(function(_key: string, empty: boolean)
	VM.relSnd = 0; VM.relDrop = false; VM.relEmpty = empty
	if not VM.hasMag then sfx("reload", 0.8) end
end)

-- chargeur vide qui tombe (copie des pièces, lâchée avec la gravité)
local function dropMag()
	if not VM.model then return end
	local grip = VM.model.PrimaryPart :: BasePart
	for _, p in ipairs(VM.magParts) do
		local c = p:Clone(); c.Anchored = false; c.CanCollide = false; c.Parent = workspace
		c.AssemblyLinearVelocity = grip.CFrame:VectorToWorldSpace(VM.magDir * 4 + Vector3.new(-0.6, 0, 0))
		c.AssemblyAngularVelocity = Vector3.new(math.random() * 6 - 3, math.random() * 4 - 2, 4 + math.random() * 3)
		Debris:AddItem(c, 1.2)
	end
end

-- ---------- inspection (clés du web : [instant, px, py, pz, rx, ry, rz]) ----------
local TAU = math.pi * 2
local INSK = {
	mag = { { 0, 0, 0, 0, 0, 0, 0 }, { .08, -.03, .03, -.02, .2, 1.05, .45 }, { .22, -.045, .035, -.03, .26, 1.32, .52 }, { .31, .015, .02, -.02, .1, -.5, -.55 },
		{ .39, -.01, 0, -.02, .15, .38, .32 }, { .78, -.01, -.02, 0, .1, .3, .26 }, { .83, -.01, -.012, 0, .02, .26, .2 }, { .9, -.01, 0, 0, .06, .2, .12 }, { 1, 0, 0, 0, 0, 0, 0 } },
	plain = { { 0, 0, 0, 0, 0, 0, 0 }, { .12, -.03, .03, -.03, .22, 1.1, .45 }, { .4, -.05, .04, -.04, .28, 1.35, .55 }, { .55, .02, .02, -.02, .1, -.5, -.6 },
		{ .8, .01, .02, -.02, .15, -.62, -.5 }, { 1, 0, 0, 0, 0, 0, 0 } },
	knife = { { 0, 0, 0, 0, 0, 0, 0 }, { .12, -.06, .06, -.04, .3, .2, .2 }, { .5, -.08, .07, -.05, .3, .3, .2 + TAU * 2 }, { .72, -.08, .06, -.06, .2, 1.3, .3 + TAU * 2 },
		{ .88, -.06, .05, -.05, .25, -.4, TAU * 2 - .3 }, { 1, 0, 0, 0, 0, 0, TAU * 2 } },
}
local INSD = { mag = 4.4, plain = 3, knife = 2.2 }

local function inspectKind(): string
	local w = VM.key and Config.WEAPONS[VM.key]
	if w and w.melee then return "knife" end
	return if VM.hasMag and not NO_MAG_SHOW[VM.key or ""] then "mag" else "plain"
end

-- ---------- IK des bras (épaule → coude → poignet), comme place() du web ----------
local function seg(p: BasePart, a: Vector3, b: Vector3, thick: number)
	local d = b - a
	local L = math.max(d.Magnitude, 1e-3)
	p.Size = Vector3.new(L, thick, thick)        -- cylindre : axe X
	p.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
end
local function placeArm(up: BasePart, fore: BasePart, cuff: BasePart, hand: Vector3, sx: number, ads: number, camCF: CFrame)
	local sh = Vector3.new(sx * (0.3 - 0.06 * ads), -0.5 - 0.14 * ads, -0.05)
	local LU, LF = 0.34, 0.3
	local d0 = (hand - sh).Magnitude
	local k = math.max(1, d0 / (LU + LF - 0.01))
	local lu, lf, d = LU * k, LF * k, math.max(d0, 1e-4)
	local dir = (hand - sh) / d
	local a = (lu * lu - lf * lf + d * d) / (2 * d)
	local h = math.sqrt(math.max(0, lu * lu - a * a))
	local pole = Vector3.new(sx * 0.8, -1, 0.2)
	pole = (pole - dir * pole:Dot(dir)).Unit
	local el = sh + dir * a + pole * h
	local function w(v: Vector3): Vector3 return camCF:PointToWorldSpace(v) end
	seg(up, w(sh), w(el), 0.1)
	seg(fore, w(el), w(hand), 0.085)
	cuff.CFrame = CFrame.lookAt(w(el:Lerp(hand, 0.9)), w(hand))
end

local function setVisible(on: boolean)
	for _, c in ipairs(rig:GetDescendants()) do
		if c:IsA("BasePart") then c.LocalTransparencyModifier = if on then 0 else 1 end
	end
end

-- ---------- boucle ----------
RunService:BindToRenderStep("Viewmodel", Enum.RenderPriority.Camera.Value + 2, function(dt: number)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local kc = S.kc                         -- kill-cam : l'arme du tueur, dans ses mains (KillcamController)
	local key = if kc then kc.key else S.weapon
	local alive = if kc then key ~= nil else hum ~= nil and hum.Health > 0 and key ~= nil and camera.CameraType == Enum.CameraType.Custom
	if not alive or not key then setVisible(false); scopeGui.Enabled = false; S.muzzle = nil; return end
	if not kc and os.clock() < S.drinkHideUntil then setVisible(false); scopeGui.Enabled = false; S.muzzle = nil; return end   -- boisson d'atout : arme rangée
	if key ~= VM.key then
		if building ~= sigOf(key) then task.spawn(setGun, key) end
		setVisible(false); return
	end
	if VM.sig ~= sigOf(key) and building ~= sigOf(key) then task.spawn(setGun, key) end   -- accessoires changés : on garde l'ancienne le temps de reconstruire
	local model = VM.model
	if not model then return end
	local w = Config.WEAPONS[key]
	local t = os.clock()

	-- visée (lissée), poids des postures de déplacement
	-- vitesse de visée du web : ×7 à la lunette, ×12 sinon, multipliée par les accessoires (mods.ads)
	VM.ads += ((if S.aiming and not w.melee then 1 else 0) - VM.ads) * math.min(1, dt * (if A.sightOv(key, VM.att) then 7 else 12) * VM.mods.ads)
	S.adsT = VM.ads
	local ads = VM.ads
	local function follow(cur: number, on: boolean): number return cur + ((if on then 1 else 0) - cur) * math.min(1, dt * 12) end
	VM.spr = follow(VM.spr, S.sprint and not S.tactical); VM.tac = follow(VM.tac, S.tactical)
	VM.sld = follow(VM.sld, S.slide); VM.mnt = follow(VM.mnt, S.mantle)

	-- ressorts : recul, traînée de la souris, atterrissage, pas de côté
	local sd = math.min(dt, 0.033)
	VM.kv += (-VM.kick * 300 - VM.kv * 26) * sd; VM.kick = clamp(VM.kick + VM.kv * sd, -0.3, 1.4)
	VM.flashT = math.max(0, VM.flashT - dt); VM.drawT = math.max(0, VM.drawT - dt); VM.swingT = math.max(0, VM.swingT - dt)
	VM.boltT = math.max(0, VM.boltT - dt); VM.pumpT = math.max(0, VM.pumpT - dt)
	local spdMs = S.speed / STUDS_PER_M
	local spd = clamp(spdMs / 5.2, 0, 1.3)
	VM.bph += dt * spdMs * 1.7
	local look = camera.CFrame.LookVector
	local yaw0 = math.atan2(-VM.lastLook.X, -VM.lastLook.Z); local yaw1 = math.atan2(-look.X, -look.Z)
	local dyaw = (yaw1 - yaw0 + math.pi) % TAU - math.pi
	local dp = math.asin(clamp(look.Y, -1, 1)) - math.asin(clamp(VM.lastLook.Y, -1, 1))
	VM.lastLook = look
	local id = 1 / math.max(dt, 1e-3)
	local tx, ty = clamp(dyaw * id * 0.016, -0.07, 0.07), clamp(-dp * id * 0.016, -0.055, 0.055)
	VM.sxv += ((tx - VM.sx) * 150 - VM.sxv * 17) * sd; VM.sx += VM.sxv * sd
	VM.syv += ((ty - VM.sy) * 150 - VM.syv * 17) * sd; VM.sy += VM.syv * sd
	local vyMs = S.vy / STUDS_PER_M
	if S.grounded and not VM.prevGround and VM.airVy < -2 then VM.lv -= math.min(2.2, -VM.airVy * 0.22); sfx("land", 0.6) end
	VM.airVy = if S.grounded then 0 else vyMs; VM.prevGround = S.grounded
	VM.lv += (-VM.land * 220 - VM.lv * 19) * sd; VM.land += VM.lv * sd
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and not kc then
		local lat = camera.CFrame.RightVector:Dot(root.AssemblyLinearVelocity) / STUDS_PER_M
		VM.strafe += (clamp(lat / 5, -1, 1) - VM.strafe) * (1 - math.exp(-dt * 8))
	end

	-- marche en « 8 » + respiration
	local bobk = 1 - ads * 0.88
	local ph = VM.bph
	local bx, by, br = math.sin(ph) * 0.009 * spd * bobk, (math.sin(ph * 2) * 0.5 - 0.25) * 0.012 * spd * bobk, math.sin(ph) * 0.018 * spd * bobk
	local idle = (1 - clamp(spd, 0, 1)) * (1 - ads * 0.8)
	local brY, brX = math.sin(t * 1.7) * 0.0028 * idle, math.sin(t * 0.9) * 0.0018 * idle

	-- position de base : hanche (ramenée pour un champ de 60° comme le web) → visée (exacte)
	local adsZ = -0.46
	local px = lerp(0.19 / FOV_K, 0, ads)
	local py = lerp(-0.162 / FOV_K, -VM.sightY, ads)
	local pz = lerp(-0.47 / FOV_K, adsZ, ads)
	local rx, ry, rz = 0.02 * (1 - ads), 0.06 * (1 - ads), -0.05 * (1 - ads)
	local sw = 1 - ads * 0.75
	px += bx + brX + VM.sx * sw; py += by + brY + VM.sy * sw + (if S.crouch then 0.015 * (1 - ads) else 0)
	ry += VM.sx * 1.6 * sw; rx += VM.sy * 1.2 * sw; rz += br - VM.sx * 1.2 * sw - VM.strafe * 0.06 * (1 - ads * 0.7)
	if not S.grounded then local a = clamp(-vyMs * 0.005, -0.035, 0.03); py += a * (1 - ads * 0.6); rx -= a * 1.5 end
	py += VM.land * 0.1; rx += VM.land * 0.35
	-- recul
	local kk = VM.kick
	pz += kk * 0.055; rx += kk * 0.09; rz += math.sin(t * 47) * math.max(0, kk) * 0.012; py += kk * 0.01
	-- sortie de l'arme : elle remonte du bas de l'écran
	if VM.drawT > 0 then
		local d = smooth01(VM.drawT / VM.drawMax)
		py -= d * 0.25; rx -= d * 0.7; rz += d * 0.3
	end
	-- lancer de grenade / pose de mine (vmThrow du web)
	local thr = t - S.throwStart
	if thr >= 0 and thr < 0.7 then local a = math.sin(thr / 0.7 * math.pi); py -= a * .32; rx -= a * .4 end
	-- couteau
	if VM.swingT > 0 then
		local a = 1 - VM.swingT / 0.38
		local s = math.sin(a * math.pi)
		rz += s * 1.1; ry += s * 0.7; px -= s * 0.18; rx -= s * 0.5; pz -= s * 0.06
	end
	-- inspection
	local ins: any = nil
	if S.inspectStart > 0 then
		if ads > 0.3 or S.reloading then S.inspectStart = -1; VM.inspSnd = 0
		else
			local kind = inspectKind()
			local a = (t - S.inspectStart) / INSD[kind]
			if a >= 1 then S.inspectStart = -1; VM.inspSnd = 0
			else
				local K = INSK[kind]
				local i = 1
				while i < #K - 1 and a > K[i + 1][1] do i += 1 end
				local A, B = K[i], K[i + 1]
				local f = smooth01((a - A[1]) / (B[1] - A[1]))
				local v = table.create(6)
				for j = 1, 6 do v[j] = A[j + 1] + (B[j + 1] - A[j + 1]) * f end
				px += v[1]; py += v[2]; pz += v[3]; rx += v[4] + math.sin(a * 23) * 0.006; ry += v[5]; rz += v[6] + math.sin(a * 17 + 1) * 0.008
				ins = { a = a, kind = kind, lh = 0, out = 0, hold = 0, tilt = 0 }
				if kind == "mag" then
					local function sg(x0: number, x1: number): number return smooth01((a - x0) / (x1 - x0)) end
					ins.lh = sg(0.36, 0.42) * (1 - sg(0.82, 0.9))
					ins.out = sg(0.42, 0.48) * (1 - sg(0.76, 0.8))
					ins.hold = sg(0.47, 0.56) * (1 - sg(0.69, 0.77))
					ins.tilt = math.sin(clamp((a - 0.56) / 0.13, 0, 1) * math.pi) * 0.35
					if a > 0.79 and a < 0.84 then py += -0.012 * math.sin((a - 0.79) / 0.05 * math.pi) end
					local function snd(k: number, at: number, n: string, vol: number)
						if VM.inspSnd < k and a >= at then VM.inspSnd = k; sfx(n, vol) end
					end
					snd(1, 0.37, "magout", 0.35); snd(2, 0.43, "magout", 0.7); snd(3, 0.79, "magin", 0.85)
				elseif kind == "knife" and VM.inspSnd < 1 and a > 0.14 then VM.inspSnd = 1; sfx("knife", 0.3) end
			end
		end
	end
	-- sprint (arme en travers), sprint tactique (arme levée), glissade (inclinée), escalade (arme baissée)
	do
		local s, T, L, Mn = VM.spr * (1 - ads), VM.tac * (1 - ads), VM.sld, VM.mnt
		local sb = math.sin(VM.bph * 0.9)
		px += -s * 0.045 + s * sb * 0.014; py += -s * 0.05 + s * math.abs(sb) * 0.012; rx -= s * 0.3; ry += s * 0.62; rz += s * 0.38
		px += T * (0.1 + sb * 0.01); py += T * (-0.015 + math.abs(sb) * 0.015); rx += T * 0.8; rz -= T * 0.6; ry -= T * 0.12
		rz += L * 0.32; py -= L * 0.03; px -= L * 0.02; py -= Mn * 0.22; rx -= Mn * 0.7
	end
	-- rechargement en phases
	local rl = -1
	local leftOff = 0
	local reloadDur = w.reload * VM.mods.rel
	if S.reloading and reloadDur > 0 then
		rl = clamp((t - S.reloadStart) / reloadDur, 0, 1)
		local tilt = smooth01(rl / 0.16) * (1 - smooth01((rl - 0.84) / 0.16))
		local function bump(c: number, w2: number): number return math.exp(-((rl - c) / w2) ^ 2) end
		local slap, rack = bump(0.74, 0.035), if VM.relEmpty then bump(0.87, 0.04) else 0
		local mw = if VM.hasMag then tilt else 0
		rx += tilt * 0.12 + mw * 0.1 + slap * -0.08 + rack * 0.06
		rz += tilt * (if VM.hasMag then -0.42 else 0.48) + slap * 0.06
		ry -= tilt * 0.1 - mw * 0.22
		px -= tilt * 0.02 + mw * 0.07; py -= tilt * 0.055 - mw * 0.05 - slap * 0.014; pz += rack * 0.028 - tilt * 0.02
		leftOff = if VM.hasMag then tilt else 0
		local function snd(i: number, at: number, name: string)
			if VM.relSnd < i and rl >= at then VM.relSnd = i; sfx(name, 0.8) end
		end
		if VM.hasMag then
			snd(1, 0.28, "magout"); snd(2, 0.71, "magin")
			if VM.relEmpty and VM.hasBolt then snd(3, if VM.pistol then 0.84 else 0.85, "rack") end
		elseif w.cat == "shotgun" then
			local n = clamp(w.mag - S.mag, 1, 4)
			local aa = clamp((rl - 0.15) / 0.65, 0, 0.999)
			local i = math.floor(aa * n)
			local ph2 = aa * n % 1
			if rl > 0.15 and rl < 0.8 then
				leftOff = math.sin(ph2 * math.pi) * 0.6
				if VM.relSnd <= i and ph2 > 0.55 then VM.relSnd = i + 1; sfx("shellin", 0.7) end
			end
		end
	end

	local gunCF = CFrame.new(px, py, pz) * CFrame.fromEulerAnglesXYZ(rx, ry, rz)

	-- pièces mobiles : chargeur (recharge / inspection), culasse ou glissière
	local pieces: { [string]: CFrame } = {}
	local magVisible = true
	local magPos = VM.magC
	if VM.hasMag then
		local out, tw = 0, 0
		if rl >= 0 then
			if rl < 0.26 then out = 0
			elseif rl < 0.36 then out = smooth01((rl - 0.26) / 0.1)
			elseif rl < 0.46 then out = 1 + smooth01((rl - 0.36) / 0.1) * 1.4; magVisible = false
			elseif rl < 0.58 then out = 2.4 - smooth01((rl - 0.46) / 0.12) * 1.25; tw = 1 - smooth01((rl - 0.5) / 0.08)
			elseif rl < 0.72 then out = 1.15 * (1 - smooth01((rl - 0.58) / 0.14)) end
			if rl >= 0.36 and not VM.relDrop then VM.relDrop = true; dropMag() end
		end
		local off = VM.magDir * out * 0.2
		local rot = CFrame.fromEulerAnglesXYZ(tw * 0.5, 0, tw * 0.35)
		if ins and ins.kind == "mag" then
			-- inspection : chargeur sorti, amené devant les yeux et tourné pour voir les cartouches
			off += VM.magDir * ins.out * 0.12 + Vector3.new(-0.06, 0.2, 0.12) * ins.hold
			rot = CFrame.fromEulerAnglesXYZ(ins.hold * 0.4, ins.tilt, ins.hold * -0.5)
		end
		-- rotation autour du centre du chargeur
		pieces.mag = CFrame.new(off) * CFrame.new(VM.magC) * rot * CFrame.new(-VM.magC)
		magPos = VM.magC + off
	end
	if VM.hasBolt then
		local pull = 0
		if rl >= 0 and VM.relEmpty then
			pull = if rl < 0.82 then 0 elseif rl < 0.87 then smooth01((rl - 0.82) / 0.05) elseif rl < 0.895 then 1 - smooth01((rl - 0.87) / 0.025) else 0
		end
		if VM.pistol then
			local lockBack = (rl < 0 and S.mag <= 0) or (rl >= 0 and VM.relEmpty and rl < 0.84)
			pieces.bolt = CFrame.new(0, 0, math.max(kk * 0.03, if lockBack then 0.028 else 0))
		else
			local bt = math.max(if VM.boltT > 0 then math.sin((1 - VM.boltT / 0.8) * math.pi) else 0, pull, if w.auto then math.max(0, kk) * 0.4 else 0)
			pieces.bolt = CFrame.new(0, 0, bt * 0.06)
		end
	end

	-- lunette : en visée avec un fusil de précision, l'arme disparaît derrière l'oculaire
	local scoped = ads > 0.92 and not w.melee and A.sightOv(key, VM.att)
	scopeGui.Enabled = scoped
	if scoped then scopeRetUpdate(A.optOf(VM.att)) end
	setVisible(not scoped)

	-- placement dans le monde
	local camCF = camera.CFrame
	local world = camCF * gunCF
	WeaponModels.place(model, world, pieces)
	if not magVisible then for _, p in ipairs(VM.magParts) do p.LocalTransparencyModifier = 1 end end

	-- mains : droite sur la poignée, gauche sur le garde-main (va chercher le chargeur pendant la recharge)
	local rightL = gunCF:PointToWorldSpace(Vector3.new(0.005, -0.035, 0.02))
	local leftLocal = VM.left - Vector3.new(0, leftOff * 0.12, 0)
	if rl >= 0 and VM.hasMag then
		local k = if rl < 0.15 then rl / 0.15 elseif rl > 0.8 then (1 - rl) / 0.2 else 1
		leftLocal = leftLocal:Lerp(magPos - Vector3.new(0, 0.02, 0), smooth01(k))
	end
	if ins and ins.lh > 0 then leftLocal = leftLocal:Lerp(magPos, ins.lh) end
	local leftL = gunCF:PointToWorldSpace(leftLocal)
	local handRot = gunCF.Rotation
	arms.hR.CFrame = camCF * (CFrame.new(rightL) * handRot)
	-- poignée verticale : la main gauche se referme autour, paume tournée vers l'arrière
	local leftRot = if model:GetAttribute("LeftV") == true and rl < 0 then CFrame.Angles(math.rad(-75), 0, 0) else CFrame.identity
	arms.hL.CFrame = camCF * (CFrame.new(leftL) * handRot * leftRot)
	placeArm(arms.uR, arms.fR, arms.cR, rightL + handRot:VectorToWorldSpace(Vector3.new(0, 0, 0.05)), 1, ads, camCF)
	if VM.twoHand then
		placeArm(arms.uL, arms.fL, arms.cL, leftL + handRot:VectorToWorldSpace(Vector3.new(0, 0, 0.05)), -1, ads, camCF)
	else
		local hidden = camCF * CFrame.new(0, -3, 0)
		arms.uL.CFrame = hidden; arms.fL.CFrame = hidden; arms.cL.CFrame = hidden; arms.hL.CFrame = hidden
	end
	local myTeam = player:GetAttribute("Team")   -- manches aux couleurs de l'équipe de la partie (orange T, bleu CT), kaki sinon
	local sleeve = if myTeam == "Attaquants" then Color3.fromRGB(196, 110, 52) elseif myTeam == "Défenseurs" then Color3.fromRGB(58, 96, 168) else Color3.fromRGB(86, 96, 74)
	arms.uR.Color = sleeve; arms.fR.Color = sleeve; arms.uL.Color = sleeve; arms.fL.Color = sleeve

	-- éclair de bouche
	local muzzleW = world:PointToWorldSpace(VM.muzzle)
	S.muzzle = muzzleW
	flash.CFrame = CFrame.new(muzzleW)
	local on = VM.flashT > 0 and not w.melee and not VM.noFlash      -- silencieux / cache-flamme : pas de flamme
	flash.Size = Vector3.one * (0.08 + math.random() * 0.06)
	flashLight.Brightness = if on then 4 else 0
	flash.LocalTransparencyModifier = if on and not scoped then 0.1 else 1
end)
