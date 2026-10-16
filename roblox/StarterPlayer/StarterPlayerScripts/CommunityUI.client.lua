--!strict
-- StarterPlayerScripts/CommunityUI (LocalScript)
-- Interface des ajouts « façon Roblox » : boutons Jouer / Lobby, panneau des codes promo, panneau du groupe Roblox,
-- rappel du like, messages et chronos du lobby (stand de tir, parcours), affichage des duels.
-- Le serveur vérifie tout (CodeService, LobbyService, DuelService) : ici on ne fait qu'afficher.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local GroupService = game:GetService("GroupService")

local CommunityConfig = require(ReplicatedStorage.Shared.CommunityConfig)

local player = Players.LocalPlayer

local C = {
	bg = Color3.fromRGB(13, 18, 29), panel = Color3.fromRGB(22, 29, 44), text = Color3.new(1, 1, 1), dim = Color3.fromRGB(150, 160, 180),
	red = Color3.fromRGB(255, 70, 85), blue = Color3.fromRGB(74, 163, 255), gold = Color3.fromRGB(255, 200, 60), green = Color3.fromRGB(80, 230, 140),
	purple = Color3.fromRGB(170, 90, 255), robloxGreen = Color3.fromRGB(0, 176, 111),
}

local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local o: any = Instance.new(class)
	if class == "TextLabel" or class == "TextButton" or class == "TextBox" then
		o.Font = Enum.Font.GothamBold; o.TextColor3 = C.text; o.BorderSizePixel = 0
	end
	if class == "TextLabel" then o.BackgroundTransparency = 1 end
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(o: Instance, r: number?) make("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o) end
local function tween(o: Instance, t: number, props: { [string]: any })
	TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local gui = make("ScreenGui", { Name = "CommunityUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 12,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))

-- ==========================================================================================
-- Message court en haut de l'écran
-- ==========================================================================================
local toast = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 150), Size = UDim2.fromOffset(620, 34),
	BackgroundTransparency = 0.2, BackgroundColor3 = C.bg, TextSize = 18, Text = "", Visible = false }, gui)
corner(toast, 10)
local toastToken = 0
local function showToast(text: string, color: Color3?, seconds: number?)
	toastToken += 1
	local my = toastToken
	toast.Text = text; toast.TextColor3 = color or C.text; toast.Visible = true
	toast.TextTransparency = 0; toast.BackgroundTransparency = 0.2
	task.delay(seconds or 4, function()
		if my ~= toastToken then return end
		tween(toast, 0.4, { TextTransparency = 1, BackgroundTransparency = 1 })
		task.delay(0.45, function() if my == toastToken then toast.Visible = false end end)
	end)
end

-- ==========================================================================================
-- Panneaux (libèrent la souris pendant qu'ils sont ouverts)
-- ==========================================================================================
local openPanel: Frame? = nil
local function setOpen(panel: Frame?)
	if openPanel and openPanel ~= panel then openPanel.Visible = false end
	openPanel = panel
	if panel then panel.Visible = true end
	player:SetAttribute("UiOpen", panel ~= nil)
end

local function panel(title: string, accent: Color3, height: number): (Frame, Frame)
	local f = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(440, height),
		BackgroundColor3 = C.bg, Visible = false, ZIndex = 40 }, gui)
	corner(f, 12)
	make("UIStroke", { Color = accent, Thickness = 2 }, f)
	make("TextLabel", { Size = UDim2.new(1, -60, 0, 44), Position = UDim2.fromOffset(20, 8), Text = title, TextSize = 24, Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = accent, ZIndex = 41 }, f)
	local close = make("TextButton", { Size = UDim2.fromOffset(36, 36), Position = UDim2.new(1, -48, 0, 12), BackgroundColor3 = C.panel, Text = "✕", TextSize = 18,
		Modal = true, ZIndex = 41 }, f)   -- Modal : libère le curseur en vue à la première personne
	corner(close, 8)
	close.MouseButton1Click:Connect(function() setOpen(nil) end)
	local body = make("Frame", { Size = UDim2.new(1, -40, 1, -70), Position = UDim2.fromOffset(20, 60), BackgroundTransparency = 1, ZIndex = 41 }, f)
	return f, body
end

local function button(parent: Instance, text: string, color: Color3, pos: UDim2, size: UDim2): TextButton
	local b = make("TextButton", { Position = pos, Size = size, BackgroundColor3 = color, Text = text, TextSize = 16, Font = Enum.Font.GothamBlack, ZIndex = 42 }, parent)
	corner(b, 8)
	return b
