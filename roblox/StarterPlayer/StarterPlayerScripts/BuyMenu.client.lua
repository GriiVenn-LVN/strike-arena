--!strict
-- StarterPlayerScripts/BuyMenu (LocalScript)
-- Boutique en partie, copie de #buy du jeu web (src/80_ui.js renderBuy / quickBuy / rebuy, styles .it de src/00_head.html) :
-- panneau sombre de 1100 de large, « BOUTIQUE » espacé, ⚡ ACHAT RAPIDE et ↻ RACHETER, argent en vert, colonnes
-- Pistolets / SMG / Pompes / Fusils puis Snipers / Lourd / Équipement, cartes avec nom, prix, image de l'arme et trois
-- barres (dégâts rouge, cadence bleue, précision verte), carte verte quand l'objet est équipé, grisée quand il ne
-- s'achète pas.
-- Touche B (ou croix directionnelle gauche) dans tous les modes : modes à manches (Compétitif, Désamorçage rapide,
-- Duel) pendant la phase d'achat, avec l'argent ; autres modes = « armurerie gratuite » du web, l'arme est donnée
-- tout de suite. Rien en Course aux armes, Zombies, Arme tournante, Bataille royale et Infecté (comme le web).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Config = require(ReplicatedStorage.Shared.Config)
local Modes = require(ReplicatedStorage.Shared.Modes)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local WeaponModels = require(ReplicatedStorage.Shared.WeaponModels)
local SkinPaint = require(ReplicatedStorage.Shared.SkinPaint)
local K = require(script.Parent:WaitForChild("Menu"):WaitForChild("Kit")) :: any

local player = Players.LocalPlayer
local make, spaced = K.make, K.spaced
local rgb = K.rgb

-- couleurs du web (:root et .it)
local C = {
	panel = rgb(0x0d121d), line = rgb(0x2a3750), it = rgb(0x161f33), itHover = rgb(0x22304e), own = rgb(0x12261f), ownLine = rgb(0x3dffa8),
	text = rgb(0xffffff), dim = rgb(0x8da0bd), foot = rgb(0x7b8ca6), good = rgb(0x7dff9f), accent = rgb(0xff4655), blue = rgb(0x4aa3ff),
	chip = rgb(0x1a2438), chipText = rgb(0xc5d1e4), shield = rgb(0x5ad8ff), navy = rgb(0x1a253c),
}
local ROUND_MODES = { bomb = true, rapid = true, duel = true }
local CT = "Défenseurs"
local DIM = 0.62                 -- .it:disabled { opacity: .38 }

local function remote(): RemoteFunction?
	local r = ReplicatedStorage:FindFirstChild("ModeBuy")
	return if r and r:IsA("RemoteFunction") then r else nil
end

-- ---------- fenêtre ----------
local gui = make("ScreenGui", { Name = "BuyMenu", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 26, Enabled = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
-- .ov : voile rgba(5,8,13,.78) sur tout l'écran
make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.22, BackgroundColor3 = rgb(0x05080d) }, gui)
local modal = make("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromOffset(1, 1), Modal = true, Selectable = false }, gui)   -- libère la souris
local canvas = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1600, 900) }, gui)
local scale = make("UIScale", {}, canvas)

local PW, PADX, PADY, GAP = 1100, 26, 22, 14
local CW = math.floor((PW - PADX * 2 - GAP * 3) / 4)
local panel = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(PW, 860),
	BackgroundTransparency = 0.12, BackgroundColor3 = C.panel }, canvas)
K.corner(panel, 4); K.stroke(panel, C.line, 1, 0)

-- en-tête : titre, achats rapides, argent
local title = make("TextLabel", { Position = UDim2.fromOffset(PADX, PADY), Size = UDim2.fromOffset(420, 40), Font = K.BLACK, TextSize = 26,
	TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left, Text = spaced("BOUTIQUE", 2) }, panel)
local money = make("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -PADX, 0, PADY), Size = UDim2.fromOffset(240, 40), Font = K.BLACK,
	TextSize = 32, TextColor3 = C.good, TextXAlignment = Enum.TextXAlignment.Right, Text = "" }, panel)
