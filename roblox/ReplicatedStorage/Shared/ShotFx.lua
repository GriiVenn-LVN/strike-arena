--!strict
-- ReplicatedStorage/Shared/ShotFx (ModuleScript, côté client)
-- Effets de tir du jeu web (src/50_fx.js, src/51_fx2.js, src/60_game.js, src/67_immersion.js), avec les mêmes
-- valeurs (m, m/s, s) passées en studs :
--   ShotFx.tracer(from, to, col?)       balle traçante qui voyage vraiment (420 m/s) : tête blanche brillante et traînée
--                                       qui s'efface (4,5 m ; 6 m et plus épaisse avec une traînée de couleur),
--                                       épaisseur constante à l'écran (plus large au loin)
--   ShotFx.impact(from, to)             au bout de la trajectoire : sur un décor, éclair + étincelles (deux fois plus
--                                       sur le métal) + poussière et éclats à la couleur du sol + trou de balle ;
--                                       sur un personnage, sang (gerbe + brume, plus fort à la tête) ou étincelles
--                                       bleues s'il a encore du bouclier
--   ShotFx.muzzle(pos, dir, big)        flamme de bouche en étoile des autres tireurs (0,5 m, 0,8 m au pompe et au
--                                       fusil de précision) et petite fumée
--   ShotFx.shell(pos, right)            douille de laiton qui saute à droite, tourne, rebondit deux fois et reste 2,4 s
--   ShotFx.ownShell(vmPos)              la nôtre, lancée depuis la fenêtre d'éjection du viewmodel
--   ShotFx.stain(pos)                   taches de sang au sol à la mort
--   ShotFx.explosion(pos, scale)        boule de feu, fumée sombre et débris en plus de l'explosion des grenades
--   ShotFx.trailColor(player)           couleur de la traînée cosmétique équipée (attribut Trail), nil = standard
-- Les trous et les taches partagent 160 décalques (anneau, comme le web). Graphismes bas (ombres coupées) :
-- particules au quart, comme cfg.fx = 0 du web. Option « Effets de sang » : S.opt.gore = false les coupe.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MapData = require(ReplicatedStorage.Shared.MapData)
local S = require(ReplicatedStorage.Shared.ClientState)

local ShotFx = {}
local U = Config.STUDS_PER_METER
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local function rgb(h: number): Color3 return Color3.fromRGB(bit32.rshift(h, 16), bit32.band(bit32.rshift(h, 8), 255), bit32.band(h, 255)) end
local function rand(a: number, b: number): number return a + math.random() * (b - a) end
local function low(): boolean return not Lighting.GlobalShadows end
local function fxMul(): number return if low() then 0.25 else 1 end
local function gore(): boolean return (S.opt :: any).gore ~= false end

-- dégradé rond du web (glowTex), déjà envoyé (MeshStore « glow ») : particules et décalques
local glowTex: Content? = nil
do
	local ok, MapDress = pcall(require, ReplicatedStorage.Shared.MapDress)
	if ok and MapDress then
		local ok2, c = pcall((MapDress :: any).glow)
		if ok2 then glowTex = c end
	end
end
local STAR = "rbxasset://textures/particles/sparkles_main.dds"

local folder = Instance.new("Folder"); folder.Name = "EffetsTirs"; folder.Parent = workspace
local host = Instance.new("Part")
host.Name = "Emetteurs"; host.Anchored = true; host.CanCollide = false; host.CanQuery = false; host.CanTouch = false
host.CastShadow = false; host.Transparency = 1; host.Size = Vector3.new(0.2, 0.2, 0.2); host.CFrame = CFrame.new(0, -500, 0)
host.Parent = folder

-- ---------- particules (PSys du web) ----------
-- une source par sorte d'effet : on la place au point d'impact, orientée, puis Emit(n) ; les grains vivent dans le monde
local function nseq(pts: { { number } }): NumberSequence
	local k = {}
	for _, p in ipairs(pts) do table.insert(k, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0)) end
	return NumberSequence.new(k)
end
-- fondu du web : montée sur les 12 premiers % puis (1 - t)^1,3
local function fade(a0: number): NumberSequence
	return nseq({ { 0, 1 }, { 0.12, 1 - a0 }, { 0.4, 1 - a0 * 0.62 }, { 0.7, 1 - a0 * 0.21 }, { 1, 1 } })