end

-- ---------- Codes promo ----------
local redeem = ReplicatedStorage:WaitForChild("RedeemCode") :: RemoteFunction
local codesPanel, codesBody = panel("🎟️ CODES", C.purple, 250)
make("TextLabel", { Size = UDim2.new(1, 0, 0, 36), Text = "Les codes sont annoncés sur le Discord, sur YouTube et dans la description du jeu.",
	TextSize = 13, TextColor3 = C.dim, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 42 }, codesBody)
local codeBox = make("TextBox", { Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, -130, 0, 44), BackgroundColor3 = C.panel, PlaceholderText = "Tape un code…",
	PlaceholderColor3 = C.dim, Text = "", TextSize = 18, ClearTextOnFocus = false, ZIndex = 42 }, codesBody)
corner(codeBox, 8)
local codeBtn = button(codesBody, "VALIDER", C.purple, UDim2.new(1, -120, 0, 44), UDim2.fromOffset(120, 44))
local codeResult = make("TextLabel", { Position = UDim2.fromOffset(0, 98), Size = UDim2.new(1, 0, 0, 70), Text = "", TextSize = 15, TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 42 }, codesBody)
local function submitCode()
	local text = codeBox.Text
	if #text == 0 then return end
	codeBtn.Text = "…"
	local res = redeem:InvokeServer(text)
	codeBtn.Text = "VALIDER"
	if res and res.ok then
		codeResult.TextColor3 = C.green
		codeResult.Text = "✅ " .. res.msg .. "\n" .. table.concat(res.lines or {}, "   ")
		codeBox.Text = ""
	else
		codeResult.TextColor3 = C.red
		codeResult.Text = "❌ " .. (res and res.msg or "Erreur")
	end
end
codeBtn.MouseButton1Click:Connect(submitCode)
codeBox.FocusLost:Connect(function(enter: boolean) if enter then submitCode() end end)

-- ---------- Groupe Roblox ----------
local groupStatus = ReplicatedStorage:WaitForChild("GetGroupStatus") :: RemoteFunction
local claimGroup = ReplicatedStorage:WaitForChild("ClaimGroupReward") :: RemoteFunction
local G = CommunityConfig.GROUP
local groupPanel, groupBody = panel("👥 GROUPE ROBLOX", C.robloxGreen, 300)
make("TextLabel", { Size = UDim2.new(1, 0, 0, 70), TextWrapped = true, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
	Text = "Rejoins le groupe du jeu et reçois " .. (G.reward.coins or 0) .. " 🪙 + l'effet d'élimination « Esprit du groupe », qu'on ne trouve nulle part ailleurs.",
	ZIndex = 42 }, groupBody)
local joinBtn = button(groupBody, "REJOINDRE LE GROUPE", C.robloxGreen, UDim2.fromOffset(0, 80), UDim2.new(1, 0, 0, 44))
local claimBtn = button(groupBody, "RÉCUPÉRER MA RÉCOMPENSE", C.gold, UDim2.fromOffset(0, 132), UDim2.new(1, 0, 0, 44))
local groupResult = make("TextLabel", { Position = UDim2.fromOffset(0, 184), Size = UDim2.new(1, 0, 0, 40), Text = "", TextSize = 14, TextWrapped = true, ZIndex = 42 }, groupBody)
local function refreshGroup()
	local st = groupStatus:InvokeServer()
	if not st then return end
	if st.groupId <= 0 then
		joinBtn.Text = "GROUPE BIENTÔT DISPONIBLE"; joinBtn.BackgroundColor3 = C.panel
		claimBtn.Visible = false
	elseif st.claimed then
		claimBtn.Text = "✅ RÉCOMPENSE RÉCUPÉRÉE"; claimBtn.BackgroundColor3 = C.panel
	end
end
joinBtn.MouseButton1Click:Connect(function()
	if G.id <= 0 then return end
	pcall(function() (GroupService :: any):PromptJoinAsync(G.id) end)   -- fenêtre officielle Roblox « Rejoindre le groupe »
end)
claimBtn.MouseButton1Click:Connect(function()
	local res = claimGroup:InvokeServer()
	if res and res.ok then
		groupResult.TextColor3 = C.green; groupResult.Text = "✅ " .. res.msg .. "  " .. table.concat(res.lines or {}, "   ")
	else
		groupResult.TextColor3 = C.red; groupResult.Text = "❌ " .. (res and res.msg or "Erreur")
	end
	refreshGroup()
end)

