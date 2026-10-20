--!strict
-- Modes/train : Entraînement (web : src/61_variants.js trPlaceDummies / trUpdate / variantKill, src/8Za_train.js).
-- Stand de tir sans limite de temps : des silhouettes fixes (s), mobiles (m, va-et-vient de 5 m) et surgissantes (p,
-- 2,6 s visibles puis 1,2 s cachées). Touche = +100 (+150 à la tête) + bonus de série (5 par cible, 100 au plus) ;
-- elles reviennent après 0,7 à 1,4 s. Réserve illimitée. Le chrono compte le temps passé ; « Terminer » affiche le bilan.
-- Temps de réaction (port Roblox) : délai entre la réapparition d'une cible et sa chute (moyenne des 10 dernières,
-- meilleur temps) ; records du joueur (score, précision, réaction) gardés dans le profil par CareerService.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local WeaponService = require(script.Parent.Parent.WeaponService)

local U = Config.STUDS_PER_METER
local M = {}
M.noBots = true
local function MS(): any return require(script.Parent.Parent.MatchService) :: any end
local popEvent = ReplicatedStorage:FindFirstChild("ModePop") :: RemoteEvent?
if not popEvent then
	local e = Instance.new("RemoteEvent"); e.Name = "ModePop"; e.Parent = ReplicatedStorage; popEvent = e
end

type Dummy = { kind: string, home: Vector3, model: Model?, ph: number, popT: number, up: boolean, n: number, upAt: number? }
local function CS(): any return require(script.Parent.Parent.CareerService) :: any end
local RT_MAX = 3            -- au-delà de 3 s, la cible n'a pas été vue : le temps ne compte pas

local function newModel(m: any, d: Dummy): Model
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = Color3.fromRGB(230, 200, 160); desc.TorsoColor = Color3.fromRGB(200, 70, 60)
	desc.LeftArmColor = desc.HeadColor; desc.RightArmColor = desc.HeadColor
	desc.LeftLegColor = Color3.fromRGB(60, 60, 70); desc.RightLegColor = desc.LeftLegColor
	local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	model.Name = "Cible " .. d.n
	model:SetAttribute("MatchId", m.id); model:SetAttribute("Team", "cible"); model:SetAttribute("Dummy", true)
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.BreakJointsOnDeath = false
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	root.Anchored = true
	model:PivotTo(CFrame.new(d.home + Vector3.new(0, 3, 0)))
	model.Parent = m.map.folder
	return model
end

local function place(m: any)
	local list = m.map.data.targets
	if not list or #list == 0 then
		list = {}
		for i, c in ipairs(m.map.data.roam or {}) do table.insert(list, { c[1], c[2], ({ "s", "m", "p" })[(i - 1) % 3 + 1] }) end
	end
	m.data.dummies = {}
	for i, tg in ipairs(list) do
		local d: Dummy = { kind = tg[3] or "s", home = MS().cellToWorld(m, tg[1], tg[2]), model = nil, ph = math.random() * 6, popT = 0, up = true, n = i }
		d.model = newModel(m, d)
		table.insert(m.data.dummies, d)
	end
end

function M.setup(m: any)
	m.data.tr = { score = 0, streak = 0, best = 0, hits = 0, t = 0, rts = {}, rtBest = nil, rec = nil }
	m.limit = nil
	place(m)
end
function M.onSpawn(_m: any, c: any)
	task.defer(function() local k = WeaponService.current(c); if k then WeaponService.setReserve(c, k, 999) end end)
