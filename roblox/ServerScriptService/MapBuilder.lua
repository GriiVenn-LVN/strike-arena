--!strict
-- ServerScriptService/MapBuilder (ModuleScript)
-- Construit une carte du web dans Workspace, à l'identique :
--   • Collision : blocs invisibles tirés de la grille de jeu du web (cases, hauteurs, rampes, plafonds), comme la
--     collision et les lignes de vue du web (groundH / ceilAt / rayWall). Ce sont les seules pièces touchées par
--     les balles, les bots et les déplacements.
--   • Décor : tous les blocs, boules et cylindres du décor 3D du web (MapScenes, tools/export_scene.js), en Parts
--     non collisionnables et ignorées des rayons (CanQuery = false), avec le matériau PBR haute définition de Roblox
--     qui remplace les textures floues du web (MapScene.hdMaterial). Le client (MapDetailController) ajoute les
--     maillages détaillés, les textures du web, les halos et l'ambiance (ciel, brouillard, lumière) de la carte.
-- Plusieurs cartes peuvent coexister (une par match) : build(id, origine, nom) décale tout de l'origine.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local MapData = require(ReplicatedStorage.Shared.MapData)
local MapScene = require(ReplicatedStorage.Shared.MapScene)

local MapBuilder = {}

local U = Config.STUDS_PER_METER           -- studs par mètre
local S = Config.CELL                      -- taille d'une case en mètres (2)
local CELL = S * U                         -- taille d'une case en studs
local MAXP = 2048                          -- taille maximale d'une Part

export type MapObj = {
	id: string, folder: Folder, origin: Vector3, data: any, grid: any,
	spawns: { T: { Vector3 }, CT: { Vector3 }, DM: { Vector3 } }, sites: { { name: string, pos: Vector3, radius: number } },
	cellToWorld: (cx: number, cz: number) -> Vector3, groundAt: (pos: Vector3) -> number, toCell: (pos: Vector3) -> (number, number),
}

-- couleurs de repli de l'ancien constructeur (carte sans décor exporté)
local FALLBACK = { [1] = Color3.fromRGB(226, 208, 168), [2] = Color3.fromRGB(165, 118, 64), [3] = Color3.fromRGB(235, 225, 203), [4] = Color3.fromRGB(190, 175, 140),
	[5] = Color3.fromRGB(190, 175, 140), [6] = Color3.fromRGB(205, 180, 140), [7] = Color3.fromRGB(125, 138, 106), [8] = Color3.fromRGB(150, 156, 163), [9] = Color3.fromRGB(205, 190, 160) }

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name; p.Anchored = true; p.Size = size; p.CFrame = cf
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function solid(parent: Instance, name: string, size: Vector3, cf: CFrame): Part
	local p = part(parent, name, size, cf)
	p.Transparency = 1; p.CastShadow = false; p.Material = Enum.Material.SmoothPlastic
	return p
end

-- ---------- grille : hauteur du sol (rampes comprises) en mètres, comme groundH() du web ----------
local function groundH(g: any, x: number, z: number): number
	local N = MapData.N
	local cx, cz = math.floor(x / S), math.floor(z / S)
	if cx < 0 or cz < 0 or cx >= N or cz >= N then return 99 end
	local i = cz * N + cx
	local r = g.ramp[i]
	if r and r ~= 0 then
		local R = g.ramps[r]
		local t = if R.axis == "x" then (x - R.x1 * S) / ((R.x2 - R.x1 + 1) * S) else (z - R.z1 * S) / ((R.z2 - R.z1 + 1) * S)
		return R.hA + (R.hB - R.hA) * math.clamp(t, 0, 1)
	end
	return g.h[i]
end
MapBuilder.groundH = groundH

-- rectangles maximaux de cases de même valeur (moins de Parts) ; key(i) renvoie nil pour « rien »
local function rects(key: (number) -> number?, fn: (x1: number, z1: number, x2: number, z2: number, v: number) -> ())
	local N = MapData.N
	local used = table.create(N * N, false)
	for z = 0, N - 1 do
		for x = 0, N - 1 do
			local i = z * N + x
			local v = key(i)
			if v and not used[i + 1] then
				local x2 = x
				while x2 + 1 < N and not used[z * N + x2 + 2] and key(z * N + x2 + 1) == v do x2 += 1 end
				local z2 = z
				while z2 + 1 < N do
					local ok = true
					for xx = x, x2 do local j = (z2 + 1) * N + xx; if used[j + 1] or key(j) ~= v then ok = false; break end end
					if not ok then break end
					z2 += 1
				end
				for zz = z, z2 do for xx = x, x2 do used[zz * N + xx + 1] = true end end
				fn(x, z, x2, z2, v)
			end
		end
	end
