--!strict
-- StarterPlayerScripts/Menu/Kit (ModuleScript, client)
-- Petits outils d'interface du menu principal, avec la présentation du jeu web (src/00_head.html, src/87d_lobby.js) :
-- palette, cartes « lcard », boutons rouges en dégradé, pastilles, jauges, curseurs, lettres espacées (letter-spacing).
local TweenService = game:GetService("TweenService")
local MenuConfig = require(game:GetService("ReplicatedStorage").Shared.MenuConfig)

local K = {}

local function rgb(h: number): Color3
	return Color3.fromRGB(bit32.rshift(h, 16), bit32.band(bit32.rshift(h, 8), 255), bit32.band(h, 255))
end
K.rgb = rgb

-- palette du web (:root et styles du menu)
K.C = {
	bg = rgb(0x0b1018), panel = rgb(0x141c2c), card = rgb(0x0f1726), card2 = rgb(0x152036), deep = rgb(0x0b111c), navy = rgb(0x1a2438),
	text = rgb(0xe8eef9), white = Color3.new(1, 1, 1), dim = rgb(0x8da0bd), sub = rgb(0xb8c5da), mute = rgb(0x6f819e),
	accent = rgb(0xff4655), accent2 = rgb(0xff6b5a), accentDark = rgb(0xd8323f), gold = rgb(0xffd23a), green = rgb(0x7dff9f),
	blue = rgb(0x4aa3ff), blueDark = rgb(0x2c7fe0), purple = rgb(0x8a5bff), violet = rgb(0xc77dff), orange = rgb(0xff7a1a), pumpkin = rgb(0xffae5a),
	ink = rgb(0x111111),
}
local C = K.C
K.BLACK = Enum.Font.GothamBlack
K.BOLD = Enum.Font.GothamBold
K.MED = Enum.Font.GothamMedium

function K.make(class: string, props: { [string]: any }, parent: Instance?): any
	local o: any = Instance.new(class)
	if o:IsA("GuiObject") then o.BorderSizePixel = 0 end
	if class == "TextLabel" or class == "TextButton" or class == "TextBox" then
		o.Font = K.BOLD; o.TextColor3 = C.text; o.TextSize = 14; o.RichText = true
		if class == "TextLabel" then o.BackgroundTransparency = 1 end
		if class == "TextButton" then o.AutoButtonColor = false end
	end
	if class == "Frame" or class == "ScrollingFrame" then o.BackgroundTransparency = 1 end
	for k, v in pairs(props) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
local make = K.make

function K.corner(o: Instance, r: number?) make("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o) end
function K.stroke(o: Instance, color: Color3?, th: number?, tr: number?): UIStroke
	return make("UIStroke", { Color = color or C.white, Thickness = th or 1, Transparency = tr or 0.92, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
function K.pad(o: Instance, l: number, t: number?, r: number?, b: number?)
	make("UIPadding", { PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t or l), PaddingRight = UDim.new(0, r or l), PaddingBottom = UDim.new(0, b or t or l) }, o)
end
function K.vlist(o: Instance, gap: number?, align: Enum.HorizontalAlignment?): UIListLayout
	return make("UIListLayout", { Padding = UDim.new(0, gap or 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = align or Enum.HorizontalAlignment.Left }, o)
end
function K.hlist(o: Instance, gap: number?, valign: Enum.VerticalAlignment?, wraps: boolean?): UIListLayout
	return make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, gap or 8), SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = valign or Enum.VerticalAlignment.Center, Wraps = wraps == true }, o)
end
function K.grid(o: Instance, cell: UDim2, gap: number?): UIGridLayout
	return make("UIGridLayout", { CellSize = cell, CellPadding = UDim2.fromOffset(gap or 10, gap or 10), SortOrder = Enum.SortOrder.LayoutOrder }, o)
end
function K.gradient(o: Instance, a: Color3, b: Color3, rot: number?, ta: number?, tb: number?): UIGradient
	return make("UIGradient", { Color = ColorSequence.new(a, b), Rotation = rot or 90, Transparency = NumberSequence.new(ta or 0, tb or ta or 0) }, o)