end
type Kind = { att: Attachment, pe: ParticleEmitter }
local kinds: { [string]: Kind } = {}
-- d = { life = {a, b}, size = {s0, s1}, speed = {a, b}, color, alpha, grav, drag, spread, glow, star, lit, rot }
local function kind(name: string, d: { [string]: any }): Kind
	local k = kinds[name]
	if k then return k end
	local att = Instance.new("Attachment"); att.Name = name; att.Parent = host
	local pe = Instance.new("ParticleEmitter")
	pe.Name = name; pe.Enabled = false; pe.Rate = 0
	if d.star then pe.Texture = STAR elseif glowTex then pe.TextureContent = glowTex :: Content end
	pe.Lifetime = NumberRange.new(d.life[1], d.life[2])
	pe.Size = nseq({ { 0, d.size[1] * U }, { 1, d.size[2] * U } })
	pe.Speed = NumberRange.new(d.speed[1] * U, d.speed[2] * U)
	pe.Color = ColorSequence.new(d.color :: Color3)
	pe.Transparency = d.trans or fade(d.alpha or 1)
	pe.Acceleration = Vector3.new(0, -(d.grav or 0) * U, 0)
	pe.Drag = d.drag or 0
	pe.EmissionDirection = Enum.NormalId.Front
	pe.SpreadAngle = Vector2.new(d.spread or 60, d.spread or 60)
	pe.LightEmission = if d.lit then 0 else 1
	pe.LightInfluence = if d.lit then 1 else 0
	pe.Rotation = NumberRange.new(0, if d.rot then 360 else 0)
	pe.ZOffset = d.z or 0
	pe.Parent = att
	local nk: Kind = { att = att, pe = pe }
	kinds[name] = nk
	return nk
