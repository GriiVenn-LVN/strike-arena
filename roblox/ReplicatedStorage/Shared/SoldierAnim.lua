--!strict
-- ReplicatedStorage/Shared/SoldierAnim (ModuleScript, côté client)
-- Animation procédurale des soldats, port direct du jeu web :
--   src/45_models.js animateSoldier (marche/course depuis la vitesse, accroupi, saut, visée, recharge, mort, places assises)
--   src/45_models.js danceAnim (8 danses), src/8T_anim.js (sprint, sprint tactique, glissade, escalade, chute, réception, poids)
-- En plus, façon Call of Duty : recharge en étapes vue de l'extérieur (main gauche au chargeur, à la poche, retour,
-- claque) et escalade en deux temps (mains qui agrippent le rebord au-dessus de la tête, puis poussent quand le corps monte).
-- Tout est calculé en mètres dans le repère du soldat (pieds en 0, regard vers -Z, droite vers +X : mêmes axes que three.js).
-- step(R, st, dt, t) renvoie la pose : repères des groupes (bassin, buste, cou, tête, jambes), arme et cibles des mains.
local Anim = {}

local sin, cos, abs, max, min, exp, pi = math.sin, math.cos, math.abs, math.max, math.min, math.exp, math.pi
local function clamp(x: number, a: number, b: number): number return if x < a then a elseif x > b then b else x end
local function smooth01(x: number): number x = clamp(x, 0, 1); return x * x * (3 - 2 * x) end
local function lerp(a: number, b: number, t: number): number return a + (b - a) * t end
local function angDiff(a: number, b: number): number local d = (b - a) % (2 * pi); if d > pi then d -= 2 * pi end; return d end
local V = Vector3.new
local function E(x: number, y: number, z: number): CFrame return CFrame.Angles(x, y, z) end   -- Euler XYZ de three.js

-- bits d'animation (attribut « Anim » des joueurs, envoyés par SoldierController) : mêmes rôles que AN du web
Anim.SLIDE, Anim.SPR, Anim.TAC, Anim.MANT, Anim.CROUCH, Anim.AIM = 1, 2, 4, 16, 64, 128

local DOWN = V(0, -1, 0)
local FWD = V(0, 0, -1)
local fromTo: (Vector3, Vector3) -> CFrame
do
	fromTo = function(a: Vector3, b: Vector3): CFrame
		local d = a:Dot(b)
		if d > 0.999999 then return CFrame.identity end
		if d < -0.999999 then
			local ax = a:Cross(Vector3.xAxis)
			if ax.Magnitude < 1e-3 then ax = a:Cross(Vector3.yAxis) end
			return CFrame.fromAxisAngle(ax.Unit, pi)
		end
		return CFrame.fromAxisAngle(a:Cross(b).Unit, math.acos(d))
	end
end
Anim.fromTo = fromTo

-- IK à deux segments (ik2 du web) : renvoie le coude et la main atteinte (bras tendu au maximum si trop loin)
function Anim.ik2(S: Vector3, H: Vector3, la: number, lb: number, pole: Vector3): (Vector3, Vector3)
	local u = H - S
	local L = u.Magnitude
	local mx, mn = la + lb - 0.002, abs(la - lb) + 0.002
	u = if L > 1e-6 then u / L else DOWN
	L = clamp(L, mn, mx)
	local cosA = clamp((la * la + L * L - lb * lb) / (2 * la * L), -1, 1)
	local sinA = math.sqrt(1 - cosA * cosA)
	local pp = pole - u * pole:Dot(u)
	pp = if pp.Magnitude > 1e-3 then pp.Unit else DOWN
	return S + u * (la * cosA) + pp * (la * sinA), S + u * L
end

-- poses fixes de l'arme (8T_anim.js)
local SPR_Q, TAC_Q, SLD_Q, MNT_Q = E(0.32, 1.05, 0.3), E(1.3, 0.25, -0.15), E(-0.6, 0.12, -0.3), E(-1.25, 0.2, 0.3)