end
function K.tween(o: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- ---------- effets (src/8A_juice.js, src/87d_lobby.js) : survol, clic, brillance, apparition ----------
local Sfx = require(game:GetService("ReplicatedStorage").Shared.Sfx)
local lastHover = 0
-- son d'interface (sfxUI du web) : plus discret au survol, et pas plus d'un toutes les 70 ms
function K.uiSound(hover: boolean?)
	local now = os.clock()
	if hover then
		if now - lastHover < 0.07 then return end
		lastHover = now
	end
	pcall(Sfx.play, "ui", nil, if hover then 0.3 else 0.8)
end
-- UIScale des effets (un seul par objet : survol, clic et apparition se le partagent), créé au premier besoin
function K.fxScale(o: Instance): UIScale
	local s = o:FindFirstChild("FxScale")
	if s and s:IsA("UIScale") then return s end
	return make("UIScale", { Name = "FxScale" }, o)
end
-- dans une liste ou une grille, un objet qui grossit pousse ses voisins : on grossit deux fois moins
local function inLayout(o: Instance): boolean
	local p = o.Parent
	return p ~= nil and p:FindFirstChildWhichIsA("UIGridStyleLayout") ~= nil
end
-- reflet qui traverse l'objet (.btn::after et .hero::after du web) : bande blanche en dégradé, dans un cadre qui la coupe.
-- Le dégradé est sur la bande, jamais sur un bouton qui porte son texte (il le teinterait aussi).
-- every = nil : un seul passage (survol) ; sinon recommence toutes les « every » secondes
function K.shine(o: GuiObject, every: number?, strength: number?)
	if o:FindFirstChildWhichIsA("UIGridStyleLayout") then return end   -- le cadre du reflet prendrait une place dans la liste
	local holder = o:FindFirstChild("Shine")
	local band: Frame
	if holder and holder:FindFirstChild("Band") then
		band = (holder :: any).Band
	else
		holder = make("Frame", { Name = "Shine", Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = o.ZIndex + 1, Active = false }, o)
		band = make("Frame", { Name = "Band", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(-0.6, 0.5), Size = UDim2.fromScale(0.5, 1.6),
			BackgroundTransparency = 0, BackgroundColor3 = C.white, ZIndex = o.ZIndex + 1, Rotation = 12, Active = false }, holder)
		local a = 1 - (strength or 0.22)
		make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, a), NumberSequenceKeypoint.new(1, 1) }) }, band)
	end
	local h = holder :: Instance
	if not every and h:GetAttribute("Loop") then return end   -- le reflet tourne déjà en boucle
	band.Position = UDim2.fromScale(-0.6, 0.5)
	if every then
		h:SetAttribute("Loop", true)
		TweenService:Create(band, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, every), { Position = UDim2.fromScale(1.1, 0.5) }):Play()
	else
		K.tween(band, 0.6, { Position = UDim2.fromScale(1.1, 0.5) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	end
end
-- battement (pastilles .ndot du web : scale 1,18 toutes les 1,6 s)
function K.beat(o: GuiObject, to: number?, period: number?)
	TweenService:Create(K.fxScale(o), TweenInfo.new((period or 1.6) / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = to or 1.18 }):Play()
end
-- survol / sélection manette : léger agrandissement, lueur du bord, son ; clic : enfoncement puis rebond
function K.juice(b: GuiButton, grow: number?, shine: boolean?)
	local g = grow or 0.04
	local hovered = false
	local function target(): number
		if not hovered then return 1 end
		return 1 + (if inLayout(b) then g * 0.5 else g)
	end
	local function glow(on: boolean)
		local st = b:FindFirstChildOfClass("UIStroke")
		if st and st.Name == "Pulse" then return end
		if not st then
			if not on or b:FindFirstChild("Cut") then return end   -- coins coupés : un bord dessinerait les coins carrés
			local base = b:GetAttribute("BaseColor")
			st = make("UIStroke", { Name = "Glow", Thickness = 1.5, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = if typeof(base) == "Color3" then base:Lerp(C.white, 0.45) else C.white }, b)
		end
		local s = st :: UIStroke
		if s:GetAttribute("BaseT") == nil then s:SetAttribute("BaseT", s.Transparency) end
		local baseT = s:GetAttribute("BaseT") :: number
		K.tween(s, 0.16, { Transparency = if on then math.min(baseT, 1) - (if s.Name == "Glow" then 0.6 else math.min(0.35, baseT * 0.5)) else baseT })
	end
	local function hover(on: boolean)
		if hovered == on then return end
		hovered = on
		K.tween(K.fxScale(b), 0.16, { Scale = target() }, if on then Enum.EasingStyle.Back else Enum.EasingStyle.Quad)
		glow(on)
		if on then
			K.uiSound(true)
			if shine then K.shine(b) end
		end
	end
	b.MouseEnter:Connect(function() hover(true) end)
	b.MouseLeave:Connect(function() hover(false) end)
	b.SelectionGained:Connect(function() hover(true) end)
	b.SelectionLost:Connect(function() hover(false) end)
	b.MouseButton1Down:Connect(function() K.tween(K.fxScale(b), 0.06, { Scale = 0.95 }) end)
	b.MouseButton1Up:Connect(function() K.tween(K.fxScale(b), 0.22, { Scale = target() }, Enum.EasingStyle.Back) end)
	b.Activated:Connect(function()
		K.uiSound(false)
		-- manette / tactile : pas de MouseButton1Down, on rejoue l'enfoncement ici
		local s = K.fxScale(b)
		if s.Scale > 0.97 then
			s.Scale = 0.95
			K.tween(s, 0.22, { Scale = target() }, Enum.EasingStyle.Back)
		end
	end)
end
-- apparition en cascade (lcIn du web : chaque carte arrive avec un léger décalage) : les cartes de la page grossissent
-- de 0,94 à 1 l'une après l'autre, de haut en bas puis de gauche à droite
function K.cascade(root: Instance, max: number?)
	local found: { GuiObject } = {}
	local function walk(o: Instance, depth: number)
		for _, c in ipairs(o:GetChildren()) do
			if #found >= (max or 14) then return end
			if c:IsA("GuiObject") and c.Visible then
				local isCard = (c:IsA("Frame") or c:IsA("TextButton")) and c:FindFirstChildOfClass("UICorner") ~= nil
					and c.AbsoluteSize.X >= 140 and c.AbsoluteSize.Y >= 56
				if isCard then table.insert(found, c)
				elseif depth < 5 then walk(c, depth + 1) end
			end
		end
	end
	walk(root, 0)
	table.sort(found, function(a, b)
		local pa, pb = a.AbsolutePosition, b.AbsolutePosition
		if math.abs(pa.Y - pb.Y) > 8 then return pa.Y < pb.Y end
		return pa.X < pb.X
	end)
	for i, c in ipairs(found) do
		local s = K.fxScale(c)
		s.Scale = 0.94
		TweenService:Create(s, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, (i - 1) * 0.045), { Scale = 1 }):Play()
	end
end

-- lettres espacées (letter-spacing du web), comme HudController
function K.spaced(s: string, n: number?): string
	local gap = string.rep(" ", n or 1)
	local out = {}
	for _, cp in utf8.codes(s) do table.insert(out, utf8.char(cp)) end
	return table.concat(out, gap)
end
-- texte sûr pour RichText
function K.esc(s: string): string
	return (string.gsub(string.gsub(string.gsub(s, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end
function K.hex(c: Color3): string return "#" .. c:ToHex() end
function K.fmt(n: number): string   -- 12 500
	local s = tostring(math.floor(n))
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1 ")))
	return (string.gsub(out, "^%s+", ""))
end

function K.clear(o: Instance)
	for _, c in ipairs(o:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
end

function K.text(parent: Instance?, props: { [string]: any }): TextLabel
	local base: { [string]: any } = { Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true }
	for k, v in pairs(props) do base[k] = v end
	return make("TextLabel", base, parent)
end
-- texte qui prend sa hauteur tout seul (paragraphes)
function K.para(parent: Instance?, text: string, size: number?, color: Color3?, order: number?): TextLabel
	return K.text(parent, { Text = text, TextSize = size or 13, TextColor3 = color or C.sub, Font = K.MED, AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0), LayoutOrder = order or 0, TextYAlignment = Enum.TextYAlignment.Top, LineHeight = 1.15 })
end

-- coins coupés (clip-path du web) : deux triangles de la couleur du fond posés sur les coins haut-droit et bas-gauche
function K.cut(o: GuiObject, size: number?, bg: Color3?)
	local s = size or 12
	for _, at in ipairs({ { 1, 0 }, { 0, 1 } }) do
		local f = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(at[1], at[2]), Size = UDim2.fromOffset(s * 1.42, s * 1.42),
			Rotation = 45, BackgroundColor3 = bg or C.bg, BackgroundTransparency = 0, ZIndex = o.ZIndex + 2, Name = "Cut" }, o)
		f.Active = false
	end
end

-- carte du menu (.lcard) : dégradé bleu nuit translucide, bord blanc à 8 %, coins arrondis
-- onClick : la carte entière devient un bouton (cartes cliquables de l'accueil)
function K.card(parent: Instance?, props: { [string]: any }?, onClick: (() -> ())?): Frame
	local f = make(if onClick then "TextButton" else "Frame", { BackgroundTransparency = 0, BackgroundColor3 = C.white, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y }, parent)
	K.gradient(f, rgb(0x121b2c), rgb(0x0b111c), 90, 0.13, 0.2)
	K.corner(f, 14); K.stroke(f)
	if onClick then
		(f :: any).Text = ""; (f :: any).Selectable = true
		-- carte cliquable : elle grossit un peu et son bord s'éclaire au survol (.mcard:hover du web)
		K.juice(f :: any, 0.02);
		(f :: any).Activated:Connect(onClick)
	end
	K.pad(f, 18, 16)
	if props then for k, v in pairs(props) do (f :: any)[k] = v end end
	return f
end
-- titre de carte (.lcard h4) : icône + lettres espacées, petit texte à droite
function K.h4(parent: Instance, title: string, small: string?, order: number?, color: Color3?): Frame
	local row = make("Frame", { Size = UDim2.new(1, 0, 0, 20), LayoutOrder = order or 0 }, parent)
	K.text(row, { Text = K.spaced(title, 2), Font = K.BLACK, TextSize = 12, TextColor3 = color or C.white, Size = UDim2.new(1, 0, 1, 0), TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd })
	if small then
		K.text(row, { Text = small, TextSize = 11, TextColor3 = C.dim, Size = UDim2.new(0.45, 0, 1, 0), Position = UDim2.fromScale(0.55, 0),
			TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false })
	end
	return row
end
-- petit titre de section (« DIFFICULTÉ », « JOUEURS »)
function K.label(parent: Instance, title: string, order: number?, color: Color3?): TextLabel
	return K.text(parent, { Text = K.spaced(title, 2), Font = K.BLACK, TextSize = 11, TextColor3 = color or C.white, LayoutOrder = order or 0,
		Size = UDim2.new(1, 0, 0, 18), TextWrapped = false })
end

-- jauge (.lbar) : fond blanc à 7 %, remplissage dégradé rouge -> or
function K.bar(parent: Instance, frac: number, props: { [string]: any }?, a: Color3?, b: Color3?): Frame
	local back = make("Frame", { Size = UDim2.new(1, 0, 0, 6), BackgroundTransparency = 0.93, BackgroundColor3 = C.white }, parent)
	K.corner(back, 3)
	local fill = make("Frame", { Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1), BackgroundTransparency = 0, BackgroundColor3 = C.white, Name = "Fill" }, back)
	K.corner(fill, 3); K.gradient(fill, a or C.accent, b or C.gold, 0)
	if props then for k, v in pairs(props) do (back :: any)[k] = v end end
	return back
end

-- boutons. kind : "primary" (rouge), "alt" (bleu nuit), "ghost" (transparent), "gold", "white", "blue", "purple"
export type BtnKind = string
local KINDS: { [string]: { Color3 | number } } = {
	primary = { rgb(0xff4655), rgb(0xd8323f), 0 }, alt = { rgb(0x1e2a42), rgb(0x16203a), 0 }, ghost = { rgb(0x0f1726), rgb(0x0b111c), 0.3 },
	gold = { rgb(0xffd23a), rgb(0xffb300), 0 }, white = { rgb(0xffffff), rgb(0xe8eef9), 0 }, blue = { rgb(0x4aa3ff), rgb(0x2c7fe0), 0 },
	purple = { rgb(0x7a3dff), rgb(0x5a2bd6), 0 }, green = { rgb(0x2fd27a), rgb(0x1fa35e), 0 }, dark = { rgb(0x0b111c), rgb(0x0b111c), 0.2 },
}
-- Fond uni (milieu du dégradé du web) : un UIGradient sur un bouton teinte aussi son texte, ce qui rendait
-- les libellés invisibles (texte rouge sur fond rouge).
local function kindColor(k: { any }): Color3 return (k[1] :: Color3):Lerp(k[2] :: Color3, 0.5) end
function K.btn(parent: Instance?, text: string, kind: BtnKind?, cb: (() -> ())?, props: { [string]: any }?): TextButton
	local k = KINDS[kind or "alt"] or KINDS.alt
	local dark = kind == "gold" or kind == "white"
	local b = make("TextButton", { Text = text, Font = K.BLACK, TextSize = 14, BackgroundColor3 = kindColor(k), BackgroundTransparency = k[3] :: number,
		TextColor3 = if dark then rgb(0x111111) else C.white, Size = UDim2.fromOffset(160, 40), Selectable = true }, parent)
	K.corner(b, 8)
	if kind == "ghost" or kind == "alt" or kind == "dark" then K.stroke(b, C.white, 1, 0.9) end
	if props then for key, v in pairs(props) do (b :: any)[key] = v end end
	b:SetAttribute("BaseColor", b.BackgroundColor3)
	-- survol / sélection manette : éclaircit un peu (filter:brightness du web)
	-- (un bouton transparent, comme les onglets de la navigation, prend un léger fond au survol)
	local baseT = b.BackgroundTransparency
	local function hi(on: boolean)
		local base = b:GetAttribute("BaseColor")
		if typeof(base) == "Color3" then K.tween(b, 0.12, { BackgroundColor3 = if on then base:Lerp(C.white, 0.12) else base }) end
		if baseT >= 0.95 then K.tween(b, 0.12, { BackgroundTransparency = if on then 0.9 else baseT }) end
	end
	b.MouseEnter:Connect(function() hi(true) end)
	b.MouseLeave:Connect(function() hi(false) end)
	b.SelectionGained:Connect(function() hi(true) end)
	b.SelectionLost:Connect(function() hi(false) end)
	-- agrandissement, lueur, son ; reflet qui traverse les boutons pleins (rouge, or, bleu…)
	K.juice(b, 0.04, k[3] == 0 and kind ~= "alt" and kind ~= "white")
	if cb then b.Activated:Connect(cb) end
	return b
end
-- change la couleur de fond d'un bouton K.btn (garde l'effet de survol)
function K.setBtnColor(b: GuiObject, c: Color3)
	b:SetAttribute("BaseColor", c); b.BackgroundColor3 = c
end
function K.setKind(b: TextButton, kind: BtnKind)
	local k = KINDS[kind] or KINDS.alt
	K.setBtnColor(b, kindColor(k))
	b.BackgroundTransparency = k[3] :: number
	b.TextColor3 = if kind == "gold" or kind == "white" then rgb(0x111111) else C.white
end

-- pastille / puce (chip) : on = fond coloré
function K.chip(parent: Instance?, text: string, on: boolean, cb: (() -> ())?, props: { [string]: any }?, onColor: Color3?): TextButton
	local b = make("TextButton", { Text = text, Font = K.BOLD, TextSize = 13, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 36),
		BackgroundTransparency = if on then 0 else 0.25, BackgroundColor3 = if on then (onColor or C.accent) else C.navy, TextColor3 = C.white, Selectable = true }, parent)
	K.corner(b, 6); K.pad(b, 14, 0)
	-- puce choisie : lueur de sa couleur (.chip.on du web) ; les autres : bord fin qui s'éclaire au survol
	if on then K.stroke(b, (onColor or C.accent):Lerp(C.white, 0.35), 1.5, 0.45) else K.stroke(b, C.white, 1, 0.92) end
	if props then for k, v in pairs(props) do (b :: any)[k] = v end end
	K.juice(b, 0.05)
	if cb then b.Activated:Connect(cb) end
	return b
end

-- curseur (input range du web) : rail fin, partie gauche rouge, rond blanc ; manette : gauche / droite quand il est sélectionné
function K.slider(parent: Instance, title: string, min: number, max: number, step: number, value: number, fmt: (number) -> string,
	onChange: (number) -> (), order: number?): Frame
	local UIS = game:GetService("UserInputService")
	local box = make("Frame", { Size = UDim2.new(1, 0, 0, 44), LayoutOrder = order or 0 }, parent)
	local head = K.text(box, { Text = "", Font = K.BLACK, TextSize = 11, Size = UDim2.new(1, 0, 0, 16), TextWrapped = false })
	local rail = make("TextButton", { Text = "", Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 6), BackgroundTransparency = 0.85,
		BackgroundColor3 = C.white, Selectable = true, AutoButtonColor = false }, box)
	K.corner(rail, 3)
	local fill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundTransparency = 0, BackgroundColor3 = C.accent }, rail)
	K.corner(fill, 3)
	local knob = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(16, 16),
		BackgroundTransparency = 0, BackgroundColor3 = C.white, ZIndex = rail.ZIndex + 1 }, rail)
	K.corner(knob, 8); K.stroke(knob, C.accent, 2, 0)
	local v = value
	local function show()
		local f = (v - min) / (max - min)
		fill.Size = UDim2.fromScale(f, 1); knob.Position = UDim2.fromScale(f, 0.5)
		head.Text = K.spaced(title, 2) .. "   " .. fmt(v)
	end
	local function set(nv: number)
		nv = math.clamp(math.floor((nv - min) / step + 0.5) * step + min, min, max)
		if math.abs(nv - v) < 1e-6 then return end
		v = nv; show(); onChange(v)
	end
	local dragging = false
	local function fromX(x: number)
		local a, w = rail.AbsolutePosition.X, rail.AbsoluteSize.X
		if w > 0 then set(min + (max - min) * math.clamp((x - a) / w, 0, 1)) end
	end
	rail.InputBegan:Connect(function(i: InputObject)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true; fromX(i.Position.X) end
	end)
	local conns: { RBXScriptConnection } = {}
	table.insert(conns, UIS.InputChanged:Connect(function(i: InputObject)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then fromX(i.Position.X) end
	end))
	table.insert(conns, UIS.InputEnded:Connect(function(i: InputObject)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end))
	-- manette : la croix gauche / droite règle le curseur sélectionné
	rail.SelectionBehaviorLeft = Enum.SelectionBehavior.Stop; rail.SelectionBehaviorRight = Enum.SelectionBehavior.Stop
	table.insert(conns, UIS.InputBegan:Connect(function(i: InputObject)
		if game:GetService("GuiService").SelectedObject ~= rail then return end
		if i.KeyCode == Enum.KeyCode.DPadLeft or i.KeyCode == Enum.KeyCode.Left then set(v - step)
		elseif i.KeyCode == Enum.KeyCode.DPadRight or i.KeyCode == Enum.KeyCode.Right then set(v + step) end
	end))
	box.Destroying:Connect(function() for _, c in ipairs(conns) do c:Disconnect() end end)
	show()
	return box
