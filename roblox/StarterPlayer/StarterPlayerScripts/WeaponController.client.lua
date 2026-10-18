--!strict
-- StarterPlayerScripts/WeaponController (LocalScript)
-- Commandes de tir en vue à la première personne : tir (auto / coup par coup), visée (clic droit), recharge (R),
-- armes 1/2/3 et molette, manette (RT/LT/X/Y) et bouton tactile. Recul de caméra, éclair de bouche, traceurs,
-- impacts et sons. Le serveur (WeaponService) reste la seule référence pour les munitions et les dégâts :
-- le client prédit la munition puis se recale sur AmmoState.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local X = require(ReplicatedStorage.Shared.ConfigExtra)
local ModeConfig = require(ReplicatedStorage.Shared.ModeConfig)
local S = require(ReplicatedStorage.Shared.ClientState)      -- partagé avec MovementController et ViewmodelController

local fireRemote = ReplicatedStorage:WaitForChild("FireWeapon") :: RemoteEvent
local switchRemote = ReplicatedStorage:WaitForChild("SwitchWeapon") :: RemoteEvent
local reloadRemote = ReplicatedStorage:WaitForChild("ReloadWeapon") :: RemoteEvent
local ammoState = ReplicatedStorage:WaitForChild("AmmoState") :: RemoteEvent
local tracerRemote = ReplicatedStorage:WaitForChild("Tracer") :: RemoteEvent

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local BASE_FOV = 70

local W = {
	weapon = nil :: string?, mag = 0, reserve = 0, reloading = false, slot = 1, loadout = {} :: { string },
	nextShot = 0, firing = false, fresh = false, aiming = false, matchLive = true,
	recoilPitch = 0, recoilYaw = 0, fov = BASE_FOV, reloadStart = 0, menu = false,
}

-- Mode menu (touche M) : libère la souris en vue à la première personne pour cliquer sur la boutique,
-- le profil ou les caisses. Un bouton « Modal » invisible suffit à Roblox pour débloquer le curseur.
local menuGui = Instance.new("ScreenGui"); menuGui.Name = "MenuCursor"; menuGui.ResetOnSpawn = false; menuGui.Parent = player:WaitForChild("PlayerGui")
local modal = Instance.new("TextButton"); modal.Modal = true; modal.BackgroundTransparency = 1; modal.Text = ""; modal.Size = UDim2.fromOffset(1, 1)
modal.Visible = false; modal.Parent = menuGui

-- ---------- attributs lus par le HUD ----------
local function publish()
	player:SetAttribute("Weapon", W.weapon or "")
	player:SetAttribute("Mag", W.mag)
	player:SetAttribute("Reserve", W.reserve)
	player:SetAttribute("Reloading", W.reloading)
	player:SetAttribute("ReloadStart", W.reloadStart)
	player:SetAttribute("Slot", W.slot)
	player:SetAttribute("Loadout", table.concat(W.loadout, ","))
	player:SetAttribute("Aiming", W.aiming)
	S.weapon = W.weapon; S.mag = W.mag; S.reserve = W.reserve; S.aiming = W.aiming
	S.reloading = W.reloading; S.reloadStart = W.reloadStart
end

-- ---------- sons ----------
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local function playSound(def: any, at: Vector3?) Sfx.play(def, at) end

local function fireSound(key: string): any
	local w = Config.WEAPONS[key]
	return ModeConfig.SOUNDS.fire[if w.melee then "melee" else w.cat] or ModeConfig.SOUNDS.fire.rifle
end

-- ---------- effets visuels ----------
local function tracer(from: Vector3, to: Vector3, mine: boolean)
	local len = (to - from).Magnitude
	if len < 1 then return end
	local p = Instance.new("Part"); p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
	p.Material = Enum.Material.Neon; p.Color = if mine then Color3.fromRGB(255, 226, 150) else Color3.fromRGB(255, 190, 120)
	p.Size = Vector3.new(0.06, 0.06, len); p.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -len / 2)
	p.Transparency = 0.15; p.Parent = workspace
	TweenService:Create(p, TweenInfo.new(0.09), { Transparency = 1 }):Play()
	Debris:AddItem(p, 0.12)
	-- étincelle d'impact
	local spark = Instance.new("Part"); spark.Anchored = true; spark.CanCollide = false; spark.CanQuery = false; spark.CanTouch = false
	spark.Shape = Enum.PartType.Ball; spark.Material = Enum.Material.Neon; spark.Color = Color3.fromRGB(255, 210, 140)
	spark.Size = Vector3.new(0.35, 0.35, 0.35); spark.Position = to; spark.Parent = workspace
	TweenService:Create(spark, TweenInfo.new(0.18), { Size = Vector3.new(0.05, 0.05, 0.05), Transparency = 1 }):Play()
	Debris:AddItem(spark, 0.2)
