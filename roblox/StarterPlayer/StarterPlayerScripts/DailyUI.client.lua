--!strict
-- StarterPlayerScripts/DailyUI (LocalScript)
-- CALENDRIER DE CONNEXION sur 7 jours (façon Fortnite / Call of Duty Mobile) : les 7 récompenses de la série
-- (Config.DAILY) côte à côte, jours déjà pris tamponnés ✔, jour du jour qui brille avec RÉCUPÉRER, gros lot du 7e jour,
-- paliers de série suivants (LoyaltyConfig.STREAK_GOALS, à récupérer dans les Cadeaux) et rappel des bonus du jour
-- (première victoire, XP ×2 du week-end).
-- S'ouvre tout seul la première fois qu'on ouvre le menu dans la journée si la récompense attend, et par le bouton
-- BONUS DU JOUR du menu (S.panels.daily). Le serveur (RewardService.claimDaily via ClaimDaily) vérifie tout.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local L = require(ReplicatedStorage.Shared.LoyaltyConfig)
local S = require(ReplicatedStorage.Shared.ClientState)
local K = require(script.Parent:WaitForChild("Menu"):WaitForChild("Kit"))
local C = K.C
local make, text, spaced = K.make, K.text, K.spaced

local player = Players.LocalPlayer
local function call(name: string, ...: any): any
	local r = ReplicatedStorage:FindFirstChild(name)
	if not r or not r:IsA("RemoteFunction") then return nil end
	local ok, res = pcall((r :: RemoteFunction).InvokeServer, r :: RemoteFunction, ...)
	return if ok then res else nil
end

local gui = make("ScreenGui", { Name = "DailyUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 31, Enabled = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
local veil = make("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = K.rgb(0x05080e), BackgroundTransparency = 0.35, Text = "", AutoButtonColor = false, Modal = true }, gui)
local win = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(980, 470), BackgroundTransparency = 0,
	BackgroundColor3 = C.white }, gui)
K.corner(win, 16); K.gradient(win, K.rgb(0x2a1608), K.rgb(0x0b111c), 90); K.stroke(win, C.gold, 1.5, 0.45)
local winScale = make("UIScale", { Scale = 1 }, win)
local function fit()
	local cam = workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1600, 900)
	winScale.Scale = math.clamp(math.min((vp.X - 24) / 980, (vp.Y - 24) / 470), 0.45, 1.2)
end
text(win, { Position = UDim2.fromOffset(28, 18), Size = UDim2.new(1, -100, 0, 30), Font = K.BLACK, TextSize = 26, TextWrapped = false,
	Text = "📅  " .. spaced("CALENDRIER DE CONNEXION", 2) })
local subL = text(win, { Position = UDim2.fromOffset(30, 52), Size = UDim2.new(1, -100, 0, 18), TextSize = 13, TextColor3 = C.sub, TextWrapped = false, Text = "" })
K.btn(win, "✕", "dark", function() gui.Enabled = false end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16), Size = UDim2.fromOffset(40, 40), TextSize = 18 })
local days = make("Frame", { Position = UDim2.fromOffset(28, 86), Size = UDim2.new(1, -56, 0, 210) }, win)
K.hlist(days, 10, Enum.VerticalAlignment.Bottom)
local foot = make("Frame", { Position = UDim2.fromOffset(28, 312), Size = UDim2.new(1, -56, 0, 140) }, win)
K.vlist(foot, 8)

local function rewardParts(r: any): (string, string)
	local ic, t = "🪙", {}
	if r.coins then table.insert(t, K.fmt(r.coins) .. " pièces") end
	if r.dance then ic = "💃"; table.insert(t, "Danse « " .. (Config.DANCES[r.dance] and Config.DANCES[r.dance].name or r.dance) .. " »") end
	if r.box then ic = "📦"; table.insert(t, if r.box == "prem" then "Caisse Premium" else "Caisse Standard") end
	return ic, table.concat(t, " + ")
end

local data: any = nil
local render: () -> ()
local function claim()
	local res = call("ClaimDaily")
	if res and res.reward then
		pcall(function() K.uiSound(false) end)
		local _, t = rewardParts(res.reward)
		subL.Text = "🎁 Jour " .. tostring(res.day) .. " récupéré : " .. t .. " !"
		subL.TextColor3 = C.gold
	end
	data = call("GetProfile") or data
	render()
	local f = S.panels.menuRefresh; if f then task.spawn(f) end
end