local chips = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, PADY + 4), Size = UDim2.fromOffset(300, 32) }, panel)
local cl = K.hlist(chips, 6); cl.HorizontalAlignment = Enum.HorizontalAlignment.Center
local function chip(text: string, order: number): TextButton
	local b = make("TextButton", { Text = text, Font = K.BOLD, TextSize = 13, TextColor3 = C.chipText, BackgroundColor3 = C.chip, BackgroundTransparency = 0,
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 32), LayoutOrder = order, Selectable = true }, chips)
	K.corner(b, 3); K.stroke(b, C.line, 1, 0); K.pad(b, 13, 0)
	b.MouseEnter:Connect(function() b.BackgroundColor3 = C.itHover end)
	b.MouseLeave:Connect(function() b.BackgroundColor3 = C.chip end)
	return b
end
local quickB = chip("⚡  " .. spaced("ACHAT RAPIDE", 0), 1)
local rebuyB = chip("↻  " .. spaced("RACHETER", 0), 2)

-- grille (défile si l'écran est petit, comme .panel { max-height: 96vh; overflow: auto })
local TOP = PADY + 40 + 14
local FOOT = 12 + 16 + 10 + 38 + PADY
local grid = make("ScrollingFrame", { Position = UDim2.fromOffset(PADX, TOP), Size = UDim2.new(1, -PADX * 2 + 8, 1, -TOP - FOOT), BackgroundTransparency = 1,
	ScrollBarThickness = 5, ScrollBarImageColor3 = C.line, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y, BorderSizePixel = 0 }, panel)
local foot = make("TextLabel", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, PADX, 1, -(PADY + 38 + 10)), Size = UDim2.new(1, -PADX * 2, 0, 16),
	Font = K.MED, TextSize = 11, TextColor3 = C.foot, Text = "" }, panel)
local closeB = make("TextButton", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -PADY), Size = UDim2.fromOffset(150, 38), Font = K.BLACK,
	TextSize = 14, TextColor3 = C.text, BackgroundColor3 = C.navy, BackgroundTransparency = 0, Text = spaced("FERMER", 1), Selectable = true }, panel)
K.corner(closeB, 3); K.stroke(closeB, C.text, 1, 0.88)
closeB.MouseEnter:Connect(function() closeB.BackgroundColor3 = C.itHover end)
closeB.MouseLeave:Connect(function() closeB.BackgroundColor3 = C.navy end)

local toast = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromOffset(700, 26), Font = K.BOLD,
	TextSize = 17, TextColor3 = rgb(0xff6b6b), Text = "", TextStrokeTransparency = 0.5, BackgroundTransparency = 1 },
	make("ScreenGui", { Name = "BuyToast", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 12 }, player:WaitForChild("PlayerGui")))
local toastN = 0
local function showToast(t: string)
	toastN += 1
	local my = toastN
	toast.Text = t
	task.delay(1.8, function() if my == toastN then toast.Text = "" end end)
end

-- ---------- cartes ----------
type Card = { b: TextButton, k: string, price: number, slot: number?, name: TextLabel, tag: TextLabel, stroke: UIStroke,
	icon: ViewportFrame?, bars: { Frame }, can: boolean, own: boolean, hover: boolean }
local cards: { Card } = {}

-- image de l'arme (weaponImg du web) : modèle 3D vu de côté, canon vers la gauche
local function weaponIcon(parent: Instance, key: string, size: Vector2, pos: UDim2): ViewportFrame
	local vf = make("ViewportFrame", { Size = UDim2.fromOffset(size.X, size.Y), Position = pos, BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 175, 190), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(0.4, -1, 0.3) }, parent)
	task.spawn(function()
		local ok, m = pcall(WeaponModels.build, key, 1)
		if not ok or not m or not vf.Parent then return end
		local model = m :: Model
		pcall(SkinPaint.apply, model, player:GetAttribute("Skin_" .. key) :: number?, player:GetAttribute("Camo_" .. key) :: string?)
		model.Parent = vf
		local cf, ext = model:GetBoundingBox()
		local cam = Instance.new("Camera"); cam.FieldOfView = 16
		local tv = math.tan(math.rad(8))
		local dist = math.max(ext.Y / 2 / tv, ext.Z / 2 / (tv * size.X / size.Y)) * 1.05 + ext.X
		cam.CFrame = CFrame.lookAt(cf.Position - Vector3.new(dist, 0, 0), cf.Position)
		cam.Parent = vf; vf.CurrentCamera = cam
	end)
	return vf
end

