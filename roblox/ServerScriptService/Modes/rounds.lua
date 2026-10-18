--!strict
-- Modes/rounds : moteur commun des modes à manches du web (src/60_game.js resetRound / endRound / afterEnd, bombe,
-- boutique ; src/8Zc_eco.js économie ; src/8G_rounds.js mi-temps ; src/61_variants.js Désamorçage rapide ;
-- src/8B_duel.js Duel). Ce n'est pas un mode : bomb.lua, rapid.lua et duel.lua appellent Rounds.make(variante).
--
-- Une manche : phase d'achat figée (20 s / 10 s / 6 s), puis la manche (100 s / 45 s / 60 s), sans réapparition.
-- Bombe (Compétitif, Désamorçage rapide) : un attaquant au hasard la porte ; il la pose sur un site (maintenir E, 3,2 s),
-- elle explose 40 s plus tard ; un défenseur la désamorce (maintenir E à côté, 5 s, 2,5 s avec le kit).
-- Les attaquants gagnent si la bombe explose ou si tous les défenseurs sont éliminés ; les défenseurs gagnent si la
-- bombe est désamorcée, si tous les attaquants sont éliminés avant la pose, ou à la fin du temps.
-- Économie façon Valorant (réglage « Économie réaliste », par défaut) : 800 au départ, 3000 par manche gagnée,
-- 1900 / 2400 / 2900 par défaites d'affilée, 200 par élimination, 300 à chaque attaquant quand la bombe est posée,
-- plafond 9000. Mi-temps : changement de camp, retour à 800 et manche au pistolet. « Armes libres » : tout est gratuit.
-- Les survivants gardent leur équipement à la manche suivante.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local ModeConfig = require(ReplicatedStorage.Shared.ModeConfig)
local Modes = require(ReplicatedStorage.Shared.Modes)
local WeaponService = require(script.Parent.Parent.WeaponService)
local BotService = require(script.Parent.Parent.BotService)
local O = require(script.Parent.objutil)
local GrenadeService = require(script.Parent.Parent.GrenadeService)
local Grenades = require(ReplicatedStorage.Shared.Grenades)

local U = O.U
local T, CT = O.T, O.CT
local ECO = { start = 800, win = 3000, loss = { 1900, 2400, 2900 }, kill = 200, plant = 300, defuse = 0, max = 9000 }
local PLANT_T, DEFUSE_T, BOMB_T, END_T = 3.2, 5, 40, 5.5
local PICK_R, DEFUSE_R = 1.4 * U, 1.8 * U
local REVEAL = 20
local GOLD, PINK = Color3.fromRGB(255, 215, 94), Color3.fromRGB(255, 122, 217)

local VARIANTS = {
	bomb = { round = 100, freeze = 20, bomb = true, half = true },
	rapid = { round = 45, freeze = 10, bomb = true, half = true },
	duel = { round = 60, freeze = 6, bomb = false, half = false },
}

local ITEM_PRICE: { [string]: number } = {}
for _, it in ipairs(Modes.BUY_ITEMS) do ITEM_PRICE[it.k] = it.price end
local BUYABLE: { [string]: boolean } = {}
for _, cat in ipairs(Modes.BUY_CATS) do for _, k in ipairs(cat.list) do BUYABLE[k] = true end end
local PRIMARIES: { string } = {}
for _, cat in ipairs(Modes.BUY_CATS) do for _, k in ipairs(cat.list) do if Config.WEAPONS[k].slot == 0 then table.insert(PRIMARIES, k) end end end

type Inv = { money: number, primary: string?, secondary: string, armor: number, shield: number, kit: boolean,
	frag: number, flash: number, smoke: number, mine: number, keep: boolean }

local function MS(): any return O.MS() end
local function now(): number return os.clock() end
local function pistolOf(team: string?): string return if team == T then "glock" else "usp" end
local function shuffle<V>(l: { V }): { V }
	for i = #l, 2, -1 do local j = math.random(i); l[i], l[j] = l[j], l[i] end
	return l
end
local function setAttr(inst: Instance, name: string, v: any)
	if inst:GetAttribute(name) ~= v then inst:SetAttribute(name, v) end
end

local Rounds = {}

-- ---------- remotes (boutique, touche E) ; les grenades et les mines passent par GrenadeService ----------
local function remote(class: string, name: string): Instance
	local r = ReplicatedStorage:FindFirstChild(name)
	if not r then r = Instance.new(class); r.Name = name; r.Parent = ReplicatedStorage end
	return r :: Instance
end
local buyFn = remote("RemoteFunction", "ModeBuy") :: RemoteFunction
local useEv = remote("RemoteEvent", "ModeUse") :: RemoteEvent
buyFn.OnServerInvoke = function(p: Player, key: any)
	local m = MS().matchOf(p)
	if m and m.mod and m.mod.buy then return m.mod.buy(m, p, if typeof(key) == "string" then key else nil) end
	return nil
end
useEv.OnServerEvent:Connect(function(p: Player, on: any)
	local m = MS().matchOf(p)
	if m and m.mod and m.mod.useKey then m.mod.useKey(m, p, on == true) end
end)

