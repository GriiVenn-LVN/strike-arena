--!strict
-- ReplicatedStorage/Shared/Attachments (ModuleScript, client + serveur)
-- Armurier façon Gunsmith (src/64b_gunsmith.js) et viseurs (src/64c_sights.js) du jeu web, à l'identique :
-- 6 emplacements, 5 accessoires max, déblocage par niveau ET éliminations avec l'arme, effets réels (multiplicateurs).
-- Sélection d'une arme : sel = { muzzle = "sil", optic = "reddot", ... } ; le serveur ne recopie dans l'attribut
-- Att_<arme> du joueur que les accessoires réellement débloqués (format « muzzle=sil,optic=reddot »).
local A = {}

A.MAX = 5
A.SLOTS = {
	{ id = "muzzle", n = "Bouche", ic = "◉" }, { id = "optic", n = "Optique", ic = "◎" }, { id = "barrel", n = "Canon", ic = "▬" },
	{ id = "under", n = "Sous-canon", ic = "▼" }, { id = "mag", n = "Chargeur", ic = "▮" }, { id = "stock", n = "Crosse", ic = "◣" },
}

-- m : multiplicateurs. rec = recul vertical, recH = horizontal, adsSpr = dispersion en visée, hip = à la hanche,
-- mob = vitesse de déplacement, ads = vitesse de visée, rng = portée efficace, rel = rechargement, mag = chargeur, snd = volume du tir
export type Att = { s: string, n: string, lv: number, d: string, m: { [string]: number }, sil: boolean?, noFlash: boolean?, ov: boolean? }
A.ATTS = {
	sil = { s = "muzzle", n = "Silencieux", lv = 1, d = "Tir discret : son très réduit, les ennemis vous entendent de moins loin, pas de flamme.", m = { snd = .35, rng = .9, ads = .95, dmg = .95 }, sil = true, noFlash = true },
	comp = { s = "muzzle", n = "Compensateur", lv = 2, d = "Canalise les gaz vers le haut : recul vertical réduit.", m = { rec = .85, ads = .97 } },
	brake = { s = "muzzle", n = "Frein de bouche", lv = 3, d = "Gaz sur les côtés : recul horizontal fortement réduit, tir plus bruyant.", m = { recH = .68, snd = 1.15 } },
	flash = { s = "muzzle", n = "Cache-flamme", lv = 1, d = "Masque la flamme de bouche, léger gain de stabilité.", m = { rec = .95 }, noFlash = true },
	reddot = { s = "optic", n = "Point rouge", lv = 1, d = "Visée nette et dégagée : dispersion en visée -25 %.", m = { adsSpr = .75, zoom = 1.55 } },
	holo = { s = "optic", n = "Holographique", lv = 2, d = "Réticule cerclé, grande fenêtre : dispersion en visée -20 %, visée plus rapide.", m = { adsSpr = .8, ads = 1.05, zoom = 1.5 } },
	mini = { s = "optic", n = "Mini réflex", lv = 1, d = "Petit viseur ouvert, très léger : visée plus rapide, dispersion en visée -15 %.", m = { adsSpr = .85, ads = 1.08, zoom = 1.42 } },
	acog = { s = "optic", n = "Lunette ×2,5", lv = 4, d = "Grossissement ×2,5 pour la moyenne distance. Visée plus lente.", m = { adsSpr = .7, ads = .85, zoom = 1.9 } },
	sc4 = { s = "optic", n = "Lunette ×4", lv = 3, d = "Lunette de précision ×4 : vue plein écran en visée, idéale à longue distance. Visée lente.", m = { adsSpr = .6, ads = .78, mob = .97, zoom = 2.4 }, ov = true },
	sc6 = { s = "optic", n = "Lunette ×6", lv = 5, d = "Grossissement ×6 : pour tenir une longue ligne. Visée lente.", m = { adsSpr = .55, ads = .72, mob = .96, zoom = 3.1 }, ov = true },
	sc8 = { s = "optic", n = "Lunette ×8", lv = 6, d = "Grossissement ×8 pour les très longues distances.", m = { ads = .95, zoom = 3.8 }, ov = true },
	sc10 = { s = "optic", n = "Lunette ×10", lv = 8, d = "Grossissement maximal ×10. Visée plus lente, champ de vision très étroit.", m = { ads = .88, zoom = 4.8 }, ov = true },
	long = { s = "barrel", n = "Canon long", lv = 3, d = "Portée efficace +30 %, balles plus précises. Arme plus lourde.", m = { rng = 1.3, hip = .92, adsSpr = .92, mob = .96, ads = .92 } },
	heavy = { s = "barrel", n = "Canon lourd", lv = 5, d = "Recul -12 %, portée +10 %. Mobilité réduite.", m = { rec = .88, recH = .9, rng = 1.1, mob = .93, ads = .9 } },
	grip = { s = "under", n = "Poignée verticale", lv = 2, d = "Meilleure tenue : recul -18 %.", m = { rec = .82, recH = .85, ads = .96 } },
	angled = { s = "under", n = "Poignée inclinée", lv = 3, d = "Épaulement rapide : vitesse de visée +20 %.", m = { ads = 1.2, rec = .94 } },
	laser = { s = "under", n = "Laser tactique", lv = 4, d = "Précision à la hanche +30 %, visée plus rapide. Le laser est visible.", m = { hip = .7, ads = 1.06 } },
	ext = { s = "mag", n = "Chargeur étendu", lv = 2, d = "+30 % de munitions par chargeur. Rechargement un peu plus lent.", m = { mag = 1.3, rel = 1.12, mob = .98 } },
	fast = { s = "mag", n = "Chargeurs jumelés", lv = 3, d = "Deux chargeurs scotchés : rechargement -30 %.", m = { rel = .7 } },
	light = { s = "stock", n = "Crosse squelette", lv = 4, d = "Mobilité +7 %, visée plus rapide. Un peu plus de recul.", m = { mob = 1.07, ads = 1.08, rec = 1.08 } },
	tac = { s = "stock", n = "Crosse tactique", lv = 5, d = "Crosse rembourrée : recul -10 %. Mobilité réduite.", m = { rec = .9, recH = .92, mob = .96 } },
} :: { [string]: Att }
-- ordre d'affichage (le web suit l'ordre de déclaration de ATTS)
A.ORDER = { "sil", "comp", "brake", "flash", "reddot", "holo", "mini", "acog", "sc4", "sc6", "sc8", "sc10", "long", "heavy", "grip", "angled", "laser", "ext", "fast", "light", "tac" }

