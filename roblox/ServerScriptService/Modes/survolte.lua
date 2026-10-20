--!strict
-- Modes/survolte : Survolté (« Cranked » de Call of Duty). Match à mort par équipe, réapparition en 3 s, 1 point par
-- élimination, première équipe à la limite (25 / 40 / 60) ou meilleur score au bout des 8 minutes (MatchService).
-- Après une élimination, le tueur est SURVOLTÉ : il court 20 % plus vite (attribut SpeedMult, lu par le mouvement et les
-- bots) mais il a 30 s pour éliminer à nouveau, sinon il explose. Chaque nouvelle élimination remet le compte à 30 s.
-- Être éliminé ou exploser enlève l'état survolté. Les bots survoltés foncent vers l'adversaire le plus proche.
local WeaponService = require(script.Parent.Parent.WeaponService)
local O = require(script.Parent.objutil)

local LIMIT, SPEED = 30, 1.2
local PINK = Color3.fromRGB(255, 90, 209)
local M = {}
local function MS(): any return O.MS() end
local function now(): number return os.clock() end

-- état survolté visible : halo rose, vitesse, ligne personnelle du HUD
local function look(c: any, on: boolean)
	local ch = WeaponService.charOf(c)
	if not ch then return end
	local h = ch:FindFirstChild("CrankGlow")
	if on and not h then
		local hl = Instance.new("Highlight"); hl.Name = "CrankGlow"; hl.FillColor = PINK; hl.FillTransparency = 0.75
		hl.OutlineColor = PINK; hl.OutlineTransparency = 0.3; hl.DepthMode = Enum.HighlightDepthMode.Occluded; hl.Parent = ch
	elseif not on and h then h:Destroy() end
	-- vitesse : multipliée par-dessus celle d'avant (modificateur Turbo compris), rendue telle quelle à la fin
	local base = ch:GetAttribute("CrankBase")     -- présent = déjà survolté ; 0 = pas de multiplicateur avant
	local was = base ~= nil
	if O.isPlayer(c) and not on then (c :: Player):SetAttribute("ModeLine", nil) end
	if was == on then return end
	local hum = ch:FindFirstChildOfClass("Humanoid")
	if hum and not O.isPlayer(c) then   -- le joueur, lui, applique SpeedMult dans son mouvement
		hum.WalkSpeed = if on then hum.WalkSpeed * SPEED else hum.WalkSpeed / SPEED
	end
	if on then
		local cur = ch:GetAttribute("SpeedMult")
		local mult = if typeof(cur) == "number" then cur else 1
		ch:SetAttribute("CrankBase", if typeof(cur) == "number" then cur else 0)
		ch:SetAttribute("SpeedMult", mult * SPEED)
	else
		ch:SetAttribute("SpeedMult", if typeof(base) == "number" and base > 0 then base else nil)
		ch:SetAttribute("CrankBase", nil)
	end
end
local function clear(m: any, c: any)
	local k = MS().keyOf(c)
	if m.data.cr[k] then m.data.cr[k] = nil end
	m.data.warn[k] = nil
	look(c, false)
end
-- explosion : vraie élimination sans tueur (comptée comme une mort, réapparition normale)
local function explode(m: any, c: any)
	local ch = MS().aliveChar(c)
	clear(m, c)
	if not ch then return end
	local r = ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	if r then
		local e = Instance.new("Explosion"); e.Position = r.Position; e.BlastPressure = 0; e.BlastRadius = 6
		e.DestroyJointRadiusPercent = 0; e.ExplosionType = Enum.ExplosionType.NoCraters; e.Parent = m.map and m.map.folder or workspace
	end
	ch:SetAttribute("ProtectedUntil", 0)
	WeaponService.applyDamage(nil, ch, 9999, false, "bomb", 1)
	if O.isPlayer(c) then O.pop(c, "💥 TU AS EXPLOSÉ — élimine plus vite !", O.BAD, "click") end
end

function M.setup(m: any)
	m.data.cr = {}; m.data.warn = {}
	m.data.public = { kind = "survolte" }
end
function M.onKill(m: any, killer: any, victim: any, _key: string, _hs: boolean, ks: any, vs: any): boolean
	clear(m, victim)
	if not ks or ks == vs or ks.team == vs.team then return false end
	m.data.cr[ks.key] = now() + LIMIT
	m.data.warn[ks.key] = nil
	look(killer, true)
	if O.isPlayer(killer) then O.pop(killer, "⏱ SURVOLTÉ ! 30 s pour éliminer à nouveau", PINK, "pickup") end
	return false     -- MatchService compte le point de l'élimination
end
function M.tick(m: any, _dt: number)
	local t = now()
	for _, c in ipairs(MS().combatants(m)) do
		local k = MS().keyOf(c)
		local dl = m.data.cr[k]
		if dl then
			if not MS().aliveChar(c) then clear(m, c)
			elseif t >= dl then explode(m, c)
			else
				local left = math.ceil(dl - t)
				if O.isPlayer(c) then
					(c :: Player):SetAttribute("ModeLine", "⏱ SURVOLTÉ — " .. left .. " s pour éliminer")
					if left <= 10 and (m.data.warn[k] or 99) > 10 then O.pop(c, "⚠ PLUS QUE 10 S !", O.BAD, "click") end
					if left <= 5 and (m.data.warn[k] or 99) > 5 then O.pop(c, "⚠ 5 S !", O.BAD, "click") end
				end
				m.data.warn[k] = left
			end
		end
	end
end
-- bots survoltés : vers l'ennemi vivant le plus proche (sinon leur comportement habituel)
function M.botGoal(m: any, bot: Model): Vector3?
	if not m.data.cr["bot:" .. bot.Name] then return nil end
	local r = bot:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not r then return nil end
	local team = WeaponService.teamOf(bot)
	local best, bd = nil, math.huge
	for _, c in ipairs(O.alive(m)) do
		if WeaponService.teamOf(c) ~= team then
			local cr = O.root(c)
			if cr then
				local d = O.flat(cr.Position, r.Position)
				if d < bd then best, bd = cr.Position, d end
			end
		end
	end
	return best
end
function M.info(m: any): any
	local n = 0
	for _ in pairs(m.data.cr) do n += 1 end
	return { line = "⏱ SURVOLTÉ — élimine toutes les 30 s ou explose", sub = (if n > 0 then n .. " survolté(s) en ce moment · " else "") .. "premier à " .. tostring(m.limit),
		color = PINK, kind = "survolte" }
end
function M.onLeave(m: any, p: Player)
	if m.data.cr then m.data.cr[p] = nil end
	p:SetAttribute("ModeLine", nil)
end
function M.cleanup(m: any)
	for _, c in ipairs(MS().combatants(m)) do look(c, false) end
	for p in pairs(m.players) do p:SetAttribute("ModeLine", nil) end
	m.data.cr = {}
end
return M
