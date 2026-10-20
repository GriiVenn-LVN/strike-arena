--!strict
-- Modes/zombies : Zombies (coop) façon « Black Ops », sur l'Asile hanté
-- (web : src/61_variants.js zStartWave / zSpawn / zombieWaves, src/69_zombies.js, src/69z_extra.js, src/8K_zammo.js, src/8L_zdiff.js).
--   - Tous les humains (joueurs + bots alliés) sont dans la même équipe ; les zombies arrivent par vagues (7 + 5 × manche,
--     au plus min(24, 6 + 2 × manche) en même temps). Manche des rôdeurs toutes les 5 manches, la Brute toutes les 10.
--   - Points : +10 par touche, +50 élimination (+90 à la tête, +120 au couteau), +1000 la Brute, +100 réanimation.
--   - Armes murales (moitié prix pour les munitions), boîte mystère (950, nounours qui la déplace), Forge Arcane (5000),
--     atouts (Mastodonte, Turbo Cola, Double Détente, Second Souffle, Pas de Course), armes prodiges.
--   - Bonus lâchés : Munitions max, Mort instantanée, Points doubles, Bombe, Vente de feu (30 s).
--   - Débris à dégager pour ouvrir l'asile, joueurs à terre (30 s pour être réanimé), porteurs de munitions, easter egg.
--   - Victoire après la dernière manche choisie, défaite quand plus personne n'est debout.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Modes = require(ReplicatedStorage.Shared.Modes)
local Z = require(ReplicatedStorage.Shared.ZombieConfig)
local MapData = require(ReplicatedStorage.Shared.MapData) :: any
local WeaponService = require(script.Parent.Parent.WeaponService)
local BotService = require(script.Parent.Parent.BotService)
local ZombieService = require(script.Parent.Parent.ZombieService)
local RewardService = require(script.Parent.Parent.RewardService)

Z.registerWeapons()

local U = Config.STUDS_PER_METER
local S = Config.CELL * U                 -- une case en studs
local HUMANS = "Attaquants"               -- équipe 0 du web
local RED = Z.rgb(0xd0202a)
local GOLD = Z.rgb(0xffd23a)

local M = {}
M.noPickups = true
local function MS(): any return require(script.Parent.Parent.MatchService) :: any end

local function remote(name: string): RemoteEvent
	local r = ReplicatedStorage:FindFirstChild(name) :: RemoteEvent?
	if not r then local e = Instance.new("RemoteEvent"); e.Name = name; e.Parent = ReplicatedStorage; r = e end
	return r :: RemoteEvent
end
local popEvent = remote("ModePop")        -- petit message au centre (HudController)
local gainEvent = remote("ZombieGain")    -- serveur -> joueur : +points (ZombieBrHud)
local feedEvent = ReplicatedStorage:WaitForChild("KillFeed") :: RemoteEvent
local bannerEvent = ReplicatedStorage:WaitForChild("KillBanner") :: RemoteEvent

local function isPlayer(c: any): boolean return typeof(c) == "Instance" and c:IsA("Player") end
local function now(): number return os.clock() end
local function hypot(a: number, b: number): number return math.sqrt(a * a + b * b) end

-- ==========================================================================================
-- Survivants : points, atouts, armes
-- ==========================================================================================
type Person = { pts: number, perks: { [string]: boolean }, pap: { [string]: boolean }, p: string?, s: string?,
	downed: boolean, downT: number, revP: number, lastAttacker: any, prompt: ProximityPrompt? }

local function zOn(m: any): boolean return m ~= nil and m.mode == "zombies" and m.data and m.data.zs ~= nil end

local function person(m: any, c: any): Person
	local k = MS().keyOf(c)
	local p = m.data.people[k]
	if not p then
		p = { pts = Z.START_PTS, perks = {}, pap = {}, p = nil, s = nil, downed = false, downT = 0, revP = 0, lastAttacker = nil, prompt = nil }
		m.data.people[k] = p
	end
	return p
end

-- humains de la partie (vivants ou non) et vivants debout
local function humans(m: any): { any }
	local l = {}
	for _, c in ipairs(MS().combatants(m)) do if WeaponService.teamOf(c) == HUMANS then table.insert(l, c) end end
	return l
end
local function aliveHumans(m: any, standing: boolean?): { any }
	local l = {}
	for _, c in ipairs(humans(m)) do
		if MS().aliveChar(c) and (not standing or not person(m, c).downed) then table.insert(l, c) end
	end
	return l
end
local function rootOf(c: any): BasePart?
	local ch = WeaponService.charOf(c)
	return ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
end
local function flatDist(a: Vector3, b: Vector3): number return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude end

local function syncAttrs(m: any, c: any)
	if not isPlayer(c) then return end
	local p = person(m, c)
	c:SetAttribute("ZPts", p.pts)
	local perks = {}
	for _, k in ipairs(Z.PERK_ORDER) do if p.perks[k] then table.insert(perks, k) end end
	c:SetAttribute("ZPerks", table.concat(perks, ","))
	local pap = {}
	for k in pairs(p.pap) do table.insert(pap, k) end
	c:SetAttribute("ZPap", table.concat(pap, ","))
	c:SetAttribute("ZOwn", (p.p or "") .. "," .. (p.s or ""))
end

local function tell(c: any, text: string, color: Color3?, sound: string?)
	if isPlayer(c) and text ~= "" then popEvent:FireClient(c, text, color, sound) end
end

-- points (doublés pendant « Points doubles »)
local function zPts(m: any, c: any, n: number)
	if not c then return end
	local zs = m.data.zs
	n = math.floor(n * (if zs.dbl > now() then 2 else 1) + 0.5)
	local p = person(m, c)
	p.pts += n
	local s = MS().statOf(m, c)
	if s then s.pts = p.pts; s.score += n end
	if isPlayer(c) then c:SetAttribute("ZPts", p.pts); gainEvent:FireClient(c, n) end
end
local function zSpend(m: any, c: any, n: number): boolean
	local p = person(m, c)
	if p.pts < n then tell(c, "Pas assez de points (" .. n .. ")", Z.rgb(0xff6b6b), "deny"); return false end
	p.pts -= n
	local s = MS().statOf(m, c)
	if s then s.pts = p.pts end
	syncAttrs(m, c)
	return true
end

-- effets des atouts sur le personnage : cadence (lue aussi par WeaponController), vitesse
local function applyPerks(m: any, c: any)
	local ch = WeaponService.charOf(c)
	if not ch then return end
	local p = person(m, c)
	ch:SetAttribute("RateMult", if p.perks.dtap then 1.33 else nil)
	if isPlayer(c) then
		ch:SetAttribute("SpeedMult", if p.downed then 0.15 elseif p.perks.stamin then 1.18 else nil)
	end
	syncAttrs(m, c)
end

-- jeu d'armes : emplacement principal (p), pistolet (s), couteau
local function slotOf(key: string): string
	local w = Config.WEAPONS[key]
	return if w and w.slot == 1 then "s" else "p"
end
local function equip(m: any, c: any, select: string?)
	local p = person(m, c)
	local keys = {}
	if p.p then table.insert(keys, p.p) end
	if p.s then table.insert(keys, p.s) end
	table.insert(keys, "knife")
	WeaponService.setLoadoutKeep(c, keys, select)
	syncAttrs(m, c)
end
local function zGive(m: any, c: any, key: string)
	local p = person(m, c)
	local sl = slotOf(key)
	local old = if sl == "p" then p.p else p.s
	if old then p.pap[old] = nil end
	p.pap[key] = nil
	if sl == "p" then p.p = nil else p.s = nil end
	equip(m, c, nil)                              -- retire l'ancienne (ses munitions repartent à zéro)
	if sl == "p" then p.p = key else p.s = key end
	equip(m, c, key)
	tell(c, Config.WEAPONS[key].name, GOLD, "draw")
end
local function refillAll(m: any, c: any)
	local p = person(m, c)
	for _, k in ipairs({ p.p, p.s }) do
		if k then
			local _, res = WeaponService.ammoOf(c, k)
			local full = Config.WEAPONS[k].reserve * (if p.pap[k] then 2 else 1)
			if k == "p250" or k == "glock" then full = math.max(full, Z.START_RES) end
			WeaponService.setAmmo(c, k, WeaponService.magOf(c, k), math.max(res, full))
		end
	end
end

-- ==========================================================================================
-- Grille de la carte : cases libres, zones accessibles depuis la chapelle
-- ==========================================================================================
local N = MapData.N
local function cellIdx(cx: number, cz: number): number return cz * N + cx end
local function cellPos(m: any, cx: number, cz: number): Vector3
	return MS().cellToWorld(m, cx, cz)        -- centre de la case, au niveau du sol (MapBuilder)
end
local function walkable(g: any, i: number): boolean
	if g.blocked[i] then return false end
	return g.ramp[i] ~= 0 or g.h[i] < 1.4
end
local function zReach(m: any)
	local g = m.data.grid
	local sp = m.map.data.spawnCT[1]
	local start = cellIdx(sp[1], sp[2])
	local R = { [start] = true }
	local q = { start }
	while #q > 0 do
		local c = table.remove(q) :: number
		local cx, cz = c % N, c // N
		for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
			local nx, nz = cx + d[1], cz + d[2]
			if nx >= 0 and nz >= 0 and nx < N and nz < N then
				local ni = cellIdx(nx, nz)
				if not R[ni] and walkable(g, ni) and (g.ramp[ni] ~= 0 or g.ramp[c] ~= 0 or math.abs(g.h[ni] - g.h[c]) <= 1.3) then
					R[ni] = true; table.insert(q, ni)
				end
			end
		end
	end
	m.data.reach = R
	local cells = {}
	for i in pairs(R) do if g.ramp[i] == 0 then table.insert(cells, i) end end
	m.data.reachCells = cells
