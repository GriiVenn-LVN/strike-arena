--!strict
-- ReplicatedStorage/Shared/VehicleModels (ModuleScript, côté client + Studio)
-- Les véhicules des arrivées du jeu web (src/65_cine.js, src/65b_car.js), pour CinematicController :
--   « heli »                    hélicoptère de transport, construit pièce par pièce comme makeHeli() du web
--                               (le web le fabrique aussi en blocs, cylindres et silhouettes extrudées) ;
--   « blinde », « camion_sable », « camion_vert »   véhicules Blender du web (models/vehicles/*.glb),
--                               exportés par tools/export_vehicles_lua.py dans VehicleMeshes/<véhicule>.
-- Les maillages des véhicules sont envoyés une fois par ServerStorage/MeshUploader (clés « v:… », MeshAssets) ;
-- tant qu'ils ne le sont pas, le véhicule est monté en Parts, une par objet du modèle Blender (VehicleMeshes/*/Info
-- « boxes ») : même silhouette, mêmes couleurs, aucune EditableMesh chez le joueur.
--
-- build(kind) -> Vehicle : toutes les pièces sont ancrées, sans collision ; place(v, cf, poses) les pose chaque image.
--   cf    = repère du véhicule dans le monde (studs, avant = -Z, plancher du web à info.CF mètres au-dessus)
--   poses = { [pièce] = CFrame } rotation locale d'une pièce animée autour de son pivot
--           (door_L, door_R, tailgate, wheel_FL/FR/RL/RR ; rotor, tail pour l'hélicoptère)
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MeshStore = require(ReplicatedStorage.Shared.MeshStore)
local decode = require(ReplicatedStorage.Shared.Base64)

local VM = {}
local U = Config.STUDS_PER_METER

export type Piece = { parts: { BasePart }, offs: { CFrame }, pivot: CFrame }
export type Vehicle = {
	kind: string, model: Model, info: any,
	static: Piece, pieces: { [string]: Piece },
	beacons: { { BasePart } },           -- gyrophares (bleu, rouge) ou feu anticollision de l'hélicoptère
	screens: { BasePart },               -- écrans du tableau de bord (hélicoptère)
	CF: number, CW: number, Z1: number,  -- plancher, demi-largeur, arrière de la cellule (mètres, comme userData du web)
	wheelR: number, meshes: boolean,
}

-- ---------- apparence des matériaux (vehMat() du web : les textures du jeu deviennent des matériaux Roblox) ----------
local function rgb(h: number): Color3 return Color3.fromRGB(bit32.rshift(h, 16), bit32.band(bit32.rshift(h, 8), 255), bit32.band(h, 255)) end
type Look = { color: Color3, material: Enum.Material, alpha: number?, refl: number?, neon: boolean? }
local function lookOf(kind: string, mat: string, m: any): Look
	local sand = kind == "camion_sable"
	if mat == "paint" then
		return { color = if kind == "blinde" then rgb(0x2c312e) elseif sand then rgb(0xa08f68) else rgb(0x5c6650),
			material = if kind == "blinde" then Enum.Material.DiamondPlate else Enum.Material.Metal }
	elseif mat == "tarp" then return { color = if sand then rgb(0xb4a37c) else rgb(0x5d6648), material = Enum.Material.Fabric }
	elseif mat == "inner" then return { color = rgb(0x4a4f55), material = Enum.Material.Metal }
	elseif mat == "floor" then return { color = rgb(0x2a2c2b), material = Enum.Material.DiamondPlate }
	elseif mat == "wood" then return { color = rgb(0x7a5a3a), material = Enum.Material.WoodPlanks }
	elseif mat == "glass" then return { color = rgb(0x1a2630), material = Enum.Material.Glass, alpha = 0.6, refl = 0.2 }
	elseif mat == "headlight" then return { color = rgb(0xfff4dd), material = Enum.Material.Neon, neon = true }
	elseif mat == "taillight" then return { color = rgb(0xd01a0c), material = Enum.Material.Neon, neon = true }
	elseif mat == "amber" then return { color = rgb(0xff8a10), material = Enum.Material.Neon, neon = true }
	elseif mat == "beacon_L" then return { color = rgb(0x001a55), material = Enum.Material.SmoothPlastic }
	elseif mat == "beacon_R" then return { color = rgb(0x550000), material = Enum.Material.SmoothPlastic }
	elseif mat == "chrome" then return { color = rgb(0xb8bcc0), material = Enum.Material.Metal, refl = 0.25 }
	elseif mat == "rubber" then return { color = rgb(0x151515), material = Enum.Material.SmoothPlastic }
	elseif mat == "seat" or mat == "gear" then
		local c = m and m.color or { 60, 60, 60 }
		return { color = Color3.fromRGB(c[1], c[2], c[3]), material = Enum.Material.Fabric }
	end
	local c = m and m.color or { 60, 60, 60 }
	return { color = Color3.fromRGB(c[1], c[2], c[3]), material = if m and (m.metal or 0) > 0.25 then Enum.Material.Metal else Enum.Material.SmoothPlastic }
end

local function styled(p: BasePart, lk: Look)
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Massless = true
	p.Color = lk.color; p.Material = lk.material
	p.Transparency = lk.alpha or 0; p.Reflectance = lk.refl or 0
	p.CastShadow = (lk.alpha or 0) == 0 and not lk.neon
end

local function newPiece(pivot: CFrame): Piece return { parts = {}, offs = {}, pivot = pivot } end
local function addTo(pc: Piece, p: BasePart, off: CFrame, model: Model)
	table.insert(pc.parts, p); table.insert(pc.offs, off); p.Parent = model
end

-- ==========================================================================================
-- Véhicules Blender (VehicleMeshes)
-- ==========================================================================================
local function infoOf(file: string): (any, Instance?)
	local folder = ReplicatedStorage.Shared:FindFirstChild("VehicleMeshes")
	local f = folder and folder:FindFirstChild(file)
	local im = f and f:FindFirstChild("Info")
	if not (f and im and im:IsA("ModuleScript")) then return nil, nil end
	return require(im :: ModuleScript) :: any, f
end
local function fileOf(kind: string): string return if string.sub(kind, 1, 6) == "camion" then "camion" else kind end
local function keyOf(file: string, g: any): string return "v:" .. file .. ":" .. g.piece .. ":" .. g.mat .. "/" .. g.nv .. "/" .. g.nt end

-- maillage d'un groupe (EditableMesh, seulement pour l'envoi depuis Studio ou si la clé est déjà envoyée)
local function meshOf(file: string, folder: Instance, info: any, g: any): (MeshPart, EditableMesh?)
	local center = Vector3.new(g.center[1], g.center[2], g.center[3])
	local mp, em0 = MeshStore.meshPart(keyOf(file, g), function()
		local src = folder:FindFirstChild(g.mod) :: ModuleScript
		local raw = decode(require(src) :: any)
		local k = 1 / info.Q
		local em = AssetService:CreateEditableMesh({ FixedSize = false })
		if not em then error("mémoire des maillages pleine (CreateEditableMesh a renvoyé nil)") end
		local pos = table.create(g.nv)
		local vid, nid = table.create(g.nv), table.create(g.nv)
		local nb = g.nv * 6
		for i = 0, g.nv - 1 do
			local v = Vector3.new(buffer.readi16(raw, i * 6), buffer.readi16(raw, i * 6 + 2), buffer.readi16(raw, i * 6 + 4)) * k
			local n = Vector3.new(buffer.readi8(raw, nb + i * 3), buffer.readi8(raw, nb + i * 3 + 1), buffer.readi8(raw, nb + i * 3 + 2))
			pos[i + 1] = v
			vid[i + 1] = em:AddVertex(v - center)
			nid[i + 1] = em:AddNormal(if n.Magnitude > 1e-3 then n.Unit else Vector3.yAxis)
		end
		local tb = nb + g.nv * 3
		for t = 0, g.nt - 1 do
			local a = buffer.readu16(raw, tb + t * 6) + 1
			local b = buffer.readu16(raw, tb + t * 6 + 2) + 1
			local c = buffer.readu16(raw, tb + t * 6 + 4) + 1
			local face = em:AddTriangle(vid[a], vid[b], vid[c])
			em:SetFaceNormals(face, { nid[a], nid[b], nid[c] })
			-- coordonnées de texture en projection cubique, comme vehBoxUV() du web (0,5 répétition par mètre)
			local fn = (pos[b] - pos[a]):Cross(pos[c] - pos[a])
			local ax, ay, az = math.abs(fn.X), math.abs(fn.Y), math.abs(fn.Z)
			local uvs = table.create(3)
			for j, v in ipairs({ pos[a], pos[b], pos[c] }) do
				local u, w
				if ax >= ay and ax >= az then u, w = v.Z, v.Y elseif ay >= az then u, w = v.X, v.Z else u, w = v.X, v.Y end
				uvs[j] = em:AddUV(Vector2.new(u * 0.5, w * 0.5))
			end
			em:SetFaceUVs(face, uvs)
		end
		return em
	end)
	mp.Size = mp.Size * U
	return mp, em0
