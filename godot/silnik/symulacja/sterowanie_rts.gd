class_name SterowanieRTS
extends Node
## Sterowanie użytkownika – reguły oryginalnego EE (etap 9, docs/MECHANIKA_RUCHU_EE.md § 2; logika w ZaznaczenieEE):
## * LPM na jednostce – zaznaczenie tylko jej; Shift + LPM – dodanie; Ctrl + LPM – usunięcie; LPM na pustym terenie –
##   odznaczenie,
## * przeciągnięcie LPM – ramka (zastępuje; Shift – dodaje; Ctrl – usuwa), podgląd ramki na ekranie,
## * PPM – rozkaz ruchu grupy (szyk EE, Symulacja.rozkaz_grupy) do punktu terenu; Shift + PPM – dopisanie punktu do
##   kolejki rozkazów,
## * przewijanie krawędzią ekranu nieaktywne podczas przeciągania ramki (jak w EE),
## * P – podgląd tras, spacja – pauza symulacji (rozkazy wydane w pauzie czekają w kolejce na następny takt).
## Rozkazy inne niż ruch (PPM na budynku, wrogu, zasobie) nie są odtwarzane – PPM zawsze wskazuje punkt terenu
## pod kursorem [N: etap 9 obejmuje tylko ruch].

signal zmiana_zaznaczenia(id: int)
signal rozkaz(id: int, cel: Vector2)

const PROG_RAMKI := 6.0            # px – mniejsze przesunięcie traktowane jako kliknięcie [H]

var sym: Symulacja
var widok: WidokJednostek
var zegar: ZegarSymulacji
var kamera: Camera3D
var komunikat := ""
var zaznaczenie := ZaznaczenieEE.new()
var gracz: int = -1                # właściciel jednostek wybieranych ramką (−1 – wszyscy)
var _start_ramki := Vector2.INF
var _ramka: ReferenceRect


func _init(s: Symulacja, w: WidokJednostek, z: ZegarSymulacji, k: Camera3D) -> void:
	sym = s; widok = w; zegar = z; kamera = k
	name = "SterowanieRTS"


func _ready() -> void:
	var warstwa := CanvasLayer.new(); add_child(warstwa)
	_ramka = ReferenceRect.new()
	_ramka.editor_only = false; _ramka.border_color = Color(1, 1, 1, 0.9); _ramka.border_width = 1.0
	_ramka.mouse_filter = Control.MOUSE_FILTER_IGNORE; _ramka.visible = false
	warstwa.add_child(_ramka)


static func modyfikator(e: InputEventWithModifiers) -> String:
	if e.shift_pressed: return "shift"
	if e.ctrl_pressed: return "ctrl"
	return ""


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_start_ramki = e.position
				_ramka_kamery(true)
			elif _start_ramki != Vector2.INF:
				if _start_ramki.distance_to(e.position) >= PROG_RAMKI:
					ramka(Rect2(_start_ramki, e.position - _start_ramki), modyfikator(e))
				else:
					klik_lewy(e.position, modyfikator(e))
				_start_ramki = Vector2.INF
				_ramka_kamery(false)
				if _ramka: _ramka.visible = false
		elif e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
			klik_prawy(e.position, e.shift_pressed)
	elif e is InputEventMouseMotion and _start_ramki != Vector2.INF and _ramka:
		var r := Rect2(_start_ramki, e.position - _start_ramki).abs()
		_ramka.position = r.position; _ramka.size = r.size
		_ramka.visible = r.size.length() >= PROG_RAMKI
	elif e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_P: widok.pokaz_trasy = not widok.pokaz_trasy
		elif e.keycode == KEY_SPACE: zegar.pauza = not zegar.pauza


## EE: podczas przeciągania ramki zaznaczenia przewijanie krawędzią jest wyłączone [P: etap 10] – kamera dostaje
## informację o ramce (kamera produkcyjna ma właściwość `ramka_aktywna`).
func _ramka_kamery(aktywna: bool) -> void:
	if kamera and "ramka_aktywna" in kamera:
		kamera.ramka_aktywna = aktywna


func _promien(ekran: Vector2) -> Array:
	return [kamera.project_ray_origin(ekran), kamera.project_ray_normal(ekran)]


func _odswiez() -> void:
	widok.zaznaczone.clear()
	for id in zaznaczenie.ids:
		if sym.jednostki.has(id): widok.zaznaczone.append(id)
	zaznaczenie.ids = widok.zaznaczone.duplicate()


func klik_lewy(ekran: Vector2, mod: String = "") -> int:
	var r := _promien(ekran)
	var w := Zaznaczanie.klik(sym, r[0], r[1])
	zaznaczenie.ids = widok.zaznaczone.duplicate()
	zaznaczenie.klik(int(w.jednostka), mod)
	_odswiez()
	komunikat = "zaznaczono: %d" % widok.zaznaczone.size() if not widok.zaznaczone.is_empty() else "brak zaznaczenia"
	zmiana_zaznaczenia.emit(int(w.jednostka))
	return int(w.jednostka)


func ramka(r: Rect2, mod: String = "") -> Array:
	var w := ZaznaczenieEE.w_prostokacie(sym, r, func(p: Vector3): return kamera.unproject_position(p), gracz)
	zaznaczenie.ids = widok.zaznaczone.duplicate()
	zaznaczenie.ramka(w, mod)
	_odswiez()
	komunikat = "zaznaczono ramką: %d" % widok.zaznaczone.size()
	zmiana_zaznaczenia.emit(widok.zaznaczone[0] if not widok.zaznaczone.is_empty() else -1)
	return w


func klik_prawy(ekran: Vector2, dolacz := false) -> bool:
	if widok.zaznaczone.is_empty():
		komunikat = "najpierw zaznacz jednostki (LPM lub ramka)"; return false
	var r := _promien(ekran)
	var te := Zaznaczanie.teren(sym.mapa, r[0], r[1])
	if te.is_empty():
		komunikat = "kliknięcie poza terenem"; return false
	sym.rozkaz_grupy(widok.zaznaczone.duplicate(), te.punkt, dolacz)
	for id in widok.zaznaczone: rozkaz.emit(id, te.punkt)
	komunikat = "rozkaz ruchu%s (%d jedn.) do (%.1f, %.1f)" % [" – kolejka" if dolacz else "", widok.zaznaczone.size(),
		te.punkt.x, te.punkt.y]
	return true
