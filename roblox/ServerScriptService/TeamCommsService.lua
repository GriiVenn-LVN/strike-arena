--!strict
-- ServerScriptService/TeamCommsService (ModuleScript, requis par Main)
-- Communication d'équipe tirée d'autres jeux (ping d'Apex / Valorant, radio de CS) :
--   • Ping (clic molette ou K) : marque un point ou un ennemi pour toute l'équipe pendant quelques secondes.
--     Remote « TeamPing » (joueur -> serveur : position, modèle visé ou nil) puis « TeamPingShow »
--     (serveur -> coéquipiers : position, genre "spot" | "enemy", nom de l'auteur, modèle visé).
--   • Messages rapides (touche N puis 1 à 6) : « QuickChat » (joueur -> serveur : numéro) puis
--     « QuickChatShow » (serveur -> coéquipiers : nom, numéro). Les textes sont dans Shared/TeamComms.
-- Le serveur vérifie tout : joueur en vie dans une partie, cadence limitée, point pas trop loin,
-- cible = vrai ennemi de la même partie. En chacun pour soi, seul l'auteur voit son ping.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TeamComms = require(ReplicatedStorage.Shared.TeamComms)
local WeaponService = require(script.Parent.WeaponService)
local MatchService = require(script.Parent.MatchService)

local function remote(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent"); r.Name = name; r.Parent = ReplicatedStorage; return r
end
local pingIn, pingOut = remote("TeamPing"), remote("TeamPingShow")
local chatIn, chatOut = remote("QuickChat"), remote("QuickChatShow")

local MAX_DIST = 900          -- studs : au-delà, le point ne peut pas venir de la vue du joueur
local lastPing: { [Player]: number } = {}
local lastChat: { [Player]: number } = {}

local TeamCommsService = {}

-- coéquipiers de p dans sa partie (p compris) ; en chacun pour soi (« solo:… ») : p seul
local function mates(p: Player): { Player }
	local m = MatchService.matchOf(p)
	local team = WeaponService.teamOf(p)
	if not m or not team or string.sub(team, 1, 5) == "solo:" then return { p } end
	local list = {}
	for q in pairs(m.players) do
		if WeaponService.teamOf(q) == team then table.insert(list, q) end
	end
	return list
end

local function aliveRoot(p: Player): BasePart?
	local ch = MatchService.aliveChar(p)
	return ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
end

pingIn.OnServerEvent:Connect(function(p: Player, pos: any, target: any)
	if typeof(pos) ~= "Vector3" or pos ~= pos then return end           -- refuse NaN
	local now = os.clock()
	if now - (lastPing[p] or 0) < TeamComms.PING_COOLDOWN then return end
	local root = aliveRoot(p)
	if not root or (pos - root.Position).Magnitude > MAX_DIST then return end
	lastPing[p] = now
	local kind, model = "spot", nil
	if typeof(target) == "Instance" and target:IsA("Model") then
		local m = MatchService.matchOf(p)
		local c = WeaponService.combatantOf(target)
		local team, mine = WeaponService.teamOf(c), WeaponService.teamOf(p)
		if m and MatchService.matchOf(c) == m and team and team ~= mine and MatchService.aliveChar(c) then
			kind, model = "enemy", target
		end
	end
	for _, q in ipairs(mates(p)) do pingOut:FireClient(q, pos, kind, p.DisplayName, model) end
end)

chatIn.OnServerEvent:Connect(function(p: Player, index: any)
	if typeof(index) ~= "number" or not TeamComms.LINES[index] then return end
	local now = os.clock()
	if now - (lastChat[p] or 0) < TeamComms.CHAT_COOLDOWN then return end
	if not MatchService.matchOf(p) then return end
	lastChat[p] = now
	for _, q in ipairs(mates(p)) do chatOut:FireClient(q, p.DisplayName, index) end
end)

Players.PlayerRemoving:Connect(function(p: Player) lastPing[p] = nil; lastChat[p] = nil end)

return TeamCommsService
