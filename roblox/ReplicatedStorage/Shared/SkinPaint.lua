--!strict
-- ReplicatedStorage/Shared/SkinPaint (ModuleScript, côté client)
-- Peint les armes avec les skins du jeu web : les mêmes peintures (exportées par tools/export_skins.js dans SkinTextures)
-- posées en texture sur les pièces de l'arme (EditableImage), avec la finition du skin (mat, brillant, chrome…).
-- Les camos animés (exclusifs Robux) sont recalculés en direct, comme sur le web (src/44b_animcamo.js).
-- Comme pour les armes 3D, il faut « Allow Mesh / Image APIs » ; sinon l'arme prend la couleur moyenne du skin.
--
-- Rendu (comme le MeshStandardMaterial du web, src/45_models.js gunMats + src/44d_skinhq.js) :
--   * arme dans le monde (vue à la 1re personne, 3e personne, killcam) : SurfaceAppearance = peinture + carte de métal
--     (metalness de la finition) + carte de rugosité (vernis, usure, traces de doigts : skinRough du web) + masque lumineux
--     des skins néon et des camos animés (émission du web) ; pièces secondaires teintées #8c8c8c comme M.acc ;
--   * aperçus (ViewportFrame : pas de reflets de l'environnement, le métal y paraîtrait noir) et repli sans SurfaceAppearance :
--     peinture posée en TextureContent, SmoothPlastic + reflet selon la finition.
--   * peinture 256 px « sk2:<motif> » (ServerStorage/SkinTexturesHQ, envoyée par MeshUploader) dès qu'elle est envoyée,
--     sinon la 128 px « sk:<motif> » de SkinTextures ; pièces simples (lame du couteau, arme en blocs) : Texture sur les faces.
--
-- SkinPaint.apply(model, skinIndex, camoId?) : skinIndex suit Config.SKINS (1 = Défaut), camoId = clé de SkinInfo.ANIM.
local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Info = require(ReplicatedStorage.Shared.SkinInfo)
local decode = require(ReplicatedStorage.Shared.Base64)
local MeshStore = require(ReplicatedStorage.Shared.MeshStore)

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
local ANIM_EI: { [string]: number } = { plasma = 0.55, magma = 0.9, code = 0.8, nebula = 0.6, prism = 0.35, storm = 1 }
local TINT = Color3.fromRGB(140, 140, 140)  -- web : M.acc color #8c8c8c
-- taille d'une répétition de la peinture, en mètres d'arme (web : 0,78 / 1,35) ; × échelle du modèle pour les Texture
local TILE = 0.78 / 1.35

-- sans EditableImage : couleur vive du camo animé
local ANIM_FALLBACK: { [string]: Color3 } = {
	plasma = Color3.fromRGB(138, 59, 255), magma = Color3.fromRGB(255, 90, 26), code = Color3.fromRGB(42, 255, 122),
	nebula = Color3.fromRGB(74, 58, 255), prism = Color3.fromRGB(255, 106, 213), storm = Color3.fromRGB(74, 184, 255),
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
local sin, cos, abs, max, min, floor = math.sin, math.cos, math.abs, math.max, math.min, math.floor

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

-- ---------- peintures 256 px (envoyées) et masques lumineux ----------
-- Côté joueur, seulement si MeshUploader les a envoyées (clé « i:sk2:… » dans MeshAssets) ; les données restent dans
-- ServerStorage/SkinTexturesHQ, que seul l'envoi depuis Studio lit.
local function hqFill(name: string): EditableImage?
	local folder = ServerStorage:FindFirstChild("SkinTexturesHQ")
	local src = folder and folder:FindFirstChild(name)
	if not src or not SkinPaint.imageApi then return nil end
	local data = require(src :: ModuleScript) :: any
	local size = data.size :: number
	local out = buffer.create(size * size * 4)
	if data.gray then
		local g = decode(data.gray)
		for i = 0, size * size - 1 do
			local l = buffer.readu8(g, i)
			buffer.writeu8(out, i * 4, l); buffer.writeu8(out, i * 4 + 1, l); buffer.writeu8(out, i * 4 + 2, l); buffer.writeu8(out, i * 4 + 3, 255)
		end
	else
		local pal, px = decode(data.pal), decode(data.px)
		for i = 0, size * size - 1 do
			local c = buffer.readu8(px, i) * 3
			buffer.writeu8(out, i * 4, buffer.readu8(pal, c)); buffer.writeu8(out, i * 4 + 1, buffer.readu8(pal, c + 1))
			buffer.writeu8(out, i * 4 + 2, buffer.readu8(pal, c + 2)); buffer.writeu8(out, i * 4 + 3, 255)
		end
	end
	local e = AssetService:CreateEditableImage({ Size = Vector2.new(size, size) })
	e:WritePixelsBuffer(Vector2.zero, Vector2.new(size, size), out)
	return e
end

local sent: { [string]: Content | false } = {}
local function uploaded(name: string): Content?
	local c = sent[name]
	if c == nil then
		local id = MeshStore.ids["i:sk2:" .. name]
		local got: Content | false = false
		if id then got = Content.fromUri("rbxassetid://" .. id) end
		sent[name] = got
		c = got
	end
	return if c then c :: Content else nil
end

-- ---------- cartes de métal et de rugosité par finition ----------
-- rugosité du web (skinRough + 44d) : roughness = r × 1,5 (pièces secondaires r + 0,1) × carte 150..255 (bruit + usure)
local function hash(x: number, y: number, s: number): number
	local h = (x * 374761393 + y * 668265263 + (s + 1) * 1442695041) % 4294967296
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = (h * 1274126177) % 4294967296
	return bit32.bxor(h, bit32.rshift(h, 16)) / 4294967296
end
-- bruit de valeur sans couture (période P cellules), comme vnoise/fbm du web
local function vnoise(u: number, v: number, P: number, s: number): number
	local x, y = u * P, v * P
	local ix, iy = floor(x), floor(y)
	local fx, fy = x - ix, y - iy
	local x0, y0 = ix % P, iy % P
	local x1, y1 = (x0 + 1) % P, (y0 + 1) % P
	local a, b, c, d = hash(x0, y0, s), hash(x1, y0, s), hash(x0, y1, s), hash(x1, y1, s)
	local sx, sy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
	return a + (b - a) * sx + (c - a) * sy + (a - b - c + d) * sx * sy
end
local function fbm(u: number, v: number, P: number, oct: number, s: number): number
	local t, amp, n = 0, 0.5, 0
	for i = 0, oct - 1 do t += amp * vnoise(u, v, P, s + i * 31); n += amp; amp *= 0.5; P *= 2 end
	return t / n
end
local function sstep(a: number, b: number, x: number): number
	local t = max(0, min(1, (x - a) / (b - a)))
	return t * t * (3 - 2 * t)
end

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
			local e = AssetService:CreateEditableImage({ Size = Vector2.new(size, size) })
			e:WritePixelsBuffer(Vector2.zero, Vector2.new(size, size), out)
			return e
		end))
	end)
	local res = if ok then img else nil
	finCache[id] = res or false
	return res