-- emplacements autorisés par catégorie (nil = tous les accessoires de l'emplacement)
A.CAT = {
	pistol = { muzzle = { "sil", "comp", "flash" }, optic = { "reddot" }, under = { "laser" }, mag = { "ext", "fast" } },
	shotgun = { muzzle = { "brake", "flash" }, optic = { "reddot", "holo" }, barrel = { "long" }, under = { "grip", "laser" }, mag = { "ext", "fast" }, stock = { "light", "tac" } },
	sniper = { muzzle = { "sil", "brake", "flash" }, barrel = { "long", "heavy" }, under = { "grip", "laser" }, mag = { "ext", "fast" }, stock = { "light", "tac" } },
} :: { [string]: { [string]: { string } } }
-- viseurs proposés par catégorie (« aucun » = mires d'origine, ou lunette d'origine des snipers)
A.OPTIC_CAT = {
	pistol = { "mini", "reddot", "holo" }, smg = { "mini", "reddot", "holo", "acog" }, shotgun = { "mini", "reddot", "holo" },
	rifle = { "reddot", "holo", "acog", "sc4", "sc6" }, lmg = { "reddot", "holo", "acog", "sc4" }, sniper = { "sc4", "sc6", "sc8", "sc10" },
} :: { [string]: { string } }

-- déblocage réaliste : niveau du joueur ET éliminations avec CETTE arme
local REQ = { [1] = { 3, 15 }, [2] = { 6, 40 }, [3] = { 9, 80 }, [4] = { 12, 130 }, [5] = { 15, 200 }, [6] = { 18, 280 }, [8] = { 24, 450 } }
function A.req(a: string): (number, number)
	local d = A.ATTS[a]
	local r = REQ[d.lv]
	if r then return r[1], r[2] end
	return d.lv * 3, d.lv * 55
end

-- web : W[k] (stats de l'arme) ; données qui manquent à Config.WEAPONS : chute des dégâts (fo, fr, fmin)
A.FALLOFF = {
	glock = { 15, .012 }, usp = { 15, .012 }, p250 = { 15, .012 }, fiveseven = { 18, .011 }, deagle = { 20, .01 },
	mac10 = { 10, .014 }, mp9 = { 12, .012 }, ump = { 15, .011 }, p90 = { 14, .012 },
	nova = { 5, .07, .1 }, sawedoff = { 4, .09, .08 }, xm = { 5, .07, .1 },
	galil = { 40, .004 }, famas = { 40, .004 }, ak = { 50, .003 }, m4 = { 50, .003 }, sg553 = { 50, .003 }, aug = { 50, .003 },
	ssg = { 90, .001 }, awp = { 120, .001 }, scar = { 90, .001 }, negev = { 40, .004 }, m249 = { 45, .003 },
} :: { [string]: { number } }
A.RUN = 5.2                                         -- vitesse de course du web (m/s)
A.ADS_ZOOM = { pistol = 1.2, smg = 1.3, shotgun = 1.18, rifle = 1.4, lmg = 1.3, sniper = 1, melee = 1 } :: { [string]: number }

local Config = require(script.Parent.Config)
local function W(k: string): any return Config.WEAPONS[k] end

export type Sel = { [string]: string }

function A.allowed(k: string): { [string]: { string } }
	local w = W(k)
	local out = {}
	if not w or w.melee then return out end
	local lim = A.CAT[w.cat]
	for _, s in ipairs(A.SLOTS) do
		local l: { string }
		if s.id == "optic" and A.OPTIC_CAT[w.cat] then l = A.OPTIC_CAT[w.cat]
		elseif lim == nil then
			l = {}
			for _, a in ipairs(A.ORDER) do if A.ATTS[a].s == s.id then table.insert(l, a) end end
		else l = lim[s.id] or {} end
		if #l > 0 then out[s.id] = l end
	end
	return out
end

-- progression : { level = n, kills = { [arme] = n } } (profil côté serveur, GetProfile côté client)
export type Prog = { level: number, kills: { [string]: number } }
function A.isOpen(k: string, a: string, p: Prog?): boolean
	if not p then return false end
	local lv, n = A.req(a)
	return p.level >= lv and (p.kills[k] or 0) >= n
end
function A.lockText(k: string, a: string, p: Prog?): string
	local lv, n = A.req(a)
	local have = p and (p.kills[k] or 0) or 0
	local o = {}
	if not p or p.level < lv then table.insert(o, "niveau " .. lv) end
	if have < n then table.insert(o, n .. " éliminations avec cette arme (" .. have .. "/" .. n .. ")") end
	return if #o > 0 then "Requis : " .. table.concat(o, " + ") else ""
end

-- accessoires actifs (respecte la catégorie ; p = nil : pas de contrôle du déblocage, déjà fait par le serveur)
function A.list(k: string, sel: Sel?, p: Prog?, skipLock: boolean?): { string }
	local ok, out = A.allowed(k), {}
	if not sel then return out end
	for _, s in ipairs(A.SLOTS) do
		local a = sel[s.id]
		if a and A.ATTS[a] and A.ATTS[a].s == s.id and ok[s.id] and table.find(ok[s.id], a) and (skipLock or A.isOpen(k, a, p)) then table.insert(out, a) end
	end
	return out
end
function A.count(sel: Sel): number
	local n = 0
	for _ in pairs(sel) do n += 1 end
	return n
end

export type Mods = { dmg: number, rec: number, recH: number, adsSpr: number, hip: number, mob: number, ads: number, rng: number, rel: number, mag: number, snd: number, zoom: number, sil: boolean, noFlash: boolean }
function A.neutral(): Mods
	return { dmg = 1, rec = 1, recH = 1, adsSpr = 1, hip = 1, mob = 1, ads = 1, rng = 1, rel = 1, mag = 1, snd = 1, zoom = 0, sil = false, noFlash = false }
end
function A.modsOf(list: { string }): Mods
	local r: any = A.neutral()
	for _, a in ipairs(list) do
		local d = A.ATTS[a]
		if d then
			for x, v in pairs(d.m) do if x == "zoom" then r.zoom = v else r[x] *= v end end
			if d.sil then r.sil = true end
			if d.noFlash then r.noFlash = true end
		end
	end
	return r
end

-- ---------- attributs Att_<arme> ----------
function A.encode(sel: Sel): string
	local o = {}
	for _, s in ipairs(A.SLOTS) do if sel[s.id] then table.insert(o, s.id .. "=" .. sel[s.id]) end end
	return table.concat(o, ",")
end
function A.decode(str: any): Sel
	local sel: Sel = {}
	if typeof(str) ~= "string" then return sel end
	for slot, a in string.gmatch(str, "(%w+)=(%w+)") do sel[slot :: string] = a :: string end
	return sel
end
-- accessoires actifs d'un joueur (ou d'une poignée HeldWeapon) d'après son attribut, déjà filtré par le serveur
function A.activeOf(inst: Instance?, k: string): { string }
	if not inst then return {} end
	return A.list(k, A.decode(inst:GetAttribute("Att_" .. k)), nil, true)
end
function A.optOf(list: { string }): string?
	for _, a in ipairs(list) do if A.ATTS[a].s == "optic" then return a end end
	return nil
end

-- ---------- viseurs ----------
-- visée plein écran ? (lunettes, ou sniper sans optique)
function A.sightOv(k: string, list: { string }): boolean
	local o = A.optOf(list)
	if o then return A.ATTS[o].ov == true end
	local w = W(k)
	return w ~= nil and w.cat == "sniper"
end
function A.sightZoom(k: string, m: Mods): number
	local w = W(k)
	if m.zoom > 0 then return m.zoom end
	if w and (w.zoom or 0) > 0 then return w.zoom end
	return A.ADS_ZOOM[w and w.cat or "rifle"] or 1.1
end
function A.opticNone(k: string): string
	local w = W(k)
	return if w and w.cat == "sniper" then "Lunette d'origine" else "Mires d'origine"
end
function A.zoomText(k: string, o: string?): string
	if o then
		if o:sub(1, 2) == "sc" then return "×" .. o:sub(3) end
		return if o == "acog" then "×2,5" else ""
	end
	local w = W(k)
	return if w and w.cat == "sniper" then "×" .. math.floor(w.zoom * 2 + 0.5) else ""
end

A.RET_SHAPES = { { "dot", "Point" }, { "circle", "Cercle" }, { "cross", "Croix" }, { "chevron", "Chevron" }, { "duplex", "Duplex" }, { "mildot", "Mil-dot" } }
A.RET_COLS = { "#ff2a3a", "#3dff6e", "#33e0ff", "#ffe03a", "#ff4fd8", "#ffffff", "#101010" }
-- « scope » = lunette d'origine des snipers
A.RET_DEF = {
	reddot = { s = "dot", c = "#ff2a3a" }, mini = { s = "dot", c = "#ff2a3a" }, holo = { s = "circle", c = "#ff2a3a" }, acog = { s = "chevron", c = "#ff3a2a" },
	sc4 = { s = "duplex", c = "#101010" }, sc6 = { s = "duplex", c = "#101010" }, sc8 = { s = "mildot", c = "#101010" }, sc10 = { s = "mildot", c = "#101010" },
	scope = { s = "cross", c = "#101010" },
} :: { [string]: { s: string, c: string } }
-- réticule choisi : attribut Ret_<optique> = "forme|#couleur" sur le joueur
function A.retOf(o: string, inst: Instance?): (string, string)
	local d = A.RET_DEF[o] or A.RET_DEF.reddot
	local s, c = d.s, d.c
	local raw = inst and inst:GetAttribute("Ret_" .. o)
	if typeof(raw) == "string" then
		local s2, c2 = string.match(raw, "^(%w+)|(#%x+)$")
		if s2 then s = s2 end
		if c2 then c = c2 end
	end
	return s, c
end
function A.validRet(shape: any, col: any): boolean
	local okS = false
	for _, r in ipairs(A.RET_SHAPES) do if r[1] == shape then okS = true end end
	return okS and typeof(col) == "string" and table.find(A.RET_COLS, col) ~= nil
end

-- ---------- statistiques de l'armurier (gsStatsHTML du web) ----------
-- renvoie { libellé, fonction(mods) -> valeur, max, format, sens } ; sens 1 = plus c'est mieux, -1 = moins, 0 = neutre
function A.statRows(k: string): { { any } }
	local w = W(k)
	local fo = A.FALLOFF[k] and A.FALLOFF[k][1] or 40
	local overlay = w.cat == "sniper"
	local function cl(x: number): number return math.clamp(x, 0, 100) end
	local function pct(v: number) return math.floor(v + 0.5) .. "%" end
	local rows: { { any } } = {
		{ "DÉGÂTS", function(m: Mods) return w.dmg * (w.pellets or 1) * m.dmg end, 150, function(v: number) return math.floor(v + 0.5) .. (if (w.pellets or 1) > 1 then "×" else "") end, 1 },
		{ "CADENCE", function(_m: Mods) return w.rpm end, 1000, function(v: number) return tostring(math.floor(v + 0.5)) end, 1 },
		{ "CHARGEUR", function(m: Mods) return math.ceil(w.mag * m.mag) end, 150, function(v: number) return tostring(v) end, 1 },
		{ "PRÉCISION", function(m: Mods) return cl(100 - w.spread * 14 * m.hip) end, 100, pct, 1 },
		{ "VISÉE", function(m: Mods) return cl(100 - (w.spread * 14 * m.adsSpr * .6) - (1 - m.ads) * 30 - (if overlay then 15 else 0)) end, 100, pct, 1 },
		{ "CONTRÔLE", function(m: Mods) return cl(100 - w.recoil * 40 * (m.rec * .7 + m.recH * .3)) end, 100, pct, 1 },
		{ "PORTÉE", function(m: Mods) return fo * m.rng * 1.2 end, 120, function(v: number) return math.floor(v + 0.5) .. " m" end, 1 },
		{ "MOBILITÉ", function(m: Mods) return A.RUN * w.speed * m.mob end, 6.5, function(v: number) return string.format("%.1f m/s", v) end, 1 },
		{ "RECHARGEMENT", function(m: Mods) return w.reload * m.rel end, 5, function(v: number) return string.format("%.1f s", v) end, -1 },
		{ "PRIX", function(_m: Mods) return w.price end, 5200, function(v: number) return "$" .. v end, 0 },
	}
	return rows
end

return A
