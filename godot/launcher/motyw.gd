class_name MotywLaunchera
## Paleta, czcionki i style launchera OpenEE (ciemny granat, niebieskie obrysy, złote logo, zielony przycisk akcji).
## Wszystko budowane w kodzie – łatwo zmienić w jednym miejscu.

const TLO := Color("#0a0f18")
const TLO_PANEL_BOCZNY := Color("#0d1521")
const PANEL := Color("#111b2a")
const PANEL_JASNY := Color("#16233a")
const OBRYS := Color("#22344f")
const OBRYS_JASNY := Color("#2f4a70")
const POSWIATA := Color(0.23, 0.45, 0.85, 0.16)
const TEKST := Color("#e7eef8")
const TEKST_PRZYGASZONY := Color("#9db0c8")
const TEKST_SLABY := Color("#5f7189")
const AKCENT := Color("#3d8bfd")
const AKCENT_TLO := Color("#1b3760")
const ZLOTO := Color("#e8b75a")
const ZLOTO_CIEMNE := Color("#8a5a1c")
const ZIELEN := Color("#2ea043")
const ZIELEN_JASNA := Color("#3fbf55")
const ZIELEN_CIEMNA := Color("#1f7a30")
const OSTRZEZENIE := Color("#e3a33b")
const BLAD := Color("#e5534b")
const SUKCES := Color("#3fd068")

const PROMIEN := 8

static var _czcionki := {}


static func czcionka(rodzaj: String = "ui") -> Font:
	if _czcionki.has(rodzaj):
		return _czcionki[rodzaj]
	var f := SystemFont.new()
	match rodzaj:
		"logo":
			f.font_names = PackedStringArray(["DejaVu Serif", "Liberation Serif", "Noto Serif", "Times New Roman", "serif"])
			f.font_weight = 700
			f.font_italic = true
		"pogrubiona":
			f.font_names = PackedStringArray(["Noto Sans", "Cantarell", "DejaVu Sans", "Liberation Sans", "Segoe UI", "sans-serif"])
			f.font_weight = 600
		_:
			f.font_names = PackedStringArray(["Noto Sans", "Cantarell", "DejaVu Sans", "Liberation Sans", "Segoe UI", "sans-serif"])
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_LIGHT
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	f.multichannel_signed_distance_field = false
	_czcionki[rodzaj] = f
	return f


