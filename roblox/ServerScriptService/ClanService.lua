--!strict
-- ServerScriptService/ClanService (ModuleScript) — base pour les clans
-- Un clan = tag de 3-4 lettres, couleur, membres (max 30), stats cumulées. Stocké dans un DataStore dédié.
-- Version minimale : création, rejoindre, quitter, tag affiché dans le profil. À étendre (salon, classement, guerres).
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local DataService = require(script.Parent.DataService)
local STORE = DataStoreService:GetDataStore("StrikeArenaClans_v1")
local MAX_MEMBERS = 30
local CREATE_COST = 2000

local ClanService = {}

local function clean(tag: string, player: Player): string?
	tag = string.upper((tag:gsub("[^%w]", "")))
	if #tag < 3 or #tag > 4 then return nil end
	local ok, res = pcall(function() return TextService:FilterStringAsync(tag, player.UserId):GetNonChatStringForBroadcastAsync() end)
	if not ok or res ~= tag then return nil end                           -- refuse les tags filtrés
	return tag
end

local createFn = Instance.new("RemoteFunction"); createFn.Name = "ClanCreate"; createFn.Parent = ReplicatedStorage
createFn.OnServerInvoke = function(player: Player, tag: any, color: any)
	if typeof(tag) ~= "string" or typeof(color) ~= "Color3" then return false, "invalide" end
	local profile = DataService.get(player); if not profile then return false, "pas de profil" end
	if profile.clan then return false, "déjà dans un clan" end
	if profile.coins < CREATE_COST then return false, "pièces insuffisantes" end
	local t = clean(tag, player); if not t then return false, "tag refusé" end
	local created = false
	local ok = pcall(function()
		STORE:UpdateAsync("clan_" .. t, function(old)
			if old then return nil end                                       -- tag déjà pris
			created = true
			return { tag = t, color = { color.R, color.G, color.B }, owner = player.UserId, members = { player.UserId }, kills = 0, wins = 0 }
		end)
	end)
	if not ok or not created then return false, "tag déjà utilisé" end
	profile.coins -= CREATE_COST; profile.clan = t
	return true
end

local joinFn = Instance.new("RemoteFunction"); joinFn.Name = "ClanJoin"; joinFn.Parent = ReplicatedStorage
joinFn.OnServerInvoke = function(player: Player, tag: any)
	if typeof(tag) ~= "string" then return false end
	local profile = DataService.get(player); if not profile or profile.clan then return false end
	local t = string.upper(tag)
	local joined = false
	pcall(function()
		STORE:UpdateAsync("clan_" .. t, function(old)
			if not old or #old.members >= MAX_MEMBERS or table.find(old.members, player.UserId) then return nil end
			table.insert(old.members, player.UserId); joined = true
			return old
		end)
	end)
	if joined then profile.clan = t end
	return joined
end

local leaveFn = Instance.new("RemoteFunction"); leaveFn.Name = "ClanLeave"; leaveFn.Parent = ReplicatedStorage
leaveFn.OnServerInvoke = function(player: Player)
	local profile = DataService.get(player); if not profile or not profile.clan then return false end
	local t = profile.clan
	pcall(function()
		STORE:UpdateAsync("clan_" .. t, function(old)
			if not old then return nil end
			local i = table.find(old.members, player.UserId); if i then table.remove(old.members, i) end
			if #old.members == 0 then return nil end
			if old.owner == player.UserId then old.owner = old.members[1] end
			return old
		end)
	end)
	profile.clan = nil
	return true
end

function ClanService.tagOf(player: Player): string
	local p = DataService.get(player); return p and p.clan or ""
end

return ClanService
