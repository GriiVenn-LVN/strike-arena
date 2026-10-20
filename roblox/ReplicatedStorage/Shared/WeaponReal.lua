--!strict
-- ReplicatedStorage/Shared/WeaponReal (ModuleScript, client + Studio)
-- Armes réalistes du jeu web (models/weapons_real : AK, M4 avec son viseur holographique, AWP, Desert Eagle ; Sketchfab,
-- CC BY, voir credits_real.json) : maillages lissés et textures d'origine (couleur, normales, métal, rugosité).
-- Comme sur le web (src/46_glb.js useRealGun), le modèle réaliste ne sert qu'avec la finition d'usine : un skin repasse
-- sur le modèle stylisé, qu'il sait peindre (WeaponModels.setVariant, appelé par SkinPaint.apply).
-- Chez le joueur, tout vient des assets envoyés une fois par ServerStorage/MeshUploader (étape « armes réalistes ») :
--   maillages « w:real:<arme>#<pièce>/<nv>/<nt> », images « i:wr:<arme>:<matériau>:c|n|m|r ».
-- Tant qu'une seule de ces clés manque dans MeshAssets, ready() répond false et l'arme stylisée reste en place.
-- Les données brutes (ServerStorage/WeaponRealData, tools/export_weapons_real_lua.py) ne sont lues que dans Studio.
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Info = require(ReplicatedStorage.Shared.WeaponInfoReal) :: { [string]: any }
local MeshStore = require(ReplicatedStorage.Shared.MeshStore)
local decode = require(ReplicatedStorage.Shared.Base64)

local WeaponReal = {}
WeaponReal.Info = Info
local Q, NQ, UVQ = 20000, 127, 8192            -- doivent correspondre à tools/export_weapons_real_lua.py
local KINDS = { "c", "n", "m", "r" }

function WeaponReal.meshKey(key: string, gi: number): string
	local g = Info[key].groups[gi]
	return "w:real:" .. key .. "#" .. gi .. "/" .. g.nv .. "/" .. g.nt
end
-- clé passée à MeshStore.image (qui ajoute « i: »)
function WeaponReal.imageKey(key: string, mi: number, kind: string): string
	return "wr:" .. key .. ":" .. mi .. ":" .. kind
end

-- toutes les clés de l'arme sont envoyées
local readyCache: { [string]: boolean } = {}
function WeaponReal.ready(key: string): boolean
	local inf = Info[key]
	if not inf then return false end
	if MeshStore.uploader then return false end
	local r = readyCache[key]
	if r ~= nil then return r end
	r = true
	for gi in ipairs(inf.groups) do if not MeshStore.ids[WeaponReal.meshKey(key, gi)] then r = false end end
	for mi in ipairs(inf.mats) do
		for _, k in ipairs(KINDS) do if not MeshStore.ids["i:" .. WeaponReal.imageKey(key, mi, k)] then r = false end end
	end
	if r then readyCache[key] = true end        -- « non » n'est pas gardé : un envoi en cours peut compléter MeshAssets
	return r
end

-- ---------- données brutes (Studio : envoi) ----------
type Raw = { info: any, blob: buffer }
local rawCache: { [string]: Raw | false } = {}
local function raw(key: string): Raw?
	local c = rawCache[key]
	if c ~= nil then return if c then c :: Raw else nil end
	local folder = ServerStorage:FindFirstChild("WeaponRealData")
	local f = folder and folder:FindFirstChild(key)
	local got: Raw | false = false
	if f then
		local info = require(f:FindFirstChild("Info") :: ModuleScript) :: any
		local parts = table.create(info.chunks)
		for i = 1, info.chunks do parts[i] = require(f:FindFirstChild("D" .. i) :: ModuleScript) :: any end
		got = { info = info, blob = decode(table.concat(parts)) }
	end
	rawCache[key] = got
	return if got then got :: Raw else nil
end