end

-- envoi depuis Studio (MeshUploader, mode Edit) : peintures 256 px, masques lumineux, cartes des finitions
function SkinPaint.uploadAll()
	local folder = ServerStorage:FindFirstChild("SkinTexturesHQ")
	if folder then
		for _, m in ipairs(folder:GetChildren()) do
			local _, e = MeshStore.image("sk2:" .. m.Name, function() return hqFill(m.Name) end)
			if e then pcall(function() (e :: EditableImage):Destroy() end) end
		end
	end
	for fin in pairs(FIN) do for _, k in ipairs({ "m", "r", "ra" }) do finCache[fin .. ":" .. k] = nil; finMap(fin, k) end end
end

-- ---------- application sur une arme ----------
local DEFAULT: { [Instance]: { Color3 | Enum.Material | number } } = setmetatable({}, { __mode = "k" }) :: any
local saOK = true                   -- passe à false si Roblox refuse la SurfaceAppearance créée par script
local tintOK = true                 -- passe à false si la teinte (SurfaceAppearance.Color) est refusée
local pending: { [Instance]: { any } } = setmetatable({}, { __mode = "k" }) :: any
local FACES = { Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Top, Enum.NormalId.Bottom }
local WHITE = Color3.new(1, 1, 1)

-- peinture d'une pièce (MeshPart) en SurfaceAppearance ; renvoie false si Roblox la refuse
type Glow = { mask: Content, tint: Color3, k: number }
type Look = { color: Content, dark: Content?, fin: string, secondary: boolean, glow: Glow? }
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
		local m, r = finMap(o.fin, "m"), finMap(o.fin, if o.secondary then "ra" else "r")
		if m then pcall(function() sa.MetalnessMapContent = m :: Content end) end
		if r then pcall(function() sa.RoughnessMapContent = r :: Content end) end
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

