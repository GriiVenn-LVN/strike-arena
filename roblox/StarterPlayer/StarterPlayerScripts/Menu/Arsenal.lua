--!strict
-- StarterPlayerScripts/Menu/Arsenal (ModuleScript) — rubrique « Arsenal » (src/85_menu.js, src/86_meta_ui.js)
-- Armes / Viseurs : panneaux de ReplicatedStorage/Shared/ArsenalPanels s'ils existent, sinon une version simple ici
-- (liste des armes, aperçu 3D, statistiques, skins ; viseurs et réticules). Tenues et effets (id « Casier ») : tenues,
-- danses, sprays, effets d'élimination et traînées de balles (avant dans Profil › Style), avec un aperçu du personnage.
-- Caisses : les deux caisses, probabilités affichées, ouverture animée (LootService).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local X = require(ReplicatedStorage.Shared.ConfigExtra)
local Catalog = require(ReplicatedStorage.Shared.ShopCatalog)
local KillFxConfig = require(ReplicatedStorage.Shared.KillFxConfig)
local K = require(script.Parent.Kit)
local C = K.C
local make, text, spaced = K.make, K.text, K.spaced

-- nom et symbole des sprays (SprayService.LOOK)
local SPRAY_LOOK: { [string]: { string } } = {
	smile = { "Sourire", "☺" }, heart = { "Cœur", "♥" }, skull = { "Crâne", "☠" }, bolt = { "Éclair", "⚡" },
	flame = { "Flamme", "🔥" }, crown = { "Couronne", "♛" }, target = { "Cible", "◎" }, ghost = { "Fantôme", "👻" },
}
local CAT = { { "melee", "COUTEAU" }, { "pistol", "PISTOLETS" }, { "smg", "SMG" }, { "shotgun", "POMPES" }, { "rifle", "FUSILS" }, { "sniper", "PRÉCISION" }, { "lmg", "MITRAILLEUSES" } }

-- panneaux de l'autre module (Armurier, viseurs), s'il est présent
local function panels(): any
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local m = shared and shared:FindFirstChild("ArsenalPanels")
	if not m or not m:IsA("ModuleScript") then return nil end
	local ok, res = pcall(require, m)
	return if ok then res else nil
end

-- aperçu 3D qui tourne (ViewportFrame) ; build = fabrique le modèle
local function preview(parent: Instance, props: { [string]: any }, build: () -> Model?, fov: number?, side: boolean?): ViewportFrame
	local vf = make("ViewportFrame", { BackgroundTransparency = 0, BackgroundColor3 = K.rgb(0x101a2e), Ambient = Color3.fromRGB(150, 158, 178),
		LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(0.4, -1, 0.3) }, parent)
	for k, v in pairs(props) do (vf :: any)[k] = v end
	K.gradient(vf, K.rgb(0x22355a), K.rgb(0x0b1220), 90)
	K.corner(vf, 4); K.stroke(vf, C.white, 1, 0.9)
	task.spawn(function()
		local ok, m = pcall(build)
		if not ok or not m then
			text(vf, { Text = "Aperçu indisponible", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.dim })
			return
		end
		if not vf.Parent then m:Destroy(); return end
		local world = make("WorldModel", {}, vf)
		m.Parent = world
		local cf, ext = m:GetBoundingBox()
		local cam = Instance.new("Camera"); cam.FieldOfView = fov or 30
		cam.Parent = vf; vf.CurrentCamera = cam
		local radius = ext.Magnitude / 2
		local dist = radius / math.tan(math.rad((fov or 30) / 2)) * 1.05
		local center = cf.Position
		local a = 0
		local conn: RBXScriptConnection
		conn = RunService.RenderStepped:Connect(function(dt: number)
			if not vf.Parent then conn:Disconnect(); return end
			a += dt * 0.6
			local dir = if side then Vector3.new(-math.cos(a * 0.5) , 0.12, math.sin(a * 0.5) * 0.6) else Vector3.new(math.sin(a), 0.15, math.cos(a))
			cam.CFrame = CFrame.lookAt(center + dir.Unit * dist, center)
			vf.LightDirection = cam.CFrame:VectorToWorldSpace(Vector3.new(0.35, -0.6, -1))   -- lumière qui suit la caméra : camo toujours éclairé
		end)
	end)
	return vf
