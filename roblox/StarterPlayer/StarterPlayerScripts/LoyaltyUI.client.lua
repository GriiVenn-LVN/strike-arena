--!strict
-- StarterPlayerScripts/LoyaltyUI (LocalScript)
-- Centre des cadeaux (temps de jeu, série, fidélité, bonus), fenêtre Premium (avantages, couleur de pseudo, offres en Robux),
-- notifications « Cadeau débloqué ! » et « Bon retour ! », pseudo Premium en couleur dans le chat.
-- Le serveur (LoyaltyService, ShopService) vérifie tout ; ici on ne fait qu'afficher. Même contenu que la version web (8W_loyalty.js).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local TextChatService = game:GetService("TextChatService")
local MarketplaceService = game:GetService("MarketplaceService")
local L = require(ReplicatedStorage.Shared.LoyaltyConfig)
local Catalog = require(ReplicatedStorage.Shared.ShopCatalog)

local player = Players.LocalPlayer
local loyGet = ReplicatedStorage:WaitForChild("Loy_Get") :: RemoteFunction
local loyClaim = ReplicatedStorage:WaitForChild("Loy_Claim") :: RemoteFunction
local vipSetColor = ReplicatedStorage:WaitForChild("Vip_SetColor") :: RemoteFunction
local shopBuy = ReplicatedStorage:WaitForChild("ShopBuy") :: RemoteFunction

local DARK = Color3.fromRGB(13, 18, 29)
local PANEL = Color3.fromRGB(22, 29, 44)
local PURPLE = Color3.fromRGB(122, 44, 255)
local GOLD = Color3.fromRGB(255, 196, 40)
local MUTED = Color3.fromRGB(70, 80, 100)
local GREEN = Color3.fromRGB(125, 255, 159)

local gui = Instance.new("ScreenGui"); gui.Name = "LoyaltyUI"; gui.ResetOnSpawn = false; gui.Parent = player:WaitForChild("PlayerGui")

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local o: any = Instance.new(className)
	if className == "TextLabel" or className == "TextButton" then
		o.Font = Enum.Font.GothamBold
		o.TextColor3 = Color3.new(1, 1, 1)
		o.RichText = true
	end
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(o: Instance, r: number) make("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
local function stroke(o: Instance, c: Color3, t: number) make("UIStroke", { Color = c, Thickness = t, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o) end
local function gradient(o: Instance, a: Color3, b: Color3) make("UIGradient", { Color = ColorSequence.new(a, b), Rotation = 20 }, o) end

local function rewardText(r: any): string
	local t = {}
	if r.coins then table.insert(t, "+" .. r.coins .. " pièces") end
	if r.box then table.insert(t, (r.n or 1) .. (if r.box == "prem" then " Caisse Premium" else " Caisse Standard")) end
	if r.boost then table.insert(t, "Boost XP ×1,5 (" .. r.boost .. " parties)") end
	if r.title then table.insert(t, "Titre « " .. L.TITLES[r.title] .. " »") end
	return table.concat(t, " • ")
end

-- Petit rebond « tape-à-l'œil » sur un objet
local function pop(o: GuiObject)
	local s = make("UIScale", { Scale = 0.3 }, o)
	TweenService:Create(s, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end
local function wiggle(o: GuiObject)
	task.spawn(function()
		while o.Parent do
			TweenService:Create(o, TweenInfo.new(0.12), { Rotation = -6 }):Play(); task.wait(0.12)
			TweenService:Create(o, TweenInfo.new(0.12), { Rotation = 6 }):Play(); task.wait(0.12)
			TweenService:Create(o, TweenInfo.new(0.12), { Rotation = 0 }):Play(); task.wait(1.6)
		end
	end)
end

-- ---------- boutons (sous le bouton Boutique de ShopUI) ----------
local giftBtn = make("TextButton", { Size = UDim2.fromOffset(150, 40), Position = UDim2.new(1, -170, 0, 68), BackgroundColor3 = PURPLE,
	Text = "🎁 Cadeaux", TextSize = 18, Font = Enum.Font.GothamBlack }, gui)
corner(giftBtn, 8); gradient(giftBtn, Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 160, 255))
local badge = make("TextLabel", { Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -12, 0, -10), BackgroundColor3 = Color3.fromRGB(255, 70, 85),
	Text = "", TextSize = 13, Visible = false }, giftBtn)
corner(badge, 12)
local vipBtn = make("TextButton", { Size = UDim2.fromOffset(150, 40), Position = UDim2.new(1, -170, 0, 116), BackgroundColor3 = GOLD,
	Text = "⭐ Premium", TextSize = 18, Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(42, 26, 0) }, gui)
corner(vipBtn, 8)
local vipGrad = make("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 179, 0)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 246, 201)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 157, 0)) }) }, vipBtn)
TweenService:Create(vipGrad, TweenInfo.new(2.5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Offset = Vector2.new(1, 0) }):Play()

-- ---------- fenêtre générique ----------
local function window(title: string, accent: Color3): (Frame, ScrollingFrame)
	local win = make("Frame", { Size = UDim2.fromOffset(780, 520), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = DARK, Visible = false }, gui)
	corner(win, 12); stroke(win, accent, 2)
	make("TextLabel", { Size = UDim2.new(1, -80, 0, 50), Position = UDim2.fromOffset(20, 8), BackgroundTransparency = 1, Text = title,
		TextSize = 28, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = accent }, win)
	local close = make("TextButton", { Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -55, 0, 12), BackgroundColor3 = PANEL, Text = "✕", TextSize = 20 }, win)
	corner(close, 20)
	close.MouseButton1Click:Connect(function() win.Visible = false end)
	local body = make("ScrollingFrame", { Size = UDim2.new(1, -40, 1, -76), Position = UDim2.fromOffset(20, 64), BackgroundTransparency = 1,
		ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new() }, win)
	make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, body)
	return win, body
