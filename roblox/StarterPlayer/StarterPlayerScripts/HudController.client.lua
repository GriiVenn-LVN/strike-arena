--!strict
-- StarterPlayerScripts/HudController (LocalScript)
-- HUD du match à mort par équipe : score et temps, vie + bouclier, munitions et armes, marqueur de touche,
-- chiffres de dégâts, indicateur de direction des dégâts, fil des éliminations, bannière d'élimination et séries,
-- écran de mort, tableau des scores (touche Tab) et écran de fin avec les récompenses.
-- Fait pour le mode « tdm » (ModeConfig.MODE) : les événements TDMState, KillFeed… sont créés par TDMService.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local ModeConfig = require(ReplicatedStorage.Shared.ModeConfig)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local hitRemote = ReplicatedStorage:WaitForChild("HitFeedback") :: RemoteEvent
local damagedRemote = ReplicatedStorage:WaitForChild("Damaged") :: RemoteEvent
local stateRemote = ReplicatedStorage:WaitForChild("TDMState") :: RemoteEvent
local feedRemote = ReplicatedStorage:WaitForChild("KillFeed") :: RemoteEvent
local bannerRemote = ReplicatedStorage:WaitForChild("KillBanner") :: RemoteEvent
local deathRemote = ReplicatedStorage:WaitForChild("DeathInfo") :: RemoteEvent
local endRemote = ReplicatedStorage:WaitForChild("MatchEnd") :: RemoteEvent

-- le tableau Tab remplace la liste des joueurs de Roblox
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end)
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)

-- ---------- palette ----------
local C = {
	bg = Color3.fromRGB(12, 16, 24), panel = Color3.fromRGB(20, 26, 38), text = Color3.fromRGB(240, 244, 250), dim = Color3.fromRGB(150, 160, 178),
	gold = Color3.fromRGB(255, 205, 80), red = Color3.fromRGB(255, 70, 85), green = Color3.fromRGB(110, 240, 140), blue = Color3.fromRGB(80, 170, 255),
	Attaquants = Color3.fromRGB(255, 140, 60), ["Défenseurs"] = Color3.fromRGB(80, 160, 255),
}
local function teamColor(t: string?): Color3 return (t and (C :: any)[t]) or C.text end

-- ---------- petits outils ----------
local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local o = Instance.new(class)
	for k, v in pairs(props) do (o :: any)[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function corner(o: Instance, r: number?) make("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o) end
local function stroke(o: Instance, color: Color3?, th: number?, tr: number?)
	make("UIStroke", { Color = color or Color3.new(0, 0, 0), Thickness = th or 1.5, Transparency = tr or 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local function label(parent: Instance, props: { [string]: any }): TextLabel
	local base = { BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextColor3 = C.text, TextSize = 16, Text = "" }
	for k, v in pairs(props) do (base :: any)[k] = v end
	return make("TextLabel", base, parent)
end
local function tween(o: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function playSound(def: any)
	if not def or not def.id or def.id == "" then return end
	local s = make("Sound", { SoundId = def.id, Volume = def.volume or 0.6, PlaybackSpeed = def.pitch or 1 }, SoundService)
	s:Play(); Debris:AddItem(s, 3)
end
local function fmtTime(s: number): string return string.format("%d:%02d", s // 60, s % 60) end

local gui = make("ScreenGui", { Name = "MatchHud", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 10, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))

-- ==========================================================================================
-- Haut : score des deux équipes + temps
-- ==========================================================================================
local top = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(420, 64), BackgroundTransparency = 1 }, gui)
local function teamBox(x: number, align: Enum.TextXAlignment): (TextLabel, Frame, TextLabel)
	local box = make("Frame", { Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(150, 64), BackgroundColor3 = C.bg, BackgroundTransparency = 0.25 }, top)
	corner(box, 10)
	local score = label(box, { Size = UDim2.new(1, -16, 0, 40), Position = UDim2.fromOffset(8, 2), TextSize = 34, TextXAlignment = align, Text = "0" })
	local name = label(box, { Size = UDim2.new(1, -16, 0, 14), Position = UDim2.fromOffset(8, 40), TextSize = 11, TextXAlignment = align, TextColor3 = C.dim })
	local barBg = make("Frame", { Position = UDim2.new(0, 8, 1, -8), Size = UDim2.new(1, -16, 0, 4), BackgroundColor3 = Color3.fromRGB(50, 56, 70), BorderSizePixel = 0 }, box)
	corner(barBg, 2)
	local bar = make("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, AnchorPoint = Vector2.new(if align == Enum.TextXAlignment.Right then 1 else 0, 0),
		Position = UDim2.fromScale(if align == Enum.TextXAlignment.Right then 1 else 0, 0) }, barBg)
	corner(bar, 2)
	return score, bar, name
end
local scoreA, barA, nameA = teamBox(0, Enum.TextXAlignment.Left)
local scoreB, barB, nameB = teamBox(270, Enum.TextXAlignment.Right)
local timerBox = make("Frame", { Position = UDim2.fromOffset(160, 6), Size = UDim2.fromOffset(100, 52), BackgroundColor3 = C.bg, BackgroundTransparency = 0.15 }, top)
corner(timerBox, 10)
local timerLabel = label(timerBox, { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 4), TextSize = 24, Text = "0:00" })
local goalLabel = label(timerBox, { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 32), TextSize = 10, TextColor3 = C.dim, Text = "" })
-- rappel des touches, visible seulement quand le mode menu (M) est ouvert
local menuHint = label(gui, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -130), Size = UDim2.fromOffset(500, 20), TextSize = 14, TextColor3 = C.dim,
	Text = "Souris libre · M pour revenir au jeu", Visible = false })