end

-- tous les maillages du véhicule sont envoyés ?
local function meshesReady(file: string, info: any): boolean
	if MeshStore.uploader then return true end
	for _, g in ipairs(info.groups) do if not MeshStore.ids[keyOf(file, g)] then return false end end
	return true
end

local function buildBlender(kind: string): Vehicle?
	local file = fileOf(kind)
	local info, folder = infoOf(file)
	if not info or not folder then return nil end
	local model = Instance.new("Model"); model.Name = "Vehicule_" .. kind
	local v: Vehicle = {
		kind = kind, model = model, info = info, static = newPiece(CFrame.identity), pieces = {}, beacons = { {}, {} }, screens = {},
		CF = info.CF, CW = info.W, Z1 = info.rear, wheelR = info.wheelR or 0.5, meshes = false,
	}
	for name, p in pairs(info.pivots) do v.pieces[name] = newPiece(CFrame.new(p[1] * U, p[2] * U, p[3] * U)) end
	local wheels = {}
	for name, pc in pairs(v.pieces) do if string.sub(name, 1, 6) == "wheel_" then table.insert(wheels, pc) end end
	local function put(piece: string, p: BasePart, off: CFrame, mat: string)
		if piece == "wheel" then
			for i, pc in ipairs(wheels) do
				local q = if i == 1 then p else p:Clone()
				addTo(pc, q, off, model)
			end
		else
			addTo(v.pieces[piece] or v.static, p, off, model)
		end
		if mat == "beacon_L" then table.insert(v.beacons[1], p) elseif mat == "beacon_R" then table.insert(v.beacons[2], p) end
	end
	-- 1) maillages envoyés (ou envoi en cours depuis Studio)
	if meshesReady(file, info) then
		local ok, err = pcall(function()
			for _, g in ipairs(info.groups) do
				local mp = meshOf(file, folder, info, g)
				mp.Name = g.piece .. "_" .. g.mat
				styled(mp, lookOf(kind, g.mat, info.mats[g.mat]))
				put(g.piece, mp, CFrame.new(g.center[1] * U, g.center[2] * U, g.center[3] * U), g.mat)
			end
		end)
		if ok then v.meshes = true; return v end
		warn("[VehicleModels] " .. kind .. " en pièces : " .. tostring(err))
		model:ClearAllChildren()
		v.static = newPiece(CFrame.identity); v.beacons = { {}, {} }
		for name, pc in pairs(v.pieces) do pc.parts = {}; pc.offs = {}; v.pieces[name] = pc end
	end
	-- 2) version en pièces : une Part par objet du modèle Blender
	for _, b in ipairs(info.boxes) do
		local p = Instance.new("Part")
		p.Name = b.p .. "_" .. b.m
		p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
		if b.cyl then p.Shape = Enum.PartType.Cylinder end
		p.Size = Vector3.new(b.s[1], b.s[2], b.s[3]) * U
		styled(p, lookOf(kind, b.m, info.mats[b.m]))
		local off = CFrame.new(b.c[1] * U, b.c[2] * U, b.c[3] * U)
		if b.r then local r = b.r; off = CFrame.new(b.c[1] * U, b.c[2] * U, b.c[3] * U, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9]) end
		put(b.p, p, off, b.m)
	end
	return v
