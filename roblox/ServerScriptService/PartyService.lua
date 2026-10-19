--!strict
-- ServerScriptService/PartyService (ModuleScript)
-- Groupes d'amis (jusqu'à 5) + téléportation vers un serveur privé réservé.
-- Les invitations passent par SocialService (boîte de dialogue native Roblox) ; le chef lance la partie.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local MessagingService = game:GetService("MessagingService")

local PartyService = {}
local MAX_PARTY = 5

type Party = { id: string, leader: Player, members: { Player } }
local parties: { [string]: Party } = {}
local partyOf: { [Player]: string } = {}

local function remote(kind: string, name: string)
	local r = Instance.new(kind); r.Name = name; r.Parent = ReplicatedStorage; return r
end
local partyEvent = remote("RemoteEvent", "PartyUpdate") :: RemoteEvent
local createFn = remote("RemoteFunction", "PartyCreate") :: RemoteFunction
local joinFn = remote("RemoteFunction", "PartyJoin") :: RemoteFunction
local leaveFn = remote("RemoteFunction", "PartyLeave") :: RemoteFunction
local startFn = remote("RemoteFunction", "PartyStart") :: RemoteFunction

local function broadcast(party: Party)
	local names = {}
	for _, m in ipairs(party.members) do table.insert(names, { userId = m.UserId, name = m.DisplayName, leader = m == party.leader }) end
	for _, m in ipairs(party.members) do
		m:SetAttribute("Party", party.id); m:SetAttribute("PartyLeader", m == party.leader)   -- lus par le menu (groupes du serveur)
		partyEvent:FireClient(m, party.id, names)
	end
end

local function leave(player: Player)
	local id = partyOf[player]; if not id then return end
	local party = parties[id]; partyOf[player] = nil
	if not party then return end
	local i = table.find(party.members, player); if i then table.remove(party.members, i) end
	player:SetAttribute("Party", nil); player:SetAttribute("PartyLeader", nil)
	partyEvent:FireClient(player, nil, {})
	if #party.members == 0 then parties[id] = nil return end
	if party.leader == player then party.leader = party.members[1] end
	broadcast(party)
end

createFn.OnServerInvoke = function(player: Player)
	leave(player)
	local id = string.format("%d-%d", player.UserId, os.time())
	parties[id] = { id = id, leader = player, members = { player } }; partyOf[player] = id
	broadcast(parties[id])
	return id
end
function PartyService.join(player: Player, id: any): boolean
	if typeof(id) ~= "string" then return false end
	local party = parties[id]
	if not party or #party.members >= MAX_PARTY or table.find(party.members, player) then return false end
	leave(player)
	table.insert(party.members, player); partyOf[player] = id
	broadcast(party)
	return true
end
joinFn.OnServerInvoke = PartyService.join
-- invitation (SocialService, LaunchData = numéro du groupe) : l'ami qui arrive rejoint le groupe tout seul
Players.PlayerAdded:Connect(function(player: Player)
	local ok, data = pcall(function() return player:GetJoinData() end)
	local launch = ok and typeof(data) == "table" and data.LaunchData
	if typeof(launch) == "string" and string.sub(launch, 1, 6) == "party:" then
		task.delay(3, function() if player.Parent then PartyService.join(player, string.sub(launch, 7)) end end)
	end
end)
leaveFn.OnServerInvoke = function(player: Player) leave(player); return true end

-- Le chef lance : serveur réservé + téléportation de tout le groupe
-- toujours ce jeu-ci : un numéro de place venu du client enverrait tout le groupe vers n'importe quel jeu
local RateLimit = require(script.Parent.RateLimit)
startFn.OnServerInvoke = function(player: Player, _placeId: any)
	local id = partyOf[player]; local party = id and parties[id]
	if not party or party.leader ~= player or not RateLimit.ok(player, "PartyStart", 5) then return false end
	local pid = game.PlaceId
	local ok, code = pcall(function() return TeleportService:ReserveServer(pid) end)
	if not ok then return false end
	local opts = Instance.new("TeleportOptions"); opts.ReservedServerAccessCode = code
	opts:SetTeleportData({ partyId = party.id, size = #party.members })
	local ok2 = pcall(function() TeleportService:TeleportAsync(pid, party.members, opts) end)
	return ok2
end

-- Invitation d'un ami : ouvre la fenêtre native de Roblox (le client appelle SocialService:PromptGameInvite)
Players.PlayerRemoving:Connect(leave)

-- Équilibrage : les groupes arrivent dans la même équipe (utilisé par MatchService)
-- Membres du groupe d'un joueur (lui compris) ; seul s'il n'a pas de groupe
function PartyService.membersOf(player: Player): { Player }
	local id = partyOf[player]
	local party = id and parties[id]
	return if party then table.clone(party.members) else { player }
end
function PartyService.isLeader(player: Player): boolean
	local id = partyOf[player]
	local party = id and parties[id]
	return party == nil or party.leader == player
end

function PartyService.groupsOf(players: { Player }): { { Player } }
	local seen: { [string]: { Player } } = {}
	local solo: { { Player } } = {}
	for _, p in ipairs(players) do
		local id = partyOf[p]
		if id then seen[id] = seen[id] or {}; table.insert(seen[id], p) else table.insert(solo, { p }) end
	end
	local out = {}
	for _, g in pairs(seen) do table.insert(out, g) end
	for _, g in ipairs(solo) do table.insert(out, g) end
	table.sort(out, function(a, b) return #a > #b end)
	return out
end

return PartyService
