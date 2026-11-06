extends SceneTree
## Testy OpenEE (bez okna):  godot --headless --path godot --script res://testy/uruchom_testy.gd
## Etap 1 (zachowane): SSA/DCL/CEM/SST zgodne z Pythonem, warstwy, zdarzenia.
## Etap 2: instalacje, tabele db, scenariusz (teren + obiekty), CEM 1.3, teksty Language.dll, lokalizacja audio.
## Etap 3: mieszanie tekstur terenu, warianty, woda, klify, scenariusze EE (wersja 231), orientacja obiektów.
## Etap 4: animacje CEM (klatki, sekwencje dbgraphics, interpolacja), hierarchia części, odtwarzanie (testy/testy_etapu4.gd).
## Etap 5: nawigacja, symulacja jednostek, zaznaczanie, stały krok (testy/testy_etapu5.gd).
## Naprawa grafiki: indeksy materiałów (v_offset), obrazy SST (tekstura_id), kolor gracza, UV (testy/testy_grafiki.gd).
## Diagnostyka 0.5.1: współpłaszczyznowe/duplikaty, nawinięcie, wycinanie alfa, odrzucanie ścian, billboard (testy/testy_diagnostyki.gd).
## Układ współrzędnych (etap 7): UkladEE, skrętność, punkty kontrolne EE, wskazywanie, Windows-1250 (testy/testy_ukladu.gd).
## Ruch grupowy EE (etap 9): zaznaczanie, szyk, trasy oktylowe, kolejka, przesmyk, kolizje (testy/testy_ruchu.gd).
## Kamera RTS: model kamery EE, kamera produkcyjna bez obrotu, kamera diagnostyczna (testy/testy_kamery.gd).
## Etap 12: pomiary mechanik EE i AoC a wspólny kod kamery i ruchu (testy/testy_etapu12.gd).
## Launcher: teksty UI PL/EN, model profili/modów/języka (w pamięci, bez zapisu), ikony, budowa sceny launchera.

var wyniki: Array = []
var bledy := 0
var pominiete := 0


func _ok(nazwa: String, warunek: bool, szczegoly: Variant = "") -> void:
	wyniki.append({"test": nazwa, "ok": warunek, "szczegoly": str(szczegoly).left(400)})
	if not warunek:
		bledy += 1
	print(("OK    " if warunek else "BŁĄD  ") + nazwa + ("" if str(szczegoly) == "" else "  – " + str(szczegoly).left(300)))


