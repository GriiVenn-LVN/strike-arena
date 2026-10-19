--!strict
-- StarterPlayerScripts/Menu/Settings (ModuleScript) — rubrique « Réglages » (src/85_menu.js, src/68_access.js)
-- Général, Viseur, Son, Accessibilité : Menu/Options (le même panneau que dans la pause, réglages appliqués tout de suite
-- et gardés dans le profil). Touches : les commandes du jeu Roblox.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MenuConfig = require(ReplicatedStorage.Shared.MenuConfig)
local K = require(script.Parent.Kit)
local Options = require(script.Parent.Options)
local C = K.C
local make, text = K.make, K.text

local function keys(ctx: any, sc: ScrollingFrame)
	local W = ctx.W - 56
	K.para(sc, "Les commandes du jeu Roblox (clavier · manette). Sur téléphone, les boutons tactiles s'affichent à l'écran.", 12, C.sub, 0)
	local g = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 }, sc)
	K.grid(g, UDim2.new(if W >= 1000 then 0.5 else 1, -10, 0, 42), 8)
	for i, k in ipairs(MenuConfig.KEYS) do
		local r = make("Frame", { LayoutOrder = i, BackgroundTransparency = 0.1, BackgroundColor3 = K.rgb(0x111a2e) }, g)
		K.stroke(r, C.white, 1, 0.92); K.pad(r, 12, 0, 8, 0)
		text(r, { Text = k[1], Size = UDim2.new(1, -300, 1, 0), TextSize = 13, Font = K.MED, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
		for j = 1, 2 do
			local box = text(r, { Text = k[j + 1], AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, if j == 1 then -126 else 0, 0.5, 0), Size = UDim2.fromOffset(if j == 1 then 160 else 118, 28),
				BackgroundTransparency = 0, BackgroundColor3 = K.rgb(0x1a2744), TextColor3 = if j == 1 then C.gold else C.blue, Font = K.BLACK, TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
			K.stroke(box, C.white, 1, 0.9)
		end
	end
end

return function(ctx: any, body: Frame, sub: string?)
	local sc = K.scroll(body, { Name = "Settings" .. tostring(sub) })
	K.vlist(sc, 14); K.pad(sc, 0, 4, 8, 12)
	if sub == "Touches" then keys(ctx, sc)
	else Options.build(sc, ctx.W - 56, sub, ctx.render) end
end
