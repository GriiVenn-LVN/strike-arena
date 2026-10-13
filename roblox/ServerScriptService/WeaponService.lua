--!strict
-- ServerScriptService/WeaponService (ModuleScript, requis par Main)
-- Tir "hitscan" validé côté serveur (cadence, munitions, portée, équipes), dégâts avec bouclier -> gilet -> santé.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Config = require(ReplicatedStorage.Shared.Config)

local fireEvent = Instance.new("RemoteEvent"); fireEvent.Name = "FireWeapon"; fireEvent.Parent = ReplicatedStorage
local hitFx = Instance.new("RemoteEvent"); hitFx.Name = "HitFeedback"; hitFx.Parent = ReplicatedStorage
local tracerFx = Instance.new("RemoteEvent"); tracerFx.Name = "Tracer"; tracerFx.Parent = ReplicatedStorage

local MAX_RANGE = 400
local X = require(ReplicatedStorage.Shared.ConfigExtra)
local NetService = require(script.Parent.NetService)
local state: { [Player]: { weapon: string, mag: number, reserve: number, nextShot: number, shield: number, armor: number, reduction: number, attachments: { [string]: boolean } } } = {}
local flashFx = Instance.new("RemoteEvent"); flashFx.Name = "FlashFeedback"; flashFx.Parent = ReplicatedStorage

local WeaponService = {}

function WeaponService.giveWeapon(player: Player, key: string)
	local w = Config.WEAPONS[key]
	local att: { [string]: boolean } = {}
	local raw = player:GetAttribute("Attachments_" .. key)
	if typeof(raw) == "string" then
		for a, on in pairs(game:GetService("HttpService"):JSONDecode(raw)) do att[a] = on == true end
	end
	local magMult = att.ext and X.ATTACHMENTS.ext.magMult or 1
	local old = state[player]
	state[player] = { weapon = key, mag = math.ceil(w.mag * magMult), reserve = w.reserve, nextShot = 0, shield = old and old.shield or 0, armor = old and old.armor or 0, reduction = 0, attachments = att }
end

local function damageHumanoid(attacker: Player, victimChar: Model, w, zone: string, dist: number)
	local hum = victimChar:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	local victimPlayer = Players:GetPlayerFromCharacter(victimChar)
	local dmg = w.dmg * (zone == "Head" and w.hs or (zone == "Leg" and 0.75 or 1))
	local as = state[attacker]
	if as and as.attachments.sil then dmg *= X.ATTACHMENTS.sil.damageMult end
	if dist > 50 then dmg *= math.max(0.5, 1 - (dist - 50) * 0.004) end
	local vs = victimPlayer and state[victimPlayer]
	if vs and vs.reduction > 0 then dmg *= (1 - vs.reduction) end
	if vs and vs.shield > 0 then                       -- le bouclier absorbe en premier
		local absorbed = math.min(vs.shield, dmg)
		vs.shield -= absorbed; dmg -= absorbed
	end
	if dmg > 0 and vs and vs.armor > 0 then            -- puis le gilet (armorPen)
		local hp = dmg * w.armorPen
		vs.armor = math.max(0, vs.armor - (dmg - hp) * 0.5)
		dmg = hp
	end
	hum:TakeDamage(math.max(1, math.floor(dmg + 0.5)))
	hitFx:FireClient(attacker, zone == "Head", hum.Health <= 0)
end

fireEvent.OnServerEvent:Connect(function(player: Player, origin: any, direction: any)
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then return end
	local s = state[player]
	local char = player.Character
	if not s or not char then return end
	local w = Config.WEAPONS[s.weapon]
	local now = os.clock()
	if now < s.nextShot - 0.02 or s.mag <= 0 then return end          -- anti-spam / pas de munition
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (origin - root.Position).Magnitude > 8 then return end -- l'origine doit rester près du joueur
	s.nextShot = now + 60 / w.rpm
	s.mag -= 1

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	NetService.rewound(player, function()
	for _ = 1, (w.pellets or 1) do
		local spread = math.rad(w.spread)
		local dir = (CFrame.lookAlong(Vector3.zero, direction.Unit) * CFrame.Angles(
			(math.random() - 0.5) * spread, (math.random() - 0.5) * spread, 0)).LookVector
		local result = workspace:Raycast(origin, dir * MAX_RANGE, params)
		local endPos = result and result.Position or origin + dir * MAX_RANGE
		tracerFx:FireAllClients(origin, endPos)
		if result and result.Instance then
			local victim = result.Instance:FindFirstAncestorOfClass("Model")
			if victim and victim:FindFirstChildOfClass("Humanoid") then
				local vp = Players:GetPlayerFromCharacter(victim)
				if not vp or vp.Team ~= player.Team then                  -- pas de tir ami
					local zone = result.Instance.Name == "Head" and "Head" or (result.Instance.Name:find("Leg") and "Leg" or "Body")
					damageHumanoid(player, victim, w, zone, (result.Position - origin).Magnitude)
				end
			end
		end
	end
	return true
	end)
end)

