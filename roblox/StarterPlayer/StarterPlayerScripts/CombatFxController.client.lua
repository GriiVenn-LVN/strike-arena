--!strict
-- StarterPlayerScripts/CombatFxController (LocalScript)
-- Effets de combat du web qui ne dépendent pas d'un tir :
--   * taches de sang au sol à la mort d'un soldat (stain de src/67_immersion.js), pas pour les zombies ni les cibles ;
--   * alerte santé basse (src/8I_lowhp.js) : sous 30 PV, battements de cœur de plus en plus rapides
--     (une période de 1,1 s à 30 PV, 0,7 s à 0 PV), deux coups sourds à chaque battement.
-- Le voile rouge qui bat est dessiné par HudController.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShotFx = require(ReplicatedStorage.Shared.ShotFx)
local Sfx = require(ReplicatedStorage.Shared.Sfx)

local player = Players.LocalPlayer

-- ---------- taches de sang ----------
local watched: { [Humanoid]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local function watch(h: Humanoid)
	if watched[h] then return end
	watched[h] = true
	local was = h.Health
	h.HealthChanged:Connect(function(hp: number)
		if hp <= 0 and was > 0 then
			local m = h.Parent
			local root = m and m:FindFirstChild("HumanoidRootPart") :: BasePart?
			if m and root and m:GetAttribute("Zombie") ~= true and m:GetAttribute("Dummy") ~= true then
				ShotFx.stain(root.Position, m)
			end
		end
		was = hp
	end)
end
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("Humanoid") then watch(d) end
end)
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("Humanoid") then watch(d) end
end

-- ---------- battements de cœur sous 30 PV ----------
local beatT = 0
RunService.Heartbeat:Connect(function(dt: number)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local hp = if hum then hum.Health else 0
	if not hum or hp <= 0 or hp >= 30 or player:GetAttribute("Zone") == "lobby" then beatT = 0; return end
	local per = 1.1 - 0.4 * (1 - hp / 30)
	beatT -= dt
	if beatT <= 0 then
		beatT = per
		Sfx.step("stone", nil, 0.55)            -- le web joue un pas sourd (sfx('step'))
		task.delay(0.16, function()
			local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if h and h.Health > 0 then Sfx.step("stone", nil, 0.4) end
		end)
	end
end)
