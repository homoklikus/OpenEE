class_name ImporterEE
extends RefCounted
## Interfejs importera zasobu Empire Earth.
##
## Każdy importer:
##  * deklaruje obsługiwane rozszerzenia (`rozszerzenia()`),
##  * przyjmuje surowe bajty pliku (już rozpakowane z PK01 przez system zasobów),
##  * zwraca obiekt Godota (Image, ArrayMesh, Dictionary z danymi) albo null + wpis w dzienniku,
##  * NIE czyta plików samodzielnie – dostęp do danych wyłącznie przez Zasoby (warstwy, VFS),
##  * jest deterministyczny i bezstanowy (może działać w wątku roboczym).
## Wyniki mogą być zapisywane w cache OpenEE (wersje pośrednie), nigdy w instalacji EE.

func nazwa() -> String:
	return "abstrakcyjny"


func rozszerzenia() -> PackedStringArray:
	return PackedStringArray()


## kontekst: {"klucz": String, "zasoby": Node} – zasoby pozwalają importerowi dociągnąć zależności
## (np. tekstury modelu) przez ten sam mechanizm warstw.
func importuj(_dane: PackedByteArray, _kontekst: Dictionary) -> Variant:
	push_error("ImporterEE.importuj() nie zaimplementowany w %s" % nazwa())
	return null


## Zgłoszenie błędu do Dziennika (jeśli działa) albo do konsoli Godota – importery nie zależą
## bezpośrednio od autoloadów, dzięki czemu działają też w narzędziach i testach bez sceny.
static func zglos(poziom: String, modul: String, tekst: String) -> void:
	var ml := Engine.get_main_loop()
	var d: Node = null
	if ml is SceneTree:
		d = (ml as SceneTree).root.get_node_or_null("Dziennik")
	if d:
		d.call(poziom, modul, tekst)
	elif poziom == "blad":
		push_error("%s: %s" % [modul, tekst])
	else:
		print("%s: %s" % [modul, tekst])
