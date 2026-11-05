# Mapa drogowa OpenEE

Kolejność orientacyjna; każdy etap kończy się testami, dokumentacją i weryfikacją, że w zmianach nie ma zasobów gry.

## Zrobione w 0.4.0-dev (etap 4)
* Animacje modeli CEM (klatki, sekwencje dbgraphics), modele potomne z transformacjami, odtwarzacz instancji.
* Animacja wody (klatki i tempo z dbterrain; bez tabeli faz 33×33).
* Szybsza dekompresja DCL w GDScript (3×).

## Zrobione w 0.5.0-dev (etap 5)
* Symulacja jednostek (stały krok), nawigacja z danych mapy, A*, zaznaczanie i rozkaz ruchu, animacje ruchu.
* Poziom wody = 0 z klas głębokości punktów.

## Najbliżej (0.5.x / 0.6)
* Zaznaczanie grupowe, kolejki rozkazów, unikanie kolizji i formacje, szybsze trasy (hierarchiczne/GDExtension po pomiarach).
* Rozróżnienie nawierzchni lądu (flagi dbobjects ↔ typy terenu), znaczenie progu wody płytkiej, tempo symulacji.
* Porównanie wizualne z oryginalnym EE – skrypt izolowanego środowiska gotowy (`narzedzia/izolowane_ee.sh`); w piaskownicy
  sesji Claude zablokowane przez seccomp – do uruchomienia w środowisku bez filtra (po zgodzie); rozstrzygnięcie tempa
  animacji, interpolacji i skrętności obrazu.
* Sterowanie proceduralne części (orbital_*, wieżyczki, koła), znaczenie gniazda 3 i parametru sekwencji.
* Tabela faz wody 33×33, ściany brzegowe mapy, mapy kosmiczne.
* Pełny odczyt listy celów jednostki (3 scenariusze EE).
* Pamięć podręczna rozpakowanych danych (gdy wczytywanie pełnych map będzie wąskim gardłem).

## Dalej (0.5–0.7)
* Kamera i sterowanie jak w grze, zaznaczanie jednostek, minimapa.
* Ruch jednostek po siatce terenu, znajdowanie ścieżek.
* Interfejs gry (panele, przyciski z tabel UI), dźwięki zdarzeń.
* Menedżer modów (katalog `mody/`, manifesty, kolejność ładowania).

## Długoterminowo
* Ekonomia, budowanie, walka, epoki – zgodnie z tabelami gry.
* SI przeciwników, scenariusze i kampanie grywalne.
* Tryb wieloosobowy.

Nie deklarujemy terminów; priorytetem jest zgodność z danymi oryginalnej gry i rozróżnianie faktów od hipotez.