local function fillMesh(key: string, gi: number, center: Vector3): EditableMesh
	local r = raw(key)
	if not r then error("données de l'arme réaliste absentes (ServerStorage/WeaponRealData/" .. key .. ")") end
	local g = r.info.groups[gi]
	local b, o0 = r.blob, g.at[1]
	local em = AssetService:CreateEditableMesh({ FixedSize = false })
	if not em then error("mémoire des maillages pleine (CreateEditableMesh a renvoyé nil)") end
	local vid, nid, uid = table.create(g.nv), table.create(g.nv), table.create(g.nv)
	for i = 0, g.nv - 1 do
		local o = o0 + i * 14
		local p = Vector3.new(buffer.readi16(b, o), buffer.readi16(b, o + 2), buffer.readi16(b, o + 4)) / Q
		local n = Vector3.new(buffer.readi8(b, o + 6), buffer.readi8(b, o + 7), buffer.readi8(b, o + 8)) / NQ
		vid[i + 1] = em:AddVertex(p - center)
		nid[i + 1] = em:AddNormal(if n.Magnitude > 1e-3 then n.Unit else Vector3.yAxis)
		-- glTF et Roblox : (0, 0) = coin haut gauche de l'image, aucune inversion
		uid[i + 1] = em:AddUV(Vector2.new(buffer.readi16(b, o + 10) / UVQ, buffer.readi16(b, o + 12) / UVQ))
	end
	local t0 = o0 + g.nv * 14
	for t = 0, g.nt - 1 do
		local a = buffer.readu16(b, t0 + t * 6) + 1
		local c = buffer.readu16(b, t0 + t * 6 + 2) + 1
		local d = buffer.readu16(b, t0 + t * 6 + 4) + 1
		local f = em:AddTriangle(vid[a], vid[c], vid[d])
		em:SetFaceNormals(f, { nid[a], nid[c], nid[d] })      -- normales lissées du modèle (pas de facettes)
		em:SetFaceUVs(f, { uid[a], uid[c], uid[d] })
	end
	return em
end

-- image d'un matériau : JPEG décodé (ServerStorage/JpegDecode) ; carte de métal / rugosité en niveaux de gris
local function fillImage(key: string, mi: number, kind: string): EditableImage?
	local r = raw(key)
	local dec = ServerStorage:FindFirstChild("JpegDecode")
	if not r or not dec then return nil end
	local jpeg = require(dec :: ModuleScript) :: any
	local at = r.info.mats[mi][kind]
	local w, h, px = jpeg(r.blob, at[1], at[2])
	local e = AssetService:CreateEditableImage({ Size = Vector2.new(w, h) })
	e:WritePixelsBuffer(Vector2.zero, Vector2.new(w, h), px)
	return e
end

local images: { [string]: Content | false } = {}
function WeaponReal.image(key: string, mi: number, kind: string): Content?
	local k = WeaponReal.imageKey(key, mi, kind)
	local c = images[k]
	if c ~= nil then return if c then c :: Content else nil end
	if MeshStore.uploader and MeshStore.ids["i:" .. k] then return nil end      -- déjà envoyée : pas de décodage
	local ok, got, img = pcall(function() return MeshStore.image(k, function() return fillImage(key, mi, kind) end) end)
	if not ok and string.find(tostring(got), "trop d'échecs") then error(got) end      -- MeshUploader s'arrête
	-- pendant l'envoi : l'image est partie, on libère sa mémoire (EditableImage de 4 Mo)
	if MeshStore.uploader and ok and img then pcall(function() (img :: any):Destroy() end); got = nil end
	local res: Content | false = if ok and got then got :: Content else false
	if not MeshStore.uploader then images[k] = res end
	return if res then res :: Content else nil
end

-- ---------- pièces ----------
local pieceCache: { [string]: MeshPart } = {}
local function piece(key: string, gi: number): MeshPart
	local id = key .. "#" .. gi
	local mp = pieceCache[id]
	if mp then return mp end
	local g = Info[key].groups[gi]
	local center = Vector3.new(g.center[1], g.center[2], g.center[3])
	local made = MeshStore.meshPart(WeaponReal.meshKey(key, gi), function() return fillMesh(key, gi, center) end, MeshStore.PRECISE)
	pcall(function() (made :: any).DoubleSided = Info[key].mats[g.mat].double end)
	pieceCache[id] = made
	return made
