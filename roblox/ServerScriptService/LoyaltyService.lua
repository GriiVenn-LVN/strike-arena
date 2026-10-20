--!strict
-- ServerScriptService/LoyaltyService (ModuleScript)
-- Fidélité et Premium : cadeaux de temps de jeu, paliers de série, rang de fidélité, bonus de fin de partie,
-- abonnement Premium (jours cumulables achetés en Robux, crédités par ShopService) et couleur de pseudo.
-- Valeurs dans ReplicatedStorage/Shared/LoyaltyConfig. Le serveur vérifie tout, le client ne fait qu'afficher.
-- Branché dans : RewardService.finishMatch (bonus), RewardService.dailyStatus/claimDaily (série protégée), ShopService (achat).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local L = require(ReplicatedStorage.Shared.LoyaltyConfig)
local DataService = require(script.Parent.DataService)

local LoyaltyService = {}

local function today(): number return math.floor(os.time() / 86400) end
local function week(): number return math.floor((today() + 3) / 7) end   -- semaine commençant le lundi

-- ---------- données du profil ----------
function LoyaltyService.ensure(profile: any)
	local y = profile.loy
	if not y then
		y = { day = 0, secs = 0, got = {}, days = 0, lastDay = 0, total = 0, tiers = { 1 }, streakGot = {}, boost = 0, win = 0,
			back = 0, titles = {}, vip = { untilTime = 0, color = "gold", daily = 0, shield = 0 } }
		profile.loy = y
	end
	if y.day ~= today() then y.day = today(); y.secs = 0; y.got = {} end
	return y
end
local ensure = LoyaltyService.ensure

function LoyaltyService.isVip(profile: any): boolean
	return ensure(profile).vip.untilTime > os.time()
end
local isVip = LoyaltyService.isVip

local function tierIndex(y: any): number
	local idx = 1
	for i, t in ipairs(L.TIERS) do if y.days >= t.days then idx = i end end
	return idx
end

local function addTitle(y: any, id: string)
	if not table.find(y.titles, id) then table.insert(y.titles, id) end
end

local function apply(profile: any, r: any)
	local y = ensure(profile)
	if r.coins then profile.coins += r.coins end
	if r.box then profile.boxes[r.box] = (profile.boxes[r.box] or 0) + (r.n or 1) end
	if r.boost then y.boost += r.boost end
	if r.title then addTitle(y, r.title) end
end
LoyaltyService.give = apply   -- { coins, box, n, boost, title } : utilisé aussi par le pack de départ (ShopService)

-- Attributs lus par les clients (chat, futur HUD) : Vip, VipColor, LoyaltyTier
local function publish(player: Player, profile: any)
	local y = ensure(profile)
	local vip = isVip(profile)
	player:SetAttribute("Vip", vip)
	player:SetAttribute("VipColor", if vip then y.vip.color else "")
	player:SetAttribute("LoyaltyTier", tierIndex(y))
end
LoyaltyService.publish = publish

-- ---------- ce qui peut être récupéré ----------
local function ready(profile: any, kind: string, i: number): (boolean, any)
	local y = ensure(profile)
	if kind == "pt" then
		local g = L.PLAYTIME_GIFTS[i]
		return g ~= nil and y.secs >= g.minutes * 60 and not table.find(y.got, i), g and g.reward
	elseif kind == "st" then
		local g = L.STREAK_GOALS[i]
		return g ~= nil and (profile.streak or 0) >= g.days and not table.find(y.streakGot, g.days), g and g.reward
	elseif kind == "tier" then
		local t = L.TIERS[i]
		return t ~= nil and t.reward ~= nil and y.days >= t.days and not table.find(y.tiers, i), t and t.reward
	elseif kind == "vip" then
		return isVip(profile) and y.vip.daily ~= today(), L.VIP.daily
	end
	return false, nil
end

function LoyaltyService.claim(player: Player, kind: string, i: number)
	local profile = DataService.get(player); if not profile then return nil end
	local ok, r = ready(profile, kind, i)
	if not ok then return nil end
	local y = ensure(profile)
	if kind == "pt" then table.insert(y.got, i)
	elseif kind == "st" then table.insert(y.streakGot, L.STREAK_GOALS[i].days)
	elseif kind == "tier" then table.insert(y.tiers, i)
	elseif kind == "vip" then y.vip.daily = today() end
	apply(profile, r)
	return r
end

function LoyaltyService.state(player: Player)
	local profile = DataService.get(player); if not profile then return nil end
	local y = ensure(profile)
	local pending = {}
	for i in ipairs(L.PLAYTIME_GIFTS) do if ready(profile, "pt", i) then table.insert(pending, { "pt", i }) end end
	for i in ipairs(L.STREAK_GOALS) do if ready(profile, "st", i) then table.insert(pending, { "st", i }) end end
	for i in ipairs(L.TIERS) do if ready(profile, "tier", i) then table.insert(pending, { "tier", i }) end end
	if ready(profile, "vip", 0) then table.insert(pending, { "vip", 0 }) end
	return { minutes = math.floor(y.secs / 60), got = y.got, streak = profile.streak or 0, streakGot = y.streakGot, days = y.days,
		tier = tierIndex(y), tiers = y.tiers, boost = y.boost, firstWinAvailable = y.win ~= today(), titles = y.titles,
		vip = isVip(profile), vipDaysLeft = math.max(0, math.ceil((y.vip.untilTime - os.time()) / 86400)), vipColor = y.vip.color,
		pending = pending }
