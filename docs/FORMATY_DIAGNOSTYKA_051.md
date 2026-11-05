# OpenEE – modele CEM: ustalenia diagnostyki 0.5.1 → 0.5.2-dev

Oznaczenia: [D] potwierdzone na danych, [H] hipoteza OpenEE. Ustalenia pochodzą ze statystyki plików gry
(narzędzia `godot/narzedzia/statystyka_geometrii.gd`, `narzedzia/kierunek_billboardow.py`, `narzedzia/statystyka_alfa.py`),
bez dekompilacji. Próbka geometrii: 150 pierwszych par model/tekstura z `dbgraphics` (37 019 trójkątów).

## 1. Kanał alfa wycina we wszystkich materiałach, także „player color” [D]
* Tekstury modeli są 32-bitowe; teksele z alfa = 0 mają kolor czarny (99,8% próbek).
* Trójkąty materiału „player color” leżą w obszarach o kształcie wyznaczonym przez alfę (emblemat „X” koszar
  `bld_barracks_01`, haki `bld_dock_02`, kraty i ramy `bld_stable_03`). 64 z 4027 trójkątów „player color” (14 modeli)
  ma środek UV na alfa = 0.
* Ukryte bryły pomocnicze: `bld_stable_03` ma zamknięty prostopadłościan 0,45 × 0,45 × 0,145 w środku modelu,
  podzielony między materiał zwykły (góra, 2 boki) i „player color” (dół, 2 boki), z UV na kwadracie 0,02 × 0,02 tekstury
  (0,368–0,388; 0,492–0,512), gdzie alfa = 0 w całości. Gra go nie pokazuje, więc musi go wycinać alfą.
* Reguła z naprawy grafiki („player color” bez wycinania) była błędna. Bez wycinania bryła rysowała się jako czarne
  pudło (tekstura czarna × kolor gracza).

## 2. Ściany dwustronne = dwa przeciwnie skierowane trójkąty; nawinięcie spójne [D]
* Po imporcie (zamiana 2↔3 indeksu przy zmianie osi) normalna geometryczna 98,6% trójkątów jest przeciwna do
  normalnych wierzchołków. Nawinięcie jest więc spójne, a ściany przednie w Godot (zgodnie z ruchem wskazówek zegara) są
  zewnętrzne. W modelach scenariusza Troi spójność wynosi 98,9% (64 modele, 11 720 trójkątów).
* 1189 par trójkątów współpłaszczyznowych o przeciwnym zwrocie w tym samym materiale (52 ze 150 modeli). Ściany
  widoczne z obu stron (płyty podłoża, dachy, płoty) są zbudowane z dwóch trójkątów. Silnik gry musiał więc odrzucać
  tylne ściany [H co do trybu D3D].
* Rysowanie obustronne (OpenEE do 0.5.1) powodowało, że oba trójkąty walczyły w buforze głębokości. Tylny miał normalną
  skierowaną w dół, więc był ciemny, i dawał czarno-pomarańczowe poziome pasy na płycie stajni. Wewnętrzne ściany dachów
  i płotów przebijały się przez zewnętrzne, więc dach i płot wyglądały na źle złożone.
* Baza obiektów sceny ma wyznacznik −1 (UkladEE: osie EE → Godot). `render_mode cull_back` nie kompensował odbicia:
  budynki znikały w OpenGL i Vulkanie. Dlatego odrzucanie robi shader: `FRONT_FACING` porównany ze znakiem wyznacznika
  `MODELVIEW_MATRIX`. Sprawdzone zrzutami modelu zwykłego i w bazie lustrzanej (`--lustro`), także dla MultiMesh i VAT.

## 3. Nakładki koloru gracza [D]
* 113 par „player color” leży równolegle 0,001–0,002 jednostki modelu przed innym materiałem (zwrot zgodny).
  Przykład: kraty na snopkach siana w stajni. To zamierzone nakładki. Po wycinaniu alfy widać tylko ich kształt.

## 4. Billboardy („Always face camera”) [D]
* Średnia normalna (ważona polem) impostorów wskazuje azymut −45° układu CEM (od +X ku −Y), z nachyleniem ok. 18° ku
  górze. Dotyczy to 91 ze 195 modeli; kolejne grupy to −60° (26 modeli) i −30° (23 modele). To kierunek stałej kamery EE,
  pod którą narysowano karty drzew.
* OpenEE do 0.5.1 obracał do kamery oś +Z modelu, czyli 45° obok kierunku projektowego. Drzewo (np. `amb_spruce05`,
  karta korony 18 wierzchołków) było widoczne ukośnie, jako płaski, „złożony” zielony pas. Od 0.5.2 do kamery obracany
  jest kierunek −45° CEM (`ImporterModeli.BILLBOARD_AZYMUT_ST = 45`).

## 5. Podstawy budynków a teren [D/H]
* Płyty podłoża budynków leżą ok. 0,008 jednostki modelu nad podstawą. Wysokość obiektu to interpolacja dwuliniowa,
  a siatka terenu składa się z trójkątów, więc teren przebijał płyty zależnie od precyzji bufora głębokości (w Vulkanie
  lavapipe płyta stajni znikała prawie całkiem).
* OpenEE przesuwa głębię wierzchołków modeli o 0,3% odległości ku kamerze, wzdłuż promienia, więc obraz na ekranie się
  nie zmienia. Sposób, w jaki robi to gra (np. spłaszczanie terenu pod budynkiem), jest nieustalony [H].

## 6. Kolor tekseli przezroczystych [D]
* Przed budową mipmap kolor tekseli o alfa = 0 jest uzupełniany kolorem sąsiadów (`Image.fix_alpha_edges`). Bez tego
  filtrowanie wciąga czerń w brzegi wycinanych kształtów. Kanał alfa się nie zmienia.
