extends Control
## Launcher OpenEE – ekran główny i strony boczne. UI budowane w kodzie (motyw: MotywLaunchera, ikony: IkonyLaunchera,
## teksty: TekstyUI + dane/launcher/i18n/*.json, model: StanLaunchera).
## Argumenty (po "--"): --zrzut=<plik.png> --strona=<start|gra|mody|profile|ustawienia|narzedzia|informacje>
##                      --jezyk-ui=<pl|en> --rozmiar=<SZERxWYS> --skala=<0.7..1.4>   (zrzut/rozmiar/język bez zapisu ustawień)
##                      --uruchom=<0|1|2>  od razu uruchamia tryb z menu przycisku (test integracji)

const BAZA := Vector2i(1520, 900)       # rozmiar logiczny układu; okno skaluje go proporcjonalnie (tryb canvas_items + expand)
const STRONY := ["start", "gra", "mody", "profile", "ustawienia", "narzedzia", "informacje"]
const IKONY_STRON := {"start": "start", "gra": "gra", "mody": "mody", "profile": "profile",
	"ustawienia": "ustawienia", "narzedzia": "narzedzia", "informacje": "informacje"}
const M = preload("res://launcher/motyw.gd")

var K: Node
var Z: Node
var stan: StanLaunchera
var tx := TekstyUI.new()
var strona := "start"
var _arg_zrzut := ""
var _bez_zapisu := false
var _obraz_baner: Texture2D
var _obraz_okladka: Texture2D
var _obraz_podglad: Texture2D
var _baner_ref: Texture2D
var _baner_ref_plik := ""
var _okno_katalogu: FileDialog
var _kontener_strony: Control
var _przyciski_nav := {}
var _menu_startu: PopupMenu
var _menu_modow: PopupMenu
var _lista_modow: ItemList
var _lista_profili: ItemList
var _okno_info: AcceptDialog


func _arg(nazwa: String, dom: String = "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nazwa):
			return a.split("=", true, 1)[1]
	return dom


func _ready() -> void:
	K = get_node("/root/Konfiguracja")
	Z = get_node("/root/Zasoby")
	_arg_zrzut = _arg("zrzut")
	_bez_zapisu = _arg_zrzut != ""
	stan = StanLaunchera.new(K, Z, false)
	tx.wczytaj(K.katalog_openee.path_join("dane/launcher/i18n"))
	tx.wczytaj_tlumaczenia_silnika(K.katalog_openee.path_join("dane/launcher/i18n/godot"))
	if _arg("jezyk-ui") != "":
		stan.jezyk_ui = _arg("jezyk-ui")
	if _arg("skala") != "":
		stan.skala_ui = clampf(float(_arg("skala")), 0.7, 1.6)
	tx.ustaw(stan.jezyk_ui)
	if _arg("strona") in STRONY:
		strona = _arg("strona")
	_ustaw_okno()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	theme = M.zbuduj_motyw(15)
	theme.set_constant("icon_max_width", "Button", 20)
	_obraz_podglad = _wczytaj_podglad()
	_zbuduj()
	# grafiki z instalacji gry – po pierwszej klatce (pierwsze uruchomienie składa je z archiwów, potem cache)
	await get_tree().process_frame
	_wczytaj_grafiki_gry()
	_zbuduj()
	if _arg("okno-katalogu") != "":
		_wybierz_sciezke(K.zrodlo_gry)   # zrzut okna wyboru katalogu (kontrola języka i wyglądu)
	if _arg("uruchom") != "":
		# test integracji: od razu przejdź do sceny (scena sama obsłuży --zrzut)
		uruchom_tryb(int(_arg("uruchom")))
		return
	if _arg_zrzut != "":
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(_arg_zrzut.get_base_dir())
		var e := img.save_png(_arg_zrzut)
		print("Launcher: zrzut %s (%dx%d) %s" % [_arg_zrzut, img.get_width(), img.get_height(), "OK" if e == OK else "BŁĄD"])
		get_tree().quit(0 if e == OK else 1)


func _ustaw_okno() -> void:
	var w := get_window()
	w.title = "OpenEE Launcher"
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	w.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	w.content_scale_size = Vector2i(Vector2(BAZA) / stan.skala_ui)
	if DisplayServer.get_name() == "headless":
		return
	var roz := _arg("rozmiar")
	if roz != "" and "x" in roz:
		var p := roz.split("x")
		w.size = Vector2i(int(p[0]), int(p[1]))
	elif not Engine.has_meta("openee_launcher_okno"):
		# pierwsze otwarcie: ~85% ekranu w proporcjach układu (HiDPI: rozmiar ekranu jest w pikselach fizycznych)
		var ekran := DisplayServer.screen_get_usable_rect(w.current_screen).size
		var s := minf(ekran.x * 0.88 / BAZA.x, ekran.y * 0.88 / BAZA.y)
		w.size = Vector2i(Vector2(BAZA) * maxf(s, 0.8))
		w.move_to_center()
	Engine.set_meta("openee_launcher_okno", true)
	w.min_size = Vector2i(1100, 700)


# ======================================================================== budowa UI

func _zbuduj() -> void:
	for c in get_children():
		if not c is Window:
			c.queue_free()
	var tlo := ColorRect.new()
	tlo.color = M.TLO
	tlo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(tlo)
	var grad := TextureRect.new()
	grad.texture = _gradient([Color(0.09, 0.15, 0.26, 0.55), Color(0.04, 0.06, 0.1, 0.0)], Vector2(0.75, 0.0), Vector2(0.3, 1.0), true)
	grad.set_anchors_preset(Control.PRESET_FULL_RECT)
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grad)

	var uklad := HBoxContainer.new()
	uklad.set_anchors_preset(Control.PRESET_FULL_RECT)
	uklad.add_theme_constant_override("separation", 0)
	add_child(uklad)
	uklad.add_child(_pasek_boczny())
	var glowny := VBoxContainer.new()
	glowny.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	glowny.add_theme_constant_override("separation", 0)
	uklad.add_child(glowny)
	glowny.add_child(_baner())
	var marg := MarginContainer.new()
	marg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for s in ["left", "right"]:
		marg.add_theme_constant_override("margin_" + s, 20)
	marg.add_theme_constant_override("margin_top", 12)
	marg.add_theme_constant_override("margin_bottom", 16)
	glowny.add_child(marg)
	_kontener_strony = marg
	_pokaz_strone(strona)


func _pokaz_strone(nazwa: String) -> void:
	strona = nazwa
	for c in _kontener_strony.get_children():
		c.queue_free()
	var s: Control
	match nazwa:
		"gra": s = _strona_gra()
		"mody": s = _strona_mody()
		"profile": s = _strona_profile()
		"ustawienia": s = _strona_ustawienia()
		"narzedzia": s = _strona_narzedzia()
		"informacje": s = _strona_informacje()
		_:
			# start: przewijanie tylko awaryjnie (gdy skala UI użytkownika nie mieści układu w oknie)
			var sc := ScrollContainer.new()
			var st := _strona_start()
			st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			st.size_flags_vertical = Control.SIZE_EXPAND_FILL
			sc.add_child(st)
			s = sc
	_kontener_strony.add_child(s)
	for k in _przyciski_nav:
		var b: Button = _przyciski_nav[k]
		b.button_pressed = (k == nazwa)
		b.icon = IkonyLaunchera.tekstura(IKONY_STRON[k], Color.WHITE if k == nazwa else M.TEKST_PRZYGASZONY, 24)


# ------------------------------------------------------------------------ elementy wspólne

func _l(tekst: String, rozmiar: int = 15, kolor: Color = M.TEKST, czc: String = "ui") -> Label:
	var l := Label.new()
	l.text = tekst
	l.add_theme_font_size_override("font_size", rozmiar)
	l.add_theme_color_override("font_color", kolor)
	if czc != "ui":
		l.add_theme_font_override("font", M.czcionka(czc))
	return l


