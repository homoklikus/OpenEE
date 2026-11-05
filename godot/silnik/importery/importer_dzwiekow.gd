class_name ImporterDzwiekow
extends ImporterEE
## Dźwięki EE: WAV (PCM 8/16-bit) i MP3 → AudioStream bez przekodowania (dane źródłowe przekazywane wprost).

func nazwa() -> String:
	return "dźwięki WAV/MP3"


func rozszerzenia() -> PackedStringArray:
	return PackedStringArray(["wav", "mp3"])


static func info_wav(d: PackedByteArray) -> Dictionary:
	if d.size() < 44 or d.slice(0, 4).get_string_from_ascii() != "RIFF":
		return {}
	var p := 12
	var info := {}
	while p + 8 <= d.size():
		var id := d.slice(p, p + 4).get_string_from_ascii()
		var n := d.decode_u32(p + 4)
		if id == "fmt ":
			info = {"format": d.decode_u16(p + 8), "kanaly": d.decode_u16(p + 10), "hz": d.decode_u32(p + 12),
				"bity": d.decode_u16(p + 22)}
		elif id == "data":
			info["dane_bajty"] = n
			if info.has("hz"):
				info["sekundy"] = float(n) / (info.hz * info.kanaly * info.bity / 8)
		p += 8 + n + (n & 1)
	return info


func importuj(dane: PackedByteArray, kontekst: Dictionary) -> Variant:
	var k: String = kontekst.get("klucz", "")
	if k.ends_with(".mp3"):
		var s := AudioStreamMP3.new()
		s.data = dane
		return s
	var st: AudioStreamWAV = AudioStreamWAV.load_from_buffer(dane)
	if st == null:
		ImporterEE.zglos("blad", "importer_dzwiekow", "%s: nie udało się odczytać WAV" % k)
	return st
