--!strict
-- ReplicatedStorage/Shared/MapScene (ModuleScript, client + serveur)
-- Lit le décor 3D des cartes du web exporté par tools/export_scene.js + tools/scene_to_lua.py (dossier MapScenes) :
-- matériaux, primitives (blocs, boules, cylindres : construits par le serveur, MapBuilder), maillages
-- (construits par le client, MapDetailController), textures canvas du web (palette 256 couleurs), lampes, halos, ambiance.
-- Toutes les longueurs des données sont en mètres (comme le web) : multiplier par Config.STUDS_PER_METER.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local decode = require(ReplicatedStorage.Shared.Base64)

local MapScene = {}

export type Mat = { c: { number }, avg: { number }, rm: string, tex: string?, rep: { number }?, off: { number }?, cut: boolean?,
	a: number?, ds: boolean?, vc: boolean?, fs: boolean?, refl: number?, det: { tex: string, rep: number, str: number }? }
export type Prim = { kind: number, flags: number, pos: Vector3, size: Vector3, tile: Vector3, rot: CFrame, mats: { number }, color: Color3? }
export type Tex = { w: number, h: number, fmt: string, kind: string, avg: Color3, rgba: buffer }

local root = ReplicatedStorage.Shared:FindFirstChild("MapScenes")

local function folderOf(id: string): Instance?
	return root and root:FindFirstChild(id)
end

function MapScene.has(id: string): boolean
	local f = folderOf(id)
	return f ~= nil and f:FindFirstChild("Info") ~= nil
end

local infos: { [string]: any } = {}
function MapScene.info(id: string): any
	if infos[id] == nil then
		local f = folderOf(id)
		local m = f and f:FindFirstChild("Info")
		infos[id] = if m then (require(m :: ModuleScript) :: any) else false
	end
	return infos[id] or nil
end

