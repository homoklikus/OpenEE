class_name MapaNawigacji
extends RefCounted
## Struktura nawigacyjna wyprowadzona z mapy scenariusza EE (etap 5, docs/FORMATY_ETAP5.md §2).
##
## Siatka pokrywa pola mapy (1 pole = 1 jednostka świata: x = kolumna, y = wiersz) z podziałem `podzial` komórek na
## bok pola (domyślnie 2 – przeszkody obiektów dokładniejsze niż pole). Każde pole ma kategorię nawierzchni:
##   POZA   – poza rombem mapy (granica) [D: zakres wierszy pól w kawałku 4],
##   LAD    – ląd,
##   PLYTKA – woda płytka, GLEBOKA – woda głęboka: z klas punktów 0xA8…0xAF w narożnikach pola; niskie bity klasy =
##            poziom głębokości (A8 ≈ −0,2 … AF < −1,6, wszystkie punkty wody poniżej 0) [D]; próg płytka/głęboka [H],
##   KLIF   – pole z teksturą klifu (dbcliffterrain) [D: tekstura; H: że odpowiada flagi „Elevation: cliffs”].
## Dopuszczalność kategorii dla jednostki określa PolitykaRuchu (flagi dbobjects). Przeszkody obiektów (budynki, drzewa…)
## zlicza się w komórkach (`blokady`), osobno dla drzew (`drzewa` – jednostki z „Can walk through trees” je pomijają).

enum { POZA = 0, LAD = 1, PLYTKA = 2, GLEBOKA = 3, KLIF = 4 }
const NAZWY := ["poza mapą", "ląd", "woda płytka", "woda głęboka", "klif"]
const KLASA_WODY_OD := 0xA8
const KLASA_WODY_DO := 0xAF

var wiersze: int = 0              # pól w pionie (y)
var kolumny: int = 0              # pól w poziomie (x)
var podzial: int = 2
var kategorie := PackedByteArray()   # na pole: wiersze × kolumny
var wysokosci := PackedFloat32Array() # na punkt: (wiersze + 1) × (kolumny + 1)
var blokady := PackedByteArray()     # na komórkę: liczba przeszkód (budynki, zasoby…)
var drzewa := PackedByteArray()      # na komórkę: liczba drzew
var prog_glebokosci := 1             # poziom ≥ prog → woda głęboka [H]; poziom = klasa − 0xA8
var opis := {}


## Mapa z tablic (testy, mapy syntetyczne). kat: PackedByteArray wiersze×kolumny, wys: (wiersze+1)×(kolumny+1) albo pusta.
static func z_tablic(w: int, k: int, kat: PackedByteArray, wys: PackedFloat32Array = PackedFloat32Array(), pd: int = 2) -> MapaNawigacji:
	var m := MapaNawigacji.new()
	m.wiersze = w; m.kolumny = k; m.podzial = maxi(1, pd)
	m.kategorie = kat.duplicate()
	if wys.size() == (w + 1) * (k + 1):
		m.wysokosci = wys.duplicate()
	else:
		m.wysokosci.resize((w + 1) * (k + 1))
	m._przydziel()
	return m


## Mapa z wczytanego scenariusza (teren musi być odczytany). tereny_klifow: ID terenów klifów z dbcliffterrain.
static func z_scenariusza(scn: ScenariuszEE, tereny_klifow: Array, skala_wysokosci: float = 1.0, pd: int = 2,
		prog: int = 1) -> MapaNawigacji:
	var m := MapaNawigacji.new()
	var N: int = scn.teren.N
	m.wiersze = N; m.kolumny = N; m.podzial = maxi(1, pd); m.prog_glebokosci = prog
	m.kategorie.resize(N * N)
	m.wysokosci.resize((N + 1) * (N + 1))
	var kl: PackedByteArray = scn.teren.klasa
	var wy: PackedFloat32Array = scn.teren.wysokosc
	var klasy_pkt := PackedByteArray(); klasy_pkt.resize((N + 1) * (N + 1))
	for r in N + 1:
		for c in N + 1:
			var i := scn.indeks_punktu(r, c)
			if i >= 0:
				m.wysokosci[r * (N + 1) + c] = wy[i] * skala_wysokosci
				klasy_pkt[r * (N + 1) + c] = kl[i]
	var klify := {}
	for t in tereny_klifow: klify[int(t)] = true
	var licz := [0, 0, 0, 0, 0]
	for r in N:
		for c in N:
			var ip := scn.indeks_pola(r, c)
			var kat := POZA
			if ip >= 0:
				if klify.has(int(scn.teren.teren[ip])):
					kat = KLIF
				else:
					var poziom := -1
					for d in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1)]:
						var k := int(klasy_pkt[(r + d.x) * (N + 1) + c + d.y])
						if k >= KLASA_WODY_OD and k <= KLASA_WODY_DO:
							poziom = maxi(poziom, k - KLASA_WODY_OD)
					if poziom < 0: kat = LAD
					elif poziom >= prog: kat = GLEBOKA
					else: kat = PLYTKA
			m.kategorie[r * N + c] = kat
			licz[kat] += 1
	m._przydziel()
	m.opis = {"pola": N * N, "kategorie": {"poza": licz[0], "lad": licz[1], "plytka": licz[2], "gleboka": licz[3], "klif": licz[4]},
		"podzial": m.podzial, "prog_glebokosci": prog}
	return m


