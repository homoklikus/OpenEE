class_name Symulacja
extends RefCounted
## Warstwa symulacji jednostek niezależna od renderera (etap 5, docs/ARCHITEKTURA.md §Etap 5).
##
## * Stały krok KROK (s) niezależny od FPS – postęp wyłącznie przez krok(); zegar sceny (ZegarSymulacji) woła krok()
##   tyle razy, ile mieści się w upływie czasu.
## * Rozkazy trafiają do kolejki i są wykonywane na początku następnego taktu w kolejności wydania (podstawa
##   przyszłego trybu wieloosobowego: wymiana rozkazów zamiast stanu).
## * Jednostki aktualizowane w porządku rosnących identyfikatorów; brak losowości.
## * Zdarzenia taktu (`zdarzenia`) informują warstwę widoku o zmianach stanu animacji i trasach – symulacja nie zna
##   węzłów Godota.
## Deterministyczność między platformami – nietestowana (arytmetyka zmiennoprzecinkowa GDScript).

const KROK := 0.05                 # 20 taktów/s [H – częstotliwość symulacji EE nieustalona]
const PROG_OBROTU := 0.79          # rad (~45°): większa różnica kursu → obrót w miejscu przed ruchem
const TOLERANCJA_CELU := 0.05      # pola
## Prędkość w polach na sekundę rzeczywistą = dbobjects „Speed” × MNOZNIK_PREDKOSCI.
## Etap 13 (docs/MECHANIKA_PREDKOSCI_EE.md): „Speed” to pola na sekundę CZASU GRY [P]; licznik ms czasu gry (A_GRA+0xD0)
## przy normalnej szybkości rośnie o 1460,7–1461,5 ms na sekundę rzeczywistą w EE i AoC [P] – stąd mnożnik. Zgadza się
## z pomiarem etapu 9 (Riverlands, AoC: 1,45–1,55). Wartość 1,706 z etapu 12 była artefaktem metody (maksimum próbek
## 10 Hz przy położeniach zmienianych skokowo co takt) i została wycofana. Dodatek +0,15 pola/s gry w scenariuszach
## z kampanii „Blitzkrieg” – przyczyna [N], bez implementacji.
const MNOZNIK_PREDKOSCI := 1.461
## Etap 13 (docs/KOLIZJE_JEDNOSTEK_EE.md): jednostka w ruchu omija pole jednostki STOJĄCEJ (trasa po siatce obchodzi
## to pole) [P: EE i AoC, ta sama trajektoria]; jednostki idące przenikają się [P]. Bez fizyki i odpychania.
const OMIJANIE_STOJACYCH := true

var mapa: MapaNawigacji
var sciezki: Sciezki
var takt: int = 0
var jednostki := {}                # id → JednostkaSym
var _kolejnosc := PackedInt32Array()
var _kolejka: Array = []           # [{id, typ, cel}]
var _nastepne_id: int = 1
var zdarzenia: Array = []          # zdarzenia ostatniego taktu
var dziennik: Array = []           # diagnostyka (ostatnie wpisy)
var czas_taktow_us: int = 0
var czas_tras_us: int = 0
var _ruszajace := {}               # id jednostek z rozkazem w bieżącym takcie (nie blokują tras innych)


func _init(m: MapaNawigacji) -> void:
	mapa = m
	sciezki = Sciezki.new(m)
	sciezki.oktylowe = true            # trasy jak w EE (etap 9): odcinki w 8 kierunkach przez środki pól


## Tworzy jednostkę z danych scenariusza i rekordu dbobjects; zwraca id.
func dodaj_jednostke(dane: JednostkaSym.DaneJednostki, ob: Dictionary = {}) -> int:
	var j := JednostkaSym.new()
	j.id = _nastepne_id; _nastepne_id += 1
	j.typ = dane.typ; j.wlasciciel = dane.wlasciciel; j.nazwa = String(ob.get("Name", ""))
	j.pozycja = dane.pozycja; j.pozycja_poprz = dane.pozycja
	j.kurs = dane.kurs; j.kurs_poprz = dane.kurs
	j.cel = dane.pozycja
	if not ob.is_empty():
		j.predkosc = maxf(0.0, float(ob.get("Speed", 0.5))) * MNOZNIK_PREDKOSCI
		j.rozmiar_szyku = maxf(0.1, float(ob.get("Size in formation", 0.625)))
		j.obrot_w_miejscu = maxf(0.1, float(ob.get("Idle turning speed", 6.0)))
		j.obrot_w_ruchu = maxf(0.1, float(ob.get("Moving turning speed", 6.0)))
		j.promien = maxf(0.15, float(ob.get("Circle selection size", 0.25)))
		j.polityka = PolitykaRuchu.z_obiektu(ob)
	else:
		j.polityka = PolitykaRuchu.new()
	jednostki[j.id] = j
	_kolejnosc.append(j.id)
	return j.id