func _sha(b: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(b)
	return h.finish().hex_encode()


func _json(K, rel: String) -> Variant:
	var p: String = K.katalog_openee.path_join(rel)
	return JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else null


## Pominięcie testów wymagających danych komercyjnych (instalacja EE, pliki z narzedzia/przygotuj_dane_lokalne.sh).
## Pominięty test nie jest błędem – liczy się osobno („pominiete” w wyniki/testy_godot.json).
func _pomin(nazwy: Array, powod: String) -> void:
	for n in nazwy:
		wyniki.append({"test": n, "ok": null, "pominiety": powod})
		pominiete += 1
		print("POMIŃ " + n + "  – " + powod)


func _initialize() -> void:
	await process_frame
	var K = root.get_node("Konfiguracja")
	var Z = root.get_node("Zasoby")
	var Zd = root.get_node("Zdarzenia")
	var ref: String = K.instalacje.get("referencyjna", "")
	var spol: String = K.instalacje.get("spolecznosciowa", "")
	if ref == "":
		_pomin(["konfiguracja: instalacja referencyjna"], "brak instalacji EE w konfiguracja/openee.cfg")
	else:
		_ok("konfiguracja: instalacja referencyjna", ref != "", ref)
	if spol == "":
		_pomin(["konfiguracja: instalacja społecznościowa"], "brak instalacji społecznościowej (opcjonalna)")
	else:
		_ok("konfiguracja: instalacja społecznościowa", spol != "", spol)
	if ref == "":
		_pomin(["konfiguracja: domyślna baza = referencyjna", "zasoby: źródła zbudowane"], "brak instalacji EE")
	else:
		_ok("konfiguracja: domyślna baza = referencyjna", K.zrodlo_gry == "referencyjna" and K.instalacja_ee == ref)
		_ok("zasoby: źródła zbudowane", Z.gotowe, Z.opis_zrodel())
	await _testy_etapu1(K, Z, Zd, spol)
	if ref == "":
		_pomin(["E2 db dbobjects (AoC, GDScript) = Python", "E2 db dbgraphics (AoC, GDScript) = Python", "E2 db dbsounds (AoC, GDScript) = Python",
			"E2 db dbterrain (AoC, GDScript) = Python", "E2 db dbcolortable (AoC, GDScript) = Python",
			"E2 CEM 1.3: modele zużyte co do bajta (GDScript)", "E2 CEM 1.3: grupa 'player color' wydzielona jako osobny materiał",
			"E2 SCN: kawałki i teren (GDScript)", "E2 SCN: gracze i obiekty = Python", "E2 SCN: kolor gracza 1 = (1,0,0)"], "brak instalacji EE")
	elif _json(K, "wyniki/test_db_referencyjna.json") == null or _json(K, "wyniki/test_cem13.json") == null or _json(K, "wyniki/test_gracze.json") == null:
		_pomin(["E2 db dbobjects (AoC, GDScript) = Python", "E2 db dbgraphics (AoC, GDScript) = Python", "E2 db dbsounds (AoC, GDScript) = Python",
			"E2 db dbterrain (AoC, GDScript) = Python", "E2 db dbcolortable (AoC, GDScript) = Python",
			"E2 CEM 1.3: modele zużyte co do bajta (GDScript)", "E2 CEM 1.3: grupa 'player color' wydzielona jako osobny materiał",
			"E2 SCN: kawałki i teren (GDScript)", "E2 SCN: gracze i obiekty = Python", "E2 SCN: kolor gracza 1 = (1,0,0)"], "brak wyników Pythona – uruchom narzedzia/przygotuj_dane_lokalne.sh")
	else:
		await _testy_etapu2_dane(K, Z)
	var nazwy_pl := ["E2 teksty PL: Language.dll AoC – liczba napisów = Python", "E2 teksty PL: nazwa falangi",
		"E2 audio: dbobjects→dbsounds (falanga, Selection sound 1)", "E2 audio: głos PL z nakładki localization/pl",
		"E2 audio: AudioStreamWAV z oryginalnych bajtów (bez przekodowania)", "E2 audio: odtwarzanie rozpoczęte (sterownik dummy)",
		"E2 audio: głosy EN + teksty PL (oddzielny wybór)", "E2 audio: narracja kampanii PL (AOCRoman roman1_1)",
		"E2 audio: brak nagrania PL → angielski odpowiednik", "E2 audio: MP3 narracji – długość > 0"]
	if ref == "" or spol == "":
		_pomin(nazwy_pl, "lokalizacja PL wymaga instalacji EE i instalacji z polską wersją")
	elif _json(K, "dane/lokalizacja/pl/manifest.json") == null:
		_pomin(nazwy_pl, "brak dane/lokalizacja/pl/manifest.json – uruchom narzedzia/przygotuj_dane_lokalne.sh")
	else:
		await _testy_lokalizacji(K, Z)
	if ref == "":
		_pomin(["E2 warstwy: baza GOG → tekstura z archiwum referencyjnego"], "brak instalacji EE")
	else:
		var bez: Dictionary = Z.znajdz("textures/basegrass_1_1.sst")
		_ok("E2 warstwy: baza GOG → tekstura z archiwum referencyjnego", String(bez.get("zrodlo", "")).begins_with("referencyjna:"), bez.get("zrodlo"))
	if ref == "" or spol == "" or _json(K, "audyt/manifest_zasobow.json") == null:
		_pomin(["E2 warstwy: nakładka hd_nieustalone z instalacji społecznościowej"],
			"wymaga obu instalacji i audyt/manifest_zasobow.json (pełny audyt warstw: narzedzia/klasyfikuj_warstwy_v2.py)")
	else:
		_testy_warstw(K, Z)
	await _testy_etapu3(K, Z)
	await TestyEtapu4.new(self).uruchom(K, Z)
	await TestyEtapu5.new(self).uruchom(K, Z)
	await TestyGrafiki.new(self).uruchom(K, Z)
	await TestyDiagnostyki.new(self).uruchom(K, Z)
	TestyKamery.new(self).uruchom()
	TestyUkladu.new(self).uruchom()
	await TestyWariantow.new(self).uruchom(K, Z)
	TestyGierEeAoc.new(self).uruchom(K, Z)
	TestyEtapu12.new(self).uruchom(K)
	TestyRuchuEE.new(self).uruchom()
	TestyPrzezroczystosci.new(self).uruchom()
	await _testy_launchera(K, Z)

	var out: String = K.katalog_openee.path_join("wyniki/testy_godot.json")
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var f := FileAccess.open(out, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"bledy": bledy, "pominiete": pominiete, "testy": wyniki, "godot": Engine.get_version_info().string}, "  "))
	print("WYNIK: %s (%d testów: %d zaliczonych, %d pominiętych, %d błędów) → %s" % ["ZALICZONE" if bledy == 0 else "NIEZALICZONE",
		wyniki.size(), wyniki.size() - pominiete - bledy, pominiete, bledy, out])
	quit(1 if bledy else 0)


