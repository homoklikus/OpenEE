class_name StanLaunchera
## Model launchera (bez UI): wybór GRY (Empire Earth / The Art of Conquest – etap 11), profile (instalacja + mody),
## język gry, ustawienia launchera. Gra i profil są niezależne: ten sam profil (np. instalacja społecznościowa z PL
## i nakładką HD) działa z obiema grami.
## Migracja (etap 11): profile wbudowane "vanilla_aoc"/"vanilla_ee" zawierały grę – są aliasami profilu "vanilla"
## z grą aoc/ee; [gra] wariant dopisywany na podstawie starego [zrodlo] profil. Kopia uzytkownik.cfg przed migracją:
## konfiguracja/uzytkownik.cfg.przed_etapem11. Pole "gra" w profilach użytkownika jest ignorowane (pozostaje w pliku).
## Trwałość: konfiguracja/uzytkownik.cfg (przez Konfiguracja.zapisz_uzytkownika) oraz
## konfiguracja/profile_uzytkownika.json (profile utworzone przez użytkownika). openee.cfg nie jest zmieniany.
## `tylko_pamiec = true` (testy) – nic nie jest zapisywane, konfiguracja silnika nie jest zmieniana.

signal zmieniono(co: String)

const WERSJA := "0.5.2-dev"
const JEZYKI_GRY := ["pl", "en", "pl_en"]   # presety; "wlasny" gdy konfiguracja nie pasuje do żadnego

var K: Node            # autoload Konfiguracja
var Z: Node            # autoload Zasoby
var tylko_pamiec := false
var stosuj_w_pamieci := false    # z tylko_pamiec: zmiany gry/profilu trafiają do silnika w pamięci (testy przełączania)
var katalog := ""
var profile: Array = []          # [{id, nazwa, opis, zrodlo, mody[], wbudowany}]
var profil_id := "vanilla"
var gra_id := GryEE.DOMYSLNA      # "ee" | "aoc"
var migracja: Dictionary = {}     # opis wykonanej migracji (pusty – brak)
const ALIASY_PROFILI := {"vanilla_aoc": ["vanilla", "aoc"], "vanilla_ee": ["vanilla", "ee"]}
var jezyk_ui := "pl"
var uzyj_openee := true
var skala_ui := 1.0
var dostepne_mody: Array = []    # [{id, nazwa, opis, zrodlo, typ, dostepny}]


func _init(konfiguracja: Node, zasoby: Node, pamiec := false) -> void:
	K = konfiguracja
	Z = zasoby
	tylko_pamiec = pamiec
	katalog = K.katalog_openee
	_wczytaj_profile()
	_wczytaj_mody()
	var sys := OS.get_locale_language()
	jezyk_ui = String(_ust("jezyk_ui", "pl" if sys == "pl" else "en"))
	uzyj_openee = bool(_ust("uzyj_openee", true))
	skala_ui = clampf(float(_ust("skala_ui", 1.0)), 0.7, 1.4)
	gra_id = String(K.gra) if GryEE.poprawna(String(K.gra)) else GryEE.DOMYSLNA
	profil_id = String(_ust("profil", _profil_z_konfiguracji()))
	_migruj()
	if profil(profil_id).is_empty():
		profil_id = "vanilla"


