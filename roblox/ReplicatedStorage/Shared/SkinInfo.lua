-- Généré par tools/skins_to_lua.py depuis les skins du jeu web : ne pas modifier à la main.
-- SkinInfo.SKINS[n] suit Config.SKINS ; tex = image de SkinTextures ; fin = finition ; a = couleur des pièces secondaires ;
-- b = couleur unie (skin sans peinture) ; glow = skin lumineux. SkinInfo.ANIM = camos animés (exclusifs Robux).
local SkinInfo = {}
SkinInfo.SKINS = {
	[1] = { name = "Défaut", tex = nil, fin = nil, a = nil, b = nil, tint = nil, glow = false },  -- web 0
	[2] = { name = "Noir mat", tex = nil, fin = "matte", a = "#0c0d0f", b = "#202327", tint = nil, glow = false },  -- web 1
	[3] = { name = "Or royal", tex = "goldleaf", fin = "chrome", a = "#6a4a10", b = nil, tint = nil, glow = false },  -- web 2
	[4] = { name = "Rouge sang", tex = "bloodfade", fin = "gloss", a = "#1a0406", b = nil, tint = nil, glow = false },  -- web 3
	[5] = { name = "Bleu néon", tex = "neonlines", fin = "gloss", a = "#050c22", b = nil, tint = nil, glow = true },  -- web 4
	[6] = { name = "Arctique", tex = "frost", fin = "gloss", a = "#7f93a8", b = nil, tint = nil, glow = false },  -- web 5
	[7] = { name = "Violet nacré", tex = "pearl", fin = "pearl", a = "#2b1450", b = nil, tint = nil, glow = false },  -- web 6
	[8] = { name = "Cœurs", tex = "hearts", fin = "paint", a = "#b0306a", b = nil, tint = nil, glow = false },  -- web 7
	[9] = { name = "Camo forêt", tex = "camoForest", fin = "paint", a = "#1f2810", b = nil, tint = nil, glow = false },  -- web 8
	[10] = { name = "Camo désert", tex = "camoDesert", fin = "paint", a = "#5e4726", b = nil, tint = nil, glow = false },  -- web 9
	[11] = { name = "Carbone", tex = "hex", fin = "gloss", a = "#0b0b0d", b = nil, tint = nil, glow = false },  -- web 10
	[12] = { name = "Vapeur", tex = "brass", fin = "anod", a = "#3a1c0c", b = nil, tint = nil, glow = false },  -- web 11
	[13] = { name = "Dragon", tex = "flame", fin = "gloss", a = "#1a0606", b = nil, tint = nil, glow = false },  -- web 12
	[14] = { name = "Galaxie", tex = "galaxy", fin = "gloss", a = "#090720", b = nil, tint = nil, glow = true },  -- web 13
	[15] = { name = "Tigre", tex = "tiger", fin = "paint", a = "#3a1d08", b = nil, tint = nil, glow = false },  -- web 14
	[16] = { name = "Toxique", tex = "toxic", fin = "gloss", a = "#0b1f06", b = nil, tint = nil, glow = true },  -- web 15
	[17] = { name = "Circuit", tex = "circuit", fin = "anod", a = "#06181b", b = nil, tint = nil, glow = true },  -- web 16
	[18] = { name = "Marbre", tex = "marble", fin = "chrome", a = "#8a7a52", b = nil, tint = nil, glow = false },  -- web 17
	[19] = { name = "Damas", tex = "damascus", fin = "chrome", a = "#2a2e33", b = nil, tint = nil, glow = false },  -- web 18
	[20] = { name = "Bois précieux", tex = "burl", fin = "gloss", a = "#2a1608", b = nil, tint = nil, glow = false },  -- web 19
	[21] = { name = "Coucher de soleil", tex = "sunset", fin = "gloss", a = "#3a1630", b = nil, tint = nil, glow = false },  -- web 20
	[22] = { name = "Course", tex = "racing", fin = "gloss", a = "#160608", b = nil, tint = nil, glow = false },  -- web 21
	[23] = { name = "Danger", tex = "hazard", fin = "paint", a = "#1a1a1a", b = nil, tint = nil, glow = false },  -- web 22
	[24] = { name = "Léopard", tex = "leopard", fin = "paint", a = "#2a1606", b = nil, tint = nil, glow = false },  -- web 23
	[25] = { name = "Écailles", tex = "scales", fin = "anod", a = "#0a2a1a", b = nil, tint = nil, glow = false },  -- web 24
	[26] = { name = "Cristal", tex = "ice", fin = "chrome", a = "#244a66", b = nil, tint = nil, glow = false },  -- web 25
	[27] = { name = "Lave", tex = "lava", fin = "matte", a = "#120806", b = nil, tint = nil, glow = true },  -- web 26
	[28] = { name = "Graffiti", tex = "graffiti", fin = "paint", a = "#15161a", b = nil, tint = nil, glow = false },  -- web 27
	[29] = { name = "Matrice", tex = "matrix", fin = "gloss", a = "#03140a", b = nil, tint = nil, glow = true },  -- web 28
	[30] = { name = "Sakura", tex = "sakura", fin = "paint", a = "#8a3a58", b = nil, tint = nil, glow = false },  -- web 29
	[31] = { name = "Bonbon", tex = "candy", fin = "paint", a = "#ff8fb8", b = nil, tint = nil, glow = false },  -- web 30
	[32] = { name = "Océan", tex = "ocean", fin = "gloss", a = "#06284a", b = nil, tint = nil, glow = false },  -- web 31
	[33] = { name = "Étoilé", tex = "stars", fin = "paint", a = "#0a1233", b = nil, tint = nil, glow = false },  -- web 32
	[34] = { name = "Hologramme", tex = "holo", fin = "chrome", a = "#2a2a3a", b = nil, tint = nil, glow = false },  -- web 33
	[35] = { name = "Digital", tex = "digital", fin = "paint", a = "#1c2420", b = nil, tint = nil, glow = false },  -- web 34
	[36] = { name = "Damier", tex = "checker", fin = "gloss", a = "#161616", b = nil, tint = nil, glow = false },  -- web 35
	[37] = { name = "Nuages", tex = "clouds", fin = "paint", a = "#3a6fb0", b = nil, tint = nil, glow = false },  -- web 36
	[38] = { name = "Filigrane royal", tex = "royal", fin = "chrome", a = "#07102a", b = nil, tint = nil, glow = false },  -- web 37
	[39] = { name = "Arcade", tex = "pixel8", fin = "gloss", a = "#0a0612", b = nil, tint = nil, glow = true },  -- web 38
	[40] = { name = "Orbite", tex = "cs_orbit", fin = "gloss", a = "#1b1b1f", b = nil, tint = nil, glow = false },  -- web 39
	[41] = { name = "Dégradé solaire", tex = "cs_fade", fin = "chrome", a = "#3a1650", b = nil, tint = nil, glow = false },  -- web 40
	[42] = { name = "Bête néon", tex = "cs_beast", fin = "gloss", a = "#0d2a2a", b = nil, tint = nil, glow = false },  -- web 41
	[43] = { name = "Ligne rouge", tex = "cs_redline", fin = "gloss", a = "#0b0b0d", b = nil, tint = nil, glow = false },  -- web 42
	[44] = { name = "Dragon d'or", tex = "cs_lore", fin = "paint", a = "#5a4a22", b = nil, tint = nil, glow = false },  -- web 43
	[45] = { name = "Loup hurleur", tex = "cs_howl", fin = "gloss", a = "#2a0a06", b = nil, tint = nil, glow = false },  -- web 44
	[46] = { name = "Trempe", tex = "cs_hardened", fin = "anod", a = "#3a3a40", b = nil, tint = nil, glow = false },  -- web 45
	[47] = { name = "Doppler", tex = "cs_doppler", fin = "chrome", a = "#140818", b = nil, tint = nil, glow = false },  -- web 46
	[48] = { name = "Dent de tigre", tex = "cs_tooth", fin = "chrome", a = "#5a3a08", b = nil, tint = nil, glow = false },  -- web 47
	[49] = { name = "Marbre flamme", tex = "cs_mfade", fin = "chrome", a = "#2a1030", b = nil, tint = nil, glow = false },  -- web 48
	[50] = { name = "Toile cramoisie", tex = "cs_web", fin = "matte", a = "#140406", b = nil, tint = nil, glow = false },  -- web 49
	[51] = { name = "Abattoir", tex = "cs_slaughter", fin = "chrome", a = "#3a0c10", b = nil, tint = nil, glow = false },  -- web 50
	[52] = { name = "Néo-noir", tex = "cs_noir", fin = "gloss", a = "#0a0a0a", b = nil, tint = nil, glow = false },  -- web 51
	[53] = { name = "Volcan bleu", tex = "cs_vulcan", fin = "gloss", a = "#0a1430", b = nil, tint = nil, glow = false },  -- web 52
	[54] = { name = "Imprimé nacré", tex = "cs_print", fin = "pearl", a = "#d8d8de", b = nil, tint = nil, glow = false },  -- web 53
	[55] = { name = "Bonbon d'Halloween", tex = "hw_candy", fin = "gloss", a = "#3a1a08", b = nil, tint = nil, glow = false },  -- web 60
	[56] = { name = "Citrouille", tex = "hw_pumpkin", fin = "paint", a = "#1a0c04", b = nil, tint = nil, glow = true },  -- web 61
	[57] = { name = "Toile maudite", tex = "hw_web", fin = "matte", a = "#12061a", b = nil, tint = nil, glow = false },  -- web 62
	[58] = { name = "Ossuaire", tex = "hw_bones", fin = "matte", a = "#141216", b = nil, tint = nil, glow = false },  -- web 63
	[59] = { name = "Ectoplasme", tex = "hw_ecto", fin = "gloss", a = "#03100a", b = nil, tint = nil, glow = true },  -- web 64
	[60] = { name = "Sang de vampire", tex = "hw_vampire", fin = "gloss", a = "#0a0204", b = nil, tint = nil, glow = false },  -- web 65
	[61] = { name = "Nuit des sorcières", tex = "hw_witch", fin = "gloss", a = "#120820", b = nil, tint = nil, glow = true },  -- web 66
}
SkinInfo.ANIM = {
	plasma = { name = "Plasma", a = "#12061f", fin = "gloss" },
	magma = { name = "Magma vivant", a = "#140604", fin = "matte" },
	code = { name = "Code vivant", a = "#021008", fin = "gloss" },
	nebula = { name = "Nébuleuse", a = "#07051a", fin = "gloss" },
	prism = { name = "Prisme", a = "#2a2a3a", fin = "chrome" },
	storm = { name = "Tempête électrique", a = "#05080f", fin = "anod" },
}
return SkinInfo
