--!strict
-- StarterPlayerScripts/MedalController (LocalScript)
-- • Médailles en partie (src/8G_medals.js #medalPop) : icône, nom, « +XP », l'une après l'autre au-dessus du centre.
-- • Écran de fin : rangée des médailles du match et bilan perso (précision, têtes, dégâts, meilleure série,
--   src/8Zf_confort.js #oPerso), sous les cartes de l'écran de fin de HudController.
-- • Petits messages : défi du jour / de la semaine terminé (ChallengeDone), citrouilles ramassées (PumpkinToast).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Medals = require(ReplicatedStorage.Shared.Medals)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local ModeConfig = require(ReplicatedStorage.Shared.ModeConfig)

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 210, 58)
local PANEL = Color3.fromRGB(15, 23, 38)
local DIM = Color3.fromRGB(141, 160, 189)

local gui = Instance.new("ScreenGui"); gui.Name = "MedalHud"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.DisplayOrder = 12
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; gui.Parent = player:WaitForChild("PlayerGui")

local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local o = Instance.new(class)
	if o:IsA("GuiObject") then (o :: any).BorderSizePixel = 0 end
	for k, v in pairs(props) do (o :: any)[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function tween(o: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?)
	TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end
local function spaced(s: string): string
	local out = {}
	for _, cp in utf8.codes(s) do table.insert(out, utf8.char(cp)) end
	return table.concat(out, "\u{200A}")   -- espace fine
end

-- ---------- médaille en partie ----------
local pop = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.25), Size = UDim2.fromOffset(320, 110), BackgroundTransparency = 1 }, gui)
local popScale = make("UIScale", { Scale = 0.6 }, pop)
local popIcon = make("TextLabel", { Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1, TextSize = 46, Font = Enum.Font.GothamBold, Text = "", TextTransparency = 1, TextColor3 = Color3.new(1, 1, 1) }, pop)
local popName = make("TextLabel", { Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, TextSize = 17, Font = Enum.Font.GothamBlack,
	TextColor3 = GOLD, Text = "", TextTransparency = 1, TextStrokeTransparency = 1 }, pop)
local popXp = make("TextLabel", { Position = UDim2.fromOffset(0, 82), Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, TextSize = 13, Font = Enum.Font.GothamBold,
	TextColor3 = Color3.new(1, 1, 1), Text = "", TextTransparency = 1 }, pop)
local queue: { string } = {}
local showing = false
local function showNext()
	if showing or #queue == 0 then return end
	showing = true
	local id = table.remove(queue, 1) :: string
	local m = Medals.LIST[id]
	popIcon.Text = m.ic; popName.Text = spaced(string.upper(m.n)); popXp.Text = "+" .. m.xp .. " XP"
	popScale.Scale = 0.6
	tween(popScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	for _, l in ipairs({ popIcon, popName, popXp }) do tween(l, 0.2, { TextTransparency = if l == popXp then 0.2 else 0 }) end
	tween(popName, 0.2, { TextStrokeTransparency = 0.4 })
	pcall(function() Sfx.play(ModeConfig.SOUNDS.streak) end)
	task.delay(1.15, function()
		for _, l in ipairs({ popIcon, popName, popXp }) do tween(l, 0.2, { TextTransparency = 1 }) end
		tween(popName, 0.2, { TextStrokeTransparency = 1 })
		task.delay(0.2, function() showing = false; showNext() end)
	end)
end
local popRemote = ReplicatedStorage:WaitForChild("MedalPop", 30) :: RemoteEvent?
if popRemote then
	popRemote.OnClientEvent:Connect(function(id: any)
		if typeof(id) == "string" and Medals.LIST[id] then table.insert(queue, id); showNext() end
	end)
end

-- ---------- écran de fin : médailles + bilan perso ----------
local endBox = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.42, 162), Size = UDim2.fromOffset(780, 120), BackgroundTransparency = 1, Visible = false }, gui)
make("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, endBox)
local function row(order: number): Frame
	local r = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order }, endBox)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), Wraps = true }, r)
	return r
