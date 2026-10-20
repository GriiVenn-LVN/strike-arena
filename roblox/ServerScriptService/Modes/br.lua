--!strict
-- Modes/br : Bataille royale (web : src/61_variants.js brInit / brUpdate / addLoot, src/8G_rounds.js durée, src/70_ai.js botGoal).
--   - Chacun pour soi, pas de réapparition : tout le monde commence au couteau, sans gilet ni bouclier ni grenade.
--   - Butin à usage unique réparti sur la carte (au moins 26 objets, 3 par joueur) : 70 % d'armes (4 paliers, meilleures
--     au centre), sinon gilet, bouclier, santé ou munitions. On ramasse en passant dessus.
--   - Zone de 64 m de rayon au centre ; 4 phases (attente puis réduction vers 44, 26, 12 puis 0 m) étirées pour se fermer
--     vers 80 % du chrono (5 min). Hors zone : dégâts chaque seconde (2, 4, 7, 12 selon la phase, + 1,5 par phase passée).
--   - Le dernier en vie gagne ; à la fin du chrono, le survivant le plus en forme (vie + gilet + bouclier).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Z = require(ReplicatedStorage.Shared.ZombieConfig)
local MapData = require(ReplicatedStorage.Shared.MapData) :: any
local WeaponService = require(script.Parent.Parent.WeaponService)

local U = Config.STUDS_PER_METER
local N = MapData.N
local PURPLE = Z.rgb(0xc77dff)
local M = {}
M.noPickups = true
local function MS(): any return require(script.Parent.Parent.MatchService) :: any end
local popEvent = ReplicatedStorage:FindFirstChild("ModePop") :: RemoteEvent?
if not popEvent then
	local e = Instance.new("RemoteEvent"); e.Name = "ModePop"; e.Parent = ReplicatedStorage; popEvent = e
end
local function isPlayer(c: any): boolean return typeof(c) == "Instance" and c:IsA("Player") end
local function tell(c: any, text: string, color: Color3?, sound: string?)
	if isPlayer(c) and popEvent then (popEvent :: RemoteEvent):FireClient(c, text, color, sound) end
end
local function lerp(a: number, b: number, t: number): number return a + (b - a) * t end

-- ---------- armes de chacun (principale p / pistolet s) ----------
local function arms(m: any, c: any): { p: string?, s: string? }
	local k = MS().keyOf(c)
	local a = m.data.arms[k]
	if not a then a = { p = nil, s = nil }; m.data.arms[k] = a end
	return a
end
local function equip(m: any, c: any, select: string?)
	local a = arms(m, c)
	local keys = {}
	if a.p then table.insert(keys, a.p) end
	if a.s then table.insert(keys, a.s) end
	table.insert(keys, "knife")
	WeaponService.setLoadoutKeep(c, keys, select)
end

-- ---------- butin ----------
local function aliveCombatants(m: any): { any }
	local l = {}
	for _, c in ipairs(MS().combatants(m)) do if MS().aliveChar(c) then table.insert(l, c) end end
	return l
end

local function lootPart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, transp: number): Part
	local p = Instance.new("Part"); p.Name = name; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Size = size; p.CFrame = cf; p.Color = color; p.Material = Enum.Material.Neon; p.Transparency = transp; p.Parent = parent
	return p
end

local useLoot: (any, any, any) -> boolean