end
function M.onKill(m: any, killer: any, victim: any, _key: string, headshot: boolean, ks: any, _vs: any): boolean
	if typeof(victim) ~= "Instance" or not victim:GetAttribute("Dummy") then return true end
	m.stats[MS().keyOf(victim)] = nil       -- les cibles n'apparaissent pas au tableau
	local tr = m.data.tr
	tr.hits += 1; tr.streak += 1; tr.best = math.max(tr.best, tr.streak)
	local pts = (if headshot then 150 else 100) + math.min(100, tr.streak * 5)
	tr.score += pts
	if ks then ks.pts = tr.score end
	if typeof(killer) == "Instance" and killer:IsA("Player") and popEvent then
		popEvent:FireClient(killer, (if headshot then "TÊTE ! " else "") .. "+" .. pts, Color3.fromRGB(255, 215, 94), "pickup")
	end
	for _, d in ipairs(m.data.dummies :: { Dummy }) do
		if d.model == victim then
			-- temps de réaction : depuis la réapparition de la cible (pas les cibles posées au départ)
			if d.upAt then
				local rt = os.clock() - d.upAt
				if rt > 0.05 and rt < RT_MAX then
					table.insert(tr.rts, rt); if #tr.rts > 10 then table.remove(tr.rts, 1) end
					tr.rtBest = math.min(tr.rtBest or rt, rt)
				end
			end
			d.popT = 0.7 + math.random() * 0.7; d.up = false; d.upAt = nil
		end
	end
	-- records du joueur (score, précision à partir de 30 tirs, réaction moyenne à partir de 5 cibles)
	if typeof(killer) == "Instance" and killer:IsA("Player") then
		local st = m.stats[killer]
		local acc = if st and st.shots >= 30 then math.floor(math.min(1, st.hits / st.shots) * 100 + 0.5) else nil
		local avg: number? = nil
		if #tr.rts >= 5 then local s = 0; for _, v in ipairs(tr.rts) do s += v end; avg = s / #tr.rts end
		local okR, beat = pcall(function() return CS().trainRecord(killer, { score = tr.score, acc = acc, rt = avg, rtBest = tr.rtBest }) end)
		if okR and beat and not tr.recShown and tr.score >= 1000 and popEvent then
			tr.recShown = true
			popEvent:FireClient(killer, "NOUVEAU RECORD !", Color3.fromRGB(125, 255, 159), "pickup")
		end
	end
	return true
end
function M.tick(m: any, dt: number)
	local tr = m.data.tr
	tr.t += dt
	local t = os.clock()
	for _, d in ipairs(m.data.dummies :: { Dummy }) do
		local model = d.model
		local hum = model and model:FindFirstChildOfClass("Humanoid")
		local alive = hum ~= nil and hum.Health > 0 and d.up
		if d.kind == "m" and alive and model then
			local x = math.sin(t * 0.9 + d.ph) * 5 * U
			local dir = if math.cos(t * 0.9 + d.ph) > 0 then -90 else 90
			model:PivotTo(CFrame.new(d.home + Vector3.new(x, 3, 0)) * CFrame.Angles(0, math.rad(dir), 0))
		end
		if d.kind == "p" and alive then
			d.ph += dt
			if d.ph > 2.6 then d.up = false; d.ph = 0; d.popT = 1.2; if model then model.Parent = nil end end
		end
		if not d.up then
			d.popT -= dt
			if d.popT <= 0 then
				if model and (not hum or hum.Health <= 0) then model:Destroy(); model = nil end
				if model then model.Parent = m.map.folder; d.up = true
				else d.model = newModel(m, d); d.up = true end
				d.ph = 0; d.upAt = os.clock()
			end
		end
	end
	-- un tir raté remet la série à zéro (comme le web)
	local shots = 0
	for p in pairs(m.players) do local st = m.stats[p]; if st then shots += st.shots end end
	local misses = math.max(0, shots - tr.hits)
	if misses > (tr.misses or 0) then tr.streak = 0 end
	tr.misses = misses
	for p in pairs(m.players) do
		local k, _mag, reserve = WeaponService.current(p)
		if k and reserve < 30 and not Config.WEAPONS[k].melee then WeaponService.setReserve(p, k, 999) end
	end
end
function M.info(m: any): any
	local tr = m.data.tr
	local shots, hits = 0, 0
	for p in pairs(m.players) do local s = m.stats[p]; if s then shots += s.shots; hits += s.hits end end
	local acc = if shots > 0 then math.floor(math.min(1, tr.hits / shots) * 100 + 0.5) else 0
	local mins = math.floor(tr.t / 60)
	local avg: number? = nil
	if #tr.rts > 0 then local s = 0; for _, v in ipairs(tr.rts) do s += v end; avg = s / #tr.rts end
	m.data.public = { train = { score = tr.score, acc = acc, streak = tr.streak, best = tr.best, t = math.floor(tr.t), rt = avg, rtBest = tr.rtBest } }
	local function sec(x: number): string return (string.gsub(string.format("%.2f", x), "%.", ",")) .. " s" end
	return { line = "SCORE " .. tr.score .. "   ·   précision " .. acc .. " %   ·   série " .. tr.streak,
		sub = string.format("%d:%02d — série max %d", mins, math.floor(tr.t) % 60, tr.best)
			.. (if avg then " — réaction " .. sec(avg) .. " (meilleure " .. sec(tr.rtBest or avg) .. ")" else ""), color = Color3.fromRGB(255, 215, 94) }
end
function M.cleanup(m: any)
	for _, d in ipairs(m.data.dummies or {}) do if d.model then d.model:Destroy() end end
	m.data.dummies = {}
end
return M
