--!strict
-- Modes/koth : Capture de zone (web : src/61_variants.js kothUpdate). Par équipe : une zone (anneau) sur la carte ;
-- une équipe seule dans la zone marque 1 point par seconde, deux équipes = zone disputée. La zone se déplace au bout
-- de 60 s puis toutes les 75 s (zones de la carte : MAP.koth, sinon le centre puis les sites A et B). Les éliminations
-- ne marquent pas. Premier à la limite (100 / 200 / 300) ; à la fin du chrono (10 min), le plus de points gagne.
-- Les bots vont dans la zone.
local WeaponService = require(script.Parent.Parent.WeaponService)
local O = require(script.Parent.objutil)

local U = O.U
local T, CT = O.T, O.CT
-- zones du web (src/21_maps_extra.js) pour les cartes qui en ont ; les autres : le centre puis les sites
local KOTH: { [string]: { { number } } } = {
	harbor = { { 20, 19, 5 }, { 7, 5, 5 }, { 33, 6, 5 } },
	metro = { { 20, 21, 5 }, { 6, 20, 5 }, { 33, 20, 5 } },
	jungle = { { 20, 19, 5 }, { 7, 8, 5 }, { 33, 8, 5 } },
	range = { { 20, 20, 5 } },
	labo = { { 19, 31, 4 }, { 6, 28, 4 }, { 33, 28, 4 }, { 19, 11, 5 } },
	asile = { { 19, 32, 4 }, { 6, 28, 4 }, { 33, 29, 4 }, { 19, 18, 4 } },
}
local M = {}
local function MS(): any return O.MS() end

local function zones(m: any): { { number } }
	local z = m.map.data.koth or KOTH[m.settings.map]
	if z and #z > 0 then return z end
	local l = { { 20, 20, 5 } }
	for _, s in ipairs(m.map.data.sites or {}) do table.insert(l, { s.cx, s.cz, 5 }) end
	return l
end
local function zone(m: any): (Vector3, number)
	local list = zones(m)
	local z = list[(m.data.idx % #list) + 1]
	return O.ground(m, MS().cellToWorld(m, z[1], z[2])), z[3] * 1.45 * U
end
local function place(m: any)
	local pos, r = zone(m)
	if m.data.ring then m.data.ring:Destroy() end
	m.data.ring = O.ring(m, "KothRing", pos, r, 9 * U, O.WHITE, 0.92)
	m.data.owner = nil; m.data.hold = 0; m.data.contested = false
	m.data.pos, m.data.r = pos, r
	m.data.bot = {}
end

function M.setup(m: any)
	local d = m.data
	d.idx = 0; d.owner = nil; d.contested = false; d.hold = 0; d.moveAt = math.huge; d.bot = {}
	m.score[T] = 0; m.score[CT] = 0
	place(m)
	d.public = { kind = "koth", pos = d.pos, r = d.r, owner = nil, contested = false, moveLeft = 60 }
end
function M.start(m: any) m.data.moveAt = os.clock() + 60 end
function M.onKill(): boolean return true end     -- les éliminations ne marquent pas
function M.tick(m: any, dt: number)
	local d = m.data
	if os.clock() >= d.moveAt then
		d.idx += 1; d.moveAt = os.clock() + 75
		place(m)
		for p in pairs(m.players) do O.pop(p, "LA ZONE SE DÉPLACE !", O.CONTEST, "click") end
	end
	local c = { [T] = 0, [CT] = 0 }
	for _, cb in ipairs(O.alive(m)) do
		local r = O.root(cb) :: BasePart
		local team = WeaponService.teamOf(cb)
		if team and c[team] and O.flat(r.Position, d.pos) < d.r and math.abs(O.feet(r).Y - d.pos.Y) < 3 * U then c[team] += 1 end
	end
	d.contested = c[T] > 0 and c[CT] > 0
	local owner = if c[T] > 0 and c[CT] == 0 then T elseif c[CT] > 0 and c[T] == 0 then CT else nil
	d.owner = owner
	O.ringColor(d.ring, if owner then O.COL[owner] elseif d.contested then O.CONTEST else O.WHITE)
	if owner then
		d.hold += dt
		while d.hold >= 1 do
			d.hold -= 1
			m.score[owner] = (m.score[owner] or 0) + 1
			for _, cb in ipairs(O.alive(m, owner)) do
				local r = O.root(cb) :: BasePart
				local s = m.stats[MS().keyOf(cb)]
				if s and O.flat(r.Position, d.pos) < d.r then s.pts += 1; s.score += 5 end
			end
		end
	end
	d.public = { kind = "koth", pos = d.pos, r = d.r, owner = owner, contested = d.contested, moveLeft = math.max(0, math.ceil(d.moveAt - os.clock())) }
end
function M.checkEnd(m: any): (boolean, any)
	for _, t in ipairs({ T, CT }) do if m.limit and (m.score[t] or 0) >= m.limit then return true, t end end
	return false, nil
end
function M.timeUp(m: any): any
	local a, b = m.score[T] or 0, m.score[CT] or 0
	return if a > b then T elseif b > a then CT else nil
end
-- les bots vont dans la zone, chacun à un endroit différent (web : z.x ± 0,7 r), et changent de place de temps en temps
function M.botGoal(m: any, bot: Model): Vector3?
	local d = m.data
	if not d.pos then return nil end
	local g = d.bot[bot.Name]
	if not g or os.clock() > g.t then
		local s = d.r * 0.7
		g = { pos = d.pos + Vector3.new((math.random() * 2 - 1) * s, 3, (math.random() * 2 - 1) * s), t = os.clock() + 7 + math.random() * 8 }
		d.bot[bot.Name] = g
	end
	return g.pos
end
function M.info(m: any): any
	local d = m.data
	local line = if d.contested then "ZONE DISPUTÉE" elseif d.owner == nil then "ZONE LIBRE — allez dessus !"
		else "ZONE TENUE PAR LES " .. (if d.owner == T then "ATTAQUANTS" else "DÉFENSEURS")
	local left = if d.moveAt == math.huge then 60 else math.max(0, math.ceil(d.moveAt - os.clock()))
	return { line = line, sub = "Prochaine zone " .. left .. " s · premier à " .. tostring(m.limit),
		color = if d.owner then O.COL[d.owner] elseif d.contested then O.CONTEST else O.WHITE, kind = "koth" }
end
function M.cleanup(m: any)
	if m.data.ring then m.data.ring:Destroy() end
	m.data.ring = nil
end
return M
