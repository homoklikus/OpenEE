extends Node
## Konfiguracja OpenEE (etap 2). Plik: <OpenEE>/konfiguracja/openee.cfg.
##
## [instalacje]  nazwa = lista kandydatów ścieżek (pierwsza istniejąca); obecnie: referencyjna (GOG), spolecznosciowa
## [zrodlo]      gra = nazwa instalacji bazowej (domyślnie "referencyjna"), profil = "aoc" | "ee"
## [warstwy]     aktywne = warstwy plików bazowych + nakładki modów (np. "hd_nieustalone" – z instalacji społecznościowej)
## [lokalizacja] jezyk_tekstow / jezyk_glosow / jezyk_kampanii = "en" | "pl"; zrodlo_pl = instalacja z polską wersją
## Zmienna OPENEE_EE_PATH (jeśli ustawiona) zastępuje ścieżkę instalacji bazowej.
## Wszystkie instalacje są wyłącznie czytane.
## Nakładka użytkownika: <OpenEE>/konfiguracja/uzytkownik.cfg (zapisywana przez launcher; openee.cfg z komentarzami
## pozostaje nietknięty). Klucze z uzytkownik.cfg zastępują openee.cfg; listy [instalacje] są doklejane na początek.
## Testy automatyczne (res://testy/…) biorą z nakładki wyłącznie [instalacje] (ścieżki), aby wynik nie zależał od wyborów
## w launcherze, a jednocześnie działał po wskazaniu instalacji w launcherze.

var katalog_openee: String = ""
var plik_konfiguracji: String = ""
var plik_uzytkownika: String = ""
var instalacje := {}               # nazwa -> ścieżka (tylko znalezione)
var zrodlo_gry: String = "referencyjna"
var profil: String = "aoc"
var instalacja_ee: String = ""      # ścieżka instalacji bazowej (zgodność z etapem 1)
var katalog_cache: String = ""
var aktywne_warstwy: PackedStringArray = []
var jezyk_tekstow: String = "en"
var jezyk_glosow: String = "en"
var jezyk_kampanii: String = "en"
var zrodlo_pl: String = "spolecznosciowa"
var skala_wysokosci: float = 1.0
var _cfg := ConfigFile.new()


func _ready() -> void:
	katalog_openee = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	plik_konfiguracji = katalog_openee.path_join("konfiguracja/openee.cfg")
	plik_uzytkownika = katalog_openee.path_join("konfiguracja/uzytkownik.cfg")
	wczytaj()


static func _rozwin(p: String) -> String:
	return p.replace("~", OS.get_environment("HOME"))


func wczytaj() -> void:
	var e := _cfg.load(plik_konfiguracji)
	if e != OK:
		Dziennik.uwaga("konfiguracja", "Brak lub błąd pliku %s (kod %d) – wartości domyślne" % [plik_konfiguracji, e])
	_nalozenie_uzytkownika()
	instalacje.clear()
	if _cfg.has_section("instalacje"):
		for nazwa in _cfg.get_section_keys("instalacje"):
			for k in _cfg.get_value("instalacje", nazwa, []):
				var p := _rozwin(String(k))
				if DirAccess.dir_exists_absolute(p.path_join("Empire Earth")):
					instalacje[nazwa] = p
					break
	# zgodność z konfiguracją etapu 1 ([instalacja] sciezki)
	if instalacje.is_empty():
		for k in _cfg.get_value("instalacja", "sciezki", []):
			var p := _rozwin(String(k))
			if DirAccess.dir_exists_absolute(p.path_join("Empire Earth")):
				instalacje["referencyjna"] = p
				break
	zrodlo_gry = String(_cfg.get_value("zrodlo", "gra", "referencyjna"))
	profil = String(_cfg.get_value("zrodlo", "profil", "aoc"))
	var env := OS.get_environment("OPENEE_EE_PATH")
	if env != "":
		instalacje[zrodlo_gry] = env
	instalacja_ee = instalacje.get(zrodlo_gry, "")
	for n in instalacje:
		Dziennik.info("konfiguracja", "Instalacja '%s': %s" % [n, instalacje[n]])
	if instalacja_ee == "":
		Dziennik.blad("konfiguracja", "Nie znaleziono instalacji bazowej '%s'" % zrodlo_gry)
	var c := String(_cfg.get_value("cache", "katalog", "cache"))
	katalog_cache = c if c.is_absolute_path() else katalog_openee.path_join(c)
	DirAccess.make_dir_recursive_absolute(katalog_cache)
	aktywne_warstwy = PackedStringArray(_cfg.get_value("warstwy", "aktywne", ["vanilla", "aoc"]))
	jezyk_tekstow = String(_cfg.get_value("lokalizacja", "jezyk_tekstow", "en"))
	jezyk_glosow = String(_cfg.get_value("lokalizacja", "jezyk_glosow", "en"))
	jezyk_kampanii = String(_cfg.get_value("lokalizacja", "jezyk_kampanii", jezyk_glosow))
	zrodlo_pl = String(_cfg.get_value("lokalizacja", "zrodlo_pl", "spolecznosciowa"))
	skala_wysokosci = float(_cfg.get_value("render", "skala_wysokosci", 1.0))
	Dziennik.info("konfiguracja", "Baza: %s (%s), warstwy: %s, teksty: %s, głosy: %s, kampanie: %s" % [
		zrodlo_gry, profil, ", ".join(aktywne_warstwy), jezyk_tekstow, jezyk_glosow, jezyk_kampanii])