end

local function weaponModel(key: string, skin: number?, camo: string?): () -> Model?
	return function()
		local WeaponModels = require(ReplicatedStorage.Shared.WeaponModels)
		local SkinPaint = require(ReplicatedStorage.Shared.SkinPaint)
		local m = WeaponModels.build(key, 1)
		pcall(SkinPaint.apply, m, skin, camo)
		return m
	end
end
-- copie du personnage du joueur (tenue portée), sinon un soldat en blocs
local function characterModel(player: Player): () -> Model?
	return function()
		local ch = player.Character
		if ch then
			local was = ch.Archivable
			ch.Archivable = true
			local ok, copy = pcall(function() return ch:Clone() end)
			ch.Archivable = was
			if ok and copy then
				for _, d in ipairs(copy:GetDescendants()) do
					if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") or d:IsA("Tool") then d:Destroy()
					elseif d:IsA("BasePart") then d.Anchored = true end
				end
				local hum = copy:FindFirstChildOfClass("Humanoid")
				if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
				copy:PivotTo(CFrame.new())
				return copy
			end
		end
		local m = Instance.new("Model")
		local function part(size: Vector3, pos: Vector3, col: Color3)
			local p = Instance.new("Part"); p.Size = size; p.Position = pos; p.Color = col; p.Anchored = true; p.Material = Enum.Material.SmoothPlastic; p.Parent = m
		end
		local navy = K.rgb(0x3a4a6a)
		part(Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), navy); part(Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 4.6, 0), K.rgb(0xe0b48a))
		part(Vector3.new(1, 2, 1), Vector3.new(-1.5, 3, 0), navy); part(Vector3.new(1, 2, 1), Vector3.new(1.5, 3, 0), navy)
		part(Vector3.new(1, 2, 1), Vector3.new(-0.5, 1, 0), K.rgb(0x2a3448)); part(Vector3.new(1, 2, 1), Vector3.new(0.5, 1, 0), K.rgb(0x2a3448))
		return m
	end
end

-- carte d'objet (Casier) : bord gauche de la couleur de rareté, nom, rareté, ÉQUIPÉE / cadenas
local function itemCard(parent: Instance, order: number, name: string, rarity: number, owned: boolean, equipped: boolean, cb: () -> ())
	local col = K.rarityColor(rarity)
	local b = make("TextButton", { Text = "", LayoutOrder = order, BackgroundTransparency = if owned then 0.1 else 0.35, BackgroundColor3 = if equipped then K.rgb(0x1c2740) else C.card,
		Selectable = true }, parent)
	K.stroke(b, if equipped then C.white else C.white, 1, if equipped then 0.4 else 0.93)
	make("Frame", { Size = UDim2.new(0, 3, 1, 0), BackgroundTransparency = 0, BackgroundColor3 = col }, b)
	text(b, { Text = name, Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -90, 0, 18), Font = K.BLACK, TextSize = 14, TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = if owned then C.white else C.dim })
	text(b, { Text = spaced(string.upper(Config.RARITY[rarity] and Config.RARITY[rarity].name or ""), 1), Position = UDim2.fromOffset(16, 32), Size = UDim2.new(1, -30, 0, 14),
		TextSize = 10, Font = K.BLACK, TextColor3 = if owned then col:Lerp(C.white, 0.4) else col, TextWrapped = false })
	text(b, { Text = if equipped then spaced("ÉQUIPÉE", 1) elseif owned then "" else "🔒", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(80, 14), TextSize = 10, TextColor3 = C.green, TextXAlignment = Enum.TextXAlignment.Right, Font = K.BLACK })
	b.Activated:Connect(cb)
	b.MouseEnter:Connect(function() if not equipped then b.BackgroundColor3 = C.card2 end end)
	b.MouseLeave:Connect(function() if not equipped then b.BackgroundColor3 = C.card end end)
end