func _przydziel() -> void:
	var n := wiersze * podzial * kolumny * podzial
	blokady.resize(n); blokady.fill(0)
	drzewa.resize(n); drzewa.fill(0)


func szer_komorek() -> int:
	return kolumny * podzial


func wys_komorek() -> int:
	return wiersze * podzial


func rozmiar_komorki() -> float:
	return 1.0 / podzial


## Komórka zawierająca punkt mapy (x = kolumna, y = wiersz); Vector2i(-1, -1) poza siatką.
func komorka(p: Vector2) -> Vector2i:
	var cx := int(floor(p.x * podzial)); var cy := int(floor(p.y * podzial))
	if cx < 0 or cy < 0 or cx >= szer_komorek() or cy >= wys_komorek():
		return Vector2i(-1, -1)
	return Vector2i(cx, cy)


func srodek(k: Vector2i) -> Vector2:
	return Vector2((k.x + 0.5) / podzial, (k.y + 0.5) / podzial)


func indeks(k: Vector2i) -> int:
	return k.y * szer_komorek() + k.x


func kategoria_komorki(k: Vector2i) -> int:
	if k.x < 0 or k.y < 0 or k.x >= szer_komorek() or k.y >= wys_komorek():
		return POZA
	return kategorie[(k.y / podzial) * kolumny + (k.x / podzial)]


func kategoria_punktu(p: Vector2) -> int:
	return kategoria_komorki(komorka(p))


## Wysokość terenu w punkcie mapy (interpolacja dwuliniowa punktów siatki – jak renderer terenu).
func wysokosc(p: Vector2) -> float:
	var c := clampi(int(floor(p.x)), 0, kolumny - 1); var r := clampi(int(floor(p.y)), 0, wiersze - 1)
	var fx := clampf(p.x - c, 0.0, 1.0); var fz := clampf(p.y - r, 0.0, 1.0)
	var k := kolumny + 1
	var h00 := wysokosci[r * k + c]; var h01 := wysokosci[r * k + c + 1]
	var h10 := wysokosci[(r + 1) * k + c]; var h11 := wysokosci[(r + 1) * k + c + 1]
	return lerpf(lerpf(h00, h01, fx), lerpf(h10, h11, fx), fz)


## Przeszkoda kołowa (środek w układzie mapy, promień w polach): blokuje komórki, których środek leży w kole.
func dodaj_przeszkode(srodek_p: Vector2, promien: float, drzewo: bool = false) -> int:
	var r := maxf(promien, 0.5 / podzial)
	var k0 := komorka(srodek_p - Vector2(r, r)); var k1 := komorka(srodek_p + Vector2(r, r))
	var x0 := clampi(int(floor((srodek_p.x - r) * podzial)), 0, szer_komorek() - 1)
	var x1 := clampi(int(floor((srodek_p.x + r) * podzial)), 0, szer_komorek() - 1)
	var y0 := clampi(int(floor((srodek_p.y - r) * podzial)), 0, wys_komorek() - 1)
	var y1 := clampi(int(floor((srodek_p.y + r) * podzial)), 0, wys_komorek() - 1)
	var n := 0
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var k := Vector2i(x, y)
			if srodek(k).distance_to(srodek_p) <= r:
				var i := indeks(k)
				if drzewo: drzewa[i] = mini(255, drzewa[i] + 1)
				else: blokady[i] = mini(255, blokady[i] + 1)
				n += 1
	if n == 0 and k0.x >= 0:
		var i := indeks(komorka(srodek_p))
		if drzewo: drzewa[i] = mini(255, drzewa[i] + 1)
		else: blokady[i] = mini(255, blokady[i] + 1)
		n = 1
	return n


## Czy komórka jest przechodnia dla polityki ruchu.
func przechodnia(k: Vector2i, pol: PolitykaRuchu) -> bool:
	var kat := kategoria_komorki(k)
	if not pol.dozwolona(kat):
		return false
	var i := indeks(k)
	if blokady[i] > 0:
		return false
	if drzewa[i] > 0 and not pol.przez_drzewa:
		return false
	return true


## Powód nieprzechodniości komórki (diagnostyka) albo "".
func powod(k: Vector2i, pol: PolitykaRuchu) -> String:
	var kat := kategoria_komorki(k)
	if not pol.dozwolona(kat):
		return "nawierzchnia: %s (niedozwolona dla jednostki)" % NAZWY[kat]
	var i := indeks(k)
	if blokady[i] > 0: return "przeszkoda (budynek/obiekt)"
	if drzewa[i] > 0 and not pol.przez_drzewa: return "drzewa"
	return ""
