class_name TestyGierEeAoc
extends RefCounted
## Testy etapu 11 (docs/FORMATY_DB_EE_VS_AOC.md, docs/WARIANTY_GRY.md): dwie gry na jednym silniku.
##  * formaty baz EE 1.0 / AoC – dane syntetyczne: rozpoznanie wariantu z nagłówka i rozmiaru, przesunięcia pól,
##    rozmiar niejednoznaczny / nieznany / ucięty → czytelny błąd (bez błędu silnika), dbtechtree 268/272, dbeffects 68/88;
##  * definicje gier (dane/gry.json), wybór gry w konfiguracji (pierwszeństwo i migracja), aliasy starych profili;
##  * dane rzeczywiste (jeśli instalacja jest skonfigurowana): EE → format "ee" 724 obiekty, AoC → "aoc" 848, powiązania
##    dbobjects → dbgraphics w obrębie tej samej gry, epoki 0–14 / 0–15, Language.dll każdej gry;
##  * przełączanie EE → AoC → EE w jednej sesji launchera: brak rekordów i zasobów poprzedniej gry, tryb EE nie czyta
##    plików AoC. Ten zestaw wychwytuje powtórzenie błędu `vanilla_ee` (baza EE czytana układem AoC).

var t
const WSPOLNY_ROZNY := "models/bld_barracks_06.cem"


func _init(runner) -> void:
	t = runner


# ---------------------------------------------------------------- pomocnicze

func _offset_pola(pola: Array, nazwa: String) -> int:
	var o := 0
	for f in pola:
		if f[0] == nazwa:
			return o
		o += int(f[1])
	return -1


func _tabela(n: int, rekord: int) -> PackedByteArray:
	var b := PackedByteArray(); b.resize(4 + n * rekord); b.fill(0)
	b.encode_u32(0, n)
	return b


func _rek_tech(f: Dictionary, id: int, epoka: int, budowniczowie: Array) -> PackedByteArray:
	var b := PackedByteArray(); b.resize(int(f.rekord) + 4 * budowniczowie.size()); b.fill(0)
	b.encode_s32(104, id); b.encode_s32(int(f.epoka), epoka); b.encode_s32(int(f.budowniczowie), budowniczowie.size())
	for i in budowniczowie.size(): b.encode_s32(int(f.rekord) + 4 * i, budowniczowie[i])
	return b


func _techtree(w: String) -> PackedByteArray:
	var f: Dictionary = EpokiDB.TECH[w]
	var d := PackedByteArray()
	var n := PackedByteArray(); n.resize(4)
	n.encode_s32(0, 1); d.append_array(n)
	d.append_array(_rek_tech(f, 0, 1, [35, 41])); d.append_array(_rek_tech(f, 100, 0, []))
	n.encode_s32(0, 0); d.append_array(n)
	d.append_array(_rek_tech(f, 1, 15 if w == "aoc" else 14, [7]))
	return d


# ---------------------------------------------------------------- testy

func uruchom(K: Node, Z: Node) -> void:
	_formaty_db(K)
	_epoki()
	_definicje_gier(K)
	_konfiguracja_i_migracja(K, Z)
	if not K.instalacje.has("referencyjna") or not GryEE.dostepna("ee", K.instalacje["referencyjna"], K.katalog_openee) \
			or not GryEE.dostepna("aoc", K.instalacje["referencyjna"], K.katalog_openee):
		t._pomin(["E11 dane: dbobjects EE → format ee, 724 rekordy", "E11 dane: dbobjects AoC → format aoc, 848 rekordów",
			"E11 dane: EE – Graphic ID → dbgraphics EE", "E11 dane: AoC – Graphic ID → dbgraphics AoC",
			"E11 dane: dbcivilization EE/AoC", "E11 dane: dbtechtree EE epoki 0–14, AoC 0–15", "E11 dane: dbeffects EE 68 B / AoC 88 B",
			"E11 dane: Language.dll – osobna dla każdej gry", "E11 dane: kampanie EE (5) i AoC (4) z własnych katalogów",
			"E11 przełączanie: EE – baza EE (724, format ee)", "E11 przełączanie: EE – źródła bez katalogu AoC",
			"E11 przełączanie: EE – zasób tylko z AoC zgłaszany jako brak", "E11 przełączanie: EE – Language.dll EE",
			"E11 przełączanie: AoC – baza AoC (848, format aoc)", "E11 przełączanie: AoC – zasób AoC dostępny, archiwum EE jako drugie",
			"E11 przełączanie: AoC → EE – brak rekordów i zasobów AoC w pamięci", "E11 przełączanie: pamięć podręczna modeli czyszczona"],
			"wymaga instalacji referencyjnej z obiema grami")
		return
	_dane_rzeczywiste(K, Z)
	_przelaczanie(K, Z)


