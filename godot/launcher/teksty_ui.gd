class_name TekstyUI
## Teksty interfejsu launchera. Jeden plik JSON na język: <OpenEE>/dane/launcher/i18n/<kod>.json
## ({"_nazwa": "Polski", "klucz": "tekst", ...}). Nowy język = nowy plik – wykrywany automatycznie.
## Brak klucza w wybranym języku → angielski → sam klucz (i wpis w dzienniku).
## Język UI launchera jest niezależny od języka danych gry ([lokalizacja] w konfiguracji).

var jezyk := "pl"
var _teksty := {}      # kod -> {klucz: tekst}
var _zglos_braki := {}


func wczytaj(katalog: String) -> void:
	_teksty.clear()
	if not DirAccess.dir_exists_absolute(katalog):
		return
	for f in DirAccess.get_files_at(katalog):
		if f.ends_with(".json"):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(katalog.path_join(f)))
			if d is Dictionary:
				_teksty[f.get_basename()] = d


## Tłumaczenia wbudowanych kontrolek Godota (okno plików, menu pól tekstowych, OK/Anuluj):
## <katalog>/godot/<kod>.json {tekst angielski: tłumaczenie}. Rejestrowane w TranslationServer – działają tam, gdzie silnik
## tłumaczy swoje teksty; dodatkowo launcher ustawia teksty przycisków okien jawnie.
var _silnik := {}


func wczytaj_tlumaczenia_silnika(katalog: String) -> void:
	_silnik.clear()
	if not DirAccess.dir_exists_absolute(katalog):
		return
	for f in DirAccess.get_files_at(katalog):
		if not f.ends_with(".json"):
			continue
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(katalog.path_join(f)))
		if not d is Dictionary:
			continue
		var tr := Translation.new()
		tr.locale = f.get_basename()
		for k in d:
			if not String(k).begins_with("_"):
				tr.add_message(String(k), String(d[k]))
		TranslationServer.add_translation(tr)
		_silnik[tr.locale] = d


## Tekst wbudowanej kontrolki w języku UI (np. do jawnego ustawienia przycisków okien).
func silnik(tekst_en: String) -> String:
	return String(_silnik.get(jezyk, {}).get(tekst_en, tekst_en))


func jezyki() -> Array:
	var k := _teksty.keys()
	k.sort()
	return k


func nazwa_jezyka(kod: String) -> String:
	return String(_teksty.get(kod, {}).get("_nazwa", kod))


func ustaw(kod: String) -> void:
	jezyk = kod if _teksty.has(kod) else ("en" if _teksty.has("en") else kod)
	TranslationServer.set_locale(jezyk)   # język wbudowanych kontrolek Godota = język UI launchera


func t(klucz: String, argumenty: Variant = null) -> String:
	var s: Variant = _teksty.get(jezyk, {}).get(klucz)
	if s == null:
		s = _teksty.get("en", {}).get(klucz)
		if not _zglos_braki.has(jezyk + klucz):
			_zglos_braki[jezyk + klucz] = true
			print_verbose("TekstyUI: brak '%s' w '%s'" % [klucz, jezyk])
	if s == null:
		return klucz
	if argumenty != null:
		return String(s) % argumenty
	return String(s)


func ma(klucz: String, kod: String) -> bool:
	return _teksty.get(kod, {}).has(klucz)


func klucze(kod: String) -> Array:
	return _teksty.get(kod, {}).keys()