local function paint(c: Card)
	local dim = if c.can or c.own then 0 else DIM
	c.b.BackgroundColor3 = if c.own then C.own elseif c.hover and c.can then C.itHover else C.it
	c.b.BackgroundTransparency = dim * 0.6
	c.stroke.Color = if c.own then C.ownLine elseif c.hover and c.can then C.accent else C.line
	c.stroke.Transparency = dim
	c.name.TextTransparency = dim
	c.tag.TextTransparency = dim
	c.tag.TextColor3 = if c.own then C.ownLine else C.good
	if c.icon then c.icon.ImageTransparency = dim end
	for _, bar in ipairs(c.bars) do bar.BackgroundTransparency = dim end
	c.b.AutoButtonColor = false
end

local buy: (k: string) -> ()
local function newCard(parent: Instance, k: string, label: string, price: number, slot: number?, weapon: boolean, y: number): Card
	local h = if weapon then 76 else 32
	local b = make("TextButton", { Text = "", Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 0, BackgroundColor3 = C.it,
		Selectable = true }, parent)
	local stroke = K.stroke(b, C.line, 1, 0)
	local name = make("TextLabel", { Position = UDim2.fromOffset(10, if weapon then 7 else 0), Size = UDim2.new(1, -110, 0, if weapon then 16 else h), Font = K.BLACK,
		TextSize = 13, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = label }, b)
	local tag = make("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, if weapon then 7 else 0), Size = UDim2.fromOffset(150, if weapon then 16 else h),
		Font = K.BLACK, TextSize = 12, TextColor3 = C.good, TextXAlignment = Enum.TextXAlignment.Right, Text = "" }, b)
	local c: Card = { b = b, k = k, price = price, slot = slot, name = name, tag = tag, stroke = stroke, icon = nil, bars = {}, can = false, own = false, hover = false }
	if weapon then
		c.icon = weaponIcon(b, k, Vector2.new(84, 26), UDim2.fromOffset(8, 27))
		local w = Config.WEAPONS[k]
		local pel = w.pellets or 1
		local pct = {
			math.clamp(w.dmg * (if pel > 1 then pel * 0.45 else 1) * 0.8, 8, 100),
			math.clamp(w.rpm / 10, 6, 100),
			math.clamp(100 - w.spread * 14, 8, 100),
		}
		local cols = { C.accent, C.blue, C.good }
		for i = 1, 3 do
			local bar = make("Frame", { Position = UDim2.fromOffset(10, 57 + (i - 1) * 5), Size = UDim2.new((pct[i] / 100) * (CW - 20) / CW, 0, 0, 3),
				BackgroundTransparency = 0, BackgroundColor3 = cols[i] }, b)
			K.corner(bar, 2)
			table.insert(c.bars, bar)
		end
	end
	b.MouseEnter:Connect(function() c.hover = true; paint(c) end)
	b.MouseLeave:Connect(function() c.hover = false; paint(c) end)
	b.SelectionGained:Connect(function() c.hover = true; paint(c) end)
	b.SelectionLost:Connect(function() c.hover = false; paint(c) end)
	b.Activated:Connect(function() buy(k) end)
	table.insert(cards, c)
	return c
end

