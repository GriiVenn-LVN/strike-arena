--!strict
-- ReplicatedStorage/Shared/MapExtras (ModuleScript, client)
-- Détails de rendu ajoutés par le client à la carte où se trouve le joueur, en plus du décor du web, pour un rendu de jeu
-- réaliste (utilisé par StarterPlayerScripts/MapDetailController). Placés d'après la grille de jeu (MapData : cases
-- libres, murs, fûts, plafonds) et le thème de la carte, tirés au sort avec une graine fixe (mêmes places à chaque partie) :
--   • terrain Roblox autour de la carte, à la place du grand sol uni du web : eau animée qui reflète (Port, Labo), herbe
--     (Temple perdu, cartes hantées : herbe en 3D si Terrain.Decoration est coché dans Studio) ;
--   • au sol : flaques qui brillent (nuit, métro, cartes hantées), traînées de saleté au pied des murs, gravats, feuilles
--     mortes, congères (Station), douilles (Stand de tir) ;
--   • décalcomanies d'usure (images de MapDress.decal) : taches au sol, coulures d'eau sous le haut des murs, fissures,
--     crasse au pied des murs, graffitis abstraits sur les grands murs (pas dans le temple ni les cartes hantées) ;
--   • câbles tendus entre les toits, projecteurs muraux et lampes des halos du web qui éclairent vraiment la nuit, fûts en
--     feu (Port, Labo), brume au ras du sol (cartes hantées, Port).
-- Pièces simples, Beam, terrain, textures intégrées au client (rbxasset) et images de MapDress (halo, décalcomanies
-- « m:fx:* », envoyées par MeshUploader ; sinon dessinées en EditableImage, ou absentes si l'API est refusée). Budget : quelques centaines de pièces non collisionnables et ignorées des rayons, une trentaine de lumières
-- au plus, une seule carte habillée à la fois. Qualité basse (ombres coupées dans les réglages) : ni particules, ni ombres.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MapData = require(ReplicatedStorage.Shared.MapData)
local MapScene = require(ReplicatedStorage.Shared.MapScene)
local MapDress = require(ReplicatedStorage.Shared.MapDress)

local MapExtras = {}
local U = Config.STUDS_PER_METER
local S = Config.CELL
local CELL = S * U
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

type Build = MapDress.Build

-- réglages par thème du web (nombres = combien en poser au plus)
type Profile = { puddles: number, dirt: number, debris: number, debrisMat: Enum.Material, leaves: number, leafCols: { Color3 },
	drifts: boolean, casings: number, cables: number, lamps: number, lampCol: Color3, glowLights: number, fire: number,
	mist: boolean, grass: Color3?, stains: number, streaks: number, cracks: number, grime: number, graffiti: number, stainCol: Color3? }
local GREEN = { Color3.fromRGB(86, 112, 48), Color3.fromRGB(112, 96, 52), Color3.fromRGB(70, 92, 40), Color3.fromRGB(128, 104, 60) }
local DEAD = { Color3.fromRGB(92, 64, 36), Color3.fromRGB(120, 78, 38), Color3.fromRGB(70, 52, 34), Color3.fromRGB(140, 96, 44) }
local function P(t: { [string]: any }): Profile
	local d: { [string]: any } = { puddles = 0, dirt = 60, debris = 70, debrisMat = Enum.Material.Concrete, leaves = 0, leafCols = GREEN,
		drifts = false, casings = 0, cables = 0, lamps = 0, lampCol = Color3.fromRGB(255, 214, 160), glowLights = 0, fire = 0, mist = false,
		stains = 16, streaks = 12, cracks = 10, grime = 14, graffiti = 3 }
	for k, v in pairs(t) do d[k] = v end
	return d :: any
end
local PROFILES: { [string]: Profile } = {
	sand = P({ dirt = 70, debris = 90, debrisMat = Enum.Material.Sandstone, cables = 6, stains = 14, streaks = 8, cracks = 14, grime = 16, graffiti = 3 }),
	industrial = P({ puddles = 6, dirt = 90, debris = 110, cables = 8, stains = 24, streaks = 16, graffiti = 6, stainCol = Color3.fromRGB(26, 26, 28) }),
	snow = P({ dirt = 0, debris = 40, debrisMat = Enum.Material.Rock, drifts = true, cables = 5, stains = 6, streaks = 10, grime = 6, graffiti = 2 }),
	night = P({ puddles = 18, dirt = 90, debris = 110, cables = 10, lamps = 6, lampCol = Color3.fromRGB(255, 196, 128), glowLights = 16, fire = 2, mist = true,
		stains = 24, streaks = 18, graffiti = 6, stainCol = Color3.fromRGB(24, 24, 26) }),
	metro = P({ puddles = 14, dirt = 100, debris = 120, glowLights = 10, stains = 28, streaks = 16, grime = 24, graffiti = 10, stainCol = Color3.fromRGB(24, 24, 26) }),
	jungle = P({ puddles = 5, dirt = 60, debris = 70, debrisMat = Enum.Material.Rock, leaves = 220, grass = Color3.fromRGB(86, 120, 58),
		stains = 14, streaks = 20, cracks = 12, graffiti = 0, stainCol = Color3.fromRGB(40, 52, 30) }),
	range = P({ dirt = 60, debris = 60, casings = 90, cables = 6, stains = 14, graffiti = 2 }),
	haunt = P({ puddles = 10, dirt = 70, debris = 80, debrisMat = Enum.Material.Slate, leaves = 200, leafCols = DEAD, lamps = 4,
		lampCol = Color3.fromRGB(200, 220, 255), glowLights = 14, mist = true, grass = Color3.fromRGB(52, 64, 40),
		stains = 26, streaks = 22, cracks = 18, grime = 20, graffiti = 0 }),
	halloween = P({ puddles = 8, dirt = 70, debris = 80, debrisMat = Enum.Material.Slate, leaves = 220, leafCols = DEAD, lamps = 4,
		glowLights = 18, mist = true, grass = Color3.fromRGB(56, 62, 38), stains = 22, streaks = 20, cracks = 16, grime = 18, graffiti = 0 }),
}

-- état d'une carte habillée (terrain et éclairage global à remettre en partant)
type Saved = { regions: { { cf: CFrame, size: Vector3 } }, water: { [string]: any }?, grass: Color3?,
	emitters: { ParticleEmitter }, shadows: { Light }, conn: RBXScriptConnection? }
local saved: { [Build]: Saved } = {}

local function low(): boolean return not Lighting.GlobalShadows end

local function hash(s: string): number
	local h = 5381
	for i = 1, #s do h = (h * 33 + string.byte(s, i)) % 2147483647 end
	return h
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, cls: string?): BasePart
	local p = Instance.new((cls or "Part") :: any) :: BasePart
	p.Name = name; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Massless = true
	p.CastShadow = false; p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size; p.CFrame = cf; p.Color = color; p.Material = mat
	p.Parent = parent
	return p
