--!strict
-- StarterPlayerScripts/LaunchNews (LocalScript)
-- Fenêtre « QUOI DE NEUF ? » au lancement (écran d'actualités des FPS : saison, mode de la semaine, nouveautés), par-dessus
-- le menu principal, UNE fois par version des nouveautés (MenuConfig.NEWS_VERSION) : la version vue est gardée dans le
-- profil (remote « Career », action « news », vérifiée par CareerService). Montre aussi la carte de joueur.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local MenuConfig = require(ReplicatedStorage.Shared.MenuConfig)
local X = require(ReplicatedStorage.Shared.ConfigExtra)
local Modes = require(ReplicatedStorage.Shared.Modes)
local PlayerCard = require(ReplicatedStorage.Shared.PlayerCard)
local MenuDir = script.Parent:WaitForChild("Menu")
local K = require(MenuDir:WaitForChild("Kit"))
local C = K.C
local make, text, spaced = K.make, K.text, K.spaced

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function call(name: string, ...: any): any
	local r = ReplicatedStorage:WaitForChild(name, 10)
	if not r or not r:IsA("RemoteFunction") then return nil end
	local ok, res = pcall((r :: RemoteFunction).InvokeServer, r :: RemoteFunction, ...)
	return if ok then res else nil
end

local shown = false
local function show(cd: any)
	if shown then return end
	shown = true
	local gui = make("ScreenGui", { Name = "LaunchNews", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 26, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, playerGui)
	local dim = make("TextButton", { Text = "", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, AutoButtonColor = false, Modal = true }, gui)
	local panel = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(620, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0, BackgroundColor3 = C.white }, gui)
	K.gradient(panel, K.rgb(0x151f33), K.rgb(0x0a0f1a), 90)
	K.corner(panel, 14); K.stroke(panel, C.accent, 1, 0.5); K.pad(panel, 26, 22); K.vlist(panel, 10)
	local sc = make("UIScale", { Scale = 0.85 }, panel)
	-- petits écrans : la fenêtre se réduit pour tenir
	local cam = workspace.CurrentCamera
	local fit = if cam then math.clamp(math.min(cam.ViewportSize.X / 700, cam.ViewportSize.Y / 640), 0.55, 1) else 1
	text(panel, { LayoutOrder = 1, Text = "📰  " .. spaced("QUOI DE NEUF ?", 2), Font = K.BLACK, TextSize = 26, Size = UDim2.new(1, 0, 0, 32), TextWrapped = false })
	local feat = Modes.featured()
	local fm = Modes.LIST[feat]
	text(panel, { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 18), TextSize = 13, TextColor3 = C.gold, Font = K.BLACK, TextWrapped = false,
		Text = "★ " .. string.upper(X.SEASON.name) .. (if fm then '   <font color="#8da0bd">·</font>   MODE DE LA SEMAINE : ' .. string.upper((string.gsub(fm.n, "%s*%(.*%)", ""))) .. " (XP ×2)" else "") })
	-- carte de joueur
	if typeof(cd) == "table" and typeof(cd.card) == "table" then
		local holder = make("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 84) }, panel)
		local title = player:GetAttribute("Title")
		local card = PlayerCard.render(holder, { banner = cd.card.b, emblem = cd.card.e, name = player.DisplayName, title = if typeof(title) == "string" then title else nil,
			level = player:GetAttribute("CardLevel"), size = 340 })
		card.AnchorPoint = Vector2.new(0.5, 0); card.Position = UDim2.fromScale(0.5, 0)
	end
	-- nouveautés (les 5 premières : les plus récentes)
	for i = 1, math.min(5, #MenuConfig.NEWS) do
		local n = MenuConfig.NEWS[i]
		local row = make("Frame", { LayoutOrder = 10 + i, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 0.94, BackgroundColor3 = C.white }, panel)
		K.corner(row, 8); K.pad(row, 10, 8)
		text(row, { Text = n.ic, TextSize = 22, Size = UDim2.fromOffset(34, 34), TextXAlignment = Enum.TextXAlignment.Center })
		local tx = make("Frame", { Position = UDim2.fromOffset(44, 0), Size = UDim2.new(1, -44, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, row)
		K.vlist(tx, 2)
		text(tx, { LayoutOrder = 1, Text = n.t .. '  <font size="9" color="#ff4655">' .. spaced("NOUVEAU", 1) .. "</font>", Font = K.BLACK, TextSize = 14,
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
		K.para(tx, n.d, 12, C.dim, 2)
		-- arrivée en cascade
		local rs = make("UIScale", { Scale = 0.9 }, row)
		TweenService:Create(rs, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.15 + i * 0.06), { Scale = 1 }):Play()
	end
	local closing = false
	local function close()
		if closing then return end
		closing = true
		task.spawn(call, "Career", "news", MenuConfig.NEWS_VERSION)
		TweenService:Create(sc, TweenInfo.new(0.18), { Scale = 0.85 * fit }):Play()
		TweenService:Create(dim, TweenInfo.new(0.18), { BackgroundTransparency = 1 }):Play()
		task.delay(0.2, function() gui:Destroy() end)
	end
	local go = K.btn(panel, "▶  " .. spaced("C'EST PARTI !", 2), "primary", close, { LayoutOrder = 30, Size = UDim2.new(1, 0, 0, 48), TextSize = 16, Name = "NewsGo" })
	K.shine(go, 2.4, 0.25)
	dim.Activated:Connect(close)
	K.overlay(gui, close, function() return go end)
	TweenService:Create(dim, TweenInfo.new(0.25), { BackgroundTransparency = 0.45 }):Play()
	TweenService:Create(sc, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = fit }):Play()
	pcall(function() require(MenuDir:WaitForChild("Fx")).confetti(panel, 26) end)
end

-- au premier affichage du menu principal (hors partie), une fois la carrière reçue
task.spawn(function()
	local mm = playerGui:WaitForChild("MainMenu", 60)
	if not mm or not mm:IsA("ScreenGui") then return end
	local checking = false
	local function check()
		if shown or checking or not mm.Enabled or player:GetAttribute("Zone") == "match" then return end
		checking = true
		task.delay(1.2, function()
			-- deux essais : la demande peut tomber pile en même temps que celle du Profil (cadence limitée côté serveur)
			for _ = 1, 2 do
				if shown or not mm.Enabled then break end
				local cd = call("Career", "get")
				if typeof(cd) == "table" then
					if cd.newsSeen ~= MenuConfig.NEWS_VERSION then show(cd) end
					break
				end
				task.wait(1)
			end
			checking = false
		end)
	end
	mm:GetPropertyChangedSignal("Enabled"):Connect(check)
	check()
end)
