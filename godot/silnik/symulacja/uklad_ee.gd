class_name UkladEE
extends RefCounted
## Jedyna warstwa konwersji współrzędnych Empire Earth ↔ Godot (etap 7, RAPORT_UKLAD_WSPOLRZEDNYCH_OPENEE.md).
##
## Świat EE: x = kolumna, y = wiersz, z = góra (układ prawoskrętny – tak gra pokazuje mapę na ekranie: oś x biegnie
## w prawo-w-dół, oś y w prawo-w-górę, x → y przeciwnie do ruchu wskazówek zegara [Z: pomiar kamery EE i rzuty punktów
## kontrolnych scenariusza „Żołnierze dla Rzymu”]).
## Godot (prawoskrętny, Y w górę): W(x, y, z) = (x, z, −y) – OBRÓT (wyznacznik +1), ta sama macierz co CEM → Godot
## (ModelCEM.P), więc świat i siatki modeli przechodzą przez tę samą konwersję.
## Do etapu 6 świat był mapowany przez C(x, y, z) = (x, z, y) – odbicie (wyznacznik −1); mapa w OpenEE była lustrzanym
## odbiciem mapy EE (raport etapu 7 § 1).
##
## Wszystkie miejsca silnika przeliczające współrzędne EE ↔ Godot używają funkcji tej klasy (bez lokalnych zmian znaków).
##
## Baza obiektu w Godocie = W · R · L · P⁻¹: R – obrót z macierzy GETransformation rekordu (świat EE), P – układ siatki
## z importera, L – konwencja osi modelu CEM względem świata EE (L = I: model w tym samym układzie co świat
## [Z: etap 7 – orientacja asymetrycznych budynków i kierunek chodu jednostek zgodne z grą]).
## Kurs jednostki: kąt θ obrotu wokół osi z świata EE. Przód modelu = +Y modelu (etap 5), więc kierunek ruchu
## d = (Δkolumna, Δwiersz) = Rz(θ)·(0, 1) ⇒ θ = atan2(−dx, dy).

## W: kolumny = obrazy osi x, y, z świata EE w Godocie.
const W := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
## Konwencja osi modelu CEM względem świata EE (diagnostyka etapu 7 pozwala ją podmienić: --uklad-modelu=I|D|F).
static var L := Basis.IDENTITY


## Pozycja Godota z punktu mapy EE (x = kolumna, y = wiersz) i wysokości.
static func godot(p: Vector2, h: float) -> Vector3:
	return Vector3(p.x, h, -p.y)


## Punkt mapy EE (x = kolumna, y = wiersz) z pozycji Godota (wysokość pomijana).
static func mapa(v: Vector3) -> Vector2:
	return Vector2(v.x, -v.z)


## Wektor świata EE (x, y, z) → Godot.
static func wektor(v: Vector3) -> Vector3:
	return Vector3(v.x, v.z, -v.y)


## Wektor Godota → świat EE (x, y, z).
static func wektor_ee(v: Vector3) -> Vector3:
	return Vector3(v.x, -v.z, v.y)


## Kierunek w płaszczyźnie mapy EE → poziomy wektor Godota.
static func kierunek(d: Vector2) -> Vector3:
	return Vector3(d.x, 0.0, -d.y)


## Macierz 3×3 (wiersze) świata EE → Basis (te same osie, bez konwersji).
static func basis_ee(R: Array) -> Basis:
	return Basis(Vector3(R[0][0], R[1][0], R[2][0]), Vector3(R[0][1], R[1][1], R[2][1]), Vector3(R[0][2], R[1][2], R[2][2]))


## Baza Godota obiektu z macierzy obrotu R (3×3, wiersze) świata EE: W · R · L · P⁻¹.
static func baza(R: Array) -> Basis:
	return W * basis_ee(R) * L * ModelCEM.P.inverse()


## Macierz R z 64 bajtów GETransformation (16 f32 wierszami).
static func R_z_rekordu(tr: PackedByteArray) -> Array:
	if tr.size() != 64:
		return [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]
	return [[tr.decode_float(0), tr.decode_float(4), tr.decode_float(8)],
		[tr.decode_float(16), tr.decode_float(20), tr.decode_float(24)],
		[tr.decode_float(32), tr.decode_float(36), tr.decode_float(40)]]


## Pozycja (x, y) mapy EE z rekordu GETransformation (t[3], t[7]); brak macierzy – środek pola.
static func pozycja_z_rekordu(tr: PackedByteArray, pole_x: int, pole_y: int) -> Vector2:
	if tr.size() == 64:
		return Vector2(tr.decode_float(12), tr.decode_float(28))
	return Vector2(pole_x + 0.5, pole_y + 0.5)


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


## Różnica kątów w przedziale (−π, π].
static func roznica_katow(a: float, b: float) -> float:
	return wrapf(a - b, -PI, PI)


## Diagnostyka: konwencja osi modelu (I – jak świat, D – odbita oś y modelu, F – odbicie względem płaszczyzny
## kierunku patrzenia kamery EE). Tylko do porównań z oryginałem; produkcja: I.
static func ustaw_konwencje_modelu(nazwa: String) -> void:
	match nazwa.to_upper():
		"D": L = Basis(Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, 1))
		"F": L = Basis(Vector3(0, -1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1))
		_: L = Basis.IDENTITY
