extends Node
## System zasobów OpenEE (etap 2): instalacja bazowa + nakładki (lokalizacja, mody) niezależne od wyboru gry.
##
## Kolejność rozwiązywania klucza (np. "sounds/kv1wherego.wav", "textures/basegrass_1_1.sst"):
##   1. nakładka localization/<język> – tylko klucze wymienione w dane/lokalizacja/<język>/manifest.json
##      (głosy: jezyk_glosow, grafika z tekstem: jezyk_tekstow); dane czytane z instalacji `zrodlo_pl`,
##   2. nakładka hd_nieustalone – luźne pliki instalacji społecznościowej z dowodem D-OVR (jeśli warstwa aktywna),
##   3. instalacja bazowa – katalogi danych WYBRANEJ GRY (dane/gry.json, GryEE): Empire Earth – tylko „Empire Earth”;
##      The Art of Conquest – „Empire Earth - The Art of Conquest”, potem „Empire Earth” (jawne współdzielenie zmierzone
##      na oryginale: EE-AOC.exe otwiera oba archiwa data.ssa, docs/WARIANTY_GRY.md). Tryb EE nigdy nie czyta plików AoC.
## Pamięć podręczna (tabele db, obrazy) jest kluczowana grą, instalacją, warstwami i językami (`klucz_zrodel`) –
## zmiana gry lub profilu czyści ją w całości.
## Warstwa każdego pliku bazowego pochodzi z manifestu tej instalacji (manifest_referencyjny.json dla GOG,
## manifest_zasobow.json dla społecznościowej). Nakładki nie wymagają włączania NeoEE ani dreXmoda.
## Ograniczenie: gdy bazą jest instalacja społecznościowa, polskie głosy są wbudowane w jej data.ssa – wybór
## jezyk_glosow="en" wymaga instalacji referencyjnej (inaczej zostaje PL i trafia ostrzeżenie do dziennika).

const EE := "Empire Earth"
const AOC := "Empire Earth - The Art of Conquest"

var definicje_warstw: Array = []
var _warstwa_bazy := {}           # ścieżka względna (małe litery) -> warstwa, dla instalacji bazowej
var _hd := {}                     # klucz (np. textures/x.sst) -> pełna ścieżka luźnego pliku społecznościowego
var _lok := {}                    # klucz -> {"archiwum": rel, "rodzaj": "glos"/"grafika"}
var _lok_kampanie := {}           # kampania -> {"brak_pl": [klucze]}
var _spolszczone := {}            # klucz -> archiwum: wpisy, które w instalacji społecznościowej są polskie
var _zrodla: Array = []
var _archiwa := {}                # (instalacja|rel) -> ArchiwumSSA
var _importery := {}
var _cache_obrazow := {}
var _tabele := {}
var klucz_zrodel := ""           # gra|instalacja|warstwy|języki, dla których zbudowano źródła i pamięć podręczną
var gotowe := false
var statystyka := {"localization": 0, "hd_nieustalone": 0, "baza": 0, "brak": 0}


func _ready() -> void:
	zarejestruj_importer(ImporterTekstur.new())
	zarejestruj_importer(ImporterModeli.new())
	zarejestruj_importer(ImporterDzwiekow.new())
	_wczytaj_definicje()
	przebuduj_zrodla()


func zarejestruj_importer(imp: ImporterEE) -> void:
	for r in imp.rozszerzenia():
		_importery[r] = imp


func _json(rel: String) -> Variant:
	var p := Konfiguracja.katalog_openee.path_join(rel)
	if not FileAccess.file_exists(p):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(p))


func _wczytaj_definicje() -> void:
	var j = _json("dane/warstwy.json")
	definicje_warstw = j.get("warstwy", []) if j else []


func archiwum(instalacja: String, rel: String) -> ArchiwumSSA:
	var k := instalacja + "|" + rel
	if not _archiwa.has(k):
		var a := ArchiwumSSA.new()
		var sciezka: String = Konfiguracja.instalacje.get(instalacja, "")
		if sciezka == "" or a.otworz(sciezka.path_join(rel)) != OK:
			_archiwa[k] = null
		else:
			_archiwa[k] = a
	return _archiwa[k]


func warstwa_aktywna(w: String) -> bool:
	if w.begins_with("mieszane:"):
		for cz in w.trim_prefix("mieszane:").split("+"):
			if cz in ["vanilla", "aoc"] and cz in Konfiguracja.aktywne_warstwy:
				return true
		return false
	return w in Konfiguracja.aktywne_warstwy


