--!strict
-- ServerScriptService/AgentService (ModuleScript)
-- Capacités d'agents : le client demande (RemoteEvent "UseAbility"), le serveur valide la recharge
-- et applique l'effet. Aucun effet n'est décidé par le client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local X = require(ReplicatedStorage.Shared.ConfigExtra)
local DataService = require(script.Parent.DataService)
local WeaponService = require(script.Parent.WeaponService)

-- 1 mètre du prototype = 3.571 studs (Config.STUDS_PER_METER)
local STUDS = 3.571

local AgentService = {}
local cooldowns: { [Player]: { [number]: number } } = {}
local chosen: { [Player]: string } = {}
local mines: { [Player]: { Part } } = {}
local buffs: { [Player]: { speedUntil: number, domeUntil: number, healUntil: number } } = {}

local useRemote = Instance.new("RemoteEvent"); useRemote.Name = "UseAbility"; useRemote.Parent = ReplicatedStorage
local feedbackRemote = Instance.new("RemoteEvent"); feedbackRemote.Name = "AbilityFeedback"; feedbackRemote.Parent = ReplicatedStorage
local pickAgent = Instance.new("RemoteFunction"); pickAgent.Name = "PickAgent"; pickAgent.Parent = ReplicatedStorage

pickAgent.OnServerInvoke = function(player: Player, id: any)
	if typeof(id) ~= "string" or not X.AGENTS[id] then return false end
	chosen[player] = id
	cooldowns[player] = { 0, 0 }
	return true
end

function AgentService.agentOf(player: Player): string return chosen[player] or "none" end
function AgentService.resetRound(player: Player) cooldowns[player] = { 0, 0 } end

local function root(player: Player): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end
local function humanoid(player: Player): Humanoid?
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end
local function enemies(player: Player, radius: number)
	local out = {}
	local r = root(player); if not r then return out end
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and other.Team ~= player.Team then
			local o = root(other)
			if o and (o.Position - r.Position).Magnitude <= radius * STUDS then table.insert(out, other) end
		end
	end
	return out
end

local handlers: { [string]: (player: Player, a: any) -> boolean } = {}

handlers.scan = function(player, a)
	for _, e in ipairs(enemies(player, a.radius)) do
		-- le client affiche un Highlight sur ces joueurs pour `duration` secondes
		feedbackRemote:FireClient(player, "reveal", e, a.duration)
	end
	return true
end
handlers.sprint = function(player, a)
	local h = humanoid(player); if not h then return false end
	local base = h.WalkSpeed
	h.WalkSpeed = base * a.mult
	task.delay(a.duration, function() if h.Parent then h.WalkSpeed = base end end)
	return true
end
handlers.shield = function(player, a)
	WeaponService.addShield(player, a.amount)
	return true
end
handlers.dome = function(player, a)
	WeaponService.setReduction(player, a.reduction)
	task.delay(a.duration, function() if player.Parent then WeaponService.setReduction(player, 0) end end)
	return true
end
handlers.heal = function(player, a)
	local r = root(player); if not r then return false end
	local t0 = os.clock()
	task.spawn(function()
		while os.clock() - t0 < a.duration do
			for _, other in ipairs(Players:GetPlayers()) do
				local o, h = root(other), humanoid(other)
				if o and h and other.Team == player.Team and (o.Position - r.Position).Magnitude <= a.radius * STUDS then
					h.Health = math.min(h.MaxHealth, h.Health + a.hps * 0.25)
				end
			end
			task.wait(0.25)
		end
	end)
	return true
end
handlers.resupply = function(player, _)
	WeaponService.resupply(player)
	WeaponService.addShield(player, 25)
	return true
end
handlers.dash = function(player, a)
	local r = root(player); if not r then return false end
	local dir = r.CFrame.LookVector * Vector3.new(1, 0, 1)
	local lv = Instance.new("LinearVelocity")
	lv.MaxForce = math.huge; lv.VectorVelocity = dir.Unit * a.speed * STUDS
	lv.Attachment0 = r:FindFirstChildOfClass("Attachment") or Instance.new("Attachment", r)
	lv.Parent = r; Debris:AddItem(lv, a.duration)
	return true
end
handlers.mine = function(player, a)
	local r = root(player); if not r then return false end
	local list = mines[player] or {}; mines[player] = list
	if #list >= a.max then local old = table.remove(list, 1); if old then old:Destroy() end end
	local p = Instance.new("Part"); p.Name = "Mine"; p.Shape = Enum.PartType.Cylinder; p.Size = Vector3.new(0.3, 1.6, 1.6)
	p.Anchored = true; p.CanCollide = false; p.Color = Color3.fromRGB(196, 181, 253); p.Material = Enum.Material.Neon
	p.CFrame = CFrame.new(r.Position - Vector3.new(0, 2.9, 0)) * CFrame.Angles(0, 0, math.rad(90))
	p.Parent = workspace; table.insert(list, p)
	local armedAt = os.clock() + a.armTime
	task.spawn(function()
		while p.Parent do
			task.wait(0.1)
			if os.clock() >= armedAt then
				for _, e in ipairs(enemies(player, 1.7)) do
					local er = root(e)
					if er and (er.Position - p.Position).Magnitude < 1.7 * STUDS then
						local ex = Instance.new("Explosion"); ex.Position = p.Position; ex.BlastRadius = 0; ex.BlastPressure = 0; ex.Parent = workspace
						for _, v in ipairs(enemies(player, a.radius)) do
							local vr, vh = root(v), humanoid(v)
							if vr and vh then
								local d = (vr.Position - p.Position).Magnitude / STUDS
								vh:SetAttribute("LastDamager", player.UserId)
								vh:TakeDamage(a.damage * (1 - d / a.radius) + 10)
							end
						end
						p:Destroy(); return
					end
				end
			end
		end
	end)
	return true
end

useRemote.OnServerEvent:Connect(function(player: Player, index: any)
	if typeof(index) ~= "number" or (index ~= 1 and index ~= 2) then return end
	local agent = X.AGENTS[chosen[player] or "none"]
	local ab = agent and agent.abilities[index]
	if not ab then return end
	local cds = cooldowns[player] or { 0, 0 }; cooldowns[player] = cds
	local now = os.clock()
	if now < cds[index] then return end
	local h = humanoid(player); if not h or h.Health <= 0 then return end
	local fn = handlers[ab.id]
	if fn and fn(player, ab) then
		cds[index] = now + ab.cd
		feedbackRemote:FireClient(player, "cooldown", index, ab.cd)
	elseif ab.id == "smoke" or ab.id == "flash" then
		-- fumigène / flash : délégués à WeaponService (grenades) qui possède la physique des lancers
		if WeaponService.throwGrenade(player, ab.id, true) then
			cds[index] = now + ab.cd
			feedbackRemote:FireClient(player, "cooldown", index, ab.cd)
		end
	end
end)

Players.PlayerRemoving:Connect(function(p)
	cooldowns[p] = nil; chosen[p] = nil; buffs[p] = nil
	for _, m in ipairs(mines[p] or {}) do m:Destroy() end
	mines[p] = nil
end)

return AgentService
