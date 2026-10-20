-- Généré par tools/export_weapons_real_lua.py depuis models/weapons_real (Sketchfab, CC BY) : ne pas modifier à la main.
-- Données de l'arme réaliste « m4 » : chunks = modules D1..Dn (base64 mis bout à bout) ; at = { début, longueur }
-- dans les octets décodés. Pièce : par sommet int16 ×3 (position / 20000), int8 ×3 (normale / 127), 1 octet vide,
-- int16 ×2 (texture / 8192), puis les triangles en uint16 ×3. Image : JPEG { début, longueur, largeur, hauteur }.
return {
	chunks = 4,
	groups = {
		{ part = "body", mat = 1, nv = 7166, nt = 11673, at = { 0, 170362 } },
		{ part = "body", mat = 1, nv = 333, nt = 489, at = { 170364, 7596 } },
		{ part = "mag", mat = 1, nv = 441, nt = 796, at = { 177960, 10950 } },
	},
	mats = {
		{ c = { 188912, 98458, 1024, 1024 }, n = { 287372, 125787, 1024, 1024 }, m = { 498344, 33861, 512, 512 }, r = { 413160, 85181, 1024, 1024 } },
	},
}
