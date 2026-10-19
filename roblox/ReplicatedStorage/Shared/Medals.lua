--!strict
-- ReplicatedStorage/Shared/Medals (ModuleScript, client + serveur)
-- Médailles de fin de partie du jeu web (src/8G_medals.js MEDALS) : nom, icône, XP gagnée en fin de partie.
local Medals = {}

export type Medal = { id: string, n: string, ic: string, xp: number }

Medals.ORDER = { "first", "revenge", "long", "knife", "nade", "air", "clutchhp", "save", "collat", "ace", "s5", "s10", "assist" }
Medals.LIST = {
	first = { id = "first", n = "Premier sang", ic = "🩸", xp = 20 },
	revenge = { id = "revenge", n = "Vengeance", ic = "😤", xp = 15 },
	long = { id = "long", n = "Tir lointain", ic = "🎯", xp = 15 },
	knife = { id = "knife", n = "Humiliation", ic = "🔪", xp = 20 },
	nade = { id = "nade", n = "Grenadier", ic = "💥", xp = 10 },
	air = { id = "air", n = "Acrobate", ic = "🤸", xp = 15 },
	clutchhp = { id = "clutchhp", n = "Sur le fil", ic = "❤️‍🩹", xp = 15 },
	save = { id = "save", n = "Sauveur", ic = "🛡️", xp = 15 },
	collat = { id = "collat", n = "Doublé", ic = "⚡", xp = 25 },
	ace = { id = "ace", n = "As", ic = "🂡", xp = 50 },
	s5 = { id = "s5", n = "Inarrêtable", ic = "🔥", xp = 25 },
	s10 = { id = "s10", n = "Légende", ic = "👑", xp = 60 },
	assist = { id = "assist", n = "Assistance", ic = "🤝", xp = 15 },
} :: { [string]: Medal }

-- seuils du web (mètres / secondes / dégâts)
Medals.LONG_M = 38          -- tir lointain : plus de 38 m
Medals.ASSIST_DMG = 25      -- assistance : au moins 25 dégâts sur la victime…
Medals.ASSIST_T = 8         -- … dans les 8 dernières secondes
Medals.CLUTCH_HP = 20       -- sur le fil : 20 PV ou moins
Medals.SAVE_T = 2           -- sauveur : l'allié visé a été touché il y a moins de 2 s
Medals.COLLAT_T = 0.2       -- doublé : deux éliminations à moins de 0,2 s avec la même arme

return Medals