func _formaty_db(K: Node) -> void:
	var kat: String = K.katalog_openee
	var pe := BazaDB.uklad("dbobjects", "ee", kat); var pa := BazaDB.uklad("dbobjects", "aoc", kat)
	var re := BazaDB.rozmiar_rekordu(pe); var ra := BazaDB.rozmiar_rekordu(pa)
	t._ok("E11 format: dbobjects – rekord EE 1948 B, AoC 1960 B", re == 1948 and ra == 1960, [re, ra])
	var de := _tabela(3, re); var da := _tabela(3, ra)
	var oid_e := _offset_pola(pe, "ID"); var oct_e := _offset_pola(pe, "Can build tech"); var oct_a := _offset_pola(pa, "Can build tech")
	de.encode_s32(4 + re + oid_e, 77); de.encode_s32(4 + 2 * re + oct_e, 555)
	da.encode_s32(4 + 2 * ra + oct_a, 666)
	var we := BazaDB.dekoduj(de, "dbobjects", kat); var wa := BazaDB.dekoduj(da, "dbobjects", kat)
	t._ok("E11 format: rozpoznanie dbobjects EE → ee", BazaDB.rozpoznaj(de, "dbobjects", kat).get("wariant") == "ee" and we.get("wariant") == "ee")
	t._ok("E11 format: rozpoznanie dbobjects AoC → aoc", BazaDB.rozpoznaj(da, "dbobjects", kat).get("wariant") == "aoc" and wa.get("wariant") == "aoc")
	t._ok("E11 format: EE – pola za usuniętymi polami AoC (ID, Can build tech) pod właściwym przesunięciem",
		we.has("rekordy") and int(we.rekordy[1].ID) == 77 and int(we.rekordy[2]["Can build tech"]) == 555 and not we.rekordy[0].has("Unknown#55"),
		[oct_e, oct_a])
	t._ok("E11 format: AoC – Can build tech przesunięte o 8 B względem EE", oct_a - oct_e == 8 and wa.has("rekordy") and int(wa.rekordy[2]["Can build tech"]) == 666 and wa.rekordy[0].has("Unknown#55"))
	# regresja vanilla_ee: baza EE wymuszona układem AoC musi dać błąd, nie śmieci ani błąd silnika
	var wymuszony := BazaDB.dekoduj(de, "dbobjects", kat, "aoc")
	t._ok("E11 format: baza EE czytana układem AoC → błąd (regresja vanilla_ee)", wymuszony.has("blad"), wymuszony.get("blad", ""))
	# ten sam rozmiar pliku dla obu wariantów (NWW 1948 i 1960 = 954520 B) – rozstrzyga licznik N z nagłówka
	var wsp := PackedByteArray(); wsp.resize(4 + 954520); wsp.fill(0)
	wsp.encode_u32(0, 490)
	var r490 := BazaDB.rozpoznaj(wsp, "dbobjects", kat)
	wsp.encode_u32(0, 487)
	var r487 := BazaDB.rozpoznaj(wsp, "dbobjects", kat)
	t._ok("E11 format: jednakowy rozmiar – wariant z licznika N (490 → ee, 487 → aoc)", r490.get("wariant") == "ee" and r487.get("wariant") == "aoc")
	var nz := _tabela(3, re + 2)
	var rn := BazaDB.rozpoznaj(nz, "dbobjects", kat)
	t._ok("E11 format: nieznany rozmiar rekordu → błąd „nieobsługiwany wariant”", rn.has("blad") and String(rn.blad).contains("nieobsługiwany wariant"), rn.get("blad", ""))
	var uc := da.slice(0, da.size() - 1)
	var ru := BazaDB.dekoduj(uc, "dbobjects", kat)
	var ru2 := BazaDB.dekoduj(uc, "dbobjects", kat, "aoc")
	t._ok("E11 format: ucięty plik → błąd rozpoznania i błąd odczytu poza danymi", ru.has("blad") and ru2.has("blad") and String(ru2.blad).contains("poza danymi"), ru2.get("blad", ""))
	var zly_n := _tabela(3, ra); zly_n.encode_u32(0, 1000000)
	t._ok("E11 format: licznik N większy niż dane → błąd", BazaDB.dekoduj(zly_n, "dbobjects", kat).has("blad"))
	t._ok("E11 format: plik krótszy niż nagłówek → błąd", BazaDB.rozpoznaj(PackedByteArray([1, 2]), "dbobjects", kat).has("blad"))
	var ce := BazaDB.rozmiar_rekordu(BazaDB.uklad("dbcivilization", "ee", kat)); var ca := BazaDB.rozmiar_rekordu(BazaDB.uklad("dbcivilization", "aoc", kat))
	t._ok("E11 format: dbcivilization – EE 416 B / AoC 600 B rozpoznane", ce == 416 and ca == 600
		and BazaDB.rozpoznaj(_tabela(2, ce), "dbcivilization", kat).get("wariant") == "ee"
		and BazaDB.rozpoznaj(_tabela(2, ca), "dbcivilization", kat).get("wariant") == "aoc", [ce, ca])
	t._ok("E11 format: tabela o wspólnym układzie (dbgraphics) → wspolny", BazaDB.rozpoznaj(_tabela(0, 1), "dbgraphics", kat).get("wariant") == "wspolny"
		and not BazaDB.ma_warianty("dbgraphics", kat))


