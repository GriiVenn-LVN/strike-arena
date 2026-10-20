--!strict
-- ServerScriptService/RegenService (Script)
-- Régénération de santé du jeu web (src/8J_regen.js) : après 3 s sans subir de dégâts, les PV remontent de 20 PV/s
-- jusqu'à 100, pour les joueurs et les bots. Pas pour les zombies, les cibles d'entraînement ni un joueur à terre.
-- Pas dans les modes à manches sans réapparition (Compétitif, Désamorçage rapide, Duel, Gunfight, duels du lobby)
-- ni à l'Entraînement : la santé y reste tactique. Le script « Health » de Roblox est remplacé par un script vide
-- (StarterCharacterScripts/Health), sinon il ajoutait 1 % de vie par seconde partout.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DELAY, RATE, MAX = 3, 20, 100
local NO_REGEN = { bomb = true, rapid = true, duel = true, gunfight = true, train = true }

type Track = { last: number, hurt: number }
local track: { [Humanoid]: Track } = {}

local function watch(h: Humanoid)
	if track[h] then return end
	local st: Track = { last = h.Health, hurt = os.clock() }
	track[h] = st
	-- tout dégât relance le délai (coups, chute, explosions…)
	h.HealthChanged:Connect(function(hp: number)
		if hp < st.last - 1e-3 then st.hurt = os.clock() end
		st.last = hp
	end)
	h.AncestryChanged:Connect(function()
		if not h:IsDescendantOf(workspace) then track[h] = nil end
	end)
end
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("Humanoid") then watch(d) end
end)
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("Humanoid") then watch(d) end
end

-- mode de la partie d'un combattant : attribut MatchMode du joueur ; un bot prend celui d'un joueur de sa partie
local function modeOf(char: Model): string?
	local p = Players:GetPlayerFromCharacter(char)
	if p then
		local zone = p:GetAttribute("Zone")
		if zone == "duel" then return "duel" end
		if zone ~= "match" then return nil end
		local m = p:GetAttribute("MatchMode")
		return if typeof(m) == "string" then m else nil
	end
	local id = char:GetAttribute("MatchId")
	if id == nil then return nil end
	for _, q in ipairs(Players:GetPlayers()) do
		if q:GetAttribute("MatchId") == id then
			local m = q:GetAttribute("MatchMode")
			return if typeof(m) == "string" then m else nil
		end
	end
	return nil
end

local acc = 0
RunService.Heartbeat:Connect(function(dt: number)
	acc += dt
	if acc < 0.1 then return end
	local step = acc; acc = 0
	local now = os.clock()
	for h, st in pairs(track) do
		local hp = h.Health
		local cap = math.min(MAX, h.MaxHealth)
		if hp <= 0 or hp >= cap or now - st.hurt < DELAY then continue end
		local char = h.Parent
		if not char or not char:IsA("Model") then continue end
		if char:GetAttribute("Zombie") == true or char:GetAttribute("Dummy") == true or char:GetAttribute("Downed") == true then continue end
		local mode = modeOf(char)
		if mode and NO_REGEN[mode] then continue end
		local nh = math.min(cap, hp + RATE * step)
		st.last = nh                                   -- notre propre soin n'est pas un dégât
		h.Health = nh
	end
end)
