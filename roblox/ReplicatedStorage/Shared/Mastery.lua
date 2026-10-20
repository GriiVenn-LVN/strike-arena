--!strict
-- ReplicatedStorage/Shared/Mastery (ModuleScript, client + serveur)
-- Maîtrise d'arme façon Call of Duty : chaque arme (sauf le couteau) a ses défis de maîtrise, qui débloquent des camos
-- animés pour CETTE arme. Les camos sont dessinés par Shared/SkinPaint (cartes 512 px « i:mc:<camo> » envoyées par
-- MeshUploader, dessin en direct en attendant) et se posent comme les camos animés de la boutique (attribut Camo_<arme>).
--   Or            : 100 éliminations et 30 tirs à la tête avec l'arme
--   Diamant       : l'Or, puis 300 éliminations et 120 tirs à la tête avec l'arme
--   Matière noire : le Diamant sur l'arme ET sur 5 armes en tout
-- Les compteurs viennent de CareerService (profile.career[arme] = { k, hs }, comptés côté serveur à chaque élimination).
local Mastery = {}

export type Tier = { id: string, camo: string, name: string, color: Color3, kills: number, hs: number, needDiamonds: number? }

Mastery.TIERS = {
	{ id = "gold", camo = "m_gold", name = "Or", color = Color3.fromRGB(255, 196, 58), kills = 100, hs = 30 },
	{ id = "diamond", camo = "m_diamond", name = "Diamant", color = Color3.fromRGB(150, 225, 255), kills = 300, hs = 120 },
	{ id = "dark", camo = "m_dark", name = "Matière noire", color = Color3.fromRGB(190, 110, 255), kills = 300, hs = 120, needDiamonds = 5 },
} :: { Tier }

-- camos de maîtrise : même forme que SkinInfo.ANIM (nom, couleur des pièces secondaires, finition) ; SkinPaint les ajoute
Mastery.CAMOS = {
	m_gold = { name = "Or de maîtrise", a = "#5a3c08", fin = "chrome" },
	m_diamond = { name = "Diamant", a = "#1a3a52", fin = "chrome" },
	m_dark = { name = "Matière noire", a = "#0a0614", fin = "gloss" },
} :: { [string]: { name: string, a: string, fin: string } }

-- armes concernées : toutes celles qui tirent (Config.WEAPONS sans le couteau)
function Mastery.eligible(weapons: { [string]: any }, key: string): boolean
	local w = weapons[key]
	return w ~= nil and not w.melee
end

-- niveau atteint sur une arme : 0 = rien, 1 = Or, 2 = Diamant, 3 = Matière noire
-- rec = { k, hs } de l'arme ; diamonds = nombre d'armes au Diamant (toutes armes)
function Mastery.level(rec: any, diamonds: number): number
	local k = if typeof(rec) == "table" then tonumber(rec.k) or 0 else 0
	local hs = if typeof(rec) == "table" then tonumber(rec.hs) or 0 else 0
	local lvl = 0
	for i, t in ipairs(Mastery.TIERS) do
		if k >= t.kills and hs >= t.hs and (t.needDiamonds == nil or diamonds >= t.needDiamonds) then lvl = i else break end
	end
	return lvl
end

-- nombre d'armes au Diamant (sert à la Matière noire)
function Mastery.diamonds(career: any): number
	local n = 0
	if typeof(career) ~= "table" then return 0 end
	local d = Mastery.TIERS[2]
	for _, rec in pairs(career) do
		if typeof(rec) == "table" and (tonumber(rec.k) or 0) >= d.kills and (tonumber(rec.hs) or 0) >= d.hs then n += 1 end
	end
	return n
end

-- camo de maîtrise débloqué sur cette arme ?
function Mastery.camoOpen(career: any, key: string, camo: string): boolean
	local rec = typeof(career) == "table" and career[key] or nil
	local lvl = Mastery.level(rec, Mastery.diamonds(career))
	for i, t in ipairs(Mastery.TIERS) do
		if t.camo == camo then return lvl >= i end
	end
	return false
end

-- prochain objectif d'une arme (texte court pour le Profil), nil si tout est fait
function Mastery.nextGoal(rec: any, diamonds: number): (Tier?, number, number)
	local lvl = Mastery.level(rec, diamonds)
	local t = Mastery.TIERS[lvl + 1]
	if not t then return nil, 1, 1 end
	local k = if typeof(rec) == "table" then tonumber(rec.k) or 0 else 0
	local hs = if typeof(rec) == "table" then tonumber(rec.hs) or 0 else 0
	return t, math.clamp(k / t.kills, 0, 1), math.clamp(hs / t.hs, 0, 1)
end

return Mastery
