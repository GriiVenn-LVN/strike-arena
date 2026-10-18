--!strict
-- StarterPlayerScripts/HalloweenController (LocalScript)
-- Animations du décor d'Halloween posé par HalloweenService (src/8W_halloween.js) :
--   • repères « HwBats » : nuée de chauves-souris qui tournent autour du repère en battant des ailes (hwBats) ;
--   • lumières « HwFlicker » des citrouilles : vacillement de bougie.
-- Tout est local (aucune Part créée ici n'existe sur le serveur).
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local camera = workspace.CurrentCamera
local BAT = Color3.fromRGB(11, 7, 16)

type Bat = { body: BasePart, wl: BasePart, wr: BasePart, r: number, h: number, sp: number, ph: number, fl: number, sz: number }
type Flock = { anchor: BasePart, bats: { Bat }, folder: Folder }
local flocks: { [Instance]: Flock } = {}

local function part(size: Vector3, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Size = size; p.Color = BAT; p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Parent = parent
	return p
end

local function addFlock(anchor: Instance)
	if not anchor:IsA("BasePart") or flocks[anchor] then return end
	local n = anchor:GetAttribute("N")
	local rad = anchor:GetAttribute("Radius")
	local count = if typeof(n) == "number" then n else 14
	local radius = if typeof(rad) == "number" then rad else 60
	local folder = Instance.new("Folder"); folder.Name = "HwBatsLocal"; folder.Parent = workspace
	local rng = Random.new()
	local bats = {}
	for _ = 1, count do
		local sz = rng:NextNumber(0.7, 1.2) * 3.5
		local b: Bat = {
			body = part(Vector3.new(sz * 0.22, sz * 0.22, sz * 0.4), folder),
			wl = part(Vector3.new(sz * 0.55, 0.08, sz * 0.32), folder),
			wr = part(Vector3.new(sz * 0.55, 0.08, sz * 0.32), folder),
			r = radius * rng:NextNumber(0.5, 1.1), h = rng:NextNumber(-2, 3) * 3.5,
			sp = rng:NextNumber(0.35, 0.7) * (if rng:NextNumber() < 0.5 then -1 else 1),
			ph = rng:NextNumber(0, math.pi * 2), fl = rng:NextNumber(14, 20), sz = sz,
		}
		b.body.Shape = Enum.PartType.Ball
		local eye = Instance.new("PointLight"); eye.Color = Color3.fromRGB(255, 48, 48); eye.Range = 2; eye.Brightness = 0.6; eye.Parent = b.body
		table.insert(bats, b)
	end
	flocks[anchor] = { anchor = anchor, bats = bats, folder = folder }
end
local function removeFlock(anchor: Instance)
	local f = flocks[anchor]
	if f then f.folder:Destroy(); flocks[anchor] = nil end
end
CollectionService:GetInstanceAddedSignal("HwBats"):Connect(addFlock)
CollectionService:GetInstanceRemovedSignal("HwBats"):Connect(removeFlock)
for _, a in ipairs(CollectionService:GetTagged("HwBats")) do addFlock(a) end

local flicker: { [Instance]: { l: PointLight, base: number, ph: number } } = {}
local function addLight(l: Instance)
	if l:IsA("PointLight") then flicker[l] = { l = l, base = l.Brightness, ph = math.random() * 6 } end
end
CollectionService:GetInstanceAddedSignal("HwFlicker"):Connect(addLight)
CollectionService:GetInstanceRemovedSignal("HwFlicker"):Connect(function(l: Instance) flicker[l] = nil end)
for _, l in ipairs(CollectionService:GetTagged("HwFlicker")) do addLight(l) end

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	local cam = camera.CFrame.Position
	for anchor, f in pairs(flocks) do
		if not anchor.Parent then removeFlock(anchor)
		else
			local c = f.anchor.Position
			local near = (c - cam).Magnitude < 600
			f.folder.Parent = if near then workspace else nil
			if near then
				for _, b in ipairs(f.bats) do
					local a = b.ph + t * b.sp
					local pos = c + Vector3.new(math.cos(a) * b.r, b.h + math.sin(t * 1.3 + b.ph) * 4, math.sin(a * 1.3) * b.r * 0.8)
					local a2 = a + 0.02
					local ahead = c + Vector3.new(math.cos(a2) * b.r, b.h + math.sin(t * 1.3 + b.ph) * 4, math.sin(a2 * 1.3) * b.r * 0.8)
					local dir = if b.sp > 0 then ahead - pos else pos - ahead
					local cf = CFrame.lookAt(pos, pos + (if dir.Magnitude > 1e-3 then dir else Vector3.new(0, 0, -1)))
					local flap = math.sin(t * b.fl + b.ph) * 0.9
					local half = b.sz * 0.275
					b.body.CFrame = cf
					b.wl.CFrame = cf * CFrame.new(-b.sz * 0.08, 0, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(-half, 0, 0)
					b.wr.CFrame = cf * CFrame.new(b.sz * 0.08, 0, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(half, 0, 0)
				end
			end
		end
	end
	for l, v in pairs(flicker) do
		if not l.Parent then flicker[l] = nil
		else v.l.Brightness = v.base * (0.82 + 0.18 * math.sin(t * 9 + v.ph) * math.sin(t * 3.7 + v.ph)) end
	end
end)
