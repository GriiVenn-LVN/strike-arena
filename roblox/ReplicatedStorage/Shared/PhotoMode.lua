--!strict
-- ReplicatedStorage/Shared/PhotoMode (ModuleScript, côté client)
-- Mode photo du jeu web (src/8Z_photo.js) : caméra libre, interface masquée, ton soldat visible, 7 filtres
-- (Aucun, Noir et blanc, Sépia, Cinéma + bandes noires, Éclatant, Nocturne, Rétro + vignette), zoom et inclinaison,
-- capture (CaptureService : l'image va dans les captures Roblox du joueur).
-- Commandes : ZQSD / WASD ou flèches pour bouger, glisser la souris pour regarder, Espace / C pour monter / descendre,
-- Maj = plus vite, molette = zoom, Entrée = capturer, H = masquer les commandes, Échap = retour.
-- Sur Roblox la partie ne se fige pas (multijoueur) : en match, la caméra reste à 8 m de ton soldat au plus et ne
-- traverse pas les murs (sinon ce serait un moyen d'espionner l'adversaire).
-- API : PhotoMode.enter(), PhotoMode.exit(), PhotoMode.toggle(), PhotoMode.active(). Touche provisoire : F4
-- (PhotoController) en attendant le bouton du menu pause.
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local S = require(ReplicatedStorage.Shared.ClientState)

local PhotoMode = {}

local player = Players.LocalPlayer
local U = 3.571   -- studs par mètre (Config.STUDS_PER_METER)
local MATCH_RADIUS = 8 * U

local FILTERS: { { n: string, cc: { [string]: any }?, bars: boolean?, vig: boolean? } } = {
	{ n = "Aucun" },
	{ n = "Noir et blanc", cc = { Saturation = -1, Contrast = 0.25, Brightness = 0.05 } },
	{ n = "Sépia", cc = { Saturation = -0.75, Contrast = 0.1, Brightness = 0.05, TintColor = Color3.fromRGB(255, 226, 184) } },
	{ n = "Cinéma", cc = { Saturation = -0.18, Contrast = 0.18, Brightness = -0.05 }, bars = true },
	{ n = "Éclatant", cc = { Saturation = 0.7, Contrast = 0.12 } },
	{ n = "Nocturne", cc = { Saturation = -0.45, Contrast = 0.3, Brightness = -0.2, TintColor = Color3.fromRGB(150, 190, 255) } },
	{ n = "Rétro", cc = { Saturation = 0.4, Contrast = -0.08, Brightness = 0.08, TintColor = Color3.fromRGB(255, 226, 196) }, vig = true },
}
PhotoMode.FILTERS = FILTERS

type State = { on: boolean, pos: Vector3, yaw: number, pit: number, roll: number, fov: number, filter: number, drag: boolean, bare: boolean,
	keys: { [Enum.KeyCode]: boolean }, hidden: { ScreenGui }, prevType: Enum.CameraType, prevSubject: Instance?, prevFov: number }
local PH: State = { on = false, pos = Vector3.zero, yaw = 0, pit = 0, roll = 0, fov = 60, filter = 1, drag = false, bare = false, keys = {}, hidden = {},
	prevType = Enum.CameraType.Custom, prevSubject = nil, prevFov = 70 }

local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local o = Instance.new(class)
	if o:IsA("GuiObject") then (o :: any).BorderSizePixel = 0 end
	for k, v in pairs(props) do (o :: any)[k] = v end
	if parent then o.Parent = parent end
	return o
end

-- ---------- interface ----------
local gui: ScreenGui? = nil
local ui: { [string]: any } = {}
local cc: ColorCorrectionEffect? = nil
local function build(): ScreenGui
	if gui and gui.Parent then return gui end
	local g = make("ScreenGui", { Name = "PhotoMode", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 90, Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
	ui.top = make("Frame", { Size = UDim2.new(1, 0, 0.11, 0), BackgroundColor3 = Color3.new(), Visible = false }, g)
	ui.bot = make("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0.11, 0), BackgroundColor3 = Color3.new(), Visible = false }, g)
	ui.vig = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, g)
	make("UIStroke", { Color = Color3.fromRGB(20, 8, 0), Thickness = 140, Transparency = 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, ui.vig)
	ui.flash = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ZIndex = 5 }, g)
	ui.sign = make("TextLabel", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -20), Size = UDim2.fromOffset(400, 22), BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack, TextSize = 18, TextColor3 = Color3.new(1, 1, 1), TextTransparency = 0.25, TextStrokeTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Right, Text = "STRIKE ARENA", ZIndex = 3 }, g)
	local ctl = make("Frame", { Name = "Controls", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 4 }, g)
	ui.ctl = ctl
	make("TextButton", { Size = UDim2.fromOffset(1, 1), BackgroundTransparency = 1, Text = "", Modal = true }, ctl)   -- libère la souris
	make("TextLabel", { Position = UDim2.fromOffset(18, 14), Size = UDim2.fromOffset(300, 24), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 18,
		TextColor3 = Color3.fromRGB(255, 210, 58), TextXAlignment = Enum.TextXAlignment.Left, Text = "📷 MODE PHOTO", ZIndex = 4 }, ctl)
	make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 44), Size = UDim2.new(1, -40, 0, 18), BackgroundTransparency = 1, Font = Enum.Font.Gotham,
		TextSize = 12, TextColor3 = Color3.fromRGB(200, 210, 230), TextStrokeTransparency = 0.6, ZIndex = 4,
		Text = "ZQSD / flèches : bouger · Glisser : regarder · Espace / C : monter / descendre · Maj : vite · Molette : zoom · Entrée : capturer · H : masquer · Échap : retour" }, ctl)
	local bar = make("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(820, 84), BackgroundColor3 = Color3.fromRGB(15, 23, 38),
		BackgroundTransparency = 0.15, ZIndex = 4 }, ctl)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, bar)
	make("UISizeConstraint", { MaxSize = Vector2.new(820, 84) }, bar)
	local fl = make("Frame", { Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 28), BackgroundTransparency = 1, ZIndex = 4 }, bar)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5) }, fl)
	ui.fbtn = {}
	for i, f in ipairs(FILTERS) do
		local b = make("TextButton", { Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.fromRGB(24, 35, 56), Font = Enum.Font.GothamBold,
			TextSize = 12, TextColor3 = Color3.new(1, 1, 1), Text = f.n, ZIndex = 4 }, fl)
		make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, b)
		make("UICorner", { CornerRadius = UDim.new(0, 5) }, b)
		b.Activated:Connect(function() PhotoMode.setFilter(i) end)
		ui.fbtn[i] = b
	end
	local row = make("Frame", { Position = UDim2.fromOffset(10, 44), Size = UDim2.new(1, -20, 0, 30), BackgroundTransparency = 1, ZIndex = 4 }, bar)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center }, row)
	local function stepper(label: string, get: () -> string, minus: () -> (), plus: () -> ())
		local f = make("Frame", { Size = UDim2.fromOffset(170, 28), BackgroundTransparency = 1, ZIndex = 4 }, row)
		local l = make("TextLabel", { Size = UDim2.fromOffset(110, 28), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.fromRGB(141, 160, 189),
			TextXAlignment = Enum.TextXAlignment.Left, Text = label, ZIndex = 4 }, f)
		local function upd() l.Text = label .. " " .. get() end
		for j, s in ipairs({ "−", "+" }) do
			local b = make("TextButton", { Position = UDim2.fromOffset(110 + (j - 1) * 30, 1), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = Color3.fromRGB(24, 35, 56),
				Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Color3.new(1, 1, 1), Text = s, ZIndex = 4 }, f)
			make("UICorner", { CornerRadius = UDim.new(0, 5) }, b)
			b.Activated:Connect(function() if j == 1 then minus() else plus() end; upd() end)
		end
		upd()
		return upd
	end
	ui.updFov = stepper("ZOOM", function() return tostring(math.floor(PH.fov)) end, function() PH.fov = math.clamp(PH.fov + 5, 15, 100) end, function() PH.fov = math.clamp(PH.fov - 5, 15, 100) end)
	ui.updRoll = stepper("INCLINAISON", function() return tostring(math.floor(math.deg(PH.roll) + 0.5)) .. "°" end,
		function() PH.roll = math.clamp(PH.roll - math.rad(5), math.rad(-30), math.rad(30)) end, function() PH.roll = math.clamp(PH.roll + math.rad(5), math.rad(-30), math.rad(30)) end)
	local function button(txt: string, gold: boolean, cb: () -> ())
		local b = make("TextButton", { Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = if gold then Color3.fromRGB(255, 210, 58) else Color3.fromRGB(24, 35, 56),
			Font = Enum.Font.GothamBlack, TextSize = 12, TextColor3 = if gold then Color3.fromRGB(15, 23, 38) else Color3.new(1, 1, 1), Text = txt, ZIndex = 4 }, row)
		make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, b)
		make("UICorner", { CornerRadius = UDim.new(0, 5) }, b)
		b.Activated:Connect(cb)
	end
	button("MASQUER", false, function() PhotoMode.toggleBare() end)
	button("📸 CAPTURER", true, function() PhotoMode.capture() end)
	button("RETOUR", false, function() PhotoMode.exit() end)
	gui = g
	return g
