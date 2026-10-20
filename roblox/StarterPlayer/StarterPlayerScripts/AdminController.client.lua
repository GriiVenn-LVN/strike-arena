--!strict
-- StarterPlayerScripts/AdminController (LocalScript)
-- Panneau admin (src/8M_admin.js) : touche Inser (F2 en secours). Ne s'ouvre QUE pour le propriétaire du jeu
-- (attribut AdminEligible posé par le serveur) et demande d'abord le code. Tout passe par AdminRequest : le serveur
-- revérifie les droits à chaque appel, ce script n'est qu'un affichage.
-- Onglets : Joueurs, Partie, Donner, Triche, Journal.
-- Vision à travers les murs et visée auto : ici (côté client), seulement quand le serveur répond que c'est permis
-- (visionWhy / aimWhy vides : pas de joueur humain en face, comme sur le web).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local S = require(ReplicatedStorage.Shared.ClientState)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local PANEL = Color3.fromRGB(15, 23, 38)
local PANEL2 = Color3.fromRGB(24, 35, 56)
local DIM = Color3.fromRGB(141, 160, 189)
local GOLD = Color3.fromRGB(255, 210, 58)
local RED = Color3.fromRGB(255, 107, 107)
local GREEN = Color3.fromRGB(125, 255, 159)
local BLUE = Color3.fromRGB(159, 227, 255)

local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local o = Instance.new(class)
	if o:IsA("GuiObject") then (o :: any).BorderSizePixel = 0 end
	for k, v in pairs(props) do (o :: any)[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function corner(o: Instance, r: number?) make("UICorner", { CornerRadius = UDim.new(0, r or 6) }, o) end

local request: RemoteFunction? = nil
local function ask(action: string, a: any?, b: any?): any
	request = request or ReplicatedStorage:FindFirstChild("AdminRequest") :: RemoteFunction?
	if not request then return nil end
	local ok, res = pcall(function() return (request :: RemoteFunction):InvokeServer(action, a, b) end)
	return if ok then res else nil
end

-- ---------- fenêtre ----------
local gui = make("ScreenGui", { Name = "AdminPanel", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 60, Enabled = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
local win = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(600, 440),
	BackgroundColor3 = PANEL, BackgroundTransparency = 0.04 }, gui)
corner(win, 10)
make("UIStroke", { Color = GOLD, Transparency = 0.6, Thickness = 1 }, win)
make("UISizeConstraint", { MaxSize = Vector2.new(600, 440) }, win)
make("TextButton", { Size = UDim2.fromOffset(1, 1), BackgroundTransparency = 1, Text = "", Modal = true }, win)   -- libère la souris
make("TextLabel", { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -60, 0, 24), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 17,
	TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, Text = "PANNEAU ADMIN" }, win)
local closeBtn = make("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(28, 24), BackgroundColor3 = PANEL2,
	Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.new(1, 1, 1), Text = "✕" }, win)
corner(closeBtn)
require(ReplicatedStorage.Shared.Icons).closeButton(closeBtn, 11)   -- la croix U+2715 donne un carré vide
local tabBar = make("Frame", { Position = UDim2.fromOffset(10, 38), Size = UDim2.new(1, -20, 0, 28), BackgroundTransparency = 1 }, win)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }, tabBar)
local body = make("ScrollingFrame", { Position = UDim2.fromOffset(10, 72), Size = UDim2.new(1, -20, 1, -102), BackgroundTransparency = 1, ScrollBarThickness = 5,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, win)
local status = make("TextLabel", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -6), Size = UDim2.new(1, -28, 0, 20), BackgroundTransparency = 1,
	Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextTruncate = Enum.TextTruncate.AtEnd }, win)

local function say(txt: string, col: Color3?) status.Text = txt; status.TextColor3 = col or DIM end

local order = 0
local function clear()
	for _, c in ipairs(body:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
	order = 0
	if not body:FindFirstChildOfClass("UIListLayout") then make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, body) end
end
local function nextOrder(): number order += 1; return order end
local function title(txt: string)
	make("TextLabel", { Size = UDim2.new(1, -8, 0, 20), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 13, TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Left, Text = string.upper(txt), LayoutOrder = nextOrder() }, body)
end
local function note(txt: string, col: Color3?)
	make("TextLabel", { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 13,
		TextColor3 = col or DIM, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Text = txt, LayoutOrder = nextOrder() }, body)
