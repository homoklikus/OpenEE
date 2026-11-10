class_name SymulacjaCore
extends RefCounted
## Etap 36: model widoku symulacji OpenEE Core (C++, GDExtension `OpenEESymulacja`) dla scen Godota.
## NIE symuluje: każdy krok() to jeden takt Core (`takt(1)`), po którym stan jednostek jest tylko odczytywany
## (`stan_jednostek`, `zdarzenia_walki_od`) i przepisywany do obiektów JednostkaSym, których używają istniejące
## warstwy prezentacji (WidokJednostek, SterowanieRTS, Zaznaczanie). Rozkazy gracza idą wprost do Core
## (`rozkaz_ruchu`, `rozkaz_ataku`). Mapa wysokości (MapaNawigacji) służy wyłącznie do rysowania i do wskazania
## punktu terenu myszą – przejezdność, trasy, kolizje i walka są w Core.
##
## Krok czasu rzeczywistego: takty EE przychodzą porcjami po 15 co 350 ms (42,857/s), każdy = 34,09 ms czasu gry
## (G = 1,5) – docs/titan/zegar_symulacji.md [P]. KROK = 0,35 / 15 s.

const KROK := 0.35 / 15.0

var core: Object                       # OpenEESymulacja
var mapa: MapaNawigacji                # tylko wysokości do renderu i wskazania terenu
var jednostki := {}                    # id Core → JednostkaSym (model widoku)
var gracz_jednostki := {}              # id → gracz
var hp := {}                           # id → HP
var hp_max := {}                       # id → HP maksymalne
var stan := {}                         # id → numer stanu .tai
var cel_walki := {}                    # id → id celu (0 – brak)
var zdarzenia: Array = []              # zdarzenia ostatniego taktu dla warstw prezentacji (animacja, walka)
var takt: int = 0
var gracz_lokalny := 1                 # rozkazy przyjmowane tylko dla jednostek tego gracza
var _indeks_zdarzen := 0
var _anim := {}                        # id → ostatni stan animacji
var czas_taktow_us := 0


func _init(c: Object, m: MapaNawigacji) -> void:
	core = c
	mapa = m


## Rejestruje jednostkę już dodaną do Core (id z `dodaj_jednostke`) w modelu widoku.
func zarejestruj(id: int, gracz: int, typ: int, promien: float, nazwa: String = "") -> JednostkaSym:
	var j := JednostkaSym.new()
	j.id = id; j.typ = typ; j.wlasciciel = gracz; j.nazwa = nazwa; j.promien = promien
	jednostki[id] = j
	gracz_jednostki[id] = gracz
	_odczytaj_wszystko()
	j.pozycja_poprz = j.pozycja; j.kurs_poprz = j.kurs
	return j


## Jeden takt Core i odczyt stanu.
func krok() -> void:
	var t0 := Time.get_ticks_usec()
	zdarzenia.clear()
	for id in jednostki:
		var j: JednostkaSym = jednostki[id]
		j.pozycja_poprz = j.pozycja; j.kurs_poprz = j.kurs
	takt = int(core.takt(1))
	_odczytaj_wszystko()
	for e in core.zdarzenia_walki_od(_indeks_zdarzen):
		_indeks_zdarzen = int(e["indeks"]) + 1
		zdarzenia.append({"typ": "walka", "rodzaj": String(e["rodzaj"]), "kto": int(e["kto"]), "cel": int(e["cel"]),
			"wartosc": int(e["wartosc"]), "takt": int(e["takt"])})
	czas_taktow_us = Time.get_ticks_usec() - t0


func _odczytaj_wszystko() -> void:
	for d in core.stan_jednostek():
		var id := int(d["id"])
		var j: JednostkaSym = jednostki.get(id)
		if j == null: continue
		j.pozycja = Vector2(float(d["x"]), float(d["y"]))
		j.kurs = float(d["kurs"])
		var st := int(d["stan"])
		stan[id] = st
		hp[id] = int(d.get("hp", 0))
		hp_max[id] = maxi(int(d.get("hp_max", 1)), 1)
		cel_walki[id] = int(d.get("cel", 0))
		var v := float(d["v"])
		j.ruch = JednostkaSym.Ruch.IDZIE if absf(v) > 1e-6 else JednostkaSym.Ruch.STOI
		var a := _stan_animacji(st, v)
		if _anim.get(id, "") != a:
			_anim[id] = a
			j.stan_animacji = a
			zdarzenia.append({"typ": "animacja", "id": id, "stan": a})