func _ik(nazwa: String, kolor: Color = M.TEKST, rozmiar: int = 22) -> TextureRect:
	var r := TextureRect.new()
	r.texture = IkonyLaunchera.tekstura(nazwa, kolor, rozmiar)
	r.custom_minimum_size = Vector2(rozmiar, rozmiar)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	return r


func _przycisk(tekst: String, ikona: String = "", akcja: Callable = Callable(), wylaczony := false) -> Button:
	var b := Button.new()
	b.text = tekst
	if ikona != "":
		b.icon = IkonyLaunchera.tekstura(ikona, M.TEKST, 18)
	b.disabled = wylaczony
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT if ikona != "" else HORIZONTAL_ALIGNMENT_CENTER
	if akcja.is_valid():
		b.pressed.connect(akcja)
	return b


func _hbox(sep: int = 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


func _vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


func _odstep(poziomy := true) -> Control:
	var c := Control.new()
	if poziomy:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Karta z nagłówkiem (ikona + tytuł). Zwraca [karta, zawartość].
func _karta(ikona: String, tytul: String, rozciagnij := 1.0) -> Array:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", M.styl_karty())
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_stretch_ratio = rozciagnij
	var v := _vbox(10)
	p.add_child(v)
	if tytul != "":
		var h := _hbox(12)
		h.add_child(_ik(ikona, M.TEKST, 28))
		var l := _l(tytul, 20, M.TEKST, "pogrubiona")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		h.add_child(l)
		v.add_child(h)
	return [p, v]


func _status(ok: bool, tekst: String, rozmiar: int = 16) -> HBoxContainer:
	var h := _hbox(8)
	h.add_child(_ik("ok" if ok else "uwaga", M.SUKCES if ok else M.OSTRZEZENIE, 20))
	h.add_child(_l(tekst, rozmiar, M.SUKCES if ok else M.OSTRZEZENIE))
	return h


func _gradient(kolory: Array, od: Vector2, do_: Vector2, liniowy := true) -> GradientTexture2D:
	var g := Gradient.new()
	var off := PackedFloat32Array()
	var kol := PackedColorArray()
	for i in kolory.size():
		off.append(float(i) / max(1, kolory.size() - 1))
		kol.append(kolory[i])
	g.offsets = off
	g.colors = kol
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_LINEAR if liniowy else GradientTexture2D.FILL_RADIAL
	t.fill_from = od
	t.fill_to = do_
	t.width = 256; t.height = 256
	return t


# ------------------------------------------------------------------------ pasek boczny

func _pasek_boczny() -> Control:
	var p := PanelContainer.new()
	var s := M.styl(M.TLO_PANEL_BOCZNY, Color.TRANSPARENT, 0, 0, Vector4(12, 14, 12, 14))
	s.border_color = M.OBRYS
	s.border_width_right = 1
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size.x = 214
	var v := _vbox(6)
	p.add_child(v)
	# marka
	var marka := _hbox(10)
	var logo := _ik("logo", M.ZLOTO, 30)
	marka.add_child(logo)
	var mv := _vbox(0)
	mv.add_child(_l("OpenEE", 20, M.ZLOTO, "logo"))
	mv.add_child(_l("Launcher", 12, M.TEKST_PRZYGASZONY))
	marka.add_child(mv)
	var mm := MarginContainer.new()
	mm.add_theme_constant_override("margin_left", 8)
	mm.add_theme_constant_override("margin_bottom", 14)
	mm.add_child(marka)
	v.add_child(mm)
	_przyciski_nav.clear()
	var grupa := ButtonGroup.new()
	for k in STRONY:
		var b := Button.new()
		b.text = "  " + tx.t("nav_" + k)
		b.toggle_mode = true
		b.button_group = grupa
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size.y = 50
		b.add_theme_font_size_override("font_size", 17)
		b.add_theme_constant_override("icon_max_width", 24)
		var pusty := M.styl(Color.TRANSPARENT, Color.TRANSPARENT, 8, 0, Vector4(14, 6, 10, 6))
		var hov := M.styl(Color("#152238"), Color.TRANSPARENT, 8, 0, Vector4(14, 6, 10, 6))
		var akt := M.styl(M.AKCENT_TLO, Color("#2c5793"), 8, 1, Vector4(14, 6, 10, 6))
		akt.shadow_color = Color(0.24, 0.55, 1.0, 0.18); akt.shadow_size = 6
		b.add_theme_stylebox_override("normal", pusty)
		b.add_theme_stylebox_override("hover", hov)
		b.add_theme_stylebox_override("pressed", akt)
		b.add_theme_stylebox_override("hover_pressed", akt)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_color_override("font_color", M.TEKST_PRZYGASZONY)
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
		b.pressed.connect(_pokaz_strone.bind(k))
		_przyciski_nav[k] = b
		v.add_child(b)
	v.add_child(_odstep(false))
	# język UI (niezależny od języka danych gry)
	var jez := _hbox(6)
	jez.add_child(_ik("globus", M.TEKST_PRZYGASZONY, 18))
	for kod in tx.jezyki():
		var bj := Button.new()
		bj.text = kod.to_upper()
		bj.toggle_mode = true
		bj.button_pressed = kod == tx.jezyk
		bj.focus_mode = Control.FOCUS_NONE
		bj.tooltip_text = tx.t("jezyk_ui_podpowiedz") + " – " + tx.nazwa_jezyka(kod)
		bj.add_theme_font_size_override("font_size", 13)
		bj.add_theme_stylebox_override("pressed", M.styl(M.AKCENT_TLO, M.AKCENT, 5, 1, Vector4(10, 3, 10, 3)))
		bj.add_theme_stylebox_override("normal", M.styl(Color("#141f30"), M.OBRYS, 5, 1, Vector4(10, 3, 10, 3)))
		bj.add_theme_stylebox_override("hover", M.styl(Color("#1b2a40"), M.OBRYS_JASNY, 5, 1, Vector4(10, 3, 10, 3)))
		bj.pressed.connect(_zmien_jezyk_ui.bind(kod))
		jez.add_child(bj)
	var jm := MarginContainer.new()
	jm.add_theme_constant_override("margin_left", 8)
	jm.add_child(jez)
	v.add_child(jm)
	var sep := HSeparator.new()
	v.add_child(sep)
	var wer := _hbox(10)
	var kropka := Panel.new()
	kropka.custom_minimum_size = Vector2(12, 12)
	kropka.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var gotowy: bool = stan.info_silnika().gotowy
	var ks := M.styl(M.SUKCES if gotowy else M.OSTRZEZENIE, Color.TRANSPARENT, 6)
	ks.shadow_color = Color(M.SUKCES if gotowy else M.OSTRZEZENIE, 0.5); ks.shadow_size = 4
	kropka.add_theme_stylebox_override("panel", ks)
	wer.add_child(kropka)
	wer.add_child(_l("OpenEE " + StanLaunchera.WERSJA, 15, M.TEKST_PRZYGASZONY))
	var wm := MarginContainer.new()
	wm.add_theme_constant_override("margin_left", 10)
	wm.add_child(wer)
	v.add_child(wm)
	return p


# ------------------------------------------------------------------------ baner

## Nagłówek z grafiki referencyjnej launchera: dane/launcher/grafika/baner_<język UI>.png (podtytuł wpisany w grafikę
## w danym języku; brak pliku dla języka → baner_en.png). Brak grafik → wariant zastępczy z grafiką z instalacji gry.
func _baner() -> Control:
	var plik: String = K.katalog_openee.path_join("dane/launcher/grafika/baner_%s.png" % tx.jezyk)
	if not FileAccess.file_exists(plik):
		plik = K.katalog_openee.path_join("dane/launcher/grafika/baner_en.png")
	if FileAccess.file_exists(plik):
		if _baner_ref == null or _baner_ref_plik != plik:
			var img := Image.load_from_file(plik)
			if img and not img.is_empty():
				img.generate_mipmaps()
				_baner_ref = ImageTexture.create_from_image(img)
				_baner_ref_plik = plik
		if _baner_ref:
			return _baner_referencyjny()
	return _baner_zastepczy()


func _baner_referencyjny() -> Control:
	var b := Control.new()
	b.clip_contents = true
	b.name = "Baner"
	var t := TextureRect.new()
	t.texture = _baner_ref
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.tooltip_text = tx.t("podtytul")
	b.add_child(t)
	var linia := ColorRect.new()
	linia.color = Color(M.OBRYS_JASNY, 0.9)
	linia.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	linia.offset_top = -1
	b.add_child(linia)
	_dopasuj_baner(b)
	if not get_viewport().size_changed.is_connected(_dopasuj_baner_teraz):
		get_viewport().size_changed.connect(_dopasuj_baner_teraz)
	return b


## Wysokość nagłówka = szerokość / proporcje grafiki (bez przycinania), w granicach 128–176.
func _dopasuj_baner(b: Control) -> void:
	if _baner_ref == null:
		return
	var proporcje := float(_baner_ref.get_width()) / _baner_ref.get_height()
	var szer := get_viewport_rect().size.x - 214.0
	b.custom_minimum_size.y = clampf(szer / proporcje, 128.0, 176.0)


func _dopasuj_baner_teraz() -> void:
	var b := find_child("Baner", true, false)
	if b:
		_dopasuj_baner(b)


func _baner_zastepczy() -> Control:
	var b := Control.new()
	b.custom_minimum_size.y = 140
	b.clip_contents = true
	if _obraz_baner:
		var t := TextureRect.new()
		t.texture = _obraz_baner
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.modulate = Color(1.0, 0.92, 0.8)
		b.add_child(t)
	else:
		var zast := TextureRect.new()   # grafika zastępcza (brak instalacji): gradient
		zast.texture = _gradient([Color("#2b1d0c"), Color("#16233a"), Color("#0b1220")], Vector2(1, 0), Vector2(0, 1))
		zast.set_anchors_preset(Control.PRESET_FULL_RECT)
		zast.stretch_mode = TextureRect.STRETCH_SCALE
		b.add_child(zast)
	var cien := TextureRect.new()
	cien.texture = _gradient([Color(0.03, 0.05, 0.09, 0.97), Color(0.03, 0.05, 0.09, 0.78), Color(0.03, 0.05, 0.09, 0.15)], Vector2(0, 0), Vector2(1, 0))
	cien.set_anchors_preset(Control.PRESET_FULL_RECT)
	cien.stretch_mode = TextureRect.STRETCH_SCALE
	b.add_child(cien)
	var dol := TextureRect.new()
	dol.texture = _gradient([Color(0.04, 0.06, 0.1, 0.0), Color(0.04, 0.06, 0.1, 0.85)], Vector2(0, 0.45), Vector2(0, 1))
	dol.set_anchors_preset(Control.PRESET_FULL_RECT)
	dol.stretch_mode = TextureRect.STRETCH_SCALE
	b.add_child(dol)
	var linia := ColorRect.new()
	linia.color = Color(M.ZLOTO, 0.45)
	linia.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	linia.offset_top = -1
	b.add_child(linia)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 40)
	b.add_child(m)
	var v := _vbox(0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(v)
	var logo := _l("OpenEE", 66, M.ZLOTO, "logo")
	logo.add_theme_color_override("font_outline_color", M.ZLOTO_CIEMNE)
	logo.add_theme_constant_override("outline_size", 3)
	logo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	logo.add_theme_constant_override("shadow_offset_x", 2)
	logo.add_theme_constant_override("shadow_offset_y", 3)
	logo.add_theme_constant_override("shadow_outline_size", 6)
	v.add_child(logo)
	var pod := _l(tx.t("podtytul"), 21, Color("#f1dcae"))
	pod.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	pod.add_theme_constant_override("shadow_offset_y", 2)
	var pm := MarginContainer.new()
	pm.add_theme_constant_override("margin_left", 6)
	pm.add_theme_constant_override("margin_top", -6)
	pm.add_child(pod)
	v.add_child(pm)
	return b


# ======================================================================== strona START

func _strona_start() -> Control:
	var v := _vbox(12)
	var gora := _hbox(14)
	v.add_child(gora)
	var lewa := _vbox(14)
	lewa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gora.add_child(lewa)
	var r1 := _hbox(14)
	r1.add_child(_karta_instalacji())
	r1.add_child(_karta_silnika())
	lewa.add_child(r1)
	var r2 := _hbox(14)
	r2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	r2.add_child(_karta_gry())
	r2.add_child(_karta_profilu())
	r2.add_child(_karta_jezyka())
	lewa.add_child(r2)
	gora.add_child(_karta_aktualnosci())
	var r3 := _hbox(14)
	r3.size_flags_vertical = Control.SIZE_EXPAND_FILL
	r3.add_child(_karta_modow())
	r3.add_child(_karta_podgladu())
	v.add_child(r3)
	v.add_child(_pasek_startu())
	return v


func _karta_instalacji() -> Control:
	var k := _karta("", "", 1.75)
	var info := stan.info_instalacji()
	var h := _hbox(18)
	k[1].add_child(h)
	var ramka := PanelContainer.new()
	ramka.add_theme_stylebox_override("panel", M.styl(Color("#0b111b"), Color("#3a3020"), 4, 1, Vector4(2, 2, 2, 2)))
	ramka.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ok := TextureRect.new()
	ok.custom_minimum_size = Vector2(152, 114)
	ok.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ok.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if _obraz_okladka:
		ok.texture = _obraz_okladka
		ok.tooltip_text = tx.t("okladka_podpowiedz")
	else:
		ok.texture = IkonyLaunchera.tekstura("obraz", M.TEKST_SLABY, 64)
		ok.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ramka.add_child(ok)
	h.add_child(ramka)
	var v := _vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(_l("Empire Earth", 24, M.TEKST, "pogrubiona"))
	var wyd := _l(tx.t("wydanie_gold") + ("\n" + tx.t("wydanie_aoc") if info.get("aoc", false) else ""), 15, M.TEKST_PRZYGASZONY)
	v.add_child(wyd)
	var st := _status(info.ok, tx.t("instalacja_znaleziona") if info.ok else tx.t("instalacja_brak"))
	var zr := _l("·  " + tx.t("zrodlo_" + String(info.zrodlo)) + (" · GOG" if info.get("gog", false) else ""), 13, M.TEKST_SLABY)
	zr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zr.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	zr.clip_text = true
	st.add_child(zr)
	v.add_child(st)
	var ph := _hbox(10)
	var sciezka := _l(_krotka_sciezka(String(info.get("sciezka", ""))) if info.get("sciezka", "") != "" else tx.t("brak_sciezki"), 14, M.TEKST_PRZYGASZONY)
	sciezka.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sciezka.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sciezka.clip_text = true
	sciezka.tooltip_text = String(info.get("sciezka", ""))
	sciezka.mouse_filter = Control.MOUSE_FILTER_PASS
	sciezka.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ph.add_child(sciezka)
	ph.add_child(_przycisk(tx.t("zmien"), "folder", _wybierz_sciezke.bind(String(info.zrodlo))))
	v.add_child(_odstep(false))
	v.add_child(ph)
	return k[0]


func _karta_silnika() -> Control:
	var k := _karta("silnik", tx.t("silnik_tytul"), 1.0)
	var s := stan.info_silnika()
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 4)
	for para in [["wersja", s.wersja], ["renderer", s.renderer], ["platforma", s.platforma]]:
		g.add_child(_l(tx.t(para[0]) + ":", 15, M.TEKST_PRZYGASZONY))
		var w := _l(String(para[1]), 15)
		w.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		w.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		w.tooltip_text = String(para[1]) + ("\n" + s.karta if para[0] == "renderer" and s.karta != "" else "")
		w.mouse_filter = Control.MOUSE_FILTER_PASS
		g.add_child(w)
	k[1].add_child(g)
	k[1].add_child(_odstep(false))
	k[1].add_child(_status(s.gotowy, tx.t("gotowy") if s.gotowy else tx.t("niegotowy")))
	k[0].custom_minimum_size.x = 280
	return k[0]


