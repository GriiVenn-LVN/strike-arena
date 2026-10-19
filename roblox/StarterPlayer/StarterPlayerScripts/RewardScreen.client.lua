--!strict
-- StarterPlayerScripts/RewardScreen (LocalScript)
-- Récompenses qui se voient, façon Call of Duty / Fortnite :
--   • BILAN DE LA PARTIE (écran de fin, à droite des cartes de HudController) : chaque gain d'XP ligne par ligne
--     (participation, éliminations, victoire, mode de la semaine, week-end XP ×2, médailles…), bonus de fidélité,
--     total d'XP et de pièces qui défilent, barre de niveau qui se remplit (et repart à zéro à chaque niveau gagné),
--     avancée du passe de combat, défis terminés pendant la partie, rappel de la première victoire du jour.
--     Données : résumé MatchEnd → recap (ServerScriptService/RecapService).
--   • NIVEAU SUPÉRIEUR : grande fenêtre avec le nouveau niveau, la récompense débloquée et le prochain gros palier
--     (remote « LevelUp » de RewardService). En fin de partie, elle attend que la barre de niveau ait fini de se remplir.
-- Rien n'est crédité ici : tout l'a déjà été par le serveur.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local S = require(ReplicatedStorage.Shared.ClientState)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local ModeConfig = require(ReplicatedStorage.Shared.ModeConfig)
local K = require(script.Parent:WaitForChild("Menu"):WaitForChild("Kit"))
local C = K.C
local make, text, spaced = K.make, K.text, K.spaced

local player = Players.LocalPlayer
local gui = make("ScreenGui", { Name = "RewardScreen", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 13,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))

-- texte d'une récompense de niveau ou de palier : { coins, box, n, dance }
local function rewardText(r: any): string
	if typeof(r) ~= "table" then return "" end
	local t = {}
	if r.coins then table.insert(t, "🪙 " .. K.fmt(r.coins) .. " pièces") end
	if r.box then table.insert(t, "📦 " .. (if (r.n or 1) > 1 then r.n .. " " else "") .. (if r.box == "prem" then "Caisse Premium" else "Caisse Standard")) end
	if r.dance and Config.DANCES[r.dance] then table.insert(t, "💃 Danse « " .. Config.DANCES[r.dance].name .. " »") end
	return table.concat(t, "   ")
end

-- taille de l'écran : les panneaux rétrécissent sur les petits écrans (téléphones)
local function screenScale(): number
	local cam = workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1600, 900)
	return math.clamp(math.min(vp.X / 1700, vp.Y / 860), 0.55, 1)
end

-- =====================================================================================
-- BILAN DE LA PARTIE
-- =====================================================================================
local recap = make("Frame", { Name = "Recap", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0.56, 0), Size = UDim2.fromOffset(330, 0),
	AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 0.06, BackgroundColor3 = K.rgb(0x0b111c), Visible = false, ZIndex = 2 }, gui)
K.corner(recap, 12); K.stroke(recap, C.gold, 1.5, 0.55); K.pad(recap, 16, 14)
K.gradient(recap, K.rgb(0x141e31), K.rgb(0x0a0f19), 90)
local recapScale = make("UIScale", { Scale = 1 }, recap)
K.vlist(recap, 6)
local recapToken = 0
local animating = false     -- barre de niveau en train de se remplir : la fenêtre NIVEAU SUPÉRIEUR attend