func przebuduj_zrodla() -> void:
	# etap 11: tabele db zależą od profilu (EE 1.0 / AoC) – po zmianie źródeł czytane od nowa
	_tabele.clear(); warianty_tabel.clear()
	klucz_zrodel = _klucz()
	_zrodla.clear(); _cache_obrazow.clear(); _cache_tekstur_wielu.clear(); _cache_cem.clear(); _warstwa_bazy.clear(); _hd.clear(); _lok.clear(); _lok_kampanie.clear(); _spolszczone.clear()
	var baza := Konfiguracja.zrodlo_gry
	if Konfiguracja.instalacja_ee == "":
		gotowe = false
		return
	# manifest instalacji bazowej
	var man = _json("audyt/manifest_referencyjny.json" if baza == "referencyjna" else "audyt/manifest_zasobow.json")
	if man:
		for e in man.pliki:
			_warstwa_bazy[String(e.sciezka).to_lower()] = e.warstwa
	else:
		# brak manifestu (np. świeża kopia z GitHuba): archiwa data.ssa = warstwy bazowe gry (EE → vanilla, AoC → aoc),
		# luźne pliki w Data/ – „nieustalone” (nieaktywne), bo mogą to być nadpisania modów/HD.
		Dziennik.uwaga("zasoby", "Brak manifestu instalacji '%s' – archiwa data.ssa = vanilla/aoc, luźne pliki pominięte" % baza)
	var gry := GryEE.katalogi_danych(Konfiguracja.gra, Konfiguracja.katalog_openee)
	if gry.is_empty():
		Dziennik.blad("zasoby", "Brak definicji gry '%s' (dane/gry.json)" % Konfiguracja.gra)
	for g in gry:
		_zrodla.append({"typ": "luzne", "instalacja": baza, "katalog": g + "/Data"})
		var rel: String = g + "/Data/data.ssa"
		var a := archiwum(baza, rel)
		if a == null:
			Dziennik.blad("zasoby", "Nie można otworzyć %s w instalacji '%s'" % [rel, baza])
			continue
		var domyslna := "nieustalone" if man else ("aoc" if g == AOC else "vanilla")
		_zrodla.append({"typ": "archiwum", "instalacja": baza, "rel": rel, "warstwa": _warstwa_bazy.get(rel.to_lower(), domyslna)})
	# nakładka HD (luźne nadpisania instalacji społecznościowej)
	if "hd_nieustalone" in Konfiguracja.aktywne_warstwy and Konfiguracja.instalacje.has("spolecznosciowa"):
		var ms = _json("audyt/manifest_zasobow.json")
		var korzen: String = Konfiguracja.instalacje["spolecznosciowa"]
		if ms:
			for e in ms.pliki:
				if e.warstwa == "hd_nieustalone":
					var s: String = e.sciezka
					for g in gry:
						if s.begins_with(g + "/Data/"):
							var klucz := s.trim_prefix(g + "/Data/").to_lower()
							if not _hd.has(klucz):
								_hd[klucz] = korzen.path_join(s)
	# klucze spolszczone w archiwach społecznościowych (potrzebne, gdy baza = społecznościowa, a język = en)
	var mpl = _json("dane/lokalizacja/pl/manifest.json")
	if mpl:
		for g in mpl.glosy:
			_spolszczone[String(g.klucz)] = g.archiwum
	# nakładka lokalizacji
	var jezyki := []
	if Konfiguracja.jezyk_glosow != "en": jezyki.append(Konfiguracja.jezyk_glosow)
	if Konfiguracja.jezyk_tekstow != "en" and not Konfiguracja.jezyk_tekstow in jezyki: jezyki.append(Konfiguracja.jezyk_tekstow)
	for jz in jezyki:
		var ml = _json("dane/lokalizacja/%s/manifest.json" % jz)
		if ml == null:
			Dziennik.uwaga("zasoby", "Brak manifestu lokalizacji '%s'" % jz)
			continue
		if not Konfiguracja.instalacje.has(Konfiguracja.zrodlo_pl):
			Dziennik.uwaga("zasoby", "Brak instalacji z lokalizacją '%s' (%s)" % [jz, Konfiguracja.zrodlo_pl])
			continue
		if Konfiguracja.jezyk_glosow == jz:
			for g in ml.glosy:
				_lok[String(g.klucz)] = {"archiwum": g.archiwum, "rodzaj": "glos", "sha256": g.sha256_pl}
		if Konfiguracja.jezyk_tekstow == jz:
			for g in ml.grafika_z_tekstem:
				if String(g.archiwum).ends_with("Data/data.ssa"):
					_lok[String(g.klucz)] = {"archiwum": g.archiwum, "rodzaj": "grafika"}
		for b in ml.narracja_brak_pl:
			if not _lok_kampanie.has(b.kampania): _lok_kampanie[b.kampania] = []
			_lok_kampanie[b.kampania].append(b.klucz)
	gotowe = true
	Dziennik.info("zasoby", "Źródła: baza '%s' (%d), nakładka lokalizacji: %d kluczy, nakładka HD: %d plików" % [
		baza, _zrodla.size(), _lok.size(), _hd.size()])


