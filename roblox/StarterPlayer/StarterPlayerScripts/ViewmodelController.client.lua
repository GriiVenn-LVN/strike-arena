--!strict
-- StarterPlayerScripts/ViewmodelController (LocalScript)
-- Bras + arme en vue à la première personne, repris du jeu web (src/55_vm.js, 55c_inspect.js) :
-- position hanche → visée, balancement de marche en « 8 », respiration, traînée de la souris, inclinaison en pas
-- de côté, atterrissage, recul sur ressort, sortie d'arme, sprint / sprint tactique / glissade / escalade,
-- recharge en phases (bascule, chargeur dehors qui tombe, chargeur neuf, claque, armement à vide),
-- inspection (touche V), coup de couteau, éclair de bouche, douilles, lunette des fusils de précision.
-- Aussi : sortie d'arme amortie avec figure des skins Épiques et plus (55c_inspect.js), main droite qui arme la culasse
-- à vide, chargeur vide qui tombe dans la vue, crosse masquée en visée, et la caméra du web (90_main.js placeCamera) :
-- balancement de tête, roulis en pas de côté et en glissade, plongeon à l'atterrissage, champ élargi en sprint.
-- Façon Call of Duty en plus : escalade avec la main gauche (ou les deux mains sur un rebord haut) posée sur le rebord,
-- arme baissée et caméra qui plonge vers l'avant ; recharge tactique (chargeur encore entamé rangé par la main gauche)
-- ou à vide (chargeur lâché qui tombe, puis armement) ; bras gauche qui balance en sprint tactique ; arme qui vibre en
-- glissade. Le balancement de tête et le plongeon d'atterrissage suivent le réglage « Secousses de l'écran ».
-- Les distances sont en mètres comme sur le web (1 m = 1 stud ici : tout est relatif à la caméra).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")

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

-- réglage d'accessibilité « Secousses de l'écran » (attribut Access, AccessibilityController) : 0 = tête immobile
local shakeK = 1
local function readShake()
	shakeK = 1
	local raw = player:GetAttribute("Access")
	if typeof(raw) ~= "string" then return end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
	if ok and typeof(data) == "table" and typeof(data.shake) == "number" then shakeK = clamp(data.shake, 0, 1) end
end
player:GetAttributeChangedSignal("Access"):Connect(readShake)
readShake()

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
-- hR / hL : simples repères invisibles, les gants modelés (ci-dessous) s'y accrochent
arms.hR.Transparency = 1; arms.hL.Transparency = 1
for _, k in ipairs({ "uR", "fR", "uL", "fL" }) do arms[k].Material = Enum.Material.Fabric end
arms.cR.Material = Enum.Material.Fabric; arms.cL.Material = Enum.Material.Fabric