player:GetAttributeChangedSignal("MenuOpen"):Connect(function() menuHint.Visible = player:GetAttribute("MenuOpen") == true end)
local centerMsg = label(gui, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 86), Size = UDim2.fromOffset(500, 24), TextSize = 16, TextColor3 = C.gold, Text = "" })
make("UIStroke", { Thickness = 1.5, Transparency = 0.4 }, centerMsg)

-- ==========================================================================================
-- Bas gauche : vie + bouclier
-- ==========================================================================================
local vitals = make("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 22, 1, -22), Size = UDim2.fromOffset(300, 64), BackgroundColor3 = C.bg, BackgroundTransparency = 0.3 }, gui)
corner(vitals, 10)
local hpText = label(vitals, { Position = UDim2.fromOffset(14, 6), Size = UDim2.fromOffset(80, 34), TextSize = 30, TextXAlignment = Enum.TextXAlignment.Left, Text = "100" })
label(vitals, { Position = UDim2.fromOffset(74, 14), Size = UDim2.fromOffset(40, 20), TextSize = 11, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, Text = "VIE" })
local shieldText = label(vitals, { Position = UDim2.new(1, -94, 0, 10), Size = UDim2.fromOffset(80, 24), TextSize = 16, TextColor3 = C.blue, TextXAlignment = Enum.TextXAlignment.Right, Text = "" })
local hpBg = make("Frame", { Position = UDim2.new(0, 14, 1, -18), Size = UDim2.new(1, -28, 0, 8), BackgroundColor3 = Color3.fromRGB(45, 50, 62), BorderSizePixel = 0 }, vitals)
corner(hpBg, 4)
local hpLag = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0 }, hpBg); corner(hpLag, 4)
local hpBar = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.green, BorderSizePixel = 0 }, hpBg); corner(hpBar, 4)
local shieldBar = make("Frame", { Position = UDim2.new(0, 14, 1, -24), Size = UDim2.new(0, 0, 0, 4), BackgroundColor3 = C.blue, BorderSizePixel = 0 }, vitals); corner(shieldBar, 2)
local protectLabel = label(gui, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 24, 1, -92), Size = UDim2.fromOffset(200, 18), TextSize = 13,
	TextColor3 = Color3.fromRGB(150, 220, 255), TextXAlignment = Enum.TextXAlignment.Left, Text = "", })