end

-- ==========================================================================================
-- Hélicoptère (makeHeli() de src/65_cine.js, mêmes cotes)
-- ==========================================================================================
local HCF, HCR, HCZ0, HCZ1, HCW = -0.9, 1.15, -1.7, 1.9, 1.25   -- plancher, toit, avant, arrière, demi-largeur

-- triangle plein en deux coins (WedgePart), épaisseur le long de sa normale
local function triangle(a: Vector3, b: Vector3, c: Vector3, thick: number, lk: Look, add: (BasePart, CFrame) -> ())
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then c, a = a, c elseif acd > bcd and acd > abd then a, b = b, a end
	ab, ac, bc = b - a, c - a, c - b
	if ac:Cross(ab).Magnitude < 1e-6 then return end
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	for i = 1, 2 do
		local w = Instance.new("WedgePart")
		w.TopSurface = Enum.SurfaceType.Smooth; w.BottomSurface = Enum.SurfaceType.Smooth
		styled(w, lk)
		if i == 1 then
			w.Size = Vector3.new(thick, math.max(height, 0.05), math.max(math.abs(ab:Dot(back)), 0.05))
			add(w, CFrame.fromMatrix((a + b) / 2, right, up, back))
		else
			w.Size = Vector3.new(thick, math.max(height, 0.05), math.max(math.abs(ac:Dot(back)), 0.05))
			add(w, CFrame.fromMatrix((a + c) / 2, -right, up, -back))
		end
	end
