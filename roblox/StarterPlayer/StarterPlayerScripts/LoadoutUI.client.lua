--!strict
-- StarterPlayerScripts/LoadoutUI (LocalScript)
-- Menu de chargement (touche B ou bouton « 🔫 Armes ») : choisir son arme principale et son pistolet.
-- Les armes non débloquées sont affichées avec un cadenas et leur prix en pièces (achat dans la Boutique).
-- Le serveur revérifie tout (SetLoadout dans TDMService) ; le choix est gardé dans le profil et appliqué à la prochaine apparition.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")

local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.ShopCatalog)
local ModeConfig = require(ReplicatedStorage.Shared.ModeConfig)

local player = Players.LocalPlayer
local setLoadout = ReplicatedStorage:WaitForChild("SetLoadout", 30) :: RemoteFunction?
local getProfile = ReplicatedStorage:WaitForChild("GetProfile") :: RemoteFunction

local C = {
	bg = Color3.fromRGB(13, 18, 29), panel = Color3.fromRGB(22, 29, 44), card = Color3.fromRGB(30, 38, 56), text = Color3.new(1, 1, 1),
	dim = Color3.fromRGB(150, 160, 180), accent = Color3.fromRGB(255, 70, 85), green = Color3.fromRGB(80, 230, 140), gold = Color3.fromRGB(255, 200, 60),
}
local CAT_NAME = { pistol = "Pistolet", smg = "Mitraillette", shotgun = "Fusil à pompe", rifle = "Fusil d'assaut", sniper = "Précision", lmg = "Mitrailleuse" }
local CAT_ORDER = { "rifle", "smg", "shotgun", "sniper", "lmg", "pistol" }

local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local o: any = Instance.new(class)
	if class == "TextLabel" or class == "TextButton" then o.Font = Enum.Font.GothamBold; o.TextColor3 = C.text; o.BorderSizePixel = 0 end
	if class == "TextLabel" then o.BackgroundTransparency = 1 end
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(o: Instance, r: number?) make("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o) end

local gui = make("ScreenGui", { Name = "LoadoutUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 14 }, player:WaitForChild("PlayerGui"))
local openBtn = make("TextButton", { Size = UDim2.fromOffset(150, 40), Position = UDim2.new(1, -170, 0, 164), BackgroundColor3 = C.accent,
	Text = "🔫 Armes (B)", TextSize = 18, Font = Enum.Font.GothamBlack }, gui)
corner(openBtn)

local win = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.8, 0, 0.8, 0),
	BackgroundColor3 = C.bg, Visible = false, ZIndex = 50 }, gui)
corner(win, 14); make("UIStroke", { Color = C.accent, Thickness = 2 }, win)
make("UISizeConstraint", { MaxSize = Vector2.new(1100, 720) }, win)
make("TextLabel", { Size = UDim2.new(1, -80, 0, 50), Position = UDim2.fromOffset(24, 10), Text = "CHARGEMENT", TextSize = 28, Font = Enum.Font.GothamBlack,
	TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.accent, ZIndex = 51 }, win)
local hint = make("TextLabel", { Size = UDim2.new(1, -48, 0, 20), Position = UDim2.fromOffset(24, 56), Text = "", TextSize = 14, TextColor3 = C.dim,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 51 }, win)
local close = make("TextButton", { Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -54, 0, 14), BackgroundColor3 = C.panel, Text = "✕", TextSize = 20,
	Modal = true, ZIndex = 52 }, win)   -- Modal : libère le curseur en vue à la première personne
corner(close)

make("TextLabel", { Size = UDim2.new(1, -48, 0, 16), Position = UDim2.new(0, 24, 1, -18), TextSize = 11, TextColor3 = C.dim,
	Text = "Modèles d'armes : série « Low-Poly » de TastyTony (Sketchfab), licence CC BY 4.0", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 51 }, win)

-- onglets
local tabs = make("Frame", { Size = UDim2.new(1, -48, 0, 40), Position = UDim2.fromOffset(24, 84), BackgroundTransparency = 1, ZIndex = 51 }, win)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }, tabs)
local list = make("ScrollingFrame", { Size = UDim2.new(1, -48, 1, -160), Position = UDim2.fromOffset(24, 134), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 51 }, win)
make("UIGridLayout", { CellSize = UDim2.fromOffset(240, 150), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder }, list)

local state = { tab = "primary", profile = nil :: any }

local function bar(parent: Instance, y: number, label: string, frac: number, color: Color3)
	make("TextLabel", { Size = UDim2.fromOffset(70, 14), Position = UDim2.fromOffset(12, y), Text = label, TextSize = 12, TextColor3 = C.dim,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 53 }, parent)
	local back = make("Frame", { Size = UDim2.new(1, -96, 0, 6), Position = UDim2.fromOffset(84, y + 4), BackgroundColor3 = C.panel, BorderSizePixel = 0, ZIndex = 53 }, parent)
	corner(back, 3)
	local fill = make("Frame", { Size = UDim2.fromScale(math.clamp(frac, 0.04, 1), 1), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 54 }, back)
	corner(fill, 3)
end

local function owned(key: string): boolean
	return Catalog.STARTER_WEAPONS[key] == true or (state.profile ~= nil and Catalog.ownsWeapon(state.profile, key))
end

local function current(slot: number): string
	local attr = player:GetAttribute(if slot == 0 then "Primary" else "Secondary")
	if typeof(attr) == "string" then return attr end
	local team = player.Team and player.Team.Name
	local base = team and ModeConfig.TDM.loadout[team]
	if base then return if slot == 0 then base.primary else base.secondary end
	return if slot == 0 then "galil" else "glock"
end