## Migracja konfiguracji sprzed etapu 11 (bez utraty ustawień; nic nie jest usuwane).
func _migruj() -> void:
	var zmiany := {}
	if ALIASY_PROFILI.has(profil_id):
		var a: Array = ALIASY_PROFILI[profil_id]
		migracja["profil"] = "%s → %s + gra %s" % [profil_id, a[0], a[1]]
		if K.wartosc_uzytkownika("gra", "wariant", null) == null:
			gra_id = a[1]
		profil_id = a[0]
		zmiany["launcher/profil"] = profil_id
	if not tylko_pamiec and K.wartosc_uzytkownika("gra", "wariant", null) == null \
			and FileAccess.file_exists(K.plik_uzytkownika):
		migracja["gra"] = "[gra] wariant = %s (z %s)" % [gra_id, K.zrodlo_wyboru_gry]
		zmiany["gra/wariant"] = gra_id
		zmiany["warstwy/aktywne"] = _warstwy_profilu(profil(profil_id)) if not profil(profil_id).is_empty() else K.aktywne_warstwy
	if zmiany.is_empty() or tylko_pamiec or K.tryb_testow():
		return      # testy: żadnych operacji na plikach użytkownika (ani zapisu, ani kopii zapasowej)
	var kopia: String = String(K.plik_uzytkownika) + ".przed_etapem11"
	if not FileAccess.file_exists(kopia):
		DirAccess.copy_absolute(K.plik_uzytkownika, kopia)
	_zapisz(zmiany)
	var dz: Node = Engine.get_main_loop().root.get_node_or_null("Dziennik") if Engine.get_main_loop() is SceneTree else null
	if dz:
		dz.info("launcher", "Migracja konfiguracji (etap 11): %s; kopia: %s" % [str(migracja), kopia])
	if Z and Z.has_method("przebuduj_zrodla"):
		Z.przebuduj_zrodla()


func _ust(klucz: String, dom: Variant) -> Variant:
	return dom if tylko_pamiec else K.wartosc_uzytkownika("launcher", klucz, dom)


func _zapisz(zmiany: Dictionary) -> void:
	if not tylko_pamiec:
		K.zapisz_uzytkownika(zmiany)


func _json(rel: String) -> Variant:
	var p := katalog.path_join(rel)
	return JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else null


# ---------------------------------------------------------------- profile

func _wczytaj_profile() -> void:
	profile.clear()
	var d: Variant = _json("dane/launcher/profile_domyslne.json")
	for p in (d.get("profile", []) if d is Dictionary else []):
		var q: Dictionary = p.duplicate(true)
		q["wbudowany"] = true
		profile.append(q)
	if profile.is_empty():
		profile.append({"id": "vanilla", "nazwa": {"pl": "Vanilla", "en": "Vanilla"},
			"opis": {"pl": "Oryginalna gra bez modyfikacji.", "en": "Original game without modifications."},
			"zrodlo": "referencyjna", "mody": [], "wbudowany": true})
	if not tylko_pamiec:
		var u: Variant = _json("konfiguracja/profile_uzytkownika.json")
		for p in (u.get("profile", []) if u is Dictionary else []):
			var q: Dictionary = p.duplicate(true)
			q["wbudowany"] = false
			profile.append(q)


func _zapisz_profile_uzytkownika() -> void:
	if tylko_pamiec:
		return
	var lista := []
	for p in profile:
		if not p.get("wbudowany", false):
			var q: Dictionary = p.duplicate(true)
			q.erase("wbudowany")
			lista.append(q)
	var f := FileAccess.open(katalog.path_join("konfiguracja/profile_uzytkownika.json"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"opis": "Profile utworzone w launcherze OpenEE", "profile": lista}, "  "))


func profil(id: String) -> Dictionary:
	if ALIASY_PROFILI.has(id):
		id = ALIASY_PROFILI[id][0]
	for p in profile:
		if p.id == id:
			return p
	return {}


func aktualny() -> Dictionary:
	return profil(profil_id)


static func tekst(v: Variant, jez: String) -> String:
	if v is Dictionary:
		return String(v.get(jez, v.get("en", v.values()[0] if not v.is_empty() else "")))
	return String(v)


func _profil_z_konfiguracji() -> String:
	var w: PackedStringArray = K.aktywne_warstwy
	for p in profile:
		if p.zrodlo == K.zrodlo_gry and _warstwy_profilu(p) == Array(w):
			return p.id
	return "vanilla"


## Warstwy silnika: warstwy bazowe WYBRANEJ GRY (dane/gry.json) + nakładki modów profilu.
func _warstwy_profilu(p: Dictionary) -> Array:
	var w: Array = GryEE.warstwy_bazowe(gra_id, katalog).duplicate()
	for m in p.get("mody", []):
		if m in p.get("wylaczone", []):
			continue
		var md := mod(m)
		if not md.is_empty() and md.get("typ", "") == "nakladka":
			w.append(m)
	return w


