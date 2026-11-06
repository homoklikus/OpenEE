# OpenEE – raport: diagnostyka pozostałych artefaktów modeli (0.5.1-dev → 0.5.2-dev)

Data: 2026-11-05. Mechanika RTS wstrzymana; zmiany dotyczą wyłącznie importu i renderowania modeli oraz narzędzi
diagnostycznych.

## 1. Punkt wyjścia
* Git: `main` = `667b677` lokalnie i na GitHubie (sprawdzone `git ls-remote origin`). Drzewo było czyste.
* Kopia zapasowa: `kopie_OpenEE/OpenEE_przed_diagnostyka_051_2026-11-05.tar.gz`.
* Zrzut użytkownika (Debian 13, Vulkan) pokazywał: prostokąt z czarno-pomarańczowymi poziomymi pasami, „źle złożone”
  fragmenty dachu i płotu oraz płaską zieloną roślinność obok budynku.

## 2. Identyfikacja obiektu – z danych scenariusza, bez zgadywania nazwy
1. Narzędzie `godot/narzedzia/obiekty_scenariusza.gd` wypisało budynki scenariusza „The Trojan War”
   (`EETheGreeks.ssa`, scena RTS/podglądu). Kandydaci: m.in. Stable – Copper (2 obiekty), Granary/Mill – Copper.
2. Wyrenderowano okolice kandydatów w scenie podglądu. Kadr wokół pola **(157, 230)** odtwarza ten sam obiekt i układ co
   zrzut użytkownika (inna kamera): czarne pudło z pasami, dach, płot, zielony pas, granica bruku i trawy
   (`wyniki/diag051/troja_stajnia5_przed.png`). Artefakt występował też w OpenGL, nie tylko w Vulkanie.
3. Obiekty w promieniu 3 pól (`--wokol=157,230,3`):

| Obiekt (dbobjects) | Grafika (dbgraphics) | Model | Położenie |
|---|---|---|---|
| b Stable (gracz 5) | **Stable - Copper** | `models/bld_stable_03`, tekstura `bld_stable_03T.sst` (1 obraz 256²) | 157,0; 230,0; skala 1,85 |
| Tree 12 [Spruce] (świat) | **Tree - Spruce 5** | `models/amb_spruce05`, „Always face camera” = 1 | 156,5; 231,5 |
| Camera Object ×3 | Camera | `bld_camera` (pomocniczy, niewidoczny) | – |

**Zielony fragment nie należy do budynku.** To osobny obiekt scenariusza: świerk z flagą billboardu.

## 3. Narzędzia diagnostyczne (nowe)
* **`sceny/diag_modelu.tscn`** (`./uruchom_openee.sh model --model="…"`) – tryb diagnostyczny pojedynczego modelu:
  1. każda powierzchnia (część × materiał) osobno, z przełącznikami (`--czesci`, `--materialy`, UI);
  2. włączanie i wyłączanie materiałów;
  3. tryby `uv` (siatka UV), `indeksy` (kolor z numeru trójkąta), `normalne`, `alfa`;
  4. animacja wyłączona, dowolna klatka CEM (`--klatka`, UI);
  5. tryb `materialy` – bez tekstur, osobny kolor dla każdego materiału;
  6. diagnostyczne przełączniki odrzucania ścian (`--cull=tyl|nie|przod`), testu głębokości, przezroczystości
     (`--alfa=wycinanie|brak|mieszanie`), mipmap, alfy z poziomu 0, uzupełniania koloru pod alfa = 0, baza lustrzana
     (`--lustro`), materiały produkcyjne (`--produkcja`);
  7. porównanie rendererów: `narzedzia/porownaj_renderery.sh` (OpenGL i Vulkan, ta sama kamera, różnica pikseli);
  8. tryb `wspolplaszczyznowe`: pary współpłaszczyznowe (czerwone = zwrot przeciwny, żółte = zgodny) i duplikaty
     (fioletowe).
  Kliknięcie trójkąta albo `--zbadaj=id` daje: indeksy, wierzchołki, UV, materiał, `tekstura_id`, użyty obraz SST,
  alfę w środku, transformację części i rodzica. Raport JSON: `wyniki/diag_modelu/<model>.json`.
