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

-- ---------- Viseurs personnalisables (boutique) ----------
-- Purement visuels : l'effet de jeu reste celui de l'accessoire « Point rouge » (X.ATTACHMENTS.opt), pour ne rien vendre qui donne un avantage.
-- SIGHTS = modèle d'optique posé sur l'arme (un par arme), RETICLES = forme et couleur du point de visée (un pour toutes les armes).
X.SIGHTS = {
	{ id = "reddot", name = "Point rouge", rarity = 1 },
	{ id = "holo", name = "Holographique", rarity = 1 },
	{ id = "mini", name = "Mini-reflex", rarity = 2 },
	{ id = "tube", name = "Tube tactique", rarity = 2 },
	{ id = "x2", name = "Lunette x2", rarity = 3 },
	{ id = "acog", name = "ACOG x4", rarity = 3 },
	{ id = "neon", name = "Néon", rarity = 4 },
}
X.RETICLES = {
	{ id = "dot_red", name = "Point rouge", shape = "dot", color = Color3.fromRGB(255, 60, 60), rarity = 1 },
	{ id = "cross_green", name = "Croix verte", shape = "cross", color = Color3.fromRGB(80, 255, 120), rarity = 1 },
	{ id = "circle_cyan", name = "Cercle cyan", shape = "circle", color = Color3.fromRGB(60, 230, 255), rarity = 2 },
	{ id = "chevron_yellow", name = "Chevron jaune", shape = "chevron", color = Color3.fromRGB(255, 220, 60), rarity = 2 },
	{ id = "tdot_white", name = "T blanc", shape = "t", color = Color3.fromRGB(255, 255, 255), rarity = 2 },
	{ id = "circledot_pink", name = "Cercle-point rose", shape = "circledot", color = Color3.fromRGB(255, 90, 200), rarity = 3 },
	{ id = "skull_gold", name = "Crâne doré", shape = "skull", color = Color3.fromRGB(255, 185, 56), rarity = 4 },
}
X.TRAILS = { "", "cyan", "red", "lime", "gold", "violet", "rainbow" }
X.CHARMS = { "", "cube", "heart", "star", "bear", "orb", "skull", "bolt" }
X.SPRAYS = { "smile", "heart", "skull", "bolt", "flame", "crown", "target", "ghost" }
X.KNIVES = { "classic", "karambit", "bayonet", "tanto" }

-- ---------- Passe de combat ----------
X.SEASON = { id = "s1", name = "Saison 1 · Néon", tiers = 30, xpPerTier = 900, premiumRobux = 399, premiumCoins = 3500 }
function X.bpReward(tier: number, premium: boolean)
	if not premium then
		if tier == X.SEASON.tiers then return { box = "prem", coins = 200 } end
		if tier % 10 == 0 then return { box = "std", coins = 60 } end
		return { coins = 20 + tier * 2 }
	end
	if tier == 1 then return { box = "prem" } end
	if tier % 5 == 0 then return { item = true, rarity = if tier >= 25 then 4 elseif tier >= 10 then 3 else 2 } end -- choisi côté serveur (graine = palier)
	return { coins = 40 + tier * 4 }
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

-- ---------- Boutique : produits Robux (Developer Products) ----------
-- Prix alignés sur les FPS Roblox comparables (Arsenal, RIVALS, Phantom Forces) : petit pack ~50 R$, passe de combat 399 R$,
-- objet cosmétique exclusif 249-449 R$, gros lot ~1300 R$.
-- Renseigne productId après création de chaque produit dans le Creator Hub (0 = bouton désactivé). Voir README_ROBLOX.md.
X.SHOP = {
	{ id = "pass_premium", kind = "devproduct", robux = 399, name = "Passe de combat Premium", productId = 0, premium = true },
	{ id = "coins_s", kind = "devproduct", robux = 49, name = "300 pièces", productId = 0, coins = 300 },
	{ id = "coins_m", kind = "devproduct", robux = 129, name = "900 pièces", productId = 0, coins = 900 },
	{ id = "coins_l", kind = "devproduct", robux = 299, name = "2 200 pièces", productId = 0, coins = 2200 },
	{ id = "coins_xl", kind = "devproduct", robux = 699, name = "5 500 pièces", productId = 0, coins = 5500 },
	{ id = "boxes_prem1", kind = "devproduct", robux = 79, name = "1 Caisse Premium", productId = 0, box = "prem", boxes = 1 },
	{ id = "boxes_prem5", kind = "devproduct", robux = 349, name = "5 Caisses Premium", productId = 0, box = "prem", boxes = 5 },
}

-- ---------- Exclusifs payants : camos animés ----------
-- Ne s'obtiennent QU'en Robux (jamais dans les caisses, le passe ou contre des pièces). Un camo s'applique à toutes les armes.
-- anim = paramètres de l'animation de texture (défilement en studs/s, pulsation de l'éclat), même rendu que le prototype web.
X.EXCLUSIVES = {
	{ id = "camo_plasma", camo = "plasma", name = "Camo animé Plasma", robux = 299, productId = 0, anim = { scroll = 0.6, pulse = 1.2, colors = { "#7a1fff", "#ff2bd6", "#21e6c1" } } },
	{ id = "camo_magma", camo = "magma", name = "Camo animé Magma vivant", robux = 349, productId = 0, anim = { scroll = 0.3, pulse = 2.2, colors = { "#1a0806", "#ff6a14", "#ffd070" } } },
	{ id = "camo_code", camo = "code", name = "Camo animé Code vivant", robux = 249, productId = 0, anim = { scroll = 1.5, pulse = 0, colors = { "#021209", "#3ce678", "#e6fff0" } } },
	{ id = "camo_nebula", camo = "nebula", name = "Camo animé Nébuleuse", robux = 399, productId = 0, anim = { scroll = 0.2, pulse = 0.8, colors = { "#07051a", "#3a4bff", "#d84bff" } } },
	{ id = "camo_prism", camo = "prism", name = "Camo animé Prisme", robux = 449, productId = 0, anim = { scroll = 0.8, pulse = 0, colors = { "#ff3b3b", "#3bff8a", "#3b7bff" } } },
	{ id = "camo_storm", camo = "storm", name = "Camo animé Tempête électrique", robux = 349, productId = 0, anim = { scroll = 0, pulse = 9, colors = { "#0a0f1a", "#3caaff", "#c8f2ff" } } },
	{ id = "camo_bundle", camos = { "plasma", "magma", "code", "nebula", "prism", "storm" }, name = "Collection des 6 camos animés", robux = 1299, productId = 0 },
}

return X