-- ---------- API utilisée par AgentService ----------
function WeaponService.addShield(player: Player, amount: number)
	local s = state[player]; if s then s.shield = math.max(s.shield, math.min(amount, 50)) end
end
function WeaponService.setReduction(player: Player, r: number)
	local s = state[player]; if s then s.reduction = r end
end
function WeaponService.resupply(player: Player)
	local s = state[player]; if not s then return end
	local w = Config.WEAPONS[s.weapon]
	s.mag = math.ceil(w.mag * (s.attachments.ext and X.ATTACHMENTS.ext.magMult or 1)); s.reserve = w.reserve
end
function WeaponService.hearingRange(player: Player): number
	local s = state[player]
	return if s and s.attachments.sil then X.ATTACHMENTS.sil.hearingRange else 42
end

-- ---------- grenades : fumigène (nuage opaque 15 s), flash (aveuglement côté client), frag ----------
local grenades: { [Player]: { [string]: number } } = {}
function WeaponService.giveGrenades(player: Player, smoke: number, flash: number, frag: number)
	grenades[player] = { smoke = smoke, flash = flash, frag = frag }
end
function WeaponService.throwGrenade(player: Player, kind: string, free: boolean?): boolean
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return false end
	if not free then
		local stock = grenades[player]
		if not stock or (stock[kind] or 0) <= 0 then return false end
		stock[kind] -= 1
	end
	local M = Config.STUDS_PER_METER
	local g = Instance.new("Part"); g.Shape = Enum.PartType.Ball; g.Size = Vector3.new(0.8, 0.8, 0.8)
	g.Color = if kind == "smoke" then Color3.fromRGB(170, 175, 185) elseif kind == "flash" then Color3.fromRGB(250, 250, 250) else Color3.fromRGB(60, 80, 55)
	g.Material = Enum.Material.Metal; g.CFrame = root.CFrame * CFrame.new(0, 1.2, -2)
	g.AssemblyLinearVelocity = root.CFrame.LookVector * 55 + Vector3.new(0, 18, 0)
	g.Parent = workspace
	task.delay(if kind == "flash" then 1.5 else 1.3, function()
		local pos = g.Position; g:Destroy()
		if kind == "smoke" then
			local cloud = Instance.new("Part"); cloud.Anchored = true; cloud.CanCollide = false; cloud.Transparency = 1; cloud.Size = Vector3.new(1, 1, 1); cloud.Position = pos; cloud.Parent = workspace
			local pe = Instance.new("ParticleEmitter"); pe.Texture = "rbxasset://textures/particles/smoke_main.dds"; pe.Rate = 60; pe.Lifetime = NumberRange.new(6, 9)
			pe.Speed = NumberRange.new(2, 5); pe.SpreadAngle = Vector2.new(180, 180); pe.Size = NumberSequence.new(14, 20)
			pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
			pe.Color = ColorSequence.new(Color3.fromRGB(200, 205, 212)); pe.Parent = cloud
			task.delay(15, function() pe.Enabled = false; task.wait(9); cloud:Destroy() end)
		elseif kind == "flash" then
			for _, other in ipairs(Players:GetPlayers()) do
				local c = other.Character
				local r = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
				if r then
					local d = (r.Position - pos).Magnitude
					if d < 34 * M then
						local rp = RaycastParams.new(); rp.FilterDescendantsInstances = { c }; rp.FilterType = Enum.RaycastFilterType.Exclude
						if not workspace:Raycast(r.Position, pos - r.Position, rp) then
							local facing = r.CFrame.LookVector:Dot((pos - r.Position).Unit)
							flashFx:FireClient(other, (if facing > 0.1 then 3.4 else 1.1) * math.clamp(1.25 - d / (30 * M), 0.2, 1))
						end
					end
				end
			end
		else
			local ex = Instance.new("Explosion"); ex.Position = pos; ex.BlastRadius = 9 * M; ex.BlastPressure = 0; ex.DestroyJointRadiusPercent = 0; ex.Parent = workspace
			for _, other in ipairs(Players:GetPlayers()) do
				local c = other.Character
				local r = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
				local h = c and c:FindFirstChildOfClass("Humanoid")
				if r and h and other.Team ~= player.Team then
					local d = (r.Position - pos).Magnitude / M
					if d < 9 then h:TakeDamage(140 * (1 - d / 9)) end
				end
			end
		end
	end)
	return true
end

Players.PlayerRemoving:Connect(function(p) state[p] = nil; grenades[p] = nil end)
return WeaponService
