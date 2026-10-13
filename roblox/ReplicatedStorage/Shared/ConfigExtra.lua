--!strict
-- Config partagée (extensions) : agents, modes, passe de combat, classement, succès, événement, accessoires...
-- Valeurs identiques au prototype web (src/63_agents.js, 64_extras.js, 66_progress.js, 67_immersion.js).
local X = {}

-- ---------- Agents : 2 capacités, recharge en secondes ----------
X.AGENTS = {
	none = { name = "Recrue", abilities = {} },
	nova = { name = "Nova", abilities = { { id = "smoke", name = "Fumigène", cd = 26 }, { id = "flash", name = "Flash", cd = 20 } } },
	pulse = { name = "Pulse", abilities = { { id = "scan", name = "Scan", cd = 30, radius = 34, duration = 3.2 }, { id = "sprint", name = "Sprint", cd = 24, duration = 4, mult = 1.35 } } },
	aegis = { name = "Aegis", abilities = { { id = "shield", name = "Bouclier", cd = 40, amount = 50 }, { id = "dome", name = "Dôme", cd = 36, duration = 4, reduction = 0.5 } } },
	mender = { name = "Mender", abilities = { { id = "heal", name = "Soin", cd = 32, hps = 15, duration = 3.2, radius = 9 }, { id = "resupply", name = "Ravitaillement", cd = 40 } } },
	phantom = { name = "Phantom", abilities = { { id = "dash", name = "Dash", cd = 14, speed = 46, duration = 0.2 }, { id = "mine", name = "Mine", cd = 28, radius = 5, damage = 95, max = 2, armTime = 1 } } },
}

-- ---------- Modes ----------
X.MODES = {
	bomb = { name = "Compétitif", team = true, roundsToWin = { 3, 5, 7, 13 } },
	rapid = { name = "Désamorçage rapide", team = true, roundTime = 45, freezeTime = 6, roundsToWin = { 5, 7, 9 }, freeWeapons = true },
	tdm = { name = "Match à mort par équipe", team = true, respawn = 3, killsToWin = { 20, 30, 40, 60 } },
	koth = { name = "Capture de zone", team = true, respawn = 3, pointsToWin = { 100, 200, 300 }, zoneMoveEvery = 60, zoneRadius = 5 },
	zombies = { name = "Zombies (coop)", team = true, waves = { 5, 8, 12 } },
	ffa = { name = "Match à mort", team = false, respawn = 2, killsToWin = { 15, 25, 35 } },
	gg = { name = "Course aux armes", team = false, respawn = 1.5 },
	br = { name = "Bataille royale", team = false, zonePhases = 5, startRadius = 62 },
	train = { name = "Entraînement", team = false, duration = 60 },
}

-- ---------- Accessoires d'armes ----------
X.ATTACHMENTS = {
	sil = { name = "Silencieux", minLevel = 1, damageMult = 0.92, hearingRange = 16 },
	opt = { name = "Point rouge", minLevel = 3, adsSpreadMult = 0.75 },
	ext = { name = "Chargeur étendu", minLevel = 2, magMult = 1.3 },
	grip = { name = "Poignée verticale", minLevel = 4, recoilMult = 0.82 },
}
X.TRAILS = { "", "cyan", "red", "lime", "gold", "violet", "rainbow" }
X.CHARMS = { "", "cube", "heart", "star", "bear", "orb", "skull", "bolt" }
X.SPRAYS = { "smile", "heart", "skull", "bolt", "flame", "crown", "target", "ghost" }
X.KNIVES = { "classic", "karambit", "bayonet", "tanto" }

-- ---------- Passe de combat ----------
X.SEASON = { id = "s1", name = "Saison 1 · Néon", tiers = 30, xpPerTier = 180, premiumRobux = 499, premiumCoins = 1500 }
function X.bpReward(tier: number, premium: boolean)
	if not premium then
		if tier == X.SEASON.tiers then return { box = "prem", coins = 300 } end
		if tier % 5 == 0 then return { box = "std", coins = 100 } end
		return { coins = 60 + tier * 8 }
	end
	if tier == 1 then return { box = "prem" } end
	if tier % 5 == 0 then return { item = true, rarity = if tier >= 25 then 4 elseif tier >= 10 then 3 else 2 } end -- choisi côté serveur (graine = palier)
	return { coins = 100 + tier * 10 }
