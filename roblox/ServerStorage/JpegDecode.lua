--!strict
--!native
--!optimize 2
-- ServerStorage/JpegDecode (ModuleScript, Studio seulement : envoi des textures par ServerStorage/MeshUploader)
-- Décodeur JPEG « baseline » (le format des textures des armes réalistes, models/weapons_real) : tables de Huffman,
-- quantification, transformée en cosinus inverse (algorithme de Loeffler, comme stb_image), sous-échantillonnage des
-- couleurs (4:2:0, 4:2:2, 4:4:4), intervalles de reprise, images en niveaux de gris ou en couleur (YCbCr).
-- Les JPEG progressifs ou arithmétiques sont refusés (erreur) : tools/export_weapons_real_lua.py n'en écrit pas.
--   decode(données, début, longueur) -> largeur, hauteur, pixels RGBA (buffer de largeur × hauteur × 4 octets)
-- Garder les textures en JPEG (et non en pixels) divise par dix la place qu'elles prennent dans la place Roblox.

local ZZ = { -- ordre en zigzag -> position dans le bloc 8 × 8 (0..63)
	0, 1, 8, 16, 9, 2, 3, 10, 17, 24, 32, 25, 18, 11, 4, 5, 12, 19, 26, 33, 40, 48, 41, 34, 27, 20, 13, 6, 7, 14, 21,
	28, 35, 42, 49, 56, 57, 50, 43, 36, 29, 22, 15, 23, 30, 37, 44, 51, 58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61,
	54, 47, 55, 62, 63,
}
local LUTBITS = 9

type Huff = { lut: { number }, maxcode: { number }, valptr: { number }, mincode: { number }, vals: { number } }
type Comp = { id: number, h: number, v: number, tq: number, td: number, ta: number, bw: number, bh: number,
	plane: buffer, stride: number, pred: number }

local function buildHuff(counts: { number }, vals: { number }): Huff
	local lut = table.create(bit32.lshift(1, LUTBITS), 0)
	local maxcode, valptr, mincode = table.create(17, -1), table.create(17, 0), table.create(17, 0)
	local code, k = 0, 0
	for len = 1, 16 do
		local n = counts[len]
		valptr[len] = k; mincode[len] = code
		for _ = 1, n do
			if len <= LUTBITS then
				-- toutes les entrées de 9 bits qui commencent par ce code
				local shift = LUTBITS - len
				local base = bit32.lshift(code, shift)
				for f = 0, bit32.lshift(1, shift) - 1 do lut[base + f + 1] = len * 256 + vals[k + 1] end
			end
			code += 1; k += 1
		end
		maxcode[len] = if n > 0 then code - 1 else -1
		code *= 2
	end
	return { lut = lut, maxcode = maxcode, valptr = valptr, mincode = mincode, vals = vals }
end

