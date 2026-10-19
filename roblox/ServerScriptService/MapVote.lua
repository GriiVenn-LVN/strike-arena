--!strict
-- ServerScriptService/MapVote (ModuleScript, appelé par MatchService pendant la pause entre deux parties)
-- Vote de la carte suivante, comme à la fin d'une partie de Call of Duty ou de Valorant :
-- trois cartes du mode (dont la carte jouée), un vote par joueur, la plus votée gagne (égalité : tirage au sort,
-- aucun vote : on reste sur la même carte).
--   « MapVote » (serveur -> joueurs de la partie) : { options = { { id, n, theme } }, votes = { n1, n2, n3 }, left = s, mine = i? }
--     ou { done = id } quand le vote se termine.
--   « MapVoteCast » (joueur -> serveur) : numéro de la carte (1 à 3). Le serveur vérifie que le joueur est dans la partie.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modes = require(ReplicatedStorage.Shared.Modes)

local push = Instance.new("RemoteEvent"); push.Name = "MapVote"; push.Parent = ReplicatedStorage
local cast = Instance.new("RemoteEvent"); cast.Name = "MapVoteCast"; cast.Parent = ReplicatedStorage

type Vote = { m: any, options: { string }, ballots: { [Player]: number }, endsAt: number }
local votes: { [any]: Vote } = {}          -- par partie
local byPlayer: { [Player]: Vote } = {}

local MapVote = {}

local function counts(v: Vote): { number }
	local c = table.create(#v.options, 0)
	for _, i in pairs(v.ballots) do c[i] += 1 end
	return c
end

local function send(v: Vote, only: Player?)
	local opts = {}
	for _, id in ipairs(v.options) do
		local def = Modes.MAP[id]
		table.insert(opts, { id = id, n = def and def.n or id, theme = def and def.theme or "" })
	end
	local c, left = counts(v), math.max(0, math.ceil(v.endsAt - os.clock()))
	for p in pairs(v.m.players) do
		if not only or only == p then push:FireClient(p, { options = opts, votes = c, left = left, mine = v.ballots[p] }) end
	end
end

-- ouvre le vote ; « seconds » = durée de la pause. Rien si le mode n'a qu'une carte (Zombies, Entraînement).
function MapVote.open(m: any, seconds: number)
	local pool = Modes.mapsFor(m.mode)
	if #pool < 2 or seconds < 4 then return end
	local cur = m.settings.map
	local others = {}
	for _, id in ipairs(pool) do if id ~= cur then table.insert(others, id) end end
	local options = { cur }
	while #options < 3 and #others > 0 do table.insert(options, table.remove(others, math.random(#others)) :: string) end
	local v: Vote = { m = m, options = options, ballots = {}, endsAt = os.clock() + seconds - 1.5 }
	votes[m] = v
	for p in pairs(m.players) do byPlayer[p] = v end
	send(v)
end

-- ferme le vote et règle la carte de la partie suivante
function MapVote.close(m: any)
	local v = votes[m]
	if not v then return end
	votes[m] = nil
	local c = counts(v)
	local best, list = 0, {}
	for i, n in ipairs(c) do
		if n > best then best, list = n, { i } elseif n == best and n > 0 then table.insert(list, i) end
	end
	local id = if #list > 0 then v.options[list[math.random(#list)]] else m.settings.map
	m.settings.map = id
	for p in pairs(m.players) do
		if byPlayer[p] == v then byPlayer[p] = nil end
		push:FireClient(p, { done = id, n = Modes.MAP[id] and Modes.MAP[id].n or id })
	end
end

cast.OnServerEvent:Connect(function(p: Player, i: any)
	local v = byPlayer[p]
	if not v or votes[v.m] ~= v or not v.m.players[p] then return end
	if typeof(i) ~= "number" or i ~= math.floor(i) or not v.options[i] or os.clock() > v.endsAt then return end
	v.ballots[p] = i
	send(v)
end)

game:GetService("Players").PlayerRemoving:Connect(function(p: Player)
	local v = byPlayer[p]
	if v then v.ballots[p] = nil end
	byPlayer[p] = nil
end)

return MapVote
