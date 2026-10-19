--!strict
-- ReplicatedStorage/Shared/ArsenalPanels (ModuleScript, côté client)
-- Les panneaux « Arsenal › Armes » et « Arsenal › Viseurs » du jeu web, à l'identique :
--   arms(parent)   : liste des armes (icônes 3D), aperçu 3D qui tourne (rendu réaliste / schéma 3D / vue éclatée,
--                    clique-glisse pour tourner), nom, 10 statistiques avec comparaison ▲▼ au survol, ARMURIER
--                    (6 emplacements, options avec cadenas et conditions de déblocage), skins + « Équiper au départ »
--                    (src/85_menu.js, 88_blueprint.js, 64b_gunsmith.js)
--   sights(parent) : armes par catégorie, aperçu du stand de tir vu à travers le viseur, liste des viseurs avec
--                    grossissement, forme + couleur du réticule, « mettre ce viseur sur toutes les armes » (64c_sights.js)
-- Chaque fonction construit tout dans le cadre donné et renvoie { destroy = fn, refresh = fn }.
-- Les choix passent par le serveur (RemoteFunction « Armory », ArmoryService) qui vérifie et sauvegarde.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local A = require(ReplicatedStorage.Shared.Attachments)
local WeaponModels = require(ReplicatedStorage.Shared.WeaponModels)
local SkinPaint = require(ReplicatedStorage.Shared.SkinPaint)
local ReticleGui = require(ReplicatedStorage.Shared.ReticleGui)
local Sfx = require(ReplicatedStorage.Shared.Sfx)

local player = Players.LocalPlayer
local P = {}

-- ---------- palette et outils (CSS du web) ----------
local function rgb(h: number): Color3 return Color3.fromRGB(bit32.rshift(h, 16), bit32.band(bit32.rshift(h, 8), 255), bit32.band(h, 255)) end
local C = {
	bg = rgb(0x0b1018), panel = rgb(0x0d121d), card = rgb(0x121b2b), card2 = rgb(0x141c2c), line = rgb(0x2a3750), text = rgb(0xe8eef9), white = Color3.new(1, 1, 1),
	dim = rgb(0x8da0bd), dim2 = rgb(0x6f819e), soft = rgb(0xb8c5da), opt = rgb(0xdfe8f5), accent = rgb(0xff4655), orange = rgb(0xff9a3c), orangeT = rgb(0xffb35c),
	green = rgb(0x5dff8a), greenBg = rgb(0x142619), red = rgb(0xff5a5a), gold = rgb(0xffd75e), slotOn = rgb(0x1d1a17), dark = rgb(0x16191e),
}
local RARITY = { rgb(0x9aa6b8), rgb(0x4aa3ff), rgb(0xb36bff), rgb(0xffb938), rgb(0xff3df0) }
local function spaced(s: string, n: number?): string
	local gap = if (n or 1) >= 2 then "\u{2009}" else "\u{200A}"   -- espaces fines
	local out = {}
	for _, cp in utf8.codes(s) do table.insert(out, utf8.char(cp)) end
	return table.concat(out, gap)
end
local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local o: any = Instance.new(class)
	if class == "TextLabel" or class == "TextButton" then
		o.Font = Enum.Font.GothamBold; o.TextColor3 = C.text; o.BorderSizePixel = 0; o.TextSize = 13
		if class == "TextLabel" then o.BackgroundTransparency = 1 end
		if class == "TextButton" then o.AutoButtonColor = false end
	elseif class == "Frame" or class == "ScrollingFrame" then o.BorderSizePixel = 0 end
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(o: Instance, r: number?) make("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o) end
local function stroke(o: Instance, col: Color3, t: number?, tr: number?): UIStroke
	return make("UIStroke", { Color = col, Thickness = t or 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local function pad(o: Instance, p: number) make("UIPadding", { PaddingLeft = UDim.new(0, p), PaddingRight = UDim.new(0, p), PaddingTop = UDim.new(0, p), PaddingBottom = UDim.new(0, p) }, o) end
local function vlist(o: Instance, gap: number) return make("UIListLayout", { Padding = UDim.new(0, gap), SortOrder = Enum.SortOrder.LayoutOrder }, o) end
local function clear(o: Instance) for _, c in ipairs(o:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end end
local function sfx(name: string, vol: number?) pcall(Sfx.play, name, nil, vol) end
-- puce (.chip du web)
local function chip(parent: Instance, text: string, on: boolean, order: number?): TextButton
	local b = make("TextButton", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 28), Text = text, TextSize = 12, LayoutOrder = order or 0,
		BackgroundColor3 = if on then C.accent else C.card2, TextColor3 = C.white }, parent)
	pad(b, 0); make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, b)
	corner(b, 4); stroke(b, if on then C.accent else C.line, 1, if on then 0 else .2)
	return b
end
local function hflow(o: Instance, gap: number) return make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Wraps = true, Padding = UDim.new(0, gap), SortOrder = Enum.SortOrder.LayoutOrder }, o) end
local function header(parent: Instance, text: string, order: number, col: Color3?): TextLabel
	return make("TextLabel", { Size = UDim2.new(1, 0, 0, 22), Text = spaced(string.upper(text), 2), TextSize = 10, TextColor3 = col or C.dim,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Bottom, LayoutOrder = order }, parent)
end

-- ---------- données partagées (profil côté serveur) ----------
local D = { att = {} :: { [string]: A.Sel }, ret = {} :: { [string]: string }, prog = { level = 1, kills = {} } :: A.Prog, profile = nil :: any, loaded = false }
local changed = Instance.new("BindableEvent")
local armory: RemoteFunction? = nil
local function remote(): RemoteFunction?
	if not armory then armory = ReplicatedStorage:WaitForChild("Armory", 10) :: RemoteFunction? end
	return armory
