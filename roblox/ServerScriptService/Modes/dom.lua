--!strict
-- Modes/dom : Domination (web : src/8P_domination.js). Trois drapeaux A, B, C entre les deux bases (A et C décalés
-- sur les côtés). Reste seul dans le cercle (3,4 m) pour capturer : 5 s depuis neutre, 8 s pour retourner un drapeau
-- adverse, plus vite à plusieurs (jusqu'à ×2) ; un adversaire dans le cercle bloque la capture ; la progression
-- redescend quand personne n'y est. Chaque drapeau tenu rapporte 1 point par seconde. Les éliminations ne marquent pas.
-- Premier à la limite (100 / 200 / 300) ; à la fin du chrono (10 min), le plus de points gagne.
-- Les bots choisissent un drapeau à prendre (75 %) ou à défendre et en changent toutes les 12 à 20 s.
local WeaponService = require(script.Parent.Parent.WeaponService)
local O = require(script.Parent.objutil)

local U = O.U
local T, CT = O.T, O.CT
local R, CAP = 3.4 * U, 5
local M = {}
local function MS(): any return O.MS() end

type Flag = { n: string, pos: Vector3, owner: string?, cap: string?, prog: number, contested: boolean, ring: Model, pole: BasePart }

function M.setup(m: any)
	local d = m.data
	d.flags = {}; d.tick = 0; d.bot = {}
	m.score[T] = 0; m.score[CT] = 0
	local tx, tz = O.avg(m.map.data.spawnT or { { 10, 30 } })
	local cx2, cz2 = O.avg(m.map.data.spawnCT or { { 30, 10 } })
	for i, n in ipairs({ "A", "B", "C" }) do
		local k = ({ 0.28, 0.5, 0.72 })[i]
		local cx, cz = O.spot(m, tx + (cx2 - tx) * k, tz + (cz2 - tz) * k)
		if i ~= 2 then
			-- A et C décalés sur les côtés pour que les trois drapeaux ne soient pas alignés
			local px, pz = -(cz2 - tz), cx2 - tx
			local L = math.max(0.001, math.sqrt(px * px + pz * pz))
			local s = (if i == 1 then 1 else -1) * 7
			cx, cz = O.spot(m, cx + px / L * s, cz + pz / L * s)
		end
		local pos = O.ground(m, MS().cellToWorld(m, cx, cz))
		local ring = O.ring(m, "DomRing_" .. n, pos, R, 4.5 * U, O.WHITE, 0.92)
		local pole = O.part(ring, "Marker", Vector3.new(0.3, 0.3, 0.3), CFrame.new(pos + Vector3.new(0, 3.2 * U, 0)), O.WHITE, 1)
		O.label(pole, n, O.WHITE, 0)
		ring:SetAttribute("Flag", n)
		table.insert(d.flags, { n = n, pos = pos, owner = nil, cap = nil, prog = 0, contested = false, ring = ring, pole = pole } :: Flag)
	end
	M.publish(m)
end

local function color(f: Flag): Color3
	return if f.contested then O.CONTEST elseif f.owner then O.COL[f.owner] else O.WHITE
end
function M.publish(m: any)
	local l = {}
	for _, f in ipairs(m.data.flags :: { Flag }) do
		table.insert(l, { n = f.n, pos = f.pos, owner = f.owner, cap = f.cap, prog = f.prog, contested = f.contested })
	end
	m.data.public = { kind = "dom", flags = l, r = R }
end

function M.onKill(): boolean return true end
function M.tick(m: any, dt: number)
	local d = m.data
	for _, f in ipairs(d.flags :: { Flag }) do
		local c = { [T] = 0, [CT] = 0 }
		local inside = {}
		for _, cb in ipairs(O.alive(m)) do
			local r = O.root(cb) :: BasePart
			local team = WeaponService.teamOf(cb)
			if team and c[team] and O.flat(r.Position, f.pos) < R and math.abs(O.feet(r).Y - f.pos.Y) < 2.5 * U then
				c[team] += 1; table.insert(inside, cb)
			end
		end
		f.contested = c[T] > 0 and c[CT] > 0
		local who = if c[T] > 0 and c[CT] == 0 then T elseif c[CT] > 0 and c[T] == 0 then CT else nil
		if who and who ~= f.owner then
			if f.cap ~= who then f.cap = who; f.prog = 0 end
			f.prog += dt * math.min(2, 1 + 0.25 * (c[who] - 1)) / (if f.owner == nil then CAP else CAP * 1.6)
			if f.prog >= 1 then
				local prev = f.owner
				f.owner = who; f.prog = 0; f.cap = nil
				for p in pairs(m.players) do
					local mine = WeaponService.teamOf(p) == who
					MS().announce(m, if mine then "DRAPEAU " .. f.n .. " CAPTURÉ" else "DRAPEAU " .. f.n .. " PERDU", nil, if mine then O.GOOD else O.BAD, p)
				end
				for _, cb in ipairs(inside) do
					local s = m.stats[MS().keyOf(cb)]
					if s then s.score += 100 end
				end
				-- les défenseurs du drapeau perdu réagissent
				if prev then for name, g in pairs(d.bot) do if g.team == prev then d.bot[name] = nil end end end
			end
		elseif not who and not f.contested and f.prog > 0 then
			f.prog = math.max(0, f.prog - dt * 0.25)
		end
		O.ringColor(f.ring, color(f))
		local lab = f.pole:FindFirstChild("Label")
		local txt = lab and lab:FindFirstChild("Text") :: TextLabel?
		if txt then
			txt.TextColor3 = color(f)
			local st = txt:FindFirstChildOfClass("UIStroke"); if st then st.Color = color(f) end
		end
	end
	d.tick += dt
	while d.tick >= 1 do
		d.tick -= 1
		for _, f in ipairs(d.flags :: { Flag }) do
			if f.owner then
				m.score[f.owner] = (m.score[f.owner] or 0) + 1
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
-- botGoal du web : un drapeau à prendre (75 %, le plus proche 7 fois sur 10) ou à défendre, pour 12 à 20 s
function M.botGoal(m: any, bot: Model): Vector3?
	local d = m.data
	local flags = d.flags :: { Flag }
	if #flags == 0 then return nil end
	local root = bot:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return nil end
	local team = bot:GetAttribute("Team")
	local g = d.bot[bot.Name]
	if not g or os.clock() > g.t then
		local mine, other = {}, {}
		for _, f in ipairs(flags) do if f.owner == team then table.insert(mine, f) else table.insert(other, f) end end
		local f: Flag
		if #other > 0 and (math.random() < 0.75 or #mine == 0) then
			table.sort(other, function(a, b) return O.flat(a.pos, root.Position) < O.flat(b.pos, root.Position) end)
			f = if math.random() < 0.7 then other[1] else other[math.random(#other)]
		else
			local l = if #mine > 0 then mine else flags
			f = l[math.random(#l)]
		end
		local s = 1.8 * U
		g = { f = f, team = team, t = os.clock() + 12 + math.random() * 8,
			pos = f.pos + Vector3.new((math.random() * 2 - 1) * s, 3, (math.random() * 2 - 1) * s) }
		d.bot[bot.Name] = g
	end
	-- un bot posté sur un drapeau tenu et calme repart de temps en temps
	if g.f.owner == team and not g.f.contested and O.flat(root.Position, g.f.pos) < R and math.random() < 0.002 then g.t = 0 end
	return g.pos
end
function M.info(m: any): any
	local parts = {}
	for _, f in ipairs(m.data.flags :: { Flag }) do
		table.insert(parts, f.n .. " " .. (if f.contested then "disputé" elseif f.owner == T then "ATT" elseif f.owner == CT then "DÉF" else "libre"))
	end
	return { line = "Capture A, B et C — premier à " .. tostring(m.limit) .. " points", sub = table.concat(parts, "   ·   "), color = Color3.fromRGB(255, 210, 58), kind = "dom" }
end
function M.cleanup(m: any)
	for _, f in ipairs(m.data.flags or {}) do if f.ring.Parent then f.ring:Destroy() end end
	m.data.flags = {}
end
return M
