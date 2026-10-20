--!strict
-- ReplicatedStorage/Shared/MapDress (ModuleScript, client + Studio)
-- Habillage d'une carte comme sur le web (utilisé par StarterPlayerScripts/MapDetailController, et par
-- ServerStorage/MeshUploader pour envoyer une fois sur Roblox les maillages et textures, voir MeshStore) :
--   • textures canvas du web posées sur les blocs du décor, sauf celles remplacées par un matériau PBR haute définition
--     de Roblox (MapScene.hdMaterial : enduit, briques, bois, béton, tôle… posé par le serveur) ; dessin du sol (sites,
--     zones) en calque translucide sur le matériau du sol, ombres cuites du web éclaircies ;
--   • tous les maillages non primitifs du web regroupés par matériau (peu de pièces), construits petit à petit ;
--   • halos lumineux des lampes, images du ciel.
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MapScene = require(ReplicatedStorage.Shared.MapScene)
local MeshStore = require(ReplicatedStorage.Shared.MeshStore)

local MapDress = {}
local U = Config.STUDS_PER_METER
local api = { mesh = true, image = true }
MapDress.api = api
local MAXV, MAXT = 30000, 18000          -- par maillage (limites Roblox : 60 000 sommets, 20 000 triangles)

export type Build = { folder: Instance, id: string, origin: Vector3, details: Folder?, alive: boolean, meshes: { EditableMesh }, images: { EditableImage } }

-- ---------- images ----------
-- clé stable (MeshStore) : l'image envoyée est utilisée si elle existe, sinon une EditableImage
local function newImage(key: string, w: number, h: number, make: () -> buffer, b: Build?): Content?
	local ok, res, img = pcall(function()
		return MeshStore.image("m:" .. key, function(): EditableImage?
			if not api.image then return nil end
			local e = AssetService:CreateEditableImage({ Size = Vector2.new(w, h) })
			e:WritePixelsBuffer(Vector2.zero, Vector2.new(w, h), make())
			return e
		end)
	end)
	if ok then
		if img and b then table.insert(b.images, img) end
		return res
	end
	api.image = false
	warn("[MapDetail] EditableImage indisponible : coche Game Settings → Security → « Allow Mesh / Image APIs ». Cartes en couleurs unies en attendant.")
	return nil
end

-- version haute définition (ServerStorage/MapTexturesHQ, clés « t2: » / « tt2: ») : prise quand elle est déjà envoyée sur
-- Roblox (le joueur n'a pas ses pixels, seulement le numéro d'asset), ou pendant l'envoi depuis Studio (MeshUploader) ;
-- sinon la texture réduite d'avant (clés « t: » / « tt: », repli)
local function wantHD(tid: string, key: string): boolean
	if MeshStore.uploader then return MapScene.hasHD(tid) end
	return MeshStore.ids["i:m:" .. key] ~= nil
end

-- image déjà envoyée : MeshStore.image renvoie son asset sans appeler fill (pas de pixels à lire)
local function sentImage(key: string): Content?
	local res = MeshStore.image("m:" .. key, function(): EditableImage? return nil end)
	return res
end

local baseImg: { [string]: Content | false } = {}      -- textures du web (gardées pour toutes les cartes)
local upImg: { [string]: Content | false } = {}        -- les mêmes pendant l'envoi (sans reprendre une image du jeu)
local function texImage(tid: string): Content?
	local cache = if MeshStore.uploader then upImg else baseImg
	local c = cache[tid]
	if c ~= nil then return if c then c :: any else nil end
	local img: Content? = nil
	if wantHD(tid, "t2:" .. tid) then
		if MeshStore.uploader then
			local t = MapScene.textureHD(tid)
			img = t and newImage("t2:" .. tid, t.w, t.h, function() return t.rgba end)
		else
			img = sentImage("t2:" .. tid)
		end
	end
	if not img then
		local t = MapScene.texture(tid)
		img = t and newImage("t:" .. tid, t.w, t.h, function() return t.rgba end)
	end
	cache[tid] = img or false
	return img
end