end

local function darker(c: Color3, k: number): Color3 return Color3.new(c.R * k, c.G * k, c.B * k) end

-- ---------- terrain autour de la carte : eau (grand sol bleu métallique du web) ou herbe ----------
local function terrainRing(b: Build, sv: Saved, prof: Profile)
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if not terrain then return end
	local prims = MapScene.prims(b.id)
	local info = MapScene.info(b.id)
	-- grand sol extérieur du web (plan de 600 m) : le plus grand bloc
	local best, bi = 0, 0
	for i, p in ipairs(prims) do
		local a = p.size.X * p.size.Y + p.size.Y * p.size.Z + p.size.X * p.size.Z
		if p.kind == 0 and a > best then best, bi = a, i end
	end
	if bi == 0 or best < 300 * 300 then return end
	local pr = prims[bi]
	local mi = MapScene.faceMain(pr)
	local m = mi > 0 and info.mats[mi] or nil
	local water = m ~= nil and m.rm == "Metal"
	if not water and not prof.grass then return end
	-- surface du terrain un peu au-dessus du plan du web (gardé dessous : il prolonge le sol au loin, dans la brume)
	local top = pr.pos.Y * U + (if water then 0.5 else 0.4)
	local W = MapData.N * CELL
	local M = 50 * U                                  -- 50 m autour de la carte (bien moins que l'écart entre deux matchs)
	local gap = if water then 0 else 4                 -- l'herbe reste hors du sol de jeu (brins qui dépasseraient)
	local th = 8
	local y = top - th / 2
	local blocks = {
		{ -M / 2 - gap / 2, W / 2, M - gap, W + 2 * M }, { W + M / 2 + gap / 2, W / 2, M - gap, W + 2 * M },
		{ W / 2, -M / 2 - gap / 2, W + 2 * gap, M - gap }, { W / 2, W + M / 2 + gap / 2, W + 2 * gap, M - gap },
	}
	local mat = if water then Enum.Material.Water else Enum.Material.Grass
	if water then
		sv.water = { WaterColor = terrain.WaterColor, WaterTransparency = terrain.WaterTransparency, WaterReflectance = terrain.WaterReflectance,
			WaterWaveSize = terrain.WaterWaveSize, WaterWaveSpeed = terrain.WaterWaveSpeed }
		terrain.WaterColor = Color3.fromRGB(16, 40, 58); terrain.WaterTransparency = 0.25; terrain.WaterReflectance = 1
		terrain.WaterWaveSize = 0.1; terrain.WaterWaveSpeed = 5
	else
		sv.grass = terrain:GetMaterialColor(Enum.Material.Grass)
		terrain:SetMaterialColor(Enum.Material.Grass, prof.grass :: Color3)
	end
	for _, e in ipairs(blocks) do
		local cf = CFrame.new(b.origin + Vector3.new(e[1], y, e[2]))
		local size = Vector3.new(e[3], th, e[4])
		terrain:FillBlock(cf, size, mat)
		table.insert(sv.regions, { cf = cf, size = size + Vector3.new(4, 8, 4) })
	end
end

-- ---------- grille : cases libres au sol, bords de murs, hauts de murs ----------
type Cell = { cx: number, cz: number, dx: number, dz: number, h: number }
local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

local function scan(g: any): ({ Cell }, { Cell }, { Cell }, { Cell }, { Cell })
	local N = MapData.N
	local open, outdoor, edges, tops, barrels = {}, {}, {}, {}, {}
	local function solid(x: number, z: number, minH: number): boolean
		if x < 0 or z < 0 or x >= N or z >= N then return false end
		local j = z * N + x
		return g.type[j] ~= 0 and g.ramp[j] == 0 and g.h[j] >= minH
	end
	local function free(x: number, z: number): boolean
		if x < 0 or z < 0 or x >= N or z >= N then return false end
		local j = z * N + x
		return g.type[j] == 0 and g.ramp[j] == 0 and g.h[j] < 0.05
	end
	for z = 0, N - 1 do
		for x = 0, N - 1 do
			local i = z * N + x
			if free(x, z) then
				local c: Cell = { cx = x, cz = z, dx = 0, dz = 0, h = 0 }
				table.insert(open, c)
				if g.ceil[i] >= 90 then table.insert(outdoor, c) end
				for _, d in ipairs(DIRS) do
					if solid(x + d[1], z + d[2], 0.8) then table.insert(edges, { cx = x, cz = z, dx = d[1], dz = d[2], h = 0 }) end
				end
			elseif g.ramp[i] == 0 and g.type[i] == 5 and g.ceil[i] >= 90 then
				table.insert(barrels, { cx = x, cz = z, dx = 0, dz = 0, h = g.h[i] })
			elseif solid(x, z, 3) then
				-- haut d'un mur au bord d'une case libre à ciel ouvert (câbles, projecteurs)
				for _, d in ipairs(DIRS) do
					local nx, nz = x + d[1], z + d[2]
					if free(nx, nz) and g.ceil[nz * N + nx] >= 90 and g.ceil[i] >= 90 then
						table.insert(tops, { cx = x, cz = z, dx = d[1], dz = d[2], h = g.h[i] })
						break
					end
				end
			end
		end
	end
	return open, outdoor, edges, tops, barrels
end

-- ---------- décalcomanies d'usure ----------
-- Chaque décalcomanie est un Decal sur une pièce invisible très fine posée 3 cm devant le mur (ou sur le sol) : les blocs
-- du décor restent intacts. Murs : face de la case libre contre une case pleine (grille du web), hauteur du mur lue
-- dans la grille ; les graffitis seulement sur un mur continu sur trois cases (pas à cheval sur un angle ou une porte).
local function decals(folder: Instance, rng: Random, prof: Profile, g: any, edges: { Cell }, open: { Cell }, floorCol: Color3,
	at: (Cell, number, number, number) -> Vector3)
	local N = MapData.N
	local function wallH(c: Cell): number
		local x, z = c.cx + c.dx, c.cz + c.dz
		if x < 0 or z < 0 or x >= N or z >= N then return 0 end
		local j = z * N + x
		return math.min(g.h[j], g.ceil[c.cz * N + c.cx])
	end
	local function sameWall(c: Cell, k: number): boolean   -- case voisine le long du mur, libre et contre un mur aussi haut
		local px, pz = c.cx + c.dz * k, c.cz + c.dx * k
		if px < 0 or pz < 0 or px >= N or pz >= N then return false end
		local i = pz * N + px
		if g.type[i] ~= 0 or g.ramp[i] ~= 0 or g.h[i] > 0.05 then return false end
		return wallH({ cx = px, cz = pz, dx = c.dx, dz = c.dz, h = 0 }) >= wallH(c) - 0.3
	end
	local function onWall(name: string, c: Cell, w: number, h: number, y: number, along: number, col: Color3, tr: number)
		local img = MapDress.decal(name)
		if not img then return end
		local dir = Vector3.new(c.dx, 0, c.dz)
		local side = Vector3.new(c.dz, 0, c.dx)
		local pos = at(c, c.dx * (CELL / 2 - 0.1), c.dz * (CELL / 2 - 0.1), y * U) + side * along
		local p = part(folder, "Usure", Vector3.new(w * U, h * U, 0.05), CFrame.lookAt(pos, pos - dir), Color3.new(), Enum.Material.SmoothPlastic)
		p.Transparency = 1
		local d = Instance.new("Decal")
		d.Face = Enum.NormalId.Front; d.TextureContent = img; d.Color3 = col; d.Transparency = tr
		d.Parent = p
	end
	local wallCol = darker(floorCol, 0.32)
	-- coulures sous le haut des murs de plus de 2,2 m
	for _ = 1, prof.streaks do
		local c = edges[rng:NextInteger(1, math.max(1, #edges))]
		if not c then break end
		local hw = wallH(c)
		if hw >= 2.2 and hw < 40 then
			local h = math.min(hw - 0.1, rng:NextNumber(1.4, 2.8))
			local w = rng:NextNumber(0.7, 1.5)
			onWall("coulure", c, w, h, hw - 0.05 - h / 2, rng:NextNumber(-0.5, 0.5) * (S - w) * U, prof.stainCol or wallCol, rng:NextNumber(0.15, 0.4))
		end
	end
	-- crasse au pied des murs
	for _ = 1, prof.grime do
		local c = edges[rng:NextInteger(1, math.max(1, #edges))]
		if not c then break end
		if wallH(c) >= 0.8 then
			local h = rng:NextNumber(0.35, 0.7)
			onWall("suie", c, S * rng:NextNumber(0.7, 1), h, h / 2 + 0.01, 0, prof.stainCol or wallCol, rng:NextNumber(0.2, 0.45))
		end
	end
	-- fissures dans les murs
	for _ = 1, prof.cracks do
		local c = edges[rng:NextInteger(1, math.max(1, #edges))]
		if not c then break end
		local hw = wallH(c)
		if hw >= 1.6 then
			local s = rng:NextNumber(0.6, 1.3)
			onWall("fissure", c, s, s, rng:NextNumber(0.6, math.min(hw - s / 2 - 0.1, 2.6)), rng:NextNumber(-0.3, 0.3) * (S - s) * U,
				Color3.fromRGB(26, 23, 20), rng:NextNumber(0.1, 0.35))
		end
	end
	-- graffitis (peinture usée), sur un mur continu d'au moins 3 cases
	local placed, tries = 0, 0
	while placed < prof.graffiti and tries < 300 and #edges > 0 do
		tries += 1
		local c = edges[rng:NextInteger(1, #edges)]
		local hw = wallH(c)
		if hw >= 2.4 and hw < 40 and sameWall(c, 1) and sameWall(c, -1) then
			placed += 1
			local w = rng:NextNumber(1.8, 2.8)
			onWall(if rng:NextNumber() < 0.5 then "graffiti1" else "graffiti2", c, w, w / 2, rng:NextNumber(1.1, math.min(1.7, hw - w / 4 - 0.1)), 0,
				Color3.new(1, 1, 1), rng:NextNumber(0.1, 0.3))
		end
	end
	-- taches au sol
	local img = MapDress.decal("tache")
	if img then
		for _ = 1, prof.stains do
			local c = open[rng:NextInteger(1, math.max(1, #open))]
			if not c then break end
			local d = rng:NextNumber(0.7, 2) * U
			local cf = CFrame.new(at(c, rng:NextNumber(-0.4, 0.4) * CELL, rng:NextNumber(-0.4, 0.4) * CELL, 0.135)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			local p = part(folder, "Tache", Vector3.new(d, 0.02, d * rng:NextNumber(0.6, 1)), cf, Color3.new(), Enum.Material.SmoothPlastic)
			p.Transparency = 1
			local dc = Instance.new("Decal")
			dc.Face = Enum.NormalId.Top; dc.TextureContent = img; dc.Color3 = prof.stainCol or darker(floorCol, 0.38)
			dc.Transparency = rng:NextNumber(0.2, 0.5)
			dc.Parent = p
		end
	end
end

-- ---------- construction ----------
function MapExtras.build(b: Build, info: any)
	if not b.alive or not b.details then return end
	local md = MapData[b.id]
	local themeName: string = (md and md.theme) or "sand"
	local prof = PROFILES[themeName] or PROFILES.sand
	local sv: Saved = { regions = {}, emitters = {}, shadows = {} }
	saved[b] = sv
	local folder = Instance.new("Folder"); folder.Name = "Extras"; folder.Parent = b.details
	local rng = Random.new(hash(b.id))
	local O = b.origin
	local function at(c: Cell, ox: number, oz: number, y: number): Vector3
		return O + Vector3.new((c.cx + 0.5) * CELL + ox, y, (c.cz + 0.5) * CELL + oz)
	end
	local function pick<T>(list: { T }): T? return if #list > 0 then list[rng:NextInteger(1, #list)] else nil end

	pcall(terrainRing, b, sv, prof)
	if not b.alive then return end

	local g = MapData.buildGrid(b.id)
	local open, outdoor, edges, tops, barrels = scan(g)
	-- couleur du sol de jeu (le grand plan de 80 m avec le détail du sol du web)
	local floorCol = Color3.fromRGB(120, 120, 120)
	for _, p in ipairs(MapScene.prims(b.id)) do
		local mi = MapScene.faceMain(p)
		local m = mi > 0 and info.mats[mi] or nil
		if m and m.det then floorCol = MapScene.color(m.avg); if p.color then floorCol = Color3.new(floorCol.R * p.color.R, floorCol.G * p.color.G, floorCol.B * p.color.B) end; break end
	end
	local snowy = md and md.base == "snow"

	-- flaques : disques vitreux sombres (reflets des lampes et du ciel avec l'éclairage Future)
	local wetCells = if themeName == "metro" then open else outdoor
	for _ = 1, prof.puddles do
		local c = pick(wetCells)
		if not c then break end
		local d = rng:NextNumber(0.9, 2.2) * U
		local ox, oz = rng:NextNumber(-0.5, 0.5) * U, rng:NextNumber(-0.5, 0.5) * U
		local col = darker(floorCol, 0.32)
		-- dessus des surfaces au sol (studs) : sol dessiné 0,01, calque d'ombres 0,09 (écarté par MapBuilder), saleté 0,13,
		-- flaque 0,18, petite flaque 0,23 ; à moins de 0,04 stud l'une de l'autre, elles scintillaient (z-fighting) au loin
		local p = part(folder, "Flaque", Vector3.new(0.03, d, d), CFrame.new(at(c, ox, oz, 0.165)) * CFrame.Angles(0, 0, math.pi / 2), col, Enum.Material.Glass)
		local pc = p :: Part; pc.Shape = Enum.PartType.Cylinder; p.Transparency = 0.3; p.Reflectance = 0.25
		local d2 = d * rng:NextNumber(0.45, 0.7)
		local q = part(folder, "Flaque", Vector3.new(0.03, d2, d2), CFrame.new(at(c, ox + (d - d2) * 0.45, oz + rng:NextNumber(-0.3, 0.3) * d, 0.215)) * CFrame.Angles(0, 0, math.pi / 2), col, Enum.Material.Glass)
		local qc = q :: Part; qc.Shape = Enum.PartType.Cylinder; q.Transparency = 0.3; q.Reflectance = 0.25
	end

	-- saleté au pied des murs (bande sombre translucide, terre ou béton sale) ; congères sur la neige
	local nd = 0
	for _, c in ipairs(edges) do
		if nd >= math.max(prof.dirt, if prof.drifts then 80 else 0) then break end
		if rng:NextNumber() < 0.45 then
			nd += 1
			local len = CELL * rng:NextNumber(0.55, 1)
			local along = rng:NextNumber(-1, 1) * (CELL - len) / 2
			if prof.drifts and snowy then
				-- congère : pente de neige contre le mur (face haute de la WedgePart vers le mur, côté +Z local)
				local depth, hgt = rng:NextNumber(0.6, 1.2) * U, rng:NextNumber(0.2, 0.45) * U
				local pos = at(c, c.dx * (CELL / 2 - depth / 2) + (if c.dx == 0 then along else 0), c.dz * (CELL / 2 - depth / 2) + (if c.dz == 0 then along else 0), hgt / 2)
				local dir = Vector3.new(c.dx, 0, c.dz)
				part(folder, "Congere", Vector3.new(len, hgt, depth), CFrame.lookAt(pos, pos - dir), Color3.fromRGB(236, 241, 248), Enum.Material.Snow, "WedgePart")
			elseif prof.dirt > 0 then
				local depth = rng:NextNumber(0.3, 0.7) * U
				local sx = if c.dx ~= 0 then depth else len
				local sz = if c.dz ~= 0 then depth else len
				local pos = at(c, c.dx * (CELL / 2 - depth / 2) + (if c.dx == 0 then along else 0), c.dz * (CELL / 2 - depth / 2) + (if c.dz == 0 then along else 0), 0.115)
				local mat = if themeName == "sand" or themeName == "jungle" then Enum.Material.Ground elseif themeName == "metro" or themeName == "night" or themeName == "industrial" or themeName == "range" then Enum.Material.Asphalt else Enum.Material.Mud
				local p = part(folder, "Salete", Vector3.new(sx, 0.03, sz), CFrame.new(pos), darker(floorCol, rng:NextNumber(0.45, 0.65)), mat)
				p.Transparency = rng:NextNumber(0.35, 0.55)
			end
		end
	end

	-- gravats : petits éclats contre les murs (et quelques-uns au milieu)
	for k = 1, prof.debris do
		local c = if rng:NextNumber() < 0.75 then pick(edges) else pick(open)
		if not c then break end
		local s = Vector3.new(rng:NextNumber(0.06, 0.32), rng:NextNumber(0.04, 0.2), rng:NextNumber(0.06, 0.3)) * U
		local ox = c.dx * rng:NextNumber(0.55, 0.92) * CELL / 2 + (if c.dx == 0 then rng:NextNumber(-0.45, 0.45) * CELL else 0)
		local oz = c.dz * rng:NextNumber(0.55, 0.92) * CELL / 2 + (if c.dz == 0 then rng:NextNumber(-0.45, 0.45) * CELL else 0)
		local cf = CFrame.new(at(c, ox, oz, s.Y * 0.35)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.4, 0.4))
		local p = part(folder, "Gravat", s, cf, darker(floorCol, rng:NextNumber(0.55, 1)), prof.debrisMat, if k % 4 == 0 then "WedgePart" else nil)
		p.CastShadow = s.Magnitude > 0.9
	end

	-- douilles du stand de tir
	for _ = 1, prof.casings do
		local c = pick(open)
		if not c then break end
		local cf = CFrame.new(at(c, rng:NextNumber(-0.45, 0.45) * CELL, rng:NextNumber(-0.45, 0.45) * CELL, 0.045)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		local p = part(folder, "Douille", Vector3.new(0.26, 0.09, 0.09), cf, Color3.fromRGB(196, 150, 70), Enum.Material.Metal)
		local pc = p :: Part; pc.Shape = Enum.PartType.Cylinder; p.Reflectance = 0.15
	end

	-- feuilles mortes au sol, plus nombreuses le long des murs
	for _ = 1, prof.leaves do
		local c = if rng:NextNumber() < 0.6 then pick(edges) else pick(outdoor)
		if not c then break end
		local ox = c.dx * rng:NextNumber(0.3, 0.95) * CELL / 2 + (if c.dx == 0 then rng:NextNumber(-0.48, 0.48) * CELL else 0)
		local oz = c.dz * rng:NextNumber(0.3, 0.95) * CELL / 2 + (if c.dz == 0 then rng:NextNumber(-0.48, 0.48) * CELL else 0)
		local sz = rng:NextNumber(0.08, 0.16) * U
		local cf = CFrame.new(at(c, ox, oz, 0.05)) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.25, 0.25))
		part(folder, "Feuille", Vector3.new(sz, 0.02, sz * 0.7), cf, prof.leafCols[rng:NextInteger(1, #prof.leafCols)], Enum.Material.Fabric)
	end
	task.wait()
	if not b.alive then return end
	local okD, errD = pcall(function(): any decals(folder, rng, prof, g, edges, open, floorCol, at); return nil end)
	if not okD then warn("[MapDetail] décalcomanies : " .. tostring(errD)) end
	task.wait()
	if not b.alive then return end

	-- câbles entre deux hauts de murs (8 à 22 m, hauteurs proches), qui pendent un peu
	if prof.cables > 0 and #tops > 1 then
		local anchor = part(folder, "Cables", Vector3.new(0.2, 0.2, 0.2), CFrame.new(O), Color3.new(), Enum.Material.SmoothPlastic)
		anchor.Transparency = 1
		local n, tries = 0, 0
		local used: { [string]: boolean } = {}
		while n < prof.cables and tries < 400 do
			tries += 1
			local a, c = pick(tops), pick(tops)
			if a and c and a ~= c then
				local pa = at(a, a.dx * CELL * 0.5, a.dz * CELL * 0.5, a.h * U + 0.08 * U)
				local pc = at(c, c.dx * CELL * 0.5, c.dz * CELL * 0.5, c.h * U + 0.08 * U)
				local dist = (pc - pa).Magnitude / U
				local key = math.min(a.cx * 100 + a.cz, c.cx * 100 + c.cz) .. ":" .. math.max(a.cx * 100 + a.cz, c.cx * 100 + c.cz)
				if dist > 8 and dist < 22 and math.abs(a.h - c.h) < 2.5 and not used[key] then
					used[key] = true
					n += 1
					-- courbe de Bézier du Beam : les deux poignées vers le bas (axe X des attachements)
					local a0 = Instance.new("Attachment"); a0.Parent = anchor; a0.WorldCFrame = CFrame.fromMatrix(pa, Vector3.new(0, -1, 0), Vector3.new(1, 0, 0))
					local a1 = Instance.new("Attachment"); a1.Parent = anchor; a1.WorldCFrame = CFrame.fromMatrix(pc, Vector3.new(0, 1, 0), Vector3.new(1, 0, 0))
					local sag = dist * rng:NextNumber(0.04, 0.08) * U / 0.75
					local bm = Instance.new("Beam")
					bm.Attachment0 = a0; bm.Attachment1 = a1
					bm.CurveSize0 = sag; bm.CurveSize1 = sag
					bm.Width0 = 0.045 * U; bm.Width1 = 0.045 * U; bm.FaceCamera = true; bm.Segments = 16
					bm.Color = ColorSequence.new(Color3.fromRGB(22, 22, 24)); bm.LightInfluence = 1; bm.LightEmission = 0
					bm.Transparency = NumberSequence.new(0)
					bm.Parent = anchor
				end
			end
		end
	end

	-- lumières : projecteurs muraux (nuit) et lampes sous les halos du web qui n'ont pas de vraie lampe
	local lights: { Vector3 } = {}
	for _, L in ipairs(info.lights or {}) do table.insert(lights, O + Vector3.new(L.p[1], L.p[2], L.p[3]) * U) end
	local function farFrom(p: Vector3, d: number): boolean
		for _, q in ipairs(lights) do if (q - p).Magnitude < d then return false end end
		return true
	end
	local nshadow = 0
	local function shadowed(l: Light, want: boolean)
		if want and nshadow < 6 then nshadow += 1; l.Shadows = not low(); table.insert(sv.shadows, l) else l.Shadows = false end
	end
	local glowImg = MapDress.glow()
	local placed = 0
	for _ = 1, 200 do
		if placed >= prof.lamps then break end
		local c = pick(tops)
		if not c then break end
		local dir = Vector3.new(c.dx, 0, c.dz)
		local base = at(c, c.dx * (CELL / 2 + 0.12 * U), c.dz * (CELL / 2 + 0.12 * U), (c.h - 0.35) * U)
		if farFrom(base, 14 * U) then
			placed += 1
			table.insert(lights, base)
			local cf = CFrame.lookAt(base, base + dir)
			part(folder, "Projecteur", Vector3.new(0.34, 0.14, 0.26) * U, cf, Color3.fromRGB(40, 42, 46), Enum.Material.Metal)
			local bulb = part(folder, "Ampoule", Vector3.new(0.28, 0.03, 0.2) * U, cf * CFrame.new(0, -0.085 * U, 0), prof.lampCol, Enum.Material.Neon)
			local sl = Instance.new("SpotLight")
			sl.Face = Enum.NormalId.Bottom; sl.Angle = 115; sl.Range = 15 * U; sl.Brightness = 2.4; sl.Color = prof.lampCol
			shadowed(sl, true)
			sl.Parent = bulb
			if glowImg then
				local bg = Instance.new("BillboardGui")
				bg.Size = UDim2.fromScale(1.4 * U, 1.4 * U); bg.LightInfluence = 0; bg.Brightness = 1.4; bg.MaxDistance = 450; bg.Adornee = bulb
				local il = Instance.new("ImageLabel")
				il.Size = UDim2.fromScale(1, 1); il.BackgroundTransparency = 1; il.ImageContent = glowImg; il.ImageColor3 = prof.lampCol; il.ImageTransparency = 0.35
				il.Parent = bg; bg.Parent = bulb
			end
		end
	end
	if prof.glowLights > 0 and #(info.glows or {}) > 0 then
		local list = table.clone(info.glows)
		table.sort(list, function(x: any, y: any) return x.s * x.o > y.s * y.o end)
		local anchor = part(folder, "LampesHalos", Vector3.new(0.2, 0.2, 0.2), CFrame.new(O), Color3.new(), Enum.Material.SmoothPlastic)
		anchor.Transparency = 1
		local n = 0
		for _, gl in ipairs(list) do
			if n >= prof.glowLights then break end
			local pos = O + Vector3.new(gl.p[1], gl.p[2], gl.p[3]) * U
			if farFrom(pos, 3 * U) then
				n += 1
				table.insert(lights, pos)
				local att = Instance.new("Attachment"); att.Parent = anchor; att.WorldPosition = pos
				local col = MapScene.color(gl.c)
				local l: Light
				if gl.p[2] > 2.5 then          -- lampe haute (réverbère, applique) : cône vers le sol
					local sl = Instance.new("SpotLight"); sl.Face = Enum.NormalId.Bottom; sl.Angle = 120; sl.Range = math.clamp(gl.s * U * 2.2, 10, 40)
					l = sl
				else
					local pl = Instance.new("PointLight"); pl.Range = math.clamp(gl.s * U * 1.6, 6, 24)
					l = pl
				end
				l.Color = col; l.Brightness = 0.8 + math.clamp(gl.o, 0, 1) * 1.2
				shadowed(l, n <= 3)
				l.Parent = att
			end
		end
	end

	-- fûts en feu : flammes, fumée et lueur orange
	local nf = 0
	for _ = 1, 40 do
		if nf >= prof.fire then break end
		local c = pick(barrels)
		if not c then break end
		local pos = at(c, 0, 0, (c.h + 0.05) * U)
		if farFrom(pos, 10 * U) then
			nf += 1
			table.insert(lights, pos)
			local p = part(folder, "Feu", Vector3.new(0.5, 0.2, 0.5) * U, CFrame.new(pos), Color3.new(), Enum.Material.SmoothPlastic)
			p.Transparency = 1
			local fl = Instance.new("ParticleEmitter")
			fl.Name = "Flammes"; fl.Texture = FIRE; fl.Rate = 28; fl.Lifetime = NumberRange.new(0.5, 0.9)
			fl.Speed = NumberRange.new(0.6 * U, 1.2 * U); fl.SpreadAngle = Vector2.new(12, 12); fl.LightEmission = 1; fl.LightInfluence = 0
			fl.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35 * U), NumberSequenceKeypoint.new(1, 0.08 * U) })
			fl.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
			fl.Color = ColorSequence.new(Color3.fromRGB(255, 190, 90), Color3.fromRGB(255, 80, 30))
			fl.Enabled = not low(); fl.Parent = p
			local sm = Instance.new("ParticleEmitter")
			sm.Name = "Fumee"; sm.Texture = SMOKE; sm.Rate = 5; sm.Lifetime = NumberRange.new(6, 9)
			sm.Speed = NumberRange.new(0.5 * U, 0.9 * U); sm.SpreadAngle = Vector2.new(10, 10); sm.Acceleration = Vector3.new(0.12 * U, 0, 0.05 * U)
			sm.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4 * U), NumberSequenceKeypoint.new(1, 2.4 * U) })
			sm.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0.72), NumberSequenceKeypoint.new(1, 1) })
			sm.Color = ColorSequence.new(Color3.fromRGB(46, 44, 42)); sm.RotSpeed = NumberRange.new(-25, 25); sm.Rotation = NumberRange.new(0, 360)
			sm.LightInfluence = 1; sm.Enabled = not low(); sm.Parent = p
			table.insert(sv.emitters, fl); table.insert(sv.emitters, sm)
			local pl = Instance.new("PointLight")
			pl.Color = Color3.fromRGB(255, 140, 60); pl.Range = 7 * U; pl.Brightness = 2
			shadowed(pl, true)
			pl.Parent = p
		end
	end

	-- brume au ras du sol, sur toute la carte
	if prof.mist then
		local W = MapData.N * CELL
		local p = part(folder, "Brume", Vector3.new(W * 0.95, 0.4 * U, W * 0.95), CFrame.new(O + Vector3.new(W / 2, 0.35 * U, W / 2)), Color3.new(), Enum.Material.SmoothPlastic)
		p.Transparency = 1
		local e = Instance.new("ParticleEmitter")
		e.Name = "Brume"; e.Texture = SMOKE; e.Shape = Enum.ParticleEmitterShape.Box; e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.Rate = 7; e.Lifetime = NumberRange.new(14, 20); e.Speed = NumberRange.new(0.05 * U, 0.2 * U); e.SpreadAngle = Vector2.new(180, 10)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3.5 * U), NumberSequenceKeypoint.new(1, 5 * U) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.86), NumberSequenceKeypoint.new(0.7, 0.86), NumberSequenceKeypoint.new(1, 1) })
		local fog = info.theme and info.theme.fog
		e.Color = ColorSequence.new(if fog then Color3.new(math.min(1, fog[1] * 1.6 + 0.08), math.min(1, fog[2] * 1.6 + 0.08), math.min(1, fog[3] * 1.6 + 0.1)) else Color3.fromRGB(150, 160, 170))
		e.RotSpeed = NumberRange.new(-6, 6); e.Rotation = NumberRange.new(0, 360); e.LightInfluence = 1
		e.Enabled = not low(); e.Parent = p
		table.insert(sv.emitters, e)
	end

	-- vraies lampes du web posées par le serveur (MapBuilder) : leurs ombres suivent aussi le réglage de qualité
	local lf = b.folder:FindFirstChild("Lights")
	if lf then
		for _, l in ipairs(lf:GetDescendants()) do
			if l:IsA("Light") and l.Shadows then table.insert(sv.shadows, l); l.Shadows = not low() end
		end
	end

	-- qualité : les réglages (ombres) coupent particules et ombres des lampes
	sv.conn = Lighting:GetPropertyChangedSignal("GlobalShadows"):Connect(function()
		for _, e in ipairs(sv.emitters) do e.Enabled = not low() end
		for _, l in ipairs(sv.shadows) do l.Shadows = not low() end
	end)
end

-- remet le terrain, l'eau et la couleur de l'herbe comme avant (les pièces sont dans Details, détruit avec la carte)
function MapExtras.clear(b: Build)
	local sv = saved[b]
	if not sv then return end
	saved[b] = nil
	if sv.conn then sv.conn:Disconnect() end
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		for _, r in ipairs(sv.regions) do pcall(function() terrain:FillBlock(r.cf, r.size, Enum.Material.Air) end) end
		local w = sv.water
		if w then for k, v in pairs(w) do pcall(function() (terrain :: any)[k] = v end) end end
		local gc = sv.grass
		if gc then pcall(function() terrain:SetMaterialColor(Enum.Material.Grass, gc) end) end
	end
end

return MapExtras
