extends Node
## Konfiguracja OpenEE (etap 2). Plik: <OpenEE>/konfiguracja/openee.cfg.
##
## [instalacje]  nazwa = lista kandydatów ścieżek (pierwsza istniejąca); obecnie: referencyjna (GOG), spolecznosciowa
## [gra]         wariant = "ee" (Empire Earth) | "aoc" (Empire Earth: The Art of Conquest) – wybór GRY (etap 11),
##               niezależny od instalacji, języka i modów; definicje gier: dane/gry.json (GryEE)
## [zrodlo]      gra = nazwa instalacji bazowej (domyślnie "referencyjna"); profil = "aoc" | "ee" – klucz sprzed etapu 11,
##               czytany tylko, gdy brak [gra] wariant (migracja: launcher dopisuje [gra] wariant, nic nie usuwa)
## [warstwy]     aktywne = warstwy plików bazowych + nakładki modów (np. "hd_nieustalone" – z instalacji społecznościowej)
## [lokalizacja] jezyk_tekstow / jezyk_glosow / jezyk_kampanii = "en" | "pl"; zrodlo_pl = instalacja z polską wersją
## Zmienna OPENEE_EE_PATH (jeśli ustawiona) zastępuje ścieżkę instalacji bazowej.
## Zmienna OPENEE_KONFIGURACJA_UZYTKOWNIKA (etap 11) wskazuje inny plik nakładki użytkownika zamiast
## konfiguracja/uzytkownik.cfg – testy profili na odseparowanych konfiguracjach bez zmiany ustawień użytkownika
## (to samo: argument `--konfiguracja-uzytkownika=<plik>` po "--"). Argument `--gra=ee|aoc` po "--" wybiera grę
## niezależnie od plików konfiguracji (testy, rendery porównawcze).
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
var gra: String = GryEE.DOMYSLNA        # wariant gry: "ee" | "aoc" (etap 11)
var zrodlo_wyboru_gry: String = ""        # skąd pochodzi wybór (plik i klucz albo „argument --gra”)
## Zgodność z kodem sprzed etapu 11: `profil` = wariant gry.
var profil: String:
	get: return gra
	set(v): gra = v
var instalacja_ee: String = ""      # ścieżka instalacji bazowej (zgodność z etapem 1)
var katalog_cache: String = ""
var aktywne_warstwy: PackedStringArray = []
var jezyk_tekstow: String = "en"
var jezyk_glosow: String = "en"
var jezyk_kampanii: String = "en"
var zrodlo_pl: String = "spolecznosciowa"
var skala_wysokosci: float = 1.0
var _cfg := ConfigFile.new()
var _u_gra: Variant = null       # [gra] wariant z nakładki użytkownika (null – brak)
var _u_profil: Variant = null    # [zrodlo] profil z nakładki użytkownika (klucz sprzed etapu 11)


func _ready() -> void:
	katalog_openee = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	plik_konfiguracji = katalog_openee.path_join("konfiguracja/openee.cfg")
	plik_uzytkownika = katalog_openee.path_join("konfiguracja/uzytkownik.cfg")
	var alt := OS.get_environment("OPENEE_KONFIGURACJA_UZYTKOWNIKA")
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--konfiguracja-uzytkownika="):
			alt = String(a).split("=", true, 1)[1]          # to samo z linii poleceń (np. rendery MCP oe_render)
	if alt != "":
		plik_uzytkownika = alt
	wczytaj()


static func _rozwin(p: String) -> String:
	return p.replace("~", OS.get_environment("HOME"))


