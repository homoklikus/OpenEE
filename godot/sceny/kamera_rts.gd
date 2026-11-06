extends Camera3D
## Produkcyjna kamera RTS – wierna kamerze oryginalnego EE (ModelKameryEE; pomiary: docs/MECHANIKA_KAMERY_EE.md):
## stały kierunek patrzenia i pochylenie 35° (bez obrotu), 21 poziomów zoomu kółkiem myszy (skok o poziom, punkt pod
## kursorem bez znaczenia), przesuwanie strzałkami (suma kierunków), krawędzią ekranu (włączane pchaniem myszy poza
## krawędź, 5/6 prędkości strzałek, wyłączone podczas przeciągania ramki) i środkowym przyciskiem myszy (w kierunku
## ruchu myszy, kursor zatrzymany), ognisko ograniczone do rombu mapy, 0,4 nad terenem (woda = 0).
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
var ramka_aktywna := false         # ustawiane przez SterowanieRTS podczas przeciągania ramki – blokuje krawędź [P]
var _krawedz := Vector2.ZERO       # aktywne przewijanie krawędzią (x = prawo/lewo, y = dalej/bliżej), stan jak w EE
var _srodkowy := false             # przeciąganie środkowym przyciskiem
var _kursor_srodkowy := Vector2.ZERO
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
		y = ModelKameryEE.wysokosc_ogniska(float(wysokosc_terenu.call(p)))
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
	if not przesuwanie_krawedzia or ramka_aktywna or _srodkowy:
		return Vector2.ZERO
	if DisplayServer.get_name() != "headless" and not get_window().has_focus():
		return Vector2.ZERO
	return _krawedz


## Stan przewijania krawędzią z ruchu myszy (EE: włączenie pchaniem na zewnątrz, gdy kursor stoi na krawędzi;
## wyłączenie ruchem do wnętrza albo zejściem z krawędzi). `poz` – pozycja kursora w oknie, `rel` – ruch względny.
func aktualizuj_krawedz(poz: Vector2, rel: Vector2, rozmiar: Vector2) -> void:
	if ramka_aktywna:
		_krawedz = Vector2.ZERO        # ramka zaznaczenia: krawędź nieaktywna [P], stan nie przechodzi poza ramkę [H]
		return
	var s := ModelKameryEE.PROG_KRAWEDZI_PX
	var na_lewej := poz.x <= s; var na_prawej := poz.x >= rozmiar.x - 1.0 - s
	var na_gorze := poz.y <= s; var na_dole := poz.y >= rozmiar.y - 1.0 - s
	if na_lewej and rel.x < 0.0: _krawedz.x = -1.0
	elif na_prawej and rel.x > 0.0: _krawedz.x = 1.0
	elif (_krawedz.x < 0.0 and (not na_lewej or rel.x > 0.0)) or (_krawedz.x > 0.0 and (not na_prawej or rel.x < 0.0)):
		_krawedz.x = 0.0
	if na_gorze and rel.y < 0.0: _krawedz.y = 1.0
	elif na_dole and rel.y > 0.0: _krawedz.y = -1.0
	elif (_krawedz.y > 0.0 and (not na_gorze or rel.y > 0.0)) or (_krawedz.y < 0.0 and (not na_dole or rel.y < 0.0)):
		_krawedz.y = 0.0


func _process(dt: float) -> void:
	_zamknij_kursor_w_oknie()
	var v := kierunek_klawiszy()
	if v != Vector2.ZERO:
		# kierunki składane bez normalizacji (ukos szybszy o √2), przeciwne się znoszą – jak w EE [P]
		przesun(v * ModelKameryEE.predkosc(poziom) * dt)
		return
	var k := kierunek_krawedzi()
	if k != Vector2.ZERO:
		przesun(k * ModelKameryEE.predkosc_krawedzi(poziom) * dt)


func _notification(co: int) -> void:
	if co == NOTIFICATION_WM_MOUSE_EXIT or co == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_krawedz = Vector2.ZERO
		if _srodkowy: _koniec_srodkowego()


func _input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		if _srodkowy:
			przesun(ModelKameryEE.przesuniecie_srodkowym(e.relative, poziom))
		else:
			aktualizuj_krawedz(e.position, e.relative, get_viewport().get_visible_rect().size)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_UP: ustaw_poziom(poziom - 1)
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN: ustaw_poziom(poziom + 1)
		elif e.button_index == MOUSE_BUTTON_MIDDLE:
			if e.pressed: _poczatek_srodkowego(e.position)
			elif _srodkowy: _koniec_srodkowego()


## W EE (pełny ekran) kursor nie opuszcza okna – pchanie poza krawędź daje ruch względny przy kursorze na krawędzi.
## W OpenEE kursor jest zamykany w oknie tylko na pełnym ekranie [H]; w oknie zwykłym wyjście kursora za okno
## przerywa przewijanie krawędzią (NOTIFICATION_WM_MOUSE_EXIT).
func _zamknij_kursor_w_oknie() -> void:
	if not przesuwanie_krawedzia or _srodkowy or DisplayServer.get_name() == "headless":
		return
	var tryb := DisplayServer.window_get_mode()
	var pelny := tryb == DisplayServer.WINDOW_MODE_FULLSCREEN or tryb == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if pelny and get_window().has_focus() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED
	elif not pelny and Input.mouse_mode == Input.MOUSE_MODE_CONFINED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Środkowy przycisk: kursor zatrzymany (tryb przechwycenia myszy daje sam ruch względny), po zwolnieniu wraca
## w miejsce wciśnięcia. W EE kursor pozostaje widoczny [H: w OpenEE ukryty na czas przeciągania].
func _poczatek_srodkowego(poz: Vector2) -> void:
	_srodkowy = true
	_krawedz = Vector2.ZERO
	_kursor_srodkowy = poz
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _koniec_srodkowego() -> void:
	_srodkowy = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE      # _zamknij_kursor_w_oknie przywróci CONFINED na pełnym ekranie
		get_viewport().warp_mouse(_kursor_srodkowy)


func opis() -> Dictionary:
	return {"ognisko": [snappedf(cel.x, 0.001), snappedf(cel.y, 0.001), snappedf(cel.z, 0.001)], "poziom": poziom,
		"odleglosc": snappedf(odleglosc, 0.001), "pochylenie_st": ModelKameryEE.POCHYLENIE_ST,
		"fov_poziomy_st": fov, "keep_aspect": keep_aspect}
