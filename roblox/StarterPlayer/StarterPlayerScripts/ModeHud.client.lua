--!strict
-- StarterPlayerScripts/ModeHud (LocalScript)
-- Interface des modes à objectifs, comme le web : lit la ligne « data » de TDMState (MatchService) et le dossier de la
-- carte de la partie.
--   Compétitif / Désamorçage rapide / Duel (Modes/rounds) : boutique (touche B pendant la phase d'achat, #buy du web),
--     argent, décompte 3-2-1, barre de pose / désamorçage (maintenir E), bombe portée / posée (chrono et bips),
--     marqueurs des sites A et B (grenades et mines : GrenadeController), positions révélées du Duel.
--   Capture de zone : état de la zone pour ton équipe, marqueur de la zone.
--   Domination : les trois drapeaux A B C (couleur, progression), texte du drapeau où tu te trouves (#domHud).
--   Capture du drapeau : état des deux drapeaux, « RAMÈNE LE DRAPEAU À TA BASE » (#ctfHud), marqueurs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Config = require(ReplicatedStorage.Shared.Config)
local Modes = require(ReplicatedStorage.Shared.Modes)
local Sfx = require(ReplicatedStorage.Shared.Sfx)

local player = Players.LocalPlayer
local stateRemote = ReplicatedStorage:WaitForChild("TDMState") :: RemoteEvent

local function rgb(h: number): Color3 return Color3.fromRGB(bit32.rshift(h, 16), bit32.band(bit32.rshift(h, 8), 255), bit32.band(h, 255)) end
local C = {
	text = rgb(0xe8eef9), dim = rgb(0x8da0bd), gold = rgb(0xffd75e), good = rgb(0x7dff9f), bad = rgb(0xff6b6b),
	yellow = rgb(0xffd23a), bomb = rgb(0xffb938), panel = rgb(0x0e131e), panel2 = rgb(0x161e2e), line = rgb(0x2a3750), accent = rgb(0xff4655),
	Attaquants = rgb(0xff7a4a), ["Défenseurs"] = rgb(0x4aa3ff),
}
local T, CT = "Attaquants", "Défenseurs"
local ROUND_MODES = { bomb = true, rapid = true, duel = true }
local function teamColor(t: string?): Color3 return (t and (C :: any)[t]) or C.text end
local function other(t: string?): string return if t == T then CT else T end

local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local o = Instance.new(class)
	if o:IsA("GuiObject") then (o :: any).BorderSizePixel = 0 end
	for k, v in pairs(props) do (o :: any)[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function corner(o: Instance, r: number?) make("UICorner", { CornerRadius = UDim.new(0, r or 4) }, o) end
local function label(parent: Instance, props: { [string]: any }): TextLabel
	local base = { BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextColor3 = C.text, TextSize = 15, Text = "", TextStrokeTransparency = 0.5 }
	for k, v in pairs(props) do (base :: any)[k] = v end
	return make("TextLabel", base, parent)
end

local gui = make("ScreenGui", { Name = "ModeHud", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 11, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))

-- ---------- état reçu ----------
local st: any = nil          -- dernier TDMState de ma partie
local data: any = nil        -- st.data (m.data.public du mode)
local mode = ""
local inMatch = false
local recvAt = 0
local function myTeam(): string? return player:GetAttribute("Team") :: string? end
local function myRoot(): BasePart?
	local ch = player.Character
	local h = ch and ch:FindFirstChildOfClass("Humanoid")
	if not ch or not h or h.Health <= 0 then return nil end
	return ch:FindFirstChild("HumanoidRootPart") :: BasePart?
end
local function remote(name: string): Instance? return ReplicatedStorage:FindFirstChild(name) end

-- ---------- panneau d'objectif (sous la ligne du mode du HUD) ----------
local objFrame = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 146), Size = UDim2.fromOffset(560, 64), BackgroundTransparency = 1, Visible = false }, gui)
local objLine = label(objFrame, { Size = UDim2.new(1, 0, 0, 20), TextSize = 15, Font = Enum.Font.GothamBlack })
local objSub = label(objFrame, { Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 18), TextSize = 13, TextColor3 = C.dim })
local objCall = label(objFrame, { Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 20), TextSize = 15, Font = Enum.Font.GothamBlack, TextColor3 = C.yellow })
-- drapeaux de Domination : trois ronds A B C avec la progression de capture
local domRow = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 146), Size = UDim2.fromOffset(140, 38), BackgroundTransparency = 1, Visible = false }, gui)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10) }, domRow)
local domIcons: { { box: Frame, txt: TextLabel, bar: Frame, stroke: UIStroke } } = {}
for i, n in ipairs({ "A", "B", "C" }) do
	local box = make("Frame", { Size = UDim2.fromOffset(34, 34), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, ClipsDescendants = true, LayoutOrder = i }, domRow)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, box)
	local stroke = make("UIStroke", { Thickness = 3, Color = C.text, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, box)
	local txt = label(box, { Size = UDim2.fromScale(1, 1), Text = n, TextSize = 17, Font = Enum.Font.GothamBlack })
	local bar = make("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(0, 0, 0, 4), BackgroundColor3 = C.text }, box)
	domIcons[i] = { box = box, txt = txt, bar = bar, stroke = stroke }
end

-- ---------- argent, barre d'action, décompte ----------
local moneyLabel = label(gui, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -132), Size = UDim2.fromOffset(220, 26), TextSize = 22,
	Font = Enum.Font.GothamBlack, TextColor3 = rgb(0x7dff9f), TextXAlignment = Enum.TextXAlignment.Left, Visible = false })
