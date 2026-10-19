--!strict
-- StarterPlayerScripts/MainMenu (LocalScript)
-- Menu principal du jeu web (index.html #menu, src/87_nav.js, src/87d_lobby.js) : plein écran par-dessus le lobby,
-- logo STRIKE ARENA, navigation Accueil / Jouer / Arsenal / Profil / Réglages, encart du profil (niveau, XP, pièces,
-- caisses, BONUS DU JOUR), boutons BOUTIQUE, CADEAUX et PREMIUM. Chaque rubrique est un module de Menu/ (Home, Play, Arsenal, Profile, Settings).
-- Sous les onglets : une ligne « RUBRIQUE › SOUS-PARTIE · phrase d'aide » (TABS), pour savoir tout de suite où l'on est.
-- Organisation (une action principale par écran) :
--   ACCUEIL   JOUER (partie en ligne), partie rapide, avec des amis · saison, bonus du jour · défis · nouveautés, codes, communauté
--   JOUER     EN LIGNE / AVEC DES AMIS · 1 Mode · 2 Carte · 3 Jouer (parties en cours, réglages si une partie est créée)
--   ARSENAL   Armes · Viseurs · Tenues et effets (tenues, danses, sprays, effets d'élimination, traînées) · Caisses
--   PROFIL    Progression (rang, événement, saison) · Statistiques · Pseudo et titre
--   RÉGLAGES  Général · Point de visée · Son · Touches · Accessibilité (les mêmes que dans la pause)
-- S'ouvre à l'arrivée au lobby et au retour d'une partie ; se rouvre avec le bouton en haut à gauche, la touche P ou la croix
-- bas de la manette. En partie, P ouvre la pause (PauseMenu : Reprendre, Options, Menu principal, Quitter la partie),
-- d'où l'on rejoint ce menu, avec « Reprendre » et « Quitter la partie ». Le serveur vérifie tout (MatchService, PartyService, MenuService…).
-- Effets du web (src/8A_juice.js, src/87d_lobby.js) : fond animé avec deux lueurs, onglets qui glissent en fondu,
-- cartes qui apparaissent en cascade, menu qui s'ouvre en zoomant, pastille qui bat ; survol et clic des boutons dans Menu/Kit.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

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

-- ---------- serveur ----------
local function rf(name: string): RemoteFunction?
	local r = ReplicatedStorage:FindFirstChild(name)
	return if r and r:IsA("RemoteFunction") then r else nil
end
-- appel protégé : nil si le remote n'existe pas ou si le serveur plante
local function call(name: string, ...: any): ...any
	local r = rf(name) or (ReplicatedStorage:WaitForChild(name, 5) :: RemoteFunction?)
	if not r or not r:IsA("RemoteFunction") then return nil end
	local res = table.pack(pcall(r.InvokeServer, r, ...))
	if not res[1] then warn("[MainMenu]", name, res[2]); return nil end
	return table.unpack(res, 2, res.n)
end

-- ---------- interface ----------
local bgGui = make("ScreenGui", { Name = "MainMenuBg", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 18, Enabled = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, playerGui)
-- voile du web : sombre à gauche (là où sont les panneaux), le lobby reste visible derrière
local veil = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1) }, bgGui)
make("UIGradient", { Color = ColorSequence.new(K.rgb(0x05080e), K.rgb(0x0b1220)), Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(0.55, 0.38), NumberSequenceKeypoint.new(1, 0.55) }), Rotation = 0 }, veil)
local veil2 = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1) }, bgGui)
make("UIGradient", { Color = ColorSequence.new(K.rgb(0x05080e), K.rgb(0x2a1608)), Transparency = NumberSequence.new(0.35, 0.75), Rotation = -90 }, veil2)
-- fond animé du web (#menu::before) : une lueur rouge en bas à gauche, une bleue en haut à droite, qui dérivent lentement
-- (14 s, aller-retour). Une lueur = cercles concentriques très transparents : plus dense au centre, fondue sur les bords.
local glows: { { Frame } } = {}
local function glow(pos: UDim2, size: number, color: Color3, drift: UDim2): { Frame }
	local holder = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromScale(size, size), SizeConstraint = Enum.SizeConstraint.RelativeXX }, bgGui)
	local rings = {}
	for i = 1, 7 do
		local f = i / 7
		local r = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(f, f),
			BackgroundTransparency = 0.972, BackgroundColor3 = color }, holder)
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, r)
		table.insert(rings, r)
	end
	TweenService:Create(holder, TweenInfo.new(14, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = pos + drift, Size = UDim2.fromScale(size * 1.08, size * 1.08) }):Play()
	table.insert(glows, rings)
	return rings
