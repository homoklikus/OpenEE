class_name SterowanieRTS
extends Node
## Sterowanie użytkownika (etap 5): LPM – zaznaczenie jednostki / odznaczenie (puste miejsce), PPM – rozkaz ruchu
## dla zaznaczonej jednostki, P – podgląd trasy, spacja – pauza symulacji. Zamienia wejście na rozkazy Symulacja;
## logika trafień w Zaznaczanie (bez węzłów).

signal zmiana_zaznaczenia(id: int)
signal rozkaz(id: int, cel: Vector2)

var sym: Symulacja
var widok: WidokJednostek
var zegar: ZegarSymulacji
var kamera: Camera3D
var komunikat := ""


func _init(s: Symulacja, w: WidokJednostek, z: ZegarSymulacji, k: Camera3D) -> void:
	sym = s; widok = w; zegar = z; kamera = k
	name = "SterowanieRTS"


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_LEFT:
			klik_lewy(e.position)
		elif e.button_index == MOUSE_BUTTON_RIGHT:
			klik_prawy(e.position)
	elif e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_P: widok.pokaz_trasy = not widok.pokaz_trasy
		elif e.keycode == KEY_SPACE: zegar.pauza = not zegar.pauza


func _promien(ekran: Vector2) -> Array:
	return [kamera.project_ray_origin(ekran), kamera.project_ray_normal(ekran)]


func klik_lewy(ekran: Vector2) -> int:
	var r := _promien(ekran)
	var w := Zaznaczanie.klik(sym, r[0], r[1])
	widok.zaznaczone.clear()
	if int(w.jednostka) >= 0:
		widok.zaznaczone.append(int(w.jednostka))
		komunikat = "zaznaczono jednostkę %d" % w.jednostka
	else:
		komunikat = "brak zaznaczenia"
	zmiana_zaznaczenia.emit(int(w.jednostka))
	return int(w.jednostka)


func klik_prawy(ekran: Vector2) -> bool:
	if widok.zaznaczone.is_empty():
		komunikat = "najpierw zaznacz jednostkę (LPM)"; return false
	var r := _promien(ekran)
	var te := Zaznaczanie.teren(sym.mapa, r[0], r[1])
	if te.is_empty():
		komunikat = "kliknięcie poza terenem"; return false
	for id in widok.zaznaczone:
		sym.rozkaz_ruchu(id, te.punkt)
		rozkaz.emit(id, te.punkt)
	komunikat = "rozkaz ruchu do (%.1f, %.1f)" % [te.punkt.x, te.punkt.y]
	return true