local useWrap = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.68), Size = UDim2.fromOffset(320, 44), BackgroundTransparency = 1, Visible = false }, gui)
local useMsg = label(useWrap, { Size = UDim2.new(1, 0, 0, 20), TextSize = 15, Font = Enum.Font.GothamBlack, TextColor3 = C.bomb })
local useBack = make("Frame", { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 10), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4 }, useWrap)
corner(useBack, 5)
local useFill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.bomb }, useBack)
corner(useFill, 5)
local useHint = label(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.72), Size = UDim2.fromOffset(500, 22), TextSize = 16, TextColor3 = C.text, Visible = false })
local countdown = label(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(200, 120), TextSize = 96,
	Font = Enum.Font.GothamBlack, TextColor3 = C.gold, Text = "", TextTransparency = 1, TextStrokeTransparency = 1 })
local bombPanel = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 208), Size = UDim2.fromOffset(250, 34), BackgroundColor3 = Color3.fromRGB(60, 10, 10),
	BackgroundTransparency = 0.25, Visible = false }, gui)
corner(bombPanel, 5)
local bombText = label(bombPanel, { Size = UDim2.fromScale(1, 1), TextSize = 18, Font = Enum.Font.GothamBlack, TextColor3 = C.bomb })

-- ---------- boutons tactiles ----------
local touch = UserInputService.TouchEnabled
local function touchButton(text: string, pos: UDim2): TextButton
	local b = make("TextButton", { AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(78, 78), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45,
		Text = text, TextColor3 = C.text, TextSize = 14, Font = Enum.Font.GothamBlack, Visible = false, AutoButtonColor = true }, gui)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, b)
	make("UIStroke", { Color = C.text, Transparency = 0.5, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	return b
end
local buyTouch = touchButton("ACHAT", UDim2.new(1, -230, 1, -260))
local useTouch = touchButton("E", UDim2.new(1, -140, 1, -300))

-- ---------- boutique (#buy du web) ----------
local buyWin = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.new(0.94, 0, 0.74, 0), BackgroundColor3 = C.panel,
	BackgroundTransparency = 0.06, Visible = false, ZIndex = 40 }, gui)
corner(buyWin, 6)
make("UISizeConstraint", { MaxSize = Vector2.new(1180, 640) }, buyWin)
make("UIStroke", { Color = C.line, Thickness = 1.5 }, buyWin)
local buyTitle = label(buyWin, { Position = UDim2.fromOffset(18, 10), Size = UDim2.new(0.5, 0, 0, 30), Text = "BOUTIQUE", TextSize = 24, Font = Enum.Font.GothamBlack,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 41 })
local buyMoney = label(buyWin, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -60, 0, 10), Size = UDim2.fromOffset(260, 30), TextSize = 24, Font = Enum.Font.GothamBlack,
	TextColor3 = rgb(0x7dff9f), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 41 })