end

local function muzzleFlash(char: Model?)
	local held = char and char:FindFirstChild("HeldWeapon")
	local muzzle = held and held:FindFirstChild("Muzzle", true)
	if not muzzle then return end
	local light = Instance.new("PointLight"); light.Color = Color3.fromRGB(255, 200, 120); light.Range = 10; light.Brightness = 4
	light.Parent = muzzle
	Debris:AddItem(light, 0.05)
end

-- ---------- état serveur ----------
ammoState.OnClientEvent:Connect(function(info: any)
	local changedWeapon = info.weapon ~= W.weapon
	if info.reloading and not W.reloading then
		W.reloadStart = os.clock()
		S.reloadEmpty = W.mag <= 0; S.inspectStart = -1
		S.reload:Fire(info.weapon, S.reloadEmpty)       -- le viewmodel joue l'animation et ses sons (chargeur dehors / dedans)
	end
	W.weapon = info.weapon; W.mag = info.mag; W.reserve = info.reserve; W.reloading = info.reloading
	W.slot = info.slot; W.loadout = info.loadout
	if changedWeapon then W.aiming = false end
	publish()
	if changedWeapon and info.weapon then S.inspectStart = -1; S.draw:Fire(info.weapon) end
end)

tracerRemote.OnClientEvent:Connect(function(origin: Vector3, endPos: Vector3, shooter: Instance?)
	if shooter and shooter == player.Character then return end -- nos propres traceurs sont déjà dessinés
	tracer(origin, endPos, false)
	if shooter then
		local key = shooter:GetAttribute("Weapon")
		if typeof(key) == "string" and Config.WEAPONS[key] then playSound(fireSound(key), origin) end
		muzzleFlash(shooter :: Model)
	end
end)

local stateRemote = ReplicatedStorage:WaitForChild("TDMState", 5) :: RemoteEvent?
if stateRemote then
	stateRemote.OnClientEvent:Connect(function(st: any) W.matchLive = st.state == "live" end)
end

-- ---------- tir ----------
local function alive(): boolean
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

local function tryFire()
	local key = W.weapon
	-- la pause entre deux parties ne bloque que les joueurs du match (pas le lobby ni les duels)
	local blocked = not W.matchLive and player:GetAttribute("Zone") == "tdm"
	if not key or not alive() or blocked or W.menu or player:GetAttribute("UiOpen") == true then return end
	-- on ne tire pas en sprintant ni pendant une escalade ; à la sortie du sprint l'arme met un instant à revenir
	if S.sprint or S.mantle or os.clock() < S.fireBlockedUntil then return end
	local w = Config.WEAPONS[key]
	if not w.auto and not W.fresh then return end
	local t = os.clock()
	if t < W.nextShot or W.reloading then return end
	if not w.melee and W.mag <= 0 then
		if W.fresh then playSound(ModeConfig.SOUNDS.empty) end
		W.fresh = false
		if W.reserve > 0 then reloadRemote:FireServer() end
		return
	end
	W.fresh = false
	W.nextShot = t + 60 / w.rpm
	local cf = camera.CFrame
	fireRemote:FireServer(cf.Position, cf.LookVector)
	if not w.melee then
		W.mag -= 1
		local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character :: Instance }
		local r = workspace:Raycast(cf.Position, cf.LookVector * 400, params)
		local muzzle = S.muzzle or (cf.Position + cf.LookVector * 1.5 - cf.UpVector * 0.4 + cf.RightVector * 0.5)
		tracer(muzzle, if r then r.Position else cf.Position + cf.LookVector * 400, true)
	end
	S.inspectStart = -1
	S.shot:Fire(key)                                   -- recul de l'arme, éclair et douille dans le viewmodel
	playSound(fireSound(key))
	-- recul : plus fort à la hanche, réduit par la poignée verticale
	local att = player:GetAttribute("Attachments_" .. key)
	local grip = typeof(att) == "string" and att:find("\"grip\":true") ~= nil
	local mult = (if W.aiming then 0.65 else 1) * (if grip then X.ATTACHMENTS.grip.recoilMult else 1)
	W.recoilPitch += w.recoil * 0.9 * mult
	W.recoilYaw += (math.random() - 0.5) * w.recoil * 0.5 * mult
	publish()
end

-- ---------- commandes (clavier/souris, manette, tactile) ----------
local function onFire(_: string, st: Enum.UserInputState)
	if st == Enum.UserInputState.Begin then W.firing = true; W.fresh = true
	elseif st == Enum.UserInputState.End or st == Enum.UserInputState.Cancel then W.firing = false end
	S.firing = W.firing                                -- coupe le sprint (MovementController), souris, manette ou tactile
	return Enum.ContextActionResult.Sink
