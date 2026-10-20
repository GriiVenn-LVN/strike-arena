--!strict
-- StarterPlayerScripts/Menu/Profile (ModuleScript) — rubrique « Profil » (src/66_progress.js, src/86_meta_ui.js, src/8W_showcase.js)
-- Progression : classement, événement d'Halloween, passe de saison (ProgressService). Les défis sont sur l'Accueil
--               (un lien y mène) : avant, ils étaient aux deux endroits.
-- Statistiques : 8 tuiles, par mode, par carte, armes les plus efficaces (profil de GetProfile)
-- Pseudo et titre (id « Style ») : pseudo, couleur de pseudo Premium (LoyaltyService), titre de profil (MenuService).
--               La traînée de balles est rangée dans Arsenal › Tenues et effets, avec les autres effets.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local X = require(ReplicatedStorage.Shared.ConfigExtra)
local Modes = require(ReplicatedStorage.Shared.Modes)
local Catalog = require(ReplicatedStorage.Shared.ShopCatalog)
local L = require(ReplicatedStorage.Shared.LoyaltyConfig)
local MenuConfig = require(ReplicatedStorage.Shared.MenuConfig)
local K = require(script.Parent.Kit)
local C = K.C
local make, text, spaced = K.make, K.text, K.spaced

local function panel(parent: Instance, order: number, props: { [string]: any }?): Frame
	local f = make("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 0.12, BackgroundColor3 = K.rgb(0x0f1626) }, parent)
	K.stroke(f, C.white, 1, 0.9); K.pad(f, 16, 14); K.vlist(f, 8)
	if props then for k, v in pairs(props) do (f :: any)[k] = v end end
	return f
end
local function rewardText(r: any): string
	local t = {}
	if r.coins then table.insert(t, "+" .. r.coins .. " pièces") end
	if r.box then table.insert(t, "1 " .. (if r.box == "prem" then "Caisse Premium" else "Caisse Standard")) end
	if r.item then table.insert(t, "Skin " .. string.lower(Config.RARITY[r.rarity or 2].name)) end
	if r.dance then table.insert(t, "Danse " .. (Config.DANCES[r.dance] and Config.DANCES[r.dance].name or r.dance)) end
	return table.concat(t, " • ")
end

-- ======================= Progression =======================
local function progression(ctx: any, sc: ScrollingFrame)
	local d = ctx.data
	local profile = d and d.profile
	if not profile then K.para(sc, "Chargement du profil…", 13, C.dim); return end
	local W = ctx.W - 56
	-- défis : sur l'Accueil (un seul endroit), avec le nombre à récupérer
	local ready, total = 0, 0
	for _, list in ipairs({ ctx.ch and ctx.ch.daily or profile.missions and profile.missions.list or {}, ctx.ch and ctx.ch.weekly or profile.wmis and profile.wmis.list or {} }) do
		for _, m in ipairs(list) do total += 1; if m.done and not m.claimed then ready += 1 end end
	end
	local top = make("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 40) }, sc)
	text(top, { Text = "🎯  Défis du jour et de la semaine : " .. total .. (if ready > 0 then '  ·  <font color="#ffd23a">' .. ready .. " à récupérer</font>" else ""),
		Size = UDim2.new(1, -230, 1, 0), TextSize = 13, Font = K.MED, TextColor3 = C.sub, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
	K.btn(top, spaced("VOIR LES DÉFIS", 1) .. "  ▸", if ready > 0 then "gold" else "alt", function() ctx.go("home") end,
		{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(210, 34), TextSize = 12 })
	-- classement
	local rank = profile.rank or { rp = 0, best = 0 }
	local rc = panel(sc, 2)
	local row = make("Frame", { Size = UDim2.new(1, 0, 0, 56), LayoutOrder = 1 }, rc)
	text(row, { Text = "🏅", TextSize = 34, Size = UDim2.fromOffset(50, 56) })
	text(row, { Text = spaced(string.upper(X.rankName(rank.rp or 0)), 2), Position = UDim2.fromOffset(56, 0), Size = UDim2.new(0.5, 0, 0, 30), Font = K.BLACK, TextSize = 24,
		TextColor3 = K.rgb(0xd08a4a), TextWrapped = false })
	text(row, { Text = ((rank.rp or 0) % X.RANK_RP_PER_DIVISION) .. " / " .. X.RANK_RP_PER_DIVISION .. " PR — meilleur : " .. X.rankName(rank.best or 0), Position = UDim2.fromOffset(56, 30),
		Size = UDim2.new(0.5, 0, 0, 14), TextSize = 11, TextColor3 = C.dim, TextWrapped = false })
	local bar = K.bar(row, ((rank.rp or 0) % X.RANK_RP_PER_DIVISION) / X.RANK_RP_PER_DIVISION, { Position = UDim2.fromOffset(56, 48), Size = UDim2.fromOffset(240, 5) })
	bar.Name = "RankBar"
	if W >= 900 then
		text(row, { Text = "Les parties compétitives, en équipe et de capture de zone contre des bots comptent pour le classement.", AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.4, 0, 1, 0), TextSize = 11, TextColor3 = C.sub })
	end
	-- événement
	local es: any = ctx.ev
	if (es and es.active) or (not es and d.eventActive) then
		local ev = make("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 0.1, BackgroundColor3 = K.rgb(0x1d1408) }, sc)
		K.stroke(ev, C.orange, 1, 0.5); K.corner(ev, 8); K.pad(ev, 16, 14); K.vlist(ev, 8)
		local own = profile.ev and profile.ev.id == X.EVENT.id
		local pk: number = if es then (es.pumpkins or 0) elseif own then profile.ev.pumpkins or 0 else 0
		local claimed = if own then profile.ev.claimed or {} else {}
		local evName: string = if es and es.name then es.name else X.EVENT.name
		local evTo: string = if es and es.to then es.to else X.EVENT.to
		text(ev, { LayoutOrder = 1, Text = "🎃  " .. spaced("ÉVÉNEMENT : " .. string.upper(evName), 2), Font = K.BLACK, TextSize = 15, Size = UDim2.new(1, 0, 0, 20) })
		local y, mo, da = string.match(evTo, "(%d+)-(%d+)-(%d+)")
		K.para(ev, "Ramasse les citrouilles cachées sur les cartes jusqu'au " .. (if y then tostring(da) .. "/" .. tostring(mo) .. "/" .. tostring(y) else evTo) .. ". Citrouilles : <b>" .. pk .. "</b>", 12, C.text, 2)
		local gr = make("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, ev)
		K.hlist(gr, 8, Enum.VerticalAlignment.Center, true)
		local goals: { any } = if es and es.goals then es.goals else X.EVENT.goals
		for i, g in ipairs(goals) do
			local got = if es and es.goals then g.done == true else table.find(claimed, g.n) ~= nil
			local label = if es and es.goals and g.text then g.text else rewardText(g)
			local chip = text(gr, { LayoutOrder = i, Text = g.n .. " → " .. label .. (if got then "  ✔" else ""), AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 32),
				TextSize = 12, Font = K.BLACK, BackgroundTransparency = 0.2, BackgroundColor3 = if got then K.rgb(0x1f3a26) else C.navy, TextColor3 = if got then C.green else C.text, TextWrapped = false })
			K.pad(chip, 12, 0); K.stroke(chip, C.white, 1, 0.9)
		end
	end
	-- passe de saison
	local bp = profile.bp or { xp = 0, premium = false, claimedFree = {}, claimedPremium = {} }
	local tier = math.min(X.SEASON.tiers, math.floor((bp.xp or 0) / X.SEASON.xpPerTier))
	local sh = make("Frame", { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 36) }, sc)
	text(sh, { Text = "🎟  " .. spaced(string.upper(X.SEASON.name) .. " — PALIER " .. tier .. " / " .. X.SEASON.tiers, 2), Font = K.BLACK, TextSize = 15, Size = UDim2.new(1, -330, 1, 0), TextWrapped = false })
	if not bp.premium then
		K.btn(sh, "🎟  Passe de saison Premium — " .. K.fmt(X.SEASON.premiumCoins) .. " 💰", "alt", function()
			local ok = ctx.call("BP_BuyPremium")
			ctx.toast(if ok then "✔ Passe Premium débloqué !" else "Pas assez de pièces (ou Robux dans la Boutique)", if ok then C.gold else C.accent)
			ctx.refresh()
		end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(310, 32), TextSize = 12 })
	else
		text(sh, { Text = "🎟 PASSE DE SAISON PREMIUM ACTIF", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 300, 1, 0), TextColor3 = C.gold, Font = K.BLACK,
			TextXAlignment = Enum.TextXAlignment.Right })
	end
	local sp = panel(sc, 5)
	K.bar(sp, ((bp.xp or 0) % X.SEASON.xpPerTier) / X.SEASON.xpPerTier, { LayoutOrder = 1 })
	text(sp, { LayoutOrder = 2, Text = "Prochain palier : " .. ((bp.xp or 0) % X.SEASON.xpPerTier) .. " / " .. X.SEASON.xpPerTier .. " XP", TextSize = 11, TextColor3 = C.sub, Size = UDim2.new(1, 0, 0, 14) })
	local strip = K.scroll(sp, { Name = "SeasonTiers", LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 150), ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X })
	K.hlist(strip, 8, Enum.VerticalAlignment.Top)
	for t = 1, X.SEASON.tiers do
		local reached = t <= tier
		local f = make("Frame", { LayoutOrder = t, Size = UDim2.fromOffset(132, 138), BackgroundTransparency = if reached then 0.1 else 0.4, BackgroundColor3 = C.card }, strip)
		K.corner(f, 6); K.stroke(f, if reached then C.gold else C.white, 1, if reached then 0.5 else 0.92)
		text(f, { Text = "PALIER " .. t, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 6), TextSize = 10, Font = K.BLACK, TextColor3 = if reached then C.gold else C.dim,
			TextXAlignment = Enum.TextXAlignment.Center })
		for j, prem in ipairs({ false, true }) do
			local r = X.bpReward(t, prem)
			local list = if prem then bp.claimedPremium or {} else bp.claimedFree or {}
			local got = table.find(list, t) ~= nil
			local y = 26 + (j - 1) * 56
			text(f, { Text = (if prem then "⭐ " else "") .. rewardText(r), Position = UDim2.fromOffset(6, y), Size = UDim2.new(1, -12, 0, 26), TextSize = 10, Font = K.MED,
				TextColor3 = if prem then C.gold else C.text, TextXAlignment = Enum.TextXAlignment.Center })
			if got then
				text(f, { Text = "✔ REÇU", Position = UDim2.fromOffset(0, y + 28), Size = UDim2.new(1, 0, 0, 20), TextSize = 10, TextColor3 = C.green, Font = K.BLACK,
					TextXAlignment = Enum.TextXAlignment.Center })
			elseif reached and (not prem or bp.premium) then
				K.btn(f, "RÉCUPÉRER", "gold", function()
					local res = ctx.call("BP_Claim", t, prem)
					if res then ctx.toast("✔ Palier " .. t .. " : " .. rewardText(res.reward or r), C.gold) end
					ctx.refresh()
				end, { Position = UDim2.fromOffset(14, y + 28), Size = UDim2.new(1, -28, 0, 22), TextSize = 10 })
			else
				text(f, { Text = "🔒", Position = UDim2.fromOffset(0, y + 28), Size = UDim2.new(1, 0, 0, 20), TextSize = 12, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Center })
			end
		end
	end