-- ==========================================================================================
-- Bas droite : munitions + armes
-- ==========================================================================================
local ammoBox = make("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -22, 1, -22), Size = UDim2.fromOffset(260, 96), BackgroundColor3 = C.bg, BackgroundTransparency = 0.3 }, gui)
corner(ammoBox, 10)
local magText = label(ammoBox, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -78, 0, 4), Size = UDim2.fromOffset(110, 46), TextSize = 42, TextXAlignment = Enum.TextXAlignment.Right, Text = "" })
local reserveText = label(ammoBox, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 20), Size = UDim2.fromOffset(60, 26), TextSize = 18, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, Text = "" })
local weaponText = label(ammoBox, { Position = UDim2.fromOffset(14, 8), Size = UDim2.fromOffset(120, 18), TextSize = 13, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, Text = "" })
local reloadBg = make("Frame", { Position = UDim2.new(0, 14, 0, 54), Size = UDim2.new(1, -28, 0, 4), BackgroundColor3 = Color3.fromRGB(45, 50, 62), BorderSizePixel = 0, Visible = false }, ammoBox)
corner(reloadBg, 2)
local reloadBar = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.gold, BorderSizePixel = 0 }, reloadBg); corner(reloadBar, 2)
local slotRow = make("Frame", { Position = UDim2.new(0, 14, 1, -32), Size = UDim2.new(1, -28, 0, 24), BackgroundTransparency = 1 }, ammoBox)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }, slotRow)
local slotLabels: { TextLabel } = {}
for i = 1, 3 do
	local s = label(slotRow, { Size = UDim2.fromOffset(72, 24), TextSize = 11, BackgroundColor3 = C.panel, BackgroundTransparency = 0.2, Text = "" })
	corner(s, 6)
	slotLabels[i] = s
end

-- ==========================================================================================
-- Centre : point de visée, marqueur de touche, indicateurs de dégâts, vignette
-- ==========================================================================================
local center = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1 }, gui)
local dot = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(4, 4), BackgroundColor3 = C.text, BorderSizePixel = 0, Visible = ModeConfig.CENTER_DOT }, center)
corner(dot, 2); stroke(dot, Color3.new(0, 0, 0), 1, 0.4)

local hitmarker = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 1, Visible = false }, center)
local hmScale = make("UIScale", { Scale = 1 }, hitmarker)
local hmLines: { Frame } = {}
for i, rot in ipairs({ 45, 135, 225, 315 }) do
	local holder = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 0), Rotation = rot, BackgroundTransparency = 1 }, hitmarker)
	hmLines[i] = make("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(0, -5), Size = UDim2.fromOffset(2.5, 8), BackgroundColor3 = C.text, BorderSizePixel = 0 }, holder)
	stroke(hmLines[i], Color3.new(0, 0, 0), 1, 0.5)
end
local hmToken = 0
local function showHitmarker(head: boolean, kill: boolean)
	hmToken += 1
	local my = hmToken
	local col = if kill then C.red elseif head then C.gold else C.text
	for _, l in ipairs(hmLines) do l.BackgroundColor3 = col; l.BackgroundTransparency = 0; l.Size = UDim2.fromOffset(if kill then 3.5 else 2.5, if kill then 11 else 8) end
	hitmarker.Visible = true; hitmarker.Rotation = if kill then 0 else math.random(-6, 6)
	hmScale.Scale = if kill then 1.8 else 1.35
	tween(hmScale, 0.12, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(if kill then 0.35 else 0.18, function()
		if my ~= hmToken then return end
		for _, l in ipairs(hmLines) do tween(l, 0.15, { BackgroundTransparency = 1 }) end
		task.delay(0.16, function() if my == hmToken then hitmarker.Visible = false end end)
	end)
end

-- voile rouge qui pulse quand la vie est basse (remplaçable par une image de vignette importée)
local vignette = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.red, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 0 }, gui)
local flash = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.red, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 0 }, gui)

local function damageIndicator(fromPos: Vector3)
	local cf = camera.CFrame
	local rel = cf:VectorToObjectSpace(fromPos - cf.Position)
	local angle = math.deg(math.atan2(rel.X, -rel.Z))
	local holder = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(0, 0), Rotation = angle, BackgroundTransparency = 1 }, center)
	local arc = make("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(0, -110), Size = UDim2.fromOffset(90, 10), BackgroundColor3 = C.red, BackgroundTransparency = 0.05, BorderSizePixel = 0 }, holder)
	corner(arc, 5)
	make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }, arc)
	tween(arc, 0.12, { Position = UDim2.fromOffset(0, -120) }, Enum.EasingStyle.Back)
	task.delay(0.6, function() tween(arc, 0.5, { BackgroundTransparency = 1 }) end)
	Debris:AddItem(holder, 1.2)
end