local function row(order: number, h: number?): Frame
	return make("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, h or 20) }, recap)
end
local function fadeIn(o: GuiObject, delay: number)
	local lbls = {}
	if o:IsA("TextLabel") then table.insert(lbls, o) end
	for _, d in ipairs(o:GetDescendants()) do if d:IsA("TextLabel") then table.insert(lbls, d) end end
	for _, l in ipairs(lbls) do (l :: TextLabel).TextTransparency = 1 end
	task.delay(delay, function()
		for _, l in ipairs(lbls) do if l.Parent then K.tween(l, 0.25, { TextTransparency = 0 }) end end
	end)
end
-- nombre qui défile de 0 à n
local function countUp(l: TextLabel, n: number, fmt: (number) -> string, dur: number, delay: number)
	task.delay(delay, function()
		local t0 = os.clock()
		while l.Parent and os.clock() - t0 < dur do
			l.Text = fmt(math.floor(n * (os.clock() - t0) / dur))
			task.wait(1 / 30)
		end
		if l.Parent then l.Text = fmt(n) end
	end)
end

local levelQueue: { any } = {}
local showLevelUp: () -> ()

local function buildRecap(rc: any)
	K.clear(recap)
	recapToken += 1
	local my = recapToken
	recapScale.Scale = screenScale()
	recap.Visible = true
	local order = 0
	local function nextOrder(): number order += 1; return order end
	local delay = 0.9
	local function step(d: number): number delay += d; return delay end

	-- titre + étiquettes des bonus actifs
	local head = row(nextOrder(), 24)
	text(head, { Text = spaced("BILAN DE LA PARTIE", 2), Font = K.BLACK, TextSize = 15, TextColor3 = C.gold, Size = UDim2.fromScale(1, 1), TextWrapped = false })
	local tags: { { t: string, c: Color3 } } = {}
	if rc.weekend then table.insert(tags, { t = "WEEK-END XP ×2", c = C.violet }) end
	if rc.featured then table.insert(tags, { t = "MODE DE LA SEMAINE ×2", c = C.blue }) end
	if rc.firstWin then table.insert(tags, { t = "1RE VICTOIRE DU JOUR", c = C.gold }) end
	if #tags > 0 then
		local tr = make("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, recap)
		K.hlist(tr, 6, nil, true)
		for i, tg in ipairs(tags) do
			local chip = text(tr, { LayoutOrder = i, Text = spaced(tg.t, 1), Font = K.BLACK, TextSize = 10, TextColor3 = C.ink, AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 20), BackgroundTransparency = 0, BackgroundColor3 = tg.c, TextWrapped = false })
			K.corner(chip, 4); K.pad(chip, 8, 0)
			K.beat(chip, 1.06, 1.2)
		end
	end
	-- XP ligne par ligne
	for _, l in ipairs(if typeof(rc.lines) == "table" then rc.lines else {}) do
		local r = row(nextOrder(), 18)
		text(r, { Text = tostring(l.t), TextSize = 13, Font = K.MED, TextColor3 = C.sub, Size = UDim2.new(1, -90, 1, 0), TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
		text(r, { Text = "+" .. K.fmt(tonumber(l.xp) or 0) .. " XP", TextSize = 13, Font = K.BLACK, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 90, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false })
		fadeIn(r, step(0.12))
		task.delay(delay, function() if my == recapToken then K.uiSound(true) end end)
	end
	for _, b in ipairs(if typeof(rc.bonus) == "table" then rc.bonus else {}) do
		local r = text(recap, { LayoutOrder = nextOrder(), Text = tostring(b), TextSize = 12, Font = K.BOLD, TextColor3 = C.gold, Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y })
		fadeIn(r, step(0.12))
	end
	-- totaux
	make("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 1), BackgroundTransparency = 0.85, BackgroundColor3 = C.white }, recap)
	local tot = row(nextOrder(), 34)
	local xpL = text(tot, { Text = "+0 XP", Font = K.BLACK, TextSize = 26, Size = UDim2.new(0.55, 0, 1, 0), TextWrapped = false })
	local coinL = text(tot, { Text = "+0 🪙", Font = K.BLACK, TextSize = 22, TextColor3 = C.gold, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.45, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false })
	countUp(xpL, tonumber(rc.xp) or 0, function(n) return "+" .. K.fmt(n) .. " XP" end, 0.9, step(0.15))
	countUp(coinL, tonumber(rc.coins) or 0, function(n) return "+" .. K.fmt(n) .. ' <font size="16">🪙</font>' end, 0.9, delay)
	text(recap, { LayoutOrder = nextOrder(), Text = "Total : " .. K.fmt(tonumber(rc.coinsTotal) or 0) .. " pièces", TextSize = 11, TextColor3 = C.dim, Size = UDim2.new(1, 0, 0, 14) })

	-- barre de niveau : de « from » à « to », un tour complet par niveau gagné
	local from, to = rc.from or { level = 1, xp = 0, need = 1 }, rc.to or { level = 1, xp = 0, need = 1 }
	local lv = row(nextOrder(), 44)
	local badgeHolder = make("Frame", { Size = UDim2.fromOffset(40, 40) }, lv)
	local badge = K.levelBadge(badgeHolder, from.level, 40)
	local lvlL = text(lv, { Text = "NIVEAU " .. from.level, Font = K.BLACK, TextSize = 13, Position = UDim2.fromOffset(52, 2), Size = UDim2.new(1, -52, 0, 16), TextWrapped = false })
	local bar = K.bar(lv, from.xp / math.max(1, from.need), { Position = UDim2.fromOffset(52, 22), Size = UDim2.new(1, -52, 0, 8) }, C.blue, C.gold)
	local fill = bar:FindFirstChild("Fill") :: Frame
	local xpTxt = text(lv, { Text = K.fmt(from.xp) .. " / " .. K.fmt(from.need) .. " XP", TextSize = 10, TextColor3 = C.dim, Position = UDim2.fromOffset(52, 32),
		Size = UDim2.new(1, -52, 0, 12), TextWrapped = false })
	animating = true
	task.delay(step(0.5), function()
		if my ~= recapToken then return end
		local level = from.level
		local levels = math.max(0, (to.level or level) - level)
		for _ = 1, levels do
			if my ~= recapToken then break end
			K.tween(fill, 0.55, { Size = UDim2.fromScale(1, 1) }); task.wait(0.6)
			level += 1
			badge:Destroy(); badge = K.levelBadge(badgeHolder, level, 40)
			local sc = make("UIScale", { Scale = 1.6 }, badge); K.tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			lvlL.Text = "NIVEAU " .. level .. '  <font color="#ffd23a">▲</font>'
			pcall(function() Sfx.play(ModeConfig.SOUNDS.streak) end)
			fill.Size = UDim2.fromScale(0, 1)
		end
		if my ~= recapToken then return end
		K.tween(fill, 0.7, { Size = UDim2.fromScale(math.clamp(to.xp / math.max(1, to.need), 0, 1), 1) })
		xpTxt.Text = K.fmt(to.xp) .. " / " .. K.fmt(to.need) .. " XP  ·  encore " .. K.fmt(math.max(0, to.need - to.xp)) .. " XP"
		task.wait(0.8)
		animating = false
		showLevelUp()
	end)

	-- passe de combat
	local bp = rc.bp
	if typeof(bp) == "table" then
		local pr = row(nextOrder(), 40)
		text(pr, { Text = "🎟 PASSE DE COMBAT · PALIER " .. bp.tier .. " / " .. bp.max .. (if (bp.gained or 0) > 0 then '  <font color="#7dff9f">+' .. bp.gained .. "</font>" else ""),
			Font = K.BLACK, TextSize = 12, Size = UDim2.new(1, 0, 0, 16), TextWrapped = false })
		K.bar(pr, bp.frac or 0, { Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 5) }, C.purple, C.violet)
		if (bp.claimable or 0) > 0 then
			text(pr, { Text = "🎁 " .. bp.claimable .. " récompense(s) à récupérer", TextSize = 11, TextColor3 = C.gold, Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, -110, 0, 12), TextWrapped = false })
		end
		local b = K.btn(pr, spaced("VOIR LE PASSE", 1), "purple", function() local f = S.panels.pass; if f then task.spawn(f) end end,
			{ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 26), Size = UDim2.fromOffset(104, 16), TextSize = 9, Modal = true })
		fadeIn(pr, step(0.1)); local _ = b
	end
	-- défis terminés pendant la partie
	for _, c in ipairs(if typeof(rc.challenges) == "table" then rc.challenges else {}) do
		local r = text(recap, { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 11, Font = K.BOLD,
			TextColor3 = if c.weekly then C.violet else C.green,
			Text = "✔ " .. (if c.weekly then "Défi de la semaine" else "Défi du jour") .. " : " .. K.esc(tostring(c.text)) .. '  <font color="#ffd23a">🪙 ' .. tostring(c.coins) .. " · " .. tostring(c.xp) .. " XP</font> à récupérer" })
		fadeIn(r, step(0.1))
	end
	if rc.firstWinLeft and not rc.firstWin then
		local r = text(recap, { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 11, TextColor3 = C.dim,
			Text = "🏆 Première victoire du jour encore à prendre : +100 XP, +25 pièces" })
		fadeIn(r, step(0.1))
	end
	-- apparition du panneau
	recap.Position = UDim2.new(1, 40, 0.56, 0)
	K.tween(recap, 0.45, { Position = UDim2.new(1, -18, 0.56, 0) }, Enum.EasingStyle.Quint)
end

local endRemote = ReplicatedStorage:WaitForChild("MatchEnd", 30) :: RemoteEvent?
if endRemote then
	endRemote.OnClientEvent:Connect(function(r: any)
		if typeof(r) ~= "table" or typeof(r.recap) ~= "table" then return end
		buildRecap(r.recap)
		local my = recapToken
		task.delay((tonumber(r.next) or 15) + 0.5, function() if my == recapToken then recap.Visible = false end end)
	end)
end
-- quitter la partie ou une nouvelle partie : le bilan disparaît
local function hideRecap() recapToken += 1; recap.Visible = false; animating = false end
player:GetAttributeChangedSignal("Zone"):Connect(function()
	if player:GetAttribute("Zone") ~= "match" then hideRecap(); task.defer(function() showLevelUp() end) end
end)
local stateRemote = ReplicatedStorage:WaitForChild("TDMState", 30) :: RemoteEvent?
if stateRemote then
	stateRemote.OnClientEvent:Connect(function(st: any)
		if typeof(st) == "table" and st.warmup and recap.Visible then hideRecap() end
	end)
end

-- =====================================================================================
-- NIVEAU SUPÉRIEUR
-- =====================================================================================
local veil = make("TextButton", { Name = "LevelUp", Size = UDim2.fromScale(1, 1), BackgroundColor3 = K.rgb(0x05080e), BackgroundTransparency = 1, Text = "",
	AutoButtonColor = false, Visible = false, ZIndex = 20 }, gui)
local card = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(460, 300), BackgroundTransparency = 0,
	BackgroundColor3 = C.white, ZIndex = 21 }, veil)
