--!strict
-- StarterPlayerScripts/ShopUI (LocalScript)
-- BOUTIQUE (façon Fortnite / Arsenal) : onglets en haut, contenu à gauche, aperçu de l'objet choisi à droite.
--  · « À la une » : pack de départ (offre unique, disparaît une fois acheté), offre vedette -40 %, 4 offres du jour -25 %
--    avec le compte à rebours, promo du passe de combat Premium, passe de jeu XP ×2.
--  · « Pièces » : lots de pièces présentés comme dans les grands jeux (bonus en % par rapport au plus petit lot,
--    étiquettes POPULAIRE / MEILLEURE VALEUR), puis caisses Premium.
--  · Aperçu : cliquer une carte montre l'arme en 3D (avec le skin ou le camo animé) avant d'acheter.
-- Un produit Robux dont le numéro vaut 0 dans ProductIds affiche « Bientôt disponible » et ne s'achète pas.
-- Le serveur (ShopService) vérifie chaque achat ; ici on ne fait qu'afficher.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.ShopCatalog)
local ItemPreview = require(ReplicatedStorage.Shared.ItemPreview)
local S = require(ReplicatedStorage.Shared.ClientState)
local K = require(script.Parent:WaitForChild("Menu"):WaitForChild("Kit"))
local C = K.C
local make, text, spaced = K.make, K.text, K.spaced

local player = Players.LocalPlayer
local getShop = ReplicatedStorage:WaitForChild("GetShop") :: RemoteFunction
local shopBuy = ReplicatedStorage:WaitForChild("ShopBuy") :: RemoteFunction
local shopEquip = ReplicatedStorage:WaitForChild("ShopEquip") :: RemoteFunction
local equipSkin = ReplicatedStorage:WaitForChild("EquipSkin") :: RemoteFunction

local SOON = "Bientôt disponible"
local W, H = 1060, 620

-- ---------- Fenêtre ----------
local gui = make("ScreenGui", { Name = "ShopUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 30, Enabled = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
local veil = make("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = K.rgb(0x05080e), BackgroundTransparency = 0.35, Text = "",
	AutoButtonColor = false, Modal = true, Visible = false }, gui)
local win = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H),
	BackgroundTransparency = 0, BackgroundColor3 = C.white, Visible = false }, gui)
K.corner(win, 16); K.gradient(win, K.rgb(0x141c2c), K.rgb(0x0b111c), 90); K.stroke(win, C.white, 1, 0.85)
local winScale = make("UIScale", { Scale = 1 }, win)
local function fit()
	local cam = workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1600, 900)
	winScale.Scale = math.clamp(math.min((vp.X - 24) / W, (vp.Y - 24) / H), 0.45, 1.2)
end

text(win, { Position = UDim2.fromOffset(26, 16), Size = UDim2.fromOffset(400, 32), Font = K.BLACK, TextSize = 28, TextWrapped = false,
	Text = "🛒  " .. spaced("BOUTIQUE", 3) })
local coinsLabel = text(win, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -72, 0, 20), Size = UDim2.fromOffset(260, 26), Font = K.BLACK,
	TextSize = 20, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false, Text = "🪙 …" })
local function close() win.Visible = false; veil.Visible = false end
K.btn(win, "✕", "dark", close, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 14), Size = UDim2.fromOffset(42, 42), TextSize = 18 })
veil.Activated:Connect(close)

local tabBar = make("Frame", { Position = UDim2.fromOffset(24, 62), Size = UDim2.new(1, -48, 0, 36) }, win)
K.hlist(tabBar, 6)
local toast = text(win, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 26, 1, -10), Size = UDim2.new(1, -360, 0, 20), TextSize = 14,
	Font = K.BOLD, TextColor3 = C.gold, TextWrapped = false, Text = "" })