end

-- ---------- collision exacte du web ----------
local function buildCollision(folder: Folder, g: any, origin: Vector3)
	local N = MapData.N
	local col = Instance.new("Folder"); col.Name = "Collision"; col.Parent = folder
	local W = N * CELL
	-- sol (la grille) et murs invisibles tout autour : hors de la grille, le web bloque (groundH = 99)
	solid(col, "Floor", Vector3.new(W, 4, W), CFrame.new(origin + Vector3.new(W / 2, -2, W / 2)))
	local wallH = 40 * U
	for _, e in ipairs({ { W / 2, -1, W + 4, 2 }, { W / 2, W + 1, W + 4, 2 }, { -1, W / 2, 2, W + 4 }, { W + 1, W / 2, 2, W + 4 } }) do
		solid(col, "Border", Vector3.new(e[3], wallH, e[4]), CFrame.new(origin + Vector3.new(e[1], wallH / 2, e[2])))
	end
	-- colonnes pleines (murs, caisses, maisons, plateformes, fûts, piliers, blocs invisibles sous les décors)
	rects(function(i)
		if g.type[i] ~= 0 and g.ramp[i] == 0 and g.h[i] > 0 then return g.h[i] end
		return nil
	end, function(x1, z1, x2, z2, h)
		local sx, sz, hs = (x2 - x1 + 1) * CELL, (z2 - z1 + 1) * CELL, h * U
		local p = solid(col, "Block", Vector3.new(sx, hs, sz), CFrame.new(origin + Vector3.new(x1 * CELL + sx / 2, hs / 2, z1 * CELL + sz / 2)))
		p:SetAttribute("CellType", g.type[z1 * N + x1])
	end)
	-- plafonds : au-dessus de G_CEIL tout est plein sur le web (tunnels, souk, hangars, salles)
	local CEILH = 14 * U
	rects(function(i) local c = g.ceil[i]; return if c < 90 then c else nil end, function(x1, z1, x2, z2, h)
		local sx, sz = (x2 - x1 + 1) * CELL, (z2 - z1 + 1) * CELL
		solid(col, "Ceiling", Vector3.new(sx, CEILH, sz), CFrame.new(origin + Vector3.new(x1 * CELL + sx / 2, h * U + CEILH / 2, z1 * CELL + sz / 2)))
	end)
	-- rampes : pente continue (WedgePart) comme groundH() du web, plus un socle sous la partie basse
	for _, R in ipairs(g.ramps) do
		local lenC = if R.axis == "x" then R.x2 - R.x1 + 1 else R.z2 - R.z1 + 1
		local widC = if R.axis == "x" then R.z2 - R.z1 + 1 else R.x2 - R.x1 + 1
		local lo, hi = math.min(R.hA, R.hB), math.max(R.hA, R.hB)
		local cx = (R.x1 + (R.x2 - R.x1 + 1) / 2) * CELL
		local cz = (R.z1 + (R.z2 - R.z1 + 1) / 2) * CELL
		-- la face haute d'une WedgePart est du côté +Z local : on la tourne vers le côté haut de la rampe
		local up = R.hB > R.hA
		local yaw = if R.axis == "x" then (if up then math.pi / 2 else -math.pi / 2) else (if up then 0 else math.pi)
		local L, Wd = lenC * CELL, widC * CELL
		if hi - lo > 0.01 then
			local w = Instance.new("WedgePart")
			w.Name = "Ramp"; w.Anchored = true; w.Transparency = 1; w.CastShadow = false
			w.Size = Vector3.new(Wd, (hi - lo) * U, L)
			w.CFrame = CFrame.new(origin + Vector3.new(cx, lo * U + (hi - lo) * U / 2, cz)) * CFrame.Angles(0, yaw, 0)
			w.Parent = col
		end
		if lo > 0.01 then
			local sx = if R.axis == "x" then L else Wd
			local sz = if R.axis == "x" then Wd else L
			solid(col, "RampBase", Vector3.new(sx, lo * U, sz), CFrame.new(origin + Vector3.new(cx, lo * U / 2, cz)))
		end
	end
end

-- ---------- décor : primitives du web ----------
local faceMain = MapScene.faceMain

local function mulC(a: Color3, b: Color3): Color3 return Color3.new(a.R * b.R, a.G * b.G, a.B * b.B) end

