extends Control
## Ekran startowy OpenEE: stan konfiguracji, warstw, źródeł danych i dziennika.

func _ready() -> void:
	var tlo := ColorRect.new()
	tlo.color = Color(0.08, 0.1, 0.13)
	tlo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(tlo)
	var v := VBoxContainer.new()
	v.position = Vector2(24, 20)
	v.size = Vector2(1220, 680)
	add_child(v)
	var tyt := Label.new()
	tyt.text = "OpenEE – etap 1 (fundament)"
	tyt.add_theme_font_size_override("font_size", 26)
	v.add_child(tyt)
	var info := Label.new()
	var linie := [
		"Godot: %s" % Engine.get_version_info().string,
		"Instalacja EE: %s" % (Konfiguracja.instalacja_ee if Konfiguracja.instalacja_ee != "" else "NIE ZNALEZIONO"),
		"Aktywne warstwy: %s" % ", ".join(Konfiguracja.aktywne_warstwy),
		"Źródła danych:"]
	for z in Zasoby.opis_zrodel():
		linie.append("   • " + z)
	linie.append("Planowane API modów (bez interpretera):")
	for l in ApiModow.opis().split("\n"):
		linie.append("   • " + l)
	info.text = "\n".join(linie)
	v.add_child(info)
	var b := Button.new()
	b.text = "Uruchom test graficzny (teren + model z oryginalnych archiwów)"
	b.pressed.connect(func(): get_tree().change_scene_to_file("res://sceny/test_teren.tscn"))
	v.add_child(b)
	var log := Label.new()
	log.text = "Dziennik:\n" + "\n".join(Dziennik.ostatnie(12))
	log.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	v.add_child(log)
