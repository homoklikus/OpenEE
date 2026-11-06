extends Camera3D
## Produkcyjna kamera RTS – wierna kamerze oryginalnego EE (ModelKameryEE, pomiary z 2026-11-06):
## stały kierunek patrzenia i pochylenie 35° (bez obrotu), 21 poziomów zoomu kółkiem myszy (skok o poziom),
## przesuwanie strzałkami i myszą przy krawędzi okna z prędkością zależną od zoomu, ognisko ograniczone do mapy.
## Wolna kamera (obrót Q/E, WASD, środkowy przycisk, R, dowolny zoom) – res://sceny/kamera_diagnostyczna.gd.
##
## Zgodność z wcześniejszym interfejsem: `cel`, `odleglosc`, `ustaw(cel, odl)`, `_aktualizuj()` – odległość jest
## dociągana do najbliższego poziomu zoomu EE.

var cel := Vector3.ZERO            # ognisko (Godot; punkt mapy EE = UkladEE.mapa(cel)), wysokość = teren + 0,4
var poziom := ModelKameryEE.POZIOM_STARTOWY
var odleglosc := ModelKameryEE.odleglosc(ModelKameryEE.POZIOM_STARTOWY)
var granice := Rect2()             # zakresy (x+z, x−z) ogniska; pusty = bez ograniczenia
var wysokosc_terenu: Callable      # (Vector2) -> float; pusty = cel.y bez zmian
var przesuwanie_krawedzia := true  # wyłączane w testach i przy zrzutach (deterministyczny kadr)
var _mysz_w_oknie := false         # przesuwanie krawędzią dopiero po ruchu myszy w oknie (nowe okno zgłasza (0, 0))
var _odl_ostatnia := odleglosc


func _ready() -> void:
	keep_aspect = Camera3D.KEEP_WIDTH
	fov = ModelKameryEE.FOV_POZIOMY_ST
	near = 0.05
	far = 400.0


## Ustawia ognisko i odległość (dociąganą do poziomu zoomu EE).
func ustaw(c: Vector3, odl: float) -> void:
	cel = c
	poziom = ModelKameryEE.poziom_dla_odleglosci(odl)
	_aktualizuj()


func ustaw_poziom(p: int) -> void:
	poziom = clampi(p, 0, ModelKameryEE.POZIOMOW - 1)
	_aktualizuj()


## Granice z zakresów kolumn wierszy mapy (ScenariuszEE.teren.rp) – ognisko nie wyjdzie poza romb mapy.
func ustaw_granice_z_mapy(wiersze_zakresy: Array) -> void:
	granice = ModelKameryEE.granice_z_pol(wiersze_zakresy)
	_aktualizuj()


func _aktualizuj() -> void:
	# zgodność: ktoś mógł ustawić `odleglosc` bezpośrednio (np. kamera podążająca w rts_test)
	if not is_equal_approx(odleglosc, _odl_ostatnia):
		poziom = ModelKameryEE.poziom_dla_odleglosci(odleglosc)
	var p := ModelKameryEE.ogranicz(UkladEE.mapa(cel), granice)     # ognisko w układzie mapy EE
	var y := cel.y
	if wysokosc_terenu.is_valid():
		y = float(wysokosc_terenu.call(p)) + ModelKameryEE.WYSOKOSC_OGNISKA
	cel = UkladEE.godot(p, y)
	odleglosc = ModelKameryEE.odleglosc(poziom)
	_odl_ostatnia = odleglosc
	var oko := ModelKameryEE.oko(cel, poziom)
	position = oko
	look_at(cel if not oko.is_equal_approx(cel) else cel + ModelKameryEE.kierunek_godot(), Vector3.UP)


## Przesunięcie ogniska o wektor ekranowy (x = prawo, y = dalej) w polach.
func przesun(ekran: Vector2) -> void:
	var d := ModelKameryEE.os_prawo_mapy() * ekran.x + ModelKameryEE.os_dalej_mapy() * ekran.y
	cel = UkladEE.godot(UkladEE.mapa(cel) + d, cel.y)
	_aktualizuj()


func kierunek_klawiszy() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_UP): v.y += 1
	if Input.is_key_pressed(KEY_DOWN): v.y -= 1
	if Input.is_key_pressed(KEY_LEFT): v.x -= 1
	if Input.is_key_pressed(KEY_RIGHT): v.x += 1
	return v


func kierunek_krawedzi() -> Vector2:
	if not przesuwanie_krawedzia or not _mysz_w_oknie or not get_window().has_focus():
		return Vector2.ZERO
	var vp := get_viewport()
	var m := vp.get_mouse_position(); var r := vp.get_visible_rect().size
	var s := float(ModelKameryEE.STREFA_KRAWEDZI_PX)
	var v := Vector2.ZERO
	if m.x <= s: v.x -= 1
	elif m.x >= r.x - 1 - s: v.x += 1
	if m.y <= s: v.y += 1
	elif m.y >= r.y - 1 - s: v.y -= 1
	return v


func _process(dt: float) -> void:
	var v := kierunek_klawiszy()
	if v == Vector2.ZERO:
		v = kierunek_krawedzi()
	if v != Vector2.ZERO:
		# kierunki składane bez normalizacji (ukos szybszy o √2) – zachowanie oryginału przy dwóch klawiszach [N]
		przesun(v * ModelKameryEE.predkosc(poziom) * dt)


func _notification(co: int) -> void:
	if co == NOTIFICATION_WM_MOUSE_EXIT or co == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_mysz_w_oknie = false


func _input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		_mysz_w_oknie = true


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP: ustaw_poziom(poziom - 1)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN: ustaw_poziom(poziom + 1)


func opis() -> Dictionary:
	return {"ognisko": [snappedf(cel.x, 0.001), snappedf(cel.y, 0.001), snappedf(cel.z, 0.001)], "poziom": poziom,
		"odleglosc": snappedf(odleglosc, 0.001), "pochylenie_st": ModelKameryEE.POCHYLENIE_ST,
		"fov_poziomy_st": fov, "keep_aspect": keep_aspect}