-- transformée inverse d'un bloc (coefficients déquantifiés, en place) puis écriture des 64 pixels dans le plan
local function idct(c: { number }, plane: buffer, stride: number, px: number, py: number)
	-- colonnes
	for i = 0, 7 do
		local s0, s1, s2, s3 = c[i + 1], c[i + 9], c[i + 17], c[i + 25]
		local s4, s5, s6, s7 = c[i + 33], c[i + 41], c[i + 49], c[i + 57]
		if s1 == 0 and s2 == 0 and s3 == 0 and s4 == 0 and s5 == 0 and s6 == 0 and s7 == 0 then
			c[i + 9] = s0; c[i + 17] = s0; c[i + 25] = s0; c[i + 33] = s0; c[i + 41] = s0; c[i + 49] = s0; c[i + 57] = s0
		else
			local p1 = (s2 + s6) * 0.5411961
			local t2 = p1 + s6 * -1.847759065
			local t3 = p1 + s2 * 0.765366865
			local t0 = s0 + s4
			local t1 = s0 - s4
			local x0, x3, x1, x2 = t0 + t3, t0 - t3, t1 + t2, t1 - t2
			local q3, q4, q1, q2 = s7 + s3, s5 + s1, s7 + s1, s5 + s3
			local p5 = (q3 + q4) * 1.175875602
			local a0, a1, a2, a3 = s7 * 0.298631336, s5 * 2.053119869, s3 * 3.072711026, s1 * 1.501321110
			q1 = p5 + q1 * -0.899976223
			q2 = p5 + q2 * -2.562915447
			q3 = q3 * -1.961570560
			q4 = q4 * -0.390180644
			a3 += q1 + q4; a2 += q2 + q3; a1 += q2 + q4; a0 += q1 + q3
			c[i + 1] = x0 + a3; c[i + 57] = x0 - a3; c[i + 9] = x1 + a2; c[i + 49] = x1 - a2
			c[i + 17] = x2 + a1; c[i + 41] = x2 - a1; c[i + 25] = x3 + a0; c[i + 33] = x3 - a0
		end
	end
	-- lignes, puis /8, +128, bornes 0..255
	for r = 0, 7 do
		local o = r * 8
		local s0, s1, s2, s3 = c[o + 1], c[o + 2], c[o + 3], c[o + 4]
		local s4, s5, s6, s7 = c[o + 5], c[o + 6], c[o + 7], c[o + 8]
		local p1 = (s2 + s6) * 0.5411961
		local t2 = p1 + s6 * -1.847759065
		local t3 = p1 + s2 * 0.765366865
		local t0 = s0 + s4
		local t1 = s0 - s4
		local x0, x3, x1, x2 = t0 + t3, t0 - t3, t1 + t2, t1 - t2
		local q3, q4, q1, q2 = s7 + s3, s5 + s1, s7 + s1, s5 + s3
		local p5 = (q3 + q4) * 1.175875602
		local a0, a1, a2, a3 = s7 * 0.298631336, s5 * 2.053119869, s3 * 3.072711026, s1 * 1.501321110
		q1 = p5 + q1 * -0.899976223
		q2 = p5 + q2 * -2.562915447
		q3 = q3 * -1.961570560
		q4 = q4 * -0.390180644
		a3 += q1 + q4; a2 += q2 + q3; a1 += q2 + q4; a0 += q1 + q3
		local base = (py + r) * stride + px
		local v
		v = (x0 + a3) * 0.125 + 128.5; buffer.writeu8(plane, base, if v < 0 then 0 elseif v > 255 then 255 else v)
		v = (x1 + a2) * 0.125 + 128.5; buffer.writeu8(plane, base + 1, if v < 0 then 0 elseif v > 255 then 255 else v)
		v = (x2 + a1) * 0.125 + 128.5; buffer.writeu8(plane, base + 2, if v < 0 then 0 elseif v > 255 then 255 else v)
		v = (x3 + a0) * 0.125 + 128.5; buffer.writeu8(plane, base + 3, if v < 0 then 0 elseif v > 255 then 255 else v)
		v = (x3 - a0) * 0.125 + 128.5; buffer.writeu8(plane, base + 4, if v < 0 then 0 elseif v > 255 then 255 else v)
		v = (x2 - a1) * 0.125 + 128.5; buffer.writeu8(plane, base + 5, if v < 0 then 0 elseif v > 255 then 255 else v)
		v = (x1 - a2) * 0.125 + 128.5; buffer.writeu8(plane, base + 6, if v < 0 then 0 elseif v > 255 then 255 else v)
		v = (x0 - a3) * 0.125 + 128.5; buffer.writeu8(plane, base + 7, if v < 0 then 0 elseif v > 255 then 255 else v)
	end
end

