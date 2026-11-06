extends Camera3D
## Kamera DIAGNOSTYCZNA (wolna) – tylko sceny testowe i narzędzia: WASD/strzałki – przesuwanie, kółko myszy –
## przybliżenie bez ograniczeń kroku (3–400), Q/E – obrót, środkowy przycisk + ruch – przesuwanie, R – widok
## początkowy. W rozgrywce RTS używana jest kamera produkcyjna res://sceny/kamera_rts.gd (wierna oryginałowi);
## tę włącza argument --kamera-wolna.

var cel := Vector3.ZERO
var odleglosc := 30.0
var kat_obrotu := -45.0
var pochylenie := 50.0
var _start := {}


func ustaw(c: Vector3, odl: float) -> void:
	cel = c; odleglosc = odl
	_start = {"cel": c, "odl": odl, "obr": kat_obrotu}
	_aktualizuj()


func _aktualizuj() -> void:
	var o := deg_to_rad(kat_obrotu); var p := deg_to_rad(pochylenie)
	position = cel + Vector3(sin(o) * cos(p), sin(p), cos(o) * cos(p)) * odleglosc
	look_at(cel, Vector3.UP)


func _process(dt: float) -> void:
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): v.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): v.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): v.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): v.x += 1
	if Input.is_key_pressed(KEY_Q): kat_obrotu += 60 * dt
	if Input.is_key_pressed(KEY_E): kat_obrotu -= 60 * dt
	if v != Vector2.ZERO:
		var o := deg_to_rad(kat_obrotu)
		var przod := Vector3(-sin(o), 0, -cos(o)); var prawo := Vector3(cos(o), 0, -sin(o))
		cel += (prawo * v.x - przod * v.y) * odleglosc * 0.8 * dt
	if v != Vector2.ZERO or Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_E):
		_aktualizuj()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP: odleglosc = max(3.0, odleglosc * 0.9); _aktualizuj()
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN: odleglosc = min(400.0, odleglosc * 1.1); _aktualizuj()
	elif e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_MIDDLE):
		var o := deg_to_rad(kat_obrotu)
		cel += (Vector3(cos(o), 0, -sin(o)) * -e.relative.x + Vector3(-sin(o), 0, -cos(o)) * e.relative.y) * odleglosc * 0.002
		_aktualizuj()
	elif e is InputEventKey and e.pressed and e.keycode == KEY_R and not _start.is_empty():
		cel = _start.cel; odleglosc = _start.odl; kat_obrotu = _start.obr; _aktualizuj()


func opis() -> Dictionary:
	return {"cel": [snappedf(cel.x, 0.001), snappedf(cel.y, 0.001), snappedf(cel.z, 0.001)], "odleglosc": snappedf(odleglosc, 0.001),
		"kat_obrotu": kat_obrotu, "pochylenie": pochylenie, "fov": fov, "wolna": true}
