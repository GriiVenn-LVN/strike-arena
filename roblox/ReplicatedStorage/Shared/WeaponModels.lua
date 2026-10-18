--!strict
-- ReplicatedStorage/Shared/WeaponModels (ModuleScript, côté client)
-- Fabrique les vraies armes du jeu web (modèles Low-Poly de TastyTony, CC BY) à partir des données de WeaponMeshes,
-- avec l'API EditableMesh : aucun fichier à importer dans Studio.
-- Il faut cocher « Allow Mesh / Image APIs » (Game Settings → Security) ; sinon une silhouette en blocs est utilisée.
--
-- build(clé, échelle) renvoie un Model :
--   PrimaryPart « Grip » = la poignée (main droite), l'arme pointe vers -Z, le haut vers +Y ;
--   chaque pièce porte l'attribut Piece = "body" | "bolt" | "mag" (le chargeur et la culasse bougent dans les animations) ;
--   attachments « Muzzle » (bout du canon) et « LeftHand » (main gauche) sur Grip.
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Info = require(ReplicatedStorage.Shared.WeaponInfo)

local WeaponModels = {}
WeaponModels.meshApi = true            -- passe à false si Roblox refuse EditableMesh (réglage non coché)
WeaponModels.Q = 30000                 -- doit correspondre à tools/export_weapons_lua.py

-- apparence par rôle de matériau (même découpage que glbRole() du jeu web)
local LOOK = {
	body = { color = Color3.fromRGB(38, 40, 45), material = Enum.Material.Metal },
	acc = { color = Color3.fromRGB(62, 64, 69), material = Enum.Material.SmoothPlastic },
	steel = { color = Color3.fromRGB(150, 153, 160), material = Enum.Material.Metal },
	wood = { color = Color3.fromRGB(122, 74, 42), material = Enum.Material.Wood },
}

local decode = require(ReplicatedStorage.Shared.Base64)

-- répétitions de la peinture par mètre d'arme (web : 1/0,78 × 1,35)
local UV_SCALE = 1.35 / 0.78

