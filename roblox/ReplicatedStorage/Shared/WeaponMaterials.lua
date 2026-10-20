--!strict
-- ReplicatedStorage/Shared/WeaponMaterials (ModuleScript, client + Studio)
-- Rendu matériel réaliste des armes, dans le monde (vue à la 1re personne, 3e personne, kill-cam) :
--   * armes stylisées sans skin : SurfaceAppearance par rôle de pièce (WeaponModels : body / acc / steel / wood), avec
--     des cartes génériques qui se répètent (tools/export_weapon_materials.py) : acier bruni, aluminium anodisé,
--     polymère grenu, bois vernis, acier poli. La couleur de la pièce devient la teinte de la SurfaceAppearance ;
--   * viseurs 3D de l'armurier (AttachmentModels, attribut OMat) : mêmes matériaux (corps anodisé, caoutchouc, métal) ;
--   * armes réalistes (WeaponReal, rôle « real ») : leurs propres cartes de couleur, normales, métal et rugosité.
-- Les pièces peintes par un skin (SkinPaint : body / acc / wood quand le skin a une peinture ou une couleur) gardent
-- la SurfaceAppearance du skin ; l'acier (canon, culasse) et les viseurs gardent toujours leur matériau.
-- Pas de SurfaceAppearance dans les aperçus (ViewportFrame, sans reflets : le métal y paraîtrait noir), comme SkinPaint.
-- Repli : tant que MeshUploader n'a pas envoyé les cartes (« i:mat:<nom>:c|n|r|m »), les pièces restent comme avant.
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local MeshStore = require(ReplicatedStorage.Shared.MeshStore)
local decode = require(ReplicatedStorage.Shared.Base64)

local WM = {}
WM.NAMES = { "bruni", "anod", "poly", "bois", "acier" }
local KINDS = { "c", "n", "r", "m" }
-- valeur moyenne de chaque carte de couleur (WeaponMatData : avg) : la teinte est divisée par elle pour garder la
-- couleur d'origine de la pièce ; métal uni de chaque matériau
local AVG = { bruni = 0.71, anod = 0.77, poly = 0.74, bois = 0.77, acier = 0.86 }
local METAL = { bruni = 0.9, anod = 0.7, poly = 0, bois = 0, acier = 1 }

-- carcasse (rôle body) : acier bruni par défaut ; aluminium anodisé (AR-15, SCAR) ; polymère (armes en plastique)
local BODY: { [string]: string } = {
	m4 = "anod", scar = "anod", sg553 = "anod",
	glock = "poly", usp = "poly", p250 = "poly", fiveseven = "poly", ump = "poly", p90 = "poly", famas = "poly", aug = "poly",
	mp9 = "poly", xm = "poly",
}
local ROLE: { [string]: string } = { acc = "poly", steel = "acier", wood = "bois" }
-- matériaux des viseurs Blender (OPT3D_MAT du web, AttachmentModels)
local OMAT: { [string]: string } = { body = "anod", dark = "anod", rubber = "poly", tan = "poly", metal = "acier" }

-- ---------- cartes (MeshAssets ; envoi depuis Studio) ----------
local data: any = nil
local blob: buffer? = nil
local function loadData(): boolean
	if blob then return true end
	local f = ServerStorage:FindFirstChild("WeaponMatData")
	if not f then return false end
	data = require(f:FindFirstChild("Info") :: ModuleScript) :: any
	local parts = table.create(data.chunks)
	for i = 1, data.chunks do parts[i] = require(f:FindFirstChild("D" .. i) :: ModuleScript) :: any end
	blob = decode(table.concat(parts))
	return true
end

local function fill(name: string, kind: string): EditableImage?
	if kind == "m" then
		-- métal uni : petite image
		local l = math.floor(METAL[name] * 255 + 0.5)
		local out = buffer.create(4 * 4 * 4)
		for i = 0, 15 do buffer.writeu32(out, i * 4, 0xFF000000 + l * 0x10101) end
		local e = AssetService:CreateEditableImage({ Size = Vector2.new(4, 4) })
		e:WritePixelsBuffer(Vector2.zero, Vector2.new(4, 4), out)
		return e
	end
	local dec = ServerStorage:FindFirstChild("JpegDecode")
	if not dec or not loadData() then return nil end
	local jpeg = require(dec :: ModuleScript) :: any
	local at = data[name][kind]
	local w, h, px = jpeg(blob, at[1], at[2])
	local e = AssetService:CreateEditableImage({ Size = Vector2.new(w, h) })
	e:WritePixelsBuffer(Vector2.zero, Vector2.new(w, h), px)
	return e
end

local function key(name: string, kind: string): string return "mat:" .. name .. ":" .. kind end

-- Content de la carte envoyée (nil tant qu'elle ne l'est pas)
local function map(name: string, kind: string): Content?
	local id = MeshStore.ids["i:" .. key(name, kind)]
	if id and not MeshStore.uploader then return Content.fromUri("rbxassetid://" .. id) end
	return nil
