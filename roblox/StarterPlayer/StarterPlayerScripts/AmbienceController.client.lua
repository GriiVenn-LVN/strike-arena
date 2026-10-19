--!strict
-- StarterPlayerScripts/AmbienceController (LocalScript)
-- Tout ce qui sonne sans qu'une arme le demande :
--   * réverbération du lieu : celle de la carte, plus fermée quand un plafond est au-dessus de la caméra (souk, tunnels, hangars) ;
--   * fond sonore de la carte (vent, bourdonnement, port…) en boucle, avec des rafales, plus fort sous l'orage ;
--   * bruits de pas des joueurs et des bots selon le sol (sable, herbe, neige, pierre, bois, métal) et saut du joueur.
-- Les pas Roblox par défaut (RbxCharacterSounds) sont coupés : ils feraient doublon avec ceux de la planche.
-- Réglages dans ModeConfig.SOUNDS (MAPS, ACOUSTICS, AMBIENCE, STEPS).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModeConfig = require(ReplicatedStorage.Shared.ModeConfig)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local S = require(ReplicatedStorage.Shared.ClientState)

local player = Players.LocalPlayer
local SOUNDS: any = ModeConfig.SOUNDS
local M = 3.571                                  -- studs par mètre (Config.STUDS_PER_METER)
local HAS_SHEET = ModeConfig.SOUND_SHEET ~= 0

-- ---------- carte du joueur ----------
-- attribut MatchMap du joueur (nom du dossier de la carte), sinon la carte sous la caméra, sinon le lobby (nil)
local function currentMap(): Folder?
	local name = player:GetAttribute("MatchMap")
	if typeof(name) == "string" and name ~= "" then
		local f = workspace:FindFirstChild(name)
		if f and f:IsA("Folder") and f:GetAttribute("MapId") then return f end
	end
	local cam = workspace.CurrentCamera
	if not cam then return nil end
	local pos = cam.CFrame.Position
	for _, f in ipairs(workspace:GetChildren()) do
		if f:IsA("Folder") and typeof(f:GetAttribute("MapId")) == "string" then
			local o = f:GetAttribute("Origin")
			local size = f:GetAttribute("MapSize")
			if typeof(o) == "Vector3" and typeof(size) == "number"
				and pos.X >= o.X and pos.X <= o.X + size and pos.Z >= o.Z and pos.Z <= o.Z + size and math.abs(pos.Y - o.Y) < 200 then
				return f
			end
		end
	end
	return nil
end

local mapFolder: Folder? = nil
local mapInfo: any = nil
local covered = false

-- ---------- fond sonore ----------
type Bed = { sound: Sound, layer: any, fade: number, out: boolean, seed: number }
local beds: { Bed } = {}
local bedName: string? = nil

local function setAmbience(name: string?)
	if name == bedName then return end
	bedName = name
	for _, b in ipairs(beds) do b.out = true end
	local layers = name and SOUNDS.AMBIENCE and SOUNDS.AMBIENCE[name]
	if not layers then return end
	local group = Sfx.group("ambient")
	for i, L in ipairs(layers) do
		local s = Instance.new("Sound")
		s.Name = "Ambiance"; s.SoundId = L.id; s.Looped = true; s.Volume = 0; s.PlaybackSpeed = L.rate or 1
		if group then s.SoundGroup = group end
		local eq = Instance.new("EqualizerSoundEffect")
		eq.HighGain = L.high or 0; eq.MidGain = L.mid or 0; eq.LowGain = 0; eq.Parent = s
		s.Parent = game:GetService("SoundService")
		s.TimePosition = math.random() * 2
		s:Play()
		table.insert(beds, { sound = s, layer = L, fade = 0, out = false, seed = i * 7.3 + math.random() * 50 })
	end
end

