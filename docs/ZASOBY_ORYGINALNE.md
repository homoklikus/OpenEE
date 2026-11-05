# Zasady korzystania z oryginalnych zasobów Empire Earth

## Zasada ogólna
OpenEE nie zawiera i nie rozpowszechnia żadnych zasobów Empire Earth. Silnik wczytuje je **w czasie działania, bez
kopiowania**, z instalacji wskazanej przez użytkownika, otwieranej wyłącznie do odczytu. Użytkownik odpowiada za to, by
posiadana instalacja była legalna (np. zakupiona wersja GOG Empire Earth Gold Edition).

## Czego nie ma i nie może być w repozytorium
* archiwów `*.ssa`, modeli `*.cem`, tekstur `*.sst/*.tga`, dźwięków i muzyki, filmów, plików `*.exe/*.dll`,
* tekstów gry (np. zawartości `Language.dll`, list napisów), tabel `db*.dat` ani ich pełnych zrzutów,
* scenariuszy i map z gry,
* polskiego dubbingu i innych zasobów lokalizacji z instalacji społecznościowych,
* zrzutów ekranu i grafik wygenerowanych z zasobów gry,
* manifestów i inwentarzy instalacji (listy plików i sum kontrolnych konkretnej instalacji).

## Dane generowane lokalnie
Część funkcji i testów korzysta z plików tworzonych z instalacji użytkownika (`narzedzia/przygotuj_dane_lokalne.sh`):

| Plik / katalog | Zawartość | Publikacja |
|---|---|---|
| `cache/` | rozpakowane/złożone grafiki (np. tło launchera z ekranów gry), dane testu graficznego | nie |
| `wyniki/` | wyniki testów, zrzuty ekranu, pomiary | nie |
| `audyt/` | inwentarze, porównania i manifesty warstw instalacji | nie |
| `dane/lokalizacja/<język>/manifest.json` | odniesienia do nagrań i tekstów wersji językowej w instalacji | nie |
| `konfiguracja/uzytkownik.cfg`, `profile_uzytkownika.json` | ustawienia użytkownika | nie |

Wszystkie są wykluczone w `.gitignore`; przed każdym commitem sprawdzamy też faktyczną listę plików.

## Co jest w repozytorium
* kod silnika (Godot/GDScript), narzędzia (Python, C), testy,
* własna dokumentacja formatów (opisy własnymi słowami, bez kodu z dekompilacji),
* opis rekordu jednostki scenariusza (`dane/gramatyka_jednostki.json`) – nazwy i typy pól ustalone analizą,
* schemat pól tabel z projektu EE DB Editor (GPLv3) i wygenerowany z niego `dane/uklad_db.json` (bez danych z tabel),
* własne pliki interfejsu launchera (teksty, profile, grafika nagłówka – patrz `dane/launcher/grafika/ZRODLO.md`).

## Lokalizacja polska
Polska wersja językowa jest czytana z instalacji użytkownika (np. wydania z polskim dubbingiem). OpenEE przechowuje tylko
odniesienia (klucze wpisów i sumy kontrolne) – generowane lokalnie i niepublikowane. Szczegóły: [LOKALIZACJA.md](LOKALIZACJA.md).

## Analiza oryginalnego silnika
Reguły (np. mieszanie tekstur terenu) ustalono analizą plików i kodu gry w celu zapewnienia zgodności. Do OpenEE trafiają
wyłącznie opisy i własne implementacje – nie kod ani fragmenty dekompilacji.
