--!strict
-- Modes/ctf : Capture du drapeau (web : src/8Zd_ctf.js). Chaque équipe a un drapeau dans sa base, un peu en avant de
-- son point de départ. Touche le drapeau adverse pour le prendre, ramène-le dans ta base pendant que ton drapeau y est :
-- +1 capture. Le porteur éliminé lâche le drapeau ; un adversaire qui le touche le ramène aussitôt chez lui, un allié
-- du porteur peut le reprendre ; un drapeau lâché revient seul au bout de 25 s. Les éliminations ne marquent pas.
-- Premier à 3 / 5 / 7 captures ; à la fin du chrono (10 min), le plus de captures gagne.
-- Bots : un tiers défend, le reste attaque ; tout le monde poursuit le voleur ; le porteur file vers sa base.
local WeaponService = require(script.Parent.Parent.WeaponService)
local O = require(script.Parent.objutil)

local U = O.U
local T, CT = O.T, O.CT
local R, BACK = 1.5 * U, 25
local CLOTH = { Attaquants = Color3.fromRGB(216, 64, 15), ["Défenseurs"] = Color3.fromRGB(22, 96, 216) }
local M = {}
local function MS(): any return O.MS() end

type Flag = { team: string, home: Vector3, pos: Vector3, state: string, carrier: any, backAt: number, model: Model, ring: Model, rot: number }

local function base(m: any, team: string): Vector3
	local mine = if team == T then m.map.data.spawnT else m.map.data.spawnCT
	local them = if team == T then m.map.data.spawnCT else m.map.data.spawnT
	local x, z = O.avg(mine or { { 20, 36 } })
	local ox, oz = O.avg(them or { { 20, 4 } })
	local cx, cz = O.spot(m, x + (ox - x) * 0.12, z + (oz - z) * 0.12)
	return O.ground(m, MS().cellToWorld(m, cx, cz))
end
local function flagOf(m: any, team: string): Flag return m.data.flags[team] end
local function say(m: any, f: Flag, mineText: string, theirText: string, goodForMine: boolean, special: Player?, specialText: string?)
	for p in pairs(m.players) do
		local mine = WeaponService.teamOf(p) == f.team
		local good = if mine then goodForMine else not goodForMine
		local text = if special == p and specialText then specialText elseif mine then mineText else theirText
		MS().announce(m, text, nil, if good then O.GOOD else O.BAD, p)
	end
end
local function setHome(m: any, f: Flag)
	O.release(f.model, CFrame.new(f.home) * CFrame.Angles(0, f.rot, 0))
	f.state = "home"; f.carrier = nil; f.pos = f.home
	f.model:SetAttribute("State", "home")
	local _ = m
end
local function drop(m: any, f: Flag)
	local c = f.carrier
	local r = c and O.root(c)
	local at = if r then O.feet(r) else f.pos
	f.carrier = nil
	local ch = c and WeaponService.charOf(c)
	if ch then ch:SetAttribute("HasFlag", nil) end
	f.pos = O.groundBelow(m, at)
	O.release(f.model, CFrame.new(f.pos))
	f.state = "dropped"; f.backAt = os.clock() + BACK
	f.model:SetAttribute("State", "dropped")
	say(m, f, "NOTRE DRAPEAU EST TOMBÉ", "DRAPEAU ENNEMI LÂCHÉ", false)
end
local function take(m: any, f: Flag, c: any)
	f.state = "carried"; f.carrier = c
	f.model:SetAttribute("State", "carried")
	local ch = WeaponService.charOf(c)
	if ch then ch:SetAttribute("HasFlag", f.team) end
	O.carry(f.model, c, CFrame.new(-0.18 * U, -0.6 * U, 0.4 * U) * CFrame.Angles(0.18, 0, -0.12), 0.75)
	say(m, f, "NOTRE DRAPEAU EST PRIS", "DRAPEAU ENNEMI PRIS", false, if O.isPlayer(c) then c else nil, "TU AS LE DRAPEAU ! RAMÈNE-LE À TA BASE")
