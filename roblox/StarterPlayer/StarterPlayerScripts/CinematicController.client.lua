--!strict
-- StarterPlayerScripts/CinematicController (LocalScript)
-- Arrivée au début d'une partie en équipe, comme le jeu web :
--   src/65_cine.js   hélicoptère : plan d'ensemble au-dessus des toits, vue à la première personne depuis la cabine
--                    (pilotes, coéquipiers sur les bancs, porte ouverte), coéquipiers qui descendent en rappel, puis notre
--                    propre descente le long de la corde jusqu'au sol (ou saut depuis la porte si le départ est couvert) ;
--   src/65b_car.js   véhicule : camion (Village, Station polaire) ou blindé (Port de nuit, Métro, Laboratoire, Asile, et
--                    toute carte où l'on démarre sous un toit) sur une route qui longe la carte : plan au bord de la route,
--                    vue assise dans la cellule, freinage, portes arrière (ou hayon) qui s'ouvrent, descente, sortie.
-- Bandes noires, titres (carte, mode, camp, puis objectif), sons (rotor, moteur, freinage, portes), flash blanc final,
-- puis la main revient au joueur en vue à la première personne. Espace, Entrée, clic ou toucher l'écran : passer.
-- Déclenchée par le serveur (ServerScriptService/ArrivalService, remote « ArrivalCinematic ») au début de chaque partie
-- en équipe, pendant « PRÉPAREZ-VOUS » : le serveur garde tout le monde immobile et attend la fin (ou le passage) de
-- la scène de chacun, puis le compte à rebours reprend.
-- Les coéquipiers (joueurs et bots) sont des copies figées de leurs soldats, posées et animées ici (assis, rappel,
-- marche) ; les vrais restent cachés à leur point de départ pendant la scène.
-- Tous les calculs sont en mètres dans le repère de la carte du web (x, z de 0 à 80, sol à 0), comme sur le web.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local MapData = require(ReplicatedStorage.Shared.MapData)
local Modes = require(ReplicatedStorage.Shared.Modes)
local S = require(ReplicatedStorage.Shared.ClientState)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local VM = require(ReplicatedStorage.Shared.VehicleModels)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local U = Config.STUDS_PER_METER
local remote = ReplicatedStorage:WaitForChild("ArrivalCinematic", math.huge) :: RemoteEvent

-- carte -> véhicule (CAR_MAPS du web) ; les autres cartes gardent l'hélicoptère, sauf départ sous un toit (blindé)
local CAR_MAPS: { [string]: string } = { metro = "blinde", labo = "blinde", asile = "blinde", harbor = "blinde", village = "camion_sable", station = "camion_vert" }

-- ---------- petits calculs (65_cine.js) ----------
local pi, sin, cos, abs, max, min = math.pi, math.sin, math.cos, math.abs, math.max, math.min
local function clamp(x: number, a: number, b: number): number return if x < a then a elseif x > b then b else x end
local function lerp(a: number, b: number, k: number): number return a + (b - a) * k end
local function easeOut(t: number): number t = clamp(t, 0, 1); return 1 - (1 - t) ^ 3 end
local function easeIO(t: number): number t = clamp(t, 0, 1); return t * t * (3 - 2 * t) end
local function angDiff(a: number, b: number): number local d = (b - a) % (2 * pi); if d > pi then d -= 2 * pi end; return d end
local function V(x: number, y: number, z: number): Vector3 return Vector3.new(x, y, z) end
local function E(x: number, y: number, z: number): CFrame return CFrame.fromEulerAnglesYXZ(x, y, z) end   -- Euler « YXZ » de three.js
-- interpolation par images-clés { temps, valeur }
local function keyAt(K: { { number } }, T: number): number
	if T <= K[1][1] then return K[1][2] end
	for i = 2, #K do
		if T <= K[i][1] then local a, b = K[i - 1], K[i]; return lerp(a[2], b[2], easeIO((T - a[1]) / (b[1] - a[1]))) end
	end
	return K[#K][2]
end
local LOOKA = { { 2.6, 0.12 }, { 3.4, 0.12 }, { 4.6, 0.85 }, { 6.2, 1.0 }, { 7.2, -0.35 }, { 7.9, -0.7 }, { 8.9, -0.8 }, { 9.5, 1.5 } }
local LOOKP = { { 2.6, -0.1 }, { 3.4, -0.12 }, { 4.6, -0.45 }, { 6.2, -0.55 }, { 7.2, -0.18 }, { 7.9, -0.38 }, { 8.9, -0.42 }, { 9.5, -1.0 } }
local CLOOKA = { { 2.4, 0.05 }, { 3.3, -0.1 }, { 4.3, -1.15 }, { 5.3, -1.25 }, { 6.0, -0.2 }, { 6.8, 2.6 } }
local CLOOKP = { { 2.4, -0.08 }, { 3.3, -0.1 }, { 4.3, -0.22 }, { 5.3, -0.2 }, { 6.0, -0.1 }, { 6.8, -0.12 } }
local ARR = 7.6              -- fin de l'approche de l'hélicoptère
local CAR_STOP = 6.0         -- arrêt du véhicule

-- ==========================================================================================
-- Interface : bandes noires, titres, « passer », flash blanc (#cine et #flashfx du web)
-- ==========================================================================================
local GAP = "\u{2009}"
local function spaced(s: string): string
	local out = {}
	for _, cp in utf8.codes(s) do table.insert(out, utf8.char(cp)) end
	return table.concat(out, GAP)
end
local gui = Instance.new("ScreenGui")
gui.Name = "ArrivalCinematic"; gui.IgnoreGuiInset = true; gui.ResetOnSpawn = false; gui.DisplayOrder = 60; gui.Enabled = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local bars: { Frame } = {}
for i = 1, 2 do
	local f = Instance.new("Frame"); f.Name = "Bar" .. i; f.BorderSizePixel = 0; f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.Size = UDim2.fromScale(1, 0.11); f.Position = UDim2.fromScale(0, if i == 1 then 0 else 0.89); f.Parent = gui
	table.insert(bars, f)
end
local function label(name: string, pos: UDim2, size: UDim2, font: Enum.Font, color: Color3, maxSize: number, align: Enum.TextXAlignment): TextLabel
	local t = Instance.new("TextLabel"); t.Name = name; t.BackgroundTransparency = 1; t.Position = pos; t.Size = size
	t.Font = font; t.TextColor3 = color; t.TextScaled = true; t.TextXAlignment = align; t.TextYAlignment = Enum.TextYAlignment.Bottom
	t.TextStrokeTransparency = 0.55; t.TextStrokeColor3 = Color3.new(0, 0, 0); t.Text = ""
	local c = Instance.new("UITextSizeConstraint"); c.MaxTextSize = maxSize; c.MinTextSize = 10; c.Parent = t
	t.Parent = gui
	return t
end
-- titre : 3,4 rem, très gras, en bas à gauche ; sous-titre doré (--gold du web) ; « ESPACE — PASSER » à droite
local title = label("Title", UDim2.new(0.07, 0, 0.81, -62), UDim2.new(0.86, 0, 0, 60), Enum.Font.GothamBlack, Color3.new(1, 1, 1), 54, Enum.TextXAlignment.Left)
local sub = label("Sub", UDim2.new(0.072, 0, 0.85, -22), UDim2.new(0.8, 0, 0, 22), Enum.Font.GothamBold, Color3.fromRGB(255, 215, 94), 18, Enum.TextXAlignment.Left)
local skipLbl = label("Skip", UDim2.new(0.55, 0, 0.87, -14), UDim2.new(0.42, 0, 0, 14), Enum.Font.GothamMedium, Color3.new(1, 1, 1), 12, Enum.TextXAlignment.Right)
skipLbl.TextTransparency = 0.33; skipLbl.TextStrokeTransparency = 1
local flash = Instance.new("Frame"); flash.Name = "Flash"; flash.BorderSizePixel = 0; flash.BackgroundColor3 = Color3.new(1, 1, 1)
flash.BackgroundTransparency = 1; flash.Size = UDim2.fromScale(1, 1); flash.ZIndex = 5; flash.Parent = gui
gui.Parent = player:WaitForChild("PlayerGui")

-- titres qui glissent depuis la gauche en apparaissant (animation cinein du web, 1 s)
local titleT0 = 0
local function setTitles(a: string, b: string)
	title.Text = spaced(string.upper(a)); sub.Text = spaced(b)
	titleT0 = os.clock()
end
local function animTitles()
	local k = 1 - (1 - clamp((os.clock() - titleT0) / 1.0, 0, 1)) ^ 3
	title.TextTransparency = 1 - k; title.Position = UDim2.new(0.07, -60 * (1 - k), 0.81, -62)
	title.TextStrokeTransparency = 1 - 0.45 * k
end

-- ==========================================================================================
-- Sons : boucles du rotor et du moteur (startHeli / startEngine du web, bruit filtré modulé) et bruitages
-- ==========================================================================================
type Loop = { set: (number) -> (), tick: (number) -> (), stop: () -> () }
local function loopSound(id: string, speed: number, vol: number, high: number, mid: number, low: number): (Sound, EqualizerSoundEffect)
	local s = Instance.new("Sound"); s.SoundId = id; s.Looped = true; s.Volume = vol; s.PlaybackSpeed = speed
	local eq = Instance.new("EqualizerSoundEffect"); eq.HighGain = high; eq.MidGain = mid; eq.LowGain = low; eq.Parent = s
	s.SoundGroup = Sfx.group("ambient") or Sfx.group("master")
	s.Parent = SoundService
	s:Play()
	return s, eq
end
-- hélicoptère : souffle des pales haché à 12 Hz + grondement grave de la turbine
local function startHeli(): Loop
	local blades, beq = loopSound("rbxasset://sounds/action_falling.mp3", 0.42, 0.3, -22, -4, 6)
	local turb = loopSound("rbxasset://sounds/action_falling.mp3", 0.2, 0.15, -30, -8, 8)
	local v, t = 0.45, 0
	return {
		set = function(x: number) v = x end,
		tick = function(dt: number)
			t += dt
			local chop = 0.55 + 0.45 * sin(t * 12 * 2 * pi)
			blades.Volume = (0.12 + 0.35 * v) * (0.45 + 0.55 * chop) * 1.6
			beq.HighGain = -26 + 8 * v
			turb.Volume = (0.05 + 0.12 * v) * 1.5
		end,
		stop = function() blades:Destroy(); turb:Destroy() end,
	}
end
-- moteur : grondement dont le régime suit la vitesse
local function startEngine(): Loop
	local eng, eeq = loopSound("rbxasset://sounds/action_falling.mp3", 0.16, 0.1, -32, -10, 10)
	local road = loopSound("rbxasset://sounds/action_swim.mp3", 0.5, 0.05, -20, -6, 2)
	local v, t = 0, 0
	return {
		set = function(x: number) v = x end,
		tick = function(dt: number)
			t += dt
			local rpm = 8 + 18 * v                                     -- cognement du diesel
			eng.PlaybackSpeed = 0.14 + 0.16 * v
			eng.Volume = (0.08 + 0.12 * v) * (0.75 + 0.25 * sin(t * rpm * 2 * pi)) * 1.8
			eeq.MidGain = -12 + 6 * v
			road.Volume = 0.02 + 0.1 * v
		end,
		stop = function() eng:Destroy(); road:Destroy() end,
	}
end
-- bruitage court (sons fournis avec Roblox), coupé en fondu après len secondes
local function oneShot(id: string, speed: number, vol: number, len: number, high: number?)
	local s = Instance.new("Sound"); s.SoundId = id; s.PlaybackSpeed = speed; s.Volume = vol
	if high then local eq = Instance.new("EqualizerSoundEffect"); eq.HighGain = high; eq.MidGain = 0; eq.LowGain = 4; eq.Parent = s end
	s.SoundGroup = Sfx.group("ui") or Sfx.group("master")
	s.Parent = SoundService; s:Play()
	task.delay(len, function()
		for i = 1, 6 do if s.Parent then s.Volume = vol * (1 - i / 6); task.wait(0.04) end end
		s:Destroy()
	end)
	Debris:AddItem(s, len + 2)
end
local function sndBrake() oneShot("rbxasset://sounds/action_falling.mp3", 1.7, 0.35, 0.9, 6) end      -- frein à air
local function sndDoor()                                                                             -- portes métalliques
	oneShot("rbxasset://sounds/clickfast.wav", 0.55, 0.6, 0.3)
	task.delay(0.08, function() oneShot("rbxasset://sounds/swordhit.wav", 0.42, 0.45, 0.6, -8) end)
end
local function sndRope() Sfx.play("slide", nil, 0.8) end                                             -- glisse le long de la corde
local function sndLand() Sfx.play("land", nil, 1.1) end

-- ==========================================================================================
-- Soldats figés (copies) : assis, debout, en marche
-- ==========================================================================================
local R15 = { HumanoidRootPart = true, Head = true, UpperTorso = true, LowerTorso = true, LeftUpperArm = true, LeftLowerArm = true,
	LeftHand = true, RightUpperArm = true, RightLowerArm = true, RightHand = true, LeftUpperLeg = true, LeftLowerLeg = true,
	LeftFoot = true, RightUpperLeg = true, RightLowerLeg = true, RightFoot = true, Torso = true, ["Left Leg"] = true, ["Right Leg"] = true,
	["Left Arm"] = true, ["Right Arm"] = true }
type Ghost = {
	model: Model, body: { BasePart }, rel: { CFrame }, leg: { string }, extra: { BasePart }, host: { number }, hrel: { CFrame },
	hipL: Vector3, hipR: Vector3, kneeL: Vector3, kneeR: Vector3, thigh: number, hOff: number,
}
local function makeGhost(src: Model): Ghost?
	local hrp0 = src:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp0 then return nil end
	local was = src.Archivable
	src.Archivable = true
	local ok, copy = pcall(function() return src:Clone() end)
	src.Archivable = was
	if not ok or not copy then return nil end
	local model = copy :: Model
	model.Name = "Arrivee_" .. src.Name
	local held = model:FindFirstChild("HeldWeapon"); if held then held:Destroy() end
	local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then model:Destroy(); return nil end
	local h0 = hrp.CFrame
	local g: Ghost = { model = model, body = {}, rel = {}, leg = {}, extra = {}, host = {}, hrel = {},
		hipL = Vector3.zero, hipR = Vector3.zero, kneeL = Vector3.zero, kneeR = Vector3.zero, thigh = 0, hOff = 3 }
	local index: { [BasePart]: number } = {}
	local all: { BasePart } = {}
	-- liens pièce -> membre porteur, lus avant de supprimer les articulations
	local link: { [BasePart]: BasePart } = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then table.insert(all, d)
		elseif d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			local a, b = (d :: any).Part0 :: BasePart?, (d :: any).Part1 :: BasePart?
			if a and b then
				if R15[a.Name] and not R15[b.Name] then link[b] = a elseif R15[b.Name] and not R15[a.Name] then link[a] = b end
			end
		end
	end
	local minY = math.huge
	for _, p in ipairs(all) do
		if R15[p.Name] and p.Parent == model then
			table.insert(g.body, p); table.insert(g.rel, h0:Inverse() * p.CFrame); index[p] = #g.body
			table.insert(g.leg, if string.find(p.Name, "Leg") or string.find(p.Name, "Foot") then (if string.sub(p.Name, 1, 4) == "Left" then "L" else "R") else "")
			if string.find(p.Name, "Foot") or p.Name == "Left Leg" or p.Name == "Right Leg" then minY = min(minY, p.Position.Y - p.Size.Y / 2) end
		end
	end
	for _, p in ipairs(all) do
		if not index[p] then
			local host = link[p]
			if not host or not index[host] then
				local best, bd = g.body[1], math.huge
				for _, b in ipairs(g.body) do local dd = (b.Position - p.Position).Magnitude; if dd < bd then best, bd = b, dd end end
				host = best
			end
			if host and index[host] then
				table.insert(g.extra, p); table.insert(g.host, index[host]); table.insert(g.hrel, host.CFrame:Inverse() * p.CFrame)
			end
		end
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Constraint") or d:IsA("Script") or d:IsA("LocalScript")
			or d:IsA("ModuleScript") or d:IsA("Highlight") or d:IsA("BillboardGui") or d:IsA("Sound") or d:IsA("ForceField") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true; d.CanCollide = false; d.CanQuery = false; d.CanTouch = false; d.LocalTransparencyModifier = 0
		elseif d:IsA("Humanoid") then
			d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			d.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
			d.EvaluateStateMachine = false
		end
	end
	-- hanches et genoux (haut des cuisses et des tibias), longueur de cuisse, hauteur du bassin au-dessus des semelles
	local function top(name: string): Vector3?
		local p = model:FindFirstChild(name) :: BasePart?
		if not p or not index[p] then return nil end
		return (h0:Inverse() * p.CFrame * CFrame.new(0, p.Size.Y / 2, 0)).Position
	end
	g.hipL = top("LeftUpperLeg") or V(-0.5, -1, 0); g.hipR = top("RightUpperLeg") or V(0.5, -1, 0)
	g.kneeL = top("LeftLowerLeg") or g.hipL - V(0, 1.4, 0); g.kneeR = top("RightLowerLeg") or g.hipR - V(0, 1.4, 0)
	g.thigh = (g.hipL - g.kneeL).Magnitude
	g.hOff = if minY < math.huge then h0.Position.Y - minY else 3
	return g
end

-- pose : feet = repère au niveau des semelles (studs, regard vers -Z) ; thL/thR = cuisses levées vers l'avant (rad),
-- knee = genoux pliés (rad, négatif : le tibia revient sous le genou). Renvoie les pièces et leurs repères.
local function poseGhost(g: Ghost, feet: CFrame, thL: number, thR: number, knee: number, outP: { BasePart }, outC: { CFrame })
	local th = max(thL, thR)
	local root = feet * CFrame.new(0, g.hOff - g.thigh * (1 - cos(th)), 0)
	local T1L = CFrame.new(g.hipL) * CFrame.Angles(thL, 0, 0) * CFrame.new(-g.hipL)
	local T1R = CFrame.new(g.hipR) * CFrame.Angles(thR, 0, 0) * CFrame.new(-g.hipR)
	local kL, kR = T1L * g.kneeL, T1R * g.kneeR
	local T2L = CFrame.new(kL) * CFrame.Angles(knee, 0, 0) * CFrame.new(-kL) * T1L
	local T2R = CFrame.new(kR) * CFrame.Angles(knee, 0, 0) * CFrame.new(-kR) * T1R
	local now: { CFrame } = table.create(#g.body)
	for i, p in ipairs(g.body) do
		local side = g.leg[i]
		local L = CFrame.identity
		if side ~= "" then
			local upper = string.find(p.Name, "Upper") ~= nil or p.Name == "Left Leg" or p.Name == "Right Leg"
			if side == "L" then L = if upper then T1L else T2L else L = if upper then T1R else T2R end
		end
		local cf = root * L * g.rel[i]
		now[i] = cf
		table.insert(outP, p); table.insert(outC, cf)
	end
	for i, p in ipairs(g.extra) do table.insert(outP, p); table.insert(outC, now[g.host[i]] * g.hrel[i]) end
end

-- ==========================================================================================
-- Scène
-- ==========================================================================================
local playing = false
local abortRun: (() -> ())? = nil   -- remise en état de la scène en cours (appelée aussi si elle plante)

local function run(info: any)
	if playing then return end
	playing = true
	local function done() pcall(function() remote:FireServer("done") end) end
	-- ---------- carte, joueur, équipe ----------
	local folder = workspace:FindFirstChild(tostring(player:GetAttribute("MatchMap") or ""))
	local origin = folder and folder:GetAttribute("Origin")
	local mapId = folder and folder:GetAttribute("MapId")
	local char = player.Character
	local t0 = os.clock()
	while (not char or not char:FindFirstChild("HumanoidRootPart")) and os.clock() - t0 < 4 do task.wait(0.1); char = player.Character end
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not folder or typeof(origin) ~= "Vector3" or typeof(mapId) ~= "string" or not char or not hrp or not hum then playing = false; done(); return end
	local O: Vector3 = origin
	local M = (folder:GetAttribute("MapSize") :: number? or MapData.N * Config.CELL * U) / U   -- côté de la carte (m)
	local function toW(p: Vector3): Vector3 return O + p * U end
	local function toL(p: Vector3): Vector3 return (p - O) / U end
	local function cfW(posL: Vector3, rot: CFrame): CFrame return CFrame.new(toW(posL)) * rot end
	-- rayons : collision de la carte, sans les murs invisibles du bord
	local hitList = {}
	local col = folder:FindFirstChild("Collision")
	for _, c in ipairs(if col then col:GetChildren() else {}) do if c:IsA("BasePart") and c.Name ~= "Border" then table.insert(hitList, c) end end
	local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Include; rp.FilterDescendantsInstances = hitList
	-- hauteur du décor autour d'un point (cineTopAt du web)
	local function topAt(x: number, z: number, r: number): number
		local top = -1e9
		for _, d in ipairs({ { 0, 0 }, { r, 0 }, { -r, 0 }, { 0, r }, { 0, -r } }) do
			local hit = workspace:Raycast(toW(V(x + d[1], 120, z + d[2])), V(0, -140 * U, 0), rp)
			if hit then top = max(top, toL(hit.Position).Y) end
		end
		return top
	end
	-- segment dégagé de tout décor ?
	local function clear(a: Vector3, b: Vector3): boolean
		local d = b - a
		if d.Magnitude < 1e-3 then return true end
		return workspace:Raycast(toW(a), d * U, rp) == nil
	end
	local function feetOf(m: Model): (Vector3?, number)
		local r = m:FindFirstChild("HumanoidRootPart") :: BasePart?
		local h = m:FindFirstChildOfClass("Humanoid")
		if not r then return nil, 0 end
		local lv = r.CFrame.LookVector
		local off = if h then h.HipHeight + r.Size.Y / 2 else 3
		return toL(r.Position - V(0, off, 0)), math.atan2(-lv.X, -lv.Z)
	end
	local Pp, Pyaw = feetOf(char)
	if not Pp then playing = false; done(); return end
	local P: Vector3 = Pp
	local myTeam = player:GetAttribute("Team")
	local matchId = player:GetAttribute("MatchId")
	-- combattants de la partie : coéquipiers (joueurs puis bots, comme ents du web) et adversaires
	type Mate = { m: Model, pos: Vector3, yaw: number }
	local mates: { Mate } = {}
	local everyone: { Model } = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		if c and p:GetAttribute("MatchId") == matchId then
			table.insert(everyone, c)
			if p ~= player and p:GetAttribute("Team") == myTeam then
				local pos, yaw = feetOf(c)
				if pos then table.insert(mates, { m = c, pos = pos, yaw = yaw }) end
			end
		end
	end
	local bots = workspace:FindFirstChild("Bots")
	for _, b in ipairs(if bots then bots:GetChildren() else {}) do
		if b:IsA("Model") and b:GetAttribute("MatchId") == matchId then
			table.insert(everyone, b)
			local h = b:FindFirstChildOfClass("Humanoid")
			if b:GetAttribute("Team") == myTeam and h and h.Health > 0 then
				local pos, yaw = feetOf(b)
				if pos then table.insert(mates, { m = b, pos = pos, yaw = yaw }) end
			end
		end
	end
	-- ---------- textes ----------
	local mode = tostring(player:GetAttribute("MatchMode") or "tdm")
	local def = Modes.LIST[mode]
	local md = MapData[mapId] :: any
	local bomb = mode == "bomb" or mode == "rapid"
	local att = myTeam == "Attaquants"
	local side = if bomb then (if att then "ATTAQUANTS" else "DÉFENSEURS") else (if att then "ÉQUIPE ORANGE" else "ÉQUIPE BLEUE")
	local limit = tonumber(info and info.limit) or 0
	local obj, objSub
	if mode == "duel" then obj, objSub = "ÉLIMINE L'ADVERSAIRE", "Premier à " .. limit .. " manches"
	elseif bomb then obj, objSub = (if att then "POSEZ LA BOMBE" else "PROTÉGEZ LES SITES"), "Site A ou B"
	elseif mode == "zombies" then obj, objSub = "SURVIVEZ", "Survis à " .. (if limit >= 99 then "l'infini" else limit .. " manches")
	else obj, objSub = "ÉLIMINEZ L'ÉQUIPE ADVERSE", "Premier à " .. limit end

	-- ---------- choix de la scène ----------
	local covered = workspace:Raycast(toW(P + V(0, 2, 0)), V(0, 60 * U, 0), rp) ~= nil   -- ceilAt < 90 du web
	local carKind = CAR_MAPS[mapId] or (if covered then "blinde" else nil)
	local veh = VM.build(carKind or "heli")
	local car = carKind ~= nil and veh.kind ~= "heli"      -- véhicule introuvable : l'hélicoptère le remplace
	veh.model.Parent = workspace
	local cx, cz = M / 2, M / 2
	local hx, hz = P.X, P.Z
	do
		local n = 1
		for _, mt in ipairs(mates) do hx += mt.pos.X; hz += mt.pos.Z; n += 1 end
		hx /= n; hz /= n
	end
	-- état commun
	local dur = 11.6
	local yaw = 0
	local poses: { [string]: CFrame } = {}
	local Hcf = CFrame.identity                       -- repère du véhicule (mètres, repère de la carte)
	local Hrot = CFrame.identity
	local function hToW(lp: Vector3): Vector3 return toW((Hcf * CFrame.new(lp)).Position) end
	-- hélicoptère
	local from, to, cruise, sideV, ext, headSm = Vector3.zero, Vector3.zero, 0, Vector3.zero, nil :: Vector3?, nil :: number?
	local heliCovered = false
	-- véhicule
	local Ept, uV, nV, dist0 = Vector3.zero, Vector3.zero, Vector3.zero, 70
	local road: Model? = nil
	local hidden: { { p: BasePart, t: number } } = {}
	local pp = { x = -0.68, z = 0.55 }
	local wheelA = 0
	if not car then
		-- point de stationnaire : la porte gauche juste au-dessus du point de départ du joueur
		local dx, dz = hx - cx, hz - cz
		local dl = math.sqrt(dx * dx + dz * dz)
		if dl < 1 then dx, dz, dl = 0, 1, 1 end
		dx /= dl; dz /= dl
		yaw = math.atan2(dx, dz)                       -- nez vers le centre de la carte
		local ox, oz = -(veh.CW + 0.35), 0.2
		hx = P.X - (ox * cos(yaw) + oz * sin(yaw)); hz = P.Z - (-ox * sin(yaw) + oz * cos(yaw))
		local hoverY = max(topAt(hx, hz, 6) + 6.5, topAt(P.X, P.Z, 1.5) + 8, P.Y + 9)
		-- arrivée de l'extérieur de la carte, côté de l'équipe, au-dessus de tout le décor
		local fx, fz = hx + dx * 120, hz + dz * 120
		cruise = hoverY
		for i = 0, 16 do local k = i / 16; cruise = max(cruise, topAt(lerp(fx, hx, k), lerp(fz, hz, k), 5) + 7) end
		from = V(fx, cruise + 6, fz); to = V(hx, hoverY, hz)
		-- départ sous un toit : pas de rappel à travers le plafond, on saute de la porte
		heliCovered = topAt(P.X, P.Z, 0.4) > P.Y + 2.6
		dur = if heliCovered then 9.8 else 11.6
		sideV = V(cos(yaw), 0, -sin(yaw))
	end
	-- position de l'hélicoptère à l'instant T (approche, arrondi, stationnaire, départ)
	local function path(T: number): Vector3
		local k = easeOut(T / ARR)
		local x, z = lerp(from.X, to.X, k), lerp(from.Z, to.Z, k)
		local sw = sin(clamp(T / ARR, 0, 1) * pi) * 7     -- léger virage en S pendant l'approche
		x += sideV.X * sw; z += sideV.Z * sw
		local y = if T < ARR * 0.7 then lerp(from.Y, cruise + 1, easeIO(T / (ARR * 0.7))) else lerp(cruise + 1, to.Y, easeIO((T - ARR * 0.7) / (ARR * 0.3)))
		if T > ARR then y += sin(T * 1.6) * 0.1; x += sin(T * 1.1) * 0.12 end
		if T > 10.4 then y += easeOut((T - 10.4) / 1.6) * 9 end
		return V(x, y, z)
	end
	if not car then
		-- plan d'ensemble : caméra au-dessus des toits, choisie pour voir l'hélico sans obstacle
		local midp = path(2.2)
		for _, sd in ipairs({ 1, -1 }) do
			for _, fw in ipairs({ -14, -24, -6 }) do
				for _, up in ipairs({ 2, 5, 9 }) do
					if not ext then
						local dx, dz = -sideV.Z, sideV.X                 -- (dx, dz) du web : sin(yaw), cos(yaw)
						local cp = V(midp.X + sideV.X * sd * 15 - dx * fw, max(midp.Y, cruise) + up, midp.Z + sideV.Z * sd * 15 - dz * fw)
						local ok = true
						for i = 0, 8 do if ok then ok = clear(cp, path(i / 8 * 2.8)) end end
						if ok then ext = cp end
					end
				end
			end
		end
	else
		-- arrêt juste à l'extérieur du bord de carte le plus proche du camp de l'équipe ; la route longe ce bord
		dur = 9.9
		local dx, dz = hx - cx, hz - cz
		if abs(dx) > abs(dz) then
			local s = if dx > 0 then 1 else -1
			nV = V(s, 0, 0); Ept = V(if s > 0 then M + 5 else -5, 0, clamp(hz, 12, M - 12)); uV = V(0, 0, if hz < cz then 1 else -1)
		else
			local s = if dz > 0 then 1 else -1
			nV = V(0, 0, s); Ept = V(clamp(hx, 12, M - 12), 0, if s > 0 then M + 5 else -5); uV = V(if hx < cx then 1 else -1, 0, 0)
		end
		yaw = math.atan2(-uV.X, -uV.Z)
		if veh.info then pp = { x = veh.info.player[1], z = veh.info.player[2] } end
		-- ruban de route (asphalte, lignes, bordures)
		local rm = Instance.new("Model"); rm.Name = "ArriveeRoute"
		local len = 140
		local rot = CFrame.Angles(0, math.atan2(uV.X, uV.Z), 0)
		local mid = Ept - uV * (len / 2 - 15)
		local function slab(name: string, w: number, h: number, l: number, at: Vector3, color: Color3, mat: Enum.Material)
			local p = Instance.new("Part"); p.Name = name; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
			p.Size = V(w, h, l) * U; p.CFrame = CFrame.new(toW(at)) * rot; p.Color = color; p.Material = mat
			p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth; p.Parent = rm
		end
		local nX = V(uV.Z, 0, -uV.X)                       -- perpendiculaire à la route
		slab("Asphalte", 7, 0.06, len, mid + V(0, 0.0, 0), Color3.fromRGB(58, 59, 61), Enum.Material.Asphalt)
		for _, s in ipairs({ -1, 1 }) do
			slab("Bordure", 0.3, 0.18, len, mid + nX * (s * 3.65) + V(0, 0.06, 0), Color3.fromRGB(154, 152, 144), Enum.Material.Concrete)
			slab("Rive", 0.12, 0.01, len, mid + nX * (s * 3.15) + V(0, 0.035, 0), Color3.fromRGB(235, 235, 225), Enum.Material.SmoothPlastic)
		end
		for i = 0, math.floor(len / 7) - 1 do   -- ligne médiane pointillée
			slab("Ligne", 0.12, 0.01, 3.8, Ept - uV * (i * 7 - 15 + 3.5) + V(0, 0.035, 0), Color3.fromRGB(235, 235, 225), Enum.Material.SmoothPlastic)
		end
		rm.Parent = workspace; road = rm
		-- dégage le couloir de la route : décor hors carte masqué le temps de la scène (carClear du web)
		local function inside(x: number, z: number, r: number): boolean
			local dn = (x - Ept.X) * nV.X + (z - Ept.Z) * nV.Z
			local du = -((x - Ept.X) * uV.X + (z - Ept.Z) * uV.Z)
			return dn > -4.5 and dn < 11 + r and du > -30 - r and du < 135 + r
		end
		for _, d in ipairs(folder:GetDescendants()) do
			if d:IsA("BasePart") and d.Transparency < 1 then
				local l = toL(d.Position)
				if (l.X < -1 or l.X > M + 1 or l.Z < -1 or l.Z > M + 1) and l.Y > 0.2 and d.Size.Magnitude < 120 * U and inside(l.X, l.Z, max(d.Size.X, d.Size.Z) / U / 2) then
					table.insert(hidden, { p = d, t = d.LocalTransparencyModifier }); d.LocalTransparencyModifier = 1
				end
			end
		end
	end
	local function carDist(T: number): number local k = clamp(T / CAR_STOP, 0, 1); return dist0 * (1 - (1 - (1 - k) * (1 - k))) end

	-- ---------- soldats : pilotes / chauffeur, coéquipiers ----------
	type Seat = { g: Ghost?, mate: Mate, x: number, z: number, f: number, door: number, drop: number, hidden: boolean }
	local pilots: { Ghost } = {}
	local pilotSpots: { { number } } = {}
	if car then
		if veh.info then
			if veh.info.driver then table.insert(pilotSpots, { veh.info.driver[1], veh.info.driver[2] }) end
		else table.insert(pilotSpots, { -0.5, -1.62 }) end
	else pilotSpots = { { -0.55, -2.5 }, { 0.55, -2.5 } } end
	local pilotSrc: Model = char
	for _, mt in ipairs(mates) do if not Players:GetPlayerFromCharacter(mt.m) then pilotSrc = mt.m; break end end
	for _ in ipairs(pilotSpots) do
		local g = makeGhost(pilotSrc)
		if g then g.model.Parent = workspace; table.insert(pilots, g) end
	end
	local HSEATS = { { x = 0.05, z = 1.4, f = 0 }, { x = 0.75, z = 1.4, f = 0 }, { x = -0.42, z = -1.38, f = pi }, { x = 0.42, z = -1.38, f = pi } }
	local seatsDef: { { x: number, z: number, f: number } } = HSEATS
	if car then
		seatsDef = {}
		local list = if veh.info then veh.info.seats else { { -0.72, -0.35 }, { 0.72, -0.35 }, { 0.72, 0.55 }, { 0.72, 1.45 } }
		for _, s in ipairs(list) do table.insert(seatsDef, { x = s[1], z = s[2], f = if s[1] < 0 then -pi / 2 else pi / 2 }) end
	end
	local seats: { Seat } = {}
	for i, mt in ipairs(mates) do
		local st = seatsDef[i]
		local g = if st then makeGhost(mt.m) else nil
		if g then g.model.Parent = workspace end
		local doorSide = if st and (st.x > 0 or (st.x >= 0 and st.f ~= 0)) then 1 else -1
		table.insert(seats, { g = g, mate = mt, x = if st then st.x else 0, z = if st then st.z else 0, f = if st then st.f else 0,
			door = doorSide, drop = if car then 6.3 + (i - 1) * 0.3 else 7.9 + (i - 1) * 0.35, hidden = g == nil })
	end
	-- cordes (une par coéquipier + la nôtre) et nos mains gantées
	local ropes: { Part } = {}
	local function newRope(): Part
		local r = Instance.new("Part"); r.Name = "Corde"; r.Anchored = true; r.CanCollide = false; r.CanQuery = false; r.CanTouch = false
		r.Shape = Enum.PartType.Cylinder; r.Color = Color3.fromRGB(43, 38, 32); r.Material = Enum.Material.Fabric
		r.Size = V(1, 0.05 * U, 0.05 * U); r.Transparency = 1; r.Parent = veh.model
		return r
	end
	if not car then for _ = 1, #seats + 1 do table.insert(ropes, newRope()) end end
	local function ropeSet(r: Part, a: Vector3, b: Vector3)   -- a, b en mètres (repère de la carte)
		local wa, wb = toW(a), toW(b)
		local L = (wb - wa).Magnitude
		if L < 0.01 then r.Transparency = 1; return end
		r.Size = V(L, 0.05 * U, 0.05 * U)
		r.CFrame = CFrame.lookAt((wa + wb) / 2, wb) * CFrame.Angles(0, pi / 2, 0)
		r.Transparency = 0
	end
	local hands: { Part } = {}
	if not car then
		for i = 1, 2 do
			local h = Instance.new("Part"); h.Name = "Gant" .. i; h.Anchored = true; h.CanCollide = false; h.CanQuery = false; h.CanTouch = false
			h.Size = V(0.09, 0.05, 0.11) * U; h.Color = Color3.fromRGB(38, 36, 32); h.Material = Enum.Material.Fabric; h.Transparency = 1; h.Parent = veh.model
			table.insert(hands, h)
		end
	end
	-- poussière soulevée par le rotor
	local dustPart: Part? = nil
	local dust: ParticleEmitter? = nil
	if not car then
		local dp = Instance.new("Part"); dp.Name = "Poussiere"; dp.Anchored = true; dp.CanCollide = false; dp.CanQuery = false; dp.CanTouch = false
		dp.Transparency = 1; dp.Size = V(10, 0.2, 10) * U; dp.Parent = veh.model
		local pe = Instance.new("ParticleEmitter")
		pe.Color = ColorSequence.new(Color3.fromRGB(184, 160, 120)); pe.LightEmission = 0; pe.Rate = 0
		pe.Lifetime = NumberRange.new(0.9, 1.6); pe.Speed = NumberRange.new(9, 20); pe.SpreadAngle = Vector2.new(80, 10)
		pe.EmissionDirection = Enum.NormalId.Top; pe.Acceleration = V(0, -2, 0); pe.Drag = 1.5
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 7) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
		pe.Parent = dp
		dustPart, dust = dp, pe
	end

	-- ---------- on cache les vrais soldats, l'interface, et on prend la caméra ----------
	local ltm: { [BasePart]: number } = {}
	local offs: { Instance } = {}
	local function hideReal()
		for _, m in ipairs(everyone) do
			if m.Parent then
				for _, d in ipairs(m:GetDescendants()) do
					if d:IsA("BasePart") then
						if ltm[d] == nil then ltm[d] = d.LocalTransparencyModifier end
						d.LocalTransparencyModifier = 1
					elseif (d:IsA("BillboardGui") or d:IsA("Highlight")) and (d :: any).Enabled then
						(d :: any).Enabled = false; table.insert(offs, d)        -- noms, contours d'équipe
					end
				end
			end
		end
	end
	hideReal()
	local guis: { ScreenGui } = {}
	for _, g in ipairs(player.PlayerGui:GetChildren()) do
		if g:IsA("ScreenGui") and g ~= gui and g.Enabled then g.Enabled = false; table.insert(guis, g) end
	end
	local prevKc = S.kc
	S.kc = { key = nil, skin = nil, camo = nil, arrival = true } :: any   -- comme la kill-cam : la scène tient la caméra
	local savedType, savedFov = camera.CameraType, camera.FieldOfView
	camera.CameraType = Enum.CameraType.Scriptable
	hrp.Anchored = true
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	skipLbl.Text = spaced(if touch then "TOUCHE L'ÉCRAN — PASSER" else "ESPACE — PASSER")
	setTitles(if md and md.name then md.name else mapId, (if def then def.n else mode) .. " — " .. side)
	flash.BackgroundTransparency = 1
	gui.Enabled = true
	local snd = if car then startEngine() else startHeli()

	-- ---------- passer ----------
	local T = 0
	local skipped = false
	local function skip()
		if skipped then return end
		skipped = true; T = max(T, dur - 0.5)
	end
	ContextActionService:BindActionAtPriority("ArriveePasser", function(_, st: Enum.UserInputState)
		if st == Enum.UserInputState.Begin then skip() end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 50, Enum.KeyCode.Space, Enum.KeyCode.Return, Enum.KeyCode.ButtonA,
		Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2)
	local touchConn = UserInputService.TouchStarted:Connect(function() skip() end)

	-- ---------- image par image ----------
	local t2 = false
	local fired: { [string]: boolean } = {}
	local function once(k: string, f: () -> ()) if not fired[k] then fired[k] = true; f() end end
	local finished = false
	local lastEye = camera.CFrame
	-- ---------- fin : tout remettre, la main revient au joueur ----------
	-- (aussi appelé si la scène plante en route : sinon caméra Scriptable, soldat ancré et interface cachée pour de bon)
	local restored = false
	local function restore()
		if restored then return end
		restored = true; finished = true
		pcall(function() RunService:UnbindFromRenderStep("ArriveeCinematique") end)
		ContextActionService:UnbindAction("ArriveePasser")
		touchConn:Disconnect()
		snd.stop()
		for _, g in ipairs(pilots) do g.model:Destroy() end
		for _, s in ipairs(seats) do if s.g then s.g.model:Destroy() end end
		veh.model:Destroy()
		if road then road:Destroy() end
		for _, h in ipairs(hidden) do if h.p.Parent then h.p.LocalTransparencyModifier = h.t end end
		for p, t in pairs(ltm) do if p.Parent then p.LocalTransparencyModifier = t end end
		for _, d in ipairs(offs) do if d.Parent then (d :: any).Enabled = true end end
		for _, g in ipairs(guis) do if g.Parent then g.Enabled = true end end
		if (S.kc :: any) and (S.kc :: any).arrival then S.kc = prevKc end
		if hrp.Parent then hrp.Anchored = false end
		-- vue à la première personne : on regarde là où la scène finit (la caméra Roblox repart de camera.CFrame)
		local r = hrp.Parent and hrp.Position or toW(P + V(0, 1, 0))
		local look = lastEye.LookVector
		local flat = V(look.X, 0, look.Z)
		if flat.Magnitude < 1e-3 then flat = V(0, 0, -1) end
		camera.CameraType = if savedType == Enum.CameraType.Scriptable then Enum.CameraType.Custom else savedType
		camera.FieldOfView = savedFov
		camera.CFrame = CFrame.lookAt(r + V(0, 1.5, 0), r + V(0, 1.5, 0) + flat.Unit)
		if hum.Parent then camera.CameraSubject = hum end
		gui.Enabled = false
	end
	abortRun = restore
	local function seatedFeet(lx: number, lz: number, f: number): CFrame
		return CFrame.new(hToW(V(lx, veh.CF, lz))) * Hrot * CFrame.Angles(0, f, 0)
	end
	local function step(dt: number)
		T += dt
		local oP: { BasePart }, oC: { CFrame } = {}, {}
		if not car then
			-- ======== hélicoptère ========
			local pos = path(T)
			local pv = path(T + 0.05)
			local vx, vz = pv.X - pos.X, pv.Z - pos.Z
			local sp = math.sqrt(vx * vx + vz * vz) / 0.05
			local head = if sp > 2 then math.atan2(-vx, -vz) else yaw
			headSm = if headSm == nil then head else (headSm :: number) + angDiff(headSm :: number, head) * min(1, dt * 3)
			local hd = headSm :: number
			local pitch = if T < ARR - 1.2 then -clamp(sp / 40, 0, 0.16) elseif T < ARR + 0.6 then sin(clamp((T - (ARR - 1.2)) / 1.8, 0, 1) * pi) * 0.14 else 0
			local roll = cos(clamp(T / ARR, 0, 1) * pi) * 0.08 * (if T < ARR then 1 else 0) + sin(T * 1.3) * 0.02
			Hrot = E(pitch, hd, roll)
			Hcf = CFrame.new(pos) * Hrot
			poses.rotor = CFrame.Angles(0, T * 34, 0); poses.tail = CFrame.Angles(T * 44, 0, 0)
			VM.place(veh, cfW(pos, Hrot), poses)
			VM.setBeacon(veh, 1, (T % 1) < 0.12)
			for i, s in ipairs(veh.screens) do s.Transparency = 0.15 + 0.15 * sin(T * 3 + i * 2) end
			snd.set(if T < 2.6 then 0.45 else 0.95)
			-- pilotes : assis aux commandes
			for i, g in ipairs(pilots) do
				local sp2 = pilotSpots[i]
				poseGhost(g, seatedFeet(sp2[1], sp2[2], 0), 1.45, 1.45, -1.5, oP, oC)
			end
			-- coéquipiers : assis, puis rejoignent la porte et descendent en rappel
			for i, s in ipairs(seats) do
				local g = s.g
				if g then
					local mt = s.mate
					local tGo, tDoor = s.drop, s.drop + 0.4
					local tLand = tDoor + 1.3
					local dLx, dLy, dLz = s.door * (veh.CW + 0.15), veh.CF, if s.z > 0 then 0.3 else -0.5
					local rope = ropes[i]
					if T < tDoor then
						local k = easeIO((T - tGo) / 0.4)
						local f = lerp(s.f, if s.door > 0 then -pi / 2 else pi / 2, k)
						local sit = if k > 0 then 0 else 1
						poseGhost(g, seatedFeet(lerp(s.x, dLx, k), lerp(s.z, dLz, k), f), 1.45 * sit, 1.45 * sit, -1.5 * sit, oP, oC)
						rope.Transparency = 1
					elseif heliCovered then
						-- départ couvert : ils sautent de la porte et sont déjà au sol
						poseGhost(g, CFrame.new(toW(mt.pos)) * CFrame.Angles(0, mt.yaw, 0), 0, 0, 0, oP, oC)
						rope.Transparency = 1
					elseif T < tLand then
						local top = (Hcf * CFrame.new(dLx, dLy, dLz)).Position
						local k = easeIO((T - tDoor) / 1.3)
						local at = top:Lerp(mt.pos, k)
						poseGhost(g, CFrame.new(toW(at)) * CFrame.Angles(0, hd + (if s.door > 0 then -pi / 2 else pi / 2), 0), 0.25, 0.25, -0.3, oP, oC)
						ropeSet(rope, top + V(0, 0.6, 0), mt.pos)
						if k < 0.05 then once("rope" .. i, sndRope) end
					else
						poseGhost(g, CFrame.new(toW(mt.pos)) * CFrame.Angles(0, mt.yaw, 0), 0, 0, 0, oP, oC)
						local top = (Hcf * CFrame.new(dLx, dLy + 0.6, dLz)).Position
						if T < tLand + 2.2 then ropeSet(rope, top, top + V(0.1, -9, 0)) else rope.Transparency = 1 end
					end
				end
			end
			-- poussière du rotor
			if dust and dustPart then
				local on = T > ARR - 1.6 and T < 11
				dustPart.CFrame = CFrame.new(toW(V(pos.X, topAt(pos.X, pos.Z, 0) + 0.2, pos.Z)))
				dust.Rate = if on then 60 else 0
			end
		else
			-- ======== véhicule ========
			local d, d2 = carDist(T), carDist(T + 0.05)
			local v = (d - d2) / 0.05
			local vib = min(1, v / 8)
			local pos = Ept - uV * d
			local brake = if T > CAR_STOP - 1.6 and T < CAR_STOP + 0.4 then sin(clamp((T - (CAR_STOP - 1.6)) / 2, 0, 1) * pi) * 0.025 else 0
			pos += V(0, sin(T * 11) * 0.012 * vib, 0)
			Hrot = E(-brake + sin(T * 7.3) * 0.003 * vib, yaw, sin(T * 5.1) * 0.004 * vib)
			Hcf = CFrame.new(pos) * Hrot
			wheelA -= v * dt / veh.wheelR
			for _, w in ipairs({ "wheel_FL", "wheel_FR", "wheel_RL", "wheel_RR" }) do poses[w] = CFrame.Angles(wheelA, 0, 0) end
			-- portes arrière qui s'ouvrent (ou hayon du camion qui s'abaisse)
			local ko = easeIO((T - 6.0) / 0.7)
			poses.door_L = CFrame.Angles(0, -ko * 1.9, 0); poses.door_R = CFrame.Angles(0, ko * 1.9, 0)
			poses.tailgate = CFrame.Angles(ko * 1.62, 0, 0)
			VM.place(veh, cfW(pos, Hrot), poses)
			VM.setBeacon(veh, 1, ((T * 3) % 1) < 0.5); VM.setBeacon(veh, 2, ((T * 3 + 0.5) % 1) < 0.5)
			snd.set(clamp(v / 22, 0, 1))
			if T > CAR_STOP - 1.5 then once("brake", sndBrake) end
			if T > 5.95 then once("doors", sndDoor) end
			for i, g in ipairs(pilots) do
				local sp2 = pilotSpots[i]
				poseGhost(g, seatedFeet(sp2[1], sp2[2], 0), 1.45, 1.45, -1.5, oP, oC)
			end
			-- coéquipiers : assis, puis sortent par l'arrière et s'écartent vers la carte
			for i, s in ipairs(seats) do
				local g = s.g
				if g then
					local tGo, tOut = s.drop, s.drop + 0.7
					local tEnd = tOut + 1.2
					if T < tOut then
						local k = easeIO((T - tGo) / 0.7)
						local sit = if k > 0 then 0 else 1
						local walk = if k > 0 and k < 1 then sin(T * 9) * 0.45 else 0
						poseGhost(g, seatedFeet(lerp(s.x, s.x * 0.3, k), lerp(s.z, veh.Z1 + 0.3, k), lerp(s.f, pi, k)),
							1.45 * sit + max(0, walk), 1.45 * sit + max(0, -walk), -1.5 * sit, oP, oC)
					else
						local hp = (Hcf * CFrame.new(s.x * 0.3, 0, veh.Z1 + 0.8)).Position
						local k = easeIO((T - tOut) / 1.2)
						local gx = hp.X - nV.X * (2 + (i - 1) * 1.2) + uV.X * ((i - 1) - 1.5)
						local gz = hp.Z - nV.Z * (2 + (i - 1) * 1.2) + uV.Z * ((i - 1) - 1.5)
						local y = max(0, veh.CF * (1 - k * 3))
						local walk = if T < tEnd then sin(T * 9 + i) * 0.5 else 0
						poseGhost(g, CFrame.new(toW(V(lerp(hp.X, gx, k), y, lerp(hp.Z, gz, k)))) * CFrame.Angles(0, math.atan2(nV.X, nV.Z), 0),
							max(0, walk), max(0, -walk), -0.4 * abs(walk), oP, oC)
					end
				end
			end
		end
		if #oP > 0 then workspace:BulkMoveTo(oP, oC, Enum.BulkMoveMode.FireCFrameChanged) end
		snd.tick(dt)
		hideReal()
		animTitles()
		-- titres : objectif
		if T > (if car then 3.2 else 3.4) and not t2 then t2 = true; setTitles(obj, objSub) end
		if T >= dur then finished = true; return end

		-- ---------------- caméra ----------------
		local eye: CFrame
		local fov = 70
		if not car then
			for _, h in ipairs(hands) do h.Transparency = 1 end
			local pRope = ropes[#ropes]
			pRope.Transparency = 1
			local tMove, tRope, tGround = 8.9, 9.5, 11.0
			local hd = headSm :: number
			if T < 2.6 and ext then        -- plan 1 : vue d'ensemble, au-dessus des toits
				local e = ext :: Vector3
				local pos = Hcf.Position
				eye = CFrame.lookAt(toW(e + V(0, T * 0.25, 0)), toW(pos - V(0, 0.5, 0)))
				fov = lerp(40, 48, T / 2.6)
			elseif T < tRope then           -- plan 2 : à la première personne, assis dans la cabine
				local a, p = keyAt(LOOKA, T), keyAt(LOOKP, T)
				local mk = easeIO((T - tMove) / (tRope - tMove))
				local tb = if T < ARR then 1 else 0.5
				local lp = V(lerp(-0.72, -veh.CW + 0.05, mk) + sin(T * 13.1) * 0.006 * tb,
					lerp(veh.CF + 1.22, veh.CF + 1.0, mk) + sin(T * 17.3) * 0.008 * tb + sin(T * 2.1) * 0.01, lerp(1.32, 0.2, mk))
				eye = CFrame.new(hToW(lp)) * Hrot * E(p + sin(T * 9.7) * 0.004 * tb, a + sin(T * 0.7) * 0.03, sin(T * 1.9) * 0.01)
				fov = lerp(68, 74, mk)
			else                            -- plan 3 : descente en rappel, puis arrivée au sol
				local gy = P.Y
				local k = easeIO((T - tRope) / (tGround - tRope))
				local door = (Hcf * CFrame.new(-veh.CW - 0.35, veh.CF + 1.0, 0.2)).Position
				local ey = gy + 1.6
				local cam = V(lerp(door.X, P.X, k), lerp(door.Y, ey, k), lerp(door.Z, P.Z, k))
				if T > tGround then cam -= V(0, math.exp(-(T - tGround) * 7) * sin((T - tGround) * 16) * 0.08, 0); once("land", sndLand) end
				local q = E(-1.0, hd + 1.5, 0):Lerp(E(-0.05, Pyaw, 0), easeIO((T - tRope - 0.5) / 1.3))
				eye = CFrame.new(toW(cam)) * q
				fov = 74
				once("myrope", sndRope)
				-- corde devant soi + mains qui la tiennent
				local top = (Hcf * CFrame.new(-veh.CW - 0.35, veh.CF + 0.6, 0.2)).Position
				local fwd = q.LookVector; fwd = V(fwd.X, 0, fwd.Z); fwd = if fwd.Magnitude > 1e-3 then fwd.Unit else V(0, 0, -1)
				local bot = V(P.X + fwd.X * 0.4, gy, P.Z + fwd.Z * 0.4)
				if T < tGround + 0.15 then
					ropeSet(pRope, top, bot)
					local kk = clamp((top.Y - cam.Y + 0.35) / max(0.1, top.Y - bot.Y), 0, 1)
					local r = top:Lerp(bot, kk)
					local rightV = q.RightVector
					for i, h in ipairs(hands) do
						local at = r + V(0, if i == 2 then 0.12 else -0.05, 0) + rightV * (if i == 2 then -0.04 else 0.04)
						h.CFrame = CFrame.new(toW(at)) * q.Rotation * CFrame.Angles(-1.2, 0, if i == 2 then -0.4 else 0.4)
						h.Transparency = 0
					end
				end
			end
			if T < 2.6 and not ext then
				local a, p = keyAt(LOOKA, T), keyAt(LOOKP, T)
				eye = CFrame.new(hToW(V(-0.72, veh.CF + 1.22, 1.32))) * Hrot * E(p, a, 0); fov = 68
			end
		else
			if T < 2.4 then                 -- plan 1 : au bord de la route, le véhicule arrive gyrophares allumés
				local cp = V(Ept.X - uV.X * 18 + nV.X * 6.5, 1.1 + T * 0.1, Ept.Z - uV.Z * 18 + nV.Z * 6.5)
				local hp = Hcf.Position
				eye = CFrame.lookAt(toW(cp), toW(V(hp.X, 1.3, hp.Z)))
				fov = lerp(38, 46, T / 2.4)
			elseif T < 7.6 then             -- plan 2 : assis dans la cellule, on regarde la route puis les coéquipiers
				local d, d2 = carDist(T), carDist(T + 0.05)
				local vib = min(1, (d - d2) / 0.05 / 8)
				local a, p = keyAt(CLOOKA, T), keyAt(CLOOKP, T)
				local lp = V(pp.x + 0.1 + sin(T * 13.1) * 0.004 * vib, veh.CF + 1.12 + sin(T * 17.3) * 0.006 * vib, pp.z)
				eye = CFrame.new(hToW(lp)) * Hrot * E(p + sin(T * 9.7) * 0.004 * vib, a, sin(T * 1.9) * 0.006)
				fov = 70
			else                            -- plan 3 : on se lève, on sort par l'arrière et on se tourne vers l'objectif
				local k = easeIO((T - 7.6) / 1.6)
				local lp = V(lerp(pp.x + 0.1, 0, k), lerp(veh.CF + 1.12, 1.6, k), lerp(pp.z, veh.Z1 + 2.2, k))
				local q = E(-0.08, yaw + pi, 0):Lerp(E(-0.03, math.atan2(nV.X, nV.Z), 0), easeIO((T - 8.6) / 1.0))
				eye = CFrame.new(hToW(lp)) * q
				fov = 72
			end
		end
		camera.CFrame = eye; camera.FieldOfView = fov
		lastEye = eye
		-- flash blanc de transition à la fin
		if T > dur - 0.5 then flash.BackgroundTransparency = 1 - min(1, (T - (dur - 0.5)) / 0.5) end
	end
	-- après la caméra Roblox et WeaponCamera (Camera + 1) : la scène a le dernier mot
	local ok = pcall(function()
		RunService:BindToRenderStep("ArriveeCinematique", Enum.RenderPriority.Camera.Value + 10, function(dt: number)
			if finished then return end
			local okS, err = pcall(step :: any, math.min(dt, 0.1))
			if not okS then warn("[CinematicController] " .. tostring(err)); finished = true end
		end)
	end)
	if not ok then finished = true end
	local tStart = os.clock()
	while not finished and os.clock() - tStart < dur + 3 do task.wait(0.05) end
	restore()
	abortRun = nil
	gui.Enabled = true
	title.Text = ""; sub.Text = ""; skipLbl.Text = ""
	for _, b in ipairs(bars) do b.Visible = false end
	flash.BackgroundTransparency = 0.1
	Sfx.play("round")
	done()
	for i = 1, 14 do flash.BackgroundTransparency = 0.1 + 0.9 * i / 14; task.wait(0.05) end
	gui.Enabled = false
	for _, b in ipairs(bars) do b.Visible = true end
	playing = false
end

remote.OnClientEvent:Connect(function(info: any)
	task.spawn(function()
		local ok, err = pcall(run :: any, info)
		if not ok then
			warn("[CinematicController] " .. tostring(err))
			local abort = abortRun
			abortRun = nil
			if abort then abort() end
			playing = false
			pcall(function() remote:FireServer("done") end)
		end
	end)
end)