-- bornes du lobby (ProximityPrompt) : le serveur demande d'ouvrir un panneau
local panels = { codes = codesPanel, group = groupPanel }
;(ReplicatedStorage:WaitForChild("OpenPanel") :: RemoteEvent).OnClientEvent:Connect(function(id: string)
	local f = panels[id]
	if not f then return end
	if id == "group" then task.spawn(refreshGroup) end
	setOpen(if openPanel == f then nil else f)
end)

-- ==========================================================================================
-- Boutons à gauche : Jouer / Lobby / Codes / Groupe (clic avec M pour libérer la souris)
-- ==========================================================================================
local joinMatch = ReplicatedStorage:WaitForChild("JoinMatch", 10) :: RemoteFunction?
local leaveMatch = ReplicatedStorage:WaitForChild("LeaveMatch", 10) :: RemoteFunction?
local side = make("Frame", { Position = UDim2.new(0, 16, 0.5, -90), Size = UDim2.fromOffset(150, 200), BackgroundTransparency = 1 }, gui)
make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, side)
local function sideButton(text: string, color: Color3, order: number, cb: () -> ()): TextButton
	local b = make("TextButton", { Size = UDim2.fromOffset(150, 40), BackgroundColor3 = color, Text = text, TextSize = 15, Font = Enum.Font.GothamBlack, LayoutOrder = order }, side)
	corner(b, 8)
	b.MouseButton1Click:Connect(cb)
	return b
end
local playBtn = sideButton("🎮 JOUER", C.red, 1, function()
	if joinMatch then joinMatch:InvokeServer() end
end)
local lobbyBtn = sideButton("🏠 LOBBY", C.panel, 2, function()
	if leaveMatch then leaveMatch:InvokeServer() end
end)
sideButton("🎟️ CODES", C.purple, 3, function() setOpen(if openPanel == codesPanel then nil else codesPanel) end)
sideButton("👥 GROUPE", C.robloxGreen, 4, function()
	task.spawn(refreshGroup)
	setOpen(if openPanel == groupPanel then nil else groupPanel)
end)

local queueLabel = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -170), Size = UDim2.fromOffset(500, 28),
	TextSize = 18, TextColor3 = C.gold, Text = "", TextStrokeTransparency = 0.5 }, gui)

local function refreshZone()
	local zone = player:GetAttribute("Zone")
	local hasLobby = joinMatch ~= nil
	playBtn.Visible = hasLobby and zone == "lobby"
	lobbyBtn.Visible = hasLobby and zone == "tdm"
	side.Visible = zone ~= "duel"
	local q = player:GetAttribute("DuelQueued")
	queueLabel.Text = if zone == "lobby" and q then "⏳ En attente d'adversaires… reste sur la plateforme" else ""
end
player:GetAttributeChangedSignal("Zone"):Connect(refreshZone)
player:GetAttributeChangedSignal("DuelQueued"):Connect(refreshZone)
refreshZone()

-- ==========================================================================================
-- Lobby : messages, chrono du parcours, défi du stand de tir
-- ==========================================================================================
local lobbyToast = ReplicatedStorage:WaitForChild("LobbyToast", 10) :: RemoteEvent?
if lobbyToast then lobbyToast.OnClientEvent:Connect(function(text: string, color: Color3?) showToast(text, color, 5) end) end

local timerLabel = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 96), Size = UDim2.fromOffset(360, 44),
	BackgroundColor3 = C.bg, BackgroundTransparency = 0.25, TextSize = 26, Font = Enum.Font.GothamBlack, Text = "", Visible = false }, gui)
corner(timerLabel, 10)
local timer: any = nil
local lobbyTimer = ReplicatedStorage:WaitForChild("LobbyTimer", 10) :: RemoteEvent?
if lobbyTimer then
	lobbyTimer.OnClientEvent:Connect(function(t: any)
		if t.kind == "stop" then timer = nil; timerLabel.Visible = false; return end
		timer = t
		timerLabel.Visible = true
	end)
end
RunService.Heartbeat:Connect(function()
	if not timer then return end
	local now = workspace:GetServerTimeNow()
	if timer.kind == "parkour" then
		timerLabel.TextColor3 = C.green
		timerLabel.Text = string.format("🏃 %.2f s", now - timer.start)
	elseif timer.kind == "range" then
		local left = math.max(0, timer.endsAt - now)
		timerLabel.TextColor3 = if (timer.score or 0) >= timer.goal then C.green else C.gold
		timerLabel.Text = string.format("🎯 %d / %d   ·   %.1f s", timer.score or 0, timer.goal, left)
	end
end)

