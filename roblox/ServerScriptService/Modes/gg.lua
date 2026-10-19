--!strict
-- Modes/gg : Course aux armes (web : GG_LADDER, ggKill, ggEquip dans src/60_game.js).
-- Chacun pour soi : chaque élimination fait passer à l'arme suivante de l'échelle ; une élimination au couteau fait
-- reculer la victime d'un niveau. Le premier qui élimine avec le couteau (dernier niveau) gagne.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local WeaponService = require(script.Parent.Parent.WeaponService)

local LADDER = { "glock", "p250", "fiveseven", "deagle", "mac10", "mp9", "ump", "nova", "xm", "galil", "famas", "ak", "m4", "sg553", "ssg", "awp", "knife" }

local M = {}
local function MS(): any return require(script.Parent.Parent.MatchService) :: any end
local function alive(c: any): boolean
	local ch = WeaponService.charOf(c)
	local h = ch and ch:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0
end
local function levelOf(m: any, c: any): number
	m.data.lvl = m.data.lvl or {}
	return m.data.lvl[MS().keyOf(c)] or 1
end
local function setLevel(m: any, c: any, n: number)
	m.data.lvl[MS().keyOf(c)] = n
	local s = m.stats[MS().keyOf(c)]
	if s then s.pts = n end
	if typeof(c) == "Instance" and c:IsA("Player") then
		local key = LADDER[n]
		c:SetAttribute("ModeLine", "Niveau " .. n .. " / " .. #LADDER .. " — " .. (Config.WEAPONS[key] and Config.WEAPONS[key].name or key))
	end
end
local function equip(c: any, n: number)
	local key = LADDER[n]
	WeaponService.giveLoadout(c, if key == "knife" then { "knife" } else { key, "knife" })
	WeaponService.setReserve(c, key, 999)
end

function M.setup(m: any) m.data.lvl = {}; m.limit = #LADDER end
function M.loadout(m: any, c: any): { string }
	local n = levelOf(m, c)
	setLevel(m, c, n)
	local key = LADDER[n]
	return if key == "knife" then { "knife" } else { key, "knife" }
end
function M.onSpawn(_m: any, c: any) task.defer(function() local s = WeaponService.current(c); if s then WeaponService.setReserve(c, s, 999) end end) end

function M.onKill(m: any, killer: any, victim: any, key: string, _hs: boolean, ks: any, vs: any): boolean
	if not ks or ks == vs then return true end
	local n = levelOf(m, killer)
	if n >= #LADDER then
		m.data.winner = ks
		return true
	end
	setLevel(m, killer, n + 1)
	if alive(killer) then equip(killer, n + 1) end
	if typeof(killer) == "Instance" and killer:IsA("Player") then
		local nk = LADDER[n + 1]
		MS().announce(m, "NIVEAU " .. (n + 1) .. " / " .. #LADDER, Config.WEAPONS[nk] and Config.WEAPONS[nk].name or nk, Color3.fromRGB(125, 255, 159), killer)
	end
	if Config.WEAPONS[key] and Config.WEAPONS[key].melee then
		local vn = levelOf(m, victim)
		if vn > 1 then
			setLevel(m, victim, vn - 1)
			if typeof(victim) == "Instance" and victim:IsA("Player") then MS().announce(m, "RÉTROGRADÉ", "par un coup de couteau !", Color3.fromRGB(255, 90, 90), victim) end
		end
	end
	m.score[ks.key] = levelOf(m, killer)
	return true
end

function M.checkEnd(m: any): (boolean, any)
	if m.data.winner then return true, m.data.winner end
	return false, nil
end
function M.timeUp(m: any): any
	local best, bl, bk = nil, -1, -1
	for k, s in pairs(m.stats) do
		local l = m.data.lvl[k] or 1
		if l > bl or (l == bl and s.k > bk) then best, bl, bk = s, l, s.k end
	end
	return best
end
function M.info(m: any): any
	local best, bl = nil, 0
	for k, s in pairs(m.stats) do local l = m.data.lvl[k] or 1; if l > bl then best, bl = s, l end end
	return { line = "Course aux armes", sub = if best then "En tête : " .. best.name .. " (niveau " .. bl .. " / " .. #LADDER .. ")" else nil, color = Color3.fromRGB(125, 255, 159) }
end
function M.cleanup(m: any)
	for p in pairs(m.players) do p:SetAttribute("ModeLine", nil) end
end
function M.onLeave(_m: any, p: Player) p:SetAttribute("ModeLine", nil) end
return M
