--!strict
-- ReplicatedStorage/Shared/AttachmentModels (ModuleScript, côté client)
-- Pose les accessoires de l'armurier sur une arme fabriquée par WeaponModels, comme attBuild() du web
-- (src/64b_gunsmith.js) : silencieux, compensateur, frein, cache-flamme, canons, poignées, laser, chargeurs, crosses,
-- et les viseurs en 3D faits dans Blender (OpticMeshes, src/64d_optics3d.js) avec leur lentille et le réticule choisi.
-- Met à jour la ligne de visée (attribut SightY), le bout du canon (Muzzle) et la main gauche (LeftHand, autour de la
-- poignée verticale) : le viewmodel, les tracés et la vue à la 3e personne suivent sans rien changer.
-- Tout est calculé en mètres dans le repère de l'arme (poignée en 0, canon vers -Z), puis multiplié par l'échelle.
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Info = require(ReplicatedStorage.Shared.WeaponInfo)
local A = require(ReplicatedStorage.Shared.Attachments)
local ReticleGui = require(ReplicatedStorage.Shared.ReticleGui)
local decode = require(ReplicatedStorage.Shared.Base64)

local AM = {}
AM.optics3d = true                      -- false : viseurs simples (géométrie de base), comme cfg.optics3d = 0 sur le web

local function rgb(h: number): Color3 return Color3.fromRGB(bit32.rshift(h, 16), bit32.band(bit32.rshift(h, 8), 255), bit32.band(h, 255)) end
local MAT: { [string]: { any } } = {
	blk = { rgb(0x17191d), Enum.Material.Metal }, dark = { rgb(0x2b3037), Enum.Material.Metal }, tan = { rgb(0x6b6150), Enum.Material.SmoothPlastic },
	rub = { rgb(0x101114), Enum.Material.SmoothPlastic }, tape = { rgb(0x2d2d24), Enum.Material.Fabric }, red = { rgb(0xff2030), Enum.Material.Neon },
	tube = { rgb(0x15171b), Enum.Material.Metal }, wood = { rgb(0x8a7a5a), Enum.Material.Wood },
}
-- matériaux des viseurs Blender (OPT3D_MAT du web)
local OMAT: { [string]: { any } } = {
	body = { rgb(0x17191c), Enum.Material.Metal }, dark = { rgb(0x2a2e34), Enum.Material.Metal }, rubber = { rgb(0x0d0d0f), Enum.Material.SmoothPlastic },
	metal = { rgb(0x9a9ca2), Enum.Material.Metal }, tan = { rgb(0x7a6a4c), Enum.Material.SmoothPlastic },
	emit_red = { rgb(0xff2010), Enum.Material.Neon }, emit_fiber = { rgb(0xff4a10), Enum.Material.Neon },
}
local OPT3D_KEY = { reddot = "reddot", holo = "holo", mini = "mini", acog = "acog", sc4 = "scope", sc6 = "scope", sc8 = "scope", sc10 = "scope" }

-- ---------- profil de l'arme (hauteur du dessus / du dessous le long du canon), gunProfile() du web ----------
type Prof = { z0: number, z1: number, NB: number, top: { number }, bot: { number }, pts: { Vector3 }, bore: number }
local PROF: { [string]: Prof } = {}
local NB = 160

