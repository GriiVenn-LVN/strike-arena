--!strict
-- ServerScriptService/MenuService (ModuleScript, requis par Main)
-- Ce dont le menu principal (StarterPlayerScripts/MainMenu) a besoin côté serveur :
--   ClaimWeekly(i)        récupérer un défi de la semaine (RewardService)
--   MenuSave(kind, data)  garder dans le profil les réglages de l'écran « Jouer » (kind = "play") et les Réglages (kind = "opts")
--   SetTitle(id)          titre de profil (niveau ou fidélité), recopié dans l'attribut « Title » du joueur
-- Le serveur vérifie tout : réglages passés par Modes.sanitize, nombres bornés, titre réellement débloqué.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Modes = require(ReplicatedStorage.Shared.Modes)
local MenuConfig = require(ReplicatedStorage.Shared.MenuConfig)
local LoyaltyConfig = require(ReplicatedStorage.Shared.LoyaltyConfig)
local DataService = require(script.Parent.DataService)
local RewardService = require(script.Parent.RewardService)

local MenuService = {}

local function remote(name: string, fn: (Player, ...any) -> any)
	local r = Instance.new("RemoteFunction"); r.Name = name; r.Parent = ReplicatedStorage; r.OnServerInvoke = fn
end

remote("ClaimWeekly", function(p: Player, index: any)
	if typeof(index) ~= "number" then return nil end
	return RewardService.claimWeekly(p, index)
end)

-- réglages du menu : bornés, un enregistrement toutes les 0,5 s au plus
local lastSave: { [Player]: number } = {}
local OPTS = { fov = { 60, 110, 70 }, sens = { 0.1, 4, 1 }, aimSens = { 0.2, 2, 1 }, vol = { 0, 1, 0.7 }, quality = { 1, 3, 3 } }
remote("MenuSave", function(p: Player, kind: any, data: any)
	local profile = DataService.get(p)
	if not profile or typeof(data) ~= "table" then return false end
	if os.clock() - (lastSave[p] or 0) < 0.5 then return false end
	lastSave[p] = os.clock()
	profile.menu = if typeof(profile.menu) == "table" then profile.menu else {}
	if kind == "play" then
		local s = Modes.sanitize(data)
		profile.menu.play = { mode = s.mode, map = s.map, diff = s.diff, size = s.size, limit = s.limit, side = s.side, eco = s.eco, mut = s.mut,
			friends = data.friends == true }
		return true
	elseif kind == "opts" then
		local o: { [string]: number } = {}
		for k, r in pairs(OPTS) do
			local v = data[k]
			o[k] = if typeof(v) == "number" and v == v then math.clamp(v, r[1], r[2]) else r[3]
		end
		o.quality = math.floor(o.quality + 0.5)
		profile.menu.opts = o
		return true
	end
	return false
end)

-- titres : ceux du niveau (MenuConfig.TITLES) et ceux de fidélité possédés (LoyaltyService, profile.loy.titles)
local function titleName(profile: any, id: string): string?
	if id == "" then return "" end
	local level = RewardService.levelInfo(profile)
	for _, t in ipairs(MenuConfig.TITLES) do
		if t.id == id then return if level >= t.lvl then t.n else nil end
	end
	local owned = profile.loy and profile.loy.titles or {}
	if table.find(owned, id) and LoyaltyConfig.TITLES[id] then return LoyaltyConfig.TITLES[id] end
	return nil
end
local function publishTitle(p: Player, profile: any)
	local id = profile.cosmetics and profile.cosmetics.title or ""
	local name = if typeof(id) == "string" then titleName(profile, id) else nil
	p:SetAttribute("Title", if name and name ~= "" then name else nil)
end
remote("SetTitle", function(p: Player, id: any)
	local profile = DataService.get(p)
	if not profile or typeof(id) ~= "string" or titleName(profile, id) == nil then return false end
	profile.cosmetics = profile.cosmetics or { attachments = {}, charm = "", trail = "", spray = "smile", title = "", knife = "classic" }
	profile.cosmetics.title = id
	publishTitle(p, profile)
	return true
end)

Players.PlayerAdded:Connect(function(p: Player)
	for _ = 1, 30 do
		local profile = DataService.get(p)
		if profile then publishTitle(p, profile); return end
		task.wait(1)
	end
end)
Players.PlayerRemoving:Connect(function(p: Player) lastSave[p] = nil end)

return MenuService
