--!strict
-- StarterPlayerScripts/WeaponVisuals (LocalScript)
-- Arme vue en 3e personne (autres joueurs et bots) : le serveur ne pose qu'une poignée invisible « HeldWeapon » ;
-- ici on y soude la vraie arme du jeu web, fabriquée localement par WeaponModels. Notre propre arme est dans le viewmodel.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponModels = require(ReplicatedStorage.Shared.WeaponModels)
local WORLD_SCALE = 2.9          -- même valeur que WeaponService

local player = Players.LocalPlayer

local function dress(held: Instance)
	if not held:IsA("BasePart") or held:GetAttribute("Custom") == true then return end
	local key = held:GetAttribute("Key")
	if typeof(key) ~= "string" then return end
	local char = held.Parent
	if char == player.Character then return end
	task.defer(function()
		if not held.Parent then return end
		local ok, model = pcall(WeaponModels.build, key, WORLD_SCALE)
		if not ok or not model then warn("[WeaponVisuals]", key, model) return end
		WeaponModels.weldTo(model, held :: BasePart, (held :: BasePart).CFrame)
		model.Parent = held
	end)
end

workspace.DescendantAdded:Connect(function(d)
	if d.Name == "HeldWeapon" then dress(d) end
end)
for _, d in ipairs(workspace:GetDescendants()) do
	if d.Name == "HeldWeapon" then dress(d) end
end
