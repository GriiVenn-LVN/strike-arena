--!strict
-- StarterPlayerScripts/PassUI (LocalScript)
-- Fenêtre du PASSE DE COMBAT (façon Fortnite / Call of Duty) : les 30 paliers de la saison sur une piste qui défile,
-- rangée GRATUITE en haut, rangée PREMIUM (dorée, cadenas tant qu'elle n'est pas débloquée) en bas, aperçu 3D des skins
-- des paliers Premium, barre d'XP vers le palier suivant, « TOUT RÉCUPÉRER », déblocage du Premium en pièces ou en Robux
-- (« Bientôt disponible » tant que le produit n'est pas créé dans ProductIds).
-- S'ouvre par S.panels.pass : carte Saison de l'accueil, bouton « VOIR LE PASSE » du bilan de fin de partie.
-- Serveur : BP_State, BP_Claim, BP_ClaimAll, BP_BuyPremium (ProgressService) et ShopBuy (ShopService) vérifient tout.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.ShopCatalog)
local ItemPreview = require(ReplicatedStorage.Shared.ItemPreview)
local S = require(ReplicatedStorage.Shared.ClientState)
local Icons = require(ReplicatedStorage.Shared.Icons)
local K = require(script.Parent:WaitForChild("Menu"):WaitForChild("Kit"))
local C = K.C
local make, text, spaced = K.make, K.text, K.spaced

local player = Players.LocalPlayer
local function call(name: string, ...: any): any
	local r = ReplicatedStorage:FindFirstChild(name)
	if not r or not r:IsA("RemoteFunction") then return nil end
	local ok, res = pcall((r :: RemoteFunction).InvokeServer, r :: RemoteFunction, ...)
	return if ok then res else nil
end

local gui = make("ScreenGui", { Name = "PassUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 32,   -- au-dessus du calendrier (31)
	Enabled = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
local veil = make("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = K.rgb(0x05080e), BackgroundTransparency = 0.35, Text = "", AutoButtonColor = false, Modal = true }, gui)
local win = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1120, 600), BackgroundTransparency = 0,
	BackgroundColor3 = C.white }, gui)
K.corner(win, 16); K.gradient(win, K.rgb(0x18122e), K.rgb(0x0b111c), 90); K.stroke(win, C.violet, 1.5, 0.5)
local winScale = make("UIScale", { Scale = 1 }, win)
local function fit()
	local cam = workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1600, 900)
	winScale.Scale = math.clamp(math.min((vp.X - 24) / 1120, (vp.Y - 24) / 600), 0.45, 1.2)
end

-- en-tête
local titleL = text(win, { Position = UDim2.fromOffset(28, 18), Size = UDim2.new(1, -420, 0, 30), Font = K.BLACK, TextSize = 26, TextWrapped = false,
	Text = "🎟  " .. spaced("PASSE DE COMBAT", 2) })
local seasonL = text(win, { Position = UDim2.fromOffset(30, 50), Size = UDim2.new(1, -420, 0, 18), TextSize = 13, TextColor3 = C.violet, TextWrapped = false, Text = "" })
local tierL = text(win, { Position = UDim2.fromOffset(28, 78), Size = UDim2.fromOffset(300, 34), Font = K.BLACK, TextSize = 30, TextWrapped = false, Text = "" })
local xpBar = K.bar(win, 0, { Position = UDim2.fromOffset(30, 118), Size = UDim2.fromOffset(420, 8) }, C.purple, C.violet)
local xpL = text(win, { Position = UDim2.fromOffset(30, 130), Size = UDim2.fromOffset(420, 14), TextSize = 11, TextColor3 = C.dim, TextWrapped = false, Text = "" })
local closeB = K.btn(win, "✕", "dark", function() gui.Enabled = false end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16), Size = UDim2.fromOffset(40, 40), TextSize = 18 })
local actions = make("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -70, 0, 18), Size = UDim2.fromOffset(560, 130) }, win)
K.vlist(actions, 8, Enum.HorizontalAlignment.Right)
local toastL = text(win, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(700, 20), TextSize = 13, TextColor3 = C.gold,
	TextXAlignment = Enum.TextXAlignment.Center, Text = "" })