func _karta_aktualnosci() -> Control:
	var k := _karta("megafon", tx.t("aktualnosci_tytul"), 0.0)
	k[1].add_theme_constant_override("separation", 5)
	k[0].size_flags_horizontal = Control.SIZE_FILL
	k[0].custom_minimum_size.x = 320
	var wpisy := stan.aktualnosci()
	var n := 0
	for w in wpisy:
		if n >= 3:
			break
		k[1].add_child(HSeparator.new())
		var h := _hbox(8)
		var t := _l(StanLaunchera.tekst(w.get("tytul", ""), tx.jezyk), 16, M.TEKST, "pogrubiona")
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		h.add_child(t)
		h.add_child(_l(String(w.get("data", "")), 13, M.TEKST_PRZYGASZONY))
		k[1].add_child(h)
		var o := _l(StanLaunchera.tekst(w.get("tekst", ""), tx.jezyk), 13, M.TEKST_PRZYGASZONY)
		o.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		o.max_lines_visible = 2
		o.custom_minimum_size.x = 260
		k[1].add_child(o)
		n += 1
	k[1].add_child(_odstep(false))
	var wiecej := LinkButton.new()
	wiecej.text = tx.t("wiecej")
	wiecej.add_theme_color_override("font_color", M.AKCENT)
	wiecej.add_theme_color_override("font_hover_color", Color("#7db4ff"))
	wiecej.size_flags_horizontal = Control.SIZE_SHRINK_END
	wiecej.focus_mode = Control.FOCUS_NONE
	wiecej.pressed.connect(_pokaz_strone.bind("informacje"))
	k[1].add_child(wiecej)
	return k[0]