-- ---------- gants tactiques modelés (src/55b_hands.js) ----------
-- paume arrondie, quatre doigts en trois phalanges enroulés autour de la poignée, pouce opposé,
-- coque des jointures, sangle de poignet ; la main gauche est le reflet de la droite.
type GPiece = { p: BasePart, at: CFrame, mat: string }
local function newGlove(): { GPiece }
	local list: { GPiece } = {}
	local function add(p: BasePart, at: CFrame, mat: string)
		p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false; p.Massless = true
		p.Material = if mat == "pad" then Enum.Material.SmoothPlastic else Enum.Material.Fabric
		p.Parent = rig
		table.insert(list, { p = p, at = at, mat = mat })
	end
	local function box(size: Vector3, pos: Vector3, ry: number, mat: string)
		local p = Instance.new("Part"); p.Name = "Gant"; p.Size = size
		add(p, CFrame.new(pos) * CFrame.Angles(0, ry, 0), mat)
	end
	-- capsule (cylindre + deux demi-sphères) de longueur totale L, axe = up
	local function caps(center: Vector3, up: Vector3, r: number, L: number, mat: string)
		-- axe X du cylindre le long de up
		local side = up:Cross(if math.abs(up.Z) < 0.9 then Vector3.zAxis else Vector3.xAxis).Unit
		local axis = CFrame.fromMatrix(Vector3.zero, up, side)
		local h = math.max(0, L / 2 - r)
		if h > 1e-4 then
			local c = Instance.new("Part"); c.Name = "Gant"; c.Shape = Enum.PartType.Cylinder; c.Size = Vector3.new(h * 2, r * 2, r * 2)
			add(c, CFrame.new(center) * axis, mat)
		end
		for _, sgn in ipairs({ -1, 1 }) do
			local b = Instance.new("Part"); b.Name = "Gant"; b.Shape = Enum.PartType.Ball; b.Size = Vector3.new(r * 2, r * 2, r * 2)
			add(b, CFrame.new(center + up * (h * sgn)), mat)
		end
	end
	local function seg(a: Vector3, b: Vector3, r: number, mat: string)
		local d = b - a
		caps((a + b) / 2, d.Unit, r, d.Magnitude + r * 1.6, mat)
	end
	local R, D = 0.026, math.pi / 180
	local function P(phi: number, y: number, rr: number?): Vector3
		local k = rr or R
		return Vector3.new(math.cos(phi) * k, y, math.sin(phi) * k)
	end
	box(Vector3.new(0.028, 0.084, 0.07), Vector3.new(0.03, -0.036, 0.018), -0.62, "fab")      -- paume + dos
	box(Vector3.new(0.012, 0.07, 0.026), Vector3.new(0.046, -0.034, -0.006), -0.35, "pad")    -- coque des jointures
	box(Vector3.new(0.03, 0.05, 0.02), Vector3.new(0.03, -0.03, 0.05), -0.9, "strap")         -- sangle du poignet
	local F = {
		{ y = -0.008, L = { 0.042, 0.026, 0.021 }, r = 0.0088 }, { y = -0.027, L = { 0.046, 0.029, 0.022 }, r = 0.0092 },
		{ y = -0.046, L = { 0.043, 0.027, 0.021 }, r = 0.0088 }, { y = -0.063, L = { 0.034, 0.021, 0.018 }, r = 0.0076 },
	}
	for _, f in ipairs(F) do
		local phi = -14 * D
		local a = P(phi, f.y)
		caps(a, Vector3.yAxis, f.r * 1.12, f.r * 2.4, "fab")                                -- jointure
		for i, L in ipairs(f.L) do
			local i0 = i - 1
			phi += -L / R * (if i0 > 0 then 1.05 else 0.95)
			local b = P(phi, f.y - 0.002 * i0, R - 0.002 * i0)
			seg(a, b, f.r * (1 - i0 * 0.1), if i0 == 2 then "palm" else "fab")
			a = b
		end
	end
	do  -- pouce
		local a = Vector3.new(0.03, -0.03, 0.042)
		local pts = { P(118 * D, -0.004, 0.03), P(168 * D, 0.004, 0.028), P(205 * D, 0.008, 0.026) }
		local rr = { 0.0125, 0.0105, 0.0095 }
		for i, b in ipairs(pts) do seg(a, b, rr[i], "fab"); a = b end
	end
	return list
end
local WRIST = Vector3.new(0.032, -0.032, 0.07)        -- le bras s'arrête au poignet du gant
local gloveR, gloveL = newGlove(), newGlove()
-- reflet en x (main gauche) : position (-x, y, z), rotation S·R·S
local function mirror(c: CFrame): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = c:GetComponents()
	return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end
local LEFT_FLAT = CFrame.new(0, -0.006, 0) * CFrame.Angles(math.pi / 2, 0, 0)   -- main gauche à plat sous le garde-main
local LEFT_VERT = CFrame.Angles(0, 0.7, 0)                                        -- main gauche autour d'une poignée verticale
local leftAt: { CFrame } = {}
local leftVert: boolean? = nil
local function setLeftHold(vert: boolean)
	if leftVert == vert then return end
	leftVert = vert
	local inner = if vert then LEFT_VERT else LEFT_FLAT
	for i, g in ipairs(gloveL) do leftAt[i] = mirror(inner * g.at) end
end
setLeftHold(false)
local function leftWrist(): Vector3
	local w = (if leftVert then LEFT_VERT else LEFT_FLAT) * WRIST
	return Vector3.new(-w.X, w.Y, w.Z)
end
local gloveLook = ""
local function setGloveColor(glove: Color3)
	local key = glove:ToHex()
	if key == gloveLook then return end
	gloveLook = key
	local col = {
		fab = glove:Lerp(Color3.new(1, 1, 1), 0.08), palm = Color3.new(glove.R * 0.75, glove.G * 0.75, glove.B * 0.75),
		pad = Color3.new(0.025, 0.027, 0.03), strap = Color3.new(glove.R * 0.6, glove.G * 0.6, glove.B * 0.6),
	}
	for _, list in ipairs({ gloveR, gloveL }) do
		for _, g in ipairs(list) do g.p.Color = (col :: any)[g.mat] end
	end
