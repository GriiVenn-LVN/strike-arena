--!strict
-- ServerScriptService/ArmoryService (ModuleScript, requis par WeaponService)
-- Armurier + viseurs du jeu web (src/64b_gunsmith.js, 64c_sights.js) : choix des accessoires par arme et des réticules,
-- gardés dans le profil (profile.att[arme] = { emplacement = accessoire }, profile.ret[optique] = "forme|#couleur").
-- Le serveur vérifie tout (catégorie, niveau + éliminations avec l'arme, 5 accessoires max) puis recopie le résultat
-- en attributs du joueur, comme DataService.syncSkins : Att_<arme> = "muzzle=sil,optic=reddot", Ret_<optique>.
-- Tout le monde voit donc les accessoires (arme en 3e personne) et WeaponService applique leurs effets.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local A = require(ReplicatedStorage.Shared.Attachments)
local DataService = require(script.Parent.DataService)
local RewardService = require(script.Parent.RewardService)

local ArmoryService = {}

local function progOf(profile: any): A.Prog
	local level = RewardService.levelInfo(profile)
	local kills: { [string]: number } = {}
	local a = profile.weaponKills or {}
	local b = profile.stats and profile.stats.byWeapon or {}
	for k in pairs(Config.WEAPONS) do kills[k] = math.max(a[k] or 0, b[k] or 0) end
	return { level = level, kills = kills }
end
ArmoryService.progOf = progOf

local function ensure(profile: any)
	if typeof(profile.att) ~= "table" then profile.att = {} end
	if typeof(profile.ret) ~= "table" then profile.ret = {} end
end

-- recopie les choix (seulement ce qui est débloqué) en attributs du joueur
function ArmoryService.sync(player: Player)
	local profile = DataService.get(player)
	if not profile then return end
	ensure(profile)
	local p = progOf(profile)
	for k in pairs(Config.WEAPONS) do
		local sel = profile.att[k]
		local out: A.Sel = {}
		for _, a in ipairs(A.list(k, if typeof(sel) == "table" then sel else nil, p)) do out[A.ATTS[a].s] = a end
		local s = A.encode(out)
		player:SetAttribute("Att_" .. k, if s ~= "" then s else nil)
	end
	for o in pairs(A.RET_DEF) do
		local r = profile.ret[o]
		player:SetAttribute("Ret_" .. o, if typeof(r) == "string" then r else nil)
	end
end

local function setSlot(profile: any, k: string, slot: string, a: string?, skipLock: boolean?): (boolean, string?)
	local ok = A.allowed(k)
	if not ok[slot] then return false, "Emplacement indisponible" end
	local sel: A.Sel = table.clone(if typeof(profile.att[k]) == "table" then profile.att[k] else {})
	if a then
		if not table.find(ok[slot], a) then return false, "Accessoire incompatible" end
		if not skipLock and not A.isOpen(k, a, progOf(profile)) then return false, A.lockText(k, a, progOf(profile)) end
		sel[slot] = a
	else sel[slot] = nil end
	if A.count(sel) > A.MAX then return false, "Maximum " .. A.MAX .. " accessoires : retire-en un d'abord" end
	profile.att[k] = sel
	return true, nil
end

local fn = Instance.new("RemoteFunction"); fn.Name = "Armory"; fn.Parent = ReplicatedStorage
fn.OnServerInvoke = function(player: Player, action: any, a1: any, a2: any, a3: any): any
	local profile = DataService.get(player)
	if not profile then return nil end
	ensure(profile)
	if action == "get" then
		local p = progOf(profile)
		return { att = profile.att, ret = profile.ret, level = p.level, kills = p.kills }
	elseif action == "set" then                           -- (arme, emplacement, accessoire | "")
		if typeof(a1) ~= "string" or not Config.WEAPONS[a1] or typeof(a2) ~= "string" then return { ok = false } end
		local att = if typeof(a3) == "string" and a3 ~= "" then a3 else nil
		local ok, msg = setSlot(profile, a1, a2, att)
		if ok then ArmoryService.sync(player) end
		return { ok = ok, msg = msg, att = profile.att }
	elseif action == "ret" then                           -- (optique, forme, couleur)
		if typeof(a1) ~= "string" or not A.RET_DEF[a1] or not A.validRet(a2, a3) then return { ok = false } end
		profile.ret[a1] = a2 .. "|" .. a3
		ArmoryService.sync(player)
		return { ok = true, ret = profile.ret }
	elseif action == "all" then                           -- (arme) : même viseur sur toutes les armes compatibles
		if typeof(a1) ~= "string" or not Config.WEAPONS[a1] then return { ok = false } end
		local cur = profile.att[a1] and profile.att[a1].optic
		if typeof(cur) ~= "string" then return { ok = false } end
		local n = 0
		for k in pairs(Config.WEAPONS) do
			local opts = A.allowed(k).optic
			if k ~= a1 and opts and table.find(opts, cur) and setSlot(profile, k, "optic", cur, true) then n += 1 end   -- comme le web : verrouillé = ignoré en jeu
		end
		ArmoryService.sync(player)
		return { ok = true, n = n, att = profile.att }
	end
	return nil
end

-- synchronisation à l'arrivée (le profil se charge en tâche de fond) et à chaque apparition (niveau gagné entre-temps)
local function watch(player: Player)
	task.spawn(function()
		for _ = 1, 60 do
			if DataService.get(player) then break end
			task.wait(0.5)
		end
		ArmoryService.sync(player)
	end)
	player.CharacterAdded:Connect(function() ArmoryService.sync(player) end)
end
Players.PlayerAdded:Connect(watch)
for _, p in ipairs(Players:GetPlayers()) do watch(p) end

return ArmoryService