func wybierz_profil(id: String) -> bool:
	var p := profil(id)
	if p.is_empty():
		return false
	profil_id = p.id
	_zastosuj()
	zmieniono.emit("profil")
	return true


## Zapisuje profil i grę do konfiguracji silnika i przebudowuje źródła zasobów (czyści pamięć podręczną poprzedniej gry).
## [zrodlo] profil jest zapisywany równolegle z [gra] wariant – zgodność ze starszymi wersjami OpenEE.
func _zastosuj() -> void:
	var p := aktualny()
	if tylko_pamiec:
		if stosuj_w_pamieci:       # testy przełączania gry: silnik zmieniany w pamięci, nic nie jest zapisywane
			K.gra = gra_id
			K.zrodlo_gry = String(p.get("zrodlo", K.zrodlo_gry))
			K.instalacja_ee = K.instalacje.get(K.zrodlo_gry, "")
			K.aktywne_warstwy = PackedStringArray(_warstwy_profilu(p))
			if Z and Z.has_method("przebuduj_zrodla"):
				Z.przebuduj_zrodla()
		return
	_zapisz({"launcher/profil": profil_id, "zrodlo/gra": p.get("zrodlo", "referencyjna"), "gra/wariant": gra_id,
		"zrodlo/profil": gra_id, "warstwy/aktywne": _warstwy_profilu(p)})
	if Z and Z.has_method("przebuduj_zrodla"):
		Z.przebuduj_zrodla()


# ---------------------------------------------------------------- gra (Empire Earth / The Art of Conquest)

func gry() -> Array:
	return GryEE.WSZYSTKIE


func nazwa_gry(id: String) -> String:
	return GryEE.nazwa(id, katalog)


## Czy gra jest w instalacji bazowej bieżącego profilu.
func gra_dostepna(id: String) -> bool:
	return GryEE.dostepna(id, K.instalacje.get(String(aktualny().get("zrodlo", K.zrodlo_gry)), ""), katalog)


func wybierz_gre(id: String) -> bool:
	if not GryEE.poprawna(id):
		return false
	gra_id = id
	_zastosuj()
	zmieniono.emit("gra")
	return true


## Kampanie wybranej gry (z jej katalogu Data/Campaigns).
func kampanie() -> Array:
	return GryEE.kampanie(gra_id, K.instalacje.get(String(aktualny().get("zrodlo", K.zrodlo_gry)), ""), katalog)


func nowy_profil(nazwa: String) -> String:
	var id := "uzytkownik_%d" % Time.get_unix_time_from_system()
	while not profil(id).is_empty():
		id += "_"
	profile.append({"id": id, "nazwa": nazwa, "opis": "", "zrodlo": "referencyjna", "mody": [], "wbudowany": false})
	_zapisz_profile_uzytkownika()
	wybierz_profil(id)
	return id


func klonuj_profil(nazwa: String) -> String:
	var p := aktualny().duplicate(true)
	var id := "uzytkownik_%d" % Time.get_unix_time_from_system()
	while not profil(id).is_empty():
		id += "_"
	p.id = id; p.nazwa = nazwa; p.wbudowany = false
	profile.append(p)
	_zapisz_profile_uzytkownika()
	wybierz_profil(id)
	return id


func usun_profil(id: String) -> bool:
	var p := profil(id)
	if p.is_empty() or p.get("wbudowany", false):
		return false
	profile.erase(p)
	_zapisz_profile_uzytkownika()
	if profil_id == id:
		wybierz_profil("vanilla")
	zmieniono.emit("profile")
	return true


func zmien_nazwe_profilu(id: String, nazwa: String) -> bool:
	var p := profil(id)
	if p.is_empty() or p.get("wbudowany", false) or nazwa.strip_edges() == "":
		return false
	p.nazwa = nazwa.strip_edges()
	_zapisz_profile_uzytkownika()
	zmieniono.emit("profile")
	return true


func ustaw_pole_profilu(pole: String, wartosc: Variant) -> bool:
	var p := aktualny()
	if p.is_empty() or p.get("wbudowany", false):
		return false
	p[pole] = wartosc
	_zapisz_profile_uzytkownika()
	_zastosuj()
	zmieniono.emit("profil")
	return true