-- pièce simple (Part, WedgePart) : la peinture en Texture sur les faces, à la même échelle que sur les maillages
local function faces(part: BasePart, color: Content, tint: Color3, tile: number): boolean
	for _, f in ipairs(FACES) do
		local t = Instance.new("Texture")
		t.Name = "SkinTex"; t.Face = f; t.StudsPerTileU = tile; t.StudsPerTileV = tile; t.Color3 = tint
		local ok = pcall(function() t.ColorMapContent = color end)
		if not ok then
			local uri = color.Uri
			if not uri then t:Destroy(); return false end
			t.Texture = uri
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
	local hq = (not anim) and sk.tex and uploaded(sk.tex :: string) or nil
	local scale = model:GetAttribute("Scale")
	local tile = TILE * (if type(scale) == "number" then scale else 1)
	-- émission (web : emissiveMap × ge × ei) : masque, teinte, intensité
	local glow: Glow? = nil
	if anim and L then glow = { mask = Content.fromObject(L.img), tint = WHITE, k = ANIM_EI[camo :: string] or 0.6 }
	elseif sk.glow and sk.tex and GLOW[sk.tex] then
		local mask = uploaded(sk.tex .. "#g")
		local gl = GLOW[sk.tex]
		if mask then glow = { mask = mask, tint = Color3.fromHex(string.format("%06x", gl[1])), k = gl[2] } end
	end
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
			if L then
				local img = Content.fromObject(L.img)
				if mesh then
					if not (world and surface(mesh, { color = img, dark = Content.fromObject(L.dimg), fin = finName, secondary = secondary, glow = glow })) then
						if secondary then L.dark = true end
						mesh.TextureContent = Content.fromObject(if secondary then L.dimg else L.img)
					elseif secondary and not tintOK then
						L.dark = true
					end
					L.users[mesh] = true
				elseif faces(bp, img, if secondary then TINT else WHITE, tile) then
					L.users[bp] = true
				end
				bp.Material = Enum.Material.SmoothPlastic
			else
				bp.Color = (if secondary then ANIM_FALLBACK[camo :: string]:Lerp(Color3.new(), 0.45) else ANIM_FALLBACK[camo :: string]) or bp.Color
				bp.Material = Enum.Material.Neon
			end
			bp.Reflectance = fin
		elseif main then
			local pt = if secondary then dark :: Paint else main
			-- peinture 256 px si elle est envoyée (pièces secondaires : teinte de la SurfaceAppearance), sinon 128 px
			local col = hq or main.img
			local done = false
			if mesh and col and world then
				done = surface(mesh, { color = col :: Content, dark = dark and dark.img, fin = finName, secondary = secondary, glow = glow })
			end
			if not done then
				if mesh then
					local c = if secondary then pt.img else (hq or pt.img)
					if c then mesh.TextureContent = c :: Content end
				elseif col then
					faces(bp, col :: Content, if secondary then TINT else WHITE, tile)
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
