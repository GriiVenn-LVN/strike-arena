--!strict
-- StarterPlayerScripts/ZombieBrHud (LocalScript)
-- Ce que voit le joueur en Zombies et en Bataille royale (web : zHud / zHudUpdate de src/69_zombies.js, zDownUpdate de
-- src/69z_extra.js, brUpdate / variantRadar de src/61_variants.js, orage de src/42_haunt.js) :
--   Zombies : numéro de manche « Black Ops » (bâtons rouges), points (+gains), atouts bus, bonus actifs, écran « À TERRE »,
--             textes des invites (E) selon ce que le joueur possède, contenu de la boîte mystère.
--   Bataille royale : mur de la zone, alerte hors zone, cercle de la zone sur le radar, armes posées au sol.
--   Asile hanté : éclairs et tonnerre par-dessus l'éclairage de la carte (MapDetailController).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Z = require(ReplicatedStorage.Shared.ZombieConfig)
local WeaponModels = require(ReplicatedStorage.Shared.WeaponModels)
local Sfx = require(ReplicatedStorage.Shared.Sfx)


local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local U = Config.STUDS_PER_METER
local RADAR, RANGE = 184, 31 * U  -- mêmes valeurs que le radar de HudController

local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local i = Instance.new(class)
	for k, v in pairs(props) do (i :: any)[k] = v end
	if parent then i.Parent = parent end
	return i
end
local function fmtPts(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	return (out:gsub("^%s+", ""))
end

local gui = make("ScreenGui", { Name = "ZombieBrHud", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 11 }, player:WaitForChild("PlayerGui"))

-- ---------- Zombies : manche, points, atouts, bonus (bas gauche, au-dessus de la vie) ----------
local zRoot = make("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 26, 1, -170), Size = UDim2.fromOffset(320, 190), BackgroundTransparency = 1, Visible = false }, gui)
local zRound = make("TextLabel", { Size = UDim2.fromOffset(320, 72), BackgroundTransparency = 1, Font = Enum.Font.Antique, TextSize = 68, Text = "",
	TextColor3 = Color3.fromRGB(179, 18, 27), TextStrokeColor3 = Color3.fromRGB(48, 0, 0), TextStrokeTransparency = 0.2, TextXAlignment = Enum.TextXAlignment.Left }, zRoot)
local zPts = make("TextLabel", { Position = UDim2.fromOffset(0, 76), Size = UDim2.fromOffset(200, 32), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 26,
	Text = "0", TextColor3 = Color3.fromRGB(255, 215, 94), TextStrokeTransparency = 0.4, TextXAlignment = Enum.TextXAlignment.Left }, zRoot)
local zPerks = make("Frame", { Position = UDim2.fromOffset(0, 112), Size = UDim2.fromOffset(320, 34), BackgroundTransparency = 1 }, zRoot)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }, zPerks)
local zFx = make("TextLabel", { Position = UDim2.fromOffset(0, 150), Size = UDim2.fromOffset(320, 40), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13,
	Text = "", RichText = true, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.5, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, zRoot)

local function gain(n: number)
	local l = make("TextLabel", { Position = UDim2.fromOffset(zPts.TextBounds.X + 10, 76), Size = UDim2.fromOffset(80, 20), BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack, TextSize = 16, Text = "+" .. n, TextColor3 = Color3.fromRGB(255, 233, 160), TextStrokeTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Left }, zRoot)
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - t0) / 0.9
		if k >= 1 then conn:Disconnect(); l:Destroy(); return end
		l.Position = UDim2.fromOffset(zPts.TextBounds.X + 10 + k * 26, 76 - k * 26)
		l.TextTransparency = k; l.TextStrokeTransparency = 0.5 + k * 0.5
	end)
end
local gainRemote = ReplicatedStorage:WaitForChild("ZombieGain", 30) :: RemoteEvent?
if gainRemote then gainRemote.OnClientEvent:Connect(function(n: number) if typeof(n) == "number" then gain(n) end end) end

