--!strict
-- StarterPlayerScripts/Menu/Options (ModuleScript, client)
-- Les options du joueur, communes au menu principal (Réglages) et au panneau Options de la pause (PauseMenu) :
-- un seul état (O.v), appliqué tout de suite et enregistré dans le profil une seconde après le dernier changement.
--   Général       qualité graphique, sensibilité, sensibilité en visée, champ de vision, axe vertical inversé, FPS / ping
--   Viseur        couleur (XHCOL du web) et forme
--   Son           volume général + armes, pas, interface, ambiance, musique (Shared/Sfx.setVolume quand il existe)
--   Accessibilité daltonisme, sous-titres, taille de l'interface, secousses (AccessibilityController, événement AccessSet)
-- Où chaque réglage agit : S.opt (ClientState) pour WeaponController / HudController / PauseMenu, Lighting pour la qualité,
-- SoundService.Master ou Sfx pour les volumes. Enregistrement : MenuSave("opts") (anciens réglages, MenuService) et
-- OptionsSave (tout, OptionsService), le serveur borne chaque valeur (MenuConfig.cleanOptions).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")

local MenuConfig = require(ReplicatedStorage.Shared.MenuConfig)
local S = require(ReplicatedStorage.Shared.ClientState)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local K = require(script.Parent:WaitForChild("Kit"))
local C = K.C
local make, spaced = K.make, K.spaced

local player = Players.LocalPlayer

local O = {}
O.SUBS = { "Général", "Viseur", "Son", "Accessibilité" }
local clean = MenuConfig.cleanOptions({})
O.v = clean :: { [string]: any }           -- valeurs courantes (fov, sens, aimSens, quality, vol… ; access à part)
O.access = clean.access :: { [string]: any }
O.v.access = nil
local changedEv = Instance.new("BindableEvent")
O.changed = changedEv.Event                -- après chaque application

-- ---------- application ----------
-- volume général : groupe « Master » (les sons sans groupe y sont rangés), comme avant l'arrivée de Sfx.setVolume
local master = SoundService:FindFirstChild("Master") :: SoundGroup?
if not master then
	local g = Instance.new("SoundGroup"); g.Name = "Master"; g.Parent = SoundService; master = g
end
local function adopt(s: Instance)
	if s:IsA("Sound") and s.SoundGroup == nil then s.SoundGroup = master end
end
for _, where in ipairs({ workspace, SoundService }) do
	for _, d in ipairs(where:GetDescendants()) do adopt(d) end
	where.DescendantAdded:Connect(adopt)
end
local disabledFx: { [Instance]: boolean } = {}
local function xhColor(i: number): Color3
	return K.rgb(MenuConfig.XH_COLORS[i] or 0xffffff)
end
O.xhColor = xhColor

