class_name PolitykaRuchu
extends RefCounted
## Polityka przechodniości dla rodzaju jednostki – wymienna (etap 5, FORMATY_ETAP5 §2).
##
## Źródło [D]: dbobjects ma dla każdego obiektu 18 flag nawierzchni (pola od „dbterrain.dat Grass, Snow”):
##   0 Grass/Snow, 1 Elevation: Deep water, 2 Rock/Stones/Artificial, 10 Asphalt, 11 Elevation: cliffs,
##   12 Elevation: Shallow water, 14 Sand, 15 Space (pozostałe – nieopisane w schemacie).
## Przykłady z danych: obywatel/falanga – woda głęboka 0, klify 0, woda płytka 1; okręty – trawa 0, woda głęboka 1.
## Przybliżenie OpenEE [H]: wszystkie pola lądowe traktowane jak kategoria 0 (trawa) – rozróżnienie nawierzchni lądu
## (skały, asfalt, piasek) wymaga ustalenia odwzorowania typów terenu na te flagi; brak progu nachylenia (gra może go
## stosować – nieustalone), wysokość wpływa tylko na koszt trasy.

const FLAGA_TRAWA := 0
const FLAGA_GLEBOKA := 1
const FLAGA_KLIFY := 11
const FLAGA_PLYTKA := 12

var nazwa: String = ""
var flagi := PackedByteArray()      # 18 flag z dbobjects
var przez_drzewa := false           # dbobjects „Can walk through trees”
var koszt_wysokosci := 1.0          # [H] dodatkowy koszt za różnicę wysokości (na jednostkę wysokości)
var _dozw := PackedByteArray()      # kategoria MapaNawigacji → 0/1


func _init(f: PackedByteArray = PackedByteArray([1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 0, 0, 0]), drzewa := false, n := "lądowa") -> void:
	flagi = f; przez_drzewa = drzewa; nazwa = n
	_dozw = PackedByteArray([0, 0, 0, 0, 0])
	_dozw[MapaNawigacji.LAD] = 1 if flagi[FLAGA_TRAWA] else 0
	_dozw[MapaNawigacji.PLYTKA] = 1 if flagi[FLAGA_PLYTKA] else 0
	_dozw[MapaNawigacji.GLEBOKA] = 1 if flagi[FLAGA_GLEBOKA] else 0
	_dozw[MapaNawigacji.KLIF] = 1 if flagi[FLAGA_KLIFY] else 0


## Polityka z rekordu dbobjects (słownik BazaDB – kolejność pól jak w układzie tabeli).
static func z_obiektu(ob: Dictionary) -> PolitykaRuchu:
	var klucze := ob.keys()
	var i0 := klucze.find("dbterrain.dat Grass, Snow")
	var f := PackedByteArray()
	if i0 < 0:
		return PolitykaRuchu.new()
	var w := ob.values()
	for i in 18: f.append(1 if int(w[i0 + i]) != 0 else 0)
	return PolitykaRuchu.new(f, int(ob.get("Can walk through trees", 0)) != 0, String(ob.get("Name", "")))


func dozwolona(kategoria: int) -> bool:
	return kategoria >= 0 and kategoria < _dozw.size() and _dozw[kategoria] == 1


## Klucz do pamięci podręcznej składowych spójności (polityki o tych samych dopuszczeniach dzielą składowe).
func klucz() -> String:
	return "%d%d%d%d|%d" % [_dozw[1], _dozw[2], _dozw[3], _dozw[4], 1 if przez_drzewa else 0]