local buyClose = make("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(36, 30), BackgroundColor3 = C.panel2,
	Text = "✕", TextColor3 = C.text, TextSize = 18, Font = Enum.Font.GothamBlack, ZIndex = 41 }, buyWin)
corner(buyClose)
local buyInfo = label(buyWin, { Position = UDim2.new(0, 18, 1, -30), Size = UDim2.new(1, -36, 0, 22), TextSize = 13, TextColor3 = C.dim,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 41 })
local buyGrid = make("ScrollingFrame", { Position = UDim2.fromOffset(12, 48), Size = UDim2.new(1, -24, 1, -84), BackgroundTransparency = 1, ScrollBarThickness = 6,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.XY, ScrollingDirection = Enum.ScrollingDirection.XY, ZIndex = 41 }, buyWin)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }, buyGrid)

local buyState: any = nil
local buyOpen = false
local buyButtons: { { b: TextButton, k: string, n: string, price: number, slot: number? } } = {}
local function column(title: string, order: number): Frame
	local col = make("Frame", { Size = UDim2.fromOffset(170, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 41 }, buyGrid)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, col)
	label(col, { Size = UDim2.new(1, 0, 0, 20), Text = string.upper(title), TextSize = 13, Font = Enum.Font.GothamBlack, TextColor3 = C.dim,
		TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 0, ZIndex = 41, TextStrokeTransparency = 1 })
	return col
end
local function itemButton(col: Frame, k: string, n: string, price: number, slot: number?, order: number)
	local b = make("TextButton", { Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = C.panel2, Text = "", AutoButtonColor = true, LayoutOrder = order, ZIndex = 42 }, col)
	corner(b)
	label(b, { Name = "N", Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 20), Text = n, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 43, TextStrokeTransparency = 1 })
	label(b, { Name = "P", Position = UDim2.fromOffset(8, 24), Size = UDim2.new(1, -16, 0, 18), Text = "", TextSize = 12, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 43, TextStrokeTransparency = 1 })
	table.insert(buyButtons, { b = b, k = k, n = n, price = price, slot = slot })
	b.MouseButton1Click:Connect(function()
		local fn = remote("ModeBuy") :: RemoteFunction?
		if not fn then return end
		local ok, res = pcall(function() return fn:InvokeServer(k) end)
		if ok and res then
			buyState = res
			pcall(function() Sfx.play(if res.ok then "buy" else "deny") end)
		end
	end)
end
for i, cat in ipairs(Modes.BUY_CATS) do
	local col = column(cat.n, i)
	for j, k in ipairs(cat.list) do
		local w = Config.WEAPONS[k]
		itemButton(col, k, w.name, w.price, w.slot, j)
	end
end
local equip = column("Équipement", 99)
for j, it in ipairs(Modes.BUY_ITEMS) do itemButton(equip, it.k, it.n, it.price, nil, j) end

local function owned(k: string): boolean
	local s = buyState
	if not s then return false end
	if k == "armor" then return (s.armor or 0) >= 100 elseif k == "shield1" then return (s.shield or 0) >= 25
	elseif k == "shield2" then return (s.shield or 0) >= 50 elseif k == "kit" then return s.kit == true
	elseif k == "frag" then return (s.frag or 0) >= 1 elseif k == "flash" then return (s.flash or 0) >= 2
	elseif k == "smoke" then return (s.smoke or 0) >= 1 elseif k == "mine" then return (s.mine or 0) >= 2 end
	return s.primary == k or s.secondary == k
