class_name ImporterTekstur
extends ImporterEE
## Tekstury SST (EE) i TGA (AoC) → Image (RGBA8). Format: docs/FORMATY.md §SST.

func nazwa() -> String:
	return "tekstury SST/TGA"


func rozszerzenia() -> PackedStringArray:
	return PackedStringArray(["sst", "tga"])


static func _tga(d: PackedByteArray, p: int) -> Dictionary:
	var idlen := d[p]
	var typ := d[p + 2]
	var w := d.decode_u16(p + 12)
	var h := d.decode_u16(p + 14)
	var bpp := d[p + 16]
	var desc := d[p + 17]
	if d[p + 1] != 0 or typ != 2 or (bpp != 24 and bpp != 32):
		return {"blad": "TGA: nieobsługiwany typ %d / %d bpp" % [typ, bpp]}
	var bp := bpp / 8
	var start := p + 18 + idlen
	var rgba := PackedByteArray(); rgba.resize(w * h * 4)
	var gora := (desc & 0x20) != 0
	for y in range(h):
		var sy := y if gora else h - 1 - y
		var src := start + sy * w * bp
		var dst := y * w * 4
		for x in range(w):
			rgba[dst] = d[src + 2]
			rgba[dst + 1] = d[src + 1]
			rgba[dst + 2] = d[src]
			rgba[dst + 3] = d[src + 3] if bp == 4 else 255
			src += bp
			dst += 4
	return {"obraz": Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, rgba), "koniec": start + w * h * bp}


## Zwraca {"obrazy": [Image...], "naglowek": {...}} lub {"blad": ...}
static func dekoduj(d: PackedByteArray) -> Dictionary:
	if d.size() < 18:
		return {"blad": "za krótki plik"}
	if d[1] == 0:                       # czysty TGA
		var t := _tga(d, 0)
		return t if t.has("blad") else {"obrazy": [t.obraz], "naglowek": {"format": "tga"}}
	var n := d.decode_u32(2)
	var hdr := {"format": "sst", "klatki": n, "w": d.decode_u32(6), "h": d.decode_u32(10)}
	var p := 14
	var obrazy: Array[Image] = []
	for i in range(n):
		p += 1                          # bajt znacznika przed każdym obrazem
		var t := _tga(d, p)
		if t.has("blad"):
			return t
		obrazy.append(t.obraz)
		p = t.koniec
	return {"obrazy": obrazy, "naglowek": hdr}


func importuj(dane: PackedByteArray, kontekst: Dictionary) -> Variant:
	var r := dekoduj(dane)
	if r.has("blad"):
		ImporterEE.zglos("blad", "importer_tekstur", "%s: %s" % [kontekst.get("klucz", "?"), r.blad])
		return null
	return r.obrazy[0]