end

-- ======================= Statistiques =======================
local function statistics(ctx: any, sc: ScrollingFrame)
	local profile = ctx.data and ctx.data.profile
	local s = profile and profile.stats or {}
	local W = ctx.W - 56
	local function n(k: string): number return tonumber(s[k]) or 0 end
	local hasMatches = n("matches") > 0
	local tiles: { { any } } = {
		{ tostring(n("matches")), "PARTIES", C.blue },
		{ if hasMatches then math.floor(n("wins") / n("matches") * 100 + 0.5) .. " %" else "—", "VICTOIRES", C.green },
		{ if n("deaths") > 0 or n("kills") > 0 then string.format("%.2f", n("kills") / math.max(1, n("deaths"))) else "—", "RATIO K/D", C.accent },
		{ if n("shots") > 0 then math.floor(n("hits") / n("shots") * 100 + 0.5) .. " %" else "—", "PRÉCISION", C.gold },
		{ if n("kills") > 0 then math.floor(n("hs") / n("kills") * 100 + 0.5) .. " %" else "—", "HEADSHOTS", K.rgb(0xff7a3a) },
		{ if hasMatches then tostring(math.floor(n("dmg") / n("matches"))) else "—", "DÉGÂTS / PARTIE", C.violet },
		{ tostring(n("bestStreak")), "MEILLEURE SÉRIE", C.gold },
		{ string.format("%dh%02d", n("seconds") // 3600, (n("seconds") % 3600) // 60), "TEMPS DE JEU", C.blue },
	}
	local g = make("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, sc)
	local per = if W >= 1000 then 4 else 2
	K.grid(g, UDim2.new(1 / per, -9, 0, 80), 12)
	for i, t in ipairs(tiles) do
		local f = make("Frame", { LayoutOrder = i, BackgroundTransparency = 0.1, BackgroundColor3 = K.rgb(0x0f1626) }, g)
		K.stroke(f, C.white, 1, 0.9)
		make("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 3), BackgroundTransparency = 0, BackgroundColor3 = t[3] }, f)
		text(f, { Text = t[1], Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 32), Font = K.BLACK, TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center })
		text(f, { Text = spaced(t[2], 2), Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 14), TextSize = 10, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Center })
	end
	local row = make("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, sc)
	local two = W >= 1000
	if two then K.hlist(row, 14, Enum.VerticalAlignment.Top) else K.vlist(row, 12) end
	local left = panel(row, 1, { Size = UDim2.new(if two then 0.5 else 1, if two then -7 else 0, 0, 0) })
	local function line(parent: Instance, order: number, name: string, rec: any)
		local r = make("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 20) }, parent)
		text(r, { Text = name, Size = UDim2.new(0.25, 0, 1, 0), TextSize = 12, Font = K.MED, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
		local m = if typeof(rec) == "table" then tonumber(rec.m) or 0 else 0
		local w = if typeof(rec) == "table" then tonumber(rec.w) or 0 else 0
		local b = K.bar(r, if m > 0 then w / m else 0, { Position = UDim2.new(0.27, 0, 0.5, -3), Size = UDim2.new(0.6, 0, 0, 6) }, C.green, C.green)
		b.Name = "Bar"
		text(r, { Text = if m > 0 then w .. " / " .. m .. " V" else "—", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.12, 0, 1, 0),
			TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.sub })
	end
	K.label(left, "PAR MODE", 0, C.dim)
	local o = 0
	for _, grp in ipairs(Modes.GROUPS) do
		for _, id in ipairs(grp[2]) do o += 1; line(left, o, Modes.LIST[id].n, s.byMode and s.byMode[id]) end
	end
	o += 1; K.label(left, "PAR CARTE", o, C.dim)
	for _, m in ipairs(Modes.MAPS) do o += 1; line(left, o, m.n, s.byMap and s.byMap[m.id]) end
	local right = panel(row, 2, { Size = UDim2.new(if two then 0.5 else 1, if two then -7 else 0, 0, 0) })
	K.label(right, "ARMES LES PLUS EFFICACES (éliminations)", 0, C.dim)
	local ws = {}
	for k, v in pairs(s.byWeapon or {}) do if Config.WEAPONS[k] and (tonumber(v) or 0) > 0 then table.insert(ws, { k, tonumber(v) or 0 }) end end
	table.sort(ws, function(a, b) return a[2] > b[2] end)
	if #ws == 0 then K.para(right, "Joue des parties pour voir tes armes favorites.", 12, C.sub, 1) end
	for i = 1, math.min(8, #ws) do
		local r = make("Frame", { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 24) }, right)
		text(r, { Text = i .. ". " .. Config.WEAPONS[ws[i][1]].name, Size = UDim2.new(0.4, 0, 1, 0), TextSize = 13, Font = K.BLACK, TextWrapped = false })
		K.bar(r, ws[i][2] / ws[1][2], { Position = UDim2.new(0.42, 0, 0.5, -3), Size = UDim2.new(0.45, 0, 0, 6) })
		text(r, { Text = tostring(ws[i][2]), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.12, 0, 1, 0), TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Right })
	end
end

-- ======================= Style =======================
local function style(ctx: any, sc: ScrollingFrame)
	local d = ctx.data
	local profile = d and d.profile
	local player = ctx.player
	local function chips(order: number): Frame
		local f = make("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, sc)
		K.hlist(f, 8, Enum.VerticalAlignment.Center, true)
		return f
	end
	-- choix avec niveau requis (sous-texte gris quand c'est verrouillé)
	local function choice(parent: Instance, order: number, label: string, on: boolean, lockText: string?, cb: () -> (), color: Color3?)
		local b = K.chip(parent, if lockText then label .. '\n<font size="9" color="#6f819e">' .. lockText .. "</font>" else label, on, cb,
			{ LayoutOrder = order, Size = UDim2.fromOffset(0, if lockText then 46 else 40), TextColor3 = color or (if lockText then C.dim else C.white) })
		if lockText then b.BackgroundTransparency = 0.6 end
	end
	K.label(sc, "PSEUDO", 1)
	local nb = text(sc, { LayoutOrder = 2, Text = "  " .. K.esc(player.DisplayName) .. '   <font color="#6f819e" size="11">(ton nom d\'affichage Roblox)</font>', Size = UDim2.fromOffset(460, 40),
		BackgroundTransparency = 0.1, BackgroundColor3 = K.rgb(0x111a2e), TextSize = 15, TextWrapped = false })
	K.stroke(nb, C.white, 1, 0.88)
	-- couleur de pseudo (Premium)
	local loy = ctx.loy
	K.label(sc, "COULEUR DU PSEUDO (PREMIUM)", 3)
	local cr = chips(4)
	for i, col in ipairs(L.VIP.colors) do
		local on = loy ~= nil and loy.vip and loy.vipColor == col.id
		choice(cr, i, "⭐ " .. col.name, on, if loy and loy.vip then nil else "Premium", function()
			if not (loy and loy.vip) then ctx.panel("vip"); return end
			ctx.call("Vip_SetColor", col.id); ctx.refresh()
		end, col.color)
	end
	-- titre de profil
	K.label(sc, "TITRE DE PROFIL", 5)
	local tr = chips(6)
	local cur = profile and profile.cosmetics and profile.cosmetics.title or ""
	local level = d and d.level or 1
	local function setTitle(id: string)
		if ctx.call("SetTitle", id) then ctx.toast(if id == "" then "Titre retiré" else "✔ Titre équipé", C.green) end
		ctx.refresh()
	end
	choice(tr, 0, "—", cur == "", nil, function() setTitle("") end)
	for i, t in ipairs(MenuConfig.TITLES) do
		local locked = level < t.lvl
		choice(tr, i, t.n, cur == t.id, if locked then "Niveau " .. t.lvl else nil, function()
			if locked then ctx.toast("Débloqué au niveau " .. t.lvl, C.gold); return end
			setTitle(t.id)
		end)
	end
	for i, id in ipairs(loy and loy.titles or {}) do
		if L.TITLES[id] then choice(tr, 100 + i, L.TITLES[id], cur == id, nil, function() setTitle(id) end, C.gold) end
	end
	K.para(sc, "La traînée de balles, les tenues, les danses et les effets se choisissent dans <b>Arsenal › Tenues et effets</b>.", 12, C.dim, 9)
end

return function(ctx: any, body: Frame, sub: string?)
	local sc = K.scroll(body, { Name = "Profile" .. tostring(sub) })
	K.vlist(sc, 14); K.pad(sc, 0, 0, 8, 12)
	if sub == "Statistiques" then statistics(ctx, sc)
	elseif sub == "Style" then style(ctx, sc)
	else progression(ctx, sc) end
end