end
local gParts: { BasePart } = {}
for _, g in ipairs(gloveR) do table.insert(gParts, g.p) end
for _, g in ipairs(gloveL) do table.insert(gParts, g.p) end
local gCFs: { CFrame } = table.create(#gParts)
local function placeGloves(rootR: CFrame, rootL: CFrame?, hiddenCF: CFrame)
	local n = 0
	for _, g in ipairs(gloveR) do n += 1; gCFs[n] = rootR * g.at end
	for i in ipairs(gloveL) do n += 1; gCFs[n] = if rootL then rootL * leftAt[i] else hiddenCF end
	workspace:BulkMoveTo(gParts, gCFs, Enum.BulkMoveMode.FireCFrameChanged)
end
local flash = part("Flash", Vector3.new(0.12, 0.12, 0.12), Color3.fromRGB(255, 214, 140), Enum.Material.Neon)
flash.Shape = Enum.PartType.Ball
local flashLight = Instance.new("PointLight"); flashLight.Color = Color3.fromRGB(255, 200, 120); flashLight.Range = 12; flashLight.Brightness = 0; flashLight.Parent = flash
-- reflet qui balaie l'arme (inspection, sortie des skins Légendaires) : INS_LIGHT du web, une simple lumière
local glint = part("Glint", Vector3.new(0.02, 0.02, 0.02), Color3.new(), nil)
glint.Transparency = 1
local glintLight = Instance.new("PointLight"); glintLight.Color = Color3.fromRGB(255, 241, 214); glintLight.Range = 0.9; glintLight.Brightness = 0
glintLight.Shadows = false; glintLight.Parent = glint

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
	spr = 0, tac = 0, sld = 0, mnt = 0, mhi = 0,
	drawT = 0, drawMax = 0.35, flashT = 0, swingT = 0, boltT = 0, pumpT = 0,
	relKey = 0, relSnd = 0, relDrop = false, relEmpty = false, inspSnd = 0,
	sig = "", att = {} :: { string }, mods = A.neutral(), noFlash = false,
	lastLook = Vector3.new(0, 0, -1), prevGround = true, airVy = 0,
	relShells = 3, boltC = Vector3.zero, boltX = 0, stock = {} :: { BasePart },
	drawQ = 0, drawFl = false, drawK = "long", drawRack = false, glintK = 0, glintX = 0,
	-- caméra (placeCamera du web) : ressort d'atterrissage, phase du balancement, tangage déjà ajouté, champ posé
	camL = 0, camLv = 0, camAir = 0, camGround = true, camPit = 0, bobT = 0, fovSet = -1, fovBase = 70,
}
-- chargeurs vides qui tombent : copies ancrées, déplacées dans le repère de la caméra (vmDropsUpdate du web)
type Drop = { parts: { BasePart }, rel: { CFrame }, pos: Vector3, r0: CFrame, ang: Vector3, v: Vector3, s: Vector3, t: number }
local drops: { Drop } = {}

-- durée de sortie (drawDur du web) : skins Épiques et plus (rareté 3+) font une petite figure, plus longue
local function drawDur(key: string): number
	local w = Config.WEAPONS[key]
	local q = 0
	if not S.kc then
		local sk = player:GetAttribute("Skin_" .. key)
		local def = if typeof(sk) == "number" then Config.SKINS[sk] else nil
		if def and (sk :: number) > 1 then q = def.rarity - 1 end
		if player:GetAttribute("Camo_" .. key) ~= nil then q = math.max(q, 3) end   -- camos animés : exclusifs
	end
	VM.drawQ = q; VM.drawFl = q >= 2; VM.drawRack = false
	VM.drawK = if w and w.melee then "knife" elseif w and w.cat == "pistol" then "pistol" else "long"
	return if VM.drawFl then (if VM.drawK == "long" then 0.95 else 0.8) else 0.5
end

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
	VM.magParts = {}; VM.hasBolt = false; VM.stock = {}
	local sum, n = Vector3.zero, 0
	local bsum, bn, bx = Vector3.zero, 0, -math.huge
	for _, c in ipairs(model:GetChildren()) do
		if c:IsA("BasePart") then
			local off = c:GetAttribute("Offset")
			local pos = if typeof(off) == "CFrame" then off.Position else nil
			if c:GetAttribute("Piece") == "mag" then
				table.insert(VM.magParts, c)
				if pos then sum += pos; n += 1 end
			elseif c:GetAttribute("Piece") == "bolt" then
				VM.hasBolt = true
				if pos then bsum += pos; bn += 1; bx = math.max(bx, pos.X + c.Size.X / 2) end
			end
			-- crosse (pièce entièrement derrière la poignée) : masquée en visée, vue de près elle boucherait l'écran
			if pos and not w.melee and c:GetAttribute("Piece") ~= "mag" and pos.Z - c.Size.Z / 2 > 0 then table.insert(VM.stock, c) end
		end
	end
	-- levier d'armement : à droite de la culasse (rackC du web), la main droite vient le tirer
	VM.boltC = if bn > 0 then bsum / bn else Vector3.new(0, 0.03, -0.02)
	VM.boltX = if bn > 0 then bx - VM.boltC.X + 0.012 else 0.03
	VM.hasMag = n > 0
	VM.magC = if n > 0 then sum / n else Vector3.new(0, -0.08, -0.05)
	VM.magDir = if key == "p90" then Vector3.new(0, 0.55, 0.85).Unit else Vector3.new(0.18, -1, 0).Unit
	VM.drawMax = drawDur(key)
	VM.drawT = VM.drawMax
end

