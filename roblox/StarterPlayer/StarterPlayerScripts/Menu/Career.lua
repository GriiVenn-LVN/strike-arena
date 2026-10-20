--!strict
-- StarterPlayerScripts/Menu/Career (ModuleScript, client) — Profil › Statistiques, sous les statistiques générales :
--   • records du stand d'entraînement (score, précision, temps de réaction moyen et meilleur) ;
--   • carrière par arme : éliminations, tirs à la tête, % de têtes, et la MAÎTRISE (camos Or, Diamant, Matière noire,
--     Shared/Mastery) avec sa progression et les boutons pour poser un camo débloqué sur l'arme.
-- Les données viennent du remote « Career » (CareerService), gardées dans ctx.career ; tout est vérifié côté serveur.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Mastery = require(ReplicatedStorage.Shared.Mastery)
local K = require(script.Parent.Kit)
local Fx = require(script.Parent.Fx)
local C = K.C
local make, text, spaced = K.make, K.text, K.spaced

local Career = {}

-- charge (ou recharge) la carrière ; cb après réception
function Career.fetch(ctx: any, cb: (() -> ())?)
	if ctx.careerBusy then return end
	ctx.careerBusy = true
	task.spawn(function()
		local res = ctx.call("Career", "get")
		ctx.careerBusy = false
		if typeof(res) == "table" then
			ctx.career = res; ctx.careerT = os.clock()
			if cb then cb() end
		end
	end)
end
-- données prêtes ? sinon un message et un rendu dès qu'elles arrivent
function Career.ready(ctx: any, sc: Instance, order: number): boolean
	if ctx.career then
		if os.clock() - (ctx.careerT or 0) > 15 then Career.fetch(ctx) end   -- rafraîchit en douce (la page suivante l'affichera)
		return true
	end
	K.para(sc, "Chargement de la carrière…", 12, C.dim, order)
	Career.fetch(ctx, function() if ctx.render and ctx.tab == "profile" then ctx.render() end end)
	return false
end

local function panel(parent: Instance, order: number): Frame
	local f = make("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 0.12,
		BackgroundColor3 = K.rgb(0x0f1626) }, parent)
	K.stroke(f, C.white, 1, 0.9); K.pad(f, 16, 14); K.vlist(f, 8)
	return f
end
local function sec(x: any): string
	if typeof(x) ~= "number" then return "—" end
	return (string.gsub(string.format("%.2f", x), "%.", ",")) .. " s"
end