-- contenu (gauche) et aperçu (droite)
local body = K.scroll(win, { Position = UDim2.fromOffset(24, 110), Size = UDim2.new(1, -350, 1, -150) })
K.pad(body, 2, 2, 10, 10); K.vlist(body, 10)
local side = make("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, 110), Size = UDim2.new(0, 300, 1, -134),
	BackgroundTransparency = 0, BackgroundColor3 = C.white }, win)
K.corner(side, 14); K.gradient(side, K.rgb(0x1a2438), K.rgb(0x0b111c), 90, 0.1, 0.15); K.stroke(side, C.white, 1, 0.88)

-- ---------- État ----------
local state: any = nil
local fetchedAt = 0
local currentTab = "featured"
local selected: any = nil
local gunKeys = {}
for _, k in ipairs(Catalog.WEAPON_KEYS) do if not Config.WEAPONS[k].melee then table.insert(gunKeys, k) end end
local weaponIndex = table.find(gunKeys, "ak") or 1
local countdowns: { TextLabel } = {}

local render: () -> ()
local renderSide: () -> ()

local function refresh()
	local ok, res = pcall(getShop.InvokeServer, getShop)
	if ok and res then state = res; fetchedAt = os.clock() end
	if state then coinsLabel.Text = "🪙 " .. K.fmt(state.coins) end
	render()
end

local function say(msg: string, color: Color3?)
	toast.Text = msg; toast.TextColor3 = color or C.gold
	task.delay(3.5, function() if toast.Text == msg then toast.Text = "" end end)
end

