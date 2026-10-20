--!strict
-- StarterPlayerScripts/LobbyUI (LocalScript)
-- Interface de lobby minimale : profil (niveau/XP/pièces), récompense quotidienne, défis, ouverture de caisses.
-- À habiller avec ton propre design (ScreenGui dans StarterGui, ViewportFrame pour l'animation 3D des caisses).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local getProfile = ReplicatedStorage:WaitForChild("GetProfile") :: RemoteFunction
local claimDaily = ReplicatedStorage:WaitForChild("ClaimDaily") :: RemoteFunction
local openBox = ReplicatedStorage:WaitForChild("OpenBox") :: RemoteFunction

local gui = Instance.new("ScreenGui"); gui.Name = "LobbyUI"; gui.ResetOnSpawn = false; gui.Parent = player:WaitForChild("PlayerGui")

local function label(text: string, y: number): TextLabel
	local l = Instance.new("TextLabel"); l.Size = UDim2.fromOffset(420, 30); l.Position = UDim2.fromOffset(20, y)
	l.BackgroundTransparency = 0.3; l.BackgroundColor3 = Color3.fromRGB(13, 18, 29); l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.GothamBold; l.TextSize = 18; l.TextXAlignment = Enum.TextXAlignment.Left; l.Text = text; l.Parent = gui
	return l
end

local function button(text: string, y: number, cb: () -> ()): TextButton
	local b = Instance.new("TextButton"); b.Size = UDim2.fromOffset(260, 36); b.Position = UDim2.fromOffset(20, y)
	b.BackgroundColor3 = Color3.fromRGB(255, 70, 85); b.TextColor3 = Color3.new(1, 1, 1); b.Font = Enum.Font.GothamBlack; b.TextSize = 16
	b.Text = text; b.Parent = gui; b.Activated:Connect(cb)
	return b
end

local profileLabel = label("Chargement…", 20)
local function refresh()
	local data = getProfile:InvokeServer()
	if not data then return end
	profileLabel.Text = string.format("Niv. %d  •  %d/%d XP  •  💰 %d  •  📦 %d", data.level, data.xp, data.xpNeed, data.profile.coins, (data.profile.boxes.std or 0) + (data.profile.boxes.prem or 0))
	return data
end

local data = refresh()
if data and data.daily.canClaim then
	button("🎁 Récupérer la récompense du jour", 60, function()
		local res = claimDaily:InvokeServer()
		if res then print("Récompense jour", res.day, res.reward) end
		refresh()
	end)
end

for i, id in ipairs({ "std", "prem" }) do
	local def = Config.BOXES[id]
	local odds = {}
	for r, w in ipairs(def.weights) do table.insert(odds, Config.RARITY[r].name .. " " .. w .. "%") end
	label(def.name .. " — " .. table.concat(odds, " • "), 110 + (i - 1) * 80)         -- probabilités visibles (obligatoire)
	button("Ouvrir " .. def.name, 142 + (i - 1) * 80, function()
		local res = openBox:InvokeServer(id)
		if res and res.ok then
			print("Tirage :", Config.RARITY[res.rarity].name, res.item.kind, res.duplicate and "(doublon)" or "")
			-- animation 3D d'ouverture du web (src/8V_crate.js) : caisse qui tombe, loquets, lumière, ouverture, objet révélé
			require(ReplicatedStorage.Shared.CrateOpening).play(nil, res, id)
		else
			warn("Ouverture impossible :", res and res.err)
		end
		refresh()
	end)
end

-- Remplacée par le menu principal (MainMenu : profil, récompense du jour, défis, Arsenal › Caisses) : on la cache.
gui.Enabled = false
