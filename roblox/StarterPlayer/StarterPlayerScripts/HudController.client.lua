--!strict
-- StarterPlayerScripts/HudController (LocalScript)
-- HUD du match à mort par équipe, avec la présentation du jeu web (index.html #hud, src/80_ui.js, src/8W_degats.js) :
--   haut : score des deux équipes (soldats en vie) et chrono ; dessous, la phase (« PRÉPAREZ-VOUS… »)
--   haut gauche : radar qui tourne avec le regard (carte, coéquipiers, ennemis repérés, objets) + nom du lieu
--   haut droite : fil des éliminations avec l'icône 3D de l'arme
--   bas gauche : ❤ vie et 🛡 bouclier (chiffre + jauge, traînée blanche des dégâts)
--   bas droite : emplacements d'armes et panneau de l'arme (icône, nom, munitions, balles du chargeur)
--   centre : marqueur de touche (blanc, doré à la tête, bleu sur bouclier, rouge + anneau à l'élimination),
--   chiffres de dégâts cumulés au-dessus de la cible, flèches de direction des tirs reçus, voile rouge, recharge
--   + bannière d'élimination et séries, écran de mort et réapparition, tableau des scores (Tab), écran de fin.
-- Fait pour le mode « tdm » (ModeConfig.MODE) : les événements TDMState, KillFeed… sont créés par TDMService.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local Debris = game:GetService("Debris")
local AssetService = game:GetService("AssetService")

local Config = require(ReplicatedStorage.Shared.Config)
local ModeConfig = require(ReplicatedStorage.Shared.ModeConfig)
local MapData = require(ReplicatedStorage.Shared.MapData)
local WeaponModels = require(ReplicatedStorage.Shared.WeaponModels)
local SkinPaint = require(ReplicatedStorage.Shared.SkinPaint)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local S = require(ReplicatedStorage.Shared.ClientState)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local U = Config.STUDS_PER_METER

local hitRemote = ReplicatedStorage:WaitForChild("HitFeedback") :: RemoteEvent
local damagedRemote = ReplicatedStorage:WaitForChild("Damaged") :: RemoteEvent
local stateRemote = ReplicatedStorage:WaitForChild("TDMState") :: RemoteEvent
local feedRemote = ReplicatedStorage:WaitForChild("KillFeed") :: RemoteEvent
local bannerRemote = ReplicatedStorage:WaitForChild("KillBanner") :: RemoteEvent
local deathRemote = ReplicatedStorage:WaitForChild("DeathInfo") :: RemoteEvent
local endRemote = ReplicatedStorage:WaitForChild("MatchEnd") :: RemoteEvent
local leaveFn = ReplicatedStorage:WaitForChild("MatchLeave") :: RemoteFunction
local tracerRemote = ReplicatedStorage:WaitForChild("Tracer") :: RemoteEvent

-- le tableau Tab remplace la liste des joueurs de Roblox
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end)
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)

-- ---------- palette du web (:root de index.html) ----------
local function rgb(h: number): Color3 return Color3.fromRGB(bit32.rshift(h, 16), bit32.band(bit32.rshift(h, 8), 255), bit32.band(h, 255)) end
local C = {
	bg = rgb(0x090d15), panel = rgb(0x0e131e), panel2 = rgb(0x161e2e), line = rgb(0x2a3750), text = rgb(0xe8eef9), dim = rgb(0x8da0bd),
	accent = rgb(0xff4655), gold = rgb(0xffd75e), good = rgb(0x7dff9f), blue = rgb(0x4aa3ff), orange = rgb(0xff7a4a),
	red = rgb(0xff4655), green = rgb(0x7dff9f),
	Attaquants = rgb(0xff7a4a), ["Défenseurs"] = rgb(0x4aa3ff),
}
local function teamColor(t: string?): Color3 return (t and (C :: any)[t]) or C.text end
local FONT = Enum.Font.GothamBlack
local ITALIC = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)

-- ---------- petits outils ----------
local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local o = Instance.new(class)
	if o:IsA("GuiObject") then (o :: any).BorderSizePixel = 0 end
	for k, v in pairs(props) do (o :: any)[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function corner(o: Instance, r: number?) make("UICorner", { CornerRadius = UDim.new(0, r or 3) }, o) end
local function stroke(o: Instance, color: Color3?, th: number?, tr: number?)
	make("UIStroke", { Color = color or Color3.new(0, 0, 0), Thickness = th or 1.5, Transparency = tr or 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local function label(parent: Instance, props: { [string]: any }): TextLabel
	local base = { BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextColor3 = C.text, TextSize = 16, Text = "" }
	for k, v in pairs(props) do (base :: any)[k] = v end
	return make("TextLabel", base, parent)
end
local function tween(o: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
-- lettres espacées (letter-spacing du web)
local function spaced(s: string, n: number?): string
	local gap = string.rep(" ", n or 1)   -- espace fine
	local out = {}
	for _, cp in utf8.codes(s) do table.insert(out, utf8.char(cp)) end
	return table.concat(out, gap)
end
-- fond des panneaux du web : dégradé sombre, plus transparent vers la droite
local function panelBg(o: GuiObject, vertical: boolean?)
	o.BackgroundColor3 = Color3.new(1, 1, 1)
	o.BackgroundTransparency = 0
	make("UIGradient", {
		Color = ColorSequence.new(rgb(0x121826), rgb(0x0e131e)),
		Transparency = if vertical then NumberSequence.new(0.12, 0.18) else NumberSequence.new(0.1, 0.4),
		Rotation = if vertical then 90 else 0,
	}, o)
	corner(o, 3)
end
local function playSound(def: any) Sfx.play(def) end
local function fmtTime(s: number): string return string.format("%d:%02d", s // 60, s % 60) end
local function clamp(x: number, a: number, b: number): number return math.max(a, math.min(b, x)) end

local gui = make("ScreenGui", { Name = "MatchHud", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 10, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))

-- ---------- icône 3D d'une arme (le web dessine aussi ses icônes à partir des modèles) ----------
local function weaponIcon(parent: Instance, key: string, size: Vector2, props: { [string]: any }?, skin: number?, camo: string?): ViewportFrame
	local vf = make("ViewportFrame", { Size = UDim2.fromOffset(size.X, size.Y), BackgroundTransparency = 1, Ambient = Color3.fromRGB(170, 175, 190),
		LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(0.4, -1, 0.3) }, parent)
	if props then for k, v in pairs(props) do (vf :: any)[k] = v end end
	task.spawn(function()
		if not Config.WEAPONS[key] then return end
		local ok, m = pcall(WeaponModels.build, key, 1)
		if not ok or not m or not vf.Parent then if ok and m then (m :: Model):Destroy() end return end
		local model = m :: Model
		SkinPaint.apply(model, skin, camo)
		model.Parent = vf
		local cf, ext = model:GetBoundingBox()
		local cam = Instance.new("Camera"); cam.FieldOfView = 16
		local aspect = size.X / size.Y
		local tv = math.tan(math.rad(8))
		local dist = math.max(ext.Y / 2 / tv, ext.Z / 2 / (tv * aspect)) * 1.12 + ext.X
		-- vue de côté, canon à gauche comme les icônes du web
		cam.CFrame = CFrame.lookAt(cf.Position - Vector3.new(dist, 0, 0), cf.Position)
		cam.Parent = vf; vf.CurrentCamera = cam
	end)
	return vf
end
-- partie du joueur (MatchService) : équipe, carte (dossier dans workspace) et son décalage
local function myTeam(): string?
	local t = player:GetAttribute("Team")
	if typeof(t) == "string" then return t end
	return player.Team and player.Team.Name or nil
end
local function myMapFolder(): Instance?
	local n = player:GetAttribute("MatchMap")
	return if typeof(n) == "string" then workspace:FindFirstChild(n) else workspace:FindFirstChild("Map")
end
local function mapOrigin(): Vector3
	local f = myMapFolder()
	local o = f and f:GetAttribute("Origin")
	return if typeof(o) == "Vector3" then o else Vector3.zero
end
local function mySkin(key: string): (number?, string?)
	return player:GetAttribute("Skin_" .. key) :: number?, player:GetAttribute("Camo_" .. key) :: string?
end

-- ==========================================================================================
-- Haut : score des deux équipes (soldats en vie) + chrono (#top du web)
-- ==========================================================================================
local top = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 11), Size = UDim2.fromOffset(0, 60),
	AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1 }, gui)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, top)
local function topBox(order: number, width: number): Frame
	local box = make("Frame", { Size = UDim2.fromOffset(width, 60), LayoutOrder = order }, top)
	panelBg(box, true)
	return box
end
local function teamBox(order: number): (TextLabel, TextLabel, Frame)
	local box = topBox(order, 80)
	local score = label(box, { Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 5), TextSize = 32, Font = FONT, Text = "0" })
	local alive = label(box, { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 39), TextSize = 11, Font = Enum.Font.GothamMedium,
		TextColor3 = rgb(0xaab8cf), Text = "" })
	local border = make("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 3) }, box)
	return score, alive, border
end
local scoreL, aliveL, borderL = teamBox(1)
local timerBox = topBox(2, 124)
local timerLabel = label(timerBox, { Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 5), TextSize = 32, Font = FONT, Text = "0:00" })
local goalLabel = label(timerBox, { Size = UDim2.new(1, 0, 0, 12), Position = UDim2.fromOffset(0, 40), TextSize = 10, TextColor3 = C.dim, Text = "" })
local scoreR, aliveR, borderR = teamBox(3)
local phaseLabel = label(gui, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 82), Size = UDim2.fromOffset(600, 20), TextSize = 13,
	Font = FONT, TextColor3 = C.gold, Text = "", TextStrokeTransparency = 0.55 })