end
local function section(body: Instance, order: number, title: string, height: number): Frame
	local f = make("Frame", { Size = UDim2.new(1, -8, 0, height), BackgroundColor3 = PANEL, LayoutOrder = order }, body)
	corner(f, 8)
	make("TextLabel", { Size = UDim2.new(1, -24, 0, 26), Position = UDim2.fromOffset(12, 6), BackgroundTransparency = 1, Text = title,
		TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left }, f)
	return f
end
local function row(parent: Instance, y: number): Frame
	local r = make("Frame", { Size = UDim2.new(1, -24, 0, 104), Position = UDim2.fromOffset(12, y), BackgroundTransparency = 1 }, parent)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }, r)
	return r
end

local giftWin, giftBody = window("🎁 CENTRE DES CADEAUX", Color3.fromRGB(201, 164, 255))
local vipWin, vipBody = window("⭐ STRIKE PREMIUM", GOLD)
local state: any = nil
local renderGifts: () -> ()

local function refreshState()
	state = loyGet:InvokeServer()
	if not state then return end
	badge.Visible = #state.pending > 0
	badge.Text = tostring(#state.pending)
	vipBtn.Text = if state.vip then "⭐ Premium · " .. state.vipDaysLeft .. " j" else "⭐ Premium"
end

local function isPending(kind: string, i: number): boolean
	for _, p in ipairs(state.pending) do if p[1] == kind and p[2] == i then return true end end
	return false
end

-- Carte de cadeau : verrouillé (gris), prêt (doré, il bouge, clic = récupérer), reçu (✔)
local function giftCard(parent: Instance, icon: string, title: string, text: string, kind: string, i: number, done: boolean, progress: number?)
	local ready = isPending(kind, i)
	local f = make("TextButton", { Size = UDim2.fromOffset(112, 104), BackgroundColor3 = if ready then Color3.fromRGB(60, 40, 10) else DARK,
		Text = "", AutoButtonColor = ready }, parent)
	corner(f, 8); stroke(f, if ready then GOLD elseif done then GREEN else MUTED, if ready then 2 else 1)
	local ic = make("TextLabel", { Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 4), BackgroundTransparency = 1, Text = icon, TextSize = 28,
		TextTransparency = if ready or done then 0 else 0.5 }, f)
	make("TextLabel", { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 38), BackgroundTransparency = 1, Text = title, TextSize = 13 }, f)
	make("TextLabel", { Size = UDim2.new(1, -8, 0, 34), Position = UDim2.fromOffset(4, 54), BackgroundTransparency = 1, Text = text, TextSize = 10,
		TextWrapped = true, TextColor3 = Color3.fromRGB(197, 209, 228) }, f)
	local foot = if ready then "RÉCUPÉRER" elseif done then "✔ REÇU" else ""
	if foot ~= "" then
		make("TextLabel", { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -16), BackgroundTransparency = 1, Text = foot, TextSize = 11,
			TextColor3 = if ready then GOLD else GREEN }, f)
	elseif progress then
		local bar = make("Frame", { Size = UDim2.new(1, -16, 0, 4), Position = UDim2.new(0, 8, 1, -10), BackgroundColor3 = MUTED, BorderSizePixel = 0 }, f)
		make("Frame", { Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1), BackgroundColor3 = Color3.fromRGB(255, 122, 26), BorderSizePixel = 0 }, bar)
	end
	if ready then
		wiggle(ic)
		f.MouseButton1Click:Connect(function()
			local r = loyClaim:InvokeServer(kind, i)
			if r then pop(f) end
			refreshState(); renderGifts()
		end)
	end
