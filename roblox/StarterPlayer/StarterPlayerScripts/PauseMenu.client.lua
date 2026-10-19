--!strict
-- StarterPlayerScripts/PauseMenu (LocalScript)
-- Pause en partie (menu Échap du web) : REPRENDRE (action principale), RÉGLAGES, MENU PRINCIPAL, puis plus petits
-- MODE PHOTO et QUITTER LA PARTIE (deuxième appui pour confirmer).
-- S'ouvre avec P ou la croix bas (MainMenu passe la main ici quand on est en partie, via S.panels.pause), avec Échap
-- (Roblox ouvre aussi son propre menu : en le refermant, on retrouve la pause) et avec le bouton ⏸ sur téléphone.
-- Le panneau Réglages est celui du menu principal (Menu/Options, mêmes onglets : MenuConfig.SETTINGS_TABS) : chaque réglage s'applique tout de suite
-- et est enregistré dans le profil. La partie continue derrière (jeu en ligne) : on ne peut ni tirer ni bouger pendant la pause.
-- Affiche aussi les compteurs FPS / ping en haut à droite quand ils sont activés dans les options.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

local Modes = require(ReplicatedStorage.Shared.Modes)
local MenuConfig = require(ReplicatedStorage.Shared.MenuConfig)
local S = require(ReplicatedStorage.Shared.ClientState)
local MenuDir = script.Parent:WaitForChild("Menu")
local K = require(MenuDir:WaitForChild("Kit"))
local Options = require(MenuDir:WaitForChild("Options"))
local C = K.C
local make, text, spaced = K.make, K.text, K.spaced

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function zone(): string
	local z = player:GetAttribute("Zone")
	return if typeof(z) == "string" then z else ""
end
local function invoke(name: string, ...: any): any
	local r = ReplicatedStorage:FindFirstChild(name)
	if not r or not r:IsA("RemoteFunction") then return nil end
	local ok, res = pcall(r.InvokeServer, r, ...)
	if not ok then warn("[PauseMenu]", name, res); return nil end
	return res
end

-- ---------- interface ----------
local gui = make("ScreenGui", { Name = "PauseMenu", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 25, Enabled = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, playerGui)
-- voile : sombre, un peu plus à gauche et en bas (comme le fond du menu)
local dim = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BackgroundColor3 = K.rgb(0x05080e) }, gui)
make("UIGradient", { Transparency = NumberSequence.new(0, 0.25), Rotation = -30 }, dim)
local modal = make("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromOffset(1, 1), Modal = true, Selectable = false, Visible = false }, gui)
-- panneau : un CanvasGroup pour le fondu d'ensemble, un UIScale pour tenir dans l'écran (et l'effet de zoom à l'ouverture)
local panel = make("CanvasGroup", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(420, 470),
	GroupTransparency = 1 }, gui)
K.corner(panel, 14); K.stroke(panel, C.white, 1, 0.88)
-- fond en dégradé sur un cadre à part : un UIGradient posé sur le CanvasGroup teinterait tout son contenu
local bg = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.04, BackgroundColor3 = C.white }, panel)
K.gradient(bg, K.rgb(0x141d30), K.rgb(0x0b111c), 90)
local fit = make("UIScale", {}, panel)
-- barre rouge en haut (bord des panneaux du web)
local topBar = make("Frame", { Size = UDim2.new(1, 0, 0, 3), BackgroundTransparency = 0, BackgroundColor3 = C.white, ZIndex = 5 }, panel)
K.gradient(topBar, C.orange, C.accent, 0)
local content = make("Frame", { Size = UDim2.fromScale(1, 1) }, panel)

-- compteurs FPS / ping et bouton pause tactile (toujours là, hors du panneau)
local hud = make("ScreenGui", { Name = "PauseHud", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 9 }, playerGui)
local perf = text(hud, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Size = UDim2.fromOffset(200, 18), TextSize = 12, Font = K.BOLD,
	TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false, TextStrokeTransparency = 0.5, Visible = false })
local touchBtn = K.btn(hud, "⏸", "dark", nil, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0.3, 0), Size = UDim2.fromOffset(48, 48),
	TextSize = 20, Visible = false, Name = "PauseButton" })
K.corner(touchBtn, 24)
local c = touchBtn:FindFirstChildOfClass("UICorner"); if c then c.CornerRadius = UDim.new(0, 24) end

