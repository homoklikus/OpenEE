class_name ModelKameryEE
extends RefCounted
## Model kamery RTS oryginalnego Empire Earth: The Art of Conquest – parametry zmierzone w pamięci działającej gry
## (narzędzia MCP ee_kamera / ee_kamera_ustaw, 2026-11-06, mapa Riverlands 100×100, okno 3440×1440, Wine/DXVK).
## Oznaczenia: [P] potwierdzone powtarzalnymi pomiarami, [W] wniosek z ograniczonych pomiarów, [H] przybliżenie OpenEE,
## [N] nieustalone. Szczegóły i dane: docs/MECHANIKA_KAMERY_EE.md (etap 10), RAPORT_KAMERA_EE_OPENEE.md.
##
## Wielkości kamery są wyrażone w układzie świata EE (x = kolumna, y = wiersz, z = góra); do Godota przechodzą
## wyłącznie przez UkladEE (etap 7: obrót bez odbicia – kadr OpenEE pokrywa się z kadrem EE, nie jest odbity).

## Kierunek patrzenia w płaszczyźnie mapy EE: (−1, +1)/√2 (azymut 135° od osi x) – stały, gra nie obraca kamery [P].
const KIERUNEK_MAPY := Vector2(-0.70710678, 0.70710678)
## Pochylenie osi widoku w dół od poziomu [P]: 35° (macierz kamery: sin = 0,5736, cos = 0,8192).
const POCHYLENIE_ST := 35.0
## Poziomy kąt widzenia [W]: 48,4° przy oknie 3440×1440 (obszar mapy 3440×1302). Etap 10: kadry EE i OpenEE przy tym
## samym ognisku i poziomie (Riverlands, poziomy 20 i 10, 8 punktów – flagi centrum miasta i jednostki): przy 50,4°
## (wartość z pierwszego badania, szerokość jednego budynku) obraz OpenEE był o 4–5 % mniejszy, przy 48,4° odchyłki
## poziome 1–8 px (ogniskowa ~3830 px). Pozostaje stałe przesunięcie pionowe ~21 px (środek rzutu EE niżej) [W] –
## nieodtworzone [N]. Zasada dla innych proporcji okna [N]: przyjęto stały kąt poziomy (Camera3D.KEEP_WIDTH) [H].
const FOV_POZIOMY_ST := 48.4
## Zoom: 21 poziomów (0 = najbliżej, 20 = najdalej), jedno kliknięcie kółka = jeden poziom, zmiana natychmiastowa
## w stanie gry i w kopiach macierzy renderera – bez wygładzania obrazu [P: etap 10, próbki co 19 ms]; punkt pod
## kursorem i modyfikatory (Shift/Ctrl/Alt) nie wpływają na zoom [P: etap 10, docs/MECHANIKA_KAMERY_EE.md § 2]. Odległość oko–ognisko: 29,7 przy poziomie 20, krok 1,49 [P]; poziom 0 – 0,1 (oko tuż nad
## ogniskiem; gra ogranicza tu wysokość oka do 0,4) [P].
const POZIOMOW := 21
const ODL_MAKS := 29.7
const KROK_ODL := 1.49
const ODL_MIN := 0.1
const POZIOM_STARTOWY := 20        # scenariusz zaczyna się przy największym oddaleniu [P]
## Ognisko kamery leży 0,4 nad terenem i nadąża za jego wysokością; teren poniżej zera (woda, depresje) liczy się
## jak 0 [P: etap 10, „Wojna trojańska”, 8 punktów, wysokości −0,8…4,3]. Wysokość terenu EE bywa wyższa od
## interpolacji dwuliniowej OpenEE o ≤ 0,23 [W] – reguła wygładzania terenu w EE nieustalona [N].
const WYSOKOSC_OGNISKA := 0.4
## Przesuwanie strzałkami: 15 + 30·(poziom/20) pól/s, liniowo z poziomem zoomu (15 / 30 / 45 przy poziomach
## 0 / 10 / 20) [P]; stała prędkość od pierwszej klatki, bez rozpędzania i wybiegu (1 s i 3 s ⇒ ta sama prędkość) [P].
const PREDKOSC_MIN := 15.0
const PREDKOSC_MAKS := 45.0
## Dwie strzałki: wektory się sumują bez normalizacji (ukos √2 szybciej), przeciwne się znoszą [P: etap 10].
##
## Przewijanie krawędzią ekranu [P: etap 10, § 3.2]: brak strefy o stałej szerokości – kursor stojący 0–30 px od
## krawędzi nie przewija; przewijanie włącza ruch myszy NA ZEWNĄTRZ okna, gdy kursor jest już na krawędzi (kursor
## zatrzymany, gra dostaje ruch względny), trwa, dopóki kursor zostaje na krawędzi, i ustaje po ruchu do wnętrza.
## Prędkość = 5/6 prędkości strzałek (12,5 / 25 / 37,5 pola/s). Podczas przeciągania ramki zaznaczenia wyłączone.
const WSP_PREDKOSCI_KRAWEDZI := 5.0 / 6.0
const PROG_KRAWEDZI_PX := 1.0      # kursor „na krawędzi”: ≤ 1 px od brzegu okna [H – w EE kursor stoi na 0 / W−1]
## Przesuwanie środkowym przyciskiem myszy [P: etap 10, § 3.3]: przytrzymanie i ruch myszy przesuwa ognisko
## w kierunku ruchu (mysz w prawo → kamera w prawo, w dół → w dół ekranu), Δ pól = Δ jednostek myszy × prędkość
## strzałek(poziom) / 640, bez bezwładności; kursor zatrzymany na czas przeciągania. Jednostka myszy EE (ruch
## względny DirectInput) ↔ piksel ruchu względnego Godota: 1 : 1 [H].
const DZIELNIK_SRODKOWEGO := 640.0