end
glow(UDim2.fromScale(0.15, 1.05), 0.75, C.accent, UDim2.fromScale(0.03, -0.04))
glow(UDim2.fromScale(0.9, -0.08), 0.6, C.blue, UDim2.fromScale(-0.03, 0.03))
-- Halloween (#menu.theme-hw::before) : orange et violet
local function glowTheme(hw: boolean)
	local cols = if hw then { C.orange, K.rgb(0x8a3dff) } else { C.accent, C.blue }
	for i, rings in ipairs(glows) do for _, r in ipairs(rings) do r.BackgroundColor3 = cols[i] end end
end

local gui = make("ScreenGui", { Name = "MainMenu", ResetOnSpawn = false, DisplayOrder = 19, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, playerGui)
local root = make("Frame", { Name = "Root", Size = UDim2.fromOffset(1600, 900), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0) }, gui)
local uiScale = make("UIScale", {}, root)
local modal = make("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromOffset(1, 1), Modal = true, Selectable = false }, gui)   -- libère la souris

-- bouton pour rouvrir le menu depuis le lobby
local openGui = make("ScreenGui", { Name = "MainMenuButton", ResetOnSpawn = false, DisplayOrder = 8 }, playerGui)
local openBtn = K.btn(openGui, "☰  " .. spaced("MENU", 1) .. '  <font color="#8da0bd" size="11">P</font>', "dark", nil,
	{ Position = UDim2.fromOffset(16, 10), Size = UDim2.fromOffset(132, 40), TextSize = 14, Visible = false })

-- ---------- état ----------
-- rubriques : n = nom de l'onglet, help = phrase d'aide ; subs = sous-parties { id (clé gardée dans ctx.sub), n (nom affiché), help }
type Sub = { id: string, n: string, help: string }
local TABS: { { id: string, n: string, ic: string, help: string?, subs: { Sub }? } } = {
	{ id = "home", n = "ACCUEIL", ic = "⌂", help = "Lance une partie, récupère tes cadeaux et relève les défis du jour." },
	{ id = "play", n = "JOUER", ic = "▶", help = "Trois étapes : choisis un mode, puis une carte, puis appuie sur JOUER." },
	{ id = "arsenal", n = "ARSENAL", ic = "✦", subs = {
		{ id = "Armes", n = "Armes", help = "Choisis tes armes, compare leurs statistiques et mets-leur un skin." },
		{ id = "Viseurs", n = "Viseurs", help = "L'optique posée sur chaque arme et le réticule qu'on voit dedans." },
		{ id = "Casier", n = "Tenues et effets", help = "Tenue du soldat, danses (T), sprays (J), effets d'élimination et traînées de balles." },
		{ id = "Caisses", n = "Caisses", help = "Ouvre des caisses pour gagner des skins, des danses et des tenues." },
	} },
	{ id = "profile", n = "PROFIL", ic = "★", subs = {
		{ id = "Progression", n = "Progression", help = "Ton rang, l'événement en cours et la saison. Les défis sont sur l'Accueil." },
		{ id = "Statistiques", n = "Statistiques", help = "Tes résultats : parties, victoires, précision et armes préférées." },
		{ id = "Style", n = "Pseudo et titre", help = "La couleur de ton pseudo et le titre affiché à côté de ton nom." },
	} },
	{ id = "settings", n = "RÉGLAGES", ic = "⚙", subs = MenuConfig.SETTINGS_TABS },
}
local PAGES: { [string]: any } = {}
for _, id in ipairs({ "Home", "Play", "Arsenal", "Profile", "Settings" }) do
	local m = MenuDir:WaitForChild(id, 10)
	if m and m:IsA("ModuleScript") then
		local ok, res = pcall(require, m)
		if ok then PAGES[string.lower(id)] = res else warn("[MainMenu] module " .. id, res) end
	end
end

local ctx: any = {
	K = K, call = call, player = player,
	data = nil :: any, loy = nil :: any, shop = nil :: any,
	tab = "home", sub = { arsenal = "Armes", profile = "Progression", settings = "Général" } :: { [string]: string },
	play = Modes.sanitize({}), friends = false,
	party = { id = nil :: string?, members = {} :: { any } },
	W = 1600, H = 900, newsSeen = false, busy = false,
}
ctx.play.mode = "bomb"; ctx.play.map = "village"; ctx.play.diff = 3; ctx.play.size = 5; ctx.play.limit = Modes.defaultLimit("bomb")
local open = false

local function zone(): string
	local z = player:GetAttribute("Zone")
	return if typeof(z) == "string" then z else ""
end
ctx.zone = zone
function ctx.inMatch(): boolean return zone() == "match" end

-- ---------- message court ----------
local toastLabel = text(root, { Name = "Toast", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -44), Size = UDim2.fromOffset(640, 40),
	BackgroundTransparency = 0.1, BackgroundColor3 = K.rgb(0x0b111c), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 15, ZIndex = 80, Visible = false })
K.corner(toastLabel, 10); K.stroke(toastLabel, C.white, 1, 0.85)
local toastN = 0
function ctx.toast(msg: string, color: Color3?)
	toastN += 1
	local my = toastN
	toastLabel.Text = msg; toastLabel.TextColor3 = color or C.text; toastLabel.Visible = true
	task.delay(3.2, function() if my == toastN then toastLabel.Visible = false end end)
end

-- ---------- réglages : Menu/Options (appliqués côté client, gardés dans le profil, partagés avec la pause) ----------
ctx.opts = Options.v
ctx.applyOpts = Options.apply
local saveTokens: { [string]: number } = {}
function ctx.save(kind: string)   -- enregistre dans le profil, une seconde après le dernier changement
	if kind == "opts" then Options.save(); return end
	saveTokens[kind] = (saveTokens[kind] or 0) + 1
	local my = saveTokens[kind]
	task.delay(1, function()
		if saveTokens[kind] ~= my then return end
		local payload = if kind == "play" then table.clone(ctx.play) else ctx.opts
		if kind == "play" then payload.friends = ctx.friends end
		call("MenuSave", kind, payload)
	end)
end

-- ---------- données ----------
local headerRefs: any = {}
local render: () -> ()
local loadedOnce = false
function ctx.refresh(andRender: boolean?)
	local d = call("GetProfile")
	if d then
		ctx.data = d
		if not loadedOnce then
			loadedOnce = true
			local menu = d.profile and d.profile.menu
			if typeof(menu) == "table" then
				if typeof(menu.play) == "table" then
					ctx.play = Modes.sanitize(menu.play); ctx.friends = menu.play.friends == true
				end
			end
			Options.load(d.profile)   -- anciens réglages (menu.opts) puis toutes les options (profile.options), appliqués
		end
		glowTheme(d.eventActive == true)
	end
	ctx.loy = call("Loy_Get") or ctx.loy
	ctx.ch = call("GetChallenges") or ctx.ch          -- défis du jour / de la semaine, avec leurs textes (pool complet du web)
	ctx.ev = call("EventStatus") or ctx.ev            -- événement d'Halloween (citrouilles, paliers)
	if headerRefs.update then headerRefs.update() end
	if andRender ~= false and open then render() end
end
-- défis, récompense du jour, cadeaux, nouveautés : la pastille sur « Accueil »
function ctx.pending(): number
	local n = 0
	local d = ctx.data
	if d and d.profile then
		local ch = ctx.ch
		for _, m in ipairs(ch and ch.daily or d.profile.missions and d.profile.missions.list or {}) do if m.done and not m.claimed then n += 1 end end
		for _, m in ipairs(ch and ch.weekly or d.profile.wmis and d.profile.wmis.list or {}) do if m.done and not m.claimed then n += 1 end end
		if d.daily and d.daily.canClaim then n += 1 end
	end
	if ctx.loy and ctx.loy.pending then n += #ctx.loy.pending end
	if not ctx.newsSeen then n += 1 end
	return n
end

-- fenêtres des autres interfaces (ShopUI, LoyaltyUI, CommunityUI, LoadoutUI) : registre de ClientState
function ctx.panel(name: string): boolean
	local f = S.panels[name]
	if f then task.spawn(f); return true end
	ctx.toast("Bientôt disponible", C.gold)
	return false
end

-- récompense du jour (bouton RÉCOMPENSE et carte « Cadeau du jour ») : ouvre le calendrier de connexion (DailyUI)
-- s'il est chargé ; sinon récupère directement comme avant
function ctx.claimDaily()
	local cal = S.panels.daily
	if cal then task.spawn(cal); return end
	local d = ctx.data
	if d and d.daily and not d.daily.canClaim then
		ctx.toast("Déjà récupérée · série de " .. tostring(d.daily.streak) .. " jour(s) · reviens demain", C.dim); return
	end
	local res = call("ClaimDaily")
	if res and res.reward then
		local r = res.reward
		local parts = {}
		if r.coins then table.insert(parts, "+" .. r.coins .. " 🪙") end
		if r.box then table.insert(parts, "1 caisse") end
		if r.dance then table.insert(parts, "danse") end
		ctx.toast("🎁 Jour " .. tostring(res.day) .. " : " .. table.concat(parts, " · "), C.gold)
	end
	ctx.refresh()
end

-- passe de combat : la fenêtre du passe (PassUI) si elle est chargée, sinon l'onglet Progression du profil
function ctx.openPass()
	local f = S.panels.pass
	if f then task.spawn(f) else ctx.go("profile", "Progression") end
end

-- ---------- lancer une partie ----------
function ctx.leaveMatch()
	call("MatchLeave")
end
local function launch(fn: () -> (boolean?, string?))
	if ctx.busy then return end
	ctx.busy = true
	if ctx.inMatch() then call("MatchLeave"); task.wait(0.4) end
	ctx.toast("Lancement de la partie…", C.gold)
	local ok, err = fn()
	ctx.busy = false
	if ok then ctx.close() else ctx.toast("❌ " .. tostring(err or "Impossible de lancer la partie"), C.accent) end
end
function ctx.startPlay()
	if ctx.friends and ctx.party.id and player:GetAttribute("PartyLeader") ~= true then
		ctx.toast("Seul le chef du groupe lance la partie", C.gold); return
	end
	local s = table.clone(ctx.play)
	s.private = ctx.friends and ctx.party.id ~= nil
	launch(function() return call("MatchCreate", s) end)
end
function ctx.quick(mode: string?)
	launch(function() return call("MatchQuick", mode) end)
end
function ctx.join(id: number)
	launch(function() return call("MatchJoin", id) end)
end

-- groupe d'amis (PartyService)
local partyEv = ReplicatedStorage:WaitForChild("PartyUpdate", 10) :: RemoteEvent?
if partyEv then
	partyEv.OnClientEvent:Connect(function(id: string?, names: { any })
		ctx.party.id = id; ctx.party.members = names or {}
		if open and ctx.tab == "play" then render() end
	end)
end

-- ---------- mise à l'échelle (téléphones) ----------
local function computeScale()
	local cam = workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1600, 900)
	local inset = GuiService:GetGuiInset()
	local w, h = vp.X, math.max(200, vp.Y - inset.Y)
	-- base 1280 × 720 (taille du texte du web sur un écran de portable) ; au-delà de 1600 de large, le menu reste
	-- centré au lieu de s'étirer sur tout l'écran (fenêtres Studio très larges, écrans 21:9)
	local s = math.clamp(math.min(w / 1280, h / 720), 0.6, 1.6)
	-- AccessibilityController pose un UIScale « AccessScale » sur chaque ScreenGui : le menu, lui, doit tenir dans l'écran
	local acc = gui:FindFirstChild("AccessScale")
	uiScale.Scale = s / (if acc and acc:IsA("UIScale") and acc.Scale > 0 then acc.Scale else 1)
	ctx.W, ctx.H = math.min(math.floor(w / s), 1600), math.floor(h / s)
	root.Size = UDim2.fromOffset(ctx.W, ctx.H)
