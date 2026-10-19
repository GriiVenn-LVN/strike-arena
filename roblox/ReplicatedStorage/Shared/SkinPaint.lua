--!strict
-- ReplicatedStorage/Shared/SkinPaint (ModuleScript, côté client)
-- Peint les armes avec les skins du jeu web : les mêmes peintures (exportées par tools/export_skins.js dans SkinTextures)
-- posées en texture sur les pièces de l'arme (EditableImage), avec la finition du skin (mat, brillant, chrome…).
-- Les camos animés (exclusifs Robux) sont recalculés en direct, comme sur le web (src/44b_animcamo.js).
-- Comme pour les armes 3D, il faut « Allow Mesh / Image APIs » ; sinon l'arme prend la couleur moyenne du skin.
--
-- SkinPaint.apply(model, skinIndex, camoId?) : skinIndex suit Config.SKINS (1 = Défaut), camoId = clé de SkinInfo.ANIM.
local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Info = require(ReplicatedStorage.Shared.SkinInfo)
local decode = require(ReplicatedStorage.Shared.Base64)
local MeshStore = require(ReplicatedStorage.Shared.MeshStore)

local SkinPaint = {}
SkinPaint.imageApi = true

local DARK = 0.55                  -- pièces secondaires : peinture assombrie (teinte #8c8c8c du web)
-- finition -> reflet (SmoothPlastic pour que la peinture reste lisible)
local REFLECT = { matte = 0, paint = 0.02, gloss = 0.08, anod = 0.14, pearl = 0.18, chrome = 0.26 }

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
local AS = 64                       -- 64 × 64 pixels recalculés ~20 fois par seconde, comme acPix() du web
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
do local r = rng(77); for i = 1, 35 do STARS[i] = { r(0, AS), r(0, AS), r(0, P2), r(1.5, 4) } end end

type Live = { img: EditableImage, dimg: EditableImage, buf: buffer, dbuf: buffer, users: { [Instance]: boolean } }
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
	for i = 0, AS * AS * 4 - 1 do buffer.writeu8(L.dbuf, i, if i % 4 == 3 then 255 else buffer.readu8(buf, i) * DARK) end
	L.img:WritePixelsBuffer(Vector2.zero, Vector2.new(AS, AS), buf)
	L.dimg:WritePixelsBuffer(Vector2.zero, Vector2.new(AS, AS), L.dbuf)
end

local function animImage(id: string): Live?
	if live[id] then return live[id] end
	if not SkinPaint.imageApi or not (PIX[id] or DRAW[id]) then return nil end
	local ok, L = pcall(function()
		local size = Vector2.new(AS, AS)
		return { img = AssetService:CreateEditableImage({ Size = size }), dimg = AssetService:CreateEditableImage({ Size = size }),
			buf = buffer.create(AS * AS * 4), dbuf = buffer.create(AS * AS * 4), users = setmetatable({}, { __mode = "k" }) :: any }
	end)
	if not ok then SkinPaint.imageApi = false; return nil end
	render(id, L, os.clock())
	live[id] = L
	return L
end

-- un seul camo de chaque sorte est recalculé, et seulement tant qu'une arme le porte
local acc = 0
RunService.Heartbeat:Connect(function(dt: number)
	acc += dt
	if acc < 0.05 then return end
	acc = 0
	local t = os.clock()
	for id, L in pairs(live) do
		local used = false
		for part in pairs(L.users) do if part.Parent then used = true; break end end
		if used then render(id, L, t) end
	end
end)

-- ---------- application sur une arme ----------
local DEFAULT: { [Instance]: { Color3 | Enum.Material | number } } = setmetatable({}, { __mode = "k" }) :: any

function SkinPaint.apply(model: Instance, skinIndex: number?, camo: string?)
	local sk = Info.SKINS[skinIndex or 1] or Info.SKINS[1]
	local anim = camo and Info.ANIM[camo]
	local fin = REFLECT[(if anim then anim.fin else sk.fin) or "gloss"] or 0.08
	local L = anim and animImage(camo :: string) or nil
	local main = (not anim) and sk.tex and paint(sk.tex, false) or nil
	local dark = (not anim) and sk.tex and paint(sk.tex, true) or nil
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
		bp.Color = d[1] :: Color3; bp.Material = d[2] :: Enum.Material; bp.Reflectance = d[3] :: number
		if anim then
			if L and mesh then
				mesh.TextureContent = Content.fromObject(if secondary then L.dimg else L.img); L.users[mesh] = true
				bp.Material = Enum.Material.SmoothPlastic
			else
				bp.Color = (if secondary then ANIM_FALLBACK[camo :: string]:Lerp(Color3.new(), 0.45) else ANIM_FALLBACK[camo :: string]) or bp.Color
				bp.Material = Enum.Material.Neon
			end
			bp.Reflectance = fin
		elseif main then
			local pt = if secondary then dark :: Paint else main
			if mesh and pt.img then mesh.TextureContent = pt.img :: Content end
			bp.Color = pt.avg; bp.Material = Enum.Material.SmoothPlastic; bp.Reflectance = fin
		elseif sk.b then                               -- skin uni (Noir mat…)
			bp.Color = (if secondary or role == "wood" then hex(sk.a) else hex(sk.b)) or bp.Color
			bp.Material = Enum.Material.SmoothPlastic; bp.Reflectance = fin
		end
	end
end

return SkinPaint