local function plain(name: string, size: Vector3, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part"); p.Name = name; p.Size = size; p.Color = color; p.Material = material
	if shape then p.Shape = shape end
	p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Massless = true; p.CastShadow = false; p.Anchored = true
	return p
end

-- ---------- une pièce en EditableMesh ----------
local function meshPiece(g: any, scale: number): (MeshPart?, Vector3)
	local raw = decode(g.data)
	local k = scale / WeaponModels.Q
	local uvK = UV_SCALE / scale                   -- studs -> mètres -> répétitions de la peinture
	local pos = table.create(g.nv)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for i = 0, g.nv - 1 do
		local v = Vector3.new(buffer.readi16(raw, i * 6), buffer.readi16(raw, i * 6 + 2), buffer.readi16(raw, i * 6 + 4)) * k
		pos[i + 1] = v; lo = lo:Min(v); hi = hi:Max(v)
	end
	local center = (lo + hi) / 2
	local em = AssetService:CreateEditableMesh({ FixedSize = false })
	local ids = table.create(g.nv)
	for i, v in ipairs(pos) do ids[i] = em:AddVertex(v - center) end
	local base = g.nv * 6
	for t = 0, g.nt - 1 do
		local a = buffer.readu16(raw, base + t * 6) + 1
		local b = buffer.readu16(raw, base + t * 6 + 2) + 1
		local c = buffer.readu16(raw, base + t * 6 + 4) + 1
		local face = em:AddTriangle(ids[a], ids[b], ids[c])
		local n = (pos[b] - pos[a]):Cross(pos[c] - pos[a])
		if n.Magnitude > 1e-9 then
			local nid = em:AddNormal(n.Unit)
			em:SetFaceNormals(face, { nid, nid, nid })      -- normales par face : rendu « low-poly » net comme sur le web
		end
		-- coordonnées de texture pour les skins : projection continue sur toute l'arme, comme applyPlanarUV() du web
		-- (côtés en z-y, dessus et dessous en z-x, avant et arrière en x-y)
		local ax, ay, az = math.abs(n.X), math.abs(n.Y), math.abs(n.Z)
		local uvs = table.create(3)
		for j, v in ipairs({ pos[a], pos[b], pos[c] }) do
			local m = v * uvK
			local u, w
			if ax >= ay and ax >= az then u, w = -m.Z, m.Y
			elseif ay >= az then u, w = -m.Z, m.X + 0.37 * UV_SCALE
			else u, w = m.X, m.Y end
			uvs[j] = em:AddUV(Vector2.new(u + 0.5, 0.5 - w))
		end
		em:SetFaceUVs(face, uvs)
	end
	local mp = AssetService:CreateMeshPartAsync(Content.fromObject(em), { CollisionFidelity = Enum.CollisionFidelity.Box })
	return mp, center
end

-- ---------- silhouette en blocs (si EditableMesh est refusé) ----------
local function blockGun(model: Model, grip: BasePart, key: string, scale: number)
	local inf = Info[key]
	local w = Config.WEAPONS[key]
	local back, front = inf.min[3] * scale, inf.muzzle * scale
	local h = math.max(inf.sight, 0.04) * scale
	local dark = LOOK.body.color
	local function add(name: string, piece: string, size: Vector3, at: Vector3, color: Color3?, shape: Enum.PartType?)
		local p = plain(name, size, color or dark, Enum.Material.Metal, shape)
		p:SetAttribute("Piece", piece); p:SetAttribute("Offset", CFrame.new(at))
		p:SetAttribute("Role", if color == LOOK.steel.color then "steel" elseif color == LOOK.wood.color then "wood" else "body")
		p.CFrame = grip.CFrame * CFrame.new(at); p.Parent = model
	end
	local recvLen = (back - front) * 0.55
	add("Receiver", "body", Vector3.new(0.05 * scale, h * 1.1, recvLen), Vector3.new(0, h * 0.35, back - recvLen / 2))
	local barrelLen = math.max(0.05, (back - front) - recvLen)
	add("Barrel", "body", Vector3.new(barrelLen, 0.022 * scale, 0.022 * scale), Vector3.new(0, h * 0.55, front + barrelLen / 2), LOOK.steel.color)
	local barrel = model:FindFirstChild("Barrel") :: BasePart
	barrel:SetAttribute("Offset", CFrame.new(0, h * 0.55, front + barrelLen / 2) * CFrame.Angles(0, math.rad(90), 0))
	add("Grip", "body", Vector3.new(0.035 * scale, 0.1 * scale, 0.045 * scale), Vector3.new(0, -0.04 * scale, 0.01 * scale))
	if not w.melee and w.cat ~= "pistol" then
		add("Mag", "mag", Vector3.new(0.03 * scale, 0.12 * scale, 0.05 * scale), Vector3.new(0, -0.05 * scale, inf.left[3] * scale * 0.5))
		add("Stock", "body", Vector3.new(0.04 * scale, h * 1.2, math.max(0.02, inf.min[3] * scale * 0.9)), Vector3.new(0, 0, inf.min[3] * scale * 0.5),
			if w.cat == "rifle" and key == "ak" or key == "galil" then LOOK.wood.color else nil)
	end
end

local function knife(model: Model, grip: BasePart, scale: number)
	local function add(name: string, size: Vector3, at: CFrame, color: Color3, mat: Enum.Material, role: string)
		local p = plain(name, size, color, mat); p:SetAttribute("Piece", "body"); p:SetAttribute("Role", role); p:SetAttribute("Offset", at)
		p.CFrame = grip.CFrame * at; p.Parent = model
	end
	add("Handle", Vector3.new(0.03, 0.035, 0.12) * scale, CFrame.new(0, 0, 0.03 * scale), Color3.fromRGB(30, 31, 34), Enum.Material.SmoothPlastic, "acc")
	add("Guard", Vector3.new(0.035, 0.06, 0.012) * scale, CFrame.new(0, 0, -0.035 * scale), Color3.fromRGB(80, 82, 88), Enum.Material.Metal, "steel")
	add("Blade", Vector3.new(0.006, 0.035, 0.16) * scale, CFrame.new(0, 0.004 * scale, -0.12 * scale), Color3.fromRGB(200, 205, 212), Enum.Material.Metal, "body")   -- le skin couvre aussi la lame
	local tip = plain("Tip", Vector3.new(0.006, 0.035, 0.03) * scale, Color3.fromRGB(200, 205, 212), Enum.Material.Metal)
	local mesh = Instance.new("SpecialMesh"); mesh.MeshType = Enum.MeshType.Wedge; mesh.Parent = tip
	local at = CFrame.new(0, 0.004 * scale, -0.215 * scale) * CFrame.Angles(0, math.rad(180), 0)
	tip:SetAttribute("Piece", "body"); tip:SetAttribute("Role", "body"); tip:SetAttribute("Offset", at); tip.CFrame = grip.CFrame * at; tip.Parent = model
end

-- ---------- fabrication + cache ----------
local cache: { [string]: Model } = {}

local function make(key: string, scale: number): Model
	local model = Instance.new("Model"); model.Name = "Weapon_" .. key
	local grip = plain("Grip", Vector3.new(0.05, 0.05, 0.05), Color3.new(), Enum.Material.SmoothPlastic)
	grip.Transparency = 1; grip.Parent = model; model.PrimaryPart = grip
	local w = Config.WEAPONS[key]
	local inf = Info[key]
	local muzzleZ = if inf then inf.muzzle * scale else -0.3 * scale
	local sightY = if inf then inf.sight * scale else 0.05 * scale
	if w and w.melee then
		knife(model, grip, scale); muzzleZ = -0.23 * scale
	else
		local ok = false
		local folder = ReplicatedStorage.Shared:FindFirstChild("WeaponMeshes")
		local src = folder and folder:FindFirstChild(key)
		if src and WeaponModels.meshApi then
			ok = pcall(function()
				local groups = require(src :: ModuleScript) :: any
				for _, g in ipairs(groups) do
					local mp, center = meshPiece(g, scale)
					if mp then
						local look = LOOK[g.role]
						mp.Name = g.part .. "_" .. g.role
						mp.Color = if look then look.color else Color3.fromRGB(g.color[1], g.color[2], g.color[3])
						mp.Material = if look then look.material else Enum.Material.Metal
						mp.Anchored = true; mp.CanCollide = false; mp.CanQuery = false; mp.CanTouch = false; mp.Massless = true; mp.CastShadow = false
						mp:SetAttribute("Piece", g.part); mp:SetAttribute("Offset", CFrame.new(center))
						mp.CFrame = grip.CFrame * CFrame.new(center)
						mp.Parent = model
					end
				end
			end)
			if not ok then
				WeaponModels.meshApi = false
				warn("[WeaponModels] EditableMesh indisponible : coche Game Settings → Security → « Allow Mesh / Image APIs ». Armes en blocs en attendant.")
				for _, c in ipairs(model:GetChildren()) do if c ~= grip then c:Destroy() end end
			end
		end
		if not ok and inf then blockGun(model, grip, key, scale) end
	end
	local muzzle = Instance.new("Attachment"); muzzle.Name = "Muzzle"; muzzle.Position = Vector3.new(0, sightY * 0.6, muzzleZ); muzzle.Parent = grip
	local left = Instance.new("Attachment"); left.Name = "LeftHand"
	left.Position = if inf then Vector3.new(inf.left[1], inf.left[2], inf.left[3]) * scale else Vector3.new()
	left.Parent = grip
	model:SetAttribute("SightY", sightY)
	return model
end

function WeaponModels.build(key: string, scale: number): Model
	local id = key .. "@" .. scale
	if not cache[id] then cache[id] = make(key, scale) end
	return cache[id]:Clone()
end

-- Recalcule la position de chaque pièce d'après Grip ; pieceCF[piece] = décalage d'animation (chargeur, culasse).
function WeaponModels.place(model: Model, gripCF: CFrame, pieceCF: { [string]: CFrame }?)
	local parts, cfs = {}, {}
	for _, c in ipairs(model:GetChildren()) do
		if c:IsA("BasePart") then
			local off = c:GetAttribute("Offset")
			local anim = pieceCF and pieceCF[c:GetAttribute("Piece") :: string] or nil
			table.insert(parts, c)
			table.insert(cfs, if typeof(off) == "CFrame" then (if anim then gripCF * anim * off else gripCF * off) else gripCF)
		end
	end
	if model:IsDescendantOf(workspace) then
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	else
		for i, p in ipairs(parts) do (p :: BasePart).CFrame = cfs[i] end
	end
end

-- Arme tenue par un personnage (3e personne) : soudée à la poignée, pièces non ancrées.
function WeaponModels.weldTo(model: Model, handle: BasePart, gripCF: CFrame)
	WeaponModels.place(model, gripCF)
	for _, c in ipairs(model:GetChildren()) do
		if c:IsA("BasePart") then
			local wc = Instance.new("WeldConstraint"); wc.Part0 = handle; wc.Part1 = c; wc.Parent = c
			c.Anchored = false
		end
	end
end

return WeaponModels