end

renderGifts = function()
	for _, c in ipairs(giftBody:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
	if not state then return end
	local nextG
	for _, g in ipairs(L.PLAYTIME_GIFTS) do if state.minutes < g.minutes then nextG = g; break end end
	local s1 = section(giftBody, 1, string.format("⏱ CADEAUX DE TEMPS DE JEU · %d min aujourd'hui · %s", state.minutes,
		if nextG then "prochain dans " .. (nextG.minutes - state.minutes) .. " min" else "tous débloqués !"), 146)
	local r1 = row(s1, 36)
	for i, g in ipairs(L.PLAYTIME_GIFTS) do
		giftCard(r1, g.icon, g.minutes .. " MIN", rewardText(g.reward), "pt", i, table.find(state.got, i) ~= nil, state.minutes / g.minutes)
	end
	local s2 = section(giftBody, 2, string.format("🔥 SÉRIE DE CONNEXION · %d jour(s) d'affilée%s", state.streak,
		if state.vip then " · ⭐ un jour manqué par semaine pardonné" else ""), 146)
	local r2 = row(s2, 36)
	for i, g in ipairs(L.STREAK_GOALS) do
		giftCard(r2, g.icon, g.days .. " JOURS", rewardText(g.reward), "st", i, table.find(state.streakGot, g.days) ~= nil, state.streak / g.days)
	end
	local t = L.TIERS[state.tier]
	local s3 = section(giftBody, 3, string.format('💠 RANG DE FIDÉLITÉ : <font color="#%s">%s</font> · %d jour(s) de jeu · +%d %% XP permanent',
		t.color:ToHex(), string.upper(t.name), state.days, t.xp), 146)
	local r3 = row(s3, 36)
	for i, x in ipairs(L.TIERS) do
		if x.reward then
			giftCard(r3, "💠", x.name, x.days .. " j · +" .. x.xp .. " % XP · " .. rewardText(x.reward), "tier", i, table.find(state.tiers, i) ~= nil, state.days / x.days)
		end
	end
	local s4 = section(giftBody, 4, "✨ BONUS ACTIFS", 110)
	local lines = {
		"💠 Fidélité +" .. t.xp .. " % XP",
		"⚡ Boost XP ×1,5 : " .. (if state.boost > 0 then state.boost .. " partie(s)" else "aucun"),
		"🏆 Première victoire du jour : " .. (if state.firstWinAvailable then "+" .. L.FIRST_WIN.xp .. " XP dispo" else "déjà prise"),
		"⭐ Premium : " .. (if state.vip then "+20 % XP et pièces · " .. state.vipDaysLeft .. " j" else "inactif"),
	}
	make("TextLabel", { Size = UDim2.new(1, -24, 0, 70), Position = UDim2.fromOffset(12, 34), BackgroundTransparency = 1, Text = table.concat(lines, "\n"),
		TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, s4)
	if isPending("vip", 0) then
		local b = make("TextButton", { Size = UDim2.fromOffset(250, 34), Position = UDim2.new(1, -262, 0, 40), BackgroundColor3 = GOLD,
			Text = "🎁 Cadeau Premium du jour : +" .. L.VIP.daily.coins, TextSize = 14, TextColor3 = Color3.fromRGB(42, 26, 0) }, s4)
		corner(b, 6); wiggle(b)
		b.MouseButton1Click:Connect(function() loyClaim:InvokeServer("vip", 0); refreshState(); renderGifts() end)
	end
end

local function renderVip()
	for _, c in ipairs(vipBody:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
	if not state then return end
	local perks = {
		{ "🌈", "Couleur de pseudo exclusive", "Ton pseudo brille avec une étoile ⭐ dans le chat et le tableau des scores." },
		{ "⚡", "+20 % d'XP et +20 % de pièces", "À chaque fin de partie, en plus des autres bonus." },
		{ "🎁", "Cadeau Premium chaque jour", "+" .. L.VIP.daily.coins .. " pièces dans le Centre des cadeaux." },
		{ "🛡", "Série protégée", "Un jour manqué par semaine ne remet pas ta série à zéro." },
		{ "📦", "1 Caisse Premium offerte", "À chaque achat, plus le titre « ⭐ Premium »." },
	}
	local p = section(vipBody, 1, if state.vip then "⭐ PREMIUM ACTIF · encore " .. state.vipDaysLeft .. " jour(s)" else "AVANTAGES", 34 + #perks * 34)
	for i, k in ipairs(perks) do
		make("TextLabel", { Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 4 + i * 34), BackgroundTransparency = 1,
			Text = k[1] .. '  <b>' .. k[2] .. '</b>  <font color="#8da0bd">' .. k[3] .. "</font>", TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left }, p)
	end
	local c = section(vipBody, 2, "COULEUR DE TON PSEUDO · aperçu : " .. L.richName(player), 90)
	local cr = make("Frame", { Size = UDim2.new(1, -24, 0, 40), Position = UDim2.fromOffset(12, 40), BackgroundTransparency = 1 }, c)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }, cr)
	for _, col in ipairs(L.VIP.colors) do
		local b = make("TextButton", { Size = UDim2.fromOffset(130, 36), BackgroundColor3 = DARK, Text = "⭐ " .. col.name, TextSize = 14, TextColor3 = col.color }, cr)
		corner(b, 6); stroke(b, if state.vipColor == col.id then GOLD else MUTED, if state.vipColor == col.id then 2 else 1)
		if col.id == "rainbow" then gradient(b, Color3.fromRGB(255, 70, 85), Color3.fromRGB(74, 163, 255)) end
		b.MouseButton1Click:Connect(function()
			if not state.vip then return end
			vipSetColor:InvokeServer(col.id); refreshState(); renderVip()
		end)
	end
	local o = section(vipBody, 3, "OFFRES (jours cumulables)", 100)
	local orow = make("Frame", { Size = UDim2.new(1, -24, 0, 54), Position = UDim2.fromOffset(12, 38), BackgroundTransparency = 1 }, o)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10) }, orow)
	for _, off in ipairs(L.VIP.offers) do
		-- numéro du produit : celui de ProductIds.lua (repris par ShopCatalog), pas la valeur par défaut de LoyaltyConfig
		local it = Catalog.get(off.id)
		local pid = if it then it.productId or 0 else off.productId
		local b = make("TextButton", { Size = UDim2.fromOffset(330, 54), BackgroundColor3 = if pid > 0 then GOLD else MUTED,
			Text = string.format("%s%s · R$ %d", if off.best then "🔥 " else "", off.name, off.robux), TextSize = 17,
			TextColor3 = if pid > 0 then Color3.fromRGB(42, 26, 0) else Color3.new(1, 1, 1) }, orow)
		corner(b, 8)
		if pid > 0 then
			b.MouseButton1Click:Connect(function() shopBuy:InvokeServer(off.id) end)   -- ShopService ouvre la fenêtre de paiement
		else
			b.Text ..= " · bientôt disponible"
		end
	end
