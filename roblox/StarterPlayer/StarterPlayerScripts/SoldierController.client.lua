--!strict
-- StarterPlayerScripts/SoldierController (LocalScript)
-- Les soldats du jeu web sur Roblox, pour tout le monde (joueurs, bots, soi-même pour la kill-cam) :
--   habillage : soldat réaliste de l'équipe (T orange / CT bleu / chacun-pour-soi teinté) ou tenue de la boutique
--     (SoldierModels), soudé pièce par pièce aux membres R15, qui sont cachés (sur ce client seulement) ;
--   animation : la pose est recalculée à chaque image comme sur le web (SoldierAnim) et appliquée aux Motor6D
--     (Motor6D.Transform, après les animations Roblox) : marche/course selon la vitesse, accroupi, glissade, sprint,
--     saut et réception, visée (regard), recharge, recul, bras qui tiennent l'arme, danses, mort si pas de ragdoll.
-- Notre propre corps reste caché à la première personne (comme sur le web) : seul le viewmodel est visible.
-- Si EditableMesh est refusé, le R15 garde son apparence mais bouge quand même comme le soldat du web.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local WeaponInfo = require(ReplicatedStorage.Shared.WeaponInfo)
local S = require(ReplicatedStorage.Shared.ClientState)
local Look = require(ReplicatedStorage.Shared.SoldierLook)
local Anim = require(ReplicatedStorage.Shared.SoldierAnim)
local Models = require(ReplicatedStorage.Shared.SoldierModels)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local K = Look.K
local SPEED_K = 5.2 / 16          -- studs/s -> m/s du web (vitesse de base 16 studs/s = course du web 5,2 m/s)
local GRIP = CFrame.new(0, -0.1, 0) * CFrame.Angles(math.rad(-90), 0, 0)   -- arme dans la main (WeaponService)
local FAR = 400                   -- au-delà : plus d'animation
local animRemote = ReplicatedStorage:WaitForChild("SoldierAnim", 30) :: UnreliableRemoteEvent?
local tracerRemote = ReplicatedStorage:WaitForChild("Tracer", 30) :: RemoteEvent?

type D = {
	char: Model, hum: Humanoid, hrp: BasePart, own: boolean, look: Look.LookInfo, rest: Look.Rest,
	N: { [BasePart]: CFrame }, joints: { Look.Joint }, parts: { [string]: BasePart }, BN: { [string]: CFrame },
	anim: Anim.State, rh: { Weld }, items: { BasePart }, dressed: boolean,
	visYaw: number?, visY: number?, pitch: number, fire: number, lastShot: number, hurt: boolean, hp: number,
	weapon: string?, dieDir: number, dead: boolean, gunShown: boolean?, conns: { RBXScriptConnection }, hideConn: boolean,
}
local active: { [Model]: D } = {}

local function scaled(cf: CFrame): CFrame return CFrame.new(cf.Position * K) * cf.Rotation end
local function hash(s: string): number local h = 7; for i = 1, #s do h = (h * 31 + string.byte(s, i)) % 1000003 end; return h end

-- ---------- mains sur l'arme (repère de l'arme, m) : comme userData.right / left des armes du web ----------
local function hands(key: string?): (Vector3, Vector3?)
	local w = key and Config.WEAPONS[key]
	if not w then return Vector3.new(0, -0.03, 0.012), Vector3.new(0, 0.015, -0.25) end
	if w.melee then return Vector3.new(0, 0, 0.04), nil end
	local inf = WeaponInfo[key :: string]
	local l = inf and inf.left
	if l and (math.abs(l[3]) > 0.01 or math.abs(l[2]) > 0.01) then return Vector3.new(0, -0.03, 0.012), Vector3.new(l[1], l[2], l[3]) end
	return Vector3.new(0, -0.03, 0.012), Vector3.new(-0.012, -0.04, 0.02)        -- pistolet : main gauche sous la droite
end

