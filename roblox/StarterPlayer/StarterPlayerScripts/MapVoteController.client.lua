--!strict
-- StarterPlayerScripts/MapVoteController (LocalScript)
-- Vote de la carte suivante sur l'écran de fin (MapVote côté serveur) : trois cartes cliquables (ou touches 1, 2, 3),
-- le nombre de votes en direct, puis la carte retenue. La souris est déjà libre sur l'écran de fin (bouton Modal du HUD).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Sfx = require(ReplicatedStorage.Shared.Sfx)

local player = Players.LocalPlayer
local push = ReplicatedStorage:WaitForChild("MapVote") :: RemoteEvent
local cast = ReplicatedStorage:WaitForChild("MapVoteCast") :: RemoteEvent

local GOLD, TEXT, DIM, LINE = Color3.fromRGB(255, 215, 94), Color3.fromRGB(232, 238, 249), Color3.fromRGB(141, 160, 189), Color3.fromRGB(42, 55, 80)
local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local HEAVY = Font.new("rbxasset://fonts/families/RobotoCondensed.json", Enum.FontWeight.Bold)
-- couleur de chaque thème de carte (ciels du web, src/41_gfx_themes.js) pour le bandeau des cartes
local THEME = {
	sand = Color3.fromRGB(214, 160, 92), industrial = Color3.fromRGB(120, 132, 150), snow = Color3.fromRGB(170, 205, 235),
	night = Color3.fromRGB(70, 96, 170), metro = Color3.fromRGB(150, 120, 90), jungle = Color3.fromRGB(80, 160, 90),
	haunt = Color3.fromRGB(120, 90, 160), halloween = Color3.fromRGB(240, 120, 40),
}

local gui = Instance.new("ScreenGui"); gui.Name = "MapVote"; gui.ResetOnSpawn = false; gui.DisplayOrder = 11
gui.IgnoreGuiInset = true; gui.Enabled = false; gui.Parent = player:WaitForChild("PlayerGui")
local root = Instance.new("Frame")
root.AnchorPoint = Vector2.new(0.5, 1); root.Position = UDim2.new(0.5, 0, 1, -128); root.Size = UDim2.fromOffset(660, 96)
root.BackgroundTransparency = 1; root.Parent = gui
local head = Instance.new("TextLabel")
head.BackgroundTransparency = 1; head.Size = UDim2.new(1, 0, 0, 18); head.FontFace = FONT; head.TextSize = 13; head.TextColor3 = DIM
head.Text = "VOTE POUR LA PROCHAINE CARTE  ·  1  2  3"; head.Parent = root
local row = Instance.new("Frame"); row.Position = UDim2.fromOffset(0, 22); row.Size = UDim2.new(1, 0, 0, 72); row.BackgroundTransparency = 1; row.Parent = root
local lay = Instance.new("UIListLayout"); lay.FillDirection = Enum.FillDirection.Horizontal; lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
lay.Padding = UDim.new(0, 12); lay.Parent = row

type Card = { b: TextButton, stroke: UIStroke, count: TextLabel, scale: UIScale }
local cards: { Card } = {}
local mine: number? = nil
local doneT = 0

local function vote(i: number)
	if not gui.Enabled or not cards[i] or mine == i then return end
	mine = i
	cast:FireServer(i)
	pcall(function() Sfx.play("ui", nil, 0.7) end)
	local c = cards[i]
	c.scale.Scale = 1.08
	TweenService:Create(c.scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

local function build(options: { any })
	for _, c in ipairs(cards) do c.b:Destroy() end
	table.clear(cards)
	for i, o in ipairs(options) do
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromOffset(204, 72); b.BackgroundColor3 = Color3.fromRGB(22, 30, 46); b.BackgroundTransparency = 0.1
		b.AutoButtonColor = false; b.Text = ""; b.LayoutOrder = i; b.Parent = row
		local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(0, 4); cr.Parent = b
		local st = Instance.new("UIStroke"); st.Color = LINE; st.Thickness = 1.5; st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st.Parent = b
		local sc = Instance.new("UIScale"); sc.Parent = b
		local band = Instance.new("Frame")
		band.Size = UDim2.new(0, 4, 1, 0); band.BackgroundColor3 = THEME[o.theme] or GOLD; band.BorderSizePixel = 0; band.Parent = b
		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1; name.Position = UDim2.fromOffset(16, 10); name.Size = UDim2.new(1, -60, 0, 28)
		name.FontFace = HEAVY; name.TextSize = 24; name.TextColor3 = TEXT; name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = string.upper(o.n); name.TextTruncate = Enum.TextTruncate.AtEnd; name.Parent = b
		local sub = name:Clone(); sub.Position = UDim2.fromOffset(16, 40); sub.Size = UDim2.new(1, -60, 0, 18)
		sub.FontFace = FONT; sub.TextSize = 12; sub.TextColor3 = DIM; sub.Text = if i == 1 then "Carte actuelle" else "Touche " .. i; sub.Parent = b
		local count = name:Clone(); count.AnchorPoint = Vector2.new(1, 0.5); count.Position = UDim2.new(1, -14, 0.5, 0); count.Size = UDim2.fromOffset(40, 40)
		count.TextXAlignment = Enum.TextXAlignment.Right; count.TextSize = 30; count.TextColor3 = GOLD; count.Text = "0"; count.Parent = b
		b.MouseEnter:Connect(function() if mine ~= i then st.Color = DIM end end)
		b.MouseLeave:Connect(function() if mine ~= i then st.Color = LINE end end)
		b.Activated:Connect(function() vote(i) end)
		table.insert(cards, { b = b, stroke = st, count = count, scale = sc })
	end
end

local function paint(votes: { number })
	for i, c in ipairs(cards) do
		c.count.Text = tostring(votes[i] or 0)
		c.stroke.Color = if mine == i then GOLD else LINE
		c.stroke.Thickness = if mine == i then 2.5 else 1.5
	end
end

push.OnClientEvent:Connect(function(d: any)
	if typeof(d) ~= "table" then return end
	if d.done then
		head.Text = "PROCHAINE CARTE : " .. string.upper(tostring(d.n or d.done))
		head.TextColor3 = GOLD
		for _, c in ipairs(cards) do c.b.Active = false end
		doneT += 1
		local my = doneT
		task.delay(2.5, function() if my == doneT then gui.Enabled = false end end)
		return
	end
	if typeof(d.options) ~= "table" then return end
	local fresh = not gui.Enabled or #cards ~= #d.options
	if fresh then
		mine = d.mine
		build(d.options)
		head.Text = "VOTE POUR LA PROCHAINE CARTE  ·  1  2  3"; head.TextColor3 = DIM
		gui.Enabled = true; doneT += 1
		root.Position = UDim2.new(0.5, 0, 1, -96)
		TweenService:Create(root, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Position = UDim2.new(0.5, 0, 1, -128) }):Play()
	end
	if d.mine then mine = d.mine end
	paint(d.votes or {})
end)

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed or not gui.Enabled then return end
	if input.KeyCode == Enum.KeyCode.One then vote(1)
	elseif input.KeyCode == Enum.KeyCode.Two then vote(2)
	elseif input.KeyCode == Enum.KeyCode.Three then vote(3) end
end)
player:GetAttributeChangedSignal("MatchId"):Connect(function()
	if typeof(player:GetAttribute("MatchId")) ~= "number" then gui.Enabled = false end
end)
