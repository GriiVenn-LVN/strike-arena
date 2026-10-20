--!strict
-- ServerScriptService/SprayService (ModuleScript, requis par Main)
-- Sprays sur les murs (src/64_extras.js doSpray) : touche J (SprayController). Le serveur vérifie tout et pose le spray
-- pour tout le monde : mur à 4,5 m au plus devant la tête, pas au sol ni au plafond, 4 s entre deux sprays,
-- 12 sprays par joueur au plus (le plus ancien disparaît), pas pendant le temps d'achat du mode Bombe.
-- Remotes : Spray (RemoteEvent, client -> serveur : direction du regard), SetSpray (RemoteFunction : choisir son spray
-- parmi ConfigExtra.SPRAYS ; débloqués par niveau comme sur le web : 1, 1, 2, 2, 3, 3, 4, 4).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local X = require(ReplicatedStorage.Shared.ConfigExtra)
local DataService = require(script.Parent.DataService)
local RewardService = require(script.Parent.RewardService)
local ProgressService = require(script.Parent.ProgressService)
local MatchService = require(script.Parent.MatchService)

local SprayService = {}

local U = Config.STUDS_PER_METER
local RANGE = 4.5 * U
local SIZE = 1.1 * U
local COOLDOWN = 4
local MAX = 12

-- dessin de chaque spray (couleur du web, symbole)
SprayService.LOOK = {
	smile = { n = "Sourire", g = "☺", c = Color3.fromHex("#ffd23a") },
	heart = { n = "Cœur", g = "♥", c = Color3.fromHex("#ff4d6d") },
	skull = { n = "Crâne", g = "☠", c = Color3.fromHex("#f2f2f2") },
	bolt = { n = "Éclair", g = "⚡", c = Color3.fromHex("#fff04a") },
	flame = { n = "Flamme", g = "🔥", c = Color3.fromHex("#ff7a2a") },
	crown = { n = "Couronne", g = "♛", c = Color3.fromHex("#ffc933") },
	target = { n = "Cible", g = "◎", c = Color3.fromHex("#ff4655") },
	ghost = { n = "Fantôme", g = "👻", c = Color3.fromHex("#e8f1ff") },
}
function SprayService.levelOf(id: string): number
	local i = table.find(X.SPRAYS, id)
	return if i then 1 + (i - 1) // 2 else math.huge
end

local sprayEv = Instance.new("RemoteEvent"); sprayEv.Name = "Spray"; sprayEv.Parent = ReplicatedStorage
local setSpray = Instance.new("RemoteFunction"); setSpray.Name = "SetSpray"; setSpray.Parent = ReplicatedStorage
local toast = Instance.new("RemoteEvent"); toast.Name = "SprayToast"; toast.Parent = ReplicatedStorage

local last: { [Player]: number } = {}
local placed: { [Player]: { Instance } } = {}

local function chosen(p: Player): string
	local profile: any = DataService.get(p)
	if not profile then return "smile" end
	ProgressService.ensure(profile)
	local id = profile.cosmetics.spray
	if typeof(id) ~= "string" or not SprayService.LOOK[id] then return "smile" end
	if RewardService.levelInfo(profile) < SprayService.levelOf(id) then return "smile" end
	return id
end

setSpray.OnServerInvoke = function(p: Player, id: any): any
	if typeof(id) ~= "string" or not SprayService.LOOK[id] then return false end
	local profile: any = DataService.get(p)
	if not profile then return false end
	ProgressService.ensure(profile)
	if RewardService.levelInfo(profile) < SprayService.levelOf(id) then return false end
	profile.cosmetics.spray = id
	return true
end

local function build(id: string, pos: Vector3, normal: Vector3, parent: Instance): Part
	local look = SprayService.LOOK[id]
	local p = Instance.new("Part")
	p.Name = "Spray"; p.Size = Vector3.new(SIZE, SIZE, 0.05); p.Transparency = 1
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	local up = if math.abs(normal.Y) > 0.95 then Vector3.new(0, 0, 1) else Vector3.new(0, 1, 0)
	p.CFrame = CFrame.lookAt(pos + normal * 0.04, pos + normal * 2, up)
	local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Front; sg.CanvasSize = Vector2.new(128, 128); sg.LightInfluence = 0.6
	sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize; sg.Parent = p
	local t = Instance.new("TextLabel"); t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1; t.Text = look.g; t.TextScaled = true
	t.Font = Enum.Font.GothamBlack; t.TextColor3 = look.c; t.TextTransparency = 0.08; t.Parent = sg
	p:SetAttribute("SprayId", id)
	p.Parent = parent
	return p
end

sprayEv.OnServerEvent:Connect(function(p: Player, dir: any)
	if typeof(dir) ~= "Vector3" or not (dir.Magnitude >= 0.5 and dir.Magnitude <= 1.5) then return end   -- refuse aussi NaN
	dir = dir.Unit
	local now = os.clock()
	if last[p] and now - last[p] < COOLDOWN then return end
	local ch = p.Character
	local head = ch and ch:FindFirstChild("Head") :: BasePart?
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if not head or not hum or hum.Health <= 0 then return end
	local m = MatchService.matchOf(p)
	if m and m.mode == "bomb" and m.data and m.data.phase == "freeze" then return end
	if math.abs(dir.Y) > 0.8 then toast:FireClient(p, "Vise un mur"); return end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex: { Instance } = { ch :: Model }
	local bots = workspace:FindFirstChild("Bots"); if bots then table.insert(ex, bots) end
	for _, q in ipairs(Players:GetPlayers()) do if q.Character then table.insert(ex, q.Character) end end
	params.FilterDescendantsInstances = ex
	local hit = workspace:Raycast(head.Position, dir * RANGE, params)
	if not hit or not hit.Instance:IsA("BasePart") or not hit.Instance.Anchored then toast:FireClient(p, "Trop loin d'une surface"); return end
	if math.abs(hit.Normal.Y) > 0.6 then toast:FireClient(p, "Vise un mur"); return end
	last[p] = now
	local parent: Instance = if m and m.map then m.map.folder else (workspace:FindFirstChild("Lobby") or workspace)
	local s = build(chosen(p), hit.Position, hit.Normal, parent)
	local list = placed[p] or {}; placed[p] = list
	table.insert(list, s)
	while #list > MAX do local old = table.remove(list, 1); if old then old:Destroy() end end
	sprayEv:FireAllClients(p, hit.Position)   -- son du spray chez tout le monde
end)

Players.PlayerRemoving:Connect(function(p: Player)
	last[p] = nil
	for _, s in ipairs(placed[p] or {}) do s:Destroy() end
	placed[p] = nil
end)

return SprayService
