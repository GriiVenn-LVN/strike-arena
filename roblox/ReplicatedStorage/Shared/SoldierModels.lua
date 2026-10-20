--!strict
-- ReplicatedStorage/Shared/SoldierModels (ModuleScript, côté client)
-- Fabrique les soldats du jeu web à partir des données de SoldierMeshes (tools/soldiers/), avec EditableMesh et
-- EditableImage (« Allow Mesh / Image APIs », comme les armes) : un MeshPart par membre R15 et par matière.
--   real : soldat photo-réaliste CC0 (texture de l'équipe ; chacun-pour-soi teinté de la couleur du joueur) + équipement
--   proc : soldat procédural des tenues (couleurs de la tenue, coiffe propre à chaque tenue)
-- parts(look, seed) renvoie une liste { part = MeshPart (copie), seg = membre R15, offset = CFrame (studs, repère de l'os) }.
-- Matière : SurfaceAppearance (couleur + carte de normales du relief du tissu + rugosité / métal) quand les cartes sont
-- envoyées (MeshUploader) : tissu mat comme le web (rugosité 0,88, sans reflet spéculaire), peau un peu moins mate,
-- équipement par couleur (gilet en toile, casque satiné, lunettes et pièces métalliques qui reflètent un peu) ;
-- seed donne à chaque soldat une très légère variation de teinte (tissus plus ou moins délavés).
-- Si l'API est refusée, renvoie nil : le soldat garde l'apparence R15 (mais il est quand même animé comme sur le web).
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local decode = require(ReplicatedStorage.Shared.Base64)
local MeshStore = require(ReplicatedStorage.Shared.MeshStore)
local Look = require(ReplicatedStorage.Shared.SoldierLook)
local folder = ReplicatedStorage.Shared:WaitForChild("SoldierMeshes")
local Rig = Look.Rig

local SoldierModels = {}
SoldierModels.meshApi = true
SoldierModels.imageApi = true
local K = Look.K
local QK = K / Rig.Q
local PAL_W = 16                       -- image de palette 16 × 16 : couleur n = texel n

type Tpl = { part: MeshPart, seg: string, offset: CFrame, kind: string, col: number }
type Item = { part: MeshPart, seg: string, offset: CFrame }

local function data(name: string): any?
	local m = folder:FindFirstChild(name)
	if not m then return nil end
	local ok, d = pcall(require, m :: ModuleScript)
	return if ok then d else nil
end

-- ---------- maillages ----------
-- kind = "tex" (uv du modèle), "pal" (uv = texel de la couleur du sommet) ; keep(col) choisit les triangles
local function build(key: string, piece: any, kind: string, keep: (number) -> boolean, palIndex: (number) -> number): (MeshPart?, Vector3, number)
	local raw = decode(piece.data)
	local nv, nt = piece.nv :: number, piece.nt :: number
	local base = nv * 14
	local tris, used, counts = {}, {}, {}
	for t = 0, nt - 1 do
		local a = buffer.readu16(raw, base + t * 6)
		local col = buffer.readu8(raw, a * 14 + 13)
		if keep(col) then
			local b, c = buffer.readu16(raw, base + t * 6 + 2), buffer.readu16(raw, base + t * 6 + 4)
			table.insert(tris, { a, b, c }); used[a] = true; used[b] = true; used[c] = true
			counts[col] = (counts[col] or 0) + 1
		end
	end
	if #tris == 0 then return nil, Vector3.zero, 0 end
	local main, best = 0, -1
	for c, n in pairs(counts) do if n > best then main, best = c, n end end
	local pos: { [number]: Vector3 } = {}
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for i in pairs(used) do
		local o = i * 14
		local v = Vector3.new(buffer.readi16(raw, o), buffer.readi16(raw, o + 2), buffer.readi16(raw, o + 4)) * QK
		pos[i] = v; lo = lo:Min(v); hi = hi:Max(v)
	end
	local center = (lo + hi) / 2
	local mp = MeshStore.meshPart("s:" .. key .. "/" .. nv .. "/" .. nt, function()
		local em = AssetService:CreateEditableMesh({ FixedSize = false })
		local vid, nid, uid = {}, {}, {}
		for i, v in pairs(pos) do
			local o = i * 14
			vid[i] = em:AddVertex(v - center)
			local n = Vector3.new(buffer.readi8(raw, o + 6), buffer.readi8(raw, o + 7), buffer.readi8(raw, o + 8))
			nid[i] = em:AddNormal(if n.Magnitude > 0 then n.Unit else Vector3.yAxis)
			local uv: Vector2
			if kind == "tex" then
				uv = Vector2.new(buffer.readu16(raw, o + 9) / 65535, buffer.readu16(raw, o + 11) / 65535)
			else
				local p = palIndex(buffer.readu8(raw, o + 13))
				uv = Vector2.new((p % PAL_W + 0.5) / PAL_W, (p // PAL_W + 0.5) / PAL_W)
			end
			uid[i] = em:AddUV(uv)
		end
		for _, tr in ipairs(tris) do
			local f = em:AddTriangle(vid[tr[1]], vid[tr[2]], vid[tr[3]])
			em:SetFaceNormals(f, { nid[tr[1]], nid[tr[2]], nid[tr[3]] })
			em:SetFaceUVs(f, { uid[tr[1]], uid[tr[2]], uid[tr[3]] })
		end
		return em
	end)
	mp.Anchored = false; mp.CanCollide = false; mp.CanQuery = false; mp.CanTouch = false; mp.Massless = true
	mp.CastShadow = true; mp.Material = Enum.Material.SmoothPlastic; mp.Color = Color3.new(1, 1, 1)
	return mp, center, main
end

-- morceaux d'un module, découpés par matière : base (texture/palette), néon et verre (une pièce par couleur)
local function addPieces(prefix: string, out: { Tpl }, pieces: any, kind: string, clsOf: (number) -> string, palIndex: (number) -> number)
	for pi, piece in ipairs(pieces) do
		local raw = decode(piece.data)
		local special: { [number]: string } = {}
		for v = 0, piece.nv - 1 do
			local c = buffer.readu8(raw, v * 14 + 13)
			local cl = clsOf(c)
			if cl ~= "base" then special[c] = cl end
		end
		local mp, center, main = build(prefix .. "/" .. pi, piece, kind, function(c) return special[c] == nil end, palIndex)
		if mp then
			mp.Name = "Soldat_" .. piece.seg
			table.insert(out, { part = mp, seg = piece.seg, offset = CFrame.new(center), kind = kind, col = palIndex(main) })
		end
		for c, cl in pairs(special) do
			local sp, sc = build(prefix .. "/" .. pi .. "/c" .. c, piece, kind, function(x) return x == c end, palIndex)
			if sp then
				sp.Name = "Soldat_" .. piece.seg .. "_" .. cl
				table.insert(out, { part = sp, seg = piece.seg, offset = CFrame.new(sc), kind = cl, col = palIndex(c) })
			end
		end
	end
end

-- ---------- images ----------
local function image(key: string, size: number, buf: buffer | () -> buffer): Content?
	local ok, img = pcall(function()
		return (MeshStore.image("s:" .. key, function(): EditableImage?
			if not SoldierModels.imageApi then return nil end
			local e = AssetService:CreateEditableImage({ Size = Vector2.new(size, size) })
			e:WritePixelsBuffer(Vector2.zero, Vector2.new(size, size), if type(buf) == "function" then buf() else buf)
			return e
		end))
	end)
	if ok then return img end
	SoldierModels.imageApi = false
	warn("[SoldierModels] EditableImage indisponible (Allow Mesh / Image APIs) : soldats en couleur unie.")
	return nil
end

local LIN = table.create(256)
for i = 0, 255 do local x = i / 255; LIN[i + 1] = if x <= 0.04045 then x / 12.92 else ((x + 0.055) / 1.055) ^ 2.4 end
local function srgb(x: number): number
	x = math.clamp(x, 0, 1)
	return math.floor((if x <= 0.0031308 then x * 12.92 else 1.055 * x ^ (1 / 2.4) - 0.055) * 255 + 0.5)
end

type Tex = { img: Content?, avg: Color3 }
local texCache: { [string]: Tex } = {}
-- texture d'équipe ; tint = teinte chacun-pour-soi du web (blanc mélangé à 50 % à la couleur du joueur, en linéaire)
local function teamTex(k: string, tint: Color3?): Tex?
	local id = k .. (if tint then tint:ToHex() else "")
	if texCache[id] then return texCache[id] end
	local d = data("Tex_" .. k)
	if not d then return nil end
	local pal, px = decode(d.pal), decode(d.px)
	local size = d.size :: number
	local tr, tg, tb = 1, 1, 1
	if tint then
		tr = 0.5 + 0.5 * LIN[math.floor(tint.R * 255 + 0.5) + 1]
		tg = 0.5 + 0.5 * LIN[math.floor(tint.G * 255 + 0.5) + 1]
		tb = 0.5 + 0.5 * LIN[math.floor(tint.B * 255 + 0.5) + 1]
	end
	local pr, pg, pb = table.create(256), table.create(256), table.create(256)
	for i = 0, 255 do
		local r, g, b = buffer.readu8(pal, i * 3), buffer.readu8(pal, i * 3 + 1), buffer.readu8(pal, i * 3 + 2)
		if tint then r = srgb(LIN[r + 1] * tr); g = srgb(LIN[g + 1] * tg); b = srgb(LIN[b + 1] * tb) end
		pr[i + 1], pg[i + 1], pb[i + 1] = r, g, b
	end
	local n = size * size
	local out = buffer.create(n * 4)
	local sr, sg, sb = 0, 0, 0
	for i = 0, n - 1 do
		local c = buffer.readu8(px, i) + 1
		buffer.writeu8(out, i * 4, pr[c]); buffer.writeu8(out, i * 4 + 1, pg[c]); buffer.writeu8(out, i * 4 + 2, pb[c]); buffer.writeu8(out, i * 4 + 3, 255)
		sr += pr[c]; sg += pg[c]; sb += pb[c]
	end
	local t: Tex = { img = image("tex:" .. id, size, out), avg = Color3.fromRGB(sr / n, sg / n, sb / n) }
	texCache[id] = t
	return t
end

-- palette : couleur de chaque index (texels de l'image 16 × 16)
type Pal = { img: Content?, col: { [number]: Color3 } }
local function palette(id: string, cols: { [number]: Color3 }): Pal
	local out = buffer.create(PAL_W * PAL_W * 4)
	for i = 0, PAL_W * PAL_W - 1 do
		local c = cols[i] or Color3.new(1, 1, 1)
		buffer.writeu8(out, i * 4, math.floor(c.R * 255 + 0.5)); buffer.writeu8(out, i * 4 + 1, math.floor(c.G * 255 + 0.5))
		buffer.writeu8(out, i * 4 + 2, math.floor(c.B * 255 + 0.5)); buffer.writeu8(out, i * 4 + 3, 255)
	end
	return { img = image("pal:" .. id, PAL_W, out), col = cols }
end
local function rgb(t: { number }): Color3 return Color3.fromRGB(t[1], t[2], t[3]) end

-- ---------- cartes de matière (SurfaceAppearance) ----------
-- seulement si elles sont envoyées (ou pendant l'envoi) : chez le joueur, la mémoire des EditableImage reste aux textures
local function mapImg(key: string, size: number, gen: () -> buffer): Content?
	if not MeshStore.uploader and not MeshStore.ids["i:s:" .. key] then return nil end
	return image(key, size, gen)
end
local function gray(size: number, at: (number) -> number): buffer
	local n = size * size
	local out = buffer.create(n * 4)
	for i = 0, n - 1 do
		local v = math.clamp(math.floor(at(i) * 255 + 0.5), 0, 255)
		buffer.writeu8(out, i * 4, v); buffer.writeu8(out, i * 4 + 1, v); buffer.writeu8(out, i * 4 + 2, v); buffer.writeu8(out, i * 4 + 3, 255)
	end
	return out
end

type Maps = { nrm: Content?, rgh: Content?, mtl: Content? }
local NO_MAPS: Maps = { nrm = nil, rgh = nil, mtl = nil }
local mapCache: { [string]: Maps } = {}
-- corps réaliste : relief tiré de la texture de l'équipe (plis, coutures, sangles : luminance, comme le « det » de
-- tools/soldiers/build_soldiers.py), pente réglée sur le contraste moyen de la texture ; rugosité 0,88 du web
-- (tissu), creux plus mats, écussons / boucles plus clairs un peu moins mats, peau 0,7
local function bodyMaps(k: string): Maps
	local hit = mapCache["b:" .. k]
	if hit then return hit end
	local m: Maps = { nrm = nil, rgh = nil, mtl = nil }
	local d = data("Tex_" .. k)
	if d then
		local size = d.size :: number
		local lum: { number }, skin: { boolean } = table.create(256, 0), table.create(256, false)
		local pal = decode(d.pal)
		for i = 0, 255 do
			if i * 3 + 2 < buffer.len(pal) then
				local r, g, b = buffer.readu8(pal, i * 3) / 255, buffer.readu8(pal, i * 3 + 1) / 255, buffer.readu8(pal, i * 3 + 2) / 255
				lum[i + 1] = 0.299 * r + 0.587 * g + 0.114 * b
				local mx, mn = math.max(r, g, b), math.min(r, g, b)
				local sat = (mx - mn) / math.max(mx, 1e-3)
				skin[i + 1] = r > g and g > b * 0.95 and sat > 0.12 and sat < 0.75 and mx > 0.2
			end
		end
		local px: buffer? = nil
		local function pixels(): buffer
			if not px then px = decode(d.px) end
			return px :: buffer
		end
		m.nrm = mapImg("nrm:" .. k, size, function(): buffer
			local pb = pixels()
			local function L(x: number, y: number): number
				x = math.clamp(x, 0, size - 1); y = math.clamp(y, 0, size - 1)
				return lum[buffer.readu8(pb, y * size + x) + 1]
			end
			local n = size * size
			local gxs: { number }, gys: { number } = table.create(n, 0), table.create(n, 0)
			local sum = 0
			for y = 0, size - 1 do
				for x = 0, size - 1 do
					local gx = (L(x + 1, y) - L(x - 1, y)) / 2
					local gy = (L(x, y - 1) - L(x, y + 1)) / 2      -- v d'OpenGL : vers le haut de l'image
					gxs[y * size + x + 1] = gx; gys[y * size + x + 1] = gy
					sum += math.sqrt(gx * gx + gy * gy)
				end
			end
			local S = 0.3 / math.max(0.01, sum / n)          -- pente moyenne ≈ 0,3 : relief marqué, sans faux trous
			local out = buffer.create(n * 4)
			for i = 0, n - 1 do
				local nx, ny = math.clamp(-gxs[i + 1] * S, -1.2, 1.2), math.clamp(-gys[i + 1] * S, -1.2, 1.2)
				local l = math.sqrt(nx * nx + ny * ny + 1)
				buffer.writeu8(out, i * 4, math.floor((nx / l * 0.5 + 0.5) * 255 + 0.5))
				buffer.writeu8(out, i * 4 + 1, math.floor((ny / l * 0.5 + 0.5) * 255 + 0.5))
				buffer.writeu8(out, i * 4 + 2, math.floor((1 / l * 0.5 + 0.5) * 255 + 0.5))
				buffer.writeu8(out, i * 4 + 3, 255)
			end
			return out
		end)
		m.rgh = mapImg("rgh:" .. k, size, function(): buffer
			local pb = pixels()
			return gray(size, function(i)
				local c = buffer.readu8(pb, i) + 1
				if skin[c] then return 0.7 end
				local l = lum[c]
				return math.clamp(0.88 + (0.18 - l) * 0.25 - math.max(0, l - 0.45) * 0.4, 0.62, 0.97)
			end)
		end)
	end
	mapCache["b:" .. k] = m
	return m
end

-- équipement et tenues : rugosité / métal de chaque couleur de la palette (lookMats du web)
local GEAR_MAT: { [string]: { number } } = {
	["1b1d22"] = { 0.6, 0.3 },     -- M.dark : boucles, radio, crochets
	["16171a"] = { 0.7, 0 },       -- M.blk
	["0a0c10"] = { 0.08, 0.9 },    -- M.lens : lunettes, optiques
	["232f45"] = { 0.5, 0.15 },    -- casque CT
	["8c7a58"] = { 0.95, 0 },      -- toile sable du T
	["34383e"] = { 0.6, 0.1 },     -- casque gris du chacun-pour-soi
}
local SLOT_MAT: { [string]: { number } } = {
	skin = { 0.75, 0 }, shirt = { 0.9, 0 }, pants = { 0.9, 0 }, vest = { 0.85, 0 }, helm = { 0.5, 0.15 }, glove = { 0.8, 0 },
	boot = { 0.7, 0 }, accent = { 0.6, 0 }, dark = { 0.6, 0.3 }, lens = { 0.08, 0.9 }, blk = { 0.7, 0 }, gold = { 0.35, 0.8 }, glass = { 0.1, 0 },
}
local function palMaps(id: string, mat: { [number]: { number } }): Maps
	local hit = mapCache["p:" .. id]
	if hit then return hit end
	local function at(j: number): (number) -> number
		return function(i: number): number
			local e = mat[i]
			return if e then e[j] else (if j == 1 then 0.85 else 0)
		end
	end
	local m: Maps = {
		nrm = nil,
		rgh = mapImg("rgh:" .. id, PAL_W, function() return gray(PAL_W, at(1)) end),
		mtl = mapImg("mtl:" .. id, PAL_W, function() return gray(PAL_W, at(2)) end),
	}
	mapCache["p:" .. id] = m
	return m
end
local function gearMaps(k: string): Maps
	local mat: { [number]: { number } } = {}
	local g = data("Gear_" .. k)
	if g then
		for i, e in ipairs(g.pal) do
			mat[i - 1] = GEAR_MAT[string.lower(rgb(e.c):ToHex())] or { 0.85, 0 }   -- gilet, poches, sac : toile (0,85)
		end
	end
	return palMaps("g:" .. k, mat)
end
local function outfitMaps(web: number, def: any): Maps
	local mat: { [number]: { number } } = {}
	for i, sl in ipairs(Rig.SLOTS) do
		local e = SLOT_MAT[sl] or { 0.85, 0 }
		-- tenues métalliques (samouraï, roi doré) : casque, gilet et accent en métal poli
		if def.metal and (sl == "helm" or sl == "vest" or sl == "accent" or sl == "gold") then e = { 0.3, 0.75 } end
		mat[i - 1] = e
	end
	local h = data("Head_" .. web)
	if h then
		for j, e in ipairs(h.pal) do
			local si = if e.s then table.find(Rig.SLOTS, e.s) else nil
			mat[16 + j - 1] = if si then mat[si - 1] or { 0.85, 0 } else { 0.7, 0 }
		end
	end
	return palMaps("o" .. web, mat)
end

-- SurfaceAppearance d'une pièce ; false si Roblox la refuse ou si les cartes manquent (texture simple gardée)
local saOK = true
local function surface(mp: MeshPart, color: Content, maps: Maps, tint: Color3?): boolean
	if not saOK or not maps.rgh then return false end
	local ok = pcall(function()
		local sa = Instance.new("SurfaceAppearance")
		sa.Name = "SoldatSA"
		sa.ColorMapContent = color
		if maps.nrm then sa.NormalMapContent = maps.nrm :: Content end
		sa.RoughnessMapContent = maps.rgh :: Content
		if maps.mtl then sa.MetalnessMapContent = maps.mtl :: Content end
		if tint then pcall(function() (sa :: any).Color = tint end) end
		sa.Parent = mp
	end)
	if not ok then
		saOK = false
		warn("[SoldierModels] SurfaceAppearance refusée : soldats en texture simple.")
	end
	return ok
end

-- ---------- gabarits (une fois par soldat ; ensuite copiés) ----------
local tplCache: { [string]: { Tpl } } = {}
local building: { [string]: boolean } = {}
local function cached(id: string, make: () -> { Tpl }): { Tpl }?
	while building[id] do task.wait() end
	if tplCache[id] then return tplCache[id] end
	if not SoldierModels.meshApi and MeshStore.count() == 0 then return nil end
	building[id] = true
	local ok, res = pcall(make)
	building[id] = nil
	if not ok then
		SoldierModels.meshApi = false
		warn("[SoldierModels] EditableMesh indisponible : coche Game Settings → Security → « Allow Mesh / Image APIs ». Soldats R15 en attendant.", res)
		return nil
	end
	tplCache[id] = res
	return res
end

local function realTpl(k: string): { Tpl }?
	return cached("real:" .. k, function()
		local out: { Tpl } = {}
		addPieces("real:" .. k .. "/body", out, data("Body") or {}, "tex", function() return "base" end, function(c) return c end)
		local g = data("Gear_" .. k)
		if g then addPieces("real:" .. k .. "/gear", out, g, "pal", function(c) return g.pal[c + 1].cls end, function(c) return c end) end
		return out
	end)
end

local function outfitTpl(web: number, glow: boolean): { Tpl }?
	local def = nil
	for _, o in pairs(Rig.OUTFITS) do if o.web == web then def = o end end
	if not def then return nil end
	local body = cached("obody:" .. (if glow then "g" else "n"), function()
		local out: { Tpl } = {}
		addPieces("obody:" .. (if glow then "g" else "n"), out, data("Outfit") or {}, "pal", function(c)
			return if Rig.SLOTS[c + 1] == "accent" and glow then "neon" else "base"
		end, function(c) return c end)
		return out
	end)
	local head = cached("ohead:" .. web, function()
		local out: { Tpl } = {}
		local h = data("Head_" .. web)
		if h then
			addPieces("ohead:" .. web, out, h, "pal", function(c)
				local e = h.pal[c + 1]
				if e.s then local sc = def.colors[e.s]; return if sc then sc.cls else "base" end
				return e.cls
			end, function(c) return 16 + c end)
		end
		return out
	end)
	if not body or not head then return nil end
	local all = table.clone(body)
	for _, t in ipairs(head) do table.insert(all, t) end
	return all
end

-- ---------- soldat habillé ----------
local palCache: { [string]: Pal } = {}
function SoldierModels.parts(look: Look.LookInfo, seed: number?): { Item }?
	local tpls: { Tpl }?
	local tex: Tex? = nil
	local pal: Pal
	local metal = false
	local bMaps: Maps, pMaps: Maps = NO_MAPS, NO_MAPS
	if look.rig == "proc" and look.outfit then
		local def: any = nil
		for _, o in pairs(Rig.OUTFITS) do if o.web == look.outfit then def = o end end
		if not def then return nil end
		metal = def.metal
		tpls = outfitTpl(look.outfit, def.glow)
		pMaps = outfitMaps(look.outfit, def)
		local id = "o" .. look.outfit .. ":" .. look.tone:ToHex()
		local p = palCache[id]
		if not p then
			local cols: { [number]: Color3 } = {}
			for i, s in ipairs(Rig.SLOTS) do
				local sc = def.colors[s]
				cols[i - 1] = if s == "skin" then look.tone elseif sc then rgb(sc.c) else Color3.new(1, 1, 1)
			end
			local h = data("Head_" .. look.outfit)
			if h then
				for j, e in ipairs(h.pal) do
					cols[16 + j - 1] = if e.s then cols[table.find(Rig.SLOTS, e.s) :: number - 1] or Color3.new(1, 1, 1) else rgb(e.c)
				end
			end
			p = palette(id, cols); palCache[id] = p
		end
		pal = p
	else
		tpls = realTpl(look.tex)
		tex = teamTex(look.tex, if look.tex == "ffa" then look.acc else nil)
		bMaps = bodyMaps(look.tex); pMaps = gearMaps(look.tex)
		local p = palCache["g:" .. look.tex]
		if not p then
			local cols: { [number]: Color3 } = {}
			local g = data("Gear_" .. look.tex)
			if g then for i, e in ipairs(g.pal) do cols[i - 1] = rgb(e.c) end end
			p = palette("g:" .. look.tex, cols); palCache["g:" .. look.tex] = p
		end
		pal = p
	end
	if not tpls then return nil end
	-- légère variation par soldat : tissu un peu plus ou moins délavé, à peine plus chaud ou plus froid
	local tint: Color3? = nil
	if seed then
		local a, b = (seed % 97) / 96, ((seed // 97) % 89) / 88
		local v = 0.93 + a * 0.07
		tint = Color3.new(v * (0.985 + b * 0.03), v, v * (1.015 - b * 0.03))
	end
	local items: { Item } = {}
	for _, t in ipairs(tpls) do
		local mp = t.part:Clone()
		-- tissu mat (rugosité 0,88 du web) : en SmoothPlastic, le reflet du ciel (EnvironmentSpecularScale de la carte)
		-- recouvrait les tenues sombres (CT bleu marine, gilets) d'un vernis noir brillant
		if t.kind == "tex" then
			mp.Material = Enum.Material.Fabric
			if tex and tex.img then
				if surface(mp, tex.img :: Content, bMaps, tint) then mp.Material = Enum.Material.SmoothPlastic
				else mp.TextureContent = tex.img :: Content end
			elseif tex then mp.Color = tex.avg end
		elseif t.kind == "pal" then
			if pal.img and surface(mp, pal.img :: Content, pMaps, tint) then
				mp.Material = Enum.Material.SmoothPlastic
			else
				if pal.img then mp.TextureContent = pal.img :: Content else mp.Color = pal.col[t.col] or mp.Color end
				if metal then mp.Reflectance = 0.12 else mp.Material = Enum.Material.Fabric end
			end
		else
			mp.Color = pal.col[t.col] or Color3.new(1, 1, 1)
			if t.kind == "neon" then mp.Material = Enum.Material.Neon
			elseif t.kind == "glass" then mp.Material = Enum.Material.Glass; mp.Transparency = 0.65; mp.CastShadow = false end
		end
		table.insert(items, { part = mp, seg = t.seg, offset = t.offset })
	end
	return items
end

-- envoi des modèles depuis Studio (ServerStorage/MeshUploader) : construit tout ce qui ne dépend pas du joueur
function SoldierModels.prebuildAll()
	local tone = Look.hex(Rig.TONES[1])
	for _, k in ipairs({ "t", "ct", "ffa" }) do
		SoldierModels.parts({ rig = "real", key = k, tex = k, acc = Look.hex(Rig.PALETTE[1]), tone = tone, colorIndex = 1 } :: any)
	end
	for _, c in ipairs(Rig.PALETTE) do teamTex("ffa", Look.hex(c)) end    -- chacun-pour-soi : une teinte par couleur de joueur
	-- cartes de matière (SurfaceAppearance) : relief et rugosité du corps, rugosité / métal des palettes
	for _, k in ipairs({ "t", "ct", "ffa" }) do mapCache["b:" .. k] = nil; bodyMaps(k); mapCache["p:g:" .. k] = nil; gearMaps(k) end
	for _, o in pairs(Rig.OUTFITS) do mapCache["p:o" .. o.web] = nil; outfitMaps(o.web, o) end
	for _, o in pairs(Rig.OUTFITS) do
		for _, t in ipairs(Rig.TONES) do
			SoldierModels.parts({ rig = "proc", key = "o" .. o.web, tex = "ffa", outfit = o.web, acc = Color3.new(1, 1, 1), tone = Look.hex(t), colorIndex = 1 } :: any)
		end
	end
end

return SoldierModels
