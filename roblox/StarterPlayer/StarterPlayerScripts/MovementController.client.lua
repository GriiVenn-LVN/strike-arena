--!strict
-- StarterPlayerScripts/MovementController (LocalScript)
-- Déplacements façon Call of Duty, mêmes règles que le jeu web (src/60m_move.js) :
--   Maj : sprint (reste actif tant qu'on avance) ; double appui : sprint tactique (jauge 3 s, recharge 5 s)
--   C ou Ctrl : s'accroupir ; en sprintant : glissade (0,8 s), un saut pendant la glissade l'annule en gardant l'élan
--   Saut face à un rebord (caisse, muret, plateforme), même en plein saut : escalade (enjamber ou se hisser)
-- Tirer ou viser coupe le sprint ; l'arme met un court instant à revenir (on ne tire pas en sprintant).
-- En plus, façon Call of Duty : inertie (on prend sa vitesse en ~0,3 s, plus vite au freinage), glissade dirigée
-- à la souris qui ralentit peu à peu, réception lourde qui freine un instant, jauge du sprint tactique sous le viseur.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ModeConfig = require(ReplicatedStorage.Shared.ModeConfig)
local S = require(ReplicatedStorage.Shared.ClientState)
local A = require(ReplicatedStorage.Shared.Attachments)    -- mobilité des accessoires de l'armurier

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local MV = { SPR = 1.36, TAC = 1.62, TAC_DUR = 3, TAC_REC = 5, SLIDE_T = 0.8, SLIDE_CD = 0.9, OUT = 0.13, OUT_TAC = 0.24, CROUCH = 0.55 }
local BASE_SPEED = 16
local SLIDE_MIN = 30           -- vitesse de départ minimale d'une glissade (studs/s)
local CROUCH_CAM = -1.4        -- caméra abaissée accroupi
local SLIDE_CAM = -1.9
local STUDS = Config.STUDS_PER_METER
local HARD_LAND = -16 * STUDS  -- chute plus rapide que 16 m/s : réception lourde (on freine un instant)

local function smooth01(x: number): number x = math.clamp(x, 0, 1); return x * x * (3 - 2 * x) end

local st = { tacE = 1, lastTap = -9, slideT = 0, slideCd = 0, slideDir = Vector3.zero, slideV = 0, slideV0 = 0, camY = 0, crouchKey = false,
	jl = 0, ws = BASE_SPEED, fall = 0, heavyT = 0 }
local slideVel: LinearVelocity? = nil

local Sfx = require(ReplicatedStorage.Shared.Sfx)
local function sound(def: any) Sfx.play(def) end

local function parts(): (Humanoid?, BasePart?)
	local char = player.Character
	if not char then return nil, nil end
	return char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function stopSprint()
	if not S.sprint then return end
	S.fireBlockedUntil = math.max(S.fireBlockedUntil, os.clock() + (if S.tactical then MV.OUT_TAC else MV.OUT))
	S.sprint = false; S.tactical = false
end

local function endSlide()
	S.slide = false
	if slideVel then slideVel:Destroy(); slideVel = nil end
end

local function forwardInput(hum: Humanoid): boolean
	local md = hum.MoveDirection
	if md.Magnitude < 0.1 then return false end
	local look = camera.CFrame.LookVector
	return Vector3.new(look.X, 0, look.Z).Unit:Dot(md.Unit) > 0.5
end

-- ---------- escalade ----------
-- Comme mvLedge / mvMantle du web : un rebord entre 0,56 et 2,15 m devant soi, avec de la place pour se tenir debout.
-- Rebord bas (muret, barrière, caisse basse) : on l'enjambe s'il y a du vide derrière, sinon on monte dessus ;
-- rebord haut : on se hisse (mains sur le rebord, arme baissée : ViewmodelController / SoldierAnim).
-- Le mouvement est interpolé (le corps monte puis avance), le Humanoid passe en état Physics le temps du geste.
type Mantle = { t: number, dur: number, p0: Vector3, p1: Vector3, peak: number, over: boolean, rot: CFrame }
local mt: Mantle? = nil
local LOW_REL = 1.15                -- au-dessus (m) : rebord haut, on se hisse à deux mains

local function isBody(r: RaycastResult): boolean
	local m = r.Instance:FindFirstAncestorOfClass("Model")
	return m ~= nil and m:FindFirstChildOfClass("Humanoid") ~= nil
end

local function tryMantle(hum: Humanoid, root: BasePart): boolean
	if mt or S.mantle then return false end
	local look = camera.CFrame.LookVector
	local fwd = Vector3.new(look.X, 0, look.Z)
	if fwd.Magnitude < 0.1 then return false end
	fwd = fwd.Unit
	local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance, camera }
	local stand = hum.HipHeight + root.Size.Y / 2                 -- hauteur du centre du corps au-dessus des pieds
	local feet = root.Position - Vector3.new(0, stand, 0)
	-- un obstacle juste devant : genoux, taille ou poitrine (le plus proche)
	local wall: RaycastResult? = nil
	for _, y in ipairs({ 1.2, 2.8, 4.6 }) do
		local r = workspace:Raycast(feet + Vector3.new(0, y, 0), fwd * 3.2, params)
		if r and not isBody(r) and (not wall or r.Distance < (wall :: RaycastResult).Distance) then wall = r end
	end
	if not wall then return false end
	-- son dessus : entre 0,56 et 2,15 m (comme le web), à peu près plat
	local d = wall.Distance
	local top = workspace:Raycast(feet + fwd * (d + 0.9) + Vector3.new(0, 8.4, 0), Vector3.new(0, -8.4, 0), params)
	if not top or isBody(top) or top.Normal.Y < 0.7 then return false end
	local h = top.Position.Y - feet.Y
	local rel = h / STUDS
	if rel < 0.56 or rel > 2.15 then return false end
	-- place pour se tenir debout au-dessus du rebord, et pas de plafond au-dessus de nous
	if workspace:Raycast(top.Position + Vector3.new(0, 0.2, 0), Vector3.new(0, 5.2, 0), params) then return false end
	if workspace:Raycast(root.Position, Vector3.new(0, h + 1.5, 0), params) then return false end
	local p0 = root.Position
	local edge = feet + fwd * (d + 1.5)                         -- bien posé sur le dessus, pas au bord…
	local deep = workspace:Raycast(Vector3.new(edge.X, top.Position.Y + 1, edge.Z), Vector3.new(0, -1.6, 0), params)
	if not deep then edge = feet + fwd * (d + 0.9) end          -- …sauf si le dessus est étroit
	local onTop = Vector3.new(edge.X, top.Position.Y + stand + 0.05, edge.Z)
	local m: Mantle = { t = 0, dur = 0.26 + 0.12 * rel, p0 = p0, p1 = onTop, peak = onTop.Y, over = false,
		rot = root.CFrame.Rotation }
	-- rebord bas et étroit (muret, barrière) : vide derrière, on passe par-dessus et on retombe de l'autre côté
	if rel <= LOW_REL then
		local beyond = feet + fwd * (d + 2.8)
		local clear = not workspace:Raycast(top.Position + Vector3.new(0, 2.6, 0) - fwd * (d + 0.9), fwd * (d + 3.4), params)
		local far = workspace:Raycast(beyond + Vector3.new(0, h + 1, 0), Vector3.new(0, -(h + 6), 0), params)
		if clear and far and not isBody(far) and far.Position.Y < top.Position.Y - 1.5 then
			m.over = true
			m.p1 = Vector3.new(far.Position.X, math.max(far.Position.Y + stand, p0.Y - 3), far.Position.Z)
			m.peak = top.Position.Y + stand + 0.6
			m.dur = 0.42 + 0.08 * rel
		end
	end
	endSlide(); stopSprint()
	mt = m
	S.mantle = true; S.mantleT = os.clock(); S.mantleDur = m.dur; S.mantleHigh = rel > LOW_REL and not m.over
	S.fireBlockedUntil = math.max(S.fireBlockedUntil, os.clock() + m.dur + 0.05)
	S.crouch = false
	pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
	root.AssemblyLinearVelocity = Vector3.zero
	Sfx.play("land", nil, 0.45)
	return true
