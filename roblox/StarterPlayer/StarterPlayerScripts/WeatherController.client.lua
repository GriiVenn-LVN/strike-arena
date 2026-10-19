--!strict
-- StarterPlayerScripts/WeatherController (LocalScript)
-- Pluie (ParticleEmitter qui suit la caméra), éclairs (flash + tonnerre) selon l'attribut Workspace.Weather.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local camera = workspace.CurrentCamera

local rainPart = Instance.new("Part")
-- ignorée des rayons (tirs, caméra, viseur) et des ombres : sinon on tirait dans un plafond invisible 30 studs au-dessus
rainPart.Anchored = true; rainPart.CanCollide = false; rainPart.CanQuery = false; rainPart.CanTouch = false; rainPart.CastShadow = false
rainPart.Transparency = 1; rainPart.Size = Vector3.new(60, 1, 60); rainPart.Name = "Pluie"
local rain = Instance.new("ParticleEmitter")
rain.Texture = "rbxasset://textures/particles/sparkles_main.dds"; rain.Rate = 0; rain.Lifetime = NumberRange.new(1.2)
rain.Speed = NumberRange.new(90); rain.EmissionDirection = Enum.NormalId.Bottom; rain.Size = NumberSequence.new(0.1, 0.1)
rain.Transparency = NumberSequence.new(0.5); rain.Color = ColorSequence.new(Color3.fromRGB(180, 200, 225)); rain.Orientation = Enum.ParticleOrientation.VelocityParallel
rain.Parent = rainPart; rainPart.Parent = workspace

local rainSound = Instance.new("Sound")
rainSound.SoundId = "rbxassetid://0"       -- remplace par un son de pluie (boucle)
rainSound.Looped = true; rainSound.Volume = 0.35; rainSound.Parent = SoundService

local thunder = Instance.new("Sound"); thunder.SoundId = "rbxassetid://0"; thunder.Volume = 0.9; thunder.Parent = SoundService

local function refresh()
	local w = workspace:GetAttribute("Weather")
	local raining = w == "rain" or w == "storm"
	rain.Rate = if w == "storm" then 900 elseif raining then 450 else 0
	if raining and not rainSound.IsPlaying then rainSound:Play() elseif not raining then rainSound:Stop() end
end
workspace:GetAttributeChangedSignal("Weather"):Connect(refresh)
refresh()

local nextLightning = os.clock() + 8
RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera or camera
	rainPart.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 30, 0))
	if workspace:GetAttribute("Weather") == "storm" and os.clock() > nextLightning then
		nextLightning = os.clock() + 7 + math.random() * 9
		local old = Lighting.Brightness
		Lighting.Brightness = old + 3
		task.delay(0.1, function() Lighting.Brightness = old + 1 end)
		task.delay(0.22, function() Lighting.Brightness = old end)
		task.delay(0.3 + math.random() * 1.2, function() thunder:Play() end)
	end
end)
