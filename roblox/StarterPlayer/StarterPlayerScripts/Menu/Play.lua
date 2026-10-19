--!strict
-- StarterPlayerScripts/Menu/Play (ModuleScript) — rubrique « Jouer » (src/87b_playui.js, src/85_menu.js, src/87d_lobby.js)
-- Interrupteur EN LIGNE / AVEC DES AMIS, avec une phrase qui dit ce que ça change, puis trois étapes :
--   1 MODE   tuiles des modes (pastille « 👤 n » : joueurs en ligne dans ce mode)
--   2 CARTE  vignettes vues de dessus et description
--   3 JOUER  le gros bouton JOUER (MatchCreate -> MatchService.playOnline : rejoint une partie publique du mode où il reste
--            de la place, sinon en crée une), ce qu'il va faire, PARTIE RAPIDE, les parties en cours (MatchList, joueurs humains),
--            puis les réglages « si une nouvelle partie est créée » : niveau des bots, places, et « Plus d'options »
--            (camp, limite, économie, modificateurs, classé).
-- Avec des amis : le groupe (PartyService) ; avec un groupe, la partie est privée (settings.private) et le chef la lance pour tous.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local AssetService = game:GetService("AssetService")
local SocialService = game:GetService("SocialService")
local Modes = require(ReplicatedStorage.Shared.Modes)
local MapData = require(ReplicatedStorage.Shared.MapData)
local X = require(ReplicatedStorage.Shared.ConfigExtra)
local K = require(script.Parent.Kit)
local C = K.C
local make, text, spaced = K.make, K.text, K.spaced

local function modeName(id: string): string
	local m = Modes.LIST[id]
	return if m then (string.gsub(m.n, "%s*%(.*%)", "")) else id
end

-- ---------- vignettes des cartes (drawMapThumb du web, src/20_maps.js) ----------
local TH: { [string]: { [string]: number } } = {
	night = { bg = 0x1a2438, w = 0x5a6a86, h = 0x3a4a6a, x = 0xd39a2b, l = 0x6a7a96, p = 0x4a6a9a },
	metro = { bg = 0x3a3f47, w = 0x9aa4b4, h = 0x7a8494, x = 0xc9a23a, l = 0x7a8494, p = 0x6a8ab0 },
	jungle = { bg = 0x4a7a3a, w = 0x8a9a7a, h = 0x7a8a6a, x = 0x6a7a5a, l = 0x9aa48a, p = 0xc9b070 },
	range = { bg = 0x7a8088, w = 0xcfd5dd, h = 0x8d97a6, x = 0xd39a2b, l = 0x8d97a6, p = 0x6e8fb5 },
	snow = { bg = 0xe8eef6, w = 0x7f8998, h = 0x8a5a38, x = 0x6f7a8a, l = 0xffffff, p = 0xb08a5a },
	sand = { bg = 0xc9b18a, w = 0xf0e6cc, h = 0xc56a3e, x = 0x8c6a3a, l = 0xa89b78, p = 0xe0c070 },
	industrial = { bg = 0x566070, w = 0xcfd5dd, h = 0x8d97a6, x = 0xd39a2b, l = 0x8d97a6, p = 0x6e8fb5 },
	haunt = { bg = 0x1e2a22, w = 0x6a4a40, h = 0x5a3a30, x = 0x6a5030, l = 0x7d8580, p = 0x5a5048 },
}
TH.halloween = TH.haunt
local thumbs: { [string]: any } = {}   -- EditableImage par carte (gardée d'un affichage à l'autre)
local function thumbImage(id: string): any
	if thumbs[id] ~= nil then return thumbs[id] end
	thumbs[id] = false
	local md = (MapData :: any)[id]
	local info = Modes.MAP[id]
	if not md or not info then return false end
	local okG, g = pcall(MapData.buildGrid, id)
	if not okG then return false end
	local N = MapData.N
	local th = TH[info.theme] or TH.industrial
	local okI, img = pcall(function() return AssetService:CreateEditableImage({ Size = Vector2.new(N, N) }) end)
	if not okI or not img then return false end
	local buf = buffer.create(N * N * 4)
	local function put(i: number, hex: number, a: number?)
		buffer.writeu8(buf, i * 4, bit32.rshift(hex, 16)); buffer.writeu8(buf, i * 4 + 1, bit32.band(bit32.rshift(hex, 8), 255))
		buffer.writeu8(buf, i * 4 + 2, bit32.band(hex, 255)); buffer.writeu8(buf, i * 4 + 3, a or 255)
	end
	for i = 0, N * N - 1 do
		local t = g.type[i]
		local col = th.bg
		if g.ramp[i] ~= 0 then col = 0xd9b45a
		elseif t == 1 or t == 8 then col = th.w
		elseif t == 3 or t == 7 then col = th.h
		elseif t == 2 or t == 9 then col = th.x
		elseif t == 4 or t == 5 then col = th.l
		elseif t == 6 then col = th.p
		elseif g.ceil[i] < 90 then   -- couvert : 18 % plus sombre
			local r, gg, b = bit32.rshift(th.bg, 16), bit32.band(bit32.rshift(th.bg, 8), 255), bit32.band(th.bg, 255)
			col = bit32.lshift(math.floor(r * 0.82), 16) + bit32.lshift(math.floor(gg * 0.82), 8) + math.floor(b * 0.82)
		end
		put(i, col)
	end
	local okW = pcall(function() (img :: any):WritePixelsBuffer(Vector2.zero, Vector2.new(N, N), buf) end)
	if not okW then return false end
	thumbs[id] = img
	return img
