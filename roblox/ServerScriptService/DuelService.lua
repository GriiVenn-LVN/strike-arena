--!strict
-- ServerScriptService/DuelService (ModuleScript, requis par Main quand le lobby est activé)
-- Duels façon Rivals : on monte sur une plateforme du lobby (1v1 ou 2v2, avec ou sans mise), le duel démarre dès
-- qu'elle est pleine. Premier à CommunityConfig.DUEL.roundsToWin manches, une seule vie par manche.
-- La mise de chacun va dans un pot que l'équipe gagnante se partage. Chaque duel fait bouger le classement Elo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CommunityConfig = require(ReplicatedStorage.Shared.CommunityConfig)
local DataService = require(script.Parent.DataService)
local WeaponService = require(script.Parent.WeaponService)
local RewardService = require(script.Parent.RewardService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local LobbyService = require(script.Parent.LobbyService)

local D = CommunityConfig.DUEL

local function remoteEvent(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent"); r.Name = name; r.Parent = ReplicatedStorage; return r
end
local stateEvent = remoteEvent("DuelState")   -- serveur -> duellistes : manche, score, chrono, message
local endEvent = remoteEvent("DuelEnd")       -- serveur -> chaque duelliste : victoire/défaite, Elo, pièces

local DuelService = {}

-- ==========================================================================================
-- Arènes : petites salles symétriques construites loin de tout, réutilisées d'un duel à l'autre
-- ==========================================================================================
type Arena = { slot: number, folder: Folder, spawnsA: { Vector3 }, spawnsB: { Vector3 } }
local arenas: { [number]: Arena } = {}
local busy: { [number]: boolean } = {}

local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true; p.Size = size; p.CFrame = cf; p.Color = color; p.Material = material or Enum.Material.Concrete
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function buildArena(slot: number): Arena
	local O = D.arenaOrigin + Vector3.new(slot * 400, 0, 0)
	local folder = Instance.new("Folder"); folder.Name = "DuelArena_" .. slot; folder.Parent = workspace
	local S, H = 110, 22
	local wall = Color3.fromRGB(58, 64, 82)
	part(folder, Vector3.new(S, 2, S), CFrame.new(O + Vector3.new(0, -1, 0)), Color3.fromRGB(80, 86, 102))
	for _, d in ipairs({ { 0, S / 2, true }, { 0, -S / 2, true }, { S / 2, 0, false }, { -S / 2, 0, false } }) do
		part(folder, if d[3] then Vector3.new(S, H, 2) else Vector3.new(2, H, S), CFrame.new(O + Vector3.new(d[1] :: number, H / 2, d[2] :: number)), wall)
	end
	part(folder, Vector3.new(S, 1, 2), CFrame.new(O + Vector3.new(0, 2, -S / 2 + 1.5)), Color3.fromRGB(255, 70, 85), Enum.Material.Neon)
	part(folder, Vector3.new(S, 1, 2), CFrame.new(O + Vector3.new(0, 2, S / 2 - 1.5)), Color3.fromRGB(74, 163, 255), Enum.Material.Neon)
	-- abris symétriques (caisses et murets) pour des duels tactiques
	local crate = Color3.fromRGB(165, 118, 64)
	for _, c in ipairs({ { 0, 0, 10, 8, 10 }, { -24, -18, 8, 6, 8 }, { 24, 18, 8, 6, 8 }, { 24, -18, 8, 6, 8 }, { -24, 18, 8, 6, 8 },
		{ 0, -30, 18, 4, 3 }, { 0, 30, 18, 4, 3 }, { -40, 0, 3, 7, 14 }, { 40, 0, 3, 7, 14 } }) do
		part(folder, Vector3.new(c[3], c[4], c[5]), CFrame.new(O + Vector3.new(c[1], c[4] / 2, c[2])), crate, Enum.Material.WoodPlanks)
	end
	local a = {
		slot = slot, folder = folder,
		spawnsA = { O + Vector3.new(-6, 3, -46), O + Vector3.new(6, 3, -46) },
		spawnsB = { O + Vector3.new(6, 3, 46), O + Vector3.new(-6, 3, 46) },
	}
	return a
end

local function takeArena(): Arena
	local slot = 0
	while busy[slot] do slot += 1 end
	busy[slot] = true
	if not arenas[slot] then arenas[slot] = buildArena(slot) end
	return arenas[slot]
end

-- ==========================================================================================
-- Elo
-- ==========================================================================================
local function eloOf(p: Player): number
	local profile = DataService.get(p)
	return profile and profile.duel and profile.duel.elo or D.startElo
end

local function average(list: { Player }): number
	if #list == 0 then return D.startElo end
	local sum = 0
	for _, p in ipairs(list) do sum += eloOf(p) end
	return sum / #list
end

-- ==========================================================================================
-- Un duel
-- ==========================================================================================
local nextId = 0

local function alive(p: Player): boolean
	local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	return p.Parent ~= nil and h ~= nil and h.Health > 0
end

local function present(list: { Player }): { Player }
	local out = {}
	for _, p in ipairs(list) do if p.Parent and p:GetAttribute("Zone") == "duel" then table.insert(out, p) end end
	return out
end

local function runDuel(def: any, players: { Player }, arena: Arena)
	nextId += 1
	local id = nextId
	for i = #players, 2, -1 do local j = math.random(i); players[i], players[j] = players[j], players[i] end
	local teamA, teamB = {}, {}
	for i, p in ipairs(players) do table.insert(if i <= def.size then teamA else teamB, p) end
	local tagA, tagB = "DuelA_" .. id, "DuelB_" .. id

	-- mises : chacun paie en entrant (vérifié juste avant), le pot va aux gagnants
	local pot = 0
	local paid: { [Player]: number } = {}   -- mise réellement prise (des pièces ont pu être dépensées depuis la plateforme)
	for _, p in ipairs(players) do
		local profile = DataService.get(p)
		p:SetAttribute("DuelQueued", nil)
		p:SetAttribute("Zone", "duel")
		p:SetAttribute("DuelTeam", if table.find(teamA, p) then tagA else tagB)
		p.Team = nil
		if def.stake > 0 and profile then
			local pay = math.clamp(profile.coins, 0, def.stake)   -- jamais de solde négatif
			profile.coins -= pay; paid[p] = pay; pot += pay
		end
	end

	local score = { A = 0, B = 0 }
	local function nameList(list: { Player }): string
		local n = {}
		for _, p in ipairs(list) do table.insert(n, p.DisplayName) end
		return table.concat(n, " & ")
	end
	local function send(phase: string, extra: { [string]: any }?)
		for _, p in ipairs(present(players)) do
			local mine = table.find(teamA, p) ~= nil
			local msg = {
				phase = phase, mode = def.name, toWin = D.roundsToWin, stake = def.stake, pot = pot,
				me = if mine then score.A else score.B, them = if mine then score.B else score.A,
				myTeam = nameList(if mine then teamA else teamB), theirTeam = nameList(if mine then teamB else teamA),
			}
			for k, v in pairs(extra or {}) do msg[k] = v end
			stateEvent:FireClient(p, msg)
		end
	end

	local killConn = WeaponService.Killed:Connect(function(killer, victim)
		if typeof(victim) ~= "Instance" or not table.find(players, victim) then return end
		local text = WeaponService.nameOf(killer) .. " a éliminé " .. WeaponService.nameOf(victim)
		send("feed", { feed = text })
	end)

	local function spawnRound(p: Player, spawnPos: Vector3, facing: Vector3)
		WeaponService.reset(p)
		p:LoadCharacter()
		local char = p.Character or p.CharacterAdded:Wait()
		char:PivotTo(CFrame.lookAt(spawnPos, Vector3.new(facing.X, spawnPos.Y, facing.Z)))
		local hum = char:WaitForChild("Humanoid") :: Humanoid
		hum.WalkSpeed = 0; hum.JumpPower = 0
	end

	local round = 0
	while score.A < D.roundsToWin and score.B < D.roundsToWin do
		local A, B = present(teamA), present(teamB)
		if #A == 0 or #B == 0 then break end
		round += 1
		local center = (arena.spawnsA[1] + arena.spawnsB[1]) / 2
		for i, p in ipairs(A) do task.spawn(spawnRound, p, arena.spawnsA[i] or arena.spawnsA[1], center) end
		for i, p in ipairs(B) do task.spawn(spawnRound, p, arena.spawnsB[i] or arena.spawnsB[1], center) end
		for c = D.countdown, 1, -1 do
			send("countdown", { round = round, count = c })
			task.wait(1)
		end
		for _, p in ipairs(present(players)) do
			local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			if hum then hum.WalkSpeed = 16; hum.JumpPower = 50 end
			local primary = p:GetAttribute("Primary")
			local w = typeof(primary) == "string" and Config.WEAPONS[primary]
			local sec = p:GetAttribute("Secondary")
			local sw = typeof(sec) == "string" and Config.WEAPONS[sec]
			WeaponService.giveLoadout(p, { if w and w.slot == 0 then primary :: string else D.defaultPrimary,
				if sw and sw.slot == 1 then sec :: string else D.secondary, "knife" })
		end
		local endsAt = os.clock() + D.roundTime
		send("live", { round = round, timeLeft = D.roundTime })
		local winner: string? = nil
		while true do
			task.wait(0.25)
			local aliveA, aliveB = 0, 0
			for _, p in ipairs(present(teamA)) do if alive(p) then aliveA += 1 end end
			for _, p in ipairs(present(teamB)) do if alive(p) then aliveB += 1 end end
			if aliveA == 0 or aliveB == 0 then
				winner = if aliveA > 0 then "A" elseif aliveB > 0 then "B" else nil
				break
			end
			if os.clock() >= endsAt then
				-- temps écoulé : l'équipe qui a le plus de vie l'emporte
				local hpA, hpB = 0, 0
				for _, p in ipairs(present(teamA)) do local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid"); if h then hpA += h.Health end end
				for _, p in ipairs(present(teamB)) do local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid"); if h then hpB += h.Health end end
				winner = if hpA > hpB then "A" elseif hpB > hpA then "B" else nil
				break
			end
		end
		if winner then score[winner] += 1 end
		for _, p in ipairs(present(players)) do
			local mine = if table.find(teamA, p) then "A" else "B"
			stateEvent:FireClient(p, { phase = "round", round = round, toWin = D.roundsToWin, mode = def.name, stake = def.stake, pot = pot,
				me = score[mine], them = score[if mine == "A" then "B" else "A"],
				result = if winner == nil then "draw" elseif winner == mine then "win" else "loss" })
		end
		task.wait(2.5)
	end
	killConn:Disconnect()

	-- vainqueur : le plus de manches ; si une équipe est partie, l'autre gagne
	local A, B = present(teamA), present(teamB)
	local winnerSide: string? = if score.A > score.B then "A" elseif score.B > score.A then "B" else nil
	if #A == 0 and #B > 0 then winnerSide = "B" elseif #B == 0 and #A > 0 then winnerSide = "A" end

	local eloA, eloB = average(teamA), average(teamB)
	local expectA = 1 / (1 + 10 ^ ((eloB - eloA) / 400))
	local winners = if winnerSide == "A" then A elseif winnerSide == "B" then B else {}
	local share = if #winners > 0 then math.floor(pot / #winners) else 0

	for _, p in ipairs(present(players)) do
		local side = if table.find(teamA, p) then "A" else "B"
		local won = winnerSide == side
		local profile = DataService.get(p)
		local delta, coins = 0, 0
		if profile then
			local expected = if side == "A" then expectA else 1 - expectA
			local result = if winnerSide == nil then 0.5 elseif won then 1 else 0
			delta = math.floor(D.eloK * (result - expected) + 0.5)
			local duel = profile.duel
			duel.elo = math.max(0, duel.elo + delta)
			duel.best = math.max(duel.best or 0, duel.elo)
			if winnerSide ~= nil then if won then duel.w += 1 else duel.l += 1 end end
			LeaderboardService.setDuelElo(p, duel.elo)
			if won then coins = share; profile.coins += share end
			if winnerSide == nil and def.stake > 0 then coins = paid[p] or 0; profile.coins += coins end   -- égalité : mise rendue
			RewardService.addXP(p, 40 + (if won then 60 else 0))
			if won then RewardService.missionEvent(p, "win") end
		end
		local rank = CommunityConfig.duelRank(profile and profile.duel.elo or D.startElo)
		endEvent:FireClient(p, { won = won, draw = winnerSide == nil, me = score[side], them = score[if side == "A" then "B" else "A"],
			eloDelta = delta, elo = profile and profile.duel.elo or D.startElo, rank = rank.name, coins = coins, stake = def.stake })
	end

	task.wait(4)
	for _, p in ipairs(present(players)) do task.spawn(LobbyService.spawn, p) end
	busy[arena.slot] = nil
end

-- ==========================================================================================
-- Plateformes du lobby : détection des joueurs debout dessus
-- ==========================================================================================
local function onPad(p: Player, pad: BasePart): boolean
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return false end
	local d = root.Position - pad.Position
	return Vector3.new(d.X, 0, d.Z).Magnitude < 8 and d.Y > -2 and d.Y < 8
end

function DuelService.start()
	task.spawn(function()
		while true do
			task.wait(0.5)
			local taken: { [Player]: boolean } = {}
			for _, pad in ipairs(LobbyService.duelPads) do
				local def = pad.def
				local need = def.size * 2
				local on = {}
				for _, p in ipairs(Players:GetPlayers()) do
					if not taken[p] and p:GetAttribute("Zone") == "lobby" and alive(p) and onPad(p, pad.part) then
						local profile = DataService.get(p)
						if def.stake > 0 and (not profile or profile.coins < def.stake) then
							if not p:GetAttribute("StakeWarned") then
								p:SetAttribute("StakeWarned", true)
								LobbyService.toast(p, "Il te faut " .. def.stake .. " 🪙 pour cette mise", Color3.fromRGB(255, 90, 90))
								task.delay(5, function() p:SetAttribute("StakeWarned", nil) end)
							end
						else
							table.insert(on, p); taken[p] = true
						end
					end
				end
				for _, p in ipairs(Players:GetPlayers()) do
					if p:GetAttribute("Zone") == "lobby" then
						if table.find(on, p) then p:SetAttribute("DuelQueued", def.id)
						elseif p:GetAttribute("DuelQueued") == def.id then p:SetAttribute("DuelQueued", nil) end
					end
				end
				pad.label.Text = def.name .. "  ·  " .. math.min(#on, need) .. "/" .. need .. (if def.stake > 0 then "  ·  " .. def.stake .. " 🪙" else "")
				if #on >= need then
					local group = {}
					for i = 1, need do table.insert(group, on[i]) end
					for _, p in ipairs(group) do p:SetAttribute("Zone", "duel") end   -- bloque tout de suite (pas de double départ)
					local arena = takeArena()
					task.spawn(function()
						local ok, err = pcall(runDuel, def, group, arena)
						if not ok then
							warn("[DuelService] duel interrompu :", err)
							busy[arena.slot] = nil
							for _, p in ipairs(group) do if p.Parent then task.spawn(LobbyService.spawn, p) end end
						end
					end)
				end
			end
		end
	end)
end

return DuelService