end
local function emit(k: Kind, pos: Vector3, dir: Vector3, n: number)
	if n <= 0 then return end
	local d = if dir.Magnitude > 1e-3 then dir.Unit else Vector3.yAxis
	local up = if math.abs(d.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	k.att.WorldCFrame = CFrame.lookAt(pos, pos + d, up)
	k.pe:Emit(math.max(1, math.round(n)))
end

-- étincelles du web (fxA additives : 1 / 0,82 / 0,45)
local function sparkKind(): Kind
	return kind("Etincelles", { life = { 0.12, 0.35 }, size = { 0.045, 0.015 }, speed = { 2, 6 }, color = Color3.new(1, 0.82, 0.45),
		grav = 10, drag = 0.4, spread = 70 })
end
-- couleurs de la poussière selon le sol (impactFX du web) ; bois en plus, que Roblox sait reconnaître
local DUST: { [string]: Color3 } = { snow = Color3.new(0.95, 0.97, 1), sand = Color3.new(0.82, 0.7, 0.52), metal = Color3.new(0.5, 0.5, 0.52),
	wood = Color3.new(0.55, 0.43, 0.3), stone = Color3.new(0.62, 0.6, 0.56) }
local function dustKind(surf: string): Kind
	return kind("Poussiere_" .. surf, { life = { 0.5, 1.1 }, size = { 0.06, 0.32 }, speed = { 0.4, 1.6 }, color = DUST[surf], alpha = 0.5,
		grav = -0.15, drag = 1.8, spread = 55, lit = true, rot = true })
end
local function chipKind(surf: string): Kind
	local c = DUST[surf]
	return kind("Eclats_" .. surf, { life = { 0.4, 0.8 }, size = { 0.035, 0.03 }, speed = { 2, 4 }, color = Color3.new(c.R * 0.6, c.G * 0.6, c.B * 0.6),
		trans = nseq({ { 0, 0 }, { 0.75, 0 }, { 1, 1 } }), grav = 14, drag = 0.2, spread = 65, lit = true })
end
local function flashKind(name: string, size: number, life: number): Kind
	return kind(name, { life = { life, life }, size = { size, size * 1.6 }, speed = { 0, 0 }, color = Color3.new(1, 0.86, 0.6),
		trans = nseq({ { 0, 0 }, { 1, 1 } }), star = name ~= "Eclair", rot = true, z = 0.3 })
end

-- ---------- sol touché ----------
local MAT: { [string]: string } = {
	Metal = "metal", CorrodedMetal = "metal", DiamondPlate = "metal", Foil = "metal",
	Wood = "wood", WoodPlanks = "wood", Sand = "sand", Sandstone = "sand", Snow = "snow", Ice = "snow", Glacier = "snow",
}
local BASE: { [string]: string } = { industrial = "metal", snow = "snow", sand = "sand" }
-- Les blocs de collision des cartes sont invisibles et lisses : on prend alors le sol de la carte (MAP.base du web)
local function surfaceOf(inst: Instance, mat: Enum.Material): string
	local m = MAT[mat.Name]
	if m and inst:IsA("BasePart") and inst.Transparency < 0.9 then return m end
	local f: Instance? = inst.Parent
	while f and f ~= workspace do
		local id = f:GetAttribute("MapId")
		if typeof(id) == "string" then
			local md = MapData[id]
			return md and BASE[md.base] or "stone"
		end
		f = f.Parent
	end
	return m or "stone"
end

-- ---------- décalques : trous de balle et taches de sang (160, en anneau) ----------
local decals: { { p: Part, d: Instance? } } = {}
local dIdx = 0
local function nextDecal(): { p: Part, d: Instance? }
	dIdx = dIdx % 160 + 1
	local e = decals[dIdx]
	if e then return e end
	local p = Instance.new("Part")
	p.Name = "Decalque"; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	local d: Instance? = nil
	if glowTex then
		p.Transparency = 1
		local dc = Instance.new("Decal"); dc.Face = Enum.NormalId.Front; dc.TextureContent = glowTex :: Content; dc.Parent = p
		d = dc
	else
		-- repli sans la texture : petit disque sombre
		p.Shape = Enum.PartType.Cylinder
	end
	p.Parent = folder
	local ne = { p = p, d = d }
	decals[dIdx] = ne
	return ne
end
local function putDecal(pos: Vector3, normal: Vector3, size: number, color: Color3, alpha: number)
	local e = nextDecal()
	local up = if math.abs(normal.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	local cf = CFrame.lookAt(pos + normal * 0.012, pos + normal * 2, up) * CFrame.Angles(0, 0, rand(0, math.pi * 2))
	if e.d then
		e.p.Size = Vector3.new(size, size, 0.02); e.p.CFrame = cf
		local dc = (e.d :: any) :: Decal
		dc.Color3 = color; dc.Transparency = 1 - alpha
	else
		e.p.Size = Vector3.new(0.01, size * 0.6, size * 0.6); e.p.CFrame = cf * CFrame.Angles(0, math.pi / 2, 0)
		e.p.Color = color; e.p.Transparency = 1 - alpha * 0.9
	end
end

-- ---------- balles traçantes (FX2.streaks du web, 56) ----------
type Streak = { a0: Attachment, a1: Attachment, beam: Beam, on: boolean, o: Vector3, dir: Vector3, L: number, d: number,
	len: number, w: number, fade: number, speed: number }
local streaks: { Streak } = {}
local sIdx = 0
local seqCache: { [string]: ColorSequence } = {}
-- dégradé du web (tête blanche -> 255,240,200 -> 255,190,90 -> 255,150,40) multiplié par la teinte de la balle
local function streakColors(tint: Color3): ColorSequence
	local key = tint:ToHex()
	local c = seqCache[key]
	if c then return c end
	local function m(r: number, g: number, b: number): Color3 return Color3.new(r * tint.R, g * tint.G, b * tint.B) end
	local nc = ColorSequence.new({ ColorSequenceKeypoint.new(0, m(1, 1, 1)), ColorSequenceKeypoint.new(0.06, m(1, 0.94, 0.78)),
		ColorSequenceKeypoint.new(0.35, m(1, 0.75, 0.35)), ColorSequenceKeypoint.new(1, m(1, 0.59, 0.16)) })
	seqCache[key] = nc
	return nc
end
local function streakAlpha(k: number): NumberSequence
	return nseq({ { 0, 1 - k }, { 0.06, 1 - 0.95 * k }, { 0.35, 1 - 0.45 * k }, { 1, 1 } })
end
local ALPHA1 = streakAlpha(1)
local DEFAULT_TINT = rgb(0xffd28a)

function ShotFx.tracer(from: Vector3, to: Vector3, col: Color3?)
	local seg = to - from
	local L = seg.Magnitude / U
	if L < 0.5 then return end
	sIdx = sIdx % 56 + 1
	local s = streaks[sIdx]
	if not s then
		local a0 = Instance.new("Attachment"); a0.Parent = host
		local a1 = Instance.new("Attachment"); a1.Parent = host
		local b = Instance.new("Beam")
		b.Attachment0 = a0; b.Attachment1 = a1; b.FaceCamera = true; b.Segments = 1
		b.LightEmission = 1; b.LightInfluence = 0; b.Brightness = 2.5; b.Enabled = false
		b.Parent = host
		s = { a0 = a0, a1 = a1, beam = b, on = false, o = from, dir = Vector3.zAxis, L = 0, d = 0, len = 0, w = 0, fade = 0, speed = 0 }
		streaks[sIdx] = s
	end
	local st = s :: Streak
	st.on = true; st.o = from; st.dir = seg.Unit; st.L = L; st.d = 0; st.fade = 0; st.speed = 420
	st.len = math.min(L, if col then 6 else 4.5); st.w = if col then 0.03 else 0.018
	st.beam.Color = streakColors(col or DEFAULT_TINT)
	st.beam.Transparency = ALPHA1
	st.beam.Enabled = false            -- allumé à la première image, une fois placé
end

-- couleur de la traînée cosmétique (TRAILS de src/64_extras.js)
local TRAILS: { [string]: number } = { cyan = 0x55e6ff, red = 0xff4655, lime = 0x9dff5a, gold = 0xffc933, violet = 0xb36bff }
function ShotFx.trailColor(p: Player?): Color3?
	local t = p and p:GetAttribute("Trail")
	if typeof(t) ~= "string" or t == "" then return nil end
	if t == "rainbow" then return Color3.fromHSV((os.clock() * 1.7) % 1, 0.8, 1) end
	local h = TRAILS[t]
	return if h then rgb(h) else nil
end

-- ---------- impacts ----------
local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude
local impT, impN = 0, 0
local function humanoidModel(inst: Instance): Model?
	local m = inst:FindFirstAncestorOfClass("Model")
	while m do
		if m:FindFirstChildOfClass("Humanoid") then return m end
		m = m:FindFirstAncestorOfClass("Model")
	end
	return nil
end

function ShotFx.impact(from: Vector3, to: Vector3)
	local seg = to - from
	if seg.Magnitude < 1 then return end
	if (to - camera.CFrame.Position).Magnitude > 260 then return end
	-- 12 impacts par dixième de seconde au plus (rafales de pompe à plusieurs)
	local t = os.clock()
	if t - impT > 0.1 then impT = t; impN = 0 end
	if impN >= 12 then return end
	impN += 1
	local dir = seg.Unit
	params.FilterDescendantsInstances = if player.Character then { folder, camera, player.Character } else { folder, camera }
	local r = workspace:Raycast(to - dir * 1.5, dir * 3, params)
	if not r then return end
	local pos, n = r.Position, r.Normal
	local back = -dir                              -- les éclats repartent vers le tireur
	local model = humanoidModel(r.Instance)
	local mul = fxMul()
	if model then
		local sh = model:GetAttribute("Shield")
		if typeof(sh) == "number" and sh > 0 then
			-- bodyHitFX du web, bouclier : étincelles bleues
			emit(kind("Bouclier", { life = { 0.15, 0.35 }, size = { 0.07, 0.02 }, speed = { 1.5, 4 }, color = Color3.new(0.3, 0.8, 1),
				grav = 4, drag = 0.6, spread = 70 }), pos, back, 10)
			return
		end
		if not gore() then return end
		local hs = string.find(r.Instance.Name, "Head") ~= nil
		-- gerbe de sang (fxBlood : 4, 7 à la tête) et brume qui traverse (bodyHitFX : 5, 10 à la tête)
		emit(kind(if hs then "SangGros" else "Sang", { life = { 0.35, 0.7 }, size = if hs then { 0.09, 0.2 } else { 0.06, 0.12 },
			speed = { 1, 3.5 }, color = Color3.new(0.62, 0.04, 0.05), alpha = 0.9, grav = 9, drag = 1.2, spread = 55, lit = true }),
			pos, back, (if hs then 7 else 4) * mul)
		emit(kind(if hs then "BrumeTete" else "Brume", { life = { 0.25, 0.5 }, size = if hs then { 0.05, 0.4 } else { 0.05, 0.28 },
			speed = { 0.5, 2 }, color = Color3.new(0.55, 0.03, 0.04), alpha = 0.75, grav = 2, drag = 1.5, spread = 40, lit = true, rot = true }),
			pos, dir, if hs then 10 else 5)
		return
	end
	local surf = surfaceOf(r.Instance, r.Material)
	local at = pos + n * 0.05 * U
	emit(flashKind("Eclair", 0.35, 0.06), at, n, 1)
	emit(sparkKind(), at, back + n, (if surf == "metal" then 10 else 5) * mul)
	emit(dustKind(surf), at, back * 0.6 + n * 0.8, 5 * mul)
	emit(chipKind(surf), at, back + n + Vector3.new(0, 0.6, 0), 4 * mul)
	-- trou de balle : sur le décor fixe seulement
	local inst = r.Instance
	if inst:IsA("Terrain") or (inst:IsA("BasePart") and inst.Anchored) then
		putDecal(pos, n, rand(0.16, 0.22) * U, Color3.fromRGB(12, 9, 5), 0.95)
	end
end

-- ---------- flamme de bouche des autres tireurs ----------
function ShotFx.muzzle(pos: Vector3, dir: Vector3, big: boolean)
	if (pos - camera.CFrame.Position).Magnitude > 300 then return end
	emit(flashKind(if big then "FlammeGrosse" else "Flamme", if big then 0.8 else 0.5, 0.05), pos, dir, 1)
	emit(kind("FumeeBouche", { life = { 0.5, 0.9 }, size = { 0.05, 0.28 }, speed = { 0.6, 1 }, color = Color3.new(0.75, 0.75, 0.75), alpha = 0.26,
		grav = -0.1, drag = 1.6, spread = 15, lit = true, rot = true }), pos, dir + Vector3.new(0, 0.25, 0), 1)
end

-- ---------- douilles (48, comme le web) ----------
type Shell = { p: Part, on: boolean, pos: Vector3, v: Vector3, rx: number, rz: number, wx: number, wz: number, ry: number, t: number, bounced: number, rest: boolean }
local shells: { Shell } = {}
local shIdx = 0
local BRASS = rgb(0xd4a73a)
local shellParams = RaycastParams.new(); shellParams.FilterType = Enum.RaycastFilterType.Exclude
function ShotFx.shell(pos: Vector3, right: Vector3)
	if low() then return end                       -- cfg.fx = 0 du web : pas de douilles
	shIdx = shIdx % 48 + 1
	local s = shells[shIdx]
	if not s then
		local p = Instance.new("Part")
		p.Name = "Douille"; p.Shape = Enum.PartType.Cylinder; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
		p.CastShadow = false; p.Color = BRASS; p.Material = Enum.Material.Metal; p.Reflectance = 0.15
		p.Size = Vector3.new(0.03 * U, 0.012 * U, 0.012 * U); p.Transparency = 1; p.Parent = folder
		s = { p = p, on = false, pos = pos, v = Vector3.zero, rx = 0, rz = 0, wx = 0, wz = 0, ry = 0, t = 0, bounced = 0, rest = false }
		shells[shIdx] = s
	end
	local sh = s :: Shell
	local r = Vector3.new(right.X, 0, right.Z)
	r = if r.Magnitude > 1e-3 then r.Unit else Vector3.xAxis
	local sp = rand(1.6, 2.6)
	sh.on = true; sh.rest = false; sh.pos = pos; sh.t = 2.4; sh.bounced = 0
	sh.v = (r * sp + Vector3.new(rand(-0.3, 0.3), rand(1.6, 2.6), rand(-0.3, 0.3))) * U
	sh.wx = rand(-14, 14); sh.wz = rand(-14, 14); sh.rx = rand(0, 6); sh.rz = rand(0, 6); sh.ry = math.atan2(r.X, r.Z)
	sh.p.Transparency = 0
end
-- notre douille : la fenêtre d'éjection du viewmodel (en mètres, collé à la caméra) ramenée à l'échelle du monde
function ShotFx.ownShell(vmPos: Vector3)
	local cf = camera.CFrame
	ShotFx.shell(cf.Position + (vmPos - cf.Position) * U, cf.RightVector)
end

-- ---------- taches de sang à la mort (stain du web : 6 taches de 0,25 à 0,55 m) ----------
local downParams = RaycastParams.new(); downParams.FilterType = Enum.RaycastFilterType.Exclude
function ShotFx.stain(pos: Vector3, ignore: Instance?)
	if not gore() then return end
	downParams.FilterDescendantsInstances = if ignore then { folder, camera, ignore } else { folder, camera }
	for _ = 1, 6 do
		local o = pos + Vector3.new(rand(-0.5, 0.5) * U, 0, rand(-0.5, 0.5) * U)
		local r = workspace:Raycast(o + Vector3.new(0, 1.5 * U, 0), Vector3.new(0, -4 * U, 0), downParams)
		if r and not humanoidModel(r.Instance) then putDecal(r.Position, r.Normal, rand(0.25, 0.55) * U, Color3.fromRGB(115, 10, 13), 0.8) end
	end
end

-- ---------- explosion : ce que l'explosion Roblox n'a pas (fxExplosion du web) ----------
function ShotFx.explosion(pos: Vector3, scale: number)
	local mul = fxMul()
	local up = Vector3.yAxis
	emit(kind("BouleDeFeu", { life = { 0.4, 0.8 }, size = { 1.2 * scale, 2.8 * scale }, speed = { 1, 5 * scale }, color = Color3.new(1, 0.55, 0.15),
		alpha = 0.95, grav = -0.5, drag = 2, spread = 50, rot = true }), pos + up * 0.3 * U, up, 16 * mul)
	emit(kind("FumeeNoire", { life = { 1.2, 2.6 }, size = { 1, 3.6 * scale }, speed = { 0.5, 4 * scale }, color = Color3.new(0.25, 0.23, 0.22),
		alpha = 0.7, grav = -0.4, drag = 1.2, spread = 70, lit = true, rot = true }), pos + up * 0.4 * U, up, 26 * mul)
	emit(kind("Debris", { life = { 0.5, 1 }, size = { 0.12, 0.2 }, speed = { 3, 10 }, color = Color3.new(0.55, 0.5, 0.45),
		trans = nseq({ { 0, 0.1 }, { 0.8, 0.1 }, { 1, 1 } }), grav = 12, drag = 0.3, spread = 75, lit = true }), pos + up * 0.2 * U, up, 20 * mul)
end

-- ---------- animation ----------
RunService.RenderStepped:Connect(function(dt: number)
	local camPos = camera.CFrame.Position
	for _, s in ipairs(streaks) do
		if not s.on then continue end
		s.d += s.speed * dt
		local k = 1
		if s.d >= s.L then
			s.d = s.L; s.fade += dt
			if s.fade > 0.05 then s.on = false; s.beam.Enabled = false; continue end
			k = 1 - s.fade / 0.05
			s.beam.Transparency = streakAlpha(k)
		end
		local head = s.o + s.dir * s.d * U
		local len = math.min(s.len, s.d)
		s.a0.WorldPosition = head
		s.a1.WorldPosition = head - s.dir * math.max(0.05, len) * U
		local cd = math.max(1, (head - camPos).Magnitude / U)
		local w = s.w * math.min(3, 0.6 + cd * 0.06) * U
		s.beam.Width0 = w; s.beam.Width1 = w
		s.beam.Enabled = true
	end
	local active = false
	for _, s in ipairs(shells) do
		if not s.on then continue end
		active = true
		s.t -= dt
		if s.t <= 0 then s.on = false; s.p.Transparency = 1; continue end
		if not s.rest then
			s.v -= Vector3.new(0, 14 * U * dt, 0)
			local step = s.v * dt
			local r = workspace:Raycast(s.pos, step + step.Unit * 0.02, shellParams)
			if r and not humanoidModel(r.Instance) then
				s.pos = r.Position + r.Normal * 0.006 * U
				if math.abs(s.v.Y) > 1 * U and s.bounced < 2 then
					s.v = Vector3.new(s.v.X * 0.5, -s.v.Y * 0.35, s.v.Z * 0.5); s.bounced += 1
				else
					s.rest = true; s.v = Vector3.zero
				end
			else
				s.pos += step
			end
			s.rx += s.wx * dt; s.rz += s.wz * dt
		end
		-- au repos, la douille est couchée (axe du cylindre à l'horizontale)
		s.p.CFrame = if s.rest then CFrame.new(s.pos + Vector3.new(0, 0.006 * U, 0)) * CFrame.Angles(0, s.ry + s.rx, 0)
			else CFrame.new(s.pos) * CFrame.Angles(s.rx, s.ry, s.rz)
	end
	if active then
		-- les douilles ne touchent pas les personnages ni les effets
		local ex: { Instance } = { folder, camera }
		for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(ex, p.Character) end end
		shellParams.FilterDescendantsInstances = ex
	end
end)

return ShotFx