* `silnik/diagnostyka/diagnostyka_modelu.gd` – analizy używane przez scenę i testy.
* `godot/narzedzia/statystyka_geometrii.gd`, `narzedzia/kierunek_billboardow.py`, `statystyka_alfa.py`,
  `wspolplaszczyznowe.py`, `analiza_modelu.py`, `uv_modelu.py` – statystyki na danych gry (tylko odczyt).
* `narzedzia/test_wizualny_051.sh` + `metryki_zrzutu.py` – test wizualny przed/po z tej samej kamery.

## 4. Przyczyny artefaktów (eksperymenty)

### Artefakt 1 – prostokąt z czarno-pomarańczowymi poziomymi pasami
Są tu dwie nakładające się przyczyny w **rendererze**:
* **Czarne pudło = ukryta bryła pomocnicza rysowana bez wycinania alfy.** Model ma zamknięty prostopadłościan
  0,45 × 0,45 × 0,145. Sześć trójkątów należy do materiału zwykłego, sześć do „player color”. Wszystkie mają UV na
  kwadracie tekstury o alfa = 0 (teksele czarne). Materiał zwykły był wycinany, ale „player color” nie, więc dół i dwa
  boki rysowały się na czarno. Pokazuje to `wyniki/diag051/tryby/czesci_mat1.png`, gdzie sam materiał 1 jest bez alfy.
  Błędna była reguła z naprawy grafiki 0.5.1: „player color bez wycinania”.
* **Pasy = z-fighting ścian dwustronnych.** Płyta podłoża stajni (i dachy, płoty) to dwa trójkąty o przeciwnym
  zwrocie w tej samej płaszczyźnie (42 pary w modelu). Renderer rysował obustronnie, więc obie ściany walczyły w buforze
  głębokości. Tylna miała normalną w dół, czyli była ciemna. Stąd poziome pasy czerni i pomarańczowej ziemi.
  Tryb `wspolplaszczyznowe` zaznacza tę płytę na czerwono.

  To nie był „zwykły” z-fighting do załatania przesunięciem. Właściwą poprawką jest odrzucanie tylnych ścian, którego
  wymagają dane.
* **Pomniejsza przyczyna: teren przebijał płytę podstawy.** Płyta leży 0,008 jednostki modelu nad podstawą, a siatka
  terenu odbiega od interpolowanej wysokości obiektu. W Vulkanie (lavapipe) płyta znikała prawie w całości.

### Artefakt 2 – „źle złożone” dach i płot
Geometria i hierarchia są poprawne: jedna część, macierz jednostkowa, 0 duplikatów, nawinięcie spójne w 100%.
Przyczyna też leży w **rendererze** i jest ta sama co pasów: rysowanie obustronne ścian zbudowanych z dwóch trójkątów.
Wewnętrzne strony dachu i płotu (z normalnymi do wnętrza) przebijały się przez zewnętrzne, więc kształt dachu się
rozpadał. Do tego czarne pudło zasłaniało część zagrody. Po odrzucaniu tylnych ścian dach dwuspadowy, szopa i płot są
spójne (`wyniki/diag051/eksp/zestaw_cull.png`).

Pierwsza próba z `render_mode cull_back` sprawiła, że budynki w scenie znikły. Przyczyną jest lustrzana baza obiektów
(wyznacznik −1, `UkladEE`). Dlatego odrzucanie robi shader, z uwzględnieniem znaku wyznacznika.

### Artefakt 3 – płaska zielona roślinność
To osobny obiekt (świerk), błąd w **rendererze** (billboard). Impostory „Always face camera” są narysowane pod stałą
kamerę EE: średnia normalna wskazuje azymut −45° CEM (91 ze 195 modeli, mediana 40 sprawdzonych w teście: −41,8°).
OpenEE obracał do kamery oś +Z modelu, więc kartę korony było widać pod kątem 45°, jako płaski, wygięty pas.
Porównanie azymutów 0°/45°/−45°/90° jest w `wyniki/diag051/eksp/zestaw_drzewo.png`; przy 45° drzewo jest poprawne.

