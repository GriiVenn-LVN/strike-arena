--!strict
-- ServerStorage/SkinInflate (ModuleScript, Studio seulement)
-- Décompresse le deflate « brut » (RFC 1951, comme zlib.compressobj(wbits=-15) en Python) des peintures et cartes des
-- skins de ServerStorage/SkinTexturesHQ (tools/skins_hq_to_lua.py). Seul l'envoi depuis Studio (MeshUploader →
-- SkinPaint.uploadAll) s'en sert : rien de tout ça n'est envoyé aux joueurs.
--   inflate(src: buffer, outSize: number?) -> buffer
local band, lshift, rshift, bor = bit32.band, bit32.lshift, bit32.rshift, bit32.bor
local readu8, writeu8, bcopy, bcreate = buffer.readu8, buffer.writeu8, buffer.copy, buffer.create

-- longueurs et distances (bases + bits en plus), ordre des longueurs de codes de l'arbre dynamique
local LBASE = { 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258 }
local LEXT = { 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0 }
local DBASE = { 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073,
	4097, 6145, 8193, 12289, 16385, 24577 }
local DEXT = { 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13 }
local CLORDER = { 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 }

-- table de Huffman canonique : counts[len] et symboles triés (méthode de « puff » de zlib)
type Huff = { counts: { number }, symbols: { number } }
local function build(lengths: { number }, n: number): Huff
	local counts = table.create(16, 0)
	for i = 0, n - 1 do local l = lengths[i + 1]; counts[l + 1] += 1 end
	local offs = table.create(16, 0)              -- offs[l + 1] : premier rang des symboles de longueur l
	for l = 1, 14 do offs[l + 2] = offs[l + 1] + counts[l + 1] end
	local symbols = table.create(n, 0)
	for i = 0, n - 1 do
		local l = lengths[i + 1]
		if l ~= 0 then symbols[offs[l + 1] + 1] = i; offs[l + 1] += 1 end
	end
	counts[1] = 0
	return { counts = counts, symbols = symbols }
end

local function inflate(src: buffer, outSize: number?): buffer
	local srcLen = buffer.len(src)
	local cap = outSize or srcLen * 6
	local out = bcreate(cap)
	local op = 0
	local ip, bitbuf, bitcnt = 0, 0, 0

	local function need(n: number)
		while bitcnt < n do
			local b = if ip < srcLen then readu8(src, ip) else 0
			ip += 1
			bitbuf = bitbuf + lshift(b, bitcnt)
			bitcnt += 8
		end
	end
	local function bits(n: number): number
		need(n)
		local v = band(bitbuf, lshift(1, n) - 1)
		bitbuf = rshift(bitbuf, n); bitcnt -= n
		return v
	end
	local function grow(n: number)
		if op + n <= cap then return end
		while op + n > cap do cap *= 2 end
		local nb = bcreate(cap)
		bcopy(nb, 0, out, 0, op)
		out = nb
	end
	local function decode(h: Huff): number
		local code, first, index = 0, 0, 0
		local counts, symbols = h.counts, h.symbols
		for len = 1, 15 do
			code = bor(code, bits(1))
			local count = counts[len + 1]
			if code - count < first then return symbols[index + (code - first) + 1] end
			index += count; first += count
			first = lshift(first, 1); code = lshift(code, 1)
		end
		error("[SkinInflate] code de Huffman invalide")
	end

	local fixedL: Huff?, fixedD: Huff?
	repeat
		local final = bits(1)
		local btype = bits(2)
		if btype == 0 then
			bitbuf, bitcnt = 0, 0                       -- bloc stocké : on se recale sur l'octet
			local len = buffer.readu16(src, ip); ip += 4
			grow(len)
			bcopy(out, op, src, ip, len); op += len; ip += len
		else
			local lh: Huff, dh: Huff
			if btype == 1 then
				if not fixedL then
					local l = table.create(288, 8)
					for i = 145, 256 do l[i] = 9 end
					for i = 257, 280 do l[i] = 7 end
					fixedL = build(l, 288); fixedD = build(table.create(30, 5), 30)
				end
				lh, dh = fixedL :: Huff, fixedD :: Huff
			elseif btype == 2 then
				local nlen, ndist, ncode = bits(5) + 257, bits(5) + 1, bits(4) + 4
				local cl = table.create(19, 0)
				for i = 1, ncode do cl[CLORDER[i] + 1] = bits(3) end
				local ch = build(cl, 19)
				local lengths = table.create(nlen + ndist, 0)
				local i = 0
				while i < nlen + ndist do
					local sym = decode(ch)
					if sym < 16 then lengths[i + 1] = sym; i += 1
					else
						local rep, val = 0, 0
						if sym == 16 then val = lengths[i]; rep = 3 + bits(2)
						elseif sym == 17 then rep = 3 + bits(3)
						else rep = 11 + bits(7) end
						for _ = 1, rep do lengths[i + 1] = val; i += 1 end
					end
				end
				local ll, dl = table.create(nlen, 0), table.create(ndist, 0)
				for k = 1, nlen do ll[k] = lengths[k] end
				for k = 1, ndist do dl[k] = lengths[nlen + k] end
				lh, dh = build(ll, nlen), build(dl, ndist)
			else
				error("[SkinInflate] type de bloc invalide")
			end
			while true do
				local sym = decode(lh)
				if sym < 256 then
					grow(1); writeu8(out, op, sym); op += 1
				elseif sym == 256 then
					break
				else
					sym -= 257
					local len = LBASE[sym + 1] + bits(LEXT[sym + 1])
					local ds = decode(dh)
					local dist = DBASE[ds + 1] + bits(DEXT[ds + 1])
					grow(len)
					local from = op - dist
					if dist >= len then
						bcopy(out, op, out, from, len)
					else
						for k = 0, len - 1 do writeu8(out, op + k, readu8(out, from + k)) end
					end
					op += len
				end
			end
		end
	until final == 1
	if op == cap then return out end
	local res = bcreate(op)
	bcopy(res, 0, out, 0, op)
	return res
end

return inflate