-- rappel des touches, visible seulement quand le mode menu (M) est ouvert
local menuHint = label(gui, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -150), Size = UDim2.fromOffset(500, 20), TextSize = 14, TextColor3 = C.dim,
	Text = "Souris libre · M pour revenir au jeu", Visible = false })
player:GetAttributeChangedSignal("MenuOpen"):Connect(function() menuHint.Visible = player:GetAttribute("MenuOpen") == true end)

-- ==========================================================================================
-- Radar (haut gauche) : la carte tourne avec le regard, comme drawRadar() du web
-- ==========================================================================================
local RADAR = 184                 -- taille à l'écran
local RIMG = 128                  -- résolution de l'image de la carte
local RANGE = 31 * U              -- rayon couvert (31 m comme le web)
local radarWrap = make("Frame", { Position = UDim2.fromOffset(13, 13), Size = UDim2.fromOffset(RADAR, RADAR + 24), BackgroundTransparency = 1 }, gui)
local radar = make("Frame", { Size = UDim2.fromOffset(RADAR, RADAR), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, ClipsDescendants = true }, radarWrap)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, radar)
make("UIStroke", { Color = rgb(0x36476a), Thickness = 2 }, radar)
local radarImg = make("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ResampleMode = Enum.ResamplerMode.Default }, radar)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, radarImg)
local dotsLayer = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, radar)
local selfArrow = label(radar, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(16, 16), Text = "▲", TextSize = 15,
	TextColor3 = Color3.new(1, 1, 1), ZIndex = 5 })
local locLabel = label(radarWrap, { Position = UDim2.fromOffset(0, RADAR + 6), Size = UDim2.new(1, 0, 0, 14), TextSize = 11, Font = FONT, TextColor3 = C.gold,
	TextStrokeTransparency = 0.6, Text = "" })

type RadarMap = { id: string, grid: any, colors: buffer, img: EditableImage?, buf: buffer, sites: { any } }
local rmap: RadarMap? = nil
local function buildRadar(id: string)
	if rmap and rmap.id == id then return end
	if not MapData[id] then return end
	local g = MapData.buildGrid(id)
	local N, TY = MapData.N, MapData.TY
	local colors = buffer.create(N * N * 4)
	for i = 0, N * N - 1 do
		local t, r, gg, b, a = g.type[i], 70, 85, 110, 140      -- sol : rgba(70,85,110,.55) sur le fond noir à 50 %
		if g.ramp[i] ~= 0 then r, gg, b, a = 0xca, 0xa8, 0x5a, 220
		elseif t == TY.PLAT then r, gg, b, a = 0x6d, 0x8f, 0xb5, 220
		elseif t == TY.LOW or t == TY.BARREL or t == TY.CRATE then r, gg, b, a = 0x56, 0x61, 0x75, 230
		elseif t ~= 0 then r, gg, b, a = 5, 8, 13, 240
		elseif g.ceil[i] < 90 then r, gg, b, a = 50, 60, 80, 150 end
		buffer.writeu8(colors, i * 4, r); buffer.writeu8(colors, i * 4 + 1, gg); buffer.writeu8(colors, i * 4 + 2, b); buffer.writeu8(colors, i * 4 + 3, a)
	end
	local img: EditableImage? = nil
	local ok, res = pcall(function() return AssetService:CreateEditableImage({ Size = Vector2.new(RIMG, RIMG) }) end)
	if ok then img = res; radarImg.ImageContent = Content.fromObject(res) end
	rmap = { id = id, grid = g, colors = colors, img = img, buf = buffer.create(RIMG * RIMG * 4), sites = MapData[id].sites or {} }
end

-- nom du lieu (locName() du web, Village et Entrepôt)
local LOC: { [string]: (number, number, number) -> string } = {
	village = function(cx, cz, h)
		if cz <= 10 then return if cx >= 13 and cx <= 26 then "Spawn CT" elseif cx < 13 then "Accès A" else "Accès B" end
		if cz >= 29 then return if cz >= 31 and cx >= 13 and cx <= 26 then "Spawn T" else "Départ T" end
		if h > 2 then return "Hauteurs" end
		if cx <= 6 then return "Grand couloir" end
		if cx >= 33 then return if cz >= 17 and cz <= 24 then "Souk couvert" else "Couloir est" end
		if cx >= 7 and cx <= 13 then return "Ruelle" end
		if cx >= 26 and cx <= 32 then return "Rue du marché" end
		return "Place centrale"
	end,
	warehouse = function(cx, cz, h)
		if cz <= 10 then return if cx >= 13 and cx <= 26 then "Bureaux CT" elseif cx < 13 then "Vestiaires" else "Salle serveurs" end
		if cz >= 31 then return if cx >= 10 and cx <= 29 then "Quai T" elseif cx < 10 then "Couloir ouest" else "Couloir est" end
		if h > 2 then return "Mezzanine" end
		if cx <= 9 then return "Stockage" end
		if cx >= 30 then return "Contrôle" end
		return "Halle centrale"
	end,
}
local function locName(pos: Vector3): string
	local m = rmap
	if not m then return "" end
	local cs = Config.CELL * U
	local lp = pos - mapOrigin()
	local cx, cz = math.floor(lp.X / cs), math.floor(lp.Z / cs)
	for _, s in ipairs(m.sites) do
		if Vector2.new(cx + 0.5 - s.cx, cz + 0.5 - s.cz).Magnitude < (s.r or 7) then return "Site " .. s.n end
	end
	local fn = LOC[m.id]
	return if fn then fn(cx, cz, pos.Y / U) else ""
end

-- points du radar (réutilisés d'une image à l'autre)
local dotPool: { Frame } = {}
local function dotAt(i: number): Frame
	local d = dotPool[i]
	if not d then
		d = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 10), ZIndex = 3 }, dotsLayer)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, d)
		make("UIStroke", { Name = "Ring", Color = Color3.new(1, 1, 1), Thickness = 1.5, Enabled = false }, d)
		local holder = make("Frame", { Name = "Dir", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1 }, d)
		make("Frame", { Name = "Line", AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(2.5, 14) }, holder)
		dotPool[i] = d
	end
	return d
end

local spotted: { [Instance]: number } = {}     -- ennemis repérés parce qu'ils tirent
tracerRemote.OnClientEvent:Connect(function(_o: Vector3, _e: Vector3, shooter: Instance?)
	if shooter then spotted[shooter] = os.clock() + 2.2 end
end)

-- soldats de MA partie (plusieurs parties tournent en même temps sur le serveur)
local function soldierList(): { { model: Model, team: string?, alive: boolean } }
	local out = {}
	local mid = player:GetAttribute("MatchId")
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if c and h and p:GetAttribute("MatchId") == mid and mid ~= nil then
			local t = p:GetAttribute("Team")
			table.insert(out, { model = c, team = if typeof(t) == "string" then t else nil, alive = h.Health > 0 })
		end
	end
	local bots = workspace:FindFirstChild("Bots")
	if bots then
		for _, b in ipairs(bots:GetChildren()) do
			local h = b:FindFirstChildOfClass("Humanoid")
			if b:IsA("Model") and h and b:GetAttribute("MatchId") == mid then
				table.insert(out, { model = b, team = b:GetAttribute("Team") :: string?, alive = h.Health > 0 })
			end
		end
	end
	return out
