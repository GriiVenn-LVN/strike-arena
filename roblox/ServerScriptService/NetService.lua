--!strict
-- ServerScriptService/NetService (ModuleScript)
-- Réseau : mesure du ping + compensation de latence (« lag compensation ») pour le tir hitscan.
-- Le serveur garde un historique des positions des joueurs (1 s, à 30 Hz) ; quand un tir arrive,
-- il rejoue la scène au moment où le tireur a visé (now - ping - interpolation) avant de lancer le rayon.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local NetService = {}

local HISTORY_SECONDS = 1
local MAX_REWIND = 0.35                         -- on ne rembobine jamais plus de 350 ms (anti-abus des gros pings)
local history: { [Player]: { { t: number, cf: CFrame } } } = {}
local pings: { [Player]: number } = {}

local pingFn = Instance.new("RemoteFunction"); pingFn.Name = "Ping"; pingFn.Parent = ReplicatedStorage
pingFn.OnServerInvoke = function(_) return os.clock() end              -- le client mesure l'aller-retour
local pingReport = Instance.new("RemoteEvent"); pingReport.Name = "PingReport"; pingReport.Parent = ReplicatedStorage
pingReport.OnServerEvent:Connect(function(player: Player, rtt: any)
	if typeof(rtt) == "number" and rtt >= 0 and rtt < 2 then pings[player] = rtt end
end)

function NetService.pingOf(player: Player): number return pings[player] or 0.06 end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for _, p in ipairs(Players:GetPlayers()) do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local h = history[p] or {}; history[p] = h
			table.insert(h, { t = now, cf = root.CFrame })
			while #h > 0 and now - h[1].t > HISTORY_SECONDS do table.remove(h, 1) end
		end
	end
end)

local function sampleAt(p: Player, t: number): CFrame?
	local h = history[p]; if not h or #h == 0 then return nil end
	for i = #h, 2, -1 do
		if h[i - 1].t <= t then
			local a, b = h[i - 1], h[i]
			return a.cf:Lerp(b.cf, math.clamp((t - a.t) / math.max(b.t - a.t, 1e-4), 0, 1))
		end
	end
	return h[1].cf
end

-- Exécute fn pendant que les autres joueurs sont replacés à leur position passée.
function NetService.rewound<T>(shooter: Player, fn: () -> T): T
	local rewind = math.min(NetService.pingOf(shooter) / 2 + 0.05, MAX_REWIND)
	local target = os.clock() - rewind
	local saved: { [Player]: CFrame } = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= shooter then
			local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local past = sampleAt(p, target)
			if root and past then saved[p] = root.CFrame; root.CFrame = past end
		end
	end
	local ok, res = pcall(fn)
	for p, cf in pairs(saved) do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then root.CFrame = cf end
	end
	if not ok then error(res) end
	return res :: T
end

Players.PlayerRemoving:Connect(function(p) history[p] = nil; pings[p] = nil end)
return NetService