function O.apply()
	local o = O.v
	S.opt.fov = o.fov; S.opt.sens = o.sens; S.opt.aimSens = o.aimSens
	S.opt.invertY = o.invertY == true
	S.opt.xhColor = xhColor(o.xhColor); S.opt.xhStyle = o.xhStyle
	S.opt.showFps = o.showFps == true; S.opt.showPing = o.showPing == true
	-- volumes : Sfx.setVolume règle lui-même le groupe Master (1 = niveau d'origine, 70 % du curseur)
	if (Sfx :: any).setVolume then
		local setVolume = (Sfx :: any).setVolume
		pcall(setVolume, "master", o.vol / 0.7)
		for _, g in ipairs(MenuConfig.VOLUME_GROUPS) do pcall(setVolume, g[2], o[g[1]]) end
	elseif master then
		master.Volume = o.vol / 0.7
	end
	-- qualité : 1 sans ombres ni halos, 2 ombres, 3 ombres + halos + rayons
	Lighting.GlobalShadows = o.quality >= 2
	for _, e in ipairs(Lighting:GetChildren()) do
		if e:IsA("BloomEffect") or e:IsA("SunRaysEffect") then
			if o.quality < 3 and e.Enabled then e.Enabled = false; disabledFx[e] = true
			elseif o.quality >= 3 and disabledFx[e] then e.Enabled = true; disabledFx[e] = nil end
		end
	end
	changedEv:Fire()
end

-- ---------- chargement (profil reçu par GetProfile) ----------
function O.load(profile: any)
	if typeof(profile) ~= "table" then return end
	local src: { [string]: any } = {}
	local menu = profile.menu
	if typeof(menu) == "table" and typeof(menu.opts) == "table" then
		for k, v in pairs(menu.opts) do src[k] = v end                 -- anciens réglages (MenuService)
	end
	if typeof(profile.options) == "table" then
		for k, v in pairs(profile.options) do src[k] = v end           -- toutes les options (OptionsService)
	end
	local c = MenuConfig.cleanOptions(src)
	for k, v in pairs(c) do if k ~= "access" then O.v[k] = v end end
	if typeof(profile.options) == "table" and typeof(profile.options.access) == "table" then O.access = c.access end
	O.apply()
end

-- accessibilité : ce qu'AccessibilityController a en ce moment (attribut « Access »)
local function readAccess()
	local raw = player:GetAttribute("Access")
	if typeof(raw) == "string" then
		local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and typeof(data) == "table" then
			local c = MenuConfig.cleanOptions({ access = data }).access
			for k, v in pairs(c) do O.access[k] = v end
		end
	end
end
readAccess()
player:GetAttributeChangedSignal("Access"):Connect(readAccess)

-- ---------- enregistrement ----------
local function invoke(name: string, ...: any): any
	local r = ReplicatedStorage:FindFirstChild(name) or ReplicatedStorage:WaitForChild(name, 5)
	if not r or not r:IsA("RemoteFunction") then return nil end
	local ok, res = pcall(r.InvokeServer, r, ...)
	if not ok then warn("[Options]", name, res); return nil end
	return res
end
local saveToken = 0
function O.save()   -- une seconde après le dernier changement
	saveToken += 1
	local my = saveToken
	task.delay(1, function()
		if saveToken ~= my then return end
		local payload: { [string]: any } = table.clone(O.v)
		payload.access = table.clone(O.access)
		invoke("MenuSave", "opts", { fov = O.v.fov, sens = O.v.sens, aimSens = O.v.aimSens, vol = O.v.vol, quality = O.v.quality })
		task.wait(0.6)   -- MenuService et OptionsService acceptent un enregistrement par demi-seconde
		if saveToken == my then invoke("OptionsSave", payload) end
	end)
end
local function changed() O.apply(); O.save() end
O.set = function(key: string, value: any) O.v[key] = value; changed() end

function O.reset()
	local c = MenuConfig.cleanOptions({})
	for k, v in pairs(c) do if k ~= "access" then O.v[k] = v end end
	changed()
end

-- ---------- interface (Réglages du menu et Options de la pause) ----------
local QUALITY = { "Basse", "Moyenne", "Haute" }

local function chips(parent: Instance, order: number, items: { { any } }, cur: any, pick: (any) -> ())
	local r = make("Frame", { Size = UDim2.new(1, 0, 0, 36), LayoutOrder = order }, parent)
	K.hlist(r, 6)
	for i, it in ipairs(items) do
		K.chip(r, it[2], cur == it[1], function() pick(it[1]) end, { LayoutOrder = i })
	end
	return r
end
local function column(parent: Instance, W: number): (Frame, Frame)
	local two = W >= 900
	local cols = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 }, parent)
	if two then K.hlist(cols, 36, Enum.VerticalAlignment.Top) else K.vlist(cols, 14) end
	local cw = if two then math.min(440, (W - 40) // 2) else W - 10
	local a = make("Frame", { Size = UDim2.fromOffset(cw, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 }, cols)
	local b = make("Frame", { Size = UDim2.fromOffset(cw, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 }, cols)
	K.vlist(a, 10); K.vlist(b, 10)
	return a, b
end
local ONOFF: { { any } } = { { false, "Non" }, { true, "Oui" } }

local function general(sc: Instance, W: number, rerender: () -> ())
	local o = O.v
	local a, b = column(sc, W)
	K.label(a, "QUALITÉ GRAPHIQUE", 1)
	chips(a, 2, { { 1, QUALITY[1] }, { 2, QUALITY[2] }, { 3, QUALITY[3] } }, o.quality, function(v) O.set("quality", v); rerender() end)
	K.para(a, "Basse : sans ombres ni halos. Moyenne : ombres. Haute : ombres, halos et rayons de soleil. (Le niveau de détail Roblox se règle aussi dans le menu Échap.)", 11, C.dim, 3)
	K.slider(a, "SENSIBILITÉ EN VISÉE", 0.2, 2, 0.05, o.aimSens, function(v) return string.format("×%.2f", v) end, function(v) O.set("aimSens", v) end, 4)
	K.label(a, "INVERSER L'AXE VERTICAL", 5)
	chips(a, 6, ONOFF, o.invertY == true, function(v) O.set("invertY", v); rerender() end)
	K.slider(b, "SENSIBILITÉ", 0.1, 4, 0.05, o.sens, function(v) return string.format("%.2f", v) end, function(v) O.set("sens", v) end, 1)
	K.slider(b, "CHAMP DE VISION", 60, 110, 1, o.fov, function(v) return math.floor(v) .. "°" end, function(v) O.set("fov", v) end, 2)
	K.label(b, "AFFICHER LES FPS", 3)
	chips(b, 4, ONOFF, o.showFps == true, function(v) O.set("showFps", v); rerender() end)
	K.label(b, "AFFICHER LE PING", 5)
	chips(b, 6, ONOFF, o.showPing == true, function(v) O.set("showPing", v); rerender() end)
	K.btn(sc, spaced("RÉTABLIR PAR DÉFAUT", 1), "dark", function() O.reset(); rerender() end,
		{ LayoutOrder = 2, Size = UDim2.fromOffset(220, 32), TextSize = 11 })
end

-- aperçu du viseur : point, croix ou cercle de la couleur choisie
local function drawReticle(parent: Instance, style: string, col: Color3)
	local function piece(size: UDim2, pos: UDim2)
		local f = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = size, BackgroundTransparency = 0, BackgroundColor3 = col }, parent)
		K.stroke(f, Color3.new(0, 0, 0), 1, 0.4)
		return f
	end
	if style == "dot" then
		K.corner(piece(UDim2.fromOffset(6, 6), UDim2.fromScale(0.5, 0.5)), 3)
	elseif style == "cross" then
		for _, d in ipairs({ { 0, -12 }, { 0, 12 }, { -12, 0 }, { 12, 0 } }) do
			piece(if d[1] == 0 then UDim2.fromOffset(2, 10) else UDim2.fromOffset(10, 2), UDim2.new(0.5, d[1], 0.5, d[2]))
		end
	elseif style == "circle" then
		local ring = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(26, 26) }, parent)
		K.corner(ring, 13); K.stroke(ring, col, 2, 0)
		K.corner(piece(UDim2.fromOffset(4, 4), UDim2.fromScale(0.5, 0.5)), 2)
	end
