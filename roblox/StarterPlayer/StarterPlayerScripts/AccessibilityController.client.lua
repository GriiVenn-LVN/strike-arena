--!strict
-- StarterPlayerScripts/AccessibilityController (LocalScript)
-- Daltonisme (ColorCorrection), taille du HUD (UIScale), sous-titres sonores directionnels (tirs entendus),
-- secousses réduites, sensibilité par arme. Réglages stockés dans l'attribut "Access" (JSON) ou profil serveur.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local DEFAULTS = { colorblind = "none", subtitles = false, hudScale = 1, shake = 1, weaponSens = {} :: { [string]: number } }
local settings = table.clone(DEFAULTS)

local cc = Instance.new("ColorCorrectionEffect"); cc.Parent = Lighting
-- Approximation par teinte/saturation (Roblox n'expose pas de matrice 3x3) — suffisant pour différencier rouge/vert/bleu
local CB = {
	none = { Color3.new(1, 1, 1), 0 },
	deut = { Color3.fromRGB(255, 235, 200), 0.1 },    -- deutéranopie : accentue jaune/bleu
	prot = { Color3.fromRGB(255, 225, 215), 0.1 },
	trit = { Color3.fromRGB(235, 245, 255), 0.05 },
}

local gui = Instance.new("ScreenGui"); gui.Name = "AccessHud"; gui.ResetOnSpawn = false; gui.DisplayOrder = 50; gui.Parent = player:WaitForChild("PlayerGui")
local subs = Instance.new("Frame"); subs.BackgroundTransparency = 1; subs.AnchorPoint = Vector2.new(0.5, 1); subs.Position = UDim2.new(0.5, 0, 1, -200); subs.Size = UDim2.fromOffset(360, 100); subs.Parent = gui
local list = Instance.new("UIListLayout"); list.VerticalAlignment = Enum.VerticalAlignment.Bottom; list.HorizontalAlignment = Enum.HorizontalAlignment.Center; list.Padding = UDim.new(0, 3); list.Parent = subs

local function apply()
	local cb = CB[settings.colorblind] or CB.none
	cc.TintColor = cb[1]; cc.Saturation = cb[2]
	for _, g in ipairs((player:FindFirstChild("PlayerGui") :: Instance):GetChildren()) do
		if g:IsA("ScreenGui") and g ~= gui then
			local s = g:FindFirstChild("AccessScale") or Instance.new("UIScale"); s.Name = "AccessScale"; (s :: UIScale).Scale = settings.hudScale; s.Parent = g
		end
	end
end

-- chargement des réglages (envoyés par le serveur dans l'attribut "Access")
local function load()
	local raw = player:GetAttribute("Access")
	if typeof(raw) == "string" then
		local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and typeof(data) == "table" then for k, v in pairs(data) do (settings :: any)[k] = v end end
	end
	apply()
end
player:GetAttributeChangedSignal("Access"):Connect(load)
load()

-- sous-titres sonores : chaque tir ennemi (événement Tracer) devient une ligne « ◀ Tir · 23 m »
local tracer = ReplicatedStorage:WaitForChild("Tracer") :: RemoteEvent
tracer.OnClientEvent:Connect(function(origin: Vector3)
	if not settings.subtitles then return end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end
	local to = origin - root.Position
	local d = to.Magnitude / 3.571
	if d < 1.5 or d > 60 then return end
	local look = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
	local angle = math.deg(math.atan2((look:Cross(to * Vector3.new(1, 0, 1))).Y, look:Dot(to * Vector3.new(1, 0, 1))))
	local arrow = if math.abs(angle) < 30 then "▲" elseif math.abs(angle) > 150 then "▼" elseif angle > 0 then "◀" else "▶"
	local l = Instance.new("TextLabel"); l.AutomaticSize = Enum.AutomaticSize.XY; l.BackgroundColor3 = Color3.new(0, 0, 0); l.BackgroundTransparency = 0.35
	l.Font = Enum.Font.GothamBold; l.TextSize = 14; l.TextColor3 = Color3.new(1, 1, 1); l.Text = string.format(" %s Tir · %d m ", arrow, math.floor(d)); l.Parent = subs
	Instance.new("UICorner", l).CornerRadius = UDim.new(0, 4)
	task.delay(1.4, function() l:Destroy() end)
end)

-- sensibilité par arme : multiplie la sensibilité souris quand l'arme équipée a un réglage
local function currentWeapon(): string?
	local c = player.Character; local tool = c and c:FindFirstChildOfClass("Tool")
	return tool and tool.Name or nil
end
local base = UserInputService.MouseDeltaSensitivity
game:GetService("RunService").RenderStepped:Connect(function()
	local w = currentWeapon()
	UserInputService.MouseDeltaSensitivity = base * ((w and settings.weaponSens[w]) or 1)
end)

-- API pour l'interface de réglages
local setEvent = Instance.new("BindableEvent"); setEvent.Name = "AccessSet"; setEvent.Parent = script
setEvent.Event:Connect(function(key: string, value: any)
	(settings :: any)[key] = value; apply()
	player:SetAttribute("Access", HttpService:JSONEncode(settings))
end)
