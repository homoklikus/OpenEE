# Mapa drogowa OpenEE

Kolejność orientacyjna; każdy etap kończy się testami, dokumentacją i weryfikacją, że w zmianach nie ma zasobów gry.

## Zrobione w 0.4.0-dev (etap 4)
* Animacje modeli CEM (klatki, sekwencje dbgraphics), modele potomne z transformacjami, odtwarzacz instancji.
* Animacja wody (klatki i tempo z dbterrain; bez tabeli faz 33×33).
* Szybsza dekompresja DCL w GDScript (3×).

## Zrobione w 0.5.0-dev (etap 5)
* Symulacja jednostek (stały krok), nawigacja z danych mapy, A*, zaznaczanie i rozkaz ruchu, animacje ruchu.
* Poziom wody = 0 z klas głębokości punktów.

## Zrobione w 0.5.1-dev (naprawa grafiki)
* Poprawny import modeli wielomateriałowych (indeksy względne, obraz wg `tekstura_id`), kolor gracza przez mnożenie.

## Zrobione w 0.5.2-dev (diagnostyka modeli)
* Tryb diagnostyczny modelu, porównanie rendererów; poprawki alfa, odrzucania ścian, billboardów i głębi.
* Do potwierdzenia na GPU użytkownika (test wyłącznie w środowisku wirtualnym: llvmpipe/lavapipe). *(Od etapu 6 rendery
  sprawdzane na RTX 5090 przez Riverlands_MCP `oe_render`.)*

## Zrobione w etapach 6–13
* Kamera wierna EE (6, 10), układ współrzędnych bez odbicia (7), epoki i przezroczystość budynków (8).
* Zaznaczanie grupowe, szyk, kolejka rozkazów, trasy oktylowe (9); kolizje według oryginału – przenikanie i objazd
  stojących (13); prędkość z tempa czasu gry (13).
* Dwie gry na jednym silniku (11), pomiary mechanik EE i AoC (12), start oryginałów bez filmów do pomiarów (13).
* Porządki i dokument orientacyjny `docs/ARCHITEKTURA_OPENEE.md` (13.5).

## Najbliżej (0.5.x / 0.6)
* Atlas funkcji silnika Titan (`docs/titan/`) – analiza podsystemów przed implementacją rozgrywki.
* Formacje z przycisków i tryb Szybko/Sprytnie, ponowne wyznaczanie trasy przy przeszkodzie, szybsze trasy
  (hierarchiczne/GDExtension po pomiarach).
* Rozróżnienie nawierzchni lądu (flagi dbobjects ↔ typy terenu), znaczenie progu wody płytkiej, tempo symulacji.
* Rozstrzygnięcie tempa animacji i interpolacji w oryginale (porównania kadrów EE ↔ OpenEE działają przez
  Riverlands_MCP od etapu 6; skrętność obrazu rozstrzygnięta w etapie 7).
* Sterowanie proceduralne części (orbital_*, wieżyczki, koła), znaczenie gniazda 3 i parametru sekwencji.
* Tabela faz wody 33×33, ściany brzegowe mapy, mapy kosmiczne.
* Pełny odczyt listy celów jednostki (3 scenariusze EE).
* Pamięć podręczna rozpakowanych danych (gdy wczytywanie pełnych map będzie wąskim gardłem).

## Dalej (0.5–0.7)
* Minimapa.
* Interfejs gry (panele, przyciski z tabel UI), dźwięki zdarzeń.
* Menedżer modów (katalog `mody/`, manifesty, kolejność ładowania).

## Długoterminowo
* Ekonomia, budowanie, walka, epoki – zgodnie z tabelami gry.
* SI przeciwników, scenariusze i kampanie grywalne.
* Tryb wieloosobowy.

Nie deklarujemy terminów; priorytetem jest zgodność z danymi oryginalnej gry i rozróżnianie faktów od hipotez.
