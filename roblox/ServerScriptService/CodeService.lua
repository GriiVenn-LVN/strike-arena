--!strict
-- ServerScriptService/CodeService (ModuleScript, requis par Main)
-- Codes promo (comme Arsenal, BedWars, Blox Fruits) et récompense du groupe Roblox.
-- Tout est vérifié côté serveur : un code ne marche qu'une fois par joueur, avec une limite d'essais contre le forçage.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CommunityConfig = require(ReplicatedStorage.Shared.CommunityConfig)
local KillFxConfig = require(ReplicatedStorage.Shared.KillFxConfig)
local DataService = require(script.Parent.DataService)
local CODES = require(script.Parent.CodeList)

local CodeService = {}

-- ---------- donner un lot de récompenses ----------
-- reward = { coins, box, killfx, dance } ; renvoie la liste lisible de ce qui a été donné
function CodeService.grant(profile: any, reward: any): { string }
	local lines = {}
	if reward.coins then
		profile.coins += reward.coins
		table.insert(lines, "🪙 " .. reward.coins .. " pièces")
	end
	if reward.box then
		profile.boxes[reward.box] = (profile.boxes[reward.box] or 0) + 1
		table.insert(lines, if reward.box == "prem" then "📦 Caisse Premium" else "📦 Caisse Standard")
	end
	if reward.killfx then
		profile.inv.killfx = profile.inv.killfx or {}
		if not table.find(profile.inv.killfx, reward.killfx) then table.insert(profile.inv.killfx, reward.killfx) end
		local fx = KillFxConfig.get(reward.killfx)
		table.insert(lines, "💥 Effet « " .. (fx and fx.name or reward.killfx) .. " »")
	end
	if reward.dance and not table.find(profile.inv.dances, reward.dance) then
		table.insert(profile.inv.dances, reward.dance)
		table.insert(lines, "💃 Danse")
	end
	return lines
end

-- ---------- codes promo ----------
local byCode: { [string]: any } = {}
for _, c in ipairs(CODES) do byCode[string.upper(c.code)] = c end

local tries: { [Player]: { last: number, window: number, count: number } } = {}
local function rateLimited(p: Player): boolean
	local t = os.clock()
	local r = tries[p] or { last = 0, window = t, count = 0 }
	tries[p] = r
	if t - r.last < 1.5 then return true end
	if t - r.window > 60 then r.window = t; r.count = 0 end
	r.count += 1; r.last = t
	return r.count > 10                 -- 10 essais par minute au maximum
end

function CodeService.redeem(player: Player, raw: string)
	if rateLimited(player) then return { ok = false, msg = "Doucement ! Réessaie dans quelques secondes." } end
	local profile = DataService.get(player)
	if not profile then return { ok = false, msg = "Profil pas encore chargé" } end
	local code = string.upper((string.gsub(raw, "%s", "")))
	if #code == 0 or #code > 30 then return { ok = false, msg = "Code invalide" } end
	local c = byCode[code]
	if not c then return { ok = false, msg = "Code invalide" } end
	local today = os.date("!%Y-%m-%d") :: string
	if c.from and today < c.from then return { ok = false, msg = "Ce code n'est pas encore actif" } end
	if c.to and today > c.to then return { ok = false, msg = "Ce code a expiré" } end
	profile.codes = profile.codes or {}
	if table.find(profile.codes, code) then return { ok = false, msg = "Tu as déjà utilisé ce code" } end
	table.insert(profile.codes, code)
	local lines = CodeService.grant(profile, c.reward)
	task.spawn(DataService.save, player)
	return { ok = true, msg = "Code accepté !", lines = lines }
end

-- ---------- groupe Roblox ----------
local function inGroup(player: Player, groupId: number): boolean
	local ok, res = pcall(function() return (player :: any):IsInGroupAsync(groupId) end)
	if ok then return res == true end
	ok, res = pcall(function() return player:IsInGroup(groupId) end)   -- ancienne méthode si la nouvelle n'existe pas
	return ok and res == true
end

function CodeService.claimGroup(player: Player)
	local G = CommunityConfig.GROUP
	if G.id <= 0 then return { ok = false, msg = "Le groupe n'est pas encore ouvert" } end
	local profile = DataService.get(player)
	if not profile then return { ok = false, msg = "Profil pas encore chargé" } end
	profile.social = profile.social or {}
	if profile.social.group then return { ok = false, msg = "Récompense déjà récupérée", claimed = true } end
	if not inGroup(player, G.id) then return { ok = false, msg = "Rejoins d'abord le groupe, puis réessaie" } end
	profile.social.group = os.time()
	local lines = CodeService.grant(profile, G.reward)
	task.spawn(DataService.save, player)
	return { ok = true, msg = "Merci d'avoir rejoint le groupe !", lines = lines, claimed = true }
end

function CodeService.groupStatus(player: Player)
	local profile = DataService.get(player)
	return { groupId = CommunityConfig.GROUP.id, claimed = profile ~= nil and profile.social ~= nil and profile.social.group ~= nil }
end

-- ---------- remotes ----------
local function remote(name: string, fn: (Player, ...any) -> any)
	local r = Instance.new("RemoteFunction"); r.Name = name; r.Parent = ReplicatedStorage; r.OnServerInvoke = fn
end
remote("RedeemCode", function(p, code: any)
	if typeof(code) ~= "string" then return { ok = false, msg = "Code invalide" } end
	return CodeService.redeem(p, code)
end)
remote("ClaimGroupReward", function(p) return CodeService.claimGroup(p) end)
remote("GetGroupStatus", function(p) return CodeService.groupStatus(p) end)

Players.PlayerRemoving:Connect(function(p) tries[p] = nil end)

return CodeService
