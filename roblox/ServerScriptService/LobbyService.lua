--!strict
-- ServerScriptService/LobbyService (ModuleScript, requis par Main quand CommunityConfig.LOBBY_ENABLED = true)
-- Lobby jouable façon Rivals : on y arrive, on s'entraîne au stand de tir, on fait le parcours, on regarde le
-- classement géant, on monte sur une plateforme de duel ou on passe le portail pour rejoindre le match à mort.
-- Personne ne peut blesser personne dans le lobby (pas d'équipe = pas de dégâts, voir WeaponService.fire).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CommunityConfig = require(ReplicatedStorage.Shared.CommunityConfig)
local DataService = require(script.Parent.DataService)
local WeaponService = require(script.Parent.WeaponService)
local TDMService = require(script.Parent.TDMService)

local L = CommunityConfig.LOBBY
local O = L.origin

local LobbyService = {}
LobbyService.duelPads = {} :: { { part: BasePart, def: any, label: TextLabel } }
LobbyService.board = nil :: BasePart?

local function remoteEvent(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent"); r.Name = name; r.Parent = ReplicatedStorage; return r
end
local toastEvent = remoteEvent("LobbyToast")    -- serveur -> joueur : message court (record, récompense…)
local timerEvent = remoteEvent("LobbyTimer")    -- serveur -> joueur : chrono du parcours / du stand de tir
local panelEvent = remoteEvent("OpenPanel")     -- serveur -> joueur : ouvrir le panneau Codes ou Groupe (bornes du lobby)

function LobbyService.toast(p: Player, text: string, color: Color3?)
	toastEvent:FireClient(p, text, color)
end

-- ==========================================================================================
-- Construction
-- ==========================================================================================
local folder: Folder
local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Name = name; p.Anchored = true; p.Size = size; p.CFrame = cf; p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or folder
	return p
end
local function at(x: number, y: number, z: number): CFrame return CFrame.new(O + Vector3.new(x, y, z)) end

-- Panneau texte posé sur la face avant d'une pièce
local function sign(target: BasePart, text: string, color: Color3, face: Enum.NormalId?)
	local sg = Instance.new("SurfaceGui"); sg.Face = face or Enum.NormalId.Front; sg.PixelsPerStud = 20; sg.LightInfluence = 0
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.Parent = target
	local l = Instance.new("TextLabel"); l.Size = UDim2.fromScale(1, 1); l.BackgroundTransparency = 1; l.Text = text
	l.TextColor3 = color; l.Font = Enum.Font.GothamBlack; l.TextScaled = true; l.Parent = sg
	return l
end

local function billboard(target: BasePart, text: string, color: Color3, height: number): TextLabel
	local bb = Instance.new("BillboardGui"); bb.Size = UDim2.fromOffset(260, 60); bb.StudsOffset = Vector3.new(0, height, 0)
	bb.AlwaysOnTop = false; bb.MaxDistance = 140; bb.LightInfluence = 0; bb.Parent = target
	local l = Instance.new("TextLabel"); l.Size = UDim2.fromScale(1, 1); l.BackgroundTransparency = 1; l.Text = text
	l.TextColor3 = color; l.Font = Enum.Font.GothamBlack; l.TextScaled = true; l.TextStrokeTransparency = 0.4; l.Parent = bb
	return l
end

local DARK = Color3.fromRGB(28, 32, 44)
local FLOOR = Color3.fromRGB(46, 52, 68)
local RED = Color3.fromRGB(255, 70, 85)
local BLUE = Color3.fromRGB(74, 163, 255)
local GOLD = Color3.fromRGB(255, 200, 60)
local GREEN = Color3.fromRGB(80, 230, 140)

local rangeTargets: { BasePart } = {}
local rangeStart: BasePart
local parkourStart: BasePart
local parkourFinish: BasePart

local function build()
	local old = workspace:FindFirstChild("Lobby"); if old then old:Destroy() end
	folder = Instance.new("Folder"); folder.Name = "Lobby"; folder.Parent = workspace
	local S = L.size
	local half = S / 2

	-- sol, murs, bandes lumineuses
	part("Floor", Vector3.new(S, 2, S), at(0, -1, 0), FLOOR, Enum.Material.Concrete)
	for i, d in ipairs({ { 0, half }, { 0, -half }, { half, 0 }, { -half, 0 } }) do
		local alongX = i <= 2
		part("Wall", if alongX then Vector3.new(S, 34, 2) else Vector3.new(2, 34, S), at(d[1], 17, d[2]), DARK, Enum.Material.Metal)
		part("Strip", if alongX then Vector3.new(S, 0.6, 2.4) else Vector3.new(2.4, 0.6, S), at(d[1], 3, d[2]), if i % 2 == 0 then RED else BLUE, Enum.Material.Neon)
	end
	local spawnPad = part("SpawnPad", Vector3.new(26, 0.4, 26), at(0, 0.2, 0), Color3.fromRGB(60, 68, 90), Enum.Material.Metal)
	billboard(spawnPad, "STRIKE ARENA", Color3.new(1, 1, 1), 12)

	-- ---------- portail du match à mort (nord) ----------
	local portalFrame = part("PortalFrame", Vector3.new(30, 26, 3), at(0, 13, half - 14), DARK, Enum.Material.Metal)
	portalFrame.Transparency = 0
	local portal = part("Portal", Vector3.new(22, 20, 1), at(0, 10, half - 16), RED, Enum.Material.Neon)
	portal.Transparency = 0.35; portal.CanCollide = false
	billboard(portal, "⚔️ MATCH À MORT PAR ÉQUIPE", Color3.new(1, 1, 1), 14)
	local portalDebounce: { [Player]: boolean } = {}
	portal.Touched:Connect(function(hit)
		local p = Players:GetPlayerFromCharacter(hit.Parent)
		if not p or portalDebounce[p] or p:GetAttribute("Zone") ~= "lobby" or p:GetAttribute("DuelQueued") then return end
		portalDebounce[p] = true
		task.delay(2, function() portalDebounce[p] = nil end)
		LobbyService.joinMatch(p)
	end)

	-- ---------- plateformes de duel (ouest) ----------
	part("DuelSign", Vector3.new(50, 8, 1), at(-half + 2, 22, 0) * CFrame.Angles(0, math.rad(-90), 0), DARK)
	sign(folder:FindFirstChild("DuelSign") :: BasePart, "DUELS", GOLD)
	for i, def in ipairs(CommunityConfig.DUEL.pads) do
		local z = -54 + (i - 1) * 34
		local pad = part("DuelPad_" .. def.id, Vector3.new(1, 16, 16), at(-80, 0.3, z) * CFrame.Angles(0, 0, math.rad(90)),
			if def.stake > 0 then GOLD else BLUE, Enum.Material.Neon)
		pad.Shape = Enum.PartType.Cylinder; pad.Size = Vector3.new(0.6, 16, 16)
		local label = billboard(pad, def.name, Color3.new(1, 1, 1), 7)
		table.insert(LobbyService.duelPads, { part = pad, def = def, label = label })
	end

	-- ---------- stand de tir (est) ----------
	local rx = 85
	part("RangeBack", Vector3.new(70, 30, 2), at(rx, 15, -110), DARK, Enum.Material.Metal)
	part("RangeLine", Vector3.new(70, 0.3, 1), at(rx, 0.15, -24), GOLD, Enum.Material.Neon)
	part("RangeSign", Vector3.new(40, 6, 1), at(rx, 24, -108.5), DARK)
	sign(folder:FindFirstChild("RangeSign") :: BasePart, "STAND DE TIR", GOLD, Enum.NormalId.Back)
	for row = 0, 2 do
		for col = 0, 4 do
			local t = part("Target", Vector3.new(4, 4, 0.6), at(rx - 26 + col * 13, 5 + row * 8, -100 + row * 6), Color3.fromRGB(235, 235, 235))
			t.Shape = Enum.PartType.Cylinder; t.Size = Vector3.new(0.6, 4, 4)
			t.CFrame = at(rx - 26 + col * 13, 5 + row * 8, -100 + row * 6) * CFrame.Angles(0, math.rad(90), 0)
			t:SetAttribute("RangeTarget", true)
			local bull = part("Bull", Vector3.new(0.7, 1.4, 1.4), t.CFrame, RED, Enum.Material.Neon)
			bull.Shape = Enum.PartType.Cylinder; bull.CanQuery = false; bull.CanCollide = false
			bull.Parent = t
			table.insert(rangeTargets, t)
		end
	end
	rangeStart = part("RangeStart", Vector3.new(4, 4, 4), at(rx, 2, -18), GREEN, Enum.Material.Neon)
	local pr = Instance.new("ProximityPrompt"); pr.ActionText = "Défi " .. L.range.duration .. " s"; pr.ObjectText = "Stand de tir"
	pr.HoldDuration = 0.3; pr.MaxActivationDistance = 10; pr.Parent = rangeStart
	billboard(rangeStart, "🎯 Défi " .. L.range.duration .. " secondes", GREEN, 4)

	-- ---------- parcours (nord-est) : 16 plateformes en zigzag qui montent jusqu'à ~45 studs ----------
	parkourStart = part("ParkourStart", Vector3.new(10, 0.6, 10), at(40, 0.3, 30), GREEN, Enum.Material.Neon)
	billboard(parkourStart, "🏃 PARCOURS · départ", GREEN, 5)
	local x, y, z = 40, 0, 30
	local steps = {   -- déplacement { x, hauteur, z } d'une plateforme à la suivante (saut faisable avec le saut Roblox par défaut)
		{ 12, 3, 0 }, { 12, 3, 0 }, { 13, 3, 0 }, { 12, 3, 0 }, { 0, 3, 12 }, { 0, 3, 13 }, { -12, 2, 0 }, { -13, 3, 0 },
		{ -12, 3, 0 }, { 0, 3, 12 }, { 13, 3, 0 }, { 12, 3, 0 }, { 13, 2, 0 }, { 0, 3, 12 }, { -12, 3, 0 }, { -13, 3, 0 },
	}
	local hues = { RED, GOLD, GREEN, BLUE }
	for i, st in ipairs(steps) do
		x += st[1]; y += st[2]; z += st[3]
		local size = if i % 5 == 0 then Vector3.new(4, 1, 4) else Vector3.new(6, 1, 6)   -- quelques plateformes plus petites
		part("Parkour_" .. i, size, at(x, y, z), hues[(i - 1) % 4 + 1], Enum.Material.Neon)
	end
	parkourFinish = part("ParkourFinish", Vector3.new(10, 1, 10), at(x - 13, y + 2, z), GOLD, Enum.Material.Neon)
	billboard(parkourFinish, "🏁 ARRIVÉE", GOLD, 5)

	-- ---------- bornes Codes et Groupe ----------
	local function kiosk(name: string, pos: CFrame, color: Color3, text: string, action: string, panel: string)
		local k = part(name, Vector3.new(6, 9, 3), pos, DARK, Enum.Material.Metal)
		local screen = part(name .. "Screen", Vector3.new(5, 4, 0.3), pos * CFrame.new(0, 2, 1.6), color, Enum.Material.Neon)
		sign(screen, text, Color3.new(1, 1, 1), Enum.NormalId.Back)
		local prompt = Instance.new("ProximityPrompt"); prompt.ActionText = action; prompt.ObjectText = text
		prompt.MaxActivationDistance = 10; prompt.HoldDuration = 0; prompt.Parent = k
		prompt.Triggered:Connect(function(p) panelEvent:FireClient(p, panel) end)
	end
	kiosk("CodesKiosk", at(-26, 4.5, 26) * CFrame.Angles(0, math.rad(180), 0), Color3.fromRGB(170, 90, 255), "🎟️ CODES", "Entrer un code", "codes")
	kiosk("GroupKiosk", at(26, 4.5, 26) * CFrame.Angles(0, math.rad(180), 0), Color3.fromRGB(0, 176, 111), "👥 GROUPE", "Récompense", "group")

	-- ---------- classement géant (fond du lobby, face au point d'arrivée) ----------
	local board = part("Leaderboard", Vector3.new(96, 50, 2), at(0, 30, -half + 3) * CFrame.Angles(0, math.rad(180), 0), Color3.fromRGB(14, 18, 28), Enum.Material.SmoothPlastic)
	part("BoardFrame", Vector3.new(100, 54, 1.5), at(0, 30, -half + 2), GOLD, Enum.Material.Neon)
	LobbyService.board = board
end

-- ==========================================================================================
-- Apparition dans le lobby
-- ==========================================================================================
local function lobbyLoadout(p: Player): { string }
	local primary = p:GetAttribute("Primary")
	local keys = table.clone(L.loadout)
	if typeof(primary) == "string" then keys[1] = primary end
	return keys
end

function LobbyService.spawn(p: Player)
	if not p.Parent then return end
	p:SetAttribute("Zone", "lobby")
	p:SetAttribute("DuelTeam", nil)
	p.Team = nil
	WeaponService.reset(p)
	p:LoadCharacter()
	local char = p.Character or p.CharacterAdded:Wait()
	char:PivotTo(CFrame.new(O + Vector3.new(math.random(-8, 8), 4, math.random(-8, 8))) * CFrame.Angles(0, math.rad(180), 0))
	WeaponService.giveLoadout(p, lobbyLoadout(p))
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	hum.Died:Connect(function()
		WeaponService.reset(p)
		task.delay(2, function()
			if p.Parent and p.Character == char and p:GetAttribute("Zone") == "lobby" then LobbyService.spawn(p) end
		end)
	end)
end

function LobbyService.joinMatch(p: Player)
	if p:GetAttribute("Zone") ~= "lobby" or p:GetAttribute("DuelQueued") then return false end
	TDMService.join(p)
	if TDMService.state() ~= "live" then
		LobbyService.toast(p, "Tu es inscrit : la partie commence dans quelques secondes", BLUE)
	end
	return true
end

function LobbyService.leaveMatch(p: Player)
	if p:GetAttribute("Zone") ~= "tdm" then return false end
	TDMService.leave(p)
	LobbyService.spawn(p)
	return true
end

-- ==========================================================================================
-- Stand de tir : entraînement libre + défi chronométré (un joueur à la fois)
-- ==========================================================================================
local challenge = { player = nil :: Player?, endsAt = 0, score = 0, active = {} :: { [BasePart]: boolean } }

local function setTargetVisible(t: BasePart, on: boolean)
	t.Transparency = if on then 0 else 0.85
	local bull = t:FindFirstChild("Bull") :: BasePart?
	if bull then bull.Transparency = if on then 0 else 0.85 end
end

local function pickNewTarget(except: BasePart?)
	local pool = {}
	for _, t in ipairs(rangeTargets) do
		if not challenge.active[t] and t ~= except then table.insert(pool, t) end
	end
	if #pool == 0 then return end
	local t = pool[math.random(#pool)]
	challenge.active[t] = true
	setTargetVisible(t, true)
end

local function endChallenge()
	local p = challenge.player
	challenge.player = nil
	challenge.active = {}
	for _, t in ipairs(rangeTargets) do setTargetVisible(t, true) end
	if not p or not p.Parent then return end
	timerEvent:FireClient(p, { kind = "stop" })
	local profile = DataService.get(p)
	if not profile then return end
	local score = challenge.score
	local lb = profile.lobby
	local msg = "🎯 " .. score .. " cibles en " .. L.range.duration .. " s"
	if score > lb.rangeBest then lb.rangeBest = score; msg ..= " · nouveau record !" end
	if score >= L.range.firstReward and not lb.rangeRewarded then
		lb.rangeRewarded = true
		profile.coins += L.range.rewardCoins
		msg ..= " · +" .. L.range.rewardCoins .. " 🪙"
	end
	LobbyService.toast(p, msg, GOLD)
end

local function startChallenge(p: Player)
	if challenge.player then
		if challenge.player ~= p then LobbyService.toast(p, "Le stand est occupé, attends la fin du défi", RED) end
		return
	end
	if p:GetAttribute("Zone") ~= "lobby" then return end
	challenge.player = p
	challenge.score = 0
	challenge.active = {}
	challenge.endsAt = workspace:GetServerTimeNow() + L.range.duration
	for _, t in ipairs(rangeTargets) do setTargetVisible(t, false) end
	for _ = 1, L.range.visibleTargets do pickNewTarget() end
	WeaponService.resupply(p)
	timerEvent:FireClient(p, { kind = "range", endsAt = challenge.endsAt, goal = L.range.firstReward })
	local mine = challenge.endsAt
	task.delay(L.range.duration, function() if challenge.player == p and challenge.endsAt == mine then endChallenge() end end)
end

WeaponService.TargetHit:Connect(function(shooter, target: BasePart)
	if typeof(shooter) ~= "Instance" or not shooter:IsA("Player") then return end
	-- petit flash de la cible touchée
	local bull = target:FindFirstChild("Bull") :: BasePart?
	if bull then
		bull.Color = GREEN
		task.delay(0.15, function() bull.Color = RED end)
	end
	if challenge.player ~= shooter or not challenge.active[target] then return end
	challenge.active[target] = nil
	setTargetVisible(target, false)
	challenge.score += 1
	timerEvent:FireClient(shooter, { kind = "range", endsAt = challenge.endsAt, score = challenge.score, goal = L.range.firstReward })
	pickNewTarget(target)
end)

-- ==========================================================================================
-- Parcours : chrono du départ à l'arrivée, record personnel, récompense au premier parcours
-- ==========================================================================================
local parkourRun: { [Player]: number } = {}

local function touchedBy(partObj: BasePart, fn: (Player) -> ())
	local cooldown: { [Player]: number } = {}
	partObj.Touched:Connect(function(hit)
		local p = Players:GetPlayerFromCharacter(hit.Parent)
		if not p or p:GetAttribute("Zone") ~= "lobby" then return end
		if (cooldown[p] or 0) > os.clock() then return end
		cooldown[p] = os.clock() + 1
		fn(p)
	end)
end

local function hookParkour()
	touchedBy(parkourStart, function(p)
		parkourRun[p] = workspace:GetServerTimeNow()
		timerEvent:FireClient(p, { kind = "parkour", start = parkourRun[p] })
	end)
	touchedBy(parkourFinish, function(p)
		local t0 = parkourRun[p]
		if not t0 then return end
		parkourRun[p] = nil
		local t = workspace:GetServerTimeNow() - t0
		timerEvent:FireClient(p, { kind = "stop" })
		if t < 8 or t > 600 then return end     -- trop rapide pour être honnête, ou départ oublié
		local profile = DataService.get(p)
		if not profile then return end
		local lb = profile.lobby
		local msg = string.format("🏁 Parcours en %.2f s", t)
		if lb.parkourBest == 0 or t < lb.parkourBest then lb.parkourBest = math.floor(t * 100) / 100; msg ..= " · nouveau record !" end
		if not lb.parkourRewarded then
			lb.parkourRewarded = true
			profile.coins += L.parkour.rewardCoins
			msg ..= " · +" .. L.parkour.rewardCoins .. " 🪙"
		end
		LobbyService.toast(p, msg, GOLD)
	end)
end

-- ==========================================================================================
-- Démarrage
-- ==========================================================================================
function LobbyService.start()
	Players.CharacterAutoLoads = false
	build()
	hookParkour()
	;(rangeStart:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt).Triggered:Connect(startChallenge)

	local function onJoin(p: Player)
		p:SetAttribute("Zone", "lobby")
		task.spawn(LobbyService.spawn, p)
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, p in ipairs(Players:GetPlayers()) do onJoin(p) end
	Players.PlayerRemoving:Connect(function(p)
		parkourRun[p] = nil
		if challenge.player == p then endChallenge() end
	end)

	local joinFn = Instance.new("RemoteFunction"); joinFn.Name = "JoinMatch"; joinFn.Parent = ReplicatedStorage
	joinFn.OnServerInvoke = function(p) return LobbyService.joinMatch(p) end
	local leaveFn = Instance.new("RemoteFunction"); leaveFn.Name = "LeaveMatch"; leaveFn.Parent = ReplicatedStorage
	leaveFn.OnServerInvoke = function(p) return LobbyService.leaveMatch(p) end
end

return LobbyService