end

local radarAcc = 0
local function drawRadar(dt: number)
	radarAcc += dt
	local m = rmap
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not m or not root then return end
	local pos = root.Position
	local O = mapOrigin()
	local look = camera.CFrame.LookVector
	local fwd = Vector3.new(look.X, 0, look.Z)
	if fwd.Magnitude < 1e-3 then fwd = Vector3.new(0, 0, -1) end
	fwd = fwd.Unit
	local right = Vector3.new(-fwd.Z, 0, fwd.X)
	local half = RADAR / 2
	local pps = half / RANGE                    -- pixels d'écran par stud
	-- carte (image recalculée ~15 fois par seconde)
	if m.img and radarAcc >= 1 / 15 then
		radarAcc = 0
		local N = MapData.N
		local cs = Config.CELL * U
		local buf, colors = m.buf, m.colors
		local k = RANGE / (RIMG / 2)            -- studs par pixel de l'image
		local c0 = RIMG / 2 - 0.5
		for py = 0, RIMG - 1 do
			local dy = py - c0
			-- monde = pos + right * dx * k - fwd * dy * k
			local wx0 = pos.X - O.X - fwd.X * dy * k - right.X * c0 * k
			local wz0 = pos.Z - O.Z - fwd.Z * dy * k - right.Z * c0 * k
			local sx, sz = right.X * k, right.Z * k
			for px = 0, RIMG - 1 do
				local o = (py * RIMG + px) * 4
				local dx = px - c0
				local r2 = dx * dx + dy * dy
				if r2 > c0 * c0 then
					buffer.writeu32(buf, o, 0)
				else
					local cx, cz = (wx0 + sx * px) // cs, (wz0 + sz * px) // cs
					if cx < 0 or cz < 0 or cx >= N or cz >= N then
						buffer.writeu32(buf, o, 0)
					else
						buffer.writeu32(buf, o, buffer.readu32(colors, (cz * N + cx) * 4))
						-- cône de vision
						if dy < 0 and r2 < 1400 and math.abs(dx) < -dy * 0.85 then
							buffer.writeu8(buf, o, math.min(255, buffer.readu8(buf, o) + 26))
							buffer.writeu8(buf, o + 1, math.min(255, buffer.readu8(buf, o + 1) + 26))
							buffer.writeu8(buf, o + 2, math.min(255, buffer.readu8(buf, o + 2) + 26))
						end
					end
				end
			end
		end
		(m.img :: EditableImage):WritePixelsBuffer(Vector2.zero, Vector2.new(RIMG, RIMG), buf)
	end
	-- coéquipiers, ennemis repérés, objets
	local n = 0
	local mine = myTeam()
	local now = os.clock()
	local function place(at: Vector3, col: Color3, size: number, ring: boolean, dir: Vector3?)
		local rel = at - pos
		local x, y = rel:Dot(right) * pps, -rel:Dot(fwd) * pps
		if x * x + y * y > (half - 4) ^ 2 then return end
		n += 1
		local d = dotAt(n)
		d.Visible = true; d.BackgroundColor3 = col; d.Size = UDim2.fromOffset(size, size)
		d.Position = UDim2.fromOffset(half + x, half + y)
		local ringS = d:FindFirstChild("Ring") :: UIStroke
		ringS.Enabled = ring
		local holder = d:FindFirstChild("Dir") :: Frame
		holder.Visible = dir ~= nil
		if dir then
			local a = math.deg(math.atan2(dir:Dot(right), dir:Dot(fwd)))
			holder.Rotation = a
			local line = holder:FindFirstChild("Line") :: Frame
			line.BackgroundColor3 = col
		end
	end
	for _, s in ipairs(soldierList()) do
		local r = s.model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if r and s.alive and s.model ~= char then
			if mine and s.team == mine and (mine:sub(1, 5) ~= "solo:") then
				local lv = r.CFrame.LookVector
				place(r.Position, teamColor(s.team), 11, false, Vector3.new(lv.X, 0, lv.Z))
			elseif (spotted[s.model] or 0) > now then
				place(r.Position, rgb(0xff2a2a), 12, true, nil)
			end
		end
	end
	local folder = myMapFolder() or workspace
	for _, p in ipairs(folder:GetDescendants()) do
		if p:IsA("Model") and p:GetAttribute("Pickup") and p:GetAttribute("Ready") ~= false then
			local kind = p:GetAttribute("Pickup")
			local core = p.PrimaryPart
			if core then
				local col = if kind == "shield" then rgb(0x31c8ff) elseif kind == "health" then rgb(0xff4a5a) elseif kind == "tag" then (if p:GetAttribute("TagTeam") == mine then rgb(0x7dd8ff) else rgb(0xffd23a)) else rgb(0xffd24a)
				place(core.Position, col, 7, false, nil)
			end
		end
	end
	for i = n + 1, #dotPool do dotPool[i].Visible = false end
	locLabel.Text = spaced(string.upper(locName(pos)), 2)
end

-- ==========================================================================================
-- Fil des éliminations (haut droite, #feed du web)
-- ==========================================================================================
local feed = make("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -13, 0, 13), Size = UDim2.fromOffset(460, 220), BackgroundTransparency = 1 }, gui)
make("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, feed)
local feedOrder = 0
local WEAPON_KEY_BY_NAME: { [string]: string } = {}
for k, w in pairs(Config.WEAPONS) do WEAPON_KEY_BY_NAME[w.name] = k end
feedRemote.OnClientEvent:Connect(function(k: any)
	if player:GetAttribute("Zone") == "lobby" or player:GetAttribute("Zone") == "duel" then return end   -- fil du match à mort : seulement pour ceux qui y jouent
	feedOrder += 1
	local me = player.DisplayName
	local involved = k.killer == me or k.victim == me
	local row = make("Frame", { Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = feedOrder,
		BackgroundColor3 = if involved then rgb(0x3c0c14) else C.bg, BackgroundTransparency = if involved then 0.15 else 0.2 }, feed)
	if involved then stroke(row, C.accent, 1, 0) end
	make("UIPadding", { PaddingLeft = UDim.new(0, 11), PaddingRight = UDim.new(0, 14) }, row)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder }, row)
	make("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 14, 0, 0), Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = teamColor(k.killerTeam) }, row)
	local order = 0
	local function part(text: string, color: Color3)
		order += 1
		label(row, { Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, Text = text, TextColor3 = color, TextSize = 13, LayoutOrder = order })
	end
	part(k.killer, teamColor(k.killerTeam))
	local key = WEAPON_KEY_BY_NAME[k.weapon]
	order += 1
	if key then weaponIcon(row, key, Vector2.new(52, 19), { LayoutOrder = order })
	else part("[" .. tostring(k.weapon) .. "]", C.dim) end
	if k.headshot then part("✦", C.gold) end
	part(k.victim, teamColor(k.victimTeam))
	-- au plus 6 lignes, chaque ligne s'efface après 7 s
	local rows = {}
	for _, c in ipairs(feed:GetChildren()) do if c:IsA("Frame") then table.insert(rows, c) end end
	table.sort(rows, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	while #rows > 6 do (table.remove(rows, 1) :: Instance):Destroy() end
	task.delay(7, function()
		if not row.Parent then return end
		tween(row, 0.4, { BackgroundTransparency = 1 })
		for _, c in ipairs(row:GetDescendants()) do
			if c:IsA("TextLabel") then tween(c, 0.4, { TextTransparency = 1 }) elseif c:IsA("ViewportFrame") then tween(c, 0.4, { ImageTransparency = 1 }) end
		end
		Debris:AddItem(row, 0.45)
	end)
end)

-- ==========================================================================================
-- Bas gauche : ❤ vie et 🛡 bouclier (.vital du web)
-- ==========================================================================================
local vitals = make("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 19, 1, -16), Size = UDim2.fromOffset(228, 108), BackgroundTransparency = 1 }, gui)
make("UIListLayout", { Padding = UDim.new(0, 7), VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder }, vitals)
local function vital(order: number, icon: string, c1: Color3, c2: Color3): (TextLabel, Frame, Frame, Frame)
	local row = make("Frame", { Size = UDim2.fromOffset(228, 50), LayoutOrder = order }, vitals)
	panelBg(row)
	make("Frame", { Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.87 }, row)
	label(row, { Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(22, 50), Text = icon, TextSize = 19 })
	local num = label(row, { Position = UDim2.fromOffset(42, 0), Size = UDim2.fromOffset(62, 50), Text = "0", TextSize = 40, Font = FONT,
		TextXAlignment = Enum.TextXAlignment.Left })
	local meter = make("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 112, 0.5, 0), Size = UDim2.new(1, -126, 0, 9), BackgroundColor3 = rgb(0x0a0f18) }, row)
	local ghost = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.25 }, meter)
	local fill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 2 }, meter)
	local grad = make("UIGradient", { Color = ColorSequence.new(c1, c2) }, fill)
	grad.Name = "Grad"
	return num, fill, ghost, row
end
local hpText, hpBar, hpGhost = vital(1, "❤", rgb(0xff4655), rgb(0xff8a65))
local shieldText, shieldBar = vital(2, "🛡", rgb(0x16b8ff), rgb(0x9af0ff))
local protectLabel = label(gui, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 21, 1, -130), Size = UDim2.fromOffset(240, 18), TextSize = 13,
	TextColor3 = rgb(0x96dcff), TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextStrokeTransparency = 0.6 })