end

-- Pièces de l'arme dans model (repère de la poignée Grip, échelle scale) ; opts.ret(optique) -> réticule du holo intégré
-- Renvoie la hauteur de la ligne de visée (mètres × échelle).
function WeaponReal.build(model: Model, grip: BasePart, key: string, scale: number, retOf: ((string) -> (string, string))?): number
	local inf = Info[key]
	for gi, g in ipairs(inf.groups) do
		local mp = piece(key, gi):Clone()
		mp.Size = (Vector3.new(g.size[1], g.size[2], g.size[3]) * scale):Max(Vector3.one * 0.001)
		local m = inf.mats[g.mat]
		mp.Name = "Real_" .. g.part .. "_" .. gi
		mp.Color = Color3.fromRGB(m.avg[1], m.avg[2], m.avg[3])
		mp.Material = if m.metal > 0.5 then Enum.Material.Metal else Enum.Material.SmoothPlastic
		-- couleur toujours posée (aperçus en ViewportFrame) ; normales, métal et rugosité dans le monde (WeaponMaterials)
		local col = WeaponReal.image(key, g.mat, "c")
		if col then mp.TextureContent = col end
		mp.Anchored = true; mp.CanCollide = false; mp.CanQuery = false; mp.CanTouch = false; mp.Massless = true; mp.CastShadow = false
		local off = CFrame.new(Vector3.new(g.center[1], g.center[2], g.center[3]) * scale)
		mp:SetAttribute("Piece", g.part); mp:SetAttribute("Role", "real"); mp:SetAttribute("RealMat", g.mat)
		mp:SetAttribute("Offset", off)
		if g.optic then mp:SetAttribute("BuiltinOptic", true) end
		mp.CFrame = grip.CFrame * off
		mp.Parent = model
	end
	-- viseur holographique intégré (M4) : réticule du holo (forme et couleur d'Arsenal › Viseurs) au milieu de la fenêtre
	if inf.optic then
		local shape, color = "dot", "red"
		if retOf then shape, color = retOf("holo") else
			local okA, A = pcall(require, ReplicatedStorage.Shared.Attachments)
			if okA then shape, color = (A :: any).retOf("holo", nil) end
		end
		local s = 0.015 * scale
		local p = Instance.new("Part"); p.Name = "Real_reticle"; p.Size = Vector3.new(s, s, 0.0002 * scale)
		p.Transparency = 1; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Massless = true; p.CastShadow = false
		local off = CFrame.new(Vector3.new(0, inf.sight, (inf.optic[1] + inf.optic[2]) / 2 + 0.01) * scale)
		p:SetAttribute("Piece", "body"); p:SetAttribute("Role", "att"); p:SetAttribute("Offset", off); p:SetAttribute("BuiltinOptic", true)
		p.CFrame = grip.CFrame * off
		local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Back; sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		sg.CanvasSize = Vector2.new(128, 128); sg.LightInfluence = 0; sg.Brightness = 2.5; sg.ClipsDescendants = true
		local holder = Instance.new("Frame"); holder.Size = UDim2.fromScale(1, 1); holder.BackgroundTransparency = 1; holder.Parent = sg
		local okR, RG = pcall(require, ReplicatedStorage.Shared.ReticleGui)
		if okR then pcall((RG :: any).draw, holder, 64, 64, 58, shape, color, false) end
		sg.Parent = p
		p.Parent = model
	end
	return inf.sight * scale
end

-- envoi depuis Studio (MeshUploader) : maillages et les quatre cartes de chaque matériau
function WeaponReal.uploadAll()
	for key, inf in pairs(Info) do
		for gi in ipairs(inf.groups) do piece(key, gi) end
		for mi in ipairs(inf.mats) do for _, k in ipairs(KINDS) do WeaponReal.image(key, mi, k) end end
	end
end

return WeaponReal
