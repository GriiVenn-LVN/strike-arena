--!strict
-- ServerScriptService/RewardService (ModuleScript)
-- XP / niveaux, récompense quotidienne (série de 7 jours), défis du jour, récompenses de fin de partie.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local LoyaltyService = require(script.Parent.LoyaltyService)

local RewardService = {}

local function today(): number
	return math.floor(os.time() / 86400)      -- jour UTC
end

-- ---------- niveaux ----------
function RewardService.levelInfo(profile)
	local level, xp = 1, profile.xp
	while xp >= Config.xpNeeded(level) do
		xp -= Config.xpNeeded(level)
		level += 1
	end
	return level, xp, Config.xpNeeded(level)
end

local function applyReward(profile, r)
	if r.coins then profile.coins += r.coins end
	if r.box then profile.boxes[r.box] = (profile.boxes[r.box] or 0) + (r.n or 1) end
	if r.dance and not table.find(profile.inv.dances, r.dance) then table.insert(profile.inv.dances, r.dance) end
end
RewardService.applyReward = applyReward

local function levelReward(level: number)
	if level % 25 == 0 then return { box = "prem", coins = 250 } end
	if level % 10 == 0 then return { box = "std", coins = 150 } end
	if level % 5 == 0 then return { coins = 120 } end
	return { coins = 30 + level * 3 }
end

function RewardService.addXP(player: Player, amount: number)
	local profile = DataService.get(player)
	if not profile then return {} end
	local before = RewardService.levelInfo(profile)
	profile.xp += amount
	local after = RewardService.levelInfo(profile)
	local ups = {}
	for l = before + 1, after do
		local r = levelReward(l)
		applyReward(profile, r)
		table.insert(ups, { level = l, reward = r })
	end
	return ups
end

-- ---------- récompense quotidienne ----------
function RewardService.dailyStatus(profile)
	local t = today()
	if profile.lastLoginDay == t then
		return { canClaim = false, day = ((profile.streak - 1) % 7) + 1, streak = profile.streak }
	end
	local nextStreak = (profile.lastLoginDay == t - 1) and (profile.streak + 1) or 1
	local shield = nextStreak == 1 and LoyaltyService.shieldOk(profile)   -- Premium : un jour manqué par semaine est pardonné
	if shield then nextStreak = profile.streak + 1 end
	return { canClaim = true, day = ((nextStreak - 1) % 7) + 1, streak = nextStreak, shield = shield }
end

function RewardService.claimDaily(player: Player)
	local profile = DataService.get(player)
	if not profile then return nil end
	local st = RewardService.dailyStatus(profile)
	if not st.canClaim then return nil end
	if st.shield then LoyaltyService.useShield(profile) end
	profile.streak = st.streak
	profile.lastLoginDay = today()
	local r = Config.DAILY[st.day]
	applyReward(profile, r)
	return r, st.day
end

-- ---------- défis du jour ----------
local MISSION_POOL = {
	{ id = "kills", target = 15, coins = 50, xp = 60 },
	{ id = "hs", target = 5, coins = 40, xp = 50 },
	{ id = "win", target = 1, coins = 65, xp = 80 },
	{ id = "matches", target = 3, coins = 60, xp = 60 },
	{ id = "plant", target = 2, coins = 50, xp = 60 },
	{ id = "nade", target = 2, coins = 65, xp = 70 },
	{ id = "knife", target = 1, coins = 85, xp = 90 },
	{ id = "dmg", target = 1500, coins = 50, xp = 60 },
}

local function ensureMissions(profile)
	local t = today()
	if profile.missions.day ~= t then
		profile.missions.day = t
		local pool = table.clone(MISSION_POOL)
		local list = {}
		for _ = 1, 3 do
			local i = math.random(#pool)
			local m = table.remove(pool, i)
			table.insert(list, { id = m.id, target = m.target, coins = m.coins, xp = m.xp, progress = 0, done = false, claimed = false })
		end
		profile.missions.list = list
	end
end
RewardService.ensureMissions = ensureMissions

function RewardService.missionEvent(player: Player, id: string, n: number?)
	local profile = DataService.get(player)
	if not profile then return end
	ensureMissions(profile)
	for _, m in ipairs(profile.missions.list) do
		if m.id == id and not m.done then
			m.progress = math.min(m.target, m.progress + (n or 1))
			if m.progress >= m.target then m.done = true end
		end
	end
end

function RewardService.claimMission(player: Player, index: number)
	local profile = DataService.get(player)
	if not profile then return nil end
	local m = profile.missions.list[index]
	if not m or not m.done or m.claimed then return nil end
	m.claimed = true
	profile.coins += m.coins
	return RewardService.addXP(player, m.xp)
end

-- ---------- fin de partie ----------
function RewardService.finishMatch(player: Player, summary)
	-- summary = { kills, deaths, hs, dmg, shots, hits, plants, defuses, won, seconds, mode, map, weaponKills = {} }
	local profile = DataService.get(player)
	if not profile then return end
	local s = profile.stats
	s.matches += 1; if summary.won then s.wins += 1 end
	s.kills += summary.kills; s.deaths += summary.deaths; s.hs += summary.hs; s.dmg += summary.dmg
	s.shots += summary.shots; s.hits += summary.hits; s.seconds += summary.seconds
	s.bestStreak = math.max(s.bestStreak, summary.bestStreak or 0)
	local bm = s.byMode[summary.mode] or { m = 0, w = 0 }; bm.m += 1; if summary.won then bm.w += 1 end; s.byMode[summary.mode] = bm
	local bp = s.byMap[summary.map] or { m = 0, w = 0 }; bp.m += 1; if summary.won then bp.w += 1 end; s.byMap[summary.map] = bp
	for k, v in pairs(summary.weaponKills or {}) do s.byWeapon[k] = (s.byWeapon[k] or 0) + v end
	table.insert(profile.history, 1, { t = os.time(), mode = summary.mode, map = summary.map, won = summary.won, k = summary.kills, d = summary.deaths })
	while #profile.history > 25 do table.remove(profile.history) end
	local xp = 40 + summary.kills * 10 + summary.hs * 5 + (summary.won and 120 or 0) + (summary.plants + summary.defuses) * 25
	local coins = math.floor(xp * 0.15)   -- ~35 pièces par partie : progression lente, comme sur le web
	local bonusXp, bonusCoins, bonusLines = LoyaltyService.matchBonus(player, xp, coins, summary.won)   -- fidélité, Premium, boost, 1re victoire
	xp += bonusXp; coins += bonusCoins
	profile.coins += coins
	RewardService.missionEvent(player, "matches")
	if summary.won then RewardService.missionEvent(player, "win") end
	RewardService.missionEvent(player, "dmg", summary.dmg)
	local ups = RewardService.addXP(player, xp)
	return { xp = xp, coins = coins, levelUps = ups, bonus = bonusLines }
end

return RewardService