-- ==========================================================================================
-- Bas droite : emplacements + panneau de l'arme (#slots et #wpanel du web)
-- ==========================================================================================
local br = make("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -19, 1, -16), Size = UDim2.fromOffset(330, 130), BackgroundTransparency = 1 }, gui)
make("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Bottom,
	SortOrder = Enum.SortOrder.LayoutOrder }, br)
local slotRow = make("Frame", { Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, LayoutOrder = 1 }, br)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, slotRow)
type Slot = { frame: Frame, num: TextLabel, icon: ViewportFrame?, key: string?, skin: string, border: UIStroke }
local slots: { Slot } = {}
for i = 1, 3 do
	local f = make("Frame", { Size = UDim2.fromOffset(74, 26), BackgroundColor3 = C.bg, BackgroundTransparency = 0.22, LayoutOrder = i, Visible = false }, slotRow)
	local num = label(f, { Position = UDim2.fromOffset(7, 0), Size = UDim2.fromOffset(10, 26), Text = tostring(i), TextSize = 11, TextColor3 = C.dim })
	local b = make("UIStroke", { Color = C.accent, Thickness = 1, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, f)
	slots[i] = { frame = f, num = num, icon = nil, key = nil, skin = "", border = b }
end
local wpanel = make("Frame", { Size = UDim2.fromOffset(310, 88), LayoutOrder = 2 }, br)
panelBg(wpanel)
make("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = C.accent }, wpanel)
local wIconHolder = make("Frame", { Position = UDim2.fromOffset(14, 16), Size = UDim2.fromOffset(120, 52), BackgroundTransparency = 1 }, wpanel)
local wName = label(wpanel, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 8), Size = UDim2.fromOffset(160, 14), TextSize = 11, TextColor3 = C.dim,
	TextXAlignment = Enum.TextXAlignment.Left })
local magText = label(wpanel, { Position = UDim2.new(1, -176, 0, 22), Size = UDim2.fromOffset(0, 44), AutomaticSize = Enum.AutomaticSize.X, TextSize = 45, Font = FONT,
	TextXAlignment = Enum.TextXAlignment.Left, Text = "" })
local reserveText = label(wpanel, { Position = UDim2.new(1, -176, 0, 36), Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, TextSize = 21,
	TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, Text = "" })
local pips = make("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 70), Size = UDim2.fromOffset(160, 6), BackgroundTransparency = 1 }, wpanel)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 2) }, pips)
local pipList: { Frame } = {}
local panelKey, panelSkin, pipMax = "", "", -1

-- ==========================================================================================
-- Centre : marqueur de touche, chiffres de dégâts, direction des tirs, voiles, recharge (src/8W_degats.js)
-- ==========================================================================================
local center = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1 }, gui)
local dot = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(4, 4), BackgroundColor3 = C.text, Visible = ModeConfig.CENTER_DOT }, center)
corner(dot, 2); stroke(dot, Color3.new(0, 0, 0), 1, 0.4)

local hitmarker = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 6 }, center)
local hmLines: { Frame } = {}
local hmHolders: { Frame } = {}
for i, rot in ipairs({ 45, 135, 225, 315 }) do
	local holder = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(0, 0), Rotation = rot, BackgroundTransparency = 1 }, hitmarker)
	hmLines[i] = make("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(0, -7), Size = UDim2.fromOffset(3, 11), BackgroundColor3 = C.text, ZIndex = 6 }, holder)
	corner(hmLines[i], 2); stroke(hmLines[i], Color3.new(0, 0, 0), 1, 0.3)
	hmHolders[i] = holder
end
local hmRing = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(44, 44), BackgroundTransparency = 1, Visible = false, ZIndex = 6 }, center)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, hmRing)
local hmRingStroke = make("UIStroke", { Color = rgb(0xff3b47), Thickness = 2 }, hmRing)
local hmToken = 0
local function showHitmarker(head: boolean, kill: boolean, shieldOnly: boolean)
	hmToken += 1
	local my = hmToken
	local col = if kill then rgb(0xff3b47) elseif shieldOnly then rgb(0x5fd6ff) elseif head then rgb(0xffd23f) else C.text
	local dur = if kill then 0.55 elseif head then 0.4 else 0.3
	hitmarker.Visible = true
	for _, l in ipairs(hmLines) do
		l.BackgroundColor3 = col; l.BackgroundTransparency = 0
		l.Size = UDim2.fromOffset(if kill then 4 else 3, if kill then 15 else 11)
		l.Position = UDim2.fromOffset(0, -13)
		tween(l, dur * 0.18, { Position = UDim2.fromOffset(0, -6) })
		task.delay(dur * 0.18, function()
			if my ~= hmToken then return end
			tween(l, dur * 0.82, { Position = UDim2.fromOffset(0, -9), BackgroundTransparency = 1 })
		end)
	end
	if kill then
		hmRing.Visible = true; hmRing.Size = UDim2.fromOffset(15, 15); hmRingStroke.Transparency = 0.05
		tween(hmRing, 0.45, { Size = UDim2.fromOffset(66, 66) }); tween(hmRingStroke, 0.45, { Transparency = 1 })
	end
	task.delay(dur + 0.05, function() if my == hmToken then hitmarker.Visible = false; hmRing.Visible = false end end)
end

-- voile rouge des dégâts (dégradé vers les bords) et vignette de vie basse
local function edgeVeil(color: Color3, z: number): { Frame }
	local list = {}
	local specs: { { any } } = { { UDim2.fromScale(1, 0.32), UDim2.fromScale(0, 0), 90 }, { UDim2.fromScale(1, 0.32), UDim2.fromScale(0, 0.68), -90 },
		{ UDim2.fromScale(0.22, 1), UDim2.fromScale(0, 0), 0 }, { UDim2.fromScale(0.22, 1), UDim2.fromScale(0.78, 0), 180 } }
	for i, spec in ipairs(specs) do
		local f = make("Frame", { Size = spec[1], Position = spec[2], BackgroundColor3 = color, BackgroundTransparency = 1, ZIndex = z }, gui)
		make("UIGradient", { Rotation = spec[3], Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) }, f)
		list[i] = f
	end
	return list
end
local hurtVeil = edgeVeil(rgb(0xaa0000), 0)
local lowVeil = edgeVeil(rgb(0xb40000), 0)
local function setVeil(list: { Frame }, alpha: number)
	for _, f in ipairs(list) do f.BackgroundTransparency = 1 - clamp(alpha, 0, 1) end
end
local hurtAlpha = 0

-- direction des tirs reçus : l'arc suit la position du tireur quand on se retourne
type Dir = { holder: Frame, arc: Frame, chev: TextLabel, from: Vector3, att: Instance?, t: number, k: number }
local dirs: { Dir } = {}
for i = 1, 6 do
	local holder = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, ZIndex = 5 }, center)
	local arc = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(0, -146), Size = UDim2.fromOffset(112, 9), BackgroundColor3 = rgb(0xff2636),
		BackgroundTransparency = 1, ZIndex = 5 }, holder)
	corner(arc, 5)
	make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }, arc)
	local chev = label(holder, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(0, -161), Size = UDim2.fromOffset(26, 16), Text = "▲", TextSize = 16,
		TextColor3 = rgb(0xff3442), TextTransparency = 1, ZIndex = 5 })
	dirs[i] = { holder = holder, arc = arc, chev = chev, from = Vector3.zero, att = nil, t = 9, k = 0 }