## Etap 11: wybór GRY – Empire Earth albo The Art of Conquest (dwie gry na jednym silniku), niezależny od profilu.
func _karta_gry() -> Control:
	var k := _karta("gra", tx.t("gra_wybor_tytul"), 1.0)
	for g in stan.gry():
		var b := _przycisk(stan.nazwa_gry(g), "", func(): stan.wybierz_gre(g); _pokaz_strone(strona), not stan.gra_dostepna(g))
		b.toggle_mode = true
		b.button_pressed = g == stan.gra_id
		b.add_theme_font_size_override("font_size", 15)
		b.clip_text = true
		b.tooltip_text = stan.nazwa_gry(g) if stan.gra_dostepna(g) else tx.t("gra_niedostepna")
		k[1].add_child(b)
	var lk := _l(tx.t("gra_kampanie") % stan.kampanie().size(), 13, M.TEKST_SLABY)
	lk.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lk.tooltip_text = ", ".join(stan.kampanie())
	lk.mouse_filter = Control.MOUSE_FILTER_PASS
	k[1].add_child(lk)
	return k[0]


func _karta_profilu() -> Control:
	var k := _karta("warstwy", tx.t("profil_tytul"), 1.1)
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_NONE
	ob.fit_to_longest_item = false
	ob.clip_text = true
	ob.add_theme_font_size_override("font_size", 16)
	var wyb := 0
	for i in stan.profile.size():
		var p: Dictionary = stan.profile[i]
		ob.add_item(StanLaunchera.tekst(p.nazwa, tx.jezyk) + ("" if p.get("wbudowany", false) else "  ✎"), i)
		if p.id == stan.profil_id:
			wyb = i
	ob.select(wyb)
	ob.item_selected.connect(func(i): stan.wybierz_profil(stan.profile[i].id); _pokaz_strone(strona))
	k[1].add_child(ob)
	var p := stan.aktualny()
	var opis := StanLaunchera.tekst(p.get("opis", ""), tx.jezyk)
	if opis == "":
		opis = tx.t("profil_wlasny_opis")
	var lo := _l(opis, 14, M.TEKST_PRZYGASZONY)
	lo.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lo.tooltip_text = opis
	lo.mouse_filter = Control.MOUSE_FILTER_PASS
	k[1].add_child(lo)
	k[1].add_child(_odstep(false))
	var h := _hbox(10)
	h.add_child(_przycisk(tx.t("nowy"), "plus", _profil_nowy))
	h.add_child(_przycisk(tx.t("klonuj"), "kopiuj", _profil_klonuj))
	h.add_child(_przycisk(tx.t("usun"), "kosz", _profil_usun, p.get("wbudowany", true)))
	k[1].add_child(h)
	return k[0]


func _karta_jezyka() -> Control:
	var k := _karta("globus", tx.t("jezyk_gry_tytul"), 1.0)
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_NONE
	ob.clip_text = true
	ob.add_theme_font_size_override("font_size", 16)
	ob.add_theme_constant_override("icon_max_width", 30)
	var akt := stan.jezyk_gry()
	var pl_ok := stan.pl_dostepny()
	var flagi := {"pl": "pl", "en": "en", "pl_en": "pl_en"}
	var i := 0
	for kod in StanLaunchera.JEZYKI_GRY:
		ob.add_icon_item(IkonyLaunchera.flaga(flagi[kod], 30, 20), tx.t("jezyk_" + kod), i)
		ob.set_item_metadata(i, kod)
		if kod != "en" and not pl_ok:
			ob.set_item_disabled(i, true)
		if kod == akt:
			ob.select(i)
		i += 1
	if akt == "wlasny":
		ob.add_item(tx.t("jezyk_wlasny"), i)
		ob.set_item_metadata(i, "wlasny")
		ob.set_item_disabled(i, true)
		ob.select(i)
	ob.item_selected.connect(func(j): stan.ustaw_jezyk_gry(String(ob.get_item_metadata(j))); _pokaz_strone(strona))
	k[1].add_child(ob)
	var opis := _l(tx.t("jezyk_opis_" + akt), 14, M.TEKST_PRZYGASZONY)
	opis.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	opis.custom_minimum_size.x = 200
	k[1].add_child(opis)
	if not pl_ok:
		k[1].add_child(_status(false, tx.t("pl_niedostepny"), 13))
	return k[0]


