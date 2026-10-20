--!strict
-- ReplicatedStorage/Shared/SkinPaint (ModuleScript, côté client)
-- Peint les armes avec les skins du jeu web : les mêmes peintures (exportées par tools/export_skins.js dans SkinTextures)
-- posées en texture sur les pièces de l'arme (EditableImage), avec la finition du skin (mat, brillant, chrome…).
-- Les camos animés (exclusifs Robux) sont recalculés en direct, comme sur le web (src/44b_animcamo.js).
-- Comme pour les armes 3D, il faut « Allow Mesh / Image APIs » ; sinon l'arme prend la couleur moyenne du skin.
--
-- Rendu (comme le MeshStandardMaterial du web, src/45_models.js gunMats + src/44d_skinhq.js) :
--   * arme dans le monde (vue à la 1re personne, 3e personne, killcam) : SurfaceAppearance = peinture + carte de métal
--     (metalness de la finition, acier nu dans les éclats d'usure) + carte de rugosité propre au skin (vernis, usure,
--     rayures : skinRough du web) + carte de normales des skins gravés (relief HQH du web) + masque lumineux des skins néon
--     et des camos animés (émission du web) ; pièces secondaires teintées #8c8c8c comme M.acc ;
--   * aperçus (ViewportFrame : pas de reflets de l'environnement, le métal y paraîtrait noir) et repli sans SurfaceAppearance :
--     peinture posée en TextureContent, SmoothPlastic + reflet selon la finition.
--   * peinture 512 px « sk3:<motif> » et ses cartes « #r » « #m » « #n » « #g » (ServerStorage/SkinTexturesHQ, envoyées par
--     MeshUploader) dès qu'elles sont envoyées, sinon la 256 px « sk2: » d'un ancien envoi, sinon la 128 px « sk:<motif> »
--     de SkinTextures avec les cartes de la finition ; pièces simples (lame du couteau, arme en blocs) : Texture sur les faces,
--     avec les mêmes cartes dans le monde.
--   * camos de maîtrise (Or, Diamant, Matière noire) : cartes 512 px dessinées ici et envoyées (« mc:<camo> »), effet animé
--     léger par le masque lumineux ; tant qu'elles ne sont pas envoyées, dessin en direct comme les camos animés.
--
-- SkinPaint.apply(model, skinIndex, camoId?) : skinIndex suit Config.SKINS (1 = Défaut), camoId = clé de SkinInfo.ANIM.
local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Info = require(ReplicatedStorage.Shared.SkinInfo)
local decode = require(ReplicatedStorage.Shared.Base64)
local MeshStore = require(ReplicatedStorage.Shared.MeshStore)
local Mastery = require(ReplicatedStorage.Shared.Mastery)
-- camos de maîtrise (Or, Diamant, Matière noire) : dessinés ici comme les camos animés (et en cartes 512 px, voir MASTER)
for id, c in pairs(Mastery.CAMOS) do (Info.ANIM :: any)[id] = c end

local SkinPaint = {}
SkinPaint.imageApi = true