end
local function carrying(m: any, c: any): boolean
	for _, f in pairs(m.data.flags :: { [string]: Flag }) do if f.state == "carried" and f.carrier == c then return true end end
	return false
end

function M.setup(m: any)
	local d = m.data
	d.flags = {}; d.bot = {}
	m.score[T] = 0; m.score[CT] = 0
	local center = MS().cellToWorld(m, 20, 20)
	for _, team in ipairs({ T, CT }) do
		local home = base(m, team)
		-- la toile fait face au milieu de la carte (d'où arrivent les attaquants)
		local rot = math.atan2(center.X - home.X, center.Z - home.Z) - math.pi / 4
		local model = O.flag(m.map.folder, "CtfFlag_" .. team, home, CLOTH[team])
		model:SetAttribute("Team", team); model:SetAttribute("State", "home")
		model:PivotTo(CFrame.new(home) * CFrame.Angles(0, rot, 0))
		local ring = O.ring(m, "CtfRing_" .. team, home, R + 0.3 * U, 0.9 * U, O.COL[team], 0.95)
		d.flags[team] = { team = team, home = home, pos = home, state = "home", carrier = nil, backAt = 0, model = model, ring = ring, rot = rot } :: Flag
	end
	M.publish(m)
end
function M.publish(m: any)
	local l = {}
	for team, f in pairs(m.data.flags :: { [string]: Flag }) do
		local s = f.carrier and m.stats[MS().keyOf(f.carrier)]
		l[team] = { state = f.state, pos = f.pos, home = f.home, carrier = s and s.name, carrierUserId = if O.isPlayer(f.carrier) then f.carrier.UserId else nil,
			back = if f.state == "dropped" then math.max(0, math.ceil(f.backAt - os.clock())) else nil }
	end
	m.data.public = { kind = "ctf", flags = l }
end

function M.onKill(m: any, _killer: any, victim: any): boolean
	for _, f in pairs(m.data.flags :: { [string]: Flag }) do
		if f.state == "carried" and f.carrier == victim then drop(m, f) end
	end
	return true
end
function M.tick(m: any, _dt: number)
	local d = m.data
	for _, team in ipairs({ T, CT }) do
		local f = flagOf(m, team)
		if f.state == "carried" then
			local c = f.carrier
			local r = c and O.root(c)
			if not r then drop(m, f); continue end
			f.pos = O.feet(r)
			local own = flagOf(m, O.other(team))
			-- le porteur (de l'autre équipe) rentre chez lui avec son propre drapeau à la base : capture
			if own.state == "home" and O.flat(f.pos, own.home) < R + 0.6 * U and math.abs(f.pos.Y - own.home.Y) < 2 * U then
				local ct = own.team
				m.score[ct] = (m.score[ct] or 0) + 1
				local s = m.stats[MS().keyOf(c)]
				if s then s.pts += 1; s.score += 300 end
				local ch = WeaponService.charOf(c)
				if ch then ch:SetAttribute("HasFlag", nil) end
				setHome(m, f)
				for p in pairs(m.players) do
					local us = WeaponService.teamOf(p) == ct
					local mine = m.score[WeaponService.teamOf(p) or T] or 0
					local their = m.score[O.other(WeaponService.teamOf(p) or T)] or 0
					MS().announce(m, if us then "DRAPEAU CAPTURÉ !" else "L'ENNEMI A CAPTURÉ NOTRE DRAPEAU",
						(if p == c then "Bien joué ! " else "") .. mine .. " – " .. their, if us then O.GOOD else O.BAD, p)
				end
				d.bot = {}
			end
			continue
		end
		if f.state == "dropped" and os.clock() >= f.backAt then
			setHome(m, f)
			say(m, f, "NOTRE DRAPEAU EST REVENU", "LE DRAPEAU ENNEMI EST REVENU", true)
			continue
		end
		for _, c in ipairs(O.alive(m)) do
			local r = O.root(c) :: BasePart
			if O.flat(r.Position, f.pos) <= R and math.abs(O.feet(r).Y - f.pos.Y) <= 2 * U then
				if WeaponService.teamOf(c) ~= f.team then
					if not carrying(m, c) then take(m, f, c); break end
				elseif f.state == "dropped" then
					setHome(m, f)
					say(m, f, "DRAPEAU RÉCUPÉRÉ", "L'ENNEMI A RÉCUPÉRÉ SON DRAPEAU", true)
					if O.isPlayer(c) then O.pop(c, "Drapeau ramené", O.GOOD, "pickup") end
					local s = m.stats[MS().keyOf(c)]; if s then s.score += 100 end
					break
				end
			end
		end
	end
	M.publish(m)
end
function M.checkEnd(m: any): (boolean, any)
	for _, t in ipairs({ T, CT }) do if m.limit and (m.score[t] or 0) >= m.limit then return true, t end end
	return false, nil
end
function M.timeUp(m: any): any
	local a, b = m.score[T] or 0, m.score[CT] or 0
	return if a > b then T elseif b > a then CT else nil
end
-- botGoal du web : un tiers défend (id % 3 == 0), le reste attaque ; le porteur rentre ; tout le monde chasse le voleur
local function jitter(p: Vector3, s: number): Vector3 return p + Vector3.new((math.random() * 2 - 1) * s * U, 3, (math.random() * 2 - 1) * s * U) end
function M.botGoal(m: any, bot: Model): Vector3?
	local d = m.data
	local attr = bot:GetAttribute("Team")
	if attr ~= T and attr ~= CT then return nil end
	local team = attr :: string
	local own, foe = flagOf(m, team), flagOf(m, O.other(team))
	if not own or not foe then return nil end
	if foe.state == "carried" and foe.carrier == bot then return own.home + Vector3.new(0, 3, 0) end
	local g = d.bot[bot.Name]
	if g and os.clock() < g.t then return g.pos end
	local root = bot:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return nil end
	local id = 0
	for i = 1, #bot.Name do id += string.byte(bot.Name, i) end
	local def = id % 3 == 0
	local pos, hold
	if own.state == "carried" and own.carrier and (def or math.random() < 0.6) then
		local r = O.root(own.carrier); pos = if r then r.Position else own.pos; hold = 0.8
	elseif own.state == "dropped" and (def or O.flat(own.pos, root.Position) < 28 * U) then
		pos = own.pos + Vector3.new(0, 3, 0); hold = 1.2
	elseif def then
		pos = jitter(own.home, 5); hold = 4 + math.random() * 4
	elseif foe.state == "carried" and foe.carrier then
		local r = O.root(foe.carrier); pos = jitter(if r then r.Position - Vector3.new(0, 3, 0) else foe.pos, 3); hold = 1.2
	else
		pos = foe.pos + Vector3.new(0, 3, 0); hold = 1.2
	end
	d.bot[bot.Name] = { pos = pos, t = os.clock() + hold }
	return pos
end
function M.info(m: any): any
	return { line = "Ramène le drapeau adverse — premier à " .. tostring(m.limit) .. " captures", color = Color3.fromRGB(255, 159, 67), kind = "ctf" }
end
function M.onLeave(m: any, p: Player)
	for _, f in pairs(m.data.flags or {}) do if f.state == "carried" and f.carrier == p then drop(m, f) end end
end
function M.cleanup(m: any)
	for _, f in pairs(m.data.flags or {}) do
		local ch = f.carrier and WeaponService.charOf(f.carrier)
		if ch then ch:SetAttribute("HasFlag", nil) end
		if f.model.Parent then f.model:Destroy() end
		if f.ring.Parent then f.ring:Destroy() end
	end
	m.data.flags = {}
end
return M
