--!strict
-- ServerScriptService/MedalService (ModuleScript, requis par Main)
-- Médailles en partie et fin de partie (src/8G_medals.js), bilan perso (src/8Zf_confort.js) et défis qui avancent
-- pendant les parties (src/8O_defis.js : éliminations par type d'arme, victoires par mode, Infecté, plaques).
--   • En partie : chaque médaille s'affiche au joueur (remote « MedalPop », MedalController) et compte dans son profil
--     (profile.medals[id]).
--   • Fin de partie (MatchService.finishHooks) : XP des médailles ajoutée aux récompenses, liste des médailles du match
--     (résumé MatchEnd : medals = { { id, n, ic, count } }, rewards.medXp) et bilan perso (bilan = { acc, hsPct, dmg, streak }).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Medals = require(ReplicatedStorage.Shared.Medals)
local DataService = require(script.Parent.DataService)
local RewardService = require(script.Parent.RewardService)
local WeaponService = require(script.Parent.WeaponService)
local BotService = require(script.Parent.BotService)
local MatchService = require(script.Parent.MatchService)

local U = Config.STUDS_PER_METER
local popEvent = Instance.new("RemoteEvent"); popEvent.Name = "MedalPop"; popEvent.Parent = ReplicatedStorage   -- serveur -> joueur : id de la médaille

type PState = { got: { [string]: number }, killer: any, lastKill: { t: number, key: string }?, streak: number, roundKills: number }
type MState = { fb: boolean, round: any, players: { [Player]: PState }, dmg: { [any]: { [Player]: { d: number, t: number } } }, hurtAt: { [Instance]: number } }

local MedalService = {}
local states: { [number]: MState } = {}

local function now(): number return os.clock() end
local function isPlayer(c: any): boolean return typeof(c) == "Instance" and c:IsA("Player") end

local function stateOf(m: any): MState
	local cur = states[m.id]
	if cur and cur.round ~= "__over" then return cur end
	local s: MState = { fb = false, round = nil, players = {}, dmg = {}, hurtAt = {} }
	states[m.id] = s
	return s
end
local function pstate(ms: MState, p: Player): PState
	local ps = ms.players[p]
	if not ps then ps = { got = {}, killer = nil, lastKill = nil, streak = 0, roundKills = 0 }; ms.players[p] = ps end
	return ps
end

function MedalService.award(p: Player, ms: MState, id: string)
	local def = Medals.LIST[id]
	if not def then return end
	local ps = pstate(ms, p)
	ps.got[id] = (ps.got[id] or 0) + 1
	local profile = DataService.get(p)
	if profile then
		profile.medals = profile.medals or {}
		profile.medals[id] = (profile.medals[id] or 0) + 1
	end
	popEvent:FireClient(p, id)
end

local function rootOf(c: any): BasePart?
	local ch = WeaponService.charOf(c)
	return ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
end
local function enemies(m: any, a: any, b: any): boolean
	local ta, tb = WeaponService.teamOf(a), WeaponService.teamOf(b)
	if m.teams then return ta ~= tb end
	return a ~= b
end

-- dégâts des joueurs (assistances) et dernier coup reçu (Sauveur)
WeaponService.Damaged:Connect(function(attacker, victim, amount: number, _headshot: boolean)
	local m = MatchService.matchOf(victim)
	if not m or m.state ~= "live" then return end
	local ms = stateOf(m)
	local vc = WeaponService.charOf(victim)
	if vc then ms.hurtAt[vc] = now() end
	if isPlayer(attacker) and attacker ~= victim and MatchService.matchOf(attacker) == m then
		local key = MatchService.keyOf(victim)
		local by = ms.dmg[key] or {}; ms.dmg[key] = by
		local e = by[attacker]
		if e and now() - e.t < Medals.ASSIST_T then e.d += amount; e.t = now() else by[attacker] = { d = amount, t = now() } end
	end
end)

WeaponService.Killed:Connect(function(killer, victim, key: string, _headshot: boolean)
	local m = MatchService.matchOf(victim)
	if not m or m.state ~= "live" then return end
	local ms = stateOf(m)
	-- manche suivante (modes à manches) : compteurs de l'As remis à zéro
	local round = m.data and m.data.round
	if round ~= ms.round then
		ms.round = round
		for _, ps in pairs(ms.players) do ps.roundKills = 0 end
	end
	local w = Config.WEAPONS[key]
	local melee = w ~= nil and w.melee
	local t = now()
	if isPlayer(victim) then
		local vs = pstate(ms, victim)
		vs.killer = if killer ~= nil and killer ~= victim then killer else nil
		vs.streak = 0
	end
	-- assistances : un autre joueur a infligé au moins 25 dégâts à cet adversaire dans les 8 dernières secondes
	local vkey = MatchService.keyOf(victim)
	for p, e in pairs(ms.dmg[vkey] or {}) do
		if p ~= killer and p.Parent and m.players[p] and e.d >= Medals.ASSIST_DMG and t - e.t < Medals.ASSIST_T and enemies(m, p, victim) then
			MedalService.award(p, ms, "assist")
		end
	end
	ms.dmg[vkey] = nil
	if killer == nil or killer == victim then return end
	local firstBlood = not ms.fb
	ms.fb = true     -- le premier sang compte pour tout le monde
	if not isPlayer(killer) or not m.players[killer] or not enemies(m, killer, victim) then return end
	if victim:GetAttribute("Zombie") then return end
	local p = killer :: Player
	local ps = pstate(ms, p)
	ps.streak += 1
	if firstBlood then MedalService.award(p, ms, "first") end
	if ps.killer ~= nil and ps.killer == victim then ps.killer = nil; MedalService.award(p, ms, "revenge") end
	local kr, vr = rootOf(killer), rootOf(victim)
	if kr and vr and not melee and (Vector3.new(kr.Position.X - vr.Position.X, 0, kr.Position.Z - vr.Position.Z)).Magnitude / U > Medals.LONG_M then
		MedalService.award(p, ms, "long")
	end
	if melee then MedalService.award(p, ms, "knife") end
	if key == "frag" then MedalService.award(p, ms, "nade") end
	local kc = WeaponService.charOf(killer)
	local hum = kc and kc:FindFirstChildOfClass("Humanoid")
	local anim = kc and kc:GetAttribute("Anim")
	local inAir = hum ~= nil and (hum.FloorMaterial == Enum.Material.Air or (typeof(anim) == "number" and bit32.band(anim, 1) ~= 0))
	if inAir and not melee and key ~= "frag" then MedalService.award(p, ms, "air") end
	if hum and hum.Health > 0 and hum.Health <= Medals.CLUTCH_HP then MedalService.award(p, ms, "clutchhp") end
	-- sauveur : la victime (un bot) visait un allié du tueur, touché il y a moins de 2 s
	if m.teams and BotService.isBot(victim) then
		local tgt = BotService.combatOf(victim)
		local tc = tgt and WeaponService.combatantOf(tgt)
		local th = tgt and tgt:FindFirstChildOfClass("Humanoid")
		if tgt and tc ~= nil and tc ~= p and th and th.Health > 0 and WeaponService.teamOf(tc) == WeaponService.teamOf(p)
			and t - (ms.hurtAt[tgt] or -99) < Medals.SAVE_T then
			MedalService.award(p, ms, "save")
		end
	end
	local lk = ps.lastKill
	if lk and t - lk.t < Medals.COLLAT_T and lk.key == key and not melee then MedalService.award(p, ms, "collat") end
	ps.lastKill = { t = t, key = key }
	if ps.streak == 5 then MedalService.award(p, ms, "s5") end
	if ps.streak == 10 then MedalService.award(p, ms, "s10") end
	-- As (Compétitif) : toute l'équipe adverse (3 au moins) éliminée par le joueur dans la manche
	if m.mode == "bomb" then
		ps.roundKills += 1
		local foes = 0
		for _, c in ipairs(MatchService.combatants(m)) do if WeaponService.teamOf(c) ~= WeaponService.teamOf(p) then foes += 1 end end
		if foes >= 3 and ps.roundKills == foes then MedalService.award(p, ms, "ace") end
	end
	-- défis : éliminations par type d'arme (k_pistol, k_smg, k_shotgun, k_rifle, k_sniper) et à la grenade
	if w and w.cat and not melee then RewardService.missionEvent(p, "k_" .. w.cat) end
	if key == "frag" then RewardService.missionEvent(p, "nade") end
end)

-- ---------- fin de partie ----------
table.insert(MatchService.finishHooks, function(m: any, p: Player, s: any, won: boolean, payload: { [string]: any })
	local ms = states[m.id]
	local ps = ms and ms.players[p]
	-- médailles du match et leur XP
	local list, xp = {}, 0
	if ps then
		for _, id in ipairs(Medals.ORDER) do
			local n = ps.got[id]
			if n and n > 0 then
				local d = Medals.LIST[id]
				table.insert(list, { id = id, n = d.n, ic = d.ic, count = n })
				xp += d.xp * n
			end
		end
	end
	payload.medals = list
	if xp > 0 and payload.rewards then
		local ups = RewardService.addXP(p, xp)
		local r = payload.rewards
		r.xp += xp; r.medXp = xp
		r.levelUps = r.levelUps or {}
		for _, u in ipairs(ups) do table.insert(r.levelUps, u) end
		local profile = DataService.get(p)
		if profile and profile.history and profile.history[1] then profile.history[1].xp = r.xp end
	end
	-- bilan perso : précision, tirs à la tête, dégâts, meilleure série (pas en Entraînement)
	if s and m.mode ~= "train" then
		payload.bilan = {
			acc = if s.shots > 0 then math.floor(s.hits / s.shots * 100 + 0.5) else nil,
			hsPct = if s.k > 0 then math.floor(s.hs / s.k * 100 + 0.5) else nil,
			dmg = math.floor(s.dmg + 0.5), streak = s.bestStreak,
		}
	end
	-- défis liés au résultat de la partie
	if s then
		if won then RewardService.missionEvent(p, "w_" .. m.mode) end
		local planted = (s.plants or 0) + (s.defuses or 0)
		if planted > 0 then RewardService.missionEvent(p, "plant", planted) end
		if m.mode == "inf" and won and s.team == "Défenseurs" then RewardService.missionEvent(p, "inf_surv") end    -- survivant jusqu'au bout
		if m.mode == "kc" and (s.pts or 0) > 0 then RewardService.missionEvent(p, "kcTag", s.pts) end
	end
	-- Zombies : manches survécues (m.data.zs du mode, lu sans le modifier)
	local zs = m.mode == "zombies" and m.data and (m.data :: any).zs
	if zs and typeof(zs.wave) == "number" then
		local survived = zs.wave - (if zs.result == "win" then 0 else 1)
		if survived > 0 then RewardService.missionEvent(p, "z_wave", survived) end
	end
end)

-- partie suivante (même salon) ou fermée : les compteurs repartent à zéro
task.spawn(function()
	while true do
		task.wait(2)
		for id, ms in pairs(states) do
			local m = MatchService.get(id)
			if not m then states[id] = nil
			elseif m.state == "warmup" and ms.round ~= "__over" then ms.round = "__over" end
		end
	end
end)

Players.PlayerRemoving:Connect(function(p)
	for _, ms in pairs(states) do ms.players[p] = nil end
end)

return MedalService