func _karta_modow() -> Control:
	var aktywne := stan.aktywne_mody()
	var k := _karta("mody", tx.t("mody_tytul") % stan.liczba_wlaczonych_modow(), 1.25)
	k[1].add_child(HSeparator.new())
	var h := _hbox(16)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	k[1].add_child(h)
	_lista_modow = null
	if aktywne.is_empty():
		var pust := _vbox(6)
		pust.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pust.alignment = BoxContainer.ALIGNMENT_CENTER
		var ik := _ik("mody", M.TEKST_PRZYGASZONY, 60)
		ik.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		pust.add_child(ik)
		var t1 := _l(tx.t("mody_brak"), 18, M.TEKST, "pogrubiona")
		t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pust.add_child(t1)
		var t2 := _l(tx.t("mody_brak_opis"), 15, M.TEKST_PRZYGASZONY)
		t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pust.add_child(t2)
		h.add_child(pust)
	else:
		var lista := ItemList.new()
		lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
		lista.focus_mode = Control.FOCUS_NONE
		for id in aktywne:
			var md := stan.mod(id)
			var wl := stan.mod_wlaczony(id)
			var idx := lista.add_item(String(md.get("nazwa", id)) + ("" if wl else "  (" + tx.t("wylaczony") + ")"),
				IkonyLaunchera.tekstura("ok" if wl else "wylacz", M.SUKCES if wl else M.TEKST_SLABY, 18))
			lista.set_item_metadata(idx, id)
			lista.set_item_tooltip(idx, String(md.get("opis", "")))
			if not wl:
				lista.set_item_custom_fg_color(idx, M.TEKST_SLABY)
		lista.select(0)
		_lista_modow = lista
		h.add_child(lista)
	var pr := _vbox(8)
	pr.custom_minimum_size.x = 160
	var dodaj := MenuButton.new()
	dodaj.text = tx.t("dodaj_mod")
	dodaj.icon = IkonyLaunchera.tekstura("plus", M.TEKST, 18)
	dodaj.flat = false
	dodaj.focus_mode = Control.FOCUS_NONE
	dodaj.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for st in ["normal", "hover", "pressed", "disabled"]:
		dodaj.add_theme_stylebox_override(st, M.styl_przycisku(st))
	_menu_modow = dodaj.get_popup()
	var do_dodania := stan.mody_do_dodania()
	for i in do_dodania.size():
		_menu_modow.add_item(String(do_dodania[i].nazwa), i)
		_menu_modow.set_item_metadata(i, do_dodania[i].id)
	if do_dodania.is_empty():
		_menu_modow.add_item(tx.t("brak_modow_do_dodania"), 0)
		_menu_modow.set_item_disabled(0, true)
	_menu_modow.id_pressed.connect(func(i): stan.dodaj_mod(String(_menu_modow.get_item_metadata(_menu_modow.get_item_index(i))), _nazwa_kopii()); _pokaz_strone(strona))
	dodaj.tooltip_text = tx.t("dodaj_mod_podpowiedz")
	pr.add_child(dodaj)
	var brak := aktywne.is_empty()
	pr.add_child(_przycisk(tx.t("w_gore"), "gora", _mod_akcja.bind("gora"), brak or aktywne.size() < 2))
	pr.add_child(_przycisk(tx.t("w_dol"), "dol", _mod_akcja.bind("dol"), brak or aktywne.size() < 2))
	pr.add_child(_przycisk(tx.t("wylacz"), "wylacz", _mod_akcja.bind("przelacz"), brak))
	pr.add_child(_przycisk(tx.t("usun"), "kosz", _mod_akcja.bind("usun"), brak))
	h.add_child(pr)
	return k[0]


func _karta_podgladu() -> Control:
	var k := _karta("obraz", tx.t("podglad_tytul"), 1.0)
	var ramka := PanelContainer.new()
	ramka.add_theme_stylebox_override("panel", M.styl(Color("#0b111b"), M.OBRYS, 6, 1, Vector4(1, 1, 1, 1)))
	ramka.size_flags_vertical = Control.SIZE_EXPAND_FILL
	k[1].add_child(ramka)
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.custom_minimum_size = Vector2(240, 120)
	if _obraz_podglad:
		t.texture = _obraz_podglad
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	else:
		t.texture = IkonyLaunchera.tekstura("obraz", M.TEKST_SLABY, 64)
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.tooltip_text = tx.t("podglad_podpowiedz")
	ramka.add_child(t)
	var podpis := _l(tx.t("podglad_podpis") if _obraz_podglad else tx.t("podglad_brak"), 12, M.TEKST_PRZYGASZONY)
	podpis.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	k[1].add_child(podpis)
	return k[0]


func _pasek_startu() -> Control:
	var h := _hbox(12)
	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left", 16)
	var ch := _hbox(8)
	var cb := CheckBox.new()
	cb.text = " " + tx.t("uzyj_openee")
	cb.button_pressed = stan.uzyj_openee
	cb.focus_mode = Control.FOCUS_NONE
	cb.add_theme_font_size_override("font_size", 16)
	cb.toggled.connect(func(v): stan.ustaw_uzyj_openee(v))
	ch.add_child(cb)
	var info := _ik("informacje", M.TEKST_PRZYGASZONY, 20)
	info.tooltip_text = tx.t("uzyj_openee_podpowiedz")
	ch.add_child(info)
	mc.add_child(ch)
	h.add_child(mc)
	h.add_child(_odstep())
	var grupa := _hbox(0)
	var start := Button.new()
	start.text = "  " + tx.t("uruchom")
	start.icon = IkonyLaunchera.tekstura("graj", Color.WHITE, 26)
	start.add_theme_constant_override("icon_max_width", 26)
	start.custom_minimum_size = Vector2(340, 56)
	start.focus_mode = Control.FOCUS_NONE
	start.add_theme_font_size_override("font_size", 23)
	start.add_theme_font_override("font", M.czcionka("pogrubiona"))
	for st in ["normal", "hover", "pressed", "disabled"]:
		var s := M.styl_startu(st)
		s.corner_radius_top_right = 0; s.corner_radius_bottom_right = 0
		start.add_theme_stylebox_override(st, s)
	start.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	start.tooltip_text = tx.t("uruchom_podpowiedz_openee") if stan.uzyj_openee else tx.t("uruchom_podpowiedz_oryginal")
	start.pressed.connect(uruchom)
	grupa.add_child(start)
	var strz := MenuButton.new()
	strz.icon = IkonyLaunchera.tekstura("rozwin", Color.WHITE, 22)
	strz.custom_minimum_size = Vector2(52, 56)
	strz.focus_mode = Control.FOCUS_NONE
	strz.flat = false
	strz.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for st in ["normal", "hover", "pressed", "disabled"]:
		var s := M.styl_startu(st)
		s.corner_radius_top_left = 0; s.corner_radius_bottom_left = 0
		s.border_width_left = 0
		s.border_color = Color("#58d36d")
		s.content_margin_left = 8; s.content_margin_right = 8
		strz.add_theme_stylebox_override(st, s)
	var sep := VSeparator.new()
	var sl := StyleBoxLine.new(); sl.vertical = true; sl.color = Color(0, 0, 0, 0.3); sl.thickness = 1
	sep.add_theme_stylebox_override("separator", sl)
	sep.add_theme_constant_override("separation", 1)
	grupa.add_child(sep)
	_menu_startu = strz.get_popup()
	_menu_startu.add_item(tx.t("tryb_scenariusz"), 0)
	_menu_startu.add_item(tx.t("tryb_teren"), 1)
	_menu_startu.add_item(tx.t("tryb_diagnostyka"), 2)
	_menu_startu.add_separator()
	_menu_startu.add_item(tx.t("tryb_oryginal"), 3)
	_menu_startu.set_item_disabled(_menu_startu.get_item_index(3), true)
	_menu_startu.id_pressed.connect(uruchom_tryb)
	grupa.add_child(strz)
	h.add_child(grupa)
	return h


# ======================================================================== pozostałe strony

func _strona_naglowek(v: VBoxContainer, klucz: String, ikona: String) -> void:
	var h := _hbox(12)
	h.add_child(_ik(ikona, M.ZLOTO, 30))
	h.add_child(_l(tx.t("nav_" + klucz), 26, M.TEKST, "pogrubiona"))
	v.add_child(h)
	var o := _l(tx.t("strona_opis_" + klucz), 15, M.TEKST_PRZYGASZONY)
	o.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(o)


