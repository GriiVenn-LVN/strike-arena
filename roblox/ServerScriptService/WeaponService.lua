--!strict
-- ServerScriptService/WeaponService (ModuleScript, requis par Main)
-- Tir "hitscan" validé côté serveur : cadence, munitions, recharge, changement d'arme, couteau, équipes.
-- Dégâts : bouclier -> gilet -> santé. Le serveur est la seule référence : le client ne fait que demander.
--
-- Un « combattant » est soit un Player, soit le Model d'un bot (BotService). Les deux passent par les
-- mêmes fonctions, ce qui garantit que les dégâts sont identiques pour tout le monde.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage.Shared.Config)
local X = require(ReplicatedStorage.Shared.ConfigExtra)
local NetService = require(script.Parent.NetService)

local function remoteEvent(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent"); r.Name = name; r.Parent = ReplicatedStorage; return r
end
local fireEvent = remoteEvent("FireWeapon")       -- client -> serveur : (origine, direction)
local switchEvent = remoteEvent("SwitchWeapon")   -- client -> serveur : (emplacement 1..3)
local reloadEvent = remoteEvent("ReloadWeapon")   -- client -> serveur : ()
local ammoFx = remoteEvent("AmmoState")           -- serveur -> client : état de l'arme tenue
local hitFx = remoteEvent("HitFeedback")          -- serveur -> tireur : (tête, élimination, dégâts, position)
local damagedFx = remoteEvent("Damaged")          -- serveur -> victime : (position du tireur, dégâts, tête)
local tracerFx = remoteEvent("Tracer")            -- serveur -> tous : (origine, impact, personnage du tireur)
local flashFx = remoteEvent("FlashFeedback")

local MAX_RANGE = 400
local MELEE_RANGE = 2.6 * Config.STUDS_PER_METER
local DRAW_TIME = 0.35                             -- temps pour sortir une arme

local WeaponService = {}

-- Événements serveur pour le mode de jeu (score, statistiques, assistances)
local killedEvent = Instance.new("BindableEvent")
local damagedEvent = Instance.new("BindableEvent")
local shotEvent = Instance.new("BindableEvent")
local targetEvent = Instance.new("BindableEvent")
WeaponService.Killed = killedEvent.Event       -- (tueur, victime, cléArme, tête)
WeaponService.Damaged = damagedEvent.Event     -- (tireur, victime, dégâts, tête)
WeaponService.ShotFired = shotEvent.Event      -- (tireur, cléArme)
WeaponService.TargetHit = targetEvent.Event    -- (tireur, cible) : cibles du stand de tir (attribut RangeTarget)

type Ammo = { mag: number, reserve: number }
type WState = {
	loadout: { string }, slot: number, weapon: string, ammo: { [string]: Ammo },
	nextShot: number, reloading: boolean, reloadToken: number,
	shield: number, armor: number, reduction: number, attachments: { [string]: boolean },
}
local state: { [any]: WState } = {}
local dead: { [Model]: boolean } = {}

-- ---------- identité des combattants ----------
function WeaponService.charOf(c: any): Model?
	if typeof(c) == "Instance" and c:IsA("Player") then return c.Character end
	if typeof(c) == "Instance" and c:IsA("Model") then return c end
	return nil
end

function WeaponService.combatantOf(model: Model): any
	return Players:GetPlayerFromCharacter(model) or model
end

function WeaponService.teamOf(c: any): string?
	if typeof(c) == "Instance" and c:IsA("Player") then
		local duelTeam = c:GetAttribute("DuelTeam")          -- en duel, l'équipe du duel passe avant celle du match
		if typeof(duelTeam) == "string" then return duelTeam end
		return c.Team and c.Team.Name or nil
	end
	if typeof(c) == "Instance" and c:IsA("Model") then return c:GetAttribute("Team") :: string? end
	return nil
end

function WeaponService.nameOf(c: any): string
	if typeof(c) == "Instance" and c:IsA("Player") then return c.DisplayName end
	if typeof(c) == "Instance" then return c.Name end
	return "?"
end

local function isPlayer(c: any): boolean
	return typeof(c) == "Instance" and c:IsA("Player")
end

local function now(): number return workspace:GetServerTimeNow() end

-- ---------- arme visible dans la main ----------
-- Si ReplicatedStorage/Assets/Weapons/<clé> existe (Model ou MeshPart), il est utilisé ; sinon un bloc provisoire.
local PLACEHOLDER = {
	pistol = Vector3.new(0.3, 0.7, 1.2), smg = Vector3.new(0.35, 0.8, 2.0), rifle = Vector3.new(0.35, 0.8, 3.0),
	shotgun = Vector3.new(0.4, 0.8, 3.0), sniper = Vector3.new(0.35, 0.8, 3.8), lmg = Vector3.new(0.5, 1.0, 3.4), melee = Vector3.new(0.12, 0.3, 1.4),
}
local function attachModel(c: any, key: string)
	local char = WeaponService.charOf(c)
	if not char then return end
	local old = char:FindFirstChild("HeldWeapon"); if old then old:Destroy() end
	local hand = (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")) :: BasePart?
	if not hand then return end
	local w = Config.WEAPONS[key]
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Weapons")
	local src = folder and folder:FindFirstChild(key)
	local model: Instance
	local handle: BasePart
	if src and (src:IsA("Model") or src:IsA("BasePart")) then
		model = src:Clone()
		handle = (if model:IsA("Model") then (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)) else model) :: BasePart
	else
		local p = Instance.new("Part"); p.Name = "Handle"; p.Size = PLACEHOLDER[w.cat] or PLACEHOLDER.rifle
		p.Color = if w.melee then Color3.fromRGB(200, 205, 212) else Color3.fromRGB(45, 48, 54)
		p.Material = Enum.Material.Metal
		model = p; handle = p
	end
	model.Name = "HeldWeapon"
	local parts = if model:IsA("BasePart") then { model } else {}
	for _, d in ipairs(model:GetDescendants()) do if d:IsA("BasePart") then table.insert(parts, d) end end
	for _, bp in ipairs(parts) do
		local b = bp :: BasePart
		b.Anchored = false; b.CanCollide = false; b.CanQuery = false; b.CanTouch = false; b.Massless = true
	end
	if not handle:FindFirstChild("Muzzle") then
		local a = Instance.new("Attachment"); a.Name = "Muzzle"; a.Position = Vector3.new(0, 0.1, -handle.Size.Z / 2); a.Parent = handle
	end
	local target = hand.CFrame * CFrame.new(0, -0.2, -handle.Size.Z / 2 + 0.3)
	if model:IsA("Model") then model:PivotTo(target * handle.CFrame:ToObjectSpace(model:GetPivot())) else handle.CFrame = target end
	local weld = Instance.new("WeldConstraint"); weld.Part0 = hand; weld.Part1 = handle; weld.Parent = handle
	model.Parent = char
	char:SetAttribute("Weapon", key)
end

-- ---------- état et notification ----------
local function current(s: WState): Ammo
	local a = s.ammo[s.weapon]
	if not a then a = { mag = 0, reserve = 0 }; s.ammo[s.weapon] = a end
	return a
end

local function notify(c: any)
	local s = state[c]
	if not s or not isPlayer(c) then return end
	local a = current(s)
	ammoFx:FireClient(c, { weapon = s.weapon, mag = a.mag, reserve = a.reserve, reloading = s.reloading, slot = s.slot, loadout = s.loadout })
end

-- Le bouclier vit sur le serveur : on le recopie dans un attribut du personnage pour le HUD.
local function syncShield(c: any)
	local s, char = state[c], WeaponService.charOf(c)
	if s and char then char:SetAttribute("Shield", math.floor(s.shield + 0.5)) end
end

local function readAttachments(c: any, key: string): { [string]: boolean }
	local att: { [string]: boolean } = {}
	if not isPlayer(c) then return att end
	local raw = c:GetAttribute("Attachments_" .. key)
	if typeof(raw) == "string" then
		local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and typeof(data) == "table" then for a, on in pairs(data) do att[a] = on == true end end
	end
	return att
end

local function magSize(key: string, att: { [string]: boolean }): number
	return math.ceil(Config.WEAPONS[key].mag * (if att.ext then X.ATTACHMENTS.ext.magMult else 1))
end

-- Donne un jeu d'armes complet (ex. { "galil", "glock", "knife" }) et sort la première.
function WeaponService.giveLoadout(c: any, keys: { string })
	local old = state[c]
	local s: WState = {
		loadout = {}, slot = 1, weapon = keys[1], ammo = {}, nextShot = 0, reloading = false, reloadToken = 0,
		shield = old and old.shield or 0, armor = old and old.armor or 0, reduction = 0, attachments = {},
	}
	for _, k in ipairs(keys) do
		if Config.WEAPONS[k] then
			table.insert(s.loadout, k)
			s.ammo[k] = { mag = magSize(k, readAttachments(c, k)), reserve = Config.WEAPONS[k].reserve }
		end
	end
	if #s.loadout == 0 then return end
	s.weapon = s.loadout[1]
	s.attachments = readAttachments(c, s.weapon)
	s.nextShot = now() + DRAW_TIME
	state[c] = s
	attachModel(c, s.weapon)
	syncShield(c)
	notify(c)
end

-- Compatibilité avec RoundService (mode bombe) : une seule arme + couteau.
function WeaponService.giveWeapon(c: any, key: string)
	WeaponService.giveLoadout(c, { key, "knife" })
end

function WeaponService.switchTo(c: any, slot: number)
	local s = state[c]
	if not s or not s.loadout[slot] or s.slot == slot then return end
	s.slot = slot; s.weapon = s.loadout[slot]
	s.reloading = false; s.reloadToken += 1
	s.attachments = readAttachments(c, s.weapon)
	s.nextShot = now() + DRAW_TIME
	attachModel(c, s.weapon)
	notify(c)
end

function WeaponService.reload(c: any)
	local s = state[c]
	if not s or s.reloading then return end
	local w = Config.WEAPONS[s.weapon]
	local a = current(s)
	if w.melee or a.reserve <= 0 or a.mag >= magSize(s.weapon, s.attachments) then return end
	s.reloading = true; s.reloadToken += 1
	local token, key = s.reloadToken, s.weapon
	notify(c)
	task.delay(w.reload, function()
		local s2 = state[c]
		if s2 ~= s or s.reloadToken ~= token or s.weapon ~= key then return end
		local need = magSize(key, s.attachments) - a.mag
		local take = math.min(need, a.reserve)
		a.mag += take; a.reserve -= take
		s.reloading = false
		notify(c)
	end)
end

function WeaponService.current(c: any): (string?, number, number, boolean)
	local s = state[c]
	if not s then return nil, 0, 0, false end
	local a = current(s)
	return s.weapon, a.mag, a.reserve, s.reloading
end

function WeaponService.reset(c: any)
	state[c] = nil
	local char = WeaponService.charOf(c)
	if char then dead[char] = nil end
end

-- ---------- dégâts ----------
-- Point d'entrée unique pour tous les dégâts (balles, couteau, grenade) : bouclier -> gilet -> santé.
function WeaponService.applyDamage(attacker: any, victimChar: Model, raw: number, headshot: boolean, weaponKey: string, armorPen: number)
	local hum = victimChar:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or dead[victimChar] then return end
	local protectedUntil = victimChar:GetAttribute("ProtectedUntil")
	if typeof(protectedUntil) == "number" and protectedUntil > now() then return end
	local victim = WeaponService.combatantOf(victimChar)
	if victim == attacker then return end
	local dmg = raw
	local vs = state[victim]
	if vs and vs.reduction > 0 then dmg *= (1 - vs.reduction) end
	if vs and vs.shield > 0 then
		local absorbed = math.min(vs.shield, dmg)
		vs.shield -= absorbed; dmg -= absorbed
		syncShield(victim)
	end
	if dmg > 0 and vs and vs.armor > 0 then
		local hp = dmg * armorPen
		vs.armor = math.max(0, vs.armor - (dmg - hp) * 0.5)
		dmg = hp
	end
	local final = math.max(1, math.floor(dmg + 0.5))
	hum:TakeDamage(final)
	local killed = hum.Health <= 0
	if killed then dead[victimChar] = true end

	local aChar = WeaponService.charOf(attacker)
	local aRoot = aChar and aChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	local vRoot = victimChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	if isPlayer(attacker) then
		hitFx:FireClient(attacker, headshot, killed, final, vRoot and vRoot.Position or Vector3.zero)
	end
	if isPlayer(victim) then
		damagedFx:FireClient(victim, aRoot and aRoot.Position or Vector3.zero, final, headshot)
	end
	damagedEvent:Fire(attacker, victim, final, headshot)
	if killed then killedEvent:Fire(attacker, victim, weaponKey, headshot) end
end

local function zoneOf(part: Instance): string
	if part.Name == "Head" then return "Head" end
	if part.Name:find("Leg") or part.Name:find("Foot") then return "Leg" end
	return "Body"
end

-- ---------- tir ----------
-- Utilisé par le client (via FireWeapon) et par les bots : mêmes règles pour tout le monde.
function WeaponService.fire(c: any, origin: Vector3, direction: Vector3): boolean
	local s = state[c]
	local char = WeaponService.charOf(c)
	if not s or not char or direction.Magnitude < 1e-3 then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return false end
	local w = Config.WEAPONS[s.weapon]
	local t = now()
	if t < s.nextShot - 0.03 or s.reloading then return false end
	local a = current(s)
	if not w.melee and a.mag <= 0 then return false end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (origin - root.Position).Magnitude > 8 then return false end -- l'origine doit rester près du tireur
	s.nextShot = t + 60 / w.rpm
	if not w.melee then a.mag -= 1 end
	char:SetAttribute("ProtectedUntil", 0)             -- tirer annule la protection d'apparition
	shotEvent:Fire(c, s.weapon)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local myTeam = WeaponService.teamOf(c)

	local function shoot()
		for _ = 1, (if w.melee then 1 else (w.pellets or 1)) do
			local spread = math.rad(w.spread)
			local dir = (CFrame.lookAlong(Vector3.zero, direction.Unit) * CFrame.Angles(
				(math.random() - 0.5) * spread, (math.random() - 0.5) * spread, 0)).LookVector
			local range = if w.melee then MELEE_RANGE else MAX_RANGE
			local result = workspace:Raycast(origin, dir * range, params)
			local endPos = result and result.Position or origin + dir * range
			if not w.melee then tracerFx:FireAllClients(origin, endPos, char) end
			if result and result.Instance and result.Instance:GetAttribute("RangeTarget") then
				targetEvent:Fire(c, result.Instance)
			elseif result and result.Instance then
				local victim = result.Instance:FindFirstAncestorOfClass("Model")
				if victim and victim:FindFirstChildOfClass("Humanoid") then
					local vc = WeaponService.combatantOf(victim)
					if WeaponService.teamOf(vc) ~= myTeam then          -- pas de tir ami
						local zone = zoneOf(result.Instance)
						local dmg = w.dmg * (if zone == "Head" then w.hs elseif zone == "Leg" then 0.75 else 1)
						if s.attachments.sil then dmg *= X.ATTACHMENTS.sil.damageMult end
						local dist = (result.Position - origin).Magnitude
						if dist > 50 then dmg *= math.max(0.5, 1 - (dist - 50) * 0.004) end
						WeaponService.applyDamage(c, victim, dmg, zone == "Head", s.weapon, w.armorPen)
					end
				end
			end
		end
	end
	if isPlayer(c) then NetService.rewound(c, function() shoot(); return true end) else shoot() end
	if not w.melee and a.mag <= 0 then WeaponService.reload(c) end -- recharge automatique
	return true
end

fireEvent.OnServerEvent:Connect(function(player: Player, origin: any, direction: any)
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then return end
	if not WeaponService.fire(player, origin, direction) then notify(player) end -- tir refusé : on resynchronise le client
end)
switchEvent.OnServerEvent:Connect(function(player: Player, slot: any)
	if typeof(slot) == "number" then WeaponService.switchTo(player, math.floor(slot)) end
end)
reloadEvent.OnServerEvent:Connect(function(player: Player)
	WeaponService.reload(player)
end)

-- ---------- bouclier, soins, munitions (ramassables de la carte) ----------
function WeaponService.addShield(c: any, amount: number)
	local s = state[c]; if s then s.shield = math.max(s.shield, math.min(amount, Config.SHIELD_MAX)); syncShield(c) end
end
function WeaponService.shieldOf(c: any): number
	local s = state[c]; return s and s.shield or 0
end
function WeaponService.setReduction(c: any, r: number)
	local s = state[c]; if s then s.reduction = r end
end
function WeaponService.resupply(c: any)
	local s = state[c]; if not s then return end
	for _, k in ipairs(s.loadout) do
		local a = s.ammo[k]
		if a then a.reserve = Config.WEAPONS[k].reserve end
	end
	notify(c)
end
function WeaponService.hearingRange(c: any): number
	local s = state[c]
	return if s and s.attachments.sil then X.ATTACHMENTS.sil.hearingRange else 42
end

-- ---------- grenades : fumigène (nuage opaque 15 s), flash (aveuglement côté client), frag ----------
local grenades: { [any]: { [string]: number } } = {}
function WeaponService.giveGrenades(c: any, smoke: number, flash: number, frag: number)
	grenades[c] = { smoke = smoke, flash = flash, frag = frag }
end
function WeaponService.throwGrenade(c: any, kind: string, free: boolean?): boolean
	local char = WeaponService.charOf(c)
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return false end
	if not free then
		local stock = grenades[c]
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
				local oc = other.Character
				local r = oc and oc:FindFirstChild("HumanoidRootPart") :: BasePart?
				if oc and r then
					local d = (r.Position - pos).Magnitude
					if d < 34 * M then
						local rp = RaycastParams.new(); rp.FilterDescendantsInstances = { oc }; rp.FilterType = Enum.RaycastFilterType.Exclude
						if not workspace:Raycast(r.Position, pos - r.Position, rp) then
							local facing = r.CFrame.LookVector:Dot((pos - r.Position).Unit)
							flashFx:FireClient(other, (if facing > 0.1 then 3.4 else 1.1) * math.clamp(1.25 - d / (30 * M), 0.2, 1))
						end
					end
				end
			end
		else
			local ex = Instance.new("Explosion"); ex.Position = pos; ex.BlastRadius = 9 * M; ex.BlastPressure = 0; ex.DestroyJointRadiusPercent = 0; ex.Parent = workspace
			local myTeam = WeaponService.teamOf(c)
			for other in pairs(state) do
				local oc = WeaponService.charOf(other)
				local r = oc and oc:FindFirstChild("HumanoidRootPart") :: BasePart?
				if oc and r and WeaponService.teamOf(other) ~= myTeam then
					local d = (r.Position - pos).Magnitude / M
					if d < 9 then WeaponService.applyDamage(c, oc, 140 * (1 - d / 9), false, "frag", 0.6) end
				end
			end
		end
	end)
	return true
end

Players.PlayerRemoving:Connect(function(p) WeaponService.reset(p); grenades[p] = nil end)
return WeaponService
