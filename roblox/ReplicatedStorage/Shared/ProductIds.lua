--!strict
-- ReplicatedStorage/Shared/ProductIds (ModuleScript)
-- LE SEUL fichier à remplir pour activer les achats en Robux.
-- Pour chaque ligne : Creator Hub (create.roblox.com) → ton expérience → Monétisation → Produits pour développeurs
-- → « Créer un produit » avec le MÊME nom et le MÊME prix, puis colle ici le numéro du produit (ID).
-- Tant qu'un numéro vaut 0, le bouton correspondant affiche « Bientôt ».
return {
	-- Robux : pièces, caisses, passe de combat
	pass_premium = 0,   -- Passe de combat Premium · 399 R$
	coins_s = 0,        -- 300 pièces · 49 R$
	coins_m = 0,        -- 900 pièces · 129 R$
	coins_l = 0,        -- 2 200 pièces · 299 R$
	coins_xl = 0,       -- 5 500 pièces · 699 R$
	boxes_prem1 = 0,    -- 1 Caisse Premium · 79 R$
	boxes_prem5 = 0,    -- 5 Caisses Premium · 349 R$
	-- Exclusifs : camos animés
	camo_plasma = 0,    -- Camo animé Plasma · 299 R$
	camo_magma = 0,     -- Camo animé Magma vivant · 349 R$
	camo_code = 0,      -- Camo animé Code vivant · 249 R$
	camo_nebula = 0,    -- Camo animé Nébuleuse · 399 R$
	camo_prism = 0,     -- Camo animé Prisme · 449 R$
	camo_storm = 0,     -- Camo animé Tempête électrique · 349 R$
	camo_bundle = 0,    -- Collection des 6 camos animés · 1 299 R$
	-- Abonnement Premium
	vip_30 = 0,         -- Premium 30 jours · 349 R$
	vip_90 = 0,         -- Premium 90 jours · 899 R$
	-- Effets d'élimination
	killfx_lightning = 0, -- Coup de foudre · 149 R$
	killfx_ice = 0,       -- Statue de glace · 199 R$
	killfx_blackhole = 0, -- Trou noir · 299 R$
}