local function decode(data: buffer, start: number, len: number): (number, number, buffer)
	local pos = start
	local stop = start + len
	local function u8(): number local b = buffer.readu8(data, pos); pos += 1; return b end
	local function u16(): number local b = buffer.readu8(data, pos) * 256 + buffer.readu8(data, pos + 1); pos += 2; return b end

	local qt: { { number } } = {}
	local hdc: { Huff } = {}
	local hac: { Huff } = {}
	local comps: { Comp } = {}
	local W, H, hmax, vmax = 0, 0, 1, 1
	local restart = 0
	local done = false
	local scanned = 0

	if u16() ~= 0xFFD8 then error("JPEG : en-tête SOI absent") end
	while not done and pos < stop do
		local m = u8()
		if m ~= 0xFF then continue end
		local mk = u8()
		while mk == 0xFF do mk = u8() end
		if mk == 0xD8 or (mk >= 0xD0 and mk <= 0xD7) or mk == 0x01 then continue end
		if mk == 0xD9 then break end
		local seg = u16()
		local segEnd = pos + seg - 2
		if mk == 0xDB then                                  -- tables de quantification
			while pos < segEnd do
				local pq = u8()
				local t = table.create(64, 0)
				local wide = bit32.rshift(pq, 4) ~= 0
				for k = 1, 64 do t[k] = if wide then u16() else u8() end
				qt[bit32.band(pq, 15) + 1] = t
			end
		elseif mk == 0xC4 then                              -- tables de Huffman
			while pos < segEnd do
				local tc = u8()
				local counts = table.create(16, 0)
				local total = 0
				for k = 1, 16 do counts[k] = u8(); total += counts[k] end
				local vals = table.create(total, 0)
				for k = 1, total do vals[k] = u8() end
				local h = buildHuff(counts, vals)
				if bit32.rshift(tc, 4) == 0 then hdc[bit32.band(tc, 15) + 1] = h else hac[bit32.band(tc, 15) + 1] = h end
			end
		elseif mk == 0xC0 or mk == 0xC1 then                -- image « baseline »
			if u8() ~= 8 then error("JPEG : seuls les échantillons de 8 bits sont lus") end
			H = u16(); W = u16()
			local nf = u8()
			for _ = 1, nf do
				local id, hv, tq = u8(), u8(), u8()
				local c: Comp = { id = id, h = bit32.rshift(hv, 4), v = bit32.band(hv, 15), tq = tq + 1, td = 1, ta = 1,
					bw = 0, bh = 0, plane = buffer.create(0), stride = 0, pred = 0 }
				hmax = math.max(hmax, c.h); vmax = math.max(vmax, c.v)
				table.insert(comps, c)
			end
		elseif mk == 0xC2 or mk == 0xC3 or (mk >= 0xC5 and mk <= 0xCF and mk ~= 0xC8 and mk ~= 0xCC) then
			error("JPEG : format non pris en charge (progressif ou arithmétique)")
		elseif mk == 0xDD then
			restart = u16()
		elseif mk == 0xDA then                              -- début des données
			local ns = u8()
			local scomp: { Comp } = {}
			for _ = 1, ns do
				local id, t = u8(), u8()
				for _, c in ipairs(comps) do
					if c.id == id then c.td = bit32.rshift(t, 4) + 1; c.ta = bit32.band(t, 15) + 1; table.insert(scomp, c) end
				end
			end
			pos = segEnd
			local mcuW, mcuH = 8 * hmax, 8 * vmax
			local mx, my = (W + mcuW - 1) // mcuW, (H + mcuH - 1) // mcuH
			for _, c in ipairs(comps) do
				c.bw = mx * c.h; c.bh = my * c.v
				c.stride = c.bw * 8
				if buffer.len(c.plane) == 0 then c.plane = buffer.create(c.stride * c.bh * 8) end
				c.pred = 0
			end
			-- lecture des bits (octets 0xFF00 = 0xFF ; un marqueur arrête la lecture : on complète par des zéros)
			local bitbuf, bitcnt = 0, 0
			local function fill()
				while bitcnt <= 24 do
					local b = 0
					if pos < stop then
						b = buffer.readu8(data, pos)
						if b == 0xFF then
							local n2 = if pos + 1 < stop then buffer.readu8(data, pos + 1) else 0
							if n2 == 0 then pos += 2 else b = 0 end    -- marqueur : on ne le consomme pas
						else
							pos += 1
						end
					end
					bitbuf = bit32.bor(bit32.lshift(bitbuf, 8), b)
					bitcnt += 8
				end
			end
			local function bits(n: number): number
				if bitcnt < n then fill() end
				bitcnt -= n
				return bit32.band(bit32.rshift(bitbuf, bitcnt), bit32.lshift(1, n) - 1)
			end
			local function huff(h: Huff): number
				if bitcnt < 16 then fill() end
				local look = bit32.band(bit32.rshift(bitbuf, bitcnt - LUTBITS), bit32.lshift(1, LUTBITS) - 1)
				local e = h.lut[look + 1]
				if e ~= 0 then
					bitcnt -= e // 256
					return e % 256
				end
				-- code plus long que 9 bits
				local code = 0
				for l = 1, 16 do
					code = code * 2 + bits(1)
					if h.maxcode[l] >= 0 and code <= h.maxcode[l] and code >= h.mincode[l] then
						return h.vals[h.valptr[l] + code - h.mincode[l] + 1]
					end
				end
				error("JPEG : code de Huffman invalide")
			end
			local function extend(v: number, s: number): number
				if v < bit32.lshift(1, s - 1) then return v - bit32.lshift(1, s) + 1 end
				return v
			end
			local blk = table.create(64, 0)
			local function block(c: Comp, bx: number, by: number)
				for k = 1, 64 do blk[k] = 0 end
				local q = qt[c.tq]
				local t = huff(hdc[c.td])
				local diff = if t == 0 then 0 else extend(bits(t), t)
				c.pred += diff
				blk[1] = c.pred * q[1]
				local ac = hac[c.ta]
				local k = 1
				while k < 64 do
					local rs = huff(ac)
					local r, s = bit32.rshift(rs, 4), bit32.band(rs, 15)
					if s == 0 then
						if r == 15 then k += 16 else break end
					else
						k += r
						if k > 63 then break end
						blk[ZZ[k + 1] + 1] = extend(bits(s), s) * q[k + 1]
						k += 1
					end
				end
				idct(blk, c.plane, c.stride, bx * 8, by * 8)
			end
			local function resync()
				-- marqueur de reprise RSTn : on vide les bits, on saute le marqueur, les prédictions repartent de 0
				bitbuf, bitcnt = 0, 0
				while pos + 1 < stop and not (buffer.readu8(data, pos) == 0xFF and buffer.readu8(data, pos + 1) >= 0xD0 and buffer.readu8(data, pos + 1) <= 0xD7) do pos += 1 end
				pos += 2
				for _, c in ipairs(scomp) do c.pred = 0 end
			end
			local n = 0
			if #scomp == 1 then
				-- une seule composante : blocs non entrelacés, juste ce qu'il faut pour couvrir l'image
				local c = scomp[1]
				local cw = (W * c.h + hmax - 1) // hmax
				local ch = (H * c.v + vmax - 1) // vmax
				for by = 0, (ch + 7) // 8 - 1 do
					for bx = 0, (cw + 7) // 8 - 1 do
						if restart > 0 and n > 0 and n % restart == 0 then resync() end
						block(c, bx, by); n += 1
					end
				end
			else
				for y = 0, my - 1 do
					for x = 0, mx - 1 do
						if restart > 0 and n > 0 and n % restart == 0 then resync() end
						for _, c in ipairs(scomp) do
							for v = 0, c.v - 1 do
								for u = 0, c.h - 1 do block(c, x * c.h + u, y * c.v + v) end
							end
						end
						n += 1
					end
				end
			end
			-- fin du balayage : prochain marqueur
			while pos + 1 < stop and not (buffer.readu8(data, pos) == 0xFF and buffer.readu8(data, pos + 1) ~= 0 and
				not (buffer.readu8(data, pos + 1) >= 0xD0 and buffer.readu8(data, pos + 1) <= 0xD7)) do pos += 1 end
			scanned += #scomp
			if scanned >= #comps then done = true end
		else
			pos = segEnd                                     -- APPn, COM… : ignorés
		end
		if not done and pos < segEnd then pos = segEnd end
	end
	if W == 0 or #comps == 0 then error("JPEG : image vide") end

	-- conversion en RGBA (couleurs : YCbCr -> RGB, chrominance agrandie)
	local out = buffer.create(W * H * 4)
	if #comps == 1 then
		local c = comps[1]
		for y = 0, H - 1 do
			local row = y * c.stride
			local o = y * W * 4
			for x = 0, W - 1 do
				local l = buffer.readu8(c.plane, row + x)
				buffer.writeu32(out, o + x * 4, 0xFF000000 + l * 0x10101)
			end
		end
	else
		local cy = comps[1]
		-- chrominance à pleine taille : interpolation bilinéaire centrée (comme le « fancy upsampling » de libjpeg),
		-- sinon les cartes de normales gardent des marches de 2 pixels le long des arêtes
		local function full(c: Comp): (buffer, number)
			local sx, sy = hmax // c.h, vmax // c.v
			if sx == 1 and sy == 1 then return c.plane, c.stride end
			local cw, ch = (W + sx - 1) // sx, (H + sy - 1) // sy
			local o = buffer.create(W * H)
			local xa, xb, xf = table.create(W, 0), table.create(W, 0), table.create(W, 0)
			for x = 0, W - 1 do
				local f = (x + 0.5) / sx - 0.5
				local i = math.floor(f)
				xf[x + 1] = f - i
				xa[x + 1] = math.clamp(i, 0, cw - 1); xb[x + 1] = math.clamp(i + 1, 0, cw - 1)
			end
			for y = 0, H - 1 do
				local f = (y + 0.5) / sy - 0.5
				local i = math.floor(f)
				local fy = f - i
				local r0 = math.clamp(i, 0, ch - 1) * c.stride
				local r1 = math.clamp(i + 1, 0, ch - 1) * c.stride
				local ro = y * W
				for x = 1, W do
					local a, b = xa[x], xb[x]
					local fx = xf[x]
					local t = buffer.readu8(c.plane, r0 + a); t += (buffer.readu8(c.plane, r0 + b) - t) * fx
					local u = buffer.readu8(c.plane, r1 + a); u += (buffer.readu8(c.plane, r1 + b) - u) * fx
					buffer.writeu8(o, ro + x - 1, t + (u - t) * fy + 0.5)
				end
			end
			return o, W
		end
		local pb, sb = full(comps[2])
		local pr, sr = full(comps[3])
		for y = 0, H - 1 do
			local ry = y * cy.stride
			local rb = y * sb
			local rr = y * sr
			local o = y * W * 4
			for x = 0, W - 1 do
				local Y = buffer.readu8(cy.plane, ry + x)
				local B = buffer.readu8(pb, rb + x) - 128
				local R = buffer.readu8(pr, rr + x) - 128
				local r = Y + 1.402 * R + 0.5
				local g = Y - 0.344136 * B - 0.714136 * R + 0.5
				local b = Y + 1.772 * B + 0.5
				r = if r < 0 then 0 elseif r > 255 then 255 else r // 1
				g = if g < 0 then 0 elseif g > 255 then 255 else g // 1
				b = if b < 0 then 0 elseif b > 255 then 255 else b // 1
				buffer.writeu32(out, o + x * 4, 0xFF000000 + b * 65536 + g * 256 + r)
			end
		end
	end
	return W, H, out
end

return decode