-- ---------- événements ----------
S.onDraw:Connect(function(key: string)
	if key ~= VM.key then task.spawn(setGun, key) else VM.drawMax = drawDur(key); VM.drawT = VM.drawMax end
	sfx("draw", 0.6)
end)
S.onShot:Connect(function(key: string)
	local w = Config.WEAPONS[key]
	if not w then return end
	if VM.drawFl then VM.drawT = 0 end              -- tirer coupe la figure de sortie (vmFire du web)
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
	-- pompe : nombre de cartouches glissées une à une, fixé au début de la recharge
	local w = VM.key and Config.WEAPONS[VM.key]
	VM.relShells = if w then clamp(w.mag - S.mag, 1, 4) else 3
	if not VM.hasMag and not (w and w.cat == "shotgun") then sfx("reload", 0.8) end
end)

-- chargeur vide qui tombe (vmDropMag du web) : copie des pièces lâchée dans la vue, 0,9 m/s le long du puits,
-- gravité de 7 m/s² dans le repère de la caméra, rotation au hasard ; disparaît après 1,2 s ou sous l'écran
local function dropMag(gunCF: CFrame, magAnim: CFrame)
	local g0 = gunCF * magAnim * CFrame.new(VM.magC)          -- centre du chargeur, repère de la caméra
	local d: Drop = { parts = {}, rel = {}, pos = g0.Position, r0 = g0.Rotation, ang = Vector3.zero, t = 0,
		v = gunCF:VectorToWorldSpace(VM.magDir) * 0.9 - Vector3.new(0.15, 0, 0),
		s = Vector3.new((math.random() - 0.5) * 6, (math.random() - 0.5) * 4, 4 + math.random() * 3) }
	for _, p in ipairs(VM.magParts) do
		local off = p:GetAttribute("Offset")
		local c = p:Clone(); c.Anchored = true; c.CanCollide = false; c.Parent = rig
		table.insert(d.parts, c)
		table.insert(d.rel, CFrame.new(-VM.magC) * (if typeof(off) == "CFrame" then off else CFrame.identity))
	end
	table.insert(drops, d)
end
local function dropsUpdate(dt: number, camCF: CFrame)
	for i = #drops, 1, -1 do
		local d = drops[i]
		d.t += dt; d.v -= Vector3.new(0, 7 * dt, 0); d.pos += d.v * dt; d.ang += d.s * dt
		if d.t > 1.2 or d.pos.Y < -1.2 then
			for _, p in ipairs(d.parts) do p:Destroy() end
			table.remove(drops, i)
		else
			local base = camCF * CFrame.new(d.pos) * d.r0 * CFrame.fromEulerAnglesXYZ(d.ang.X, d.ang.Y, d.ang.Z)
			for j, p in ipairs(d.parts) do p.CFrame = base * d.rel[j] end
		end
	end
end