-- colonnes : 4 par ligne, la hauteur d'une ligne = sa colonne la plus haute
local function column(title: string, x: number, y: number): Frame
	local col = make("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(CW, 0) }, grid)
	make("TextLabel", { Size = UDim2.new(1, 0, 0, 16), Font = K.BOLD, TextSize = 10, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
		Text = spaced(string.upper(title), 2) }, col)
	return col
end
local cols: { { title: string, list: { any }, weapon: boolean } } = {}
for _, cat in ipairs(Modes.BUY_CATS) do table.insert(cols, { title = cat.n, list = cat.list, weapon = true }) end
table.insert(cols, { title = "ÉQUIPEMENT", list = Modes.BUY_ITEMS, weapon = false })
local kitCard: Card? = nil
local rowY = 0
local i = 1
while i <= #cols do
	local rowH = 0
	for j = 0, 3 do
		local cdef = cols[i + j]
		if not cdef then break end
		local col = column(cdef.title, j * (CW + GAP), rowY)
		local y = 22
		for _, it in ipairs(cdef.list) do
			if cdef.weapon then
				local w = Config.WEAPONS[it]
				newCard(col, it, w.name, w.price, w.slot, true, y); y += 76 + 6
			else
				local c = newCard(col, it.k, it.n, it.price, nil, false, y); y += 32 + 6
				if it.k == "kit" then kitCard = c end
			end
		end
		if not cdef.weapon then
			make("TextLabel", { Position = UDim2.fromOffset(0, y + 2), Size = UDim2.new(1, 0, 0, 34), Font = K.MED, TextSize = 11, TextColor3 = C.foot, RichText = true,
				TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, LineHeight = 1.25,
				Text = 'Barres : <font color="#ff4655">dégâts</font> · <font color="#4aa3ff">cadence</font> · <font color="#7dff9f">précision</font><br/>'
					.. 'Le <b><font color="#5ad8ff">bouclier</font></b> absorbe les dégâts avant le gilet et la santé.' }, col)
			y += 40
		end
		col.Size = UDim2.fromOffset(CW, y)
		rowH = math.max(rowH, y)
	end
	rowY += rowH + GAP
	i += 4
end
local GRID_H = rowY - GAP
make("Frame", { Position = UDim2.fromOffset(0, GRID_H), Size = UDim2.fromOffset(1, 1) }, grid)   -- fond de la zone qui défile

-- ---------- état ----------
local st: any = nil
local open = false
local mode = ""
local phase: string? = nil

local function owned(k: string): boolean
	local s = st
	if not s then return false end
	if k == "armor" then return (s.armor or 0) >= 100 elseif k == "shield1" then return (s.shield or 0) >= 25
	elseif k == "shield2" then return (s.shield or 0) >= 50 elseif k == "kit" then return s.kit == true
	elseif k == "frag" then return (s.frag or 0) >= 1 elseif k == "flash" then return (s.flash or 0) >= 2
	elseif k == "smoke" then return (s.smoke or 0) >= 1 elseif k == "mine" then return (s.mine or 0) >= 2 end
	return s.primary == k or s.secondary == k
end
local function render()
	local s = st
	if not s then return end
	local free = s.free == true
	title.Text = if mode == "duel" then spaced("CHOISIS TON ARME", 2)
		elseif s.dm then spaced("ARMURERIE", 2) .. '  <font size="13" color="#7dff9f">' .. spaced("GRATUITE", 1) .. "</font>"
		else spaced("BOUTIQUE", 2)
	money.Text = if free then "" else "$" .. tostring(s.money or 0)
	foot.Text = if s.dm then "B ou Échap : fermer  •  l'arme achetée est donnée tout de suite"
		else "B ou Échap : fermer  •  les achats ne sont possibles qu'en début de manche"
	for _, c in ipairs(cards) do
		local own = owned(c.k)
		local pistolLock = s.pistol == true and c.slot == 0
		c.own = own
		c.can = (free or (s.money or 0) >= c.price) and not own and not pistolLock and s.phase == "freeze"
		c.tag.Text = if own then "ÉQUIPÉ" elseif pistolLock then "MANCHE PISTOLET" elseif free then "GRATUIT" else "$" .. c.price
		paint(c)
	end
	if kitCard then kitCard.b.Visible = s.team == CT and s.bombMode == true end
end
local function fetch(k: string?): any
	local fn = remote()
	if not fn then return nil end
	local ok, res = pcall(function() return fn:InvokeServer(k) end)
	return if ok then res else nil
end
buy = function(k: string)
	if not open then return end
	local res = fetch(k)
	if not res or res.closed then return end
	st = res
	pcall(Sfx.play, if res.ok then "buy" else "deny")
	if res.msg then showToast(res.msg) end
	render()
end
local function buyQuiet(k: string): boolean
	local res = fetch(k)
	if not res or res.closed then return false end
	st = res
	return res.ok == true
end

-- ⚡ ACHAT RAPIDE (quickBuy du web) : un fusil si pas d'arme principale, gilet, bouclier, kit (CT), grenades
quickB.Activated:Connect(function()
	if not open or not st then return end
	if not st.primary then
		for _, k in ipairs({ "m4", "ak", "famas", "galil", "mp9", "ump" }) do
			if (st.free or (st.money or 0) >= Config.WEAPONS[k].price) and buyQuiet(k) then break end
		end
	end
	buyQuiet("armor")
	if st.free or (st.money or 0) >= 1000 then buyQuiet("shield2") else buyQuiet("shield1") end
	if st.team == CT and st.bombMode then buyQuiet("kit") end
	buyQuiet("frag"); buyQuiet("flash"); buyQuiet("smoke")
	pcall(Sfx.play, "buy")
	render()
end)
-- ↻ RACHETER (rebuy du web) : les armes choisies dans l'arsenal, gilet, frag
rebuyB.Activated:Connect(function()
	if not open or not st then return end
	local p, s = player:GetAttribute("Primary"), player:GetAttribute("Secondary")
	if typeof(p) == "string" and Config.WEAPONS[p] then buyQuiet(p) end
	if typeof(s) == "string" and Config.WEAPONS[s] then buyQuiet(s) end
	buyQuiet("armor"); buyQuiet("frag")
	pcall(Sfx.play, "buy")
	render()
end)

local function fit()
	local cam = workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1600, 900)
	scale.Scale = math.clamp(math.min(vp.X / 1600, vp.Y / 900), 0.45, 2)
	-- panneau : hauteur du contenu, au plus 96 % de l'écran
	local need = TOP + GRID_H + FOOT
	panel.Size = UDim2.fromOffset(PW, math.min(need, math.floor(900 * 0.96)))