func _przewijana(v: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(v)
	return s


func _wiersz(kl: String, wart: String, kolor: Color = M.TEKST) -> HBoxContainer:
	var h := _hbox(12)
	var a := _l(kl, 15, M.TEKST_PRZYGASZONY)
	a.custom_minimum_size.x = 220
	h.add_child(a)
	var b := _l(wart, 15, kolor)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	h.add_child(b)
	return h


func _strona_gra() -> Control:
	var v := _vbox(14)
	_strona_naglowek(v, "gra", "gra")
	var nazwy: Array = []
	if K._cfg.has_section("instalacje"):
		nazwy = Array(K._cfg.get_section_keys("instalacje"))
	for n in K.instalacje:
		if not n in nazwy:
			nazwy.append(n)
	for n in nazwy:
		var k := _karta("folder", tx.t("zrodlo_" + n) if tx.ma("zrodlo_" + n, tx.jezyk) else n)
		var p: String = K.instalacje.get(n, "")
		var spr: Dictionary = K.czy_instalacja_ee(p) if p != "" else {"ok": false}
		k[1].add_child(_status(spr.ok, tx.t("instalacja_znaleziona") if spr.ok else tx.t("instalacja_brak")))
		k[1].add_child(_wiersz(tx.t("sciezka"), p if p != "" else tx.t("brak_sciezki")))
		if spr.ok:
			k[1].add_child(_wiersz(tx.t("zawartosc"), "Empire Earth" + (" + The Art of Conquest" if spr.aoc else "") + (" · GOG" if spr.gog else "")))
		if n == K.zrodlo_gry:
			k[1].add_child(_wiersz(tx.t("rola"), tx.t("rola_baza"), M.SUKCES))
		elif n == K.zrodlo_pl:
			k[1].add_child(_wiersz(tx.t("rola"), tx.t("rola_pl")))
		var h := _hbox(10)
		h.add_child(_przycisk(tx.t("zmien_sciezke"), "folder", _wybierz_sciezke.bind(n)))
		h.add_child(_przycisk(tx.t("otworz_folder"), "folder", func(): OS.shell_open(p), p == ""))
		k[1].add_child(h)
		v.add_child(k[0])
	var hk := _karta("ok", tx.t("weryfikacja_tytul"))
	var hd: Variant = _json("wyniki/hashdb.json")
	if hd == null:
		hd = _json("wyniki/hashdb_po_etapie2.json")
	if hd is Dictionary:
		var zg := int(hd.get("zgodne_md5", 0))
		var wsz := int(hd.get("rekordy", 0))
		hk[1].add_child(_status(zg > 0 and zg == wsz, tx.t("weryfikacja_wynik") % [zg, wsz]))
	else:
		hk[1].add_child(_l(tx.t("weryfikacja_brak"), 15, M.TEKST_PRZYGASZONY))
	hk[1].add_child(_l(tx.t("tylko_odczyt"), 13, M.TEKST_SLABY))
	v.add_child(hk[0])
	return _przewijana(v)


func _strona_mody() -> Control:
	var v := _vbox(14)
	_strona_naglowek(v, "mody", "mody")
	for m in stan.dostepne_mody:
		var k := _karta("mody" if m.typ != "informacyjny" else "informacje", String(m.nazwa))
		var aktywny := stan.mod_wlaczony(m.id)
		var typ := tx.t("typ_" + String(m.typ))
		k[1].add_child(_wiersz(tx.t("typ"), typ))
		k[1].add_child(_wiersz(tx.t("zrodlo"), String(m.zrodlo)))
		if String(m.opis) != "":
			k[1].add_child(_wiersz(tx.t("opis"), String(m.opis), M.TEKST_PRZYGASZONY))
		if m.typ == "nakladka":
			k[1].add_child(_status(m.dostepny, tx.t("mod_dostepny") if m.dostepny else tx.t("mod_niedostepny"), 14))
			var h := _hbox(10)
			if aktywny or m.id in stan.aktywne_mody():
				h.add_child(_przycisk(tx.t("usun_z_profilu"), "kosz", func(): stan.usun_mod(m.id, _nazwa_kopii()); _pokaz_strone(strona)))
			else:
				h.add_child(_przycisk(tx.t("dodaj_do_profilu"), "plus", func(): stan.dodaj_mod(m.id, _nazwa_kopii()); _pokaz_strone(strona), not m.dostepny))
			k[1].add_child(h)
		else:
			k[1].add_child(_l(tx.t("mod_informacyjny"), 13, M.TEKST_SLABY))
		v.add_child(k[0])
	var kp := _karta("informacje", tx.t("mody_plan_tytul"))
	var lp := _l(tx.t("mody_plan"), 14, M.TEKST_PRZYGASZONY)
	lp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kp[1].add_child(lp)
	v.add_child(kp[0])
	return _przewijana(v)


func _strona_profile() -> Control:
	var v := _vbox(14)
	_strona_naglowek(v, "profile", "profile")
	var h := _hbox(14)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(h)
	var kl := _karta("warstwy", tx.t("profile_lista"), 0.8)
	var lista := ItemList.new()
	lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lista.focus_mode = Control.FOCUS_NONE
	for i in stan.profile.size():
		var p: Dictionary = stan.profile[i]
		var idx := lista.add_item(StanLaunchera.tekst(p.nazwa, tx.jezyk), IkonyLaunchera.tekstura("warstwy" if p.get("wbudowany", false) else "profile", M.TEKST_PRZYGASZONY, 18))
		if p.id == stan.profil_id:
			lista.select(idx)
	lista.item_selected.connect(func(i): stan.wybierz_profil(stan.profile[i].id); _pokaz_strone(strona))
	kl[1].add_child(lista)
	var hb := _hbox(10)
	hb.add_child(_przycisk(tx.t("nowy"), "plus", _profil_nowy))
	hb.add_child(_przycisk(tx.t("klonuj"), "kopiuj", _profil_klonuj))
	hb.add_child(_przycisk(tx.t("usun"), "kosz", _profil_usun, stan.aktualny().get("wbudowany", true)))
	kl[1].add_child(hb)
	h.add_child(kl[0])
	var p := stan.aktualny()
	var wb: bool = p.get("wbudowany", false)
	var kp := _karta("ustawienia", tx.t("profil_szczegoly"), 1.2)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 10)
	kp[1].add_child(g)
	g.add_child(_l(tx.t("nazwa"), 15, M.TEKST_PRZYGASZONY))
	var le := LineEdit.new()
	le.text = StanLaunchera.tekst(p.nazwa, tx.jezyk)
	le.editable = not wb
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.text_submitted.connect(func(t): stan.zmien_nazwe_profilu(p.id, t); _pokaz_strone(strona))
	le.focus_exited.connect(func():
		if le.text != StanLaunchera.tekst(p.nazwa, tx.jezyk):
			stan.zmien_nazwe_profilu(p.id, le.text))
	g.add_child(le)
	g.add_child(_l(tx.t("zrodlo_danych"), 15, M.TEKST_PRZYGASZONY))
	var oz := OptionButton.new()
	oz.focus_mode = Control.FOCUS_NONE
	var nazwy := ["referencyjna", "spolecznosciowa"]
	for i in nazwy.size():
		oz.add_item(tx.t("zrodlo_" + nazwy[i]), i)
		oz.set_item_disabled(i, not K.instalacje.has(nazwy[i]))
		if nazwy[i] == p.get("zrodlo", ""):
			oz.select(i)
	oz.disabled = wb
	oz.item_selected.connect(func(i): stan.ustaw_pole_profilu("zrodlo", nazwy[i]); _pokaz_strone(strona))
	g.add_child(oz)
	g.add_child(_l(tx.t("zawartosc_gry"), 15, M.TEKST_PRZYGASZONY))
	var lg := _l(stan.nazwa_gry(stan.gra_id) + " — " + tx.t("gra_osobno"), 15)
	lg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_child(lg)
	g.add_child(_l(tx.t("mody_w_profilu"), 15, M.TEKST_PRZYGASZONY))
	var mods: Array = []
	for m in stan.aktywne_mody():
		mods.append(String(stan.mod(m).get("nazwa", m)) + ("" if stan.mod_wlaczony(m) else " (" + tx.t("wylaczony") + ")"))
	var lm := _l(", ".join(mods) if not mods.is_empty() else tx.t("brak"), 15)
	lm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_child(lm)
	g.add_child(_l(tx.t("warstwy_silnika"), 15, M.TEKST_PRZYGASZONY))
	g.add_child(_l(", ".join(K.aktywne_warstwy), 15, M.TEKST_PRZYGASZONY))
	if wb:
		var uw := _l(tx.t("profil_wbudowany_uwaga"), 13, M.TEKST_SLABY)
		uw.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		kp[1].add_child(uw)
	h.add_child(kp[0])
	return v