-- ======================= Armes (version simple) =======================
local function arms(ctx: any, body: Frame)
	local profile = ctx.data and ctx.data.profile
	local player = ctx.player
	local W = ctx.W - 56
	local sel = ctx.armSel
	if not sel or not Config.WEAPONS[sel] then
		local a = player:GetAttribute("Primary")
		sel = if typeof(a) == "string" and Config.WEAPONS[a] then a else "galil"
		ctx.armSel = sel
	end
	local key: string = sel
	local w = Config.WEAPONS[key]
	local function owned(k: string): boolean
		return Catalog.STARTER_WEAPONS[k] == true or (profile ~= nil and Catalog.ownsWeapon(profile, k))
	end
	-- liste à gauche
	local left = K.scroll(body, { Name = "ArmList", Size = UDim2.new(0, 200, 1, 0) })
	K.vlist(left, 4); K.pad(left, 0, 0, 8, 10)
	local o = 0
	for _, cat in ipairs(CAT) do
		local keys = {}
		for k, ww in pairs(Config.WEAPONS) do if ww.cat == cat[1] then table.insert(keys, k) end end
		table.sort(keys, function(a, b) return Config.WEAPONS[a].price < Config.WEAPONS[b].price end)
		if #keys > 0 then
			o += 1; K.label(left, cat[2], o, C.dim)
			for _, k in ipairs(keys) do
				o += 1
				local on = k == key
				local b = K.btn(left, "  " .. Config.WEAPONS[k].name .. (if owned(k) then "" else '  <font color="#ffd23a">🔒</font>'), if on then "primary" else "alt",
					function() ctx.armSel = k; ctx.render() end, { LayoutOrder = o, Size = UDim2.new(1, 0, 0, 30), TextSize = 13, Font = K.BOLD, TextXAlignment = Enum.TextXAlignment.Left })
				K.corner(b, 2)
			end
		end
	end
	-- skins à droite
	local rw = if W >= 1100 then 240 else 0
	local mid = make("Frame", { Position = UDim2.fromOffset(216, 0), Size = UDim2.new(1, -216 - (if rw > 0 then rw + 16 else 0), 1, 0) }, body)
	local equippedSkin = profile and profile.equippedSkins and profile.equippedSkins[key] or 1
	local camo = profile and profile.equipped and profile.equipped.animCamo and profile.equipped.animCamo[key]
	local midScroll = K.scroll(mid, { Name = "ArmMid" })
	K.vlist(midScroll, 10, Enum.HorizontalAlignment.Center); K.pad(midScroll, 0, 0, 6, 10)
	preview(midScroll, { Size = UDim2.new(1, 0, 0, math.max(220, ctx.H - 470)), LayoutOrder = 1 }, weaponModel(key, equippedSkin, camo), 24, true)
	text(midScroll, { Text = spaced(string.upper(w.name), 2), Font = K.BLACK, TextSize = 26, LayoutOrder = 2, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 30) })
	-- statistiques (10 tuiles comme le web)
	local stats = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3 }, midScroll)
	K.grid(stats, UDim2.new(0.2, -8, 0, 54), 8)
	local acc = 1 - math.min(1, w.spread / 4)
	local list: { { any } } = {
		{ "DÉGÂTS", tostring(w.dmg * w.pellets), w.dmg * w.pellets / 120 }, { "CADENCE", tostring(w.rpm), w.rpm / 1000 }, { "CHARGEUR", tostring(w.mag), w.mag / 100 },
		{ "PRÉCISION", math.floor(acc * 100) .. "%", acc }, { "TÊTE", "×" .. tostring(w.hs), w.hs / 4 }, { "CONTRÔLE", math.floor((1 - math.min(1, w.recoil / 5)) * 100) .. "%", 1 - math.min(1, w.recoil / 5) },
		{ "PERFORATION", math.floor(w.armorPen * 100) .. "%", w.armorPen }, { "MOBILITÉ", string.format("%.2f", w.speed), (w.speed - 0.7) / 0.4 },
		{ "RECHARGEMENT", if w.reload > 0 then w.reload .. " s" else "—", if w.reload > 0 then 1 - w.reload / 6 else 0 },
		{ "PRIX", if owned(key) then "✔" else K.fmt(Catalog.weaponPrice(key)) .. " 🪙", 1 },
	}
	for i, s in ipairs(list) do
		local t = make("Frame", { LayoutOrder = i, BackgroundTransparency = 0.1, BackgroundColor3 = C.panel }, stats)
		text(t, { Text = spaced(s[1], 1), Size = UDim2.new(1, 0, 0, 12), Position = UDim2.fromOffset(0, 8), TextSize = 9, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Center })
		text(t, { Text = s[2], Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 22), TextSize = 17, Font = K.BLACK, TextXAlignment = Enum.TextXAlignment.Center })
		local bar = make("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 6, 1, -4), Size = UDim2.new(math.clamp(tonumber(s[3]) or 0, 0.04, 1), -12, 0, 3),
			BackgroundTransparency = 0, BackgroundColor3 = C.accent }, t)
		K.corner(bar, 2)
	end
	-- équiper / acheter
	local act = make("Frame", { Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 4 }, midScroll)
	K.hlist(act, 10).HorizontalAlignment = Enum.HorizontalAlignment.Center
	if w.slot == 0 or w.slot == 1 then
		local cur = player:GetAttribute(if w.slot == 0 then "Primary" else "Secondary")
		if not owned(key) then
			K.btn(act, "🔒  Débloquer · " .. K.fmt(Catalog.weaponPrice(key)) .. " 🪙", "gold", function()
				local res = ctx.call("ShopBuy", "weapon_" .. key)
				ctx.toast(if res and res.ok then "✔ " .. w.name .. " débloquée !" else "Achat impossible : " .. tostring(res and res.err or "erreur"), if res and res.ok then C.green else C.accent)
				ctx.refresh()
			end, { Size = UDim2.fromOffset(240, 36), TextSize = 13, LayoutOrder = 1 })
		elseif cur == key then
			K.btn(act, "✔  " .. (if w.slot == 0 then "Arme principale" else "Pistolet") .. " équipée", "dark", nil, { Size = UDim2.fromOffset(260, 36), TextSize = 13, LayoutOrder = 1 })
		else
			K.btn(act, "Équiper comme " .. (if w.slot == 0 then "arme principale" else "pistolet"), "primary", function()
				local ok = ctx.call("SetLoadout", key)
				ctx.toast(if ok then "✔ " .. w.name .. " : tu l'auras à ta prochaine apparition" else "Impossible d'équiper cette arme", if ok then C.green else C.accent)
				ctx.render()
			end, { Size = UDim2.fromOffset(280, 36), TextSize = 13, LayoutOrder = 1 })
		end
	end
	K.btn(act, "🛒  Ouvrir la boutique", "alt", function() ctx.panel("shop") end, { Size = UDim2.fromOffset(190, 36), TextSize = 13, LayoutOrder = 2 })
	-- skins
	local skinParent: Instance = midScroll
	if rw > 0 then
		local r = K.scroll(body, { Name = "ArmSkins", Size = UDim2.new(0, rw, 1, 0), Position = UDim2.new(1, -rw, 0, 0) })
		K.vlist(r, 8); K.pad(r, 0, 0, 6, 10)
		skinParent = r
	end
	K.label(skinParent, "SKIN", 10, C.dim)
	local sg = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 11 }, skinParent)
	K.grid(sg, UDim2.new(0.5, -4, 0, 38), 6)
	if w.melee then
		K.para(skinParent, "Les couteaux se choisissent dans la Boutique.", 11, C.dim, 12)
	else
		for i, sk in ipairs(Config.SKINS) do
			local have = sk.rarity == 1 or (profile ~= nil and profile.inv.skins[key] ~= nil and table.find(profile.inv.skins[key], i) ~= nil)
			local on = equippedSkin == i
			local col = K.rarityColor(sk.rarity)
			local b = make("TextButton", { Text = "", LayoutOrder = i, BackgroundTransparency = if have then 0.1 else 0.4, BackgroundColor3 = C.panel, Selectable = true }, sg)
			K.stroke(b, if on then C.accent else C.white, if on then 2 else 1, if on then 0 else 0.92)
			make("Frame", { Size = UDim2.new(0, 2, 1, 0), BackgroundTransparency = 0, BackgroundColor3 = col }, b)
			local dot = make("Frame", { Size = UDim2.fromOffset(14, 14), Position = UDim2.new(0, 10, 0.5, -7), BackgroundTransparency = 0, BackgroundColor3 = col }, b)
			K.corner(dot, 7)
			text(b, { Text = sk.name .. (if have then "" else " 🔒"), Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -34, 1, 0), TextSize = 11, Font = K.MED,
				TextColor3 = if have then C.text else C.dim })
			b.Activated:Connect(function()
				if not have then ctx.toast("Skin à gagner dans les caisses ou à acheter dans la Boutique", C.gold); return end
				local ok = ctx.call("EquipSkin", key, i)
				if ok then ctx.toast("✔ " .. sk.name .. " sur " .. w.name, C.green) end
				ctx.refresh()
			end)
		end
	end