end
local medalRow, persoRow = row(1), row(2)
local endToken = 0
local function clearRows()
	for _, r in ipairs({ medalRow, persoRow }) do for _, c in ipairs(r:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end end
end
local endRemote = ReplicatedStorage:WaitForChild("MatchEnd", 30) :: RemoteEvent?
if endRemote then
	endRemote.OnClientEvent:Connect(function(r: any)
		clearRows()
		endToken += 1
		local my = endToken
		local any = false
		for _, md in ipairs(if typeof(r.medals) == "table" then r.medals else {}) do
			any = true
			local chip = make("TextLabel", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 28), BackgroundColor3 = PANEL, BackgroundTransparency = 0.05,
				Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.new(1, 1, 1), RichText = true,
				Text = "  " .. md.ic .. " " .. md.n .. (if md.count > 1 then ' <font color="#ffd23a">×' .. md.count .. "</font>" else "") .. "  " }, medalRow)
			make("UICorner", { CornerRadius = UDim.new(0, 8) }, chip)
			make("UIStroke", { Color = GOLD, Transparency = 0.7, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, chip)
		end
		local b = r.bilan
		if typeof(b) == "table" then
			any = true
			local tiles = { { "PRÉCISION", if b.acc then b.acc .. " %" else "—" }, { "TÊTES", if b.hsPct then b.hsPct .. " %" else "—" },
				{ "DÉGÂTS", tostring(b.dmg or 0) }, { "MEILLEURE SÉRIE", tostring(b.streak or 0) } }
			for _, t in ipairs(tiles) do
				local f = make("Frame", { Size = UDim2.fromOffset(120, 50), BackgroundColor3 = PANEL, BackgroundTransparency = 0.05 }, persoRow)
				make("UICorner", { CornerRadius = UDim.new(0, 8) }, f)
				make("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.92, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, f)
				make("TextLabel", { Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 12), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 10,
					TextColor3 = DIM, Text = spaced(t[1]) }, f)
				make("TextLabel", { Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 19,
					TextColor3 = Color3.new(1, 1, 1), Text = t[2] }, f)
			end
		end
		endBox.Visible = any
		task.delay((tonumber(r.next) or 15) + 0.5, function() if my == endToken then endBox.Visible = false end end)
	end)
end
-- l'écran de fin se ferme quand on quitte la partie ou qu'une nouvelle commence
player:GetAttributeChangedSignal("Zone"):Connect(function() if player:GetAttribute("Zone") ~= "match" then endBox.Visible = false end end)
local stateRemote = ReplicatedStorage:WaitForChild("TDMState", 30) :: RemoteEvent?
if stateRemote then
	stateRemote.OnClientEvent:Connect(function(st: any)
		if typeof(st) == "table" and st.warmup then endBox.Visible = false end
	end)
end

-- ---------- petits messages (défis, citrouilles) ----------
local toasts = make("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 120), Size = UDim2.fromOffset(340, 300), BackgroundTransparency = 1 }, gui)
make("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Right }, toasts)
local function toast(text: string, color: Color3)
	local l = make("TextLabel", { AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.fromOffset(340, 0), BackgroundColor3 = PANEL, BackgroundTransparency = 0.1,
		Font = Enum.Font.GothamBold, TextSize = 14, TextWrapped = true, TextColor3 = Color3.new(1, 1, 1), Text = text, TextXAlignment = Enum.TextXAlignment.Left }, toasts)
	make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7) }, l)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, l)
	make("UIStroke", { Color = color, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, l)
	task.delay(4, function()
		tween(l, 0.4, { BackgroundTransparency = 1, TextTransparency = 1 })
		task.delay(0.45, function() l:Destroy() end)
	end)
end
local doneRemote = ReplicatedStorage:WaitForChild("ChallengeDone", 30) :: RemoteEvent?
if doneRemote then
	doneRemote.OnClientEvent:Connect(function(d: any)
		if typeof(d) ~= "table" then return end
		toast((if d.weekly then "Défi de la semaine terminé : " else "Défi du jour terminé : ") .. tostring(d.text) .. "  (💰 " .. tostring(d.coins) .. " • " .. tostring(d.xp) .. " XP à récupérer)",
			if d.weekly then Color3.fromRGB(199, 125, 255) else GOLD)
		pcall(function() Sfx.play(ModeConfig.SOUNDS.streak) end)
	end)
end
local pkRemote = ReplicatedStorage:WaitForChild("PumpkinToast", 30) :: RemoteEvent?
if pkRemote then
	pkRemote.OnClientEvent:Connect(function(d: any)
		if typeof(d) ~= "table" then return end
		toast("🎃 Citrouille ramassée : " .. tostring(d.count), Color3.fromRGB(255, 138, 42))
		for _, line in ipairs(if typeof(d.lines) == "table" then d.lines else {}) do toast(tostring(line), Color3.fromRGB(255, 138, 42)) end
	end)
end