-- chiffres de dégâts au-dessus de la cible (doré = tête, rouge = élimination), qui se cumulent sur une même cible
local lastNumber: { at: number, pos: Vector3, total: number, gui: BillboardGui? } = { at = 0, pos = Vector3.zero, total = 0, gui = nil }
local function damageNumber(pos: Vector3, dmg: number, head: boolean, kill: boolean)
	local t = os.clock()
	local stack = lastNumber.gui ~= nil and t - lastNumber.at < 0.6 and (lastNumber.pos - pos).Magnitude < 8
	lastNumber.total = if stack then lastNumber.total + dmg else dmg
	lastNumber.at = t; lastNumber.pos = pos
	if stack and lastNumber.gui then lastNumber.gui:Destroy() end
	local anchor = make("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2),
		Position = pos + Vector3.new((math.random() - 0.5) * 1.5, 3.2, 0) }, workspace)
	local bb = make("BillboardGui", { Adornee = anchor, Size = UDim2.fromOffset(120, 50), AlwaysOnTop = true, LightInfluence = 0 }, anchor)
	local txt = label(bb, { Size = UDim2.fromScale(1, 1), TextSize = if kill then 30 elseif head then 26 else 22, Font = Enum.Font.GothamBlack,
		TextColor3 = if kill then C.red elseif head then C.gold else C.text, Text = tostring(lastNumber.total) .. (if head then " ◎" else "") })
	make("UIStroke", { Thickness = 2, Transparency = 0.2 }, txt)
	local sc = make("UIScale", { Scale = 1.6 }, txt)
	tween(sc, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(bb, 0.8, { StudsOffset = Vector3.new(0, 2.2, 0) })
	task.delay(0.45, function() tween(txt, 0.35, { TextTransparency = 1 }) end)
	lastNumber.gui = bb
	Debris:AddItem(anchor, 0.9)
end

hitRemote.OnClientEvent:Connect(function(head: boolean, kill: boolean, dmg: number?, pos: Vector3?)
	showHitmarker(head, kill)
	playSound(if kill then ModeConfig.SOUNDS.kill elseif head then ModeConfig.SOUNDS.hitHead else ModeConfig.SOUNDS.hitBody)
	if dmg and pos then damageNumber(pos, dmg, head, kill) end
end)

damagedRemote.OnClientEvent:Connect(function(fromPos: Vector3, dmg: number, _head: boolean)
	if fromPos.Magnitude > 0 then damageIndicator(fromPos) end
	playSound(ModeConfig.SOUNDS.hurt)
	flash.BackgroundTransparency = math.clamp(0.92 - dmg / 250, 0.6, 0.92)
	tween(flash, 0.35, { BackgroundTransparency = 1 })
end)

-- ==========================================================================================
-- Fil des éliminations (haut droite)
-- ==========================================================================================
local feed = make("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 72), Size = UDim2.fromOffset(380, 200), BackgroundTransparency = 1 }, gui)
make("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, feed)
local feedOrder = 0
feedRemote.OnClientEvent:Connect(function(k: any)
	if player:GetAttribute("Zone") == "lobby" or player:GetAttribute("Zone") == "duel" then return end   -- fil du match à mort : seulement pour ceux qui y jouent
	feedOrder += 1
	local me = player.DisplayName
	local involved = k.killer == me or k.victim == me
	local row = make("Frame", { Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = if involved then Color3.fromRGB(60, 50, 20) else C.bg,
		BackgroundTransparency = 0.25, LayoutOrder = feedOrder }, feed)
	corner(row, 6)
	if involved then stroke(row, C.gold, 1.2, 0.2) end
	make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, row)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8) }, row)
	local function part(text: string, color: Color3, size: number?, font: Enum.Font?)
		label(row, { Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, Text = text, TextColor3 = color, TextSize = size or 14, Font = font or Enum.Font.GothamBold })
	end
	part(k.killer, teamColor(k.killerTeam))
	part("[" .. k.weapon .. "]", C.dim, 12, Enum.Font.GothamMedium)
	if k.headshot then part("◎", C.gold, 14) end
	part(k.victim, teamColor(k.victimTeam))
	-- au plus 5 lignes, chaque ligne s'efface après 5 s
	local rows = {}
	for _, c in ipairs(feed:GetChildren()) do if c:IsA("Frame") then table.insert(rows, c) end end
	table.sort(rows, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	while #rows > 5 do (table.remove(rows, 1) :: Instance):Destroy() end
	task.delay(5, function()
		if not row.Parent then return end
		tween(row, 0.4, { BackgroundTransparency = 1 })
		for _, c in ipairs(row:GetChildren()) do if c:IsA("TextLabel") then tween(c, 0.4, { TextTransparency = 1 }) end end
		Debris:AddItem(row, 0.45)
	end)
end)

