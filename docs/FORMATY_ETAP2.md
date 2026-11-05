# OpenEE – nowe ustalenia dotyczące formatów (etap 2)

Uzupełnienie `docs/FORMATY.md`. Oznaczenia: [D] potwierdzone na danych/testem, [K] wniosek pośredni, [H] hipoteza, [?] nieustalone.

## 1. CEM `SSMF` 1.3 [D] – 11/11 modeli EE zużytych co do bajta
Nazwy struktur zgodne z publiczną dokumentacją crate `cem` (moduł v1: Quantities, Vertex, Material, Frame);
układ, kolejność i rozmiary ustalone na danych (fx_debrisflat, amb_walrus_00, następnie wszystkie 11 plików).
```
'SSMF' u16 1 u16 3
8 × u32: klatki, materiały, punkty, trójkąty, grupy_trójkątów, wierzchołki, punkty_tag, modele_potomne
napis nazwa (u32 + bajty)      3 × f32 środek      u8 [?]
punkty × u32 [?]
trójkąty × 3 × { u32 indeks_wierzchołka, 2 f32 UV, 3 f32 RGB, 4 f32 [?] }
grupy × { napis nazwa (np. "player color", "staff"), u32 n, n × u32 indeks_trójkąta }
materiały × { u32 n, n × u32 indeks_trójkąta, u8 flaga, [jeśli flaga: napis tekstura, u32 [?]] }
wierzchołki × { u32 indeks_punktu, f32 [?] }
punkty_tag × napis
klatki × { f32 promień, punkty × 3 f32, wierzchołki × u16 normalna_kwantowana [?], punkty_tag × 3 f32, 4×4 f32, AABB 6 f32 }
potomne × model SSMF (także 2.0)
```
Modele: air_balloon_09, amb_foundation1–3, amb_streetlamp_12, amb_walrus_00 (50 klatek), bld_towncenter_10,
fx_debrisflat, gun_80mmaa_10 (21 klatek, 1 potomny), men_priest_11 (75 klatek), nav_dardocruiser_11 (2 potomne).
Normalne kwantowane (10086 kierunków wg dokumentacji crate) – tablica nieodtworzona; OpenEE liczy normalne ścian.

## 2. Tabele db – dekoder sterowany schematem [D]
Schemat EE DB Editor (GPLv3) skopiowany do `dane/schemat_db_eedbeditor`, układ wyeksportowany do `dane/uklad_db.json`.
AoC: 39/39 testowanych tabel zużytych co do bajta (dbobjects 848, dbgraphics 991, dbsounds 1087, dbterrain 93, …).
EE: dbobjects i dbcivilization **nie** pasują do schematu AoC (inne rekordy) – [?]; pozostałe 10 sprawdzonych tabel EE – OK.
Kluczowe pola: dbobjects `Graphic ID`, `Graphic size`, `Unit type`, `Always face camera`, `Language ID`,
`Creation/Action/Selection/Death sound`; dbgraphics `Model path`, `Texture path` (czasem bez rozszerzenia);
dbsounds `Pathname`, `ID`; dbterrain `Tyles/Tiles on X/Y axis`, `Available` (animacja).

## 3. Warianty tekstur terenu [D] – ZASTĄPIONE w etapie 3 (FORMATY_ETAP3 §1: kolumny odbite, obraz odbity poziomo)
`dbterrain`: liczba plików `<baza>_N` = `Tiles on X axis × Tiles on Y axis` (2×2 → 4, 4×4 → 16; woda 16×1 = 16 klatek
animacji). Analiza ciągłości krawędzi między plikami: układ **wierszami** (pliki 1,2 obok siebie, 3,4 w następnym
wierszu) daje najmniejsze szwy (rock_2: 138 vs 198 dla układu kolumnami i ≥166 dla losowych permutacji; cliff_1 58,9;
sandybeach_1 32,0 – minimum). Tekstura obejmuje jedno pole, mozaika powtarza się co X×Y pól.
Wybór pliku: `1 + (r mod Y)·X + (c mod X)`; orientacja osi (r↔c, odbicia) – [K], nierozstrzygnięta bez porównania z grą.

## 4. Przejścia tekstur i klasa punktu [?] – ROZSTRZYGNIĘTE w etapie 3 (FORMATY_ETAP3 §2)
Klasa punktu (u8) nie koreluje jednoznacznie z typem/rodziną/teksturą szarą terenu sąsiednich pól (zgodność 4885/32001
dla „Terrain gray type”) – mechanizm mieszania tekstur nieodtworzony. OpenEE rysuje granice pól bez mieszania.

## 5. Kolor gracza [K/H]
* Źródło koloru: `GEColor` gracza w kawałku 5 scenariusza [D] (np. P1 = (1,0,0) w kampanii Rzym), `dbcolortable`
  (pola „Player” i „Model” RGB) [D].
* CEM 2.0: materiał o nazwie `player color`; CEM 1.3: grupa trójkątów `player color` [D].
* Tekstury 32-bit: kanał alfa = 0 w obszarach tarczy/emblematu na teksturze koszar i w nieużywanych obszarach atlasu [D];
  liście drzew – alfa jako przezroczystość [D]. ~~OpenEE: w materiale `player color` kolor = mix(kolor gracza, tekstura, alfa)~~
  – **OBALONE** w naprawie grafiki (FORMATY_NAPRAWA_GRAFIKI §3): fragmenty tekstur pod `player color` są szare z alfa 255,
  więc kolor = tekstura.rgb × kolor gracza; w pozostałych materiałach alfa = wycinanie [H].

## 6. Obiekty scenariusza [D]
Kawałek 5: 18/18 scenariuszy kampanii AoC (do 15 593 obiektów) – czytnik OpenEE (Python i GDScript) zgodny z czytnikiem
laboratorium co do liczby obiektów. Pozycja ciągła = elementy t[3], t[7] macierzy GETransformation (kolumna, wiersz siatki).
Obiekty z pozycją (−10000, −10000) to jednostki ukryte/w garnizonie. Kąt `angle` – [H] radiany wokół osi pionowej (etap 3: ODRZUCONE – obrót z macierzy, FORMATY_ETAP3 §5).
Scenariusze EE (wersja starsza) – czytnik kończy się błędem listy (format jednostek inny) [?].

## 7. hashdb GOG [D]
`goggame-<id>.hashdb`: ZIP z jednym plikiem; `u32 12, u32 1, u32 N`, N × {ścieżka char[1024], MD5 char[32]}.

## 8. Language.dll [D]
Tabele RT_STRING (bloki po 16 napisów UTF-16, ID = (blok−1)·16 + i). Czytnik GDScript bez ładowania DLL. ID zgodne
z „Language ID” w dbobjects (np. 1143 – „Falanga”).