func _epoki() -> void:
	var te := EpokiDB.techtree(_techtree("ee")); var we := EpokiDB.wariant_techtree
	var ta := EpokiDB.techtree(_techtree("aoc")); var wa := EpokiDB.wariant_techtree
	t._ok("E11 epoki: dbtechtree EE (268 B) – wariant i epoka z przesunięcia 248", we == "ee" and te.size() == 3 and int(te[0].epoka) == 1 and int(te[2].epoka) == 14, we)
	t._ok("E11 epoki: dbtechtree AoC (272 B) – wariant i epoka z przesunięcia 252", wa == "aoc" and ta.size() == 3 and int(ta[2].epoka) == 15, wa)
	var zly := _techtree("aoc").slice(0, 300)
	t._ok("E11 epoki: ucięty dbtechtree → błąd, brak rekordów", EpokiDB.techtree(zly).is_empty() and EpokiDB.blad.contains("dbtechtree"), EpokiDB.blad)
	var ef_ee := PackedByteArray(); ef_ee.resize(68 * 3); ef_ee.fill(0)
	var ef_aoc := PackedByteArray(); ef_aoc.resize(88 * 3); ef_aoc.fill(0)
	EpokiDB.efekty(ef_ee); var w1 := EpokiDB.wariant_efektow
	EpokiDB.efekty(ef_aoc); var w2 := EpokiDB.wariant_efektow
	t._ok("E11 epoki: dbeffects 68 B → ee, 88 B → aoc", w1 == "ee" and w2 == "aoc", [w1, w2])
	var ef_nj := PackedByteArray(); ef_nj.resize(1496); ef_nj.fill(0)       # NWW(68, 88) – oba formaty pasują
	t._ok("E11 epoki: dbeffects o długości wielokrotności 1496 B → błąd niejednoznaczności", EpokiDB.efekty(ef_nj).is_empty() and EpokiDB.blad.contains("niejednoznaczny"), EpokiDB.blad)