## Zwraca {"dane", "zrodlo", "warstwa"} lub {}.
func znajdz(klucz: String) -> Dictionary:
	var k := klucz.replace("\\", "/").to_lower()
	if _lok.has(k):
		var l: Dictionary = _lok[k]
		var a := archiwum(Konfiguracja.zrodlo_pl, l.archiwum)
		if a and a.zawiera(k):
			statystyka.localization += 1
			return {"dane": a.czytaj(k), "zrodlo": "%s:%s:%s" % [Konfiguracja.zrodlo_pl, l.archiwum, k],
				"warstwa": "localization/%s" % (Konfiguracja.jezyk_glosow if l.rodzaj == "glos" else Konfiguracja.jezyk_tekstow)}
	if Konfiguracja.zrodlo_gry != "referencyjna" and Konfiguracja.jezyk_glosow == "en" and _spolszczone.has(k):
		var ar: ArchiwumSSA = null
		if Konfiguracja.instalacje.has("referencyjna"):
			ar = archiwum("referencyjna", _spolszczone[k])
		if ar and ar.zawiera(k):
			return {"dane": ar.czytaj(k), "zrodlo": "referencyjna:%s:%s" % [_spolszczone[k], k], "warstwa": "vanilla/aoc (en)"}
		Dziennik.uwaga("zasoby", "%s: w instalacji bazowej tylko wersja PL (brak instalacji referencyjnej)" % k)
	if _hd.has(k):
		statystyka.hd_nieustalone += 1
		return {"dane": DCL.moze_rozpakuj(FileAccess.get_file_as_bytes(_hd[k])), "zrodlo": _hd[k], "warstwa": "hd_nieustalone"}
	for z in _zrodla:
		if z.typ == "luzne":
			var korzen: String = Konfiguracja.instalacje[z.instalacja]
			var p := _plik_bez_wielkosci_liter(korzen, z.katalog + "/" + k)
			if p != "":
				var w: String = _warstwa_bazy.get(p.trim_prefix(korzen + "/").to_lower(), "nieustalone")
				if warstwa_aktywna(w):
					statystyka.baza += 1
					return {"dane": DCL.moze_rozpakuj(FileAccess.get_file_as_bytes(p)), "zrodlo": p, "warstwa": w}
		else:
			var a := archiwum(z.instalacja, z.rel)
			if a and a.zawiera(k) and warstwa_aktywna(z.warstwa):
				statystyka.baza += 1
				return {"dane": a.czytaj(k), "zrodlo": "%s:%s:%s" % [z.instalacja, z.rel, k], "warstwa": z.warstwa}
	statystyka.brak += 1
	return {}


func _plik_bez_wielkosci_liter(baza: String, rel: String) -> String:
	var cur := baza
	for czesc in rel.split("/"):
		var d := DirAccess.open(cur)
		if d == null:
			return ""
		var znal := ""
		for n in d.get_files() + d.get_directories():
			if n.to_lower() == czesc.to_lower():
				znal = n
				break
		if znal == "":
			return ""
		cur = cur.path_join(znal)
	return cur if FileAccess.file_exists(cur) else ""


func wczytaj_teksture(klucz: String) -> Image:
	if _cache_obrazow.has(klucz):
		return _cache_obrazow[klucz]
	var baza := klucz
	if not (klucz.ends_with(".sst") or klucz.ends_with(".tga")):
		baza = klucz + ".sst"          # dbgraphics zapisuje część ścieżek bez rozszerzenia
	var r := znajdz(baza)
	if r.is_empty() and baza.ends_with(".sst"):
		r = znajdz(baza.trim_suffix(".sst") + ".tga")
	if r.is_empty():
		Dziennik.debug("zasoby", "Brak tekstury %s" % klucz)
		_cache_obrazow[klucz] = null
		return null
	var img: Image = _importery["sst"].importuj(r.dane, {"klucz": klucz})
	_cache_obrazow[klucz] = img
	return img


var _cache_tekstur_wielu := {}