end
local function renderBuy()
	local s = buyState
	if not s then return end
	buyTitle.Text = if mode == "duel" then "CHOISIS TON ARME" elseif s.pistol then "BOUTIQUE — MANCHE AU PISTOLET" else "BOUTIQUE"
	buyMoney.Text = if s.free then "" else "$" .. tostring(s.money)
	buyInfo.Text = "Barres : dégâts · cadence · précision — le bouclier absorbe les dégâts avant le gilet et la santé. B ou Échap pour fermer."
	for _, e in ipairs(buyButtons) do
		local isKit = e.k == "kit"
		e.b.Visible = not isKit or (s.team == CT and s.bombMode)
		local own = owned(e.k)
		local pistolLock = s.pistol and e.slot == 0
		local can = (s.free or (s.money or 0) >= e.price) and not own and not pistolLock and s.phase == "freeze"
		local p = e.b:FindFirstChild("P") :: TextLabel
		p.Text = if own then "ÉQUIPÉ" elseif pistolLock then "MANCHE PISTOLET" elseif s.free then "GRATUIT" else "$" .. e.price
		p.TextColor3 = if own then C.good elseif can then C.gold else C.dim
		e.b.BackgroundColor3 = if own then rgb(0x1d3a2a) else C.panel2
		e.b.BackgroundTransparency = if can or own then 0 else 0.45
		e.b.Active = can; e.b.AutoButtonColor = can
	end
end
local function setBuy(on: boolean)
	if on == buyOpen then return end
	buyOpen = on
	buyWin.Visible = on
	player:SetAttribute("UiOpen", if on then true else nil)
	if on then
		task.spawn(function()
			local fn = remote("ModeBuy") :: RemoteFunction?
			if not fn then return end
			local ok, res = pcall(function() return fn:InvokeServer(nil) end)
			if ok and res then buyState = res; renderBuy() end
		end)
	end
end
buyClose.MouseButton1Click:Connect(function() setBuy(false) end)
buyTouch.MouseButton1Click:Connect(function() setBuy(not buyOpen) end)

local function roundPhase(): string? return if ROUND_MODES[mode] and data and data.kind == "rounds" then data.phase else nil end
local toastLabel = label(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromOffset(600, 24), TextSize = 17, TextColor3 = C.bad, Text = "" })
local toastToken = 0
local function toast(text: string)
	toastToken += 1
	local my = toastToken
	toastLabel.Text = text
	task.delay(1.6, function() if my == toastToken then toastLabel.Text = "" end end)
end

-- ---------- touches : B (boutique), E (poser / désamorcer) ----------
-- la touche B et la fenêtre de la boutique sont dans BuyMenu.client.lua (copie de #buy du web, tous les modes)

local holding = false
local function setUse(on: boolean)
	if on == holding then return end
	holding = on
	local ev = remote("ModeUse") :: RemoteEvent?
	if ev then ev:FireServer(on) end
end
ContextActionService:BindActionAtPriority("ModeUse", function(_, state)
	if not inMatch or not ROUND_MODES[mode] then return Enum.ContextActionResult.Pass end
	if state == Enum.UserInputState.Begin then setUse(true) elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then setUse(false) end
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.E, Enum.KeyCode.ButtonB)
useTouch.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then setUse(true) end
end)
useTouch.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then setUse(false) end
end)

