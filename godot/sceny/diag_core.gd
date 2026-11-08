extends Node2D
## Scena diagnostyczna OpenEE Core (C++) – etap 28.  ./uruchom_openee.sh core [--gra=aoc] [--dll=…] [--przypadek=N]
## GDScript tylko przekazuje dane i rysuje migawkę; ruch liczy natywny Core przez GDExtension.
## Klawisze: 1 – EE, 2 – AoC, ←/→ – przypadek, spacja – start/pauza, N – jeden takt, R – od nowa.
## --auto=N: N taktów bez okna i wypis migawki (sprawdzenie przepływu danych).

const SKALA := 40.0

var sym: Object
var przypadki: Array = []
var nr := 4
var gra := "ee"
var biegnie := false
var id := 0
var slad := PackedVector2Array()
var komunikat := ""
var etykieta := Label.new()


func _ready() -> void:
	add_child(etykieta)
	etykieta.position = Vector2(10, 10)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--gra="):
			gra = a.trim_prefix("--gra=")
		elif a.begins_with("--przypadek="):
			nr = int(a.trim_prefix("--przypadek="))
	if not CoreCpp.dostepny():
		komunikat = "Brak biblioteki OpenEE Core (godot/bin). Zbuduj: docs/cpp/BUDOWANIE.md"
		etykieta.text = komunikat
		push_error(komunikat)
		return
	sym = CoreCpp.nowa_symulacja()
	przypadki = CoreCpp.wczytaj_przypadki(get_node("/root/Konfiguracja").katalog_openee)
	_laduj_tablice()
	_reset()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--auto="):
			_auto(int(a.trim_prefix("--auto=")))


func _laduj_tablice() -> void:
	var dll := CoreCpp.znajdz_dll(gra, get_node_or_null("/root/Konfiguracja"))
	if dll == "":
		sym.uzyj_tablic_przyblizonych()
		komunikat = "Nie znaleziono Low-Level Engine.dll – tryb PRZYBLIŻONY (niezgodny z Titan)"
	else:
		var r: Dictionary = sym.zaladuj_tablice(dll)
		komunikat = r["komunikat"]
		if not r["ok"]:
			sym.uzyj_tablic_przyblizonych()


func _reset() -> void:
	if przypadki.is_empty():
		return
	nr = clampi(nr, 0, przypadki.size() - 1)
	var p: Dictionary = przypadki[nr].duplicate(true)
	p["wariant"] = gra
	id = CoreCpp.uruchom_przypadek(sym, p)
	slad.clear()
	biegnie = false
	_odswiez()


func _auto(n: int) -> void:
	sym.takt(n)
	print("OpenEE Core – ", sym.wersja())
	print(komunikat)
	print("przypadek ", przypadki[nr]["nazwa"], " (", gra, ") po ", n, " taktach: ", sym.jednostka(id))
	print("diagnostyka: ", sym.diagnostyka())
	get_tree().quit()


func _process(_d: float) -> void:
	if biegnie and sym:
		sym.takt(1)
		_odswiez()
		if int(sym.jednostka(id).get("stan", 0)) == 5000:
			biegnie = false


func _odswiez() -> void:
	var j: Dictionary = sym.jednostka(id)
	if j.is_empty():
		return
	slad.append(Vector2(j["x"], -j["y"]) * SKALA)
	var d: Dictionary = sym.diagnostyka()
	etykieta.text = "OpenEE Core (C++) – %s\n%s\nprzypadek %d/%d: %s   gra: %s\ntakt %d   stan %d %s   tryb %d\nx %.6f  y %.6f  z %.4f\nv %.6f  ω %.5f  kurs %.6f rad\npunkty zdjęte %d / pozostało %d   RNG %d (%d losowań)\n1/2 – EE/AoC, ←/→ – przypadek, spacja – start, N – takt, R – od nowa" % [
		sym.wersja(), komunikat, nr + 1, przypadki.size(), przypadki[nr]["nazwa"], gra, d["takty"], j["stan"],
		j["stan_nazwa"], j["tryb"], j["x"], j["y"], j["z"], j["v"], j["omega"], j["kurs"], j["zdjete_punkty"],
		j["pozostalo_punktow"], d["rng_stan"], d["rng_losowania"]]
	queue_redraw()


func _draw() -> void:
	if not sym or przypadki.is_empty():
		return
	var srodek := get_viewport_rect().size * 0.5
	var p: Dictionary = przypadki[nr]
	var o := Vector2(p["start"]["x"], -p["start"]["y"]) * SKALA
	var t := Transform2D(0, srodek - o)
	draw_set_transform_matrix(t)
	for q in p["punkty"]:
		draw_circle(Vector2(q["x"], -q["y"]) * SKALA, 4, Color(1, 0.8, 0.2))
	if slad.size() > 1:
		draw_polyline(slad, Color(0.3, 0.8, 1.0), 2)
	var j: Dictionary = sym.jednostka(id)
	if not j.is_empty():
		var pos := Vector2(j["x"], -j["y"]) * SKALA
		var m: PackedFloat64Array = j["macierz"]
		draw_circle(pos, 8, Color(0.9, 0.3, 0.3))
		draw_line(pos, pos + Vector2(m[1], -m[4]) * 24.0, Color.WHITE, 3)  # oś przodu (m01, m11)


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed) or not sym:
		return
	match e.keycode:
		KEY_1:
			gra = "ee"
			_laduj_tablice()
			_reset()
		KEY_2:
			gra = "aoc"
			_laduj_tablice()
			_reset()
		KEY_LEFT:
			nr -= 1
			_reset()
		KEY_RIGHT:
			nr += 1
			_reset()
		KEY_SPACE:
			biegnie = not biegnie
		KEY_N:
			sym.takt(1)
			_odswiez()
		KEY_R:
			_reset()
