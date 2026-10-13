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
			if skin.rarity == rarity and w ~= "knife" then table.insert(pool, { weapon = w, skin = i }) end
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
	if tier < 1 or tier > bpTier(profile) or table.find(claimed, tier) then return nil end
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
function ProgressService.collectPumpkin(player: Player)
	local profile = DataService.get(player); if not profile or not ProgressService.eventActive() then return nil end
	ensure(profile)
	if profile.ev.id ~= X.EVENT.id then profile.ev = { id = X.EVENT.id, pumpkins = 0, claimed = {} } end
	profile.ev.pumpkins += 1
	local rewards = {}
	for _, g in ipairs(X.EVENT.goals) do
		if profile.ev.pumpkins >= g.n and not table.find(profile.ev.claimed, g.n) then
			table.insert(profile.ev.claimed, g.n)
			if g.coins then profile.coins += g.coins end
			if g.box then profile.boxes[g.box] = (profile.boxes[g.box] or 0) + 1 end
			if g.dance and not table.find(profile.inv.dances, g.dance) then table.insert(profile.inv.dances, g.dance) end
			table.insert(rewards, g)
		end
	end
	return { count = profile.ev.pumpkins, rewards = rewards }
end

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
remote("BP_Claim", function(p, tier: any, premium: any)
	if typeof(tier) ~= "number" or typeof(premium) ~= "boolean" then return nil end
	return ProgressService.claimTier(p, tier, premium)
end)
remote("BP_BuyPremium", function(p) return ProgressService.buyPremiumWithCoins(p) end)
remote("PumpkinCollected", function(p, id: any)
	-- la citrouille existe côté serveur (Part nommée "Pumpkin") : on vérifie la distance avant de créditer
	if typeof(id) ~= "Instance" or id.Name ~= "Pumpkin" or not id:IsDescendantOf(workspace) then return nil end
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or ((id :: BasePart).Position - root.Position).Magnitude > 12 then return nil end
	id:Destroy()
	return ProgressService.collectPumpkin(p)
end)

-- Décor d'événement : citrouilles posées sur les points de passage des bots (MapData.roam)
function ProgressService.spawnPumpkins(map, cellToWorld: (number, number) -> Vector3)
	if not ProgressService.eventActive() then return end
	local pts = table.clone(map.roam or {})
	local rng = Random.new()
	for i = #pts, 2, -1 do local j = rng:NextInteger(1, i); pts[i], pts[j] = pts[j], pts[i] end
	for i = 1, math.min(X.EVENT.pumpkinsPerMatch, #pts) do
		local p = Instance.new("Part"); p.Name = "Pumpkin"; p.Shape = Enum.PartType.Ball; p.Size = Vector3.new(2.2, 1.8, 2.2)
		p.Color = Color3.fromRGB(255, 122, 26); p.Material = Enum.Material.SmoothPlastic; p.Anchored = true; p.CanCollide = false
		p.Position = cellToWorld(pts[i][1], pts[i][2]) + Vector3.new(0, 1, 0)
		local light = Instance.new("PointLight"); light.Color = Color3.fromRGB(255, 120, 20); light.Range = 10; light.Parent = p
		local prompt = Instance.new("ProximityPrompt"); prompt.ActionText = "Ramasser"; prompt.ObjectText = "Citrouille"; prompt.HoldDuration = 0; prompt.MaxActivationDistance = 8; prompt.Parent = p
		prompt.Triggered:Connect(function(player) ProgressService.collectPumpkin(player); p:Destroy() end)
		p.Parent = workspace
	end
end

return ProgressService
