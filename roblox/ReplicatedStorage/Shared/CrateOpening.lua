--!strict
-- ReplicatedStorage/Shared/CrateOpening (ModuleScript, côté client)
-- Animation 3D d'ouverture de caisse du jeu web (src/8V_crate.js), dans un ViewportFrame :
--   1) 0 – 0,9 s : la caisse tombe en tournant, se pose (écrasement, anneau de poussière, secousse) ;
--   2) 1,1 – 2,9 s : suspense — les deux loquets sautent (1,5 s et 2,1 s, voyant rouge -> vert), la caisse tremble de
--      plus en plus, le couvercle se soulève par à-coups, la lumière fuit par les joints et monte de couleur jusqu'à la
--      rareté obtenue, la caméra s'approche ;
--   3) 2,9 s : ouverture — le couvercle s'ouvre sur ses charnières (ou part en l'air dès Légendaire, avec un ralenti),
--      étincelles, onde de choc, faisceau (Rare et +), rayons tournants et tourbillon (Épique et +), pluie de pièces
--      (Légendaire), l'objet sort et flotte au-dessus d'un socle holographique ; le texte arrive à +0,95 s.
-- Utilisation : CrateOpening.play(parent?, res, boxId, onDone?) où res est la réponse d'OpenBox
-- ({ rarity, item = { kind, weapon, skin, outfit, dance }, duplicate, coins }). parent = nil : l'écran a son propre
-- ScreenGui (au-dessus du menu). Renvoie une fonction qui ferme l'écran.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sfx = require(ReplicatedStorage.Shared.Sfx)

local CrateOpening = {}

local BOX_ACCENT = { std = Color3.fromHex("#4aa3ff"), prem = Color3.fromHex("#ffb938") }
local TAU = math.pi * 2