func _strona_ustawienia() -> Control:
	var v := _vbox(14)
	_strona_naglowek(v, "ustawienia", "ustawienia")
	var k := _karta("globus", tx.t("ust_launcher"))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 12)
	k[1].add_child(g)
	g.add_child(_l(tx.t("jezyk_ui"), 15, M.TEKST_PRZYGASZONY))
	var oj := OptionButton.new()
	oj.focus_mode = Control.FOCUS_NONE
	var kody := tx.jezyki()
	for i in kody.size():
		oj.add_icon_item(IkonyLaunchera.flaga(kody[i], 24, 16), tx.nazwa_jezyka(kody[i]), i)
		if kody[i] == tx.jezyk:
			oj.select(i)
	oj.item_selected.connect(func(i): _zmien_jezyk_ui(kody[i]))
	g.add_child(oj)
	g.add_child(_l(tx.t("skala_ui"), 15, M.TEKST_PRZYGASZONY))
	var sh := _hbox(10)
	var sl := HSlider.new()
	sl.min_value = 0.7; sl.max_value = 1.4; sl.step = 0.05
	sl.value = stan.skala_ui
	sl.custom_minimum_size.x = 260
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sv := _l("%d%%" % roundi(stan.skala_ui * 100), 15)
	sl.value_changed.connect(func(x): sv.text = "%d%%" % roundi(x * 100))
	sl.drag_ended.connect(func(_c): _zmien_skale(sl.value))
	sh.add_child(sl); sh.add_child(sv)
	g.add_child(sh)
	v.add_child(k[0])
	var kj := _karta("warstwy", tx.t("ust_jezyk_danych"))
	var opis := _l(tx.t("ust_jezyk_danych_opis"), 14, M.TEKST_PRZYGASZONY)
	opis.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kj[1].add_child(opis)
	var g2 := GridContainer.new()
	g2.columns = 2
	g2.add_theme_constant_override("h_separation", 16)
	g2.add_theme_constant_override("v_separation", 10)
	kj[1].add_child(g2)
	var pl_ok := stan.pl_dostepny()
	for pole in ["jezyk_tekstow", "jezyk_glosow", "jezyk_kampanii"]:
		g2.add_child(_l(tx.t(pole), 15, M.TEKST_PRZYGASZONY))
		var o := OptionButton.new()
		o.focus_mode = Control.FOCUS_NONE
		o.add_icon_item(IkonyLaunchera.flaga("pl", 24, 16), "Polski", 0)
		o.add_icon_item(IkonyLaunchera.flaga("en", 24, 16), "English", 1)
		o.set_item_disabled(0, not pl_ok)
		o.select(0 if String(K.get(pole)) == "pl" else 1)
		o.item_selected.connect(func(i): _zmien_jezyk_danych(pole, "pl" if i == 0 else "en"))
		g2.add_child(o)
	kj[1].add_child(_wiersz(tx.t("zrodlo_pl"), tx.t("zrodlo_" + K.zrodlo_pl) + (" – " + K.instalacje.get(K.zrodlo_pl, "") if pl_ok else "")))
	v.add_child(kj[0])
	var kc := _karta("folder", tx.t("ust_pliki"))
	kc[1].add_child(_wiersz("openee.cfg", K.plik_konfiguracji))
	kc[1].add_child(_wiersz("uzytkownik.cfg", K.plik_uzytkownika))
	var lc := _l(tx.t("ust_pliki_opis"), 13, M.TEKST_SLABY)
	lc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kc[1].add_child(lc)
	v.add_child(kc[0])
	return _przewijana(v)


func _strona_narzedzia() -> Control:
	var v := _vbox(14)
	_strona_naglowek(v, "narzedzia", "narzedzia")
	var k := _karta("graj", tx.t("narz_sceny"))
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	g.add_child(_przycisk(tx.t("tryb_scenariusz"), "graj", uruchom_tryb.bind(0)))
	g.add_child(_przycisk(tx.t("tryb_teren"), "graj", uruchom_tryb.bind(1)))
	g.add_child(_przycisk(tx.t("tryb_diagnostyka"), "graj", uruchom_tryb.bind(2)))
	k[1].add_child(g)
	k[1].add_child(_l(tx.t("narz_powrot"), 13, M.TEKST_SLABY))
	v.add_child(k[0])
	var kt := _karta("ok", tx.t("narz_testy"))
	var wt: Variant = _json("wyniki/testy_godot.json")
	if wt is Dictionary:
		var n: int = wt.get("testy", []).size()
		var bl := int(wt.get("bledy", 0))
		kt[1].add_child(_status(bl == 0, tx.t("narz_testy_wynik") % [n - bl, n]))
		kt[1].add_child(_l("wyniki/testy_godot.json · Godot " + String(wt.get("godot", "")), 13, M.TEKST_SLABY))
	else:
		kt[1].add_child(_l(tx.t("narz_testy_brak"), 15, M.TEKST_PRZYGASZONY))
	var bt := _przycisk(tx.t("narz_uruchom_testy"), "graj", _uruchom_testy)
	bt.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	kt[1].add_child(bt)
	v.add_child(kt[0])
	var kf := _karta("folder", tx.t("narz_foldery"))
	var hf := _hbox(10)
	for para in [["OpenEE", ""], ["wyniki", "wyniki"], ["docs", "docs"], ["konfiguracja", "konfiguracja"]]:
		var p: String = K.katalog_openee.path_join(para[1])
		hf.add_child(_przycisk(para[0], "folder", func(): OS.shell_open(p)))
	kf[1].add_child(hf)
	v.add_child(kf[0])
	return _przewijana(v)


func _strona_informacje() -> Control:
	var v := _vbox(14)
	_strona_naglowek(v, "informacje", "informacje")
	var k := _karta("logo", "OpenEE " + StanLaunchera.WERSJA)
	for klucz in ["info_opis", "info_dane", "info_licencja"]:
		var l := _l(tx.t(klucz), 15, M.TEKST_PRZYGASZONY)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		k[1].add_child(l)
	var s := stan.info_silnika()
	k[1].add_child(_wiersz(tx.t("renderer"), s.renderer + (" · " + s.karta if s.karta != "" else "")))
	k[1].add_child(_wiersz(tx.t("platforma"), s.platforma))
	k[1].add_child(_wiersz(tx.t("katalog"), K.katalog_openee))
	v.add_child(k[0])
	var ka := _karta("megafon", tx.t("aktualnosci_tytul"))
	for w in stan.aktualnosci():
		var h := _hbox(10)
		var t := _l(StanLaunchera.tekst(w.get("tytul", ""), tx.jezyk), 16, M.TEKST, "pogrubiona")
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(t)
		h.add_child(_l(String(w.get("data", "")), 13, M.TEKST_PRZYGASZONY))
		ka[1].add_child(h)
		var o := _l(StanLaunchera.tekst(w.get("tekst", ""), tx.jezyk), 14, M.TEKST_PRZYGASZONY)
		o.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ka[1].add_child(o)
	v.add_child(ka[0])
	var kd := _karta("folder", tx.t("info_dokumenty"))
	for d in ["RAPORT_ETAP_2.md", "RAPORT_LAUNCHER_UI.md", "docs/ARCHITEKTURA.md", "docs/LOKALIZACJA.md", "docs/FORMATY_ETAP2.md"]:
		var p: String = K.katalog_openee.path_join(d)
		if FileAccess.file_exists(p):
			var lb := LinkButton.new()
			lb.text = d
			lb.add_theme_color_override("font_color", M.AKCENT)
			lb.focus_mode = Control.FOCUS_NONE
			lb.pressed.connect(func(): OS.shell_open(p))
			kd[1].add_child(lb)
	v.add_child(kd[0])
	return _przewijana(v)