end
local function damageIndicator(fromPos: Vector3, att: Instance?, dmg: number)
	local k = math.min(1, 0.35 + dmg / 45)
	local slot: Dir? = nil
	for _, d in ipairs(dirs) do if att and d.att == att and d.t < 1.4 then slot = d end end
	if not slot then
		slot = dirs[1]
		for _, d in ipairs(dirs) do if d.t > (slot :: any).t then slot = d end end
	end
	local s = (slot :: any) :: Dir
	s.k = math.max(if s.t < 1.4 then s.k else 0, k); s.from = fromPos; s.att = att; s.t = 0
end

-- chiffres de dégâts au-dessus de la cible : cumulés tant que les touches s'enchaînent (doré = tête, bleu = bouclier, rouge = élimination)
type Num = { bb: BillboardGui, txt: TextLabel, total: number, hs: boolean, sh: boolean, kill: boolean, t0: number, tu: number, bump: number, target: Instance?, anchor: BasePart }
local nums: { Num } = {}
local function damageNumber(pos: Vector3, dmg: number, head: boolean, kill: boolean, shieldOnly: boolean, target: Instance?)
	local t = os.clock()
	local o: Num? = nil
	for _, n in ipairs(nums) do if n.target == target and t - n.tu < 0.65 and not n.kill then o = n end end
	if not o then
		local anchor = make("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2),
			Position = pos + Vector3.new(0, 2.05 * U * 0.8, 0) }, workspace)
		local bb = make("BillboardGui", { Adornee = anchor, Size = UDim2.fromOffset(160, 60), AlwaysOnTop = true, LightInfluence = 0,
			StudsOffsetWorldSpace = Vector3.zero }, anchor)
		local txt = label(bb, { Size = UDim2.fromScale(1, 1), FontFace = ITALIC, TextSize = 22, Text = "", RichText = true })
		make("UIStroke", { Thickness = 1.5, Transparency = 0.15 }, txt)
		o = { bb = bb, txt = txt, total = 0, hs = false, sh = true, kill = false, t0 = t, tu = t, bump = 0, target = target, anchor = anchor }
		table.insert(nums, (o :: any) :: Num)
	end
	local n = (o :: any) :: Num
	n.total += dmg; n.hs = n.hs or head; n.sh = n.sh and shieldOnly; n.tu = t; n.bump = 1
	if kill then n.kill = true end
	n.txt.TextColor3 = if n.kill then rgb(0xff4655) elseif n.hs then rgb(0xffd23f) elseif n.sh then rgb(0x5fd6ff) else Color3.new(1, 1, 1)
	n.txt.Text = tostring(math.floor(n.total + 0.5)) .. (if n.kill then '<font size="13"> ☠</font>' elseif n.hs then '<font size="13"> ✦</font>' else "")
	n.txt.TextSize = math.min(40, 20 + math.sqrt(n.total) * 1.5 + (if n.hs then 4 else 0) + (if n.kill then 5 else 0))
	if target and target:IsA("Model") then
		local head = target:FindFirstChild("Head") :: BasePart?
		if head then n.anchor.Position = head.Position + Vector3.new(0, 1.6, 0) end
	end
end
local function updateNumbers(dt: number)
	local t = os.clock()
	for i = #nums, 1, -1 do
		local n = nums[i]
		local age, life = t - n.tu, t - n.t0
		if age > 1.05 then n.anchor:Destroy(); table.remove(nums, i); continue end
		n.bump = math.max(0, n.bump - dt * 7)
		local rise = math.min(life, 1.6) * 26 + age * 30
		n.bb.StudsOffset = Vector3.new(0, rise / 60, 0)
		n.txt.TextTransparency = if age < 0.7 then 0 else (age - 0.7) / 0.35
		local sc = (1 + n.bump * 0.45) * (if life < 0.08 then 1.6 - life * 7.5 else 1)
		n.bb.Size = UDim2.fromOffset(160 * sc, 60 * sc)
	end
end

-- recharge : petite barre sous le viseur
local relBar = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(0, 46), Size = UDim2.fromOffset(84, 4), BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0.88, Visible = false }, center)
corner(relBar, 3)
local relFill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.5 }, relBar)
corner(relFill, 3)

hitRemote.OnClientEvent:Connect(function(head: boolean, kill: boolean, dmg: number?, pos: Vector3?, shieldOnly: boolean?, target: Instance?)
	showHitmarker(head, kill, shieldOnly == true)
	playSound(if kill then ModeConfig.SOUNDS.kill elseif shieldOnly then "shield" elseif head then ModeConfig.SOUNDS.hitHead else ModeConfig.SOUNDS.hitBody)
	if dmg and pos then damageNumber(pos, dmg, head, kill, shieldOnly == true, target) end
end)

damagedRemote.OnClientEvent:Connect(function(fromPos: Vector3, dmg: number, _head: boolean, shieldOnly: boolean?, shieldBroke: boolean?, att: Instance?)
	if fromPos.Magnitude > 0 then damageIndicator(fromPos, att, dmg) end
	playSound(if shieldOnly then "shield" else ModeConfig.SOUNDS.hurt)
	if shieldBroke then playSound("shieldbreak") end
	hurtAlpha = math.max(hurtAlpha, math.min(0.95, 0.25 + dmg / 50) * (if shieldOnly then 0.4 else 1))
end)

-- ==========================================================================================
-- Bannière d'élimination (#killmsg) et séries (#banner)
-- ==========================================================================================
local killMsg = label(gui, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.fromOffset(700, 26), TextSize = 18, Font = FONT,
	RichText = true, TextTransparency = 1, TextStrokeTransparency = 1, Text = "" })
local killScale = make("UIScale", { Scale = 1 }, killMsg)
local streakLabel = label(gui, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.2), Size = UDim2.fromOffset(900, 64), TextSize = 56, Font = FONT,
	TextColor3 = C.text, TextTransparency = 1, Text = "", RichText = true })
make("UIStroke", { Thickness = 3, Transparency = 0.35, Color = rgb(0x3a0a10) }, streakLabel)
local streakScale = make("UIScale", { Scale = 1 }, streakLabel)
local bannerToken = 0
bannerRemote.OnClientEvent:Connect(function(b: any)
	bannerToken += 1
	local my = bannerToken
	killMsg.Text = spaced((if b.headshot then "TIR À LA TÊTE" else "ÉLIMINATION") .. "  +" .. b.points, 1) .. '   <font color="#ffd75e">' .. tostring(b.victim) .. "</font>"
		.. (if b.streak >= 2 then '   <font color="#8da0bd">' .. b.streak .. " d'affilée</font>" else "")
	killMsg.TextTransparency = 0; killMsg.TextStrokeTransparency = 0.5
	killScale.Scale = 1.3
	tween(killScale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(1.8, function()
		if my ~= bannerToken then return end
		tween(killMsg, 0.3, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	if b.streakName then
		streakLabel.Text = spaced(string.upper(b.streakName), 2) .. '\n<font size="19" color="#ffd75e">' .. spaced(b.streak .. " ÉLIMINATIONS D'AFFILÉE", 1) .. "</font>"
		streakLabel.TextTransparency = 0; streakScale.Scale = 1.3
		tween(streakScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		playSound(ModeConfig.SOUNDS.streak)
		task.delay(2.2, function() tween(streakLabel, 0.5, { TextTransparency = 1 }) end)
	end
end)

-- ==========================================================================================
-- Écran de mort + réapparition (#respawn du web)
-- ==========================================================================================
local deathFrame = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(30, 0, 5), BackgroundTransparency = 1, Visible = false, ZIndex = 5 }, gui)
local deathTitle = label(deathFrame, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.fromOffset(700, 26), TextSize = 18, Font = FONT,
	ZIndex = 6, RichText = true, TextStrokeTransparency = 0.5, Text = "" })
local respawnNum = label(deathFrame, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromOffset(300, 70), TextSize = 64, Font = FONT,
	ZIndex = 6, TextStrokeTransparency = 0.6, Text = "" })
label(deathFrame, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.36, 74), Size = UDim2.fromOffset(700, 20), TextSize = 14, Font = FONT, ZIndex = 6,
	TextColor3 = C.gold, TextStrokeTransparency = 0.6, Text = spaced("RÉAPPARITION — B : CHOISIR UNE ARME", 1) })
