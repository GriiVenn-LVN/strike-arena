--!strict
-- StarterPlayerScripts/ShopUI (LocalScript)
-- Écran boutique simple : un bouton « Boutique », 5 onglets, les offres du jour en haut, une grille d'objets avec Acheter / Équiper.
-- Le serveur (ShopService) vérifie chaque achat ; ici on ne fait qu'afficher.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.ShopCatalog)

local player = Players.LocalPlayer
local getShop = ReplicatedStorage:WaitForChild("GetShop") :: RemoteFunction
local shopBuy = ReplicatedStorage:WaitForChild("ShopBuy") :: RemoteFunction
local shopEquip = ReplicatedStorage:WaitForChild("ShopEquip") :: RemoteFunction
local equipSkin = ReplicatedStorage:WaitForChild("EquipSkin") :: RemoteFunction

local DARK = Color3.fromRGB(13, 18, 29)
local PANEL = Color3.fromRGB(22, 29, 44)
local ACCENT = Color3.fromRGB(255, 70, 85)
local MUTED = Color3.fromRGB(70, 80, 100)

local gui = Instance.new("ScreenGui"); gui.Name = "ShopUI"; gui.ResetOnSpawn = false; gui.Parent = player:WaitForChild("PlayerGui")

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local o: any = Instance.new(className)
	if className == "TextLabel" or className == "TextButton" then
		o.Font = Enum.Font.GothamBold
		o.TextColor3 = Color3.new(1, 1, 1)
	end
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(o: Instance, r: number) make("UICorner", { CornerRadius = UDim.new(0, r) }, o) end

-- ---------- Bouton d'ouverture ----------
local openBtn = make("TextButton", { Size = UDim2.fromOffset(150, 40), Position = UDim2.new(1, -170, 0, 20), BackgroundColor3 = ACCENT,
	Text = "🛒 Boutique", TextSize = 18, Font = Enum.Font.GothamBlack }, gui)
corner(openBtn, 8)

-- ---------- Fenêtre ----------
local win = make("Frame", { Size = UDim2.fromOffset(760, 500), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = DARK, Visible = false }, gui)
corner(win, 12)
make("TextLabel", { Size = UDim2.fromOffset(300, 40), Position = UDim2.fromOffset(20, 10), BackgroundTransparency = 1, Text = "BOUTIQUE",
	TextSize = 26, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left }, win)
local coinsLabel = make("TextLabel", { Size = UDim2.fromOffset(200, 40), Position = UDim2.new(1, -270, 0, 10), BackgroundTransparency = 1,
	Text = "🪙 …", TextSize = 20, TextXAlignment = Enum.TextXAlignment.Right }, win)
local closeBtn = make("TextButton", { Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -55, 0, 10), BackgroundColor3 = PANEL, Text = "✕", TextSize = 20 }, win)
corner(closeBtn, 8)
local toast = make("TextLabel", { Size = UDim2.new(1, -40, 0, 24), Position = UDim2.new(0, 20, 1, -30), BackgroundTransparency = 1, Text = "",
	TextSize = 15, TextColor3 = Color3.fromRGB(255, 210, 120) }, win)

local tabBar = make("Frame", { Size = UDim2.new(1, -40, 0, 36), Position = UDim2.fromOffset(20, 56), BackgroundTransparency = 1 }, win)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }, tabBar)

-- Offres du jour (toujours visibles)
local offersTitle = make("TextLabel", { Size = UDim2.new(1, -40, 0, 20), Position = UDim2.fromOffset(20, 98), BackgroundTransparency = 1,
	Text = "Offres du jour (-25 %)", TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 185, 56) }, win)
local offersRow = make("Frame", { Size = UDim2.new(1, -40, 0, 70), Position = UDim2.fromOffset(20, 120), BackgroundTransparency = 1 }, win)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }, offersRow)