func _testy_etapu1(K, Z, Zd, spol: String) -> void:
	# --- etap 1: archiwa społecznościowe vs manifest Pythona ---
	var man = _json(K, "audyt/manifest_archiwow.json")
	if man == null or spol == "":
		_pomin(["E1 SSA data.ssa: wpisy i SHA-256 (społecznościowa)", "E1 SSA data.ssa: wpisy i SHA-256 (społecznościowa)"], "wymaga instalacji społecznościowej i audyt/manifest_archiwow.json")
	else:
		for rel in man.keys():
			var a := ArchiwumSSA.new()
			a.otworz(spol.path_join(rel))
			var zg := 0; var spr := 0
			var lista: Array = man[rel].wpisy
			for i in range(0, lista.size(), 97):
				spr += 1
				if _sha(a.czytaj_surowe(String(lista[i].nazwa))) == lista[i].sha256_surowe: zg += 1
			_ok("E1 SSA %s: wpisy i SHA-256 (społecznościowa)" % rel.get_file(), a.wpisy.size() == int(man[rel].liczba_wpisow) and zg == spr, "%d wpisów, %d/%d" % [a.wpisy.size(), zg, spr])
	var eks = _json(K, "cache/test_graficzny/eksport.json")
	if eks == null or spol == "":
		_pomin(["E1 DCL+SSA: tekstury = Python (SHA-256)", "E1 DCL+SSA: model = Python (SHA-256)", "E1 CEM 2.0: parsowanie bld_barracks_05", "E1 SST: dekodowanie basegrass_1_1"], "wymaga instalacji społecznościowej i cache/test_graficzny (narzedzia/przygotuj_dane_lokalne.sh)")
	else:
		var aoc := ArchiwumSSA.new(); aoc.otworz(spol.path_join("Empire Earth - The Art of Conquest/Data/data.ssa"))
		var ee := ArchiwumSSA.new(); ee.otworz(spol.path_join("Empire Earth/Data/data.ssa"))
		var zg := 0; var n := 0
		var tex: Dictionary = eks.zrodla.get("tekstury", {})
		for k in tex.keys():
			var src: String = tex[k].get("archiwum", "ee:" + k)
			var arch := aoc if src.begins_with("aoc") else ee
			var kl: String = src.split(":", true, 1)[1] if ":" in src else k
			n += 1
			if _sha(arch.czytaj(kl)) == tex[k].sha256_rozpakowane: zg += 1
		_ok("E1 DCL+SSA: tekstury = Python (SHA-256)", zg == n and n > 0, "%d/%d" % [zg, n])
		var dm := ee.czytaj(String(eks.zrodla.model.wpis))
		_ok("E1 DCL+SSA: model = Python (SHA-256)", _sha(dm) == eks.zrodla.model.sha256_rozpakowane)
		var pm := ImporterModeli.parsuj(dm)
		_ok("E1 CEM 2.0: parsowanie bld_barracks_05", not pm.has("blad") and pm.get("reszta", -1) == 0, "%s wierzch." % pm.get("wierzcholki"))
		var r := ImporterTekstur.dekoduj(ee.czytaj("textures/basegrass_1_1.sst"))
		_ok("E1 SST: dekodowanie basegrass_1_1", r.has("obrazy") and r.obrazy[0].get_width() == 128)
	var log := []
	Zd.zarejestruj_symulacyjne("test", func(t, d): log.append([t, d]))
	Zd.kolejkuj_symulacyjne(2, "test", "b"); Zd.kolejkuj_symulacyjne(1, "test", "a"); Zd.kolejkuj_symulacyjne(2, "test", "c")
	Zd.przetworz_tick(2)
	_ok("E1 zdarzenia: kolejność (tick, sekwencja)", str(log) == str([[1, "a"], [2, "b"], [2, "c"]]))



func _testy_etapu2_dane(K, Z) -> void:
	# --- etap 2: tabele db (GDScript) vs Python ---
	var tdb = _json(K, "wyniki/test_db_referencyjna.json")
	for t in ["dbobjects", "dbgraphics", "dbsounds", "dbterrain", "dbcolortable"]:
		var rek: Array = Z.tabela(t)
		var oczek := int(tdb.get("Empire Earth - The Art of Conquest:" + t, {}).get("rekordy", -1)) if tdb else -1
		_ok("E2 db %s (AoC, GDScript) = Python" % t, rek.size() == oczek and oczek > 0, "%d vs %d" % [rek.size(), oczek])

	# --- CEM 1.3 ---
	var c13 = _json(K, "wyniki/test_cem13.json")
	var a_ee: ArchiwumSSA = Z.archiwum("referencyjna", "Empire Earth/Data/data.ssa")
	var ok13 := 0; var n13 := 0
	if c13:
		for k in c13.keys():
			n13 += 1
			var m := ImporterModeli.parsuj(a_ee.czytaj(k))
			if not m.has("blad") and m.get("reszta", -1) == 0 and m.wersja == "1.3": ok13 += 1
	_ok("E2 CEM 1.3: modele zużyte co do bajta (GDScript)", n13 == 11 and ok13 == 11, "%d/%d" % [ok13, n13])
	var pc := ImporterModeli.parsuj(a_ee.czytaj("models/men_priest_11.cem"))
	_ok("E2 CEM 1.3: grupa 'player color' wydzielona jako osobny materiał", pc.get("grupy", []).has("player color") and pc.materialy.size() >= 2, pc.get("grupy"))

	# --- scenariusz: teren + obiekty vs Python ---
	var tg = _json(K, "wyniki/test_gracze.json")
	var ak: ArchiwumSSA = Z.archiwum("referencyjna", "Empire Earth - The Art of Conquest/Data/Campaigns/AOCRoman.ssa")
	var t0 := Time.get_ticks_msec()
	var s := ScenariuszEE.new()
	var klucz := "scenarios/een1ve1s_soldiers for rome.scn"
	var ok_s := s.wczytaj(ak.czytaj(klucz)) and s.czytaj_teren()
	_ok("E2 SCN: kawałki i teren (GDScript)", ok_s and s.teren.A == 125 and s.teren.B == 125, s.blad)
	var t1 := Time.get_ticks_msec()
	var ok_g := s.czytaj_graczy(K.katalog_openee)
	var n_ob := 0
	for g in s.gracze: n_ob += g.jednostki.size()
	var oczek_ob := int(tg.get(klucz, {}).get("obiektow", -1)) if tg else -1
	_ok("E2 SCN: gracze i obiekty = Python (%d ms)" % (Time.get_ticks_msec() - t1), ok_g and n_ob == oczek_ob, "%d vs %d; %s" % [n_ob, oczek_ob, s.blad])
	if ok_g:
		_ok("E2 SCN: kolor gracza 1 = (1,0,0)", s.gracze[1].kolor.is_equal_approx(Color(1, 0, 0)), s.gracze[1].kolor)