export type Rot = { x: number, y: number, z: number }
export type Leg = { th: Rot, sh: Rot, ft: Rot }
export type State = { [string]: any }
export type Input = {
	speed: number, lf: number, lr: number, yaw: number, pitch: number, onGround: boolean, vy: number,
	crouch: boolean, bits: number, alive: boolean, ready: boolean, alert: number, hurt: boolean, fire: number,
	reload: number, reloadMax: number, dance: string?, danceT: number, seated: number, dieDir: number,
	right: Vector3, left: Vector3?,        -- mains sur l'arme (m, repère de l'arme ; left = nil : arme à une main)
}
export type Pose = {
	root: CFrame, hips: CFrame, spine: CFrame, neck: CFrame, head: CFrame,
	th: { L: CFrame, R: CFrame }, sh: { L: CFrame, R: CFrame }, ft: { L: CFrame, R: CFrame },
	gun: CFrame, gunVisible: boolean,
	-- bras (repère du buste) : épaule, coude, cible de la main, orientation de la main, pôle du coude
	arm: { [string]: { S: Vector3, E: Vector3, H: Vector3, q: CFrame, pole: Vector3 } },
}

local function rot(): Rot return { x = 0, y = 0, z = 0 } end
function Anim.new(seed: number): State
	return {
		ph = seed % 628 / 100, ck = 0, ready = 0.4, rec = 0, flinch = 0, dieT = -1, dieStyle = 0, swT = 0,
		ks = 0, fw = 0, sd = 0, lyaw = nil, turn = 0, aw = nil,
		hipsP = V(0, 0.94, 0), hipsR = rot(), spineP = V(0, 0.07, 0), spineR = rot(), neckR = rot(), headR = rot(),
		legs = { L = { th = rot(), sh = rot(), ft = rot() }, R = { th = rot(), sh = rot(), ft = rot() } },
		rootR = rot(), rootY = 0, rootYaw = 0,
		poles = { L = V(-0.55, -0.8, 0.25), R = V(0.55, -0.8, 0.25) },
	}
end

local S0 = { L = V(-0.215, 0.44, 0), R = V(0.215, 0.44, 0) }
local LA, LB = 0.29, 0.27

local function setR(r: Rot, x: number, y: number, z: number) r.x = x; r.y = y; r.z = z end