## Wszystkie obrazy pliku tekstury (SST może zawierać N obrazów: animacja wody albo – w teksturach modeli – obrazy
## wybierane polem `tekstura_id` materiału CEM [D, naprawa grafiki]). Pusta tablica, gdy brak pliku.
func wczytaj_tekstury(klucz: String) -> Array:
	if _cache_tekstur_wielu.has(klucz):
		return _cache_tekstur_wielu[klucz]
	var baza := klucz
	if not (klucz.ends_with(".sst") or klucz.ends_with(".tga")):
		baza = klucz + ".sst"
	var r := znajdz(baza)
	if r.is_empty() and baza.ends_with(".sst"):
		r = znajdz(baza.trim_suffix(".sst") + ".tga")
	var out: Array = []
	if not r.is_empty():
		var d := ImporterTekstur.dekoduj(r.dane)
		if d.has("blad"):
			Dziennik.blad("zasoby", "Tekstura %s: %s" % [klucz, d.blad])
		else:
			out = d.obrazy
	_cache_tekstur_wielu[klucz] = out
	return out


func wczytaj_model(klucz: String, kontekst: Dictionary = {}) -> Mesh:
	var r := znajdz(klucz)
	if r.is_empty():
		Dziennik.uwaga("zasoby", "Brak modelu %s" % klucz)
		return null
	var k := kontekst.duplicate()
	k["klucz"] = klucz; k["zasoby"] = self
	return _importery["cem"].importuj(r.dane, k)


var _cache_cem := {}

## Pełny model CEM (klatki + hierarchia, etap 4) – współdzielony, w pamięci podręcznej; null gdy brak/błąd.
func wczytaj_model_cem(klucz: String) -> ModelCEM:
	if _cache_cem.has(klucz):
		return _cache_cem[klucz]
	var r := znajdz(klucz)
	var m: ModelCEM = null
	if r.is_empty():
		Dziennik.uwaga("zasoby", "Brak modelu %s" % klucz)
	else:
		m = ModelCEM.z_danych(r.dane)
		if m.blad != "":
			Dziennik.blad("zasoby", "%s: %s" % [klucz, m.blad]); m = null
	_cache_cem[klucz] = m
	return m


## Animacja wypieczona do tekstury (AnimacjaVAT) dla modelu + tekstury dbgraphics; null gdy brak modelu.
func wczytaj_animacje(klucz: String, kontekst: Dictionary = {}) -> AnimacjaVAT:
	var m := wczytaj_model_cem(klucz)
	if m == null:
		return null
	var k := kontekst.duplicate()
	k["klucz"] = klucz; k["zasoby"] = self
	return AnimacjaVAT.wypiecz(m, k)


## Dźwięk wg klucza; zwraca {"strumien": AudioStream, "zrodlo", "warstwa", "dane"} lub {}.
func wczytaj_dzwiek(klucz: String) -> Dictionary:
	var r := znajdz(klucz)
	if r.is_empty():
		return {}
	r["strumien"] = _importery["wav" if klucz.ends_with(".wav") else "mp3"].importuj(r.dane, {"klucz": klucz})
	return r


## Archiwum kampanii w języku kampanii (PL: z instalacji zrodlo_pl), z odwołaniem do EN dla braków.
## Kampania musi należeć do wybranej gry (GryEE.archiwum_kampanii); w AoC kampanie EE są dostępne jawnie (uwaga w dzienniku).
func plik_kampanii(kampania: String, klucz: String) -> Dictionary:
	var ak := GryEE.archiwum_kampanii(Konfiguracja.gra, kampania, Konfiguracja.instalacja_ee, Konfiguracja.katalog_openee)
	if ak.has("blad"):
		Dziennik.blad("zasoby", ak.blad)
		return {}
	if not ak.wlasna:
		Dziennik.uwaga("zasoby", "Kampania %s spoza katalogu gry %s – jawne współdzielenie (%s)" % [kampania, Konfiguracja.gra, ak.rel])
	var rel_g: String = ak.rel
	var k := klucz.to_lower()
	if Konfiguracja.jezyk_kampanii != "en" and Konfiguracja.instalacje.has(Konfiguracja.zrodlo_pl):
		var a := archiwum(Konfiguracja.zrodlo_pl, rel_g)
		if a and a.zawiera(k):
			return {"dane": a.czytaj(k), "jezyk": Konfiguracja.jezyk_kampanii, "zastepstwo": false}
	var ref := "referencyjna" if Konfiguracja.instalacje.has("referencyjna") else Konfiguracja.zrodlo_gry
	var b := archiwum(ref, rel_g)
	if b and b.zawiera(k):
		var zast := Konfiguracja.jezyk_kampanii != "en"
		if zast:
			Dziennik.uwaga("zasoby", "Brak %s w wersji '%s' kampanii %s – użyto EN" % [k, Konfiguracja.jezyk_kampanii, kampania])
		return {"dane": b.czytaj(k), "jezyk": "en", "zastepstwo": zast}
	return {}


