--!strict
-- StarterPlayerScripts/MovementController (LocalScript)
-- Déplacements façon Call of Duty, mêmes règles que le jeu web (src/60m_move.js) :
--   Maj : sprint (reste actif tant qu'on avance) ; double appui : sprint tactique (jauge 3 s, recharge 5 s)
--   C ou Ctrl : s'accroupir ; en sprintant : glissade (0,8 s), un saut pendant la glissade l'annule en gardant l'élan
--   Saut face à un rebord (caisse, muret, plateforme) : escalade
-- Tirer ou viser coupe le sprint ; l'arme met un court instant à revenir (on ne tire pas en sprintant).
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

local st = { tacE = 1, lastTap = -9, slideT = 0, slideCd = 0, slideDir = Vector3.zero, slideV = 0, camY = 0, crouchKey = false }
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
local function tryMantle(hum: Humanoid, root: BasePart): boolean
	local look = camera.CFrame.LookVector
	local fwd = Vector3.new(look.X, 0, look.Z)
	if fwd.Magnitude < 0.1 then return false end
	fwd = fwd.Unit
	local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	local feet = root.Position - Vector3.new(0, hum.HipHeight + root.Size.Y / 2, 0)
	-- un obstacle juste devant, entre les genoux et le haut de la tête…
	local wall = workspace:Raycast(feet + Vector3.new(0, 1.2, 0), fwd * 3.2, params)
	if not wall then return false end
	-- …dont le dessus est entre 2 et 7,5 studs, avec de la place pour se tenir debout
	local top = workspace:Raycast(feet + fwd * (wall.Distance + 1) + Vector3.new(0, 8, 0), Vector3.new(0, -8, 0), params)
	if not top then return false end
	local h = top.Position.Y - feet.Y
	if h < 2 or h > 7.5 then return false end
	if workspace:Raycast(top.Position + Vector3.new(0, 0.2, 0), Vector3.new(0, 5, 0), params) then return false end
	endSlide(); stopSprint()
	S.mantle = true
	local g = workspace.Gravity
	root.AssemblyLinearVelocity = fwd * 10 + Vector3.new(0, math.sqrt(2 * g * (h + 0.9)), 0)
	S.fireBlockedUntil = math.max(S.fireBlockedUntil, os.clock() + 0.45)
	task.delay(0.45, function() S.mantle = false end)
	return true
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
		local hum, root = parts()
		if hum and root and S.sprint and st.slideCd <= 0 and hum.FloorMaterial ~= Enum.Material.Air then
			local v = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
			if v.Magnitude > BASE_SPEED * 0.95 then
				-- glissade : vitesse imposée qui décroît, caméra basse, arme inclinée (viewmodel)
				S.slide = true; st.slideT = 0; st.slideCd = MV.SLIDE_CD
				st.slideDir = v.Unit; st.slideV = math.max(v.Magnitude * 1.22, SLIDE_MIN)
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
	if not hum or not root or hum.WalkSpeed == 0 then return end
	if S.slide and st.slideT > 0.08 then
		local keep = st.slideDir * st.slideV
		endSlide()
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
		root.AssemblyLinearVelocity = Vector3.new(keep.X, root.AssemblyLinearVelocity.Y, keep.Z)
		return
	end
	if not S.mantle and S.crouch then S.crouch = false end
	if not S.mantle then tryMantle(hum, root) end
end)

-- ---------- boucle ----------
RunService.RenderStepped:Connect(function(dt: number)
	local hum, root = parts()
	if not hum or not root or hum.Health <= 0 then
		S.sprint = false; S.tactical = false; S.crouch = false; endSlide(); return
	end
	st.slideCd = math.max(0, st.slideCd - dt)
	local v = root.AssemblyLinearVelocity
	S.speed = Vector3.new(v.X, 0, v.Z).Magnitude; S.vy = v.Y
	S.grounded = hum.FloorMaterial ~= Enum.Material.Air

	-- ce qui coupe le sprint : ne plus avancer, viser, tirer (WeaponController), s'accroupir
	if S.sprint and (not forwardInput(hum) or S.aiming or S.firing) then stopSprint() end
	if S.tactical then
		st.tacE -= dt / MV.TAC_DUR
		if st.tacE <= 0 then st.tacE = 0; S.tactical = false end
	else
		st.tacE = math.min(1, st.tacE + dt / MV.TAC_REC)
	end

	-- glissade
	if S.slide then
		st.slideT += dt
		local k = 1 - st.slideT / MV.SLIDE_T
		st.slideV = math.max(BASE_SPEED * 0.6, st.slideV * (1 - dt * 1.6))
		if slideVel then slideVel.PlaneVelocity = Vector2.new(st.slideDir.X, st.slideDir.Z) * st.slideV end
		if k <= 0 or (not S.grounded and st.slideT > 0.15) then
			endSlide()
			S.crouch = st.crouchKey               -- touche encore enfoncée : on finit accroupi
		end
	end

	-- vitesse : le serveur met WalkSpeed à 0 pour figer un joueur (fin de partie, décompte d'un duel) : on n'y touche pas
	if hum.WalkSpeed > 0 then
		local w = S.weapon and Config.WEAPONS[S.weapon]
		local mult = (if w and S.weapon then w.speed * A.modsOf(A.activeOf(player, S.weapon)).mob else 1)
		if S.sprint then mult *= if S.tactical then MV.TAC else MV.SPR
		elseif S.crouch then mult *= MV.CROUCH
		elseif S.aiming then mult *= 0.75 end
		hum.WalkSpeed = BASE_SPEED * mult
	end

	-- caméra plus basse accroupi / en glissade
	local camTarget = if S.slide then SLIDE_CAM elseif S.crouch then CROUCH_CAM else 0
	st.camY += (camTarget - st.camY) * math.min(1, dt * 12)
	hum.CameraOffset = Vector3.new(0, st.camY, 0)
end)

player.CharacterAdded:Connect(function()
	S.sprint = false; S.tactical = false; S.crouch = false; S.mantle = false; endSlide()
	st.tacE = 1; st.camY = 0
end)