local function leftText(): string
	if not state then return "" end
	local s = math.max(0, (state.secondsToReset or 0) - math.floor(os.clock() - fetchedAt))
	return string.format("%d h %02d min %02d s", s // 3600, s % 3600 // 60, s % 60)
end

local function iconFor(it: any): string
	local k = it.kind
	if k == "weapon" then return "🔫" elseif k == "skin" then return "🎨" elseif k == "sight" then return "🔭" elseif k == "reticle" then return "➕"
	elseif k == "outfit" then return "🪖" elseif k == "trail" then return "✨" elseif k == "killfx" then return "💥" elseif k == "vip" then return "👑"
	elseif k == "exclusive" then return "🌈" elseif k == "gamepass" then return "⚡" elseif it.once then return "🎁"
	elseif k == "devproduct" then return if it.premium then "⭐" elseif it.box then "📦" else "🪙" end
	return "🏷"
end

local function offerOf(id: string): any
	if not state then return nil end
	for _, o in ipairs(state.offers) do if o.id == id then return o end end
	return nil
end

-- achat Robux : Roblox affiche sa propre fenêtre de paiement, le serveur crédite dans ProcessReceipt
local function robuxBuy(it: any)
	local ok, res = pcall(shopBuy.InvokeServer, shopBuy, it.id)
	if ok and res and res.err then say(res.err, C.accent2) end
end

-- Libellé, style et action du bouton d'un objet
local function actionFor(it: any): (string, string, (() -> ())?)
	local owned = state and state.owned[it.id]
	if it.kind == "gamepass" then
		if state and state.passes and state.passes[it.id] then return "Possédé ✔", "dark", nil end
		if (it.passId or 0) <= 0 then return SOON, "dark", nil end
		return "R$ " .. it.robux, "green", function() robuxBuy(it) end
	end
	if it.once and owned then return "Déjà acheté ✔", "dark", nil end
	if it.kind == "devproduct" or it.kind == "vip" then   -- vip = abonnement Premium, se rachète pour ajouter des jours
		if (it.productId or 0) <= 0 then return SOON, "dark", nil end
		return "R$ " .. it.robux, "green", function() robuxBuy(it) end
	end
	if it.kind == "exclusive" and not owned then                 -- exclusif : Robux uniquement
		if (it.productId or 0) <= 0 then return SOON, "dark", nil end
		return "R$ " .. it.robux, "green", function() robuxBuy(it) end
	end
	if it.kind == "killfx" and not owned and it.source ~= "coins" then   -- effet d'élimination exclusif, de code ou de groupe
		if it.source == "code" then return "Code 🔑", "dark", nil end
		if it.source == "group" then return "Groupe 👥", "dark", nil end
		if it.source == "event" then return "Événement 🎃", "dark", nil end
		if (it.productId or 0) <= 0 then return SOON, "dark", nil end
		return "R$ " .. it.robux, "green", function() robuxBuy(it) end
	end
	if not owned then
		if it.event then return "Événement 🎃", "dark", nil end
		local o = offerOf(it.id)
		local price = if o then o.price else it.price
		return "🪙 " .. K.fmt(price), if state and state.coins >= price then "primary" else "alt", function()
			local ok, res = pcall(shopBuy.InvokeServer, shopBuy, it.id)
			if ok and res and res.ok then say("Acheté : " .. it.name .. " !", C.green); pcall(function() K.uiSound(false) end)
			else say("Achat impossible : " .. (if ok and res and res.err then res.err else "erreur"), C.accent2) end
			refresh()
		end
	end
	local eq = state.equipped
	local weapon = gunKeys[weaponIndex]
	local isEquipped = (it.kind == "outfit" and eq.outfit == it.outfit) or (it.kind == "reticle" and eq.reticle == it.reticle)
		or (it.kind == "trail" and eq.trail == it.trail) or (it.kind == "sight" and (eq.sights or {})[weapon] == it.sight)
		or (it.kind == "skin" and state.equippedSkins[it.weapon] == it.skin)
		or (it.kind == "exclusive" and it.camo ~= nil and (eq.animCamo or {})[weapon] == it.camo)
		or (it.kind == "killfx" and (eq.killFx or "none") == it.fx)
	if isEquipped then return "Équipé ✔", "dark", nil end
	if it.kind == "weapon" or it.kind == "misc" or (it.kind == "exclusive" and not it.camo) then return "Possédé ✔", "dark", nil end
	return "Équiper", "blue", function()
		local ok, res
		if it.kind == "skin" then ok, res = pcall(equipSkin.InvokeServer, equipSkin, it.weapon, it.skin)
		else ok, res = pcall(shopEquip.InvokeServer, shopEquip, it.id, weapon) end
		if not (ok and res) then say("Impossible d'équiper cet objet", C.accent2) end
		refresh()
	end
end

local function select(it: any)
	selected = it
	renderSide()
end

-- étiquette de coin (-25 %, POPULAIRE…)
local function tag(parent: Instance, str: string, color: Color3, dark: boolean?)
	local t = text(parent, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X,
		Font = K.BLACK, TextSize = 11, TextWrapped = false, BackgroundTransparency = 0, BackgroundColor3 = color, Text = " " .. str .. " ",
		TextColor3 = if dark then C.ink else C.white, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3 })
	K.corner(t, 6); K.pad(t, 6, 0, 6, 0)
	return t
end

-- carte d'objet de la grille : bande de rareté, icône, nom, prix barré pour les offres, bouton
local function card(it: any, parent: Instance, order: number, size: UDim2?): Frame
	local rc = K.rarityColor(it.rarity or 1)
	local f = make("TextButton", { LayoutOrder = order, Size = size or UDim2.fromOffset(0, 0), BackgroundTransparency = 0, BackgroundColor3 = C.white,
		Text = "", AutoButtonColor = false, Selectable = true }, parent)
	K.corner(f, 12); K.gradient(f, rc:Lerp(K.rgb(0x0b111c), 0.72), K.rgb(0x0b111c), 90)
	K.stroke(f, if selected == it then C.white else rc, if selected == it then 2 else 1, if selected == it then 0.1 else 0.55)
	f.Activated:Connect(function() select(it) end)
	K.juice(f :: any, 0.03)   -- survol / manette : la carte grossit un peu, son d'interface (comme les cartes du menu)
	make("Frame", { Size = UDim2.new(1, 0, 0, 4), BackgroundTransparency = 0, BackgroundColor3 = rc }, f)
	text(f, { Position = UDim2.fromOffset(10, 12), Size = UDim2.new(1, -20, 0, 40), TextSize = 34, TextXAlignment = Enum.TextXAlignment.Left, Text = iconFor(it) })
	text(f, { Position = UDim2.fromOffset(12, 56), Size = UDim2.new(1, -24, 0, 34), Font = K.BOLD, TextSize = 13, TextYAlignment = Enum.TextYAlignment.Top,
		TextTruncate = Enum.TextTruncate.AtEnd, Text = it.name })
	local o = offerOf(it.id)
	if o and not (state and state.owned[it.id]) then
		tag(f, "-" .. o.off .. " %", if o.featured then C.gold else C.accent, o.featured)
		text(f, { Position = UDim2.fromOffset(12, 88), Size = UDim2.new(1, -24, 0, 14), TextSize = 11, TextColor3 = C.mute, TextWrapped = false,
			Text = "au lieu de " .. K.fmt(o.was) .. " 🪙" })
	end
	local label, kind, cb = actionFor(it)
	K.btn(f, label, kind, cb or function() select(it) end, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -20, 0, 32),
		TextSize = if #label > 14 then 11 else 13, AutoButtonColor = cb ~= nil })
	return f :: any