function Career.stats(ctx: any, sc: Instance, order: number)
	if not Career.ready(ctx, sc, order) then return end
	local cd = ctx.career
	local career = cd.career or {}
	local diamonds = Mastery.diamonds(career)
	local W = ctx.W - 56
	-- ---------- stand d'entraînement ----------
	local tr = cd.train or {}
	local tp = panel(sc, order)
	K.label(tp, "🎯 STAND D'ENTRAÎNEMENT · RECORDS", 0, C.dim)
	local row = make("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 58) }, tp)
	type Cell = { v: string, n: string, c: Color3 }
	local cells: { Cell } = { { v = tostring(tr.score or "—"), n = "MEILLEUR SCORE", c = C.gold }, { v = if tr.acc then tr.acc .. " %" else "—", n = "PRÉCISION", c = C.green },
		{ v = sec(tr.rt), n = "RÉACTION MOYENNE", c = C.blue }, { v = sec(tr.rtBest), n = "MEILLEURE RÉACTION", c = C.violet } }
	for j, c in ipairs(cells) do
		local cell = make("Frame", { Position = UDim2.new((j - 1) / 4, 4, 0, 0), Size = UDim2.new(0.25, -8, 1, 0), BackgroundTransparency = 0.6, BackgroundColor3 = C.navy }, row)
		K.corner(cell, 6)
		text(cell, { Text = c.v, Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 26), Font = K.BLACK, TextSize = 22, TextColor3 = c.c,
			TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false })
		text(cell, { Text = spaced(c.n, 1), Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 0, 14), TextSize = 9, TextColor3 = C.dim,
			TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false })
	end
	K.para(tp, "Mode Entraînement : les cibles qui réapparaissent mesurent ton temps de réaction (moyenne des 10 dernières).", 11, C.dim, 2)

	-- ---------- maîtrise et carrière par arme ----------
	local mp = panel(sc, order + 1)
	local nGold, nDark = 0, 0
	for k, rec in pairs(career) do
		if Mastery.eligible(Config.WEAPONS, k) then
			local l = Mastery.level(rec, diamonds)
			if l >= 1 then nGold += 1 end
			if l >= 3 then nDark += 1 end
		end
	end
	K.label(mp, "🥇 MAÎTRISE D'ARMES ET CARRIÈRE", 0, C.dim)
	K.para(mp, "Or : 100 éliminations et 30 tirs à la tête avec l'arme · Diamant : 300 et 120 · Matière noire : le Diamant sur 5 armes."
		.. '   <font color="#ffd23a">Or ' .. nGold .. '</font>  ·  <font color="#96e1ff">Diamant ' .. diamonds .. '</font>  ·  <font color="#be6eff">Matière noire ' .. nDark .. "</font>", 11, C.sub, 1)
	type Row = { key: string, name: string, k: number, hs: number }
	local list: { Row } = {}
	for k, w in pairs(Config.WEAPONS) do
		if Mastery.eligible(Config.WEAPONS, k) then
			local rec = career[k]
			table.insert(list, { key = k, name = w.name, k = if rec then rec.k or 0 else 0, hs = if rec then rec.hs or 0 else 0 })
		end
	end
	table.sort(list, function(a: Row, b: Row): boolean
		if a.k ~= b.k then return a.k > b.k end
		return a.name < b.name
	end)
	local all = ctx.careerAll == true
	local camos = cd.camos or {}
	for j, it in ipairs(list) do
		if not all and j > 8 then break end
		local rec = career[it.key]
		local lvl = Mastery.level(rec, diamonds)
		local goal, pk, ph = Mastery.nextGoal(rec, diamonds)
		-- écran étroit : les boutons des camos passent sur une 2e ligne
		local narrow = W < 900
		local r = make("Frame", { LayoutOrder = 10 + j, Size = UDim2.new(1, 0, 0, if narrow then 72 else 40), BackgroundTransparency = if j % 2 == 0 then 0.97 else 1,
			BackgroundColor3 = C.white }, mp)
		K.corner(r, 6)
		local ln = make("Frame", { Size = UDim2.new(if narrow then 1.45 else 1, 0, 0, 40) }, r)   -- la ligne principale (plus large : sans la colonne des camos)
		local badge = if lvl >= 3 then "🌌" elseif lvl == 2 then "💎" elseif lvl == 1 then "🥇" else "·"
		text(ln, { Text = badge .. "  " .. it.name, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0.22, 0, 1, 0), Font = K.BLACK, TextSize = 13, TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd })
		local pct = if it.k > 0 then math.floor(it.hs / it.k * 100 + 0.5) .. " %" else "—"
		text(ln, { Text = it.k .. ' <font color="#8da0bd">élim.</font>  ·  ' .. it.hs .. ' <font color="#8da0bd">têtes</font>  ·  ' .. pct, Position = UDim2.new(0.23, 0, 0, 0),
			Size = UDim2.new(0.25, 0, 1, 0), TextSize = 12, Font = K.MED, TextWrapped = false })
		-- progression vers le palier suivant (la plus lente des deux jauges)
		if goal then
			local frac = math.min(pk, ph)
			local b = K.bar(ln, frac, { Position = UDim2.new(0.49, 0, 0.5, -9), Size = UDim2.new(0.18, 0, 0, 5) }, goal.color, goal.color:Lerp(C.white, 0.4))
			b.Name = "MasteryBar"
			text(ln, { Text = goal.name .. " : " .. math.min(it.k, goal.kills) .. "/" .. goal.kills .. " · " .. math.min(it.hs, goal.hs) .. "/" .. goal.hs
				.. (if goal.needDiamonds and diamonds < goal.needDiamonds then " · " .. diamonds .. "/" .. goal.needDiamonds .. " 💎" else ""),
				Position = UDim2.new(0.49, 0, 0.5, -2), Size = UDim2.new(0.2, 0, 0, 14), TextSize = 10, TextColor3 = C.dim, TextWrapped = false })
		else
			text(ln, { Text = "Maîtrise complète", Position = UDim2.new(0.49, 0, 0, 0), Size = UDim2.new(0.2, 0, 1, 0), TextSize = 11, TextColor3 = C.violet, Font = K.BLACK })
		end
		-- camos débloqués : un bouton par camo (posé = surligné ; un 2e clic le retire)
		local bx = make("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.new(0.31, 0, 0, 28) }, r)
		local lay = K.hlist(bx, 6); lay.HorizontalAlignment = Enum.HorizontalAlignment.Right
		local cur = camos[it.key]
		for ti, t in ipairs(Mastery.TIERS) do
			if lvl >= ti then
				local on = cur == t.camo
				local cb = K.chip(bx, (if on then "✔ " else "") .. t.name, on, function()
					local res = ctx.call("Career", "camo", it.key, if on then "" else t.camo)
					if typeof(res) == "table" and res.ok then
						cd.camos = res.camos or cd.camos
						Fx.pop((if on then "Camo retiré : " else "Camo " .. t.name .. " posé sur ") .. it.name, t.color)
						ctx.render()
					else
						ctx.toast("❌ " .. tostring(typeof(res) == "table" and res.err or "Impossible"), C.accent)
					end
				end, { LayoutOrder = ti, Size = UDim2.fromOffset(0, 26), TextSize = 11 }, t.color:Lerp(Color3.new(0, 0, 0), 0.35))
				cb.TextColor3 = if on then C.white else t.color
			end
		end
		if narrow then
			bx.AnchorPoint = Vector2.new(0, 1); bx.Position = UDim2.new(0, 8, 1, -4); bx.Size = UDim2.new(1, -16, 0, 26)
			lay.HorizontalAlignment = Enum.HorizontalAlignment.Left
		end
	end
	if #list > 8 then
		K.btn(mp, if all then "▴  Moins d'armes" else "▾  Toutes les armes (" .. #list .. ")", "ghost", function() ctx.careerAll = not all; ctx.render() end,
			{ LayoutOrder = 100, Size = UDim2.new(1, 0, 0, 30), TextSize = 12 })
	end
end

return Career