deathRemote.OnClientEvent:Connect(function(d: any)
	deathFrame.Visible = true; deathFrame.BackgroundTransparency = 1
	tween(deathFrame, 0.4, { BackgroundTransparency = 0.6 })
	deathTitle.Text = spaced("ÉLIMINÉ PAR", 1) .. '  <font color="#ffd75e">' .. tostring(d.killer) .. "</font>   " .. '<font color="#8da0bd">' .. tostring(d.weapon)
		.. (if d.headshot then " · tête" else "") .. "</font>"
	local left = d.respawn
	task.spawn(function()
		while left > 0 and deathFrame.Visible do
			respawnNum.Text = tostring(left)
			task.wait(1); left -= 1
		end
		respawnNum.Text = ""
	end)
end)

-- ==========================================================================================
-- Tableau des scores (Tab)
-- ==========================================================================================
local board = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(820, 460), BackgroundColor3 = C.bg,
	BackgroundTransparency = 0.08, Visible = false, ZIndex = 20 }, gui)
corner(board, 6); stroke(board, C.line, 1.5, 0.2)
local boardScale = make("UIScale", { Scale = 1 }, board)
label(board, { Position = UDim2.fromOffset(20, 12), Size = UDim2.new(1, -40, 0, 26), TextSize = 18, Font = FONT, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21,
	Text = spaced("MATCH À MORT PAR ÉQUIPE", 1) })
local boardTitle = board:FindFirstChildOfClass("TextLabel") :: TextLabel
local boardInfo = label(board, { Position = UDim2.fromOffset(20, 12), Size = UDim2.new(1, -40, 0, 26), TextSize = 14, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 21 })
local columns: { Frame } = {}
for i = 1, 2 do
	local col = make("Frame", { Position = UDim2.new((i - 1) * 0.5, if i == 1 then 16 else 8, 0, 50), Size = UDim2.new(0.5, -24, 1, -66), BackgroundTransparency = 1, ZIndex = 21 }, board)
	make("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, col)
	columns[i] = col
end
local function boardRow(parent: Instance, order: number, cells: { string }, color: Color3, bg: Color3?, bold: boolean?)
	local row = make("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = bg or C.panel2, BackgroundTransparency = if bg then 0.1 else 0.35, LayoutOrder = order, ZIndex = 21 }, parent)
	corner(row, 3)
	local widths = { 0.46, 0.12, 0.12, 0.12, 0.18 }
	local x = 0
	for i, text in ipairs(cells) do
		label(row, { Position = UDim2.new(x, if i == 1 then 10 else 0, 0, 0), Size = UDim2.new(widths[i], if i == 1 then -10 else 0, 1, 0), Text = text, ZIndex = 22,
			TextSize = if i == 1 then 14 else 13, TextColor3 = if i == 1 then color else C.text, Font = if bold then FONT else Enum.Font.GothamBold,
			TextXAlignment = if i == 1 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd })
		x += widths[i]
	end
end
local lastState: any = nil
local function renderBoard()
	local st = lastState
	if not st then return end
	for _, col in ipairs(columns) do for _, c in ipairs(col:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end end
	boardTitle.Text = spaced(string.upper(st.modeName or "Match à mort par équipe"), 1)
	boardInfo.Text = st.mapName .. (if st.timeLeft >= 0 then "   ·   " .. fmtTime(st.timeLeft) else "") .. (if st.killsToWin then "   ·   premier à " .. st.killsToWin else "")
	if not st.team then
		-- chacun pour soi : une seule liste, classée par points du mode (éliminations, niveau, points du Mastodonte…)
		local list = table.clone(st.board)
		table.sort(list, function(a: any, b: any) return (a.pts or 0) > (b.pts or 0) or ((a.pts or 0) == (b.pts or 0) and a.score > b.score) end)
		for ci, col in ipairs(columns) do
			boardRow(col, 0, { if ci == 1 then "JOUEUR" else "JOUEUR", "É", "M", "PTS", "SCORE" }, C.gold, rgb(0x1e2434), true)
		end
		for i, e in ipairs(list) do
			local col = columns[if i <= math.ceil(#list / 2) then 1 else 2]
			local isMe = e.userId == player.UserId
			boardRow(col, i, { i .. ". " .. (if e.bot then "[BOT] " else "") .. e.name, tostring(e.k), tostring(e.d), tostring(e.pts or 0), tostring(e.score) },
				if isMe then C.gold else C.text, if isMe then rgb(0x3c3418) else nil)
		end
		return
	end
	for i, team in ipairs(st.teams) do
		local col = columns[i]
		boardRow(col, 0, { string.upper(team) .. "   " .. (st.score[team] or 0), "É", "M", "A", "SCORE" }, teamColor(team), rgb(0x1e2434), true)
		local n = 0
		for _, e in ipairs(st.board) do
			if e.team == team then
				n += 1
				local mine = e.userId == player.UserId
				boardRow(col, n, { (if e.bot then "[BOT] " else "") .. e.name .. (if e.bot then "" else "  · " .. e.ping .. " ms"), tostring(e.k), tostring(e.d), tostring(e.a), tostring(e.score) },
					if mine then C.gold else C.text, if mine then rgb(0x3c3418) else nil)
			end
		end
	end
end
local function showBoard(on: boolean)
	if on == board.Visible then return end
	if on then
		renderBoard(); board.Visible = true; boardScale.Scale = 0.94
		tween(boardScale, 0.14, { Scale = 1 }, Enum.EasingStyle.Back)
	else
		board.Visible = false
	end
end
UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Tab or input.KeyCode == Enum.KeyCode.ButtonSelect then showBoard(true) end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Tab or input.KeyCode == Enum.KeyCode.ButtonSelect then showBoard(false) end
end)
-- bouton tactile pour les téléphones
if UserInputService.TouchEnabled then
	local btn = make("TextButton", { AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromOffset(16, RADAR + 46), Size = UDim2.fromOffset(90, 34), BackgroundColor3 = C.bg,
		BackgroundTransparency = 0.25, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = C.text, Text = "Scores" }, gui)
	corner(btn, 3)
	btn.Activated:Connect(function() showBoard(not board.Visible) end)
end

-- ==========================================================================================
-- Écran de fin de partie
-- ==========================================================================================
local endFrame = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(5, 8, 14), BackgroundTransparency = 1, Visible = false, ZIndex = 30 }, gui)
local endTitle = label(endFrame, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.24), Size = UDim2.fromOffset(900, 90), TextSize = 84, Font = FONT, ZIndex = 31 })
make("UIStroke", { Thickness = 3, Transparency = 0.3 }, endTitle)
local endTitleScale = make("UIScale", { Scale = 1 }, endTitle)
local endScore = label(endFrame, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.34), Size = UDim2.fromOffset(600, 40), TextSize = 30, ZIndex = 31 })
local endCards = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(760, 150), BackgroundTransparency = 1, ZIndex = 31 }, endFrame)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 14) }, endCards)
local endNext = label(endFrame, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40), Size = UDim2.fromOffset(600, 24), TextSize = 16, TextColor3 = C.dim, ZIndex = 31 })

-- bouton « Quitter la partie » (web : écran de fin -> Menu) ; Modal libère la souris en vue à la 1re personne
local endLeave = make("TextButton", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -76), Size = UDim2.fromOffset(240, 40),
	BackgroundColor3 = C.panel2, BackgroundTransparency = 0.1, Text = spaced("QUITTER LA PARTIE", 1), TextColor3 = C.text, TextSize = 15, Font = FONT,
	AutoButtonColor = true, Modal = true, ZIndex = 32 }, endFrame)
corner(endLeave, 4)
make("UIStroke", { Color = C.red, Thickness = 1.5, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, endLeave)
endLeave.Activated:Connect(function()
	endLeave.Text = spaced("RETOUR AU SALON…", 1)
	local ok = pcall(function() leaveFn:InvokeServer() end)
	endLeave.Text = spaced("QUITTER LA PARTIE", 1)
	if ok then endFrame.Visible = false end
end)

local function card(title: string, lines: { string }, accent: Color3, delay: number)
	local f = make("Frame", { Size = UDim2.fromOffset(240, 150), BackgroundColor3 = C.panel2, BackgroundTransparency = 1, ZIndex = 31 }, endCards)
	corner(f, 4)
	local st = make("UIStroke", { Color = accent, Thickness = 1.5, Transparency = 1 }, f)
	local t = label(f, { Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 20), TextSize = 13, TextColor3 = accent, TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1, ZIndex = 32, Text = spaced(string.upper(title), 1) })
	local items = {}
	for i, l in ipairs(lines) do
		table.insert(items, label(f, { Position = UDim2.fromOffset(16, 14 + i * 24), Size = UDim2.new(1, -32, 0, 22), TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1, ZIndex = 32, Text = l }))
	end
	task.delay(delay, function()
		tween(f, 0.3, { BackgroundTransparency = 0.1 }); tween(st, 0.3, { Transparency = 0.2 }); tween(t, 0.3, { TextTransparency = 0 })
		for i, it in ipairs(items) do task.delay(i * 0.08, function() tween(it, 0.25, { TextTransparency = 0 }) end) end
	end)