end

-- ---------- temps de jeu : le joueur doit avoir un personnage en vie (pas l'écran de chargement ni un AFK mort) ----------
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local profile = DataService.get(player)
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if profile and hum and hum.Health > 0 then
				local y = ensure(profile)
				local before = math.floor(y.secs / 60)
				y.secs += 1; y.total += 1
				local now = math.floor(y.secs / 60)
				if now ~= before then
					for _, g in ipairs(L.PLAYTIME_GIFTS) do
						if g.minutes == now then player:SetAttribute("LoyaltyGiftReady", now) end   -- le client affiche « Cadeau débloqué ! »
					end
				end
			end
		end
	end
end)

-- ---------- bonus de fin de partie (appelé par RewardService.finishMatch) ----------
-- Retourne l'XP et les pièces en plus, et les lignes à afficher.
function LoyaltyService.matchBonus(player: Player, baseXp: number, baseCoins: number, won: boolean): (number, number, { string }, boolean)
	local profile = DataService.get(player); if not profile then return 0, 0, {}, false end
	local y = ensure(profile)
	local xp, coins, lines = 0, 0, {}
	if y.lastDay ~= today() then y.lastDay = today(); y.days += 1 end   -- un jour de jeu de plus
	local tier = L.TIERS[tierIndex(y)]
	if tier.xp > 0 then
		local v = math.floor(baseXp * tier.xp / 100 + 0.5); xp += v
		table.insert(lines, string.format("Fidélité +%d %% (%d XP)", tier.xp, v))
	end
	if isVip(profile) then
		local v, c = math.floor(baseXp * L.VIP.xp + 0.5), math.floor(baseCoins * L.VIP.coins + 0.5)
		xp += v; coins += c
		table.insert(lines, string.format("⭐ Premium +%d XP, +%d pièces", v, c))
	end
	if y.boost > 0 then
		local v = math.floor(baseXp * L.BOOST_MULT + 0.5); xp += v; y.boost -= 1
		table.insert(lines, string.format("⚡ Boost +%d XP (%d restante(s))", v, y.boost))
	end
	local firstWin = false
	if won and y.win ~= today() then
		y.win = today(); xp += L.FIRST_WIN.xp; coins += L.FIRST_WIN.coins; firstWin = true
		table.insert(lines, string.format("🏆 Première victoire du jour +%d XP, +%d pièces", L.FIRST_WIN.xp, L.FIRST_WIN.coins))
	end
	publish(player, profile)
	return xp, coins, lines, firstWin
end

-- ---------- série protégée (Premium) : un jour manqué par semaine ne casse pas la série ----------
-- lastLoginDay = avant-hier, série en cours, Premium actif, bouclier pas encore utilisé cette semaine.
function LoyaltyService.shieldOk(profile: any): boolean
	local y = ensure(profile)
	return isVip(profile) and (profile.streak or 0) > 0 and profile.lastLoginDay == today() - 2 and y.vip.shield ~= week()
end
function LoyaltyService.useShield(profile: any)
	ensure(profile).vip.shield = week()
end

-- ---------- abonnement Premium (appelé par ShopService.ProcessReceipt) ----------
function LoyaltyService.grantVip(player: Player, days: number)
	local profile = DataService.get(player); if not profile then return false end
	local y = ensure(profile)
	y.vip.untilTime = math.max(os.time(), y.vip.untilTime) + days * 86400
	addTitle(y, "vip")
	apply(profile, L.VIP.onPurchase)
	publish(player, profile)
	return true
end

-- ---------- bon retour : après BACK_DAYS jours sans récompense quotidienne ----------
local function welcomeBack(player: Player, profile: any)
	local y = ensure(profile)
	local last = profile.lastLoginDay or 0
	if last <= 0 or y.back == today() or today() - last < L.BACK_DAYS then return end
	y.back = today()
	apply(profile, L.BACK_GIFT)
	player:SetAttribute("LoyaltyWelcomeBack", today() - last)   -- le client affiche la grande fenêtre « Bon retour ! »
end

-- ---------- remotes ----------
local function remoteFunction(name: string, fn: (Player, ...any) -> any)
	local r = Instance.new("RemoteFunction"); r.Name = name; r.Parent = ReplicatedStorage
	r.OnServerInvoke = fn
end
remoteFunction("Loy_Get", function(p) return LoyaltyService.state(p) end)
remoteFunction("Loy_Claim", function(p, kind: any, i: any)
	if typeof(kind) ~= "string" or typeof(i) ~= "number" then return nil end
	return LoyaltyService.claim(p, kind, i)
end)
remoteFunction("Vip_SetColor", function(p, id: any)
	local profile = DataService.get(p)
	if not profile or typeof(id) ~= "string" or not isVip(profile) then return false end
	local known = false
	for _, c in ipairs(L.VIP.colors) do if c.id == id then known = true end end
	if not known then return false end
	ensure(profile).vip.color = id
	publish(p, profile)
	return true
end)

-- Profil chargé par DataService : on attend qu'il existe puis on publie les attributs
Players.PlayerAdded:Connect(function(player)
	for _ = 1, 30 do
		local profile = DataService.get(player)
		if profile then publish(player, profile); welcomeBack(player, profile); return end
		task.wait(1)
	end
end)

return LoyaltyService