function Rounds.make(variant: string): any
	local V = VARIANTS[variant]
	local M: any = {}
	M.noPickups = true      -- web : pas d'objets à ramasser dans les modes à bombe (setupPickups seulement hors « bomb »)

	local function ecoOn(m: any): boolean return m.settings.eco == 1 and variant ~= "rapid" and variant ~= "duel" end
	local function cap(m: any): number return if ecoOn(m) then ECO.max else 16000 end
	local function free(m: any): boolean return m.settings.eco ~= 1 end
	local function startMoney(m: any): number return if m.settings.eco == 1 and variant == "bomb" then ECO.start else 16000 end

	-- ---------- inventaire (argent, armes, gilet, bouclier, kit, grenades) de chaque combattant ----------
	local function invOf(m: any, key: any, team: string?): Inv
		local inv = m.data.inv[key]
		if not inv then
			inv = { money = startMoney(m), primary = nil, secondary = pistolOf(team), armor = 0, shield = 0, kit = false,
				frag = 0, flash = 0, smoke = 0, mine = 0, keep = false }
			m.data.inv[key] = inv
		end
		return inv
	end
	local function inv(m: any, c: any): Inv return invOf(m, MS().keyOf(c), WeaponService.teamOf(c)) end
	local function listOf(i: Inv): { string }
		local l = {}
		if i.primary then table.insert(l, i.primary) end
		table.insert(l, i.secondary)
		table.insert(l, "knife")
		return l
	end
	local function syncMoney(m: any, p: Player)
		local i = m.data.inv[p]
		setAttr(p, "Money", if i then i.money else nil)
	end
	local function applyGear(c: any, i: Inv)
		WeaponService.setArmor(c, i.armor)
		WeaponService.setShield(c, i.shield)
	end
	-- grenades et mines : le stock vit dans GrenadeService (lancers, compteur « Nades »), l'inventaire le garde entre deux manches
	local function stockOf(c: any): { frag: number, flash: number, smoke: number, mine: number }
		local s = GrenadeService.get(c)
		return if s then s else { frag = 0, flash = 0, smoke = 0, mine = 0 }
	end
	local function applyNades(c: any, i: Inv)
		WeaponService.giveGrenades(c, i.smoke, i.flash, i.frag, i.mine)    -- remplace l'équipement de départ du match à mort
	end

	-- membres de la partie (joueurs + bots de l'effectif, même morts) : { key, team, c? }
	local function members(m: any): { { key: any, team: string, c: any } }
		local l = {}
		for p in pairs(m.players) do table.insert(l, { key = p, team = WeaponService.teamOf(p) or T, c = p }) end
		local models: { [string]: Model } = {}
		for _, b in ipairs(BotService.ofMatch(m.id)) do models[b.Name] = b end
		for _, team in ipairs({ T, CT }) do
			for _, n in ipairs(m.data.roster[team]) do table.insert(l, { key = "bot:" .. n, team = team, c = models[n] }) end
		end
		return l
	end

	local function freezeHum(c: any, on: boolean)
		local ch = WeaponService.charOf(c)
		local h = ch and ch:FindFirstChildOfClass("Humanoid")
		if not h then return end
		if O.isPlayer(c) then
			h.WalkSpeed = if on then 0 else 16
			h.JumpPower = if on then 0 else 50; h.JumpHeight = if on then 0 else 7.2
		end
	end

	-- ---------- bombe ----------
	local function bombModel(m: any): Model
		local b = m.data.bombModel
		if b then return b end
		local model = Instance.new("Model"); model.Name = "Bomb"
		local body = O.part(model, "Body", Vector3.new(0.5, 0.14, 0.32) * U, CFrame.new(0, 0.07 * U, 0), Color3.fromRGB(42, 45, 51), 0, nil, Enum.Material.Metal)
		O.part(model, "Screen", Vector3.new(0.18, 0.05, 0.07) * U, CFrame.new(0, 0.145 * U, 0), Color3.fromRGB(255, 32, 32), 0)
		for i = 0, 2 do
			O.part(model, "Tube", Vector3.new(0.28, 0.06, 0.06) * U, CFrame.new((-0.15 + i * 0.15) * U, 0.18 * U, 0) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(184, 69, 42), 0, Enum.PartType.Cylinder, Enum.Material.SmoothPlastic)
		end
		local light = Instance.new("PointLight"); light.Name = "Glow"; light.Color = Color3.fromRGB(255, 48, 48); light.Range = 2 * U; light.Brightness = 2; light.Parent = body
		body.PivotOffset = CFrame.new(0, -0.07 * U, 0)
		model.PrimaryPart = body
		m.data.bombModel = model
		return model
	end
	local function showBomb(m: any, at: Vector3?)
		local model = bombModel(m)
		if at then
			O.release(model, CFrame.new(at))
			model.Parent = m.map.folder
		else
			model.Parent = nil
		end
	end
	local function bombState(m: any, st: string)
		local b = m.data.bomb
		b.state = st
		local model = bombModel(m)
		model:SetAttribute("State", st)
	end
	local function dropBomb(m: any, at: Vector3?)
		local b = m.data.bomb
		if b.state ~= "carried" then return end
		local c = b.carrier
		local r = c and O.root(c)
		local pos = at or (r and O.feet(r)) or b.lastPos or m.data.sites[1].pos
		b.carrier = nil
		if typeof(c) == "Instance" and c:IsA("Model") then c:SetAttribute("Busy", nil) end
		local ch = c and WeaponService.charOf(c)
		if ch then ch:SetAttribute("HasBomb", nil) end
		b.pos = O.groundBelow(m, pos)
		bombState(m, "dropped")
		showBomb(m, b.pos)
		for p in pairs(m.players) do
			if WeaponService.teamOf(p) == T then O.pop(p, "BOMBE LÂCHÉE", Color3.fromRGB(255, 185, 56), "click") end
		end
	end
	local function giveBomb(m: any, c: any)
		local b = m.data.bomb
		b.carrier = c; b.prog = 0
		bombState(m, "carried")
		local model = bombModel(m)
		local ch = WeaponService.charOf(c)
		if ch then ch:SetAttribute("HasBomb", true) end
		model.Parent = m.map.folder
		O.carry(model, c, CFrame.new(0, 0.2 * U, 0.42 * U) * CFrame.Angles(math.rad(90), 0, 0))
		if O.isPlayer(c) then O.pop(c, "TU AS LA BOMBE — POSE-LA SUR UN SITE (E)", Color3.fromRGB(255, 185, 56), "pickup") end
	end
	local function siteAt(m: any, pos: Vector3): any
		for _, s in ipairs(m.data.sites) do
			if O.flat(pos, s.pos) < s.r and math.abs(pos.Y - s.pos.Y) < 3.5 * U then return s end
		end
		return nil
	end

	-- ---------- fin de manche ----------
	local function teamWord(team: string): string return if team == T then "ATTAQUANTS" else "DÉFENSEURS" end
	local function endRound(m: any, win: string, reason: string)
		local d = m.data
		if d.phase ~= "live" then return end
		if variant == "duel" and reason == "Temps écoulé" then
			-- départage du duel : le plus de survivants, puis le plus de points de vie
			local al, hp = { [T] = 0, [CT] = 0 }, { [T] = 0, [CT] = 0 }
			for _, c in ipairs(O.alive(m)) do
				local team = WeaponService.teamOf(c) :: string
				local ch = MS().aliveChar(c)
				local h = ch and ch:FindFirstChildOfClass("Humanoid")
				al[team] = (al[team] or 0) + 1; hp[team] = (hp[team] or 0) + (if h then h.Health else 0)
			end
			if al[T] ~= al[CT] then win = if al[T] > al[CT] then T else CT
			elseif hp[T] ~= hp[CT] then win = if hp[T] > hp[CT] then T else CT
			else win = if math.random() < 0.5 then T else CT end
			reason = "Temps écoulé — " .. (if al[T] ~= al[CT] then "plus de survivants" else "plus de points de vie")
		end
		d.phase = "end"; d.phaseEnd = now() + END_T; m.endsAt = d.phaseEnd
		m.score[win] = (m.score[win] or 0) + 1
		d.lastWin, d.lastReason = win, reason
		local lose = O.other(win)
		for _, e in ipairs(members(m)) do
			local i = invOf(m, e.key, e.team)
			local bonus = if e.team == win then ECO.win else ECO.loss[math.min(#ECO.loss, d.loss[e.team] + 1)]
			if m.settings.eco == 1 then i.money = math.min(cap(m), i.money + bonus) end
			-- les survivants gardent leur équipement (web : e.keep)
			i.keep = e.c ~= nil and MS().aliveChar(e.c) ~= nil
			if i.keep then
				i.armor = WeaponService.armorOf(e.c); i.shield = WeaponService.shieldOf(e.c)
				local s = stockOf(e.c); i.frag, i.flash, i.smoke, i.mine = s.frag, s.flash, s.smoke, s.mine
			end
			if O.isPlayer(e.c) then syncMoney(m, e.c) end
		end
		d.loss[win] = 0; d.loss[lose] += 1
		for _, b in ipairs(BotService.ofMatch(m.id)) do b:SetAttribute("Busy", nil) end
		WeaponService.clearGrenades(m.id)     -- plus de mines au sol pour la manche suivante
		for p in pairs(m.players) do
			local mine = WeaponService.teamOf(p) == win
			local r = reason
			if variant == "duel" and string.find(reason, "Temps écoulé", 1, true) ~= 1 then r = if mine then "Adversaire éliminé" else "Ton équipe est éliminée" end
			MS().announce(m, if mine then "MANCHE GAGNÉE" else "MANCHE PERDUE", r, if mine then O.GOOD else O.BAD, p)
			setAttr(p, "UseProg", nil); setAttr(p, "UseMsg", nil); setAttr(p, "UseHint", nil)
		end
	end

	local function checkAlive(m: any)
		if m.data.phase ~= "live" then return end
		local aT, aC = #O.alive(m, T), #O.alive(m, CT)
		if m.data.bomb.state == "planted" then
			if aC == 0 then endRound(m, T, "Défenseurs éliminés") end
		elseif aT == 0 then endRound(m, CT, "Attaquants éliminés")
		elseif aC == 0 then endRound(m, T, "Défenseurs éliminés") end
	end

	-- ---------- achats ----------
	local function buyState(m: any, p: Player): any
		local i = inv(m, p)
		local d = m.data
		return { money = i.money, free = free(m), pistol = d.pistol, phase = d.phase, team = WeaponService.teamOf(p), bombMode = V.bomb,
			primary = i.primary, secondary = i.secondary, armor = i.armor, shield = i.shield, kit = i.kit, frag = stockOf(p).frag, flash = stockOf(p).flash, smoke = stockOf(p).smoke, mine = stockOf(p).mine,
			left = math.max(0, math.floor(d.phaseEnd - now())) }
	end
	local function doBuy(m: any, c: any, k: string): (boolean, string?)
		local d = m.data
		if d.phase ~= "freeze" then return false, "Achats possibles seulement en début de manche" end
		local i = inv(m, c)
		local team = WeaponService.teamOf(c)
		local function pay(pr: number): boolean
			if free(m) then return true end
			if i.money < pr then return false end
			i.money -= pr
			return true
		end
		if k == "armor" then
			if i.armor >= 100 or not pay(ITEM_PRICE.armor) then return false, nil end
			i.armor = 100; WeaponService.setArmor(c, 100); return true, nil
		elseif k == "shield1" then
			if i.shield >= 25 or not pay(ITEM_PRICE.shield1) then return false, nil end
			i.shield = 25; WeaponService.setShield(c, 25); return true, nil
		elseif k == "shield2" then
			if i.shield >= 50 or not pay(ITEM_PRICE.shield2) then return false, nil end
			i.shield = 50; WeaponService.setShield(c, 50); return true, nil
		elseif k == "kit" then
			if team ~= CT or i.kit or not V.bomb or not pay(ITEM_PRICE.kit) then return false, nil end
			i.kit = true; return true, nil
		elseif k == "frag" or k == "flash" or k == "smoke" or k == "mine" then
			-- limites du web : 1 frag, 2 flashs, 1 fumigène, 2 mines
			local s = table.clone(stockOf(c)) :: any
			local max = if k == "flash" then 2 elseif k == "mine" then Grenades.MINE.max else 1
			if (s[k] or 0) >= max or not pay(ITEM_PRICE[k]) then return false, nil end
			s[k] = (s[k] or 0) + 1
			GrenadeService.set(c, s.frag, s.flash, s.smoke, s.mine)
			local ii = i :: any; ii[k] = s[k]
			return true, nil
		end
		local w = Config.WEAPONS[k]
		if not w or not BUYABLE[k] then return false, nil end
		if d.pistol and w.slot == 0 then return false, "Manche au pistolet : pistolets uniquement" end
		if (w.slot == 0 and i.primary == k) or (w.slot == 1 and i.secondary == k) then return false, nil end
		if not pay(w.price) then return false, nil end
		if w.slot == 0 then i.primary = k else i.secondary = k end
		if MS().aliveChar(c) then
			WeaponService.giveLoadout(c, listOf(i))
			applyGear(c, i)
		end
		return true, nil
	end
	function M.buy(m: any, p: Player, k: string?): any
		if not m.data.inv then return nil end
		local ok, msg = true, nil
		if k then ok, msg = doBuy(m, p, k); syncMoney(m, p) end
		local st = buyState(m, p)
		st.ok = ok; st.msg = msg
		return st
	end

	-- achats d'un bot (botBuy du web)
	local function botBuy(m: any, b: Model)
		if m.data.phase ~= "freeze" or not b.Parent then return end
		local i = inv(m, b)
		local function try(k: string) doBuy(m, b, k) end
		local aff = {}
		for _, k in ipairs(PRIMARIES) do if Config.WEAPONS[k].price <= i.money or free(m) then table.insert(aff, k) end end
		if not i.primary and #aff > 0 and not (m.settings.eco == 1 and i.money < 1800 and math.random() < 0.5) then
			local wt = { rifle = 5, smg = 2.4, sniper = 1, shotgun = 1, lmg = 0.5 }
			local tot, ws = 0, {}
			for _, k in ipairs(aff) do
				local w = if m.settings.diff <= 2 then 1 else (wt[Config.WEAPONS[k].cat] or 1) * (if k == "awp" then 0.8 else 1)
				table.insert(ws, w); tot += w
			end
			local r, ch = math.random() * tot, aff[1]
			for n, k in ipairs(aff) do r -= ws[n]; if r <= 0 then ch = k; break end end
			try(ch)
		elseif not i.primary and i.money >= 700 and math.random() < 0.5 then
			local l = { "p250", "fiveseven", "deagle" }; try(l[math.random(#l)])
		end
		if i.armor < 100 and i.money >= 650 and math.random() < 0.85 then try("armor") end
		if i.money >= 1000 and math.random() < 0.35 then try("shield2") elseif i.money >= 400 and math.random() < 0.4 then try("shield1") end
		if WeaponService.teamOf(b) == CT and i.money >= 400 and math.random() < 0.6 then try("kit") end
		if i.money >= 300 and math.random() < 0.55 then try("frag") end
		if i.money >= 300 and math.random() < 0.3 then try("smoke") end
		if i.money >= 200 and math.random() < 0.3 then try("flash") end
		if i.money >= ITEM_PRICE.mine and math.random() < 0.25 then try("mine") end
	end

	-- ---------- début de manche ----------
	local function botName(m: any): string
		local used = {}
		for _, team in ipairs({ T, CT }) do for _, n in ipairs(m.data.roster[team]) do used[n] = true end end
		local pool = shuffle(table.clone(ModeConfig.BOT.names))
		for _, n in ipairs(pool) do if not used[n] then return n end end
		local n = pool[1] .. " " .. math.random(10, 99)
		while used[n] do n = pool[1] .. " " .. math.random(10, 99) end
		return n
	end
	local function spawnRoster(m: any)
		for _, b in ipairs(BotService.ofMatch(m.id)) do BotService.remove(b) end
		for _, team in ipairs({ T, CT }) do
			local humans = 0
			for p in pairs(m.players) do if WeaponService.teamOf(p) == team then humans += 1 end end
			local want = if m.mod.noBots then 0 else math.max(0, m.settings.size - humans)
			local list = m.data.roster[team]
			while #list > want do
				local n = table.remove(list) :: string
				m.stats["bot:" .. n] = nil; m.data.inv["bot:" .. n] = nil
			end
			while #list < want do table.insert(list, botName(m)) end
			for _, n in ipairs(list) do
				local model = MS().spawnBot(m, team, n)
				MS().setTeam(m, model, team)
			end
		end
		BotService.freezeMatch(m.id, m.data.phase ~= "live")
	end

	-- postes des bots : attaquants autour du site prévu, défenseurs sur leurs positions de garde (plans du web)
	local function placeBots(m: any)
		local d = m.data
		d.hold = {}
		local site = d.sites[d.plan]
		local holdCT = m.map.data.holdCT or {}
		local ci = 0
		for _, b in ipairs(BotService.ofMatch(m.id)) do
			local key = "bot:" .. b.Name
			if b:GetAttribute("Team") == T then
				local a, r = math.random() * math.pi * 2, (2.5 * U) + math.random() * math.max(1, site.r - 3 * U)
				d.hold[key] = O.ground(m, site.pos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
			elseif #holdCT > 0 then
				ci += 1
				local h = holdCT[(ci - 1) % #holdCT + 1]
				local cx, cz = O.spot(m, h[1], h[2])
				d.hold[key] = O.ground(m, MS().cellToWorld(m, cx, cz))
			else
				ci += 1
				local s = d.sites[(ci - 1) % #d.sites + 1]
				d.hold[key] = s.pos
			end
		end
	end

	local function resetRound(m: any)
		local d = m.data
		d.round += 1
		d.pistol = variant ~= "duel" and (d.round == 1 or d.halfPistol)
		d.halfPistol = false
		d.phase = "freeze"; d.phaseEnd = now() + V.freeze; m.endsAt = d.phaseEnd
		d.revealed = false; d.use = {}; d.retake = {}; d.roam = {}
		local b = d.bomb
		b.carrier = nil; b.prog = 0; b.defProg = {}; b.pos = nil; b.site = nil; b.explodeAt = nil
		bombState(m, if V.bomb then "carried" else "none")
		showBomb(m, nil)
		-- inventaire de la manche (web : resetRound, Duel : armes du profil, gilet)
		for _, e in ipairs(members(m)) do
			local i = invOf(m, e.key, e.team)
			if not i.keep then
				i.armor = 0; i.shield = 0; i.kit = false; i.frag = 0; i.flash = 0; i.smoke = 0; i.mine = 0
				i.primary = nil; i.secondary = pistolOf(e.team)
				local p = if O.isPlayer(e.c) then e.c :: Player else nil
				local prim = p and p:GetAttribute("Primary")
				local sec = p and p:GetAttribute("Secondary")
				if variant == "duel" then
					if p then
						if typeof(prim) == "string" and Config.WEAPONS[prim] then i.primary = prim end
						if typeof(sec) == "string" and Config.WEAPONS[sec] then i.secondary = sec end
					end
					i.armor = 100
				elseif p then
					if not free(m) then
						if typeof(sec) == "string" and Config.WEAPONS[sec] and Config.WEAPONS[sec].price <= 300 then i.secondary = sec end
					else
						if typeof(prim) == "string" and Config.WEAPONS[prim] and not d.pistol then i.primary = prim end
						if typeof(sec) == "string" and Config.WEAPONS[sec] then i.secondary = sec end
						i.armor = 100
					end
				end
			end
			if free(m) or variant == "duel" then i.money = 16000 end
			i.keep = false
		end
		-- points d'apparition : chaque équipe à son départ, une place chacun
		d.spawnQ = {}
		for _, team in ipairs({ T, CT }) do d.spawnQ[team] = shuffle(table.clone(if team == T then m.map.spawns.T else m.map.spawns.CT)) end
		d.plan = math.random(#d.sites)
		for p in pairs(m.players) do MS().respawn(m, p); syncMoney(m, p) end
		spawnRoster(m)
		placeBots(m)
		-- la bombe : un attaquant au hasard
		if V.bomb then
			local ts = {}
			for _, e in ipairs(members(m)) do if e.team == T then table.insert(ts, e) end end
			d.bombFor = if #ts > 0 then ts[math.random(#ts)].key else nil
		end
		-- les bots font leurs achats pendant la phase d'achat
		local round = d.round
		for _, bot in ipairs(BotService.ofMatch(m.id)) do
			task.delay(0.5 + math.random() * math.min(3.5, V.freeze - 1), function()
				if d.round == round and d.phase == "freeze" then botBuy(m, bot) end
			end)
		end
		if variant == "duel" then
			MS().announce(m, "MANCHE " .. d.round, "Premier à " .. tostring(m.limit) .. " — touche B pour changer d'arme (" .. V.freeze .. " s)", PINK)
		elseif d.pistol then
			MS().announce(m, "MANCHE AU PISTOLET", "Pistolets uniquement — achète avec B (" .. V.freeze .. " s)", GOLD)
		else
			MS().announce(m, "MANCHE " .. d.round, "Phase d'achat — touche B (" .. V.freeze .. " s)", GOLD)
		end
	end

	local function goLive(m: any)
		local d = m.data
		d.phase = "live"; d.phaseEnd = now() + V.round; m.endsAt = d.phaseEnd
		for p in pairs(m.players) do freezeHum(p, false) end
		BotService.freezeMatch(m.id, false)
		MS().announce(m, "C'EST PARTI !", nil, O.WHITE)
	end

	-- mi-temps (Compétitif, Désamorçage rapide) : changement de camp après la manche limite - 1
	local function halfTimeDue(m: any): boolean
		local d = m.data
		local lim = m.limit or 0
		return V.half and not d.halfDone and lim > 1 and d.round == lim - 1 and (m.score[T] or 0) < lim and (m.score[CT] or 0) < lim
	end
	local function halfTime(m: any)
		local d = m.data
		d.halfDone = true
		for p in pairs(m.players) do MS().setTeam(m, p, O.other(WeaponService.teamOf(p) or T)) end
		d.roster[T], d.roster[CT] = d.roster[CT], d.roster[T]
		for _, i in pairs(d.inv) do
			i.keep = false
			if ecoOn(m) then i.money = ECO.start end
		end
		m.score[T], m.score[CT] = m.score[CT] or 0, m.score[T] or 0
		d.loss = { [T] = 0, [CT] = 0 }
		d.halfPistol = true
	end

	-- ---------- interface du mode ----------
	function M.setup(m: any)
		local d = m.data
		m.timed = true
		d.phase = "pre"; d.phaseEnd = math.huge; d.round = 0; d.pistol = false; d.halfDone = false; d.halfPistol = false
		d.nadeT = {}; d.mineT = {}
		d.loss = { [T] = 0, [CT] = 0 }; d.inv = {}; d.roster = { [T] = {}, [CT] = {} }; d.use = {}; d.hold = {}; d.retake = {}; d.roam = {}
		d.sites = O.sites(m); d.plan = 1; d.started = false; d.over = false
		d.bomb = { state = "none", carrier = nil, prog = 0, defProg = {}, pos = nil, site = nil, explodeAt = nil, lastPos = nil }
		d.bombModel = nil
		d.public = { kind = "rounds", variant = variant }
	end
	function M.start(m: any)
		local d = m.data
		d.started = true
		for _, b in ipairs(BotService.ofMatch(m.id)) do
			local team = b:GetAttribute("Team")
			if team == T or team == CT then table.insert(d.roster[team], b.Name) end
		end
		resetRound(m)
	end
	function M.botsWanted(m: any, _team: string?, want: number): number?
		if m.data.started then return nil end      -- pendant les manches, les bots sont recréés à chaque manche
		return want
	end
	function M.canRespawn(_m: any, _c: any): boolean return false end
	function M.spawnPoint(m: any, c: any): Vector3?
		local q = m.data.spawnQ and m.data.spawnQ[WeaponService.teamOf(c) or ""]
		if q and #q > 0 then return table.remove(q) end
		local l = if WeaponService.teamOf(c) == T then m.map.spawns.T else m.map.spawns.CT
		return if #l > 0 then l[math.random(#l)] else nil
	end
	function M.loadout(m: any, c: any): { string }?
		if not m.data.inv then return nil end
		return listOf(inv(m, c))
	end
	function M.onSpawn(m: any, c: any, char: Model)
		if not m.data.inv then return end
		char:SetAttribute("ProtectedUntil", 0)     -- pas de protection d'apparition dans une manche
		applyGear(c, inv(m, c)); applyNades(c, inv(m, c))
		if m.data.phase == "freeze" or m.data.phase == "pre" then
			freezeHum(c, true)
			if not O.isPlayer(c) then BotService.freezeMatch(m.id, true) end
		end
		if O.isPlayer(c) then syncMoney(m, c) end
	end
	function M.onKill(m: any, killer: any, victim: any, key: string, _hs: boolean, ks: any, vs: any): boolean
		local d = m.data
		if ks and ks ~= vs and ks.team ~= vs.team then
			local i = inv(m, killer)
			local w = Config.WEAPONS[key]
			i.money = math.min(cap(m), i.money + (if ecoOn(m) then ECO.kill else (w and w.kill or 300)))
			if O.isPlayer(killer) then syncMoney(m, killer) end
		end
		if d.bomb.carrier == victim then dropBomb(m, nil) end
		if typeof(victim) == "Instance" and victim:IsA("Model") then victim:SetAttribute("Busy", nil) end
		return true     -- les éliminations ne marquent pas : on compte les manches
	end
	function M.useKey(m: any, p: Player, on: boolean) m.data.use[p] = if on then true else nil end

	-- grenades et mines des bots, aux mêmes moments que le web (src/70_ai.js botUpdate, src/63_agents.js agentBot) :
	-- en combat, flash entre 9 et 24 m, fumigène quand il est blessé ; hors combat, frag sur la dernière position vue
	-- (moins de 4 s, entre 9 et 26 m) ; mine de temps en temps quand il ne se bat pas
	local function botNades(m: any, dt: number)
		local d = m.data
		local diff = Modes.DIFFS[m.settings.diff] or Modes.DIFFS[3]
		local t = now()
		for _, bot in ipairs(BotService.ofMatch(m.id)) do
			local r = O.root(bot)
			if not r or bot:GetAttribute("Frozen") then continue end
			local s = GrenadeService.get(bot)
			if not s then continue end
			local key = bot.Name
			local target, seen, ago = BotService.combatOf(bot)
			local tr = target and target:FindFirstChild("HumanoidRootPart") :: BasePart?
			if t > (d.nadeT[key] or 0) then
				if tr then
					local dist = O.flat(tr.Position, r.Position) / U
					local hum = bot:FindFirstChildOfClass("Humanoid")
					if s.flash > 0 and dist > 9 and dist < 24 and math.random() < dt * 0.5 * diff.nade then
						d.nadeT[key] = t + 4; WeaponService.throwGrenade(bot, "flash", false, tr.Position)
					elseif s.smoke > 0 and hum and hum.Health < 40 and dist > 6 and math.random() < dt * 1.2 * diff.nade then
						d.nadeT[key] = t + 6; WeaponService.throwGrenade(bot, "smoke", false, r.Position:Lerp(tr.Position, 0.35))
					end
				elseif s.frag > 0 and seen and ago < 4 then
					local dd = O.flat(seen, r.Position) / U
					if dd > 9 and dd < 26 and math.random() < dt * 0.8 * diff.nade then
						d.nadeT[key] = t + 5; WeaponService.throwGrenade(bot, "frag", false, seen)
					end
				end
			end
			d.mineT[key] = (d.mineT[key] or (1.5 + math.random() * 2)) - dt
			if d.mineT[key] <= 0 then
				d.mineT[key] = 1.5 + math.random() * 2
				if not target and s.mine > 0 and math.random() < 0.18 then WeaponService.placeMine(bot) end
			end
		end
	end

	function M.tick(m: any, dt: number)
		local d = m.data
		if not d.started then return end
		local t = now()
		if d.phase == "freeze" then
			m.endsAt = d.phaseEnd
			if t >= d.phaseEnd then goLive(m) end
		elseif d.phase == "live" then
			pcall(botNades, m, dt)
			local b = d.bomb
			-- la bombe va à son porteur dès qu'il est apparu
			if V.bomb and b.state == "carried" and not b.carrier and d.bombFor then
				local c = if typeof(d.bombFor) == "string" then nil else d.bombFor
				if not c then
					for _, bot in ipairs(BotService.ofMatch(m.id)) do if "bot:" .. bot.Name == d.bombFor then c = bot end end
				end
				if c and O.root(c) then giveBomb(m, c) else
					local ts = O.alive(m, T)
					if #ts > 0 then giveBomb(m, ts[math.random(#ts)]) end
				end
				d.bombFor = nil
			end
			if V.bomb then
				if b.state == "carried" and b.carrier then
					local r = O.root(b.carrier)
					if not r then dropBomb(m, nil)
					else
						b.lastPos = O.feet(r)
						local c = b.carrier
						local site = siteAt(m, b.lastPos)
						local isBot = not O.isPlayer(c)
						local holding = site ~= nil and (if isBot then true else d.use[c] == true)
						if isBot then c:SetAttribute("Busy", if site then true else nil) end
						if holding then
							b.prog += dt
							if b.prog >= PLANT_T then
								-- bombe posée
								b.prog = 0
								local ch = WeaponService.charOf(c)
								if ch then ch:SetAttribute("HasBomb", nil) end
								if isBot then c:SetAttribute("Busy", nil) end
								b.carrier = nil
								b.pos = O.groundBelow(m, b.lastPos); b.site = site.n
								b.explodeAt = t + BOMB_T
								bombState(m, "planted")
								showBomb(m, b.pos)
								local model = bombModel(m)
								model:SetAttribute("Site", site.n); model:SetAttribute("ExplodeAt", workspace:GetServerTimeNow() + BOMB_T)
								local s = m.stats[MS().keyOf(c)]
								if s then (s :: any).plants = ((s :: any).plants or 0) + 1; s.score += 300 end
								if ecoOn(m) then
									for _, e in ipairs(members(m)) do
										if e.team == T then
											local i = invOf(m, e.key, e.team); i.money = math.min(ECO.max, i.money + ECO.plant)
											if O.isPlayer(e.c) then syncMoney(m, e.c) end
										end
									end
								else
									local i = inv(m, c); i.money = math.min(16000, i.money + 300)
									if O.isPlayer(c) then syncMoney(m, c) end
								end
								MS().announce(m, "BOMBE POSÉE", "Site " .. site.n, Color3.fromRGB(255, 185, 56))
								-- les défenseurs bots se replacent autour de la bombe
								for _, bot in ipairs(BotService.ofMatch(m.id)) do
									if bot:GetAttribute("Team") == CT then
										local a, rr = math.random() * math.pi * 2, (5 + math.random() * 5) * U
										d.retake["bot:" .. bot.Name] = O.ground(m, b.pos + Vector3.new(math.cos(a) * rr, 0, math.sin(a) * rr))
									end
								end
							end
						else
							b.prog = 0
						end
						if O.isPlayer(c) then
							setAttr(c, "UseHint", if site and not holding then "Maintenez E : poser la bombe" else nil)
							setAttr(c, "UseMsg", if holding then "POSE DE LA BOMBE" else nil)
							setAttr(c, "UseProg", if holding then math.clamp(b.prog / PLANT_T, 0, 1) else nil)
						end
					end
				elseif b.state == "dropped" and b.pos then
					-- un attaquant qui passe dessus la ramasse ; le bot le plus proche va la chercher
					local best, bd = nil, math.huge
					for _, c in ipairs(O.alive(m, T)) do
						local r = O.root(c) :: BasePart
						local dd = O.flat(O.feet(r), b.pos)
						if dd < PICK_R and math.abs(O.feet(r).Y - b.pos.Y) < 2 * U then giveBomb(m, c); break end
						if not O.isPlayer(c) and dd < bd then best, bd = c, dd end
					end
					d.fetcher = best
				elseif b.state == "planted" and b.pos then
					m.endsAt = b.explodeAt
					-- désamorçage : le défenseur bot le plus proche y va ; un joueur maintient E à côté
					local best, bd = nil, math.huge
					local busy = {}
					for _, c in ipairs(O.alive(m, CT)) do
						local r = O.root(c) :: BasePart
						local dd = O.flat(O.feet(r), b.pos)
						local isBot = not O.isPlayer(c)
						if isBot and dd < bd then best, bd = c, dd end
						local near = dd < DEFUSE_R and math.abs(O.feet(r).Y - b.pos.Y) < 1.5 * U + 1
						local key = MS().keyOf(c)
						local holding = near and (if isBot then c == d.defuser else d.use[c] == true)
						local need = if inv(m, c).kit then DEFUSE_T / 2 else DEFUSE_T
						if isBot then c:SetAttribute("Busy", if holding then true else nil) end
						if holding then
							busy[key] = true
							b.defProg[key] = (b.defProg[key] or 0) + dt
							if b.defProg[key] >= need then
								-- bombe désamorcée
								local i = inv(m, c); i.money = math.min(cap(m), i.money + (if ecoOn(m) then ECO.defuse else 300))
								if O.isPlayer(c) then syncMoney(m, c) end
								local s = m.stats[key]
								if s then (s :: any).defuses = ((s :: any).defuses or 0) + 1; s.score += 300 end
								bombState(m, "defused"); showBomb(m, nil)
								endRound(m, CT, "Bombe désamorcée")
								return
							end
						end
						if O.isPlayer(c) then
							setAttr(c, "UseHint", if near and not holding then "Maintenez E : désamorcer" else nil)
							setAttr(c, "UseMsg", if holding then "DÉSAMORÇAGE" else nil)
							setAttr(c, "UseProg", if holding then math.clamp((b.defProg[key] or 0) / need, 0, 1) else nil)
						end
					end
					for k in pairs(b.defProg) do if not busy[k] then b.defProg[k] = nil end end
					d.defuser = best
					if t >= b.explodeAt then
						-- explosion : dégâts autour (240 au centre, nuls à 16 m), puis fin de manche
						bombState(m, "exploded"); showBomb(m, nil)
						local ex = Instance.new("Explosion"); ex.Position = b.pos; ex.BlastRadius = 6 * U; ex.BlastPressure = 0
						ex.DestroyJointRadiusPercent = 0; ex.Parent = m.map.folder
						for _, c in ipairs(O.alive(m)) do
							local r = O.root(c)
							local dist = r and O.flat(r.Position, b.pos) / U or math.huge
							if r and dist < 16 then
								WeaponService.applyDamage(nil, r.Parent :: Model, math.floor(240 * (1 - dist / 16) + 0.5), false, "bomb", 1)
							end
						end
						endRound(m, T, "La bombe a explosé")
						return
					end
				end
			end
			-- duel : positions révélées à 20 s de la fin
			if variant == "duel" and not d.revealed and d.phaseEnd - t <= REVEAL then
				d.revealed = true
				d.roam = {}
				MS().announce(m, "POSITIONS RÉVÉLÉES", "Plus que " .. REVEAL .. " s", PINK)
			end
			if b.state ~= "planted" then
				m.endsAt = d.phaseEnd
				if t >= d.phaseEnd then endRound(m, CT, "Temps écoulé") end
			end
			checkAlive(m)
			-- les autres joueurs : rien à faire avec E
			for p in pairs(m.players) do
				if p ~= b.carrier and not (b.state == "planted" and WeaponService.teamOf(p) == CT) then
					setAttr(p, "UseHint", nil); setAttr(p, "UseMsg", nil); setAttr(p, "UseProg", nil)
				end
			end
		elseif d.phase == "end" then
			m.endsAt = d.phaseEnd
			if t >= d.phaseEnd then
				local lim = m.limit or 1
				if (m.score[T] or 0) >= lim or (m.score[CT] or 0) >= lim then
					d.over = true
					d.winner = if (m.score[T] or 0) >= lim then T else CT
					m.endsAt = t + 60
				elseif halfTimeDue(m) then
					halfTime(m)
					resetRound(m)
					for p in pairs(m.players) do
						MS().announce(m, "MI-TEMPS", "Changement de camp — vous êtes maintenant " .. teamWord(WeaponService.teamOf(p) or T)
							.. (if d.pistol then " · manche au pistolet" else ""), GOLD, p)
					end
				else
					resetRound(m)
				end
			end
		end
		-- pour le HUD (ModeHud) : phase, manche, bombe, sites
		local b = d.bomb
		local carrierName = nil
		if b.carrier then local s = m.stats[MS().keyOf(b.carrier)]; carrierName = s and s.name end
		local sites = {}
		for _, s in ipairs(d.sites) do table.insert(sites, { n = s.n, pos = s.pos, r = s.r }) end
		d.public = {
			kind = "rounds", variant = variant, phase = d.phase, round = d.round, pistol = d.pistol, limit = m.limit, bombMode = V.bomb,
			left = if d.phaseEnd < math.huge then math.max(0, d.phaseEnd - t) else 0, freeze = V.freeze, half = d.halfDone,
			bomb = { state = b.state, site = b.site, pos = b.pos, carrier = carrierName, left = if b.explodeAt then math.max(0, b.explodeAt - t) else nil },
			sites = sites, revealed = d.revealed, lastWin = d.lastWin, lastReason = d.lastReason,
		}
	end

	function M.checkEnd(m: any): (boolean, any)
		if m.data.over then return true, m.data.winner end
		return false, nil
	end
	function M.timeUp(m: any): any
		local a, b = m.score[T] or 0, m.score[CT] or 0
		return if a > b then T elseif b > a then CT else nil
	end

	-- où vont les bots (botGoal du web, et la traque du duel)
	function M.botGoal(m: any, bot: Model): Vector3?
		local d = m.data
		if not d.started or d.phase ~= "live" then return nil end
		local key = "bot:" .. bot.Name
		local team = (bot:GetAttribute("Team") :: string?) or T
		local root = bot:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then return nil end
		if not V.bomb then
			local r = d.roam[key]
			if not r or now() > r.t or O.flat(r.pos, root.Position) < 1.6 * U then
				local foes = O.alive(m, O.other(team))
				local pos: Vector3? = nil
				if #foes > 0 then
					local fr = O.root(foes[math.random(#foes)])
					local s = (if d.revealed then 3 else 10) * U
					if fr then pos = fr.Position + Vector3.new((math.random() * 2 - 1) * s, 0, (math.random() * 2 - 1) * s) end
				end
				if not pos and #m.roam > 0 then pos = m.roam[math.random(#m.roam)] end
				r = { pos = pos or root.Position, t = now() + 4 + math.random() * 3 }
				d.roam[key] = r
			end
			return r.pos
		end
		local b = d.bomb
		if team == T then
			if b.state == "dropped" and d.fetcher == bot and b.pos then return b.pos end
			if b.state == "carried" and b.carrier == bot then
				local s = d.sites[d.plan]
				return s and s.pos
			end
			return d.hold[key]
		end
		if b.state == "planted" and b.pos then
			if d.defuser == bot then return b.pos end
			return d.retake[key] or b.pos
		end
		return d.hold[key]
	end

	function M.info(m: any): any
		local d = m.data
		local col = m.def.c
		if not d.started then return { line = "Premier à " .. tostring(m.limit) .. " manches", color = col } end
		local sub = "Premier à " .. tostring(m.limit) .. " manches" .. (if V.half and not d.halfDone and (m.limit or 0) > 1 then " · mi-temps après la manche " .. ((m.limit or 1) - 1) else "")
		if d.phase == "freeze" then
			local line = if variant == "duel" then "MANCHE " .. d.round .. " — CHOISIS TON ARME (B)"
				elseif d.pistol then "MANCHE AU PISTOLET — PHASE D'ACHAT (B)" else "MANCHE " .. d.round .. " — PHASE D'ACHAT (B)"
			return { line = line, sub = sub, color = GOLD }
		elseif d.phase == "end" then
			return { line = "MANCHE " .. d.round .. " : VICTOIRE DES " .. teamWord(d.lastWin or T), sub = d.lastReason, color = O.COL[d.lastWin or T] }
		end
		local b = d.bomb
		if b.state == "planted" then
			return { line = "💣 BOMBE POSÉE — SITE " .. (b.site or "?"), sub = "Explosion dans " .. math.max(0, math.ceil((b.explodeAt or 0) - now())) .. " s", subWarn = true, color = Color3.fromRGB(255, 185, 56) }
		elseif b.state == "dropped" then
			return { line = "MANCHE " .. d.round .. " — 💣 BOMBE LÂCHÉE", sub = sub, color = Color3.fromRGB(255, 185, 56) }
		elseif variant == "duel" and d.revealed then
			return { line = "MANCHE " .. d.round .. " — POSITIONS RÉVÉLÉES", sub = sub, color = PINK }
		end
		return { line = "MANCHE " .. d.round, sub = sub, color = col }
	end

	local function clearPlayer(p: Player)
		for _, a in ipairs({ "Money", "UseProg", "UseMsg", "UseHint" }) do p:SetAttribute(a, nil) end
		if p.Character then p.Character:SetAttribute("HasBomb", nil) end
	end
	function M.onLeave(m: any, p: Player)
		clearPlayer(p)
		if m.data.use then m.data.use[p] = nil end
		if m.data.bomb and m.data.bomb.carrier == p then dropBomb(m, nil) end
	end
	function M.cleanup(m: any)
		for p in pairs(m.players) do clearPlayer(p) end
		WeaponService.clearGrenades(m.id)
		local model = m.data.bombModel
		if model then model:Destroy() end
		m.data.bombModel = nil
	end

	local _ = Players
	return M
end

return Rounds