end

-- ---------- en-tête : logo, navigation, profil ----------
local header = make("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, 90) }, root)
local subRow = make("Frame", { Name = "SubRow", Size = UDim2.new(1, -56, 0, 40), Position = UDim2.fromOffset(28, 96) }, root)
local body = make("Frame", { Name = "Body", Size = UDim2.new(1, -56, 1, -170), Position = UDim2.fromOffset(28, 140), ClipsDescendants = true }, root)
-- en haut de chaque page : « RUBRIQUE › SOUS-PARTIE   phrase d'aide » ; la page elle-même est dessinée dans « pageBox »
local helpBar = text(body, { Name = "HelpBar", Size = UDim2.new(1, 0, 0, 22), TextSize = 13, TextColor3 = C.white, Font = K.MED, TextWrapped = false,
	TextTruncate = Enum.TextTruncate.AtEnd, Text = "" })
local pageBox = make("Frame", { Name = "Page", Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 1, -30), ClipsDescendants = true }, body)
local footer = text(root, { Name = "Footer", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 28, 1, -8), Size = UDim2.new(1, -56, 0, 16),
	TextSize = 11, TextColor3 = C.mute, Font = K.MED, TextWrapped = false,
	Text = 'P : menu (en partie : pause)  •  Tous les réglages sont sauvegardés automatiquement  •  <u>Crédits</u> : modèles d\'armes « Low-Poly » de TastyTony (CC BY 4.0)' })