-- Sélecteur d'arme (onglets Skins et Viseurs)
local weaponBar = make("Frame", { Size = UDim2.new(1, -40, 0, 32), Position = UDim2.fromOffset(20, 198), BackgroundTransparency = 1 }, win)
local prevW = make("TextButton", { Size = UDim2.fromOffset(32, 32), BackgroundColor3 = PANEL, Text = "◀", TextSize = 16 }, weaponBar)
local weaponLabel = make("TextLabel", { Size = UDim2.fromOffset(220, 32), Position = UDim2.fromOffset(40, 0), BackgroundTransparency = 1, Text = "", TextSize = 17 }, weaponBar)
local nextW = make("TextButton", { Size = UDim2.fromOffset(32, 32), Position = UDim2.fromOffset(268, 0), BackgroundColor3 = PANEL, Text = "▶", TextSize = 16 }, weaponBar)
corner(prevW, 6); corner(nextW, 6)

local grid = make("ScrollingFrame", { Size = UDim2.new(1, -40, 1, -270), Position = UDim2.fromOffset(20, 236), BackgroundTransparency = 1,
	ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new() }, win)
make("UIGridLayout", { CellSize = UDim2.fromOffset(170, 96), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, grid)

-- ---------- État ----------
local state: any = nil
local currentTab = "weapons"
local gunKeys = {}
for _, k in ipairs(Catalog.WEAPON_KEYS) do if not Config.WEAPONS[k].melee then table.insert(gunKeys, k) end end
local weaponIndex = table.find(gunKeys, "ak") or 1

local render: () -> ()

local function refresh()
	state = getShop:InvokeServer()
	if state then coinsLabel.Text = "🪙 " .. state.coins end
	render()
end

local function say(text: string)
	toast.Text = text
	task.delay(3, function() if toast.Text == text then toast.Text = "" end end)
end

-- Libellé et action du bouton d'un objet
local function actionFor(it: any): (string, Color3, (() -> ())?)
	if it.kind == "devproduct" or it.kind == "vip" then   -- vip = abonnement Premium, se rachète pour ajouter des jours
		if it.productId <= 0 then return "Bientôt", MUTED, nil end
		return "R$ " .. it.robux, Color3.fromRGB(0, 176, 111), function()
			shopBuy:InvokeServer(it.id)                   -- Roblox affiche sa propre fenêtre de paiement
		end
	end
	local owned = state.owned[it.id]
	if it.kind == "exclusive" and not owned then                 -- exclusif : Robux uniquement
		if it.productId <= 0 then return "Bientôt", MUTED, nil end
		return "R$ " .. it.robux, Color3.fromRGB(0, 176, 111), function()
			shopBuy:InvokeServer(it.id)
		end
	end
	if it.kind == "killfx" and not owned and it.source ~= "coins" then   -- effet d'élimination exclusif, de code ou de groupe
		if it.source == "code" then return "Code 🔑", MUTED, nil end
		if it.source == "group" then return "Groupe 👥", MUTED, nil end
		if it.productId <= 0 then return "Bientôt", MUTED, nil end
		return "R$ " .. it.robux, Color3.fromRGB(0, 176, 111), function()
			shopBuy:InvokeServer(it.id)
		end
	end
	if not owned then
		local price = it.price
		for _, o in ipairs(state.offers) do if o.id == it.id then price = o.price end end
		return "🪙 " .. price, if state.coins >= price then ACCENT else MUTED, function()
			local res = shopBuy:InvokeServer(it.id)
			say(if res and res.ok then "Acheté : " .. it.name else "Achat impossible : " .. (res and res.err or "erreur"))
			refresh()
		end
	end
	local eq = state.equipped
	local weapon = gunKeys[weaponIndex]
	local isEquipped = (it.kind == "outfit" and eq.outfit == it.outfit) or (it.kind == "reticle" and eq.reticle == it.reticle)
		or (it.kind == "trail" and eq.trail == it.trail) or (it.kind == "sight" and eq.sights[weapon] == it.sight)
		or (it.kind == "skin" and state.equippedSkins[it.weapon] == it.skin)
		or (it.kind == "exclusive" and it.camo ~= nil and (eq.animCamo or {})[weapon] == it.camo)
		or (it.kind == "killfx" and (eq.killFx or "none") == it.fx)
	if isEquipped then return "Équipé", MUTED, nil end
	if it.kind == "weapon" or it.kind == "misc" or (it.kind == "exclusive" and not it.camo) then return "Possédé", MUTED, nil end
	return "Équiper", Color3.fromRGB(74, 163, 255), function()
		local ok
		if it.kind == "skin" then ok = equipSkin:InvokeServer(it.weapon, it.skin)
		else ok = shopEquip:InvokeServer(it.id, weapon) end
		if not ok then say("Impossible d'équiper cet objet") end
		refresh()
	end
end

local function card(it: any, parent: Instance, order: number, small: boolean?)
	local f = make("Frame", { BackgroundColor3 = PANEL, LayoutOrder = order, Size = if small then UDim2.fromOffset(170, 70) else UDim2.new() }, parent)
	corner(f, 8)
	make("Frame", { Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = Config.RARITY[it.rarity].color, BorderSizePixel = 0 }, f)
	make("TextLabel", { Size = UDim2.new(1, -16, 0, 36), Position = UDim2.fromOffset(12, 4), BackgroundTransparency = 1, Text = it.name,
		TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, f)
	local text, color, cb = actionFor(it)
	local b = make("TextButton", { Size = UDim2.new(1, -20, 0, 26), Position = UDim2.new(0, 12, 1, -32), BackgroundColor3 = color, Text = text, TextSize = 14 }, f)
	corner(b, 6)
	if cb then b.MouseButton1Click:Connect(cb) else b.AutoButtonColor = false end
end

render = function()
	for _, c in ipairs(grid:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
	for _, c in ipairs(offersRow:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
	for _, c in ipairs(tabBar:GetChildren()) do if c:IsA("TextButton") then c.BackgroundColor3 = if c.Name == currentTab then ACCENT else PANEL end end
	if not state then return end

	local hours = math.floor(state.secondsToReset / 3600)
	offersTitle.Text = string.format("Offres du jour (-25 %%) · nouvelles offres dans %d h %02d", hours, math.floor(state.secondsToReset % 3600 / 60))
	for i, o in ipairs(state.offers) do card(Catalog.get(o.id), offersRow, i, true) end

	local weapon = gunKeys[weaponIndex]
	weaponBar.Visible = currentTab == "skins" or currentTab == "sights" or currentTab == "exclusive"
	weaponLabel.Text = Config.WEAPONS[weapon].name
	grid.Position = UDim2.fromOffset(20, if weaponBar.Visible then 236 else 198)
	grid.Size = UDim2.new(1, -40, 1, if weaponBar.Visible then -270 else -232)

	local order = 0
	for _, it in ipairs(Catalog.ITEMS) do
		if it.tab == currentTab and (it.kind ~= "skin" or it.weapon == weapon) then
			order += 1
			card(it, grid, order)
		end
	end
end

for _, tab in ipairs(Catalog.TABS) do
	local b = make("TextButton", { Name = tab.id, Size = UDim2.fromOffset(82, 36), BackgroundColor3 = PANEL, Text = tab.name, TextSize = 12 }, tabBar)
	corner(b, 6)
	b.MouseButton1Click:Connect(function() currentTab = tab.id; render() end)
end
prevW.MouseButton1Click:Connect(function() weaponIndex = (weaponIndex - 2) % #gunKeys + 1; render() end)
nextW.MouseButton1Click:Connect(function() weaponIndex = weaponIndex % #gunKeys + 1; render() end)

openBtn.MouseButton1Click:Connect(function()
	win.Visible = not win.Visible
	if win.Visible then refresh() end
end)
closeBtn.MouseButton1Click:Connect(function() win.Visible = false end)

-- Après un achat Robux, Roblox crédite côté serveur : on rafraîchit quand la fenêtre de paiement se ferme
game:GetService("MarketplaceService").PromptProductPurchaseFinished:Connect(function(userId: number, _productId: number, purchased: boolean)
	if userId == player.UserId and purchased and win.Visible then task.wait(1); refresh() end
end)