end
local function row(): Frame
	local f = make("Frame", { Size = UDim2.new(1, -8, 0, 28), BackgroundTransparency = 1, LayoutOrder = nextOrder() }, body)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), VerticalAlignment = Enum.VerticalAlignment.Center }, f)
	return f
end
local function btn(parent: Instance, txt: string, col: Color3?, cb: () -> ()): TextButton
	local b = make("TextButton", { Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = PANEL2, Font = Enum.Font.GothamBold,
		TextSize = 12, TextColor3 = col or Color3.new(1, 1, 1), Text = txt, AutoButtonColor = true }, parent)
	make("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }, b)
	corner(b, 5)
	b.Activated:Connect(cb)
	return b
end
local function cell(parent: Instance, txt: string, w: number, col: Color3?)
	make("TextLabel", { Size = UDim2.fromOffset(w, 26), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = col or Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = txt }, parent)
end

-- ---------- état ----------
local state: any = nil
local tab = "Joueurs"
local cheats = { vision = false, aim = false, aimMode = "ads", aimStr = "strong" }
local AIM_MODES = { ads = "en visant", fire = "en tirant", always = "toujours" }
local AIM_STR = { soft = 0.08, strong = 0.25, locked = 1 }
local AIM_STR_N = { soft = "douce", strong = "forte", locked = "verrouillée" }
local render: () -> () = function() end

local function refresh()
	local s = ask("state", tab == "Journal")
	if s then state = s end
end
local function act(action: string, a: any?, b: any?)
	local r = ask(action, a, b)
	if r == nil then say("Refusé", RED)
	elseif r == false then say("Impossible", RED)
	elseif typeof(r) == "string" then say(r, GREEN)
	else say("OK", GREEN) end
	refresh(); render()
end

-- ---------- onglets ----------
local TABS = { "Joueurs", "Partie", "Donner", "Triche", "Journal" }
local tabBtns: { [string]: TextButton } = {}

local function renderLogin()
	clear()
	title("Code administrateur")
	note("Tape le code défini dans ServerScriptService/AdminConfig.")
	local r = row()
	local box = make("TextBox", { Size = UDim2.fromOffset(260, 26), BackgroundColor3 = PANEL2, Font = Enum.Font.Code, TextSize = 14, TextColor3 = Color3.new(1, 1, 1),
		PlaceholderText = "XXXX-XXXX-XXXX-XXXX", Text = "", ClearTextOnFocus = false }, r)
	corner(box, 5)
	local function go()
		local res = ask("unlock", box.Text)
		if res and res.ok then say("Accès ouvert", GREEN); refresh(); render()
		else say(if res and res.err then res.err else "Refusé", RED) end
	end
	btn(r, "Valider", GOLD, go)
	box.FocusLost:Connect(function(enter: boolean) if enter then go() end end)
	task.defer(function() box:CaptureFocus() end)
end

local function renderPlayers()
	local g = state.game
	if g then
		local r = row()
		if g.team then
			for _, t in ipairs(g.teams) do btn(r, "+ Bot " .. t, nil, function() act("addbot", t) end) end
		else
			btn(r, "+ Bot", nil, function() act("addbot") end)
		end
		btn(r, if g.botsFrozen then "Libérer les bots" else "Figer les bots", BLUE, function() act("freeze") end)
	end
	title(if g then "Combattants de ta partie" else "Joueurs du serveur")
	for _, p in ipairs(state.players) do
		local r = row()
		local col = if p.kind == "me" then GOLD elseif p.kind == "bot" then DIM else Color3.new(1, 1, 1)
		cell(r, p.name .. (if p.kind == "bot" then " (bot)" else ""), 130, col)
		cell(r, if p.zone then tostring(p.zone) else tostring(p.team), 60, DIM)
		cell(r, p.k .. "/" .. p.d .. "  " .. (if p.alive then p.hp .. "pv" else "mort") .. (if p.ping then "  " .. p.ping .. "ms" else ""), 120, DIM)
		if g then
			if p.alive then
				btn(r, "Tuer", RED, function() act("kill", p.key) end)
				btn(r, "Soigner", GREEN, function() act("heal", p.key) end)
			elseif p.kind ~= "bot" then
				btn(r, "Réapparaître", GREEN, function() act("revive", p.key) end)
			end
			if g.team then btn(r, "Équipe", nil, function() act("team", p.key) end) end
			if p.kind ~= "me" then btn(r, if p.frozen then "Dégeler" else "Geler", BLUE, function() act("freeze1", p.key) end) end
			if p.kind == "bot" then btn(r, "Retirer", RED, function() act("rmbot", p.key) end) end
		end
		if p.kind == "player" then
			local r2 = if g then row() else r
			if g then cell(r2, "", 130) end
			btn(r2, if p.muted then "Rendre la parole" else "Muet", nil, function() act("mute", p.userId) end)
			btn(r2, "Expulser", RED, function() act("kick", p.userId) end)
			btn(r2, "Bannir", RED, function() act("ban", p.userId) end)
		end
	end
	if #state.banned > 0 then
		title("Bannis (jusqu'à la fermeture du serveur)")
		for _, b in ipairs(state.banned) do
			local r = row()
			cell(r, b.name, 200)
			btn(r, "Débannir", GREEN, function() act("unban", b.userId) end)
		end
	end
end

local function renderGame()
	local g = state.game
	if not g then note("Lance une partie pour utiliser ces commandes."); return end
	title(g.mode .. " · " .. tostring(g.map))
	local sc = {}
	if g.team then for _, t in ipairs(g.teams) do table.insert(sc, t .. " " .. tostring(g.score[t] or 0)) end end
	note("État : " .. tostring(g.state) .. (if g.round then " · manche " .. tostring(g.round) else "") .. (if g.phase then " (" .. tostring(g.phase) .. ")" else "")
		.. (if #sc > 0 then " · " .. table.concat(sc, " – ") else "") .. " · limite " .. tostring(g.limit)
		.. (if g.timeLeft >= 0 then string.format(" · %d:%02d restantes", g.timeLeft // 60, g.timeLeft % 60) else "")
		.. " · " .. g.humans .. " humain" .. (if g.humans > 1 then "s" else ""))
	local r = row()
	btn(r, "Terminer la partie", RED, function() act("endmatch") end)
	btn(r, "+1 minute", nil, function() act("time") end)
	title("Annonce à tout le serveur")
	local r2 = row()
	local box = make("TextBox", { Size = UDim2.fromOffset(360, 26), BackgroundColor3 = PANEL2, Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = Color3.new(1, 1, 1),
		PlaceholderText = "Message (90 caractères max)", Text = "", ClearTextOnFocus = false }, r2)
	corner(box, 5)
	btn(r2, "Envoyer", GOLD, function() if box.Text ~= "" then act("announce", box.Text); box.Text = "" end end)
end

local function renderGive()
	local pr = state.profile
	if pr then note("Ton profil : niveau " .. tostring(pr.level) .. " · " .. tostring(pr.coins) .. " pièces · " .. tostring(pr.boxes) .. " caisses") end
	title("Débloquer")
	local r = row()
	btn(r, "Tout débloquer", GOLD, function() act("giveall") end)
	btn(r, "+5 caisses de chaque", nil, function() act("boxes") end)
	title("Pièces")
	local r2 = row()
	for _, n in ipairs({ 1000, 5000, 25000 }) do btn(r2, "+" .. n, nil, function() act("coins", n) end) end
	title("Niveaux")
	local r3 = row()
	for _, n in ipairs({ 1, 5, 10 }) do btn(r3, "+" .. n, nil, function() act("lvl", n) end) end
end

local function onOff(b: boolean): string return if b then "ACTIVÉ" else "coupé" end
local spectating: Model? = nil
local function enemyModels(): { Model }
	local list = {}
	local mid = player:GetAttribute("MatchId")
	local myTeam = player:GetAttribute("Team")
	if mid == nil then return list end
	for _, q in ipairs(Players:GetPlayers()) do
		if q ~= player and q:GetAttribute("MatchId") == mid and (q:GetAttribute("Team") ~= myTeam or myTeam == nil) and q.Character then table.insert(list, q.Character) end
	end
	local bots = workspace:FindFirstChild("Bots")
	if bots then
		for _, b in ipairs(bots:GetChildren()) do
			if b:IsA("Model") and b:GetAttribute("MatchId") == mid and b:GetAttribute("Team") ~= myTeam then table.insert(list, b) end
		end
	end
	return list
end
local function aliveModel(m: Model): boolean
	local h = m:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0 and m.Parent ~= nil
end

local function renderCheats()
	local f = state.flags
	local why = state.cheatWhy
	if why ~= "" then note("⚠ " .. why, RED) end
	title("Serveur")
	local r = row()
	btn(r, "Immortel : " .. onOff(f.god), if f.god then GREEN else nil, function() act("god") end)
	btn(r, "Balles infinies : " .. onOff(f.ammo), if f.ammo then GREEN else nil, function() act("ammo") end)
	btn(r, "Grenades infinies : " .. onOff(f.nades), if f.nades then GREEN else nil, function() act("nades") end)
	title("Vision à travers les murs")
	if state.visionWhy ~= "" then note(state.visionWhy, RED) end
	local r2 = row()
	btn(r2, "Vision : " .. onOff(cheats.vision), if cheats.vision then GREEN else nil, function() cheats.vision = not cheats.vision; render() end)
	btn(r2, "Regarder un ennemi", nil, function()
		local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if h and h.Health > 0 then say("Seulement quand tu es éliminé", RED); return end
		local list = enemyModels()
		if #list == 0 then say("Personne à regarder", RED); return end
		local idx = (spectating and table.find(list, spectating) or 0) % #list + 1
		spectating = list[idx]
		local eh = list[idx]:FindFirstChildOfClass("Humanoid")
		if eh then camera.CameraSubject = eh; say("Tu regardes " .. list[idx].Name, GREEN) end
	end)
	title("Visée automatique")
	if state.aimWhy ~= "" then note(state.aimWhy, RED) end
	local r3 = row()
	btn(r3, "Visée auto : " .. onOff(cheats.aim), if cheats.aim then GREEN else nil, function() cheats.aim = not cheats.aim; render() end)
	btn(r3, "Quand : " .. AIM_MODES[cheats.aimMode], nil, function()
		cheats.aimMode = if cheats.aimMode == "ads" then "fire" elseif cheats.aimMode == "fire" then "always" else "ads"; render()
	end)
	btn(r3, "Force : " .. AIM_STR_N[cheats.aimStr], nil, function()
		cheats.aimStr = if cheats.aimStr == "soft" then "strong" elseif cheats.aimStr == "strong" then "locked" else "soft"; render()
	end)
	title("Prendre une arme")
	local keys = {}
	for k, w in pairs(Config.WEAPONS) do if not w.melee and (w.slot == 0 or w.slot == 1) then table.insert(keys, k) end end
	table.sort(keys, function(a, b)
		local wa, wb = Config.WEAPONS[a], Config.WEAPONS[b]
		if wa.slot ~= wb.slot then return wa.slot < wb.slot end
		return wa.name < wb.name
	end)
	local rr: Frame? = nil
	for i, k in ipairs(keys) do
		if (i - 1) % 6 == 0 then rr = row() end
		btn(rr :: Frame, Config.WEAPONS[k].name, nil, function() act("weapon", k) end)
	end
end

local function renderLog()
	local r = row()
	btn(r, "Actualiser", nil, function() refresh(); render() end)
	btn(r, "Effacer", RED, function() act("clearlog") end)
	btn(r, "Verrouiller le panneau", nil, function() ask("lock"); state = nil; render() end)
	local lines = state.log or {}
	for i = #lines, math.max(1, #lines - 80), -1 do
		local l = lines[i]
		local ok, col = pcall(Color3.fromHex, l.col)
		note(l.t .. "  " .. l.txt, if ok and l.col ~= "" then col else Color3.new(1, 1, 1))
	end
end

render = function()
	for name, b in pairs(tabBtns) do b.BackgroundColor3 = if name == tab then GOLD else PANEL2; b.TextColor3 = if name == tab then PANEL else Color3.new(1, 1, 1) end
	if player:GetAttribute("AdminUnlocked") ~= true or not state then tabBar.Visible = false; renderLogin(); return end
	tabBar.Visible = true
	clear()
	if tab == "Joueurs" then renderPlayers()
	elseif tab == "Partie" then renderGame()
	elseif tab == "Donner" then renderGive()
	elseif tab == "Triche" then renderCheats()
	else renderLog() end
end

for _, name in ipairs(TABS) do
	local b = make("TextButton", { Size = UDim2.fromOffset(100, 26), BackgroundColor3 = PANEL2, Font = Enum.Font.GothamBold, TextSize = 13,
		TextColor3 = Color3.new(1, 1, 1), Text = name }, tabBar)
	corner(b, 5)
	b.Activated:Connect(function() tab = name; refresh(); render() end)
	tabBtns[name] = b
end

local function setOpen(on: boolean)
	gui.Enabled = on
	player:SetAttribute("UiOpen", if on then true else nil)
	if on then
		if player:GetAttribute("AdminUnlocked") == true then refresh() end
		say("")
		render()
	end
end
closeBtn.Activated:Connect(function() setOpen(false) end)

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if input.KeyCode ~= Enum.KeyCode.Insert and input.KeyCode ~= Enum.KeyCode.F2 then return end
	if processed and not gui.Enabled then return end
	if player:GetAttribute("AdminEligible") ~= true then return end   -- joueur normal : rien
	setOpen(not gui.Enabled)
end)

-- rafraîchit l'état (raisons de coupure des triches) toutes les secondes quand le panneau ou une triche est actif
task.spawn(function()
	while true do
		task.wait(1)
		if player:GetAttribute("AdminUnlocked") == true and (gui.Enabled or cheats.vision or cheats.aim) then
			refresh()
			if gui.Enabled and tab ~= "Journal" and not UserInputService:GetFocusedTextBox() then render() end
		elseif player:GetAttribute("AdminUnlocked") ~= true then
			state = nil
		end
	end
end)

-- ---------- vision (Highlight toujours visible + nom, vie, distance) ----------
local marks: { [Model]: { hl: Highlight, bb: BillboardGui, txt: TextLabel } } = {}
local function visionOn(): boolean
	return cheats.vision and state ~= nil and state.visionWhy == "" and player:GetAttribute("AdminUnlocked") == true
end
local function clearMarks()
	for m, v in pairs(marks) do v.hl:Destroy(); v.bb:Destroy(); marks[m] = nil end
end
RunService.Heartbeat:Connect(function()
	if not visionOn() then if next(marks) then clearMarks() end; return end
	local seen: { [Model]: boolean } = {}
	local me = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	for _, m in ipairs(enemyModels()) do
		if aliveModel(m) then
			seen[m] = true
			local v = marks[m]
			if not v then
				local hl = make("Highlight", { DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, FillColor = RED, FillTransparency = 0.6, OutlineColor = Color3.new(1, 1, 1), Adornee = m }, gui)
				local bb = make("BillboardGui", { Size = UDim2.fromOffset(150, 34), StudsOffset = Vector3.new(0, 3.4, 0), AlwaysOnTop = true, Adornee = m:FindFirstChild("Head") or m.PrimaryPart }, gui)
				local txt = make("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.new(1, 1, 1),
					TextStrokeTransparency = 0.3, Text = "" }, bb)
				v = { hl = hl, bb = bb, txt = txt }
				marks[m] = v
			end
			local h = m:FindFirstChildOfClass("Humanoid") :: Humanoid
			local root = m:FindFirstChild("HumanoidRootPart") :: BasePart?
			local dist = if me and root then math.floor((root.Position - me.Position).Magnitude / Config.STUDS_PER_METER + 0.5) else 0
			v.txt.Text = m.Name .. "\n" .. math.floor(h.Health + 0.5) .. " pv · " .. dist .. " m"
		end
	end
	for m, v in pairs(marks) do if not seen[m] then v.hl:Destroy(); v.bb:Destroy(); marks[m] = nil end end
end)

-- ---------- visée auto ----------
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local AIM_CONE = math.cos(math.rad(28))
RunService:BindToRenderStep("AdminAim", Enum.RenderPriority.Camera.Value + 1, function()
	if not cheats.aim or not state or state.aimWhy ~= "" or player:GetAttribute("AdminUnlocked") ~= true or S.kc then return end
	local ch = player.Character
	if not ch then return end
	local active = cheats.aimMode == "always" or (cheats.aimMode == "ads" and S.aiming)
		or (cheats.aimMode == "fire" and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1))
	if not active then return end
	local cf = camera.CFrame
	local best: Vector3? = nil
	local bestDot = AIM_CONE
	rayParams.FilterDescendantsInstances = { ch, camera }
	for _, m in ipairs(enemyModels()) do
		local head = m:FindFirstChild("Head") :: BasePart?
		if head and aliveModel(m) then
			local to = head.Position - cf.Position
			local dot = cf.LookVector:Dot(to.Unit)
			if dot > bestDot then
				local hit = workspace:Raycast(cf.Position, to, rayParams)
				if not hit or hit.Instance:IsDescendantOf(m) then best = head.Position; bestDot = dot end
			end
		end
	end
	if not best then return end
	local goal = CFrame.lookAt(cf.Position, best)
	camera.CFrame = cf:Lerp(goal, AIM_STR[cheats.aimStr])
end)

player:GetAttributeChangedSignal("AdminUnlocked"):Connect(function()
	if player:GetAttribute("AdminUnlocked") ~= true then cheats.vision = false; cheats.aim = false; state = nil; clearMarks() end
end)
player.CharacterAdded:Connect(function() spectating = nil end)