local function drawPerks()
	for _, c in ipairs(zPerks:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
	local v = player:GetAttribute("ZPerks")
	if typeof(v) ~= "string" or v == "" then return end
	for k in v:gmatch("[^,]+") do
		local p = Z.PERKS[k]
		if p then
			local i = make("TextLabel", { Size = UDim2.fromOffset(34, 34), BackgroundColor3 = p.c, Font = Enum.Font.GothamBlack, TextSize = 15, Text = p.ic, TextColor3 = Color3.new(1, 1, 1) }, zPerks)
			make("UICorner", { CornerRadius = UDim.new(1, 0) }, i)
			make("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.6, Thickness = 2 }, i)
		end
	end
end
player:GetAttributeChangedSignal("ZPerks"):Connect(drawPerks)

-- « À TERRE » au centre
local downLabel = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(600, 80), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack, TextSize = 32, RichText = true, Text = "", TextColor3 = Color3.fromRGB(255, 70, 85), TextStrokeTransparency = 0.3, Visible = false }, gui)
local downVeil = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(120, 0, 0), BackgroundTransparency = 0.75, Visible = false, ZIndex = 0 }, gui)

-- ---------- Bataille royale : alerte hors zone ----------
local outLabel = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.2), Size = UDim2.fromOffset(600, 34), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack, TextSize = 24, Text = "⚠ VOUS ÊTES HORS DE LA ZONE", TextColor3 = Color3.fromRGB(255, 80, 80), TextStrokeTransparency = 0.3, Visible = false }, gui)

-- ==========================================================================================
-- État de la partie
-- ==========================================================================================
local st: any = nil
local function myFolder(): Instance?
	local n = player:GetAttribute("MatchMap")
	return if typeof(n) == "string" then workspace:FindFirstChild(n) else nil
end
local function inMatch(): boolean
	return player:GetAttribute("Zone") == "match" and st ~= nil and st.id == player:GetAttribute("MatchId")
end
local stateRemote = ReplicatedStorage:WaitForChild("TDMState") :: RemoteEvent
stateRemote.OnClientEvent:Connect(function(s: any)
	st = s
	-- armes prodiges connues du client (tir, viewmodel) dès la première partie Zombies, pas avant (menus, boutique)
	if s and s.mode == "zombies" then Z.registerWeapons() end
end)

-- ==========================================================================================
-- Invites (touche E) : texte selon ce que possède le joueur (zInteractFor du web)
-- ==========================================================================================
local shown: { [ProximityPrompt]: boolean } = {}
local function has(attr: string, key: string): boolean
	local v = player:GetAttribute(attr)
	if typeof(v) ~= "string" then return false end
	for k in v:gmatch("[^,]+") do if k == key then return true end end
	return false
end
local function wname(k: string?): string
	local w = k and Config.WEAPONS[k]
	return if w then w.name else (k or "?")
end
local function refreshPrompt(pp: ProximityPrompt)
	local kind = pp:GetAttribute("ZKind")
	if kind == "wall" then
		local key, price = pp:GetAttribute("Weapon") :: string, pp:GetAttribute("Price") :: number
		local own = has("ZOwn", key)
		pp.ActionText = (if own then "Munitions " else "Acheter ") .. wname(key) .. " — " .. (if own then math.floor(price / 2 + 0.5) else price) .. " pts"
	elseif kind == "box" then
		local box = pp:FindFirstAncestorOfClass("Model")
		local state = box and box:GetAttribute("BoxState")
		local price = (st and st.data and st.data.z and st.data.z.boxPrice) or Z.BOX_PRICE
		if state == "idle" then pp.ActionText = "Boîte mystère — " .. price .. " pts"; pp.Enabled = true
		elseif state == "ready" and box and box:GetAttribute("BoxOwner") == player.UserId then pp.ActionText = "Prendre " .. wname(box:GetAttribute("BoxWeapon") :: string?); pp.Enabled = true
		else pp.ActionText = "Boîte mystère…" end
	elseif kind == "perk" then
		local key = pp:GetAttribute("Perk") :: string
		local p = Z.PERKS[key]
		if p then pp.ActionText = if has("ZPerks", key) then p.n .. " (déjà bu)" else p.n .. " — " .. p.price .. " pts" end
	elseif kind == "pap" then
		local w = player.Character and player.Character:GetAttribute("Weapon")
		if typeof(w) ~= "string" or w == "knife" then pp.ActionText = "Forge Arcane : prends une arme en main"
		elseif has("ZPap", w) then pp.ActionText = wname(w) .. " est déjà améliorée"
		else pp.ActionText = "Forge Arcane : améliorer " .. wname(w) .. " — " .. Z.PAP_PRICE .. " pts" end
	elseif kind == "revive" then
		-- pas d'invite sur soi-même ; Second Souffle : réanimation 2× plus rapide
		local char = player.Character
		if char and pp:IsDescendantOf(char) then pp.Enabled = false; return end
		pp.HoldDuration = if has("ZPerks", "revive") then 1.5 else 3
		pp.ActionText = "Maintiens : réanimer"
	end