end
local function nearestFree(m: any, cx: number, cz: number): (number, number)
	local g = m.data.grid
	for r = 0, 4 do
		for dz = -r, r do for dx = -r, r do
			local x, z = cx + dx, cz + dz
			if x > 0 and z > 0 and x < N - 1 and z < N - 1 and walkable(g, cellIdx(x, z)) then return x, z end
		end end
	end
	return cx, cz
end
-- ligne de vue sur la grille (à 1,2 m du sol), comme losClear du web
local function gridLos(g: any, x0: number, z0: number, x1: number, z1: number): boolean
	local d = math.max(math.abs(x1 - x0), math.abs(z1 - z0))
	local steps = math.max(1, math.ceil(d * 4))
	for k = 1, steps - 1 do
		local t = k / steps
		local cx, cz = math.floor(x0 + (x1 - x0) * t), math.floor(z0 + (z1 - z0) * t)
		local i = cellIdx(cx, cz)
		if (g.h[i] or 0) > 1.2 and g.ramp[i] == 0 then return false end
	end
	return true
end

-- emplacements contre un mur (armes murales, boîte, machines) : zFindSpots du web
type Spot = { cx: number, cz: number, pos: Vector3, dx: number, dz: number }
local function findSpots(m: any): { Spot }
	local g = m.data.grid
	local out, seen = {}, {}
	local function free(cx: number, cz: number): boolean
		local i = cellIdx(cx, cz)
		return cx > 0 and cz > 0 and cx < N - 1 and cz < N - 1 and g.type[i] == 0 and g.h[i] == 0 and g.ramp[i] == 0 and not g.blocked[i]
	end
	local function wallAt(cx: number, cz: number): boolean
		if cx < 0 or cz < 0 or cx >= N or cz >= N then return true end
		local i = cellIdx(cx, cz)
		return g.h[i] >= 2.4 or g.blocked[i] == true
	end
	local list = {}
	for _, r in ipairs(m.map.data.roam or {}) do table.insert(list, r) end
	for _, r in ipairs(m.map.data.spawnDM or {}) do table.insert(list, r) end
	for _, r in ipairs(list) do
		for dz = -2, 2 do for dx = -2, 2 do
			local cx, cz = r[1] + dx, r[2] + dz
			local key = cx .. "," .. cz
			if not seen[key] and free(cx, cz) then
				seen[key] = true
				for _, o in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
					if wallAt(cx + o[1], cz + o[2]) and free(cx - o[1], cz - o[2]) and gridLos(g, r[1] + 0.5, r[2] + 0.5, cx + 0.5, cz + 0.5) then
						table.insert(out, { cx = cx, cz = cz, pos = cellPos(m, cx, cz), dx = o[1], dz = o[2] })
						break
					end
				end
			end
		end end
	end
	return out
end
local function pickSpread(list: { Spot }, n: number, avoid: { Spot }): { Spot }
	local res, pool = {}, table.clone(list)
	while #res < n and #pool > 0 do
		local best, bd = 1, -1
		for i, s in ipairs(pool) do
			local md = math.huge
			for _, p in ipairs(res) do md = math.min(md, flatDist(p.pos, s.pos)) end
			for _, p in ipairs(avoid) do md = math.min(md, flatDist(p.pos, s.pos)) end
			if #res == 0 and #avoid == 0 then md = math.random() end
			if md > bd then bd = md; best = i end
		end
		table.insert(res, table.remove(pool, best) :: Spot)
	end
	return res
end

-- ==========================================================================================
-- Construction : armes murales, boîte mystère, machines, Forge Arcane, débris, fragments
-- ==========================================================================================
local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, transp: number?): Part
	local p = Instance.new("Part"); p.Name = name; p.Anchored = true; p.Size = size; p.CFrame = cf; p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic; p.Transparency = transp or 0
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth; p.Parent = parent
	return p
end
local function surface(p: BasePart, face: Enum.NormalId, ppu: number?): SurfaceGui
	local sg = Instance.new("SurfaceGui"); sg.Face = face; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = ppu or 40
	sg.LightInfluence = 0; sg.Brightness = 1.4; sg.Parent = p
	return sg
end
local function text(parent: Instance, t: string, pos: UDim2, size: UDim2, color: Color3, font: Enum.Font?): TextLabel
	local l = Instance.new("TextLabel"); l.BackgroundTransparency = 1; l.Position = pos; l.Size = size; l.Text = t; l.TextColor3 = color
	l.TextScaled = true; l.Font = font or Enum.Font.GothamBlack; l.Parent = parent
	return l
end
local function prompt(parent: Instance, kind: string, action: string, object: string, dist: number): ProximityPrompt
	local pp = Instance.new("ProximityPrompt"); pp.Name = "ZPrompt"; pp.ActionText = action; pp.ObjectText = object
	pp.KeyboardKeyCode = Enum.KeyCode.E; pp.GamepadKeyCode = Enum.KeyCode.ButtonX; pp.HoldDuration = 0; pp.RequiresLineOfSight = false
	pp.MaxActivationDistance = dist * U; pp:SetAttribute("ZKind", kind); pp.Parent = parent
	return pp
end
-- objet posé contre le mur, face vers la pièce (zPlaceObj du web)
local function placeCF(s: Spot, depth: number, y: number): CFrame
	local d = Vector3.new(s.dx, 0, s.dz)
	local pos = s.pos + d * ((1 - depth / 2 - 0.02) * U) + Vector3.new(0, y * U, 0)
	return CFrame.lookAt(pos, pos - d)
end

local handleUse: (any, Player, ProximityPrompt) -> ()

local function hookPrompt(m: any, pp: ProximityPrompt)
	pp.Triggered:Connect(function(pl: Player)
		if m.closed or m.state ~= "live" or MS().matchOf(pl) ~= m then return end
		local ok, err = pcall(function() handleUse(m, pl, pp) end)
		if not ok then warn("[zombies]", err) end
	end)
end

local function buildWall(m: any, s: Spot, key: string, price: number)
	local d = Vector3.new(s.dx, 0, s.dz)
	local pos = s.pos + d * ((1 - 0.03) * U) + Vector3.new(0, 1.45 * U, 0)
	local p = part(m.data.folder, "WallBuy", Vector3.new(1.5 * U, 0.75 * U, 0.05), CFrame.lookAt(pos, pos - d), Color3.new(1, 1, 1), nil, 1)
	p.CanCollide = false; p.CanQuery = false
	local sg = surface(p, Enum.NormalId.Front, 30)
	local fr = Instance.new("Frame"); fr.BackgroundTransparency = 1; fr.Size = UDim2.fromScale(0.86, 0.62); fr.Position = UDim2.fromScale(0.07, 0.06); fr.Parent = sg
	local st = Instance.new("UIStroke"); st.Color = Color3.fromRGB(244, 244, 240); st.Thickness = 3; st.Transparency = 0.25; st.Parent = fr
	text(fr, "✏️ " .. string.upper(Config.WEAPONS[key].name), UDim2.fromScale(0.05, 0.2), UDim2.fromScale(0.9, 0.6), Color3.fromRGB(244, 244, 240), Enum.Font.PermanentMarker)
	text(sg, string.upper(Config.WEAPONS[key].name) .. " — " .. price, UDim2.fromScale(0, 0.74), UDim2.fromScale(1, 0.24), Color3.fromRGB(244, 244, 240), Enum.Font.PermanentMarker)
	local pp = prompt(p, "wall", "Acheter " .. Config.WEAPONS[key].name .. " — " .. price .. " pts", "Arme murale", 2.4)
	pp:SetAttribute("Weapon", key); pp:SetAttribute("Price", price)
	hookPrompt(m, pp)
end