func wartosc(sekcja: String, klucz: String, domyslna: Variant = null) -> Variant:
	return _cfg.get_value(sekcja, klucz, domyslna)


## Tryb testów automatycznych – nakładka użytkownika jest wtedy pomijana.
static func tryb_testow() -> bool:
	for a in OS.get_cmdline_args():
		if String(a).contains("res://testy/"):
			return true
	return false


func _nalozenie_uzytkownika() -> void:
	if not FileAccess.file_exists(plik_uzytkownika):
		return
	var u := ConfigFile.new()
	if u.load(plik_uzytkownika) != OK:
		Dziennik.uwaga("konfiguracja", "Nie można odczytać %s" % plik_uzytkownika)
		return
	for sek in u.get_sections():
		if tryb_testow() and sek != "instalacje":
			continue   # testy: tylko ścieżki instalacji (wskazane przez użytkownika), bez jego wyborów profilu/języka
		for k in u.get_section_keys(sek):
			var v: Variant = u.get_value(sek, k)
			if sek == "instalacje":
				var baza: Array = _cfg.get_value(sek, k, [])
				var nowa: Array = (v if v is Array else [v]).duplicate()
				for x in baza:
					if not x in nowa:
						nowa.append(x)
				v = nowa
			_cfg.set_value(sek, k, v)
	Dziennik.info("konfiguracja", "Nakładka użytkownika: %s" % plik_uzytkownika)


## Odczyt ustawienia z nakładki użytkownika (np. sekcja [launcher]).
func wartosc_uzytkownika(sekcja: String, klucz: String, domyslna: Variant = null) -> Variant:
	var u := ConfigFile.new()
	if tryb_testow() or u.load(plik_uzytkownika) != OK:
		return domyslna
	return u.get_value(sekcja, klucz, domyslna)


## Zapis ustawień do konfiguracja/uzytkownik.cfg (openee.cfg nie jest zmieniany). zmiany = {"sekcja/klucz": wartość}.
## W trybie testów nic nie jest zapisywane. Po zapisie konfiguracja jest wczytywana ponownie.
func zapisz_uzytkownika(zmiany: Dictionary, przeladuj := true) -> bool:
	if tryb_testow():
		return false
	var u := ConfigFile.new()
	u.load(plik_uzytkownika)
	for klucz in zmiany:
		var cz := String(klucz).split("/", true, 1)
		if zmiany[klucz] == null:
			if u.has_section_key(cz[0], cz[1]):
				u.erase_section_key(cz[0], cz[1])
		else:
			u.set_value(cz[0], cz[1], zmiany[klucz])
	var e := u.save(plik_uzytkownika)
	if e != OK:
		Dziennik.blad("konfiguracja", "Zapis %s nieudany (kod %d)" % [plik_uzytkownika, e])
		return false
	if przeladuj:
		_cfg = ConfigFile.new()
		wczytaj()
	return true


## Czy katalog wygląda na instalację Empire Earth (podkatalog "Empire Earth" z Data/data.ssa).
static func czy_instalacja_ee(sciezka: String) -> Dictionary:
	var p := _rozwin(sciezka)
	var ee := DirAccess.dir_exists_absolute(p.path_join("Empire Earth"))
	var dane := FileAccess.file_exists(p.path_join("Empire Earth/Data/data.ssa"))
	var aoc := DirAccess.dir_exists_absolute(p.path_join("Empire Earth - The Art of Conquest"))
	var gog := false
	for f in DirAccess.get_files_at(p) if DirAccess.dir_exists_absolute(p) else PackedStringArray():
		if f.begins_with("goggame-") and f.ends_with(".info"):
			gog = true
	return {"ok": ee and dane, "ee": ee, "dane": dane, "aoc": aoc, "gog": gog, "sciezka": p}
