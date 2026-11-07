class_name GryEE
extends RefCounted
## Dwie gry na jednym silniku (etap 11, docs/WARIANTY_GRY.md): "ee" – Empire Earth, "aoc" – Empire Earth: The Art of
## Conquest. Definicje (katalogi danych, kampanie, Language.dll, format bazy, wersje SCN, warstwy bazowe) pochodzą z
## dane/gry.json – każda z dowodem z pomiaru oryginału. Wariant gry jest niezależny od profilu instalacji/języka/modów.

const WSZYSTKIE := ["ee", "aoc"]
const DOMYSLNA := "aoc"

static var _def: Dictionary = {}


static func _wczytaj(katalog_openee: String) -> void:
	if _def.is_empty():
		var j = JSON.parse_string(FileAccess.get_file_as_string(katalog_openee.path_join("dane/gry.json")))
		_def = j.get("gry", {}) if j is Dictionary else {}


static func poprawna(gra: String) -> bool:
	return gra in WSZYSTKIE


## Definicja gry (pusty słownik dla nieznanego identyfikatora).
static func definicja(gra: String, katalog_openee: String) -> Dictionary:
	_wczytaj(katalog_openee)
	return _def.get(gra, {})


static func nazwa(gra: String, katalog_openee: String) -> String:
	return String(definicja(gra, katalog_openee).get("nazwa", gra))


## Katalogi gier (względem instalacji) w kolejności wyszukiwania danych.
static func katalogi_danych(gra: String, katalog_openee: String) -> Array:
	return definicja(gra, katalog_openee).get("katalogi_danych", [])


## Katalog własny gry (pierwszy z katalogów danych).
static func katalog(gra: String, katalog_openee: String) -> String:
	return String(definicja(gra, katalog_openee).get("katalog", ""))


static func katalogi_kampanii(gra: String, katalog_openee: String) -> Array:
	return definicja(gra, katalog_openee).get("katalogi_kampanii", [])


static func katalog_language_dll(gra: String, katalog_openee: String) -> String:
	return String(definicja(gra, katalog_openee).get("language_dll", ""))


static func format_db(gra: String, katalog_openee: String) -> String:
	return String(definicja(gra, katalog_openee).get("format_db", gra))


static func warstwy_bazowe(gra: String, katalog_openee: String) -> Array:
	return definicja(gra, katalog_openee).get("warstwy_bazowe", [])


static func wersje_scn(gra: String, katalog_openee: String) -> Array:
	return definicja(gra, katalog_openee).get("wersje_scn", []).map(func(x): return int(x))   # JSON: liczby jako float


## Czy instalacja zawiera daną grę (katalog gry z Data/data.ssa i plikiem exe).
static func dostepna(gra: String, instalacja: String, katalog_openee: String) -> bool:
	var d := definicja(gra, katalog_openee)
	if d.is_empty() or instalacja == "":
		return false
	var k := instalacja.path_join(String(d.katalog))
	return FileAccess.file_exists(k.path_join("Data/data.ssa"))


## Kampanie gry: archiwa *.ssa z WŁASNEGO katalogu kampanii (menu kampanii tej gry), posortowane.
static func kampanie(gra: String, instalacja: String, katalog_openee: String) -> Array:
	var out: Array = []
	var k := instalacja.path_join(katalog(gra, katalog_openee)).path_join("Data/Campaigns")
	if instalacja == "" or not DirAccess.dir_exists_absolute(k):
		return out
	for f in DirAccess.get_files_at(k):
		if f.to_lower().ends_with(".ssa"):
			out.append(f)
	out.sort()
	return out


## Położenie archiwum kampanii dla gry: {"rel", "wlasna": bool} albo {"blad"}. Kampanie spoza własnego katalogu
## (tylko AoC → EE, zgodnie z dane/gry.json) są zwracane z "wlasna" = false – wywołujący zgłasza to w dzienniku.
static func archiwum_kampanii(gra: String, kampania: String, instalacja: String, katalog_openee: String) -> Dictionary:
	var kat := katalogi_kampanii(gra, katalog_openee)
	for i in kat.size():
		var rel := String(kat[i]) + "/Data/Campaigns/" + kampania
		if instalacja != "" and FileAccess.file_exists(instalacja.path_join(rel)):
			return {"rel": rel, "wlasna": i == 0}
	return {"blad": "Kampania %s nie należy do gry %s (szukano w: %s)" % [kampania, nazwa(gra, katalog_openee),
		", ".join(kat.map(func(x): return String(x) + "/Data/Campaigns"))]}


## Etap 13: lista scenariuszy kampanii z `campaigns/*_scenariolist.txt` w archiwum kampanii (kolejność kampanii).
## Format: kolejne napisy [u32 długość z NUL][Windows-1250]. Wynik: [{"nr": 1.., "nazwa": tytuł z listy (w języku
## instalacji – tylko do wyświetlania), "klucz": wpis .scn w archiwum albo ""}]. Numer jest identyfikatorem stałym
## między wersjami językowymi (tytuły i nazwy plików w archiwum są tłumaczone).
static func scenariusze_kampanii(archiwum) -> Array:
	var out: Array = []
	var lista := ""
	for k in archiwum.wpisy:
		if String(k).begins_with("campaigns/") and String(k).ends_with("_scenariolist.txt"):
			lista = k
	if lista == "":
		return out
	var d: PackedByteArray = archiwum.czytaj(lista)
	var p := 0
	var prefiks := String(lista).get_file().trim_suffix("scenariolist.txt")   # np. "een1ve1s_"
	while p + 4 <= d.size():
		var n := d.decode_u32(p)
		p += 4
		if n == 0 or p + n > d.size():
			break
		var b := d.slice(p, p + n)
		if b.size() > 0 and b[b.size() - 1] == 0:
			b = b.slice(0, b.size() - 1)
		p += n
		var nazwa := TekstEE.cp1250(b)
		var klucz := "scenarios/" + prefiks + nazwa.to_lower()
		if not archiwum.wpisy.has(klucz):
			klucz = ""
			for k in archiwum.wpisy:
				if String(k).ends_with(".scn") and String(k).get_file().trim_prefix(prefiks) == nazwa.to_lower():
					klucz = k
		out.append({"nr": out.size() + 1, "nazwa": nazwa, "klucz": klucz})
	return out