local navButtons: { [string]: TextButton } = {}

local function buildHeader()
	K.clear(header)
	navButtons = {}
	local W = ctx.W
	local wide = W >= 1570   -- logo (450) + navigation (~620) + encart du profil (480) sur une seule ligne
	-- logo
	local logo = make("Frame", { Position = UDim2.fromOffset(28, 22), Size = UDim2.fromOffset(420, 50) }, header)
	local barL = make("Frame", { Size = UDim2.fromOffset(4, 44), BackgroundTransparency = 0, BackgroundColor3 = C.white }, logo)
	K.gradient(barL, C.orange, C.accent, 90)
	text(logo, { Position = UDim2.fromOffset(18, -2), Size = UDim2.fromOffset(400, 32), Font = K.BLACK, TextSize = 29, TextWrapped = false,
		Text = spaced("STRIKE", 2) .. '   <font color="#ff8a3a">' .. spaced("ARENA", 2) .. "</font>" })
	local nModes, nMaps = 0, #Modes.MAPS
	for _ in pairs(Modes.LIST) do nModes += 1 end
	text(logo, { Position = UDim2.fromOffset(19, 32), Size = UDim2.fromOffset(400, 14), Font = K.BOLD, TextSize = 10, TextColor3 = C.dim, TextWrapped = false,
		Text = spaced("FPS TACTIQUE  •  " .. nModes .. " MODES  •  " .. nMaps .. " CARTES  •  BOTS IA", 1) })
	-- navigation
	local nav = make("Frame", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 50), BackgroundTransparency = 0.4, BackgroundColor3 = C.deep }, header)
	K.corner(nav, 12); K.stroke(nav, C.white, 1, 0.93); K.pad(nav, 4); K.hlist(nav, 2)
	if wide then
		nav.AnchorPoint = Vector2.new(0, 0); nav.Position = UDim2.fromOffset(456, 22)   -- juste après le logo, comme le web
	else
		nav.AnchorPoint = Vector2.new(0, 0); nav.Position = UDim2.fromOffset(28, 84)
	end
	for i, t in ipairs(TABS) do
		local on = ctx.tab == t.id
		local b = K.btn(nav, t.ic .. "  " .. spaced(t.n, 2), if on then "primary" else "ghost", function()
			ctx.go(t.id)
		end, { LayoutOrder = i, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 42), TextSize = 13, BackgroundTransparency = if on then 0 else 1,
			TextColor3 = if on then C.white else K.rgb(0xc5d1e4) })
		K.pad(b, 16, 0)
		local st = b:FindFirstChildOfClass("UIStroke"); if st then st:Destroy() end
		if t.id == "home" then
			local n = ctx.pending()
			if n > 0 then
				local dot = text(b, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -2, 0, 2), Size = UDim2.fromOffset(17, 17), Text = tostring(n),
					BackgroundTransparency = 0, BackgroundColor3 = C.gold, TextColor3 = C.ink, Font = K.BLACK, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Center,
					ZIndex = b.ZIndex + 1 })
				K.corner(dot, 9); K.beat(dot)   -- bat comme la pastille .ndot du web
			end
		end
		navButtons[t.id] = b
	end
	-- encart du profil (en haut à droite)
	local pbox = make("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -28, 0, 16), Size = UDim2.fromOffset(450, 62),
		BackgroundTransparency = 0.15, BackgroundColor3 = C.deep }, header)
	K.corner(pbox, 6); K.stroke(pbox, C.white, 1, 0.9)
	local d = ctx.data
	local lvl = if d then d.level else 1
	local badge = K.levelBadge(pbox, lvl, 38); badge.Position = UDim2.fromOffset(12, 12)
	local nameL = text(pbox, { Position = UDim2.fromOffset(60, 8), Size = UDim2.fromOffset(150, 18), Font = K.BLACK, TextSize = 15, TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd, Text = K.esc(player.DisplayName) })
	local xpBar = K.bar(pbox, if d then d.xp / math.max(1, d.xpNeed) else 0, { Position = UDim2.fromOffset(60, 30), Size = UDim2.fromOffset(110, 5) })
	local xpL = text(pbox, { Position = UDim2.fromOffset(60, 38), Size = UDim2.fromOffset(150, 14), TextSize = 10, TextColor3 = C.dim, TextWrapped = false,
		Text = if d then K.fmt(d.xp) .. " / " .. K.fmt(d.xpNeed) .. " XP" else "…" })
	local coinsL = text(pbox, { Position = UDim2.fromOffset(186, 16), Size = UDim2.fromOffset(100, 28), Font = K.BLACK, TextSize = 16, TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Right, Text = "" })
	-- bonus du jour (ClaimDaily) : rouge quand il attend, discret une fois récupéré
	local canClaim = d ~= nil and d.daily ~= nil and d.daily.canClaim == true
	local rew = K.btn(pbox, "📅  BONUS DU JOUR", if canClaim or not d then "primary" else "alt", ctx.claimDaily,
		{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(150, 40), TextSize = 12, Name = "DailyBonus" })
	if canClaim or not d then K.setBtnColor(rew, K.rgb(0xff5f48)) end
	-- CADEAUX, BOUTIQUE et PREMIUM sous l'encart
	local row = make("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -150, 0, 84), Size = UDim2.fromOffset(400, 32) }, header)
	local lay = K.hlist(row, 10); lay.HorizontalAlignment = Enum.HorizontalAlignment.Right
	K.btn(row, "🛒  " .. spaced("BOUTIQUE", 1), "alt", function() ctx.panel("shop") end, { Size = UDim2.fromOffset(124, 30), TextSize = 11, LayoutOrder = 1 })
	local giftB = K.btn(row, "🎁  " .. spaced("CADEAUX", 1), "purple", function() ctx.panel("gifts") end, { Size = UDim2.fromOffset(118, 30), TextSize = 11, LayoutOrder = 2 })
	local vipB = K.btn(row, "⭐  " .. spaced("PREMIUM", 1), "gold", function() ctx.panel("vip") end, { Size = UDim2.fromOffset(118, 30), TextSize = 11, LayoutOrder = 3 })
	K.setBtnColor(vipB, K.rgb(0xffc53a))
	row.Position = UDim2.new(1, -28, 0, 84)
	local giftDot = text(giftB, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 6, 0, -6), Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 0,
		BackgroundColor3 = C.accent, TextXAlignment = Enum.TextXAlignment.Center, Font = K.BLACK, TextSize = 10, Text = "", Visible = false, ZIndex = giftB.ZIndex + 1 })
	K.corner(giftDot, 9)
	headerRefs.update = function()
		local dd = ctx.data
		if dd then
			badge:Destroy(); badge = K.levelBadge(pbox, dd.level, 38); badge.Position = UDim2.fromOffset(12, 12)
			local fill = xpBar:FindFirstChild("Fill") :: Frame?
			if fill then fill.Size = UDim2.fromScale(math.clamp(dd.xp / math.max(1, dd.xpNeed), 0, 1), 1) end
			xpL.Text = K.fmt(dd.xp) .. " / " .. K.fmt(dd.xpNeed) .. " XP"
			local b = dd.profile.boxes or {}
			coinsL.Text = '<font color="#ffd23a">🪙</font> ' .. K.fmt(dd.profile.coins or 0) .. '   📦 ' .. tostring((b.std or 0) + (b.prem or 0))
			local title = player:GetAttribute("Title")
			nameL.Text = K.esc(player.DisplayName) .. (if typeof(title) == "string" then '  <font size="10" color="#ffd23a">' .. K.esc(title) .. "</font>" else "")
		end
		local lp = ctx.loy and ctx.loy.pending and #ctx.loy.pending or 0
		giftDot.Visible = lp > 0; giftDot.Text = tostring(lp)
		if ctx.loy and ctx.loy.vip then vipB.Text = "⭐  " .. spaced("PREMIUM", 1) .. " · " .. tostring(ctx.loy.vipDaysLeft) .. " j" end
	end
	headerRefs.update()
	-- disposition : en-tête sur une ou deux lignes
	local hh = if wide then 120 else 140
	header.Size = UDim2.new(1, 0, 0, hh)
	subRow.Position = UDim2.fromOffset(28, if wide then 88 else 140)
	local top = (if wide then 88 else 140) + 46
	body.Position = UDim2.fromOffset(28, top); body.Size = UDim2.new(1, -56, 1, -(top + 30))
	if not wide then row.Position = UDim2.new(1, -28, 0, 92); row.AnchorPoint = Vector2.new(1, 0) end
	footer.Visible = ctx.W >= 900