static func styl(tlo: Color, obrys: Color = Color.TRANSPARENT, promien: int = PROMIEN, grubosc: int = 1,
		margines: Vector4 = Vector4(10, 6, 10, 6)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = tlo
	s.set_corner_radius_all(promien)
	if obrys.a > 0:
		s.border_color = obrys
		s.set_border_width_all(grubosc)
	s.content_margin_left = margines.x
	s.content_margin_top = margines.y
	s.content_margin_right = margines.z
	s.content_margin_bottom = margines.w
	s.anti_aliasing = true
	return s


## Karta: granatowe tło z gradientem obrysu i delikatną niebieską poświatą.
static func styl_karty() -> StyleBoxFlat:
	var s := styl(PANEL, OBRYS, 10, 1, Vector4(18, 14, 18, 14))
	s.shadow_color = POSWIATA
	s.shadow_size = 8
	return s


static func styl_przycisku(stan: String) -> StyleBoxFlat:
	match stan:
		"hover": return styl(Color("#22324b"), OBRYS_JASNY, 6, 1, Vector4(12, 4, 12, 4))
		"pressed": return styl(Color("#1a283d"), AKCENT, 6, 1, Vector4(12, 4, 12, 4))
		"disabled": return styl(Color("#131c2b"), Color("#1d2a3e"), 6, 1, Vector4(12, 4, 12, 4))
		"focus":
			var f := styl(Color.TRANSPARENT, AKCENT, 6, 1)
			f.draw_center = false
			return f
		_: return styl(Color("#1a2638"), Color("#2c3f5c"), 6, 1, Vector4(12, 4, 12, 4))


static func styl_startu(stan: String) -> StyleBoxFlat:
	var tlo := ZIELEN
	match stan:
		"hover": tlo = ZIELEN_JASNA
		"pressed": tlo = ZIELEN_CIEMNA
		"disabled": tlo = Color("#2a3b2e")
	var s := styl(tlo, Color("#58d36d") if stan != "disabled" else Color("#33473a"), 6, 1, Vector4(22, 8, 22, 8))
	s.shadow_color = Color(0.2, 0.75, 0.3, 0.22 if stan != "disabled" else 0.0)
	s.shadow_size = 10
	return s


static func zbuduj_motyw(rozmiar_tekstu: int = 15) -> Theme:
	var t := Theme.new()
	t.default_font = czcionka("ui")
	t.default_font_size = rozmiar_tekstu
	t.set_color("font_color", "Label", TEKST)
	for typ in ["Button", "OptionButton", "MenuButton", "CheckBox", "CheckButton"]:
		t.set_color("font_color", typ, TEKST)
		t.set_color("font_hover_color", typ, Color.WHITE)
		t.set_color("font_pressed_color", typ, Color.WHITE)
		t.set_color("font_focus_color", typ, TEKST)
		t.set_color("font_disabled_color", typ, TEKST_SLABY)
		t.set_color("icon_normal_color", typ, TEKST)
		t.set_color("icon_disabled_color", typ, Color(1, 1, 1, 0.35))
		t.set_constant("h_separation", typ, 8)
	for typ in ["Button", "OptionButton", "MenuButton"]:
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			t.set_stylebox(st, typ, styl_przycisku(st))
	t.set_stylebox("hover_pressed", "Button", styl_przycisku("hover"))
	# rozwijane listy
	t.set_icon("arrow", "OptionButton", IkonyLaunchera.tekstura("rozwin", TEKST_PRZYGASZONY, 18))
	t.set_constant("arrow_margin", "OptionButton", 10)
	var pop := styl(Color("#121d2e"), OBRYS_JASNY, 6, 1, Vector4(6, 6, 6, 6))
	pop.shadow_color = Color(0, 0, 0, 0.45); pop.shadow_size = 10
	t.set_stylebox("panel", "PopupMenu", pop)
	t.set_stylebox("hover", "PopupMenu", styl(AKCENT_TLO, Color.TRANSPARENT, 4))
	t.set_color("font_color", "PopupMenu", TEKST)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_color("font_disabled_color", "PopupMenu", TEKST_SLABY)
	t.set_color("font_separator_color", "PopupMenu", TEKST_PRZYGASZONY)
	t.set_constant("v_separation", "PopupMenu", 8)
	t.set_icon("checked", "PopupMenu", IkonyLaunchera.tekstura("zaznaczone", AKCENT, 16))
	t.set_icon("unchecked", "PopupMenu", IkonyLaunchera.tekstura("niezaznaczone", TEKST_PRZYGASZONY, 16))
	t.set_icon("radio_checked", "PopupMenu", IkonyLaunchera.tekstura("radio_on", AKCENT, 16))
	t.set_icon("radio_unchecked", "PopupMenu", IkonyLaunchera.tekstura("radio_off", TEKST_PRZYGASZONY, 16))
	# pola wyboru
	for typ in ["CheckBox"]:
		var pusty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "disabled", "hover_pressed", "focus"]:
			t.set_stylebox(st, typ, pusty)
		t.set_icon("checked", typ, IkonyLaunchera.tekstura("zaznaczone", AKCENT, 22))
		t.set_icon("unchecked", typ, IkonyLaunchera.tekstura("niezaznaczone", TEKST_PRZYGASZONY, 22))
		t.set_icon("checked_disabled", typ, IkonyLaunchera.tekstura("zaznaczone", TEKST_SLABY, 22))
		t.set_icon("unchecked_disabled", typ, IkonyLaunchera.tekstura("niezaznaczone", TEKST_SLABY, 22))
		t.set_icon("radio_checked", typ, IkonyLaunchera.tekstura("radio_on", AKCENT, 20))
		t.set_icon("radio_unchecked", typ, IkonyLaunchera.tekstura("radio_off", TEKST_PRZYGASZONY, 20))
	# pola tekstowe
	t.set_stylebox("normal", "LineEdit", styl(Color("#0e1724"), Color("#2c3f5c"), 6, 1, Vector4(10, 6, 10, 6)))
	t.set_stylebox("focus", "LineEdit", styl(Color.TRANSPARENT, AKCENT, 6, 1))
	t.set_color("font_color", "LineEdit", TEKST)
	t.set_color("font_placeholder_color", "LineEdit", TEKST_SLABY)
	# listy
	t.set_stylebox("panel", "ItemList", styl(Color("#0e1724"), OBRYS, 6, 1, Vector4(6, 6, 6, 6)))
	t.set_stylebox("selected", "ItemList", styl(AKCENT_TLO, Color.TRANSPARENT, 4))
	t.set_stylebox("selected_focus", "ItemList", styl(AKCENT_TLO, AKCENT, 4))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_color("font_color", "ItemList", TEKST)
	t.set_color("font_selected_color", "ItemList", Color.WHITE)
	t.set_constant("v_separation", "ItemList", 8)
	# podpowiedzi
	t.set_stylebox("panel", "TooltipPanel", styl(Color("#0f1826"), OBRYS_JASNY, 6, 1, Vector4(10, 6, 10, 6)))
	t.set_color("font_color", "TooltipLabel", TEKST)
	# separatory, przewijanie
	var linia := StyleBoxLine.new(); linia.color = OBRYS; linia.thickness = 1
	t.set_stylebox("separator", "HSeparator", linia)
	t.set_constant("separation", "HSeparator", 10)
	var suwak := styl(Color("#2a3c57"), Color.TRANSPARENT, 4, 0, Vector4(4, 4, 4, 4))
	t.set_stylebox("grabber", "VScrollBar", suwak)
	t.set_stylebox("grabber_highlight", "VScrollBar", styl(Color("#3a5378"), Color.TRANSPARENT, 4))
	t.set_stylebox("grabber_pressed", "VScrollBar", styl(AKCENT, Color.TRANSPARENT, 4))
	t.set_stylebox("scroll", "VScrollBar", styl(Color(0, 0, 0, 0.15), Color.TRANSPARENT, 4, 0, Vector4(3, 3, 3, 3)))
	# okna dialogowe
	var okno := styl(Color("#111b2a"), OBRYS_JASNY, 10, 1, Vector4(16, 12, 16, 12))
	t.set_stylebox("panel", "AcceptDialog", okno)
	# ramka okien osadzonych: pasek tytułu rysowany NAD obszarem okna – margines rozszerzenia musi go objąć
	var ramka := styl(Color("#111b2a"), OBRYS_JASNY, 10, 1)
	ramka.expand_margin_top = 34; ramka.expand_margin_left = 6; ramka.expand_margin_right = 6; ramka.expand_margin_bottom = 6
	ramka.shadow_color = Color(0, 0, 0, 0.5); ramka.shadow_size = 16
	t.set_stylebox("embedded_border", "Window", ramka)
	t.set_stylebox("embedded_unfocused_border", "Window", ramka)
	t.set_constant("title_height", "Window", 34)
	t.set_font_size("title_font_size", "Window", 16)
	t.set_icon("close", "Window", IkonyLaunchera.tekstura("wylacz_x", TEKST_PRZYGASZONY, 16))
	t.set_icon("close_pressed", "Window", IkonyLaunchera.tekstura("wylacz_x", Color.WHITE, 16))
	t.set_constant("close_h_offset", "Window", 22)
	t.set_constant("close_v_offset", "Window", 18)
	t.set_stylebox("panel", "FileDialog", styl(Color("#111b2a"), Color.TRANSPARENT, 0, 0, Vector4(12, 10, 12, 10)))
	t.set_color("title_color", "Window", TEKST)
	t.set_font("title_font", "Window", czcionka("pogrubiona"))
	return t
