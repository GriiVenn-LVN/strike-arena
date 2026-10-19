--!strict
-- ReplicatedStorage/Shared/MeshStore (ModuleScript, client + Studio)
-- Roblox limite très fort la mémoire des EditableMesh / EditableImage chez le joueur (quelques maillages seulement) :
-- les modèles du web (armes, viseurs, soldats, décor des cartes) et leurs textures sont donc envoyés une fois sur Roblox
-- depuis Studio (ServerStorage/MeshUploader), et leurs numéros d'asset sont rangés dans MeshAssets.
--   meshPart(clé, fill) : MeshPart chargé depuis l'asset s'il existe, sinon construit par fill() (EditableMesh) ;
--   image(clé, fill)    : Content de l'image envoyée, sinon de l'EditableImage rendue par fill().
-- Pendant l'envoi (Studio, mode Edit), MeshStore.uploader reçoit chaque objet construit.
local AssetService = game:GetService("AssetService")

local MeshStore = {}
local okIds, ids = pcall(require, script.Parent:WaitForChild("MeshAssets", 5) :: ModuleScript)
MeshStore.ids = (if okIds and type(ids) == "table" then ids else {}) :: { [string]: number }
MeshStore.uploader = nil :: ((key: string, obj: any, kind: string) -> ())?

local OPTS = { CollisionFidelity = Enum.CollisionFidelity.Box }
-- armes et viseurs : toujours le maillage complet. En « Automatic », Roblox affiche de loin (et parfois en ViewportFrame)
-- une version simplifiée qui écrase les pièces fines (crosse, garde-main, rails) : l'arme paraît plate vue de face.
MeshStore.PRECISE = { CollisionFidelity = Enum.CollisionFidelity.Box, RenderFidelity = Enum.RenderFidelity.Precise }
local warned = false

-- CreateMeshPartAsync avec les options demandées ; si Roblox refuse une option (RenderFidelity…), on refait sans
local function create(content: Content, o: { [string]: any }): MeshPart
	if o == OPTS then return AssetService:CreateMeshPartAsync(content, OPTS) end
	local ok, mp = pcall(function() return AssetService:CreateMeshPartAsync(content, o) end)
	if ok and mp then return mp end
	return AssetService:CreateMeshPartAsync(content, OPTS)
end

function MeshStore.count(): number
	local n = 0
	for _ in pairs(MeshStore.ids) do n += 1 end
	return n
end

-- opts : options de CreateMeshPartAsync (OPTS par défaut, MeshStore.PRECISE pour les armes)
function MeshStore.meshPart(key: string, fill: () -> EditableMesh, opts: { [string]: any }?): (MeshPart, EditableMesh?)
	local o = opts or OPTS
	local id = MeshStore.ids[key]
	if id and not MeshStore.uploader then
		local ok, mp = pcall(function() return create(Content.fromUri("rbxassetid://" .. id), o) end)
		if ok and mp then return mp, nil end
		if not warned then warned = true; warn("[MeshStore] maillage envoyé illisible (" .. key .. ") : " .. tostring(mp)) end
	end
	local em = fill()
	if not em then error("mémoire des maillages pleine (CreateEditableMesh a renvoyé nil)") end
	if MeshStore.uploader and not id then (MeshStore.uploader :: any)(key, em, "mesh") end
	return create(Content.fromObject(em), o), em
end

-- fill peut renvoyer nil (API refusée) : l'appelant garde alors la couleur moyenne
function MeshStore.image(key: string, fill: () -> EditableImage?): (Content?, EditableImage?)
	local k = "i:" .. key
	local id = MeshStore.ids[k]
	if id and not MeshStore.uploader then return Content.fromUri("rbxassetid://" .. id), nil end
	local img = fill()
	if not img then return nil, nil end
	if MeshStore.uploader and not id then (MeshStore.uploader :: any)(k, img, "image") end
	return Content.fromObject(img), img
end

return MeshStore