end
local function reticle(sc: Instance, W: number, rerender: () -> ())
	local o = O.v
	local a, b = column(sc, W)
	K.label(a, "COULEUR DU VISEUR", 1)
	local sw = make("Frame", { Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 2 }, a)
	K.hlist(sw, 8)
	for i, hex in ipairs(MenuConfig.XH_COLORS) do
		local on = o.xhColor == i
		local c = make("TextButton", { Text = "", Size = UDim2.fromOffset(32, 32), BackgroundTransparency = 0, BackgroundColor3 = K.rgb(hex), LayoutOrder = i,
			Selectable = true, AutoButtonColor = false }, sw)
		K.corner(c, 16); K.stroke(c, C.white, if on then 3 else 1, if on then 0 else 0.7)
		K.juice(c, 0.12)
		c.Activated:Connect(function() O.set("xhColor", i); rerender() end)
	end
	K.label(a, "FORME", 3)
	local styles = {}
	for _, st in ipairs(MenuConfig.XH_STYLES) do table.insert(styles, { st[1], st[2] }) end
	chips(a, 4, styles, o.xhStyle, function(v) O.set("xhStyle", v); rerender() end)
	-- aperçu (le web dessine le viseur sur une grille sombre)
	local prev = make("Frame", { Size = UDim2.new(1, 0, 0, 150), BackgroundTransparency = 0.2, BackgroundColor3 = K.rgb(0x0b111c), LayoutOrder = 1 }, b)
	K.corner(prev, 10); K.stroke(prev)
	for i = 1, 13 do
		make("Frame", { Position = UDim2.fromScale(i / 14, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundTransparency = 0.95, BackgroundColor3 = C.white }, prev)
	end
	drawReticle(prev, o.xhStyle, xhColor(o.xhColor))
	K.para(b, "Aperçu du viseur affiché au centre de l'écran en partie.", 11, C.dim, 2)
end

local function sound(sc: Instance, W: number, _rerender: () -> ())
	local o = O.v
	local a, b = column(sc, W)
	local pct = function(v: number) return math.floor(v * 100 + 0.5) .. "%" end
	K.slider(a, "VOLUME GÉNÉRAL", 0, 1, 0.05, o.vol, pct, function(v) O.set("vol", v) end, 1)
	K.para(a, "70 % = le volume d'origine du jeu.", 11, C.dim, 2)
	local has = (Sfx :: any).setVolume ~= nil
	for i, g in ipairs(MenuConfig.VOLUME_GROUPS) do
		K.slider(b, g[3], 0, 2, 0.05, o[g[1]], pct, function(v)
			O.set(g[1], v)
			if g[2] == "ui" then K.uiSound(false) end
		end, i)
	end
	if not has then K.para(b, "Les volumes par catégorie s'appliqueront avec la prochaine mise à jour des sons.", 11, C.dim, 10) end
end

local function access(sc: Instance, _W: number, rerender: () -> ())
	local ps = player:FindFirstChild("PlayerScripts")
	local ac = ps and ps:FindFirstChild("AccessibilityController")
	local ev = ac and ac:FindFirstChild("AccessSet")
	local cur = O.access
	local function set(key: string, value: any)
		cur[key] = value
		if ev and ev:IsA("BindableEvent") then ev:Fire(key, value) end
		O.save()
	end
	K.label(sc, "MODE DALTONIEN", 1)
	chips(sc, 2, { { "none", "Aucun" }, { "deut", "Deutéranopie" }, { "prot", "Protanopie" }, { "trit", "Tritanopie" } }, cur.colorblind,
		function(v) set("colorblind", v); rerender() end)
	K.label(sc, "SOUS-TITRES DES SONS (tirs entendus, avec la direction)", 3)
	chips(sc, 4, { { true, "Affichés" }, { false, "Masqués" } }, cur.subtitles == true, function(v) set("subtitles", v); rerender() end)
	local box = make("Frame", { Size = UDim2.fromOffset(440, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 5 }, sc)
	K.vlist(box, 10)
	K.slider(box, "TAILLE DE L'INTERFACE", 0.7, 1.4, 0.05, tonumber(cur.hudScale) or 1, function(v) return string.format("×%.2f", v) end, function(v) set("hudScale", v) end, 1)
	K.slider(box, "SECOUSSES DE L'ÉCRAN", 0, 1, 0.1, tonumber(cur.shake) or 1, function(v) return math.floor(v * 100 + 0.5) .. "%" end, function(v) set("shake", v) end, 2)
	if not (ev and ev:IsA("BindableEvent")) then K.para(sc, "Accessibilité indisponible pour le moment.", 11, C.accent, 6) end
end

-- sub : un des O.SUBS ; W : largeur disponible ; rerender : redessine (une puce a changé)
function O.build(sc: Instance, W: number, sub: string?, rerender: () -> ())
	if sub == "Viseur" then reticle(sc, W, rerender)
	elseif sub == "Son" then sound(sc, W, rerender)
	elseif sub == "Accessibilité" then access(sc, W, rerender)
	else general(sc, W, rerender) end
end

O.apply()
return O