end

-- ======================= Viseurs (version simple) =======================
local function sights(ctx: any, body: Frame)
	local profile = ctx.data and ctx.data.profile
	local sc = K.scroll(body, { Name = "Sights" })
	K.vlist(sc, 10); K.pad(sc, 0, 0, 8, 10)
	local key = ctx.armSel or "galil"
	if not Config.WEAPONS[key] or Config.WEAPONS[key].melee then key = "galil" end
	local function own(id: string): boolean
		local it = Catalog.get(id)
		return it ~= nil and profile ~= nil and Catalog.owns(profile, it)
	end
	local function grid(order: number): Frame
		local g = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order }, sc)
		K.grid(g, UDim2.fromOffset(300, 56), 10)
		return g
	end
	K.label(sc, "RÉTICULE (POUR TOUTES LES ARMES)", 1)
	local g1 = grid(2)
	for i, r in ipairs(X.RETICLES) do
		local id = "reticle_" .. r.id
		local have = own(id)
		itemCard(g1, i, r.name, r.rarity, have, profile ~= nil and profile.equipped.reticle == r.id, function()
			if not have then ctx.panel("shop"); return end
			ctx.call("ShopEquip", id); ctx.refresh()
		end)
	end
	K.label(sc, "OPTIQUE · " .. string.upper(Config.WEAPONS[key].name) .. " (choisis l'arme dans Armes)", 3)
	local g2 = grid(4)
	for i, s in ipairs(X.SIGHTS) do
		local id = "sight_" .. s.id
		local have = own(id)
		itemCard(g2, i, s.name, s.rarity, have, profile ~= nil and profile.equipped.sights[key] == s.id, function()
			if not have then ctx.panel("shop"); return end
			ctx.call("ShopEquip", id, key); ctx.refresh()
		end)
	end
	K.para(sc, "Purement visuels : l'effet en jeu reste celui du point rouge. Les viseurs verrouillés s'achètent dans la Boutique.", 12, C.dim, 5)
