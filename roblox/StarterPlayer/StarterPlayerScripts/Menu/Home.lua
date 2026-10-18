--!strict
-- StarterPlayerScripts/Menu/Home (ModuleScript) — rubrique « Accueil » (src/87d_lobby.js lobbyDraw)
-- colonne 1 : grande carte JOUER (événement, mode de la semaine), saison et cadeau du jour
-- colonne 2 : défis du jour et de la semaine (récupérables ici) ; colonne 3 : cadeaux, Premium, nouveautés
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modes = require(ReplicatedStorage.Shared.Modes)
local X = require(ReplicatedStorage.Shared.ConfigExtra)
local MenuConfig = require(ReplicatedStorage.Shared.MenuConfig)
local K = require(script.Parent.Kit)
local C = K.C
local make, text, spaced = K.make, K.text, K.spaced

local function modeName(id: string): string
	local m = Modes.LIST[id]
	return if m then (string.gsub(m.n, "%s*%(.*%)", "")) else id
end
local function untilMidnight(): string
	local left = 86400 - os.time() % 86400
	local h, mn = left // 3600, (left % 3600) // 60
	return if h > 0 then string.format("%d h %02d", h, mn) else mn .. " min"
end
local function weekLeft(): string
	local t = os.time()
	local dow = (t // 86400 + 3) % 7           -- 0 = lundi
	local left = (7 - dow) * 86400 - t % 86400
	local h = math.ceil(left / 3600)
	return if h > 48 then math.ceil(h / 24) .. " j" else h .. " h"
end

-- un défi (.lmis) : texte, bouton RÉCUPÉRER quand il est fini, jauge, progression et gains
local function mission(ctx: any, parent: Instance, m: any, i: number, weekly: boolean)
	local f = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = if m.done and not m.claimed then 0.92 else 0.97,
		BackgroundColor3 = if m.done and not m.claimed then C.gold else C.white, LayoutOrder = i }, parent)
	K.corner(f, 10); K.pad(f, 12, 10)
	K.stroke(f, if m.done and not m.claimed then C.gold else C.white, 1, if m.done and not m.claimed then 0.45 else 0.94)
	K.vlist(f, 6)
	local top = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 }, f)
	text(top, { Text = MenuConfig.missionText(m.id, m.target, weekly), TextSize = 13, Font = K.MED, TextColor3 = if m.claimed then C.dim else C.text,
		Size = UDim2.new(1, -110, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	if m.done and not m.claimed then
		K.btn(top, spaced("RÉCUPÉRER", 1), "gold", function()
			local res = ctx.call(if weekly then "ClaimWeekly" else "ClaimMission", i)
			if res then ctx.toast("✔ +" .. m.coins .. " 🪙 · +" .. m.xp .. " XP", C.gold) end
			ctx.refresh()
		end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(104, 24), TextSize = 10 })
	elseif m.claimed then
		text(top, { Text = "✔", TextColor3 = C.green, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(30, 18),
			TextXAlignment = Enum.TextXAlignment.Right })
	end
	local bar = K.bar(f, m.progress / math.max(1, m.target), { LayoutOrder = 2 }, if m.claimed then C.green elseif weekly then C.purple else nil,
		if m.claimed then C.green elseif weekly then C.violet else nil)
	bar.Size = UDim2.new(1, 0, 0, 5)
	text(f, { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 14), TextSize = 11, TextColor3 = C.dim, TextWrapped = false,
		Text = K.fmt(m.progress) .. " / " .. K.fmt(m.target) .. '  ·  <font color="#ffd23a">🪙</font> ' .. m.coins .. "  ·  " .. m.xp .. " XP" })
end

return function(ctx: any, body: Frame, _sub: string?)
	local d = ctx.data
	local profile = d and d.profile
	local W = ctx.W - 56
	local three = W >= 1100
	local cols: { GuiObject } = {}
	if three then
		local unit = (W - 36) / 3.3
		local widths = { unit * 1.3, unit, unit }
		local x = 0
		for i = 1, 3 do
			local s = K.scroll(body, { Name = "HomeCol" .. i, Size = UDim2.new(0, widths[i], 1, 0), Position = UDim2.fromOffset(x, 0) })
			K.vlist(s, 14); K.pad(s, 0, 2, 6, 10)
			cols[i] = s; x += widths[i] + 18
		end
	else
		local s = K.scroll(body, { Name = "HomeCol" })
		K.vlist(s, 14); K.pad(s, 0, 2, 6, 10)
		cols = { s, s, s }
	end

	-- ============ colonne 1 : JOUER ============
	local hw = d and d.eventActive == true
	local hero = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 0, BackgroundColor3 = C.white,
		LayoutOrder = 1, ClipsDescendants = true }, cols[1])
	-- fond du web : radial-gradient rouge (orange à Halloween) en haut à gauche, bleu (violet) en bas à droite, sur un bleu nuit
	make("UIGradient", { Rotation = 35, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, if hw then K.rgb(0x5a2a1c) else K.rgb(0x4a1c2a)),
		ColorSequenceKeypoint.new(0.42, if hw then K.rgb(0x1d1426) else K.rgb(0x151f33)),
		ColorSequenceKeypoint.new(0.78, if hw then K.rgb(0x0e0b16) else K.rgb(0x0a0f1a)),
		ColorSequenceKeypoint.new(1, if hw then K.rgb(0x2a1a4a) else K.rgb(0x10284a)) }), Transparency = NumberSequence.new(0.04) }, hero)
	K.corner(hero, 14); K.stroke(hero, if hw then K.rgb(0xff8a2a) else C.accent, 1, 0.6); K.pad(hero, 26, 24, 26, 22)
	K.vlist(hero, 10)

	local tags = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 }, hero)
	K.hlist(tags, 6, Enum.VerticalAlignment.Center, true)
	local function tag(txt: string, col: Color3, onClick: () -> ())
		local b = make("TextButton", { Text = txt, Font = K.BLACK, TextSize = 10, TextColor3 = col, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 24),
			BackgroundTransparency = 0.88, BackgroundColor3 = col }, tags)
		K.corner(b, 12); K.stroke(b, col, 1, 0.6); K.pad(b, 12, 0)
		b.Activated:Connect(onClick)
	end
	if hw then
		local pk = if profile and profile.ev and profile.ev.id == X.EVENT.id then profile.ev.pumpkins or 0 else 0
		local y, mo, da = string.match(X.EVENT.to, "(%d+)-(%d+)-(%d+)")
		local days = 0
		if y then
			local endT = DateTime.fromUniversalTime(tonumber(y) :: number, tonumber(mo) :: number, tonumber(da) :: number, 23, 59, 59).UnixTimestamp
			days = math.max(0, math.ceil((endT - os.time()) / 86400))
		end
		tag("🎃  " .. spaced(string.upper(X.EVENT.name), 1) .. " · " .. pk .. " citrouille" .. (if pk > 1 then "s" else "") .. " · encore " .. days .. " j", C.pumpkin,
			function() ctx.go("profile", "Progression") end)
	end
	local feat = Modes.featured()
	if Modes.LIST[feat] then
		tag("★  " .. spaced("MODE DE LA SEMAINE : " .. string.upper(modeName(feat)) .. " · XP ×2", 1), C.gold, function()
			ctx.play = Modes.sanitize({ mode = feat, diff = ctx.play.diff }); ctx.save("play"); ctx.go("play")
		end)
	end
	local name = string.upper(ctx.player.DisplayName)
	text(hero, { LayoutOrder = 2, Font = K.BLACK, TextSize = 34, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LineHeight = 1.0,
		Text = spaced("PRÊT AU COMBAT,", 1) .. '\n<font color="#ff4655">' .. K.esc(spaced(name, 1)) .. "</font> ?" })
	K.para(hero, "Lance une partie, relève les défis du jour et débloque de nouveaux skins.", 13, C.sub, 3)
	local sel = modeName(ctx.play.mode) .. " · " .. (Modes.MAP[ctx.play.map] and Modes.MAP[ctx.play.map].n or "")
	local play = K.btn(hero, "", "primary", function() ctx.startPlay() end, { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 92), Name = "HeroPlay" })
	text(play, { Text = "▶  " .. spaced("JOUER", 3), Font = K.BLACK, TextSize = 30, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 16),
		TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, ZIndex = play.ZIndex + 1 })
	text(play, { Text = spaced(sel, 1), Font = K.BOLD, TextSize = 11, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 60),
		TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, TextTransparency = 0.15, ZIndex = play.ZIndex + 1 })
	K.cut(play, 14, if hw then K.rgb(0x170f1d) else K.rgb(0x111a2b))
	local row = make("Frame", { LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 46) }, hero)
	local q = K.btn(row, "⚡  " .. spaced("PARTIE RAPIDE", 1), "alt", function() ctx.quick(nil) end, { Size = UDim2.new(0.5, -5, 1, 0), TextSize = 14 })
	local fr = K.btn(row, "👥  " .. spaced("AVEC DES AMIS", 1), "alt", function() ctx.friends = true; ctx.go("play") end,
		{ Size = UDim2.new(0.5, -5, 1, 0), Position = UDim2.new(0.5, 5, 0, 0), TextSize = 14 })
	K.cut(q, 10, K.rgb(0x111a2b)); K.cut(fr, 10, K.rgb(0x111a2b))
	local ch = K.btn(hero, spaced("CHOISIR LE MODE ET LA CARTE", 2), "alt", function() ctx.friends = false; ctx.go("play") end,
		{ LayoutOrder = 6, Size = UDim2.new(1, 0, 0, 36), TextSize = 12 })
	K.cut(ch, 8, K.rgb(0x0f1626))

	-- saison + cadeau du jour (.lmini)
	local mini = make("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 132) }, cols[1])
	local bp = profile and profile.bp
	local tier = if bp then math.min(X.SEASON.tiers, math.floor((bp.xp or 0) / X.SEASON.xpPerTier)) else 0
	local pc = if bp then math.floor(((bp.xp or 0) % X.SEASON.xpPerTier) / X.SEASON.xpPerTier * 100) else 0
	local sc = K.card(mini, { Size = UDim2.new(0.5, -7, 1, 0), AutomaticSize = Enum.AutomaticSize.None }, function() ctx.go("profile", "Progression") end)
	K.vlist(sc, 8)
	K.h4(sc, "★ " .. string.upper(X.SEASON.name), nil, 1)
	text(sc, { LayoutOrder = 2, Font = K.BLACK, TextSize = 24, Size = UDim2.new(1, 0, 0, 28), TextWrapped = false,
		Text = "Palier " .. tier .. ' <font size="13" color="#8da0bd">/ ' .. X.SEASON.tiers .. "</font>" })
	K.bar(sc, pc / 100, { LayoutOrder = 3 })
	text(sc, { LayoutOrder = 4, TextSize = 11, TextColor3 = C.dim, Text = pc .. " % vers le palier suivant", Size = UDim2.new(1, 0, 0, 14) })
	local ds = d and d.daily
	local day = if ds then ds.day else 1
	local gc = K.card(mini, { Size = UDim2.new(0.5, -7, 1, 0), Position = UDim2.new(0.5, 7, 0, 0), AutomaticSize = Enum.AutomaticSize.None }, function() ctx.claimDaily() end)
	K.vlist(gc, 8)
	K.h4(gc, "🎁 CADEAU DU JOUR", nil, 1)
	text(gc, { LayoutOrder = 2, Font = K.BLACK, TextSize = 24, Size = UDim2.new(1, 0, 0, 28), TextWrapped = false,
		Text = "Jour " .. day .. ' <font size="13" color="#8da0bd">/ 7</font>' })
	K.bar(gc, (if ds and ds.canClaim then day - 1 else day) / 7, { LayoutOrder = 3 })
	if ds and ds.canClaim then
		K.btn(gc, spaced("RÉCUPÉRER", 1), "gold", function() ctx.claimDaily() end, { LayoutOrder = 4, Size = UDim2.fromOffset(110, 24), TextSize = 10 })
	else
		text(gc, { LayoutOrder = 4, TextSize = 11, TextColor3 = C.dim, Size = UDim2.new(1, 0, 0, 14),
			Text = "Série de " .. (if ds then ds.streak else 0) .. " jour" .. (if ds and ds.streak > 1 then "s" else "") .. " · reviens demain" })
	end

	-- ============ colonne 2 : défis ============
	local dc = K.card(cols[2], { LayoutOrder = 3 })
	K.vlist(dc, 8)
	K.h4(dc, "🎯 DÉFIS DU JOUR", "nouveaux dans " .. untilMidnight(), 0)
	for i, m in ipairs(profile and profile.missions and profile.missions.list or {}) do mission(ctx, dc, m, i, false) end
	if not profile then K.para(dc, "Chargement du profil…", 12, C.dim, 1) end
	local wc = K.card(cols[2], { LayoutOrder = 4 })
	K.vlist(wc, 8)
	K.h4(wc, "🏆 DÉFIS DE LA SEMAINE", "nouveaux dans " .. weekLeft(), 0)
	for i, m in ipairs(profile and profile.wmis and profile.wmis.list or {}) do mission(ctx, wc, m, i, true) end

	-- ============ colonne 3 : cadeaux, Premium, nouveautés ============
	local lm = make("Frame", { LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 122) }, cols[3])
	local lp = ctx.loy and ctx.loy.pending and #ctx.loy.pending or 0
	local cg = K.card(lm, { Size = UDim2.new(0.5, -7, 1, 0), AutomaticSize = Enum.AutomaticSize.None }, function() ctx.panel("gifts") end)
	if lp > 0 then
		local st = cg:FindFirstChildOfClass("UIStroke"); if st then st.Color = C.gold; st.Transparency = 0.45 end
	end
	K.vlist(cg, 6)
	K.h4(cg, "🎁 CADEAUX", nil, 1)
	text(cg, { LayoutOrder = 2, Font = K.BLACK, TextSize = 24, Size = UDim2.new(1, 0, 0, 28), TextWrapped = false,
		Text = if lp > 0 then lp .. ' <font size="13" color="#8da0bd">à récupérer</font>' else "✔" })
	if lp > 0 then
		K.btn(cg, spaced("OUVRIR", 1), "gold", function() ctx.panel("gifts") end, { LayoutOrder = 3, Size = UDim2.fromOffset(90, 24), TextSize = 10 })
	else
		K.para(cg, "Plus tu joues, plus tu gagnes", 11, C.dim, 3)
	end
	local vip = ctx.loy and ctx.loy.vip
	local cv = K.card(lm, { Size = UDim2.new(0.5, -7, 1, 0), Position = UDim2.new(0.5, 7, 0, 0), AutomaticSize = Enum.AutomaticSize.None }, function() ctx.panel("vip") end)
	local sv = cv:FindFirstChildOfClass("UIStroke"); if sv then sv.Color = C.gold; sv.Transparency = 0.67 end
	K.vlist(cv, 6)
	K.h4(cv, "👑 PREMIUM", nil, 1)
	text(cv, { LayoutOrder = 2, Font = K.BLACK, TextSize = 24, Size = UDim2.new(1, 0, 0, 28), TextColor3 = C.gold, TextWrapped = false,
		Text = if vip then "Actif" else "Découvrir" })
	K.para(cv, "Récompenses et pseudo en couleur", 11, C.dim, 3)

	local nc = K.card(cols[3], { LayoutOrder = 6 })
	K.vlist(nc, 0)
	K.h4(nc, "📰 NOUVEAUTÉS", nil, 0)
	for i, n in ipairs(MenuConfig.NEWS) do
		local go = n.go
		local item = make(if go then "TextButton" else "Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = i,
			BackgroundTransparency = 1, BackgroundColor3 = C.white }, nc)
		if go then
			(item :: any).Text = ""; (item :: any).AutoButtonColor = false
			item.MouseEnter:Connect(function() item.BackgroundTransparency = 0.97 end)
			item.MouseLeave:Connect(function() item.BackgroundTransparency = 1 end)
			;(item :: any).Activated:Connect(function()
				if go == "friends" then ctx.friends = true; ctx.go("play")
				elseif go == "boxes" then ctx.go("arsenal", "Caisses")
				elseif go == "arms" then ctx.go("arsenal", "Armes")
				elseif string.sub(go, 1, 5) == "mode:" then
					ctx.play = Modes.sanitize({ mode = string.sub(go, 6), diff = ctx.play.diff }); ctx.save("play"); ctx.go("play")
				end
			end)
		end
		K.corner(item, 8); K.pad(item, 4, 10)
		local ic = text(item, { Text = n.ic, TextSize = 20, Size = UDim2.fromOffset(34, 34), BackgroundTransparency = 0.95, BackgroundColor3 = C.white,
			TextXAlignment = Enum.TextXAlignment.Center })
		K.corner(ic, 9)
		local tx = make("Frame", { Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -46, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, item)
		K.vlist(tx, 3)
		text(tx, { LayoutOrder = 1, Font = K.BLACK, TextSize = 13, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			Text = n.t .. (if ctx.newsSeen then "" else '  <font size="9" color="#ff4655">' .. spaced("NOUVEAU", 1) .. "</font>") })
		K.para(tx, n.d, 11, C.dim, 2)
		if i < #MenuConfig.NEWS then
			make("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 10), Size = UDim2.new(1, 0, 0, 1), BackgroundTransparency = 0.95,
				BackgroundColor3 = C.white }, item)
		end
	end
end
