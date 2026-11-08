class_name CoreCpp
extends RefCounted
## Dostęp do natywnego OpenEE Core (C++, GDExtension) z GDScript – etap 28 (docs/cpp/INTEGRACJA_GODOT.md).
## Tylko przygotowanie danych i wywołania; obliczenia ruchu wykonuje Core. Gdy biblioteka nie jest zbudowana,
## dostepny() zwraca false, a starsze sceny działają bez zmian.

const KLASA := "OpenEESymulacja"
const PLIK_PRZYPADKOW := "dane/testy_ruchu/ruch_syntetyczne_etap27.json"


static func dostepny() -> bool:
	return ClassDB.class_exists(KLASA)


static func nowa_symulacja() -> Object:
	return ClassDB.instantiate(KLASA) if dostepny() else null


## Kandydaci ścieżki Low-Level Engine.dll dla gry „ee” / „aoc” z katalogu instalacji (konfiguracja OpenEE).
static func sciezki_dll(katalog_instalacji: String, gra: String) -> PackedStringArray:
	var podkatalog := "Empire Earth - The Art of Conquest" if gra == "aoc" else "Empire Earth"
	var w := PackedStringArray()
	if katalog_instalacji == "":
		return w
	w.append(katalog_instalacji.path_join(podkatalog).path_join("Low-Level Engine.dll"))
	w.append(katalog_instalacji.path_join("Low-Level Engine.dll"))
	w.append(katalog_instalacji.get_base_dir().path_join(podkatalog).path_join("Low-Level Engine.dll"))
	return w


## Pierwsza istniejąca ścieżka DLL: argument --dll=…, zmienna OPENEE_DLL_EE/AOC, instalacje z konfiguracji.
static func znajdz_dll(gra: String, konfiguracja: Object = null) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dll="):
			return a.trim_prefix("--dll=")
	var env := OS.get_environment("OPENEE_DLL_AOC" if gra == "aoc" else "OPENEE_DLL_EE")
	if env != "" and FileAccess.file_exists(env):
		return env
	var katalogi := PackedStringArray()
	var inst := OS.get_environment("OPENEE_INSTALACJA")
	if inst != "":
		katalogi.append(inst)
	if konfiguracja != null:
		if str(konfiguracja.get("instalacja_ee")) != "":
			katalogi.append(str(konfiguracja.get("instalacja_ee")))
		var d: Variant = konfiguracja.get("instalacje")
		if d is Dictionary:
			for k in d:
				katalogi.append(str(d[k]))
	for k in katalogi:
		for p in sciezki_dll(k, gra):
			if FileAccess.file_exists(p):
				return p
	return ""


## Przypadki syntetyczne etapu 27 (dane wejściowe – bez obliczeń).
static func wczytaj_przypadki(katalog_openee: String) -> Array:
	var p := katalog_openee.path_join(PLIK_PRZYPADKOW)
	if not FileAccess.file_exists(p):
		return []
	var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	return j["przypadki"] if j is Dictionary else []


## Konfiguruje jednostkę przypadku w symulacji Core. Zwraca id jednostki (0 przy błędzie).
static func uruchom_przypadek(sym: Object, przypadek: Dictionary) -> int:
	if not sym.utworz_swiat(przypadek["wariant"]):
		return 0
	var s: Dictionary = przypadek["start"]
	var id: int = sym.dodaj_jednostke(przypadek["parametry"], s["x"], s["y"], s["kurs"])
	var xy := PackedFloat64Array()
	for p in przypadek["punkty"]:
		xy.append(p["x"])
		xy.append(p["y"])
	sym.nadaj_trase(id, xy, przypadek["kurs_koncowy"], "advance")
	return id
