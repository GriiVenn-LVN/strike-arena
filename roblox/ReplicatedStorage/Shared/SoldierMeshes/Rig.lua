-- Généré par tools/soldiers/soldiers_to_lua.py (squelette et couleurs des soldats du jeu web) : ne pas modifier à la main.
local Rig = {}
Rig.Q = 10000                  -- unités par mètre des positions int16
-- soldat réaliste : position au repos des os (m, repère du soldat : pieds en 0, regard vers -Z), bras en croix
Rig.real = {
	bones = {
		pelvis = Vector3.new(0.00000, 0.93747, 0.05010),
		spine = Vector3.new(0.00000, 1.03815, 0.02414),
		neck = Vector3.new(0.00000, 1.45232, 0.05138),
		head = Vector3.new(0.00000, 1.57414, -0.01142),
		thighL = Vector3.new(-0.10214, 0.90507, 0.00320),
		calfL = Vector3.new(-0.11050, 0.52587, 0.01253),
		footL = Vector3.new(-0.12364, 0.09796, 0.08002),
		thighR = Vector3.new(0.10214, 0.90507, 0.00320),
		calfR = Vector3.new(0.11050, 0.52587, 0.01253),
		footR = Vector3.new(0.12364, 0.09796, 0.08002),
		uarmL = Vector3.new(-0.14008, 1.44568, 0.01057),
		farmL = Vector3.new(-0.42144, 1.44598, 0.03134),
		handL = Vector3.new(-0.70974, 1.46320, 0.03381),
		uarmR = Vector3.new(0.14008, 1.44568, 0.01057),
		farmR = Vector3.new(0.42144, 1.44598, 0.03134),
		handR = Vector3.new(0.70974, 1.46320, 0.03381),
	},
	pelOff = Vector3.new(0.00000, -0.00253, 0.05010),      -- bassin du modèle - bassin du soldat procédural
	arm = {
		L = { la = 0.28212, lb = 0.28882, dU = Vector3.new(-0.99729, 0.00105, 0.07361), dF = Vector3.new(-0.99818, 0.05962, 0.00855) },
		R = { la = 0.28212, lb = 0.28882, dU = Vector3.new(0.99729, 0.00105, 0.07361), dF = Vector3.new(0.99818, 0.05962, 0.00855) },
	},
}
-- soldat procédural (tenues) : pivots au repos des groupes, épaules dans le repère du buste, porte-arme
Rig.proc = {
	piv = {
		LowerTorso = Vector3.new(0.00000, 0.94000, 0.00000),
		UpperTorso = Vector3.new(0.00000, 1.01000, 0.00000),
		Head = Vector3.new(0.00000, 1.65000, 0.00000),
		LeftUpperLeg = Vector3.new(-0.10000, 0.92000, 0.00000),
		LeftLowerLeg = Vector3.new(-0.10000, 0.46000, 0.00000),
		LeftFoot = Vector3.new(-0.10000, 0.01000, 0.00000),
		RightUpperLeg = Vector3.new(0.10000, 0.92000, 0.00000),
		RightLowerLeg = Vector3.new(0.10000, 0.46000, 0.00000),
		RightFoot = Vector3.new(0.10000, 0.01000, 0.00000),
	},
	S = { L = Vector3.new(-0.21500, 0.44000, 0.00000), R = Vector3.new(0.21500, 0.44000, 0.00000) },
	hips = Vector3.new(0.00000, 0.94000, 0.00000), spine = Vector3.new(0.00000, 1.01000, 0.00000), neck = Vector3.new(0.00000, 1.51000, 0.00000), gun = Vector3.new(0.12000, 0.20000, -0.20000),
}
-- emplacements de couleur du soldat procédural (Outfit.lua : couleur du sommet = index + 1)
Rig.SLOTS = { "skin", "shirt", "pants", "vest", "helm", "glove", "boot", "accent", "dark", "lens", "blk", "gold", "glass" }
-- tenues du jeu web, par nom (Config.OUTFITS[n].name)
Rig.OUTFITS = {
	["Opérateur nocturne"] = { web = 1, glow = false, metal = false, colors = { skin = { c = { 240, 200, 160 }, cls = "base" }, shirt = { c = { 42, 45, 51 }, cls = "base" }, pants = { c = { 36, 39, 44 }, cls = "base" }, vest = { c = { 22, 24, 28 }, cls = "base" }, helm = { c = { 27, 29, 34 }, cls = "base" }, glove = { c = { 16, 17, 20 }, cls = "base" }, boot = { c = { 14, 15, 17 }, cls = "base" }, accent = { c = { 53, 214, 255 }, cls = "base" }, dark = { c = { 27, 29, 34 }, cls = "base" }, lens = { c = { 10, 12, 16 }, cls = "base" }, blk = { c = { 22, 23, 26 }, cls = "base" }, gold = { c = { 243, 192, 64 }, cls = "base" }, glass = { c = { 154, 208, 255 }, cls = "glass" } } },
	["Ranger forêt"] = { web = 2, glow = false, metal = false, colors = { skin = { c = { 240, 200, 160 }, cls = "base" }, shirt = { c = { 95, 113, 53 }, cls = "base" }, pants = { c = { 82, 99, 47 }, cls = "base" }, vest = { c = { 60, 74, 42 }, cls = "base" }, helm = { c = { 58, 74, 42 }, cls = "base" }, glove = { c = { 42, 51, 32 }, cls = "base" }, boot = { c = { 58, 42, 26 }, cls = "base" }, accent = { c = { 255, 210, 74 }, cls = "base" }, dark = { c = { 27, 29, 34 }, cls = "base" }, lens = { c = { 10, 12, 16 }, cls = "base" }, blk = { c = { 22, 23, 26 }, cls = "base" }, gold = { c = { 243, 192, 64 }, cls = "base" }, glass = { c = { 154, 208, 255 }, cls = "glass" } } },
	["Patrouille polaire"] = { web = 3, glow = false, metal = false, colors = { skin = { c = { 240, 200, 160 }, cls = "base" }, shirt = { c = { 233, 238, 245 }, cls = "base" }, pants = { c = { 227, 234, 242 }, cls = "base" }, vest = { c = { 174, 189, 208 }, cls = "base" }, helm = { c = { 238, 243, 250 }, cls = "base" }, glove = { c = { 207, 217, 230 }, cls = "base" }, boot = { c = { 138, 153, 173 }, cls = "base" }, accent = { c = { 74, 163, 255 }, cls = "base" }, dark = { c = { 27, 29, 34 }, cls = "base" }, lens = { c = { 10, 12, 16 }, cls = "base" }, blk = { c = { 22, 23, 26 }, cls = "base" }, gold = { c = { 243, 192, 64 }, cls = "base" }, glass = { c = { 154, 208, 255 }, cls = "glass" } } },
	["Urbain"] = { web = 4, glow = false, metal = false, colors = { skin = { c = { 240, 200, 160 }, cls = "base" }, shirt = { c = { 91, 100, 112 }, cls = "base" }, pants = { c = { 76, 85, 96 }, cls = "base" }, vest = { c = { 42, 47, 54 }, cls = "base" }, helm = { c = { 47, 53, 61 }, cls = "base" }, glove = { c = { 21, 24, 29 }, cls = "base" }, boot = { c = { 21, 23, 26 }, cls = "base" }, accent = { c = { 255, 138, 42 }, cls = "base" }, dark = { c = { 27, 29, 34 }, cls = "base" }, lens = { c = { 10, 12, 16 }, cls = "base" }, blk = { c = { 22, 23, 26 }, cls = "base" }, gold = { c = { 243, 192, 64 }, cls = "base" }, glass = { c = { 154, 208, 255 }, cls = "glass" } } },
	["Pilote de course"] = { web = 5, glow = false, metal = false, colors = { skin = { c = { 240, 200, 160 }, cls = "base" }, shirt = { c = { 228, 135, 142 }, cls = "base" }, pants = { c = { 26, 26, 31 }, cls = "base" }, vest = { c = { 212, 26, 40 }, cls = "base" }, helm = { c = { 244, 244, 244 }, cls = "base" }, glove = { c = { 244, 244, 244 }, cls = "base" }, boot = { c = { 212, 26, 40 }, cls = "base" }, accent = { c = { 255, 210, 58 }, cls = "base" }, dark = { c = { 27, 29, 34 }, cls = "base" }, lens = { c = { 10, 12, 16 }, cls = "base" }, blk = { c = { 22, 23, 26 }, cls = "base" }, gold = { c = { 243, 192, 64 }, cls = "base" }, glass = { c = { 154, 208, 255 }, cls = "glass" } } },
	["Pirate"] = { web = 6, glow = false, metal = false, colors = { skin = { c = { 240, 200, 160 }, cls = "base" }, shirt = { c = { 134, 135, 142 }, cls = "base" }, pants = { c = { 90, 58, 34 }, cls = "base" }, vest = { c = { 106, 62, 34 }, cls = "base" }, helm = { c = { 196, 38, 28 }, cls = "base" }, glove = { c = { 58, 36, 18 }, cls = "base" }, boot = { c = { 42, 26, 14 }, cls = "base" }, accent = { c = { 255, 210, 74 }, cls = "base" }, dark = { c = { 27, 29, 34 }, cls = "base" }, lens = { c = { 10, 12, 16 }, cls = "base" }, blk = { c = { 22, 23, 26 }, cls = "base" }, gold = { c = { 243, 192, 64 }, cls = "base" }, glass = { c = { 154, 208, 255 }, cls = "glass" } } },
	["Chef étoilé"] = { web = 7, glow = false, metal = false, colors = { skin = { c = { 240, 200, 160 }, cls = "base" }, shirt = { c = { 246, 246, 246 }, cls = "base" }, pants = { c = { 50, 54, 66 }, cls = "base" }, vest = { c = { 222, 222, 222 }, cls = "base" }, helm = { c = { 255, 255, 255 }, cls = "base" }, glove = { c = { 255, 255, 255 }, cls = "base" }, boot = { c = { 26, 26, 26 }, cls = "base" }, accent = { c = { 224, 64, 42 }, cls = "base" }, dark = { c = { 27, 29, 34 }, cls = "base" }, lens = { c = { 10, 12, 16 }, cls = "base" }, blk = { c = { 22, 23, 26 }, cls = "base" }, gold = { c = { 243, 192, 64 }, cls = "base" }, glass = { c = { 154, 208, 255 }, cls = "glass" } } },
	["Samouraï"] = { web = 8, glow = false, metal = true, colors = { skin = { c = { 240, 200, 160 }, cls = "base" }, shirt = { c = { 168, 20, 28 }, cls = "base" }, pants = { c = { 28, 20, 23 }, cls = "base" }, vest = { c = { 42, 16, 20 }, cls = "base" }, helm = { c = { 138, 15, 22 }, cls = "base" }, glove = { c = { 20, 16, 15 }, cls = "base" }, boot = { c = { 20, 16, 15 }, cls = "base" }, accent = { c = { 255, 210, 74 }, cls = "base" }, dark = { c = { 27, 29, 34 }, cls = "base" }, lens = { c = { 10, 12, 16 }, cls = "base" }, blk = { c = { 22, 23, 26 }, cls = "base" }, gold = { c = { 243, 192, 64 }, cls = "base" }, glass = { c = { 154, 208, 255 }, cls = "glass" } } },
	["Cyber néon"] = { web = 9, glow = true, metal = false, colors = { skin = { c = { 240, 200, 160 }, cls = "base" }, shirt = { c = { 23, 26, 38 }, cls = "base" }, pants = { c = { 18, 21, 30 }, cls = "base" }, vest = { c = { 13, 15, 24 }, cls = "base" }, helm = { c = { 13, 15, 24 }, cls = "base" }, glove = { c = { 13, 15, 24 }, cls = "base" }, boot = { c = { 13, 15, 24 }, cls = "base" }, accent = { c = { 53, 240, 255 }, cls = "neon" }, dark = { c = { 27, 29, 34 }, cls = "base" }, lens = { c = { 10, 12, 16 }, cls = "base" }, blk = { c = { 22, 23, 26 }, cls = "base" }, gold = { c = { 243, 192, 64 }, cls = "base" }, glass = { c = { 154, 208, 255 }, cls = "glass" } } },
	["Astronaute"] = { web = 10, glow = false, metal = false, colors = { skin = { c = { 240, 200, 160 }, cls = "base" }, shirt = { c = { 242, 244, 248 }, cls = "base" }, pants = { c = { 230, 233, 240 }, cls = "base" }, vest = { c = { 255, 255, 255 }, cls = "base" }, helm = { c = { 242, 244, 248 }, cls = "base" }, glove = { c = { 255, 138, 42 }, cls = "base" }, boot = { c = { 207, 212, 222 }, cls = "base" }, accent = { c = { 255, 138, 42 }, cls = "base" }, dark = { c = { 27, 29, 34 }, cls = "base" }, lens = { c = { 10, 12, 16 }, cls = "base" }, blk = { c = { 22, 23, 26 }, cls = "base" }, gold = { c = { 243, 192, 64 }, cls = "base" }, glass = { c = { 154, 208, 255 }, cls = "glass" } } },
	["Roi doré"] = { web = 11, glow = false, metal = true, colors = { skin = { c = { 240, 200, 160 }, cls = "base" }, shirt = { c = { 216, 160, 40 }, cls = "base" }, pants = { c = { 122, 28, 42 }, cls = "base" }, vest = { c = { 240, 192, 64 }, cls = "base" }, helm = { c = { 240, 192, 64 }, cls = "base" }, glove = { c = { 246, 220, 122 }, cls = "base" }, boot = { c = { 122, 28, 42 }, cls = "base" }, accent = { c = { 255, 255, 255 }, cls = "base" }, dark = { c = { 27, 29, 34 }, cls = "base" }, lens = { c = { 10, 12, 16 }, cls = "base" }, blk = { c = { 22, 23, 26 }, cls = "base" }, gold = { c = { 243, 192, 64 }, cls = "base" }, glass = { c = { 154, 208, 255 }, cls = "glass" } } },
	["Licorne"] = { web = 12, glow = true, metal = false, colors = { skin = { c = { 240, 200, 160 }, cls = "base" }, shirt = { c = { 219, 200, 235 }, cls = "base" }, pants = { c = { 231, 204, 215 }, cls = "base" }, vest = { c = { 255, 255, 255 }, cls = "base" }, helm = { c = { 255, 208, 236 }, cls = "base" }, glove = { c = { 255, 255, 255 }, cls = "base" }, boot = { c = { 255, 176, 216 }, cls = "base" }, accent = { c = { 255, 106, 213 }, cls = "neon" }, dark = { c = { 27, 29, 34 }, cls = "base" }, lens = { c = { 10, 12, 16 }, cls = "base" }, blk = { c = { 22, 23, 26 }, cls = "base" }, gold = { c = { 243, 192, 64 }, cls = "base" }, glass = { c = { 154, 208, 255 }, cls = "glass" } } },
	["Robot chrome"] = { web = 13, glow = true, metal = true, colors = { skin = { c = { 240, 200, 160 }, cls = "base" }, shirt = { c = { 170, 180, 194 }, cls = "base" }, pants = { c = { 142, 152, 166 }, cls = "base" }, vest = { c = { 200, 208, 220 }, cls = "base" }, helm = { c = { 216, 223, 233 }, cls = "base" }, glove = { c = { 106, 116, 130 }, cls = "base" }, boot = { c = { 106, 116, 130 }, cls = "base" }, accent = { c = { 255, 59, 59 }, cls = "neon" }, dark = { c = { 27, 29, 34 }, cls = "base" }, lens = { c = { 10, 12, 16 }, cls = "base" }, blk = { c = { 22, 23, 26 }, cls = "base" }, gold = { c = { 243, 192, 64 }, cls = "base" }, glass = { c = { 154, 208, 255 }, cls = "glass" } } },
	["Tête de citrouille"] = { web = 14, glow = true, metal = false, colors = { skin = { c = { 240, 200, 160 }, cls = "base" }, shirt = { c = { 129, 65, 25 }, cls = "base" }, pants = { c = { 26, 18, 24 }, cls = "base" }, vest = { c = { 42, 26, 42 }, cls = "base" }, helm = { c = { 232, 112, 26 }, cls = "base" }, glove = { c = { 26, 18, 24 }, cls = "base" }, boot = { c = { 18, 12, 16 }, cls = "base" }, accent = { c = { 255, 176, 48 }, cls = "neon" }, dark = { c = { 27, 29, 34 }, cls = "base" }, lens = { c = { 10, 12, 16 }, cls = "base" }, blk = { c = { 22, 23, 26 }, cls = "base" }, gold = { c = { 243, 192, 64 }, cls = "base" }, glass = { c = { 154, 208, 255 }, cls = "glass" } } },
	["Faucheuse"] = { web = 15, glow = true, metal = false, colors = { skin = { c = { 240, 200, 160 }, cls = "base" }, shirt = { c = { 14, 12, 18 }, cls = "base" }, pants = { c = { 14, 12, 18 }, cls = "base" }, vest = { c = { 22, 19, 28 }, cls = "base" }, helm = { c = { 14, 12, 18 }, cls = "base" }, glove = { c = { 232, 224, 208 }, cls = "base" }, boot = { c = { 10, 9, 12 }, cls = "base" }, accent = { c = { 109, 255, 122 }, cls = "neon" }, dark = { c = { 27, 29, 34 }, cls = "base" }, lens = { c = { 10, 12, 16 }, cls = "base" }, blk = { c = { 22, 23, 26 }, cls = "base" }, gold = { c = { 243, 192, 64 }, cls = "base" }, glass = { c = { 154, 208, 255 }, cls = "glass" } } },
}
-- couleurs des joueurs (PALETTE) et teints de peau (SKIN_TONES) du jeu web
Rig.PALETTE = { "#e74c3c", "#3498db", "#2ecc71", "#f1c40f", "#9b59b6", "#e67e22", "#1abc9c", "#ff6bd6", "#ecf0f1", "#95a5a6", "#d35400", "#16a085" }
Rig.TONES = { "#f0c8a0", "#d9a577", "#b5835a", "#8a5a3b", "#e8b896", "#6f452c" }
return Rig