-- reflet (inspectGlint du web) : intensité en cloche, la lumière passe de gauche à droite devant l'arme
local function inspectGlint(a: number)
	local x = clamp((a - 0.04) / 0.3, 0, 1)
	VM.glintK = math.sin(x * math.pi); VM.glintX = lerp(-0.25, 0.45, x)
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
	-- mvWeights du web : le sprint ne compte qu'au-dessus de 80 % de la course, chaque posture a sa vitesse de transition
	local function follow(cur: number, on: boolean, rate: number): number return cur + ((if on then 1 else 0) - cur) * math.min(1, dt * rate) end
	local running = S.speed / STUDS_PER_M > 5.2 * 0.8
	VM.spr = follow(VM.spr, S.sprint and not S.tactical and running, 9); VM.tac = follow(VM.tac, S.tactical and running, 9)
	VM.sld = follow(VM.sld, S.slide, 12); VM.mnt = follow(VM.mnt, S.mantle, 14)
	VM.mhi = follow(VM.mhi, S.mantle and S.mantleHigh, 14)
	-- avancement de l'escalade 0..1 (MovementController), -1 hors escalade
	local mA = if S.mantle and S.mantleDur > 0 then clamp((t - S.mantleT) / S.mantleDur, 0, 1) else -1
	local mBump = if mA >= 0 then math.sin(mA * math.pi) else 0

	-- ressorts : recul, traînée de la souris, atterrissage, pas de côté
	local sd = math.min(dt, 0.033)
	VM.kv += (-VM.kick * 300 - VM.kv * 26) * sd; VM.kick = clamp(VM.kick + VM.kv * sd, -0.3, 1.4)
	VM.flashT = math.max(0, VM.flashT - dt); VM.drawT = math.max(0, VM.drawT - dt); VM.swingT = math.max(0, VM.swingT - dt)
	VM.boltT = math.max(0, VM.boltT - dt); VM.pumpT = math.max(0, VM.pumpT - dt)
	local spdMs = S.speed / STUDS_PER_M
	local spd = clamp(spdMs / 5.2, 0, 1.3)
	VM.bph += dt * spdMs * 1.7
	-- direction du regard sans le plongeon d'atterrissage ajouté par nous (sinon l'arme traînerait derrière)
	local look = (camera.CFrame * CFrame.Angles(-VM.camPit, 0, 0)).LookVector
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
	local lat = 0
	if root and not kc then
		lat = camera.CFrame.RightVector:Dot(root.AssemblyLinearVelocity) / STUDS_PER_M
		VM.strafe += (clamp(lat / 5, -1, 1) - VM.strafe) * (1 - math.exp(-dt * 8))
	end

	-- caméra du web (placeCamera) : la tête balance en marchant, roule un peu en pas de côté et en glissade,
	-- plonge à l'atterrissage puis revient ; le champ s'élargit en sprint / sprint tactique / glissade.
	-- La caméra Roblox repart chaque image de sa direction : le roulis et la position sont reposés à chaque fois,
	-- le tangage n'est ajouté que par différence (comme le recul de WeaponController).
	if not kc then
		VM.bobT += dt * spdMs * 1.6
		if not S.grounded then VM.camAir = vyMs end
		if S.grounded and not VM.camGround and VM.camAir < -2.5 then VM.camLv -= math.min(1.6, -VM.camAir * 0.16) end
		VM.camGround = S.grounded; if S.grounded then VM.camAir = 0 end
		VM.camLv += (-VM.camL * 190 - VM.camLv * 20) * sd; VM.camL += VM.camLv * sd
		local roll = -clamp(lat / 5.2, -1, 1) * 0.012 * spdMs / 5 + VM.sld * 0.055
		local bobX, bobY = 0, 0
		if S.grounded then
			local a = clamp(spdMs / 5, 0, 1.3) * shakeK
			bobY = math.sin(VM.bobT * 2) * 0.016 * a; bobX = math.sin(VM.bobT) * 0.011 * a; roll += math.sin(VM.bobT) * 0.0035 * a
		end
		-- escalade : la tête plonge vers le rebord et roule un peu du côté de la main posée
		roll += mBump * 0.035 * (0.4 + 0.6 * shakeK)
		local land = VM.camL * (0.35 + 0.65 * shakeK)
		bobY += land - VM.camL                                 -- plongeon d'atterrissage réduit avec les secousses
		local pit = land * 0.35 - mBump * (0.07 + VM.mhi * 0.05)
		local cf = camera.CFrame
		local flatR = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
		flatR = if flatR.Magnitude > 1e-3 then flatR.Unit else Vector3.xAxis
		local off = (flatR * bobX + Vector3.yAxis * (bobY + VM.camL)) * STUDS_PER_M
		camera.CFrame = CFrame.new(off) * cf * CFrame.Angles(pit - VM.camPit, 0, 0) * CFrame.Angles(0, 0, roll)
		VM.camPit = pit
		-- champ : WeaponController le repose à chaque image ; s'il ne l'a pas fait, on repart de notre base
		local fov = camera.FieldOfView
		if math.abs(fov - VM.fovSet) < 1e-4 then fov = VM.fovBase end
		VM.fovBase = fov
		VM.fovSet = fov * (1 + VM.spr * 0.06 + VM.tac * 0.1 + VM.sld * 0.07)
		camera.FieldOfView = VM.fovSet
	end

	-- marche en « 8 » + respiration
	local bobk = 1 - ads * 0.88
	local ph = VM.bph
	local bx, by, br = math.sin(ph) * 0.009 * spd * bobk, (math.sin(ph * 2) * 0.5 - 0.25) * 0.012 * spd * bobk, math.sin(ph) * 0.018 * spd * bobk
	local idle = (1 - clamp(spd, 0, 1)) * (1 - ads * 0.8)
	local brY, brX = math.sin(t * 1.7) * 0.0028 * idle, math.sin(t * 0.9) * 0.0018 * idle

	-- position de base : hanche (ramenée pour un champ de 60° comme le web) → visée (exacte)
	local adsZ = -0.46 + (if A.optOf(VM.att) then 0.08 else 0)     -- optique : arme un peu plus près de l'œil
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
	-- sortie de l'arme (drawPose du web) : arrive du bas, dépasse un peu, se pose ;
	-- skins Épiques et plus : pistolet qui fait un tour autour du pontet, couteau qui tournoie, fusil basculé puis armé
	VM.glintK = 0
	local drawSpin = 0
	if VM.drawT > 0 then
		local a = 1 - VM.drawT / VM.drawMax
		local up = clamp(a / (if VM.drawFl then 0.45 else 0.75), 0, 1)
		local e = 1 - up
		local ov = math.sin(up * math.pi) * (1 - up) * 0.6
		py += -e * e * 0.3 + ov * 0.02; rx += -e * e * 0.95 + ov * 0.12; px += e * e * 0.06; rz += e * 0.25
		if VM.drawFl then
			local f = clamp((a - 0.3) / 0.55, 0, 1)
			local s = smooth01(f)
			if VM.drawK == "pistol" then
				drawSpin = s * TAU; py += math.sin(f * math.pi) * 0.05; pz -= math.sin(f * math.pi) * 0.03
			elseif VM.drawK == "knife" then
				rz += s * TAU * 2; py += math.sin(f * math.pi) * 0.04
			else
				local b = math.sin(f * math.pi)
				rz += b * 0.9; ry += b * 0.35; py += b * 0.03; px -= b * 0.03
				if VM.hasBolt and not VM.pistol and a > 0.78 and not VM.drawRack then VM.drawRack = true; VM.boltT = 0.8; sfx("rack", 0.5) end
			end
			if VM.drawQ >= 3 then inspectGlint(clamp((a - 0.2) * 0.75, 0, 1)) end
		end
		if a < 0.05 then VM.drawRack = false end
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
				inspectGlint(a)
			end
		end
	end
	-- sprint (arme en travers), sprint tactique (arme levée), glissade (inclinée), escalade (arme baissée)
	do
		local s, T, L, Mn = VM.spr * (1 - ads), VM.tac * (1 - ads), VM.sld, VM.mnt
		local sb = math.sin(VM.bph * 0.9)
		px += -s * 0.045 + s * sb * 0.014; py += -s * 0.05 + s * math.abs(sb) * 0.012; rx -= s * 0.3; ry += s * 0.62; rz += s * 0.38
		rz += s * sb * 0.05; rx += s * math.abs(sb) * 0.03                      -- l'arme ballotte au rythme des foulées
		px += T * (0.1 + sb * 0.01); py += T * (-0.015 + math.abs(sb) * 0.015); rx += T * 0.8; rz -= T * 0.6; ry -= T * 0.12
		rz += L * 0.32; py -= L * 0.03; px -= L * 0.02
		-- glissade : l'arme vibre sur le sol, puis se redresse en fin de glissade
		rz += L * math.sin(t * 31) * 0.006; py += L * math.sin(t * 27 + 1) * 0.0035; rx += L * math.sin(t * 23) * 0.004
		-- escalade : arme baissée sur la droite (rebord bas) ou sortie de la vue (rebord haut, les deux mains se hissent)
		py -= Mn * 0.22; rx -= Mn * 0.7; px += Mn * 0.03
		py -= VM.mhi * 0.42; rz -= VM.mhi * 0.5; px += VM.mhi * 0.06
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
		-- étapes de recharge (Sfx.reloadStep : "out" / "in" / "bolt" / "shell"), calées sur la durée de recharge
		local function snd(i: number, at: number, step: string)
			if VM.relSnd < i and rl >= at then VM.relSnd = i; Sfx.reloadStep(w.cat, step, nil, 0.8) end
		end
		if VM.hasMag then
			snd(1, 0.28, "out"); snd(2, 0.71, "in")
			if VM.relEmpty and VM.hasBolt then snd(3, if VM.pistol then 0.84 else 0.85, "bolt") end
		elseif w.cat == "shotgun" then
			local n = VM.relShells
			local aa = clamp((rl - 0.15) / 0.65, 0, 0.999)
			local i = math.floor(aa * n)
			local ph2 = aa * n % 1
			if rl > 0.15 and rl < 0.8 then
				leftOff = math.sin(ph2 * math.pi) * 0.6
				if VM.relSnd <= i and ph2 > 0.55 then VM.relSnd = i + 1; Sfx.reloadStep(w.cat, "shell", nil, 0.7) end
			end
			if VM.relEmpty and VM.hasBolt then snd(99, 0.85, "bolt") end   -- à vide : on pompe à la fin
		end
	end

	local gunCF = CFrame.new(px, py, pz) * CFrame.fromEulerAnglesXYZ(rx, ry, rz)
	-- tour du pistolet : autour de la main (doigt dans le pontet), la main et le bras ne tournent pas
	local gunDraw = gunCF
	if drawSpin ~= 0 then
		local piv = Vector3.new(0.005, -0.035, 0.02) + Vector3.new(0, -0.012, -0.02) * VM_SCALE
		gunDraw = gunCF * CFrame.new(piv) * CFrame.Angles(drawSpin, 0, 0) * CFrame.new(-piv)
	end

	-- pièces mobiles : chargeur (recharge / inspection), culasse ou glissière
	local pieces: { [string]: CFrame } = {}
	local magVisible = true
	local magPos = VM.magC
	if VM.hasMag then
		local out, tw = 0, 0
		if rl >= 0 then
			if rl < 0.26 then out = 0
			elseif rl < 0.36 then out = smooth01((rl - 0.26) / 0.1)
			elseif rl < 0.46 then
				-- à vide le chargeur est lâché (il tombe dans la vue) ; recharge tactique : la main gauche l'emporte vers la poche
				out = 1 + smooth01((rl - 0.36) / 0.1) * 1.4; magVisible = not VM.relEmpty and rl < 0.42
			elseif rl < 0.58 then out = 2.4 - smooth01((rl - 0.46) / 0.12) * 1.25; tw = 1 - smooth01((rl - 0.5) / 0.08)
			elseif rl < 0.72 then out = 1.15 * (1 - smooth01((rl - 0.58) / 0.14)) end
		end
		local off = VM.magDir * out * 0.2
		local rot = CFrame.fromEulerAnglesXYZ(tw * 0.5, 0, tw * 0.35)
		-- repère du centre du chargeur (repère de l'arme), rotation autour de ce centre
		local center = CFrame.new(VM.magC + off) * rot
		if ins and ins.kind == "mag" and (ins.out > 0 or ins.hold > 0) then
			-- inspection (inspectMag du web) : glissé hors du puits, puis amené devant les yeux, haut du chargeur
			-- tourné vers la caméra et cartouches vers le haut, tourné un peu pour les montrer
			center = CFrame.new(VM.magC + VM.magDir * ins.out * 0.24)
			if ins.hold > 0 then
				local tilt = CFrame.Angles(0, ins.tilt, 0)
				local iA = tilt * Vector3.new(0, 0.45, 1).Unit
				local iB = tilt * Vector3.new(0.25, 1, -0.35).Unit
				local c2 = iA:Cross(iB).Unit
				iB = c2:Cross(iA).Unit
				local up, fw = Vector3.yAxis, Vector3.new(0, 0, -1)
				local Rq = CFrame.fromMatrix(Vector3.zero, iA, iB, c2) * CFrame.fromMatrix(Vector3.zero, up, fw, up:Cross(fw)):Inverse()
				local hold = gunCF:Inverse() * CFrame.new(Vector3.new(-0.04, -0.06, -0.28) / FOV_K) * Rq
				center = center:Lerp(hold, ins.hold)
			end
			magPos = center:PointToWorldSpace(Vector3.new(0, -0.02, 0)) + Vector3.new(0, 0.02, 0)   -- la main le tient par le bas
		else
			magPos = VM.magC + off
		end
		pieces.mag = center * CFrame.new(-VM.magC)
		if rl >= 0.36 and not VM.relDrop and VM.relEmpty then VM.relDrop = true; dropMag(gunCF, pieces.mag) end
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
			local bt = math.max(if VM.boltT > 0 then math.sin((1 - VM.boltT / 0.8) * math.pi) else 0, pull)
			-- fusil à verrou : le levier pivote avant de reculer (rotation autour de la culasse)
			local turn = if w.cat == "sniper" then bt * 0.8 else 0
			pieces.bolt = CFrame.new(0, 0, bt * 0.06) * CFrame.new(VM.boltC) * CFrame.Angles(0, 0, turn) * CFrame.new(-VM.boltC)
		end
	end

	-- lunette : en visée avec un fusil de précision, l'arme disparaît derrière l'oculaire
	local scoped = ads > 0.92 and not w.melee and A.sightOv(key, VM.att)
	scopeGui.Enabled = scoped
	if scoped then scopeRetUpdate(A.optOf(VM.att)) end
	setVisible(not scoped)
	if ads >= 0.55 then for _, p in ipairs(VM.stock) do p.LocalTransparencyModifier = 1 end end

	-- placement dans le monde
	local camCF = camera.CFrame
	local world = camCF * gunDraw
	WeaponModels.place(model, world, pieces)
	dropsUpdate(dt, camCF)
	glint.CFrame = camCF * CFrame.new(VM.glintX, 0.05, -0.25)
	glintLight.Brightness = VM.glintK * 2.4
	if not magVisible then for _, p in ipairs(VM.magParts) do p.LocalTransparencyModifier = 1 end end

	-- mains : droite sur la poignée, gauche sur le garde-main (va chercher le chargeur pendant la recharge)
	local rightL = gunCF:PointToWorldSpace(Vector3.new(0.005, -0.035, 0.02))
	local leftLocal = VM.left - Vector3.new(0, leftOff * 0.12, 0)
	if rl >= 0 and VM.hasMag then
		local k = if rl < 0.15 then rl / 0.15 elseif rl > 0.8 then (1 - rl) / 0.2 else 1
		leftLocal = leftLocal:Lerp(magPos - Vector3.new(0, 0.02, 0), smooth01(k))
		-- armement d'une arme longue vide : la main droite lâche la poignée et tire le levier d'armement
		if VM.relEmpty and VM.hasBolt and not VM.pistol and VM.twoHand and rl >= 0.76 then
			local kin = smooth01((rl - 0.76) / 0.06)
			local bolt = pieces.bolt or CFrame.identity
			local hp = gunCF * bolt * (VM.boltC + Vector3.new(VM.boltX, 0, 0))
			rightL = rightL:Lerp(hp, kin * (if rl < 0.92 then 1 else smooth01((1 - rl) / 0.08)))
		end
	end
	if ins and ins.lh > 0 then leftLocal = leftLocal:Lerp(magPos - Vector3.new(0, 0.02, 0), ins.lh) end
	local leftL = gunCF:PointToWorldSpace(leftLocal)
	local handRot = gunCF.Rotation
	local rotR, rotL = handRot, handRot
	-- sprint tactique : la main gauche lâche le garde-main et balance au rythme de la course (arme tenue haute)
	local pump = if VM.twoHand and rl < 0 and not ins then VM.tac * (1 - ads) * (1 - VM.mnt) else 0
	if pump > 0.001 then
		local sb = math.sin(VM.bph * 0.9)
		local swing = Vector3.new(-0.2 + sb * 0.02, -0.3 + sb * 0.07, -0.34 - sb * 0.1) / FOV_K
		leftL = leftL:Lerp(swing, smooth01(pump))
		rotL = handRot:Lerp(CFrame.Angles(0.5 + sb * 0.4, 0.3, 0.2), smooth01(pump))
	end
	-- escalade : la main gauche (et la droite sur un rebord haut) vient se poser à plat sur le rebord ; le corps monte,
	-- le rebord descend donc dans la vue sous la paume, qui pousse jusqu'à la fin du geste
	local plant = false
	if mA >= 0 and VM.twoHand then
		local reach = smooth01(mA / 0.2) * (1 - smooth01((mA - 0.8) / 0.2))
		local push = smooth01((mA - 0.12) / 0.6)
		local ly, lz = lerp(0.03, -0.34, push), lerp(-0.5, -0.3, push)
		local palmL = CFrame.Angles(-0.25, 0.15, 0) * CFrame.Angles(0, 0, -math.pi / 2)    -- paume vers le bas, doigts vers l'avant
		local palmR = CFrame.Angles(-0.25, -0.15, 0) * CFrame.Angles(0, 0, math.pi / 2)
		leftL = leftL:Lerp(Vector3.new(-0.15, ly, lz), reach)
		rotL = rotL:Lerp(palmL, reach)
		plant = reach > 0.5
		local rk = reach * VM.mhi
		if rk > 0.001 then
			rightL = rightL:Lerp(Vector3.new(0.13, ly + 0.01, lz - 0.02), rk)
			rotR = handRot:Lerp(palmR, rk)
		end
	end
	arms.hR.CFrame = camCF * (CFrame.new(rightL) * rotR)
	-- poignée verticale : la main gauche se referme autour, paume tournée vers l'arrière
	-- (même tenue pour la main posée sur un rebord : c'est le reflet de la main droite)
	setLeftHold(plant or (model:GetAttribute("LeftV") == true and rl < 0 and not (ins and ins.lh > 0.3)))
	arms.hL.CFrame = camCF * (CFrame.new(leftL) * rotL)
	local hidden = camCF * CFrame.new(0, -3, 0)
	placeGloves(arms.hR.CFrame, if VM.twoHand then arms.hL.CFrame else nil, hidden)
	placeArm(arms.uR, arms.fR, arms.cR, rightL + rotR:VectorToWorldSpace(WRIST), 1, ads, camCF)
	if VM.twoHand then
		placeArm(arms.uL, arms.fL, arms.cL, leftL + rotL:VectorToWorldSpace(leftWrist()), -1, ads, camCF)
	else
		arms.uL.CFrame = hidden; arms.fL.CFrame = hidden; arms.cL.CFrame = hidden; arms.hL.CFrame = hidden
	end
	-- tenue du web (lookMats) : T = treillis sable et gants coyote, CT (et chacun pour soi) = bleu marine et gants noirs
	local myTeam = player:GetAttribute("Team")
	local isT = myTeam == "Attaquants"
	local sleeve = if isT then Color3.fromRGB(169, 148, 104) else Color3.fromRGB(43, 58, 82)
	arms.uR.Color = sleeve; arms.fR.Color = sleeve; arms.uL.Color = sleeve; arms.fL.Color = sleeve
	local cuff = if isT then Color3.fromRGB(74, 74, 50) else Color3.fromRGB(27, 31, 39)
	arms.cR.Color = cuff; arms.cL.Color = cuff
	setGloveColor(if isT then Color3.fromRGB(138, 122, 85) else Color3.fromRGB(21, 24, 29))

	-- éclair de bouche
	local muzzleW = world:PointToWorldSpace(VM.muzzle)
	S.muzzle = muzzleW
	flash.CFrame = CFrame.new(muzzleW)
	local on = VM.flashT > 0 and not w.melee and not VM.noFlash      -- silencieux / cache-flamme : pas de flamme
	flash.Size = Vector3.one * (0.08 + math.random() * 0.06)
	flashLight.Brightness = if on then 4 else 0
	flash.LocalTransparencyModifier = if on and not scoped then 0.1 else 1
end)