func _definicje_gier(K: Node) -> void:
	var kat: String = K.katalog_openee
	t._ok("E11 gry: dwie definicje (ee, aoc), nieznana odrzucana", GryEE.WSZYSTKIE == ["ee", "aoc"] and not GryEE.poprawna("xyz") and GryEE.definicja("xyz", kat).is_empty())
	t._ok("E11 gry: EE – dane tylko z katalogu Empire Earth", GryEE.katalogi_danych("ee", kat) == ["Empire Earth"] and GryEE.katalogi_kampanii("ee", kat) == ["Empire Earth"])
	t._ok("E11 gry: AoC – katalog AoC przed EE (zmierzone: EE-AOC.exe otwiera oba data.ssa)",
		GryEE.katalogi_danych("aoc", kat) == ["Empire Earth - The Art of Conquest", "Empire Earth"])
	t._ok("E11 gry: format bazy i Language.dll każdej gry", GryEE.format_db("ee", kat) == "ee" and GryEE.format_db("aoc", kat) == "aoc"
		and GryEE.katalog_language_dll("ee", kat) == "Empire Earth" and GryEE.katalog_language_dll("aoc", kat) == "Empire Earth - The Art of Conquest")
	t._ok("E11 gry: wersje SCN – EE tylko 231, AoC 231–250", GryEE.wersje_scn("ee", kat) == [231] and 250 in GryEE.wersje_scn("aoc", kat) and 231 in GryEE.wersje_scn("aoc", kat))
	t._ok("E11 gry: warstwy bazowe – EE vanilla, AoC vanilla+aoc", GryEE.warstwy_bazowe("ee", kat) == ["vanilla"] and GryEE.warstwy_bazowe("aoc", kat) == ["vanilla", "aoc"])


func _konfiguracja_i_migracja(K: Node, Z: Node) -> void:
	var KS = K.get_script()
	t._ok("E11 konfiguracja: [gra] wariant użytkownika ma pierwszeństwo przed szablonem", KS.wybierz_gre(null, "ee", null, "aoc", null).gra == "ee")
	t._ok("E11 konfiguracja: stary [zrodlo] profil użytkownika wygrywa z nowym kluczem szablonu (migracja bez utraty wyboru)",
		KS.wybierz_gre(null, null, "ee", "aoc", "aoc").gra == "ee" and String(KS.wybierz_gre(null, null, "ee", "aoc", null).zrodlo).contains("stary"))
	t._ok("E11 konfiguracja: argument --gra nadpisuje pliki", KS.wybierz_gre("ee", "aoc", "aoc", "aoc", "aoc").gra == "ee")
	var zla: Dictionary = KS.wybierz_gre(null, "xyz", null, null, null)
	t._ok("E11 konfiguracja: nieznana gra → błąd i gra domyślna", zla.has("blad") and zla.gra == GryEE.DOMYSLNA, zla.get("blad", ""))
	t._ok("E11 konfiguracja: brak kluczy → aoc (domyślna)", KS.wybierz_gre(null, null, null, null, null).gra == "aoc")
	var st := StanLaunchera.new(K, Z, true)
	st.profil_id = "vanilla_ee"
	st._migruj()
	t._ok("E11 launcher: migracja profilu vanilla_ee → vanilla + gra ee (w pamięci, bez zapisu)", st.profil_id == "vanilla" and st.gra_id == "ee", st.migracja)
	st.profil_id = "vanilla_aoc"
	st._migruj()
	t._ok("E11 launcher: migracja profilu vanilla_aoc → vanilla + gra aoc", st.profil_id == "vanilla" and st.gra_id == "aoc")
	st.gra_id = "ee"
	t._ok("E11 launcher: warstwy profilu zależą od gry, nie od profilu", st._warstwy_profilu(st.profil("vanilla")) == ["vanilla"]
		and st._warstwy_profilu(st.profil("vanilla_hd")) == ["vanilla", "hd_nieustalone"])


