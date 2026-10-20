-- Généré par tools/export_weapons_real_lua.py depuis models/weapons_real (Sketchfab, CC BY) : ne pas modifier à la main.
-- Données de l'arme réaliste « awp » : chunks = modules D1..Dn (base64 mis bout à bout) ; at = { début, longueur }
-- dans les octets décodés. Pièce : par sommet int16 ×3 (position / 20000), int8 ×3 (normale / 127), 1 octet vide,
-- int16 ×2 (texture / 8192), puis les triangles en uint16 ×3. Image : JPEG { début, longueur, largeur, hauteur }.
return {
	chunks = 5,
	groups = {
		{ part = "body", mat = 1, nv = 17294, nt = 17041, at = { 0, 344362 } },
		{ part = "bolt", mat = 1, nv = 222, nt = 280, at = { 344364, 4788 } },
		{ part = "mag", mat = 1, nv = 196, nt = 134, at = { 349152, 3548 } },
	},
	mats = {
		{ c = { 352700, 55070, 1024, 1024 }, n = { 407772, 118985, 1024, 1024 }, m = { 637900, 51139, 512, 512 }, r = { 526760, 111139, 1024, 1024 } },
	},
}
