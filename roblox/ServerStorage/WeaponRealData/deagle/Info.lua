-- Généré par tools/export_weapons_real_lua.py depuis models/weapons_real (Sketchfab, CC BY) : ne pas modifier à la main.
-- Données de l'arme réaliste « deagle » : chunks = modules D1..Dn (base64 mis bout à bout) ; at = { début, longueur }
-- dans les octets décodés. Pièce : par sommet int16 ×3 (position / 20000), int8 ×3 (normale / 127), 1 octet vide,
-- int16 ×2 (texture / 8192), puis les triangles en uint16 ×3. Image : JPEG { début, longueur, largeur, hauteur }.
return {
	chunks = 8,
	groups = {
		{ part = "body", mat = 1, nv = 2810, nt = 2552, at = { 0, 54652 } },
		{ part = "body", mat = 2, nv = 5456, nt = 4939, at = { 54652, 106018 } },
		{ part = "bolt", mat = 1, nv = 4840, nt = 3624, at = { 160672, 89504 } },
		{ part = "mag", mat = 3, nv = 1656, nt = 1686, at = { 250176, 33300 } },
	},
	mats = {
		{ c = { 283476, 173938, 1024, 1024 }, n = { 457416, 48001, 512, 512 }, m = { 538384, 39404, 512, 512 }, r = { 505420, 32964, 512, 512 } },
		{ c = { 577788, 128867, 1024, 1024 }, n = { 706656, 46542, 512, 512 }, m = { 805648, 58851, 512, 512 }, r = { 753200, 52447, 512, 512 } },
		{ c = { 864500, 113052, 1024, 1024 }, n = { 977552, 27263, 512, 512 }, m = { 1041608, 41045, 512, 512 }, r = { 1004816, 36792, 512, 512 } },
	},
}