end

-- position du corps pendant l'escalade (0..1) : monter d'abord, avancer ensuite (mvMantle du web)
local function mantlePos(m: Mantle, a: number): Vector3
	if m.over then
		-- enjamber : on monte au-dessus du rebord en avançant, puis on redescend de l'autre côté
		local fw = smooth01(a)
		local y = if a < 0.45 then m.p0.Y + (m.peak - m.p0.Y) * smooth01(a / 0.45)
			else m.peak + (m.p1.Y - m.peak) * smooth01((a - 0.45) / 0.55) ^ 1.6
		local xz = m.p0:Lerp(m.p1, fw)
		return Vector3.new(xz.X, y, xz.Z)
	end
	local up = smooth01(math.min(1, a / 0.55))
	local fw = smooth01(math.clamp((a - 0.28) / 0.72, 0, 1))
	local xz = m.p0:Lerp(m.p1, fw)
	return Vector3.new(xz.X, m.p0.Y + (m.p1.Y + 0.12 - m.p0.Y) * up, xz.Z)
end

local function endMantle(hum: Humanoid?, root: BasePart?)
	local m = mt
	mt = nil
	S.mantle = false
	if not m or not hum or not root then return end
	if hum.Health > 0 then
		root.CFrame = CFrame.new(m.p1) * m.rot
		root.AssemblyLinearVelocity = if m.over then m.rot.LookVector * 6 else Vector3.zero
		pcall(function() hum:ChangeState(if m.over then Enum.HumanoidStateType.Freefall else Enum.HumanoidStateType.Running) end)
		st.jl = os.clock() + 0.35                -- pas de saut tout de suite après (mvState.jl du web)
		Sfx.play("land", nil, 0.3)
	end