end
local function load()
	local r = remote()
	if r then
		local ok, data = pcall(r.InvokeServer, r, "get")
		if ok and typeof(data) == "table" then
			D.att = data.att or {}; D.ret = data.ret or {}; D.prog = { level = data.level or 1, kills = data.kills or {} }
		end
	end
	local gp = ReplicatedStorage:FindFirstChild("GetProfile") :: RemoteFunction?
	if gp then
		local ok, data = pcall(gp.InvokeServer, gp)
		if ok and typeof(data) == "table" then D.profile = data.profile end
	end
	D.loaded = true
	changed:Fire()
end
local function selOf(k: string): A.Sel return D.att[k] or {} end
local function retOf(o: string): (string, string)
	local d = A.RET_DEF[o] or A.RET_DEF.reddot
	local raw = D.ret[o]
	if typeof(raw) == "string" then
		local s, c = string.match(raw, "^(%w+)|(#%x+)$")
		if s and c then return s, c end
	end
	return d.s, d.c
end

-- toast en bas du panneau (uiToast du web)
local function toaster(root: GuiObject): (string) -> ()
	local t = make("TextLabel", { AnchorPoint = Vector2.new(.5, 1), Position = UDim2.new(.5, 0, 1, -10), Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = rgb(0x161f33), BackgroundTransparency = 0, Text = "", TextSize = 13, TextColor3 = C.white, Visible = false, ZIndex = 30 }, root)
	make("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) }, t); stroke(t, C.gold); corner(t, 4)
	local id = 0
	return function(msg: string)
		id += 1
		local my = id
		t.Text = msg; t.Visible = true
		task.delay(2.4, function() if id == my then t.Visible = false end end)
	end
end

local CATS: { { any } } = {
	{ "Couteau", { "knife" } }, { "Pistolets", { "glock", "usp", "p250", "fiveseven", "deagle" } }, { "SMG", { "mac10", "mp9", "ump", "p90" } },
	{ "Pompes", { "nova", "sawedoff", "xm" } }, { "Fusils", { "galil", "famas", "ak", "m4", "sg553", "aug" } }, { "Snipers", { "ssg", "awp", "scar" } },
	{ "Lourd", { "negev", "m249" } },
}
local SIGHT_CATS = { { "pistol", "Pistolets" }, { "smg", "Mitraillettes" }, { "shotgun", "Pompes" }, { "rifle", "Fusils" }, { "lmg", "Mitrailleuses" }, { "sniper", "Snipers" } }
local SIGHT_WEAPONS: { [string]: { string } } = {}
for _, c in ipairs(CATS) do
	for _, k in ipairs(c[2]) do
		local w = Config.WEAPONS[k]
		if w and A.allowed(k).optic then SIGHT_WEAPONS[w.cat] = SIGHT_WEAPONS[w.cat] or {}; table.insert(SIGHT_WEAPONS[w.cat], k) end
	end
end
local current = { key = nil :: string? }
local function defaultKey(): string
	if current.key and Config.WEAPONS[current.key] then return current.key end
	local p = player:GetAttribute("Primary")
	return if typeof(p) == "string" and Config.WEAPONS[p] then p else "ak"
end

-- icône 3D d'une arme (vue de côté, comme weaponIcon du web)
local function weaponIcon(parent: Instance, key: string, size: Vector2, pos: UDim2?): ViewportFrame
	local vf = make("ViewportFrame", { Size = UDim2.fromOffset(size.X, size.Y), Position = pos or UDim2.new(), BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 175, 190), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(.4, -1, .3) }, parent)
	task.spawn(function()
		local ok, m = pcall(WeaponModels.build, key, 1)
		if not ok or not m or not vf.Parent then if ok and m then (m :: Model):Destroy() end return end
		local model = m :: Model
		SkinPaint.apply(model, player:GetAttribute("Skin_" .. key) :: number?, player:GetAttribute("Camo_" .. key) :: string?)
		model.Parent = vf
		local cf, ext = model:GetBoundingBox()
		local cam = Instance.new("Camera"); cam.FieldOfView = 16
		local tv = math.tan(math.rad(8))
		local dist = math.max(ext.Y / 2 / tv, ext.Z / 2 / (tv * size.X / size.Y)) * 1.12 + ext.X
		cam.CFrame = CFrame.lookAt(cf.Position - Vector3.new(dist, 0, 0), cf.Position)
		cam.Parent = vf; vf.CurrentCamera = cam
	end)
	return vf
end

