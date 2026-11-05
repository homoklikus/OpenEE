extends CanvasLayer
## Węzeł dodawany przez launcher do korzenia drzewa przed przejściem do sceny OpenEE.
## Esc lub przycisk w rogu → powrót do launchera. Nie zmienia scen testowych.

const SCENA := "res://launcher/launcher.tscn"
var napis := "← Launcher (Esc)"


func _ready() -> void:
	layer = 100
	var b := Button.new()
	b.text = napis
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", MotywLaunchera.styl(Color(0.05, 0.08, 0.13, 0.75), MotywLaunchera.OBRYS_JASNY, 6))
	b.add_theme_stylebox_override("hover", MotywLaunchera.styl(Color(0.1, 0.16, 0.26, 0.9), MotywLaunchera.AKCENT, 6))
	b.add_theme_color_override("font_color", MotywLaunchera.TEKST)
	b.pressed.connect(wroc)
	add_child(b)
	b.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
		wroc()


func wroc() -> void:
	get_tree().change_scene_to_file(SCENA)
	queue_free()