# ======================================================================== akcje

## Ścieżka do wyświetlenia: katalog domowy jako „~”.
func _krotka_sciezka(p: String) -> String:
	var dom := OS.get_environment("HOME")
	return "~" + p.substr(dom.length()) if dom != "" and p.begins_with(dom) else p


func _json(rel: String) -> Variant:
	var p: String = K.katalog_openee.path_join(rel)
	return JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else null


func _nazwa_kopii() -> String:
	return tx.t("kopia_profilu") % StanLaunchera.tekst(stan.aktualny().get("nazwa", ""), tx.jezyk)


func _profil_nowy() -> void:
	var n := 1
	while true:
		var nazwa := tx.t("profil_nowy_nazwa") % n
		var zajete := false
		for p in stan.profile:
			if StanLaunchera.tekst(p.nazwa, tx.jezyk) == nazwa:
				zajete = true
		if not zajete:
			stan.nowy_profil(nazwa)
			break
		n += 1
	_pokaz_strone(strona)


func _profil_klonuj() -> void:
	stan.klonuj_profil(_nazwa_kopii())
	_pokaz_strone(strona)


func _profil_usun() -> void:
	stan.usun_profil(stan.profil_id)
	_pokaz_strone(strona)


func _mod_akcja(co: String) -> void:
	if _lista_modow == null or _lista_modow.get_selected_items().is_empty():
		return
	var id := String(_lista_modow.get_item_metadata(_lista_modow.get_selected_items()[0]))
	match co:
		"gora": stan.przesun_mod(id, -1, _nazwa_kopii())
		"dol": stan.przesun_mod(id, 1, _nazwa_kopii())
		"przelacz": stan.przelacz_mod(id, _nazwa_kopii())
		"usun": stan.usun_mod(id, _nazwa_kopii())
	_pokaz_strone(strona)


func _zmien_jezyk_ui(kod: String) -> void:
	if _bez_zapisu:
		stan.jezyk_ui = kod
	else:
		stan.ustaw_jezyk_ui(kod)
	tx.ustaw(kod)
	_zbuduj()


func _zmien_skale(v: float) -> void:
	stan.ustaw_skale_ui(v)
	get_window().content_scale_size = Vector2i(Vector2(BAZA) / stan.skala_ui)


func _zmien_jezyk_danych(pole: String, kod: String) -> void:
	K.zapisz_uzytkownika({"lokalizacja/" + pole: kod})
	Z.przebuduj_zrodla()
	_pokaz_strone(strona)


func _wybierz_sciezke(nazwa: String) -> void:
	var d := FileDialog.new()
	d.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	d.access = FileDialog.ACCESS_FILESYSTEM
	d.title = tx.t("wybierz_katalog") % (tx.t("zrodlo_" + nazwa) if tx.ma("zrodlo_" + nazwa, tx.jezyk) else nazwa)
	var obecna: String = K.instalacje.get(nazwa, "")
	d.current_dir = obecna if obecna != "" else OS.get_environment("HOME")
	# systemowe okno wyboru (KDE/GNOME przez portal XDG) – w języku systemu; gdy niedostępne – okno Godota po polsku
	d.use_native_dialog = DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE) and _arg("bez-natywnych") == ""
	d.ok_button_text = tx.silnik("Select Current Folder")
	d.cancel_button_text = tx.silnik("Cancel")
	d.min_size = Vector2i(820, 520)
	d.dir_selected.connect(func(p):
		var w := stan.ustaw_sciezke_instalacji(nazwa, p)
		if not w.get("ok", false):
			_komunikat(tx.t("blad"), tx.t("katalog_nie_ee") % p)
		_zbuduj()
		d.queue_free())
	d.canceled.connect(d.queue_free)
	add_child(d)
	d.popup_centered_ratio(0.7)
	_okno_katalogu = d


func _komunikat(tytul: String, tekst: String) -> void:
	if _okno_info and is_instance_valid(_okno_info):
		_okno_info.queue_free()
	_okno_info = AcceptDialog.new()
	_okno_info.title = tytul
	_okno_info.dialog_text = tekst
	_okno_info.dialog_autowrap = true
	_okno_info.min_size = Vector2i(520, 160)
	_okno_info.ok_button_text = tx.silnik("OK")
	add_child(_okno_info)
	_okno_info.popup_centered()


## Główny przycisk. Przygotowany pod przyszłą logikę: OpenEE → tryb domyślny (scenariusz testowy),
## oryginalna gra → hak _uruchom_oryginalna_gre() (jeszcze niepodpięty).
func uruchom() -> void:
	if stan.uzyj_openee:
		uruchom_tryb(0)
	else:
		_uruchom_oryginalna_gre()


func uruchom_tryb(id: int) -> void:
	var sceny := {0: "res://sceny/test_scenariusz.tscn", 1: "res://sceny/test_teren.tscn", 2: "res://sceny/diagnostyka.tscn"}
	if id == 3:
		_uruchom_oryginalna_gre()
		return
	if not sceny.has(id):
		return
	if not stan.info_instalacji().ok and id != 2:
		_komunikat(tx.t("blad"), tx.t("brak_instalacji_start"))
		return
	var w := get_window()
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	w.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	var powrot = load("res://launcher/powrot.gd").new()
	powrot.napis = tx.t("powrot")
	get_tree().root.add_child(powrot)
	get_tree().change_scene_to_file(sceny[id])


## Hak pod uruchamianie oryginalnego EE (Wine/proton) – celowo niepodpięty na tym etapie.
func _uruchom_oryginalna_gre() -> void:
	_komunikat(tx.t("uruchom"), tx.t("oryginal_niepodpiety"))


func _uruchom_testy() -> void:
	var pid := OS.create_process(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://testy/uruchom_testy.gd"])
	_komunikat(tx.t("narz_testy"), tx.t("narz_testy_uruchomione") % pid if pid > 0 else tx.t("narz_testy_blad"))


# ======================================================================== grafiki

func _wczytaj_grafiki_gry() -> void:
	if not stan.info_instalacji().ok:
		return
	# baner z instalacji gry potrzebny tylko jako wariant zastępczy (gdy brak grafiki referencyjnej nagłówka)
	var b: Image = null
	if not FileAccess.file_exists(K.katalog_openee.path_join("dane/launcher/grafika/baner_en.png")):
		b = GrafikiGry.obraz("baner", Z, K.katalog_cache)
	if b:
		b.generate_mipmaps()
		_obraz_baner = ImageTexture.create_from_image(b)
	var o := GrafikiGry.obraz("okladka", Z, K.katalog_cache)
	if o:
		o.generate_mipmaps()
		_obraz_okladka = ImageTexture.create_from_image(o)


## Podgląd: najnowszy zrzut z testu graficznego OpenEE (wyniki/test_graficzny_etap2), jeśli istnieje.
func _wczytaj_podglad() -> Texture2D:
	for nazwa in ["test_graficzny_etap3/aoc_rzym_ogolny.png", "test_graficzny_etap2/scenariusz_jednostki_zblizenie.png", "test_graficzny_etap2/scenariusz_ogolny.png"]:
		var p: String = K.katalog_openee.path_join("wyniki/" + nazwa)
		if FileAccess.file_exists(p):
			var img := Image.load_from_file(p)
			if img:
				# górny pasek zrzutu zawiera tekst diagnostyczny sceny testowej – przycinamy go
				var h := img.get_height()
				img = img.get_region(Rect2i(0, int(h * 0.16), img.get_width(), h - int(h * 0.16)))
				img.generate_mipmaps()
				return ImageTexture.create_from_image(img)
	return null