-- =====================================================================================
-- ARSENAL › ARMES (+ ARMURIER)
-- =====================================================================================
function P.arms(parent: Frame): { destroy: () -> (), refresh: () -> () }
	local root = make("Frame", { Name = "ArsenalArms", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true }, parent)
	local toast = toaster(root)
	local conns: { RBXScriptConnection } = {}
	-- colonnes : liste (210) | aperçu + stats + armurier | skins (240)
	local wl = make("ScrollingFrame", { Size = UDim2.new(0, 200, 1, 0), BackgroundTransparency = 1, ScrollBarThickness = 4, ScrollBarImageColor3 = C.line,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new() }, root)
	vlist(wl, 4)
	local mid = make("ScrollingFrame", { Position = UDim2.fromOffset(216, 0), Size = UDim2.new(1, -216 - 256, 1, 0), BackgroundTransparency = 1, ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.line, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new() }, root)
	vlist(mid, 8)
	local skl = make("ScrollingFrame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 240, 1, 0), BackgroundTransparency = 1,
		ScrollBarThickness = 4, ScrollBarImageColor3 = C.line, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new() }, root)
	vlist(skl, 6)

	local st = { key = defaultKey(), prev = nil :: A.Sel?, slot = "muzzle", mode = "real", spin = true, rx = 0, ry = math.pi * .55, drag = nil :: Vector2?, token = 0 }
	local chips: { [string]: TextButton } = {}

	-- ----- aperçu 3D -----
	local pvBox = make("Frame", { Size = UDim2.new(1, 0, 0, 300), BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = 1 }, mid)
	corner(pvBox, 4)
	local pvGrad = make("UIGradient", { Rotation = 90, Color = ColorSequence.new(rgb(0x16233b), rgb(0x2d4a72)) }, pvBox)
	local vp = make("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = Color3.fromRGB(120, 130, 150),
		LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-.5, -1, -.4) }, pvBox)
	local cam = Instance.new("Camera"); cam.FieldOfView = 30; cam.Parent = vp; vp.CurrentCamera = cam
	local floor = make("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(.02, 2.6, 2.6), Color = rgb(0x1a2438), Material = Enum.Material.Metal, Anchored = true,
		CFrame = CFrame.new(0, -.36, 0) * CFrame.Angles(0, 0, math.rad(90)) }, vp)
	local _ = floor
	local pv = { model = nil :: Model?, center = Vector3.zero, size = 1, parts = {} :: { { p: BasePart, off: Vector3 } } }

	local modeBar = make("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = 2 }, mid)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6) }, modeBar)
	make("TextLabel", { Size = UDim2.new(1, 0, 0, 14), Text = "Clique-glisse sur l'arme pour la tourner", TextSize = 11, Font = Enum.Font.Gotham, TextColor3 = C.dim2, LayoutOrder = 3 }, mid)
	local nameL = make("TextLabel", { Size = UDim2.new(1, 0, 0, 34), Text = "", TextSize = 26, Font = Enum.Font.GothamBlack, TextColor3 = C.white, LayoutOrder = 4 }, mid)
	local statsBox = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 5 }, mid)
	make("UIGridLayout", { CellSize = UDim2.new(.2, -5, 0, 54), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }, statsBox)
	local gs = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = rgb(0x0b1220), BackgroundTransparency = .2, LayoutOrder = 6 }, mid)
	corner(gs, 10); stroke(gs, C.white, 1, .9); pad(gs, 10); vlist(gs, 8)

	local function curList(k: string, sel: A.Sel?): { string } return A.list(k, sel or selOf(k), D.prog) end

	local function applyMode()
		local m = pv.model
		if not m then return end
		local schem = st.mode == "schema"
		for _, c in ipairs(m:GetDescendants()) do
			if c:IsA("BasePart") then
				if c:GetAttribute("C0") == nil then c:SetAttribute("C0", c.Color); c:SetAttribute("M0", c.Material.Name); c:SetAttribute("T0", c.Transparency) end
				if schem then c.Color = rgb(0x9fe3ff); c.Material = Enum.Material.SmoothPlastic; c.Transparency = .72
				else c.Color = c:GetAttribute("C0") :: Color3; c.Material = (Enum.Material :: any)[c:GetAttribute("M0") :: string]; c.Transparency = c:GetAttribute("T0") :: number end
			end
		end
		pvGrad.Color = if schem then ColorSequence.new(rgb(0x0a2a4d)) else ColorSequence.new(rgb(0x16233b), rgb(0x2d4a72))
		floor.Transparency = if schem then 1 else 0
	end
	local function drawModes()
		clear(modeBar)
		for i, mdef in ipairs({ { "real", "Rendu réaliste" }, { "schema", "Schéma 3D" }, { "explode", "Vue éclatée" } }) do
			local b = chip(modeBar, mdef[2], st.mode == mdef[1], i)
			b.MouseButton1Click:Connect(function() sfx("ui"); st.mode = mdef[1]; applyMode(); drawModes() end)
		end
		local r = chip(modeBar, if st.spin then "⟳ Rotation auto" else "⟳ Rotation fixe", st.spin, 9)
		r.MouseButton1Click:Connect(function() sfx("ui"); st.spin = not st.spin; drawModes() end)
	end

	local function setPreview()
		st.token += 1
		local my, k = st.token, st.key
		local sel = st.prev or selOf(k)
		task.spawn(function()
			local list = curList(k, sel)
			local ok, m = pcall(WeaponModels.build, k, 1, list, { preview = true, ret = retOf })
			if my ~= st.token or not root.Parent then if ok and m then (m :: Model):Destroy() end return end
			if not ok or not m then warn("[Arsenal]", m) return end
			if pv.model then pv.model:Destroy() end
			local model = m :: Model
			SkinPaint.apply(model, player:GetAttribute("Skin_" .. k) :: number?, player:GetAttribute("Camo_" .. k) :: string?)
			WeaponModels.place(model, CFrame.identity)
			local cf, ext = model:GetBoundingBox()
			pv.center = cf.Position; pv.size = math.max(ext.X, ext.Z, .3)
			pv.parts = {}
			for _, c in ipairs(model:GetDescendants()) do
				if c:IsA("BasePart") then table.insert(pv.parts, { p = c, off = c.Position - pv.center }) end
			end
			model.Parent = vp
			pv.model = model
			applyMode()
		end)
	end

	-- ----- statistiques (gsStatsHTML) -----
	local function drawStats()
		clear(statsBox)
		local k = st.key
		local w = Config.WEAPONS[k]
		local cur = A.modsOf(curList(k))
		local nw = A.modsOf(curList(k, st.prev or selOf(k)))
		local rows = if w.melee then { A.statRows(k)[1] } else A.statRows(k)
		for i, r in ipairs(rows) do
			local label: string, f: (A.Mods) -> number, mx: number, fmt: (number) -> string, dir: number = (r :: any)[1], (r :: any)[2], (r :: any)[3], (r :: any)[4], (r :: any)[5]
			local v0, v1 = f(cur), f(nw)
			if w.melee then v0 = w.dmg; v1 = w.dmg; mx = 120 end
			local diff = v1 - v0
			local good: boolean? = nil
			if dir ~= 0 and math.abs(diff) > 1e-6 then good = diff * dir > 0 end
			local a = math.clamp(math.min(v0, v1) / mx * 100, 2, 100)
			local b = math.clamp(math.max(v0, v1) / mx * 100, 2, 100)
			local col = if good == nil then C.white elseif good then C.green else C.red
			local box = make("Frame", { BackgroundColor3 = C.panel, BackgroundTransparency = .1, LayoutOrder = i }, statsBox)
			stroke(box, C.line, 1, .3)
			make("TextLabel", { Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 12), Text = spaced(label, 1), TextSize = 9, TextColor3 = C.dim }, box)
			make("TextLabel", { Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 20), Text = fmt(v1) .. (if good == nil then "" elseif good then " ▲" else " ▼"),
				TextSize = 17, Font = Enum.Font.GothamBlack, TextColor3 = col }, box)
			local bar = make("Frame", { AnchorPoint = Vector2.new(.5, 1), Position = UDim2.new(.5, 0, 1, -6), Size = UDim2.new(1, -12, 0, 3), BackgroundColor3 = rgb(0x1c2538) }, box)
			make("Frame", { Size = UDim2.fromScale(a / 100, 1), BackgroundColor3 = C.accent }, bar)
			if good ~= nil then make("Frame", { Position = UDim2.fromScale(a / 100, 0), Size = UDim2.fromScale((b - a) / 100, 1), BackgroundColor3 = col }, bar) end
		end
	end

	-- ----- armurier (gsDraw) -----
	local drawGs: () -> ()
	local function equip(k: string, slot: string, a: string?)
		local r = remote()
		if not r then return end
		local ok, res = pcall(r.InvokeServer, r, "set", k, slot, a or "")
		if ok and typeof(res) == "table" then
			if res.att then D.att = res.att end
			if res.ok then sfx("reload", .35) else sfx("ui"); if res.msg then toast(res.msg) end end
		end
		st.prev = nil
		changed:Fire()
	end
	drawGs = function()
		clear(gs)
		local k = st.key
		local ok = A.allowed(k)
		local sel = selOf(k)
		local any = false
		for _ in pairs(ok) do any = true end
		local head = make("Frame", { Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, LayoutOrder = 1 }, gs)
		make("TextLabel", { Size = UDim2.fromScale(.4, 1), Text = spaced("ARMURIER", 2), TextSize = 12, Font = Enum.Font.GothamBlack, TextColor3 = C.orange, TextXAlignment = Enum.TextXAlignment.Left }, head)
		if not any then
			make("TextLabel", { Size = UDim2.new(1, 0, 0, 16), Text = "Pas d'accessoires pour cette arme.", TextSize = 12, Font = Enum.Font.Gotham, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2 }, gs)
			return
		end
		if not ok[st.slot] then for _, s in ipairs(A.SLOTS) do if ok[s.id] then st.slot = s.id; break end end end
		make("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(.6, 1), TextXAlignment = Enum.TextXAlignment.Right,
			Text = A.count(sel) .. " / " .. A.MAX .. " accessoires · survole pour comparer, clique pour équiper", TextSize = 11, TextColor3 = C.dim }, head)
		-- emplacements
		local slots = make("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1, LayoutOrder = 2 }, gs)
		make("UIGridLayout", { CellSize = UDim2.new(1 / 6, -5, 0, 50), CellPadding = UDim2.fromOffset(6, 0), SortOrder = Enum.SortOrder.LayoutOrder }, slots)
		for i, s in ipairs(A.SLOTS) do
			local a = sel[s.id]
			local has = a ~= nil and A.ATTS[a] ~= nil
			local on, avail = st.slot == s.id, ok[s.id] ~= nil
			local b = make("TextButton", { Text = "", BackgroundColor3 = if on then C.slotOn else C.card, BackgroundTransparency = if avail then 0 else .7, LayoutOrder = i }, slots)
			corner(b, 8); stroke(b, if on then C.orange else C.white, if on then 2 else 1, if on then 0 else .87)
			make("TextLabel", { Position = UDim2.fromOffset(7, 6), Size = UDim2.new(1, -12, 0, 12), Text = s.ic .. " " .. spaced(string.upper(s.n), 1), TextSize = 9,
				TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = if avail then 0 else .6 }, b)
			make("TextLabel", { Position = UDim2.fromOffset(7, 22), Size = UDim2.new(1, -12, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd,
				Text = if has then A.ATTS[a].n elseif avail then "—" else "Indisponible", TextSize = 12, TextColor3 = if has then C.orangeT else C.white,
				TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = if avail then 0 else .6 }, b)
			b.MouseButton1Click:Connect(function() if not avail then return end sfx("ui"); st.slot = s.id; drawGs() end)
		end
		-- options
		local opts = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 3 }, gs)
		make("UIGridLayout", { CellSize = UDim2.new(.2, -5, 0, 118), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }, opts)
		local cur = sel[st.slot]
		local function option(order: number, a: string?, title: string, desc: string, lock: boolean)
			local on = (a == nil and cur == nil) or (a ~= nil and cur == a)
			local b = make("TextButton", { Text = "", BackgroundColor3 = if on then C.greenBg else C.card, BackgroundTransparency = if lock then .55 else 0, LayoutOrder = order }, opts)
			corner(b, 8); stroke(b, if on then C.green else C.white, 1, if on then 0 else .87)
			make("TextLabel", { Position = UDim2.fromOffset(9, 8), Size = UDim2.new(1, -16, 0, 16), Text = title .. (if lock then " 🔒" else ""), TextSize = 12,
				TextColor3 = C.opt, TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = if lock then .5 else 0, TextTruncate = Enum.TextTruncate.AtEnd }, b)
			make("TextLabel", { Position = UDim2.fromOffset(9, 26), Size = UDim2.new(1, -16, 1, -30), Text = desc, TextSize = 10, Font = Enum.Font.Gotham, TextWrapped = true,
				TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextTransparency = if lock then .4 else 0 }, b)
			local function trial(): A.Sel
				local s2: A.Sel = table.clone(selOf(k))
				s2[st.slot :: string] = a :: string
				return s2
			end
			b.MouseEnter:Connect(function() if lock then return end st.prev = trial(); setPreview(); drawStats() end)
			b.MouseLeave:Connect(function() if not st.prev then return end st.prev = nil; setPreview(); drawStats() end)
			b.MouseButton1Click:Connect(function()
				if lock and a then sfx("ui"); toast(A.lockText(k, a, D.prog)) return end
				if A.count(trial()) > A.MAX then sfx("ui"); toast("Maximum " .. A.MAX .. " accessoires : retire-en un d'abord") return end
				equip(k, st.slot, a)
			end)
		end
		option(0, nil, if st.slot == "optic" then A.opticNone(k) else "Aucun", if st.slot == "optic" then "Viseur de base de l'arme" else "Retirer l'accessoire", false)
		for i, a in ipairs(ok[st.slot] or {}) do
			local d = A.ATTS[a]
			local lock = not A.isOpen(k, a, D.prog)
			option(i, a, d.n, (if lock then A.lockText(k, a, D.prog) .. ". " else "") .. d.d, lock)
		end
	end

	-- ----- skins + équiper au départ -----
	local function drawSkins()
		clear(skl)
		header(skl, "Skin", 0)
		local grid = make("Frame", { Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1 }, skl)
		make("UIGridLayout", { CellSize = UDim2.new(.5, -4, 0, 36), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
		local k = st.key
		local prof = D.profile
		local eq = (prof and prof.equippedSkins and prof.equippedSkins[k]) or 1
		for i, s in ipairs(Config.SKINS) do
			local own = s.rarity == 1 or (prof ~= nil and prof.inv and prof.inv.skins and prof.inv.skins[k] ~= nil and table.find(prof.inv.skins[k], i) ~= nil)
			local on = i == eq
			local b = make("TextButton", { Text = "", BackgroundColor3 = C.card, BackgroundTransparency = if own then .05 else .4, LayoutOrder = i }, grid)
			stroke(b, if on then C.accent else C.white, if on then 2 else 1, if on then 0 else .9)
			make("Frame", { Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = RARITY[s.rarity] or C.dim }, b)
			make("TextLabel", { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -14, 1, 0), Text = s.name .. (if own then "" else " 🔒"), TextSize = 11, TextWrapped = true,
				TextColor3 = if own then C.text else C.dim, TextXAlignment = Enum.TextXAlignment.Left }, b)
			b.MouseButton1Click:Connect(function()
				if not own then sfx("ui"); toast("Skin verrouillé : trouve-le dans les caisses !") return end
				local r = ReplicatedStorage:FindFirstChild("EquipSkin") :: RemoteFunction?
				if r and pcall(r.InvokeServer, r, k, i) then
					if prof then prof.equippedSkins = prof.equippedSkins or {}; prof.equippedSkins[k] = i end
					sfx("ui"); drawSkins(); task.delay(.3, setPreview)
				end
			end)
		end
		local w = Config.WEAPONS[k]
		if w.slot == 0 or w.slot == 1 then
			local attr = player:GetAttribute(if w.slot == 0 then "Primary" else "Secondary")
			local cur = attr == k
			local b = chip(skl, if cur then "✔ Équipée au départ" else "Équiper au départ", cur, 2)
			b.MouseButton1Click:Connect(function()
				local r = ReplicatedStorage:FindFirstChild("SetLoadout") :: RemoteFunction?
				if not r then toast("Choix de l'arme indisponible ici") return end
				local ok, res = pcall(r.InvokeServer, r, k)
				sfx("ui")
				if ok and res then task.delay(.2, drawSkins) else toast("Cette arme n'est pas encore débloquée.") end
			end)
		end
		make("TextLabel", { Size = UDim2.new(1, -6, 0, 30), Text = if w.slot == 0 then "Arme principale de départ (Match à mort)." elseif w.slot == 1 then "Pistolet de départ." else "Le skin du couteau est visible en jeu.",
			TextSize = 10, Font = Enum.Font.Gotham, TextWrapped = true, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 3 }, skl)
	end

	local function refreshAll()
		for k2, c in pairs(chips) do
			local on = k2 == st.key
			c.BackgroundColor3 = if on then rgb(0x3a1a22) else C.panel
			local s = c:FindFirstChildOfClass("UIStroke"); if s then s.Color = if on then C.accent else C.line end
		end
		nameL.Text = spaced(string.upper(Config.WEAPONS[st.key].name), 2)
		drawStats(); drawGs(); drawSkins(); setPreview()
	end

	-- ----- liste des armes -----
	local order = 0
	for _, cat in ipairs(CATS) do
		order += 1; header(wl, cat[1], order)
		for _, k in ipairs(cat[2]) do
			if Config.WEAPONS[k] then
				order += 1
				local b = make("TextButton", { Size = UDim2.new(1, -8, 0, 30), Text = "", BackgroundColor3 = C.panel, LayoutOrder = order }, wl)
				stroke(b, C.line, 1, .2)
				weaponIcon(b, k, Vector2.new(46, 18), UDim2.fromOffset(8, 6))
				make("TextLabel", { Position = UDim2.fromOffset(62, 0), Size = UDim2.new(1, -66, 1, 0), Text = Config.WEAPONS[k].name, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left }, b)
				b.MouseButton1Click:Connect(function() sfx("ui"); st.key = k; current.key = k; st.prev = nil; refreshAll() end)
				chips[k] = b
			end
		end
	end

	-- rotation : auto ou à la souris
	table.insert(conns, vp.InputBegan:Connect(function(i: InputObject)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then st.drag = Vector2.new(i.Position.X, i.Position.Y) end
	end))
	table.insert(conns, UserInputService.InputChanged:Connect(function(i: InputObject)
		if st.drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local p = Vector2.new(i.Position.X, i.Position.Y)
			local d = p - (st.drag :: Vector2)
			st.ry += d.X * .01; st.rx = math.clamp(st.rx + d.Y * .006, -.6, .6); st.drag = p
		end
	end))
	table.insert(conns, UserInputService.InputEnded:Connect(function(i: InputObject)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then st.drag = nil end
	end))
	local explode = 0
	table.insert(conns, RunService.RenderStepped:Connect(function(dt: number)
		if not root.Visible or not pv.model then return end
		if st.spin and not st.drag then st.ry += dt * .5 end
		explode += ((if st.mode == "explode" then 1 else 0) - explode) * math.min(1, dt * 6)
		local rot = CFrame.Angles(st.rx, st.ry, 0)
		for _, e in ipairs(pv.parts) do
			if e.p.Parent then
				local off = e.off * (1 + explode * .9) + Vector3.new(0, 0, 0)
				local base = e.p:GetAttribute("Offset")
				local localRot = if typeof(base) == "CFrame" then base.Rotation else CFrame.identity
				e.p.CFrame = rot * CFrame.new(off) * localRot
			end
		end
		-- caméra du web : (0, .28, 2.6) vers l'origine, arme ramenée à 1,9 de large
		local k = pv.size / 1.9
		cam.CFrame = CFrame.lookAt(Vector3.new(0, .28, 2.6) * k, Vector3.zero)
		floor.CFrame = CFrame.new(0, -.36 * k, 0) * CFrame.Angles(0, 0, math.rad(90)); floor.Size = Vector3.new(.02, 2.6 * k, 2.6 * k)
	end))
	table.insert(conns, changed.Event:Connect(function() if root.Parent then refreshAll() end end))

	drawModes()
	refreshAll()
	if not D.loaded then task.spawn(load) end
	return {
		destroy = function() for _, c in ipairs(conns) do c:Disconnect() end root:Destroy() end,
		refresh = function() task.spawn(load) end,
	}
end

-- =====================================================================================
-- ARSENAL › VISEURS
-- =====================================================================================
local function curOpt(k: string): string?
	local o = selOf(k).optic
	local l = A.allowed(k).optic or {}
	return if o and table.find(l, o) then o else nil
end

-- aperçu : petite scène de stand de tir vue à travers le viseur (svScene + svPreview du web)
local function drawScene(host: Frame, z: number)
	local world = make("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, host)
	make("UIScale", { Scale = z }, world)
	local function rect(x: number, y: number, w: number, h: number, col: Color3, edge: boolean?): Frame
		local f = make("Frame", { Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h), BackgroundColor3 = col }, world)
		if edge then stroke(f, Color3.new(), 1, .75) end
		return f
	end
	local sky = rect(-1, -1, 3, 1.55, Color3.new(1, 1, 1))
	make("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(0x5d7ea6)), ColorSequenceKeypoint.new(.64, rgb(0x5d7ea6)), ColorSequenceKeypoint.new(1, rgb(0xb9c9d8)) }) }, sky)
	rect(-1, .55, 3, 2, rgb(0x6d6250))
	-- lignes du sol qui fuient vers l'horizon
	for i = -6, 11 do
		local x0, x1 = .5 + i * 90 / 640, .5 + i * 260 / 640
		local f = make("Frame", { AnchorPoint = Vector2.new(.5, 0), Position = UDim2.fromScale((x0 + x1) / 2, .55), Size = UDim2.new(0, 3, 1.45, 0), BackgroundColor3 = rgb(0x857a66),
			Rotation = -math.deg(math.atan2((x1 - x0) * 640, 1.45 * 400)) }, world)
		local _ = f
	end
	rect(.08, .42, .12, .16, rgb(0x8a6a42), true); rect(.78, .4, .14, .18, rgb(0x8a6a42), true); rect(.3, .47, .06, .09, rgb(0x7a5d3a), true)
	-- cible au centre
	make("Frame", { AnchorPoint = Vector2.new(.5, 0), Position = UDim2.fromScale(.5, .5), Size = UDim2.new(0, 3, .06, 0), BackgroundColor3 = rgb(0x2b2f36) }, world)
	local head = make("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .465), Size = UDim2.fromScale(.0875, .056), BackgroundColor3 = rgb(0xe9e3d4) }, world)
	make("UIAspectRatioConstraint", { AspectRatio = 1 }, head); corner(head, 999)
	make("Frame", { AnchorPoint = Vector2.new(.5, 0), Position = UDim2.fromScale(.5, .49), Size = UDim2.fromScale(.0375, .07), BackgroundColor3 = rgb(0xe9e3d4) }, world)
	local ringF = make("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .52), Size = UDim2.fromScale(.056, .036), BackgroundTransparency = 1 }, world)
	make("UIAspectRatioConstraint", { AspectRatio = 1 }, ringF); corner(ringF, 999); stroke(ringF, rgb(0xc23b3b), 1.5)
end

local function drawSightPreview(host: Frame, k: string)
	clear(host)
	local W, H = host.AbsoluteSize.X, host.AbsoluteSize.Y
	if W < 10 or H < 10 then return end
	local o = curOpt(k)
	local w = Config.WEAPONS[k]
	local ov = if o then A.ATTS[o].ov == true else w.cat == "sniper"
	local z = if ov then (if o then A.ATTS[o].m.zoom else w.zoom) * .8 elseif o == "acog" then 2 else 1.15
	drawScene(host, z)
	local cx, cy = W / 2, H / 2
	local dk = C.dark
	local layer = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3 }, host)
	local function rectPx(x: number, y: number, ww: number, hh: number, col: Color3, tr: number?)
		make("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(ww, hh), BackgroundColor3 = col, BackgroundTransparency = tr or 0, ZIndex = 3 }, layer)
	end
	-- trou circulaire : anneau à bord énorme (même astuce que la lunette du viewmodel)
	local function hole(R: number, ringCol: Color3?, ringW: number?)
		local f = make("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(R * 2, R * 2), BackgroundTransparency = 1, ZIndex = 3 }, layer)
		corner(f, 9999); make("UIStroke", { Thickness = math.max(W, H), Color = Color3.new() }, f)
		if ringCol then
			local r2 = make("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(R * 2 + 10, R * 2 + 10), BackgroundTransparency = 1, ZIndex = 4 }, layer)
			corner(r2, 9999); make("UIStroke", { Thickness = ringW or 10, Color = ringCol }, r2)
		end
	end
	if ov then
		local R = H * .44
		hole(R)
		local s, c = retOf(o or "scope")
		ReticleGui.draw(layer, cx, cy, R, s, c, true, 5)
		return
	end
	if not o then               -- mires : guidon + cran de mire
		rectPx(cx - 3, cy, 6, H * .2, dk); rectPx(cx - 80, cy + H * .1, 62, H * .4, dk); rectPx(cx + 18, cy + H * .1, 62, H * .4, dk)
		rectPx(cx - 18, cy + H * .16, 36, H * .4, dk)
		return
	end
	local s, c = retOf(o)
	if o == "acog" then
		local R = H * .36
		hole(R, rgb(0x2c3138), 10)
		ReticleGui.draw(layer, cx, cy, R * .55, s, c, false, 5)
		return
	end
	local frameCol = rgb(0x2c3138)
	if o == "reddot" then
		local R = H * .3
		local f = make("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(R * 2, R * 2), BackgroundTransparency = 1, ZIndex = 3 }, layer)
		corner(f, 9999); make("UIStroke", { Thickness = 16, Color = frameCol }, f)
		rectPx(cx - R * .7, cy + R + 4, R * 1.4, H, dk)
	elseif o == "holo" then
		local ww, hh = H * .62, H * .44
		local f = make("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(ww, hh), BackgroundTransparency = 1, ZIndex = 3 }, layer)
		make("UIStroke", { Thickness = 14, Color = frameCol }, f)
		rectPx(cx - ww / 2 - 7, cy + hh / 2, ww + 14, H, dk)
	else
		local ww, hh = H * .38, H * .3
		local f = make("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(ww, hh), BackgroundTransparency = 1, ZIndex = 3 }, layer)
		make("UIStroke", { Thickness = 9, Color = frameCol }, f)
		rectPx(cx - ww / 2 - 5, cy + hh / 2, ww + 10, H, dk)
	end
	rectPx(0, 0, W, H, rgb(0x7fd8ff), .94)
	ReticleGui.draw(layer, cx, cy, if o == "holo" then H * .1 else H * .08, s, c, false, 5)
end

function P.sights(parent: Frame): { destroy: () -> (), refresh: () -> () }
	local root = make("Frame", { Name = "ArsenalSights", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true }, parent)
	local toast = toaster(root)
	local conns: { RBXScriptConnection } = {}
	local left = make("ScrollingFrame", { Size = UDim2.new(0, 230, 1, 0), BackgroundTransparency = 1, ScrollBarThickness = 4, ScrollBarImageColor3 = C.line,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new() }, root)
	vlist(left, 4)
	local mid = make("Frame", { Position = UDim2.fromOffset(252, 0), Size = UDim2.new(1, -252 - 352, 1, 0), BackgroundTransparency = 1 }, root)
	local prev = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(0x0b1220), ClipsDescendants = true }, mid)
	make("UIAspectRatioConstraint", { AspectRatio = 1.6 }, prev); corner(prev, 10)
	local info = make("TextLabel", { Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 60), Text = "", RichText = true, TextSize = 13, Font = Enum.Font.Gotham,
		TextColor3 = C.soft, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, mid)
	local right = make("ScrollingFrame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 330, 1, 0), BackgroundTransparency = 1,
		ScrollBarThickness = 4, ScrollBarImageColor3 = C.line, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new() }, root)
	vlist(right, 6)

	local st = { key = nil :: string? }
	local draw: () -> ()
	local function setOpt(k: string, a: string?): boolean
		local s2: A.Sel = table.clone(selOf(k))
		s2.optic = a :: any
		if A.count(s2) > A.MAX then sfx("ui"); toast("Maximum " .. A.MAX .. " accessoires : retire-en un dans l'armurier") return false end
		local r = remote()
		if not r then return false end
		local ok, res = pcall(r.InvokeServer, r, "set", k, "optic", a or "")
		if ok and typeof(res) == "table" then
			if res.att then D.att = res.att end
			if not res.ok then if res.msg then toast(res.msg) end return false end
		end
		return true
	end
	local function setRet(o: string, shape: string?, col: string?)
		local s0, c0 = retOf(o)
		local r = remote()
		if not r then return end
		local ok, res = pcall(r.InvokeServer, r, "ret", o, shape or s0, col or c0)
		if ok and typeof(res) == "table" and res.ret then D.ret = res.ret end
		changed:Fire()
	end

	draw = function()
		local k = st.key
		if not k or not Config.WEAPONS[k] or not A.allowed(k).optic then
			local pk = current.key
			st.key = if pk and Config.WEAPONS[pk] and A.allowed(pk).optic then pk else (SIGHT_WEAPONS.rifle or SIGHT_WEAPONS.smg)[1]
			k = st.key
		end
		local key = k :: string
		-- armes
		clear(left)
		local order = 0
		for _, c in ipairs(SIGHT_CATS) do
			local l = SIGHT_WEAPONS[c[1]]
			if l then
				order += 1; header(left, c[2], order)
				order += 1
				local box = make("Frame", { Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order }, left)
				hflow(box, 5)
				for i, kk in ipairs(l) do
					local o = curOpt(kk)
					local b = chip(box, Config.WEAPONS[kk].name .. (if o then "  ⌖" else ""), kk == key, i)
					b.MouseButton1Click:Connect(function() sfx("ui"); st.key = kk; current.key = kk; draw() end)
				end
			end
		end
		-- viseurs
		clear(right)
		local cur = curOpt(key)
		header(right, "Viseur — " .. Config.WEAPONS[key].name, 1)
		local function row(order2: number, a: string?, title: string, small: string, zoom: string, lock: boolean)
			local on = a == cur
			local b = make("TextButton", { Size = UDim2.new(1, -6, 0, 48), Text = "", BackgroundColor3 = if on then C.greenBg else C.card, BackgroundTransparency = if lock then .55 else 0, LayoutOrder = order2 }, right)
			corner(b, 8); stroke(b, if on then C.green else C.white, 1, if on then 0 else .87)
			make("TextLabel", { Position = UDim2.fromOffset(11, 7), Size = UDim2.new(1, -70, 0, 16), Text = title .. (if lock then " 🔒" else ""), TextSize = 13, TextColor3 = C.opt,
				TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = if lock then .45 else 0 }, b)
			make("TextLabel", { Position = UDim2.fromOffset(11, 25), Size = UDim2.new(1, -70, 0, 16), Text = small, TextSize = 10, Font = Enum.Font.Gotham, TextColor3 = C.dim,
				TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, TextTransparency = if lock then .4 else 0 }, b)
			make("TextLabel", { AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -11, .5, 0), Size = UDim2.fromOffset(50, 16), Text = zoom, TextSize = 11, TextColor3 = C.orangeT,
				TextXAlignment = Enum.TextXAlignment.Right }, b)
			b.MouseButton1Click:Connect(function()
				if lock and a then sfx("ui"); toast(A.lockText(key, a, D.prog)) return end
				if setOpt(key, a) then sfx("reload", .3) end
				changed:Fire()
			end)
		end
		row(2, nil, A.opticNone(key), "Viseur de base de l'arme", A.zoomText(key, nil), false)
		for i, a in ipairs(A.allowed(key).optic) do
			local d = A.ATTS[a]
			local lock = not A.isOpen(key, a, D.prog)
			local small = if lock then string.gsub(A.lockText(key, a, D.prog), "Requis : ", "") else (string.split(string.split(d.d, ":")[1], ".")[1])
			row(2 + i, a, d.n, small, A.zoomText(key, a), lock)
		end
		-- réticule
		local o = cur or (if Config.WEAPONS[key].cat == "sniper" then "scope" else nil)
		if not o then
			header(right, "Réticule", 20)
			make("TextLabel", { Size = UDim2.new(1, -6, 0, 40), Text = "Les mires d'origine n'ont pas de réticule réglable. Choisis un viseur pour personnaliser son réticule.",
				TextSize = 12, Font = Enum.Font.Gotham, TextWrapped = true, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 21 }, right)
		else
			local s0, c0 = retOf(o)
			header(right, "Forme du réticule", 20)
			local shapes = make("Frame", { Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 21 }, right)
			hflow(shapes, 5)
			for i, r in ipairs(A.RET_SHAPES) do
				local b = chip(shapes, r[2], s0 == r[1], i)
				b.MouseButton1Click:Connect(function() sfx("ui"); setRet(o :: string, r[1], nil) end)
			end
			header(right, "Couleur", 22)
			local sw = make("Frame", { Size = UDim2.new(1, -6, 0, 30), BackgroundTransparency = 1, LayoutOrder = 23 }, right)
			make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 7) }, sw)
			for i, col in ipairs(A.RET_COLS) do
				local b = make("TextButton", { Size = UDim2.fromOffset(26, 26), Text = "", BackgroundColor3 = ReticleGui.hex(col), LayoutOrder = i }, sw)
				corner(b, 13); stroke(b, if col == c0 then C.white else C.white, 2, if col == c0 then 0 else .8)
				b.MouseButton1Click:Connect(function() sfx("ui"); setRet(o :: string, nil, col) end)
			end
			if cur then
				local all = chip(right, "Mettre ce viseur sur toutes les armes compatibles", false, 24)
				all.Size = UDim2.new(1, -6, 0, 32); all.AutomaticSize = Enum.AutomaticSize.None
				all.MouseButton1Click:Connect(function()
					sfx("ui")
					local r = remote()
					if not r then return end
					local ok, res = pcall(r.InvokeServer, r, "all", key)
					if ok and typeof(res) == "table" and res.ok then
						if res.att then D.att = res.att end
						local n = res.n or 0
						toast(A.ATTS[cur].n .. " posé sur " .. n .. " autre" .. (if n > 1 then "s" else "") .. " arme" .. (if n > 1 then "s" else ""))
					end
					changed:Fire()
				end)
			end
		end
		info.Text = "<b><font color=\"#ffffff\">" .. spaced(string.upper(if cur then A.ATTS[cur].n else A.opticNone(key)), 1) .. "</font></b>\n"
			.. (if cur then A.ATTS[cur].d elseif Config.WEAPONS[key].cat == "sniper" then "Lunette montée d'usine. Choisis un autre grossissement à droite." else "Visée par les organes de visée de l'arme.")
		info.Position = UDim2.fromOffset(0, prev.AbsoluteSize.Y + 10)
		drawSightPreview(prev, key)
	end

	table.insert(conns, prev:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() if st.key then info.Position = UDim2.fromOffset(0, prev.AbsoluteSize.Y + 10); drawSightPreview(prev, st.key) end end))
	table.insert(conns, changed.Event:Connect(function() if root.Parent then draw() end end))
	draw()
	if not D.loaded then task.spawn(load) end
	return {
		destroy = function() for _, c in ipairs(conns) do c:Disconnect() end root:Destroy() end,
		refresh = function() task.spawn(load) end,
	}
end

-- recharge les données (après un gain de niveau, une fin de partie…)
P.reload = function() task.spawn(load) end
P.changed = changed.Event

return P