### Sprawdzone i bez błędu
Indeksy (względne wobec `v_offset`), wybór obrazu SST (`tekstura_id`), UV, transformacje części, liczba klatek
(świerk ma 2 klatki kołysania – statyczny), brak duplikatów w stajni.

### Wcześniejsze hipotezy uznane za błędne
* „Player color bez wycinania alfy” (naprawa grafiki 0.5.1).
* Rysowanie modeli obustronnie (etapy 1–5).
* Billboard obracający oś +Z modelu (etap 3).

## 5. Poprawki (bez wyjątków dla konkretnych modeli)

| Warstwa | Zmiana | Pliki |
|---|---|---|
| renderer | wycinanie alfa w każdym materiale z kanałem alfa (`ImporterModeli.wymaga_wycinania`) | `importer_modeli.gd`, `animacja_vat.gd` |
| renderer | odrzucanie tylnych ścian w shaderze: `FRONT_FACING` + znak wyznacznika `MODELVIEW_MATRIX` (MeshInstance, MultiMesh, VAT, billboard) | j.w. |
| renderer | billboard: obrót kierunku projektowego −45° CEM do kamery (`BILLBOARD_AZYMUT_ST = 45`) | `importer_modeli.gd` |
| renderer | przesunięcie głębi modeli o 0,3% ku kamerze wzdłuż promienia (obraz bez zmian, podstawy nad terenem) | `importer_modeli.gd`, `animacja_vat.gd` |
| przygotowanie tekstur | kolor tekseli o alfa 0 uzupełniany przed mipmapami (`ImporterModeli.obraz_gpu`) – bez czarnych obwódek | j.w. |

Importer geometrii nie wymagał zmian.

## 6. Testy
* Nowe `godot/testy/testy_diagnostyki.gd` (14 testów):
  * wykrywanie par współpłaszczyznowych przeciwnych i zgodnych oraz duplikatów (model syntetyczny);
  * zgodność nawinięcia;
  * wycinanie alfa w „player color” (statyczne i VAT);
  * uzupełnianie koloru pod alfa 0;
  * odrzucanie ścian z wyznacznikiem;
  * przesunięcie głębi;
  * obrót billboardu.
  Na danych gry:
  * ukryta bryła stajni w obu materiałach;
  * pary współpłaszczyznowe stajni;
  * spójność nawinięcia w Troi (98,9%);
  * kierunek impostorów.
* Zaktualizowany test z naprawy grafiki („player color” z wycinaniem).
* **Wynik: 150/150 zaliczonych.** Test czystej kopii (bez danych gry) – w sekcji 9.
* **Test wizualny** (`narzedzia/test_wizualny_051.sh`, kadr stajni, ta sama kamera, `wyniki/diag051/test_wizualny/`):

| Zrzut | czarne piksele | gradient pion./poziom (pasy) |
|---|---|---|
| przed, OpenGL (llvmpipe) | 4,18% | 1,288 |
| po, OpenGL (llvmpipe) | **0,66%** | **1,060** |
| przed, Vulkan (lavapipe) | 2,62% | 1,172 |
| po, Vulkan (lavapipe) | **0,40%** | **1,064** |

* Porównanie rendererów po zmianach (`porownaj_renderery.sh`, stajnia): 0,72% pikseli różni się o więcej niż 16/255.
* Zrzuty przed/po z identycznej kamery (`wyniki/diag051/`, lokalnie – zawierają grafikę gry):
  * `stajnia_przed_po_kadr.png` (OpenGL i Vulkan);
  * `kamera/troja_przed_po_4.png`;
  * `kamera/rzym_przed_po.png`;
  * `kamera/galeria_przed_po.png` (jednostki VAT bez zmian).