-- bras : épaule -> coude -> main dans le repère du buste ; handQ = orientation de la main (nil : suit l'avant-bras)
local function armTo(out: { [string]: any }, R: State, k: string, tgt: Vector3, handQ: CFrame?)
	local Sv = S0[k]
	local el, _ = Anim.ik2(Sv, tgt, LA, LB, R.poles[k])
	local q = handQ
	if not q then
		local d = tgt - el
		q = fromTo(FWD, if d.Magnitude > 1e-5 then d.Unit else DOWN)
	end
	out[k] = { S = Sv, E = el, H = tgt, q = q :: CFrame, pole = R.poles[k] }
end

local function armsFromGun(out: { [string]: any }, R: State, st: Input, gp: Vector3, gq: CFrame, leftDown: number)
	local tR = gp + gq:VectorToWorldSpace(st.right)
	local tL: Vector3
	if st.left then tL = gp + gq:VectorToWorldSpace(st.left :: Vector3) - V(0, leftDown, 0) else tL = V(-0.2, 0, 0.1) end
	armTo(out, R, "R", tR, gq)
	armTo(out, R, "L", tL, if st.left then nil else gq)
end

-- ---------- danses (danceAnim du web) ----------
local function dance(R: State, st: Input, out: { [string]: any })
	local id, tt = st.dance :: string, st.danceT
	local hips, legs = R.hipsR, R.legs
	R.hipsP = V(0, 0.94, 0); setR(hips, 0, 0, 0); setR(R.spineR, 0, 0, 0); setR(R.neckR, 0, 0, 0); setR(R.headR, 0, 0, 0)
	R.spineP = V(0, 0.07, 0); setR(R.rootR, 0, 0, 0); R.rootY = 0; R.rootYaw = 0
	for _, k in ipairs({ "L", "R" }) do setR(legs[k].th, 0, 0, 0); setR(legs[k].sh, 0, 0, 0); setR(legs[k].ft, 0, 0, 0) end
	local tR, tL = V(0.25, 0.12, -0.1), V(-0.25, 0.12, -0.1)
	local b = tt * 8
	if id == "wave" then
		tR = V(0.32 + sin(b * 1.2) * 0.13, 0.93, -0.05); tL = V(-0.22, 0.13, -0.02)
		R.spineR.z = -0.06 + sin(tt * 2) * 0.03; R.headR.z = 0.1 * sin(tt * 2); hips.z = sin(tt * 3) * 0.03; legs.R.th.x = 0.04
	elseif id == "clap" then
		local ph = abs(sin(tt * 9))
		tR = V(0.04 + ph * 0.15, 0.38, -0.34); tL = V(-0.04 - ph * 0.15, 0.38, -0.34); R.hipsP = V(0, 0.94 - ph * 0.03, 0)
		legs.L.th.x = 0.15; legs.R.th.x = 0.15; legs.L.sh.x = -0.2; legs.R.sh.x = -0.2; R.headR.x = 0.1
	elseif id == "disco" then
		local beat, sw = math.floor(tt * 2.5) % 2, sin(tt * 5)
		tR = if beat == 1 then V(0.3, 1.0, -0.02) else V(-0.12, 0.05, -0.2); tL = V(-0.28, 0.14, 0.02)
		hips.z = sw * 0.12; R.spineR.z = -sw * 0.14; R.hipsP = V(sw * 0.06, 0.94, 0); R.headR.z = sw * 0.1
		legs.R.th.x = 0.25 + sw * 0.25; legs.L.th.x = 0.25 - sw * 0.25; legs.R.sh.x = -0.3; legs.L.sh.x = -0.3
	elseif id == "robot" then
		local stp = math.floor(tt * 2.5) % 4 + 1
		local rs = { V(0.45, 0.45, 0), V(0.25, 0.92, -0.1), V(0.4, 0.45, -0.45), V(0.2, 0.2, -0.1) }
		local ls = { V(-0.2, 0.92, -0.1), V(-0.45, 0.45, 0), V(-0.2, 0.2, -0.1), V(-0.4, 0.45, -0.45) }
		tR = rs[stp]; tL = ls[stp]; R.headR.y = ({ 0, 0.6, 0, -0.6 })[stp]; R.spineR.y = ({ 0, 0.2, 0, -0.2 })[stp]
		legs.L.th.x = 0.1; legs.R.th.x = 0.1
	elseif id == "floss" then
		local sw = sin(tt * 7)
		tR = V(0.25 + sw * 0.3, 0.16, -0.12 - sw * 0.3); tL = V(-0.25 + sw * 0.3, 0.16, -0.12 + sw * 0.3)
		hips.y = -sw * 0.38; R.hipsP = V(sw * 0.05, 0.94 - 0.05, 0)
		for _, k in ipairs({ "L", "R" }) do legs[k].th.x = 0.3; legs[k].sh.x = -0.45 end
		R.headR.y = sw * 0.2
	elseif id == "twist" then
		tR = V(0.62, 0.5, 0); tL = V(-0.62, 0.5, 0); R.rootYaw = tt * 7; R.rootY = abs(sin(tt * 5)) * 0.1; R.hipsP = V(0, 0.94 - 0.04, 0)
		for _, k in ipairs({ "L", "R" }) do legs[k].th.x = 0.25; legs[k].sh.x = -0.4 end
	elseif id == "moonwalk" then
		local ph = tt * 3
		tR = V(0.3, 0.86, -0.16); tL = V(-0.2, 0.14, 0); R.spineR.x = 0.12
		legs.R.th.x = sin(ph) * 0.28; legs.L.th.x = -sin(ph) * 0.28; legs.R.sh.x = -max(0, sin(ph)) * 0.5; legs.L.sh.x = -max(0, -sin(ph)) * 0.5
		R.hipsP = V(0, 0.94, min(tt * 0.12, 0.5)); R.headR.z = 0.06
	elseif id == "break_" or id == "break" then
		R.rootR.x = -1.52; R.rootY = 0.2; R.rootYaw = tt * 8
		tR = V(0.5, 0.15, -0.35); tL = V(-0.5, 0.15, -0.35)
		legs.L.th.x = 1.1 + sin(tt * 6) * 0.55; legs.R.th.x = 1.1 - sin(tt * 6) * 0.55; legs.L.sh.x = -0.3; legs.R.sh.x = -0.3
	end
	armTo(out, R, "R", tR, nil); armTo(out, R, "L", tL, nil)
end

-- ---------- couche 8T_anim.js : sprint, glissade, escalade, chute, réception ----------
local function layer(R: State, st: Input, dt: number, gp: Vector3, gq: CFrame, arms: { [string]: any }): (Vector3, CFrame)
	local b = st.bits
	local w = R.aw
	if not w then
		w = { spr = 0, tac = 0, sld = 0, mnt = 0, mntT = 0, air = 0, lnd = 0, lv = 0, acc = 0, pfw = 0, og = true, vy = 0, fall = 0 }
		R.aw = w
	end
	local function has(f: number): boolean return bit32.band(b, f) ~= 0 end
	local f, fs = 1 - exp(-dt * 10), 1 - exp(-dt * 16)
	local mant = has(Anim.MANT)
	local air = not st.onGround and not mant
	w.spr += ((if has(Anim.SPR) and not has(Anim.TAC) then 1 else 0) - w.spr) * f
	w.tac += ((if has(Anim.TAC) then 1 else 0) - w.tac) * f
	w.sld += ((if has(Anim.SLIDE) then 1 else 0) - w.sld) * fs
	w.mnt += ((if mant then 1 else 0) - w.mnt) * fs
	w.mntT = if mant then w.mntT + dt else 0           -- temps depuis le début de l'escalade (le geste n'est pas envoyé)
	w.air += ((if air then 1 else 0) - w.air) * (1 - exp(-dt * 12))
	w.vy += (st.vy - w.vy) * min(1, dt * 10)
	-- réception : ressort amorti, d'autant plus fort que la chute est rapide
	if st.onGround and not w.og and w.fall < -3 then w.lv -= min(9, -w.fall * 0.9) end
	w.fall = if st.onGround then 0 else min(w.fall, w.vy)
	w.og = st.onGround
	do
		local sd = min(dt, 0.033)
		w.lv += (-w.lnd * 160 - w.lv * 15) * sd
		w.lnd = clamp(w.lnd + w.lv * sd, -1, 0.15)
	end
	local land = max(0, -w.lnd)
	local fwv = R.fw
	w.acc += (clamp((fwv - w.pfw) / max(dt, 1e-3) * 0.08, -1, 1) - w.acc) * (1 - exp(-dt * 6)); w.pfw = fwv
	local ph = R.ph
	local Sg, T, L, Mn = w.spr * (1 - w.sld), w.tac * (1 - w.sld), w.sld, w.mnt
	local A = w.air * (1 - Mn) * (1 - L)
	local legs, hr = R.legs, R.hipsR
	local hy = R.hipsP.Y
	if Sg + T > 0.01 then
		local g = Sg + T * 1.15
		for _, k in ipairs({ "L", "R" }) do legs[k].th.x *= 1 + 0.4 * g; legs[k].sh.x *= 1 + 0.35 * g end
		hy = hy - 0.03 * g + abs(sin(ph)) * 0.025 * g
	end
	if A > 0.01 then
		local up = clamp(w.vy / 5, -1, 1)
		local r, dn = max(up, 0), max(-up, 0)
		for _, k in ipairs({ "L", "R" }) do
		local side: number = if k == "L" then -1 else 1
			local Lg = legs[k]
			local th = 0.25 + r * 0.75 + (if side > 0 then 0.25 else -0.1) * r - dn * 0.05
			local sh = -0.35 - r * 1.15 - (if side > 0 then 0.3 else 0) * r - dn * 0.05
			Lg.th.x += (th - Lg.th.x) * A; Lg.sh.x += (sh - Lg.sh.x) * A; Lg.ft.x += (0.2 + r * 0.25 - Lg.ft.x) * A; Lg.th.z += (-side * 0.06 * dn) * A
		end
	end
	if land > 0.001 then
		for _, k in ipairs({ "L", "R" }) do legs[k].th.x += land * 0.75; legs[k].sh.x -= land * 1.3; legs[k].ft.x += land * 0.5 end
		hy -= land * 0.17
	end
	if L > 0.01 then
		-- glissade : jambe droite tendue devant, jambe gauche repliée dessous
		local function lp(Lg: Leg, th: number, sh: number, ft: number, tz: number)
			Lg.th.x += (th - Lg.th.x) * L; Lg.sh.x += (sh - Lg.sh.x) * L; Lg.ft.x += (ft - Lg.ft.x) * L; Lg.th.z += (tz - Lg.th.z) * L
		end
		lp(legs.R, 1.42, -0.12, 0.55, -0.05); lp(legs.L, 0.45, -2.15, 0.25, 0.2)
		hy += (0.36 - hy) * L; hr.y += (0.38 - hr.y) * L; hr.z += (-0.08 - hr.z) * L
	end
	-- escalade : genoux remontés pendant qu'on se hisse, puis la jambe droite se pose sur le rebord et pousse
	local mPush = smooth01((w.mntT - 0.1) / 0.3)
	if Mn > 0.01 then
		local step = smooth01((w.mntT - 0.25) / 0.2)
		for _, k in ipairs({ "L", "R" }) do
			local th = if k == "R" then lerp(1.25, 1.55, step) else lerp(1.25, 0.7, step)
			local sh = if k == "R" then lerp(-1.7, -1.9, step) else lerp(-1.7, -0.9, step)
			legs[k].th.x += (th - legs[k].th.x) * Mn; legs[k].sh.x += (sh - legs[k].sh.x) * Mn
		end
	end
	R.hipsP = V(R.hipsP.X, hy, R.hipsP.Z)
	R.spineR.x += -0.3 * Sg - 0.2 * T + 0.62 * L - 0.12 * A * clamp(-w.vy / 5, 0, 1) - 0.18 * land - w.acc * 0.12 * (1 - L) - (0.25 + 0.25 * mPush) * Mn
	R.spineR.y -= 0.4 * L; R.spineR.z += sin(ph) * 0.05 * Sg
	R.neckR.x += 0.22 * Sg + 0.12 * T - 0.4 * L + 0.2 * Mn
	-- arme et bras
	local bob = sin(ph * 2) * 0.02
	local cf = CFrame.new(gp) * gq
	local function mix(p: Vector3, q: CFrame, k: number) if k > 0.001 then cf = cf:Lerp(CFrame.new(p) * q, k) end end
	if Sg > 0.01 then mix(V(0.02, 0.13 + bob, -0.2), SPR_Q, Sg) end
	if T > 0.01 then mix(V(0.17, 0.36 + bob * 0.6, -0.14), TAC_Q, T) end
	mix(V(0.1, 0.22, -0.3), SLD_Q, L); mix(V(0.16, 0.05, -0.12), MNT_Q, Mn)
	gp, gq = cf.Position, cf.Rotation
	armsFromGun(arms, R, st, gp, gq, 0)
	if T > 0.3 then armTo(arms, R, "L", V(-0.24, 0.12 + sin(ph) * 0.08, -0.06 - sin(ph) * 0.26), nil) end
	if L > 0.3 then
		-- main gauche qui frotte le sol, sur le côté et un peu derrière
		local spineCF = CFrame.new(R.hipsP) * E(hr.x, hr.y, hr.z) * CFrame.new(R.spineP) * E(R.spineR.x, R.spineR.y, R.spineR.z)
		local p = spineCF:PointToObjectSpace(V(-0.42, 0.04, 0.18))
		local d = p - S0.L
		if d.Magnitude > 0.55 then p = S0.L + d.Unit * 0.55 end
		armTo(arms, R, "L", p, nil)
	end
	if Mn > 0.3 then
		-- mains qui agrippent le rebord au-dessus de la tête, puis poussent dessus : le corps monte, elles descendent
		local reach = smooth01(w.mntT / 0.12)
		local gy = lerp(0.62, 0.92, reach) - mPush * 0.62
		local hz = -0.38 + mPush * 0.06
		armTo(arms, R, "L", V(-0.22, gy, hz), nil); armTo(arms, R, "R", V(0.22, gy + 0.02, hz - 0.02), nil)
	end
	return gp, gq
