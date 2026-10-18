--!strict
-- ServerScriptService/MatchService (ModuleScript, lancé par Main)
-- Toutes les parties du jeu web, plusieurs en même temps sur un même serveur : chaque joueur choisit son mode, sa carte,
-- le niveau des bots et la taille des équipes dans le menu (écran « Jouer » du web), et sa partie est construite à part,
-- à côté des autres (une carte par partie, ses bots, ses scores). Les autres joueurs peuvent la rejoindre depuis la liste
-- des parties en cours ou par « Partie rapide ».
--
-- Le moteur gère ce qui est commun à tous les modes (équipes ou chacun pour soi, apparition loin des ennemis, protection,
-- objets à ramasser, éliminations, assistances, séries, kill-cam, tableau Tab, chrono, fin de partie et récompenses) ;
-- chaque mode (ServerScriptService/Modes/<id>) n'ajoute que ses règles. Interface d'un mode (tout est facultatif) :
--   setup(m)                  carte construite, avant les apparitions          start(m)        la partie commence
--   loadout(m, c) -> {clés}   armes d'un combattant à l'apparition             onSpawn(m, c, char)
--   onKill(m, killer, victim, key, headshot, ks, vs) -> boolean?   true = le mode compte lui-même les points
--   tick(m, dt)               10 fois par seconde pendant la partie            checkEnd(m) -> (fini, gagnant)
--   timeUp(m) -> gagnant      fin du chrono                                    canRespawn(m, c) -> boolean
--   respawnDelay(m, c)        teamFor(m, c) -> équipe à l'arrivée              info(m) -> { line, sub, color }
--   botGoal(m, bot) -> Vector3?   où envoyer un bot (zone, drapeau…)          spawnPoint(m, c) -> Vector3?
--   cleanup(m)                fin de partie
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ModeConfig = require(ReplicatedStorage.Shared.ModeConfig)
local Modes = require(ReplicatedStorage.Shared.Modes)
local ShopCatalog = require(ReplicatedStorage.Shared.ShopCatalog)
local DataService = require(script.Parent.DataService)
local RewardService = require(script.Parent.RewardService)
local ProgressService = require(script.Parent.ProgressService)
local MapBuilder = require(script.Parent.MapBuilder)
local WeaponService = require(script.Parent.WeaponService)
local BotService = require(script.Parent.BotService)
local NetService = require(script.Parent.NetService)
local PartyService = require(script.Parent.PartyService)

local TDM = ModeConfig.TDM
local U = Config.STUDS_PER_METER
local CELL = Config.CELL * U
local TEAMS = { "Attaquants", "Défenseurs" }      -- T (orange) et CT (bleu), comme le web
local MAX_MATCHES = 6                             -- parties en même temps sur un serveur
local SLOT_ORIGIN = Vector3.new(0, 0, 5000)       -- loin du lobby (0, 0, -700) et des arènes de duel (2000, 0, 2000)
local SLOT_SPACING = 1200                         -- une carte du web fait 40 cases de 2 m ≈ 290 studs
local KILLCAM_MAX = 9                             -- la réapparition n'attend jamais plus longtemps la kill-cam
local WARMUP = 4                                  -- « PRÉPAREZ-VOUS… » avant le début
local INTERMISSION = TDM.intermission