local function buildVisuals(folder: Folder, id: string, origin: Vector3): number
	local info = MapScene.info(id)
	if not info then return 0 end
	local vis = Instance.new("Folder"); vis.Name = "Visuals"
	local mats = info.mats
	local count = 0
	local md = MapData[id]
	local theme, base = md and md.theme, md and md.base
	for i, p in ipairs(MapScene.prims(id)) do
		local mi = if p.kind == 0 then faceMain(p) else p.mats[1]
		local m: MapScene.Mat? = if mi > 0 then mats[mi] else nil
		if m then
			local size = p.size * U
			local q = Instance.new("Part")
			q.Name = if p.kind == 0 then "Box" elseif p.kind == 1 then "Ball" else "Cyl"
			q.Anchored = true; q.CanCollide = false; q.CanQuery = false; q.CanTouch = false
			q.TopSurface = Enum.SurfaceType.Smooth; q.BottomSurface = Enum.SurfaceType.Smooth
			local col = MapScene.color(m.avg)
			if p.color then col = mulC(col, p.color) end
			-- matériau PBR haute définition à la place d'une texture floue du web (MapScene.hdMaterial) : le client ne pose
			-- alors pas la texture ; teinte légèrement variée d'un bloc à l'autre
			local hd = MapScene.hdMaterial(m)
			q.Material = hd or MapScene.material(m.rm)
			-- sol de jeu (texture de détail du web) et grand sol extérieur : matériau du sol de la carte (grain, relief)
			local big = (if p.size.X > 300 then 1 else 0) + (if p.size.Y > 300 then 1 else 0) + (if p.size.Z > 300 then 1 else 0) >= 2
			local ground = m.rm == "SmoothPlastic" and p.kind == 0 and (m.det ~= nil or (big and not m.tex))
			if ground then
				q.Material = MapScene.groundMaterial(theme, base, m.det == nil)
			elseif not hd and not m.tex and not m.a and m.rm == "SmoothPlastic" then
				-- bloc uni : béton ou bois d'après sa couleur, si assez grand pour que le grain se voie
				local s2 = math.max(size.X, size.Y, size.Z) + math.min(size.X, size.Y, size.Z)
				local g = if s2 > 2.5 * U then MapScene.guessMaterial(col) else nil
				if g then q.Material = g; hd = g end
			end
			if hd and not ground then col = MapScene.vary(col, i) end
			q.Color = col
			if m.refl then q.Reflectance = m.refl end
			local tr = m.a or 0
			if m.cut and p.kind == 0 and not hd then tr = 1 end   -- texture découpée : seule la texture (client) se voit
			q.Transparency = tr
			q.CastShadow = bit32.band(p.flags, 2) ~= 0 and tr < 0.5
			local cf = CFrame.new(origin + p.pos * U) * p.rot
			if p.kind == 2 then                                -- cylindre : axe Y du web -> axe X de Roblox
				q.Shape = Enum.PartType.Cylinder
				q.Size = Vector3.new(math.min(size.X, MAXP), math.min(size.Y, MAXP), math.min(size.Z, MAXP))
				q.CFrame = cf * CFrame.Angles(0, 0, math.pi / 2)
				local cap = p.mats[2]
				if cap > 0 and cap ~= mi then q:SetAttribute("Cap", cap) end
			elseif p.kind == 1 then
				local d = size
				if math.abs(d.X - d.Y) < 0.02 * d.X and math.abs(d.X - d.Z) < 0.02 * d.X then
					q.Shape = Enum.PartType.Ball
					q.Size = Vector3.new(d.X, d.X, d.X)
				else
					q.Size = d
					local sm = Instance.new("SpecialMesh"); sm.MeshType = Enum.MeshType.Sphere; sm.Parent = q
				end
				q.CFrame = cf
			else
				q.Size = Vector3.new(math.clamp(size.X, 0.02, MAXP), math.clamp(size.Y, 0.02, MAXP), math.clamp(size.Z, 0.02, MAXP))
				q.CFrame = cf
			end
			q:SetAttribute("P", i)                             -- numéro de la primitive : le client y pose les textures du web
			q.Parent = vis
			count += 1
		end
	end
	vis.Parent = folder
	-- vraies lampes du web
	if #info.lights > 0 then
		local lf = Instance.new("Folder"); lf.Name = "Lights"
		for _, L in ipairs(info.lights) do
			local a = Instance.new("Part"); a.Name = "Lamp"; a.Anchored = true; a.CanCollide = false; a.CanQuery = false; a.CanTouch = false
			a.Transparency = 1; a.Size = Vector3.new(0.2, 0.2, 0.2); a.CastShadow = false
			a.Position = origin + Vector3.new(L.p[1], L.p[2], L.p[3]) * U
			local pl = Instance.new("PointLight")
			pl.Color = MapScene.color(L.c); pl.Range = math.clamp((if L.d > 0 then L.d else 20) * U * 0.6, 8, 60)
			pl.Brightness = math.clamp(L.i / 9, 0.4, 3); pl.Shadows = true    -- ombres des lampes (éclairage Future)
			pl.Parent = a; a.Parent = lf
		end
		lf.Parent = folder
	end
	return count
