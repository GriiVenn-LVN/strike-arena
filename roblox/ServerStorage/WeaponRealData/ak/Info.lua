-- Généré par tools/export_weapons_real_lua.py depuis models/weapons_real (Sketchfab, CC BY) : ne pas modifier à la main.
-- Données de l'arme réaliste « ak » : chunks = modules D1..Dn (base64 mis bout à bout) ; at = { début, longueur }
-- dans les octets décodés. Pièce : par sommet int16 ×3 (position / 20000), int8 ×3 (normale / 127), 1 octet vide,
-- int16 ×2 (texture / 8192), puis les triangles en uint16 ×3. Image : JPEG { début, longueur, largeur, hauteur }.
return {
	chunks = 6,
	groups = {
		{ part = "body", mat = 1, nv = 12051, nt = 14545, at = { 0, 255984 } },
		{ part = "bolt", mat = 1, nv = 216, nt = 215, at = { 255984, 4314 } },
		{ part = "mag", mat = 1, nv = 747, nt = 634, at = { 260300, 14262 } },
	},
	mats = {
		{ c = { 274564, 127578, 1024, 1024 }, n = { 402144, 146810, 1024, 1024 }, m = { 712332, 63393, 512, 512 }, r = { 548956, 163375, 1024, 1024 } },
	},
}