end

-- ---------- recharge vue de l'extérieur ----------
-- rl 0..1 : la main gauche va au chargeur, le tire, le range à la ceinture, revient avec le neuf, l'enfonce
-- (petite claque), puis reprend le garde-main ; l'arme bascule pendant ce temps (pose de l'arme dans step)
local POUCH = V(-0.16, -0.06, -0.14)                -- poche à chargeurs, devant la hanche gauche (repère du buste)
local function reloadHands(R: State, st: Input, arms: { [string]: any }, gp: Vector3, gq: CFrame, rl: number)
	local left = st.left
	if not left then return end                       -- arme tenue à une main : rien à faire de la main gauche
	local hold = gp + gq:VectorToWorldSpace(left)
	-- puits du chargeur : entre les deux mains, sous l'arme (pistolet : dans la poignée)
	local mag = gp + gq:VectorToWorldSpace((st.right + left) * 0.5 + V(0, -0.075, 0))
	local low = mag - V(0, 0.08, 0)
	local tgt: Vector3
	if rl < 0.12 then tgt = hold:Lerp(mag, smooth01(rl / 0.12))
	elseif rl < 0.28 then tgt = mag:Lerp(low, smooth01((rl - 0.12) / 0.16))
	elseif rl < 0.46 then tgt = low:Lerp(POUCH, smooth01((rl - 0.28) / 0.18))
	elseif rl < 0.64 then tgt = POUCH:Lerp(low, smooth01((rl - 0.46) / 0.18))
	elseif rl < 0.74 then tgt = low:Lerp(mag + V(0, 0.015, 0), smooth01((rl - 0.64) / 0.1))
	else tgt = mag:Lerp(hold, smooth01((rl - 0.76) / 0.14)) end
	armTo(arms, R, "L", tgt, nil)
