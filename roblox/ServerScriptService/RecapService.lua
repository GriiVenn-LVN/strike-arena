--!strict
-- ServerScriptService/RecapService (ModuleScript, requis par Main après MedalService)
-- Écran de fin de partie façon Call of Duty / Fortnite : complète le résumé MatchEnd (MatchService.finishHooks) avec
-- payload.recap = {
--   lines      = { { t, xp } }  détail de l'XP (participation, éliminations, victoire, mode de la semaine, week-end, médailles…)
--   bonus      = { texte }       bonus de fidélité, Premium, boost, première victoire du jour (LoyaltyService)
--   xp, coins  = gains totaux ; coinsTotal = pièces du joueur après la partie
--   from, to   = { level, xp, need } avant / après la partie (la barre de niveau se remplit d'un état à l'autre)
--   challenges = défis du jour / de la semaine terminés pendant la partie (à récupérer dans le menu)
--   bp         = { tier, gained, frac, max, claimable } passe de combat
--   weekend, firstWin, firstWinLeft (première victoire du jour encore possible), featured (mode de la semaine)
-- }
-- Rien n'est crédité ici : tout l'a déjà été par RewardService / MedalService / ProgressService. On ne fait que décrire.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local X = require(ReplicatedStorage.Shared.ConfigExtra)
local Modes = require(ReplicatedStorage.Shared.Modes)
local DataService = require(script.Parent.DataService)
local RewardService = require(script.Parent.RewardService)
local LoyaltyService = require(script.Parent.LoyaltyService)
local MatchService = require(script.Parent.MatchService)

local RecapService = {}

local function lvl(xp: number): { level: number, xp: number, need: number }
	local l, cur, need = RewardService.levelInfo({ xp = xp })
	return { level = l, xp = cur, need = need }
end

table.insert(MatchService.finishHooks, function(m: any, p: Player, _s: any, _won: boolean, payload: { [string]: any })
	local r = payload.rewards
	local profile = DataService.get(p)
	if not r or not profile then return end
	local lines = table.clone(r.lines or {})
	if (r.medXp or 0) > 0 then table.insert(lines, { t = "Médailles", xp = r.medXp }) end
	-- passe de combat : palier atteint, avancée dans le palier, récompenses qui attendent
	local bp = profile.bp
	local bpInfo = nil
	if bp then
		local tier = math.min(X.SEASON.tiers, math.floor((bp.xp or 0) / X.SEASON.xpPerTier))
		local claimable = 0
		for t = 1, tier do
			if not table.find(bp.claimedFree or {}, t) then claimable += 1 end
			if bp.premium and not table.find(bp.claimedPremium or {}, t) then claimable += 1 end
		end
		bpInfo = { tier = tier, max = X.SEASON.tiers, gained = payload.progress and payload.progress.tiersGained or 0,
			frac = if tier >= X.SEASON.tiers then 1 else ((bp.xp or 0) % X.SEASON.xpPerTier) / X.SEASON.xpPerTier, claimable = claimable, premium = bp.premium == true }
	end
	local y = LoyaltyService.ensure(profile)
	payload.recap = {
		lines = lines, bonus = r.bonus or {}, xp = r.xp, coins = r.coins, coinsTotal = profile.coins,
		from = lvl(r.xpStart or profile.xp), to = lvl(profile.xp),
		challenges = RewardService.takeDone(p), bp = bpInfo,
		weekend = r.weekend == true, firstWin = r.firstWin == true, firstWinLeft = y.win ~= math.floor(os.time() / 86400),
		featured = m.mode == Modes.featured(),
	}
end)

return RecapService