end

-- ======================= Casier =======================
local function locker(ctx: any, body: Frame)
	local profile = ctx.data and ctx.data.profile
	local W = ctx.W - 56
	local kind = ctx.lockerKind or "outfits"
	local lw = if W >= 1000 then math.floor(W * 0.42) else W
	local left = K.scroll(body, { Name = "Locker", Size = UDim2.new(0, lw, 1, 0) })
	K.vlist(left, 10); K.pad(left, 0, 0, 8, 10)
	-- choix de la catégorie d'abord, puis une phrase qui dit où ça se voit en jeu
	local tabs = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 }, left)
	K.hlist(tabs, 6, Enum.VerticalAlignment.Center, true)
	for i, t in ipairs({ { "outfits", "👕 Tenues" }, { "dances", "💃 Danses" }, { "sprays", "🎨 Sprays" }, { "killfx", "💥 Effets d'élimination" }, { "trails", "✨ Traînées" } }) do
		K.chip(tabs, t[2], kind == t[1], function() ctx.lockerKind = t[1]; ctx.render() end, { LayoutOrder = i, Size = UDim2.fromOffset(0, 32) })
	end
	K.para(left, if kind == "dances" then "Danses et emotes : touche T en partie." elseif kind == "outfits" then "La tenue de ton soldat, visible à ta prochaine apparition."
		elseif kind == "sprays" then "Un dessin sur les murs : touche J en partie." elseif kind == "trails" then "La couleur de la traînée de tes balles."
		else "L'effet qui apparaît quand tu élimines un adversaire.", 12, C.dim, 2)
	local g = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3 }, left)
	K.grid(g, UDim2.new(0.5, -5, 0, 56), 10)
	local status = ""
	if kind == "dances" then
		local ids = {}
		for id in pairs(Config.DANCES) do table.insert(ids, id) end
		table.sort(ids, function(a, b)
			local ra, rb = Config.DANCES[a].rarity, Config.DANCES[b].rarity
			return if ra ~= rb then ra < rb else Config.DANCES[a].name < Config.DANCES[b].name
		end)
		for i, id in ipairs(ids) do
			local dd = Config.DANCES[id]
			local have = profile ~= nil and table.find(profile.inv.dances, id) ~= nil
			local on = profile ~= nil and profile.equippedDance == id
			if on then status = "✔ Danse équipée : " .. dd.name end
			itemCard(g, i, dd.name, dd.rarity, have, on, function()
				if not have then ctx.toast("Danse à gagner dans les caisses, le cadeau du jour ou l'événement", C.gold); return end
				if ctx.call("EquipDance", id) then ctx.toast("✔ " .. dd.name .. " équipée (touche T)", C.green) end
				ctx.refresh()
			end)
		end
	elseif kind == "sprays" then
		-- sprays (SprayService) : débloqués par niveau comme sur le web (1, 1, 2, 2, 3, 3, 4, 4)
		local level = ctx.data and ctx.data.level or 1
		local cur = profile and profile.cosmetics and profile.cosmetics.spray or "smile"
		for i, id in ipairs(X.SPRAYS) do
			local look = SPRAY_LOOK[id] or { id, "?" }
			local need = 1 + (i - 1) // 2
			local have = level >= need
			if cur == id then status = "✔ Spray équipé : " .. look[1] end
			itemCard(g, i, look[2] .. "  " .. look[1] .. (if have then "" else "  · niveau " .. need), math.min(4, need), have, cur == id, function()
				if not have then ctx.toast("Débloqué au niveau " .. need, C.gold); return end
				if ctx.call("SetSpray", id) then ctx.toast("✔ " .. look[1] .. " (touche J en jeu)", C.green) end
				ctx.refresh()
			end)
		end
	elseif kind == "outfits" then
		for i, o in ipairs(Config.OUTFITS) do
			local it = Catalog.get("outfit_" .. i)
			local have = it ~= nil and profile ~= nil and Catalog.owns(profile, it)
			local on = profile ~= nil and profile.equipped.outfit == i
			if on then status = "✔ Tenue équipée : " .. o.name end
			itemCard(g, i, o.name, o.rarity, have, on, function()
				if not have then ctx.panel("shop"); return end
				if ctx.call("ShopEquip", "outfit_" .. i) then ctx.toast("✔ " .. o.name .. " : visible à ta prochaine apparition", C.green) end
				ctx.refresh()
			end)
		end
	elseif kind == "trails" then
		-- traînée de balles (boutique, X.TRAILS) : « Standard » = aucune traînée achetée
		local eqTrail = profile and profile.equipped and profile.equipped.trail or ""
		if eqTrail == "" then status = "✔ Traînée : Standard" end
		itemCard(g, 0, "Standard", 1, true, eqTrail == "", function()
			if eqTrail ~= "" then ctx.toast("La traînée standard revient en équipant « Standard » dans la Boutique", C.dim) end
		end)
		for i, t in ipairs(X.TRAILS) do
			if t ~= "" then
				local it = Catalog.get("trail_" .. t)
				local have = it ~= nil and profile ~= nil and Catalog.owns(profile, it)
				local nm = if it then (string.gsub(it.name, "^Traînée ", "")) else t
				if eqTrail == t then status = "✔ Traînée : " .. nm end
				itemCard(g, i, nm .. (if have or not it then "" else "  · " .. K.fmt(it.price) .. " 🪙"), if it then it.rarity else 1, have, eqTrail == t, function()
					if not have then ctx.panel("shop"); return end
					ctx.call("ShopEquip", "trail_" .. t); ctx.refresh()
				end)
			end
		end
	else
		for i, fx in ipairs(KillFxConfig.LIST) do
			local have = fx.id == "none" or (profile ~= nil and table.find(profile.inv.killfx or {}, fx.id) ~= nil)
			local on = profile ~= nil and (profile.equipped.killFx or "none") == fx.id
			if on then status = "✔ Effet équipé : " .. fx.name end
			itemCard(g, i, fx.name, fx.rarity, have, on, function()
				if not have then
					if fx.source == "code" then ctx.toast("S'obtient avec un code promo", C.gold); ctx.panel("codes")
					elseif fx.source == "group" then ctx.toast("S'obtient en rejoignant le groupe Roblox", C.gold); ctx.panel("group")
					else ctx.panel("shop") end
					return
				end
				if ctx.call("ShopEquip", "killfx_" .. fx.id) then ctx.toast("✔ " .. fx.name, C.green) end
				ctx.refresh()
			end)
		end
	end
	-- aperçu du personnage
	if W >= 1000 then
		local pw = math.min(620, W - lw - 30)
		local right = make("Frame", { Position = UDim2.fromOffset(lw + 30, 0), Size = UDim2.new(0, pw, 1, 0) }, body)
		preview(right, { Size = UDim2.new(1, 0, 1, -50) }, characterModel(ctx.player), 32)
		if status ~= "" then
			K.btn(right, status, "primary", nil, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.fromOffset(0, 34),
				AutomaticSize = Enum.AutomaticSize.X, TextSize = 13, Font = K.BOLD })
		end
	end