end

-- ---------- pose complète ----------
function Anim.step(R: State, st: Input, dt: number, t: number): Pose
	local arms: { [string]: any } = {}
	local gp, gq = V(0.12, 0.2, -0.2), CFrame.identity
	local gunVisible = true
	local hr, sr, legs = R.hipsR, R.spineR, R.legs
	R.rootYaw = 0; R.rootY = 0; setR(R.rootR, 0, 0, 0)
	if st.dance and st.alive then
		dance(R, st, arms); gunVisible = false
	elseif not st.alive then
		-- mort (si le ragdoll du serveur n'a pas pris le relais) : chute dans une des 4 directions
		if R.dieT < 0 then R.dieT = 0; R.dieStyle = st.dieDir end
		R.dieT += dt
		local k = smooth01(R.dieT / 0.55)
		local bounce = if R.dieT > 0.55 then exp(-(R.dieT - 0.55) * 6) * sin((R.dieT - 0.55) * 18) * 0.04 else 0
		local sty = R.dieStyle
		R.rootR.x = if sty == 1 then k * 1.45 elseif sty == 0 then -k * 1.45 else -k * 0.3
		R.rootR.z = if sty == 2 then k * 1.4 elseif sty == 3 then -k * 1.4 else 0
		R.rootY = k * 0.12 + bounce
		R.hipsP = V(0, 0.94 - k * 0.1, 0)
		legs.L.th.x = -k * 0.4; legs.R.th.x = k * 0.2; legs.L.sh.x = k * 0.6; legs.R.sh.x = k * 0.9
		sr.x = k * 0.2; R.headR.x = k * 0.4
		R.poles.R = V(0.6, -0.6, 0.4); R.poles.L = V(-0.6, -0.6, 0.4)
		gp = V(0.12 + k * 0.18, 0.2 - k * 0.35, -0.2 + k * 0.15); gq = E(k * 1.2, 0, k * 0.9)
		armsFromGun(arms, R, st, gp, gq, 0)
	else
		R.dieT = -1
		R.poles.L = V(-0.55, -0.8, 0.25); R.poles.R = V(0.55, -0.8, 0.25)
		local spd = st.speed
		local ae = 1 - exp(-dt * 9)
		R.ks += (clamp(spd / 5.2, 0, 1.4) - R.ks) * ae
		local k = R.ks
		R.ph += dt * spd * 1.7
		local ph = R.ph
		local sw, sw2 = sin(ph), sin(ph + pi)
		R.ck += ((if st.crouch then 1 else 0) - R.ck) * min(1, dt * 10)
		local air = not st.onGround
		R.fw += (clamp(st.lf / 5.2, -1.2, 1.2) - R.fw) * ae
		R.sd += (clamp(st.lr / 5.2, -1.2, 1.2) - R.sd) * ae
		local fw, sd = R.fw, R.sd
		-- virage : le buste se penche dans la courbe
		if R.lyaw == nil then R.lyaw = st.yaw end
		local yr = angDiff(R.lyaw, st.yaw) / max(dt, 1e-3); R.lyaw = st.yaw
		R.turn += (clamp(yr * 0.05, -0.12, 0.12) - R.turn) * (1 - exp(-dt * 6))
		local amp = 0.75 * min(1, k * 1.15)
		R.hipsP = V(sin(ph) * 0.012 * k, 0.94 - R.ck * 0.4 + (if air then 0.03 else abs(sw) * 0.035 * k), 0)
		setR(hr, 0, -sd * 0.18 * k, sin(ph) * 0.03 * k)
		local function leg(Lg: Leg, s: number, swv: number)
			local hipA = swv * amp * (if abs(fw) > 0.15 then (if fw < 0 then -1 else 1) else 1)
			local knee = max(0, cos(ph + (if s > 0 then 0 else pi))) * amp * 1.3 * (if abs(fw) > 0.15 then 1 else 0.6) + 0.06
			setR(Lg.th, hipA + R.ck * 1.25, 0, -s * 0.03 - sd * 0.28 * swv * k)
			setR(Lg.sh, -knee - R.ck * 1.7, 0, 0); setR(Lg.ft, -hipA * 0.3 + knee * 0.2, 0, 0)
			if air then Lg.th.x = -0.5 - s * 0.1; Lg.sh.x = -0.9; Lg.ft.x = 0.3 end
		end
		leg(legs.L, -1, sw); leg(legs.R, 1, sw2)
		if st.seated > 0 then
			R.hipsP = V(0, 0.55, 0)
			for _, kk in ipairs({ "L", "R" }) do
				legs[kk].th.x = 1.45; legs[kk].sh.x = if st.seated == 2 then -1.2 + sin(t * 2 + R.ph) * 0.18 else -1.5; legs[kk].ft.x = 0
			end
		end
		-- viser
		R.ready += ((if st.ready then 1 else 0.35) - R.ready) * min(1, dt * 6)
		R.flinch *= max(0, 1 - dt * 8); if st.hurt then R.flinch = 1 end
		R.rec *= max(0, 1 - dt * 14); if st.fire > 0 then R.rec = max(R.rec, st.fire) end
		local p = clamp(st.pitch, -1.3, 1.3)
		local lowered = 1 - R.ready
		setR(sr, p * 0.5 - R.ck * 0.18 + R.flinch * 0.18 + R.rec * 0.04,
			-sin(ph) * 0.07 * min(1, k) + sin(t * 1.3 + R.ph) * 0.01 * (1 - min(1, k)) + R.flinch * (sin(t * 40) * 0.03),
			-sd * 0.06 * k - R.turn)
		setR(R.neckR, p * 0.35, 0, 0)
		setR(R.headR, 0, clamp(sin(t * 0.6 + R.ph * 3) * 0.1 * (1 - st.alert), -0.2, 0.2), 0)
		R.spineP = V(0, 0.07 + sin(t * 2 + R.ph) * 0.004, 0)
		-- pose de l'arme
		local rl = if st.reloadMax > 0 and st.reload > 0 then 1 - st.reload / st.reloadMax else -1
		local gx = 0.12 + sin(ph) * 0.012 * min(1, k)
		local gy = 0.2 - lowered * 0.08 - abs(cos(ph)) * 0.02 * min(1, k)
		local gz = -0.2 + lowered * 0.04
		local rx, ry, rz, leftDown = -lowered * 0.55, lowered * 0.18, 0, 0
		if rl >= 0 then
			local a = sin(rl * pi); rx += a * 0.55; rz += a * 0.25; gy -= a * 0.06; leftDown = a * 0.2
		end
		if R.swT > 0 then R.swT = max(0, R.swT - dt); rx += R.swT * 1.2; gy -= R.swT * 0.15 end
		gz += R.rec * 0.05; rx += R.rec * 0.08
		gp = V(gx, gy, gz); gq = E(rx, ry, rz)
		armsFromGun(arms, R, st, gp, gq, leftDown)
		if st.seated == 0 then gp, gq = layer(R, st, dt, gp, gq, arms) else R.aw = nil end
		-- la recharge garde la main gauche, sauf pendant une escalade (les deux mains sur le rebord)
		if rl >= 0 and not (R.aw and R.aw.mnt > 0.3) then reloadHands(R, st, arms, gp, gq, rl) end
	end
	local hips = CFrame.new(R.hipsP) * E(hr.x, hr.y, hr.z)
	local spine = hips * CFrame.new(R.spineP) * E(sr.x, sr.y, sr.z)
	local neck = spine * CFrame.new(0, 0.5, 0) * E(R.neckR.x, R.neckR.y, R.neckR.z)
	local head = neck * CFrame.new(0, 0.14, 0) * E(R.headR.x, R.headR.y, R.headR.z)
	local pose: Pose = {
		-- ordre YXZ de la racine du web (le lacet vient du HumanoidRootPart)
		root = CFrame.new(0, R.rootY, 0) * CFrame.Angles(0, R.rootYaw, 0) * CFrame.Angles(R.rootR.x, 0, 0) * CFrame.Angles(0, 0, R.rootR.z),
		hips = hips, spine = spine, neck = neck, head = head,
		th = {} :: any, sh = {} :: any, ft = {} :: any,
		gun = CFrame.new(gp) * gq, gunVisible = gunVisible, arm = arms,
	}
	for _, k in ipairs({ "L", "R" }) do
		local side: number = if k == "L" then -1 else 1
		local Lg = legs[k]
		local th = hips * CFrame.new(side * 0.1, -0.02, 0) * E(Lg.th.x, Lg.th.y, Lg.th.z)
		local sh = th * CFrame.new(0, -0.46, 0) * E(Lg.sh.x, Lg.sh.y, Lg.sh.z)
		pose.th[k] = th; pose.sh[k] = sh; pose.ft[k] = sh * CFrame.new(0, -0.45, 0) * E(Lg.ft.x, Lg.ft.y, Lg.ft.z)
	end
	return pose
end

return Anim
