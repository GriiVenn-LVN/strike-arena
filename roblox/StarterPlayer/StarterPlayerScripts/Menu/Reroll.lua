--!strict
-- StarterPlayerScripts/Menu/Reroll (ModuleScript, client) — défis renouvelables, branché par Kit.mission :
--   • bouton « CHANGER » sur chaque défi du jour pas encore terminé (1 changement gratuit par jour, ensuite des pièces :
--     prix et nombre restant donnés par le serveur, GetChallenges.reroll ; un changement payant se confirme d'un 2e clic) ;
--   • la carte s'efface, le serveur tire un autre défi (remote RerollChallenge, tout est vérifié là-bas), puis la nouvelle
--     carte arrive en rebondissant (Menu/Fx) ;
--   • étiquette « DÉFI D'ARME DU JOUR » sur le 3e défi, reflet doré sur les défis prêts à récupérer.
local K = require(script.Parent.Kit)
local Fx = require(script.Parent.Fx)
local C = K.C

return function(ctx: any, card: Frame, top: Frame, m: any, i: number, weekly: boolean)
	local idx = m.index or i
	local key = (if weekly then "w" else "d") .. idx
	if ctx.fxIn == key then ctx.fxIn = nil; Fx.flipIn(card) end
	if m.weapon then
		K.text(card, { LayoutOrder = 0, Text = "🔫  " .. K.spaced("DÉFI D'ARME DU JOUR", 1), Font = K.BLACK, TextSize = 9, TextColor3 = C.gold,
			Size = UDim2.new(1, 0, 0, 12), TextWrapped = false })
	end
	if m.done and not m.claimed then Fx.sheen(card, 2.6) end
	if weekly or m.done or m.claimed then return end
	local rr = ctx.ch and ctx.ch.reroll
	if not rr or (rr.left or 0) <= 0 then return end
	local cost: number = rr.cost or 0
	local label = if cost <= 0 then "🔄  " .. K.spaced("CHANGER", 1) .. '  <font color="#7dff9f">gratuit</font>'
		else "🔄  " .. K.spaced("CHANGER", 1) .. '  <font color="#ffd23a">' .. cost .. " 🪙</font>"
	local armed = false
	local b: TextButton
	b = K.btn(top, label, "alt", function()
		if ctx.rerolling then return end
		-- payant : un premier clic demande confirmation (3 s)
		if cost > 0 and not armed then
			armed = true
			b.Text = K.spaced("CONFIRMER", 1) .. '  <font color="#ffd23a">−' .. cost .. " 🪙</font>"
			K.setBtnColor(b, K.rgb(0x7a3dff))
			task.delay(3, function()
				if armed and b.Parent then armed = false; b.Text = label; K.setBtnColor(b, K.rgb(0x1a2540)) end
			end)
			return
		end
		armed = false
		ctx.rerolling = true
		Fx.flipOut(card)
		local res = ctx.call("RerollChallenge", idx)
		ctx.rerolling = false
		if typeof(res) == "table" and res.ok then
			ctx.fxIn = key
			Fx.pop("🔄  Nouveau défi : " .. tostring(res.text), C.gold)
			if (res.cost or 0) > 0 then Fx.coins(-(res.cost :: number), b) end
			ctx.refresh()
		else
			ctx.toast("❌ " .. tostring(typeof(res) == "table" and res.err or "Impossible de changer ce défi"), C.accent)
		end
	end, { Name = "Reroll", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(104, 24), TextSize = 9 })
end