K.corner(card, 18); K.gradient(card, K.rgb(0x1d2a45), K.rgb(0x0b111c), 90); K.stroke(card, C.gold, 2, 0.2)
local cardScale = make("UIScale", { Scale = 1 }, card)
-- rayons qui tournent derrière le badge
local rays = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 94), Size = UDim2.fromOffset(220, 220), ZIndex = 21 }, card)
for i = 1, 8 do
	local f = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(14, 200), Rotation = i * 22.5,
		BackgroundTransparency = 0.9, BackgroundColor3 = C.gold, ZIndex = 21 }, rays)
	K.corner(f, 7)
end
local title = text(card, { Text = spaced("NIVEAU SUPÉRIEUR", 3), Font = K.BLACK, TextSize = 26, TextColor3 = C.gold, Position = UDim2.fromOffset(0, 16),
	Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, ZIndex = 23 })
local badgeBox = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 56), Size = UDim2.fromOffset(76, 76), ZIndex = 23 }, card)
local rewardL = text(card, { Text = "", Font = K.BLACK, TextSize = 17, Position = UDim2.fromOffset(20, 150), Size = UDim2.new(1, -40, 0, 44),
	TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 23 })
local nextL = text(card, { Text = "", TextSize = 12, TextColor3 = C.dim, Position = UDim2.fromOffset(20, 200), Size = UDim2.new(1, -40, 0, 32),
	TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 23 })
