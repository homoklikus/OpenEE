extends Node
## Dziennik OpenEE – podstawowy system logowania i diagnostyki.
## Poziomy: DEBUG < INFO < UWAGA < BLAD. Wpisy trafiają do konsoli, do pliku user://logi/
## oraz do bufora pierścieniowego (dla ekranu diagnostyki i testów).

enum Poziom { DEBUG, INFO, UWAGA, BLAD }
const NAZWY := ["DEBUG", "INFO", "UWAGA", "BŁĄD"]
const ROZMIAR_BUFORA := 500

var poziom_minimalny: int = Poziom.INFO
var _bufor: Array[String] = []
var _plik: FileAccess = null
var liczniki := {"DEBUG": 0, "INFO": 0, "UWAGA": 0, "BŁĄD": 0}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://logi")
	var nazwa := "user://logi/openee_%s.log" % Time.get_datetime_string_from_system().replace(":", "-")
	_plik = FileAccess.open(nazwa, FileAccess.WRITE)
	info("dziennik", "Start OpenEE, Godot %s, plik dziennika: %s" % [Engine.get_version_info().string, ProjectSettings.globalize_path(nazwa)])


func zapisz(poziom: int, modul: String, tekst: String) -> void:
	if poziom < poziom_minimalny:
		return
	var linia := "%s [%s] %s: %s" % [Time.get_time_string_from_system(), NAZWY[poziom], modul, tekst]
	liczniki[NAZWY[poziom]] += 1
	_bufor.append(linia)
	if _bufor.size() > ROZMIAR_BUFORA:
		_bufor.pop_front()
	if poziom >= Poziom.UWAGA:
		printerr(linia)
	else:
		print(linia)
	if _plik:
		_plik.store_line(linia)
		_plik.flush()


func debug(modul: String, tekst: String) -> void: zapisz(Poziom.DEBUG, modul, tekst)
func info(modul: String, tekst: String) -> void: zapisz(Poziom.INFO, modul, tekst)
func uwaga(modul: String, tekst: String) -> void: zapisz(Poziom.UWAGA, modul, tekst)
func blad(modul: String, tekst: String) -> void: zapisz(Poziom.BLAD, modul, tekst)


func ostatnie(n: int = 50) -> Array[String]:
	return _bufor.slice(max(0, _bufor.size() - n))