func _testy_lokalizacji(K, Z) -> void:
	var jezyki_przed := [K.jezyk_tekstow, K.jezyk_glosow, K.jezyk_kampanii]
	K.jezyk_tekstow = "pl"; K.jezyk_glosow = "pl"; K.jezyk_kampanii = "pl"; Z.przebuduj_zrodla()
	await _testy_lokalizacji_pl(K, Z)
	K.jezyk_tekstow = jezyki_przed[0]; K.jezyk_glosow = jezyki_przed[1]; K.jezyk_kampanii = jezyki_przed[2]; Z.przebuduj_zrodla()


func _testy_lokalizacji_pl(K, Z) -> void:
	# --- teksty ---
	var tpl: Dictionary = Z.teksty()
	var ob_ph := {}
	for o in Z.tabela("dbobjects"):
		if String(o.Name) == "Inf04 - Phalanx": ob_ph = o
	var lid := int(ob_ph.get("Language ID", -1))
	var mpl = _json(K, "dane/lokalizacja/pl/manifest.json")
	_ok("E2 teksty PL: Language.dll AoC – liczba napisów = Python", mpl != null and tpl.size() == int(mpl.teksty.aoc.napisy_pl), "%d" % tpl.size())
	_ok("E2 teksty PL: nazwa falangi", tpl.get(lid, "") != "" , tpl.get(lid, "?"))

	# --- lokalizacja audio: polski głos falangi (Selection sound 1) ---
	var snd := {}
	for r in Z.tabela("dbsounds"): snd[int(r.ID)] = r
	var sid := int(ob_ph.get("Selection sound 1", -1))
	var sciezka := String(snd.get(sid, {}).get("Pathname", "")).to_lower().replace("\\", "/")
	var glos: Dictionary = Z.wczytaj_dzwiek(sciezka)
	var wpis_pl := {}
	if mpl:
		for g in mpl.glosy:
			if g.klucz == sciezka: wpis_pl = g
	_ok("E2 audio: dbobjects→dbsounds (falanga, Selection sound 1)", sciezka != "", sciezka)
	_ok("E2 audio: głos PL z nakładki localization/pl", glos.get("warstwa", "") == "localization/pl" and not wpis_pl.is_empty() and _sha(glos.dane) == wpis_pl.sha256_pl, glos.get("zrodlo", ""))
	var st = glos.get("strumien")
	_ok("E2 audio: AudioStreamWAV z oryginalnych bajtów (bez przekodowania)", st is AudioStreamWAV and abs(st.get_length() - float(wpis_pl.pl.sekundy)) < 0.05, "%.3f s vs %.3f s" % [st.get_length() if st else -1.0, float(wpis_pl.get("pl", {}).get("sekundy", -1))])
	var pl_odtw := AudioStreamPlayer.new(); root.add_child(pl_odtw); pl_odtw.stream = st; pl_odtw.play()
	await process_frame
	_ok("E2 audio: odtwarzanie rozpoczęte (sterownik dummy)", pl_odtw.playing)
	# przełączenie głosów na EN przy zachowaniu polskich tekstów
	K.jezyk_glosow = "en"; Z.przebuduj_zrodla()
	var glos_en: Dictionary = Z.wczytaj_dzwiek(sciezka)
	_ok("E2 audio: głosy EN + teksty PL (oddzielny wybór)", _sha(glos_en.dane) == wpis_pl.get("sha256_en", "") and Z.teksty().get(lid, "") == tpl.get(lid, ""), glos_en.get("zrodlo", ""))
	K.jezyk_glosow = "pl"; Z.przebuduj_zrodla()
	# narracja kampanii PL + brak PL → EN
	var nar: Dictionary = Z.plik_kampanii("AOCRoman.ssa", "sounds/een1ve1s_roman1_1.mp3")
	_ok("E2 audio: narracja kampanii PL (AOCRoman roman1_1)", nar.get("jezyk", "") == "pl" and not nar.zastepstwo)
	var brak: Dictionary = Z.plik_kampanii("AOCPacific.ssa", "sounds/een1ve1s_radar.mp3")
	_ok("E2 audio: brak nagrania PL → angielski odpowiednik", brak.get("jezyk", "") == "en" and brak.get("zastepstwo", false))
	var mp3 := AudioStreamMP3.new(); mp3.data = nar.get("dane", PackedByteArray())
	_ok("E2 audio: MP3 narracji – długość > 0", mp3.get_length() > 0.1, "%.2f s" % mp3.get_length())