end

-- ancien rendu en blocs colorés (carte sans décor exporté) : visible directement sur la collision
local function fallbackVisuals(folder: Folder, g: any)
	local col = folder:FindFirstChild("Collision")
	if not col then return end
	for _, p in ipairs(col:GetChildren()) do
		if p:IsA("BasePart") and p.Name ~= "Border" and p.Name ~= "Ceiling" then
			p.Transparency = 0
			p.Color = if p.Name == "Floor" then Color3.fromRGB(201, 177, 138) else (FALLBACK[p:GetAttribute("CellType") :: number] or Color3.fromRGB(200, 200, 200))
			p.Material = Enum.Material.Sandstone
		end
	end
end

-- ---------- API ----------
function MapBuilder.list(): { { id: string, name: string, desc: string, theme: string } }
	local out = {}
	for _, id in ipairs(MapData.ORDER) do
		local m = MapData[id]
		table.insert(out, { id = id, name = m.name, desc = m.desc or "", theme = m.theme })
	end
	return out
end

function MapBuilder.destroy(map: MapObj?)
	if map and map.folder then map.folder:Destroy() end
end

function MapBuilder.build(mapId: string, origin: Vector3?, name: string?): MapObj
	if not MapData[mapId] then mapId = MapData.ORDER[1] end
	local o = origin or Vector3.zero
	local fname = name or "Map"
	local g = MapData.buildGrid(mapId)
	local m = g.map

	local old = workspace:FindFirstChild(fname); if old then old:Destroy() end
	local folder = Instance.new("Folder"); folder.Name = fname
	folder:SetAttribute("MapId", mapId)
	folder:SetAttribute("Origin", o)
	folder:SetAttribute("Theme", m.theme)
	folder:SetAttribute("MapSize", MapData.N * CELL)

	buildCollision(folder, g, o)
	local n = buildVisuals(folder, mapId, o)
	if n == 0 then fallbackVisuals(folder, g) end
	folder:SetAttribute("NVis", n)                      -- le client attend d'avoir reçu tout le décor avant d'y poser les textures
	folder.Parent = workspace                          -- un seul envoi aux clients, carte complète

	local function toCell(pos: Vector3): (number, number)
		local l = pos - o
		return math.floor(l.X / CELL), math.floor(l.Z / CELL)
	end
	local function groundAt(pos: Vector3): number     -- hauteur du sol (studs, monde) sous une position
		local l = pos - o
		return o.Y + groundH(g, l.X / U, l.Z / U) * U
	end
	local function cellToWorld(cx: number, cz: number): Vector3   -- centre d'une case, au niveau du sol
		local x, z = (cx + 0.5) * S, (cz + 0.5) * S
		return o + Vector3.new(x * U, math.min(groundH(g, x, z), 20) * U, z * U)
	end
	local function spawnAt(c: { number }): Vector3 return cellToWorld(c[1], c[2]) + Vector3.new(0, 3, 0) end
	local spawns = { T = {}, CT = {}, DM = {} }
	for _, c in ipairs(m.spawnT or {}) do table.insert(spawns.T, spawnAt(c)) end
	for _, c in ipairs(m.spawnCT or {}) do table.insert(spawns.CT, spawnAt(c)) end
	for _, c in ipairs(m.spawnDM or {}) do table.insert(spawns.DM, spawnAt(c)) end
	if #spawns.DM == 0 then spawns.DM = table.clone(spawns.T) end
	local sites = {}
	for _, s in ipairs(m.sites or {}) do table.insert(sites, { name = s.n, pos = spawnAt({ s.cx, s.cz }), radius = s.r * U }) end
	return { id = mapId, folder = folder, origin = o, data = m, grid = g, spawns = spawns, sites = sites,
		cellToWorld = cellToWorld, groundAt = groundAt, toCell = toCell }
end

return MapBuilder