## Napisy Language.dll w języku tekstów (id → tekst).
## Domyślnie Language.dll WYBRANEJ gry (każda gra ma własną: EE 3398 napisów, AoC 3707 – audyt etapu 11).
func teksty(gra: String = "") -> Dictionary:
	if gra == "":
		gra = GryEE.katalog_language_dll(Konfiguracja.gra, Konfiguracja.katalog_openee)
	var inst := Konfiguracja.zrodlo_pl if Konfiguracja.jezyk_tekstow != "en" else ("referencyjna" if Konfiguracja.instalacje.has("referencyjna") else Konfiguracja.zrodlo_gry)
	var p: String = Konfiguracja.instalacje.get(inst, "")
	return TekstyDLL.wczytaj(p.path_join(gra).path_join("Language.dll")) if p != "" else {}


## Wariant formatu wczytanych tabel (etap 11): nazwa → "aoc" | "ee" | "wspolny" | "blad".
var warianty_tabel := {}


## Tabela db (z archiwum bazowego profilu), np. "dbobjects" → Array[Dictionary].
func tabela(nazwa: String) -> Array:
	if klucz_zrodel != _klucz():
		# konfiguracja zmieniona bez przebuduj_zrodla() – nie wolno oddać tabel poprzedniej gry/instalacji
		Dziennik.uwaga("zasoby", "Zmiana źródeł (%s → %s) – przebudowa" % [klucz_zrodel, _klucz()])
		przebuduj_zrodla()
	if _tabele.has(nazwa):
		return _tabele[nazwa]
	var r := znajdz("db/%s.dat" % nazwa)
	var w: Dictionary = BazaDB.dekoduj(r.dane, nazwa, Konfiguracja.katalog_openee) if not r.is_empty() else {"blad": "brak"}
	if w.has("blad"):
		Dziennik.blad("zasoby", "Tabela %s (%s): %s" % [nazwa, r.get("zrodlo", "?"), w.blad])
		_tabele[nazwa] = []
		warianty_tabel[nazwa] = "blad"
	else:
		_tabele[nazwa] = w.rekordy
		warianty_tabel[nazwa] = w.wariant
		# etap 11: wariant formatu zgodny z profilem (aoc – archiwum AoC ma pierwszeństwo, ee – tylko archiwum EE)
		var oczek := GryEE.format_db(Konfiguracja.gra, Konfiguracja.katalog_openee)
		if w.wariant != "wspolny" and w.wariant != oczek:
			Dziennik.blad("zasoby", "Tabela %s: format '%s' niezgodny z grą '%s' (%s)" % [
				nazwa, w.wariant, Konfiguracja.gra, r.get("zrodlo", "?")])
	return _tabele[nazwa]


func opis_zrodel() -> Array[String]:
	var out: Array[String] = []
	for z in _zrodla:
		if z.typ == "archiwum":
			var a := archiwum(z.instalacja, z.rel)
			out.append("%s: %s – %d wpisów – warstwa %s%s" % [z.instalacja, z.rel, a.wpisy.size() if a else 0, z.warstwa,
				"" if warstwa_aktywna(z.warstwa) else " [nieaktywna]"])
		else:
			out.append("%s: luźne %s" % [z.instalacja, z.katalog])
	out.append("nakładka localization: %d kluczy (głosy: %s, teksty: %s, kampanie: %s)" % [_lok.size(),
		Konfiguracja.jezyk_glosow, Konfiguracja.jezyk_tekstow, Konfiguracja.jezyk_kampanii])
	out.append("nakładka hd_nieustalone: %d plików" % _hd.size())
	return out


func _klucz() -> String:
	return "%s|%s|%s|%s|%s" % [Konfiguracja.gra, Konfiguracja.zrodlo_gry, ",".join(Konfiguracja.aktywne_warstwy),
		Konfiguracja.jezyk_tekstow, Konfiguracja.jezyk_glosow]


## Kampanie wybranej gry (archiwa z jej katalogu Data/Campaigns) – lista menu kampanii.
func kampanie() -> Array:
	return GryEE.kampanie(Konfiguracja.gra, Konfiguracja.instalacja_ee, Konfiguracja.katalog_openee)