-- ---------- état ----------
local open = false
local view = "main"
local optSub = Options.SUBS[1]
local lastToggle = 0

local controls: any = nil
task.spawn(function()
	local ps = player:WaitForChild("PlayerScripts")
	local pm = ps:WaitForChild("PlayerModule", 10)
	if pm and pm:IsA("ModuleScript") then
		local ok, m = pcall(require, pm)
		if ok and m and (m :: any).GetControls then controls = (m :: any):GetControls() end
	end
end)

local function computeFit(): number
	local cam = workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	local s = math.clamp(math.min(vp.X / 1280, vp.Y / 720), 0.6, 1.6)
	local acc = gui:FindFirstChild("AccessScale")   -- UIScale posé par AccessibilityController sur chaque ScreenGui
	return s / (if acc and acc:IsA("UIScale") and acc.Scale > 0 then acc.Scale else 1)
end
-- taille du panneau options : grande, mais dans l'écran
local function optionsSize(s: number): Vector2
	local cam = workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	return Vector2.new(math.min(900, vp.X / s - 40), math.min(620, vp.Y / s - 40))
end

local setOpen: (boolean) -> ()
local render: () -> ()

-- les boutons de la vue principale arrivent l'un après l'autre
local function stagger(list: { GuiObject })
	for i, b in ipairs(list) do
		local sc = K.fxScale(b)
		sc.Scale = 0.85
		game:GetService("TweenService"):Create(sc, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.05 + (i - 1) * 0.04), { Scale = 1 }):Play()
	end
end