local function buildBox(m: any, s: Spot, first: boolean)
	local zs = m.data.zs
	if zs.box and zs.box.model then zs.box.model:Destroy() end
	local model = Instance.new("Model"); model.Name = "MysteryBox"
	local cf = placeCF(s, 0.75, 0.31)
	local wood = Color3.fromRGB(74, 53, 32)
	local base = part(model, "Base", Vector3.new(1.5, 0.62, 0.75) * U, cf, wood, Enum.Material.WoodPlanks)
	local lid = part(model, "Lid", Vector3.new(1.52, 0.12, 0.77) * U, cf * CFrame.new(0, 0.37 * U, 0), Color3.fromRGB(58, 42, 24), Enum.Material.WoodPlanks)
	lid:SetAttribute("Closed", lid.CFrame)
	local q = surface(base, Enum.NormalId.Front, 30)
	text(q, "?", UDim2.fromScale(0.35, 0), UDim2.fromScale(0.3, 1), Color3.fromRGB(127, 224, 255), Enum.Font.Fantasy)
	local beam = part(model, "Beam", Vector3.new(40 * U, 0.9 * U, 0.9 * U), CFrame.new(cf.Position + Vector3.new(0, 20.6 * U, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(127, 224, 255), Enum.Material.Neon, 0.86)
	beam.Shape = Enum.PartType.Cylinder; beam.CanCollide = false; beam.CanQuery = false; beam.CastShadow = false
	local l = Instance.new("PointLight"); l.Color = Color3.fromRGB(127, 224, 255); l.Range = 3 * U; l.Brightness = 2; l.Parent = base
	model.PrimaryPart = base
	model:SetAttribute("BoxState", "idle")
	model.Parent = m.data.folder
	local pp = prompt(base, "box", "Boîte mystère — " .. Z.BOX_PRICE .. " pts", "Boîte mystère", 2.4)
	hookPrompt(m, pp)
	zs.box = { model = model, spot = s, state = "idle", t = 0, key = nil, owner = nil, teddy = false }
	if not first then
		for p in pairs(m.players) do tell(p, "La boîte mystère a changé de place !", Z.rgb(0x7fe0ff), "beep") end
	end
end

local function buildPerk(m: any, s: Spot, key: string)
	local pk = Z.PERKS[key]
	local model = Instance.new("Model"); model.Name = "Perk_" .. key
	local cf = placeCF(s, 0.7, 1.025)
	local body = part(model, "Body", Vector3.new(0.95, 2.05, 0.7) * U, cf, pk.c:Lerp(Color3.new(0, 0, 0), 0.45), Enum.Material.Metal)
	part(model, "Top", Vector3.new(1.02, 0.14, 0.76) * U, cf * CFrame.new(0, 1.075 * U, 0), Color3.fromRGB(34, 34, 34), Enum.Material.Metal)
	local lamp = part(model, "Lamp", Vector3.new(0.8, 0.06, 0.06) * U, cf * CFrame.new(0, 0.925 * U, -0.36 * U), pk.c, Enum.Material.Neon)
	lamp.CanCollide = false
	local sg = surface(body, Enum.NormalId.Front, 30)
	local bg = Instance.new("Frame"); bg.Size = UDim2.fromScale(1, 1); bg.BackgroundColor3 = pk.c; bg.Parent = sg
	local grad = Instance.new("UIGradient"); grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(30, 24, 18)); grad.Parent = bg
	text(bg, pk.ic, UDim2.fromScale(0.15, 0.12), UDim2.fromScale(0.7, 0.28), Color3.new(1, 1, 1))
	text(bg, string.upper(pk.n), UDim2.fromScale(0.05, 0.46), UDim2.fromScale(0.9, 0.1), Color3.new(1, 1, 1))
	text(bg, pk.price .. " points", UDim2.fromScale(0.1, 0.58), UDim2.fromScale(0.8, 0.07), Color3.fromRGB(255, 233, 176), Enum.Font.GothamBold)
	local l = Instance.new("PointLight"); l.Color = pk.c; l.Range = 2.6 * U; l.Brightness = 1.2; l.Parent = lamp
	model.Parent = m.data.folder
	local pp = prompt(body, "perk", pk.n .. " — " .. pk.price .. " pts", pk.d, 2.4)
	pp:SetAttribute("Perk", key); pp:SetAttribute("Price", pk.price)
	hookPrompt(m, pp)
end

local function buildPap(m: any, s: Spot)
	local model = Instance.new("Model"); model.Name = "ForgeArcane"
	local cf = placeCF(s, 0.85, 0.65)
	local body = part(model, "Body", Vector3.new(1.7, 1.3, 0.85) * U, cf, Color3.fromRGB(58, 37, 96), Enum.Material.Metal)
	local top = part(model, "Top", Vector3.new(0.5, 1.1, 1.1) * U, cf * CFrame.new(0, 0.9 * U, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(138, 77, 255), Enum.Material.Neon, 0.2)
	top.Shape = Enum.PartType.Cylinder
	local sg = surface(body, Enum.NormalId.Front, 30)
	local bg = Instance.new("Frame"); bg.Size = UDim2.fromScale(1, 1); bg.BackgroundColor3 = Color3.fromRGB(29, 20, 48); bg.Parent = sg
	local st = Instance.new("UIStroke"); st.Color = Color3.fromRGB(180, 107, 255); st.Thickness = 4; st.Parent = bg
	text(bg, "FORGE ARCANE", UDim2.fromScale(0.05, 0.2), UDim2.fromScale(0.9, 0.3), Color3.fromRGB(231, 200, 255))
	text(bg, "Améliore ton arme — " .. Z.PAP_PRICE .. " pts", UDim2.fromScale(0.08, 0.58), UDim2.fromScale(0.84, 0.16), Color3.fromRGB(255, 215, 94), Enum.Font.GothamBold)
	local l = Instance.new("PointLight"); l.Color = Color3.fromRGB(180, 107, 255); l.Range = 4 * U; l.Brightness = 2; l.Parent = top
	model.Parent = m.data.folder
	local pp = prompt(body, "pap", "Forge Arcane — " .. Z.PAP_PRICE .. " pts", "Forge Arcane", 2.6)
	hookPrompt(m, pp)
end

-- débris qui bouchent un passage (zSetupDoors / zDebrisMesh du web)
local function buildDoors(m: any)
	local g = m.data.grid
	m.data.doors = {}
	for k, dd in ipairs(m.map.data.zdoors or {}) do
		local price = dd.price or Z.DOOR_PRICES[k] or 1500
		local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
		local cells = {}
		for _, c in ipairs(dd.cells) do
			minX = math.min(minX, c[1]); maxX = math.max(maxX, c[1]); minZ = math.min(minZ, c[2]); maxZ = math.max(maxZ, c[2])
			local i = cellIdx(c[1], c[2]); g.blocked[i] = true; table.insert(cells, i)
		end
		local horiz = (maxX - minX) >= (maxZ - minZ)
		local n = #dd.cells
		local a = MS().cellToWorld(m, minX, minZ)
		local b = MS().cellToWorld(m, maxX, maxZ)
		local center = (a + b) / 2
		local model = Instance.new("Model"); model.Name = "Debris"
		local size = if horiz then Vector3.new(n * S, 2.4 * U, S) else Vector3.new(S, 2.4 * U, n * S)
		local block = part(model, "Blocker", size, CFrame.new(center + Vector3.new(0, 1.2 * U, 0)), Color3.new(0, 0, 0), nil, 1)
		local rot = if horiz then CFrame.identity else CFrame.Angles(0, math.rad(90), 0)
		local base = CFrame.new(center) * rot
		local W2 = n * 2
		local r = Random.new(k * 31)
		for j = 0, 5 do
			local plank = part(model, "Plank", Vector3.new(W2 * 1.05, 0.22, 0.08) * U, base * CFrame.new(0, (0.3 + j * 0.36) * U, (if j % 2 == 1 then 0.12 else -0.12) * U)
				* CFrame.Angles(0, 0, r:NextNumber(-0.18, 0.18)), if j % 2 == 1 then Color3.fromRGB(107, 74, 43) else Color3.fromRGB(59, 42, 26), Enum.Material.WoodPlanks)
			plank.CanCollide = false
		end
		for j = 0, n * 2 - 1 do
			local cr = part(model, "Crate", Vector3.new(0.8, 0.8, 0.8) * U, base * CFrame.new(r:NextNumber(-W2 / 2 + 0.4, W2 / 2 - 0.4) * U, (0.4 + (j % 2) * 0.8) * U,
				r:NextNumber(-0.6, 0.6) * U) * CFrame.Angles(0, r:NextNumber(0, 3), 0), if j % 3 ~= 0 then Color3.fromRGB(107, 74, 43) else Color3.fromRGB(85, 91, 98),
				if j % 3 ~= 0 then Enum.Material.WoodPlanks else Enum.Material.DiamondPlate)
			cr.CanCollide = false
		end
		local sign = part(model, "Sign", Vector3.new(1.2, 0.4, 0.05) * U, base * CFrame.new(0, 2.2 * U, 0.2 * U), Color3.fromRGB(255, 210, 58))
		sign.CanCollide = false
		local sg = surface(sign, Enum.NormalId.Front, 20)
		text(sg, "⚠ " .. price .. " ⚠", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Color3.fromRGB(17, 17, 17))
		local sgb = surface(sign, Enum.NormalId.Back, 20)
		text(sgb, "⚠ " .. price .. " ⚠", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Color3.fromRGB(17, 17, 17))
		model.Parent = m.data.folder
		local door = { cells = cells, price = price, model = model, open = false, pos = center }
		table.insert(m.data.doors, door)
		local pp = prompt(block, "door", "Dégager les débris — " .. price .. " pts", "Débris", 2.8)
		pp:SetAttribute("Price", price); pp:SetAttribute("Door", #m.data.doors)
		hookPrompt(m, pp)
	end
end
local function openDoor(m: any, door: any)
	if door.open then return end
	door.open = true
	for _, i in ipairs(door.cells) do m.data.grid.blocked[i] = nil end
	if door.model then door.model:Destroy() end
	zReach(m)
	MS().announce(m, "ZONE OUVERTE", "", GOLD)
end

-- easter egg : 3 fragments de l'Orbe aux points les plus éloignés du départ
local function buildEgg(m: any)
	m.data.frags = {}; m.data.fragGot = 0
	local sp = m.map.data.spawnCT[1]
	local pts = {}
	for _, r in ipairs(m.map.data.roam or {}) do table.insert(pts, r) end
	for _, r in ipairs(m.map.data.spawnDM or {}) do table.insert(pts, r) end
	table.sort(pts, function(a, b)
		return hypot(b[1] - sp[1], b[2] - sp[2]) < hypot(a[1] - sp[1], a[2] - sp[2])
	end)
	local chosen = {}
	for _, p in ipairs(pts) do
		if #chosen >= 3 then break end
		local ok = true
		for _, c in ipairs(chosen :: { any }) do if hypot(c[1] - p[1], c[2] - p[2]) <= 8 then ok = false end end
		if ok then table.insert(chosen, p) end
	end
	for _, c in ipairs(chosen) do
		local fx, fz = nearestFree(m, c[1], c[2])
		local pos = cellPos(m, fx, fz) + Vector3.new((math.random() - 0.5) * 1.2 * U, 0.45 * U, (math.random() - 0.5) * 1.2 * U)
		local f = part(m.data.folder, "OrbFragment", Vector3.new(0.22, 0.22, 0.22) * U, CFrame.new(pos) * CFrame.Angles(math.rad(45), 0, math.rad(35)), Color3.fromRGB(199, 125, 255), Enum.Material.Neon)
		f.CanCollide = false; f.CanQuery = false
		local l = Instance.new("PointLight"); l.Color = Color3.fromRGB(180, 107, 255); l.Range = 2.5 * U; l.Brightness = 2; l.Parent = f
		table.insert(m.data.frags, { part = f, pos = pos })
	end
end

-- ==========================================================================================
-- Bonus lâchés par les zombies
-- ==========================================================================================
local function zDrop(m: any, pos: Vector3)
	local key = Z.DROP_ORDER[math.random(#Z.DROP_ORDER)]
	local d = Z.DROPS[key]
	local p = part(m.data.folder, "Drop_" .. key, Vector3.new(0.5, 0.5, 0.5) * U, CFrame.new(pos + Vector3.new(0, 1 * U, 0)), d.c, Enum.Material.Neon, 0.35)
	p.Shape = Enum.PartType.Ball; p.CanCollide = false; p.CanQuery = false
	local bb = Instance.new("BillboardGui"); bb.Size = UDim2.fromOffset(64, 64); bb.AlwaysOnTop = false; bb.LightInfluence = 0; bb.Parent = p
	local l = text(bb, d.ic, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), d.c)
	l.TextStrokeTransparency = 0.3
	local pl = Instance.new("PointLight"); pl.Color = d.c; pl.Range = 3 * U; pl.Brightness = 2; pl.Parent = p
	table.insert(m.data.drops, { key = key, part = p, pos = pos, t = 26 })
end
local function applyDrop(m: any, key: string, who: any)
	local d = Z.DROPS[key]
	local zs = m.data.zs
	MS().announce(m, d.n, "", d.c)
	for p in pairs(m.players) do popEvent:FireClient(p, "", nil, "pickup") end
	if key == "ammo" then
		for _, h in ipairs(aliveHumans(m)) do refillAll(m, h) end
	elseif key == "insta" then zs.insta = now() + 30
	elseif key == "dbl" then zs.dbl = now() + 30
	elseif key == "fire" then zs.fire = now() + 30
	elseif key == "nuke" then
		m.data.nuking = true
		for _, z in ipairs(ZombieService.ofMatch(m.id)) do
			local h = z:FindFirstChildOfClass("Humanoid")
			if h then
				local ex = Instance.new("Explosion"); ex.Position = (z:GetPivot()).Position; ex.BlastPressure = 0; ex.BlastRadius = 1.5 * U
				ex.DestroyJointRadiusPercent = 0; ex.Parent = workspace
				WeaponService.applyDamage(who, z, h.Health + 999, false, "frag", 1)
			end
		end
		m.data.nuking = false
		for _, h in ipairs(humans(m)) do zPts(m, h, 400) end
	end
end

-- ==========================================================================================
-- Joueurs à terre, Second Souffle, réanimation
-- ==========================================================================================
local function clearDown(m: any, c: any)
	local p = person(m, c)
	p.downed = false; p.revP = 0
	if p.prompt then p.prompt:Destroy(); p.prompt = nil end
	local ch = WeaponService.charOf(c)
	if ch then
		ch:SetAttribute("Downed", nil); ch:SetAttribute("DownT", nil)
		if not isPlayer(c) then ch:SetAttribute("Frozen", nil) end
		local h = ch:FindFirstChildOfClass("Humanoid")
		if h and isPlayer(c) then h.JumpPower = 50; h.JumpHeight = 7.2 end
	end
	applyPerks(m, c)
end
local function zRevive(m: any, v: any, by: any)
	local ch = MS().aliveChar(v)
	clearDown(m, v)
	if not ch then return end
	local h = ch:FindFirstChildOfClass("Humanoid")
	if h then h.Health = math.min(h.MaxHealth, 60) end
	ch:SetAttribute("ProtectedUntil", workspace:GetServerTimeNow() + 1.5)
	if isPlayer(v) then MS().announce(m, "RÉANIMÉ", "", Z.rgb(0x7dff9f), v) end
	if by and isPlayer(by) then zPts(m, by, 100); tell(by, "Allié réanimé (+100)", Z.rgb(0x7dff9f), "heal") end
end
local function zDown(m: any, v: any)
	local p = person(m, v)
	local ch = WeaponService.charOf(v)
	if not ch then return end
	p.downed = true; p.downT = 30; p.revP = 0; p.perks = {}
	ch:SetAttribute("Downed", true); ch:SetAttribute("DownT", 30)
	ch:SetAttribute("ProtectedUntil", workspace:GetServerTimeNow() + 1e6)   -- les zombies ignorent les joueurs à terre
	local h = ch:FindFirstChildOfClass("Humanoid")
	if isPlayer(v) then
		if h then h.JumpPower = 0; h.JumpHeight = 0 end
		MS().announce(m, "À TERRE !", "Un allié doit te réanimer — tu peux encore tirer", Z.rgb(0xff4655), v)
		popEvent:FireClient(v, "", nil, "dmg")
	else
		ch:SetAttribute("Frozen", true)
		if h then h:Move(Vector3.zero) end
	end
	-- on garde le pistolet en main
	if p.s then
		local idx = table.find(WeaponService.loadoutOf(v), p.s)
		if idx then WeaponService.switchTo(v, idx) end
	end
	applyPerks(m, v)
	local root = ch:FindFirstChild("HumanoidRootPart")
	if root then
		local pp = prompt(root, "revive", "Réanimer", WeaponService.nameOf(v), 1.9)
		pp.HoldDuration = 3
		pp:SetAttribute("Target", MS().keyOf(v) == v and (v :: Player).UserId or 0)
		p.prompt = pp
		pp.Triggered:Connect(function(pl: Player)
			if pl == v or MS().matchOf(pl) ~= m or not p.downed then return end
			if person(m, pl).downed or not MS().aliveChar(pl) then return end
			zRevive(m, v, pl)
		end)
	end
	-- plus personne debout : tout le monde saigne
	for p2 in pairs(m.players) do if p2 ~= v then tell(p2, WeaponService.nameOf(v) .. " est à terre !", Z.rgb(0xff4655), nil) end end
end
local function bleedOut(m: any, v: any)
	local p = person(m, v)
	local ch = MS().aliveChar(v)
	clearDown(m, v)
	if not ch then return end
	ch:SetAttribute("ProtectedUntil", 0)
	local h = ch:FindFirstChildOfClass("Humanoid")
	if h then WeaponService.applyDamage(p.lastAttacker, ch, h.Health + 999, false, "Saignement", 1) end
	if h and h.Health > 0 then h.Health = 0 end
end
-- true = le coup ne tue pas (à terre avec des alliés debout, ou Second Souffle seul) : zSave du web
local function zSave(m: any, v: any): boolean
	local p = person(m, v)
	if p.downed then return true end
	local others = 0
	for _, c in ipairs(aliveHumans(m, true)) do if c ~= v then others += 1 end end
	if others > 0 then zDown(m, v); return true end
	if not p.perks.revive then return false end
	p.perks = {}
	local ch = MS().aliveChar(v)
	local h = ch and ch:FindFirstChildOfClass("Humanoid")
	if h then h.Health = math.min(h.MaxHealth, 100) end
	if ch then ch:SetAttribute("ProtectedUntil", workspace:GetServerTimeNow() + 2.5) end
	applyPerks(m, v)
	if isPlayer(v) then MS().announce(m, "SECOND SOUFFLE", "Tu te relèves… atouts perdus", Z.rgb(0x4aa3ff), v) end
	local r = rootOf(v)
	if r then
		for _, z in ipairs(ZombieService.ofMatch(m.id)) do
			local zp = z:GetPivot().Position
			if flatDist(zp, r.Position) < 4 * U then ZombieService.push(z, zp - r.Position, 2 * U) end
		end
	end
	return true
end

-- morsure d'un zombie (hurt du web) : Mastodonte encaisse, à terre plutôt que mort
local function onBite(m: any, z: Model, target: Model, dmg: number)
	if m.state ~= "live" then return end
	local c = WeaponService.combatantOf(target)
	if MS().matchOf(c) ~= m then return end
	local p = person(m, c)
	if p.downed then return end
	local h = target:FindFirstChildOfClass("Humanoid")
	if not h or h.Health <= 0 then return end
	local pu = target:GetAttribute("ProtectedUntil")
	if typeof(pu) == "number" and pu > workspace:GetServerTimeNow() then return end
	if p.perks.jugg then dmg *= 0.45 end
	p.lastAttacker = z
	local shield = WeaponService.shieldOf(c)
	if h.Health + shield - dmg <= 0.5 then
		if zSave(m, c) then
			if h.Health > 1 then WeaponService.applyDamage(z, target, math.max(0, h.Health - 1 + shield), false, "Morsure", 1) end
			if p.downed then h.Health = 1 end
			return
		end
	end
	WeaponService.applyDamage(z, target, dmg, false, "Morsure", 1)
end

-- ==========================================================================================
-- Zombies et manches
-- ==========================================================================================
local function zDiff(m: any): any return Z.ZDIFF[math.clamp(m.settings.diff, 1, #Z.ZDIFF)] end

local function zTargets(m: any): { Model }
	local out = {}
	local t = workspace:GetServerTimeNow()
	for _, c in ipairs(aliveHumans(m, true)) do
		local ch = WeaponService.charOf(c)
		local pu = ch and ch:GetAttribute("ProtectedUntil")
		if ch and not (typeof(pu) == "number" and pu > t) then table.insert(out, ch) end
	end
	return out
end

-- case accessible la plus éloignée des humains (zReachSpot)
local function reachSpot(m: any, hum: { Vector3 }): { number }?
	local cells = m.data.reachCells
	if not cells or #cells == 0 then return nil end
	local best, bd = nil, -1
	for _ = 1, 40 do
		local i = cells[math.random(#cells)]
		local p = cellPos(m, i % N, i // N)
		local md = math.huge
		for _, h in ipairs(hum) do md = math.min(md, flatDist(h, p)) end
		if md > bd then bd = md; best = { i % N, i // N } end
	end
	return best
end

local function zSpawn(m: any)
	local zs = m.data.zs
	local hum = {}
	for _, c in ipairs(aliveHumans(m)) do local r = rootOf(c); if r then table.insert(hum, r.Position) end end
	if #hum == 0 then return end
	local cand = {}
	for _, r in ipairs(m.map.data.roam or {}) do table.insert(cand, r) end
	for _, r in ipairs(m.map.data.spawnDM or {}) do table.insert(cand, r) end
	if m.data.reach then
		local f = {}
		for _, c in ipairs(cand) do local x, z = nearestFree(m, c[1], c[2]); if m.data.reach[cellIdx(x, z)] then table.insert(f, c) end end
		if #f > 0 then cand = f end
	end
	local best, bd = nil, -1
	for _ = 1, 8 do
		local c = cand[math.random(#cand)]
		local p = cellPos(m, c[1], c[2])
		local md = math.huge
		for _, h in ipairs(hum) do md = math.min(md, flatDist(h, p) / U) end
		if md > bd and md > 14 then bd = md; best = c end
	end
	if m.data.reach then
		local s = reachSpot(m, hum)
		if s and (not best or bd < 10) then best = s end
	end
	if not best then best = cand[math.random(#cand)] end
	local bx, bz = nearestFree(m, best[1], best[2])
	-- type de zombie (zSpawn + zSpecialType)
	local w = zs.wave
	local r = math.random()
	local ztype = if w >= 4 and r < 0.07 then "tank" elseif r < math.min(0.7, (w - 2) * 0.12) then "runner" else "normal"
	if zs.boss > 0 and (math.random() < 0.12 or zs.queue < 6) then zs.boss -= 1; ztype = "boss"
	elseif zs.special and math.random() < 0.75 then ztype = "crawler" end
	local hp = (if ztype == "tank" then 3 elseif ztype == "runner" then 0.7 else 1) * (if w < 10 then 100 + 55 * (w - 1) else 595 * math.pow(1.08, w - 9))
	local speed = if ztype == "runner" then 5 + math.min(1, w * 0.05) elseif ztype == "tank" then 2.6 else 2.3 + math.min(1.6, w * 0.13)
	local dmg = if ztype == "tank" then 28 else 12 + w
	if ztype == "crawler" then hp *= 0.55; speed = 4.6; dmg = math.floor(dmg * 0.7 + 0.5) end
	if ztype == "boss" then hp = 1500 + w * 400; speed = 2.9; dmg = 45 end
	local d = zDiff(m)
	hp = math.max(1, math.floor(hp * d.hp + 0.5))
	speed = math.min(speed * Z.ZSLOW * d.spd, Z.RUN * 0.9 * d.spd)
	dmg = math.max(1, math.floor(dmg * d.dmg + 0.5))
	-- porteur de munitions : tous sortent avant la fin de la manche
	local carrier = false
	if zs.ammoLeft > 0 and ztype ~= "boss" and math.random() < zs.ammoLeft / math.max(1, zs.queue) then zs.ammoLeft -= 1; carrier = true end
	zs.nextId += 1
	ZombieService.spawn({
		match = m.id, parent = m.data.zfolder, pos = cellPos(m, bx, bz), ztype = ztype, hp = hp, speed = ZombieService.metersToSpeed(speed), dmg = dmg, atk = d.atk,
		carrier = carrier, id = zs.nextId,
		targets = function() return zTargets(m) end,
		onHit = function(z: Model, t: Model, n: number) onBite(m, z, t, n) end,
	})
end

-- alliés bots : ils dépensent leurs points à chaque manche (zBotsShop)
local function botsShop(m: any)
	for _, b in ipairs(aliveHumans(m)) do
		if not isPlayer(b) then
			local p = person(m, b)
			if not p.perks.jugg and p.pts >= Z.PERKS.jugg.price + 500 then p.pts -= Z.PERKS.jugg.price; p.perks.jugg = true
			elseif p.p and not p.pap[p.p] and p.pts >= Z.PAP_PRICE + 800 then
				p.pts -= Z.PAP_PRICE; p.pap[p.p] = true
				WeaponService.setAmmo(b, p.p, WeaponService.magOf(b, p.p), Config.WEAPONS[p.p].reserve * 2)
			elseif p.pts >= 1500 then
				local w = ({ "m4", "ak", "famas", "ump", "xm" })[math.random(5)]
				if not p.p or Config.WEAPONS[p.p].price < Config.WEAPONS[w].price then p.pts -= 1500; zGive(m, b, w) end
			end
			local s = MS().statOf(m, b); if s then s.pts = p.pts end
		end
	end
end

local function zStartWave(m: any)
	local zs = m.data.zs
	zs.wave += 1
	zs.queue = 7 + zs.wave * 5
	zs.state = "spawn"; zs.spawnT = 1.2
	MS().announce(m, "MANCHE " .. zs.wave, if zs.wave == 1 then "Gagne des points, achète des armes aux murs, tente la boîte mystère" else "Ils sont plus nombreux…", RED)
	-- les morts reviennent près d'un allié vivant (60 PV), les vivants regagnent 35 PV
	local alive = aliveHumans(m)
	local sp = m.map.data.spawnCT[1]
	local nearCell = { sp[1], sp[2] }
	local fr = alive[1] and rootOf(alive[1])
	if fr then
		local lp = fr.Position - m.origin
		nearCell = { math.floor(lp.X / S), math.floor(lp.Z / S) }
	end
	local nx, nz = nearestFree(m, nearCell[1] + 1, nearCell[2])
	m.data.respawnAt = cellPos(m, nx, nz)
	for p in pairs(m.players) do
		if not MS().aliveChar(p) then m.data.waveRespawn[p] = true; MS().respawn(m, p) end
	end
	for k, s in pairs(m.stats) do
		if s.bot and s.team == HUMANS and not (s.model and MS().aliveChar(s.model)) then
			local name = string.sub(tostring(k), 5)
			m.data.waveRespawn[k] = true
			MS().spawnBot(m, HUMANS, name)
		end
	end
	local t = workspace:GetServerTimeNow()
	for _, c in ipairs(alive) do
		local ch = WeaponService.charOf(c)
		local h = ch and ch:FindFirstChildOfClass("Humanoid")
		if h and not person(m, c).downed then h.Health = math.min(100, h.Health + 35) end
		WeaponService.giveGrenades(c, 0, 0, 2)
		if ch and isPlayer(c) and not person(m, c).downed then ch:SetAttribute("ProtectedUntil", t + 1.5) end
	end
	-- zOnWave : manches spéciales, bonus, achats des bots, porteurs de munitions, difficulté
	zs.special = zs.wave % 5 == 0
	zs.boss = if zs.wave % 10 == 0 then 1 else 0
	if zs.special then
		zs.queue = math.floor(zs.queue * 1.3 + 0.5)
		task.delay(2.8, function() if not m.closed then MS().announce(m, "MANCHE DES RÔDEURS", "Ils rampent… et ils sont rapides", Z.rgb(0xb06bff)) end end)
	end
	if zs.boss > 0 then
		task.delay(if zs.special then 5.6 else 2.8, function() if not m.closed then MS().announce(m, "LA BRUTE ARRIVE", "Un boss rejoint la manche", Z.rgb(0xff3030)) end end)
	end
	zs.dropsWave = 0
	botsShop(m)
	zs.ammoLeft = math.min(5, #humans(m))
	zs.queue = math.max(4, math.floor(zs.queue * zDiff(m).n + 0.5))
	local allyDiff = Modes.DIFFS[math.max(3, m.settings.diff)]
	for _, c in ipairs(humans(m)) do if not isPlayer(c) then BotService.setDiff(c, allyDiff) end end
	for p in pairs(m.players) do popEvent:FireClient(p, "", nil, "round") end
end

-- ==========================================================================================
-- Interactions (touche E) : zInteractFor du web
-- ==========================================================================================
handleUse = function(m: any, pl: Player, pp: ProximityPrompt)
	local p = person(m, pl)
	if p.downed or not MS().aliveChar(pl) then return end
	local zs = m.data.zs
	local kind = pp:GetAttribute("ZKind")
	if kind == "wall" then
		local key = pp:GetAttribute("Weapon") :: string
		local price = pp:GetAttribute("Price") :: number
		local own = p.p == key or p.s == key
		local pr = if own then math.floor(price / 2 + 0.5) else price
		if not zSpend(m, pl, pr) then return end
		if own then
			WeaponService.setAmmo(pl, key, WeaponService.magOf(pl, key), Config.WEAPONS[key].reserve * (if p.pap[key] then 2 else 1))
			tell(pl, "Munitions rechargées", GOLD, "pickup")
		else
			zGive(m, pl, key); popEvent:FireClient(pl, "", nil, "buy")
		end
	elseif kind == "box" then
		local b = zs.box
		if not b then return end
		if b.state == "idle" then
			local price = if zs.fire > now() then 10 else Z.BOX_PRICE
			if not zSpend(m, pl, price) then return end
			b.state = "roll"; b.t = 0; b.owner = pl; zs.boxUses += 1
			b.teddy = zs.boxUses > 3 and math.random() < 0.16 and #zs.boxSpots > 1
			local pool = {}
			for _, k in ipairs(Z.BOXPOOL) do if k ~= p.p and k ~= p.s then table.insert(pool, k) end end
			b.key = pool[math.random(#pool)]
			b.model:SetAttribute("BoxState", "roll"); b.model:SetAttribute("BoxT", workspace:GetServerTimeNow())
			b.model:SetAttribute("BoxOwner", pl.UserId); b.model:SetAttribute("BoxWeapon", nil)
			popEvent:FireClient(pl, "", nil, "beep")
		elseif b.state == "ready" and b.owner == pl and b.key then
			zGive(m, pl, b.key)
			b.state = "idle"; b.model:SetAttribute("BoxState", "idle"); b.model:SetAttribute("BoxWeapon", nil)
		end
	elseif kind == "perk" then
		local key = pp:GetAttribute("Perk") :: string
		local pk = Z.PERKS[key]
		if p.perks[key] then tell(pl, pk.n .. " (déjà bu)", pk.c, "deny"); return end
		if not zSpend(m, pl, pk.price) then return end
		p.perks[key] = true
		applyPerks(m, pl)
		MS().announce(m, string.upper(pk.n), pk.d, pk.c, pl)
	elseif kind == "door" then
		local door = m.data.doors[pp:GetAttribute("Door") :: number]
		if not door or door.open then return end
		if not zSpend(m, pl, door.price) then return end
		openDoor(m, door)
	elseif kind == "pap" then
		local key = WeaponService.current(pl)
		if not key or key == "knife" then tell(pl, "Forge Arcane : prends une arme en main", Z.rgb(0xc77dff), "deny"); return end
		if p.pap[key] then tell(pl, Config.WEAPONS[key].name .. " est déjà améliorée", Z.rgb(0xc77dff), "deny"); return end
		if not zSpend(m, pl, Z.PAP_PRICE) then return end
		p.pap[key] = true
		WeaponService.setAmmo(pl, key, WeaponService.magOf(pl, key), Config.WEAPONS[key].reserve * 2)
		syncAttrs(m, pl)
		MS().announce(m, "ARME AMÉLIORÉE", Config.WEAPONS[key].name .. " ★ — dégâts ×2, chargeur +50 %", Z.rgb(0xc77dff), pl)
	end
end

-- ==========================================================================================
-- Crochets globaux (installés une fois) : dégâts sur les zombies, multiplicateurs d'armes, cibles des bots
-- ==========================================================================================
local prevFilter = WeaponService.damageFilter
WeaponService.damageFilter = function(attacker: any, victimChar: Model, raw: number, headshot: boolean, key: string): number?
	local r: number? = raw
	if prevFilter then r = prevFilter(attacker, victimChar, raw, headshot, key) end
	if r == nil then return nil end
	if not ZombieService.isZombie(victimChar) then return r end
	local m = MS().matchOf(victimChar)
	if not zOn(m) or MS().matchOf(attacker) ~= m or WeaponService.teamOf(attacker) ~= HUMANS then return r end
	if m.data.nuking then return r end
	local p = person(m, attacker)
	local w = Config.WEAPONS[key]
	local wonder = Z.isWonder(key)
	local out = r :: number
	if p.pap[key] then out *= if wonder then 1.5 else 2 end
	if p.perks.dtap and w and not w.melee and not wonder then out *= 1.5 end
	if m.data.zs.insta > now() then
		local h = victimChar:FindFirstChildOfClass("Humanoid")
		out = (if h then h.Health else 0) + 999
	end
	m.data.lastHit[attacker] = { model = victimChar, t = os.clock() }
	zPts(m, attacker, 10)
	return out
end

WeaponService.modFn = function(c: any, key: string, what: string): number
	local m = MS().matchOf(c)
	if not zOn(m) then return 1 end
	local p = m.data.people[MS().keyOf(c)]
	if not p then return 1 end
	if what == "rate" and p.perks.dtap then return 1.33 end
	if what == "reload" and p.perks.speed then return 0.5 end
	if what == "mag" and p.pap[key] then return 1.5 end
	return 1
end

local prevTargets = BotService.extraTargets
BotService.extraTargets = function(team: string, matchId: number): { Model }
	local out = if prevTargets then prevTargets(team, matchId) else {}
	local m = MS().get(matchId)
	if zOn(m) and team == HUMANS then
		for _, z in ipairs(ZombieService.ofMatch(matchId)) do table.insert(out, z) end
	end
	return out
end

-- élimination d'un zombie (zKillHook + porteurs de munitions)
WeaponService.Killed:Connect(function(killer: any, victim: any, key: string, headshot: boolean)
	if not ZombieService.isZombie(victim) then return end
	local m = MS().matchOf(victim)
	if not zOn(m) or m.state ~= "live" then return end
	local zs = m.data.zs
	local z = victim :: Model
	local zpos = z:GetPivot().Position
	local human = if killer and MS().matchOf(killer) == m and WeaponService.teamOf(killer) == HUMANS then killer else nil
	local ks = human and MS().statOf(m, human)
	local w = Config.WEAPONS[key]
	if human and ks then
		ks.k += 1; ks.streak += 1; ks.bestStreak = math.max(ks.bestStreak, ks.streak)
		if headshot then ks.hs += 1 end
		ks.weaponKills[key] = (ks.weaponKills[key] or 0) + 1
		local before = person(m, human).pts
		zPts(m, human, if w and w.melee then 120 elseif headshot then 90 else 50)
		if isPlayer(human) then
			bannerEvent:FireClient(human, { victim = "Zombie", headshot = headshot, points = person(m, human).pts - before, streak = ks.streak, streakName = nil })
			RewardService.missionEvent(human, "kills")
			if headshot then RewardService.missionEvent(human, "hs") end
			if key == "knife" then RewardService.missionEvent(human, "knife") end
		end
	end
	MS().fire(m, feedEvent, { killer = if ks then ks.name else "?", killerTeam = HUMANS, victim = "Zombie", victimTeam = "Zombies",
		weapon = MS().weaponName(key), key = key, headshot = headshot })
	if ZombieService.typeOf(z) == "boss" then
		if human then zPts(m, human, 1000) end
		zDrop(m, zpos)
		MS().announce(m, "BRUTE ÉLIMINÉE", "+1000", GOLD)
	end
	if math.random() < 0.035 and zs.dropsWave < 4 then zs.dropsWave += 1; zDrop(m, zpos) end
	if z:GetAttribute("AmmoCarrier") then
		z:SetAttribute("AmmoCarrier", nil)
		local h = if human and MS().aliveChar(human) then human else nil
		if not h then
			local bd = math.huge
			for _, c in ipairs(aliveHumans(m)) do
				local r = rootOf(c)
				if r and flatDist(r.Position, zpos) < bd then bd = flatDist(r.Position, zpos); h = c end
			end
		end
		if h then
			refillAll(m, h)
			if isPlayer(h) then MS().announce(m, "MUNITIONS RECHARGÉES", "Zombie porteur éliminé", GOLD, h); popEvent:FireClient(h, "", nil, "pickup") end
		end
	end
	m.dmgBy[MS().keyOf(z)] = nil
	task.delay(4, function() WeaponService.reset(z); ZombieService.remove(z) end)
end)

-- armes prodiges : effets de zone en plus du tir (wonderFire du web)
local function wonderEnemies(m: any): { Model }
	return ZombieService.ofMatch(m.id)
end
WeaponService.ShotFired:Connect(function(c: any, key: string)
	local wdef = Z.WONDERS[key]
	if not wdef then return end
	local m = MS().matchOf(c)
	if not zOn(m) then return end
	local ch = WeaponService.charOf(c)
	local head = ch and ch:FindFirstChild("Head") :: BasePart?
	local root = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not ch or not head or not root then return end
	local pitch = ch:GetAttribute("Pitch")
	local dir = (root.CFrame * CFrame.Angles(if typeof(pitch) == "number" then pitch else 0, 0, 0)).LookVector
	local origin = head.Position
	local shotT = os.clock()
	local pap = person(m, c).pap[key] == true
	task.delay(0.05, function()
		-- zombie touché directement par ce tir (noté par le filtre de dégâts) : il a déjà pris les dégâts du tir
		local lh = m.data.lastHit[c]
		local direct: Model? = if lh and lh.t >= shotT - 0.01 then lh.model else nil
		local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances = { ch, m.data.zfolder }
		local function los(to: Vector3): boolean
			local r = workspace:Raycast(origin, to - origin, params)
			return r == nil or (r.Position - origin).Magnitude >= (to - origin).Magnitude - 0.5 * U
		end
		if wdef.wonder == "ray" then
			local r = workspace:Raycast(origin, dir * 120 * U, params)
			local impact = if r then r.Position else origin + dir * 120 * U
			if direct then impact = direct:GetPivot().Position end
			for _, z in ipairs(wonderEnemies(m)) do
				if z ~= direct and (z:GetPivot().Position - impact).Magnitude < 2.8 * U then
					WeaponService.applyDamage(c, z, wdef.dmg * 0.6, false, key, 1)
				end
			end
		else
			local range = (if wdef.wonder == "thunder" then (if pap then 18 else 14) else (if pap then 14 else 11)) * U
			local cone = if wdef.wonder == "thunder" then (if pap then 0.72 else 0.6) else 0.42
			for _, z in ipairs(wonderEnemies(m)) do
				local zp = z:GetPivot().Position
				local to = zp - origin
				local L = to.Magnitude
				if L <= range and L > 0.01 and to.Unit:Dot(dir) >= math.cos(cone) and los(zp) then
					if wdef.wonder == "thunder" then
						if z ~= direct then WeaponService.applyDamage(c, z, wdef.dmg, false, key, 1) end
						ZombieService.push(z, to, 3 * U)
					else
						ZombieService.freeze(z, if pap then 4 else 2.6)
						WeaponService.applyDamage(c, z, if z == direct then wdef.dmg * 0.5 else wdef.dmg * 1.5, false, key, 1)
					end
				end
			end
		end
	end)
end)

-- ==========================================================================================
-- Interface du mode (MatchService)
-- ==========================================================================================
function M.setup(m: any)
	Z.registerWeapons()
	-- la grille de MapData est partagée (cache) : les débris fermés vont dans une table à part
	local g = (m.map and m.map.grid) or MapData.buildGrid(m.settings.map)
	m.data.grid = setmetatable({ blocked = {} }, { __index = g })
	m.data.limit = m.settings.limit or 15
	m.limit = nil                                   -- pas de « PREMIER À » : on compte les manches
	m.data.people = {}
	m.data.lastHit = {}
	m.data.drops = {}
	m.data.waveRespawn = {}
	m.data.zs = { wave = 0, queue = 0, state = "wait", breakT = 6, spawnT = 0, special = false, boss = 0, dropsWave = 0, ammoLeft = 0, nextId = 100,
		insta = 0, dbl = 0, fire = 0, box = nil, boxSpots = {}, boxIdx = 1, boxUses = 0, result = nil }
	local folder = Instance.new("Folder"); folder.Name = "Zombies"; folder.Parent = m.map.folder
	m.data.folder = folder
	local zf = Instance.new("Folder"); zf.Name = "Horde"; zf.Parent = m.map.folder
	m.data.zfolder = zf
	m.map.folder:SetAttribute("Atmosphere", "haunt")
	buildDoors(m)
	zReach(m)
	buildEgg(m)
	-- armes murales près du départ, boîte mystère, Forge Arcane et machines à atouts réparties sur la carte (zSetup du web)
	local spots = findSpots(m)
	local sp = m.map.data.spawnCT[1]
	local home = MS().cellToWorld(m, sp[1], sp[2])
	local near = table.clone(spots)
	table.sort(near, function(a, b) return flatDist(a.pos, home) < flatDist(b.pos, home) end)
	local reach = m.data.reach
	local function inStart(s: Spot): boolean return reach[cellIdx(s.cx, s.cz)] == true end
	local first: Spot? = nil
	for _, s in ipairs(near) do if inStart(s) and flatDist(s.pos, home) > 2 * U then first = s; break end end
	if not first then for _, s in ipairs(near) do if inStart(s) then first = s; break end end end
	first = first or near[1]
	local walls: { Spot } = {}
	if first then
		walls = { first }
		local pool = {}
		for i = 1, math.max(10, #near // 2) do local s = near[i]; if s and s ~= first then table.insert(pool, s) end end
		for _, s in ipairs(pickSpread(pool, math.min(#Z.WALLBUYS, 7) - 1, { first })) do table.insert(walls, s) end
	end
	local rest = {}
	for _, s in ipairs(spots) do if not table.find(walls, s) then table.insert(rest, s) end end
	local boxSpots = pickSpread(rest, 3, walls)
	local i0 = nil
	for i, s in ipairs(boxSpots) do if inStart(s) then i0 = i; break end end
	if i0 and i0 > 1 then table.insert(boxSpots, 1, table.remove(boxSpots, i0) :: Spot)
	elseif not i0 then
		local st = {}
		for _, s in ipairs(rest) do if inStart(s) and not table.find(boxSpots, s) then table.insert(st, s) end end
		if #st > 0 then table.insert(boxSpots, 1, st[math.random(#st)]) end
	end
	local rest2 = {}
	for _, s in ipairs(rest) do if not table.find(boxSpots, s) then table.insert(rest2, s) end end
	local avoid = table.clone(walls)
	for _, s in ipairs(boxSpots) do table.insert(avoid, s) end
	local machines = pickSpread(rest2, 6, avoid)
	for i, s in ipairs(walls) do buildWall(m, s, Z.WALLBUYS[i][1], Z.WALLBUYS[i][2]) end
	m.data.zs.boxSpots = boxSpots
	if #boxSpots > 0 then buildBox(m, boxSpots[1], true) end
	for i, s in ipairs(machines) do
		if i == 1 then buildPap(m, s)
		elseif Z.PERK_ORDER[i - 1] then buildPerk(m, s, Z.PERK_ORDER[i - 1]) end
	end
end

function M.teamFor(_m: any, _c: any): string? return HUMANS end
function M.botsWanted(m: any, team: string?, want: number): number?
	if m.state == "live" then return nil end     -- ensuite les bots morts reviennent seulement au début de chaque manche
	return if team == HUMANS then want else 0
end
function M.botRespawn(_m: any, _s: any): boolean return false end
function M.spawnPoint(m: any, c: any): Vector3?
	local k = MS().keyOf(c)
	if m.data.waveRespawn and m.data.waveRespawn[k] and m.data.respawnAt then
		return m.data.respawnAt + Vector3.new((math.random() - 0.5) * 2, 3, (math.random() - 0.5) * 2)
	end
	local list = m.map.spawns.CT
	return if #list > 0 then list[math.random(#list)] else nil
end
function M.loadout(_m: any, c: any): { string }?
	return if isPlayer(c) then { "p250", "knife" } else { "glock", "knife" }
end
function M.onSpawn(m: any, c: any, char: Model)
	local p = person(m, c)
	p.perks = {}; p.pap = {}; p.p = nil; p.s = if isPlayer(c) then "p250" else "glock"; p.downed = false; p.prompt = nil
	local k = MS().keyOf(c)
	local again = m.data.waveRespawn[k]
	m.data.waveRespawn[k] = nil
	task.defer(function()
		if not char.Parent then return end
		WeaponService.setAmmo(c, p.s :: string, nil, Z.START_RES)
		WeaponService.giveGrenades(c, 0, 0, 2)
		char:SetAttribute("RateMult", nil); char:SetAttribute("Downed", nil)
		if again then
			local h = char:FindFirstChildOfClass("Humanoid"); if h then h.Health = 60 end
			char:SetAttribute("ProtectedUntil", workspace:GetServerTimeNow() + 1.5)
		end
		applyPerks(m, c)
		local s = MS().statOf(m, c); if s then s.pts = p.pts end
	end)
end
function M.onKill(m: any, _killer: any, victim: any, _key: string, _hs: boolean, _ks: any, vs: any): boolean
	if vs.team == HUMANS then
		local p = person(m, victim)
		if p.prompt then p.prompt:Destroy(); p.prompt = nil end
		p.downed = false; p.perks = {}; p.pap = {}
		syncAttrs(m, victim)
		vs.streak = 0
	end
	return true
end

function M.tick(m: any, dt: number)
	local zs = m.data.zs
	if zs.result then return end
	-- les zombies n'apparaissent pas au tableau (ils n'ont pas d'équipe ; on nettoie au cas où)
	local hs = humans(m)
	local standing = aliveHumans(m, true)
	local alive = aliveHumans(m)
	if #alive == 0 and #hs > 0 then zs.result = "lose"; return end
	local zAlive = #ZombieService.ofMatch(m.id)
	if zs.state == "wait" or zs.state == "break" then
		zs.breakT -= dt
		if zs.breakT <= 0 then zStartWave(m) end
	elseif zs.state == "spawn" then
		zs.spawnT -= dt
		if zs.spawnT <= 0 and zs.queue > 0 and zAlive < math.min(24, 6 + zs.wave * 2) then
			zSpawn(m); zs.queue -= 1
			zs.spawnT = math.max(0.35, 1.1 - zs.wave * 0.06)
		end
		if zs.queue <= 0 and zAlive == 0 then
			if zs.wave >= m.data.limit then zs.result = "win"; return end
			zs.state = "break"; zs.breakT = 9
			MS().announce(m, "MANCHE " .. zs.wave .. " TERMINÉE", "La suivante arrive…", RED)
			for p in pairs(m.players) do popEvent:FireClient(p, "", nil, "win") end
		end
	end
	-- boîte mystère (zBoxUpdate)
	local b = zs.box
	if b and b.state ~= "idle" then
		b.t += dt
		if b.state == "roll" and b.t >= 4.2 then
			if b.teddy then
				b.state = "teddy"; b.t = 0
				b.model:SetAttribute("BoxState", "teddy")
				if b.owner then
					local op = person(m, b.owner); op.pts += Z.BOX_PRICE; syncAttrs(m, b.owner)
					tell(b.owner, "Le nounours ! Points remboursés", Z.rgb(0x7fe0ff), "deny")
				end
			else
				b.state = "ready"; b.t = 0
				b.model:SetAttribute("BoxState", "ready"); b.model:SetAttribute("BoxWeapon", b.key)
				if b.key and Z.isWonder(b.key) and b.owner then MS().announce(m, string.upper(Config.WEAPONS[b.key].name), "Arme prodige !", Z.rgb(0x7dff6a), b.owner) end
			end
		elseif b.state == "ready" and b.t > 9 then
			b.state = "idle"; b.model:SetAttribute("BoxState", "idle"); b.model:SetAttribute("BoxWeapon", nil)
		elseif b.state == "teddy" and b.t > 3 then
			local n = #zs.boxSpots
			local idx = ((zs.boxIdx - 1 + 1 + math.random(0, math.max(0, n - 2))) % n) + 1
			zs.boxIdx = idx; zs.boxUses = 0
			buildBox(m, zs.boxSpots[idx], false)
		end
	end
	-- bonus au sol (26 s, clignotent les 6 dernières)
	for i = #m.data.drops, 1, -1 do
		local d = m.data.drops[i]
		d.t -= dt
		if d.part.Parent then
			d.part.CFrame = CFrame.new(d.pos + Vector3.new(0, (1 + math.sin(os.clock() * 3) * 0.15) * U, 0))
			d.part.Transparency = if d.t > 6 or math.floor(os.clock() * 6) % 2 == 0 then 0.35 else 1
		end
		if d.t <= 0 then d.part:Destroy(); table.remove(m.data.drops, i)
		else
			for _, h in ipairs(alive) do
				local r = rootOf(h)
				if r and flatDist(r.Position, d.pos) < 1.3 * U and math.abs(r.Position.Y - d.pos.Y) < 3 * U then
					d.part:Destroy(); table.remove(m.data.drops, i)
					applyDrop(m, d.key, h)
					break
				end
			end
		end
	end
	-- fragments de l'Orbe (joueurs seulement)
	for i = #m.data.frags, 1, -1 do
		local f = m.data.frags[i]
		f.part.CFrame = CFrame.new(f.pos + Vector3.new(0, math.sin(os.clock() * 2 + i) * 0.08 * U, 0)) * CFrame.Angles(math.rad(45), os.clock() * 2, math.rad(35))
		for p in pairs(m.players) do
			local r = rootOf(p)
			if r and MS().aliveChar(p) and not person(m, p).downed and flatDist(r.Position, f.pos) < 1.2 * U and math.abs(r.Position.Y - f.pos.Y) < 3 * U then
				f.part:Destroy(); table.remove(m.data.frags, i)
				m.data.fragGot += 1
				if m.data.fragGot < 3 then tell(p, "Fragment de l'Orbe " .. m.data.fragGot .. " / 3", Z.rgb(0xc77dff), "pickup")
				else
					MS().announce(m, "EASTER EGG RÉUSSI !", "L'Orbe est reconstituée — arme prodige améliorée + 5000 pts", Z.rgb(0xc77dff))
					zGive(m, p, "raygun")
					person(m, p).pap.raygun = true
					WeaponService.setAmmo(p, "raygun", WeaponService.magOf(p, "raygun"), Z.WONDERS.raygun.reserve * 2)
					zPts(m, p, 5000)
				end
				break
			end
		end
	end
	-- à terre : saignement, réanimation par les bots (zDownUpdate)
	for _, v in ipairs(alive) do
		local p = person(m, v)
		if p.downed then
			p.downT -= dt
			local ch = WeaponService.charOf(v)
			if ch then ch:SetAttribute("DownT", math.ceil(p.downT)) end
			local vr = rootOf(v)
			local best, bd = nil, math.huge
			for _, b2 in ipairs(standing) do
				if b2 ~= v and not isPlayer(b2) then
					local r = rootOf(b2)
					if r and vr and flatDist(r.Position, vr.Position) < bd then best, bd = b2, flatDist(r.Position, vr.Position) end
				end
			end
			if best and vr then
				local br = rootOf(best) :: BasePart
				local danger = false
				for _, z in ipairs(ZombieService.ofMatch(m.id)) do
					if flatDist(z:GetPivot().Position, br.Position) < 3.5 * U then danger = true; break end
				end
				m.data.reviveGoal = m.data.reviveGoal or {}
				if bd < 1.6 * U and not danger then
					p.revP += dt
					m.data.reviveGoal[best] = vr.Position
				elseif not danger or bd < 12 * U then
					m.data.reviveGoal[best] = vr.Position
				end
			end
			if p.revP >= 3 then zRevive(m, v, best)
			elseif p.downT <= 0 then bleedOut(m, v) end
		end
	end
	if #standing == 0 then
		for _, v in ipairs(alive) do if person(m, v).downed then bleedOut(m, v) end end
	end
	if m.data.reviveGoal then
		for b2, _ in pairs(m.data.reviveGoal) do
			local still = false
			for _, v in ipairs(alive) do if person(m, v).downed then still = true end end
			if not still or not MS().aliveChar(b2) then m.data.reviveGoal[b2] = nil end
		end
	end
	-- score affiché en haut : manche (survivants) et zombies restants
	local left = zAlive + zs.queue
	m.score[HUMANS] = zs.wave
	m.score["Défenseurs"] = left
	for k, s in pairs(m.stats) do if s.team ~= HUMANS then m.stats[k] = nil end end
end

function M.checkEnd(m: any): (boolean, any)
	local zs = m.data.zs
	if not zs or not zs.result then return false, nil end
	for _, z in ipairs(ZombieService.ofMatch(m.id)) do z:SetAttribute("Frozen", true); local h = z:FindFirstChildOfClass("Humanoid"); if h then h:Move(Vector3.zero) end end
	return true, if zs.result == "win" then HUMANS else "Zombies"
end

function M.botGoal(m: any, bot: Model): Vector3?
	local g = m.data.reviveGoal
	return g and g[bot] or nil
end

local function fmt(t: number): string return string.format("%d:%02d", math.floor(t / 60), math.floor(t) % 60) end
function M.info(m: any): any
	local zs = m.data.zs
	if not zs then return nil end
	local left = #ZombieService.ofMatch(m.id) + zs.queue
	local surv = #aliveHumans(m, true)
	local t = os.clock()
	local pause = zs.state == "wait" or zs.state == "break"
	local lim = if m.data.limit >= 99 then "∞" else tostring(m.data.limit)
	local fx = {}
	if zs.insta > t then table.insert(fx, "☠ MORT INSTANTANÉE " .. math.ceil(zs.insta - t)) end
	if zs.dbl > t then table.insert(fx, "×2 POINTS " .. math.ceil(zs.dbl - t)) end
	if zs.fire > t then table.insert(fx, "$ VENTE DE FEU " .. math.ceil(zs.fire - t)) end
	m.data.public = { z = {
		wave = zs.wave, limit = m.data.limit, state = zs.state, breakT = math.max(0, math.ceil(zs.breakT)), left = left, survivors = surv,
		insta = math.max(0, math.ceil(zs.insta - t)), dbl = math.max(0, math.ceil(zs.dbl - t)), fire = math.max(0, math.ceil(zs.fire - t)),
		boxPrice = if zs.fire > t then 10 else Z.BOX_PRICE, elapsed = math.floor(t - m.startedAt), frags = m.data.fragGot or 0,
	} }
	return {
		line = if pause then "PROCHAINE VAGUE  " .. math.max(0, math.ceil(zs.breakT)) .. " s" else "MANCHE " .. zs.wave .. " / " .. lim .. "   ·   " .. left .. " ZOMBIES RESTANTS",
		sub = surv .. " survivant" .. (if surv > 1 then "s" else "") .. "   ·   survie " .. fmt(t - m.startedAt) .. (if #fx > 0 then "   ·   " .. table.concat(fx, "  ") else ""),
		subWarn = zs.insta > t,
		color = RED, kind = "zombies",
	}
end

local function clearAttrs(p: Player)
	for _, a in ipairs({ "ZPts", "ZPerks", "ZPap", "ZOwn" }) do p:SetAttribute(a, nil) end
	local ch = p.Character
	if ch then for _, a in ipairs({ "RateMult", "SpeedMult", "Downed", "DownT" }) do ch:SetAttribute(a, nil) end end
end
function M.onLeave(_m: any, p: Player) clearAttrs(p) end
function M.cleanup(m: any)
	ZombieService.removeMatch(m.id)
	for p in pairs(m.players) do clearAttrs(p) end
	if m.data.folder then m.data.folder:Destroy() end
	if m.data.zfolder then m.data.zfolder:Destroy() end
	m.data.zs = nil
end

-- pour l'aperçu dans d'autres scripts
M.HUMANS = HUMANS
local _ = Players
return M
