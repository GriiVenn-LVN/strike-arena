--!strict
-- ServerScriptService/RewardService (ModuleScript)
-- XP / niveaux, récompense quotidienne (série de 7 jours), défis du jour, récompenses de fin de partie.
-- Fin de partie : le détail des gains (lignes XP / pièces) part dans le résumé MatchEnd (RecapService le complète,
-- RewardScreen l'affiche côté client) ; chaque montée de niveau est envoyée au joueur (remote « LevelUp ») avec sa récompense.
-- Bonus : XP ×2 le week-end (samedi et dimanche UTC) et passe de jeu « XP ×2 » (attribut PassXp2 posé par ShopService) ;
-- les pièces, elles, ne sont pas doublées (économie lente).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Modes = require(ReplicatedStorage.Shared.Modes)
local DataService = require(script.Parent.DataService)
local LoyaltyService = require(script.Parent.LoyaltyService)
local LeaderboardService = require(script.Parent.LeaderboardService)

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
RewardService.levelReward = levelReward

-- montée de niveau : fenêtre « NIVEAU SUPÉRIEUR » côté client (RewardScreen), avec la récompense et le prochain gros palier
local levelUpEvent = Instance.new("RemoteEvent"); levelUpEvent.Name = "LevelUp"; levelUpEvent.Parent = ReplicatedStorage
local function nextMilestone(level: number): any
	local l = level + 1
	while l % 5 ~= 0 do l += 1 end
	return { level = l, reward = levelReward(l) }
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
	if #ups > 0 then levelUpEvent:FireClient(player, { ups = ups, level = after, milestone = nextMilestone(after) }) end
	return ups
end

-- ---------- bonus d'XP ----------
-- week-end : samedi ou dimanche (UTC), XP ×2 en fin de partie
function RewardService.weekend(): boolean
	local wd = (os.date("!*t", os.time()) :: any).wday   -- 1 = dimanche, 7 = samedi
	return wd == 1 or wd == 7
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
-- n = texte du défi ({t} = objectif), comme MPOOL du web (src/62_meta.js + src/8O_defis.js + src/8W_confirm.js)
local MISSION_POOL = {
	{ id = "kills", n = "Élimine {t} adversaires", target = 15, coins = 50, xp = 60 },
	{ id = "hs", n = "Fais {t} headshots", target = 5, coins = 40, xp = 50 },
	{ id = "win", n = "Gagne {t} partie", target = 1, coins = 65, xp = 80 },
	{ id = "matches", n = "Joue {t} parties", target = 3, coins = 60, xp = 60 },
	{ id = "plant", n = "Pose ou désamorce la bombe {t} fois", target = 2, coins = 50, xp = 60 },
	{ id = "nade", n = "Élimine {t} adversaires avec une grenade", target = 2, coins = 65, xp = 70 },
	{ id = "knife", n = "Élimine {t} adversaire au couteau", target = 1, coins = 85, xp = 90 },
	{ id = "dmg", n = "Inflige {t} dégâts", target = 1500, coins = 50, xp = 60 },
	-- défis ajoutés par src/8O_defis.js : par type d'arme, par mode, Zombies, Infecté
	{ id = "k_shotgun", n = "Élimine {t} adversaires au fusil à pompe", target = 8, coins = 180, xp = 70 },
	{ id = "k_sniper", n = "Élimine {t} adversaires au fusil de précision", target = 5, coins = 200, xp = 80 },
	{ id = "k_smg", n = "Élimine {t} adversaires au pistolet-mitrailleur", target = 12, coins = 160, xp = 60 },
	{ id = "k_pistol", n = "Élimine {t} adversaires au pistolet", target = 8, coins = 180, xp = 70 },
	{ id = "k_rifle", n = "Élimine {t} adversaires au fusil d'assaut", target = 15, coins = 160, xp = 60 },
	{ id = "w_duel", n = "Gagne {t} Duel", target = 1, coins = 220, xp = 90 },
	{ id = "w_dom", n = "Gagne {t} partie de Domination", target = 1, coins = 220, xp = 90 },
	{ id = "w_gg", n = "Gagne {t} Course aux armes", target = 1, coins = 250, xp = 100 },
	{ id = "z_wave", n = "Survis à {t} manches de Zombies", target = 5, coins = 200, xp = 80 },
	{ id = "inf_surv", n = "Termine {t} partie d'Infecté sans être infecté", target = 1, coins = 250, xp = 100 },
	{ id = "kcTag", n = "Ramasse {t} plaques en Élimination confirmée", target = 10, coins = 150, xp = 70 },
	-- modes ajoutés : Gunfight et Survolté
	{ id = "w_gunfight", n = "Gagne {t} Gunfight", target = 1, coins = 220, xp = 90 },
	{ id = "w_survolte", n = "Gagne {t} partie de Survolté", target = 1, coins = 220, xp = 90 },
}
-- défis de la semaine (src/8O_defis.js WPOOL) : 3 par semaine (lundi), plus longs et mieux payés
local WEEKLY_POOL = {
	{ id = "kills", n = "Élimine {t} adversaires", target = 150, coins = 800, xp = 300 },
	{ id = "hs", n = "Fais {t} headshots", target = 40, coins = 700, xp = 280 },
	{ id = "win", n = "Gagne {t} parties", target = 8, coins = 900, xp = 350 },
	{ id = "matches", n = "Joue {t} parties", target = 15, coins = 700, xp = 250 },
	{ id = "k_sniper", n = "Élimine {t} adversaires au fusil de précision", target = 25, coins = 800, xp = 300 },
	{ id = "k_shotgun", n = "Élimine {t} adversaires au fusil à pompe", target = 30, coins = 800, xp = 300 },
	{ id = "knife", n = "Élimine {t} adversaires au couteau", target = 5, coins = 900, xp = 350 },
	{ id = "w_duel", n = "Gagne {t} Duels", target = 3, coins = 800, xp = 300 },
	{ id = "w_dom", n = "Gagne {t} parties de Domination", target = 3, coins = 800, xp = 300 },
	{ id = "z_wave", n = "Survis à {t} manches de Zombies", target = 20, coins = 900, xp = 350 },
	{ id = "dmg", n = "Inflige {t} dégâts", target = 15000, coins = 700, xp = 280 },
	{ id = "inf_surv", n = "Termine {t} parties d'Infecté sans être infecté", target = 3, coins = 900, xp = 350 },
}
local function poolDef(pool: { any }, id: string): any
	for _, m in ipairs(pool) do if m.id == id then return m end end
	return nil
end
local function missionText(d: any): string
	return (string.gsub(d.n, "{t}", tostring(d.target)))
end

-- défi terminé : petit message au joueur (uiMissionDone / uiToast du web)
local doneEvent = Instance.new("RemoteEvent"); doneEvent.Name = "ChallengeDone"; doneEvent.Parent = ReplicatedStorage
-- défis terminés depuis la dernière fin de partie : listés sur l'écran de fin (RecapService les relève)
local doneLog: { [Player]: { any } } = {}
local function logDone(player: Player, d: any)
	local l = doneLog[player] or {}
	if #l < 12 then table.insert(l, d) end
	doneLog[player] = l
end
function RewardService.takeDone(player: Player): { any }
	local l = doneLog[player] or {}
	doneLog[player] = nil
	return l
end
game:GetService("Players").PlayerRemoving:Connect(function(p) doneLog[p] = nil end)

local function ensureMissions(profile: any)
	local t = today()
	if profile.missions.day ~= t then
		profile.missions.day = t
		local pool = table.clone(MISSION_POOL)
		local list = {}
		for _ = 1, 3 do
			local i = math.random(#pool)
			local m = table.remove(pool, i) :: any
			table.insert(list, { id = m.id, target = m.target, coins = m.coins, xp = m.xp, progress = 0, done = false, claimed = false })
		end
		profile.missions.list = list
	end
end
RewardService.ensureMissions = ensureMissions

-- semaine commençant le lundi (weekKey du web)
local function weekKey(): string
	return "w" .. math.floor((os.time() / 86400 + 3) / 7)
end
function RewardService.weekSecondsLeft(): number
	local w = math.floor((os.time() / 86400 + 3) / 7)
	return math.max(0, math.floor(((w + 1) * 7 - 3) * 86400 - os.time()))
end
local function ensureWeekly(profile: any)
	local k = weekKey()
	if not profile.wmis or profile.wmis.wk ~= k then
		local pool = table.clone(WEEKLY_POOL)
		local list = {}
		for _ = 1, 3 do
			local m = table.remove(pool, math.random(#pool)) :: any
			table.insert(list, { id = m.id, target = m.target, coins = m.coins, xp = m.xp, progress = 0, done = false, claimed = false })
		end
		profile.wmis = { wk = k, list = list }
	end
end
RewardService.ensureWeekly = ensureWeekly

function RewardService.missionEvent(player: Player, id: string, n: number?)
	local profile = DataService.get(player)
	if not profile then return end
	ensureMissions(profile)
	ensureWeekly(profile)
	for _, m in ipairs(profile.missions.list) do
		if m.id == id and not m.done then
			m.progress = math.min(m.target, m.progress + (n or 1))
			if m.progress >= m.target then
				m.done = true
				local d = poolDef(MISSION_POOL, m.id)
				if d then
					local info = { weekly = false, text = missionText(d), coins = m.coins, xp = m.xp }
					doneEvent:FireClient(player, info); logDone(player, info)
				end
			end
		end
	end
	for _, m in ipairs(profile.wmis.list) do
		if m.id == id and not m.done then
			m.progress = math.min(m.target, m.progress + (n or 1))
			if m.progress >= m.target then
				m.done = true
				local d = poolDef(WEEKLY_POOL, m.id)
				if d then
					local info = { weekly = true, text = missionText(d), coins = m.coins, xp = m.xp }
					doneEvent:FireClient(player, info); logDone(player, info)
				end
			end
		end
	end
end

function RewardService.claimMission(player: Player, index: number): any
	local profile = DataService.get(player)
	if not profile then return nil end
	local m = profile.missions.list[index]
	if not m or not m.done or m.claimed then return nil end
	m.claimed = true
	profile.coins += m.coins
	return RewardService.addXP(player, m.xp)
end
function RewardService.claimWeekly(player: Player, index: number): any
	local profile = DataService.get(player)
	if not profile then return nil end
	ensureWeekly(profile)
	local m = profile.wmis.list[index]
	if not m or not m.done or m.claimed then return nil end
	m.claimed = true
	profile.coins += m.coins
	return RewardService.addXP(player, m.xp)
end
-- défis du jour et de la semaine avec leurs textes, pour le menu (Progression)
function RewardService.challenges(player: Player): any
	local profile = DataService.get(player)
	if not profile then return nil end
	ensureMissions(profile)
	ensureWeekly(profile)
	local function view(list: { any }, pool: { any }): { any }
		local out = {}
		for i, m in ipairs(list) do
			local d = poolDef(pool, m.id)
			table.insert(out, { index = i, id = m.id, text = if d then missionText(d) else m.id, progress = m.progress, target = m.target,
				coins = m.coins, xp = m.xp, done = m.done, claimed = m.claimed })
		end
		return out
	end
	return { daily = view(profile.missions.list, MISSION_POOL), dailyLeft = 86400 - os.time() % 86400,
		weekly = view(profile.wmis.list, WEEKLY_POOL), weeklyLeft = RewardService.weekSecondsLeft() }
end

-- ---------- fin de partie ----------
function RewardService.finishMatch(player: Player, summary: any)
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
	LeaderboardService.addKills(player, summary.kills)    -- classement géant de la semaine (lobby)
	table.insert(profile.history, 1, { t = os.time(), mode = summary.mode, map = summary.map, won = summary.won, k = summary.kills, d = summary.deaths })
	while #profile.history > 25 do table.remove(profile.history) end
	-- détail des gains, ligne par ligne (écran de fin de partie)
	local lines = {}
	local function line(t: string, x: number)
		if x > 0 then table.insert(lines, { t = t, xp = x }) end
	end
	local obj = summary.plants + summary.defuses
	line("Participation", 40)
	line("Éliminations ×" .. summary.kills, summary.kills * 10)
	line("Tirs à la tête ×" .. summary.hs, summary.hs * 5)
	if summary.won then line("Victoire", 120) end
	line("Objectifs ×" .. obj, obj * 25)
	local xp = 40 + summary.kills * 10 + summary.hs * 5 + (summary.won and 120 or 0) + obj * 25
	local base = xp
	if summary.mode == Modes.featured() then xp *= 2; line("Mode de la semaine ×2", base) end   -- mode de la semaine : XP ×2 (affiché sur l'accueil du menu)
	-- pièces tirées de l'XP de base (web : coinsGain = xp × 0,15 avant le ×2 du mode de la semaine, qui ne double que l'XP)
	local coins = math.floor(base * 0.15)   -- ~35 pièces par partie : progression lente, comme sur le web
	-- XP ×2 du week-end et du passe XP ×2 : chacun ajoute l'XP de base de la partie (pas de pièces en plus)
	local weekend = RewardService.weekend()
	if weekend then xp += base; line("Week-end XP ×2", base) end
	if player:GetAttribute("PassXp2") == true then xp += base; line("Passe XP ×2", base) end
	local bonusXp, bonusCoins, bonusLines, firstWin = LoyaltyService.matchBonus(player, xp, coins, summary.won)   -- fidélité, Premium, boost, 1re victoire
	local matchCoins = coins
	xp += bonusXp; coins += bonusCoins
	profile.coins += coins
	RewardService.missionEvent(player, "matches")
	if summary.won then RewardService.missionEvent(player, "win") end
	RewardService.missionEvent(player, "dmg", summary.dmg)
	local xpStart = profile.xp
	local ups = RewardService.addXP(player, xp)
	return { xp = xp, coins = coins, levelUps = ups, bonus = bonusLines, lines = lines, matchCoins = matchCoins,
		xpStart = xpStart, weekend = weekend, firstWin = firstWin == true }
end

return RewardService
