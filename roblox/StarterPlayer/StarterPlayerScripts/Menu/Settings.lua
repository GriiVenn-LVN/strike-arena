--!strict
-- StarterPlayerScripts/Menu/Settings (ModuleScript) — rubrique « Réglages » (src/85_menu.js, src/68_access.js)
-- Général : qualité graphique, sensibilité, sensibilité en visée, champ de vision, volume (appliqués par MainMenu via ClientState,
-- gardés dans le profil par MenuService). Touches : les commandes du jeu Roblox. Accessibilité : AccessibilityController (AccessSet).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local MenuConfig = require(ReplicatedStorage.Shared.MenuConfig)
local K = require(script.Parent.Kit)
local C = K.C
local make, text, spaced = K.make, K.text, K.spaced

local QUALITY = { "Basse", "Moyenne", "Haute" }

local function general(ctx: any, sc: ScrollingFrame)
	local o = ctx.opts
	local W = ctx.W - 56
	local two = W >= 960
	local cols = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 }, sc)
	if two then K.hlist(cols, 36, Enum.VerticalAlignment.Top) else K.vlist(cols, 14) end
	local cw = if two then math.min(440, (W - 40) // 2) else W - 10
	local a = make("Frame", { Size = UDim2.fromOffset(cw, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 }, cols)
	local b = make("Frame", { Size = UDim2.fromOffset(cw, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 }, cols)
	K.vlist(a, 10); K.vlist(b, 10)
	local function changed() ctx.applyOpts(); ctx.save("opts") end
	K.label(a, "QUALITÉ GRAPHIQUE", 1)
	local qr = make("Frame", { Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 2 }, a)
	K.hlist(qr, 6)
	for i, q in ipairs(QUALITY) do
		K.chip(qr, q, o.quality == i, function() o.quality = i; changed(); ctx.render() end, { LayoutOrder = i })
	end
	K.para(a, "Basse : sans ombres ni halos. Moyenne : ombres. Haute : ombres, halos et rayons de soleil. (Le niveau de détail Roblox se règle aussi dans le menu Échap.)", 11, C.dim, 3)
	K.slider(a, "SENSIBILITÉ EN VISÉE", 0.2, 2, 0.05, o.aimSens, function(v) return string.format("×%.2f", v) end, function(v) o.aimSens = v; changed() end, 4)
	K.slider(a, "VOLUME", 0, 1, 0.05, o.vol, function(v) return math.floor(v * 100 + 0.5) .. "%" end, function(v) o.vol = v; changed() end, 5)
	K.slider(b, "SENSIBILITÉ", 0.1, 4, 0.05, o.sens, function(v) return string.format("%.2f", v) end, function(v) o.sens = v; changed() end, 1)
	K.slider(b, "CHAMP DE VISION", 60, 110, 1, o.fov, function(v) return math.floor(v) .. "°" end, function(v) o.fov = v; changed() end, 2)
	K.btn(sc, spaced("RÉTABLIR PAR DÉFAUT", 1), "dark", function()
		o.fov = 70; o.sens = 1; o.aimSens = 1; o.vol = 0.7; o.quality = 3
		changed(); ctx.render()
	end, { LayoutOrder = 2, Size = UDim2.fromOffset(220, 32), TextSize = 11 })
end

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

local function access(ctx: any, sc: ScrollingFrame)
	local player = ctx.player
	local ps = player:FindFirstChild("PlayerScripts")
	local ac = ps and ps:FindFirstChild("AccessibilityController")
	local ev = ac and ac:FindFirstChild("AccessSet")
	local cur: { [string]: any } = { colorblind = "none", subtitles = false, hudScale = 1, shake = 1 }
	local raw = player:GetAttribute("Access")
	if typeof(raw) == "string" then
		local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and typeof(data) == "table" then for k, v in pairs(data) do cur[k] = v end end
	end
	local function set(key: string, value: any)
		if ev and ev:IsA("BindableEvent") then ev:Fire(key, value) else ctx.toast("Accessibilité indisponible", C.accent) end
	end
	K.label(sc, "MODE DALTONIEN", 1)
	local r = make("Frame", { Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 2 }, sc)
	K.hlist(r, 6)
	for i, cb in ipairs({ { "none", "Aucun" }, { "deut", "Deutéranopie" }, { "prot", "Protanopie" }, { "trit", "Tritanopie" } }) do
		K.chip(r, cb[2], cur.colorblind == cb[1], function() set("colorblind", cb[1]); task.wait(0.1); ctx.render() end, { LayoutOrder = i })
	end
	K.label(sc, "SOUS-TITRES DES SONS (tirs entendus, avec la direction)", 3)
	local r2 = make("Frame", { Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 4 }, sc)
	K.hlist(r2, 6)
	K.chip(r2, "Affichés", cur.subtitles == true, function() set("subtitles", true); task.wait(0.1); ctx.render() end, { LayoutOrder = 1 })
	K.chip(r2, "Masqués", cur.subtitles ~= true, function() set("subtitles", false); task.wait(0.1); ctx.render() end, { LayoutOrder = 2 })
	local box = make("Frame", { Size = UDim2.fromOffset(440, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 5 }, sc)
	K.vlist(box, 10)
	K.slider(box, "TAILLE DE L'INTERFACE", 0.7, 1.4, 0.05, tonumber(cur.hudScale) or 1, function(v) return string.format("×%.2f", v) end, function(v) set("hudScale", v) end, 1)
	K.slider(box, "SECOUSSES DE L'ÉCRAN", 0, 1, 0.1, tonumber(cur.shake) or 1, function(v) return math.floor(v * 100 + 0.5) .. "%" end, function(v) set("shake", v) end, 2)
end

return function(ctx: any, body: Frame, sub: string?)
	local sc = K.scroll(body, { Name = "Settings" .. tostring(sub) })
	K.vlist(sc, 14); K.pad(sc, 0, 4, 8, 12)
	if sub == "Touches" then keys(ctx, sc)
	elseif sub == "Accessibilité" then access(ctx, sc)
	else general(ctx, sc) end
end
