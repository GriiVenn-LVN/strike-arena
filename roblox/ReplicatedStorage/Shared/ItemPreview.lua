--!strict
-- ReplicatedStorage/Shared/ItemPreview (ModuleScript, côté client)
-- Aperçu 3D d'une arme avant achat ou réclamation (boutique, passe de combat) : le modèle de l'arme (WeaponModels)
-- peint avec le skin ou le camo animé (SkinPaint), dans un ViewportFrame, qui tourne doucement si spin = true.
-- Même rendu que les icônes de l'Arsenal. Si le modèle ne se construit pas (maillage pas encore envoyé), le cadre reste vide :
-- l'appelant affiche déjà le nom et la rareté à côté.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponModels = require(ReplicatedStorage.Shared.WeaponModels)
local SkinPaint = require(ReplicatedStorage.Shared.SkinPaint)

local ItemPreview = {}

-- parent : où poser l'aperçu ; key : arme (Config.WEAPONS) ; skin : numéro de Config.SKINS ; camo : camo animé (ConfigExtra.EXCLUSIVES)
function ItemPreview.weapon(parent: Instance, key: string, skin: number?, camo: string?, props: { [string]: any }?, spin: boolean?): ViewportFrame
	local vf = Instance.new("ViewportFrame")
	vf.BackgroundTransparency = 1; vf.BorderSizePixel = 0; vf.Size = UDim2.fromScale(1, 1)
	vf.Ambient = Color3.fromRGB(170, 175, 190); vf.LightColor = Color3.new(1, 1, 1); vf.LightDirection = Vector3.new(0.4, -1, 0.3)
	if props then for k, v in pairs(props) do (vf :: any)[k] = v end end
	vf.Parent = parent
	task.spawn(function()
		local ok, m = pcall(WeaponModels.build, key, 1)
		if not ok or not m then return end
		local model = m :: Model
		if not vf.Parent then model:Destroy(); return end
		pcall(SkinPaint.apply, model, skin, camo)
		model.Parent = vf
		local cf, ext = model:GetBoundingBox()
		local cam = Instance.new("Camera"); cam.FieldOfView = 20
		local size = vf.AbsoluteSize
		local aspect = if size.Y > 0 then size.X / size.Y else 1.6
		local tv = math.tan(math.rad(10))
		local dist = math.max(ext.Y / 2 / tv, math.max(ext.Z, ext.X) / 2 / (tv * aspect)) * 1.15 + math.max(ext.X, ext.Z) / 2
		local center = cf.Position
		cam.CFrame = CFrame.lookAt(center - Vector3.new(dist, -dist * 0.12, 0), center)
		cam.Parent = vf; vf.CurrentCamera = cam
		if spin then
			local a = 0
			local conn: RBXScriptConnection
			conn = RunService.RenderStepped:Connect(function(dt: number)
				if not vf.Parent then conn:Disconnect(); return end
				if not vf.Visible then return end
				a += dt * 0.6
				cam.CFrame = CFrame.lookAt(center + Vector3.new(-math.cos(a) * dist, dist * 0.12, math.sin(a) * dist), center)
				-- la lumière suit la caméra (en haut à gauche) : la face vue du camo reste éclairée pendant tout le tour
				vf.LightDirection = cam.CFrame:VectorToWorldSpace(Vector3.new(0.35, -0.6, -1))
			end)
		end
	end)
	return vf
end

return ItemPreview