end

-- ---------- sous-onglets (Armes / Viseurs…) et bandeau « partie en cours » ----------
local function buildSubRow()
	K.clear(subRow)
	local t: any = nil
	for _, x in ipairs(TABS) do if x.id == ctx.tab then t = x end end
	local row = make("Frame", { Size = UDim2.new(1, if ctx.inMatch() then -640 else 0, 1, 0), AutomaticSize = Enum.AutomaticSize.None }, subRow)
	K.hlist(row, 8)
	if t and t.subs then
		for i, s in ipairs(t.subs) do
			local on = ctx.sub[t.id] == s.id
			local b = K.btn(row, spaced(s.n, 1), if on then "white" else "dark", function() if ctx.sub[t.id] ~= s.id then ctx.goSub(t.id, s.id) end end,
				{ LayoutOrder = i, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 32), TextSize = 13, Font = K.BLACK })
			K.pad(b, 16, 0); K.corner(b, 16)
			local c = b:FindFirstChildOfClass("UICorner"); if c then c.CornerRadius = UDim.new(0, 16) end
		end
	end
	-- ligne d'aide : où l'on est et à quoi sert cette page
	if t then
		local subDef: Sub? = nil
		for _, s in ipairs(t.subs or {}) do if s.id == ctx.sub[t.id] then subDef = s end end
		local where = t.n .. (if subDef then "  ›  " .. K.upper(subDef.n) else "")
		helpBar.Text = "<b>" .. spaced(where, 1) .. '</b>    <font color="#b8c5da">' .. K.esc(if subDef then subDef.help else (t.help or "")) .. "</font>"
	end
	-- en partie : on peut reprendre ou quitter
	if ctx.inMatch() then
		local strip = make("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(760, 36),
			BackgroundTransparency = 0.1, BackgroundColor3 = K.rgb(0x2a0f14) }, subRow)
		K.corner(strip, 8); K.stroke(strip, C.accent, 1, 0.5); K.pad(strip, 12, 0, 4, 0)
		local mm = player:GetAttribute("MatchMode")
		local mdef = if typeof(mm) == "string" then Modes.LIST[mm] else nil
		text(strip, { Size = UDim2.new(1, -420, 1, 0), TextSize = 12, Font = K.BLACK, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd,
			Text = '<font color="#ff4655">●</font>  ' .. spaced("PARTIE EN COURS", 1) .. (if mdef then '  <font color="#b8c5da">· ' .. mdef.n .. "</font>" else "") })
		K.btn(strip, "📷  MODE PHOTO", "alt", function()
			ctx.close()
			local ok, err = pcall(function() require(ReplicatedStorage.Shared.PhotoMode).enter() end)
			if not ok then warn("[MainMenu] PhotoMode", err) end
		end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -280, 0.5, 0), Size = UDim2.fromOffset(124, 28), TextSize = 11 })
		K.btn(strip, "▶  REPRENDRE", "primary", function() ctx.close() end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -150, 0.5, 0), Size = UDim2.fromOffset(124, 28), TextSize = 12 })
		K.btn(strip, "QUITTER LA PARTIE", "dark", function()
			ctx.leaveMatch(); ctx.go("home")
		end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(146, 28), TextSize = 11 })
	end