end

endRemote.OnClientEvent:Connect(function(r: any)
	showBoard(false)
	deathFrame.Visible = false
	for _, c in ipairs(endCards:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
	endFrame.Visible = true; endFrame.BackgroundTransparency = 1
	tween(endFrame, 0.5, { BackgroundTransparency = 0.25 })
	endTitle.Text = spaced(if r.draw then "ÉGALITÉ" elseif r.won then "VICTOIRE" else "DÉFAITE", 2)
	endTitle.TextColor3 = if r.draw then C.text elseif r.won then C.gold else C.red
	endTitleScale.Scale = 2.2; endTitle.TextTransparency = 1
	tween(endTitleScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back); tween(endTitle, 0.3, { TextTransparency = 0 })
	local t1, t2 = lastState and lastState.teams[1] or "", lastState and lastState.teams[2] or ""
	if r.team then
		endScore.Text = string.format("%s  %d  —  %d  %s", t1, r.score[t1] or 0, r.score[t2] or 0, t2)
	else
		endScore.Text = if r.winner then "Vainqueur : " .. tostring(r.winner) else (r.modeName or "")
	end
	if r.me then
		card("Ta partie", { r.me.k .. " éliminations · " .. r.me.d .. " morts", r.me.a .. " assistances · " .. r.me.hs .. " à la tête", r.me.dmg .. " dégâts",
			"Meilleure série : " .. r.me.bestStreak }, C.blue, 0.5)
	end
	if r.mvp then
		card("Meilleur joueur", { (if r.mvp.bot then "[BOT] " else "") .. r.mvp.name, r.mvp.k .. " éliminations", r.mvp.score .. " points" }, C.gold, 0.7)
	end
	if r.rewards then
		local lines = { "+" .. r.rewards.xp .. " XP", "+" .. r.rewards.coins .. " pièces" }
		local ups = r.rewards.levelUps
		if typeof(ups) == "table" and #ups > 0 then table.insert(lines, "Niveau supérieur !") end
		if r.progress and (r.progress.tiersGained or 0) > 0 then table.insert(lines, "+" .. r.progress.tiersGained .. " palier(s) du passe") end
		card("Récompenses", lines, C.green, 0.9)
	end
	task.spawn(function()
		local left = r.next or 15
		while left > 0 and endFrame.Visible do
			endNext.Text = "Prochaine partie dans " .. left .. " s — même mode, même carte"
			task.wait(1); left -= 1
		end
	end)
end)

-- ==========================================================================================
-- Mise à jour continue
-- ==========================================================================================
local inMatch = false
-- ligne du mode (web : #shpHud, #jugHud, #kcHud… au-dessus du centre de l'écran)
local modeLine = label(gui, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 104), Size = UDim2.fromOffset(700, 20), TextSize = 15,
	Font = FONT, TextColor3 = C.gold, Text = "", TextStrokeTransparency = 0.5 })
local modeSub = label(gui, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 124), Size = UDim2.fromOffset(700, 16), TextSize = 12,
	Font = Enum.Font.GothamBold, TextColor3 = rgb(0xdfe6f2), Text = "", TextStrokeTransparency = 0.5 })
-- grande bannière du mode (uiBanner du web : « NOUVELLE ARME », « TU ES LE MASTODONTE »…)
local annTitle = label(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(900, 50), TextSize = 40, Font = FONT,
	Text = "", TextTransparency = 1, ZIndex = 8 })
make("UIStroke", { Thickness = 3, Transparency = 0.35, Color = Color3.new(0, 0, 0) }, annTitle)
local annSub = label(gui, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.3, 28), Size = UDim2.fromOffset(900, 22), TextSize = 17, Font = Enum.Font.GothamBold,
	Text = "", TextTransparency = 1, TextStrokeTransparency = 1, ZIndex = 8 })