static func odleglosc(poziom: int) -> float:
	var p := clampi(poziom, 0, POZIOMOW - 1)
	return maxf(ODL_MIN, ODL_MAKS - KROK_ODL * float(POZIOMOW - 1 - p))


static func poziom_dla_odleglosci(odl: float) -> int:
	var najl := 0
	for p in POZIOMOW:
		if absf(odleglosc(p) - odl) < absf(odleglosc(najl) - odl):
			najl = p
	return najl


static func predkosc(poziom: int) -> float:
	return lerpf(PREDKOSC_MIN, PREDKOSC_MAKS, float(clampi(poziom, 0, POZIOMOW - 1)) / float(POZIOMOW - 1))


static func predkosc_krawedzi(poziom: int) -> float:
	return predkosc(poziom) * WSP_PREDKOSCI_KRAWEDZI


## Przesunięcie ekranowe (x = prawo, y = dalej) w polach dla ruchu myszy `rel` (piksele Godota, y w dół) przy
## wciśniętym środkowym przycisku.
static func przesuniecie_srodkowym(rel: Vector2, poziom: int) -> Vector2:
	return Vector2(rel.x, -rel.y) * predkosc(poziom) / DZIELNIK_SRODKOWEGO


## Wysokość ogniska nad wysokością terenu `h`.
static func wysokosc_ogniska(h: float) -> float:
	return maxf(0.0, h) + WYSOKOSC_OGNISKA


## Kierunek patrzenia w świecie EE (x, y, z): poziomo KIERUNEK_MAPY, w dół o POCHYLENIE_ST.
static func kierunek_ee() -> Vector3:
	var p := deg_to_rad(POCHYLENIE_ST)
	return Vector3(KIERUNEK_MAPY.x * cos(p), KIERUNEK_MAPY.y * cos(p), -sin(p)).normalized()


## Kierunek patrzenia w Godocie (jednostkowy) – przez UkladEE (jedyna konwersja osi).
static func kierunek_godot() -> Vector3:
	return UkladEE.wektor(kierunek_ee())


## Osie przesuwania na ekranie w płaszczyźnie mapy EE: „prawo” = (+1, +1)/√2 i „dalej” (strzałka w górę) =
## kierunek patrzenia (−1, +1)/√2 [Z: pomiar klawiszy w EE]. Prawo = przód × góra w świecie EE.
static func os_prawo_mapy() -> Vector2:
	var r := kierunek_ee().cross(Vector3(0, 0, 1)).normalized()
	return Vector2(r.x, r.y)


static func os_dalej_mapy() -> Vector2:
	return KIERUNEK_MAPY


## Położenie oka dla ogniska (Godot) i poziomu zoomu.
static func oko(ognisko: Vector3, poziom: int) -> Vector3:
	return ognisko - kierunek_godot() * odleglosc(poziom)


## Granice ogniska: w EE ognisko nie wychodzi poza obszar mapy (romb poprawnych pól) – zmierzone ograniczenie
## (x + y) ∈ [100, 300], (x − y) ∈ [−100, 100] dla mapy 100×100 [P]. Granice tu: zakresy u = x + y, v = x − y
## w układzie mapy EE, wyliczone z pól mapy. Prostokąt w osiach (u, v) = osie ekranu (prawo/dalej).
static func granice_z_pol(wiersze_zakresy: Array) -> Rect2:
	var umin := INF; var umax := -INF; var vmin := INF; var vmax := -INF
	for r in wiersze_zakresy.size():
		var w: Vector2i = wiersze_zakresy[r]
		if w.y < w.x:
			continue
		for c in [w.x, w.y + 1]:
			for rr in [r, r + 1]:
				umin = minf(umin, c + rr); umax = maxf(umax, c + rr)
				vmin = minf(vmin, c - rr); vmax = maxf(vmax, c - rr)
	if umin == INF:
		return Rect2()
	return Rect2(umin, vmin, umax - umin, vmax - vmin)


static func ogranicz(p: Vector2, g: Rect2) -> Vector2:
	if g.size == Vector2.ZERO:
		return p
	var u := clampf(p.x + p.y, g.position.x, g.end.x)
	var v := clampf(p.x - p.y, g.position.y, g.end.y)
	return Vector2((u + v) * 0.5, (u - v) * 0.5)