# ---------------------------------------------------------------- mody (obecnie: nakładki warstw)

func _wczytaj_mody() -> void:
	dostepne_mody.clear()
	var d: Variant = _json("dane/warstwy.json")
	for w in (d.get("warstwy", []) if d is Dictionary else []):
		var id := String(w.get("id", ""))
		if w.get("nakladka", false):
			dostepne_mody.append({"id": id, "nazwa": w.get("nazwa", id), "opis": w.get("uwagi", ""),
				"zrodlo": w.get("zrodlo", ""), "typ": "nakladka", "dostepny": K.instalacje.has(String(w.get("zrodlo", "")))})
		elif id in ["neoee", "drexmod"]:
			dostepne_mody.append({"id": id, "nazwa": w.get("nazwa", id), "opis": w.get("uwagi", ""),
				"zrodlo": "spolecznosciowa", "typ": "informacyjny", "dostepny": false})
	# mody użytkownika: <OpenEE>/mody/<nazwa>/mod.json (przyszły format – na razie tylko wykrywanie)
	var km := katalog.path_join("mody")
	if DirAccess.dir_exists_absolute(km):
		for n in DirAccess.get_directories_at(km):
			var m: Variant = _json("mody/%s/mod.json" % n)
			if m is Dictionary:
				dostepne_mody.append({"id": "mod:" + n, "nazwa": m.get("nazwa", n), "opis": m.get("opis", ""),
					"zrodlo": "mody/" + n, "typ": "uzytkownika", "dostepny": false})


func mod(id: String) -> Dictionary:
	for m in dostepne_mody:
		if m.id == id:
			return m
	return {}


func aktywne_mody() -> Array:
	return aktualny().get("mody", [])


## Mody, które można dodać do bieżącego profilu.
func mody_do_dodania() -> Array:
	var wynik := []
	for m in dostepne_mody:
		if m.typ == "nakladka" and m.dostepny and not m.id in aktywne_mody():
			wynik.append(m)
	return wynik


## Profil wbudowany jest niezmienny – modyfikacja listy modów tworzy automatycznie kopię profilu.
func _profil_edytowalny(nazwa_kopii: String) -> Dictionary:
	if aktualny().get("wbudowany", false):
		klonuj_profil(nazwa_kopii)
	return aktualny()


func dodaj_mod(id: String, nazwa_kopii: String) -> bool:
	var m := mod(id)
	if m.is_empty() or m.typ != "nakladka":
		return false
	var p := _profil_edytowalny(nazwa_kopii)
	var lista: Array = p.get("mody", []).duplicate()
	if not id in lista:
		lista.append(id)
	return ustaw_pole_profilu("mody", lista)


func usun_mod(id: String, nazwa_kopii: String) -> bool:
	var p := _profil_edytowalny(nazwa_kopii)
	var lista: Array = p.get("mody", []).duplicate()
	lista.erase(id)
	var w: Array = p.get("wylaczone", []).duplicate()
	w.erase(id)
	p["wylaczone"] = w
	return ustaw_pole_profilu("mody", lista)


func mod_wlaczony(id: String) -> bool:
	return id in aktywne_mody() and not id in aktualny().get("wylaczone", [])


func liczba_wlaczonych_modow() -> int:
	var n := 0
	for m in aktywne_mody():
		if mod_wlaczony(m):
			n += 1
	return n


func przelacz_mod(id: String, nazwa_kopii: String) -> bool:
	var p := _profil_edytowalny(nazwa_kopii)
	var w: Array = p.get("wylaczone", []).duplicate()
	if id in w: w.erase(id)
	else: w.append(id)
	return ustaw_pole_profilu("wylaczone", w)


func przesun_mod(id: String, o: int, nazwa_kopii: String) -> bool:
	var p := _profil_edytowalny(nazwa_kopii)
	var lista: Array = p.get("mody", []).duplicate()
	var i := lista.find(id)
	var j := i + o
	if i < 0 or j < 0 or j >= lista.size():
		return false
	lista[i] = lista[j]; lista[j] = id
	return ustaw_pole_profilu("mody", lista)