func wczytaj() -> void:
	var e := _cfg.load(plik_konfiguracji)
	if e != OK:
		Dziennik.uwaga("konfiguracja", "Brak lub błąd pliku %s (kod %d) – wartości domyślne" % [plik_konfiguracji, e])
	var t_gra: Variant = _cfg.get_value("gra", "wariant") if _cfg.has_section_key("gra", "wariant") else null
	var t_prof: Variant = _cfg.get_value("zrodlo", "profil") if _cfg.has_section_key("zrodlo", "profil") else null
	_u_gra = null; _u_profil = null
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
	var arg_gra: Variant = null
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--gra="):
			arg_gra = String(a).split("=", true, 1)[1]
	var wyb := wybierz_gre(arg_gra, _u_gra, _u_profil, t_gra, t_prof)
	gra = wyb.gra; zrodlo_wyboru_gry = wyb.zrodlo
	if wyb.has("blad"):
		Dziennik.blad("konfiguracja", wyb.blad)
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
	aktywne_warstwy = PackedStringArray(_cfg.get_value("warstwy", "aktywne", GryEE.warstwy_bazowe(gra, katalog_openee)))
	# warstwy bazowe muszą odpowiadać grze (np. stary profil "ee" z warstwą "aoc" albo argument --gra)
	var baz := GryEE.warstwy_bazowe(gra, katalog_openee)
	var popr := PackedStringArray(baz)
	for w in aktywne_warstwy:
		if not w in ["vanilla", "aoc"] and not w in popr:
			popr.append(w)
	if popr != aktywne_warstwy:
		Dziennik.info("konfiguracja", "Warstwy bazowe dopasowane do gry '%s': %s → %s" % [gra, ", ".join(aktywne_warstwy), ", ".join(popr)])
		aktywne_warstwy = popr
	jezyk_tekstow = String(_cfg.get_value("lokalizacja", "jezyk_tekstow", "en"))
	jezyk_glosow = String(_cfg.get_value("lokalizacja", "jezyk_glosow", "en"))
	jezyk_kampanii = String(_cfg.get_value("lokalizacja", "jezyk_kampanii", jezyk_glosow))
	zrodlo_pl = String(_cfg.get_value("lokalizacja", "zrodlo_pl", "spolecznosciowa"))
	skala_wysokosci = float(_cfg.get_value("render", "skala_wysokosci", 1.0))
	Dziennik.info("konfiguracja", "Gra: %s (%s), instalacja: %s, warstwy: %s, teksty: %s, głosy: %s, kampanie: %s" % [
		gra, zrodlo_wyboru_gry, zrodlo_gry, ", ".join(aktywne_warstwy), jezyk_tekstow, jezyk_glosow, jezyk_kampanii])


## Wybór gry (etap 11). Pierwszeństwo: argument --gra, użytkownik [gra] wariant, użytkownik [zrodlo] profil (klucz sprzed
## etapu 11), openee.cfg [gra] wariant, openee.cfg [zrodlo] profil, domyślna. null = brak klucza.
## Zwraca {"gra", "zrodlo"} oraz "blad" dla nieznanej wartości (wtedy gra domyślna).
static func wybierz_gre(arg: Variant, u_gra: Variant, u_prof: Variant, t_gra: Variant, t_prof: Variant) -> Dictionary:
	var w := {"gra": GryEE.DOMYSLNA, "zrodlo": "domyślna"}
	for kand in [[arg, "argument --gra"], [u_gra, "uzytkownik: [gra] wariant"], [u_prof, "uzytkownik: [zrodlo] profil (stary klucz)"],
			[t_gra, "openee.cfg: [gra] wariant"], [t_prof, "openee.cfg: [zrodlo] profil (stary klucz)"]]:
		if kand[0] != null:
			w = {"gra": String(kand[0]), "zrodlo": kand[1]}
			break
	if not GryEE.poprawna(w.gra):
		w["blad"] = "Nieznany wariant gry '%s' (%s) – dozwolone: %s; użyto '%s'" % [
			w.gra, w.zrodlo, ", ".join(GryEE.WSZYSTKIE), GryEE.DOMYSLNA]
		w.gra = GryEE.DOMYSLNA
	return w


func wartosc(sekcja: String, klucz: String, domyslna: Variant = null) -> Variant:
	return _cfg.get_value(sekcja, klucz, domyslna)


## Tryb testów automatycznych – nakładka użytkownika jest wtedy pomijana.
static func tryb_testow() -> bool:
	for a in OS.get_cmdline_args():
		if String(a).contains("res://testy/"):
			return true
	return false


## Diagnostyka (etap 10): `--konfiguracja-domyslna` po "--" – jak w testach pomija wybory użytkownika (profil,
## warstwy, języki z konfiguracja/uzytkownik.cfg), zostawia tylko ścieżki instalacji; powtarzalne rendery porównawcze
## niezależnie od profilu wybranego w launcherze.
static func konfiguracja_domyslna() -> bool:
	return "--konfiguracja-domyslna" in OS.get_cmdline_user_args()


func _nalozenie_uzytkownika() -> void:
	if not FileAccess.file_exists(plik_uzytkownika):
		return
	var u := ConfigFile.new()
	if u.load(plik_uzytkownika) != OK:
		Dziennik.uwaga("konfiguracja", "Nie można odczytać %s" % plik_uzytkownika)
		return
	for sek in u.get_sections():
		if (tryb_testow() or konfiguracja_domyslna()) and sek != "instalacje":
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
			if sek == "gra" and k == "wariant": _u_gra = v
			if sek == "zrodlo" and k == "profil": _u_profil = v
			_cfg.set_value(sek, k, v)
	Dziennik.info("konfiguracja", "Nakładka użytkownika: %s" % plik_uzytkownika)


## Odczyt ustawienia z nakładki użytkownika (np. sekcja [launcher]).
func wartosc_uzytkownika(sekcja: String, klucz: String, domyslna: Variant = null) -> Variant:
	var u := ConfigFile.new()
	if tryb_testow() or u.load(plik_uzytkownika) != OK or not u.has_section_key(sekcja, klucz):
		return domyslna
	return u.get_value(sekcja, klucz)


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