local function rcol(q: number): Color3
	local r = Config.RARITY[math.clamp(q + 1, 1, #Config.RARITY)]
	return r.color
end
local function smooth(x: number): number x = math.clamp(x, 0, 1); return x * x * (3 - 2 * x) end
local function rand(a: number, b: number): number return a + math.random() * (b - a) end
local function snd(id: string, pitch: number, vol: number)
	pcall(function() Sfx.play({ id = id, volume = vol, pitch = pitch }) end)
end

function CrateOpening.itemName(res: any): string
	local it = res.item or {}
	if it.kind == "skin" then
		return (Config.SKINS[it.skin] and Config.SKINS[it.skin].name or "Skin") .. " · " .. (Config.WEAPONS[it.weapon] and Config.WEAPONS[it.weapon].name or "")
	elseif it.kind == "dance" then return "Danse " .. (Config.DANCES[it.dance] and Config.DANCES[it.dance].name or "")
	elseif it.kind == "outfit" then return "Tenue " .. (Config.OUTFITS[it.outfit] and Config.OUTFITS[it.outfit].name or "") end
	return "+" .. tostring(res.coins or 0) .. " pièces"
end

local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local o = Instance.new(class)
	if o:IsA("GuiObject") then (o :: any).BorderSizePixel = 0 end
	for k, v in pairs(props) do (o :: any)[k] = v end
	if parent then o.Parent = parent end
	return o
end

-- pièce de décor : position locale dans son groupe (off), redessinée chaque image
type Piece = { p: Part, off: CFrame }
local function piece(list: { Piece }, parent: Instance, size: Vector3, off: CFrame, color: Color3, mat: Enum.Material?, shape: Enum.PartType?, transp: number?): Part
	local p = Instance.new("Part")
	p.Size = size; p.Color = color; p.Material = mat or Enum.Material.SmoothPlastic; p.Transparency = transp or 0
	if shape then p.Shape = shape end
	p.Anchored = true; p.CanCollide = false; p.CastShadow = false; p.CFrame = off
	p.Parent = parent
	table.insert(list, { p = p, off = off })
	return p
end
local function draw(list: { Piece }, base: CFrame)
	for _, e in ipairs(list) do e.p.CFrame = base * e.off end
end
local UPCYL = CFrame.Angles(0, 0, math.pi / 2)   -- cylindre Roblox couché sur X : redressé sur Y

function CrateOpening.play(parent: Instance?, res: any, boxId: string?, onDone: (() -> ())?): () -> ()
	local own: ScreenGui? = nil
	if not parent then
		local sg = Instance.new("ScreenGui"); sg.Name = "CrateOpening"; sg.IgnoreGuiInset = true; sg.ResetOnSpawn = false; sg.DisplayOrder = 80
		sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		sg.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		own = sg
	end
	local q = math.clamp((res.rarity or 1) - 1, 0, 4)
	local col = rcol(q)
	local acc = BOX_ACCENT[boxId or "std"] or BOX_ACCENT.std
	local prem = boxId == "prem"

	-- ---------- écran ----------
	local veil = make("TextButton", { Name = "CrateOpening", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(7, 11, 20),
		BackgroundTransparency = 0.08, ZIndex = 95, Modal = true }, parent or own)
	local vf = make("ViewportFrame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromScale(0.9, 0.78), BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(70, 80, 100), LightColor = Color3.fromRGB(220, 230, 255), LightDirection = Vector3.new(-0.4, -1, -0.6), ZIndex = 96 }, veil)
	make("UIAspectRatioConstraint", { AspectRatio = 1.6 }, vf)
	local cam = make("Camera", { FieldOfView = 42 }, vf)
	vf.CurrentCamera = cam
	local world = make("WorldModel", {}, vf)
	local flash = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = col, BackgroundTransparency = 1, ZIndex = 97 }, veil)
	local rar = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.8), Size = UDim2.new(0.9, 0, 0, 22), BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = acc, Text = "OUVERTURE…", ZIndex = 98 }, veil)
	local title = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.8, 24), Size = UDim2.new(0.9, 0, 0, 34), BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack, TextSize = 28, TextColor3 = col, Text = "", ZIndex = 98, TextTransparency = 1 }, veil)
	local sub = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.8, 62), Size = UDim2.new(0.9, 0, 0, 20), BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.fromRGB(141, 160, 189), Text = "", ZIndex = 98, TextTransparency = 1, RichText = true }, veil)
	local hint = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.new(0.9, 0, 0, 16), BackgroundTransparency = 1,
		Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Color3.fromRGB(141, 160, 189), Text = "", ZIndex = 98 }, veil)

	-- ---------- décor : sol, socle hexagonal, liseré, halo ----------
	local env: { Piece } = {}
	piece(env, world, Vector3.new(0.05, 9.2, 9.2), CFrame.new(0, 0, 0) * UPCYL, Color3.fromRGB(13, 20, 36), Enum.Material.Metal, Enum.PartType.Cylinder, 0.2)
	piece(env, world, Vector3.new(0.16, 3.7, 3.7), CFrame.new(0, 0.08, 0) * UPCYL, Color3.fromRGB(26, 34, 54), Enum.Material.Metal, Enum.PartType.Cylinder)
	piece(env, world, Vector3.new(0.1, 3.0, 3.0), CFrame.new(0, 0.21, 0) * UPCYL, Color3.fromRGB(26, 34, 54), Enum.Material.Metal, Enum.PartType.Cylinder)
	local rim = piece(env, world, Vector3.new(0.03, 3.3, 3.3), CFrame.new(0, 0.165, 0) * UPCYL, acc, Enum.Material.Neon, Enum.PartType.Cylinder)
	local halo = piece(env, world, Vector3.new(5.5, 5.5, 0.05), CFrame.new(0, 1.6, -2.5), acc, Enum.Material.Neon, Enum.PartType.Ball, 0.8)
	local motes: { Piece } = {}
	for _ = 1, 40 do piece(motes, world, Vector3.new(0.035, 0.035, 0.035), CFrame.new(rand(-5, 5), rand(0, 4.5), rand(-4, 2)), Color3.fromRGB(159, 200, 255), Enum.Material.Neon, Enum.PartType.Ball, 0.5) end
	draw(env, CFrame.new())

	-- ---------- la caisse ----------
	local W, H, D = 1.7, 0.9, 1.1
	local shell = if prem then Color3.fromRGB(42, 36, 24) else Color3.fromRGB(34, 43, 61)
	local trim = if prem then Color3.fromRGB(224, 176, 64) else Color3.fromRGB(154, 166, 184)
	local dark = Color3.fromRGB(11, 14, 20)
	local body: { Piece } = {}
	piece(body, world, Vector3.new(W, H, D), CFrame.new(0, H / 2, 0), shell, Enum.Material.Metal)
	for _, z in ipairs({ D / 2 + 0.006, -D / 2 - 0.006 }) do
		piece(body, world, Vector3.new(W - 0.24, H - 0.18, 0.012), CFrame.new(0, H / 2, z), Color3.fromRGB(28, 35, 51), Enum.Material.Metal)
		piece(body, world, Vector3.new(W - 0.36, 0.08, 0.016), CFrame.new(0, 0.2, z), acc, Enum.Material.Neon, nil, 0.3)           -- bande d'avertissement
		piece(body, world, Vector3.new(0.2, 0.2, 0.016), CFrame.new(0, H * 0.55, z) * CFrame.Angles(0, 0, math.rad(45)), acc, Enum.Material.Neon, nil, 0.1)   -- emblème
	end
	piece(body, world, Vector3.new(W + 0.04, 0.08, D + 0.04), CFrame.new(0, 0.06, 0), trim, Enum.Material.Metal)
	piece(body, world, Vector3.new(W + 0.04, 0.06, D + 0.04), CFrame.new(0, H - 0.03, 0), trim, Enum.Material.Metal)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			piece(body, world, Vector3.new(0.2, 0.2, 0.2), CFrame.new(sx * (W / 2 - 0.06), 0.1, sz * (D / 2 - 0.06)), trim, Enum.Material.Metal)
			piece(body, world, Vector3.new(0.2, 0.16, 0.2), CFrame.new(sx * (W / 2 - 0.06), H - 0.08, sz * (D / 2 - 0.06)), trim, Enum.Material.Metal)
		end
		piece(body, world, Vector3.new(0.05, 0.08, 0.34), CFrame.new(sx * (W / 2 + 0.02), H * 0.62, 0), dark, Enum.Material.Metal)   -- poignées
	end
	local seam = piece(body, world, Vector3.new(W - 0.02, 0.035, D - 0.02), CFrame.new(0, H + 0.005, 0), acc, Enum.Material.Neon, nil, 1)
	local inner = piece(body, world, Vector3.new(W - 0.16, 0.01, D - 0.16), CFrame.new(0, H - 0.04, 0), acc, Enum.Material.Neon, nil, 1)
	-- loquets : socle, levier (pivote), voyant
	type Latch = { lever: { Piece }, led: Part, at: CFrame, open: number, popped: boolean }
	local latches: { Latch } = {}
	for _, sx in ipairs({ -0.42, 0.42 }) do
		local at = CFrame.new(sx, H - 0.02, D / 2 + 0.03)
		piece(body, world, Vector3.new(0.16, 0.1, 0.05), at * CFrame.new(0, -0.02, 0), trim, Enum.Material.Metal)
		local led = piece(body, world, Vector3.new(0.044, 0.044, 0.044), at * CFrame.new(0, 0.04, 0.03), Color3.fromRGB(255, 51, 68), Enum.Material.Neon, Enum.PartType.Ball)
		local lever: { Piece } = {}
		piece(lever, world, Vector3.new(0.12, 0.2, 0.035), CFrame.new(0, -0.1, 0.02), dark, Enum.Material.Metal)
		piece(lever, world, Vector3.new(0.13, 0.04, 0.04), CFrame.new(0, -0.19, 0.03), trim, Enum.Material.Metal)
		table.insert(latches, { lever = lever, led = led, at = at, open = 0, popped = false })
	end
	-- fuites de lumière autour du joint
	local leaks: { Piece } = {}
	for i = 0, 9 do
		local a = i / 10 * TAU
		piece(leaks, world, Vector3.new(0.06, 1.6, 0.01), CFrame.new(math.cos(a) * 0.75, 0.3, math.sin(a) * 0.5) * CFrame.Angles(0, -a, math.cos(a) * 0.6), acc, Enum.Material.Neon, nil, 1)
	end
	-- couvercle sur charnières : pivot sur l'arête arrière
	local lid: { Piece } = {}
	piece(lid, world, Vector3.new(W + 0.02, 0.2, D + 0.02), CFrame.new(0, 0.1, D / 2), shell, Enum.Material.Metal)
	piece(lid, world, Vector3.new(W - 0.3, 0.06, D - 0.3), CFrame.new(0, 0.22, D / 2), shell, Enum.Material.Metal)
	piece(lid, world, Vector3.new(W + 0.06, 0.05, D + 0.06), CFrame.new(0, 0.02, D / 2), trim, Enum.Material.Metal)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do piece(lid, world, Vector3.new(0.2, 0.16, 0.2), CFrame.new(sx * (W / 2 - 0.06), 0.11, D / 2 + sz * (D / 2 - 0.06)), trim, Enum.Material.Metal) end
		piece(lid, world, Vector3.new(0.22, 0.1, 0.1), CFrame.new(sx * 0.55, 0.02, -0.02), trim, Enum.Material.Metal)   -- charnières
	end
	local emb = piece(lid, world, Vector3.new(0.012, 0.4, 0.4), CFrame.new(0, 0.256, D / 2) * UPCYL, acc, Enum.Material.Neon, Enum.PartType.Cylinder)

	-- ---------- état ----------
	local T = 0
	local hit, burst, shown = false, false, false
	local sq, pulse, shake = -1, 0, 0
	local crateY, crateRY, crateRX, crateRZ, lidRX = 6.5, -2.6, 0, 0, 0
	local scaleY, scaleXZ = 1, 1
	local dust: BasePart? = nil
	local lidFree: { cf: CFrame, v: Vector3, w: Vector3 }? = nil
	local sparks: { { p: Part, v: Vector3 } } = {}
	local beam: BasePart? = nil
	local rays: { Piece } = {}
	local swirl: { { p: Part, a: number, r: number, tilt: number } } = {}
	local wave: BasePart? = nil
	local coins: { { p: Part, v: Vector3, w: Vector3 } } = {}
	local glow: BasePart? = nil
	local holo: { BasePart } = {}
	local item: Model? = nil
	local itemBase = 1
	local done = false


	local function buildItem(): Model
		local it = res.item or {}
		local m: Model? = nil
		if it.kind == "skin" and it.weapon then
			pcall(function()
				local WeaponModels = require(ReplicatedStorage.Shared.WeaponModels) :: any
				local SkinPaint = require(ReplicatedStorage.Shared.SkinPaint) :: any
				local w = WeaponModels.build(it.weapon, 1)
				pcall(SkinPaint.apply, w, it.skin, nil)
				for _, d in ipairs(w:GetDescendants()) do if d:IsA("BasePart") then d.Anchored = true end end
				m = w
			end)
		end
		if not m then
			local g = Instance.new("Model")
			if it.kind == "coins" or not it.kind then
				for i = 0, 4 do
					local c = Instance.new("Part"); c.Shape = Enum.PartType.Cylinder; c.Material = Enum.Material.Metal; c.Color = Color3.fromRGB(242, 185, 40)
					c.Size = if i == 0 then Vector3.new(0.13, 0.84, 0.84) else Vector3.new(0.08, 0.48, 0.48); c.Anchored = true
					c.CFrame = if i == 0 then CFrame.Angles(0, math.pi / 2, 0) else CFrame.new(math.cos(i * 1.7) * 0.62, math.sin(i * 2.3) * 0.25 - 0.1, math.sin(i * 1.7) * 0.3 - 0.1) * CFrame.Angles(rand(-0.5, 0.5), math.pi / 2 + rand(-0.6, 0.6), 0)
					c.Parent = g
				end
			else
				local gem = Instance.new("Part"); gem.Material = Enum.Material.Neon; gem.Color = col; gem.Size = Vector3.new(0.7, 0.7, 0.7); gem.Anchored = true
				gem.CFrame = CFrame.Angles(math.rad(45), 0, math.rad(45)); gem.Parent = g
				local core = Instance.new("Part"); core.Material = Enum.Material.Glass; core.Transparency = 0.5; core.Color = Color3.new(1, 1, 1); core.Size = Vector3.new(0.95, 0.95, 0.95)
				core.Anchored = true; core.Shape = Enum.PartType.Ball; core.Parent = g
			end
			m = g
		end
		local model = m :: Model
		local ext = model:GetExtentsSize()
		itemBase = 1.6 / math.max(ext.X, ext.Y, ext.Z, 0.1)
		model.Parent = world
		return model
	end

	local function doBurst()
		burst = true
		crateRX, crateRZ, crateY = 0, 0, 0
		snd(if q >= 2 then "rbxasset://sounds/victory.wav" else "rbxasset://sounds/clickfast.wav", if q >= 2 then 1.1 else 0.6, 0.6)
		snd("rbxasset://sounds/Rocket shot.wav", 1.5, if q >= 3 then 0.6 else 0.25)
		if q >= 3 then lidFree = { cf = CFrame.new(0, H, -D / 2), v = Vector3.new(rand(-0.6, 0.6), 6.5, -2.5), w = Vector3.new(rand(-5, -3), rand(-2, 2), rand(-2, 2)) } end
		for _ = 1, math.min(140, 30 + q * 30) do
			local p = Instance.new("Part"); p.Shape = Enum.PartType.Ball; p.Material = Enum.Material.Neon; p.Color = col; p.Anchored = true; p.CanCollide = false
			local s = 0.06 + q * 0.015; p.Size = Vector3.new(s, s, s); p.Position = Vector3.new(rand(-0.5, 0.5), 1, rand(-0.3, 0.3)); p.Parent = world
			local a, sp = rand(0, TAU), rand(1, 2.5 + q)
			table.insert(sparks, { p = p, v = Vector3.new(math.cos(a) * sp, rand(2, 5 + q), math.sin(a) * sp * 0.6) })
		end
		if q >= 1 then
			local b = Instance.new("Part"); b.Shape = Enum.PartType.Cylinder; b.Material = Enum.Material.Neon; b.Color = col; b.Anchored = true; b.Transparency = 1
			b.Size = Vector3.new(14, 1.2 + q * 0.25, 1.2 + q * 0.25); b.CFrame = CFrame.new(0, 7, 0) * UPCYL; b.Parent = world; beam = b
		end
		if q >= 2 then
			local nr = if q >= 3 then 16 else 10
			for i = 0, nr - 1 do piece(rays, world, Vector3.new(0.5 + math.random() * 0.5, 10, 0.01), CFrame.Angles(0, 0, i / nr * math.pi + rand(-0.05, 0.05)), col, Enum.Material.Neon, nil, 1) end
			for i = 0, 2 do
				for j = 0, 15 do
					local p = Instance.new("Part"); p.Shape = Enum.PartType.Ball; p.Material = Enum.Material.Neon; p.Color = col; p.Anchored = true; p.Size = Vector3.new(0.05, 0.05, 0.05)
					p.Parent = world
					table.insert(swirl, { p = p, a = j / 16 * TAU, r = 0.7 + i * 0.18, tilt = rand(-0.5, 0.5) + i * 0.4 })
				end
			end
		end
		local w = Instance.new("Part"); w.Shape = Enum.PartType.Cylinder; w.Material = Enum.Material.Neon; w.Color = col; w.Anchored = true; w.Transparency = 0.1
		w.Size = Vector3.new(0.02, 2, 2); w.CFrame = CFrame.new(0, 0.3, 0) * UPCYL; w.Parent = world; wave = w
		local g = Instance.new("Part"); g.Shape = Enum.PartType.Ball; g.Material = Enum.Material.Neon; g.Color = col; g.Anchored = true; g.Transparency = 1
		g.Size = Vector3.new(3.2, 3.2, 0.05); g.CFrame = CFrame.new(0, 2.3, -0.4); g.Parent = world; glow = g
		for i = 0, 1 do
			local r = Instance.new("Part"); r.Shape = Enum.PartType.Cylinder; r.Material = Enum.Material.Neon; r.Color = col; r.Anchored = true; r.Transparency = 1
			r.Size = Vector3.new(0.01, 1.2 + i * 0.28, 1.2 + i * 0.28); r.Parent = world
			table.insert(holo, r)
		end
		local it = res.item or {}
		if q >= 3 or (it.kind == "coins" and (res.coins or 0) >= 300) then
			for _ = 1, if q >= 3 then 40 else 18 do
				local c = Instance.new("Part"); c.Shape = Enum.PartType.Cylinder; c.Material = Enum.Material.Metal; c.Color = Color3.fromRGB(242, 185, 40); c.Anchored = true
				c.Size = Vector3.new(0.02, 0.14, 0.14); c.Position = Vector3.new(rand(-2.5, 2.5), rand(4, 9), rand(-1.5, 1)); c.Parent = world
				table.insert(coins, { p = c, v = Vector3.new(0, -rand(1, 3), 0), w = Vector3.new(rand(-8, 8), rand(-8, 8), rand(-8, 8)) })
			end
		end
		item = buildItem()
		inner.Color = col; inner.Transparency = 0.1; seam.Color = col
		flash.BackgroundColor3 = col
		flash.BackgroundTransparency = 1 - (if q >= 3 then 0.85 elseif q >= 2 then 0.6 elseif q >= 1 then 0.4 else 0.2)
		vf.Ambient = col:Lerp(Color3.fromRGB(70, 80, 100), 0.5)
		shake = if q >= 3 then 0.5 elseif q >= 2 then 0.25 else 0.1
	end

	local conn: RBXScriptConnection? = nil
	local function close()
		if done then return end
		done = true
		if conn then conn:Disconnect() end
		veil:Destroy()
		if own then own:Destroy() end
		if onDone then task.spawn(onDone) end
	end
	veil.Activated:Connect(function() if shown then close() end end)

	snd("rbxasset://sounds/swoosh.wav", 1.1, 0.4)
	conn = RunService.RenderStepped:Connect(function(rdt: number)
		local dt = math.min(0.05, rdt)
		if burst and q >= 3 and T - 2.9 < 0.5 then dt *= 0.45 end   -- petit ralenti pour un légendaire
		T += dt
		shake = math.max(0, shake - dt * 1.5)
		flash.BackgroundTransparency = math.min(1, flash.BackgroundTransparency + dt * 1.6)
		-- 1) chute
		if T < 0.9 then
			local k = T / 0.9
			crateY = 6.5 * (1 - k * k); crateRY = -2.6 + smooth(k) * 2.25
		elseif not hit then
			hit = true; crateY = 0; crateRY = -0.35; shake = 0.35
			snd("rbxasset://sounds/Rocket shot.wav", 0.5, 0.15); snd("rbxasset://sounds/clickfast.wav", 0.5, 0.5)
			local d = Instance.new("Part"); d.Shape = Enum.PartType.Cylinder; d.Material = Enum.Material.SmoothPlastic; d.Color = Color3.fromRGB(200, 190, 170)
			d.Anchored = true; d.Transparency = 0.4; d.Size = Vector3.new(0.01, 2.4, 2.4); d.CFrame = CFrame.new(0, 0.28, 0) * UPCYL; d.Parent = world; dust = d
		end
		if T >= 0.9 and T < 1.3 then
			local k = (T - 0.9) / 0.4
			scaleXZ = 1 + math.sin(k * math.pi) * 0.06 * (1 - k); scaleY = 1 - math.sin(k * math.pi) * 0.1 * (1 - k)
		else scaleXZ, scaleY = 1, 1 end
		if dust then
			local k = (T - 0.9) / 1.2
			local s = 2.4 * (1 + k * 2.5)
			dust.Size = Vector3.new(0.01, s, s); dust.Transparency = math.min(1, 0.4 + k * 0.6)
		end
		-- 2) suspense
		if T >= 1.1 and T < 2.9 then
			local k = (T - 1.1) / 1.8
			local s2 = math.min(q, math.floor(k * k * (q + 1.3)))
			local sc = rcol(s2)
			if s2 ~= sq then sq = s2; pulse = 1; snd("rbxasset://sounds/clickfast.wav", 1.4 + s2 * 0.2, 0.45) end
			pulse = math.max(0, pulse - dt * 3)
			for i, L in ipairs(latches) do
				local at = 1.5 + (i - 1) * 0.6
				if T >= at and not L.popped then L.popped = true; L.led.Color = Color3.fromRGB(61, 255, 122); shake = math.max(shake, 0.12); snd("rbxasset://sounds/clickfast.wav", 1, 0.7) end
				if L.popped then L.open = math.min(1, L.open + dt * 9) end
			end
			local sh = k * k
			crateY = math.abs(math.sin(T * (9 + k * 20))) * 0.05 * sh
			crateRZ = math.sin(T * (21 + k * 30)) * 0.05 * sh
			crateRX = math.cos(T * (17 + k * 25)) * 0.035 * sh
			lidRX = -math.max(0, math.sin(T * (14 + k * 22))) * 0.05 * sh
			seam.Transparency = 1 - (0.15 + k * 0.85); seam.Color = sc
			for _, e in ipairs(leaks) do e.p.Transparency = 1 - math.min(1, k * k * 0.5 + pulse * 0.3); e.p.Color = sc end
			emb.Color = sc; rim.Color = sc; halo.Color = sc; halo.Transparency = 1 - (0.25 + k * 0.35)
			vf.Ambient = Color3.fromRGB(70, 80, 100):Lerp(sc, math.min(1, k * 0.35 + pulse * 0.4))
			if math.random() < k * 0.35 * dt * 60 * 0.1 then snd("rbxasset://sounds/clickfast.wav", 2, 0.2) end
		end
		-- 3) ouverture
		if T >= 2.9 and not burst then doBurst() end
		local crateCF = CFrame.new(0, crateY, 0) * CFrame.Angles(0, crateRY, 0) * CFrame.Angles(crateRX, 0, crateRZ)
		if burst then
			local k = T - 2.9
			if lidFree then
				local lf = lidFree :: { cf: CFrame, v: Vector3, w: Vector3 }
				lf.v -= Vector3.new(0, 12 * dt, 0)
				lf.cf = (lf.cf + lf.v * dt) * CFrame.Angles(lf.w.X * dt, lf.w.Y * dt, lf.w.Z * dt)
			else
				local a = math.min(1, k / 0.45)
				local ov = if a < 1 then smooth(a) * 1.18 else 1.18 - math.sin(math.min(1, (k - 0.45) / 0.5) * math.pi) * 0.08 * math.exp(-(k - 0.45) * 3)
				lidRX = -ov * 1.62
			end
			for _, e in ipairs(leaks) do e.p.Transparency = math.min(1, e.p.Transparency + dt * 1.5) end
			seam.Transparency = 1 - math.max(0, 0.9 - k * 2)
			inner.Transparency = 1 - math.max(0.35, 0.9 - k * 0.4)
			for _, s in ipairs(sparks) do
				s.v = (s.v - Vector3.new(0, 6 * dt, 0)) * (1 - dt * 0.6)
				s.p.Position += s.v * dt
				s.p.Transparency = math.min(1, k / 2.4)
			end
			if beam then beam.Transparency = 1 - math.min(0.55, k * 3) * math.max(0.25, 1 - k * 0.3) * (0.6 + q * 0.15) end
			if #rays > 0 then
				local rot = T * (if q >= 3 then 0.6 else 0.35)
				local sc = math.min(1, k * 1.8)
				for _, e in ipairs(rays) do
					e.p.Transparency = 1 - math.min(0.32 + q * 0.05, k * 1.2)
					e.p.Size = Vector3.new(e.p.Size.X, 10 * math.max(0.05, sc), 0.01)
				end
				draw(rays, CFrame.new(0, 2.3, -1.2) * CFrame.Angles(0, 0, rot))
			end
			for _, s in ipairs(swirl) do
				s.a += dt * 2.2
				local sc = math.min(1, k * 1.5)
				local pos = CFrame.new(0, 2.3, 0) * CFrame.Angles(s.tilt, 0, s.tilt * 0.5) * CFrame.new(math.cos(s.a) * s.r * sc, 0, math.sin(s.a) * s.r * sc)
				s.p.CFrame = pos
				s.p.Transparency = 1 - math.min(0.7, k) * (0.6 + 0.4 * math.sin(T * 3 + s.r * 9))
			end
			if wave then
				local sk = math.min(1, k / 0.9)
				local s = 2 * (1 + sk * (5 + q * 1.5))
				wave.Size = Vector3.new(0.02, s, s); wave.Transparency = math.min(1, 0.1 + sk)
			end
			if glow then glow.Transparency = 1 - math.min(0.42, k) * (0.85 + 0.15 * math.sin(T * 3)) end
			for _, c in ipairs(coins) do
				c.v -= Vector3.new(0, 6 * dt, 0)
				local p = c.p.Position + c.v * dt
				if p.Y < 0.32 then p = Vector3.new(p.X, 0.32, p.Z); c.v = Vector3.new(c.v.X, math.abs(c.v.Y) * 0.3, c.v.Z); c.w *= 0.7 end
				c.p.CFrame = CFrame.new(p) * c.p.CFrame.Rotation * CFrame.Angles(c.w.X * dt, 0, c.w.Z * dt)
			end
			local ik = smooth(math.min(1, k / 0.9))
			if item then
				local mdl = item :: Model
				pcall(function() mdl:ScaleTo(math.max(0.01, itemBase * (0.01 + ik * 0.99))) end)
				mdl:PivotTo(CFrame.new(0, 1.0 + ik * 1.3 + math.sin(T * 2) * 0.05, 0) * CFrame.Angles(0, T * 1.1, 0))
			end
			for i, r in ipairs(holo) do
				r.CFrame = CFrame.new(0, 1.0 + ik * 0.45, 0) * CFrame.Angles(0, T, 0) * UPCYL
				r.Transparency = 1 - ik * 0.55 * (1 + math.sin(T * 3 + i) * 0.04)
			end
			rim.Transparency = 0.45 - 0.25 * math.sin(T * 4)
			if k > 0.95 and not shown then
				shown = true
				rar.Text = string.upper(Config.RARITY[q + 1].name); rar.TextColor3 = col
				title.Text = CrateOpening.itemName(res); title.TextTransparency = 0
				sub.Text = if res.duplicate then "Doublon — converti en <b>" .. tostring(res.coins) .. " pièces</b>"
					elseif (res.item or {}).kind == "coins" then "Pièces ajoutées à ton solde" else "<b>NOUVEAU !</b> Ajouté à ta collection"
				sub.TextTransparency = 0
				hint.Text = "Clique pour continuer"
			end
		end
		-- dessin de la caisse
		local bcf = crateCF * CFrame.new(0, 0, 0)
		for _, e in ipairs(body) do
			local o = e.off
			e.p.CFrame = bcf * CFrame.new(o.Position.X * scaleXZ, o.Position.Y * scaleY, o.Position.Z * scaleXZ) * o.Rotation
		end
		for _, L in ipairs(latches) do draw(L.lever, bcf * CFrame.new(L.at.Position.X * scaleXZ, L.at.Position.Y * scaleY, L.at.Position.Z * scaleXZ) * CFrame.Angles(L.open * 1.3, 0, 0)) end
		draw(leaks, bcf * CFrame.new(0, H * scaleY, 0) * CFrame.Angles(0, T * 0.8, 0))
		if lidFree then draw(lid, crateCF * (lidFree :: any).cf)
		else draw(lid, bcf * CFrame.new(0, H * scaleY, -D / 2 * scaleXZ) * CFrame.Angles(lidRX, 0, 0)) end
		-- poussières qui montent
		for _, e in ipairs(motes) do
			local p = e.p.Position
			e.p.Position = Vector3.new(p.X, if p.Y > 4.5 then 0 else p.Y + dt * 0.12, p.Z)
		end
		-- caméra : s'approche pendant le suspense, recule à l'ouverture, tremble aux chocs
		local cz, cy = 6.4, 2.0
		if T > 1.1 and T < 2.9 then cz -= smooth((T - 1.1) / 1.8) * 0.9 end
		if burst then local k = T - 2.9; cz = 5.5 + smooth(math.min(1, k / 0.6)) * 0.9; cy = 2.0 + smooth(math.min(1, k / 0.8)) * 0.35 end
		local shk = shake * shake
		local pos = Vector3.new(math.sin(T * 0.45) * 0.5 + rand(-1, 1) * shk * 0.3, cy + math.sin(T * 0.4) * 0.1 + rand(-1, 1) * shk * 0.3, cz)
		cam.CFrame = CFrame.lookAt(pos, Vector3.new(0, if burst then 1.7 else 1.0, 0))
		if T > 12 and shown then close() end
	end)
	return close
end

return CrateOpening