local quitArmed = 0
local function mainView(animate: boolean)
	panel.Size = UDim2.fromOffset(420, 470)
	K.pad(content, 28, 26, 28, 22)
	K.vlist(content, 10, Enum.HorizontalAlignment.Center)
	text(content, { Text = spaced("PAUSE", 4), Font = K.BLACK, TextSize = 34, Size = UDim2.new(1, 0, 0, 40), TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false, LayoutOrder = 1 })
	local mm = player:GetAttribute("MatchMode")
	local mdef = if typeof(mm) == "string" then Modes.LIST[mm] else nil
	text(content, { Text = '<font color="#ff4655">●</font>  ' .. spaced("PARTIE EN COURS", 1) .. (if mdef then "  ·  " .. mdef.n else ""), TextSize = 11, TextColor3 = C.dim,
		Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, LayoutOrder = 2 })
	text(content, { Text = "La partie continue pendant la pause.", TextSize = 11, TextColor3 = C.mute, Size = UDim2.new(1, 0, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, LayoutOrder = 3 })
	local list: { GuiObject } = {}
	local function add(label: string, kind: string, cb: () -> (), h: number?): TextButton
		local b = K.btn(content, label, kind, cb, { Size = UDim2.new(1, 0, 0, h or 46), TextSize = if h then 12 else 14, LayoutOrder = 10 + #list })
		table.insert(list, b)
		return b
	end
	local resume = add("▶  " .. spaced("REPRENDRE", 2), "primary", function() setOpen(false) end, 54)
	resume.TextSize = 16
	add("⚙  " .. spaced("RÉGLAGES", 2), "alt", function() view = "options"; render() end)
	add("☰  " .. spaced("MENU PRINCIPAL", 2), "alt", function()
		setOpen(false)
		local m = S.panels.menu
		if m then task.spawn(m) end
	end)
	add("📷  " .. spaced("MODE PHOTO", 2), "dark", function()
		setOpen(false)
		local ok, err = pcall(function() require(ReplicatedStorage.Shared.PhotoMode).enter() end)
		if not ok then warn("[PauseMenu] PhotoMode", err) end
	end, 38)
	-- quitter : deuxième appui pour confirmer (le web demande aussi une confirmation)
	local quit: TextButton
	quit = add(spaced("QUITTER LA PARTIE", 1), "dark", function()
		if os.clock() - quitArmed < 3 then
			quitArmed = 0
			setOpen(false)
			task.spawn(invoke, "MatchLeave")
		else
			quitArmed = os.clock()
			quit.Text = spaced("CONFIRMER ?", 2); quit.TextColor3 = C.accent
			task.delay(3, function()
				if quit.Parent and os.clock() - quitArmed >= 3 then quit.Text = spaced("QUITTER LA PARTIE", 1); quit.TextColor3 = C.white end
			end)
		end
	end, 38)
	text(content, { Text = "P · Échap · B pour reprendre", TextSize = 11, TextColor3 = C.mute, Size = UDim2.new(1, 0, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, LayoutOrder = 40 })
	if animate then stagger(list) end
	if UserInputService.GamepadEnabled then GuiService.SelectedObject = resume end
end

local function optionsView(slide: number?)
	local s = computeFit()
	local size = optionsSize(s)
	panel.Size = UDim2.fromOffset(size.X, size.Y)
	-- en-tête : retour, titre, onglets
	local back = K.btn(content, "◀  " .. spaced("RETOUR", 1), "dark", function() view = "main"; render() end,
		{ Position = UDim2.fromOffset(20, 18), Size = UDim2.fromOffset(110, 32), TextSize = 11 })
	text(content, { Text = spaced("RÉGLAGES", 3), Font = K.BLACK, TextSize = 22, Position = UDim2.fromOffset(146, 18), Size = UDim2.fromOffset(240, 32), TextWrapped = false })
	local tabs = make("Frame", { Position = UDim2.fromOffset(20, 62), Size = UDim2.new(1, -40, 0, 36) }, content)
	K.hlist(tabs, 6)
	for i, sub in ipairs(Options.SUBS) do
		local def = MenuConfig.settingsTab(sub)
		K.chip(tabs, spaced(if def then def.n else sub, 1), sub == optSub, function()
			if sub == optSub then return end
			local old = table.find(Options.SUBS, optSub) or 1
			optSub = sub
			render()
			-- le contenu glisse depuis le côté de l'onglet choisi
			local area = content:FindFirstChild("Area")
			if area and area:IsA("GuiObject") then
				area.Position = UDim2.fromOffset(20 + (if i > old then 30 else -30), 128)
				K.tween(area, 0.26, { Position = UDim2.fromOffset(20, 128) }, Enum.EasingStyle.Quint)
			end
		end, { LayoutOrder = i })
	end
	-- phrase d'aide de l'onglet
	local cur = MenuConfig.settingsTab(optSub)
	text(content, { Text = if cur then cur.help else "", Position = UDim2.fromOffset(20, 102), Size = UDim2.new(1, -40, 0, 18), TextSize = 12, Font = K.MED,
		TextColor3 = C.sub, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
	local area = make("Frame", { Name = "Area", Position = UDim2.fromOffset(20 + (slide or 0), 128), Size = UDim2.new(1, -40, 1, -144) }, content)
	local sc = K.scroll(area, { Name = "Opt" .. optSub })
	K.vlist(sc, 14); K.pad(sc, 0, 4, 8, 12)
	Options.build(sc, math.floor(size.X - 50), optSub, function() render() end)
	if slide then K.tween(area, 0.26, { Position = UDim2.fromOffset(20, 128) }, Enum.EasingStyle.Quint) end
	if UserInputService.GamepadEnabled then GuiService.SelectedObject = back end
end

local lastView = ""
render = function()
	if not open then return end
	-- garder la position de défilement quand une puce redessine la page
	local keep: Vector2? = nil
	local old = content:FindFirstChild("Area")
	local oldSc = old and old:FindFirstChildWhichIsA("ScrollingFrame")
	if oldSc and oldSc.Name == "Opt" .. optSub then keep = oldSc.CanvasPosition end
	for _, ch in ipairs(content:GetChildren()) do ch:Destroy() end
	local changed = view ~= lastView
	lastView = view
	if view == "options" then optionsView(if changed then 30 else nil) else mainView(changed) end
	if keep then
		local area = content:FindFirstChild("Area")
		local sc = area and area:FindFirstChildWhichIsA("ScrollingFrame")
		if sc then task.defer(function() sc.CanvasPosition = keep :: Vector2 end) end
	end
end

-- ---------- ouverture / fermeture ----------
local function bindActions(on: boolean)
	if on then
		ContextActionService:BindActionAtPriority("PauseBack", function(_, st)
			if st == Enum.UserInputState.Begin then
				if view == "options" then view = "main"; render() else setOpen(false) end
			end
			return Enum.ContextActionResult.Sink
		end, false, 3000, Enum.KeyCode.ButtonB)
	else
		ContextActionService:UnbindAction("PauseBack")
	end
end

local closeN = 0
setOpen = function(on: boolean)
	if on and (zone() ~= "match" or S.menuOpen) then return end
	if on == open then return end
	lastToggle = os.clock()
	open = on
	closeN += 1
	local my = closeN
	modal.Visible = on
	touchBtn.Visible = false
	player:SetAttribute("UiOpen", if on then true else nil)   -- WeaponController : pas de tir, souris visible
	if controls then pcall(function() if on then controls:Disable() else controls:Enable() end end) end
	bindActions(on)
	if on then
		view = "main"; lastView = ""; quitArmed = 0
		gui.Enabled = true
		local s = computeFit()
		render()
		-- arrivée : voile qui s'assombrit, panneau qui apparaît en fondu en grossissant un peu
		dim.BackgroundTransparency = 1
		K.tween(dim, 0.2, { BackgroundTransparency = 0.4 })
		panel.GroupTransparency = 1
		fit.Scale = s * 0.92
		K.tween(panel, 0.22, { GroupTransparency = 0 })
		K.tween(fit, 0.34, { Scale = s }, Enum.EasingStyle.Back)
	else
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then GuiService.SelectedObject = nil end
		K.tween(dim, 0.14, { BackgroundTransparency = 1 })
		K.tween(panel, 0.14, { GroupTransparency = 1 })
		K.tween(fit, 0.14, { Scale = computeFit() * 0.96 })
		task.delay(0.15, function()
			if my == closeN and not open then gui.Enabled = false; for _, ch in ipairs(content:GetChildren()) do ch:Destroy() end end
		end)
	end
end
local function toggle()
	if os.clock() - lastToggle < 0.25 then return end   -- Échap peut arriver deux fois (touche + menu Roblox)
	setOpen(not open)
end
S.panels.pause = toggle

-- Échap : Roblox garde la touche pour son menu ; quand il s'ouvre en partie, la pause s'ouvre dessous
GuiService.MenuOpened:Connect(function()
	if not open and zone() == "match" and not S.menuOpen then toggle() end
end)
UserInputService.InputBegan:Connect(function(input: InputObject)
	if input.KeyCode == Enum.KeyCode.Escape and (open or zone() == "match") then toggle() end
end)
touchBtn.Activated:Connect(function() setOpen(true) end)

-- une autre interface relâche « UiOpen » pendant la pause : on le reprend
player:GetAttributeChangedSignal("UiOpen"):Connect(function()
	if open and player:GetAttribute("UiOpen") ~= true then player:SetAttribute("UiOpen", true) end
end)
-- fin de partie : la pause se ferme
player:GetAttributeChangedSignal("Zone"):Connect(function()
	if open and zone() ~= "match" then setOpen(false) end
end)
-- écran redimensionné : le panneau suit
local function watchCamera(cam: Camera?)
	if not cam then return end
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if open then fit.Scale = computeFit(); if view == "options" then render() end end
	end)
end
watchCamera(workspace.CurrentCamera)
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() watchCamera(workspace.CurrentCamera) end)

-- ---------- compteurs FPS / ping, bouton tactile ----------
local frames, acc = 0, 0
RunService.RenderStepped:Connect(function(dt: number)
	frames += 1; acc += dt
	if acc < 0.5 then return end
	local fps = frames / acc
	frames, acc = 0, 0
	local parts = {}
	if S.opt.showFps then
		local col = if fps >= 50 then "#7dff9f" elseif fps >= 30 then "#ffd23a" else "#ff4655"
		table.insert(parts, '<font color="' .. col .. '">' .. math.floor(fps + 0.5) .. "</font> FPS")
	end
	if S.opt.showPing then
		local ok, ping = pcall(function() return player:GetNetworkPing() end)
		local ms = if ok and typeof(ping) == "number" then math.floor(ping * 1000 + 0.5) else 0
		local col = if ms <= 80 then "#7dff9f" elseif ms <= 160 then "#ffd23a" else "#ff4655"
		table.insert(parts, '<font color="' .. col .. '">' .. ms .. "</font> ms")
	end
	perf.Visible = #parts > 0
	perf.Text = table.concat(parts, "  ·  ")
	touchBtn.Visible = UserInputService.TouchEnabled and not open and zone() == "match" and not S.menuOpen
end)