## 6a. Porównanie z oryginalną grą (komputer użytkownika, prawdziwe GPU)
Za zgodą użytkownika uruchomiono oryginalne Empire Earth: The Art of Conquest (instalacja GOG przez Lutris/Proton,
narzędzia riverlands-ee) na komputerze użytkownika. Kampania „The Trojan War” jest w EE 1.x, a nie w AoC, więc
w **edytorze scenariuszy** na nowej, niezapisanej mapie postawiono obiekty „Stajnia” i „Drzewo – świerk”. W instalacji
nie zapisano żadnego pliku; mapy nie zapisano, a grę zamknięto. Zrzut: `Testy_MCP/zrzuty/zrzut_20261105_233725.png`,
zestawienie: `wyniki/diag051/porownanie_ee.png`.

Wyniki:
* **Stajnia w oryginale nie ma czarnej bryły ani pasów.** Widać dwuspadowy dom kryty strzechą (rama okna i belki
  w kolorze gracza), daszek nad klepiskiem, kamienną obwódkę, snopki, płot i chorągiew w kolorze gracza z ciemną
  sylwetką konia. OpenEE 0.5.2 pokazuje ten sam układ i te same elementy; OpenEE 0.5.1 pokazywał czarne pudło, pasy
  i rozsypany dach. To potwierdza, że bryła pomocnicza jest w grze ukryta, a ściany dwustronne nie walczą ze sobą.
* **Szyld:** sylwetka konia w oryginale jest ciemna, nie przezroczysta. Teksele konia mają alfę 255 (923 z 1150 tekseli
  szyldu), więc wycinanie alfy w OpenEE też zostawia konia ciemnym. Przezroczyste są tylko pojedyncze plamki
  (16 tekseli z alfą 0) – tak samo w oryginale (zielone kropki trawy na chorągwi).
* **Świerk w oryginale stoi pionowo i jest stożkowy, zwrócony do kamery.** Tak samo wygląda w OpenEE 0.5.2
  (azymut 45°). W 0.5.1 (azymut 0°) był płaskim, wygiętym pasem.
* Orientacja budynku względem kamery w oryginale (chorągiew z lewej, szczyt domu z prawej u góry, snopki z prawej) jest
  zgodna z OpenEE.
* Pozostała różnica: w OpenEE krawędź płyty klepiska bywa ciemniejsza od strony kamery (oświetlenie boków płyty).
  W oryginale tego nie widać. To kwestia oświetlenia, nie geometrii [H].

## 7. Ograniczenia weryfikacji
* **OpenEE renderowano wyłącznie w środowisku wirtualnym** (Ubuntu 22.04 w maszynie wirtualnej Claude). OpenGL działał
  na llvmpipe, a Vulkan na lavapipe (Mesa 23.2.1). Lavapipe rozpakowano do katalogu użytkownika bez instalacji
  w systemie i bez sudo. Na GPU użytkownika uruchomiono tylko **oryginalną grę**, jako wzorzec (§6a); narzędzia sesji
  nie pozwalają uruchomić Godota na komputerze użytkownika. **Render OpenEE na GPU użytkownika (Debian 13, Vulkan)
  pozostaje niezweryfikowany.** Proszę uruchomić `GODOT=… narzedzia/test_wizualny_051.sh wyniki/tw` i
  `./uruchom_openee.sh rts` w tym samym miejscu mapy.
* Przesunięcie głębi (0,3%) jest kompromisem: przy bardzo płaskim kącie obiekty mogą przebijać wzgórza leżące tuż
  przed nimi. Sposób, w jaki robi to gra, jest nieznany.
* Około 1,4% trójkątów ma nawinięcie przeciwne do reszty modelu (np. `bld_capital_02` 14%). Przy odrzucaniu ścian mogą
  zniknąć, jeśli to nie są ściany od spodu. Wizualnie nie zauważono ubytków w Troi i Rzymie, ale nie sprawdzono
  wszystkich modeli.
* Impostory o innym azymucie (−60°, −30°; ok. 25% modeli) są obracane stałym 45°, więc odchylenie wynosi do 15°.
* Pary współpłaszczyznowe o zgodnym zwrocie w tym samym materiale (589 w próbce) mogą nadal migotać przy dużym
  oddaleniu.