local render: () -> ()

local function choose(key: string)
	if not setLoadout then return end
	local ok = setLoadout:InvokeServer(key)
	hint.Text = if ok then "✅ " .. Config.WEAPONS[key].name .. " choisi : tu l'auras à ta prochaine apparition." else "Cette arme n'est pas encore débloquée."
	hint.TextColor3 = if ok then C.green else C.accent
	render()
end

-- onglets Armurier / Viseurs (panneaux de l'Arsenal du web)
local host = make("Frame", { Size = UDim2.new(1, -48, 1, -160), Position = UDim2.fromOffset(24, 134), BackgroundTransparency = 1, ClipsDescendants = true,
	Visible = false, ZIndex = 51 }, win)
local panel: { destroy: () -> (), refresh: () -> () }? = nil
local panelTab: string? = nil
local Panels: any = nil
pcall(function() Panels = require(ReplicatedStorage.Shared.ArsenalPanels) end)

render = function()
	local isPanel = state.tab == "arms" or state.tab == "sights"
	list.Visible = not isPanel; host.Visible = isPanel
	if panel and panelTab ~= state.tab then pcall(panel.destroy); panel = nil; panelTab = nil end
	if isPanel then
		if not panel and Panels then
			local ok, p = pcall(Panels[state.tab], host)
			if ok then panel = p; panelTab = state.tab else warn("ArsenalPanels:", p) end
		end
		for _, b in ipairs(tabs:GetChildren()) do
			if b:IsA("TextButton") then b.BackgroundColor3 = if b.Name == state.tab then C.accent else C.panel end
		end
		return
	end
	for _, c in ipairs(list:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
	local slot = if state.tab == "primary" then 0 else 1
	local selected = current(slot)
	local keys = {}
	for key, w in pairs(Config.WEAPONS) do if w.slot == slot and not w.melee then table.insert(keys, key) end end
	table.sort(keys, function(a, b)
		local wa, wb = Config.WEAPONS[a], Config.WEAPONS[b]
		local ca, cb = table.find(CAT_ORDER, wa.cat) or 9, table.find(CAT_ORDER, wb.cat) or 9
		if ca ~= cb then return ca < cb end
		return wa.price < wb.price
	end)
	for i, key in ipairs(keys) do
		local w = Config.WEAPONS[key]
		local have = owned(key)
		local isSel = key == selected
		local card = make("TextButton", { LayoutOrder = i, BackgroundColor3 = if isSel then Color3.fromRGB(60, 30, 38) else C.card, Text = "", AutoButtonColor = have, ZIndex = 52 }, list)
		corner(card, 10)
		if isSel then make("UIStroke", { Color = C.accent, Thickness = 2 }, card) end
		make("TextLabel", { Size = UDim2.new(1, -24, 0, 24), Position = UDim2.fromOffset(12, 8), Text = w.name, TextSize = 18, Font = Enum.Font.GothamBlack,
			TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = if have then C.text else C.dim, ZIndex = 53 }, card)
		make("TextLabel", { Size = UDim2.new(1, -24, 0, 16), Position = UDim2.fromOffset(12, 32), Text = CAT_NAME[w.cat] or w.cat, TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.dim, ZIndex = 53 }, card)
		bar(card, 56, "Dégâts", w.dmg * w.pellets / 115, C.accent)
		bar(card, 74, "Cadence", w.rpm / 1000, C.gold)
		bar(card, 92, "Précision", 1 - math.min(1, w.spread / 2), C.green)
		bar(card, 110, "Mobilité", (w.speed - 0.75) / 0.3, Color3.fromRGB(74, 163, 255))
		local status = if isSel then "✔ ÉQUIPÉE" elseif have then "Choisir" else ("🔒 " .. Catalog.weaponPrice(key) .. " 🪙 · Boutique")
		make("TextLabel", { Size = UDim2.new(1, -24, 0, 18), Position = UDim2.new(0, 12, 1, -24), Text = status, TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = if isSel then C.accent elseif have then C.green else C.gold, ZIndex = 53 }, card)
		card.MouseButton1Click:Connect(function() if have and not isSel then choose(key) end end)
	end
	for _, b in ipairs(tabs:GetChildren()) do
		if b:IsA("TextButton") then b.BackgroundColor3 = if b.Name == state.tab then C.accent else C.panel end
	end
end

for _, t in ipairs({ { "primary", "Arme principale" }, { "secondary", "Pistolet" }, { "arms", "Armurier" }, { "sights", "Viseurs" } }) do
	local b = make("TextButton", { Name = t[1], Size = UDim2.fromOffset(180, 40), BackgroundColor3 = C.panel, Text = t[2], TextSize = 16, ZIndex = 52 }, tabs)
	corner(b)
	b.MouseButton1Click:Connect(function() state.tab = t[1]; render() end)
end

local function setOpen(on: boolean)
	win.Visible = on
	player:SetAttribute("UiOpen", on)
	if on then
		hint.Text = "Clique sur une arme pour la prendre à ta prochaine apparition."; hint.TextColor3 = C.dim
		task.spawn(function()
			local data = getProfile:InvokeServer()
			state.profile = data and data.profile
			if Panels then Panels.reload() end
			render()
		end)
		render()
	end
end
openBtn.MouseButton1Click:Connect(function() setOpen(not win.Visible) end)
close.MouseButton1Click:Connect(function() setOpen(false) end)
ContextActionService:BindAction("Loadout", function(_, st)
	if st == Enum.UserInputState.Begin then setOpen(not win.Visible) end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.B, Enum.KeyCode.DPadLeft)
player:GetAttributeChangedSignal("Primary"):Connect(function() if win.Visible then render() end end)
