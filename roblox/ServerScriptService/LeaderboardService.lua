--!strict
-- ServerScriptService/LeaderboardService (ModuleScript)
-- Classement géant du lobby : meilleurs tueurs de la SEMAINE (remis à zéro chaque lundi) et classement des duels.
-- Les scores vivent dans des OrderedDataStore (partagés par tous les serveurs du jeu) ; le panneau se met à jour
-- toutes les CommunityConfig.LEADERBOARD.refresh secondes. Les éliminations sont regroupées avant l'envoi
-- pour respecter les limites de requêtes de Roblox.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CommunityConfig = require(ReplicatedStorage.Shared.CommunityConfig)
local LB = CommunityConfig.LEADERBOARD

local LeaderboardService = {}

local function weeklyStore(week: number): OrderedDataStore
	return DataStoreService:GetOrderedDataStore("WeeklyKills_" .. week)
end
local duelStore = DataStoreService:GetOrderedDataStore("DuelElo_v1")

-- ---------- écriture ----------
local pendingKills: { [number]: number } = {}      -- userId -> éliminations pas encore envoyées
local pendingElo: { [number]: number } = {}

function LeaderboardService.addKills(player: Player, n: number)
	if n <= 0 then return end
	pendingKills[player.UserId] = (pendingKills[player.UserId] or 0) + n
end

function LeaderboardService.setDuelElo(player: Player, elo: number)
	pendingElo[player.UserId] = math.floor(elo)
end

local function flush()
	local week = CommunityConfig.weekId()
	local store = weeklyStore(week)
	local kills = pendingKills; pendingKills = {}
	for userId, n in pairs(kills) do
		local ok, err = pcall(function() store:IncrementAsync("u_" .. userId, n) end)
		if not ok then
			warn("[Leaderboard] envoi des éliminations échoué :", err)
			pendingKills[userId] = (pendingKills[userId] or 0) + n
		end
	end
	local elos = pendingElo; pendingElo = {}
	for userId, elo in pairs(elos) do
		local ok = pcall(function() duelStore:SetAsync("u_" .. userId, elo) end)
		if not ok and not pendingElo[userId] then pendingElo[userId] = elo end
	end
end

-- ---------- lecture ----------
local nameCache: { [number]: string } = {}
local function nameOf(userId: number): string
	if nameCache[userId] then return nameCache[userId] end
	local p = Players:GetPlayerByUserId(userId)
	if p then nameCache[userId] = p.DisplayName; return p.DisplayName end
	local ok, name = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
	nameCache[userId] = if ok and name then name else "Joueur"
	return nameCache[userId]
end

local function top(store: OrderedDataStore): { { name: string, value: number, userId: number } }
	local out = {}
	local ok, pages = pcall(function() return store:GetSortedAsync(false, LB.top) end)
	if not ok or not pages then return out end
	for _, entry in ipairs((pages :: any):GetCurrentPage()) do
		local userId = tonumber(string.sub(entry.key, 3)) or 0
		table.insert(out, { name = nameOf(userId), value = entry.value, userId = userId })
	end
	return out
end

-- ---------- panneau ----------
local MEDALS = { Color3.fromRGB(255, 205, 60), Color3.fromRGB(205, 212, 222), Color3.fromRGB(215, 140, 70) }
local columns: { [string]: Frame } = {}
local footer: TextLabel? = nil

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local o: any = Instance.new(className)
	if className == "TextLabel" then
		o.BackgroundTransparency = 1; o.Font = Enum.Font.GothamBold; o.TextColor3 = Color3.new(1, 1, 1); o.TextScaled = true
	end
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end