## 8. Bezpieczeństwo i licencja
Instalacje gry tylko do odczytu; Riverlands i laboratorium nietknięte. Bez dekompilacji. Do repozytorium trafiają
wyłącznie pliki tekstowe; zrzuty i wyniki pozostają w ignorowanym `wyniki/`. Licencja GPLv3.

## 9. Git / GitHub
* Commit lokalny `1b8ed1c` „OpenEE 0.5.2-dev – diagnostyka modeli: alfa, odrzucanie ścian, billboardy” (34 pliki, tylko
  tekst: kod, testy, narzędzia, dokumentacja) + commit z tym raportem; rodzic `667b677` (= `origin/main`).
* W indeksie nie ma zasobów gry. Jedyne pliki PNG w repozytorium to własne banery launchera.
* Test czystej kopii (`git clone` bez danych): 145 testów – 78 zaliczonych, 67 jawnie pominiętych, 0 błędów.
  Z danymi: 150/150.
* GitHub: sesja nie ma dostępu do konta (brak powiązania; push z maszyny wirtualnej bez poświadczeń). Publikację
  wykonuje użytkownik: `git push origin main` (bez force, historia liniowa nad `667b677`).

## 10. Dodatek (2026-11-06): koszary i meczet ze zrzutu użytkownika
Identyfikacja z danych scenariusza „The Trojan War” (`--wokol=152,239,9`, gracz 5):
* **Barracks - 01** (`models/bld_barracks_01`, tekstura `bld_barracks_01T.sst`, 1 obraz) – pole (148, 239), skala 1,78;
* **x Mosque** (`models/bld_bluemosque_04`, tekstury `bld_bluemosque_04T.sst`, 2 obrazy: `bld_mosque_AT` i `bld_mosque_BT`)
  – pole (152, 239), skala 1,78.

Analiza: oba modele mają 1 część, macierz jednostkową, 0 duplikatów i 100% spójne nawinięcie. Oba mają ukryte bryły
pomocnicze z UV na alfa 0, tak jak stajnia (koszary: 40 trójkątów; meczet: 24 trójkąty, prostopadłościany
0,82 × 0,86 × 0,32 i 0,86 × 0,86 × 0,55), usuwane wycinaniem alfy. Pomarańczowe obramowania to kolor gracza 5
(w oryginale gracz 1 jest niebieski).

Porównanie z oryginalnym EE (edytor scenariuszy, Twój komputer, bez zapisu; `wyniki/diag052/porownanie_ee_koszary_meczet.png`):
* **Koszary:** kształt, otwór, kości, kolce, emblemat „X” w kolorze gracza i kamienie u podstawy są zgodne z OpenEE 0.5.2.
  Różnica: w OpenEE skóra namiotu ma ostrzejsze załamania cieniowania. To oświetlenie, nie geometria [H].
* **Meczet:** w OpenEE (OpenGL/llvmpipe i Vulkan/lavapipe, w scenie i w trybie diagnostycznym, z bliska i z daleka)
  wszystkie elementy są obecne i zgodne z oryginałem. Dotyczy to też arkady z ostrołukami po prawej stronie i kolumn
  w kolorze gracza między drzwiami. **Na zrzucie użytkownika (GPU, Vulkan) brakuje arkady i kolumn między drzwiami** –
  w środowisku wirtualnym tego nie odtworzono. Wyłączenie odrzucania ścian (`--bez-odrzucania`) w VM niczego nie zmienia.
  Przyczyna pozostaje nieustalona; podejrzewane: różnica sprzętowa w odrzucaniu ścian (`FRONT_FACING` przy lustrzanej
  bazie), przesunięcie głębi (`POSITION`) przy przebiegu wstępnym głębi Forward+, wybór poziomu mipmapy dla wycinania alfy.
* Dodano przełączniki A/B do sprawdzenia na GPU (argumenty po `--` w każdej scenie):
  `--bez-odrzucania`, `--bez-przesuniecia-glebi`, `--bez-wycinania-alfa`.
