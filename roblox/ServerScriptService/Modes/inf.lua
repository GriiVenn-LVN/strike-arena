--!strict
-- Modes/inf : Infecté (web : src/8Q_infecte.js). Tout le monde commence survivant (armes normales) dans l'équipe
-- « Défenseurs » ; quelques secondes après le début, un joueur au hasard devient l'infecté (équipe « Attaquants ») :
-- couteau seulement, plus rapide, halo vert, réapparaît. Chaque survivant tué rejoint les infectés. Les infectés gagnent
-- s'il ne reste plus de survivant ; les survivants gagnent s'il en reste au moins un à la fin du chrono (5 min).
-- Les bots infectés foncent au couteau sur le survivant le plus proche.
local WeaponService = require(script.Parent.Parent.WeaponService)

local SURV, INF = "Défenseurs", "Attaquants"
local GREEN = Color3.fromRGB(157, 255, 90)
local M = {}
local function MS(): any return require(script.Parent.Parent.MatchService) :: any end

local function look(c: any)
	local ch = WeaponService.charOf(c)
	if not ch or ch:FindFirstChild("InfGlow") then return end
	local hl = Instance.new("Highlight"); hl.Name = "InfGlow"; hl.FillColor = GREEN; hl.FillTransparency = 0.55; hl.OutlineColor = GREEN; hl.Parent = ch
	local hum = ch:FindFirstChildOfClass("Humanoid")
	if hum then hum.WalkSpeed = 16 * 1.12 end
end
local function arm(c: any)
	if not MS().aliveChar(c) then return end
	WeaponService.giveLoadout(c, { "knife" })
	WeaponService.setReduction(c, 0)
	look(c)
end
local function turn(m: any, c: any, first: boolean)
	MS().setTeam(m, c, INF)
	arm(c)
	local s = m.stats[MS().keyOf(c)]
	local isP = typeof(c) == "Instance" and c:IsA("Player")
	if first then
		for p in pairs(m.players) do
			if p == c then MS().announce(m, "TU ES L'INFECTÉ", "Contamine tout le monde au couteau", GREEN, p)
			else MS().announce(m, string.upper(s and s.name or "?") .. " EST INFECTÉ", "Survis jusqu'à la fin du chrono", GREEN, p) end
		end
	elseif isP then
		MS().announce(m, "TU ES INFECTÉ", "Contamine les survivants", GREEN, c)
	end
end
local function count(m: any): (number, number)
	local s, i = 0, 0
	for _, c in ipairs(MS().combatants(m)) do
		if WeaponService.teamOf(c) == INF then i += 1 else s += 1 end
	end
	m.score[SURV] = s; m.score[INF] = i
	return s, i
end

function M.setup(m: any) m.data.started = false; m.data.startAt = math.huge; m.limit = nil end
function M.teamFor(m: any, _c: any): string? return if m.data.started then INF else SURV end
function M.start(m: any) m.data.startAt = os.clock() + 5 end
function M.loadout(m: any, c: any): { string }?
	if WeaponService.teamOf(c) == INF then return { "knife" } end
	return nil
end
function M.onSpawn(_m: any, c: any) if WeaponService.teamOf(c) == INF then task.defer(look, c) end end
function M.onKill(m: any, _killer: any, victim: any, _key: string, _hs: boolean, ks: any, vs: any): boolean
	if vs.team == SURV and m.data.started then
		MS().setTeam(m, victim, INF)
		if victim:IsA("Player") then MS().announce(m, "TU ES INFECTÉ", "Contamine les survivants", GREEN, victim) end
		if ks and ks.player and ks ~= vs then ks.pts += 1 end
	end
	if ks and ks.team == SURV and ks ~= vs then ks.pts += 1 end
	count(m)
	return true
end
function M.tick(m: any, _dt: number)
	if not m.data.started and os.clock() >= m.data.startAt then
		m.data.started = true
		local alive = {}
		for _, c in ipairs(MS().combatants(m)) do if MS().aliveChar(c) then table.insert(alive, c) end end
		if #alive > 0 then turn(m, alive[math.random(#alive)], true) end
	end
	count(m)
end
-- les infectés n'ont pas de bots en plus : l'équipe des survivants est complétée, les bots infectés viennent des contaminés
function M.botsWanted(m: any, team: string?, want: number): number?
	if m.data.started then return nil end      -- après le début, les bots ne changent plus (les contaminés réapparaissent)
	if team == INF then return 0 end
	-- tout le monde commence survivant : l'équipe des survivants reçoit les places des deux équipes
	return want + math.max(0, m.settings.size - 0)
end
function M.botRespawn(_m: any, _s: any): boolean return true end
function M.checkEnd(m: any): (boolean, any)
	if not m.data.started then return false, nil end
	local s = count(m)
	if s == 0 then return true, INF end
	return false, nil
end
function M.timeUp(m: any): any
	local s = count(m)
	return if s > 0 then SURV else INF
end
function M.botGoal(m: any, bot: Model): Vector3?
	if bot:GetAttribute("Team") ~= INF then return nil end
	local root = bot:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return nil end
	local best, bd = nil, math.huge
	for _, c in ipairs(MS().combatants(m)) do
		if WeaponService.teamOf(c) == SURV then
			local ch = MS().aliveChar(c)
			local r = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r and (r.Position - root.Position).Magnitude < bd then best, bd = r.Position, (r.Position - root.Position).Magnitude end
		end
	end
	return best
end
function M.info(m: any): any
	local s, i = count(m)
	if not m.data.started then return { line = "Un joueur va être infecté… survis jusqu'à la fin", color = GREEN } end
	return { line = "☣ " .. s .. " survivant" .. (if s > 1 then "s" else "") .. " · " .. i .. " infecté" .. (if i > 1 then "s" else ""), color = GREEN }
end
return M