render = function()
	K.clear(days); K.clear(foot)   -- les UIListLayout restent
	local ds = data and data.daily or { canClaim = false, day = 1, streak = 0 }
	local today = tonumber(ds.day) or 1
	for i, r in ipairs(Config.DAILY) do
		local big = i == 7
		local taken = (ds.canClaim and i < today) or (not ds.canClaim and i <= today)
		local now = ds.canClaim and i == today
		local f = make("Frame", { LayoutOrder = i, Size = UDim2.fromOffset(if big then 176 else 112, if now or big then 206 else 186), BackgroundTransparency = 0,
			BackgroundColor3 = C.white }, days)
		K.corner(f, 12)
		K.gradient(f, if big then K.rgb(0x4a3108) elseif now then K.rgb(0x3a2410) else K.rgb(0x16233a), K.rgb(0x0b111c), 90, if taken then 0.3 else 0, if taken then 0.3 else 0)
		K.stroke(f, if now then C.gold elseif big then C.gold elseif taken then C.green else C.white, if now then 2.5 else 1, if now or big then 0.1 elseif taken then 0.5 else 0.88)
		text(f, { Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 16), Font = K.BLACK, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = if now then C.gold else C.sub, Text = spaced(if big then "JOUR 7 · GROS LOT" else "JOUR " .. i, 1) })
		local ic, t = rewardParts(r)
		local icon = text(f, { Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 64), TextSize = if big then 54 else 44, TextXAlignment = Enum.TextXAlignment.Center, Text = ic })
		text(f, { Position = UDim2.fromOffset(6, 100), Size = UDim2.new(1, -12, 0, 40), TextSize = 12, Font = K.BOLD, TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Top, Text = t })
		if taken then
			icon.TextTransparency = 0.5
			text(f, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 62), Size = UDim2.fromOffset(60, 60), TextSize = 44, Font = K.BLACK,
				TextColor3 = C.green, TextXAlignment = Enum.TextXAlignment.Center, Text = "✔", Rotation = -12 })
		elseif now then
			local b = K.btn(f, spaced("RÉCUPÉRER", 1), "gold", claim, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -16, 0, 34), TextSize = 12 })
			K.beat(b, 1.06, 1)
			K.shine(f, 2.2, 0.3)
		else
			text(f, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -14), Size = UDim2.new(1, 0, 0, 16), TextSize = 11, TextColor3 = C.dim,
				TextXAlignment = Enum.TextXAlignment.Center, Text = if i == today and not ds.canClaim then "Reviens demain" else "Dans " .. (i - today + (if ds.canClaim then 0 else 0)) .. " j" })
		end
	end
	-- série et paliers de série suivants
	local streak = tonumber(ds.streak) or 0
	subL.TextColor3 = C.sub
	subL.Text = if ds.canClaim then "Ta récompense du jour t'attend ! Connecte-toi chaque jour : la série repart à zéro si tu manques un jour."
		else "Série de " .. streak .. " jour" .. (if streak > 1 then "s" else "") .. " · reviens demain pour le jour " .. (today % 7 + 1)
	local nextGoal = nil
	for _, g in ipairs(L.STREAK_GOALS) do if streak < g.days then nextGoal = g; break end end
	if nextGoal then
		local row = make("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 36) }, foot)
		local parts = {}
		local r: any = nextGoal.reward
		if r.coins then table.insert(parts, K.fmt(r.coins) .. " pièces") end
		if r.box then table.insert(parts, if r.box == "prem" then "Caisse Premium" else "Caisse Standard") end
		if r.boost then table.insert(parts, r.boost .. " boosts d'XP") end
		if r.title and L.TITLES[r.title] then table.insert(parts, "titre « " .. L.TITLES[r.title] .. " »") end
		text(row, { Size = UDim2.new(1, 0, 0, 16), Font = K.BLACK, TextSize = 12, TextWrapped = false,
			Text = nextGoal.icon .. "  " .. spaced("PROCHAIN PALIER DE SÉRIE", 1) .. " : " .. nextGoal.days .. " jours → " .. table.concat(parts, " + ") })
		K.bar(row, streak / nextGoal.days, { Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 6) })
	end
	local tips = { "🏆 Première victoire du jour : +" .. L.FIRST_WIN.xp .. " XP et +" .. L.FIRST_WIN.coins .. " pièces." }
	if data and data.weekend then table.insert(tips, 1, "⚡ C'est le week-end : XP ×2 sur toutes les parties !") end
	table.insert(tips, "⭐ Premium : un jour manqué par semaine ne casse pas ta série, et un cadeau de plus chaque jour.")
	for i, t in ipairs(tips) do K.para(foot, t, 12, if i == 1 and data and data.weekend then C.violet else C.dim, 1 + i) end
end

local function open()
	fit()
	data = call("GetProfile") or data
	gui.Enabled = true
	render()
	-- petite entrée qui rebondit (sur l'échelle d'adaptation à l'écran : un seul UIScale par cadre)
	local target = winScale.Scale
	winScale.Scale = target * 0.9; K.tween(winScale, 0.25, { Scale = target }, Enum.EasingStyle.Back)
end
veil.Activated:Connect(function() gui.Enabled = false end)
S.panels.daily = function()
	if gui.Enabled then gui.Enabled = false else task.spawn(open) end
end

-- ouverture automatique : la première fois que le menu s'ouvre au lobby avec la récompense du jour en attente
task.spawn(function()
	local shown = false
	while not shown do
		task.wait(1.5)
		if S.menuOpen and player:GetAttribute("Zone") == "lobby" then
			local d = call("GetProfile")
			if d and d.daily then
				shown = true
				if d.daily.canClaim then task.wait(1); data = d; if not gui.Enabled then open() end end
			end
		end
	end
end)
