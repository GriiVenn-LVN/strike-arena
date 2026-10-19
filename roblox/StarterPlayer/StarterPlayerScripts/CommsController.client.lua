--!strict
-- StarterPlayerScripts/CommsController (LocalScript)
-- Ping et messages rapides d'équipe (TeamCommsService) :
--   • clic molette ou K : ping sur le point visé ; un ennemi visé est marqué en rouge et suivi quelques secondes.
--   • N : ouvre la liste des messages rapides, 1 à 6 pour en envoyer un (N ou Échap pour fermer).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local TeamComms = require(ReplicatedStorage.Shared.TeamComms)
local Sfx = require(ReplicatedStorage.Shared.Sfx)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local pingIn = ReplicatedStorage:WaitForChild("TeamPing") :: RemoteEvent
local pingOut = ReplicatedStorage:WaitForChild("TeamPingShow") :: RemoteEvent
local chatIn = ReplicatedStorage:WaitForChild("QuickChat") :: RemoteEvent
local chatOut = ReplicatedStorage:WaitForChild("QuickChatShow") :: RemoteEvent

local GOLD, RED, TEXT = Color3.fromRGB(255, 215, 94), Color3.fromRGB(255, 70, 85), Color3.fromRGB(232, 238, 249)
local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

local gui = Instance.new("ScreenGui"); gui.Name = "TeamComms"; gui.ResetOnSpawn = false; gui.DisplayOrder = 9
gui.IgnoreGuiInset = true; gui.Parent = player:WaitForChild("PlayerGui")

local function inMatch(): boolean return typeof(player:GetAttribute("MatchId")) == "number" end
local function uiBlocked(): boolean
	return player:GetAttribute("UiOpen") == true or player:GetAttribute("MenuOpen") == true
end

-- ---------- ping ----------
local function aimedPoint(): (Vector3?, Model?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = { camera }                      -- le modèle de l'arme en vue FPS est rangé sous la caméra
	if player.Character then table.insert(skip, player.Character) end
	params.FilterDescendantsInstances = skip
	local cf = camera.CFrame
	local r = workspace:Raycast(cf.Position, cf.LookVector * 800, params)
	if not r then return nil, nil end
	local model = r.Instance:FindFirstAncestorOfClass("Model")
	while model and not model:FindFirstChildOfClass("Humanoid") do model = model:FindFirstAncestorOfClass("Model") end
	return r.Position, model
end

local lastAsk = 0
local function askPing()
	if not inMatch() or uiBlocked() or os.clock() - lastAsk < TeamComms.PING_COOLDOWN then return end
	local pos, model = aimedPoint()
	if not pos then return end
	lastAsk = os.clock()
	pingIn:FireServer(pos, model)
end

type Ping = { bb: BillboardGui, anchor: Part?, dist: TextLabel, born: number, life: number, target: Model? }
local pings: { Ping } = {}

local function showPing(pos: Vector3, kind: string, who: string, target: Model?)
	local enemy = kind == "enemy"
	local color = if enemy then RED else GOLD
	local anchor: Part? = nil
	local adornee: BasePart? = target and target:FindFirstChild("Head") :: BasePart?
	if not adornee then
		local a = Instance.new("Part")
		a.Anchored = true; a.CanCollide = false; a.CanQuery = false; a.CanTouch = false; a.Transparency = 1
		a.Size = Vector3.one * 0.2; a.Position = pos; a.Parent = workspace
		anchor = a; adornee = a
	end
	local bb = Instance.new("BillboardGui")
	bb.AlwaysOnTop = true; bb.LightInfluence = 0; bb.Size = UDim2.fromOffset(120, 64)
	bb.StudsOffsetWorldSpace = if target then Vector3.new(0, 2.2, 0) else Vector3.new(0, 1.2, 0)
	bb.Adornee = adornee :: BasePart; bb.Parent = gui
	-- losange façon Apex : carré tourné de 45°, avec une onde qui s'agrandit à l'arrivée
	local dia = Instance.new("Frame")
	dia.AnchorPoint = Vector2.new(0.5, 0.5); dia.Position = UDim2.new(0.5, 0, 0, 14); dia.Size = UDim2.fromOffset(14, 14)
	dia.Rotation = 45; dia.BackgroundColor3 = color; dia.BorderSizePixel = 0; dia.Parent = bb
	local st = Instance.new("UIStroke"); st.Color = Color3.new(0, 0, 0); st.Transparency = 0.4; st.Thickness = 1.5; st.Parent = dia
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5); ring.Position = dia.Position; ring.Size = UDim2.fromOffset(14, 14); ring.Rotation = 45
	ring.BackgroundTransparency = 1; ring.Parent = bb
	local rs = Instance.new("UIStroke"); rs.Color = color; rs.Thickness = 2; rs.Parent = ring
	TweenService:Create(ring, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(46, 46) }):Play()
	TweenService:Create(rs, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Transparency = 1 }):Play()
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1; name.Position = UDim2.fromOffset(0, 26); name.Size = UDim2.new(1, 0, 0, 16)
	name.FontFace = FONT; name.TextSize = 13; name.TextColor3 = color; name.TextStrokeTransparency = 0.4
	name.Text = if enemy then "ENNEMI" else string.upper(who); name.Parent = bb
	local dist = name:Clone(); dist.Position = UDim2.fromOffset(0, 42); dist.TextColor3 = TEXT; dist.TextSize = 12; dist.Text = ""; dist.Parent = bb
	table.insert(pings, { bb = bb, anchor = anchor, dist = dist, born = os.clock(),
		life = if enemy then TeamComms.PING_LIFE / 2 else TeamComms.PING_LIFE, target = target })
	pcall(function() Sfx.play(if enemy then "beep" else "tick", nil, 0.8) end)
