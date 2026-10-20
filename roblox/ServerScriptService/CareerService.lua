--!strict
-- ServerScriptService/CareerService (ModuleScript, requis par Main)
-- Carrière du joueur, comptée côté serveur :
--   • statistiques par arme (profile.career[arme] = { k, hs }) : éliminations et tirs à la tête en partie (pas les zombies
--     ni les cibles d'entraînement), qui font avancer la maîtrise d'arme (Shared/Mastery : camos Or, Diamant, Matière noire) ;
--   • défis qui avancent en partie : défi d'arme du jour (« kw_<arme> »), tirs à la tête par type d'arme (« hs_<type> »),
--     glissades et escalades (« slide », « climb », lues sur l'attribut Anim du personnage, cadence bornée) ;
--   • carte de joueur (Shared/PlayerCard : bannière + emblème, profile.card), recopiée dans l'attribut « Card » ;
--   • records du stand d'entraînement (profile.train : score, précision, temps de réaction), écrits par Modes/train ;
--   • version des nouveautés déjà vue (fenêtre « Quoi de neuf », profile.newsSeen).
-- Remote « Career » (RemoteFunction, cadence limitée) :
--   ("get")                         -> carrière, maîtrise, carte, records, déblocages
--   ("camo", arme, camo | "")       -> pose (ou retire) un camo de maîtrise débloqué sur cette arme
--   ("card", banniere, embleme)     -> équipe une carte débloquée
--   ("news", version)               -> mémorise la version des nouveautés vue
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local X = require(ReplicatedStorage.Shared.ConfigExtra)
local Mastery = require(ReplicatedStorage.Shared.Mastery)
local PlayerCard = require(ReplicatedStorage.Shared.PlayerCard)
local MenuConfig = require(ReplicatedStorage.Shared.MenuConfig)
local DataService = require(script.Parent.DataService)
local RewardService = require(script.Parent.RewardService)
local LoyaltyService = require(script.Parent.LoyaltyService)
local WeaponService = require(script.Parent.WeaponService)
local MatchService = require(script.Parent.MatchService)
local RateLimit = require(script.Parent.RateLimit)

local CareerService = {}

local SLIDE, MANT = 1, 16          -- bits de l'attribut « Anim » (Shared/SoldierAnim : Anim.SLIDE, Anim.MANT)
local MOVE_GAP = 0.8               -- une glissade / escalade comptée toutes les 0,8 s au plus
local MOVES: { [number]: string } = { [SLIDE] = "slide", [MANT] = "climb" }

local function career(profile: any): { [string]: { k: number, hs: number } }
	if typeof(profile.career) ~= "table" then profile.career = {} end
	return profile.career
end

-- ---------- éliminations : carrière par arme et défis ----------
local function enemies(m: any, a: any, b: any): boolean
	if m.teams then return WeaponService.teamOf(a) ~= WeaponService.teamOf(b) end
	return a ~= b
end
WeaponService.Killed:Connect(function(killer, victim, key: string, headshot: boolean)
	if typeof(killer) ~= "Instance" or not killer:IsA("Player") or killer == victim then return end
	local m = MatchService.matchOf(victim)
	if not m or m.state ~= "live" or MatchService.matchOf(killer) ~= m or not enemies(m, killer, victim) then return end
	if typeof(victim) == "Instance" and (victim:GetAttribute("Zombie") or victim:GetAttribute("Dummy")) then return end
	local w = Config.WEAPONS[key]
	if not w then return end
	local p = killer :: Player
	local profile = DataService.get(p)
	if profile then
		local c = career(profile)
		local rec = c[key] or { k = 0, hs = 0 }
		local before = Mastery.level(rec, Mastery.diamonds(c))
		rec.k += 1
		if headshot then rec.hs += 1 end
		c[key] = rec
		-- palier de maîtrise atteint : petite annonce au centre de l'écran (remote ModePop, comme le stand de tir)
		if Mastery.eligible(Config.WEAPONS, key) then
			local after = Mastery.level(rec, Mastery.diamonds(c))
			if after > before then
				local t = Mastery.TIERS[after]
				local pop = ReplicatedStorage:FindFirstChild("ModePop")
				if pop and pop:IsA("RemoteEvent") then
					pop:FireClient(p, "MAÎTRISE " .. string.upper(t.name) .. " : " .. w.name .. " (camo débloqué)", t.color, "pickup")
				end
			end
		end
	end
	if not w.melee then
		RewardService.missionEvent(p, "kw_" .. key)
		if headshot and w.cat then RewardService.missionEvent(p, "hs_" .. w.cat) end
	end
end)

-- ---------- glissades et escalades (défis « slide » et « climb ») ----------
local lastMove: { [Player]: { [string]: number } } = {}
local function watchChar(p: Player, char: Model)
	local prev = 0
	char:GetAttributeChangedSignal("Anim"):Connect(function()
		local bits = char:GetAttribute("Anim")
		if typeof(bits) ~= "number" then return end
		local rose = bit32.band(bits, bit32.bnot(prev))
		prev = bits
		if rose == 0 then return end
		local m = MatchService.matchOf(p)
		if not m or m.state ~= "live" then return end
		local mine = lastMove[p] or {}; lastMove[p] = mine
		local t = os.clock()
		for bit, id in pairs(MOVES) do
			if bit32.band(rose, bit) ~= 0 and t - (mine[id] or 0) >= MOVE_GAP then
				mine[id] = t
				RewardService.missionEvent(p, id)
			end
		end
	end)
end

-- ---------- carte de joueur ----------
function CareerService.cardView(profile: any): PlayerCard.View
	local c = career(profile)
	local gold, diamonds, dark = 0, Mastery.diamonds(c), 0
	for k, rec in pairs(c) do
		if Mastery.eligible(Config.WEAPONS, k) then
			local l = Mastery.level(rec, diamonds)
			if l >= 1 then gold += 1 end
			if l >= 3 then dark += 1 end
		end
	end
	local level = RewardService.levelInfo(profile)
	local rank = profile.rank and tonumber(profile.rank.best) or 0
	local pk = if profile.ev and profile.ev.id == X.EVENT.id then tonumber(profile.ev.pumpkins) or 0 else 0
	return { level = level, ach = if typeof(profile.ach) == "table" then profile.ach else {}, medals = if typeof(profile.medals) == "table" then profile.medals else {},
		gold = gold, diamonds = diamonds, dark = dark, vip = LoyaltyService.isVip(profile), rankBest = math.floor((rank or 0) / X.RANK_RP_PER_DIVISION),
		pumpkins = pk }
end
-- recopie la carte (si elle est toujours débloquée, sinon celle de base) dans l'attribut « Card » du joueur
function CareerService.publish(p: Player)
	local profile = DataService.get(p)
	if not profile then return end
	local card = if typeof(profile.card) == "table" then profile.card else {}
	local v = CareerService.cardView(profile)
	local b = PlayerCard.findBanner(tostring(card.b))
	local e = PlayerCard.findEmblem(tostring(card.e))
	local bid = if b and PlayerCard.open(b.need, v) then b.id else "recrue"
	local eid = if e and PlayerCard.open(e.need, v) then e.id else "cible"
	p:SetAttribute("Card", bid .. "|" .. eid)
	p:SetAttribute("CardLevel", v.level)
end

-- ---------- stand d'entraînement : records (appelé par Modes/train) ----------
-- rec = { score, acc (%, nil si trop peu de tirs), rt (temps de réaction moyen, s), rtBest (meilleur, s) } ; renvoie true si record battu
function CareerService.trainRecord(p: Player, rec: { [string]: number? }): boolean
	local profile = DataService.get(p)
	if not profile then return false end
	if typeof(profile.train) ~= "table" then profile.train = {} end
	local t = profile.train
	local beat = false
	if rec.score and rec.score > (t.score or 0) then t.score = rec.score; beat = true end
	if rec.acc and rec.acc > (t.acc or 0) then t.acc = rec.acc end
	if rec.rt and (t.rt == nil or rec.rt < t.rt) then t.rt = rec.rt end
	if rec.rtBest and (t.rtBest == nil or rec.rtBest < t.rtBest) then t.rtBest = rec.rtBest end
	return beat
end

-- ---------- remote ----------
local fn = Instance.new("RemoteFunction"); fn.Name = "Career"; fn.Parent = ReplicatedStorage
fn.OnServerInvoke = function(p: Player, action: any, a1: any, a2: any): any
	if typeof(action) ~= "string" or not RateLimit.ok(p, "Career_" .. action, if action == "get" then 0.3 else 0.4) then return nil end
	local profile = DataService.get(p)
	if not profile then return nil end
	if action == "get" then
		local c = career(profile)
		local cur = if typeof(profile.card) == "table" then profile.card else {}
		local b, e = PlayerCard.decode(p:GetAttribute("Card"))
		return { career = c, diamonds = Mastery.diamonds(c), view = CareerService.cardView(profile), card = { b = cur.b or b, e = cur.e or e },
			train = profile.train or {}, camos = profile.equipped and profile.equipped.animCamo or {}, byWeapon = profile.stats and profile.stats.byWeapon or {},
			newsSeen = profile.newsSeen }
	elseif action == "camo" then
		if typeof(a1) ~= "string" or not Mastery.eligible(Config.WEAPONS, a1) or typeof(a2) ~= "string" then return { ok = false } end
		local eq = profile.equipped
		eq.animCamo = eq.animCamo or {}
		if a2 == "" then
			if Mastery.CAMOS[eq.animCamo[a1] or ""] then eq.animCamo[a1] = nil end   -- ne retire qu'un camo de maîtrise
		else
			if not Mastery.CAMOS[a2] then return { ok = false } end
			if not Mastery.camoOpen(career(profile), a1, a2) then return { ok = false, err = "Maîtrise pas encore atteinte sur cette arme" } end
			eq.animCamo[a1] = a2
		end
		DataService.syncSkins(p)
		return { ok = true, camos = eq.animCamo }
	elseif action == "card" then
		if typeof(a1) ~= "string" or typeof(a2) ~= "string" then return { ok = false } end
		local b, e = PlayerCard.findBanner(a1), PlayerCard.findEmblem(a2)
		local v = CareerService.cardView(profile)
		if not b or not e then return { ok = false } end
		if not PlayerCard.open(b.need, v) or not PlayerCard.open(e.need, v) then return { ok = false, err = "Pas encore débloqué" } end
		profile.card = { b = b.id, e = e.id }
		CareerService.publish(p)
		return { ok = true }
	elseif action == "news" then
		if a1 ~= MenuConfig.NEWS_VERSION then return false end
		profile.newsSeen = a1
		return true
	end
	return nil
end

-- ---------- arrivée ----------
local function arrive(p: Player)
	p.CharacterAdded:Connect(function(char) watchChar(p, char); CareerService.publish(p) end)
	if p.Character then watchChar(p, p.Character) end
	task.spawn(function()
		for _ = 1, 30 do
			if DataService.get(p) then CareerService.publish(p); return end
			task.wait(1)
		end
	end)
end
Players.PlayerAdded:Connect(arrive)
for _, p in ipairs(Players:GetPlayers()) do arrive(p) end
Players.PlayerRemoving:Connect(function(p) lastMove[p] = nil end)

return CareerService