local toastN = 0
local function toast(msg: string, col: Color3?)
	toastN += 1
	local my = toastN
	toastL.Text = msg; toastL.TextColor3 = col or C.gold
	task.delay(3.5, function() if my == toastN then toastL.Text = "" end end)
end
-- libellés des deux rangées (78 px : la rangée de paliers commence à 110 px, « ⭐ P  R  E  M… » mordait sur la 1re case)
text(win, { Position = UDim2.fromOffset(28, 168), Size = UDim2.fromOffset(78, 16), Font = K.BLACK, TextSize = 11, TextColor3 = C.sub, Text = spaced("GRATUIT", 1),
	TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
text(win, { Position = UDim2.fromOffset(28, 368), Size = UDim2.fromOffset(78, 16), Font = K.BLACK, TextSize = 11, TextColor3 = C.gold, Text = "⭐ " .. spaced("PREMIUM", 1),
	TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
local track = K.scroll(win, { Position = UDim2.fromOffset(110, 160), Size = UDim2.new(1, -130, 0, 400), ScrollingDirection = Enum.ScrollingDirection.X,
	AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollBarThickness = 6 })
K.hlist(track, 10, Enum.VerticalAlignment.Top)

local state: any = nil
local render: () -> ()

local function rewardLabel(r: any, item: any): (string, string)
	if r.item and item then
		local sk = Config.SKINS[item.skin]
		local w = Config.WEAPONS[item.weapon]
		return "🎨", (if sk then sk.name else "Skin") .. " · " .. (if w then w.name else item.weapon)
	end
	if r.box then return "📦", (if r.box == "prem" then "Caisse Premium" else "Caisse Standard") .. (if r.coins then " + " .. r.coins .. " 💰" else "") end
	if r.coins then return "💰", K.fmt(r.coins) .. " pièces" end
	return "•", ""
end

local function claim(t: number, prem: boolean)
	local res = call("BP_Claim", t, prem)
	if res then
		local _, txt = rewardLabel(res.reward or {}, res.item)
		toast("✔ Palier " .. t .. " : " .. txt .. (if res.item and res.item.duplicate then " (déjà possédé : pièces rendues)" else ""))
		pcall(function() K.uiSound(false) end)
	else
		toast("Impossible de récupérer ce palier", C.accent)
	end
	state = call("BP_State") or state
	render()
	local f = S.panels.menuRefresh; if f then task.spawn(f) end
end

local function cell(parent: Instance, t: number, prem: boolean, y: number)
	local def = state.tiers[t]
	local r = if prem then def.prem else def.free
	local reached = t <= state.tier
	local list = if prem then state.claimedPremium else state.claimedFree
	local got = table.find(list or {}, t) ~= nil
	local locked = prem and not state.premium
	local ready = reached and not got and not locked
	local accent = if prem then C.gold else C.blue
	local f = make("Frame", { Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(124, 180), BackgroundTransparency = 0, BackgroundColor3 = C.white }, parent)
	K.corner(f, 10)
	K.gradient(f, if prem then K.rgb(0x3a2a0a) else K.rgb(0x16233a), K.rgb(0x0b111c), 90, if reached then 0 else 0.35, if reached then 0 else 0.35)
	K.stroke(f, if ready then C.gold elseif got then C.green else accent, if ready then 2 else 1, if ready then 0 elseif reached then 0.4 else 0.8)
	local ic, txt = rewardLabel(r, def.item)
	if r.item and def.item then
		local box = make("Frame", { Position = UDim2.fromOffset(6, 10), Size = UDim2.new(1, -12, 0, 78) }, f)
		ItemPreview.weapon(box, def.item.weapon, def.item.skin, nil, nil, false)
		local rar = Config.RARITY[r.rarity or 2]
		text(f, { Position = UDim2.fromOffset(6, 86), Size = UDim2.new(1, -12, 0, 12), TextSize = 9, Font = K.BLACK, TextColor3 = rar and rar.color or C.white,
			TextXAlignment = Enum.TextXAlignment.Center, Text = spaced(string.upper(rar and rar.name or ""), 1) })
	else
		text(f, { Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 60), TextSize = 44, TextXAlignment = Enum.TextXAlignment.Center, Text = ic })
	end
	text(f, { Position = UDim2.fromOffset(6, 100), Size = UDim2.new(1, -12, 0, 34), TextSize = 11, Font = K.BOLD, TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top, Text = txt, TextColor3 = if prem then C.gold else C.text })
	if got then
		text(f, { Position = UDim2.new(0, 12, 1, -36), Size = UDim2.new(1, 0, 0, 26), TextSize = 13, Font = K.BLACK, TextColor3 = C.green,
			TextXAlignment = Enum.TextXAlignment.Center, Text = spaced("REÇU", 1) })
		-- coche verte dessinée devant « REÇU » (le ✔ texte sort en emoji gris)
		Icons.check(f, 16, C.green, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, -26, 1, -23) })
	elseif ready then
		local b = K.btn(f, spaced("RÉCUPÉRER", 1), "gold", function() claim(t, prem) end,
			{ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -16, 0, 28), TextSize = 11 })
		K.beat(b, 1.05, 1)
	else
		text(f, { Position = UDim2.new(0, 0, 1, -36), Size = UDim2.new(1, 0, 0, 26), TextSize = 16, TextColor3 = C.dim,
			TextXAlignment = Enum.TextXAlignment.Center, Text = if locked then "🔒" else "Palier " .. t })
	end
	if locked then
		make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.55, BackgroundColor3 = K.rgb(0x05080e), ZIndex = 3 }, f)
		text(f, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(40, 40), TextSize = 28, ZIndex = 4,
			TextXAlignment = Enum.TextXAlignment.Center, Text = "🔒" })
	end
