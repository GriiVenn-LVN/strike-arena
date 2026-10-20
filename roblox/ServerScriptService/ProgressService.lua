--!strict
-- ServerScriptService/ProgressService (ModuleScript)
-- Passe de combat saisonnier, classement (PR), succès (+ Badges Roblox) et événement limité.
-- À appeler depuis RewardService.finishMatch (voir Main.server.lua) avec le résumé de partie.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local X = require(ReplicatedStorage.Shared.ConfigExtra)
local DataService = require(script.Parent.DataService)

local ProgressService = {}

-- Crée ces badges dans le Creator Hub puis colle leurs identifiants ici (0 = ignoré)
local BADGE_IDS: { [string]: number } = {}

local function ensure(profile)
	if not profile.bp or profile.bp.id ~= X.SEASON.id then
		profile.bp = { id = X.SEASON.id, xp = 0, premium = false, claimedFree = {}, claimedPremium = {} }
	end
	profile.rank = profile.rank or { rp = 0, best = 0 }
	profile.ach = profile.ach or {}
	profile.ev = profile.ev or { id = "", pumpkins = 0, claimed = {} }
	profile.weaponKills = profile.weaponKills or {}
	profile.cosmetics = profile.cosmetics or { attachments = {}, charm = "", trail = "", spray = "smile", title = "", knife = "classic" }
end
ProgressService.ensure = ensure

local function bpTier(profile): number
	return math.min(X.SEASON.tiers, math.floor(profile.bp.xp / X.SEASON.xpPerTier))
end