func usun_jednostke(id: int) -> void:
	jednostki.erase(id)
	var i := _kolejnosc.find(id)
	if i >= 0: _kolejnosc.remove_at(i)


## Rozkaz ruchu – zastępuje poprzedni (i kolejkę punktów); wykonywany na początku następnego taktu.
## `dolacz` (Shift + PPM w EE): punkt dopisywany do kolejki – jednostka idzie do niego po dojściu do bieżącego celu
## [P: pomiar etap 9 – jednostka dochodzi do punktu A, potem rusza do B].
func rozkaz_ruchu(id: int, cel: Vector2, dolacz := false) -> void:
	_kolejka.append({"id": id, "typ": "ruch", "cel": cel, "dolacz": dolacz})


## Rozkaz ruchu grupy (etap 9): każda jednostka dostaje własne miejsce w szyku EE (FormacjaEE) i idzie do niego
## własną trasą i prędkością. Pojedyncza jednostka – dokładnie punkt rozkazu. Zastępuje poprzednie rozkazy, chyba że
## `dolacz` (Shift) – wtedy miejsca liczone względem ostatnich punktów kolejek i dopisywane [H: szyk w kolejce].
func rozkaz_grupy(ids: Array, cel: Vector2, dolacz := false) -> void:
	_kolejka.append({"id": -1, "typ": "grupa", "ids": ids.duplicate(), "cel": cel, "dolacz": dolacz})


## Rozkaz zatrzymania.
func rozkaz_stop(id: int) -> void:
	_kolejka.append({"id": id, "typ": "stop"})


## Jeden takt symulacji (KROK sekund).
func krok() -> void:
	var t0 := Time.get_ticks_usec()
	zdarzenia.clear()
	var rozkazy := _kolejka; _kolejka = []
	_ruszajace.clear()
	for r in rozkazy:
		if r.typ == "grupa":
			for i in r.ids: _ruszajace[int(i)] = true
		elif r.typ == "ruch":
			_ruszajace[int(r.id)] = true
	for r in rozkazy:
		if r.typ == "grupa":
			_wykonaj_grupe(r.ids, r.cel, bool(r.get("dolacz", false))); continue
		var j: JednostkaSym = jednostki.get(int(r.id))
		if j == null: continue
		if r.typ == "ruch":
			if bool(r.get("dolacz", false)) and j.w_ruchu():
				j.kolejka_celow.append(r.cel)
			else:
				j.kolejka_celow = PackedVector2Array()
				_wykonaj_ruch(j, r.cel)
		elif r.typ == "stop":
			j.kolejka_celow = PackedVector2Array()
			_zatrzymaj(j, "rozkaz stop")
	for id in _kolejnosc:
		_aktualizuj(jednostki[id])
	takt += 1
	czas_taktow_us += Time.get_ticks_usec() - t0


## Komórki jednostek stojących (bez rozkazu w tym takcie) – przeszkody dla trasy `j` [P, etap 13].
func zajete_komorki(j: JednostkaSym) -> PackedInt32Array:
	var out := PackedInt32Array()
	if not OMIJANIE_STOJACYCH: return out
	for id in _kolejnosc:
		if id == j.id or _ruszajace.has(id): continue
		var u: JednostkaSym = jednostki[id]
		if u.ruch != JednostkaSym.Ruch.STOI: continue
		var k := mapa.komorka(u.pozycja)
		if k.x >= 0: out.append(mapa.indeks(k))
	return out


func _wykonaj_ruch(j: JednostkaSym, cel: Vector2, proba := false) -> bool:
	var t0 := Time.get_ticks_usec()
	var zaj := zajete_komorki(j)
	var w := sciezki.znajdz(j.pozycja, cel, j.polityka, zaj)
	if not w.ok and not zaj.is_empty():
		w = sciezki.znajdz(j.pozycja, cel, j.polityka)   # stojące jednostki zamykają przejście – trasa bez nich [H]
	czas_tras_us += Time.get_ticks_usec() - t0
	if not w.ok and proba:
		return false
	if not w.ok:
		j.ostatni_powod = w.powod
		_log("jednostka %d (%s): rozkaz do %s odrzucony – %s" % [j.id, j.nazwa, cel, w.powod])
		zdarzenia.append({"id": j.id, "typ": "trasa_odrzucona", "powod": w.powod, "cel": cel})
		if j.w_ruchu(): _zatrzymaj(j, "nowy rozkaz nieosiągalny")
		return false
	j.cel = cel; j.sciezka = w.sciezka; j.indeks_punktu = 0; j.ostatni_powod = ""
	j.ruch = JednostkaSym.Ruch.OBROT
	zdarzenia.append({"id": j.id, "typ": "trasa", "sciezka": w.sciezka, "odwiedzone": w.odwiedzone, "czas_us": w.czas_us})
	return true


