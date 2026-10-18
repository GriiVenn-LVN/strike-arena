--!strict
-- ServerScriptService/AdminService (ModuleScript, requis par Main)
-- Panneau admin du jeu web (src/8M_admin.js, PR #14 / #22 / #26), version Roblox :
--   • Accès : seulement le propriétaire du jeu (créateur, ou propriétaire du groupe qui publie le jeu) ou un compte de
--     AdminConfig.USER_IDS, ET après avoir tapé le code d'AdminConfig.CODE. Tout est vérifié ici, sur le serveur :
--     un joueur normal ne peut rien faire, même en trafiquant son client. Attributs du joueur : AdminEligible (le client
--     peut proposer la saisie du code), AdminUnlocked (code accepté).
--   • Joueurs : expulser, bannir (jusqu'à la fermeture du serveur), rendre muet, tuer, soigner, faire réapparaître,
--     changer d'équipe, geler, ajouter / retirer des bots, figer les bots.
--   • Partie : terminer, +1 minute, annonce à tous.
--   • Donner (son propre profil) : tout débloquer, pièces, niveaux, caisses.
--   • Triche : immortel, balles et grenades infinies, prendre une arme. Vision à travers les murs et visée auto (côté
--     client, AdminController). Comme sur le web, tout cela est COUPÉ dès que des joueurs humains sont en face (en
--     ligne contre d'autres joueurs) ; la vision reste permise en spectateur (admin éliminé).
--   • Journal : arrivées, départs, éliminations, discussion, actions admin.
-- Remote : AdminRequest (RemoteFunction) : (action, a, b) -> résultat.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Config = require(ReplicatedStorage.Shared.Config)
local AdminConfig = require(script.Parent.AdminConfig)
local DataService = require(script.Parent.DataService)
local RewardService = require(script.Parent.RewardService)
local WeaponService = require(script.Parent.WeaponService)
local BotService = require(script.Parent.BotService)
local MatchService = require(script.Parent.MatchService)
local NetService = require(script.Parent.NetService)

local AdminService = {}

local request = Instance.new("RemoteFunction"); request.Name = "AdminRequest"; request.Parent = ReplicatedStorage

type Flags = { god: boolean, ammo: boolean, nades: boolean }
local unlocked: { [Player]: boolean } = {}
local flags: { [Player]: Flags } = {}
local tries: { [Player]: { number } } = {}
local banned: { [number]: string } = {}
local muted: { [number]: boolean } = {}
local frozen: { [number]: boolean } = {}
local botsFrozen: { [number]: boolean } = {}
local log: { { t: string, txt: string, col: string } } = {}

local function addLog(txt: string, col: string?)
	table.insert(log, { t = os.date("%H:%M:%S") :: string, txt = txt, col = col or "" })
	while #log > 150 do table.remove(log, 1) end
end
AdminService.log = addLog

-- ---------- droits ----------
local ownerCache: { [Player]: boolean } = {}
function AdminService.isEligible(p: Player): boolean
	if ownerCache[p] ~= nil then return ownerCache[p] end
	local ok = false
	if table.find(AdminConfig.USER_IDS, p.UserId) then ok = true
	elseif game.CreatorType == Enum.CreatorType.User then ok = game.CreatorId ~= 0 and p.UserId == game.CreatorId
	elseif game.CreatorType == Enum.CreatorType.Group then
		local s, rank = pcall(function() return p:GetRankInGroup(game.CreatorId) end)
		ok = s and rank == 255
	end
	if not ok and AdminConfig.STUDIO and RunService:IsStudio() then ok = true end
	ownerCache[p] = ok
	return ok
end
local function isAdmin(p: Player): boolean
	return unlocked[p] == true and AdminService.isEligible(p)
end
AdminService.isAdmin = isAdmin

local function norm(code: string): string
	return (string.gsub(string.upper(code), "[^A-Z0-9]", ""))
end

-- des joueurs humains sont-ils en face ? (admHumansFacing du web)
local function humansFacing(p: Player): boolean
	if p:GetAttribute("Zone") == "duel" then return true end
	local m = MatchService.matchOf(p)
	if not m then return false end
	local mine = WeaponService.teamOf(p)
	for q in pairs(m.players) do
		if q ~= p and (not m.teams or WeaponService.teamOf(q) ~= mine) then return true end
	end
	return false
end
local function aliveChar(c: any): Model? return MatchService.aliveChar(c) end
-- '' = triche permise, sinon la raison (admCheatWhy / admVisionWhy / admAimWhy du web)
local function cheatWhy(p: Player): string
	if not MatchService.matchOf(p) then return "Lance une partie pour l'utiliser" end
	if humansFacing(p) then return "Des joueurs humains sont en face : coupé pour ne pas fausser leur partie" end
	return ""
end
local function visionWhy(p: Player): string
	if not MatchService.matchOf(p) then return "Lance une partie pour l'utiliser" end
	if not aliveChar(p) then return "" end
	if humansFacing(p) then return "Des joueurs humains sont en face : la vision ne marche qu'en spectateur (quand tu es éliminé)" end
	return ""
end
local function aimWhy(p: Player): string
	if not MatchService.matchOf(p) then return "Lance une partie pour l'utiliser" end
	if not aliveChar(p) then return "Tu es éliminé" end
	if humansFacing(p) then return "Des joueurs humains sont en face : la visée auto est coupée pour ne pas fausser leur partie" end
	return ""
end
AdminService.cheatWhy = cheatWhy

-- ---------- immortel, gel (filtre de dégâts et de grenades de WeaponService) ----------
local prevFilter = (WeaponService :: any).damageFilter
;(WeaponService :: any).damageFilter = function(attacker: any, victimChar: Model, raw: number, headshot: boolean, key: string): number?
	if typeof(attacker) == "Instance" and attacker:IsA("Player") and frozen[attacker.UserId] then return nil end
	local vp = Players:GetPlayerFromCharacter(victimChar)
	if vp and isAdmin(vp) and flags[vp] and flags[vp].god and cheatWhy(vp) == "" then return nil end
	if prevFilter then return prevFilter(attacker, victimChar, raw, headshot, key) end
	return raw
end
local prevThrow = (WeaponService :: any).throwBlocked
;(WeaponService :: any).throwBlocked = function(c: any): boolean
	if typeof(c) == "Instance" and c:IsA("Player") and frozen[c.UserId] then return true end
	return if prevThrow then prevThrow(c) else false
end

local function applyFreeze(p: Player)
	local ch = p.Character
	local root = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	local on = frozen[p.UserId] == true
	if ch then ch:SetAttribute("AdminFrozen", if on then true else nil) end
	if root then root.Anchored = on end
end

-- ---------- muet (TextChatService) ----------
local function applyMute(p: Player)
	local on = muted[p.UserId] == true
	pcall(function()
		for _, ch in ipairs(TextChatService:GetDescendants()) do
			if ch:IsA("TextChannel") then
				local src = ch:FindFirstChild(p.Name)
				if src and src:IsA("TextSource") then src.CanSend = not on end
			end
		end
	end)
end

-- ---------- combattants de la partie de l'admin ----------
local function keyOfC(c: any): string
	if typeof(c) == "Instance" and c:IsA("Player") then return "p:" .. c.UserId end
	return "b:" .. c.Name
end
local function findC(m: any, key: any): any
	if typeof(key) ~= "string" then return nil end
	for _, c in ipairs(MatchService.combatants(m)) do if keyOfC(c) == key then return c end end
	return nil
end

local function rows(admin: Player): { any }
	local list = {}
	local m = MatchService.matchOf(admin)
	if m then
		for _, c in ipairs(MatchService.combatants(m)) do
			local s = MatchService.statOf(m, c)
			local ch = aliveChar(c)
			local h = ch and ch:FindFirstChildOfClass("Humanoid")
			local isP = typeof(c) == "Instance" and c:IsA("Player")
			table.insert(list, { key = keyOfC(c), name = WeaponService.nameOf(c), kind = if c == admin then "me" elseif isP then "player" else "bot",
				team = WeaponService.teamOf(c) or "", k = s and s.k or 0, d = s and s.d or 0, hp = if h then math.floor(h.Health + 0.5) else 0, alive = h ~= nil,
				ping = if isP then math.floor(NetService.pingOf(c) * 1000) else nil, userId = if isP then c.UserId else nil,
				frozen = if isP then frozen[c.UserId] == true else c:GetAttribute("Frozen") == true, muted = isP and muted[c.UserId] == true })
		end
	else
		for _, q in ipairs(Players:GetPlayers()) do
			table.insert(list, { key = "p:" .. q.UserId, name = q.DisplayName, kind = if q == admin then "me" else "player", team = "", k = 0, d = 0, hp = 0, alive = false,
				ping = math.floor(NetService.pingOf(q) * 1000), userId = q.UserId, frozen = frozen[q.UserId] == true, muted = muted[q.UserId] == true, zone = q:GetAttribute("Zone") })
		end
	end
	return list
end

local function gameInfo(admin: Player): any
	local m = MatchService.matchOf(admin)
	if not m then return nil end
	local humans = 0
	for _ in pairs(m.players) do humans += 1 end
	return { mode = m.def.n, map = m.map and m.map.data.name or m.settings.map, state = m.state, team = m.teams ~= nil, score = m.score, teams = m.teams,
		limit = m.limit, timeLeft = if m.timed then math.max(0, math.floor(m.endsAt - os.clock())) else -1, humans = humans, botsFrozen = botsFrozen[m.id] == true,
		phase = m.data and m.data.phase, round = m.data and m.data.round }
end

local function profileInfo(p: Player): any
	local profile = DataService.get(p)
	if not profile then return nil end
	local level = RewardService.levelInfo(profile)
	return { level = level, coins = profile.coins, boxes = (profile.boxes.std or 0) + (profile.boxes.prem or 0) }
end

-- ---------- donner (profil de l'admin seulement) ----------
local function giveAll(p: Player): string
	local profile = DataService.get(p)
	if not profile then return "Profil pas chargé" end
	local n = 0
	for w in pairs(Config.WEAPONS) do
		local owned = profile.inv.skins[w] or {}
		for i = 2, #Config.SKINS do if not table.find(owned, i) then table.insert(owned, i); n += 1 end end
		profile.inv.skins[w] = owned
	end
	profile.inv.outfits = profile.inv.outfits or {}
	for i = 2, #Config.OUTFITS do if not table.find(profile.inv.outfits, i) then table.insert(profile.inv.outfits, i); n += 1 end end
	for id in pairs(Config.DANCES) do if not table.find(profile.inv.dances, id) then table.insert(profile.inv.dances, id); n += 1 end end
	local KillFxConfig = require(ReplicatedStorage.Shared.KillFxConfig)
	profile.inv.killfx = profile.inv.killfx or {}
	for _, f in ipairs(KillFxConfig.LIST) do if f.id ~= "none" and not table.find(profile.inv.killfx, f.id) then table.insert(profile.inv.killfx, f.id); n += 1 end end
	local okP, ProgressService = pcall(require, script.Parent.ProgressService)
	if okP then
		local X = require(ReplicatedStorage.Shared.ConfigExtra)
		ProgressService.ensure(profile)
		profile.bp.premium = true
		profile.bp.xp = math.max(profile.bp.xp, X.SEASON.tiers * X.SEASON.xpPerTier)
	end
	profile.adminAll = true
	DataService.syncSkins(p)
	return "Tout débloqué (" .. n .. " objets, passe de combat premium au max)"
end
local function giveLevels(p: Player, n: number): string
	local profile = DataService.get(p)
	if not profile then return "Profil pas chargé" end
	local level, cur, need = RewardService.levelInfo(profile)
	local x = need - cur
	for l = level + 1, level + n - 1 do x += Config.xpNeeded(l) end
	RewardService.addXP(p, x)
	return "+" .. n .. " niveau" .. (if n > 1 then "x" else "") .. " (niveau " .. (RewardService.levelInfo(profile)) .. ")"
end

-- ---------- actions ----------
local function targetPlayer(a: any): Player?
	local id = tonumber(a)
	return if id then Players:GetPlayerByUserId(id) else nil
end

local ACTIONS: { [string]: (Player, any, any) -> any } = {}

ACTIONS.state = function(p, withLog)
	local f = flags[p] or { god = false, ammo = false, nades = false }
	local bl = {}
	for id, name in pairs(banned) do table.insert(bl, { userId = id, name = name }) end
	return { players = rows(p), game = gameInfo(p), flags = f, cheatWhy = cheatWhy(p), visionWhy = visionWhy(p), aimWhy = aimWhy(p),
		banned = bl, profile = profileInfo(p), log = if withLog then log else nil, inMatch = MatchService.matchOf(p) ~= nil }
end
ACTIONS.lock = function(p)
	unlocked[p] = nil; flags[p] = nil
	p:SetAttribute("AdminUnlocked", nil)
	return true
end
-- modération
ACTIONS.kick = function(p, a)
	local q = targetPlayer(a)
	if not q or q == p then return false end
	addLog(q.Name .. " expulsé", "#ff6b6b")
	q:Kick("L'administrateur t'a expulsé du serveur")
	return true
end
ACTIONS.ban = function(p, a)
	local q = targetPlayer(a)
	if not q or q == p then return false end
	banned[q.UserId] = q.Name
	addLog(q.Name .. " banni", "#ff6b6b")
	q:Kick("L'administrateur t'a banni de ce serveur")
	return true
end
ACTIONS.unban = function(_p, a)
	local id = tonumber(a)
	if not id or not banned[id] then return false end
	addLog(banned[id] .. " débanni")
	banned[id] = nil
	return true
end
ACTIONS.mute = function(_p, a)
	local q = targetPlayer(a)
	if not q then return false end
	muted[q.UserId] = not muted[q.UserId]
	applyMute(q)
	addLog(q.Name .. (if muted[q.UserId] then " rendu muet" else " peut de nouveau écrire"), "#ffb36b")
	return true
end
-- personnages de la partie
ACTIONS.kill = function(p, key)
	local m = MatchService.matchOf(p); local c = m and findC(m, key)
	local ch = c and aliveChar(c)
	local h = ch and ch:FindFirstChildOfClass("Humanoid")
	if not h or not ch then return false end
	ch:SetAttribute("ProtectedUntil", 0)
	WeaponService.applyDamage(nil, ch, 1e6, false, "knife", 1)
	if h.Health > 0 then h.Health = 0 end
	addLog(WeaponService.nameOf(c) .. " éliminé par l'admin", "#ffb36b")
	return true
end
ACTIONS.heal = function(p, key)
	local m = MatchService.matchOf(p); local c = m and findC(m, key)
	local ch = c and aliveChar(c)
	local h = ch and ch:FindFirstChildOfClass("Humanoid")
	if not h then return false end
	h.Health = h.MaxHealth
	WeaponService.setArmor(c, 100)
	addLog(WeaponService.nameOf(c) .. " soigné")
	return true
end
ACTIONS.revive = function(p, key)
	local m = MatchService.matchOf(p); local c = m and findC(m, key)
	if not m or not c or aliveChar(c) then return false end
	if typeof(c) == "Instance" and c:IsA("Player") then MatchService.respawn(m, c); addLog(c.Name .. " réapparu"); return true end
	return false
end
ACTIONS.team = function(p, key)
	local m = MatchService.matchOf(p); local c = m and findC(m, key)
	if not m or not c or not m.teams then return false end
	local cur = WeaponService.teamOf(c)
	local other = if cur == m.teams[1] then m.teams[2] else m.teams[1]
	MatchService.setTeam(m, c, other)
	if typeof(c) == "Instance" and c:IsA("Player") then
		MatchService.respawn(m, c)
	else
		c:SetAttribute("Look", other)
		local h = c:FindFirstChildOfClass("Humanoid"); if h then h.Health = 0 end   -- réapparaît dans sa nouvelle équipe
	end
	addLog(WeaponService.nameOf(c) .. " passe chez les " .. other)
	return true
end
ACTIONS.freeze1 = function(p, key)
	local m = MatchService.matchOf(p); local c = m and findC(m, key)
	if not c or c == p then return false end
	if typeof(c) == "Instance" and c:IsA("Player") then
		frozen[c.UserId] = not frozen[c.UserId]
		applyFreeze(c)
		addLog(c.Name .. (if frozen[c.UserId] then " gelé" else " dégelé"), "#9fe3ff")
	else
		local on = not c:GetAttribute("Frozen")
		c:SetAttribute("Frozen", if on then true else nil)
		local h = c:FindFirstChildOfClass("Humanoid"); if h then h:Move(Vector3.zero); h.WalkSpeed = if on then 0 else 15 end
		addLog(c.Name .. (if on then " gelé" else " dégelé"), "#9fe3ff")
	end
	return true
end
ACTIONS.rmbot = function(p, key)
	local m = MatchService.matchOf(p); local c = m and findC(m, key)
	if not m or not c or not BotService.isBot(c) then return false end
	local team = WeaponService.teamOf(c)
	local group = if m.teams then team or "solo" else "solo"
	m.botCount[group] = math.max(0, (m.botCount[group] or 1) - 1)
	m.stats["bot:" .. c.Name] = nil
	addLog("Bot " .. c.Name .. " retiré")
	BotService.remove(c)
	return true
end
ACTIONS.addbot = function(p, team)
	local m = MatchService.matchOf(p)
	if not m or (m.state ~= "live" and m.state ~= "warmup") then return false end
	local t = if m.teams then (if team == m.teams[2] then m.teams[2] else m.teams[1]) else "solo"
	local group = if m.teams then t else "solo"
	m.botCount[group] = (m.botCount[group] or 0) + 1
	local b = MatchService.spawnBot(m, t)
	if botsFrozen[m.id] then BotService.freezeMatch(m.id, true) end
	addLog("Bot " .. b.Name .. " ajouté" .. (if m.teams then " (" .. t .. ")" else ""))
	return true
end
ACTIONS.freeze = function(p)
	local m = MatchService.matchOf(p)
	if not m then return false end
	botsFrozen[m.id] = not botsFrozen[m.id]
	BotService.freezeMatch(m.id, botsFrozen[m.id] == true)
	addLog(if botsFrozen[m.id] then "Bots figés" else "Bots libérés")
	return true
end
-- partie
ACTIONS.endmatch = function(p)
	local m = MatchService.matchOf(p)
	if not m then return false end
	MatchService.forceEnd(m)
	addLog("Partie terminée par l'admin", "#ffb36b")
	return true
end
ACTIONS.time = function(p)
	local m = MatchService.matchOf(p)
	if not m then return false end
	if m.timed then m.endsAt += 60 end
	if m.data and typeof(m.data.phaseEnd) == "number" and m.data.phaseEnd < math.huge then m.data.phaseEnd += 60 end
	addLog("+1 minute")
	return true
end
ACTIONS.announce = function(_p, txt)
	if typeof(txt) ~= "string" then return false end
	local t = string.sub((string.gsub(txt, "^%s+", "")), 1, 90)
	if t == "" then return false end
	local ann = ReplicatedStorage:FindFirstChild("MatchAnnounce") :: RemoteEvent?
	if ann then ann:FireAllClients("ANNONCE", t, Color3.fromRGB(255, 215, 94)) end
	addLog("Annonce : " .. t, "#ffd75e")
	return true
end
-- donner
ACTIONS.giveall = function(p) local r = giveAll(p); addLog(r, "#7dff9f"); return r end
ACTIONS.coins = function(p, n)
	local v = tonumber(n)
	local profile = DataService.get(p)
	if not v or not profile or v <= 0 or v > 1e6 then return false end
	profile.coins += math.floor(v)
	addLog("+" .. math.floor(v) .. " pièces", "#7dff9f")
	return "+" .. math.floor(v) .. " pièces"
end
ACTIONS.lvl = function(p, n)
	local v = tonumber(n)
	if not v or v < 1 or v > 100 then return false end
	local r = giveLevels(p, math.floor(v)); addLog(r, "#7dff9f"); return r
end
ACTIONS.boxes = function(p)
	local profile = DataService.get(p)
	if not profile then return false end
	profile.boxes.std = (profile.boxes.std or 0) + 5; profile.boxes.prem = (profile.boxes.prem or 0) + 5
	addLog("+5 caisses standard et +5 premium", "#7dff9f")
	return "+5 caisses standard et +5 premium"
end
-- triches (coupées contre des humains)
local function toggle(name: string)
	return function(p: Player)
		local f = flags[p] or { god = false, ammo = false, nades = false }
		flags[p] = f
		local ff = f :: any
		ff[name] = not ff[name]
		addLog(({ god = "Immortel", ammo = "Balles infinies", nades = "Grenades infinies" } :: any)[name] .. (if ff[name] then " activé" else " coupé"))
		return true
	end
end
ACTIONS.god = toggle("god")
ACTIONS.ammo = toggle("ammo")
ACTIONS.nades = toggle("nades")
ACTIONS.weapon = function(p, key)
	if typeof(key) ~= "string" or cheatWhy(p) ~= "" or not aliveChar(p) then return false end
	local w = Config.WEAPONS[key]
	if not w or w.melee or (w.slot ~= 0 and w.slot ~= 1) then return false end
	local prim = p:GetAttribute("Primary"); local sec = p:GetAttribute("Secondary")
	local keys = if w.slot == 0 then { key, if typeof(sec) == "string" then sec else "glock", "knife" } else { if typeof(prim) == "string" then prim else "ak", key, "knife" }
	WeaponService.giveLoadout(p, keys)
	addLog("Arme prise : " .. w.name)
	return true
end
ACTIONS.clearlog = function() table.clear(log); return true end

request.OnServerInvoke = function(p: Player, action: any, a: any, b: any): any
	if typeof(action) ~= "string" then return nil end
	if not AdminService.isEligible(p) then return nil end            -- joueur normal : rien, jamais
	if action == "unlock" then
		local now = os.clock()
		local list = tries[p] or {}; tries[p] = list
		while list[1] and now - list[1] > 60 do table.remove(list, 1) end
		if #list >= AdminConfig.MAX_TRIES then return { ok = false, err = "Trop d'essais : réessaie dans une minute" } end
		table.insert(list, now)
		if typeof(a) ~= "string" or norm(a) == "" or norm(a) ~= norm(AdminConfig.CODE) then return { ok = false, err = "Code incorrect" } end
		unlocked[p] = true
		p:SetAttribute("AdminUnlocked", true)
		addLog("Accès admin ouvert par " .. p.Name, "#7dff9f")
		return { ok = true }
	end
	if not isAdmin(p) then return nil end
	local fn = ACTIONS[action]
	if not fn then return nil end
	local ok, res = pcall(fn, p, a, b)
	if not ok then warn("[AdminService]", action, res); return nil end
	return res
end

-- ---------- boucle : balles / grenades infinies, immortel ----------
task.spawn(function()
	while true do
		task.wait(0.4)
		for p, f in pairs(flags) do
			if p.Parent and isAdmin(p) and aliveChar(p) and cheatWhy(p) == "" then
				if f.ammo then WeaponService.fillMags(p) end
				if f.nades then for _, k in ipairs({ "frag", "flash", "smoke", "mine" }) do WeaponService.refillGrenade(p, k) end end
				if f.god then
					local h = (aliveChar(p) :: Model):FindFirstChildOfClass("Humanoid")
					if h and h.Health < 100 then h.Health = math.max(h.Health, math.min(100, h.MaxHealth)) end
				end
			end
		end
	end
end)

-- ---------- journal ----------
local function hookPlayer(p: Player)
	if banned[p.UserId] then p:Kick("Tu es banni de ce serveur"); addLog(p.Name .. " (banni) a essayé de revenir", "#ff6b6b"); return end
	addLog(p.Name .. " a rejoint le serveur", "#7dff9f")
	if AdminService.isEligible(p) then p:SetAttribute("AdminEligible", true) end
	p.Chatted:Connect(function(msg) table.insert(log, { t = "💬", txt = p.Name .. " : " .. msg, col = "#9fe3ff" }); while #log > 150 do table.remove(log, 1) end end)
	p.CharacterAdded:Connect(function()
		task.defer(function() applyFreeze(p); applyMute(p) end)
	end)
end
Players.PlayerAdded:Connect(hookPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(hookPlayer, p) end
Players.PlayerRemoving:Connect(function(p: Player)
	addLog(p.Name .. " a quitté le serveur", "#ffb36b")
	unlocked[p] = nil; flags[p] = nil; tries[p] = nil; ownerCache[p] = nil
end)
WeaponService.Killed:Connect(function(killer, victim, key: string, headshot: boolean)
	if not MatchService.matchOf(victim) then return end
	local vn = WeaponService.nameOf(victim)
	if killer == nil or killer == victim then addLog(vn .. " est mort"); return end
	addLog(WeaponService.nameOf(killer) .. " ➜ " .. vn .. " (" .. MatchService.weaponName(key) .. (if headshot then ", tête" else "") .. ")")
end)
pcall(function()
	TextChatService.DescendantAdded:Connect(function(d)
		if d:IsA("TextSource") then
			local q = Players:GetPlayerByUserId(d.UserId)
			if q and muted[q.UserId] then d.CanSend = false end
		end
	end)
end)

return AdminService
