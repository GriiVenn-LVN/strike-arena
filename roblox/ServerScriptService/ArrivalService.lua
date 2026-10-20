--!strict
-- ServerScriptService/ArrivalService (ModuleScript, appelé par MatchService)
-- Arrivée en hélicoptère ou en véhicule au début d'une partie en équipe, comme le web (src/61_variants.js :
-- startCine() quand le mode se joue en équipe, hors Entraînement ; src/65_cine.js, src/65b_car.js).
-- La scène se joue chez chaque joueur (StarterPlayerScripts/CinematicController) pendant « PRÉPAREZ-VOUS » :
-- tout le monde est déjà à son point de départ, immobile (joueurs à vitesse 0, bots gelés par MatchService).
-- play() attend que chacun ait fini ou passé sa scène (au plus MAX_WAIT secondes), puis rend la main à MatchService
-- qui relance son compte à rebours.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArrivalService = {}

local MAX_WAIT = 14         -- scène la plus longue (hélicoptère, 11,6 s) + chargement du véhicule
local CHAR_WAIT = 3         -- personnages encore en train d'apparaître

local remote = Instance.new("RemoteEvent")
remote.Name = "ArrivalCinematic"      -- serveur -> joueur : jouer la scène ; joueur -> serveur : "done" (finie ou passée)
remote.Parent = ReplicatedStorage

local pending: { [Player]: number } = {}   -- joueur -> partie dont il regarde l'arrivée

remote.OnServerEvent:Connect(function(p: Player, what: any)
	if what == "done" then pending[p] = nil end
end)

-- m : partie de MatchService ; warmup : durée du « PRÉPAREZ-VOUS » qui suit ; tick : envoi de l'état (toutes les 0,5 s)
-- Renvoie true si une scène a été jouée (le compte à rebours repart alors de warmup).
function ArrivalService.play(m: any, warmup: number, tick: () -> ()): boolean
	if not m.def.team or m.mode == "train" then return false end
	-- les personnages viennent d'être lancés (MatchService.spawnPlayer) : on leur laisse le temps d'arriver
	local t0 = os.clock()
	while os.clock() - t0 < CHAR_WAIT do
		local ready = true
		for p in pairs(m.players) do
			local c = p.Character
			if p.Parent and not (c and c:FindFirstChild("HumanoidRootPart") and c:GetAttribute("MatchId") == m.id) then ready = false end
		end
		if ready then break end
		task.wait(0.1)
	end
	local any = false
	for p in pairs(m.players) do
		if p.Parent and p.Character then
			pending[p] = m.id; any = true
			remote:FireClient(p, { limit = m.limit or 0, mode = m.mode })
		end
	end
	if not any then return false end
	local deadline = os.clock() + MAX_WAIT
	local nextTick = 0
	while os.clock() < deadline and not m.closed do
		local waiting = false
		for p, id in pairs(pending) do
			if id == m.id then
				if not p.Parent or not m.players[p] then pending[p] = nil else waiting = true end
			end
		end
		if not waiting then break end
		m.endsAt = deadline + warmup
		if os.clock() >= nextTick then nextTick = os.clock() + 0.5; pcall(tick) end
		task.wait(0.1)
	end
	for p, id in pairs(pending) do if id == m.id then pending[p] = nil end end
	m.endsAt = os.clock() + warmup
	return true
end

return ArrivalService
