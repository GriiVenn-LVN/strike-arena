--!strict
-- StarterPlayerScripts/ShieldController (LocalScript)
-- Bouclier et objets à ramasser, comme le jeu web :
--   * les objets (cristal de bouclier, cube de santé, boîte de munitions) tournent et flottent au-dessus de leur anneau ;
--   * message « +25 bouclier » / « +35 santé » / « Munitions » et son quand on en ramasse un ;
--   * étincelles bleues (au lieu du sang) quand une balle frappe un soldat qui a encore du bouclier.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Sfx = require(ReplicatedStorage.Shared.Sfx)

local player = Players.LocalPlayer
local tracerRemote = ReplicatedStorage:WaitForChild("Tracer") :: RemoteEvent

-- ---------- objets qui tournent ----------
type Spin = { model: Model, core: BasePart, parts: { [BasePart]: CFrame }, base: Vector3, phase: number }
local spins: { [Model]: Spin } = {}

local function track(m: Instance)
	if not m:IsA("Model") or m:GetAttribute("Pickup") == nil or spins[m] then return end
	local core = m:WaitForChild("Core", 5) :: BasePart?
	if not core or not m.Parent then return end
	local parts: { [BasePart]: CFrame } = {}
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") and p.Name ~= "Ring" and p.Name ~= "Zone" then parts[p] = core.CFrame:ToObjectSpace(p.CFrame) end
	end
	spins[m] = { model = m, core = core, parts = parts, base = core.Position, phase = core.Position.X }
	m.AncestryChanged:Connect(function() if not m:IsDescendantOf(workspace) then spins[m] = nil end end)
end
workspace.DescendantAdded:Connect(function(d: Instance) if d:IsA("Model") and d.Name:sub(1, 7) == "Pickup_" then task.spawn(track, d) end end)
for _, d in ipairs(workspace:GetDescendants()) do if d:IsA("Model") and d.Name:sub(1, 7) == "Pickup_" then task.spawn(track, d) end end

local U = require(ReplicatedStorage.Shared.Config).STUDS_PER_METER   -- flottement de 10 cm comme le web
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, s in pairs(spins) do
		local cf = CFrame.new(s.base + Vector3.new(0, math.sin(t * 2 + s.phase) * 0.1 * U, 0)) * CFrame.Angles(0, t * 1.6, 0)
		for p, off in pairs(s.parts) do
			if p.Name == "Core" and s.model:GetAttribute("Pickup") == "shield" then p.CFrame = cf * CFrame.Angles(math.rad(45), 0, math.rad(35.26))
			else p.CFrame = cf * (if p.Name == "Core" then CFrame.identity else off) end
		end
	end
end)

-- ---------- message de ramassage ----------
local gui = Instance.new("ScreenGui"); gui.Name = "PickupToast"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.DisplayOrder = 12
gui.Parent = player:WaitForChild("PlayerGui")
local toast = Instance.new("TextLabel"); toast.AnchorPoint = Vector2.new(0.5, 0); toast.Position = UDim2.new(0.5, 0, 0.62, 0)
toast.Size = UDim2.fromOffset(300, 30); toast.BackgroundTransparency = 1; toast.Font = Enum.Font.GothamBlack; toast.TextSize = 20
toast.TextColor3 = Color3.new(1, 1, 1); toast.TextStrokeTransparency = 0.5; toast.TextTransparency = 1; toast.Text = ""; toast.Parent = gui
local TOAST: { [string]: { any } } = { shield = { "+25 bouclier", Color3.fromRGB(95, 214, 255), "pickup" }, health = { "+35 santé", Color3.fromRGB(255, 120, 130), "heal" },
	ammo = { "Munitions", Color3.fromRGB(255, 215, 94), "pickup" } }
local toastId = 0
local remote = ReplicatedStorage:WaitForChild("PickupToast", 30) :: RemoteEvent?
if remote then
	remote.OnClientEvent:Connect(function(kind: string)
		local d = TOAST[kind]
		if not d then return end
		toastId += 1
		local my = toastId
		toast.Text = d[1]; toast.TextColor3 = d[2]; toast.TextTransparency = 0; toast.Position = UDim2.new(0.5, 0, 0.62, 0)
		TweenService:Create(toast, TweenInfo.new(1.4), { Position = UDim2.new(0.5, 0, 0.6, 0) }):Play()
		Sfx.play(d[3])
		task.delay(1.1, function() if my == toastId then TweenService:Create(toast, TweenInfo.new(0.3), { TextTransparency = 1 }):Play() end end)
	end)
end

-- ---------- étincelles bleues sur un bouclier touché ----------
local function soldiers(): { Model }
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(list, p.Character) end end
	local bots = workspace:FindFirstChild("Bots")
	if bots then for _, b in ipairs(bots:GetChildren()) do if b:IsA("Model") then table.insert(list, b) end end end
	return list
end

local function sparks(at: Vector3, dir: Vector3)
	local a = Instance.new("Attachment"); a.WorldPosition = at; a.Parent = workspace.Terrain
	a.WorldCFrame = CFrame.lookAt(at, at - dir)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Color3.fromRGB(150, 230, 255), Color3.fromRGB(40, 150, 255))
	e.LightEmission = 1; e.LightInfluence = 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	e.Speed = NumberRange.new(8, 18); e.SpreadAngle = Vector2.new(55, 55); e.Lifetime = NumberRange.new(0.15, 0.35)
	e.Acceleration = Vector3.new(0, -25, 0); e.Rate = 0; e.EmissionDirection = Enum.NormalId.Front; e.Parent = a
	e:Emit(10)
	-- éclat de la bulle du bouclier
	local flash = Instance.new("Part"); flash.Shape = Enum.PartType.Ball; flash.Anchored = true; flash.CanCollide = false; flash.CanQuery = false
	flash.CanTouch = false; flash.CastShadow = false; flash.Material = Enum.Material.Neon; flash.Color = Color3.fromRGB(90, 200, 255)
	flash.Transparency = 0.45; flash.Size = Vector3.new(0.6, 0.6, 0.6); flash.Position = at; flash.Parent = workspace
	TweenService:Create(flash, TweenInfo.new(0.18), { Size = Vector3.new(2.2, 2.2, 2.2), Transparency = 1 }):Play()
	Debris:AddItem(flash, 0.2); Debris:AddItem(a, 0.6)
end

tracerRemote.OnClientEvent:Connect(function(origin: Vector3, endPos: Vector3, shooter: Instance?)
	for _, m in ipairs(soldiers()) do
		if m ~= shooter then
			local sh = m:GetAttribute("Shield")
			local root = m:FindFirstChild("HumanoidRootPart") :: BasePart?
			if typeof(sh) == "number" and sh > 0 and root and (root.Position - endPos).Magnitude < 3.5 then
				sparks(endPos, (endPos - origin).Unit)
				return
			end
		end
	end
end)
