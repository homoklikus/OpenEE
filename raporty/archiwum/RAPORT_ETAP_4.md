# OpenEE – raport etapu 4: animacje, hierarchia modeli i weryfikacja silnika graficznego

Wersja: **0.4.0-dev** (rozwojowa). Punkt wyjścia: `main` = `82ef227` (GitHub i lokalnie zgodne, drzewo czyste).
Kopia przed zmianami: `kopie_OpenEE/OpenEE_przed_etap4_2026-11-05.tar.gz` (poza repozytorium).
Szczegóły formatów: [docs/FORMATY_ETAP4.md](../../docs/FORMATY_ETAP4.md); architektura: [docs/ARCHITEKTURA.md](../../docs/ARCHITEKTURA.md) §Etap 4.

## 1. Rozpoznana struktura animacji CEM
* **Klatki kluczowe pełnej geometrii, bez szkieletu** [D]: każda klatka zawiera pozycje i normalne wszystkich
  wierzchołków (2.0) lub pozycje punktów (1.3), punkty tag, macierz części i AABB. UV stałe (0/866 modeli zmienia UV),
  macierz korzenia zawsze jednostkowa (866/866). 866 modeli EE+AoC dekoduje się bez błędów; 276 ma animację
  wierzchołkową, 155 części potomne, 567 punkty tag.
* **Sekwencje są w `dbgraphics`, nie w CEM** [D]: jeden model na grafikę, sekwencja = zakres klatek
  + czas + pętla + 2 klatki zdarzeń z dźwiękami. 12 gniazd; znaczenie gniazd ustalone na dźwiękach z dbsounds
  (0 atak, 1 ruch, 2 bezczynność, 4 śmierć + sekwencje po śmierci, 5–11 prace zależne od jednostki). 1493 sekwencje –
  99,7 % mieści się w modelach (5 wyjątków = błędy danych gry / modele pomocnicze).
* **Tempo** [H]: „wartość” × 0,01 s = czas cyklu (uzasadnienie i alternatywa – FORMATY_ETAP4 §2.3).
* **Interpolacja** [H]: liniowa między klatkami (wyłączalna) – format zapisuje tylko klatki kluczowe.

## 2. Zaimplementowane typy animacji
| Typ | Realizacja | Przykłady |
|---|---|---|
| animacja wierzchołkowa (morph klatek) | VAT: wszystkie klatki w teksturze float, interpolacja w shaderze | piechota, obywatele, kawaleria, trebusz |
| ruch części potomnych zapisany w klatkach | macierz części na klatkę × hierarchia, wypiekane do VAT | koła armat i trebusza, wieżyczka AA Gun 88 (21 kl.), Grigor (67 kl.) |
| części statyczne | macierz klatki 0 (także w imporcie statycznym) | koła/wieżyczka półgąsienicówki AA |
| pętla / jednorazowa | stan instancji (liczba klatek ze znakiem) | bezczynność, ruch, atak / śmierć (zatrzymuje się na ostatniej klatce) |
| animowany teren | Texture2DArray 16 klatek wody, tempo z dbterrain [H] | Ocean Water (ID 46) |

System odtwarzania (`OdtwarzaczAnimacji`): odtwarzanie wybranej sekwencji, pauza/wznowienie, pętla wymuszona lub z danych,
zmiana sekwencji, prędkość kanału i globalna, niezależna faza każdej instancji, stany logiczne wybierane nazwą stanu
z danych (bez mechaniki ruchu i walki). Stan instancji to 4 liczby zapisywane tylko przy zmianie; aktualizacja na klatkę
to jedno ustawienie zegara globalnego – niezależnie od liczby jednostek.

## 3. Hierarchia modeli
Część potomna = zagnieżdżony SSMF z wierzchołkami lokalnymi i macierzą na klatkę (`v' = D·v + t`, wiersze, przesunięcie
w elementach 3/7/11). `ModelCEM.globalna(i, k) = T_rodzic · T_lokalna`, klatka części `min(k, n−1)`, skala przenoszona,
interpolacja transformacji (obrót sferyczny) w scenie diagnostycznej. Nieprawidłowy rodzic → część jak korzeń,
zgłoszona w `kontrola()`. **Wcześniej (etapy 1–3) części potomne były rysowane w środku modelu bez macierzy** – naprawione
również w imporcie statycznym. Konwencja nazw (`wheel`, `turret_N`, `orbital_cw/ccw_<n>`, `gate`, `ball`) rozpoznawana
i opisana; obrót `orbital_*` nie jest zapisany w klatkach – sterowanie proceduralne poza zakresem etapu.