end

-- ---------- rendu d'une rubrique ----------
local function scrollPositions(): { [string]: Vector2 }
	local out = {}
	for _, d in ipairs(pageBox:GetDescendants()) do if d:IsA("ScrollingFrame") then out[d.Name] = d.CanvasPosition end end
	return out
end
-- changement d'onglet (dir = -1 / 1) : la page arrive en glissant et en fondu (tpin du web), puis ses cartes en cascade.
-- Le fondu passe par un CanvasGroup le temps de l'animation ; ensuite la page est remise directement dans « pageBox »
-- (un CanvasGroup permanent rendrait le texte un peu flou).
local fadeN, fadeAt = 0, 0
local function animateIn(host: CanvasGroup, dir: number)
	fadeN += 1; fadeAt = os.clock()
	local my = fadeN
	host.GroupTransparency = 1
	host.Position = UDim2.fromOffset(28 * dir, 0)
	task.defer(function()
		if not host.Parent then return end
		K.cascade(host)
		local tw = K.tween(host, 0.28, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quint)
		tw.Completed:Connect(function()
			if my ~= fadeN or host.Parent ~= pageBox then return end
			for _, c in ipairs(host:GetChildren()) do c.Parent = pageBox end
			host:Destroy()
		end)
	end)
end
local function renderWith(dir: number?)
	if not open then return end
	local keep = scrollPositions()
	buildHeader(); buildSubRow()
	K.clear(pageBox)
	local host: GuiObject = pageBox
	if dir then host = make("CanvasGroup", { Name = "PageFade", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, pageBox) end
	local pageFn = PAGES[ctx.tab]
	if pageFn then
		local ok, err = pcall(pageFn, ctx, host, ctx.sub[ctx.tab])
		if not ok then
			warn("[MainMenu] rubrique " .. ctx.tab, err)
			text(host, { Text = "Cette rubrique n'a pas pu s'afficher.", TextColor3 = C.dim, Size = UDim2.new(1, 0, 0, 30) })
		end
	end
	if dir and host:IsA("CanvasGroup") then animateIn(host, dir) end
	task.defer(function()
		for _, d in ipairs(pageBox:GetDescendants()) do
			if d:IsA("ScrollingFrame") and keep[d.Name] then d.CanvasPosition = keep[d.Name] end
		end
	end)
end
-- un rafraîchissement (profil reçu juste après l'ouverture…) attend la fin de l'animation au lieu de la couper
local renderLater = false
render = function()
	if pageBox:FindFirstChild("PageFade") and os.clock() - fadeAt < 1 then
		if not renderLater then
			renderLater = true
			task.delay(0.35, function() renderLater = false; render() end)
		end
		return
	end
	renderWith(nil)
end
ctx.render = function() render() end

local function tabIndex(id: string): number
	for i, t in ipairs(TABS) do if t.id == id then return i end end
	return 1
end
-- sous-onglet (Armes / Viseurs…, Général / Son…) : glisse depuis le côté où il se trouve
function ctx.goSub(tab: string, s: string)
	local t = TABS[tabIndex(tab)]
	local function at(id: string?): number
		for i, x in ipairs(t.subs or {}) do if x.id == id then return i end end
		return 1
	end
	local old, new = at(ctx.sub[tab]), at(s)
	ctx.sub[tab] = s
	renderWith(if new >= old then 1 else -1)
end

function ctx.go(tab: string, sub: string?)
	local dir = if tabIndex(tab) >= tabIndex(ctx.tab) then 1 else -1
	local changed = tab ~= ctx.tab or (sub ~= nil and sub ~= ctx.sub[tab])
	if tab ~= ctx.tab then
		for _, d in ipairs(pageBox:GetDescendants()) do if d:IsA("ScrollingFrame") then d.CanvasPosition = Vector2.zero end end
	end
	if ctx.tab == "home" then ctx.newsSeen = true end
	ctx.tab = tab
	if sub then ctx.sub[tab] = sub end
	if changed then renderWith(dir) else render() end
	if UserInputService.GamepadEnabled and navButtons[tab] then GuiService.SelectedObject = navButtons[tab] end
end

-- ---------- ouverture / fermeture ----------
local controls: any = nil
task.spawn(function()
	local ps = player:WaitForChild("PlayerScripts")
	local pm = ps:WaitForChild("PlayerModule", 10)
	if pm and pm:IsA("ModuleScript") then
		local ok, m = pcall(require, pm)
		if ok and m and (m :: any).GetControls then controls = (m :: any):GetControls() end
	end
end)

local function tabStep(dir: number)
	local idx = 1
	for i, t in ipairs(TABS) do if t.id == ctx.tab then idx = i end end
	ctx.go(TABS[(idx - 1 + dir) % #TABS + 1].id)
end
local function bindOpenActions(on: boolean)
	if on then
		ContextActionService:BindActionAtPriority("MainMenuBack", function(_, st)
			if st == Enum.UserInputState.Begin then ctx.close() end
			return Enum.ContextActionResult.Sink
		end, false, 3000, Enum.KeyCode.ButtonB)
		ContextActionService:BindActionAtPriority("MainMenuTabs", function(_, st, input)
			if st == Enum.UserInputState.Begin then tabStep(if input.KeyCode == Enum.KeyCode.ButtonR1 then 1 else -1) end
			return Enum.ContextActionResult.Sink
		end, false, 3000, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1)
	else
		ContextActionService:UnbindAction("MainMenuBack")
		ContextActionService:UnbindAction("MainMenuTabs")
	end
end

-- interface de partie (vie, munitions, minicarte…) et chat cachés derrière le menu, comme sur le web
local HUD_GUIS = { "MatchHud", "ModeHud", "ZombieBrHud", "GrenadeHud", "MedalHud", "PerkDrink", "PickupToast", "Scope" }
local hiddenHud: { ScreenGui } = {}
local function hideHud(on: boolean)
	if on then
		for _, n in ipairs(HUD_GUIS) do
			local g = playerGui:FindFirstChild(n)
			if g and g:IsA("ScreenGui") and g.Enabled then g.Enabled = false; table.insert(hiddenHud, g) end
		end
	else
		for _, g in ipairs(hiddenHud) do if g.Parent then g.Enabled = true end end
		table.clear(hiddenHud)
	end
	pcall(function()
		local TextChatService = game:GetService("TextChatService")
		local win = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
		local bar = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
		if win then win.Enabled = not on end
		if bar then bar.Enabled = not on end
	end)
end
local function setOpen(on: boolean)
	if on and zone() == "duel" then return end
	if on == open then return end
	open = on
	S.menuOpen = on
	hideHud(on)
	gui.Enabled = on; bgGui.Enabled = on; modal.Visible = on
	openBtn.Visible = not on and zone() == "lobby"
	player:SetAttribute("UiOpen", on)
	player:SetAttribute("MenuOpen", on)   -- les boutons des autres interfaces se cachent pendant ce temps
	if controls then pcall(function() if on then controls:Disable() else controls:Enable() end end) end
	bindOpenActions(on)
	if on then
		computeScale()
		-- ouverture : le menu arrive en zoomant légèrement (sbIn du web), la page et ses cartes en fondu et en cascade
		local s = uiScale.Scale
		uiScale.Scale = s * 0.965
		K.tween(uiScale, 0.32, { Scale = s }, Enum.EasingStyle.Quint)
		renderWith(1)
		task.spawn(function() ctx.refresh(true) end)
		if UserInputService.GamepadEnabled and navButtons[ctx.tab] then GuiService.SelectedObject = navButtons[ctx.tab] end
	else
		if ctx.tab == "home" then ctx.newsSeen = true end
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then GuiService.SelectedObject = nil end
	end
end
function ctx.open(tab: string?, sub: string?)
	if tab then ctx.tab = tab; if sub then ctx.sub[tab] = sub end end
	setOpen(true)
end
function ctx.close() setOpen(false) end
function ctx.isOpen(): boolean return open end

-- une autre interface referme son panneau et libère « UiOpen » : le menu, lui, est toujours ouvert
player:GetAttributeChangedSignal("UiOpen"):Connect(function()
	if open and player:GetAttribute("UiOpen") ~= true then player:SetAttribute("UiOpen", true) end
end)

openBtn.Activated:Connect(function() setOpen(true) end)
-- P / croix bas : au lobby le menu ; en partie la pause (PauseMenu, qui s'inscrit dans S.panels), d'où l'on rejoint le menu
ContextActionService:BindAction("MainMenu", function(_, st)
	if st == Enum.UserInputState.Begin then
		local pause = S.panels.pause
		if not open and ctx.inMatch() and pause then pause() else setOpen(not open) end
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.P, Enum.KeyCode.DPadDown)
-- la pause ouvre le menu principal (bouton MENU PRINCIPAL) ; « settings » l'ouvre sur les Réglages
S.panels.menu = function() setOpen(true) end
S.panels.settings = function() ctx.open("settings", "Général") end
-- les autres fenêtres (passe, calendrier, boutique) demandent de rafraîchir le menu après une récupération
S.panels.menuRefresh = function() task.spawn(ctx.refresh) end

-- arrivée au lobby et retour d'une partie : le menu s'ouvre ; une partie commence : il se ferme
local lastZone = zone()
local function onZone()
	local z = zone()
	if z == "match" or z == "duel" then
		setOpen(false)
	elseif z == "lobby" and lastZone ~= "lobby" then
		task.delay(if lastZone == "" then 1.5 else 2.5, function()
			if zone() == "lobby" then ctx.tab = "home"; setOpen(true) end
		end)
	end
	openBtn.Visible = not open and z == "lobby"
	lastZone = z
	if open then render() end
end
player:GetAttributeChangedSignal("Zone"):Connect(onZone)
if zone() == "lobby" then lastZone = ""; onZone() end

-- écran redimensionné / téléphone tourné
local resizeN = 0
local function watchCamera(cam: Camera?)
	if not cam then return end
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		resizeN += 1
		local my = resizeN
		task.delay(0.25, function() if my == resizeN and open then computeScale(); render() end end)
	end)
end
watchCamera(workspace.CurrentCamera)
local function hookAccess(c: Instance)
	if c.Name == "AccessScale" and c:IsA("UIScale") then
		c:GetPropertyChangedSignal("Scale"):Connect(computeScale); computeScale()
	end
end
gui.ChildAdded:Connect(hookAccess)
for _, c in ipairs(gui:GetChildren()) do hookAccess(c) end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() watchCamera(workspace.CurrentCamera) end)

-- achat Robux terminé, cadeau débloqué : les chiffres du profil changent
game:GetService("MarketplaceService").PromptProductPurchaseFinished:Connect(function(userId: number, _id: number, ok: boolean)
	if userId == player.UserId and ok then task.wait(1); ctx.refresh() end
end)
player:GetAttributeChangedSignal("LoyaltyGiftReady"):Connect(function() task.spawn(ctx.refresh) end)
player:GetAttributeChangedSignal("Title"):Connect(function() if headerRefs.update then headerRefs.update() end end)

-- premier chargement du profil (réglages gardés, pastilles) même si le menu est fermé
task.spawn(function()
	for _ = 1, 20 do
		ctx.refresh(false)
		if ctx.data then break end
		task.wait(1.5)
	end
end)
computeScale()
