--!strict
-- ReplicatedStorage/Shared/LoyaltyConfig (ModuleScript)
-- Fidélité et Premium, mêmes valeurs que la version web (src/8W_loyalty.js) :
-- cadeaux de temps de jeu, paliers de série, rang de fidélité, bonus, abonnement Premium (Robux).
-- Économie lente conservée : ~35 pièces par partie, ces cadeaux ajoutent ~150 pièces par longue journée de jeu.
local L = {}

-- Cadeaux de temps de jeu : minutes jouées dans la journée (UTC), remis à zéro chaque jour
L.PLAYTIME_GIFTS = {
	{ minutes = 10, reward = { coins = 15 }, icon = "🪙" },
	{ minutes = 20, reward = { boost = 2 }, icon = "⚡" },
	{ minutes = 35, reward = { coins = 30 }, icon = "💰" },
	{ minutes = 50, reward = { coins = 45 }, icon = "💎" },
	{ minutes = 75, reward = { coins = 70, boost = 2 }, icon = "🎁" },
}

-- Paliers de la série de connexion (profile.streak, voir RewardService.claimDaily), chacun récupérable une fois
L.STREAK_GOALS = {
	{ days = 3, reward = { coins = 100 }, icon = "🔥" },
	{ days = 7, reward = { coins = 200, boost = 3 }, icon = "🔥" },
	{ days = 14, reward = { box = "std", coins = 150 }, icon = "📦" },
	{ days = 30, reward = { box = "prem", title = "loy_flame" }, icon = "👑" },
	{ days = 60, reward = { box = "prem", coins = 600 }, icon = "💠" },
	{ days = 100, reward = { box = "prem", n = 2, title = "loy_100" }, icon = "🏆" },
}

-- Rang de fidélité : nombre de jours où le joueur a fini au moins une partie. xp = bonus d'XP permanent en %.
L.TIERS = {
	{ days = 0, name = "Nouvelle recrue", color = Color3.fromRGB(141, 160, 189), xp = 0 },
	{ days = 3, name = "Habitué", color = Color3.fromRGB(125, 255, 159), xp = 2, reward = { coins = 100 } },
	{ days = 7, name = "Régulier", color = Color3.fromRGB(74, 163, 255), xp = 4, reward = { box = "std" } },
	{ days = 14, name = "Vétéran", color = Color3.fromRGB(199, 125, 255), xp = 6, reward = { coins = 300, title = "loy_vet" } },
	{ days = 30, name = "Fidèle", color = Color3.fromRGB(255, 215, 94), xp = 8, reward = { box = "prem", coins = 200 } },
	{ days = 60, name = "Pilier de l'arène", color = Color3.fromRGB(255, 122, 74), xp = 10, reward = { box = "prem", coins = 500, title = "loy_pillar" } },
	{ days = 100, name = "Légende fidèle", color = Color3.fromRGB(255, 70, 85), xp = 12, reward = { box = "prem", n = 2, coins = 800, title = "loy_legend" } },
}

L.TITLES = { loy_flame = "Flamme éternelle", loy_100 = "Centurion", loy_vet = "Vétéran", loy_pillar = "Pilier de l'arène",
	loy_legend = "Légende fidèle", vip = "⭐ Premium" }

L.FIRST_WIN = { xp = 100, coins = 25 }     -- première victoire du jour
L.BOOST_MULT = 0.5                          -- +50 % d'XP par partie de boost
L.BACK_DAYS = 3                             -- absence (jours) qui déclenche le cadeau « bon retour »
L.BACK_GIFT = { coins = 150, boost = 3 }

-- ---------- Abonnement Premium ----------
-- Developer Products (et pas Game Pass) : chaque achat ajoute des jours, cumulables. Crédité dans ShopService (seul ProcessReceipt).
-- Prix alignés sur les VIP des FPS Roblox (Arsenal VIP ~400 R$, RIVALS ~350 R$). productId = 0 tant que le produit n'est pas créé.
L.VIP = {
	xp = 0.2, coins = 0.2,                  -- +20 % XP et pièces en fin de partie
	daily = { coins = 60 },                 -- cadeau Premium chaque jour
	onPurchase = { box = "prem" },          -- offert à chaque achat
	offers = {
		{ id = "vip_30", days = 30, robux = 349, name = "Premium 30 jours", productId = 0 },
		{ id = "vip_90", days = 90, robux = 899, name = "Premium 90 jours", productId = 0, best = true },
	},
	-- Couleurs de pseudo (chat, tableau des scores, fil des éliminations). "rainbow" = dégradé animé côté client.
	colors = {
		{ id = "gold", name = "Or", color = Color3.fromRGB(255, 196, 40) },
		{ id = "neon", name = "Néon", color = Color3.fromRGB(95, 246, 255) },
		{ id = "rose", name = "Rose", color = Color3.fromRGB(255, 106, 213) },
		{ id = "emerald", name = "Émeraude", color = Color3.fromRGB(77, 255, 166) },
		{ id = "rainbow", name = "Arc-en-ciel", color = Color3.fromRGB(255, 255, 255) },
	},
}

function L.color(id: string?): Color3
	for _, c in ipairs(L.VIP.colors) do
		if c.id == id then return c.color end
	end
	return L.VIP.colors[1].color
end

-- Texte riche pour afficher un pseudo Premium (chat, futur HUD) : à partir des attributs « VipColor » posés par LoyaltyService
function L.richName(player: Player): string
	local name = player.DisplayName
	local col = player:GetAttribute("VipColor")
	if typeof(col) ~= "string" or col == "" then return name end
	if col == "rainbow" then
		local hues = { "#ff4655", "#ffb300", "#fff36a", "#4dff88", "#4aa3ff", "#c77dff" }
		local out = ""
		for i = 1, utf8.len(name) or 0 do
			local ch = string.sub(name, utf8.offset(name, i) or 1, (utf8.offset(name, i + 1) or (#name + 1)) - 1)
			out ..= string.format('<font color="%s">%s</font>', hues[(i - 1) % #hues + 1], ch)
		end
		return '<font color="#ffd24a">⭐</font> ' .. out
	end
	return string.format('<font color="#ffd24a">⭐</font> <font color="#%s">%s</font>', L.color(col):ToHex(), name)
end

return L