end

local function buildHeli(): Vehicle
	local model = Instance.new("Model"); model.Name = "Vehicule_heli"
	local v: Vehicle = {
		kind = "heli", model = model, info = nil, static = newPiece(CFrame.identity), pieces = {}, beacons = { {} }, screens = {},
		CF = HCF, CW = HCW, Z1 = HCZ1, wheelR = 0.27, meshes = false,
	}
	v.pieces.rotor = newPiece(CFrame.new(0, (HCR + 1.28) * U, 0.1 * U))
	v.pieces.tail = newPiece(CFrame.new(-0.22 * U, 1.9 * U, 9.75 * U))
	local BODY: Look = { color = rgb(0x4d5a3c), material = Enum.Material.Metal }
	local DARK: Look = { color = rgb(0x22262a), material = Enum.Material.Metal }
	local BLACK: Look = { color = rgb(0x111214), material = Enum.Material.SmoothPlastic }
	local INNER: Look = { color = rgb(0x4a3a36), material = Enum.Material.Metal }        -- éclairé en rouge comme le web
	local FLOOR: Look = { color = rgb(0x2a2c2b), material = Enum.Material.DiamondPlate }
	local SEAT: Look = { color = rgb(0x5a5040), material = Enum.Material.Fabric }
	local STRAP: Look = { color = rgb(0x7a2a22), material = Enum.Material.Fabric }
	local GLASS: Look = { color = rgb(0x8fb8d8), material = Enum.Material.Glass, alpha = 0.72, refl = 0.15 }
	local YEL: Look = { color = rgb(0xd8c020), material = Enum.Material.SmoothPlastic }
	local function into(pc: Piece): (BasePart, CFrame) -> ()
		return function(p: BasePart, off: CFrame) addTo(pc, p, off, model) end
	end
	local addS = into(v.static)
	-- bloc : rb(l, h, p, matière, x, y, z, arrondi, rx, ry, rz) du web, en mètres
	local function rb(w: number, h: number, d: number, lk: Look, x: number, y: number, z: number, rx: number?, ry: number?, rz: number?, add: ((BasePart, CFrame) -> ())?): BasePart
		local p = Instance.new("Part")
		p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
		p.Size = Vector3.new(math.max(w, 0.02), math.max(h, 0.02), math.max(d, 0.02)) * U
		styled(p, lk)
		local put: (BasePart, CFrame) -> () = add or addS
		put(p, CFrame.new(x * U, y * U, z * U) * CFrame.Angles(rx or 0, ry or 0, rz or 0))
		return p
	end
	-- cylindre le long de z : cz(rayon avant, rayon arrière, longueur…) du web (rayon moyen : Roblox ne fait pas de cône)
	local function cz(r1: number, r2: number, len: number, lk: Look, x: number, y: number, z: number, add: ((BasePart, CFrame) -> ())?): BasePart
		local p = Instance.new("Part"); p.Shape = Enum.PartType.Cylinder
		local r = (r1 + r2) / 2
		p.Size = Vector3.new(len, r * 2, r * 2) * U
		styled(p, lk)
		local put: (BasePart, CFrame) -> () = add or addS
		put(p, CFrame.new(x * U, y * U, z * U) * CFrame.Angles(0, math.pi / 2, 0))
		return p
	end
	-- cylindre le long de x (roues)
	local function cx(r: number, len: number, lk: Look, x: number, y: number, z: number)
		local p = Instance.new("Part"); p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(len, r * 2, r * 2) * U
		styled(p, lk); addS(p, CFrame.new(x * U, y * U, z * U))
	end
	-- silhouette (z, y) extrudée sur x : polyZY() du web, en éventail de triangles
	local function polyZY(pts: { { number } }, thick: number, lk: Look)
		local a = Vector3.new(0, pts[1][2], pts[1][1]) * U
		for i = 2, #pts - 1 do
			triangle(a, Vector3.new(0, pts[i][2], pts[i][1]) * U, Vector3.new(0, pts[i + 1][2], pts[i + 1][1]) * U, thick * U, lk, addS)
		end
	end
	local CF, CR, CZ0, CZ1, CW = HCF, HCR, HCZ0, HCZ1, HCW
	local mid, len = (CZ0 + CZ1) / 2, CZ1 - CZ0
	-- --- cabine : panneaux séparés pour que l'intérieur soit visible ---
	rb(CW * 2 + 0.1, 0.12, len, DARK, 0, CF - 0.06, mid)                 -- dessous
	rb(CW * 2 - 0.1, 0.04, len - 0.1, FLOOR, 0, CF + 0.02, mid)          -- plancher antidérapant
	rb(CW * 2 + 0.1, 0.14, len + 0.1, BODY, 0, CR + 0.07, mid)           -- toit
	rb(CW * 2 - 0.1, 0.03, len - 0.2, INNER, 0, CR - 0.02, mid)          -- plafond intérieur
	rb(CW * 2 + 0.1, CR - CF + 0.1, 0.12, BODY, 0, (CR + CF) / 2, CZ1)   -- cloison arrière
	rb(CW * 2 - 0.1, CR - CF - 0.1, 0.03, INNER, 0, (CR + CF) / 2, CZ1 - 0.08)
	for _, s in ipairs({ -1, 1 }) do
		-- flancs : montants avant/arrière des portes + bandeau au-dessus
		rb(0.1, CR - CF, 0.5, BODY, s * CW, (CR + CF) / 2, CZ0 + 0.25); rb(0.1, CR - CF, 0.32, BODY, s * CW, (CR + CF) / 2, CZ1 - 0.16)
		rb(0.1, 0.32, len, BODY, s * CW, CR - 0.16, mid)
		rb(0.03, CR - CF - 0.1, 0.26, INNER, s * (CW - 0.07), (CR + CF) / 2, CZ1 - 0.2)
		-- porte coulissante repoussée vers l'arrière, à l'extérieur, avec hublot
		local dy, dz = (CR + CF) / 2 - 0.08, CZ1 + 0.55
		rb(0.06, CR - CF - 0.3, 1.7, BODY, s * (CW + 0.1), dy, dz); rb(0.065, 0.42, 0.5, GLASS, s * (CW + 0.1), dy + 0.32, dz - 0.2)
		rb(0.05, 0.05, len + 1.4, DARK, s * (CW + 0.04), CR - 0.34, CZ1 - 0.3)   -- rail de porte
		for z = -1.2, 1.3, 0.6 do rb(0.03, 0.12, 0.03, BLACK, s * (CW - 0.3), CR - 0.1, z) end   -- poignées de maintien
	end
	-- bancs (dossiers sangles rouges) : arrière face à l'avant, avant face à l'arrière
	rb(2.2, 0.08, 0.5, SEAT, 0, CF + 0.48, 1.45); rb(2.2, 0.6, 0.06, STRAP, 0, CF + 0.85, 1.73)
	rb(1.5, 0.08, 0.45, SEAT, 0, CF + 0.48, -1.42); rb(1.5, 0.6, 0.06, STRAP, 0, CF + 0.85, -1.66)
	for _, x in ipairs({ -1, -0.35, 0.35, 1 }) do rb(0.04, 0.46, 0.04, BLACK, x, CF + 0.23, 1.45) end
	for _, x in ipairs({ -0.6, 0.6 }) do rb(0.04, 0.46, 0.04, BLACK, x, CF + 0.23, -1.42) end
	-- filet de chargement et extincteur sur la cloison arrière
	for i = 0, 4 do rb(1.6, 0.015, 0.015, BLACK, 0, CR - 0.65 + i * 0.1, CZ1 - 0.13) end
	for i = 0, 8 do rb(0.015, 0.5, 0.015, BLACK, -0.8 + i * 0.2, CR - 0.45, CZ1 - 0.13) end
	cz(0.07, 0.07, 0.4, { color = rgb(0xb01e1e), material = Enum.Material.SmoothPlastic }, 1.0, CF + 0.6, CZ1 - 0.18)
	-- lumière de cabine rouge
	for _, z in ipairs({ -0.8, 0.9 }) do
		local l = rb(0.25, 0.04, 0.12, { color = rgb(0xff2a1a), material = Enum.Material.Neon, neon = true }, 0, CR - 0.03, z)
		local pl = Instance.new("PointLight"); pl.Color = rgb(0xff3020); pl.Brightness = 1.6; pl.Range = 2.6 * U; pl.Parent = l
	end
	-- --- cockpit : nez bas plein + verrière vitrée, pilotes visibles depuis la cabine ---
	polyZY({ { CZ0, CF - 0.12 }, { -3.4, CF - 0.05 }, { -4.15, -0.45 }, { -4.3, 0.05 }, { CZ0, 0.05 } }, CW * 2 - 0.05, BODY)
	polyZY({ { CZ0, 0.05 }, { -4.3, 0.05 }, { -3.75, 0.75 }, { -2.9, 1.12 }, { CZ0, CR + 0.12 } }, CW * 2 - 0.14, GLASS)
	for _, s in ipairs({ -1, 1 }) do   -- montants de verrière
		rb(0.08, 0.08, 1.4, DARK, s * (CW - 0.08), 0.92, -3.25, -0.5); rb(0.08, 0.9, 0.08, DARK, s * (CW - 0.08), 0.55, -2.15)
		rb(0.08, 0.08, 1.15, DARK, s * (CW - 0.08), 0.1, -3.6)
	end
	rb(0.07, 0.07, 1.6, DARK, 0, 0.95, -3.2, -0.45); rb(CW * 2 - 0.1, 0.1, 0.1, DARK, 0, CR + 0.06, CZ0 - 0.02)
	-- tableau de bord + écrans
	rb(2.0, 0.36, 0.35, BLACK, 0, 0.1, -3.45, -0.3)
	for _, x in ipairs({ -0.7, -0.25, 0.25, 0.7 }) do
		local sc = rb(0.28, 0.2, 0.02, { color = if x < 0 then rgb(0x3cff8a) else rgb(0xffb040), material = Enum.Material.Neon, neon = true }, x, 0.2, -3.27, -0.3)
		table.insert(v.screens, sc)
	end
	-- sièges pilotes
	for _, x in ipairs({ -0.55, 0.55 }) do
		rb(0.5, 0.1, 0.5, SEAT, x, CF + 0.5, -2.45); rb(0.5, 0.75, 0.1, SEAT, x, CF + 0.9, -2.2); rb(0.08, 0.5, 0.08, BLACK, x, CF + 0.25, -2.45)
	end
	-- --- moteurs, mât, rotor ---
	rb(1.5, 0.55, 3.0, BODY, 0, CR + 0.42, 0.4)
	for _, s in ipairs({ -1, 1 }) do cz(0.28, 0.32, 2.2, BODY, s * 0.55, CR + 0.55, 0.6); cz(0.22, 0.18, 0.5, BLACK, s * 0.62, CR + 0.6, 1.85) end
	cz(0.12, 0.12, 0.25, BLACK, 0, CR + 0.45, -1.1)
	do
		local mast = Instance.new("Part"); mast.Shape = Enum.PartType.Cylinder; mast.Size = Vector3.new(0.6, 0.31, 0.31) * U
		styled(mast, DARK); addS(mast, CFrame.new(0, (CR + 0.95) * U, 0.1 * U) * CFrame.Angles(0, 0, math.pi / 2))
	end
	local addR = into(v.pieces.rotor)
	do
		local hub = Instance.new("Part"); hub.Shape = Enum.PartType.Cylinder; hub.Size = Vector3.new(0.18, 0.6, 0.6) * U
		styled(hub, DARK); addR(hub, CFrame.Angles(0, 0, math.pi / 2))
		for i = 0, 3 do
			local a = i * math.pi / 2
			local arm = CFrame.Angles(0, a, 0)
			local bl = Instance.new("Part"); bl.Size = Vector3.new(0.42, 0.05, 7.6) * U; styled(bl, BLACK)
			addR(bl, arm * CFrame.new(0, -0.03 * U, 3.9 * U) * CFrame.Angles(-0.012, 0, 0))
			local tip = Instance.new("Part"); tip.Size = Vector3.new(0.2, 0.04, 0.14) * U; styled(tip, YEL)
			addR(tip, arm * CFrame.new(0, -0.03 * U, 7.6 * U))
		end
		-- disque de flou des pales
		local blur = Instance.new("Part"); blur.Shape = Enum.PartType.Cylinder; blur.Size = Vector3.new(0.02, 15.6, 15.6) * U
		styled(blur, { color = rgb(0x111111), material = Enum.Material.SmoothPlastic, alpha = 0.9 })
		addR(blur, CFrame.new(0, -0.03 * U, 0) * CFrame.Angles(0, 0, math.pi / 2))
	end
	-- --- poutre de queue, dérive, stabilisateur, rotor de queue ---
	polyZY({ { CZ1, CF + 0.02 }, { CZ1, CR + 0.2 }, { 3.4, CR + 0.05 }, { 4.2, 0.75 }, { 3.6, 0.15 } }, 1.5, BODY)
	cz(0.62, 0.26, 5.4, BODY, 0, 0.55, 6.4)
	polyZY({ { 8.6, 0.5 }, { 9.6, 2.1 }, { 10.1, 2.25 }, { 9.7, 0.55 }, { 9.1, 0.25 } }, 0.14, BODY)
	rb(3.0, 0.08, 0.75, BODY, 0, 0.55, 9.0)
	local addT = into(v.pieces.tail)
	for i = 0, 3 do rb(0.04, 1.5, 0.13, BLACK, 0, 0, 0, i * math.pi / 4, 0, 0, addT) end
	do
		local h = Instance.new("Part"); h.Shape = Enum.PartType.Cylinder; h.Size = Vector3.new(0.12, 0.16, 0.16) * U
		styled(h, DARK); addT(h, CFrame.identity)
	end
	-- antennes, marchepieds, train d'atterrissage
	rb(0.03, 0.5, 0.03, BLACK, 0.4, CR + 0.35, -1.0); rb(0.6, 0.03, 0.03, BLACK, 0, CF - 0.3, -3.2)
	for _, s in ipairs({ -1, 1 }) do
		rb(0.1, 0.05, 1.5, DARK, s * (CW + 0.12), CF - 0.18, -0.1)
		rb(0.08, 0.8, 0.08, DARK, s * 1.05, CF - 0.4, -2.6, 0, 0, s * 0.3)
		cx(0.27, 0.18, BLACK, s * 1.25, CF - 0.78, -2.6)
	end
	cx(0.16, 0.12, BLACK, 0, 0.05, 8.6); rb(0.06, 0.4, 0.06, DARK, 0, 0.25, 8.55)
	-- feux : phare, feux de position, feu anticollision qui clignote
	local function nav(c: number, x: number, y: number, z: number): BasePart
		local p = Instance.new("Part"); p.Shape = Enum.PartType.Ball; p.Size = Vector3.new(0.12, 0.12, 0.12) * U
		styled(p, { color = rgb(c), material = Enum.Material.Neon, neon = true }); addS(p, CFrame.new(x * U, y * U, z * U))
		return p
	end
	local spot = nav(0xffffff, 0, CF - 0.2, -3.9)
	local sl = Instance.new("SpotLight"); sl.Face = Enum.NormalId.Front; sl.Angle = 50; sl.Range = 14 * U; sl.Brightness = 1.2; sl.Parent = spot
	nav(0xff3030, -CW - 0.05, 0.1, -1.8); nav(0x30ff70, CW + 0.05, 0.1, -1.8)
	table.insert(v.beacons[1], nav(0xff2020, 0, CR + 0.3, 2.6))
	return v