end

giftBtn.MouseButton1Click:Connect(function()
	vipWin.Visible = false
	giftWin.Visible = not giftWin.Visible
	if giftWin.Visible then refreshState(); renderGifts(); pop(giftWin) end
end)
vipBtn.MouseButton1Click:Connect(function()
	giftWin.Visible = false
	vipWin.Visible = not vipWin.Visible
	if vipWin.Visible then refreshState(); renderVip(); pop(vipWin) end
end)
MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, _id: number, purchased: boolean)
	if userId == player.UserId and purchased then task.wait(1); refreshState(); if vipWin.Visible then renderVip() end end
end)

-- ---------- notifications ----------
local function banner(icon: string, title: string, text: string)
	local f = make("Frame", { Size = UDim2.fromOffset(460, 76), Position = UDim2.new(0.5, 0, 0, -90), AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(42, 22, 64) }, gui)
	corner(f, 10); stroke(f, GOLD, 2)
	local ic = make("TextLabel", { Size = UDim2.fromOffset(60, 76), BackgroundTransparency = 1, Text = icon, TextSize = 36 }, f)
	make("TextLabel", { Size = UDim2.new(1, -70, 0, 26), Position = UDim2.fromOffset(64, 10), BackgroundTransparency = 1, Text = title, TextSize = 17,
		TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left }, f)
	make("TextLabel", { Size = UDim2.new(1, -70, 0, 34), Position = UDim2.fromOffset(64, 36), BackgroundTransparency = 1, Text = text, TextSize = 12,
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(229, 220, 255) }, f)
	wiggle(ic)
	TweenService:Create(f, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, 80) }):Play()
	task.delay(4.5, function()
		TweenService:Create(f, TweenInfo.new(0.4), { Position = UDim2.new(0.5, 0, 0, -90) }):Play()
		task.wait(0.5); f:Destroy()
	end)