local annScale = make("UIScale", { Scale = 1 }, annTitle)
local annToken = 0
local annRemote = ReplicatedStorage:WaitForChild("MatchAnnounce", 20) :: RemoteEvent?
if annRemote then
	annRemote.OnClientEvent:Connect(function(title: string, sub: string?, color: Color3?)
		annToken += 1
		local my = annToken
		annTitle.Text = spaced(title, 2); annTitle.TextColor3 = color or C.gold; annTitle.TextTransparency = 0
		annSub.Text = sub or ""; annSub.TextTransparency = 0; annSub.TextStrokeTransparency = 0.5
		annScale.Scale = 1.35; tween(annScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		playSound(ModeConfig.SOUNDS.streak)
		task.delay(2.2, function()
			if my ~= annToken then return end
			tween(annTitle, 0.4, { TextTransparency = 1 }); tween(annSub, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end)
	end)
end
-- petit message de mode au centre (« ÉLIMINATION CONFIRMÉE +1 », « +150 »…)
local popLabel = label(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.fromOffset(600, 26), TextSize = 20, Font = FONT,
	Text = "", TextTransparency = 1, TextStrokeTransparency = 1 })
local popToken = 0
local popRemote = ReplicatedStorage:WaitForChild("ModePop", 20) :: RemoteEvent?
if popRemote then
	popRemote.OnClientEvent:Connect(function(text: string, color: Color3?, sound: string?)
		popToken += 1
		local my = popToken
		popLabel.Text = spaced(text, 1); popLabel.TextColor3 = color or C.gold
		popLabel.TextTransparency = 0; popLabel.TextStrokeTransparency = 0.5; popLabel.Position = UDim2.fromScale(0.5, 0.6)
		tween(popLabel, 1.1, { Position = UDim2.fromScale(0.5, 0.57) })
		if sound then pcall(function() Sfx.play(sound) end) end
		task.delay(1, function() if my == popToken then tween(popLabel, 0.3, { TextTransparency = 1, TextStrokeTransparency = 1 }) end end)
	end)
end
player:GetAttributeChangedSignal("ModeLine"):Connect(function()
	local v = player:GetAttribute("ModeLine")
	if typeof(v) == "string" then modeLine.Text = v end
end)
player:GetAttributeChangedSignal("Zone"):Connect(function()
	if player:GetAttribute("Zone") ~= "match" then
		inMatch = false; top.Visible = false; radarWrap.Visible = false; phaseLabel.Text = ""; modeLine.Text = ""; modeSub.Text = ""
		endFrame.Visible = false; deathFrame.Visible = false; showBoard(false)
	end
end)
stateRemote.OnClientEvent:Connect(function(st: any)
	-- avec le lobby, le score du match à mort ne s'affiche que pour ceux qui y jouent
	inMatch = player:GetAttribute("Zone") == "match" and st.id == player:GetAttribute("MatchId")
	top.Visible = inMatch; radarWrap.Visible = inMatch
	if not inMatch then phaseLabel.Text = ""; modeLine.Text = ""; modeSub.Text = ""; return end
	lastState = st
	if typeof(st.mapId) == "string" and st.mapId ~= "" then buildRadar(st.mapId) end
	local mine = myTeam()
	if st.team then
		-- à gauche l'équipe bleue (Défenseurs), à droite l'orange (Attaquants), comme #top du web
		local l, r = st.teams[2], st.teams[1]
		scoreL.Text = tostring(st.score[l] or 0); scoreR.Text = tostring(st.score[r] or 0)
		borderL.BackgroundColor3 = teamColor(l); borderR.BackgroundColor3 = teamColor(r)
		scoreL.TextColor3 = if mine == l then C.text else rgb(0xd5deec)
		scoreR.TextColor3 = if mine == r then C.text else rgb(0xd5deec)
	else
		-- chacun pour soi (comme le web) : à gauche mon score, à droite celui du premier
		local me, best = 0, 0
		for _, e in ipairs(st.board) do
			if e.userId == player.UserId then me = e.pts or 0 end
			best = math.max(best, e.pts or 0)
		end
		scoreL.Text = tostring(me); scoreR.Text = tostring(best)
		aliveL.Text = "TOI"; aliveR.Text = "1ER"
		borderL.BackgroundColor3 = C.gold; borderR.BackgroundColor3 = st.modeColor or C.red
		scoreL.TextColor3 = C.text; scoreR.TextColor3 = rgb(0xd5deec)
	end
	timerLabel.Text = if st.timeLeft >= 0 then fmtTime(st.timeLeft) else "—"
	goalLabel.Text = if st.state == "live" and st.killsToWin then spaced("PREMIER À " .. st.killsToWin, 1) elseif st.state == "intermission" then spaced("PAUSE", 1) else spaced(string.upper(st.modeName or ""), 1)
	phaseLabel.Text = if st.state == "intermission" then spaced("NOUVELLE PARTIE DANS " .. st.timeLeft .. " S", 2)
		elseif st.warmup then spaced("PRÉPAREZ-VOUS…", 2)
		else ""
	-- ligne du mode (arme tournante, Mastodonte, infectés, plaques, score de l'entraînement…) sous le chrono
	local info = st.info
	local personal = player:GetAttribute("ModeLine")
	modeLine.Text = if typeof(personal) == "string" then personal elseif info and info.line then info.line else ""
	modeLine.TextColor3 = if info and info.color then info.color else C.gold
	modeSub.Text = if info and info.sub then info.sub else ""
	modeSub.TextColor3 = if info and info.subWarn then rgb(0xff6b6b) else rgb(0xdfe6f2)
	if info and info.kind == "kc" and st.data and st.data.tags and mine then
		local other = if mine == st.teams[1] then st.teams[2] else st.teams[1]
		modeSub.Text = "🏷 " .. (st.data.tags[other] or 0) .. " à confirmer     🏷 " .. (st.data.tags[mine] or 0) .. " à refuser"
	end
	if st.state == "live" and endFrame.Visible then endFrame.Visible = false end
	if board.Visible then renderBoard() end
end)

local ghostHp, ghostT = 100, 0
player.CharacterAdded:Connect(function(char)
	deathFrame.Visible = false
	ghostHp = 100
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	local last = hum.Health
	hum.HealthChanged:Connect(function(hp)
		if hp < last then ghostT = os.clock() + 0.45 end
		last = hp
	end)
end)

RunService.RenderStepped:Connect(function(dt: number)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hp = if hum then math.max(0, hum.Health) else 0
	local maxHp = if hum then hum.MaxHealth else 100
	local frac = hp / maxHp
	local t = os.clock()
	-- vie : chiffre (rouge et qui pulse sous 30), jauge, traînée blanche qui rattrape la vie restante
	hpText.Text = tostring(math.ceil(hp))
	hpText.TextColor3 = if hp > 0 and hp < 30 then (if t % 0.8 < 0.4 then rgb(0xff5050) else rgb(0xff8080)) else C.text
	hpBar.Size = UDim2.fromScale(frac, 1)
	local hpPct = frac * 100
	if hpPct >= ghostHp or hp <= 0 then ghostHp = hpPct elseif t > ghostT then ghostHp = math.max(hpPct, ghostHp - dt * 70) end
	hpGhost.Size = UDim2.fromScale(ghostHp / 100, 1)
	-- bouclier
	local shield = char and char:GetAttribute("Shield")
	local sh = if typeof(shield) == "number" then shield else 0
	shieldText.Text = tostring(sh)
	shieldBar.Size = UDim2.fromScale(sh / Config.SHIELD_MAX, 1)
	-- voiles rouges
	hurtAlpha = math.max(0, hurtAlpha - dt / 0.7)
	setVeil(hurtVeil, hurtAlpha * 0.85)
	setVeil(lowVeil, if frac < 0.3 and hp > 0 then 0.35 + 0.25 * math.sin(t * 5.7) else 0)
	local prot = char and char:GetAttribute("ProtectedUntil")
	protectLabel.Text = if typeof(prot) == "number" and prot > workspace:GetServerTimeNow() then "◇ Protection d'apparition" else ""

	-- arme en main
	local key = player:GetAttribute("Weapon")
	local w = typeof(key) == "string" and Config.WEAPONS[key] or nil
	wpanel.Visible = w ~= nil
	if w then
		local k = key :: string
		local skin, camo = mySkin(k)
		local skinId = tostring(skin) .. "/" .. tostring(camo)
		if panelKey ~= k or panelSkin ~= skinId then
			panelKey = k; panelSkin = skinId
			for _, c in ipairs(wIconHolder:GetChildren()) do c:Destroy() end
			weaponIcon(wIconHolder, k, Vector2.new(120, 52), nil, skin, camo)
			wName.Text = spaced(string.upper(w.name), 2)
			pipMax = -1
		end
		local mag = player:GetAttribute("Mag") :: number? or 0
		if w.melee then
			magText.Text = "—"; reserveText.Text = ""
		else
			magText.Text = tostring(mag)
			reserveText.Text = "/ " .. tostring(player:GetAttribute("Reserve") or 0)
			reserveText.Position = UDim2.new(1, -176 + magText.AbsoluteSize.X + 4, 0, 36)
		end
		magText.TextColor3 = if not w.melee and mag <= math.ceil(w.mag * 0.2) then rgb(0xff6b6b) else C.text
		-- balles du chargeur
		local maxPips = if w.melee then 0 else math.min(w.mag, 50)
		if maxPips ~= pipMax then
			pipMax = maxPips
			for _, p in ipairs(pipList) do p:Destroy() end
			pipList = {}
			local pw = if maxPips > 36 then 2 else 3
			for i = 1, maxPips do pipList[i] = make("Frame", { Size = UDim2.fromOffset(pw, 6), BackgroundColor3 = C.gold, LayoutOrder = i }, pips) end
		end
		local shown = if w.mag > 50 then math.ceil(mag / w.mag * 50) else mag
		for i, p in ipairs(pipList) do p.BackgroundTransparency = if i <= shown then 0 else 0.8 end
		-- recharge sous le viseur
		local reloading = player:GetAttribute("Reloading") == true
		relBar.Visible = reloading
		if reloading then
			local started = player:GetAttribute("ReloadStart") :: number? or t
			relFill.Size = UDim2.fromScale(clamp((t - started) / math.max(w.reload, 0.1), 0, 1), 1)
		end
	else
		relBar.Visible = false
	end
	-- emplacements
	local loadout = string.split(tostring(player:GetAttribute("Loadout") or ""), ",")
	local slot = player:GetAttribute("Slot") :: number? or 1
	for i, s in ipairs(slots) do
		local k = loadout[i]
		local wk = k and Config.WEAPONS[k]
		s.frame.Visible = wk ~= nil
		if wk then
			local skin, camo = mySkin(k)
			local id = tostring(skin) .. "/" .. tostring(camo)
			if s.key ~= k or s.skin ~= id then
				s.key = k; s.skin = id
				if s.icon then s.icon:Destroy() end
				s.icon = weaponIcon(s.frame, k, Vector2.new(46, 18), { Position = UDim2.fromOffset(20, 4) }, skin, camo)
			end
			local on = i == slot
			s.border.Transparency = if on then 0 else 1
			s.num.TextColor3 = if on then C.text else C.dim
		end
	end
	-- haut : soldats en vie, chrono pressé
	if inMatch and lastState then
		local alive: { [string]: number } = {}
		for _, so in ipairs(soldierList()) do if so.alive and so.team then alive[so.team] = (alive[so.team] or 0) + 1 end end
		local l, r = lastState.teams[2], lastState.teams[1]
		aliveL.Text = (alive[l] or 0) .. " en vie"; aliveR.Text = (alive[r] or 0) .. " en vie"
		timerLabel.TextColor3 = if lastState.state == "live" and lastState.timeLeft <= 30 then (if t % 1 < 0.5 then rgb(0xff5050) else rgb(0xff9090)) else C.text
	end
	-- radar
	if inMatch then drawRadar(dt) end
	-- direction des tirs reçus
	local cf = camera.CFrame
	for _, d in ipairs(dirs) do
		d.t += dt
		if d.t > 1.6 then d.arc.BackgroundTransparency = 1; d.chev.TextTransparency = 1; continue end
		if d.att and d.att:IsA("Model") then
			local r = d.att:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r then d.from = r.Position end
		end
		local rel = cf:VectorToObjectSpace(d.from - cf.Position)
		d.holder.Rotation = math.deg(math.atan2(rel.X, -rel.Z))
		local a = d.k * (if d.t < 1 then 1 else 1 - (d.t - 1) / 0.6)
		d.arc.BackgroundTransparency = 1 - a; d.chev.TextTransparency = 1 - a
	end
	updateNumbers(dt)
	dot.Visible = ModeConfig.CENTER_DOT and player:GetAttribute("Aiming") ~= true and hp > 0
end)