end
local readyCache: { [string]: boolean } = {}
local function ready(name: string): boolean
	local r = readyCache[name]
	if r == nil then
		r = true
		for _, k in ipairs(KINDS) do if not MeshStore.ids["i:" .. key(name, k)] then r = false end end
		if r then readyCache[name] = true end
	end
	return r :: boolean
end

-- envoi depuis Studio (MeshUploader) : les cinq matériaux, chacun ses quatre cartes
function WM.uploadAll()
	for _, name in ipairs(WM.NAMES) do
		for _, k in ipairs(KINDS) do
			local kk = key(name, k)
			if not MeshStore.ids["i:" .. kk] then
				local _, e = MeshStore.image(kk, function() return fill(name, k) end)
				if e then pcall(function() (e :: EditableImage):Destroy() end) end
			end
		end
	end
end

-- ---------- pose sur une arme ----------
local saOK = true
local function matFor(wkey: string?, role: string): string?
	if role == "body" then
		local m = wkey and BODY[wkey]
		if not m and wkey then
			local okC, Config = pcall(require, ReplicatedStorage.Shared.Config)
			local w = okC and (Config :: any).WEAPONS[wkey]
			local look = w and w.look
			m = if type(look) == "string" then BODY[look] else nil
		end
		return m or "bruni"
	end
	return ROLE[role]
end

local function realSA(p: MeshPart): SurfaceAppearance?
	local okR, WeaponReal = pcall(require, ReplicatedStorage.Shared.WeaponReal)
	local wkey = p.Parent and (p.Parent :: Instance):GetAttribute("WeaponKey")
	local mi = p:GetAttribute("RealMat")
	if not okR or type(wkey) ~= "string" or type(mi) ~= "number" then return nil end
	local WR = WeaponReal :: any
	local c, n, m, r = WR.image(wkey, mi, "c"), WR.image(wkey, mi, "n"), WR.image(wkey, mi, "m"), WR.image(wkey, mi, "r")
	if not c then return nil end
	local sa = Instance.new("SurfaceAppearance")
	sa.ColorMapContent = c
	if n then pcall(function() sa.NormalMapContent = n :: Content end) end
	if m then pcall(function() sa.MetalnessMapContent = m :: Content end) end
	if r then pcall(function() sa.RoughnessMapContent = r :: Content end) end
	return sa
end

local function matSA(name: string, color: Color3): SurfaceAppearance?
	if not ready(name) then return nil end
	local sa = Instance.new("SurfaceAppearance")
	-- teinte = couleur de la pièce ; la carte de couleur (moyenne AVG) l'assombrit : on compense
	local k = 1 / AVG[name]
	local tint = Color3.new(math.min(1, color.R * k), math.min(1, color.G * k), math.min(1, color.B * k))
	local tinted = pcall(function() sa.Color = tint end)
	if not tinted then sa:Destroy(); return nil end              -- sans teinte, la pièce deviendrait grise : on s'abstient
	sa.ColorMapContent = map(name, "c") :: Content
	pcall(function() sa.NormalMapContent = map(name, "n") :: Content end)
	pcall(function() sa.MetalnessMapContent = map(name, "m") :: Content end)
	pcall(function() sa.RoughnessMapContent = map(name, "r") :: Content end)
	return sa
end

-- world : l'arme est dans le workspace ; painted : le skin peint les pièces body / acc / wood
function WM.dress(model: Instance, world: boolean, painted: boolean)
	if MeshStore.uploader then return end
	local wkey = model:GetAttribute("WeaponKey")
	local wk = if type(wkey) == "string" then wkey else nil
	for _, d in ipairs(model:GetDescendants()) do
		if not d:IsA("MeshPart") then continue end
		local p = d :: MeshPart
		local role = p:GetAttribute("Role")
		local want: string? = nil
		if role == "real" then want = "real"
		elseif role == "body" or role == "acc" or role == "wood" then
			if not painted then want = matFor(wk, role :: string) end
		elseif role == "steel" then want = "acier"
		elseif role == "att" then
			local om = p:GetAttribute("OMat")
			want = if type(om) == "string" then OMAT[om] else nil
		end
		local cur = p:FindFirstChild("MatSA")
		if not world or not want or not saOK then
			if cur then cur:Destroy() end
			continue
		end
		if cur and cur:GetAttribute("Mat") == want then continue end
		if cur then cur:Destroy() end
		local ok, sa = pcall(function(): SurfaceAppearance?
			if want == "real" then return realSA(p) end
			return matSA(want :: string, p.Color)
		end)
		if not ok then
			saOK = false
			warn("[WeaponMaterials] SurfaceAppearance refusée : armes sans matériaux réalistes (" .. tostring(sa) .. ")")
		elseif sa then
			sa.Name = "MatSA"; sa:SetAttribute("Mat", want)
			sa.Parent = p
		end
	end
end

return WM