end

function PhotoMode.setFilter(i: number)
	PH.filter = math.clamp(i, 1, #FILTERS)
	local f = FILTERS[PH.filter]
	if cc then cc:Destroy(); cc = nil end
	if f.cc and PH.on then
		local e = Instance.new("ColorCorrectionEffect"); e.Name = "PhotoFilter"
		for k, v in pairs(f.cc) do (e :: any)[k] = v end
		e.Parent = Lighting
		cc = e
	end
	ui.top.Visible = f.bars == true; ui.bot.Visible = f.bars == true; ui.vig.Visible = f.vig == true
	ui.sign.Position = if f.bars then UDim2.new(1, -24, 0.89, -14) else UDim2.new(1, -24, 1, -20)
	for j, b in pairs(ui.fbtn) do
		b.BackgroundColor3 = if j == PH.filter then Color3.fromRGB(255, 210, 58) else Color3.fromRGB(24, 35, 56)
		b.TextColor3 = if j == PH.filter then Color3.fromRGB(15, 23, 38) else Color3.new(1, 1, 1)
	end
end
function PhotoMode.toggleBare()
	PH.bare = not PH.bare
	if ui.ctl then ui.ctl.Visible = not PH.bare end
end
function PhotoMode.active(): boolean return PH.on end

-- capture : les commandes disparaissent le temps de la photo, puis Roblox propose d'enregistrer l'image
function PhotoMode.capture()
	if not PH.on then return end
	local wasBare = PH.bare
	if ui.ctl then ui.ctl.Visible = false end
	task.wait()
	local ok = pcall(function()
		local CaptureService = game:GetService("CaptureService") :: any
		CaptureService:CaptureScreenshot(function(contentId: any)
			pcall(function() CaptureService:PromptSaveCapturesToGallery({ contentId }, function() end) end)
		end)
	end)
	task.wait(0.1)
	if ui.ctl and PH.on then ui.ctl.Visible = not wasBare end
	ui.flash.BackgroundTransparency = 0.15
	TweenService:Create(ui.flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	if not ok then warn("[PhotoMode] capture indisponible ici") end
end

-- ---------- entrées : on prend les touches de déplacement, de tir et de saut au jeu ----------
local MOVE_KEYS = { Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Z, Enum.KeyCode.Q, Enum.KeyCode.Up, Enum.KeyCode.Down,
	Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.Space, Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift,
	Enum.KeyCode.Return, Enum.KeyCode.KeypadEnter, Enum.KeyCode.Escape, Enum.KeyCode.H, Enum.KeyCode.R, Enum.KeyCode.E, Enum.KeyCode.G, Enum.KeyCode.F }
local function sink(_: string, st: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
	local k = input.KeyCode
	if st == Enum.UserInputState.Begin then
		PH.keys[k] = true
		if k == Enum.KeyCode.Escape then task.defer(PhotoMode.exit)
		elseif k == Enum.KeyCode.Return or k == Enum.KeyCode.KeypadEnter then task.spawn(PhotoMode.capture)
		elseif k == Enum.KeyCode.H then PhotoMode.toggleBare() end
	elseif st == Enum.UserInputState.End or st == Enum.UserInputState.Cancel then
		PH.keys[k] = nil
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		PH.drag = st == Enum.UserInputState.Begin
	elseif input.UserInputType == Enum.UserInputType.MouseWheel then
		PH.fov = math.clamp(PH.fov + (if input.Position.Z > 0 then -3 else 3), 15, 100)
		if ui.updFov then ui.updFov() end
	end
	return Enum.ContextActionResult.Sink
end

local conns: { RBXScriptConnection } = {}
local function rootOf(): BasePart?
	local ch = player.Character
	return ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
end
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function step(dt: number)
	local camera = workspace.CurrentCamera
	local k = PH.keys
	local sp = (if k[Enum.KeyCode.LeftShift] or k[Enum.KeyCode.RightShift] then 14 else 4.5) * U * math.min(dt, 0.05)
	local f, s, u = 0, 0, 0
	if k[Enum.KeyCode.W] or k[Enum.KeyCode.Z] or k[Enum.KeyCode.Up] then f += 1 end
	if k[Enum.KeyCode.S] or k[Enum.KeyCode.Down] then f -= 1 end
	if k[Enum.KeyCode.D] or k[Enum.KeyCode.Right] then s += 1 end
	if k[Enum.KeyCode.A] or k[Enum.KeyCode.Q] or k[Enum.KeyCode.Left] then s -= 1 end
	if k[Enum.KeyCode.Space] then u += 1 end
	if k[Enum.KeyCode.C] or k[Enum.KeyCode.LeftControl] then u -= 1 end
	local rot = CFrame.fromEulerAnglesYXZ(PH.pit, PH.yaw, 0)
	local want = PH.pos + (rot.LookVector * f + rot.RightVector * s + Vector3.new(0, u, 0)) * sp
	-- en match : pas plus loin que MATCH_RADIUS de son soldat, et jamais à travers un mur
	local root = rootOf()
	if root and player:GetAttribute("Zone") == "match" then
		local head = root.Position + Vector3.new(0, 2, 0)
		local off = want - head
		if off.Magnitude > MATCH_RADIUS then want = head + off.Unit * MATCH_RADIUS end
		local ex: { Instance } = { camera }
		if player.Character then table.insert(ex, player.Character) end
		rayParams.FilterDescendantsInstances = ex
		local hit = workspace:Raycast(head, want - head, rayParams)
		if hit then want = hit.Position - (want - head).Unit * 0.6 end
	end
	PH.pos = want
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.new(PH.pos) * CFrame.fromEulerAnglesYXZ(PH.pit, PH.yaw, PH.roll)
	camera.FieldOfView = PH.fov
	-- ton soldat est visible sur les photos
	local ch = player.Character
	if ch then for _, d in ipairs(ch:GetDescendants()) do if d:IsA("BasePart") then d.LocalTransparencyModifier = 0 end end end
end

function PhotoMode.enter()
	if PH.on then return end
	-- kill-cam, arrivée, spectateur ou soldat mort : la caméra appartient déjà à une autre scène
	-- (on en garderait le type Scriptable au retour, caméra bloquée)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if S.kc ~= nil or not hum or hum.Health <= 0 then return end
	local camera = workspace.CurrentCamera
	if camera.CameraType == Enum.CameraType.Scriptable then return end
	local g = build()
	PH.on = true; PH.keys = {}; PH.drag = false; PH.roll = 0; PH.bare = false
	PH.prevType = camera.CameraType; PH.prevSubject = camera.CameraSubject; PH.prevFov = camera.FieldOfView
	PH.pos = camera.CFrame.Position
	local rx, ry = camera.CFrame:ToEulerAnglesYXZ()
	PH.pit, PH.yaw = rx, ry
	PH.fov = math.clamp(math.floor(camera.FieldOfView + 0.5), 15, 100)
	-- on cache les autres interfaces
	PH.hidden = {}
	for _, sg in ipairs((player:WaitForChild("PlayerGui")):GetChildren()) do
		if sg:IsA("ScreenGui") and sg ~= g and sg.Enabled then sg.Enabled = false; table.insert(PH.hidden, sg) end
	end
	g.Enabled = true
	ui.ctl.Visible = true
	ui.sign.Text = "STRIKE ARENA" .. (function()
		local m = player:GetAttribute("MatchMap")
		return if typeof(m) == "string" and m ~= "" then " · " .. string.upper(m) else ""
	end)()
	PhotoMode.setFilter(PH.filter)
	ui.updFov(); ui.updRoll()
	player:SetAttribute("UiOpen", true)
	ContextActionService:BindActionAtPriority("PhotoModeInput", sink, false, Enum.ContextActionPriority.High.Value + 50,
		Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2, Enum.UserInputType.MouseWheel, table.unpack(MOVE_KEYS))
	table.insert(conns, UserInputService.InputChanged:Connect(function(input: InputObject)
		if PH.drag and input.UserInputType == Enum.UserInputType.MouseMovement then
			local sc = 0.0042 * (PH.fov / 60)
			PH.yaw -= input.Delta.X * sc
			PH.pit = math.clamp(PH.pit - input.Delta.Y * sc, -1.5, 1.5)
		end
	end))
	RunService:BindToRenderStep("PhotoMode", Enum.RenderPriority.Last.Value, step)
	table.insert(conns, player.CharacterRemoving:Connect(function() task.defer(PhotoMode.exit) end))
	-- mort : on sort tout de suite, avant que la kill-cam ne prenne la caméra
	table.insert(conns, hum.Died:Connect(function() task.defer(PhotoMode.exit) end))
end

function PhotoMode.exit()
	if not PH.on then return end
	PH.on = false
	local camera = workspace.CurrentCamera
	pcall(function() RunService:UnbindFromRenderStep("PhotoMode") end)
	ContextActionService:UnbindAction("PhotoModeInput")
	for _, c in ipairs(conns) do c:Disconnect() end
	conns = {}
	if cc then cc:Destroy(); cc = nil end
	for _, sg in ipairs(PH.hidden) do if sg.Parent then sg.Enabled = true end end
	PH.hidden = {}
	if gui then gui.Enabled = false end
	camera.CameraType = PH.prevType
	if PH.prevSubject and PH.prevSubject.Parent then camera.CameraSubject = PH.prevSubject end
	camera.FieldOfView = PH.prevFov
	player:SetAttribute("UiOpen", nil)
end

function PhotoMode.toggle() if PH.on then PhotoMode.exit() else PhotoMode.enter() end end

return PhotoMode