## 4. Działające przykłady (oryginalne modele z instalacji)
Falanga (75 kl.: ruch 0–15, atak 16–31, bezczynność 32–47, śmierć 48–74), obywatel paleolityczny (prace z dźwiękami
zdarzeń), armata 12-funtowa (strzał 0–7, koła z odrzutem), trebusz (atak 3–33, 6 kół), AA Gun 88 (wieżyczka animowana
macierzą), półgąsienicówka AA (wieżyczka i koła na miejscu). Scenariusze: „The Trojan War” – 84 animowane jednostki
w oknie (4 modele), „Soldiers for Rome” – 11 w oknie; w całych scenariuszach 173 (Troja, 16 modeli) i 669 (Rzym, 31 modeli)
jednostek z bezczynnością, wszystkie zakresy poprawne.

Materiały (lokalne, zawierają zasoby EE – nie trafiają do repozytorium): `wyniki/etap4/diag_falanga.png`,
`diag_galeria_pojazdy.png`, `troja_anim.png`, `rzym_anim.png`, `film_klatki.png`, nagranie `animacje_galeria.mp4`
(100 klatek, 25 kl./s).

## 5. Ograniczenia i nieobsługiwane przypadki
* Tempo animacji i interpolacja – hipotezy (bez porównania z grą); znaczenie gniazda 3 i pola `parametr` – nieustalone.
* Brak sterowania proceduralnego: obrót `orbital_*`, celowanie wieżyczek, toczenie kół podczas ruchu.
* Normalne CEM 1.3 liczone płasko (kwantowane normalne nieodkodowane).
* Interpolacja w VAT jest liniowa na pozycjach – przy szybkim obrocie części (np. koło) między klatkami geometria minimalnie
  się „ściąga”; transformacje w scenie diagnostycznej są interpolowane poprawnie (obrót sferyczny).
* Obiekty `Always face camera` (billboard) pozostają statyczne.
* Zegar animacji w float32 – precyzja fazy maleje po wielu godzinach działania (do przebazowania w przyszłości).
* Woda: jedna faza dla wszystkich pól (tabela 33×33 nieodtworzona), poziom 0; brak ścian brzegowych.

## 6. Wyniki testów – `wyniki/testy_godot.json`: **95/95** (0 pominiętych z instalacją)
* 66 testów etapów 1–3 i launchera – bez regresji (w tym DCL/SSA = Python: 76 tekstur + model, liczby obiektów
  scenariuszy, teren, launcher).
* 29 nowych (`testy/testy_etapu4.gd`):
  * jednostkowe (syntetyczne modele, bez danych komercyjnych):
    * dekodowanie klatek;
    * hierarchia: przesunięcie, oś, obrót, kolejność T_rodzic·T_lokalna na wnuku, interpolacja 45°, tag, zły rodzic, uszkodzone dane;
    * sekwencje z rekordu dbgraphics: zakresy, pętla po masce bajtu, zdarzenia, dźwięki, czas, kontrola;
    * wybór klatek: zawijanie pętli, jednorazowa;
    * VAT = interpolacja ModelCEM;
    * niezależne instancje: faza, pauza, prędkość bez skoku;
    * przełączanie animacji;
    * kolory graczy;
    * import statyczny z hierarchią;
    * wydajność 2000 kanałów;
    * strażnik „testy wykonane do końca”: błąd skryptu nie może dać zielonego wyniku.
  * integracyjne (instalacja EE):
    * falanga: 75 klatek pokrytych sekwencjami;
    * koła armaty dotykają ziemi: test osi;
    * trebusz i AA Gun 88;
    * ModelCEM = Python dla 61 modeli;
    * 1493 sekwencje w zakresie;
    * woda: 16 klatek;
    * DCL szybki = wzorcowy;
    * Troja i Rzym: zakresy, brak znikania obiektów.
* Bez instalacji EE testy integracyjne są jawnie pomijane.
* Błąd znaleziony testami w trakcie prac: sekwencja jednej klatki (74–74) była odrzucana jako pusta – poprawione.

## 7. Wydajność
Warunki: maszyna wirtualna, Xvfb + **llvmpipe (renderowanie programowe)**, Godot 4.7.2 Compatibility, okno 1600×900.
Pomiar na rzeczywistym GPU nie został wykonany: wymagałby otwarcia okna na pulpicie użytkownika. Czasy klatki są
więc czasami rasteryzacji CPU – nadają się do porównań wariantów, nie jako wartości bezwzględne.

