class_name IkonyLaunchera
## Ikony launchera – własne, proste rysunki SVG (linie 24×24, styl „outline”), renderowane w locie w potrzebnej skali,
## więc są ostre także przy HiDPI. Nie pochodzą z żadnego zestawu zewnętrznego.

const _SCIEZKI := {
	"start": "<path d='M3 11 12 3.5 21 11'/><path d='M5.5 9.5V20.5h5v-6h3v6h5V9.5'/>",
	"gra": "<rect x='2.5' y='7' width='19' height='11' rx='5.5'/><path d='M7.5 10.5v4M5.5 12.5h4'/><circle cx='15.5' cy='11.5' r='.9' fill='C'/><circle cx='18' cy='13.8' r='.9' fill='C'/>",
	"mody": "<path d='M9 3.5h3.2a2 2 0 1 1 3.6 0H19v3.8a2 2 0 1 1 0 3.6V15h-3.4a2 2 0 1 0-3.6 0H9v-3.6a2 2 0 1 1 0-3.8z'/><path d='M5 13.5v7h7'/>",
	"profile": "<circle cx='9' cy='8' r='3.5'/><path d='M2.5 20c0-3.6 2.9-6 6.5-6s6.5 2.4 6.5 6'/><circle cx='17' cy='9' r='2.6'/><path d='M16.5 14.2c2.9.2 5 2.3 5 5.3'/>",
	"ustawienia": "<circle cx='12' cy='12' r='3.2'/><path d='M12 2.5v3M12 18.5v3M2.5 12h3M18.5 12h3M5.3 5.3l2.1 2.1M16.6 16.6l2.1 2.1M5.3 18.7l2.1-2.1M16.6 7.4l2.1-2.1'/><circle cx='12' cy='12' r='6.5'/>",
	"narzedzia": "<path d='M14.5 6.5a4 4 0 0 0 5 5l-9 9a2.1 2.1 0 0 1-3-3l9-9a4 4 0 0 0-2-2z'/><path d='M14.5 6.5 17 4l3 3-2.5 2.5'/><path d='M4 4l5 5'/><path d='M3 7l4-4'/>",
	"informacje": "<circle cx='12' cy='12' r='9.5'/><path d='M12 11v6'/><circle cx='12' cy='7.6' r='.9' fill='C'/>",
	"warstwy": "<path d='M12 3 21.5 8 12 13 2.5 8z'/><path d='M2.5 12 12 17l9.5-5'/><path d='M2.5 16 12 21l9.5-5'/>",
	"globus": "<circle cx='12' cy='12' r='9.5'/><path d='M2.5 12h19'/><ellipse cx='12' cy='12' rx='4.2' ry='9.5'/>",
	"megafon": "<path d='M3.5 9.5v5h3l8 4.5v-14l-8 4.5z'/><path d='M6.5 14.5l1.5 5h2.5l-1-4.4'/><path d='M18 8.5a5 5 0 0 1 0 7'/>",
	"silnik": "<circle cx='12' cy='12' r='3'/><path d='M10.3 2.8h3.4l.6 2.6 2 .9 2.3-1.4 2.4 2.4-1.4 2.3.9 2 2.6.6v3.4l-2.6.6-.9 2 1.4 2.3-2.4 2.4-2.3-1.4-2 .9-.6 2.6h-3.4l-.6-2.6-2-.9-2.3 1.4-2.4-2.4 1.4-2.3-.9-2-2.6-.6v-3.4l2.6-.6.9-2-1.4-2.3 2.4-2.4 2.3 1.4 2-.9z'/>",
	"folder": "<path d='M2.5 6.5a1.5 1.5 0 0 1 1.5-1.5h5l2 2.2h9a1.5 1.5 0 0 1 1.5 1.5V18a1.5 1.5 0 0 1-1.5 1.5H4A1.5 1.5 0 0 1 2.5 18z'/>",
	"plus": "<path d='M12 5v14M5 12h14'/>",
	"kopiuj": "<rect x='8.5' y='8.5' width='12' height='12' rx='1.5'/><path d='M15.5 8.5v-4a1 1 0 0 0-1-1h-10a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h4'/>",
	"kosz": "<path d='M4 6.5h16M9.5 6.5V4h5v2.5'/><path d='M6 6.5l1 14h10l1-14'/><path d='M10 10.5v6M14 10.5v6'/>",
	"gora": "<path d='M12 20V4.5M5.5 11 12 4.5 18.5 11'/>",
	"dol": "<path d='M12 4v15.5M5.5 13 12 19.5 18.5 13'/>",
	"wylacz": "<path d='M9 3.5h3.2a2 2 0 1 1 3.6 0H19v3.8a2 2 0 1 1 0 3.6V15h-3.4a2 2 0 1 0-3.6 0H9v-3.6a2 2 0 1 1 0-3.8z'/><path d='M3 3l18 18'/>",
	"graj": "<path d='M7 4.5v15l12.5-7.5z' fill='C'/>",
	"rozwin": "<path d='M6 9.5l6 6 6-6'/>",
	"ok": "<circle cx='12' cy='12' r='10' fill='C' stroke='none'/><path d='M7.5 12.3l3 3 6-6.3' stroke='#0d1a12' stroke-width='2.4'/>",
	"uwaga": "<circle cx='12' cy='12' r='10' fill='C' stroke='none'/><path d='M12 7v6.5' stroke='#1a1208' stroke-width='2.4'/><circle cx='12' cy='17' r='1.3' fill='#1a1208' stroke='none'/>",
	"obraz": "<rect x='3' y='4.5' width='18' height='15' rx='2'/><circle cx='9' cy='10' r='1.8'/><path d='M3.5 17.5 9 13l4 3 3-2.5 4.5 3.5'/>",
	"zaznaczone": "<rect x='2' y='2' width='20' height='20' rx='4' fill='C' stroke='none'/><path d='M6.5 12.3l3.6 3.6 7.4-7.6' stroke='#ffffff' stroke-width='2.6'/>",
	"niezaznaczone": "<rect x='3' y='3' width='18' height='18' rx='3.5'/>",
	"radio_on": "<circle cx='12' cy='12' r='9'/><circle cx='12' cy='12' r='4.5' fill='C' stroke='none'/>",
	"radio_off": "<circle cx='12' cy='12' r='9'/>",
	"strzalka": "<path d='M5 12h14M13 6l6 6-6 6'/>",
	"wstecz": "<path d='M19 12H5M11 6l-6 6 6 6'/>",
	"wylacz_x": "<path d='M6 6l12 12M18 6 6 18'/>",
	"logo": "<path d='M12 2.5 20.5 7v10L12 21.5 3.5 17V7z'/><path d='M12 2.5v19M3.5 7 12 12l8.5-5'/>",
}