end
local function thumb(parent: Instance, id: string, size: number): Frame
	local info = Modes.MAP[id]
	local th = TH[info and info.theme or ""] or TH.industrial
	local f = make("Frame", { Size = UDim2.fromOffset(size, size), BackgroundTransparency = 0, BackgroundColor3 = K.rgb(th.bg), ClipsDescendants = true }, parent)
	K.corner(f, 6)
	local img = thumbImage(id)
	if img then
		local il = make("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ResampleMode = Enum.ResamplerMode.Pixelated }, f)
		pcall(function() il.ImageContent = Content.fromObject(img) end)
	else
		-- pas d'EditableImage (réglage Roblox) ou carte sans plan : vignette de couleur avec le nom
		K.gradient(f, K.rgb(th.bg), K.rgb(th.w), 135, 0, 0.3)
		text(f, { Text = info and info.n or id, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Font = K.BLACK, TextSize = math.max(10, size // 9),
			TextColor3 = K.rgb(th.h), TextTransparency = 0.2 })
	end
	local md = (MapData :: any)[id]
	if md and not (info and info.zombie) then
		local N = MapData.N
		for _, s in ipairs(md.sites or {}) do
			local r = (s.r or 7) / N * size
			local ring = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale((s.cx + 0.5) / N, (s.cz + 0.5) / N), Size = UDim2.fromOffset(r, r) }, f)
			K.corner(ring, math.floor(r)); K.stroke(ring, C.accent, 2, 0.1)
			text(ring, { Text = s.n, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Font = K.BLACK, TextSize = math.max(9, size // 11),
				TextColor3 = C.accent })
		end
		text(f, { Text = "CT", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(20 / N, 5 / N), Size = UDim2.fromOffset(30, 14), Font = K.BLACK,
			TextSize = math.max(8, size // 16), TextColor3 = C.blue, TextXAlignment = Enum.TextXAlignment.Center })
		text(f, { Text = "T", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(20 / N, 36 / N), Size = UDim2.fromOffset(30, 14), Font = K.BLACK,
			TextSize = math.max(8, size // 16), TextColor3 = K.rgb(0xff7a4a), TextXAlignment = Enum.TextXAlignment.Center })
	end
	return f
end

-- titre d'étape « (1) MODE », avec une phrase d'aide courte dessous
local function step(parent: Instance, n: number, title: string, order: number, help: string?)
	local row = make("Frame", { Size = UDim2.new(1, 0, 0, if help then 42 else 26), LayoutOrder = order }, parent)
	local b = text(row, { Text = tostring(n), Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(0, 2), BackgroundTransparency = 0, BackgroundColor3 = C.accent,
		TextXAlignment = Enum.TextXAlignment.Center, Font = K.BLACK, TextSize = 12 })
	K.corner(b, 11)
	text(row, { Text = spaced(title, 2), Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -32, 0, 26), Font = K.BLACK, TextSize = 14, TextWrapped = false })
	if help then
		text(row, { Text = help, Position = UDim2.fromOffset(32, 24), Size = UDim2.new(1, -32, 0, 16), TextSize = 11, Font = K.MED, TextColor3 = C.dim, TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd })
	end
end

-- état d'une partie de la liste (MatchService : loading, warmup, live, intermission, over)
local STATE_TEXT: { [string]: string } = { loading = "démarre", warmup = "échauffement", live = "en cours", intermission = "entre deux manches", over = "terminée" }
local function people(n: number): string return n .. " joueur" .. (if n > 1 then "s" else "") end

local DIFF_COL = { 0x7dff9f, 0xc6ff5a, 0xffd23a, 0xff9a3a, 0xff4655 }
local matchToken = 0

return function(ctx: any, body: Frame, _sub: string?)
	local p = ctx.play
	local player = ctx.player
	local W = ctx.W - 56
	local friends = ctx.friends == true
	local inParty = ctx.party.id ~= nil
	local leader = not inParty or player:GetAttribute("PartyLeader") == true
	local privateGame = friends and inParty   -- partie privée du groupe (settings.private) : toujours une nouvelle partie
	local function set(changes: { [string]: any })
		for k, v in pairs(changes) do p[k] = v end
		local s = Modes.sanitize(p)
		for k, v in pairs(s) do p[k] = v end
		-- comme sur le web : pas de partie classée avec des modificateurs ni hors des modes classés
		if next(p.mut) ~= nil or not X.RANKED_MODES[p.mode] then p.ranked = false end
		ctx.save("play"); ctx.render()
	end

	-- ---------- EN LIGNE / AVEC DES AMIS ----------
	local tog = make("Frame", { Size = UDim2.fromOffset(398, 44), BackgroundTransparency = 0, BackgroundColor3 = C.deep }, body)
	K.corner(tog, 12); K.stroke(tog, C.white, 1, 0.9); K.pad(tog, 4); K.hlist(tog, 4)
	local function togBtn(label: string, on: boolean, kind: string, order: number, w: number, cb: () -> ())
		local b = K.btn(tog, label, if on then kind else "ghost", cb, { LayoutOrder = order, Size = UDim2.fromOffset(w, 36), TextSize = 12,
			BackgroundTransparency = if on then 0 else 1, TextColor3 = if on then (if kind == "white" then C.ink else C.white) else C.dim })
		local st = b:FindFirstChildOfClass("UIStroke"); if st then st:Destroy() end
	end
	togBtn("🌐  " .. spaced("EN LIGNE", 1), not friends, "white", 1, 150, function() ctx.friends = false; ctx.save("play"); ctx.render() end)
	togBtn("👥  " .. spaced("AVEC DES AMIS", 1) .. (if inParty then '  <font color="#7dff9f">' .. #ctx.party.members .. "</font>" else ""), friends, "blue", 2, 232,
		function() ctx.friends = true; ctx.save("play"); ctx.render() end)
	-- ce que veut dire le choix, en une phrase
	local helpText = if not friends then "<b>En ligne</b> : tu joues avec les autres joueurs du serveur. S'il en manque, des bots complètent les places."
		elseif inParty then "<b>Avec des amis</b> : ton groupe joue dans une partie rien qu'à vous. Des bots prennent les places vides."
		else "<b>Avec des amis</b> : crée un groupe et invite tes amis. Tant que tu n'as pas de groupe, tu joues en ligne."
	local narrow = W < 900
	text(body, { Text = helpText, Position = if narrow then UDim2.fromOffset(0, 50) else UDim2.fromOffset(414, 0), Size = if narrow then UDim2.new(1, 0, 0, 34) else UDim2.new(1, -414, 0, 44),
		TextSize = 13, Font = K.MED, TextColor3 = C.sub, TextWrapped = true })

	-- ---------- colonnes : 1 MODE · 2 CARTE · 3 JOUER ----------
	local top = if narrow then 92 else 58
	local area = make("Frame", { Position = UDim2.fromOffset(0, top), Size = UDim2.new(1, 0, 1, -top) }, body)
	local c1: GuiObject, c2: GuiObject, c3: GuiObject
	local w1, w2, w3: number
	if W >= 1250 then
		w1, w3 = 330, 340
		w2 = W - w1 - w3 - 52
		c1 = K.scroll(area, { Name = "PlayMode", Size = UDim2.new(0, w1, 1, 0) })
		c2 = K.scroll(area, { Name = "PlayMap", Size = UDim2.new(0, w2, 1, 0), Position = UDim2.fromOffset(w1 + 26, 0) })
		c3 = K.scroll(area, { Name = "PlayCfg", Size = UDim2.new(0, w3, 1, 0), Position = UDim2.new(1, -w3, 0, 0) })
	elseif W >= 860 then
		w3 = 340; w1 = W - w3 - 30; w2 = w1
		local left = K.scroll(area, { Name = "PlayLeft", Size = UDim2.new(0, w1, 1, 0) })
		K.vlist(left, 18)
		c1 = make("Frame", { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 }, left)
		c2 = make("Frame", { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 }, left)
		c3 = K.scroll(area, { Name = "PlayCfg", Size = UDim2.new(0, w3, 1, 0), Position = UDim2.new(1, -w3, 0, 0) })
	else
		w1, w2, w3 = W, W, W
		local all = K.scroll(area, { Name = "PlayAll" })
		K.vlist(all, 18)
		c1 = make("Frame", { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 }, all)
		c2 = make("Frame", { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 }, all)
		c3 = make("Frame", { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3 }, all)
	end
	for _, c in ipairs({ c1, c2, c3 }) do K.vlist(c, 12); K.pad(c, 0, 0, 6, 12) end
	local guest = friends and inParty and not leader   -- les invités ne choisissent pas : le chef décide

	-- ---------- 1 MODE ----------
	step(c1, 1, "MODE", 1, if guest then "Le chef du groupe choisit." else "Comment veux-tu jouer ?")
	local tiles = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 }, c1)
	local cell = math.floor((w1 - 6 - 20) / 3)
	K.grid(tiles, UDim2.fromOffset(cell, 112), 10)
	local feat = Modes.featured()
	local order = 0
	local liveBadges: { [string]: TextLabel } = {}   -- « 👤 3 » : joueurs en ligne dans ce mode (mis à jour avec la liste)
	for _, grp in ipairs(Modes.GROUPS) do
		for _, id in ipairs(grp[2]) do
			local m = Modes.LIST[id]
			if m then
				order += 1
				local on = p.mode == id
				local b = make("TextButton", { Text = "", LayoutOrder = order, BackgroundTransparency = 0, BackgroundColor3 = if on then m.c:Lerp(C.card, 0.82) else C.card,
					Selectable = true, Active = not guest }, tiles)
				K.corner(b, 10); K.stroke(b, if on then m.c else C.white, 2, if on then 0 else 0.93)
				text(b, { Text = m.ic, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 14), TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center })
				text(b, { Text = spaced(K.upper(modeName(id)), 1), Size = UDim2.new(1, -10, 0, 44), Position = UDim2.fromOffset(5, 58), TextSize = 11, Font = K.BLACK,
					TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, LineHeight = 1.1 })
				if id == feat then
					local x2 = text(b, { Text = "XP ×2", Size = UDim2.fromOffset(46, 16), Position = UDim2.new(1, -52, 0, 6), BackgroundTransparency = 0, BackgroundColor3 = C.gold,
						TextColor3 = C.ink, Font = K.BLACK, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Center })
					K.corner(x2, 4)
				end
				local lb = text(b, { Text = "", Size = UDim2.fromOffset(40, 16), Position = UDim2.fromOffset(6, 6), BackgroundTransparency = 0, BackgroundColor3 = K.rgb(0x1f3a26),
					TextColor3 = C.green, Font = K.BLACK, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Center, Visible = false })
				K.corner(lb, 4)
				liveBadges[id] = lb
				if friends and id == "train" then b.BackgroundTransparency = 0.6 end
				if not guest then
					b.Activated:Connect(function()
						local maps = Modes.mapsFor(id)
						set({ mode = id, map = if table.find(maps, p.map) then p.map else maps[1], limit = Modes.defaultLimit(id) })
					end)
				end
				b.MouseEnter:Connect(function() if not on then b.BackgroundColor3 = C.card2 end end)
				b.MouseLeave:Connect(function() if not on then b.BackgroundColor3 = C.card end end)
			end
		end
	end
	K.para(c1, Modes.LIST[p.mode] and ("<b>" .. modeName(p.mode) .. "</b> : " .. Modes.LIST[p.mode].desc) or "", 12, C.sub, 3)
	local legend = K.para(c1, '<font color="#7dff9f">👤 3</font> = joueurs en ligne dans ce mode en ce moment.', 11, C.mute, 4)
	legend.Visible = false

	-- ---------- 2 CARTE ----------
	step(c2, 2, "CARTE", 1, if guest then "Le chef du groupe choisit." else "Où veux-tu jouer ?")
	local maps = Modes.mapsFor(p.mode)
	local mgrid = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 }, c2)
	local single = #maps == 1
	local per = if single then 1 elseif w2 >= 560 then 4 elseif w2 >= 400 then 3 else 2
	local cw = if single then math.min(420, w2 - 10) else math.floor((w2 - 8 - (per - 1) * 10) / per)
	local th = cw - 16
	K.grid(mgrid, UDim2.fromOffset(cw, th + 52), 10)
	for i, id in ipairs(maps) do
		local on = p.map == id
		local b = make("TextButton", { Text = "", LayoutOrder = i, BackgroundTransparency = 0, BackgroundColor3 = C.card, Selectable = true, Active = not guest }, mgrid)
		K.corner(b, 10); K.stroke(b, if on then C.accent else C.white, 2, if on then 0 else 0.93)
		local t = thumb(b, id, th); t.Position = UDim2.fromOffset(8, 8)
		text(b, { Text = spaced(K.upper(Modes.MAP[id].n), 1), Position = UDim2.fromOffset(4, th + 12), Size = UDim2.new(1, -8, 0, 36), Font = K.BLACK, TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center, LineHeight = 1.05 })
		if not guest then b.Activated:Connect(function() set({ map = id }) end) end
		b.MouseEnter:Connect(function() b.BackgroundColor3 = C.card2 end)
		b.MouseLeave:Connect(function() b.BackgroundColor3 = C.card end)
	end
	local desc = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, BackgroundTransparency = 0.2, BackgroundColor3 = C.deep }, c2)
	K.corner(desc, 8); K.pad(desc, 12, 12)
	K.para(desc, Modes.MAP[p.map] and ("<b>" .. Modes.MAP[p.map].n .. "</b> : " .. Modes.MAP[p.map].desc) or "", 12, C.sub)

	-- ---------- 3 JOUER ----------
	step(c3, 3, "JOUER", 1, if guest then "Le chef lance la partie pour tout le groupe." else "Lance la partie ou rejoins-en une.")

	-- le groupe d'amis (PartyService)
	if friends then
		local fb = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, BackgroundTransparency = 0, BackgroundColor3 = C.white }, c3)
		K.gradient(fb, K.rgb(0x132036), K.rgb(0x0d1626), 90); K.corner(fb, 12); K.stroke(fb, C.blue, 1, 0.6); K.pad(fb, 14)
		K.vlist(fb, 8)
		K.h4(fb, "👥 TON GROUPE", if inParty then #ctx.party.members .. " / 5" else nil, 0, K.rgb(0x9fd0ff))
		if not inParty then
			K.para(fb, "1. Crée un groupe.  2. Invite tes amis Roblox : ils arrivent ici et entrent dans ton groupe.  3. Choisis le mode et la carte, puis JOUER lance la partie pour tout le monde.", 12, C.sub, 1)
			K.btn(fb, "➕  " .. spaced("CRÉER UN GROUPE", 1), "blue", function()
				ctx.call("PartyCreate"); task.wait(0.3); ctx.render()
			end, { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 44), TextSize = 14 })
			-- groupes ouverts sur ce serveur
			local others = {}
			for _, q in ipairs(Players:GetPlayers()) do
				if q ~= player and q:GetAttribute("PartyLeader") == true and typeof(q:GetAttribute("Party")) == "string" then table.insert(others, q) end
			end
			if #others > 0 then
				K.label(fb, "OU REJOINS UN GROUPE DE CE SERVEUR", 3, C.dim)
				for i, q in ipairs(others) do
					local r = make("Frame", { Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 3 + i, BackgroundTransparency = 0.94, BackgroundColor3 = C.white }, fb)
					K.corner(r, 8); K.pad(r, 10, 0, 4, 0)
					text(r, { Text = "👑 " .. K.esc(q.DisplayName), Size = UDim2.new(1, -110, 1, 0), TextSize = 13, TextWrapped = false })
					K.btn(r, spaced("REJOINDRE", 1), "blue", function()
						local ok = ctx.call("PartyJoin", q:GetAttribute("Party"))
						ctx.toast(if ok then "✔ Tu as rejoint le groupe de " .. q.DisplayName else "Groupe plein ou fermé", if ok then C.green else C.accent)
					end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(100, 28), TextSize = 10 })
				end
			end
		else
			for i, m in ipairs(ctx.party.members) do
				local r = make("Frame", { Size = UDim2.new(1, 0, 0, 34), LayoutOrder = i, BackgroundTransparency = 0.94, BackgroundColor3 = C.white }, fb)
				K.corner(r, 8); K.pad(r, 10, 0)
				text(r, { Text = K.esc(tostring(m.name)) .. (if m.userId == player.UserId then '  <font color="#8da0bd">(toi)</font>' else ""), Size = UDim2.new(1, -60, 1, 0), TextSize = 13,
					TextWrapped = false })
				if m.leader then
					text(r, { Text = spaced("CHEF", 1), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(60, 34), TextColor3 = C.gold,
						Font = K.BLACK, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right })
				end
			end
			for i = #ctx.party.members + 1, 5 do
				local r = make("Frame", { Size = UDim2.new(1, 0, 0, 30), LayoutOrder = i, BackgroundTransparency = 0.97, BackgroundColor3 = C.white }, fb)
				K.corner(r, 8); K.pad(r, 10, 0)
				text(r, { Text = "Place libre : invite un ami", Size = UDim2.fromScale(1, 1), TextSize = 12, Font = K.MED, TextColor3 = C.mute })
			end
			K.btn(fb, "✉  " .. spaced("INVITER DES AMIS", 1), "blue", function()
				local ok, can = pcall(function() return SocialService:CanSendGameInviteAsync(player) end)
				if ok and not can then ctx.toast("Les invitations ne sont pas disponibles sur ce compte", C.gold); return end
				local opts = Instance.new("ExperienceInviteOptions")
				opts.PromptMessage = "Rejoins mon groupe sur Strike Arena !"
				opts.LaunchData = "party:" .. tostring(ctx.party.id)
				local okP = pcall(function() SocialService:PromptGameInvite(player, opts) end)
				if not okP then ctx.toast("Invitation impossible pour le moment", C.accent) end
			end, { LayoutOrder = 10, Size = UDim2.new(1, 0, 0, 42), TextSize = 13 })
			K.btn(fb, spaced("QUITTER LE GROUPE", 1), "dark", function()
				ctx.call("PartyLeave"); ctx.party.id = nil; ctx.party.members = {}; ctx.render()
			end, { LayoutOrder = 11, Size = UDim2.new(1, 0, 0, 32), TextSize = 11 })
			if guest then
				K.para(fb, "Le chef du groupe choisit le mode et la carte, puis lance la partie pour tout le monde. Reste dans le lobby !", 12, K.rgb(0xcfe5ff), 12)
			end
		end
	end
	if guest then return end

	-- JOUER : l'action principale de l'écran
	local def = Modes.LIST[p.mode]
	local label = if privateGame then "JOUER AVEC LE GROUPE" else "JOUER"
	local pb = K.btn(c3, "", "primary", function() ctx.startPlay() end, { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 78), Name = "PlayGo" })
	text(pb, { Text = "▶  " .. spaced(label, if privateGame then 2 else 4), Font = K.BLACK, TextSize = if privateGame then 20 else 28, Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.fromOffset(0, 12), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, ZIndex = pb.ZIndex + 1 })
	text(pb, { Text = spaced(modeName(p.mode) .. " · " .. (Modes.MAP[p.map] and Modes.MAP[p.map].n or ""), 1), Font = K.BOLD, TextSize = 11, Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, 50), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, TextTransparency = 0.15, ZIndex = pb.ZIndex + 1 })
	K.cut(pb, 12, K.rgb(0x0b111c))
	K.shine(pb, 2.4, 0.25)   -- reflet qui revient sur JOUER (playglow du web)
	-- ce que fera JOUER (mis à jour avec la liste des parties)
	local alone = p.mode == "train" or next(p.mut) ~= nil   -- MatchService : l'Entraînement et les modificateurs restent seuls
	local status = K.para(c3, "", 12, C.sub, 4)
	local function showStatus(list: { any }?)
		if privateGame then
			status.Text = "🔒 Une partie privée est créée pour ton groupe, avec les réglages ci-dessous."
		elseif p.mode == "train" then
			status.Text = "🎯 L'Entraînement se joue seul : une nouvelle partie est créée."
		elseif alone then
			status.Text = "🧪 Avec des modificateurs, une nouvelle partie est créée (les autres peuvent la rejoindre)."
		else
			local n, humans = 0, 0
			local l: { any } = list or {}
			for _, m in ipairs(l) do
				if m.mode == p.mode and m.state ~= "over" and m.players < m.max then n += 1; humans += m.players end
			end
			status.Text = if n > 0 then '🌐 <font color="#7dff9f">' .. people(humans) .. "</font> en " .. modeName(p.mode) .. " : JOUER te place dans une de ces parties."
				else "🌐 Personne en " .. modeName(p.mode) .. " pour l'instant : JOUER crée une partie que les autres pourront rejoindre."
		end
	end
	showStatus(ctx.matchList)
	-- PARTIE RAPIDE : la deuxième façon de jouer, bien visible
	if not friends then
		local qb = K.btn(c3, "", "alt", function() ctx.quick(nil) end, { LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 56) })
		text(qb, { Text = "⚡  " .. spaced("PARTIE RAPIDE", 2), Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 8), Font = K.BLACK, TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Center, ZIndex = qb.ZIndex + 1 })
		text(qb, { Text = spaced("mode et carte au hasard", 1), Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 34), TextSize = 10, TextColor3 = C.dim,
			TextXAlignment = Enum.TextXAlignment.Center, ZIndex = qb.ZIndex + 1 })
		K.cut(qb, 10, K.rgb(0x0b111c))
	end

	-- parties en cours (MatchList) : joueurs humains, rejoignables
	local listBox: Frame? = nil
	local countL: TextLabel? = nil
	if not privateGame then
		local mc = K.card(c3, { LayoutOrder = 6 })
		local st = mc:FindFirstChildOfClass("UIStroke"); if st then st.Color = C.green; st.Transparency = 0.7 end
		K.vlist(mc, 6)
		local h = K.h4(mc, "🌐 PARTIES EN COURS", nil, 0, C.green)
		countL = text(h, { Text = "…", TextSize = 11, TextColor3 = C.dim, Size = UDim2.new(0.45, 0, 1, 0), Position = UDim2.fromScale(0.55, 0),
			TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false })
		K.para(mc, "Les joueurs comptés sont des vrais joueurs ; les bots ne sont pas comptés.", 11, C.dim, 1)
		local lb = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 }, mc)
		K.vlist(lb, 6)
		K.para(lb, "Recherche…", 12, C.dim)
		listBox = lb
	end
	matchToken += 1
	local myToken = matchToken
	local function fill(list: { any })
		-- pastilles des tuiles de mode
		local per: { [string]: number } = {}
		for _, m in ipairs(list) do if m.state ~= "over" then per[m.mode] = (per[m.mode] or 0) + m.players end end
		local any = false
		for id, lbl in pairs(liveBadges) do
			local n = per[id] or 0
			lbl.Visible = n > 0; lbl.Text = "👤 " .. n
			any = any or n > 0
		end
		legend.Visible = any
		showStatus(list)
		local box = listBox
		if not box then return end
		K.clear(box)
		local total = 0
		for _, m in ipairs(list) do total += m.players end
		if countL then countL.Text = people(total) .. " en ligne" end
		if #list == 0 then
			K.para(box, "Aucune partie pour l'instant. Appuie sur JOUER : ta partie apparaîtra ici pour les autres.", 12, C.dim)
			return
		end
		-- le mode choisi d'abord, puis les plus remplies
		local sorted = table.clone(list)
		table.sort(sorted, function(a, b)
			local sa, sb = (if a.mode == p.mode then 1000 else 0) + a.players, (if b.mode == p.mode then 1000 else 0) + b.players
			return sa > sb
		end)
		for i, m in ipairs(sorted) do
			if i > 8 then break end
			local mine = m.mode == p.mode
			local r = make("Frame", { Size = UDim2.new(1, 0, 0, 46), LayoutOrder = i, BackgroundTransparency = if mine then 0.9 else 0.95, BackgroundColor3 = if mine then C.green else C.white }, box)
			K.corner(r, 8); K.pad(r, 10, 0, 6, 0)
			local md = Modes.LIST[m.mode]
			local tl = if m.timeLeft and m.timeLeft >= 0 then string.format(" · %d:%02d", m.timeLeft // 60, m.timeLeft % 60) else ""
			local diff = Modes.DIFFS[m.diff or 3]
			text(r, { Size = UDim2.new(1, -112, 0, 18), Position = UDim2.fromOffset(0, 5), Font = K.BLACK, TextSize = 12, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd,
				Text = (if md then md.ic .. " " else "") .. K.esc(tostring(m.modeName)) .. '  <font color="#8da0bd">· ' .. K.esc(tostring(m.mapName)) .. "</font>" })
			text(r, { Size = UDim2.new(1, -112, 0, 14), Position = UDim2.fromOffset(0, 25), TextSize = 10, TextColor3 = C.dim, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd,
				Text = '<font color="#7dff9f">👤 ' .. m.players .. " / " .. m.max .. "</font> · bots " .. (if diff then diff.n else "") .. tl
					.. " · " .. (STATE_TEXT[tostring(m.state)] or tostring(m.state)) })
			local full = m.players >= m.max or m.state == "over"
			K.btn(r, if full then "PLEINE" else spaced("REJOINDRE", 1), if full then "dark" else "green", if full then nil else function() ctx.join(m.id) end,
				{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(100, 30), TextSize = 10 })
		end
	end
	if ctx.matchList then fill(ctx.matchList) end
	task.spawn(function()
		while area.Parent and myToken == matchToken and ctx.isOpen() do   -- (la page quitte son cadre de fondu : on suit « area »)
			local list = ctx.call("MatchList")
			if not area.Parent or myToken ~= matchToken then return end
			if typeof(list) == "table" then ctx.matchList = list; fill(list)
			elseif listBox then K.clear(listBox); K.para(listBox, "Liste indisponible pour le moment.", 12, C.dim) end
			task.wait(6)
		end
	end)

	-- ---------- réglages : seulement si une nouvelle partie est créée ----------
	local cfg = K.card(c3, { LayoutOrder = 7 })
	K.vlist(cfg, 8)
	K.h4(cfg, if privateGame then "⚙ RÉGLAGES DE LA PARTIE" else "⚙ SI UNE NOUVELLE PARTIE EST CRÉÉE", nil, 0)
	K.para(cfg, if privateGame then "Ils comptent pour la partie de ton groupe." else "Si tu rejoins une partie en cours, ce sont ses réglages qui comptent.", 11, C.dim, 0)
	local function chips(order: number, parent: Instance?): Frame
		local f = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order }, parent or cfg)
		K.hlist(f, 6, Enum.VerticalAlignment.Center, true)
		return f
	end
	-- difficulté des bots
	K.label(cfg, "NIVEAU DES BOTS", 1)
	local dRow = chips(2)
	for i, dd in ipairs(Modes.DIFFS) do
		local on = p.diff == i
		local col = K.rgb(DIFF_COL[i])
		local b = make("TextButton", { Text = spaced(K.upper(dd.n), 0), Font = K.BLACK, TextSize = 10, TextColor3 = if on then C.white else col, LayoutOrder = i,
			Size = UDim2.new(0.2, -5, 0, 36), BackgroundTransparency = 0, BackgroundColor3 = if on then col:Lerp(C.card, 0.75) else C.card, Selectable = true }, dRow)
		K.corner(b, 8); K.stroke(b, col, if on then 2 else 1, if on then 0 else 0.7)
		make("Frame", { Size = UDim2.new(1, -12, 0, 2), Position = UDim2.fromOffset(6, 0), BackgroundTransparency = 0, BackgroundColor3 = col }, b)
		K.juice(b, 0.05)
		b.Activated:Connect(function() set({ diff = i }) end)
	end
	K.para(cfg, (Modes.DIFFS[p.diff] and Modes.DIFFS[p.diff].desc) or "", 11, C.dim, 3)
	-- nombre de places
	K.label(cfg, if p.mode == "zombies" then "JOUEURS (COOP)" elseif def.team then "TAILLE DES ÉQUIPES" else "NOMBRE DE PLACES", 4)
	local sRow = chips(5)
	for i, n in ipairs(Modes.sizes(p.mode)) do
		local lab = if p.mode == "zombies" then n .. " joueur" .. (if n > 1 then "s" else "") elseif def.team then n .. " v " .. n else n .. " joueurs"
		K.chip(sRow, lab, p.size == n, function() set({ size = n }) end, { LayoutOrder = i })
	end
	-- plus d'options : camp, limite, économie, modificateurs, partie classée (rangés ici, résumés sur le bouton)
	local extras = {}
	if p.ranked and next(p.mut) == nil and X.RANKED_MODES[p.mode] then table.insert(extras, "Classé") end
	local nMut = 0; for _ in pairs(p.mut) do nMut += 1 end
	if nMut > 0 then table.insert(extras, nMut .. " modificateur" .. (if nMut > 1 then "s" else "")) end
	local more = ctx.moreOpen == true
	local mb = K.btn(cfg, (if more then "▾  " else "▸  ") .. spaced("PLUS D'OPTIONS", 2) .. (if #extras > 0 then '   <font color="#ffd23a">' .. table.concat(extras, " · ") .. "</font>" else ""),
		"ghost", function() ctx.moreOpen = not more; ctx.render() end,
		{ LayoutOrder = 6, Size = UDim2.new(1, 0, 0, 30), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, TextColor3 = C.dim })
	local mst = mb:FindFirstChildOfClass("UIStroke"); if mst then mst:Destroy() end
	make("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundTransparency = 0.92, BackgroundColor3 = C.white, Position = UDim2.fromOffset(0, -3) }, mb)
	if more then
		local o = 7
		if def.team and p.mode ~= "zombies" then
			K.label(cfg, "TON CAMP", o, C.dim); o += 1
			local r = chips(o); o += 1
			for i, sd in ipairs({ { "t", "Attaquants (T)" }, { "ct", "Défenseurs (CT)" }, { "rnd", "Au hasard" } }) do
				K.chip(r, sd[2], p.side == sd[1], function() set({ side = sd[1] }) end, { LayoutOrder = i })
			end
		end
		if #def.limits > 0 then
			K.label(cfg, K.upper(def.limitLabel), o, C.dim); o += 1
			local r = chips(o); o += 1
			for i, l in ipairs(def.limits) do K.chip(r, tostring(l), p.limit == l, function() set({ limit = l }) end, { LayoutOrder = i }) end
		end
		if p.mode == "bomb" then
			K.label(cfg, "ARGENT ET ACHATS", o, C.dim); o += 1
			local r = chips(o); o += 1
			K.chip(r, "Réaliste", p.eco == 1, function() set({ eco = 1 }) end, { LayoutOrder = 1 })
			K.chip(r, "Armes libres", p.eco == 0, function() set({ eco = 0 }) end, { LayoutOrder = 2 })
		end
		-- modificateurs
		K.label(cfg, "MODIFICATEURS", 20, C.dim)
		K.para(cfg, "Des règles amusantes. Avec un modificateur, une nouvelle partie est toujours créée.", 11, C.dim, 21)
		local mg = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 22 }, cfg)
		K.grid(mg, UDim2.new(1 / 3, -6, 0, 62), 8)
		local active = {}
		for i, mu in ipairs(Modes.MUTATORS) do
			local on = p.mut[mu.k] == true
			if on then table.insert(active, mu.ic .. " " .. mu.d) end
			local b = make("TextButton", { Text = "", LayoutOrder = i, BackgroundTransparency = 0, BackgroundColor3 = if on then C.accent:Lerp(C.card, 0.7) else C.card, Selectable = true }, mg)
			K.corner(b, 8); K.stroke(b, if on then C.accent else C.white, if on then 2 else 1, if on then 0 else 0.92)
			text(b, { Text = mu.ic, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 6), TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center })
			text(b, { Text = spaced(K.upper(mu.n), 0), Size = UDim2.new(1, -6, 0, 26), Position = UDim2.fromOffset(3, 32), TextSize = 9, Font = K.BLACK,
				TextXAlignment = Enum.TextXAlignment.Center, LineHeight = 1.0 })
			K.juice(b, 0.05)
			b.Activated:Connect(function()
				local mut = table.clone(p.mut); mut[mu.k] = if on then nil else true
				set({ mut = mut })
			end)
		end
		if #active > 0 then K.para(cfg, table.concat(active, "\n"), 11, C.dim, 23) end
		-- classé (web : cfg.ranked) : seulement dans les modes classés, désactivé avec des modificateurs
		if X.RANKED_MODES[p.mode] then
			local blocked = next(p.mut) ~= nil
			K.label(cfg, "PARTIE CLASSÉE", 24, C.dim)
			local rr = chips(25)
			local rb = K.chip(rr, (if p.ranked and not blocked then "🏆  " else "") .. spaced("CLASSÉ", 1), p.ranked == true and not blocked,
				if blocked then nil else function() set({ ranked = not p.ranked }) end, { LayoutOrder = 1, Name = "Ranked", Font = K.BLACK, TextSize = 12 }, C.gold)
			if blocked then rb.AutoButtonColor = false; rb.TextTransparency = 0.5; rb.Selectable = false end
			K.para(cfg, if blocked then "Indisponible avec des modificateurs." else "La victoire et la défaite comptent pour ton rang (PR). Tu joues avec ceux qui ont aussi choisi Classé.",
				11, C.dim, 26)
		end
	end
	-- résumé de la partie qui serait créée
	local sum = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 30, BackgroundTransparency = 0.15, BackgroundColor3 = C.panel }, cfg)
	K.corner(sum, 4); K.pad(sum, 16, 10)
	make("Frame", { Size = UDim2.new(0, 3, 1, 20), Position = UDim2.fromOffset(-16, -10), BackgroundTransparency = 0, BackgroundColor3 = C.gold }, sum)
	local size = if p.mode == "zombies" then p.size .. " joueur" .. (if p.size > 1 then "s" else "") elseif def.team then p.size .. " v " .. p.size else p.size .. " joueurs"
	local lim = if p.limit then " · " .. string.lower(def.limitLabel) .. " : " .. p.limit else ""
	K.para(sum, "<b>" .. modeName(p.mode) .. "</b> · " .. (Modes.MAP[p.map] and Modes.MAP[p.map].n or "") .. " · bots " .. Modes.DIFFS[p.diff].n .. " · " .. size .. lim
		.. (if p.ranked and next(p.mut) == nil and X.RANKED_MODES[p.mode] then " · <b>Classé</b>" else ""), 12, C.text)
end