end

player:GetAttributeChangedSignal("LoyaltyGiftReady"):Connect(function()
	local m = player:GetAttribute("LoyaltyGiftReady")
	for _, g in ipairs(L.PLAYTIME_GIFTS) do
		if g.minutes == m then banner(g.icon, "CADEAU DÉBLOQUÉ !", m .. " min de jeu aujourd'hui · " .. rewardText(g.reward) .. " · bouton 🎁 Cadeaux") end
	end
	refreshState()
end)
player:GetAttributeChangedSignal("LoyaltyWelcomeBack"):Connect(function()
	banner("🎉", "BON RETOUR !", "Tu nous as manqué. Cadeau : " .. rewardText(L.BACK_GIFT))
	refreshState()
end)

-- ---------- pseudo Premium en couleur dans le chat ----------
TextChatService.OnIncomingMessage = function(message: TextChatMessage)
	local props = Instance.new("TextChatMessageProperties")
	local src = message.TextSource
	local who = src and Players:GetPlayerByUserId(src.UserId)
	if who and who:GetAttribute("Vip") then props.PrefixText = L.richName(who) .. " :" end
	return props
end

task.spawn(refreshState)
task.spawn(function() while true do task.wait(60); refreshState() end end)   -- le badge suit les minutes jouées

-- ---------- menu principal (MainMenu) : ses boutons CADEAUX et PREMIUM ouvrent ces fenêtres ----------
giftBtn.Visible = false; vipBtn.Visible = false
gui.DisplayOrder = 30   -- au-dessus du menu
local panels = require(ReplicatedStorage.Shared.ClientState).panels
panels.gifts = function()
	vipWin.Visible = false
	giftWin.Visible = not giftWin.Visible
	if giftWin.Visible then refreshState(); renderGifts(); pop(giftWin) end
end
panels.vip = function()
	giftWin.Visible = false
	vipWin.Visible = not vipWin.Visible
	if vipWin.Visible then refreshState(); renderVip(); pop(vipWin) end
end
