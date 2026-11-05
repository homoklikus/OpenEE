class_name UkladEE
extends RefCounted
## Układy współrzędnych EE ↔ OpenEE (etapy 3–5).
## Świat EE: X = kolumna, Y = wiersz, Z = góra; Godot: (X, Z, Y) – macierz C. Siatki modeli z importera: (x, z, −y) – M.
## Baza obiektu w Godocie = C · R · M⁻¹, R – obrót z macierzy GETransformation rekordu [D, etap 3]; wyznacznik −1
## wynika z konwencji osi (skrętność obrazu – nierozstrzygnięta, FORMATY_ETAP4 §3.1).
## Kurs jednostki (etap 5): kąt θ obrotu wokół osi Z świata EE. Przód modelu = +Y modelu [D, etap 5: stopa podparta
## w animacji chodu przesuwa się w −Y (falanga, obywatel, kawaleria), punkt `attack` w klatkach ruchu/ataku/bezczynności
## leży po stronie +Y; obserwacja etapu 4 „−Y” wynikała z uśrednienia z klatkami śmierci – sprostowanie w FORMATY_ETAP5],
## więc kierunek ruchu d = (Δkolumna, Δwiersz) = Rz(θ)·(0, 1) ⇒ θ = atan2(−dx, dy).

const C := [[1.0, 0.0, 0.0], [0.0, 0.0, 1.0], [0.0, 1.0, 0.0]]
const MT := [[1.0, 0.0, 0.0], [0.0, 0.0, -1.0], [0.0, 1.0, 0.0]]


static func _mnoz(a: Array, b: Array) -> Array:
	var w := [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
	for i in 3:
		for j in 3:
			w[i][j] = a[i][0] * b[0][j] + a[i][1] * b[1][j] + a[i][2] * b[2][j]
	return w


## Baza Godota z macierzy obrotu R (3×3, wiersze) świata EE.
static func baza(R: Array) -> Basis:
	var B := _mnoz(C, _mnoz(R, MT))
	return Basis(Vector3(B[0][0], B[1][0], B[2][0]), Vector3(B[0][1], B[1][1], B[2][1]), Vector3(B[0][2], B[1][2], B[2][2]))


## Macierz R z 64 bajtów GETransformation (16 f32 wierszami).
static func R_z_rekordu(tr: PackedByteArray) -> Array:
	if tr.size() != 64:
		return [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]
	return [[tr.decode_float(0), tr.decode_float(4), tr.decode_float(8)],
		[tr.decode_float(16), tr.decode_float(20), tr.decode_float(24)],
		[tr.decode_float(32), tr.decode_float(36), tr.decode_float(40)]]


## Obrót wokół osi Z świata EE o kąt θ (radiany).
static func R_z_kata(theta: float) -> Array:
	var c := cos(theta); var s := sin(theta)
	return [[c, -s, 0.0], [s, c, 0.0], [0.0, 0.0, 1.0]]


## Kurs θ z macierzy rekordu (składowa obrotu wokół Z).
static func kat_z_R(R: Array) -> float:
	return atan2(R[1][0], R[0][0])


## Kurs θ dla kierunku ruchu w płaszczyźnie mapy (x = kolumna, y = wiersz).
static func kat_kierunku(d: Vector2) -> float:
	return atan2(-d.x, d.y)


## Wektor przodu jednostki (świat EE, płaszczyzna mapy) dla kursu θ.
static func przod(theta: float) -> Vector2:
	return Vector2(-sin(theta), cos(theta))


## Pozycja Godota z pozycji mapy (x = kolumna, y = wiersz) i wysokości.
static func godot(p: Vector2, h: float) -> Vector3:
	return Vector3(p.x, h, p.y)


## Różnica kątów w przedziale (−π, π].
static func roznica_katow(a: float, b: float) -> float:
	return wrapf(a - b, -PI, PI)