-- ==========================================================================================
-- Duels
-- ==========================================================================================
local duelTop = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(460, 70),
	BackgroundColor3 = C.bg, BackgroundTransparency = 0.2, Visible = false }, gui)
corner(duelTop, 12)
local duelMode = make("TextLabel", { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 4), TextSize = 12, TextColor3 = C.dim, Text = "" }, duelTop)
local duelMe = make("TextLabel", { Size = UDim2.new(0.42, 0, 0, 44), Position = UDim2.fromScale(0, 0.3), TextSize = 16, TextColor3 = C.blue, Text = "",
	TextXAlignment = Enum.TextXAlignment.Right }, duelTop)
local duelScore = make("TextLabel", { Size = UDim2.new(0.16, 0, 0, 44), Position = UDim2.fromScale(0.42, 0.3), TextSize = 28, Font = Enum.Font.GothamBlack, Text = "0 - 0" }, duelTop)
local duelThem = make("TextLabel", { Size = UDim2.new(0.42, 0, 0, 44), Position = UDim2.fromScale(0.58, 0.3), TextSize = 16, TextColor3 = C.red, Text = "",
	TextXAlignment = Enum.TextXAlignment.Left }, duelTop)
local bigText = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.38), Size = UDim2.fromOffset(700, 90),
	TextSize = 64, Font = Enum.Font.GothamBlack, Text = "", TextStrokeTransparency = 0.4 }, gui)
local function flashBig(text: string, color: Color3, seconds: number)
	bigText.Text = text; bigText.TextColor3 = color; bigText.TextTransparency = 0
	local my = text
	task.delay(seconds, function() if bigText.Text == my then tween(bigText, 0.3, { TextTransparency = 1 }) end end)
end

local duelState = ReplicatedStorage:WaitForChild("DuelState", 10) :: RemoteEvent?
if duelState then
	duelState.OnClientEvent:Connect(function(s: any)
		if s.phase == "feed" then showToast(s.feed, C.text, 2.5); return end
		duelTop.Visible = true
		duelMode.Text = string.upper(s.mode or "Duel") .. "  ·  premier à " .. s.toWin .. (if (s.pot or 0) > 0 then "  ·  pot " .. s.pot .. " 🪙" else "")
		duelScore.Text = s.me .. " - " .. s.them
		if s.myTeam then duelMe.Text = s.myTeam .. "  " end
		if s.theirTeam then duelThem.Text = "  " .. s.theirTeam end
		if s.phase == "countdown" then
			flashBig(if s.count == 3 then "MANCHE " .. s.round else tostring(s.count), C.gold, 0.9)
		elseif s.phase == "live" then
			flashBig("GO !", C.green, 0.8)
		elseif s.phase == "round" then
			if s.result == "win" then flashBig("MANCHE GAGNÉE", C.green, 2)
			elseif s.result == "loss" then flashBig("MANCHE PERDUE", C.red, 2)
			else flashBig("ÉGALITÉ", C.dim, 2) end
		end
	end)
end

local duelEnd = ReplicatedStorage:WaitForChild("DuelEnd", 10) :: RemoteEvent?
if duelEnd then
	duelEnd.OnClientEvent:Connect(function(r: any)
		duelTop.Visible = false
		local title = if r.draw then "ÉGALITÉ" elseif r.won then "VICTOIRE !" else "DÉFAITE"
		flashBig(title, if r.won then C.gold elseif r.draw then C.dim else C.red, 3.5)
		local elo = (if r.eloDelta >= 0 then "+" else "") .. r.eloDelta .. " Elo · " .. r.rank .. " (" .. r.elo .. ")"
		local coins = if r.coins > 0 then "  ·  +" .. r.coins .. " 🪙" elseif r.stake > 0 and not r.won then "  ·  -" .. r.stake .. " 🪙" else ""
		showToast(r.me .. " - " .. r.them .. "  ·  " .. elo .. coins, if r.won then C.gold else C.text, 6)
	end)
end
player:GetAttributeChangedSignal("Zone"):Connect(function()
	if player:GetAttribute("Zone") ~= "duel" then duelTop.Visible = false end
end)

-- ==========================================================================================
-- Rappel du « J'aime » (une fois par session, sans récompense)
-- ==========================================================================================
task.delay(G.likeReminderAfter, function()
	showToast("Tu t'amuses ? Mets un 👍 et ajoute Strike Arena à tes favoris, ça nous aide énormément !", C.gold, 8)
end)
