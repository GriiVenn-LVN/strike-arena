--!strict
-- StarterPlayerScripts/AbilityController (LocalScript)
-- Touches X / Z (modifiables via profile.binds), icônes avec recharge, révélation (Scan) par Highlight.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local X = require(ReplicatedStorage.Shared.ConfigExtra)
local useRemote = ReplicatedStorage:WaitForChild("UseAbility") :: RemoteEvent
local feedback = ReplicatedStorage:WaitForChild("AbilityFeedback") :: RemoteEvent
local pickAgent = ReplicatedStorage:WaitForChild("PickAgent") :: RemoteFunction

local player = Players.LocalPlayer
local binds = { Enum.KeyCode.X, Enum.KeyCode.Z }
local readyAt = { 0, 0 }
local maxCd = { 1, 1 }

local gui = Instance.new("ScreenGui"); gui.Name = "Abilities"; gui.ResetOnSpawn = false; gui.Parent = player:WaitForChild("PlayerGui")
local icons = {}
for i = 1, 2 do
	local f = Instance.new("Frame"); f.Size = UDim2.fromOffset(58, 58); f.Position = UDim2.new(0.5, (i - 1.5) * 68, 1, -150)
	f.BackgroundColor3 = Color3.fromRGB(14, 18, 28); f.BackgroundTransparency = 0.15; f.Parent = gui
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)
	local stroke = Instance.new("UIStroke", f); stroke.Color = Color3.fromRGB(125, 211, 252); stroke.Thickness = 1.5
	local cd = Instance.new("Frame"); cd.AnchorPoint = Vector2.new(0, 1); cd.Position = UDim2.fromScale(0, 1); cd.Size = UDim2.fromScale(1, 0)
	cd.BackgroundColor3 = Color3.new(0, 0, 0); cd.BackgroundTransparency = 0.4; cd.BorderSizePixel = 0; cd.Parent = f
	local key = Instance.new("TextLabel"); key.BackgroundTransparency = 1; key.Size = UDim2.fromOffset(20, 16); key.Position = UDim2.fromOffset(4, 2)
	key.Font = Enum.Font.GothamBold; key.TextSize = 12; key.TextColor3 = Color3.new(1, 1, 1); key.Text = binds[i].Name; key.Parent = f
	local name = Instance.new("TextLabel"); name.BackgroundTransparency = 1; name.Size = UDim2.fromScale(1, 1); name.Font = Enum.Font.GothamMedium
	name.TextSize = 11; name.TextColor3 = Color3.new(1, 1, 1); name.Text = ""; name.Parent = f
	local t = Instance.new("TextLabel"); t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(1, 1); t.Font = Enum.Font.GothamBold; t.TextSize = 20
	t.TextColor3 = Color3.new(1, 1, 1); t.Text = ""; t.Parent = f
	icons[i] = { frame = f, cd = cd, name = name, time = t, stroke = stroke }
end

local function setAgent(id: string)
	local agent = X.AGENTS[id]
	for i = 1, 2 do
		local ab = agent.abilities[i]
		icons[i].frame.Visible = ab ~= nil
		icons[i].name.Text = ab and ab.name or ""
	end
	pickAgent:InvokeServer(id)
end
player:GetAttributeChangedSignal("Agent"):Connect(function() setAgent((player:GetAttribute("Agent") :: string?) or "none") end)
setAgent((player:GetAttribute("Agent") :: string?) or "nova")

for i = 1, 2 do
	ContextActionService:BindAction("Ability" .. i, function(_, state)
		if state == Enum.UserInputState.Begin then useRemote:FireServer(i) end
		return Enum.ContextActionResult.Sink
	end, false, binds[i])
end

feedback.OnClientEvent:Connect(function(kind: string, a: any, b: any)
	if kind == "cooldown" then
		readyAt[a] = os.clock() + b; maxCd[a] = b
	elseif kind == "reveal" and typeof(a) == "Instance" and a:IsA("Player") and a.Character then
		local h = Instance.new("Highlight"); h.FillColor = Color3.fromRGB(255, 80, 80); h.OutlineColor = Color3.fromRGB(255, 220, 90)
		h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; h.Parent = a.Character
		task.delay(b, function() h:Destroy() end)
	end
end)

game:GetService("RunService").RenderStepped:Connect(function()
	for i = 1, 2 do
		local left = math.max(0, readyAt[i] - os.clock())
		icons[i].cd.Size = UDim2.fromScale(1, left / maxCd[i])
		icons[i].time.Text = if left > 0 then tostring(math.ceil(left)) else ""
	end
end)
