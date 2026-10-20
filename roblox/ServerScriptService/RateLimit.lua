--!strict
-- ServerScriptService/RateLimit (ModuleScript)
-- Cadence des remotes de récompenses et de boutique : un joueur ne peut pas appeler la même action plus d'une fois
-- toutes les `gap` secondes (un client modifié qui spamme ne fait que recevoir des refus).
--   if not RateLimit.ok(player, "ShopBuy", 0.4) then return { ok = false, err = "Doucement !" } end
local Players = game:GetService("Players")

local RateLimit = {}
local last: { [Player]: { [string]: number } } = {}

function RateLimit.ok(player: Player, key: string, gap: number): boolean
	local t = os.clock()
	local mine = last[player]
	if not mine then mine = {}; last[player] = mine end
	local prev = mine[key]
	if prev and t - prev < gap then return false end
	mine[key] = t
	return true
end

Players.PlayerRemoving:Connect(function(p) last[p] = nil end)

return RateLimit