func _testy_warstw(K, Z) -> void:
	# --- warstwa HD niezależna od bazy ---
	var bez: Dictionary = Z.znajdz("textures/basegrass_1_1.sst")
	K.aktywne_warstwy.append("hd_nieustalone"); Z.przebuduj_zrodla()
	var hd: Dictionary = Z.znajdz("textures/basegrass_1_1.sst")
	K.aktywne_warstwy.remove_at(K.aktywne_warstwy.find("hd_nieustalone")); Z.przebuduj_zrodla()
	_ok("E2 warstwy: nakładka hd_nieustalone z instalacji społecznościowej", hd.get("warstwa", "") == "hd_nieustalone", hd.get("zrodlo"))



func _testy_launchera(K, Z) -> void:
	# teksty UI: te same klucze w PL i EN, wszystkie klucze użyte w kodzie istnieją
	var tx := TekstyUI.new()
	tx.wczytaj(K.katalog_openee.path_join("dane/launcher/i18n"))
	var kpl: Array = tx.klucze("pl"); var ken: Array = tx.klucze("en")
	kpl.sort(); ken.sort()
	_ok("L teksty UI: języki pl i en, te same klucze", tx.jezyki().has("pl") and tx.jezyki().has("en") and kpl == ken, "%d kluczy" % kpl.size())
	var kod := FileAccess.get_file_as_string("res://launcher/launcher.gd")
	var re := RegEx.create_from_string("tx\\.t\\(\"([a-z_]+)\"\\)")
	var brak := []
	for m in re.search_all(kod):
		if not tx.ma(m.get_string(1), "pl") or not tx.ma(m.get_string(1), "en"):
			brak.append(m.get_string(1))
	_ok("L teksty UI: brak brakujących kluczy", brak.is_empty(), brak)
	tx.wczytaj_tlumaczenia_silnika(K.katalog_openee.path_join("dane/launcher/i18n/godot"))
	tx.ustaw("pl")
	_ok("L teksty UI: okna Godota po polsku (okno plików, OK/Anuluj)", tx.silnik("Cancel") == "Anuluj" and TranslationServer.translate("Path:") == "Ścieżka:" and TranslationServer.translate("Select Current Folder") == "Wybierz bieżący folder")
	tx.ustaw("en")
	_ok("L teksty UI: okna Godota po angielsku przy UI EN", TranslationServer.translate("Path:") == "Path:" and tx.silnik("Cancel") == "Cancel")
	_ok("L teksty UI: przełączenie na EN", tx.t("nav_ustawienia") == "Settings" and tx.t("mody_tytul", 2) == "Active mods (2)")
	# model (w pamięci – nic nie jest zapisywane)
	var st := StanLaunchera.new(K, Z, true)
	_ok("L profile: wbudowane profile wczytane (bez gry w profilu)", st.profile.size() >= 3 and not st.profil("vanilla").is_empty() and not st.profil("vanilla").has("gra"), st.profile.size())
	_ok("L profile: stare id vanilla_aoc/vanilla_ee = alias profilu vanilla", st.profil("vanilla_aoc").get("id", "") == "vanilla" and st.profil("vanilla_ee").get("id", "") == "vanilla")
	_ok("L profile: domyślnie vanilla + AoC = konfiguracja silnika", st.profil_id == "vanilla" and st.gra_id == "aoc" and st._warstwy_profilu(st.aktualny()) == ["vanilla", "aoc"])
	var inst := st.info_instalacji()
	if not K.instalacje.has("referencyjna"):
		_pomin(["L karta gry: wykryta instalacja bieżącego źródła"], "brak instalacji EE")
	else:
		_ok("L karta gry: wykryta instalacja bieżącego źródła", inst.ok and inst.aoc and inst.gog and inst.zrodlo == K.zrodlo_gry, inst.sciezka)
	if not K.instalacje.has("spolecznosciowa"):
		_pomin(["L mody: nakładka HD dostępna do dodania"], "nakładka HD wymaga instalacji społecznościowej")
	else:
		_ok("L mody: nakładka HD dostępna do dodania", st.mody_do_dodania().size() >= 1 and st.mody_do_dodania()[0].id == "hd_nieustalone")
	st.dodaj_mod("hd_nieustalone", "Kopia testowa")
	var kopia := st.aktualny()
	_ok("L mody: dodanie do profilu wbudowanego tworzy kopię", not kopia.get("wbudowany", true) and kopia.mody == ["hd_nieustalone"] and st.profil("vanilla").mody.is_empty())
	_ok("L mody: warstwy profilu zawierają nakładkę", st._warstwy_profilu(kopia) == ["vanilla", "aoc", "hd_nieustalone"] and st.liczba_wlaczonych_modow() == 1)
	st.przelacz_mod("hd_nieustalone", "x")
	_ok("L mody: wyłączony mod nie trafia do warstw", st._warstwy_profilu(st.aktualny()) == ["vanilla", "aoc"] and st.liczba_wlaczonych_modow() == 0)
	_ok("L profile: usunięcie profilu użytkownika", st.usun_profil(kopia.id) and st.profil_id == "vanilla" and not st.usun_profil("vanilla"))
	var j0 := [K.jezyk_tekstow, K.jezyk_glosow, K.jezyk_kampanii]
	st.ustaw_jezyk_gry("pl_en")
	_ok("L język gry: preset PL tekst + EN głosy", st.jezyk_gry() == "pl_en" and K.jezyk_glosow == "en" and K.jezyk_tekstow == "pl")
	K.jezyk_tekstow = j0[0]; K.jezyk_glosow = j0[1]; K.jezyk_kampanii = j0[2]
	_ok("L konfiguracja: tryb testów nie zapisuje uzytkownik.cfg", K.zapisz_uzytkownika({"launcher/test": 1}) == false)
	# ikony
	var zle := []
	for n in IkonyLaunchera.nazwy():
		var t: Texture2D = IkonyLaunchera.tekstura(n, Color.WHITE, 24)
		if t == null or t.get_width() != 24 or t.get_image().get_width() < 48:
			zle.append(n)
	_ok("L ikony: wszystkie SVG renderowane (HiDPI ×3)", zle.is_empty(), "%d ikon %s" % [IkonyLaunchera.nazwy().size(), zle])
	# scena launchera
	var sc: Node = load("res://launcher/launcher.tscn").instantiate()
	root.add_child(sc)
	for i in 6:
		await process_frame
	var nav: Array = []
	var start_ok := false
	for n in sc.find_children("*", "Button", true, false):
		if n.toggle_mode and n.button_group != null:
			nav.append(n)
		if n.text.strip_edges() == sc.tx.t("uruchom"):
			start_ok = true
	_ok("L scena: 7 pozycji menu bocznego + przycisk uruchamiania", nav.size() == 7 and start_ok, nav.size())
	var etykiety := sc.find_children("*", "Label", true, false).map(func(l): return l.text)
	_ok("L scena: karty ekranu głównego", etykiety.has(sc.tx.t("silnik_tytul")) and etykiety.has(sc.tx.t("profil_tytul")) and etykiety.has(sc.tx.t("podglad_tytul")) and etykiety.has("Empire Earth"))
	sc._zmien_jezyk_ui("en" if sc.tx.jezyk == "pl" else "pl")
	for i in 3:
		await process_frame
	etykiety = sc.find_children("*", "Label", true, false).map(func(l): return l.text)
	# podtytuł nagłówka: w grafice baner_<język>.png (nagłówek z referencji) albo etykieta (wariant zastępczy)
	var naglowek_ok: bool = sc._baner_ref_plik.ends_with("baner_%s.png" % sc.tx.jezyk) or etykiety.has(sc.tx.t("podtytul"))
	_ok("L scena: przełączenie języka UI przebudowuje teksty i nagłówek", etykiety.has(sc.tx.t("silnik_tytul")) and naglowek_ok, "%s %s" % [sc.tx.jezyk, sc._baner_ref_plik.get_file()])
	for s in ["gra", "mody", "profile", "ustawienia", "narzedzia", "informacje", "start"]:
		sc._pokaz_strone(s)
		await process_frame
	_ok("L scena: wszystkie strony budują się bez błędów", sc.strona == "start")
	sc.queue_free()
	await process_frame
	var w := root
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED


func _scn(Z, gra: String, kamp: String, czesc: String) -> ScenariuszEE:
	var a = Z.archiwum("referencyjna", "%s/Data/Campaigns/%s" % [gra, kamp])
	if a == null:
		return null
	for k in a.wpisy:
		if k.ends_with(".scn") and czesc in k:
			var s := ScenariuszEE.new()
			if s.wczytaj(a.czytaj(k)) and s.czytaj_teren():
				return s
	return null


func _liczba_obiektow(s: ScenariuszEE) -> int:
	var n := 0
	for g in s.gracze:
		n += g.jednostki.size()
	return n


func _testy_etapu3(K, Z) -> void:
	if not K.instalacje.has("referencyjna"):
		_pomin(["E3 teren: wariant tekstury N = 1 + W·(r mod H) + (W−1−(c mod W))",
			"E3 teren: narożnik = tekstura rodzaju terenu pola (−1,−1) – wszystkie pola okna",
			"E3 teren: narożnik 0 (r+1,c+1) = rodzaj terenu samego pola",
			"E3 teren: przejścia między teksturami występują (warstwy > 1)",
			"E3 teren: siatka okna 48×48 (2 trójkąty na pole + woda, bez dodatkowej geometrii klifów)",
			"E3 woda: warstwa półprzezroczysta, alfa narożników ∈ {0; 0,5} (bity lądu)",
			"E3 klify: pola z teksturą klifu (dbcliffterrain) rysowane jako zwykłe pola",
			"E3 scenariusz EE: wersja 231, 17 graczy, obiekty = czytnik Pythona",
			"E3 scenariusz EE z nieczytelną listą celów: gracz 3 częściowo, pozostali kompletni (= Python)",
			"E3 scenariusz AoC (wersja 250) bez zmian: 9537 obiektów",
			"E3 wzorzec Pythona: 52 scenariusze kampanii, 0 błędów"], "brak instalacji EE")
		_test_bazy_obiektu()
		_pomin(["E3 obiekty: mury ukośne zgodne z macierzą transformacji (Python, wyniki/test_orientacji_modeli.json)"], "brak instalacji EE")
		return
	var wzor = _json(K, "wyniki/test_scenariuszy_ee_aoc.json")
	var rzym := _scn(Z, "Empire Earth - The Art of Conquest", "AOCRoman.ssa", "soldiers")
	if rzym == null:
		_ok("E3 scenariusz AoC wczytany", false); return
	var te := TerenEE.new(rzym, Z.tabela("dbterrain"))
	# --- warianty tekstur (reguła silnika) ---
	_ok("E3 teren: wariant tekstury N = 1 + W·(r mod H) + (W−1−(c mod W))",
		te.plik_wariantu(18, 1, 0).ends_with("_8.sst") and te.plik_wariantu(18, 0, 3).ends_with("_1.sst") and te.plik_wariantu(3, 3, 2).ends_with("_4.sst"),
		[te.plik_wariantu(18, 1, 0), te.plik_wariantu(18, 0, 3), te.plik_wariantu(3, 3, 2)])
	# --- mieszanie: w każdym narożniku widoczna jest dokładnie tekstura rodzaju terenu narożnika ---
	var pola := 0; var zgodne := 0; var przejscia := 0; var wlasny := 0
	for r in range(104, 152):
		for c in range(160, 208):
			if rzym.indeks_pola(r, c) < 0:
				continue
			pola += 1
			var w := te.warstwy_pola(r, c)
			if w.tereny[0] == te.teren_pola(r, c): wlasny += 1
			var ok := true
			var wiele := false
			for k in 4:
				var widoczna := ""
				for sl in 4:
					if w.warstwy[sl] != "" and float(w.alfa[k][sl]) >= 1.0:
						widoczna = w.warstwy[sl]
				var oczek := te.plik_wariantu(int(w.tereny[k]), r, c) if int(w.tereny[k]) >= 0 else widoczna
				if widoczna != oczek: ok = false
				if w.warstwy[1] != "": wiele = true
			if ok: zgodne += 1
			if wiele: przejscia += 1
	_ok("E3 teren: narożnik = tekstura rodzaju terenu pola (−1,−1) – wszystkie pola okna", pola > 0 and zgodne == pola, "%d/%d pól, przejść %d" % [zgodne, pola, przejscia])
	_ok("E3 teren: narożnik 0 (r+1,c+1) = rodzaj terenu samego pola", wlasny == pola, "%d/%d" % [wlasny, pola])
	_ok("E3 teren: przejścia między teksturami występują (warstwy > 1)", przejscia > 50, przejscia)
	# --- budowa siatki, woda, klify ---
	var wezel: Node3D = te.zbuduj(104, 160, 48, Z)
	var st: Dictionary = te.statystyka
	_ok("E3 teren: siatka okna 48×48 (2 trójkąty na pole + woda, bez dodatkowej geometrii klifów)",
		st.pola == 48 * 48 and st.trojkaty == 2 * st.pola + 2 * st.pola_wody and st.pola_bez_tekstury == 0, st)
	var woda: MeshInstance3D = wezel.get_node_or_null("Woda")
	var alfy := {}
	if woda:
		for col in woda.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]:
			alfy[snappedf(col.a, 0.01)] = true
	_ok("E3 woda: warstwa półprzezroczysta, alfa narożników ∈ {0; 0,5} (bity lądu)", woda != null and st.pola_wody > 0 and alfy.keys().all(func(a): return a == 0.0 or a == 0.5), [st.pola_wody, alfy.keys()])
	var klify := 0
	for i in rzym.teren.teren.size():
		if int(rzym.teren.teren[i]) in [50, 51, 74, 75, 77, 78]: klify += 1
	_ok("E3 klify: pola z teksturą klifu (dbcliffterrain) rysowane jako zwykłe pola", klify > 0, "%d pól klifu na mapie" % klify)
	wezel.free()
	# --- scenariusze EE (wersja 231) ---
	var troja := _scn(Z, "Empire Earth", "EETheGreeks.ssa", "trojan")
	var ok_t := troja != null and troja.czytaj_graczy(K.katalog_openee)
	var oczek_t: int = int(wzor.pliki.get("EETheGreeks.ssa:scenarios/een1ve1s_the trojan war.scn", {}).get("obiekty", -1)) if wzor else -1
	if wzor == null:
		_pomin(["E3 scenariusz EE: wersja 231, 17 graczy, obiekty = czytnik Pythona"], "brak wyniki/test_scenariuszy_ee_aoc.json – uruchom narzedzia/przygotuj_dane_lokalne.sh")
	else:
		_ok("E3 scenariusz EE: wersja 231, 17 graczy, obiekty = czytnik Pythona", ok_t and troja.wersja == 231 and troja.gracze.size() == 17 and _liczba_obiektow(troja) == oczek_t,
			"%s obiektów (Python %d)" % [_liczba_obiektow(troja) if ok_t else -1, oczek_t])
	var wojownicy := _scn(Z, "Empire Earth", "EETheGreeks.ssa", "warriors")
	var ok_w := wojownicy != null and wojownicy.czytaj_graczy(K.katalog_openee)
	var oczek_w: int = int(wzor.pliki.get("EETheGreeks.ssa:scenarios/een1ve1s_warriors from the sea.scn", {}).get("obiekty", -1)) if wzor else -1
	var niep := []
	if ok_w:
		for i in wojownicy.gracze.size():
			if wojownicy.gracze[i].has("niepelny"): niep.append(i)
	if wzor == null:
		_pomin(["E3 scenariusz EE z nieczytelną listą celów: gracz 3 częściowo, pozostali kompletni (= Python)"], "brak wyniki/test_scenariuszy_ee_aoc.json – uruchom narzedzia/przygotuj_dane_lokalne.sh")
	else:
		_ok("E3 scenariusz EE z nieczytelną listą celów: gracz 3 częściowo, pozostali kompletni (= Python)", ok_w and niep == [3] and _liczba_obiektow(wojownicy) == oczek_w,
			"%s obiektów (Python %d), niepełni %s" % [_liczba_obiektow(wojownicy) if ok_w else -1, oczek_w, niep])
	var ok_r := rzym.czytaj_graczy(K.katalog_openee)
	_ok("E3 scenariusz AoC (wersja 250) bez zmian: 9537 obiektów", ok_r and rzym.wersja == 250 and _liczba_obiektow(rzym) == 9537, _liczba_obiektow(rzym))
	if wzor == null:
		_pomin(["E3 wzorzec Pythona: 52 scenariusze kampanii, 0 błędów"], "brak wyniki/test_scenariuszy_ee_aoc.json – uruchom narzedzia/przygotuj_dane_lokalne.sh")
	else:
		_ok("E3 wzorzec Pythona: 52 scenariusze kampanii, 0 błędów", wzor != null and int(wzor.podsumowanie.bledy) == 0 and int(wzor.podsumowanie["231"].pliki) + int(wzor.podsumowanie["250"].pliki) == 52, wzor.podsumowanie if wzor else null)
	_test_bazy_obiektu()
	var orient = _json(K, "wyniki/test_orientacji_modeli.json")
	var zg := 0; var n_uk := 0
	if orient:
		for sc in orient.values():
			var u: Dictionary = sc.get("zgodnosc_osi_z_kierunkiem_muru", {}).get("R·a ukosne", {})
			zg += int(u.get("<15st", 0)); n_uk += int(u.get("n", 0))
	if orient == null:
		_pomin(["E3 obiekty: mury ukośne zgodne z macierzą transformacji (Python, wyniki/test_orientacji_modeli.json)"], "brak wyniki/test_orientacji_modeli.json – uruchom narzedzia/przygotuj_dane_lokalne.sh")
	else:
		_ok("E3 obiekty: mury ukośne zgodne z macierzą transformacji (Python, wyniki/test_orientacji_modeli.json)", n_uk > 0 and zg >= n_uk * 0.7, "%d/%d" % [zg, n_uk])