-- ==========================================================================================
-- Bannière d'élimination et séries (centre bas)
-- ==========================================================================================
local banner = make("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -170), Size = UDim2.fromOffset(420, 80), BackgroundTransparency = 1 }, gui)
local bannerScale = make("UIScale", { Scale = 1 }, banner)
local bannerTitle = label(banner, { Size = UDim2.new(1, 0, 0, 34), TextSize = 28, Font = Enum.Font.GothamBlack, TextTransparency = 1, Text = "" })
make("UIStroke", { Thickness = 2, Transparency = 0.25 }, bannerTitle)
local bannerSub = label(banner, { Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 0, 20), TextSize = 15, TextColor3 = C.dim, TextTransparency = 1, Text = "" })
local streakLabel = label(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.32), Size = UDim2.fromOffset(600, 60), TextSize = 46, Font = Enum.Font.GothamBlack,
	TextColor3 = C.gold, TextTransparency = 1, Text = "" })
make("UIStroke", { Thickness = 3, Transparency = 0.2, Color = Color3.fromRGB(80, 40, 0) }, streakLabel)
local streakScale = make("UIScale", { Scale = 1 }, streakLabel)
local bannerToken = 0
bannerRemote.OnClientEvent:Connect(function(b: any)
	bannerToken += 1
	local my = bannerToken
	bannerTitle.Text = (if b.headshot then "TIR À LA TÊTE" else "ÉLIMINATION") .. "  +" .. b.points
	bannerTitle.TextColor3 = if b.headshot then C.gold else C.text
	bannerSub.Text = b.victim .. (if b.streak >= 2 then "   ·   " .. b.streak .. " d'affilée" else "")
	bannerTitle.TextTransparency = 0; bannerSub.TextTransparency = 0
	bannerScale.Scale = 1.5
	tween(bannerScale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(1.6, function()
		if my ~= bannerToken then return end
		tween(bannerTitle, 0.4, { TextTransparency = 1 }); tween(bannerSub, 0.4, { TextTransparency = 1 })
	end)
	if b.streakName then
		streakLabel.Text = string.upper(b.streakName)
		streakLabel.TextTransparency = 0; streakScale.Scale = 0.3
		tween(streakScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		playSound(ModeConfig.SOUNDS.streak)
		task.delay(2, function() tween(streakLabel, 0.5, { TextTransparency = 1 }) end)
	end
end)

-- ==========================================================================================
-- Écran de mort
-- ==========================================================================================
local deathFrame = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(30, 0, 5), BackgroundTransparency = 1, Visible = false, ZIndex = 5 }, gui)
local deathTitle = label(deathFrame, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(600, 40), TextSize = 30, Font = Enum.Font.GothamBlack, ZIndex = 6, Text = "" })
local deathSub = label(deathFrame, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromOffset(600, 24), TextSize = 16, TextColor3 = C.dim, ZIndex = 6, Text = "" })
deathRemote.OnClientEvent:Connect(function(d: any)
	deathFrame.Visible = true; deathFrame.BackgroundTransparency = 1
	tween(deathFrame, 0.4, { BackgroundTransparency = 0.55 })
	deathTitle.Text = "Éliminé par " .. d.killer
	local left = d.respawn
	task.spawn(function()
		while left > 0 and deathFrame.Visible do
			deathSub.Text = d.weapon .. (if d.headshot then " · tir à la tête" else "") .. "   —   réapparition dans " .. left
			task.wait(1); left -= 1
		end
	end)
end)

-- ==========================================================================================
-- Tableau des scores (Tab)
-- ==========================================================================================
local board = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(820, 460), BackgroundColor3 = C.bg,
	BackgroundTransparency = 0.08, Visible = false, ZIndex = 20 }, gui)