local DARK = 0.55                  -- pièces secondaires : peinture assombrie (teinte #8c8c8c du web)
-- finition -> reflet (SmoothPlastic pour que la peinture reste lisible), quand la SurfaceAppearance n'est pas utilisée
local REFLECT = { matte = 0, paint = 0.02, gloss = 0.08, anod = 0.14, pearl = 0.18, chrome = 0.26 }
-- finitions du web (FIN, src/44_skins.js) : m = metalness, r = roughness
local FIN: { [string]: { m: number, r: number } } = {
	matte = { m = 0.5, r = 0.55 }, gloss = { m = 0.65, r = 0.24 }, chrome = { m = 1, r = 0.12 },
	anod = { m = 0.9, r = 0.3 }, pearl = { m = 0.85, r = 0.16 }, paint = { m = 0.3, r = 0.42 },
}
-- émission des skins lumineux du web (ge = couleur, ei = intensité) ; camos animés : leur propre image, blanc
local GLOW: { [string]: { number } } = {
	neonlines = { 0x35d6ff, 1.1 }, galaxy = { 0xffffff, 0.9 }, toxic = { 0x6dff2e, 1 }, circuit = { 0x28f0ff, 1.2 },
	lava = { 0xff7a1a, 1.4 }, matrix = { 0x45ff7a, 1.1 }, pixel8 = { 0xffffff, 0.7 },
	hw_pumpkin = { 0xffb040, 1.2 }, hw_ecto = { 0x6dff6a, 1.1 }, hw_witch = { 0xffc070, 1 },
}
local ANIM_EI: { [string]: number } = { plasma = 0.55, magma = 0.9, code = 0.8, nebula = 0.6, prism = 0.35, storm = 1,
	m_gold = 0.3, m_diamond = 0.45, m_dark = 0.85 }
local TINT = Color3.fromRGB(140, 140, 140)  -- web : M.acc color #8c8c8c
-- taille d'une répétition de la peinture, en mètres d'arme (web : 0,78 / 1,35) ; × échelle du modèle pour les Texture
local TILE = 0.78 / 1.35

-- sans EditableImage : couleur vive du camo animé
local ANIM_FALLBACK: { [string]: Color3 } = {
	plasma = Color3.fromRGB(138, 59, 255), magma = Color3.fromRGB(255, 90, 26), code = Color3.fromRGB(42, 255, 122),
	nebula = Color3.fromRGB(74, 58, 255), prism = Color3.fromRGB(255, 106, 213), storm = Color3.fromRGB(74, 184, 255),
	m_gold = Color3.fromRGB(240, 180, 50), m_diamond = Color3.fromRGB(160, 225, 255), m_dark = Color3.fromRGB(120, 50, 200),
}

local function hex(s: string?): Color3?
	if not s then return nil end
	local n = tonumber(string.sub(s, 2), 16)
	return n and Color3.fromRGB(bit32.rshift(n, 16), bit32.band(bit32.rshift(n, 8), 255), bit32.band(n, 255))
end

-- ---------- peintures fixes ----------
type Paint = { img: Content?, avg: Color3 }
local paints: { [string]: Paint } = {}

local function paint(tex: string, dark: boolean): Paint?
	local id = tex .. (if dark then "#d" else "")
	if paints[id] then return paints[id] end
	local folder = ReplicatedStorage.Shared:FindFirstChild("SkinTextures")
	local src = folder and folder:FindFirstChild(tex)
	if not src then return nil end
	local data = require(src :: ModuleScript) :: any
	local pal, px = decode(data.pal), decode(data.px)
	local size = data.size :: number
	local out = buffer.create(size * size * 4)
	local k = if dark then DARK else 1
	local sr, sg, sb = 0, 0, 0
	for i = 0, size * size - 1 do
		local c = buffer.readu8(px, i) * 3
		local r, g, b = buffer.readu8(pal, c) * k, buffer.readu8(pal, c + 1) * k, buffer.readu8(pal, c + 2) * k
		buffer.writeu8(out, i * 4, r); buffer.writeu8(out, i * 4 + 1, g); buffer.writeu8(out, i * 4 + 2, b); buffer.writeu8(out, i * 4 + 3, 255)
		sr += r; sg += g; sb += b
	end
	local n = size * size
	local p: Paint = { img = nil, avg = Color3.fromRGB(sr / n, sg / n, sb / n) }
	do
		local ok, img = pcall(function()
			return (MeshStore.image("sk:" .. id, function(): EditableImage?
				if not SkinPaint.imageApi then return nil end
				local e = AssetService:CreateEditableImage({ Size = Vector2.new(size, size) })
				e:WritePixelsBuffer(Vector2.zero, Vector2.new(size, size), out)
				return e
			end))
		end)
		if ok then p.img = img else
			SkinPaint.imageApi = false
			warn("[SkinPaint] EditableImage indisponible : coche Game Settings → Security → « Allow Mesh / Image APIs ». Skins en couleur unie en attendant.")
		end
	end
	paints[id] = p
	return p
end
SkinPaint.paint = paint

-- ---------- camos animés (port de ANIM_DRAW, src/44b_animcamo.js) ----------
local AS = 64                       -- 64 × 64 pixels recalculés 30 fois par seconde, comme acPix() du web
local P2 = math.pi * 2
local sin, cos, abs, max, min, floor, sqrt = math.sin, math.cos, math.abs, math.max, math.min, math.floor, math.sqrt

local function hsl(h: number, s: number, l: number): (number, number, number)
	h = h % 1
	local a = s * min(l, 1 - l)
	local function f(n: number): number
		local k = (n + h * 12) % 12
		return 255 * (l - a * max(-1, min(k - 3, 9 - k, 1)))
	end
	return f(0), f(8), f(4)
end

-- petit générateur pseudo-aléatoire déterministe (comme mkRng du web)
local function rng(seed: number): (number?, number?) -> number
	local s = seed
	return function(a: number?, b: number?): number
		s = (s * 1103515245 + 12345) % 2147483648
		local v = s / 2147483648
		if a == nil then return v end
		return (a :: number) + v * ((b :: number) - (a :: number))
	end
end

type Pix = (u: number, v: number, t: number) -> (number, number, number)
local PIX: { [string]: Pix } = {
	plasma = function(u, v, t)
		local s = sin(P2 * u + t) + sin(P2 * 2 * v - t * 1.3) + sin(P2 * (u + v) + t * 0.7) + sin(P2 * (u - v) * 2 + t * 0.4)
		return hsl(0.72 + s * 0.09 + t * 0.03, 0.95, 0.32 + 0.18 * sin(s * 1.7 + t))
	end,
	magma = function(u, v, t)
		local f = abs(sin(P2 * 2 * u + sin(P2 * v + t * 0.6) * 1.6 + sin(P2 * 2 * v - t * 0.35) * 0.8))
		local g = abs(sin(P2 * 3 * v + sin(P2 * 2 * u - t * 0.5) * 1.2))
		local crack = max(0, 1 - min(f, g) * 5.5)
		local k = crack * (0.75 + 0.25 * sin(t * 2.2 + u * P2))
		return 40 + 215 * k, 14 + 170 * k * k, 10 + 60 * k * k * k
	end,
	nebula = function(u, v, t)
		local s = sin(P2 * u + sin(P2 * v + t * 0.25) * 2) + sin(P2 * 2 * v + cos(P2 * u - t * 0.2) * 1.5)
		local k = max(0, s * 0.35 + 0.25)
		return hsl(0.64 + s * 0.1 + sin(t * 0.15) * 0.06, 0.85, 0.05 + k * 0.42)
	end,
	prism = function(u, v, t)
		local d = u + v
		local band = 0.5 + 0.5 * sin(P2 * 6 * d - t * 4)
		return hsl(d * 0.5 + t * 0.12, 0.9, 0.5 + band * 0.22)
	end,
	-- maîtrise : or brossé avec un reflet qui passe lentement
	m_gold = function(u, v, t)
		local brush = 0.5 + 0.5 * sin(P2 * v * 9 + sin(P2 * u * 2) * 0.8)
		local band = max(0, sin(P2 * (u * 0.8 + v * 0.6) - t * 1.6)) ^ 8
		local k = 0.76 + 0.14 * brush
		return 235 * k + 200 * band, 172 * k + 190 * band, 56 * k + 170 * band
	end,
	-- maîtrise : facettes de diamant (triangles) qui scintillent chacune à leur tour
	m_diamond = function(u, v, t)
		local x, y = u * 6, v * 6
		local cx, cy = floor(x), floor(y)
		local tri = if x - cx > y - cy then 1 else 0
		local h = ((cx * 7385 + cy * 1934 + tri * 8349) % 997) / 997
		local l = 0.55 + 0.22 * h + 0.12 * (0.5 + 0.5 * sin(t * 1.8 + h * P2))
		local spark = max(0, sin(t * 3 + h * 40)) ^ 30
		return hsl(0.53 + h * 0.06, 0.6, min(0.95, l + spark * 0.4))
	end,
	-- maîtrise : matière noire, nuit violette parcourue de veines lumineuses
	m_dark = function(u, v, t)
		local s = sin(P2 * u * 2 + sin(P2 * v * 3 + t * 0.5) * 1.5) + sin(P2 * v * 2 - t * 0.4 + cos(P2 * u * 3) * 1.2)
		local vein = max(0, 1 - abs(s) * 3.2)
		return hsl(0.76 + s * 0.04 + t * 0.02, 0.9, 0.06 + 0.05 * sin(P2 * (u + v) + t * 0.3) + vein * 0.45)
	end,
}

local function put(buf: buffer, x: number, y: number, r: number, g: number, b: number, a: number)
	x = floor(x) % AS; y = floor(y) % AS
	local i = (y * AS + x) * 4
	local ia = 1 - a
	buffer.writeu8(buf, i, min(255, buffer.readu8(buf, i) * ia + r * a))
	buffer.writeu8(buf, i + 1, min(255, buffer.readu8(buf, i + 1) * ia + g * a))
	buffer.writeu8(buf, i + 2, min(255, buffer.readu8(buf, i + 2) * ia + b * a))
end
local function fill(buf: buffer, r: number, g: number, b: number)
	for i = 0, AS * AS - 1 do
		buffer.writeu8(buf, i * 4, r); buffer.writeu8(buf, i * 4 + 1, g); buffer.writeu8(buf, i * 4 + 2, b); buffer.writeu8(buf, i * 4 + 3, 255)
	end
end
local function line(buf: buffer, x0: number, y0: number, x1: number, y1: number, w: number, r: number, g: number, b: number, a: number)
	local n = math.max(1, math.ceil(math.max(abs(x1 - x0), abs(y1 - y0))))
	for s = 0, n do
		local x, y = x0 + (x1 - x0) * s / n, y0 + (y1 - y0) * s / n
		for dx = -w, w do for dy = -w, w do put(buf, x + dx, y + dy, r, g, b, a) end end
	end
end

-- motifs dessinés (pluie de code, éclairs) : version « pixels » des dessins du web
local DRAW: { [string]: (buf: buffer, t: number) -> () } = {
	code = function(buf, t)
		fill(buf, 2, 18, 9)
		local r = rng(31)
		for x = 2, AS - 1, 4 do
			local sp, len, off = r(9, 23), floor(r(6, 14)), r(0, AS)
			local y0 = (t * sp + off) % AS
			for k = 0, len - 1 do
				local y = (y0 - k * 5) % AS
				local a = 1 - k / len
				local glyph = floor(t * 6 + x * 0.37 + k * 1.7)
				for gx = 0, 2 do for gy = 0, 3 do
					if bit32.band(bit32.rshift(glyph * 2654435761 % 4294967296, gx * 4 + gy), 1) == 1 then
						if k == 0 then put(buf, x + gx - 1, y + gy, 230, 255, 240, 1) else put(buf, x + gx - 1, y + gy, 60, 230, 120, a * 0.9) end
					end
				end end
			end
		end
	end,
	storm = function(buf, t)
		fill(buf, 10, 15, 26)
		for y = 0, AS - 1, 4 do for x = 0, AS - 1 do if (x + y) % 2 == 0 and y % 8 == 0 then put(buf, x, y + (if (x // 4) % 2 == 1 then 2 else 0), 60, 90, 140, 0.35) end end end
		local r = rng(1000 + floor(t * 7))
		for _ = 1, 4 do
			local x, y = r(0, AS), r(0, AS)
			for _ = 1, 7 do
				local nx, ny = x + r(-9, 9), y + r(3, 9)
				line(buf, x, y, nx, ny, 1, 60, 170, 255, 0.35)
				line(buf, x, y, nx, ny, 0, 200, 242, 255, 1)
				x, y = nx, ny
			end
		end
		local fl = 0.12 + 0.12 * max(0, sin(t * 9))
		for i = 0, AS * AS - 1 do put(buf, i % AS, i // AS, 120, 200, 255, fl) end
	end,
}
local STARS: { { number } } = {}
-- web : 70 étoiles sur 128 × 128 ; ici 64 × 64, donc 4 fois moins de place
do local r = rng(77); for i = 1, 18 do STARS[i] = { r(0, AS), r(0, AS), r(0, P2), r(1.5, 4) } end end

-- dark : la version assombrie (pièces secondaires) n'est recalculée que si une pièce l'utilise sans teinte possible
type Live = { img: EditableImage, dimg: EditableImage, buf: buffer, dbuf: buffer, users: { [Instance]: boolean }, dark: boolean }
local live: { [string]: Live } = {}

local function render(id: string, L: Live, t: number)
	local buf = L.buf
	local fn = PIX[id]
	if fn then
		for y = 0, AS - 1 do
			for x = 0, AS - 1 do
				local r, g, b = fn(x / AS, y / AS, t)
				local i = (y * AS + x) * 4
				buffer.writeu8(buf, i, max(0, min(255, r))); buffer.writeu8(buf, i + 1, max(0, min(255, g))); buffer.writeu8(buf, i + 2, max(0, min(255, b)))
				buffer.writeu8(buf, i + 3, 255)
			end
		end
		if id == "nebula" then
			for _, s in ipairs(STARS) do put(buf, s[1], s[2], 255, 255, 255, 0.35 + 0.65 * max(0, sin(t * s[4] + s[3]))) end
		end
	elseif DRAW[id] then
		DRAW[id](buf, t)
	end
	L.img:WritePixelsBuffer(Vector2.zero, Vector2.new(AS, AS), buf)
	if L.dark then
		for i = 0, AS * AS * 4 - 1 do buffer.writeu8(L.dbuf, i, if i % 4 == 3 then 255 else buffer.readu8(buf, i) * DARK) end
		L.dimg:WritePixelsBuffer(Vector2.zero, Vector2.new(AS, AS), L.dbuf)
	end
end

local function animImage(id: string): Live?
	if live[id] then return live[id] end
	if not SkinPaint.imageApi or not (PIX[id] or DRAW[id]) then return nil end
	local ok, L = pcall(function()
		local size = Vector2.new(AS, AS)
		return { img = AssetService:CreateEditableImage({ Size = size }), dimg = AssetService:CreateEditableImage({ Size = size }),
			buf = buffer.create(AS * AS * 4), dbuf = buffer.create(AS * AS * 4), users = setmetatable({}, { __mode = "k" }) :: any, dark = false }
	end)
	if not ok then SkinPaint.imageApi = false; return nil end
	render(id, L, os.clock())
	live[id] = L
	return L
end

-- un seul camo de chaque sorte est recalculé, et seulement tant qu'une arme le porte (web : ~30 images par seconde)
local acc = 0
RunService.Heartbeat:Connect(function(dt: number)
	acc += dt
	if acc < 1 / 30 then return end
	acc = 0
	local t = os.clock()
	for id, L in pairs(live) do
		local used = false
		for part in pairs(L.users) do if part.Parent then used = true; break end end
		if used then render(id, L, t) end
	end
end)


-- ---------- bruit sans couture (hqHash, vnoise, fbm, voro du web) ----------
-- multiplication 32 bits exacte (Math.imul du web) : en nombres flottants, x × 1274126177 perdrait les bits du bas
local function imul(a: number, b: number): number
	local al, ah = a % 65536, (a // 65536) % 65536
	local bl, bh = b % 65536, (b // 65536) % 65536
	return ((ah * bl + al * bh) % 65536 * 65536 + al * bl) % 4294967296
end
local bxor, brshift = bit32.bxor, bit32.rshift
local function hash(x: number, y: number, s: number): number
	local h = (imul(x % 4294967296, 374761393) + imul(y % 4294967296, 668265263) + imul((s + 1) % 4294967296, 1442695041)) % 4294967296
	h = imul(bxor(h, brshift(h, 13)), 1274126177)
	return bxor(h, brshift(h, 16)) / 4294967296
end
-- valeurs du hachage sur une grille Pu × Pv (calculées une fois : les cartes 512 px en demandent des millions)
local latCache: { [number]: { number } } = {}
local function lattice(Pu: number, Pv: number, s: number): { number }
	local key = (s * 4096 + Pu) * 4096 + Pv
	local t = latCache[key]
	if t then return t end
	local nt: { number } = table.create(Pu * Pv)
	for y = 0, Pv - 1 do for x = 0, Pu - 1 do nt[y * Pu + x + 1] = hash(x, y, s) end end
	latCache[key] = nt
	return nt
end
-- bruit de valeur sans couture (période Pu × Pv cellules), comme vnoise/fbm du web ; Pu ≠ Pv donne des stries (brossage)
local function vnoise2(u: number, v: number, Pu: number, Pv: number, s: number): number
	local x, y = u * Pu, v * Pv
	local ix, iy = floor(x), floor(y)
	local fx, fy = x - ix, y - iy
	local x0, y0 = ix % Pu, iy % Pv
	local x1, y1 = (x0 + 1) % Pu, (y0 + 1) % Pv
	local t = lattice(Pu, Pv, s)
	local a, b, c, d = t[y0 * Pu + x0 + 1], t[y0 * Pu + x1 + 1], t[y1 * Pu + x0 + 1], t[y1 * Pu + x1 + 1]
	local sx, sy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
	return a + (b - a) * sx + (c - a) * sy + (a - b - c + d) * sx * sy
end
local function fbm2(u: number, v: number, Pu: number, Pv: number, oct: number, s: number): number
	local t, amp, n = 0, 0.5, 0
	for i = 0, oct - 1 do t += amp * vnoise2(u, v, Pu, Pv, s + i * 31); n += amp; amp *= 0.5; Pu *= 2; Pv *= 2 end
	return t / n
end
local function fbm(u: number, v: number, P: number, oct: number, s: number): number
	return fbm2(u, v, P, P, oct, s)
end
-- fbm « tourbillonnée » (domaine déformé) : nébuleuses
local function warp(u: number, v: number, P: number, oct: number, s: number, k: number): number
	local a, b = fbm(u, v, P, 3, s + 101), fbm(u, v, P, 3, s + 202)
	return fbm(u + (a - 0.5) * k, v + (b - 0.5) * k, P, oct, s)
end
-- voronoï sans couture : distance au 1er et au 2e point, numéro de la cellule, centre de la cellule
local function voro(u: number, v: number, N: number, s: number, j: number): (number, number, number, number, number)
	local x, y = u * N, v * N
	local ix, iy = floor(x), floor(y)
	local d1, d2, id, cx, cy = 9, 9, 0, 0, 0
	local jx, jy = lattice(N, N, s), lattice(N, N, s + 7)
	for oy = -1, 1 do
		for ox = -1, 1 do
			local gx, gy = ix + ox, iy + oy
			local wx, wy = gx % N, gy % N
			local px, py = gx + 0.5 + (jx[wy * N + wx + 1] - 0.5) * j, gy + 0.5 + (jy[wy * N + wx + 1] - 0.5) * j
			local d = sqrt((px - x) ^ 2 + (py - y) ^ 2)
			if d < d1 then d2 = d1; d1 = d; id = wy * N + wx; cx = px; cy = py elseif d < d2 then d2 = d end
		end
	end
	return d1, d2, id, cx / N, cy / N
end
local function sstep(a: number, b: number, x: number): number
	local t = max(0, min(1, (x - a) / (b - a)))
	return t * t * (3 - 2 * t)
end
local function clamp8(x: number): number
	return max(0, min(255, floor(x + 0.5)))
end

-- ---------- images haute qualité (envoyées) : peintures 512 px, rugosité, métal, relief, masques lumineux ----------
-- Côté joueur, seulement si MeshUploader les a envoyées (clés « i:sk3:… » dans MeshAssets) ; les données restent dans
-- ServerStorage/SkinTexturesHQ (tools/skins_hq_to_lua.py), que seul l'envoi depuis Studio lit et décompresse.
local inflateFn: any = nil
local function inflate(b: buffer, n: number): buffer
	if not inflateFn then
		local m = ServerStorage:FindFirstChild("SkinInflate")
		if not m then error("ServerStorage/SkinInflate manquant") end
		inflateFn = (require :: any)(m)
	end
	return inflateFn(b, n)
end

-- plan prédit (MED, comme JPEG-LS) : valeur = prédiction (gauche a, haut b, haut-gauche c) + reste modulo 256 ;
-- renvoie les valeurs quantifiées (à multiplier par le pas)
local readu8, writeu8 = buffer.readu8, buffer.writeu8
local function unmed(raw: buffer, off: number, n: number): buffer
	local q = buffer.create(n * n)
	local a = 0
	for x = 0, n - 1 do a = (a + readu8(raw, off + x)) % 256; writeu8(q, x, a) end   -- 1re ligne : prédiction = gauche
	for y = 1, n - 1 do
		local row = y * n
		local c = readu8(q, row - n)
		a = (c + readu8(raw, off + row)) % 256                                      -- 1re colonne : prédiction = haut
		writeu8(q, row, a)
		for x = 1, n - 1 do
			local b = readu8(q, row - n + x)
			local p
			if a > b then p = if c >= a then b elseif c <= b then a else a + b - c
			else p = if c >= b then a elseif c <= a then b else a + b - c end
			a = (p + readu8(raw, off + row + x)) % 256
			writeu8(q, row + x, a)
			c = b
		end
	end
	return q
end

-- pixels RGBA d'une image de SkinTexturesHQ (formats de tools/skins_hq_to_lua.py)
local function hqPixels(data: any): (buffer, number)
	local N = data.size :: number
	local kind = data.kind :: string
	local st = data.step :: number
	local nPl = if kind == "ycc" then N * N * 3 // 2 elseif kind == "rgb" then N * N * 3 else N * N
	local raw = inflate(decode(data.z), nPl)
	local out = buffer.create(N * N * 4)
	if kind == "ycc" then
		-- YCoCg : luminance pleine taille, couleur en demi-taille (lissée), puis le grain du web (hqFinish) recalculé
		local h = N // 2
		local Y = unmed(raw, 0, N)
		local cs = data.cstep or 2
		local Co, Cg = unmed(raw, N * N, h), unmed(raw, N * N + h * h, h)
		-- couleur lissée (bilinéaire, bords bouclés comme la peinture qui se répète) : pixel x -> x / 2 - 0,25 en demi-taille
		local XA, XB, TX = table.create(N), table.create(N), table.create(N)
		for x = 0, N - 1 do
			local f = x / 2 - 0.25
			local x0 = floor(f)
			XA[x + 1], XB[x + 1], TX[x + 1] = x0 % h, (x0 + 1) % h, f - x0
		end
		local gx: number? = data.seed
		local bxor, lshift, rshift, band = bit32.bxor, bit32.lshift, bit32.rshift, bit32.band
		for y = 0, N - 1 do
			local ra, rb, ty = (XA[y + 1]) * h, (XB[y + 1]) * h, TX[y + 1]
			for x = 0, N - 1 do
				local xa, xb, tx = XA[x + 1], XB[x + 1], TX[x + 1]
				local w00, w01, w10, w11 = (1 - tx) * (1 - ty), tx * (1 - ty), (1 - tx) * ty, tx * ty
				local co = (readu8(Co, ra + xa) * w00 + readu8(Co, ra + xb) * w01 + readu8(Co, rb + xa) * w10 + readu8(Co, rb + xb) * w11) * cs - 128
				local cg = (readu8(Cg, ra + xa) * w00 + readu8(Cg, ra + xb) * w01 + readu8(Cg, rb + xa) * w10 + readu8(Cg, rb + xb) * w11) * cs - 128
				local yy = readu8(Y, y * N + x) * st
				local t = yy - cg
				local r, g, b = t + co, yy + cg, t - co
				if gx then
					local s = gx :: number
					s = bxor(s, lshift(s, 13)); s = bxor(s, rshift(s, 17)); s = bxor(s, lshift(s, 5))
					gx = s
					local gr = (band(s, 255) - 128) * 0.04
					r += gr; g += gr; b += gr
				end
				local i = (y * N + x) * 4
				writeu8(out, i, if r <= 0 then 0 elseif r >= 255 then 255 else floor(r + 0.5))
				writeu8(out, i + 1, if g <= 0 then 0 elseif g >= 255 then 255 else floor(g + 0.5))
				writeu8(out, i + 2, if b <= 0 then 0 elseif b >= 255 then 255 else floor(b + 0.5)); writeu8(out, i + 3, 255)
			end
		end
	elseif kind == "rgb" then
		local R, G, B = unmed(raw, 0, N), unmed(raw, N * N, N), unmed(raw, 2 * N * N, N)
		for i = 0, N * N - 1 do
			writeu8(out, i * 4, min(255, readu8(R, i) * st)); writeu8(out, i * 4 + 1, min(255, readu8(G, i) * st))
			writeu8(out, i * 4 + 2, min(255, readu8(B, i) * st)); writeu8(out, i * 4 + 3, 255)
		end
	else
		local L = unmed(raw, 0, N)
		for i = 0, N * N - 1 do
			local l = min(255, readu8(L, i) * st)
			writeu8(out, i * 4, l); writeu8(out, i * 4 + 1, l); writeu8(out, i * 4 + 2, l); writeu8(out, i * 4 + 3, 255)
		end
	end
	return out, N
end
SkinPaint.hqPixels = hqPixels

local function image(px: buffer, size: number): EditableImage
	local e = AssetService:CreateEditableImage({ Size = Vector2.new(size, size) })
	e:WritePixelsBuffer(Vector2.zero, Vector2.new(size, size), px)
	return e
end

local function hqFill(name: string): EditableImage?
	local folder = ServerStorage:FindFirstChild("SkinTexturesHQ")
	local src = folder and folder:FindFirstChild(name)
	if not src or not SkinPaint.imageApi then return nil end
	local px, size = hqPixels(require(src :: ModuleScript) :: any)
	return image(px, size)
end

-- image envoyée (clé « i:<key> » dans MeshAssets), sinon nil
local sent: { [string]: Content | false } = {}
local function art(key: string): Content?
	local c = sent[key]
	if c == nil then
		local id = MeshStore.ids["i:" .. key]
		local got: Content | false = false
		if id then got = Content.fromUri("rbxassetid://" .. id) end
		sent[key] = got
		c = got
	end
	return if c then c :: Content else nil
end
-- peinture d'un motif : 512 px « sk3 », sinon 256 px « sk2 » (anciens envois)
local function hqPaint(tex: string, suffix: string): Content?
	return art("sk3:" .. tex .. suffix) or art("sk2:" .. tex .. suffix)
end

-- ---------- camos de maîtrise : cartes 512 px dessinées ici, envoyées par MeshUploader (« i:mc:<camo>… ») ----------
-- Comme les camos de Call of Duty : vraie matière (métal, rugosité, relief) + effet animé léger par le masque lumineux.
--   col(u, v) -> r, g, b (0..255) ; nrm(u, v) -> normale (x, y, z) ; rough / metal (u, v) -> 0..1
type Master = { col: (number, number) -> (number, number, number), nrm: (number, number) -> (number, number, number),
	rough: (number, number) -> number, metal: (number, number) -> number, fx: string, tint: Color3, k: number }
local function ramp3(t: number, a: { number }, b: { number }, c: { number }): (number, number, number)
	t = max(0, min(1, t))
	if t < 0.5 then local k = t * 2; return a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k end
	local k = (t - 0.5) * 2
	return b[1] + (c[1] - b[1]) * k, b[2] + (c[2] - b[2]) * k, b[3] + (c[3] - b[3]) * k
end
local function norm3(x: number, y: number, z: number): (number, number, number)
	local l = sqrt(x * x + y * y + z * z)
	return x / l, y / l, z / l
end
-- normale tirée d'une hauteur (pente, comme autoNormal du web : y vers le haut de l'image)
local function slope(h: (number, number) -> number, str: number): (number, number) -> (number, number, number)
	local d = 1 / 256
	return function(u, v)
		local dx = (h(u + d, v) - h(u - d, v)) * str
		local dy = (h(u, v - d) - h(u, v + d)) * str
		return norm3(-dx, -dy, 1)
	end
end

-- Or : or massif brossé (stries fines le long de l'arme), reflets larges de polissage, quelques rayures de brossage
local GOLD_D, GOLD_M, GOLD_L = { 110, 66, 10 }, { 212, 156, 46 }, { 255, 230, 150 }
local function goldBrush(u: number, v: number): number
	return fbm2(u, v, 2, 160, 3, 501)
end
local function goldScratch(u: number, v: number): number
	local r = hash(floor(v * 512), 0, 507)
	return if r > 0.985 then 0.5 + 0.5 * vnoise2(u, v, 8, 1, 509) else 0
end
local function goldH(u: number, v: number): number
	return goldBrush(u, v) * 0.55 - goldScratch(u, v) * 0.35
end
-- Diamant : facettes taillées (voronoï), chacune inclinée à sa façon : elles renvoient la lumière tour à tour
local function facet(u: number, v: number): (number, number, number, number, number)
	local d1, d2, id, cx, cy = voro(u, v, 9, 601, 0.85)
	return d2 - d1, hash(id, 3, 607), hash(id, 5, 609), u - cx, v - cy
end
local MASTER: { [string]: Master } = {
	m_gold = {
		col = function(u, v)
			local br, big = goldBrush(u, v), fbm(u, v, 2, 3, 503)
			local r, g, b = ramp3(0.6 + (br - 0.5) * 0.4 + (big - 0.5) * 0.55, GOLD_D, GOLD_M, GOLD_L)
			local sc = goldScratch(u, v)
			return r + sc * 30, g + sc * 26, b + sc * 18
		end,
		nrm = slope(goldH, 1.2),
		rough = function(u, v) return 0.14 + 0.16 * goldBrush(u, v) + goldScratch(u, v) * 0.15 end,
		metal = function() return 1 end,
		fx = "m_gold:fx", tint = Color3.fromRGB(255, 214, 130), k = 0.35,
	},
	m_diamond = {
		col = function(u, v)
			local e, f, g, dx, dy = facet(u, v)
			local a = f * P2
			-- chaque facette : dégradé de taille (biseau), éclat propre, arêtes vives presque blanches
			local lit = 0.5 + 0.45 * f + 2.5 * (dx * cos(a) + dy * sin(a))
			local r, gg, b = 150 * lit + 40, 205 * lit + 30, 255 * min(1, lit + 0.15)
			if g > 0.86 then  -- « feu » du diamant : quelques facettes irisées
				local hr, hg, hb = hsl(g * 5, 0.8, 0.72)
				r, gg, b = r + (hr - r) * 0.35, gg + (hg - gg) * 0.35, b + (hb - b) * 0.35
			end
			local edge = sstep(0.06, 0, e)
			return r + (255 - r) * edge * 0.85, gg + (255 - gg) * edge * 0.85, b + (255 - b) * edge * 0.85
		end,
		nrm = function(u, v)
			local e, f, g = facet(u, v)
			local a, tilt = g * P2, 0.25 + 0.4 * f
			if e < 0.025 then return 0, 0, 1 end
			return norm3(cos(a) * tilt, sin(a) * tilt, 1)
		end,
		rough = function(u, v) local e = facet(u, v); return 0.03 + sstep(0.06, 0, e) * 0.25 end,
		metal = function() return 0.7 end,
		fx = "m_diamond:fx", tint = Color3.fromRGB(225, 245, 255), k = 0.9,
	},
	-- Matière noire : nuit violette profonde, nébuleuses, éclats d'étoiles, cristaux à peine visibles ; veines animées
	m_dark = {
		col = function(u, v)
			local n1, n2 = warp(u, v, 2, 4, 701, 1.2), warp(u, v, 3, 4, 709, 0.9)
			local r, g, b = 6, 3, 14
			local p = n1 ^ 3
			r += 120 * p * 1.2; g += 40 * p; b += 220 * p * 1.2
			local q = n2 ^ 4
			r += 30 * q * 0.8; g += 70 * q * 0.8; b += 255 * q * 0.8
			local m = max(0, n1 - n2 - 0.15) * 1.5
			r += 255 * m; g += 40 * m; b += 170 * m
			local vein = max(0, 1 - abs(sin((u + n1 * 1.4) * P2 * 2)) * 6)
			r += 200 * vein * 0.4; g += 140 * vein * 0.4; b += 255 * vein * 0.4
			local e, d2 = voro(u, v, 7, 713, 0.9)
			local edge = sstep(0.04, 0, d2 - e) * 0.12
			r += 120 * edge; g += 90 * edge; b += 200 * edge
			local sp = hash(floor(u * 512), floor(v * 512), 711)
			if sp > 0.994 then local k = (sp - 0.994) / 0.006; r += 230 * k; g += 200 * k; b += 255 * k end
			return r, g, b
		end,
		nrm = function(u, v)
			local _, _, id = voro(u, v, 7, 713, 0.9)
			local a, tilt = hash(id, 9, 715) * P2, 0.08 + 0.12 * hash(id, 11, 717)
			return norm3(cos(a) * tilt, sin(a) * tilt, 1)
		end,
		rough = function(u, v)
			return if hash(floor(u * 512), floor(v * 512), 711) > 0.994 then 0.05 else 0.2 + 0.08 * fbm(u, v, 8, 2, 719)
		end,
		metal = function() return 0.8 end,
		fx = "m_dark:fx", tint = Color3.fromRGB(175, 95, 255), k = 1.1,
	},
}
SkinPaint.MASTER = MASTER

-- effets animés des camos de maîtrise (masque lumineux 64 px, recalculé comme les camos animés)
PIX["m_gold:fx"] = function(u, v, t)
	local band = max(0, sin(P2 * (u * 0.8 + v * 0.6) - t * 1.6)) ^ 8
	local l = 255 * band * 0.9
	return l, l, l
end
PIX["m_dark:fx"] = function(u, v, t)
	local s = sin(P2 * u * 2 + sin(P2 * v * 3 + t * 0.5) * 1.5) + sin(P2 * v * 2 - t * 0.4 + cos(P2 * u * 3) * 1.2)
	local vein = max(0, 1 - abs(s) * 3.2)
	local l = 255 * min(1, vein ^ 1.5 * (0.8 + 0.2 * sin(t * 2.3 + u * P2)))
	return l, l, l
end
local SPARKS: { { number } } = {}
do local r = rng(613); for i = 1, 16 do SPARKS[i] = { r(0, AS), r(0, AS), r(0, P2), r(2.2, 4.2) } end end
DRAW["m_diamond:fx"] = function(buf, t)
	fill(buf, 0, 0, 0)
	for _, s in ipairs(SPARKS) do
		local k = max(0, sin(t * s[4] + s[3])) ^ 16
		if k > 0.02 then
			-- étoile à 4 branches qui s'allume et s'éteint
			for d = -4, 4 do
				local a = k * (1 - abs(d) / 5)
				put(buf, s[1] + d, s[2], 255, 255, 255, a); put(buf, s[1], s[2] + d, 255, 255, 255, a)
			end
		end
	end
end

-- carte d'un camo de maîtrise : "" couleur 512 px, "#n" normales, "#r" rugosité, "#m" métal (256 px)
local function masterFill(id: string, map: string): EditableImage?
	local M = MASTER[id]
	if not M or not SkinPaint.imageApi then return nil end
	local size = if map == "" then 512 else 256
	local out = buffer.create(size * size * 4)
	for y = 0, size - 1 do
		local v = y / size
		for x = 0, size - 1 do
			local u = x / size
			local r, g, b
			if map == "" then r, g, b = M.col(u, v)
			elseif map == "#n" then
				local nx, ny, nz = M.nrm(u, v)
				r, g, b = (nx * 0.5 + 0.5) * 255, (ny * 0.5 + 0.5) * 255, (nz * 0.5 + 0.5) * 255
			else
				local l = (if map == "#r" then M.rough(u, v) else M.metal(u, v)) * 255
				r, g, b = l, l, l
			end
			local i = (y * size + x) * 4
			writeu8(out, i, clamp8(r)); writeu8(out, i + 1, clamp8(g)); writeu8(out, i + 2, clamp8(b)); writeu8(out, i + 3, 255)
		end
	end
	return image(out, size)
end
SkinPaint.masterFill = masterFill

-- ---------- cartes de métal et de rugosité par finition (skins sans carte propre envoyée) ----------
-- rugosité du web (skinRough + 44d) : roughness = r × 1,5 (pièces secondaires r + 0,1) × carte 150..255 (bruit + usure)
local RS = 64                       -- carte de rugosité 64 × 64 (répétée comme la peinture)
local finCache: { [string]: Content | false } = {}
-- kind : "m" (métal, uni) | "r" (rugosité) | "ra" (rugosité des pièces secondaires)
local function finMap(fin: string, kind: string): Content?
	local id = fin .. ":" .. kind
	local c = finCache[id]
	if c ~= nil then return if c then c :: Content else nil end
	local f = FIN[fin] or FIN.gloss
	local ok, img = pcall(function()
		return (MeshStore.image("fin:" .. id, function(): EditableImage?
			if not SkinPaint.imageApi then return nil end
			local size = if kind == "m" then 8 else RS
			local out = buffer.create(size * size * 4)
			local R = min(1, (f.r + (if kind == "ra" then 0.1 else 0)) * 1.5)
			for y = 0, size - 1 do
				for x = 0, size - 1 do
					local l
					if kind == "m" then l = f.m * 255
					else
						local u, v = x / size, y / size
						local wear = sstep(0.6, 0.75, fbm(u, v, 3, 4, 17))
						l = R * min(255, 150 + fbm(u, v, 6, 4, 11) * 70 + wear * 35)
					end
					local i = (y * size + x) * 4
					buffer.writeu8(out, i, l); buffer.writeu8(out, i + 1, l); buffer.writeu8(out, i + 2, l); buffer.writeu8(out, i + 3, 255)
				end
			end
			return image(out, size)
		end))
	end)
	local res = if ok then img else nil
	finCache[id] = res or false
	return res
end

-- envoi depuis Studio (MeshUploader, mode Edit) : peintures 512 px et leurs cartes, camos de maîtrise, cartes des finitions.
-- Une image déjà envoyée n'est pas recalculée ; une image illisible est signalée et sautée (les autres partent quand même).
function SkinPaint.uploadAll()
	local function send(key: string, fill: () -> EditableImage?)
		if MeshStore.ids["i:" .. key] then return end
		local ok, err = pcall(function()
			local _, e = MeshStore.image(key, fill)
			if e then pcall(function() (e :: EditableImage):Destroy() end) end
		end)
		if not ok then warn("[SkinPaint] " .. key .. " : " .. tostring(err)) end
	end
	local folder = ServerStorage:FindFirstChild("SkinTexturesHQ")
	if folder then
		for _, m in ipairs(folder:GetChildren()) do
			send("sk3:" .. m.Name, function() return hqFill(m.Name) end)
		end
	end
	for id in pairs(MASTER) do
		for _, k in ipairs({ "", "#n", "#r", "#m" }) do send("mc:" .. id .. k, function() return masterFill(id, k) end) end
	end
	for fin in pairs(FIN) do for _, k in ipairs({ "m", "r", "ra" }) do finCache[fin .. ":" .. k] = nil; finMap(fin, k) end end
	table.clear(latCache)
end

-- ---------- application sur une arme ----------
local DEFAULT: { [Instance]: { Color3 | Enum.Material | number } } = setmetatable({}, { __mode = "k" }) :: any
local saOK = true                   -- passe à false si Roblox refuse la SurfaceAppearance créée par script
local tintOK = true                 -- passe à false si la teinte (SurfaceAppearance.Color) est refusée
local pending: { [Instance]: { any } } = setmetatable({}, { __mode = "k" }) :: any
local FACES = { Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Top, Enum.NormalId.Bottom }
local WHITE = Color3.new(1, 1, 1)

-- peinture d'une pièce (MeshPart) en SurfaceAppearance ; renvoie false si Roblox la refuse
-- maps : cartes propres au skin (n = normales, r = rugosité, m = métal) ; sinon cartes de la finition, sans relief
type Glow = { mask: Content, tint: Color3, k: number }
type Maps = { n: Content?, r: Content?, m: Content? }
type Look = { color: Content, dark: Content?, fin: string, secondary: boolean, glow: Glow?, maps: Maps? }
local function pbr(o: Look): (Content?, Content?, Content?)
	local mp = o.maps
	local m = (mp and mp.m) or finMap(o.fin, "m")
	local r = (mp and mp.r) or finMap(o.fin, if o.secondary then "ra" else "r")
	return m, r, mp and mp.n
end
local function surface(mesh: MeshPart, o: Look): boolean
	local ok = pcall(function()
		local sa = Instance.new("SurfaceAppearance")
		sa.Name = "SkinSA"
		sa.ColorMapContent = o.color
		if o.secondary then
			-- teinte #8c8c8c comme M.acc du web ; sans teinte possible, l'image assombrie
			local tinted = pcall(function() sa.Color = TINT end)
			if not tinted then
				tintOK = false
				if o.dark then sa.ColorMapContent = o.dark :: Content end
			end
		end
		local m, r, n = pbr(o)
		if m then pcall(function() sa.MetalnessMapContent = m :: Content end) end
		if r then pcall(function() sa.RoughnessMapContent = r :: Content end) end
		if n then pcall(function() sa.NormalMapContent = n :: Content end) end
		local g = o.glow
		if g and not o.secondary then
			pcall(function()
				sa.EmissiveMaskContent = g.mask; sa.EmissiveTint = g.tint; sa.EmissiveStrength = g.k
			end)
		end
		sa.Parent = mesh
	end)
	if not ok then
		saOK = false
		warn("[SkinPaint] SurfaceAppearance refusée : skins en texture simple (sans métal ni rugosité).")
	end
	return ok
end

-- pièce simple (Part, WedgePart : lame du couteau, arme en blocs) : la peinture en Texture sur les faces, à la même
-- échelle que sur les maillages ; dans le monde, les Texture reçoivent aussi métal, rugosité, relief et lumière (sous pcall)
local function faces(part: BasePart, color: Content, tint: Color3, tile: number, look: Look?): boolean
	for _, f in ipairs(FACES) do
		local t = Instance.new("Texture")
		t.Name = "SkinTex"; t.Face = f; t.StudsPerTileU = tile; t.StudsPerTileV = tile; t.Color3 = tint
		local ok = pcall(function() t.ColorMapContent = color end)
		if not ok then
			local uri = color.Uri
			if not uri then t:Destroy(); return false end
			t.Texture = uri
		end
		if look then
			local m, r, n = pbr(look)
			if m then pcall(function() t.MetalnessMapContent = m :: Content end) end
			if r then pcall(function() t.RoughnessMapContent = r :: Content end) end
			if n then pcall(function() t.NormalMapContent = n :: Content end) end
			local g = look.glow
			if g and not look.secondary then
				pcall(function() t.EmissiveMaskContent = g.mask; t.EmissiveTint = g.tint; t.EmissiveStrength = g.k end)
			end
		end
		t.Parent = part
	end
	return true
end

local applyNow: (model: Instance, skinIndex: number?, camo: string?, world: boolean) -> ()

function SkinPaint.apply(model: Instance, skinIndex: number?, camo: string?)
	-- SurfaceAppearance seulement dans le monde (pas dans un ViewportFrame, sans reflets de l'environnement) ;
	-- un modèle peint avant d'être posé est repeint en SurfaceAppearance dès qu'il entre dans le workspace
	local world = saOK and model:IsDescendantOf(workspace)
	applyNow(model, skinIndex, camo, world)
	if world or not saOK then pending[model] = nil; return end
	local first = pending[model] == nil
	pending[model] = { skinIndex, camo }
	if first then
		local conn: RBXScriptConnection
		conn = model.AncestryChanged:Connect(function()
			local p = pending[model]
			if not p then conn:Disconnect(); return end
			if saOK and model:IsDescendantOf(workspace) then
				pending[model] = nil; conn:Disconnect()
				applyNow(model, p[1], p[2], true)
			end
		end)
	end
end

applyNow = function(model: Instance, skinIndex: number?, camo: string?, world: boolean)
	local sk = Info.SKINS[skinIndex or 1] or Info.SKINS[1]
	local anim = camo and Info.ANIM[camo]
	local finName = (if anim then anim.fin else sk.fin) or "gloss"
	local fin = REFLECT[finName] or 0.08
	local L = anim and animImage(camo :: string) or nil
	local main = (not anim) and sk.tex and paint(sk.tex, false) or nil
	local dark = (not anim) and sk.tex and paint(sk.tex, true) or nil
	local hq = (not anim) and sk.tex and hqPaint(sk.tex :: string, "") or nil
	-- cartes propres au skin (512 px : rugosité, métal et usure, relief des skins gravés)
	-- (seulement avec la peinture 512 px : l'usure de la carte de métal suit ses éclats)
	local maps: Maps? = nil
	if hq and art("sk3:" .. (sk.tex :: string)) then
		local t = "sk3:" .. (sk.tex :: string)
		maps = { n = art(t .. "#n"), r = art(t .. "#r"), m = art(t .. "#m") }
	end
	-- camo de maîtrise envoyé : vraie matière 512 px fixe + effet animé (masque lumineux) dans le monde
	local M = anim and MASTER[camo :: string] or nil
	local mc = M and world and art("mc:" .. (camo :: string)) or nil
	local mcMaps: Maps? = mc and { n = art("mc:" .. (camo :: string) .. "#n"), r = art("mc:" .. (camo :: string) .. "#r"),
		m = art("mc:" .. (camo :: string) .. "#m") } or nil
	local FX = mc and M and animImage(M.fx) or nil
	local scale = model:GetAttribute("Scale")
	local tile = TILE * (if type(scale) == "number" then scale else 1)
	-- émission (web : emissiveMap × ge × ei) : masque, teinte, intensité
	local glow: Glow? = nil
	if anim and L then glow = { mask = Content.fromObject(L.img), tint = WHITE, k = ANIM_EI[camo :: string] or 0.6 }
	elseif sk.glow and sk.tex and GLOW[sk.tex] then
		local mask = hqPaint(sk.tex, "#g")
		local gl = GLOW[sk.tex]
		if mask then glow = { mask = mask, tint = Color3.fromHex(string.format("%06x", gl[1])), k = gl[2] } end
	end
	local mcGlow: Glow? = if FX and M then { mask = Content.fromObject(FX.img), tint = M.tint, k = M.k } else nil
	for _, p in ipairs(model:GetDescendants()) do
		if not p:IsA("BasePart") then continue end
		local role = p:GetAttribute("Role")
		if role ~= "body" and role ~= "acc" and role ~= "wood" then continue end
		local bp = p :: BasePart
		if not DEFAULT[bp] then DEFAULT[bp] = { bp.Color, bp.Material, bp.Reflectance } end
		local d = DEFAULT[bp]
		local secondary = role == "acc"
		local mesh = if bp:IsA("MeshPart") then bp :: MeshPart else nil
		if mesh then mesh.TextureContent = Content.none end
		for _, c in ipairs(bp:GetChildren()) do if c.Name == "SkinSA" or c.Name == "SkinTex" then c:Destroy() end end
		bp.Color = d[1] :: Color3; bp.Material = d[2] :: Enum.Material; bp.Reflectance = d[3] :: number
		if anim then
			local done = false
			if mc then
				local look: Look = { color = mc :: Content, fin = finName, secondary = secondary, glow = mcGlow, maps = mcMaps }
				if mesh then done = surface(mesh, look)
				else done = faces(bp, mc :: Content, if secondary then TINT else WHITE, tile, look) end
				if done then
					if FX then FX.users[bp] = true end
					local fc = ANIM_FALLBACK[camo :: string] or bp.Color
					bp.Color = if secondary then fc:Lerp(Color3.new(), 0.45) else fc
					bp.Material = Enum.Material.SmoothPlastic
				end
			end
			if done then
				-- rien d'autre : la SurfaceAppearance (ou les Texture) porte tout
			elseif L then
				local img = Content.fromObject(L.img)
				if mesh then
					if not (world and surface(mesh, { color = img, dark = Content.fromObject(L.dimg), fin = finName, secondary = secondary, glow = glow })) then
						if secondary then L.dark = true end
						mesh.TextureContent = Content.fromObject(if secondary then L.dimg else L.img)
					elseif secondary and not tintOK then
						L.dark = true
					end
					L.users[mesh] = true
				elseif faces(bp, img, if secondary then TINT else WHITE, tile,
					if world then { color = img, fin = finName, secondary = secondary, glow = glow } else nil) then
					L.users[bp] = true
				else
					-- Texture refusée (image dessinée en direct) : couleur vive du camo, comme sans EditableImage
					bp.Color = ANIM_FALLBACK[camo :: string] or bp.Color
				end
				bp.Material = Enum.Material.SmoothPlastic
			else
				bp.Color = (if secondary then ANIM_FALLBACK[camo :: string]:Lerp(Color3.new(), 0.45) else ANIM_FALLBACK[camo :: string]) or bp.Color
				bp.Material = Enum.Material.Neon
			end
			if not done then bp.Reflectance = fin end
		elseif main then
			local pt = if secondary then dark :: Paint else main
			-- peinture 512 px (ou 256) si elle est envoyée (pièces secondaires : teinte de la SurfaceAppearance), sinon 128 px
			local col = hq or main.img
			local look: Look? = if col then { color = col :: Content, dark = dark and dark.img, fin = finName, secondary = secondary,
				glow = glow, maps = maps } else nil
			local done = false
			if mesh and look and world then done = surface(mesh, look) end
			if not done then
				if mesh then
					local c = if secondary then pt.img else (hq or pt.img)
					if c then mesh.TextureContent = c :: Content end
				elseif col then
					faces(bp, col :: Content, if secondary then TINT else WHITE, tile, if world then look else nil)
				end
				bp.Reflectance = fin
			end
			bp.Color = pt.avg; bp.Material = Enum.Material.SmoothPlastic
		elseif sk.b then                               -- skin uni (Noir mat…)
			bp.Color = (if secondary or role == "wood" then hex(sk.a) else hex(sk.b)) or bp.Color
			bp.Material = Enum.Material.SmoothPlastic; bp.Reflectance = fin
		end
	end
end

return SkinPaint