| Instancje falangi | Tryb | Czas klatki śr. / p95 [ms] | FPS | Wywołania rysowania | Tworzenie [ms] | Zmiana animacji wszystkich [ms] | Zegar/klatkę [ms] |
|---|---|---|---|---|---|---|---|
| 100 | VAT | 47,0 / 50,6 | 21,3 | 3 | 0,57 | 0,15 | 0,02 |
| 100 | statyczny | 47,9 / 51,4 | 20,9 | 3 | 0,09 | – | – |
| 1000 | VAT | 65,9 / 70,9 | 15,2 | 3 | 1,96 | 1,20 | 0,006 |
| 1000 | statyczny | 59,5 / 65,6 | 16,8 | 3 | 0,40 | – | – |
| 4000 | VAT | 162,2 / 183,3 | 6,2 | 3 | 7,88 | 4,20 | 0,015 |
| 4000 | statyczny | 133,9 / 152,5 | 7,5 | 3 | 0,82 | – | – |

* **Animacja vs statyczna geometria:**
  * narzut VAT względem statycznego MultiMesh wynosi 0–21% czasu klatki (rośnie z liczbą wierzchołków);
  * liczba wywołań rysowania jest identyczna, więc nie ona decyduje o koszcie, tylko pobrania z tekstury w shaderze wierzchołków;
  * koszt CPU aktualizacji jest stały (zegar), a zmiana stanu 4000 jednostek trwa 4,2 ms.
* **Import modelu (falanga, 450 KB po rozpakowaniu):**
  * odczyt i DCL: 173,7 ms przed optymalizacją, 65,8 ms po;
  * parsowanie CEM: 13,7 ms;
  * wypiekanie VAT: 18,8 ms;
  * tekstura VAT: 178 × 150 px.
* **Pamięć:** 61–62,5 MB pamięci statycznej i 18 MB wideo, prawie bez zmian między 100 a 4000 instancji (jedna siatka i jedna tekstura na model).
* **Scena „The Trojan War” (okno 48×48, 335 obiektów):**
  * wczytanie: 2,39 s (w etapie 3 i przed optymalizacją DCL: 7,58 s);
  * czas klatki z animacją: 72,8 ms; bez animacji (`--bez-animacji`): 74,2 ms;
  * w obu wariantach 49 wywołań rysowania;
  * wypiekanie 4 modeli: 0,44 s.
* **DCL:**
  * optymalizacja w GDScript (tablice dekodowania, bez C++);
  * wynik identyczny bajt w bajt;
  * 3,0× szybciej (1,82 MB: 153 ms wobec 454 ms).
  * Przepisanie do C++ nie jest na razie uzasadnione pomiarami.

Grupowanie instancji o tych samych klatkach nie zostało wprowadzone. Przy VAT wszystkie instancje modelu są już
w jednym MultiMesh niezależnie od fazy, więc nie ma czego dalej grupować.

## 8. Zmiany w rendererze terenu i wody
`TerenEE`: woda animowana:
* 16 klatek `Water_OceanB_*` w Texture2DArray;
* klatka = floor(czas / 100 ms) mod 16 [H: 100 z pola „<Used by animated terrains>”];
* przezroczystość przy brzegu jak w etapie 3.

**Poziom wody:** w kodzie gry jest liczony jako `−(skala_wysokości × liczba z rekordu terenu wody)` [K]. Nie ustalono,
z którego pola tę liczbę brać, więc poziom pozostaje 0.

Bez zmian: mieszanie warstw i ściany brzegowe (nie zaimplementowane).

## 9. Weryfikacja zgodności graficznej (kwestie z etapu 3)
| Kwestia | Wynik etapu 4 |
|---|---|
| Części potomne | **rozstrzygnięte [D]** – wierzchołki lokalne + macierz klatki; wcześniej błędnie w środku modelu |
| Białe sylwetki / części tekstur jednostek | nie badano osobno; poprawka transformacji części zmienia tylko wygląd modeli z częściami potomnymi – przyczyna białych sylwetek nadal [?] |
| Bezwzględna orientacja świata | obserwacje (toczenie koła, `orbital_cw/ccw`, przód jednostek = −Y) sugerują układ lewoskrętny, ale niekonkluzywnie – układ osi niezmieniony [H] |
| Poziom wody | ustalono formułę w kodzie gry [K]; pole źródłowe [?]; OpenEE 0 |
| Kolejność mieszania warstw | bez zmian [H] |
| Wysokości obiektów | bez zmian (t[11] ≈ teren, etap 3) |
| Pole `angle` | bez zmian – nie jest obrotem [D, etap 3]; znaczenie [?] |

### Porównanie z uruchomionym Empire Earth – **nie wykonane**
Powody:
1. **Brak zgody.** Zgodnie z zadaniem gry nie uruchamiano bez zgody na plan izolacji.
2. **Brak Wine w odizolowanym środowisku.** Maszyna wirtualna z Xvfb (oddzielony DISPLAY, brak dostępu do pulpitu KDE,
   myszy i klawiatury) nie ma Wine. Instalacja z pakietów jest niemożliwa bez uprawnień administratora. Wine i Lutris
   użytkownika nie są z tej maszyny dostępne i nie były dotykane.