local function profileOf(key: string): Prof?
	if PROF[key] then return PROF[key] end
	local folder = ReplicatedStorage.Shared:FindFirstChild("WeaponMeshes")
	local src = folder and folder:FindFirstChild(key)
	local inf = Info[key]
	if not inf then return nil end
	local pts: { Vector3 } = {}
	if src then
		local ok = pcall(function()
			local groups = require(src :: ModuleScript) :: any
			for _, g in ipairs(groups) do
				local raw = decode(g.data)
				local st = math.max(1, g.nv // 4000)
				for i = 0, g.nv - 1, st do
					table.insert(pts, Vector3.new(buffer.readi16(raw, i * 6), buffer.readi16(raw, i * 6 + 2), buffer.readi16(raw, i * 6 + 4)) / 30000)
				end
			end
		end)
		if not ok then pts = {} end
	end
	if #pts == 0 then     -- pas de maillage : boîte d'après WeaponInfo
		for _, z in ipairs({ inf.max[3], inf.min[3] }) do
			table.insert(pts, Vector3.new(0, inf.sight, z)); table.insert(pts, Vector3.new(0, inf.min[2] * 0.4, z))
		end
	end
	local z0, z1 = math.huge, -math.huge
	for _, p in ipairs(pts) do z0 = math.min(z0, p.Z); z1 = math.max(z1, p.Z) end
	local top, bot = table.create(NB, -1e9), table.create(NB, 1e9)
	local function bin(z: number): number return math.clamp(math.floor((z - z0) / (z1 - z0 + 1e-6) * NB), 0, NB - 1) + 1 end
	for _, p in ipairs(pts) do local b = bin(p.Z); top[b] = math.max(top[b], p.Y); bot[b] = math.min(bot[b], p.Y) end
	-- âme du canon : milieu de la section à la bouche
	local mz = inf.muzzle
	local ty, by = -1e9, 1e9
	for _, p in ipairs(pts) do if p.Z < mz + .012 then ty = math.max(ty, p.Y); by = math.min(by, p.Y) end end
	local pr: Prof = { z0 = z0, z1 = z1, NB = NB, top = top, bot = bot, pts = pts, bore = 0 }
	PROF[key] = pr
	local function at(arr: { number }, z: number): number
		local b = bin(z)
		local r = arr[b]
		local d = 1
		while math.abs(r) > 1e8 do
			if d > NB then return 0 end
			r = arr[math.clamp(b - d, 1, NB)]
			if math.abs(r) > 1e8 then r = arr[math.clamp(b + d, 1, NB)] end
			d += 1
		end
		return r
	end
	;(pr :: any).at = at
	pr.bore = if ty > -1e8 then (ty + by) / 2 else (at(top, mz + .01) + at(bot, mz + .01)) / 2
	return pr
end
local function at(pr: Prof, arr: { number }, z: number): number return ((pr :: any).at)(arr, z) end
local function topR(pr: Prof, za: number, zb: number): number
	local m = -1e9
	local z = za
	while z <= zb do m = math.max(m, at(pr, pr.top, z)); z += .01 end
	return m
end
-- dessous du garde-main à z (ignore chargeur, pontet, poignée : points trop bas sous le canon)
local function under(pr: Prof, z: number, depth: number?): number
	local m = 1e9
	local lo = pr.bore - (depth or .08)
	for _, p in ipairs(pr.pts) do if math.abs(p.Z - z) < .015 and p.Y > lo and p.Y < pr.bore then m = math.min(m, p.Y) end end
	return if m < 1e8 then m else at(pr, pr.bot, z)
end
local function slice(pr: Prof, za: number, zb: number): (number?, number?)
	local t, b = -1e9, 1e9
	for _, p in ipairs(pr.pts) do if p.Z >= za and p.Z <= zb then t = math.max(t, p.Y); b = math.min(b, p.Y) end end
	if t > -1e8 then return t, b end
	return nil, nil
end

-- ---------- fabrication des pièces ----------
type Ctx = { model: Model, sc: number, grip: BasePart }
local function piece(ctx: Ctx, name: string, size: Vector3, pos: Vector3, mat: { any }, rot: CFrame?, shape: Enum.PartType?, piece: string?): Part
	local p = Instance.new("Part"); p.Name = "Att_" .. name
	p.Size = Vector3.new(math.max(size.X, .0005), math.max(size.Y, .0005), math.max(size.Z, .0005)) * ctx.sc
	p.Color = mat[1]; p.Material = mat[2]
	if shape then p.Shape = shape end
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Massless = true; p.CastShadow = false
	local off = CFrame.new(pos * ctx.sc) * (rot or CFrame.identity)
	p:SetAttribute("Piece", piece or "body"); p:SetAttribute("Role", "att"); p:SetAttribute("Offset", off)
	p.CFrame = ctx.grip.CFrame * off
	p.Parent = ctx.model
	return p
end
local ROT_Z = CFrame.Angles(0, math.rad(90), 0)        -- cylindre Roblox (axe X) couché le long du canon
local ROT_Y = CFrame.Angles(0, 0, math.rad(90))        -- cylindre debout
local function box(ctx: Ctx, n: string, w: number, h: number, d: number, mat: { any }, x: number, y: number, z: number, rot: CFrame?): Part
	return piece(ctx, n, Vector3.new(w, h, d), Vector3.new(x, y, z), mat, rot)
end
local function cylZ(ctx: Ctx, n: string, r: number, L: number, mat: { any }, x: number, y: number, z: number): Part
	return piece(ctx, n, Vector3.new(L, r * 2, r * 2), Vector3.new(x, y, z), mat, ROT_Z, Enum.PartType.Cylinder)
end
-- tube ouvert (on vise au travers) : couronne de lattes
local function tubeZ(ctx: Ctx, n: string, r: number, L: number, mat: { any }, y: number, z: number)
	local seg = 12
	for i = 0, seg - 1 do
		local a = i / seg * math.pi * 2
		local w = 2 * r * math.tan(math.pi / seg) + .001
		box(ctx, n, w, .003, L, mat, math.cos(a) * r, y + math.sin(a) * r, z, CFrame.Angles(0, 0, a + math.pi / 2))
	end
end

-- lentille + réticule (texture du web remplacée par une SurfaceGui)
local function lens(ctx: Ctx, w: number, h: number, pos: Vector3, round: boolean)
	local p = piece(ctx, "Lens", Vector3.new(w, h, .0004), pos, { rgb(0x7fd8ff), Enum.Material.Glass })
	p.Transparency = .88
	if round then p.Shape = Enum.PartType.Cylinder; p.Size = Vector3.new(.0004, h, w) * ctx.sc; p:SetAttribute("Offset", (p:GetAttribute("Offset") :: CFrame) * ROT_Z); p.CFrame = ctx.grip.CFrame * (p:GetAttribute("Offset") :: CFrame) end
end
local function reticle(ctx: Ctx, size: number, pos: Vector3, shape: string, col: string)
	local p = piece(ctx, "Reticle", Vector3.new(size, size, .0002), pos, { Color3.new(), Enum.Material.SmoothPlastic })
	p.Transparency = 1
	local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Back; sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	sg.CanvasSize = Vector2.new(128, 128); sg.LightInfluence = 0; sg.Brightness = 2.5; sg.ClipsDescendants = true
	local holder = Instance.new("Frame"); holder.Size = UDim2.fromScale(1, 1); holder.BackgroundTransparency = 1; holder.Parent = sg
	ReticleGui.draw(holder, 64, 64, 58, shape, col, false)
	sg.Parent = p
end

-- maillage d'un viseur Blender ; f = transformation (mètres, repère de l'arme)
local function opticMesh(ctx: Ctx, key: string, f: (Vector3) -> Vector3): boolean
	if not AM.optics3d then return false end
	local folder = ReplicatedStorage.Shared:FindFirstChild("OpticMeshes")
	local src = folder and folder:FindFirstChild(key)
	if not src then return false end
	local made: { Instance } = {}
	local ok = pcall(function()
		local data = require(src :: ModuleScript) :: any
		for _, g in ipairs(data.groups) do
			local raw = decode(g.data)
			local pos, nrm = table.create(g.nv), table.create(g.nv)
			local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
			for i = 0, g.nv - 1 do
				local o = i * 9
				local v = f(Vector3.new(buffer.readi16(raw, o), buffer.readi16(raw, o + 2), buffer.readi16(raw, o + 4)) / 100000) * ctx.sc
				pos[i + 1] = v; lo = lo:Min(v); hi = hi:Max(v)
				nrm[i + 1] = Vector3.new(buffer.readi8(raw, o + 6), buffer.readi8(raw, o + 7), buffer.readi8(raw, o + 8)) / 127
			end
			local center = (lo + hi) / 2
			local em = AssetService:CreateEditableMesh({ FixedSize = false })
			local vid, nid = table.create(g.nv), table.create(g.nv)
			for i = 1, g.nv do vid[i] = em:AddVertex(pos[i] - center); nid[i] = em:AddNormal(if nrm[i].Magnitude > 1e-3 then nrm[i].Unit else Vector3.yAxis) end
			local base = g.nv * 9
			for t = 0, g.nt - 1 do
				local a = buffer.readu16(raw, base + t * 6) + 1
				local b = buffer.readu16(raw, base + t * 6 + 2) + 1
				local c = buffer.readu16(raw, base + t * 6 + 4) + 1
				local face = em:AddTriangle(vid[a], vid[b], vid[c])
				em:SetFaceNormals(face, { nid[a], nid[b], nid[c] })
			end
			local mp = AssetService:CreateMeshPartAsync(Content.fromObject(em), { CollisionFidelity = Enum.CollisionFidelity.Box })
			local m = OMAT[g.mat] or OMAT.body
			mp.Name = "Att_optic_" .. g.mat; mp.Color = m[1]; mp.Material = m[2]
			mp.Anchored = true; mp.CanCollide = false; mp.CanQuery = false; mp.CanTouch = false; mp.Massless = true; mp.CastShadow = false
			local off = CFrame.new(center)
			mp:SetAttribute("Piece", "body"); mp:SetAttribute("Role", "att"); mp:SetAttribute("Offset", off)
			mp.CFrame = ctx.grip.CFrame * off
			table.insert(made, mp)
		end
	end)
	if not ok then for _, m in ipairs(made) do m:Destroy() end return false end
	for _, m in ipairs(made) do m.Parent = ctx.model end
	return true