end

pingOut.OnClientEvent:Connect(function(pos: Vector3, kind: string, who: string, target: Model?)
	showPing(pos, kind, who, target)
end)

RunService.RenderStepped:Connect(function()
	if #pings == 0 then return end
	local now, eye = os.clock(), camera.CFrame.Position
	for i = #pings, 1, -1 do
		local p = pings[i]
		local hum = p.target and p.target:FindFirstChildOfClass("Humanoid")
		local gone = not p.bb.Adornee or not p.bb.Adornee.Parent or (p.target ~= nil and (not hum or hum.Health <= 0))
		if gone or now - p.born > p.life or not inMatch() then
			p.bb:Destroy(); if p.anchor then p.anchor:Destroy() end
			table.remove(pings, i)
		else
			local ad = p.bb.Adornee :: BasePart
			p.dist.Text = math.floor((ad.Position - eye).Magnitude / 3.57 + 0.5) .. " m"   -- 1 m ≈ 3,57 studs (Config.STUDS_PER_METER)
			local fade = math.clamp((p.born + p.life - now) / 0.5, 0, 1)                    -- fondu sur la dernière demi-seconde
			for _, d in ipairs(p.bb:GetDescendants()) do
				if d:IsA("TextLabel") then d.TextTransparency = 1 - fade end
			end
		end
	end
end)

-- ---------- messages rapides ----------
local list = Instance.new("Frame")
list.AnchorPoint = Vector2.new(0, 0.5); list.Position = UDim2.new(0, 24, 0.55, 0); list.Size = UDim2.fromOffset(250, 34 + #TeamComms.LINES * 26)
list.BackgroundColor3 = Color3.fromRGB(14, 19, 30); list.BackgroundTransparency = 0.15; list.BorderSizePixel = 0; list.Visible = false; list.Parent = gui
local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 4); corner.Parent = list
local edge = Instance.new("UIStroke"); edge.Color = Color3.fromRGB(42, 55, 80); edge.Parent = list
local head = Instance.new("TextLabel")
head.BackgroundTransparency = 1; head.Position = UDim2.fromOffset(12, 6); head.Size = UDim2.new(1, -24, 0, 22)
head.FontFace = FONT; head.TextSize = 13; head.TextColor3 = GOLD; head.TextXAlignment = Enum.TextXAlignment.Left
head.Text = "MESSAGES RAPIDES"; head.Parent = list
for i, line in ipairs(TeamComms.LINES) do
	local l = head:Clone()
	l.Position = UDim2.fromOffset(12, 6 + i * 26); l.TextColor3 = TEXT; l.TextSize = 14
	l.Text = '<font color="#ffd75e">' .. i .. "</font>   " .. line; l.RichText = true; l.Parent = list
end

local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six }
local open = false
local function close()
	if not open then return end
	open = false; list.Visible = false
	ContextActionService:UnbindAction("QuickChatPick")
end
local function pick(_: string, st: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
	if st ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
	local i = table.find(KEYS, input.KeyCode)
	if i then chatIn:FireServer(i) end
	close()
	return Enum.ContextActionResult.Sink
end
local function toggle()
	if open then close(); return end
	if not inMatch() or uiBlocked() then return end
	open = true; list.Visible = true
	-- priorité haute : les touches 1 à 6 choisissent un message au lieu de changer d'arme
	ContextActionService:BindActionAtPriority("QuickChatPick", pick, false, Enum.ContextActionPriority.High.Value + 10,
		Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Escape)
	task.delay(4, function() close() end)
end

-- fil des messages reçus, en bas à gauche au-dessus du chat
local feed = Instance.new("Frame")
feed.AnchorPoint = Vector2.new(0, 1); feed.Position = UDim2.new(0, 24, 0.78, 0); feed.Size = UDim2.fromOffset(420, 120)
feed.BackgroundTransparency = 1; feed.Parent = gui
local lay = Instance.new("UIListLayout"); lay.VerticalAlignment = Enum.VerticalAlignment.Bottom; lay.Padding = UDim.new(0, 2)
lay.SortOrder = Enum.SortOrder.LayoutOrder; lay.Parent = feed
local order = 0
chatOut.OnClientEvent:Connect(function(who: string, index: number)
	local line = TeamComms.LINES[index]
	if not line then return end
	order += 1
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1; l.Size = UDim2.new(1, 0, 0, 20); l.LayoutOrder = order; l.RichText = true
	l.FontFace = FONT; l.TextSize = 15; l.TextColor3 = TEXT; l.TextStrokeTransparency = 0.4; l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = '<font color="#7dff9f">[ÉQUIPE] ' .. who .. "</font> : " .. line; l.Parent = feed
	pcall(function() Sfx.play("ui", nil, 0.6) end)
	task.delay(5, function()
		TweenService:Create(l, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.wait(0.45); l:Destroy()
	end)
	local kids = {}
	for _, c in ipairs(feed:GetChildren()) do if c:IsA("TextLabel") then table.insert(kids, c) end end
	if #kids > 5 then table.sort(kids, function(a, b) return a.LayoutOrder < b.LayoutOrder end); kids[1]:Destroy() end
end)

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton3 or input.KeyCode == Enum.KeyCode.K then askPing()
	elseif input.KeyCode == Enum.KeyCode.N then toggle() end
end)
player:GetAttributeChangedSignal("MatchId"):Connect(close)
