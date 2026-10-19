--!strict
-- ServerScriptService/GrenadeService (ModuleScript, branché par WeaponService.init)
-- Grenades frag / flash / fumigène et mines de proximité du jeu web (src/60_game.js, src/63_agents.js) :
-- stock par combattant (attribut « Nades » = "frag,flash,smoke,mine" pour le HUD), lancer validé et simulé
-- ici (rebonds, mèche), dégâts et aveuglement calculés ici ; les clients reçoivent « GrenadeFx » pour l'affichage.
-- Fumée : WeaponService.smokeBlocks(a, b) dit si un nuage coupe la vue (pour l'IA des bots).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local G = require(ReplicatedStorage.Shared.Grenades)
local M = G.M

local GrenadeService = {}
local WS: any = nil              -- WeaponService (injecté par init, évite la dépendance circulaire)

local function remoteEvent(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent"); r.Name = name; r.Parent = ReplicatedStorage; return r
end
local fxEvent = remoteEvent("GrenadeFx")          -- serveur -> tous : { op = "throw" | "boom" | "mine" | "mineOff", ... }
local throwEvent = remoteEvent("ThrowGrenade")    -- client -> serveur : (type, regard)
local mineEvent = remoteEvent("PlaceMine")        -- client -> serveur : ()
local toastEvent = remoteEvent("GrenadeToast")    -- serveur -> joueur : texte court (« Mine posée », « Mine détruite »)
local flashFx = remoteEvent("FlashFeedback")    -- serveur -> joueur aveuglé (créé ici : WeaponService requiert ce module avant ses remotes)

type Stock = { frag: number, flash: number, smoke: number, mine: number }
local stocks: { [any]: Stock } = {}
local nades: { G.Nade } = {}
local nextId = 0
type Mine = { id: number, owner: any, team: string?, pos: Vector3, model: Model, armT: number, match: any }
local mines: { Mine } = {}
local smokes: { { p: Vector3, t: number } } = {}

local function publish(c: any)
	if typeof(c) ~= "Instance" then return end
	local s = stocks[c]
	if not s then c:SetAttribute("Nades", nil) return end
	c:SetAttribute("Nades", s.frag .. "," .. s.flash .. "," .. s.smoke .. "," .. s.mine)
end

function GrenadeService.set(c: any, frag: number, flash: number, smoke: number, mine: number)
	stocks[c] = { frag = frag, flash = flash, smoke = smoke, mine = mine }
	publish(c)
end
function GrenadeService.get(c: any): Stock?
	return stocks[c]
end
-- rend une grenade de ce type si le combattant n'en a plus (« Grenades à volonté ») ; true si rendue
function GrenadeService.refill(c: any, kind: string): boolean
	local s = stocks[c]
	if not s then s = { frag = 0, flash = 0, smoke = 0, mine = 0 }; stocks[c] = s end
	local st = s :: any
	if (st[kind] or 0) > 0 then return false end
	st[kind] = 1
	publish(c)
	return true
end
-- équipement de départ du web (dmLoadout) : joueur 1 de chaque ; bot frag 50 %, fumigène 20 %, mine 35 %
function GrenadeService.defaultKit(c: any)
	if typeof(c) == "Instance" and c:IsA("Player") then GrenadeService.set(c, 1, 1, 1, 1)
	else GrenadeService.set(c, if math.random() < .5 then 1 else 0, 0, if math.random() < .2 then 1 else 0, if math.random() < .35 then 1 else 0) end
end

local function rootOf(c: any): BasePart?
	local char = WS.charOf(c)
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end
local function alive(c: any): boolean
	local char = WS.charOf(c)
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end
local function characters(): { Instance }
	local out = {}
	for c in WS.eachCombatant() do local ch = WS.charOf(c); if ch then table.insert(out, ch) end end
	for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(out, p.Character) end end
	return out
end
local function wallBetween(a: Vector3, b: Vector3, ignore: { Instance }): boolean
	local params = G.params(ignore)
	return G.cast(a, b - a, params) ~= nil
end

-- ---------- mines ----------
local function removeMine(m: Mine, boom: boolean)
	local i = table.find(mines, m)
	if not i then return end
	table.remove(mines, i)
	m.model:Destroy()
	fxEvent:FireAllClients({ op = "mineOff", p = m.pos, boom = boom })
	if not boom then return end
	-- explosion : 95 × (1 − d/5) + 10 dans 5 m (écart de hauteur < 2,2 m), coéquipiers épargnés mais pas le poseur
	for c in WS.eachCombatant() do
		local r = rootOf(c)
		local char = WS.charOf(c)
		if r and char and alive(c) then
			local d = Vector3.new(r.Position.X - m.pos.X, 0, r.Position.Z - m.pos.Z).Magnitude / M
			local dy = math.abs(r.Position.Y - 3 - m.pos.Y) / M
			local mate = m.team ~= nil and WS.teamOf(c) == m.team and c ~= m.owner
			if d <= G.MINE.r and dy <= 2.2 and not mate then
				WS.applyDamage(if c == m.owner then nil else m.owner, char, math.floor(95 * (1 - d / G.MINE.r) + 10 + .5), false, "mine", .5)
			end
		end
	end
end
local function isFoeMine(m: Mine, c: any): boolean
	return m.owner ~= c and (m.team == nil or WS.teamOf(c) ~= m.team)
end
-- balle sur une pièce de mine : renvoie true si c'était une mine (cassée, pas d'explosion)
function GrenadeService.bulletHit(shooter: any, inst: Instance): boolean
	local id = inst:GetAttribute("MineId")
	if typeof(id) ~= "number" then return false end
	for _, m in ipairs(mines) do
		if m.id == id and m.owner ~= shooter then
			removeMine(m, false)
			if typeof(shooter) == "Instance" and shooter:IsA("Player") then toastEvent:FireClient(shooter, "Mine détruite") end
			return true
		end
	end
	return true
end
-- coup de couteau / explosion : casse les mines proches (by = seulement les mines ennemies de by)
function GrenadeService.minesNear(pos: Vector3, r: number, by: any)
	for _, m in ipairs(table.clone(mines)) do
		local d = Vector3.new(m.pos.X - pos.X, 0, m.pos.Z - pos.Z).Magnitude / M
		if d < r and (by == nil or isFoeMine(m, by)) then removeMine(m, false) end
	end
end
function GrenadeService.placeMine(c: any): boolean
	if WS.throwBlocked and WS.throwBlocked(c) then return false end
	local s = stocks[c]
	local r = rootOf(c)
	if not s or s.mine <= 0 or not r or not alive(c) then return false end
	local own = {}
	for _, m in ipairs(mines) do if m.owner == c then table.insert(own, m) end end
	if #own >= G.MINE.max then removeMine(own[1], false) end
	local look = r.CFrame.LookVector
	local at = r.Position + Vector3.new(look.X, 0, look.Z).Unit * .8 * M
	local hit = G.cast(at + Vector3.new(0, 1, 0), Vector3.new(0, -12, 0), G.params(characters()))
	if not hit or wallBetween(r.Position, at, characters()) then return false end
	nextId += 1
	local model = G.mineMesh()
	model:PivotTo(CFrame.new(hit.Position) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
	for _, p in ipairs(model:GetDescendants()) do if p:IsA("BasePart") then p:SetAttribute("MineId", nextId) end end
	model:SetAttribute("MineId", nextId); model:SetAttribute("Team", WS.teamOf(c))
	model.Parent = workspace
	local ch = WS.charOf(c)
	table.insert(mines, { id = nextId, owner = c, team = WS.teamOf(c), pos = hit.Position, model = model, armT = G.MINE.arm, match = ch and ch:GetAttribute("MatchId") })
	s.mine -= 1; publish(c)
	fxEvent:FireAllClients({ op = "mine", p = hit.Position, owner = WS.charOf(c) })
	if typeof(c) == "Instance" and c:IsA("Player") then toastEvent:FireClient(c, "Mine posée") end
	return true
end

-- ---------- grenades ----------
local function explode(n: G.Nade)
	fxEvent:FireAllClients({ op = "boom", id = n.id, kind = n.kind, p = n.p })
	local owner = n.owner
	if n.kind == "frag" then
		GrenadeService.minesNear(n.p, 4.5, nil)
		for c in WS.eachCombatant() do
			local char = WS.charOf(c)
			local r = rootOf(c)
			if char and r and alive(c) then
				local target = r.Position + Vector3.new(0, -.5, 0)
				local d = (target - n.p).Magnitude / M
				local self = c == owner
				local mate = not self and n.team ~= nil and WS.teamOf(c) == n.team
				if d < G.FRAG_R and not mate and not wallBetween(n.p + Vector3.new(0, .4 * M, 0), target, characters()) then
					WS.applyDamage(if self then nil else owner, char, math.floor(140 * (1 - d / G.FRAG_R) * (if self then .6 else 1) + .5), false, "frag", .5)
				end
			end
		end
		-- zombies (pas des combattants de WeaponService)
		if WS.extraVictims then
			for _, z in ipairs(WS.extraVictims()) do
				local zr = z:FindFirstChild("HumanoidRootPart") :: BasePart?
				if zr and z:IsDescendantOf(workspace) then
					local d = (zr.Position - n.p).Magnitude / M
					if d < G.FRAG_R and not wallBetween(n.p + Vector3.new(0, .4 * M, 0), zr.Position, characters()) then
						WS.applyDamage(owner, z, math.floor(140 * (1 - d / G.FRAG_R) + .5), false, "frag", .5)
					end
				end
			end
		end
	elseif n.kind == "flash" then
		for c in WS.eachCombatant() do
			local char = WS.charOf(c)
			local head = char and (char:FindFirstChild("Head") :: BasePart?)
			local r = rootOf(c)
			if head and r and alive(c) then
				local to = n.p - head.Position
				local d = to.Magnitude / M
				if d <= G.FLASH_R and not wallBetween(head.Position, n.p, characters()) then
					local look = r.CFrame.LookVector
					local h = Vector3.new(to.X, 0, to.Z)
					local facing = if h.Magnitude > 1e-3 then Vector3.new(look.X, 0, look.Z).Unit:Dot(h.Unit) else 1
					local dur = (if facing > .1 then 3.4 else 1.1) * math.clamp(1.25 - d / 30, .2, 1)
					if typeof(c) == "Instance" and c:IsA("Player") then flashFx:FireClient(c, dur)
					elseif char then char:SetAttribute("BlindUntil", workspace:GetServerTimeNow() + dur) end   -- pour l'IA des bots
				end
			end
		end
	else
		table.insert(smokes, { p = n.p + Vector3.new(0, 1.3 * M, 0), t = G.SMOKE_T })
	end
end

-- target : point visé (bots) ; sinon le regard look (joueur) ; free : ne consomme pas le stock
function GrenadeService.throw(c: any, kind: string, free: boolean?, look: Vector3?, target: Vector3?): boolean
	if not G.KINDS[kind] then return false end
	if WS.throwBlocked and WS.throwBlocked(c) then return false end   -- début de manche, « PRÉPAREZ-VOUS »
	local char = WS.charOf(c)
	local r = rootOf(c)
	if not char or not r or not alive(c) then return false end
	if not free then
		local s = stocks[c] :: any
		if not s or (s[kind] or 0) <= 0 then return false end
		s[kind] -= 1; publish(c)
	end
	local head = char:FindFirstChild("Head") :: BasePart?
	local eye = (if head then head.Position else r.Position + Vector3.new(0, 1.5, 0)) - Vector3.new(0, .2 * M, 0)
	local v = if target then G.launchAt(eye, target) else G.launch(look or r.CFrame.LookVector, r.AssemblyLinearVelocity)
	nextId += 1
	local n: G.Nade = { id = nextId, kind = kind, p = eye, v = v, t = G.KINDS[kind].fuse, owner = c, team = WS.teamOf(c) }
	table.insert(nades, n)
	fxEvent:FireAllClients({ op = "throw", id = n.id, kind = kind, p = eye, v = v, t = n.t, owner = char, team = n.team })
	return true
end

-- ---------- la fumée coupe-t-elle la vue entre a et b ? (smokeBlocks du web) ----------
function GrenadeService.smokeBlocks(a: Vector3, b: Vector3): boolean
	local d = b - a
	local L = d.Magnitude
	if L < 1e-3 then return false end
	local u = d / L
	for _, s in ipairs(smokes) do
		local t = math.clamp((s.p - a):Dot(u), 0, L)
		if (a + u * t - s.p).Magnitude < G.SMOKE_R * M * .85 then return true end
	end
	return false
end

function GrenadeService.reset(c: any)
	stocks[c] = nil
	publish(c)
end
-- fin de manche / de partie : plus rien au sol
-- matchId : seulement les mines de cette partie (plusieurs parties tournent sur le même serveur)
function GrenadeService.clear(matchId: any?)
	if matchId == nil then table.clear(nades); table.clear(smokes) end
	for _, m in ipairs(table.clone(mines)) do if matchId == nil or m.match == matchId then removeMine(m, false) end end
end

function GrenadeService.init(weaponService: any)
	WS = weaponService
	throwEvent.OnServerEvent:Connect(function(player: Player, kind: any, look: any)
		if typeof(kind) ~= "string" then return end
		if typeof(look) ~= "Vector3" or look.Magnitude < .5 or look.Magnitude > 1.5 then look = nil end
		GrenadeService.throw(player, kind, false, if look then (look :: Vector3).Unit else nil)
	end)
	mineEvent.OnServerEvent:Connect(function(player: Player) GrenadeService.placeMine(player) end)

	local params = G.params({})
	local blink = 0
	RunService.Heartbeat:Connect(function(dt: number)
		if #nades > 0 then
			params.FilterDescendantsInstances = characters()
			for i = #nades, 1, -1 do
				local n = nades[i]
				G.step(n, math.min(dt, 1 / 20), params)
				if n.t <= 0 then table.remove(nades, i); explode(n) end
			end
		end
		for i = #smokes, 1, -1 do
			smokes[i].t -= dt
			if smokes[i].t <= 0 then table.remove(smokes, i) end
		end
		-- mines : armées après 1 s, explosent au passage d'un ennemi (1,5 m, écart de hauteur < 1,6 m)
		blink += dt
		local on = math.floor(blink * 2.5) % 2 == 1
		for _, m in ipairs(table.clone(mines)) do
			m.armT -= dt
			local led = m.model:FindFirstChild("Led") :: BasePart?
			if led then led.Color = if m.armT > 0 then Color3.fromRGB(102, 102, 102) elseif on then Color3.fromRGB(255, 42, 42) else Color3.fromRGB(85, 16, 16) end
			if m.owner == nil or (typeof(m.owner) == "Instance" and not m.owner.Parent) then removeMine(m, false)
			elseif m.armT <= 0 then
				for c in WS.eachCombatant() do
					local r = rootOf(c)
					if r and alive(c) and isFoeMine(m, c) then
						local d = Vector3.new(r.Position.X - m.pos.X, 0, r.Position.Z - m.pos.Z).Magnitude / M
						if d < G.MINE.trigger and math.abs(r.Position.Y - 3 - m.pos.Y) / M < G.MINE.dy then removeMine(m, true); break end
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		stocks[p] = nil
		for _, m in ipairs(table.clone(mines)) do if m.owner == p then removeMine(m, false) end end
	end)
end

return GrenadeService