end

local function section(title: string, small: string?, order: number, color: Color3?): Frame
	local row = K.h4(body, title, small, order, color)
	row.Size = UDim2.new(1, 0, 0, 24)
	return row
end
local function gridBox(order: number, cell: UDim2): Frame
	local g = make("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, body)
	K.grid(g, cell, 10)
	return g
end

-- ---------- Onglet « À la une » ----------
local function renderFeatured()
	local n = 0
	local function nx(): number n += 1; return n end
	-- pack de départ (une seule fois par compte)
	local st = Catalog.get(Catalog.STARTER.id)
	if st and not state.owned[st.id] then
		local b = make("TextButton", { LayoutOrder = nx(), Size = UDim2.new(1, 0, 0, 150), BackgroundTransparency = 0, BackgroundColor3 = C.white,
			Text = "", AutoButtonColor = false }, body)
		K.corner(b, 14); K.gradient(b, K.rgb(0x5a3a08), K.rgb(0x1a1206), 0); K.stroke(b, C.gold, 2, 0.2)
		b.Activated:Connect(function() select(st) end)
		K.juice(b :: any, 0.015)
		text(b, { Position = UDim2.fromOffset(20, 14), Size = UDim2.fromOffset(120, 120), TextSize = 86, TextXAlignment = Enum.TextXAlignment.Center, Text = "🎁" })
		text(b, { Position = UDim2.fromOffset(150, 16), Size = UDim2.new(1, -360, 0, 26), Font = K.BLACK, TextSize = 22, TextColor3 = C.gold, TextWrapped = false,
			Text = spaced("PACK DE DÉPART", 2) })
		text(b, { Position = UDim2.fromOffset(150, 44), Size = UDim2.new(1, -360, 0, 16), TextSize = 12, TextColor3 = C.sub, TextWrapped = false,
			Text = "Offre unique : une seule fois par compte !" })
		for i, l in ipairs(Catalog.STARTER.lines) do
			text(b, { Position = UDim2.fromOffset(150 + ((i - 1) % 2) * 190, 70 + (i - 1) // 2 * 24), Size = UDim2.fromOffset(186, 20), Font = K.BOLD, TextSize = 13,
				TextWrapped = false, Text = "✔ " .. l })
		end
		tag(b, "VALEUR ×4", C.accent)
		local label, kind, cb = actionFor(st)
		local btn = K.btn(b, label, if kind == "green" then "gold" else kind, cb, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -18),
			Size = UDim2.fromOffset(190, 46), TextSize = if #label > 14 then 13 else 18 })
		if cb then K.beat(btn, 1.05, 1.2) end
		K.shine(b, 3, 0.25)
	end
	-- offres du jour : vedette (-40 %) + 4 offres (-25 %)
	local cd = section("🔥 OFFRES DU JOUR", "nouvelles offres dans " .. leftText(), nx(), C.gold)
	for _, c in ipairs(cd:GetChildren()) do
		if c:IsA("TextLabel") and string.sub(c.Text, 1, 9) == "nouvelles" then table.insert(countdowns, c) end
	end
	local row = make("Frame", { LayoutOrder = nx(), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, body)
	K.hlist(row, 10, Enum.VerticalAlignment.Top, true)
	local feat, daily = nil, {}
	for _, o in ipairs(state.offers) do
		local it = Catalog.get(o.id)
		if it then if o.featured then feat = it else table.insert(daily, it) end end
	end
	if feat then
		local f = card(feat, row, 0, UDim2.fromOffset(200, 290))
		K.stroke(f, C.gold, 2, 0.1)
		text(f, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -50), Size = UDim2.new(1, -24, 0, 14), Font = K.BLACK, TextSize = 11, TextColor3 = C.gold,
			TextWrapped = false, Text = "★ " .. spaced("OFFRE VEDETTE", 1) })
		if feat.weapon and (feat.kind == "weapon" or feat.kind == "skin") then
			local holder = make("Frame", { Position = UDim2.fromOffset(6, 104), Size = UDim2.new(1, -12, 0, 116) }, f)
			ItemPreview.weapon(holder, feat.weapon, if feat.kind == "skin" then feat.skin else nil, nil, nil, true)
		end
		K.shine(f, 2.6, 0.25)
	end
	local grid = make("Frame", { LayoutOrder = 1, Size = UDim2.new(1, -210, 0, 290) }, row)
	K.grid(grid, UDim2.new(0.5, -5, 0, 140), 10)
	for i, it in ipairs(daily) do card(it, grid, i) end
	-- passe de combat Premium et passe de jeu XP ×2
	section("⭐ ACCÉLÈRE TA PROGRESSION", nil, nx())
	local promo = make("Frame", { LayoutOrder = nx(), Size = UDim2.new(1, 0, 0, 120) }, body)
	K.hlist(promo, 10)
	local pass = make("TextButton", { Size = UDim2.new(0.5, -5, 1, 0), BackgroundTransparency = 0, BackgroundColor3 = C.white, Text = "", AutoButtonColor = false }, promo)
	K.corner(pass, 14); K.gradient(pass, K.rgb(0x4a2a8a), K.rgb(0x0b111c), 0); K.stroke(pass, C.violet, 1.5, 0.3)
	text(pass, { Position = UDim2.fromOffset(16, 14), Size = UDim2.new(1, -32, 0, 22), Font = K.BLACK, TextSize = 16, TextWrapped = false, Text = "🎖 " .. spaced("PASSE DE COMBAT PREMIUM", 1) })
	text(pass, { Position = UDim2.fromOffset(16, 40), Size = UDim2.new(1, -32, 0, 34), TextSize = 12, TextColor3 = C.sub,
		Text = "Débloque la ligne Premium : skins, caisses et pièces à chaque palier." })
	K.btn(pass, "VOIR LE PASSE", "purple", function() local f = S.panels.pass; if f then close(); f() end end,
		{ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -12), Size = UDim2.fromOffset(150, 32), TextSize = 12 })
	pass.Activated:Connect(function() local it = Catalog.get("pass_premium"); if it then select(it) end end)
	K.juice(pass :: any, 0.02)
	for _, g in ipairs(Catalog.GAMEPASSES) do
		local it = Catalog.get(g.id)
		if it then
			local gp = make("TextButton", { Size = UDim2.new(0.5, -5, 1, 0), BackgroundTransparency = 0, BackgroundColor3 = C.white, Text = "", AutoButtonColor = false }, promo)
			K.corner(gp, 14); K.gradient(gp, K.rgb(0x0a4a5a), K.rgb(0x0b111c), 0); K.stroke(gp, C.blue, 1.5, 0.3)
			gp.Activated:Connect(function() select(it) end)
			K.juice(gp :: any, 0.02)
			text(gp, { Position = UDim2.fromOffset(16, 14), Size = UDim2.new(1, -32, 0, 22), Font = K.BLACK, TextSize = 16, TextWrapped = false, Text = "⚡ " .. spaced(K.upper(it.name), 1) })
			text(gp, { Position = UDim2.fromOffset(16, 40), Size = UDim2.new(1, -32, 0, 34), TextSize = 12, TextColor3 = C.sub, Text = it.desc })
			local label, kind, cb = actionFor(it)
			K.btn(gp, label, kind, cb, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -12), Size = UDim2.fromOffset(170, 32), TextSize = 12 })
		end
	end