local function addLoot(m: any, kind: string, key: string?, pos: Vector3)
	local model = Instance.new("Model"); model.Name = "Loot_" .. (key or kind)
	model:SetAttribute("LootKind", kind)
	local col: Color3
	local corePos = pos + Vector3.new(0, 0.9 * U, 0)
	if kind == "weapon" and key then
		col = Z.lootColor(Config.WEAPONS[key].cat)
		model:SetAttribute("LootKey", key)          -- le client y pose le vrai modèle de l'arme (ZombieBrHud)
		local core = lootPart(model, "Core", Vector3.new(0.3, 0.3, 0.3) * U, CFrame.new(corePos), col, 1)
		local l = Instance.new("PointLight"); l.Color = col; l.Range = 2.4 * U; l.Brightness = 1.2; l.Parent = core
		model.PrimaryPart = core
	else
		local vis = if kind == "armor" then "shield" else kind     -- le gilet a l'apparence du bouclier, comme sur le web
		col = if vis == "shield" then Z.rgb(0x31c8ff) elseif vis == "health" then Z.rgb(0xff4a5a) else Z.rgb(0xffd24a)
		local core: Part
		if vis == "shield" then
			core = lootPart(model, "Core", Vector3.new(0.4, 0.4, 0.4) * U, CFrame.new(corePos) * CFrame.Angles(math.rad(45), 0, math.rad(35.26)), col, 0.08)
		elseif vis == "health" then
			core = lootPart(model, "Core", Vector3.new(0.4, 0.4, 0.4) * U, CFrame.new(corePos), col, 0.08)
			lootPart(model, "CrossA", Vector3.new(0.5, 0.12, 0.12) * U, CFrame.new(corePos), Color3.new(1, 1, 1), 0)
			lootPart(model, "CrossB", Vector3.new(0.12, 0.5, 0.12) * U, CFrame.new(corePos), Color3.new(1, 1, 1), 0)
		else
			core = lootPart(model, "Core", Vector3.new(0.5, 0.28, 0.32) * U, CFrame.new(corePos), col, 0.08)
		end
		local l = Instance.new("PointLight"); l.Color = col; l.Range = 2.4 * U; l.Brightness = 1.6; l.Parent = core
		model.PrimaryPart = core
	end
	local ring = lootPart(model, "Ring", Vector3.new(0.04 * U, 1.3 * U, 1.3 * U), CFrame.new(pos + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)), col, 0.45)
	ring.Shape = Enum.PartType.Cylinder
	local zone = lootPart(model, "Zone", Vector3.new(2.6, 3, 2.6) * U, CFrame.new(pos + Vector3.new(0, 1.5 * U, 0)), col, 1)
	zone.CanTouch = true
	model.Parent = m.data.folder
	local item = { kind = kind, key = key, pos = pos, model = model }
	table.insert(m.data.loot, item)
	zone.Touched:Connect(function(hit: BasePart)
		if not model.Parent or m.state ~= "live" then return end
		local mm = hit:FindFirstAncestorOfClass("Model")
		local hum = mm and mm:FindFirstChildOfClass("Humanoid")
		if not mm or not hum or hum.Health <= 0 then return end
		local c = WeaponService.combatantOf(mm)
		if MS().matchOf(c) ~= m then return end
		if useLoot(m, c, item) then
			model:Destroy()
			local i = table.find(m.data.loot, item); if i then table.remove(m.data.loot, i) end
		end
	end)
end

useLoot = function(m: any, c: any, item: any): boolean
	local ch = WeaponService.charOf(c)
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if not hum then return false end
	local k = item.kind
	if k == "shield" then
		if WeaponService.shieldOf(c) >= Config.SHIELD_MAX then return false end
		WeaponService.addShield(c, 25); tell(c, "+25 bouclier", Z.rgb(0x31c8ff), "pickup")
	elseif k == "health" then
		if hum.Health >= 100 then return false end
		hum.Health = math.min(math.max(100, hum.MaxHealth), hum.Health + 35); tell(c, "+35 santé", Z.rgb(0xff4a5a), "heal")
	elseif k == "ammo" then
		for _, w in ipairs(WeaponService.loadoutOf(c)) do
			local def = Config.WEAPONS[w]
			if def and not def.melee then
				local _, res = WeaponService.ammoOf(c, w)
				WeaponService.setAmmo(c, w, WeaponService.magOf(c, w), math.max(res, def.reserve))
			end
		end
		tell(c, "Munitions", Z.rgb(0xffd24a), "pickup")
	elseif k == "armor" then
		if WeaponService.armorOf(c) >= 100 then return false end
		WeaponService.setArmor(c, 100); tell(c, "Gilet récupéré", Z.rgb(0x31c8ff), "pickup")
	elseif k == "weapon" and item.key then
		local a = arms(m, c)
		local slot = if Config.WEAPONS[item.key].slot == 1 then "s" else "p"
		if (a :: any)[slot] == item.key then return false end
		if slot == "p" then a.p = nil else a.s = nil end
		equip(m, c, nil)                          -- l'ancienne arme de cet emplacement est jetée
		if slot == "p" then a.p = item.key else a.s = item.key end
		equip(m, c, item.key)
		tell(c, "Arme : " .. Config.WEAPONS[item.key].name, Z.lootColor(Config.WEAPONS[item.key].cat), "pickup")
	else
		return false
	end
	return true
end

