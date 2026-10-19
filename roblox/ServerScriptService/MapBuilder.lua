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

-- graine de la petite variation de teinte (MapScene.vary) de chaque bloc. Les blocs alignés dont une face est dans le
-- même plan qu'une face d'un autre bloc et la recouvre en partie (dalles de 2,12 m posées tous les 2 m, murs du web qui
-- se chevauchent), du même matériau et de la même couleur, prennent la même graine : sinon la bande commune clignote
-- entre les deux teintes (z-fighting), en quadrillage sur les sols des 10 cartes (environ 2 000 recouvrements par carte,
-- mesurés sur MapScenes).
local function shadeSeeds(list: { MapScene.Prim }): { number }
	local parent = table.create(#list, 0)
	for i = 1, #list do parent[i] = i end
	local function find(i: number): number
		while parent[i] ~= i do parent[i] = parent[parent[i]]; i = parent[i] end
		return i
	end
	-- faces de chaque bloc aligné : plan (axe, sens, position au millimètre) -> { bloc, rectangle sur les deux autres axes }
	local planes: { [string]: { { any } } } = {}
	for i, p in ipairs(list) do
		if p.kind == 0 then
			local half = { 0, 0, 0 }
			local aligned = true
			local look = faceMain(p) .. "|" .. (if p.color then p.color:ToHex() else "")
			for j, v in ipairs({ p.rot.XVector, p.rot.YVector, p.rot.ZVector }) do
				local c = { math.abs(v.X), math.abs(v.Y), math.abs(v.Z) }
				local ax = if c[1] > 0.999 then 1 elseif c[2] > 0.999 then 2 elseif c[3] > 0.999 then 3 else 0
				if ax == 0 then aligned = false; break end
				half[ax] = (if j == 1 then p.size.X elseif j == 2 then p.size.Y else p.size.Z) / 2
			end
			if aligned then
				local c = { p.pos.X, p.pos.Y, p.pos.Z }
				for ax = 1, 3 do
					local o1, o2 = if ax == 1 then 2 else 1, if ax == 3 then 2 else 3
					local rect = { i, c[o1] - half[o1], c[o1] + half[o1], c[o2] - half[o2], c[o2] + half[o2] }
					for _, sg in ipairs({ -1, 1 }) do
						local key = ax .. (if sg > 0 then "+" else "-") .. math.floor((c[ax] + sg * half[ax]) * 1000 + 0.5) .. "|" .. look
						local l = planes[key]
						if not l then l = {}; planes[key] = l end
						table.insert(l, rect)
					end
				end
			end
		end
	end
	for _, l in pairs(planes) do
		for a = 1, #l - 1 do
			local ra = l[a]
			for b = a + 1, #l do
				local rb = l[b]
				if math.min(ra[3], rb[3]) - math.max(ra[2], rb[2]) > 0.01 and math.min(ra[5], rb[5]) - math.max(ra[4], rb[4]) > 0.01 then
					local x, y = find(ra[1]), find(rb[1])
					if x ~= y then parent[math.max(x, y)] = math.min(x, y) end
				end
			end
		end
	end
	local seeds = table.create(#list, 0)
	for i = 1, #list do seeds[i] = find(i) end
	return seeds
end

-- ---------- faces presque confondues (z-fighting) ----------
-- Le web empile des surfaces à quelques millimètres les unes des autres (calque d'ombres 1,2 cm au-dessus du sol dessiné,
-- nez de marche 5 mm au-dessus de la marche, affiches et vitraux contre les murs) : sous Roblox elles scintillent l'une
-- dans l'autre dès qu'on s'éloigne. Quand deux faces alignées de même sens se recouvrent à moins de GAP studs (GAP_BIG
-- pour deux grandes surfaces vues de loin), la face extérieure (celle du plus petit bloc si elles sont confondues) est
-- avancée jusqu'à cet écart en allongeant son bloc : 5 cm au plus (mesuré sur les 10 cartes : 60 à 170 faces par carte),
-- invisible. Deux faces confondues de même matériau, même couleur et même transparence (dalles qui se chevauchent) ne
-- bougent pas : elles ne peuvent pas scintiller.
local GAP, GAP_BIG = 0.05, 0.08
type Face = { part: BasePart, look: string, j: number, axv: Vector3, sg: number, off: number, qoff: number, adj: number, r: { number }, area: number }
local function separateFaces(items: { { part: BasePart, prim: MapScene.Prim } })
	local buckets: { [number]: { Face } } = {}
	for _, it in ipairs(items) do
		local p, q = it.prim, it.part
		if p.kind == 0 then
			local half, jOf, sOf = { 0, 0, 0 }, { 0, 0, 0 }, { 1, 1, 1 }
			local ok = true
			local sz = q.Size
			for j, v in ipairs({ q.CFrame.XVector, q.CFrame.YVector, q.CFrame.ZVector }) do
				local ax = if math.abs(v.X) > 0.999 then 1 elseif math.abs(v.Y) > 0.999 then 2 elseif math.abs(v.Z) > 0.999 then 3 else 0
				if ax == 0 then ok = false; break end
				half[ax] = (if j == 1 then sz.X elseif j == 2 then sz.Y else sz.Z) / 2
				jOf[ax] = j
				sOf[ax] = if (if ax == 1 then v.X elseif ax == 2 then v.Y else v.Z) > 0 then 1 else -1
			end
			if ok then
				local pos = q.Position
				local c = { pos.X, pos.Y, pos.Z }
				local hidden = q.Transparency >= 0.999
				local look = q.Material.Name .. q.Color:ToHex() .. q.Transparency
				for ax = 1, 3 do
					local o1, o2 = if ax == 1 then 2 else 1, if ax == 3 then 2 else 3
					local r = { c[o1] - half[o1], c[o1] + half[o1], c[o2] - half[o2], c[o2] + half[o2] }
					for _, sg in ipairs({ -1, 1 }) do
						-- bloc invisible (texture découpée posée par le client) : seules ses faces texturées comptent
						local k = (jOf[ax] - 1) * 2 + (if sg * sOf[ax] > 0 then 1 else 2)
						if not hidden or p.mats[k] > 0 then
							local key = ax * 2 + (if sg > 0 then 1 else 0)
							local l = buckets[key]
							if not l then l = {}; buckets[key] = l end
							local off = c[ax] + sg * half[ax]
							table.insert(l, { part = q, look = look, j = jOf[ax], axv = if ax == 1 then Vector3.xAxis elseif ax == 2 then Vector3.yAxis else Vector3.zAxis,
								sg = sg, off = off * sg, qoff = math.floor(off * sg * 10000 + 0.5), adj = off * sg, r = r, area = (r[2] - r[1]) * (r[4] - r[3]) })
						end
					end
				end
			end
		end
	end
	local grow: { [BasePart]: { size: Vector3, shift: Vector3 } } = {}
	for _, l in pairs(buckets) do
		-- tri par plan (au 1/10 000 de stud, ordre strict) puis du plus grand au plus petit bloc
		table.sort(l, function(a, b)
			if a.qoff ~= b.qoff then return a.qoff < b.qoff end
			return a.area > b.area
		end)
		for i = 2, #l do
			local f = l[i]
			local fp = f.part
			for gi = i - 1, 1, -1 do
				local g = l[gi]
				if f.off - g.off > GAP_BIG then break end
				if g.part ~= fp and not (f.qoff == g.qoff and f.look == g.look) then
					local ox = math.min(f.r[2], g.r[2]) - math.max(f.r[1], g.r[1])
					local oy = math.min(f.r[4], g.r[4]) - math.max(f.r[3], g.r[3])
					if ox > 0.05 and oy > 0.05 then
						local need = if math.min(ox, oy) > 100 then GAP_BIG else GAP
						if f.adj < g.adj + need then f.adj = g.adj + need end
					end
				end
			end
			local d = f.adj - f.off
			if d > 1e-5 then
				local gr = grow[fp]
				if not gr then gr = { size = Vector3.zero, shift = Vector3.zero }; grow[fp] = gr end
				gr.size += if f.j == 1 then Vector3.new(d, 0, 0) elseif f.j == 2 then Vector3.new(0, d, 0) else Vector3.new(0, 0, d)
				gr.shift += f.axv * (f.sg * d / 2)
			end
		end
	end
	for q, gr in pairs(grow) do
		q.Size += gr.size
		q.CFrame = q.CFrame + gr.shift
	end
end

local function buildVisuals(folder: Folder, id: string, origin: Vector3): number
	local info = MapScene.info(id)
	if not info then return 0 end
	local vis = Instance.new("Folder"); vis.Name = "Visuals"
	local mats = info.mats
	local count = 0
	local items: { { part: BasePart, prim: MapScene.Prim } } = {}
	local md = MapData[id]
	local theme, base = md and md.theme, md and md.base
	local list = MapScene.prims(id)
	local seeds = shadeSeeds(list)
	for i, p in ipairs(list) do
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
			if hd and not ground then col = MapScene.vary(col, seeds[i]) end
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
				-- grand sol extérieur (plan de 600 m, 2 cm sous le sol de jeu sur le web ; mer en métal du port et du labo) :
				-- descendu de 8 cm, sinon il perce le sol de jeu au loin
				if big and not m.tex and m.det == nil then cf = cf - Vector3.new(0, 0.3, 0) end
				q.CFrame = cf
				table.insert(items, { part = q :: BasePart, prim = p })
			end
			q:SetAttribute("P", i)                             -- numéro de la primitive : le client y pose les textures du web
			q.Parent = vis
			count += 1
		end
	end
	separateFaces(items)
	vis.Parent = folder
	-- vraies lampes du web
	if #info.lights > 0 then
		local lf = Instance.new("Folder"); lf.Name = "Lights"
		-- ombres pour les 4 lampes les plus fortes seulement : chaque lumière à ombres coûte cher en éclairage Future
		-- (jusqu'à 10 lampes dans le métro, plus les projecteurs et lampes de MapExtras côté client)
		local order = {}
		for k in ipairs(info.lights) do table.insert(order, k) end
		table.sort(order, function(x: number, y: number) return info.lights[x].i > info.lights[y].i end)
		local shadowed: { [number]: boolean } = {}
		for r = 1, math.min(4, #order) do shadowed[order[r]] = true end
		for li, L in ipairs(info.lights) do
			local a = Instance.new("Part"); a.Name = "Lamp"; a.Anchored = true; a.CanCollide = false; a.CanQuery = false; a.CanTouch = false
			a.Transparency = 1; a.Size = Vector3.new(0.2, 0.2, 0.2); a.CastShadow = false
			a.Position = origin + Vector3.new(L.p[1], L.p[2], L.p[3]) * U
			local pl = Instance.new("PointLight")
			pl.Color = MapScene.color(L.c); pl.Range = math.clamp((if L.d > 0 then L.d else 20) * U * 0.6, 8, 60)
			pl.Brightness = math.clamp(L.i / 9, 0.4, 3); pl.Shadows = shadowed[li] == true    -- ombres des lampes (éclairage Future)
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