end

local function setOpen(on: boolean)
	if on == open then return end
	open = on
	gui.Enabled = on; modal.Visible = on
	player:SetAttribute("UiOpen", if on then true else nil)
	if on then
		fit()
		grid.CanvasPosition = Vector2.zero
		render()
		task.spawn(function()
			local res = fetch(nil)
			if not open then return end
			if not res then setOpen(false); return end
			if res.closed then setOpen(false); showToast(res.closed); return end
			st = res; render()
		end)
	end
end
closeB.Activated:Connect(function() setOpen(false) end)

local function inMatch(): boolean return player:GetAttribute("Zone") == "match" end
local function tryOpen()
	if not inMatch() or player:GetAttribute("MenuOpen") == true then return end
	mode = tostring(player:GetAttribute("MatchMode") or "")
	if ROUND_MODES[mode] and phase ~= nil and phase ~= "freeze" then showToast("Achats possibles seulement en début de manche"); return end
	setOpen(true)
end

ContextActionService:BindActionAtPriority("BuyMenu", function(_, state)
	if not inMatch() then return Enum.ContextActionResult.Pass end
	if state == Enum.UserInputState.Begin then
		if open then setOpen(false) else tryOpen() end
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.B, Enum.KeyCode.DPadLeft)
ContextActionService:BindActionAtPriority("BuyMenuClose", function(_, state)
	if not open then return Enum.ContextActionResult.Pass end
	if state == Enum.UserInputState.Begin then setOpen(false) end
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.Escape, Enum.KeyCode.ButtonB)

-- bouton tactile ACHAT (téléphones)
local touchGui = make("ScreenGui", { Name = "BuyTouch", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 11, Enabled = UserInputService.TouchEnabled },
	player:WaitForChild("PlayerGui"))
local touchB = make("TextButton", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -230, 1, -260), Size = UDim2.fromOffset(78, 78), BackgroundColor3 = Color3.new(),
	BackgroundTransparency = 0.45, Text = "ACHAT", TextColor3 = C.text, TextSize = 14, Font = K.BLACK, Visible = false }, touchGui)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, touchB)
K.stroke(touchB, C.text, 2, 0.5)
touchB.Activated:Connect(function() if open then setOpen(false) else tryOpen() end end)

-- phase des modes à manches (TDMState), pour fermer la boutique quand la manche démarre
local stateRemote = ReplicatedStorage:WaitForChild("TDMState", 30)
if stateRemote and stateRemote:IsA("RemoteEvent") then
	stateRemote.OnClientEvent:Connect(function(s: any)
		if typeof(s) ~= "table" then return end
		if s.mode then mode = tostring(s.mode) end
		local d = s.data
		phase = if typeof(d) == "table" and d.kind == "rounds" then d.phase else nil
		if open and ROUND_MODES[mode] and phase ~= nil and phase ~= "freeze" then setOpen(false) end
		touchB.Visible = inMatch() and not open
	end)
end
local function onZone()
	if not inMatch() then setOpen(false); phase = nil end
	touchB.Visible = inMatch() and not open
end
player:GetAttributeChangedSignal("Zone"):Connect(onZone)
player:GetAttributeChangedSignal("MenuOpen"):Connect(function() if player:GetAttribute("MenuOpen") == true then setOpen(false) end end)
local cam = workspace.CurrentCamera
if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(function() if open then fit() end end) end
onZone()