static var _pamiec := {}


## Tekstura ikony w kolorze `kolor`, o boku `rozmiar` pikseli logicznych (renderowana ×`nadprobkowanie`).
static func tekstura(nazwa: String, kolor: Color, rozmiar: int = 22, nadprobkowanie: float = 3.0) -> Texture2D:
	var klucz := "%s|%s|%d|%.1f" % [nazwa, kolor.to_html(), rozmiar, nadprobkowanie]
	if _pamiec.has(klucz):
		return _pamiec[klucz]
	var c := "#" + kolor.to_html(false)
	var tresc := String(_SCIEZKI.get(nazwa, _SCIEZKI["obraz"])).replace("'C'", "'%s'" % c)
	var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' stroke='%s' stroke-width='1.7' stroke-linecap='round' stroke-linejoin='round' opacity='%.3f'>%s</svg>" % [c, kolor.a, tresc]
	var img := Image.new()
	var e := img.load_svg_from_string(svg, rozmiar / 24.0 * nadprobkowanie)
	if e != OK:
		img = Image.create(rozmiar, rozmiar, false, Image.FORMAT_RGBA8)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	t.set_size_override(Vector2i(rozmiar, rozmiar))   # dane w wyższej rozdzielczości, rozmiar logiczny = rozmiar
	_pamiec[klucz] = t
	return t


static func nazwy() -> Array:
	return _SCIEZKI.keys()


## Flagi (rysunek uproszczony): "pl", "en", "pl_en" (pół na pół).
static func flaga(kod: String, szer: int = 30, wys: int = 20, nadprobkowanie: float = 3.0) -> Texture2D:
	var klucz := "flaga|%s|%d|%d" % [kod, szer, wys]
	if _pamiec.has(klucz):
		return _pamiec[klucz]
	var pl := "<rect width='30' height='10' fill='#f4f4f4'/><rect y='10' width='30' height='10' fill='#dc143c'/>"
	var en := "<rect width='30' height='20' fill='#1f3d8a'/><path d='M0 0 30 20M30 0 0 20' stroke='#fff' stroke-width='4'/><path d='M0 0 30 20M30 0 0 20' stroke='#c8102e' stroke-width='1.6'/><path d='M15 0v20M0 10h30' stroke='#fff' stroke-width='6'/><path d='M15 0v20M0 10h30' stroke='#c8102e' stroke-width='3.4'/>"
	var tresc := pl if kod == "pl" else (en if kod == "en" else "<g>%s</g><g clip-path='url(#p)'>%s</g><clipPath id='p'><rect x='15' width='15' height='20'/></clipPath>" % [pl, en])
	var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='30' height='20' viewBox='0 0 30 20'>%s<rect x='.25' y='.25' width='29.5' height='19.5' fill='none' stroke='#000' stroke-opacity='.35' stroke-width='.5'/></svg>" % tresc
	var img := Image.new()
	img.load_svg_from_string(svg, szer / 30.0 * nadprobkowanie)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	t.set_size_override(Vector2i(szer, wys))
	_pamiec[klucz] = t
	return t
