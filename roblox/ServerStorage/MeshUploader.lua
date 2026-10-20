--!strict
-- ServerStorage/MeshUploader (ModuleScript, Studio seulement, en mode Edit)
-- Envoie une seule fois sur le compte Roblox du créateur tous les maillages et textures du jeu web (armes, viseurs,
-- soldats, skins, véhicules des arrivées, décor des cartes). Roblox limite très fort la mémoire des EditableMesh / EditableImage chez le
-- joueur : avec ces assets, le jeu charge de vrais modèles (MeshStore), aussi sur téléphone.
-- Il faut la fonctionnalité bêta de Studio « CreateAssetAsync Luau API ». Dans la barre de commande :
--   require(game.ServerStorage.MeshUploader).start()     -- lance l'envoi (30 par minute au plus), reprend où il s'était arrêté
--   require(game.ServerStorage.MeshUploader).status()    -- avancement
--   require(game.ServerStorage.MeshUploader).source()    -- texte de ReplicatedStorage/Shared/MeshAssets.lua à recopier
-- À la fin, ReplicatedStorage.Shared.MeshAssets de la place ouverte est rempli (install) : il reste à publier.
-- Les numéros déjà obtenus sont gardés dans ServerStorage.MeshUploadResults (JSON).
local AssetService = game:GetService("AssetService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local M = {}
local state = { step = "prêt", sent = 0, skipped = 0, failed = 0, running = false, last = "" }

local function resultsValue(): StringValue
	local v = ServerStorage:FindFirstChild("MeshUploadResults")
	if not v then
		v = Instance.new("StringValue"); v.Name = "MeshUploadResults"; v.Value = "{}"; v.Parent = ServerStorage
	end
	return v :: StringValue
end

local function load(): { [string]: number }
	local ok, t = pcall(function() return HttpService:JSONDecode(resultsValue().Value) end)
	local out: { [string]: number } = {}
	if ok and type(t) == "table" then for k, v in pairs(t) do out[k] = tonumber(v) :: number end end
	local Shared = ReplicatedStorage.Shared
	local okA, known = pcall(require, Shared:FindFirstChild("MeshAssets") :: ModuleScript)
	if okA and type(known) == "table" then for k, v in pairs(known) do if out[k] == nil then out[k] = v end end end
	return out
end

local function save(t: { [string]: number })
	resultsValue().Value = HttpService:JSONEncode(t)
end

function M.status(): string
	local s = string.format("[MeshUploader] %s | envoyés %d | déjà là %d | échecs %d | en cours %s | %s",
		state.step, state.sent, state.skipped, state.failed, tostring(state.running), state.last)
	print(s)
	return s
end

function M.source(): string
	local t = load()
	local keys = {}
	for k in pairs(t) do table.insert(keys, k) end
	table.sort(keys)
	local lines = { "-- Généré par ServerStorage/MeshUploader (envoi depuis Studio) : ne pas modifier à la main.",
		"-- clé du maillage ou de l'image -> numéro d'asset Roblox", "return {" }
	for _, k in ipairs(keys) do table.insert(lines, string.format("\t[%q] = %d,", k, t[k])) end
	table.insert(lines, "}")
	local src = table.concat(lines, "\n") .. "\n"
	local v = ServerStorage:FindFirstChild("MeshAssetsSource") or Instance.new("StringValue")
	v.Name = "MeshAssetsSource"; (v :: StringValue).Value = src; v.Parent = ServerStorage
	return src
end

-- recopie les numéros dans ReplicatedStorage.Shared.MeshAssets de la place ouverte (à publier ensuite)
function M.install(): number
	local src = M.source()
	local mod = ReplicatedStorage.Shared:FindFirstChild("MeshAssets") :: ModuleScript
	mod.Source = src
	local _, n = string.gsub(src, "\n\t%[", "")
	print("[MeshUploader] MeshAssets mis à jour : " .. n .. " assets")
	return n
end

local function run()
	local uid = 0
	pcall(function() uid = (game:GetService("StudioService") :: any):GetUserId() end)
	if uid == 0 then uid = game.CreatorId end
	local results = load()
	local Shared = ReplicatedStorage.Shared
	local MeshStore = require(Shared.MeshStore) :: any
	MeshStore.ids = results
	local lastAt = 0
	local streak = 0
	MeshStore.uploader = function(key: string, obj: any, kind: string)
		if results[key] then state.skipped += 1; return end
		for attempt = 1, 3 do
			local wait = 2.1 - (os.clock() - lastAt)
			if wait > 0 then task.wait(wait) end
			lastAt = os.clock()
			local ok, r, id = pcall(function()
				return (AssetService :: any):CreateAssetAsync(obj, if kind == "mesh" then Enum.AssetType.Mesh else Enum.AssetType.Image, {
					Name = "StrikeArena " .. kind .. " " .. (state.sent + state.failed + 1), Description = "Strike Arena",
					CreatorId = uid, CreatorType = Enum.AssetCreatorType.User,
				})
			end)
			if ok and r == Enum.CreateAssetResult.Success then
				results[key] = tonumber(id) :: number
				state.sent += 1; streak = 0
				if state.sent % 5 == 0 then save(results) end
				return
			end
			state.last = key .. " : " .. tostring(r) .. " " .. tostring(id)
			warn("[MeshUploader] échec " .. state.last .. " (essai " .. attempt .. ")")
			task.wait(if attempt == 1 then 20 else 60)    -- limite de débit probable : on patiente
		end
		state.failed += 1; streak += 1
		save(results)
		if streak >= 6 then error("trop d'échecs d'affilée, arrêt : " .. state.last) end
	end

	local function step(name: string, fn: () -> ())
		state.step = name
		M.status()
		local ok, err = pcall(fn :: any)
		if not ok then
			warn("[MeshUploader] " .. name .. " : " .. tostring(err))
			if string.find(tostring(err), "trop d'échecs") then error(err) end
		end
		save(results)
	end

	step("armes", function()
		local WeaponModels = require(Shared.WeaponModels) :: any
		for _, m in ipairs(Shared.WeaponMeshes:GetChildren()) do WeaponModels.build(m.Name, 1) end
	end)
	step("viseurs", function()
		local AM = require(Shared.AttachmentModels) :: any
		for _, m in ipairs(Shared.OpticMeshes:GetChildren()) do
			local data = require(m :: ModuleScript) :: any
			for gi, g in ipairs(data.groups) do AM.opticBase(m.Name, gi, g) end
		end
	end)
	step("soldats", function()
		local SoldierModels = require(Shared.SoldierModels) :: any
		SoldierModels.prebuildAll()
	end)
	step("skins", function()
		local SkinPaint = require(Shared.SkinPaint) :: any
		for _, m in ipairs(Shared.SkinTextures:GetChildren()) do SkinPaint.paint(m.Name, false); SkinPaint.paint(m.Name, true) end
		-- peintures 256 px « sk2: » (ServerStorage/SkinTexturesHQ), masques lumineux et cartes métal / rugosité des finitions
		SkinPaint.uploadAll()
	end)
	step("véhicules", function()   -- arrivées : blindé et camion (models/vehicles, VehicleMeshes)
		local VehicleModels = require(Shared.VehicleModels) :: any
		VehicleModels.prebuildAll()
	end)
	step("cartes", function()
		local MapScene = require(Shared.MapScene) :: any
		local MapDress = require(Shared.MapDress) :: any
		for _, f in ipairs(Shared.MapScenes:GetChildren()) do
			local id = f.Name
			if MapScene.has(id) then
				state.step = "carte " .. id
				MapDress.prebuildImages(id)
				local folder = Instance.new("Folder"); folder.Name = "UploadTmp_" .. id
				local details = Instance.new("Folder"); details.Name = "Details"; details.Parent = folder
				local b = { folder = folder, id = id, origin = Vector3.zero, details = details, alive = true, meshes = {}, images = {} }
				MapDress.buildMeshes(b, MapScene.info(id))
				folder:Destroy()
				for _, em in ipairs(b.meshes) do pcall(function() em:Destroy() end) end
				save(results)
			end
		end
	end)
	MeshStore.uploader = nil
	state.step = "terminé"
	pcall(M.install)
	M.status()
end

function M.start()
	if state.running then return M.status() end
	state.running = true; state.sent = 0; state.skipped = 0; state.failed = 0
	task.spawn(function()
		local ok, err = pcall(run :: any)
		state.running = false
		if not ok then state.step = "arrêté : " .. tostring(err); warn("[MeshUploader] " .. tostring(err)) end
		M.status()
	end)
	return M.status()
end

return M