local function tintKey(c: Color3): string return string.format("%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)) end

-- texture teintée (MeshPart.TextureContent ne se teinte pas : on multiplie les pixels), propre à une carte
local function tintedImage(b: Build, cache: { [string]: Content | false }, tid: string, tint: Color3): Content?
	if tint.R > 0.98 and tint.G > 0.98 and tint.B > 0.98 then return texImage(tid) end
	local key = tid .. "|" .. tintKey(tint)
	local c = cache[key]
	if c ~= nil then return if c then c :: any else nil end
	local hd = wantHD(tid, "tt2:" .. key)
	if hd and not MeshStore.uploader then
		local sent = sentImage("tt2:" .. key)
		if sent then cache[key] = sent; return sent end
		hd = false
	end
	local t = if hd then MapScene.textureHD(tid) else MapScene.texture(tid)
	local img: Content? = nil
	if t then
		img = newImage((if hd then "tt2:" else "tt:") .. key, t.w, t.h, function()
			local n = t.w * t.h
			local out = buffer.create(n * 4)
			local r, g, bb = tint.R, tint.G, tint.B
			for i = 0, n - 1 do
				local o = i * 4
				buffer.writeu8(out, o, buffer.readu8(t.rgba, o) * r)
				buffer.writeu8(out, o + 1, buffer.readu8(t.rgba, o + 1) * g)
				buffer.writeu8(out, o + 2, buffer.readu8(t.rgba, o + 2) * bb)
				buffer.writeu8(out, o + 3, buffer.readu8(t.rgba, o + 3))
			end
			return out
		end, b)
	end
	cache[key] = img or false
	return img
end

-- détail fin du sol : gris centré sur 128 multiplié ×2 sur le web -> calque noir / blanc semi-transparent
local detailImg: { [string]: Content | false } = {}
local function detailImage(tid: string, str: number): Content?
	local key = tid .. "|" .. str
	local c = detailImg[key]
	if c ~= nil then return if c then c :: any else nil end
	local t = MapScene.texture(tid)
	local img: Content? = nil
	if t then
		img = newImage("d:" .. key, t.w, t.h, function()
			local n = t.w * t.h
			local out = buffer.create(n * 4)
			for i = 0, n - 1 do
				local m = 1 + str * (buffer.readu8(t.rgba, i * 4) * 2 / 255 - 1)
				local v, a = if m < 1 then 0 else 255, math.clamp(math.abs(m - 1), 0, 1)
				buffer.writeu8(out, i * 4, v); buffer.writeu8(out, i * 4 + 1, v); buffer.writeu8(out, i * 4 + 2, v); buffer.writeu8(out, i * 4 + 3, a * 255)
			end
			return out
		end)
	end
	detailImg[key] = img or false
	return img
end

local whiteImg: Content? = nil
local function white(): Content?
	if whiteImg then return whiteImg end
	whiteImg = newImage("white", 4, 4, function() local buf = buffer.create(4 * 4 * 4); buffer.fill(buf, 0, 255); return buf end)
	return whiteImg
end

local glowImg: Content? = nil
local function glow(): Content?      -- même dégradé que glowTex() du web
	if glowImg then return glowImg end
	local S = 64
	glowImg = newImage("glow", S, S, function()
		local buf = buffer.create(S * S * 4)
		for y = 0, S - 1 do for x = 0, S - 1 do
			local d = math.min(1, math.sqrt((x + 0.5 - S / 2) ^ 2 + (y + 0.5 - S / 2) ^ 2) / (S / 2))
			local a = if d < 0.2 then 1 - d / 0.2 * 0.3 elseif d < 0.5 then 0.7 - (d - 0.2) / 0.3 * 0.52 else 0.18 * (1 - (d - 0.5) / 0.5)
			local o = (y * S + x) * 4
			buffer.writeu8(buf, o, 255); buffer.writeu8(buf, o + 1, 255); buffer.writeu8(buf, o + 2, 255); buffer.writeu8(buf, o + 3, math.clamp(a, 0, 1) * 255)
		end end
		return buf
	end)
	return glowImg
end

-- déjà envoyées (MeshStore) : réutilisées par MapAmbience (particules, halo de la lune, feuilles qui tombent)
MapDress.glow = glow
MapDress.texture = texImage

-- ---------- décalcomanies d'usure (MapExtras) : images dessinées ici, envoyées une fois (clés « m:fx:<nom> ») ----------
-- taches, coulures d'eau sous les toits, fissures, crasse au pied des murs, deux graffitis abstraits (sans texte).
-- Dessin déterministe (graine fixe) : la même image à chaque partie, envoyée telle quelle par MeshUploader. Usure en gris
-- clair (teinte donnée par Decal.Color3 selon la carte), graffitis en couleurs.
local function fbm(seed: number, P: number): (number, number) -> number
	-- bruit de valeur répété (période P cases) sur 4 octaves, de 0 à 1
	local rng = Random.new(seed)
	local grid = table.create(P * P)
	for i = 1, P * P do grid[i] = rng:NextNumber() end
	local function at(x: number, y: number): number return grid[(y % P) * P + (x % P) + 1] end
	local function vn(u: number, v: number, f: number): number
		local x, y = u * f, v * f
		local x0, y0 = math.floor(x), math.floor(y)
		local tx, ty = x - x0, y - y0
		tx = tx * tx * (3 - 2 * tx); ty = ty * ty * (3 - 2 * ty)
		local a = at(x0, y0) + (at(x0 + 1, y0) - at(x0, y0)) * tx
		local b = at(x0, y0 + 1) + (at(x0 + 1, y0 + 1) - at(x0, y0 + 1)) * tx
		return a + (b - a) * ty
	end
	return function(u: number, v: number): number
		return vn(u, v, 4) * 0.5 + vn(u, v, 8) * 0.25 + vn(u, v, 16) * 0.15 + vn(u, v, 32) * 0.1
	end
end

-- distance d'un point à une polyligne (liste de { x, y }) en pixels
local function polyDist(pts: { { number } }, x: number, y: number): number
	local best = math.huge
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local dx, dy = b[1] - a[1], b[2] - a[2]
		local t = math.clamp(((x - a[1]) * dx + (y - a[2]) * dy) / math.max(1e-6, dx * dx + dy * dy), 0, 1)
		local ex, ey = a[1] + dx * t - x, a[2] + dy * t - y
		local d = ex * ex + ey * ey
		if d < best then best = d end
	end
	return math.sqrt(best)
end

type Painter = (u: number, v: number, x: number, y: number) -> (number, number, number, number)
local DECALS: { [string]: { w: number, h: number, make: () -> Painter } } = {
	-- tache sombre aux bords déchiquetés (huile, eau, terre)
	tache = { w = 128, h = 128, make = function(): Painter
		local n = fbm(101, 32)
		return function(u, v)
			local r = math.sqrt((u - 0.5) ^ 2 + (v - 0.5) ^ 2) * 2
			local a = math.clamp((1 - r * 1.1) * 1.6 + (n(u, v) - 0.5) * 1.4, 0, 1) ^ 1.3
			local k = 0.8 + n(v, u) * 0.4
			return 240 * k, 240 * k, 240 * k, a * 0.85
		end
	end },
	-- coulures d'eau sous le haut d'un mur (haut de l'image = haut du mur)
	coulure = { w = 128, h = 256, make = function(): Painter
		local n = fbm(202, 32)
		local cols = table.create(128)
		local rng = Random.new(203)
		for i = 1, 128 do cols[i] = 0 end
		for _ = 1, 9 do                                     -- traînées de largeurs et longueurs différentes
			local c, w, len = rng:NextNumber(0.08, 0.92), rng:NextNumber(0.02, 0.07), rng:NextNumber(0.35, 1)
			for i = 1, 128 do
				local d = math.abs((i - 0.5) / 128 - c) / w
				if d < 1 then cols[i] = math.max(cols[i], (1 - d * d) * len) end
			end
		end
		return function(u, v, x)
			local len = cols[math.clamp(x + 1, 1, 128)]
			local fade = math.clamp(1 - v / math.max(0.05, len), 0, 1)
			local a = fade ^ 1.6 * (0.55 + n(u * 0.5, v) * 0.6) + math.clamp(1 - v * 9, 0, 1) * 0.35
			return 235, 235, 235, math.clamp(a, 0, 1) * 0.7
		end
	end },
	-- fissures fines qui partent d'un point (marches aléatoires ramifiées)
	fissure = { w = 128, h = 128, make = function(): Painter
		local rng = Random.new(304)
		local lines: { { { number } } } = {}
		local function walk(x: number, y: number, ang: number, steps: number, depth: number)
			local pts = { { x, y } }
			for _ = 1, steps do
				ang += rng:NextNumber(-0.6, 0.6)
				x += math.cos(ang) * 5; y += math.sin(ang) * 5
				table.insert(pts, { x, y })
				if depth < 2 and rng:NextNumber() < 0.12 then walk(x, y, ang + rng:NextNumber(-1.2, 1.2), steps // 2, depth + 1) end
			end
			table.insert(lines, pts)
		end
		for k = 0, 2 do walk(64, 64, k * 2.1 + rng:NextNumber(-0.4, 0.4), 11, 0) end
		return function(_u, _v, x, y)
			local d = math.huge
			for _, l in ipairs(lines) do d = math.min(d, polyDist(l, x + 0.5, y + 0.5)) end
			local a = math.clamp(1.3 - d * 0.75, 0, 1)
			return 255, 255, 255, a * 0.85
		end
	end },
	-- crasse et éclaboussures au pied des murs (bas de l'image = sol)
	suie = { w = 128, h = 64, make = function(): Painter
		local n = fbm(405, 32)
		return function(u, v)
			local a = v ^ 2.2 * (0.45 + n(u, v * 0.5) * 0.8)
			local side = math.clamp(math.min(u, 1 - u) * 6, 0, 1)    -- bords fondus
			return 240, 240, 240, math.clamp(a * side, 0, 1) * 0.8
		end
	end },
	-- graffitis abstraits (trait épais cerné, coulures de peinture), usés par le bruit
	graffiti1 = { w = 256, h = 128, make = function(): Painter
		local n = fbm(506, 32)
		local pts = {}
		for i = 0, 48 do local t = i / 48; table.insert(pts, { 20 + t * 216, 64 + math.sin(t * math.pi * 3 + 0.6) * 26 - t * 8 }) end
		return function(u, v, x, y)
			local d = polyDist(pts, x + 0.5, y + 0.5)
			local wear = 0.65 + n(u, v) * 0.5
			if d < 9 then return 168, 46, 40, math.clamp(wear, 0, 1) end
			if d < 13 then return 26, 22, 22, math.clamp(wear, 0, 1) end
			-- coulures sous le trait
			local drip = (x % 37 < 3) and y > 64 and y < 64 + 40 * n(u, 0.3) and d < 40
			if drip then return 150, 40, 36, 0.7 * wear end
			return 0, 0, 0, 0
		end
	end },
	graffiti2 = { w = 256, h = 128, make = function(): Painter
		local n = fbm(607, 32)
		local loops = {}
		for i = 0, 64 do
			local t = i / 64
			table.insert(loops, { 28 + t * 200 + math.cos(t * math.pi * 8) * 14, 66 + math.sin(t * math.pi * 8) * 30 })
		end
		return function(u, v, x, y)
			local d = polyDist(loops, x + 0.5, y + 0.5)
			local wear = 0.6 + n(u, v) * 0.55
			if d < 6 then return 44, 92, 164, math.clamp(wear, 0, 1) end
			if d < 10 then return 232, 230, 220, math.clamp(wear * 0.95, 0, 1) end
			return 0, 0, 0, 0
		end
	end },
}
MapDress.DECALS = { "tache", "coulure", "fissure", "suie", "graffiti1", "graffiti2" }

local decalImg: { [string]: Content | false } = {}
local decalUp: { [string]: Content | false } = {}
function MapDress.decal(name: string): Content?
	local cache = if MeshStore.uploader then decalUp else decalImg
	local c = cache[name]
	if c ~= nil then return if c then c :: any else nil end
	-- chez le joueur, seulement une fois envoyée : une EditableImage affichée donne le damier rose et cyan de Roblox
	local d = if MeshStore.uploader or MeshStore.ids["i:m:fx:" .. name] ~= nil then DECALS[name] else nil
	local img: Content? = nil
	if d then
		img = newImage("fx:" .. name, d.w, d.h, function()
			local paint = d.make()
			local buf = buffer.create(d.w * d.h * 4)
			for y = 0, d.h - 1 do
				for x = 0, d.w - 1 do
					local r, g, b, a = paint((x + 0.5) / d.w, (y + 0.5) / d.h, x, y)
					local o = (y * d.w + x) * 4
					buffer.writeu8(buf, o, math.clamp(r, 0, 255)); buffer.writeu8(buf, o + 1, math.clamp(g, 0, 255))
					buffer.writeu8(buf, o + 2, math.clamp(b, 0, 255)); buffer.writeu8(buf, o + 3, math.clamp(a, 0, 1) * 255)
				end
				if y % 16 == 15 then task.wait() end
			end
			return buf
		end)
	end
	cache[name] = img or false
	return img
end

local function mulC(a: Color3, b: Color3): Color3 return Color3.new(a.R * b.R, a.G * b.G, a.B * b.B) end
local function cdiff(a: Color3, b: Color3): number return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) end

-- ---------- textures du web sur les blocs du serveur ----------
local FACES = { Enum.NormalId.Right, Enum.NormalId.Left, Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Back, Enum.NormalId.Front }

local function faceDims(k: number, s: Vector3): (number, number)
	if k <= 2 then return s.Z, s.Y elseif k <= 4 then return s.X, s.Z end
	return s.X, s.Y
end

-- dessin du sol du web (512 px pour 80 m : sites, zones, marquages) : translucide, le grain du matériau du sol se voit dessous
local GROUND_DRAWING = 0.4

local function addTexture(p: BasePart, face: Enum.NormalId, img: Content, color: Color3, su: number, sv: number, transp: number?): Texture
	local t = Instance.new("Texture")
	t.Face = face; t.TextureContent = img; t.Color3 = color
	t.StudsPerTileU = math.max(su, 0.01); t.StudsPerTileV = math.max(sv, 0.01)
	if transp then t.Transparency = transp end
	t.Parent = p
	return t
end

function MapDress.dressPrims(b: Build, info: any)
	local vis = b.folder:FindFirstChild("Visuals")
	if not vis then return end
	local prims = MapScene.prims(b.id)
	local mats = info.mats
	local n = 0
	for _, p in ipairs(vis:GetChildren()) do
		if not b.alive then return end
		local idx = p:GetAttribute("P")
		local pr = typeof(idx) == "number" and prims[idx] or nil
		if pr and pr.kind == 0 and p:IsA("BasePart") then
			local inst = pr.color or Color3.new(1, 1, 1)
			local main = MapScene.faceMain(pr)
			-- couleur du bloc posée par le serveur, sans sa petite variation (MapScene.vary)
			local base = if main > 0 then mulC(MapScene.color(mats[main].avg), inst) else p.Color
			for k = 1, 6 do
				local mi = pr.mats[k]
				local plane = bit32.band(pr.flags, 1) ~= 0
				if mi > 0 and (k ~= 4 or plane) then
					local m = mats[mi]
					local fw, fh = faceDims(k, pr.size)
					local tw, th = faceDims(k, pr.tile)
					local hd = MapScene.hdMaterial(m)
					local col = mulC(MapScene.color(m.avg), inst)
					if hd and hd == p.Material then
						-- motif rendu par le matériau PBR du bloc : rien à poser, sauf une face d'une autre couleur
						if cdiff(col, base) > 0.05 then
							local w = white()
							if w then addTexture(p, FACES[k], w, col, fw * U, fh * U) end
						end
					elseif m.tex then                            -- dessin du web (ou face d'un autre matériau que le bloc)
						local img = texImage(m.tex)
						if img then
							local rep = m.rep or { 1, 1 }
							local tr: number? = if m.cut then (m.a or 0) else nil
							if MapScene.isBakedShadow(m) then tr = 1 - (1 - (m.a or 0)) * 0.55
							elseif m.det and p.Material ~= Enum.Material.SmoothPlastic then tr = GROUND_DRAWING end
							addTexture(p, FACES[k], img, mulC(MapScene.color(m.c), inst), tw * U / rep[1], th * U / rep[2], tr)
						end
					else
						if cdiff(col, base) > 0.05 then         -- dessus d'un mur, corniche… d'une autre couleur que les côtés
							local w = white()
							if w then addTexture(p, FACES[k], w, col, fw * U, fh * U) end
						end
					end
					-- grain du sol répété tous les 3 m : seulement si le sol n'a pas reçu de matériau Roblox à relief
					if m.det and p.Material == Enum.Material.SmoothPlastic then
						local d = detailImage(m.det.tex, m.det.str)
						if d then addTexture(p, FACES[k], d, Color3.new(1, 1, 1), m.det.rep * U, m.det.rep * U) end
					end
				end
			end
			n += 1
			if n % 150 == 0 then task.wait() end
		end
	end
end


-- ---------- maillages du web ----------
type Geo = { nv: number, ni: number, flags: number, groups: { { number } }, lo: Vector3, ext: Vector3, pos: number, nrm: number, uv: number, col: number, idx: number, i32: boolean }

local function readGeos(buf: buffer): ({ Geo }, number, number)
	local ng, ninst = buffer.readu32(buf, 0), buffer.readu32(buf, 4)
	local o = 8
	local geos: { Geo } = table.create(ng)
	for gi = 1, ng do
		local nv, ni, fl, ngr = buffer.readu32(buf, o), buffer.readu32(buf, o + 4), buffer.readu8(buf, o + 8), buffer.readu8(buf, o + 9)
		local f = function(k: number) return buffer.readf32(buf, o + 10 + k * 4) end
		local lo, hi = Vector3.new(f(0), f(1), f(2)), Vector3.new(f(3), f(4), f(5))
		o += 34
		local groups = table.create(ngr)
		for _ = 1, ngr do
			table.insert(groups, { buffer.readu32(buf, o), buffer.readu32(buf, o + 4), buffer.readu8(buf, o + 8) })
			o += 9
		end
		local g: Geo = { nv = nv, ni = ni, flags = fl, groups = groups, lo = lo, ext = hi - lo, pos = o, nrm = 0, uv = 0, col = 0, idx = 0, i32 = nv > 65535 }
		o += nv * 6
		if bit32.band(fl, 1) ~= 0 then g.nrm = o; o += nv * 3 end
		if bit32.band(fl, 2) ~= 0 then g.uv = o; o += nv * 4 end
		if bit32.band(fl, 4) ~= 0 then g.col = o; o += nv * 3 end
		g.idx = o; o += ni * (if g.i32 then 4 else 2)
		geos[gi] = g
	end
	return geos, ninst, o
end

-- un morceau de maillage en cours de remplissage
type Chunk = { P: { Vector3 }, N: { Vector3 }, UV: { Vector2 }, C: { Color3 }, T: { number }, hasN: boolean, hasUV: boolean, hasC: boolean }
local function newChunk(): Chunk return { P = {}, N = {}, UV = {}, C = {}, T = {}, hasN = false, hasUV = false, hasC = false } end


type Look = { color: Color3, img: Content?, shadow: boolean, mat: Enum.Material, cut: boolean }
local function flush(b: Build, ch: Chunk, m: any, look: Look, key: string)
	if #ch.T == 0 or not b.alive then return end
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in ipairs(ch.P) do lo = lo:Min(p); hi = hi:Max(p) end
	local center = (lo + hi) / 2
	local ok, err = pcall(function()
		local mp, em = MeshStore.meshPart(key, function()
			local em = AssetService:CreateEditableMesh({ FixedSize = false })
			if not em then error("mémoire des maillages pleine") end
			local vid = table.create(#ch.P)
			for i, p in ipairs(ch.P) do vid[i] = em:AddVertex(p - center); if i % 10000 == 0 then task.wait() end end
			local nid, uid, cid = {}, {}, {}
			if ch.hasN then for i, nn in ipairs(ch.N) do nid[i] = em:AddNormal(nn) end end
			if ch.hasUV then for i, uv in ipairs(ch.UV) do uid[i] = em:AddUV(uv) end end
			if ch.hasC then for i, c in ipairs(ch.C) do cid[i] = em:AddColor(c, 1) end end
			local T = ch.T
			for t = 1, #T, 3 do
				local a, bb, c = T[t], T[t + 1], T[t + 2]
				local f = em:AddTriangle(vid[a], vid[bb], vid[c])
				if ch.hasN then em:SetFaceNormals(f, { nid[a], nid[bb], nid[c] })
				else
					local nn = (ch.P[bb] - ch.P[a]):Cross(ch.P[c] - ch.P[a])
					if nn.Magnitude > 1e-9 then local k = em:AddNormal(nn.Unit); em:SetFaceNormals(f, { k, k, k }) end
				end
				if ch.hasUV then em:SetFaceUVs(f, { uid[a], uid[bb], uid[c] }) end
				if ch.hasC then em:SetFaceColors(f, { cid[a], cid[bb], cid[c] }) end
				if t % 12000 == 1 and t > 1 then task.wait() end
			end
			return em
		end)
		mp.Name = "Detail"; mp.Anchored = true; mp.CanCollide = false; mp.CanQuery = false; mp.CanTouch = false; mp.Massless = true
		mp.CastShadow = look.shadow; mp.Color = look.color; mp.Material = look.mat
		if m.refl then mp.Reflectance = m.refl end
		if m.a and not look.cut then mp.Transparency = m.a end
		if look.img then
			mp.TextureContent = look.img :: Content
			if look.cut then     -- feuilles, toiles : découpe par la transparence de la texture
				local okCut = pcall(function()
					local sa = Instance.new("SurfaceAppearance")
					sa.AlphaMode = Enum.AlphaMode.Transparency
					sa.ColorMapContent = look.img :: Content
					sa.Parent = mp
				end)
				-- sans découpe, l'herbe et les toiles s'affichaient en carrés noirs : on ne les montre pas
				if not okCut then mp:Destroy(); if em then em:Destroy() end; return end
			end
		elseif look.cut then
			mp:Destroy(); if em then em:Destroy() end; return
		end
		mp.CFrame = CFrame.new(b.origin + center)
		mp.Parent = b.details
		if em then table.insert(b.meshes, em) end
	end)
	if not ok then
		if api.mesh then warn("[MapDetail] EditableMesh indisponible (" .. tostring(err) .. ") : décor détaillé en blocs simples.") end
		api.mesh = false
	end
end

-- repli sans EditableMesh : boîte englobante colorée de chaque objet
local function fallbackPart(b: Build, g: Geo, e: { number }, color: Color3, m: any)
	local x, y, z = Vector3.new(e[1], e[2], e[3]), Vector3.new(e[4], e[5], e[6]), Vector3.new(e[7], e[8], e[9])
	local size = Vector3.new(g.ext.X * x.Magnitude, g.ext.Y * y.Magnitude, g.ext.Z * z.Magnitude) * U
	if size.Magnitude < 0.25 or math.max(size.X, size.Y, size.Z) > 150 then return end
	local c = g.lo + g.ext / 2
	local wc = Vector3.new(e[10], e[11], e[12]) + x * c.X + y * c.Y + z * c.Z
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Color = color
	p.Material = MapScene.hdMaterial(m) or MapScene.material(m.rm)
	p.Size = Vector3.new(math.max(size.X, 0.05), math.max(size.Y, 0.05), math.max(size.Z, 0.05))
	local ok = pcall(function() p.CFrame = CFrame.fromMatrix(b.origin + wc * U, x.Unit, y.Unit, z.Unit) end)
	if not ok then p.CFrame = CFrame.new(b.origin + wc * U) end
	p.Parent = b.details
end

function MapDress.buildMeshes(b: Build, info: any)
	local buf = MapScene.meshBlob(b.id)
	if not buf then return end
	local geos, ninst, o = readGeos(buf)
	local mats, matlists = info.mats, info.matlists
	-- répartition des triangles par (matériau, couleur d'instance)
	type Entry = { e: { number }, g: Geo, start: number, count: number, flip: boolean, inst: Color3 }
	local buckets: { [string]: { mat: number, inst: Color3, list: { Entry }, shadow: boolean } } = {}
	local order: { string } = {}
	for i = 0, ninst - 1 do
		local r = o + i * 56
		local g = geos[buffer.readu16(buf, r) + 1]
		local ml = matlists[buffer.readu16(buf, r + 2) + 1]
		local fl = buffer.readu8(buf, r + 7)
		local inst = if bit32.band(fl, 1) ~= 0 then Color3.fromRGB(buffer.readu8(buf, r + 4), buffer.readu8(buf, r + 5), buffer.readu8(buf, r + 6)) else Color3.new(1, 1, 1)
		local e = table.create(12)
		for k = 0, 11 do e[k + 1] = buffer.readf32(buf, r + 8 + k * 4) end
		local det = e[1] * (e[5] * e[9] - e[6] * e[8]) - e[4] * (e[2] * e[9] - e[3] * e[8]) + e[7] * (e[2] * e[6] - e[3] * e[5])
		local groups = if #ml == 1 then { { 0, g.ni, 0 } } else g.groups
		if not api.mesh then
			local m0 = mats[ml[1] + 1]
			if m0 and (not m0.cut or MapScene.hdMaterial(m0)) then fallbackPart(b, g, e, mulC(MapScene.color(m0.avg), inst), m0) end
		else
			for _, gr: { number } in ipairs(groups) do
				local mi = ml[math.min(#ml, gr[3] + 1)]
				if mi and mi >= 0 then
					local key = mi .. "#" .. tintKey(inst)
					local bk = buckets[key]
					if not bk then bk = { mat = mi + 1, inst = inst, list = {}, shadow = false }; buckets[key] = bk; table.insert(order, key) end
					if bit32.band(fl, 2) ~= 0 then bk.shadow = true end
					table.insert(bk.list, { e = e, g = g, start = gr[1], count = gr[2], flip = det < 0, inst = inst })
				end
			end
		end
		if i % 200 == 199 then task.wait() end
	end
	local tinted: { [string]: Content | false } = {}
	local work = 0
	for _, key in ipairs(order) do
		if not b.alive or not api.mesh then break end
		local bk = buckets[key]
		local m = mats[bk.mat]
		local rep, off = m.rep or { 1, 1 }, m.off or { 0, 0 }
		-- texture floue remplacée par un matériau PBR (MapScene.hdMaterial) : couleur moyenne de la texture + matériau Roblox
		-- (les UV restent dans le maillage : mêmes morceaux, mêmes clés MeshStore qu'avant)
		local hd = MapScene.hdMaterial(m)
		local look: Look = { color = mulC(MapScene.color(m.avg), bk.inst), img = nil, shadow = bk.shadow and (hd ~= nil or not m.cut),
			mat = hd or MapScene.material(m.rm), cut = m.cut == true and hd == nil }
		if m.tex and not hd then look.img = tintedImage(b, tinted, m.tex, mulC(MapScene.color(m.c), bk.inst)) end
		if m.vc then look.color = bk.inst end
		-- clé stable de chaque morceau (MeshStore) : carte, matériau + teinte, numéro du morceau
		local nfl = 0
		local function fl(c: Chunk) nfl += 1; flush(b, c, m, look, "m:" .. b.id .. "#" .. key .. "#" .. nfl) end
		local ch = newChunk()
		for _, en in ipairs(bk.list) do
			local g, e = en.g, en.e
			local hasN = g.nrm ~= 0 and not m.fs
			local hasUV = g.uv ~= 0 and m.tex ~= nil
			local hasC = g.col ~= 0 and m.vc == true
			if #ch.T > 0 and (ch.hasN ~= hasN or ch.hasUV ~= hasUV or ch.hasC ~= hasC) then fl(ch); ch = newChunk() end
			ch.hasN, ch.hasUV, ch.hasC = hasN, hasUV, hasC
			local vmap: { [number]: number } = {}
			local sides = if m.ds then 2 else 1
			for t = en.start, en.start + en.count - 3, 3 do
				if #ch.P > MAXV - 3 or #ch.T / 3 > MAXT - 2 then fl(ch); ch = newChunk(); ch.hasN, ch.hasUV, ch.hasC = hasN, hasUV, hasC; vmap = {} end
				local tri = table.create(3)
				for k = 0, 2 do
					local vi = if g.i32 then buffer.readu32(buf, g.idx + (t + k) * 4) else buffer.readu16(buf, g.idx + (t + k) * 2)
					local id: number = vmap[vi] or 0
					if id == 0 then
						local po = g.pos + vi * 6
						local lx = g.lo.X + buffer.readu16(buf, po) / 65535 * g.ext.X
						local ly = g.lo.Y + buffer.readu16(buf, po + 2) / 65535 * g.ext.Y
						local lz = g.lo.Z + buffer.readu16(buf, po + 4) / 65535 * g.ext.Z
						table.insert(ch.P, Vector3.new(e[1] * lx + e[4] * ly + e[7] * lz + e[10], e[2] * lx + e[5] * ly + e[8] * lz + e[11], e[3] * lx + e[6] * ly + e[9] * lz + e[12]) * U)
						id = #ch.P
						if hasN then
							local no = g.nrm + vi * 3
							local nx, ny, nz = buffer.readi8(buf, no) / 127, buffer.readi8(buf, no + 1) / 127, buffer.readi8(buf, no + 2) / 127
							local wn = Vector3.new(e[1] * nx + e[4] * ny + e[7] * nz, e[2] * nx + e[5] * ny + e[8] * nz, e[3] * nx + e[6] * ny + e[9] * nz)
							ch.N[id] = if wn.Magnitude > 1e-6 then wn.Unit else Vector3.yAxis
						end
						if hasUV then
							local uo = g.uv + vi * 4
							local u = buffer.readi16(buf, uo) / 2048 * rep[1] + off[1]
							local v = buffer.readi16(buf, uo + 2) / 2048 * rep[2] + off[2]
							ch.UV[id] = Vector2.new(u, 1 - v)
						end
						if hasC then
							local co = g.col + vi * 3
							ch.C[id] = mulC(Color3.fromRGB(buffer.readu8(buf, co), buffer.readu8(buf, co + 1), buffer.readu8(buf, co + 2)), en.inst)
						end
						vmap[vi] = id
						work += 1
					end
					tri[k + 1] = id
				end
				local T = ch.T
				if en.flip then tri[2], tri[3] = tri[3], tri[2] end
				table.insert(T, tri[1]); table.insert(T, tri[2]); table.insert(T, tri[3])
				if sides == 2 then   -- matériau double face : on ajoute le revers (normales inversées)
					local ids = table.create(3)
					for k, id in ipairs({ tri[1], tri[3], tri[2] }) do
						table.insert(ch.P, ch.P[id]); local nid = #ch.P
						if hasN then ch.N[nid] = -(ch.N[id] :: Vector3) end
						if hasUV then ch.UV[nid] = ch.UV[id] end
						if hasC then ch.C[nid] = ch.C[id] end
						ids[k] = nid
					end
					table.insert(T, ids[1]); table.insert(T, ids[2]); table.insert(T, ids[3])
				end
				if work > 2500 then work = 0; task.wait() end
			end
		end
		fl(ch)
		task.wait()
	end
	if not api.mesh and b.alive then      -- l'API a été refusée en cours de route : on termine en blocs simples
		for _, c in ipairs((b.details :: Folder):GetChildren()) do if c.Name == "Detail" then c:Destroy() end end
		for i = 0, ninst - 1 do
			local r = o + i * 56
			local g = geos[buffer.readu16(buf, r) + 1]
			local ml = matlists[buffer.readu16(buf, r + 2) + 1]
			local m0 = mats[ml[1] + 1]
			local e = table.create(12)
			for k = 0, 11 do e[k + 1] = buffer.readf32(buf, r + 8 + k * 4) end
			if m0 and (not m0.cut or MapScene.hdMaterial(m0)) then fallbackPart(b, g, e, MapScene.color(m0.avg), m0) end
			if i % 200 == 199 then task.wait() end
		end
	end
end

-- ---------- halos des lampes (sprites additifs du web) ----------
function MapDress.buildGlows(b: Build, info: any)
	local img = glow()
	if not img or #info.glows == 0 then return end
	local anchor = Instance.new("Part")
	anchor.Name = "Halos"; anchor.Anchored = true; anchor.CanCollide = false; anchor.CanQuery = false; anchor.CanTouch = false
	anchor.Transparency = 1; anchor.Size = Vector3.new(0.2, 0.2, 0.2); anchor.CFrame = CFrame.new(b.origin)
	anchor.Parent = b.details
	for _, gl in ipairs(info.glows) do
		local at = Instance.new("Attachment")
		at.Position = Vector3.new(gl.p[1], gl.p[2], gl.p[3]) * U
		at.Parent = anchor
		local bg = Instance.new("BillboardGui")
		local s = gl.s * U
		bg.Size = UDim2.fromScale(s, s); bg.LightInfluence = 0; bg.Brightness = 1.6; bg.MaxDistance = 450; bg.Adornee = at
		local il = Instance.new("ImageLabel")
		il.Size = UDim2.fromScale(1, 1); il.BackgroundTransparency = 1; il.ImageContent = img
		il.ImageColor3 = MapScene.color(gl.c); il.ImageTransparency = 1 - math.clamp(gl.o, 0, 1) * 0.8
		il.Parent = bg
		bg.Parent = at
	end
end

-- ---------- ciel : dégradé du web (th.sky : t = 0 zénith, 0,5 horizon, 1 nadir) ----------
local function hexColor(s: string): Color3
	local n = tonumber(string.sub(s, 2), 16) or 0
	return Color3.fromRGB(bit32.rshift(n, 16), bit32.band(bit32.rshift(n, 8), 255), bit32.band(n, 255))
end
local function skyAt(stops: { any }, t: number): Color3
	local prev = stops[1]
	if t <= prev[1] then return hexColor(prev[2]) end
	for i = 2, #stops do
		local s = stops[i]
		if t <= s[1] then return hexColor(prev[2]):Lerp(hexColor(s[2]), (t - prev[1]) / math.max(1e-6, s[1] - prev[1])) end
		prev = s
	end
	return hexColor(prev[2])
end

local skyCache: { [string]: { side: Content, up: Content, dn: Content } | false } = {}
function MapDress.skyImages(id: string, stops: { any }): { side: Content, up: Content, dn: Content }?
	local c = skyCache[id]
	if c ~= nil then return if c then c :: any else nil end
	local S = 64
	local function face(kind: string): Content?
		return newImage("sky:" .. id .. ":" .. kind, S, S, function()
			local buf = buffer.create(S * S * 4)
			for y = 0, S - 1 do for x = 0, S - 1 do
				local u, v = (x + 0.5) / S * 2 - 1, (y + 0.5) / S * 2 - 1
				local el
				if kind == "side" then el = math.atan2(-v, math.sqrt(u * u + 1))
				elseif kind == "up" then el = math.atan2(1, math.sqrt(u * u + v * v))
				else el = -math.atan2(1, math.sqrt(u * u + v * v)) end
				local col = skyAt(stops, 0.5 - el / math.pi)
				local o = (y * S + x) * 4
				buffer.writeu8(buf, o, col.R * 255); buffer.writeu8(buf, o + 1, col.G * 255); buffer.writeu8(buf, o + 2, col.B * 255); buffer.writeu8(buf, o + 3, 255)
			end end
			return buf
		end)
	end
	local side, up, dn = face("side"), face("up"), face("dn")
	local r: any = if side and up and dn then { side = side, up = up, dn = dn } else false
	skyCache[id] = r
	return if r then r else nil
end

-- envoi depuis Studio : toutes les images de la carte qui ne dépendent pas des blocs construits par le serveur
function MapDress.prebuildImages(id: string)
	local info = MapScene.info(id)
	if not info then return end
	for _, m in ipairs(info.mats) do
		if m.tex then texImage(m.tex) end
		if m.det then detailImage(m.det.tex, m.det.str) end
	end
	white(); glow()
	for _, name in ipairs(MapDress.DECALS) do MapDress.decal(name) end
	if info.theme and info.theme.sky then MapDress.skyImages(id, info.theme.sky) end
end

return MapDress
