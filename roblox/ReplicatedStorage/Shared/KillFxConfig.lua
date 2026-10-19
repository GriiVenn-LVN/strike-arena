--!strict
-- ReplicatedStorage/Shared/KillFxConfig (ModuleScript)
-- Effets d'élimination : ce qui arrive au corps de l'ennemi que TU élimines (comme dans Rivals ou Arsenal).
-- Purement visuel : aucun avantage de jeu. Joués par KillFxController (client), déclenchés par KillFxService (serveur).
--
-- source :
--   "coins"  = s'achète avec des pièces (price)
--   "robux"  = exclusif payant (robux + productId à créer dans le Creator Hub, 0 = « Bientôt »)
--   "code"   = seulement avec un code promo (ServerScriptService/CodeList)
--   "group"  = seulement en rejoignant le groupe Roblox (CommunityConfig.GROUP)
--   "event"  = récompense d'un palier de citrouilles de l'événement d'Halloween (pk = citrouilles), utilisable pendant l'événement
local KillFxConfig = {}

KillFxConfig.LIST = {
	{ id = "none", name = "Aucun effet", rarity = 1, source = "coins", price = 0 },
	{ id = "confetti", name = "Confettis", rarity = 2, source = "coins", price = 900 },
	{ id = "pixels", name = "Désintégration pixel", rarity = 3, source = "coins", price = 2000 },
	{ id = "ascend", name = "Envol céleste", rarity = 4, source = "coins", price = 5000 },
	{ id = "lightning", name = "Coup de foudre", rarity = 5, source = "robux", robux = 149, productId = 0 },
	{ id = "ice", name = "Statue de glace", rarity = 5, source = "robux", robux = 199, productId = 0 },
	{ id = "blackhole", name = "Trou noir", rarity = 5, source = "robux", robux = 299, productId = 0 },
	{ id = "pumpkins", name = "Pluie de citrouilles", rarity = 4, source = "code" },
	{ id = "spirit", name = "Esprit du groupe", rarity = 4, source = "group" },
	-- événement d'Halloween (src/8W_halloween.js) : paliers 15, 60 et 85 citrouilles
	{ id = "bats", name = "Nuée de chauves-souris", rarity = 4, source = "event", pk = 15 },
	{ id = "soul", name = "Âme damnée", rarity = 4, source = "event", pk = 60 },
	{ id = "grave", name = "Pierre tombale", rarity = 4, source = "event", pk = 85 },
}

local byId: { [string]: any } = {}
for _, fx in ipairs(KillFxConfig.LIST) do byId[fx.id] = fx end
function KillFxConfig.get(id: string): any
	return byId[id]
end

return KillFxConfig
