class_name OdtwarzaczAnimacji
extends Node
## Stan animacji instancji – oddzielony od danych modelu (AnimacjaVAT/ModelCEM są współdzielone) – etap 4.
##
## Każdy kanał (instancja) ma: sekwencję (zakres klatek, tempo, pętla), fazę, prędkość i pauzę. Zmiana stanu
## zapisuje 4 liczby do celu (egzemplarz MultiMesh albo MeshInstance3D); odtwarzanie liczy GPU z globalnego
## czasu `czas_animacji` (jedno wywołanie na klatkę gry niezależnie od liczby jednostek).
## Stany logiczne (bezczynność, ruch, atak, śmierć…) wybiera się nazwą stanu z SekwencjeAnimacji – odwzorowanie
## gniazd dbgraphics na stany pochodzi z danych gry (SekwencjeAnimacji). Mechaniki ruchu/walki tu nie ma.

var czas: float = 0.0
var predkosc_globalna: float = 1.0
var pauza_globalna: bool = false
# kanały (struktura tablic – szybki dostęp przy tysiącach jednostek)
var _cel: Array = []           # MultiMesh albo MeshInstance3D
var _idx := PackedInt32Array() # indeks egzemplarza w MultiMesh
var _od := PackedInt32Array()
var _n := PackedInt32Array()   # liczba klatek (ujemna = jednorazowa)
var _tempo := PackedFloat32Array()   # klatki/s przy prędkości 1
var _pred := PackedFloat32Array()
var _faza_ref := PackedFloat32Array() # faza przy czas = 0 (z bieżącym tempem)
var _pauza := PackedByteArray()
var _sek: Array = []
var zapisow_stanu: int = 0     # licznik zmian (pomiary)


func _process(delta: float) -> void:
	krok(delta)


## Przesuwa zegar animacji (wywoływane z _process albo ręcznie w testach i pomiarach).
func krok(delta: float) -> void:
	if not pauza_globalna:
		czas += delta * predkosc_globalna
	RenderingServer.global_shader_parameter_set(&"czas_animacji", czas)


func liczba_kanalow() -> int:
	return _cel.size()


## Dodaje kanał dla egzemplarza MultiMesh (mm, i) albo węzła MeshInstance3D (i ignorowane). Zwraca id kanału.
func dodaj(cel: Object, i: int = 0) -> int:
	AnimacjaVAT.shader()      # rejestracja zmiennej globalnej przed pierwszym użyciem
	_cel.append(cel); _idx.append(i); _od.append(0); _n.append(1); _tempo.append(0.0); _pred.append(1.0)
	_faza_ref.append(0.0); _pauza.append(0); _sek.append({})
	return _cel.size() - 1


## Odtwarza sekwencję (słownik z SekwencjeAnimacji) od fazy `faza` (w klatkach; np. losowa dla rozproszenia).
## petla: -1 = jak w danych, 0/1 = wymuszenie.
func odtworz(id: int, sek: Dictionary, faza: float = 0.0, petla: int = -1) -> void:
	var n: int = maxi(int(sek.get("klatki", 1)), 1)
	var p: bool = bool(sek.get("petla", true)) if petla < 0 else petla == 1
	_sek[id] = sek
	_od[id] = int(sek.get("od", 0)); _n[id] = n if p else -n
	_tempo[id] = float(sek.get("klatki_na_s", 0.0))
	_ustaw_faze(id, faza)
	_zapisz(id)


## Statyczna klatka (np. model bez sekwencji).
func ustaw_klatke(id: int, klatka: int) -> void:
	odtworz(id, {"od": klatka, "klatki": 1, "klatki_na_s": 0.0, "petla": true})


func pauza(id: int, wl: bool) -> void:
	var f := faza(id)
	_pauza[id] = 1 if wl else 0
	_ustaw_faze(id, f); _zapisz(id)


func ustaw_predkosc(id: int, v: float) -> void:
	var f := faza(id)
	_pred[id] = v
	_ustaw_faze(id, f); _zapisz(id)


func tempo_efektywne(id: int) -> float:
	return 0.0 if _pauza[id] else _tempo[id] * _pred[id]


## Bieżąca faza kanału w klatkach (od początku sekwencji, bez zawijania).
func faza(id: int) -> float:
	return _faza_ref[id] + czas * tempo_efektywne(id)


## Stan dla shadera (Vector4) – patrz AnimacjaVAT.
func stan(id: int) -> Vector4:
	return Vector4(_od[id], _n[id], _faza_ref[id], tempo_efektywne(id))


## Klatki (a, b, udział) kanału w bieżącej chwili.
func klatki(id: int) -> Vector3:
	return AnimacjaVAT.klatki_dla(stan(id), czas)


func sekwencja(id: int) -> Dictionary:
	return _sek[id]


func _ustaw_faze(id: int, f: float) -> void:
	_faza_ref[id] = f - czas * tempo_efektywne(id)


func _zapisz(id: int) -> void:
	zapisow_stanu += 1
	var st := stan(id)
	var c: Object = _cel[id]
	if c is MultiMesh:
		(c as MultiMesh).set_instance_custom_data(_idx[id], Color(st.x, st.y, st.z, st.w))
	elif c is GeometryInstance3D:
		(c as GeometryInstance3D).set_instance_shader_parameter(&"anim_stan", st)