end

local function mantleStep(dt: number)
	local m = mt
	if not m then return end
	local hum, root = parts()
	if not hum or not root or hum.Health <= 0 then endMantle(nil, nil); return end
	m.t += dt
	local a = math.min(1, m.t / m.dur)
	if a >= 1 then endMantle(hum, root); return end
	root.CFrame = CFrame.new(mantlePos(m, a)) * m.rot
	root.AssemblyLinearVelocity = Vector3.zero
end

-- ---------- commandes ----------
local function onSprint(_: string, state: Enum.UserInputState)
	if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	local hum = parts()
	if not hum or S.slide or S.mantle or not forwardInput(hum) then return Enum.ContextActionResult.Pass end
	local t = os.clock()
	if S.sprint and t - st.lastTap < 0.35 and st.tacE > 0.3 then S.tactical = true end
	S.sprint = true; S.crouch = false; st.lastTap = t
	return Enum.ContextActionResult.Pass
end

local function onCrouch(_: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		st.crouchKey = true
		if S.mantle then return Enum.ContextActionResult.Sink end
		local hum, root = parts()
		if hum and root and S.sprint and st.slideCd <= 0 and hum.FloorMaterial ~= Enum.Material.Air then
			local v = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
			if v.Magnitude > BASE_SPEED * 0.95 then
				-- glissade : vitesse imposée qui décroît, caméra basse, arme inclinée (viewmodel)
				S.slide = true; st.slideT = 0; st.slideCd = MV.SLIDE_CD
				st.slideDir = v.Unit; st.slideV = math.max(v.Magnitude * 1.22, SLIDE_MIN); st.slideV0 = st.slideV
				S.sprint = false; S.tactical = false
				local att = root:FindFirstChild("RootAttachment") :: Attachment?
				if att then
					local lv = Instance.new("LinearVelocity"); lv.Attachment0 = att
					lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
					lv.PrimaryTangentAxis = Vector3.xAxis; lv.SecondaryTangentAxis = Vector3.zAxis
					lv.RelativeTo = Enum.ActuatorRelativeTo.World
					lv.MaxForce = 1e6; lv.PlaneVelocity = Vector2.new(st.slideDir.X, st.slideDir.Z) * st.slideV
					lv.Parent = root
					slideVel = lv
				end
				sound(ModeConfig.SOUNDS.slide)
				return Enum.ContextActionResult.Sink
			end
		end
		S.crouch = not S.crouch                  -- appui = bascule accroupi / debout
		if S.crouch then stopSprint() end
	elseif state == Enum.UserInputState.End then
		st.crouchKey = false
	end
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindAction("Sprint", onSprint, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
ContextActionService:BindAction("Crouch", onCrouch, true, Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)
ContextActionService:SetTitle("Sprint", "Sprint"); ContextActionService:SetTitle("Crouch", "Accr.")
ContextActionService:SetPosition("Sprint", UDim2.new(1, -230, 1, -120)); ContextActionService:SetPosition("Crouch", UDim2.new(1, -230, 1, -60))

-- saut : annule la glissade (en gardant l'élan) ou lance une escalade
UserInputService.JumpRequest:Connect(function()
	local hum, root = parts()
	if not hum or not root or hum.WalkSpeed == 0 or S.mantle then return end
	if S.slide and st.slideT > 0.08 then
		local keep = st.slideDir * st.slideV
		endSlide()
		S.crouch = false
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
		root.AssemblyLinearVelocity = Vector3.new(keep.X, root.AssemblyLinearVelocity.Y, keep.Z)
		return
	end
	if S.crouch then S.crouch = false end
	-- en avançant (ou à l'arrêt face au rebord), pas en reculant
	if os.clock() > st.jl and (forwardInput(hum) or hum.MoveDirection.Magnitude < 0.1) then tryMantle(hum, root) end
end)

-- ---------- jauge du sprint tactique (mvHud du web) : petite barre sous le viseur ----------
local tacGui = Instance.new("ScreenGui"); tacGui.Name = "TacBar"; tacGui.ResetOnSpawn = false; tacGui.IgnoreGuiInset = true
tacGui.DisplayOrder = 4; tacGui.Parent = player:WaitForChild("PlayerGui")
local tacBg = Instance.new("Frame"); tacBg.AnchorPoint = Vector2.new(0.5, 0); tacBg.Position = UDim2.new(0.5, 0, 0.5, 46)
tacBg.Size = UDim2.fromOffset(64, 4); tacBg.BackgroundColor3 = Color3.new(0, 0, 0); tacBg.BackgroundTransparency = 1
tacBg.BorderSizePixel = 0; tacBg.Parent = tacGui
local tacCorner = Instance.new("UICorner"); tacCorner.CornerRadius = UDim.new(0, 3); tacCorner.Parent = tacBg
local tacFill = Instance.new("Frame"); tacFill.Size = UDim2.fromScale(1, 1); tacFill.BackgroundColor3 = Color3.fromRGB(255, 179, 92)
tacFill.BackgroundTransparency = 1; tacFill.BorderSizePixel = 0; tacFill.Parent = tacBg
local fillCorner = Instance.new("UICorner"); fillCorner.CornerRadius = UDim.new(0, 3); fillCorner.Parent = tacFill
local tacShow = 0
local function tacHud(dt: number, alive: boolean)
	local show = alive and (S.tactical or st.tacE < 0.999)
	tacShow += ((if show then 1 else 0) - tacShow) * math.min(1, dt * 7)
	tacBg.BackgroundTransparency = 1 - tacShow * 0.5
	tacFill.BackgroundTransparency = 1 - tacShow
	tacFill.Size = UDim2.fromScale(st.tacE, 1)
end

-- ---------- boucle ----------
-- l'escalade déplace le corps juste avant la physique (le Humanoid est en état Physics pendant le geste)
local okPre = pcall(function() RunService.PreSimulation:Connect(mantleStep) end)
if not okPre then RunService.Stepped:Connect(function(_, dt: number) mantleStep(dt) end) end

RunService.RenderStepped:Connect(function(dt: number)
	local hum, root = parts()
	if not hum or not root or hum.Health <= 0 then
		S.sprint = false; S.tactical = false; S.crouch = false; endSlide()
		if mt then endMantle(nil, nil) end
		tacHud(dt, false)
		return
	end
	st.slideCd = math.max(0, st.slideCd - dt)
	local v = root.AssemblyLinearVelocity
	S.speed = Vector3.new(v.X, 0, v.Z).Magnitude; S.vy = v.Y
	S.grounded = hum.FloorMaterial ~= Enum.Material.Air
	if mt then S.speed = 0; S.vy = 0; S.grounded = true end      -- pendant l'escalade : ni balancement ni « réception »

	-- escalade en plein saut : touche de saut tenue face à un rebord, pas en pleine montée (mvTryMantle du web)
	if not mt and not S.grounded and hum.Jump and hum.WalkSpeed > 0 and os.clock() > st.jl and v.Y < 4.5 * STUDS and forwardInput(hum) then
		tryMantle(hum, root)
	end

	-- réception lourde : après une grosse chute, on freine un court instant (comme les jeux COD)
	if not S.grounded then st.fall = math.min(st.fall, v.Y)
	else
		if st.fall < HARD_LAND then st.heavyT = 0.3 end
		st.fall = 0
	end
	st.heavyT = math.max(0, st.heavyT - dt)

	-- ce qui coupe le sprint : ne plus avancer, viser, tirer (WeaponController), s'accroupir
	if S.sprint and (not forwardInput(hum) or S.aiming or S.firing) then stopSprint() end
	if S.tactical then
		st.tacE -= dt / MV.TAC_DUR
		if st.tacE <= 0 then st.tacE = 0; S.tactical = false end
	else
		st.tacE = math.min(1, st.tacE + dt / MV.TAC_REC)
	end
	S.tacE = st.tacE
	tacHud(dt, true)

	-- glissade (mvSlide du web) : la vitesse décroît en k² jusqu'à 45 % de la course, on l'infléchit un peu à la souris
	if S.slide then
		st.slideT += dt
		local k = math.min(1, st.slideT / MV.SLIDE_T)
		st.slideV = st.slideV0 + (BASE_SPEED * 0.45 - st.slideV0) * k * k
		local look = camera.CFrame.LookVector
		local yv = Vector3.new(look.X, 0, look.Z)
		if yv.Magnitude > 0.1 then
			local nd = st.slideDir + (yv.Unit - st.slideDir) * math.min(1, dt * 0.8)
			if nd.Magnitude > 1e-3 then st.slideDir = nd.Unit end
		end
		if slideVel then slideVel.PlaneVelocity = Vector2.new(st.slideDir.X, st.slideDir.Z) * st.slideV end
		if k >= 1 or (not S.grounded and st.slideT > 0.15) then
			endSlide()
			S.crouch = st.crouchKey               -- touche encore enfoncée : on finit accroupi
		end
	end

	-- vitesse : le serveur met WalkSpeed à 0 pour figer un joueur (fin de partie, décompte d'un duel) : on n'y touche pas
	if hum.WalkSpeed > 0 then
		local w = S.weapon and Config.WEAPONS[S.weapon]
		-- poids de l'arme (vitesses du web : M249 plus lente, couteau plus rapide…) × mobilité des accessoires
		local mult = (if w and S.weapon then w.speed * A.modsOf(A.activeOf(player, S.weapon)).mob else 1)
		if S.sprint then mult *= if S.tactical then MV.TAC else MV.SPR
		elseif S.crouch then mult *= MV.CROUCH
		elseif S.aiming then mult *= 0.75 end
		if st.heavyT > 0 then mult *= 0.55 end
		local ch = hum.Parent
		local target = BASE_SPEED * mult * ((ch and ch:GetAttribute("SpeedMult") :: number?) or 1)   -- modificateur « Turbo »
		-- inertie : on repart d'un peu plus de la moitié de la vitesse et on monte vite, on freine plus vite encore ;
		-- en l'air on garde son élan (saut en sprint)
		if math.abs(hum.WalkSpeed - st.ws) > 0.5 then st.ws = hum.WalkSpeed end     -- changée par un autre script
		if S.grounded and hum.MoveDirection.Magnitude < 0.1 then
			st.ws = math.min(target, BASE_SPEED * 0.55 * mult)
		elseif S.grounded then
			st.ws += (target - st.ws) * math.min(1, dt * (if target > st.ws then 7 else 14))
		elseif target > st.ws then
			st.ws += (target - st.ws) * math.min(1, dt * 2)        -- en l'air : on accélère à peine
		end
		st.ws = math.max(st.ws, 0.1)
		hum.WalkSpeed = st.ws
	end

	-- caméra plus basse accroupi / en glissade (descente plus vive en glissade)
	local camTarget = if S.slide then SLIDE_CAM elseif S.crouch then CROUCH_CAM else 0
	st.camY += (camTarget - st.camY) * math.min(1, dt * (if S.slide then 14 else 10))
	hum.CameraOffset = Vector3.new(0, st.camY, 0)
end)

player.CharacterAdded:Connect(function()
	S.sprint = false; S.tactical = false; S.crouch = false; S.mantle = false; mt = nil; endSlide()
	st.tacE = 1; st.camY = 0; st.ws = BASE_SPEED; st.fall = 0; st.heavyT = 0
end)