end

local function buildActions()
	K.clear(actions)   -- le UIListLayout (créé une fois) reste
	local claimable = 0
	for t = 1, state.tier do
		if not table.find(state.claimedFree or {}, t) then claimable += 1 end
		if state.premium and not table.find(state.claimedPremium or {}, t) then claimable += 1 end
	end
	local row1 = make("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 44) }, actions)
	local l1 = K.hlist(row1, 10); l1.HorizontalAlignment = Enum.HorizontalAlignment.Right
	if not state.premium then
		local it = Catalog.get("pass_premium")
		local live = it ~= nil and (it.productId or 0) > 0
		local rb = K.btn(row1, "⭐  " .. spaced("PREMIUM", 1) .. "  ·  R$ " .. tostring(state.premiumRobux), if live then "gold" else "dark", function()
			local res = call("ShopBuy", "pass_premium")
			if not (res and res.ok) then toast((res and res.err or "Bientôt disponible") .. " — le Premium s'obtient aussi avec des pièces", C.gold) end
		end, { LayoutOrder = 2, Size = UDim2.fromOffset(230, 42), TextSize = 13 })
		if not live then rb.Text = "⭐  PREMIUM · R$ " .. tostring(state.premiumRobux) .. '  <font size="10">bientôt disponible</font>' end
		local enough = (state.coins or 0) >= state.premiumCoins
		K.btn(row1, "⭐  " .. spaced("PREMIUM", 1) .. "  ·  " .. K.fmt(state.premiumCoins) .. " 💰", if enough then "purple" else "dark", function()
			local ok = call("BP_BuyPremium")
			if ok then toast("✔ Passe Premium débloqué ! Tous les paliers Premium atteints sont à récupérer.") else toast("Pas assez de pièces (" .. K.fmt(state.coins or 0) .. " / " .. K.fmt(state.premiumCoins) .. ")", C.accent) end
			state = call("BP_State") or state; render()
			local f = S.panels.menuRefresh; if f then task.spawn(f) end
		end, { LayoutOrder = 1, Size = UDim2.fromOffset(230, 42), TextSize = 13 })
	else
		text(row1, { LayoutOrder = 1, Size = UDim2.fromOffset(300, 42), Font = K.BLACK, TextSize = 15, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Right,
			TextWrapped = false, Text = "⭐ " .. spaced("PREMIUM ACTIF", 1) })
	end
	local row2 = make("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 40) }, actions)
	local l2 = K.hlist(row2, 10); l2.HorizontalAlignment = Enum.HorizontalAlignment.Right
	if claimable > 0 then
		local b = K.btn(row2, "🎁  " .. spaced("TOUT RÉCUPÉRER", 1) .. " (" .. claimable .. ")", "green", function()
			local res = call("BP_ClaimAll")
			if typeof(res) == "table" and #res > 0 then toast("✔ " .. #res .. " récompense(s) récupérée(s) !") else toast("Rien à récupérer pour l'instant", C.dim) end
			state = call("BP_State") or state; render()
			local f = S.panels.menuRefresh; if f then task.spawn(f) end
		end, { Size = UDim2.fromOffset(260, 38), TextSize = 13 })
		K.beat(b, 1.04, 1.1)
	end
	if not state.premium then
		K.para(actions, "Le Premium débloque la rangée dorée : caisse Premium au palier 1, un skin tous les 5 paliers (rare, épique puis légendaire) et plus de pièces.", 11, C.dim, 3).TextXAlignment = Enum.TextXAlignment.Right
	end
end

render = function()
	if not state then return end
	seasonL.Text = string.upper(state.name)
	tierL.Text = "PALIER " .. state.tier .. ' <font size="16" color="#8da0bd">/ ' .. state.max .. "</font>"
	local inTier = if state.tier >= state.max then state.xpPerTier else state.xp % state.xpPerTier
	local fill = xpBar:FindFirstChild("Fill") :: Frame?
	if fill then fill.Size = UDim2.fromScale(math.clamp(inTier / state.xpPerTier, 0, 1), 1) end
	xpL.Text = if state.tier >= state.max then "Passe terminé : bravo !" else K.fmt(inTier) .. " / " .. K.fmt(state.xpPerTier) .. " XP vers le palier " .. (state.tier + 1) .. "  ·  l'XP des parties fait avancer le passe"
	buildActions()
	local cp: any = track.CanvasPosition
	local keepX = if typeof(cp) == "Vector2" then cp.X else 0   -- garde le défilement d'un rendu à l'autre
	K.clear(track)
	for t = 1, state.max do
		local col = make("Frame", { LayoutOrder = t, Size = UDim2.fromOffset(124, 392) }, track)
		local reached = t <= state.tier
		local num = text(col, { Position = UDim2.fromOffset(0, 186), Size = UDim2.new(1, 0, 0, 20), Font = K.BLACK, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = if t == state.tier + 1 then C.gold elseif reached then C.white else C.dim, Text = tostring(t) })
		if t == state.tier + 1 then num.Text = "▶ " .. t end
		cell(col, t, false, 0)
		cell(col, t, true, 210)
	end
	task.defer(function()
		if keepX > 0 then track.CanvasPosition = Vector2.new(keepX, 0)
		else track.CanvasPosition = Vector2.new(math.max(0, (state.tier - 2) * 134), 0) end
	end)
end

local function open()
	fit()
	gui.Enabled = true
	state = call("BP_State")
	if not state then toast("Chargement du passe…", C.dim); task.wait(1); state = call("BP_State") end
	track.CanvasPosition = Vector2.zero
	render()
	-- petite entrée qui rebondit (sur l'échelle d'adaptation à l'écran : un seul UIScale par cadre)
	local target = winScale.Scale
	winScale.Scale = target * 0.9; K.tween(winScale, 0.25, { Scale = target }, Enum.EasingStyle.Back)
end
veil.Activated:Connect(function() gui.Enabled = false end)
-- B / Échap / Retour arrière ferment le passe (avant le menu) ; à la manette, la sélection arrive sur la croix
K.overlay(gui, function() gui.Enabled = false end, function() return closeB end)
local _t = titleL
S.panels.pass = function()
	if gui.Enabled then gui.Enabled = false else open() end
end
MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, _id: number, ok: boolean)
	if userId == player.UserId and ok and gui.Enabled then task.wait(1.2); state = call("BP_State") or state; render() end
end)
