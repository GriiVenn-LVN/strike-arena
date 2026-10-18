--!strict
-- StarterPlayerScripts/WeaponVisuals (LocalScript)
-- Arme vue en 3e personne (autres joueurs et bots) : le serveur ne pose qu'une poignée invisible « HeldWeapon » ;
-- ici on y soude la vraie arme du jeu web, fabriquée localement par WeaponModels. Notre propre arme est dans le viewmodel.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponModels = require(ReplicatedStorage.Shared.WeaponModels)
local SkinPaint = require(ReplicatedStorage.Shared.SkinPaint)
local A = require(ReplicatedStorage.Shared.Attachments)
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
		-- accessoires de l'armurier (attribut Att de la poignée) et réticules du propriétaire
		local owner = Players:GetPlayerFromCharacter(char :: any)
		local att = A.list(key, A.decode(held:GetAttribute("Att")), nil, true)
		local ok, model = pcall(WeaponModels.build, key, WORLD_SCALE, att, { ret = function(o: string) return A.retOf(o, owner) end })
		if not ok or not model then warn("[WeaponVisuals]", key, model) return end
		WeaponModels.weldTo(model, held :: BasePart, (held :: BasePart).CFrame)
		SkinPaint.apply(model, held:GetAttribute("Skin") :: number?, held:GetAttribute("Camo") :: string?)
		model.Parent = held
	end)
end

workspace.DescendantAdded:Connect(function(d)
	if d.Name == "HeldWeapon" then dress(d) end
end)
for _, d in ipairs(workspace:GetDescendants()) do
	if d.Name == "HeldWeapon" then dress(d) end
end