local function buildBoard(board: BasePart)
	local sg = make("SurfaceGui", { Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 12, LightInfluence = 0 }, board)
	make("TextLabel", { Size = UDim2.new(1, 0, 0.12, 0), Position = UDim2.fromScale(0, 0.02), Text = "🏆 CLASSEMENT", Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(255, 200, 60) }, sg)
	local function column(id: string, title: string, x: number)
		local col = make("Frame", { Size = UDim2.fromScale(0.46, 0.74), Position = UDim2.fromScale(x, 0.16), BackgroundColor3 = Color3.fromRGB(24, 30, 46), BorderSizePixel = 0 }, sg)
		make("UICorner", { CornerRadius = UDim.new(0.03, 0) }, col)
		make("TextLabel", { Size = UDim2.new(1, -20, 0.1, 0), Position = UDim2.new(0, 10, 0.02, 0), Text = title, TextColor3 = Color3.fromRGB(150, 200, 255) }, col)
		local list = make("Frame", { Name = "List", Size = UDim2.new(1, -20, 0.84, 0), Position = UDim2.new(0, 10, 0.14, 0), BackgroundTransparency = 1 }, col)
		make("UIListLayout", { Padding = UDim.new(0.01, 0), SortOrder = Enum.SortOrder.LayoutOrder }, list)
		columns[id] = list
	end
	column("kills", "⚔️ Éliminations de la semaine", 0.03)
	column("duel", "🥊 Meilleurs duellistes", 0.51)
	footer = make("TextLabel", { Size = UDim2.new(0.9, 0, 0.06, 0), Position = UDim2.fromScale(0.05, 0.92), Text = "", TextColor3 = Color3.fromRGB(170, 180, 200), Font = Enum.Font.Gotham }, sg)
end

local function fillColumn(id: string, rows: { any }, fmt: (number) -> string)
	local list = columns[id]
	if not list then return end
	for _, c in ipairs(list:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
	if #rows == 0 then
		local row = make("Frame", { Size = UDim2.fromScale(1, 0.09), BackgroundTransparency = 1 }, list)
		make("TextLabel", { Size = UDim2.fromScale(1, 1), Text = "Personne pour l'instant : à toi de jouer !", TextColor3 = Color3.fromRGB(150, 160, 180) }, row)
		return
	end
	for i, r in ipairs(rows) do
		local row = make("Frame", { Size = UDim2.fromScale(1, 0.09), BackgroundColor3 = Color3.fromRGB(34, 42, 62), BackgroundTransparency = if i % 2 == 0 then 0.4 else 0.1,
			BorderSizePixel = 0, LayoutOrder = i }, list)
		local color = MEDALS[i] or Color3.new(1, 1, 1)
		make("TextLabel", { Size = UDim2.fromScale(0.12, 0.8), Position = UDim2.fromScale(0.02, 0.1), Text = "#" .. i, TextColor3 = color, Font = Enum.Font.GothamBlack }, row)
		make("TextLabel", { Size = UDim2.fromScale(0.58, 0.8), Position = UDim2.fromScale(0.15, 0.1), Text = r.name, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left }, row)
		make("TextLabel", { Size = UDim2.fromScale(0.25, 0.8), Position = UDim2.fromScale(0.73, 0.1), Text = fmt(r.value), TextXAlignment = Enum.TextXAlignment.Right }, row)
	end
end

local function refresh()
	fillColumn("kills", top(weeklyStore(CommunityConfig.weekId())), function(v) return tostring(v) end)
	fillColumn("duel", top(duelStore), function(v)
		return CommunityConfig.duelRank(v).name .. " · " .. v
	end)
	local left = CommunityConfig.secondsToNextWeek()
	if footer then
		footer.Text = string.format("Remise à zéro des éliminations dans %d j %d h · mis à jour toutes les %d s",
			left // 86400, (left % 86400) // 3600, LB.refresh)
	end
end

function LeaderboardService.start(board: BasePart?)
	if board then buildBoard(board) end
	task.spawn(function()
		while true do
			pcall(flush)
			if board then pcall(refresh) end
			task.wait(LB.refresh)
		end
	end)
end

Players.PlayerRemoving:Connect(function(p) nameCache[p.UserId] = nil end)
game:BindToClose(function()
	if RunService:IsStudio() then return end
	pcall(flush)
end)

return LeaderboardService
