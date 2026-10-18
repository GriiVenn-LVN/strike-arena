--!strict
-- ServerScriptService/WeaponService (ModuleScript, requis par Main)
-- Tir "hitscan" validé côté serveur : cadence, munitions, recharge, changement d'arme, couteau, équipes.
-- Dégâts : bouclier -> gilet -> santé. Le serveur est la seule référence : le client ne fait que demander.
--
-- Un « combattant » est soit un Player, soit le Model d'un bot (BotService). Les deux passent par les
-- mêmes fonctions, ce qui garantit que les dégâts sont identiques pour tout le monde.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Config = require(ReplicatedStorage.Shared.Config)
local X = require(ReplicatedStorage.Shared.ConfigExtra)
local NetService = require(script.Parent.NetService)
local A = require(ReplicatedStorage.Shared.Attachments)       -- armurier (effets des accessoires)
require(script.Parent.ArmoryService)                           -- choix des accessoires / réticules (profil -> attributs Att_, Ret_)
local GrenadeService = require(script.Parent.GrenadeService)

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
local _flashFx = remoteEvent("FlashFeedback")      -- serveur -> joueur aveuglé (GrenadeService)
-- client -> serveur : inclinaison du regard (radians), recopiée en attribut « Pitch » du personnage pour la kill-cam
local pitchFx = Instance.new("UnreliableRemoteEvent"); pitchFx.Name = "AimPitch"; pitchFx.Parent = ReplicatedStorage
pitchFx.OnServerEvent:Connect(function(player: Player, pitch: any)
	local char = player.Character
	if char and typeof(pitch) == "number" and pitch == pitch then char:SetAttribute("Pitch", math.clamp(pitch, -1.5, 1.5)) end
end)

local MAX_RANGE = 400
local MELEE_RANGE = 2.6 * Config.STUDS_PER_METER
local DRAW_TIME = 0.35                             -- temps pour sortir une arme

local WeaponService = {}
WeaponService.damageFilter = nil :: ((any, Model, number, boolean, string) -> number?)?
WeaponService.throwBlocked = nil :: ((any) -> boolean)?   -- posé par MatchService : pas de grenade pendant l'attente

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
	shield: number, armor: number, reduction: number, attachments: { string }, mods: A.Mods,
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
		local team = c:GetAttribute("Team")                  -- équipe dans sa partie (MatchService), « solo:… » en chacun pour soi
		if typeof(team) == "string" then return team end
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
-- Le serveur ne pose qu'une poignée invisible (« HeldWeapon ») avec l'attachment Muzzle au bout du vrai canon.
-- Chaque client y soude la vraie arme du jeu web (WeaponVisuals + WeaponModels) : rien ne passe par le réseau.
-- Si ReplicatedStorage/Assets/Weapons/<clé> existe (Model ou MeshPart fait dans Studio), il est utilisé à la place.
local WeaponInfo = require(ReplicatedStorage.Shared.WeaponInfo)
local WORLD_SCALE = 2.9                            -- studs par mètre pour l'arme tenue (proportions d'un avatar R15)

-- bras levés « en position de tir » : on tourne l'épaule (C0), l'animation de marche reste par-dessus
local function aimPose(char: Model, key: string)
	local w = Config.WEAPONS[key]
	local function pose(armName: string, jointName: string, cf: CFrame?)
		local arm = char:FindFirstChild(armName)
		local joint = arm and arm:FindFirstChild(jointName)
		if not joint or not joint:IsA("Motor6D") then return end
		local base = joint:GetAttribute("BaseC0")
		if typeof(base) ~= "CFrame" then base = joint.C0; joint:SetAttribute("BaseC0", base) end
		joint.C0 = if cf then (base :: CFrame) * cf else base :: CFrame
	end
	if w.melee then
		pose("RightUpperArm", "RightShoulder", CFrame.Angles(math.rad(55), 0, 0))
		pose("LeftUpperArm", "LeftShoulder", nil)
	else
		pose("RightUpperArm", "RightShoulder", CFrame.Angles(math.rad(90), 0, 0))
		pose("LeftUpperArm", "LeftShoulder", CFrame.Angles(math.rad(85), 0, math.rad(-35)))
	end
end

