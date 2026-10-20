--!strict
-- ServerScriptService/SoldierService (Script)
-- Côté serveur des soldats du jeu web (l'habillage et l'animation sont faits par chaque client, SoldierController) :
--   attributs répliqués : Outfit (joueur, tenue équipée du profil), Anim (personnage : glissade, sprint, accroupi…
--     envoyés par son client), ReloadT (début de recharge), Dance / DanceT (danse procédurale du web) ;
--   ragdoll à la mort (src/8Zb_ragdoll.js) pour les joueurs et les bots : les Motor6D sont remplacés par des
--     BallSocketConstraint placées aux articulations du soldat, et le corps part dans le sens du tir qui tue
--     (plus fort au fusil à pompe et au sniper, sur la tête pour un tir à la tête).
-- La réapparition (TDMService : LoadCharacter, BotService.remove) ne change pas : le corps disparaît avec le personnage.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")

local Config = require(ReplicatedStorage.Shared.Config)
local Look = require(ReplicatedStorage.Shared.SoldierLook)
local WeaponService = require(script.Parent.WeaponService)
local DataService = require(script.Parent.DataService)

local K = Look.K
local IMP = 6            -- studs/s par m/s d'élan du web (le monde Roblox tombe plus vite : élan renforcé)

-- ---------- remotes ----------
local animRemote = Instance.new("UnreliableRemoteEvent"); animRemote.Name = "SoldierAnim"; animRemote.Parent = ReplicatedStorage
local danceRemote = Instance.new("RemoteEvent"); danceRemote.Name = "SoldierDance"; danceRemote.Parent = ReplicatedStorage

animRemote.OnServerEvent:Connect(function(p: Player, bits: any)
	local c = p.Character
	if c and typeof(bits) == "number" and bits >= 0 and bits < 256 and bits % 1 == 0 then c:SetAttribute("Anim", bits) end
end)

danceRemote.OnServerEvent:Connect(function(p: Player, on: any)
	local c = p.Character
	if not c then return end
	local prof = DataService.get(p) :: any
	local id = prof and prof.equippedDance
	if on == true and typeof(id) == "string" and Config.DANCES[id] then
		c:SetAttribute("Dance", id); c:SetAttribute("DanceT", workspace:GetServerTimeNow())
	else
		c:SetAttribute("Dance", nil)
	end
end)

-- ---------- tenue équipée et recharge ----------
local function soldiers(): { [Model]: any }
	local out: { [Model]: any } = {}
	for _, p in ipairs(Players:GetPlayers()) do if p.Character then out[p.Character] = p end end
	local bots = workspace:FindFirstChild("Bots")
	if bots then for _, m in ipairs(bots:GetChildren()) do if m:IsA("Model") then out[m] = m end end end
	return out
end

task.spawn(function()
	local n = 0
	while true do
		task.wait(0.1)
		n += 1
		if n % 15 == 0 then
			for _, p in ipairs(Players:GetPlayers()) do
				local prof = DataService.get(p) :: any
				local o = prof and prof.equipped and prof.equipped.outfit
				if typeof(o) == "number" and p:GetAttribute("Outfit") ~= o then p:SetAttribute("Outfit", o) end
			end
		end
		for char, c in pairs(soldiers()) do
			local ok, _, _, _, reloading = pcall(WeaponService.current, c)
			if ok then
				local cur = char:GetAttribute("ReloadT")
				if reloading and cur == nil then char:SetAttribute("ReloadT", workspace:GetServerTimeNow())
				elseif not reloading and cur ~= nil then char:SetAttribute("ReloadT", nil) end
			end
		end
	end
end)

-- ---------- ragdoll ----------
pcall(function()
	PhysicsService:RegisterCollisionGroup("Ragdoll")
	PhysicsService:CollisionGroupSetCollidable("Ragdoll", "Ragdoll", false)   -- les membres d'un corps ne se bloquent pas entre eux
end)

-- angle du cône et torsion de chaque articulation (degrés)
local LIMITS: { [string]: { number } } = {
	UpperTorso = { 30, 20 }, Head = { 45, 40 },
	LeftUpperArm = { 110, 60 }, RightUpperArm = { 110, 60 }, LeftLowerArm = { 110, 10 }, RightLowerArm = { 110, 10 },
	LeftHand = { 50, 20 }, RightHand = { 50, 20 },
	LeftUpperLeg = { 80, 20 }, RightUpperLeg = { 80, 20 }, LeftLowerLeg = { 100, 5 }, RightLowerLeg = { 100, 5 },
	LeftFoot = { 35, 10 }, RightFoot = { 35, 10 },
}
-- part de l'élan reçue par chaque membre (poids W du web : corps / tir à la tête)
local WEIGHT: { [string]: { number } } = {
	LowerTorso = { 0.9, 0.6 }, UpperTorso = { 1, 0.9 }, Head = { 0.8, 1.3 },
	UpperLeg = { 0.5, 0.4 }, LowerLeg = { 0.3, 0.2 }, Foot = { 0.15, 0.1 },
	UpperArm = { 0.8, 0.8 }, LowerArm = { 0.6, 0.6 }, Hand = { 0.5, 0.5 },
}

type Impulse = { dir: Vector3, f: number, hs: boolean }
local pending: { [Model]: Impulse } = {}
local done: { [Model]: boolean } = {}

