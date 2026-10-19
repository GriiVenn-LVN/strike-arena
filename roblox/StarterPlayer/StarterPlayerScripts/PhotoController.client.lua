--!strict
-- StarterPlayerScripts/PhotoController (LocalScript)
-- Entrée provisoire du mode photo (src/8Z_photo.js) : touche F4. Le menu pause pourra appeler
-- require(ReplicatedStorage.Shared.PhotoMode).enter() à la place.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local PhotoMode = require(ReplicatedStorage.Shared.PhotoMode)

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed or input.KeyCode ~= Enum.KeyCode.F4 then return end
	PhotoMode.toggle()
end)