func _wykonaj_grupe(ids: Array, cel: Vector2, dolacz := false) -> void:
	var dane: Array = []
	for id in ids:
		var j: JednostkaSym = jednostki.get(int(id))
		if j != null and j.predkosc > 0.0:
			var od := j.pozycja
			if dolacz and j.w_ruchu():
				od = j.kolejka_celow[j.kolejka_celow.size() - 1] if not j.kolejka_celow.is_empty() else j.cel
			dane.append([j.id, od, j.rozmiar_szyku])
	var miejsca := FormacjaEE.rozmiesc(dane, cel)
	for id in miejsca:
		var j: JednostkaSym = jednostki[id]
		var m: Vector2 = miejsca[id]
		j.miejsce_w_szyku = m
		if dolacz and j.w_ruchu():
			j.kolejka_celow.append(m); continue
		j.kolejka_celow = PackedVector2Array()
		# miejsce w szyku nieosiągalne (np. w wodzie) – najbliższe osiągalne pole przy nim [W]
		if not _wykonaj_ruch(j, m, true):
			var z := sciezki.najblizszy_osiagalny(j.pozycja, m, j.polityka)
			if z == Vector2.INF:
				_wykonaj_ruch(j, m)        # odrzucenie z powodem w dzienniku
			else:
				j.miejsce_w_szyku = z
				_wykonaj_ruch(j, z)


func _zatrzymaj(j: JednostkaSym, powod: String) -> void:
	j.ruch = JednostkaSym.Ruch.STOI
	j.sciezka = PackedVector2Array(); j.indeks_punktu = 0
	_ustaw_animacje(j, "bezczynnosc")
	zdarzenia.append({"id": j.id, "typ": "stop", "powod": powod})


func _ustaw_animacje(j: JednostkaSym, stan: String) -> void:
	if j.stan_animacji != stan:
		j.stan_animacji = stan
		zdarzenia.append({"id": j.id, "typ": "animacja", "stan": stan})


func _aktualizuj(j: JednostkaSym) -> void:
	j.pozycja_poprz = j.pozycja; j.kurs_poprz = j.kurs
	if j.ruch == JednostkaSym.Ruch.STOI:
		return
	var budzet := KROK
	while budzet > 1e-9 and j.ruch != JednostkaSym.Ruch.STOI:
		var punkt: Vector2 = j.sciezka[j.indeks_punktu]
		var d := punkt - j.pozycja
		var dl := d.length()
		if dl <= TOLERANCJA_CELU:
			j.pozycja = punkt
			j.indeks_punktu += 1
			if j.indeks_punktu >= j.sciezka.size():
				if not j.kolejka_celow.is_empty():
					var nast := j.kolejka_celow[0]
					j.kolejka_celow.remove_at(0)
					if _wykonaj_ruch(j, nast):
						j.ruch = JednostkaSym.Ruch.IDZIE   # bez zatrzymania przy punkcie pośrednim [P]
						continue
				_zatrzymaj(j, "cel osiągnięty")
				return
			continue
		var docel := UkladEE.kat_kierunku(d)
		var roz := UkladEE.roznica_katow(docel, j.kurs)
		if j.ruch == JednostkaSym.Ruch.OBROT or absf(roz) > PROG_OBROTU:
			# obrót w miejscu (bez przesuwania) do różnicy ≤ progu
			j.ruch = JednostkaSym.Ruch.OBROT
			var maks := j.obrot_w_miejscu * budzet
			if absf(roz) <= maks:
				j.kurs = docel; budzet -= absf(roz) / j.obrot_w_miejscu
				j.ruch = JednostkaSym.Ruch.IDZIE
			else:
				j.kurs = wrapf(j.kurs + signf(roz) * maks, -PI, PI); budzet = 0.0
			continue
		_ustaw_animacje(j, "ruch")
		var maks_obr := j.obrot_w_ruchu * budzet
		j.kurs = docel if absf(roz) <= maks_obr else wrapf(j.kurs + signf(roz) * maks_obr, -PI, PI)
		var droga := j.predkosc * budzet
		if droga >= dl:
			j.pozycja = punkt; budzet -= dl / maxf(j.predkosc, 1e-6); j.przebyta_droga += dl
		else:
			j.pozycja += d / dl * droga; budzet = 0.0; j.przebyta_droga += droga


## Wysokość jednostki (na powierzchni terenu).
func wysokosc(j: JednostkaSym) -> float:
	return mapa.wysokosc(j.pozycja)


func lista() -> Array:
	var out: Array = []
	for id in _kolejnosc: out.append(jednostki[id])
	return out


## Skrót stanu (porównania deterministyczności i niezależności od FPS).
func skrot_stanu() -> String:
	var s := ""
	for id in _kolejnosc:
		var j: JednostkaSym = jednostki[id]
		s += "%d:%.6f,%.6f,%.6f,%d;" % [id, j.pozycja.x, j.pozycja.y, j.kurs, j.ruch]
	return s


func _log(t: String) -> void:
	dziennik.append("[takt %d] %s" % [takt, t])
	if dziennik.size() > 200: dziennik.pop_front()
	ImporterEE.zglos("debug", "symulacja", t)