func _dane_rzeczywiste(K: Node, Z: Node) -> void:
	var kat: String = K.katalog_openee
	var ae = Z.archiwum("referencyjna", "Empire Earth/Data/data.ssa")
	var aa = Z.archiwum("referencyjna", "Empire Earth - The Art of Conquest/Data/data.ssa")
	var tab := {}
	for g in [["ee", ae], ["aoc", aa]]:
		for n in ["dbobjects", "dbgraphics", "dbcivilization"]:
			tab[g[0] + n] = BazaDB.dekoduj(g[1].czytaj("db/%s.dat" % n), n, kat)
	var oe: Dictionary = tab["eedbobjects"]; var oa: Dictionary = tab["aocdbobjects"]
	t._ok("E11 dane: dbobjects EE → format ee, 724 rekordy", oe.get("wariant") == "ee" and oe.get("rekordy", []).size() == 724, oe.get("blad", ""))
	t._ok("E11 dane: dbobjects AoC → format aoc, 848 rekordów", oa.get("wariant") == "aoc" and oa.get("rekordy", []).size() == 848, oa.get("blad", ""))
	for g in ["ee", "aoc"]:
		var gr := {}
		for r in tab[g + "dbgraphics"].get("rekordy", []): gr[int(r.ID)] = true
		var braki := 0
		for o in tab[g + "dbobjects"].get("rekordy", []):
			if int(o["Graphic ID"]) >= 0 and not gr.has(int(o["Graphic ID"])): braki += 1
		t._ok("E11 dane: %s – Graphic ID → dbgraphics %s" % ["EE" if g == "ee" else "AoC", "EE" if g == "ee" else "AoC"], not gr.is_empty() and braki == 0, braki)
	t._ok("E11 dane: dbcivilization EE/AoC", tab["eedbcivilization"].get("wariant") == "ee" and tab["aocdbcivilization"].get("wariant") == "aoc"
		and tab["eedbcivilization"].rekordy.size() == 27 and tab["aocdbcivilization"].rekordy.size() == 29)
	var tte := EpokiDB.techtree(ae.czytaj("db/dbtechtree.dat")); var w1 := EpokiDB.wariant_techtree
	var tta := EpokiDB.techtree(aa.czytaj("db/dbtechtree.dat")); var w2 := EpokiDB.wariant_techtree
	var me := 0; var ma := 0
	for x in tte: me = maxi(me, int(x.epoka))
	for x in tta: ma = maxi(ma, int(x.epoka))
	t._ok("E11 dane: dbtechtree EE epoki 0–14, AoC 0–15", w1 == "ee" and w2 == "aoc" and me == 14 and ma == 15, [w1, w2, me, ma])
	EpokiDB.efekty(ae.czytaj("db/dbeffects.dat")); var e1 := EpokiDB.wariant_efektow
	EpokiDB.efekty(aa.czytaj("db/dbeffects.dat")); var e2 := EpokiDB.wariant_efektow
	t._ok("E11 dane: dbeffects EE 68 B / AoC 88 B", e1 == "ee" and e2 == "aoc", [e1, e2])
	var ref: String = K.instalacje["referencyjna"]
	var le := TekstyDLL.wczytaj(ref.path_join("Empire Earth/Language.dll")); var la := TekstyDLL.wczytaj(ref.path_join("Empire Earth - The Art of Conquest/Language.dll"))
	t._ok("E11 dane: Language.dll – osobna dla każdej gry", le.size() == 3398 and la.size() == 3707, [le.size(), la.size()])
	var ke := GryEE.kampanie("ee", ref, kat); var ka := GryEE.kampanie("aoc", ref, kat)
	t._ok("E11 dane: kampanie EE (5) i AoC (4) z własnych katalogów", ke.size() == 5 and "EETheGreeks.ssa" in ke and not "AOCRoman.ssa" in ke
		and ka.size() == 4 and "AOCRoman.ssa" in ka and not "EETheGreeks.ssa" in ka
		and GryEE.archiwum_kampanii("ee", "AOCRoman.ssa", ref, kat).has("blad")
		and GryEE.archiwum_kampanii("aoc", "EETheGreeks.ssa", ref, kat).get("wlasna") == false
		and GryEE.archiwum_kampanii("aoc", "EELearningCampaign.ssa", ref, kat).get("rel", "").begins_with("Empire Earth - The Art of Conquest"), [ke, ka])


