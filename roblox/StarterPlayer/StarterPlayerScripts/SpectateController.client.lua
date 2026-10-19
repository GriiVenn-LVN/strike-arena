--!strict
-- StarterPlayerScripts/SpectateController (LocalScript)
-- Spectateur après la mort, comme dans CS et Valorant : une fois la kill-cam finie, si on attend encore sa
-- réapparition (Recherche et destruction, manches, Élimination…), la caméra suit un coéquipier en vie.
-- Clic gauche / droit (ou flèches, gâchettes de la manette) : coéquipier suivant / précédent.
-- On ne regarde jamais un adversaire : la liste ne contient que des soldats de son équipe dans sa partie.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local S = require(ReplicatedStorage.Shared.ClientState)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local DELAY = 2.5          -- secondes après la mort (et après la kill-cam) avant de passer en spectateur

local gui = Instance.new("ScreenGui"); gui.Name = "Spectate"; gui.ResetOnSpawn = false; gui.DisplayOrder = 8
gui.IgnoreGuiInset = true; gui.Enabled = false; gui.Parent = player:WaitForChild("PlayerGui")
local bar = Instance.new("TextLabel")
bar.AnchorPoint = Vector2.new(0.5, 1); bar.Position = UDim2.new(0.5, 0, 1, -150); bar.Size = UDim2.fromOffset(520, 44)
bar.BackgroundColor3 = Color3.fromRGB(14, 19, 30); bar.BackgroundTransparency = 0.25; bar.BorderSizePixel = 0; bar.RichText = true
bar.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold); bar.TextSize = 16
bar.TextColor3 = Color3.fromRGB(232, 238, 249); bar.Text = ""; bar.Parent = gui
local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 4); corner.Parent = bar

local watching: Model? = nil
local deadSince: number? = nil

local function myHumanoid(): Humanoid?
	return player.Character and player.Character:FindFirstChildOfClass("Humanoid")
end
local function alive(m: Model): boolean
	local h = m:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0 and m:FindFirstChild("HumanoidRootPart") ~= nil
end

-- coéquipiers en vie de la même partie (joueurs puis bots), dans un ordre stable
local function mates(): { Model }
	local id, team = player:GetAttribute("MatchId"), player:GetAttribute("Team")
	local list = {}
	if typeof(id) ~= "number" or typeof(team) ~= "string" or string.sub(team, 1, 5) == "solo:" then return list end
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p:GetAttribute("MatchId") == id and p:GetAttribute("Team") == team and p.Character and alive(p.Character) then
			table.insert(list, p.Character)
		end
	end
	local bots = workspace:FindFirstChild("Bots")
	if bots then
		for _, b in ipairs(bots:GetChildren()) do
			if b:IsA("Model") and b:GetAttribute("MatchId") == id and b:GetAttribute("Team") == team and alive(b) then table.insert(list, b) end
		end
	end
	return list
end

local function nameOf(m: Model): string
	local p = Players:GetPlayerFromCharacter(m)
	return if p then p.DisplayName else "[BOT] " .. m.Name
end

local function watch(m: Model?)
	watching = m
	if m then
		-- caméra libre placée derrière l'épaule (en vue FPS verrouillée, suivre un autre Humanoid mettrait l'œil dans sa tête)
		camera.CameraType = Enum.CameraType.Scriptable
		local n = #mates()
		bar.Text = 'SPECTATEUR  <font color="#ffd75e">' .. nameOf(m) .. "</font>"
			.. (if n > 1 then '   <font color="#8da0bd" size="13">clic : changer (' .. n .. ")</font>" else "")
		gui.Enabled = true
	else
		gui.Enabled = false
		if camera.CameraType == Enum.CameraType.Scriptable and S.kc == nil then camera.CameraType = Enum.CameraType.Custom end
		local h = myHumanoid()
		if h then camera.CameraSubject = h end
	end
end

local function step(dir: number)
	local list = mates()
	if #list == 0 then watch(nil); return end
	local i = (watching and table.find(list, watching)) or 0
	watch(list[(i - 1 + dir) % #list + 1])
end

RunService.Heartbeat:Connect(function()
	local h = myHumanoid()
	local dead = typeof(player:GetAttribute("MatchId")) == "number" and (not h or h.Health <= 0)
	if not dead then
		deadSince = nil
		if watching then watch(nil) end
		return
	end
	if S.kc ~= nil then deadSince = os.clock(); if watching then watch(nil) end; return end   -- la kill-cam a la caméra
	deadSince = deadSince or os.clock()
	if os.clock() - (deadSince :: number) < DELAY then return end
	if not watching or not watching.Parent or not alive(watching) then step(1) end
end)

-- au-dessus de l'épaule droite, dans la direction où regarde le coéquipier (attribut Pitch des soldats pour la hauteur)
RunService:BindToRenderStep("Spectate", Enum.RenderPriority.Camera.Value + 2, function(dt: number)
	local m = watching
	if not m then return end
	local root = m:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end
	local pitch = m:GetAttribute("Pitch")
	local p = Players:GetPlayerFromCharacter(m)
	if typeof(pitch) ~= "number" and p then pitch = p:GetAttribute("Pitch") end
	local look = (root.CFrame * CFrame.Angles(math.clamp(if typeof(pitch) == "number" then pitch else 0, -1.2, 1.2), 0, 0)).LookVector
	local eye = root.Position + Vector3.new(0, 2.4, 0)
	local want = CFrame.lookAt(eye - look * 9 + root.CFrame.RightVector * 2.2 + Vector3.new(0, 1.2, 0), eye + look * 30)
	camera.CFrame = camera.CFrame:Lerp(want, math.min(1, dt * 10))
end)

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed or not watching then return end
	local t, k = input.UserInputType, input.KeyCode
	if t == Enum.UserInputType.MouseButton1 or k == Enum.KeyCode.Right or k == Enum.KeyCode.ButtonR1 then step(1)
	elseif t == Enum.UserInputType.MouseButton2 or k == Enum.KeyCode.Left or k == Enum.KeyCode.ButtonL1 then step(-1) end
end)
player.CharacterAdded:Connect(function() deadSince = nil; if watching then watch(nil) end end)