-- ---------- passe de combat ----------
local function seededItem(tier: number, rarity: number)
	-- même tirage pour tous les joueurs : l'objet du palier est déterministe
	local pool = {}
	for w, _ in pairs(Config.WEAPONS) do
		for i, skin in ipairs(Config.SKINS) do
			if skin.rarity == rarity and w ~= "knife" and not (skin :: any).ev then table.insert(pool, { weapon = w, skin = i }) end   -- skins d'événement : jamais dans le passe
		end
	end
	table.sort(pool, function(a, b) return a.weapon .. a.skin < b.weapon .. b.skin end)
	local r = Random.new(tier * 17 + rarity)
	return pool[r:NextInteger(1, #pool)]
end

function ProgressService.claimTier(player: Player, tier: number, premium: boolean)
	local profile = DataService.get(player); if not profile then return nil end
	ensure(profile)
	local claimed = if premium then profile.bp.claimedPremium else profile.bp.claimedFree
	if tier ~= math.floor(tier) or tier < 1 or tier > bpTier(profile) or table.find(claimed, tier) then return nil end   -- palier entier seulement (1,5 ferait un palier fantôme)
	if premium and not profile.bp.premium then return nil end
	local r = X.bpReward(tier, premium)
	if r.coins then profile.coins += r.coins end
	if r.box then profile.boxes[r.box] = (profile.boxes[r.box] or 0) + 1 end
	local granted
	if r.item then
		granted = seededItem(tier, r.rarity)
		local owned = profile.inv.skins[granted.weapon] or {}
		if table.find(owned, granted.skin) then
			profile.coins += Config.DUPLICATE_VALUE[r.rarity]
			granted.duplicate = true
		else
			table.insert(owned, granted.skin); profile.inv.skins[granted.weapon] = owned
		end
	end
	table.insert(claimed, tier)
	return { reward = r, item = granted }
end

function ProgressService.grantPremium(player: Player)
	local profile = DataService.get(player); if not profile then return false end
	ensure(profile); profile.bp.premium = true
	return true
end

function ProgressService.buyPremiumWithCoins(player: Player): boolean
	local profile = DataService.get(player); if not profile then return false end
	ensure(profile)
	if profile.bp.premium or profile.coins < X.SEASON.premiumCoins then return false end
	profile.coins -= X.SEASON.premiumCoins; profile.bp.premium = true
	return true
end

-- ---------- succès ----------
local function awardBadge(player: Player, id: string)
	local badge = BADGE_IDS[id]
	if badge and badge > 0 then task.spawn(function() pcall(BadgeService.AwardBadge, BadgeService, player.UserId, badge) end) end
end
local function checkAchievements(player: Player, profile, ctx)
	local unlocked = {}
	for _, a in ipairs(X.ACHIEVEMENTS) do
		if not profile.ach[a.id] then
			local ok = false
			if a.stat then ok = (profile.stats[a.stat] or 0) >= a.target
			elseif a.match then ok = (ctx[a.match] or 0) >= a.target
			elseif a.rank then ok = math.floor(profile.rank.rp / X.RANK_RP_PER_DIVISION) >= a.rank end
			if ok then
				profile.ach[a.id] = os.time(); profile.coins += a.coins
				table.insert(unlocked, a.id); awardBadge(player, a.id)
			end
		end
	end
	return unlocked
end

-- ---------- événement ----------
local function today(): string return os.date("!%Y-%m-%d") :: string end
function ProgressService.eventActive(): boolean
	local t = today(); return t >= X.EVENT.from and t <= X.EVENT.to
end
local toastEvent = Instance.new("RemoteEvent"); toastEvent.Name = "PumpkinToast"; toastEvent.Parent = ReplicatedStorage   -- serveur -> joueur : { count, lines }

-- objets d'Halloween d'un palier (src/8W_halloween.js applyReward) : skin pour toutes les armes, tenue, effet d'élimination
local function skinIndex(pattern: string): number?
	for i, sk in ipairs(Config.SKINS) do if sk.pattern == pattern then return i end end
	return nil
end
local function outfitIndex(name: string): number?
	for i, o in ipairs(Config.OUTFITS) do if o.name == name then return i end end
	return nil
end
local function grantHw(profile: any, g: any): { string }
	local lines = {}
	if g.skin then
		local i = skinIndex(g.skin)
		if i then
			for w in pairs(Config.WEAPONS) do
				local owned = profile.inv.skins[w] or {}
				if not table.find(owned, i) then table.insert(owned, i) end
				profile.inv.skins[w] = owned
			end
			table.insert(lines, "Skin " .. Config.SKINS[i].name)
		end
	end
	if g.outfit then
		local i = outfitIndex(g.outfit)
		if i then
			profile.inv.outfits = profile.inv.outfits or {}
			if not table.find(profile.inv.outfits, i) then table.insert(profile.inv.outfits, i) end
			table.insert(lines, "Tenue " .. g.outfit)
		end
	end
	if g.fx then
		profile.inv.killfx = profile.inv.killfx or {}
		if not table.find(profile.inv.killfx, g.fx) then table.insert(profile.inv.killfx, g.fx) end
		local KillFxConfig = require(ReplicatedStorage.Shared.KillFxConfig)
		local f = KillFxConfig.get(g.fx)
		table.insert(lines, "Effet " .. (if f then f.name else g.fx))
	end
	return lines
end
-- texte d'un palier (rewardText du web)
function ProgressService.goalText(g: any): string
	local a = {}
	if g.coins then table.insert(a, g.coins .. " pièces") end
	if g.box then table.insert(a, if g.box == "prem" then "Caisse Premium" else "Caisse Standard") end
	if g.dance and Config.DANCES[g.dance] then table.insert(a, "Danse « " .. Config.DANCES[g.dance].name .. " »") end
	if g.skin then local i = skinIndex(g.skin); if i then table.insert(a, "Skin " .. Config.SKINS[i].name) end end
	if g.outfit then table.insert(a, "Tenue " .. g.outfit) end
	if g.fx then
		local KillFxConfig = require(ReplicatedStorage.Shared.KillFxConfig)
		local f = KillFxConfig.get(g.fx)
		table.insert(a, "Effet " .. (if f then f.name else g.fx))
	end
	return table.concat(a, " • ")
end
-- paliers atteints : récompenses de base (claimed = n) et objets d'Halloween (claimed = "hw" .. n, rattrapage des anciens profils)
local GOALS: { any } = X.EVENT.goals :: any
local function claimGoals(profile: any): ({ any }, { string })
	local rewards, lines = {}, {}
	for _, g in ipairs(GOALS) do
		if profile.ev.pumpkins >= g.n then
			if (g.coins or g.box or g.dance) and not table.find(profile.ev.claimed, g.n) then
				table.insert(profile.ev.claimed, g.n)
				if g.coins then profile.coins += g.coins end
				if g.box then profile.boxes[g.box] = (profile.boxes[g.box] or 0) + 1 end
				if g.dance and not table.find(profile.inv.dances, g.dance) then table.insert(profile.inv.dances, g.dance) end
				table.insert(rewards, g)
				table.insert(lines, "🎃 Palier " .. g.n .. " : " .. ProgressService.goalText(g))
			end
			local tag = "hw" .. g.n
			if (g.skin or g.outfit or g.fx) and not table.find(profile.ev.claimed, tag) then
				table.insert(profile.ev.claimed, tag)
				local got = grantHw(profile, g)
				if not table.find(rewards, g) then table.insert(rewards, g) end
				if #got > 0 then table.insert(lines, "🎃 Palier " .. g.n .. " : " .. table.concat(got, " • ")) end
			end
		end
	end
	return rewards, lines
end
local function evProfile(profile: any)
	ensure(profile)
	if profile.ev.id ~= X.EVENT.id then profile.ev = { id = X.EVENT.id, pumpkins = 0, claimed = {} } end
end
function ProgressService.collectPumpkin(player: Player): any
	local profile = DataService.get(player); if not profile or not ProgressService.eventActive() then return nil end
	evProfile(profile)
	profile.ev.pumpkins += 1
	local rewards, lines = claimGoals(profile)
	toastEvent:FireClient(player, { count = profile.ev.pumpkins, lines = lines })
	return { count = profile.ev.pumpkins, rewards = rewards }
end
-- état de l'événement pour le menu (paliers, citrouilles ramassées, textes)
function ProgressService.eventStatus(player: Player): any
	local profile: any = DataService.get(player)
	local pk = 0
	if profile then ensure(profile); if profile.ev.id == X.EVENT.id then pk = profile.ev.pumpkins end end
	local goals = {}
	for _, g in ipairs(GOALS) do table.insert(goals, { n = g.n, text = ProgressService.goalText(g), done = pk >= g.n }) end
	return { id = X.EVENT.id, name = X.EVENT.name, from = X.EVENT.from, to = X.EVENT.to, active = ProgressService.eventActive(), pumpkins = pk, goals = goals }
end
-- rattrapage à l'arrivée : paliers déjà atteints avant l'ajout des objets d'Halloween
task.spawn(function()
	local function catchUp(p: Player)
		for _ = 1, 30 do
			local profile = DataService.get(p)
			if profile then
				ensure(profile)
				if ProgressService.eventActive() and profile.ev.id == X.EVENT.id then claimGoals(profile) end
				return
			end
			task.wait(1)
		end
	end
	Players.PlayerAdded:Connect(catchUp)
	for _, p in ipairs(Players:GetPlayers()) do task.spawn(catchUp, p) end
end)

-- ---------- fin de partie ----------
-- summary : { xp, won, mode, difficulty, ranked, kills, brWin, zombieWave, kothWin, trainScore, weaponKills }
function ProgressService.finishMatch(player: Player, summary)
	local profile = DataService.get(player); if not profile then return nil end
	ensure(profile)
	local before = bpTier(profile)
	profile.bp.xp += summary.xp
	local rankInfo
	if summary.ranked and X.RANKED_MODES[summary.mode] and (summary.difficulty or 0) >= 1 then
		local old = profile.rank.rp
		profile.rank.rp = math.max(0, old + X.rankDelta(summary.won, summary.difficulty))
		profile.rank.best = math.max(profile.rank.best, profile.rank.rp)
		rankInfo = { delta = profile.rank.rp - old, name = X.rankName(profile.rank.rp) }
	end
	for k, v in pairs(summary.weaponKills or {}) do profile.weaponKills[k] = (profile.weaponKills[k] or 0) + v end
	local ach = checkAchievements(player, profile, summary)
	return { tier = bpTier(profile), tiersGained = bpTier(profile) - before, rank = rankInfo, achievements = ach }
end

-- ---------- Remotes UI ----------
local function remote(name: string, fn: (Player, ...any) -> any)
	local r = Instance.new("RemoteFunction"); r.Name = name; r.Parent = ReplicatedStorage; r.OnServerInvoke = fn
end
local RateLimit = require(script.Parent.RateLimit)
remote("BP_Claim", function(p, tier: any, premium: any)
	if typeof(tier) ~= "number" or typeof(premium) ~= "boolean" or not RateLimit.ok(p, "BP_Claim", 0.15) then return nil end
	return ProgressService.claimTier(p, tier, premium)
end)
remote("BP_BuyPremium", function(p) return ProgressService.buyPremiumWithCoins(p) end)
-- fenêtre du passe de combat (PassUI) : paliers gratuits et Premium, avec l'objet exact de chaque palier Premium
-- (même tirage que claimTier) pour l'aperçu 3D ; « tout récupérer » d'un coup. Cadence limitée.
remote("BP_State", function(p)
	if not RateLimit.ok(p, "BP_State", 0.25) then return nil end
	local profile = DataService.get(p); if not profile then return nil end
	ensure(profile)
	local tiers = {}
	for t = 1, X.SEASON.tiers do
		local free, prem = X.bpReward(t, false), X.bpReward(t, true)
		local item = if prem.item then seededItem(t, prem.rarity) else nil
		table.insert(tiers, { free = free, prem = prem, item = item })
	end
	return { name = X.SEASON.name, tier = bpTier(profile), max = X.SEASON.tiers, xp = profile.bp.xp, xpPerTier = X.SEASON.xpPerTier,
		premium = profile.bp.premium, claimedFree = profile.bp.claimedFree, claimedPremium = profile.bp.claimedPremium,
		premiumCoins = X.SEASON.premiumCoins, premiumRobux = X.SEASON.premiumRobux, coins = profile.coins, tiers = tiers }
end)
remote("BP_ClaimAll", function(p)
	if not RateLimit.ok(p, "BP_ClaimAll", 1) then return nil end
	local profile = DataService.get(p); if not profile then return nil end
	ensure(profile)
	local got = {}
	for t = 1, bpTier(profile) do
		for _, prem in ipairs({ false, true }) do
			local list = if prem then profile.bp.claimedPremium else profile.bp.claimedFree
			if not table.find(list, t) and (not prem or profile.bp.premium) then
				local r = ProgressService.claimTier(p, t, prem)
				if r then r.tier = t; r.premium = prem; table.insert(got, r) end
			end
		end
	end
	if #got > 0 then task.spawn(DataService.save, p) end
	return got
end)
remote("EventStatus", function(p) return ProgressService.eventStatus(p) end)
remote("PumpkinCollected", function(p, id: any)
	-- la citrouille existe côté serveur (Part nommée "Pumpkin") : on vérifie la distance avant de créditer
	if typeof(id) ~= "Instance" or not id:IsA("BasePart") or id.Name ~= "Pumpkin" or not id:IsDescendantOf(workspace) then return nil end
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or ((id :: BasePart).Position - root.Position).Magnitude > 12 then return nil end
	id:Destroy()
	return ProgressService.collectPumpkin(p)
end)

-- Citrouille à ramasser : Part « Pumpkin » (vérifiée par PumpkinCollected) habillée en citrouille sculptée (jackO du web)
function ProgressService.pumpkinAt(pos: Vector3, parent: Instance?): BasePart
	local p = Instance.new("Part"); p.Name = "Pumpkin"; p.Shape = Enum.PartType.Ball; p.Size = Vector3.new(2.2, 1.8, 2.2)
	p.Color = Color3.fromRGB(232, 112, 26); p.Material = Enum.Material.SmoothPlastic; p.Anchored = true; p.CanCollide = false; p.CanQuery = false
	p.Position = pos + Vector3.new(0, 0.9, 0)
	for i = 0, 5 do   -- côtes
		local a = i / 6 * math.pi
		local r = Instance.new("Part"); r.Name = "Rib"; r.Shape = Enum.PartType.Ball; r.Size = Vector3.new(0.9, 1.75, 2.25)
		r.Color = Color3.fromRGB(214, 98, 20); r.Material = Enum.Material.SmoothPlastic; r.Anchored = true; r.CanCollide = false; r.CanQuery = false; r.CanTouch = false
		r.CFrame = CFrame.new(p.Position) * CFrame.Angles(0, a, 0); r.Parent = p
	end
	local stem = Instance.new("Part"); stem.Name = "Stem"; stem.Size = Vector3.new(0.25, 0.5, 0.25); stem.Color = Color3.fromRGB(74, 90, 34)
	stem.Anchored = true; stem.CanCollide = false; stem.CanQuery = false; stem.CanTouch = false
	stem.CFrame = CFrame.new(p.Position + Vector3.new(0, 1.05, 0)) * CFrame.Angles(0, 0, 0.25); stem.Parent = p
	for _, sx in ipairs({ -0.4, 0.4 }) do   -- yeux lumineux
		local e = Instance.new("Part"); e.Name = "Eye"; e.Size = Vector3.new(0.32, 0.32, 0.1); e.Material = Enum.Material.Neon; e.Color = Color3.fromRGB(255, 208, 96)
		e.Anchored = true; e.CanCollide = false; e.CanQuery = false; e.CanTouch = false
		e.CFrame = CFrame.new(p.Position + Vector3.new(sx, 0.2, -1.08)) * CFrame.Angles(0, 0, math.rad(45)); e.Parent = p
	end
	local mouth = Instance.new("Part"); mouth.Name = "Mouth"; mouth.Size = Vector3.new(0.9, 0.18, 0.1); mouth.Material = Enum.Material.Neon; mouth.Color = Color3.fromRGB(255, 208, 96)
	mouth.Anchored = true; mouth.CanCollide = false; mouth.CanQuery = false; mouth.CanTouch = false
	mouth.CFrame = CFrame.new(p.Position + Vector3.new(0, -0.3, -1.06)); mouth.Parent = p
	local light = Instance.new("PointLight"); light.Color = Color3.fromRGB(255, 120, 20); light.Range = 10; light.Parent = p
	local prompt = Instance.new("ProximityPrompt"); prompt.ActionText = "Ramasser"; prompt.ObjectText = "Citrouille"; prompt.HoldDuration = 0; prompt.MaxActivationDistance = 8; prompt.RequiresLineOfSight = false; prompt.Parent = p
	prompt.Triggered:Connect(function(player)
		if not p.Parent then return end
		p:Destroy()
		ProgressService.collectPumpkin(player)
	end)
	p.Parent = parent or workspace
	return p
end

-- Décor d'événement : citrouilles posées sur les points de passage des bots (MapData.roam)
function ProgressService.spawnPumpkins(map, cellToWorld: (number, number) -> Vector3, parent: Instance?)
	if not ProgressService.eventActive() then return end
	local pts = table.clone(map.roam or {})
	local rng = Random.new()
	for i = #pts, 2, -1 do local j = rng:NextInteger(1, i); pts[i], pts[j] = pts[j], pts[i] end
	for i = 1, math.min(X.EVENT.pumpkinsPerMatch, #pts) do
		ProgressService.pumpkinAt(cellToWorld(pts[i][1], pts[i][2]) + Vector3.new(0, 0.1, 0), parent)
	end
end

return ProgressService