end

-- ---------- Classement ----------
X.RANKS = { "Bronze", "Argent", "Or", "Platine", "Diamant", "Maître" } -- 3 divisions chacun puis Légende (18 = Légende)
X.RANK_RP_PER_DIVISION = 100
X.RANKED_MODES = { bomb = true, rapid = true, tdm = true, koth = true }
function X.rankDelta(won: boolean, difficulty: number): number
	return if won then 18 + difficulty * 4 else -math.max(8, 20 - difficulty * 3)
end
function X.rankName(rp: number): string
	local idx = math.min(18, math.floor(rp / X.RANK_RP_PER_DIVISION))
	if idx >= 18 then return "Légende" end
	return X.RANKS[idx // 3 + 1] .. " " .. ({ "I", "II", "III" })[idx % 3 + 1]
end

-- ---------- Succès (BadgeService : renseigne badgeId après création dans le Creator Hub) ----------
X.ACHIEVEMENTS = {
	{ id = "first", name = "Premier sang", coins = 50, stat = "kills", target = 1 },
	{ id = "k100", name = "Centurion", coins = 200, stat = "kills", target = 100 },
	{ id = "k500", name = "Machine de guerre", coins = 500, stat = "kills", target = 500 },
	{ id = "hs50", name = "Chasseur de têtes", coins = 250, stat = "hs", target = 50 },
	{ id = "win1", name = "Première victoire", coins = 100, stat = "wins", target = 1 },
	{ id = "win10", name = "Champion", coins = 400, stat = "wins", target = 10 },
	{ id = "play20", name = "Habitué", coins = 300, stat = "matches", target = 20 },
	{ id = "streak8", name = "Série infernale", coins = 300, stat = "bestStreak", target = 8 },
	{ id = "ace", name = "Ace", coins = 300, match = "kills", target = 10 },
	{ id = "royal", name = "Dernier survivant", coins = 350, match = "brWin", target = 1 },
	{ id = "zomb", name = "Exterminateur", coins = 350, match = "zombieWave", target = 5 },
	{ id = "koth", name = "Roi de la colline", coins = 300, match = "kothWin", target = 1 },
	{ id = "train", name = "Sur cible", coins = 250, match = "trainScore", target = 3000 },
	{ id = "gold", name = "Chasseur d'or", coins = 400, rank = 6 },
}

-- ---------- Événement limité ----------
X.EVENT = {
	id = "hw", name = "Nuit d'Halloween", from = "2026-10-01", to = "2026-11-07", pumpkinsPerMatch = 7,
	goals = { { n = 10, coins = 300 }, { n = 25, box = "std", coins = 200 }, { n = 50, box = "prem" }, { n = 100, box = "prem", coins = 800, dance = "moonwalk" } },
}

-- ---------- Ambiance ----------
X.WEATHER = {
	clear = { fogEnd = 1, sun = 1 },
	rain = { fogEnd = 0.72, sun = 0.55, rain = true },
	storm = { fogEnd = 0.55, sun = 0.3, rain = true, lightning = true },
	fog = { fogStart = 4, fogEnd = 75, sun = 0.6 },
}
X.TIME_OF_DAY = { day = 14, dusk = 18.2, night = 23 } -- Lighting.ClockTime

-- ---------- Boutique cosmétique (aucun avantage de gameplay) ----------
X.SHOP = {
	{ id = "pass_premium", kind = "devproduct", robux = 499, name = "Passe de combat Premium", productId = 0 },
	{ id = "coins_s", kind = "devproduct", robux = 99, name = "500 pièces", productId = 0, coins = 500 },
	{ id = "coins_m", kind = "devproduct", robux = 249, name = "1500 pièces", productId = 0, coins = 1500 },
	{ id = "coins_l", kind = "devproduct", robux = 599, name = "4000 pièces", productId = 0, coins = 4000 },
	{ id = "title_pack", kind = "coins", price = 800, name = "Pack de titres de profil" },
	{ id = "trail_gold", kind = "coins", price = 1200, name = "Traînée Or" },
}

return X
