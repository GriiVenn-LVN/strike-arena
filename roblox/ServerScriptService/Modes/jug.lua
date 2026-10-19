--!strict
-- Modes/jug : Mastodonte (web : src/8X_mastodonte.js). Chacun pour soi : le premier qui élimine devient le Mastodonte
-- (400 PV, gilet, M249 à réserve illimitée, halo rouge). Seul le Mastodonte marque : +1 par élimination et +1 toutes les
-- 5 s. Celui qui l'élimine prend sa place. Premier à la limite (25 / 40 / 60) ; à la fin du chrono, le meilleur score gagne.
-- Les bots chassent le Mastodonte.
local WeaponService = require(script.Parent.Parent.WeaponService)

local HP, WPN = 400, "m249"
local M = {}
local function MS(): any return require(script.Parent.Parent.MatchService) :: any end

local function look(c: any, on: boolean)
	local ch = WeaponService.charOf(c)
	if not ch then return end
	local h = ch:FindFirstChild("JugGlow")
	if on and not h then
		local hl = Instance.new("Highlight"); hl.Name = "JugGlow"; hl.FillColor = Color3.fromRGB(255, 58, 42); hl.FillTransparency = 0.6
		hl.OutlineColor = Color3.fromRGB(255, 120, 60); hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent = ch
	elseif not on and h then h:Destroy() end
	ch:SetAttribute("Jug", if on then true else nil)
end
local function point(m: any, c: any, n: number)
	local k = MS().keyOf(c)
	m.score[k] = (m.score[k] or 0) + n
	local s = m.stats[k]; if s then s.pts = m.score[k] end
end
local function make(m: any, c: any, s: any)
	local prev = m.data.who
	if prev and prev ~= c then look(prev, false) end
	m.data.who = c; m.data.whoName = s and s.name; m.data.tick = 0
	local ch = MS().aliveChar(c)
	if not ch then return end
	local hum = ch:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.MaxHealth = HP; hum.Health = HP
	WeaponService.giveLoadout(c, { WPN, "knife" })
	WeaponService.setReserve(c, WPN, 999)
	WeaponService.addShield(c, 0)
	look(c, true)
	if typeof(c) == "Instance" and c:IsA("Player") then
		MS().announce(m, "TU ES LE MASTODONTE", "Tiens le plus longtemps possible", Color3.fromRGB(255, 90, 60), c)
	end
	for p in pairs(m.players) do
		if p ~= c then MS().announce(m, string.upper(s and s.name or "?") .. " EST LE MASTODONTE", "Élimine-le pour prendre sa place", Color3.fromRGB(255, 90, 60), p) end
	end
end

function M.setup(m: any) m.data.who = nil; m.data.tick = 0 end
function M.onKill(m: any, killer: any, victim: any, _key: string, _hs: boolean, ks: any, vs: any): boolean
	local wasJ = m.data.who == victim
	if wasJ then look(victim, false); m.data.who = nil end
	if not ks or ks == vs then return true end
	if wasJ or not m.data.who then make(m, killer, ks)
	elseif m.data.who == killer then point(m, killer, 1) end
	return true
end
function M.tick(m: any, dt: number)
	local j = m.data.who
	if j and not MS().aliveChar(j) then look(j, false); m.data.who = nil; return end
	if j then
		m.data.tick += dt
		if m.data.tick >= 5 then m.data.tick -= 5; point(m, j, 1) end
	end
end
function M.checkEnd(m: any): (boolean, any)
	for k, v in pairs(m.score) do if m.limit and v >= m.limit then return true, m.stats[k] end end
	return false, nil
end
function M.botGoal(m: any, bot: Model): Vector3?
	local j = m.data.who
	if not j or j == bot then return nil end
	local ch = MS().aliveChar(j)
	local r = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	return r and r.Position
end
function M.info(m: any): any
	local j = m.data.who
	local ch = j and MS().aliveChar(j)
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	local top = {}
	for k, v in pairs(m.score) do local s = m.stats[k]; if s then table.insert(top, { s.name, v }) end end
	table.sort(top, function(a, b) return a[2] > b[2] end)
	local parts = {}
	for i = 1, math.min(3, #top) do table.insert(parts, top[i][1] .. " " .. top[i][2]) end
	return { line = if j then "🛡 MASTODONTE : " .. (m.data.whoName or "?") .. " — " .. (if hum then math.ceil(hum.Health) else 0) .. " PV" else "Première élimination = Mastodonte",
		sub = table.concat(parts, "   ") .. (if m.limit then "   / " .. m.limit else ""), color = Color3.fromRGB(255, 122, 90) }
end
function M.cleanup(m: any) if m.data.who then look(m.data.who, false) end; m.data.who = nil end
return M