-- concatène les modules base64 B<n> listés dans Info puis décode
local function blob(id: string, names: { string }): buffer?
	local f = folderOf(id)
	if not f then return nil end
	local parts = table.create(#names)
	for _, n in ipairs(names) do
		local m = f:FindFirstChild(n)
		if not m then return nil end
		table.insert(parts, require(m :: ModuleScript) :: any)
	end
	return decode(table.concat(parts))
end

local function rgb8(r: number, g: number, b: number): Color3 return Color3.fromRGB(r, g, b) end
MapScene.rgb8 = rgb8
function MapScene.color(t: { number }): Color3 return Color3.fromRGB(t[1], t[2], t[3]) end

-- ---------- primitives (62 octets chacune, voir tools/scene_to_lua.py) ----------
local primCache: { [string]: { Prim } } = {}
function MapScene.prims(id: string): { Prim }
	if primCache[id] then return primCache[id] end
	local info = MapScene.info(id)
	local list: { Prim } = {}
	local buf = info and blob(id, info.prims)
	if buf then
		local n = buffer.len(buf) // 62
		for i = 0, n - 1 do
			local o = i * 62
			local f = function(k: number) return buffer.readf32(buf, o + 2 + k * 4) end
			local q = function(k: number) return buffer.readi16(buf, o + 38 + k * 2) / 32767 end
			local mats = table.create(6)
			for k = 0, 5 do local v = buffer.readu16(buf, o + 46 + k * 2); mats[k + 1] = if v == 65535 then -1 else v + 1 end
			local flags = buffer.readu8(buf, o + 1)
			local col: Color3? = nil
			if bit32.band(flags, 4) ~= 0 then col = rgb8(buffer.readu8(buf, o + 58), buffer.readu8(buf, o + 59), buffer.readu8(buf, o + 60)) end
			list[i + 1] = { kind = buffer.readu8(buf, o), flags = flags, pos = Vector3.new(f(0), f(1), f(2)), size = Vector3.new(f(3), f(4), f(5)),
				tile = Vector3.new(f(6), f(7), f(8)), rot = CFrame.new(0, 0, 0, q(0), q(1), q(2), q(3)), mats = mats, color = col }
		end
	end
	primCache[id] = list
	return list
end

-- ---------- maillages : buffer brut (décodé par MapDetailController) ----------
function MapScene.meshBlob(id: string): buffer?
	local info = MapScene.info(id)
	return info and blob(id, info.meshes)
end

-- ---------- textures ----------
local texCache: { [string]: Tex | false } = {}
function MapScene.texture(tid: string): Tex?
	local c = texCache[tid]
	if c ~= nil then return if c then c :: any else nil end
	local folder = root and root:FindFirstChild("_Tex")
	local m = folder and folder:FindFirstChild(tid)
	if not m then texCache[tid] = false; return nil end
	local d = require(m :: ModuleScript) :: any
	local s = d.px :: string
	if d.parts > 1 then
		local parts = { s }
		for k = 2, d.parts do
			local more = (folder :: Instance):FindFirstChild(tid .. "_" .. k)
			if more then table.insert(parts, require(more :: ModuleScript) :: any) end
		end
		s = table.concat(parts)
	end
	local px = decode(s)
	local w, h = d.w :: number, d.h :: number
	local out = buffer.create(w * h * 4)
	if d.fmt == "g" then        -- gris (détail du sol) : canal R = gris, alpha 255
		for i = 0, w * h - 1 do
			local g = buffer.readu8(px, i)
			buffer.writeu8(out, i * 4, g); buffer.writeu8(out, i * 4 + 1, g); buffer.writeu8(out, i * 4 + 2, g); buffer.writeu8(out, i * 4 + 3, 255)
		end
	else
		local pal = decode(d.pal)
		local stride = if d.fmt == "pa" then 4 else 3
		for i = 0, w * h - 1 do
			local k = buffer.readu8(px, i) * stride
			buffer.writeu8(out, i * 4, buffer.readu8(pal, k)); buffer.writeu8(out, i * 4 + 1, buffer.readu8(pal, k + 1)); buffer.writeu8(out, i * 4 + 2, buffer.readu8(pal, k + 2))
			buffer.writeu8(out, i * 4 + 3, if stride == 4 then buffer.readu8(pal, k + 3) else 255)
		end
	end
	local t: Tex = { w = w, h = h, fmt = d.fmt, kind = d.kind, avg = rgb8(d.avg[1], d.avg[2], d.avg[3]), rgba = out }
	texCache[tid] = t
	return t
end

-- genre de texture du web (« leafbroad », « plaster »…) sans décoder les pixels
function MapScene.texKind(tid: string): string?
	local folder = root and root:FindFirstChild("_Tex")
	local m = folder and folder:FindFirstChild(tid)
	if not m then return nil end
	local d = require(m :: ModuleScript) :: any
	return if type(d) == "table" and type(d.kind) == "string" then d.kind else nil
end

-- matériau Roblox du sol d'une carte, choisi comme groundKind() du web (40c_ground.js) : son relief se voit sous la
-- texture du web, comme le relief du sol du web ; outer : grand sol extérieur sans texture
function MapScene.groundMaterial(theme: string?, base: string?, outer: boolean): Enum.Material
	if theme == "jungle" then return if outer then Enum.Material.Grass else Enum.Material.Ground end
	if base == "sand" then return Enum.Material.Sand end
	if base == "snow" then return Enum.Material.Snow end
	if base == "haunt" then return Enum.Material.Ground end
	return Enum.Material.Concrete
end

-- matériau Roblox (nom d'Enum.Material) avec repli
function MapScene.material(name: string): Enum.Material
	local ok, m = pcall(function() return (Enum.Material :: any)[name] end)
	return if ok and m then m else Enum.Material.SmoothPlastic
end

-- ---------- matériaux Roblox haute définition (PBR) à la place des textures floues du web ----------
-- Les textures canvas du web sont exportées en 43 à 128 px : posées en Texture sur des blocs de plusieurs mètres, elles
-- sont floues. Quand une texture n'est qu'un motif de surface (enduit, briques, planches, béton, tôle rouillée, tuiles…),
-- le bloc prend plutôt le matériau PBR de Roblox équivalent (relief, rugosité et reflets nets à toute distance), teinté de
-- la couleur moyenne de la texture (avg). Les textures qui portent un dessin restent posées : conteneurs marqués, caisses
-- « FRAGILE », façades avec fenêtres, rame du métro, bottes de foin, panneaux, feuillages découpés, sol avec les sites.
-- Caisses, planchers et cabanes « découpés » sur le web sont en fait opaques (94 à 100 % des pixels) : bois plein.
local HD: { [string]: string } = {
	plaster = "Plaster", crate = "WoodPlanks", stone = "Brick", plat = "Pavement", roof = "ClayRoofTiles", pillar = "Sandstone",
	conc = "Concrete", platI = "DiamondPlate", pillarI = "Concrete", wceil = "WoodPlanks", corrug = "CorrodedMetal", rock = "Rock",
	cabin = "WoodPlanks", snowb = "Snow", wdeck = "WoodPlanks", deck = "WoodPlanks", pole = "Wood", bark = "Wood", brick = "Brick",
	tomb = "Slate", shelf = "WoodPlanks", barrel = "Metal",
}
local hdCache: { [string]: Enum.Material | false } = {}
-- matériau PBR qui remplace la texture du web de ce matériau ; nil : pas de texture, ou une texture à dessin gardée
function MapScene.hdMaterial(m: Mat): Enum.Material?
	local tid = m.tex
	if not tid then return nil end
	local c = hdCache[tid]
	if c == nil then
		local k = MapScene.texKind(tid)
		local name = if k then HD[k] else nil
		local mat: Enum.Material | false = if name then MapScene.material(name) else false
		hdCache[tid] = mat
		c = mat
	end
	if c == false or c == nil then return nil end
	return c :: any
end

-- calque d'ombres cuites du web (texture noire découpée de 128 px posée sur tout le sol) : très flou, et l'éclairage
-- Future de Roblox fait déjà les vraies ombres ; on l'éclaircit
function MapScene.isBakedShadow(m: Mat): boolean
	return m.cut == true and m.tex ~= nil and m.avg[1] + m.avg[2] + m.avg[3] < 6 and MapScene.texKind(m.tex :: string) == "misc"
end

-- bloc uni du web en plastique lisse : matériau d'après sa couleur ; nil : inchangé. Mesuré sur les 10 cartes : surtout
-- les chaperons et socles des murs (gris -> béton, beige des cartes de sable -> grès) et les poutres (brun foncé -> bois)
function MapScene.guessMaterial(c: Color3): Enum.Material?
	local h, s, v = c:ToHSV()
	if s < 0.16 and v > 0.18 and v < 0.85 then return Enum.Material.Concrete end
	if h > 0.03 and h < 0.12 and s > 0.45 and v > 0.12 and v < 0.45 then return Enum.Material.Wood end
	if h > 0.07 and h < 0.14 and s > 0.2 and s < 0.5 and v > 0.4 then return Enum.Material.Sandstone end
	return nil
end

-- matériau principal d'un bloc (première face non vide, dans l'ordre des côtés puis dessus et dessous)
function MapScene.faceMain(p: Prim): number
	for _, k in ipairs({ 1, 2, 5, 6, 3, 4 }) do if p.mats[k] > 0 then return p.mats[k] end end
	return -1
end

-- légère variation de teinte d'un bloc (n : numéro stable) : deux murs voisins ne sont jamais exactement pareils
function MapScene.vary(c: Color3, n: number): Color3
	local k = 1 + ((n * 7919) % 101 / 101 - 0.5) * 0.07
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

return MapScene