local function push(char: Model, imp: Impulse)
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local base = if hrp then hrp.AssemblyLinearVelocity else Vector3.zero
	local fwd = if hrp then hrp.CFrame.LookVector else Vector3.zero
	for _, p in ipairs(char:GetChildren()) do
		if p:IsA("BasePart") and p ~= hrp then
			local key = string.gsub(string.gsub(p.Name, "^Left", ""), "^Right", "")
			local w = WEIGHT[key]
			if w then
				local k = (if imp.hs then w[2] else w[1]) * imp.f * (0.85 + math.random() * 0.3)
				local up = if key == "LowerTorso" or key == "UpperTorso" then 0.6 else 0.2
				local v = base + imp.dir * (k * IMP) + Vector3.new(0, up * IMP, 0)
				if key == "LowerLeg" then v += fwd * (0.9 * IMP) end                -- les genoux lâchent vers l'avant
				p.AssemblyLinearVelocity = v
			end
		end
	end
end

local function ragdoll(char: Model)
	if done[char] then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not hrp or not char:FindFirstChild("UpperTorso") then return end
	done[char] = true
	local look = Look.look(char)
	local rest = Look.rest(look.rig)
	local N, joints = Look.natural(char, hum, hrp)
	hum.RequiresNeck = false
	local held = char:FindFirstChild("HeldWeapon")
	for _, j in ipairs(joints) do
		local m, p0, p1 = j.m, j.p0, j.p1
		if m.Name ~= "Root" then
			-- articulation au point du soldat du web (repère naturel de la pièce parente), axe X le long du membre
			local piv = rest.pivot[p1.Name]
			local a0cf: CFrame
			if piv then
				local dir = rest.dir[p1.Name] or Vector3.new(0, -1, 0)
				local side = if math.abs(dir.Y) > 0.9 then Vector3.xAxis else Vector3.yAxis
				a0cf = N[p0]:Inverse() * CFrame.fromMatrix(piv * K, dir, side)
			else
				a0cf = Look.jointC0(m)
			end
			local a0 = Instance.new("Attachment"); a0.Name = "RagdollA0_" .. m.Name; a0.CFrame = a0cf; a0.Parent = p0
			local a1 = Instance.new("Attachment"); a1.Name = "RagdollA1_" .. m.Name
			a1.CFrame = p1.CFrame:ToObjectSpace(p0.CFrame * a0cf)   -- même point qu'à l'instant de la mort : pas de saut
			a1.Parent = p1
			local bs = Instance.new("BallSocketConstraint"); bs.Name = "Ragdoll_" .. m.Name
			bs.Attachment0 = a0; bs.Attachment1 = a1
			local lim = LIMITS[p1.Name]
			if lim then
				bs.LimitsEnabled = true; bs.UpperAngle = lim[1]
				bs.TwistLimitsEnabled = true; bs.TwistLowerAngle = -lim[2]; bs.TwistUpperAngle = lim[2]
			end
			-- un peu de frottement aux articulations (tonus qui s'éteint) : le corps s'affaisse au lieu de gigoter comme un
			-- pantin, sans se figer (≈ 5 % du couple de son propre poids)
			pcall(function() bs.MaxFrictionTorque = p1:GetMass() * workspace.Gravity * 0.05 end)
			bs.Parent = p1
			m:Destroy()
		end
	end
	for _, p in ipairs(char:GetDescendants()) do
		if p:IsA("BasePart") and not (held and p:IsDescendantOf(held)) and p ~= held then
			if p == hrp then p.CanCollide = false; p.Massless = true
			elseif p.Parent == char then p.CanCollide = true; p.CollisionGroup = "Ragdoll" end
		end
	end
	char:SetAttribute("Ragdoll", true)
	-- la physique du corps passe au serveur (même chute pour tout le monde)
	for _, p in ipairs(char:GetChildren()) do
		if p:IsA("BasePart") then pcall(function() p:SetNetworkOwner(nil) end) end
	end
	local imp = pending[char]
	if imp then pending[char] = nil; push(char, imp) end
end

local function setup(hum: Humanoid)
	local char = hum.Parent
	if not char or not char:IsA("Model") then return end
	hum.BreakJointsOnDeath = false
	hum.Died:Connect(function()
		task.defer(function() local ok, err = pcall(function() ragdoll(char :: Model); return true end); if not ok then warn("[SoldierService] ragdoll", err) end end)
	end)
	char.AncestryChanged:Connect(function()
		if not char:IsDescendantOf(workspace) then done[char :: Model] = nil; pending[char :: Model] = nil end
	end)
end
workspace.DescendantAdded:Connect(function(d) if d:IsA("Humanoid") then setup(d) end end)
for _, d in ipairs(workspace:GetDescendants()) do if d:IsA("Humanoid") then setup(d) end end

-- élan du tir qui tue (direction : du tueur vers la victime ; sans tireur : en arrière)
WeaponService.Killed:Connect(function(attacker: any, victim: any, key: any, headshot: any)
	local vc = WeaponService.charOf(victim)
	if not vc then return end
	local vr = vc:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not vr then return end
	local ac = attacker and WeaponService.charOf(attacker)
	local ar = ac and ac ~= vc and ac:FindFirstChild("HumanoidRootPart") :: BasePart?
	local dir = if ar then Vector3.new(vr.Position.X - ar.Position.X, 0, vr.Position.Z - ar.Position.Z) else -vr.CFrame.LookVector
	dir = if dir.Magnitude > 1e-3 then dir.Unit else -vr.CFrame.LookVector
	local w = typeof(key) == "string" and Config.WEAPONS[key]
	local c = w and w.cat
	local f = if c == "shotgun" then 3.2 elseif c == "sniper" then 2.9 elseif w and w.melee then 1.1 elseif c == "pistol" then 1.3 else 1.7
	local imp: Impulse = { dir = dir, f = f, hs = headshot == true }
	if done[vc] then push(vc, imp) else pending[vc] = imp end
end)