## EE → AoC → EE w jednej sesji launchera (zmiany w pamięci, bez zapisu konfiguracji użytkownika).
func _przelaczanie(K: Node, Z: Node) -> void:
	var stan0 := {"gra": K.gra, "zrodlo": K.zrodlo_gry, "inst": K.instalacja_ee, "warstwy": K.aktywne_warstwy, "tekst": K.jezyk_tekstow, "glos": K.jezyk_glosow}
	K.jezyk_tekstow = "en"; K.jezyk_glosow = "en"
	# zasób obecny wyłącznie w archiwum AoC (model nowej jednostki dodatku)
	var ae = Z.archiwum("referencyjna", "Empire Earth/Data/data.ssa")
	var aa = Z.archiwum("referencyjna", "Empire Earth - The Art of Conquest/Data/data.ssa")
	var tylko_aoc := ""
	for k in aa.wpisy:
		if String(k).begins_with("models/") and String(k).ends_with(".cem") and not ae.zawiera(k):
			tylko_aoc = k
			break
	var st := StanLaunchera.new(K, Z, true)
	st.stosuj_w_pamieci = true
	st.wybierz_profil("vanilla")
	var wyniki := []
	for g in ["ee", "aoc", "ee"]:
		st.wybierz_gre(g)
		var ob: Array = Z.tabela("dbobjects")
		var zr := "\n".join(Z.opis_zrodel())
		var r: Dictionary = Z.znajdz(tylko_aoc)
		# ten sam klucz, inna zawartość w EE i AoC (audyt etapu 11) – źródło musi odpowiadać grze, bez starej kopii w pamięci
		var cache_przed: bool = Z._cache_cem.has(WSPOLNY_ROZNY)
		Z.wczytaj_model_cem(WSPOLNY_ROZNY)
		var zr_m := String(Z.znajdz(WSPOLNY_ROZNY).get("zrodlo", ""))
		wyniki.append({"gra": K.gra, "n": ob.size(), "wariant": Z.warianty_tabel.get("dbobjects", ""), "aoc_w_zrodlach": zr.contains("Art of Conquest"),
			"zasob": String(r.get("zrodlo", "")), "teksty": Z.teksty().size(), "model": zr_m, "model_w_cache_przed": cache_przed,
			"klucz": Z.klucz_zrodel})
	var e1: Dictionary = wyniki[0]; var a: Dictionary = wyniki[1]; var e2: Dictionary = wyniki[2]
	t._ok("E11 przełączanie: EE – baza EE (724, format ee)", e1.gra == "ee" and e1.n == 724 and e1.wariant == "ee", e1)
	t._ok("E11 przełączanie: EE – źródła bez katalogu AoC", not e1.aoc_w_zrodlach)
	t._ok("E11 przełączanie: EE – zasób tylko z AoC zgłaszany jako brak", tylko_aoc != "" and e1.zasob == "", tylko_aoc)
	t._ok("E11 przełączanie: EE – Language.dll EE", e1.teksty == 3398, e1.teksty)
	t._ok("E11 przełączanie: AoC – baza AoC (848, format aoc)", a.gra == "aoc" and a.n == 848 and a.wariant == "aoc", a)
	t._ok("E11 przełączanie: AoC – zasób AoC dostępny, archiwum EE jako drugie", a.zasob.contains("Art of Conquest") and a.aoc_w_zrodlach and a.teksty == 3707, a.zasob)
	t._ok("E11 przełączanie: AoC → EE – brak rekordów i zasobów AoC w pamięci", e2.n == 724 and e2.wariant == "ee" and e2.zasob == "" and not e2.aoc_w_zrodlach and e2.klucz == e1.klucz, e2)
	t._ok("E11 przełączanie: pamięć podręczna modeli czyszczona (%s z archiwum właściwej gry)" % WSPOLNY_ROZNY,
		not e1.model_w_cache_przed and not a.model_w_cache_przed and not e2.model_w_cache_przed
		and e1.model.begins_with("referencyjna:Empire Earth/") and a.model.contains("Art of Conquest") and e2.model.begins_with("referencyjna:Empire Earth/"),
		[e1.model, a.model, e2.model])
	# przywrócenie konfiguracji silnika
	K.gra = stan0.gra; K.zrodlo_gry = stan0.zrodlo; K.instalacja_ee = stan0.inst; K.aktywne_warstwy = stan0.warstwy
	K.jezyk_tekstow = stan0.tekst; K.jezyk_glosow = stan0.glos
	Z.przebuduj_zrodla()
