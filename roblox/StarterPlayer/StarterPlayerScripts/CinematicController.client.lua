--!strict
-- StarterPlayerScripts/CinematicController (LocalScript)
-- Cinématique d'arrivée en hélicoptère (style Call of Duty) : approche, caméra de poursuite, descente en rappel.
-- Place ton hélicoptère dans ReplicatedStorage/Assets/Helicopter (Model avec PrimaryPart) ; sinon un modèle simple est généré.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local cineEvent = ReplicatedStorage:WaitForChild("PlayCinematic") :: RemoteEvent

local function buildFallbackHeli(): Model
	local m = Instance.new("Model"); m.Name = "Helicopter"
	local body = Instance.new("Part"); body.Name = "Body"; body.Size = Vector3.new(9, 8, 22); body.Color = Color3.fromRGB(76, 91, 61)
	body.Anchored = true; body.CanCollide = false; body.Material = Enum.Material.Metal; body.Parent = m
	local rotor = Instance.new("Part"); rotor.Name = "Rotor"; rotor.Size = Vector3.new(50, 0.4, 2); rotor.Color = Color3.fromRGB(35, 40, 43)
	rotor.Anchored = true; rotor.CanCollide = false; rotor.Parent = m
	local tail = Instance.new("Part"); tail.Name = "Tail"; tail.Size = Vector3.new(2.5, 3, 18); tail.Color = body.Color
	tail.Anchored = true; tail.CanCollide = false; tail.Parent = m
	m.PrimaryPart = body
	return m
end

local function letterbox(on: boolean)
	local gui = player:WaitForChild("PlayerGui"):FindFirstChild("CinematicBars") :: ScreenGui?
	if not gui then
		gui = Instance.new("ScreenGui"); gui.Name = "CinematicBars"; gui.IgnoreGuiInset = true; gui.ResetOnSpawn = false; gui.Parent = player.PlayerGui
		for i, pos in ipairs({ UDim2.fromScale(0, 0), UDim2.fromScale(0, 0.89) }) do
			local f = Instance.new("Frame"); f.Name = "Bar" .. i; f.Size = UDim2.fromScale(1, 0.11); f.Position = pos
			f.BackgroundColor3 = Color3.new(0, 0, 0); f.BorderSizePixel = 0; f.Parent = gui
		end
		local title = Instance.new("TextLabel"); title.Name = "Title"; title.BackgroundTransparency = 1
		title.Size = UDim2.fromScale(0.8, 0.12); title.Position = UDim2.fromScale(0.06, 0.74); title.TextXAlignment = Enum.TextXAlignment.Left
		title.Font = Enum.Font.GothamBlack; title.TextScaled = true; title.TextColor3 = Color3.new(1, 1, 1); title.Parent = gui
	end
	gui.Enabled = on
	return gui
end

cineEvent.OnClientEvent:Connect(function(info)
	local skip = false
	local conn = UserInputService.InputBegan:Connect(function(i, gp) if i.KeyCode == Enum.KeyCode.Space then skip = true end end)

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local heli: Model = (assets and assets:FindFirstChild("Helicopter") and (assets.Helicopter :: Model):Clone()) or buildFallbackHeli()
	heli.Parent = workspace

	local hover: Vector3 = info.hover
	local dirSign = info.north and 1 or -1                 -- direction d'approche (nord = on arrive par -Z)
	local start = hover + Vector3.new(0, 30, -dirSign * 260)
	local yaw = info.north and math.pi or 0
	local bars = letterbox(true);
	(bars.Title :: TextLabel).Text = string.upper(info.mapName) .. " — " .. info.team

	camera.CameraType = Enum.CameraType.Scriptable
	local duration: number = info.duration or 10
	local t0 = os.clock()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then root.Anchored = true end                 -- le joueur est "dans" l'hélico pendant la cinématique

	local cn
	cn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local k = math.clamp(t / 6.6, 0, 1); k = 1 - (1 - k) ^ 3          -- ease-out
		local pos = start:Lerp(hover, k) + Vector3.new(0, math.sin(t * 1.7) * 0.4, 0)
		local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
		heli:PivotTo(cf)
		local rotor = heli:FindFirstChild("Rotor") :: BasePart?
		if rotor then rotor.CFrame = cf * CFrame.new(0, 5, 0) * CFrame.Angles(0, t * 40, 0) end
		-- plans de caméra : 1) passage au sol, 2) poursuite, 3) vue du sol sur le rappel
		if t < 3.2 then
			camera.CFrame = CFrame.lookAt(hover + Vector3.new(60, -35, dirSign * 20), pos)
		elseif t < 6.6 then
			camera.CFrame = CFrame.lookAt(pos + Vector3.new(math.sin(t * 0.5) * 30, 12, dirSign * 55), pos)
		else
			camera.CFrame = CFrame.lookAt(hover + Vector3.new(-30, -34 + (t - 6.6) * 1.2, -dirSign * 28), pos)
		end
		if t >= duration or skip then cn:Disconnect() end
	end)
	while os.clock() - t0 < duration and not skip do task.wait(0.05) end
	if cn.Connected then cn:Disconnect() end

	heli:Destroy(); conn:Disconnect()
	letterbox(false)
	if root then root.Anchored = false end
	camera.CameraType = Enum.CameraType.Custom
	if hum then camera.CameraSubject = hum end
end)