## Stan animacji z numeru stanu .tai i prędkości Core (prezentacja; numery stanów – skrypty .tai EE).
static func _stan_animacji(st: int, v: float) -> String:
	if _umiera(st): return "smierc"                                   # Dying
	if st == 2001 or st == 2021: return "atak"                        # AttackEnemyUnit (cykl ataku)
	if absf(v) > 1e-6: return "ruch"
	return "bezczynnosc"


func zywa(id: int) -> bool:
	return jednostki.has(id) and int(hp.get(id, 0)) > 0 and not _umiera(int(stan.get(id, 0)))


## Stany umierania skryptu .tai EE: Dying 6000 i jego kontynuacje 6001–6003 (symulacja.cpp, etap 31).
static func _umiera(st: int) -> bool:
	return st >= 6000 and st <= 6003


## Jednostki do zaznaczania i rysowania pierścieni – tylko żywe (zwłoki nie są wybieralne).
func lista() -> Array:
	var w: Array = []
	for id in jednostki:
		if zywa(id): w.append(jednostki[id])
	return w


func wysokosc(j: JednostkaSym) -> float:
	return mapa.wysokosc(j.pozycja)


## Wróg wg dyplomacji Core: różni gracze są wrogami (Swiat::wrogowie – domyślnie). Martwy cel → false
## (EEAMouseClick: PPM na HP ≤ 0 daje ruch – etap 35).
func czy_wrog(gracz: int, id: int) -> bool:
	return zywa(id) and gracz >= 0 and int(gracz_jednostki.get(id, -1)) != gracz


## PPM w teren: rozkaz ruchu każdej zaznaczonej jednostki do punktu (Core: kolejka celów, Shift = dopisanie).
## Kurs końcowy celu = kąt szyku liczony w Core z zaznaczenia w chwili kliknięcia (EEUICCommandUnits 0x64138B,
## etap 37). Szyk grupy EE nie jest jeszcze w Core [N] – wszystkie jednostki dostają ten sam punkt.
func rozkaz_grupy(ids: Array, cel: Vector2, dolacz := false) -> void:
	var wlasne: Array = ids.filter(func(i): return _wlasna(int(i)))
	if wlasne.is_empty(): return
	var kat: float = core.kat_rozkazu(wlasne, cel.x, cel.y)
	for id in wlasne:
		core.rozkaz_ruchu(int(id), cel.x, cel.y, kat, dolacz)


## PPM na wrogu: rozkaz ataku (EEUGAttackUnit w Core). Zwraca liczbę jednostek, które go przyjęły.
func rozkaz_ataku_grupy(ids: Array, cel: int, _dolacz := false) -> int:
	var n := 0
	if not zywa(cel): return 0          # EEAMouseClick: HP celu ≤ 0 → nie atak (etap 35)
	for id in ids:
		if _wlasna(int(id)) and core.rozkaz_ataku(int(id), cel):
			n += 1
	return n


func _wlasna(id: int) -> bool:
	return zywa(id) and int(gracz_jednostki.get(id, -1)) == gracz_lokalny


## Żywe jednostki gracza.
func liczba_zywych(gracz: int) -> int:
	var n := 0
	for id in jednostki:
		if int(gracz_jednostki[id]) == gracz and zywa(id): n += 1
	return n


## Skrót stanu do porównań determinizmu (pozycje, kursy, HP, stany co takt).
func skrot_stanu() -> String:
	var t := PackedStringArray()
	var ids := jednostki.keys(); ids.sort()
	for id in ids:
		var j: JednostkaSym = jednostki[id]
		t.append("%d:%.5f,%.5f,%.5f,%d,%d" % [id, j.pozycja.x, j.pozycja.y, j.kurs, int(hp.get(id, 0)), int(stan.get(id, 0))])
	return ",".join(t).sha256_text().left(16)