end

-- ---------- Onglet « Pièces » ----------
local function renderCoins()
	local base = Catalog.get("coins_s")
	local rate = if base and base.robux > 0 then base.coins / base.robux else 0
	section("🪙 LOTS DE PIÈCES", "Les pièces achètent armes, skins, viseurs et tenues", 1, C.gold)
	local g = gridBox(2, UDim2.new(0.25, -8, 0, 230))
	local n = 0
	for _, it in ipairs(Catalog.ITEMS) do
		if it.tab == "robux" and it.coins then
			n += 1
			local tagName = Catalog.BUNDLE_TAGS[it.id]
			local f = make("TextButton", { LayoutOrder = n, BackgroundTransparency = 0, BackgroundColor3 = C.white, Text = "", AutoButtonColor = false }, g)
			K.corner(f, 14)
			K.gradient(f, if tagName then K.rgb(0x4a3108) else K.rgb(0x1a2438), K.rgb(0x0b111c), 90)
			K.stroke(f, if tagName then C.gold elseif selected == it then C.white else C.white, if tagName then 2 else 1, if tagName then 0.15 else 0.85)
			f.Activated:Connect(function() select(it) end)
			K.juice(f :: any, 0.03)
			-- plus le lot est gros, plus la pile de pièces est haute
			text(f, { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 70), TextSize = 30 + n * 8, TextXAlignment = Enum.TextXAlignment.Center,
				Text = string.rep("🪙", math.min(n, 3)) })
			text(f, { Position = UDim2.fromOffset(0, 104), Size = UDim2.new(1, 0, 0, 30), Font = K.BLACK, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center,
				TextWrapped = false, Text = K.fmt(it.coins) })
			text(f, { Position = UDim2.fromOffset(0, 134), Size = UDim2.new(1, 0, 0, 16), Font = K.BOLD, TextSize = 12, TextColor3 = C.sub,
				TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, Text = "pièces" })
			local bonus = if rate > 0 then math.floor((it.coins / it.robux / rate - 1) * 100 + 0.5) else 0
			if bonus > 0 then
				text(f, { Position = UDim2.fromOffset(0, 154), Size = UDim2.new(1, 0, 0, 16), Font = K.BLACK, TextSize = 13, TextColor3 = C.green,
					TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, Text = "+" .. bonus .. " % de pièces en plus" })
			end
			if tagName then
				local t = tag(f, tagName, C.gold, true)
				t.AnchorPoint = Vector2.new(0.5, 0); t.Position = UDim2.new(0.5, 0, 0, -2)
				K.shine(f, 3, 0.2)
			end
			local label, kind, cb = actionFor(it)
			K.btn(f, label, kind, cb, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(1, -24, 0, 36),
				TextSize = if #label > 14 then 11 else 15 })
		end
	end
	section("📦 CAISSES ET AUTRES", nil, 3)
	local g2 = gridBox(4, UDim2.fromOffset(170, 150))
	n = 0
	for _, it in ipairs(Catalog.ITEMS) do
		if it.tab == "robux" and not it.coins then n += 1; card(it, g2, n) end
	end
end

-- ---------- Autres onglets : grille d'objets ----------
local function renderGrid()
	local n = 0
	if currentTab == "skins" or currentTab == "sights" or currentTab == "exclusive" then
		local bar = make("Frame", { LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 36) }, body)
		K.hlist(bar, 8, Enum.VerticalAlignment.Center)
		K.btn(bar, "◀", "alt", function() weaponIndex = (weaponIndex - 2) % #gunKeys + 1; render() end, { Size = UDim2.fromOffset(36, 36), LayoutOrder = 1 })
		text(bar, { LayoutOrder = 2, Size = UDim2.fromOffset(240, 36), Font = K.BLACK, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false,
			Text = Config.WEAPONS[gunKeys[weaponIndex]].name })
		K.btn(bar, "▶", "alt", function() weaponIndex = weaponIndex % #gunKeys + 1; render() end, { Size = UDim2.fromOffset(36, 36), LayoutOrder = 3 })
		text(bar, { LayoutOrder = 4, Size = UDim2.fromOffset(260, 36), TextSize = 12, TextColor3 = C.dim, TextWrapped = false,
			Text = if currentTab == "exclusive" then "Arme utilisée pour l'aperçu et l'équipement" else "Arme choisie" })
	end
	local g = gridBox(1, UDim2.fromOffset(170, 150))
	local weapon = gunKeys[weaponIndex]
	for _, it in ipairs(Catalog.ITEMS) do
		if it.tab == currentTab and (it.kind ~= "skin" or it.weapon == weapon) then
			n += 1
			card(it, g, n)
		end
	end
end

-- ---------- Aperçu (droite) ----------
renderSide = function()
	K.clear(side)
	local it = selected
	if not it or not state then
		text(side, { Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -40, 1, 0), TextSize = 14, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Center,
			Text = "Touche un objet pour le voir en détail avant de l'acheter." })
		return
	end
	local rc = K.rarityColor(it.rarity or 1)
	local stage = make("Frame", { Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -24, 0, 210), BackgroundTransparency = 0, BackgroundColor3 = C.white }, side)
	K.corner(stage, 12); K.gradient(stage, rc:Lerp(K.rgb(0x0b111c), 0.55), K.rgb(0x0b111c), 90)
	local key: string? = nil
	local skin: number? = nil
	local camo: string? = nil
	if it.kind == "weapon" and not Config.WEAPONS[it.weapon].melee then key = it.weapon
	elseif it.kind == "weapon" then key = it.weapon
	elseif it.kind == "skin" then key = it.weapon; skin = it.skin
	elseif it.kind == "exclusive" then key = gunKeys[weaponIndex]; camo = it.camo or (it.camos and it.camos[1]) end
	if key then
		ItemPreview.weapon(stage, key, skin, camo, nil, true)
	else
		text(stage, { Size = UDim2.fromScale(1, 1), TextSize = 96, TextXAlignment = Enum.TextXAlignment.Center, Text = iconFor(it) })
	end
	local rar = Config.RARITY[it.rarity or 1]
	text(side, { Position = UDim2.fromOffset(16, 232), Size = UDim2.new(1, -32, 0, 16), Font = K.BLACK, TextSize = 11, TextColor3 = rc, TextWrapped = false,
		Text = spaced(K.upper(if rar and rar.name then rar.name else (if (it.rarity or 1) >= 5 then "Exclusif" else "")), 1) })
	text(side, { Position = UDim2.fromOffset(16, 250), Size = UDim2.new(1, -32, 0, 46), Font = K.BLACK, TextSize = 18, TextYAlignment = Enum.TextYAlignment.Top,
		Text = it.name })
	-- détails selon le type
	local lines = {}
	if it.once then for _, l in ipairs(Catalog.STARTER.lines) do table.insert(lines, "✔ " .. l) end; table.insert(lines, "Une seule fois par compte") end
	if it.desc then table.insert(lines, it.desc) end
	if it.coins and not it.once then table.insert(lines, K.fmt(it.coins) .. " pièces créditées tout de suite") end
	if it.boxes and not it.once then table.insert(lines, it.boxes .. " caisse" .. (if it.boxes > 1 then "s" else "") .. " Premium à ouvrir dans Cadeaux") end
	if it.premium then table.insert(lines, "Débloque toute la ligne Premium du passe de combat de la saison") end
	if it.days then table.insert(lines, it.days .. " jours de Premium : +20 % XP et pièces, pseudo en couleur, cadeau quotidien") end
	if it.kind == "exclusive" then table.insert(lines, "Camo animé sur toutes tes armes · s'obtient seulement ici") end
	if it.kind == "weapon" then table.insert(lines, "Débloquée pour toujours dans l'Arsenal") end
	if it.kind == "skin" then table.insert(lines, "Skin pour " .. Config.WEAPONS[it.weapon].name) end
	local o = offerOf(it.id)
	if o and not state.owned[it.id] then table.insert(lines, "Offre du jour : -" .. o.off .. " % (" .. K.fmt(o.was) .. " → " .. K.fmt(o.price) .. " 🪙)") end
	local info = make("Frame", { Position = UDim2.fromOffset(16, 300), Size = UDim2.new(1, -32, 1, -360) }, side)
	K.vlist(info, 4)
	for i, l in ipairs(lines) do K.para(info, l, 12, C.sub, i) end
	local label, kind, cb = actionFor(it)
	local b = K.btn(side, label, kind, cb, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(1, -24, 0, 44),
		TextSize = if #label > 14 then 13 else 17, AutoButtonColor = cb ~= nil })
	if cb and kind ~= "blue" then K.beat(b, 1.04, 1.2) end
end

-- ---------- Rendu ----------
local tabButtons: { [string]: TextButton } = {}
render = function()
	K.clear(body)   -- garde le UIListLayout et le UIPadding (K.clear n'enlève que les GuiObject)
	table.clear(countdowns)
	for id, b in pairs(tabButtons) do K.setKind(b, if id == currentTab then "primary" else "alt") end
	if not state then
		K.para(body, "Chargement de la boutique…", 14, C.dim, 1)
		renderSide()
		return
	end
	if currentTab == "featured" then renderFeatured()
	elseif currentTab == "robux" then renderCoins()
	else renderGrid() end
	renderSide()
end

for i, tab in ipairs(Catalog.TABS) do
	local b = K.btn(tabBar, tab.name, "alt", function()
		currentTab = tab.id; selected = nil; body.CanvasPosition = Vector2.zero; render()
	end, { LayoutOrder = i, Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X, TextSize = 12 })
	K.pad(b, 12, 0, 12, 0)
	tabButtons[tab.id] = b
end

-- compte à rebours des offres du jour (rafraîchit la boutique au changement de jour)
task.spawn(function()
	while true do
		task.wait(1)
		if win.Visible and state then
			local t = leftText()
			for _, l in ipairs(countdowns) do if l.Parent then l.Text = "nouvelles offres dans " .. t end end
			if (state.secondsToReset or 0) - (os.clock() - fetchedAt) <= 0 then refresh() end
		end
	end
end)

-- Après un achat Robux, Roblox crédite côté serveur : on rafraîchit quand la fenêtre de paiement se ferme
MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, _productId: number, purchased: boolean)
	if userId == player.UserId and purchased and win.Visible then task.wait(1); refresh() end
end)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(p: Player, _passId: number, purchased: boolean)
	if p == player and purchased and win.Visible then task.wait(1); refresh() end
end)

-- B / Échap / Retour arrière ferment la boutique (avant le menu) ; à la manette, la sélection arrive sur l'onglet en cours
K.overlay(win, close, function() return tabButtons[currentTab] end)

-- ---------- menu principal (MainMenu) : bouton « BOUTIQUE » du menu ----------
S.panels.shop = function()
	if win.Visible then close(); return end
	fit()
	win.Visible = true; veil.Visible = true
	render()
	-- petite entrée qui rebondit (sur l'échelle d'adaptation à l'écran : un seul UIScale par cadre)
	local target = winScale.Scale
	winScale.Scale = target * 0.92; K.tween(winScale, 0.25, { Scale = target }, Enum.EasingStyle.Back)
	task.spawn(refresh)
end
