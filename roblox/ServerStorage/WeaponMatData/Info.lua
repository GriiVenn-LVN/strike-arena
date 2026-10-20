-- Généré par tools/export_weapon_materials.py (cartes procédurales des matériaux des armes) : ne pas modifier à la main.
-- chunks = modules D1..Dn (base64 mis bout à bout) ; c / n / r = JPEG { début, longueur, largeur, hauteur } dans les
-- octets décodés ; avg = valeur moyenne de la carte de couleur (la teinte de la pièce est divisée par elle) ; metal = métal uni.
return {
	chunks = 11, size = 512,
	bruni = { c = { 0, 67173, 512, 512 }, n = { 67176, 166654, 512, 512 }, r = { 233832, 89051, 512, 512 }, avg = 0.715, metal = 0.90 },
	anod = { c = { 322884, 69934, 512, 512 }, n = { 392820, 209304, 512, 512 }, r = { 602124, 102660, 512, 512 }, avg = 0.771, metal = 0.70 },
	poly = { c = { 704784, 53878, 512, 512 }, n = { 758664, 268322, 512, 512 }, r = { 1026988, 71241, 512, 512 }, avg = 0.742, metal = 0.00 },
	bois = { c = { 1098232, 51323, 512, 512 }, n = { 1149556, 90471, 512, 512 }, r = { 1240028, 52559, 512, 512 }, avg = 0.767, metal = 0.00 },
	acier = { c = { 1292588, 45959, 512, 512 }, n = { 1338548, 108268, 512, 512 }, r = { 1446816, 49056, 512, 512 }, avg = 0.863, metal = 1.00 },
}