local function placeLoot(m: any)
	local g = m.map.grid or MapData.buildGrid(m.settings.map)
	local cells = {}
	for cz = 2, N - 3 do for cx = 2, N - 3 do
		local i = cz * N + cx
		if g.type[i] == 0 and g.ramp[i] == 0 then table.insert(cells, { cx, cz }) end
	end end
	for i = #cells, 2, -1 do local j = math.random(i); cells[i], cells[j] = cells[j], cells[i] end
	local want = math.max(26, #MS().combatants(m) * 3, m.settings.size * 3)
	local placed, taken = 0, {} :: { { number } }
	for _, c in ipairs(cells) do
		if placed >= want then break end
		local near = false
		for _, t in ipairs(taken) do if math.sqrt((t[1] - c[1]) ^ 2 + (t[2] - c[2]) ^ 2) < 3.2 then near = true; break end end
		if not near then
			table.insert(taken, c)
			local dc = math.sqrt((c[1] - 20) ^ 2 + (c[2] - 20) ^ 2) / 28
			local r = math.random()
			local kind, key = "weapon", nil :: string?
			if r < 0.7 then
				local tr = if r < 0.3 then 1 elseif r < 0.52 then 2 elseif r < 0.66 then 3 else 4
				local tier = Z.BR_TIERS[math.min(4, tr + (if dc < 0.5 and math.random() < 0.4 then 1 else 0))]
				key = tier[math.random(#tier)]
			else
				kind = ({ "armor", "shield", "health", "ammo" })[math.random(4)]
			end
			addLoot(m, kind, key, MS().cellToWorld(m, c[1], c[2]))
			placed += 1
		end
	end
end

-- ---------- zone ----------
local function zoneWorld(m: any): (Vector3, number)
	local z = m.data.zone
	return m.origin + Vector3.new(z.cx * U, 0, z.cz * U), z.r * U
end

function M.setup(m: any)
	m.limit = nil
	m.data.arms = {}
	m.data.loot = {}
	m.data.phases = Z.brPhases(Z.BR_TIME)
	m.data.zone = { phase = 1, state = "wait", t = 0, wait = m.data.phases[1].wait, r = Z.BR_START_R, from = Z.BR_START_R, to = Z.BR_START_R,
		cx = 40, cz = 40, fx = 40, fz = 40, tx = 40, tz = 40, dmg = 2, tick = 0, done = false }
	local f = Instance.new("Folder"); f.Name = "BattleRoyale"; f.Parent = m.map.folder
	m.data.folder = f
	m.data.warned = false
end
function M.start(m: any)
	m.timed = true
	m.endsAt = os.clock() + Z.BR_TIME
	m.data.started = true
	placeLoot(m)
	MS().announce(m, "BATAILLE ROYALE", "Ramasse une arme, reste dans la zone — " .. math.floor(Z.BR_TIME / 60) .. " min", PURPLE)
end
function M.loadout(_m: any, _c: any): { string }? return { "knife" } end
function M.onSpawn(m: any, c: any, char: Model)
	local a = arms(m, c); a.p = nil; a.s = nil
	task.defer(function()
		if not char.Parent then return end
		WeaponService.giveGrenades(c, 0, 0, 0)
		WeaponService.setArmor(c, 0)
		local sh = WeaponService.shieldOf(c)
		if sh > 0 then WeaponService.addShield(c, -sh) end
	end)
end
function M.botsWanted(m: any, _team: string?, want: number): number?
	if m.state == "live" then return nil end       -- personne ne réapparaît : on ne remplace pas les éliminés
	return want
end
function M.botRespawn(_m: any, _s: any): boolean return false end
function M.canRespawn(_m: any, _c: any): boolean return false end

function M.tick(m: any, dt: number)
	local z = m.data.zone
	local ph = m.data.phases[math.min(z.phase, #m.data.phases)]
	if z.state == "wait" then
		z.wait -= dt
		if z.wait <= 0 then
			z.state = "shrink"; z.t = ph.shrink; z.from = z.r; z.to = ph.r
			local a = math.random() * math.pi * 2
			local d = if ph.r > 0 then math.random() * math.max(0, z.r - ph.r) * 0.6 else 0
			z.tx = math.clamp(z.cx + math.cos(a) * d, 20, 60); z.tz = math.clamp(z.cz + math.sin(a) * d, 20, 60)
			z.fx = z.cx; z.fz = z.cz
			for p in pairs(m.players) do tell(p, "La zone se réduit !", Z.ZONE_COLOR, "beep") end
		end
	elseif z.state == "shrink" then
		z.t -= dt
		local k = 1 - math.max(0, z.t) / ph.shrink
		z.r = lerp(z.from, z.to, k); z.cx = lerp(z.fx, z.tx, k); z.cz = lerp(z.fz, z.tz, k); z.dmg = ph.dmg
		if z.t <= 0 then
			z.phase += 1
			if z.phase > #m.data.phases then z.state = "final" else z.state = "wait"; z.wait = m.data.phases[z.phase].wait end
		end
	end
	-- dégâts hors zone, une fois par seconde
	z.tick += dt
	if z.tick >= 1 then
		z.tick -= 1
		local center, r = zoneWorld(m)
		for _, c in ipairs(aliveCombatants(m)) do
			local ch = WeaponService.charOf(c)
			local root = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
			if ch and root and Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z).Magnitude > r + 0.5 * U then
				WeaponService.applyDamage(nil, ch, z.dmg + (z.phase - 1) * 1.5, false, "Zone", 1)
			end
		end
	end
	if not m.data.warned and m.endsAt - os.clock() <= 60 then
		m.data.warned = true
		for p in pairs(m.players) do tell(p, "Plus qu'une minute !", Z.rgb(0xff6b6b), "beep") end
	end
	-- objets : petite rotation
	local t = os.clock()
	for _, it in ipairs(m.data.loot) do
		local core = it.model.PrimaryPart
		if core then core.CFrame = CFrame.new(it.pos + Vector3.new(0, (0.9 + math.sin(t * 2 + it.pos.X) * 0.1) * U, 0)) * CFrame.Angles(0, t * 1.6, 0) * (if it.kind == "shield" or it.kind == "armor" then CFrame.Angles(math.rad(45), 0, math.rad(35.26)) else CFrame.identity) end
	end
	-- ligne personnelle : en vie / éliminations
	local alive = #aliveCombatants(m)
	for p in pairs(m.players) do
		local s = m.stats[p]
		p:SetAttribute("ModeLine", "🌀 " .. alive .. " EN VIE   ·   " .. (if s then s.k else 0) .. " ÉLIMINATION" .. (if s and s.k > 1 then "S" else ""))
	end
	m.data.alive = alive
end

local function winnerStat(m: any, c: any): any return if c then m.stats[MS().keyOf(c)] else nil end
function M.checkEnd(m: any): (boolean, any)
	if not m.data.started then return false, nil end
	local alive = aliveCombatants(m)
	if #alive <= 1 then return true, winnerStat(m, alive[1]) end
	return false, nil
end
function M.timeUp(m: any): any
	local best, bs = nil, -1
	for _, c in ipairs(aliveCombatants(m)) do
		local h = (MS().aliveChar(c) :: Model):FindFirstChildOfClass("Humanoid")
		local s = (if h then h.Health else 0) + WeaponService.armorOf(c) + WeaponService.shieldOf(c)
		if s > bs then bs = s; best = c end
	end
	for p in pairs(m.players) do tell(p, "Temps écoulé !", Z.rgb(0xff6b6b), "beep") end
	return winnerStat(m, best)
end

-- bots : rentrer dans la zone, prendre une arme, puis gilet / soins (botGoal du web)
function M.botGoal(m: any, bot: Model): Vector3?
	local root = bot:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return nil end
	local center, r = zoneWorld(m)
	if Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z).Magnitude > r - 5 * U then
		return center + Vector3.new((math.random() - 0.5) * 6 * U, 3, (math.random() - 0.5) * 6 * U)
	end
	local a = arms(m, bot)
	local function nearest(ok: (any) -> boolean, maxD: number): Vector3?
		local best, bd = nil, maxD * U
		for _, it in ipairs(m.data.loot) do
			if ok(it) then
				local d = (it.pos - root.Position).Magnitude
				if d < bd then best, bd = it.pos, d end
			end
		end
		return best
	end
	if not a.p then
		local p = nearest(function(it) return it.kind == "weapon" end, 70)
		if p then return p end
	end
	local hum = bot:FindFirstChildOfClass("Humanoid")
	if WeaponService.armorOf(bot) < 1 or (hum and hum.Health < 60) then
		local p = nearest(function(it) return it.kind ~= "weapon" and it.kind ~= "ammo" end, 40)
		if p then return p end
	end
	return nil
end

function M.info(m: any): any
	local z = m.data.zone
	if not z then return nil end
	local center, r = zoneWorld(m)
	local label, tt
	if z.state == "wait" then label, tt = "ZONE STABLE", z.wait
	elseif z.state == "shrink" then label, tt = "LA ZONE SE RÉDUIT", z.t
	else label, tt = "ZONE FINALE", 0 end
	local alive = m.data.alive or #aliveCombatants(m)
	m.data.public = { br = { x = center.X, z = center.Z, r = r, state = z.state, label = label, t = math.max(0, math.ceil(tt)), phase = z.phase, alive = alive,
		dmg = z.dmg + (z.phase - 1) * 1.5 } }
	return {
		line = "🌀 " .. alive .. " EN VIE",
		sub = label .. (if z.state ~= "final" then "  " .. string.format("%d:%02d", math.floor(math.ceil(tt) / 60), math.ceil(tt) % 60) else ""),
		subWarn = z.state == "shrink",
		color = Z.ZONE_COLOR, kind = "br",
	}
end

function M.onLeave(_m: any, p: Player) p:SetAttribute("ModeLine", nil) end
function M.cleanup(m: any)
	for p in pairs(m.players) do p:SetAttribute("ModeLine", nil) end
	if m.data.folder then m.data.folder:Destroy() end
	m.data.loot = {}
	m.data.started = false
end
return M
