--!strict
-- StarterPlayerScripts/SprayController (LocalScript)
-- Touche J : spray sur le mur visé (src/64_extras.js). Le serveur (SprayService) vérifie la distance, le mur et le délai,
-- puis pose le spray pour tout le monde. Choix du spray : RemoteFunction SetSpray (menu Style, port du menu).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local G = require(ReplicatedStorage.Shared.Grenades)
local Sfx = require(ReplicatedStorage.Shared.Sfx)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local sprayEv = ReplicatedStorage:WaitForChild("Spray") :: RemoteEvent
local toast = ReplicatedStorage:WaitForChild("SprayToast") :: RemoteEvent

local gui = Instance.new("ScreenGui"); gui.Name = "SprayToast"; gui.ResetOnSpawn = false; gui.DisplayOrder = 11; gui.Parent = player:WaitForChild("PlayerGui")
local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 0); label.Position = UDim2.new(0.5, 0, 0.62, 0); label.Size = UDim2.fromOffset(300, 24)
label.BackgroundTransparency = 1; label.Font = Enum.Font.GothamBold; label.TextSize = 15; label.TextColor3 = Color3.new(1, 1, 1)
label.TextStrokeTransparency = 0.4; label.Text = ""; label.Parent = gui
local stamp = 0
toast.OnClientEvent:Connect(function(txt: string)
	label.Text = txt
	stamp += 1
	local mine = stamp
	task.delay(1.6, function() if stamp == mine then label.Text = "" end end)
end)

local lastAsk = 0
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed or input.KeyCode ~= Enum.KeyCode.J then return end
	if player:GetAttribute("UiOpen") == true or os.clock() - lastAsk < 0.3 then return end
	lastAsk = os.clock()
	sprayEv:FireServer(camera.CFrame.LookVector)
end)

sprayEv.OnClientEvent:Connect(function(_who: Player, at: Vector3)
	pcall(function() Sfx.play(G.SFX.smoke, at, 0.25) end)
end)
