--!strict
-- StarterPlayerScripts/Menu/CardPicker (ModuleScript, client) — Profil › Pseudo et titre : CARTE DE JOUEUR.
-- Aperçu de la carte (Shared/PlayerCard), puis les bannières et les emblèmes : débloqués = cliquables, verrouillés = grisés
-- avec leur condition. Le serveur (remote « Career », action « card ») vérifie le déblocage ; la carte se voit dans la kill-cam.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerCard = require(ReplicatedStorage.Shared.PlayerCard)
local K = require(script.Parent.Kit)
local Fx = require(script.Parent.Fx)
local Career = require(script.Parent.Career)
local C = K.C
local make, text = K.make, K.text

return function(ctx: any, sc: Instance, order: number)
	K.label(sc, "CARTE DE JOUEUR (VISIBLE DANS LA KILL-CAM)", order)
	if not Career.ready(ctx, sc, order + 1) then return end
	local cd = ctx.career
	local v: PlayerCard.View = cd.view
	local cur = cd.card or {}
	local selB: string = ctx.cardB or cur.b or "recrue"
	local selE: string = ctx.cardE or cur.e or "cible"
	local box = make("Frame", { LayoutOrder = order + 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, sc)
	K.vlist(box, 10)
	-- aperçu + bouton équiper
	local narrow = ctx.W - 56 < 680   -- écran étroit : bouton sous l'aperçu
	local top = make("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, if narrow then 130 else 96) }, box)
	local title = ctx.player:GetAttribute("Title")
	PlayerCard.render(top, { banner = selB, emblem = selE, name = ctx.player.DisplayName, title = if typeof(title) == "string" then title else nil,
		level = ctx.data and ctx.data.level, size = if narrow then 300 else 400 })
	local changed = selB ~= cur.b or selE ~= cur.e
	K.btn(top, if changed then "✔  " .. K.spaced("ÉQUIPER CETTE CARTE", 1) else "✔  " .. K.spaced("CARTE ÉQUIPÉE", 1), if changed then "primary" else "alt", function()
		if not changed then return end
		local res = ctx.call("Career", "card", selB, selE)
		if typeof(res) == "table" and res.ok then
			cd.card = { b = selB, e = selE }; ctx.cardB = nil; ctx.cardE = nil
			Fx.pop("🪪  Nouvelle carte de joueur équipée", C.gold)
			ctx.render()
		else
			ctx.toast("❌ " .. tostring(typeof(res) == "table" and res.err or "Impossible d'équiper cette carte"), C.accent)
		end
	end, { Position = if narrow then UDim2.fromOffset(0, 82) else UDim2.fromOffset(416, 24), Size = UDim2.fromOffset(230, 44), TextSize = 12 })
	-- bannières
	K.label(box, "BANNIÈRES", 2, C.dim)
	local g = make("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, box)
	K.hlist(g, 8, Enum.VerticalAlignment.Top, true)
	for i, b in ipairs(PlayerCard.BANNERS) do
		local open = PlayerCard.open(b.need, v)
		local cell = make("TextButton", { LayoutOrder = i, Text = "", Size = UDim2.fromOffset(170, 62), BackgroundTransparency = 1, AutoButtonColor = false }, g)
		local mini = PlayerCard.render(cell, { banner = b.id, emblem = selE, name = b.n, size = 170 })
		mini.Position = UDim2.fromOffset(0, 0)
		if not open then
			for _, d in ipairs(mini:GetDescendants()) do if d:IsA("TextLabel") then d.TextTransparency = 0.6 end end
			local lock = text(cell, { Text = "🔒 " .. PlayerCard.needText(b.need), Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 18), TextSize = 10,
				TextColor3 = C.dim, BackgroundTransparency = 0.25, BackgroundColor3 = C.deep, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3 })
			K.corner(lock, 4)
		else
			text(cell, { Text = b.n, Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 16), TextSize = 10, TextColor3 = if b.id == selB then C.gold else C.sub,
				TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, ZIndex = 3 })
		end
		if b.id == selB then K.stroke(cell, C.gold, 2, 0) end
		K.juice(cell, 0.03)
		cell.Activated:Connect(function()
			if not open then ctx.toast("🔒 " .. PlayerCard.needText(b.need), C.gold); return end
			ctx.cardB = b.id; ctx.cardE = selE; ctx.render()
		end)
	end
	-- emblèmes
	K.label(box, "EMBLÈMES", 4, C.dim)
	local eg = make("Frame", { LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, box)
	K.hlist(eg, 8, Enum.VerticalAlignment.Center, true)
	for i, e in ipairs(PlayerCard.EMBLEMS) do
		local open = PlayerCard.open(e.need, v)
		local label = e.ic .. "  " .. e.n .. (if open then "" else '\n<font size="9" color="#6f819e">🔒 ' .. PlayerCard.needText(e.need) .. "</font>")
		local chip = K.chip(eg, label, e.id == selE, function()
			if not open then ctx.toast("🔒 " .. PlayerCard.needText(e.need), C.gold); return end
			ctx.cardB = selB; ctx.cardE = e.id; ctx.render()
		end, { LayoutOrder = i, Size = UDim2.fromOffset(0, if open then 40 else 46), TextColor3 = if open then C.white else C.dim })
		if not open then chip.BackgroundTransparency = 0.6 end
	end
end
