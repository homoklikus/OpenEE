class_name ModelKameryEE
extends RefCounted
## Model kamery RTS oryginalnego Empire Earth: The Art of Conquest – parametry zmierzone w pamięci działającej gry
## (narzędzia MCP ee_kamera / ee_kamera_ustaw, 2026-11-06, mapa Riverlands 100×100, okno 3440×1440, Wine/DXVK).
## Oznaczenia: [Z] zmierzone, [W] wnioskowane z pomiarów, [N] nieznane – przyjęta wartość robocza.
## Szczegóły i dane: RAPORT_KAMERA_EE_OPENEE.md.
##
## Układ EE: x = kolumna, y = wiersz, z = góra. OpenEE (UkladEE): Godot (X, Y, Z) = (x, z, y). To odbicie
## (wyznacznik −1), więc świat OpenEE jest lustrzanym obrazem świata EE: kamera o tym samym kierunku patrzenia
## pokazuje kadr EE odbity lewo–prawo (dalej = dalej, prawo = lewo). Model trzyma się kierunku patrzenia
## (widać te same ściany budynków), a skrętność obrazu opisuje raport (§ „Odbicie”).

## Kierunek patrzenia w płaszczyźnie mapy EE: (−1, +1)/√2 (azymut 135° od osi x) – stały, gra nie obraca kamery [Z].
const KIERUNEK_MAPY := Vector2(-0.70710678, 0.70710678)
## Pochylenie osi widoku w dół od poziomu [Z]: 35° (macierz kamery: sin = 0,5736, cos = 0,8192).
const POCHYLENIE_ST := 35.0
## Poziomy kąt widzenia [W]: ogniskowa ~3650 px przy szerokości 3440 px (przesunięcie obrazu przy znanym
## przesunięciu kamery, dwa kierunki, ±4 %) → 2·atan(1720/3650) ≈ 50,4°. Zasada dla innych proporcji [N]:
## przyjęto stały kąt poziomy (Camera3D.KEEP_WIDTH).
const FOV_POZIOMY_ST := 50.4
## Zoom: 21 poziomów (0 = najbliżej, 20 = najdalej), jedno kliknięcie kółka = jeden poziom, zmiana natychmiastowa
## w stanie gry [Z]. Odległość oko–ognisko: 29,7 przy poziomie 20, krok 1,49 [Z]; poziom 0 – 0,1 (oko tuż nad
## ogniskiem; gra ogranicza tu wysokość oka do 0,4) [Z].
const POZIOMOW := 21
const ODL_MAKS := 29.7
const KROK_ODL := 1.49
const ODL_MIN := 0.1
const POZIOM_STARTOWY := 20        # scenariusz zaczyna się przy największym oddaleniu [Z]
## Ognisko kamery leży 0,4 nad terenem [Z na płaskiej mapie: z = 0,4 przy terenie ≈ 0]; nadążanie za wysokością
## terenu [W] (na mapie testowej teren był płaski – w górach nie mierzono).
const WYSOKOSC_OGNISKA := 0.4
## Przesuwanie strzałkami: 15 + 30·(poziom/20) pól/s, liniowo z poziomem zoomu (15 / 30 / 45 przy poziomach
## 0 / 10 / 20) [Z]; stała prędkość od pierwszej klatki, bez rozpędzania i wybiegu (1 s i 3 s ⇒ ta sama prędkość) [Z].
const PREDKOSC_MIN := 15.0
const PREDKOSC_MAKS := 45.0
## Przesuwanie myszą przy krawędzi ekranu: występuje [Z], prędkość i szerokość strefy [N] – przyjęto prędkość
## strzałek i strefę 3 px.
const STREFA_KRAWEDZI_PX := 3


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


## Kierunek patrzenia w Godocie (jednostkowy): poziomo KIERUNEK_MAPY (x → X, y → Z), w dół o POCHYLENIE_ST.
static func kierunek_godot() -> Vector3:
	var p := deg_to_rad(POCHYLENIE_ST)
	return Vector3(KIERUNEK_MAPY.x * cos(p), -sin(p), KIERUNEK_MAPY.y * cos(p)).normalized()


## Osie przesuwania na ekranie w płaszczyźnie mapy (Godot X, Z): „prawo” i „dalej” (strzałka w górę).
static func os_prawo_godot() -> Vector2:
	var f := kierunek_godot()
	var r := f.cross(Vector3.UP).normalized()
	return Vector2(r.x, r.z)


static func os_dalej_godot() -> Vector2:
	return KIERUNEK_MAPY


## Położenie oka dla ogniska (Godot) i poziomu zoomu.
static func oko(ognisko: Vector3, poziom: int) -> Vector3:
	return ognisko - kierunek_godot() * odleglosc(poziom)


## Granice ogniska: w EE ognisko nie wychodzi poza obszar mapy (romb poprawnych pól) – zmierzone ograniczenie
## (x + y) ∈ [100, 300], (x − y) ∈ [−100, 100] dla mapy 100×100 [Z]. Granice tu: zakresy u = x + y, v = x − y
## (Godot: x = X, y = Z) wyliczone z pól mapy. Prostokąt w osiach (u, v) = osie ekranu (prawo/dalej).
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