-- ---------- cacher le R15 ----------
local function hide(d: D, inst: Instance)
	if inst:IsA("BasePart") then
		if inst == d.hrp or table.find(d.items, inst) or inst:FindFirstAncestor("HeldWeapon") or inst.Name == "HeldWeapon" then return end
		inst.Transparency = 1
	elseif inst:IsA("Decal") then
		inst.Transparency = 1
	end
end

local function weld(p0: BasePart, p1: BasePart, c0: CFrame): Weld
	p1.CFrame = p0.CFrame * c0
	local w = Instance.new("Weld"); w.Name = "SoldatWeld"; w.Part0 = p0; w.Part1 = p1; w.C0 = c0; w.Parent = p1
	return w
end

local function dress(d: D)
	local ok, items = pcall(Models.parts, d.look)
	if not ok then warn("[SoldierController]", items); return end
	if not items or not d.char.Parent or active[d.char] ~= d then return end
	-- sans articulations Motor6D (par ex. « Avatar Joint Upgrade » de Roblox), rien ne peut être soudé :
	-- on garde alors l'avatar R15 visible au lieu d'un soldat invisible
	local found = 0
	for _, it in ipairs(items) do if d.parts[it.seg] then found += 1 end end
	if found < #items / 2 then
		warn("[SoldierController] articulations introuvables sur " .. d.char.Name .. " (" .. found .. "/" .. #items .. ") : avatar R15 gardé")
		return
	end
	local folder = Instance.new("Folder"); folder.Name = "SoldatWeb"
	for _, it in ipairs(items) do
		local part = d.parts[it.seg]
		if part then
			it.part.Parent = folder
			table.insert(d.items, it.part)
			if it.seg == "RightHand" then
				table.insert(d.rh, weld(part, it.part, GRIP * it.offset))   -- C0 complet posé à chaque image (décalage de la main sur l'arme)
			else
				weld(part, it.part, d.N[part]:Inverse() * scaled(d.rest.B[it.seg]) * it.offset)
			end
			it.part:SetAttribute("Offset", it.offset)
		end
	end
	folder.Parent = d.char
	d.dressed = true
	for _, x in ipairs(d.char:GetDescendants()) do hide(d, x) end
	if d.hideConn then return end
	d.hideConn = true
	table.insert(d.conns, d.char.DescendantAdded:Connect(function(x)
		if x:IsA("BasePart") or x:IsA("Decal") then task.defer(hide, d, x) end
	end))
end

local function forget(char: Model)
	local d = active[char]
	if not d then return end
	active[char] = nil
	for _, c in ipairs(d.conns) do c:Disconnect() end
end

local redress: (Model?) -> ()
local function track(char: Model)
	if active[char] then return end
	task.spawn(function()
		local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
		local hrp = char:WaitForChild("HumanoidRootPart", 10) :: BasePart?
		if not hum or not hrp or not char:WaitForChild("UpperTorso", 10) or not char:WaitForChild("RightHand", 10) or active[char] then return end
		task.wait()                                   -- toutes les articulations sont arrivées
		local look = Look.look(char)
		local N, joints = Look.natural(char, hum, hrp)
		local rest = Look.rest(look.rig)
		local parts, BN = {}, {}
		for p, cf in pairs(N) do
			parts[p.Name] = p
			local B = rest.B[p.Name]
			if B then BN[p.Name] = scaled(B):Inverse() * cf end
		end
		local d: D = {
			char = char, hum = hum, hrp = hrp, own = char == player.Character, look = look, rest = rest,
			N = N, joints = joints, parts = parts, BN = BN, anim = Anim.new(hash(char.Name)), rh = {}, items = {}, dressed = false,
			visYaw = nil, visY = nil, pitch = 0, fire = 0, lastShot = -99, hurt = false, hp = hum.Health,
			weapon = nil, dieDir = math.random(0, 3), dead = false, gunShown = nil, conns = {}, hideConn = false,
		}
		active[char] = d
		table.insert(d.conns, hum.HealthChanged:Connect(function(h)
			if h < d.hp then d.hurt = true end
			d.hp = h
		end))
		if not Players:GetPlayerFromCharacter(char) then table.insert(d.conns, char:GetAttributeChangedSignal("Team"):Connect(function() redress(char) end)) end
		table.insert(d.conns, char.AncestryChanged:Connect(function() if not char:IsDescendantOf(workspace) then forget(char) end end))
		dress(d)
	end)
end

-- refait l'habillage d'un personnage déjà suivi (tenue ou équipe changée)
redress = function(c: Model?)
	if c and active[c] then
		local d = active[c] :: D
		local f = c:FindFirstChild("SoldatWeb"); if f then f:Destroy() end
		d.items = {}; d.rh = {}; d.look = Look.look(c); d.rest = Look.rest(d.look.rig)
		for p2, cf in pairs(d.N) do local B = d.rest.B[p2.Name]; if B then d.BN[p2.Name] = scaled(B):Inverse() * cf end end
		task.spawn(dress, d)
	end
end
-- tenue changée (attribut Outfit) : on refait l'habillage au prochain personnage ; tout de suite si on peut
local function watchPlayer(p: Player)
	p.CharacterAdded:Connect(track)
	if p.Character then track(p.Character) end
	p:GetAttributeChangedSignal("Outfit"):Connect(function() redress(p.Character) end)
	p:GetAttributeChangedSignal("Team"):Connect(function() redress(p.Character) end)   -- Infecté : on change de camp en cours de partie
end
for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end
Players.PlayerAdded:Connect(watchPlayer)
local function watchBots(f: Instance)
	f.ChildAdded:Connect(function(m) if m:IsA("Model") then track(m) end end)
	for _, m in ipairs(f:GetChildren()) do if m:IsA("Model") then track(m) end end
end
local botsFolder = workspace:FindFirstChild("Bots")
if botsFolder then watchBots(botsFolder) end
workspace.ChildAdded:Connect(function(c: Instance) if c.Name == "Bots" and c:IsA("Folder") then watchBots(c) end end)

-- tirs : recul, arme levée
if tracerRemote then
	(tracerRemote :: RemoteEvent).OnClientEvent:Connect(function(_, _, shooter: Instance?)
		local d = shooter and active[shooter :: Model]
		if d then d.fire = 1; d.lastShot = os.clock() end
	end)
end
S.onShot:Connect(function()
	if S.kc then return end                  -- tirs du tueur rejoués par la kill-cam : pas le recul de notre corps
	local c = player.Character
	local d = c and active[c]
	if d then d.fire = 1; d.lastShot = os.clock() end
end)

-- ---------- état envoyé au serveur (les autres voient nos glissades, sprints…) ----------
local lastBits, bitsT = -1, 0
local function myBits(): number
	local b = 0
	if S.slide then b += Anim.SLIDE end
	-- comme anBits du web : la pose de sprint ne s'affiche qu'au-dessus de 80 % de la course
	if S.sprint and S.speed * SPEED_K > 5.2 * 0.8 then b += Anim.SPR; if S.tactical then b += Anim.TAC end end
	if S.mantle then b += Anim.MANT end
	if S.crouch then b += Anim.CROUCH end
	if S.aiming then b += Anim.AIM end
	return b
end

-- ---------- pose ----------
local rayParams = RaycastParams.new(); rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function onGround(d: D): boolean
	if d.own then return d.hum.FloorMaterial ~= Enum.Material.Air end
	local st = d.hum:GetState()
	if st == Enum.HumanoidStateType.Jumping or st == Enum.HumanoidStateType.Freefall then return false end
	rayParams.FilterDescendantsInstances = { d.char }
	local h = d.hum.HipHeight + d.hrp.Size.Y / 2 + 1.2
	return workspace:Raycast(d.hrp.Position, Vector3.new(0, -h, 0), rayParams) ~= nil
end

local function angDiff(a: number, b: number): number local x = (b - a) % (2 * math.pi); if x > math.pi then x -= 2 * math.pi end; return x end

local function setGun(d: D, on: boolean)
	if d.own or d.gunShown == on then return end
	d.gunShown = on
	local held = d.char:FindFirstChild("HeldWeapon")
	if not held then return end
	for _, x in ipairs(held:GetDescendants()) do if x:IsA("BasePart") then x.LocalTransparencyModifier = if on then 0 else 1 end end
end

local function update(d: D, dt: number, t: number)
	local char, hum, hrp = d.char, d.hum, d.hrp
	local alive = hum.Health > 0
	if not alive and not d.dead then
		d.dead = true
		-- la main droite procédurale suit l'avant-bras pendant le ragdoll ; l'arme tombe des mains (comme le web)
		local la = d.parts.RightLowerArm
		for _, w in ipairs(d.rh) do
			local p1 = w.Part1
			if p1 and la then local c0 = la.CFrame:Inverse() * p1.CFrame; w.Part0 = la; w.C0 = c0 end
		end
		d.rh = {}
		setGun(d, false)
	end
	if char:GetAttribute("Ragdoll") then return end            -- articulations remplacées par le serveur
	local look = hrp.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	local v = hrp.AssemblyLinearVelocity
	local flat = Vector3.new(v.X, 0, v.Z)
	local grounded = onGround(d)
	local bits = if d.own then myBits() else (char:GetAttribute("Anim") :: number? or 0)
	-- bots qui foncent (au-delà de la course) : pose de sprint, comme sur le web (pas les zombies)
	if not d.own and not Players:GetPlayerFromCharacter(char) and not char:GetAttribute("Zombie")
		and bit32.band(bits, Anim.SPR) == 0 and flat.Magnitude * SPEED_K > 5.2 * 1.05 then bits += Anim.SPR end
	-- regard : caméra pour soi, attribut Pitch (≈10 fois par seconde) lissé pour les autres
	local pitch = if d.own then math.asin(math.clamp(camera.CFrame.LookVector.Y, -1, 1)) else (char:GetAttribute("Pitch") :: number? or 0)
	d.pitch += (pitch - d.pitch) * math.min(1, dt * 12)
	-- arme et recharge
	local key = char:GetAttribute("Weapon") :: string?
	if key ~= d.weapon then
		if d.weapon ~= nil then d.anim.swT = 0.35 end
		d.weapon = key; d.gunShown = nil
	end
	local right, left = hands(key)
	local reload, reloadMax = 0, 0
	local w = key and Config.WEAPONS[key]
	if w and w.reload > 0 then
		if d.own then
			-- durée réelle (accessoires, atouts) envoyée par le serveur, comme le viewmodel
			local dur = if S.reloadDur > 0 then S.reloadDur else w.reload
			if S.reloading then reloadMax = dur; reload = math.max(0, dur - (os.clock() - S.reloadStart)) end
		else
			local r0 = char:GetAttribute("ReloadT")
			if typeof(r0) == "number" then reloadMax = w.reload; reload = math.max(0, w.reload - (workspace:GetServerTimeNow() - r0)) end
		end
	end
	-- danse (attribut Dance posé par le serveur) : s'arrête si on bouge ou à la fin
	local dance: string? = nil
	local danceT = 0
	local dn, d0 = char:GetAttribute("Dance"), char:GetAttribute("DanceT")
	if typeof(dn) == "string" and typeof(d0) == "number" and Config.DANCES[dn] then
		danceT = workspace:GetServerTimeNow() - d0
		if danceT < Config.DANCES[dn].length and not (danceT > 0.45 and flat.Magnitude * SPEED_K > 1) then dance = dn end
	end
	local ready = bit32.band(bits, Anim.AIM) ~= 0 or os.clock() - d.lastShot < 2.5 or (d.own and alive)
	local st: Anim.Input = {
		speed = flat.Magnitude * SPEED_K, lf = v:Dot(look) * SPEED_K, lr = v:Dot(hrp.CFrame.RightVector) * SPEED_K,
		yaw = yaw, pitch = d.pitch, onGround = grounded, vy = v.Y / Config.STUDS_PER_METER,
		crouch = bit32.band(bits, Anim.CROUCH) ~= 0, bits = bits, alive = alive, ready = ready,
		alert = if os.clock() - d.lastShot < 3 then 1 else 0, hurt = d.hurt, fire = d.fire,
		reload = reload, reloadMax = reloadMax, dance = dance, danceT = danceT, seated = if hum.Sit then 1 else 0,
		dieDir = d.dieDir, right = right, left = left,
	}
	d.hurt = false; d.fire = 0
	local pose = Anim.step(d.anim, st, dt, t)
	setGun(d, pose.gunVisible and alive)
	-- rotation et hauteur lissées (pas de demi-tour sec des bots, marches d'escalier adoucies), comme syncRigs du web
	local yOff, yawOff = 0, 0
	if not d.own then
		if d.visYaw == nil or not alive then d.visYaw = yaw else d.visYaw = (d.visYaw :: number) + angDiff(d.visYaw :: number, yaw) * (1 - math.exp(-dt * 16)) end
		yawOff = angDiff(yaw, d.visYaw :: number)
		local y = hrp.Position.Y
		if d.visY == nil or not grounded or math.abs(y - (d.visY :: number)) > 1.2 * K then d.visY = y
		else d.visY = (d.visY :: number) + (y - (d.visY :: number)) * (1 - math.exp(-dt * 16)) end
		yOff = ((d.visY :: number) - y) / K
	end
	local root = CFrame.new(0, yOff, 0) * CFrame.Angles(0, yawOff, 0) * pose.root
	-- repères des os (m, repère du soldat)
	local F: { [string]: CFrame } = {}
	local spine = pose.spine
	local A = pose.arm
	if d.look.rig == "real" then
		local R = Look.Rig.real
		local b = R.bones
		local Dp = pose.hips.Rotation
		local Pp = pose.hips.Position + R.pelOff
		F.LowerTorso = CFrame.new(Pp) * Dp
		local Ds = spine.Rotation
		local Ps = Pp + Dp * (b.spine - b.pelvis)
		F.UpperTorso = CFrame.new(Ps) * Ds
		local Pn = Ps + Ds * (b.neck - b.spine)
		local Ph = Pn + pose.neck.Rotation * (b.head - b.neck)
		F.Head = CFrame.new(Ph) * pose.head.Rotation
		for _, k in ipairs({ "L", "R" }) do
			local s: string = if k == "L" then "Left" else "Right"
			local Pt = Pp + Dp * (b["thigh" .. k] - b.pelvis)
			local Dt = pose.th[k].Rotation
			local Pc = Pt + Dt * (b["calf" .. k] - b["thigh" .. k])
			local Dc = pose.sh[k].Rotation
			local Pf = Pc + Dc * (b["foot" .. k] - b["calf" .. k])
			F[s .. "UpperLeg"] = CFrame.new(Pt) * Dt; F[s .. "LowerLeg"] = CFrame.new(Pc) * Dc; F[s .. "Foot"] = CFrame.new(Pf) * pose.ft[k].Rotation
			-- bras : IK sur les vraies longueurs du modèle, main sur la cible de la main procédurale (syncRealBody du web)
			local arm, a = R.arm[k], A[k]
			local Su = Ps + Ds * (b["uarm" .. k] - b.spine)
			local Ht = spine * a.H
			local El, Hc = Anim.ik2(Su, Ht, arm.la, arm.lb, Ds * a.pole)
			local Du = Anim.fromTo(arm.dU, (El - Su).Unit)          -- écart à la pose de repos (bras en croix)
			local Pf2 = Su + Du * (b["farm" .. k] - b["uarm" .. k])
			local dF = Hc - Pf2
			local Dfa = Anim.fromTo(arm.dF, if dF.Magnitude > 1e-5 then dF.Unit else Vector3.new(0, -1, 0))
			F[s .. "UpperArm"] = CFrame.new(Su) * Du; F[s .. "LowerArm"] = CFrame.new(Pf2) * Dfa
			F[s .. "Hand"] = CFrame.new(Pf2 + Dfa * (b["hand" .. k] - b["farm" .. k])) * Dfa
		end
	else
		F.LowerTorso = pose.hips; F.UpperTorso = spine; F.Head = pose.head
		for _, k in ipairs({ "L", "R" }) do
			local s: string = if k == "L" then "Left" else "Right"
			F[s .. "UpperLeg"] = pose.th[k]; F[s .. "LowerLeg"] = pose.sh[k]; F[s .. "Foot"] = pose.ft[k]
			local a = A[k]
			local du, df = a.E - a.S, a.H - a.E
			F[s .. "UpperArm"] = spine * CFrame.new(a.S) * Anim.fromTo(Vector3.new(0, -1, 0), if du.Magnitude > 1e-5 then du.Unit else Vector3.new(0, -1, 0))
			F[s .. "LowerArm"] = spine * CFrame.new(a.E) * Anim.fromTo(Vector3.new(0, -1, 0), if df.Magnitude > 1e-5 then df.Unit else Vector3.new(0, -1, 0))
			F[s .. "Hand"] = spine * CFrame.new(a.H) * a.q
		end
	end
	-- cibles des pièces R15 (studs, repère du soldat) ; main droite : l'arme soudée tombe sur le porte-arme du web
	local T: { [BasePart]: CFrame } = { [hrp] = Look.rootOffset(hum, hrp) }
	for name, f in pairs(F) do
		local p = d.parts[name]
		if p and name ~= "RightHand" and d.BN[name] then T[p] = scaled(root * f) * d.BN[name] end
	end
	local rhp = d.parts.RightHand
	if rhp then
		local a = A.R
		local hand = scaled(root * spine * CFrame.new(a.H) * a.q)
		local off = CFrame.new(-right * K)
		T[rhp] = hand * off * GRIP:Inverse()
		for _, wld in ipairs(d.rh) do
			local p1 = wld.Part1
			local o = p1 and p1:GetAttribute("Offset")
			wld.C0 = GRIP * off:Inverse() * (if typeof(o) == "CFrame" then o else CFrame.identity)
		end
	end
	for _, j in ipairs(d.joints) do
		local m = j.m
		if m.Parent then
			local t0 = T[j.p0]
			local t1 = T[j.p1]
			if t0 and not t1 then t1 = t0 * d.N[j.p0]:Inverse() * d.N[j.p1]; T[j.p1] = t1 end
			if t0 and t1 then m.Transform = Look.jointC0(m):Inverse() * t0:Inverse() * t1 * Look.jointC1(m) end
		end
	end
end

local clock = 0
local function step(dt: number)
	clock += dt
	local camPos = camera.CFrame.Position
	for char, d in pairs(active) do
		if not char.Parent or not d.hrp.Parent then forget(char)
		elseif (d.hrp.Position - camPos).Magnitude < FAR or d.own then
			local ok, err = pcall(function() update(d, math.min(dt, 0.1), clock); return true end)
			if not ok then warn("[SoldierController]", err); forget(char) end
		end
	end
	-- notre état d'animation pour les autres (à chaque changement, et une fois par seconde)
	bitsT += dt
	local b = myBits()
	if animRemote and (b ~= lastBits or bitsT > 1) then lastBits = b; bitsT = 0; (animRemote :: UnreliableRemoteEvent):FireServer(b) end
end
-- PreSimulation (= Stepped) : après les animations Roblox, avant la physique ; Motor6D.Transform l'emporte
local ok = pcall(function() RunService.PreSimulation:Connect(step) end)
if not ok then RunService.Stepped:Connect(function(_, dt) step(dt) end) end