end
ProximityPromptService.PromptShown:Connect(function(pp: ProximityPrompt)
	if pp:GetAttribute("ZKind") then shown[pp] = true; refreshPrompt(pp) end
end)
ProximityPromptService.PromptHidden:Connect(function(pp: ProximityPrompt) shown[pp] = nil end)
-- l'invite de réanimation n'apparaît jamais sur soi
workspace.DescendantAdded:Connect(function(d: Instance)
	if d:IsA("ProximityPrompt") and d:GetAttribute("ZKind") == "revive" then
		task.defer(function() local c = player.Character; if c and d:IsDescendantOf(c) then d.Enabled = false end end)
	end
end)

-- ==========================================================================================
-- Boîte mystère : armes qui défilent, puis l'arme tirée (ou le nounours)
-- ==========================================================================================
local SHOW_SCALE = 2.9 * 1.5
local boxShow: Model? = nil
local boxShowKey: string? = nil
local lastSwap = 0
local function setShow(key: string?)
	if boxShowKey == key and boxShow then return end
	if boxShow then boxShow:Destroy(); boxShow = nil end
	boxShowKey = key
	if not key then return end
	if key == "teddy" then
		local m = Instance.new("Model")
		local fur = Color3.fromRGB(138, 90, 53)
		local function ball(name: string, d: number, off: Vector3)
			local p = make("Part", { Name = name, Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d) * U, Color = fur, Material = Enum.Material.Fabric, Anchored = true,
				CanCollide = false, CanQuery = false, CastShadow = false }, m)
			p:SetAttribute("Off", off * U)
		end
		ball("Body", 0.36, Vector3.new(0, 0, 0)); ball("Head", 0.26, Vector3.new(0, 0.27, 0)); ball("EarL", 0.1, Vector3.new(-0.1, 0.38, 0)); ball("EarR", 0.1, Vector3.new(0.1, 0.38, 0))
		m.Parent = workspace
		boxShow = m
		return
	end
	local ok, model = pcall(WeaponModels.build, key, SHOW_SCALE)
	if ok and model then model.Parent = workspace; boxShow = model end