end

-- ======================= Caisses =======================
local function crates(ctx: any, body: Frame)
	local profile = ctx.data and ctx.data.profile
	local W = ctx.W - 56
	local sc = K.scroll(body, { Name = "Crates" })
	local wide = W >= 1100
	local lay = if wide then K.hlist(sc, 18, Enum.VerticalAlignment.Top) else K.vlist(sc, 14)
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	K.pad(sc, 0, 0, 8, 10)
	local cw = if wide then math.floor((W - 36 - 340) / 2) else W - 10
	for i, id in ipairs({ "std", "prem" }) do
		local def = Config.BOXES[id]
		local col = if id == "std" then C.blue else C.gold
		local f = make("Frame", { LayoutOrder = i, Size = UDim2.fromOffset(cw, 400), BackgroundTransparency = 0.1, BackgroundColor3 = K.rgb(0x0c1220) }, sc)
		K.stroke(f, C.white, 1, 0.9)
		make("Frame", { Size = UDim2.new(1, 0, 0, 3), BackgroundTransparency = 0, BackgroundColor3 = col }, f)
		local icon = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 26), Size = UDim2.fromOffset(128, 98), BackgroundTransparency = 0,
			BackgroundColor3 = K.rgb(0x1e2a42) }, f)
		K.corner(icon, 6); K.stroke(icon, col, 3, 0)
		make("Frame", { Size = UDim2.new(1, 0, 0, 6), Position = UDim2.fromScale(0, 0.38), BackgroundTransparency = 0, BackgroundColor3 = col }, icon)
		text(icon, { Text = "?", Size = UDim2.fromScale(1, 1), TextSize = 40, Font = K.BLACK, TextXAlignment = Enum.TextXAlignment.Center })
		text(f, { Text = spaced(string.upper(def.name), 2), Position = UDim2.fromOffset(0, 140), Size = UDim2.new(1, 0, 0, 22), Font = K.BLACK, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center })
		local stock = profile and profile.boxes and profile.boxes[id] or 0
		text(f, { Text = "En stock : <b>" .. stock .. "</b>  •  Prix : 🪙 " .. K.fmt(def.coins), Position = UDim2.fromOffset(0, 166), Size = UDim2.new(1, 0, 0, 16), TextSize = 12,
			TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Center })
		-- probabilités (obligatoires sur Roblox)
		for r, wgt in ipairs(def.weights) do
			local y = 196 + (r - 1) * 20
			local rc = K.rarityColor(r)
			text(f, { Text = Config.RARITY[r].name, Position = UDim2.fromOffset(18, y), Size = UDim2.fromOffset(80, 16), TextSize = 11, Font = K.BLACK, TextColor3 = if r == 1 then C.text else rc })
			local bar = make("Frame", { Position = UDim2.fromOffset(100, y + 5), Size = UDim2.fromOffset(math.max(4, wgt * 1.0), 6), BackgroundTransparency = 0, BackgroundColor3 = rc }, f)
			K.corner(bar, 3)
			text(f, { Text = wgt .. " %", Position = UDim2.fromOffset(108 + wgt, y), Size = UDim2.fromOffset(60, 16), TextSize = 11, TextColor3 = C.dim })
		end
		local can = stock > 0 or (profile ~= nil and (profile.coins or 0) >= def.coins)
		local b = K.btn(f, if stock > 0 then spaced("OUVRIR", 3) else spaced("ACHETER ET OUVRIR (🪙 " .. K.fmt(def.coins) .. ")", 1), if can then "primary" else "dark", function()
			if ctx.busyCrate then return end
			ctx.busyCrate = true
			local res = ctx.call("OpenBox", id)
			if res and res.ok then
				local okA, errA = pcall(function() require(ReplicatedStorage.Shared.CrateOpening).play(nil, res, id) end)   -- ouverture 3D du web
				if not okA then warn("[MainMenu] CrateOpening", errA) end
			else ctx.toast(if res and res.err == "not_enough_coins" then "Pas assez de pièces" else "Ouverture impossible", C.accent) end
			ctx.busyCrate = false
			ctx.refresh()
		end, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 290), Size = UDim2.fromOffset(if stock > 0 then 150 else math.min(cw - 30, 400), 50), TextSize = 16 })
		K.cut(b, 10, K.rgb(0x0c1220))
	end
	-- encarts d'information
	local info = make("Frame", { LayoutOrder = 3, Size = UDim2.fromOffset(if wide then 330 else cw, 0), AutomaticSize = Enum.AutomaticSize.Y }, sc)
	K.vlist(info, 10)
	local function box(order: number, title: string, body2: string)
		local f = make("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 0.1, BackgroundColor3 = K.rgb(0x0c1220) }, info)
		K.stroke(f, C.white, 1, 0.9); K.pad(f, 14, 12); K.vlist(f, 6)
		K.label(f, title, 1, C.dim)
		K.para(f, body2, 12, C.text, 2)
	end
	box(1, "COMMENT ÇA MARCHE", "Gagne des <b>pièces</b> et de l'<b>XP</b> en jouant, termine les défis du jour et récupère ta récompense quotidienne. Les caisses contiennent des <b>skins d'armes</b>, des <b>danses</b> et des <b>tenues</b>. Les doublons sont convertis en pièces. Probabilités affichées ; une rareté Épique est garantie toutes les "
		.. Config.PITY.epic .. " ouvertures et une Légendaire toutes les " .. Config.PITY.legend .. ". Les camos animés ✨ sont exclusifs (achat en Robux).")
	local pity = profile and profile.pity or { epic = 0, legend = 0 }
	box(2, "PITIÉ", "Épique garanti dans <b>" .. math.max(1, Config.PITY.epic - pity.epic) .. "</b> ouvertures\nLégendaire garanti dans <b>" .. math.max(1, Config.PITY.legend - pity.legend)
		.. "</b> ouvertures\nCaisses ouvertes : <b>" .. (profile and profile.opened or 0) .. "</b>")
	local owned, total = 0, 0
	for k, ww in pairs(Config.WEAPONS) do
		if not ww.melee then
			for _, sk in ipairs(Config.SKINS) do if sk.rarity > 1 then total += 1 end end
			owned += profile and profile.inv.skins[k] and #profile.inv.skins[k] or 0
		end
	end
	local nd = 0; for _ in pairs(Config.DANCES) do nd += 1 end
	box(3, "COLLECTION", "Skins débloqués : <b>" .. owned .. " / " .. total .. "</b>\nDanses : <b>" .. (profile and #profile.inv.dances or 0) .. " / " .. nd .. "</b>")
end

return function(ctx: any, body: Frame, sub: string?)
	if sub == "Viseurs" or sub == "Armes" then
		local ap = panels()
		local fn = ap and (if sub == "Armes" then ap.arms else ap.sights)
		if fn then
			local ok, err = pcall(fn, body)
			if ok then return end
			warn("[MainMenu] ArsenalPanels", err)
			K.clear(body)
		end
		if sub == "Armes" then arms(ctx, body) else sights(ctx, body) end
	elseif sub == "Casier" then
		locker(ctx, body)
	else
		crates(ctx, body)
	end
end