end

-- défilement vertical (les colonnes du web ont overflow:auto)
function K.scroll(parent: Instance?, props: { [string]: any }?): ScrollingFrame
	local s = make("ScrollingFrame", { Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4, ScrollBarImageColor3 = C.white, ScrollBarImageTransparency = 0.8, ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable, Selectable = false }, parent)
	if props then for k, v in pairs(props) do (s :: any)[k] = v end end
	return s
end

-- icône ronde du niveau (le rond doré du profil)
function K.levelBadge(parent: Instance, level: number, size: number): Frame
	local f = make("Frame", { Size = UDim2.fromOffset(size, size), BackgroundTransparency = 0, BackgroundColor3 = C.white }, parent)
	K.corner(f, size // 2); K.gradient(f, rgb(0xffd23a), rgb(0xff8a1a), 135)
	K.text(f, { Text = tostring(level), Font = K.BLACK, TextSize = math.floor(size * 0.45), TextColor3 = rgb(0x2a1a00), Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false })
	return f
end

-- rareté (Config.RARITY) -> couleur
function K.rarityColor(r: number): Color3
	return ({ rgb(0x9aa6b8), rgb(0x4aa3ff), rgb(0xb36bff), rgb(0xffb938), rgb(0xff3df0) })[r] or rgb(0x9aa6b8)
end

-- un défi (.lmis) : texte, bouton RÉCUPÉRER quand il est fini, jauge, progression et gains
-- un défi (.lmis) : texte, bouton RÉCUPÉRER quand il est fini, jauge, progression et gains (Accueil et Profil)
function K.mission(ctx: any, parent: Instance, m: any, i: number, weekly: boolean)
	local f = K.make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = if m.done and not m.claimed then 0.92 else 0.97,
		BackgroundColor3 = if m.done and not m.claimed then C.gold else C.white, LayoutOrder = i }, parent)
	K.corner(f, 10); K.pad(f, 12, 10)
	K.stroke(f, if m.done and not m.claimed then C.gold else C.white, 1, if m.done and not m.claimed then 0.45 else 0.94)
	K.vlist(f, 6)
	local top = K.make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 }, f)
	K.text(top, { Text = m.text or MenuConfig.missionText(m.id, m.target, weekly), TextSize = 13, Font = K.MED, TextColor3 = if m.claimed then C.dim else C.text,
		Size = UDim2.new(1, -110, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	if m.done and not m.claimed then
		K.btn(top, K.spaced("RÉCUPÉRER", 1), "gold", function()
			local res = ctx.call(if weekly then "ClaimWeekly" else "ClaimMission", m.index or i)
			if res then ctx.toast("✔ +" .. m.coins .. " 🪙 · +" .. m.xp .. " XP", C.gold) end
			ctx.refresh()
		end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(104, 24), TextSize = 10 })
	elseif m.claimed then
		K.text(top, { Text = "✔", TextColor3 = C.green, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(30, 18),
			TextXAlignment = Enum.TextXAlignment.Right })
	end
	local bar = K.bar(f, m.progress / math.max(1, m.target), { LayoutOrder = 2 }, if m.claimed then C.green elseif weekly then C.purple else nil,
		if m.claimed then C.green elseif weekly then C.violet else nil)
	bar.Size = UDim2.new(1, 0, 0, 5)
	K.text(f, { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 14), TextSize = 11, TextColor3 = C.dim, TextWrapped = false,
		Text = K.fmt(m.progress) .. " / " .. K.fmt(m.target) .. '  ·  <font color="#ffd23a">🪙</font> ' .. m.coins .. "  ·  " .. m.xp .. " XP" })
end


return K