func _test_bazy_obiektu() -> void:
	# --- orientacja obiektów: macierz transformacji rekordu ---
	var skr := load("res://sceny/test_scenariusz.gd")
	var m90 := PackedByteArray(); m90.resize(64)
	var wart := [0.0, -1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0]
	for i in 16: m90.encode_float(4 * i, wart[i])
	var b90: Basis = skr._baza_obiektu(m90)
	var id := PackedByteArray(); id.resize(64)
	for i in 16: id.encode_float(4 * i, 1.0 if i in [0, 5, 10, 15] else 0.0)
	var b0: Basis = skr._baza_obiektu(id)
	# etap 7: oś X modelu (w siatce importera (1, 0, 0)) po obrocie 90° → oś y świata EE = UkladEE.wektor(0, 1, 0)
	# = (0, 0, −1) Godota; oś y modelu (siatka (0, 0, −1)) przy R = I → oś y świata EE; wyznacznik +1 (bez odbicia)
	_ok("E3 obiekty: obrót 90° (oś X modelu → oś y świata EE), wyznacznik +1 (UkladEE, etap 7)",
		(b90 * Vector3(1, 0, 0)).is_equal_approx(UkladEE.wektor(Vector3(0, 1, 0))) and absf(b90.determinant() - 1.0) < 1e-4
		and (b0 * Vector3(0, 0, -1)).is_equal_approx(UkladEE.wektor(Vector3(0, 1, 0))),
		[b90 * Vector3(1, 0, 0), b90.determinant(), b0 * Vector3(0, 0, -1)])