end

-- ==========================================================================================
function VM.build(kind: string): Vehicle
	if kind ~= "heli" then
		local ok, v = pcall(buildBlender, kind)
		if ok and v then return v end
		if not ok then warn("[VehicleModels] " .. kind .. " : " .. tostring(v)) end
	end
	return buildHeli()
end

-- pose toutes les pièces : cf = repère du véhicule (studs), poses = rotations locales des pièces animées
function VM.place(v: Vehicle, cf: CFrame, poses: { [string]: CFrame }?)
	local parts: { BasePart } = {}
	local cfs: { CFrame } = {}
	local function piece(pc: Piece, base: CFrame)
		for i, p in ipairs(pc.parts) do table.insert(parts, p); table.insert(cfs, base * pc.offs[i]) end
	end
	piece(v.static, cf)
	for name, pc in pairs(v.pieces) do
		local r = poses and poses[name]
		piece(pc, cf * pc.pivot * (r or CFrame.identity))
	end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

-- gyrophares / feu anticollision : allumés (néon) ou éteints
function VM.setBeacon(v: Vehicle, i: number, on: boolean)
	local list = v.beacons[i]
	if not list then return end
	for _, p in ipairs(list) do
		if v.kind == "heli" then p.Transparency = if on then 0 else 0.85
		else
			p.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
			p.Color = if i == 1 then (if on then rgb(0x2a6bff) else rgb(0x001a55)) else (if on then rgb(0xff2a2a) else rgb(0x550000))
		end
	end
end

-- envoi depuis Studio (MeshUploader) : construit chaque maillage une fois, sans le garder
function VM.prebuildAll()
	for _, file in ipairs({ "blinde", "camion" }) do
		local info, folder = infoOf(file)
		if info and folder then
			for _, g in ipairs(info.groups) do
				local ok, err = pcall(function()
					local mp, em = meshOf(file, folder, info, g)
					mp:Destroy()
					if em then em:Destroy() end
				end)
				if not ok then warn("[VehicleModels] envoi " .. keyOf(file, g) .. " : " .. tostring(err)) end
			end
		end
	end
end

-- clés de maillage à envoyer (rapport, menu admin)
function VM.keys(): { string }
	local out = {}
	for _, file in ipairs({ "blinde", "camion" }) do
		local info = infoOf(file)
		if info then for _, g in ipairs(info.groups) do table.insert(out, keyOf(file, g)) end end
	end
	return out
end

return VM