end
local function onAim(_: string, st: Enum.UserInputState)
	local key = W.weapon
	if not key or Config.WEAPONS[key].melee then return Enum.ContextActionResult.Pass end
	W.aiming = st == Enum.UserInputState.Begin
	publish()
	return Enum.ContextActionResult.Sink
end
local function onInspect(_: string, st: Enum.UserInputState)
	if st ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	if W.weapon and not W.reloading and not W.aiming and alive() then
		S.inspectStart = if S.inspectStart > 0 then -1 else os.clock()     -- 2e appui : on arrête l'inspection
	end
	return Enum.ContextActionResult.Sink
end
local function onReload(_: string, st: Enum.UserInputState)
	if st == Enum.UserInputState.Begin then reloadRemote:FireServer() end
	return Enum.ContextActionResult.Sink
end
local function switchTo(slot: number)
	if slot < 1 or slot > #W.loadout or slot == W.slot then return end
	W.aiming = false
	switchRemote:FireServer(slot)
end
local function onSwitch(name: string, st: Enum.UserInputState, input: InputObject)
	if st ~= Enum.UserInputState.Begin and input.UserInputType ~= Enum.UserInputType.MouseWheel then return Enum.ContextActionResult.Pass end
	if name == "Slot1" then switchTo(1) elseif name == "Slot2" then switchTo(2) elseif name == "Slot3" then switchTo(3)
	elseif name == "NextWeapon" then
		local dir = if input.UserInputType == Enum.UserInputType.MouseWheel and input.Position.Z > 0 then -1 else 1
		local n = math.max(1, #W.loadout)
		switchTo((W.slot - 1 + dir) % n + 1)
	end
	return Enum.ContextActionResult.Sink
end

local function onMenu(_: string, st: Enum.UserInputState)
	if st ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	W.menu = not W.menu; W.firing = false; W.aiming = false
	modal.Visible = W.menu
	player:SetAttribute("MenuOpen", W.menu)
	publish()
	return Enum.ContextActionResult.Sink
end
ContextActionService:BindAction("Menu", onMenu, false, Enum.KeyCode.M, Enum.KeyCode.ButtonStart)
ContextActionService:BindAction("Fire", onFire, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
ContextActionService:BindAction("Aim", onAim, true, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2)
ContextActionService:BindAction("Reload", onReload, true, Enum.KeyCode.R, Enum.KeyCode.ButtonX)
ContextActionService:BindAction("Inspect", onInspect, false, Enum.KeyCode.V, Enum.KeyCode.DPadUp)
ContextActionService:BindAction("Slot1", onSwitch, false, Enum.KeyCode.One)
ContextActionService:BindAction("Slot2", onSwitch, false, Enum.KeyCode.Two)
ContextActionService:BindAction("Slot3", onSwitch, false, Enum.KeyCode.Three)
ContextActionService:BindAction("NextWeapon", onSwitch, true, Enum.UserInputType.MouseWheel, Enum.KeyCode.ButtonY)
ContextActionService:SetTitle("Fire", "Tir"); ContextActionService:SetTitle("Aim", "Viser")
ContextActionService:SetTitle("Reload", "R"); ContextActionService:SetTitle("NextWeapon", "Arme")
ContextActionService:SetPosition("Fire", UDim2.new(1, -150, 1, -190))

-- ---------- caméra : première personne, visée, recul ----------
player.CameraMode = Enum.CameraMode.LockFirstPerson
local baseSens = UserInputService.MouseDeltaSensitivity

RunService.RenderStepped:Connect(function()
	if W.firing then tryFire() end
end)

RunService:BindToRenderStep("WeaponCamera", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	if S.kc then return end                -- la kill-cam tient la caméra
	local key = W.weapon
	local w = key and Config.WEAPONS[key]
	local targetFov = BASE_FOV
	if W.aiming and w then targetFov = if (w.zoom or 0) > 0 then BASE_FOV / w.zoom else BASE_FOV * 0.8 end
	W.fov += (targetFov - W.fov) * math.min(1, dt * 14)
	camera.FieldOfView = W.fov
	UserInputService.MouseDeltaSensitivity = baseSens * (W.fov / BASE_FOV)
	-- le recul est un décalage visuel ajouté après la caméra Roblox, qui revient tout seul
	W.recoilPitch *= math.exp(-dt * 9); W.recoilYaw *= math.exp(-dt * 9)
	camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(W.recoilPitch), math.rad(W.recoilYaw), 0)
	UserInputService.MouseIconEnabled = W.menu or player:GetAttribute("UiOpen") == true   -- panneaux Codes / Groupe du lobby
end)

player.CharacterAdded:Connect(function()
	W.firing = false; W.aiming = false; W.recoilPitch = 0; W.recoilYaw = 0
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	publish()
end)
publish()
