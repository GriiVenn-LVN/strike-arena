--!strict
-- ReplicatedStorage/Shared/SoldierModels (ModuleScript, côté client)
-- Fabrique les soldats du jeu web à partir des données de SoldierMeshes (tools/soldiers/), avec EditableMesh et
-- EditableImage (« Allow Mesh / Image APIs », comme les armes) : un MeshPart par membre R15 et par matière.
--   real : soldat photo-réaliste CC0 (texture de l'équipe ; chacun-pour-soi teinté de la couleur du joueur) + équipement
--   proc : soldat procédural des tenues (couleurs de la tenue, coiffe propre à chaque tenue)
-- parts(look) renvoie une liste { part = MeshPart (copie), seg = membre R15, offset = CFrame (studs, repère de l'os) }.
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
local function image(key: string, size: number, buf: buffer): Content?
	local ok, img = pcall(function()
		return (MeshStore.image("s:" .. key, function(): EditableImage?
			if not SoldierModels.imageApi then return nil end
			local e = AssetService:CreateEditableImage({ Size = Vector2.new(size, size) })
			e:WritePixelsBuffer(Vector2.zero, Vector2.new(size, size), buf)
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
function SoldierModels.parts(look: Look.LookInfo): { Item }?
	local tpls: { Tpl }?
	local tex: Tex? = nil
	local pal: Pal
	local metal = false
	if look.rig == "proc" and look.outfit then
		local def: any = nil
		for _, o in pairs(Rig.OUTFITS) do if o.web == look.outfit then def = o end end
		if not def then return nil end
		metal = def.metal
		tpls = outfitTpl(look.outfit, def.glow)
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
	local items: { Item } = {}
	for _, t in ipairs(tpls) do
		local mp = t.part:Clone()
		-- tissu mat (rugosité 0,88 du web) : en SmoothPlastic, le reflet du ciel (EnvironmentSpecularScale de la carte)
		-- recouvrait les tenues sombres (CT bleu marine, gilets) d'un vernis noir brillant
		if t.kind == "tex" then
			mp.Material = Enum.Material.Fabric
			if tex and tex.img then mp.TextureContent = tex.img :: Content elseif tex then mp.Color = tex.avg end
		elseif t.kind == "pal" then
			if pal.img then mp.TextureContent = pal.img :: Content else mp.Color = pal.col[t.col] or mp.Color end
			if metal then mp.Reflectance = 0.12 else mp.Material = Enum.Material.Fabric end
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
	for _, o in pairs(Rig.OUTFITS) do
		for _, t in ipairs(Rig.TONES) do
			SoldierModels.parts({ rig = "proc", key = "o" .. o.web, tex = "ffa", outfit = o.web, acc = Color3.new(1, 1, 1), tone = Look.hex(t), colorIndex = 1 } :: any)
		end
	end
end

return SoldierModels