Plan izolacji do akceptacji:
1. Przenośne Wine (archiwum, bez instalacji systemowej) rozpakowane w katalogu tymczasowym maszyny wirtualnej.
2. Osobny `WINEPREFIX` w katalogu tymczasowym, niewspółdzielony z Lutris ani z prefiksami użytkownika.
3. Gra uruchamiana na `Xvfb :99` wewnątrz maszyny wirtualnej. Nie ma ona dostępu do pulpitu KDE ani do fizycznej myszy
   i klawiatury, więc nie da się nimi sterować.
4. Instalacja gry w trybie tylko do odczytu (`bwrap --ro-bind`), zapisy przekierowane na nakładkę tymczasową.
   Konfiguracja Lutris i oryginalna instalacja pozostają nietknięte.
5. Zrzuty przez `xwd`/`import` z `:99`, z tych samych scenariuszy i pozycji kamery co w OpenEE.
6. Po teście usunięcie prefiksu i katalogu tymczasowego.

Zgodności wizualnej nie deklaruje się na podstawie samych zrzutów OpenEE.

## 10. Zmienione pliki
Nowe:
* silnik: `godot/silnik/importery/model_cem.gd`, `godot/silnik/animacja/sekwencje_animacji.gd`, `animacja_vat.gd`,
  `odtwarzacz_animacji.gd`;
* scena diagnostyczna: `godot/sceny/diag_animacji.gd`, `.tscn`;
* testy: `godot/testy/testy_etapu4.gd`, `cem_syntetyczny.gd`;
* narzędzia i dokumentacja: `narzedzia/analiza_animacji.py`, `docs/FORMATY_ETAP4.md`, `RAPORT_ETAP_4.md`.

Zmienione:
* importery i zasoby:
  * `importer_modeli.gd` – import statyczny z hierarchią;
  * `dcl.gd` – szybki dekoder; wzorcowy zachowany;
  * `zasoby.gd` – `wczytaj_model_cem`, `wczytaj_animacje`;
* renderer i sceny:
  * `teren_ee.gd` – woda animowana;
  * `test_scenariusz.gd` – animowany MultiMesh, `--bez-animacji`;
* testy: `uruchom_testy.gd` – wywołanie testów etapu 4;
* projekt:
  * `project.godot` – `[shader_globals] czas_animacji`, wersja;
  * `stan_launchera.gd` – tylko numer wersji;
  * `aktualnosci.json`;
* skrypty:
  * `uruchom_openee.sh` – tryb `animacje`, import po zmianie skryptów;
  * `narzedzia/przygotuj_dane_lokalne.sh` – krok analizy animacji;
* dokumentacja: `README.md`, `docs/ARCHITEKTURA.md`, `docs/HISTORIA.md`, `docs/MAPA_DROGOWA.md`.

## 11. Git i GitHub
* **Stan wyjściowy:** `origin/main` = lokalne `main` = `82ef227`, przed etapem bez zmian zdalnych.
* **Commity etapu (lokalnie, gałąź `main`):**
  * `f3d337f` – kod, testy i dokumentacja etapu 4;
  * kolejny commit – ten raport ze stanem publikacji.
* **Audyt przed commitem:**
  * 33 pliki tekstowe, 0 plików binarnych;
  * brak formatów gry (ssa, cem, sst, tga, wav, mp3, scn, dat, png, mp4);
  * brak ścieżek prywatnych, adresów e-mail i tokenów.
* **Materiały z zasobami EE pozostają lokalne:** `wyniki/etap4/` (ignorowane).
* **Test czystej kopii** (klon w osobnym katalogu, Godot importuje projekt od zera):
  * bez instalacji EE: 93 testy, 40 zaliczonych, 53 jawnie pominiętych, 0 błędów;
  * z instalacją: 95 testów, 92 zaliczone, 3 pominięte z powodem (dane z `przygotuj_dane_lokalne.sh` / pełny audyt warstw), 0 błędów;
  * drzewo robocze pozostało czyste.
* **Publikacja:** **nie wypchnięto.** Sesja nie ma uwierzytelnienia GitHub (konto niepołączone, brak poświadczeń
  w maszynie). Zdalne `main` nadal wskazuje `82ef227`, więc publikacja będzie zwykłym przewinięciem do przodu,
  bez force push. Polecenie do wykonania w katalogu projektu na komputerze z dostępem do GitHub:
  ```
  cd "/media/precell/Inne/Projekty AI/EE Projekt/OpenEE"
  git push origin main
  ```