corner(board, 14); stroke(board, Color3.fromRGB(70, 80, 100), 1.5, 0.3)
local boardScale = make("UIScale", { Scale = 1 }, board)
label(board, { Position = UDim2.fromOffset(20, 12), Size = UDim2.new(1, -40, 0, 26), TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21, Text = "Match à mort par équipe" })
local boardInfo = label(board, { Position = UDim2.fromOffset(20, 12), Size = UDim2.new(1, -40, 0, 26), TextSize = 14, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 21 })
local columns: { Frame } = {}
for i = 1, 2 do
	local col = make("Frame", { Position = UDim2.new((i - 1) * 0.5, if i == 1 then 16 else 8, 0, 50), Size = UDim2.new(0.5, -24, 1, -66), BackgroundTransparency = 1, ZIndex = 21 }, board)
	make("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, col)
	columns[i] = col
end
local function boardRow(parent: Instance, order: number, cells: { string }, color: Color3, bg: Color3?, bold: boolean?)
	local row = make("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = bg or C.panel, BackgroundTransparency = if bg then 0.1 else 0.35, LayoutOrder = order, ZIndex = 21 }, parent)
	corner(row, 6)
	local widths = { 0.46, 0.12, 0.12, 0.12, 0.18 }
	local x = 0
	for i, text in ipairs(cells) do
		label(row, { Position = UDim2.new(x, if i == 1 then 10 else 0, 0, 0), Size = UDim2.new(widths[i], if i == 1 then -10 else 0, 1, 0), Text = text, ZIndex = 22,
			TextSize = if i == 1 then 14 else 13, TextColor3 = if i == 1 then color else C.text, Font = if bold then Enum.Font.GothamBlack else Enum.Font.GothamBold,
			TextXAlignment = if i == 1 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd })
		x += widths[i]
	end
end
local lastState: any = nil
local function renderBoard()
	local st = lastState
	if not st then return end
	for _, col in ipairs(columns) do for _, c in ipairs(col:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end end
	boardInfo.Text = st.mapName .. "   ·   " .. fmtTime(st.timeLeft) .. "   ·   premier à " .. st.killsToWin
	for i, team in ipairs(st.teams) do
		local col = columns[i]
		boardRow(col, 0, { string.upper(team) .. "   " .. (st.score[team] or 0), "É", "M", "A", "SCORE" }, teamColor(team), Color3.fromRGB(30, 36, 52), true)
		local n = 0
		for _, e in ipairs(st.board) do
			if e.team == team then
				n += 1
				local mine = e.userId == player.UserId
				boardRow(col, n, { (if e.bot then "[BOT] " else "") .. e.name .. (if e.bot then "" else "  · " .. e.ping .. " ms"), tostring(e.k), tostring(e.d), tostring(e.a), tostring(e.score) },
					if mine then C.gold else C.text, if mine then Color3.fromRGB(60, 52, 24) else nil)
			end
		end
	end
end
local function showBoard(on: boolean)
	if on == board.Visible then return end
	if on then
		renderBoard(); board.Visible = true; boardScale.Scale = 0.94
		tween(boardScale, 0.14, { Scale = 1 }, Enum.EasingStyle.Back)
	else
		board.Visible = false
	end
end
UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.Tab or input.KeyCode == Enum.KeyCode.ButtonSelect then showBoard(true) end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Tab or input.KeyCode == Enum.KeyCode.ButtonSelect then showBoard(false) end
end)
-- bouton tactile pour les téléphones
if UserInputService.TouchEnabled then
	local btn = make("TextButton", { AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(90, 34), BackgroundColor3 = C.bg,
		BackgroundTransparency = 0.25, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = C.text, Text = "Scores" }, gui)
	corner(btn, 8)
	btn.Activated:Connect(function() showBoard(not board.Visible) end)
end

-- ==========================================================================================
-- Écran de fin de partie
-- ==========================================================================================
local endFrame = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(5, 8, 14), BackgroundTransparency = 1, Visible = false, ZIndex = 30 }, gui)
local endTitle = label(endFrame, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.24), Size = UDim2.fromOffset(800, 90), TextSize = 84, Font = Enum.Font.GothamBlack, ZIndex = 31 })
make("UIStroke", { Thickness = 3, Transparency = 0.3 }, endTitle)
local endTitleScale = make("UIScale", { Scale = 1 }, endTitle)
local endScore = label(endFrame, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.34), Size = UDim2.fromOffset(600, 40), TextSize = 30, ZIndex = 31 })
local endCards = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(760, 150), BackgroundTransparency = 1, ZIndex = 31 }, endFrame)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 14) }, endCards)
local endNext = label(endFrame, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40), Size = UDim2.fromOffset(600, 24), TextSize = 16, TextColor3 = C.dim, ZIndex = 31 })

