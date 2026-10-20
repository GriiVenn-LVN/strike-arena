--!strict
-- ReplicatedStorage/Shared/HandModels (ModuleScript, côté client + Studio)
-- Gants modelés et manches coniques de la vue subjective, exportés du jeu web (tools/hands/export_hands.js →
-- HandMeshes) : un maillage par matière du gant (tissu, paume, coque des jointures, sangle) et par main (la gauche est
-- le reflet de la droite, comme VM.hL.scale.x = -1 du web), plus les deux cônes de manche. 10 pièces en tout au lieu
-- d'environ 200 pièces arrondies : bien plus léger sur téléphone.
-- Les maillages ne sont chargés chez le joueur que s'ils ont été envoyés par ServerStorage/MeshUploader (MeshAssets) :
-- la mémoire des EditableMesh est gardée pour les armes ; sinon ViewmodelController garde ses pièces arrondies.
--   build() -> { R = { GlovePart }, L = { GlovePart }, u = MeshPart?, f = MeshPart? } ou nil
--   keys()  -> clés de maillage attendues (h:glove:<main>:<matière>/<nv>/<nt>, h:sleeve:<u|f>/<nv>/<nt>)
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local decode = require(ReplicatedStorage.Shared.Base64)
local MeshStore = require(ReplicatedStorage.Shared.MeshStore)
local data = require(ReplicatedStorage.Shared.HandMeshes) :: any

local HandModels = {}
HandModels.MATS = { "fab", "palm", "pad", "strap" }
HandModels.WRIST = data.wrist :: Vector3          -- le bras s'arrête au poignet du gant (userData.wristL du web)

export type GlovePart = { p: MeshPart, at: CFrame, mat: string }
export type Built = { R: { GlovePart }, L: { GlovePart }, u: MeshPart?, f: MeshPart?, ems: { EditableMesh } }

local function keyOf(prefix: string, piece: any): string
	return prefix .. "/" .. piece.nv .. "/" .. piece.nt
end

function HandModels.keys(): { string }
	local out = {}
	for _, side in ipairs({ "R", "L" }) do
		for _, m in ipairs(HandModels.MATS) do
			local piece = data.glove[m]
			if piece then table.insert(out, keyOf("h:glove:" .. side .. ":" .. m, piece)) end
		end
	end
	table.insert(out, keyOf("h:sleeve:u", data.sleeve.u))
	table.insert(out, keyOf("h:sleeve:f", data.sleeve.f))
	return out
end

-- tous les maillages sont envoyés (ou on est dans l'envoi, depuis Studio)
function HandModels.ready(): boolean
	if MeshStore.uploader then return true end
	for _, k in ipairs(HandModels.keys()) do if not MeshStore.ids[k] then return false end end
	return true
end

-- maillage d'une pièce, recentré sur sa boîte (le MeshPart a son origine au centre) ; mirror = reflet en x
local function mesh(key: string, piece: any, mirror: boolean, ems: { EditableMesh }): (MeshPart, Vector3)
	local raw = decode(piece.data)
	local nv, nt = piece.nv :: number, piece.nt :: number
	local q = 1 / (data.Q :: number)
	local sx = if mirror then -1 else 1
	local pos: { Vector3 } = table.create(nv)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for i = 0, nv - 1 do
		local o = i * 9
		local v = Vector3.new(buffer.readi16(raw, o) * sx, buffer.readi16(raw, o + 2), buffer.readi16(raw, o + 4)) * q
		pos[i + 1] = v; lo = lo:Min(v); hi = hi:Max(v)
	end
	local center = (lo + hi) / 2
	local mp, em0 = MeshStore.meshPart(key, function()
		local em = AssetService:CreateEditableMesh({ FixedSize = false })
		local vid, nid = table.create(nv), table.create(nv)
		for i = 0, nv - 1 do
			local o = i * 9
			vid[i + 1] = em:AddVertex(pos[i + 1] - center)
			local n = Vector3.new(buffer.readi8(raw, o + 6) * sx, buffer.readi8(raw, o + 7), buffer.readi8(raw, o + 8))
			nid[i + 1] = em:AddNormal(if n.Magnitude > 0 then n.Unit else Vector3.yAxis)
		end
		local base = nv * 9
		for t = 0, nt - 1 do
			local a = buffer.readu16(raw, base + t * 6) + 1
			local b = buffer.readu16(raw, base + t * 6 + 2) + 1
			local c = buffer.readu16(raw, base + t * 6 + 4) + 1
			if mirror then b, c = c, b end                  -- le reflet retourne les faces : on remet l'ordre des sommets
			local f = em:AddTriangle(vid[a], vid[b], vid[c])
			em:SetFaceNormals(f, { nid[a], nid[b], nid[c] })
		end
		return em
	end)
	if em0 then table.insert(ems, em0) end
	mp.Anchored = true; mp.CanCollide = false; mp.CanQuery = false; mp.CanTouch = false; mp.Massless = true
	mp.CastShadow = false
	return mp, center
end

-- matière Roblox proche de la rugosité / du métal du web (handMats de 55b_hands.js)
local function dress(mp: MeshPart, m: string)
	if m == "pad" then
		-- coque des jointures : plastique dur, satiné (rugosité 0,35, métal 0,15)
		mp.Material = Enum.Material.SmoothPlastic; mp.Reflectance = 0.04
	elseif m == "palm" then
		mp.Material = Enum.Material.Leather       -- paume et bout des doigts : cuir synthétique (rugosité 0,6)
	else
		mp.Material = Enum.Material.Fabric        -- toile du gant et sangle (rugosité 0,86 / 0,7)
	end
	mp.Name = "Gant_" .. m
end

-- fabrique tout (yield : CreateMeshPartAsync) ; nil si les maillages ne sont pas envoyés ou si Roblox refuse
function HandModels.build(): Built?
	if not HandModels.ready() then return nil end
	local ok, res = pcall(function(): Built
		local out: Built = { R = {}, L = {}, u = nil, f = nil, ems = {} }
		for _, side in ipairs({ "R", "L" }) do
			for _, m in ipairs(HandModels.MATS) do
				local piece = data.glove[m]
				if piece then
					local mp, c = mesh(keyOf("h:glove:" .. side .. ":" .. m, piece), piece, side == "L", out.ems)
					dress(mp, m)
					table.insert((out :: any)[side], { p = mp, at = CFrame.new(c), mat = m })
				end
			end
		end
		local u = mesh(keyOf("h:sleeve:u", data.sleeve.u), data.sleeve.u, false, out.ems)
		local f = mesh(keyOf("h:sleeve:f", data.sleeve.f), data.sleeve.f, false, out.ems)
		u.Name = "MancheHaut"; f.Name = "MancheBas"
		u.Material = Enum.Material.Fabric; f.Material = Enum.Material.Fabric
		out.u = u; out.f = f
		return out
	end)
	if ok then return res end
	warn("[HandModels] gants modelés indisponibles : pièces arrondies gardées.", res)
	return nil
end

-- envoi depuis Studio (ServerStorage/MeshUploader, mode Edit)
function HandModels.prebuildAll()
	local b = HandModels.build()
	if not b then return end
	for _, list in ipairs({ b.R, b.L }) do for _, g in ipairs(list) do g.p:Destroy() end end
	if b.u then b.u:Destroy() end
	if b.f then b.f:Destroy() end
	for _, em in ipairs(b.ems) do pcall(function() em:Destroy() end) end
end

return HandModels
