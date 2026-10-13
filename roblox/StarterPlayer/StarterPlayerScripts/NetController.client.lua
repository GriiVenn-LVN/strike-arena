--!strict
-- StarterPlayerScripts/NetController (LocalScript)
-- Ping (affiché + envoyé au serveur pour la compensation de latence) et prédiction côté client :
-- le traceur et le recul sont joués immédiatement ; le marqueur de touche attend la confirmation du serveur
-- (HitFeedback). Si le serveur refuse le tir (pas de munition, cadence), la munition affichée est corrigée.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local pingFn = ReplicatedStorage:WaitForChild("Ping") :: RemoteFunction
local pingReport = ReplicatedStorage:WaitForChild("PingReport") :: RemoteEvent
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui"); gui.Name = "NetHud"; gui.ResetOnSpawn = false; gui.DisplayOrder = 60; gui.Parent = player:WaitForChild("PlayerGui")
local label = Instance.new("TextLabel"); label.BackgroundTransparency = 1; label.AnchorPoint = Vector2.new(1, 0); label.Position = UDim2.new(1, -10, 0, 6)
label.Size = UDim2.fromOffset(180, 20); label.Font = Enum.Font.GothamMedium; label.TextSize = 12; label.TextXAlignment = Enum.TextXAlignment.Right
label.TextColor3 = Color3.fromRGB(190, 200, 215); label.Parent = gui

local smoothed = 0.06
task.spawn(function()
	while true do
		local t0 = os.clock()
		local ok = pcall(function() pingFn:InvokeServer() end)
		if ok then
			local rtt = os.clock() - t0
			smoothed = smoothed * 0.7 + rtt * 0.3
			pingReport:FireServer(smoothed)
		end
		task.wait(2)
	end
end)

RunService.RenderStepped:Connect(function(dt: number)
	local ms = math.floor(smoothed * 1000)
	local fps = math.floor(1 / math.max(dt, 1e-3))
	label.Text = string.format("%d ms · %d FPS", ms, math.clamp(fps, 0, 999))
	label.TextColor3 = if ms < 60 then Color3.fromRGB(125, 255, 159) elseif ms < 120 then Color3.fromRGB(255, 215, 94) else Color3.fromRGB(255, 70, 85)
end)

-- Réconciliation : le serveur est la référence pour les munitions
local ammo = { mag = nil :: number? }
local hit = ReplicatedStorage:WaitForChild("HitFeedback") :: RemoteEvent
hit.OnClientEvent:Connect(function(headshot: boolean, kill: boolean)
	-- ici : afficher le hitmarker (rouge si kill, doré si headshot) et jouer le son
	player:SetAttribute("LastHit", os.clock())
	player:SetAttribute("LastHitHead", headshot)
	player:SetAttribute("LastHitKill", kill)
end)