end
function AM.opticInfo(key: string): any
	local folder = ReplicatedStorage.Shared:FindFirstChild("OpticMeshes")
	local src = folder and folder:FindFirstChild(key)
	if not src then return nil end
	local ok, data = pcall(require, src :: ModuleScript)
	return if ok then (data :: any).info else nil
end

-- ---------- pose des accessoires ----------
-- opts.preview : laser court (aperçu de l'Arsenal) ; opts.ret(optique) -> (forme, couleur) du réticule
export type Opts = { preview: boolean?, ret: ((string) -> (string, string))? }
function AM.apply(model: Model, key: string, list: { string }, sc: number, opts: Opts?)
	local w = Config.WEAPONS[key]
	local inf = Info[key]
	local grip = model.PrimaryPart
	if not w or w.melee or not inf or not grip or #list == 0 then return end
	local pr = profileOf(key)
	if not pr then return end
	local o: Opts = opts or ({} :: Opts)
	local ctx: Ctx = { model = model, sc = sc, grip = grip }
	local pistol = w.cat == "pistol"
	local S = if pistol then .7 else 1
	local bore = pr.bore
	local muzzle = inf.muzzle
	local sight: number? = nil
	local left = if pistol then Vector3.new(-.012, -.04, .02) else Vector3.new(inf.left[1], inf.left[2] - .012, inf.left[3])
	local leftZ: number? = if pistol then nil else inf.left[3]
	local leftV = false
	local function retOf(a: string): (string, string)
		if o.ret then return o.ret(a) end
		return A.retOf(a, nil)
	end
	local ORD = { barrel = 1, muzzle = 2, optic = 3, under = 4, mag = 5, stock = 6 }
	local todo = table.clone(list)
	table.sort(todo, function(a, b) return ORD[A.ATTS[a].s] < ORD[A.ATTS[b].s] end)
	local mags: { BasePart } = {}
	for _, c in ipairs(model:GetChildren()) do if c:IsA("BasePart") and c:GetAttribute("Piece") == "mag" then table.insert(mags, c) end end

	-- viseur : pièces dans un repère (base, z), réduit ×0,62 sur pistolet, rehaussé si une pièce gêne la vue
	local function optic(a: string, z: number, base: number, cy0: number, zb: number, build: (add: (n: string, w: number, h: number, d: number, m: { any }, x: number, y: number, z: number, cyl: string?, r: CFrame?) -> ()) -> (), lensList: { any }, retSize: number?, retZ: number?)
		local k = if pistol then .62 else 1
		local dy = 0
		local cy = base + (cy0 - base) * k
		if not pistol then
			local occ = topR(pr, zb, .27)
			if occ > cy - .008 then dy = occ + .014 - cy
				box(ctx, "riser", .022, dy + .004, .04, MAT.dark, 0, base + dy / 2, z)
				cy += dy
			end
		end
		local function T(p: Vector3): Vector3 return Vector3.new(p.X * k, base + (p.Y - base) * k + dy, z + (p.Z - z) * k) end
		-- centre de la lentille (là où passe la ligne de visée)
		local c = Vector3.zero
		for _, l in ipairs(lensList) do c += l.p end
		c /= math.max(1, #lensList)
		local mkey = OPT3D_KEY[a]
		local info = mkey and AM.opticInfo(mkey)
		local done = false
		if info then
			local s = if mkey == "scope" then (if a == "sc4" then .88 else 1) else 1
			local mpos = Vector3.new(0, c.Y - info.cy * s, c.Z + info.lensY * s)
			done = opticMesh(ctx, mkey, function(v: Vector3) return T(v * s + mpos) end)
		end
		if not done then
			build(function(n, ww, hh, dd, m, x, y, zz, cyl, r)
				local p = T(Vector3.new(x, y, zz))
				if cyl == "z" then cylZ(ctx, n, ww * k, dd * k, m, p.X, p.Y, p.Z)
				elseif cyl == "tube" then tubeZ(ctx, n, ww * k, dd * k, m, p.Y, p.Z)
				elseif cyl == "y" then piece(ctx, n, Vector3.new(hh, ww, ww) * k, p, m, ROT_Y, Enum.PartType.Cylinder)
				else box(ctx, n, ww * k, hh * k, dd * k, m, p.X, p.Y, p.Z, r) end
			end)
		end
		for _, l in ipairs(lensList) do lens(ctx, l.w * k, l.h * k, T(l.p), l.round) end
		if retSize and retZ then
			local s2, c2 = retOf(a)
			reticle(ctx, retSize * k, T(Vector3.new(0, c.Y, retZ)), s2, c2)
		end
		sight = cy
	end

	for _, a in ipairs(todo) do
		if a == "sil" then
			local L, r = if pistol then .13 else .19, if pistol then .017 else .022
			local z = muzzle - L / 2 + .01
			cylZ(ctx, a, r, L, MAT.blk, 0, bore, z)
			cylZ(ctx, a, r * 1.08, .012, MAT.dark, 0, bore, z - L / 2 + .006); cylZ(ctx, a, r * 1.08, .012, MAT.dark, 0, bore, z + L / 2 - .006)
			for i = 0, 2 do cylZ(ctx, a, r * 1.03, .004, MAT.dark, 0, bore, z - L / 4 + i * L / 4) end
			muzzle -= L - .01
		elseif a == "comp" then
			local L, r = .05 * S, .016 * S
			local z = muzzle - L / 2 + .005
			cylZ(ctx, a, r, L, MAT.dark, 0, bore, z)
			for i = 0, 2 do box(ctx, a, r * .9, .004, .006, MAT.blk, 0, bore + r * .95, z - L / 2 + .01 + i * .014) end
			muzzle -= L - .005
		elseif a == "brake" then
			local L, r = .065 * S, .019 * S
			local z = muzzle - L / 2 + .005
			box(ctx, a, r * 2.2, r * 1.6, L, MAT.dark, 0, bore, z)
			for i = 0, 2 do box(ctx, a, r * 2.4, r * .5, .008, MAT.blk, 0, bore, z - L / 2 + .012 + i * .018) end
			muzzle -= L - .005
		elseif a == "flash" then
			local L, r = .045 * S, .014 * S
			local z = muzzle - L / 2 + .005
			cylZ(ctx, a, r * .95, L * .5, MAT.blk, 0, bore, z + L * .25)
			for i = 0, 3 do
				local an = i * math.pi / 2 + math.pi / 4
				box(ctx, a, .005, .005, L * .6, MAT.blk, math.cos(an) * r * .8, bore + math.sin(an) * r * .8, z - L * .2)
			end
			muzzle -= L - .005
		elseif a == "long" then
			local L, r = .09 * S, .012 * S
			local z = muzzle - L / 2 + .005
			cylZ(ctx, a, r, L, MAT.blk, 0, bore, z); cylZ(ctx, a, r * 1.5, .025, MAT.dark, 0, bore, z + L / 2 - .012)
			muzzle -= L - .005
		elseif a == "heavy" then
			local L, r = .07 * S, .016 * S
			local z = muzzle - L / 2 + .005
			cylZ(ctx, a, r, L, MAT.dark, 0, bore, z)
			for i = 0, 3 do cylZ(ctx, a, r * 1.15, .006, MAT.blk, 0, bore, z - L / 2 + .01 + i * .016) end
			muzzle -= L - .005
		elseif a == "reddot" then
			local z = math.clamp(muzzle * .28, -.2, -.03)
			local base = topR(pr, z - .04, z + .04) - .002
			local cy = base + .034
			optic(a, z, base, cy, z + .03, function(add)
				add(a, .03, .012, .07, MAT.dark, 0, base + .006, z)
				add(a, .012, .024, .05, MAT.blk, 0, base + .018, z)
				add(a, .024, 0, .05, MAT.blk, 0, cy, z, "tube")
				add(a, .026, 0, .008, MAT.blk, 0, cy, z - .025, "tube"); add(a, .026, 0, .008, MAT.blk, 0, cy, z + .025, "tube")
			end, { { p = Vector3.new(0, cy, z - .024), w = .045, h = .045, round = true }, { p = Vector3.new(0, cy, z - .023), w = 0, h = 0 } }, .018, z - .023)
		elseif a == "mini" then
			local z = math.clamp(muzzle * (if pistol then .2 else .26), -.18, -.02)
			local base = topR(pr, z - .03, z + .03) - .002
			local cy = base + .02
			optic(a, z, base, cy, z + .02, function(add)
				add(a, .026, .008, .04, MAT.dark, 0, base + .004, z + .004)
				add(a, .004, .026, .012, MAT.blk, -.013, cy - .002, z - .01); add(a, .004, .026, .012, MAT.blk, .013, cy - .002, z - .01)
				add(a, .03, .004, .014, MAT.blk, 0, cy + .012, z - .01)
			end, { { p = Vector3.new(0, cy, z - .016), w = .022, h = .022 }, { p = Vector3.new(0, cy, z - .017), w = 0, h = 0 } }, .012, z - .017)
		elseif a == "holo" then
			local z = math.clamp(muzzle * .3, -.22, -.05)
			local base = topR(pr, z - .05, z + .05)
			local h, cy = .04, base + .026
			optic(a, z, base, cy, z + .045, function(add)
				add(a, .034, .012, .085, MAT.dark, 0, base + .006, z)
				add(a, .005, h, .05, MAT.blk, -.02, cy + .003, z); add(a, .005, h, .05, MAT.blk, .02, cy + .003, z)
				add(a, .045, .006, .054, MAT.blk, 0, cy + h / 2 + .003, z)
				add(a, .045, .006, .034, MAT.dark, 0, base + .012, z + .016)
			end, { { p = Vector3.new(0, cy, z - .023), w = .035, h = .034 }, { p = Vector3.new(0, cy, z - .024), w = 0, h = 0 } }, .017, z - .024)
		elseif a == "acog" then
			local z = math.clamp(muzzle * .3, -.24, -.06)
			local base = topR(pr, z - .06, z + .06)
			local r, cy = .021, base + .036
			optic(a, z, base, cy, z + .075, function(add)
				add(a, .028, .016, .07, MAT.dark, 0, base + .008, z)
				add(a, r, 0, .12, MAT.tube, 0, cy, z, "tube")
				add(a, r * 1.2, 0, .03, MAT.blk, 0, cy, z - .07, "tube"); add(a, r * 1.08, 0, .02, MAT.blk, 0, cy, z + .065, "tube")
				add(a, .014, .014, .02, MAT.blk, 0, cy + r + .004, z); add(a, .014, .014, .02, MAT.blk, r + .004, cy, z)
			end, { { p = Vector3.new(0, cy, z - .05), w = r * 1.9, h = r * 1.9, round = true }, { p = Vector3.new(0, cy, z - .051), w = 0, h = 0 } }, .022, z - .051)
		elseif a == "sc4" or a == "sc6" or a == "sc8" or a == "sc10" then
			if w.cat ~= "sniper" then          -- le sniper garde sa lunette : seul le grossissement change
				local L, r = if a == "sc4" then .17 else .21, if a == "sc4" then .019 else .022
				local z = math.clamp(muzzle * .32, -.26, -.08)
				local base = topR(pr, z - L / 2, z + L / 2)
				local cy = base + r + .022
				optic(a, z, base, cy, z + L / 2 + .03, function(add)
					add(a, r * .8, 0, L, MAT.tube, 0, cy, z, "tube")
					add(a, r * 1.05, 0, .045, MAT.tube, 0, cy, z - L / 2 - .012, "tube"); add(a, r, 0, .035, MAT.tube, 0, cy, z + L / 2 + .01, "tube")
					add(a, r * .95, .03, 0, MAT.blk, 0, cy + r * .95, z, "y")
					add(a, .03, r * 1.9, r * 1.9, MAT.blk, r * .95, cy, z)
					for _, dz in ipairs({ -L * .28, L * .28 }) do add(a, .012, cy - base, .016, MAT.dark, 0, base + (cy - base) / 2, z + dz) end
				end, { { p = Vector3.new(0, cy, z - L / 2 - .034), w = r * 2.4, h = r * 2.4, round = true } })
			end
		elseif a == "grip" then
			local z = leftZ or -.25
			local b = under(pr, z)
			box(ctx, a, .022, .012, .04, MAT.dark, 0, b - .004, z)
			piece(ctx, a, Vector3.new(.075, .024, .024), Vector3.new(0, b - .045, z), MAT.rub, ROT_Y, Enum.PartType.Cylinder)
			left = Vector3.new(left.X, b - .012, z); leftV = true          -- main gauche autour de la poignée verticale
		elseif a == "angled" then
			local z = leftZ or -.25
			local b = under(pr, z)
			box(ctx, a, .02, .03, .07, MAT.dark, 0, b - .016, z + .005, CFrame.Angles(-.5, 0, 0))
			box(ctx, a, .022, .008, .075, MAT.blk, 0, b - .002, z)
			left = Vector3.new(left.X, b - .03, z + .01)
		elseif a == "laser" then
			local z = if pistol then math.clamp(muzzle * .55, -.12, -.03) elseif leftZ then leftZ - .06 else -.3
			local b = if pistol then under(pr, z, .06) else (under(pr, z) + bore) / 2
			local x = if pistol then 0 else .024
			local y = if pistol then b - .01 else b
			box(ctx, a, if pistol then .022 else .016, if pistol then .018 else .022, if pistol then .045 else .06, MAT.blk, x, y, z)
			local dz = if pistol then .023 else .031
			piece(ctx, "laserdot", Vector3.new(.0005, .008, .008), Vector3.new(x, y, z - dz), MAT.red, ROT_Z, Enum.PartType.Cylinder)
			local BL = if o.preview then .3 else 6
			local beam = cylZ(ctx, "beam", .0012, BL, MAT.red, x, y, z - .03 - BL / 2)
			beam.Transparency = .45; beam.Name = "Att_beam"
		elseif a == "ext" then
			if #mags > 0 then
				for _, m in ipairs(mags) do
					local off = m:GetAttribute("Offset") :: CFrame
					local h = m.Size.Y
					m.Size = Vector3.new(m.Size.X, h * 1.28, m.Size.Z)
					m:SetAttribute("Offset", off * CFrame.new(0, -h * .14, 0))
					m:SetAttribute("ExtMag", true)
				end
			elseif pistol then           -- pas de chargeur séparé : talon allongé sous la crosse du pistolet
				local zb, yb = 0, 1e9
				local z = -.03
				while z <= .06 do local bb = at(pr, pr.bot, z); if bb < yb then yb = bb; zb = z end; z += .005 end
				box(ctx, a, .03, .018, .05, MAT.dark, 0, yb - .007, zb)
			end
		elseif a == "fast" then
			if #mags > 0 then
				local c = Vector3.zero
				for _, m in ipairs(mags) do
					local tw = m:Clone()
					tw:SetAttribute("Offset", CFrame.new(Vector3.new(.03, .012, 0) * sc) * (m:GetAttribute("Offset") :: CFrame))
					tw:SetAttribute("Piece", "body"); tw.Name = "Att_twinmag"; tw.Parent = model
					c += (m:GetAttribute("Offset") :: CFrame).Position / sc
				end
				c /= #mags
				box(ctx, a, .05, .018, .04, MAT.tape, c.X + .015, c.Y, c.Z)
			end
		elseif a == "light" or a == "tac" then
			if not pistol then
				local z = pr.z1 - .012
				local t, b = at(pr, pr.top, z), at(pr, pr.bot, z)
				local y = (t + b) / 2
				if pr.z1 > .12 then          -- l'arme a déjà une crosse : on l'habille (plaque de couche, busc)
					local et, eb = slice(pr, pr.z1 - .015, pr.z1)
					local endT, endB = et or t, eb or b
					local ct = slice(pr, pr.z1 - .11, pr.z1 - .05)
					if a == "tac" then
						box(ctx, a, .036, endT - endB + .008, .026, MAT.rub, 0, (endT + endB) / 2, pr.z1 + .011)
						if ct then box(ctx, a, .028, .016, .06, MAT.tape, 0, ct + .006, pr.z1 - .08) end
					else
						box(ctx, a, .032, endT - endB + .004, .012, MAT.wood, 0, (endT + endB) / 2, pr.z1 + .005)
					end
				elseif a == "light" then
					box(ctx, a, .008, .008, .16, MAT.blk, 0, y + .02, z + .08); box(ctx, a, .008, .008, .17, MAT.blk, 0, y - .035, z + .085)
					box(ctx, a, .01, .075, .012, MAT.blk, 0, y - .006, z + .165); box(ctx, a, .014, .08, .02, MAT.rub, 0, y - .006, z + .18)
				else
					box(ctx, a, .03, .05, .14, MAT.dark, 0, y, z + .07); box(ctx, a, .034, .085, .03, MAT.rub, 0, y - .01, z + .15)
					box(ctx, a, .026, .012, .09, MAT.blk, 0, y + .03, z + .07)
				end
			end
		end
	end

	-- repères mis à jour : bout du canon, ligne de visée, main gauche
	local m = A.modsOf(list)
	local mz = grip:FindFirstChild("Muzzle") :: Attachment?
	if mz then mz.Position = Vector3.new(mz.Position.X, mz.Position.Y, muzzle * sc) end
	if sight then model:SetAttribute("SightY", sight * sc) end
	local lh = grip:FindFirstChild("LeftHand") :: Attachment?
	if lh and not pistol then lh.Position = left * sc end
	model:SetAttribute("LeftV", leftV)
	model:SetAttribute("NoFlash", m.noFlash)
	model:SetAttribute("Sil", m.sil)
	model:SetAttribute("Optic", A.optOf(list))
	model:SetAttribute("Attachments", table.concat(list, ","))
end

return AM
