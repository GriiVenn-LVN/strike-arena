--!strict
-- Modes/shp : Arme tournante (web : src/8Ze_tournante.js). Chacun pour soi, tout le monde a la MÊME arme, tirée au sort
-- toutes les 30 s parmi pistolets, PM, fusils à pompe, fusils, fusils de précision et mitrailleuses (jamais une des 4 dernières).
-- Réserve illimitée, pas de grenades. Premier à la limite d'éliminations.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local WeaponService = require(script.Parent.Parent.WeaponService)

local EVERY = 30
local CATS = { pistol = true, smg = true, shotgun = true, rifle = true, sniper = true, lmg = true }
local M = {}
local function MS(): any return require(script.Parent.Parent.MatchService) :: any end

local function pool(): { string }
	local l = {}
	for k, w in pairs(Config.WEAPONS) do
		if not w.melee and (w.slot == 0 or w.slot == 1) and (w.price or 0) > 0 and CATS[w.cat or ""] then table.insert(l, k) end
	end
	table.sort(l)
	return l
end
local function pick(m: any): string
	local all = pool()
	local free = {}
	for _, k in ipairs(all) do if not table.find(m.data.last, k) then table.insert(free, k) end end
	local list = if #free > 0 then free else all
	local k = list[math.random(#list)]
	table.insert(m.data.last, k); if #m.data.last > 4 then table.remove(m.data.last, 1) end
	return k
end
local function equip(m: any, c: any)
	if not MS().aliveChar(c) then return end
	WeaponService.giveLoadout(c, { m.data.key, "knife" })
	WeaponService.setReserve(c, m.data.key, 999)
end
local function roll(m: any, first: boolean)
	m.data.key = pick(m); m.data.t = EVERY
	m.data.public = { weapon = m.data.key }
	for _, c in ipairs(MS().combatants(m)) do equip(m, c) end
	if not first then MS().announce(m, "NOUVELLE ARME", Config.WEAPONS[m.data.key].name, Color3.fromRGB(255, 169, 77)) end
end

function M.setup(m: any) m.data.last = {}; roll(m, true) end
function M.loadout(m: any, _c: any): { string } return { m.data.key, "knife" } end
function M.onSpawn(m: any, c: any) task.defer(function() WeaponService.setReserve(c, m.data.key, 999) end) end
function M.tick(m: any, dt: number)
	m.data.t -= dt
	if m.data.t <= 0 then roll(m, false) end
end
function M.info(m: any): any
	local s = math.max(0, math.ceil(m.data.t or 0))
	return { line = "🎲 " .. string.upper(Config.WEAPONS[m.data.key] and Config.WEAPONS[m.data.key].name or "—"),
		sub = "nouvelle arme dans " .. s .. " s", subWarn = s <= 5, color = Color3.fromRGB(255, 169, 77) }
end
return M