local function attachModel(c: any, key: string)
	local char = WeaponService.charOf(c)
	if not char then return end
	local old = char:FindFirstChild("HeldWeapon"); if old then old:Destroy() end
	local hand = (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")) :: BasePart?
	if not hand then return end
	aimPose(char, key)
	local w = Config.WEAPONS[key]
	local inf = WeaponInfo[key]
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Weapons")
	local src = folder and folder:FindFirstChild(key)
	local model: Instance
	local handle: BasePart
	if src and (src:IsA("Model") or src:IsA("BasePart")) then
		model = src:Clone()
		handle = (if model:IsA("Model") then (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)) else model) :: BasePart
	else
		local p = Instance.new("Part"); p.Name = "Handle"; p.Size = Vector3.new(0.2, 0.2, 0.2); p.Transparency = 1
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
		local a = Instance.new("Attachment"); a.Name = "Muzzle"
		a.Position = if inf then Vector3.new(0, inf.sight * 0.6, inf.muzzle) * WORLD_SCALE elseif w.melee then Vector3.new(0, 0, -0.7) else Vector3.new(0, 0.1, -1.5)
		a.Parent = handle
	end
	-- l'épaule levée fait pointer -Y de la main vers l'avant : l'arme (-Z = canon) est tournée pour suivre
	-- (Weld avec C0 fixe, et non WeldConstraint : la pose de l'épaule n'est appliquée qu'au pas physique suivant)
	local gripOffset = CFrame.new(0, -0.1, 0) * CFrame.Angles(math.rad(-90), 0, 0)
	if model:IsA("Model") then model:PivotTo(hand.CFrame * gripOffset * handle.CFrame:ToObjectSpace(model:GetPivot())) else handle.CFrame = hand.CFrame * gripOffset end
	local weld = Instance.new("Weld"); weld.Part0 = hand; weld.Part1 = handle; weld.C0 = gripOffset; weld.Parent = handle
	model:SetAttribute("Custom", src ~= nil)
	model:SetAttribute("Key", key)
	-- skin de l'arme (attributs Skin_<arme> / Camo_<arme> du joueur, posés par DataService.syncSkins)
	model:SetAttribute("Skin", c:GetAttribute("Skin_" .. key))
	model:SetAttribute("Camo", c:GetAttribute("Camo_" .. key))
	model:SetAttribute("Att", c:GetAttribute("Att_" .. key))        -- accessoires de l'armurier, vus par tout le monde
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

-- accessoires actifs : attribut Att_<arme> posé par ArmoryService (déjà filtré : catégorie, niveau, éliminations)
local function readAttachments(c: any, key: string): { string }
	if not isPlayer(c) then return {} end
	return A.activeOf(c, key)
end

local function magSize(key: string, att: { string }): number
	return math.ceil(Config.WEAPONS[key].mag * A.modsOf(att).mag)
end

-- Donne un jeu d'armes complet (ex. { "galil", "glock", "knife" }) et sort la première.
function WeaponService.giveLoadout(c: any, keys: { string })
	local old = state[c]
	local s: WState = {
		loadout = {}, slot = 1, weapon = keys[1], ammo = {}, nextShot = 0, reloading = false, reloadToken = 0,
		shield = old and old.shield or 0, armor = old and old.armor or 0, reduction = 0, attachments = {}, mods = A.neutral(),
	}
	for _, k in ipairs(keys) do
		if Config.WEAPONS[k] then
			table.insert(s.loadout, k)
			s.ammo[k] = { mag = magSize(k, readAttachments(c, k)), reserve = Config.WEAPONS[k].reserve }
		end
	end
	if #s.loadout == 0 then return end
	s.weapon = s.loadout[1]
	s.attachments = readAttachments(c, s.weapon); s.mods = A.modsOf(s.attachments)
	s.nextShot = now() + DRAW_TIME
	state[c] = s
	if not old then GrenadeService.defaultKit(c) end        -- équipement du web (dmLoadout) ; giveGrenades le remplace
	attachModel(c, s.weapon)
	syncShield(c)
	notify(c)
end

-- Une seule arme + couteau.
function WeaponService.giveWeapon(c: any, key: string)
	WeaponService.giveLoadout(c, { key, "knife" })
end

function WeaponService.switchTo(c: any, slot: number)
	local s = state[c]
	if not s or not s.loadout[slot] or s.slot == slot then return end
	s.slot = slot; s.weapon = s.loadout[slot]
	s.reloading = false; s.reloadToken += 1
	s.attachments = readAttachments(c, s.weapon); s.mods = A.modsOf(s.attachments)
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
	task.delay(w.reload * s.mods.rel, function()
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
	GrenadeService.reset(c)
	local char = WeaponService.charOf(c)
	if char then dead[char] = nil end
end

-- ---------- dégâts ----------
-- Point d'entrée unique pour tous les dégâts (balles, couteau, grenade) : bouclier -> gilet -> santé.
function WeaponService.applyDamage(attacker: any, victimChar: Model, raw: number, headshot: boolean, weaponKey: string, armorPen: number)
	local hum = victimChar:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or dead[victimChar] then return end
	-- filtre posé par MatchService (modificateurs « Têtes seulement », « Une balle ») ; nil = aucun dégât
	if WeaponService.damageFilter then
		local r = WeaponService.damageFilter(attacker, victimChar, raw, headshot, weaponKey)
		if not r then return end
		raw = r
	end
	local protectedUntil = victimChar:GetAttribute("ProtectedUntil")
	if typeof(protectedUntil) == "number" and protectedUntil > now() then return end
	local victim = WeaponService.combatantOf(victimChar)
	if victim == attacker then return end
	local dmg = raw
	local vs = state[victim]
	if vs and vs.reduction > 0 then dmg *= (1 - vs.reduction) end
	local total = dmg
	local absorbed = 0
	if vs and vs.shield > 0 then
		absorbed = math.min(vs.shield, dmg)
		vs.shield -= absorbed; dmg -= absorbed
		syncShield(victim)
	end
	if dmg > 0 and vs and vs.armor > 0 then
		local hp = dmg * armorPen
		vs.armor = math.max(0, vs.armor - (dmg - hp) * 0.5)
		dmg = hp
	end
	-- bouclier comme sur le web : tant qu'il tient, la vie ne bouge pas
	local final = if dmg <= 0.01 then 0 else math.max(1, math.floor(dmg + 0.5))
	if final > 0 then hum:TakeDamage(final) end
	local killed = hum.Health <= 0
	if killed then dead[victimChar] = true end
	local shieldOnly = absorbed > 0 and final == 0
	local shieldBroke = absorbed > 0 and vs ~= nil and vs.shield <= 0

	local aChar = WeaponService.charOf(attacker)
	local aRoot = aChar and aChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	local vRoot = victimChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	local shown = math.max(1, math.floor(total + 0.5))   -- le chiffre affiché compte aussi ce que le bouclier a pris
	if isPlayer(attacker) then
		hitFx:FireClient(attacker, headshot, killed, shown, vRoot and vRoot.Position or Vector3.zero, shieldOnly, victimChar)
	end
	if isPlayer(victim) then
		damagedFx:FireClient(victim, aRoot and aRoot.Position or Vector3.zero, shown, headshot, shieldOnly, shieldBroke, aChar)
	end
	damagedEvent:Fire(attacker, victim, shown, headshot)
	if killed then killedEvent:Fire(attacker, victim, weaponKey, headshot) end
end

local function zoneOf(part: Instance): string
	if part.Name == "Head" then return "Head" end
	if part.Name:find("Leg") or part.Name:find("Foot") then return "Leg" end
	return "Body"
end

-- ---------- tir ----------
-- Utilisé par le client (via FireWeapon) et par les bots : mêmes règles pour tout le monde.
function WeaponService.fire(c: any, origin: Vector3, direction: Vector3, aiming: boolean?): boolean
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

	local m = s.mods
	if w.melee then          -- coup de couteau : casse les mines ennemies juste devant (minesNear du web)
		GrenadeService.minesNear(origin + direction.Unit * 1.4 * Config.STUDS_PER_METER, 1.1, c)
	end
	local function shoot()
		for _ = 1, (if w.melee then 1 else (w.pellets or 1)) do
			-- dispersion du web : réduite de 40 % en visée, puis accessoires (visée / hanche)
			local spread = math.rad(w.spread * (if aiming then .6 * m.adsSpr else m.hip))
			local dir = (CFrame.lookAlong(Vector3.zero, direction.Unit) * CFrame.Angles(
				(math.random() - 0.5) * spread, (math.random() - 0.5) * spread, 0)).LookVector
			local range = if w.melee then MELEE_RANGE else MAX_RANGE
			local result = workspace:Raycast(origin, dir * range, params)
			local endPos = result and result.Position or origin + dir * range
			if not w.melee then tracerFx:FireAllClients(origin, endPos, char) end
			if result and result.Instance and result.Instance:GetAttribute("MineId") ~= nil then
				GrenadeService.bulletHit(c, result.Instance)            -- balle sur une mine : elle est cassée
			elseif result and result.Instance and result.Instance:GetAttribute("RangeTarget") then
				targetEvent:Fire(c, result.Instance)
			elseif result and result.Instance then
				local victim = result.Instance:FindFirstAncestorOfClass("Model")
				if victim and victim:FindFirstChildOfClass("Humanoid") then
					local vc = WeaponService.combatantOf(victim)
					if WeaponService.teamOf(vc) ~= myTeam then          -- pas de tir ami
						local zone = zoneOf(result.Instance)
						local dmg = w.dmg * (if zone == "Head" then w.hs elseif zone == "Leg" then 0.75 else 1)
						dmg *= m.dmg
						-- chute des dégâts du web : au-delà de fo × portée (m), −fr par mètre, plancher fmin (0,5)
						local fall = A.FALLOFF[s.weapon]
						local dist = (result.Position - origin).Magnitude / Config.STUDS_PER_METER
						local fo = (if fall then fall[1] else 40) * m.rng
						if not w.melee and dist > fo then dmg *= math.max(fall and fall[3] or .5, 1 - (dist - fo) * (if fall then fall[2] else .004)) end
						local mult = char:GetAttribute("DmgMult")   -- niveau des bots (Modes.DIFFS.dmg)
						if typeof(mult) == "number" then dmg *= mult end
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

fireEvent.OnServerEvent:Connect(function(player: Player, origin: any, direction: any, aiming: any)
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then return end
	if not WeaponService.fire(player, origin, direction, aiming == true) then notify(player) end -- tir refusé : on resynchronise le client
end)
switchEvent.OnServerEvent:Connect(function(player: Player, slot: any)
	if typeof(slot) == "number" then WeaponService.switchTo(player, math.floor(slot)) end
end)
reloadEvent.OnServerEvent:Connect(function(player: Player)
	WeaponService.reload(player)
end)

-- ---------- bouclier, soins, munitions (ramassables de la carte) ----------
-- ajoute du bouclier (ramassable : +25, comme sur le web), sans dépasser Config.SHIELD_MAX
function WeaponService.addShield(c: any, amount: number)
	local s = state[c]; if s then s.shield = math.min(Config.SHIELD_MAX, s.shield + amount); syncShield(c) end
end
function WeaponService.shieldOf(c: any): number
	local s = state[c]; return s and s.shield or 0
end
-- bouclier fixé à une valeur (boutique des modes à manches : bouclier léger 25, lourd 50)
function WeaponService.setShield(c: any, amount: number)
	local s = state[c]; if s then s.shield = math.clamp(amount, 0, Config.SHIELD_MAX); syncShield(c) end
end
-- gilet pare-balles (boutique des modes à manches : 100 = gilet neuf)
function WeaponService.setArmor(c: any, amount: number)
	local s = state[c]; if s then s.armor = math.clamp(amount, 0, 100) end
	local char = WeaponService.charOf(c)
	if char then char:SetAttribute("Armor", math.floor(math.clamp(amount, 0, 100) + 0.5)) end
end
function WeaponService.armorOf(c: any): number
	local s = state[c]; return s and s.armor or 0
end
function WeaponService.setReduction(c: any, r: number)
	local s = state[c]; if s then s.reduction = r end
end
-- Réserve d'une arme (Arme tournante, Mastodonte : 999 = illimitée)
function WeaponService.setReserve(c: any, key: string, n: number)
	local s = state[c]
	local a = s and s.ammo[key]
	if a then a.reserve = n; notify(c) end
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
	return if s and s.mods.sil then X.ATTACHMENTS.sil.hearingRange else 42
end

-- ---------- grenades et mines : GrenadeService (trajectoire, rebonds, mèches, dégâts, flash, fumée) ----------
-- compatibilité : (fumigènes, flashs, frags[, mines])
function WeaponService.giveGrenades(c: any, smoke: number, flash: number, frag: number, mine: number?)
	GrenadeService.set(c, frag, flash, smoke, mine or 0)
end
-- rend une grenade de ce type si le combattant n'en a plus (modificateur « Grenades à volonté ») ; true si rendue
function WeaponService.refillGrenade(c: any, kind: string): boolean
	return GrenadeService.refill(c, kind)
end
-- target : point visé (bots, trajectoire en cloche du web) ; sinon le regard du personnage
function WeaponService.throwGrenade(c: any, kind: string, free: boolean?, target: Vector3?): boolean
	return GrenadeService.throw(c, kind, free, nil, target)
end
WeaponService.placeMine = GrenadeService.placeMine
-- stock de grenades et de mines d'un combattant ({ frag, flash, smoke, mine }), nil s'il n'en a pas
function WeaponService.grenadesOf(c: any): { frag: number, flash: number, smoke: number, mine: number }?
	return GrenadeService.get(c)
end
-- recharge l'arme en main et les autres armes au maximum du chargeur (panneau admin : balles infinies)
function WeaponService.fillMags(c: any)
	local s = state[c]; if not s then return end
	for _, k in ipairs(s.loadout) do
		local a = s.ammo[k]
		if a and not Config.WEAPONS[k].melee then
			a.mag = math.max(a.mag, magSize(k, if k == s.weapon then s.attachments else readAttachments(c, k)))
			a.reserve = math.max(a.reserve, Config.WEAPONS[k].reserve)
		end
	end
	notify(c)
end
WeaponService.smokeBlocks = GrenadeService.smokeBlocks
WeaponService.clearGrenades = GrenadeService.clear
-- itère sur les combattants armés (joueurs et bots)
function WeaponService.eachCombatant(): () -> any
	local list = {}
	for c in pairs(state) do table.insert(list, c) end
	local i = 0
	return function() i += 1; return list[i] end
end
GrenadeService.init(WeaponService)

Players.PlayerRemoving:Connect(function(p) WeaponService.reset(p) end)
return WeaponService