local okBtn = K.btn(card, spaced("SUPER !", 2), "gold", nil, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(160, 36),
	TextSize = 13, ZIndex = 23, Modal = true })
local luToken = 0
local showing = false
local function closeLevelUp()
	if not showing then return end
	luToken += 1
	showing = false
	K.tween(veil, 0.2, { BackgroundTransparency = 1 })
	K.tween(cardScale, 0.2, { Scale = 0.7 })
	task.delay(0.2, function()
		veil.Visible = false
		showLevelUp()
	end)
end
okBtn.Activated:Connect(closeLevelUp)
veil.Activated:Connect(closeLevelUp)
task.spawn(function()
	while true do
		task.wait(1 / 30)
		if veil.Visible then rays.Rotation = (rays.Rotation + 0.6) % 360 end
	end
end)

showLevelUp = function()
	if showing or animating or #levelQueue == 0 then return end
	if player:GetAttribute("Zone") == "match" and not recap.Visible then
		-- en pleine partie (défi récupéré, médaille…) : on attend la fin de la partie pour ne pas gêner
		return
	end
	local d = table.remove(levelQueue, 1)
	showing = true
	luToken += 1
	local my = luToken
	local ups = if typeof(d.ups) == "table" then d.ups else {}
	local last = ups[#ups] or { level = d.level }
	K.clear(badgeBox)
	local b = K.levelBadge(badgeBox, tonumber(last.level) or 1, 76)
	b.ZIndex = 23
	for _, c in ipairs(b:GetDescendants()) do if c:IsA("GuiObject") then c.ZIndex = 24 end end
	title.Text = spaced(if #ups > 1 then "+" .. #ups .. " NIVEAUX !" else "NIVEAU SUPÉRIEUR", 3)
	local lines = {}
	for _, u in ipairs(ups) do table.insert(lines, rewardText(u.reward)) end
	rewardL.Text = "Récompense débloquée\n" .. table.concat(lines, "   ")
	local ms = d.milestone
	nextL.Text = if typeof(ms) == "table" then "Prochain gros palier : niveau " .. tostring(ms.level) .. " — " .. rewardText(ms.reward) else ""
	veil.Visible = true; veil.BackgroundTransparency = 1
	K.tween(veil, 0.3, { BackgroundTransparency = 0.45 })
	cardScale.Scale = 0.4 * screenScale()
	K.tween(cardScale, 0.45, { Scale = screenScale() }, Enum.EasingStyle.Back)
	pcall(function() Sfx.play(ModeConfig.SOUNDS.streak) end)
	task.delay(6, function() if my == luToken then closeLevelUp() end end)
end

local luRemote = ReplicatedStorage:WaitForChild("LevelUp", 30) :: RemoteEvent?
if luRemote then
	luRemote.OnClientEvent:Connect(function(d: any)
		if typeof(d) ~= "table" then return end
		table.insert(levelQueue, d)
		-- MatchEnd arrive juste après : on laisse le bilan démarrer avant d'afficher quoi que ce soit
		task.delay(0.6, showLevelUp)
	end)
end
