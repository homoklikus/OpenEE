extends SceneTree
## Testy integracji GDExtension OpenEE Core (etap 28), osobno od głównego zestawu (uruchom_testy.gd, 324 testy):
##   godot --headless --path godot --script res://testy/testy_gdextension.gd
## Przepływ: GDScript → GDExtension → OpenEE Core C++ → GDExtension → GDScript. Bez obliczeń ruchu w GDScript.
## Wynik: PASS / FAIL / SKIP osobno (SKIP ≠ PASS). Kod wyjścia: 0 – brak błędów, 1 – błędy.

var zal := 0
var niezal := 0
var pomin := 0


func _wynik(nazwa: String, ok: bool, szczegoly: String = "") -> void:
	if ok:
		zal += 1
	else:
		niezal += 1
	print(("PASS  " if ok else "FAIL  ") + nazwa + ("" if szczegoly == "" else "  – " + szczegoly))


func _skip(nazwa: String, powod: String) -> void:
	pomin += 1
	print("SKIP  " + nazwa + "  – " + powod)


func _f32(v: float) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(4)
	b.encode_float(0, v)
	return b


func _initialize() -> void:
	# autoloady (Konfiguracja – ścieżki instalacji) są gotowe dopiero w pierwszej klatce
	process_frame.connect(_testy, CONNECT_ONE_SHOT)


func _testy() -> void:
	var katalog := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	_wynik("klasa OpenEESymulacja zarejestrowana (biblioteka załadowana przez Godot)", CoreCpp.dostepny(),
		"" if CoreCpp.dostepny() else "zbuduj cpp/ (docs/cpp/BUDOWANIE.md) i uruchom godot --import")
	if not CoreCpp.dostepny():
		_koniec()
		return
	var sym: Object = CoreCpp.nowa_symulacja()
	print("      ", sym.wersja())
	# brak DLL: czytelny błąd, świat się nie tworzy
	var r: Dictionary = sym.zaladuj_tablice("/nieistniejacy/Low-Level Engine.dll")
	_wynik("brak DLL – błąd zamiast tablic", not r["ok"] and str(r["komunikat"]).contains("Nie znaleziono"), r["komunikat"])
	_wynik("bez tablic nie można utworzyć świata", not sym.utworz_swiat("ee"))
	# tryb przybliżony: działa, ale jest oznaczony jako niezgodny
	sym.uzyj_tablic_przyblizonych()
	_wynik("tryb przybliżony oznaczony jako niezgodny", sym.utworz_swiat("ee") and not sym.diagnostyka()["tablice_zgodne"])
	var przypadki := CoreCpp.wczytaj_przypadki(katalog)
	_wynik("przypadki syntetyczne wczytane", przypadki.size() == 9, str(przypadki.size()))
	var dll := CoreCpp.znajdz_dll("ee", root.get_node_or_null("Konfiguracja"))
	if dll == "":
		_skip("tablice z oryginalnej DLL i przypadki S1–S7 przez GDExtension", "nie znaleziono Low-Level Engine.dll (--dll=… albo OPENEE_INSTALACJA)")
		_koniec()
		return
	r = sym.zaladuj_tablice(dll)
	_wynik("wczytanie tablic z DLL użytkownika", r["ok"], "%s – %s" % [r["wariant"] if r["ok"] else r["komunikat"], dll])
	if not r["ok"]:
		_koniec()
		return
	var pola: PackedStringArray = sym.pola_migawki()
	for p in przypadki:
		var id := CoreCpp.uruchom_przypadek(sym, p)
		var ocz: Array = p["oczekiwane"]
		var po_taktach := {}
		for o in ocz:
			po_taktach[int(o["takt"])] = o
		var rozbiezny := -1
		var opis := ""
		var koniec := -1
		for t in range(1, int(p["koniec_takt"]) + 5):
			sym.takt(1)
			var m: PackedFloat64Array = sym.migawka()
			var w := {}
			for i in pola.size():
				w[pola[i]] = m[i]
			if po_taktach.has(t) and rozbiezny < 0:
				var o: Dictionary = po_taktach[t]
				for k in [["x", "x"], ["y", "y"], ["v", "v"], ["omega", "omega"], ["kurs", "kurs"]]:
					if _f32(w[k[0]]) != _f32(o[k[1]]):
						rozbiezny = t
						opis = "%s: oczekiwano %.9f, jest %.9f" % [k[0], o[k[1]], w[k[0]]]
						break
				if rozbiezny < 0 and (int(w["stan"]) != int(o["stan"]) or int(w["zdjete_punkty"]) != int(o["punkt"])):
					rozbiezny = t
					opis = "stan/punkt"
			if int(w["stan"]) == 5001:
				koniec = t
				break
		_wynik("%s przez GDExtension (bitowo f32, koniec %d)" % [p["nazwa"], koniec],
			rozbiezny < 0 and koniec == int(p["koniec_takt"]),
			"" if rozbiezny < 0 else "pierwszy rozbieżny takt %d: %s" % [rozbiezny, opis])
	# wsadowe takty: jedno wywołanie na wiele taktów = te same wyniki
	CoreCpp.uruchom_przypadek(sym, przypadki[4])
	sym.takt(100)
	var a: PackedFloat64Array = sym.migawka()
	CoreCpp.uruchom_przypadek(sym, przypadki[4])
	for i in 100:
		sym.takt(1)
	_wynik("takt(100) == 100 × takt(1)", a == sym.migawka())
	var d: Dictionary = sym.diagnostyka()
	_wynik("diagnostyka: tablice zgodne, RNG liczy losowania", d["tablice_zgodne"] and int(d["rng_losowania"]) > 0,
		"rng %d, losowań %d, nieobsługiwanych zdarzeń %d" % [d["rng_stan"], d["rng_losowania"], d["zdarzenia_nieobslugiwane"]])
	_koniec()


func _koniec() -> void:
	print("WYNIK GDExtension: %d zaliczonych, %d niezaliczonych, %d pominiętych" % [zal, niezal, pomin])
	quit(1 if niezal > 0 else 0)