local function remoteEvent(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent"); r.Name = name; r.Parent = ReplicatedStorage; return r
end
local function remoteFunction(name: string): RemoteFunction
	local r = Instance.new("RemoteFunction"); r.Name = name; r.Parent = ReplicatedStorage; return r
end
local stateEvent = remoteEvent("TDMState")      -- serveur -> joueurs de la partie : score, temps, tableau, ligne du mode
local feedEvent = remoteEvent("KillFeed")       -- serveur -> joueurs de la partie : une élimination
local bannerEvent = remoteEvent("KillBanner")   -- serveur -> tueur : « +100 Élimination », séries
local deathEvent = remoteEvent("DeathInfo")     -- serveur -> victime : par qui, réapparition dans…
local endEvent = remoteEvent("MatchEnd")        -- serveur -> chaque joueur : victoire/défaite + récompenses
local announceEvent = remoteEvent("MatchAnnounce") -- serveur -> joueurs de la partie : grande bannière (« NOUVELLE ARME », « TU ES LE MASTODONTE »…)
local killcamEvent = remoteEvent("KillcamHold") -- victime -> serveur : kill-cam en cours (true) / finie ou passée (false)
local pickupToast = remoteEvent("PickupToast")  -- serveur -> joueur : objet ramassé
local createFn = remoteFunction("MatchCreate")  -- client -> serveur : lancer une partie avec ses réglages (et son groupe)
local quickFn = remoteFunction("MatchQuick")    -- client -> serveur : partie rapide
local joinFn = remoteFunction("MatchJoin")      -- client -> serveur : rejoindre une partie de la liste
local leaveFn = remoteFunction("MatchLeave")    -- client -> serveur : retour au lobby
local listFn = remoteFunction("MatchList")      -- client -> serveur : parties en cours (menu)
local loadoutFn = remoteFunction("SetLoadout")  -- client -> serveur : arme principale / pistolet du profil

local MatchService = {}

-- ==========================================================================================
-- Types
-- ==========================================================================================
export type Stat = {
	key: any, name: string, team: string, bot: boolean, player: Player?, model: Model?, k: number, d: number, a: number, hs: number,
	dmg: number, shots: number, hits: number, streak: number, bestStreak: number, score: number, pts: number, weaponKills: { [string]: number },
}
export type Match = {
	id: number, slot: number, settings: Modes.Settings, def: Modes.ModeDef, mode: string, mod: any,
	map: any, origin: Vector3, folderName: string, roam: { Vector3 },
	state: string, teams: { string }?, score: { [string]: number }, limit: number?, endsAt: number, startedAt: number, timed: boolean,
	players: { [Player]: boolean }, stats: { [any]: Stat }, dmgBy: { [any]: { [any]: number } }, kcHold: { [Player]: boolean },
	host: Player?, data: { [string]: any }, botCount: { [string]: number }, closed: boolean, pickups: { Model },
}

local matches: { [number]: Match } = {}
local nextId = 1
local matchOfPlayer: { [Player]: Match } = {}

local modeCache: { [string]: any } = {}
local function modeModule(id: string): any
	if modeCache[id] ~= nil then return modeCache[id] end
	local folder = script.Parent:FindFirstChild("Modes")
	local ms = folder and folder:FindFirstChild(id)
	local mod = {}
	if ms and ms:IsA("ModuleScript") then
		local ok, res = pcall(require, ms)
		if ok and typeof(res) == "table" then mod = res else warn("[MatchService] mode", id, res) end
	end
	modeCache[id] = mod
	return mod
end

-- ==========================================================================================
-- Combattants
-- ==========================================================================================
local function isBot(c: any): boolean return typeof(c) == "Instance" and c:IsA("Model") end
local function keyOf(c: any): any
	if isBot(c) then return "bot:" .. c.Name end
	return c
end
function MatchService.keyOf(c: any): any return keyOf(c) end

function MatchService.matchOf(c: any): Match?
	if typeof(c) ~= "Instance" then return nil end
	if c:IsA("Player") then return matchOfPlayer[c] end
	local id = c:GetAttribute("MatchId")
	return if typeof(id) == "number" then matches[id] else nil
end
function MatchService.get(id: number): Match? return matches[id] end

-- Tous les combattants (joueurs + bots) d'une partie
function MatchService.combatants(m: Match): { any }
	local list = {}
	for p in pairs(m.players) do table.insert(list, p) end
	for _, b in ipairs(BotService.ofMatch(m.id)) do table.insert(list, b) end
	return list
end
local function aliveChar(c: any): Model?
	local ch = WeaponService.charOf(c)
	local h = ch and ch:FindFirstChildOfClass("Humanoid")
	return if ch and h and h.Health > 0 then ch else nil
end
MatchService.aliveChar = aliveChar

function MatchService.statOf(m: Match, c: any): Stat?
	local k = keyOf(c)
	local s = m.stats[k]
	if not s then
		local team = WeaponService.teamOf(c)
		if not team then return nil end
		local bot = isBot(c)
		s = { key = k, name = WeaponService.nameOf(c), team = team, bot = bot, player = if bot then nil else c, model = if bot then c else nil,
			k = 0, d = 0, a = 0, hs = 0, dmg = 0, shots = 0, hits = 0, streak = 0, bestStreak = 0, score = 0, pts = 0, weaponKills = {} }
		m.stats[k] = s
	end
	return s
end
local statOf = MatchService.statOf

-- équipe « affichée » d'un combattant : T/CT en équipe, sa propre clé en chacun pour soi
local function soloTeam(c: any): string
	return "solo:" .. (if isBot(c) then c.Name else tostring((c :: Player).UserId))
end
function MatchService.setTeam(m: Match, c: any, team: string)
	if typeof(c) == "Instance" then c:SetAttribute("Team", team) end
	local s = m.stats[keyOf(c)]
	if s then s.team = team end
end

function MatchService.cellToWorld(m: Match, cx: number, cz: number): Vector3
	-- hauteur du sol comprise (MapBuilder) ; repli : sol plat
	if m.map and m.map.cellToWorld then return m.map.cellToWorld(cx, cz) end
	return m.origin + Vector3.new((cx + 0.5) * CELL, 0, (cz + 0.5) * CELL)
end

-- ==========================================================================================
-- Messages aux joueurs d'une partie
-- ==========================================================================================
local function fireMatch(m: Match, ev: RemoteEvent, ...: any)
	for p in pairs(m.players) do if p.Parent then ev:FireClient(p, ...) end end
end
MatchService.fire = fireMatch
function MatchService.announce(m: Match, title: string, sub: string?, color: Color3?, to: Player?)
	if to then announceEvent:FireClient(to, title, sub, color) else fireMatch(m, announceEvent, title, sub, color) end
end

-- ==========================================================================================
-- Apparition
-- ==========================================================================================
local function enemyPositions(m: Match, team: string): { Vector3 }
	local list = {}
	for _, c in ipairs(MatchService.combatants(m)) do
		local ch = aliveChar(c)
		local r = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
		if r and WeaponService.teamOf(c) ~= team then table.insert(list, r.Position) end
	end
	return list
end

-- point le plus éloigné des ennemis parmi ceux de l'équipe (et ceux du chacun pour soi une fois la partie lancée), comme spawnFor du web
function MatchService.spawnPoint(m: Match, c: any): Vector3
	if m.mod.spawnPoint then
		local p = m.mod.spawnPoint(m, c)
		if p then return p end
	end
	local team = WeaponService.teamOf(c) or ""
	local candidates = {}
	if m.teams and (team == TEAMS[1] or team == TEAMS[2]) then
		for _, p in ipairs(if team == TEAMS[1] then m.map.spawns.T else m.map.spawns.CT) do table.insert(candidates, p) end
		if m.state == "live" then for _, p in ipairs(m.map.spawns.DM) do table.insert(candidates, p) end end
	else
		for _, p in ipairs(m.map.spawns.DM) do table.insert(candidates, p) end
	end
	if #candidates == 0 then candidates = table.clone(m.roam) end
	local enemies = enemyPositions(m, team)
	local best, bestScore = candidates[math.random(#candidates)], -1
	for _ = 1, 8 do
		local cand = candidates[math.random(#candidates)]
		local minD = math.huge
		for _, e in ipairs(enemies) do minD = math.min(minD, (e - cand).Magnitude) end
		if minD > bestScore then best, bestScore = cand, minD end
	end
	return best
end

-- ---------- modificateurs de partie (web : src/8Y_mutators.js) ----------
local popEvent = ReplicatedStorage:FindFirstChild("ModePop") :: RemoteEvent?
if not popEvent then
	local e = Instance.new("RemoteEvent"); e.Name = "ModePop"; e.Parent = ReplicatedStorage; popEvent = e
end
local function mutOn(m: Match, k: string): boolean return m.settings.mut[k] == true end
local LUNE = 0.5     -- part de la gravité gardée en gravité lunaire
local TURBO = 1.3
-- appliqué à chaque apparition : gravité lunaire (force vers le haut sur le corps) et turbo (attribut lu par le mouvement)
local function applyMut(m: Match, char: Model)
	if mutOn(m, "turbo") then
		char:SetAttribute("SpeedMult", TURBO)
		local h = char:FindFirstChildOfClass("Humanoid")
		if h and isBot(char) then h.WalkSpeed *= TURBO end   -- le joueur, lui, applique le multiplicateur dans son mouvement
	end
	if mutOn(m, "lune") then
		char:SetAttribute("MutLune", true)
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and not root:FindFirstChild("MutLune") then
			local att = Instance.new("Attachment"); att.Name = "MutLuneAtt"; att.Parent = root
			local vf = Instance.new("VectorForce"); vf.Name = "MutLune"; vf.Attachment0 = att
			vf.RelativeTo = Enum.ActuatorRelativeTo.World; vf.ApplyAtCenterOfMass = true
			vf.Force = Vector3.new(0, root.AssemblyMass * workspace.Gravity * (1 - LUNE), 0)
			vf.Parent = root
			-- la masse change quand l'arme et les accessoires arrivent : on recalcule un peu plus tard
			task.delay(0.5, function() if vf.Parent then vf.Force = Vector3.new(0, root.AssemblyMass * workspace.Gravity * (1 - LUNE), 0) end end)
		end
	end
end
-- grenades et mines bloquées pendant « PRÉPAREZ-VOUS » et le début de manche (comme le web)
;(WeaponService :: any).throwBlocked = function(c: any): boolean
	local m = MatchService.matchOf(c)
	return m ~= nil and (m.state ~= "live" or (m.data :: any).phase == "freeze")
end
-- têtes seulement / une balle : filtre des dégâts de WeaponService (pas sur le couteau ni les grenades)
local NADES = { frag = true, flash = true, smoke = true, molotov = true, mine = true }
;(WeaponService :: any).damageFilter = function(attacker: any, victimChar: Model, raw: number, headshot: boolean, key: string): number?
	local m = MatchService.matchOf(attacker)
	if not m or m.state ~= "live" or MatchService.matchOf(victimChar) ~= m then return raw end
	local w = Config.WEAPONS[key]
	if (w and w.melee) or NADES[key] then return raw end
	if mutOn(m, "tetes") and not headshot then
		if typeof(attacker) == "Instance" and attacker:IsA("Player") and popEvent then popEvent:FireClient(attacker, "🎯 À LA TÊTE SEULEMENT", Color3.fromRGB(150, 200, 255), "shield") end
		return nil
	end
	if mutOn(m, "balle") then return 9999 end
	return raw
end

local function protect(char: Model)
	char:SetAttribute("ProtectedUntil", workspace:GetServerTimeNow() + TDM.spawnProtection)
	local h = Instance.new("Highlight"); h.Name = "SpawnShield"; h.FillColor = Color3.fromRGB(255, 255, 255)
	h.FillTransparency = 0.75; h.OutlineColor = Color3.fromRGB(140, 220, 255); h.Parent = char
	task.delay(TDM.spawnProtection, function() if h.Parent then h:Destroy() end end)
	char:GetAttributeChangedSignal("ProtectedUntil"):Connect(function()
		if (char:GetAttribute("ProtectedUntil") :: number? or 0) <= 0 and h.Parent then h:Destroy() end
	end)
end

local BOT_PRIMARIES = ModeConfig.BOT.primaries
function MatchService.defaultLoadout(m: Match, c: any): { string }
	local team = WeaponService.teamOf(c)
	local base = TDM.loadout[team or ""] or TDM.loadout.Attaquants
	if isBot(c) then
		return { BOT_PRIMARIES[math.random(#BOT_PRIMARIES)], base.secondary, "knife" }
	end
	local chosen, secondary = c:GetAttribute("Primary"), c:GetAttribute("Secondary")
	return { if typeof(chosen) == "string" then chosen else base.primary, if typeof(secondary) == "string" then secondary else base.secondary, "knife" }
end

local function loadoutOf(m: Match, c: any): { string }
	if m.mod.loadout then
		local l = m.mod.loadout(m, c)
		if l then return l end
	end
	return MatchService.defaultLoadout(m, c)
end

local function respawnDelay(m: Match, c: any): number
	if m.mod.respawnDelay then return m.mod.respawnDelay(m, c) end
	return m.def.respawn or TDM.respawnDelay
end
local function canRespawn(m: Match, c: any): boolean
	if m.mod.canRespawn then return m.mod.canRespawn(m, c) end
	return (m.def.respawn or 0) > 0
end

local spawnPlayer: (Match, Player) -> ()
spawnPlayer = function(m: Match, p: Player)
	if not p.Parent or matchOfPlayer[p] ~= m or m.closed then return end
	p:LoadCharacter()
	local char = p.Character or p.CharacterAdded:Wait()
	char:SetAttribute("MatchId", m.id)
	char:PivotTo(CFrame.new(MatchService.spawnPoint(m, p) + Vector3.new(0, 1, 0)))
	protect(char)
	WeaponService.giveLoadout(p, loadoutOf(m, p))
	statOf(m, p)
	applyMut(m, char)
	if m.mod.onSpawn then m.mod.onSpawn(m, p, char) end
	if m.state ~= "live" then
		local h = char:FindFirstChildOfClass("Humanoid"); if h and m.state == "warmup" then h.WalkSpeed = 0 end
	end
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	hum.Died:Connect(function()
		WeaponService.reset(p)
		if m.state ~= "live" or not canRespawn(m, p) then return end
		local delay = respawnDelay(m, p)
		task.delay(delay, function()
			-- la réapparition attend la fin de la kill-cam (comme sur le web), sans jamais dépasser KILLCAM_MAX
			local deadline = os.clock() + KILLCAM_MAX - delay
			while m.kcHold[p] and os.clock() < deadline do task.wait(0.1) end
			m.kcHold[p] = nil
			if m.state == "live" and p.Parent and p.Character == char and matchOfPlayer[p] == m and canRespawn(m, p) then spawnPlayer(m, p) end
		end)
	end)
end
function MatchService.respawn(m: Match, c: any)
	if isBot(c) then return end
	task.spawn(spawnPlayer, m, c)
end

local BOT_NO_NADES = { inf = true, zombies = true, br = true, train = true }   -- Infecté (couteau), Zombies, BR, Entraînement
local liveBots: (Match, string?) -> { Model }
local spawnBot: (Match, string, string?) -> Model
spawnBot = function(m: Match, team: string, name: string?): Model
	local model = BotService.spawn(if m.teams then team else "Attaquants", Vector3.zero, m.roam, name, {
		match = m.id, diff = Modes.DIFFS[m.settings.diff], loadout = { "knife" },
		goal = function(b: Model): Vector3? return if m.mod.botGoal then m.mod.botGoal(m, b) else nil end,
		-- grenades et mines des bots dans les modes à mort (les modes à manches les gèrent eux-mêmes, Modes/rounds)
		nades = m.def.respawn ~= nil and not BOT_NO_NADES[m.mode],
	})
	model:SetAttribute("Team", if m.teams then team else soloTeam(model))
	model:SetAttribute("Look", if m.teams then team else "ffa")
	model:PivotTo(CFrame.new(MatchService.spawnPoint(m, model) + Vector3.new(0, 3, 0)))
	WeaponService.giveLoadout(model, loadoutOf(m, model))
	protect(model)
	statOf(m, model)
	applyMut(m, model)
	if m.mod.onSpawn then m.mod.onSpawn(m, model, model) end
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local botName = model.Name
	hum.Died:Connect(function()
		task.delay(2, function() if model.Parent then BotService.remove(model) end end)
		if not canRespawn(m, model) then return end
		task.delay(respawnDelay(m, model), function()
			if m.state ~= "live" or m.closed then return end
			local s = m.stats["bot:" .. botName]
			-- ne réapparaît que s'il a toujours sa place (un joueur a pu le remplacer entre-temps)
			if not s then return end
			local group = if m.teams then s.team else nil
			local keep = if m.mod.botRespawn then m.mod.botRespawn(m, s) else #liveBots(m, group) < (m.botCount[group or "solo"] or 0)
			if keep then spawnBot(m, s.team, botName) end
		end)
	end)
	return model
end

-- Ajuste les bots pour que chaque équipe ait sa taille (ou que le chacun pour soi ait son nombre de joueurs)
local function humansIn(m: Match, team: string?): number
	local n = 0
	for p in pairs(m.players) do
		if not team or WeaponService.teamOf(p) == team then n += 1 end
	end
	return n
end
liveBots = function(m: Match, team: string?): { Model }
	local l = {}
	for _, b in ipairs(BotService.ofMatch(m.id)) do
		local h = b:FindFirstChildOfClass("Humanoid")
		if h and h.Health > 0 and (not team or b:GetAttribute("Team") == team) then table.insert(l, b) end
	end
	return l
end
function MatchService.balanceBots(m: Match)
	if m.state ~= "live" and m.state ~= "warmup" then return end
	if m.mod.noBots then return end
	local groups: { { string? } } = if m.teams then { { m.teams[1] }, { m.teams[2] } } else { { nil } }
	for _, g in ipairs(groups) do
		local team = g[1]
		local want: number? = math.max(0, m.settings.size - humansIn(m, team))
		if m.mod.botsWanted then want = m.mod.botsWanted(m, team, want) end
		if want == nil then continue end           -- le mode gère lui-même ses bots
		m.botCount[team or "solo"] = want
		local mine = liveBots(m, if m.teams then team else nil)
		while #mine > (want :: number) do
			local b = table.remove(mine) :: Model
			m.stats["bot:" .. b.Name] = nil
			BotService.remove(b)
		end
		for _ = #mine + 1, want :: number do spawnBot(m, team or "solo") end
	end
end
function MatchService.spawnBot(m: Match, team: string, name: string?): Model return spawnBot(m, team, name) end

-- ==========================================================================================
-- Objets à ramasser (bouclier, santé, munitions), comme makePickup() du web
-- ==========================================================================================
local PICKUP_COLORS = { shield = Color3.fromRGB(49, 200, 255), health = Color3.fromRGB(255, 74, 90), ammo = Color3.fromRGB(255, 210, 74) }

local function pickupPart(name: string, size: Vector3, color: Color3, cf: CFrame, parent: Instance, transparency: number?): Part
	local p = Instance.new("Part"); p.Name = name; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
	p.CastShadow = false; p.Size = size; p.Color = color; p.Material = Enum.Material.Neon; p.CFrame = cf
	p.Transparency = transparency or 0.08; p.Parent = parent
	return p
end

function MatchService.makePickup(m: Match, kind: string, pos: Vector3, temp: boolean)
	local col = PICKUP_COLORS[kind] or Color3.new(1, 1, 1)
	local model = Instance.new("Model"); model.Name = "Pickup_" .. kind
	model:SetAttribute("Pickup", kind)
	local corePos = pos + Vector3.new(0, 0.9 * U, 0)
	local core: Part
	if kind == "shield" then       -- octaèdre du web : un cube posé sur une pointe
		core = pickupPart("Core", Vector3.new(0.4, 0.4, 0.4) * U, col, CFrame.new(corePos) * CFrame.Angles(math.rad(45), 0, math.rad(35.26)), model)
	elseif kind == "health" then
		core = pickupPart("Core", Vector3.new(0.4, 0.4, 0.4) * U, col, CFrame.new(corePos), model)
		pickupPart("CrossA", Vector3.new(0.5, 0.12, 0.12) * U, Color3.new(1, 1, 1), CFrame.new(corePos), model, 0)
		pickupPart("CrossB", Vector3.new(0.12, 0.5, 0.12) * U, Color3.new(1, 1, 1), CFrame.new(corePos), model, 0)
	else
		core = pickupPart("Core", Vector3.new(0.5, 0.28, 0.32) * U, col, CFrame.new(corePos), model)
	end
	local light = Instance.new("PointLight"); light.Color = col; light.Range = 2.4 * U; light.Brightness = 1.6; light.Parent = core
	local ring = pickupPart("Ring", Vector3.new(0.04 * U, 1.3 * U, 1.3 * U), col, CFrame.new(pos + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)), model, 0.5)
	ring.Shape = Enum.PartType.Cylinder
	local zone = pickupPart("Zone", Vector3.new(2.6, 3, 2.6) * U, col, CFrame.new(pos + Vector3.new(0, 1.5 * U, 0)), model, 1)
	zone.CanTouch = true
	model.PrimaryPart = core
	model.Parent = m.map.folder
	if temp then
		table.insert(m.pickups, model)
		if #m.pickups > 6 then local old = table.remove(m.pickups, 1); if old and old.Parent then old:Destroy() end end
		task.delay(25, function() if model.Parent then model:Destroy() end end)
	end
	local ready = true
	local function setShown(on: boolean)
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and d.Name ~= "Zone" then d.Transparency = if on then (if d.Name == "Ring" then 0.5 elseif d.Name:sub(1, 5) == "Cross" then 0 else 0.08) else 1 end
		end
		light.Enabled = on
		model:SetAttribute("Ready", on)
	end
	model:SetAttribute("Ready", true)
	zone.Touched:Connect(function(hit)
		if not ready or m.state ~= "live" then return end
		local mm = hit:FindFirstAncestorOfClass("Model")
		local hum = mm and mm:FindFirstChildOfClass("Humanoid")
		if not mm or not hum or hum.Health <= 0 then return end
		local c = WeaponService.combatantOf(mm)
		if MatchService.matchOf(c) ~= m then return end
		if kind == "health" then
			if hum.Health >= hum.MaxHealth then return end
			hum.Health = math.min(hum.MaxHealth, hum.Health + 35)
		elseif kind == "shield" then
			if WeaponService.shieldOf(c) >= Config.SHIELD_MAX then return end
			WeaponService.addShield(c, 25)
		else
			WeaponService.resupply(c)
		end
		local pl = Players:GetPlayerFromCharacter(mm)
		if pl then pickupToast:FireClient(pl, kind) end
		if temp then model:Destroy(); return end
		ready = false; setShown(false)
		task.delay(20, function() if model.Parent then ready = true; setShown(true) end end)
	end)
end

-- bouclier lâché par un soldat éliminé (web : s'il en avait encore, ou 18 % du temps)
local function dropShield(m: Match, victim: any)
	if m.mod.noPickups then return end
	local char = WeaponService.charOf(victim)
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end
	if WeaponService.shieldOf(victim) > 0 or math.random() < 0.18 then
		local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = { (char :: any) :: Instance }
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -20, 0), rp)
		MatchService.makePickup(m, "shield", if hit then hit.Position else root.Position - Vector3.new(0, 3, 0), true)
	end
end

-- ==========================================================================================
-- Éliminations, dégâts, tirs
-- ==========================================================================================
function MatchService.weaponName(key: string): string
	if key == "frag" then return "Grenade" end
	if key == "bomb" then return "Bombe" end
	local w = Config.WEAPONS[key]
	return w and w.name or key
end

WeaponService.Damaged:Connect(function(attacker, victim, amount: number, _headshot: boolean)
	local m = MatchService.matchOf(attacker)
	if not m or m.state ~= "live" or MatchService.matchOf(victim) ~= m then return end
	local s = statOf(m, attacker)
	if s then s.dmg += amount; s.hits += 1 end
	local vk, ak = keyOf(victim), keyOf(attacker)
	local by = m.dmgBy[vk] or {}; m.dmgBy[vk] = by
	by[ak] = (by[ak] or 0) + amount
end)

WeaponService.ShotFired:Connect(function(shooter, _key: string)
	local m = MatchService.matchOf(shooter)
	if not m or m.state ~= "live" then return end
	local s = statOf(m, shooter)
	if s then s.shots += 1 end
end)

-- points d'une élimination (+25 à la tête), comme le web
local KILL_POINTS = TDM.scorePerKill
WeaponService.Killed:Connect(function(killer, victim, key: string, headshot: boolean)
	local m = MatchService.matchOf(victim)
	if not m or m.state ~= "live" then return end
	local vs = statOf(m, victim)
	if not vs then return end
	local ks = if MatchService.matchOf(killer) == m then statOf(m, killer) else nil
	dropShield(m, victim)
	vs.d += 1; vs.streak = 0
	local selfKill = ks == nil or ks == vs
	if ks and not selfKill then
		ks.k += 1; ks.streak += 1; ks.bestStreak = math.max(ks.bestStreak, ks.streak)
		ks.score += KILL_POINTS + (if headshot then 25 else 0)
		if headshot then ks.hs += 1 end
		ks.weaponKills[key] = (ks.weaponKills[key] or 0) + 1
	end
	-- le mode compte ses points lui-même (plaques, Mastodonte, Course aux armes…) ; sinon : 1 point par élimination
	local handled = m.mod.onKill and m.mod.onKill(m, killer, victim, key, headshot, ks, vs)
	if not handled and ks and not selfKill then
		local scoreKey = if m.teams then ks.team else ks.key
		m.score[scoreKey] = (m.score[scoreKey] or 0) + 1
	end
	-- assistances : au moins 30 dégâts sur la victime pendant cette vie
	local vk, kk = keyOf(victim), keyOf(killer)
	for ak, amount in pairs(m.dmgBy[vk] or {}) do
		local as = m.stats[ak]
		if ak ~= kk and as and amount >= 30 then as.a += 1; as.score += TDM.scorePerAssist end
	end
	m.dmgBy[vk] = nil
	-- vampire : chaque élimination rend 50 PV au tueur
	if mutOn(m, "vamp") and ks and not selfKill and ks.team ~= vs.team then
		local kc = aliveChar(killer)
		local h = kc and kc:FindFirstChildOfClass("Humanoid")
		if h then
			h.Health = math.min(math.max(100, h.MaxHealth), h.Health + 50)
			if typeof(killer) == "Instance" and killer:IsA("Player") and popEvent then popEvent:FireClient(killer, "🩸 +50 PV", Color3.fromRGB(255, 70, 80), "heal") end
		end
	end

	local kName = if ks then ks.name else vs.name
	fireMatch(m, feedEvent, { killer = kName, killerTeam = if ks then ks.team else vs.team, victim = vs.name, victimTeam = vs.team,
		weapon = MatchService.weaponName(key), key = key, headshot = headshot })
	local kp = ks and ks.player
	if kp and not selfKill and ks then
		bannerEvent:FireClient(kp, { victim = vs.name, headshot = headshot, points = KILL_POINTS + (if headshot then 25 else 0), streak = ks.streak, streakName = TDM.streaks[ks.streak] })
		RewardService.missionEvent(kp, "kills")
		if headshot then RewardService.missionEvent(kp, "hs") end
		if key == "knife" then RewardService.missionEvent(kp, "knife") end
	end
	local vp = vs.player
	if vp then
		deathEvent:FireClient(vp, { killer = kName, weapon = MatchService.weaponName(key), headshot = headshot,
			respawn = if canRespawn(m, vp) then respawnDelay(m, vp) else nil, killerChar = if ks then WeaponService.charOf(killer) else nil,
			victimName = vs.name, key = key, killcam = ks ~= nil and not selfKill })
	end
end)

killcamEvent.OnServerEvent:Connect(function(p: Player, on: any)
	local m = matchOfPlayer[p]
	if m then m.kcHold[p] = if on == true then true else nil end
end)

-- ==========================================================================================
-- État de la partie (score, temps, tableau Tab, ligne du mode) envoyé aux joueurs de la partie
-- ==========================================================================================
local function board(m: Match)
	local list = {}
	for _, s in pairs(m.stats) do
		table.insert(list, { name = s.name, team = s.team, bot = s.bot, k = s.k, d = s.d, a = s.a, score = s.score, pts = if m.teams then s.pts else (m.score[s.key] or s.pts),
			userId = s.player and s.player.UserId or 0, ping = if s.player then math.floor(NetService.pingOf(s.player) * 1000) else 0 })
	end
	table.sort(list, function(x, y) return x.score > y.score end)
	return list
end
MatchService.board = board

local function broadcast(m: Match)
	local info = if m.mod.info then m.mod.info(m) else nil
	-- modificateurs actifs ajoutés à la sous-ligne du mode, comme le web (« · 🌙 Gravité lunaire »)
	local muts = {}
	for _, mu in ipairs(Modes.MUTATORS) do if mutOn(m, mu.k) then table.insert(muts, mu.ic .. " " .. mu.n) end end
	if #muts > 0 then
		info = table.clone(info or {})
		info.sub = (if info.sub and info.sub ~= "" then info.sub .. "  ·  " else "") .. table.concat(muts, "  ")
	end
	local payload = {
		state = if m.state == "warmup" then "live" else m.state, warmup = m.state == "warmup", id = m.id, mode = m.mode, modeName = m.def.n,
		modeColor = m.def.c, team = m.teams ~= nil, score = if m.teams then m.score else {}, teams = m.teams or TEAMS, killsToWin = m.limit, limitLabel = m.def.limitLabel,
		timeLeft = if m.timed or m.state ~= "live" then math.max(0, math.floor(m.endsAt - os.clock())) else -1,
		mapName = m.map and m.map.data.name or "", mapId = m.settings.map, board = board(m), info = info, data = m.data.public,
	}
	fireMatch(m, stateEvent, payload)
end
MatchService.broadcast = broadcast

-- ==========================================================================================
-- Arrivées / départs
-- ==========================================================================================
local function teamCounts(m: Match): (number, number)
	local a, b = 0, 0
	for p in pairs(m.players) do
		local t = WeaponService.teamOf(p)
		if t == TEAMS[1] then a += 1 elseif t == TEAMS[2] then b += 1 end
	end
	return a, b
end

local function pickTeam(m: Match, p: Player, prefer: string?): string
	if m.mod.teamFor then
		local t = m.mod.teamFor(m, p)
		if t then return t end
	end
	if not m.teams then return soloTeam(p) end
	local a, b = teamCounts(m)
	if prefer == "t" and a < m.settings.size then return TEAMS[1] end
	if prefer == "ct" and b < m.settings.size then return TEAMS[2] end
	if a == b then return TEAMS[math.random(2)] end
	return if a < b then TEAMS[1] else TEAMS[2]
end

function MatchService.capacity(m: Match): number
	return if m.teams then m.settings.size * 2 else m.settings.size
end
local function humanCount(m: Match): number
	local n = 0; for _ in pairs(m.players) do n += 1 end; return n
end

local leaveLobby: ((Player) -> ())? = nil     -- branché par LobbyService (sortie du lobby)
local backToLobby: ((Player) -> ())? = nil
function MatchService.setLobbyHooks(onLeave: (Player) -> (), onBack: (Player) -> ())
	leaveLobby, backToLobby = onLeave, onBack
end

function MatchService.join(p: Player, m: Match, prefer: string?): boolean
	if m.closed or m.state == "over" or matchOfPlayer[p] == m then return false end
	if humanCount(m) >= MatchService.capacity(m) then return false end
	if matchOfPlayer[p] then MatchService.leave(p, true) end
	if leaveLobby then leaveLobby(p) end
	matchOfPlayer[p] = m
	m.players[p] = true
	p:SetAttribute("Zone", "match")
	p:SetAttribute("MatchId", m.id)
	p:SetAttribute("MatchMap", m.folderName)
	p:SetAttribute("MatchMode", m.mode)
	p.Team = nil
	MatchService.setTeam(m, p, pickTeam(m, p, prefer))
	statOf(m, p)
	if m.state == "live" or m.state == "warmup" then
		MatchService.balanceBots(m)
		task.spawn(spawnPlayer, m, p)
	end
	broadcast(m)
	return true
end

function MatchService.leave(p: Player, silent: boolean?)
	local m = matchOfPlayer[p]
	if not m then return end
	matchOfPlayer[p] = nil
	m.players[p] = nil
	m.kcHold[p] = nil
	m.stats[p] = nil
	if m.mod.onLeave then pcall(m.mod.onLeave, m, p) end
	WeaponService.reset(p)
	for _, a in ipairs({ "MatchId", "MatchMap", "MatchMode", "Team" }) do p:SetAttribute(a, nil) end
	if p.Character then p.Character:SetAttribute("MatchId", nil) end
	if not silent and p.Parent then
		p:SetAttribute("Zone", "lobby")
		if backToLobby then task.spawn(backToLobby, p) end
	end
	task.delay(0.3, function() MatchService.balanceBots(m) end)
end

-- ==========================================================================================
-- Déroulement d'une partie
-- ==========================================================================================
local function freeSlot(): number?
	local used = {}
	for _, m in pairs(matches) do used[m.slot] = true end
	for i = 1, MAX_MATCHES do if not used[i] then return i end end
	return nil
end

-- fonctions appelées pour chaque joueur à la fin d'une partie : (m, joueur, stat, gagné, résumé MatchEnd modifiable)
MatchService.finishHooks = {} :: { (Match, Player, Stat?, boolean, { [string]: any }) -> () }
local function finish(m: Match, winner: any)
	m.state = "over"
	broadcast(m)
	local seconds = math.floor(os.clock() - m.startedAt)
	local finalBoard = board(m)
	local mvp = finalBoard[1]
	for p in pairs(m.players) do
		local s = m.stats[p]
		local won: boolean
		if typeof(winner) == "string" then won = WeaponService.teamOf(p) == winner
		else won = winner ~= nil and s ~= nil and winner == s end
		local rewards, progress = nil, nil
		if s then
			local okR, r = pcall(RewardService.finishMatch, p, { kills = s.k, deaths = s.d, hs = s.hs, dmg = s.dmg, shots = s.shots, hits = s.hits,
				plants = (s :: any).plants or 0, defuses = (s :: any).defuses or 0, won = won, seconds = seconds, mode = m.mode, map = m.settings.map,
				bestStreak = s.bestStreak, weaponKills = s.weaponKills })
			if okR then rewards = r end
			if rewards then
				-- classement (rankUpdate du web) : partie classée, mode classé, bots Facile ou plus (diff web = diff - 1), sans modificateur
				local ranked = m.settings.ranked == true and next(m.settings.mut) == nil
				local okP, pr = pcall(ProgressService.finishMatch, p, { xp = rewards.xp, won = won, mode = m.mode, kills = s.k, weaponKills = s.weaponKills,
					ranked = ranked, difficulty = m.settings.diff - 1 })
				if okP then progress = pr end
			end
		end
		local winnerName = if typeof(winner) == "string" then winner elseif typeof(winner) == "table" then (winner :: any).name else nil
		local payload = { won = won, draw = winner == nil, winner = winnerName, team = m.teams ~= nil, mode = m.mode, modeName = m.def.n,
			score = if m.teams then m.score else {}, rewards = rewards, progress = progress, mvp = mvp, board = finalBoard,
			me = s and { k = s.k, d = s.d, a = s.a, hs = s.hs, dmg = s.dmg, score = s.score, bestStreak = s.bestStreak, shots = s.shots, hits = s.hits } or nil, next = INTERMISSION }
		-- médailles, défis de la semaine… (MatchService.finishHooks) : complètent le résumé avant l'envoi
		for _, hook in ipairs(MatchService.finishHooks) do
			local okH, errH = pcall(hook, m, p, s, won, payload)
			if not okH then warn("[MatchService] fin de partie :", errH) end
		end
		endEvent:FireClient(p, payload)
	end
	BotService.freezeMatch(m.id, true)
	for p in pairs(m.players) do
		local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid"); if h then h.WalkSpeed = 0 end
	end
end

local function close(m: Match)
	m.closed = true
	if m.mod.cleanup then pcall(m.mod.cleanup, m) end
	for p in pairs(m.players) do MatchService.leave(p) end
	BotService.removeMatch(m.id)
	if m.map then
		pcall(WeaponService.clearGrenades, m.id)
		if MapBuilder.destroy then pcall(MapBuilder.destroy, m.map) elseif m.map.folder then m.map.folder:Destroy() end
	end
	matches[m.id] = nil
end

local function playOnce(m: Match)
	-- carte, points de passage des bots, objets
	if m.map then
		pcall(WeaponService.clearGrenades, m.id)
		if MapBuilder.destroy then pcall(MapBuilder.destroy, m.map) elseif m.map.folder then m.map.folder:Destroy() end
	end
	BotService.removeMatch(m.id)
	m.map = (MapBuilder.build :: any)(m.settings.map, m.origin, m.folderName)
	m.map.folder:SetAttribute("MatchId", m.id); m.map.folder:SetAttribute("Origin", m.origin)
	m.roam = {}
	for _, c in ipairs(m.map.data.roam or {}) do table.insert(m.roam, MatchService.cellToWorld(m, c[1], c[2]) + Vector3.new(0, 3, 0)) end
	if #m.roam == 0 then m.roam = table.clone(m.map.spawns.DM) end
	m.stats = {}; m.dmgBy = {}; m.pickups = {}; m.data = {}; m.botCount = {}
	m.score = {}
	if m.teams then for _, t in ipairs(m.teams) do m.score[t] = 0 end end
	m.limit = m.settings.limit
	m.timed = m.def.time ~= nil
	if not m.mod.noPickups then
		for _, pk in ipairs(m.map.data.pickups or {}) do MatchService.makePickup(m, pk[3], MatchService.cellToWorld(m, pk[1], pk[2]), false) end
	end
	pcall(ProgressService.spawnPumpkins, m.map.data, function(cx: number, cz: number) return MatchService.cellToWorld(m, cx, cz) end, m.map.folder)
	if m.mod.setup then m.mod.setup(m) end

	-- équipes : on rebat les cartes à chaque partie, les groupes d'amis restent ensemble
	if m.teams then
		local list = {}
		for p in pairs(m.players) do table.insert(list, p) end
		local groups = PartyService.groupsOf(list)
		table.sort(groups, function(a, b) return #a > #b end)
		local counts = { 0, 0 }
		for _, g in ipairs(groups) do
			local i = if counts[1] <= counts[2] then 1 else 2
			for _, p in ipairs(g) do MatchService.setTeam(m, p, TEAMS[i]); counts[i] += 1 end
		end
		if m.host and m.players[m.host] and m.settings.side ~= "rnd" then
			MatchService.setTeam(m, m.host, if m.settings.side == "t" then TEAMS[1] else TEAMS[2])
		end
		if m.mod.teamFor then for p in pairs(m.players) do local t = m.mod.teamFor(m, p); if t then MatchService.setTeam(m, p, t) end end end
	else
		for p in pairs(m.players) do MatchService.setTeam(m, p, pickTeam(m, p)) end
	end

	-- « PRÉPAREZ-VOUS… » : tout le monde apparaît, puis la partie démarre
	m.state = "warmup"
	m.startedAt = os.clock(); m.endsAt = os.clock() + WARMUP
	for p in pairs(m.players) do task.spawn(spawnPlayer, m, p) end
	MatchService.balanceBots(m)
	BotService.freezeMatch(m.id, true)
	for _ = 1, WARMUP * 2 do task.wait(0.5); broadcast(m) end
	m.state = "live"
	BotService.freezeMatch(m.id, false)
	for p in pairs(m.players) do
		local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid"); if h then h.WalkSpeed = 16 end
	end
	m.startedAt = os.clock()
	m.endsAt = os.clock() + (m.def.time or 0)
	if m.mod.start then m.mod.start(m) end

	local winner: any = nil
	local done = false
	local last, sinceBroadcast = os.clock(), 0
	while not done do
		task.wait(0.1)
		if m.closed then return end
		local now = os.clock()
		local dt = now - last; last = now
		-- grenades à volonté : une frag revient toutes les 5 s
		if mutOn(m, "nades") then
			m.data._nadeT = (m.data._nadeT or 0) + dt
			if m.data._nadeT >= 5 then
				m.data._nadeT = 0
				for _, c in ipairs(MatchService.combatants(m)) do
					if aliveChar(c) and WeaponService.refillGrenade(c, "frag") and typeof(c) == "Instance" and c:IsA("Player") and popEvent then
						popEvent:FireClient(c, "💣 GRENADE RECHARGÉE", Color3.fromRGB(255, 210, 58))
					end
				end
			end
		end
		if m.mod.tick then
			local ok, err = pcall(m.mod.tick, m, dt)
			if not ok then warn("[MatchService] tick", m.mode, err) end
		end
		sinceBroadcast += dt
		if sinceBroadcast >= 0.5 then sinceBroadcast = 0; broadcast(m) end
		-- fin : limite atteinte (ou règle du mode), chrono écoulé, plus personne ; ou décision de l'admin (MatchService.forceEnd)
		if (m :: any).forced then
			(m :: any).forced = nil
			done = true
			if m.teams then
				local a, b = m.score[m.teams[1]] or 0, m.score[m.teams[2]] or 0
				winner = if a > b then m.teams[1] elseif b > a then m.teams[2] else nil
			else
				local best, bv = nil, -1
				for k, v in pairs(m.score) do if v > bv and m.stats[k] then best, bv = m.stats[k], v end end
				winner = best
			end
		elseif m.mod.checkEnd then
			local fin, w = m.mod.checkEnd(m)
			if fin then done, winner = true, w end
		elseif m.limit then
			for k, v in pairs(m.score) do
				if v >= m.limit then done = true; winner = if m.teams then k else m.stats[k] end
			end
		end
		if not done and m.timed and now >= m.endsAt then
			done = true
			if m.mod.timeUp then winner = m.mod.timeUp(m)
			elseif m.teams then
				local a, b = m.score[m.teams[1]] or 0, m.score[m.teams[2]] or 0
				winner = if a > b then m.teams[1] elseif b > a then m.teams[2] else nil
			else
				local best, bv = nil, -1
				for k, v in pairs(m.score) do if v > bv and m.stats[k] then best, bv = m.stats[k], v end end
				winner = best
			end
		end
		if humanCount(m) == 0 then return end
	end
	finish(m, winner)
	m.state = "intermission"
	m.endsAt = os.clock() + INTERMISSION
	for _ = 1, INTERMISSION * 2 do task.wait(0.5); if m.closed then return end; broadcast(m) end
end

local function run(m: Match)
	while not m.closed do
		local ok, err = pcall(playOnce, m)
		if not ok then warn("[MatchService] partie interrompue :", err); task.wait(2) end
		if humanCount(m) == 0 then break end
		if m.mod.cleanup then pcall(m.mod.cleanup, m) end
	end
	close(m)
end

function MatchService.create(settings: any, host: Player?): Match?
	local s = Modes.sanitize(settings)
	local slot = freeSlot()
	if not slot then return nil end
	local id = nextId; nextId += 1
	local def = Modes.LIST[s.mode]
	local m: Match = {
		id = id, slot = slot, settings = s, def = def, mode = s.mode, mod = modeModule(s.mode),
		map = nil, origin = SLOT_ORIGIN + Vector3.new((slot - 1) * SLOT_SPACING, 0, 0), folderName = "Match_" .. id, roam = {},
		state = "loading", teams = if def.team then table.clone(TEAMS) else nil, score = {}, limit = s.limit, endsAt = 0, startedAt = 0, timed = def.time ~= nil,
		players = {}, stats = {}, dmgBy = {}, kcHold = {}, host = host, data = {}, botCount = {}, closed = false, pickups = {},
	}
	matches[id] = m
	return m
end

-- termine la partie tout de suite (panneau admin) : le meilleur score gagne, comme à la fin du chrono
function MatchService.forceEnd(m: Match)
	if m.state == "live" then (m :: any).forced = true end
end

function MatchService.start(m: Match)
	task.spawn(run, m)
end

-- Parties qu'on peut rejoindre, pour le menu
function MatchService.list(): { any }
	local l = {}
	for _, m in pairs(matches) do
		if not m.closed and not m.settings.private then
			table.insert(l, { id = m.id, mode = m.mode, modeName = m.def.n, map = m.settings.map, mapName = Modes.MAP[m.settings.map] and Modes.MAP[m.settings.map].n or m.settings.map,
				players = humanCount(m), max = MatchService.capacity(m), state = m.state, diff = m.settings.diff,
				timeLeft = if m.timed then math.max(0, math.floor(m.endsAt - os.clock())) else -1, host = m.host and m.host.DisplayName or "" })
		end
	end
	table.sort(l, function(a, b) return a.players > b.players end)
	return l
end

-- Lancer une partie avec ses réglages : le joueur et les membres de son groupe y entrent
function MatchService.hostFor(p: Player, settings: any): (boolean, string?)
	if not PartyService.isLeader(p) then return false, "Seul le chef du groupe lance la partie" end
	local m = MatchService.create(settings, p)
	if not m then return false, "Serveur plein : rejoins une partie en cours" end
	local group = PartyService.membersOf(p)
	for _, q in ipairs(group) do
		if q.Parent then
			matchOfPlayer[q] = nil
			MatchService.join(q, m, if q == p then m.settings.side else nil)
		end
	end
	MatchService.start(m)
	return true, nil
end

-- Partie rapide : une partie publique d'un mode rapide où il reste de la place, sinon une nouvelle
function MatchService.quick(p: Player, mode: string?): (boolean, string?)
	local best: Match? = nil
	for _, m in pairs(matches) do
		if not m.closed and not m.settings.private and m.state ~= "over" and (mode == nil or m.mode == mode)
			and table.find(Modes.QUICK, m.mode) and humanCount(m) < MatchService.capacity(m) then
			if not best or humanCount(m) > humanCount(best) then best = m end
		end
	end
	if best and MatchService.join(p, best) then return true, nil end
	local pick = mode or Modes.QUICK[math.random(#Modes.QUICK)]
	local maps = Modes.mapsFor(pick)
	return MatchService.hostFor(p, { mode = pick, map = maps[math.random(#maps)], diff = 3 })
end

createFn.OnServerInvoke = function(p: Player, settings: any)
	if p:GetAttribute("DuelQueued") or p:GetAttribute("Zone") == "duel" then return false, "Termine ton duel d'abord" end
	return MatchService.hostFor(p, settings)
end
quickFn.OnServerInvoke = function(p: Player, mode: any)
	if p:GetAttribute("DuelQueued") or p:GetAttribute("Zone") == "duel" then return false, "Termine ton duel d'abord" end
	return MatchService.quick(p, if typeof(mode) == "string" and Modes.LIST[mode] then mode else nil)
end
joinFn.OnServerInvoke = function(p: Player, id: any)
	local m = if typeof(id) == "number" then matches[id] else nil
	if not m or m.settings.private then return false, "Cette partie n'existe plus" end
	if MatchService.join(p, m) then return true, nil end
	return false, "Partie pleine"
end
leaveFn.OnServerInvoke = function(p: Player)
	if not matchOfPlayer[p] then return false end
	MatchService.leave(p)
	return true
end
listFn.OnServerInvoke = function(_p: Player) return MatchService.list() end

-- arme principale (slot 0) ou pistolet (slot 1) ; gardé dans le profil, appliqué à la prochaine apparition
loadoutFn.OnServerInvoke = function(player: Player, key: any)
	if typeof(key) ~= "string" then return false end
	local w = Config.WEAPONS[key]
	if not w or (w.slot ~= 0 and w.slot ~= 1) then return false end
	local profile = DataService.get(player)
	if not ShopCatalog.STARTER_WEAPONS[key] and not (profile and ShopCatalog.ownsWeapon(profile, key)) then return false end
	player:SetAttribute(if w.slot == 0 then "Primary" else "Secondary", key)   -- repris aussi par les duels et le stand de tir du lobby
	if profile then
		profile.loadout = profile.loadout or {}
		profile.loadout[if w.slot == 0 then "primary" else "secondary"] = key
	end
	return true
end

Players.PlayerRemoving:Connect(function(p) MatchService.leave(p, true) end)

return MatchService