local function card(title: string, lines: { string }, accent: Color3, delay: number)
	local f = make("Frame", { Size = UDim2.fromOffset(240, 150), BackgroundColor3 = C.panel, BackgroundTransparency = 1, ZIndex = 31 }, endCards)
	corner(f, 12)
	local st = make("UIStroke", { Color = accent, Thickness = 1.5, Transparency = 1 }, f)
	local t = label(f, { Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 20), TextSize = 13, TextColor3 = accent, TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1, ZIndex = 32, Text = string.upper(title) })
	local items = {}
	for i, l in ipairs(lines) do
		table.insert(items, label(f, { Position = UDim2.fromOffset(16, 14 + i * 24), Size = UDim2.new(1, -32, 0, 22), TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1, ZIndex = 32, Text = l }))
	end
	task.delay(delay, function()
		tween(f, 0.3, { BackgroundTransparency = 0.1 }); tween(st, 0.3, { Transparency = 0.2 }); tween(t, 0.3, { TextTransparency = 0 })
		for i, it in ipairs(items) do task.delay(i * 0.08, function() tween(it, 0.25, { TextTransparency = 0 }) end) end
	end)
end

endRemote.OnClientEvent:Connect(function(r: any)
	showBoard(false)
	deathFrame.Visible = false
	for _, c in ipairs(endCards:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
	endFrame.Visible = true; endFrame.BackgroundTransparency = 1
	tween(endFrame, 0.5, { BackgroundTransparency = 0.25 })
	endTitle.Text = if r.draw then "ÉGALITÉ" elseif r.won then "VICTOIRE" else "DÉFAITE"
	endTitle.TextColor3 = if r.draw then C.text elseif r.won then C.gold else C.red
	endTitleScale.Scale = 2.2; endTitle.TextTransparency = 1
	tween(endTitleScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back); tween(endTitle, 0.3, { TextTransparency = 0 })
	local t1, t2 = lastState and lastState.teams[1] or "", lastState and lastState.teams[2] or ""
	endScore.Text = string.format("%s  %d  —  %d  %s", t1, r.score[t1] or 0, r.score[t2] or 0, t2)
	if r.me then
		card("Ta partie", { r.me.k .. " éliminations · " .. r.me.d .. " morts", r.me.a .. " assistances · " .. r.me.hs .. " à la tête", r.me.dmg .. " dégâts",
			"Meilleure série : " .. r.me.bestStreak }, C.blue, 0.5)
	end
	if r.mvp then
		card("Meilleur joueur", { (if r.mvp.bot then "[BOT] " else "") .. r.mvp.name, r.mvp.k .. " éliminations", r.mvp.score .. " points" }, C.gold, 0.7)
	end
	if r.rewards then
		local lines = { "+" .. r.rewards.xp .. " XP", "+" .. r.rewards.coins .. " pièces" }
		local ups = r.rewards.levelUps
		if typeof(ups) == "table" and #ups > 0 then table.insert(lines, "Niveau supérieur !") end
		if r.progress and (r.progress.tiersGained or 0) > 0 then table.insert(lines, "+" .. r.progress.tiersGained .. " palier(s) du passe") end
		card("Récompenses", lines, C.green, 0.9)
	end
	task.spawn(function()
		local left = r.next or 15
		while left > 0 and endFrame.Visible do
			endNext.Text = "Prochaine partie dans " .. left .. " s"
			task.wait(1); left -= 1
		end
	end)
end)

-- ==========================================================================================
-- Mise à jour continue
-- ==========================================================================================
stateRemote.OnClientEvent:Connect(function(st: any)
	-- avec le lobby, le score du match à mort ne s'affiche que pour ceux qui y jouent
	local inMatch = player:GetAttribute("Zone") == nil or player:GetAttribute("Zone") == "tdm"
	top.Visible = inMatch
	if not inMatch then centerMsg.Text = ""; return end
	lastState = st
	local a, b = st.teams[1], st.teams[2]
	scoreA.Text = tostring(st.score[a] or 0); scoreB.Text = tostring(st.score[b] or 0)
	scoreA.TextColor3 = teamColor(a); scoreB.TextColor3 = teamColor(b)
	nameA.Text = string.upper(a) .. (if player.Team and player.Team.Name == a then "  · TOI" else "")
	nameB.Text = (if player.Team and player.Team.Name == b then "TOI ·  " else "") .. string.upper(b)
	barA.BackgroundColor3 = teamColor(a); barB.BackgroundColor3 = teamColor(b)
	tween(barA, 0.3, { Size = UDim2.fromScale(math.clamp((st.score[a] or 0) / st.killsToWin, 0, 1), 1) })
	tween(barB, 0.3, { Size = UDim2.fromScale(math.clamp((st.score[b] or 0) / st.killsToWin, 0, 1), 1) })
	timerLabel.Text = fmtTime(st.timeLeft)
	timerLabel.TextColor3 = if st.state == "live" and st.timeLeft <= 30 then C.red else C.text
	goalLabel.Text = if st.state == "live" then "PREMIER À " .. st.killsToWin else (if st.state == "intermission" then "PAUSE" else "")
	centerMsg.Text = if st.state == "intermission" then "Nouvelle partie dans " .. st.timeLeft .. " s" else ""
	if st.state == "live" and endFrame.Visible then endFrame.Visible = false end
	if board.Visible then renderBoard() end
end)

local shownHp = 100
player.CharacterAdded:Connect(function(char)
	deathFrame.Visible = false
	shownHp = 100
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	hum.HealthChanged:Connect(function(hp)
		if hp < shownHp then
			hpLag.Size = UDim2.fromScale(shownHp / hum.MaxHealth, 1)
			task.delay(0.25, function() tween(hpLag, 0.4, { Size = UDim2.fromScale(math.max(0, hp) / hum.MaxHealth, 1) }) end)
		else
			hpLag.Size = UDim2.fromScale(math.max(0, hp) / hum.MaxHealth, 1)
		end
		shownHp = hp
	end)
end)

RunService.RenderStepped:Connect(function()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hp = if hum then math.max(0, hum.Health) else 0
	local maxHp = if hum then hum.MaxHealth else 100
	local frac = hp / maxHp
	hpText.Text = tostring(math.ceil(hp))
	hpBar.Size = UDim2.fromScale(frac, 1)
	hpBar.BackgroundColor3 = if frac > 0.5 then C.green elseif frac > 0.25 then C.gold else C.red
	vignette.BackgroundTransparency = if frac < 0.35 and hp > 0 then 0.88 + 0.05 * math.sin(os.clock() * 5) else 1
	local shield = char and char:GetAttribute("Shield")
	local sh = if typeof(shield) == "number" then shield else 0
	shieldText.Text = if sh > 0 then "◆ " .. sh else ""
	shieldBar.Size = UDim2.new((sh / Config.SHIELD_MAX) * 1, -28 * (sh / Config.SHIELD_MAX), 0, 4)
	local prot = char and char:GetAttribute("ProtectedUntil")
	protectLabel.Text = if typeof(prot) == "number" and prot > workspace:GetServerTimeNow() then "◇ Protection d'apparition" else ""

	local key = player:GetAttribute("Weapon")
	local w = typeof(key) == "string" and Config.WEAPONS[key] or nil
	if w then
		weaponText.Text = string.upper(w.name)
		if w.melee then magText.Text = "—"; reserveText.Text = ""
		else
			local mag = player:GetAttribute("Mag") :: number? or 0
			magText.Text = tostring(mag); reserveText.Text = "/ " .. tostring(player:GetAttribute("Reserve") or 0)
			magText.TextColor3 = if mag <= math.ceil(w.mag * 0.2) then C.red else C.text
		end
		local reloading = player:GetAttribute("Reloading") == true
		reloadBg.Visible = reloading
		if reloading then
			local started = player:GetAttribute("ReloadStart") :: number? or os.clock()
			reloadBar.Size = UDim2.fromScale(math.clamp((os.clock() - started) / math.max(w.reload, 0.1), 0, 1), 1)
		end
	end
	local loadout = string.split(tostring(player:GetAttribute("Loadout") or ""), ",")
	local slot = player:GetAttribute("Slot") :: number? or 1
	for i, l in ipairs(slotLabels) do
		local k = loadout[i]
		local wk = k and Config.WEAPONS[k]
		l.Visible = wk ~= nil
		if wk then
			l.Text = i .. "  " .. wk.name
			l.TextColor3 = if i == slot then C.bg else C.dim
			l.BackgroundColor3 = if i == slot then C.gold else C.panel
		end
	end
	dot.Visible = ModeConfig.CENTER_DOT and player:GetAttribute("Aiming") ~= true and hp > 0
end)
