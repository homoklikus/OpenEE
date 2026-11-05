class_name GrafikiGry
## Grafiki launchera pobierane w locie z instalacji gry użytkownika (tylko odczyt):
## ekrany menu/splash EE i AoC są w archiwach pocięte na 3×4 tekstury 256×256 – składamy je w jeden obraz.
## Wynik trafia do <OpenEE>/cache/launcher/<nazwa>.png (pamięć podręczna – tylko lokalnie, nie rozpowszechniać).
## Brak instalacji → null (launcher pokazuje grafikę zastępczą rysowaną w kodzie).

const ZESTAWY := {
	"baner": [["textures/bkg_caesar_battle_%d_%d.tga", 3, 4], ["textures/mainmenuback_%d_%d.sst", 3, 4]],
	"okladka": [["textures/splash_%d_%d.sst", 3, 4]],
}


static func obraz(nazwa: String, zasoby: Node, katalog_cache: String) -> Image:
	var plik := katalog_cache.path_join("launcher/%s.png" % nazwa)
	if FileAccess.file_exists(plik):
		var img := Image.load_from_file(plik)
		if img and not img.is_empty():
			return img
	if zasoby == null or not zasoby.has_method("wczytaj_teksture"):
		return null
	for z in ZESTAWY.get(nazwa, []):
		var img := _sklej(zasoby, z[0], z[1], z[2])
		if img:
			DirAccess.make_dir_recursive_absolute(plik.get_base_dir())
			img.save_png(plik)
			return img
	return null


static func _sklej(zasoby: Node, wzor: String, wiersze: int, kolumny: int) -> Image:
	var kafle := []
	for r in range(1, wiersze + 1):
		for c in range(1, kolumny + 1):
			var k: Image = zasoby.wczytaj_teksture(wzor % [r, c])
			if k == null:
				return null
			k = k.duplicate()
			k.clear_mipmaps()
			if k.is_compressed():
				k.decompress()
			k.convert(Image.FORMAT_RGBA8)
			kafle.append(k)
	var w: int = kafle[0].get_width(); var h: int = kafle[0].get_height()
	var out := Image.create(w * kolumny, h * wiersze, false, Image.FORMAT_RGBA8)
	for i in kafle.size():
		out.blit_rect(kafle[i], Rect2i(0, 0, w, h), Vector2i((i % kolumny) * w, (i / kolumny) * h))
	return out