# ---------------------------------------------------------------- język gry (dane), język UI, inne

func jezyk_gry() -> String:
	var t: String = K.jezyk_tekstow; var g: String = K.jezyk_glosow; var k: String = K.jezyk_kampanii
	if t == "pl" and g == "pl" and k == "pl": return "pl"
	if t == "en" and g == "en" and k == "en": return "en"
	if t == "pl" and g == "en" and k == "pl": return "pl_en"
	return "wlasny"


func ustaw_jezyk_gry(kod: String) -> void:
	var m := {"pl": ["pl", "pl", "pl"], "en": ["en", "en", "en"], "pl_en": ["pl", "en", "pl"]}
	if not m.has(kod):
		return
	if tylko_pamiec:
		K.jezyk_tekstow = m[kod][0]; K.jezyk_glosow = m[kod][1]; K.jezyk_kampanii = m[kod][2]
	else:
		_zapisz({"lokalizacja/jezyk_tekstow": m[kod][0], "lokalizacja/jezyk_glosow": m[kod][1],
			"lokalizacja/jezyk_kampanii": m[kod][2]})
		if Z and Z.has_method("przebuduj_zrodla"):
			Z.przebuduj_zrodla()
	zmieniono.emit("jezyk_gry")


## Czy polska wersja danych jest dostępna (instalacja z PL skonfigurowana i znaleziona).
func pl_dostepny() -> bool:
	return K.instalacje.has(K.zrodlo_pl) and FileAccess.file_exists(katalog.path_join("dane/lokalizacja/pl/manifest.json"))


func ustaw_jezyk_ui(kod: String) -> void:
	jezyk_ui = kod
	_zapisz({"launcher/jezyk_ui": kod})
	zmieniono.emit("jezyk_ui")


func ustaw_uzyj_openee(v: bool) -> void:
	uzyj_openee = v
	_zapisz({"launcher/uzyj_openee": v})
	zmieniono.emit("uzyj_openee")


func ustaw_skale_ui(v: float) -> void:
	skala_ui = clampf(v, 0.7, 1.4)
	_zapisz({"launcher/skala_ui": skala_ui})
	zmieniono.emit("skala_ui")


## Zmiana ścieżki instalacji (zapis w uzytkownik.cfg, lista doklejana przed ścieżkami z openee.cfg).
func ustaw_sciezke_instalacji(nazwa: String, sciezka: String) -> Dictionary:
	var spr: Dictionary = K.czy_instalacja_ee(sciezka)
	if not spr.ok:
		return spr
	if not tylko_pamiec:
		_zapisz({"instalacje/" + nazwa: [spr.sciezka]})
		if Z and Z.has_method("przebuduj_zrodla"):
			Z.przebuduj_zrodla()
	zmieniono.emit("instalacja")
	return spr


## Informacje do karty instalacji.
func info_instalacji() -> Dictionary:
	var src: String = K.zrodlo_gry
	var p: String = K.instalacje.get(src, "")
	var spr: Dictionary = K.czy_instalacja_ee(p) if p != "" else {"ok": false, "aoc": false, "gog": false, "sciezka": ""}
	spr["zrodlo"] = src
	return spr


func info_silnika() -> Dictionary:
	var v := Engine.get_version_info()
	var metoda := RenderingServer.get_current_rendering_method()
	var opis_metody := {"gl_compatibility": "OpenGL", "forward_plus": "Vulkan", "mobile": "Vulkan Mobile"}
	var karta := RenderingServer.get_video_adapter_name()
	return {"wersja": WERSJA, "godot": "%d.%d.%d" % [v.major, v.minor, v.patch],
		"renderer": "Godot %d.%d (%s)" % [v.major, v.minor, opis_metody.get(metoda, metoda if metoda != "" else "headless")],
		"karta": karta, "platforma": "%s (%s)" % [OS.get_name(), Engine.get_architecture_name()],
		"gotowy": info_instalacji().ok and (Z == null or bool(Z.get("gotowe")))}


func aktualnosci() -> Array:
	var d: Variant = _json("dane/launcher/aktualnosci.json")
	return d.get("wpisy", []) if d is Dictionary else []
