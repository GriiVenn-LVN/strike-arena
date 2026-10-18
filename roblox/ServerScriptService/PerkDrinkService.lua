--!strict
-- ServerScriptService/PerkDrinkService (ModuleScript, requis par Main)
-- Boire un atout en Zombies (src/8U_perkdrink.js) : quand un joueur prend un atout, il range l'arme, sort le flacon de
-- la couleur de l'atout, fait sauter la capsule, boit, jette le flacon puis ressort l'arme. Pendant 2,3 s : ni tir ni
-- visée (vérifié ici aussi : ses tirs ne font pas de dégâts). Vu par les autres : flacon porté à la bouche.
-- Rien à appeler depuis Modes/zombies : on suit l'attribut « ZPerks » du joueur (liste des atouts, publiée par le mode)
-- et chaque atout nouveau lance la boisson. PerkDrinkService.drink(joueur, atout) reste disponible.
-- Attributs du personnage : DrinkUntil (heure serveur de fin), DrinkPerk (clé de l'atout).
-- Remote : PerkDrink (RemoteEvent, serveur -> tous : (joueur, atout, durée)).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponService = require(script.Parent.WeaponService)

local PerkDrinkService = {}
PerkDrinkService.T = 2.3

local ev = Instance.new("RemoteEvent"); ev.Name = "PerkDrink"; ev.Parent = ReplicatedStorage

local function drinking(ch: Instance?): boolean
	local u = ch and ch:GetAttribute("DrinkUntil")
	return typeof(u) == "number" and workspace:GetServerTimeNow() < u
end
PerkDrinkService.drinking = drinking

function PerkDrinkService.drink(p: Player, perk: string)
	local ch = p.Character
	local h = ch and ch:FindFirstChildOfClass("Humanoid")
	if not ch or not h or h.Health <= 0 then return end
	ch:SetAttribute("DrinkUntil", workspace:GetServerTimeNow() + PerkDrinkService.T)
	ch:SetAttribute("DrinkPerk", perk)
	ev:FireAllClients(p, perk, PerkDrinkService.T)
end

-- pas de dégâts pendant qu'on boit (le client bloque déjà le tir ; ceci empêche un client trafiqué de tirer quand même)
local prevFilter = (WeaponService :: any).damageFilter
;(WeaponService :: any).damageFilter = function(attacker: any, victimChar: Model, raw: number, headshot: boolean, key: string): number?
	if typeof(attacker) == "Instance" and attacker:IsA("Player") and drinking(attacker.Character) then return nil end
	if prevFilter then return prevFilter(attacker, victimChar, raw, headshot, key) end
	return raw
end
local prevThrow = (WeaponService :: any).throwBlocked
;(WeaponService :: any).throwBlocked = function(c: any): boolean
	if typeof(c) == "Instance" and c:IsA("Player") and drinking(c.Character) then return true end
	return if prevThrow then prevThrow(c) else false
end

-- suit la liste des atouts du joueur (attribut ZPerks : "jugg,speed,…")
local function setOf(v: any): { [string]: boolean }
	local s = {}
	if typeof(v) == "string" then for k in string.gmatch(v, "[^,]+") do s[k] = true end end
	return s
end
local function watch(p: Player)
	local prev = setOf(p:GetAttribute("ZPerks"))
	p:GetAttributeChangedSignal("ZPerks"):Connect(function()
		local now = setOf(p:GetAttribute("ZPerks"))
		local new: string? = nil
		for k in pairs(now) do if not prev[k] then new = k end end
		prev = now
		if new then PerkDrinkService.drink(p, new) end
	end)
end
Players.PlayerAdded:Connect(watch)
for _, p in ipairs(Players:GetPlayers()) do watch(p) end

return PerkDrinkService