end
local function updateBox(folder: Instance)
	local z = folder:FindFirstChild("Zombies")
	local box = z and z:FindFirstChild("MysteryBox") :: Model?
	local base = box and box:FindFirstChild("Base") :: BasePart?
	local lid = box and box:FindFirstChild("Lid") :: BasePart?
	if not box or not base then setShow(nil); return end
	local state = box:GetAttribute("BoxState")
	local t0 = box:GetAttribute("BoxT")
	local t = workspace:GetServerTimeNow() - (if typeof(t0) == "number" then t0 else 0)
	if lid then
		local closed = lid:GetAttribute("Closed")
		if typeof(closed) == "CFrame" then
			local hinge = closed * CFrame.new(0, 0, 0.385 * U)
			lid.CFrame = if state == "idle" then closed else hinge * CFrame.Angles(math.rad(70), 0, 0) * CFrame.new(0, 0, -0.385 * U)
		end
	end
	local y = 0.8
	if state == "roll" then
		if os.clock() - lastSwap > 0.08 + t * 0.06 and t < 4 then
			lastSwap = os.clock()
			setShow(Z.BOXPOOL[math.random(#Z.BOXPOOL)])
		end
		y = 0.8 + math.min(1, t / 4) * 0.6
	elseif state == "ready" then
		local k = box:GetAttribute("BoxWeapon")
		setShow(if typeof(k) == "string" then k else nil)
		y = 1.4 - math.min(0.6, (t - 4.2) / 9 * 0.6)
	elseif state == "teddy" then
		setShow("teddy")
		y = 1.4 + math.max(0, t - 4.2) * 1.4
	else
		setShow(nil)
	end
	if boxShow then
		local cf = CFrame.new(base.Position + Vector3.new(0, (y - 0.31) * U, 0)) * CFrame.Angles(0, os.clock() * (if state == "teddy" then 3 else 0.6), 0)
		if boxShowKey == "teddy" then
			for _, p in ipairs(boxShow:GetChildren()) do
				local off = p:GetAttribute("Off")
				if p:IsA("BasePart") and typeof(off) == "Vector3" then p.CFrame = cf * CFrame.new(off) end
			end
		else
			WeaponModels.place(boxShow, cf * CFrame.Angles(0, math.rad(90), 0))
		end
	end
end

-- ==========================================================================================
-- Bataille royale : mur de la zone (panneaux fins visibles des deux côtés), armes au sol
-- ==========================================================================================
local SEG = 48
local wall: { BasePart } = {}
local wallFolder: Folder? = nil
local zoneC, zoneR = Vector3.zero, 0
local function ensureWall()
	if wallFolder and wallFolder.Parent then return end
	local f = Instance.new("Folder"); f.Name = "BrZoneWall"
	wall = {}
	for i = 1, SEG do
		wall[i] = make("Part", { Name = "Wall", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.Neon,
			Color = Z.ZONE_COLOR, Transparency = 0.8, Size = Vector3.new(1, 14 * U, 0.2) }, f)
	end
	f.Parent = workspace
	wallFolder = f
end
local function dropWall()
	if wallFolder then wallFolder:Destroy(); wallFolder = nil end
	wall = {}
	zoneR = 0
end
local function updateWall(br: any, dt: number, pulse: number)
	ensureWall()
	local target = Vector3.new(br.x, 0, br.z)
	if zoneR <= 0 then zoneC, zoneR = target, br.r end
	local k = math.min(1, dt * 2.5)
	zoneC = zoneC:Lerp(target, k); zoneR += (br.r - zoneR) * k
	local folder = myFolder()
	local origin = folder and folder:GetAttribute("Origin")
	local y0 = if typeof(origin) == "Vector3" then origin.Y else 0
	local r = math.max(0.05, zoneR)
	local w = 2 * math.pi * r / SEG * 1.02
	local parts, cfs = {}, {}
	for i = 1, SEG do
		local a = (i - 0.5) / SEG * math.pi * 2
		local p = Vector3.new(zoneC.X + math.cos(a) * r, y0 + 7 * U, zoneC.Z + math.sin(a) * r)
		wall[i].Size = Vector3.new(w, 14 * U, 0.2)
		wall[i].Transparency = 0.8 + pulse * 0.04
		table.insert(parts, wall[i]); table.insert(cfs, CFrame.lookAt(p, Vector3.new(zoneC.X, p.Y, zoneC.Z)))
	end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

local lootModels: { [Instance]: Model } = {}
local function updateLoot(folder: Instance)
	local brf = folder:FindFirstChild("BattleRoyale")
	if not brf then return end
	local t = os.clock()
	for _, it in ipairs(brf:GetChildren()) do
		local key = it:GetAttribute("LootKey")
		local core: BasePart? = if it:IsA("Model") then it.PrimaryPart else nil
		if typeof(key) == "string" and core then
			local gm = lootModels[it]
			if not gm then
				local ok, model = pcall(WeaponModels.build, key, 2.9 * 1.15)
				if ok and model then model.Parent = it; lootModels[it] = model; gm = model end
			end
			if gm then WeaponModels.place(gm, CFrame.new(core.Position) * CFrame.Angles(0, t * 1.6, 0)) end
		end
	end
	for it, gm in pairs(lootModels) do if not it.Parent then gm:Destroy(); lootModels[it] = nil end end
end

-- cercle de la zone sur le radar de HudController (cadre « Radar »)
local radarRing: Frame? = nil
local function radarFrame(): Frame?
	local hud = player.PlayerGui:FindFirstChild("MatchHud")
	return hud and hud:FindFirstChild("Radar", true) :: Frame?
end
local function updateRadar(show: boolean)
	local rf = radarFrame()
	if not show or not rf then if radarRing then radarRing.Visible = false end return end
	if not radarRing or radarRing.Parent ~= rf then
		if radarRing then radarRing:Destroy() end
		local f = make("Frame", { Name = "ZoneRing", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 4 }, rf)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, f)
		make("UIStroke", { Color = Z.ZONE_COLOR, Thickness = 3 }, f)
		radarRing = f
	end
	local ring = radarRing :: Frame
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then ring.Visible = false; return end
	local look = camera.CFrame.LookVector
	local fwd = Vector3.new(look.X, 0, look.Z)
	if fwd.Magnitude < 1e-3 then fwd = Vector3.new(0, 0, -1) end
	fwd = fwd.Unit
	local right = Vector3.new(-fwd.Z, 0, fwd.X)
	local half = RADAR / 2
	local pps = half / RANGE
	local d = Vector3.new(zoneC.X - root.Position.X, 0, zoneC.Z - root.Position.Z)
	ring.Visible = true
	ring.Position = UDim2.fromOffset(half + d:Dot(right) * pps, half - d:Dot(fwd) * pps)
	ring.Size = UDim2.fromOffset(2 * zoneR * pps, 2 * zoneR * pps)
end

-- ==========================================================================================
-- Asile hanté : éclairs (flash bleuté) puis tonnerre
-- ==========================================================================================
local nextFlash = -1
local function storm()
	local t = os.clock()
	if nextFlash < 0 then nextFlash = t + 6 + math.random() * 8 end
	if t < nextFlash then return end
	nextFlash = t + 9 + math.random() * 13
	local old = Lighting.Brightness
	local oldShift = Lighting.ColorShift_Top
	Lighting.Brightness = old + 3.2; Lighting.ColorShift_Top = Color3.fromRGB(191, 212, 255)
	task.delay(0.08, function() Lighting.Brightness = old + 0.4 end)
	task.delay(0.16, function() Lighting.Brightness = old + 2.4 end)
	task.delay(0.24, function() Lighting.Brightness = old + 1 end)
	task.delay(0.45, function() Lighting.Brightness = old; Lighting.ColorShift_Top = oldShift end)
	task.delay(0.6 + math.random() * 1.6, function() pcall(function() Sfx.play("boom", nil, 0.35) end) end)
end

-- ==========================================================================================
-- Boucle
-- ==========================================================================================
RunService.RenderStepped:Connect(function(dt: number)
	local live = inMatch()
	local mode = if live then st.mode else nil
	local data = live and st.data or nil
	local folder = if live then myFolder() else nil
	-- Zombies
	local zd = data and data.z
	zRoot.Visible = mode == "zombies" and zd ~= nil
	if mode == "zombies" and zd then
		zRound.Text = Z.tally(zd.wave)
		local pts = player:GetAttribute("ZPts")
		zPts.Text = fmtPts(if typeof(pts) == "number" then pts else 0)
		local fx = {}
		if zd.insta > 0 then table.insert(fx, '<font color="#ff3a3a">☠ MORT INSTANTANÉE ' .. zd.insta .. "</font>") end
		if zd.dbl > 0 then table.insert(fx, '<font color="#ffd23a">×2 POINTS ' .. zd.dbl .. "</font>") end
		if zd.fire > 0 then table.insert(fx, '<font color="#7fe0ff">$ VENTE DE FEU ' .. zd.fire .. "</font>") end
		zFx.Text = table.concat(fx, "<br/>")
		for pp in pairs(shown) do if pp.Parent then refreshPrompt(pp) else shown[pp] = nil end end
		if folder then updateBox(folder) end
	else
		setShow(nil)
	end
	local char = player.Character
	local downed = mode == "zombies" and char ~= nil and char:GetAttribute("Downed") == true
	downLabel.Visible = downed; downVeil.Visible = downed
	if downed and char then
		local dt2 = char:GetAttribute("DownT")
		downLabel.Text = 'À TERRE<br/><font size="16" color="#ffffff">' .. (if typeof(dt2) == "number" then dt2 else 30) .. " s — un allié doit te réanimer</font>"
	end
	-- Bataille royale
	local br = data and data.br
	if mode == "br" and br and st.state == "live" then
		updateWall(br, dt, math.sin(os.clock() * 2))
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		outLabel.Visible = root ~= nil and Vector3.new(root.Position.X - zoneC.X, 0, root.Position.Z - zoneC.Z).Magnitude > zoneR
		updateRadar(true)
		if folder then updateLoot(folder) end
	else
		if wallFolder then dropWall() end
		outLabel.Visible = false
		updateRadar(false)
	end
	-- orage sur l'Asile
	if folder and folder:GetAttribute("MapId") == "asile" then storm() else nextFlash = -1 end
end)