local function updateBeds(dt: number)
	local t = os.clock()
	local w = workspace:GetAttribute("Weather")
	local weather = if w == "storm" then 1.6 elseif w == "rain" then 1.25 else 1
	local cover = if covered then 0.5 else 1
	for i = #beds, 1, -1 do
		local b = beds[i]
		if b.out then b.fade -= dt / 1.5 else b.fade = math.min(1, b.fade + dt / 2.5) end
		if b.fade <= 0 and b.out then
			b.sound:Destroy(); table.remove(beds, i)
		else
			local L = b.layer
			local gust = 1 + (L.gust or 0) * math.noise(t * 0.13, b.seed) * 1.6
			b.sound.Volume = math.max(0, (L.vol or 0.1) * gust * weather * cover * math.max(0, b.fade))
			b.sound.PlaybackSpeed = (L.rate or 1) * (1 + (L.gust or 0) * 0.08 * math.noise(t * 0.1, b.seed + 3))
		end
	end
end

-- ---------- lieu : carte, plafond, réverbération ----------
local upParams = RaycastParams.new(); upParams.FilterType = Enum.RaycastFilterType.Include
local coverVotes = 0
local function updatePlace()
	local f = currentMap()
	if f ~= mapFolder then
		mapFolder = f
		local id = f and f:GetAttribute("MapId")
		mapInfo = if typeof(id) == "string" and SOUNDS.MAPS then SOUNDS.MAPS[id] else nil
		covered = false; coverVotes = 0
		setAmbience(mapInfo and mapInfo.ambience)
	end
	if not mapFolder or not mapInfo then Sfx.setAcoustics("lobby"); return end
	local cam = workspace.CurrentCamera
	local hit = false
	if cam then
		upParams.FilterDescendantsInstances = { mapFolder }
		hit = workspace:Raycast(cam.CFrame.Position, Vector3.new(0, 18 * M, 0), upParams) ~= nil
	end
	-- deux lectures de suite avant de changer (pas de va-et-vient au bord d'un toit)
	if hit ~= covered then coverVotes += 1 else coverVotes = 0 end
	if coverVotes >= 2 then covered = hit; coverVotes = 0 end
	Sfx.setAcoustics(if covered then mapInfo.inn else mapInfo.out)
end

-- ---------- pas ----------
local MAT: { [string]: string } = {
	Sand = "sand", Ground = "sand", Mud = "sand", Salt = "sand",
	Grass = "grass", LeafyGrass = "grass",
	Snow = "snow", Ice = "snow", Glacier = "snow",
	Wood = "wood", WoodPlanks = "wood",
	Metal = "metal", CorrodedMetal = "metal", DiamondPlate = "metal", Foil = "metal",
	Concrete = "stone", Brick = "stone", Cobblestone = "stone", Granite = "stone", Marble = "stone", Slate = "stone",
	Rock = "stone", Basalt = "stone", Pavement = "stone", Limestone = "stone", Asphalt = "stone", Sandstone = "stone",
}
local function surfaceOf(part: BasePart): string
	local byMat = MAT[part.Material.Name]
	if byMat then return byMat end
	local info = mapInfo
	if not info then return "stone" end
	if part.Name == "Floor" then return info.floor or "sand" end
	if part:IsA("WedgePart") or part.Name == "Block" then return info.raised or info.floor or "stone" end
	return info.floor or "stone"
end

local DEFAULT_SOUNDS = { Running = true, Jumping = true, Landing = true, FreeFalling = true }
type Walker = { char: Model, hum: Humanoid, hrp: BasePart, t: number, foot: boolean, conns: { RBXScriptConnection } }
local walkers: { [Model]: Walker } = {}
local downParams = RaycastParams.new(); downParams.FilterType = Enum.RaycastFilterType.Exclude

local function mute(s: Instance, conns: { RBXScriptConnection })
	if s:IsA("Sound") and DEFAULT_SOUNDS[s.Name] and s.Parent and s.Parent.Name == "HumanoidRootPart" then
		s.Volume = 0
		table.insert(conns, s:GetPropertyChangedSignal("Volume"):Connect(function() if s.Volume > 0 then s.Volume = 0 end end))
	end
end

local function forget(char: Model)
	local w = walkers[char]
	if not w then return end
	walkers[char] = nil
	for _, c in ipairs(w.conns) do c:Disconnect() end
end

local function track(char: Model)
	if walkers[char] or not HAS_SHEET then return end
	task.spawn(function()
		local hum = char:WaitForChild("Humanoid", 10)
		local hrp = char:WaitForChild("HumanoidRootPart", 10)
		if not hum or not hum:IsA("Humanoid") or not hrp or not hrp:IsA("BasePart") or walkers[char] then return end
		local w: Walker = { char = char, hum = hum, hrp = hrp, t = 0, foot = false, conns = {} }
		walkers[char] = w
		for _, d in ipairs(hrp:GetChildren()) do mute(d, w.conns) end
		table.insert(w.conns, hrp.ChildAdded:Connect(function(d) mute(d, w.conns) end))
		table.insert(w.conns, char.AncestryChanged:Connect(function() if not char:IsDescendantOf(workspace) then forget(char) end end))
		if char == player.Character then
			table.insert(w.conns, hum.StateChanged:Connect(function(_, new)
				if new == Enum.HumanoidStateType.Jumping then Sfx.play("jump") end
			end))
		end
	end)
end

local function stepOf(w: Walker, dt: number, cam: Vector3)
	local own = w.char == player.Character
	if w.hum.Health <= 0 then return end
	local v = w.hrp.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude / M
	if speed < 3.2 or (own and (S.crouch or S.slide or S.mantle)) then w.t = math.min(w.t, 0.12); return end
	local d = (w.hrp.Position - cam).Magnitude / M
	if not own and d > 40 then return end
	w.t -= dt
	if w.t > 0 then return end
	-- comme le web : 0,4 s entre deux pas en marchant, 0,3 en sprint, 0,25 en sprint tactique
	w.t = if own then (if S.sprint and S.tactical then 0.25 elseif S.sprint then 0.3 else 0.4)
		else math.clamp(2 / speed, 0.25, 0.42)
	downParams.FilterDescendantsInstances = { w.char }
	local reach = w.hum.HipHeight + w.hrp.Size.Y / 2 + 1.5
	local r = workspace:Raycast(w.hrp.Position, Vector3.new(0, -reach, 0), downParams)
	if not r then return end
	local part = r.Instance
	local surface = if part:IsA("BasePart") then surfaceOf(part) else "stone"
	w.foot = not w.foot
	local vol = if own then (if S.sprint then 0.36 else 0.28) else 0.5
	Sfx.step(surface, if own then nil else r.Position, vol * (if w.foot then 1 else 0.9))
end

local function watchPlayer(p: Player)
	p.CharacterAdded:Connect(track)
	if p.Character then track(p.Character) end
end
for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end
Players.PlayerAdded:Connect(watchPlayer)
local function watchBots(f: Instance)
	f.ChildAdded:Connect(function(m) if m:IsA("Model") then track(m) end end)
	for _, m in ipairs(f:GetChildren()) do if m:IsA("Model") then track(m) end end
end
local botsFolder = workspace:FindFirstChild("Bots")
if botsFolder then watchBots(botsFolder) end
workspace.ChildAdded:Connect(function(c: Instance) if c.Name == "Bots" and c:IsA("Folder") then watchBots(c) end end)

-- ---------- boucle ----------
local placeT = 0
RunService.Heartbeat:Connect(function(dt: number)
	placeT -= dt
	if placeT <= 0 then placeT = 0.4; updatePlace() end
	updateBeds(dt)
	local cam = workspace.CurrentCamera
	if not cam then return end
	local cp = cam.CFrame.Position
	for _, w in pairs(walkers) do stepOf(w, dt, cp) end
end)