-- ---------- marqueurs dans le monde (sites, bombe, zone, drapeaux) ----------
local markerFolder = Instance.new("Folder"); markerFolder.Name = "ModeMarkers"; markerFolder.Parent = workspace.CurrentCamera
local markers: { [string]: { part: Part, bb: BillboardGui, txt: TextLabel, stroke: UIStroke } } = {}
local seen: { [string]: boolean } = {}
local function marker(id: string, pos: Vector3, text: string, color: Color3, size: number?)
	seen[id] = true
	local mk = markers[id]
	if not mk then
		local p = Instance.new("Part"); p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Transparency = 1
		p.Size = Vector3.new(0.2, 0.2, 0.2); p.Parent = markerFolder
		local bb = make("BillboardGui", { AlwaysOnTop = true, Size = UDim2.fromOffset(size or 34, size or 34), LightInfluence = 0, Adornee = p }, p)
		local txt = label(bb, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, TextScaled = true, Font = Enum.Font.GothamBlack, TextStrokeTransparency = 1 })
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, txt)
		local stroke = make("UIStroke", { Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, txt)
		mk = { part = p, bb = bb, txt = txt, stroke = stroke }
		markers[id] = mk
	end
	mk.part.Position = pos
	mk.txt.Text = text; mk.txt.TextColor3 = color; mk.stroke.Color = color
end
local function sweepMarkers()
	for id, mk in pairs(markers) do
		if not seen[id] then mk.part:Destroy(); markers[id] = nil end
	end
	table.clear(seen)
end

-- positions révélées (Duel) : contour des ennemis
local revealed: { [Model]: Highlight } = {}
local function setReveal(on: boolean)
	local want: { [Model]: boolean } = {}
	if on then
		local mine, id = myTeam(), player:GetAttribute("MatchId")
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player and p.Character and p:GetAttribute("MatchId") == id and p:GetAttribute("Team") ~= mine then want[p.Character] = true end
		end
		local bots = workspace:FindFirstChild("Bots")
		if bots then
			for _, b in ipairs(bots:GetChildren()) do
				if b:IsA("Model") and b:GetAttribute("MatchId") == id and b:GetAttribute("Team") ~= mine then want[b] = true end
			end
		end
	end
	for ch, h in pairs(revealed) do if not want[ch] or not ch.Parent then h:Destroy(); revealed[ch] = nil end end
	for ch in pairs(want) do
		if not revealed[ch] then
			revealed[ch] = make("Highlight", { FillColor = rgb(0xff7ad9), FillTransparency = 0.7, OutlineColor = rgb(0xff7ad9), DepthMode = Enum.HighlightDepthMode.AlwaysOnTop }, ch)
		end
	end
end

-- ---------- réception de l'état ----------
local lastPhaseKey = ""
stateRemote.OnClientEvent:Connect(function(s: any)
	inMatch = player:GetAttribute("Zone") == "match" and s.id == player:GetAttribute("MatchId") and s.state ~= "intermission"
	if not inMatch then st = nil; data = nil; mode = ""; return end
	st = s; data = s.data; mode = s.mode or ""; recvAt = os.clock()
	if buyOpen and (roundPhase() ~= "freeze" or s.state ~= "live") then setBuy(false) end
	-- nouvelle phase : on relit son inventaire (grenades, argent) auprès du serveur
	local key = tostring(data and data.round) .. ":" .. tostring(roundPhase())
	if roundPhase() and key ~= lastPhaseKey then
		lastPhaseKey = key
		task.spawn(function()
			local fn = remote("ModeBuy") :: RemoteFunction?
			if not fn then return end
			local ok, res = pcall(function() return fn:InvokeServer(nil) end)
			if ok and res then buyState = res end
		end)
	end
end)
player:GetAttributeChangedSignal("Zone"):Connect(function()
	if player:GetAttribute("Zone") ~= "match" then inMatch = false; st = nil; data = nil; mode = ""; setBuy(false) end
end)
player.CharacterAdded:Connect(function() setUse(false) end)

-- ---------- affichage, chaque image ----------
local lastCount, beepAt = -1, 0
local function pct(x: number): string return tostring(math.floor(x * 100 + 0.5)) .. " %" end

local function drawRounds(d: any, dtSince: number)
	local mine = myTeam()
	local char = player.Character
	local phase = d.phase
	-- argent
	local money = player:GetAttribute("Money")
	moneyLabel.Visible = typeof(money) == "number"
	moneyLabel.Text = if typeof(money) == "number" then (if money >= 16000 and mode ~= "bomb" then "$16000" else "$" .. tostring(money)) else ""
	if buyOpen then renderBuy() end
	buyTouch.Visible = false   -- bouton ACHAT : BuyMenu
	-- décompte 3-2-1 avant « C'EST PARTI »
	local left = math.max(0, (d.left or 0) - dtSince)
	if phase == "freeze" and left <= 3.2 and left > 0 then
		local n = math.ceil(left)
		if n ~= lastCount then lastCount = n; pcall(function() Sfx.play("tick") end) end
		countdown.Text = tostring(n); countdown.TextTransparency = 0; countdown.TextStrokeTransparency = 0.4
	else
		lastCount = -1; countdown.TextTransparency = 1; countdown.TextStrokeTransparency = 1
	end
	-- objectif personnel
	objFrame.Visible = true
	local b = d.bomb or {}
	local hasBomb = char ~= nil and char:GetAttribute("HasBomb") == true
	objLine.Text = ""; objSub.Text = ""; objCall.Text = ""
	if phase == "freeze" then
		objLine.Text = if mode == "duel" then "Touche B : choisis ton arme" else "Touche B : boutique" .. (if d.pistol then " — pistolets uniquement" else "")
		objLine.TextColor3 = C.gold
	elseif phase == "live" and d.bombMode then
		if b.state == "planted" then
			objLine.Text = if mine == CT then "DÉSAMORCEZ LA BOMBE — SITE " .. tostring(b.site) else "DÉFENDEZ LA BOMBE — SITE " .. tostring(b.site)
			objLine.TextColor3 = C.bomb
		elseif hasBomb then
			objLine.Text = "💣 TU AS LA BOMBE — pose-la sur un site (maintiens E)"; objLine.TextColor3 = C.bomb
		elseif mine == T then
			objLine.Text = if b.state == "dropped" then "💣 BOMBE LÂCHÉE — récupère-la" elseif b.carrier then "💣 Bombe portée par " .. b.carrier else "Attaquez un site"
			objLine.TextColor3 = teamColor(T)
		else
			objLine.Text = "Défendez les sites A et B"; objLine.TextColor3 = teamColor(CT)
		end
	elseif phase == "live" and d.revealed then
		objLine.Text = "POSITIONS RÉVÉLÉES"; objLine.TextColor3 = rgb(0xff7ad9)
	end
	-- bombe posée : chrono et bips de plus en plus rapides (web : clamp(t / 40, 0.12, 1) × 0.9 s)
	if b.state == "planted" and b.left then
		local bl = math.max(0, b.left - dtSince)
		bombPanel.Visible = true
		bombText.Text = "💣 SITE " .. tostring(b.site) .. " — " .. string.format("%.1f", bl) .. " s"
		local now = os.clock()
		if now >= beepAt and bl > 0 then
			beepAt = now + math.clamp(bl / 40, 0.12, 1) * 0.9
			pcall(function() Sfx.play("beep", b.pos, 1.1) end)
		end
	else
		bombPanel.Visible = false
	end
	-- pose / désamorçage
	local prog = player:GetAttribute("UseProg")
	local msg = player:GetAttribute("UseMsg")
	local hint = player:GetAttribute("UseHint")
	useWrap.Visible = typeof(prog) == "number"
	if typeof(prog) == "number" then useFill.Size = UDim2.fromScale(prog, 1); useMsg.Text = if typeof(msg) == "string" then msg else "" end
	useHint.Visible = typeof(hint) == "string" and not useWrap.Visible
	useHint.Text = if typeof(hint) == "string" then hint else ""
	useTouch.Visible = touch and (useWrap.Visible or useHint.Visible)
	-- marqueurs : sites, bombe
	if d.bombMode then
		for _, s in ipairs(d.sites or {}) do
			local here = b.state == "planted" and b.site == s.n
			marker("site" .. s.n, s.pos + Vector3.new(0, 9, 0), s.n, if here then C.bomb else C.text)
		end
		if b.pos and (b.state == "planted" or (b.state == "dropped" and mine == T)) then
			marker("bomb", b.pos + Vector3.new(0, 4, 0), "💣", C.bomb, 30)
		end
	end
	setReveal(d.revealed == true and phase == "live")
end

local function drawKoth(d: any)
	local mine = myTeam()
	objFrame.Visible = true
	objLine.Text = if d.contested then "ZONE DISPUTÉE" elseif d.owner == nil then "ZONE LIBRE — allez dessus !"
		elseif d.owner == mine then "VOTRE ÉQUIPE TIENT LA ZONE" else "L'ENNEMI TIENT LA ZONE"
	objLine.TextColor3 = if d.contested then C.yellow elseif d.owner then teamColor(d.owner) else C.text
	objSub.Text = "Prochaine zone " .. tostring(d.moveLeft or 0) .. " s"
	local r = myRoot()
	objCall.Text = if r and d.pos and (Vector3.new(r.Position.X - d.pos.X, 0, r.Position.Z - d.pos.Z)).Magnitude < (d.r or 0) then "TU ES DANS LA ZONE" else ""
	if d.pos then marker("koth", d.pos + Vector3.new(0, 12, 0), "⚑", if d.owner then teamColor(d.owner) elseif d.contested then C.yellow else C.text) end
end

local function drawDom(d: any)
	local mine = myTeam()
	domRow.Visible = true
	objFrame.Visible = true
	objFrame.Position = UDim2.new(0.5, 0, 0, 188)
	objLine.Text = ""; objSub.Text = ""; objCall.Text = ""
	local r = myRoot()
	for i, f in ipairs(d.flags or {}) do
		local icon = domIcons[i]
		if icon then
			local col = if f.contested then C.yellow elseif f.owner then teamColor(f.owner) else C.text
			icon.stroke.Color = col; icon.txt.TextColor3 = col
			icon.bar.Size = UDim2.new(f.prog or 0, 0, 0, 4)
			icon.bar.BackgroundColor3 = if f.cap then teamColor(f.cap) else C.text
		end
		marker("dom" .. f.n, f.pos + Vector3.new(0, 3.2 * Config.STUDS_PER_METER + 2, 0), f.n, if f.contested then C.yellow elseif f.owner then teamColor(f.owner) else C.text)
		if r and (Vector3.new(r.Position.X - f.pos.X, 0, r.Position.Z - f.pos.Z)).Magnitude < (d.r or 12) then
			objLine.Text = if f.contested then "DRAPEAU " .. f.n .. " DISPUTÉ" elseif f.owner == mine then "DRAPEAU " .. f.n .. " TENU"
				else "CAPTURE DE " .. f.n .. " — " .. pct(f.prog or 0)
			objLine.TextColor3 = C.text
		end
	end
end

local function drawCtf(d: any)
	local mine = myTeam() or T
	local flags = d.flags or {}
	local me, them = flags[mine], flags[other(mine)]
	if not me or not them then return end
	objFrame.Visible = true
	local function st(f: any): string
		if f.state == "home" then return "à la base" end
		if f.state == "dropped" then return "à terre " .. tostring(f.back or 0) .. " s" end
		if f.carrierUserId == player.UserId then return "TU LE PORTES" end
		return "porté par " .. tostring(f.carrier)
	end
	objLine.Text = "🚩 Le nôtre : " .. st(me); objLine.TextColor3 = teamColor(mine)
	objSub.Text = "🚩 Le leur : " .. st(them); objSub.TextColor3 = teamColor(other(mine))
	local char = player.Character
	local carrying = char ~= nil and char:GetAttribute("HasFlag") ~= nil
	objCall.Text = if carrying then "RAMÈNE LE DRAPEAU À TA BASE" .. (if me.state ~= "home" then " — RÉCUPÈRE D'ABORD LE TIEN" else "") else ""
	objCall.TextTransparency = if carrying then 0.25 + 0.25 * math.sin(os.clock() * 6) else 0
	for team, f in pairs(flags) do
		if not (f.state == "carried" and f.carrierUserId == player.UserId) then
			marker("ctf" .. team, f.pos + Vector3.new(0, 11, 0), "🚩", teamColor(team), 30)
		end
	end
end

RunService.RenderStepped:Connect(function()
	objFrame.Visible = false; domRow.Visible = false; objFrame.Position = UDim2.new(0.5, 0, 0, 146)
	objSub.TextColor3 = C.dim; objCall.TextTransparency = 0
	moneyLabel.Visible = false; useWrap.Visible = false; useHint.Visible = false; bombPanel.Visible = false
	buyTouch.Visible = false; useTouch.Visible = false
	local d = data
	if inMatch and st and st.state == "live" and not st.warmup and d then
		local since = os.clock() - recvAt
		if d.kind == "rounds" then drawRounds(d, since)
		elseif d.kind == "koth" then drawKoth(d)
		elseif d.kind == "dom" then drawDom(d)
		elseif d.kind == "ctf" then drawCtf(d) end
	end
	if not (d and d.kind == "rounds" and d.revealed) then setReveal(false) end
	if not (inMatch and d and d.kind == "rounds") then countdown.TextTransparency = 1; countdown.TextStrokeTransparency = 1 end
	sweepMarkers()
end)
